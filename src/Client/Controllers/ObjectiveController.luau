--!strict
-- Ce are jucatorul de facut ACUM, plus semnul din lume care arata unde [RIVERKEEP 2].
--
-- Regulile care conteaza, in ordinea importantei:
--   1. UN SINGUR obiectiv pe ecran cat timp jucatorul invata. Cea mai mare pierdere de jucatori
--      pe Roblox e chiar la prima actiune ceruta, iar cauza masurata e ca nu e clar ce si unde.
--   2. UN SINGUR semn care pulseaza in tot ecranul. Daca totul straluceste, nimic nu iese in
--      evidenta si ecranul devine zgomot.
--   3. Cand un pas se termina, se sarbatoreste scurt si se trece mai departe. Fara bife ramase
--      pe ecran.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ObjectiveConfig = require(ReplicatedStorage.Shared.Config.ObjectiveConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local CameraController = require(script.Parent.CameraController)

local ObjectiveController = {}

local card: Frame
local titleLabel: TextLabel
local hintLabel: TextLabel
local stepLabel: TextLabel
local marker: Frame
local markerIcon: ImageLabel?
local guide: Frame
local guideIcon: ImageLabel?
local latest: { [string]: any } = {}
local unlocked: { [string]: boolean } = { net = true }
local markerWorld: Vector2? = nil
local onMarkerPanel: ((string?) -> ())? = nil
local hidden = false
local hudScale: (() -> number)? = nil
local hasTask = false
local onUnlockChanged: (() -> ())? = nil
local openers: { [string]: () -> () } = {}
local cardButton: TextButton
local cardOpener: (() -> ())? = nil
local tapIcon: ImageLabel?
local collapseArrow: ImageLabel?
local targets: { [string]: () -> (number?, number?) } = {}
local progressTrack: Frame
local progressFill: Frame

-- Unde se pune semnul. Toate tintele sunt VII: pozitia reala a plasei, a santierului, a
-- atelierului. O constanta ar lasa sageata suspendata peste iarba goala, ceea ce deruteaza
-- mai tare decat lipsa ei. Cand nu exista tinta, semnul dispare.
-- Ce buton din bara corespunde sarcinii curente. Doar marcajele care SUNT panouri au buton;
-- pentru "net_slot" sau "river" nu exista nimic de apasat, deci inelul se stinge.
local PANEL_FOR_MARKER: { [string]: string } = {
    build = "build",
    workshop = "workshop",
    people = "people",
    site = "build",
}

local function onHighlight(kind: string?)
    -- local, nu apel direct pe campul optional: stylua sterge punctul-si-virgula care apara o
    -- instructiune ce incepe cu paranteza, si fisierul s-ar rupe la prima formatare
    local notify = onMarkerPanel
    if notify == nil then
        return
    end
    notify(if kind ~= nil then PANEL_FOR_MARKER[kind] else nil)
end

local function markerTargetFor(kind: string): Vector2?
    local getter = targets[kind]
    if getter == nil then
        return nil
    end
    local x, y = getter()
    if x == nil or y == nil then
        return nil
    end
    return Vector2.new(x, y)
end

-- Ascuns cat timp cineva vorbeste cu jucatorul: ecranul trebuie sa fie al discutiei
function ObjectiveController.SetHidden(value: boolean)
    hidden = value
    if card ~= nil then
        card.Visible = not hidden and hasTask
    end
end

function ObjectiveController.IsUnlocked(name: string): boolean
    return unlocked[name] == true
end

function ObjectiveController.Latest(): { [string]: any }
    return latest
end

-- Ce pas din lant e activ ACUM. Panourile intreaba ca sa se poata ghida singure: la pasul care
-- cere dezmembrare, atelierul isi aprinde butonul Scrap si il opreste pe Repair, in loc sa lase
-- jucatorul sa aleaga intre doua butoane identice dupa un text pe care poate nu l-a citit.
function ObjectiveController.CurrentStepId(): string?
    local current = latest.current
    if current == nil then
        return nil
    end
    return (current :: { [string]: any }).id
end

-- Ce deschide sarcina curenta, daca deschide ceva. Cartonasul e si buton: apesi pe sarcina si
-- se deschide exact ce trebuie. Fara asta, singura cale era bara laterala, iar daca aceea nu
-- apare din orice motiv, jucatorul ramane blocat definitiv.
local function openerFor(markerKind: string): (() -> ())?
    return openers[markerKind]
end

-- Asezare MASURATA. `AutomaticSize` se aseaza cu un cadru intarziere si a lasat indiciul taiat
-- sub marginea ramei; inaltimile fixe lasau o banda goala. `TextBounds` da inaltimea reala pe
-- loc, cu conditia ca latimea etichetei sa fie in pixeli, nu in fractiuni.
local CARD_WIDTH = 420
local CARD_PAD = 20
local TEXT_WIDTH = CARD_WIDTH - CARD_PAD * 2
local collapsed = false
local progressWanted = false

-- Semn, nu propozitie: o sageata mica pe marginea cartonasului cand se poate apasa pe el
local function setTappable(on: boolean)
    if tapIcon ~= nil then
        (tapIcon :: ImageLabel).Visible = on and not collapsed
    end
end

-- Strans: raman doar pasul si titlul. Jucatorul care a inteles sarcina nu trebuie sa se uite la
-- ea tot timpul, dar nici nu trebuie sa o piarda.
local function layout()
    if hintLabel == nil then
        return
    end
    local y = 0
    stepLabel.Position = UDim2.fromOffset(0, y)
    y += 19

    titleLabel.Position = UDim2.fromOffset(0, y)
    local titleH = math.max(30, math.ceil(titleLabel.TextBounds.Y))
    titleLabel.Size = UDim2.fromOffset(TEXT_WIDTH, titleH)
    y += titleH + 6

    if not collapsed then
        hintLabel.Position = UDim2.fromOffset(0, y)
        local hintH = math.max(22, math.ceil(hintLabel.TextBounds.Y))
        hintLabel.Size = UDim2.fromOffset(TEXT_WIDTH, hintH)
        y += hintH + 8
        if progressWanted then
            progressTrack.Position = UDim2.fromOffset(0, y)
            y += 22
        end
    end
    card.Size = UDim2.fromOffset(CARD_WIDTH, y + CARD_PAD * 2)
end

local function applyCollapse()
    if hintLabel == nil then
        return
    end
    hintLabel.Visible = not collapsed
    progressTrack.Visible = progressWanted and not collapsed
    if collapseArrow ~= nil then
        (collapseArrow :: ImageLabel).Rotation = if collapsed then 0 else 180
    end
    setTappable(cardOpener ~= nil)
    layout()
end

local function applyState(state: { [string]: any })
    latest = state
    unlocked = state.unlocked or unlocked
    -- ANUNTUL VINE DUPA ce s-au actualizat deblocarile. Invers, bara de butoane citea starea
    -- veche, iar butonul cerut de pasul curent nu aparea niciodata.
    local notify = onUnlockChanged
    if notify ~= nil then
        notify()
    end

    local current = state.current
    if current == nil then
        -- lantul s-a terminat: se arata primul tel lung, nu toate deodata
        local goals = state.goals or {}
        -- Cartonasul nu se goleste NICIODATA. Cand toate treptele sunt atinse, ramane sarcina
        -- permanenta: colonia trebuie tinuta in picioare. Un ecran fara nicio directie e exact
        -- momentul in care jucatorul inchide jocul.
        local goal = goals[1]
            or {
                title = "Keep the colony standing",
                hint = "Watch food, beds and moods on the colony board.",
                marker = "people",
                have = 0,
                target = 0,
            }
        hasTask = true
        card.Visible = not hidden
        titleLabel.Text = goal.title
        hintLabel.Text = ObjectiveConfig.fill(goal.hint, UserInputService.TouchEnabled)
        stepLabel.Text = if goal.target > 0 then `{goal.have} / {goal.target}` else "ONGOING"
        markerWorld = markerTargetFor(goal.marker)
        onHighlight(goal.marker)
        local p = goal.progress
        cardOpener = openerFor(goal.marker)
        setTappable(cardOpener ~= nil)
        progressWanted = p ~= nil and p > 0
        if p ~= nil then
            progressFill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
        end
        applyCollapse()
        return
    end

    hasTask = true
    card.Visible = not hidden
    titleLabel.Text = current.title
    -- simbolurile devin comanda pe care o are CHIAR clientul asta: pe telefon nu exista tasta E
    hintLabel.Text = ObjectiveConfig.fill(current.hint, UserInputService.TouchEnabled)
    stepLabel.Text = `Step {state.index} of {state.total}`
    markerWorld = markerTargetFor(current.marker)
    cardOpener = openerFor(current.marker)
    onHighlight(current.marker)
    setTappable(cardOpener ~= nil)
    -- bara apare doar cand chiar exista ceva in curs: o bara la zero nu spune nimic
    local p = current.progress
    progressWanted = p ~= nil and p > 0
    if p ~= nil then
        progressFill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
    end
    applyCollapse()
end

-- Sarbatoarea misca panoul, nu il scaleaza. Un UIScale ar mari si corpul, corpul ar cere alta
-- inaltime pentru rama, iar rama ar mari iar corpul: bucla, in timpul animatiei.
local function celebrate()
    local base = card.Position
    card.Position = base + UDim2.fromOffset(0, -10)
    local settle = TweenService:Create(
        card,
        TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Position = base }
    )
    settle:Play()
