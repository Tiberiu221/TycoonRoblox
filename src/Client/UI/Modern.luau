--!strict
-- [D70] SATUL VECHI SE MODERNIZEAZA IN ERA 3, pe client. Treapta vine din ModernMath (citita din stare de
-- ModernController, sau din fotografia gazdei in balci); aici se alege doar DESENUL: varianta moderna a unei cladiri
-- (treapta 3), stratul cu geamuri peste o casa (4) sau aprins (5), luminile unei cladiri moderne (5), caruciorul de
-- fier in locul roabei (2). Orice desen inca neurcat (id 0) lasa desenul de azi: nimic nu se strica.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local ModernConfig = require(ReplicatedStorage.Shared.Config.ModernConfig)
local ModernMath = require(ReplicatedStorage.Shared.Modules.ModernMath)

local Modern = {}

-- Treapta satului de acasa (0..5). O scrie doar ModernController; macheta din balci da treapta gazdei explicit.
Modern.stage = 0

type Cell = { x: number, y: number, w: number, h: number }

local tycoon = Assets.tycoon :: any
local keyOf: { [any]: string }? = nil

-- Cheia unui desen din Assets.tycoon (desenele sunt tabele unice, deci se recunosc dupa identitate).
local function spriteKey(sprite: Assets.Sprite): string?
    local map = keyOf
    if map == nil then
        local built: { [any]: string } = {}
        for key, value in tycoon do
            if type(value) == "table" and built[value] == nil then
                built[value] = key
            end
        end
        keyOf = built
        map = built
    end
    return map[sprite]
end

local function has(sprite: any): boolean
    return sprite ~= nil and Assets.has(sprite)
end

-- Desenul de azi sau varianta lui moderna (tabla si caramida), dupa treapta. Doar cladirile satului vechi au variante.
function Modern.variant(sprite: Assets.Sprite, stage: number?): Assets.Sprite
    if not ModernMath.has(stage or Modern.stage, "brick") then
        return sprite
    end
    local key = spriteKey(sprite)
    local modern = if key ~= nil then ModernConfig.MODERN_OF[key] else nil
    local art = if modern ~= nil then tycoon[modern] else nil
    return if has(art) then art else sprite
end

-- Pune (sau scoate) peste `host` un strat de aceeasi marime cu el, decupat din `sheet` pe celula `cell`. Copilul se
-- deseneaza peste parinte, deci ce e desenat in fata casei in foaia ei ramane in fata si in strat.
local function overlay(host: GuiObject, name: string, sheet: Assets.Sprite?, cell: Cell?)
    local existing = host:FindFirstChild(name)
    if sheet == nil or cell == nil or not has(sheet) then
        if existing ~= nil then
            existing:Destroy()
        end
        return
    end
    local img: ImageLabel
    if existing ~= nil and existing:IsA("ImageLabel") then
        img = existing
    else
        img = Instance.new("ImageLabel")
        img.Name = name
        img.BackgroundTransparency = 1
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.Size = UDim2.fromScale(1, 1)
        img.ZIndex = host.ZIndex
        img.Parent = host
    end
    img.Image = Assets.url(sheet)
    img.ImageRectOffset = Vector2.new(cell.x, cell.y)
    img.ImageRectSize = Vector2.new(cell.w, cell.h)
end

-- Geamurile unei case (desenul `hut`, cu marimea lui pe `host`): sticla de la treapta 4, aprinse de la treapta 5.
function Modern.windows(host: GuiObject, hut: Assets.Sprite, stage: number?)
    local s = stage or Modern.stage
    local key = spriteKey(hut)
    local cell: Cell? = if key ~= nil then ModernConfig.WINDOW_CELLS[key] else nil
    local sheet = if ModernMath.has(s, "lights")
        then tycoon.windows_lit
        elseif ModernMath.has(s, "glass") then tycoon.windows_glass
        else nil
    overlay(host, "ModernWindows", sheet, cell)
end

-- Luminile unei cladiri moderne (becurile firmei, lampile), de la treapta 5. `building` e desenul pus azi pe `host`.
function Modern.lights(host: GuiObject, building: Assets.Sprite, stage: number?)
    local s = stage or Modern.stage
    local key = spriteKey(building)
    local cell: Cell? = if key ~= nil then ModernConfig.MODERN_LIT_CELLS[key] else nil
    overlay(
        host,
        "ModernLights",
        if ModernMath.has(s, "lights") then tycoon.modern_lit else nil,
        cell
    )
end

-- [verificatorul A4] treapta citita doar de carucior: la baraj (lumea 2) oamenii imping caruciorul de fier, dar casele lor
-- de imprumut nu primesc geamurile satului modernizat (Modern.stage ramane 0 acolo)
Modern.cartStage = nil :: number?

-- Roaba oamenilor: caruciorul de fier de la treapta 2 (aceeasi foaie, aceleasi cadre).
function Modern.barrow(stage: number?): Assets.Sprite
    local iron = tycoon.barrow_iron
    if ModernMath.has(stage or Modern.cartStage or Modern.stage, "carts") and has(iron) then
        return iron
    end
    return Assets.tycoon.barrow
end

return Modern
