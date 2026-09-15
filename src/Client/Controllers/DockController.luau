--!strict
-- Taverna [D50], fostul debarcader: locul fix si prefabricat unde se vinde (TycoonConfig.DOCK = usa ei),
-- nu o platforma de cumparat [F0 spec 1.1]. Owner-ul: "nu se intelege nimic de acolo ca ar trebui sa
-- vinzi ceva, imi imaginez o taverna in care stau degeaba niste npc-uri «ca la piata»".
--
-- PRIMESTE DOAR CE E TAIAT [D49]: E cu scanduri in traista le lasa aici, iar bustenii bruti raman in
-- traista, cu un mesaj care spune de ce. Tot aici lasa Hauler-ul. Gramada se scurge in monede si,
-- atinsa, taverna isi deschide meniul de niveluri.
--
-- CLIENTII: cati vin = cat vinzi chiar acum (TavernCrowd, peste evenimentele Sold), nu cat ar putea
-- vinde taverna. Vin pe drumul mare dinspre vest, stau in fata ei si, la fiecare vanzare, unul pleaca
-- ducand o scandura. Doar pe client: nu schimba nicio cifra.
--
-- Pontonul cu barca a ramas pe punte (TycoonConfig.PIER): barca pleaca tot la fiecare vanzare.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local HandConfig = require(ReplicatedStorage.Shared.Config.HandConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local TavernCrowd = require(ReplicatedStorage.Shared.Modules.TavernCrowd)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local PileView = require(script.Parent.Parent.UI.PileView)
local PersonView = require(script.Parent.Parent.UI.PersonView)
local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)

export type Deps = {
    Plot: Frame,
    Remotes: { DeliverDock: RemoteEvent, Sold: RemoteEvent },
    CharacterPos: () -> (number, number),
    -- taverna atinsa deschide panoul de niveluri pe ea; dat din Bootstrap
    OpenStation: ((string, string?) -> ())?,
}

export type Sack = {
    count: number,
    capacity: number,
    raw: number,
    rawScrap: number, -- [D55]
    finds: number, -- [D56] gasirile neprelucrate (se vand si asa; incluse in `cut`)
    iron: number, -- [D55] fierul din traista: indemnul nu mai spune doar "planks"
    cut: number,
    cutValue: number,
}

type Point = { x: number, y: number }
type Customer = {
    view: PersonView.View,
    state: string, -- "arriving" | "waiting" | "leaving"
    spot: number?,
    x: number,
    y: number,
    path: { Point },
    facing: string,
    plank: boolean,
}

local DockController = {}
local deps: Deps
local pile: PileView.View
local salePill: Frame
local saleValueLabel: TextLabel
local sack: Sack =
    { count = 0, capacity = 0, raw = 0, rawScrap = 0, finds = 0, iron = 0, cut = 0, cutValue = 0 }
local boat: ImageLabel? = nil

local DOCK = TycoonConfig.DOCK
local TAVERN = TycoonConfig.TAVERN
local PIER = TycoonConfig.PIER
local PILE_SPOT = TycoonConfig.PILES.tavern
local TAVERN_TOP = TAVERN.y - TAVERN.h

