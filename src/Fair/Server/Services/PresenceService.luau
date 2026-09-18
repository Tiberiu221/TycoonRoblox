--!strict
-- [D60] CINE E IN BALCI SI UNDE. Fiecare client isi spune pozitia (Where, de zece ori pe secunda); serverul o
-- verifica (FairPresence: numere adevarate, loc pe care se merge, pas cat se poate alerga) si le trimite tuturor
-- intr-un singur pachet (Crowd, CrowdCodec). Cine e fiecare -- numele, tinuta, titlul -- pleaca separat (People), doar
-- cand se schimba, si il pune serverul din profil, nu clientul.
--
-- Pozitia e DOAR aspect: nicio cifra din economie nu trece pe aici, deci un pachet stricat poate cel mult sa-si
-- deseneze gresit propriul om.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CrowdCodec = require(ReplicatedStorage.Shared.Modules.CrowdCodec)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local FairPresence = require(ReplicatedStorage.Shared.Modules.FairPresence)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local PresenceService = {}

export type Person = {
    slot: number,
    userId: number,
    name: string,
    outfit: string,
    title: string,
    look: LookMath.Look, -- [D61] silueta, coafura, pielea, culoarea parului (croitoreasa)
    gold: boolean, -- [D61, partea 2] numele auriu: are pass-ul Supporter (doar aspect)
}
export type Deps = {
    Where: UnreliableRemoteEvent,
    Crowd: UnreliableRemoteEvent,
    People: RemoteEvent,
    -- tinuta, titlul purtat, [D61] infatisarea si daca numele e auriu, din profil (VillageService, TitleService, pass)
    Describe: (Player) -> (string, string, LookMath.Look, boolean),
    -- [D61, partea 2] cat de repede merge omul (Swift Boots = 1,5): pasul acceptat creste cu el. Din profil, pe server.
    SpeedFactor: ((Player) -> number)?,
    -- [D61] mesele: te asezi, te ridici, faci cu mana; raspunsul la asezare
    Sit: RemoteEvent,
    Stand: RemoteEvent,
    Wave: RemoteEvent,
    SeatResult: RemoteEvent,
    Allow: (Player, string) -> boolean, -- limita de rata (RateLimiter)
}

type Mark = {
    slot: number,
    sample: FairPresence.Sample,
    facing: string,
    moving: boolean,
    fishing: boolean, -- [D61] cu undita pe jetiu (doar aspect; crezut doar pe jetiu)
    seat: string?, -- [D61] locul pe care stai (FairLayout.SEATS)
    seatedAt: number, -- [D61] cand te-ai asezat (os.clock)
    cheerUntil: number, -- [D61] pana cand faci cu mana (os.clock)
    heardAt: number,
    card: Person,
}

local WAVE_SECONDS = 2
local SEAT_LEAVE = 6 -- cat te poti misca pe loc fara sa te ridici
-- Clientul se aseaza abia cand afla raspunsul; un pachet cu pozitia de dinainte, inca pe drum, nu trebuie sa-l ridice.
-- Ridicarea adevarata vine oricum pe Stand (sigur); pachetele sunt doar plasa pentru un client care nu-l trimite.
local SEAT_GRACE = 1
-- Pozitia de pe server ramane in urma cu un pachet si cu drumul pana aici: cine apasa E din mers e tot langa loc.
local SIT_SLACK = 60
local occupied: { [string]: Player } = {} -- [D61] locul -> cine sta pe el

local MIN_GAP = 1 / (FairPresence.RATE * 2) -- un client care trimite mai des de 20 Hz e ignorat intre pachete
local marks: { [Player]: Mark } = {}
local bySlot: { [number]: Player } = {}
local deps: Deps? = nil
local rosterQueued = false

-- [D60] Pasul "FirstBoardSeen" din palnia balciului: cine a ajuns in fata scenei (pozitia o stim deja de aici).
local STAGE_FRONT = { x = FairLayout.CENTER.x, y = 420 }
local SEEN_DISTANCE = 260
local function noteStage(player: Player, x: number, y: number)
    if (x - STAGE_FRONT.x) ^ 2 + (y - STAGE_FRONT.y) ^ 2 > SEEN_DISTANCE ^ 2 then
        return
    end
    local data = DataService.Get(player)
    if data ~= nil and not data.Firsts.FirstBoardSeen then
        data.Firsts.FirstBoardSeen = true
        Analytics.FairStep(player, "FirstBoardSeen")
    end
end

local function freeSlot(): number?
    for slot = 1, 255 do
        if bySlot[slot] == nil then
            return slot
        end
    end
    return nil
end

local function roster(): { Person }
    local list: { Person } = {}
    for _, mark in marks do
        table.insert(list, mark.card)
    end
    table.sort(list, function(a: Person, b: Person): boolean
        return a.slot < b.slot
    end)
    return list
