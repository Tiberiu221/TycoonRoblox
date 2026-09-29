--!strict
-- Forja [D55, D56]: aici scrap-ul se topeste in fier. Owner-ul: "scraps... sa se duca in alta parte la procesare, nu la
-- sawmill, si apoi la final duse la taverna la vanzare".
--
-- [D56] Ca gaterul: fara Smelter forja topeste doar cat stai in inelul ei (StandRing, comun cu gaterul); cu Smelter,
-- tot timpul, iar el bate cu ciocanul cat are ce topi (HandRenderController intreaba `Working`). Cladirea o
-- deseneaza PadController (platforma `workshop`, acum Forge); panoul vechi al atelierului nu se mai deschide de aici.
-- Aici: cele doua gramezi (scrap-ul de topit in stanga, fierul in dreapta), inelul, fumul din horn cat topeste, si
-- cardul de la usa -- E lasa scrap-ul si ia fierul gata. Upgrade = nivelul forjei.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local PileView = require(script.Parent.Parent.UI.PileView)
local Focus = require(script.Parent.Parent.UI.Focus)
local StandRing = require(script.Parent.Parent.UI.StandRing)

export type Deps = {
    Plot: Frame,
    Remotes: { UseForge: RemoteEvent, AtForge: RemoteEvent },
    CharacterPos: () -> (number, number),
}

export type Sack = {
    count: number,
    capacity: number,
    raw: number,
    rawScrap: number,
    finds: number, -- [D56] gasirile neprelucrate (se vand si asa; incluse in `cut`)
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
    present: boolean?,
    staffed: boolean?,
}

local ForgeController = {}
local deps: Deps
local inPile: PileView.View
local outPile: PileView.View
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, finds = 0, iron = 0, cut = 0, cutValue = 0 }
local state: Snapshot = {
    count = 0,
    contents = {},
    out = 0,
    outContents = {},
    rate = 0,
    present = false,
    staffed = false,
}
local owned = false

local STAND = TycoonConfig.WORKSHOP_STAND
local PAD = TycoonConfig.byId.workshop
local IN_SPOT = TycoonConfig.PILES.forgeIn
local OUT_SPOT = TycoonConfig.PILES.forgeOut
-- Cladirea (64x48 la x3 = 192x144), prinsa de baza la 56 px sub platforma. Hornul e la pixelii 46..52 ai
-- sprite-ului, sus: de acolo iese fumul.
local BUILDING_H = 144
local CHIMNEY_DX = -96 + 49 * 3
local SMOKE_EVERY = 0.8
local smokeClock = 0
-- [D56] norul de fum: fasie cu trei nori de 10x10 (Assets.tycoon.forge_smoke)
local SMOKE_FRAME = 10

local function base(): (number, number)
    return PAD.x :: number, TycoonConfig.buildingBase(PAD)
end

local function puff()
    local x, b = base()
    local smoke = Assets.tycoon.forge_smoke
    local p: GuiObject
    if Assets.has(smoke) then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(smoke)
        img.ImageRectSize = Vector2.new(SMOKE_FRAME, SMOKE_FRAME)
        img.ImageRectOffset = Vector2.new(math.random(0, 2) * SMOKE_FRAME, 0)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        p = img
    else
        -- arta inca neurcata: un cerc gri, ca inainte
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = Color3.fromRGB(214, 210, 204)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        p = frame
    end
    p.Name = "Smoke"
    p.AnchorPoint = Vector2.new(0.5, 0.5)
    p.Position = UDim2.fromOffset(x + CHIMNEY_DX, b - BUILDING_H - 2)
    p.Size = UDim2.fromOffset(18, 18)
    p.ZIndex = 7
    p.Parent = deps.Plot
    local drift = math.random(-10, 10)
    local goal: { [string]: any } = {
        Position = UDim2.fromOffset(x + CHIMNEY_DX + drift, b - BUILDING_H - 46),
        Size = UDim2.fromOffset(36, 36),
    }
    if p:IsA("ImageLabel") then
        goal.ImageTransparency = 1
    else
        goal.BackgroundTransparency = 1
    end
    local tween = TweenService:Create(p, TweenInfo.new(1.6, Enum.EasingStyle.Sine), goal)
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

-- [D56] Forja topeste chiar acum: Smelter-ul bate cu ciocanul doar atunci.
function ForgeController.Working(): boolean
    return owned and state.rate > 0
end

-- Cardul de la usa forjei: lasi scrap-ul (si iei fierul gata), sau iei fierul. Cat topesti de mana si mai e scrap,
-- fierul NU se ofera -- placuta spune "Smelting — N left", la fel ca la gater [D51]. Upgrade = nivelul forjei.
function ForgeController.Focus(px: number, py: number): Focus.Focus?
    if not owned then
        return nil
    end
    local d = Focus.distance(px, py, STAND.x, STAND.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local smeltingByHand = state.staffed ~= true and state.count > 0
    local text: string? = nil
    if sack.rawScrap > 0 then
        text = Strings.promptSmeltScrap(keyHint)
    elseif state.out > 0 and sack.count < sack.capacity and not smeltingByHand then
        text = Strings.promptTakeIron(keyHint)
    end
    local x, b = base()
    return {
        key = "forge",
        at = STAND,
        distance = d,
        x = x,
        y = b - BUILDING_H - 6,
        action = text,
        act = if text ~= nil
            then function()
                deps.Remotes.UseForge:FireServer()
            end
            else nil,
        upgradeKind = "forge",
    }
end

function ForgeController.Init(d: Deps)
    deps = d
    inPile = PileView.new(deps.Plot, IN_SPOT.x, IN_SPOT.y, { warnAt = 40, pill = IN_SPOT.pill })
    outPile = PileView.new(deps.Plot, OUT_SPOT.x, OUT_SPOT.y, { warnAt = 40, pill = OUT_SPOT.pill })
    StandRing.new({
        plot = deps.Plot,
        name = "Forge",
        stand = STAND,
        remote = deps.Remotes.AtForge,
        characterPos = deps.CharacterPos,
        standHere = Strings.FORGE_STAND_HERE,
        working = Strings.forgeSmelting,
        state = function(): (number, boolean)
            return state.count, state.staffed == true
        end,
        active = function(): boolean
            return owned
        end,
    })
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
