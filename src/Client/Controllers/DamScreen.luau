--!strict
-- [D70, pasul k7] ECRANUL „BUILD THE DAM” (PLAN-HARTA §2 pasul 4, §3). Il deschide masa Dam Plans, cu barajul in joc si gata
-- de ridicat (k6). Trei coloane cu cifrele tale de la server (DamController: chitanta din DamMath.preview, scrisa de
-- DamWords): ce ramane cu tine, ce devine barajul, ce castigi. „Not yet” inchide fara nicio urmare; „Build the Dam” se tine
-- apasat 1,5 s (Widgets.HoldButton), apoi serverul ridica totul dintr-o bucata si salveaza.
--
-- Cat se salveaza, ecranul scrie „Saving…” si butonul nu mai raspunde. Refuzul vine pe randul de jos (prin DamController, `OnRejected`):
-- „changed” aduce o chitanta noua (o cere DamController), „save” nu ofera „Try again” (barajul e ridicat in memorie). Dupa
-- ridicare, clientul ingheata (garda lumii, k1) pana la reincarcarea in lumea 2 (k8); ecranul spune ca barajul e ridicat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local DamWords = require(ReplicatedStorage.Shared.Modules.DamWords)

local DamController = require(script.Parent.DamController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DamScreen = {}

local WIDTH, HEIGHT = 640, 540
local Z = 140
local HOLD_SECONDS = 1.5
local BUTTON_H = 48
local STATUS_H = 40
local GAP = Theme.SPACE.md

local window: Frame? = nil
local scroll: ScrollingFrame
local columnsFrame: Frame
local columnsLayout: UIListLayout
local columnViews: { { frame: Frame, title: TextLabel, rows: { TextLabel } } } = {}
local status: TextLabel
local notYet: TextButton
local hold: Widgets.HoldButton
-- "counting" (asteapta chitanta) | "ready" | "saving" | "done" (ridicat) | "refused" (fara chitanta buna) | "opening"
-- (se reincarca in lumea 2) | "stuck" (reincarcarea n-a plecat: „Try again”, afara de Studio)
local phase = "counting"
-- [D70, pasul k8] cat dureaza „The Dam is built!” inainte de reincarcare (filmul il inlocuieste la k9)
local OPEN_AFTER = 1.5

local function isOpen(): boolean
    local w = window
    return w ~= nil and w.Visible
end

function DamScreen.IsOpen(): boolean
    return isOpen()
end

function DamScreen.Close()
    local w = window
    if w ~= nil and phase ~= "saving" and phase ~= "opening" then
        w.Visible = false
    end
end

local function setStatus(text: string, color: Color3?)
    status.Text = text
    status.TextColor3 = color or Theme.COLOR.inkSoft
end

-- Coloanele una langa alta cand e loc (calculator), una sub alta pe un telefon ingust; butoanele la fel.
local function layout()
    local w = window
    if w == nil then
        return
    end
    local bodyW = w.Size.X.Offset - Theme.SPACE.lg * 2
    local wide = bodyW >= 540
    columnsLayout.FillDirection = if wide
        then Enum.FillDirection.Horizontal
        else Enum.FillDirection.Vertical
    local colW = if wide then math.floor((bodyW - GAP * 2) / 3) else bodyW
    for _, view in columnViews do
        view.frame.Size = UDim2.fromOffset(colW, 0)
        for _, row in view.rows do
            row.Size = UDim2.fromOffset(colW, 0)
        end
        view.title.Size = UDim2.fromOffset(colW, 24)
        view.title.TextSize = Theme.fitSize(view.title.Text, Theme.TEXT.body, "strong", colW)
    end
    local sideBySide = bodyW >= 200 + 8 + 240
    -- randul de jos (stare) sta chiar deasupra butoanelor: unul langa altul, sau unul sub altul
    local buttonsH = if sideBySide then BUTTON_H else BUTTON_H * 2 + 8
    status.Position = UDim2.new(0, 0, 1, -(buttonsH + Theme.SPACE.sm))
    scroll.Size = UDim2.new(1, 0, 1, -(buttonsH + STATUS_H + Theme.SPACE.sm * 2))
    if sideBySide then
        notYet.AnchorPoint = Vector2.new(0, 1)
        notYet.Position = UDim2.new(0.5, -(200 + 8 + 240) / 2, 1, 0)
        notYet.Size = UDim2.fromOffset(200, BUTTON_H)
        hold.button.AnchorPoint = Vector2.new(0, 1)
        hold.button.Position = UDim2.new(0.5, -(200 + 8 + 240) / 2 + 208, 1, 0)
        hold.button.Size = UDim2.fromOffset(240, BUTTON_H)
    else
        hold.button.AnchorPoint = Vector2.new(0.5, 1)
        hold.button.Position = UDim2.new(0.5, 0, 1, -(BUTTON_H + 8))
        hold.button.Size = UDim2.fromOffset(bodyW, BUTTON_H)
        notYet.AnchorPoint = Vector2.new(0.5, 1)
        notYet.Position = UDim2.fromScale(0.5, 1)
        notYet.Size = UDim2.fromOffset(bodyW, BUTTON_H)
    end
end

local function showColumns(receipt: DamController.Receipt?)
    local columns = if receipt ~= nil then DamWords.columns(receipt) else {}
    for i, view in columnViews do
        local column = columns[i]
        view.frame.Visible = column ~= nil
        if column ~= nil then
            view.title.Text = column.title
            for k, row in view.rows do
                local text = column.rows[k]
                row.Visible = text ~= nil
                row.Text = text or ""
            end
        end
    end
    layout()
end

local function setPhase(next: string)
    phase = next
    hold.SetEnabled(next == "ready")
    Widgets.SetButtonText(
        notYet,
        if next == "stuck"
            then Strings.DAM_TRY_AGAIN
            elseif next == "done" then Strings.DAM_CLOSE
            else Strings.DAM_NOT_YET
    )
    notYet.Visible = next ~= "saving" and next ~= "opening"
end

-- [D70, pasul k8] Cartonasul din timpul drumului (TeleportGui): negru, „THE DAM”, ramane si la sosire (Loading il pastreaza
-- pana se construieste harta noua). Fontul de pixeli, ca ecranul de incarcare.
local function travelCard(): ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "DamTravel"
    gui.IgnoreGuiInset = true
    local black = Instance.new("Frame")
    black.Size = UDim2.fromScale(1, 1)
    black.BackgroundColor3 = Color3.new(0, 0, 0)
    black.BorderSizePixel = 0
    black.Parent = gui
    local title = Instance.new("TextLabel")
    title.AnchorPoint = Vector2.new(0.5, 0.5)
    title.Position = UDim2.fromScale(0.5, 0.46)
    title.Size = UDim2.fromScale(0.8, 0.12)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(240, 233, 218)
    title.Font = Enum.Font.Arcade
    title.TextScaled = true
    title.Text = Strings.DAM_CARD_TITLE
    title.Parent = black
    local sub = title:Clone()
    sub.Position = UDim2.fromScale(0.5, 0.58)
    sub.Size = UDim2.fromScale(0.8, 0.04)
    sub.TextColor3 = Color3.fromRGB(196, 186, 168)
    sub.Text = Strings.DAM_CARD_SUB
    sub.Parent = black
    return gui
end

local function openDam()
    setPhase("opening")
    setStatus(Strings.DAM_OPENING, Theme.COLOR.inkSoft)
    pcall(function()
        TeleportService:SetTeleportGui(travelCard())
    end)
    DamController.FilmSeen()
end

-- Masa Dam Plans (E): ecranul se deschide pe „Counting…” si cere chitanta.
function DamScreen.Open()
    local w = window
    if w == nil or not Panels.CanOpen("dam") then
        return
    end
    Panels.CloseOthers("dam")
    if phase == "counting" or phase == "ready" or phase == "refused" then
        showColumns(DamController.LastPreview())
        setPhase("counting")
        setStatus(Strings.DAM_COUNTING)
    end
    w.Visible = true
    DamController.RequestPreview()
end

-- Chitanta (sau motivul pentru care nu se poate), de la DamController.
function DamScreen.OnPreview(receipt: DamController.Receipt?, why: string?)
    if phase == "saving" or phase == "done" or phase == "opening" or phase == "stuck" then
        return
    end
    if receipt ~= nil then
        showColumns(receipt)
        setPhase("ready")
        setStatus(Strings.DAM_HOLD_HINT)
    elseif why ~= nil then
        setPhase(if DamWords.canRetry(why) then "counting" else "refused")
        setStatus(Strings.damRejected(why), Theme.COLOR.badInk)
    end
end

function DamScreen.OnRejected(reason: string)
    if reason == "save" or reason == "built" then
        setPhase("done")
        setStatus(Strings.damRejected(reason), Theme.COLOR.warnInk)
        return
    end
    -- „changed”: DamController cere singur o chitanta noua; pana vine, butonul asteapta
    setPhase(if DamWords.canRetry(reason) then "counting" else "refused")
    setStatus(Strings.damRejected(reason), Theme.COLOR.badInk)
    if reason ~= "changed" and DamWords.canRetry(reason) and DamController.LastPreview() ~= nil then
        setPhase("ready")
    end
end

function DamScreen.OnBuilt(_receipt: DamController.Receipt)
    setPhase("opening")
    setStatus(Strings.DAM_BUILT, Theme.COLOR.goodInk)
    SoundController.Play("chime")
    -- [D70, pasul k8] apoi reincarcarea in lumea 2 (la k9, dupa film)
    task.delay(OPEN_AFTER, openDam)
end

-- [D70, pasul k8] Reincarcarea n-a plecat: in Studio spune ce sa faci; altfel „Try again” (aceeasi cerere).
function DamScreen.OnReloadFailed(reason: string)
    setPhase(if reason == "studio" then "done" else "stuck")
    setStatus(Strings.damReloadFailed(reason), Theme.COLOR.warnInk)
end

function DamScreen.Init(deps: { HudGui: Frame })
    local root, body = Widgets.Window(deps.HudGui, {
        name = "DamScreen",
        title = Strings.DAM_SCREEN_TITLE,
        icon = "hammer",
        width = WIDTH,
        height = HEIGHT,
        z = Z,
        onClose = DamScreen.Close,
    })
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.Visible = false
    window = root
    Panels.Register("dam", { isOpen = isOpen, close = DamScreen.Close })

    -- coloanele, intr-o lista care se deruleaza cand nu incap (telefonul ingust le pune una sub alta)
    scroll = Instance.new("ScrollingFrame")
    scroll.Name = "Columns"
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.Size = UDim2.new(1, 0, 1, -(BUTTON_H * 2 + 8 + STATUS_H + Theme.SPACE.sm * 2))
    scroll.CanvasSize = UDim2.fromOffset(0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.ScrollBarThickness = 6
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.ZIndex = Z + 1
    scroll.Parent = body
    columnsFrame = Instance.new("Frame")
    columnsFrame.Name = "Row"
    columnsFrame.BackgroundTransparency = 1
    columnsFrame.Size = UDim2.fromScale(1, 0)
    columnsFrame.AutomaticSize = Enum.AutomaticSize.Y
    columnsFrame.ZIndex = Z + 1
    columnsFrame.Parent = scroll
    columnsLayout = Instance.new("UIListLayout")
    columnsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    columnsLayout.Padding = UDim.new(0, GAP)
    columnsLayout.Parent = columnsFrame
    for i = 1, 3 do
        local frame = Instance.new("Frame")
        frame.Name = `Column{i}`
        frame.BackgroundTransparency = 1
        frame.AutomaticSize = Enum.AutomaticSize.Y
        frame.LayoutOrder = i
        frame.ZIndex = Z + 1
        frame.Parent = columnsFrame
        local stack = Instance.new("UIListLayout")
        stack.SortOrder = Enum.SortOrder.LayoutOrder
        stack.Padding = UDim.new(0, Theme.SPACE.xs + 2)
        stack.Parent = frame
        local title = Widgets.Label(frame, "", Theme.TEXT.body, Theme.COLOR.gold, "strong")
        title.LayoutOrder = 0
        title.ZIndex = Z + 2
        local rows: { TextLabel } = {}
        for k = 1, 5 do
            local row = Widgets.Label(frame, "", Theme.TEXT.small, Theme.COLOR.ink, "body")
            row.TextWrapped = true
            row.AutomaticSize = Enum.AutomaticSize.Y
            row.LayoutOrder = k
            row.ZIndex = Z + 2
            row.Visible = false
            rows[k] = row
        end
        columnViews[i] = { frame = frame, title = title, rows = rows }
    end

    status = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.inkSoft, "body")
    status.TextWrapped = true
    status.TextXAlignment = Enum.TextXAlignment.Center
    status.AnchorPoint = Vector2.new(0, 1)
    status.Position = UDim2.new(0, 0, 1, -(BUTTON_H * 2 + 8 + Theme.SPACE.sm))
    status.Size = UDim2.new(1, 0, 0, STATUS_H)
    status.ZIndex = Z + 1

    notYet = Widgets.Button(body, {
        text = Strings.DAM_NOT_YET,
        width = 200,
        height = BUTTON_H,
        z = Z + 1,
        onClick = function()
            SoundController.Play("click")
            if phase == "stuck" then
                openDam() -- [D70, pasul k8] „Try again”
                return
            end
            DamScreen.Close()
        end,
    })
    hold = Widgets.HoldButton(body, {
        text = Strings.DAM_HOLD,
        width = 240,
        height = BUTTON_H,
        z = Z + 1,
        seconds = HOLD_SECONDS,
        onDone = function()
            if phase ~= "ready" then
                return
            end
            if DamController.Build() then
                setPhase("saving")
                setStatus(Strings.DAM_SAVING)
            end
        end,
    })
    setPhase("counting")
    root:GetPropertyChangedSignal("Size"):Connect(layout)
    layout()
end

return DamScreen
