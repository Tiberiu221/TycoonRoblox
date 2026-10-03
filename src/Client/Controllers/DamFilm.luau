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

local gui: ScreenGui -- de la margine la margine (ScreenInsets.None): amurgul, benzile, cartonasul
local safeGui: ScreenGui -- in zona sigura a telefonului: Skip nu ajunge sub crestatura sau sub bara de jos
local stage: Frame
local topBar: Frame
local bottomBar: Frame
local dusk: Frame
local caption: TextLabel
local card: Frame? = nil -- nil cat Init n-a ajuns la capat: Play nu blocheaza nimic atunci
local cardTitle: TextLabel
local cardSub: TextLabel
local skipButton: TextButton

local SKIP_W, SKIP_H, EDGE = 120, 40, 16
-- [verificatorul k9-k10a] cartonasul singur (filmul pierdut la o iesire): cat sta, apoi cat se ridica peste harta noua
local CARD_HOLD, CARD_FADE = 3, 1
local cardOnly = false
local cardDone: (() -> ())? = nil

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

-- Cartonasul „THE DAM”: fundalul si textele apar impreuna din negru (`a` = cat de transparente sunt).
local function cardAlpha(a: number)
    local c = card
    if c == nil then
        return
    end
    c.BackgroundTransparency = a
    cardTitle.TextTransparency = a
    cardSub.TextTransparency = a
end

local function finish()
    if not playing then
        return
    end
    playing = false
    -- cartonasul ramane pe ecran: urmeaza reincarcarea (k8), cu acelasi cartonas ca TeleportGui
    local c = card
    if c ~= nil then
        c.Visible = true
    end
    cardAlpha(0)
    skipButton.Visible = false
    caption.Visible = false
    CameraController.ReleaseFocus(focusGetter)
    local done = onDone
    onDone = nil
    if done ~= nil then
        done()
    end
end

-- [verificatorul k9-k10a] Textul sta in mijlocul benzii de jos si nu ajunge niciodata la Skip: e centrat, iar jumatatea lui
-- se opreste la 8 px de marginea din stanga a butonului (ambele ScreenGui au originea in coltul ecranului).
local function placeCaption()
    local size = stage.AbsoluteSize
    local barH = bottomBar.AbsoluteSize.Y
    local h = math.clamp(barH - 6, 18, 36)
    local half = math.max(60, skipButton.AbsolutePosition.X - 8 - size.X / 2)
    caption.Size = UDim2.fromOffset(math.min(half * 2, size.X * 0.9), h)
    caption.Position = UDim2.fromOffset(size.X / 2, size.Y - barH / 2)
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
    local c = card :: Frame
    c.Visible = isCard
    -- [verificatorul k9-k10a] fundalul si textele apar impreuna din negru, nu textele intai peste sat
    cardAlpha(if reduced then 0 else 1 - math.clamp(frame.progress * 3, 0, 1))
    caption.Visible = not isCard and frame.text ~= nil
    caption.Text = if not isCard then frame.text or "" else ""
    placeCaption()
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

local function enter()
    Panels.CloseAll()
    CharacterController.SetLocked(true)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(false)
    end
    gui.Enabled = true
    safeGui.Enabled = true
end

local function leave()
    gui.Enabled = false
    safeGui.Enabled = false
    CameraController.ReleaseFocus(focusGetter)
    CharacterController.SetLocked(false)
    local d = deps
    if d ~= nil then
        d.SetHudVisible(true)
    end
end

-- Porneste filmul. `seen`: s-a mai vazut (Skip de la inceput). `done`: la capat sau la Skip (reincarcarea, k8).
-- [verificatorul k9-k10a] Daca desenul filmului n-a putut fi facut (Init a cazut), nu se blocheaza nimic: `done` pleaca
-- direct, ca barajul ridicat sa duca totusi in lumea 2.
function DamFilm.Play(seen: boolean, done: () -> ())
    if playing or cardOnly then
        return
    end
    local c = card
    if c == nil then
        done()
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
    enter()
    c.Visible = false
    CameraController.SetFocus(focusGetter)
    render(0)
end

-- [verificatorul k9-k10a] FILMUL PIERDUT: ai iesit din joc in cele 17 s, iar barajul era deja ridicat si salvat. La prima
-- intrare la baraj, doar cartonasul „THE DAM / Your people built this” (filmul are nevoie de satul vechi), care se ridica
-- peste harta noua. `done`: dupa ce s-a vazut (serverul noteaza filmul, ca sa nu mai vina).
function DamFilm.PlayCard(done: () -> ())
    local c = card
    if playing or cardOnly or c == nil then
        done()
        return
    end
    cardOnly = true
    cardDone = done
    startedAt = os.clock()
    enter()
    topBar.Size = UDim2.fromScale(1, 0)
    bottomBar.Size = UDim2.fromScale(1, 0)
    dusk.BackgroundTransparency = 1
    caption.Visible = false
    skipButton.Visible = false
    c.Visible = true
    cardAlpha(0)
    SoundController.Play("chime")
