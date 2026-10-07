--!strict
-- Panoul statiilor: cele trei debite ale lantului sus, apoi cate un rand pentru fiecare statie pe
-- care o poti urca. Panoul de nivel, in tiparul genului idle (inspirat de Idle Miner):
--
--   * fiecare rand arata CE ARE ACUM si CE-AR AVEA LA NIVELUL URMATOR, cu diferenta in verde.
--     Nimic ascuns: cifra din dreapta e exact ce primesti pe banii aia [D40].
--   * fiecare rand spune UNDE E URMATORUL SALT ("Next boost at level 10"), cu bara pana acolo.
--     Asta e mecanismul care te tine apasand: esti mereu la cateva niveluri de o dublare.
--   * multiplicatorul (x1/x10/x50/Max) e UNUL pentru tot panoul, nu cate patru butoane pe rand --
--     altfel randul devine o gradina de butoane si nu se mai citeste nimic.
--
-- Semnul de avertizare sta pe VERIGA SLABA. Un nivel pe o veriga care nu e gatuirea nu aduce nimic,
-- si panoul o spune pe fata in loc sa arate o cifra frumoasa care nu se intampla.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local ChainHead = require(ReplicatedStorage.Shared.Modules.ChainHead)
local HeldBack = require(ReplicatedStorage.Shared.Modules.HeldBack)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local EraWords = require(ReplicatedStorage.Shared.Modules.EraWords)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WorldConfig = require(ReplicatedStorage.Shared.Config.WorldConfig)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Row = {
    kind: string,
    id: string?,
    name: string,
    level: number,
    output: number,
    nextOutput: number,
    nextMilestone: number?,
    costs: { number },
    maxCount: number,
    maxCost: number,
    bottleneck: boolean,
    gain: number?, -- [D52] castigul real al unui nivel; 0 = nu aduce nimic pe loc (randul spune de ce)
    line: string?, -- [D56] "wood" | "iron"; nil = taverna
}

export type Snapshot = {
    rows: { Row },
    bottleneck: string,
    -- [D65] vederea pe linii (HeldBack.View): veriga slaba a fiecarei linii ("" = inca inchisa), debitul verigilor,
    -- si veriga care tine venitul fiecarui cartier, dupa numarul erei
    lines: { [string]: HeldBack.LineView },
    linkRates: { [string]: number },
    eraBottleneck: { string }?,
    -- [2026-09-30] oamenii (acelasi obiect ca pentru StationMenu): un echipaj la maxim pe veriga nu e sfatuit sa angajeze
    crews: { { role: string, plural: string, pad: string, maxed: boolean } }?,
}

export type Deps = {
    HudGui: Frame,
    Remotes: { UpgradeStation: RemoteEvent, UpgradeRejected: RemoteEvent },
    OnToast: (string, Color3?) -> (),
    -- [D65] unde esti (coordonatele lumii): panoul se deschide pe cartierul in care stai
    CharacterPos: (() -> (number, number))?,
    -- [2026-09-30] platforma e cumparata (PadController): un clopot tras nu mai e trimis ca pas urmator
    IsBought: ((padId: string) -> boolean)?,
    World: number?, -- [D70, pasul k2] harta: cartierele ei (la baraj, primul e al Erei 4)
    -- [verificatorul k6] barajul se poate ridica acum (in sat): langa x1/x10/x50/Max, ca in meniul obiectului
    DamAvailable: (() -> boolean)?,
}

local StationPanel = {}
local deps: Deps
local window: Frame
local body: Frame
local open = false

local PANEL_W, PANEL_H = 600, 720 -- [D56] +80: patru verigi ale fierului in capul panoului
local ROW_H = 96
local Z = 60

