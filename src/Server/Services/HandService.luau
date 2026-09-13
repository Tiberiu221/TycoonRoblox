--!strict
-- Oamenii jucatorului [F1, aria I; D49]. Cinci meserii, cate un pas al lantului fiecare:
--   Collector  goleste plasele in depozit        Porter  duce din depozit la gater
--   Hauler     duce ce a iesit din gater la debarcader
--   Sawyer     sta la gater (il tine pornit)      Negustorul  sta la debarcader (vinde)
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
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local WorkshopService = require(script.Parent.WorkshopService)
local RiverService = require(script.Parent.RiverService)

type Hand = DataService.Hand
type Catch = DataService.Catch

local TICK_SECONDS = 0.1 -- 10 Hz, peste minimul de 5 Hz cerut [F1 spec 3.3]

-- Unde lasa fiecare meserie de drum ce duce.
local DROP_PLACE = { collector = "storage", porter = "sawmill", hauler = "dock" }

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

-- Oglinda lui netEffectOf din PadService/NetService: rata plasei acestei platforme.
local function netEffectOf(pad: TycoonConfig.Pad): number?
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate
        end
    end
    return nil
end

-- Plasele DETINUTE, in ordinea platformelor -- intrarea pe care o cere HandRoutes.
local function ownedNetIds(data: DataService.ProfileData): { string }
    local ids: { string } = {}
    for _, p in TycoonConfig.PADS do
        if data.Pads[p.id] and netEffectOf(p) ~= nil then
            table.insert(ids, p.id)
        end
    end
    return ids
end

local function routeKey(hand: Hand, index: number, count: number, nets: { string }): string
    local netsPart = if hand.role == "collector" then table.concat(nets, ",") else ""
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
    local index = crews[role].count + 1
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
    local at = RiverService.Now()
    data.Hands[key] = {
        id = key,
        role = role,
        padId = pad.id,
        name = HandConfig.nameFor(seed),
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

-- "collect" la o plasa: ia cel mult `room` bucati. Gasirile cu nume ocolesc traista omului si duc
-- direct in gramada Atelierului daca e cumparat -- ca la strangerea de mana. [D53] Ceasul plasei nu se
-- mai reporneste aici: plina, a mers mai departe in ritm (NetService.tick), deci nu prinde din urma deodata.
local function collectNet(
    player: Player,
    data: DataService.ProfileData,
    hand: Hand,
    padId: string,
    room: number
)
    local net = data.Nets[padId]
    if net == nil or #net.goods == 0 then
        return
    end
    local workshopOwned = data.Pads.workshop == true
    local kept: { Catch } = {}
    local taken = 0
    for _, item: Catch in net.goods do
        if item.g == "named" and workshopOwned then
            WorkshopService.AddCatch(player, item)
        elseif taken < room then
            table.insert(hand.carry, item)
            taken += 1
        else
            table.insert(kept, item)
        end
    end
    net.goods = kept
end

-- La o oprire: cat mai incape in drumul asta, din plasa, din depozit sau de la iesirea gaterului.
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
    if stopId == HandRoutes.STORAGE_STOP then
        local items = EconomyService.TakeFrom(player, "storage", room)
        table.move(items, 1, #items, #hand.carry + 1, hand.carry)
    elseif stopId == HandRoutes.PLANKS_STOP then
        local items = EconomyService.TakeFrom(player, "planks", room)
        table.move(items, 1, #items, #hand.carry + 1, hand.carry)
    else
        collectNet(player, data, hand, stopId, room)
    end
end

-- La capat: lasa tot ce duce, in gramada meseriei lui.
local function drop(player: Player, hand: Hand)
    local n = #hand.carry
    local place = DROP_PLACE[hand.role]
    if n == 0 or place == nil then
        return
    end
    local items = hand.carry
    hand.carry = {}
    EconomyService.DropAt(player, place, items)
    deps.Remotes.HandDelivered:FireClient(player, hand.id, n, place)
end

-- Instantaneul pentru TycoonState.hands [F1 spec 2.1]. Clientul reface ciclul fiecarui om din
-- HandRoutes cu exact aceleasi argumente (`role`, `index`, `count`, `nets`), deci il deseneaza unde e.
function HandService.Snapshot(player: Player): { any }
    local data = DataService.Get(player)
    local result = {}
    if data == nil then
        return result
    end
    local nets = ownedNetIds(data)
    local crews = CrewMath.fromProfile(data.Hands, data.Crews)
    for id, hand in data.Hands do
        local crew = crews[hand.role] or { count = 0, tier = 1 }
        local index = CrewMath.indexOf(id)
        local walker = HandRoutes.isWalker(hand.role)
        local stand = HandRoutes.standFor(hand.role, index)
        local capacity = 0
        if walker then
            local cycle = HandRoutes.cycleFor(hand.role, index, crew.count, nets)
            capacity = HandRoutes.loadFor(ChainMath.walkerRate(hand.role, crew), cycle.duration)
        end
        table.insert(result, {
            id = id,
            role = hand.role,
            name = hand.name,
            index = index,
            count = crew.count,
            tier = crew.tier,
            nets = if walker then nets else {},
            cycleStartAt = hand.cycleStartAt,
            carrying = #hand.carry,
            capacity = capacity,
            appearance = hand.appearance,
            x = if stand ~= nil then stand.x else nil,
            y = if stand ~= nil then stand.y else nil,
        })
    end
    return result
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
                    drop(player, hand)
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
