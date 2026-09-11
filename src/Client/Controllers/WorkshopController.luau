--!strict
-- Atelierul: gramada nesortata, sloturi de reparatie cu cronometru; dezmembrarea plateste in
-- monede [DECIZII D16, D45]. Adormit in F0 (nu are buton in bara), revine in F1.
--
-- Construit din trusa comuna (rama de lemn, pergament, randuri scobite, butoane cu trei stari).
-- Varianta veche era desenata de mana, cu Gotham si 17 culori scrise direct in cod, si arata ca
-- un dialog generic lipit peste un joc pixelat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ItemConfig = require(ReplicatedStorage.Shared.Config.ItemConfig)
local RepairConfig = require(ReplicatedStorage.Shared.Config.RepairConfig)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local WorkshopController = {}
local deps: { HudGui: Frame, Remotes: { [string]: RemoteEvent }, OnToast: (string) -> () }
local panel: Frame
local pileList: ScrollingFrame
local pileCount: TextLabel
local slotFrames: { Frame } = {}
local foundValue: TextLabel
local repairedValue: TextLabel
local state: { [string]: any }? = nil
local serverOffset = 0 -- os.time() client vs server (Studio: 0)

local PANEL_W, PANEL_H = 1060, 660
local LEFT_W = 610
local Z = 30
-- randul din gramada: nume sus, apoi cate o banda Repair/Scrap cu explicatia lipita de butonul ei
local PILE_ROW_H = 122

local TIER_COLORS: { [string]: Color3 } = {}
for _, t in RiverConfig.TIERS do
    TIER_COLORS[t.id] = Color3.fromRGB(t.rgb[1], t.rgb[2], t.rgb[3])
end

-- Numele obiectului din catalog. Cade elegant la tier pentru obiectele prinse inainte de Index.
local function itemName(entry: { [string]: any }): string
    local catalog = entry.catalog
    if catalog ~= nil and catalog ~= "" then
        local def = ItemConfig.get(catalog)
        if def ~= nil then
            return def.name
        end
    end
    return `{entry.tier} salvage`
end

local function fmt(sec: number): string
    sec = math.max(0, math.floor(sec))
    if sec >= 3600 then
        return `{math.floor(sec / 3600)}h {math.floor(sec % 3600 / 60)}m`
    end
    return `{math.floor(sec / 60)}:{string.format("%02d", sec % 60)}`
end

local function firstFreeSlot(): number?
    local s = state
    if s == nil then
        return nil
    end
    for i = 1, s.slots do
        if s.repairs[tostring(i)] == nil then
            return i
        end
    end
    return nil
end

