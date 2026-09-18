--!strict
-- [D61, partea 2] PANOUL `Shop`, acelasi in sat si in balci (montat in ambele proiecte). Ce se vinde pe Robux, cu fraza
-- fiecarui lucru si pretul CITIT DE LA ROBLOX -- nu scris in cod, deci nu poate minti [D40] si owner-ul il schimba din
-- Creator Hub fara noi. Ce nu exista inca pe universul asta (ID 0) scrie `Opens soon` si nu are buton.
--
-- Regulile (D20, D46, nota 41): viteza, spatiu, aspect. Fara noroc, fara lazi, fara perle, fara cronometre de presiune,
-- fara nimic care se pierde. In sat, intrarea `Shop` din bara apare abia dupa prima vanzare: un magazin aratat inainte
-- de prima moneda castigata invata jucatorul ca e sarac inainte sa-l invete ca poate castiga (nota 41).
--
-- Cumpararea: clientul cere (`RobuxBuy`), serverul deschide fereastra Roblox (pretul si confirmarea sunt ale lor), iar ce
-- ai primit vine pe `RobuxResult`.
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Robux = {
    passes: { [string]: boolean },
    quote: { [string]: number },
    speed: number,
}
export type Deps = {
    HudGui: Frame,
    RobuxBuy: RemoteEvent,
    -- ce se vinde aici: "village" = pass-urile si produsele pe monede; "fair" = doar pass-urile
    Place: string,
}

local ShopPanel = {}
local deps: Deps? = nil
local window: Frame
local open = false
local list: ScrollingFrame
local state: Robux = { passes = {}, quote = {}, speed = 1 }

-- Cutiile randului: scripts/art/check_panel_rows.py (SHOP_ROW).
local PANEL_W, PANEL_H = 640, 520
local ROW_H = 76
local BUTTON_W = 150
local TEXT_X = 64
local TEXT_W = 330
local Z = 78

type RowView = {
    frame: Frame,
    icon: ImageLabel,
    name: TextLabel,
    blurb: TextLabel,
    state: TextLabel,
    button: TextButton,
}
local views: { RowView } = {}
local actions: { [number]: () -> () } = {}

-- Preturile citite de la Roblox, pe cheie: numar = pretul; false = citirea a picat (se reincearca la deschidere).
local prices: { [string]: number | boolean } = {}
local asking: { [string]: boolean } = {}
local onPrice: { () -> () } = {}

local function idOf(key: string): number
    return MonetizationConfig.idOf(game.GameId, key)
end

-- Pretul unui lucru, daca il stim deja. Altfel il cere (o singura data) si anunta cand a venit.
function ShopPanel.PriceOf(key: string): number?
    local known = prices[key]
    if typeof(known) == "number" then
        return known
    end
    local item = MonetizationConfig.byKey[key]
    local id = idOf(key)
    if item == nil or id == 0 or asking[key] then
        return nil
    end
    asking[key] = true
    task.spawn(function()
        local ok, info = pcall(function()
            local infoType = if item.kind == "pass"
                then Enum.InfoType.GamePass
                else Enum.InfoType.Product
            return MarketplaceService:GetProductInfo(id, infoType)
        end)
        asking[key] = nil
        local price = if ok and typeof(info) == "table" then (info :: any).PriceInRobux else nil
        prices[key] = if typeof(price) == "number" then price else false
        for _, fn in onPrice do
            fn()
        end
    end)
    return nil
end

-- Cineva vrea sa afle cand vine un pret (fereastra "Welcome back", pentru butonul ei).
function ShopPanel.OnPrice(fn: () -> ())
    table.insert(onPrice, fn)
end

function ShopPanel.Exists(key: string): boolean
    return idOf(key) ~= 0
end

local function itemsHere(): { MonetizationConfig.Item }
    local d = deps :: Deps
    local out: { MonetizationConfig.Item } = {}
    for _, item in MonetizationConfig.ITEMS do
        if item.where == "shop" or (item.where == "village" and d.Place == "village") then
            table.insert(out, item)
        end
    end
    return out
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
    icon.Position = UDim2.fromOffset(Theme.SPACE.md, (ROW_H - 40) / 2)
    icon.Size = UDim2.fromOffset(40, 40)
    icon.ZIndex = Z + 3
    icon.Parent = frame

    local name = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    name.Position = UDim2.fromOffset(TEXT_X, 8)
    name.Size = UDim2.fromOffset(TEXT_W, 20)
    name.TextTruncate = Enum.TextTruncate.AtEnd
    name.ZIndex = Z + 3

    -- fraza lucrului, pe doua randuri: spune exact ce face
    local blurb = Widgets.Label(frame, "", Theme.TEXT.tiny, Theme.COLOR.onDarkSoft, "body")
    blurb.Position = UDim2.fromOffset(TEXT_X, 30)
    blurb.Size = UDim2.fromOffset(TEXT_W, 38)
    blurb.TextWrapped = true
    blurb.TextYAlignment = Enum.TextYAlignment.Top
    blurb.ZIndex = Z + 3

    local stateLabel = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.good, "display")
    stateLabel.AnchorPoint = Vector2.new(1, 0.5)
    stateLabel.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    stateLabel.Size = UDim2.fromOffset(BUTTON_W, 24)
    stateLabel.TextXAlignment = Enum.TextXAlignment.Center
    stateLabel.ZIndex = Z + 3

    local button = Widgets.Button(frame, {
        text = "",
        width = BUTTON_W,
        height = 44,
        z = Z + 3,
        onClick = function()
            local act = actions[index]
            if act ~= nil then
                act()
            end
        end,
    })
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.Position = UDim2.new(1, -Theme.SPACE.md, 0.5, 0)
    Widgets.SetButtonTone(button, Theme.COLOR.gold)
    return {
        frame = frame,
        icon = icon,
        name = name,
        blurb = blurb,
        state = stateLabel,
        button = button,
    }
