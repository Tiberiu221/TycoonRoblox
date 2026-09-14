--!strict
-- Forja atelierului [D55]: aici scrap-ul se topeste in fier. Owner-ul: "scraps... sa se duca in alta parte la
-- procesare, nu la sawmill, si apoi la final duse la taverna la vanzare".
--
-- Atelierul (cladirea) il deseneaza PadController; panoul lui cu gasirile ramane al lui WorkshopController.
-- Aici: cele doua gramezi (scrap-ul de topit in stanga, fierul in dreapta), fumul din horn cat topeste, si
-- cardul de la usa -- E lasa scrap-ul si ia fierul gata, iar fara nimic de facut deschide atelierul;
-- Upgrade = nivelul forjei.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local PileView = require(script.Parent.Parent.UI.PileView)
local Focus = require(script.Parent.Parent.UI.Focus)

export type Deps = {
    Plot: Frame,
    Remotes: { UseForge: RemoteEvent },
    OpenWorkshop: () -> (),
}

export type Sack = {
    count: number,
    capacity: number,
    raw: number,
    rawScrap: number,
    iron: number,
    cut: number,
    cutValue: number,
}
export type Snapshot = {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
}

local ForgeController = {}
local deps: Deps
local inPile: PileView.View
local outPile: PileView.View
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, iron = 0, cut = 0, cutValue = 0 }
local state: Snapshot = { count = 0, contents = {}, out = 0, outContents = {}, rate = 0 }
local owned = false

local STAND = TycoonConfig.WORKSHOP_STAND
local PAD = TycoonConfig.byId.workshop
local IN_SPOT = TycoonConfig.PILES.forgeIn
local OUT_SPOT = TycoonConfig.PILES.forgeOut
-- Atelierul (64x48 la x3 = 192x144), prins de baza la 56 px sub platforma. Hornul e la pixelii 46..52 ai
-- sprite-ului, sus: de acolo iese fumul.
local BUILDING_H = 144
local CHIMNEY_DX = -96 + 49 * 3
local SMOKE_EVERY = 0.8
local smokeClock = 0

local function base(): (number, number)
    return PAD.x :: number, (PAD.y :: number) + 56
end

local function puff()
    local x, b = base()
    local p = Instance.new("Frame")
    p.Name = "Smoke"
    p.AnchorPoint = Vector2.new(0.5, 0.5)
    p.Position = UDim2.fromOffset(x + CHIMNEY_DX, b - BUILDING_H - 2)
    p.Size = UDim2.fromOffset(10, 10)
    p.BackgroundColor3 = Color3.fromRGB(214, 210, 204)
    p.BackgroundTransparency = 0.25
    p.BorderSizePixel = 0
    p.ZIndex = 7
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = p
    p.Parent = deps.Plot
    local drift = math.random(-10, 10)
    local tween = TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine), {
        Position = UDim2.fromOffset(x + CHIMNEY_DX + drift, b - BUILDING_H - 46),
        Size = UDim2.fromOffset(24, 24),
        BackgroundTransparency = 1,
    })
    tween.Completed:Connect(function()
        p:Destroy()
    end)
    tween:Play()
end

function ForgeController.Apply(newSack: Sack, snap: Snapshot?, isOwned: boolean)
    sack = newSack
    owned = isOwned
    if snap == nil then
        return
    end
    state = snap
    inPile.Set(snap.count, snap.contents)
    outPile.Set(snap.out, snap.outContents)
end

-- Cardul de la usa atelierului: lasi scrap-ul la forja (si iei fierul gata), sau iei fierul, sau -- fara
-- nimic de facut cu forja -- intri in atelier, la gasiri. Upgrade = nivelul forjei.
function ForgeController.Focus(px: number, py: number): Focus.Focus?
    if not owned then
        return nil
    end
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local text: string
    local act: () -> ()
    if sack.rawScrap > 0 then
        text = Strings.promptSmeltScrap(keyHint)
        act = function()
            deps.Remotes.UseForge:FireServer()
        end
    elseif state.out > 0 and sack.count < sack.capacity then
        text = Strings.promptTakeIron(keyHint)
        act = function()
            deps.Remotes.UseForge:FireServer()
        end
    else
        text = Strings.promptWorkshop(keyHint)
        act = deps.OpenWorkshop
    end
    local x, b = base()
    return {
        key = "forge",
        distance = d,
        x = x,
        y = b - BUILDING_H - 6,
        action = text,
        act = act,
        upgradeKind = "forge",
    }
end

function ForgeController.Init(d: Deps)
    deps = d
    inPile = PileView.new(deps.Plot, IN_SPOT.x, IN_SPOT.y, { warnAt = 40, pill = IN_SPOT.pill })
    outPile = PileView.new(deps.Plot, OUT_SPOT.x, OUT_SPOT.y, { warnAt = 40, pill = OUT_SPOT.pill })
    RunService.Heartbeat:Connect(function(dt: number)
        if not owned or state.rate <= 0 then
            smokeClock = 0
            return
        end
        smokeClock += dt
        if smokeClock >= SMOKE_EVERY then
            smokeClock = 0
            puff()
        end
    end)
end

return ForgeController
