--!strict
-- [D61] CROITOREASA, la cortul vargat din sud-estul balciului. Langa cort, cardul scrie `Tailor (E)`; panoul are omul
-- tau desenat mare, intors pe rand cu fata, din profil si din spate, si doua file:
--   * Look    -- silueta, coafura, culoarea parului si a pielii. Gratuit, oricand. Sunt straturile si paletele pe care
--                le au deja oamenii din sat (LookMath, SettlerConfig); pana la D61 jucatorul avea un singur chip.
--                Sagetile schimba doar previzualizarea; `Save look` o trimite serverului (o singura cerere, nu una la
--                fiecare sageata).
--   * Outfits -- toate tinutele: atingi randul ca s-o probezi in previzualizare; butonul face ce scrie pe el (Buy cu
--                pretul in perle, Wear, sau nimic cand o porti). Ale croitoresei se vand doar aici.
-- Cumpararea si purtatul trec prin aceiasi validatori ca la avizierul satului (VillageService); ce alegi vad toti cei
-- din balci (lista People) si ramane la fel in sat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Portrait = require(script.Parent.Parent.UI.Portrait)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Village = {
    outfits: { [string]: boolean },
    outfit: string,
    look: LookMath.Look,
}
export type Deps = {
    HudGui: Frame,
    Remotes: { BuyOutfit: RemoteEvent, WearOutfit: RemoteEvent, SetLook: RemoteEvent },
}

local TailorController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local tab = "look"
local village: Village = {
    outfits = { keeper = true },
    outfit = VillageConfig.DEFAULT_OUTFIT,
    look = table.clone(LookMath.DEFAULT),
}
local pearls = 0
local speciesCaught = 0
-- ce se vede in previzualizare: infatisarea la care lucrezi si tinuta probata (nil = cea purtata)
local draft: LookMath.Look = table.clone(LookMath.DEFAULT)
local tryingOn: string? = nil
local facingIndex = 1
local turnClock = 0

-- Cutiile: scripts/art/check_panel_rows.py (TAILOR_PANEL). Corpul ferestrei: 640 x 424.
local PANEL_W, PANEL_H = 680, 520
local Z = 74
local PREVIEW_W, PREVIEW_H = 200, 300
local SIDE_X = PREVIEW_W + 16
local SIDE_W = PANEL_W - Theme.SPACE.lg * 2 - SIDE_X
local CONTENT_Y = 52
local LOOK_ROW_H = 60
local OUTFIT_ROW_H = 64
local BUTTON_W = 130
local TEXT_W = 186 -- numele si randul mic: de la 60 pana la buton (randul are 398, butonul incepe la 256)
local TEXT_WIDE_W = 326 -- randul fara buton (tinuta din jurnal): fraza are tot randul
local TURN_SECONDS = 2
local NEAR = 130

local preview: Frame
local tryLabel: TextLabel
local saveButton: TextButton
local tabButtons: { [string]: TextButton } = {}
local lookGroup: { GuiObject } = {}
local lookValues: { [string]: TextLabel } = {}
local lookSwatches: { [string]: Frame } = {}
local list: ScrollingFrame
local listHolder: Frame

type RowView = {
    frame: TextButton,
    art: Frame,
    name: TextLabel,
    sub: TextLabel,
    state: TextLabel,
    button: TextButton,
}
local views: { RowView } = {}
local actions: { [number]: () -> () } = {}
local tryActions: { [number]: () -> () } = {}

local LOOK_ROWS = { "body", "hair", "hairColor", "skin" }
local refreshAll: () -> () = function() end -- legata mai jos, dupa ce exista refresh()

local function shownOutfit(): string
    return tryingOn or village.outfit
end

local function drawPreview()
    local facing = Portrait.FACINGS[facingIndex] or "down"
    Portrait.draw(preview, shownOutfit(), draft, 128, 192, Z + 3, facing)
    local outfit = VillageConfig.outfitById[shownOutfit()]
    local name = if outfit ~= nil then outfit.name else ""
    local text = if tryingOn ~= nil and tryingOn ~= village.outfit
        then Strings.tailorTrying(name)
        else Strings.tailorWearing(name)
    tryLabel.Text = text
    tryLabel.TextSize = Theme.fitSize(text, Theme.TEXT.small, "strong", PREVIEW_W)
