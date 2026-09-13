--!strict
-- Panoul "Sound" [D54]: nivelul muzicii si al efectelor, 0..10. Owner-ul, la intrarea in joc: "muzica
-- este prea tare, nu prea este de fundal. userul ar trebui sa poata selecta nivelul audio".
--
-- Fiecare rand: numele, "-", zece segmente aurii umplute pana la nivel (si ele se apasa), "+", "40%" /
-- "Off". Schimbarea se aude pe loc (MusicController / SoundController.SetLevel); la Sounds, un click de
-- proba la nivelul nou. Salvarea pleaca la server dupa SAVE_DELAY de liniste, SEPARAT pe fiecare canal
-- (Music si imediat Sounds nu pierde Music), iar la inchiderea panoului pleaca pe loc. Cine iese din joc
-- in cele 0,6 s de dupa o apasare, cu panoul deschis, pierde doar acea ultima apasare.
--
-- Randul Music apare doar cand exista muzica urcata: un reglaj care nu schimba nimic ar minti [D40].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local MusicController = require(script.Parent.MusicController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    HudGui: Frame,
    SetAudio: RemoteEvent,
}

type Channel = {
    kind: string, -- "music" | "sound": exact ce asteapta SetAudio pe server
    level: () -> number,
    set: (number) -> (),
    segments: { Frame },
    value: TextLabel,
    minus: TextButton,
    plus: TextButton,
    pending: number?, -- nivelul care n-a plecat inca la server
    token: number, -- o salvare programata pleaca doar daca nu a venit alta apasare intre timp
}

local AudioPanel = {}
local deps: Deps
local window: Frame
local open = false
local channels: { Channel } = {}

-- Cutiile de mai jos le verifica scripts/art/check_panel_rows.py (AUDIO_PANEL): schimbate aici,
-- schimbate si acolo. Fereastra 520 -> corpul 480; un rand are 44 si pasul intre randuri e 60.
local PANEL_W = 520
local PANEL_H_ONE_ROW = 180
local ROW_TOP, ROW_STEP = 10, 60
local NAME_W = 96
local MINUS_X, PLUS_X, VALUE_X = 104, 344, 396
local STEP_W, STEP_H = 44, 40
local SEGMENTS_X, SEGMENT_W, SEGMENT_GAP = 158, 14, 4
-- segmentele cresc spre dreapta, ca semnul de volum: de la 10 la 24, asezate pe aceeasi linie de jos
local SEGMENT_H_MIN, SEGMENT_H_MAX = 10, 24
local VALUE_W = 84
local Z = 70
local SAVE_DELAY = 0.6
local EMPTY = Color3.fromRGB(74, 58, 44) -- aceeasi urma ca Widgets.Bar
local GREY = Color3.fromRGB(150, 144, 136) -- butonul care nu mai are unde (ca in StationMenu)

local function paint(ch: Channel)
    local level = ch.level()
    for i, segment in ch.segments do
        segment.BackgroundColor3 = if i <= level then Theme.COLOR.gold else EMPTY
    end
    ch.value.Text = Strings.audioLevel(level)
    ch.value.TextColor3 = if level > 0 then Theme.COLOR.ink else Theme.COLOR.inkSoft
    Widgets.SetButtonTone(ch.minus, if level > 0 then nil else GREY)
    Widgets.SetButtonTone(ch.plus, if level < AudioLevels.MAX_LEVEL then nil else GREY)
end

local function flush(ch: Channel)
    local level = ch.pending
    ch.pending = nil
    ch.token += 1 -- salvarea deja programata nu mai are ce trimite
    if level ~= nil then
        deps.SetAudio:FireServer(ch.kind, level)
    end
end

local function scheduleSave(ch: Channel, level: number)
    ch.pending = level
    ch.token += 1
    local token = ch.token
    task.delay(SAVE_DELAY, function()
        if token == ch.token then
            flush(ch)
        end
    end)
end

local function change(ch: Channel, wanted: number)
    local level = math.clamp(wanted, 0, AudioLevels.MAX_LEVEL)
    if level == ch.level() then
        return -- butonul e deja gri: nu are unde
    end
    ch.set(level)
    paint(ch)
    if ch.kind == "sound" and level > 0 then
        SoundController.Play("click") -- proba, la nivelul tocmai ales
    end
    scheduleSave(ch, level)
end

