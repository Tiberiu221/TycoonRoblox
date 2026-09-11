--!strict
-- Catalogul de cladiri [RIVERKEEP 4.3]. Costul e in Materiale (din dezmembrare, D16).
-- `kind`: rest/food/joy = satisfac o nevoie; work = loc de munca; store = capacitate.
-- Dimensiunile sunt in TILE-uri; pozitionarea si validarea se fac pe grila.
local BuildingConfig = {}

export type Def = {
    id: string,
    label: string,
    kind: string,
    w: number, -- in tile-uri
    h: number,
    cost: number, -- Materiale
    slots: number, -- cati colonisti simultan
    beds: number, -- capacitate de populatie (doar la kind = "rest")
    buildWork: number, -- unitati de munca de constructie
    blurb: string,
}

local function def(t: Def): Def
    return t
end

BuildingConfig.DEFS = {
    def({
        id = "tent",
        label = "Tent",
        kind = "rest",
        w = 2,
        h = 2,
        cost = 6,
        slots = 1,
        beds = 1,
        buildWork = 40,
        blurb = "One bed. Cheap and quick — the first thing you build.",
    }),
    def({
        id = "cottage",
        label = "Cottage",
        kind = "rest",
        w = 3,
        h = 3,
        cost = 22,
        slots = 2,
        beds = 3,
        buildWork = 140,
        blurb = "Three beds and a warm hearth.",
    }),
    def({
        id = "bunkhouse",
        label = "Bunkhouse",
        kind = "rest",
        w = 4,
        h = 3,
        cost = 48,
        slots = 4,
        beds = 6,
        buildWork = 300,
        blurb = "Six beds. The backbone of a growing settlement.",
    }),
    def({
        id = "kitchen",
        label = "Kitchen",
        kind = "food",
        w = 3,
        h = 3,
        cost = 18,
        slots = 2,
        beds = 0,
        buildWork = 120,
        blurb = "Feeds two settlers at a time.",
    }),
    def({
        id = "smokehouse",
        label = "Smokehouse",
        kind = "food",
        w = 4,
        h = 3,
        cost = 44,
        slots = 4,
        beds = 0,
        buildWork = 260,
        blurb = "Feeds four at once, and faster.",
    }),
    def({
        id = "workshop",
        label = "Workshop",
        kind = "work",
        w = 4,
        h = 4,
        cost = 30,
        slots = 3,
        beds = 0,
        buildWork = 200,
        blurb = "Where crafters repair what the river brings.",
    }),
    def({
        id = "hall",
        label = "Meeting hall",
        kind = "joy",
        w = 4,
        h = 4,
        cost = 40,
        slots = 4,
        beds = 0,
        buildWork = 240,
        blurb = "Keeps spirits up. Neglect it and people drift away.",
    }),
    def({
        id = "garden",
        label = "Garden",
        kind = "farm",
        w = 3,
        h = 2,
        cost = 14,
        slots = 2,
        beds = 0,
        buildWork = 90,
        blurb = "Gardeners grow food here. Two can work it at once.",
    }),
    def({
        id = "firepit",
        label = "Firepit",
        kind = "joy",
        w = 2,
        h = 2,
        cost = 10,
        slots = 2,
        beds = 0,
        buildWork = 50,
        blurb = "A cheap place to sit and talk.",
    }),
}

function BuildingConfig.get(id: string): Def?
    for _, d in BuildingConfig.DEFS do
        if d.id == id then
            return d
        end
    end
    return nil
end

-- Asezarea de start: ce exista deja cand intri prima oara (coordonate in pixeli logici)
-- Asezarea mostenita: atelier, bucatarie, vatra si UN singur cort.
-- Un singur pat inseamna ca nimeni nou nu se opreste aici pana nu construiesti al doilea.
-- Cu o cabana de trei paturi de la inceput, cresterea venea de la sine si nu mai era a ta.
BuildingConfig.STARTER = {
    { defId = "workshop", x = 288, y = 912 },
    { defId = "kitchen", x = 720, y = 1392 },
    { defId = "tent", x = 1056, y = 1440 },
    { defId = "firepit", x = 1344, y = 1440 },
}

return BuildingConfig
