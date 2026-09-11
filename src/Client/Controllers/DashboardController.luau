--!strict
-- Tabloul coloniei: tot ce trebuie sa stie administratorul, intr-un singur loc [RIVERKEEP 5].
--
-- Corpul e o lista care se deruleaza, cu sectiuni asezate una sub alta. Varianta veche calcula
-- pozitii pe verticala de mana si orice text mai lung iesea din panou sau se suprapunea peste
-- randul urmator. Aici nu mai exista aritmetica de asezare, deci nu mai exista nici clasa aia
-- de erori.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)
local SettlerConfig = require(ReplicatedStorage.Shared.Config.SettlerConfig)
local Panels = require(script.Parent.Panels)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DashboardController = {}
local panel: Frame
local body: ScrollingFrame
local open = false
local latest: { [string]: any } = {}
local latestGoals: { { [string]: any } } = {}

local PANEL_W, PANEL_H = 440, 740
local Z = 35

local NEED_COLORS: { [string]: Color3 } = {
    fed = Theme.COLOR.warn,
    rested = Theme.COLOR.cool,
    content = Theme.COLOR.good,
}
local NEED_ICONS: { [string]: string } = { fed = "food", rested = "rest", content = "joy" }

local lines: { [string]: TextLabel } = {}
local bars: { [string]: Frame } = {}
local jobLabels: { [string]: TextLabel } = {}
local goalRows: { TextLabel } = {}
local logTitles: { TextLabel } = {}
local logBodies: { TextLabel } = {}

local function setIfChanged(inst: Instance, prop: string, value: any)
    local target = inst :: any
    if target[prop] ~= value then
        target[prop] = value
    end
end

-- O sectiune: titlu mic cu majuscule si un cadru care creste dupa continut
local function section(title: string, order: number): Frame
    local header = Widgets.Label(body, title, Theme.TEXT.tiny, Theme.COLOR.wood, "strong")
    header.Size = UDim2.new(1, -16, 0, 18)
    header.LayoutOrder = order
    header.ZIndex = Z + 2

    local holder = Instance.new("Frame")
    holder.Name = title
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1, -16, 0, 0)
    holder.AutomaticSize = Enum.AutomaticSize.Y
    holder.LayoutOrder = order + 1
    holder.ZIndex = Z + 2
    holder.Parent = body
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = holder
    return holder
end

local function line(
    parent: Instance,
    key: string,
    size: number,
    color: Color3,
    kind: string,
    order: number
): TextLabel
    local l = Widgets.Label(parent, "", size, color, kind)
    -- Corpul e o lista care taie ce iese din ea. Fara incadrare, tocmai liniile care conteaza
    -- cand colonia merge prost (bilantul de hrana, avertismentul) raman fara coada.
    l.Size = UDim2.new(1, 0, 0, size + 7)
    l.AutomaticSize = Enum.AutomaticSize.Y
    l.TextWrapped = true
    l.LayoutOrder = order
    l.ZIndex = Z + 3
    lines[key] = l
    return l
end

function DashboardController.Toggle()
    if panel == nil then
        return
    end
    if not open and not Panels.CanOpen("colony") then
        return
    end
    open = not open
    if open then
        Panels.CloseOthers("colony")
    end
    panel.Visible = true
    local goal = if open then -PANEL_W - Theme.SPACE.lg - 86 else 20
    local slide = TweenService:Create(
        panel,
        TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Position = UDim2.new(1, goal, 0.5, 0) }
    )
    slide:Play()
    if not open then
        task.delay(0.26, function()
            if not open then
                panel.Visible = false
            end
        end)
    end
end

function DashboardController.IsOpen(): boolean
    return open
end

function DashboardController.Close()
    if open then
        DashboardController.Toggle()
    end
end

