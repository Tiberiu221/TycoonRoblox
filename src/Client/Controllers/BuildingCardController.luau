--!strict
-- Cartonasul de cladire: apesi pe o cladire si vezi ce face si cine e inauntru.
--
-- DE CE EXISTA: pana acum cladirile nu erau apasabile DELOC. Le puteai ridica si te puteai uita
-- la ele, dar nu puteai intreba una singura ce face. Intr-un joc in care esti administrator,
-- asta e verbul principal care lipsea. In jocurile mobile de constructie (Clash of Clans si tot
-- ce a venit dupa) apasatul pe cladire e prima interactiune pe care o invata oricine, si nu
-- deschide un ecran plin: deschide un cartonas mic, ancorat langa cladire, care spune ce e
-- acolo si iti da una-doua actiuni mari.
--
-- Trei reguli luate de acolo:
--  1. Cartonasul sta LANGA cladire, in lume, nu in mijlocul ecranului. Nu pierzi contextul.
--  2. Cladirea aleasa se vede aleasa: inel auriu care pulseaza. Fara asta nu stii pe ce ai apasat.
--  3. Cel mult doua actiuni, mari, cu text. Un meniu de opt actiuni mici e tiparul opus.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local BuildingCardController = {}

local CARD_W = 340
local CARD_PAD = 16

type Deps = {
    Scroll: Frame,
    GetSettlers: () -> { { [string]: any } },
    GetBuildings: () -> { { [string]: any } },
    Open: { [string]: () -> () }, -- actiuni de panou, dupa numele panoului
    IsUnlocked: (string) -> boolean,
}

local deps: Deps
local card: Frame? = nil
local content: Frame? = nil
local ring: Frame? = nil
local selectedId: number? = nil
local ringPulse: Tween? = nil
local cardHeight = 200 -- inaltimea calculata la ultima reimprospatare

-- Pictograma si cuvantul pentru capacitatea fiecarui fel de cladire. Cuvantul conteaza: "Beds 3"
-- si "Seats 3" spun doua lucruri diferite, "Slots 3" nu spune niciunul.
local KINDS: { [string]: { icon: string, unit: string } } = {
    rest = { icon = "bed", unit = "beds" },
    food = { icon = "food", unit = "cooking spots" },
    work = { icon = "hammer", unit = "work benches" },
    farm = { icon = "food", unit = "plots" },
    joy = { icon = "joy", unit = "seats" },
}

local title: TextLabel
local blurb: TextLabel
local statLine: TextLabel
local hereLine: TextLabel
local progressTrack: Frame
local progressFill: Frame
local actionButton: TextButton
local actionHandler: (() -> ())? = nil

-- Cati oameni sunt FIZIC in dreptunghiul cladirii. Clientul are pozitiile, deci nu cere nimic
-- serverului. E si mai onest asa: scrie "cine e aici", nu "cine e repartizat" -- vezi ce vezi.
local function peopleInside(b: { [string]: any }, d: BuildingConfig.Def): number
    local x0, y0 = b.x, b.y
    local x1, y1 = x0 + d.w * RiverConfig.TILE, y0 + d.h * RiverConfig.TILE
    local n = 0
    for _, s in deps.GetSettlers() do
        if s.x >= x0 and s.x <= x1 and s.y >= y0 and s.y <= y1 then
            n += 1
        end
    end
    return n
end

local function findBuilding(id: number): { [string]: any }?
    for _, b in deps.GetBuildings() do
        if b.id == id then
            return b
        end
    end
    return nil
end

-- Inelul de selectie. Se creeaza o data si se muta; pulseaza incet ca sa se vada ca e viu.
local function ensureRing(): Frame
    local existing = ring
    if existing ~= nil then
        return existing
    end
    local r = Instance.new("Frame")
    r.Name = "BuildingSelection"
    r.BackgroundTransparency = 1
    r.BorderSizePixel = 0
    r.ZIndex = 2
    r.Visible = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = r
    local stroke = Instance.new("UIStroke")
    stroke.Name = "Edge"
    stroke.Color = Theme.COLOR.gold
    stroke.Thickness = 3
    stroke.Transparency = 0.15
    stroke.Parent = r
    r.Parent = deps.Scroll
    ring = r
    return r
end