local function rebuildPile()
    for _, child in pileList:GetChildren() do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end
    local s = state
    if s == nil then
        return
    end
    pileCount.Text = `{#s.pile} waiting`

    -- Gramada goala trebuie sa SPUNA ce e de facut. Un dreptunghi gol arata a eroare.
    if #s.pile == 0 then
        local busy = 0
        for _ in s.repairs do
            busy += 1
        end
        -- "totul e la reparat" nu e acelasi lucru cu "n-ai adunat nimic": mesajul gresit ii
        -- spunea jucatorului sa se duca iar la plasa, desi tocmai adusese ceva
        local text = if busy > 0
            then `Pile empty — {busy} being repaired on the right. Collect a net for more.`
            else "Nothing here yet. The river fills your nets on its own — go collect one."
        local empty = Widgets.Label(pileList, text, Theme.TEXT.body, Theme.COLOR.inkSoft, "body")
        empty.Size = UDim2.new(1, -20, 0, 70)
        empty.TextWrapped = true
        empty.TextYAlignment = Enum.TextYAlignment.Top
        return
    end

    for index, item in s.pile do
        local rule = (RepairConfig.TIERS :: any)[item.tier]
        local row = Widgets.Row(pileList, PILE_ROW_H, Z + 3)
        row.LayoutOrder = index

        -- fasie de raritate pe muchie: culoarea spune tierul fara sa citesti nimic
        local swatch = Instance.new("Frame")
        swatch.Size = UDim2.fromOffset(6, PILE_ROW_H)
        swatch.BackgroundColor3 = TIER_COLORS[item.tier] or TIER_COLORS.common
        swatch.BorderSizePixel = 0
        swatch.ZIndex = Z + 4
        local sc = Instance.new("UICorner")
        sc.CornerRadius = UDim.new(0, 3)
        sc.Parent = swatch
        swatch.Parent = row

        local ico = Widgets.Icon(row, "crate", 32)
        if ico ~= nil then
            ico.Position = UDim2.fromOffset(18, (PILE_ROW_H - 32) // 2)
            ico.ZIndex = Z + 4
        end

        -- numele adevarat al obiectului. "rare crate" nu spunea nimic si nu se putea colectiona.
        local name = Widgets.Label(row, itemName(item), Theme.TEXT.body, Theme.COLOR.ink, "strong")
        name.Position = UDim2.fromOffset(60, 8)
        name.Size = UDim2.fromOffset(220, 22)
        name.ZIndex = Z + 4

        -- Repair si Scrap sunt alegeri OPUSE -- una pastreaza obiectul in Index pentru totdeauna,
        -- cealalta il vinde pe loc pentru monede -- deci fiecare isi are banda ei, cu
        -- explicatia lipita de butonul care o declanseaza. Text la Theme.TEXT.small: e informatie
        -- de care depinde alegerea, nu o eticheta decorativa (tiny ramane doar pentru etichete).
        -- coloana de text: x60, latime 398, pana unde incepe butonul (x470 pe un rand de 584).
        local repairInfo = Widgets.Label(
            row,
            `{fmt(rule.repairSeconds)} to repair — joins Index`,
            Theme.TEXT.small,
            Theme.COLOR.inkSoft,
            "body"
        )
        repairInfo.Position = UDim2.fromOffset(60, 34)
        repairInfo.Size = UDim2.fromOffset(398, 36)
        repairInfo.TextTruncate = Enum.TextTruncate.AtEnd
        repairInfo.ZIndex = Z + 4

        local repairBtn = Widgets.Button(row, {
            text = "Repair",
            icon = nil,
            width = 104,
            height = 36,
            z = Z + 4,
            onClick = function()
                local slot = firstFreeSlot()
                if slot == nil then
                    deps.OnToast("All repair slots are busy — collect one or scrap instead")
                    return
                end
                deps.Remotes.StartRepair:FireServer(item.id, slot)
            end,
        })
        repairBtn.Position = UDim2.new(1, -114, 0, 34)

        -- Dezmembrarea plateste in monede cat ar da debarcaderul (WorkshopService.ScrapItem).
        -- Suma exacta depinde de multiplicatorii de vanzare, pe care panoul nu-i primeste --
        -- deci nu scriem o cifra care ar putea minti [D40].
        local scrapInfo = Widgets.Label(
            row,
            "Sell it for coins now — item is lost for good",
            Theme.TEXT.small,
            Theme.COLOR.inkSoft,
            "body"
        )
        scrapInfo.Position = UDim2.fromOffset(60, 78)
        scrapInfo.Size = UDim2.fromOffset(398, 36)
        scrapInfo.TextTruncate = Enum.TextTruncate.AtEnd
        scrapInfo.ZIndex = Z + 4

        local scrapBtn = Widgets.Button(row, {
            text = "Scrap",
            icon = nil,
            width = 104,
            height = 36,
            z = Z + 4,
            onClick = function()
                deps.Remotes.ScrapItem:FireServer(item.id)
            end,
        })
        scrapBtn.Position = UDim2.new(1, -114, 0, 78)
    end
end

local function refreshSlots()
    local s = state
    if s == nil then
        return
    end
    local now = os.time() + serverOffset
    for i, frame in slotFrames do
        local title = frame:FindFirstChild("Title", true) :: TextLabel
        local sub = frame:FindFirstChild("Sub", true) :: TextLabel
        local bar = frame:FindFirstChild("Bar", true) :: Frame
        local track = frame:FindFirstChild("Track", true) :: Frame
        local btn = frame:FindFirstChild("Collect", true) :: TextButton
        local r = s.repairs[tostring(i)]

        if i > s.slots then
            title.Text = "Locked"
            title.TextColor3 = Theme.COLOR.inkSoft
            -- pragul ADEVARAT, nu "Unlocks with progress". Pana acum nu deblocase nimic nimic.
            local gate = RepairConfig.SLOT_GATES[i - RepairConfig.WORKSHOP_SLOTS_FREE]
            sub.Text = if gate ~= nil
                then `Opens at {math.floor(gate * 100)}% of the Index`
                else "Opens with a Workshop pass"
            track.Visible = false
            btn.Visible = false
        elseif r == nil then
            title.Text = "Empty"
            title.TextColor3 = Theme.COLOR.inkSoft
            sub.Text = "Send a crate here from the pile"
            track.Visible = false
            btn.Visible = false
        else
            local remaining = r.finishAt - now
            local total = math.max(1, r.finishAt - r.startedAt)
            local progress = math.clamp(1 - remaining / total, 0, 1)
            title.Text = itemName(r)
            title.TextColor3 = Theme.COLOR.ink
            sub.Text = if remaining > 0 then `{fmt(remaining)} left` else "Ready to collect"
            track.Visible = true
            bar.Size = UDim2.fromScale(progress, 1)
            bar.BackgroundColor3 = if remaining > 0 then Theme.COLOR.good else Theme.COLOR.gold
            btn.Visible = remaining <= 0
        end
    end

    -- Din Index (schema v2): cate obiecte distincte ai gasit si de cate ori ai reparat in total.
    -- Materialele si contorul pe tier au disparut odata cu colonia.
    local found, total = 0, 0
    for _, n in s.index or {} do
        found += 1
        total += n
    end
    foundValue.Text = tostring(found)
    repairedValue.Text = tostring(total)
end

function WorkshopController.Open()
    if not Panels.CanOpen("workshop") then
        return
    end
    Panels.CloseOthers("workshop")
    panel.Visible = true
    deps.Remotes.RequestWorkshop:FireServer()
end

function WorkshopController.Close()
    if panel ~= nil then
        panel.Visible = false
    end
end

function WorkshopController.Toggle()
    if panel == nil then
        return
    end
    if panel.Visible then
        WorkshopController.Close()
    else
        WorkshopController.Open()
    end
end

function WorkshopController.IsOpen(): boolean
    return panel ~= nil and panel.Visible
end

local function buildSlotCard(parent: Instance, index: number, y: number): Frame
    local card = Widgets.Slot(parent, Z + 3)
    card.Position = UDim2.fromOffset(0, y)
    card.Size = UDim2.new(1, 0, 0, 84)

    local title = Widgets.Label(card, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
    title.Name = "Title"
    title.Position = UDim2.fromOffset(16, 10)
    title.Size = UDim2.fromOffset(220, 22)
    title.ZIndex = Z + 5

    -- TEXT.small, nu tiny: aici scrie "Opens at 25% of the Index" si cat mai are o reparatie.
    -- Amandoua sunt informatii pe care jucatorul ia decizii, nu etichete decorative.
    local sub = Widgets.Label(card, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    sub.Name = "Sub"
    sub.Position = UDim2.fromOffset(16, 32)
    sub.Size = UDim2.fromOffset(260, 20)
    sub.ZIndex = Z + 5

    local track, bar = Widgets.Bar(card, 240, 10, Theme.COLOR.good, Z + 5)
    track.Name = "Track"
    bar.Name = "Bar"
    track.Position = UDim2.fromOffset(16, 58)
    track.Visible = false

    local btn = Widgets.Button(card, {
        text = "Collect",
        icon = nil,
        width = 110,
        height = 40,
        z = Z + 5,
        onClick = function()
            deps.Remotes.CollectRepair:FireServer(index)
        end,
    })
    btn.Name = "Collect"
    btn.Position = UDim2.new(1, -126, 0, 22)
    btn.Visible = false
    return card
end

function WorkshopController.Init(d: typeof(deps))
    deps = d
    Panels.Register(
        "workshop",
        { isOpen = WorkshopController.IsOpen, close = WorkshopController.Close }
    )

    local root, body = Widgets.Window(deps.HudGui, {
        name = "Workshop",
        title = "Workshop",
        icon = "hammer",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = WorkshopController.Close,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false
    panel = root

    -- coloana stanga: gramada
    local pileHeader =
        Widgets.Label(body, "Unsorted pile", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    pileHeader.Size = UDim2.fromOffset(300, 26)
    pileCount = Widgets.Label(body, "0 waiting", Theme.TEXT.small, Theme.COLOR.inkSoft, "strong")
    pileCount.Position = UDim2.fromOffset(LEFT_W - 120, 4)
    pileCount.Size = UDim2.fromOffset(110, 20)
    pileCount.TextXAlignment = Enum.TextXAlignment.Right

    local pileHint = Widgets.Label(
        body,
        "Always more crates than slots. Repair the good ones, sell the rest for coins.",
        Theme.TEXT.tiny,
        Theme.COLOR.inkSoft,
        "body"
    )
    pileHint.Position = UDim2.fromOffset(0, 28)
    pileHint.Size = UDim2.fromOffset(LEFT_W, 18)

    pileList = Widgets.List(body, Z + 2)
    local pileHolder = pileList.Parent :: Frame
    pileHolder.Position = UDim2.fromOffset(0, 52)
    -- inaltime relativa la corp, nu PANEL_H: pe telefon Widgets.Window micsoreaza fereastra sub
    -- inaltimea ceruta (fitToCanvas), iar o inaltime fixa aici ar impinge lista peste footer.
    -- 52 sus + 46 footer + 6 respiro = acelasi ~460 px ca inainte pe desktop, mai putin pe telefon.
    pileHolder.Size = UDim2.new(0, LEFT_W, 1, -104)

    -- coloana dreapta: sloturi
    local slotsHeader =
        Widgets.Label(body, "Repair slots", Theme.TEXT.heading, Theme.COLOR.ink, "display")
    slotsHeader.Position = UDim2.fromOffset(LEFT_W + Theme.SPACE.lg, 0)
    slotsHeader.Size = UDim2.fromOffset(300, 26)

    local slotsColumn = Instance.new("Frame")
    slotsColumn.Name = "Slots"
    slotsColumn.BackgroundTransparency = 1
    slotsColumn.Position = UDim2.fromOffset(LEFT_W + Theme.SPACE.lg, 52)
    slotsColumn.Size = UDim2.new(1, -LEFT_W - Theme.SPACE.lg, 0, 5 * 92)
    slotsColumn.ZIndex = Z + 2
    slotsColumn.Parent = body

    for i = 1, 5 do -- 3 libere + 2 blocate: sloturile blocate se vad, ca sa fie un motiv sa cresti
        slotFrames[i] = buildSlotCard(slotsColumn, i, (i - 1) * 92)
    end

    -- bara de jos: doua cifre care conteaza
    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.BackgroundTransparency = 1
    footer.Position = UDim2.new(0, 0, 1, -46)
    footer.Size = UDim2.new(1, 0, 0, 46)
    footer.ZIndex = Z + 2
    footer.Parent = body
    local footerLayout = Instance.new("UIListLayout")
    footerLayout.FillDirection = Enum.FillDirection.Horizontal
    footerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    footerLayout.Padding = UDim.new(0, Theme.SPACE.md)
    footerLayout.Parent = footer

    local foundChip, foundText = Widgets.Chip(footer, "crate", Z + 3)
    foundChip.LayoutOrder = 1
    foundChip.BackgroundTransparency = 0.85
    foundText.TextColor3 = Theme.COLOR.ink
    foundValue = foundText

    local repChip, repValue = Widgets.Chip(footer, "check", Z + 3)
    repChip.LayoutOrder = 2
    repChip.BackgroundTransparency = 0.85
    repValue.TextColor3 = Theme.COLOR.ink
    repairedValue = repValue

    local footerHint =
        Widgets.Label(footer, "found  ·  repaired", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    footerHint.LayoutOrder = 3
    footerHint.Size = UDim2.fromOffset(220, 20)

    deps.Remotes.WorkshopState.OnClientEvent:Connect(function(s: { [string]: any })
        state = s
        serverOffset = (s.now or os.time()) - os.time()
        rebuildPile()
        refreshSlots()
    end)
    deps.Remotes.WorkshopRejected.OnClientEvent:Connect(function(reason: string)
        deps.OnToast(`Workshop: {reason}`)
    end)
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc >= 1 and panel.Visible then
            acc = 0
            refreshSlots()
        end
    end)
    local _ = Workspace
end

return WorkshopController
