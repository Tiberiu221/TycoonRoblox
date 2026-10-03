-- [D70, pasul j7] ASEZAREA LUMII 2 (barajul), din TycoonConfig: aceleasi reguli ca testele de asezare ale satului
-- (TycoonConfig.test), cu care a fost verificata planseta aprobata in D74 (scripts/art/preview_dam_layout.py). Nimic nu se
-- calca, nimic construit nu sta pe drum sau pe apa canalului, plasele stau pe punte, locurile de predare langa drum,
-- clientii orasului in oglinda tavernei, felinarele dupa regula strazii, numele de sub case nu se ating, drumurile fac
-- un singur graf, iar oamenii isi lasa marfa cu fata spre gramada.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local Assets = require("../src/Shared/Config/Assets")
local RoadGraph = require("../src/Shared/Modules/RoadGraph")
local HandRoutes = require("../src/Shared/Modules/HandRoutes")
local WorldMap = require("../src/Shared/Modules/WorldMap")
local DriftMath = require("../src/Shared/Modules/DriftMath")
local CatchFloat = require("../src/Shared/Modules/CatchFloat")
local RiverSim = require("../src/Shared/Modules/RiverSim")
local StationConfig = require("../src/Shared/Config/StationConfig")

type Rect = { x0: number, x1: number, y0: number, y1: number }
type Point = { x: number, y: number }

local W = 2
local PAD = TycoonConfig.PAD_SIZE
local HALF = PAD / 2
local EM, TINY = 572 / 1024, 13 -- fontul de pixeli (CLAUDE.md), marimea numelui de sub casa

local function hit(a: Rect, b: Rect): boolean
    return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end
local function box(cx: number, bottom: number, w: number, h: number): Rect
    return { x0 = cx - w / 2, x1 = cx + w / 2, y0 = bottom - h, y1 = bottom }
end
local function corner(b: TycoonConfig.Box): Rect
    return { x0 = b.x, x1 = b.x + b.w, y0 = b.y, y1 = b.y + b.h }
end
local function gap(p: Point, r: Rect): number
    local dx = math.max(r.x0 - p.x, 0, p.x - r.x1)
    local dy = math.max(r.y0 - p.y, 0, p.y - r.y1)
    return math.sqrt(dx * dx + dy * dy)
end

local function isNet(p: TycoonConfig.Pad): boolean
    for _, e in p.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

-- amprenta cladirii de pe o platforma (ca in TycoonConfig.test: taraba, magazie, atelier mare, clopot, casa)
local function footprint(p: TycoonConfig.Pad): { number }?
    if isNet(p) then
        return nil
    elseif p.id == "hire_dispatcher" then
        return { 128, 80 }
    elseif TycoonConfig.CREW_OF_PAD[p.id] ~= nil then
        return { 120, 102 }
    elseif p.motive == "D" then
        return { 120, 168 }
    elseif p.id == "crystal_shed" then
        return { 120, 96 }
    end
    return { 192, 144 }
end

local world = TycoonConfig.WORLDS[W]
local lines = TycoonConfig.linePlacesOf(W)
local joins = TycoonConfig.joinPlacesOf(W)
local sellers = TycoonConfig.sellerPlacesOf(W)

local function roads(): { TycoonConfig.Road }
    local out = {}
    for _, d in TycoonConfig.districtsOf(W) do
        for _, r in d.roads do
            table.insert(out, r)
        end
    end
    return out
end
local function decks(): { Rect }
    local out = {}
    for _, d in TycoonConfig.districtsOf(W) do
        table.insert(out, d.deck)
    end
    return out
end

