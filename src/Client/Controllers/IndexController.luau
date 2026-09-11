--!strict
-- Colectia: ce a scos raul la mal si ai reparat [DECIZII D17].
--
-- DE CE EXISTA: reparatia umple deja Indexul si deschide sloturi, dar pana acum jucatorul nu si-l
-- putea VEDEA. Adica muncea pentru ceva ce nu exista pe ecran. Panoul asta e jumatatea care da
-- inteles celeilalte: aici se vede ce ai, ce iti lipseste si ce se deschide mai departe.
--
-- Pictogramele obiectelor nu sunt inca urcate pe platforma. Pana atunci fiecare obiect isi arata
-- culoarea de accent din catalog, iar `swatchFor` e singurul loc de schimbat cand vor exista.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RepairConfig = require(ReplicatedStorage.Shared.Config.RepairConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local IndexController = {}

local Z = 30
local PANEL_W, PANEL_H = 920, 620
local TILE_W, TILE_H = 138, 152
local HEAD_H = 74
local FOOT_H = 52

local root: Frame? = nil
local grid: ScrollingFrame
local headline: TextLabel
local unlockLine: TextLabel
local detail: TextLabel
local bar: Frame
local tiles: { [string]: TextButton } = {}
local counts: { [string]: number } = {}
local selected: string? = nil
local remotes: { [string]: RemoteEvent } = {}
local celebrationHost: Frame? = nil
local celebrateToken = 0

local function tierColor(tier: string): Color3
    for _, t in RiverConfig.TIERS do
        if t.id == tier then
            return Color3.fromRGB(t.rgb[1], t.rgb[2], t.rgb[3])
        end
    end
    return Theme.COLOR.inkSoft
end

-- Singurul loc care decide cum arata un obiect. Cand pictogramele ajung pe platforma, aici se
-- schimba un ImageLabel in loc de patratul de culoare, si nimic altundeva.
local function swatchFor(parent: Instance, item: ItemConfig.Item): Frame
    local sw = Instance.new("Frame")
    sw.Name = "Swatch"
    sw.Position = UDim2.fromOffset(10, 10)
    sw.Size = UDim2.fromOffset(TILE_W - 20, 74)
    sw.BackgroundColor3 = Color3.fromRGB(item.accent[1], item.accent[2], item.accent[3])
    sw.BorderSizePixel = 0
    sw.ZIndex = Z + 4
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = sw
    -- fasie de raritate pe muchia de jos: culoarea spune tierul fara sa citesti nimic
    local stripe = Instance.new("Frame")
    stripe.Name = "Tier"
    stripe.AnchorPoint = Vector2.new(0, 1)
    stripe.Position = UDim2.fromScale(0, 1)
    stripe.Size = UDim2.new(1, 0, 0, 6)
    stripe.BackgroundColor3 = tierColor(item.tier)
    stripe.BorderSizePixel = 0
    stripe.ZIndex = Z + 5
    stripe.Parent = sw
    sw.Parent = parent
    return sw
end

local function describe(item: ItemConfig.Item)
    selected = item.id
    local have = counts[item.id] or 0
    if have > 0 then
        detail.Text = item.flavour
        detail.TextColor3 = Theme.COLOR.ink
    else
        -- Numele se vede si inainte sa-l gasesti, ca sa stii ce vanezi. Replica nu: aia e
        -- rasplata pentru ca l-ai reparat, si singurul lucru pe care dezmembrarea nu ti-l da.
        detail.Text = `{item.name} — not recovered yet. Repair one to add it here.`
        detail.TextColor3 = Theme.COLOR.inkSoft
    end
end

local function buildTile(item: ItemConfig.Item): TextButton
    local tile = Instance.new("TextButton")
    tile.Name = item.id
    tile.Text = ""
    tile.AutoButtonColor = false
    tile.BackgroundColor3 = Theme.COLOR.parchmentDim
    tile.BackgroundTransparency = 0.25
    tile.Size = UDim2.fromOffset(TILE_W, TILE_H)
    tile.ZIndex = Z + 3
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = tile

    swatchFor(tile, item)

    local name = Widgets.Label(tile, item.name, Theme.TEXT.tiny, Theme.COLOR.ink, "strong")
    name.Position = UDim2.fromOffset(10, 90)
    name.Size = UDim2.fromOffset(TILE_W - 20, 52)
    name.TextWrapped = true
    name.TextYAlignment = Enum.TextYAlignment.Top
    name.ZIndex = Z + 4

    local badge = Widgets.Label(tile, "", Theme.TEXT.tiny, Theme.COLOR.gold, "display")
    badge.Name = "Badge"
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, -12, 0, 12)
    badge.Size = UDim2.fromOffset(40, 20)
    badge.TextXAlignment = Enum.TextXAlignment.Right
    badge.ZIndex = Z + 6
    Theme.punch(badge, 2)

    tile.Activated:Connect(function()
        describe(item)
    end)
    tile.Parent = grid
    return tile
