--!strict
-- [D59] AVIZIERUL SATULUI: perlele cumpara aspect. Recomandarea acceptata de owner (2026-09-15): "perlele cumpara decor
-- pentru sat si tinute". Pe punte, langa roata, un avizier cu doua pagini:
--   * Village -- zece imbunatatiri, fiecare cu locul ei fix pe harta (VillageConfig.DECOR); cumparata, apare pe loc, cu
--     praf, sunetul de constructie si numele ei deasupra;
--   * Outfits -- tinutele jucatorului: cumperi o data, apoi schimbi gratuit; River Legend vine din jurnalul complet.
-- Nimic de aici nu schimba venitul si nimic nu e aleatoriu. Serverul scade perlele (VillageService); aici se vede.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local FishConfig = require(ReplicatedStorage.Shared.Config.FishConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local CharacterController = require(script.Parent.CharacterController)
local Panels = require(script.Parent.Panels)
local SceneArt = require(script.Parent.SceneArt)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Snapshot = {
    decor: { [string]: boolean },
    outfits: { [string]: boolean },
    outfit: string,
}

export type Deps = {
    HudGui: Frame,
    Plot: Frame,
    Remotes: {
        BuyDecor: RemoteEvent,
        BuyOutfit: RemoteEvent,
        WearOutfit: RemoteEvent,
        ShopResult: RemoteEvent,
    },
    OnToast: (string, Color3?) -> (),
}

local VillageController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local tab = "village"
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}

local village: Snapshot =
    { decor = {}, outfits = { keeper = true }, outfit = VillageConfig.DEFAULT_OUTFIT }
local pearls = 0
local caught = 0 -- specii prinse, pentru randul River Legend
local applied = false

-- [D59] Cutiile randului: scripts/art/check_panel_rows.py (BOARD_ROW).
local PANEL_W, PANEL_H = 600, 560
local ROW_H = 64
local BUTTON_W = 150
local Z = 66
local BOARD_SCALE = 2

type RowView = {
    frame: Frame,
    art: Frame,
    name: TextLabel,
    sub: TextLabel,
    state: TextLabel,
    button: TextButton,
}
local views: { RowView } = {}
local decorShown: { [string]: boolean } = {}

-- ---- decorul din lume -----------------------------------------------------------------------------
local function zFor(decor: VillageConfig.Decor): number
    if decor.ground == "water" then
        return 2 -- sub pontonul (3)
    elseif decor.ground == "pier" then
        return 4 -- pe ponton
    end
    return 3 -- nivelul solului, ca cladirile platformelor
end

