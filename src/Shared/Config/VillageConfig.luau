--!strict
-- [D59] PERLELE CUMPARA ASPECT: avizierul satului, de pe punte, cu doua pagini -- satul (decor, fiecare lucru cu locul
-- lui fix) si tinutele jucatorului. Recomandarea acceptata de owner (2026-09-15): "perlele cumpara decor pentru sat si
-- tinute". Nimic de aici nu schimba venitul, nimic nu e aleatoriu, iar ce ai cumparat ramane al tau [D59].
--
-- Fisier separat de TycoonConfig: simulatorul leaga pretul unei platforme de primul `id = "..."` din acel fisier, iar
-- aici sunt preturi in perle, pe care simulatorul nu trebuie sa le vada.
local WorldConfig = require(script and script.Parent.WorldConfig or "./WorldConfig")

local VillageConfig = {}

-- `ground`: unde sta lucrul, pentru testul de asezare -- "land" pe teren (in zona, nu calca nimic), "pier" pe ponton,
-- "water" pe rau. `overRoad`: are voie peste drum (ghirlanda atarna deasupra strazii, stalpii ei stau pe margine).
-- [D70, pasul k2b] LUMILE: `spots` si `where` sunt ale satului (lumea 1, neschimbate). La baraj (lumea 2) lucrurile de pe
-- uscat isi au locurile in piata Dam Town (`spotsByWorld[2]`, acelasi numar de locuri ca in sat, cu textul lor in
-- `whereByWorld[2]`); pontonul si lacul stau pe aceleasi coordonate in ambele lumi, deci cele de pe ponton si de pe apa
-- nu au nevoie de alte locuri. Cine deseneaza decorul citeste `spotsOf` / `whereOf`, nu campurile directe.
export type Spot = { x: number, y: number } -- y = baza (AnchorPoint 0.5, 1)
export type Decor = {
    id: string,
    name: string,
    where: string, -- pe randul din panou: unde apare (in sat)
    whereByWorld: { [number]: string }?, -- [k2b] unde apare in alta lume
    price: number,
    sprite: string, -- cheia din Assets.decor
    scale: number,
    ground: string,
    overRoad: boolean?,
    spots: { Spot }, -- locurile din sat (lumea 1)
    spotsByWorld: { [number]: { Spot } }?, -- [k2b] locurile din alta lume
}
export type Outfit = {
    id: string, -- cheia din Assets.people.outfit
    name: string,
    price: number?, -- nil = nu se vinde
    journal: boolean?, -- se primeste cand jurnalul pestilor e complet
    tailor: boolean?, -- [D61] se vinde doar la croitoreasa din balci
    pass: string?, -- [D61, partea 2] vine cu pass-ul asta (MonetizationConfig): a ta cat ai pass-ul
}

