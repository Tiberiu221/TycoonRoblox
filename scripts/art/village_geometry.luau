--!strict
-- [D62, pasul 5] GEOMETRIA SATULUI, scoasa din modulele jocului, pentru `village_ground.py`.
--
-- Pamantul copt trebuie sa cada EXACT pe ce stie jocul: linia apei (Shoreline.edgeY, aceeasi pe care testele o tin
-- departe de benzile bunurilor si de punte), puntea, drumurile pe care merg oamenii, curtile, locurile cladirilor,
-- copacii imprastiati din seed. Un port al lui Shoreline in Python ar fi fost a doua sursa pentru aceleasi cifre; asa,
-- Python doar citeste ce scrie jocul. Iese JSON pe stdout.
--
-- Rulare: lune run scripts/art/village_geometry   (il cheama village_ground.py)
local serde = require("@lune/serde")

local RiverConfig = require("../../src/Shared/Config/RiverConfig")
local TycoonConfig = require("../../src/Shared/Config/TycoonConfig")
local Shoreline = require("../../src/Shared/Modules/Shoreline")
local WorldDecor = require("../../src/Shared/Modules/WorldDecor")

-- aceleasi constante ca in SceneArt (decorul imprastiat si linia padurii)
local DECOR_COUNT = 130
local DECOR_SEED = 20260910
local FOREST_SEED = 480917
local STEP = 3 -- un pixel de imagine = 3 pixeli de lume

local W, H = RiverConfig.WORLD_WIDTH, RiverConfig.WORLD_HEIGHT

local function edgeSamples(e: Shoreline.Edge): { y: { number }, beach: { number } }
    local ys: { number } = {}
    local beaches: { number } = {}
    local x = STEP / 2
    while x < W do
        table.insert(ys, Shoreline.edgeY(e, x))
        table.insert(beaches, Shoreline.beachWidth(e, x))
        x += STEP
    end
    return { y = ys, beach = beaches }
end

local treeLine: Shoreline.Edge = { seed = FOREST_SEED, baseY = 312, amp = 96, side = -1 }
local treeYs: { number } = {}
do
    local x = STEP / 2
    while x < W do
        table.insert(treeYs, Shoreline.edgeY(treeLine, x))
        x += STEP
    end
end

local pads: { { id: string, x: number, y: number, net: boolean } } = {}
for _, p in TycoonConfig.PADS do
    -- doar platformele care se deseneaza (`live`): ale unei ere inca inchise au deja locul lor in config, dar pamantul
    -- lor se coace odata cu harta cartierului [D65, docs/PLAN-ERA2.md]
    if p.x ~= nil and p.y ~= nil and p.live then
        local net = false
        for _, e in p.effects do
            if e.kind == "net" then
                net = true
            end
        end
        table.insert(pads, { id = p.id, x = p.x, y = p.y, net = net })
    end
end

-- acelasi decor ca in joc (SceneArt): partea veche a satului isi tine copacii pe loc, fasia noua ii primeste pe ai ei
local scattered = WorldDecor.village(DECOR_SEED, DECOR_COUNT, {
    width = W,
    height = H,
    oldWidth = RiverConfig.ERA1_WORLD_WIDTH,
}, {
    riverTop = RiverConfig.SHORE_FAR.baseY - RiverConfig.SHORE_FAR.amp,
    riverBottom = RiverConfig.SHORE_NEAR.baseY + RiverConfig.SHORE_NEAR.amp,
}, RiverConfig.PLOT, RiverConfig.PLOT_ERA1, TycoonConfig.homeClearRects())

-- [D65] CARTIERELE, fiecare cu puntea, drumurile si curtile lui. Id-urile ies CANONICE (cele din The Landing, prin
-- `like`), ca pamantul copt sa deseneze aceleasi detalii in fiecare: piata de piatra, potecile dintre case, zgura din
-- curtea cuptorului. Un cartier intra aici doar cand se deseneaza in joc (are platforme `live`).
local districts = {}
for _, d in TycoonConfig.DISTRICTS do
    local built = false
    for _, p in TycoonConfig.PADS do
        if p.era == d.era and p.live then
            built = true
        end
    end
    if built then
        local roads, yards = {}, {}
        for _, r in d.roads do
            table.insert(roads, { id = r.like or r.id, x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 })
        end
        for _, y in d.yards do
            table.insert(yards, { id = y.like or y.id, x0 = y.x0, x1 = y.x1, y0 = y.y0, y1 = y.y1 })
        end
        table.insert(districts, { id = d.id, era = d.era, deck = d.deck, roads = roads, yards = yards })
    end
end

local out = {
    step = STEP,
    world = { w = W, h = H },
    far = edgeSamples(RiverConfig.SHORE_FAR),
    near = edgeSamples(RiverConfig.SHORE_NEAR),
    treeLine = treeYs,
    plot = RiverConfig.PLOT,
    -- latimea unei felii de pamant copt, in pixeli de lume: Roblox micsoreaza orice imagine peste 1024, deci lumea
    -- (3840 / 3 = 1280 px) se coace pe felii de 2880 (960 px)
    tile = RiverConfig.ERA1_WORLD_WIDTH,
    districts = districts,
    pierWalk = TycoonConfig.PIER_WALK,
    decor = TycoonConfig.DECOR,
    scattered = scattered,
    pads = pads,
    spots = {
        tavern = TycoonConfig.TAVERN,
        storage = TycoonConfig.STORAGE,
        sawmill = TycoonConfig.SAWMILL,
        dock = TycoonConfig.DOCK,
        spawn = TycoonConfig.SPAWN,
        wheel = TycoonConfig.WHEEL_STAND,
        board = TycoonConfig.VILLAGE_BOARD,
        sawmillStand = TycoonConfig.SAWMILL_STAND,
        forgeStand = TycoonConfig.WORKSHOP_STAND,
    },
}

print(serde.encode("json", out))