local function buildRow(
    body: Frame,
    y: number,
    kind: string,
    label: string,
    level: () -> number,
    set: (number) -> ()
): Channel
    local name = Widgets.Label(body, label, Theme.TEXT.body, Theme.COLOR.ink, "strong")
    name.Position = UDim2.fromOffset(0, y + 10)
    name.Size = UDim2.fromOffset(NAME_W, 28)
    name.ZIndex = Z + 3

    local ch: Channel
    local minus = Widgets.Button(body, {
        text = "-",
        width = STEP_W,
        height = STEP_H,
        z = Z + 3,
        onClick = function()
            change(ch, ch.level() - 1)
        end,
    })
    minus.Position = UDim2.fromOffset(MINUS_X, y + 4)
    local plus = Widgets.Button(body, {
        text = "+",
        width = STEP_W,
        height = STEP_H,
        z = Z + 3,
        onClick = function()
            change(ch, ch.level() + 1)
        end,
    })
    plus.Position = UDim2.fromOffset(PLUS_X, y + 4)

    local value = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.ink, "strong")
    value.Position = UDim2.fromOffset(VALUE_X, y + 10)
    value.Size = UDim2.fromOffset(VALUE_W, 28)
    value.TextXAlignment = Enum.TextXAlignment.Right
    value.ZIndex = Z + 3

    ch = {
        kind = kind,
        level = level,
        set = set,
        segments = {},
        value = value,
        minus = minus,
        plus = plus,
        pending = nil,
        token = 0,
    }

    -- Fiecare segment e si buton: apasat, nivelul sare acolo. Zona de apasare are inaltimea butoanelor,
    -- desenul sta pe linia de jos a celui mai inalt segment.
    for i = 1, AudioLevels.MAX_LEVEL do
        local hit = Instance.new("TextButton")
        hit.Name = `Segment{i}`
        hit.BackgroundTransparency = 1
        hit.AutoButtonColor = false
        hit.Text = ""
        hit.Position = UDim2.fromOffset(SEGMENTS_X + (i - 1) * (SEGMENT_W + SEGMENT_GAP), y + 4)
        hit.Size = UDim2.fromOffset(SEGMENT_W, STEP_H)
        hit.ZIndex = Z + 3
        hit.Parent = body
        local h = SEGMENT_H_MIN
            + math.round((SEGMENT_H_MAX - SEGMENT_H_MIN) * (i - 1) / (AudioLevels.MAX_LEVEL - 1))
        local segment = Instance.new("Frame")
        segment.BorderSizePixel = 0
        segment.BackgroundColor3 = EMPTY
        segment.AnchorPoint = Vector2.new(0, 1)
        segment.Position = UDim2.fromOffset(0, (STEP_H - SEGMENT_H_MAX) // 2 + SEGMENT_H_MAX)
        segment.Size = UDim2.fromOffset(SEGMENT_W, h)
        segment.ZIndex = Z + 4
        segment.Parent = hit
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 3)
        corner.Parent = segment
        table.insert(ch.segments, segment)
        hit.Activated:Connect(function()
            change(ch, i)
        end)
    end
    return ch
end

function AudioPanel.IsOpen(): boolean
    return open
end

function AudioPanel.Close()
    open = false
    window.Visible = false
    for _, ch in channels do
        flush(ch) -- ce era in asteptare pleaca acum, nu dupa 0,6 s
    end
end

function AudioPanel.Open()
    Panels.CloseOthers("audio")
    open = true
    window.Visible = true
    SoundController.Play("click")
    for _, ch in channels do
        paint(ch)
    end
end

function AudioPanel.Toggle()
    if open then
        AudioPanel.Close()
    else
        AudioPanel.Open()
    end
end

-- Dupa fiecare stare: daca panoul a fost deschis inainte de prima stare, nivelurile din profil tocmai au
-- ajuns si bara trebuie sa le arate.
function AudioPanel.Refresh()
    if not open then
        return
    end
    for _, ch in channels do
        paint(ch)
    end
end

function AudioPanel.Init(d: Deps)
    deps = d
    local hasMusic = MusicController.Available()
    local rows = if hasMusic then 2 else 1
    local root, body = Widgets.Window(deps.HudGui, {
        name = "AudioPanel",
        title = Strings.AUDIO_TITLE,
        icon = "music",
        width = PANEL_W,
        height = PANEL_H_ONE_ROW + (rows - 1) * ROW_STEP,
        z = Z,
        onClose = AudioPanel.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    channels = {}
    local y = ROW_TOP
    if hasMusic then
        table.insert(
            channels,
            buildRow(
                body,
                y,
                "music",
                Strings.AUDIO_MUSIC,
                MusicController.Level,
                MusicController.SetLevel
            )
        )
        y += ROW_STEP
    end
    table.insert(
        channels,
        buildRow(
            body,
            y,
            "sound",
            Strings.AUDIO_SOUNDS,
            SoundController.Level,
            SoundController.SetLevel
        )
    )

    Panels.Register("audio", { isOpen = AudioPanel.IsOpen, close = AudioPanel.Close })
end

return AudioPanel