end

local function lookValueText(field: string): string
    local index = (draft :: any)[field] :: number
    if field == "hair" then
        return Strings.tailorHair(SettlerConfig.HAIR_STYLES[index])
    end
    return Strings.tailorChoice(index, LookMath.count(field))
end

local function refreshLook()
    local r = LookMath.resolve(draft)
    for _, field in LOOK_ROWS do
        lookValues[field].Text = lookValueText(field)
    end
    lookSwatches.skin.BackgroundColor3 = Color3.fromRGB(r.skin[1], r.skin[2], r.skin[3])
    lookSwatches.hairColor.BackgroundColor3 =
        Color3.fromRGB(r.hairColor[1], r.hairColor[2], r.hairColor[3])
    local changed = not LookMath.same(draft, village.look)
    Widgets.SetButtonText(saveButton, if changed then Strings.TAILOR_SAVE else Strings.TAILOR_SAVED)
    Widgets.SetButtonTone(saveButton, if changed then Theme.COLOR.gold else nil)
end

local function buildRow(index: number): RowView
    -- randul e un buton (il atingi ca sa probezi tinuta), pe pastila inchisa a celorlalte liste din balci: textul
    -- lor e deschis (onDark), iar pe pergamentul lui Widgets.Row nu s-ar fi citit
    local frame = Instance.new("TextButton")
    frame.Name = `Row{index}`
    frame.AutoButtonColor = false
    frame.Text = ""
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, -10, 0, OUTFIT_ROW_H)
    frame.LayoutOrder = index
    frame.ZIndex = Z + 2
    frame.Parent = list
    Widgets.PillBackground(frame, Z + 2)

    local art = Instance.new("Frame")
    art.Name = "Art"
    art.BackgroundTransparency = 1
    art.Position = UDim2.fromOffset(10, 4)
    art.Size = UDim2.fromOffset(40, 56)
    art.ZIndex = Z + 3
    art.Parent = frame

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(60, 10)
    name.Size = UDim2.fromOffset(TEXT_W, 22)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    local sub = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    sub.Position = UDim2.fromOffset(60, 36)
    sub.Size = UDim2.fromOffset(TEXT_W, 18)
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

    frame.Activated:Connect(function()
        local act = tryActions[index]
        if act ~= nil then
            act()
        end
    end)
    button.Activated:Connect(function()
        local act = actions[index]
        if act ~= nil then
            act()
        end
    end)
    return { frame = frame, art = art, name = name, sub = sub, state = state, button = button }
end

