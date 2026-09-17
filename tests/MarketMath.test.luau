--!strict
-- [D60] Negustorul: acelasi stoc pentru aceeasi zi, fara repetitii, iar in cateva zile trece prin tot catalogul.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local MarketMath = require("../src/Shared/Modules/MarketMath")
local TitleMath = require("../src/Shared/Modules/TitleMath")
local VillageConfig = require("../src/Shared/Config/VillageConfig")

local function catalog(n: number): { string }
    local out = {}
    for i = 1, n do
        table.insert(out, `item_{i}`)
    end
    return out
end

return function()
    test.suite("MarketMath", function()
        test.case("ziua se schimba la miezul noptii UTC", function()
            check.equal(MarketMath.dayNumber(0), 0)
            check.equal(MarketMath.dayNumber(86399), 0)
            check.equal(MarketMath.dayNumber(86400), 1)
            check.equal(MarketMath.dayNumber(1789344000), 20710)
        end)

        test.case("aceeasi zi, acelasi stoc, pe orice server", function()
            local pool = catalog(16)
            local a = MarketMath.stockFor(20710, pool, MarketMath.STOCK)
            local b = MarketMath.stockFor(20710, pool, MarketMath.STOCK)
            check.equal(table.concat(a, ","), table.concat(b, ","))
        end)

        test.case(
            "cate lucruri se cer, fara repetitii; cu un catalog mic le da pe toate",
            function()
                local pool = catalog(16)
                for day = 20700, 20730 do
                    local stock = MarketMath.stockFor(day, pool, MarketMath.STOCK)
                    check.equal(#stock, MarketMath.STOCK)
                    local seen: { [string]: boolean } = {}
                    for _, item in stock do
                        check.is_true(seen[item] == nil)
                        seen[item] = true
                    end
                end
                local few = MarketMath.stockFor(20710, catalog(3), MarketMath.STOCK)
                check.equal(#few, 3)
                check.equal(#MarketMath.stockFor(20710, {}, MarketMath.STOCK), 0)
            end
        )

        test.case("zilele vecine nu repeta vitrina, iar intr-o luna iese tot catalogul", function()
            local pool = catalog(16)
            local same = 0
            local shown: { [string]: boolean } = {}
            local prev = ""
            for day = 20700, 20730 do
                local stock = MarketMath.stockFor(day, pool, MarketMath.STOCK)
                local key = table.concat(stock, ",")
                if key == prev then
                    same += 1
                end
                prev = key
                for _, item in stock do
                    shown[item] = true
                end
            end
            check.equal(same, 0)
            local missing = {}
            for _, item in pool do
                if not shown[item] then
                    table.insert(missing, item)
                end
            end
            check.equal(table.concat(missing, ", "), "")
        end)

        test.case(
            "catalogul negustorului (MarketService) e de trei ori mai mare decat vitrina, fara nimic gratuit",
            function()
                -- aceeasi alegere ca MarketService.POOL: decorul, tinutele cu pret, titlurile de vanzare
                local keys: { [string]: boolean } = {}
                local count = 0
                local function add(key: string, price: number)
                    check.is_true(keys[key] == nil)
                    check.is_true(price > 0)
                    keys[key] = true
                    count += 1
                end
                for _, d in VillageConfig.DECOR do
                    add(`decor:{d.id}`, d.price)
                end
                for _, o in VillageConfig.OUTFITS do
                    if o.price ~= nil and o.price > 0 then
                        add(`outfit:{o.id}`, o.price)
                    end
                end
                for _, s in TitleMath.FOR_SALE do
                    add(`title:{s.id}`, s.price)
                end
                check.is_true(count >= MarketMath.STOCK * 3)
            end
        )
    end)
end
