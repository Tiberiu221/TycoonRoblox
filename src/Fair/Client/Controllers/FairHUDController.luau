--!strict
-- [D60] HUD-ul BALCIULUI: pastila perlelor (sus, in stanga), mesajele scurte, iar pe telefon joystick-ul si butonul
-- de actiune. Mai mic decat HUD-ul satului (HUDController), care are lantul, sacul si quest-urile: aici nu e nimic de
-- produs, doar de vazut, de invartit si de cumparat. Aceleasi masuri si acelasi comportament ca in sat, ca mana sa nu
-- simta diferenta.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    HudGui: Frame,
    SetStick: (number, number) -> (),
    Interact: () -> (),
    PanelsOpen: () -> boolean,
}

local FairHUDController = {}
local hud: Frame? = nil
local pearlPill: Frame
local pearlValue: TextLabel
local toastLabel: TextLabel
local toastToken = 0
-- [D61] degetul care tine butonul rotund (bara undiței de la iaz) si banda de sus a concursului
local actionHeldBy: InputObject? = nil
local banner: Frame
local bannerTop: TextLabel
local bannerBottom: TextLabel

local PILL_W, PILL_H = 170, 48
local TOAST_HOME = UDim2.fromScale(0.5, 0.26)
-- ca in HUDController (joystick-ul si butonul rotund)
local STICK_BASE, STICK_KNOB, STICK_RADIUS, STICK_DEADZONE, STICK_MARGIN = 170, 76, 58, 10, 44
local ACTION_SIZE = 108
local BANNER_W = 460

function FairHUDController.SetPearls(n: number)
    if hud ~= nil then
        pearlValue.Text = TycoonMath.formatNumber(math.floor(n))
    end
end

-- Unde zboara perlele castigate: iconita din pastila, pe panza HUD.
function FairHUDController.PearlAnchor(): (number, number)
    return Theme.SPACE.lg + Theme.SPACE.md + 11, Theme.SPACE.md + PILL_H / 2
end

function FairHUDController.Toast(message: string, color: Color3?)
    if hud == nil then
        return
    end
    toastToken += 1
    local token = toastToken
    toastLabel.Text = message
    toastLabel.Position = TOAST_HOME
    toastLabel.TextTransparency = 0
    toastLabel.TextColor3 = color or Theme.COLOR.gold
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = true
    task.delay(2.6, function()
        if toastToken ~= token then
            return
        end
        local away = TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toastLabel, away, {
            Position = TOAST_HOME - UDim2.fromOffset(0, 44),
            TextTransparency = 1,
            BackgroundTransparency = 1,
        }):Play()
        task.delay(0.55, function()
            if toastToken == token then
                toastLabel.Visible = false
            end
        end)
    end)
end

-- "+N" cu perla, din (fromX, fromY) spre pastila; la sosire pastila tresare si se aude.
function FairHUDController.PearlFly(fromX: number, fromY: number, amount: number)
    local gui = hud
    if gui == nil or amount <= 0 then
        return
    end
    local toX, toY = FairHUDController.PearlAnchor()
    local row = Instance.new("Frame")
    row.Name = "PearlFly"
    row.AnchorPoint = Vector2.new(0.5, 0.5)
    row.Position = UDim2.fromOffset(fromX, fromY)
    row.Size = UDim2.fromOffset(0, 30)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.BackgroundColor3 = Theme.COLOR.plate
    row.BackgroundTransparency = Theme.PLATE_TRANSPARENCY
    row.ZIndex = 18
    row.Parent = gui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = row
    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 6)
    padding.PaddingRight = UDim.new(0, 8)
    padding.Parent = row
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 5)
    layout.Parent = row
    local pearl = Widgets.PearlIcon(row, 18, 19)
    pearl.LayoutOrder = 1
    local label = Widgets.Label(row, `+{amount}`, Theme.TEXT.body, Theme.COLOR.cool, "display")
    label.LayoutOrder = 2
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, Theme.TEXT.body + 4)
    label.ZIndex = 19
    Theme.punch(label, 2)
    local duration = 0.7
    TweenService:Create(
        row,
        TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = UDim2.fromOffset(toX, toY) }
    ):Play()
    task.delay(duration, function()
        row:Destroy()
        SoundController.Play("pop")
        local scale = pearlValue:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
        scale.Parent = pearlValue
        scale.Scale = 1.25
        TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 1 }):Play()
    end)
end

-- [D61] Butonul rotund e tinut apasat (bara undiței).
function FairHUDController.IsActionHeld(): boolean
    return actionHeldBy ~= nil
end

-- [D61] Banda concursului: doua randuri, sau nil ca sa dispara. Textul se strange ca sa incapa (fontul de pixeli e lat).
function FairHUDController.SetBanner(top: string?, bottom: string?)
    if banner == nil then
        return
    end
    if top == nil then
        banner.Visible = false
        return
    end
    if bannerTop.Text ~= top then
        bannerTop.Text = top
        bannerTop.TextSize = Theme.fitSize(top, Theme.TEXT.small, "strong", BANNER_W - 20)
    end
    local second = bottom or ""
    if bannerBottom.Text ~= second then
        bannerBottom.Text = second
        bannerBottom.TextSize = Theme.fitSize(second, Theme.TEXT.small, "strong", BANNER_W - 20)
    end
    banner.Visible = true
end

