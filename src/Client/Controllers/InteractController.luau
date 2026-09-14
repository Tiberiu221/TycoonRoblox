--!strict
-- Cardul obiectului [D51]. Owner-ul: "cand te duci la un obiect vreau sa existe optiunea de upgrade, nu
-- sa existe doar de la click. pe multe obiecte exista E collect dar vreau sa arate pe care este cazul,
-- si buton de upgrade care sa deschida acel meniu mai departe."
--
-- TINTA = cel mai apropiat obiect din raza: plasa, depozit, gater, taverna, atelier, platforma de
-- meserie. Fiecare isi da `Focus(px, py)`; aici se alege unul singur si se deseneaza deasupra lui: actiunea
-- de acum doar daca are sens (altfel starea), plus Upgrade, care deschide meniul obiectului. E face exact
-- ce scrie pe card, U deschide Upgrade, iar pe telefon amandoua sunt butoane. Cartonasul de cumparare
-- al platformelor [D47] intra in aceeasi alegere: se vede doar cel mai apropiat dintre ele.
--
-- Upgrade apare dupa prima vanzare: in primul minut n-ai ce urca si ar trage atentia din bucla. Pulseaza
-- cand pasul ghidajului cere chiar upgrade-ul obiectului asta. Atingerea cladirilor ramane -- cardul e
-- al doilea drum spre acelasi meniu, nu un inlocuitor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GuideMath = require(ReplicatedStorage.Shared.Modules.GuideMath)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local NetController = require(script.Parent.NetController)
local StorageController = require(script.Parent.StorageController)
local SawmillController = require(script.Parent.SawmillController)
local DockController = require(script.Parent.DockController)
local PadController = require(script.Parent.PadController)
local ShedController = require(script.Parent.ShedController)
local ForgeController = require(script.Parent.ForgeController)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local Focus = require(script.Parent.Parent.UI.Focus)

export type Deps = {
    Plot: Frame,
    CharacterPos: () -> (number, number),
    OpenStation: (string, string?) -> (),
    -- E pe un card fara actiune spune de ce (starea lui), nu tace [D43]
    OnToast: (string) -> (),
}

export type StationRow = { kind: string, id: string?, costs: { number } }

local InteractController = {}
local deps: Deps

local card: Frame
local actionButton: TextButton
local statusLabel: TextLabel
local upgradeButton: TextButton
local upgradeScale: UIScale
local current: Focus.Focus? = nil
local shownAction: string? = nil
local shownUpgrade: string? = nil

-- ce stie din starea jocului, impins de Overlay la fiecare TycoonState
local goal: GuideMath.Goal? = nil
local firstSale = false
local coins = 0
local rows: { StationRow } = {}

local ACTION_W, UPGRADE_W, CARD_H = 240, 180, 44

local SOURCES: { (number, number) -> Focus.Focus? } = {
    NetController.Focus,
    StorageController.Focus,
    SawmillController.Focus,
    DockController.Focus,
    ShedController.Focus, -- [D55] shed-ul de scrap
    ForgeController.Focus, -- [D55] forja atelierului (si usa lui)
    PadController.FocusBuilt,
}

local function nextLevelCost(kind: string?, id: string?): number?
    if kind == nil or kind == "crew" then
        return nil
    end
    for _, row in rows do
        if row.kind == kind and row.id == id then
            return row.costs[1]
        end
    end
    return nil
end

local function hide()
    if card.Visible then
        card.Visible = false
    end
end

local function openUpgrade(): boolean
    local f = current
    if f == nil or f.upgradeKind == nil or not firstSale then
        return false
    end
    deps.OpenStation(f.upgradeKind :: string, f.upgradeId)
    return true
end

