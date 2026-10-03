--!strict
-- Camera 2D: scara se calculeaza din ecranul REAL, nu dintr-o rezolutie fixa [DECIZII D06, revizuit]
-- Pe telefon (ecran mic) se vede mai putina lume, dar sprite-urile raman lizibile; pe desktop se
-- vede mai mult. Vechea varianta scala toata lumea la o cutie de 1920x1080 si pe mobil ieseau
-- sprite-uri minuscule.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldMap = require(ReplicatedStorage.Shared.Modules.WorldMap)

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
-- [D60] marimea lumii: harta satului, sau alta lume (balciul) data la Init. O lume data la Init, mai mica decat
-- ecranul, sta in mijlocul lui; harta satului ramane cum a fost (lipita de colt).
local worldW, worldH = RiverConfig.WORLD_WIDTH, RiverConfig.WORLD_HEIGHT
local centerSmall = false
-- [D61, partea 2] coltul lumii in care se plimba camera. Satul vizitat din balci e desenat in acelasi strat, departe
-- in dreapta hartii balciului: cat esti in vizita, camera sta intre marginile LUI (SetWorld), apoi se intoarce.
local worldX0, worldY0 = 0, 0
local homeW, homeH = worldW, worldH

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
-- [D60] Portitele balciului (implicit = satul, neschimbat): WorldWidth/WorldHeight = marimea lumii in care se
-- plimba camera, PlotOrigin = unde sta terenul. [D70, pasul k1] `World` = harta satului sau a barajului: marimea ei vine din
-- RiverConfig.WORLDS (barajul are 3385 px). Fara el, satul. Ramane fixata in colt, ca satul (`centerSmall` e al balciului).
function CameraController.Init(deps: {
    WorldGui: Frame,
    WorldWidth: number?,
    WorldHeight: number?,
    PlotOrigin: { x: number, y: number }?,
    World: number?,
}): { Fixed: Frame, Parallax: Frame, Scroll: Frame, Plot: Frame }
    local _, cfg = WorldMap.forWorld(deps.World)
    worldW = deps.WorldWidth or cfg.WORLD_WIDTH
    worldH = deps.WorldHeight or cfg.WORLD_HEIGHT
    homeW, homeH = worldW, worldH
    centerSmall = deps.WorldWidth ~= nil or deps.WorldHeight ~= nil
    local origin = deps.PlotOrigin or TycoonConfig.PLOT_ORIGIN
    local viewport = Instance.new("Frame")
    viewport.Name = "Viewport"
    viewport.BackgroundTransparency = 1
    viewport.Size = UDim2.fromScale(1, 1)
    viewport.ClipsDescendants = true
    viewport.Parent = deps.WorldGui

    local canvas = Instance.new("Frame")
    canvas.Name = "WorldCanvas"
    canvas.BackgroundTransparency = 1
    canvas.Size = UDim2.fromOffset(worldW, worldH)
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

    -- [B5] Terenul jucatorului: un singur Frame la PLOT_ORIGIN, in care platformele, plasele,
    -- debarcaderul, alergatorii, cladirile si decorul de zona se aseaza in coordonate LOCALE
    -- terenului. Azi PLOT_ORIGIN = (0,0), deci lume = local; conventia exista pentru cand vor
    -- fi mai multe terenuri pe acelasi server (aria R) fara sa rescriem pozitiile copiilor.
    local plot = Instance.new("Frame")
    plot.Name = "Plot"
    plot.BackgroundTransparency = 1
    plot.Position = UDim2.fromOffset(origin.x, origin.y)
    plot.Size = UDim2.fromOffset(0, 0) -- ancora pura; copiii nu sunt taiati (ClipsDescendants=false)
    -- 5, nu 3: pontonul de scanduri se deseneaza la 4 (ca sa acopere spuma malului, care e la 3),
    -- iar la 3 platformele si plasele ajungeau SUB scanduri -- se vedea doar varful placutelor
    -- [vazut in Studio, 2026-09-12]. Terenul construit sta mereu peste sol, niciodata invers.
    plot.ZIndex = 5
    plot.Parent = scroll

    recompute()
    camera:GetPropertyChangedSignal("ViewportSize"):Connect(recompute)
    return { Fixed = fixed, Parallax = parallax, Scroll = scroll, Plot = plot }
