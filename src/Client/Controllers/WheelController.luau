--!strict
-- Roata zilnica [D46]. Fereastra arata roata, premiile CU PROCENTELE LOR si ceasul pana la
-- urmatoarea rotire gratuita.
--
-- Procentele nu sunt scrise de mana: ies din aceleasi ponderi din care trage serverul
-- (WheelMath.percentOf) -- daca cineva schimba o pondere, cifra de pe ecran se schimba cu ea [D40].
--
-- Clientul NU trage nimic: cere rotirea, primeste premiul si abia apoi animeaza roata ca sa se
-- opreasca pe el. Asa nu exista nicio clipa in care el stie inainte, si nimic de pacalit.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local WheelMath = require(ReplicatedStorage.Shared.Modules.WheelMath)

local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Snapshot = { ready: boolean, secondsLeft: number, spins: number }

export type Deps = {
    HudGui: Frame,
    Plot: Frame,
    Remotes: { SpinWheel: RemoteEvent, WheelResult: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local WheelController = {}
local deps: Deps
local window: Frame
local open = false
local spinning = false
local face: ImageLabel?
local faceFallback: Frame
local timerLabel: TextLabel
local spinButton: TextButton
local resultLabel: TextLabel
local lastSnapshot: Snapshot? = nil
local worldGlow: UIStroke? = nil
local localSecondsLeft = 0

local PANEL_W, PANEL_H = 520, 560
-- ACUL sta DEASUPRA roții, dar in interiorul corpului ferestrei. Prima varianta il punea la y = -12
-- si intra peste antetul ferestrei -- exact felul de suprapunere care se vede imediat si nu se
-- observa cand scrii codul.
local NEEDLE_H = 34
local FACE = 190
local FACE_Y = NEEDLE_H - 6 -- acul intra putin in roata, ca sa arate spre ea
local Z = 70
local SPINS = 5 -- ture intregi inainte sa incetineasca

local function fmtTimer(seconds: number): string
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local sec = math.floor(seconds % 60)
    if h > 0 then
        return `{h}h {m}m`
    end
    return if m > 0 then `{m}m {sec}s` else `{sec}s`
end

local function refresh()
    local snap = lastSnapshot
    if snap == nil then
        return
    end
    local ready = snap.ready and localSecondsLeft <= 0
    spinButton.Visible = ready and not spinning
    timerLabel.Visible = not ready
    -- Obiectul din lume spune acelasi lucru ca fereastra: cand e o rotire de luat, straluceste;
    -- altfel sta acolo, vizibil, dar linistit. Doua locuri, un singur adevar [D40].
    local halo = worldGlow
    if halo ~= nil then
        halo.Enabled = ready
    end
    if not ready then
        timerLabel.Text = Strings.wheelNextSpin(fmtTimer(localSecondsLeft))
    end
end

function WheelController.Apply(snap: Snapshot?)
    if snap == nil then
        return
    end
    lastSnapshot = snap
    localSecondsLeft = snap.secondsLeft
    refresh()
end

function WheelController.IsOpen(): boolean
    return open
end

function WheelController.Close()
    open = false
    window.Visible = false
end

function WheelController.Open()
    Panels.CloseOthers("wheel")
    open = true
    window.Visible = true
    SoundController.Play("click")
    refresh()
end

function WheelController.Toggle()
    if open then
        WheelController.Close()
    else
        WheelController.Open()
    end
end

-- Unghiul pe care trebuie sa se opreasca roata ca felia castigatoare sa ajunga sub ac. Acul e
-- sus (-90 grade), iar centrul feliei k sta la (k+0.5)*45 - 180 in coordonate de ecran.
local function targetRotation(index: number): number
    local per = 360 / #WheelConfig.PRIZES
    return (90 - (index - 0.5) * per) % 360
end

local function landOn(prizeId: string, coins: number, pearls: number)
    local index = 1
    for i, p in WheelConfig.PRIZES do
        if p.id == prizeId then
            index = i
            break
        end
    end
    local target = targetRotation(index) + 360 * SPINS
    local subject: Instance = if face ~= nil then face :: Instance else faceFallback
    spinning = true
    spinButton.Visible = false
    resultLabel.Text = ""
    local tween = TweenService:Create(
        subject,
        TweenInfo.new(2.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { Rotation = target }
    )
    tween:Play()
    -- Clichetul porneste ODATA cu rotirea si se rareste singur (1.9s din 2.6s) -- `chime`-ul de la
    -- final ramane pentru premiu. Fara el, doua secunde si jumatate de animatie erau mute [D43].
    SoundController.Play("wheel")
    tween.Completed:Connect(function()
        spinning = false
        (subject :: any).Rotation = target % 360
        local parts = {}
        if coins > 0 then
            table.insert(parts, Strings.wheelWonCoins(TycoonMath.formatNumber(coins)))
        end
        if pearls > 0 then
            table.insert(parts, Strings.wheelWonPearls(pearls))
        end
        resultLabel.Text = table.concat(parts, "  ")
        SoundController.Play("chime")
        refresh()
    end)
end

-- Roata ca OBIECT in lume, langa debarcader. E un ImageButton, deci se apasa direct: la ei roata
-- se vede in mina, si de-aia se stie ca exista -- o intrare in bara de meniu nu se descopera.
local function buildWorldWheel()
    local sprite = Assets.tycoon.wheel
    local stand = TycoonConfig.WHEEL_STAND
    local size = if Assets.has(sprite) then sprite.width * Assets.PIXEL_SCALE else 96
    local b = Instance.new("ImageButton")
    b.Name = "LuckyWheel"
    b.AutoButtonColor = false
    b.BackgroundTransparency = 1
    b.AnchorPoint = Vector2.new(0.5, 1)
    b.Position = UDim2.fromOffset(stand.x, stand.y)
    b.Size = UDim2.fromOffset(size, size)
    b.ZIndex = 4
    if Assets.has(sprite) then
        b.Image = Assets.url(sprite)
        b.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        b.BackgroundTransparency = 0
        b.BackgroundColor3 = Theme.COLOR.wood
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = b
    end
    b.Parent = deps.Plot

    local halo = Instance.new("UIStroke")
    halo.Color = Theme.COLOR.gold
    halo.Thickness = 4
    halo.Enabled = false
    halo.Parent = b
    TweenService:Create(
        halo,
        TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { Transparency = 0.6 }
    ):Play()

    local name =
        Widgets.Label(b, Strings.WHEEL_TITLE, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    name.AnchorPoint = Vector2.new(0.5, 0)
    name.Position = UDim2.new(0.5, 0, 1, 2)
    name.Size = UDim2.fromOffset(size + 40, 18)
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.ZIndex = 5
    Theme.punch(name, 2)

    b.Activated:Connect(function()
        -- Inchiderea nu trece prin poarta: altfel un panou deschis inainte ca poarta sa se ridice
        -- ar ramane blocat deschis.
        if open then
            WheelController.Close()
        elseif Panels.CanOpen("wheel") then
            WheelController.Open()
        end
    end)
    worldGlow = halo
end

function WheelController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(deps.HudGui, {
        name = "WheelPanel",
        title = Strings.WHEEL_TITLE,
        icon = "clock",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = WheelController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    -- roata. Fara sprite incarcat, o rezerva plata rotunda tine locul -- acelasi tipar ca peste tot.
    faceFallback = Instance.new("Frame")
    faceFallback.Name = "FaceFallback"
    faceFallback.AnchorPoint = Vector2.new(0.5, 0)
    faceFallback.Position = UDim2.new(0.5, 0, 0, FACE_Y)
    faceFallback.Size = UDim2.fromOffset(FACE, FACE)
    faceFallback.BackgroundColor3 = Theme.COLOR.wood
    faceFallback.BorderSizePixel = 0
    faceFallback.ZIndex = Z + 1
    faceFallback.Parent = body
    local round = Instance.new("UICorner")
    round.CornerRadius = UDim.new(1, 0)
    round.Parent = faceFallback

    if Assets.has(Assets.tycoon.wheel_face) then
        local img = Instance.new("ImageLabel")
        img.Name = "Face"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(Assets.tycoon.wheel_face)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 0)
        img.Position = UDim2.new(0.5, 0, 0, FACE_Y)
        img.Size = UDim2.fromOffset(FACE, FACE)
        img.ZIndex = Z + 2
        img.Parent = body
        face = img
        faceFallback.Visible = false
    end

    -- acul, fix, deasupra roții: fara el nu se stie pe ce s-a oprit
    local needle = Widgets.Label(body, "▼", Theme.TEXT.title, Theme.COLOR.gold, "display")
    needle.AnchorPoint = Vector2.new(0.5, 0)
    needle.Position = UDim2.fromScale(0.5, 0)
    needle.Size = UDim2.fromOffset(40, NEEDLE_H)
    needle.TextXAlignment = Enum.TextXAlignment.Center
    needle.ZIndex = Z + 3

    resultLabel = Widgets.Label(body, "", Theme.TEXT.heading, Theme.COLOR.wood, "display")
    resultLabel.Position = UDim2.fromOffset(0, FACE_Y + FACE + 12)
    resultLabel.Size = UDim2.new(1, 0, 0, 30)
    resultLabel.TextXAlignment = Enum.TextXAlignment.Center
    resultLabel.ZIndex = Z + 1

    -- premiile, cu procentele lor. Sansele se afiseaza, nu se ascund.
    local list = Widgets.List(body, Z + 1, Theme.SPACE.xs)
    local prizeHolder = list.Parent :: Frame
    prizeHolder.Position = UDim2.fromOffset(0, FACE_Y + FACE + 48)
    prizeHolder.Size = UDim2.new(1, 0, 1, -(FACE_Y + FACE + 48 + 64))
    for _, prize in WheelConfig.PRIZES do
        local row = Widgets.Row(list, 26, Z + 2)
        local label = Widgets.Label(row, prize.label, Theme.TEXT.small, Theme.COLOR.ink, "body")
        label.Position = UDim2.fromOffset(Theme.SPACE.sm, 2)
        label.Size = UDim2.fromOffset(280, 22)
        label.ZIndex = Z + 3
        local odds = Widgets.Label(
            row,
            string.format("%.0f%%", WheelMath.percentOf(prize)),
            Theme.TEXT.small,
            Theme.COLOR.inkSoft,
            "display"
        )
        odds.AnchorPoint = Vector2.new(1, 0)
        odds.Position = UDim2.new(1, -Theme.SPACE.sm, 0, 2)
        odds.Size = UDim2.fromOffset(70, 22)
        odds.TextXAlignment = Enum.TextXAlignment.Right
        odds.ZIndex = Z + 3
    end

    spinButton = Widgets.Button(body, {
        text = Strings.WHEEL_SPIN,
        width = 220,
        height = 52,
        z = Z + 2,
        onClick = function()
            if spinning then
                return
            end
            deps.Remotes.SpinWheel:FireServer()
        end,
    })
    spinButton.AnchorPoint = Vector2.new(0.5, 1)
    spinButton.Position = UDim2.fromScale(0.5, 1)

    timerLabel = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.inkSoft, "body")
    timerLabel.AnchorPoint = Vector2.new(0.5, 1)
    timerLabel.Position = UDim2.fromScale(0.5, 1)
    timerLabel.Size = UDim2.fromOffset(320, 28)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center
    timerLabel.ZIndex = Z + 2

    deps.Remotes.WheelResult.OnClientEvent:Connect(
        function(prizeId: string?, coins: number, pearls: number, reason: string?)
            if prizeId == nil then
                deps.OnToast(Strings.wheelRejected(reason or ""), Theme.COLOR.bad)
                return
            end
            landOn(prizeId, coins, pearls)
        end
    )

    -- ceasul coboara pe client intre doua mesaje de la server: altfel ar sta pe loc minute intregi
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        -- Merge SI cu panoul inchis: roata din lume se aprinde cand ceasul ajunge la zero, iar
        -- inainte ceasul statea pe loc pana deschideai fereastra -- adica exact obiectul care
        -- trebuia sa te cheme nu se aprindea niciodata singur.
        if localSecondsLeft <= 0 then
            return
        end
        acc += dt
        if acc < 1 then
            return
        end
        localSecondsLeft = math.max(0, localSecondsLeft - acc)
        acc = 0
        refresh()
    end)

    Panels.Register("wheel", { isOpen = WheelController.IsOpen, close = WheelController.Close })
    buildWorldWheel()
end

return WheelController
