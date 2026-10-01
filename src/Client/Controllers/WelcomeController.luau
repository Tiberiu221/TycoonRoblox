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
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)

local ShopPanel = require(script.Parent.ShopPanel)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local WelcomeController = {}
-- [D61, partea 2] `Double it`: produsul Welcome Back x2 se vinde DOAR aici (nota 41), o data pentru fiecare revenire.
-- Butonul apare doar daca produsul exista pe universul asta si chiar e ceva de dublat.
local onDoubled: ((number) -> ())? = nil
local window: GuiObject? = nil

local WIDTH = 460
-- incape varianta cea mai lunga: suma, durata, ce a venit la ponton, nota curbei (doua randuri) si [D71] seria zilnica,
-- cu ~10 px pana la butoane (la 366 ramanea ~1,5 px: verificator, 2026-10-01)
local HEIGHT = 384
local BUTTON_H = 48
local COIN = 30

-- [D71] cu zile: fereastra spune acum cat ai lipsit cu adevarat, nu cat a lucrat satul (72 h scria "72h 0min")
local function fmtDuration(seconds: number): string
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then
        return if h > 0 then `{d}d {h}h` else (if d == 1 then "1 day" else `{d} days`)
    end
    if h > 0 then
        return `{h}h {m}min`
    end
    return if m > 0 then `{m} min` else "a moment"
end

-- Serverul a dublat suma (RobuxResult pentru `welcome2x`): fereastra, daca mai e deschisa, arata noul total.
function WelcomeController.OnDoubled(coins: number)
    local fn = onDoubled
    if fn ~= nil then
        fn(coins)
    end
end

-- [2026-09-30] Fereastra de revenire e pe ecran (nu e in Panels): anunturile cu buton o asteapta, ca pe un meniu.
function WelcomeController.IsOpen(): boolean
    local w = window
    return w ~= nil and w.Visible
end

