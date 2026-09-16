--!strict
-- Roata zilnica [D46]. Fereastra arata roata, premiile CU PROCENTELE LOR si ceasul pana la
-- urmatoarea rotire gratuita.
--
-- Procentele nu sunt scrise de mana: ies din aceleasi ponderi din care trage serverul
-- (WheelMath.percentOf) -- daca cineva schimba o pondere, cifra de pe ecran se schimba cu ea [D40].
--
-- Clientul NU trage nimic: cere rotirea, primeste premiul si abia apoi animeaza roata ca sa se
-- opreasca pe el. Asa nu exista nicio clipa in care el stie inainte, si nimic de pacalit.
--
-- [D59] ROATA LA PONTON. Owner-ul: "sa slefuim lucky wheel, nu prea se integreaza cu cap". Ce nu mergea: roata de
-- cazino cu felii curcubeu, in coltul satului pe unde nu trece nicio bucla, singurul obiect deschis cu click (nu cu E),
-- cu jumatate din premii in perle care nu cumparau nimic si cu monede care sareau peste tutorial. Acum:
--   * e un timonier de lemn pe punte, langa ponton, cu inelul auriu al locurilor care te cheama cand rotirea e gata;
--   * se deschide cu cardul E, ca orice obiect (tasta L o deschide de oriunde);
--   * fata din panou e timonierul, iar iconitele premiilor le pune codul intre spite, din WheelConfig;
--   * premiile sunt darurile raului (perle, ce vine la ponton, momeala aurie), fara monede;
--   * cand rotirea devine gata: punct pe butonul din bara si un toast.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TreasureConfig = require(ReplicatedStorage.Shared.Config.TreasureConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local WheelConfig = require(ReplicatedStorage.Shared.Config.WheelConfig)
local WheelMath = require(ReplicatedStorage.Shared.Modules.WheelMath)

local JuiceController = require(script.Parent.JuiceController)
local MenuBarController = require(script.Parent.MenuBarController)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)

export type Snapshot = { ready: boolean, secondsLeft: number, spins: number }

