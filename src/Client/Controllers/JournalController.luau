--!strict
-- [D59] JURNALUL: ce ai scos la undita si din rau. Doua pagini:
--   * Fish -- cele 12 specii, siluete pana la prima prindere, apoi numele, raritatea, de cate ori si cea mai mare
--     marime; jurnalul complet da tinuta River Legend (se spune sus, ca sa fie o tinta, nu o surpriza);
--   * River -- ce poate aduce raul si cat valoreaza, cate ai scos, si biletele din sticle, in ordinea gasirii.
-- Doar citeste starea (FishService / TreasureService prin TycoonState); nimic nu se cumpara de aici.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type FishSnap = {
    bait: number,
    fished: number,
    species: { [string]: { count: number, best: number } },
}
export type RiverSnap = { waiting: { string }, started: boolean, notes: number, found: number }

export type Deps = { HudGui: Frame }

local JournalController = {}
local window: Frame
local open = false
local tab = "fish"
local header: TextLabel
local headerFill: Frame
local headerNote: TextLabel
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}

local fishing: FishSnap = { bait = 0, fished = 0, species = {} }
local river: RiverSnap = { waiting = {}, started = false, notes = 0, found = 0 }

-- [D59] Cutiile randului: scripts/art/check_panel_rows.py (JOURNAL_ROW).
local PANEL_W, PANEL_H = 600, 560
local ROW_H = 56
local Z = 67

type RowView = { frame: Frame, icon: ImageLabel, name: TextLabel, sub: TextLabel, right: TextLabel }
local views: { RowView } = {}

local tierColor: { [string]: Color3 } = {}
for _, t in RiverConfig.TIERS do
    tierColor[t.id] = Color3.fromRGB(t.rgb[1], t.rgb[2], t.rgb[3])
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

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.BackgroundTransparency = 1
    icon.ResampleMode = Enum.ResamplerMode.Pixelated
    icon.AnchorPoint = Vector2.new(0.5, 0.5)
    icon.Position = UDim2.fromOffset(Theme.SPACE.md + 25, ROW_H / 2)
    icon.Size = UDim2.fromOffset(50, 40)
    icon.ZIndex = Z + 3
    icon.Parent = frame

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(74, 8)
    name.Size = UDim2.fromOffset(200, 22)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    local sub = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    sub.Position = UDim2.fromOffset(74, 32)
    sub.Size = UDim2.fromOffset(200, 18)
    sub.TextTruncate = Enum.TextTruncate.AtEnd
    sub.ZIndex = Z + 3

    local right = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDark, "body")
    right.AnchorPoint = Vector2.new(1, 0.5)
    right.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    right.Size = UDim2.fromOffset(220, 40)
    right.TextXAlignment = Enum.TextXAlignment.Right
    right.TextWrapped = true
    right.ZIndex = Z + 3

    return { frame = frame, icon = icon, name = name, sub = sub, right = right }
end

local function rowAt(index: number): RowView
    local view = views[index]
    if view == nil then
        view = buildRow(index)
        views[index] = view
    end
    return view
end

-- Un rand obisnuit: nume si raritate in stanga, cifrele in dreapta. Un bilet: textul lui pe tot randul.
local function layoutRow(view: RowView, note: boolean)
    view.name.Visible = not note
    view.sub.Visible = not note
    if note then
        view.right.AnchorPoint = Vector2.new(0, 0.5)
        view.right.Position = UDim2.new(0, 74, 0.5, 0)
        view.right.Size = UDim2.new(1, -86, 0, 48)
        view.right.TextXAlignment = Enum.TextXAlignment.Left
    else
        view.right.AnchorPoint = Vector2.new(1, 0.5)
        view.right.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
        view.right.Size = UDim2.fromOffset(220, 40)
        view.right.TextXAlignment = Enum.TextXAlignment.Right
    end
end

local function setIcon(view: RowView, sprite: Assets.Sprite?, silhouette: boolean)
    if sprite ~= nil and Assets.has(sprite) then
        view.icon.Image = Assets.url(sprite)
        local s = math.min(50 / sprite.width, 40 / sprite.height)
        view.icon.Size = UDim2.fromOffset(sprite.width * s, sprite.height * s)
        -- nepescuit inca: silueta (acelasi desen, intunecat), ca sa se vada ca exista, nu ce e
        view.icon.ImageColor3 = if silhouette
            then Color3.fromRGB(28, 24, 20)
            else Color3.new(1, 1, 1)
        view.icon.ImageTransparency = if silhouette then 0.2 else 0
        view.icon.Visible = true
    else
        view.icon.Visible = false
    end
end

local function speciesCaught(): number
    local n = 0
    for _, s in FishConfig.SPECIES do
        if fishing.species[s.id] ~= nil then
            n += 1
        end
    end
    return n
end

