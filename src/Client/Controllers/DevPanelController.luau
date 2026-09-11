--!strict
-- Consola de dezvoltare (tasta ` sau F4). Se construieste DOAR in Studio, iar serverul refuza
-- comenzile oricum in productie, deci sunt doua porti independente.
-- Fiecare buton trimite o comanda si primeste inapoi o linie, care se scrie in jurnalul de jos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)

local DevPanelController = {}
local panel: Frame
local logLabel: TextLabel
local lines: { string } = {}
local open = false
local send: (command: string, arg: unknown) -> ()

-- Paleta de mai jos e tehnica si inchisa, deliberat separata de lemn/pergament din Theme: consola
-- exista doar in Studio, nu face parte din lumea jocului, iar Theme nu are tokeni pentru un panou
-- tehnic inchis -- de-aia urmatoarele culori raman scrise de mana in acest fisier.
local BG = Color3.fromRGB(18, 22, 28)
local GROUP_COLOR = Color3.fromRGB(140, 160, 180)

local function corner(inst: Instance, radius: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = inst
end

local function pushLine(text: string)
    table.insert(lines, 1, text)
    while #lines > 9 do
        table.remove(lines)
    end
    logLabel.Text = table.concat(lines, "\n")
end

local function groupLabel(text: string, y: number)
    local l = Instance.new("TextLabel")
    l.Position = UDim2.fromOffset(16, y)
    l.Size = UDim2.fromOffset(200, 18)
    l.BackgroundTransparency = 1
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextColor3 = GROUP_COLOR
    l.TextSize = Theme.TEXT.tiny
    l.Text = string.upper(text)
    l.ZIndex = 41
    Theme.applyFont(l, "strong")
    l.Parent = panel
end

local function button(text: string, x: number, y: number, w: number, onClick: () -> ()): TextButton
    local b = Instance.new("TextButton")
    b.Position = UDim2.fromOffset(x, y)
    b.Size = UDim2.fromOffset(w, 30)
    b.BackgroundColor3 = Color3.fromRGB(44, 58, 74) -- paleta consolei, fara corespondent in Theme
    b.AutoButtonColor = false
    b.TextColor3 = Color3.fromRGB(226, 236, 245) -- paleta consolei, fara corespondent in Theme
    b.TextSize = Theme.TEXT.small
    b.TextScaled = false
    b.TextTruncate = Enum.TextTruncate.AtEnd
    b.Text = text
    b.ZIndex = 41
    Theme.applyFont(b, "strong")
    corner(b, 6)
    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = Color3.fromRGB(62, 82, 104) -- paleta consolei, fara corespondent in Theme
    end)
    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = Color3.fromRGB(44, 58, 74) -- paleta consolei, fara corespondent in Theme
    end)
    b.Activated:Connect(onClick)
    b.Parent = panel
    return b
end

-- Un rand de butoane egale, ca sa nu calculez pozitii de mana pentru fiecare
local function row(y: number, items: { { label: string, run: () -> () } })
    local total = 468
    local gap = 6
    local w = math.floor((total - gap * (#items - 1)) / #items)
    for i, item in items do
        button(item.label, 16 + (i - 1) * (w + gap), y, w, item.run)
    end
end

function DevPanelController.Toggle()
    open = not open
    if open then
        Panels.CloseOthers("dev")
    end
    panel.Visible = true
    local goal = if open then UDim2.fromOffset(16, 70) else UDim2.fromOffset(-520, 70)
    local slide = TweenService:Create(
        panel,
        TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = goal }
    )
    slide:Play()
    if not open then
        task.delay(0.25, function()
            if not open then
                panel.Visible = false
            end
        end)
    end
end

function DevPanelController.IsOpen(): boolean
    return open
end

function DevPanelController.Close()
    if open then
        DevPanelController.Toggle()
    end
end

function DevPanelController.Init(deps: {
    HudGui: Frame,
    DevCommand: RemoteEvent,
    Diagnostics: (() -> string)?,
})
    if not RunService:IsStudio() then
        return -- in productie panoul nici nu se construieste
    end
    send = function(command: string, arg: unknown)
        deps.DevCommand:FireServer(command, arg)
    end

    panel = Instance.new("Frame")
    panel.Name = "DevPanel"
    panel.Position = UDim2.fromOffset(-520, 70)
    panel.Size = UDim2.fromOffset(500, 750)
    panel.BackgroundColor3 = BG
    panel.BackgroundTransparency = 0.06
    panel.Visible = false
    panel.ZIndex = 40
    corner(panel, 12)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(90, 120, 145) -- paleta consolei, fara corespondent in Theme
    stroke.Parent = panel
    panel.Parent = deps.HudGui
    Panels.Register("dev", { isOpen = DevPanelController.IsOpen, close = DevPanelController.Close })

    local title = Instance.new("TextLabel")
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.fromOffset(468, 26)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(255, 226, 150) -- paleta consolei, fara corespondent in Theme
    title.TextSize = 20 -- fara corespondent in Theme.TEXT (30/22/18/15/13)
    title.Text = "Dev console  ·  Studio only  ·  ` to close"
    title.ZIndex = 41
    Theme.applyFont(title, "display")
    title.Parent = panel

    groupLabel("materials and pile", 46)
    row(66, {
        {
            label = "+50 mat",
            run = function()
                send("materials", 50)
            end,
        },
        {
            label = "+500 mat",
            run = function()
                send("materials", 500)
            end,
        },
        {
            label = "-25 mat",
            run = function()
                send("materials", -25)
            end,
        },
        {
            label = "+100 food",
            run = function()
                send("food", 100)
            end,
        },
        {
            label = "-100 food",
            run = function()
                send("food", -100)
            end,
        },
        {
            label = "+5 pile",
            run = function()
                send("pile", 5)
            end,
        },
        {
            label = "+25 pile",
            run = function()
                send("pile", 25)
            end,
        },
    })

    groupLabel("buildings", 106)
    row(126, {
        {
            label = "finish all sites",
            run = function()
                send("finish_sites", nil)
            end,
        },
        {
            label = "reset buildings",
            run = function()
                send("reset_buildings", nil)
            end,
        },
    })

    groupLabel("population", 166)
    row(186, {
        {
            label = "12",
            run = function()
                send("settlers", 12)
            end,
        },
        {
            label = "40",
            run = function()
                send("settlers", 40)
            end,
        },
        {
            label = "60",
            run = function()
                send("settlers", 60)
            end,
        },
        {
            label = "80",
            run = function()
                send("settlers", 80)
            end,
        },
        {
            label = "+2 people",
            run = function()
                send("add_settlers", 2)
            end,
        },
    })

    groupLabel("needs", 226)
    row(246, {
        {
            label = "fill all needs",
            run = function()
                send("fill_needs", nil)
            end,
        },
        {
            label = "drain to 18",
            run = function()
                send("drain_needs", 18)
            end,
        },
        {
            label = "drain to 0",
            run = function()
                send("drain_needs", 0)
            end,
        },
    })

    groupLabel("time scale (needs decay, boats, events)", 286)
    row(306, {
        {
            label = "×1",
            run = function()
                send("timescale", 1)
            end,
        },
        {
            label = "×10",
            run = function()
                send("timescale", 10)
            end,
        },
        {
            label = "×30",
            run = function()
                send("timescale", 30)
            end,
        },
        {
            label = "×60",
            run = function()
                send("timescale", 60)
            end,
        },
    })

    groupLabel("objectives", 346)
    row(366, {
        {
            label = "step 1",
            run = function()
                send("objective", 1)
            end,
        },
        {
            label = "step 4",
            run = function()
                send("objective", 4)
            end,
        },
        {
            label = "step 7",
            run = function()
                send("objective", 7)
            end,
        },
        {
            label = "unlock all",
            run = function()
                send("objective", 99)
            end,
        },
    })

    -- Grupul asta acopera ce s-a construit dupa consola: Indexul, meseriile cu post de lucru,
    -- plecarea cu avertisment, sosirea pe apa. Fara el, singurul mod de a le verifica era sa
    -- joci douazeci de minute pana se intampla de la sine.
    groupLabel("index, jobs, arrivals", 406)
    row(426, {
        {
            label = "index +9",
            run = function()
                send("index", 9)
            end,
        },
        {
            label = "index +18",
            run = function()
                send("index", 18)
            end,
        },
        {
            label = "all gardeners",
            run = function()
                send("job", "Gardener")
            end,
        },
        {
            label = "all crafters",
            run = function()
                send("job", "Crafter")
            end,
        },
        {
            label = "build garden",
            run = function()
                send("place", "garden")
            end,
        },
        {
            label = "build hall",
            run = function()
                send("place", "hall")
            end,
        },
        {
            label = "someone leaves",
            run = function()
                send("leave", nil)
            end,
        },
        {
            label = "boat arrives",
            run = function()
                send("arrive", nil)
            end,
        },
    })

    groupLabel("storyteller", 466)
    row(486, {
        {
            label = "random event",
            run = function()
                send("event", nil)
            end,
        },
        {
            label = "pause",
            run = function()
                send("pause_story", true)
            end,
        },
        {
            label = "resume",
            run = function()
                send("pause_story", false)
            end,
        },
        {
            label = "report",
            run = function()
                send("report", nil)
            end,
        },
    })

    -- lista completa de evenimente, ca sa poata fi declansat exact cel dorit
    local list = Instance.new("ScrollingFrame")
    list.Position = UDim2.fromOffset(16, 522)
    list.Size = UDim2.fromOffset(468, 92)
    list.BackgroundColor3 = Color3.fromRGB(26, 32, 40) -- paleta consolei, fara corespondent in Theme
    list.BorderSizePixel = 0
    list.ScrollBarThickness = 6
    list.CanvasSize = UDim2.fromOffset(0, 0)
    list.AutomaticCanvasSize = Enum.AutomaticSize.Y
    list.ZIndex = 41
    corner(list, 6)
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromOffset(148, 26)
    layout.CellPadding = UDim2.fromOffset(6, 6)
    layout.Parent = list
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 6)
    pad.PaddingLeft = UDim.new(0, 6)
    pad.Parent = list
    list.Parent = panel

    for _, e in EventConfig.EVENTS do
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(148, 26)
        b.BackgroundColor3 = Color3.fromRGB(48, 62, 78) -- paleta consolei, fara corespondent in Theme
        b.AutoButtonColor = false
        b.TextColor3 = Color3.fromRGB(220, 232, 242) -- paleta consolei, fara corespondent in Theme
        b.TextSize = Theme.TEXT.tiny
        b.Text = e.id
        b.ZIndex = 42
        Theme.applyFont(b, "strong")
        corner(b, 5)
        local eventId = e.id
        b.Activated:Connect(function()
            send("event", eventId)
        end)
        b.Parent = list
    end

    groupLabel("replies", 622)
    local logBox = Instance.new("Frame")
    logBox.Position = UDim2.fromOffset(16, 642)
    logBox.Size = UDim2.fromOffset(468, 94)
    logBox.BackgroundColor3 = Color3.fromRGB(12, 16, 20) -- paleta consolei, fara corespondent in Theme
    logBox.ZIndex = 41
    corner(logBox, 6)
    logBox.Parent = panel

    logLabel = Instance.new("TextLabel")
    logLabel.Position = UDim2.fromOffset(10, 6)
    logLabel.Size = UDim2.fromOffset(448, 82)
    logLabel.BackgroundTransparency = 1
    logLabel.TextXAlignment = Enum.TextXAlignment.Left
    logLabel.TextYAlignment = Enum.TextYAlignment.Top
    logLabel.TextColor3 = Color3.fromRGB(170, 205, 175) -- verde de terminal, paleta consolei fara corespondent in Theme
    logLabel.TextSize = Theme.TEXT.tiny
    logLabel.Text = "ready"
    logLabel.ZIndex = 42
    Theme.applyFont(logLabel, "mono") -- jurnalul trebuie sa ramana aliniat pe coloane
    logLabel.Parent = logBox

    -- Linia de performanta sta AICI, nu peste lume: e informatie pentru dezvoltator.
    local perf = Instance.new("TextLabel")
    perf.Position = UDim2.fromOffset(16, 36)
    perf.Size = UDim2.fromOffset(468, 16)
    perf.BackgroundTransparency = 1
    perf.TextXAlignment = Enum.TextXAlignment.Left
    perf.TextColor3 = Color3.fromRGB(150, 190, 230) -- paleta consolei, fara corespondent in Theme
    perf.TextSize = Theme.TEXT.tiny
    perf.Text = ""
    perf.ZIndex = 41
    Theme.applyFont(perf, "mono") -- cifrele de performanta sar in fata ochilor daca isi schimba latimea
    perf.Parent = panel
    RunService.Heartbeat:Connect(function()
        if open and deps.Diagnostics ~= nil then
            perf.Text = (deps.Diagnostics :: () -> string)()
        end
    end)

    deps.DevCommand.OnClientEvent:Connect(function(_command: string, reply: string)
        pushLine(reply)
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.F4 then
            DevPanelController.Toggle()
        end
    end)
end

return DevPanelController
