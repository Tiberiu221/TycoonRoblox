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
-- Premiile in monede se dau ca SECUNDE DE VENIT, nu ca sume fixe: o suma fixa e regeasca in
-- minutul 3 si o gluma in ora 3. Asa roata ramane relevanta toata Era 1 fara sa fie recalibrata.
local WheelConfig = {}

WheelConfig.COOLDOWN = 24 * 3600 -- o rotire gratuita pe zi
WheelConfig.MIN_COINS = 25 -- plasa de siguranta pentru inceputul de tot, cand venitul e minuscul

export type Prize = {
    id: string,
    label: string,
    weight: number,
    incomeSeconds: number?, -- monede = atatea secunde din venitul tau de acum
    pearls: number?,
}

-- Ponderile se aduna la 100, ca procentul afisat in fereastra sa fie chiar ponderea -- fara
-- inmultiri ascunse intre ce calculeaza serverul si ce citeste jucatorul [D40].
WheelConfig.PRIZES = {
    { id = "coins_s", label = "30s of income", weight = 22, incomeSeconds = 30 },
    { id = "coins_m", label = "2min of income", weight = 20, incomeSeconds = 120 },
    { id = "coins_l", label = "10min of income", weight = 10, incomeSeconds = 600 },
    { id = "coins_xl", label = "30min of income", weight = 3, incomeSeconds = 1800 },
    { id = "pearl_1", label = "1 pearl", weight = 22, pearls = 1 },
    { id = "pearl_3", label = "3 pearls", weight = 14, pearls = 3 },
    { id = "pearl_10", label = "10 pearls", weight = 6, pearls = 10 },
    { id = "pearl_25", label = "25 pearls", weight = 3, pearls = 25 },
} :: { Prize }

WheelConfig.byId = {} :: { [string]: Prize }
for _, p in WheelConfig.PRIZES do
    WheelConfig.byId[p.id] = p
end

return WheelConfig
