--!strict
-- HUD-ul permanent: doar ce trebuie sa vada jucatorul TOT timpul [DECIZII D05].
--
-- Rescris pentru tycoon [F0 spec 4.2]: cifrele de colonie (hrana, materiale, gramada, oameni,
-- paturi) au disparut -- un singur numar conteaza acum, monedele, plus rata pe secunda si cat de
-- plina e traista. Restul (joystick, buton de interactiune, mesaje scurte) ramane neschimbat:
-- nu tine de colonie, tine de cum se joaca orice ecran 2D pe telefon.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local HUDController = {}
local coinValue: TextLabel
local rateValue: TextLabel
local sackValue: TextLabel
local sackChip: Frame
local toastLabel: TextLabel
-- treimea de sus, centrat: liber la orice latime, si acolo se uita ochiul
local TOAST_HOME = UDim2.fromScale(0.5, 0.26)
-- Comenzile de atingere. Panza HUD e viewport/hudScale, deci astea sunt unitati logice:
-- pe un telefon de 896x414 factorul e 0.62, adica baza de 170 iese ~105 px fizici.
local STICK_BASE = 170
local STICK_KNOB = 76
local STICK_RADIUS = 58
local STICK_DEADZONE = 10
local STICK_MARGIN = 44
local ACTION_SIZE = 108
local toastToken = 0
local fps = 60
local touchButtons: { TextButton } = {}
local lastSackFull = false

local function touchButton(
    parent: Instance,
    text: string,
    onDown: () -> (),
    onUp: () -> ()
): TextButton
    local b = Instance.new("TextButton")
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Size = UDim2.fromOffset(112, 112)
    b.BackgroundColor3 = Theme.COLOR.plate
    b.BackgroundTransparency = 0.42
    b.TextColor3 = Theme.COLOR.onDark
    b.TextSize = 40
    b.Text = text
    b.AutoButtonColor = false
    b.ZIndex = 10
    Theme.applyFont(b, "strong")
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 18)
    c.Parent = b
    b.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            onDown()
        end
    end)
    b.InputEnded:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            onUp()
        end
    end)
    b.Parent = parent
    table.insert(touchButtons, b)
    return b
end