-- tot ce sta pe teren, cu marimea reala
local function placed(): { [string]: Rect }
    local things: { [string]: Rect } = {}
    for name, b in world.buildings :: { [string]: TycoonConfig.Box } do
        things[name] = box(b.x, b.y, b.w, b.h)
    end
    for i, c in world.cottages :: { TycoonConfig.Box } do
        things[`cottage_{i}`] = box(c.x, c.y, c.w, c.h)
    end
    for _, p in TycoonConfig.padsOfWorld(W) do
        local size = footprint(p)
        if size ~= nil then
            things[`building_{p.id}`] =
                box(p.x :: number, TycoonConfig.buildingBase(p), size[1], size[2])
        end
    end
    local function person(name: string, at: Point)
        things[name] = box(at.x, at.y, 48, 72)
    end
    local function pile(name: string, at: Point)
        things[`pile_{name}`] = { x0 = at.x - 40, x1 = at.x + 40, y0 = at.y - 56 - 26, y1 = at.y }
    end
    for line, pl in lines do
        person(`{line}.worker`, pl.workerStand)
        person(`{line}.second`, { x = pl.workerStand.x + pl.secondOffset.x, y = pl.workerStand.y })
        pile(`{line}.store`, pl.storePile)
        pile(`{line}.in`, pl.inPile)
        pile(`{line}.out`, pl.outPile)
    end
    for line, j in joins do
        person(`{line}.worker`, j.workerStand)
        person(`{line}.second`, { x = j.workerStand.x + j.secondOffset.x, y = j.workerStand.y })
        for part, at in j.inPiles do
            pile(`{line}.in.{part}`, at)
        end
        pile(`{line}.out`, j.outPile)
    end
    for seller, sp in sellers do
        person(`{seller}.stand`, sp.stand)
        person(`{seller}.second`, { x = sp.stand.x + sp.secondOffset.x, y = sp.stand.y })
        pile(seller, sp.pile)
    end
    for i, b in world.blocked :: { TycoonConfig.Box } do
        if b.x > (world.wall :: TycoonConfig.Box).x + (world.wall :: TycoonConfig.Box).w then
            things[`canal_water_{i}`] = corner(b) -- nimic construit (si nici oameni) pe apa canalului
        end
    end
    local spawn = TycoonConfig.spawnOf(W)
    things.spawn = box(spawn.x, spawn.y, 48, 72)
    for _, p in world.pylons :: { TycoonConfig.Pylon } do
        if not p.overRoad then
            things[p.name] = box(p.x, p.y, p.w, p.h)
        end
    end
    -- [D74] pontonul, roata si avizierul raman pe coordonatele satului, pe puntea lacului
    local post = Assets.props.signpost
    things.wheel =
        box(TycoonConfig.WHEEL_STAND.x, TycoonConfig.WHEEL_STAND.y, post.width * 2, post.height * 2)
    things.board = box(TycoonConfig.VILLAGE_BOARD.x, TycoonConfig.VILLAGE_BOARD.y, 80, 88)
    return things
end

local function sortedNames(things: { [string]: any }): { string }
    local names = {}
    for name in things do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

