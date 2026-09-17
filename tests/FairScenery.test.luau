--!strict
-- [D60] Ce se aseaza peste fundalul copt al balciului (FairScenery, generat de scripts/art/d60_ground.py): padurea nu
-- intra pe poiana, in apa sau peste obiecte, luminile sunt numere adevarate, fundalul acopera toata harta.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Assets = require("../src/Shared/Config/Assets")
local FairLayout = require("../src/Shared/Modules/FairLayout")
local FairScenery = require("../src/Shared/Config/FairScenery")

local function spotBoxes(): { { id: string, box: FairLayout.Rect } }
    local out = {}
    for _, spot in FairLayout.SPOTS do
        local art = (Assets.fair :: any)[spot.sprite]
        table.insert(out, { id = spot.id, box = FairLayout.boxOf(spot, art.width, art.height) })
    end
    return out
end

return function()
    test.suite("FairScenery", function()
        test.case("fundalul copt acopera toata harta si are marimea desenului", function()
            local g, size = FairScenery.GROUND, FairLayout.SIZE
            check.is_true(g.x <= 0 and g.y <= 0)
            check.is_true(g.x + g.w >= size.w and g.y + g.h >= size.h)
            check.equal(Assets.fair.ground.width * Assets.PIXEL_SCALE, g.w)
            check.equal(Assets.fair.ground.height * Assets.PIXEL_SCALE, g.h)
            -- Roblox nu primeste imagini mai mari de 1024 pe latura
            check.is_true(Assets.fair.ground.width <= 1024 and Assets.fair.ground.height <= 1024)
        end)

        test.case("padurea sta pe margini: nu pe poiana, nu in apa, nu peste obiecte", function()
            local bad = {}
            local boxes = spotBoxes()
            local f, p = FairLayout.FLOOR, FairLayout.POND
            for i, tree in FairScenery.TREES do
                local art = (Assets.props :: any)[tree.sprite]
                check.not_nil(art)
                local q = ((tree.x - f.x) / f.rx) ^ 2 + ((tree.y - f.y) / f.ry) ^ 2
                if q < 1.2 then
                    table.insert(bad, `copac {i} pe poiana`)
                end
                if FairLayout.inPond(tree.x, tree.y) or tree.y >= FairLayout.WATER_Y then
                    table.insert(bad, `copac {i} in apa`)
                end
                local w, h = art.width * Assets.PIXEL_SCALE * 0.7, art.height * Assets.PIXEL_SCALE
                local b = { x0 = tree.x - w / 2, x1 = tree.x + w / 2, y0 = tree.y - h, y1 = tree.y }
                for _, other in boxes do
                    if FairLayout.overlap(b, other.box) then
                        table.insert(bad, `copac {i} peste {other.id}`)
                    end
                end
                for j = i + 1, #FairScenery.TREES do
                    local o = FairScenery.TREES[j]
                    if math.sqrt((tree.x - o.x) ^ 2 + (tree.y - o.y) ^ 2) < 60 then
                        table.insert(bad, `copacii {i} si {j} unul in altul`)
                    end
                end
            end
            check.equal(table.concat(bad, ", "), "")
            check.is_true(#FairScenery.TREES >= 60)
            -- drumul de la debarcader in poiana ramane liber
            local s = FairLayout.SPAWN
            for _, tree in FairScenery.TREES do
                check.is_false(math.abs(tree.x - s.x) < 150 and tree.y > s.y - 240)
            end
        end)

        test.case("luminile, focurile si ghirlandele sunt pe harta, cu numere adevarate", function()
            local size = FairLayout.SIZE
            local function inside(x: number, y: number): boolean
                return x >= 0 and x <= size.w and y >= 0 and y <= size.h
            end
            for _, light in FairScenery.LIGHTS do
                check.is_true(math.isfinite(light.x) and math.isfinite(light.y))
                check.is_true(light.r > 0 and light.strength > 0 and light.strength <= 1)
                check.is_true(inside(light.x, light.y))
            end
            check.is_true(#FairScenery.FIRES >= 1)
            for _, fire in FairScenery.FIRES do
                check.is_true(inside(fire.x, fire.y) and fire.size > 0 and fire.sparks >= 0)
            end
            for _, garland in FairScenery.GARLANDS do
                check.is_true(#garland.bulbs >= 2)
                for _, bulb in garland.bulbs do
                    check.is_true(inside(bulb.x, bulb.y))
                    check.equal(#bulb.color, 3)
                end
            end
            check.equal(#FairScenery.LAMPS, 5)
        end)
    end)
end