local function showDecor(decor: VillageConfig.Decor, animate: boolean)
    local d = deps :: Deps
    local sprite = (Assets.decor :: any)[decor.sprite]
    if sprite == nil or not Assets.has(sprite) then
        return -- desenul inca neurcat: cand ajunge, starea urmatoare il deseneaza
    end
    decorShown[decor.id] = true
    for i, spot in decor.spots do
        local w, h = sprite.width * decor.scale, sprite.height * decor.scale
        if decor.ground == "land" then
            GroundShadow.add(
                d.Plot,
                UDim2.fromOffset(spot.x, spot.y),
                w * 0.8,
                zFor(decor) - 1,
                0.3
            )
        end
        local img = Instance.new("ImageLabel")
        img.Name = `Decor_{decor.id}_{i}`
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(spot.x, spot.y)
        img.Size = UDim2.fromOffset(w, h)
        img.ZIndex = zFor(decor)
        img.Parent = d.Plot
        if animate then
            -- apare cu un salt si praf, iar numele se ridica de pe primul loc: se vede ce ai cumparat si unde [D43]
            local scale = Instance.new("UIScale")
            scale.Scale = 0.3
            scale.Parent = img
            TweenService
                :Create(
                    scale,
                    TweenInfo.new(0.4 + 0.08 * i, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
                    { Scale = 1 }
                )
                :Play()
            task.delay(0.6 + 0.08 * i, function()
                scale:Destroy()
            end)
            SceneArt.Splash(img, 0.5, 0.9)
            if i == 1 then
                Widgets.FloatText(img, decor.name, Theme.COLOR.gold, 40)
            end
        end
    end
    if animate then
        SoundController.PlayBuild(decor.price)
    end
end

-- ---- avizierul din lume -----------------------------------------------------------------------------
local function buildWorldBoard(d: Deps)
    local stand = TycoonConfig.VILLAGE_BOARD
    local sprite = Assets.tycoon.village_board
    local w, h = sprite.width * BOARD_SCALE, sprite.height * BOARD_SCALE
    GroundShadow.add(d.Plot, UDim2.fromOffset(stand.x, stand.y), w * 0.7, 3, 0.35)
    local img = Instance.new("ImageLabel")
    img.Name = "VillageBoard"
    img.BackgroundTransparency = 1
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Position = UDim2.fromOffset(stand.x, stand.y)
    img.Size = UDim2.fromOffset(w, h)
    img.ZIndex = 4
    if Assets.has(sprite) then
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        img.BackgroundTransparency = 0
        img.BackgroundColor3 = Theme.COLOR.wood
    end
    img.Parent = d.Plot
    local name =
        Widgets.Label(img, Strings.BOARD_TITLE, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    name.AnchorPoint = Vector2.new(0.5, 0)
    name.Position = UDim2.new(0.5, 0, 1, 2)
    name.Size = UDim2.fromOffset(w + 60, 18)
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.ZIndex = 5
    Theme.punch(name, 2)
end

function VillageController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local stand = TycoonConfig.VILLAGE_BOARD
    local distance = Focus.distance(px, py, stand.x, stand.y - 20)
    if distance > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = "board",
        distance = distance,
        x = stand.x,
        y = stand.y - Assets.tycoon.village_board.height * BOARD_SCALE - 8,
        action = Strings.boardCard(keyHint),
        act = function()
            VillageController.Open()
        end,
    }
end

-- ---- panoul ---------------------------------------------------------------------------------------
-- Desenul decorului, micsorat intr-o casuta; pentru o tinuta, personajul in ea (corp, par, tinuta), din fata.
local function fillArt(holder: Frame, sprite: Assets.Sprite?, outfit: string?)
    for _, child in holder:GetChildren() do
        if child:IsA("ImageLabel") then
            child:Destroy()
        end
    end
    local function layer(sheet: Assets.Sprite, tint: Color3?, z: number)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sheet)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.ImageRectOffset = Vector2.new(0, 24 * 3) -- randul idle_down, cadrul 0
        img.ImageRectSize = Vector2.new(16, 24)
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromScale(0.5, 1)
        img.Size = UDim2.fromOffset(32, 48)
        img.ImageColor3 = tint or Color3.new(1, 1, 1)
        img.ZIndex = z
        img.Parent = holder
    end
    if outfit ~= nil then
        local sheet = (Assets.people.outfit :: any)[outfit]
        if sheet ~= nil and Assets.has(sheet) and Assets.has(Assets.people.body.b) then
            layer(Assets.people.body.b, Color3.fromRGB(231, 188, 150), Z + 4)
            if Assets.has(Assets.people.hair.long) then
                layer(Assets.people.hair.long, Color3.fromRGB(92, 62, 40), Z + 5)
            end
            layer(sheet, nil, Z + 6)
        end
        return
    end
    if sprite ~= nil and Assets.has(sprite) then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        local s = math.min(52 / sprite.width, 44 / sprite.height)
        img.Size = UDim2.fromOffset(sprite.width * s, sprite.height * s)
        img.ZIndex = Z + 4
        img.Parent = holder
    end
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

    local art = Instance.new("Frame")
    art.Name = "Art"
    art.BackgroundTransparency = 1
    art.Position = UDim2.fromOffset(Theme.SPACE.md, 6)
    art.Size = UDim2.fromOffset(56, 52)
    art.ZIndex = Z + 3
    art.Parent = frame

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(80, 10)
    name.Size = UDim2.fromOffset(250, 22)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    local sub = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    sub.Position = UDim2.fromOffset(80, 36)
    sub.Size = UDim2.fromOffset(250, 18)
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

    return { frame = frame, art = art, name = name, sub = sub, state = state, button = button }
end

-- Butonul fiecarui rand face ce scrie pe el acum; legatura se schimba la fiecare desenare.
local actions: { [number]: () -> () } = {}

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

