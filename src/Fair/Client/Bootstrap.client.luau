--!strict
-- [D60] Clientul balciului de seara (place-ul al doilea). Deocamdata SCHELETUL: deseneaza locul intreg, exact din
-- FairLayout -- aceleasi pozitii pe care le verifica testul de asezare --, si are butonul de intors acasa. Mersul,
-- oamenii, cardurile, scena cu clasamente si roata vin in pasii urmatori ai planului D60.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local Net = require(ReplicatedStorage.Net.Net)
local Widgets = require(script.Parent.UI.Widgets)

local NIGHT = Color3.fromRGB(18, 24, 44) -- cerul de seara, in care se scufunda tot
local NIGHT_TINT = Color3.fromRGB(120, 132, 176) -- ce e departe de felinare
local WARM_TINT = Color3.fromRGB(255, 226, 186) -- ce sta in lumina
local WATER = Color3.fromRGB(16, 30, 52)

local gui = Instance.new("ScreenGui")
gui.Name = "Fair"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local sky = Instance.new("Frame")
sky.Name = "Night"
sky.BackgroundColor3 = NIGHT
sky.BorderSizePixel = 0
sky.Size = UDim2.fromScale(1, 1)
sky.Parent = gui

local world = Instance.new("Frame")
world.Name = "World"
world.BackgroundTransparency = 1
world.AnchorPoint = Vector2.new(0.5, 0.5)
world.Position = UDim2.fromScale(0.5, 0.5)
world.Size = UDim2.fromOffset(FairLayout.SIZE.w, FairLayout.SIZE.h)
world.Parent = sky
local worldScale = Instance.new("UIScale")
worldScale.Parent = world

local function image(
    sprite: Assets.Sprite,
    x: number,
    y: number,
    w: number,
    h: number,
    z: number
): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Position = UDim2.fromOffset(x, y)
    img.Size = UDim2.fromOffset(w, h)
    img.ZIndex = z
    img.Parent = world
    return img
end

local function tiled(sprite: Assets.Sprite, img: ImageLabel)
    img.ScaleType = Enum.ScaleType.Tile
    img.TileSize =
        UDim2.fromOffset(sprite.width * Assets.PIXEL_SCALE, sprite.height * Assets.PIXEL_SCALE)
end

local function ellipse(
    x: number,
    y: number,
    rx: number,
    ry: number,
    color: Color3,
    z: number
): Frame
    local f = Instance.new("Frame")
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.Position = UDim2.fromOffset(x - rx, y - ry)
    f.Size = UDim2.fromOffset(rx * 2, ry * 2)
    f.ZIndex = z
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = f
    f.Parent = world
    return f
end

-- iarba de seara, poiana de pamant batatorit, iazul si raul pe care ai venit
local grass = image(Assets.grass_tile, 0, 0, FairLayout.SIZE.w, FairLayout.WATER_Y, 1)
tiled(Assets.grass_tile, grass)
grass.ImageColor3 = NIGHT_TINT

local f = FairLayout.FLOOR
local floor = image(Assets.tile_fair, f.x - f.rx, f.y - f.ry, f.rx * 2, f.ry * 2, 2)
tiled(Assets.tile_fair, floor)
floor.ImageColor3 = WARM_TINT
local floorCorner = Instance.new("UICorner")
floorCorner.CornerRadius = UDim.new(0.5, 0)
floorCorner.Parent = floor

local p = FairLayout.POND
ellipse(p.x, p.y, p.rx, p.ry, WATER, 3)

local river = Instance.new("Frame")
river.BackgroundColor3 = WATER
river.BorderSizePixel = 0
river.Position = UDim2.fromOffset(0, FairLayout.WATER_Y)
river.Size = UDim2.fromOffset(FairLayout.SIZE.w, FairLayout.SIZE.h - FairLayout.WATER_Y)
river.ZIndex = 1
river.Parent = world

-- obiectele, ordonate pe adancime: ce e mai jos acopera ce e mai sus, ca peste tot in joc
local center = FairLayout.CENTER
for _, spot in FairLayout.SPOTS do
    local art = (Assets.fair :: any)[spot.sprite] :: Assets.Sprite?
    if art == nil or not Assets.has(art) then
        continue
    end
    local sprite = art :: Assets.Sprite
    local w, h = sprite.width * spot.scale, sprite.height * spot.scale
    local img = image(sprite, spot.x - w / 2, spot.y - h, w, h, 5 + math.floor(spot.y / 64))
    -- lumina calda langa vatra, rece spre margini; pâlpâirea o face pasul cu luminile
    local d = math.clamp(math.sqrt((spot.x - center.x) ^ 2 + (spot.y - center.y) ^ 2) / 700, 0, 1)
    img.ImageColor3 = WARM_TINT:Lerp(NIGHT_TINT, d)
end

-- tot balciul pe ecran, oricat de mare e fereastra
local camera = Workspace.CurrentCamera
local function fit()
    local vp = camera.ViewportSize
    worldScale.Scale = math.min(vp.X / FairLayout.SIZE.w, vp.Y / FairLayout.SIZE.h) * 0.96
end
fit()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

-- barca spre casa
local hud = Instance.new("Frame")
hud.Name = "Hud"
hud.BackgroundTransparency = 1
hud.Size = UDim2.fromScale(1, 1)
hud.ZIndex = 50
hud.Parent = gui
local rowHome = Net.Get("RowHome")
local home = Widgets.Button(hud, {
    text = Strings.FAIR_ROW_HOME,
    width = 200,
    height = 48,
    z = 51,
    onClick = function()
        rowHome:FireServer()
    end,
})
home.AnchorPoint = Vector2.new(1, 0)
home.Position = UDim2.new(1, -16, 0, 16)

gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