function FairHUDController.Init(deps: Deps)
    hud = deps.HudGui
    pearlPill = Instance.new("Frame")
    pearlPill.Name = "PearlPill"
    pearlPill.Position = UDim2.fromOffset(Theme.SPACE.lg, Theme.SPACE.md)
    pearlPill.Size = UDim2.fromOffset(PILL_W, PILL_H)
    pearlPill.ZIndex = 12
    Widgets.PillBackground(pearlPill, 12)
    pearlPill.Parent = deps.HudGui
    local dot = Widgets.PearlIcon(pearlPill, 22, 13)
    dot.AnchorPoint = Vector2.new(0, 0.5)
    dot.Position = UDim2.fromOffset(Theme.SPACE.md, PILL_H / 2)
    pearlValue = Widgets.Label(pearlPill, "0", Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    pearlValue.AnchorPoint = Vector2.new(1, 0.5)
    pearlValue.Position = UDim2.fromOffset(PILL_W - Theme.SPACE.md, PILL_H / 2)
    pearlValue.Size = UDim2.fromOffset(PILL_W - 52, Theme.TEXT.heading + 6)
    pearlValue.TextXAlignment = Enum.TextXAlignment.Right
    pearlValue.ZIndex = 13

    toastLabel = Widgets.PlateLabel(deps.HudGui, "", Theme.TEXT.heading, "display")
    toastLabel.Name = "Toast"
    toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    toastLabel.Position = TOAST_HOME
    toastLabel.AutomaticSize = Enum.AutomaticSize.XY
    toastLabel.Size = UDim2.fromOffset(0, 46)
    toastLabel.TextXAlignment = Enum.TextXAlignment.Center
    toastLabel.TextWrapped = true
    toastLabel.TextColor3 = Theme.COLOR.gold
    toastLabel.BackgroundTransparency = 0.2
    toastLabel.Visible = false
    toastLabel.ZIndex = 16
    Theme.punch(toastLabel)
    local limit = Instance.new("UISizeConstraint")
    limit.MaxSize = Vector2.new(480, 10000)
    limit.Parent = toastLabel

    -- pe telefon: joystick-ul in stanga jos, butonul rotund in dreapta jos
    local showTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
            deps.SetStick(0, 0)
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

    local action = Instance.new("TextButton")
    action.Name = "ActionButton"
    action.AnchorPoint = Vector2.new(1, 1)
    action.Position = UDim2.new(1, -STICK_MARGIN, 1, -STICK_MARGIN)
    action.Size = UDim2.fromOffset(ACTION_SIZE, ACTION_SIZE)
    action.BackgroundColor3 = Theme.COLOR.gold
    action.BackgroundTransparency = 0.1
    action.AutoButtonColor = false
    action.Text = ""
    action.ZIndex = 10
    action.Visible = showTouch
    action.Parent = deps.HudGui
    local actionRound = Instance.new("UICorner")
    actionRound.CornerRadius = UDim.new(1, 0)
    actionRound.Parent = action
    local icon = Widgets.Icon(action, "hammer", 40)
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.5)
        icon.ZIndex = 12
    end
    action.Activated:Connect(deps.Interact)
    -- [D61] Butonul se si TINE apasat (bara undiței de la iaz), ca in sat: degetul care a apasat e urmarit pana se ridica
    -- oriunde pe ecran, altfel undita ar ramane "tinuta" singura cand degetul aluneca de pe buton.
    action.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType == Enum.UserInputType.Touch
            or input.UserInputType == Enum.UserInputType.MouseButton1
        then
            actionHeldBy = input
        end
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if input == actionHeldBy then
            actionHeldBy = nil
        end
    end)

    -- [D61] banda concursului de la iaz, sus la mijloc: doua randuri, doar cat esti aproape de iaz
    banner = Instance.new("Frame")
    banner.Name = "PondBanner"
    banner.AnchorPoint = Vector2.new(0.5, 0)
    banner.Position = UDim2.new(0.5, 0, 0, 12)
    banner.Size = UDim2.fromOffset(BANNER_W, 58)
    banner.BackgroundColor3 = Theme.COLOR.plate
    banner.BackgroundTransparency = 0.25
    banner.BorderSizePixel = 0
    banner.ZIndex = 8
    banner.Visible = false
    banner.Parent = deps.HudGui
    local bannerCorner = Instance.new("UICorner")
    bannerCorner.CornerRadius = UDim.new(0, 10)
    bannerCorner.Parent = banner
    local bannerLine = Instance.new("Frame")
    bannerLine.BackgroundColor3 = Theme.COLOR.gold
    bannerLine.BorderSizePixel = 0
    bannerLine.Size = UDim2.new(1, -20, 0, 2)
    bannerLine.Position = UDim2.fromOffset(10, 0)
    bannerLine.ZIndex = 9
    bannerLine.Parent = banner
    bannerTop = Widgets.Label(banner, "", Theme.TEXT.small, Theme.COLOR.gold, "strong")
    bannerTop.Position = UDim2.fromOffset(10, 8)
    bannerTop.Size = UDim2.new(1, -20, 0, 20)
    bannerTop.TextXAlignment = Enum.TextXAlignment.Center
    bannerTop.ZIndex = 9
    bannerBottom = Widgets.Label(banner, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    bannerBottom.Position = UDim2.fromOffset(10, 32)
    bannerBottom.Size = UDim2.new(1, -20, 0, 20)
    bannerBottom.TextXAlignment = Enum.TextXAlignment.Center
    bannerBottom.ZIndex = 9

    -- cu un panou deschis, butoanele de pe ecran se ascund (pe telefon, degetul ar apasa prin panou)
    RunService.Heartbeat:Connect(function()
        if not showTouch then
            return
        end
        local blocked = deps.PanelsOpen()
        if action.Visible == blocked then
            action.Visible = not blocked
        end
        if base.Visible == blocked then
            base.Visible = not blocked
            if blocked then
                release()
            end
        end
    end)
end

return FairHUDController