local function refresh()
    local d = deps
    if d == nil then
        return
    end
    for name, b in tabButtons do
        Widgets.SetButtonTone(b, if name == tab then Theme.COLOR.gold else nil)
    end
    local count = 0
    if tab == "village" then
        for i, decor in VillageConfig.DECOR do
            count = i
            local view = rowAt(i)
            view.frame.Visible = true
            fillArt(view.art, (Assets.decor :: any)[decor.sprite], nil)
            view.name.Text = decor.name
            view.sub.Text = decor.where
            local owned = village.decor[decor.id] == true
            view.state.Visible = owned
            view.state.Text = Strings.BOARD_BUILT
            view.button.Visible = not owned
            if not owned then
                Widgets.SetButtonText(view.button, Strings.BOARD_BUILD)
                Widgets.SetButtonReward(view.button, tostring(decor.price), "pearls")
                Widgets.SetButtonTone(
                    view.button,
                    if pearls >= decor.price then Theme.COLOR.gold else nil
                )
                actions[i] = function()
                    SoundController.Play("click")
                    d.Remotes.BuyDecor:FireServer(decor.id)
                end
            end
        end
    else
        for i, outfit in VillageConfig.OUTFITS do
            count = i
            local view = rowAt(i)
            view.frame.Visible = true
            fillArt(view.art, nil, outfit.id)
            view.name.Text = outfit.name
            local owned = village.outfits[outfit.id] == true
            local wearing = village.outfit == outfit.id
            view.state.Visible = wearing
            view.state.Text = Strings.BOARD_WEARING
            if outfit.journal and not owned then
                view.sub.Text = Strings.boardJournal(caught, #FishConfig.SPECIES)
                view.button.Visible = false
            elseif owned then
                view.sub.Text = ""
                view.button.Visible = not wearing
                Widgets.SetButtonText(view.button, Strings.BOARD_WEAR)
                Widgets.SetButtonReward(view.button, nil)
                Widgets.SetButtonTone(view.button, Theme.COLOR.cool)
                actions[i] = function()
                    SoundController.Play("click")
                    d.Remotes.WearOutfit:FireServer(outfit.id)
                end
            else
                local price = outfit.price or 0
                view.sub.Text = ""
                view.button.Visible = true
                Widgets.SetButtonText(view.button, Strings.BOARD_BUY)
                Widgets.SetButtonReward(view.button, tostring(price), "pearls")
                Widgets.SetButtonTone(
                    view.button,
                    if pearls >= price then Theme.COLOR.gold else nil
                )
                actions[i] = function()
                    SoundController.Play("click")
                    d.Remotes.BuyOutfit:FireServer(outfit.id)
                end
            end
        end
    end
    for i = count + 1, #views do
        views[i].frame.Visible = false
        actions[i] = nil
    end
    list.CanvasSize = UDim2.fromOffset(0, count * (ROW_H + Theme.SPACE.sm))
end

-- Din TycoonState: ce ai cumparat, ce porti, cate perle ai si cate specii ai prins (pentru River Legend).
function VillageController.Apply(snap: Snapshot, pearlsNow: number, speciesCaught: number)
    village = snap
    pearls = math.floor(pearlsNow)
    caught = speciesCaught
    if deps ~= nil then
        for _, decor in VillageConfig.DECOR do
            if village.decor[decor.id] and not decorShown[decor.id] then
                -- la prima stare doar se aseaza ce ai deja; dupa, fiecare lucru nou apare cu ceremonia lui
                showDecor(decor, applied)
            end
        end
        applied = true
    end
    CharacterController.SetOutfit(village.outfit)
    if open then
        refresh()
    end
end

function VillageController.IsOpen(): boolean
    return open
end

function VillageController.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function VillageController.Open()
    Panels.CloseOthers("board")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refresh()
end

function VillageController.Toggle()
    if open then
        VillageController.Close()
    else
        VillageController.Open()
    end
end

function VillageController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "VillageBoard",
        title = Strings.BOARD_TITLE,
        icon = "pearl",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = VillageController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    for i, entry in
        { { "village", Strings.BOARD_TAB_VILLAGE }, { "outfits", Strings.BOARD_TAB_OUTFITS } }
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
        b.Position = UDim2.fromOffset((i - 1) * 158, 0)
        tabButtons[key] = b
    end

    local blurb =
        Widgets.Label(body, Strings.BOARD_BLURB, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 48)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.ZIndex = Z + 1

    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 72)
    holder.Size = UDim2.new(1, 0, 1, -72)

    d.Remotes.ShopResult.OnClientEvent:Connect(
        function(what: string, id: string, ok: boolean, reason: string)
            local name = id
            local decor = VillageConfig.decorById[id]
            local outfit = VillageConfig.outfitById[id]
            if decor ~= nil then
                name = decor.name
            elseif outfit ~= nil then
                name = outfit.name
            end
            d.OnToast(
                Strings.shopResult(what, name, ok, reason),
                if ok then Theme.COLOR.gold else Theme.COLOR.bad
            )
            if ok and what ~= "decor" then
                SoundController.Play("chime")
            end
        end
    )

    Panels.Register("board", { isOpen = VillageController.IsOpen, close = VillageController.Close })
    buildWorldBoard(d)
end

return VillageController