export type Deps = {
    HudGui: Frame,
    Plot: Frame,
    Remotes: { SpinWheel: RemoteEvent, WheelResult: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}

local WheelController = {}
local deps: Deps? = nil
local window: Frame
local open = false
local spinning = false
local face: ImageLabel?
local faceFallback: Frame
local timerLabel: TextLabel
local spinButton: TextButton
local resultLabel: TextLabel
local lastSnapshot: Snapshot? = nil
local worldRing: ImageLabel? = nil
local localSecondsLeft = 0
local wasReady: boolean? = nil
local prizeIcons: { ImageLabel } = {}

-- [D59] Fereastra: timonierul in stanga, lista cu procente in dreapta, butonul sub lista. Cutiile:
-- scripts/art/check_panel_rows.py (WHEEL_PANEL).
local PANEL_W, PANEL_H = 640, 420
local FACE = 220
local FACE_X = 10 -- stanga fetei, in corp
local FACE_Y = 30 -- sub ac
local ICON = 30
local ICON_RADIUS = FACE * 0.30 -- mijlocul feliei, intre butuc si obada
local LIST_X = 260
local Z = 70
local SPINS = 5 -- ture intregi inainte sa incetineasca
local HELM_SCALE = 2

local function fmtTimer(seconds: number): string
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local sec = math.floor(seconds % 60)
    if h > 0 then
        return `{h}h {m}m`
    end
    return if m > 0 then `{m}m {sec}s` else `{sec}s`
end

local function isReady(): boolean
    local snap = lastSnapshot
    return snap ~= nil and snap.ready and localSecondsLeft <= 0
end

-- Iconita unui premiu: perla, lucrul care vine pe rau sau momeala.
local function prizeSprite(prize: WheelConfig.Prize): Assets.Sprite?
    local sprite: Assets.Sprite? = nil
    if prize.pearls ~= nil then
        sprite = Assets.icons.pearl
    elseif prize.treasure ~= nil then
        sprite = (Assets.treasure :: any)[prize.treasure :: string]
    elseif prize.bait ~= nil then
        sprite = Assets.icons.bait
    end
    return if sprite ~= nil and Assets.has(sprite) then sprite else nil
end

local function refresh()
    local snap = lastSnapshot
    if snap == nil then
        return
    end
    local ready = isReady()
    spinButton.Visible = ready and not spinning
    timerLabel.Visible = not ready
    local ring = worldRing
    if ring ~= nil then
        ring.Visible = ready
    end
    if not ready then
        timerLabel.Text = Strings.wheelNextSpin(fmtTimer(localSecondsLeft))
    end
    -- Obiectul din lume, butonul din bara si fereastra spun acelasi lucru [D40]. Toast-ul doar cand rotirea DEVINE gata
    -- in timpul sesiunii: la intrare punctul din bara ajunge.
    MenuBarController.SetBadge("wheel", ready)
    local d = deps
    if wasReady == false and ready and d ~= nil then
        d.OnToast(Strings.WHEEL_READY_TOAST, Theme.COLOR.gold)
    end
    wasReady = ready
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

-- [D59] Cardul timonierului: rotirea gata -> "Spin the wheel (E)", care deschide fereastra (sansele se vad inainte);
-- altfel ceasul, pe care E il spune.
function WheelController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local stand = TycoonConfig.WHEEL_STAND
    local distance = Focus.distance(px, py, stand.x, stand.y - 20)
    if distance > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    local ready = isReady()
    return {
        key = "wheel",
        distance = distance,
        x = stand.x,
        y = stand.y - Assets.tycoon.helm.height * HELM_SCALE - 8,
        action = if ready then Strings.wheelCard(keyHint) else nil,
        act = if ready then WheelController.Open else nil,
        status = if ready then nil else Strings.wheelCardWait(fmtTimer(localSecondsLeft)),
    }
end

-- Iconitele premiilor, intre spitele timonierului, la unghiul feliei lor plus rotirea fetei. Recalculate la fiecare
-- cadru cat se invarte -- nu se bazeaza pe rotirea mostenita a copiilor unui GuiObject.
local function placeIcons(rotation: number)
    local cx, cy = FACE_X + FACE / 2, FACE_Y + FACE / 2
    for i, icon in prizeIcons do
        local a = math.rad(WheelMath.sliceAngle(i) + rotation)
        icon.Position =
            UDim2.fromOffset(cx + ICON_RADIUS * math.sin(a), cy - ICON_RADIUS * math.cos(a))
    end
end

-- Unghiul pe care se opreste fata ca felia `index` sa ajunga sub ac (sus).
local function targetRotation(index: number): number
    return (360 - WheelMath.sliceAngle(index)) % 360
end

-- Punctul din fereastra de unde zboara perlele, in coordonatele panzei HUD.
local function hudPoint(obj: GuiObject): (number, number)
    local d = deps :: Deps
    local canvas = d.HudGui
    local scale = if canvas.Size.X.Offset > 0
        then canvas.AbsoluteSize.X / canvas.Size.X.Offset
        else 1
    local p = obj.AbsolutePosition + obj.AbsoluteSize / 2 - canvas.AbsolutePosition
    return p.X / scale, p.Y / scale
end

local function resultText(prize: WheelConfig.Prize, pearls: number, converted: boolean): string
    if prize.treasure ~= nil then
        if converted then
            return Strings.wheelWonConverted(pearls)
        end
        local def = TreasureConfig.byId[prize.treasure :: string]
        return Strings.wheelWonTreasure(if def ~= nil then def.phrase else "something")
    elseif prize.bait ~= nil then
        return Strings.wheelWonBait(prize.bait :: number)
    end
    return Strings.wheelWonPearls(pearls)
end

local function landOn(prizeId: string, pearls: number, converted: boolean)
    local index = 1
    for i, p in WheelConfig.PRIZES do
        if p.id == prizeId then
            index = i
            break
        end
    end
    local prize = WheelConfig.PRIZES[index]
    local target = targetRotation(index) + 360 * SPINS
    local subject: GuiObject = if face ~= nil then face :: GuiObject else faceFallback
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
        subject.Rotation = target % 360
        placeIcons(subject.Rotation)
        resultLabel.Text = resultText(prize, pearls, converted)
        SoundController.Play("chime")
        if pearls > 0 and deps ~= nil then
            local hx, hy = hudPoint(subject)
            JuiceController.PearlFly(hx, hy, pearls)
        end
        refresh()
    end)
end

