--!strict
-- HUD-ul permanent: doar ce trebuie sa vada jucatorul TOT timpul [DECIZII D05].
--
-- Ce s-a scos de aici si de ce: linia de fps, linia de diagnostic si sirul de taste stateau
-- permanent peste lume. Un ecran incarcat cu text plutitor e tiparul cel mai des reclamat pe
-- jocurile care pierd jucatori in primul minut. Diagnosticul a plecat in consola de dezvoltare,
-- unde ii e locul; tastele se invata din obiective, la momentul potrivit.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local HUDController = {}
local chips: { [string]: TextLabel } = {}
local alertButton: TextButton
local alertLabel: TextLabel
local alertClick: (() -> ())? = nil
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
    VisibleCount: () -> number,
    SettlerCount: (() -> number)?,
    Diagnostics: (() -> string)?,
    SetStick: (number, number) -> (),
    Interact: () -> (),
    PanelsOpen: (() -> boolean)?,
})
    -- Cipurile de resurse: pictograma plus numar. Numarul singur nu spune ce reprezinta.
    local bar = Instance.new("Frame")
    bar.Name = "ResourceBar"
    bar.BackgroundTransparency = 1
    bar.Position = UDim2.fromOffset(Theme.SPACE.lg, Theme.SPACE.md)
    bar.Size = UDim2.fromOffset(600, 40)
    bar.ZIndex = 12
    bar.Parent = deps.HudGui
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.Parent = bar

    -- Numele lipseau cu totul: cinci pictograme si cinci cifre, iar "gramada" nu se ghiceste
    -- dintr-o iconita. Cuvintele sunt cele din lume, nu din cod -- "Salvage", nu "pile".
    for i, spec in
        {
            { key = "food", icon = "food", name = "Food" },
            { key = "materials", icon = "materials", name = "Materials" },
            { key = "pile", icon = "crate", name = "Salvage" },
            { key = "people", icon = "people", name = "People" },
            { key = "beds", icon = "bed", name = "Beds" },
        }
    do
        local chip, value = Widgets.Chip(bar, spec.icon, 12, spec.name)
        chip.LayoutOrder = i
        chip.Size = UDim2.fromOffset(104, 52)
        chips[spec.key] = value
    end

    -- Alerta de administrator: apare doar cand chiar e nevoie de tine, si duce direct la panou.
    alertButton = Instance.new("TextButton")
    alertButton.Name = "Alert"
    alertButton.Position = UDim2.fromOffset(Theme.SPACE.lg, 74) -- randul de cifre a crescut de la 40 la 52
    alertButton.Size = UDim2.fromOffset(300, 40)
    alertButton.BackgroundColor3 = Theme.COLOR.bad
    alertButton.BackgroundTransparency = 0.12
    alertButton.AutoButtonColor = false
    alertButton.Text = ""
    alertButton.Visible = false
    alertButton.ZIndex = 13
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0, 8)
    ac.Parent = alertButton
    alertButton.Parent = deps.HudGui
    alertLabel = Widgets.Label(alertButton, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    alertLabel.Position = UDim2.fromOffset(Theme.SPACE.md, 0)
    alertLabel.Size = UDim2.new(1, -Theme.SPACE.md * 2, 1, 0)
    alertLabel.ZIndex = 14
    alertButton.Activated:Connect(function()
        if alertClick ~= nil then
            alertClick()
        end
    end)

    -- Mesajele scurte stau in TREIMEA DE SUS, centrat, si urca stingandu-se -- pozitia clasica
    -- de "Not enough gold!" din jocurile mobile de constructie.
    -- Erau jos-centru, la -150 px: exact peste caseta de dialog si peste d-pad-ul de telefon.
    -- Replici de personaj ("X arrived by boat") apareau acolo in stil de notificare, deci parea
    -- un al doilea sistem de dialog, in formatul vechi. Sus e liber la orice latime de ecran.
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

-- Cifra care se schimba, aratata LANGA cifra. Fara asta, dai Scrap si undeva sus, in alt colt
-- al ecranului, un numar creste in tacere: actiunea si urmarea ei nu se leaga niciodata in
-- mintea jucatorului. E acelasi truc din jocurile mobile de constructie -- si e jumatate din
-- motivul pentru care acolo se intelege imediat ce face fiecare buton.
local function floatDelta(label: TextLabel, delta: number)
    local chip = label.Parent
    if chip == nil or not chip:IsA("GuiObject") then
        return
    end
    local up = delta > 0
    local tag = Instance.new("TextLabel")
    tag.Name = "Delta"
    tag.BackgroundTransparency = 1
    tag.AnchorPoint = Vector2.new(0.5, 1)
    tag.Position = UDim2.fromScale(0.5, 0)
    tag.Size = UDim2.fromOffset(90, 24)
    tag.TextColor3 = if up then Theme.COLOR.good else Theme.COLOR.bad
    tag.TextSize = Theme.TEXT.body
    tag.Text = if up then `+{delta}` else tostring(delta)
    tag.ZIndex = 30
    Theme.applyFont(tag, "display")
    Theme.punch(tag, 2)
    tag.Parent = chip

    local rise = TweenService:Create(
        tag,
        TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(0.5, 0, 0, -26), TextTransparency = 1 }
    )
    rise:Play()
    task.delay(1, function()
        tag:Destroy()
    end)
end

-- Resursele se ACUMULEAZA fractionar pe server (hrana = FISH_FOOD * multiplicatorul de
-- trasatura al colonistului), dar jucatorul numara in bucati. Fara rotunjire, chipul arata
-- "45.700000" -- adica valoarea reala 45.70000000000001, taiata de latimea etichetei.
local lastChip: { [string]: number } = {}

local function setChip(key: string, value: number)
    local label = chips[key]
    if label == nil then
        return
    end
    local whole = math.floor(value)
    local text = tostring(whole)
    if label.Text ~= text then
        label.Text = text
    end
    local before = lastChip[key]
    lastChip[key] = whole
    -- prima valoare e doar incarcarea profilului, nu o schimbare pe care a facut-o jucatorul
    if before == nil or before == whole then
        return
    end
    floatDelta(label, whole - before)
end

function HUDController.SetWorkshop(pile: number, _repaired: number, materials: number)
    setChip("pile", pile)
    setChip("materials", materials)
end

function HUDController.SetColony(people: number, beds: number)
    setChip("people", people)
    setChip("beds", beds)
end

-- Hrana isi schimba culoarea inainte sa se termine: un numar care scade nu se observa,
-- unul care devine rosu, da.
function HUDController.SetFood(food: number, hungry: boolean)
    setChip("food", food)
    local label = chips.food
    if label == nil then
        return
    end
    local color = if hungry or food <= 0
        then Theme.COLOR.bad
        elseif food < 20 then Theme.COLOR.warn
        else Theme.COLOR.onDark
    if label.TextColor3 ~= color then
        label.TextColor3 = color
    end
end

function HUDController.SetInventory(_inventory: { [string]: number }) end

function HUDController.SetAlert(count: number, label: string?, onClick: (() -> ())?)
    if alertButton == nil then
        return
    end
    if count <= 0 then
        if alertButton.Visible then
            alertButton.Visible = false
        end
        return
    end
    alertButton.Visible = true
    alertLabel.Text = label or `{count} settlers need help`
    alertClick = onClick
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