end

-- Cate obiecte distincte s-au gasit, si ce prag urmeaza. Pragul se citeste din RepairConfig,
-- acelasi din care serverul chiar deschide slotul: nu se pot desincroniza.
local function nextGate(found: number, total: number): string
    local frac = if total > 0 then found / total else 0
    for i, gate in RepairConfig.SLOT_GATES do
        if frac < gate then
            local need = math.ceil(gate * total) - found
            local plural = if need == 1 then "" else "s"
            return `{need} more find{plural} opens repair slot {RepairConfig.WORKSHOP_SLOTS_FREE + i}`
        end
    end
    return "Every repair slot is open. Keep going for the collection itself."
end

function IndexController.Apply(s: { [string]: any })
    if root == nil then
        return
    end
    counts = s.index or {}
    local found = 0
    for _, item in ItemConfig.ITEMS do
        local have = counts[item.id] or 0
        if have > 0 then
            found += 1
        end
        local tile = tiles[item.id]
        if tile ~= nil then
            local sw = tile:FindFirstChild("Swatch") :: Frame?
            local badge = tile:FindFirstChild("Badge") :: TextLabel?
            if sw ~= nil then
                -- negasit: stins, dar silueta ramane, ca sa se vada golul din colectie
                sw.BackgroundTransparency = if have > 0 then 0 else 0.75
            end
            if badge ~= nil then
                badge.Text = if have > 1 then `x{have}` else ""
            end
            tile.BackgroundTransparency = if have > 0 then 0.25 else 0.55
        end
    end

    local total = ItemConfig.count()
    local pct = if total > 0 then math.floor(found / total * 100) else 0
    headline.Text = `{found} of {total} recovered  ·  {pct}%`
    bar.Size = UDim2.fromScale(if total > 0 then found / total else 0, 1)
    unlockLine.Text = nextGate(found, total)
    local current = selected
    if current ~= nil then
        local item = ItemConfig.get(current)
        if item ~= nil then
            describe(item) -- tinem fisa deschisa in acord cu starea noua
        end
    end
end

function IndexController.IsOpen(): boolean
    local r = root
    return r ~= nil and r.Visible
end

function IndexController.Close()
    local r = root
    if r ~= nil then
        r.Visible = false
    end
end

function IndexController.Toggle()
    local r = root
    if r == nil then
        return
    end
    if r.Visible then
        r.Visible = false
        return
    end
    if not Panels.CanOpen("index") then
        return
    end
    Panels.CloseOthers("index")
    r.Visible = true
    -- starea vine impinsa de server la reparatii; cerem si la deschidere, ca panoul sa nu arate
    -- o colectie invechita daca n-a mai reparat nimeni nimic de mult
    local request = remotes.RequestWorkshop
    if request ~= nil then
        request:FireServer()
    end
end

