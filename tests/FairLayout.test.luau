--!strict
-- [D60] Asezarea bâlciului: nimic nu intra in altceva, totul e pe harta, iar locul unde acostezi e liber.
-- Testul asta e chiar verificarea care a prins suprapunerile pe macheta (felinare in scena, roata in iaz).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FairLayout = require("../src/Shared/Modules/FairLayout")
local Assets = require("../src/Shared/Config/Assets")

local function pairKey(a: string, b: string): string
    return if a < b then `{a}_{b}` else `{b}_{a}`
end

return function()
    test.suite("FairLayout", function()
        test.case("fiecare obiect are desenul lui in Assets.fair", function()
            local missing = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                if art == nil or art.width == nil then
                    table.insert(missing, `{spot.id} ({spot.sprite})`)
                elseif not Assets.has(art) then
                    table.insert(missing, `{spot.id}: desen neurcat`)
                end
            end
            check.equal(table.concat(missing, ", "), "")
        end)

        test.case("id-urile sunt unice", function()
            local seen: { [string]: boolean } = {}
            local twice = {}
            for _, spot in FairLayout.SPOTS do
                if seen[spot.id] then
                    table.insert(twice, spot.id)
                end
                seen[spot.id] = true
            end
            check.equal(table.concat(twice, ", "), "")
        end)

        test.case("nimic nu intra in altceva, in afara perechilor care au voie", function()
            local boxes: { { id: string, box: FairLayout.Rect } } = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                table.insert(
                    boxes,
                    { id = spot.id, box = FairLayout.boxOf(spot, art.width, art.height) }
                )
            end
            local clashes = {}
            for i = 1, #boxes do
                for j = i + 1, #boxes do
                    local a, b = boxes[i], boxes[j]
                    if
                        FairLayout.overlap(a.box, b.box)
                        and not (FairLayout.TOUCHING :: any)[pairKey(a.id, b.id)]
                    then
                        table.insert(clashes, `{a.id} x {b.id}`)
                    end
                end
            end
            check.equal(table.concat(clashes, ", "), "")
        end)

        test.case("totul sta pe harta, iar apa ramane a barcii", function()
            local outside, onWater = {}, {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                local box = FairLayout.boxOf(spot, art.width, art.height)
                if
                    box.x0 < 0
                    or box.x1 > FairLayout.SIZE.w
                    or box.y0 < 0
                    or box.y1 > FairLayout.SIZE.h
                then
                    table.insert(outside, spot.id)
                end
                -- doar debarcaderul si barca au voie sa atinga raul de jos
                if box.y1 > FairLayout.WATER_Y and spot.id ~= "dock" and spot.id ~= "ferry" then
                    table.insert(onWater, spot.id)
                end
            end
            check.equal(table.concat(outside, ", "), "")
            check.equal(table.concat(onWater, ", "), "")
        end)

        test.case("acostezi pe un loc liber, de unde se ajunge la vatra", function()
            local spawn = FairLayout.SPAWN
            local blocked = {}
            for _, spot in FairLayout.SPOTS do
                local art = (Assets.fair :: any)[spot.sprite]
                local box = FairLayout.boxOf(spot, art.width, art.height)
                if
                    spawn.x > box.x0 - 24
                    and spawn.x < box.x1 + 24
                    and spawn.y > box.y0 - 24
                    and spawn.y < box.y1 + 24
                then
                    table.insert(blocked, spot.id)
                end
            end
            check.equal(table.concat(blocked, ", "), "")
            check.is_false(FairLayout.onFloor(spawn.x, spawn.y)) -- acostezi pe iarba, apoi urci in poiana
            check.is_true(FairLayout.onFloor(FairLayout.CENTER.x, FairLayout.CENTER.y))
        end)

        test.case("fiecare margine are eticheta ei si un loc pe harta", function()
            local seen: { [string]: boolean } = {}
            local bad = {}
            for _, edge in FairLayout.EDGES do
                if seen[edge.id] or edge.label == "" then
                    table.insert(bad, edge.id)
                end
                seen[edge.id] = true
                if
                    edge.x < 0
                    or edge.x > FairLayout.SIZE.w
                    or edge.y < 0
                    or edge.y > FairLayout.SIZE.h
                then
                    table.insert(bad, `{edge.id} (in afara hartii)`)
                end
            end
            check.equal(table.concat(bad, ", "), "")
            check.equal(#FairLayout.EDGES, 8)
        end)
    end)
end
