--!strict
-- [D60] PANOUL TITLURILOR, in balci (tasta T). Sus, titlul pe care il porti. Dedesubt, trei parti:
--   * Earned -- ce ai castigat, fiecare cu locul din care vine si butonul Wear (gratuit);
--   * Still to earn -- ce se castiga inca: jurnalul complet (cu cati pesti mai ai) si titlurile decorului din sat;
--   * For pearls -- cele trei titluri de vanzare, cu pretul pe buton (600/1000/1600).
-- Serverul hotaraste tot (TitleService); aici doar se arata si se cere.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TitleMath = require(ReplicatedStorage.Shared.Modules.TitleMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Entry = { id: string, label: string }
export type SaleEntry = { id: string, label: string, price: number, owned: boolean }
export type Snapshot = {
    worn: string,
    label: string,
    earned: { Entry },
    forSale: { SaleEntry },
    species: number,
    speciesTotal: number,
    decor: { [string]: boolean },
    pondWins: number, -- [D61]
    streakBest: number, -- [D71] cea mai lunga serie (alege titlul) si cea de acum (progresul)
    streakRun: number,
    perfectGames: number,
}

export type Deps = {
    HudGui: Frame,
    Remotes: { BuyTitle: RemoteEvent, WearTitle: RemoteEvent },
}

local TitleController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local list: ScrollingFrame
local wornLabel: TextLabel
local snapshot: Snapshot? = nil
local pearls = 0

-- Cutiile randului: scripts/art/check_panel_rows.py (TITLE_ROW).
local PANEL_W, PANEL_H = 600, 560
local ROW_H = 56
local HEAD_H = 28
local BUTTON_W = 150
local Z = 66

type RowView = {
    frame: Frame,
    skin: GuiObject?, -- fundalul pastilei (Widgets.PillBackground), ascuns pe randurile de titlu
    icon: ImageLabel,
    name: TextLabel,
    sub: TextLabel,
    state: TextLabel,
    button: TextButton,
    head: TextLabel,
}
local views: { RowView } = {}
local actions: { [number]: () -> () } = {}

local function iconFor(id: string): string
    if id == "era" then
        return "people"
    elseif id == "legend" then
        return "note"
    elseif id == "record" or id == "champion" or id == "pond" then
        return "fish"
    elseif id == "sharpshooter" then
        return "check"
    elseif id == "regular" or id == "old_friend" then
        return "clock" -- [D71] castigat din seria zilnica, nu cumparat (perla ar spune "cumparat")
    elseif string.sub(id, 1, 6) == "decor_" then
        return "build"
    end
    return "pearl"
end

local function fromFor(id: string): string
    local from = Strings.TITLE_FROM :: any
    if string.sub(id, 1, 6) == "decor_" then
        return from.decor
    elseif TitleMath.priceOf(id) ~= nil then
        return from.sale
    end
    return from[id] or ""
end

local function buildRow(index: number): RowView
    local frame = Instance.new("Frame")
    frame.Name = `Row{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = list
    Widgets.PillBackground(frame, Z + 2)
    local skin = frame:FindFirstChild("Skin")

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.ResampleMode = Enum.ResamplerMode.Pixelated
    icon.Position = UDim2.fromOffset(Theme.SPACE.md, 14)
    icon.Size = UDim2.fromOffset(28, 28)
    icon.ZIndex = Z + 3
    icon.Parent = frame

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(56, 8)
    name.Size = UDim2.fromOffset(280, 22)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    local sub = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    sub.Position = UDim2.fromOffset(56, 32)
    sub.Size = UDim2.fromOffset(280, 18)
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.ZIndex = Z + 3

    local state = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.good, "display")
    state.AnchorPoint = Vector2.new(1, 0.5)
    state.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    state.Size = UDim2.fromOffset(BUTTON_W, 24)
    state.TextXAlignment = Enum.TextXAlignment.Center
    state.ZIndex = Z + 3

    local button = Widgets.Button(frame, {
        text = "",
        width = BUTTON_W,
        height = 44,
        z = Z + 3,
        reward = true,
        onClick = function() end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)

    -- randul poate fi si titlul unei parti ("Earned"): atunci doar textul asta se vede
    local head = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.ink, "display")
    head.Position = UDim2.fromOffset(Theme.SPACE.xs, 4)
    head.Size = UDim2.new(1, -Theme.SPACE.xs * 2, 0, 20)
    head.ZIndex = Z + 3

    return {
        frame = frame,
        skin = if skin ~= nil and skin:IsA("GuiObject") then skin else nil,
        icon = icon,
        name = name,
        sub = sub,
        state = state,
        button = button,
        head = head,
    }
end

local function rowAt(index: number): RowView
    local view = views[index]
    if view == nil then
        view = buildRow(index)
        views[index] = view
        view.button.Activated:Connect(function()
            local act = actions[index]
            if act ~= nil then
                act()
            end
        end)
    end
    return view
end

local function setIcon(view: RowView, key: string)
    local sprite = (Assets.icons :: any)[key]
    view.icon.Image = if sprite ~= nil and Assets.has(sprite) then Assets.url(sprite) else ""
end

-- Randul devine titlul unei parti: fara fundal, doar textul. Fara pastila de arta, fundalul e culoarea randului.
local function setPlate(view: RowView, visible: boolean)
    local skin = view.skin
    if skin ~= nil then
        skin.Visible = visible
    else
        view.frame.BackgroundTransparency = if visible then Theme.PLATE_TRANSPARENCY else 1
    end
end

local function asHeader(view: RowView, text: string)
    view.frame.Size = UDim2.new(1, 0, 0, HEAD_H)
    setPlate(view, false)
    view.head.Visible = true
    view.head.Text = text
    for _, obj in { view.icon, view.name, view.sub, view.state, view.button } :: { GuiObject } do
        obj.Visible = false
    end
end

local function asRow(view: RowView)
    view.frame.Size = UDim2.new(1, 0, 0, ROW_H)
    setPlate(view, true)
    view.head.Visible = false
    view.icon.Visible = true
    view.name.Visible = true
    view.sub.Visible = true
    -- randurile se refolosesc: sub-eticheta revine la latimea de langa buton (cele "Still to earn" o lungesc)
    view.sub.Size = UDim2.fromOffset(280, 18)
end

local function refresh()
    local d = deps
    local snap = snapshot
    if d == nil or snap == nil then
        return
    end
    wornLabel.Text = Strings.titlesWorn(snap.label)
    local index, height = 0, 0
    local function nextRow(): (RowView, number)
        index += 1
        local view = rowAt(index)
        view.frame.Visible = true
        actions[index] = nil
        return view, index
    end

    local header, _ = nextRow()
    asHeader(header, Strings.TITLES_EARNED)
    height += HEAD_H
    for _, entry in snap.earned do
        if TitleMath.priceOf(entry.id) ~= nil then
            continue -- cele cumparate stau la "For pearls", cu butonul lor
        end
        local view, i = nextRow()
        asRow(view)
        height += ROW_H
        setIcon(view, iconFor(entry.id))
        view.name.Text = entry.label
        view.sub.Text = fromFor(entry.id)
        local wearing = snap.worn == entry.id
        view.state.Visible = wearing
        view.state.Text = Strings.BOARD_WEARING
        view.button.Visible = not wearing
        if not wearing then
            Widgets.SetButtonText(view.button, Strings.BOARD_WEAR)
            Widgets.SetButtonReward(view.button, nil)
            Widgets.SetButtonTone(view.button, Theme.COLOR.cool)
            local id = entry.id
            actions[i] = function()
                SoundController.Play("click")
                d.Remotes.WearTitle:FireServer(id)
            end
        end
    end

    -- ce se mai castiga: jurnalul si decorul din sat (gratuite, dar nu inca ale tale)
    local toEarn: { { icon: string, name: string, sub: string } } = {}
    if snap.species < snap.speciesTotal then
        table.insert(toEarn, {
            icon = "note",
            name = "River Legend",
            sub = Strings.titleLegendProgress(snap.species, snap.speciesTotal),
        })
    end
    -- [D61] iazul si gheretele: se castiga in balci, cu progresul lor
    if snap.pondWins < TitleMath.POND_WINS then
        table.insert(toEarn, {
            icon = "fish",
            name = "Pond Champion",
            sub = Strings.titlePondProgress(snap.pondWins, TitleMath.POND_WINS),
        })
    end
    -- [D71] seria zilnica: doar urmatorul titlu al ei (ales din cea mai lunga serie), cu progresul seriei de acum, ca
    -- cifra sa urce in fiecare zi in care vii [verificator: din cea mai lunga statea pe loc dupa o serie reinceputa]
    local streakGoal, streakName = TitleMath.STREAK_REGULAR, "Regular"
    if snap.streakBest >= TitleMath.STREAK_REGULAR then
        streakGoal, streakName = TitleMath.STREAK_OLD_FRIEND, "Old Friend"
    end
    if snap.streakBest < streakGoal then
        table.insert(toEarn, {
            icon = "clock",
            name = streakName,
            sub = Strings.titleStreakProgress(snap.streakRun, streakGoal),
        })
    end
    if snap.perfectGames < TitleMath.PERFECT_GAMES then
        table.insert(toEarn, {
            icon = "check",
            name = "Sharpshooter",
            sub = Strings.titleSharpshooterProgress(snap.perfectGames, TitleMath.PERFECT_GAMES),
        })
    end
    local decorIds = {}
    for decorId in TitleMath.FROM_DECOR do
        table.insert(decorIds, decorId)
    end
    table.sort(decorIds)
    for _, decorId in decorIds do
        local def = VillageConfig.decorById[decorId]
        if def ~= nil and not snap.decor[decorId] then
            table.insert(toEarn, {
                icon = "build",
                name = (TitleMath.FROM_DECOR :: any)[decorId],
                sub = Strings.titleDecorHint(def.name),
            })
        end
    end
    if #toEarn > 0 then
        local head, _ = nextRow()
        asHeader(head, Strings.TITLES_TO_EARN)
        height += HEAD_H
        for _, e in toEarn do
            local view, _ = nextRow()
            asRow(view)
            height += ROW_H
            setIcon(view, e.icon)
            view.name.Text = e.name
            view.sub.Text = e.sub
            -- fara buton si fara stare: sub-eticheta ia tot randul (check_panel_rows.py, TITLE_TO_EARN)
            view.sub.Size = UDim2.new(1, -56 - Theme.SPACE.md, 0, 18)
            view.state.Visible = false
            view.button.Visible = false
        end
    end

    local saleHead, _ = nextRow()
    asHeader(saleHead, Strings.TITLES_FOR_SALE)
    height += HEAD_H
    for _, entry in snap.forSale do
        local view, i = nextRow()
        asRow(view)
        height += ROW_H
        setIcon(view, "pearl")
        view.name.Text = entry.label
        view.sub.Text = Strings.TITLE_FROM.sale
        local wearing = snap.worn == entry.id
        view.state.Visible = wearing
        view.state.Text = Strings.BOARD_WEARING
        view.button.Visible = not wearing
        local id = entry.id
        if entry.owned then
            Widgets.SetButtonText(view.button, Strings.BOARD_WEAR)
            Widgets.SetButtonReward(view.button, nil)
            Widgets.SetButtonTone(view.button, Theme.COLOR.cool)
            actions[i] = function()
                SoundController.Play("click")
                d.Remotes.WearTitle:FireServer(id)
            end
        else
            Widgets.SetButtonText(view.button, Strings.BOARD_BUY)
            Widgets.SetButtonReward(view.button, tostring(entry.price), "pearls")
            Widgets.SetButtonTone(
                view.button,
                if pearls >= entry.price then Theme.COLOR.gold else nil
            )
            actions[i] = function()
                SoundController.Play("click")
                d.Remotes.BuyTitle:FireServer(id)
            end
        end
    end

    for i = index + 1, #views do
        views[i].frame.Visible = false
        actions[i] = nil
    end
    list.CanvasSize = UDim2.fromOffset(0, height + index * Theme.SPACE.sm)
end

-- Eticheta unui titlu, pentru mesajul de dupa alegere ("Wearing Of the Mill"); id-ul, daca nu-l stim.
function TitleController.LabelOf(id: string): string
    local snap = snapshot
    if snap ~= nil then
        for _, e in snap.earned do
            if e.id == id then
                return e.label
            end
        end
        for _, e in snap.forSale do
            if e.id == id then
                return e.label
            end
        end
    end
    return id
end

-- Din FairState: titlurile tale si cate perle ai (butoanele de cumparat se aprind cand ajung).
function TitleController.Apply(snap: Snapshot, pearlsNow: number)
    snapshot = snap
    pearls = math.floor(pearlsNow)
    if open then
        refresh()
    end
end

function TitleController.IsOpen(): boolean
    return open
end

function TitleController.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function TitleController.Open()
    Panels.CloseOthers("titles")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refresh()
end

function TitleController.Toggle()
    if open then
        TitleController.Close()
    else
        TitleController.Open()
    end
end

function TitleController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "Titles",
        title = Strings.TITLES_TITLE,
        icon = "people",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = TitleController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    wornLabel = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.ink, "display")
    wornLabel.Position = UDim2.fromOffset(0, 0)
    wornLabel.Size = UDim2.new(1, 0, 0, 26)
    wornLabel.TextTruncate = Enum.TextTruncate.AtEnd
    wornLabel.ZIndex = Z + 1

    local blurb =
        Widgets.Label(body, Strings.TITLES_BLURB, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 30)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.ZIndex = Z + 1

    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 56)
    holder.Size = UDim2.new(1, 0, 1, -56)

    Panels.Register("titles", { isOpen = TitleController.IsOpen, close = TitleController.Close })
end

return TitleController