local function moveRing(b: { [string]: any }, d: BuildingConfig.Def, startPulse: boolean)
    local r = ensureRing()
    local w, h = d.w * RiverConfig.TILE, d.h * RiverConfig.TILE
    r.Position = UDim2.fromOffset(b.x - 6, b.y - 6)
    r.Size = UDim2.fromOffset(w + 12, h + 12)
    r.Visible = true
    if not startPulse then
        return -- pulsul e un tween care se repeta la infinit; pornit din nou la fiecare
    end -- reimprospatare (de 4 ori pe secunda) s-ar stivui si nu s-ar opri niciodata
    local stroke = r:FindFirstChild("Edge") :: UIStroke?
    if stroke ~= nil then
        if ringPulse ~= nil then
            ringPulse:Cancel()
        end
        stroke.Transparency = 0.15
        local pulse = TweenService:Create(
            stroke,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Transparency = 0.6 }
        )
        ringPulse = pulse
        pulse:Play()
    end
end

local function ensureCard(): Frame
    local existing = card
    if existing ~= nil then
        return existing
    end
    local root, body = Widgets.Panel(deps.Scroll, "BuildingCard", 40)
    root.Size = UDim2.fromOffset(CARD_W, 200)
    root.Visible = false
    body.Position = UDim2.fromOffset(CARD_PAD, CARD_PAD)
    body.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2, 200 - CARD_PAD * 2)

    title = Widgets.Label(body, "", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    title.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2 - 34, 28)

    blurb = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 34)
    blurb.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2, 40)
    blurb.TextWrapped = true
    blurb.TextYAlignment = Enum.TextYAlignment.Top

    statLine = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
    statLine.Position = UDim2.fromOffset(0, 80)
    statLine.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2, 24)

    hereLine = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.inkSoft, "strong")
    hereLine.Position = UDim2.fromOffset(0, 106)
    hereLine.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2, 24)

    progressTrack, progressFill = Widgets.Bar(body, CARD_W - CARD_PAD * 2, 14, Theme.COLOR.good, 42)
    progressTrack.Position = UDim2.fromOffset(0, 108)
    progressTrack.Visible = false

    actionButton = Widgets.Button(body, {
        text = "",
        width = CARD_W - CARD_PAD * 2,
        height = 46,
        z = 42,
        onClick = function()
            local handler = actionHandler
            if handler ~= nil then
                handler()
            end
        end,
    })
    actionButton.Position = UDim2.fromOffset(0, 138)
    actionButton.Visible = false

    Widgets.CloseButton(root, 44, function()
        BuildingCardController.Hide()
    end)

    card = root
    content = body
    return root
end

-- Reaseaza cartonasul deasupra cladirii, tinut in lume. Daca n-are loc sus, trece dedesubt:
-- altfel, la o cladire de langa malul de nord, cartonasul ar iesi din lume.
local function placeCard(root: Frame, b: { [string]: any }, d: BuildingConfig.Def, height: number)
    local w = d.w * RiverConfig.TILE
    local cx = b.x + w / 2 - CARD_W / 2
    local above = b.y - height - 14
    local y = if above >= 8 then above else b.y + d.h * RiverConfig.TILE + 14
    local maxX = RiverConfig.WORLD_WIDTH - CARD_W - 8
    root.Position = UDim2.fromOffset(math.clamp(cx, 8, math.max(8, maxX)), y)
end

