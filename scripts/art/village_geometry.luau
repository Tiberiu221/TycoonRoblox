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

local scattered = WorldDecor.build(DECOR_SEED, {
    width = W,
    height = H,
    riverTop = RiverConfig.SHORE_FAR.baseY - RiverConfig.SHORE_FAR.amp,
    riverBottom = RiverConfig.SHORE_NEAR.baseY + RiverConfig.SHORE_NEAR.amp,
    plot = RiverConfig.PLOT,
}, DECOR_COUNT)

local out = {
    step = STEP,
    world = { w = W, h = H },
    far = edgeSamples(RiverConfig.SHORE_FAR),
    near = edgeSamples(RiverConfig.SHORE_NEAR),
    treeLine = treeYs,
    plot = RiverConfig.PLOT,
    deck = TycoonConfig.DECK,
    pierWalk = TycoonConfig.PIER_WALK,
    roads = TycoonConfig.ROADS,
    yards = TycoonConfig.YARDS,
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
