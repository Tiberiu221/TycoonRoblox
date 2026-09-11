--!strict
-- Banda de eveniment: cand povestitorul face ceva, intra o carte din dreapta, sta cateva
-- secunde si iese [RIVERKEEP 6]. Evenimentele care vin peste altul se pun la coada, ca sa nu
-- se suprapuna doua texte.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local Theme = require(script.Parent.Parent.UI.Theme)

local HOLD_SECONDS = 5.5
local SLIDE = TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local EventBannerController = {}
local card: Frame
local titleLabel: TextLabel
local bodyLabel: TextLabel
local detailLabel: TextLabel
local accent: Frame
local queue: { { [string]: any } } = {}
local showing = false

type Entry = { [string]: any }

local function present(entry: Entry)
    local tone = EventConfig.TONES[entry.tone] or EventConfig.TONES.neutral
    local color = Color3.fromRGB(tone[1], tone[2], tone[3])
    titleLabel.Text = entry.title or ""
    titleLabel.TextColor3 = color
    bodyLabel.Text = entry.body or ""
    detailLabel.Text = entry.detail or ""
    detailLabel.Visible = (entry.detail or "") ~= ""
    accent.BackgroundColor3 = color

    card.Visible = true
    card.Position = UDim2.new(1, 30, 1, -170)
    local slideIn = TweenService:Create(card, SLIDE, { Position = UDim2.new(1, -456, 1, -170) })
    slideIn:Play()
    task.delay(HOLD_SECONDS, function()
        local slideOut = TweenService:Create(card, SLIDE, { Position = UDim2.new(1, 30, 1, -170) })
        slideOut:Play()
        task.delay(0.45, function()
            card.Visible = false
            showing = false
            local nextEntry = table.remove(queue, 1)
            if nextEntry ~= nil then
                showing = true
                present(nextEntry)
            end
        end)
    end)
end

function EventBannerController.Show(entry: Entry)
    if showing then
        table.insert(queue, entry)
        return
    end
    showing = true
    present(entry)
end

function EventBannerController.Init(deps: { HudGui: Frame, ColonyEvent: RemoteEvent })
    card = Instance.new("Frame")
    card.Name = "EventBanner"
    card.Position = UDim2.new(1, 30, 1, -170)
    card.Size = UDim2.fromOffset(436, 116)
    -- bleumarin inchis, fara corespondent in Theme (paleta jocului e lemn/pergament, nu tehnica);
    -- cartonasul de eveniment foloseste paleta lui proprie, ca si stroke.Color si bodyLabel mai jos
    card.BackgroundColor3 = Color3.fromRGB(22, 30, 38)
    card.BackgroundTransparency = 0.05
    card.Visible = false
    card.ZIndex = 45
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(90, 115, 140) -- aceeasi paleta bleumarin ca fundalul cartonasului, fara corespondent in Theme
    stroke.Parent = card
    card.Parent = deps.HudGui

    accent = Instance.new("Frame")
    accent.Position = UDim2.fromOffset(0, 0)
    accent.Size = UDim2.fromOffset(5, 116)
    accent.BorderSizePixel = 0
    accent.ZIndex = 46
    local ac = Instance.new("UICorner")
    ac.CornerRadius = UDim.new(0, 3)
    ac.Parent = accent
    accent.Parent = card

    local function label(y: number, size: number, color: Color3, kind: string): TextLabel
        local l = Instance.new("TextLabel")
        l.Position = UDim2.fromOffset(20, y)
        l.Size = UDim2.fromOffset(400, size + 6)
        l.BackgroundTransparency = 1
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = color
        l.TextSize = size
        l.TextTruncate = Enum.TextTruncate.AtEnd
        l.ZIndex = 46
        Theme.applyFont(l, kind)
        l.Parent = card
        return l
    end
    titleLabel = label(14, Theme.TEXT.body, Theme.COLOR.onDark, "display")
    bodyLabel = label(40, 14, Color3.fromRGB(180, 196, 212), "body") -- marimea 14 nu are corespondent in Theme.TEXT; culoarea e din aceeasi paleta bleumarin ca fundalul cartonasului
    bodyLabel.Size = UDim2.fromOffset(400, 34)
    bodyLabel.TextWrapped = true
    bodyLabel.TextYAlignment = Enum.TextYAlignment.Top
    detailLabel = label(84, 14, Theme.COLOR.gold, "strong") -- marimea 14 nu are corespondent in Theme.TEXT

    deps.ColonyEvent.OnClientEvent:Connect(function(entry: Entry)
        EventBannerController.Show(entry)
    end)
end

return EventBannerController
