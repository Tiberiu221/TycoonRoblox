--!strict
-- Arta procedurala de prototip, doar din primitive UI (fara upload de imagini). Se inlocuieste cu sprite-uri la pasul 4 [DECIZII D23].
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local Shoreline = require(ReplicatedStorage.Shared.Modules.Shoreline)
local VillageDecor = require(ReplicatedStorage.Shared.Modules.VillageDecor)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local SceneArt = {}

local function image(
    parent: Instance,
    s: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Image = Assets.url(s)
    img.BackgroundTransparency = 1
    img.Position = UDim2.fromOffset(x, y)
    img.Size = UDim2.fromOffset(w, h)
    img.ResampleMode = Enum.ResamplerMode.Pixelated -- pixel-art crocant la marire [DECIZII D23]
    img.ZIndex = z
    img.Parent = parent
    return img
end

local function tiled(
    parent: Instance,
    s: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = image(parent, s, x, y, w, h, z)
    img.ScaleType = Enum.ScaleType.Tile
    img.TileSize = UDim2.fromOffset(s.width * Assets.PIXEL_SCALE, s.height * Assets.PIXEL_SCALE)
    return img
end

local function frame(
    parent: Instance,
    x: number,
    y: number,
    w: number,
    h: number,
    color: Color3,
    z: number
): Frame
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(top, bottom)
    g.Rotation = rotation or 90
    g.Parent = parent
end

local function rounded(parent: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
end

-- Cer, soare, dealuri, mal, apa cu valuri. Returneaza stratul de apa (pentru animatie).
-- [D70, pasul k1] `Plot` (optional): stratul platformelor si al plutitorilor; spuma de la piciorul zidului barajului sta
-- peste plutitori, deci acolo. Balciul (macheta) nu-l da.
export type Layers = { Fixed: Frame, Parallax: Frame, Scroll: Frame, Plot: Frame? }

-- Harta de sus. Straturile, de jos in sus: iarba, nisip la maluri, apa care curge, spuma la
-- linia apei, drum, terenul jucatorului, apoi decorul (copaci, tufe, pietre, papura).
-- Decorul se aseaza determinist din seed (WorldDecor, prin VillageDecor), deci lumea arata la fel la fiecare intrare.
-- seed-urile hartii: aceleasi la fiecare intrare, deci malul si petele nu "sar" intre sesiuni
local PATCH_SEED = 771104
local FOREST_SEED = 480917

local function decorSprite(kind: string): Assets.Sprite?
    local sprite = (Assets.props :: any)[kind]
    if sprite ~= nil and Assets.has(sprite) then
        return sprite
    end
    return nil
end

local function buildDecor(scroll: Frame, world: number)
    -- [D65] partea veche a satului isi tine copacii pe loc, fasia noua isi primeste ai ei (WorldDecor.village)
    -- [D70, pasul j1] samanta si argumentele stau in VillageDecor (le citesc si pamantul copt si martorul lumii 1)
    local items = VillageDecor.items(world)

    local layer = Instance.new("Frame")
    layer.Name = "DecorLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 5
    layer.Parent = scroll

    for _, item in items do
        local sprite = decorSprite(item.kind)
        if sprite == nil then
            continue
        end
        local w = sprite.width * Assets.PIXEL_SCALE
        local h = sprite.height * Assets.PIXEL_SCALE
        local img = image(layer, sprite, 0, 0, w, h, 5)
        -- ancorat la baza: obiectul "sta" pe punctul lui, nu e centrat pe el
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(item.x, item.y)
        -- sortare pe adancime, la fel ca la colonisti: ce e mai jos acopera ce e mai sus
        img.ZIndex = 5 + math.clamp(math.floor(item.y / 64), 0, 40)
    end
end

-- Iarba desenata din dale (harta fara imaginea coapta): dala de baza, a doua tesatura si petele de nuanta.
local function buildGrass(groundLayer: Frame, W: number, H: number)
    tiled(groundLayer, Assets.grass_tile, 0, 0, W, H, 0)
    -- A doua tesatura, la o scara care NU e multiplu al primeia: ochiul prinde imediat un tile
    -- repetat la 384px, dar doua tipare care nu se suprapun niciodata la fel nu mai au ritm.
    local weave = image(groundLayer, Assets.grass_tile, -90, -140, W + 180, H + 280, 1)
    weave.ScaleType = Enum.ScaleType.Tile
    weave.TileSize = UDim2.fromOffset(
        math.round(Assets.grass_tile.width * Assets.PIXEL_SCALE * 1.53),
        math.round(Assets.grass_tile.height * Assets.PIXEL_SCALE * 1.37)
    )
    weave.ImageTransparency = 0.72

    -- Petele de nuanta: nu sunt obiecte, doar culoare intinsa moale peste iarba. Rolul lor e ca
    -- ochiul sa nu mai recunoasca un singur tile repetat la infinit.
    local GRASS_TONES = {
        Color3.fromRGB(152, 188, 106), -- bataia soarelui
        Color3.fromRGB(64, 102, 54), -- umbra deasa
        Color3.fromRGB(146, 126, 84), -- pamant calcat, uscat
    }
    -- Petele stau DOAR pe malul de sud, sub cea mai adanca intrare a apei (824): asa nu e nevoie
    -- sa fie decupate dupa forma malului, si nu le acopera coloanele de mal desenate mai jos.
    local patchArea = { x0 = 0, y0 = 860, x1 = W, y1 = H - 20, tones = #GRASS_TONES }
    for _, p in Shoreline.patches(PATCH_SEED, patchArea, 84) do
        local f = frame(groundLayer, p.x, p.y, p.w, p.h, GRASS_TONES[p.tone], 1)
        f.BackgroundTransparency = 0.87
        f.Rotation = p.rot
        rounded(f, math.floor(math.min(p.w, p.h) / 2))
        local g = Instance.new("UIGradient")
        g.Rotation = p.rot + 90
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = f
    end
end

-- [D70, pasul k1] `world`: harta (fara ea, satul; balciul o cheama asa pentru macheta). La baraj: latimea si malurile lui,
-- fara pamantul copt al satului (BAKED_DISTRICTS, imaginea satului), cu lacul, zidul, deversorul si canalul desenate
-- provizoriu din TycoonConfig.WORLDS[2] pana la pamantul lui copt (k12).
function SceneArt.BuildBackground(layers: Layers, world: number?)
    local worldId = WorldConfig.sanitize(world)
    local river = (RiverConfig.WORLDS :: any)[worldId]
    local W, H = river.WORLD_WIDTH, river.WORLD_HEIGHT
    local scroll = layers.Scroll
    local pixel = Assets.has(Assets.water_tile)
    if not pixel then
        local g = frame(scroll, 0, 0, W, H, Color3.new(1, 1, 1), 0)
        gradient(g, Color3.fromRGB(110, 160, 80), Color3.fromRGB(85, 130, 65))
        local water = frame(
            scroll,
            0,
            river.RIVER_TOP,
            W,
            river.RIVER_BOTTOM - river.RIVER_TOP,
            Color3.new(1, 1, 1),
            1
        )
        gradient(water, Color3.fromRGB(70, 140, 175), Color3.fromRGB(35, 90, 130))
        return
    end

    -- ---- HARTA ----------------------------------------------------------------------------
    -- Rescrisa 2026-09-12. Inainte: iarba plata + trei dreptunghiuri (apa si doua fasii de nisip),
    -- toate cu muchii perfect drepte -- de aceea harta parea "desenata in paint". Acum linia apei
    -- serpuieste (Shoreline: modul pur, testat), iarba are pete de nuanta, canalul are adancime,
    -- malul are plaja cu nisip ud, pietre si spuma care se leagana.
    local function layerFrame(name: string, z: number): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.BackgroundTransparency = 1
        f.Size = UDim2.fromOffset(W, H)
        f.ZIndex = z
        f.Parent = scroll
        return f
    end
    -- Straturile hartii. Platformele si personajul stau la Z=5 (CameraController), deci TOT
    -- fundalul trebuie sa incapa sub 5; ordinea in interiorul unui strat o da ZIndex-ul copiilor.
    local groundLayer = layerFrame("Ground", 0)
    local waterLayer = layerFrame("Water", 1)
    local shoreLayer = layerFrame("Shore", 2)
    local trimLayer = layerFrame("Trim", 3)
    local builtLayer = layerFrame("Built", 4)

    -- [D62, pasul 5] PAMANTUL COPT: cand imaginea e urcata, tot uscatul (iarba, padurea, plajele, puntea, curtile,
    -- drumurile, piata) e O SINGURA imagine cu alfa, facuta de scripts/art/village_ground.py din aceleasi cifre
    -- (Shoreline, TycoonConfig). Raul animat curge pe dedesubt si se vede prin partea ei transparenta, unde imaginea
    -- are doar tentele apei: apa mica langa maluri si canalul adanc, dupa forma malurilor. Din desenul vechi raman
    -- doar ce se misca (apa, spuma) si obiectele asezate peste. Pana la urcare, harta se deseneaza ca inainte.
    local baked = worldId == 1 and Assets.has(Assets.tycoon.village_ground)
    if not baked then
        buildGrass(groundLayer, W, H)
    end
    -- Apa se intinde DINCOLO de banda raului: coloanele de mal musca din ea in ambele sensuri,
    -- deci sub iarba trebuie sa existe apa si acolo unde linia malului urca peste RIVER_TOP.
    -- Marginile trebuie sa treaca DINCOLO de cea mai adanca intrare a fiecarui mal (392 sus,
    -- 824 jos), altfel ar ramane iarba acolo unde malul s-a retras si ar trebui sa fie apa.
    local waterTop = 368
    local waterBottom = 848
    local waterH = waterBottom - waterTop
    local tileW = Assets.water_tile.width * Assets.PIXEL_SCALE
    local water = tiled(waterLayer, Assets.water_tile, -tileW, waterTop, W + tileW * 2, waterH, 1)
    -- al doilea strat de apa, translucid si mai lent: da senzatia de adancime fara shader
    local shimmer = tiled(waterLayer, Assets.water_tile, -tileW, waterTop, W + tileW * 2, waterH, 2)
    shimmer.ImageTransparency = 0.55
    -- Canalul: mijlocul raului e mai adanc, deci mai intunecat. O SINGURA banda, nu cate una pe
    -- coloana: incercarea pe coloane avea alt gradient in fiecare, iar la imbinari sareau
    -- treptele -- in joc se vedeau dreptunghiuri negre la fiecare 32px. Capetele nu trebuie taiate
    -- dupa forma malului: coloanele de iarba de deasupra o fac oricum.
    if not baked then
        local depth = frame(waterLayer, 0, waterTop, W, waterH, Color3.fromRGB(8, 34, 62), 3)
        local depthGradient = Instance.new("UIGradient")
        depthGradient.Rotation = 90
        depthGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0.6),
            NumberSequenceKeypoint.new(1, 1),
        })
        depthGradient.Parent = depth
    end

    -- Cele doua maluri. Cifrele sunt in campurile SHORE din RiverConfig, ca sa le poata verifica testele:
    -- uscatul nu are voie sa intre peste benzile bunurilor, iar apa nu are voie sa atinga
    -- pontonul. Malul de nord se retrage spre nord (raul se latește pe alocuri), cel de sud spre
    -- sud, iar in dreptul terenului construit ramane aproape drept -- e malul tau, amenajat.
    local FAR: Shoreline.Edge = river.SHORE_FAR
    local NEAR: Shoreline.Edge = river.SHORE_NEAR
    local STEP = 32
    local sandTileH = Assets.sand_tile.height * Assets.PIXEL_SCALE
    local hasSand = Assets.has(Assets.sand_tile)

    -- O coloana de mal: un dreptunghi DECUPAT in care iarba si nisipul se deseneaza cu acelasi
    -- decalaj negativ ca pe restul hartii, deci tile-urile se leaga peste coloane, fara custuri.
    -- Latimea plajei vine din coloana: pe portiuni intregi e zero, si atunci iarba ajunge in apa.
    -- Coloana acopera DOAR fasia apei, nu tot malul: iarba de baza (cu petele ei) ramane vizibila
    -- peste tot in rest. Daca ar merge pana la marginea lumii, ar redesena iarba plata peste pete.
    local function bankColumn(c: Shoreline.Column, fromTop: boolean)
        local edge = math.round(c.y)
        local y0 = if fromTop then waterTop else edge
        local h = if fromTop then edge - waterTop else waterBottom - edge
        if h <= 0 then
            return
        end
        local box = Instance.new("Frame")
        box.Name = "Bank"
        box.BackgroundTransparency = 1
        box.ClipsDescendants = true
        box.Position = UDim2.fromOffset(c.x, y0)
        box.Size = UDim2.fromOffset(c.w, h)
        box.ZIndex = 1
        box.Parent = shoreLayer
        tiled(box, Assets.grass_tile, -c.x, -y0, W, H, 1)
        local beach = math.round(c.beach)
        if not hasSand or beach <= 2 then
            return
        end
        local sandY = if fromTop then h - beach else 0
        local sandBox = Instance.new("Frame")
        sandBox.Name = "Beach"
        sandBox.BackgroundTransparency = 1
        sandBox.ClipsDescendants = true
        sandBox.Position = UDim2.fromOffset(0, sandY)
        sandBox.Size = UDim2.fromOffset(c.w, beach)
        sandBox.ZIndex = 2
        sandBox.Parent = box
        local sand = tiled(sandBox, Assets.sand_tile, -c.x, -(y0 + sandY), W, H + sandTileH, 1)
        -- Nisip ud langa apa: capatul dinspre rau e mai inchis. E umbra malului, si ea face
        -- diferenta dintre "o fasie galbena" si "o plaja".
        local wet = Instance.new("UIGradient")
        wet.Rotation = 90
        local dry, soaked = Color3.new(1, 1, 1), Color3.fromRGB(132, 136, 150)
        wet.Color = if fromTop
            then ColorSequence.new(dry, soaked)
            else ColorSequence.new(soaked, dry)
        -- ...si se stinge spre iarba. Fara asta plaja are o muchie taiata cu foarfeca acolo unde
        -- se termina nisipul, si tocmai muchiile drepte incercam sa le scoatem din harta.
        local fade = {
            NumberSequenceKeypoint.new(0, if fromTop then 0.95 else 0),
            NumberSequenceKeypoint.new(0.45, 0),
            NumberSequenceKeypoint.new(0.55, 0),
            NumberSequenceKeypoint.new(1, if fromTop then 0 else 0.95),
        }
        wet.Transparency = NumberSequence.new(fade)
        wet.Parent = sand
    end

    if not baked then
        for _, c in Shoreline.columns(FAR, W, STEP) do
            bankColumn(c, true)
        end
        for _, c in Shoreline.columns(NEAR, W, STEP) do
            bankColumn(c, false)
        end
    end

    -- Pietrele de pe plaja. `pebbles` le imprastie in jurul liniei; le impingem toate pe uscat,
    -- ca sa nu pluteasca niciuna in mijlocul apei.
    local STONE_TONES = {
        Color3.fromRGB(152, 145, 132),
        Color3.fromRGB(118, 110, 98),
        Color3.fromRGB(172, 160, 142),
    }
    local function scatterStones(e: Shoreline.Edge, side: number)
        for _, p in Shoreline.pebbles(e, W, 70, 16) do
            local base = Shoreline.edgeY(e, p.x)
            local y = base + side * (5 + math.abs(p.y - base))
            local f = frame(
                trimLayer,
                p.x,
                math.round(y),
                p.r * 2,
                math.max(3, p.r),
                STONE_TONES[p.tone],
                1
            )
            rounded(f, p.r)
        end
    end
    if not baked then
        scatterStones(FAR, -1)
        scatterStones(NEAR, 1)
    end

    -- Spuma: pete albe pe linia apei, tinute intr-un singur cadru care se leagana. Un cadru care
    -- se misca inseamna doua scrieri pe redare, nu 200 -- si arata ca apa care linge malul.
    -- Rare si inegale: un sir continuu de liniute albe arata ca o bordura punctata, nu ca apa.
    local function scatterFoam(e: Shoreline.Edge, side: number): Frame
        local holder = Instance.new("Frame")
        holder.Name = "Foam"
        holder.BackgroundTransparency = 1
        holder.Size = UDim2.fromOffset(W, H)
        holder.ZIndex = 2
        holder.Parent = trimLayer
        for _, p in Shoreline.pebbles(e, W, 64, 7, 991) do
            -- doar jumatate dintre ele sunt spuma vizibila; restul raman gauri in sir
            if p.r % 2 == 0 then
                continue
            end
            local h = math.max(3, p.r - 1)
            local f = frame(
                holder,
                p.x,
                p.y - side * 4,
                p.r * (4 + p.tone * 2),
                h,
                Color3.fromRGB(238, 249, 255),
                1
            )
            rounded(f, math.floor(h / 2))
            f.BackgroundTransparency = 0.3 + (p.r % 3) * 0.18
        end
        return holder
    end
    local farFoam = scatterFoam(FAR, -1)
    local nearFoam = scatterFoam(NEAR, 1)

    if not baked then
        -- Padurea de dincolo. Inchide harta fara zid si spune, dintr-o privire, ca acolo nu se
        -- ajunge. NU e un dreptunghi verde inchis (asa era prima incercare, si arata exact ca un
        -- dreptunghi): e o masa compacta sus, si sub ea coroane rotunde care fac silueta zdrentuita.
        local forest = frame(trimLayer, 0, 0, W, 150, Color3.fromRGB(36, 62, 44), 3)
        local forestGradient = Instance.new("UIGradient")
        forestGradient.Rotation = 90
        forestGradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.7, 0.3),
            NumberSequenceKeypoint.new(1, 0.8),
        })
        forestGradient.Parent = forest

        local CROWNS = {
            Color3.fromRGB(34, 60, 40),
            Color3.fromRGB(46, 78, 48),
            Color3.fromRGB(26, 48, 34),
        }
        local treeLine: Shoreline.Edge = { seed = FOREST_SEED, baseY = 312, amp = 96, side = -1 }
        local rng = Prng.new(FOREST_SEED)
        local cx = -40
        while cx < W + 40 do
            local base = Shoreline.edgeY(treeLine, math.max(0, cx))
            -- patru randuri, pana sus: silueta de jos e cea care conteaza, dar daca deasupra ei
            -- ramane un dreptunghi plat, tot a dreptunghi arata. Randurile de sus dau textura masei.
            for row = 0, 3 do
                local size = 54 + Prng.nextInteger(rng, 0, 66) - row * 6
                local cy = base - row * 58 - Prng.nextInteger(rng, 0, 26)
                local crown = frame(
                    trimLayer,
                    math.round(cx - size / 2),
                    math.round(cy - size / 2),
                    size,
                    math.round(size * 0.86),
                    CROWNS[Prng.nextInteger(rng, 1, #CROWNS)],
                    8 - row
                )
                rounded(crown, math.floor(size / 2))
            end
            cx += 22 + Prng.nextInteger(rng, 0, 12)
        end
    end

    -- [D70, pasul k1] LUMEA BARAJULUI, provizoriu (pana la pamantul ei copt, k12): lacul linistit din spatele zidului, zidul
    -- de piatra, apa alba a deversorului pe fata lui si canalul care taie cartierul. Spuma de la piciorul zidului sta peste
    -- plutitorii care ies de acolo (stratul Plot), ca marfa sa para ca vine de sub apa alba.
    local spill: Frame? = nil
    local data = TycoonConfig.WORLDS[worldId]
    if data ~= nil and data.wall ~= nil then
        -- [verificatorul k1] lacul tine toata apa din spatele zidului, de sus pana jos: coloanele de mal (stratul Shore) il
        -- taie dupa malul adevarat, ca pe rau; dedesubt, o apa care nu curge (lacul sta, raul curge abia de la deversor)
        local lakeW = data.wall.x
        local calm = tiled(waterLayer, Assets.water_tile, 0, waterTop, lakeW, waterH, 3)
        calm.Name = "LakeWater"
        local still = frame(waterLayer, 0, waterTop, lakeW, waterH, Color3.fromRGB(40, 88, 120), 4)
        still.Name = "Lake"
        still.BackgroundTransparency = 0.55
        local wall = data.wall
        local stone =
            frame(builtLayer, wall.x, wall.y, wall.w, wall.h, Color3.fromRGB(128, 124, 116), 8)
        stone.Name = "DamWall"
        if Assets.has(Assets.tile_plaza) then
            local face = tiled(builtLayer, Assets.tile_plaza, wall.x, wall.y, wall.w, wall.h, 9)
            face.ImageColor3 = Color3.fromRGB(170, 164, 152)
        end
        local cap = frame(
            builtLayer,
            wall.x - 6,
            wall.y - 10,
            wall.w + 12,
            18,
            Color3.fromRGB(92, 88, 82),
            10
        )
        cap.Name = "DamCap"
        local sp = data.water.spillway
        local white = frame(builtLayer, sp.x, sp.y, sp.w, sp.h, Color3.fromRGB(226, 240, 248), 11)
        white.Name = "Spillway"
        gradient(white, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 196, 220))
        spill = white
        local canal = data.water.canal
        tiled(trimLayer, Assets.water_tile, canal.x, canal.y, canal.w, canal.h, 4).Name = "Canal"
        local deep =
            frame(trimLayer, canal.x, canal.y, canal.w, canal.h, Color3.fromRGB(8, 34, 62), 5)
        deep.BackgroundTransparency = 0.6
        local plot = layers.Plot
        if plot ~= nil then
            local foot = frame(
                plot,
                wall.x + wall.w - 10,
                river.RIVER_TOP,
                64,
                river.RIVER_BOTTOM - river.RIVER_TOP,
                Color3.fromRGB(238, 249, 255),
                8
            )
            foot.Name = "SpillFoam"
            foot.BackgroundTransparency = 0.25
            local fade = Instance.new("UIGradient")
            fade.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(1, 1),
            })
            fade.Parent = foot
        end
    end

    -- [D70, pasul k1] o singura legatura pe desen, desfacuta cand desenul iese din lume (macheta balciului se face din
    -- nou la fiecare vizita: fara asta, fiecare vizita lasa o legatura in plus)
    local t = 0
    local connection: RBXScriptConnection
    connection = RunService.PreRender:Connect(function(dt: number)
        if water.Parent == nil then
            connection:Disconnect()
            return
        end
        t += dt
        local spilling = spill
        if spilling ~= nil then
            spilling.BackgroundTransparency = 0.1 + math.abs(math.sin(t * 2.3)) * 0.15
        end
        water.Position = UDim2.fromOffset(-tileW + ((t * 46) % tileW), waterTop)
        shimmer.Position = UDim2.fromOffset(-tileW + ((t * 22) % tileW), waterTop)
        -- spuma nu curge cu raul: se duce si se intoarce, ca valul mic de la mal
        farFoam.Position = UDim2.fromOffset(math.sin(t * 0.9) * 7, math.cos(t * 0.7) * 2)
        nearFoam.Position =
            UDim2.fromOffset(math.sin(t * 0.8 + 1.7) * 7, math.cos(t * 0.62 + 0.4) * 2)
    end)

    if baked then
        -- deasupra apei (stratul Water), sub spuma care se leagana (stratul Trim). [D65] PE FELII de 2880 px de lume
        -- (RiverConfig.ERA1_WORLD_WIDTH): prima e imaginea de dinainte de Moara, a doua acopera fasia noua. O felie
        -- inca neurcata isi primeste iarba din dale, ca fasia ei sa nu ramana goala.
        local sliceW = RiverConfig.BAKE_SLICE
        for k, sprite in { Assets.tycoon.village_ground, Assets.tycoon.village_ground_2 } do
            local x0 = (k - 1) * sliceW
            local w = math.min(sliceW, W - x0)
            if w <= 0 then
                break
            end
            -- [D67] cat din felie acopera imaginea URCATA (latimea ei nativa x 3): cand lumea creste, felia urcata
            -- ramane pe bucata ei, iar restul feliei isi primeste iarba din dale pana la coacerea noua, nu se intinde
            local covered = if Assets.has(sprite)
                then math.min(w, sprite.width * Assets.PIXEL_SCALE)
                else 0
            if covered > 0 then
                local ground = image(shoreLayer, sprite, x0, 0, covered, H, 1)
                ground.Name = "BakedGround" .. k
            end
            if covered < w then
                local gx, gw = x0 + covered, w - covered
                tiled(groundLayer, Assets.grass_tile, gx, 0, gw, waterTop, 0)
                tiled(groundLayer, Assets.grass_tile, gx, waterBottom, gw, H - waterBottom, 0)
            end
        end
    end

    -- [F3] Malul construit DIN DALE: pontonul (scandurile de-a lungul apei, unde stau stalpii plaselor), curtile si
    -- drumurile batatorite pe care merg oamenii [D50, D57]. [D65] Pe cartiere (TycoonConfig.DISTRICTS): fara imagine
    -- coapta, toate cartierele din joc; cu ea, doar cele pe care imaginea URCATA inca nu le contine
    -- (TycoonConfig.BAKED_DISTRICTS) -- altfel Moara ar sta pe iarba goala pana la urcarea coacerii noi.
    do
        local function groundStrip(
            sprite: Assets.Sprite,
            r: { x0: number, x1: number, y0: number, y1: number },
            z: number,
            ragged: boolean,
            shadow: boolean?
        )
            local w, h = r.x1 - r.x0, r.y1 - r.y0
            -- Umbra dedesubt doar pentru scandurile puntii: ele chiar stau PESTE mal. [D57] Un drum de pamant e calcat IN
            -- iarba; cu umbra, drumurile pareau fasii de carton puse pe harta (owner: "parca plutesc mereu").
            if shadow == true then
                local sh = frame(
                    builtLayer,
                    r.x0 - 2,
                    r.y0 + 7,
                    w + 6,
                    h + 2,
                    Color3.fromRGB(26, 32, 24),
                    z
                )
                sh.BackgroundTransparency = 0.7
                rounded(sh, 6)
            end
            local function tile(x: number, y: number, tw: number, th: number, zz: number)
                if Assets.has(sprite) then
                    local img = tiled(builtLayer, sprite, x, y, tw, th, zz)
                    img.ClipsDescendants = true
                    if ragged then
                        -- poteca batatorita: pamant, nu caramida. Fara tinta iese prea rosie langa
                        -- iarba si trage ochiul mai tare decat pontonul, care e piesa importanta.
                        img.ImageColor3 = Color3.fromRGB(214, 205, 186)
                    end
                    return
                end
                -- fara arta inca: o fasie de lemn plata tine locul, ca nicio statie sa nu ramana pe
                -- iarba goala pana apare sprite-ul [item 6]
                local fallback = frame(builtLayer, x, y, tw, th, Color3.fromRGB(150, 115, 78), zz)
                fallback.BackgroundTransparency = 0.15
            end
            if not ragged then
                tile(r.x0, r.y0, w, h, z + 1)
                return
            end
            -- Poteca nu e un dreptunghi trasat cu rigla: e batatorita, deci latimea ei variaza si
            -- marginile se rup. Bucati de 64px, fiecare putin altfel -- tot un tile, alta silueta. [D57] Pe aleile
            -- verticale bucatile merg de sus in jos, ca marginile rupte sa fie cele lungi.
            local seg = 64
            local i = 0
            if w >= h then
                local x = r.x0
                while x < r.x1 do
                    local segW = math.min(seg, r.x1 - x)
                    local wobble = math.floor(math.sin(i * 1.7) * 5 + math.sin(i * 0.6) * 4)
                    tile(x, r.y0 - wobble, segW + 1, h + wobble * 2, z + 1)
                    x += seg
                    i += 1
                end
            else
                local y = r.y0
                while y < r.y1 do
                    local segH = math.min(seg, r.y1 - y)
                    local wobble = math.floor(math.sin(i * 1.7) * 4 + math.sin(i * 0.6) * 3)
                    tile(r.x0 - wobble, y, w + wobble * 2, segH + 1, z + 1)
                    y += seg
                    i += 1
                end
            end
        end

        -- [D57] Iarba peste marginile pamantului (drumuri si curti): smocuri pe muchii, jumatate pe iarba, jumatate pe
        -- pamant, ca linia dintre ele sa nu mai fie trasa cu rigla. Fara arta urcata, marginile raman drepte.
        local EDGE = 12 -- jumatate din inaltimea fasiei (8 px de arta x3)
        local function grassEdges(r: { x0: number, x1: number, y0: number, y1: number }, z: number)
            if r.x1 - r.x0 >= r.y1 - r.y0 then
                if Assets.has(Assets.grass_edge_h) then
                    for _, y in { r.y0, r.y1 } do
                        tiled(
                            builtLayer,
                            Assets.grass_edge_h,
                            r.x0,
                            y - EDGE,
                            r.x1 - r.x0,
                            EDGE * 2,
                            z
                        )
                    end
                end
            elseif Assets.has(Assets.grass_edge_v) then
                for _, x in { r.x0, r.x1 } do
                    tiled(builtLayer, Assets.grass_edge_v, x - EDGE, r.y0, EDGE * 2, r.y1 - r.y0, z)
                end
            end
        end

        for _, district in TycoonConfig.districtsOf(worldId) do
            local inImage = baked and TycoonConfig.BAKED_DISTRICTS[district.id] == true
            if inImage or not TycoonConfig.eraIsLive(district.era) then
                continue
            end
            groundStrip(Assets.tycoon.deck_tile, district.deck, 1, false, true)

            -- [D57] PAMANTUL BATATORIT de sub cladiri si din jurul pietei (curtile cartierului): aceeasi dala ca drumul,
            -- mai deschisa, cu colturi rotunjite si iarba peste margini. Sub drumuri, ca aleile sa treaca peste curti.
            for _, yard in district.yards do
                local w, h = yard.x1 - yard.x0, yard.y1 - yard.y0
                if Assets.has(Assets.path_tile) then
                    local img = tiled(builtLayer, Assets.path_tile, yard.x0, yard.y0, w, h, 2)
                    img.Name = `Yard_{yard.id}`
                    img.ImageColor3 = Color3.fromRGB(228, 216, 192)
                    rounded(img, 14)
                end
                grassEdges({ x0 = yard.x0 + 8, x1 = yard.x1 - 8, y0 = yard.y0, y1 = yard.y1 }, 3)
            end

            -- bucla [D50], satul [D57]: aceleasi dreptunghiuri din care RoadGraph face drumurile oamenilor si dara de
            -- ghidaj, deci ce e desenat ca drum e exact pe unde merge lumea. Piata vanzatorului e de piatra, peste
            -- aleea ei (`like`: drumul-pereche din Era 1, dupa care se alege desenul).
            for _, road in district.roads do
                if (road.like or road.id) == "plaza" and Assets.has(Assets.tile_plaza) then
                    groundStrip(Assets.tile_plaza, road, 5, false)
                else
                    groundStrip(Assets.path_tile, road, 3, true)
                    grassEdges(road, 5)
                end
            end
        end
    end

    -- [D57] DECORUL ASEZAT DE MANA pe teren: fiecare lucru spune ceva despre locul lui (TycoonConfig.DECOR). Sub
    -- cladiri si oameni (stratul lor e deasupra), ordonat pe adancime intre el.
    for _, item in TycoonConfig.decorOf(worldId) do
        local sprite = decorSprite(item.sprite)
        if sprite ~= nil then
            local img = image(
                builtLayer,
                sprite,
                0,
                0,
                sprite.width * item.scale,
                sprite.height * item.scale,
                7
            )
            img.Name = `Decor_{item.sprite}`
            img.AnchorPoint = Vector2.new(0.5, 1)
            img.Position = UDim2.fromOffset(item.x, item.y)
            img.ZIndex = 7 + math.clamp(math.floor(item.y / 64), 0, 40)
        end
    end

    buildDecor(scroll, worldId)