local function refreshOutfits()
    local d = deps
    if d == nil then
        return
    end
    local count = 0
    for i, outfit in VillageConfig.OUTFITS do
        count = i
        local view = views[i]
        if view == nil then
            view = buildRow(i)
            views[i] = view
        end
        view.frame.Visible = true
        Portrait.draw(view.art, outfit.id, draft, 37, 56, Z + 3)
        view.name.Text = outfit.name
        -- tinuta din previzualizare are numele auriu: se vede pe care o probezi
        view.name.TextColor3 = if shownOutfit() == outfit.id
            then Theme.COLOR.gold
            else Theme.COLOR.onDark
        local owned = village.outfits[outfit.id] == true
        local wearing = village.outfit == outfit.id
        view.state.Visible = wearing
        view.state.Text = Strings.BOARD_WEARING
        actions[i] = nil
        -- foaia tinutei inca neurcata: n-ai ce proba si nu se vinde (serverul refuza la fel: "soon")
        local sheet = (Assets.people.outfit :: any)[outfit.id]
        local sewn = sheet ~= nil and Assets.has(sheet)
        tryActions[i] = if sewn
            then function()
                tryingOn = outfit.id
                SoundController.Play("click")
                refreshAll()
            end
            else nil
        view.sub.Size = UDim2.fromOffset(TEXT_W, 18)
        if not sewn and not owned then
            view.sub.Text = Strings.TAILOR_SOON
            view.sub.Size = UDim2.fromOffset(TEXT_WIDE_W, 18)
            view.button.Visible = false
        elseif outfit.journal and not owned then
            view.sub.Text = Strings.boardJournal(speciesCaught, #FishConfig.SPECIES)
            view.sub.Size = UDim2.fromOffset(TEXT_WIDE_W, 18)
            view.button.Visible = false
        elseif owned then
            view.sub.Text = ""
            view.button.Visible = not wearing
            Widgets.SetButtonText(view.button, Strings.BOARD_WEAR)
            Widgets.SetButtonReward(view.button, nil)
            Widgets.SetButtonTone(view.button, Theme.COLOR.cool)
            actions[i] = function()
                SoundController.Play("click")
                tryingOn = nil
                d.Remotes.WearOutfit:FireServer(outfit.id)
            end
        else
            local price = outfit.price or 0
            view.sub.Text = if outfit.tailor then Strings.TAILOR_ONLY_HERE else ""
            view.button.Visible = true
            Widgets.SetButtonText(view.button, Strings.BOARD_BUY)
            Widgets.SetButtonReward(view.button, tostring(price), "pearls")
            Widgets.SetButtonTone(view.button, if pearls >= price then Theme.COLOR.gold else nil)
            actions[i] = function()
                SoundController.Play("click")
                tryingOn = nil
                d.Remotes.BuyOutfit:FireServer(outfit.id)
            end
        end
    end
    for i = count + 1, #views do
        views[i].frame.Visible = false
        actions[i] = nil
        tryActions[i] = nil
    end
    list.CanvasSize = UDim2.fromOffset(0, count * (OUTFIT_ROW_H + Theme.SPACE.sm))
end

local function refresh()
    for name, b in tabButtons do
        Widgets.SetButtonTone(b, if name == tab then Theme.COLOR.gold else nil)
    end
    local looking = tab == "look"
    for _, g in lookGroup do
        g.Visible = looking
    end
    listHolder.Visible = not looking
    if looking then
        refreshLook()
    else
        refreshOutfits()
    end
    drawPreview()
end

refreshAll = refresh

function TailorController.IsOpen(): boolean
    return open
end

function TailorController.Close()
    open = false
    window.Visible = false
    tryingOn = nil
    draft = LookMath.clean(village.look) -- ce n-ai salvat nu ramane: omul din lume arata cum arata
end

function TailorController.Open()
    if deps == nil or not Panels.CanOpen("tailor") then
        return
    end
    Panels.CloseOthers("tailor")
    open = true
    window.Visible = true
    draft = LookMath.clean(village.look)
    tryingOn = nil
    facingIndex = 1
    turnClock = 0
    SoundController.Play("click")
    refresh()
end

function TailorController.Toggle()
    if open then
        TailorController.Close()
    else
        TailorController.Open()
    end
end

-- Din FairState: tinutele tale, ce porti, infatisarea salvata, perlele si cate specii ai prins (River Legend).
function TailorController.Apply(snap: Village, pearlsNow: number, caught: number)
    local lookChanged = not LookMath.same(snap.look, village.look)
    village = snap
    pearls = math.floor(pearlsNow)
    speciesCaught = caught
    if lookChanged then
        draft = LookMath.clean(snap.look) -- serverul a salvat: ciorna devine chiar infatisarea ta
        if open then
            SoundController.Play("chime")
        end
    end
    if open then
        refresh()
    end
end

-- Cardul de langa cort.
function TailorController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local x, y, _, h = FairScene.Spot("tent")
    local distance = Focus.distance(px, py, x, y + 10)
    if distance > NEAR then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = "tailor",
        distance = distance,
        x = x,
        y = y - h - 8,
        action = Strings.tailorCard(keyHint),
        act = TailorController.Open,
    }
end

