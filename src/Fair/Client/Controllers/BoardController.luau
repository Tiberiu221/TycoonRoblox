--!strict
-- [D60] SCENA, ADICA TABELA BALCIULUI. Owner-ul: "scena mai mare sa incapa cat mai multe stats pentru etalare".
-- Pe cele trei panouri pictate pe scena se scriu clasamentele saptamanii (BIGGEST FISH, RICHEST RIVER, FASTEST ERA 1),
-- cate sase randuri; randul tau e auriu, iar cand nu esti printre primii sase, ultimul rand spune unde esti [D43].
-- In fata scenei, sub cele patru trofee, cele mai mari exemplare prinse vreodata; sub soclu, campionul saptamanii
-- trecute. Langa scena, cardul `Leaderboards (E)` deschide panoul mare: aceleasi clasamente intregi, cu specia
-- pestelui, si toate cele 12 trofee.
--
-- Cifrele vin gata citite de la server (BoardService); randurile le face BoardMath, ca desenul sa nu socoteasca.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local BoardMath = require(ReplicatedStorage.Shared.Modules.BoardMath)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { World: Frame, HudGui: Frame, BoardState: RemoteEvent }

type Trophy = { species: string, name: string, cm: number, userId: number }
type State = {
    boards: { [string]: { BoardMath.Entry } },
    champion: { userId: number, name: string }?,
    trophies: { Trophy },
}

local BoardController = {}
local deps: Deps? = nil
local state: State =
    { boards = { fish = {}, income = {}, era1 = {} }, champion = nil, trophies = {} }
local me = Players.LocalPlayer.UserId

-- ---- panourile de pe scena -----------------------------------------------------------------------
-- Geometria vine din desen (scripts/art/d60.py, stage_big): 200x112 la x3; panoul i are hartia la
-- x = 22 + 57 i, y = 24, 49x48 pixeli de desen, cu capul de tabel in primii 6. Pe hartie sunt pictate sase randuri din
-- 7 in 7 pixeli (primul la y = 33): un patratel in culoarea tabelei (x 3..6) si o linie care tine locul textului.
-- In Studio (2026-09-17), hartia plata pusa peste ele lumina ca un ecran: scena e colorata de lumina locului
-- (FairScene.LitTint), hartia nu era. Acum hartia are culoarea celei pictate, trecuta prin aceeasi lumina, si acopera
-- doar liniile; patratelul ramane gol pe randul liber si devine insigna cu locul pe randul ocupat.
local ART = 3
local PANEL_X0, PANEL_STEP, PANEL_Y, PANEL_W, PANEL_H, HEAD_H = 22, 57, 24, 49, 48, 6
-- in unitati de lume, fata de coltul panoului (check_panel_rows.py tine aceleasi cifre)
local ROW_Y, ROW_STEP, ROW_H = 33, 21, 20 -- centrul primului rand pictat, pasul, inaltimea textului
local BULLET_X = 15 -- centrul patratelului pictat
local COVER_X = 24 -- de aici incep liniile pictate
local TEXT_X, TEXT_RIGHT = 27, PANEL_W * ART - 4
local VALUE_W = 60 -- BoardMath.STAGE_CHARS (opt) litere de pixeli la TEXT.tiny
local PAPER_ART = Color3.fromRGB(255, 250, 224) -- hartia din desen
local ACCENT_ART: { [string]: Color3 } = {
    fish = Color3.fromRGB(135, 171, 190),
    income = Color3.fromRGB(204, 168, 69),
    era1 = Color3.fromRGB(95, 156, 118),
}
local INK = Color3.fromRGB(58, 42, 30)
-- dunga randului tau: singura culoare care nu trece prin lumina, ca sa se vada de departe
local MINE = Color3.fromRGB(214, 186, 120)

type RowView = { badge: Frame, rank: TextLabel, stripe: Frame, name: TextLabel, value: TextLabel }
type PanelView = { rows: { RowView }, empty: TextLabel }
local panels: { [string]: PanelView } = {}
local trophyTags: { TextLabel } = {}
local trophyCaption: TextLabel
local championTag: TextLabel

local function worldLabel(parent: Instance, size: number, color: Color3, kind: string): TextLabel
    local l = Widgets.Label(parent, "", size, color, kind)
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.ZIndex = FairScene.Z.LABELS
    return l
end

