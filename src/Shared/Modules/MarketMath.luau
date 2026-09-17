--!strict
-- [D60] NEGUSTORUL BALCIULUI: ce scoate in fata azi. Modul pur: ziua din ceas si stocul zilei -- acelasi pentru toata
-- lumea si pe toate serverele, fara nimic salvat, pentru ca samanta e chiar ziua.
--
-- Stocul e doar VITRINA zilei: tot catalogul ramane de cumparat, iar cumpararea trece prin validatorii obisnuiti
-- (VillageService, TitleService). Nimic nu devine "de necumparat azi" [D46: orice se cumpara].
local Prng = require(script and script.Parent.Prng or "./Prng")

local MarketMath = {}

MarketMath.DAY = 86400
MarketMath.STOCK = 4 -- cate lucruri scoate negustorul in fata

-- Ziua, din ceasul serverului (UTC): se schimba la miezul noptii UTC, aceeasi pe toate serverele.
function MarketMath.dayNumber(now: number): number
    return math.floor(now / MarketMath.DAY)
end

-- `count` lucruri din `pool`, fara repetitii, aceleasi pentru aceeasi zi. Cu un pool mai mic, le da pe toate.
function MarketMath.stockFor<T>(day: number, pool: { T }, count: number): { T }
    local order: { number } = {}
    for i = 1, #pool do
        order[i] = i
    end
    -- zilele vecine nu au voie sa dea acelasi stoc doar pentru ca samantele lor sunt vecine
    local rng = Prng.new((day * 7919 + 104729) % 2147483647)
    for i = #order, 2, -1 do
        local j = rng:nextInteger(1, i)
        order[i], order[j] = order[j], order[i]
    end
    local out: { T } = {}
    for i = 1, math.min(count, #order) do
        table.insert(out, pool[order[i]])
    end
    return out
end

return MarketMath
