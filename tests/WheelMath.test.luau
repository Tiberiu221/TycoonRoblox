-- Roata schimba o regula a proiectului (D46), deci limitele ei trebuie sa fie verificate, nu
-- presupuse: niciun premiu nu ia nimic, procentele afisate sunt CHIAR cele folosite la tragere,
-- si ceasul de 24h nu se poate ocoli.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local WheelConfig = require("../src/Shared/Config/WheelConfig")
local WheelMath = require("../src/Shared/Modules/WheelMath")

return function()
    test.suite("WheelMath - tragerea", function()
        test.case("orice tragere din [0,1) da un premiu valid", function()
            local bad = 0
            for i = 0, 1000 do
                local prize = WheelMath.pick(i / 1000)
                if WheelConfig.byId[prize.id] == nil then
                    bad += 1
                end
            end
            check.equal(bad, 0)
        end)

        test.case("marginile cad exact pe ponderi", function()
            local total = WheelMath.totalWeight()
            local acc = 0
            for _, p in WheelConfig.PRIZES do
                -- chiar inainte de marginea de sus a feliei trebuie sa fie inca premiul ei
                acc += p.weight
                check.equal(WheelMath.pick((acc - 0.5) / total).id, p.id)
            end
        end)

        test.case("frecventele pe 100.000 de trageri urmeaza ponderile", function()
            local counts: { [string]: number } = {}
            local n = 100000
            for i = 0, n - 1 do
                local id = WheelMath.pick((i + 0.5) / n).id
                counts[id] = (counts[id] or 0) + 1
            end
            local worst = 0
            for _, p in WheelConfig.PRIZES do
                local expected = p.weight / WheelMath.totalWeight()
                local got = (counts[p.id] or 0) / n
                worst = math.max(worst, math.abs(got - expected))
            end
            check.is_true(worst < 0.001)
        end)
    end)

    test.suite("WheelMath - regulile care nu se negociaza", function()
        test.case("NICIUN premiu nu ia nimic [P2]", function()
            local takes = 0
            for _, p in WheelConfig.PRIZES do
                if (p.incomeSeconds or 0) < 0 or (p.pearls or 0) < 0 then
                    takes += 1
                end
                if (p.incomeSeconds or 0) <= 0 and (p.pearls or 0) <= 0 then
                    takes += 1 -- nici macar "nimic" nu e premiu: fiecare felie da ceva
                end
            end
            check.equal(takes, 0)
        end)

        test.case("procentele afisate se aduna la 100", function()
            local sum = 0
            for _, p in WheelConfig.PRIZES do
                sum += WheelMath.percentOf(p)
            end
            check.is_true(math.abs(sum - 100) < 1e-9)
        end)

        test.case("premiile in monede au o podea, ca sa nu fie o gluma la inceput", function()
            local prize = WheelConfig.byId.coins_s
            check.equal(WheelMath.coinsOf(prize, 0.1), WheelConfig.MIN_COINS)
            check.is_true(WheelMath.coinsOf(prize, 100) > WheelConfig.MIN_COINS)
        end)

        test.case("un premiu in perle nu da monede, si invers", function()
            check.equal(WheelMath.coinsOf(WheelConfig.byId.pearl_3, 1000), 0)
            check.is_true(WheelConfig.byId.coins_s.pearls == nil)
        end)
    end)

    test.suite("WheelMath - ceasul de 24h", function()
        test.case("prima rotire e mereu gata", function()
            check.is_true(WheelMath.ready(1000, 0))
            check.equal(WheelMath.secondsLeft(1000, 0), 0)
        end)

        test.case("imediat dupa o rotire nu se mai poate", function()
            check.is_false(WheelMath.ready(1000, 1000))
            check.equal(WheelMath.secondsLeft(1000, 1000), WheelConfig.COOLDOWN)
        end)

        test.case("exact la 24h redevine gata", function()
            check.is_true(WheelMath.ready(1000 + WheelConfig.COOLDOWN, 1000))
        end)

        test.case("un ceas dat inapoi nu deschide rotirea", function()
            check.is_false(WheelMath.ready(500, 1000))
        end)
    end)
end
