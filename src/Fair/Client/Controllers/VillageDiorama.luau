--!strict
-- [D61, partea 2] SATUL VIZITAT, desenat in balci din FOTOGRAFIA lui (VillageLook.Snapshot, de la VisitService).
--
-- Sta in acelasi strat cu balciul, departe in dreapta hartii lui (ORIGIN): camera trece pe dreptunghiul lui
-- (CameraController.SetWorld), omul tau e mutat acolo si se plimba liber. Totul e desen: nicio platforma nu se
-- cumpara, nicio plasa nu se goleste, nimeni nu are remote aici -- deci n-are ce porti sa uite.
--
-- Ce se vede: pamantul, raul si drumurile satului (SceneArt.BuildBackground, acelasi ca acasa), pontonul, taverna,
-- depozitul, gaterul, fiecare platforma a Erei 1 (cumparata = cladirea ei, cu coliba mica sau mare; necumparata = ruina),
-- plasele din apa cu insigna nivelului, decorul cumparat cu perle, oamenii mergand pe drumurile lor (HandRoutes, din
-- aceleasi argumente ca acasa) si cartea de oaspeti, unde lasi un like.
--
-- Ca acasa, omul tau sta mereu deasupra a tot ce e pe teren (in sat personajul are Z 6 peste Plot-ul de la 5): radacina
-- dioramei are un Z sub al obiectelor balciului, iar in interior ordinea e cea din sat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local HandMath = require(ReplicatedStorage.Shared.Modules.HandMath)
local HandRoutes = require(ReplicatedStorage.Shared.Modules.HandRoutes)
local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)
local VillageLook = require(ReplicatedStorage.Shared.Modules.VillageLook)
local WorldMap = require(ReplicatedStorage.Shared.Modules.WorldMap)

local SceneArt = require(script.Parent.SceneArt)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local PadArt = require(script.Parent.Parent.UI.PadArt)
local StreetLamps = require(script.Parent.Parent.UI.StreetLamps)
local Modern = require(script.Parent.Parent.UI.Modern)
local ModernProps = require(script.Parent.Parent.UI.ModernProps)
local PersonView = require(script.Parent.Parent.UI.PersonView)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local VillageDiorama = {}

-- Departe de balci: pe un ecran foarte lat, camera balciului vede cateva sute de pixeli dincolo de harta lui.
VillageDiorama.ORIGIN = { x = 6000, y = 0 }
VillageDiorama.SIZE = { w = RiverConfig.WORLD_WIDTH, h = RiverConfig.WORLD_HEIGHT }
-- Unde apari: locul de pornire al satului (TycoonConfig.SPAWN), in curtea lemnului.
VillageDiorama.ARRIVE = { x = TycoonConfig.SPAWN.x, y = TycoonConfig.SPAWN.y }
-- Cartea de oaspeti: pe iarba dintre aleea tavernei si curtea gaterului, la doi pasi de unde apari.
VillageDiorama.GUEST_BOOK = { x = 760, y = 1300 }

local ROOT_Z = 50 -- sub obiectele balciului (FairScene.Z.OBJECTS = 100), deci sub omul tau
local LOCKED_TINT = Color3.fromRGB(200, 196, 188) -- ruinele, usor stinse (ca in PadController)
local GUEST_BOOK_SCALE = TycoonConfig.PROP_SCALE

local scroll: Frame? = nil
local root: Frame? = nil
local plot: Frame? = nil
local rects = WorldMap.blockedRects(RiverConfig, nil, TycoonConfig.PIER_WALK)

type Walker = { snap: VillageLook.HandSnap, cycle: HandMath.Cycle, view: PersonView.View }
local walkers: { Walker } = {}

