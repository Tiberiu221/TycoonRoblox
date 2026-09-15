--!strict
-- [D59] CE ADUCE RAUL, pe ecran. Owner-ul: "A si B cum recomanzi" -- B e raul care aduce din cand in cand ceva ce
-- plasele nu prind; se opreste la ponton si te asteapta (cel mult trei). Aici doar se vede: lucrurile care stau lipite
-- de ponton, in amonte, legandu-se pe apa; cel care vine pluteste din stanga pana la locul lui; cel scos zboara spre
-- tine. Ce si cand hotaraste serverul (TreasureService); scoaterea e a undiței (PierController).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    Plot: Frame,
    Remotes: { TreasureArrived: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local TreasureController = {}
local deps: Deps? = nil

local SLOTS = TycoonConfig.TREASURE_SLOTS
local Z = 4 -- peste apa si peste ponton (Z 3), sub oameni si sub card
local SCALE = Assets.PIXEL_SCALE
local FLOAT_SPEED = 110 -- px/s: mai incet decat bustenii de pe curent (130), ca un lucru greu
local START_X = -80 -- de dincolo de marginea din stanga a lumii

local waiting: { string } = {}
local views: { [number]: ImageLabel } = {}
-- locurile in care un lucru inca pluteste spre ponton: nu se deseneaza si lipit, pana ajunge
local arrivingUntil: { [number]: number } = {}

local function spriteFor(kind: string, inWater: boolean): Assets.Sprite?
    local sprite = (Assets.treasure :: any)[if inWater then `{kind}_water` else kind]
    return if sprite ~= nil and Assets.has(sprite) then sprite else nil
end

local function makeImage(kind: string): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Name = `Treasure_{kind}`
    img.BackgroundTransparency = 1
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.ZIndex = Z
    local sprite = spriteFor(kind, true)
    if sprite ~= nil then
        img.Image = Assets.url(sprite)
        img.Size = UDim2.fromOffset(sprite.width * SCALE, sprite.height * SCALE)
    else
        -- desenul inca neurcat: un patrat auriu tine locul, ca lucrul sa nu fie invizibil
        img.BackgroundTransparency = 0
        img.BackgroundColor3 = Theme.COLOR.gold
        img.Size = UDim2.fromOffset(40, 30)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = img
    end
    img.Parent = (deps :: Deps).Plot
    return img
end

-- Centrul locului `index` de la ponton (1 = cel lipit de capat), in coordonatele terenului.
function TreasureController.SlotPosition(index: number): (number, number)
    local slot = SLOTS[math.clamp(index, 1, #SLOTS)]
    return slot.x, slot.y
end

local function render()
    if deps == nil then
        return
    end
    local now = os.clock()
    for i = 1, #SLOTS do
        local kind = waiting[i]
        local until_ = arrivingUntil[i]
        local arriving = until_ ~= nil and now < until_
        local view = views[i]
        if kind == nil or arriving then
            if view ~= nil then
                view.Visible = false
            end
            continue
        end
        if view == nil or view:GetAttribute("kind") ~= kind then
            if view ~= nil then
                view:Destroy()
            end
            view = makeImage(kind)
            view:SetAttribute("kind", kind)
            views[i] = view
        end
        view.Visible = true
    end
end

-- Din TycoonState: ce asteapta la ponton, in ordinea sosirii.
function TreasureController.Apply(newWaiting: { string })
    waiting = table.clone(newWaiting)
    render()
end

-- Primul lucru a fost scos cu undita: zboara spre tine si dispare, iar restul se muta pe loc (starea serverului vine
-- imediat dupa si spune acelasi lucru).
function TreasureController.PlayHooked(toX: number, toY: number)
    local view = views[1]
    if deps == nil or view == nil or not view.Visible then
        return
    end
    local copy = view:Clone()
    copy.Parent = (deps :: Deps).Plot
    TweenService:Create(
        copy,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In),
        { Position = UDim2.fromOffset(toX, toY), ImageTransparency = 1 }
    ):Play()
    task.delay(0.5, function()
        copy:Destroy()
    end)
    table.remove(waiting, 1)
    render()
end

-- Ceva a venit pe rau: pluteste din stanga pana la locul lui, apoi se anunta [D43]. Toast-ul vine la sosire, cand
-- "drifted to your pier" e adevarat [D40].
local function playArrival(kind: string, slot: number)
    if deps == nil then
        return
    end
    local d = deps :: Deps
    local x, y = TreasureController.SlotPosition(slot)
    local duration = (x - START_X) / FLOAT_SPEED
    arrivingUntil[slot] = os.clock() + duration
    render()
    local img = makeImage(kind)
    img.Position = UDim2.fromOffset(START_X, y)
    TweenService:Create(
        img,
        TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
        { Position = UDim2.fromOffset(x, y) }
    ):Play()
    task.delay(duration, function()
        img:Destroy()
        arrivingUntil[slot] = nil
        render()
        SoundController.Play("splash", 0.9)
        local def = TreasureConfig.byId[kind]
        if def ~= nil then
            d.OnToast(Strings.treasureArrived(def.phrase), Theme.COLOR.gold)
        end
    end)
end

function TreasureController.Init(d: Deps)
    deps = d
    d.Remotes.TreasureArrived.OnClientEvent:Connect(function(kind: string, slot: number)
        if typeof(kind) ~= "string" or typeof(slot) ~= "number" then
            return
        end
        playArrival(kind, math.clamp(math.floor(slot), 1, #SLOTS))
    end)
    -- legatul pe apa: fiecare alt ritm, ca trei lucruri sa nu se miste ca unul
    RunService.PreRender:Connect(function()
        local t = os.clock()
        for i, view in views do
            if view.Visible then
                local x, y = TreasureController.SlotPosition(i)
                view.Position = UDim2.fromOffset(x, y + math.sin(t * 1.8 + i * 1.7) * 2)
                view.Rotation = math.sin(t * 1.3 + i) * 3
            end
        end
    end)
end

return TreasureController
