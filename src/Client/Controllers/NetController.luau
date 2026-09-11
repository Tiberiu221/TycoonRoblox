--!strict
-- Plasele: cate o intrare per TycoonState.nets, randata la (x, y) trimis de server (pad.x,
-- LANE_Y[lane]) -- plasa insasi sta in apa [F0 spec 1.4, 4.4]. Interactiunea de apropiere (E /
-- butonul de atingere) foloseste insa STALPUL platformei de pe mal ca ancora de distanta, nu
-- punctul din apa -- personajul nu poate calca in rau (WorldMap il blocheaza), deci masurata fata
-- de un punct din banda de apa unele plase (banda 2-3) ar iesi din raza de interactiune.
-- Debarcaderul e ultima incercare: daca nu esti langa o plasa cu ceva inauntru, DockController
-- decide daca esti langa el si vinde.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local SceneArt = require(script.Parent.SceneArt)
local DockController = require(script.Parent.DockController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type NetSnap = {
    padId: string,
    lane: number,
    x: number,
    y: number,
    count: number,
    capacity: number,
    nextCatchAt: number,
    interval: number,
}

export type Deps = {
    Scroll: Frame,
    Remotes: {
        CollectNet: RemoteEvent,
        NetCaught: RemoteEvent,
    },
    CharacterPos: () -> (number, number),
    OnToast: (string) -> (),
}

local NetController = {}
local deps: Deps
local nets: { [string]: NetSnap } = {} -- padId -> ultima stare cunoscuta
local frames: { [string]: Frame } = {} -- padId -> caseta count/capacity randata in apa
local prompt: TextLabel
local sackCount = 0
local sackCapacity = 0

local function refreshLabel(padId: string)
    local snap = nets[padId]
    local frame = frames[padId]
    if snap == nil or frame == nil then
        return
    end
    local count = frame:FindFirstChild("Count") :: TextLabel
    if snap.count >= snap.capacity then
        count.Text = "FULL"
        count.TextColor3 = Theme.COLOR.bad
    else
        count.Text = `{snap.count} / {snap.capacity}`
        count.TextColor3 = Theme.COLOR.onDark
    end
end

local function ensureNetFrame(padId: string, x: number, y: number): Frame
    local existing = frames[padId]
    if existing ~= nil then
        return existing
    end
    local frame = Instance.new("Frame")
    frame.Name = padId
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset(x, y)
    frame.Size = UDim2.fromOffset(RiverConfig.NET_WIDTH, RiverConfig.NET_HEIGHT)
    frame.ZIndex = 4
    SceneArt.StyleNet(frame)

    local label = Instance.new("TextLabel")
    label.Name = "Count"
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 1, 4)
    label.Size = UDim2.fromOffset(120, 26)
    label.BackgroundColor3 = Theme.COLOR.plate
    label.BackgroundTransparency = 0.3
    label.TextColor3 = Theme.COLOR.onDark
    label.TextSize = 20 -- fara corespondent in Theme.TEXT (30/22/18/15/13)
    label.ZIndex = 5
    Theme.applyFont(label, "strong")
    Theme.punch(label) -- numarul din plasa sta peste apa, langa plasa
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label
    label.Parent = frame

    frame.Parent = deps.Scroll
    frames[padId] = frame
    return frame
end

-- Ancora de distanta pentru o plasa: platforma ei de pe mal (pad.x, pad.y), NU pozitia din apa a
-- plasei -- vezi comentariul de sus.
local function nearestCollectible(charX: number, charY: number): string?
    local bestId: string? = nil
    local bestD = RiverConfig.INTERACT_DISTANCE
    for padId, snap in nets do
        if snap.count <= 0 then
            continue
        end
        local pad = TycoonConfig.byId[padId]
        if pad == nil or pad.x == nil or pad.y == nil then
            continue
        end
        local dx, dy = charX - (pad.x :: number), charY - (pad.y :: number)
        local d = math.sqrt(dx * dx + dy * dy)
        if d < bestD then
            bestId = padId
            bestD = d
        end
    end
    return bestId
