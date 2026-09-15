--!strict
-- Roata norocului, copiata dupa Idle Miner [poza 7, la cererea explicita a owner-ului].
--
-- ASTA SCHIMBA O REGULA A PROIECTULUI. P4 spunea "banii cumpara viteza, spatiu, aspect; niciodata
-- noroc". Owner-ul a decis sa o luam ca la ei, deci regula se restrange: niciodata noroc care
-- SCADE ceva ce ai. Vezi D46 in docs/DECIZII.md. Doua limite raman, si nu se negociaza:
--   * niciun premiu nu ia nimic -- toate sunt in plus [P2 intact];
--   * rotirea e GRATUITA, o data la 24h. Rotiri cumparate nu intra: D20 spune "zero paid random
--     items", si obiectele aleatorii platite au reguli proprii de dezvaluire pe Roblox.
--
-- [D59] DARURILE RAULUI, FARA MONEDE. Owner-ul: "sa slefuim lucky wheel, nu prea se integreaza cu cap". Roata sta acum
-- pe punte, ca un timonier, iar premiile ei sunt ale pontonului: perle (care cumpara aspect), ce aduce raul (vine la
-- ponton si il scoti cu undita) si momeala aurie (perlele pestilor x2). Monedele au iesit: o rotire in primul minut dadea
-- 10 min de venit (10%) sau 30 min (3%) -- 324 sau 972 de monede cand tot capitolul 1 costa ~120 --, deci sarea peste
-- ritmul tutorialului, exact motivul pentru care D51 a mutat recompensele quest-urilor in perle.
local WheelConfig = {}

WheelConfig.COOLDOWN = 24 * 3600 -- o rotire gratuita pe zi

-- Fiecare premiu da exact un lucru: `pearls`, `treasure` (un fel din TreasureConfig) sau `bait` (cate momeli).
export type Prize = {
    id: string,
    label: string,
    weight: number,
    pearls: number?,
    treasure: string?,
    bait: number?,
}

-- Ponderile se aduna la 100, ca procentul afisat in fereastra sa fie chiar ponderea -- fara
-- inmultiri ascunse intre ce calculeaza serverul si ce citeste jucatorul [D40].
-- Ordinea e si ordinea feliilor de pe fata roatii, in sensul acelor de ceasornic de sus: tipurile alterneaza.
WheelConfig.PRIZES = {
    { id = "pearls_5", label = "5 pearls", weight = 26, pearls = 5 },
    { id = "bottle", label = "A bottle drifts to your pier", weight = 18, treasure = "bottle" },
    { id = "pearls_10", label = "10 pearls", weight = 18, pearls = 10 },
    { id = "bait", label = "Golden bait ×5", weight = 16, bait = 5 },
    { id = "chest", label = "A chest drifts to your pier", weight = 10, treasure = "chest" },
    { id = "pearls_25", label = "25 pearls", weight = 6, pearls = 25 },
    { id = "golden", label = "Golden Driftwood drifts in", weight = 4, treasure = "golden" },
    { id = "pearls_60", label = "60 pearls", weight = 2, pearls = 60 },
} :: { Prize }

WheelConfig.byId = {} :: { [string]: Prize }
for _, p in WheelConfig.PRIZES do
    WheelConfig.byId[p.id] = p
end

return WheelConfig
