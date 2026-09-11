--!strict
-- Raul determinist pe seed: serverul publica seed-ul, clientul deriva pozitiile, prinderea se decide aici [DECIZII D13]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RiverSim = require(ReplicatedStorage.Shared.Modules.RiverSim)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)

local BASE_SEED = 12345 -- pasul 1: fix; per oras + sezon la pasul 5 [MASTERPLAN 4.3.3]
local SEASON_EPOCH = 1_757_376_000 -- 2025-09-09T00:00:00Z, ancora sezonului [DECIZII D19] (DE CONFIRMAT la lansare)
-- Mutate din EconomyConfig (sters la pivotul D45): constantele de sezon nu mai au un al doilea
-- consumator, deci nu mai justifica un fisier shared separat.
local SEASON_LENGTH_SECONDS = 28 * 24 * 3600
local SEASONS = { "spring", "summer", "autumn", "winter" }

local DEBUG_ATTR = "DebugSpawnsPerWindow" -- test de performanta: workspace:SetAttribute("DebugSpawnsPerWindow", 800)

local RiverService = {}
local scheduleCache: { [number]: { RiverSim.RiverObject } } = {}
local onConfigChanged: (() -> ())? = nil

local function effectiveConfig(): RiverSim.Config
    local cfg = table.clone(RiverConfig) :: any
    local override = Workspace:GetAttribute(DEBUG_ATTR)
    if typeof(override) == "number" and override >= 1 then
        cfg.SPAWNS_PER_WINDOW = math.floor(override)
    end
    return cfg
end

function RiverService.Init(deps: { OnConfigChanged: (() -> ())? })
    onConfigChanged = deps.OnConfigChanged
    Workspace:GetAttributeChangedSignal(DEBUG_ATTR):Connect(function()
        table.clear(scheduleCache)
        if onConfigChanged ~= nil then
            onConfigChanged()
        end
    end)
end

function RiverService.Now(): number
    return Workspace:GetServerTimeNow()
end

function RiverService.SeasonIndex(unixTime: number): number
    return math.floor((unixTime - SEASON_EPOCH) / SEASON_LENGTH_SECONDS) % #SEASONS
end

function RiverService.Schedule(windowIndex: number): { RiverSim.RiverObject }
    local cached = scheduleCache[windowIndex]
    if cached == nil then
        cached = RiverSim.schedule(BASE_SEED, windowIndex, effectiveConfig())
        scheduleCache[windowIndex] = cached
        scheduleCache[windowIndex - 3] = nil -- ferestrele vechi nu mai pot avea obiecte pe ecran
    end
    return cached
end

function RiverService.ActiveObjects(now: number): { RiverSim.RiverObject }
    local result: { RiverSim.RiverObject } = {}
    for _, windowIndex in RiverSim.activeWindows(now, RiverConfig) do
        for _, obj in RiverService.Schedule(windowIndex) do
            table.insert(result, obj)
        end
    end
    return result
end

function RiverService.GetConfigFor(_player: Player): { [string]: any }
    return {
        seed = BASE_SEED,
        spawnsPerWindow = effectiveConfig().SPAWNS_PER_WINDOW,
        seasonIndex = RiverService.SeasonIndex(os.time()),
        serverTime = RiverService.Now(),
        flowSpeed = 1.0,
    }
end

return RiverService