function WelcomeController.Init(deps: {
    HudGui: Frame,
    WelcomeBack: RemoteEvent,
    RobuxBuy: RemoteEvent?,
})
    local Z = 150
    local root, body = Widgets.Window(deps.HudGui, {
        name = "WelcomeBack",
        title = Strings.WELCOME_TITLE,
        icon = "clock",
        width = WIDTH,
        height = HEIGHT,
        z = Z,
        -- [2026-09-30] X-ul inchide fereastra, ca butonul de jos (anunturile o asteapta)
        onClose = function()
            local w = window
            if w ~= nil then
                w.Visible = false
            end
        end,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false
    window = root

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
    -- [D71] nota curbei: nu in rosu, nu e o pedeapsa [P2, nota 16]
    local note = line(5, Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    note.Size = UDim2.fromScale(1, 0)
    note.AutomaticSize = Enum.AutomaticSize.Y
    note.TextWrapped = true
    -- [D71] seria zilnica, cand e ceva de spus
    local streakLine = line(6, Theme.TEXT.body, Theme.COLOR.wood, "strong")

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

    -- [D61, partea 2] `Double it`, in dreapta lui `Back to the river`: doua butoane de 200 cu 8 intre ele incap in corp
    local shownCoins = 0
    local double = Widgets.Button(body, {
        text = Strings.welcomeDouble(nil),
        width = 200,
        height = BUTTON_H,
        z = Z + 1,
        onClick = function()
            local buy = deps.RobuxBuy
            if buy ~= nil then
                SoundController.Play("click")
                buy:FireServer("welcome2x")
            end
        end,
    })
    double.AnchorPoint = Vector2.new(0.5, 1)
    double.Position = UDim2.new(0.5, 104, 1, 0)
    double.Visible = false
    -- [D63] Butonul GRATUIT e cel auriu, nu cel pe Robux. Pana acum era invers: `Double it` stralucea langa un
    -- `Back to the river` sters, adica drumul platit era cel care sarea in ochi. Pentru un public de copii, regulile
    -- Roblox de monetizare si codul britanic pentru copii (ICO, „nudge techniques") cer ca o cumparare sa fie o alegere
    -- limpede si negrabita, nu calea pe care te impinge culoarea. Oferta ramane la vedere, cu pretul pe ea.
    Widgets.SetButtonTone(button, Theme.COLOR.gold)
    local function showDouble(visible: boolean)
        double.Visible = visible
        button.Position = if visible then UDim2.new(0.5, -104, 1, 0) else UDim2.fromScale(0.5, 1)
        if visible then
            Widgets.SetButtonText(double, Strings.welcomeDouble(ShopPanel.PriceOf("welcome2x")))
        end
    end
    ShopPanel.OnPrice(function()
        if double.Visible then
            Widgets.SetButtonText(double, Strings.welcomeDouble(ShopPanel.PriceOf("welcome2x")))
        end
    end)

    local function fit()
        local width = root.Size.X.Offset - Theme.SPACE.lg * 2
        lead.TextSize = Theme.fitSize(lead.Text, Theme.TEXT.heading, "display", width)
        amount.TextSize =
            Theme.fitSize(amount.Text, Theme.TEXT.title, "display", width - COIN - Theme.SPACE.sm)
        away.TextSize = Theme.fitSize(away.Text, Theme.TEXT.body, "body", width)
        river.TextSize = Theme.fitSize(river.Text, Theme.TEXT.body, "strong", width)
        streakLine.TextSize = Theme.fitSize(streakLine.Text, Theme.TEXT.body, "strong", width)
    end
    -- fereastra se strange la rotirea telefonului (Widgets.Window), iar textul odata cu ea
    root:GetPropertyChangedSignal("Size"):Connect(fit)

    onDoubled = function(extra: number)
        showDouble(false)
        if not root.Visible then
            return
        end
        shownCoins += extra
        amount.Text = TycoonMath.formatNumber(shownCoins)
        note.Text = Strings.WELCOME_DOUBLED
        note.TextColor3 = Theme.COLOR.good
        note.Visible = true
        fit()
    end

    -- [D71] un singur tabel de la server (StationService.WelcomeInfo), copiat camp cu camp: un camp necunoscut sau
    -- stricat cade pe ceva cinstit, nu pe nil
    local function num(x: unknown): number
        return if typeof(x) == "number" and x == x then x else 0
    end
    deps.WelcomeBack.OnClientEvent:Connect(function(raw: unknown)
        local info: any = if typeof(raw) == "table" then raw else {}
        local coins = num(info.coins)
        local things = num(info.arrived)
        local awaySeconds = num(info.away)
        local phase = if typeof(info.phase) == "string" then info.phase else "full"
        local fullHours = if num(info.fullHours) > 0
            then num(info.fullHours)
            else PassMath.OFFLINE_HOURS
        local stopHours = if num(info.stopHours) > 0
            then num(info.stopHours)
            else PassMath.OFFLINE_STOP_HOURS
        local rawStreak: any = info.streak
        local streakText = ""
        if typeof(rawStreak) == "table" then
            local run, best = num(rawStreak.run), num(rawStreak.best)
            local title = if typeof(rawStreak.title) == "string" then rawStreak.title else nil
            if rawStreak.event == "next" and run >= 2 then
                streakText = Strings.streakNext(run, rawStreak.record == true, title)
            elseif rawStreak.event == "broke" and best >= 2 then
                streakText = Strings.streakAgain(best)
            end
        end
        if coins <= 0 and things <= 0 and streakText == "" then
            return
        end
        -- [D59] fara monede, dar cu ceva la ponton: titlul e raul, nu "ai castigat 0"; [D71] doar seria: un salut
        lead.Text = if coins > 0
            then Strings.WELCOME_EARNED
            elseif things > 0 then Strings.WELCOME_RIVER_TITLE
            else Strings.WELCOME_STREAK_TITLE
        amount.Text = TycoonMath.formatNumber(coins)
        amountRow.Visible = coins > 0
        away.Text = Strings.welcomeAway(fmtDuration(awaySeconds))
        away.Visible = awaySeconds >= 60
        river.Text = if things > 0 then Strings.welcomeArrived(things) else ""
        river.Visible = things > 0
        -- [D71] cat ai lipsit peste viteza intreaga: curba spusa pe nume (8 h, sau 16 cu Long Nights; apoi 24 h)
        note.Text = if coins <= 0
            then ""
            elseif phase == "rested" then Strings.welcomeRested(fullHours, stopHours)
            elseif phase == "slow" then Strings.welcomeSlow(fullHours, stopHours)
            else ""
        note.TextColor3 = Theme.COLOR.inkSoft
        note.Visible = note.Text ~= ""
        streakLine.Text = streakText
        streakLine.Visible = streakText ~= ""
        shownCoins = coins
        showDouble(deps.RobuxBuy ~= nil and coins >= 1 and ShopPanel.Exists("welcome2x"))
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
    end)
end

return WelcomeController