-- Capul panoului: debitele lantului [D49]. Acelasi lucru pe care Idle Miner il pune in "Mine
-- Overview" -- si tot acolo pune semnul de avertizare, pe veriga cea mai slaba. Panoul e ascuns (U)
-- [owner, 2026-09-12]; randurile de mai jos sunt doar cladirile -- meseriile au meniul lor.
-- [D56] Pe linii: prima linie, vanzatorul (al amandurora), apoi a doua linie, ascunsa cat e inchisa (ultima, ca sa nu
-- lase o gaura la mijloc). Semnul sta pe veriga slaba a fiecarei linii; la vanzator, pe cea care tine venitul.
-- [D65] UN CARTIER ODATA. Cu Era 2 lantul are 22 de verigi: toate intr-un cap de panou ar fi fost un perete de cifre.
-- Panoul arata cartierul ales (The Landing / The Mill), cu verigile si cladirile lui; comutatorul apare abia cand ai
-- ceva la Moara, deci in Era 1 panoul e exact cel de pana acum. Verigile vin din tabelul liniilor (ChainHead.rowsFor).
-- [D70, verificatorul k2] capul se masoara doar pe erele HARTII TALE (in Init, dupa lume): pe toate erele motorului, dupa
-- comutator, cele 18 verigi ale barajului ar fi impins in sat lista cladirilor la un singur rand. [pasul k4] La baraj, capul
-- sta pe doua coloane (ChainHead.layout).
local CHAIN_BY_ERA: { { ChainHead.Row } } = {}
local LAYOUT_BY_ERA: { ChainHead.Layout } = {}
local CHAIN_MAX = 0 -- randurile celei mai lungi coloane, pe erele hartii tale
local CHAIN_STEP = ChainHead.STEP -- unsprezece verigi [D56], cate 20
local HEAD_SHIFT = 0 -- tot ce sta sub cap coboara cu verigile adaugate dupa D55 (socotit in Init)
local TABS_H = 44 -- randul comutatorului de cartier; 0 cat nu exista decat The Landing

local advice: TextLabel
local damNote: TextLabel -- [verificatorul k6]
-- capul fiecarui cartier, pe era; in el, pe index: "nets" apare de doua ori (plasele fiecarei linii)
type ChainHeadView = {
    frame: Frame,
    parts: { { GuiObject } },
    value: { TextLabel },
    warn: { TextLabel },
}
local heads: { ChainHeadView } = {}
local shownEra = 1 -- cartierul ales
local firstEra = 1 -- [D70, pasul k2] prima era a hartii tale (4 la baraj)
local world = 1
local shownRows: { Row } = {} -- randurile lui, in ordinea de pe ecran
local tabRow: Frame
local tabButtons: { TextButton } = {}
local belowTabs: { { object: GuiObject, y: number } } = {}
local rowsFrame: Frame
local rowHolder: ScrollingFrame
local bulkIndex = 1 -- 1..#BULK_STEPS, apoi "Max"
local bulkButtons: { TextButton } = {}
local lastSnapshot: Snapshot? = nil

local BULK_LABELS = { "x1", "x10", "x50", "Max" }
local MAX_INDEX = #BULK_LABELS

local function countFor(row: Row): number
    if bulkIndex == MAX_INDEX then
        return row.maxCount
    end
    return StationConfig.BULK_STEPS[bulkIndex] or 1
end

local function costFor(row: Row): number
    if bulkIndex == MAX_INDEX then
        return row.maxCost
    end
    return row.costs[bulkIndex] or math.huge
end

-- Un rand de statie. Se construieste o singura data si se rescrie la fiecare stare (pool), ca
-- panoul deschis sa nu reconstruiasca zeci de instante la fiecare mesaj de la server.
type RowView = {
    frame: Frame,
    title: TextLabel,
    level: TextLabel,
    now: TextLabel,
    gain: TextLabel,
    milestone: TextLabel,
    barFill: Frame,
    button: TextButton,
    cost: TextLabel,
    warn: TextLabel,
    gainArrow: ImageLabel?,
}

local views: { RowView } = {}

