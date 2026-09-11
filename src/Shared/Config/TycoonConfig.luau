--!strict
-- Datele tycoon-ului tradus 1:1 din scripts/economy/sim_tycoon.py [F0 spec 1.1]. NU se editeaza
-- preturile aici de mana -- ele vin din simulator; acest fisier doar le transporta in joc.
-- Fara tipuri Roblox: fisierul e incarcat si de testele Lune.
--
-- Fraza jucatorului: "This stretch of river is yours. Everything that floats past is money."

export type Effect = {
    kind: string, -- "net" | "flag" | "mul" | "add" | "build" | "upgrade" | "refine"
    rate: number?,
    lane: number?, -- net: items/s, banda (1 = cea mai apropiata de malul jucatorului)
    field: string?, -- flag/mul/add: campul din State (camelCase)
    factor: number?,
    amount: number?, -- mul/upgrade/refine: factor; add: cantitate
    good: string?,
    mult: number?,
    cap: number?,
    draw: number?, -- build/upgrade/refine
}

export type Pad = {
    id: string,
    index: number,
    name: string,
    era: number,
    motive: string, -- "C" prinzi mai mult | "V" vinzi mai scump | "A" scapi de o corvoada | "D" deschide urmatorul
    price: number,
    effects: { Effect },
    live: boolean, -- efectul e implementat in F0; altfel platforma exista doar in plan
    x: number?,
    y: number?,
}

export type Good = { id: string, value: number, share: number, minLanes: number? }

local TycoonConfig = {}

-- ---- efecte, in oglinda cu net()/mul()/on()/plus()/build()/upgrade()/refine() din simulator ----
local function netEffect(rate: number, lane: number): Effect
    return { kind = "net", rate = rate, lane = lane }
end
local function mulEffect(field: string, factor: number): Effect
    return { kind = "mul", field = field, factor = factor }
end
local function flagEffect(field: string): Effect
    return { kind = "flag", field = field }
end
local function addEffect(field: string, amount: number): Effect
    return { kind = "add", field = field, amount = amount }
end
local function buildEffect(good: string, mult: number, cap: number, draw: number): Effect
    return { kind = "build", good = good, mult = mult, cap = cap, draw = draw }
end
local function upgradeEffect(good: string, factor: number): Effect
    return { kind = "upgrade", good = good, factor = factor }
end
local function refineEffect(good: string, factor: number): Effect
    return { kind = "refine", good = good, factor = factor }
end

local function pad(t: Pad): Pad
    return t
end

-- Bunurile pe care le aduce raul, in ORDINEA simulatorului -- ordinea conteaza pentru paritatea
-- in virgula mobila (suma nu e asociativa). minLanes: sub acel numar de benzi, ponderea bunului
-- cade pe driftwood (exact ca la pop() din Python).
TycoonConfig.GOODS = {
    { id = "driftwood", value = 1.0, share = 0.70 },
    { id = "scrap", value = 2.0, share = 0.13, minLanes = 2 },
    { id = "reeds", value = 2.0, share = 0.08 },
    { id = "shards", value = 2.5, share = 0.04, minLanes = 3 },
    { id = "named", value = 14.0, share = 0.05 },
} :: { Good }

-- Valoarea de vanzare a unui obiect cu nume, pe tier (ipoteza -- media ponderata ~14, cat cere GOODS.named)
TycoonConfig.NAMED_VALUE = {
    common = 6,
    uncommon = 11,
    rare = 22,
    epic = 45,
    legendary = 90,
    mythic = 180,
}

-- Toate constantele pe care income() din simulator le are batute in cuie. Un singur loc, ca sa nu
-- se dezalinieze de restul TycoonMath (sellMultiplier foloseste aceleasi trei de la coada).
TycoonConfig.MODEL = {
    manualEff = 0.70,
    manualEffBigSack = 0.82,
    manualCrowd = 0.08,
    netsPerRunner = 3,
    millerMult = 1.2,
    boatYield = 0.35,
    dockhandMult = 1.2,
    indexBonus = 0.01,
    rebirthBonus = 0.5,
}