function TailorController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "Tailor",
        title = Strings.TAILOR_TITLE,
        icon = "people",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = TailorController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    -- stanga: omul tau, mare
    preview = Widgets.Slot(body, Z + 1)
    preview.Name = "Preview"
    preview.Position = UDim2.fromOffset(0, 0)
    preview.Size = UDim2.fromOffset(PREVIEW_W, PREVIEW_H)
    tryLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
    tryLabel.Position = UDim2.fromOffset(0, PREVIEW_H + 8)
    tryLabel.Size = UDim2.fromOffset(PREVIEW_W, 20)
    tryLabel.TextXAlignment = Enum.TextXAlignment.Center
    tryLabel.TextTruncate = Enum.TextTruncate.AtEnd
    tryLabel.ZIndex = Z + 2

    -- filele
    for i, entry in
        { { "look", Strings.TAILOR_TAB_LOOK }, { "outfits", Strings.TAILOR_TAB_OUTFITS } }
    do
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
        b.Position = UDim2.fromOffset(SIDE_X + (i - 1) * 158, 0)
        tabButtons[key] = b
    end

    -- fila Look: patru randuri cu sageti
    for i, field in LOOK_ROWS do
        local y = CONTENT_Y + (i - 1) * (LOOK_ROW_H + 8)
        local row = Widgets.Slot(body, Z + 1)
        row.Name = `Look_{field}`
        row.Position = UDim2.fromOffset(SIDE_X, y)
        row.Size = UDim2.fromOffset(SIDE_W, LOOK_ROW_H)
        table.insert(lookGroup, row)

        local label = Widgets.Label(
            row,
            Strings.tailorField(field),
            Theme.TEXT.small,
            Theme.COLOR.ink,
            "strong"
        )
        label.Position = UDim2.fromOffset(14, 0)
        label.Size = UDim2.fromOffset(140, LOOK_ROW_H)
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.ZIndex = Z + 3

        local function arrow(text: string, x: number, direction: number)
            local b = Widgets.Button(row, {
                text = text,
                width = 44,
                height = 44,
                z = Z + 3,
                onClick = function()
                    draft = LookMath.step(draft, field, direction)
                    SoundController.Play("click")
                    refreshLook()
                    drawPreview()
                end,
            })
            b.Position = UDim2.fromOffset(x, (LOOK_ROW_H - 44) / 2)
        end
        arrow("<", 160, -1)
        arrow(">", SIDE_W - 58, 1)

        local value = Widgets.Label(row, "", Theme.TEXT.small, Theme.COLOR.ink, "display")
        value.Position = UDim2.fromOffset(210, 0)
        value.Size = UDim2.fromOffset(SIDE_W - 58 - 8 - 210 - 40, LOOK_ROW_H)
        value.TextXAlignment = Enum.TextXAlignment.Center
        value.TextYAlignment = Enum.TextYAlignment.Center
        value.ZIndex = Z + 3
        lookValues[field] = value

        -- culoarea aleasa se vede si ca pata, nu doar ca "3 of 6"
        local swatch = Instance.new("Frame")
        swatch.Name = "Swatch"
        swatch.AnchorPoint = Vector2.new(1, 0.5)
        swatch.Position = UDim2.new(0, SIDE_W - 58 - 12, 0.5, 0)
        swatch.Size = UDim2.fromOffset(28, 28)
        swatch.BorderSizePixel = 0
        swatch.Visible = field == "skin" or field == "hairColor"
        swatch.ZIndex = Z + 3
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.COLOR.woodDark
        stroke.Thickness = 2
        stroke.Parent = swatch
        swatch.Parent = row
        lookSwatches[field] = swatch
    end
    saveButton = Widgets.Button(body, {
        text = Strings.TAILOR_SAVE,
        icon = "check",
        width = PREVIEW_W,
        height = 44,
        z = Z + 2,
        onClick = function()
            if LookMath.same(draft, village.look) then
                return
            end
            SoundController.Play("click")
            d.Remotes.SetLook:FireServer(draft)
        end,
    })
    saveButton.Position = UDim2.fromOffset(0, PREVIEW_H + 36)
    table.insert(lookGroup, saveButton)

    -- fila Outfits
    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    listHolder = list.Parent :: Frame
    listHolder.Position = UDim2.fromOffset(SIDE_X, CONTENT_Y)
    listHolder.Size = UDim2.new(0, SIDE_W, 1, -CONTENT_Y)
    listHolder.Visible = false

    -- omul din previzualizare se intoarce: fata, profil, spate, profil
    RunService.PreRender:Connect(function(dt: number)
        if not open then
            return
        end
        turnClock += dt
        if turnClock >= TURN_SECONDS then
            turnClock = 0
            facingIndex = facingIndex % #Portrait.FACINGS + 1
            drawPreview()
        end
    end)

    Panels.Register("tailor", { isOpen = TailorController.IsOpen, close = TailorController.Close })
end

return TailorController
