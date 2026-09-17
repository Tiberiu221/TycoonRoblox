--!strict
-- [D60] TITLURILE, adica ce scrie sub numele tau in bâlci. Modul pur: primeste faptele din profil si spune ce ai
-- castigat, ce se poate cumpara si daca titlul purtat mai e al tau.
--
-- Regula: titlurile CASTIGATE sunt gratuite si vin din ce ai facut (Era, jurnalul, recordul tau, decorul cumparat,
-- concursul saptamanii). Cele CUMPARATE costa perle si sunt scumpe intentionat -- 600/1000/1600, peste tot catalogul
-- de decor (1.460) -- ca sa ramana ceva de dorit dupa ce l-ai terminat [owner, 2026-09-16].
local TitleMath = {}

export type Record = { fish: string, cm: number }
export type Facts = {
    era: number,
    species: number, -- cate specii ai prins
    speciesTotal: number, -- cate exista
    record: Record?, -- cel mai mare peste al tau
    decor: { [string]: boolean }, -- id-urile decorurilor cumparate
    champion: boolean, -- ai fost #1 la peste saptamana trecuta
    bought: { [string]: boolean }, -- titlurile cumparate cu perle
    pondWins: number?, -- [D61] runde castigate la iaz (cu cel putin doi pescari)
    perfectGames: number?, -- [D61] jocuri perfecte la gherete
}

-- [D61] Pragurile titlurilor din balci: se castiga, nu se cumpara.
TitleMath.POND_WINS = 3
TitleMath.PERFECT_GAMES = 5

-- Titlurile din decor: cumperi lucrul, primesti titlul; asa se vad perlele cheltuite fara sa-ti viziteze cineva satul.
TitleMath.FROM_DECOR = {
    fountain = "Fountain Patron",
    statue = "Statue Patron",
    beehives = "Beekeeper",
    garden = "Gardener",
}

TitleMath.FOR_SALE = {
    { id = "old_salt", label = "Old Salt", price = 600 },
    { id = "river_baron", label = "River Baron", price = 1000 },
    { id = "lord_of_the_river", label = "Lord of the River", price = 1600 },
} :: { { id: string, label: string, price: number } }

-- zonele erelor, ca in TycoonConfig.ZONES si docs/TYCOON.md: The Landing / The Mill / The Yard / The Harbor
TitleMath.ZONE_TITLE = { "Of the Landing", "Of the Mill", "Of the Yard", "Of the Harbor" }

local function saleLabel(id: string): string?
    for _, entry in TitleMath.FOR_SALE do
        if entry.id == id then
            return entry.label
        end
    end
    return nil
end

-- Eticheta unui titlu, din fapte: recordul se scrie cu specia si marimea lui, deci nu poate fi un text fix [D40].
function TitleMath.label(id: string, facts: Facts): string?
    if id == "era" then
        local index = math.clamp(facts.era, 1, #TitleMath.ZONE_TITLE)
        return TitleMath.ZONE_TITLE[index]
    elseif id == "legend" then
        return if facts.species >= facts.speciesTotal and facts.speciesTotal > 0
            then "River Legend"
            else nil
    elseif id == "record" then
        local r = facts.record
        return if r ~= nil and r.cm > 0 then `{r.fish} {math.floor(r.cm)} cm` else nil
    elseif id == "champion" then
        -- campionul e #1 la peste saptamana trecuta (BoardService), pana cand concursul de la iaz ii ia locul [D61]
        return if facts.champion then "Champion of the Week" else nil
    elseif id == "pond" then
        return if (facts.pondWins or 0) >= TitleMath.POND_WINS then "Pond Champion" else nil
    elseif id == "sharpshooter" then
        return if (facts.perfectGames or 0) >= TitleMath.PERFECT_GAMES then "Sharpshooter" else nil
    end
    local decorId = string.match(id, "^decor_(%w+)$")
    if decorId ~= nil then
        return if facts.decor[decorId] then (TitleMath.FROM_DECOR :: any)[decorId] else nil
    end
    local sale = saleLabel(id)
    if sale ~= nil then
        return if facts.bought[id] then sale else nil
    end
    return nil
end

-- Ce titluri are omul, in ordinea in care i le aratam: Era intai (o are toata lumea), apoi ce a muncit, apoi ce a
-- cumparat. Intoarce perechi {id, label}, ca panoul sa nu mai calculeze nimic.
function TitleMath.earned(facts: Facts): { { id: string, label: string } }
    local out = {}
    local order = { "era", "legend", "record", "champion" }
    for decorId in TitleMath.FROM_DECOR do
        table.insert(order, `decor_{decorId}`)
    end
    table.sort(order)
    local ordered = { "era", "legend", "record", "champion", "pond", "sharpshooter" }
    for _, id in order do
        if string.sub(id, 1, 6) == "decor_" then
            table.insert(ordered, id)
        end
    end
    for _, entry in TitleMath.FOR_SALE do
        table.insert(ordered, entry.id)
    end
    for _, id in ordered do
        local label = TitleMath.label(id, facts)
        if label ~= nil then
            table.insert(out, { id = id, label = label })
        end
    end
    return out
end

-- Titlul purtat e valid doar cat timp il mai ai: dai decorul jos din sat sau pierzi campionatul, titlul pleaca cu el.
function TitleMath.canWear(id: string, facts: Facts): boolean
    return TitleMath.label(id, facts) ~= nil
end

function TitleMath.priceOf(id: string): number?
    for _, entry in TitleMath.FOR_SALE do
        if entry.id == id then
            return entry.price
        end
    end
    return nil
end

return TitleMath
