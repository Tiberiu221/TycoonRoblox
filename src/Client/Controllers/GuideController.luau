--!strict
-- Ghidajul [F1 spec 5.1-5.2, L1-L3, D50]: fraza de deschidere, apoi UN SINGUR obiectiv deodata, aratat
-- in lume SI in text -- regula owner-ului: nu presupune nimic, nu bloca jucatorul, niciodata mai mult
-- de un obiectiv.
--
-- [D50] Owner-ul: "vreau o sageata care sa ghideze playerul pe unde trebuie sa o ia si unde trebuie sa
-- se duca". Deci trei lucruri, toate spre aceeasi tinta:
--   * DARA: sageti mici pe jos, pe drumuri (RoadGraph), care curg de la tine spre tinta;
--   * MARCAJUL: sageata care salta deasupra tintei, cu textul, si un inel pe locul exact;
--   * indicatorul de margine, pe HUD, cand tinta e in afara ecranului.
-- Se arata IMEDIAT (fara asteptarea de 11s de pana acum) si doar pana ai cate un om la fiecare
-- meserie -- atunci GuideMath nu mai intoarce nicio tinta si totul tace.
--
-- GuideMath (modul pur) alege CE obiectiv; controller-ul asta doar il deseneaza.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local GuideMath = require(ReplicatedStorage.Shared.Modules.GuideMath)
local RoadGraph = require(ReplicatedStorage.Shared.Modules.RoadGraph)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    WorldScroll: Frame,
    -- stratul terenului: dara si inelul stau pe jos, sub oameni si cladiri
    Plot: Frame,
    HudGui: Frame,
    CharacterPos: () -> (number, number),
    WorldToHud: (number, number) -> (number, number),
    -- [2026-09-29] varful placii de pret a unei platforme (PadController.TagTop), ca sageata sa stea deasupra ei
    TagTop: ((padId: string) -> number?)?,
    -- [2026-09-29] se vede un card E, punctul locului lui si daca e trecator (InteractController.Shown)
    Card: (() -> (boolean, number?, number?, boolean))?,
    World: number?, -- [D70, pasul k2] dara merge pe drumurile hartii tale (la baraj ocoleste zidul si canalul)
}

local GuideController = {}
local deps: Deps

local phraseGroup: Frame
local worldArrow: Frame
local worldLabel: TextLabel
local edgeGroup: Frame
local edgeIcon: ImageLabel?
local edgeLabel: TextLabel
local ring: GuiObject
local ringScale: UIScale
local chevrons: { GuiObject } = {}
local chevronsShown = 0

local currentGoal: GuideMath.Goal? = nil
local phraseState = "pending" -- "pending" | "shown" | "faded"

-- drumul curent al darei, refacut cand se schimba tinta sau cand te-ai miscat
local routeKey = ""
local routeFromX, routeFromY = math.huge, math.huge
local routeAt = -math.huge
local routePoints: { RoadGraph.Point } = {}
local routeLens: { number } = {}
local routeTotal = 0

-- Sageata sta chiar peste placuta platformei (care urca ~44px peste centrul ei), nu mai sus: la 118
-- ajungea deasupra liniei apei si parea ca arata spre rau [vazut in Studio, 2026-09-12].
local WORLD_ARROW_Y_OFFSET = 78
local ARROW_SIZE = 48 -- era 34: nu se vedea destul [D50]
local EDGE_MARGIN = 46

local TRAIL_POOL = 40
local TRAIL_SPACING = 56
local TRAIL_SPEED = 70 -- px/s: sagetile curg spre tinta
local TRAIL_SIZE = 32 -- sprite de 16 la x2
local TRAIL_START = 46 -- nu chiar sub picioarele tale
local TRAIL_END_GAP = 40 -- se opreste inainte de inel
local ROUTE_REFRESH = 0.5
local ROUTE_MOVE = 24
local RING_W, RING_H = 96, 48
local ARROW_BOX_H = 104 -- inaltimea marcajului: eticheta sus, sageata jos
-- [D52] Unde poate sta eticheta: deasupra marcajului (implicit, varful lui e la ARROW_BOX_H peste baza sagetii) sau sub
-- inel, la LABEL_BELOW px sub mijlocul lui. GuideMath.labelPlacement alege, ca textul sa nu ramana sub panourile HUD-ului.
local LABEL_BELOW = RING_H / 2 + 10
local labelPlace = "above" -- "above" | "below" | "hidden"