-- Timonierul pe punte, langa ponton. Sub el, inelul auriu cand rotirea e gata (limbajul locurilor care te cheama).
local function buildWorldWheel(d: Deps)
    local stand = TycoonConfig.WHEEL_STAND
    local sprite = Assets.tycoon.helm
    local w, h = sprite.width * HELM_SCALE, sprite.height * HELM_SCALE
    GroundShadow.add(d.Plot, UDim2.fromOffset(stand.x, stand.y), w * 0.6, 3, 0.35)

    if Assets.has(Assets.ui.groundring) then
        local ring = Instance.new("ImageLabel")
        ring.Name = "WheelReadyRing"
        ring.BackgroundTransparency = 1
        ring.Image = Assets.url(Assets.ui.groundring)
        ring.ResampleMode = Enum.ResamplerMode.Pixelated
        ring.ImageColor3 = Theme.COLOR.gold
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Position = UDim2.fromOffset(stand.x, stand.y - 4)
        ring.Size =
            UDim2.fromOffset(Assets.ui.groundring.width * 3, Assets.ui.groundring.height * 3)
        ring.ZIndex = 3
        ring.Visible = false
        ring.Parent = d.Plot
        worldRing = ring
    end

    local helm = Instance.new("ImageLabel")
    helm.Name = "LuckyWheel"
    helm.BackgroundTransparency = 1
    helm.AnchorPoint = Vector2.new(0.5, 1)
    helm.Position = UDim2.fromOffset(stand.x, stand.y)
    helm.Size = UDim2.fromOffset(w, h)
    helm.ZIndex = 4
    if Assets.has(sprite) then
        helm.Image = Assets.url(sprite)
        helm.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        helm.BackgroundTransparency = 0
        helm.BackgroundColor3 = Theme.COLOR.wood
    end
    helm.Parent = d.Plot

    local name =
        Widgets.Label(helm, Strings.WHEEL_TAG, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    name.AnchorPoint = Vector2.new(0.5, 0)
    name.Position = UDim2.new(0.5, 0, 1, 2)
    name.Size = UDim2.fromOffset(w + 60, 30) -- doua randuri
    name.TextXAlignment = Enum.TextXAlignment.Center
    name.ZIndex = 5
    Theme.punch(name, 2)
end

function WheelController.Init(d: Deps)
    deps = d
    local root, body = Widgets.Window(d.HudGui, {
        name = "WheelPanel",
        title = Strings.WHEEL_TITLE,
        icon = "spin",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = WheelController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    -- fata. Fara sprite incarcat, o rezerva plata rotunda tine locul -- acelasi tipar ca peste tot.
    faceFallback = Instance.new("Frame")
    faceFallback.Name = "FaceFallback"
    faceFallback.Position = UDim2.fromOffset(FACE_X, FACE_Y)
    faceFallback.Size = UDim2.fromOffset(FACE, FACE)
    faceFallback.BackgroundColor3 = Theme.COLOR.wood
    faceFallback.BorderSizePixel = 0
    faceFallback.ZIndex = Z + 1
    faceFallback.Parent = body
    local round = Instance.new("UICorner")
    round.CornerRadius = UDim.new(1, 0)
    round.Parent = faceFallback

    local faceSprite = if Assets.has(Assets.tycoon.helm_face)
        then Assets.tycoon.helm_face
        else Assets.tycoon.wheel_face
    if Assets.has(faceSprite) then
        local img = Instance.new("ImageLabel")
        img.Name = "Face"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(faceSprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.Position = UDim2.fromOffset(FACE_X, FACE_Y)
        img.Size = UDim2.fromOffset(FACE, FACE)
        img.ZIndex = Z + 2
        img.Parent = body
        face = img
        faceFallback.Visible = false
    end

    -- iconitele premiilor, peste fata (nu in ea): se rotesc cu ea, dar raman drepte
    for i, prize in WheelConfig.PRIZES do
        local icon = Instance.new("ImageLabel")
        icon.Name = `Prize{i}`
        icon.BackgroundTransparency = 1
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Size = UDim2.fromOffset(ICON, ICON)
        icon.ResampleMode = Enum.ResamplerMode.Pixelated
        icon.ZIndex = Z + 3
        local sprite = prizeSprite(prize)
        if sprite ~= nil then
            icon.Image = Assets.url(sprite)
            local s = math.min(ICON / sprite.width, ICON / sprite.height)
            icon.Size = UDim2.fromOffset(sprite.width * s, sprite.height * s)
        end
        icon.Parent = body
        prizeIcons[i] = icon
    end
    placeIcons(0)

    -- acul, fix, deasupra roții: fara el nu se stie pe ce s-a oprit
    local needle = Widgets.Label(body, "▼", Theme.TEXT.title, Theme.COLOR.gold, "display")
    needle.AnchorPoint = Vector2.new(0.5, 0)
    needle.Position = UDim2.fromOffset(FACE_X + FACE / 2, -2)
    needle.Size = UDim2.fromOffset(40, 34)
    needle.TextXAlignment = Enum.TextXAlignment.Center
    needle.ZIndex = Z + 4
    Theme.punch(needle, 2)

    resultLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.wood, "strong")
    resultLabel.Position = UDim2.fromOffset(0, FACE_Y + FACE + 12)
    resultLabel.Size = UDim2.fromOffset(FACE_X * 2 + FACE, 44)
    resultLabel.TextXAlignment = Enum.TextXAlignment.Center
    resultLabel.TextWrapped = true
    resultLabel.ZIndex = Z + 1

    -- premiile, cu iconita si procentul. Sansele se afiseaza, nu se ascund.
    local list = Widgets.List(body, Z + 1, Theme.SPACE.xs)
    local prizeHolder = list.Parent :: Frame
    prizeHolder.Position = UDim2.fromOffset(LIST_X, 0)
    prizeHolder.Size = UDim2.new(1, -LIST_X, 0, 256)
    for i, prize in WheelConfig.PRIZES do
        local row = Widgets.Row(list, 26, Z + 2)
        row.LayoutOrder = i
        local sprite = prizeSprite(prize)
        if sprite ~= nil then
            local ico = Instance.new("ImageLabel")
            ico.BackgroundTransparency = 1
            ico.Image = Assets.url(sprite)
            ico.ResampleMode = Enum.ResamplerMode.Pixelated
            ico.AnchorPoint = Vector2.new(0.5, 0.5)
            ico.Position = UDim2.fromOffset(Theme.SPACE.sm + 10, 13)
            local s = math.min(20 / sprite.width, 20 / sprite.height)
            ico.Size = UDim2.fromOffset(sprite.width * s, sprite.height * s)
            ico.ZIndex = Z + 3
            ico.Parent = row
        end
        local label = Widgets.Label(row, prize.label, Theme.TEXT.small, Theme.COLOR.ink, "body")
        label.Position = UDim2.fromOffset(Theme.SPACE.sm + 26, 2)
        label.Size = UDim2.fromOffset(200, 22)
        label.TextTruncate = Enum.TextTruncate.AtEnd
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
        odds.Size = UDim2.fromOffset(52, 22)
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
            d.Remotes.SpinWheel:FireServer()
        end,
    })
    spinButton.AnchorPoint = Vector2.new(0.5, 1)
    spinButton.Position = UDim2.new(0, LIST_X + (PANEL_W - Theme.SPACE.lg * 2 - LIST_X) / 2, 1, 0)

    timerLabel = Widgets.Label(body, "", Theme.TEXT.body, Theme.COLOR.inkSoft, "body")
    timerLabel.AnchorPoint = Vector2.new(0.5, 1)
    timerLabel.Position = spinButton.Position
    timerLabel.Size = UDim2.fromOffset(320, 28)
    timerLabel.TextXAlignment = Enum.TextXAlignment.Center
    timerLabel.ZIndex = Z + 2

    d.Remotes.WheelResult.OnClientEvent:Connect(
        function(prizeId: string?, pearls: number, converted: boolean, reason: string?)
            if prizeId == nil then
                d.OnToast(Strings.wheelRejected(reason or ""), Theme.COLOR.bad)
                return
            end
            landOn(prizeId, if typeof(pearls) == "number" then pearls else 0, converted == true)
        end
    )

    -- ceasul coboara pe client intre doua mesaje de la server: altfel ar sta pe loc minute intregi
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        -- Merge SI cu panoul inchis: timonierul din lume se aprinde cand ceasul ajunge la zero, iar
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
    RunService.PreRender:Connect(function()
        if spinning then
            local subject: GuiObject = if face ~= nil then face :: GuiObject else faceFallback
            placeIcons(subject.Rotation)
        end
        local ring = worldRing
        if ring ~= nil and ring.Visible then
            ring.ImageTransparency = 0.25 + 0.25 * (math.sin(os.clock() * 3.2) + 1) / 2
        end
    end)

    Panels.Register("wheel", { isOpen = WheelController.IsOpen, close = WheelController.Close })
    buildWorldWheel(d)
end

return WheelController
