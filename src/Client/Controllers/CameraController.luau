--!strict
-- Camera 2D: scara se calculeaza din ecranul REAL, nu dintr-o rezolutie fixa [DECIZII D06, revizuit]
-- Pe telefon (ecran mic) se vede mai putina lume, dar sprite-urile raman lizibile; pe desktop se
-- vede mai mult. Vechea varianta scala toata lumea la o cutie de 1920x1080 si pe mobil ieseau
-- sprite-uri minuscule.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)

-- Cat de mare e un pixel de lume pe ecran. Podeaua tine sprite-urile citibile pe telefon.
local REFERENCE_HEIGHT = 900 -- inaltime de lume vizibila pe un ecran mare
local MIN_SCALE = 0.85 -- sub asta, personajele devin ilizibile pe mobil
local MAX_SCALE = 2.2

local CameraController = {}
local camX, camY = 0, 0
local scale = 1
local visibleW, visibleH = RiverConfig.SCREEN_WIDTH, RiverConfig.SCREEN_HEIGHT
local scroll: Frame
local parallax: Frame
local camera = Workspace.CurrentCamera
local scaleObjects: { UIScale } = {}
local onScaleChanged: { (number) -> () } = {}

local function recompute()
    local vp = camera.ViewportSize
    scale = math.clamp(vp.Y / REFERENCE_HEIGHT, MIN_SCALE, MAX_SCALE)
    visibleW = vp.X / scale
    visibleH = vp.Y / scale
    for _, s in scaleObjects do
        s.Scale = scale
    end
    for _, fn in onScaleChanged do
        fn(scale)
    end
end

function CameraController.Scale(): number
    return scale
end

function CameraController.VisibleSize(): (number, number)
    return visibleW, visibleH
end

function CameraController.OnScaleChanged(fn: (number) -> ())
    table.insert(onScaleChanged, fn)
    fn(scale)
end

-- Structura corecta: Viewport (nescalat, taie la marginea ecranului) > Canvas (scalat) > straturi.
-- UIScale scaleaza SI obiectul pe care e pus, nu doar copiii; daca era pe un cadru de marimea
-- ecranului, pânza se micsora sub ecran si se vedea fundalul pe margini.
function CameraController.Init(
    deps: { WorldGui: Frame }
): { Fixed: Frame, Parallax: Frame, Scroll: Frame }
    local viewport = Instance.new("Frame")
    viewport.Name = "Viewport"
    viewport.BackgroundTransparency = 1
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.ClipsDescendants = true
    viewport.Parent = deps.WorldGui

    local canvas = Instance.new("Frame")
    canvas.Name = "WorldCanvas"
    canvas.BackgroundTransparency = 1
    canvas.Size = UDim2.fromOffset(RiverConfig.WORLD_WIDTH, RiverConfig.WORLD_HEIGHT)
    canvas.Parent = viewport

    local uiScale = Instance.new("UIScale")
    uiScale.Parent = canvas
    table.insert(scaleObjects, uiScale)

    local function layer(name: string, z: number): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.BackgroundTransparency = 1
        f.Size = UDim2.fromScale(1, 1)
        f.ZIndex = z
        f.Parent = canvas
        return f
    end
    local fixed = layer("Fixed", 0)
    parallax = layer("Parallax", 1)
    scroll = layer("Scroll", 2)

    recompute()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
    return { Fixed = fixed, Parallax = parallax, Scroll = scroll }
end

local focus: (() -> (number?, number?))? = nil

function CameraController.SetFocus(getter: (() -> (number?, number?))?)
    focus = getter
end

function CameraController.HasFocus(): boolean
    return focus ~= nil
end

function CameraController.Follow(worldX: number, worldY: number)
    if focus ~= nil then
        local fx, fy = focus()
        if fx ~= nil and fy ~= nil then
            worldX, worldY = fx, fy
        else
            focus = nil
        end
    end
    -- clamp pe cat de multa lume incape efectiv pe ecranul asta
    local maxX = math.max(0, RiverConfig.WORLD_WIDTH - visibleW)
    local maxY = math.max(0, RiverConfig.WORLD_HEIGHT - visibleH)
    camX = math.clamp(worldX - visibleW / 2, 0, maxX)
    camY = math.clamp(worldY - visibleH / 2, 0, maxY)
    scroll.Position = UDim2.fromOffset(-camX, -camY)
    parallax.Position = UDim2.fromOffset(-camX * 0.4, -camY * 0.4)
end

function CameraController.WorldOrigin(): (number, number)
    return camX, camY
end

-- Margine generoasa: obiectele intra in scena inainte sa fie nevoie de ele, nu "pop" la margine
local CULL_MARGIN = 220

function CameraController.IsVisible(x: number, y: number, w: number, h: number): boolean
    return x + w > camX - CULL_MARGIN
        and x < camX + visibleW + CULL_MARGIN
        and y + h > camY - CULL_MARGIN
        and y < camY + visibleH + CULL_MARGIN
end

return CameraController
