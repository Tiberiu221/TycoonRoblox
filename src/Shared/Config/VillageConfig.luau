--!strict
-- [D59] PERLELE CUMPARA ASPECT: avizierul satului, de pe punte, cu doua pagini -- satul (decor, fiecare lucru cu locul
-- lui fix) si tinutele jucatorului. Recomandarea acceptata de owner (2026-09-15): "perlele cumpara decor pentru sat si
-- tinute". Nimic de aici nu schimba venitul, nimic nu e aleatoriu, iar ce ai cumparat ramane al tau [D59].
--
-- Fisier separat de TycoonConfig: simulatorul leaga pretul unei platforme de primul `id = "..."` din acel fisier, iar
-- aici sunt preturi in perle, pe care simulatorul nu trebuie sa le vada.
local VillageConfig = {}

-- `ground`: unde sta lucrul, pentru testul de asezare -- "land" pe teren (in zona, nu calca nimic), "pier" pe ponton,
-- "water" pe rau. `overRoad`: are voie peste drum (ghirlanda atarna deasupra strazii, stalpii ei stau pe margine).
export type Spot = { x: number, y: number } -- y = baza (AnchorPoint 0.5, 1)
export type Decor = {
    id: string,
    name: string,
    where: string, -- pe randul din panou: unde apare
    price: number,
    sprite: string, -- cheia din Assets.decor
    scale: number,
    ground: string,
    overRoad: boolean?,
    spots: { Spot },
}
export type Outfit = {
    id: string, -- cheia din Assets.people.outfit
    name: string,
    price: number?, -- nil = nu se vinde
    journal: boolean?, -- se primeste cand jurnalul pestilor e complet
}

-- In ordinea pretului: primul se poate lua din perlele capitolului 1 si un minut de pescuit [PearlBudget.test].
VillageConfig.DECOR = {
    {
        id = "flowerbeds",
        name = "Flower Beds",
        where = "By the houses",
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
        where = "By the tavern square",
        price = 40,
        sprite = "bench",
        scale = 2,
        ground = "land",
        spots = { { x = 730, y = 1130 } }, -- nu peste locul unde apari (SPAWN) si nu peste butucii curtii
    },
    {
        id = "bunting",
        name = "Bunting",
        where = "Over the village street",
        price = 60,
        sprite = "bunting",
        scale = 2,
        ground = "land",
        overRoad = true,
        spots = { { x = 400, y = 1500 }, { x = 1450, y = 1500 } },
    },
    {
        id = "well",
        name = "Well",
        where = "In the lumber yard",
        price = 90,
        sprite = "well",
        scale = 2,
        ground = "land",
        spots = { { x = 880, y = 1290 } },
    },
    {
        id = "garden",
        name = "Vegetable Garden",
        where = "Next to the Innkeeper's stall",
        price = 120,
        sprite = "veggie_patch",
        scale = 2,
        ground = "land",
        spots = { { x = 420, y = 1405 } },
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
        price = 200,
        sprite = "beehives",
        scale = 2,
        ground = "land",
        spots = { { x = 1760, y = 1125 } },
    },
    {
        id = "fountain",
        name = "Fountain",
        where = "On the village green",
        price = 300,
        sprite = "fountain",
        scale = 2,
        ground = "land",
        spots = { { x = 1080, y = 1270 } },
    },
    {
        id = "statue",
        name = "River Statue",
        where = "Where the street begins",
        price = 450,
        sprite = "statue",
        scale = 2,
        ground = "land",
        spots = { { x = 320, y = 1620 } },
    },
} :: { Decor }

-- Tinutele jucatorului: siluete pe care nu le poarta nicio meserie [D44]. `keeper` e cea de la inceput.
VillageConfig.DEFAULT_OUTFIT = "keeper"
VillageConfig.OUTFITS = {
    { id = "keeper", name = "Keeper", price = 0 },
    { id = "angler", name = "Angler", price = 150 },
    { id = "captain", name = "Captain", price = 400 },
    { id = "legend", name = "River Legend", journal = true },
} :: { Outfit }

VillageConfig.decorById = {} :: { [string]: Decor }
for _, d in VillageConfig.DECOR do
    VillageConfig.decorById[d.id] = d
end
VillageConfig.outfitById = {} :: { [string]: Outfit }
for _, o in VillageConfig.OUTFITS do
    VillageConfig.outfitById[o.id] = o
end

return VillageConfig
