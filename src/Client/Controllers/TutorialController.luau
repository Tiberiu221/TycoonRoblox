--!strict
-- Deschiderea jocului [pozele Idle Miner ale owner-ului, D51]:
--
--   1. un CARD DE CAPITOL pe tot ecranul: "Chapter 1 · The Landing", o fraza, "tap anywhere".
--   2. mana arata prima plasa-fantoma. Mergi acolo si o cumperi; de aici conduce ghidajul (dara,
--      linia NEXT), pas cu pas, prin prima bucla: plasa plina, gaterul, taverna.
--   3. DUPA PRIMA VANZARE, cand ai prima recompensa de luat: ecranul se intuneca, ramane aprinsa
--      cartea de quest-uri, cu o propozitie si mana. Se stinge in clipa in care lista e deschisa.
--
-- [D51] Cartea venea chiar la inceput, inainte de orice actiune: o deschideai fara motiv. Acum vine
-- cand ai ceva de luat din ea. Si se inchide dintr-un singur click: pasul de dinainte verifica
-- lista deschisa doar DUPA un click pe intuneric, deci click-ul direct pe carte o deschidea fara
-- sa stinga intunericul [owner, 2026-09-13: "nu dispare partea neagra decat dupa al doilea click"].
--
-- REGULA, scrisa in cod: un singur lucru aprins, restul intunecat, o propozitie, o actiune.
--
-- Nu se salveaza nimic in plus: pasii se deduc din stare (plasa cumparata, prima vanzare, ceva
-- revendicat vreodata). Cine iese la jumatate reia exact de unde a ramas.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Facts = {
    firstNetBought: boolean,
    firstSale: boolean,
    everClaimed: boolean, -- in orice capitol
    claimable: number,
}

export type Deps = {
    -- ECRANUL INTREG, nu panza HUD-ului. Panza HUD sta intr-un ScreenGui cu ScreenInsets, deci
    -- incepe SUB bara de sus a Roblox-ului: intunericul lasa o fasie luminata in varf, iar pe
    -- telefon fasia aia e si mai lata. Tutorialul primeste un strat propriu, fara insets.
    Screen: Frame,
    -- coordonate de ECRAN, nu de panza HUD: stratul asta n-are nici scalare, nici inset
    WorldToScreen: (number, number) -> (number, number),
    -- butonul care deschide lista de quest-uri, din bara din dreapta, in coordonate de ECRAN
    QuestButtonRect: () -> (number, number, number, number),
    QuestsOpen: () -> boolean,
    OpenQuests: () -> (),
}

local TutorialController = {}
local deps: Deps

local Z = 200 -- peste tot: un reflector care sta sub un panou n-ar mai fi reflector
local DIM = 0.28 -- cat de mult se vede prin intuneric

local root: Frame
-- Cele patru dreptunghiuri care lasa o gaura in mijloc. Sunt BUTOANE, nu cadre: asa apasarea pe
-- intuneric e prinsa de ele, iar apasarea pe gaura ajunge la elementul adevarat de dedesubt.
-- Prima varianta avea un buton separat peste tot ecranul, inclusiv peste gaura -- si atunci
-- lucrul "aprins" nu se putea apasa deloc, exact ce s-a vazut in joc.
local shades: { TextButton } = {}
local ring: Frame
local caption: TextLabel
local pointer: ImageLabel?
-- Cardul de capitol: 600x400 = exact 4x peste ilustratia de 150x100, deci pixelii ei raman
-- patrati. CARD_ASPECT tine raportul cand ecranul e prea mic si cardul trebuie micsorat.
local CARD_W, CARD_H = 600, 400
local CARD_ASPECT = CARD_W / CARD_H
local glow: ImageLabel?
local card: TextButton
local cardTapCatcher: TextButton

