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
    -- stratul lumii (CameraController, "Scroll"): cardul sta peste teren si peste ghidaj; pozitia e cea din teren
    -- mutata cu PLOT_ORIGIN
    Scroll: Frame,
    CharacterPos: () -> (number, number),
    OpenStation: (string, string?) -> (),
    -- E pe un card fara actiune spune de ce (starea lui), nu tace [D43]
    OnToast: (string) -> (),
    -- [2026-09-29] y-ul (pe teren) al marginii de sus a ecranului: cardul nu iese pe sus (pe telefon, cel al Pietei)
    ViewTop: (() -> number)?,
    -- [2026-09-30] o privire "Look (V)" tine camera departe de tine: niciun card, iar E nu apuca nimic nevazut
    Looking: (() -> boolean)?,
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
-- [verificatorul D76] panza HUD si trecerea din lume in ea (SetHud, din Bootstrap): cardul ocoleste panourile fixe
local hud: { WorldToHud: (number, number) -> (number, number), HudGui: Frame }? = nil
-- locul cardului din cadrul trecut (GuideMath.cardPlacement il tine cat e liber) si al cui card era
local cardKey: string? = nil
local cardOf: string? = nil

-- ce stie din starea jocului, impins de Overlay la fiecare TycoonState
local goal: GuideMath.Goal? = nil
local firstSale = false
local coins = 0
local rows: { StationRow } = {}

local ACTION_W, UPGRADE_W, CARD_H = 240, 180, 44
-- [verificatorul D76] sub obiect: cat de jos de picioarele tale (sau de punctul locului) incepe cardul
local CARD_BELOW = 20
local CARD_Z = 12 -- in Scroll: peste teren (5) si ghidaj (9), sub pasari (60)
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

-- [verificatorul D76] cardul ascuns doar cat e deschis un meniu, tine o privire Look sau tii E: isi pastreaza locul, ca
-- dupa ce inchizi meniul Upgrade butonul sa fie unde l-ai lasat
local function conceal()
    if card.Visible then
        card.Visible = false
    end
end

local function hide()
    cardKey, cardOf = nil, nil -- [verificatorul D76] urmatorul card incepe de la locul lui firesc
    conceal()
end

-- Placa cu motivul ("Logs to the sawmill, scrap to the Forge first") creste dupa text pana la STATUS_MAX_W, apoi se rupe
-- pe randuri si creste in jos. Cu latimea fixa de 240, o fraza de 452 iesea de pe placa [2026-09-15].
-- [verificatorul D76] Randurile echilibrate (GuideMath.balancedWidth, ca eticheta ghidajului): „Sack full — take the” /
-- „planks to the Tavern”, nu „...the planks to” / „the Tavern”, iar placa se ingusteaza cat textul. Cei 8 px de rezerva:
-- sub UIScale, Roblox poate rupe cu o fractiune de pixel mai devreme decat masuratoarea.
local STATUS_MAX_W = 320
local function fitStatus(text: string)
    local pad = Theme.SPACE.sm * 2 -- UIPadding-ul placii, stanga + dreapta
    local line = Theme.textWidth(text, Theme.TEXT.body, "strong")
    local wraps = line + pad > STATUS_MAX_W
    local width = math.clamp(math.ceil(line + pad + 8), ACTION_W, STATUS_MAX_W)
    local height = CARD_H - 4
    if wraps then
        local function heightAt(w: number): number
            return Theme.textHeight(text, Theme.TEXT.body, "strong", w)
        end
        local textW = GuideMath.balancedWidth(heightAt, STATUS_MAX_W - pad, line / 2)
        width = math.max(ACTION_W, textW + pad + 8)
        height = math.max(CARD_H - 4, math.ceil(heightAt(textW) + 12))
    end
    statusLabel.TextWrapped = wraps
    statusLabel.Size = UDim2.fromOffset(width, height)
end

-- [verificatorul D76] Cat ocupa ce se vede pe card (butonul sau placa, plus Upgrade), in unitatile lumii. UIListLayout il
-- centreaza pe mijlocul cardului, si pe orizontala, si pe verticala.
local function contentSize(): (number, number)
    local left = if actionButton.Visible
        then actionButton.Size.X.Offset
        elseif statusLabel.Visible then statusLabel.Size.X.Offset
        else 0
    local up = if upgradeButton.Visible then upgradeButton.Size.X.Offset else 0
    local width = left + up + (if left > 0 and up > 0 then Theme.SPACE.sm else 0)
    local height =
        math.max(CARD_H - 4, if statusLabel.Visible then statusLabel.Size.Y.Offset else 0)
    return width, height
