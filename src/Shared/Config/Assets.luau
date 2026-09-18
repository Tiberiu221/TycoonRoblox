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
            -- [D59] tinutele jucatorului, cumparate cu perle (angler, captain) sau din jurnalul complet (legend). Cheile
            -- cu litera mica, ca `keeper`: nu sunt meserii. Id 0 = inca neurcat -> personajul ramane in `keeper`.
            angler = sprite(77086694802414, 64, 480),
            captain = sprite(96665945822082, 64, 480),
            legend = sprite(117264524949067, 64, 480),
            -- [D61, partea 2] tinutele croitoresei din balci (scripts/art/settlers.py). Id 0 = inca neurcat: randul
            -- ei din panou ramane fara portret, iar omul imbracat asa ramane in `keeper`.
            festival = sprite(0, 64, 480),
            minstrel = sprite(0, 64, 480),
            lampkeeper = sprite(0, 64, 480),
            harvest = sprite(0, 64, 480),
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
        deck_tile = sprite(88026317582529, 48, 48),
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
        ground = sprite(135941370631156, 740, 720),
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
