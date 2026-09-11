--!strict
-- Lumea 2D libera (vedere de sus), in pixeli logici; referinta de ecran 1920x1080 [DECIZII D06, revizuit 2026-09-09]
-- Raul e o banda orizontala care traverseaza harta; terenul jucatorului e pe malul de sud.
local RiverConfig = {
    SCREEN_WIDTH = 1920,
    SCREEN_HEIGHT = 1080,
    WORLD_WIDTH = 2880, -- 60 tile-uri de 48 px; orasul creste spre est la pasul 5
    WORLD_HEIGHT = 1920, -- 40 tile-uri
    TILE = 48,
    WINDOW_SECONDS = 60,
    RIVER_TOP = 480,
    RIVER_BOTTOM = 768,
    LANE_YS = { 516, 588, 660, 732 }, -- 4 benzi in banda raului [DECIZII D28]
    SPAWNS_PER_WINDOW = 14,
    SPEED_MIN = 100,
    SPEED_MAX = 160,
    OBJECT_WIDTH = 64,
    OBJECT_HEIGHT = 48,
    NET_SLOT_XS = { 600, 1000, 1400 }, -- 3 sloturi pe terenul jucatorului; slotul i acopera banda i
    NET_WIDTH = 144,
    NET_HEIGHT = 84, -- 48x28 x3
    INTERACT_DISTANCE = 130,
    -- RUN_MULTIPLIER: alergarea nu cere un control nou. Pe desktop e Shift, pe telefon e
    -- joystick-ul impins pana la capat -- magnitudinea exista deja, deci nu adaugam nimic pe
    -- ecran. RUN_THRESHOLD e cat de departe trebuie impins ca sa conteze alergare.
    CHARACTER = {
        SPEED = 320,
        RUN_MULTIPLIER = 1.6,
        RUN_THRESHOLD = 0.85,
        START_X = 1000,
        START_Y = 1000,
        WIDTH = 48,
        HEIGHT = 72,
    },
    -- Cladiri placeholder (x, y, w, h, eticheta): blocheaza mersul; devin locuri reale la pasii 3 si 5
    -- Cladiri: `kind` decide ce nevoie satisfac sau ce munca gazduiesc; `slots` = cati colonisti
    -- pot lucra/sta simultan; usa e punctul spre care merg colonistii [RIVERKEEP 4.3]
    BUILDINGS = {
        {
            id = "workshop",
            x = 260,
            y = 880,
            w = 192,
            h = 192,
            label = "Workshop",
            kind = "work",
            slots = 3,
        },
        {
            id = "kitchen",
            x = 700,
            y = 1400,
            w = 144,
            h = 144,
            label = "Kitchen",
            kind = "food",
            slots = 2,
        },
        {
            id = "house_a",
            x = 1050,
            y = 1450,
            w = 144,
            h = 144,
            label = "Bunkhouse",
            kind = "rest",
            slots = 4,
        },
        {
            id = "house_b",
            x = 1300,
            y = 1450,
            w = 144,
            h = 144,
            label = "Cottage",
            kind = "rest",
            slots = 3,
        },
        {
            id = "hall",
            x = 1700,
            y = 1250,
            w = 192,
            h = 192,
            label = "Meeting hall",
            kind = "joy",
            slots = 4,
        },
        {
            id = "town_workshop",
            x = 2300,
            y = 1000,
            w = 256,
            h = 256,
            label = "Town workshop (later)",
            kind = "none",
            slots = 0,
        },
        {
            id = "upstream",
            x = 2000,
            y = 120,
            w = 192,
            h = 192,
            label = "Upstream (later)",
            kind = "none",
            slots = 0,
        },
    },
    PLOT = { x = 200, y = 800, w = 1500, h = 700 }, -- terenul jucatorului (mal de sud)
    TIERS = {
        { id = "common", weight = 0.537, rgb = { 160, 110, 60 } },
        { id = "uncommon", weight = 0.248, rgb = { 90, 160, 90 } },
        { id = "rare", weight = 0.128, rgb = { 70, 120, 220 } },
        { id = "epic", weight = 0.061, rgb = { 150, 80, 200 } },
        { id = "legendary", weight = 0.021, rgb = { 240, 170, 40 } },
        { id = "mythic", weight = 0.0045, rgb = { 240, 60, 90 } },
    },
}

-- Debarcaderul: unde trage barca de sosire si unde arata indicatorul de la pasul "uita-te la apa".
-- E in dreptul terenului, nu in mijlocul lumii. Cand cele doua nu coincid, sageata trimite
-- jucatorul intr-o parte si barca apare in cealalta, adica indiciul minte.
RiverConfig.LANDING = {
    x = RiverConfig.PLOT.x + RiverConfig.PLOT.w / 2,
    y = (RiverConfig.RIVER_TOP + RiverConfig.RIVER_BOTTOM) / 2 + 40,
}

return RiverConfig