end

function ObjectiveController.Init(d: {
    HudGui: Frame,
    Scroll: Frame,
    ObjectiveState: RemoteEvent,
    ObjectiveDone: RemoteEvent,
    RequestObjectives: RemoteEvent,
    PlayerPos: () -> (number, number),
    HudScale: () -> number,
    OnToast: (string) -> (),
    Openers: { [string]: () -> () },
    Targets: { [string]: () -> (number?, number?) },
    OnUnlockChanged: () -> (),
    OnMarkerPanel: ((string?) -> ())?,
})
    openers = d.Openers
    targets = d.Targets
    hudScale = d.HudScale
    onUnlockChanged = d.OnUnlockChanged

    local root, content = Widgets.Panel(d.HudGui, "ObjectiveCard", 18)
    root.Position = UDim2.fromOffset(Theme.SPACE.lg, 128) -- sub alerta, care a coborat cu randul de cifre
    root.Size = UDim2.fromOffset(CARD_WIDTH, 150)
    root.Visible = false
    card = root

    content.Position = UDim2.fromOffset(CARD_PAD, CARD_PAD)
    content.Size = UDim2.fromOffset(TEXT_WIDTH, 400)

    -- Toata suprafata cartonasului e apasabila: apesi pe sarcina, se deschide ce trebuie.
    cardButton = Instance.new("TextButton")
    cardButton.Name = "Open"
    cardButton.BackgroundTransparency = 1
    cardButton.Text = ""
    cardButton.Size = UDim2.fromScale(1, 1)
    cardButton.ZIndex = 24
    cardButton.Parent = root
    -- Cartonasul se poate MUTA: il tragi unde vrei, inclusiv in dreapta, daca iti sta in cale.
    -- Aceeasi suprafata face si clic si tragere: daca degetul s-a miscat sub cateva pixeli, a
    -- fost clic; altfel a fost mutare. Doua suprafete separate ar fi fost o ghicitoare in plus.
    local dragging = false
    local moved = 0
    local grabX, grabY = 0, 0
    local startX, startY = 0, 0

    cardButton.InputBegan:Connect(function(input: InputObject)
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = true
        moved = 0
        grabX, grabY = input.Position.X, input.Position.Y
        startX, startY = card.Position.X.Offset, card.Position.Y.Offset
    end)
    UserInputService.InputChanged:Connect(function(input: InputObject)
        if not dragging then
            return
        end
        if
            input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        -- degetul se misca in pixeli de ECRAN, panoul traieste in pixeli de PANZA. Fara
        -- impartirea la scara, cartonasul ramane in urma cursorului pe orice ecran mai mic
        -- decat rezolutia de referinta, adica aproape peste tot.
        local getScale = hudScale
        local s = if getScale ~= nil then math.max(0.1, getScale()) else 1
        local dx = (input.Position.X - grabX) / s
        local dy = (input.Position.Y - grabY) / s
        moved = math.max(moved, math.abs(dx) + math.abs(dy))
        card.Position = UDim2.fromOffset(startX + dx, startY + dy)
    end)
    UserInputService.InputEnded:Connect(function(input: InputObject)
        if not dragging then
            return
        end
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        dragging = false
        if moved <= 6 then
            local open = cardOpener
            if open ~= nil then
                open()
            end
        end
    end)

    stepLabel = Widgets.Label(content, "", Theme.TEXT.tiny, Theme.COLOR.wood, "strong")
    stepLabel.Size = UDim2.fromOffset(TEXT_WIDTH - 52, 15)

    titleLabel = Widgets.Label(content, "", 26, Theme.COLOR.ink, "display")
    titleLabel.Size = UDim2.fromOffset(TEXT_WIDTH, 30)
    titleLabel.TextWrapped = true
    titleLabel.TextYAlignment = Enum.TextYAlignment.Top

    -- indiciul e text de citit, deci merge pe culoarea plina, nu pe cea stinsa
    hintLabel = Widgets.Label(content, "", Theme.TEXT.body, Theme.COLOR.ink, "body")
    hintLabel.Size = UDim2.fromOffset(TEXT_WIDTH, 22)
    hintLabel.TextWrapped = true
    hintLabel.TextTransparency = 0.18
    hintLabel.TextYAlignment = Enum.TextYAlignment.Top

    progressTrack, progressFill = Widgets.Bar(content, TEXT_WIDTH, 12, Theme.COLOR.good, 22)
    progressTrack.Visible = false

    -- buton de strans, in coltul din dreapta sus
    local collapse = Instance.new("TextButton")
    collapse.Name = "Collapse"
    collapse.AnchorPoint = Vector2.new(1, 0)
    collapse.Position = UDim2.new(1, -12, 0, 10)
    collapse.Size = UDim2.fromOffset(40, 34) -- cea mai mica tinta de apasare era 30x26
    collapse.BackgroundColor3 = Theme.COLOR.parchmentDim
    collapse.BackgroundTransparency = 0.3
    collapse.AutoButtonColor = false
    collapse.Text = ""
    collapse.ZIndex = 26
    local arrow = Widgets.Icon(collapse, "arrow", 20)
    if arrow ~= nil then
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Position = UDim2.fromScale(0.5, 0.5)
        arrow.Rotation = 180
        arrow.ZIndex = 27
        collapseArrow = arrow
    end
    local cc = Instance.new("UICorner")
    cc.CornerRadius = UDim.new(0, 6)
    cc.Parent = collapse
    collapse.Activated:Connect(function()
        collapsed = not collapsed
        applyCollapse()
    end)
    collapse.Parent = root

    local chevron = Widgets.Icon(root, "arrow", 26)
    if chevron ~= nil then
        chevron.AnchorPoint = Vector2.new(1, 1)
        chevron.Position = UDim2.new(1, -14, 1, -12)
        chevron.Rotation = 90 -- sageata desenata in sus, intoarsa spre dreapta
        chevron.ImageTransparency = 0.25
        chevron.ZIndex = 23
        chevron.Visible = false
        tapIcon = chevron
    end

    -- Semnul din lume: o sageata care pluteste deasupra tintei. Singurul lucru care pulseaza.
    marker = Instance.new("Frame")
    marker.Name = "ObjectiveMarker"
    marker.BackgroundTransparency = 1
    marker.AnchorPoint = Vector2.new(0.5, 1)
    marker.Size = UDim2.fromOffset(56, 56)
    marker.Visible = false
    marker.ZIndex = 50
    marker.Parent = d.Scroll
    if Assets.has(Assets.icons.arrow) then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(Assets.icons.arrow)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.Rotation = 180 -- sageata desenata in sus, aratata in jos catre tinta
        img.Size = UDim2.fromScale(1, 1)
        img.ZIndex = 50
        img.Parent = marker
        markerIcon = img
    else
        local l = Instance.new("TextLabel")
        l.BackgroundTransparency = 1
        l.Text = "▼"
        l.TextColor3 = Theme.COLOR.gold
        l.TextSize = 46
        l.Size = UDim2.fromScale(1, 1)
        l.ZIndex = 50
        l.Parent = marker
    end

    -- Busola: o sageata care se roteste in jurul jucatorului si arata incotro e sarcina.
    -- Semnul de la tinta ajuta doar cand tinta e pe ecran. Cand nu e, jucatorul se invarte
    -- fara sa stie in ce parte sa o ia, si exact acolo se pierde.
    guide = Instance.new("Frame")
    guide.Name = "ObjectiveGuide"
    guide.BackgroundTransparency = 1
    guide.AnchorPoint = Vector2.new(0.5, 0.5)
    guide.Size = UDim2.fromOffset(44, 44)
    guide.Visible = false
    guide.ZIndex = 49
    guide.Parent = d.Scroll
    local gi = Widgets.Icon(guide, "arrow", 40)
    if gi ~= nil then
        gi.AnchorPoint = Vector2.new(0.5, 0.5)
        gi.Position = UDim2.fromScale(0.5, 0.5)
        gi.ZIndex = 49
        guideIcon = gi
    end

    d.ObjectiveState.OnClientEvent:Connect(function(state: { [string]: any })
        applyState(state)
    end)
    d.ObjectiveDone.OnClientEvent:Connect(function(_id: string, title: string)
        celebrate()
        d.OnToast(`Done: {title}`)
    end)

    RunService.PreRender:Connect(function()
        -- busola, in jurul jucatorului
        local guideTo = markerWorld
        if guideTo == nil or hidden then
            if guide.Visible then
                guide.Visible = false
            end
        else
            local px, py = d.PlayerPos()
            local cx, cy = px, py - 36 -- centrul personajului, nu talpile
            local dx, dy = guideTo.X - cx, guideTo.Y - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            -- aproape de tinta, sageata de deasupra ei e destula; busola ar fi zgomot
            local show = dist > 260
            if guide.Visible ~= show then
                guide.Visible = show
            end
            if show and dist > 0 then
                local RADIUS = 78
                local nx, ny = dx / dist, dy / dist
                guide.Position =
                    UDim2.fromOffset(math.round(cx + nx * RADIUS), math.round(cy + ny * RADIUS))
                if guideIcon ~= nil then
                    -- pictograma e desenata cu varful in sus; 0 grade inseamna nord
                    (guideIcon :: ImageLabel).Rotation = math.deg(math.atan2(nx, -ny))
                end
            end
        end

        if markerWorld == nil then
            if marker.Visible then
                marker.Visible = false
            end
            return
        end
        local target = markerWorld :: Vector2
        local visible = CameraController.IsVisible(target.X - 40, target.Y - 120, 80, 120)
        if marker.Visible ~= visible then
            marker.Visible = visible
        end
        if not visible then
            return
        end
        local bob = math.sin(Workspace:GetServerTimeNow() * 3.4) * 10
        marker.Position = UDim2.fromOffset(target.X, target.Y - 46 + math.floor(bob))
        if markerIcon ~= nil then
            markerIcon.ImageTransparency = 0.08
                + 0.16 * (0.5 + 0.5 * math.sin(Workspace:GetServerTimeNow() * 3.4))
        end
    end)

    -- Inca o asezare pe cadrul urmator: la prima trecere, latimile abia s-au aplicat si
    -- TextBounds poate raporta o valoare de dinainte de incadrarea textului.
    task.defer(layout)
    d.RequestObjectives:FireServer()
end

return ObjectiveController