return function()
    test.suite("World2Layout [D70, pasul j7]", function()
        test.case("lumea 2 are datele ei, iar platformele barajului au loc in ea", function()
            check.equal(world.width, 3385)
            check.equal(RiverConfig.WORLDS[W].WORLD_WIDTH, world.width)
            check.equal(#TycoonConfig.districtsOf(W), 2)
            for _, p in TycoonConfig.padsOfWorld(W) do
                check.not_nil(p.x)
                check.not_nil(p.y)
                check.is_false(p.live) -- adormite pana la l3
            end
            -- zona barajului fara gard, ceata Erei 5 dupa ea, pana la capatul lumii
            local zones = TycoonConfig.zonesOf(W)
            check.equal(zones[1].fence, false)
            check.equal(zones[#zones].x1, world.width)
        end)

        test.case(
            "platformele nu se ating, iar tot ce sta pe teren nu se calca si sta in zona",
            function()
                local pads = TycoonConfig.padsOfWorld(W)
                local bad = {}
                for i = 1, #pads do
                    for j = i + 1, #pads do
                        local a, b = pads[i], pads[j]
                        if
                            math.abs((a.x :: number) - (b.x :: number)) < PAD
                            and math.abs((a.y :: number) - (b.y :: number)) < PAD
                        then
                            table.insert(bad, `pad {a.id} x {b.id}`)
                        end
                    end
                end
                local things = placed()
                local names = sortedNames(things)
                for i = 1, #names do
                    for j = i + 1, #names do
                        if hit(things[names[i]], things[names[j]]) then
                            table.insert(bad, `{names[i]} x {names[j]}`)
                        end
                    end
                end
                for _, p in pads do
                    local px, py = p.x :: number, p.y :: number
                    local pb = { x0 = px - HALF, x1 = px + HALF, y0 = py - HALF, y1 = py + HALF }
                    for _, n in names do
                        if n ~= `building_{p.id}` and hit(things[n], pb) then
                            table.insert(bad, `{n} x pad {p.id}`)
                        end
                    end
                end
                local zone = TycoonConfig.zonesOf(W)[1]
                local bottom = RiverConfig.WORLDS[W].PLOT.y + RiverConfig.WORLDS[W].PLOT.h
                for _, n in names do
                    local b = things[n]
                    if b.x0 < zone.x0 or b.x1 > zone.x1 or b.y1 > bottom then
                        table.insert(bad, `in afara terenului: {n}`)
                    end
                end
                for _, b in bad do
                    print("  ! " .. b)
                end
                check.equal(#bad, 0)
            end
        )

        test.case("nimic construit pe drum; plasele pe punte; predarea langa drum", function()
            local things = placed()
            local rs = roads()
            local bad = {}
            -- doar cladirile, casutele, apa si stalpii: oamenii si gramezile au voie pe marginea drumului
            for name, b in things do
                local built = string.sub(name, 1, 5) ~= "pile_"
                    and string.find(name, ".", 1, true) == nil
                    and string.sub(name, 1, 9) ~= "building_"
                if built then
                    for _, r in rs do
                        if hit(b, r) then
                            table.insert(bad, `pe drum: {name} x {r.id}`)
                        end
                    end
                end
            end
            for _, p in TycoonConfig.padsOfWorld(W) do
                local px, py = p.x :: number, p.y :: number
                if isNet(p) then
                    local onDeck = false
                    for _, d in decks() do
                        onDeck = onDeck or (px >= d.x0 and px <= d.x1 and py >= d.y0 and py <= d.y1)
                    end
                    if not onDeck then
                        table.insert(bad, `plasa {p.id} nu e pe punte`)
                    end
                else
                    local pb = { x0 = px - HALF, x1 = px + HALF, y0 = py - HALF, y1 = py + HALF }
                    for _, r in rs do
                        if hit(pb, r) then
                            table.insert(bad, `pe drum: pad {p.id} x {r.id}`)
                        end
                    end
                end
            end
            local stands: { { name: string, at: Point } } = {}
            for line, pl in lines do
                for _, k in { "storeStand", "playerStand", "processorIn", "processorOut" } do
                    table.insert(stands, { name = `{line}.{k}`, at = (pl :: any)[k] })
                end
            end
            for line, j in joins do
                for part, at in j.inputIn do
                    table.insert(stands, { name = `{line}.in.{part}`, at = at })
                end
                table.insert(stands, { name = `{line}.playerStand`, at = j.playerStand })
                table.insert(stands, { name = `{line}.processorOut`, at = j.processorOut })
            end
            for seller, sp in sellers do
                table.insert(stands, { name = `{seller}.door`, at = sp.door })
            end
            for _, s in stands do
                local best = math.huge
                for _, r in rs do
                    best = math.min(best, gap(s.at, r))
                end
                for _, d in decks() do
                    best = math.min(best, gap(s.at, d))
                end
                if best > 60 then
                    table.insert(bad, `{s.name} la {math.floor(best)} px de drum (max 60)`)
                end
            end
            for _, b in bad do
                print("  ! " .. b)
            end
            check.equal(#bad, 0)
        end)

        test.case(
            "felinarele lumii 2 sunt cele date de regula strazii, cu 72 px de orice casa",
            function()
                -- regula streetLamps: la mijlocul dintre doua case vecine de pe randul y 1564, sarind unde lucreaza un om
                local xs = {}
                for _, p in TycoonConfig.padsOfWorld(W) do
                    if TycoonConfig.CREW_OF_PAD[p.id] ~= nil and p.y == 1564 then
                        table.insert(xs, p.x :: number)
                    end
                end
                table.sort(xs)
                local places: {
                    {
                        workerStand: Point,
                        secondOffset: Point,
                        processorIn: Point,
                        processorOut: Point,
                    }
                } =
                    {}
                for _, pl in lines do
                    table.insert(places, pl)
                end
                for _, j in joins do
                    for _, at in j.inputIn do
                        table.insert(places, {
                            workerStand = j.workerStand,
                            secondOffset = j.secondOffset,
                            processorIn = at,
                            processorOut = j.processorOut,
                        })
                    end
                end
                local want = {}
                for i = 1, #xs - 1 do
                    local x = (xs[i] + xs[i + 1]) / 2
                    local blocked = false
                    for _, place in places do
                        local w = place.workerStand
                        for _, spot in
                            {
                                w,
                                { x = w.x + place.secondOffset.x, y = w.y + place.secondOffset.y },
                            }
                        do
                            if
                                x - 15 < spot.x + 20
                                and spot.x - 20 < x + 15
                                and 1372 < spot.y
                                and spot.y - 60 < 1414
                            then
                                blocked = true
                            end
                        end
                        local pin, pout = place.processorIn, place.processorOut
                        if
                            (
                                x - 15 < pin.x + 73
                                and pin.x - 20 < x + 15
                                and 1372 < pin.y
                                and pin.y - 60 < 1414
                            )
                            or (
                                x - 15 < pout.x + 20
                                and pout.x - 73 < x + 15
                                and 1372 < pout.y
                                and pout.y - 60 < 1414
                            )
                        then
                            blocked = true
                        end
                    end
                    if not blocked then
                        table.insert(want, x)
                        for _, hx in xs do
                            check.is_true(math.abs(x - hx) >= 72)
                        end
                    end
                end
                local have = {}
                for _, lamp in TycoonConfig.streetLamps(W) do
                    table.insert(have, lamp.x)
                    check.equal(lamp.y, TycoonConfig.LAMP_BASE_Y)
                    check.equal(lamp.era, 4)
                end
                check.equal(table.concat(have, ","), table.concat(want, ","))
                check.equal(#have, 6)
            end
        )

        test.case("numele de sub case nu se ating; drumurile fac un singur graf", function()
            local labels = {}
            for _, p in TycoonConfig.padsOfWorld(W) do
                local role = TycoonConfig.CREW_OF_PAD[p.id]
                if role ~= nil then
                    local half = #TycoonConfig.CREWS[role].name * EM * TINY / 2 + 2
                    local x, y = p.x :: number, p.y :: number
                    table.insert(labels, {
                        id = p.id,
                        r = {
                            x0 = x - half,
                            x1 = x + half,
                            y0 = y + 56,
                            y1 = y + 58 + TINY * 1.03 + 2,
                        },
                    })
                end
            end
            for i = 1, #labels do
                for j = i + 1, #labels do
                    if hit(labels[i].r, labels[j].r) then
                        print(`  ! etichetele {labels[i].id} si {labels[j].id} se ating`)
                    end
                    check.is_false(hit(labels[i].r, labels[j].r))
                end
            end
            local rects: { Rect } = {}
            for _, d in decks() do
                table.insert(rects, d)
            end
            for _, r in roads() do
                table.insert(rects, { x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 })
            end
            check.is_true(RoadGraph.connected(RoadGraph.build(rects)))
        end)

        test.case(
            "oamenii lasa marfa cu fata spre gramada; orasul are clientii tavernei",
            function()
                for _, pl in lines do
                    check.is_true(pl.storePile.x > pl.storeStand.x)
                    check.is_true(pl.inPile.x > pl.processorIn.x)
                    check.is_true(pl.outPile.x < pl.processorOut.x)
                end
                local grid = joins.grid
                check.is_true(grid.outPile.x < grid.processorOut.x)
                local town = sellers.town
                check.is_true(town.pile.x < town.door.x)
                local dock = TycoonConfig.SELLER_PLACES.dock
                local dx = town.door.x - dock.door.x
                check.equal(town.customerEntry.x, dock.customerEntry.x + dx)
                for i, spot in town.customerSpots do
                    check.equal(spot.x, dock.customerSpots[i].x + dx)
                    check.equal(spot.y, dock.customerSpots[i].y)
                end
            end
        )
    end)

    -- [D70, pasul j8] drumurile pe lume: graful barajului e al lui, oamenii lui merg pe el, nu prin apa
    test.suite("World2Roads [D70, pasul j8]", function()
        local DAM_NETS =
            { "dam_turbine", "cable_net", "second_cable_net", "third_cable_net", "crystal_net" }

        local function wet(x: number, y: number): boolean
            if y <= RiverConfig.WORLDS[W].RIVER_BOTTOM then
                return true -- raul si lacul
            end
            for _, b in world.blocked :: { TycoonConfig.Box } do
                if x > b.x and x < b.x + b.w and y > b.y and y < b.y + b.h then
                    return true -- zidul si canalul
                end
            end
            return false
        end

        test.case("un graf pe lume: al barajului e conex si nu e al satului", function()
            local g2 = RoadGraph.forWorld(2)
            check.is_true(RoadGraph.connected(g2))
            check.is_true(RoadGraph.forWorld(1) == RoadGraph.fromConfig())
            check.is_true(g2 ~= RoadGraph.fromConfig())
            check.is_true(HandRoutes.forWorld(1) == HandRoutes.GAME)
            check.is_true(HandRoutes.forWorld(2).roads == g2)
            check.equal(HandRoutes.worldOfRole("collector"), 1)
            check.equal(HandRoutes.worldOfRole("damCollector"), 2)
            check.is_true(HandRoutes.forRole("relayKeeper") == HandRoutes.forWorld(2))
        end)

        test.case(
            "oamenii barajului merg pe drumuri, nu prin apa, in timpi ca ai satului",
            function()
                local ctx = HandRoutes.forWorld(W)
                -- cat tine cel mai scurt si cel mai lung ciclu din sat (toate plasele, cate un om)
                local nets1 = {}
                for _, p in TycoonConfig.padsOfWorld(1) do
                    if isNet(p) then
                        table.insert(nets1, p.id)
                    end
                end
                local shortest, longest = math.huge, 0
                for _, role in StationConfig.ROLES do
                    local c = HandRoutes.cycleFor(role, 1, 1, nets1)
                    if c.duration > 0 then
                        shortest = math.min(shortest, c.duration)
                        longest = math.max(longest, c.duration)
                    end
                end
                local walked, dmin, dmax = 0, math.huge, 0
                for _, role in StationConfig.ERA4_ROLES do
                    for _, pair in { { 1, 1 }, { 1, 2 }, { 2, 2 } } do
                        local c = HandRoutes.cycleFor(role, pair[1], pair[2], DAM_NETS, ctx)
                        if c.duration > 0 then
                            walked += 1
                            dmin, dmax = math.min(dmin, c.duration), math.max(dmax, c.duration)
                            check.is_true(c.duration >= shortest - 0.1 and c.duration <= longest)
                            for _, leg in c.legs do
                                if leg.kind == "walk" then
                                    for k = 0, 40 do
                                        local x = leg.from.x + (leg.to.x - leg.from.x) * k / 40
                                        local y = leg.from.y + (leg.to.y - leg.from.y) * k / 40
                                        if wet(x, y) then
                                            print(
                                                `  ! {role} {pair[1]}/{pair[2]} trece prin apa la ({x}, {y})`
                                            )
                                        end
                                        check.is_false(wet(x, y))
                                    end
                                end
                            end
                        end
                    end
                end
                -- zece meserii care merg (3 la butoaie, 3 la cablu, Pylon Runner-ul, 3 la cristal), cate trei cazuri
                check.equal(walked, 30)
                check.equal(math.floor(dmin * 10 + 0.5) / 10, 4.5)
                check.equal(math.floor(dmax * 10 + 0.5) / 10, 19.4)
            end
        )

        test.case("turul tau de mana al cablului, pe drumurile barajului", function()
            -- plasa -> magazie -> atelier (intrare, inel, iesire) -> intrarea cablului la Relay -> inelul Relay -> iesire -> oras
            local g = RoadGraph.forWorld(W)
            local cable, grid, town = lines.cable, joins.grid, sellers.town
            local net = TycoonConfig.byId.cable_net
            local tour = {
                { x = net.x :: number, y = net.y :: number },
                cable.storeStand,
                cable.processorIn,
                cable.playerStand,
                cable.processorOut,
                grid.inputIn.cable,
                grid.playerStand,
                grid.processorOut,
                town.door,
            }
            local length = 0
            for i = 1, #tour - 1 do
                local points = RoadGraph.route(g, tour[i], tour[i + 1])
                length += RoadGraph.length(points)
                for k = 1, #points - 1 do
                    local a, b = points[k], points[k + 1]
                    for t = 0, 20 do
                        check.is_false(wet(a.x + (b.x - a.x) * t / 20, a.y + (b.y - a.y) * t / 20))
                    end
                end
            end
            check.equal(math.floor(length), 2996) -- planseta aprobata (PLAN-HARTA §9)
        end)
    end)
    -- [D70, pasul j9] raul, mersul si darurile, pe lume (partea pura)
    test.suite("World2River [D70, pasul j9]", function()
        test.case("mersul: lumea 1 ca pana acum; la baraj nu treci prin zid sau canal", function()
            local rects1, cfg1 = WorldMap.forWorld(1)
            local before = WorldMap.blockedRects(RiverConfig :: any, nil, TycoonConfig.PIER_WALK)
            check.equal(#rects1, #before)
            for i, r in before do
                check.is_true(
                    r.x == rects1[i].x
                        and r.y == rects1[i].y
                        and r.w == rects1[i].w
                        and r.h == rects1[i].h
                )
            end
            check.equal(cfg1.WORLD_WIDTH, RiverConfig.WORLD_WIDTH)
            local rects, cfg = WorldMap.forWorld(W)
            check.equal(cfg.WORLD_WIDTH, world.width)
            local function blocked(x: number, y: number): boolean
                return WorldMap.isBlocked(rects, cfg, x, y)
            end
            check.is_true(blocked(760, 860)) -- zidul, pe uscat
            check.is_true(blocked(2225, 950)) -- canalul de sub Relay
            check.is_true(blocked(1500, 600)) -- raul
            check.is_true(blocked(400, 600)) -- lacul
            check.is_false(blocked(300, 700)) -- pontonul, pe lac
            check.is_false(blocked(1500, 812)) -- puntea barajului
            check.is_false(blocked(3300, 1200)) -- in ceata, inca in lume
            check.is_true(blocked(3380, 1200)) -- marginea lumii 2
            local spawn = TycoonConfig.spawnOf(W)
            check.is_false(blocked(spawn.x, spawn.y))
            -- fiecare loc de predare si fiecare stand se poate atinge
            for _, pl in lines do
                for _, k in
                    { "storeStand", "playerStand", "processorIn", "processorOut", "workerStand" }
                do
                    local at = (pl :: any)[k]
                    check.is_false(blocked(at.x, at.y))
                end
            end
            for _, j in joins do
                for _, at in j.inputIn do
                    check.is_false(blocked(at.x, at.y))
                end
                check.is_false(blocked(j.playerStand.x, j.playerStand.y))
                check.is_false(blocked(j.processorOut.x, j.processorOut.y))
            end
            check.is_false(blocked(sellers.town.door.x, sellers.town.door.y))
        end)

        test.case(
            "darurile: iesirea dincolo de marginea fiecarei lumi; la baraj, de pe lac si de pe puntea barajului",
            function()
                for w = 1, 2 do
                    check.equal(
                        DriftMath.EXIT_X_BY_WORLD[w],
                        RiverConfig.WORLDS[w].WORLD_WIDTH + 60
                    )
                end
                check.equal(DriftMath.EXIT_X_BY_WORLD[1], DriftMath.EXIT_X)
                -- acelasi dar (determinist, D13) in ambele lumi, doar iesirea difera
                local gift = DriftMath.giftFor(12345, 77)
                local late = gift.enterAt + (4000 - DriftMath.ENTER_X) / gift.speed
                check.not_nil(DriftMath.xAt(gift, late, 1))
                check.equal(DriftMath.xAt(gift, late, 2), nil)
                check.equal(DriftMath.xAt(gift, late), DriftMath.xAt(gift, late, 1))
                local spans = DriftMath.reaches(
                    TycoonConfig.deckSpans(W),
                    function(_era: number): boolean
                        return true
                    end
                )
                check.equal(#spans, 2)
                check.equal(spans[1].x0, 240 - DriftMath.REACH_MARGIN) -- puntea lacului
                check.equal(spans[2].x1, 2760 + DriftMath.REACH_MARGIN) -- puntea barajului
                -- un dar care trece pe la puntea barajului se poate scoate de acolo
                local from, to = DriftMath.reachWindow(gift, spans[2])
                check.is_true(DriftMath.canGrab(gift, (from + to) / 2, spans))
            end
        )

        test.case("ce prind plasele barajului vine de la piciorul deversorului", function()
            check.equal(CatchFloat.SPAWN_X_BY_WORLD[1], CatchFloat.SPAWN_X)
            local spawn = CatchFloat.SPAWN_X_BY_WORLD[W]
            local wall = world.wall :: TycoonConfig.Box
            check.is_true(spawn >= wall.x and spawn <= wall.x + wall.w)
            for _, p in TycoonConfig.padsOfWorld(W) do
                if isNet(p) then
                    check.is_true(CatchFloat.travel(p.x :: number, spawn) > 0)
                end
            end
            -- in sat, fara argument, ca inainte
            check.equal(CatchFloat.travel(620), CatchFloat.travel(620, CatchFloat.SPAWN_X))
        end)

        test.case("raul lumii 2 duce aceleasi obiecte pana la marginea ei", function()
            local cfg2 = RiverConfig.WORLDS[W] :: any
            local objects = RiverSim.schedule(12345, 3, cfg2)
            check.equal(#objects, #RiverSim.schedule(12345, 3, RiverConfig :: any)) -- determinist [D13]
            for _, obj in objects do
                local tEnd = (cfg2.WORLD_WIDTH + cfg2.OBJECT_WIDTH + 1) / obj.speed
                check.equal(RiverSim.box(obj, cfg2, obj.spawnAt + tEnd), nil)
                check.not_nil(RiverSim.box(obj, RiverConfig :: any, obj.spawnAt + tEnd))
            end
        end)
    end)
end