local function update()
    if Panels.AnyOpen() then
        current = nil
        PadController.SetApproachSuppressed(false)
        hide()
        return
    end
    local cx, cy = deps.CharacterPos()
    local px, py = cx - TycoonConfig.PLOT_ORIGIN.x, cy - TycoonConfig.PLOT_ORIGIN.y
    local best: Focus.Focus? = nil
    for _, source in SOURCES do
        local f = source(px, py)
        if f ~= nil and (best == nil or f.distance < (best :: Focus.Focus).distance) then
            best = f
        end
    end

    -- un card fara nimic de aratat nu ia locul cartonasului de cumparare
    local f = best
    local hasUpgrade = f ~= nil and f.upgradeKind ~= nil and firstSale
    local hasContent = f ~= nil and (f.action ~= nil or f.status ~= nil or hasUpgrade)
    local _, padDistance = PadController.ApproachCandidate()
    local objectWins = hasContent and f ~= nil and f.distance <= padDistance
    PadController.SetApproachSuppressed(objectWins)
    if not objectWins or f == nil then
        current = if hasContent then nil else f
        hide()
        return
    end
    current = f

    card.Position = UDim2.fromOffset(math.round(f.x), math.round(f.y))
    local action = f.action
    if action ~= shownAction then
        shownAction = action
        if action ~= nil then
            Widgets.SetButtonText(actionButton, action)
        end
    end
    actionButton.Visible = action ~= nil
    statusLabel.Visible = action == nil and f.status ~= nil
    if statusLabel.Visible then
        statusLabel.Text = f.status :: string
    end

    upgradeButton.Visible = hasUpgrade
    if hasUpgrade then
        local cost = nextLevelCost(f.upgradeKind, f.upgradeId)
        local text = if cost ~= nil
            then Strings.cardUpgradeCost(TycoonMath.formatNumber(cost))
            else Strings.CARD_UPGRADE
        if text ~= shownUpgrade then
            shownUpgrade = text
            Widgets.SetButtonText(upgradeButton, text)
        end
        Widgets.SetButtonTone(
            upgradeButton,
            if cost ~= nil and cost <= coins then Theme.COLOR.gold else nil
        )
        -- pasul ghidajului cere chiar upgrade-ul asta: butonul pulseaza
        local g = goal
        local wanted = g ~= nil
            and g.kind == "upgrade"
            and g.upgradeKind == f.upgradeKind
            and g.upgradeId == f.upgradeId
        upgradeScale.Scale = if wanted then 1 + 0.07 * math.abs(math.sin(os.clock() * 4)) else 1
    end
    if not card.Visible then
        card.Visible = true
    end
end

-- Impins de Overlay la fiecare stare: pasul ghidajului, prima vanzare, monedele si costurile.
function InteractController.SetContext(
    newGoal: GuideMath.Goal?,
    hasSold: boolean,
    newCoins: number,
    newRows: { StationRow }?
)
    goal = newGoal
    firstSale = hasSold
    coins = newCoins
    rows = newRows or {}
end

-- E si butonul rotund de pe telefon: ce scrie pe card; fara card, cumpararea de pe cartonas.
function InteractController.Interact()
    local f = current
    if f ~= nil and f.act ~= nil then
        (f.act :: () -> ())()
        return
    end
    if PadController.TryBuyFocused() then
        return
    end
    if f ~= nil and f.status ~= nil then
        deps.OnToast(f.status :: string)
    end
end

-- U: meniul obiectului de langa tine. Intoarce false cand nu e niciunul, ca U sa-si pastreze rostul
-- vechi (lista statiilor).
function InteractController.OpenUpgrade(): boolean
    return openUpgrade()
end

function InteractController.Init(d: Deps)
    deps = d
    card = Instance.new("Frame")
    card.Name = "InteractCard"
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.BackgroundTransparency = 1
    card.Size = UDim2.fromOffset(ACTION_W + Theme.SPACE.sm + UPGRADE_W, CARD_H)
    card.ZIndex = 30
    card.Visible = false
    card.Parent = deps.Plot
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, Theme.SPACE.sm)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    actionButton = Widgets.Button(card, {
        text = "",
        width = ACTION_W,
        height = CARD_H - 4,
        z = 31,
        onClick = InteractController.Interact,
    })
    actionButton.LayoutOrder = 1
    actionButton.Visible = false

    statusLabel = Widgets.PlateLabel(card, "", Theme.TEXT.body, "strong")
    statusLabel.Size = UDim2.fromOffset(ACTION_W, CARD_H - 4)
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.TextColor3 = Theme.COLOR.onDarkSoft
    statusLabel.LayoutOrder = 1
    statusLabel.ZIndex = 31
    statusLabel.Visible = false

    upgradeButton = Widgets.Button(card, {
        text = Strings.CARD_UPGRADE,
        icon = "levelup",
        width = UPGRADE_W,
        height = CARD_H - 4,
        z = 31,
        onClick = function()
            openUpgrade()
        end,
    })
    upgradeButton.LayoutOrder = 2
    upgradeButton.Visible = false
    upgradeScale = Instance.new("UIScale")
    upgradeScale.Parent = upgradeButton

    RunService.PreRender:Connect(update)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if not processed and input.KeyCode == Enum.KeyCode.E then
            InteractController.Interact()
        end
    end)
end

return InteractController