end

-- [verificatorul D76] Panourile FIXE ale HUD-ului (atributul GuideBlocker: cifrele din stanga-sus, bara de meniu, joystick-ul
-- si butonul E pe telefon), in coordonatele panzei. Toast-urile si bannerele sunt trecatoare: n-au voie sa mute cardul.
local function fixedBlockers(canvas: Frame): { GuideMath.Rect }
    local width = canvas.Size.X.Offset
    local scale = if width > 0 then canvas.AbsoluteSize.X / width else 1
    if scale <= 0 then
        scale = 1
    end
    local origin = canvas.AbsolutePosition
    local out: { GuideMath.Rect } = {}
    for _, child in canvas:GetChildren() do
        if
            child:IsA("GuiObject")
            and child.Visible
            and child:GetAttribute("GuideBlocker") == true
        then
            -- [verificatorul D76] fara scara trecatoare a panoului (pulsul pastilei Sack cand traista se umple): altfel
            -- cardul E fugea sub picioare fara niciun pas
            local pulse = child:FindFirstChildOfClass("UIScale")
            local k = if pulse ~= nil and pulse.Scale > 0 then pulse.Scale else 1
            local size = child.AbsoluteSize / (scale * k)
            local pos = (child.AbsolutePosition - origin) / scale
            table.insert(out, { x = pos.X, y = pos.Y, w = size.X, h = size.Y })
        end
    end
    return out
end

-- [verificatorul D76] Unde sta cardul: deasupra obiectului, ca pana acum; langa coltul cu cifre (pe telefon) mutat pe langa
-- el sau sub obiect (GuideMath.cardPlacement). Fara panza HUD (inainte de SetHud), deasupra.
local function place(f: Focus.Focus, y: number): (number, number)
    local h = hud
    if h == nil then
        return f.x, y
    end
    local w, ht = contentSize()
    local mid = y - CARD_H / 2
    local cx, top = h.WorldToHud(f.x, mid - ht / 2)
    local rx = h.WorldToHud(f.x + 100, mid)
    local perWorld = (rx - cx) / 100 -- unitati de panza pe px de lume
    if perWorld <= 0 or w <= 0 then
        return f.x, y
    end
    local _, py = deps.CharacterPos()
    local belowTop = math.max(py, if f.at ~= nil then f.at.y else f.y) + CARD_BELOW
    local _, belowY = h.WorldToHud(f.x, belowTop)
    local canvas = h.HudGui
    -- alt obiect: alt card, deci de la locul lui firesc
    if cardOf ~= f.key then
        cardKey, cardOf = nil, f.key
    end
    local where, shift, key = GuideMath.cardPlacement({
        centerX = cx,
        aboveY = top,
        belowY = belowY,
        width = w * perWorld,
        height = ht * perWorld,
        screenW = canvas.Size.X.Offset,
        screenH = canvas.Size.Y.Offset,
        blockers = fixedBlockers(canvas),
        currentKey = cardKey,
    })
    cardKey = key
    local x = f.x + shift / perWorld
    if where == "below" then
        return x, belowTop + ht / 2 + CARD_H / 2
    end
    return x, y
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
        conceal()
        return
    end
    local looking = deps.Looking
    if looking ~= nil and looking() then
        -- undita aruncata mulineaza mai departe (rig-ul citeste tasta singur); cartonasul platformei tace si el
        current = nil
        PadController.SetApproachSuppressed(true)
        conceal()
        return
    end
    local cx, cy = deps.CharacterPos()
    local px, py = cx - TycoonConfig.PLOT_ORIGIN.x, cy - TycoonConfig.PLOT_ORIGIN.y
    local focuses: { Focus.Focus } = {}
    local cards: { GuideMath.CardCandidate } = {}
    for _, source in SOURCES do
        local found = source(px, py)
        if found ~= nil then
            local withUpgrade = found.upgradeKind ~= nil and firstSale
            table.insert(focuses, found)
            table.insert(cards, {
                distance = found.distance,
                at = found.at,
                content = found.action ~= nil or found.status ~= nil or withUpgrade,
                holds = found.holds,
                urgent = found.urgent,
            })
        end
    end
    -- [2026-09-30] cel mai apropiat card, dar langa tinta ghidajului cel al tintei (GuideMath.pickCard): acolo ghidajul
    -- se retrage, deci cardul de pe ecran trebuie sa fie al locului spre care arata. Inaintea lor, darul de pe rau (trece
    -- o data), apoi undita aruncata (tine E).
    local pick, why = GuideMath.pickCard(cards, goal, px, py)
    local f = if pick ~= nil then focuses[pick] else nil
    if why == "holds" then
        -- E e al treburii in curs: niciun card, niciun cartonas de cumparare
        current = f
        PadController.SetApproachSuppressed(true)
        conceal()
        return
    end

    -- un card fara nimic de aratat nu ia locul cartonasului de cumparare
    local hasUpgrade = f ~= nil and f.upgradeKind ~= nil and firstSale
    local hasContent = pick ~= nil and cards[pick].content
    local padId, padDistance = PadController.ApproachCandidate()
    -- langa o platforma-tinta, cartonasul ei bate cardul unui obiect mai apropiat (nu si darul de pe rau); cardul unui
    -- loc-tinta bate orice platforma (cele doua nu se intalnesc: un loc-tinta n-are padId)
    local padWins = why ~= "urgent" and GuideMath.padIsGoal(goal, px, py, padId)
    local objectWins = hasContent
        and f ~= nil
        and not padWins
        and (why ~= "near" or f.distance <= padDistance)
    PadController.SetApproachSuppressed(objectWins)
    if not objectWins or f == nil then
        current = if hasContent then nil else f
        hide()
        return
    end
    current = f

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
    -- [2026-09-29] tinut in ecran: pe telefon (~460 px de teren pe inaltime) cardul Pietei si al tavernei iesea pe sus.
    -- [verificatorul D76] Dupa ce stie ce arata (latimea placii si a butonului Upgrade), ca sa ocoleasca panourile fixe.
    local y = f.y
    local viewTop = deps.ViewTop
    if viewTop ~= nil then
        y = math.max(y, viewTop() + CARD_H + 8)
    end
    local x
    x, y = place(f, y)
    local origin = TycoonConfig.PLOT_ORIGIN
    card.Position = UDim2.fromOffset(math.round(x + origin.x), math.round(y + origin.y))
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