local function countBought(pads: { [string]: string }): number
    local n = 0
    for _, status in pads do
        if status == "bought" then
            n += 1
        end
    end
    return n
end

-- [L1] Cele doua randuri de deschidere, centrate in treimea de sus, pana la prima cumparare.
local function buildPhrase(parent: Frame): Frame
    local root = Instance.new("Frame")
    root.Name = "OpeningPhrase"
    root.AnchorPoint = Vector2.new(0.5, 0)
    root.Position = UDim2.fromScale(0.5, 0.06) -- sus de tot: sub ea incap si indiciul, si cartonasul
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(620, 96)
    root.ZIndex = 14
    root.Visible = false
    root.Parent = parent

    -- UN singur panou cu doua randuri, nu doua placi separate: suprapuse peste lume aratau ca
    -- doua benzi negre care taie raul [vazut in Studio, 2026-09-12].
    local plate = Widgets.PlateLabel(root, "", Theme.TEXT.heading, "display")
    plate.AnchorPoint = Vector2.new(0.5, 0)
    plate.Position = UDim2.fromScale(0.5, 0)
    plate.Size = UDim2.fromScale(1, 1)
    plate.Text = ""
    plate.ZIndex = 15

    local line1 = Widgets.Label(
        plate,
        Strings.OPENING_LINE_1,
        Theme.TEXT.heading,
        Theme.COLOR.onDark,
        "display"
    )
    line1.AnchorPoint = Vector2.new(0.5, 0)
    line1.Position = UDim2.new(0.5, 0, 0, 14)
    line1.Size = UDim2.new(1, -32, 0, 32)
    line1.TextXAlignment = Enum.TextXAlignment.Center
    line1.ZIndex = 16

    local line2 =
        Widgets.Label(plate, Strings.OPENING_LINE_2, Theme.TEXT.body, Theme.COLOR.gold, "strong")
    line2.AnchorPoint = Vector2.new(0.5, 0)
    line2.Position = UDim2.new(0.5, 0, 0, 52)
    line2.Size = UDim2.new(1, -32, 0, 26)
    line2.TextXAlignment = Enum.TextXAlignment.Center
    line2.ZIndex = 16

    return root
end

local function fadeOutPhrase()
    for _, child in phraseGroup:GetDescendants() do
        if child:IsA("TextLabel") then
            TweenService:Create(
                child,
                TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                { TextTransparency = 1, BackgroundTransparency = 1 }
            ):Play()
        end
    end
    task.delay(1.2, function()
        phraseGroup.Visible = false
    end)
end

-- [L2] Sageata care salta deasupra tintei, in lume -- text deasupra ei.
local function buildWorldArrow(parent: Frame): (Frame, TextLabel)
    local root = Instance.new("Frame")
    root.Name = "GuideWorldArrow"
    root.AnchorPoint = Vector2.new(0.5, 1)
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(260, ARROW_BOX_H)
    root.ZIndex = 9
    root.Visible = false
    root.Parent = parent

    local icon = Widgets.Icon(root, "arrow", ARROW_SIZE)
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 1)
        icon.Position = UDim2.fromScale(0.5, 1)
        -- Assets.icons.arrow arata in sus implicit (verificat vizual) -- 180 o intoarce spre tinta
        icon.Rotation = 180
        icon.ZIndex = 10
        local bob = TweenService:Create(
            icon,
            TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Position = UDim2.new(0.5, 0, 1, -16) }
        )
        bob:Play()
    end

    -- ancorat sus, nu langa sageata -- ca bobul ei sa nu-l atinga niciodata la varful saltului
    local label = Widgets.PlateLabel(root, "", Theme.TEXT.heading, "display")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromScale(0.5, 0)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, 34)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextColor3 = Theme.COLOR.onDark
    label.ZIndex = 10

    return root, label
