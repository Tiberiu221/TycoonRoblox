--!strict
-- Consola de dezvoltare: un singur remote, o comanda pe apel, DOAR in Studio.
-- Poarta e verificata pe SERVER, nu pe client: in productie handler-ul nici nu se conecteaza,
-- deci un pachet trimis de mana nu are ce sa faca. Fiecare comanda intoarce o linie de raspuns,
-- afisata in jurnalul panoului.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildService = require(script.Parent.BuildService)
local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local SettlerService = require(script.Parent.SettlerService)
local ObjectiveConfig = require(ReplicatedStorage.Shared.Config.ObjectiveConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local ObjectiveService = require(script.Parent.ObjectiveService)
local StoreService = require(script.Parent.StoreService)
local StorytellerService = require(script.Parent.StorytellerService)
local WorkshopService = require(script.Parent.WorkshopService)

local DevService = {}
local deps: { Remotes: { [string]: RemoteEvent } }

local function number(value: unknown, fallback: number): number
    if typeof(value) == "number" and math.isfinite(value :: number) then
        return value :: number
    end
    return fallback
end

type Handler = (player: Player, arg: unknown) -> string

local HANDLERS: { [string]: Handler } = {
    materials = function(player: Player, arg: unknown): string
        local delta = math.floor(number(arg, 50))
        local total = WorkshopService.AddMaterials(player, delta)
        WorkshopService.PushState(player)
        return `materials {if delta >= 0 then "+" else ""}{delta} → {total}`
    end,

    pile = function(player: Player, arg: unknown): string
        local n = math.floor(number(arg, 5))
        local added = WorkshopService.AddToPile(player, n, "common")
        WorkshopService.PushState(player)
        return `{added} items dropped in the pile`
    end,

    food = function(_player: Player, arg: unknown): string
        local delta = math.floor(number(arg, 100))
        local moved = StoreService.AddFood(delta)
        return `food {if moved >= 0 then "+" else ""}{moved} → {StoreService.Food()}`
    end,

    finish_sites = function(_player: Player, _arg: unknown): string
        local n = BuildService.FinishAllSites()
        return if n > 0 then `{n} sites finished` else "no sites under construction"
    end,

    reset_buildings = function(_player: Player, _arg: unknown): string
        local n = BuildService.ResetToStarter()
        return `colony reset to {n} starter buildings`
    end,

    settlers = function(_player: Player, arg: unknown): string
        local n = math.floor(number(arg, 12))
        SettlerService.SetCount(n)
        return `settler count set to {SettlerService.Count()}`
    end,

    add_settlers = function(_player: Player, arg: unknown): string
        local n = math.floor(number(arg, 1))
        local joined = SettlerService.Add(n)
        return if joined > 0
            then `{joined} settlers joined`
            else `no free beds ({SettlerService.Count()} people, {BuildService.Beds()} beds)`
    end,

    fill_needs = function(_player: Player, _arg: unknown): string
        SettlerService.FillNeeds()
        return "everyone is fed, rested and content"
    end,

    drain_needs = function(_player: Player, arg: unknown): string
        local to = math.clamp(math.floor(number(arg, 18)), 0, 100)
        SettlerService.DrainNeeds(to)
        return `all needs capped at {to}`
    end,

    timescale = function(_player: Player, arg: unknown): string
        local scale = number(arg, 1)
        DevState.SetTimeScale(scale)
        return `time scale ×{DevState.TimeScale()}`
    end,

    event = function(_player: Player, arg: unknown): string
        local id = if typeof(arg) == "string" then arg :: string else nil
        local entry = StorytellerService.Fire(id)
        if entry == nil then
            return if id ~= nil then `no event named "{id}"` else "nothing is eligible right now"
        end
        return `event: {entry.title}`
    end,

    pause_story = function(_player: Player, arg: unknown): string
        local paused = arg == true or arg == 1
        DevState.SetStorytellerPaused(paused)
        return if paused then "storyteller paused" else "storyteller running"
    end,

    objective = function(player: Player, arg: unknown): string
        local data = DataService.Get(player)
        if data == nil then
            return "no profile"
        end
        local index = math.max(1, math.floor(number(arg, 1)))
        data.Objectives.index = index
        ObjectiveService.Send(player)
        local step = ObjectiveConfig.stepAt(index)
        return if step ~= nil
            then `objective {index}: {step.title}`
            else `objective chain finished ({index})`
    end,

    report = function(player: Player, _arg: unknown): string
        local data = DataService.Get(player)
        local s = SettlerService.Summary()
        local materials = if data ~= nil then data.Materials else 0
        return `{s.count} people · {BuildService.Beds()} beds · {materials} mat · next event in {StorytellerService.SecondsToNext()}s`
    end,
}

-- ADAUGATE dupa ce au aparut Indexul, meseriile cu post de lucru si plecarea cu avertisment:
-- niciuna din comenzile vechi nu le atingea, deci singurul mod de a le verifica era sa joci
-- douazeci de minute. O unealta de dezvoltare care nu acopera ce ai construit ieri nu ajuta.

HANDLERS.index = function(player: Player, arg: unknown): string
    local n = math.floor(number(arg, 9))
    local added = WorkshopService.DevFillIndex(player, n)
    WorkshopService.PushState(player)
    local found, total, frac = WorkshopService.IndexProgress(DataService.Get(player) :: any)
    return `index +{added} → {found}/{total} ({math.floor(frac * 100)}%)`
end

HANDLERS.job = function(_player: Player, arg: unknown): string
    local job = if typeof(arg) == "string" then arg :: string else "Gardener"
    local n = SettlerService.SetAllJobs(job)
    return `{n} people set to {job}`
end

HANDLERS.place = function(player: Player, arg: unknown): string
    local defId = if typeof(arg) == "string" then arg :: string else "garden"
    -- cautam primul loc valid din teren, ca sa nu trebuiasca sa dai si coordonate
    local plot = RiverConfig.PLOT
    for y = plot.y, plot.y + plot.h - RiverConfig.TILE, RiverConfig.TILE do
        for x = plot.x, plot.x + plot.w - RiverConfig.TILE, RiverConfig.TILE do
            local ok = BuildService.CanPlace(defId, x, y)
            if ok then
                local placed = BuildService.Place(player, defId, x, y)
                if placed then
                    BuildService.FinishAllSites()
                    BuildService.SendTo(player)
                    return `{defId} built at {x},{y}`
                end
            end
        end
    end
    return `no free spot for {defId}`
end

HANDLERS.leave = function(_player: Player, _arg: unknown): string
    local name = SettlerService.ForceLeaving()
    if name == nil then
        return "nobody here to send away"
    end
    return `{name} is now seconds from leaving — watch the sign above their head`
end

HANDLERS.arrive = function(_player: Player, _arg: unknown): string
    local before = SettlerService.Count()
    local after = SettlerService.Add(1)
    if after <= before then
        return "no free bed — build one first"
    end
    return `someone arrived · {after} people`
end

function DevService.Run(player: Player, command: string, arg: unknown): string
    local handler = HANDLERS[command]
    if handler == nil then
        return `unknown command: {command}`
    end
    local ok, result = pcall(handler, player, arg)
    if not ok then
        return `error: {result}`
    end
    return result :: string
end

function DevService.Init(d: typeof(deps))
    deps = d
    if not DevState.Enabled() then
        print("[Driftwood] consola de dezvoltare e inactiva in afara Studio")
        return
    end
    local remote = deps.Remotes.DevCommand
    if remote == nil then
        return
    end
    remote.OnServerEvent:Connect(function(player: Player, command: unknown, arg: unknown)
        if typeof(command) ~= "string" or #(command :: string) > 32 then
            return
        end
        local reply = DevService.Run(player, command :: string, arg)
        remote:FireClient(player, command, reply)
    end)
    print(`[Driftwood] consola de dezvoltare activa in Studio ({RunService:IsStudio()})`)
end

return DevService