-- [2026-09-29] Se vede un card acum, si punctul locului lui (campul `at` al cardului; nil la barca, la indicatorul rotii):
-- ghidajul isi retrage sageata cand cardul e chiar al locului spre care arata, iar langa tinta ramane aprins cat se vede
-- cardul altui loc [2026-09-30].
function InteractController.Shown(): (boolean, number?, number?, boolean)
    local f = current
    if card == nil or not card.Visible or f == nil then
        return false, nil, nil, false
    end
    local urgent = f.urgent == true -- al patrulea: un card trecator (darul de pe rau)
    local at = f.at
    if at == nil then
        return true, nil, nil, urgent
    end
    return true, at.x, at.y, urgent
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

-- U: meniul obiectului de langa tine -- acelasi ca butonul Upgrade de pe card, si doar cand butonul se vede. Intoarce
-- false cand nu e niciunul, ca U sa-si pastreze rostul vechi (lista statiilor).
function InteractController.OpenUpgrade(): boolean
    return openUpgrade()
end

-- [verificatorul D76] Panza HUD si trecerea din lume in ea (worldToHud din Bootstrap, definita dupa Init): de acum cardul
-- ocoleste panourile fixe ale HUD-ului (GuideMath.cardPlacement).
function InteractController.SetHud(h: {
    WorldToHud: (number, number) -> (number, number),
    HudGui: Frame,
})
    hud = h
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
    -- [D67, audit] peste textul lumii: e interfata, se apasa. [2026-09-30] Si peste sageata ghidajului: sta in stratul
    -- lumii (Scroll), deasupra terenului (Plot, 5) si a marcajului ghidajului (9); sageata spre alt loc (a doua plasa,
    -- avizierul) se desena peste butonul Upgrade al primei plase si peste placuta rotii.
    card.ZIndex = CARD_Z
    card.Visible = false
    card.Parent = deps.Scroll
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