end

-- Personajul jucatorului foloseste aceeasi foaie ca si colonistii; setter-ul isi tine singur
-- ceasul de animatie, ca sa nu duplicam logica in CharacterController.
-- [D59] `activity`: ce face personajul pe loc ("fishing" = randul cu undita); nil = mers/stat, ca pana acum.
export type Pose = (
    moving: boolean,
    facing: string,
    dt: number,
    running: boolean,
    activity: string?
) -> ()
-- [D59] Tinuta jucatorului (cheia din Assets.people.outfit), schimbata de la avizierul satului.
export type SetOutfit = (outfit: string) -> ()
-- [D61] Infatisarea jucatorului (silueta, coafura, pielea, culoarea parului), aleasa la croitoreasa din balci:
-- aceleasi straturi si palete ca la oamenii din sat (LookMath, SettlerConfig). Primeste indicii din profil.
export type SetLook = (look: LookMath.Look) -> ()

function SceneArt.MakeCharacter(parent: Instance): (GuiObject, Pose, SetOutfit, SetLook)
    local c = RiverConfig.CHARACTER
    if Assets.has(Assets.character_anim) then
        local img = image(parent, Assets.character_anim, 0, 0, c.WIDTH, c.HEIGHT, 6)
        img.AnchorPoint = Vector2.new(0.5, 1)

        -- Straturile jucatorului [D44]. Corpul se deseneaza pe o rampa neutra si primeste nuanta
        -- prin tint, la fel ca la angajati; tinuta e `keeper`, pe care NICIUN angajat nu o
        -- primeste -- de aici se vede cine e jucatorul.
        -- Cat timp foile nu sunt incarcate, ramane foaia dintr-o bucata, netonata, ca acum.
        local playerLayered = Assets.has(Assets.people.body.a)
            and Assets.has(Assets.people.outfit.keeper)
        local extra: { ImageLabel } = {}
        local outfitLayer: ImageLabel? = nil
        local hairLayer: ImageLabel? = nil
        if playerLayered then
            img.Image = Assets.url(Assets.people.body.b)
            img.ImageColor3 = Color3.fromRGB(231, 188, 150)
            for i, sheet in { Assets.people.hair.long, Assets.people.outfit.keeper } do
                local l = Instance.new("ImageLabel")
                l.Name = if i == 1 then "Hair" else "Outfit"
                l.BackgroundTransparency = 1
                l.Image = Assets.url(sheet)
                l.ResampleMode = Enum.ResamplerMode.Pixelated
                l.Size = UDim2.fromScale(1, 1)
                l.ZIndex = 6 + i
                if i == 1 then
                    l.ImageColor3 = Color3.fromRGB(92, 62, 40)
                end
                l.Parent = img
                table.insert(extra, l)
                if i == 2 then
                    outfitLayer = l
                else
                    hairLayer = l
                end
            end
        end
        -- [D61] Pana aici omul are chipul de dinainte (LookMath.DEFAULT); `setLook` il schimba cu cel din profil.
        -- O foaie de par neurcata ("bald" n-are foaie) ascunde stratul, ca la oamenii din sat (UI/PersonView).
        local function setLook(look: LookMath.Look)
            if not playerLayered then
                return
            end
            local r = LookMath.resolve(look)
            local bodySheet = (Assets.people.body :: any)[r.body]
            if bodySheet ~= nil and Assets.has(bodySheet) then
                img.Image = Assets.url(bodySheet)
            end
            img.ImageColor3 = Color3.fromRGB(r.skin[1], r.skin[2], r.skin[3])
            local hair = hairLayer
            if hair ~= nil then
                local hairSheet = (Assets.people.hair :: any)[r.hair]
                if hairSheet ~= nil and Assets.has(hairSheet) then
                    hair.Image = Assets.url(hairSheet)
                    hair.ImageTransparency = 0
                else
                    hair.ImageTransparency = 1
                end
                hair.ImageColor3 = Color3.fromRGB(r.hairColor[1], r.hairColor[2], r.hairColor[3])
            end
        end
        local function setOutfit(outfit: string)
            local layer = outfitLayer
            local sheet = (Assets.people.outfit :: any)[outfit]
            if layer == nil or sheet == nil or not Assets.has(sheet) then
                return -- tinuta inca neurcata: ramane cea de acum
            end
            local url = Assets.url(sheet)
            if layer.Image ~= url then
                layer.Image = url
            end
        end
        -- Fara inel sub picioare: l-a scos owner-ul (2026-09-11). Pe mal nu mai sunt colonisti
        -- de care sa te deosebesti, iar tinuta `keeper` ramane doar a jucatorului.
        if Assets.has(Assets.shadow) then
            local sh =
                image(img, Assets.shadow, 0, 0, 16 * Assets.PIXEL_SCALE, 6 * Assets.PIXEL_SCALE, 5)
            sh.AnchorPoint = Vector2.new(0.5, 0.5)
            sh.Position = UDim2.new(0.5, 0, 1, -4)
        end
        local w, h = AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT
        img.ImageRectSize = Vector2.new(w, h)
        local animTime = 0
        local currentRow = ""
        local dustClock = 0
        return img,
            function(
                moving: boolean,
                facing: string,
                dt: number,
                running: boolean,
                activity: string?
            )
                -- Alergarea are acum randuri DESENATE (pas lung, ambele picioare in aer, brate
                -- care leagana). Inainte era doar ciclul de mers invartit mai repede.
                -- [D59] Pe loc, cu o treaba (undita): randul ei, spre partea in care se uita.
                local row = if moving and running
                    then AnimConfig.runRow(facing)
                    elseif not moving and activity ~= nil then AnimConfig.rowFor(
                        activity,
                        facing,
                        false,
                        nil,
                        nil
                    )
                    else AnimConfig.rowFor("idle", facing, moving, nil, nil)
                if row.id ~= currentRow then
                    currentRow = row.id
                    animTime = 0
                else
                    animTime += dt * row.fps
                end
                -- Praf sub picioare: detaliul care face diferenta dintre "sprite care aluneca"
                -- si "cineva care calca pe pamant". Mai des cand alergi.
                if moving then
                    dustClock += dt
                    local every = if running then 0.11 else 0.2
                    if dustClock >= every then
                        dustClock = 0
                        local side = if math.random() < 0.5 then -6 else 6
                        SceneArt.FootDust(img, c.WIDTH / 2 + side, c.HEIGHT - 2, side, running)
                    end
                else
                    dustClock = 0
                end
                local index = math.floor(animTime) % AnimConfig.FRAMES_PER_ROW
                local mirror = row.side and facing == "left"
                local offset = if mirror
                    then Vector2.new(w * index + w, h * row.index)
                    else Vector2.new(w * index, h * row.index)
                local size = if mirror then Vector2.new(-w, h) else Vector2.new(w, h)
                img.ImageRectOffset = offset
                img.ImageRectSize = size
                -- straturile trebuie sa arate ACELASI cadru, altfel palaria ramane in urma capului
                for _, l in extra do
                    l.ImageRectOffset = offset
                    l.ImageRectSize = size
                end
            end,
            setOutfit,
            setLook
    end
    local body = frame(parent, 0, 0, c.WIDTH, c.HEIGHT, Color3.fromRGB(63, 127, 191), 6)
    body.AnchorPoint = Vector2.new(0.5, 1)
    rounded(body, 6)
    local head = frame(body, 8, 4, c.WIDTH - 16, 24, Color3.fromRGB(241, 200, 160), 7)
    rounded(head, 8)
    local bobT = 0
    return body,
        function(moving: boolean, _facing: string, dt: number)
            bobT = if moving then bobT + dt * 8 else 0
            head.Position = UDim2.fromOffset(8, if math.floor(bobT) % 2 == 1 then 6 else 4)
        end,
        function(_outfit: string) end,
        function(_look: LookMath.Look) end
