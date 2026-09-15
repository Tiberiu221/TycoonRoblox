--!strict
-- [D59] UNDITA TA: pestii raului si cat valoreaza. Owner-ul (2026-09-15): "A si B cum recomanzi, apuca-te" -- A e
-- undita de la capatul pontonului, jocul dintre asteptari: arunci, musca, tii apasat cat pestele sta in zona luminoasa.
-- Nu exista esec: daca iese din zona, doar dureaza mai mult (ReelMath).
--
-- PESCUITUL DA DOAR PERLE. Monedele vin din lant, iar simulatorul (sim_tycoon.py) e sursa preturilor lor [D51]; un
-- pescuit care da monede ar fi scurtat Era 1 exact pentru cine pescuieste, fara ca vreun pret sa stie. Perlele cumpara
-- doar aspect (VillageConfig), deci aici nu se poate cumpara nimic care sa schimbe venitul [D59, amendeaza D46 pct. 4].
--
-- Fisier separat de TycoonConfig: simulatorul leaga pretul unei platforme de primul `id = "..."` din acel fisier.
local FishConfig = {}

-- Raritatile: aceleasi nume si culori ca RiverConfig.TIERS (fara mythic). `difficulty` alege bara din ReelMath.
export type Tier = { id: string, weight: number, pearls: number, difficulty: number }
export type Species = { id: string, name: string, tier: string, minCm: number, maxCm: number }

-- Ponderile se aduna la 100. Perlele pe peste: comun si neobisnuit tot 1 -- diferenta o face jurnalul (+5 la prima
-- prindere a fiecarei specii), nu o pata de 1 perla in plus [PearlBudget.test].
FishConfig.TIERS = {
    { id = "common", weight = 50, pearls = 1, difficulty = 1 },
    { id = "uncommon", weight = 27, pearls = 1, difficulty = 2 },
    { id = "rare", weight = 14, pearls = 2, difficulty = 3 },
    { id = "epic", weight = 7, pearls = 5, difficulty = 4 },
    { id = "legendary", weight = 2, pearls = 12, difficulty = 5 },
} :: { Tier }

-- Cele 12 specii ale jurnalului, in ordinea din jurnal. Iconitele: Assets.fish[id] (scripts/art/d59.py).
FishConfig.SPECIES = {
    { id = "minnow", name = "Minnow", tier = "common", minCm = 4, maxCm = 9 },
    { id = "roach", name = "Roach", tier = "common", minCm = 12, maxCm = 30 },
    { id = "perch", name = "Perch", tier = "common", minCm = 15, maxCm = 35 },
    { id = "bream", name = "Bream", tier = "uncommon", minCm = 25, maxCm = 55 },
    { id = "trout", name = "Trout", tier = "uncommon", minCm = 25, maxCm = 60 },
    { id = "chub", name = "Chub", tier = "uncommon", minCm = 25, maxCm = 55 },
    { id = "carp", name = "Carp", tier = "rare", minCm = 35, maxCm = 85 },
    { id = "eel", name = "Eel", tier = "rare", minCm = 40, maxCm = 110 },
    { id = "pike", name = "Pike", tier = "epic", minCm = 50, maxCm = 120 },
    { id = "catfish", name = "Catfish", tier = "epic", minCm = 60, maxCm = 160 },
    { id = "sturgeon", name = "Sturgeon", tier = "legendary", minCm = 100, maxCm = 240 },
    { id = "goldcarp", name = "Golden Carp", tier = "legendary", minCm = 40, maxCm = 90 },
} :: { Species }

FishConfig.FIRST_CATCH_BONUS = 5 -- perle la prima prindere a unei specii: jurnalul se completeaza cu un motiv
FishConfig.BAIT_MULTIPLIER = 2 -- momeala aurie (premiu al roatii): perlele pestelui x2, cate o momeala pe peste

-- Ceasul unei aruncari, in secunde. Clipa muscaturii o alege serverul (`biteAt` absolut, ora serverului).
FishConfig.BITE_MIN = 3
FishConfig.BITE_MAX = 8
-- O aruncare lasata in apa: serverul o uita dupa atat de la muscatura. Nu e un ceas de pierdut ceva -- pestele nu era
-- inca al tau, iar cardul ramane `Cast (E)`.
FishConfig.EXPIRE_AFTER_BITE = 90
-- Cat de devreme poate veni scoaterea fata de cel mai bun jucator posibil pe aceeasi bara (latenta, cadre).
FishConfig.LAND_TOLERANCE = 0.3
-- Doar pentru bugetul perlelor: cat dureaza aruncarea si aratarea rezultatului, in afara muscaturii si a barei.
FishConfig.CAST_SECONDS = 1.0
FishConfig.RESULT_SECONDS = 1.2

FishConfig.tierById = {} :: { [string]: Tier }
for _, t in FishConfig.TIERS do
    FishConfig.tierById[t.id] = t
end
FishConfig.byId = {} :: { [string]: Species }
for _, s in FishConfig.SPECIES do
    FishConfig.byId[s.id] = s
end

return FishConfig
