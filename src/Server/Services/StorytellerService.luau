--!strict
-- Povestitorul: la intervale neregulate se intampla ceva in colonie [RIVERKEEP 6].
-- Regula fixa a proiectului: NICIUN dezastru natural. Niciun eveniment nu distruge o cladire,
-- nu omoara pe nimeni si nu poate duce colonia intr-o stare din care nu se mai iese.
-- Alegerea ponderata sta in modulul pur Shared/Modules/Storyteller (testat cu Lune);
-- aici raman doar efectele si anuntul.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local Storyteller = require(ReplicatedStorage.Shared.Modules.Storyteller)
local BuildService = require(script.Parent.BuildService)
local DataService = require(script.Parent.DataService)
local DevState = require(script.Parent.DevState)
local SettlerService = require(script.Parent.SettlerService)
local StoreService = require(script.Parent.StoreService)
local WorkshopService = require(script.Parent.WorkshopService)

export type LogEntry = {
    id: string,
    title: string,
    body: string,
    tone: string,
    detail: string,
    at: number,
}

local StorytellerService = {}
local deps: { Remotes: { [string]: RemoteEvent } }
local rng = Prng.new(20260911)
local log: { LogEntry } = {}
local nextAt = 0

local function owner(): (Player?, DataService.ProfileData?)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data ~= nil then
            return player, data
        end
    end
    return nil, nil
end

-- Ce conditii sunt indeplinite acum. Numele sunt cele din `requires` in EventConfig.
local function conditions(): Storyteller.Conditions
    local count = SettlerService.Count()
    local firepit = #BuildService.CompletedOfKind("joy") > 0
    return {
        beds = count < BuildService.Beds(),
        settlers = count > 0,
        firepit = firepit,
    }
end

-- Aplica efectul si intoarce o linie scurta cu ce s-a schimbat efectiv (nu ce s-ar fi vrut).
local function applyEffect(e: EventConfig.Event): string
    local player, data = owner()
    local effect = e.effect
    local parts: { string } = {}

    if effect.materials ~= nil and player ~= nil and data ~= nil then
        local before = data.Materials
        local after = WorkshopService.AddMaterials(player, effect.materials)
        local delta = after - before
        if delta ~= 0 then
            table.insert(parts, if delta > 0 then `+{delta} materials` else `{delta} materials`)
        end
        WorkshopService.PushState(player)
    end

    if effect.food ~= nil then
        local moved = StoreService.AddFood(effect.food)
        if moved ~= 0 then
            table.insert(parts, if moved > 0 then `+{moved} food` else `{moved} food`)
        end
    end

    if effect.pileItems ~= nil and player ~= nil then
        local added = WorkshopService.AddToPile(player, effect.pileItems, "common")
        if added > 0 then
            table.insert(parts, `+{added} to the pile`)
        end
        WorkshopService.PushState(player)
    end

    if effect.need ~= nil and effect.needDelta ~= nil then
        local touched = SettlerService.BoostNeed(effect.need, effect.needDelta)
        if touched > 0 then
            local sign = if effect.needDelta > 0 then "+" else ""
            table.insert(parts, `{sign}{effect.needDelta} {effect.need} for {touched}`)
        end
    end

    if effect.settlers ~= nil then
        local joined = SettlerService.Add(effect.settlers)
        if joined > 0 then
            table.insert(parts, `{joined} joined`)
        else
            table.insert(parts, "no free beds, they moved on")
        end
    end

    if effect.rerollJob then
        local name, job = SettlerService.RerollRandomJob()
        if name ~= nil and job ~= nil then
            table.insert(parts, `{name} is now a {string.lower(job)}`)
        end
    end

    return table.concat(parts, " · ")
end

local function broadcast(entry: LogEntry)
    local remote = deps.Remotes.ColonyEvent
    if remote ~= nil then
        remote:FireAllClients(entry)
    end
end

-- Declanseaza un eveniment anume (unealta de dezvoltare) sau unul ales ponderat (mersul normal).
function StorytellerService.Fire(forcedId: string?): LogEntry?
    local chosen: EventConfig.Event?
    if forcedId ~= nil then
        chosen = EventConfig.get(forcedId)
    else
        chosen = Storyteller.pick(
            EventConfig.EVENTS,
            conditions(),
            Storyteller.recentIds(log, EventConfig.REPEAT_GAP),
            rng:nextNumber()
        )
    end
    if chosen == nil then
        return nil
    end
    local entry: LogEntry = {
        id = chosen.id,
        title = chosen.title,
        body = chosen.body,
        tone = chosen.tone,
        detail = applyEffect(chosen),
        at = os.time(),
    }
    Storyteller.pushLog(log :: any, entry, EventConfig.LOG_SIZE)
    broadcast(entry)
    return entry
end

function StorytellerService.Log(): { LogEntry }
    return log
end

-- Cand vine urmatorul eveniment, in secunde. Tabloul coloniei il arata ca numaratoare inversa.
function StorytellerService.SecondsToNext(): number
    return math.max(0, math.round(nextAt - Workspace:GetServerTimeNow()))
end

local function schedule()
    local span = EventConfig.MAX_SECONDS - EventConfig.MIN_SECONDS
    local wait = EventConfig.MIN_SECONDS + rng:nextNumber() * span
    nextAt = Workspace:GetServerTimeNow() + wait / DevState.TimeScale()
end

function StorytellerService.Init(d: typeof(deps))
    deps = d
    schedule()

    RunService.Heartbeat:Connect(function()
        if DevState.StorytellerPaused() or #Players:GetPlayers() == 0 then
            return
        end
        if Workspace:GetServerTimeNow() < nextAt then
            return
        end
        schedule()
        -- un eveniment care crapa nu are voie sa opreasca Heartbeat-ul pentru tot serverul
        local ok, err = pcall(StorytellerService.Fire, nil)
        if not ok then
            warn(`[Driftwood] povestitorul a esuat: {err}`)
        end
    end)
end

return StorytellerService
