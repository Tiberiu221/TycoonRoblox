local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local NetMotion = require("../src/Shared/Modules/NetMotion")

return function()
    test.suite("NetMotion.sample - leganarea", function()
        test.case("ramane in amplitudinea ei, fara tresarire", function()
            local maxSeen = 0
            for i = 0, 400 do
                local dy, scale = NetMotion.sample(i * 0.05, 0, false, nil)
                maxSeen = math.max(maxSeen, math.abs(dy))
                check.equal(scale, 1) -- fara prindere, plasa nu se umfla deloc
            end
            check.is_true(maxSeen <= NetMotion.BOB_AMP + 1e-9)
            check.is_true(maxSeen > NetMotion.BOB_AMP * 0.99) -- chiar atinge varful
        end)

        test.case("plina: se misca mai putin si mai rar", function()
            local maxEmpty, maxFull = 0, 0
            local crossEmpty, crossFull = 0, 0
            local prevE, prevF = 0, 0
            for i = 1, 800 do
                local t = i * 0.02
                local e = NetMotion.sample(t, 0, false, nil)
                local f = NetMotion.sample(t, 0, true, nil)
                maxEmpty, maxFull = math.max(maxEmpty, math.abs(e)), math.max(maxFull, math.abs(f))
                if (e >= 0) ~= (prevE >= 0) then
                    crossEmpty += 1
                end
                if (f >= 0) ~= (prevF >= 0) then
                    crossFull += 1
                end
                prevE, prevF = e, f
            end
            check.is_true(maxFull < maxEmpty) -- amplitudine mai mica
            check.is_true(crossFull < crossEmpty) -- perioada mai lunga
        end)

        test.case("faze diferite pentru platforme diferite", function()
            local a = NetMotion.phaseFor(1)
            local b = NetMotion.phaseFor(2)
            check.is_true(math.abs(a - b) > 0.1)
            check.equal(a, NetMotion.phaseFor(1)) -- determinist
        end)
    end)

    test.suite("NetMotion.sample - tresarirea", function()
        test.case("inainte si dupa fereastra nu schimba nimic", function()
            local base, baseScale = NetMotion.sample(100, 0, false, nil)
            local before, beforeScale = NetMotion.sample(100, 0, false, 100.5) -- inca n-a prins
            local after, afterScale =
                NetMotion.sample(100, 0, false, 100 - NetMotion.TUG_SECONDS - 0.001)
            check.equal(before, base)
            check.equal(beforeScale, baseScale)
            check.equal(after, base) -- exact 0 dupa fereastra, fara rest
            check.equal(afterScale, 1)
        end)

        test.case("la mijlocul ferestrei trage in jos si umfla", function()
            local t = 50
            local base = NetMotion.sample(t, 0, false, nil)
            local dy, scale = NetMotion.sample(t, 0, false, t - NetMotion.TUG_SECONDS / 2)
            check.is_true(dy > base + 4) -- ~5 px in jos la varf
            check.is_true(scale > 1.06 and scale < 1.08)
        end)

        test.case("chiar la prindere porneste din zero, fara salt", function()
            local t = 7
            local base, baseScale = NetMotion.sample(t, 0, false, nil)
            local dy, scale = NetMotion.sample(t, 0, false, t)
            check.is_true(math.abs(dy - base) < 1e-9)
            check.equal(scale, baseScale)
        end)
    end)
end