local function buildRow(index: number): RowView
    local frame = Instance.new("Frame")
    frame.Name = `Station{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = rowHolder
    Widgets.PillBackground(frame, Z + 2)

    -- LATIMEA RANDULUI E 536, NU 600. Panoul are 20 de rama pe fiecare latura, lista inca 8+8,
    -- si bara de derulare mananca ultimii 8. Cifrele de mai jos ies din
    -- scripts/art/check_station_row.py, care refuza sa treaca daca doua cutii se ating -- inainte
    -- erau socotite ca si cum randul ar fi fost cat panoul, si patru perechi se suprapuneau.
    local title = Widgets.Label(frame, "", Theme.TEXT.body, Theme.COLOR.onDark, "display")
    title.Position = UDim2.fromOffset(Theme.SPACE.md, 6)
    title.Size = UDim2.fromOffset(200, 22)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = Z + 3

    local level = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.gold, "strong")
    level.Position = UDim2.fromOffset(Theme.SPACE.md + 204, 6)
    level.Size = UDim2.fromOffset(146, 22)
    level.ZIndex = Z + 3

    local warn = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.warn, "strong")
    warn.Position = UDim2.fromOffset(Theme.SPACE.md, ROW_H - 22)
    warn.Size = UDim2.fromOffset(354, 18)
    warn.TextTruncate = Enum.TextTruncate.AtEnd
    warn.ZIndex = Z + 3

    local now = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDarkSoft, "body")
    now.Position = UDim2.fromOffset(Theme.SPACE.md, 32)
    now.Size = UDim2.fromOffset(180, 20)
    now.ZIndex = Z + 3

    local gain = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.good, "strong")
    gain.Position = UDim2.fromOffset(Theme.SPACE.md + 204, 32)
    gain.Size = UDim2.fromOffset(146, 20)
    gain.ZIndex = Z + 3

    local track, fill = Widgets.Bar(frame, 180, 6, Theme.COLOR.gold, Z + 3)
    track.Position = UDim2.fromOffset(Theme.SPACE.md, 60)

    local milestone = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    -- Butonul incepe la 374 (536 - 12 - 150), deci coloana din stanga se opreste la 362.
    milestone.Position = UDim2.fromOffset(Theme.SPACE.md + 184, 56)
    milestone.Size = UDim2.fromOffset(166, 18)
    milestone.TextTruncate = Enum.TextTruncate.AtEnd
    milestone.ZIndex = Z + 3

    local button = Widgets.Button(frame, {
        text = Strings.STATION_UPGRADE,
        width = 150,
        height = 46,
        z = Z + 3,
        onClick = function()
            local snap = lastSnapshot
            if snap == nil then
                return
            end
            local row = shownRows[index]
            if row == nil then
                return
            end
            local count = countFor(row)
            if count < 1 then
                deps.OnToast(Strings.STATION_NEED_MORE, Theme.COLOR.bad)
                return
            end
            SoundController.Play("click")
            deps.Remotes.UpgradeStation:FireServer(row.kind, row.id, count)
        end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 4)

    local cost = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.gold, "display")
    cost.AnchorPoint = Vector2.new(1, 0)
    cost.Position = UDim2.new(1, -Theme.SPACE.md, 0, 4)
    cost.Size = UDim2.fromOffset(130, 20)
    cost.TextXAlignment = Enum.TextXAlignment.Right
    cost.ZIndex = Z + 3

    -- Moneda in coltul din stanga al coloanei din dreapta, adica exact peste marginea de sus a
    -- butonului de dedesubt; eticheta pretului incepe la 20 de pixeli dupa ea.
    local costCoin = Widgets.CoinIcon(frame, 16, Z + 3)
    costCoin.Position = UDim2.new(1, -Theme.SPACE.md - 150, 0, 6)

    -- Sageata verde inaintea castigului. Castigul poate fi si zero (statia nu e veriga slaba) --
    -- atunci sageata s-ar contrazice cu cifra, deci se ascunde odata cu ea [D40].
    local gainArrow = Widgets.Icon(frame, "levelup", 16)
    if gainArrow ~= nil then
        gainArrow.Position = UDim2.fromOffset(Theme.SPACE.md + 184, 34)
        gainArrow.ZIndex = Z + 3
        gainArrow.Visible = false
    end

    return {
        frame = frame,
        title = title,
        level = level,
        now = now,
        gain = gain,
        milestone = milestone,
        barFill = fill,
        button = button,
        cost = cost,
        warn = warn,
        gainArrow = gainArrow,
    }
end

-- Era unui rand: o plasa, dupa platforma ei; o cladire, dupa veriga ei.
local function eraOfRow(row: Row): number
    if row.kind == "net" then
        local pad = TycoonConfig.byId[row.id or ""]
        return if pad ~= nil then pad.era else 1
    end
    return StationConfig.ERA_OF_LINK[row.kind] or 1
end

-- Ai ceva la Moara? Atunci apare comutatorul de cartier; pana atunci panoul e cel al Erei 1, neschimbat.
local function hasLaterEra(snap: Snapshot): boolean
    for _, row in snap.rows do
        if eraOfRow(row) > firstEra then
            return true
        end
    end
    return false
end

local function refreshRows(snap: Snapshot)
    table.clear(shownRows)
    for _, row in snap.rows do
        if eraOfRow(row) == shownEra then
            table.insert(shownRows, row)
        end
    end
    for i, row in shownRows do
        local view = views[i]
        if view == nil then
            view = buildRow(i)
            views[i] = view
        end
        view.frame.Visible = true
        view.title.Text = row.name
        view.level.Text = Strings.stationLevel(row.level)
        view.now.Text = `{TycoonMath.formatRate(row.output)}/s`

        local count = countFor(row)
        local delta = row.nextOutput - row.output
        view.gain.Text = if delta > 0 then `+{TycoonMath.formatRate(delta)}` else ""
        -- Sageata urmeaza EXACT cifra: cand nu e niciun castig de aratat, o sageata verde singura
        -- ar promite ceva ce randul nu spune [D40].
        local arrow = view.gainArrow
        if arrow ~= nil then
            arrow.Visible = delta > 0
        end

        -- bara pana la urmatorul salt: se vede cat mai ai, nu doar ca exista
        local next = row.nextMilestone
        if next ~= nil then
            local prev = 0
            for _, t in StationConfig.MILESTONES do
                if t < next then
                    prev = t
                end
            end
            local span = math.max(1, next - prev)
            view.barFill.Size = UDim2.fromScale(math.clamp((row.level - prev) / span, 0, 1), 1)
            view.milestone.Text = Strings.stationNextBoost(next)
        else
            view.barFill.Size = UDim2.fromScale(1, 1)
            view.milestone.Text = ""
        end

        -- PANOUL NU MINTE: daca un nivel nu aduce nimic ACUM, scrie asta si spune cine il tine pe loc. [D63] Se uita
        -- la CASTIGUL REAL al nivelului (`row.gain`, ca meniul obiectului din D52), nu la steagul "sunt eu veriga
        -- slaba": cu amandoua liniile pornite, Taverna care tinea lemnul scria "No gain yet — the Forge is slowest"
        -- desi un nivel la ea aducea mai mult decat unul la Forja. Forja fara plasa de scrap n-are nicio veriga care
        -- s-o tina, doar nu vine nimic [D56].
        local earns = (row.gain or 0) > 0
        if earns then
            view.warn.Text = ""
        else
            local mine = if row.kind == "net" then "nets" else row.kind
            local key, tie, holder = HeldBack.by(snap, mine, row.line)
            view.warn.Text = if key == nil
                then Strings.lineNotOpen(holder or row.line)
                else Strings.menuHeldBack(
                    key,
                    tie,
                    holder or HeldBack.netsLine(snap, row.line, mine),
                    holder
                )
        end
        view.gain.TextColor3 = if earns then Theme.COLOR.good else Theme.COLOR.onDarkSoft

        local cost = costFor(row)
        if count < 1 then
            view.cost.Text = Strings.STATION_CANT_AFFORD
            view.cost.TextColor3 = Theme.COLOR.bad
        else
            view.cost.Text = `{TycoonMath.formatNumber(cost)}  ({count})`
            view.cost.TextColor3 = Theme.COLOR.gold
        end
    end
    for i = #shownRows + 1, #views do
        views[i].frame.Visible = false
    end
    rowHolder.CanvasSize = UDim2.fromOffset(0, #shownRows * (ROW_H + Theme.SPACE.sm))
end

-- Comutatorul de cartier: apare cand ai ceva la Moara si impinge restul panoului in jos cu inaltimea lui.
local function layoutTabs(snap: Snapshot)
    local tabs = hasLaterEra(snap)
    if not tabs then
        shownEra = firstEra
    end
    tabRow.Visible = tabs
    local shift = if tabs then TABS_H else 0
    for _, entry in belowTabs do
        entry.object.Position = UDim2.fromOffset(0, entry.y + shift)
    end
    rowsFrame.Size = UDim2.new(1, 0, 1, -(250 + HEAD_SHIFT + shift))
    for era, button in tabButtons do
        Widgets.SetButtonTone(button, if era == shownEra then Theme.COLOR.gold else nil)
    end
    for era, head in heads do
        head.frame.Visible = era == shownEra
    end
end

local function refreshChain(snap: Snapshot)
    local eraBottleneck = if snap.eraBottleneck ~= nil then snap.eraBottleneck[shownEra] else nil
    local holds = if eraBottleneck ~= nil and eraBottleneck ~= ""
        then eraBottleneck
        else snap.bottleneck
    advice.Text = Strings.stationsAdvice(holds)
    -- [2026-09-30] veriga e un echipaj deja la maxim (2 oameni, treapta 5): "hire or upgrade" ar minti, deci acelasi text
    -- ca meniul lui (EraWords)
    for _, crew in snap.crews or {} do
        if crew.maxed and StationConfig.LINK_OF[crew.role] == holds then
            local isBought = deps.IsBought
            advice.Text = EraWords.maxedCrew(crew.plural, crew.pad, function(id: string): boolean
                return isBought ~= nil and isBought(id)
            end)
        end
    end
    -- plasa de sub frazele scurtate in Strings: pe un panou strans (telefon), randul se micsoreaza, nu iese din rama
    local width = window.Size.X.Offset - Theme.SPACE.lg * 2
    advice.TextSize = Theme.fitSize(advice.Text, Theme.TEXT.small, "strong", width)
    local head = heads[shownEra]
    local firstLine = StationConfig.ERA_LINES[shownEra][1]
    for i, entry in CHAIN_BY_ERA[shownEra] do
        local line = entry.line
        local lineView = if line ~= nil then snap.lines[line] else nil
        -- prima linie a cartierului se vede mereu; a doua abia cand se deschide
        local shown = line == nil
            or line == firstLine
            or (lineView ~= nil and lineView.bottleneck ~= "")
        for _, part in head.parts[i] or {} do
            part.Visible = shown
        end
        -- semnul: pe veriga slaba a liniei; la vanzator, pe cea care tine venitul cartierului
        local bottleneck = if line == nil
            then holds
            elseif lineView ~= nil then lineView.bottleneck
            else ""
        local slowest = shown and bottleneck == entry.key
        local label = head.value[i]
        if label ~= nil then
            label.Text = `{TycoonMath.formatRate(HeldBack.rateOf(snap, entry.key, line))}/s`
            label.TextColor3 = if slowest then Theme.COLOR.bad else Theme.COLOR.ink
        end
        local warn = head.warn[i]
        if warn ~= nil then
            warn.Visible = slowest
        end
    end
end

function StationPanel.Apply(snap: Snapshot?)
    if snap == nil then
        return
    end
    lastSnapshot = snap
    if not open then
        return
    end
    layoutTabs(snap)
    refreshChain(snap)
    refreshRows(snap)
    local damReady = deps.DamAvailable
    damNote.Visible = damReady ~= nil and damReady() -- [verificatorul k6]
end

function StationPanel.IsOpen(): boolean
    return open
end

function StationPanel.Close()
    open = false
    window.Visible = false
end

-- [D65] Cartierul in care stai acum, daca ai ceva acolo: panoul se deschide pe el, nu mereu pe The Landing.
local function eraUnderfoot(): number?
    local characterPos = deps.CharacterPos
    if characterPos == nil then
        return nil
    end
    local x = characterPos() - TycoonConfig.PLOT_ORIGIN.x
    for _, zone in TycoonConfig.zonesOf(world) do
        if x >= zone.x0 and x < zone.x1 and CHAIN_BY_ERA[zone.era] ~= nil then
            return zone.era
        end
    end
    return nil
end

function StationPanel.Open()
    Panels.CloseOthers("stations")
    shownEra = eraUnderfoot() or shownEra -- fara nimic la Moara, `layoutTabs` il intoarce pe The Landing
    open = true
    window.Visible = true
    SoundController.Play("click")
    StationPanel.Apply(lastSnapshot)
end

-- Inelul auriu care arata CE rand a fost cerut. Pe un copil, nu pe rand: Widgets.PillBackground
-- poate pune singur un UIStroke pe rand, iar doua UIStroke pe acelasi obiect nu se aduna -- unul
-- dispare in tacere.
local function flashRow(frame: Frame)
    local ring = frame:FindFirstChild("Focus")
    if ring == nil then
        local f = Instance.new("Frame")
        f.Name = "Focus"
        f.BackgroundTransparency = 1
        f.Size = UDim2.fromScale(1, 1)
        f.ZIndex = Z + 6
        f.Parent = frame
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 10)
        corner.Parent = f
        local stroke = Instance.new("UIStroke")
        stroke.Name = "Stroke"
        stroke.Color = Theme.COLOR.gold
        stroke.Thickness = 3
        stroke.Transparency = 1
        stroke.Parent = f
        ring = f
    end
    local stroke = (ring :: Instance):FindFirstChild("Stroke") :: UIStroke
    stroke.Transparency = 0
    TweenService:Create(
        stroke,
        TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Transparency = 1 }
    ):Play()
end

-- Deschide panoul DIRECT pe o statie: apasarea plasei din lume, a debarcaderului, a unui angajat,
-- sau Go! la un quest de nivel. Owner-ul: "nu am vazut optiune de upgrade la urmatorul nivel pe
-- nicaieri" -- panoul exista, dar singura cale spre el era un buton din bara de meniu.
function StationPanel.OpenAt(kind: string, id: string?)
    if not open then
        if not Panels.CanOpen("stations") then
            return
        end
        StationPanel.Open()
    end
    local snap = lastSnapshot
    if snap == nil then
        return
    end
    -- randul cerut poate fi in celalalt cartier: intai se muta panoul acolo
    for _, row in snap.rows do
        if row.kind == kind and (id == nil or row.id == id) then
            if eraOfRow(row) ~= shownEra then
                shownEra = eraOfRow(row)
                StationPanel.Apply(snap)
            end
            break
        end
    end
    for i, row in shownRows do
        if row.kind == kind and (id == nil or row.id == id) then
            -- Randurile au inaltime fixa, deci pozitia se calculeaza. A doua oara dupa un cadru:
            -- abia deschisa, lista inca n-are marimea finala si Roblox ar taia pozitia la zero.
            local y = (i - 1) * (ROW_H + Theme.SPACE.sm)
            rowHolder.CanvasPosition = Vector2.new(0, y)
            task.delay(0, function()
                rowHolder.CanvasPosition = Vector2.new(0, y)
            end)
            local view = views[i]
            if view ~= nil then
                flashRow(view.frame)
            end
            return
        end
    end
end

function StationPanel.Toggle()
    if open then
        StationPanel.Close()
    else
        StationPanel.Open()
    end
end

function StationPanel.Init(d: Deps)
    deps = d
    world = WorldConfig.sanitize(d.World)
    firstEra = WorldConfig.FIRST_ERA[world]
    shownEra = firstEra
    for era in StationConfig.ERA_LINES do
        if WorldConfig.worldOfEra(era) == world then
            CHAIN_BY_ERA[era] = ChainHead.rowsFor(era)
            LAYOUT_BY_ERA[era] = ChainHead.layout(CHAIN_BY_ERA[era])
            CHAIN_MAX = math.max(CHAIN_MAX, LAYOUT_BY_ERA[era].rows)
        end
    end
    HEAD_SHIFT = ChainHead.shift(CHAIN_MAX)
    local root, content = Widgets.Window(deps.HudGui, {
        name = "StationPanel",
        title = Strings.STATIONS_TITLE,
        icon = "hammer",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = StationPanel.Close,
    })
    window = root
    body = content
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    -- [D65] comutatorul de cartier: ascuns cat ai doar The Landing
    tabRow = Instance.new("Frame")
    tabRow.Name = "Districts"
    tabRow.BackgroundTransparency = 1
    tabRow.Size = UDim2.new(1, 0, 0, TABS_H)
    tabRow.ZIndex = Z + 1
    tabRow.Visible = false
    tabRow.Parent = body
    local tabIndex = 0
    for era in StationConfig.ERA_LINES do
        -- [D70, pasul k2] doar cartierele hartii tale, de la stanga, cu numele zonei din lumea lor
        if WorldConfig.worldOfEra(era) ~= world then
            continue
        end
        tabIndex += 1
        local zoneName = `Era {era}`
        for _, zone in TycoonConfig.zonesOf(world) do
            if zone.era == era then
                zoneName = zone.name
            end
        end
        local button = Widgets.Button(tabRow, {
            text = zoneName,
            width = 200,
            height = 36,
            z = Z + 2,
            onClick = function()
                if shownEra ~= era then
                    shownEra = era
                    SoundController.Play("click")
                    rowHolder.CanvasPosition = Vector2.zero
                    StationPanel.Apply(lastSnapshot)
                end
            end,
        })
        button.Position = UDim2.fromOffset((tabIndex - 1) * 208, 0)
        tabButtons[era] = button
    end

    -- capul panoului: debitele lantului, cate un cap pe cartier (se vede doar cel ales)
    for era, rows in CHAIN_BY_ERA do
        local head = Instance.new("Frame")
        head.Name = `Chain{era}`
        head.BackgroundTransparency = 1
        head.Size = UDim2.new(1, 0, 0, CHAIN_MAX * CHAIN_STEP + 2) -- unsprezece verigi x 20 [D49, D56]
        head.ZIndex = Z + 1
        head.Visible = era == shownEra
        head.Parent = body
        table.insert(belowTabs, { object = head, y = 0 })
        local view: ChainHeadView = { frame = head, parts = {}, value = {}, warn = {} }
        heads[era] = view
        local layout = LAYOUT_BY_ERA[era]
        local cell = ChainHead.CELL[layout.columns]
        for i, entry in rows do
            local at = layout.cells[i]
            local y = (at.row - 1) * CHAIN_STEP
            local x0 = if at.column == 2 then ChainHead.SECOND_COLUMN_X else 0
            local parts: { GuiObject } = {}
            view.parts[i] = parts
            local icon = Widgets.Icon(head, entry.icon, 16)
            if icon ~= nil then
                icon.Position = UDim2.fromOffset(x0 + cell.icon, y + 2)
                icon.ZIndex = Z + 2
                table.insert(parts, icon)
            end
            local name =
                Widgets.Label(head, entry.label, Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
            name.Position = UDim2.fromOffset(x0 + cell.name, y)
            name.Size = UDim2.fromOffset(cell.nameW, CHAIN_STEP)
            name.ZIndex = Z + 2
            table.insert(parts, name)
            local value = Widgets.Label(head, "0/s", Theme.TEXT.small, Theme.COLOR.ink, "display")
            value.Position = UDim2.fromOffset(x0 + cell.value, y)
            value.Size = UDim2.fromOffset(cell.valueW, CHAIN_STEP)
            value.TextXAlignment = Enum.TextXAlignment.Right
            value.ZIndex = Z + 2
            table.insert(parts, value)
            view.value[i] = value
            local warn =
                Widgets.Label(head, cell.warnText, Theme.TEXT.tiny, Theme.COLOR.warn, "strong")
            warn.Position = UDim2.fromOffset(x0 + cell.warn, y)
            warn.Size = UDim2.fromOffset(cell.warnW, CHAIN_STEP)
            warn.Visible = false
            warn.ZIndex = Z + 2
            view.warn[i] = warn
        end
    end

    -- DE CE conteaza cifrele de mai sus, si ce sa faci cu ele. Fara randurile astea doua, panoul
    -- e trei numere si patru butoane, si nimeni nu stie ce a deschis.
    local explain =
        Widgets.Label(body, Strings.STATIONS_EXPLAIN, Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    explain.Position = UDim2.fromOffset(0, 146 + HEAD_SHIFT)
    explain.Size = UDim2.new(1, 0, 0, 20)
    explain.ZIndex = Z + 1
    table.insert(belowTabs, { object = explain, y = 146 + HEAD_SHIFT })

    advice = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
    advice.Position = UDim2.fromOffset(0, 168 + HEAD_SHIFT)
    advice.Size = UDim2.new(1, 0, 0, 20)
    advice.ZIndex = Z + 1
    table.insert(belowTabs, { object = advice, y = 168 + HEAD_SHIFT })

    -- multiplicatorul: unul pentru tot panoul
    local bulkRow = Instance.new("Frame")
    bulkRow.Name = "Bulk"
    bulkRow.BackgroundTransparency = 1
    bulkRow.Position = UDim2.fromOffset(0, 198 + HEAD_SHIFT)
    bulkRow.Size = UDim2.new(1, 0, 0, 44)
    table.insert(belowTabs, { object = bulkRow, y = 198 + HEAD_SHIFT })

    local bulkLabel =
        Widgets.Label(bulkRow, Strings.STATION_BULK, Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    bulkLabel.Position = UDim2.fromOffset(0, 12)
    bulkLabel.Size = UDim2.fromOffset(96, 20)
    bulkLabel.ZIndex = Z + 2
    bulkRow.ZIndex = Z + 1
    bulkRow.Parent = body
    for i, label in BULK_LABELS do
        local button = Widgets.Button(bulkRow, {
            text = label,
            width = 76,
            height = 36,
            z = Z + 2,
            onClick = function()
                bulkIndex = i
                -- Tonul, nu BackgroundTransparency: sub sprite, un fundal opac apare ca un
                -- dreptunghi alb in colturile rotunjite ale butonului ales.
                for j, b in bulkButtons do
                    Widgets.SetButtonTone(b, if j == i then Theme.COLOR.gold else nil)
                end
                StationPanel.Apply(lastSnapshot)
            end,
        })
        button.Position = UDim2.fromOffset(104 + (i - 1) * 82, 4)
        Widgets.SetButtonTone(button, if i == 1 then Theme.COLOR.gold else nil)
        bulkButtons[i] = button
    end
    -- [verificatorul k6] „Goes into the Dam when you build it”, in dreapta butoanelor, pe doua randuri. [k6-k8] Butonul Max
    -- se termina la 104 + 3 * 82 + 76 = 426: nota incepe dupa el, cu SPACE.sm gol (434..560)
    local noteX = 104 + 3 * 82 + 76 + Theme.SPACE.sm
    damNote =
        Widgets.Label(bulkRow, Strings.GOES_INTO_DAM, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    damNote.Position = UDim2.fromOffset(noteX, 0)
    damNote.Size = UDim2.new(1, -noteX, 0, 44)
    damNote.TextWrapped = true
    damNote.TextXAlignment = Enum.TextXAlignment.Right
    damNote.TextYAlignment = Enum.TextYAlignment.Center
    damNote.ZIndex = Z + 2
    damNote.Visible = false

    rowHolder = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    rowsFrame = rowHolder.Parent :: Frame
    rowsFrame.Position = UDim2.fromOffset(0, 250 + HEAD_SHIFT)
    rowsFrame.Size = UDim2.new(1, 0, 1, -(250 + HEAD_SHIFT))
    table.insert(belowTabs, { object = rowsFrame, y = 250 + HEAD_SHIFT })

    -- Refuzurile de nivel le anunta StationMenu: lista asta a ramas ascunsa (tasta U), iar doua
    -- ascultari ar fi dublat fiecare mesaj.

    Panels.Register("stations", { isOpen = StationPanel.IsOpen, close = StationPanel.Close })
end

return StationPanel
