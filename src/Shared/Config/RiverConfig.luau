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
    -- NET_WIDTH/HEIGHT: doar marimea vizuala a cutiei plasei in NetController; pozitia vine acum
    -- din TycoonState (F0 spec 1.4), nu din NET_SLOT_XS (scos -- era sistemul de sloturi vechi).
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
    -- Zona in care WorldDecor nu pune copaci/pietre: toate cele 12 platforme ale Erei 1 si
    -- debarcaderul incap in acest dreptunghi (verificat in tests/WorldDecor.test.luau) [F0 spec 4.6].
    PLOT = { x = 200, y = 800, w = 1500, h = 700 },
    TIERS = {
        { id = "common", weight = 0.537, rgb = { 160, 110, 60 } },
        { id = "uncommon", weight = 0.248, rgb = { 90, 160, 90 } },
        { id = "rare", weight = 0.128, rgb = { 70, 120, 220 } },
        { id = "epic", weight = 0.061, rgb = { 150, 80, 200 } },
        { id = "legendary", weight = 0.021, rgb = { 240, 170, 40 } },
        { id = "mythic", weight = 0.0045, rgb = { 240, 60, 90 } },
    },
}

return RiverConfig
