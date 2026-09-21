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
                -- [D65] doar platformele care se deseneaza: ale Erei 2 au deja locul lor, dar cartierul Morii primeste
                -- terenul lui fara decor (RiverConfig.PLOT) odata cu harta (docs/PLAN-ERA2.md); cand devin `live`,
                -- testul asta le pazeste si pe ele.
                if p.x == nil or p.y == nil or not p.live then
                    continue
                end
                local px, py = p.x :: number, p.y :: number
                for _, item in items do
                    local dx, dy = math.abs(item.x - px), math.abs(item.y - py)
                    check.is_false(dx < half and dy < half)
                end
            end
            -- taverna, prinsa de baza [D50]
            local tavern = TycoonConfig.TAVERN
            for _, item in items do
                check.is_false(
                    math.abs(item.x - tavern.x) < tavern.w / 2
                        and item.y > tavern.y - tavern.h
                        and item.y < tavern.y
                )
            end
        end)

        -- [F3 spec item 1] Malul construit: pontonul si drumurile sunt zone fara decor, la fel de
        -- explicit ca platformele si taverna de mai sus -- ca un copac sau o piatra sa nu mai poata
        -- aparea niciodata pe scandurile pontonului sau pe drum [D50].
        test.case("pontonul si drumurile raman fara copaci si pietre", function()
            local realBounds = {
                width = RiverConfig.WORLD_WIDTH,
                height = RiverConfig.WORLD_HEIGHT,
                riverTop = RiverConfig.RIVER_TOP,
                riverBottom = RiverConfig.RIVER_BOTTOM,
                plot = RiverConfig.PLOT,
            }
            local items = WorldDecor.build(2026091101, realBounds, 220)
            local function inRect(
                x: number,
                y: number,
                r: { x0: number, x1: number, y0: number, y1: number }
            ): boolean
                return x >= r.x0 and x <= r.x1 and y >= r.y0 and y <= r.y1
            end
            for _, item in items do
                check.is_false(inRect(item.x, item.y, TycoonConfig.DECK))
                for _, road in TycoonConfig.ROADS do
                    check.is_false(inRect(item.x, item.y, road))
                end
            end
        end)

        test.case("[D65] niciun copac nu acopera casa unui om sau numele ei", function()
            -- vazut de owner la Moara (2026-09-21): trei copaci cu baza chiar sub randul de case le acopereau numele
            local Assets = require("../src/Shared/Config/Assets")
            local function village(clear: { WorldDecor.Clear }?): { WorldDecor.Item }
                return WorldDecor.village(20260910, 130, {
                    width = RiverConfig.WORLD_WIDTH,
                    height = RiverConfig.WORLD_HEIGHT,
                    oldWidth = RiverConfig.ERA1_WORLD_WIDTH,
                }, {
                    riverTop = RiverConfig.SHORE_FAR.baseY - RiverConfig.SHORE_FAR.amp,
                    riverBottom = RiverConfig.SHORE_NEAR.baseY + RiverConfig.SHORE_NEAR.amp,
                }, RiverConfig.PLOT, RiverConfig.PLOT_ERA1, clear)
            end
            local clear = TycoonConfig.homeClearRects()
            check.equal(#clear, 9) -- casele celor noua meserii ale Morii (satul vechi ramane cum a fost vazut)
            local items = village(clear)
            for _, item in items do
                local size = WorldDecor.FOOTPRINT[item.kind]
                check.is_true(size ~= nil)
                for _, c in clear do
                    local over = item.y > c.frontOf
                        and item.x - size[1] / 2 < c.x1
                        and item.x + size[1] / 2 > c.x0
                        and item.y - size[2] < c.y1
                        and item.y > c.y0
                    check.is_false(over)
                end
            end
            -- satul vechi ramane EXACT cum era: regula noua nu scoate nimic din ce stiu deja jucatorii
            local function landing(list: { WorldDecor.Item }): { string }
                local out: { string } = {}
                for _, item in list do
                    if item.x < TycoonConfig.ZONES[1].x1 then
                        table.insert(out, `{item.kind}:{item.x}:{item.y}`)
                    end
                end
                return out
            end
            local before, after = landing(village(nil)), landing(items)
            check.equal(#after, #before)
            for i, key in before do
                check.equal(after[i], key)
            end
            -- iar ceva chiar s-a scos la Moara (altfel testul n-ar pazi nimic)
            check.is_true(#items < #village(nil))
            -- cifrele din FOOTPRINT sunt chiar desenele din Assets, la scara lumii
            for kind, size in WorldDecor.FOOTPRINT do
                local sprite = (Assets.props :: any)[kind]
                check.is_true(sprite ~= nil)
                check.equal(size[1], sprite.width * Assets.PIXEL_SCALE)
                check.equal(size[2], sprite.height * Assets.PIXEL_SCALE)
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
