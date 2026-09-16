--!strict
-- [D60] Drumul cu barca in amonte: cat tine, cum inainteaza, cand apare Skip si cand se inchide ecranul.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RideMath = require("../src/Shared/Modules/RideMath")

return function()
    test.suite("RideMath", function()
        test.case("drumul incepe la zero si se termina la unu", function()
            check.equal(RideMath.progress(0), 0)
            check.equal(RideMath.progress(RideMath.SECONDS), 1)
            check.equal(RideMath.progress(-3), 0)
            check.equal(RideMath.progress(99), 1)
        end)

        test.case("nu se intoarce niciodata din drum", function()
            local prev = -1
            for i = 0, 60 do
                local p = RideMath.progress(i * RideMath.SECONDS / 60)
                check.is_true(p >= prev - 1e-9)
                prev = p
            end
        end)

        test.case("curentul te tine pe loc la mijloc, deci acolo esti in urma", function()
            local half = RideMath.progress(RideMath.SECONDS / 2)
            check.is_true(half < 0.5)
            check.is_true(half > 0.35)
        end)

        test.case("barca merge in amonte si se leagana pe drum", function()
            local from = { x = 300, y = 640 }
            local start = RideMath.at(0, from)
            local mid = RideMath.at(RideMath.SECONDS / 2, from)
            local finish = RideMath.at(RideMath.SECONDS, from)
            check.equal(start.x, from.x)
            check.is_true(mid.x > start.x and finish.x > mid.x)
            check.is_true(mid.y < from.y) -- cotul spre mijlocul raului
            check.equal(math.floor(finish.y + 0.5), from.y)
        end)

        test.case("Skip apare dupa o clipa, nu din prima", function()
            check.is_false(RideMath.canSkip(0))
            check.is_false(RideMath.canSkip(RideMath.SKIP_AFTER - 0.01))
            check.is_true(RideMath.canSkip(RideMath.SKIP_AFTER))
        end)

        test.case("schimbarea de loc se face pe negru, nu in mijlocul apei", function()
            check.equal(RideMath.fade(0), 0)
            check.equal(RideMath.fade(RideMath.SECONDS - RideMath.FADE), 0)
            check.is_true(RideMath.fade(RideMath.SECONDS - RideMath.FADE / 2) > 0.4)
            check.equal(RideMath.fade(RideMath.SECONDS), 1)
            check.is_true(RideMath.done(RideMath.SECONDS))
            check.is_false(RideMath.done(RideMath.SECONDS - 0.1))
        end)
    end)
end