end

-- [D61, partea 2] Camera trece pe alta lume din acelasi strat (dreptunghiul ei, in coordonatele stratului).
function CameraController.SetWorld(x0: number, y0: number, w: number, h: number)
    worldX0, worldY0, worldW, worldH = x0, y0, w, h
end

-- ...si inapoi pe lumea data la Init.
function CameraController.ResetWorld()
    worldX0, worldY0, worldW, worldH = 0, 0, homeW, homeH
end

local focus: (() -> (number?, number?))? = nil
-- Smucitura de la o cumparare mare: un decalaj mic care se stinge, aplicat LUMII, nu HUD-ului.
-- (Prima varianta misca panza HUD: sareau monedele si butoanele, iar malul statea pe loc --
-- exact invers decat trebuie.) Se aduna peste pozitia calculata de Follow, deci nu se bate cap in
-- cap cu urmarirea personajului.
local punchX, punchY, punchUntil, punchAt = 0, 0, 0, 0
local PUNCH_SECONDS = 0.22

-- `mag` in pixeli de lume; directia e aleatoare, ca doua cumparari la rand sa nu arate identic.
function CameraController.Punch(mag: number?)
    local m = mag or 8
    local angle = math.random() * math.pi * 2
    punchX, punchY = math.cos(angle) * m, math.sin(angle) * m
    punchAt = os.clock()
    punchUntil = punchAt + PUNCH_SECONDS
end

function CameraController.SetFocus(getter: (() -> (number?, number?))?)
    focus = getter
end

function CameraController.HasFocus(): boolean
    return focus ~= nil
end

-- [2026-09-30] Camera e tinuta chiar de getter-ul dat (DriftController afla asa ca i-a luat-o altcineva).
function CameraController.Holds(getter: () -> (number?, number?)): boolean
    return focus == getter
end

-- [D62] Lasa camera doar daca inca o tii TU: cine a luat-o intre timp (tutorialul, o ceremonie) n-o pierde.
function CameraController.ReleaseFocus(getter: () -> (number?, number?))
    if focus == getter then
        focus = nil
    end
end

-- Coltul camerei cand urmareste punctul (x, y) din lume, fara focus si fara smucitura: aceeasi socoteala ca Follow.
-- [2026-09-30] "Look (V)" judeca dupa el daca un loc se vede de unde stai, nu dupa o privire in curs.
function CameraController.OriginFor(worldX: number, worldY: number): (number, number)
    -- clamp pe cat de multa lume incape efectiv pe ecranul asta
    local maxX = math.max(0, worldW - visibleW)
    local maxY = math.max(0, worldH - visibleH)
    local x = if centerSmall and worldW < visibleW
        then worldX0 + (worldW - visibleW) / 2
        else worldX0 + math.clamp(worldX - worldX0 - visibleW / 2, 0, maxX)
    local y = if centerSmall and worldH < visibleH
        then worldY0 + (worldH - visibleH) / 2
        else worldY0 + math.clamp(worldY - worldY0 - visibleH / 2, 0, maxY)
    return x, y
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
    camX, camY = CameraController.OriginFor(worldX, worldY)
    -- smucitura se stinge liniar; `camX/camY` raman curate, ca IsVisible/WorldOrigin sa nu
    -- tresara si ele odata cu efectul
    local ox, oy = 0, 0
    local now = os.clock()
    if now < punchUntil then
        local k = 1 - (now - punchAt) / PUNCH_SECONDS
        ox, oy = punchX * k, punchY * k
    end
    scroll.Position = UDim2.fromOffset(-camX + ox, -camY + oy)
    parallax.Position = UDim2.fromOffset(-camX * 0.4 + ox * 0.4, -camY * 0.4 + oy * 0.4)
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
