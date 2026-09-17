--!strict
-- [D60] BALCIUL DE SEARA, desenat pe straturile camerei (CameraController), exact din FairLayout: aceleasi pozitii pe
-- care le verifica testul de asezare (zero suprapuneri). Camera te urmareste.
--
-- [2026-09-17] Owner-ul, la prima vedere in Studio: "arata super super cheap atm texturile, efectele acelea de lumina,
-- obiectele, pamantul ala circular, basically everything". Prima versiune desena poiana din dreptunghiuri si discuri
-- plate. Acum e ca macheta aprobata:
--   * dedesubt, FUNDALUL COPT (Assets.fair.ground, scripts/art/d60_ground.py): iarba de noapte, pamantul batatorit cu
--     marginea rupta si drumurile lui, iazul, raul, umbrele, baltile de lumina calda si padurea de pe margini;
--   * peste el, ce se acopera cu oamenii, dupa baza (ZIndexFor): obiectele, colorate de lumina din jurul lor (LitTint,
--     aceeasi socoteala ca la coacere), si copacii din jur;
--   * ce traieste: focurile palpaie (lumina moale, Assets.fair.glow) si scot scantei, felinarele au aura lor, ghirlandele
--     de becuri atarna intre stalpi si clipesc;
--   * etichetele sunt doar text cu contur, ca pe macheta si ca in sat.
-- Toate pozitiile de mai sus vin din FairScenery (generat de acelasi script care coace fundalul).
--
-- Marginile inchise pana la D61 (croitoreasa, poarta satelor, iazul, gheretele) au eticheta lor, "Opens soon", ca
-- nimeni sa nu astepte degeaba [D43].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local FairScenery = require(ReplicatedStorage.Shared.Config.FairScenery)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local FairScene = {}

FairScene.NIGHT = Color3.fromRGB(18, 24, 44) -- seara din jurul lumii (fundalul ecranului, in Bootstrap)
local COLD = { 120, 132, 176 } -- ce e departe de lumini
local TREE_COLD = { 96, 112, 128 }
local LIT = { 255, 226, 186 } -- ce sta in lumina
local FIRE_GLOW = Color3.fromRGB(255, 170, 90)
local LAMP_GLOW = Color3.fromRGB(255, 214, 150)
local WIRE = Color3.fromRGB(34, 26, 22)
local GOLD = Color3.fromRGB(236, 190, 92)
local ART = Assets.PIXEL_SCALE

-- Straturile, de jos in sus. Obiectele si oamenii au ZIndexFor(baza), intre OBJECTS si LABELS.
FairScene.Z = {
    GROUND = 1,
    WATER = 2,
    FLOOR = 3,
    POND = 4,
    LIGHT = 5,
    OBJECTS = 100,
    SPARKS = 880,
    GARLANDS = 885,
    LABELS = 900,
    CARD = 950,
}

type Flicker = { host: ImageLabel, size: number, phase: number, base: number, amount: number }
type Spark = { f: Frame, fire: FairScenery.Fire, age: number, life: number, vx: number, vy: number }
type Twinkle = { host: ImageLabel, phase: number }
local flickers: { Flicker } = {}
local sparks: { Spark } = {}
local twinkles: { Twinkle } = {}
local spriteOf: { [string]: ImageLabel } = {}
local world: Frame

function FairScene.ZIndexFor(baseY: number): number
    return FairScene.Z.OBJECTS + math.clamp(math.floor(baseY / 4), 0, FairScene.Z.SPARKS - 101)
end

-- Culoarea luminii pe un lucru care sta la (x, y): langa foc sau felinar e calda, departe e rece. Aceeasi socoteala ca
-- scripts/art/d60_ground.py (lit_tint), ca obiectele si fundalul copt sa fie luminate la fel.
function FairScene.LitTint(x: number, y: number, cold: { number }?): Color3
    local best = 0
    for _, light in FairScenery.LIGHTS do
        local q = math.sqrt((x - light.x) ^ 2 + ((y - light.y) * 1.3) ^ 2) / light.r
        if q < 1 then
            best = math.max(best, light.strength * (1 - q) ^ 1.5)
        end
    end
    local t = math.min(1, best * 1.7)
    local c = cold or COLD
    return Color3.fromRGB(
        c[1] + (LIT[1] - c[1]) * t,
        c[2] + (LIT[2] - c[2]) * t,
        c[3] + (LIT[3] - c[3]) * t
    )