local function apply(s: { [string]: any })
    latest = s
    local pop, beds = s.population or 0, s.beds or 0
    local free = beds - pop
    setIfChanged(lines.population, "Text", `{pop} people   ·   {beds} beds`)
    setIfChanged(
        lines.beds,
        "Text",
        if free > 0
            then `{free} beds free — newcomers can arrive`
            elseif free == 0 then "Every bed is taken"
            else `{-free} people without a bed`
    )
    setIfChanged(lines.beds, "TextColor3", if free > 0 then Theme.COLOR.good else Theme.COLOR.warn)

    setIfChanged(
        lines.stock,
        "Text",
        `{s.food or 0}/{s.foodCap or 0} food   ·   {s.materials or 0} materials   ·   {s.pile or 0} in the pile`
    )
    local byKind = s.byKind or {}
    setIfChanged(
        lines.builds,
        "Text",
        `{s.buildingsDone or 0} built, {s.buildingSites or 0} going up   ·   beds {byKind.rest or 0}, food {byKind.food or 0}, joy {byKind.joy or 0}, work {byKind.work or 0}, farm {byKind.farm or 0}`
    )

    local inFood, outFood = s.foodIn or 0, s.foodOut or 0
    local net = inFood - outFood
    setIfChanged(
        lines.balance,
        "Text",
        string.format("%+.1f food per minute   (in %.1f, out %.1f)", net, inFood, outFood)
    )
    setIfChanged(
        lines.balance,
        "TextColor3",
        if net >= 0 then Theme.COLOR.good else Theme.COLOR.bad
    )
    setIfChanged(lines.supported, "Text", `Your producers can feed about {s.supported or 0} people`)

    local unhappy = s.unhappy or 0
    setIfChanged(
        lines.alert,
        "Text",
        if s.hungry == true
            then "Food ran out — put people on Fisher or Gardener"
            elseif unhappy > 0 then `{unhappy} people need attention`
            else "Nobody is struggling"
    )
    setIfChanged(
        lines.alert,
        "TextColor3",
        if s.hungry == true or unhappy > 0 then Theme.COLOR.bad else Theme.COLOR.good
    )

    local averages = s.averages or {}
    for _, need in SettlerConfig.NEEDS do
        local value = averages[need.id] or 100
        local fill = bars[need.id]
        if fill ~= nil then
            fill.Size = UDim2.fromScale(math.clamp(value / 100, 0, 1), 1)
        end
        local label = lines[`need_{need.id}`]
        if label ~= nil then
            setIfChanged(label, "Text", `{need.label}   {value}`)
        end
    end

    local byJob = s.byJob or {}
    for _, job in SettlerConfig.JOBS do
        local l = jobLabels[job]
        if l ~= nil then
            setIfChanged(l, "Text", `{byJob[job] or 0}  {job}`)
        end
    end

    for i, row in goalRows do
        local g = latestGoals[i]
        if g == nil then
            setIfChanged(row, "Text", "")
        else
            setIfChanged(row, "Text", `{g.title}   —   {g.have}/{g.target}`)
        end
    end

    local scale = s.timeScale or 1
    local suffix = if scale > 1 then `   (time ×{scale})` else ""
    setIfChanged(lines.nextEvent, "Text", `Next event in {s.nextEvent or 0}s{suffix}`)

    local log = s.log or {}
    for i, title in logTitles do
        local entry = log[i]
        if entry == nil then
            setIfChanged(title, "Text", "")
            setIfChanged(logBodies[i], "Text", "")
        else
            local tone = EventConfig.TONES[entry.tone] or EventConfig.TONES.neutral
            setIfChanged(title, "Text", entry.title)
            setIfChanged(title, "TextColor3", Color3.fromRGB(tone[1], tone[2], tone[3]))
            setIfChanged(
                logBodies[i],
                "Text",
                if entry.detail ~= "" then entry.detail else entry.body
            )
        end
    end
end