end

-- Particule (fum de cos, flacara, praf de santier). Toate sunt actualizate de o singura bucla:
-- o conexiune PreRender per cladire ar costa mult mai mult decat o lista parcursa o data.
type Particle = {
    f: Frame,
    host: GuiObject,
    t: number,
    dur: number,
    x: number,
    y: number,
    size: number,
    rise: number,
    sway: number,
    fade: number,
    once: boolean, -- true: joaca o singura data si dispare (praful de pasi); false: bucla (fum, flacara)
}

local particles: { Particle } = {}
local particleLoop: RBXScriptConnection? = nil

local function stepParticles(dt: number)
    for i = #particles, 1, -1 do
        local p = particles[i]
        if p.host.Parent == nil then
            p.f:Destroy()
            table.remove(particles, i)
            continue
        end
        if not p.host.Visible then
            continue
        end
        p.t += dt
        if p.once and p.t >= p.dur then
            p.f:Destroy()
            table.remove(particles, i)
            continue
        end
        local k = if p.once then p.t / p.dur else (p.t % p.dur) / p.dur
        local size = math.round(p.size * (0.55 + k * 1.05))
        p.f.Position = UDim2.fromOffset(
            math.round(p.x + math.sin((p.t + p.x) * 1.8) * p.sway),
            math.round(p.y - k * p.rise)
        )
        p.f.Size = UDim2.fromOffset(size, size)
        -- apare repede si se stinge lin: fara asta, particula ar sari brusc inapoi la opac
        local alpha = math.min(1, k * 6) * (1 - k)
        p.f.BackgroundTransparency = math.clamp(1 - alpha * (1 - p.fade), 0, 1)
    end
