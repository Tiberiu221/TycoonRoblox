--!strict
-- Platformele de cumparat: patrat stralucitor + pictograma + nume + pret [F0 spec 4.3, plan B].
-- Cumperi calcand pe ea (sau apasand, pe telefon) -- o singura metoda de cumparare pentru tot.
-- Serverul decide intotdeauna (PadService.Buy revalideaza pretul si statutul); clientul doar
-- sugereaza intentia si arata rezultatul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local AABB = require(ReplicatedStorage.Shared.Modules.AABB)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local SceneArt = require(script.Parent.SceneArt)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    Scroll: Frame,
    Remotes: {
        BuyPad: RemoteEvent,
        PadBought: RemoteEvent,
        PadRejected: RemoteEvent,
    },
    CharacterPos: () -> (number, number),
    OnToast: (string) -> (),
}

local PadController = {}
local deps: Deps
local frames: { [string]: TextButton } = {}
local statuses: { [string]: string } = {}
local lastStatus: { [string]: string } = {}
local lastAffordable: { [string]: boolean } = {}
local ringSetters: { [string]: (number, Color3, Color3) -> () } = {}
local coins = 0
local firedAt: { [string]: number } = {} -- padId -> os.clock() la ultima tragere, pentru cooldown-ul de 1s
local RING_SIZE = 112
local Z = 3 -- nivelul solului, sub personaj si decor

local function isNetPad(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

local function clearContent(frame: Frame)
    for _, child in frame:GetChildren() do
        if not child:IsA("UICorner") then
            child:Destroy()
        end
    end
end

local function nameLabel(frame: Frame, pad: TycoonConfig.Pad, color: Color3, y: number, h: number)
    local l = Widgets.Label(frame, pad.name, Theme.TEXT.tiny, color, "strong")
    l.AnchorPoint = Vector2.new(0.5, 0)
    l.Position = UDim2.new(0.5, 0, 0, y)
    l.Size = UDim2.fromOffset(TycoonConfig.PAD_SIZE - 8, h)
    l.TextXAlignment = Enum.TextXAlignment.Center
    l.TextWrapped = true
    l.ZIndex = Z + 2
    Theme.punch(l, 2)
end

-- "available": patrat auriu, pictograma, nume, pret. Fara bani: pretul rosu + inel de progres
-- (coins/price). Cu bani: patratul pulseaza -- indemnul vizual de "calca aici" [docs/TYCOON.md B].
local function styleAvailable(frame: TextButton, pad: TycoonConfig.Pad, affordable: boolean)
    clearContent(frame)
    ringSetters[pad.id] = nil
    frame.BackgroundColor3 = Theme.COLOR.gold
    frame.BackgroundTransparency = 0.6

    local stroke = Instance.new("UIStroke")
    stroke.Name = "Edge"
    stroke.Thickness = 3
    stroke.Color = Theme.COLOR.gold
    stroke.Parent = frame

    Widgets.Icon(frame, if isNetPad(pad) then "net" else "hammer", 28)
    local icon = frame:FindFirstChildWhichIsA("ImageLabel")
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 0)
        icon.Position = UDim2.new(0.5, 0, 0, 8)
    end

    nameLabel(frame, pad, Theme.COLOR.onDark, 40, 26)

    local priceText = if pad.price == 0 then "FREE" else TycoonMath.formatNumber(pad.price)
    local price = Widgets.Label(
        frame,
        priceText,
        Theme.TEXT.small,
        if affordable then Theme.COLOR.gold else Theme.COLOR.bad,
        "display"
    )
    price.AnchorPoint = Vector2.new(0.5, 1)
    price.Position = UDim2.new(0.5, 0, 1, -6)
    price.Size = UDim2.fromOffset(TycoonConfig.PAD_SIZE - 8, 20)
    price.TextXAlignment = Enum.TextXAlignment.Center
    price.ZIndex = Z + 2
    Theme.punch(price, 2)

    if affordable then
        -- pulseaza: platforma se poate cumpara chiar acum, calci sau apesi
        local pulse = TweenService:Create(
            stroke,
            TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.6 }
        )
        pulse:Play()
    else
        -- inelul de progres: cat de aproape esti de pret, nu doar "nu ai bani"
        local ring, setProgress = Widgets.Ring(frame, RING_SIZE, 4, Z + 1)
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromScale(0.5, 0.5)
        local progress = if pad.price > 0 then coins / pad.price else 1
        setProgress(progress, Theme.COLOR.gold, Theme.COLOR.woodDark)
        ringSetters[pad.id] = setProgress
    end
end

-- "outline": urmatoarea platforma, vizibil ca sa se stie ce urmeaza, dar nu inca de cumparat
-- [padStatuses: a treia eligibila sau clopotul care asteapta].
local function styleOutline(frame: TextButton, pad: TycoonConfig.Pad)
    clearContent(frame)
    ringSetters[pad.id] = nil
    frame.BackgroundTransparency = 1
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Theme.COLOR.onDarkSoft
    stroke.Transparency = 0.4
    stroke.Parent = frame
    nameLabel(frame, pad, Theme.COLOR.onDarkSoft, 34, 30)
end