local function image(
    parent: Instance,
    sprite: Assets.Sprite,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(w, h)
    img.ZIndex = z
    img.Parent = parent
    return img
end

-- Un obiect care sta pe pamant: ancorat jos la mijloc, cu umbra lui [D57].
local function standing(
    parent: Instance,
    sprite: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number,
    shadow: number?
): ImageLabel
    if shadow ~= nil then
        GroundShadow.add(parent, UDim2.fromOffset(x, y), w, z - 1, shadow)
    end
    local img = image(parent, sprite, w, h, z)
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.fromOffset(x, y)
    return img
end

-- Numele unei cladiri, peste lume (fontul de pixeli, conturat), ca in sat.
local function worldName(parent: Instance, text: string, x: number, y: number, width: number?)
    local l = Widgets.Label(parent, text, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.Position = UDim2.fromOffset(x, y)
    l.Size = UDim2.fromOffset(width or 160, 18)
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.ZIndex = 8
    Theme.punch(l, 2)
end

-- [D62, pasul 5] Treapta meseriei (1-5), sub numele casei: aceleasi patratele ca in PadController.
local function tierPips(parent: Instance, x: number, y: number, tier: number)
    local PIP, GAP, MAX = 6, 3, 5
    local width = MAX * PIP + (MAX - 1) * GAP
    for i = 1, MAX do
        local pip = Instance.new("Frame")
        pip.Position = UDim2.fromOffset(x - width / 2 + (i - 1) * (PIP + GAP), y)
        pip.Size = UDim2.fromOffset(PIP, PIP)
        pip.BorderSizePixel = 0
        pip.BackgroundColor3 = if i <= tier then Theme.COLOR.gold else Theme.COLOR.woodDark
        pip.BackgroundTransparency = if i <= tier then 0 else 0.45
        pip.ZIndex = 8
        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(24, 18, 12)
        stroke.Thickness = 1
        stroke.Parent = pip
        pip.Parent = parent
    end
end

-- Unde sta numele unei cladiri fixe, ca acasa: "inside" = jos, pe fata ei (depozitul, gaterul: StorageController,
-- SawmillController), "roof" = firma pe acoperis (taverna: DockController), "above" = deasupra acoperisului (cladirile
-- Morii si ale Wire Works: LineController.drawBuilding, cu baza etichetei la 4 px peste acoperis). [2026-09-29] Macheta
-- punea si cladirile Morii dupa regula Erei 1: numele lor cadeau pe usa sau pe acoperis, cu 52-94 px mai jos decat acasa.
type LabelAt = "inside" | "roof" | "above"

-- O cladire prefabricata (taverna, depozitul, gaterul): desenul intins pe cutia ei din TycoonConfig.
local function station(
    parent: Instance,
    sprite: Assets.Sprite?,
    box: { x: number, y: number, w: number, h: number },
    label: string,
    labelAt: LabelAt,
    stage: number? -- [D70] treapta modernizarii gazdei (doar cladirile satului vechi au lumini)
)
    GroundShadow.add(parent, UDim2.fromOffset(box.x, box.y), box.w, 2)
    if sprite ~= nil and Assets.has(sprite) then
        local img = image(parent, sprite, box.w, box.h, 3)
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(box.x, box.y)
        Modern.lights(img, sprite, stage or 0) -- [D70] luminile cladirilor moderne ale gazdei
    else
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 1)
        f.Position = UDim2.fromOffset(box.x, box.y)
        f.Size = UDim2.fromOffset(box.w, box.h)
        f.BackgroundColor3 = Theme.COLOR.wood
        f.BackgroundTransparency = 0.15
        f.BorderSizePixel = 0
        f.ZIndex = 3
        f.Parent = parent
    end
    if labelAt == "above" then
        worldName(parent, label, box.x, box.y - box.h - 4 - 18, math.max(box.w, 120))
    else
        worldName(
            parent,
            label,
            box.x,
            if labelAt == "roof" then box.y - box.h + 30 else box.y - 24,
            box.w - 8
        )
    end
end

-- Plasa cumparata: stalpul pe punte, funia, plasa pe banda ei si insigna nivelului (ca in NetController).
local function drawNet(parent: Instance, pad: TycoonConfig.Pad, level: number)
    local x, y = pad.x :: number, pad.y :: number
    local laneY = TycoonConfig.LANE_Y[PadArt.laneOf(pad)] or TycoonConfig.LANE_Y[1]
    local post = Assets.tycoon.netpost
    local postW, postH = post.width * TycoonConfig.PROP_SCALE, post.height * TycoonConfig.PROP_SCALE
    if Assets.has(post) then
        local img = image(parent, post, postW, postH, 4)
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(x, y)
    end
    local rope = Instance.new("Frame")
    rope.AnchorPoint = Vector2.new(0.5, 1)
    rope.Position = UDim2.fromOffset(x, y - postH)
    rope.Size = UDim2.fromOffset(3, math.max(0, (y - postH) - laneY))
    rope.BackgroundColor3 = Theme.COLOR.woodDark
    rope.BorderSizePixel = 0
    rope.ZIndex = 4
    rope.Parent = parent
    -- [D62, pasul 5] plasa si insigna pe rangul nivelului (pragurile 10 / 25 / 50), ca acasa
    local rank = ChainMath.rankOf(level)
    local turbine = if PadArt.isTurbine(pad) then PadArt.turbineSprite() else nil
    if turbine ~= nil then
        -- [D67, audit] turbina e roata ei cu bobine, nu o plasa (acelasi desen ca NetController)
        local art = image(
            parent,
            turbine,
            turbine.width * PadArt.TURBINE_SCALE,
            turbine.height * PadArt.TURBINE_SCALE,
            5
        )
        art.AnchorPoint = Vector2.new(0.5, 0.5)
        art.Position = UDim2.fromOffset(x, laneY)
    elseif Assets.has(Assets.tycoon.net_water) then
        local net = image(
            parent,
            PadArt.netSprite(rank, false),
            TycoonConfig.NET_DRAW.w,
            TycoonConfig.NET_DRAW.h,
            5
        )
        net.AnchorPoint = Vector2.new(0.5, 0.5)
        net.Position = UDim2.fromOffset(x, laneY)
    end
    local pill = Instance.new("Frame")
    pill.AnchorPoint = Vector2.new(0.5, 1)
    pill.Position = UDim2.fromOffset(x, y + 22)
    pill.Size = UDim2.fromOffset(56, 22)
    pill.BackgroundTransparency = 1
    pill.ZIndex = 6
    pill.Parent = parent
    Widgets.LevelBadge(pill, 6, rank)
    local text = Widgets.Label(pill, `Lv {level}`, Theme.TEXT.tiny, Theme.COLOR.onDark, "display")
    text.TextColor3 = Widgets.SetLevelBadgeRank(pill, rank)
    text.AnchorPoint = Vector2.new(0.5, 0.5)
    text.Position = UDim2.fromScale(0.5, 0.5)
    text.Size = UDim2.fromOffset(52, 18)
    text.TextXAlignment = Enum.TextXAlignment.Center
    text.ZIndex = 7
end

-- Ruina unei platforme necumparate, pe locul exact al obiectului (aceeasi baza ca in PadController.buildRuin).
local function drawRuin(parent: Instance, pad: TycoonConfig.Pad)
    if not PadArt.ruinReady(pad) then
        return
    end
    local x, y = pad.x :: number, pad.y :: number
    if PadArt.isTurbine(pad) then
        -- [D67, audit] turbina necumparata e umbra ei, ca acasa (PadController.buildGhost): stalpul intreg, funia si
        -- roata, toate intunecate si pe jumatate transparente
        local post = Assets.tycoon.netpost
        local postW, postH =
            post.width * TycoonConfig.PROP_SCALE, post.height * TycoonConfig.PROP_SCALE
        local laneY = TycoonConfig.LANE_Y[PadArt.laneOf(pad)] or TycoonConfig.LANE_Y[1]
        if Assets.has(post) then
            local postImg = image(parent, post, postW, postH, 3)
            postImg.AnchorPoint = Vector2.new(0.5, 1)
            postImg.Position = UDim2.fromOffset(x, y)
            postImg.ImageColor3 = PadArt.GHOST_TINT
            postImg.ImageTransparency = PadArt.GHOST_FADE
        end
        local art, artW, artH = PadArt.laneArt(pad, true)
        local rope = Instance.new("Frame")
        rope.AnchorPoint = Vector2.new(0.5, 1)
        rope.Position = UDim2.fromOffset(x, y - postH)
        -- pana la marginea de jos a roții: prin roata pe jumatate transparenta, funia s-ar vedea pana la butuc
        rope.Size = UDim2.fromOffset(3, math.max(0, (y - postH) - (laneY + artH / 2)))
        rope.BackgroundColor3 = PadArt.GHOST_TINT
        rope.BackgroundTransparency = PadArt.GHOST_FADE
        rope.BorderSizePixel = 0
        rope.ZIndex = 3
        rope.Parent = parent
        local wheel = image(parent, art, artW, artH, 4)
        wheel.AnchorPoint = Vector2.new(0.5, 0.5)
        wheel.Position = UDim2.fromOffset(x, laneY)
        wheel.ImageColor3 = PadArt.GHOST_TINT
        wheel.ImageTransparency = PadArt.GHOST_FADE
        return
    end
    if PadArt.isNet(pad) then
        local post = Assets.tycoon.ruin_netpost
        local net, netW, netH = PadArt.laneArt(pad, true)
        local postImg = image(
            parent,
            post,
            post.width * TycoonConfig.PROP_SCALE,
            post.height * TycoonConfig.PROP_SCALE,
            3
        )
        postImg.AnchorPoint = Vector2.new(0.5, 1)
        postImg.Position = UDim2.fromOffset(x, y)
        postImg.ImageColor3 = LOCKED_TINT
        local laneY = TycoonConfig.LANE_Y[PadArt.laneOf(pad)] or TycoonConfig.LANE_Y[1]
        local netImg = image(parent, net, netW, netH, 4)
        netImg.AnchorPoint = Vector2.new(0.5, 0.5)
        netImg.Position = UDim2.fromOffset(x, laneY)
        netImg.ImageColor3 = LOCKED_TINT
        return
    end
    local sprite, scale = PadArt.ruin(pad.id)
    if sprite ~= nil then
        local offset = PadArt.ART_OFFSET[pad.id] -- [D67, audit] ruina rotii de apa sta si ea in rau, ca acasa
        local img = standing(
            parent,
            sprite,
            x,
            TycoonConfig.buildingBase(pad) + (if offset ~= nil then offset.y else 0),
            sprite.width * scale,
            sprite.height * scale,
            4,
            if offset ~= nil and offset.inWater then nil else 0.35
        )
        img.ImageColor3 = LOCKED_TINT
    end
end

-- Ce sta pe o platforma cumparata: casa omului (mica sau mare), cladirea, sau avizierul cu pictograma meseriei.
local function drawBought(parent: Instance, pad: TycoonConfig.Pad, village: VillageLook.Snapshot)
    if PadArt.isNet(pad) then
        drawNet(parent, pad, village.netLevels[pad.id] or 1)
        return
    end
    local x = pad.x :: number
    -- [D67, audit] un desen care nu sta pe platforma lui (roata de apa, in rau), ca acasa: PadArt.ART_OFFSET
    local offset = PadArt.ART_OFFSET[pad.id]
    local base = TycoonConfig.buildingBase(pad) + (if offset ~= nil then offset.y else 0)
    local shadow = if offset ~= nil and offset.inWater then nil else 0.55
    local role = TycoonConfig.CREW_OF_PAD[pad.id]
    local count = if role ~= nil then village.crews[role] or 1 else 1
    -- nivelul forjei conteaza doar pentru forja insasi; [D67, audit] o cladire care ar cadea pe desenul forjei (arta ei
    -- lipsa) nu-l mai ia pe cel mare dupa nivelul forjei gazdei
    local forgeLevel = if pad.id == "workshop" then village.stations.forge else nil
    local sprite, scale = PadArt.bought(pad.id, count, forgeLevel, village.modern)
    local name = PadArt.homeName(pad.id)
    if sprite ~= nil and Assets.has(sprite) then
        local house = standing(
            parent,
            sprite,
            x,
            base,
            sprite.width * scale,
            sprite.height * scale,
            3,
            shadow
        )
        -- [D70] geamurile caselor si luminile cladirilor moderne, pe treapta gazdei
        Modern.windows(house, sprite, village.modern)
        Modern.lights(house, sprite, village.modern)
        if name ~= nil then
            worldName(parent, name, x, base + 2)
            -- [D62, pasul 5] treapta meseriei si fumul de la horn, ca acasa
            local tier = if role ~= nil then village.tiers[role] else nil
            if tier ~= nil then
                tierPips(parent, x, base - sprite.height * scale - 16, tier) -- deasupra acoperisului, ca acasa
            end
            local chimney = PadArt.chimneyOf(pad.id, count)
            if chimney ~= nil then
                SceneArt.AddSmoke(house, chimney[1], chimney[2])
            end
        elseif PadArt.ROOF_SIGN[pad.id] ~= nil then
            -- forja, cuptorul de cupru, Power House: numele pe acoperis, din aceeasi lista ca acasa
            worldName(
                parent,
                PadArt.ROOF_SIGN[pad.id],
                x,
                base - sprite.height * scale + PadArt.ROOF_SIGN_Y
            )
        elseif pad.id == "scrap_shed" then
            -- [2026-09-29] ca ShedController: numele jos, pe fata magaziei (baza etichetei la 6 px peste baza ei)
            worldName(parent, Strings.SHED_LABEL, x, base - 24, 112)
        end
        return
    end
    -- casa inca neurcata: avizierul curat cu pictograma meseriei (ca in PadController.styleBought)
    local iconFor = PadArt.BOARD_ICON[pad.id]
    if iconFor ~= nil and Assets.has(Assets.tycoon.board) then
        local board = Assets.tycoon.board
        standing(
            parent,
            board,
            x,
            base,
            board.width * TycoonConfig.PROP_SCALE,
            board.height * TycoonConfig.PROP_SCALE,
            3,
            0.35
        )
        local icon = iconFor()
        if Assets.has(icon) then
            local fit = 24 / math.max(icon.width, icon.height)
            local mark = image(parent, icon, icon.width * fit, icon.height * fit, 4)
            mark.AnchorPoint = Vector2.new(0.5, 0.5)
            mark.Position = UDim2.fromOffset(x, base - 34)
        end
        if name ~= nil then
            worldName(parent, name, x, base + 2)
        end
    end
end

-- Decorul cumparat cu perle, fiecare pe locurile lui din sat (VillageConfig.spotsOf, lumea 1), ca in VillageController.
-- [k2b] Macheta e mereu a satului: vizitatorul vede satul gazdei, nu piata Dam Town.
local function drawDecor(parent: Instance, village: VillageLook.Snapshot)
    for _, decor in VillageConfig.DECOR do
        local sprite = (Assets.decor :: any)[decor.sprite]
        if not village.decor[decor.id] or sprite == nil or not Assets.has(sprite) then
            continue
        end
        local z = if decor.ground == "water" then 2 elseif decor.ground == "pier" then 4 else 3
        for _, spot in VillageConfig.spotsOf(decor, 1) do
            local w, h = sprite.width * decor.scale, sprite.height * decor.scale
            if decor.ground == "land" then
                GroundShadow.add(parent, UDim2.fromOffset(spot.x, spot.y), w * 0.8, z - 1, 0.3)
            end
            local img = image(parent, sprite, w, h, z)
            img.AnchorPoint = Vector2.new(0.5, 1)
            img.Position = UDim2.fromOffset(spot.x, spot.y)
        end
    end
end

local function clearWalkers()
    for _, w in walkers do
        w.view.Destroy()
    end
    table.clear(walkers)
end

-- Oamenii: aceleasi drumuri ca acasa (HandRoutes, din meserie / al catelea / cati / plase), acelasi ceas.
local function drawPeople(parent: Frame, village: VillageLook.Snapshot)
    for _, snap in village.hands do
        local walker = HandRoutes.isWalker(snap.role)
        local view = PersonView.new(parent, snap.id, if walker then "barrow" else nil)
        view.SetAppearance(snap.appearance)
        view.SetBarrowArt(Modern.barrow(village.modern)) -- [D70] caruciorul de fier, daca gazda e acolo
        local cycle: HandMath.Cycle = { legs = {}, duration = 0 }
        if snap.x == nil then
            cycle = HandRoutes.cycleFor(snap.role, snap.index, snap.count, snap.nets)
        end
        table.insert(walkers, { snap = snap, cycle = cycle, view = view })
    end
end

local function loadStep(carrying: number, capacity: number): number
    if carrying <= 0 then
        return 0
    end
    local frac = carrying / math.max(1, capacity)
    return if frac >= 0.66 then 3 elseif frac >= 0.33 then 2 else 1
end

local function animate(dt: number)
    local r = root
    if r == nil or not r.Visible then
        return
    end
    local now = Workspace:GetServerTimeNow()
    for _, w in walkers do
        local snap = w.snap
        local x, y, state, facing
        if snap.x ~= nil and snap.y ~= nil then
            x, y, state, facing = snap.x, snap.y, "idle", "down"
        else
            x, y, state, facing = HandMath.sampleAt(w.cycle, now - snap.cycleStartAt)
        end
        local task = if state == "walk"
            then "push"
            elseif state == "collect" then "load"
            elseif state == "drop" or state == "sell" then "tip"
            else "idle"
        w.view.SetCarry(snap.carryKind, loadStep(snap.carrying, snap.capacity))
        w.view.Pose(x, y, task, facing, state == "walk", dt)
    end
end

-- Pamantul, raul si drumurile: o singura data, la prima vizita (sunt aceleasi in orice sat).
local function ensureRoot(): Frame
    local existing = root
    if existing ~= nil then
        return existing
    end
    local host = scroll :: Frame
    local r = Instance.new("Frame")
    r.Name = "VisitedVillage"
    r.BackgroundTransparency = 1
    r.Position = UDim2.fromOffset(VillageDiorama.ORIGIN.x, VillageDiorama.ORIGIN.y)
    r.Size = UDim2.fromOffset(VillageDiorama.SIZE.w, VillageDiorama.SIZE.h)
    r.ZIndex = ROOT_Z
    r.Visible = false
    r.Parent = host
    SceneArt.BuildBackground({ Fixed = r, Parallax = r, Scroll = r })
    root = r
    return r
end

-- Arata satul din fotografie. Ce era desenat de la vizita dinainte se sterge intai.
function VillageDiorama.Show(village: VillageLook.Snapshot)
    if scroll == nil then
        return
    end
    local r = ensureRoot()
    clearWalkers()
    local old = plot
    if old ~= nil then
        old:Destroy()
    end
    -- terenul construit, peste sol (in sat, Plot-ul are Z 5 in stratul lumii)
    local p = Instance.new("Frame")
    p.Name = "Plot"
    p.BackgroundTransparency = 1
    p.Position = UDim2.fromOffset(TycoonConfig.PLOT_ORIGIN.x, TycoonConfig.PLOT_ORIGIN.y)
    p.Size = UDim2.fromOffset(0, 0)
    p.ZIndex = 5
    p.Parent = r
    plot = p

    -- pontonul lung, pe care se merge
    local pier = Assets.tycoon.pier_long
    if Assets.has(pier) then
        local img =
            image(p, pier, pier.width * Assets.PIXEL_SCALE, pier.height * Assets.PIXEL_SCALE, 3)
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(
            TycoonConfig.PIER.x,
            TycoonConfig.PIER.y + pier.height * Assets.PIXEL_SCALE / 2
        )
    end
    -- [D62, pasul 5] de la nivelul 25, gazda are taverna si gaterul in a doua infatisare, ca acasa la ea
    station(
        p,
        PadArt.station("dock", village.stations.dock, village.modern),
        TycoonConfig.TAVERN,
        Strings.TAVERN_LABEL,
        "roof",
        village.modern
    )
    station(
        p,
        Modern.variant((Assets.tycoon :: any).storage, village.modern),
        TycoonConfig.STORAGE,
        Strings.STORAGE_LABEL,
        "inside",
        village.modern
    )
    station(
        p,
        PadArt.station("saw", village.stations.saw, village.modern),
        TycoonConfig.SAWMILL,
        Strings.SAWMILL_LABEL,
        "inside",
        village.modern
    )

    -- [D65] cladirile fixe ale Morii apar cu roata de apa, ca acasa la gazda (pana la arta lor: desenele perechii
    -- din Era 1, ca in LineController)
    local tycoon: any = Assets.tycoon
    -- desenul cladirii cand e urcat, altfel al perechii din era dinainte
    local function art(own: string, borrowed: string): Assets.Sprite?
        local sprite = tycoon[own]
        return if sprite ~= nil and Assets.has(sprite) then sprite else tycoon[borrowed]
    end
    -- [2026-09-29] cat cartierul e inchis, ruinele lor, ca acasa (LineController.drawRuin: fara nume, fara tenta)
    local function ruinOf(key: string, box: { x: number, y: number, w: number, h: number })
        local sprite = tycoon["ruin_" .. key]
        if sprite ~= nil and Assets.has(sprite) then
            standing(p, sprite, box.x, box.y, box.w, box.h, 3, nil)
        end
    end
    if village.pads.water_wheel then
        local words = Strings.LINE_WORDS.parts
        station(p, art("mill_store", "storage"), TycoonConfig.MILL_STORE, words.store, "above")
        station(p, art("foundry", "sawmill"), TycoonConfig.FOUNDRY, words.processor, "above")
        station(p, art("market", "tavern"), TycoonConfig.MARKET, Strings.MARKET_LABEL, "above")
    else
        ruinOf("mill_store", TycoonConfig.MILL_STORE)
        ruinOf("foundry", TycoonConfig.FOUNDRY)
        ruinOf("market", TycoonConfig.MARKET)
    end
    -- [D67] si ale Wire Works, cu masina cu abur (cat Era 3 e in joc: altfel platforma ei nu poate fi cumparata)
    if TycoonConfig.eraIsLive(3) then
        if village.pads.steam_engine then
            local words = Strings.LINE_WORDS.coils
            station(
                p,
                art("works_store", "mill_store"),
                TycoonConfig.WORKS_STORE,
                words.store,
                "above"
            )
            station(
                p,
                art("wire_works", "foundry"),
                TycoonConfig.WIRE_WORKS,
                words.processor,
                "above"
            )
            station(
                p,
                art("depot", "market"),
                TycoonConfig.DEPOT,
                Strings.LINK_WORDS.depot.label,
                "above"
            )
        else
            ruinOf("works_store", TycoonConfig.WORKS_STORE)
            ruinOf("wire_works", TycoonConfig.WIRE_WORKS)
            ruinOf("depot", TycoonConfig.DEPOT)
        end
    end

    -- [D70, verificatorul j10] macheta e a satului de pe rau (lumea 1): platformele barajului au locuri pe alta harta
    for _, pad in TycoonConfig.padsOfWorld(1) do
        if not pad.live or pad.x == nil or pad.y == nil then
            continue -- erele care nu sunt inca in joc n-au lume construita
        end
        if village.pads[pad.id] then
            drawBought(p, pad, village)
        else
            drawRuin(p, pad)
        end
    end
    drawDecor(p, village)
    -- [D67, audit] felinarele strazii, aprinse daca gazda a vandut deja curent (adancimea dupa baza, ca oamenii); [D73] se
    -- vad de la treapta "wire" a modernizarii gazdei, ca acasa (LampController)
    StreetLamps.draw(p, village.power).show(village.modern >= (ModernMath.stageOf("wire") or 1))
    ModernProps.draw(p, village.modern) -- [D70] stalpii cu sarma si recuzita modernizarii, pe treapta gazdei
    drawPeople(p, village)

    -- cartea de oaspeti: avizierul curat, cu numele dedesubt
    local book = VillageDiorama.GUEST_BOOK
    local board = Assets.tycoon.board
    if Assets.has(board) then
        standing(
            p,
            board,
            book.x,
            book.y,
            board.width * GUEST_BOOK_SCALE,
            board.height * GUEST_BOOK_SCALE,
            4,
            0.35
        )
    end
    worldName(p, Strings.VISIT_GUEST_BOOK, book.x, book.y + 2)
    r.Visible = true
end

function VillageDiorama.Hide()
    local r = root
    if r ~= nil then
        r.Visible = false
    end
    clearWalkers()
end

-- Se poate calca aici? (x, y) in coordonatele stratului balciului. Ca acasa: doar raul opreste pasul, iar pe ponton
-- mergi pana la capat.
function VillageDiorama.IsBlocked(x: number, y: number): boolean
    return WorldMap.isBlocked(
        rects,
        RiverConfig,
        x - VillageDiorama.ORIGIN.x,
        y - VillageDiorama.ORIGIN.y
    )
end

-- Din coordonatele satului in ale stratului balciului.
function VillageDiorama.ToWorld(x: number, y: number): (number, number)
    return x + VillageDiorama.ORIGIN.x, y + VillageDiorama.ORIGIN.y
end

function VillageDiorama.Init(scrollLayer: Frame)
    scroll = scrollLayer
    RunService.PreRender:Connect(animate)
end

return VillageDiorama