end

-- Obiectul desenat pentru un loc din FairLayout.SPOTS (id), pentru cine vrea sa puna ceva pe el (tabela, tarabele).
function FairScene.SpriteOf(spotId: string): ImageLabel?
    return spriteOf[spotId]
end

-- Unde e un loc din FairLayout.SPOTS si cat de mare e desenul lui (baza la x, y).
function FairScene.Spot(spotId: string): (number, number, number, number)
    for _, spot in FairLayout.SPOTS do
        if spot.id == spotId then
            local art = (Assets.fair :: any)[spot.sprite] :: Assets.Sprite
            return spot.x, spot.y, art.width * spot.scale, art.height * spot.scale
        end
    end
    error(`[FairScene] loc necunoscut: {spotId}`)
end

local function image(
    s: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(s)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Position = UDim2.fromOffset(x, y)
    img.Size = UDim2.fromOffset(w, h)
    img.ZIndex = z
    img.Parent = world
    return img
end

-- Un desen prins de baza (ancora 0.5, 1), colorat de lumina locului.
local function standing(
    s: Assets.Sprite,
    x: number,
    base: number,
    scale: number,
    tint: Color3
): ImageLabel
    local img = image(s, x, base, s.width * scale, s.height * scale, FairScene.ZIndexFor(base))
    img.AnchorPoint = Vector2.new(0.5, 1)
    if Assets.has(s) then
        img.ImageColor3 = tint
    else
        img.BackgroundTransparency = 0
        img.BackgroundColor3 = Theme.COLOR.wood
    end
    return img
end

-- Lumina moale: alb cu alfa care scade lin, colorata aici. Nu pixelata: o aura cu trepte arata a cerc lipit.
local function glow(
    x: number,
    y: number,
    size: number,
    color: Color3,
    transparency: number,
    z: number
): ImageLabel?
    if not Assets.has(Assets.fair.glow) then
        return nil
    end
    local g = Instance.new("ImageLabel")
    g.BackgroundTransparency = 1
    g.Image = Assets.url(Assets.fair.glow)
    g.ImageColor3 = color
    g.ImageTransparency = transparency
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.fromOffset(x, y)
    g.Size = UDim2.fromOffset(size, size * 0.75)
    g.ZIndex = z
    g.Parent = world
    return g
end

-- Eticheta din lume: doar text cu contur, ca pe macheta. `sub` = randul mic de dedesubt ("Opens soon").
local function tag(x: number, y: number, title: string, sub: string?)
    local w = math.ceil(Theme.textWidth(title, Theme.TEXT.small, "display")) + 12
    local t = Widgets.Label(world, title, Theme.TEXT.small, GOLD, "display")
    t.AnchorPoint = Vector2.new(0.5, 0.5)
    t.Position = UDim2.fromOffset(x, if sub ~= nil then y - 8 else y)
    t.Size = UDim2.fromOffset(w, 18)
    t.TextXAlignment = Enum.TextXAlignment.Center
    t.ZIndex = FairScene.Z.LABELS
    Theme.punch(t, 2)
    if sub ~= nil then
        local sw = math.ceil(Theme.textWidth(sub, Theme.TEXT.tiny, "strong")) + 12
        local s = Widgets.Label(world, sub, Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "strong")
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        s.Position = UDim2.fromOffset(x, y + 10)
        s.Size = UDim2.fromOffset(sw, 16)
        s.TextXAlignment = Enum.TextXAlignment.Center
        s.ZIndex = FairScene.Z.LABELS
        Theme.punch(s, 2)
    end
end

-- Fara fundalul copt (desen inca neurcat): iarba, poiana si apa, simplu si intunecat, ca jocul sa mearga oricum.
local function plainGround()
    local size = FairLayout.SIZE
    local g = FairScenery.GROUND
    local grass = image(Assets.grass_tile, g.x, g.y, g.w, g.h, FairScene.Z.GROUND)
    grass.ScaleType = Enum.ScaleType.Tile
    grass.TileSize = UDim2.fromOffset(Assets.grass_tile.width * ART, Assets.grass_tile.height * ART)
    grass.ImageColor3 = Color3.fromRGB(70, 84, 96)
    local river = Instance.new("Frame")
    river.BackgroundColor3 = Color3.fromRGB(16, 30, 52)
    river.BorderSizePixel = 0
    river.Position = UDim2.fromOffset(g.x, FairLayout.WATER_Y)
    river.Size = UDim2.fromOffset(g.w, size.h - FairLayout.WATER_Y + (g.y + g.h - size.h))
    river.ZIndex = FairScene.Z.WATER
    river.Parent = world
    local function ellipse(
        e: { x: number, y: number, rx: number, ry: number },
        color: Color3,
        z: number
    )
        local f = Instance.new("Frame")
        f.BackgroundColor3 = color
        f.BorderSizePixel = 0
        f.Position = UDim2.fromOffset(e.x - e.rx, e.y - e.ry)
        f.Size = UDim2.fromOffset(e.rx * 2, e.ry * 2)
        f.ZIndex = z
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = f
        f.Parent = world
    end
    ellipse(FairLayout.FLOOR, Color3.fromRGB(66, 52, 40), FairScene.Z.FLOOR)
    ellipse(FairLayout.POND, Color3.fromRGB(16, 30, 52), FairScene.Z.POND)
end

local function buildGarlands()
    local function wire(ax: number, ay: number, bx: number, by: number)
        local dx, dy = bx - ax, by - ay
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
        f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = WIRE
        f.BorderSizePixel = 0
        f.ZIndex = FairScene.Z.GARLANDS
        f.Parent = world
    end
    for _, garland in FairScenery.GARLANDS do
        local px, py = garland.ax, garland.ay
        for i, bulb in garland.bulbs do
            wire(px, py, bulb.x, bulb.y)
            px, py = bulb.x, bulb.y
            local color = Color3.fromRGB(bulb.color[1], bulb.color[2], bulb.color[3])
            local b = Instance.new("Frame")
            b.AnchorPoint = Vector2.new(0.5, 0.5)
            b.Position = UDim2.fromOffset(bulb.x, bulb.y + 3)
            b.Size = UDim2.fromOffset(6, 6)
            b.BackgroundColor3 = color
            b.BorderSizePixel = 0
            b.ZIndex = FairScene.Z.GARLANDS + 2
            b.Parent = world
            local halo = glow(bulb.x, bulb.y + 3, 30, color, 0.45, FairScene.Z.GARLANDS + 1)
            if halo ~= nil then
                table.insert(twinkles, { host = halo, phase = i * 1.7 + garland.ax * 0.01 })
            end
        end
        wire(px, py, garland.bx, garland.by)
    end
end

local function buildFires()
    for i, fire in FairScenery.FIRES do
        local halo = glow(fire.x, fire.y, fire.size, FIRE_GLOW, 0.5, FairScene.Z.LIGHT)
        if halo ~= nil then
            table.insert(
                flickers,
                { host = halo, size = fire.size, phase = i * 2.1, base = 0.5, amount = 0.12 }
            )
        end
        for _ = 1, fire.sparks do
            local f = Instance.new("Frame")
            f.AnchorPoint = Vector2.new(0.5, 0.5)
            f.Size = UDim2.fromOffset(3, 3)
            f.BorderSizePixel = 0
            f.BackgroundColor3 = if math.random() < 0.6
                then Color3.fromRGB(255, 196, 120)
                else Color3.fromRGB(255, 148, 80)
            f.ZIndex = FairScene.Z.SPARKS
            f.Visible = false
            f.Parent = world
            -- varsta aleatoare la pornire: altfel toate scanteile ar pleca deodata
            table.insert(
                sparks,
                { f = f, fire = fire, age = math.random() * 1.6, life = 1, vx = 0, vy = 0 }
            )
        end
    end
    for i, lamp in FairScenery.LAMPS do
        local halo = glow(lamp.x, lamp.y, 64, LAMP_GLOW, 0.35, FairScene.ZIndexFor(lamp.base) + 1)
        if halo ~= nil then
            table.insert(
                flickers,
                { host = halo, size = 64, phase = i * 1.3, base = 0.35, amount = 0.04 }
            )
        end
    end
end

local function reSpark(s: Spark)
    local spread = if s.fire.sparks > 10 then 34 else 10
    s.age = 0
    s.life = 0.9 + math.random() * 0.9
    s.vx = (math.random() - 0.5) * 30
    s.vy = -(60 + math.random() * 70)
    s.f.Position = UDim2.fromOffset(s.fire.x + (math.random() - 0.5) * spread, s.fire.y)
    s.f.BackgroundTransparency = 0
    s.f.Visible = true
end

local function animate(dt: number)
    local t = os.clock()
    for _, fl in flickers do
        local k = 1
            + fl.amount
                * (math.sin(t * 7.3 + fl.phase) * 0.6 + math.sin(t * 13.1 + fl.phase * 2) * 0.4)
        fl.host.Size = UDim2.fromOffset(fl.size * k, fl.size * 0.75 * k)
        fl.host.ImageTransparency = math.clamp(fl.base - (k - 1) * 0.8, 0, 1)
    end
    for _, tw in twinkles do
        tw.host.ImageTransparency = 0.35 + 0.3 * (math.sin(t * 1.9 + tw.phase) + 1) / 2
    end
    for _, s in sparks do
        s.age += dt
        if s.age >= s.life then
            reSpark(s)
            continue
        end
        local p = s.f.Position
        s.f.Position = UDim2.fromOffset(
            p.X.Offset + (s.vx + math.sin(t * 3 + s.life * 10) * 12) * dt,
            p.Y.Offset + s.vy * dt
        )
        s.f.BackgroundTransparency = s.age / s.life
    end
end

function FairScene.Build(layer: Frame)
    world = layer
    local g = FairScenery.GROUND
    if Assets.has(Assets.fair.ground) then
        image(Assets.fair.ground, g.x, g.y, g.w, g.h, FairScene.Z.GROUND)
    else
        plainGround()
    end

    -- obiectele, cu adancimea dupa baza si lumina locului lor
    for _, spot in FairLayout.SPOTS do
        local art = (Assets.fair :: any)[spot.sprite] :: Assets.Sprite?
        if art ~= nil then
            local img = standing(art, spot.x, spot.y, spot.scale, FairScene.LitTint(spot.x, spot.y))
            img.Name = spot.id
            spriteOf[spot.id] = img
        end
    end
    -- padurea din jur
    for _, tree in FairScenery.TREES do
        local art = (Assets.props :: any)[tree.sprite] :: Assets.Sprite?
        if art ~= nil and Assets.has(art) then
            standing(art, tree.x, tree.y, ART, FairScene.LitTint(tree.x, tree.y, TREE_COLD))
        end
    end
    buildGarlands()
    buildFires()

    -- etichetele marginilor care se deschid mai tarziu si a barcii spre casa
    for _, edge in FairLayout.EDGES do
        if not edge.open then
            tag(edge.x, edge.y, edge.label, Strings.FAIR_OPENS_SOON)
        end
    end
    local fx, fy, _, fh = FairScene.Spot("ferry")
    tag(fx, fy - fh - 16, Strings.FAIR_FERRY_TAG, nil)

    RunService.PreRender:Connect(animate)
end

return FairScene