local SALE_PILL_W, SALE_PILL_H = 110, 30
local BOAT_W = Assets.props.boat.width * TycoonConfig.PROP_SCALE
local BOAT_H = Assets.props.boat.height * TycoonConfig.PROP_SCALE
-- [D59] Barca pleaca din dreapta pontonului, in aval: in stanga lui asteapta ce aduce raul (TREASURE_SLOTS), iar in
-- stanga-sus pleca pana acum chiar peste ele.
local BOAT_START = UDim2.fromOffset(PIER.x + 100, 738)
local BOAT_END = UDim2.fromOffset(PIER.x + 260, 650)
local BOAT_TWEEN_SECONDS = 1.1
local BOAT_TWEEN = TweenInfo.new(BOAT_TWEEN_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

-- ---- clientii -----------------------------------------------------------------------------------
-- Unde stau cei care asteapta (picioarele), cu fata spre cine stau: doi la fereastra-tejghea, restul
-- pe drum si sub el, la cel putin o latime de om unul de altul, pe langa usa (unde se lasa marfa),
-- Innkeeper (x 446..494) si gramada (x <= 293, y <= 1092).
local SPOTS: { { x: number, y: number, facing: string } } = {
    { x = 340, y = 1094, facing = "up" },
    { x = 380, y = 1098, facing = "up" },
    { x = 330, y = 1150, facing = "right" },
    { x = 282, y = 1160, facing = "right" },
    { x = 385, y = 1180, facing = "left" },
    { x = 236, y = 1196, facing = "right" },
    { x = 318, y = 1212, facing = "up" },
    { x = 430, y = 1214, facing = "left" },
}
-- De unde vin si pe unde pleaca: capatul de vest al drumului mare, putin dincolo de teren.
local ENTRY: Point = { x = 150, y = 1130 }
local CUSTOMER_SPEED = 90 -- se plimba; oamenii tai merg cu 150
local SPAWN_GAP = 0.9 -- vin pe rand, nu toti deodata
local LEAVE_GAP = 1.2 -- o vanzare pe secunda n-are voie sa goleasca taverna intr-o clipa
-- Samanta clientilor. HandConfig o inmulteste cu ~2.65e9 inainte de modulo, deci trebuie sa ramana
-- sub ~3.4e6, altfel produsul trece de 2^53 si bitii de jos se pierd (clienti aproape identici).
local CUSTOMER_SEED_BASE = 900000

local customers: { Customer } = {}
local crowd = TavernCrowd.new()
local customerCount = 0
local lastSpawnAt = -math.huge
local lastLeaveAt = -math.huge

-- "Pleaca pe apa": o barca scurta paraseste pontonul si se stinge -- fara asta, o vanzare era doar o
-- cifra care sare in HUD [research 42 pct.6]. Gramada nu se goleste de mana: starea vine de la server.
local function playSaleDeparture()
    if boat == nil then
        return
    end
    local b = boat :: ImageLabel
    b.Position = BOAT_START
    b.ImageTransparency = 0
    b.Visible = true
    TweenService:Create(b, BOAT_TWEEN, { Position = BOAT_END, ImageTransparency = 1 }):Play()
    task.delay(BOAT_TWEEN_SECONDS, function()
        b.Visible = false
    end)
end

local function freeSpot(): number?
    for i = 1, #SPOTS do
        local taken = false
        for _, c in customers do
            if c.spot == i then
                taken = true
                break
            end
        end
        if not taken then
            return i
        end
    end
    return nil
end

local function spawnCustomer()
    local spot = freeSpot()
    if spot == nil then
        return
    end
    customerCount += 1
    local seed = CUSTOMER_SEED_BASE + customerCount
    local look = HandConfig.appearanceFor(seed)
    local outfits = HandConfig.CUSTOMER_OUTFITS
    local view = PersonView.new(deps.Plot, `Customer{customerCount}`, "plank")
    view.SetAppearance({
        body = look.body,
        hair = look.hair,
        skin = look.skin,
        hairColor = look.hairColor,
        outfit = outfits[(customerCount % #outfits) + 1],
    })
    local s = SPOTS[spot]
    table.insert(customers, {
        view = view,
        state = "arriving",
        spot = spot,
        x = ENTRY.x,
        y = ENTRY.y,
        path = { { x = s.x, y = ENTRY.y }, { x = s.x, y = s.y } },
        facing = "right",
        plank = false,
    })
end

-- Pleaca spre vest pe drumul mare; cu o scandura in brate, daca pleaca pentru ca a cumparat.
local function leave(c: Customer, withPlank: boolean)
    c.state = "leaving"
    c.spot = nil
    c.plank = withPlank
    c.path = { { x = c.x, y = ENTRY.y }, { x = ENTRY.x, y = ENTRY.y } }
end

local function firstWaiting(): Customer?
    for _, c in customers do
        if c.state == "waiting" then
            return c
        end
    end
    return nil
end

local function stepCustomers(dt: number)
    local now = os.clock()
    local target = TavernCrowd.count(crowd, now)
    local present = 0
    for _, c in customers do
        if c.state ~= "leaving" then
            present += 1
        end
    end
    if present < target and now - lastSpawnAt >= SPAWN_GAP then
        lastSpawnAt = now
        spawnCustomer()
    elseif present > target and now - lastLeaveAt >= LEAVE_GAP then
        local c = firstWaiting()
        if c ~= nil then
            lastLeaveAt = now
            leave(c, false)
        end
    end

    for i = #customers, 1, -1 do
        local c = customers[i]
        local budget = CUSTOMER_SPEED * dt
        while budget > 0 and #c.path > 0 do
            local p = c.path[1]
            local dx, dy = p.x - c.x, p.y - c.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d <= budget then
                c.x, c.y = p.x, p.y
                budget -= d
                table.remove(c.path, 1)
            else
                c.x += dx / d * budget
                c.y += dy / d * budget
                budget = 0
                c.facing = if math.abs(dx) >= math.abs(dy)
                    then (if dx >= 0 then "right" else "left")
                    else (if dy >= 0 then "down" else "up")
            end
        end
        local moving = #c.path > 0
        if not moving then
            if c.state == "arriving" then
                c.state = "waiting"
                c.facing = SPOTS[c.spot :: number].facing
            elseif c.state == "leaving" then
                c.view.Destroy()
                table.remove(customers, i)
                continue
            end
        end
        c.view.Pose(c.x, c.y, "idle", c.facing, moving, dt)
        c.view.SetHeld(if c.plank then 1 else 0)
    end
end

-- Starea vine din TycoonState, inlocuita la fiecare mesaj [F0 spec 4.1]; campurile sunt copiate
-- explicit in Bootstrap [CLAUDE.md capcana 3].
function DockController.Apply(
    newSack: Sack,
    dock: {
        count: number,
        value: number,
        rate: number,
        contents: { [string]: number },
    }?
)
    sack = newSack
    salePill.Visible = sack.cut > 0
    saleValueLabel.Text = TycoonMath.formatNumber(sack.cutValue)
    if dock ~= nil then
        pile.Set(dock.count, dock.contents)
    end
end

-- [D51] Cardul tavernei, la usa: vinzi scandurile, cu valoarea lor; cu busteni bruti cardul spune de
-- ce nu se poate [D43]. Upgrade = nivelul tavernei.
function DockController.Focus(px: number, py: number): Focus.Focus?
    local d = Focus.distance(px, py, DOCK.x, DOCK.y)
    if d > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local text: string? = nil
    local status: string? = nil
    if sack.cut > 0 then
        local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
        local value = TycoonMath.formatNumber(sack.cutValue)
        -- [D55, D56] cu fier sau o gasire in traista, "Sell planks" ar minti pe jumatate
        text = if sack.iron > 0 or sack.finds > 0
            then Strings.promptSell(keyHint, value)
            else Strings.promptSellPlanks(keyHint, value)
    elseif sack.rawScrap > 0 and sack.raw > 0 then
        status = Strings.PROMPT_DOCK_BOTH -- [D55] busteni si scrap: fiecare are drumul lui
    elseif sack.rawScrap > 0 then
        status = Strings.PROMPT_DOCK_SCRAP
    elseif sack.count > 0 then
        status = Strings.PROMPT_DOCK_RAW
    end
    return {
        key = "dock",
        distance = d,
        x = TAVERN.x,
        y = TAVERN_TOP - 6,
        action = text,
        act = if text ~= nil
            then function()
                deps.Remotes.DeliverDock:FireServer()
            end
            else nil,
        status = status,
        upgradeKind = "dock",
    }
end

local function buildPier()
    -- [D59] pontonul lung, pe care mergi pana la capat ca sa pescuiesti; pier3 (scurt, cu baza in acelasi loc) ramane
    -- plasa de siguranta cat desenul nou nu e inca pe platforma, iar `pier` (vechiul) dupa el
    local long = Assets.has(Assets.tycoon.pier_long)
    local pierSprite = if long
        then Assets.tycoon.pier_long
        elseif Assets.has(Assets.tycoon.pier3) then Assets.tycoon.pier3
        else Assets.tycoon.pier
    if Assets.has(pierSprite) then
        local base = PIER.y + Assets.tycoon.pier_long.height * Assets.PIXEL_SCALE / 2
        local img = Instance.new("ImageLabel")
        img.Name = "Pier"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(pierSprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(PIER.x, base)
        img.Size = UDim2.fromOffset(
            pierSprite.width * Assets.PIXEL_SCALE,
            pierSprite.height * Assets.PIXEL_SCALE
        )
        img.ZIndex = 3
        img.Parent = deps.Plot
    end

    -- barca vanzarii: un singur exemplar, ascuns pana la prima vanzare [research 42 pct.6]
    if Assets.has(Assets.props.boat) then
        local b = Instance.new("ImageLabel")
        b.Name = "SaleBoat"
        b.BackgroundTransparency = 1
        b.Image = Assets.url(Assets.props.boat)
        b.ResampleMode = Enum.ResamplerMode.Pixelated
        b.AnchorPoint = Vector2.new(0.5, 0.5)
        b.Size = UDim2.fromOffset(BOAT_W, BOAT_H)
        b.Position = BOAT_START
        b.ZIndex = 4
        b.Visible = false
        b.Parent = deps.Plot
        boat = b
    end
end

local function buildTavern()
    GroundShadow.add(deps.Plot, UDim2.fromOffset(TAVERN.x, TAVERN.y), TAVERN.w, 2) -- [D57]
    local marker = Instance.new("Frame")
    marker.Name = "Tavern"
    marker.AnchorPoint = Vector2.new(0.5, 1)
    marker.Position = UDim2.fromOffset(TAVERN.x, TAVERN.y)
    marker.Size = UDim2.fromOffset(TAVERN.w, TAVERN.h)
    marker.BackgroundTransparency = 1
    marker.ZIndex = 3
    marker.Parent = deps.Plot

    if Assets.has(Assets.tycoon.tavern) then
        local art = Instance.new("ImageLabel")
        art.Name = "Art"
        art.BackgroundTransparency = 1
        art.Image = Assets.url(Assets.tycoon.tavern)
        art.ResampleMode = Enum.ResamplerMode.Pixelated
        art.Size = UDim2.fromScale(1, 1)
        art.ZIndex = 3
        art.Parent = marker
    else
        -- arta inca neurcata: o casa de lemn simpla, cat sa se vada unde e taverna [regula 6]
        marker.BackgroundTransparency = 0.15
        marker.BackgroundColor3 = Theme.COLOR.wood
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = marker
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.COLOR.woodDark
        stroke.Thickness = 3
        stroke.Parent = marker
        local icon = Widgets.Icon(marker, "coin", 32)
        if icon ~= nil then
            icon.AnchorPoint = Vector2.new(0.5, 0.5)
            icon.Position = UDim2.fromScale(0.5, 0.5)
        end
    end

    -- Atinsa, taverna isi deschide nivelul. Vanzarea ramane pe E si pe apropiere -- doua gesturi
    -- diferite (apasare vs. tasta), deci nu se pot calca unul pe altul.
    local tap = Instance.new("TextButton")
    tap.Name = "Tap"
    tap.Text = ""
    tap.AutoButtonColor = false
    tap.BackgroundTransparency = 1
    tap.Size = UDim2.fromScale(1, 1)
    tap.ZIndex = 5
    tap.Parent = marker
    tap.Activated:Connect(function()
        if deps.OpenStation ~= nil then
            (deps.OpenStation :: (string, string?) -> ())("dock", nil)
        end
    end)

    -- numele pe acoperis, ca o firma: jos ar fi acoperit usa
    local label =
        Widgets.Label(marker, Strings.TAVERN_LABEL, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    label.AnchorPoint = Vector2.new(0.5, 0)
    label.Position = UDim2.new(0.5, 0, 0, 30)
    label.Size = UDim2.fromOffset(TAVERN.w - 40, 18)
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.ZIndex = 6
    Theme.punch(label, 2)
end

function DockController.Init(d: Deps)
    deps = d
    buildPier()
    buildTavern()

    pile = PileView.new(deps.Plot, PILE_SPOT.x, PILE_SPOT.y, { pill = PILE_SPOT.pill })

    -- Valoarea scandurilor din traista, vizibila de oriunde cat le duci [F2 spec Agent U pct.4]. Aici,
    -- nu la gater: banii se fac la taverna, iar bustenii bruti nu intra in cifra [D40, D49].
    salePill = Instance.new("Frame")
    salePill.Name = "SackValue"
    salePill.AnchorPoint = Vector2.new(0.5, 1)
    -- deasupra cardului obiectului (care sta intre TAVERN_TOP - 50 si - 6) [D51]
    salePill.Position = UDim2.fromOffset(TAVERN.x, TAVERN_TOP - 56)
    salePill.Size = UDim2.fromOffset(SALE_PILL_W, SALE_PILL_H)
    salePill.ZIndex = 4
    salePill.Visible = false
    Widgets.PillBackground(salePill, 4)
    salePill.Parent = deps.Plot
    local saleRow = Instance.new("Frame")
    saleRow.Name = "Row"
    saleRow.BackgroundTransparency = 1
    saleRow.Position = UDim2.fromOffset(Theme.SPACE.sm, 0)
    saleRow.Size = UDim2.new(1, -Theme.SPACE.sm * 2, 1, 0)
    saleRow.ZIndex = 5
    saleRow.Parent = salePill
    local saleLayout = Instance.new("UIListLayout")
    saleLayout.FillDirection = Enum.FillDirection.Horizontal
    saleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    saleLayout.Padding = UDim.new(0, Theme.SPACE.xs)
    saleLayout.Parent = saleRow
    local saleCoin = Widgets.CoinIcon(saleRow, 16, 6)
    saleCoin.LayoutOrder = 1
    saleValueLabel = Widgets.Label(saleRow, "0", Theme.TEXT.small, Theme.COLOR.onDark, "strong")
    saleValueLabel.LayoutOrder = 2
    saleValueLabel.AutomaticSize = Enum.AutomaticSize.X
    saleValueLabel.Size = UDim2.fromOffset(0, Theme.TEXT.small + 4)
    saleValueLabel.ZIndex = 6
    Theme.punch(saleValueLabel, 2)

    -- "+N" la vanzare e la Overlay [F1 spec 4.8]. Aici, acelasi Sold pune barca pe apa, intra in
    -- fereastra clientilor si trimite un client acasa cu o scandura -- raspunsuri la acelasi
    -- eveniment, fara conflict.
    deps.Remotes.Sold.OnClientEvent:Connect(function(_total: number, itemCount: number)
        local now = os.clock()
        if type(itemCount) == "number" then
            TavernCrowd.add(crowd, now, itemCount)
        end
        playSaleDeparture()
        if now - lastLeaveAt >= LEAVE_GAP then
            local c = firstWaiting()
            if c ~= nil then
                lastLeaveAt = now
                leave(c, true)
            end
        end
    end)

    RunService.PreRender:Connect(stepCustomers)
end

return DockController