-- In ordinea pretului: primul se poate lua din perlele capitolului 1 si un minut de pescuit [PearlBudget.test].
VillageConfig.DECOR = {
    {
        id = "flowerbeds",
        name = "Flower Beds",
        where = "By the houses",
        whereByWorld = { [2] = "On the town green" },
        price = 20,
        sprite = "flowerbed",
        scale = 2,
        ground = "land",
        -- In fata caselor, pe iarba de sub randul cu nume: in curti stateau peste "Collector", "Sawyer",
        -- "Scrap Collector" si "Smelter" [vazut in Studio, 2026-09-15]. x ales intre coroanele copacilor din seed.
        spots = {
            { x = 666, y = 1676 },
            { x = 1150, y = 1676 },
            { x = 1450, y = 1676 },
            { x = 1750, y = 1676 },
        },
        -- [k2b] Dam Town: pe iarba din sudul pietei, doua randuri de cate doua, cu fantana (si banca) intre ele
        spotsByWorld = {
            [2] = {
                { x = 276, y = 1236 },
                { x = 470, y = 1236 },
                { x = 276, y = 1396 },
                { x = 470, y = 1396 },
            },
        },
    },
    {
        id = "pier_lamps",
        name = "Pier Lamps",
        where = "On the pier",
        price = 30,
        sprite = "pier_lamp",
        scale = 2,
        ground = "pier",
        spots = { { x = 266, y = 724 }, { x = 334, y = 724 } },
    },
    {
        id = "bench",
        name = "Bench",
        where = "By the Tavern square",
        whereByWorld = { [2] = "On the town green" }, -- [verificatorul k2b] sub fantana, nu langa piata
        price = 40,
        sprite = "bench",
        scale = 2,
        ground = "land",
        spots = { { x = 730, y = 1130 } }, -- nu peste locul unde apari (SPAWN) si nu peste butucii curtii
        spotsByWorld = { [2] = { { x = 373, y = 1376 } } }, -- [k2b] pe iarba de sub piata, sub fantana
    },
    {
        id = "bunting",
        name = "Bunting",
        where = "Over the village street",
        whereByWorld = { [2] = "Over the town street" },
        price = 60,
        sprite = "bunting",
        scale = 2,
        ground = "land",
        overRoad = true,
        spots = { { x = 400, y = 1500 }, { x = 1450, y = 1500 } },
        -- [k2b] peste strada, in fata casutelor din Dam Town: una la capatul ei de vest, una la gura aleii pietei
        spotsByWorld = { [2] = { { x = 330, y = 1500 }, { x = 550, y = 1500 } } },
    },
    {
        id = "well",
        name = "Well",
        where = "In the lumber yard",
        whereByWorld = { [2] = "Beside the Canteen" },
        price = 90,
        sprite = "well",
        scale = 2,
        ground = "land",
        spots = { { x = 880, y = 1290 } },
        -- [verificatorul k2b] la vest de Canteen, la 40 px sub ponton: fasia de sub clopotnita ramane libera (pe acolo mergi
        -- de unde apari spre ponton, roata, avizier si barca)
        spotsByWorld = { [2] = { { x = 254, y = 1034 } } },
    },
    {
        id = "garden",
        name = "Vegetable Garden",
        where = "Next to the Innkeeper's stall",
        whereByWorld = { [2] = "Beside the Memory Wall" },
        price = 120,
        sprite = "veggie_patch",
        scale = 2,
        ground = "land",
        spots = { { x = 420, y = 1405 } },
        spotsByWorld = { [2] = { { x = 640, y = 1228 } } }, -- [k2b] chiar deasupra zidului amintirilor, pe iarba de la est de piata
    },
    {
        id = "rowboat",
        name = "Rowboat",
        where = "Tied up by the pier",
        price = 150,
        sprite = "rowboat",
        scale = 2,
        ground = "water",
        spots = { { x = 130, y = 768 } },
    },
    {
        id = "beehives",
        name = "Beehives",
        where = "By the Landing Bell",
        whereByWorld = { [2] = "Below the Battery Store" },
        price = 200,
        sprite = "beehives",
        scale = 2,
        ground = "land",
        spots = { { x = 1760, y = 1125 } },
        -- [verificatorul k2b] pe iarba dintre Battery Store si Switchyard (nimeni nu trece pe acolo), nu in fasia de sub clopotnita
        spotsByWorld = { [2] = { { x = 1120, y = 1200 } } },
    },
    {
        id = "fountain",
        name = "Fountain",
        where = "On the village green",
        whereByWorld = { [2] = "On the town green" },
        price = 300,
        sprite = "fountain",
        scale = 2,
        ground = "land",
        spots = { { x = 1080, y = 1270 } },
        spotsByWorld = { [2] = { { x = 373, y = 1320 } } }, -- [k2b] in mijlocul ierbii din sudul pietei
    },
    {
        id = "statue",
        name = "River Statue",
        where = "Where the street begins",
        whereByWorld = { [2] = "Where the lane meets the street" },
        price = 450,
        sprite = "statue",
        scale = 2,
        ground = "land",
        spots = { { x = 320, y = 1620 } },
        -- [verificatorul k2b] la gura aleii pietei, pe iarba dintre ea si Memory Wall (langa ponton era inghesuita)
        spotsByWorld = { [2] = { { x = 612, y = 1408 } } },
    },
} :: { Decor }

-- Tinutele jucatorului: siluete pe care nu le poarta nicio meserie [D44]. `keeper` e cea de la inceput.
VillageConfig.DEFAULT_OUTFIT = "keeper"
VillageConfig.OUTFITS = {
    { id = "keeper", name = "Keeper", price = 0 },
    { id = "angler", name = "Angler", price = 150 },
    { id = "captain", name = "Captain", price = 400 },
    { id = "legend", name = "River Legend", journal = true },
    -- [D61] ale croitoresei din balci: se cumpara doar la cortul ei (`tailor`), nu la avizier si nu in vitrina
    -- negustorului. Siluete de cap pe care nu le poarta nimeni altcineva (scripts/art/settlers.py).
    { id = "festival", name = "Festival Coat", price = 200, tailor = true },
    { id = "minstrel", name = "Minstrel", price = 250, tailor = true },
    { id = "lampkeeper", name = "Lantern Keeper", price = 350, tailor = true },
    { id = "harvest", name = "Harvest Crown", price = 500, tailor = true },
    -- [D61, partea 2] vine cu pass-ul Supporter (coltul cu Robux): e a ta cat ai pass-ul, nu se cumpara cu perle
    { id = "supporter", name = "Supporter", pass = "supporter" },
} :: { Outfit }

-- [k2b] Locurile unui decor intr-o lume: cele scrise pentru ea (`spotsByWorld`), altfel ale satului pentru lumea 1 si pentru
-- lucrurile de pe ponton si de pe apa (acelasi ponton, acelasi lac), altfel niciunul. O lume necunoscuta e satul.
function VillageConfig.spotsOf(decor: Decor, world: number?): { Spot }
    local w = WorldConfig.sanitize(world)
    local own = if decor.spotsByWorld ~= nil then decor.spotsByWorld[w] else nil
    if own ~= nil then
        return own
    elseif w == 1 or decor.ground ~= "land" then
        return decor.spots
    end
    return {}
end

-- Unde apare decorul, pe randul din panou, in lumea data (altfel textul satului).
function VillageConfig.whereOf(decor: Decor, world: number?): string
    local w = WorldConfig.sanitize(world)
    local own = if decor.whereByWorld ~= nil then decor.whereByWorld[w] else nil
    return own or decor.where
end

VillageConfig.decorById = {} :: { [string]: Decor }
for _, d in VillageConfig.DECOR do
    VillageConfig.decorById[d.id] = d
end
VillageConfig.outfitById = {} :: { [string]: Outfit }
for _, o in VillageConfig.OUTFITS do
    VillageConfig.outfitById[o.id] = o
end

return VillageConfig