end

-- Lista `People` pleaca o data pe cadru, oricate schimbari s-au strans.
local function sendRoster()
    if rosterQueued then
        return
    end
    rosterQueued = true
    task.defer(function()
        rosterQueued = false
        local d = deps
        if d ~= nil then
            d.People:FireAllClients(roster())
        end
    end)
end

local function describe(player: Player, slot: number): Person
    local d = deps :: Deps
    local outfit, title, look, gold = d.Describe(player)
    return {
        slot = slot,
        userId = player.UserId,
        name = player.DisplayName,
        outfit = outfit,
        title = title,
        look = look,
        gold = gold,
    }
end

-- Cineva a ajuns (profilul lui e incarcat): primeste un loc in pachet, pe mal, unde acosteaza barca.
local function arrive(player: Player)
    if marks[player] ~= nil or deps == nil then
        return
    end
    local slot = freeSlot()
    if slot == nil then
        return
    end
    bySlot[slot] = player
    local spawn = FairLayout.SPAWN
    marks[player] = {
        slot = slot,
        sample = { x = spawn.x, y = spawn.y, t = os.clock() },
        facing = "up",
        moving = false,
        fishing = false,
        seat = nil,
        seatedAt = 0,
        cheerUntil = 0,
        heardAt = 0,
        card = describe(player, slot),
    }
    sendRoster()
end

-- [D61] Locul tau se elibereaza (te-ai ridicat, ai plecat, te-ai mutat).
local function freeSeat(player: Player)
    local mark = marks[player]
    local seat = if mark ~= nil then mark.seat else nil
    if mark == nil or seat == nil then
        return
    end
    if occupied[seat] == player then
        occupied[seat] = nil
    end
    mark.seat = nil
end

local function firstStep(player: Player, flag: string)
    local data = DataService.Get(player)
    if data ~= nil and not data.Firsts[flag] then
        data.Firsts[flag] = true
        Analytics.FairStep(player, flag)
    end
end

local function leave(player: Player)
    freeSeat(player)
    local mark = marks[player]
    if mark == nil then
        return
    end
    marks[player] = nil
    bySlot[mark.slot] = nil
    sendRoster()
end

-- Tinuta sau titlul s-au schimbat (sau poate): lista pleaca din nou doar daca e altceva de spus.
function PresenceService.Touch(player: Player)
    local mark = marks[player]
    if mark == nil or deps == nil then
        return
    end
    local card = describe(player, mark.slot)
    if
        card.outfit ~= mark.card.outfit
        or card.title ~= mark.card.title
        or card.name ~= mark.card.name
        or card.gold ~= mark.card.gold
        or not LookMath.same(card.look, mark.card.look)
    then
        mark.card = card
        sendRoster()
    end
end

-- [D61] Unde e omul, dupa ultimul pachet crezut (iazul verifica de aici ca arunci de pe jetiu).
function PresenceService.PositionOf(player: Player): (number?, number?)
    local mark = marks[player]
    if mark == nil then
        return nil, nil
    end
    return mark.sample.x, mark.sample.y
end

-- [D61, partea 2] Serverul te pune undeva (in fata arcadei, cat esti in vizita in satul altcuiva): te ridica de pe loc
-- si urmatorul pachet de pozitie se masoara de aici.
function PresenceService.PlaceAt(player: Player, x: number, y: number)
    local mark = marks[player]
    if mark == nil or not FairLayout.isWalkable(x, y) then
        return
    end
    freeSeat(player)
    mark.sample = { x = x, y = y, t = os.clock() }
    mark.facing = "up"
    mark.moving = false
    mark.fishing = false
end

-- Cartea de vizita a unui om de pe server (numele, tinuta, titlul), pentru cardul lui.
function PresenceService.CardOf(userId: number): Person?
    for _, mark in marks do
        if mark.card.userId == userId then
            return mark.card
        end
    end
    return nil
end

