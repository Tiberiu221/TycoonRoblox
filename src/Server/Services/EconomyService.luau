--!strict
-- Moneda jucatorului: singurul loc care schimba Coins, ca sumele sa nu poata scadea din greseala
-- [F0 spec 3.2]. Vanzarea si venitul citesc starea prin PadService (cache-uita, vezi PadService.StateFor).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

type Catch = DataService.Catch

local EconomyService = {}
local deps: { Pads: { StateFor: (Player) -> TycoonMath.State }, PushState: ((Player) -> ())? } = {
    Pads = nil :: any,
    PushState = nil,
}

function EconomyService.GetCoins(player: Player): number
    local data = DataService.Get(player)
    return if data ~= nil then data.Coins else 0
end

-- Singurul loc care aduna la Coins: clamp la 0, ca o scadere programata gresit sa nu duca la minus.
function EconomyService.AddCoins(player: Player, n: number, _reason: string)
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) then
        return
    end
    data.Coins = math.max(0, data.Coins + n)
end

function EconomyService.TrySpend(player: Player, n: number, _reason: string): boolean
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) or n < 0 then
        return false
    end
    if data.Coins < n then
        return false
    end
    data.Coins -= n
    return true
end

function EconomyService.SellMult(player: Player): number
    local state = deps.Pads.StateFor(player)
    return TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
end

function EconomyService.IncomePerSec(player: Player): number
    return TycoonMath.income(deps.Pads.StateFor(player))
end

-- Valoarea totala din sac, formula IDENTICA cu Sell dar fara sa goleasca nimic: e ce arata HUD-ul
-- inainte sa apesi Sell, deci trebuie sa dea exact suma pe care Sell o va plati.
local function sackValue(data: DataService.ProfileData, state: TycoonMath.State): number
    local mult = TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
    local total = 0
    for _, catch: Catch in data.Sack.items do
        total += TycoonMath.itemValue(catch.g, catch.t, state) * mult
    end
    return total
end

function EconomyService.SackSnapshot(
    player: Player
): { count: number, capacity: number, value: number }
    local data = DataService.Get(player)
    local state = deps.Pads.StateFor(player)
    if data == nil then
        return { count = 0, capacity = TycoonMath.sackCapacity(state), value = 0 }
    end
    return {
        count = #data.Sack.items,
        capacity = TycoonMath.sackCapacity(state),
        value = sackValue(data, state),
    }
end

function EconomyService.Sell(player: Player): (boolean, number, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, 0, 0
    end
    local itemCount = #data.Sack.items
    if itemCount == 0 then
        return false, 0, 0
    end
    local state = deps.Pads.StateFor(player)
    local total = sackValue(data, state)
    data.Sack.items = {}
    EconomyService.AddCoins(player, total, "sell")
    data.Stats.sells += 1
    data.Stats.coinsEarned += total
    if not data.Firsts.FirstSell then
        data.Firsts.FirstSell = true
        Analytics.Funnel(player, "FirstSell")
    end
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
    return true, total, itemCount
end

-- UNEALTA DE DEZVOLTARE: umple sacul cu driftwood, ca sa se poata testa "sack full"/vanzarea
-- fara sa astepti raul.
function EconomyService.DevFillSack(player: Player): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local capacity = TycoonMath.sackCapacity(deps.Pads.StateFor(player))
    local added = 0
    while #data.Sack.items < capacity do
        table.insert(data.Sack.items, { g = "driftwood" })
        added += 1
    end
    return added
end

function EconomyService.Init(d: typeof(deps))
    deps = d
end

return EconomyService
