--!strict
-- [D70, pasul k9] FILMUL BARAJULUI, dupa ridicare (O1: 15–20 s, Skip de la secunda 3 la prima vizionare). Cronologia e
-- in DamMath.FILM / `frameAt` (pura, testata); aici doar se deseneaza: benzile negre, textul fiecarei faze, camera care trece
-- peste satul tau de la Wire Works la Landing, amurgul, cartonasul „THE DAM”. Mersul se opreste, panourile se inchid, HUD-ul
-- se stinge. Cu „miscare redusa” (GuiService.ReducedMotionEnabled) camera sare, nu aluneca.
--
-- PROVIZORIU: siluetele la apus, schelele si barajul care creste vin cu arta lotului A2 (planse, aprobarea owner-ului, apoi
-- urcarea). Pana atunci fazele „people” si „build” sunt amurgul peste satul adevarat, cu textul lor.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DamMath = require(ReplicatedStorage.Shared.Modules.DamMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

local DamFilm = {}

export type Deps = {
    SetHudVisible: (boolean) -> (),
}
local deps: Deps? = nil

local gui: ScreenGui
local topBar: Frame
local bottomBar: Frame
local dusk: Frame
local caption: TextLabel
local card: Frame
local cardTitle: TextLabel
local cardSub: TextLabel
local skipButton: TextButton

local playing = false
local startedAt = 0
local seenBefore = false
local onDone: (() -> ())? = nil
local lastPhase = ""
local reduced = false

-- unde trece camera: de la mijlocul ultimului cartier al satului (Wire Works) la primul (Landing), pe strada
local function panPoint(pan: number): (number, number)
    local districts = TycoonConfig.districtsOf(1)
    local first, last = districts[1].deck, districts[#districts].deck
    local eastX, westX = (last.x0 + last.x1) / 2, (first.x0 + first.x1) / 2
    local origin = TycoonConfig.PLOT_ORIGIN
    return origin.x + eastX + (westX - eastX) * pan, origin.y + 1100
end

local panNow = 0
local function focusGetter(): (number?, number?)
    if not playing then
        return nil, nil
    end
    return panPoint(panNow)
end

local function finish()
    if not playing then
        return
    end
    playing = false
    -- cartonasul ramane pe ecran: urmeaza reincarcarea (k8), cu acelasi cartonas ca TeleportGui
    card.Visible = true
    card.BackgroundTransparency = 0
    skipButton.Visible = false
    CameraController.ReleaseFocus(focusGetter)
    local done = onDone
    onDone = nil
    if done ~= nil then
        done()
    end
end

local function render(t: number)
    local frame = DamMath.frameAt(t, seenBefore, reduced)
    local barH = 0.12 * frame.bars
    topBar.Size = UDim2.fromScale(1, barH)
    bottomBar.Size = UDim2.fromScale(1, barH)
    panNow = frame.pan
    -- amurgul: se lasa in „people”, ramane in „build”
    local duskAmount = if frame.phase == "people"
        then frame.progress
        elseif frame.phase == "build" or frame.phase == "card" then 1
        else 0
    dusk.BackgroundTransparency = 1 - 0.45 * duskAmount
    local isCard = frame.phase == "card"
    card.Visible = isCard
    card.BackgroundTransparency = if reduced then 0 else 1 - math.clamp(frame.progress * 3, 0, 1)
    caption.Visible = not isCard and frame.text ~= nil
    caption.Text = if not isCard then frame.text or "" else ""
    skipButton.Visible = frame.skip and not frame.done
    if frame.phase ~= lastPhase then
        lastPhase = frame.phase
        if frame.phase == "bells" then
            SoundController.Play("bell")
        elseif frame.phase == "card" then
            SoundController.Play("chime")
        end
    end
    if frame.done then
        finish()
    end
end

-- Porneste filmul. `seen`: s-a mai vazut (Skip de la inceput). `done`: la capat sau la Skip (reincarcarea, k8).
function DamFilm.Play(seen: boolean, done: () -> ())
    if playing then
        return
    end
    local ok, value = pcall(function()
        return GuiService.ReducedMotionEnabled
    end)
    reduced = ok and value == true
    seenBefore = seen
    onDone = done
    playing = true
    startedAt = os.clock()
    lastPhase = ""
    Panels.CloseAll()
    CharacterController.SetLocked(true)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(false)
    end
    gui.Enabled = true
    card.Visible = false
    CameraController.SetFocus(focusGetter)
    render(0)
end

function DamFilm.Skip()
    if playing then
        finish()
    end
end

-- [D70, pasul k9] sonda din Studio: sare la secunda `t` a filmului (`cinematic:seek:<t>`), ca textele fiecarei faze sa se
-- poata citi fara sa astepti.
function DamFilm.Seek(t: number)
    if playing then
        startedAt = os.clock() - math.max(0, t)
    end
end

function DamFilm.IsPlaying(): boolean
    return playing
end

-- Reincarcarea n-a plecat (Studio, un drum esuat): filmul se ridica, ca ecranul barajului sa spuna ce urmeaza.
function DamFilm.Stop()
    playing = false
    onDone = nil
    gui.Enabled = false
    CameraController.ReleaseFocus(focusGetter)
    CharacterController.SetLocked(false)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(true)
    end
end

function DamFilm.Init(d: Deps)
    deps = d
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
    gui = Instance.new("ScreenGui")
    gui.Name = "DamFilm"
    gui.IgnoreGuiInset = true
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 60
    gui.Enabled = false
    gui.Parent = playerGui

    dusk = Instance.new("Frame")
    dusk.Name = "Dusk"
    dusk.Size = UDim2.fromScale(1, 1)
    dusk.BackgroundColor3 = Color3.fromRGB(70, 34, 52)
    dusk.BackgroundTransparency = 1
    dusk.BorderSizePixel = 0
    dusk.ZIndex = 1
    dusk.Parent = gui

    local function bar(name: string, anchorY: number): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.AnchorPoint = Vector2.new(0, anchorY)
        f.Position = UDim2.fromScale(0, anchorY)
        f.Size = UDim2.fromScale(1, 0)
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 2
        f.Parent = gui
        return f
    end
    topBar = bar("TopBar", 0)
    bottomBar = bar("BottomBar", 1)

    caption = Widgets.Label(gui, "", Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    caption.AnchorPoint = Vector2.new(0.5, 1)
    caption.Position = UDim2.new(0.5, 0, 1, -24)
    caption.Size = UDim2.new(0.9, 0, 0, 36)
    caption.TextXAlignment = Enum.TextXAlignment.Center
    caption.TextScaled = true
    caption.ZIndex = 3
    Theme.punch(caption, 2)

    card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.fromScale(1, 1)
    card.BackgroundColor3 = Color3.new(0, 0, 0)
    card.BorderSizePixel = 0
    card.Visible = false
    card.ZIndex = 4
    card.Parent = gui
    -- ca ecranul de incarcare si cartonasul drumului (DamScreen): fontul de pixeli, scalat
    cardTitle = Instance.new("TextLabel")
    cardTitle.AnchorPoint = Vector2.new(0.5, 0.5)
    cardTitle.Position = UDim2.fromScale(0.5, 0.46)
    cardTitle.Size = UDim2.fromScale(0.8, 0.12)
    cardTitle.BackgroundTransparency = 1
    cardTitle.TextColor3 = Color3.fromRGB(240, 233, 218)
    cardTitle.Font = Enum.Font.Arcade
    cardTitle.TextScaled = true
    cardTitle.Text = Strings.DAM_CARD_TITLE
    cardTitle.ZIndex = 5
    cardTitle.Parent = card
    cardSub = cardTitle:Clone()
    cardSub.Position = UDim2.fromScale(0.5, 0.58)
    cardSub.Size = UDim2.fromScale(0.8, 0.04)
    cardSub.TextColor3 = Color3.fromRGB(196, 186, 168)
    cardSub.Text = Strings.DAM_CARD_SUB
    cardSub.Parent = card

    skipButton = Widgets.Button(gui, {
        text = Strings.DAM_FILM_SKIP,
        width = 140,
        height = 48,
        z = 6,
        onClick = DamFilm.Skip,
    })
    skipButton.AnchorPoint = Vector2.new(1, 1)
    skipButton.Position = UDim2.new(1, -24, 1, -24)
    skipButton.Visible = false

    RunService.RenderStepped:Connect(function()
        if playing then
            render(os.clock() - startedAt)
        end
    end)
end

return DamFilm