function DashboardController.Init(deps: {
    HudGui: Frame,
    ColonyStats: RemoteEvent,
    RequestColony: RemoteEvent,
    ObjectiveState: RemoteEvent,
})
    local root, content = Widgets.Window(deps.HudGui, {
        name = "Dashboard",
        title = "The colony",
        icon = "colony",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = DashboardController.Close,
    })
    root.AnchorPoint = Vector2.new(0, 0.5)
    root.Position = UDim2.new(1, 20, 0.5, 0)
    root.Visible = false
    panel = root

    body = Widgets.List(content, Z + 1, 10)
    local holder = body.Parent :: Frame
    holder.Position = UDim2.fromOffset(0, 0)
    holder.Size = UDim2.fromScale(1, 1)

    local settlement = section("SETTLEMENT", 1)
    line(settlement, "population", Theme.TEXT.heading, Theme.COLOR.ink, "display", 1)
    line(settlement, "beds", Theme.TEXT.small, Theme.COLOR.good, "body", 2)
    line(settlement, "stock", Theme.TEXT.small, Theme.COLOR.inkSoft, "body", 3)
    local builds = line(settlement, "builds", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body", 4)
    builds.TextWrapped = true
    builds.Size = UDim2.new(1, 0, 0, 34)

    local food = section("FOOD", 3)
    line(food, "balance", Theme.TEXT.body, Theme.COLOR.good, "strong", 1)
    line(food, "supported", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body", 2)
    line(food, "alert", Theme.TEXT.small, Theme.COLOR.good, "strong", 3)

    local needs = section("AVERAGE NEEDS", 5)
    for i, need in SettlerConfig.NEEDS do
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1, 0, 0, 22)
        row.LayoutOrder = i
        row.ZIndex = Z + 3
        row.Parent = needs

        local ico = Widgets.Icon(row, NEED_ICONS[need.id] or "joy", 18)
        if ico ~= nil then
            ico.Position = UDim2.fromOffset(0, 2)
            ico.ZIndex = Z + 4
        end
        local label = Widgets.Label(row, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
        label.Position = UDim2.fromOffset(24, 2)
        label.Size = UDim2.fromOffset(110, 18)
        label.ZIndex = Z + 4
        lines[`need_{need.id}`] = label

        local track, fill = Widgets.Bar(row, 220, 12, NEED_COLORS[need.id], Z + 4)
        track.Position = UDim2.fromOffset(140, 5)
        bars[need.id] = fill
    end

    local trades = section("TRADES", 7)
    local grid = Instance.new("Frame")
    grid.BackgroundTransparency = 1
    grid.Size = UDim2.fromScale(1, 0)
    grid.AutomaticSize = Enum.AutomaticSize.Y
    grid.ZIndex = Z + 3
    grid.Parent = trades
    local gridLayout = Instance.new("UIGridLayout")
    -- 176*2 + 8 = 360, incape in cei 368 px utili; la 184 intra o singura coloana
    gridLayout.CellSize = UDim2.fromOffset(176, 24)
    gridLayout.CellPadding = UDim2.fromOffset(8, 6)
    gridLayout.Parent = grid
    for i, job in SettlerConfig.JOBS do
        local l = Widgets.Label(grid, "", Theme.TEXT.small, Theme.COLOR.ink, "body")
        l.Size = UDim2.fromOffset(176, 24)
        l.LayoutOrder = i
        l.ZIndex = Z + 4
        jobLabels[job] = l
    end

    local aims = section("WHAT TO AIM FOR", 9)
    for i = 1, 4 do
        local l = Widgets.Label(aims, "", Theme.TEXT.small, Theme.COLOR.ink, "body")
        l.Size = UDim2.new(1, 0, 0, 22)
        l.LayoutOrder = i
        l.ZIndex = Z + 4
        goalRows[i] = l
    end

    local happened = section("WHAT HAPPENED", 11)
    for i = 1, 4 do
        local card = Instance.new("Frame")
        card.BackgroundTransparency = 1
        card.Size = UDim2.new(1, 0, 0, 40)
        card.LayoutOrder = i
        card.ZIndex = Z + 3
        card.Parent = happened

        local title = Widgets.Label(card, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
        title.Size = UDim2.new(1, 0, 0, 20)
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.ZIndex = Z + 4
        logTitles[i] = title

        local detail = Widgets.Label(card, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
        detail.Position = UDim2.fromOffset(0, 19)
        detail.Size = UDim2.new(1, 0, 0, 18)
        detail.TextTruncate = Enum.TextTruncate.AtEnd
        detail.ZIndex = Z + 4
        logBodies[i] = detail
    end

    local footer = section("NEXT", 13)
    line(footer, "nextEvent", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body", 1)

    Panels.Register("colony", {
        isOpen = DashboardController.IsOpen,
        close = DashboardController.Close,
    })

    deps.ColonyStats.OnClientEvent:Connect(function(s: { [string]: any })
        apply(s)
    end)
    deps.ObjectiveState.OnClientEvent:Connect(function(state: { [string]: any })
        latestGoals = state.goals or {}
        if next(latest) ~= nil then
            apply(latest)
        end
    end)

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed then
            return
        end
        if input.KeyCode == Enum.KeyCode.C then
            DashboardController.Toggle()
            if open then
                deps.RequestColony:FireServer()
            end
        end
    end)
    deps.RequestColony:FireServer()
end

function DashboardController.Latest(): { [string]: any }
    return latest
end

return DashboardController