end

local function addParticle(
    host: GuiObject,
    color: Color3,
    x: number,
    y: number,
    size: number,
    rise: number,
    dur: number,
    phase: number,
    sway: number,
    fade: number,
    once: boolean?,
    zIndex: number?
)
    local f = Instance.new("Frame")
    f.Name = "Particle"
    f.AnchorPoint = Vector2.new(0.5, 1)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.Size = UDim2.fromOffset(size, size)
    f.ZIndex = zIndex or host.ZIndex + 2
    rounded(f, math.max(2, math.floor(size / 3)))
    f.Parent = host
    table.insert(particles, {
        f = f,
        host = host,
        t = phase * dur,
        dur = dur,
        x = x,
        y = y,
        size = size,
        rise = rise,
        sway = sway,
        fade = fade,
        once = once == true,
    })
    if particleLoop == nil then
        particleLoop = RunService.PreRender:Connect(stepParticles)
    end
end

-- Fum care iese dintr-un cos, pozitionat in fractiuni din cadrul cladirii
function SceneArt.AddSmoke(host: GuiObject, fx: number, fy: number)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    local x, y = math.round(w * fx), math.round(h * fy)
    for i = 1, 3 do
        addParticle(
            host,
            Color3.fromRGB(214, 214, 208),
            x,
            y,
            math.round(w * 0.13),
            h * 0.85,
            2.6,
            (i - 1) / 3,
            5,
            0.35
        )
    end