end

-- [L2] Indicatorul de margine, pe HUD, cand tinta e in afara ecranului -- sageata se roteste spre
-- directia reala, textul ramane scurt langa ea.
local function buildEdgeGroup(parent: Frame): (Frame, ImageLabel?, TextLabel)
    local root = Instance.new("Frame")
    root.Name = "GuideEdgePointer"
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromOffset(180, 62)
    root.ZIndex = 17
    root.Visible = false
    root.Parent = parent

    local icon = Widgets.Icon(root, "arrow", 30)
    if icon ~= nil then
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromScale(0.5, 0.24)
        icon.ZIndex = 18
    end

    local label = Widgets.PlateLabel(root, "", Theme.TEXT.body, "strong")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.fromScale(0.5, 0.44)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.Size = UDim2.fromOffset(0, 30)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextColor3 = Theme.COLOR.onDark
    label.ZIndex = 18

    return root, icon, label
end

-- Un obiect de pe jos (sageata darei, inelul): sprite-ul daca e urcat, altfel o forma simpla.
local function groundThing(
    parent: Frame,
    sprite: Assets.Sprite,
    name: string,
    w: number,
    h: number
): GuiObject
    local obj: GuiObject
    if Assets.has(sprite) then
        local img = Instance.new("ImageLabel")
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.BackgroundTransparency = 1
        obj = img
    else
        local frame = Instance.new("Frame")
        frame.BackgroundColor3 = Theme.COLOR.gold
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = frame
        obj = frame
    end
    obj.Name = name
    obj.AnchorPoint = Vector2.new(0.5, 0.5)
    obj.Size = UDim2.fromOffset(w, h)
    obj.ZIndex = 2 -- pe jos: peste drum, sub oameni si cladiri
    obj.Visible = false
    obj.Parent = parent
    return obj
end

local function setAlpha(obj: GuiObject, alpha: number, color: Color3?)
    if obj:IsA("ImageLabel") then
        obj.ImageTransparency = alpha
        if color ~= nil then
            obj.ImageColor3 = color
        end
    else
        obj.BackgroundTransparency = alpha
        if color ~= nil then
            obj.BackgroundColor3 = color
        end
    end
end

local function canvasSize(): (number, number)
    return deps.HudGui.Size.X.Offset, deps.HudGui.Size.Y.Offset
end

-- Directia de la centrul ecranului spre tinta, taiata sa ramana in dreptunghiul vizibil (minus o
-- margine) -- tehnica standard de indicator de margine, independenta de unde sta jucatorul.
local function clampToEdge(px: number, py: number, w: number, h: number): (number, number)
    local cx, cy = w / 2, h / 2
    local dx, dy = px - cx, py - cy
    if dx == 0 and dy == 0 then
        return cx, cy - (h / 2 - EDGE_MARGIN)
    end
    local scaleX = if dx ~= 0 then (cx - EDGE_MARGIN) / math.abs(dx) else math.huge
    local scaleY = if dy ~= 0 then (cy - EDGE_MARGIN) / math.abs(dy) else math.huge
    local scale = math.max(0, math.min(scaleX, scaleY, 1))
    return cx + dx * scale, cy + dy * scale
end

-- Scara panzei HUD (UIScale): pixeli de ecran pe pixel de panza.
local function hudScale(): number
    local canvas = deps.HudGui
    local width = canvas.Size.X.Offset
    if width <= 0 then
        return 1
    end
    local scale = canvas.AbsoluteSize.X / width
    return if scale > 0 then scale else 1
end