local function refresh()
    for name, b in tabButtons do
        Widgets.SetButtonTone(b, if name == tab then Theme.COLOR.gold else nil)
    end
    local count = 0
    if tab == "fish" then
        local caught = speciesCaught()
        header.Text = Strings.journalFishCount(caught, #FishConfig.SPECIES)
        headerFill.Size = UDim2.fromScale(caught / #FishConfig.SPECIES, 1)
        headerNote.Text = Strings.JOURNAL_REWARD
        for i, s in FishConfig.SPECIES do
            count = i
            local view = rowAt(i)
            view.frame.Visible = true
            layoutRow(view, false)
            local entry = fishing.species[s.id]
            setIcon(view, (Assets.fish :: any)[s.id], entry == nil)
            view.name.Text = if entry ~= nil then s.name else Strings.JOURNAL_UNKNOWN
            view.sub.Text = Strings.TIER_NAMES[s.tier] or s.tier
            view.sub.TextColor3 = tierColor[s.tier] or Theme.COLOR.onDarkSoft
            view.right.Text = if entry ~= nil
                then Strings.journalCaught(entry.count, entry.best)
                else Strings.JOURNAL_NOT_CAUGHT
            view.right.TextColor3 = if entry ~= nil
                then Theme.COLOR.onDark
                else Theme.COLOR.onDarkSoft
        end
    else
        local notesFound = math.min(river.notes, #TreasureConfig.NOTES)
        header.Text = Strings.journalFound(river.found)
        headerFill.Size = UDim2.fromScale(notesFound / #TreasureConfig.NOTES, 1)
        headerNote.Text = Strings.journalNotes(river.notes, #TreasureConfig.NOTES)
        for _, kind in TreasureConfig.KINDS do
            count += 1
            local view = rowAt(count)
            view.frame.Visible = true
            layoutRow(view, false)
            setIcon(view, (Assets.treasure :: any)[kind.id], false)
            view.name.Text = kind.name
            view.sub.Text = ""
            view.right.Text = Strings.journalTreasure(kind.pearls)
            view.right.TextColor3 = Theme.COLOR.cool
        end
        if notesFound == 0 then
            count += 1
            local view = rowAt(count)
            view.frame.Visible = true
            layoutRow(view, true)
            setIcon(view, Assets.icons.note, true)
            view.name.Text = Strings.NOTE_TITLE
            view.sub.Text = ""
            view.right.Text = Strings.JOURNAL_NO_NOTES
            view.right.TextColor3 = Theme.COLOR.onDarkSoft
        end
        for n = 1, notesFound do
            count += 1
            local view = rowAt(count)
            view.frame.Visible = true
            layoutRow(view, true)
            setIcon(view, Assets.icons.note, false)
            view.name.Text = `{Strings.NOTE_TITLE} {n}`
            view.sub.Text = ""
            view.right.Text = TreasureConfig.NOTES[n]
            view.right.TextColor3 = Theme.COLOR.onDark
        end
    end
    for i = count + 1, #views do
        views[i].frame.Visible = false
    end
    list.CanvasSize = UDim2.fromOffset(0, count * (ROW_H + Theme.SPACE.sm))
end

function JournalController.Apply(fish: FishSnap, riverSnap: RiverSnap)
    fishing = fish
    river = riverSnap
    if open then
        refresh()
    end
end

-- cate specii ai prins (avizierul arata progresul spre River Legend)
function JournalController.SpeciesCaught(fish: FishSnap): number
    local n = 0
    for _, s in FishConfig.SPECIES do
        if fish.species[s.id] ~= nil then
            n += 1
        end
    end
    return n
end

function JournalController.IsOpen(): boolean
    return open
end

function JournalController.Close()
    open = false
    window.Visible = false
end

function JournalController.Open()
    Panels.CloseOthers("journal")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refresh()
end

function JournalController.Toggle()
    if open then
        JournalController.Close()
    else
        JournalController.Open()
    end
end

function JournalController.Init(d: Deps)
    local root, body = Widgets.Window(d.HudGui, {
        name = "JournalPanel",
        title = Strings.JOURNAL_TITLE,
        icon = "fish",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = JournalController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    for i, entry in { { "fish", Strings.JOURNAL_TAB_FISH }, { "river", Strings.JOURNAL_TAB_RIVER } } do
        local key, label = entry[1], entry[2]
        local b = Widgets.Button(body, {
            text = label,
            width = 150,
            height = 40,
            z = Z + 2,
            onClick = function()
                tab = key
                SoundController.Play("click")
                refresh()
            end,
        })
        b.Position = UDim2.fromOffset((i - 1) * 158, 0)
        tabButtons[key] = b
    end

    header = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "display")
    header.Position = UDim2.fromOffset(0, 50)
    header.Size = UDim2.fromOffset(300, 20)
    header.ZIndex = Z + 1

    local track, fill = Widgets.Bar(body, 220, 8, Theme.COLOR.gold, Z + 1)
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, 0, 0, 56)
    headerFill = fill

    headerNote = Widgets.Label(body, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    headerNote.Position = UDim2.fromOffset(0, 74)
    headerNote.Size = UDim2.new(1, 0, 0, 18)
    headerNote.ZIndex = Z + 1

    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 98)
    holder.Size = UDim2.new(1, 0, 1, -98)

    Panels.Register(
        "journal",
        { isOpen = JournalController.IsOpen, close = JournalController.Close }
    )
end

return JournalController