local phase = "idle" -- "idle" | "card" | "point_pad" | "wait" | "book" | "done"
local pointerTime = 0
-- Cand a vazut prima vanzare: cartea asteapta sa se stinga bannerul primei vanzari (3.5 s,
-- CeremonyController.MOMENT_DURATION) -- altfel ar aparea amandoua in aceeasi secunda.
local saleSeenAt: number? = nil
local bookScheduled = false -- starile vin des (fiecare lot vandut): o singura intarziere programata
local BOOK_DELAY = 4.2
-- Butonul cu cartea sta la marginea din DREAPTA: mana si textul vin din stanga lui, spre el. Mana
-- e desenata cu degetul in sus, deci rotita 90 de grade arata spre dreapta.
local POINT_GAP = 10
-- [D73] cat de aproape de marginea ecranului poate sta mana cand tinta e in afara lui; sus, sub blocul cifrelor din HUD
local POINTER_EDGE = 40
local POINTER_TOP = 190

-- ---- desenul ---------------------------------------------------------------------------------

-- Roblox 2D nu poate taia o gaura intr-un Frame, deci intunericul se compune din PATRU dreptunghiuri
-- in jurul tintei. Calculul e in coordonate de ECRAN, luate din elementul real (AbsolutePosition),
-- ca gaura sa cada exact peste el la orice rezolutie.
local function setHole(x: number, y: number, w: number, h: number)
    local canvas = root.AbsoluteSize
    local pad = 10
    local left, top = x - pad, y - pad
    local right, bottom = x + w + pad, y + h + pad
    local rects = {
        { 0, 0, canvas.X, top }, -- sus
        { 0, bottom, canvas.X, canvas.Y - bottom }, -- jos
        { 0, top, left, bottom - top }, -- stanga
        { right, top, canvas.X - right, bottom - top }, -- dreapta
    }
    for i, r in rects do
        local f = shades[i]
        f.Position = UDim2.fromOffset(math.round(r[1]), math.round(r[2]))
        f.Size = UDim2.fromOffset(math.max(0, math.round(r[3])), math.max(0, math.round(r[4])))
    end
    ring.Position = UDim2.fromOffset(math.round(left), math.round(top))
    ring.Size = UDim2.fromOffset(math.round(right - left), math.round(bottom - top))
    -- Stralucirea: sprite cu 9 felii al carui MIJLOC e transparent. Ca mijlocul ala sa cada exact
    -- peste gaura, imaginea trebuie sa fie mai mare cu o felie de colt in fiecare parte.
    local g = glow
    if g ~= nil then
        local b = Assets.UI_SLICE.glow
        g.Position = UDim2.fromOffset(math.round(left - b), math.round(top - b))
        g.Size =
            UDim2.fromOffset(math.round(right - left + b * 2), math.round(bottom - top + b * 2))
    end
end

local function showShades(on: boolean)
    for _, f in shades do
        f.Visible = on
    end
    if glow ~= nil then
        (glow :: ImageLabel).Visible = on
    end
    ring.Visible = on
    caption.Visible = on
end

local function showPointer(on: boolean)
    if pointer ~= nil then
        (pointer :: ImageLabel).Visible = on
    end
end

local function movePointer(x: number, y: number, sideways: boolean?)
    if pointer == nil then
        return
    end
    -- se leagana spre tinta: o mana care sta nemiscata se citeste ca decor
    local bob = math.sin(pointerTime * 4) * 7
    local p = pointer :: ImageLabel
    if sideways then
        p.Position = UDim2.fromOffset(math.round(x + bob), math.round(y))
    else
        p.Position = UDim2.fromOffset(math.round(x), math.round(y + bob))
    end
end

-- Mana arata in sus (sub o tinta din lume) sau spre dreapta (spre un buton de la marginea din dreapta).
local function aimPointer(sideways: boolean)
    if pointer == nil then
        return
    end
    local p = pointer :: ImageLabel
    p.Rotation = if sideways then 90 else 0
    p.AnchorPoint = if sideways then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0)
end

-- ---- pasii -----------------------------------------------------------------------------------