-- Panourile HUD vizibile, in coordonatele panzei: copiii directi ai panzei, mai putin indicatorul
-- nostru de margine, ancorele de marime zero ale efectelor si radacinile care acopera aproape tot
-- ecranul. Citite din joc, nu dintr-o lista: un panou nou ajunge aici singur.
local function hudBlockers(w: number, h: number, scale: number): { GuideMath.Rect }
    local canvas = deps.HudGui
    local origin = canvas.AbsolutePosition
    local out: { GuideMath.Rect } = {}
    for _, child in canvas:GetChildren() do
        if child == edgeGroup or not child:IsA("GuiObject") then
            continue
        end
        local gui = child :: GuiObject
        if not gui.Visible then
            continue
        end
        local size = gui.AbsoluteSize / scale
        if size.X <= 0 or size.Y <= 0 or (size.X >= w * 0.9 and size.Y >= h * 0.9) then
            continue
        end
        local pos = (gui.AbsolutePosition - origin) / scale
        table.insert(out, { x = pos.X, y = pos.Y, w = size.X, h = size.Y })
    end
    return out
end

-- [verificatorii A0, k12] Panourile FIXE desenate peste indicatorul de margine (atributul GuideBlocker: bara de meniu).
-- Nu toti copiii panzei: toast-urile, bannerele si monedele in zbor sunt trecatoare si il faceau sa sara prin ecran.
local function edgeBlockers(scale: number): { GuideMath.Rect }
    local canvas = deps.HudGui
    local origin = canvas.AbsolutePosition
    local out: { GuideMath.Rect } = {}
    for _, child in canvas:GetChildren() do
        if
            child:IsA("GuiObject")
            and child.Visible
            and child:GetAttribute("GuideBlocker") == true
        then
            local size = child.AbsoluteSize / scale
            local pos = (child.AbsolutePosition - origin) / scale
            table.insert(out, { x = pos.X, y = pos.Y, w = size.X, h = size.Y })
        end
    end
    return out
end

-- [D52] Eticheta de deasupra tintei sta in lume, deci SUB HUD. Cu taverna sus-stanga (cand esti la
-- gater), textul cadea chiar sub monede, traista si linia NEXT si nu se mai citea [owner, Studio,
-- 2026-09-13]. Acum: deasupra daca e loc, altfel sub inel, altfel deloc -- si intreaga pe ecran.
-- `arrowY` = baza marcajului (sageata), `ringY` = mijlocul inelului, amandoua in lume.
local function placeLabel(gx: number, arrowY: number, ringY: number, w: number, h: number)
    local scale = hudScale()
    local width, height = worldLabel.AbsoluteSize.X / scale, worldLabel.AbsoluteSize.Y / scale
    local cx = deps.WorldToHud(gx, ringY)
    local rx = deps.WorldToHud(gx + 100, ringY)
    local perWorld = (rx - cx) / 100 -- px de panza pe px de lume
    if width <= 0 or perWorld <= 0 then
        return -- eticheta inca nemasurata (primul cadru): ramane unde era
    end
    local _, aboveY = deps.WorldToHud(gx, arrowY - ARROW_BOX_H)
    local _, belowY = deps.WorldToHud(gx, ringY + LABEL_BELOW)
    local place, shift = GuideMath.labelPlacement({
        centerX = cx,
        aboveY = aboveY,
        belowY = belowY,
        width = width,
        height = height,
        screenW = w,
        screenH = h,
        blockers = hudBlockers(w, h, scale),
        current = labelPlace,
    })
    labelPlace = place
    worldLabel.Visible = place ~= "hidden"
    -- sub inel: de la varful marcajului (arrowY - ARROW_BOX_H) pana sub inel
    local down = if place == "below" then (ringY + LABEL_BELOW) - (arrowY - ARROW_BOX_H) else 0
    worldLabel.Position = UDim2.new(0.5, shift / perWorld, 0, down)
end

