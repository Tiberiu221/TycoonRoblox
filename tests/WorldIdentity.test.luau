-- [D70, pasul j1] MARTORUL LUMII 1. Barajul aduce o a doua harta (PLAN-MOTOR-UNIRE §16): drumuri, felinare, decor,
-- platforme, rau si quest-uri pe lume. Satul de azi trebuie sa iasa din toate astea neatins, la bit. Martorul scrie
-- intr-un fisier (tests/witness/world1.txt) tot ce se vede si se misca in lumea 1, iar testul cere ca fisierul sa ramana
-- exact la fel. Un pas care muta o coordonata, un felinar, un copac, un traseu, malul sau un quest al satului il pica.
--
-- LUMEA 1 SE DESCRIE DUPA ERA (1-3), NU DUPA `live` [verificator, 2026-10-03]: platformele, meseriile, liniile,
-- vanzatorii si capitolele erelor 1-3, iar functiile cu lista de platforme o primesc explicit. Asa martorul ramane
-- neschimbat si la comutatorul l3, cand Era 4 intra in joc; de la j6 lista vine din `padsOfWorld(1)`.
-- Ce TREBUIE sa se schimbe la l3 (listele motorului, citite dupa StationConfig.ENGINE_ERAS, capitolele din joc si
-- statusurile pe lista intreaga) sta in al doilea fisier, tests/witness/engine.txt, de rescris la l3 si doar atunci.
--
-- Fisierele se rescriu doar cu buna stiinta, cand o schimbare e chiar dorita:
--   WORLD_WITNESS=write lune run tests/_run.luau
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local fs = require("@lune/fs")
local process = require("@lune/process")

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local StationConfig = require("../src/Shared/Config/StationConfig")
local FlowConfig = require("../src/Shared/Config/FlowConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local QuestConfig = require("../src/Shared/Config/QuestConfig")
local RoadGraph = require("../src/Shared/Modules/RoadGraph")
local VillageDecor = require("../src/Shared/Modules/VillageDecor")
local TycoonMath = require("../src/Shared/Modules/TycoonMath")
local HandRoutes = require("../src/Shared/Modules/HandRoutes")
local VillageLook = require("../src/Shared/Modules/VillageLook")
local WorldMap = require("../src/Shared/Modules/WorldMap")
local DriftMath = require("../src/Shared/Modules/DriftMath")
local CatchFloat = require("../src/Shared/Modules/CatchFloat")
local RiverSim = require("../src/Shared/Modules/RiverSim")

local WORLD1 = "tests/witness/world1.txt"
local ENGINE = "tests/witness/engine.txt"
local WORLD1_ERAS = 3 -- erele satului de pe rau; Era 4 e barajul, in lumea 2
local RIVER_SEED = 12345 -- RiverService.BASE_SEED (serverul nu se incarca in Lune); testul il cere acolo ca text

-- Text determinist: chei sortate, numere exacte (%.17g).
local function encode(v: any): string
    local t = type(v)
    if t == "number" then
        if v ~= v then
            return "nan"
        end
        return string.format("%.17g", v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "boolean" or t == "nil" then
        return tostring(v)
    elseif t == "table" then
        local n = #v
        local keys = {}
        for k in v do
            if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
                table.insert(keys, k)
            end
        end
        table.sort(keys, function(a, b)
            return tostring(a) < tostring(b)
        end)
        local parts = {}
        for i = 1, n do
            table.insert(parts, encode(v[i]))
        end
        for _, k in keys do
            table.insert(parts, tostring(k) .. "=" .. encode(v[k]))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "<" .. t .. ">"
end

-- O sectiune, sparta la primul nivel ca o diferenta sa fie un rand scurt: o lista, un element pe rand; o harta, o
-- cheie pe rand (sortate); orice altceva, un singur rand.
local function section(out: { string }, name: string, value: any)
    table.insert(out, "## " .. name)
    if type(value) ~= "table" then
        table.insert(out, encode(value))
        return
    end
    local n = #value
    for i = 1, n do
        table.insert(out, encode(value[i]))
    end
    local keys = {}
    for k in value do
        if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
            table.insert(keys, k)
        end
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for _, k in keys do
        table.insert(out, tostring(k) .. "=" .. encode(value[k]))
    end
end

local function flatten(lists: { { string } }, upTo: number): { string }
    local out = {}
    for era = 1, upTo do
        for _, x in lists[era] do
            table.insert(out, x)
        end
    end
    return out
end

-- Platformele lumii 1, in ordinea tabelului (de la j6: TycoonConfig.padsOfWorld(1)).
local function world1Pads(): { TycoonConfig.Pad }
    local out = {}
    for _, p in TycoonConfig.PADS do
        if p.era <= WORLD1_ERAS then
            table.insert(out, p)
        end
    end
    return out
end

local function isNet(p: TycoonConfig.Pad): boolean
    for _, e in p.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

-- Cele trei stari ale planului: proaspata, la mijlocul Erei 2, la Works Bell cu toata lumea 1 cumparata.
local function states(
    pads: { TycoonConfig.Pad }
): { { name: string, bought: { [string]: boolean } } }
    local midEra2: { [string]: boolean } = {}
    local era2: { string } = {}
    local all: { [string]: boolean } = {}
    for _, p in pads do
        all[p.id] = true
        if p.era == 1 then
            midEra2[p.id] = true
        elseif p.era == 2 then
            table.insert(era2, p.id)
        end
    end
    for i = 1, math.floor(#era2 / 2) do
        midEra2[era2[i]] = true
    end
    return {
        { name = "fresh", bought = {} },
        { name = "mid_era2", bought = midEra2 },
        { name = "works_bell", bought = all },
    }
end

-- Nivelurile unei stari: ultima plasa detinuta la nivelul 1 (poarta `prevNetLevel` o tine pe urmatoarea conturata, cu
-- cartonasul „urca intai plasa”), restul la 10.
local function levelsOf(
    pads: { TycoonConfig.Pad },
    bought: { [string]: boolean }
): { [string]: number }
    local levels: { [string]: number } = {}
    local last: string? = nil
    for _, p in pads do
        levels[p.id] = 10
        if bought[p.id] and isNet(p) then
            last = p.id
        end
    end
    if last ~= nil then
        levels[last] = 1
    end
    return levels
end

local function world1(): string
    local out: { string } =
        { "# Martorul lumii 1 [D70, pasul j1]. Nu se editeaza de mana; vezi WorldIdentity.test." }
    local pads = world1Pads()
    local roles = flatten(StationConfig.ERA_ROLES_ALL, WORLD1_ERAS)
    local lines = flatten(StationConfig.ERA_LINES_ALL, WORLD1_ERAS)
    local sellers = {}
    for _, seller in StationConfig.SELLER_ORDER_ALL do
        if FlowConfig.SELLERS_ALL[seller].era <= WORLD1_ERAS then
            table.insert(sellers, seller)
        end
    end
    section(out, "roles", roles)
    section(out, "lines", lines)
    section(out, "sellers", sellers)

    -- platformele: locul, conditia, efectul, pretul (fara textele, care se pot reformula)
    for _, p in pads do
        section(out, "pad." .. p.id, {
            index = p.index,
            era = p.era,
            x = p.x,
            y = p.y,
            motive = p.motive,
            price = p.price,
            needs = p.needs,
            effects = p.effects,
            live = p.live,
        })
    end

    -- drumurile, puntile, curtile, decorul pus de mana, zonele, felinarele, stalpii, casele
    local g = RoadGraph.fromConfig()
    section(out, "roads.points", g.points)
    section(out, "roads.edges", g.edges)
    section(out, "roads.rects", g.rects)
    for _, d in TycoonConfig.DISTRICTS do
        if d.era <= WORLD1_ERAS then
            section(out, "district." .. tostring(d.era), d)
        end
    end
    section(out, "DECK", TycoonConfig.DECK)
    section(out, "ROADS", TycoonConfig.ROADS)
    section(out, "YARDS", TycoonConfig.YARDS)
    section(out, "DECOR", TycoonConfig.DECOR)
    section(out, "ZONES", TycoonConfig.ZONES)
    section(out, "streetLamps", TycoonConfig.streetLamps())
    section(out, "wirePoles", TycoonConfig.wirePoles())
    section(out, "homeClearRects", TycoonConfig.homeClearRects())
    section(out, "deckSpans", TycoonConfig.deckSpans())
    section(out, "decor", VillageDecor.items())

    -- locurile liniilor si ale vanzatorilor (gramezi, standuri, clienti)
    for _, line in lines do
        section(out, "LINE_PLACES." .. line, TycoonConfig.LINE_PLACES[line])
    end
    for _, seller in sellers do
        section(out, "SELLER_PLACES." .. seller, TycoonConfig.SELLER_PLACES[seller])
    end
    section(out, "PILES", TycoonConfig.PILES)
    section(out, "spots", {
        DOCK = TycoonConfig.DOCK,
        PIER = TycoonConfig.PIER,
        PIER_WALK = TycoonConfig.PIER_WALK,
        FISH_STAND = TycoonConfig.FISH_STAND,
        BOBBER_AT = TycoonConfig.BOBBER_AT,
        FERRY = TycoonConfig.FERRY,
        FERRY_BOARD = TycoonConfig.FERRY_BOARD,
        TREASURE_SLOTS = TycoonConfig.TREASURE_SLOTS,
        TAVERN = TycoonConfig.TAVERN,
        SPAWN = TycoonConfig.SPAWN,
        WHEEL_STAND = TycoonConfig.WHEEL_STAND,
        VILLAGE_BOARD = TycoonConfig.VILLAGE_BOARD,
        STORAGE = TycoonConfig.STORAGE,
        SAWMILL = TycoonConfig.SAWMILL,
    })

    -- raul, malurile, mersul pe jos (pontonul are trecere)
    section(out, "river", {
        WORLD_WIDTH = RiverConfig.WORLD_WIDTH,
        WORLD_HEIGHT = RiverConfig.WORLD_HEIGHT,
        ERA1_WORLD_WIDTH = RiverConfig.ERA1_WORLD_WIDTH,
        ERA2_WORLD_WIDTH = RiverConfig.ERA2_WORLD_WIDTH,
        RIVER_TOP = RiverConfig.RIVER_TOP,
        RIVER_BOTTOM = RiverConfig.RIVER_BOTTOM,
        LANE_YS = RiverConfig.LANE_YS,
        SHORE_FAR = RiverConfig.SHORE_FAR,
        SHORE_NEAR = RiverConfig.SHORE_NEAR,
        PLOT = RiverConfig.PLOT,
        PLOT_ERA1 = RiverConfig.PLOT_ERA1,
        PLOT_ERA2 = RiverConfig.PLOT_ERA2,
        DECOR_STRIPS = RiverConfig.DECOR_STRIPS,
        WINDOW_SECONDS = RiverConfig.WINDOW_SECONDS,
        SPAWNS_PER_WINDOW = RiverConfig.SPAWNS_PER_WINDOW,
        SPEED_MIN = RiverConfig.SPEED_MIN,
        SPEED_MAX = RiverConfig.SPEED_MAX,
    })
    section(
        out,
        "blockedRects",
        WorldMap.blockedRects(RiverConfig :: any, nil, TycoonConfig.PIER_WALK)
    )
    for _, window in { 0, 1, 777 } do
        section(
            out,
            "riverSim." .. window,
            RiverSim.schedule(RIVER_SEED, window, RiverConfig :: any)
        )
    end

    -- ce plutesc spre plase (de la marginea lumii) si darurile raului (de pe puntile cartierelor deschise)
    section(out, "catchFloat", { SPAWN_X = CatchFloat.SPAWN_X, SPEED = CatchFloat.SPEED })
    for _, p in pads do
        if isNet(p) and p.x ~= nil and p.y ~= nil then
            section(out, "catchFloat." .. p.id, {
                travel = CatchFloat.travel(p.x :: number),
                turn = CatchFloat.turnFor(p.y :: number),
            })
        end
    end
    section(out, "drift", {
        WINDOW = DriftMath.WINDOW,
        Y = DriftMath.Y,
        ENTER_X = DriftMath.ENTER_X,
        EXIT_X = DriftMath.EXIT_X,
        REACH = DriftMath.REACH,
        REACH_MARGIN = DriftMath.REACH_MARGIN,
        reaches = DriftMath.reaches(TycoonConfig.deckSpans(), function(_era: number): boolean
            return true
        end),
    })
    for _, window in { 0, 1, 2, 500 } do
        local gift = DriftMath.giftFor(RIVER_SEED, window)
        local from, to = DriftMath.reachWindow(gift)
        section(out, "drift.gift." .. window, { gift = gift, reachFrom = from, reachTo = to })
    end

    -- statusurile pe lista lumii 1, fara niveluri si cu ultima plasa la nivelul 1
    for _, st in states(pads) do
        local levels = levelsOf(pads, st.bought)
        section(out, "padStatuses." .. st.name, TycoonMath.padStatuses(st.bought, pads))
        section(
            out,
            "padStatuses." .. st.name .. ".levels",
            TycoonMath.padStatuses(st.bought, pads, levels)
        )
        section(out, "era." .. st.name, TycoonMath.era(st.bought, pads))
        local blockers = {}
        for _, p in pads do
            local b = TycoonMath.padBlocker(p, st.bought, levels, pads)
            if b ~= nil then
                blockers[p.id] = b
            end
        end
        section(out, "padBlocker." .. st.name, blockers)
    end

    -- oamenii: primul singur, apoi amandoi dintr-o pereche; cu plasele de la mijlocul Erei 2 si cu toate
    local sets = states(pads)
    for _, st in { sets[2], sets[3] } do
        local nets = VillageLook.ownedNets(st.bought)
        for _, role in roles do
            for _, pair in { { 1, 1 }, { 1, 2 }, { 2, 2 } } do
                local cycle = HandRoutes.cycleFor(role, pair[1], pair[2], nets)
                section(out, `cycle.{st.name}.{role}.{pair[1]}of{pair[2]}`, cycle.legs)
                table.insert(out, "duration=" .. encode(cycle.duration))
            end
        end
    end
    for _, role in roles do
        section(
            out,
            "stand." .. role,
            { HandRoutes.standFor(role, 1), HandRoutes.standFor(role, 2) }
        )
    end

    -- quest-urile erelor 1-3, intregi in afara de text (de la j11: chaptersOfWorld(1))
    for _, chapter in QuestConfig.ALL_CHAPTERS do
        if chapter.era > WORLD1_ERAS then
            continue
        end
        section(out, "chapter." .. chapter.id, { era = chapter.era, reward = chapter.reward })
        for _, q in chapter.quests do
            local row = table.clone(q) :: any
            row.text = nil
            table.insert(out, encode(row))
        end
    end

    return table.concat(out, "\n") .. "\n"
end

-- Ce se schimba la comutatorul l3, si numai atunci: listele motorului (dupa ENGINE_ERAS), capitolele din joc si
-- statusurile pe lista intreaga de platforme (cu Era 4 adormita, barajul nu apare nicaieri).
local function engine(): string
    local out: { string } = {
        "# Ce rescrie comutatorul l3 [D70, PLAN-MOTOR-UNIRE §16]. Nu se editeaza de mana; vezi WorldIdentity.test.",
    }
    section(out, "LINE_ORDER", StationConfig.LINE_ORDER)
    section(out, "ROLES", StationConfig.ROLES)
    section(out, "ERA_ROLES", StationConfig.ERA_ROLES)
    section(out, "SELLER_ORDER", StationConfig.SELLER_ORDER)
    local chapters = {}
    for _, chapter in QuestConfig.CHAPTERS do
        table.insert(chapters, chapter.id)
    end
    section(out, "CHAPTERS", chapters)
    for _, st in states(world1Pads()) do
        section(out, "padStatuses.all." .. st.name, TycoonMath.padStatuses(st.bought))
        section(out, "era.all." .. st.name, TycoonMath.era(st.bought))
    end
    return table.concat(out, "\n") .. "\n"
end

-- Primul rand diferit, cu o fereastra in jurul primei coloane care difera.
local function firstDifference(saved: string, now: string): string
    local a = string.split(saved, "\n")
    local b = string.split(now, "\n")
    local where = "?"
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or "<lipsa>", b[i] or "<lipsa>"
        if string.sub(x, 1, 3) == "## " then
            where = x
        end
        if x ~= y then
            local col = 1
            while col <= #x and string.sub(x, col, col) == string.sub(y, col, col) do
                col += 1
            end
            local from = math.max(1, col - 100)
            return string.format(
                "randul %d, coloana %d (%s)\n  martor: ...%s\n  acum:   ...%s",
                i,
                col,
                where,
                string.sub(x, from, col + 100),
                string.sub(y, from, col + 100)
            )
        end
    end
    return "?"
end

local function matches(path: string, now: string): boolean
    if process.env.WORLD_WITNESS == "write" then
        fs.writeFile(path, now)
        print("[WorldIdentity] martorul rescris: " .. path)
    end
    if not fs.isFile(path) then
        print("[WorldIdentity] lipseste " .. path)
        return false
    end
    local saved = fs.readFile(path)
    if saved == now then
        return true
    end
    print(`[WorldIdentity] {path}: {firstDifference(saved, now)}`)
    return false
end

return function()
    test.suite("WorldIdentity", function()
        test.case("decorul si samanta raului din martor sunt cele din joc", function()
            -- SceneArt si pamantul copt deseneaza decorul prin VillageDecor (nu cu argumente copiate)
            local scene = fs.readFile("src/Client/Controllers/SceneArt.luau")
            check.is_true(string.find(scene, "VillageDecor.items()", 1, true) ~= nil)
            check.is_true(string.find(scene, "WorldDecor.village(", 1, true) == nil)
            local geometry = fs.readFile("scripts/art/village_geometry.luau")
            check.is_true(string.find(geometry, "VillageDecor.items()", 1, true) ~= nil)
            local river = fs.readFile("src/Server/Services/RiverService.luau")
            check.is_true(string.find(river, `local BASE_SEED = {RIVER_SEED}%f[%D]`) ~= nil)
        end)

        test.case("niciun loc de unire nu e al unei linii din lumea 1", function()
            for line in TycoonConfig.JOIN_PLACES do
                check.is_true((StationConfig.ERA_OF_LINE[line] or math.huge) > WORLD1_ERAS)
            end
        end)

        test.case("lumea 1 e exact cea din martor (tests/witness/world1.txt)", function()
            check.is_true(matches(WORLD1, world1()))
        end)

        test.case("listele motorului, de rescris doar la l3 (tests/witness/engine.txt)", function()
            check.is_true(matches(ENGINE, engine()))
        end)
    end)
end
