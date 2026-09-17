--!strict
-- [D60] CARDUL OBIECTULUI, in balci. Cel mai apropiat lucru din raza (roata, barca, tarabele, oamenii) isi da `Focus`,
-- iar aici se deseneaza unul singur deasupra lui: actiunea (E face exact ce scrie), sau starea lui cand nu e nimic de
-- facut -- E o spune ca toast, nu tace [D43]. Acelasi tipar ca InteractController din sat, fara platforme si Upgrade.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Panels = require(script.Parent.Panels)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Source = (number, number) -> Focus.Focus?
export type Deps = {
    World: Frame,
    Z: number,
    CharacterPos: () -> (number, number),
    OnToast: (string, Color3?) -> (),
}

local FairInteractController = {}
local deps: Deps? = nil
local sources: { Source } = {}
local card: Frame
local actionButton: TextButton
local statusLabel: TextLabel
local current: Focus.Focus? = nil
local shownAction: string? = nil

local ACTION_W, CARD_H = 240, 44
local ACTION_MAX = 380
local STATUS_MAX = 320
local SIDE = 12 -- marginea butonului, pe o parte (Widgets: BUTTON_INSET)

-- Un lucru nou din lume care are card (roata, barca, tarabele, oamenii).
function FairInteractController.AddSource(source: Source)
    table.insert(sources, source)
end

local function fitAction(text: string)
    local line = Theme.textWidth(text, Theme.TEXT.body, "strong")
    local width = math.clamp(math.ceil(line + SIDE * 2 + 8), ACTION_W, ACTION_MAX)
    actionButton.Size = UDim2.fromOffset(width, CARD_H - 4)
    Widgets.SetButtonText(actionButton, text)
end

local function fitStatus(text: string)
    local pad = Theme.SPACE.sm * 2
    local line = Theme.textWidth(text, Theme.TEXT.body, "strong")
    local width = math.clamp(math.ceil(line + pad + 8), ACTION_W, STATUS_MAX)
    local wraps = line + pad > STATUS_MAX
    local height = if wraps
        then math.max(
            CARD_H - 4,
            math.ceil(Theme.textHeight(text, Theme.TEXT.body, "strong", width - pad) + 12)
        )
        else CARD_H - 4
    statusLabel.TextWrapped = wraps
    statusLabel.Size = UDim2.fromOffset(width, height)
end

local function update()
    local d = deps
    if d == nil then
        return
    end
    if Panels.AnyOpen() then
        current = nil
        card.Visible = false
        return
    end
    local px, py = d.CharacterPos()
    local best: Focus.Focus? = nil
    for _, source in sources do
        local f = source(px, py)
        if f ~= nil and (best == nil or f.distance < (best :: Focus.Focus).distance) then
            best = f
        end
    end
    current = best
    local f = best
    if f == nil or (f.action == nil and f.status == nil) then
        card.Visible = false
        return
    end
    card.Position = UDim2.fromOffset(math.round(f.x), math.round(f.y))
    local action = f.action
    if action ~= shownAction then
        shownAction = action
        if action ~= nil then
            fitAction(action)
        end
    end
    actionButton.Visible = action ~= nil
    statusLabel.Visible = action == nil
    if action == nil and statusLabel.Text ~= f.status then
        statusLabel.Text = f.status :: string
        fitStatus(statusLabel.Text)
    end
    card.Visible = true
end

-- E si butonul rotund de pe telefon: ce scrie pe card; fara actiune, starea ca toast.
function FairInteractController.Interact()
    local f = current
    local d = deps
    if f == nil or d == nil then
        return
    end
    if f.act ~= nil then
        (f.act :: () -> ())()
    elseif f.status ~= nil then
        d.OnToast(f.status :: string)
    end
end

function FairInteractController.Init(d: Deps)
    deps = d
    card = Instance.new("Frame")
    card.Name = "InteractCard"
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.BackgroundTransparency = 1
    card.Size = UDim2.fromOffset(ACTION_MAX, CARD_H)
    card.ZIndex = d.Z
    card.Visible = false
    card.Parent = d.World
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    layout.Parent = card

    actionButton = Widgets.Button(card, {
        text = "",
        width = ACTION_W,
        height = CARD_H - 4,
        z = d.Z + 1,
        onClick = FairInteractController.Interact,
    })
    actionButton.Visible = false

    statusLabel = Widgets.PlateLabel(card, "", Theme.TEXT.body, "strong")
    statusLabel.Size = UDim2.fromOffset(ACTION_W, CARD_H - 4)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.TextColor3 = Theme.COLOR.onDarkSoft
    statusLabel.ZIndex = d.Z + 1
    statusLabel.Visible = false

    RunService.PreRender:Connect(update)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not processed and input.KeyCode == Enum.KeyCode.E then
            FairInteractController.Interact()
        end
    end)
end

return FairInteractController