-- [2026-09-29] UNDE SE DESENEAZA TINTA UNEI PLATFORME. Tinta e mijlocul platformei (de acolo se masoara si cat de
-- aproape esti), dar cladirea ei sta cu baza cu 56 px mai jos si e desenata PESTE inel: la o ruina sau o cladire
-- inalta, inelul ramanea ascuns in spatele ei, iar sageata, la 78 px fix peste mijloc, cadea pe placa de pret. Acum
-- inelul sta pe pamant, in fata talpii cladirii, iar sageata urca deasupra placii de pret cand ar sta pe ea. Inelul
-- plaselor si al rotii de apa (in rau) ramane pe mijlocul platformei, pe punte.
local function goalMarks(goal: GuideMath.Goal, gx: number, gy: number): (number, number)
    local arrowY, ringY = gy - WORLD_ARROW_Y_OFFSET, gy
    local pad = if goal.padId ~= nil then TycoonConfig.byId[goal.padId] else nil
    if pad == nil or pad.x ~= gx or pad.y ~= gy then
        return arrowY, ringY -- tinta nu e chiar platforma (inelul unui atelier, o usa)
    end
    local net = false
    for _, e in pad.effects do
        if e.kind == "net" then
            net = true
        end
    end
    if not net and pad.id ~= "water_wheel" then
        ringY = TycoonConfig.buildingBase(pad) + RING_H / 2 - 12
    end
    -- sageata urca deasupra placii de pret doar la o cladire de pe mal si doar cand ar sta chiar pe ea (cutia ei, cu saltul
    -- de 16 px, peste cei 28 px ai placii). La plase, la turbina si la roata de apa placa e sus in rau: sageata ramane
    -- peste stalpul de pe punte [owner, 2026-09-12: sus, "parea ca arata spre rau"]
    local tagTopOf = deps.TagTop
    local tagTop = if tagTopOf ~= nil then tagTopOf(pad.id) else nil
    if
        not net
        and pad.id ~= "water_wheel"
        and tagTop ~= nil
        and arrowY > tagTop
        and arrowY - ARROW_SIZE - 16 < tagTop + 28
    then
        arrowY = tagTop - 4
    end
    return arrowY, ringY
end

local function hideTrail()
    for i = 1, chevronsShown do
        chevrons[i].Visible = false
    end
    chevronsShown = 0
end

local function hideGuide()
    worldArrow.Visible = false
    edgeGroup.Visible = false
    ring.Visible = false
    hideTrail()
    routeKey = ""
end

local function refreshRoute(
    goal: GuideMath.Goal,
    gx: number,
    gy: number,
    px: number,
    py: number,
    now: number
)
    local moved = math.abs(px - routeFromX) + math.abs(py - routeFromY)
    if goal.key == routeKey and moved < ROUTE_MOVE and now - routeAt < ROUTE_REFRESH then
        return
    end
    routeKey = goal.key
    routeFromX, routeFromY = px, py
    routeAt = now
    routePoints = RoadGraph.route(
        RoadGraph.forWorld(deps.World),
        { x = px, y = py },
        { x = gx, y = gy }
    )
    routeLens = {}
    routeTotal = 0
    for i = 2, #routePoints do
        local a, b = routePoints[i - 1], routePoints[i]
        local len = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
        routeLens[i - 1] = len
        routeTotal += len
    end
end

-- Sagetile, la TRAIL_SPACING una de alta, pornesc de langa tine si curg spre tinta; se aprind la
-- inceput si se sting inainte de inel.
local function drawTrail(now: number)
    local used = 0
    local stopAt = routeTotal - TRAIL_END_GAP
    local d = TRAIL_START + (now * TRAIL_SPEED) % TRAIL_SPACING
    local seg, segStart = 1, 0
    while d < stopAt and used < TRAIL_POOL do
        while seg < #routeLens and segStart + routeLens[seg] < d do
            segStart += routeLens[seg]
            seg += 1
        end
        local len = routeLens[seg]
        if len == nil or len <= 0 then
            break
        end
        local a, b = routePoints[seg], routePoints[seg + 1]
        local k = math.clamp((d - segStart) / len, 0, 1)
        used += 1
        local c = chevrons[used]
        c.Position =
            UDim2.fromOffset(math.round(a.x + (b.x - a.x) * k), math.round(a.y + (b.y - a.y) * k))
        c.Rotation = math.deg(math.atan2(b.y - a.y, b.x - a.x))
        local fadeIn = math.clamp((d - TRAIL_START) / 60, 0, 1)
        local fadeOut = math.clamp((stopAt - d) / 90, 0, 1)
        setAlpha(c, 1 - 0.9 * math.min(fadeIn, fadeOut))
        if not c.Visible then
            c.Visible = true
        end
        d += TRAIL_SPACING
    end
    for i = used + 1, chevronsShown do
        chevrons[i].Visible = false
    end
    chevronsShown = used