TycoonConfig.REAL = 1.8 -- jucator real ~1.8x mai lent decat cel lacom (ipoteza, de masurat)
TycoonConfig.TARGET_WAIT = { base = 20, growth = 1.125, cap = 420 }
TycoonConfig.NICE =
    { 1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 7.5, 8, 9 }

TycoonConfig.NET_CAPACITY = 12
TycoonConfig.SACK_CAPACITY = 30
TycoonConfig.SACK_BIG_CAPACITY = 60
TycoonConfig.PAD_SIZE = 96

TycoonConfig.DOCK = { x = 330, y = 800 } -- debarcaderul e prefabricat; locul de vanzare e capatul de mal
TycoonConfig.LANE_Y = { 732, 660, 588 } -- banda 1 e cea mai aproape de mal
TycoonConfig.SPAWN = { x = 560, y = 920 }

-- Cele 48 de platforme, in ordine. Preturile NU se calculeaza aici -- vin exact din simulator
-- (sim_tycoon.py, tura 1, lacom). Pozitii doar pentru Era 1; erele urmatoare nu au inca lume construita.
TycoonConfig.PADS = {
    -- ---- Era 1 · The Landing ----
    pad({
        id = "first_net",
        index = 1,
        name = "First Net",
        era = 1,
        motive = "C",
        price = 0,
        effects = { netEffect(0.33, 1) },
        live = true,
        x = 500,
        y = 840,
    }),
    pad({
        id = "second_net",
        index = 2,
        name = "Second Net",
        era = 1,
        motive = "C",
        price = 9,
        effects = { netEffect(0.33, 1) },
        live = true,
        x = 640,
        y = 840,
    }),
    pad({
        id = "bigger_sack",
        index = 3,
        name = "Bigger Sack",
        era = 1,
        motive = "A",
        price = 18,
        effects = { flagEffect("sackBig") },
        live = true,
        x = 470,
        y = 990,
    }),
    pad({
        id = "third_net",
        index = 4,
        name = "Third Net",
        era = 1,
        motive = "C",
        price = 25,
        effects = { netEffect(0.33, 1) },
        live = true,
        x = 780,
        y = 840,
    }),
    pad({
        id = "sorting_crate",
        index = 5,
        name = "Sorting Crate",
        era = 1,
        motive = "V",
        price = 40,
        effects = { mulEffect("priceMult", 1.20) },
        live = true,
        x = 330,
        y = 990,
    }),
    pad({
        id = "first_runner",
        index = 6,
        name = "First Runner",
        era = 1,
        motive = "A",
        price = 50,
        effects = { addEffect("runners", 1) },
        live = false, -- mainile (hands) vin in F1
        x = 610,
        y = 990,
    }),
    pad({
        id = "far_lane_net",
        index = 7,
        name = "Far-Lane Net",
        era = 1,
        motive = "C",
        price = 80,
        effects = { netEffect(0.40, 2), addEffect("lanes", 1) },
        live = true,
        x = 920,
        y = 840,
    }),
    pad({
        id = "weighted_nets",
        index = 8,
        name = "Weighted Nets",
        era = 1,
        motive = "C",
        price = 130,
        effects = { mulEffect("rateMult", 1.30) },
        live = true,
        x = 750,
        y = 990,
    }),
    pad({
        id = "workshop",
        index = 9,
        name = "Workshop",
        era = 1,
        motive = "V",
        price = 200,
        effects = { addEffect("indexFound", 6) },
        live = false, -- Index-ul real inlocuieste proxy-ul; nu inca in F0
        x = 1030,
        y = 1000,
    }),
    pad({
        id = "fifth_net",
        index = 10,
        name = "Fifth Net",
        era = 1,
        motive = "C",
        price = 220,
        effects = { netEffect(0.40, 1) },
        live = true,
        x = 1060,
        y = 840,
    }),
    pad({
        id = "dock_stall",
        index = 11,
        name = "Dock Stall",
        era = 1,
        motive = "V",
        price = 300,
        effects = { mulEffect("priceMult", 1.25) },
        live = true,
        x = 330,
        y = 1130,
    }),
    pad({
        id = "landing_bell",
        index = 12,
        name = "Landing Bell",
        era = 1,
        motive = "D",
        price = 450,
        effects = { mulEffect("bells", 1.10) },
        live = false, -- renasterea/clopotele vin mai tarziu
        x = 680,
        y = 1140,
    }),

    -- ---- Era 2 · The Mill ----
    pad({
        id = "sawmill",
        index = 13,
        name = "Sawmill",
        era = 2,
        motive = "V",
        price = 550,
        effects = { buildEffect("driftwood", 3.0, 1.6, 4.0), addEffect("crank", 0.35) },
        live = false,
    }),
    pad({
        id = "water_wheel",
        index = 14,
        name = "Water Wheel",
        era = 2,
        motive = "V",
        price = 750,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "flume",
        index = 15,
        name = "Flume",
        era = 2,
        motive = "A",
        price = 1200,
        effects = { flagEffect("flume") },
        live = false,
    }),
    pad({
        id = "sixth_net",
        index = 16,
        name = "Sixth Net",
        era = 2,
        motive = "C",
        price = 1500,
        effects = { netEffect(0.45, 2) },
        live = false,
    }),
    pad({
        id = "smelter",
        index = 17,
        name = "Smelter",
        era = 2,
        motive = "V",
        price = 2000,
        effects = { buildEffect("scrap", 3.0, 1.0, 5.0) },
        live = false,
    }),
    pad({
        id = "miller",
        index = 18,
        name = "Miller",
        era = 2,
        motive = "V",
        price = 2500,
        effects = { flagEffect("miller") },
        live = false,
    }),
    pad({
        id = "loom",
        index = 19,
        name = "Loom",
        era = 2,
        motive = "V",
        price = 3500,
        effects = { buildEffect("reeds", 3.0, 0.8, 6.0) },
        live = false,
    }),
    pad({
        id = "wide_nets",
        index = 20,
        name = "Wide Nets",
        era = 2,
        motive = "C",
        price = 4000,
        effects = { mulEffect("rateMult", 1.40) },
        live = false,
    }),
    pad({
        id = "seventh_net",
        index = 21,
        name = "Seventh Net",
        era = 2,
        motive = "C",
        price = 6000,
        effects = { netEffect(0.50, 1) },
        live = false,
    }),
    pad({
        id = "second_wheel",
        index = 22,
        name = "Second Wheel",
        era = 2,
        motive = "V",
        price = 7500,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "market",
        index = 23,
        name = "Market",
        era = 2,
        motive = "V",
        price = 9000,
        effects = { mulEffect("priceMult", 1.25) },
        live = false,
    }),
    pad({
        id = "mill_bell",
        index = 24,
        name = "Mill Bell",
        era = 2,
        motive = "D",
        price = 12000,
        effects = { mulEffect("bells", 1.15) },
        live = false,
    }),

    -- ---- Era 3 · The Yard ----
    pad({
        id = "crane",
        index = 25,
        name = "Crane",
        era = 3,
        motive = "V",
        price = 15000,
        effects = { mulEffect("namedMult", 1.5) },
        live = false,
    }),
    pad({
        id = "eighth_net",
        index = 26,
        name = "Eighth Net",
        era = 3,
        motive = "C",
        price = 20000,
        effects = { netEffect(0.55, 2) },
        live = false,
    }),
    pad({
        id = "sorting_shed",
        index = 27,
        name = "Sorting Shed",
        era = 3,
        motive = "V",
        price = 25000,
        effects = { addEffect("indexFound", 6) },
        live = false,
    }),
    pad({
        id = "sawmill_2",
        index = 28,
        name = "Sawmill II",
        era = 3,
        motive = "V",
        price = 28000,
        effects = { upgradeEffect("driftwood", 2.0) },
        live = false,
    }),
    pad({
        id = "ninth_net",
        index = 29,
        name = "Ninth Net",
        era = 3,
        motive = "C",
        price = 30000,
        effects = { netEffect(0.55, 1) },
        live = false,
    }),
    pad({
        id = "fine_ingots",
        index = 30,
        name = "Fine Ingots",
        era = 3,
        motive = "V",
        price = 35000,
        effects = { refineEffect("scrap", 1.5) },
        live = false,
    }),
    pad({
        id = "dockhand",
        index = 31,
        name = "Dockhand",
        era = 3,
        motive = "V",
        price = 40000,
        effects = { flagEffect("dockhand") },
        live = false,
    }),
    pad({
        id = "deep_channel",
        index = 32,
        name = "Deep Channel",
        era = 3,
        motive = "C",
        price = 45000,
        effects = { netEffect(0.60, 3), addEffect("lanes", 1) },
        live = false,
    }),
    pad({
        id = "kiln",
        index = 33,
        name = "Kiln",
        era = 3,
        motive = "V",
        price = 50000,
        effects = { buildEffect("shards", 3.0, 0.6, 8.0) },
        live = false,
    }),
    pad({
        id = "third_wheel",
        index = 34,
        name = "Third Wheel",
        era = 3,
        motive = "V",
        price = 55000,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "salvage_hall",
        index = 35,
        name = "Salvage Hall",
        era = 3,
        motive = "V",
        price = 60000,
        effects = { mulEffect("namedMult", 1.3) },
        live = false,
    }),
    pad({
        id = "yard_bell",
        index = 36,
        name = "Yard Bell",
        era = 3,
        motive = "D",
        price = 70000,
        effects = { mulEffect("bells", 1.20) },
        live = false,
    }),

    -- ---- Era 4 · The Harbor ----
    pad({
        id = "boathouse",
        index = 37,
        name = "Boathouse",
        era = 4,
        motive = "C",
        price = 75000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "tenth_net",
        index = 38,
        name = "Tenth Net",
        era = 4,
        motive = "C",
        price = 80000,
        effects = { netEffect(0.65, 3) },
        live = false,
    }),
    pad({
        id = "fine_cloth",
        index = 39,
        name = "Fine Cloth",
        era = 4,
        motive = "V",
        price = 90000,
        effects = { refineEffect("reeds", 1.5) },
        live = false,
    }),
    pad({
        id = "deep_nets",
        index = 40,
        name = "Deep Nets",
        era = 4,
        motive = "C",
        price = 100000,
        effects = { mulEffect("rateMult", 1.30) },
        live = false,
    }),
    pad({
        id = "second_boat",
        index = 41,
        name = "Second Boat",
        era = 4,
        motive = "C",
        price = 110000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "glazed_pottery",
        index = 42,
        name = "Glazed Pottery",
        era = 4,
        motive = "V",
        price = 120000,
        effects = { refineEffect("shards", 1.5) },
        live = false,
    }),
    pad({
        id = "eleventh_net",
        index = 43,
        name = "Eleventh Net",
        era = 4,
        motive = "C",
        price = 130000,
        effects = { netEffect(0.70, 2) },
        live = false,
    }),
    pad({
        id = "lighthouse",
        index = 44,
        name = "Lighthouse",
        era = 4,
        motive = "V",
        price = 150000,
        effects = { mulEffect("priceMult", 1.25) },
        live = false,
    }),
    pad({
        id = "third_boat",
        index = 45,
        name = "Third Boat",
        era = 4,
        motive = "C",
        price = 160000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "grand_market",
        index = 46,
        name = "Grand Market",
        era = 4,
        motive = "V",
        price = 180000,
        effects = { mulEffect("priceMult", 1.30) },
        live = false,
    }),
    pad({
        id = "twelfth_net",
        index = 47,
        name = "Twelfth Net",
        era = 4,
        motive = "C",
        price = 200000,
        effects = { netEffect(0.75, 3) },
        live = false,
    }),
    pad({
        id = "the_charter",
        index = 48,
        name = "The Charter",
        era = 4,
        motive = "D",
        price = 220000,
        effects = { mulEffect("bells", 1.25) },
        live = false,
    }),
} :: { Pad }

-- Index construit o singura data la incarcare, ca PadService sa nu caute liniar prin 48 de intrari
-- la fiecare cumparare.
local byId: { [string]: Pad } = {}
for _, p in TycoonConfig.PADS do
    byId[p.id] = p
end
TycoonConfig.byId = byId

return TycoonConfig
