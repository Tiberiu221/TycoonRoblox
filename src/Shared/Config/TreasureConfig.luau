--!strict
-- [D59] CE ADUCE RAUL: din cand in cand vine pe rau ceva ce plasele nu prind -- o sticla cu bilet, un cufar, un
-- bustean de aur -- si se opreste la ponton. Te asteapta, nu pleaca [nimic nu se pierde]; cat lipsesti se aduna cel
-- mult trei, iar cat sunt trei, ceasul nu merge. Il scoti cu undita (aceeasi bara, alta dificultate).
--
-- Doar perle, ca pescuitul (vezi FishConfig). Valorile sunt FIXE: cardul poate spune dinainte ce primesti [D40].
local TreasureConfig = {}

export type Kind = {
    id: string,
    name: string, -- pe card si in jurnal
    phrase: string, -- in propozitii: "A chest drifted to your pier"
    pearls: number,
    weight: number,
    difficulty: number, -- bara din ReelMath
}

TreasureConfig.KINDS = {
    {
        id = "bottle",
        name = "Bottle",
        phrase = "a bottle",
        pearls = 5,
        weight = 60,
        difficulty = 1,
    },
    { id = "chest", name = "Chest", phrase = "a chest", pearls = 15, weight = 32, difficulty = 3 },
    {
        id = "golden",
        name = "Golden Driftwood",
        phrase = "Golden Driftwood",
        pearls = 40,
        weight = 8,
        difficulty = 4,
    },
} :: { Kind }

TreasureConfig.MAX_WAITING = 3
-- Intervalul dintre doua, pe ceasul de perete (os.time): merge si cat lipsesti, pana la plafon.
TreasureConfig.INTERVAL_MIN = 240
TreasureConfig.INTERVAL_MAX = 480
-- Primul vine la atat dupa primul tau peste si e mereu o sticla: biletul ei spune cum merge (NOTES[1]).
TreasureConfig.FIRST_DELAY = 45
TreasureConfig.FIRST_KIND = "bottle"

-- Biletele din sticle, in ordinea in care le gasesti; dupa ultimul se reiau. FIECARE E ADEVARAT in jocul de azi [D40]
-- -- cand se schimba o regula, se schimba si biletul ei.
TreasureConfig.NOTES = {
    "Up to three things wait at your pier. Hook them with your rod.",
    "Everything that floats past is money.",
    "The slowest step in a line decides what the whole line earns.",
    "A fish that swims out of the light only takes longer. It never gets away.",
    "Golden bait doubles the pearls from your next fish.",
    "Pearls dress up your village. Coins build everything else.",
    "The first catch of every kind of fish is worth five extra pearls.",
    "The Lucky Wheel turns once a day. Every prize is a gift from the river.",
    "Catch every fish in the Journal and the river will dress you as a legend.",
    "A second worker in a hut doubles the people on that job.",
} :: { string }

TreasureConfig.byId = {} :: { [string]: Kind }
for _, k in TreasureConfig.KINDS do
    TreasureConfig.byId[k.id] = k
end

return TreasureConfig