end

-- Flacara care palpaie plus scantei; pentru vatra si pentru forja
function SceneArt.AddFire(host: GuiObject, fx: number, fy: number)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    local x, y = math.round(w * fx), math.round(h * fy)
    addParticle(
        host,
        Color3.fromRGB(255, 176, 74),
        x,
        y,
        math.round(w * 0.3),
        h * 0.12,
        0.42,
        0,
        1,
        0.55
    )
    addParticle(
        host,
        Color3.fromRGB(255, 226, 150),
        x,
        y,
        math.round(w * 0.18),
        h * 0.08,
        0.31,
        0.5,
        1,
        0.4
    )
    for i = 1, 2 do
        addParticle(
            host,
            Color3.fromRGB(255, 208, 120),
            x,
            y,
            math.max(3, math.round(w * 0.07)),
            h * 0.9,
            1.5,
            (i - 1) / 2,
            7,
            0.2
        )
    end
end

-- Stropi la prindere: cateva particule deschise care sar si se sting repede [F1 spec 4.2, D2].
-- `fx, fy` sunt fractiuni din cadrul lui `host` (0.5, 0.5 = centru), la fel ca AddSmoke/AddFire.
function SceneArt.Splash(host: GuiObject, fx: number, fy: number)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    local x, y = math.round(w * fx), math.round(h * fy)
    for i = 1, 4 do
        addParticle(
            host,
            Color3.fromRGB(224, 240, 250),
            x,
            y,
            math.max(3, math.round(w * 0.09)),
            h * 0.5,
            0.45,
            (i - 1) / 4,
            8,
            0.25,
            true
        )
    end