end

local function updateGuideVisuals()
    if currentGoal == nil or Panels.AnyOpen() then
        hideGuide()
        return
    end
    local goal = currentGoal :: GuideMath.Goal
    if goal.kind == "save" or goal.x == nil or goal.y == nil then
        -- "economisesti pentru X" sau "plasele prind" nu sunt locuri: nu ai unde sa te duci, deci
        -- sageata n-are ce arata. Pasul traieste doar pe linia NEXT [D51].
        hideGuide()
        return
    end
    local gx, gy = goal.x :: number, goal.y :: number

    local cx, cy = deps.CharacterPos()
    local px, py = cx - TycoonConfig.PLOT_ORIGIN.x, cy - TycoonConfig.PLOT_ORIGIN.y
    -- [2026-09-29] Cand cardul E de pe ecran e chiar al locului spre care arata ghidajul (inelul unui atelier, magazia,
    -- usa vanzatorului, plasa, pontonul, avizierul: campul `at` al cardului e punctul tintei), cardul spune ce e de facut,
    -- iar sageata si eticheta ghidajului i-ar acoperi butoanele: se retrag, inelul si dara raman. Cardul altui obiect
    -- (barca, indicatorul rotii, casa vecina) nu retrage nimic.
    local card = deps.Card
    local shown, shownX, shownY, shownUrgent = false, nil, nil, false
    if card ~= nil then
        shown, shownX, shownY, shownUrgent = card()
    end
    local ownCard = shown
        and shownX ~= nil
        and shownY ~= nil
        and GuideMath.isGoalCard(goal, shownX :: number, shownY :: number)
    -- esti deja acolo -- ghidajul n-ar mai arata nimic util [P3]. [2026-09-30] Doar daca nu se vede cardul altui loc: langa
    -- tinta, cardul ei castiga (GuideMath.pickCard), iar cand totusi se vede altul (cardul tintei n-are ce arata, alt
    -- obiect bate platforma), ghidajul ramane aprins, ca sa nu ramai fara nicio indicatie.
    -- Darul de pe rau (trecator) trece in ~2,5 s: langa tinta ghidajul nu revine pentru el, altfel eticheta ghidajului
    -- iesea sub cardul care aluneca odata cu darul.
    if GuideMath.nearGoal(goal, px, py) and (ownCard or not shown or shownUrgent) then
        hideGuide()
        return
    end

    local now = os.clock()
    local arrowY, ringY = goalMarks(goal, gx, gy)
    refreshRoute(goal, gx, ringY, px, py, now)
    drawTrail(now)

    local pulse = (math.sin(now * 3.2) + 1) / 2
    ring.Position = UDim2.fromOffset(gx, ringY)
    if ring:IsA("ImageLabel") then
        setAlpha(ring, 0.3 - 0.25 * pulse, Theme.COLOR.gold)
    else
        -- rezerva fara sprite: se stinge doar chenarul, altfel inelul devine o pata plina
        local stroke = ring:FindFirstChildOfClass("UIStroke")
        if stroke ~= nil then
            stroke.Transparency = 0.3 - 0.25 * pulse
        end
    end
    ringScale.Scale = 0.92 + 0.12 * pulse
    ring.Visible = true

    worldLabel.Text = goal.text

    local w, h = canvasSize()
    if w <= 0 or h <= 0 then
        worldArrow.Visible = false
        edgeGroup.Visible = false
        return
    end
    local hx, hy = deps.WorldToHud(gx, gy)
    local onScreen = hx >= 0 and hx <= w and hy >= 0 and hy <= h
    if onScreen then
        -- [2026-09-29] tinta e pe ecran, dar sageata de deasupra ei (cu saltul) poate iesi pe sus, iar indicatorul de
        -- margine nu apare: sageata coboara cat sa ramana in ecran
        local _, topHud = deps.WorldToHud(gx, arrowY - ARROW_SIZE - 16)
        local _, zeroHud = deps.WorldToHud(gx, 0)
        local _, hundredHud = deps.WorldToHud(gx, 100)
        local perWorld = (hundredHud - zeroHud) / 100
        if topHud < EDGE_MARGIN / 2 and perWorld > 0 then
            arrowY = math.min(ringY, arrowY + (EDGE_MARGIN / 2 - topHud) / perWorld)
        end
    end
    worldArrow.Position = UDim2.fromOffset(gx, arrowY)
    worldArrow.Visible = onScreen and not ownCard
    edgeGroup.Visible = not onScreen
    if onScreen and not ownCard then
        placeLabel(gx, arrowY, ringY, w, h)
    end
    if not onScreen then
        local ex, ey = clampToEdge(hx, hy, w, h)
        -- [verificatorul k6-k8] eticheta de sub sageata ramane in panza: la o tinta din dreapta („Build the Dam when you're
        -- ready”, ~330 px) grupul se trage spre interior cu jumatate din ea; sageata se roteste tot spre tinta
        local half = (Theme.textWidth(goal.text, Theme.TEXT.body, "strong") + 24) / 2
        -- [verificatorii A0, k12] ...si nu sub panourile fixe desenate peste el (bara de meniu din dreapta): alunecand de-a
        -- lungul marginii lui (GuideMath.edgePlacement). Grupul: sageata de 30 px deasupra punctului, eticheta pana la +27.
        ex, ey = GuideMath.edgePlacement({
            x = ex,
            y = ey,
            w = w,
            h = h,
            half = math.max(half, 15),
            top = 31,
            bottom = 27,
            blockers = edgeBlockers(hudScale()),
        })
        edgeGroup.Position = UDim2.fromOffset(ex, ey)
        if edgeIcon ~= nil then
            -- 0 grade = sus (Assets.icons.arrow), rotatia creste in sensul acelor de ceasornic
            edgeIcon.Rotation = math.deg(math.atan2(hx - w / 2, -(hy - h / 2)))
        end
        edgeLabel.Text = goal.text
    end
