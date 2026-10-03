-- [D70, pasul j7] ASEZAREA LUMII 2 (barajul), din TycoonConfig: aceleasi reguli ca testele de asezare ale satului
-- (TycoonConfig.test), cu care a fost verificata planseta aprobata in D74 (scripts/art/preview_dam_layout.py). Nimic nu se
-- calca, nimic construit nu sta pe drum sau pe apa canalului, plasele stau pe punte, locurile de predare langa drum,
-- clientii orasului in oglinda tavernei, felinarele dupa regula strazii, numele de sub case nu se ating, drumurile fac
-- un singur graf, iar oamenii isi lasa marfa cu fata spre gramada. [k2b] Decorul cumparat cu perle are locuri in piata
-- Dam Town, la fel de curate ca ale satului (suita World2Decor).
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
local StationConfig = require("../src/Shared/Config/StationConfig")
local VillageConfig = require("../src/Shared/Config/VillageConfig")
local Strings = require("../src/Shared/Config/Strings")
local WorldConfig = require("../src/Shared/Config/WorldConfig")

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

-- [k2b] textul din lume, in fontul de pixeli: 572/1024 em pe litera, randul ~1.03 em, contur de 2 (ca in TycoonConfig.test)
local function textBox(cx: number, top: number, text: string): Rect
    local lines, widest = 0, 0
    for _, part in string.split(text, "\n") do
        lines += 1
        widest = math.max(widest, #part)
    end
    local half = widest * EM * TINY / 2 + 2
    return { x0 = cx - half, x1 = cx + half, y0 = top - 2, y1 = top + lines * TINY * 1.03 + 2 }
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
            -- cladirile (si cele de pe platforme), casutele, apa si stalpii: oamenii si gramezile au voie pe marginea drumului
            for name, b in things do
                local built = string.sub(name, 1, 5) ~= "pile_"
                    and string.find(name, ".", 1, true) == nil
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
                    -- pe puntea barajului: ce prind plasele vine de la deversor (x 880), nu de pe lac
                    local d = (TycoonConfig.districtsOf(W)[2] :: TycoonConfig.District).deck
                    check.equal(TycoonConfig.districtsOf(W)[2].id, "dam")
                    if not (px >= d.x0 and px <= d.x1 and py >= d.y0 and py <= d.y1) then
                        table.insert(bad, `plasa {p.id} nu e pe puntea barajului`)
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
            "stalpii podului, clientii orasului si gardurile nu calca oameni, gramezi sau nume",
            function()
                local things = placed()
                local bad = {}
                -- stalpii de pod stau pe marginea canalului (au voie pe drum), dar nu peste oameni sau gramezi
                for _, p in world.pylons :: { TycoonConfig.Pylon } do
                    if p.overRoad then
                        local b = box(p.x, p.y, p.w, p.h)
                        for name, other in things do
                            local person = string.find(name, ".", 1, true) ~= nil
                            if (person or string.sub(name, 1, 5) == "pile_") and hit(b, other) then
                                table.insert(bad, `stalpul {p.name} x {name}`)
                            end
                        end
                    end
                end
                -- clientii orasului: unde vin si unde asteapta (omul desenat, 40x60, prins de talpi)
                local labels = {}
                for _, p in TycoonConfig.padsOfWorld(W) do
                    local role = TycoonConfig.CREW_OF_PAD[p.id]
                    if role ~= nil then
                        local half = #TycoonConfig.CREWS[role].name * EM * TINY / 2 + 2
                        local x, y = p.x :: number, p.y :: number
                        labels[`name_{p.id}`] = {
                            x0 = x - half,
                            x1 = x + half,
                            y0 = y + 56,
                            y1 = y + 58 + TINY * 1.03 + 2,
                        }
                    end
                end
                local town = sellers.town
                local customers = { { name = "entry", at = town.customerEntry } }
                for i, spot in town.customerSpots do
                    table.insert(customers, { name = `spot_{i}`, at = spot })
                end
                for _, c in customers do
                    local b = box(c.at.x, c.at.y, 40, 60)
                    -- la fereastra-tejghea clientii stau lipiti de Switch House (ca la taverna): cladirea lor nu se numara
                    for name, other in things do
                        if name ~= "spawn" and name ~= "switchHouse" and hit(b, other) then
                            table.insert(bad, `clientul {c.name} x {name}`)
                        end
                    end
                    for name, label in labels do
                        if hit(b, label) then
                            table.insert(bad, `clientul {c.name} x {name}`)
                        end
                    end
                end
                -- un gard de zona (ZoneController) acopera ~42 px de partea luminata: nimic construit acolo
                local fenceArt = (Assets.props :: any).fence
                for _, zone in TycoonConfig.zonesOf(W) do
                    if zone.fence ~= false then
                        local edge = zone.x0 - fenceArt.height * Assets.PIXEL_SCALE / 2
                        for name, b in things do
                            if b.x1 > edge and b.x0 < zone.x0 then
                                table.insert(bad, `sub gardul zonei {zone.id}: {name}`)
                            end
                        end
                    end
                end
                for _, b in bad do
                    print("  ! " .. b)
                end
                check.equal(#bad, 0)
            end
        )

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
                local want = {}
                for i = 1, #xs - 1 do
                    local x = (xs[i] + xs[i + 1]) / 2
                    -- aceeasi regula ca TycoonConfig.streetLamps (oamenii pe loc si roabele lor, si la Relay)
                    local blocked = TycoonConfig.lampBlocked(x, W)
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

    -- [D70, pasul k2b] decorul cumparat cu perle, in piata Dam Town
    -- [verificatorul k3] turbina zidita se deseneaza pe fata zidului, in cutia ei; marfa barajului are nume si desen
    test.suite("World2Art [verificatorul k3]", function()
        test.case(
            "turbina din zid: cutia ei e pe fata zidului; nicio alta platforma n-are cutie",
            function()
                local box = TycoonConfig.wallTurbineAt(TycoonConfig.byId.dam_turbine)
                assert(box ~= nil, "turbina barajului are cutia ei")
                local wall = world.wall :: TycoonConfig.Box
                check.is_true(box.x - box.w / 2 >= wall.x and box.x + box.w / 2 <= wall.x + wall.w)
                check.is_true(box.y - box.h / 2 >= wall.y and box.y + box.h / 2 <= wall.y + wall.h)
                check.equal(TycoonConfig.wallTurbineAt(TycoonConfig.byId.first_turbine), nil)
                check.equal(TycoonConfig.wallTurbineAt(TycoonConfig.byId.first_net), nil)
                check.equal(TycoonConfig.wallTurbineAt(TycoonConfig.byId.cable_net), nil)
            end
        )
        test.case(
            "fiecare marfa a barajului are nume si un desen urcat (al ei sau al perechii)",
            function()
                local FlowConfig = require("../src/Shared/Config/FlowConfig")
                local function drawn(good: string): string?
                    for _, g in { good, TycoonConfig.lookOf(good) } do
                        local icon = (Assets.goods :: any)[g]
                        if icon ~= nil and Assets.has(icon) then
                            return g
                        end
                    end
                    return nil
                end
                for _, line in StationConfig.LINE_ORDER_ALL do
                    local spec = FlowConfig.LINES_ALL[line]
                    if spec.era == 4 then
                        local goods = table.clone(spec.raw)
                        table.insert(goods, spec.output)
                        for _, good in goods do
                            check.not_nil(TycoonConfig.GOOD_NAMES[good])
                            if drawn(good) == nil then
                                print(`  ! {good} fara desen`)
                            end
                            check.not_nil(drawn(good))
                        end
                        -- cele doua piese ale unirii se deosebesc pe gramezile Relay-ului
                        if spec.joins ~= nil then
                            local a, b = spec.joins[1], spec.joins[2]
                            check.is_true(drawn(a.good) ~= drawn(b.good))
                        end
                    end
                end
            end
        )
    end)

    -- [D70, pasul k10] Dam Town: numele de pe harta (cele din textele avizierului), plimbarea oamenilor retrasi pe uscat si
    -- pe drumuri, fara sa calce decorul cumparat
    test.suite("DamTown [D70, pasul k10]", function()
        local DamTown = require("../src/Shared/Modules/DamTown")
        local HandMath = require("../src/Shared/Modules/HandMath")
        test.case("numele din textele avizierului sunt pe harta", function()
            local labels: { [string]: boolean } = {}
            for _, b in DamTown.buildings() do
                labels[b.label] = true
            end
            check.is_true(labels.Canteen == true)
            check.is_true(labels["Memory Wall"] == true)
            check.equal(Strings.LINE_WORDS.barrels.store, "Battery Store")
            for _, d in VillageConfig.DECOR do
                local where = VillageConfig.whereOf(d, W)
                for _, name in { "Canteen", "Memory Wall", "Battery Store" } do
                    if string.find(where, name, 1, true) ~= nil then
                        check.is_true(labels[name] == true or name == "Battery Store")
                    end
                end
            end
        end)
        test.case("bonusul clopotelor vechi vine din efectele lor", function()
            check.equal(DamTown.bellsPercent(), 33)
        end)
        test.case("oamenii retrasi se plimba pe uscat, fara sa calce decorul", function()
            local decor: { { name: string, r: Rect } } = {}
            for _, d in VillageConfig.DECOR do
                if d.ground == "land" and not d.overRoad then
                    for i, spot in VillageConfig.spotsOf(d, W) do
                        local art = (Assets.decor :: any)[d.sprite]
                        table.insert(decor, {
                            name = `{d.id}_{i}`,
                            r = box(spot.x, spot.y, art.width * d.scale, art.height * d.scale),
                        })
                    end
                end
            end
            local function wet(x: number, y: number): boolean
                if y <= RiverConfig.WORLDS[W].RIVER_BOTTOM then
                    return true
                end
                for _, b in world.blocked :: { TycoonConfig.Box } do
                    if x > b.x and x < b.x + b.w and y > b.y and y < b.y + b.h then
                        return true
                    end
                end
                return false
            end
            local bad = {}
            for i = 1, DamTown.MAX_WALKERS do
                local cycle = DamTown.cycle(i)
                check.is_true(cycle.duration > 0)
                for t = 0, cycle.duration, 0.25 do
                    local x, y = HandMath.sampleAt(cycle, t)
                    if wet(x, y) then
                        table.insert(bad, `omul {i} in apa la ({math.floor(x)}, {math.floor(y)})`)
                        break
                    end
                    -- talpile (o fasie de 24 x 12 la picioare) pe baza decorului (ultimii 24 px): asta inseamna „calca”;
                    -- un om pe strada trece prin fata unui strat de flori de pe iarba, cu adancimea dupa talpi
                    local feet = { x0 = x - 12, x1 = x + 12, y0 = y - 12, y1 = y }
                    for _, d in decor do
                        local base = { x0 = d.r.x0, x1 = d.r.x1, y0 = d.r.y1 - 24, y1 = d.r.y1 }
                        if hit(feet, base) then
                            table.insert(bad, `omul {i} calca {d.name}`)
                            break
                        end
                    end
                end
            end
            for _, b in bad do
                print("  ! " .. b)
            end
            check.equal(#bad, 0)
        end)
    end)

    test.suite("World2Decor [D70, pasul k2b]", function()
        local DECOR = VillageConfig.DECOR
        local zone = TycoonConfig.zonesOf(W)[1]
        local plot = RiverConfig.WORLDS[W].PLOT

        local function boxOf(d: VillageConfig.Decor, spot: VillageConfig.Spot): Rect
            local art = (Assets.decor :: any)[d.sprite]
            return box(spot.x, spot.y, art.width * d.scale, art.height * d.scale)
        end

        test.case(
            "in sat nimic nu se schimba: spotsOf(decor, 1) e chiar decor.spots, la fel fara lume sau cu o lume necunoscuta",
            function()
                check.equal(#DECOR, 10)
                for _, d in DECOR do
                    check.is_true(VillageConfig.spotsOf(d, 1) == d.spots)
                    check.is_true(VillageConfig.spotsOf(d) == d.spots)
                    check.is_true(VillageConfig.spotsOf(d, 7) == d.spots)
                    check.is_true(VillageConfig.spotsOf(d, 0.5) == d.spots)
                    check.is_true(VillageConfig.spotsOf(d, "2" :: any) == d.spots)
                    check.equal(VillageConfig.whereOf(d, 1), d.where)
                    check.equal(VillageConfig.whereOf(d), d.where)
                    -- locurile alternative sunt doar ale lumii 2: satul si-a scris locurile in `spots`
                    if d.spotsByWorld ~= nil then
                        check.equal(d.spotsByWorld[1], nil)
                    end
                    if d.whereByWorld ~= nil then
                        check.equal(d.whereByWorld[1], nil)
                    end
                end
            end
        )

        test.case(
            "la baraj: pe uscat acelasi numar de locuri ca in sat, pe ponton si pe apa aceleasi locuri, fiecare cu textul lui",
            function()
                local land = 0
                for _, d in DECOR do
                    local spots = VillageConfig.spotsOf(d, W)
                    if d.ground == "land" then
                        check.not_nil(d.spotsByWorld)
                        check.is_true(spots ~= d.spots)
                        check.equal(#spots, #d.spots)
                        land += #spots
                        -- textul satului ("By the Tavern square") nu minte aici: fiecare lucru de pe uscat are al lui
                        local where = VillageConfig.whereOf(d, W)
                        check.is_true(where ~= d.where)
                        check.is_true(string.find(where, "village", 1, true) == nil)
                        check.is_true(string.find(where, "Tavern", 1, true) == nil)
                    else
                        -- acelasi ponton si acelasi lac pe aceleasi coordonate: nimic de mutat
                        check.equal(d.spotsByWorld, nil)
                        check.equal(d.whereByWorld, nil)
                        check.is_true(spots == d.spots)
                        check.equal(VillageConfig.whereOf(d, W), d.where)
                    end
                    check.is_true(#spots >= 1)
                end
                check.equal(land, 12) -- patru straturi de flori, doua ghirlande, un loc pentru fiecare dintre celelalte sase
            end
        )

        test.case("textul de pe randul din panou incape (Nunito, 13 px, cutia de 250)", function()
            local widths = require("./fonts/NunitoWidths") :: { [string]: number }
            local SIZE, LIMIT = 13, 240
            for _, d in DECOR do
                for _, w in { 1, W } do
                    local text = VillageConfig.whereOf(d, w)
                    local px = 0
                    for _, code in utf8.codes(text) do
                        local ch = utf8.char(code)
                        check.not_nil(widths[ch])
                        px += (widths[ch] or 1000) * SIZE / 1000
                    end
                    if px > LIMIT then
                        print(`  ! {d.id} (lumea {w}) are ~{math.floor(px)} px: {text}`)
                    end
                    check.is_true(px <= LIMIT)
                end
            end
        end)

        test.case(
            "locurile de pe uscat sunt pe uscat, in zona, si nu calca nimic, nici unul pe altul",
            function()
                -- tot ce nu are voie sa fie acoperit de un decor cumparat: cladirile, oamenii, gramezile, stalpii, locul unde
                -- apari, platformele (patratul lor si cladirea), curtile, puntile, apa si zidul, pontonul si barca
                local solid: { [string]: Rect } = {}
                for name, r in placed() do
                    solid[name] = r
                end
                for _, p in world.pylons :: { TycoonConfig.Pylon } do
                    solid[p.name] = box(p.x, p.y, p.w, p.h) -- si cei de pe pod: ghirlanda nu atarna peste ei
                end
                for _, p in TycoonConfig.padsOfWorld(W) do
                    local px, py = p.x :: number, p.y :: number
                    solid[`pad_{p.id}`] =
                        { x0 = px - HALF, x1 = px + HALF, y0 = py - HALF, y1 = py + HALF }
                end
                -- felinarele strazii: capul (x +- 15, y 1372..1414) si stalpul (x +- 6, pana la baza), ca la TycoonConfig.lampBlocked
                for i, lamp in TycoonConfig.streetLamps(W) do
                    solid[`felinar_{i}_cap`] =
                        { x0 = lamp.x - 15, x1 = lamp.x + 15, y0 = 1372, y1 = 1414 }
                    solid[`felinar_{i}_stalp`] =
                        { x0 = lamp.x - 6, x1 = lamp.x + 6, y0 = 1414, y1 = lamp.y }
                end
                for _, d in TycoonConfig.districtsOf(W) do
                    solid[`deck_{d.id}`] = d.deck
                    for _, y in d.yards do
                        solid[`curte_{y.id}`] = y
                    end
                end
                for name, b in world.water :: { [string]: TycoonConfig.Box } do
                    solid[`apa_{name}`] = corner(b)
                end
                for i, b in world.blocked :: { TycoonConfig.Box } do
                    solid[`blocat_{i}`] = corner(b)
                end
                solid.wall = corner(world.wall :: TycoonConfig.Box)
                local PIER = TycoonConfig.PIER
                solid.pier =
                    { x0 = PIER.x - 48, x1 = PIER.x + 48, y0 = PIER.y - 156, y1 = PIER.y + 156 }
                local ferryArt = Assets.fair.ferry
                solid.ferry = box(
                    TycoonConfig.FERRY.x,
                    TycoonConfig.FERRY.y,
                    ferryArt.width * 2,
                    ferryArt.height * 2
                )
                -- ce se citeste pe ecran: numele de sub casele oamenilor, casa cu treapta ei (HomeClear), etichetele rotii si
                -- avizierului (sub indicator si sub avizier, baza + 2)
                for _, p in TycoonConfig.padsOfWorld(W) do
                    local role = TycoonConfig.CREW_OF_PAD[p.id]
                    if role ~= nil then
                        local x, y = p.x :: number, p.y :: number
                        solid[`nume_{p.id}`] = textBox(x, y + 58, TycoonConfig.CREWS[role].name)
                        local base = TycoonConfig.buildingBase(p)
                        solid[`casa_{p.id}`] =
                            { x0 = x - 80, x1 = x + 80, y0 = base - 130, y1 = base + 20 }
                    end
                end
                solid.eticheta_roata = textBox(
                    TycoonConfig.WHEEL_STAND.x,
                    TycoonConfig.WHEEL_STAND.y + 2,
                    Strings.WHEEL_MOVED_TAG
                )
                solid.eticheta_avizier = textBox(
                    TycoonConfig.VILLAGE_BOARD.x,
                    TycoonConfig.VILLAGE_BOARD.y + 2,
                    Strings.BOARD_TAG
                )
                local solidNames = sortedNames(solid)
                local rs = roads()
                local deckBottom = 0
                for _, d in decks() do
                    deckBottom = math.max(deckBottom, d.y1)
                end

                local all: { { name: string, r: Rect } } = {}
                local bad = {}
                local seen = 0
                for _, d in DECOR do
                    for i, spot in VillageConfig.spotsOf(d, W) do
                        local name = `decor_{d.id}_{i}`
                        local b = boxOf(d, spot)
                        seen += 1
                        table.insert(all, { name = name, r = b })
                        if d.ground ~= "land" then
                            continue
                        end
                        -- pe uscat: in zona Erei 4, sub puntile si sub tot ce e apa, in terenul jucatorului
                        if b.x0 < zone.x0 or b.x1 > zone.x1 then
                            table.insert(bad, `{name} in afara zonei`)
                        end
                        if b.y0 < deckBottom or b.y1 > plot.y + plot.h then
                            table.insert(bad, `{name} nu e pe uscat, in terenul jucatorului`)
                        end
                        for _, other in solidNames do
                            if hit(b, solid[other]) then
                                table.insert(bad, `{name} x {other}`)
                            end
                        end
                        -- drumurile: ghirlanda atarna peste ele, cu stalpii pe margine; orice altceva sta pe iarba
                        if not d.overRoad then
                            for _, r in rs do
                                if hit(b, r) then
                                    table.insert(bad, `{name} pe drumul {r.id}`)
                                end
                            end
                        end
                        -- cardurile E ale zidului (clopotnita, Memory Wall): macar 40 px de punctul lor
                        for card, at in world.cards :: { [string]: Point } do
                            if gap(at, b) < 40 then
                                table.insert(bad, `{name} prea aproape de cardul {card}`)
                            end
                        end
                    end
                end
                check.equal(seen, 15)
                -- nici un decor peste altul (cele de pe ponton si de pe apa, la locurile lor)
                for i = 1, #all do
                    for j = i + 1, #all do
                        if hit(all[i].r, all[j].r) then
                            table.insert(bad, `{all[i].name} x {all[j].name}`)
                        end
                    end
                end
                for _, b in bad do
                    print("  ! " .. b)
                end
                check.equal(#bad, 0)
            end
        )

        -- [verificatorul k2b] o lume noua (harta Erei 8) fara locurile si textele ei ar fi desenat decorul nicaieri si ar fi
        -- scris textul satului pe avizier
        test.case(
            "fiecare lume de dupa sat are locurile si textele ei pentru tot ce sta pe uscat",
            function()
                for w = 2, WorldConfig.COUNT do
                    for _, d in DECOR do
                        if d.ground == "land" then
                            local spots = (d.spotsByWorld or {})[w]
                            check.not_nil(spots)
                            check.equal(#(spots or {}), #d.spots)
                            check.not_nil((d.whereByWorld or {})[w])
                        end
                    end
                end
            end
        )

        -- [verificatorul k2b] textele trimit la lucruri care se vad: harta n-are busola, iar „Dam Town” nu scrie nicaieri
        -- (zona se cheama „The Dam”)
        test.case("textele de la baraj: fara busola si fara nume care nu sunt pe harta", function()
            for _, d in DECOR do
                local where = VillageConfig.whereOf(d, W)
                for _, word in { "East", "West", "North", "South", "Dam Town" } do
                    local found = string.find(string.lower(where), string.lower(word), 1, true)
                    if found ~= nil then
                        print(`  ! {d.id}: {where}`)
                    end
                    check.equal(found, nil)
                end
            end
        end)

        test.case(
            "ghirlanda atarna peste un drum, cu stalpii pe iarba; nimic langa capatul pontonului",
            function()
                local rs = roads()
                local function onRoad(x: number, y: number): boolean
                    for _, r in rs do
                        if x > r.x0 and x < r.x1 and y > r.y0 and y < r.y1 then
                            return true
                        end
                    end
                    return false
                end
                local PIER = TycoonConfig.PIER
                local pierEnd = PIER.y + 156 -- capatul pontonului de pe uscat
                for _, d in DECOR do
                    if d.ground ~= "land" then
                        continue
                    end
                    for _, spot in VillageConfig.spotsOf(d, W) do
                        local b = boxOf(d, spot)
                        if d.overRoad then
                            local crosses = false
                            for _, r in rs do
                                crosses = crosses or hit(b, r)
                            end
                            check.is_true(crosses)
                            check.is_false(onRoad(b.x0, spot.y - 1))
                            check.is_false(onRoad(b.x1, spot.y - 1))
                        end
                        -- in dreptul pontonului, macar 32 px de capatul lui: altfel pontonul pare ca se termina in decor
                        if b.x1 > PIER.x - 48 and b.x0 < PIER.x + 48 then
                            check.is_true(b.y0 >= pierEnd + 32)
                        end
                    end
                end
            end
        )

        test.case(
            "clientii orasului vin la Switch House fara sa treaca prin vreun decor",
            function()
                local town = sellers.town
                local bad = {}
                local function clear(x: number, y: number, what: string)
                    local person = box(x, y, 40, 60)
                    for _, d in DECOR do
                        if d.ground == "land" then
                            for i, spot in VillageConfig.spotsOf(d, W) do
                                if hit(person, boxOf(d, spot)) then
                                    table.insert(bad, `{what} x {d.id}_{i}`)
                                end
                            end
                        end
                    end
                end
                clear(town.customerEntry.x, town.customerEntry.y, "intrarea")
                for i, spot in town.customerSpots do
                    clear(spot.x, spot.y, `locul {i}`)
                    -- drumul lor, in pasi de 8 px, de la intrare la loc (CustomerCrowd merge drept)
                    local dx, dy = spot.x - town.customerEntry.x, spot.y - town.customerEntry.y
                    local steps = math.ceil(math.sqrt(dx * dx + dy * dy) / 8)
                    for k = 0, steps do
                        local t = k / steps
                        clear(
                            town.customerEntry.x + dx * t,
                            town.customerEntry.y + dy * t,
                            `drumul {i}`
                        )
                    end
                end
                for _, b in bad do
                    print("  ! " .. b)
                end
                check.equal(#bad, 0)
            end
        )

        -- [verificatorul k2b] de unde apari pana la ponton, roata, avizier, barca si cardurile zidului: nici drumul tau drept,
        -- nici cel pe drumuri (oamenii de la k10), nu trec printr-un decor de pe uscat (ghirlanda atarna sus, peste strada)
        test.case("de unde apari pana la colturile satului, omul nu calca niciun decor", function()
            local spawn = TycoonConfig.spawnOf(W)
            local targets: { [string]: Point } = {
                roata = TycoonConfig.WHEEL_STAND,
                avizier = TycoonConfig.VILLAGE_BOARD,
                barca = TycoonConfig.FERRY_BOARD,
                ponton = { x = TycoonConfig.PIER.x, y = TycoonConfig.PIER.y + 156 },
            }
            for card, at in world.cards :: { [string]: Point } do
                targets[card] = at
            end
            local decor: { { name: string, r: Rect } } = {}
            for _, d in DECOR do
                if d.ground == "land" and not d.overRoad then
                    for i, spot in VillageConfig.spotsOf(d, W) do
                        table.insert(decor, { name = `{d.id}_{i}`, r = boxOf(d, spot) })
                    end
                end
            end
            local bad = {}
            local function walk(path: { Point }, what: string)
                for k = 1, #path - 1 do
                    local a, b = path[k], path[k + 1]
                    local dx, dy = b.x - a.x, b.y - a.y
                    local steps = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy) / 4))
                    for i = 0, steps do
                        local t = i / steps
                        local person = box(a.x + dx * t, a.y + dy * t, 48, 72)
                        for _, d in decor do
                            if hit(person, d.r) then
                                table.insert(bad, `{what} x {d.name}`)
                                return
                            end
                        end
                    end
                end
            end
            for name, at in targets do
                walk({ spawn, at }, `drept spre {name}`)
                walk(RoadGraph.route(RoadGraph.forWorld(W), spawn, at), `pe drumuri spre {name}`)
            end
            for _, b in bad do
                print("  ! " .. b)
            end
            check.equal(#bad, 0)
        end)

        test.case(
            "ponton si apa la baraj: ca in sat, pe ponton, in lac, fara sa se atinga",
            function()
                local PIER = TycoonConfig.PIER
                local pier: Rect =
                    { x0 = PIER.x - 48, x1 = PIER.x + 48, y0 = PIER.y - 156, y1 = PIER.y + 156 }
                local lake = corner(world.water.lake :: TycoonConfig.Box)
                for _, d in DECOR do
                    for _, spot in VillageConfig.spotsOf(d, W) do
                        local b = boxOf(d, spot)
                        if d.ground == "pier" then
                            check.is_true(
                                b.x0 >= pier.x0
                                    and b.x1 <= pier.x1
                                    and b.y0 >= pier.y0
                                    and b.y1 <= pier.y1
                            )
                        elseif d.ground == "water" then
                            check.is_true(
                                b.x0 >= lake.x0
                                    and b.x1 <= lake.x1
                                    and b.y0 >= lake.y0
                                    and b.y1 <= lake.y1
                            )
                            check.is_false(hit(b, pier))
                        end
                    end
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

        test.case(
            "din orice punct de uscat al barajului, drumul nu intra in apa, in zid sau in canal",
            function()
                local g = RoadGraph.forWorld(W)
                local targets = {
                    lines.cable.storeStand,
                    lines.crystal.playerStand,
                    joins.grid.playerStand,
                    sellers.town.door,
                    { x = 980, y = 812 }, -- turbina, pe puntea barajului
                    { x = 300, y = 812 }, -- puntea lacului
                }
                local tried = 0
                for x = 240, 3040, 160 do
                    for y = 880, 1640, 160 do
                        if not wet(x, y) then
                            for _, t in targets do
                                tried += 1
                                local points = RoadGraph.route(g, { x = x, y = y }, t)
                                for k = 1, #points - 1 do
                                    local a, b = points[k], points[k + 1]
                                    for i = 0, 20 do
                                        local px, py =
                                            a.x + (b.x - a.x) * i / 20, a.y + (b.y - a.y) * i / 20
                                        if wet(px, py) then
                                            print(
                                                `  ! din ({x}, {y}) spre ({t.x}, {t.y}): prin apa la ({px}, {py})`
                                            )
                                        end
                                        check.is_false(wet(px, py))
                                    end
                                end
                            end
                        end
                    end
                end
                check.is_true(tried > 500)
            end
        )

        test.case(
            "fiecare om al barajului merge sau sta pe uscat; oamenii satului n-au ce face acolo",
            function()
                local ctx = HandRoutes.forWorld(W)
                for _, role in StationConfig.ERA4_ROLES do
                    local walks = HandRoutes.cycleFor(role, 1, 1, DAM_NETS, ctx).duration > 0
                    if not walks then
                        for index = 1, 2 do
                            local at = HandRoutes.standFor(role, index, ctx)
                            check.not_nil(at)
                            if at ~= nil then
                                check.is_false(wet(at.x, at.y))
                            end
                        end
                    end
                end
                -- oamenii satului (Erele 1-3): fara comutator sunt toti din joc; cu el, doar ei, nu si cei ai barajului
                for _, role in StationConfig.ROLES do
                    if (StationConfig.ERA_OF_ROLE[role] or 1) <= 3 then
                        check.equal(HandRoutes.routeFor(role, 1, 1, DAM_NETS, ctx), nil)
                        check.equal(HandRoutes.standFor(role, 1, ctx), nil)
                    end
                end
                -- contextul satului nu mai cara locurile barajului; meseriile barajului adormite (implicit: al jocului)
                check.equal(HandRoutes.GAME.linePlaces.barrels, nil)
                check.equal(HandRoutes.GAME.joinPlaces.grid, nil)
                check.equal(HandRoutes.GAME.sellerPlaces.town, nil)
                check.equal(HandRoutes.jobOf("damCollector"), nil)
                check.equal(HandRoutes.standFor("relayKeeper", 1), nil)
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
            check.is_true(blocked(2225, 1200)) -- canalul, sub piata, pana la stavila
            check.is_false(blocked(2225, 812)) -- puntea trece peste canal
            check.is_false(blocked(2225, 1130)) -- piata Switch House trece peste canal
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

        test.case(
            "de pe ce punti se scoate un dar, pe lumea profilului (regula serverului)",
            function()
                local everything: { [string]: boolean } = {}
                for _, p in TycoonConfig.PADS do
                    everything[p.id] = true
                end
                local function live(era: number): boolean
                    return era <= 4 -- barajul pornit, ca dupa comutator
                end
                -- satul, cu toate clopotele: cele trei punti, ca in martor
                check.equal(#DriftMath.reachesFor(1, everything), 3)
                check.equal(#DriftMath.reachesFor(1, {}), 1) -- doar The Landing
                -- barajul, azi (Era 4 nu e in joc): nicio punte; dupa comutator, ca mai jos
                if not TycoonConfig.eraIsLive(4) then
                    check.equal(#DriftMath.reachesFor(2, everything), 0)
                end
                -- barajul pornit: lacul si puntea barajului, taiate la zid (de pe zid nu se scoate)
                local dam = DriftMath.reachesFor(2, everything, live)
                -- [verificatorul k1] prima era a barajului n-asteapta Works Bell-ul satului: clientul nici nu-l primeste in
                -- statusurile hartii, iar serverul l-ar lasa sa scoata darul
                check.equal(#DriftMath.reachesFor(2, {}, live), #dam)
                local noWorks = table.clone(everything)
                noWorks.works_bell = nil
                check.equal(#DriftMath.reachesFor(2, noWorks, live), #dam)
                -- in sat, regula ramane clopotul erei dinainte
                check.equal(#DriftMath.reachesFor(1, { mill_bell = true }), 2)
                check.equal(#dam, 2)
                local wall = world.wall :: TycoonConfig.Box
                check.equal(dam[1].x1, wall.x)
                check.equal(dam[2].x0, wall.x + wall.w)
                check.is_true(DriftMath.hiddenAt(760, 2))
                check.is_false(DriftMath.hiddenAt(760, 1))
                -- un profil din sat nu primeste niciodata puntile barajului; o lume stricata e satul
                for _, span in DriftMath.reachesFor(1, everything, live) do
                    check.is_true(span.x1 <= 5240 + DriftMath.REACH_MARGIN)
                end
                check.equal(#DriftMath.reachesFor("2", everything, live), 3)
            end
        )

        test.case("ce prind plasele barajului vine de la piciorul deversorului", function()
            check.equal(CatchFloat.SPAWN_X_BY_WORLD[1], CatchFloat.SPAWN_X)
            local spawn = CatchFloat.SPAWN_X_BY_WORLD[W]
            local wall = world.wall :: TycoonConfig.Box
            check.equal(spawn, wall.x + wall.w) -- fata zidului, ca pe planseta aprobata (x 880)
            check.equal(spawn, 880)
            for _, p in TycoonConfig.padsOfWorld(W) do
                if isNet(p) then
                    check.is_true(CatchFloat.travel(p.x :: number, spawn) > 0)
                end
            end
            -- in sat, fara argument, ca inainte
            check.equal(CatchFloat.travel(620), CatchFloat.travel(620, CatchFloat.SPAWN_X))
        end)
    end)

    -- [D70, pasul k12] Pamantul copt al barajului (scripts/art/village_ground.py --world 2): feliile din Assets au marimea
    -- fisierelor coapte (Roblox nu spune nimic daca o imagine urcata e mai ingusta: felia ar acoperi doar o bucata), iar
    -- cartierele barajului trec in BAKED_DISTRICTS exact odata cu urcarea (altfel puntea si drumurile s-ar desena de doua
    -- ori, sau deloc).
    test.suite("World2Ground [D70, pasul k12]", function()
        local fs = require("@lune/fs")
        local function pngSize(path: string): (number, number)
            local head = fs.readFile(path)
            local w, h = string.unpack(">I4I4", head, 17)
            return w, h
        end

        test.case("feliile barajului: marimea din Assets e cea a imaginilor coapte", function()
            local river = (RiverConfig.WORLDS :: any)[W]
            local slices = { Assets.tycoon.dam_ground, Assets.tycoon.dam_ground_2 }
            local covered = 0
            for k, sprite in slices do
                local name = if k == 1 then "prop_dam_ground" else `prop_dam_ground_{k}`
                local w, h = pngSize(`assets/sprites/{name}.png`)
                check.equal(sprite.width, w)
                check.equal(sprite.height, h)
                check.equal(h * Assets.PIXEL_SCALE, river.WORLD_HEIGHT)
                covered += w * Assets.PIXEL_SCALE
            end
            check.equal(Assets.tycoon.dam_ground.width * Assets.PIXEL_SCALE, river.BAKE_SLICE)
            -- cele doua felii acopera lumea (pana la ultimul pixel intreg de imagine)
            check.equal(covered, river.WORLD_WIDTH - river.WORLD_WIDTH % Assets.PIXEL_SCALE)
        end)

        test.case("cartierele barajului intra in BAKED_DISTRICTS doar odata cu urcarea", function()
            local uploaded = Assets.has(Assets.tycoon.dam_ground)
            check.equal(uploaded, Assets.has(Assets.tycoon.dam_ground_2))
            for _, d in TycoonConfig.districtsOf(W) do
                check.equal(TycoonConfig.BAKED_DISTRICTS[d.id] == true, uploaded)
            end
        end)
    end)
end
