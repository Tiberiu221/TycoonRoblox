--!strict
-- Oamenii jucatorului [F1, aria I; D49, D56]. Noua meserii, cate un pas al lantului fiecare:
--   Collector  goleste plasele de lemn in depozit      Porter  duce din depozit la gater
--   Hauler     duce ce a iesit din gater la taverna
--   Sawyer     sta la gater (il tine pornit)            Negustorul  sta la taverna (vinde)
--   [D56] Scrap Collector goleste plasa de scrap in shed; Scrap Porter duce din shed la forja;
--   Smelter sta la forja (o tine pornita); Iron Hauler duce fierul de la forja la taverna
-- Traseul si ceasul celor care merg vin STRICT din HandRoutes/HandMath (module pure, aceleasi pe
-- client): serverul NU inventeaza timpi proprii, altfel ce vede jucatorul si ce se intampla de fapt
-- ar diverge [F1 spec 3.3]. Sawyer-ul si Negustorul nu merg: existenta lor intra in lant prin ChainMath.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local HandConfig = require(ReplicatedStorage.Shared.Config.HandConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local CrewMath = require(ReplicatedStorage.Shared.Modules.CrewMath)
local HandMath = require(ReplicatedStorage.Shared.Modules.HandMath)
local HandRoutes = require(ReplicatedStorage.Shared.Modules.HandRoutes)
local VillageLook = require(ReplicatedStorage.Shared.Modules.VillageLook)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RiverService = require(script.Parent.RiverService)

type Hand = DataService.Hand
type Catch = DataService.Catch

local TICK_SECONDS = 0.1 -- 10 Hz, peste minimul de 5 Hz cerut [F1 spec 3.3]

-- Unde lasa fiecare meserie la capatul drumului: HandRoutes.endPlace.

local HandService = {}
local deps: { Remotes: { HandDelivered: RemoteEvent }, PushState: ((Player) -> ())? } = {
    Remotes = nil :: any,
    PushState = nil,
}

-- Ultima "semnatura" a drumului fiecarui om (meserie, al catelea, cati sunt, plasele). EFEMER -- nu se
-- salveaza; serveste doar sa detecteze CAND drumul chiar s-a schimbat (o plasa noua, un al doilea om
-- pe aceeasi meserie), ca omul sa porneasca atunci de la capat, nu la fiecare cumparatura.
local routeKeys: { [Player]: { [string]: string } } = {}

local function push(player: Player)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
end

-- Plasele DETINUTE, in ordinea platformelor -- intrarea pe care o cere HandRoutes. [D61] Lista traieste in
-- VillageLook (modul pur), ca fotografia satului vizitat din balci sa foloseasca exact aceeasi.
local function ownedNetIds(data: DataService.ProfileData): { string }
    return VillageLook.ownedNets(data.Pads)
end

local function routeKey(hand: Hand, index: number, count: number, nets: { string }): string
    local netsPart = if HandRoutes.netKindOf(hand.role) ~= nil then table.concat(nets, ",") else ""
    return `{hand.role}|{index}|{count}|{netsPart}`
end

-- ANGAJAREA [D49], una singura pentru toate meseriile (apelata de PadService la platforma meseriei si
-- de StationService la al doilea om). Numele si infatisarea vin dintr-un seed determinist (indexul
-- platformei + al catelea om): acelasi jucator primeste mereu aceiasi oameni, fara sa salvam alegeri.
function HandService.Hire(player: Player, role: string): boolean
    local data = DataService.Get(player)
    local crewDef = TycoonConfig.CREWS[role]
    if data == nil or crewDef == nil then
        return false
    end
    local crews = CrewMath.fromProfile(data.Hands, data.Crews)
    -- [D70] doar meseriile erelor din joc (CREWS le are si pe ale barajului adormit)
    local crew = crews[role]
    if crew == nil then
        return false
    end
    local index = crew.count + 1
    if index > StationConfig.MAX_PEOPLE then
        return false
    end
    local key = CrewMath.personKey(role, index)
    local pad = TycoonConfig.byId[crewDef.pad]
    if key == nil or pad == nil or data.Hands[key] ~= nil then
        return false
    end
    local seed = TycoonMath.catchSeed(player.UserId, pad.index, index - 1)
    local identity = HandConfig.appearanceFor(seed)
    -- [D65] un prenume pe care nu-l mai poarta nimeni in sat
    local usedNames: { [string]: boolean } = {}
    for _, other in data.Hands do
        usedNames[other.name] = true
    end
    local at = RiverService.Now()
    data.Hands[key] = {
        id = key,
        role = role,
        padId = pad.id,
        name = HandConfig.nameAvoiding(seed, usedNames),
        appearance = {
            body = identity.body,
            hair = identity.hair,
            skin = identity.skin,
            hairColor = identity.hairColor,
            outfit = HandConfig.ROLE_OUTFIT[role] or HandConfig.ROLE_OUTFIT.collector,
        },
        cycleStartAt = at,
        lastEventAt = at,
        carry = {},
    }
    push(player)
    return true
end

-- "collect" la o plasa: ia cel mult `room` bucati, gasirile cu nume ca pe orice marfa [D56 -- colectia e pusa
-- deoparte: gasirile se vand la taverna]. Ce nu incape ramane in plasa. [D53] Ceasul plasei nu se mai reporneste
-- aici: plina, a mers mai departe in ritm (NetService.tick), deci nu prinde din urma deodata.
local function collectNet(data: DataService.ProfileData, hand: Hand, padId: string, room: number)
    local net = data.Nets[padId]
    if net == nil or #net.goods == 0 then
        return
    end
    local kept: { Catch } = {}
    local taken = 0
    for _, item: Catch in net.goods do
        if taken < room then
            table.insert(hand.carry, item)
            taken += 1
        else
            table.insert(kept, item)
        end
    end
    net.goods = kept
end

local function takeInto(player: Player, hand: Hand, place: string, n: number)
    if n < 1 then
        return
    end
    local items = EconomyService.TakeFrom(player, place, n)
    table.move(items, 1, #items, #hand.carry + 1, hand.carry)
end

-- La o oprire: cat mai incape in drumul asta, din plasa, din depozit, de la shed, de la forja sau de la
-- iesirea gaterului.
local function pick(
    player: Player,
    data: DataService.ProfileData,
    hand: Hand,
    stopId: string,
    load: number
)
    local room = load - #hand.carry
    if room <= 0 then
        return
    end
    -- [D65] o oprire care nu e plasa poarta chiar numele locului din FlowConfig (magazia unei linii sau iesirea
    -- atelierului ei), pe orice linie
    local place = HandRoutes.takePlace(stopId)
    if place ~= nil then
        takeInto(player, hand, place, room)
    else
        collectNet(data, hand, stopId, room)
    end
end

-- Lasa tot ce duce in gramada `place`, la capatul drumului. [D70, pasul j13a] Ce nu se poate lasa acolo (la unire, ce nu
-- e piesa ei; la un vanzator, piesele unei uniri) ramane la om: `hand.carry` se rescrie abia dupa ce DropAt a raspuns.
local function drop(player: Player, hand: Hand, place: string)
    if #hand.carry == 0 then
        return
    end
    local placed, rest = EconomyService.DropAt(player, place, hand.carry)
    hand.carry = rest
    if placed > 0 then
        deps.Remotes.HandDelivered:FireClient(player, hand.id, placed, place)
    end
end

-- Instantaneul pentru TycoonState.hands [F1 spec 2.1]. Clientul reface ciclul fiecarui om din
-- HandRoutes cu exact aceleasi argumente (`role`, `index`, `count`, `nets`), deci il deseneaza unde e.
function HandService.Snapshot(player: Player): { any }
    local data = DataService.Get(player)
    if data == nil then
        return {}
    end
    -- [D61] lista se face in VillageLook (modul pur, testat): aceeasi pentru satul tau si pentru cine te viziteaza
    return VillageLook.hands(data)
end

local function tick(at: number)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data == nil or next(data.Hands) == nil then
            continue
        end
        local keys = routeKeys[player]
        if keys == nil then
            keys = {}
            routeKeys[player] = keys
        end
        local nets = ownedNetIds(data)
        local crews = CrewMath.fromProfile(data.Hands, data.Crews)
        local changed = false
        for id, hand in data.Hands do
            if not HandRoutes.isWalker(hand.role) then
                continue
            end
            local crew = crews[hand.role]
            local index = CrewMath.indexOf(id)
            local key = routeKey(hand, index, crew.count, nets)
            if keys[id] ~= key then
                -- drumul s-a schimbat (o plasa noua, un al doilea om): porneste de la capat, ce duce
                -- ramane cu el [F1 spec 3.3]. Clientul il deseneaza din cycleStartAt, deci trimitem.
                hand.cycleStartAt = at
                hand.lastEventAt = at
                keys[id] = key
                changed = true
            end
            local cycle = HandRoutes.cycleFor(hand.role, index, crew.count, nets)
            if cycle.duration <= 0 then
                continue
            end
            local load = HandRoutes.loadFor(ChainMath.walkerRate(hand.role, crew), cycle.duration)
            local events = HandMath.eventsBetween(cycle, hand.cycleStartAt, hand.lastEventAt, at)
            for _, ev in events do
                if ev.kind == "collect" and ev.padId ~= nil then
                    pick(player, data, hand, ev.padId :: string, load)
                elseif ev.kind == "sell" then
                    local place = HandRoutes.endPlace(hand.role)
                    if place ~= nil then
                        drop(player, hand, place)
                    end
                end
            end
            hand.lastEventAt = at
            if #events > 0 then
                changed = true
            end
        end
        if changed then
            push(player)
        end
    end
end

function HandService.Init(d: typeof(deps))
    deps = d
    -- La incarcarea profilului, fiecare om porneste curat de la capatul drumului lui (nu tine minte
    -- de unde a ramas intre sesiuni); ce ducea, care E salvat, ramane cu el [F1 spec 3.3].
    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil then
            return
        end
        local at = RiverService.Now()
        for _, hand in data.Hands do
            hand.cycleStartAt = at
            hand.lastEventAt = at
        end
        routeKeys[player] = nil
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        routeKeys[player] = nil
    end)
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt: number)
        accumulator += dt
        if accumulator >= TICK_SECONDS then
            accumulator = 0
            tick(RiverService.Now())
        end
    end)
end

return HandService