local function goTo(next: string)
    phase = next
    if next == "card" then
        card.Visible = true
        showShades(false)
        showPointer(false)
    elseif next == "point_pad" then
        card.Visible = false
        showShades(false)
        aimPointer(false)
        showPointer(true)
    elseif next == "book" then
        card.Visible = false
        caption.Text = Strings.TUTORIAL_CLAIM_REWARDS
        showShades(true)
        aimPointer(true)
        showPointer(true)
    else -- "wait" si "done": nimic pe ecran
        card.Visible = false
        showShades(false)
        showPointer(false)
    end
end

-- Cheamat la fiecare TycoonState. Fazele merg doar inainte; `done` e capatul.
function TutorialController.Apply(f: Facts)
    if phase == "done" then
        return
    end
    if f.everClaimed then
        goTo("done") -- a gasit deja cartea singur
        return
    end
    if phase == "idle" then
        goTo(if f.firstNetBought then "wait" else "card")
    elseif (phase == "card" or phase == "point_pad") and f.firstNetBought then
        goTo("wait")
    end
    if phase == "wait" and f.firstSale then
        local now = os.clock()
        if saleSeenAt == nil then
            saleSeenAt = now
        end
        if f.claimable > 0 and now - (saleSeenAt :: number) >= BOOK_DELAY then
            goTo("book")
        elseif f.claimable > 0 and not bookScheduled then
            -- starea urmatoare poate intarzia: pasul porneste singur cand trece bannerul
            bookScheduled = true
            task.delay(BOOK_DELAY - (now - (saleSeenAt :: number)) + 0.05, function()
                if phase == "wait" then
                    goTo("book")
                end
            end)
        end
    end
end

local function update(dt: number)
    if phase == "idle" or phase == "done" or phase == "wait" then
        return
    end
    pointerTime += dt

    if phase == "book" then
        local x, y, w, h = deps.QuestButtonRect()
        if w <= 0 then
            return
        end
        setHole(x, y, w, h)
        -- textul in stanga butonului, mana intre ele, arata spre dreapta; latimea mainii rotite e
        -- inaltimea desenului
        local handW = if pointer ~= nil then (pointer :: ImageLabel).AbsoluteSize.Y else 56
        local midY = y + h * 0.5
        caption.Position =
            UDim2.fromOffset(math.round(x - POINT_GAP * 2 - handW - POINT_GAP), math.round(midY))
        movePointer(x - POINT_GAP * 2 - handW * 0.5, midY, true)
        -- s-a deschis lista? atunci pasul si-a facut treaba -- verificat in FIECARE cadru, deci
        -- click-ul direct pe carte stinge intunericul pe loc
        if deps.QuestsOpen() then
            goTo("done")
        end
    elseif phase == "point_pad" then
        local pad = TycoonConfig.byId.first_net
        if pad == nil or pad.x == nil then
            goTo("wait")
            return
        end
        -- +40, nu -90: mana sta sub obiect si arata in sus spre el, la fel ca la jurnal.
        local hx, hy = deps.WorldToScreen(pad.x :: number, (pad.y :: number) + 40)
        -- [D73] plasa e deasupra ecranului (pe telefon, de la locul de pornire, raul nu se vede): mana ramane pe ecran, la
        -- marginea de sus, si arata tot in sus, spre ea. O singura margine, lina (fara salt cand plasa intra in cadru):
        -- 12% din inaltime, deci pe un ecran mare mana sta aproape unde statea, iar pe telefon departe de personaj (la
        -- mijlocul ecranului)
        local size = root.AbsoluteSize
        hx = math.clamp(hx, POINTER_EDGE, math.max(POINTER_EDGE, size.X - POINTER_EDGE))
        local top = math.min(POINTER_TOP, size.Y * 0.12)
        hy = math.clamp(hy, top, math.max(top, size.Y - POINTER_EDGE - 64))
        movePointer(hx, hy)
    end
end