function HUDController.Init(deps: {
    HudGui: Frame,
    SetStick: (number, number) -> (),
    Interact: () -> (),
    PanelsOpen: (() -> boolean)?,
})
    -- Numarul central: monedele. Mare, cu pictograma, fiindca e SINGURUL numar la care contribuie
    -- toata bucla -- nimic altceva nu mai merita acelasi loc pe ecran [DECIZII D45].
    local coinRow = Instance.new("Frame")
    coinRow.Name = "Coins"
    coinRow.BackgroundTransparency = 1
    coinRow.Position = UDim2.fromOffset(Theme.SPACE.lg, Theme.SPACE.md)
    coinRow.Size = UDim2.fromOffset(280, 40)
    coinRow.ZIndex = 12
    coinRow.Parent = deps.HudGui
    local coinLayout = Instance.new("UIListLayout")
    coinLayout.FillDirection = Enum.FillDirection.Horizontal
    coinLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    coinLayout.Padding = UDim.new(0, Theme.SPACE.sm)
    coinLayout.Parent = coinRow
    local coinIcon = Widgets.CoinIcon(coinRow, 30, 13)
    coinIcon.LayoutOrder = 1
    coinValue = Widgets.Label(coinRow, "0", Theme.TEXT.title, Theme.COLOR.onDark, "display")
    coinValue.LayoutOrder = 2
    coinValue.AutomaticSize = Enum.AutomaticSize.X
    coinValue.Size = UDim2.fromOffset(0, Theme.TEXT.title + 4)
    coinValue.ZIndex = 13
    Theme.punch(coinValue)

    -- rata: cat de repede creste numarul de sus, cat timp nu faci nimic. Sub cifra mare, nu
    -- langa ea -- e o completare, nu al doilea numar principal.
    -- TEXT.body, nu small: la scara HUD-ului pe un ecran de laptop, 15 px ajungeau la ~12 si
    -- rata abia se citea (vazut in Studio, 2026-09-11)
    rateValue = Widgets.Label(deps.HudGui, "+0.0/s", Theme.TEXT.body, Theme.COLOR.gold, "strong")
    rateValue.Position = UDim2.fromOffset(Theme.SPACE.lg + 38, Theme.SPACE.md + 36)
    rateValue.Size = UDim2.fromOffset(200, 24)
    rateValue.ZIndex = 12
    Theme.punch(rateValue, 2)

    -- traista: cat mai poti duce inainte sa trebuiasca sa mergi la debarcader. Se incalzeste
    -- si se aprinde rosu cand se umple -- semnalul de "du-te si vinde" [DECIZII D40, D43].
    sackChip, sackValue = Widgets.Chip(deps.HudGui, "crate", 12, "Sack")
    sackChip.Position = UDim2.fromOffset(Theme.SPACE.lg, 78)
    sackChip.Size = UDim2.fromOffset(120, 52)

    -- Mesajele scurte stau in TREIMEA DE SUS, centrat, si urca stingandu-se -- pozitia clasica
    -- de "Not enough gold!" din jocurile mobile de constructie.
    toastLabel = Widgets.PlateLabel(deps.HudGui, "", Theme.TEXT.heading, "display")
    toastLabel.Name = "Toast"
    toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    toastLabel.Position = TOAST_HOME
    toastLabel.AutomaticSize = Enum.AutomaticSize.X -- pastila se strange pe mesaje scurte
    toastLabel.Size = UDim2.fromOffset(0, 46)
    toastLabel.TextXAlignment = Enum.TextXAlignment.Center
    toastLabel.TextColor3 = Theme.COLOR.gold
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = false
    toastLabel.ZIndex = 16
    Theme.punch(toastLabel)

    local showTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    -- JOYSTICK, nu patru butoane. Cele patru pastrate de 112 px stateau imprastiate peste lume
    -- si peste cladiri, mancau o treime din ecranul de telefon si dadeau doar 8 directii.
    -- Un joystick sta intr-un colt, da directie analogica si nu acopera nimic din joc.
    local base = Instance.new("Frame")
    base.Name = "MoveStick"
    base.AnchorPoint = Vector2.new(0, 1)
    base.Position = UDim2.new(0, STICK_MARGIN, 1, -STICK_MARGIN)
    base.Size = UDim2.fromOffset(STICK_BASE, STICK_BASE)
    base.BackgroundColor3 = Theme.COLOR.plate
    base.BackgroundTransparency = 0.55
    base.ZIndex = 10
    base.Visible = showTouch
    base.Parent = deps.HudGui
    local baseRound = Instance.new("UICorner")
    baseRound.CornerRadius = UDim.new(1, 0)
    baseRound.Parent = base
    local baseEdge = Instance.new("UIStroke")
    baseEdge.Color = Theme.COLOR.onDarkSoft
    baseEdge.Thickness = 2
    baseEdge.Transparency = 0.5
    baseEdge.Parent = base

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.fromScale(0.5, 0.5)
    knob.Size = UDim2.fromOffset(STICK_KNOB, STICK_KNOB)
    knob.BackgroundColor3 = Theme.COLOR.parchment
    knob.BackgroundTransparency = 0.15
    knob.ZIndex = 11
    knob.Parent = base
    local knobRound = Instance.new("UICorner")
    knobRound.CornerRadius = UDim.new(1, 0)
    knobRound.Parent = knob

    -- Deplasarea se masoara fata de PUNCTUL IN CARE AI ATINS, nu fata de centrul desenat.
    -- Asa nu trebuie sa nimeresti mijlocul cu degetul, si scap si de nepotrivirea dintre
    -- coordonatele de input si AbsolutePosition sub decupajul de sus al platformei.
    local active: InputObject? = nil
    local origin = Vector2.zero

    local function release()
        active = nil
        knob.Position = UDim2.fromScale(0.5, 0.5)
        deps.SetStick(0, 0)
    end

    local function drive(at: Vector2)
        local delta = at - origin
        local len = delta.Magnitude
        local clamped = if len > STICK_RADIUS then delta.Unit * STICK_RADIUS else delta
        knob.Position = UDim2.new(0.5, clamped.X, 0.5, clamped.Y)
        if len < STICK_DEADZONE then
            deps.SetStick(0, 0) -- zona moarta: degetul asezat pe ecran nu inseamna "mergi"
            return
        end
        deps.SetStick(clamped.X / STICK_RADIUS, clamped.Y / STICK_RADIUS)
    end

    base.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            active = input
            origin = Vector2.new(input.Position.X, input.Position.Y)
            drive(origin)
        end
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if input == active then
            drive(Vector2.new(input.Position.X, input.Position.Y))
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if input == active then
            release()
        end
    end)

    local action = touchButton(deps.HudGui, "", deps.Interact, function() end)
    action.Name = "ActionButton"
    action.AnchorPoint = Vector2.new(1, 1)
    action.Position = UDim2.new(1, -STICK_MARGIN, 1, -STICK_MARGIN)
    action.Size = UDim2.fromOffset(ACTION_SIZE, ACTION_SIZE)
    action.BackgroundColor3 = Theme.COLOR.gold
    action.BackgroundTransparency = 0.1
    action.Visible = showTouch
    local actionRound = action:FindFirstChildOfClass("UICorner")
    if actionRound ~= nil then
        actionRound.CornerRadius = UDim.new(1, 0) -- rotund, nu patrat cu colturi taiate
    end
    local actionIcon = Widgets.Icon(action, "hammer", 40)
    if actionIcon ~= nil then
        actionIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        actionIcon.Position = UDim2.fromScale(0.5, 0.5)
        actionIcon.ZIndex = 12
    end

    local frames, elapsed = 0, 0
    RunService.Heartbeat:Connect(function(dt: number)
        frames += 1
        elapsed += dt
        if elapsed >= 0.5 then
            fps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
        end
        -- Butoanele de pe ecran stau sub panouri: pe telefon, cu panoul deschis, jucatorul
        -- apasa panoul cand vrea sa mearga. Le ascundem cat timp e ceva deschis.
        if not showTouch then
            return
        end
        local blocked = deps.PanelsOpen ~= nil and (deps.PanelsOpen :: () -> boolean)()
        for _, b in touchButtons do
            if b.Visible == blocked then
                b.Visible = not blocked
            end
        end
        if base.Visible == blocked then
            base.Visible = not blocked
            if blocked then
                release() -- altfel personajul ramane mergand in directia in care era degetul
            end
        end
    end)