-- Momentul in care un obiect intra PERMANENT in colectie. E singurul lucru pe care reparatia il
-- da si dezmembrarea nu, adica rasplata pentru cele 45 de secunde pana la o ora de asteptare --
-- si pana acum se schimba doar o cifra, in tacere. Cartonasul se inchide singur; daca apesi pe
-- el, se deschide colectia la obiectul respectiv.
function IndexController.Celebrate(catalogId: string)
    local item = ItemConfig.get(catalogId)
    if item == nil or celebrationHost == nil then
        return
    end
    celebrateToken += 1
    local token = celebrateToken
    local host = celebrationHost :: Frame

    local card = Instance.new("TextButton")
    card.Name = "IndexCelebration"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.34)
    card.Size = UDim2.fromOffset(420, 132)
    card.BackgroundColor3 = Theme.COLOR.parchment
    card.AutoButtonColor = false
    card.Text = ""
    card.ZIndex = 80
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = card
    local edge = Instance.new("UIStroke")
    edge.Color = tierColor(item.tier)
    edge.Thickness = 4
    edge.Parent = card
    card.Parent = host

    local kicker =
        Widgets.Label(card, "ADDED TO YOUR COLLECTION", 13, tierColor(item.tier), "display")
    kicker.Position = UDim2.fromOffset(18, 14)
    kicker.Size = UDim2.fromOffset(384, 16)
    kicker.ZIndex = 81

    local title = Widgets.Label(card, item.name, Theme.TEXT.heading, Theme.COLOR.ink, "display")
    title.Position = UDim2.fromOffset(18, 34)
    title.Size = UDim2.fromOffset(384, 28)
    title.ZIndex = 81

    local line = Widgets.Label(card, item.flavour, Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    line.Position = UDim2.fromOffset(18, 66)
    line.Size = UDim2.fromOffset(384, 50)
    line.TextWrapped = true
    line.TextYAlignment = Enum.TextYAlignment.Top
    line.ZIndex = 81

    card.Activated:Connect(function()
        selected = item.id
        card:Destroy()
        if not IndexController.IsOpen() then
            IndexController.Toggle()
        end
    end)

    card.Size = UDim2.fromOffset(360, 132)
    TweenService
        :Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(420, 132),
        })
        :Play()
    task.delay(3.4, function()
        if celebrateToken ~= token or card.Parent == nil then
            return
        end
        local away = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(card, away, { Position = UDim2.fromScale(0.5, 0.28) }):Play()
        for _, l in { kicker, title, line } do
            TweenService:Create(l, away, { TextTransparency = 1 }):Play()
        end
        TweenService:Create(card, away, { BackgroundTransparency = 1 }):Play()
        TweenService:Create(edge, away, { Transparency = 1 }):Play()
        task.delay(0.5, function()
            card:Destroy()
        end)
    end)
end

function IndexController.Init(deps: { HudGui: Frame, Remotes: { [string]: RemoteEvent } })
    remotes = deps.Remotes
    celebrationHost = deps.HudGui
    local window, body = Widgets.Window(deps.HudGui, {
        name = "IndexPanel",
        title = "Collection",
        icon = "crate",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = IndexController.Close,
    })
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false
    root = window

    headline = Widgets.Label(body, "", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    headline.Size = UDim2.new(1, 0, 0, 26)
    headline.ZIndex = Z + 3

    local track
    track, bar = Widgets.Bar(body, 320, 12, Theme.COLOR.gold, Z + 3)
    track.Position = UDim2.fromOffset(0, 32)

    unlockLine = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    unlockLine.Position = UDim2.fromOffset(0, 50)
    unlockLine.Size = UDim2.new(1, 0, 0, 20)
    unlockLine.ZIndex = Z + 3

    local holder = Widgets.Slot(body, Z + 1)
    holder.Position = UDim2.fromOffset(0, HEAD_H)
    holder.Size = UDim2.new(1, 0, 1, -HEAD_H - FOOT_H)

    grid = Instance.new("ScrollingFrame")
    grid.Name = "Grid"
    grid.BackgroundTransparency = 1
    grid.BorderSizePixel = 0
    grid.Position = UDim2.fromOffset(10, 10)
    grid.Size = UDim2.new(1, -20, 1, -20)
    grid.ScrollBarThickness = 8
    grid.ScrollBarImageColor3 = Theme.COLOR.wood
    grid.CanvasSize = UDim2.fromOffset(0, 0)
    grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
    grid.ZIndex = Z + 2
    grid.Parent = holder
    -- Grila se reaseaza singura pe latimea disponibila: pe telefon fereastra e mai ingusta,
    -- iar un numar fix de coloane ar taia ultima coloana fara niciun semn.
    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.fromOffset(TILE_W, TILE_H)
    layout.CellPadding = UDim2.fromOffset(Theme.SPACE.sm, Theme.SPACE.sm)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid

    for i, item in ItemConfig.ITEMS do
        local tile = buildTile(item)
        tile.LayoutOrder = i -- ordinea din catalog e deja de la comun la mitic
        tiles[item.id] = tile
    end

    detail = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    detail.AnchorPoint = Vector2.new(0, 1)
    detail.Position = UDim2.new(0, 0, 1, -6)
    detail.Size = UDim2.new(1, 0, 0, 40)
    detail.TextWrapped = true
    detail.ZIndex = Z + 3
    detail.Text = "Tap anything to read it. Repairing an item adds it here for good."

    deps.Remotes.WorkshopState.OnClientEvent:Connect(function(s: { [string]: any })
        IndexController.Apply(s)
    end)

    Panels.Register("index", { isOpen = IndexController.IsOpen, close = IndexController.Close })
end

return IndexController
