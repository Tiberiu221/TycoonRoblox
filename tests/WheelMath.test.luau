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
        test.case("NICIUN premiu nu ia nimic si fiecare da exact un lucru [P2]", function()
            local TreasureConfig = require("../src/Shared/Config/TreasureConfig")
            local bad = 0
            for _, p in WheelConfig.PRIZES do
                local things = 0
                if p.pearls ~= nil then
                    things += 1
                    bad += if p.pearls > 0 then 0 else 1
                end
                if p.treasure ~= nil then
                    things += 1
                    bad += if TreasureConfig.byId[p.treasure] ~= nil then 0 else 1
                end
                if p.bait ~= nil then
                    things += 1
                    bad += if p.bait > 0 then 0 else 1
                end
                -- nici macar "nimic" nu e premiu: fiecare felie da ceva, si doar un lucru
                bad += if things == 1 and WheelMath.kindOf(p) ~= nil then 0 else 1
            end
            check.equal(bad, 0)
        end)

        test.case("procentele afisate se aduna la 100", function()
            local sum = 0
            for _, p in WheelConfig.PRIZES do
                sum += WheelMath.percentOf(p)
            end
            check.is_true(math.abs(sum - 100) < 1e-9)
        end)

        test.case(
            "[D59] niciun premiu nu da monede: ritmul tutorialului ramane al simulatorului",
            function()
                -- o rotire in primul minut dadea 324 sau 972 de monede, cand tot capitolul 1 costa ~120 [D51]
                for _, p in WheelConfig.PRIZES do
                    check.is_true((p :: any).incomeSeconds == nil and (p :: any).coins == nil)
                end
                check.is_true((WheelMath :: any).coinsOf == nil)
            end
        )

        test.case(
            "[D59] feliile stau intre spitele timonierului: mijlocul fiecareia la (i - 0.5) * 360 / n",
            function()
                local n = #WheelConfig.PRIZES
                check.equal(n, 8) -- desenul (ui_helm) are 8 spite; alt numar de premii cere alt desen
                check.equal(WheelMath.sliceAngle(1), 180 / n)
                check.equal(WheelMath.sliceAngle(n), 360 - 180 / n)
            end
        )
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