-- Culoarea desenului asa cum o arata lumina locului (ImageColor3 inmulteste la fel).
local function lit(color: Color3, light: Color3): Color3
    return Color3.new(color.R * light.R, color.G * light.G, color.B * light.B)
end

local function block(
    parent: Instance,
    name: string,
    x: number,
    y: number,
    w: number,
    h: number,
    color: Color3,
    z: number
): Frame
    local f = Instance.new("Frame")
    f.Name = name
    f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
    f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function buildRow(world: Frame, kind: string, x: number, cy: number, light: Color3): RowView
    local z = FairScene.Z.LABELS
    local stripe =
        block(world, "Mine", x + 3, cy - ROW_H / 2, PANEL_W * ART - 6, ROW_H, MINE, z - 2)
    stripe.Visible = false
    local badge =
        block(world, "Rank", x + BULLET_X, cy, 16, 16, lit(ACCENT_ART[kind], light), z - 1)
    badge.AnchorPoint = Vector2.new(0.5, 0.5)
    badge.Visible = false
    local rank = Widgets.Label(badge, "", 12, Theme.COLOR.onDark, "strong")
    rank.Size = UDim2.fromScale(1, 1)
    rank.TextXAlignment = Enum.TextXAlignment.Center
    rank.ZIndex = z
    local name = worldLabel(world, Theme.TEXT.tiny, INK, "body")
    name.Position = UDim2.fromOffset(x + TEXT_X, cy - ROW_H / 2)
    name.Size = UDim2.fromOffset(TEXT_RIGHT - VALUE_W - 2 - TEXT_X, ROW_H)
    local value = worldLabel(world, Theme.TEXT.tiny, INK, "strong")
    value.Position = UDim2.fromOffset(x + TEXT_RIGHT - VALUE_W, cy - ROW_H / 2)
    value.Size = UDim2.fromOffset(VALUE_W, ROW_H)
    value.TextXAlignment = Enum.TextXAlignment.Right
    return { badge = badge, rank = rank, stripe = stripe, name = name, value = value }
end

local function buildPanels(world: Frame)
    local sx, sy, sw, sh = FairScene.Spot("stage")
    local left, top = sx - sw / 2, sy - sh
    local light = FairScene.LitTint(sx, sy) -- aceeasi lumina ca desenul scenei (FairScene.Build)
    local paper = lit(PAPER_ART, light)
    local rule = paper:Lerp(INK, 0.18)
    for i, kind in BoardMath.KINDS do
        local x = left + (PANEL_X0 + (i - 1) * PANEL_STEP) * ART
        local y = top + PANEL_Y * ART
        local paperTop = y + HEAD_H * ART
        local paperW, paperH = PANEL_W * ART - COVER_X, (PANEL_H - HEAD_H) * ART
        block(
            world,
            `Board_{kind}`,
            x + COVER_X,
            paperTop,
            paperW,
            paperH,
            paper,
            FairScene.Z.LABELS - 3
        )

        local head = worldLabel(world, Theme.TEXT.tiny, Theme.COLOR.onDark, "display")
        head.Position = UDim2.fromOffset(x, y)
        head.Size = UDim2.fromOffset(PANEL_W * ART, HEAD_H * ART)
        head.TextXAlignment = Enum.TextXAlignment.Center
        head.Text = (Strings.STAGE_TITLES :: any)[kind]
        Theme.punch(head, 1)

        local rows: { RowView } = {}
        for r = 1, BoardMath.ROWS do
            local cy = y + ROW_Y + (r - 1) * ROW_STEP
            if r < BoardMath.ROWS then
                -- liniile caietului, intre randuri: panoul gol nu mai e o foaie alba
                local ruleY = cy + ROW_STEP / 2
                block(
                    world,
                    "Rule",
                    x + TEXT_X,
                    ruleY,
                    TEXT_RIGHT - TEXT_X,
                    1,
                    rule,
                    FairScene.Z.LABELS - 2
                )
            end
            table.insert(rows, buildRow(world, kind, x, cy, light))
        end
        -- o eticheta pe foaia liniata: liniile se opresc in jurul textului, nu trec prin el (vazut in Studio)
        local emptyText = Strings.STAGE_EMPTY_BOARD
        local emptyW = math.ceil(Theme.textWidth(emptyText, Theme.TEXT.tiny, "strong")) + 12
        local emptyH = math.ceil(Theme.textHeight(emptyText, Theme.TEXT.tiny, "strong", emptyW)) + 6
        local empty = worldLabel(world, Theme.TEXT.tiny, INK, "strong")
        empty.AnchorPoint = Vector2.new(0.5, 0.5)
        empty.Position = UDim2.fromOffset(x + COVER_X + paperW / 2, paperTop + paperH / 2)
        empty.Size = UDim2.fromOffset(emptyW, emptyH)
        empty.BackgroundColor3 = paper
        empty.BackgroundTransparency = 0
        empty.BorderSizePixel = 0
        empty.TextXAlignment = Enum.TextXAlignment.Center
        empty.TextTruncate = Enum.TextTruncate.None
        empty.Text = emptyText
        panels[kind] = { rows = rows, empty = empty }
    end
