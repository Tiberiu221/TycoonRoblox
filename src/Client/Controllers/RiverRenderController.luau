--!strict
-- DOAR randare: deriva pozitiile din seed si scrie Position pe PreRender, cu pool de Frame-uri [DECIZII D05, D13]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RiverSim = require(ReplicatedStorage.Shared.Modules.RiverSim)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local CatchFloat = require(ReplicatedStorage.Shared.Modules.CatchFloat)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local SceneArt = require(script.Parent.SceneArt)
local CameraController = require(script.Parent.CameraController)

local POOL_SIZE = 400 -- plafonul dur din DECIZII D05
-- [D53] Decorul din larg e mai mic decat bustenii de langa plase (x0.5): e "mai departe", si asa cele doua
-- linii de curent nu se ating (504-528 fata de 533-572).
local FAR_SCALE = 0.35

local RiverRenderController = {}
local baseSeed: number? = nil
local cfg: RiverSim.Config = RiverConfig :: any
local visibleCount = 0

-- Fiecare obiect primeste ACELASI Frame cat timp e vizibil (asociere stabila pe id).
-- Fara asta, ordinea de parcurgere a tabelelor schimba atribuirea de la un cadru la altul
-- si sprite-urile clipesc/dispar pentru o fractiune de secunda.
local frameByObject: { [number]: Frame } = {}
local freeFrames: { Frame } = {}
local styledGoodOf: { [number]: string } = {}
local lanes = 1 -- benzile atinse de plase: decid ce plutese mai in larg

local hidden: { [number]: boolean } = {}
local scheduleCache: { [number]: { RiverSim.RiverObject } } = {}
local pool: { Frame } = table.create(POOL_SIZE)

local function schedule(windowIndex: number): { RiverSim.RiverObject }
    local cached = scheduleCache[windowIndex]
    if cached == nil then
        cached = RiverSim.schedule(baseSeed :: number, windowIndex, cfg)
        scheduleCache[windowIndex] = cached
        scheduleCache[windowIndex - 3] = nil
    end
    return cached
end

local function buildScene(layers: SceneArt.Layers)
    SceneArt.BuildBackground(layers)
    local layer = Instance.new("Frame")
    layer.Name = "RiverLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 3
    layer.Parent = layers.Scroll
    for i = 1, POOL_SIZE do
        local f = Instance.new("Frame")
        f.Name = "Obj"
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BackgroundTransparency = 1
        f.Size = UDim2.fromOffset(RiverConfig.OBJECT_WIDTH, RiverConfig.OBJECT_HEIGHT)
        f.BorderSizePixel = 0
        f.ZIndex = 3
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.BackgroundTransparency = 1
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
        icon.Size = UDim2.fromScale(1, 1)
        icon.ZIndex = 3
        icon.Parent = f
        f.Visible = false
        f.Parent = layer
        pool[i] = f
        table.insert(freeFrames, f)
    end
end

local function acquireFrame(objId: number): Frame?
    local existing = frameByObject[objId]
    if existing ~= nil then
        return existing
    end
    local frame = table.remove(freeFrames)
    if frame == nil then
        return nil -- pool epuizat: obiectul nu se deseneaza in acest cadru
    end
    frameByObject[objId] = frame
    return frame
end

local function releaseFrame(objId: number)
    local frame = frameByObject[objId]
    if frame == nil then
        return
    end
    frameByObject[objId] = nil
    styledGoodOf[objId] = nil
    if frame.Visible then
        frame.Visible = false
    end
    table.insert(freeFrames, frame)
end

local seenThisFrame: { [number]: boolean } = {}

-- [D53] CE PLUTESTE MAI IN LARG: bunurile pe care plasele tale inca nu le pot prinde (resturile cer a doua
-- banda, cioburile a treia -- TycoonConfig.GOODS.minLanes), ca fiecare plasa mai departata sa aiba ceva de
-- promis; cand le prinzi pe toate, busteni si stuf. Pana acum erau lazile coloniei, cu alte viteze, pe
-- aceeasi banda pe care vin acum bustenii spre plase.
local function farGood(objId: number): string
    if lanes < 2 then
        return if objId % 2 == 0 then "scrap" else "shards"
    elseif lanes < 3 then
        return "shards"
    end
    return if objId % 3 == 0 then "reeds" else "driftwood"
