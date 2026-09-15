--!strict
-- [D59] CE ADUCE RAUL, pe server. Regulile sunt in TreasureMath (pur, testat); aici doar ceasul (os.time: merge si cat
-- lipsesti), profilul, perlele si vestile catre client. Nimic nu se hotaraste pe client [D13].
--
-- Vestile, ca nimic sa nu se intample in tacere [D43]:
--   * sosit cat esti in joc -> OnArrived (clientul il face sa pluteasca pana la ponton, cu un toast);
--   * sosit cat ai lipsit -> numarul ajunge pe ecranul de bun venit (SettleOffline, chemat de StationService);
--   * deschis la undita -> rezultatul il trimite FishService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)
local TreasureMath = require(ReplicatedStorage.Shared.Modules.TreasureMath)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local TreasureService = {}
local deps: {
    PushState: ((Player) -> ())?,
    OnArrived: ((Player, string, number) -> ())?, -- (jucator, fel, locul la ponton 1..3)
} =
    { PushState = nil, OnArrived = nil }

local TICK_SECONDS = 1
-- Cine si-a primit deja socoteala de la incarcare: ce a venit cat a lipsit se numara o singura data, pentru bun venit.
local settled: { [Player]: boolean } = {}

local function riverOf(data: any): TreasureMath.State
    if typeof(data.River) ~= "table" then
        data.River = { started = false, waiting = {}, nextAt = 0, seed = 0, total = 0, notes = 0 }
    end
    local river = data.River
    if typeof(river.waiting) ~= "table" then
        river.waiting = {}
    end
    return river
end

local function push(player: Player)
    local pushState = deps.PushState
    if pushState ~= nil then
        pushState(player)
    end
end

-- `notes` = cate bilete ai citit, `found` = cate lucruri ai scos din rau (jurnalul)
export type Snapshot = { waiting: { string }, started: boolean, notes: number, found: number }

function TreasureService.Snapshot(player: Player): Snapshot
    local data = DataService.Get(player)
    if data == nil then
        return { waiting = {}, started = false, notes = 0, found = 0 }
    end
    local river = riverOf(data)
    return {
        waiting = table.clone(river.waiting),
        started = river.started,
        notes = river.notes or 0,
        found = data.Stats.treasures or 0,
    }
end

-- Felul primului lucru care te asteapta la ponton (pe el il agata urmatoarea aruncare), sau nil.
function TreasureService.FirstWaiting(player: Player): string?
    local data = DataService.Get(player)
    if data == nil then
        return nil
    end
    return riverOf(data).waiting[1]
end

-- La primul peste: raul incepe sa aduca. Primul vine la FIRST_DELAY si e o sticla.
function TreasureService.StartRiver(player: Player)
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    local river = riverOf(data)
    if river.seed == 0 then
        river.seed = (player.UserId * 3266489917 + os.time()) % 4294967296
    end
    TreasureMath.start(river, os.time())
end

-- Ce a venit cat ai lipsit, la incarcarea profilului. Intoarce cate au sosit; a doua oara pe sesiune, 0.
function TreasureService.SettleOffline(player: Player): number
    if settled[player] then
        return 0
    end
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    settled[player] = true
    return #TreasureMath.advance(riverOf(data), os.time())
end

-- Deschide primul lucru de la ponton (l-a scos undita). Intoarce (fel, perle, biletul) sau nil daca nu mai era nimic.
function TreasureService.Open(player: Player): (string?, number, number?)
    local data = DataService.Get(player)
    if data == nil then
        return nil, 0, nil
    end
    local river = riverOf(data)
    -- INTAI se scoate de la ponton, apoi se plateste: doua scoateri in acelasi cadru n-ar putea plati acelasi lucru.
    local kind = TreasureMath.take(river, os.time())
    local def = if kind ~= nil then TreasureConfig.byId[kind] else nil
    if kind == nil or def == nil then
        return nil, 0, nil
    end
    EconomyService.AddPearls(player, def.pearls, "treasure")
    data.Stats.treasures = (data.Stats.treasures or 0) + 1
    local note: number? = nil
    if kind == "bottle" then
        note = TreasureMath.nextNote(river)
    end
    if not data.Firsts.FirstTreasure then
        data.Firsts.FirstTreasure = true
        Analytics.PierStep(player, "FirstTreasure")
    end
    return kind, def.pearls, note
end

-- Un dar al roatii care vine la ponton. False = pontonul e plin (roata il plateste in perle).
function TreasureService.Grant(player: Player, kind: string): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    local river = riverOf(data)
    local ok = TreasureMath.grant(river, kind)
    if ok then
        local onArrived = deps.OnArrived
        if onArrived ~= nil then
            onArrived(player, kind, #river.waiting)
        end
    end
    return ok
end

-- [dev] un lucru adus acum, ca sa se poata incerca fara sa astepti minute
function TreasureService.DevArrive(player: Player, kind: string): boolean
    return TreasureService.Grant(player, kind)
end

function TreasureService.Init(d: typeof(deps))
    deps = d
    DataService.ProfileLoaded:Connect(function(player: Player)
        TreasureService.SettleOffline(player)
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        settled[player] = nil
    end)
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc < TICK_SECONDS then
            return
        end
        acc = 0
        local now = os.time()
        for _, player in Players:GetPlayers() do
            local data = DataService.Get(player)
            if data == nil or not settled[player] then
                continue
            end
            local river = riverOf(data)
            local arrived = TreasureMath.advance(river, now)
            if #arrived == 0 then
                continue
            end
            local onArrived = deps.OnArrived
            local slot = #river.waiting - #arrived
            for _, kind in arrived do
                slot += 1
                if onArrived ~= nil then
                    onArrived(player, kind, slot)
                end
            end
            push(player)
        end
    end)
end

return TreasureService
