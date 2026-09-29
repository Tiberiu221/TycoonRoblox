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
-- [D58] Owner-ul: "as vrea si o tasta care sa deschida meniul de upgrade la orice apare pe ecran cu upgrade". U facea
-- asta de la D51, dar nu scria nicaieri; acum butonul spune "Upgrade (U)", ca "Collect (E)", si creste dupa text.
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
local PierController = require(script.Parent.PierController)
local VillageController = require(script.Parent.VillageController)
local WheelSignpostController = require(script.Parent.WheelSignpostController)
local FerryController = require(script.Parent.FerryController)
local DriftController = require(script.Parent.DriftController)
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
    -- [2026-09-29] y-ul (pe teren) al marginii de sus a ecranului: cardul nu iese pe sus (pe telefon, cel al Pietei)
    ViewTop: (() -> number)?,
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
-- pictograma de nivel (Widgets.Button: min(28, inaltime - 10)), distanta pana la text si marginea ramei, pe o parte
local UPGRADE_ICON, UPGRADE_GAP, UPGRADE_SIDE = 28, Theme.SPACE.sm, 18

local SOURCES: { (number, number) -> Focus.Focus? } = {
    NetController.Focus,
    StorageController.Focus,
    SawmillController.Focus,
    DockController.Focus,
    ShedController.Focus, -- [D55] shed-ul de scrap
    ForgeController.Focus, -- [D55, D56] forja: lasi scrap-ul, iei fierul
    PadController.FocusBuilt,
    -- [D59] pontonul: locul de pescuit, [D60] indicatorul rotii mutate si avizierul satului -- toate cu cardul E
    PierController.Focus,
    WheelSignpostController.Focus,
    VillageController.Focus,
    FerryController.Focus, -- [D60] barca spre balci, legata in aval de ponton
    DriftController.Focus, -- [D62] darul care trece pe rau, cat e in dreptul tau
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

-- Placa cu motivul ("Logs to the sawmill, scrap to the Forge first") creste dupa text pana la STATUS_MAX_W, apoi se rupe
-- pe randuri si creste in jos. Cu latimea fixa de 240, o fraza de 452 iesea de pe placa [2026-09-15].
local STATUS_MAX_W = 320
local function fitStatus(text: string)
    local pad = Theme.SPACE.sm * 2 -- UIPadding-ul placii, stanga + dreapta
    local line = Theme.textWidth(text, Theme.TEXT.body, "strong")
    local width = math.clamp(math.ceil(line + pad + 8), ACTION_W, STATUS_MAX_W)
    local wraps = line + pad > STATUS_MAX_W
    local height = if wraps
        then math.max(
            CARD_H - 4,
            math.ceil(Theme.textHeight(text, Theme.TEXT.body, "strong", width - pad) + 12)
        )
        else CARD_H - 4
    statusLabel.TextWrapped = wraps
    statusLabel.Size = UDim2.fromOffset(width, height)
end

-- Cat de lat trebuie sa fie butonul ca eticheta sa incapa intre marginile ramei (niciodata sub latimea de baza).
local function upgradeWidth(text: string): number
    local label = Theme.textWidth(text, Theme.TEXT.body, "strong")
    return math.max(UPGRADE_W, math.ceil(UPGRADE_ICON + UPGRADE_GAP + label + UPGRADE_SIDE * 2))
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

    -- [2026-09-29] tinut in ecran: pe telefon (~460 px de teren pe inaltime) cardul Pietei si al tavernei iesea pe sus
    local y = f.y
    local viewTop = deps.ViewTop
    if viewTop ~= nil then
        y = math.max(y, viewTop() + CARD_H + 8)
    end
    card.Position = UDim2.fromOffset(math.round(f.x), math.round(y))
    local action = f.action
    if action ~= shownAction then
        shownAction = action
        if action ~= nil then
            Widgets.SetButtonText(actionButton, action)
        end
    end
    actionButton.Visible = action ~= nil
    statusLabel.Visible = action == nil and f.status ~= nil
    if statusLabel.Visible and statusLabel.Text ~= f.status then
        statusLabel.Text = f.status :: string
        fitStatus(statusLabel.Text)
    end

    upgradeButton.Visible = hasUpgrade
    if hasUpgrade then
        local cost = nextLevelCost(f.upgradeKind, f.upgradeId)
        local keyHint = if UserInputService.KeyboardEnabled then " (U)" else ""
        local text =
            Strings.cardUpgrade(if cost ~= nil then TycoonMath.formatNumber(cost) else nil, keyHint)
        if text ~= shownUpgrade then
            shownUpgrade = text
            Widgets.SetButtonText(upgradeButton, text)
            local width = upgradeWidth(text)
            upgradeButton.Size = UDim2.fromOffset(width, CARD_H - 4)
            card.Size = UDim2.fromOffset(ACTION_W + Theme.SPACE.sm + width, CARD_H)
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
-- [2026-09-29] Punctul locului al carui card e pe ecran acum (campul `at` al cardului), sau nil: ghidajul isi retrage sageata cand
-- cardul e chiar al locului spre care arata (altfel eticheta lui se desena peste butoanele cardului).
function InteractController.ShownAt(): (number?, number?)
    local f = current
    if card == nil or not card.Visible or f == nil or f.at == nil then
        return nil, nil
    end
    local at = f.at :: { x: number, y: number }
    return at.x, at.y
end

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

-- U: meniul obiectului de langa tine -- acelasi ca butonul Upgrade de pe card, si doar cand butonul se vede. Intoarce
-- false cand nu e niciunul, ca U sa-si pastreze rostul vechi (lista statiilor).
function InteractController.OpenUpgrade(): boolean
    return openUpgrade()
end

-- [D65] Un loc care nu are controllerul lui cu nume (locurile unei linii din LineController) isi adauga aici sursa de
-- `Focus`, la pornire. Lista de mai sus ramane a locurilor Erei 1.
function InteractController.AddSource(source: (number, number) -> Focus.Focus?)
    table.insert(SOURCES, source)
end

function InteractController.Init(d: Deps)
    deps = d
    card = Instance.new("Frame")
    card.Name = "InteractCard"
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.BackgroundTransparency = 1
    card.Size = UDim2.fromOffset(ACTION_W + Theme.SPACE.sm + UPGRADE_W, CARD_H)
    card.ZIndex = 48 -- [D67, audit] peste textul lumii (nume 46, placi si replici 47): e interfata, se apasa
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
        text = Strings.cardUpgrade(nil, ""),
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