function TutorialController.Init(d: Deps)
    deps = d
    root = Instance.new("Frame")
    root.Name = "Tutorial"
    root.BackgroundTransparency = 1
    root.Size = UDim2.fromScale(1, 1)
    root.ZIndex = Z
    root.Parent = deps.Screen

    for i = 1, 4 do
        local f = Instance.new("TextButton")
        f.Name = `Shade{i}`
        f.Text = ""
        f.AutoButtonColor = false
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BackgroundTransparency = DIM
        f.BorderSizePixel = 0
        f.Visible = false
        f.ZIndex = Z + 1
        f.Parent = root
        f.Activated:Connect(function()
            if phase == "book" then
                -- iesire blanda: cine apasa pe langa nu ramane blocat in intuneric
                deps.OpenQuests()
            end
        end)
        shades[i] = f
    end

    -- inelul care incadreaza lucrul aprins: fara el, "gaura" din intuneric se citeste ca o scapare
    ring = Instance.new("Frame")
    ring.Name = "Ring"
    ring.BackgroundTransparency = 1
    ring.Visible = false
    ring.ZIndex = Z + 2
    ring.Parent = root
    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(0, 14)
    ringCorner.Parent = ring
    local ringStroke = Instance.new("UIStroke")
    ringStroke.Thickness = 3
    ringStroke.Color = Theme.COLOR.gold
    ringStroke.Parent = ring

    if Assets.has(Assets.ui.glow) then
        local g = Widgets.NineSlice(root, Assets.ui.glow, Assets.UI_SLICE.glow, Z + 2)
        g.Name = "Glow"
        g.Visible = false
        g.Parent = root
        glow = g
    end
    TweenService:Create(
        ringStroke,
        TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.55 }
    ):Play()

    caption = Widgets.PlateLabel(root, "", Theme.TEXT.heading, "display")
    caption.Visible = false
    -- prins de marginea din DREAPTA, langa mana; placuta cat textul, nu o banda lata de 420
    caption.AnchorPoint = Vector2.new(1, 0.5)
    caption.AutomaticSize = Enum.AutomaticSize.X
    caption.Size = UDim2.fromOffset(0, 40)
    caption.TextXAlignment = Enum.TextXAlignment.Right
    caption.ZIndex = Z + 3

    -- MANA, nu sageata intoarsa. Sageata veche era desenata cu varful in sus si rotita 180, deci
    -- arata in JOS -- dar `movePointer` o aseaza SUB tinta la pasul cu jurnalul, adica arata in
    -- partea opusa. Mana are degetul in sus si se aseaza mereu dedesubt: o singura regula, la
    -- amandoi pasii, si nimic de rotit.
    local pointerArt: ImageLabel? = nil
    if Assets.has(Assets.ui.hand) then
        local h = Instance.new("ImageLabel")
        h.Name = "Hand"
        h.BackgroundTransparency = 1
        h.Image = Assets.url(Assets.ui.hand)
        h.ResampleMode = Enum.ResamplerMode.Pixelated
        h.Size = UDim2.fromOffset(Assets.ui.hand.width * 2, Assets.ui.hand.height * 2)
        h.Parent = root
        pointerArt = h
    else
        pointerArt = Widgets.Icon(root, "arrow", 44)
    end
    if pointerArt ~= nil then
        local pa = pointerArt :: ImageLabel
        pa.AnchorPoint = Vector2.new(0.5, 0)
        pa.Visible = false
        pa.ZIndex = Z + 4
        pointer = pa
    end

    -- ---- cardul de capitol ----
    -- ILUSTRATIA E FUNDALUL, nu o poza lipita intr-un panou de pergament. De-aia cardul nu mai e
    -- un Widgets.Window: rama de lemn + pergamentul ar fi stat degeaba sub imagine, iar antetul cu
    -- titlu si butonul de inchidere ar fi taiat din ea. Aici cardul E imaginea, cu un chenar
    -- subtire si doua voaluri in degrade -- unul de sus pentru titlu, unul de jos pentru indemn.
    local cardRoot = Instance.new("TextButton")
    cardRoot.Name = "ChapterCard"
    cardRoot.AutoButtonColor = false
    cardRoot.Text = ""
    cardRoot.BackgroundColor3 = Theme.COLOR.woodDark
    cardRoot.ClipsDescendants = true
    cardRoot.AnchorPoint = Vector2.new(0.5, 0.5)
    cardRoot.Position = UDim2.fromScale(0.5, 0.5)
    cardRoot.Size = UDim2.fromOffset(CARD_W, CARD_H)
    cardRoot.ZIndex = Z + 5
    cardRoot.Visible = false
    cardRoot.Parent = root
    Theme.shadow(cardRoot, 22, 0.40)
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 12)
    cardCorner.Parent = cardRoot
    -- Chenarul sta pe un COPIL, nu pe card. Theme.shadow adauga si el un UIStroke cand platforma
    -- n-are UIShadow, iar doua UIStroke pe acelasi obiect nu se aduna: unul din ele dispare in
    -- tacere -- si n-ai cum sa stii care, pentru ca depinde de versiunea clientului.
    local cardEdge = Instance.new("Frame")
    cardEdge.Name = "Edge"
    cardEdge.BackgroundTransparency = 1
    cardEdge.Size = UDim2.fromScale(1, 1)
    cardEdge.ZIndex = Z + 8
    cardEdge.Parent = cardRoot
    local edgeCorner = Instance.new("UICorner")
    edgeCorner.CornerRadius = UDim.new(0, 12)
    edgeCorner.Parent = cardEdge
    local edgeStroke = Instance.new("UIStroke")
    edgeStroke.Color = Theme.COLOR.wood
    edgeStroke.Thickness = 3
    edgeStroke.Parent = cardEdge
    card = cardRoot

    if Assets.has(Assets.chapters.landing) then
        local art = Instance.new("ImageLabel")
        art.Name = "ChapterArt"
        art.BackgroundTransparency = 1
        art.Image = Assets.url(Assets.chapters.landing)
        art.ResampleMode = Enum.ResamplerMode.Pixelated
        art.Size = UDim2.fromScale(1, 1)
        art.ZIndex = Z + 5
        art.Parent = cardRoot
    end

    -- Voalul: negru care se stinge spre mijlocul imaginii. Textul deschis singur peste un cer
    -- deschis s-ar pierde exact in coltul unde cade titlul.
    local function scrim(fromTop: boolean, height: number)
        local f = Instance.new("Frame")
        f.Name = if fromTop then "ScrimTop" else "ScrimBottom"
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.AnchorPoint = Vector2.new(0, if fromTop then 0 else 1)
        f.Position = UDim2.fromScale(0, if fromTop then 0 else 1)
        f.Size = UDim2.fromScale(1, height)
        f.ZIndex = Z + 6
        f.Parent = cardRoot
        local g = Instance.new("UIGradient")
        g.Rotation = 90 -- de sus in jos
        g.Color = ColorSequence.new(Color3.new(0, 0, 0))
        -- Cat de tare se inchide: destul cat sa se citeasca textul (care are si contur propriu,
        -- Theme.punch), nu mai mult. Prima incercare avea 0.18 sus pe 48% din inaltime si stingea
        -- soarele cu totul -- dar imaginea e tot subiectul cardului, nu doar un fundal de umplut.
        g.Transparency = if fromTop
            then NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.30),
                NumberSequenceKeypoint.new(0.55, 0.66),
                NumberSequenceKeypoint.new(1, 1),
            })
            else NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.45, 0.70),
                NumberSequenceKeypoint.new(1, 0.28),
            })
        g.Parent = f
    end
    scrim(true, 0.44)
    scrim(false, 0.24)

    local cardTitle = Widgets.Label(
        cardRoot,
        Strings.TUTORIAL_CHAPTER_TITLE,
        Theme.TEXT.title,
        Theme.COLOR.onDark,
        "display"
    )
    cardTitle.Position = UDim2.fromOffset(26, 20)
    cardTitle.Size = UDim2.new(1, -52, 0, 38)
    cardTitle.TextTruncate = Enum.TextTruncate.AtEnd
    cardTitle.ZIndex = Z + 7
    Theme.punch(cardTitle)

    local titleRule = Instance.new("Frame")
    titleRule.Name = "Rule"
    titleRule.BackgroundColor3 = Theme.COLOR.gold
    titleRule.BorderSizePixel = 0
    titleRule.Position = UDim2.fromOffset(28, 62)
    titleRule.Size = UDim2.fromOffset(88, 3)
    titleRule.ZIndex = Z + 7
    titleRule.Parent = cardRoot

    local line1 = Widgets.Label(
        cardRoot,
        Strings.OPENING_LINE_1,
        Theme.TEXT.heading,
        -- PESTE IMAGINE, deci culorile de "text peste lume" (deschise) + contur. Cat timp cardul
        -- era pergament, aici trebuia exact invers (cerneala) -- e aceeasi capcana, pe dos.
        Theme.COLOR.onDark,
        "display"
    )
    line1.Position = UDim2.fromOffset(26, 78)
    line1.Size = UDim2.new(1, -52, 0, 30)
    line1.TextWrapped = true
    line1.ZIndex = Z + 7
    Theme.punch(line1)

    local line2 = Widgets.Label(
        cardRoot,
        Strings.OPENING_LINE_2,
        Theme.TEXT.body,
        Theme.COLOR.onDarkSoft,
        "body"
    )
    line2.Position = UDim2.fromOffset(26, 112)
    line2.Size = UDim2.new(1, -52, 0, 26)
    line2.TextWrapped = true
    line2.ZIndex = Z + 7
    Theme.punch(line2, 2)

    local hint = Widgets.Label(
        cardRoot,
        Strings.TUTORIAL_TAP_ANYWHERE,
        Theme.TEXT.small,
        Theme.COLOR.gold,
        "strong"
    )
    hint.AnchorPoint = Vector2.new(0.5, 1)
    hint.Position = UDim2.new(0.5, 0, 1, -18)
    hint.Size = UDim2.fromOffset(340, 24)
    hint.TextXAlignment = Enum.TextXAlignment.Center
    hint.ZIndex = Z + 7
    Theme.punch(hint, 2)

    -- Cardul E butonul: "tap anywhere" inseamna si peste imagine, nu doar pe langa ea. Inainte
    -- inchiderea statea pe butonul de X al ferestrei, care acum nu mai exista.
    cardRoot.Activated:Connect(function()
        if phase == "card" then
            goTo("point_pad")
        end
    end)

    -- Imaginea are 3:2; cardul TREBUIE sa pastreze raportul, altfel pixelii ei se intind pe o axa
    -- si se vede imediat. Deci nu se taie pe inaltime independent, ca la Widgets.Window.
    local function fitCard()
        local canvas = root.AbsoluteSize
        if canvas.X <= 0 or canvas.Y <= 0 then
            return
        end
        local w = math.min(CARD_W, math.max(280, canvas.X - 48))
        local h = w / CARD_ASPECT
        if h > canvas.Y - 48 then
            h = math.max(190, canvas.Y - 48)
            w = h * CARD_ASPECT
        end
        cardRoot.Size = UDim2.fromOffset(math.round(w), math.round(h))
    end
    fitCard()
    root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCard)

    cardTapCatcher = Instance.new("TextButton")
    cardTapCatcher.Name = "CardTap"
    cardTapCatcher.BackgroundColor3 = Color3.new(0, 0, 0)
    cardTapCatcher.BackgroundTransparency = DIM
    cardTapCatcher.Text = ""
    cardTapCatcher.AutoButtonColor = false
    cardTapCatcher.Size = UDim2.fromScale(1, 1)
    cardTapCatcher.ZIndex = Z + 4
    cardTapCatcher.Parent = root
    cardTapCatcher.Visible = false
    cardTapCatcher.Activated:Connect(function()
        if phase == "card" then
            goTo("point_pad")
        end
    end)
    card:GetPropertyChangedSignal("Visible"):Connect(function()
        cardTapCatcher.Visible = card.Visible
    end)

    RunService.PreRender:Connect(update)
    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed or phase == "idle" or phase == "done" then
            return
        end
        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
            if phase == "card" then
                goTo("point_pad")
            elseif phase == "book" then
                deps.OpenQuests()
            end
        end
    end)
end

return TutorialController