end

-- Praf de santier: puffuri joase si maronii cat timp se lucreaza
-- Praf sub picioare. Sta AICI, dupa addParticle, si se cheama prin tabelul modulului din
-- MakeCharacter: campul se cauta la apel, deci ordinea functiilor din fisier nu mai conteaza.
-- Praful de pasi se naste in LUME, la picioare, si ramane acolo cat se stinge -- in urma celui
-- care merge. Inainte era copilul personajului si se repeta la nesfarsit: mergea odata cu el si
-- fiecare pas mai adauga un puf care nu disparea niciodata (vazut de owner, 2026-09-11).
-- `host` e personajul (AnchorPoint 0.5,1, pozitionat la picioare); x/y sunt in coordonatele lui.
function SceneArt.FootDust(host: GuiObject, x: number, y: number, side: number, running: boolean)
    local world = host.Parent
    if world == nil or not world:IsA("GuiObject") then
        return
    end
    -- din coordonatele personajului (colt stanga-sus) in coordonatele lumii, prin ancora lui
    local wx = host.Position.X.Offset - host.Size.X.Offset * host.AnchorPoint.X + x
    local wy = host.Position.Y.Offset - host.Size.Y.Offset * host.AnchorPoint.Y + y
    addParticle(
        world :: GuiObject,
        Color3.fromRGB(206, 190, 158),
        wx,
        wy,
        if running then 7 else 5,
        if running then 14 else 9,
        if running then 0.5 else 0.42,
        0,
        side * 0.6,
        0.35,
        true,
        host.ZIndex - 1
    )
