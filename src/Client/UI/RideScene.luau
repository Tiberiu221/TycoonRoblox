--!strict
-- [D60] DRUMUL PICTAT CU BARCA, comun celor doua place-uri: din sat spre balci (in amonte) si inapoi (in aval).
-- Owner-ul (2026-09-16): "+ o animatie de travel cu barca, ceva cinematic of course".
--
-- Ce se vede: raul de sus, cu malul departe (copaci, felinare pe nisip) si malul de langa tine (papura, tufe), barca in
-- cadru cu tine in ea, dara din spate, seara care se lasa si, la capat, luminile locului in care ajungi. Sase secunde
-- (RideMath): ecranul se stinge cat barca se desprinde, drumul apare de sub negru, iar la final se stinge din nou.
-- Schimbarea de loc (teleportul) se face pe negru, cu textul drumului; acelasi negru il vede jucatorul si in timpul
-- teleportului (SetTeleportGui) si la sosire (ReplicatedFirst/Loading), pana i se incarca profilul.
--
-- Un singur drum pe place: modulul tine starea, iar controllerul barcii (FerryController, in fiecare place) il porneste,
-- ii da desenul barcii din lume (OnPushOff/OnLeft) si il intoarce daca barca n-a plecat (ComeBack).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
local Prng = require(ReplicatedStorage.Shared.Modules.Prng)
local RideMath = require(ReplicatedStorage.Shared.Modules.RideMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local SceneArt = require(script.Parent.Parent.Controllers.SceneArt)
local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

export type Options = {
    PlayerGui: PlayerGui,
    Upstream: boolean, -- true: spre balci, contra curentului (spre stanga); false: spre casa, cu curentul
    RowingText: string, -- pe negru, la capatul drumului si in timpul teleportului
    Destination: string, -- "fair" | "village": luminile de la capat
}

export type Ride = {
    Outfit: string,
    Look: LookMath.Look?, -- [D61] infatisarea aleasa la croitoreasa; nil = chipul de la inceput
    CanSkip: boolean, -- Skip apare de la al doilea drum
    OnPushOff: (number) -> (), -- 0..1: barca din lume se desprinde de mal
    OnLeft: () -> (), -- drumul a acoperit lumea: barca din lume se ascunde
    OnArrived: () -> (), -- s-a terminat drumul, pe negru: acum se cere teleportul
    -- [2026-10-07] cu ce mergi (RideMath.Vessel): de la baraj, salupa cu aburi, mai iute; fara ea, barca cu vasle
    Vessel: string?,
    Text: string?, -- textul de pe negru pentru drumul asta; fara el, cel din Options
}

local RideScene = {}

local PUSH_OFF = 0.3
local FADE_IN = 0.35
-- Se vede STAGE_H pe inaltime (pe harta satului se vad 900: camera "coboara" spre apa), desenele la pixelul hartii.
local STAGE_H = 540
local ART = Assets.PIXEL_SCALE
local FAR_SHORE, WATER_TOP, NEAR_SHORE, NEAR_GRASS = 110, 206, 430, 526
local BOAT_BASE = 380
local CURRENT = 60 -- apa curge spre dreapta, pe langa barca
local WAKE_EVERY = 0.12
local WAKE_LIFE = 0.9
local SCENERY_SEED = 604017
-- Malurile se aseaza FATA DE BARCA (`rel`): pe ecran, x = locul barcii + rel + drumul facut (cu semnul directiei). Se
-- intind cat pe cel mai lat ecran (SPAN) plus tot drumul, ca la capat sa nu ramana mal gol.
local SPAN = 2400
local BOAT_AT = 0.56 -- barca sta putin in spatele mijlocului: in fata ei e drumul

type Strip = { img: ImageLabel, tile: number, water: boolean }
type Prop = { obj: GuiObject, rel: number }
-- o lumina si cat de tare arde la noapte; seara abia se vede, apoi creste odata cu amurgul
type Light = { discs: { Frame }, strength: number }
type Wake = { f: Frame, x: number, y: number, age: number }

local opts: Options? = nil
local state = "idle" -- "idle" | "riding" | "waiting"
local ride: Ride? = nil
local vessel = "row" -- [2026-10-07] barca drumului de acum (RideMath.Vessel)
local rideT = 0
local waitingSince = 0
local left = false
local dir = -1 -- -1 = in amonte (spre stanga), 1 = in aval

local gui: ScreenGui
local stage: Frame
local canvas: Frame
local cover: Frame
local rowingLabel: TextLabel
local skipButton: TextButton
local vesselFrame: Frame
local boatImage: ImageLabel
local smokeHost: Frame
local travelText: TextLabel? = nil
local boatLantern: Frame
local tint: Frame
local setRiderPose: SceneArt.Pose
local setRiderOutfit: SceneArt.SetOutfit
local setRiderLook: SceneArt.SetLook
local strips: { Strip } = {}
local props: { Prop } = {}
local lights: { Light } = {}
local wakes: { Wake } = {}
local wakeClock = 0

local function spriteImage(parent: Instance, s: Assets.Sprite, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Size = UDim2.fromOffset(s.width * ART, s.height * ART)
    img.ZIndex = z
    if Assets.has(s) then
        img.Image = Assets.url(s)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        img.BackgroundTransparency = 0
        img.BackgroundColor3 = Theme.COLOR.wood
    end
    img.Parent = parent
    return img
end

-- Desenele au prova in dreapta; spre stanga se oglindesc (ImageRectSize negativ, ca la mersul personajului).
function RideScene.Mirror(img: ImageLabel, s: Assets.Sprite)
    img.ImageRectOffset = Vector2.new(s.width, 0)
    img.ImageRectSize = Vector2.new(-s.width, s.height)
end

-- [2026-10-07] Desenul unei barci: salupa barajului cand e urcata, altfel barca balciului (au aceeasi marime, 62x30,
-- deci locurile din lume si din balci raman aceleasi).
function RideScene.SpriteFor(v: string): Assets.Sprite
    local launch = Assets.fair.launch
    if v == "launch" and Assets.has(launch) then
        return launch
    end
    return Assets.fair.ferry
end

-- Gura cosului salupei, in pixelii desenului nerasturnat (prova in dreapta): de aici iese fumul, si in lume, si pe drum.
RideScene.FUNNEL = { x = 40.5, y = 3 }

-- Fumul salupei: o gazda mica, cu baza in gura cosului, in care SceneArt.AddSmoke pune rotocoalele (marimea lor vine
-- din latimea gazdei, cat urca din inaltimea ei). `x`, `y`: gura cosului in parintele ei.
function RideScene.Smoke(parent: GuiObject, x: number, y: number, z: number, size: Vector2?): Frame
    local host = Instance.new("Frame")
    host.Name = "Smoke"
    host.BackgroundTransparency = 1
    host.AnchorPoint = Vector2.new(0.5, 1)
    local s = size or Vector2.new(40, 70)
    host.Size = UDim2.fromOffset(s.X, s.Y)
    host.Position = UDim2.fromOffset(x, y)
    host.ZIndex = z
    host.Parent = parent
    SceneArt.AddSmoke(host, 0.5, 1)
    return host
end

-- Lumina calda a unui felinar, peste amurg: trei discuri unul in altul, tot mai dese spre mijloc. Taria o pune
-- `setNight`, dupa cat s-a lasat seara.
local function glow(parent: Instance, size: number, z: number, strength: number): Frame
    local host = Instance.new("Frame")
    host.AnchorPoint = Vector2.new(0.5, 0.5)
    host.Size = UDim2.fromOffset(size, size)
    host.BackgroundTransparency = 1
    host.ZIndex = z
    local discs = {}
    for _, k in { 1, 0.62, 0.3 } do
        local disc = Instance.new("Frame")
        disc.AnchorPoint = Vector2.new(0.5, 0.5)
        disc.Position = UDim2.fromScale(0.5, 0.5)
        disc.Size = UDim2.fromScale(k, k)
        disc.BackgroundColor3 = Color3.fromRGB(255, 196, 120)
        disc.BackgroundTransparency = 1
        disc.BorderSizePixel = 0
        disc.ZIndex = z
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = disc
        disc.Parent = host
        table.insert(discs, disc)
    end
    host.Parent = parent
    table.insert(lights, { discs = discs, strength = strength })
    return host
end

-- 0 = inceputul drumului (inca e lumina), 1 = seara deplina
local function setNight(night: number)
    local k = 0.25 + 0.75 * night
    for _, light in lights do
        for i, disc in light.discs do
            disc.BackgroundTransparency = 1 - light.strength * k * (0.22 + 0.2 * i)
        end
    end
end

local function strip(s: Assets.Sprite, y: number, h: number, water: boolean, z: number)
    local tile = s.width * ART
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(s)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.ScaleType = Enum.ScaleType.Tile
    img.TileSize = UDim2.fromOffset(tile, s.height * ART)
    img.Position = UDim2.fromOffset(-tile, y)
    img.Size = UDim2.fromOffset(SPAN + tile * 2, h)
    img.ZIndex = z
    img.Parent = canvas
    table.insert(strips, { img = img, tile = tile, water = water })
end

local function addProp(obj: GuiObject, rel: number, y: number)
    obj.Position = UDim2.fromOffset(rel, y)
    table.insert(props, { obj = obj, rel = rel })
end

-- Luminile de la capat, pe malul departe, in fata barcii: stalpii si ghirlandele balciului, sau felinarele si casele
-- satului. Intra in cadru pe la jumatatea drumului; la capat stau deasupra barcii.
local function buildDestination(o: Options)
    -- la capat, malurile s-au mutat cu tot drumul in sens invers: ce era la `dir * DISTANCE` ajunge deasupra barcii
    local ahead = dir * RideMath.DISTANCE - 260
    if o.Destination == "fair" then
        for i = 0, 3 do
            local lx = ahead + i * 130
            addProp(spriteImage(canvas, Assets.fair.lamppost, 4), lx, WATER_TOP - 4)
            addProp(glow(canvas, 140, 8, 0.6), lx, WATER_TOP - 124)
            if i < 3 then
                addProp(spriteImage(canvas, Assets.fair.flag, 4), lx + 65, WATER_TOP - 8)
                -- ghirlanda de becuri intre doi stalpi
                for b = 1, 5 do
                    local bulb = Instance.new("Frame")
                    bulb.AnchorPoint = Vector2.new(0.5, 0.5)
                    bulb.Size = UDim2.fromOffset(6, 6)
                    bulb.BackgroundColor3 = Color3.fromRGB(255, 226, 150)
                    bulb.BorderSizePixel = 0
                    bulb.ZIndex = 9
                    bulb.Parent = canvas
                    addProp(
                        bulb,
                        lx + b * 130 / 6,
                        WATER_TOP - 128 + math.sin(b / 6 * math.pi) * 18
                    )
                end
            end
        end
    else
        -- satul tau: doua case cu ferestre aprinse si, intre ele, felinarele pontonului
        for i = 0, 1 do
            local hx = ahead + i * 210
            addProp(spriteImage(canvas, Assets.buildings.cottage, 4), hx, WATER_TOP - 30)
            addProp(glow(canvas, 110, 8, 0.45), hx, WATER_TOP - 90)
        end
        for _, dx in { -110, 105, 320 } do
            addProp(spriteImage(canvas, Assets.decor.pier_lamp, 4), ahead + dx, WATER_TOP - 4)
            addProp(glow(canvas, 110, 8, 0.55), ahead + dx, WATER_TOP - 88)
        end
    end
end

-- Malurile, din samanta: aceleasi la fiecare drum.
local function buildScenery(o: Options)
    local rng = Prng.new(SCENERY_SEED)
    -- in fata barcii se vede cel mult BOAT_AT x SPAN, in spate restul; in fata se adauga tot drumul
    local ahead = BOAT_AT * SPAN + RideMath.DISTANCE + 200
    local behind = (1 - BOAT_AT) * SPAN + 200
    local from, to = if dir < 0 then -ahead else -behind, if dir < 0 then behind else ahead
    local x = from
    while x < to do
        local pick = rng:nextNumber()
        local s = if pick < 0.45
            then Assets.props.tree_pine
            elseif pick < 0.8 then Assets.props.tree_round
            else Assets.props.bush
        local base = FAR_SHORE - 6 - rng:nextInteger(0, 40)
        addProp(spriteImage(canvas, s, 3 + math.floor(base / 60)), x, base)
        x += rng:nextInteger(70, 150)
    end
    x = from + 120
    while x < to do
        addProp(spriteImage(canvas, Assets.props.lantern, 4), x, WATER_TOP - 6)
        addProp(glow(canvas, 110, 8, 0.5), x, WATER_TOP - 112)
        x += 340
    end
    x = from + 40
    while x < to do
        local s = if rng:nextNumber() < 0.5 then Assets.props.cattails else Assets.fair.reeds
        addProp(spriteImage(canvas, s, 5), x, NEAR_SHORE + 40 + rng:nextInteger(0, 20))
        x += rng:nextInteger(110, 220)
    end
    x = from + 200
    while x < to do
        addProp(spriteImage(canvas, Assets.props.bush, 5), x, STAGE_H + 30)
        x += rng:nextInteger(160, 260)
    end
    x = from + 290
    while x < to do
        addProp(spriteImage(canvas, Assets.props.lantern, 5), x, STAGE_H + 10)
        addProp(glow(canvas, 130, 8, 0.45), x, STAGE_H + 10 - 106)
        x += 460
    end
    buildDestination(o)
end

local function coverAlpha(t: number): number
    if t < PUSH_OFF then
        return t / PUSH_OFF
    elseif t < PUSH_OFF + FADE_IN then
        return 1 - (t - PUSH_OFF) / FADE_IN
    end
    return RideMath.fade(t, vessel)
end

local function spawnWake(boatX: number, boatY: number)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Size = UDim2.fromOffset(12, 3)
    f.BackgroundColor3 = Color3.fromRGB(226, 240, 244)
    f.BorderSizePixel = 0
    f.ZIndex = 3
    f.Parent = canvas
    local side = if #wakes % 2 == 0 then -1 else 1
    -- pupa e in spatele barcii: in dreapta cand mergi spre stanga, si invers
    local stern = boatX - dir * Assets.fair.ferry.width * ART * 0.45
    -- salupa lasa o dara mai lata (elicea), barca cu vasle doar doua dungi
    local spread = if vessel == "launch" then 12 else 8
    table.insert(wakes, { f = f, x = stern, y = boatY - 12 + side * spread, age = 0 })
end

local function clearWakes()
    for _, wk in wakes do
        wk.f:Destroy()
    end
    table.clear(wakes)
end

local function draw(dt: number)
    local w = canvas.Size.X.Offset
    local travelled = RideMath.DISTANCE * RideMath.progress(rideT, vessel)
    -- barca sta pe loc in cadru; malurile trec pe langa ea, in sens invers drumului
    local boatX = if dir < 0 then w * BOAT_AT else w * (1 - BOAT_AT)
    local shift = -dir * travelled
    for _, s in strips do
        -- apa: in amonte trece mai repede decat malurile (curentul e contra), in aval mai incet (te duce ea)
        local offset = if not s.water
            then shift
            elseif dir < 0 then shift + rideT * CURRENT
            else shift * 0.6
        s.img.Position = UDim2.fromOffset(-s.tile + (offset % s.tile), s.img.Position.Y.Offset)
    end
    for _, p in props do
        p.obj.Position = UDim2.fromOffset(boatX + p.rel + shift, p.obj.Position.Y.Offset)
    end
    local at = RideMath.at(rideT, { x = 0, y = 0 }, vessel)
    local boatY = BOAT_BASE + math.sin(rideT * 2.4) * 3 + at.y * 0.4
    vesselFrame.Position = UDim2.fromOffset(boatX, boatY)
    vesselFrame.Rotation = at.tilt
    boatLantern.Position =
        UDim2.fromOffset(boatX + dir * Assets.fair.ferry.width * ART * 0.4, boatY - 60)
    setRiderPose(false, if dir < 0 then "left" else "right", dt, false, nil)
    local night = math.clamp(rideT / RideMath.secondsOf(vessel), 0, 1)
    tint.BackgroundTransparency = 0.92 - 0.47 * night
    setNight(night)

    wakeClock += dt
    if wakeClock >= (if vessel == "launch" then WAKE_EVERY * 0.6 else WAKE_EVERY) then
        wakeClock = 0
        spawnWake(boatX, boatY)
    end
    for i = #wakes, 1, -1 do
        local wk = wakes[i]
        wk.age += dt
        if wk.age >= WAKE_LIFE then
            wk.f:Destroy()
            table.remove(wakes, i)
            continue
        end
        wk.x -= dir * (140 + CURRENT) * dt
        local k = wk.age / WAKE_LIFE
        wk.f.Position = UDim2.fromOffset(wk.x, wk.y)
        wk.f.Size = UDim2.fromOffset(12 + 22 * k, 3)
        wk.f.BackgroundTransparency = 0.2 + 0.8 * k
    end
end

local function update(dt: number)
    local r = ride
    if state ~= "riding" or r == nil then
        return
    end
    rideT += dt
    cover.BackgroundTransparency = 1 - coverAlpha(rideT)
    if rideT < PUSH_OFF then
        r.OnPushOff(rideT / PUSH_OFF)
    elseif not left then
        left = true
        stage.Visible = true
        r.OnLeft()
    end
    if stage.Visible then
        draw(dt)
    end
    skipButton.Visible = r.CanSkip
        and RideMath.canSkip(rideT)
        and rideT < RideMath.secondsOf(vessel) - RideMath.FADE
    if RideMath.done(rideT, vessel) then
        state = "waiting"
        waitingSince = os.clock()
        cover.BackgroundTransparency = 0
        skipButton.Visible = false
        rowingLabel.Visible = true
        stage.Visible = false
        clearWakes()
        r.OnArrived()
    end
end

-- [verificatorul k7-k8] cartonasul barcii e pus din nou la fiecare drum: alt drum (reincarcarea in lumea 2) poate fi pus
-- intre timp pe cartonasul lui
local travelGui: ScreenGui? = nil
local function armTravel()
    local t = travelGui
    if t ~= nil then
        pcall(function()
            TeleportService:SetTeleportGui(t)
        end)
    end
end

-- [2026-10-07] Desenul barcii si fumul cosului, dupa barca drumului (ambele desene au 62x30, deci cadrul ramane).
local function setVessel(v: string)
    local sprite = RideScene.SpriteFor(v)
    if Assets.has(sprite) then
        boatImage.Image = Assets.url(sprite)
        if dir < 0 then
            RideScene.Mirror(boatImage, sprite)
        end
    end
    smokeHost.Visible = sprite == Assets.fair.launch
end

-- Porneste drumul. Intoarce false daca un drum e deja in curs.
function RideScene.Start(r: Ride): boolean
    if opts == nil or state ~= "idle" then
        return false
    end
    ride = r
    vessel = r.Vessel or "row"
    setVessel(vessel)
    local text = r.Text or (opts :: Options).RowingText
    rowingLabel.Text = text
    local tt = travelText
    if tt ~= nil then
        tt.Text = text
    end
    armTravel()
    state = "riding"
    rideT = 0
    wakeClock = 0
    left = false
    setRiderOutfit(r.Outfit)
    setRiderLook(r.Look or LookMath.DEFAULT)
    rowingLabel.Visible = false
    stage.Visible = false
    cover.BackgroundTransparency = 1
    gui.Enabled = true
    return true
end

-- Sari peste drum: ramane doar stingerea de la capat, ca schimbarea de loc sa se faca tot pe negru.
function RideScene.Skip()
    local r = ride
    if state == "riding" and r ~= nil and r.CanSkip and RideMath.canSkip(rideT) then
        rideT = math.max(rideT, RideMath.secondsOf(vessel) - RideMath.FADE)
    end
end

-- "idle" | "riding" | "waiting" (pe negru, dupa drum, pana pleaca teleportul sau vine un refuz)
function RideScene.State(): string
    return state
end

function RideScene.WaitingFor(): number
    return if state == "waiting" then os.clock() - waitingSince else 0
end

-- Barca n-a plecat: negrul se ridica de pe lume (controllerul pune la loc barca si omul inainte).
function RideScene.ComeBack()
    if state == "idle" then
        return
    end
    state = "idle"
    ride = nil
    rowingLabel.Visible = false
    skipButton.Visible = false
    stage.Visible = false
    clearWakes()
    cover.BackgroundTransparency = 0
    local fade = TweenService:Create(
        cover,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { BackgroundTransparency = 1 }
    )
    fade.Completed:Connect(function()
        if state == "idle" then
            gui.Enabled = false
        end
    end)
    fade:Play()
end

function RideScene.Init(o: Options)
    opts = o
    dir = if o.Upstream then -1 else 1
    gui = Instance.new("ScreenGui")
    gui.Name = "Ride"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ScreenInsets = Enum.ScreenInsets.None
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 20 -- peste HUD (2) si tutorial (3)
    gui.Enabled = false
    gui.Parent = o.PlayerGui

    stage = Instance.new("Frame")
    stage.Name = "Stage"
    stage.Size = UDim2.fromScale(1, 1)
    stage.BackgroundColor3 = Color3.fromRGB(34, 58, 70)
    stage.BorderSizePixel = 0
    stage.ClipsDescendants = true
    stage.Active = true -- nimic de sub drum nu se apasa
    stage.Visible = false
    stage.Parent = gui

    canvas = Instance.new("Frame")
    canvas.Name = "Canvas"
    canvas.BackgroundTransparency = 1
    canvas.Parent = stage
    local canvasScale = Instance.new("UIScale")
    canvasScale.Parent = canvas
    -- toata inaltimea ecranului arata STAGE_H; latimea e cat iese din ecran la scara asta
    local camera = Workspace.CurrentCamera
    local function fit()
        local size = camera.ViewportSize
        canvasScale.Scale = math.max(0.1, size.Y / STAGE_H)
        canvas.Size = UDim2.fromOffset(math.ceil(size.X / canvasScale.Scale), STAGE_H)
    end
    fit()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

    -- iarba de sus, malul departe, apa, malul de langa tine, iarba de jos
    strip(Assets.grass_tile, 0, FAR_SHORE, false, 1)
    strip(Assets.shore_north, FAR_SHORE, WATER_TOP - FAR_SHORE, false, 2)
    strip(Assets.water_tile, WATER_TOP, NEAR_SHORE - WATER_TOP, true, 1)
    strip(Assets.shore_south, NEAR_SHORE, NEAR_GRASS - NEAR_SHORE, false, 2)
    strip(Assets.grass_tile, NEAR_GRASS, STAGE_H - NEAR_GRASS + 8, false, 1)
    buildScenery(o)

    -- barca, cu tine in ea: omul in spatele bordului, ca bordul sa-i acopere picioarele
    local ferry = Assets.fair.ferry
    local hull = Instance.new("Frame")
    hull.Name = "Vessel"
    hull.BackgroundTransparency = 1
    hull.AnchorPoint = Vector2.new(0.5, 1)
    hull.Size = UDim2.fromOffset(ferry.width * ART, ferry.height * ART + 60)
    hull.ZIndex = 6
    hull.Parent = canvas
    vesselFrame = hull
    local rider, pose, setOutfit, setLook = SceneArt.MakeCharacter(hull)
    -- [verificatorul, 2026-10-07] talpile pe randul ~21 al desenului: bordul departat (randul 13 la barca, 11 la salupa)
    -- taie omul la mijloc; la -44, cu desenele noi, statea in picioare pe marginea barcii
    rider.Position = UDim2.new(0.5, -dir * 18, 1, -26)
    rider.ZIndex = 1
    setRiderPose = pose
    setRiderOutfit = setOutfit
    setRiderLook = setLook
    local boat = spriteImage(hull, ferry, 2)
    boat.Position = UDim2.fromScale(0.5, 1)
    if dir < 0 and Assets.has(ferry) then
        RideScene.Mirror(boat, ferry)
    end
    boatImage = boat
    -- fumul salupei, din gura cosului (oglindita cand mergi spre stanga); se vede doar pe salupa
    local funnelX = if dir < 0 then ferry.width - RideScene.FUNNEL.x else RideScene.FUNNEL.x
    smokeHost = RideScene.Smoke(hull, funnelX * ART, 60 + RideScene.FUNNEL.y * ART, 3)
    smokeHost.Visible = false

    -- amurgul se lasa pe tot drumul; luminile stau peste el
    tint = Instance.new("Frame")
    tint.Name = "Dusk"
    tint.Size = UDim2.fromScale(1, 1)
    tint.BackgroundColor3 = Color3.fromRGB(16, 20, 48)
    tint.BackgroundTransparency = 1
    tint.BorderSizePixel = 0
    tint.ZIndex = 7
    tint.Parent = canvas
    boatLantern = glow(canvas, 110, 8, 0.6)

    cover = Instance.new("Frame")
    cover.Name = "Cover"
    cover.Size = UDim2.fromScale(1, 1)
    cover.BackgroundColor3 = Color3.new(0, 0, 0)
    cover.BackgroundTransparency = 1
    cover.BorderSizePixel = 0
    cover.Active = true
    cover.ZIndex = 20
    cover.Parent = gui
    rowingLabel =
        Widgets.Label(cover, o.RowingText, Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    rowingLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    rowingLabel.Position = UDim2.fromScale(0.5, 0.5)
    rowingLabel.Size = UDim2.new(1, -32, 0, 40)
    rowingLabel.TextXAlignment = Enum.TextXAlignment.Center
    rowingLabel.ZIndex = 21
    rowingLabel.Visible = false

    skipButton = Widgets.Button(cover, {
        text = Strings.FERRY_SKIP,
        width = 140,
        height = 48,
        z = 30,
        onClick = RideScene.Skip,
    })
    skipButton.AnchorPoint = Vector2.new(1, 1)
    skipButton.Position = UDim2.new(1, -24, 1, -24)
    skipButton.Visible = false

    -- in timpul teleportului se vede acelasi negru, cu acelasi text (Loading il pastreaza si la sosire)
    local travel = Instance.new("ScreenGui")
    travel.Name = "RideTravel"
    travel.IgnoreGuiInset = true
    local black = Instance.new("Frame")
    black.Size = UDim2.fromScale(1, 1)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BorderSizePixel = 0
    black.Parent = travel
    local text = rowingLabel:Clone()
    text.Visible = true
    text.Parent = black
    travelText = text
    travelGui = travel
    armTravel()

    RunService.PreRender:Connect(update)
end

return RideScene
