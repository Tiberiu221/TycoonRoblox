--!strict
-- Platformele: cumparare, statusuri (bought/available/outline), starea tycoon cache-uita per
-- jucator [F0 spec 3.3]. StateFor e cel mai apelat lucru din tot server-ul (income, sell, net
-- interval) -- de-aici cache-ul, invalidat doar cand se schimba `Pads`/`Rebirths`/`Index`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RiverService = require(script.Parent.RiverService)
local Analytics = require(script.Parent.Analytics)

local PadService = {}
local deps: { PushState: ((Player) -> ())? } = { PushState = nil }
local cache: { [Player]: TycoonMath.State } = {}

-- Rata/banda plasei acestei platforme, daca are una. Aceeasi oglinda mica exista si in
-- NetService: e date pure pe `Pad.effects`, nu merita un modul doar pentru atat.
local function netEffectOf(pad: TycoonConfig.Pad): (number?, number?)
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate, e.lane
        end
    end
    return nil, nil
end

local function indexCount(data: DataService.ProfileData): number
    local n = 0
    for _ in data.Index do
        n += 1
    end
    return n
end

function PadService.Invalidate(player: Player)
    cache[player] = nil
end

function PadService.StateFor(player: Player): TycoonMath.State
    local cached = cache[player]
    if cached ~= nil then
        return cached
    end
    local data = DataService.Get(player)
    if data == nil then
        return TycoonMath.newState(0, 0)
    end
    -- live=true: Indexul REAL (indexCount) inlocuieste proxy-ul din efectele platformelor
    -- (Workshop, Sorting Shed) -- niciuna live in F0, dar regula trebuie sa fie corecta oricum.
    local state = TycoonMath.stateFor(data.Pads, data.Rebirths, indexCount(data), true)
    cache[player] = state
    return state
end

function PadService.Statuses(player: Player): { [string]: string }
    local data = DataService.Get(player)
    if data == nil then
        return {}
    end
    return TycoonMath.padStatuses(data.Pads)
end

local function pushState(player: Player)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
end

-- Marcheaza platforma cumparata si creeaza plasa daca are efect de plasa. Comuna intre Buy
-- (plateste) si DevGrant (unealta de dezvoltare, gratuit) -- restul logicii nu are voie sa se
-- dezalinieze intre ele.
local function grant(player: Player, data: DataService.ProfileData, pad: TycoonConfig.Pad)
    data.Pads[pad.id] = true
    data.Stats.padsBought += 1
    PadService.Invalidate(player)
    local rate = netEffectOf(pad)
    if rate ~= nil then
        local state = PadService.StateFor(player)
        data.Nets[pad.id] = {
            goods = {},
            nextCatchAt = RiverService.Now() + TycoonMath.netInterval(rate, state),
            caught = 0,
        }
    end
end

function PadService.Buy(player: Player, padId: string): (boolean, string?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local pad = TycoonConfig.byId[padId]
    if pad == nil then
        return false, "locked"
    end
    if data.Pads[padId] then
        return false, "owned"
    end
    if PadService.Statuses(player)[padId] ~= "available" then
        return false, "locked"
    end
    if not EconomyService.TrySpend(player, pad.price, `buy_{padId}`) then
        return false, "coins"
    end
    grant(player, data, pad)
    -- Firs-urile funnel-ului nou: doar cele trei momente de cumparare cerute [F0 spec 3.7].
    if padId == "first_net" and not data.Firsts.BoughtFirstNet then
        data.Firsts.BoughtFirstNet = true
        Analytics.Funnel(player, "BoughtFirstNet")
    end
    if padId == "second_net" and not data.Firsts.BoughtSecondNet then
        data.Firsts.BoughtSecondNet = true
        Analytics.Funnel(player, "BoughtSecondNet")
    end
    if pad.index == 5 and not data.Firsts.BoughtPad5 then
        data.Firsts.BoughtPad5 = true
        Analytics.Funnel(player, "BoughtPad5")
    end
    pushState(player)
    return true, nil
end

-- UNEALTA DE DEZVOLTARE (buyto): acorda o platforma gratis. Fara analytics -- nu e o cumparare reala.
function PadService.DevGrant(player: Player, padId: string): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    local pad = TycoonConfig.byId[padId]
    if pad == nil or data.Pads[padId] then
        return false
    end
    grant(player, data, pad)
    pushState(player)
    return true
end

Players.PlayerRemoving:Connect(function(player: Player)
    cache[player] = nil
end)

function PadService.Init(d: typeof(deps))
    deps = d
    DataService.ProfileLoaded:Connect(function(player: Player)
        PadService.Invalidate(player)
    end)
end

return PadService
