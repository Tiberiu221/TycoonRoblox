--!strict
-- [D60] NEGUSTORUL, in balci. Pe cele trei tarabe plutesc lucrurile zilei (patru, aceleasi pentru toata lumea); langa
-- oricare taraba, cardul scrie `Market (E)` si deschide vitrina: fiecare lucru cu felul lui, pretul pe buton sau
-- "Owned", si cat mai e pana la vitrina de maine. Cumpararea trece prin aceiasi validatori ca in sat (MarketService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local VillageConfig = require(ReplicatedStorage.Shared.Config.VillageConfig)

local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Item = {
    key: string,
    kind: string,
    id: string,
    name: string,
    price: number,
    owned: boolean,
}
export type Snapshot = { secondsLeft: number, items: { Item } }
export type Deps = {
    World: Frame,
    HudGui: Frame,
    MarketBuy: RemoteEvent,
    OnRestock: () -> (), -- a trecut miezul noptii: cere starea, cu vitrina noua
}

local MarketController = {}
local deps: Deps? = nil
local snapshot: Snapshot = { secondsLeft = 0, items = {} }
local pearls = 0
local restockAt = 0 -- os.clock() la care se schimba vitrina (din secondsLeft)

local STALLS = { "stall_1", "stall_2", "stall_3" }
local ON_STALL = { 1, 2, 2, 3 } -- pe ce taraba sta fiecare din cele patru lucruri
local STALL_DISTANCE = 120
local ICON = 36

-- ---- desenul unui lucru: decorul lui, omul in tinuta, sau pergamentul titlului -------------------
local function drawItem(holder: GuiObject, item: Item, px: number, z: number)
    for _, child in holder:GetChildren() do
        if child:IsA("ImageLabel") then
            child:Destroy()
        end
    end
    local function image(s: Assets.Sprite, w: number, h: number, tint: Color3?, rect: boolean)
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(s)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Position = UDim2.fromScale(0.5, 0.5)
        img.Size = UDim2.fromOffset(w, h)
        img.ImageColor3 = tint or Color3.new(1, 1, 1)
        if rect then
            img.ImageRectOffset = Vector2.new(0, 24 * 3) -- randul idle_down, cadrul 0
            img.ImageRectSize = Vector2.new(16, 24)
        end
        img.ZIndex = z
        img.Parent = holder
    end
    if item.kind == "decor" then
        local def = VillageConfig.decorById[item.id]
        local sprite = if def ~= nil then (Assets.decor :: any)[def.sprite] else nil
        if sprite ~= nil and Assets.has(sprite) then
            local s = math.min(px / sprite.width, px / sprite.height)
            image(sprite, sprite.width * s, sprite.height * s, nil, false)
        end
    elseif item.kind == "outfit" then
        local sheet = (Assets.people.outfit :: any)[item.id]
        if sheet ~= nil and Assets.has(sheet) and Assets.has(Assets.people.body.b) then
            local w, h = px * 2 / 3, px
            image(Assets.people.body.b, w, h, Color3.fromRGB(231, 188, 150), true)
            if Assets.has(Assets.people.hair.long) then
                image(Assets.people.hair.long, w, h, Color3.fromRGB(92, 62, 40), true)
            end
            image(sheet, w, h, nil, true)
        end
    elseif Assets.has(Assets.icons.pearl) then
        image(Assets.icons.pearl, px * 0.8, px * 0.8, Theme.COLOR.gold, false)
    end
end

-- ---- in lume: lucrurile zilei deasupra tarabelor ----------------------------------------------
local floats: { Frame } = {}

local function buildWorld(world: Frame)
    local x1, y1, _, h1 = FairScene.Spot("stall_1")
    local sign =
        Widgets.Label(world, Strings.MARKET_TITLE, Theme.TEXT.small, Theme.COLOR.gold, "display")
    sign.AnchorPoint = Vector2.new(0.5, 1)
    sign.Position = UDim2.fromOffset(x1, y1 - h1 - 6)
    sign.Size = UDim2.fromOffset(
        math.ceil(Theme.textWidth(Strings.MARKET_TITLE, Theme.TEXT.small, "display")) + 24,
        26
    )
    sign.TextXAlignment = Enum.TextXAlignment.Center
    sign.ZIndex = FairScene.Z.LABELS
    Theme.punch(sign, 2)
    for i = 1, #ON_STALL do
        local f = Instance.new("Frame")
        f.Name = `MarketItem{i}`
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Size = UDim2.fromOffset(ICON, ICON)
        f.BackgroundTransparency = 1
        f.ZIndex = FairScene.Z.LABELS - 2
        f.Visible = false
        f.Parent = world
        floats[i] = f
    end
end

local function placeFloats(t: number)
    local perStall: { [number]: number } = {}
    for i in floats do
        local stall = ON_STALL[i]
        perStall[stall] = (perStall[stall] or 0) + 1
    end
    local seen: { [number]: number } = {}
    for i, f in floats do
        local stall = ON_STALL[i]
        seen[stall] = (seen[stall] or 0) + 1
        local x, y, _, h = FairScene.Spot(STALLS[stall])
        local count = perStall[stall]
        local dx = if count > 1 then (seen[stall] - 1.5) * (ICON + 10) else 0
        local bob = math.sin(t * 2 + i) * 3
        f.Position = UDim2.fromOffset(x + dx, y - h * 0.45 + bob)
    end
end

local function drawWorld()
    for i, f in floats do
        local item = snapshot.items[i]
        f.Visible = item ~= nil
        if item ~= nil then
            drawItem(f, item, ICON, FairScene.Z.LABELS - 2)
        end
    end
end

-- ---- vitrina (panoul) -----------------------------------------------------------------------------
local PANEL_W, PANEL_H = 600, 460
local ROW_H = 64
local BUTTON_W = 150
local Z = 66
local window: Frame
local open = false
local restockLabel: TextLabel
type RowView = {
    frame: Frame,
    art: Frame,
    name: TextLabel,
    sub: TextLabel,
    state: TextLabel,
    button: TextButton,
}
local rows: { RowView } = {}
local actions: { [number]: () -> () } = {}

local function fmtDuration(seconds: number): string
    local s = math.max(0, math.floor(seconds))
    local h, m = math.floor(s / 3600), math.floor(s / 60) % 60
    return if h > 0 then `{h}h {m}m` else `{m}m {s % 60}s`
end

local function buildRow(parent: Instance, index: number): RowView
    local frame = Instance.new("Frame")
    frame.Name = `Row{index}`
    frame.BackgroundTransparency = 1
    frame.Size = UDim2.new(1, 0, 0, ROW_H)
    frame.Position = UDim2.fromOffset(0, 56 + (index - 1) * (ROW_H + Theme.SPACE.sm))
    frame.ZIndex = Z + 2
    frame.Parent = parent
    Widgets.PillBackground(frame, Z + 2)
    local art = Instance.new("Frame")
    art.Name = "Art"
    art.BackgroundTransparency = 1
    art.Position = UDim2.fromOffset(Theme.SPACE.md, 6)
    art.Size = UDim2.fromOffset(52, 52)
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
    local state =
        Widgets.Label(frame, Strings.MARKET_OWNED, Theme.TEXT.small, Theme.COLOR.good, "display")
    state.AnchorPoint = Vector2.new(1, 0.5)
    state.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    state.Size = UDim2.fromOffset(BUTTON_W, 24)
    state.TextXAlignment = Enum.TextXAlignment.Center
    state.ZIndex = Z + 3
    local button = Widgets.Button(frame, {
        text = Strings.BOARD_BUY,
        width = BUTTON_W,
        height = 44,
        z = Z + 3,
        reward = true,
        onClick = function()
            local act = actions[index]
            if act ~= nil then
                act()
            end
        end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    return { frame = frame, art = art, name = name, sub = sub, state = state, button = button }
end

local function refreshPanel()
    local d = deps
    if d == nil then
        return
    end
    for i, view in rows do
        local item = snapshot.items[i]
        view.frame.Visible = item ~= nil
        actions[i] = nil
        if item == nil then
            continue
        end
        drawItem(view.art, item, 48, Z + 4)
        view.name.Text = item.name
        view.sub.Text = (Strings.MARKET_KIND :: any)[item.kind] or ""
        view.state.Visible = item.owned
        view.button.Visible = not item.owned
        if not item.owned then
            Widgets.SetButtonReward(view.button, tostring(item.price), "pearls")
            Widgets.SetButtonTone(
                view.button,
                if pearls >= item.price then Theme.COLOR.gold else nil
            )
            local key = item.key
            actions[i] = function()
                SoundController.Play("click")
                d.MarketBuy:FireServer(key)
            end
        end
    end
end

function MarketController.IsOpen(): boolean
    return open
end

function MarketController.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function MarketController.Open()
    Panels.CloseOthers("market")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refreshPanel()
end

function MarketController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local best, bestDistance = nil :: string?, STALL_DISTANCE
    for _, stall in STALLS do
        local x, y = FairScene.Spot(stall)
        local distance = Focus.distance(px, py, x, y + 10)
        if distance <= bestDistance then
            best, bestDistance = stall, distance
        end
    end
    if best == nil then
        return nil
    end
    local x, y, _, h = FairScene.Spot(best)
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = "market",
        distance = bestDistance,
        x = x - 150, -- in stanga tarabei: deasupra ei plutesc lucrurile zilei
        y = y - h * 0.5,
        action = Strings.marketCard(keyHint),
        act = MarketController.Open,
    }
end

-- Din FairState: vitrina zilei (cu ce ai deja) si perlele tale.
function MarketController.Apply(snap: Snapshot, pearlsNow: number)
    snapshot = snap
    pearls = math.floor(pearlsNow)
    restockAt = os.clock() + snap.secondsLeft
    if deps ~= nil then
        drawWorld()
        if open then
            refreshPanel()
        end
    end
end

function MarketController.Init(d: Deps)
    deps = d
    buildWorld(d.World)
    local root, body = Widgets.Window(d.HudGui, {
        name = "Market",
        title = Strings.MARKET_TITLE,
        icon = "pearl",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = MarketController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false
    local blurb =
        Widgets.Label(body, Strings.MARKET_BLURB, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 0)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.ZIndex = Z + 1
    restockLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
    restockLabel.Position = UDim2.fromOffset(0, 24)
    restockLabel.Size = UDim2.new(1, 0, 0, 22)
    restockLabel.ZIndex = Z + 1
    for i = 1, #ON_STALL do
        rows[i] = buildRow(body, i)
    end

    local acc = 0
    RunService.PreRender:Connect(function(dt: number)
        placeFloats(os.clock())
        acc += dt
        if acc < 0.5 then
            return
        end
        acc = 0
        local left = restockAt - os.clock()
        if open then
            restockLabel.Text = Strings.marketRestock(fmtDuration(left))
        end
        if left <= 0 and restockAt > 0 then
            restockAt = 0 -- vitrina noua vine cu starea urmatoare, ceruta acum
            d.OnRestock()
        end
    end)
    Panels.Register("market", { isOpen = MarketController.IsOpen, close = MarketController.Close })
end

return MarketController
