--!strict
-- [D63] Cifrele din coltul HUD-ului stau pe o grila: un bloc drept, fara suprapuneri, care incape pe telefon.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local HudLayout = require("../src/Shared/Modules/HudLayout")

local function overlap(a: HudLayout.Rect, b: HudLayout.Rect): boolean
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

return function()
    test.suite("HudLayout", function()
        test.case(
            "randul de sus: aceeasi linie de sus si aceeasi inaltime la monede, perle si sac",
            function()
                local r = HudLayout.rects()
                for _, key in { "pearl", "sack" } do
                    check.equal(r[key].y, r.coin.y)
                    check.equal(r[key].h, r.coin.h)
                end
                check.equal(r.rate.y, r.away.y)
                check.equal(r.rate.h, r.away.h)
            end
        )

        test.case(
            "un bloc drept: toate randurile au aceeasi latime si aceeasi margine din stanga",
            function()
                for _, withStep in { false, true } do
                    local r = HudLayout.rects(withStep)
                    local left, right = r.coin.x, r.sack.x + r.sack.w
                    check.equal(right - left, HudLayout.width())
                    check.equal(r.rate.x, left)
                    check.equal(r.away.x + r.away.w, right)
                    check.equal(r.objective.x, left)
                    check.equal(r.objective.x + r.objective.w, right)
                    -- rata sta exact sub monede, AWAY exact sub perle si sac
                    check.equal(r.rate.w, r.coin.w)
                    check.equal(r.away.x, r.pearl.x)
                end
            end
        )

        test.case("nimic nu se calca, iar intre randuri e acelasi spatiu", function()
            local r = HudLayout.rects(true)
            local keys = { "coin", "pearl", "sack", "rate", "away", "objective" }
            for i = 1, #keys do
                for j = i + 1, #keys do
                    check.is_false(overlap(r[keys[i]], r[keys[j]]))
                end
            end
            check.equal(r.rate.y - (r.coin.y + r.coin.h), HudLayout.ROW_GAP)
            check.equal(r.objective.y - (r.rate.y + r.rate.h), HudLayout.ROW_GAP)
        end)

        test.case(
            "pe telefon blocul lasa loc lumii: sub 40% din latime si sub 30% din inaltime",
            function()
                -- iPhone XR culcat: 896x414, iar panza HUD e viewport / 0,62 (podeaua de scara din bootstrap)
                local canvasW, canvasH = 896 / 0.62, 414 / 0.62
                local r = HudLayout.rects(true)
                check.is_true(r.objective.x + r.objective.w < canvasW * 0.4)
                check.is_true(r.objective.y + r.objective.h < canvasH * 0.3)
            end
        )
    end)
end