end

local function stageValue(kind: string, value: number): string
    return BoardMath.compact(kind, value) .. (Strings.STAGE_UNITS :: any)[kind]
end

local function drawPanel(kind: string)
    local view = panels[kind]
    if view == nil then
        return
    end
    local entries = state.boards[kind] or {}
    local rows = BoardMath.rows(kind, entries, me)
    local mine = BoardMath.myLine(kind, entries, me)
    if mine ~= nil then
        rows[BoardMath.ROWS] = mine -- ultimul rand spune unde esti
    end
    -- valorile scurte de pe scena se refac din intrari: BoardMath.rows scrie formatul lung (cu specia)
    local sorted = table.clone(entries)
    table.sort(sorted, function(a, b)
        if a.value == b.value then
            return a.userId < b.userId
        end
        return BoardMath.better(kind, a.value, b.value)
    end)
    view.empty.Visible = #entries == 0
    for r, cells in view.rows do
        local row = rows[r]
        cells.badge.Visible = row ~= nil
        cells.stripe.Visible = row ~= nil and row.mine
        if row == nil then
            cells.name.Text = ""
            cells.value.Text = ""
            continue
        end
        local entry = sorted[row.rank]
        cells.rank.Text = tostring(row.rank)
        cells.badge.Size = UDim2.fromOffset(if row.rank >= 10 then 22 else 16, 16)
        cells.name.Text = row.name
        cells.value.Text = if entry ~= nil then stageValue(kind, entry.value) else ""
    end
end