end

local function renderCard(t: number)
    if t < CARD_HOLD then
        return
    end
    cardAlpha(math.clamp((t - CARD_HOLD) / CARD_FADE, 0, 1))
    if t >= CARD_HOLD + CARD_FADE then
        cardOnly = false
        local c = card
        if c ~= nil then
            c.Visible = false
        end
        leave()
        local done = cardDone
        cardDone = nil
        if done ~= nil then
            done()
        end
    end
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
    return playing or cardOnly
end

-- Reincarcarea n-a plecat (Studio, un drum esuat): filmul se ridica, ca ecranul barajului sa spuna ce urmeaza.
function DamFilm.Stop()
    playing = false
    onDone = nil
    cardOnly = false
    cardDone = nil
    if gui ~= nil then
        leave()
    end
end

function DamFilm.Init(d: Deps)
    deps = d
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
    local function screen(name: string, order: number, insets: Enum.ScreenInsets): ScreenGui
        local g = Instance.new("ScreenGui")
        g.Name = name
        g.IgnoreGuiInset = true
        g.ScreenInsets = insets
        g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        g.ResetOnSpawn = false
        g.DisplayOrder = order
        g.Enabled = false
        g.Parent = playerGui
        return g
    end
    -- [verificatorul k9-k10a] de la margine la margine, ca tutorialul si cartonasul drumului (RideScene): altfel pe
    -- telefonul cu crestatura ramane o fasie de sat luminat langa cartonasul negru
    gui = screen("DamFilm", 60, Enum.ScreenInsets.None)
    safeGui = screen("DamFilmControls", 61, Enum.ScreenInsets.DeviceSafeInsets)

    -- un Frame radacina: Widgets citeste ZIndex-ul parintelui, iar un ScreenGui n-are (aici cadea Init-ul inainte)
    local function root(parent: ScreenGui, name: string): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.Size = UDim2.fromScale(1, 1)
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.ZIndex = 1
        f.Parent = parent
        return f
    end
    stage = root(gui, "Stage")
    local controls = root(safeGui, "Controls")

    dusk = Instance.new("Frame")
    dusk.Name = "Dusk"
    dusk.Size = UDim2.fromScale(1, 1)
    dusk.BackgroundColor3 = Color3.fromRGB(70, 34, 52)
    dusk.BackgroundTransparency = 1
    dusk.BorderSizePixel = 0
    dusk.ZIndex = 1
    dusk.Parent = stage

    local function bar(name: string, anchorY: number): Frame
        local f = Instance.new("Frame")
        f.Name = name
        f.AnchorPoint = Vector2.new(0, anchorY)
        f.Position = UDim2.fromScale(0, anchorY)
        f.Size = UDim2.fromScale(1, 0)
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 2
        f.Parent = stage
        return f
    end
    topBar = bar("TopBar", 0)
    bottomBar = bar("BottomBar", 1)

    caption = Widgets.Label(stage, "", Theme.TEXT.heading, Theme.COLOR.onDark, "display")
    caption.AnchorPoint = Vector2.new(0.5, 0.5)
    caption.TextXAlignment = Enum.TextXAlignment.Center
    caption.TextScaled = true
    caption.ZIndex = 3
    Theme.punch(caption, 2)

    local c = Instance.new("Frame")
    c.Name = "Card"
    c.Size = UDim2.fromScale(1, 1)
    c.BackgroundColor3 = Color3.new(0, 0, 0)
    c.BorderSizePixel = 0
    c.Visible = false
    c.ZIndex = 4
    c.Parent = stage
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
    cardTitle.Parent = c
    cardSub = cardTitle:Clone()
    cardSub.Position = UDim2.fromScale(0.5, 0.58)
    cardSub.Size = UDim2.fromScale(0.8, 0.04)
    cardSub.TextColor3 = Color3.fromRGB(196, 186, 168)
    cardSub.Text = Strings.DAM_CARD_SUB
    cardSub.Parent = c

    skipButton = Widgets.Button(controls, {
        text = Strings.DAM_FILM_SKIP,
        width = SKIP_W,
        height = SKIP_H,
        z = 6,
        onClick = DamFilm.Skip,
    })
    skipButton.AnchorPoint = Vector2.new(1, 1)
    skipButton.Position = UDim2.new(1, -EDGE, 1, -EDGE)
    skipButton.Visible = false
    card = c -- abia acum: Play stie ca desenul e intreg

    RunService.RenderStepped:Connect(function()
        if playing then
            render(os.clock() - startedAt)
        elseif cardOnly then
            renderCard(os.clock() - startedAt)
        end
    end)
end

return DamFilm