end

local function styleFar(frame: Frame, good: string)
    local sprite = (Assets.goods :: any)[good] or Assets.goods.driftwood
    local w = sprite.width * Assets.PIXEL_SCALE * FAR_SCALE
    local h = sprite.height * Assets.PIXEL_SCALE * FAR_SCALE
    frame.Size = UDim2.fromOffset(math.round(w), math.round(h))
    local icon = frame:FindFirstChild("Icon") :: ImageLabel?
    if icon ~= nil then
        icon.Image = if Assets.has(sprite) then Assets.url(sprite) else ""
    end
end

local function render()
    if baseSeed == nil then
        return
    end
    local now = Workspace:GetServerTimeNow()
    table.clear(seenThisFrame)
    local used = 0
    local y = TycoonConfig.FAR_CURRENT_Y

    for _, windowIndex in RiverSim.activeWindows(now, cfg) do
        for _, obj in schedule(windowIndex) do
            if hidden[obj.id] then
                continue
            end
            -- Decor DOAR pe curentul din larg (banda 1 = FAR_CURRENT_Y); bustenii care vor fi prinsi vin
            -- pe curentul de langa plase (CatchFloat). Aceeasi viteza ca ei, ca nimic sa nu depaseasca nimic.
            if obj.lane ~= 1 or now < obj.spawnAt then
                continue
            end
            local x = CatchFloat.SPAWN_X + (now - obj.spawnAt) * CatchFloat.SPEED
            if x > cfg.WORLD_WIDTH + cfg.OBJECT_WIDTH then
                continue
            end
            local good = farGood(obj.id)
            local w, h = 40, 20
            local bob = math.sin(now * 2.2 + obj.id) * 1.5
            if not CameraController.IsVisible(x - w / 2, y - h / 2, w, h) then
                continue
            end
            local frame = acquireFrame(obj.id)
            if frame == nil then
                continue
            end
            seenThisFrame[obj.id] = true
            used += 1
            if styledGoodOf[obj.id] ~= good then
                styledGoodOf[obj.id] = good
                styleFar(frame, good)
            end
            frame.Position = UDim2.fromOffset(math.round(x), math.round(y + bob))
            if not frame.Visible then
                frame.Visible = true
            end
        end
    end

    -- elibereaza doar ce a iesit efectiv din cadru
    for objId in frameByObject do
        if not seenThisFrame[objId] then
            releaseFrame(objId)
        end
    end
    visibleCount = used
end

function RiverRenderController.VisibleCount(): number
    return visibleCount
end

-- [D53] Benzile atinse de plase, din TycoonState: o plasa noua schimba ce plutese mai in larg.
function RiverRenderController.SetLanes(newLanes: number?)
    local value = newLanes or 1
    if value == lanes then
        return
    end
    lanes = value
    table.clear(styledGoodOf)
end

function RiverRenderController.Hide(objectId: number)
    hidden[objectId] = true
    releaseFrame(objectId)
end

-- Raul e decor ambiental: platformele prind bunuri pe un ritm calculat pe server (TycoonMath), nu mai
-- exista o plasa care ciocneste cu un obiect anume de-al RiverSim-ului, deci nu mai e nimic de "ascuns"
-- cand se prinde ceva. ObjectCaught a disparut o data cu asta [F0 spec 1.4]. Ce se prinde vine pe
-- curentul de langa plase, desenat de NetController [D53].
function RiverRenderController.Init(deps: {
    Layers: SceneArt.Layers,
    RiverConfig: RemoteEvent,
})
    buildScene(deps.Layers)
    deps.RiverConfig.OnClientEvent:Connect(function(config: { [string]: any })
        baseSeed = config.seed
        local c = table.clone(RiverConfig) :: any
        c.SPAWNS_PER_WINDOW = config.spawnsPerWindow or RiverConfig.SPAWNS_PER_WINDOW
        cfg = c
        table.clear(scheduleCache)
    end)
    RunService.PreRender:Connect(render)
end

return RiverRenderController
