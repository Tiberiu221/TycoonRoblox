--!strict
-- Urmareste la ce pas e jucatorul si deschide interfata pe masura ce inainteaza [RIVERKEEP 2].
-- Serverul decide, nu clientul: altfel deblocarile s-ar putea forta din afara, iar progresul
-- nu ar supravietui unei reintrari in joc.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local ObjectiveConfig = require(ReplicatedStorage.Shared.Config.ObjectiveConfig)
local BuildService = require(script.Parent.BuildService)
local DataService = require(script.Parent.DataService)
local SettlerService = require(script.Parent.SettlerService)
local StoreService = require(script.Parent.StoreService)

local TICK_SECONDS = 1

local ObjectiveService = {}
local deps: { Remotes: { [string]: RemoteEvent } }

-- Toti contorii pe care ii pot cere obiectivele, citite din profil sau din starea vie
local function counters(player: Player): { [string]: number }
    local data = DataService.Get(player)
    if data == nil then
        return {}
    end
    local stats = data.Stats
    return {
        netsPlaced = stats.netsPlaced or 0,
        collects = stats.collects or 0,
        scraps = stats.scraps or 0,
        repairs = stats.repairs or 0,
        buildsPlaced = stats.buildsPlaced or 0,
        buildsFinished = stats.buildsFinished or 0,
        jobsAssigned = stats.jobsAssigned or 0,
        settlersArrived = stats.settlersArrived or 0,
        beds = BuildService.Beds(),
        population = SettlerService.Count(),
        food = StoreService.Food(),
        gardens = #BuildService.CompletedOfKind("farm"),
    }
end

local function stateFor(player: Player): { [string]: any }
    local data = DataService.Get(player)
    local index = if data ~= nil then (data.Objectives.index or 1) else 1
    local values = counters(player)
    local step = ObjectiveConfig.stepAt(index)

    local goals = {}
    if step == nil then
        -- lantul s-a terminat: urmeaza telurile lungi, fiecare la treapta lui curenta.
        -- Cel mai aproape de finalizare vine primul: aia e sarcina care se simte la indemana.
        for _, goal in ObjectiveConfig.GOALS do
            local have = values[goal.condition] or 0
            local target = ObjectiveConfig.nextStep(goal, have)
            if target ~= nil then
                table.insert(goals, {
                    id = goal.id,
                    title = string.gsub(goal.title, "{n}", tostring(target)),
                    hint = goal.hint,
                    marker = goal.marker,
                    have = have,
                    target = target,
                    progress = have / math.max(1, target),
                })
            end
        end
        table.sort(goals, function(a, b): boolean
            return a.progress > b.progress
        end)
    end

    -- Cat de avansat e santierul cel mai inaintat. Pasul de constructie asteapta colonistii,
    -- deci fara o bara care se misca jucatorul nu are cum sa stie ca se lucreaza.
    local progress: number? = nil
    -- si "beds": pasul de constructie se masoara acum in paturi, nu in cladiri terminate
    if step ~= nil and (step.condition == "buildsFinished" or step.condition == "beds") then
        local best = 0
        for _, b in BuildService.All() do
            local d = BuildingConfig.get(b.defId)
            if d ~= nil and not BuildService.IsComplete(b) then
                best = math.max(best, b.progress / math.max(1, d.buildWork))
            end
        end
        progress = best
    end

    return {
        index = index,
        total = ObjectiveConfig.count(),
        current = if step ~= nil
            then {
                id = step.id,
                title = step.title,
                hint = step.hint,
                marker = step.marker,
                have = values[step.condition] or 0,
                target = step.target,
                progress = progress,
            }
            else nil,
        goals = goals,
        -- `index`, nu `index - 1`: sistemul cerut de pasul curent trebuie sa fie deja deschis,
        -- altfel jucatorul primeste o sarcina pe care nu are cum sa o duca la capat
        unlocked = ObjectiveConfig.unlockedAfter(index),
    }
end

function ObjectiveService.Send(player: Player)
    local remote = deps.Remotes.ObjectiveState
    if remote ~= nil then
        remote:FireClient(player, stateFor(player))
    end
end

local function advance(player: Player): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    local index = data.Objectives.index or 1
    local step = ObjectiveConfig.stepAt(index)
    if step == nil then
        return false
    end
    local values = counters(player)
    if (values[step.condition] or 0) < step.target then
        return false
    end
    data.Objectives.index = index + 1
    table.insert(data.Objectives.done, step.id)
    local remote = deps.Remotes.ObjectiveDone
    if remote ~= nil then
        remote:FireClient(player, step.id, step.title)
    end
    return true
end

function ObjectiveService.Init(d: typeof(deps))
    deps = d

    if deps.Remotes.RequestObjectives ~= nil then
        deps.Remotes.RequestObjectives.OnServerEvent:Connect(function(player: Player)
            ObjectiveService.Send(player)
        end)
    end

    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil then
            return
        end
        if data.Objectives == nil then
            data.Objectives = { index = 1, done = {} }
        end
        task.defer(ObjectiveService.Send, player)
    end)

    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc < TICK_SECONDS then
            return
        end
        acc = 0
        for _, player in Players:GetPlayers() do
            local changed = false
            -- mai multi pasi pot fi deja indepliniti deodata (de exemplu la reintrare in joc)
            for _ = 1, ObjectiveConfig.count() do
                if not advance(player) then
                    break
                end
                changed = true
            end
            if changed then
                ObjectiveService.Send(player)
            end
        end
    end)
end

return ObjectiveService
