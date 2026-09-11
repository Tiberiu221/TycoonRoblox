--!strict
-- Debarcaderul: un singur loc fix si prefabricat unde se vinde (TycoonConfig.DOCK), nu o
-- platforma de cumparat [F0 spec 1.1, 4.5]. NetController incearca intai o colectare, apoi
-- cade aici -- un singur buton/tasta de interactiune pentru tot [F0 spec 4.4/4.5].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    Scroll: Frame,
    Remotes: { SellSack: RemoteEvent, Sold: RemoteEvent },
    CharacterPos: () -> (number, number),
}

local DockController = {}
local deps: Deps
local markerFrame: Frame
local promptLabel: TextLabel
local sackCount = 0
local sackValue = 0
local DOCK_W, DOCK_H = 112, 56

local function distanceToDock(cx: number, cy: number): number
    local dx, dy = cx - TycoonConfig.DOCK.x, cy - TycoonConfig.DOCK.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Starea vine din TycoonState, inlocuita la fiecare mesaj [F0 spec 4.1] -- doar count/value, nu
-- tot obiectul sack, ca sa fie clar exact ce foloseste debarcaderul.
function DockController.Apply(count: number, _capacity: number, value: number)
    sackCount = count
    sackValue = value
end

-- Aproape si ai ce vinde? Trage SellSack si intoarce true -- NetController.Interact() stie sa nu
-- mai caute o plasa dupa. Fara asta, apasarea E langa debarcader n-ar face nimic vizibil.
function DockController.TryInteract(): boolean
    if sackCount <= 0 then
        return false
    end
    local cx, cy = deps.CharacterPos()
    if distanceToDock(cx, cy) > RiverConfig.INTERACT_DISTANCE then
        return false
    end
    deps.Remotes.SellSack:FireServer()
    return true
end

function DockController.Init(d: Deps)
    deps = d

    markerFrame = Instance.new("Frame")
    markerFrame.Name = "Dock"
    markerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    markerFrame.Position = UDim2.fromOffset(TycoonConfig.DOCK.x, TycoonConfig.DOCK.y)
    markerFrame.Size = UDim2.fromOffset(DOCK_W, DOCK_H)
    markerFrame.BackgroundColor3 = Theme.COLOR.wood
    markerFrame.BackgroundTransparency = 0.15
    markerFrame.ZIndex = 3
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = markerFrame
    local stroke = Instance.new("UIStroke")
    stroke.Color = Theme.COLOR.woodDark
    stroke.Thickness = 3
    stroke.Parent = markerFrame
    markerFrame.Parent = deps.Scroll

    Widgets.Icon(markerFrame, "crate", 26)
    local icon = markerFrame:FindFirstChildWhichIsA("ImageLabel")
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 0)
        icon.Position = UDim2.new(0.5, 0, 0, 6)
    end
    local label = Widgets.Label(markerFrame, "Dock", Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 1)
    label.Position = UDim2.new(0.5, 0, 1, -6)
    label.Size = UDim2.fromOffset(DOCK_W - 8, 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 4
    Theme.punch(label, 2)

    promptLabel = Instance.new("TextLabel")
    promptLabel.AnchorPoint = Vector2.new(0.5, 1)
    promptLabel.Position =
        UDim2.fromOffset(TycoonConfig.DOCK.x, TycoonConfig.DOCK.y - DOCK_H / 2 - 10)
    promptLabel.Size = UDim2.fromOffset(220, 34)
    promptLabel.BackgroundColor3 = Theme.COLOR.plate
    promptLabel.BackgroundTransparency = 0.2
    promptLabel.TextColor3 = Theme.COLOR.gold
    promptLabel.TextSize = Theme.TEXT.heading
    promptLabel.ZIndex = 8
    promptLabel.Visible = false
    Theme.applyFont(promptLabel, "strong")
    Theme.punch(promptLabel)
    local pc = Instance.new("UICorner")
    pc.CornerRadius = UDim.new(0, 8)
    pc.Parent = promptLabel
    promptLabel.Parent = deps.Scroll

    RunService.PreRender:Connect(function()
        local cx, cy = deps.CharacterPos()
        local near = sackCount > 0 and distanceToDock(cx, cy) <= RiverConfig.INTERACT_DISTANCE
        if near then
            local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
            promptLabel.Text = `Sell{keyHint} — {TycoonMath.formatNumber(sackValue)}`
        end
        if promptLabel.Visible ~= near then
            promptLabel.Visible = near
        end
    end)

    deps.Remotes.Sold.OnClientEvent:Connect(function(total: number, _itemCount: number)
        -- rasplata vizibila: numarul de sus se schimba doar la urmatorul TycoonState, dar
        -- jucatorul trebuie sa vada CHIAR ACUM ca vanzarea a mers [D43]
        Widgets.FloatText(markerFrame, `+{TycoonMath.formatNumber(total)}`, Theme.COLOR.gold, 6)
    end)
end

return DockController
