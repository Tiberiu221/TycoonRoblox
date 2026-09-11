--!strict
-- Ecranul "Welcome back": ce au prins plasele cat ai lipsit [MASTERPLAN 5.2, DECIZII D15]
local Theme = require(script.Parent.Parent.UI.Theme)

local WelcomeController = {}

local function fmtDuration(seconds: number): string
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    return if h > 0 then `{h}h {m}min` else `{m} min`
end

function WelcomeController.Init(deps: {
    HudGui: Frame,
    WelcomeBack: RemoteEvent,
    CollectNet: RemoteEvent,
})
    deps.WelcomeBack.OnClientEvent:Connect(function(summary: { [string]: any })
        local panel = Instance.new("Frame")
        panel.AnchorPoint = Vector2.new(0.5, 0.5)
        panel.Position = UDim2.fromOffset(960, 480)
        panel.Size = UDim2.fromOffset(640, 300)
        -- bleumarin inchis, fara corespondent in Theme (paleta jocului e lemn/pergament, nu tehnica)
        panel.BackgroundColor3 = Color3.fromRGB(28, 40, 52)
        panel.ZIndex = 20
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = panel
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 3
        stroke.Color = Theme.COLOR.gold
        stroke.Parent = panel

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -40, 0, 50)
        title.Position = UDim2.fromOffset(20, 16)
        title.BackgroundTransparency = 1
        title.TextSize = Theme.TEXT.title
        title.TextColor3 = Theme.COLOR.onDark
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Text = `Welcome back! You were away {fmtDuration(summary.awaySeconds)}`
        title.ZIndex = 21
        Theme.applyFont(title, "display")
        title.Parent = panel

        local lines = {}
        for _, net in summary.nets do
            table.insert(
                lines,
                `Net {net.slotId}: caught {net.items} items (best: {net.best}){if net.full
                    then " — FULL"
                    else ""}`
            )
        end
        if summary.cappedByCapacity then
            table.insert(lines, "A net is full — empty it so it keeps catching.")
        elseif summary.cappedByTime then
            table.insert(lines, "Nets stop after 24h away. Come back more often!")
        end
        local body = Instance.new("TextLabel")
        body.Size = UDim2.new(1, -40, 0, 150)
        body.Position = UDim2.fromOffset(20, 70)
        body.BackgroundTransparency = 1
        body.TextSize = Theme.TEXT.heading
        body.TextColor3 = Theme.COLOR.onDark
        body.TextXAlignment = Enum.TextXAlignment.Left
        body.TextYAlignment = Enum.TextYAlignment.Top
        body.TextWrapped = true
        body.Text = table.concat(lines, "\n")
        body.ZIndex = 21
        Theme.applyFont(body, "body")
        body.Parent = panel

        local button = Instance.new("TextButton")
        button.AnchorPoint = Vector2.new(0.5, 1)
        button.Position = UDim2.new(0.5, 0, 1, -18)
        button.Size = UDim2.fromOffset(260, 50)
        button.BackgroundColor3 = Theme.COLOR.gold
        button.TextSize = 24 -- fara corespondent in Theme.TEXT (30/22/18/15/13)
        button.TextColor3 = Theme.COLOR.ink
        button.Text = "Collect all"
        button.Selectable = true
        button.ZIndex = 21
        Theme.applyFont(button, "strong")
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 10)
        bc.Parent = button
        button.Activated:Connect(function()
            for _, net in summary.nets do
                deps.CollectNet:FireServer(net.netId)
            end
            panel:Destroy()
        end)
        button.Parent = panel
        panel.Parent = deps.HudGui
    end)
end

return WelcomeController