end

-- Ce se vede deasupra cuiva care MUNCESTE, dupa felul postului. Pana acum toate meseriile
-- foloseau acelasi rand de animatie ("work"), deci un gradinar, un mestesugar si un hangiu
-- aratau identic -- de aici intrebarea "nu inteleg ce face gradinarul". Particulele nu cer
-- sprite-uri noi si spun ce se intampla acolo dintr-o privire.
local WORK_FX: { [string]: { rgb: Color3, size: number, rise: number, sway: number } } = {
    farm = { rgb = Color3.fromRGB(122, 176, 96), size = 5, rise = 13, sway = 7 }, -- frunze
    work = { rgb = Color3.fromRGB(240, 176, 84), size = 3, rise = 9, sway = 3 }, -- scantei
    site = { rgb = Color3.fromRGB(198, 184, 152), size = 5, rise = 10, sway = 4 }, -- praf
    joy = { rgb = Color3.fromRGB(236, 196, 120), size = 4, rise = 15, sway = 9 }, -- caldura
}

function SceneArt.WorkSpark(host: GuiObject, kind: string, w: number, h: number)
    local fx = WORK_FX[kind]
    if fx == nil then
        return
    end
    local side = (math.random() - 0.5) * w * 0.7
    addParticle(host, fx.rgb, w / 2 + side, h * 0.45, fx.size, fx.rise, 0.75, 0, fx.sway, 0.4)
