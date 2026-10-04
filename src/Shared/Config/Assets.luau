--!strict
-- Manifest de asset-uri (pasul 1: completat manual dupa import in Studio; de la pasul 4: generat de Asphalt, cap. 3.9).
-- 0 = lipsa -> clientul foloseste desenul procedural din SceneArt. Dimensiunile sunt in pixeli reali ai PNG-ului.
export type Sprite = { id: number, width: number, height: number }

local function sprite(id: number, width: number, height: number): Sprite
    return { id = id, width = width, height = height }
end

local Assets = {
    PIXEL_SCALE = 3, -- un pixel de sprite = 3 pixeli logici la referinta 1920x1080
    water_tile = sprite(121064767001882, 128, 64),
    grass_tile = sprite(138783135458217, 128, 128),
    tile_fair = sprite(120008148968406, 64, 64), -- [D60] pamantul batatorit al balciului
    shore_north = sprite(98223548793010, 64, 32), -- iarba -> nisip -> apa (malul de nord)
    shore_south = sprite(86170303421420, 64, 32), -- apa -> nisip -> iarba (malul de sud)
    shadow = sprite(84696637273522, 16, 6),
    hills = sprite(74054290022349, 256, 48),
    sun = sprite(125574337811161, 16, 16),
    cloud = sprite(133675539889594, 32, 12),
    -- Foaia de animatie: 12 randuri x 4 cadre de 16x24, in ordinea din AnimConfig.ROWS
    character_anim = sprite(105280199624609, 64, 360), -- foaia veche, dintr-o bucata

    -- STRATURILE [D44]. Id 0 = neincarcat inca pe platforma; `Assets.has` da false, iar clientul
    -- ramane pe foaia dintr-o bucata de mai sus. Cand se incarca, se pun id-urile si sistemul
    -- porneste singur -- nu e nevoie de nicio alta schimbare in cod.
    people = {
        body = {
            a = sprite(136581586177910, 64, 480),
            b = sprite(82444020423106, 64, 480),
        },
        hair = {
            short = sprite(107610601158067, 64, 480),
            long = sprite(77115225601547, 64, 480),
            bun = sprite(110084281856232, 64, 480),
            bald = sprite(0, 64, 480),
        },
        outfit = {
            Fisher = sprite(93764231120710, 64, 480),
            Crafter = sprite(99685239994067, 64, 480),
            Builder = sprite(139784841525496, 64, 480),
            Gardener = sprite(83753596594055, 64, 480),
            Innkeeper = sprite(108041503019278, 64, 480),
            keeper = sprite(88326631180357, 64, 480), -- doar jucatorul
            -- [D50] clientii tavernei: fara palarie, in culori pe care nu le poarta nicio meserie
            Townsfolk = sprite(133031375498480, 64, 480),
            Traveler = sprite(93487186567636, 64, 480),
            -- [D56] linia fierului: Scrap Collector, Scrap Porter, Smelter (cu sortul), Iron Hauler
            Scrapper = sprite(91090647599495, 64, 480),
            Carter = sprite(99251069118914, 64, 480),
            Smith = sprite(98115009114611, 64, 480),
            Ironmonger = sprite(88848133317835, 64, 480),
            -- [D65] oamenii Morii. Id 0 = inca neurcata: omul poarta tinuta perechii (HandConfig.OUTFIT_LOOKS_LIKE).
            Gleaner = sprite(71535293673096, 64, 480),
            Drayman = sprite(90693681103082, 64, 480),
            Founder = sprite(125438452034377, 64, 480),
            Wheelwright = sprite(116835022369035, 64, 480),
            Merchant = sprite(85816489114839, 64, 480),
            Prospector = sprite(82630973414919, 64, 480),
            Mucker = sprite(78713042840079, 64, 480),
            Coppersmith = sprite(121254545908111, 64, 480),
            Teamster = sprite(104438045676073, 64, 480),
            -- [D67] oamenii Wire Works. Id 0 = inca neurcata: omul poarta tinuta perechii din Moara.
            Dredger = sprite(117573476790780, 64, 480),
            Barrowman = sprite(88990248557313, 64, 480),
            Wiredrawer = sprite(110732481328993, 64, 480),
            Coiler = sprite(119512691181870, 64, 480),
            Clerk = sprite(136434654062236, 64, 480),
            Lineman = sprite(134848544009926, 64, 480),
            Hodman = sprite(82882146900058, 64, 480),
            Electrician = sprite(77014023456104, 64, 480),
            Freighter = sprite(126028985144101, 64, 480),
            -- [D70, pasul k10] oamenii barajului, pana la foile lor (lotul A4): id 0, deci omul poarta tinuta perechii
            -- (HandConfig.OUTFIT_LOOKS_LIKE). Veteranii arata ca in Era 1, cei noi ca perechea lor din Era 3 (O1).
            Turbineer = sprite(0, 64, 480),
            Lugger = sprite(0, 64, 480),
            Switchman = sprite(0, 64, 480),
            Cooper = sprite(0, 64, 480),
            Dispatcher = sprite(0, 64, 480),
            Spooler = sprite(0, 64, 480),
            Packer = sprite(0, 64, 480),
            Cablemaker = sprite(0, 64, 480),
            Reeler = sprite(0, 64, 480),
            Relayman = sprite(0, 64, 480),
            Linewalker = sprite(0, 64, 480),
            Gemfinder = sprite(0, 64, 480),
            Bearer = sprite(0, 64, 480),
            Crystalsmith = sprite(0, 64, 480),
            Bullioner = sprite(0, 64, 480),
            -- [D59] tinutele jucatorului, cumparate cu perle (angler, captain) sau din jurnalul complet (legend). Cheile
            -- cu litera mica, ca `keeper`: nu sunt meserii. Id 0 = inca neurcat -> personajul ramane in `keeper`.
            angler = sprite(77086694802414, 64, 480),
            captain = sprite(96665945822082, 64, 480),
            legend = sprite(117264524949067, 64, 480),
            -- [D61, partea 2] tinutele croitoresei din balci (scripts/art/settlers.py). Id 0 = inca neurcat: randul
            -- ei din panou ramane fara portret, iar omul imbracat asa ramane in `keeper`.
            festival = sprite(78963091114550, 64, 480),
            minstrel = sprite(138746724207136, 64, 480),
            lampkeeper = sprite(133414341329904, 64, 480),
            harvest = sprite(76827706740058, 64, 480),
            supporter = sprite(125428311397229, 64, 480), -- [D61, partea 2] vine cu pass-ul Supporter
        },
    },
    path_tile = sprite(124285357370417, 64, 64),
    -- [D57] satul pe flux: piatra pietei tavernei si smocurile de iarba de pe marginile drumurilor si ale curtilor
    -- (scripts/art/d57.py). Id 0 = inca neurcat: SceneArt deseneaza pamant simplu si margini drepte.
    tile_plaza = sprite(121389456528640, 64, 64),
    grass_edge_h = sprite(100759578645951, 64, 8),
    grass_edge_v = sprite(87052770891815, 8, 64),
    house = sprite(90840210687331, 64, 80), -- generic, folosit doar daca lipseste sprite-ul dedicat
    -- Cate un sprite per tip de cladire; cheia = BuildingConfig id. scaffold = santier in lucru.
    buildings = {
        tent = sprite(84689761947976, 32, 32),
        cottage = sprite(123626265873447, 48, 48),
        bunkhouse = sprite(94857722639619, 64, 48),
        kitchen = sprite(72323975891638, 48, 48),
        smokehouse = sprite(124053671220176, 64, 48),
        workshop = sprite(90845511806967, 64, 64),
        hall = sprite(83498381928881, 64, 64),
        firepit = sprite(133372752321523, 32, 32),
        garden = sprite(92303414609395, 48, 32),
        scaffold = sprite(82500666482801, 64, 64),
    },
    sand_tile = sprite(111588413820639, 128, 48),
    foam_north = sprite(86091808318798, 128, 16),
    foam_south = sprite(110190084089357, 128, 16),
    -- Recuzita de decor: se imprastie determinist din seed, vezi WorldDecor
    props = {
        -- [D62, pasul 5] pasarea care trece peste sat: doua cadre de 8x8, aripile sus si jos. Id 0 = fara pasari.
        bird = sprite(138134353949829, 16, 8),
        tree_round = sprite(96799483152033, 48, 64),
        tree_pine = sprite(117060864160137, 40, 76),
        bush = sprite(134096272864735, 32, 28),
        rock_small = sprite(101372151727323, 20, 20),
        rock_large = sprite(93613323553404, 32, 32),
        stump = sprite(70723966686012, 24, 20),
        log = sprite(119096375971754, 36, 18),
        cattails = sprite(101211546139087, 28, 38),
        fence = sprite(72374065914533, 48, 28),
        barrel = sprite(137319748315390, 22, 28),
        lantern = sprite(78400014968756, 20, 44),
        signpost = sprite(77679899934787, 28, 36),
        flowers = sprite(110918436363008, 26, 22),
        boat = sprite(104312904446511, 60, 30),
    },
    -- Trusa de interfata: rame cu 9 felii (ScaleType.Slice) si pictograme de 16x16.
    -- SLICE spune cat de mare e coltul care NU se intinde.
    ui = {
        panel = sprite(118698913420790, 24, 24),
        button = sprite(95148216188139, 20, 20),
        button_hover = sprite(104941214536899, 20, 20),
        button_down = sprite(75003141578331, 20, 20),
        slot = sprite(133230716227295, 16, 16),
        ribbon = sprite(74980546165947, 20, 20),
        -- E1.9: ce se desena pana acum din Frame+UICorner in client.
        book = sprite(127191973761273, 28, 28), -- butonul cu jurnalul de quest-uri
        badge = sprite(113965013124745, 16, 16), -- bulina rosie cu cifra; se INTINDE, nu are 9 felii (e patrata)
        levelbadge = sprite(105967142732738, 20, 20), -- pastila albastra `Level N` de pe obiecte, 9 felii
        -- [D62, pasul 5] insigna pe rangul nivelului (pragurile 10 / 25 / 50): aceeasi forma, alta culoare
        -- (scripts/art/d62_growth.py). Id 0 = inca neurcata: ramane cea albastra.
        levelbadge_bronze = sprite(121726334051629, 20, 20),
        levelbadge_silver = sprite(88283067790683, 20, 20),
        levelbadge_gold = sprite(93701832962961, 20, 20),
        hand = sprite(86879688969102, 24, 28), -- mana care arata, in tutorial
        glow = sprite(126803264537609, 32, 32), -- inelul reflectorului, 9 felii, mijloc transparent
        -- [D50] dara de ghidaj (sageata spre dreapta, rotita in cod) si inelul de pe jos (alb, colorat
        -- in cod): tinta ghidajului si locul unde stai la gater
        chevron = sprite(120621813543879, 16, 16),
        groundring = sprite(138319155945387, 32, 16),
        -- [D58] butonul de inchidere al panourilor, in trei stari (x2): X-ul desenat, nu glifa U+2715, pe care fontul
        -- de pixeli n-o are
        close = sprite(132144173252476, 20, 20),
        close_hover = sprite(76160501164057, 20, 20),
        close_down = sprite(132296781809933, 20, 20),
        -- [D61] piesele gheretelor, mana de la Wave si notele muzicantilor (scripts/art/d61.py)
        booth_bottle = sprite(95924859733627, 10, 24),
        booth_ring = sprite(99387593948162, 14, 6),
        booth_duck = sprite(110701638521318, 12, 10),
        wave_hand = sprite(135941396804265, 9, 10),
        music_note = sprite(125023281278923, 6, 8),
    },
    -- Ilustratiile cardurilor de capitol. Cheia = id-ul capitolului din QuestConfig.
    chapters = {
        landing = sprite(86407273127369, 150, 100),
    },
    UI_SLICE = {
        panel = 8,
        button = 7,
        slot = 6,
        ribbon = 7,
        plaque = 8,
        card = 10,
        pill = 8,
        levelbadge = 8,
        glow = 12,
    },
    icons = {
        materials = sprite(130374632415580, 16, 16),
        people = sprite(139509950265480, 16, 16),
        bed = sprite(133637863113050, 16, 16),
        food = sprite(79073904881410, 16, 16),
        rest = sprite(82703114667316, 16, 16),
        joy = sprite(124627996670572, 16, 16),
        hammer = sprite(113301578740401, 16, 16),
        fish = sprite(83311057994500, 16, 16),
        build = sprite(94648707516883, 16, 16),
        colony = sprite(103994806847439, 16, 16),
        net = sprite(114057801504121, 16, 16),
        crate = sprite(114427232003717, 16, 16),
        check = sprite(93089105864875, 16, 16),
        arrow = sprite(98144216396634, 16, 16),
        clock = sprite(138525428109478, 16, 16),
        -- [D63] pictogramele magazinului, cate una pe oferta (scripts/art/d63_shop_icons.py): 20x20, ca in randul de
        -- 40 px sa se mareasca exact de doua ori. Id 0 = inca neurcata -> randul arata pictograma de rezerva (`icon`).
        shop_flow2x = sprite(132108850827393, 20, 20),
        shop_swift = sprite(113207874383796, 20, 20),
        shop_nights = sprite(76213651119944, 20, 20),
        shop_supporter = sprite(91804679189991, 20, 20),
        shop_hour = sprite(108362568201532, 20, 20),
        shop_welcome2x = sprite(111284084137212, 20, 20),
        -- E1.9: monedele si randurile de statistica din panoul de niveluri.
        coin = sprite(128440453230234, 16, 16),
        music = sprite(127767294804282, 16, 16), -- [D51] butonul de muzica din bara
        pearl = sprite(97091150455479, 16, 16),
        idle = sprite(127534384783765, 16, 16),
        lock = sprite(83409690070386, 16, 16),
        capacity = sprite(85353863975751, 16, 16),
        speed = sprite(89046216507626, 16, 16),
        carry = sprite(112168472116671, 16, 16),
        levelup = sprite(128109634867858, 16, 16),
        saw = sprite(114993179316384, 16, 16), -- D48: panza gaterului, in lume si in meniul lui
        -- [D59] momeala aurie (premiu al roatii), biletul din sticla (jurnalul), roata din bara de meniu (timonierul mic)
        bait = sprite(86430714701088, 16, 16),
        note = sprite(76288229611949, 16, 16),
        spin = sprite(86359189309483, 16, 16),
        -- `catch` nu are sprite propriu: randul "total catch" e o plasa, iar plasa exista deja
        -- (icons.net). Un al doilea desen de plasa ar fi fost doar inca un fisier de intretinut.
    },
    net = sprite(87402404691704, 48, 28),
    crate = {
        common = sprite(120054651554200, 32, 28),
        uncommon = sprite(71448020804956, 32, 28),
        rare = sprite(111707791040303, 32, 28),
        epic = sprite(139426540184499, 32, 28),
        legendary = sprite(79610568405242, 32, 28),
        mythic = sprite(126926804949614, 32, 28),
    },
    -- F1: bunurile de volum care plutesc spre plase (D2, N6). Driftwood refoloseste bustenul din
    -- decor; celelalte vin din scripts/art (goods_*.png). Obiectele cu nume folosesc `crate`.
    goods = {
        driftwood = sprite(119096375971754, 36, 18),
        reeds = sprite(98267392164439, 24, 18),
        scrap = sprite(132122869387253, 24, 18),
        shards = sprite(131249894514183, 24, 18),
        planks = sprite(90552416808787, 24, 18), -- D48: ce iese din gater (fara id, gramada cade pe driftwood)
        iron = sprite(138679012726799, 24, 18), -- [D55] ce iese din atelier, din scrap
        -- [D65] marfa Morii (scrap-ul ei e acelasi desen ca al Erei 1). Id 0 = inca neurcata.
        parts = sprite(72400680313510, 24, 18),
        ore = sprite(139628705019131, 24, 18),
        copper = sprite(134474343594236, 24, 18),
        -- [D67] marfa Wire Works (minereul ei poarta desenul minereului Morii). Id 0 = inca neurcata.
        coils = sprite(86017575288916, 24, 18),
        battery = sprite(132513999851302, 24, 18),
        cell = sprite(79465091904451, 24, 18),
    },
    -- F1: constructiile Erei 1 (N1, N2): debarcaderul, clopotul, sacul mare, taraba (prop_*.png).
    tycoon = {
        pier = sprite(92244623264237, 64, 40),
        bell = sprite(94872863229377, 40, 56),
        sack = sprite(111594614951317, 24, 24),
        stall = sprite(75165573713976, 48, 40),
        -- F2 (finisaj): platforma ca obiect de lume, nu casuta de interfata
        plaque = sprite(98141889721481, 48, 24), -- placuta de lemn cu pretul, 9 felii
        post = sprite(91004597649738, 8, 26), -- stalpul placutei
        card = sprite(123403307634386, 32, 32), -- rama cartonasului de la apropiere, 9 felii
        pill = sprite(75464273669397, 24, 24), -- pastila din HUD (monede, rata, sac), 9 felii
        netpost = sprite(108154450653369, 14, 30), -- stalpul plasei cumparate, pe mal
        -- F3 (compozitia malului): plasa vazuta ca plasa in apa, nu ca o fereastra alba;
        -- scandurile pontonului; platforma pe care sta o statie; greutatile de la Weighted Nets
        net_water = sprite(84222071706088, 32, 18),
        net_water_full = sprite(94489644287184, 32, 18),
        -- [D62, pasul 5] plasa pe ranguri: flotoare rosii (10), mai multe si ata mai deasa (25), aurii (50). Id 0 =
        -- inca neurcate: plasa ramane cea de azi, la orice nivel.
        net_water_r1 = sprite(93795398301950, 32, 18),
        net_water_r1_full = sprite(97205340659434, 32, 18),
        net_water_r2 = sprite(114496081632708, 32, 18),
        net_water_r2_full = sprite(121596010886450, 32, 18),
        net_water_r3 = sprite(139617938523450, 32, 18),
        net_water_r3_full = sprite(106815901346068, 32, 18),
        deck_tile = sprite(88026317582529, 48, 48),
        -- [D62, pasul 5] pamantul satului copt intr-o singura imagine cu alfa (scripts/art/village_ground.py): 960x640,
        -- un pixel = 3 pixeli de lume. 0 = desenata, inca neurcata -> harta se deseneaza din dale, ca pana acum.
        village_ground = sprite(93287246751537, 960, 640),
        -- [D65] A DOUA FELIE a pamantului copt (x 2880..3840 al lumii): Roblox micsoreaza orice imagine peste 1024 px,
        -- deci lumea latita la 3840 se coace pe felii de 2880. 0 = coapta, inca neurcata: fasia ei se deseneaza din
        -- dale pana atunci (SceneArt). Prima felie de mai sus e inca cea de dinainte de Moara (strada Morii lipseste
        -- din ea pana la urmatoarea urcare, cu acordul owner-ului).
        village_ground_2 = sprite(91716333663371, 880, 640),
        -- [D70, pasul k12] pamantul copt al barajului (lumea 2, 3.385 px): aceleasi felii de 2.880 px de lume
        -- (scripts/art/village_ground.py --world 2). 0 = coapta, inca neurcata: harta barajului se deseneaza din dale si
        -- din zidul provizoriu. Se urca doar cu acordul owner-ului, iar odata cu ID-urile intra si cartierele barajului in
        -- TycoonConfig.BAKED_DISTRICTS (testul din World2Layout le tine impreuna).
        dam_ground = sprite(0, 960, 640),
        dam_ground_2 = sprite(0, 168, 640),
        -- [D75, lotul A1] reperele lumii 2 (scripts/art/a1_*.py). 0 = desenate, inca neurcate: jocul pastreaza desenul
        -- provizoriu (zidul din dale, cladirile de imprumut). Foile cu cadre au cadrele unul langa altul, pe orizontala.
        dam_wall = sprite(0, 80, 189), -- zidul de piatra (varianta A, D75), cu gura turbinei
        dam_spill = sprite(0, 141, 96), -- panza deversorului: 3 cadre de 47 x 96, peste zid
        dam_foam = sprite(0, 52, 96), -- spuma de la picior: 2 cadre de 26 x 96
        old_bells = sprite(0, 32, 80), -- clopotnita cu cele trei clopote vechi
        memory_wall = sprite(0, 64, 32),
        dam_cottage_1 = sprite(0, 40, 34),
        dam_cottage_2 = sprite(0, 40, 34),
        dam_cottage_3 = sprite(0, 40, 34),
        pylon_tall = sprite(0, 16, 67), -- stalpul de zabrele de langa rau
        pylon_lane = sprite(0, 8, 40),
        pylon_post = sprite(0, 5, 23), -- stalpii de pe podul canalului
        river_crystal = sprite(0, 36, 16), -- 2 cadre de 18 x 16: cristalul care pluteste de la finalul Erei 3
        painted_town = sprite(0, 340, 44), -- oraselul pictat de pe malul de nord
        painted_town_lit = sprite(0, 340, 44), -- doar luminile lui, peste el
        -- [D75, lotul A2] filmul barajului (scripts/art/a2_*.py; DamFilm, DamFilmSet). 0 = desenate, inca neurcate: filmul
        -- ramane amurgul peste satul adevarat, cu zidul din piatra simpla care creste peste rau.
        film_scaffold = sprite(0, 80, 16), -- un etaj de schela cat zidul, repetat pe verticala
        film_wall_edge_n = sprite(0, 80, 10), -- capatul neterminat al jumatatii de nord
        film_wall_edge_s = sprite(0, 80, 10), -- si al celei de sud
        film_crane = sprite(0, 64, 48), -- 2 cadre de 32 x 48
        film_stone_cart = sprite(0, 28, 16),
        film_stone_pile = sprite(0, 32, 16),
        film_dust = sprite(0, 48, 12), -- 3 cadre de 16 x 12
        film_walkers = sprite(0, 64, 96), -- siluete: 4 randuri (gol, grinda, piatra, felinar) x 4 cadre de 16 x 24
        film_workers = sprite(0, 64, 48), -- 2 randuri (ciocanul, funia) x 4 cadre de 16 x 24
        film_works_bell_swing = sprite(0, 120, 56), -- 3 cadre de 40 x 56, exact peste works_bell
        platform = sprite(136060284598059, 48, 24),
        weights = sprite(116698981575799, 24, 16),
        -- pier2 (64x48) a fost respins: se citea ca o lada cu capac. pier3 e pontonul inalt,
        -- cu scanduri transversale, pe care se vede ca umbli.
        pier3 = sprite(117181183797139, 32, 56),
        -- lipsea din rezervarea initiala, dar agentul de arta o deseneaza [F2 spec, Agent H]:
        -- adapostul lui First Runner odata cumparat, cere o cheie in manifest ca sa aiba unde intra
        runner_hut = sprite(136213749143220, 40, 36),
        -- [D53] ruinele malului, avizierele si atelierul nou (scripts/art/ruins_d53.py). Id 0 = inca neurcat:
        -- `Assets.has` e fals si PadController ramane pe desenul de dinainte (siluetele).
        ruin_netpost = sprite(91539585634485, 14, 30),
        ruin_net = sprite(128052179414609, 32, 18),
        ruin_hut = sprite(87006321578748, 40, 36),
        ruin_stall = sprite(84392957824356, 48, 40),
        ruin_sack = sprite(104094131297685, 24, 24),
        ruin_bell = sprite(137845176943532, 40, 56),
        ruin_workshop = sprite(138162606027239, 64, 48),
        workshop_e1 = sprite(98687049648969, 64, 48),
        board_old = sprite(82502800842325, 24, 32),
        board = sprite(120551282583746, 24, 32),
        -- E1.8: roata zilnica. 0 = generata local (scripts/art/tycoon_e1.py) dar inca neurcata --
        -- pana atunci UI-ul deseneaza o rezerva plata, ca la orice sprite lipsa.
        wheel = sprite(95698712031588, 40, 40),
        -- D48: gaterul, cladirea dintre carat si vanzare (fara id -> sopron desenat in cod)
        sawmill = sprite(75182981241928, 40, 32),
        -- [D62, pasul 5] a doua infatisare, de la nivelul 25 (scripts/art/d62_grand.py): aceeasi foaie, aceleasi locuri
        -- pentru panza, horn si usa. Id 0 = desenate, inca neurcate: cladirea ramane cea de azi la orice nivel.
        sawmill_grand = sprite(88632019254925, 40, 32),
        tavern_grand = sprite(76031135146562, 64, 48),
        workshop_grand = sprite(95704049513242, 64, 48),
        wheel_face = sprite(118757044132689, 64, 64),
        -- D49: depozitul de langa plase, unde varsa Collector-ul (fara id -> sopron desenat in cod)
        storage = sprite(100160905448383, 40, 32),
        -- D50: taverna, locul de vanzare (fara id -> casa desenata in cod)
        tavern = sprite(137193105345520, 64, 48),
        -- [D55] scripts/art/d55.py. Roaba oamenilor: fasie cu trei vederi de 24x20 (lateral spre dreapta, spre
        -- tine, de la tine) si incarcatura ei, fasii cu 3 trepte de 16x9. Gramezile: fasii cu 4 trepte de 40x28.
        -- Shed-ul de scrap si ruina lui; colibele oamenilor, mica (un om) si mare (doi). Id 0 = inca neurcat.
        barrow = sprite(119585275650745, 72, 20),
        load_logs = sprite(122278810809813, 48, 9),
        load_planks = sprite(95764052869278, 48, 9),
        load_scrap = sprite(110795275724218, 48, 9),
        load_iron = sprite(133283748095694, 48, 9),
        load_crate = sprite(72106465333366, 48, 9),
        pile_logs = sprite(102342481494046, 160, 28),
        pile_planks = sprite(83740208739860, 160, 28),
        pile_scrap = sprite(77672455779936, 160, 28),
        pile_iron = sprite(71911464957856, 160, 28),
        -- [D65] ARTA MORII (scripts/art/d65_mill.py, d65_crew.py). Id 0 = inca neurcata: pana atunci fiecare loc poarta
        -- desenul perechii din Era 1 (TycoonConfig.PAD_LOOKS_LIKE / GOOD_LOOKS_LIKE, HandConfig.OUTFIT_LOOKS_LIKE).
        mill_store = sprite(71223891432505, 40, 32),
        foundry = sprite(85335491781046, 40, 32),
        market = sprite(83365591938705, 64, 48),
        water_wheel = sprite(105238723804617, 48, 48),
        water_wheel_spin = sprite(87241172674036, 192, 48), -- [D67, audit] 4 cadre: roata se invarte (UI/Spin)
        copper_furnace = sprite(132247513251155, 64, 48),
        ore_shed = sprite(140203242666181, 40, 32),
        mill_bell = sprite(94086830227246, 40, 56),
        ruin_mill_store = sprite(79778219280865, 40, 32),
        ruin_foundry = sprite(106458904177228, 40, 32),
        ruin_market = sprite(71591556710613, 64, 48),
        ruin_water_wheel = sprite(134295197060005, 48, 48),
        ruin_copper_furnace = sprite(122863369678497, 64, 48),
        ruin_ore_shed = sprite(112558940076570, 40, 32),
        ruin_mill_bell = sprite(135905154022220, 40, 56),
        hut_mill_collector_1 = sprite(93113743355332, 32, 28),
        hut_mill_collector_2 = sprite(120399541180154, 40, 34),
        hut_mill_porter_1 = sprite(139179781992595, 32, 28),
        hut_mill_porter_2 = sprite(86652521034330, 40, 34),
        hut_founder_1 = sprite(73967345338676, 32, 28),
        hut_founder_2 = sprite(80461819728760, 40, 34),
        hut_parts_hauler_1 = sprite(71490682606570, 32, 28),
        hut_parts_hauler_2 = sprite(130282544235450, 40, 34),
        hut_ore_collector_1 = sprite(78171718111324, 32, 28),
        hut_ore_collector_2 = sprite(86135874694927, 40, 34),
        hut_ore_porter_1 = sprite(96322804273530, 32, 28),
        hut_ore_porter_2 = sprite(87357807535892, 40, 34),
        hut_coppersmith_1 = sprite(78839422604307, 32, 28),
        hut_coppersmith_2 = sprite(118951305697202, 40, 34),
        hut_copper_hauler_1 = sprite(105809366134714, 32, 28),
        hut_copper_hauler_2 = sprite(94226462741610, 40, 34),
        stall_merchant = sprite(102801419273883, 48, 40),
        stall_merchant_2 = sprite(106064427770865, 64, 40),
        load_parts = sprite(94292880687967, 48, 9),
        load_ore = sprite(132573549287036, 48, 9),
        load_copper = sprite(97580815649246, 48, 9),
        pile_parts = sprite(120188180597902, 160, 28),
        pile_ore = sprite(114609418668821, 160, 28),
        pile_copper = sprite(116884575542469, 160, 28),
        -- [D67] ARTA WIRE WORKS (scripts/art/d67_works.py, d67_crew.py). Id 0 = inca neurcata: pana atunci fiecare loc
        -- poarta desenul perechii din Moara (TycoonConfig.PAD_LOOKS_LIKE / GOOD_LOOKS_LIKE, HandConfig.OUTFIT_LOOKS_LIKE).
        works_store = sprite(126013207378063, 40, 32),
        wire_works = sprite(106900472973856, 40, 32),
        depot = sprite(113196855861436, 64, 48),
        steam_engine = sprite(126907357764293, 48, 48),
        power_house = sprite(89874313804605, 64, 48),
        battery_shed = sprite(70536589282026, 40, 32),
        works_bell = sprite(130371949688670, 40, 56),
        turbine = sprite(76737615657608, 48, 48),
        turbine_spin = sprite(73376293649540, 192, 48), -- [D67, audit] 4 cadre: roata se invarte (UI/Spin)
        -- [D70] MODERNIZAREA SATULUI VECHI IN ERA 3 (scripts/art/d70_modern.py; treptele in ModernMath). Aprobate de
        -- owner pe plansa pe 2026-09-29. Id 0 = inca neurcata: fiecare loc ramane pe desenul de azi.
        wire_pole = sprite(70799154653699, 16, 54),
        wire_pole_end = sprite(114936955780983, 28, 54),
        barrow_iron = sprite(119114453945483, 72, 20),
        storage_modern = sprite(117064081962379, 40, 32),
        sawmill_modern = sprite(124234295616574, 40, 32),
        sawmill_grand_modern = sprite(113446325649824, 40, 32),
        tavern_modern = sprite(74781581132216, 64, 48),
        tavern_grand_modern = sprite(86395460361326, 64, 48),
        scrap_shed_modern = sprite(108119957528412, 40, 32),
        workshop_modern = sprite(138182614577995, 64, 48),
        workshop_grand_modern = sprite(109815212052601, 64, 48),
        windows_glass = sprite(109716704448794, 320, 204),
        dam_plans = sprite(138911197043190, 48, 44),
        survey_stakes = sprite(120890070888884, 36, 26),
        windows_lit = sprite(118372829924473, 320, 204),
        modern_lit = sprite(91614247664256, 256, 96),
        cable_drums = sprite(117712532973107, 48, 32),
        substation = sprite(102733165478358, 56, 48),
        ruin_works_store = sprite(81087067861198, 40, 32),
        ruin_wire_works = sprite(122058304556328, 40, 32),
        ruin_depot = sprite(122318724202996, 64, 48),
        ruin_steam_engine = sprite(124231642295711, 48, 48),
        ruin_power_house = sprite(105755602735084, 64, 48),
        ruin_battery_shed = sprite(105653428635792, 40, 32),
        ruin_works_bell = sprite(109654328712224, 40, 56),
        hut_works_collector_1 = sprite(92413017695028, 32, 28),
        hut_works_collector_2 = sprite(82418172054995, 40, 34),
        hut_works_porter_1 = sprite(71527185145204, 32, 28),
        hut_works_porter_2 = sprite(122115610285147, 40, 34),
        hut_wiredrawer_1 = sprite(101399759806803, 32, 28),
        hut_wiredrawer_2 = sprite(93326667172683, 40, 34),
        hut_coil_hauler_1 = sprite(82615219695035, 32, 28),
        hut_coil_hauler_2 = sprite(133443219557627, 40, 34),
        hut_battery_collector_1 = sprite(76550185547372, 32, 28),
        hut_battery_collector_2 = sprite(105593052546640, 40, 34),
        hut_battery_porter_1 = sprite(134892073938448, 32, 28),
        hut_battery_porter_2 = sprite(117623874285615, 40, 34),
        hut_electrician_1 = sprite(71775355061503, 32, 28),
        hut_electrician_2 = sprite(86917713001238, 40, 34),
        hut_power_hauler_1 = sprite(119605340479201, 32, 28),
        hut_power_hauler_2 = sprite(82714220175906, 40, 34),
        stall_clerk = sprite(120064783107268, 48, 40),
        stall_clerk_2 = sprite(112306545272781, 64, 40),
        load_coils = sprite(99857966231262, 48, 9),
        load_battery = sprite(94295677740987, 48, 9),
        load_cell = sprite(128901939798627, 48, 9),
        pile_coils = sprite(101229101055119, 160, 28),
        pile_battery = sprite(134820681258967, 160, 28),
        pile_cell = sprite(139942311674023, 160, 28),
        -- felinarele de pe strada, stinse si aprinse, si lumina lor (pasul 5 al Erei 3)
        street_lamp = sprite(109489491007186, 12, 40),
        street_lamp_lit = sprite(128935797179227, 12, 40),
        lamp_glow = sprite(78073029667107, 32, 32),
        scrap_shed = sprite(89758445685801, 40, 32),
        ruin_scrap_shed = sprite(97144771907218, 40, 32),
        hut_porter_1 = sprite(106380641625046, 32, 28),
        hut_porter_2 = sprite(101783739413060, 40, 34),
        hut_sawyer_1 = sprite(116481816615732, 32, 28),
        hut_sawyer_2 = sprite(139412865739552, 40, 34),
        hut_hauler_1 = sprite(124383037580253, 32, 28),
        hut_hauler_2 = sprite(128353694504179, 40, 34),
        runner_hut_2 = sprite(111300382776252, 48, 40),
        stall_2 = sprite(121127549847093, 64, 40),
        -- [D56] scripts/art/d56.py: colibele oamenilor fierului (mica / mare) si fumul hornului forjei (fasie cu
        -- trei nori de 10x10). Id 0 = inca neurcat.
        hut_scrap_collector_1 = sprite(117732330111184, 32, 28),
        hut_scrap_collector_2 = sprite(117656831487886, 40, 34),
        hut_scrap_porter_1 = sprite(79197078173844, 32, 28),
        hut_scrap_porter_2 = sprite(88413706948685, 40, 34),
        hut_smelter_1 = sprite(71153210974685, 32, 28),
        hut_smelter_2 = sprite(121231899171956, 40, 34),
        hut_iron_hauler_1 = sprite(100681471520359, 32, 28),
        hut_iron_hauler_2 = sprite(90038858826137, 40, 34),
        forge_smoke = sprite(82327509756017, 30, 10),
        -- [D59] scripts/art/d59.py: pontonul lung (locul de pescuit), plutitorul, roata zilnica ca timonier pe punte si
        -- fata ei din panou (spitele la multipli de 45 de grade, iconitele premiilor le pune codul), avizierul satului.
        -- Id 0 = inca neurcat.
        pier_long = sprite(89476195993441, 32, 104),
        bobber = sprite(113053469115992, 8, 10),
        helm = sprite(129602449291697, 40, 48),
        helm_face = sprite(118436325407447, 64, 64),
        village_board = sprite(90611103033542, 40, 44),
    },
    -- [D59] cele 12 specii ale jurnalului (FishConfig), pe profil, capul la stanga (fish_<id>.png)
    fish = {
        minnow = sprite(104838629254248, 20, 16),
        roach = sprite(136030784477082, 20, 16),
        perch = sprite(91290989316355, 20, 16),
        bream = sprite(79713811649073, 20, 16),
        trout = sprite(91786419075325, 20, 16),
        chub = sprite(98486590792746, 20, 16),
        carp = sprite(88174610925388, 20, 16),
        eel = sprite(91948749812624, 20, 16),
        pike = sprite(102903563080606, 20, 16),
        catfish = sprite(73425419100723, 20, 16),
        sturgeon = sprite(99006995822777, 20, 16),
        goldcarp = sprite(114384138876222, 20, 16),
    },
    -- [D59] ce aduce raul (TreasureConfig): intregi (jurnalul, rezultatul) si pe jumatate in apa (cand plutesc si cand
    -- asteapta la ponton), treasure_<fel>[_water].png
    treasure = {
        bottle = sprite(101800607258354, 16, 16),
        chest = sprite(83773242496262, 20, 16),
        golden = sprite(109714973274162, 24, 12),
        bottle_water = sprite(72648872332248, 16, 16),
        chest_water = sprite(97270437241778, 20, 16),
        golden_water = sprite(114933237701252, 24, 12),
        -- [D62, pasul 3] darurile raului (scripts/art/d62.py): butoiul si lada care trec plutind. Id 0 = inca neurcate:
        -- DriftController deseneaza un butoi / o lada din dreptunghiuri, cat sa se vada ce trece.
        barrel_water = sprite(134729708355571, 22, 16),
        crate_water = sprite(132442186024728, 20, 16),
    },
    -- [D59] imbunatatirile satului cumparate cu perle (VillageConfig.DECOR), decor_<id>.png
    decor = {
        flowerbed = sprite(98215678779896, 32, 14),
        pier_lamp = sprite(105853641815036, 12, 32),
        bench = sprite(85722203903431, 32, 20),
        bunting = sprite(115700354377254, 64, 24),
        well = sprite(78354675256953, 32, 40),
        veggie_patch = sprite(109495687268052, 48, 40),
        rowboat = sprite(71688014218371, 40, 20),
        beehives = sprite(76028188795736, 40, 28),
        fountain = sprite(78184223252965, 48, 40),
        statue = sprite(81288800690481, 32, 56),
    },
    -- [D60] Balciul de seara: hub-ul rotund din place-ul al doilea, la care ajungi cu barca in amonte.
    -- Fisierele sunt prop_fair_<cheie>.png / tile_fair.png (scripts/art/d60.py). 0 = inca neurcat.
    fair = {
        stage = sprite(114372308501503, 200, 112), -- scena care e si tabela: trei panouri de clasament
        wheel = sprite(105012617626073, 70, 86), -- roata zilnica, mutata din sat
        stall_1 = sprite(98566174055056, 52, 44),
        stall_2 = sprite(128622133404661, 52, 44),
        stall_3 = sprite(94824509060723, 52, 44),
        -- [D61, partea 2] taraba `Shop`, cu copertina aurie (scripts/art/d60.py), urcata pe 2026-09-19. Sta in
        -- FairLayout.SPOTS (`shop`), cu cardul ei (ShopController); magazinul se deschide si din bara din dreapta (P).
        shop = sprite(103949308440277, 52, 44),
        tent = sprite(103727982758295, 60, 54),
        booth = sprite(90436942055073, 46, 40),
        arch = sprite(125405145209167, 76, 58),
        dock = sprite(71587394039128, 40, 64),
        ferry = sprite(77116352932467, 62, 30),
        bonfire = sprite(77625323861703, 40, 34),
        brazier = sprite(116599557369227, 22, 32),
        table = sprite(89717753669884, 40, 22),
        bench = sprite(74360052312127, 26, 14),
        lamppost = sprite(119592313749241, 16, 48),
        plinth = sprite(86875850174714, 28, 42),
        flag = sprite(139477137240825, 18, 54),
        trophy = sprite(134739125649476, 24, 34),
        crate = sprite(78506727653514, 20, 18),
        barrel = sprite(84865005444327, 18, 24),
        reeds = sprite(83701820915406, 18, 26),
        miniature = sprite(90688181765981, 32, 26), -- satul altcuiva, pe panoul de la poarta
        -- [2026-09-17] fundalul copt al balciului (scripts/art/d60_ground.py) si lumina moale colorata de joc
        ground = sprite(125388865699081, 740, 720),
        glow = sprite(122489449102404, 64, 64),
        -- [D61] tabla concursului de la iaz si muzicantii (scripts/art/d61.py); cadrele muzicantilor sunt imagini
        -- separate, cu aceeasi marime, ca sa ramana cutia unui om in FairLayout
        pond_board = sprite(73087998923570, 60, 52),
        performer = sprite(114790962686258, 18, 30),
        performer_b = sprite(91638431233055, 18, 30),
        musician = sprite(73984848832473, 20, 30),
        musician_b = sprite(76251714686019, 20, 30),
    },
    -- F1 (O1): sunete sintetizate de noi (scripts/audio), urcate ca Audio. 0 = inca neincarcat ->
    -- SoundController tace, fara eroare.
    -- [D51] Muzica de fundal, compusa de noi (scripts/audio/make_music.py). 0 = neurcata -> tace, iar
    -- butonul ei nu apare in bara.
    music = {
        river = 72095931356905,
        fair = 106949553479700, -- [D61] melodia balciului (scripts/audio/make_music.py fair)
        dam_film = 0, -- [D75, lotul A2] piesa filmului barajului, 17 s (scripts/audio/a2_film.py); 0 = neurcata
    },
    sounds = {
        splash = 125294013048224,
        coin = 132354522900169,
        build = 131776227537036,
        register = 123381692932148,
        chime = 132690579351252,
        bell = 107388484123769,
        click = 136514245754835,
        pop = 126278560484276,
        wheel = 90681910341082, -- E1.9: clichetul rotii zilnice
        saw = 78733154399219, -- D48: panza gaterului, cand taie
        -- [D59] undita: aruncarea, pestele care trage, mulinetul cat se strange firul
        cast = 125225061548722,
        bite = 112435773204646,
        reel = 127909885590038,
        -- [D62] un nivel cumparat si un prag trecut (scripts/audio/make_sounds.py); 0 = inca neurcate, iar pana
        -- atunci SoundController foloseste "pop" si "chime"
        levelup = 108593613284344,
        milestone = 79391496851488,
        -- [D75, lotul A2] filmul barajului (scripts/audio/a2_film.py): santierul si zidul care se inchide; 0 = neurcate
        film_build = 0,
        film_close = 0,
    },
}

function Assets.url(s: Sprite): string
    return `rbxassetid://{s.id}`
end

function Assets.has(s: Sprite): boolean
    return s.id ~= 0
end

function Assets.soundUrl(id: number): string
    return `rbxassetid://{id}`
end

return Assets
