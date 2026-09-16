--!strict
-- Fereastra "cat ai lipsit". Rescrisa pentru modelul cu lant: nu mai insira ce a prins fiecare
-- plasa (aia era forma veche, cu sloturi si "cea mai buna prindere"), ci spune UN SINGUR lucru --
-- cat a castigat raul tau cat ai lipsit. Banii sunt deja in punga cand fereastra se deschide:
-- serverul plateste intai si arata dupa, ca o deconectare la momentul nepotrivit sa nu coste nimic.
--
-- Apare doar daca a fost ceva de castigat. Fara Mana si fara Negustor, castigul e zero si fereastra
-- nu se arata deloc -- o fereastra care scrie "ai castigat 0" ar fi un repros, nu o veste.
--
-- [vazut in Studio, 2026-09-15] "Your river earned 42 while you were away." la marimea titlului avea 687 de unitati
-- intr-un corp de 420 si iesea din rama: fontul de pixeli are 0.56 em pe litera. Suma sta acum pe randul ei, cu
-- moneda, iar fiecare rand se strange singur daca tot nu incape (fereastra se ingusteaza pe ecranele mici).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local WelcomeController = {}

local WIDTH = 460
local HEIGHT = 330 -- incape varianta cea mai lunga: suma, durata, ce a venit la ponton si nota de plafon
local BUTTON_H = 48
local COIN = 30

local function fmtDuration(seconds: number): string
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if h > 0 then
        return `{h}h {m}min`
    end
    return if m > 0 then `{m} min` else "a moment"
end

function WelcomeController.Init(deps: { HudGui: Frame, WelcomeBack: RemoteEvent })
    local Z = 150
    local root, body = Widgets.Window(deps.HudGui, {
        name = "WelcomeBack",
        title = Strings.WELCOME_TITLE,
        icon = "clock",
        width = WIDTH,
        height = HEIGHT,
        z = Z,
        onClose = function() end,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false

    -- Randurile stau intr-o coloana centrata deasupra butonului; cele goale se ascund si nu lasa gol.
    local column = Instance.new("Frame")
    column.Name = "Lines"
    column.BackgroundTransparency = 1
    column.AnchorPoint = Vector2.new(0.5, 0.5)
    column.Position = UDim2.new(0.5, 0, 0.5, -BUTTON_H / 2)
    column.Size = UDim2.fromScale(1, 0)
    column.AutomaticSize = Enum.AutomaticSize.Y
    column.ZIndex = Z + 1
    column.Parent = body
    local stack = Instance.new("UIListLayout")
    stack.FillDirection = Enum.FillDirection.Vertical
    stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
    stack.SortOrder = Enum.SortOrder.LayoutOrder
    stack.Padding = UDim.new(0, Theme.SPACE.xs + 2)
    stack.Parent = column

    local function line(order: number, size: number, color: Color3, kind: string): TextLabel
        local l = Widgets.Label(column, "", size, color, kind)
        l.Size = UDim2.new(1, 0, 0, size + 8)
        l.TextXAlignment = Enum.TextXAlignment.Center
        l.LayoutOrder = order
        l.ZIndex = Z + 1
        return l
    end

    local lead = line(1, Theme.TEXT.heading, Theme.COLOR.ink, "display")

    local amountRow = Instance.new("Frame")
    amountRow.Name = "Amount"
    amountRow.BackgroundTransparency = 1
    amountRow.Size = UDim2.new(1, 0, 0, Theme.TEXT.title + 10)
    amountRow.LayoutOrder = 2
    amountRow.ZIndex = Z + 1
    amountRow.Parent = column
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Padding = UDim.new(0, Theme.SPACE.sm)
    rowLayout.Parent = amountRow
    local coin = Widgets.CoinIcon(amountRow, COIN, Z + 2)
    coin.LayoutOrder = 1
    local amount = Widgets.Label(amountRow, "", Theme.TEXT.title, Theme.COLOR.wood, "display")
    amount.AutomaticSize = Enum.AutomaticSize.X
    amount.Size = UDim2.fromOffset(0, Theme.TEXT.title + 8)
    amount.LayoutOrder = 2
    amount.ZIndex = Z + 2

    local away = line(3, Theme.TEXT.body, Theme.COLOR.inkSoft, "body")
    -- [D59] ce a venit pe rau cat ai lipsit
    local river = line(4, Theme.TEXT.body, Theme.COLOR.wood, "strong")
    local note = line(5, Theme.TEXT.small, Theme.COLOR.bad, "body")
    note.Size = UDim2.fromScale(1, 0)
    note.AutomaticSize = Enum.AutomaticSize.Y
    note.TextWrapped = true

    local button = Widgets.Button(body, {
        text = Strings.WELCOME_CONTINUE,
        width = 200,
        height = BUTTON_H,
        z = Z + 1,
        onClick = function()
            root.Visible = false
        end,
    })
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.Position = UDim2.fromScale(0.5, 1)

    local function fit()
        local width = root.Size.X.Offset - Theme.SPACE.lg * 2
        lead.TextSize = Theme.fitSize(lead.Text, Theme.TEXT.heading, "display", width)
        amount.TextSize =
            Theme.fitSize(amount.Text, Theme.TEXT.title, "display", width - COIN - Theme.SPACE.sm)
        away.TextSize = Theme.fitSize(away.Text, Theme.TEXT.body, "body", width)
        river.TextSize = Theme.fitSize(river.Text, Theme.TEXT.body, "strong", width)
    end
    -- fereastra se strange la rotirea telefonului (Widgets.Window), iar textul odata cu ea
    root:GetPropertyChangedSignal("Size"):Connect(fit)

    deps.WelcomeBack.OnClientEvent:Connect(
        function(coins: number, seconds: number, capped: boolean, arrived: number?)
            local things = if typeof(arrived) == "number" then arrived else 0
            if coins <= 0 and things <= 0 then
                return
            end
            -- [D59] fara monede, dar cu ceva la ponton: titlul e raul, nu "ai castigat 0"
            lead.Text = if coins > 0 then Strings.WELCOME_EARNED else Strings.WELCOME_RIVER_TITLE
            amount.Text = TycoonMath.formatNumber(coins)
            amountRow.Visible = coins > 0
            away.Text = Strings.welcomeAway(fmtDuration(seconds))
            river.Text = if things > 0 then Strings.welcomeArrived(things) else ""
            river.Visible = things > 0
            note.Text = if capped and coins > 0 then Strings.WELCOME_CAPPED else ""
            note.Visible = note.Text ~= ""
            fit()
            root.Visible = true
            SoundController.Play("chime")
            -- o mica intrare: fereastra care apare dintr-o data se citeste ca o eroare
            local scale = Instance.new("UIScale")
            scale.Scale = 0.9
            scale.Parent = root
            TweenService:Create(
                scale,
                TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                { Scale = 1 }
            ):Play()
            task.delay(0.5, function()
                scale:Destroy()
            end)
        end
    )
end

return WelcomeController