-- Umple cartonasul din starea CURENTA a cladirii. Se cheama si la deschidere, si pe ceas cat e
-- deschis: un santier isi vede bara crescand, iar numarul de oameni dinauntru se schimba singur.
local function refresh()
    local id = selectedId
    if id == nil then
        return
    end
    local root = card
    if root == nil or not root.Visible then
        return
    end
    local b = findBuilding(id)
    if b == nil then
        BuildingCardController.Hide() -- cladirea nu mai exista in starea trimisa de server
        return
    end
    local d = BuildingConfig.get(b.defId)
    if d == nil then
        return
    end

    local done = b.progress >= d.buildWork
    title.Text = d.label
    blurb.Text = d.blurb

    local kind = KINDS[d.kind]
    local capacity = if d.kind == "rest" then d.beds else d.slots
    local unit = if kind ~= nil then kind.unit else "places"

    if done then
        progressTrack.Visible = false
        statLine.Text = if capacity > 0 then `{capacity} {unit}` else "Stands on its own"
        statLine.TextColor3 = Theme.COLOR.ink
        hereLine.Position = UDim2.fromOffset(0, 106)
        local here = peopleInside(b, d)
        hereLine.Text = if here == 1
            then "1 person here right now"
            else `{here} people here right now`
    else
        -- santier: bara mare, procent, si cati constructori sunt efectiv pe el
        local pct = math.clamp(b.progress / math.max(1, d.buildWork), 0, 1)
        progressTrack.Visible = true
        progressFill.Size = UDim2.fromScale(pct, 1)
        statLine.Text = `Building — {math.floor(pct * 100)}%`
        statLine.TextColor3 = Theme.COLOR.warn
        hereLine.Position = UDim2.fromOffset(0, 128)
        local here = peopleInside(b, d)
        -- ADEVARUL, nu o trimitere catre un panou inca blocat. Textul de dinainte spunea
        -- "assign a Builder in People", dar la pasul care cere prima constructie panoul People
        -- nu e inca deschis: jucatorul era trimis undeva unde nu putea ajunge.
        -- Iar regula reala e alta: daca nu exista NICIUN constructor, pune mana oricine e liber.
        hereLine.Text = if here > 0
            then `{here} working on it`
            elseif
                deps.IsUnlocked("people")
            then "Nobody here yet — someone free will come, or set a Builder in People"
            else "Nobody here yet — someone will walk over when they are free"
    end

    -- Actiunea: doar unde chiar exista una. Un buton care nu face nimic e mai rau decat niciunul.
    local opener = if done and d.kind == "work" then deps.Open.workshop else nil
    local gateName = if d.kind == "work" then "workshop" else ""
    if opener ~= nil and deps.IsUnlocked(gateName) then
        actionHandler = opener
        actionButton.Text = "Open workshop"
        actionButton.Visible = true
    else
        actionHandler = nil
        actionButton.Visible = false
    end

    local bodyHeight = if actionButton.Visible then 138 + 46 elseif done then 106 + 24 else 128 + 24
    local total = bodyHeight + CARD_PAD * 2
    root.Size = UDim2.fromOffset(CARD_W, total)
    local body = content
    if body ~= nil then
        body.Size = UDim2.fromOffset(CARD_W - CARD_PAD * 2, bodyHeight)
    end
    cardHeight = total
    placeCard(root, b, d, total)
    moveRing(b, d, false)
end

function BuildingCardController.IsOpen(): boolean
    local root = card
    return root ~= nil and root.Visible
end

function BuildingCardController.Hide()
    selectedId = nil
    local root = card
    if root ~= nil then
        root.Visible = false
    end
    local r = ring
    if r ~= nil then
        r.Visible = false
    end
end

function BuildingCardController.Show(buildingId: number)
    if selectedId == buildingId and BuildingCardController.IsOpen() then
        BuildingCardController.Hide() -- a doua apasare pe aceeasi cladire inchide
        return
    end
    local b = findBuilding(buildingId)
    if b == nil then
        return
    end
    local d = BuildingConfig.get(b.defId)
    if d == nil then
        return
    end
    selectedId = buildingId
    local root = ensureCard()
    root.Visible = true
    refresh()
    moveRing(b, d, true) -- pulsul porneste o singura data, aici
    -- mica sarita la deschidere, ca sa se simta ca a raspuns apasarii
    -- inaltimea vine din refresh(), nu din AbsoluteSize: aceea se actualizeaza abia peste un
    -- cadru, deci animatia ar porni de la inaltimea cartonasului anterior
    root.Size = UDim2.fromOffset(CARD_W - 24, cardHeight)
    TweenService:Create(
        root,
        TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(CARD_W, cardHeight) }
    ):Play()
end

function BuildingCardController.Init(d: Deps)
    deps = d
    local accumulator = 0
    RunService.Heartbeat:Connect(function(dt: number)
        if not BuildingCardController.IsOpen() then
            return
        end
        accumulator += dt
        if accumulator < 0.25 then -- de 4 ori pe secunda ajunge; nu e un contor de reflexe
            return
        end
        accumulator = 0
        refresh()
    end)
end

return BuildingCardController
