--!strict
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local GlanceMath = require("../src/Shared/Modules/GlanceMath")

local function near(a: number?, b: number): boolean
    return a ~= nil and math.abs(a - b) < 1e-6
end

return function()
    test.suite("GlanceMath [D70, Look (V)]", function()
        test.case("pleaca de unde e camera, sta pe loc, se intoarce la om", function()
            local g = GlanceMath.start(4000, 900, 1100, 1300, 10)
            local go = g.goSeconds
            local x, y = GlanceMath.point(g, 10, 4200, 950)
            check.is_true(near(x, 4000) and near(y, 900)) -- primul cadru: exact camera de dinainte
            x, y = GlanceMath.point(g, 10 + go, 4200, 950)
            check.is_true(near(x, 1100) and near(y, 1300))
            x, y = GlanceMath.point(g, 10 + go + GlanceMath.HOLD * 0.5, 4200, 950)
            check.is_true(near(x, 1100) and near(y, 1300))
            -- intoarcerea merge la om, oriunde a ajuns intre timp
            x, y = GlanceMath.point(g, 10 + go + GlanceMath.HOLD + go * 0.999, 4300, 960)
            check.is_true(
                x ~= nil
                    and math.abs((x :: number) - 4300) < 5
                    and math.abs((y :: number) - 960) < 5
            )
            check.equal(
                (GlanceMath.point(g, 10 + go + GlanceMath.HOLD + go + 0.01, 4300, 960)),
                nil
            )
        end)

        test.case("drumul tine dupa lungime, intre MIN si MAX", function()
            check.equal(GlanceMath.seconds(0), GlanceMath.MIN_SECONDS)
            check.equal(GlanceMath.seconds(1e6), GlanceMath.MAX_SECONDS)
            check.is_true(GlanceMath.seconds(3000) > GlanceMath.seconds(500))
            -- peste toata harta (~3500 px) camera nu trece mai repede de ~60 px pe cadru (viteza de varf 1,5 d / T)
            check.is_true(1.5 * 3500 / GlanceMath.seconds(3500) / 60 < 60)
        end)

        test.case("anularea porneste din punctul de acum, fara salt", function()
            local g = GlanceMath.start(4000, 900, 1100, 1300, 0)
            for _, t in { 0.1, 0.5, g.goSeconds + 1, g.goSeconds + GlanceMath.HOLD + 0.3 } do
                local bx, by = GlanceMath.point(g, t, 4000, 900)
                local c = GlanceMath.cancel(g, t, 4000, 900)
                local ax, ay = GlanceMath.point(c, t, 4000, 900)
                check.is_true(near(ax, bx :: number) and near(ay, by :: number))
                -- si ajunge la om
                check.equal((GlanceMath.point(c, t + c.backSeconds + 0.01, 4000, 900)), nil)
            end
            -- pe drumul de intoarcere, anularea nu reia drumul din repaus (camera s-ar opri brusc)
            local back = g.goSeconds + GlanceMath.HOLD + 0.2
            check.equal(GlanceMath.cancel(g, back, 4000, 900), g)
            -- o a doua anulare nu schimba nimic; o privire terminata ramane terminata
            local c = GlanceMath.cancel(g, 0.5, 4000, 900)
            check.equal(GlanceMath.cancel(c, 0.6, 4000, 900), c)
            local done = 100
            check.equal(GlanceMath.cancel(g, done, 4000, 900), g)
        end)

        test.case("o privire noua din mijlocul alteia pleaca din punctul de acum", function()
            local g = GlanceMath.start(4000, 900, 1100, 1300, 0)
            local t = g.goSeconds * 0.5
            local mx, my = GlanceMath.point(g, t, 4000, 900)
            local g2 = GlanceMath.start(mx :: number, my :: number, 1270, 1480, t)
            local x, y = GlanceMath.point(g2, t, 4000, 900)
            check.is_true(near(x, mx :: number) and near(y, my :: number))
        end)
    end)
end