end

-- Cheamat de Overlay cand starea copiata explicit se schimba [F1 spec 4.9]. Intoarce pasul ales, ca
-- linia NEXT din HUD sa scrie exact ce arata sageata [D51].
function GuideController.Apply(state: GuideMath.State): GuideMath.Goal?
    local boughtNow = countBought(state.pads)
    if phraseState == "pending" then
        if boughtNow == 0 then
            phraseGroup.Visible = true
            phraseState = "shown"
        else
            phraseState = "faded" -- profil vechi cu ceva deja cumparat: nu arata fraza de nou-venit
        end
    elseif phraseState == "shown" and boughtNow > 0 then
        fadeOutPhrase()
        phraseState = "faded"
    end

    local goal = GuideMath.pickGoal(state)
    currentGoal = goal
    return goal
end

function GuideController.Init(d: Deps)
    deps = d
    phraseGroup = buildPhrase(deps.HudGui)
    worldArrow, worldLabel = buildWorldArrow(deps.WorldScroll)
    edgeGroup, edgeIcon, edgeLabel = buildEdgeGroup(deps.HudGui)

    ring = groundThing(deps.Plot, Assets.ui.groundring, "GuideRing", RING_W, RING_H)
    if not ring:IsA("ImageLabel") then
        -- fara sprite: inelul e un chenar, nu o pata plina peste tinta
        ring.BackgroundTransparency = 1
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.COLOR.gold
        stroke.Thickness = 4
        stroke.Parent = ring
    end
    ringScale = Instance.new("UIScale")
    ringScale.Parent = ring
    local trailSize = if Assets.has(Assets.ui.chevron) then TRAIL_SIZE else 12
    for i = 1, TRAIL_POOL do
        chevrons[i] =
            groundThing(deps.Plot, Assets.ui.chevron, `GuideTrail{i}`, trailSize, trailSize)
    end

    RunService.PreRender:Connect(function()
        updateGuideVisuals()
    end)
end

return GuideController
