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
end
