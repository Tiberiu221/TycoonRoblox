-- Graful drumurilor [D50]: pe el merg oamenii si curge dara de ghidaj.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local RoadGraph = require("../src/Shared/Modules/RoadGraph")

local function onSomeRoad(p: { x: number, y: number }): boolean
    local rects = { TycoonConfig.DECK }
    for _, r in TycoonConfig.ROADS do
        table.insert(rects, r)
    end
    for _, r in rects do
        if p.x >= r.x0 - 0.5 and p.x <= r.x1 + 0.5 and p.y >= r.y0 - 0.5 and p.y <= r.y1 + 0.5 then
            return true
        end
    end
    return false
end

local function straight(a: { x: number, y: number }, b: { x: number, y: number }): number
    return math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
end

return function()
    test.suite("RoadGraph", function()
        test.case("drumurile din config formeaza un singur graf", function()
            check.is_true(RoadGraph.connected(RoadGraph.fromConfig()))
        end)

        test.case("drumurile care doar se ating se leaga; unul departe rupe graful", function()
            local touching = {
                { x0 = 0, x1 = 400, y0 = 0, y1 = 40 },
                { x0 = 180, x1 = 220, y0 = 40, y1 = 300 }, -- incepe exact pe marginea primului
            }
            check.is_true(RoadGraph.connected(RoadGraph.build(touching)))
            table.insert(touching, { x0 = 600, x1 = 900, y0 = 500, y1 = 540 })
            check.is_false(RoadGraph.connected(RoadGraph.build(touching)))
        end)

        test.case("alege cel mai scurt dintre doua drumuri", function()
            -- un inel cu o scurtatura prin mijloc: din coltul de sus-dreapta pana jos, prin mijloc
            -- sunt 1140 px, pe la stanga 2100 (iar peste iarba 732, deci x2 = 1464: drumul castiga)
            local g = RoadGraph.build({
                { x0 = 0, x1 = 1000, y0 = 0, y1 = 40 },
                { x0 = 0, x1 = 40, y0 = 40, y1 = 600 },
                { x0 = 480, x1 = 520, y0 = 40, y1 = 600 },
                { x0 = 0, x1 = 1000, y0 = 600, y1 = 640 },
            })
            local path = RoadGraph.route(g, { x = 980, y = 20 }, { x = 560, y = 620 })
            check.is_true(math.abs(RoadGraph.length(path) - 1140) < 1e-6)
        end)

        test.case(
            "de la prima plasa la gater: pe drumuri, doar intrarea si iesirea pe iarba",
            function()
                local net = TycoonConfig.byId["first_net"]
                local from = { x = net.x :: number, y = net.y :: number }
                local to = TycoonConfig.SAWMILL_STAND
                local path = RoadGraph.route(RoadGraph.fromConfig(), from, to)
                check.equal(path[1].x, from.x)
                check.equal(path[1].y, from.y)
                check.equal(path[#path].x, to.x)
                check.equal(path[#path].y, to.y)
                for i = 2, #path - 1 do
                    check.is_true(onSomeRoad(path[i]))
                end
                local len = RoadGraph.length(path)
                print(
                    `  plasa -> gater: {math.floor(len)} px pe drum, {math.floor(straight(from, to))} in linie dreapta`
                )
                check.is_true(#path > 2)
                check.is_true(len >= straight(from, to) - 1e-6)
                check.is_true(len <= straight(from, to) * RoadGraph.GRASS_COST)
            end
        )

        test.case("pe acelasi drum, linie dreapta: fara zig-zag pana la linia de mijloc", function()
            -- doua plase vecine de pe punte (200 px) si stalpii lor sunt la 2 px de mijlocul puntii
            local a = TycoonConfig.byId["first_net"]
            local b = TycoonConfig.byId["second_net"]
            local path = RoadGraph.route(
                RoadGraph.fromConfig(),
                { x = a.x :: number, y = a.y :: number },
                { x = b.x :: number, y = b.y :: number }
            )
            check.equal(#path, 2)
        end)

        test.case("cand drumul ar ocoli de doua ori, scurtatura peste iarba", function()
            -- [D57] din mijlocul curtii lemnului la a treia plasa: pe drum (aleea fierului si puntea) ar fi ~780 px
            -- pentru o tinta aflata la 347. Pana in D57 exemplul era spawn -> prima plasa; in satul nou spawn-ul sta
            -- langa aleea tavernei, iar drumul pe alee e chiar cel bun (linia dreapta ar trece prin gramada depozitului).
            local net = TycoonConfig.byId["third_net"]
            local path = RoadGraph.route(
                RoadGraph.fromConfig(),
                { x = 1100, y = 1150 },
                { x = net.x :: number, y = net.y :: number }
            )
            check.equal(#path, 2)
        end)

        test.case("oriunde ai fi pe teren, drumul nu intra in rau", function()
            local g = RoadGraph.fromConfig()
            local targets = {
                TycoonConfig.SAWMILL_STAND,
                TycoonConfig.DOCK,
                TycoonConfig.STORAGE_STAND,
                { x = 620, y = 812 },
            }
            for x = 240, 1840, 160 do
                for y = 880, 1640, 160 do
                    for _, t in targets do
                        for _, p in RoadGraph.route(g, { x = x, y = y }, t) do
                            check.is_true(p.y > RiverConfig.RIVER_BOTTOM)
                        end
                    end
                end
            end
        end)

        test.case("aproape de tinta, linie dreapta; un graf gol nu crapa", function()
            local g = RoadGraph.fromConfig()
            local a = { x = 900, y = 1300 }
            check.equal(#RoadGraph.route(g, a, { x = 1000, y = 1350 }), 2)
            local same = RoadGraph.route(g, a, a)
            check.equal(#same, 2)
            check.equal(RoadGraph.length(same), 0)
            check.equal(#RoadGraph.route(RoadGraph.build({}), a, { x = 2000, y = 1500 }), 2)
        end)
    end)
end
