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
            a = sprite(112586528099567, 64, 360),
            b = sprite(78466711368987, 64, 360),
        },
        hair = {
            short = sprite(118861972684779, 64, 360),
            long = sprite(85022617295536, 64, 360),
            bun = sprite(94025470529885, 64, 360),
            bald = sprite(0, 64, 360),
        },
        outfit = {
            Fisher = sprite(74418128514894, 64, 360),
            Crafter = sprite(119194228310035, 64, 360),
            Builder = sprite(81470649204888, 64, 360),
            Gardener = sprite(121440047199288, 64, 360),
            Innkeeper = sprite(75711456309293, 64, 360),
            keeper = sprite(128266013737841, 64, 360), -- doar jucatorul
        },
    },
    path_tile = sprite(124285357370417, 64, 64),
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
    },
    UI_SLICE = { panel = 8, button = 7, slot = 6, ribbon = 7 },
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
}

function Assets.url(s: Sprite): string
    return `rbxassetid://{s.id}`
end

function Assets.has(s: Sprite): boolean
    return s.id ~= 0
end

return Assets
