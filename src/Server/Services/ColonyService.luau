--!strict
-- Tabloul coloniei: o singura poza cu tot ce trebuie sa stie administratorul [RIVERKEEP 5].
-- Se trimite periodic, nu la fiecare schimbare: panoul e informativ, nu are nevoie de precizie
-- de cadru, iar un push la fiecare modificare de nevoie ar insemna zeci de pachete pe secunda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local FoodBalance = require(ReplicatedStorage.Shared.Modules.FoodBalance)
local BuildService = require(script.Parent.BuildService)
local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local SettlerService = require(script.Parent.SettlerService)
local StoreService = require(script.Parent.StoreService)
local StorytellerService = require(script.Parent.StorytellerService)

local PUSH_SECONDS = 2

local ColonyService = {}
local deps: { Remotes: { [string]: RemoteEvent } }

-- Panoul arata 5 intrari; trimiterea intregului jurnal la fiecare 2 secunde ar fi risipa.
local LOG_SENT = 6

local function recentLog(): { any }
    local full = StorytellerService.Log()
    local out = {}
    for i = 1, math.min(LOG_SENT, #full) do
        table.insert(out, full[i])
    end
    return out
end

function ColonyService.Snapshot(player: Player): { [string]: any }
    local data = DataService.Get(player)
    local summary = SettlerService.Summary()
    local done, sites = 0, 0
    local byKind: { [string]: number } = {}
    for _, b in BuildService.All() do
        local d = BuildingConfig.get(b.defId)
        if d == nil then
            continue
        end
        if BuildService.IsComplete(b) then
            done += 1
            byKind[d.kind] = (byKind[d.kind] or 0) + 1
        else
            sites += 1
        end
    end
    -- cate locuri de gradina exista efectiv: gradinarii fara gradina nu produc nimic
    local gardenSlots = 0
    for _, b in BuildService.CompletedOfKind("farm") do
        gardenSlots += b.slots or 0
    end
    local production = FoodBalance.productionPerMinute(
        summary.byJob.Fisher or 0,
        summary.byJob.Gardener or 0,
        gardenSlots
    )
    local consumption = FoodBalance.consumptionPerMinute(summary.count)

    local pile = 0
    if data ~= nil then
        for _ in data.Pile do
            pile += 1
        end
    end
    return {
        population = summary.count,
        beds = BuildService.Beds(),
        byJob = summary.byJob,
        averages = summary.averages,
        unhappy = summary.unhappy,
        materials = if data ~= nil then data.Materials else 0,
        food = StoreService.Food(),
        foodCap = StoreService.Cap(),
        hungry = SettlerService.Hungry(),
        foodIn = production,
        foodOut = consumption,
        supported = FoodBalance.supportedPopulation(production),
        pile = pile,
        buildingsDone = done,
        buildingSites = sites,
        byKind = byKind,
        nextEvent = StorytellerService.SecondsToNext(),
        timeScale = DevState.TimeScale(),
        log = recentLog(),
    }
end

local function push(player: Player)
    local remote = deps.Remotes.ColonyStats
    if remote ~= nil then
        remote:FireClient(player, ColonyService.Snapshot(player))
    end
end

function ColonyService.Init(d: typeof(deps))
    deps = d

    if deps.Remotes.RequestColony ~= nil then
        deps.Remotes.RequestColony.OnServerEvent:Connect(function(player: Player)
            push(player)
        end)
    end

    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc < PUSH_SECONDS then
            return
        end
        acc = 0
        for _, player in Players:GetPlayers() do
            push(player)
        end
    end)
end

return ColonyService