end

-- Diagnosticul se citeste din consola de dezvoltare, nu se afiseaza peste lume
function HUDController.Perf(): number
    return fps
end

-- floor: monedele curg fractionar pe server, dar jucatorul numara in bucati [F0 spec 4.2].
function HUDController.SetCoins(coins: number)
    if coinValue ~= nil then
        coinValue.Text = TycoonMath.formatNumber(coins)
    end
end

function HUDController.SetIncome(perSec: number)
    if rateValue ~= nil then
        rateValue.Text = `+{TycoonMath.formatRate(perSec)}/s`
    end
end

-- Se incalzeste cu cat se apropie de plin, si devine rosie cand chiar e plina -- semnalul care
-- spune "du-te la debarcader" inainte ca o colectare sa fie refuzata in tacere [D40, D43].
function HUDController.SetSack(count: number, capacity: number)
    if sackValue == nil then
        return
    end
    sackValue.Text = `{count}/{capacity}`
    local full = capacity > 0 and count >= capacity
    local warm = capacity > 0 and count >= capacity * 0.75
    local color = if full
        then Theme.COLOR.bad
        elseif warm then Theme.COLOR.warn
        else Theme.COLOR.onDark
    if sackValue.TextColor3 ~= color then
        sackValue.TextColor3 = color
    end
    -- Un singur puls, chiar in clipa in care se umple -- nu la fiecare stare de TycoonState cat
    -- ramane plina. UIScale + Back/Out, acelasi truc ca SceneArt.Flourish (marime mare instant,
    -- revine tweenuit): mai simplu decat sa refacem manual Size dus-intors.
    if full and not lastSackFull then
        local scale = sackChip:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = sackChip
        scale.Scale = 1.18
        TweenService:Create(
            scale,
            TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
            { Scale = 1 }
        ):Play()
    end
    lastSackFull = full
end

function HUDController.Toast(message: string)
    toastToken += 1
    local token = toastToken
    toastLabel.Text = message
    toastLabel.Position = TOAST_HOME
    toastLabel.TextTransparency = 0
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = true
    -- mica sarita la intrare: mesajul se face observat fara sa ceara o apasare
    toastLabel.Size = UDim2.fromOffset(0, 38)
    TweenService:Create(
        toastLabel,
        TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(0, 46) }
    ):Play()
    task.delay(2.6, function()
        if toastToken ~= token then
            return
        end
        -- urca si se stinge, nu dispare brusc: ochiul urmareste miscarea si citeste pana la capat
        local away = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toastLabel, away, {
            Position = TOAST_HOME - UDim2.fromOffset(0, 44),
            TextTransparency = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.6, function()
            if toastToken == token then
                toastLabel.Visible = false
            end
        end)
    end)
end

return HUDController