local function buildTags(world: Frame)
    -- etichetele sunt doar text cu contur, ca in restul balciului (fara placi negre)
    local size = FairLayout.TROPHY_TAG
    local firstX, lastX, baseY = math.huge, -math.huge, 0
    for i = 1, 4 do
        local x, y = FairScene.Spot(`trophy_{i}`)
        local tag = Widgets.Label(world, "", Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
        tag.AnchorPoint = Vector2.new(0.5, 0)
        tag.Position = UDim2.fromOffset(x, y + size.gap)
        tag.Size = UDim2.fromOffset(size.w, size.h)
        tag.TextXAlignment = Enum.TextXAlignment.Center
        tag.TextYAlignment = Enum.TextYAlignment.Top
        tag.TextWrapped = true
        tag.ZIndex = FairScene.Z.LABELS
        Theme.punch(tag, 2)
        trophyTags[i] = tag
        firstX, lastX, baseY = math.min(firstX, x), math.max(lastX, x), y
    end
    -- cand nu e niciun record: o singura fraza sub tot randul, nu de patru ori aceeasi
    trophyCaption =
        Widgets.Label(world, Strings.TROPHIES_EMPTY, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    trophyCaption.AnchorPoint = Vector2.new(0.5, 0)
    trophyCaption.Position = UDim2.fromOffset((firstX + lastX) / 2, baseY + size.gap)
    trophyCaption.Size = UDim2.fromOffset(lastX - firstX + size.w, 20)
    trophyCaption.TextXAlignment = Enum.TextXAlignment.Center
    trophyCaption.TextYAlignment = Enum.TextYAlignment.Top
    trophyCaption.ZIndex = FairScene.Z.LABELS
    Theme.punch(trophyCaption, 2)
    -- deasupra soclului: dedesubt trece stalpul steagului din dreapta scenei
    local px, py, _, ph = FairScene.Spot("plinth")
    championTag = Widgets.Label(world, "", Theme.TEXT.tiny, Theme.COLOR.gold, "strong")
    championTag.AnchorPoint = Vector2.new(0.5, 1)
    championTag.Position = UDim2.fromOffset(px, py - ph - 4)
    championTag.Size = UDim2.fromOffset(
        math.ceil(Theme.textWidth(Strings.CHAMPION_TAG, Theme.TEXT.tiny, "strong")) + 20,
        36
    )
    championTag.TextXAlignment = Enum.TextXAlignment.Center
    championTag.ZIndex = FairScene.Z.LABELS
    Theme.punch(championTag, 2)
end

-- Un nume lung ar trece pe al patrulea rand al etichetei: se taie la `limit` litere, cu punct.
local function short(text: string, limit: number): string
    local length = utf8.len(text)
    if length == nil or length <= limit then
        return text
    end
    local cut = utf8.offset(text, limit)
    return if cut ~= nil then `{string.sub(text, 1, cut - 1)}.` else text
end

local function drawTags()
    local none = #state.trophies == 0
    trophyCaption.Visible = none
    for i, tag in trophyTags do
        local t = state.trophies[i]
        tag.Text = if t ~= nil
            then `{t.species}\n{Strings.trophyLine(t.cm)}\n{short(
                t.name,
                FairLayout.TROPHY_TAG.chars
            )}`
            elseif none then ""
            else Strings.TROPHY_OPEN
    end
    local champion = state.champion
    championTag.Text =
        `{Strings.CHAMPION_TAG}\n{if champion ~= nil then champion.name else Strings.STAGE_EMPTY}`
end

-- ---- panoul mare ---------------------------------------------------------------------------------
local PANEL_WIDTH, PANEL_HEIGHT = 640, 560
local Z = 68
local LIST_ROW = 30
local TABS = { "fish", "income", "era1", "trophies" }
local window: Frame
local open = false
local tab = "fish"
local tabButtons: { [string]: TextButton } = {}
local blurb: TextLabel
local list: ScrollingFrame
type ListRow = { frame: Frame, rank: TextLabel, name: TextLabel, value: TextLabel }
local listRows: { ListRow } = {}

local function listRow(index: number): ListRow
    local row = listRows[index]
    if row ~= nil then
        return row
    end
    local frame = Instance.new("Frame")
    frame.Name = `Row{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, LIST_ROW)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = list
    Widgets.PillBackground(frame, Z + 2)
    local rank = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "display")
    rank.Position = UDim2.fromOffset(Theme.SPACE.sm, 4)
    rank.Size = UDim2.fromOffset(40, 22)
    rank.ZIndex = Z + 3
    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(52, 4)
    name.Size = UDim2.fromOffset(250, 22)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3
    local value = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    value.AnchorPoint = Vector2.new(1, 0)
    value.Position = UDim2.new(1, -Theme.SPACE.sm, 0, 4)
    value.Size = UDim2.fromOffset(240, 22)
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.TextTruncate = Enum.TextTruncate.AtEnd
    value.ZIndex = Z + 3
    row = { frame = frame, rank = rank, name = name, value = value }
    listRows[index] = row
    return row
end

local function refreshPanel()
    for key, b in tabButtons do
        Widgets.SetButtonTone(b, if key == tab then Theme.COLOR.gold else nil)
    end
    local lines: { { rank: string, name: string, value: string, mine: boolean } } = {}
    if tab == "trophies" then
        blurb.Text = Strings.STAGES_TROPHIES_BLURB
        local bySpecies: { [string]: Trophy } = {}
        for _, t in state.trophies do
            bySpecies[t.species] = t
        end
        for _, species in FishConfig.SPECIES do
            local t = bySpecies[species.name]
            table.insert(lines, {
                rank = "",
                name = species.name,
                value = if t ~= nil
                    then `{Strings.trophyLine(t.cm)}  {t.name}`
                    else Strings.TROPHY_NONE,
                mine = t ~= nil and t.userId == me,
            })
        end
    else
        local entries = state.boards[tab] or {}
        blurb.Text = if #entries > 0 then Strings.STAGES_BLURB else Strings.STAGES_EMPTY
        for _, row in BoardMath.rows(tab, entries, me) do
            table.insert(
                lines,
                { rank = `#{row.rank}`, name = row.name, value = row.value, mine = row.mine }
            )
        end
        local mine = BoardMath.myLine(tab, entries, me)
        if mine ~= nil then
            table.insert(
                lines,
                { rank = `#{mine.rank}`, name = mine.name, value = mine.value, mine = true }
            )
        end
    end
    for i, line in lines do
        local row = listRow(i)
        row.frame.Visible = true
        row.rank.Text = line.rank
        row.name.Text = line.name
        row.value.Text = line.value
        local color = if line.mine then Theme.COLOR.gold else Theme.COLOR.onDark
        row.name.TextColor3 = color
        row.value.TextColor3 = color
    end
    for i = #lines + 1, #listRows do
        listRows[i].frame.Visible = false
    end
    list.CanvasSize = UDim2.fromOffset(0, #lines * (LIST_ROW + Theme.SPACE.xs))
end

function BoardController.IsOpen(): boolean
    return open
end

function BoardController.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function BoardController.Open(which: string?)
    tab = which or tab
    Panels.CloseOthers("stage")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refreshPanel()
end

-- Cardul scenei: in fata ei (unde stau si trofeele) scrie `Leaderboards (E)`; langa trofee, panoul se deschide pe ele.
function BoardController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local sx, sy = FairScene.Spot("stage")
    local tx, ty = FairScene.Spot("trophy_2")
    local toStage = Focus.distance(px, py, sx, sy + 60)
    local toTrophies = Focus.distance(px, py, tx + 45, ty + 30)
    local distance = math.min(toStage, toTrophies)
    if distance > 150 then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local which = if toTrophies < toStage then "trophies" else nil
    return {
        key = "stage",
        distance = distance,
        x = sx,
        y = sy - 4,
        action = Strings.stagesCard(keyHint),
        act = function()
            BoardController.Open(which)
        end,
    }
end

local function apply(raw: any)
    if typeof(raw) ~= "table" then
        return
    end
    -- copiat camp cu camp [CLAUDE.md, capcana 3]
    local boards: { [string]: { BoardMath.Entry } } = {}
    for _, kind in BoardMath.KINDS do
        local entries: { BoardMath.Entry } = {}
        local rawBoards: any = raw.boards or {}
        for _, e in (rawBoards[kind] or {}) :: { any } do
            if
                typeof(e) == "table"
                and typeof(e.userId) == "number"
                and typeof(e.value) == "number"
            then
                table.insert(entries, {
                    userId = e.userId,
                    name = if typeof(e.name) == "string" then e.name else "",
                    value = e.value,
                    extra = if typeof(e.extra) == "string" then e.extra else nil,
                })
            end
        end
        boards[kind] = entries
    end
    local trophies: { Trophy } = {}
    for _, t in (raw.trophies or {}) :: { any } do
        if typeof(t) == "table" and typeof(t.cm) == "number" then
            table.insert(trophies, {
                species = if typeof(t.species) == "string" then t.species else "",
                name = if typeof(t.name) == "string" then t.name else "",
                cm = t.cm,
                userId = if typeof(t.userId) == "number" then t.userId else 0,
            })
        end
    end
    local c: any = raw.champion
    state = {
        boards = boards,
        champion = if typeof(c) == "table" and typeof(c.userId) == "number"
            then { userId = c.userId, name = if typeof(c.name) == "string" then c.name else "" }
            else nil,
        trophies = trophies,
    }
    for _, kind in BoardMath.KINDS do
        drawPanel(kind)
    end
    drawTags()
    if open then
        refreshPanel()
    end
end

function BoardController.Init(d: Deps)
    deps = d
    buildPanels(d.World)
    buildTags(d.World)
    for _, kind in BoardMath.KINDS do
        drawPanel(kind)
    end
    drawTags()

    local root, body = Widgets.Window(d.HudGui, {
        name = "Leaderboards",
        title = Strings.STAGES_TITLE,
        icon = "fish",
        width = PANEL_WIDTH,
        height = PANEL_HEIGHT,
        z = Z,
        onClose = BoardController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false
    for i, key in TABS do
        local b = Widgets.Button(body, {
            text = (Strings.STAGES_TABS :: any)[key],
            width = 136,
            height = 40,
            z = Z + 2,
            onClick = function()
                tab = key
                SoundController.Play("click")
                refreshPanel()
            end,
        })
        b.Position = UDim2.fromOffset((i - 1) * 144, 0)
        tabButtons[key] = b
    end
    blurb = Widgets.Label(body, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 48)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.ZIndex = Z + 1
    list = Widgets.List(body, Z + 1, Theme.SPACE.xs)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 72)
    holder.Size = UDim2.new(1, 0, 1, -72)

    d.BoardState.OnClientEvent:Connect(apply)
    Panels.Register("stage", { isOpen = BoardController.IsOpen, close = BoardController.Close })
end

return BoardController