end

local function refresh()
    local d = deps
    if d == nil or not open then
        return
    end
    local items = itemsHere()
    for i, item in items do
        local view = views[i]
        if view == nil then
            view = buildRow(i)
            views[i] = view
        end
        view.frame.Visible = true
        -- [D63] pictograma proprie a ofertei; pana e urcata, cea de rezerva din restul jocului
        local sprite = (Assets.icons :: any)[item.art]
        if sprite == nil or not Assets.has(sprite) then
            sprite = (Assets.icons :: any)[item.icon]
        end
        view.icon.Image = if sprite ~= nil and Assets.has(sprite) then Assets.url(sprite) else ""
        view.name.Text = item.name
        -- One Hour of Flow spune si suma de acum: ce scrie e ce primesti [D40]
        local amount = state.quote[item.key]
        view.blurb.Text = if item.key == "hour"
                and typeof(amount) == "number"
                and amount > 0
            then Strings.shopHourNow(TycoonMath.formatNumber(amount))
            else item.blurb
        actions[i] = nil
        local owned = item.kind == "pass" and state.passes[item.key] == true
        if owned then
            view.button.Visible = false
            view.state.Visible = true
            view.state.Text = Strings.SHOP_OWNED
            view.state.TextColor3 = Theme.COLOR.good
        elseif not ShopPanel.Exists(item.key) then
            view.button.Visible = false
            view.state.Visible = true
            view.state.Text = Strings.FAIR_OPENS_SOON
            view.state.TextColor3 = Theme.COLOR.onDarkSoft
        else
            local price = ShopPanel.PriceOf(item.key)
            view.state.Visible = false
            view.button.Visible = true
            Widgets.SetButtonText(
                view.button,
                if price ~= nil then Strings.shopPrice(price) else Strings.SHOP_BUY
            )
            local key = item.key
            actions[i] = function()
                SoundController.Play("click")
                d.RobuxBuy:FireServer(key)
            end
        end
    end
    for i = #items + 1, #views do
        views[i].frame.Visible = false
        actions[i] = nil
    end
    list.CanvasSize = UDim2.fromOffset(0, #items * (ROW_H + Theme.SPACE.sm))
end

-- Din starea jocului: pass-urile tale si ce ar aduce produsele acum. Copiat camp cu camp [CLAUDE.md, capcana 3].
function ShopPanel.Apply(raw: unknown)
    local passes: { [string]: boolean } = {}
    local quote: { [string]: number } = {}
    local speed = 1
    if typeof(raw) == "table" then
        local r = raw :: any
        if typeof(r.passes) == "table" then
            for key, owned in r.passes do
                if typeof(key) == "string" and owned == true then
                    passes[key] = true
                end
            end
        end
        if typeof(r.quote) == "table" then
            for key, amount in r.quote do
                if typeof(key) == "string" and typeof(amount) == "number" then
                    quote[key] = amount
                end
            end
        end
        if typeof(r.speed) == "number" and r.speed >= 1 then
            speed = math.min(r.speed, 2)
        end
    end
    state = { passes = passes, quote = quote, speed = speed }
    refresh()
end

function ShopPanel.State(): Robux
    return state
end

function ShopPanel.IsOpen(): boolean
    return open
end

function ShopPanel.Close()
    open = false
    if window ~= nil then
        window.Visible = false
    end
end

function ShopPanel.Open()
    if deps == nil or not Panels.CanOpen("shop") then
        return
    end
    Panels.CloseOthers("shop")
    open = true
    window.Visible = true
    SoundController.Play("click")
    -- un pret a carui citire a picat se mai cere o data
    for key, known in prices do
        if known == false then
            prices[key] = nil
        end
    end
    refresh()
end

function ShopPanel.Toggle()
    if open then
        ShopPanel.Close()
    else
        ShopPanel.Open()
    end
end

function ShopPanel.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "Shop",
        title = Strings.SHOP_TITLE,
        icon = "coin",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = ShopPanel.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    local blurb =
        Widgets.Label(body, Strings.SHOP_BLURB, Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    blurb.Position = UDim2.fromOffset(0, 0)
    blurb.Size = UDim2.new(1, 0, 0, 18)
    blurb.TextTruncate = Enum.TextTruncate.AtEnd
    blurb.ZIndex = Z + 1

    list = Widgets.List(body, Z + 1, Theme.SPACE.sm)
    local holder = list.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 26)
    holder.Size = UDim2.new(1, 0, 1, -26)

    ShopPanel.OnPrice(refresh)
    Panels.Register("shop", { isOpen = ShopPanel.IsOpen, close = ShopPanel.Close })
end

return ShopPanel