end

-- Un singur punct de interactiune pentru tot (E si butonul de atingere): colectare, altfel
-- vanzare, exact cum NearestTarget combina odata sloturi si atelier [F0 spec 4.4/4.5].
function NetController.Interact()
    local cx, cy = deps.CharacterPos()
    local padId = nearestCollectible(cx, cy)
    if padId ~= nil then
        -- Nu exista un remot care sa spuna "refuzat, traista plina" -- verificam AICI, pe ultimul
        -- TycoonState cunoscut, inainte sa tragem CollectNet [instructiuni F0, sectiunea lipsa].
        if sackCapacity > 0 and sackCount >= sackCapacity then
            deps.OnToast("Sack full — sell at the dock")
            return
        end
        deps.Remotes.CollectNet:FireServer(padId)
        return
    end
    DockController.TryInteract()
end

-- Starea vine din TycoonState, inlocuita in intregime la fiecare mesaj [F0 spec 4.1].
function NetController.Apply(list: { NetSnap }, newSackCount: number, newSackCapacity: number)
    sackCount, sackCapacity = newSackCount, newSackCapacity
    local seen: { [string]: boolean } = {}
    for _, snap in list do
        nets[snap.padId] = snap
        seen[snap.padId] = true
        local frame = ensureNetFrame(snap.padId, snap.x, snap.y)
        if not frame.Visible then
            frame.Visible = true
        end
        refreshLabel(snap.padId)
    end
    -- nimic nu se pierde, deci o plasa nu ar trebui sa dispara niciodata -- dar daca totusi
    -- lipseste din starea serverului, mai bine ascunsa decat sa arate o cifra invechita
    for padId, frame in frames do
        if not seen[padId] and frame.Visible then
            frame.Visible = false
        end
    end
end

-- Catch-per-catch, mai ieftin decat un TycoonState intreg [F0 spec 1.4/3.4]; `good`/`catalog` nu
-- se folosesc inca in F0 -- doar cifra si un "+1" cresc.
function NetController.OnCaught(
    padId: string,
    count: number,
    capacity: number,
    _good: string,
    _catalog: string?
)
    local snap = nets[padId]
    if snap ~= nil then
        snap.count = count
        snap.capacity = capacity
    end
    refreshLabel(padId)
    local frame = frames[padId]
    if frame ~= nil then
        Widgets.FloatText(frame, "+1", Theme.COLOR.good, 6)
    end
end

function NetController.Init(d: Deps)
    deps = d

    prompt = Instance.new("TextLabel")
    prompt.AnchorPoint = Vector2.new(0.5, 1)
    prompt.Size = UDim2.fromOffset(220, 40)
    prompt.BackgroundColor3 = Theme.COLOR.plate
    prompt.BackgroundTransparency = 0.2
    prompt.TextColor3 = Theme.COLOR.gold
    prompt.TextSize = Theme.TEXT.heading
    prompt.ZIndex = 8
    prompt.Visible = false
    Theme.applyFont(prompt, "strong")
    Theme.punch(prompt) -- indemnul de interactiune urmareste tinta peste lume
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = prompt
    prompt.Parent = deps.Scroll

    RunService.PreRender:Connect(function()
        local cx, cy = deps.CharacterPos()
        local padId = nearestCollectible(cx, cy)
        local pad = if padId ~= nil then TycoonConfig.byId[padId] else nil
        if pad ~= nil then
            local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
            prompt.Text = "Collect" .. keyHint
            prompt.Position = UDim2.fromOffset(pad.x :: number, (pad.y :: number) - 56)
            prompt.Visible = true
        else
            prompt.Visible = false
        end
    end)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not processed and input.KeyCode == Enum.KeyCode.E then
            NetController.Interact()
        end
    end)

    deps.Remotes.NetCaught.OnClientEvent:Connect(
        function(padId: string, count: number, capacity: number, good: string, catalog: string?)
            NetController.OnCaught(padId, count, capacity, good, catalog)
        end
    )
end

return NetController