end

function SceneArt.AddDust(host: GuiObject)
    local w, h = host.Size.X.Offset, host.Size.Y.Offset
    for i = 1, 2 do
        addParticle(
            host,
            Color3.fromRGB(198, 178, 143),
            math.round(w * (0.3 + i * 0.22)),
            math.round(h * 0.95),
            math.round(w * 0.12),
            h * 0.3,
            1.9,
            (i - 1) / 2,
            4,
            0.5
        )
    end
end

-- Sarbatoare la terminarea unei cladiri: un salt scurt si un inel care se stinge.
-- `art` trebuie ancorat in centru: UIScale scaleaza si obiectul pe care e pus, nu doar copiii,
-- deci pe un obiect ancorat in coltul stanga-sus cladirea ar sari in diagonala [DECIZII D06].
function SceneArt.Flourish(art: GuiObject, host: GuiObject)
    local scale = art:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
    scale.Scale = 1.18
    scale.Parent = art
    local pop = TweenService:Create(
        scale,
        TweenInfo.new(0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Scale = 1 }
    )
    pop:Play()

    local ring = Instance.new("Frame")
    ring.Name = "Flourish"
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromScale(0.5, 0.7)
    ring.Size = UDim2.fromScale(0.3, 0.2)
    ring.BackgroundTransparency = 1
    ring.ZIndex = host.ZIndex + 3
    rounded(ring, 999)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.fromRGB(255, 232, 150)
    stroke.Parent = ring
    ring.Parent = host
    local grow = TweenService:Create(
        ring,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromScale(1.5, 1.1) }
    )
    grow:Play()
    local dim = TweenService:Create(
        stroke,
        TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Transparency = 1 }
    )
    dim:Play()
    task.delay(0.9, function()
        ring:Destroy()
    end)
end

-- Lada din scanduri; culoarea de accent vine de la tier
function SceneArt.StyleCrate(f: Frame, accent: Color3, tier: string?)
    for _, child in f:GetChildren() do
        child:Destroy()
    end
    local sprite = if tier then (Assets.crate :: any)[tier] else nil
    if sprite ~= nil and Assets.has(sprite) then
        f.BackgroundTransparency = 1
        local img = image(f, sprite, 0, 0, f.Size.X.Offset, f.Size.Y.Offset, f.ZIndex)
        img.Size = UDim2.fromScale(1, 1)
        return
    end
    f.BackgroundTransparency = 0
    f.BackgroundColor3 = Color3.fromRGB(150, 105, 60)
    rounded(f, 5)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(Color3.fromRGB(190, 140, 85), Color3.fromRGB(120, 80, 45))
    g.Rotation = 90
    g.Parent = f
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 3
    stroke.Color = accent
    stroke.Parent = f
    for i = 1, 2 do
        local plank = frame(
            f,
            0,
            math.floor(f.Size.Y.Offset * i / 3),
            f.Size.X.Offset,
            2,
            Color3.fromRGB(95, 60, 35),
            f.ZIndex + 1
        )
        plank.BackgroundTransparency = 0.2
    end
    local band =
        frame(f, math.floor(f.Size.X.Offset / 2) - 4, 0, 8, f.Size.Y.Offset, accent, f.ZIndex + 1)
    band.BackgroundTransparency = 0.35
end

-- Plasa: cadru de lemn cu ochiuri din linii
function SceneArt.StyleNet(f: Frame)
    if Assets.has(Assets.net) then
        f.BackgroundTransparency = 1
        local img = image(f, Assets.net, 0, 0, 0, 0, f.ZIndex)
        img.Size = UDim2.fromScale(1, 1)
        return
    end
    f.BackgroundColor3 = Color3.fromRGB(235, 220, 170)
    f.BackgroundTransparency = 0.55
    rounded(f, 8)
    local stroke = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    stroke.Thickness = 4
    stroke.Color = Color3.fromRGB(120, 85, 45)
    stroke.Parent = f
    local w, h = f.Size.X.Offset, f.Size.Y.Offset
    for i = 1, 5 do
        frame(f, math.floor(w * i / 6), 0, 2, h, Color3.fromRGB(250, 240, 200), f.ZIndex).BackgroundTransparency =
            0.3
    end
    for i = 1, 2 do
        frame(f, 0, math.floor(h * i / 3), w, 2, Color3.fromRGB(250, 240, 200), f.ZIndex).BackgroundTransparency =
            0.3
    end
end

return SceneArt
