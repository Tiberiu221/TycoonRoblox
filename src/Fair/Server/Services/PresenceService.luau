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

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local PresenceService = {}

export type Person = { slot: number, userId: number, name: string, outfit: string, title: string }
export type Deps = {
    Where: UnreliableRemoteEvent,
    Crowd: UnreliableRemoteEvent,
    People: RemoteEvent,
    -- tinuta si titlul purtat, din profil (VillageService, TitleService)
    Describe: (Player) -> (string, string),
}

type Mark = {
    slot: number,
    sample: FairPresence.Sample,
    facing: string,
    moving: boolean,
    heardAt: number,
    card: Person,
}

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
    local outfit, title = d.Describe(player)
    return {
        slot = slot,
        userId = player.UserId,
        name = player.DisplayName,
        outfit = outfit,
        title = title,
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
        heardAt = 0,
        card = describe(player, slot),
    }
    sendRoster()
end

local function leave(player: Player)
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
    then
        mark.card = card
        sendRoster()
    end
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
        function(player: Player, x: unknown, y: unknown, facing: unknown, moving: unknown)
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
            if not FairPresence.accept(mark.sample, x, y, now) then
                return -- un pachet respins nu muta nimic: ramane ultimul bun
            end
            mark.sample = { x = x :: number, y = y :: number, t = now }
            mark.facing = facing :: string
            mark.moving = moving :: boolean
            noteStage(player, x :: number, y :: number)
        end
    )

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
            })
        end
        if #entries > 0 then
            d.Crowd:FireAllClients(CrowdCodec.encode(entries))
        end
    end)
end

return PresenceService
