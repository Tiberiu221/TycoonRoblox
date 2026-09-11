local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local WorldDecor = require("../src/Shared/Modules/WorldDecor")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

local BOUNDS = {
    width = 2880,
    height = 1920,
    riverTop = 480,
    riverBottom = 768,
    plot = { x = 900, y = 1000, w = 700, h = 500 },
}

return function()
    test.suite("WorldDecor", function()
        test.case("acelasi seed da exact aceeasi lume", function()
            local a = WorldDecor.build(7, BOUNDS, 60)
            local b = WorldDecor.build(7, BOUNDS, 60)
            check.equal(#a, #b)
            for i, item in a do
                check.equal(item.kind, b[i].kind)
                check.equal(item.x, b[i].x)
                check.equal(item.y, b[i].y)
            end
        end)

        test.case("seed-uri diferite dau lumi diferite", function()
            local a = WorldDecor.build(7, BOUNDS, 60)
            local b = WorldDecor.build(8, BOUNDS, 60)
            local same = 0
            for i, item in a do
                if b[i] ~= nil and item.x == b[i].x and item.y == b[i].y then
                    same += 1
                end
            end
            check.is_true(same < #a / 2)
        end)

        test.case("nimic in apa", function()
            for _, item in WorldDecor.build(11, BOUNDS, 120) do
                local inWater = item.y > BOUNDS.riverTop - 40 and item.y < BOUNDS.riverBottom + 40
                check.is_false(inWater)
            end
        end)

        test.case("nimic pe terenul jucatorului", function()
            local plot = BOUNDS.plot
            for _, item in WorldDecor.build(12, BOUNDS, 120) do
                local inPlot = item.x > plot.x - 90
                    and item.x < plot.x + plot.w + 90
                    and item.y > plot.y - 90
                    and item.y < plot.y + plot.h + 90
                check.is_false(inPlot)
            end
        end)

        test.case("obiectele nu se ingramadesc unul peste altul", function()
            local items = WorldDecor.build(13, BOUNDS, 120)
            local tooClose = 0
            for i, a in items do
                for j = i + 1, #items do
                    local b = items[j]
                    local dx, dy = a.x - b.x, a.y - b.y
                    if dx * dx + dy * dy < 100 * 100 then
                        tooClose += 1
                    end
                end
            end
            check.equal(tooClose, 0)
        end)

        test.case("sortate pe adancime: y creste", function()
            local items = WorldDecor.build(14, BOUNDS, 80)
            for i = 2, #items do
                check.is_true(items[i].y >= items[i - 1].y)
            end
        end)

        -- F0 spec 4.6: platformele, plasele si debarcaderul sunt zone fara decor. Plasele sunt
        -- deja acoperite de excluderea raului de mai sus (LANE_Y cade intre RIVER_TOP si
        -- RIVER_BOTTOM); aici se verifica explicit platformele Erei 1 si debarcaderul, cu
        -- geometria REALA din RiverConfig/TycoonConfig, nu cu fixture-ul sintetic BOUNDS.
        test.case("platformele si debarcaderul raman fara copaci si pietre", function()
            local realBounds = {
                width = RiverConfig.WORLD_WIDTH,
                height = RiverConfig.WORLD_HEIGHT,
                riverTop = RiverConfig.RIVER_TOP,
                riverBottom = RiverConfig.RIVER_BOTTOM,
                plot = RiverConfig.PLOT,
            }
            local half = TycoonConfig.PAD_SIZE / 2
            local items = WorldDecor.build(2026091101, realBounds, 220)
            for _, p in TycoonConfig.PADS do
                if p.x == nil or p.y == nil then
                    continue
                end
                local px, py = p.x :: number, p.y :: number
                for _, item in items do
                    local dx, dy = math.abs(item.x - px), math.abs(item.y - py)
                    check.is_false(dx < half and dy < half)
                end
            end
            local dock = TycoonConfig.DOCK
            for _, item in items do
                local dx, dy = math.abs(item.x - dock.x), math.abs(item.y - dock.y)
                check.is_false(dx < half and dy < half)
            end
        end)

        test.case("toate felurile cerute exista in manifest", function()
            local known = {
                cattails = true,
                rock_small = true,
                log = true,
                stump = true,
                tree_round = true,
                tree_pine = true,
                bush = true,
                flowers = true,
            }
            for _, item in WorldDecor.build(15, BOUNDS, 150) do
                check.is_true(known[item.kind] == true)
            end
        end)
    end)
end