-- "bought": stalp pe mal pentru platformele de plasa (plasa insasi o deseneaza NetController in
-- apa); pentru restul, o bifa si numele. Fara stralucire -- nu mai e de vanzare.
local function styleBought(frame: TextButton, pad: TycoonConfig.Pad)
    clearContent(frame)
    ringSetters[pad.id] = nil
    frame.BackgroundTransparency = 1
    if isNetPad(pad) then
        local post = Instance.new("Frame")
        post.Name = "Post"
        post.AnchorPoint = Vector2.new(0.5, 1)
        post.Position = UDim2.new(0.5, 0, 1, 4)
        post.Size = UDim2.fromOffset(14, 44)
        post.BackgroundColor3 = Theme.COLOR.wood
        post.BorderSizePixel = 0
        post.ZIndex = Z
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = post
        post.Parent = frame
        local cap = Instance.new("Frame")
        cap.Name = "Cap"
        cap.AnchorPoint = Vector2.new(0.5, 1)
        cap.Position = UDim2.new(0.5, 0, 0, 2)
        cap.Size = UDim2.fromOffset(26, 8)
        cap.BackgroundColor3 = Theme.COLOR.woodDark
        cap.BorderSizePixel = 0
        cap.ZIndex = Z
        local capCorner = Instance.new("UICorner")
        capCorner.CornerRadius = UDim.new(0, 3)
        capCorner.Parent = cap
        cap.Parent = post
    else
        Widgets.Icon(frame, "check", 26)
        local icon = frame:FindFirstChildWhichIsA("ImageLabel")
        if icon ~= nil then
            icon.AnchorPoint = Vector2.new(0.5, 1)
            icon.Position = UDim2.new(0.5, 0, 1, -22)
        end
        nameLabel(frame, pad, Theme.COLOR.onDarkSoft, 44, 26)
    end
end

local function tryBuy(padId: string)
    if statuses[padId] ~= "available" then
        return
    end
    local last = firedAt[padId]
    if last ~= nil and os.clock() - last < 1 then
        return -- cooldown-ul de 1s inca nu a trecut
    end
    firedAt[padId] = os.clock()
    deps.Remotes.BuyPad:FireServer(padId)
end

local function ensureFrame(pad: TycoonConfig.Pad): TextButton
    local existing = frames[pad.id]
    if existing ~= nil then
        return existing
    end
    local frame = Instance.new("TextButton")
    frame.Name = pad.id
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromOffset(pad.x :: number, pad.y :: number)
    frame.Size = UDim2.fromOffset(TycoonConfig.PAD_SIZE, TycoonConfig.PAD_SIZE)
    frame.AutoButtonColor = false
    frame.Text = ""
    frame.BackgroundTransparency = 1
    frame.ZIndex = Z
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    frame.Activated:Connect(function()
        -- apasatul/atinsul platformei cumpara la fel ca mersul pe ea [F0 spec 4.3, mobil]
        tryBuy(pad.id)
    end)
    frame.Parent = deps.Scroll
    frames[pad.id] = frame
    return frame
end

-- Starea vine din TycoonState, inlocuita in intregime la fiecare mesaj [F0 spec 4.1]. Se
-- reconstruieste vizualul doar cand statutul sau granita afordabil/neafordabil chiar se schimba --
-- altfel un Collect oarecare ar reporni pulsul fiecarei platforme accesibile de pe ecran.
function PadController.Apply(pads: { [string]: string }, newCoins: number)
    statuses = pads
    coins = newCoins
    for _, pad in TycoonConfig.PADS do
        if pad.x == nil or pad.y == nil then
            continue -- erele 2-4 n-au inca lume construita
        end
        local status = pads[pad.id]
        if status == nil then
            local frame = frames[pad.id]
            if frame ~= nil then
                frame.Visible = false
            end
            lastStatus[pad.id] = nil
            continue
        end
        local frame = ensureFrame(pad)
        frame.Visible = true
        if status == "available" then
            local affordable = coins >= pad.price
            if lastStatus[pad.id] ~= status or lastAffordable[pad.id] ~= affordable then
                styleAvailable(frame, pad, affordable)
                lastAffordable[pad.id] = affordable
            elseif not affordable then
                local setter = ringSetters[pad.id]
                if setter ~= nil then
                    setter(
                        if pad.price > 0 then coins / pad.price else 1,
                        Theme.COLOR.gold,
                        Theme.COLOR.woodDark
                    )
                end
            end
        elseif lastStatus[pad.id] ~= status then
            if status == "outline" then
                styleOutline(frame, pad)
            elseif status == "bought" then
                styleBought(frame, pad)
            end
        end
        lastStatus[pad.id] = status
    end
end

function PadController.Init(d: Deps)
    deps = d

    RunService.PreRender:Connect(function()
        local cx, cy = deps.CharacterPos()
        local c = RiverConfig.CHARACTER
        local charBox: AABB.Box =
            { x = cx - c.WIDTH / 2, y = cy - c.HEIGHT, width = c.WIDTH, height = c.HEIGHT }
        local half = TycoonConfig.PAD_SIZE / 2
        for _, pad in TycoonConfig.PADS do
            if pad.x == nil or pad.y == nil or statuses[pad.id] ~= "available" then
                continue
            end
            local padBox: AABB.Box = {
                x = (pad.x :: number) - half,
                y = (pad.y :: number) - half,
                width = TycoonConfig.PAD_SIZE,
                height = TycoonConfig.PAD_SIZE,
            }
            if AABB.intersects(charBox, padBox) then
                if coins >= pad.price then
                    tryBuy(pad.id)
                end
            else
                firedAt[pad.id] = nil -- plecarea de pe platforma rearmeaza imediat
            end
        end
    end)

    deps.Remotes.PadBought.OnClientEvent:Connect(function(padId: string)
        -- un pufait scurt la constructie; statutul "bought" (cu stalpul/bifa) vine separat, in
        -- urmatorul TycoonState [F0 spec 4.3]
        local frame = frames[padId]
        if frame ~= nil then
            SceneArt.Flourish(frame, frame)
        end
    end)
    deps.Remotes.PadRejected.OnClientEvent:Connect(function(_padId: string, reason: string)
        if reason == "coins" then
            deps.OnToast("Not enough coins")
        end
    end)
end

return PadController
