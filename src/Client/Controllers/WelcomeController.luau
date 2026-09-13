--!strict
-- Fereastra "cat ai lipsit". Rescrisa pentru modelul cu lant: nu mai insira ce a prins fiecare
-- plasa (aia era forma veche, cu sloturi si "cea mai buna prindere"), ci spune UN SINGUR lucru --
-- cat a castigat raul tau cat ai lipsit. Banii sunt deja in punga cand fereastra se deschide:
-- serverul plateste intai si arata dupa, ca o deconectare la momentul nepotrivit sa nu coste nimic.
--
-- Apare doar daca a fost ceva de castigat. Fara Mana si fara Negustor, castigul e zero si fereastra
-- nu se arata deloc -- o fereastra care scrie "ai castigat 0" ar fi un repros, nu o veste.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local WelcomeController = {}

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
        width = 460,
        height = 260,
        z = Z,
        onClose = function() end,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false

    local amount = Widgets.Label(body, "", Theme.TEXT.title, Theme.COLOR.wood, "display")
    amount.Position = UDim2.fromOffset(0, 12)
    amount.Size = UDim2.new(1, 0, 0, 40)
    amount.TextXAlignment = Enum.TextXAlignment.Center
    amount.ZIndex = Z + 1

    local away = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.inkSoft, "body")
    away.Position = UDim2.fromOffset(0, 58)
    away.Size = UDim2.new(1, 0, 0, 26)
    away.TextXAlignment = Enum.TextXAlignment.Center
    away.TextWrapped = true
    away.ZIndex = Z + 1

    local note = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.bad, "body")
    note.Position = UDim2.fromOffset(0, 90)
    note.Size = UDim2.new(1, 0, 0, 40)
    note.TextXAlignment = Enum.TextXAlignment.Center
    note.TextWrapped = true
    note.ZIndex = Z + 1

    local button = Widgets.Button(body, {
        text = Strings.WELCOME_CONTINUE,
        width = 200,
        height = 48,
        z = Z + 1,
        onClick = function()
            root.Visible = false
        end,
    })
    button.AnchorPoint = Vector2.new(0.5, 1)
    button.Position = UDim2.fromScale(0.5, 1)

    deps.WelcomeBack.OnClientEvent:Connect(function(coins: number, seconds: number, capped: boolean)
        if coins <= 0 then
            return
        end
        amount.Text = Strings.offlineReturn(TycoonMath.formatNumber(coins))
        away.Text = Strings.welcomeAway(fmtDuration(seconds))
        note.Text = if capped then Strings.WELCOME_CAPPED else ""
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
