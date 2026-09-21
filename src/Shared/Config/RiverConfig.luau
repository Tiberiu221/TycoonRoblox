--!strict
-- Lumea 2D libera (vedere de sus), in pixeli logici; referinta de ecran 1920x1080 [DECIZII D06, revizuit 2026-09-09]
-- Raul e o banda orizontala care traverseaza harta; terenul jucatorului e pe malul de sud.
local RiverConfig = {
    SCREEN_WIDTH = 1920,
    SCREEN_HEIGHT = 1080,
    -- [D65] 80 de tile-uri de 48 px: The Landing (x 200..1860), The Mill (1860..3560) si capatul lumii, unde se vede
    -- gardul erei urmatoare. Pana la D65 erau 2880; lumea creste spre est (aval) cu fiecare era.
    -- [D67] 115 tile-uri: si The Wire Works (3560..5240), apoi gardul Erei 4 (The Dam). Pana la D67 erau 3840.
    WORLD_WIDTH = 5520,
    -- Latimea lumii de dinainte de D65. Decorul imprastiat al partii vechi se genereaza tot pe ea, cu aceeasi samanta,
    -- ca niciun copac al satului deja vazut de jucatori sa nu se mute (vezi WorldDecor.village).
    ERA1_WORLD_WIDTH = 2880,
    -- [D67] Latimea lumii cu Moara, de dinainte de Era 3: fasia ei de decor ramane exact cea de atunci (DECOR_STRIPS).
    ERA2_WORLD_WIDTH = 3840,
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
    -- MALURILE (vezi Shared/Modules/Shoreline). Cifrele stau AICI, nu in controllerul de desen,
    -- ca testele sa poata verifica exact ce se deseneaza: uscatul nu are voie sa intre peste
    -- benzile pe care plutesc bunurile (LANE_YS), iar in dreptul terenului construit malul
    -- trebuie sa ramana aproape drept, ca apa sa nu musce din ponton (TycoonConfig.DECK.y0=772).
    SHORE_FAR = {
        seed = 20260912,
        baseY = 488, -- cel mai jos punct al malului de nord; banda de sus e la 516
        amp = 96, -- se retrage spre nord pana la 392: raul se face vizibil mai lat pe alocuri
        side = -1,
        beach = 58,
    },
    SHORE_NEAR = {
        seed = 20265154,
        baseY = 758, -- cel mai sus punct al malului de sud; pontonul incepe la 772
        amp = 66, -- in salbaticie se retrage spre sud pana la 824: golfuri adevarate
        side = 1,
        beach = 46,
        -- malul amenajat: de la marginea din stanga a pontonului pana la capatul terenului [D50]
        -- [D65] pana la capatul Morii (x 3560 + 80): malul e amenajat in fata fiecarui cartier construit
        -- [D67] si in fata Wire Works (x 5240 + 80)
        calm = { x0 = 150, x1 = 5320, feather = 240, amp = 12 },
    },
    -- Zona in care WorldDecor nu pune copaci/pietre: tot ce e construit in Era 1 incape in acest
    -- dreptunghi (verificat in tests/WorldDecor.test.luau) [F0 spec 4.6]. Se termina la x 1960, cu
    -- 100 px dincolo de gardul Morii, exact unde se termina si malul amenajat (SHORE_NEAR.calm) [D50].
    -- [D65] Cu Moara, terenul fara decor se intinde pana la capatul ei (x 3640). `PLOT_ERA1` e dreptunghiul de
    -- dinainte: cu el se genereaza decorul partii vechi, ca sa ramana pe loc (WorldDecor.village).
    -- [D67] Cu Wire Works, pana la capatul ei (x 5320); `PLOT_ERA2` e terenul de pe vremea Morii (fasia ei de decor).
    PLOT = { x = 200, y = 800, w = 5120, h = 850 },
    PLOT_ERA1 = { x = 200, y = 800, w = 1760, h = 850 },
    PLOT_ERA2 = { x = 200, y = 800, w = 3440, h = 850 },
    TIERS = {
        { id = "common", weight = 0.537, rgb = { 160, 110, 60 } },
        { id = "uncommon", weight = 0.248, rgb = { 90, 160, 90 } },
        { id = "rare", weight = 0.128, rgb = { 70, 120, 220 } },
        { id = "epic", weight = 0.061, rgb = { 150, 80, 200 } },
        { id = "legendary", weight = 0.021, rgb = { 240, 170, 40 } },
        { id = "mythic", weight = 0.0045, rgb = { 240, 60, 90 } },
    },
}

-- [D67] FASIILE DE DECOR de dupa partea veche a satului (WorldDecor.village), in ordinea in care au venit: fiecare cu
-- marginea ei din dreapta si terenul fara decor de pe vremea ei. O fasie noua isi primeste decorul ei, cu samanta ei,
-- fara sa mute un copac din cele de dinainte (Moara ramane exact cum a vazut-o owner-ul).
RiverConfig.DECOR_STRIPS = {
    { x1 = RiverConfig.ERA2_WORLD_WIDTH, plot = RiverConfig.PLOT_ERA2 },
    { x1 = RiverConfig.WORLD_WIDTH, plot = RiverConfig.PLOT },
}

return RiverConfig