function PresenceService.Init(d: Deps)
    deps = d
    DataService.ProfileLoaded:Connect(arrive)
    Players.PlayerRemoving:Connect(leave)
    for _, player in Players:GetPlayers() do
        if DataService.Get(player) ~= nil then
            arrive(player)
        end
    end
    -- clientul cere lista cand porneste (si o data la cateva secunde, cat nu a primit-o): primeste lista intreaga
    local askedAt: { [Player]: number } = {}
    d.People.OnServerEvent:Connect(function(player: Player)
        local now = os.clock()
        if now - (askedAt[player] or -math.huge) < 1 then
            return
        end
        askedAt[player] = now
        d.People:FireClient(player, roster())
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        askedAt[player] = nil
    end)

    d.Where.OnServerEvent:Connect(
        function(
            player: Player,
            x: unknown,
            y: unknown,
            facing: unknown,
            moving: unknown,
            fishing: unknown
        )
            local mark = marks[player]
            if mark == nil then
                return
            end
            local now = os.clock()
            if now - mark.heardAt < MIN_GAP then
                return
            end
            mark.heardAt = now
            if not FairPresence.isValidFacing(facing) or typeof(moving) ~= "boolean" then
                return
            end
            if fishing ~= nil and typeof(fishing) ~= "boolean" then
                return
            end
            -- [D61] departe de locul pe care stai: te-ai ridicat mergand (sau e un pachet de dinainte de asezare)
            local seat = if mark.seat ~= nil then FairLayout.seatById(mark.seat) else nil
            local offSeat = seat ~= nil
                and typeof(x) == "number"
                and typeof(y) == "number"
                and math.sqrt(((x :: number) - seat.x) ^ 2 + ((y :: number) - seat.y) ^ 2)
                    > SEAT_LEAVE
            if offSeat and now - mark.seatedAt < SEAT_GRACE then
                return
            end
            local speedFactor = d.SpeedFactor
            local factor = if speedFactor ~= nil then speedFactor(player) else 1
            if not FairPresence.accept(mark.sample, x, y, now, factor) then
                return -- un pachet respins nu muta nimic: ramane ultimul bun
            end
            mark.sample = { x = x :: number, y = y :: number, t = now }
            mark.facing = facing :: string
            mark.moving = moving :: boolean
            if offSeat then
                freeSeat(player)
            end
            -- undita se vede doar de pe jetiu: altfel pachetul ar pune pe oricine "sa pescuiasca" in mijlocul balciului
            mark.fishing = fishing == true
                and FairLayout.inRect(
                    FairLayout.CAST_ZONE,
                    x :: number,
                    y :: number,
                    FairLayout.CAST_TOLERANCE
                )
            noteStage(player, x :: number, y :: number)
        end
    )

    -- [D61] Te asezi: locul exista, e liber si esti langa el. Pozitia ta devine a locului (ceilalti te vad acolo).
    -- Clientul s-a asezat deja, ca sa raspunda pe loc; la refuz se ridica si spune de ce.
    d.Sit.OnServerEvent:Connect(function(player: Player, seatId: unknown)
        if not d.Allow(player, "Seat") then
            return
        end
        local mark = marks[player]
        if mark == nil or typeof(seatId) ~= "string" or #(seatId :: string) > 24 then
            return
        end
        local seat = FairLayout.seatById(seatId :: string)
        if seat == nil then
            return
        end
        local holder = occupied[seat.id]
        if holder ~= nil and holder ~= player then
            d.SeatResult:FireClient(player, seat.id, false, "taken")
            return
        end
        local distance = math.sqrt((mark.sample.x - seat.x) ^ 2 + (mark.sample.y - seat.y) ^ 2)
        if distance > FairLayout.SEAT_REACH + SIT_SLACK then
            d.SeatResult:FireClient(player, seat.id, false, "too_far")
            return
        end
        freeSeat(player)
        occupied[seat.id] = player
        mark.seat = seat.id
        mark.seatedAt = os.clock()
        mark.sample = { x = seat.x, y = seat.y, t = mark.seatedAt }
        mark.facing = "down"
        mark.moving = false
        firstStep(player, "FirstSit")
        d.SeatResult:FireClient(player, seat.id, true)
    end)
    d.Stand.OnServerEvent:Connect(function(player: Player)
        if not d.Allow(player, "Seat") then
            return
        end
        freeSeat(player)
    end)
    -- [D61] Faci cu mana: cate o data, 2 secunde; ceilalti te vad in pachetul urmator.
    d.Wave.OnServerEvent:Connect(function(player: Player)
        if not d.Allow(player, "Seat") then
            return
        end
        local mark = marks[player]
        local now = os.clock()
        if mark == nil or now < mark.cheerUntil - 0.1 then
            return
        end
        mark.cheerUntil = now + WAVE_SECONDS
        firstStep(player, "FirstWave")
    end)

    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc < 1 / FairPresence.RATE then
            return
        end
        acc = 0
        local entries: { CrowdCodec.Entry } = {}
        for _, mark in marks do
            table.insert(entries, {
                slot = mark.slot,
                x = mark.sample.x,
                y = mark.sample.y,
                facing = mark.facing,
                moving = mark.moving,
                fishing = mark.fishing,
                sitting = mark.seat ~= nil,
                cheering = os.clock() < mark.cheerUntil,
            })
        end
        if #entries > 0 then
            d.Crowd:FireAllClients(CrowdCodec.encode(entries))
        end
    end)
end

return PresenceService
