--!strict
-- [D62, pasul 5] GEOMETRIA SATULUI, scoasa din modulele jocului, pentru `village_ground.py`.
--
-- Pamantul copt trebuie sa cada EXACT pe ce stie jocul: linia apei (Shoreline.edgeY, aceeasi pe care testele o tin
-- departe de benzile bunurilor si de punte), puntea, drumurile pe care merg oamenii, curtile, locurile cladirilor,
-- copacii imprastiati din seed. Un port al lui Shoreline in Python ar fi fost a doua sursa pentru aceleasi cifre; asa,
-- Python doar citeste ce scrie jocul. Iese JSON pe stdout.
--
-- Rulare: lune run scripts/art/village_geometry [lume]   (il cheama village_ground.py; fara lume, satul)
--
-- [D70, pasul k12] `lume` = 2: barajul (TycoonConfig.WORLDS[2], RiverConfig.WORLDS[2]), cu zidul, apa si cladirile lui in
-- cheia `dam`. Lumea 1 iese exact ca inainte, cheie cu cheie (amprenta din village_ground.lock nu se misca).
local process = require("@lune/process")
local serde = require("@lune/serde")

local RiverConfig = require("../../src/Shared/Config/RiverConfig")
local TycoonConfig = require("../../src/Shared/Config/TycoonConfig")
local Shoreline = require("../../src/Shared/Modules/Shoreline")
local VillageDecor = require("../../src/Shared/Modules/VillageDecor")
local WorldConfig = require("../../src/Shared/Config/WorldConfig")

-- aceeasi constanta ca in SceneArt (linia padurii); decorul imprastiat vine din VillageDecor, ca in joc
local FOREST_SEED = 480917
local STEP = 3 -- un pixel de imagine = 3 pixeli de lume

local WORLD = WorldConfig.sanitize(tonumber(process.args[1]))
local DAM = WORLD ~= 1
-- raul lumii: pentru lumea 1 e o copie a lui RiverConfig, cu aceleasi valori si aceleasi obiecte de mal
local river = (RiverConfig.WORLDS :: any)[WORLD]

local W, H = river.WORLD_WIDTH, river.WORLD_HEIGHT

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
-- [D70] platformele lumii coapte. In sat, doar cele care se deseneaza (`live`): ale unei ere inca inchise au deja locul
-- lor in config, dar pamantul lor se coace odata cu harta cartierului [D65, docs/PLAN-ERA2.md]. [k12] La baraj, toate:
-- imaginea lui se vede doar in lumea 2, iar l3 le face `live` fara sa mute amprenta (platformele intra doar in planse).
for _, p in TycoonConfig.padsOfWorld(WORLD) do
    if p.x ~= nil and p.y ~= nil and (p.live or DAM) then
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
local scattered = VillageDecor.items(WORLD)

local stripEnds = {}
for _, strip in river.DECOR_STRIPS do
    table.insert(stripEnds, strip.x1)
end

-- [D65] CARTIERELE, fiecare cu puntea, drumurile si curtile lui. Id-urile ies CANONICE (cele din The Landing, prin
-- `like`), ca pamantul copt sa deseneze aceleasi detalii in fiecare: piata de piatra, potecile dintre case, zgura din
-- curtea cuptorului. Un cartier intra aici doar cand se deseneaza in joc (are platforme `live`).
-- [k12] La baraj intra toate cartierele (imaginea lui se vede doar acolo), iar fiecare drum si curte isi pastreaza si
-- id-ul lui (`own`): acolo mai multe curti oglindesc aceeasi curte din The Landing (cincisprezece case), iar pamantul
-- copt alege dupa `own` ce se vede pe jos (zgura la Kiln, aschii de cupru la Cable Works).
local districts = {}
for _, d in TycoonConfig.districtsOf(WORLD) do
    local built = DAM
    for _, p in TycoonConfig.PADS do
        if p.era == d.era and p.live then
            built = true
        end
    end
    if built then
        local roads, yards = {}, {}
        for _, r in d.roads do
            local road: { [string]: any } =
                { id = r.like or r.id, x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 }
            if DAM then
                road.own = r.id
            end
            table.insert(roads, road)
        end
        for _, y in d.yards do
            local yard: { [string]: any } =
                { id = y.like or y.id, x0 = y.x0, x1 = y.x1, y0 = y.y0, y1 = y.y1 }
            if DAM then
                yard.own = y.id
            end
            table.insert(yards, yard)
        end
        table.insert(
            districts,
            { id = d.id, era = d.era, deck = d.deck, roads = roads, yards = yards }
        )
    end
end

local out: { [string]: any } = {
    step = STEP,
    world = { w = W, h = H },
    far = edgeSamples(river.SHORE_FAR),
    near = edgeSamples(river.SHORE_NEAR),
    treeLine = treeYs,
    plot = river.PLOT,
    -- latimea unei felii de pamant copt, in pixeli de lume: Roblox micsoreaza orice imagine peste 1024, deci lumea
    -- (3840 / 3 = 1280 px) se coace pe felii de 2880 (960 px)
    tile = river.BAKE_SLICE, -- [D70] felia de coacere (era aceeasi cifra ca ERA1_WORLD_WIDTH)
    -- [D67] marginile din dreapta ale fasiilor de dupa satul vechi (Moara, Wire Works): ce se imprastie la intamplare
    -- se imprastie pe fiecare fasie cu samanta ei, ca o fasie noua sa nu mute nimic din cele de dinainte
    strips = stripEnds,
    districts = districts,
    pierWalk = TycoonConfig.PIER_WALK,
    decor = TycoonConfig.decorOf(WORLD),
    scattered = scattered,
    pads = pads,
    spots = if DAM then { spawn = TycoonConfig.spawnOf(WORLD) } else {
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

-- [k12] BARAJUL: zidul, apa (lacul, deversorul, canalul), unde nu se merge, turbina, cladirile, casutele, stalpii si
-- cardurile, exact ca in TycoonConfig.WORLDS[2] (la `Box`, x/y e coltul din stanga-sus la zid si apa, mijlocul bazei la
-- cladiri si casute)
if DAM then
    local world = (TycoonConfig.WORLDS :: any)[WORLD]
    out.dam = {
        wall = world.wall,
        water = world.water,
        blocked = world.blocked,
        turbine = world.turbine,
        buildings = world.buildings,
        cottages = world.cottages,
        pylons = world.pylons,
        cards = world.cards,
    }
end

print(serde.encode("json", out))
