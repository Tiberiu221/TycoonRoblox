--!strict
-- DOAR randare: deriva pozitiile din seed si scrie Position pe PreRender, cu pool de Frame-uri [DECIZII D05, D13]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RiverSim = require(ReplicatedStorage.Shared.Modules.RiverSim)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local GoodArt = require(script.Parent.Parent.UI.GoodArt)
local CatchFloat = require(ReplicatedStorage.Shared.Modules.CatchFloat)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)
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
-- [D55, D65] marfa pe care plasele tale inca n-o prind (scrap pana la Fifth Net, minereu pana la Tenth Net); nil = doar
-- busteni
local promised: string? = "scrap"

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

-- [D70, pasul k1] harta pe care curge raul: satul (1) sau barajul (2), data la Init
local world = 1

local function buildScene(layers: SceneArt.Layers)
    SceneArt.BuildBackground(layers, world)
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

-- [D53] CE PLUTESTE MAI IN LARG: ce plasele tale inca nu pot prinde, ca plasa urmatoare sa aiba ceva de
-- promis. [D55] Scrap-ul, pana ai plasa din larg care il prinde (Fifth Net); apoi busteni. Pana in D53 erau
-- lazile coloniei, cu alte viteze, pe aceeasi banda pe care vin acum bustenii spre plase.
local function farGood(objId: number): string
    local good = promised
    if good ~= nil then
        return if objId % 3 == 0 then "driftwood" else good
    end
    return "driftwood"
end

local function styleFar(frame: Frame, good: string)
    -- [D65] desenul marfii cand e urcat, altfel al perechii din Era 1 (UI/GoodArt)
    local sprite = GoodArt.icon(good) or Assets.goods.driftwood
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
            -- [D70] la baraj, decorul din larg apare la piciorul deversorului (fata zidului)
            local x = CatchFloat.SPAWN_X_BY_WORLD[world] + (now - obj.spawnAt) * CatchFloat.SPEED
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

-- [D55, D65] Ce promite raul acum, din TycoonState: marfa urmatoarei linii, cat inca n-ai plasa care o prinde.
function RiverRenderController.SetPromise(good: string?)
    if good == promised then
        return
    end
    promised = good
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
    World: number?,
})
    world = WorldConfig.sanitize(deps.World)
    local base = (RiverConfig.WORLDS :: any)[world]
    cfg = base
    buildScene(deps.Layers)
    deps.RiverConfig.OnClientEvent:Connect(function(config: { [string]: any })
        baseSeed = config.seed
        -- [D70] configul hartii tale (latimea lumii barajului e 3385), cu ritmul trimis de server
        local c = table.clone(base) :: any
        c.SPAWNS_PER_WINDOW = config.spawnsPerWindow or base.SPAWNS_PER_WINDOW
        cfg = c
        table.clear(scheduleCache)
    end)
    RunService.PreRender:Connect(render)
end

return RiverRenderController
