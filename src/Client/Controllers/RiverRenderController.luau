--!strict
-- DOAR randare: deriva pozitiile din seed si scrie Position pe PreRender, cu pool de Frame-uri [DECIZII D05, D13]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RiverSim = require(ReplicatedStorage.Shared.Modules.RiverSim)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local SceneArt = require(script.Parent.SceneArt)
local CameraController = require(script.Parent.CameraController)

local POOL_SIZE = 400 -- plafonul dur din DECIZII D05
local TIER_COLORS: { [string]: Color3 } = {}
for _, tier in RiverConfig.TIERS do
    TIER_COLORS[tier.id] = Color3.fromRGB(tier.rgb[1], tier.rgb[2], tier.rgb[3])
end

local RiverRenderController = {}
local baseSeed: number? = nil
local cfg: RiverSim.Config = RiverConfig :: any
local visibleCount = 0

-- Fiecare obiect primeste ACELASI Frame cat timp e vizibil (asociere stabila pe id).
-- Fara asta, ordinea de parcurgere a tabelelor schimba atribuirea de la un cadru la altul
-- si sprite-urile clipesc/dispar pentru o fractiune de secunda.
local frameByObject: { [number]: Frame } = {}
local freeFrames: { Frame } = {}
local styledTierOf: { [number]: string } = {}

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
        f.Size = UDim2.fromOffset(RiverConfig.OBJECT_WIDTH, RiverConfig.OBJECT_HEIGHT)
        f.BorderSizePixel = 0
        f.ZIndex = 3
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
    styledTierOf[objId] = nil
    if frame.Visible then
        frame.Visible = false
    end
    table.insert(freeFrames, frame)
end

local seenThisFrame: { [number]: boolean } = {}

local function render()
    if baseSeed == nil then
        return
    end
    local now = Workspace:GetServerTimeNow()
    table.clear(seenThisFrame)
    local used = 0

    for _, windowIndex in RiverSim.activeWindows(now, cfg) do
        for _, obj in schedule(windowIndex) do
            if hidden[obj.id] then
                continue
            end
            local box = RiverSim.box(obj, cfg, now)
            if
                box == nil or not CameraController.IsVisible(box.x, box.y, box.width, box.height)
            then
                continue
            end
            local frame = acquireFrame(obj.id)
            if frame == nil then
                continue
            end
            seenThisFrame[obj.id] = true
            used += 1
            if styledTierOf[obj.id] ~= obj.tier then
                styledTierOf[obj.id] = obj.tier
                SceneArt.StyleCrate(frame, TIER_COLORS[obj.tier] or TIER_COLORS.common, obj.tier)
            end
            frame.Position = UDim2.fromOffset(box.x, box.y)
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

function RiverRenderController.Hide(objectId: number)
    hidden[objectId] = true
    releaseFrame(objectId)
end

-- Raul e acum doar decor ambiental: platformele prind bunuri pe un ritm calculat pe server
-- (TycoonMath), nu mai exista o plasa care ciocneste cu un obiect anume de-al RiverSim-ului, deci
-- nu mai e nimic de "ascuns" cand se prinde ceva. ObjectCaught a disparut o data cu asta [F0 spec 1.4].
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
