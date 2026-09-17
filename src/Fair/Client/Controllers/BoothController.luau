--!strict
-- [D61] GHERETELE DE JOC, pe ecran. In pasii jucatorului:
--   1. deasupra fiecarei gherete, numele jocului; langa ea, cardul `Play Ring Toss (E)` / `Play Hook a Duck (E)`;
--   2. apesi: se deschide panoul, serverul da samanta si jocul porneste;
--   3. Ring Toss: inelul se leagana deasupra sticlelor, E (sau butonul) il arunca; 5 inele, fiecare mai repede.
--      Hook a Duck: ratustele cu cifre trec pe sub carlig, E il lasa in jos; 3 carlige;
--   4. la sfarsit: scorul, premiul (sau ca a fost un joc de placere) si `Play again`.
-- Panoul spune dinainte cate jocuri cu premiu mai ai azi [D43]. Miscarea e cea din BoothMath, aceeasi pe server, care
-- socoteste scorul din clipele trimise de aici.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local BoothMath = require(ReplicatedStorage.Shared.Modules.BoothMath)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)

local FairScene = require(script.Parent.FairScene)
local Panels = require(script.Parent.Panels)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = {
    World: Frame,
    HudGui: Frame,
    Remotes: {
        BoothStart: RemoteEvent,
        BoothStarted: RemoteEvent,
        BoothFinish: RemoteEvent,
        BoothResult: RemoteEvent,
    },
    OnToast: (string, Color3?) -> (),
    PearlFly: (number, number, number) -> (),
}
export type Snapshot = { left: number, perfect: number }

local BoothController = {}
local deps: Deps? = nil
local left = BoothMath.PRIZE_GAMES

local BOOTH_DISTANCE = 110
local PANEL_W, PANEL_H = 560, 470
local AREA_W, AREA_H = 520, 250
local Z = 66
local PX = 4 -- piesele jocurilor, marite de 4 ori
local SHELF_Y = 170
local RING_Y = 60
local WATER_Y = 130
local DUCK_BASE = 196
local HOOK_REST = 110

local window: Frame
local area: Frame
local helpLabel: TextLabel
local progressLabel: TextLabel
local prizeLabel: TextLabel
local hintLabel: TextLabel
local actionButton: TextButton
local open = false
local game = "ring"
local phase = "idle" -- "waiting" | "playing" | "sending" | "done"
local seed = 0
local t0 = 0
local presses: { number } = {}
local score = 0

-- piesele din zona jocului (refacute la fiecare joc)
local ringFloat: ImageLabel? = nil
local ducks: { ImageLabel } = {}
local hookLine: Frame? = nil

local function image(parent: Instance, sprite: Assets.Sprite, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(sprite.width * PX, sprite.height * PX)
    img.ZIndex = z
    if Assets.has(sprite) then
        img.Image = Assets.url(sprite)
    else
        img.BackgroundTransparency = 0
        img.BackgroundColor3 = Theme.COLOR.gold
    end
    img.Parent = parent
    return img
end

local function block(
    parent: Instance,
    x: number,
    y: number,
    w: number,
    h: number,
    color: Color3,
    z: number
): Frame
    local f = Instance.new("Frame")
    f.Position = UDim2.fromOffset(x, y)
    f.Size = UDim2.fromOffset(w, h)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z
    f.Parent = parent
    return f
end

local function clearArea()
    for _, child in area:GetChildren() do
        if not child:IsA("UICorner") then
            child:Destroy()
        end
    end
    ringFloat = nil
    ducks = {}
    hookLine = nil
end

local function buildRing()
    clearArea()
    local stripes = 14
    local w = AREA_W / stripes
    for i = 0, stripes - 1 do
        local color = if i % 2 == 0
            then Color3.fromRGB(170, 60, 52)
            else Color3.fromRGB(214, 196, 170)
        block(area, math.floor(i * w), 0, math.ceil(w), SHELF_Y, color, Z + 2)
    end
    block(area, 0, SHELF_Y, AREA_W, 14, Color3.fromRGB(74, 48, 30), Z + 3)
    block(area, 0, SHELF_Y + 14, AREA_W, AREA_H - SHELF_Y - 14, Color3.fromRGB(112, 78, 50), Z + 3)
    for _, bx in BoothMath.BOTTLES do
        local bottle = image(area, Assets.ui.booth_bottle, Z + 4)
        bottle.AnchorPoint = Vector2.new(0.5, 1)
        bottle.Position = UDim2.fromOffset(bx * AREA_W, SHELF_Y)
    end
    local ring = image(area, Assets.ui.booth_ring, Z + 6)
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Visible = false
    ringFloat = ring
end

local function buildDucks()
    clearArea()
    block(area, 0, 0, AREA_W, WATER_Y, Color3.fromRGB(40, 70, 110), Z + 2)
    block(area, 0, WATER_Y, AREA_W, 80, Color3.fromRGB(56, 104, 150), Z + 2)
    for i = 0, AREA_W, 24 do
        block(area, i, WATER_Y + (i // 24) % 2 * 3, 12, 2, Color3.fromRGB(120, 170, 210), Z + 3)
    end
    block(area, 0, WATER_Y + 80, AREA_W, AREA_H - WATER_Y - 80, Color3.fromRGB(34, 60, 96), Z + 2)
    for k, value in BoothMath.DUCKS do
        local duck = image(area, Assets.ui.booth_duck, Z + 5)
        duck.AnchorPoint = Vector2.new(0.5, 1)
        duck.Position = UDim2.fromOffset(-100, DUCK_BASE)
        -- steguletul cu cifra, infipt in spatele ratustei: se vede de departe
        local pole = block(duck, 2, -26, 3, 30, Color3.fromRGB(90, 70, 50), Z + 4)
        pole.Name = "Pole"
        local flag = block(duck, 5, -26, 26, 20, Color3.fromRGB(246, 242, 230), Z + 6)
        flag.Name = "Flag"
        local number =
            Widgets.Label(flag, tostring(value), Theme.TEXT.small, Theme.COLOR.ink, "strong")
        number.Size = UDim2.fromScale(1, 1)
        number.TextXAlignment = Enum.TextXAlignment.Center
        number.TextColor3 = if value == 5 then Theme.COLOR.badInk else Theme.COLOR.ink
        number.ZIndex = Z + 7
        ducks[k] = duck
    end
    local line = block(
        area,
        math.floor(BoothMath.HOOK_X * AREA_W) - 1,
        0,
        3,
        HOOK_REST,
        Color3.fromRGB(210, 210, 200),
        Z + 8
    )
    local tip = block(line, -5, 0, 13, 3, Color3.fromRGB(210, 210, 200), Z + 8)
    tip.AnchorPoint = Vector2.new(0, 1)
    tip.Position = UDim2.new(0, -5, 1, 0)
    local barb = block(line, 5, 0, 3, 8, Color3.fromRGB(210, 210, 200), Z + 8)
    barb.AnchorPoint = Vector2.new(0, 1)
    barb.Position = UDim2.new(0, 5, 1, -2)
    hookLine = line
end

local function spec(): BoothMath.Game
    return BoothMath.GAMES[game]
end

local function refreshTexts()
    local s = spec()
    local used = BoothMath.PRIZE_GAMES - left
    if phase == "waiting" then
        helpLabel.Text = Strings.BOOTH_WAIT
    elseif phase == "playing" then
        helpLabel.Text = (Strings.BOOTH_HELP :: any)[game]
    end
    progressLabel.Text = Strings.boothProgress(game, #presses, s.throws, score)
    if left > 0 then
        prizeLabel.Text = Strings.boothPrizeGames(used, BoothMath.PRIZE_GAMES)
        prizeLabel.TextColor3 = Theme.COLOR.goodInk
    else
        prizeLabel.Text = Strings.BOOTH_NO_PRIZE
        prizeLabel.TextColor3 = Theme.COLOR.warnInk
    end
    hintLabel.Text = (Strings.BOOTH_HINT :: any)[game]
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    if phase == "done" then
        Widgets.SetButtonText(actionButton, Strings.BOOTH_AGAIN)
        Widgets.SetButtonTone(actionButton, Theme.COLOR.gold)
    else
        Widgets.SetButtonText(actionButton, `{(Strings.BOOTH_ACTION :: any)[game]}{keyHint}`)
        Widgets.SetButtonTone(
            actionButton,
            if phase == "playing" then Theme.COLOR.gold else Theme.COLOR.parchmentDim
        )
    end
end

local function start(which: string)
    local d = deps
    if d == nil then
        return
    end
    game = which
    phase = "waiting"
    presses = {}
    score = 0
    if which == "ring" then
        buildRing()
    else
        buildDucks()
    end
    refreshTexts()
    d.Remotes.BoothStart:FireServer(which)
end

function BoothController.IsOpen(): boolean
    return open
end

function BoothController.Close()
    open = false
    phase = "idle"
    if window ~= nil then
        window.Visible = false
    end
end

function BoothController.Open(which: string)
    if not Panels.CanOpen("booth") then
        return
    end
    Panels.CloseOthers("booth")
    open = true
    window.Visible = true
    Widgets.SetWindowTitle(window, (Strings.BOOTH_TITLES :: any)[which], "check")
    SoundController.Play("click")
    start(which)
end

-- Ce s-a intamplat cu o aruncare: inelul cade (pe gat sau pe langa), carligul coboara si ridica ratusca.
local function throwRing(x: number, hit: number?)
    local ring = image(area, Assets.ui.booth_ring, Z + 6)
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(x * AREA_W, RING_Y)
    local target = if hit ~= nil
        then UDim2.fromOffset(
            BoothMath.BOTTLES[hit] * AREA_W,
            SHELF_Y - Assets.ui.booth_bottle.height * PX + 14
        )
        else UDim2.fromOffset(x * AREA_W, SHELF_Y + 20)
    TweenService:Create(
        ring,
        TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Position = target }
    ):Play()
    if hit == nil then
        task.delay(0.45, function()
            TweenService:Create(ring, TweenInfo.new(0.3), { ImageTransparency = 1 }):Play()
        end)
    end
end

local function dropHook(k: number?)
    local line = hookLine
    if line == nil then
        return
    end
    local down = TweenService:Create(
        line,
        TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.fromOffset(3, HOOK_REST + 60) }
    )
    down:Play()
    task.delay(0.2, function()
        TweenService:Create(line, TweenInfo.new(0.35), { Size = UDim2.fromOffset(3, HOOK_REST) })
            :Play()
    end)
    if k ~= nil then
        local duck = ducks[k]
        if duck ~= nil then
            local lift = Instance.new("UIScale")
            lift.Scale = 1.25
            lift.Parent = duck
            TweenService:Create(lift, TweenInfo.new(0.5), { Scale = 1 }):Play()
            task.delay(0.55, function()
                lift:Destroy()
            end)
        end
    end
end

local function press()
    local d = deps
    if d == nil or phase ~= "playing" then
        return
    end
    local s = spec()
    local i = #presses + 1
    local now = os.clock() - t0
    local windowStart = BoothMath.windowStart(game, presses, i)
    if now < windowStart + s.minAim then
        return -- inelul (sau carligul) nu e inca gata: apasarea nu se numara
    end
    presses[i] = now
    if game == "ring" then
        local x = BoothMath.ringX(now - windowStart, seed, i)
        local hit = BoothMath.ringHit(x)
        throwRing(x, hit)
        if hit ~= nil then
            score += 1
            SoundController.Play("coin", 1.1)
        else
            SoundController.Play("splash", 0.9)
        end
    else
        local k = BoothMath.duckUnder(now, seed)
        dropHook(k)
        if k ~= nil then
            score += BoothMath.DUCKS[k]
            SoundController.Play("coin", 1 + 0.05 * BoothMath.DUCKS[k])
        else
            SoundController.Play("splash", 1.1)
        end
    end
    if i >= s.throws then
        phase = "sending"
        d.Remotes.BoothFinish:FireServer(presses)
    end
    refreshTexts()
end

local function update()
    if not open then
        return
    end
    local now = os.clock() - t0
    if game == "ring" then
        local ring = ringFloat
        if ring ~= nil then
            local i = #presses + 1
            local ws = BoothMath.windowStart(game, presses, math.min(i, spec().throws))
            local swinging = phase == "playing" and i <= spec().throws and now >= ws
            ring.Visible = swinging
            if swinging then
                ring.Position =
                    UDim2.fromOffset(BoothMath.ringX(now - ws, seed, i) * AREA_W, RING_Y)
            end
        end
    elseif phase == "playing" or phase == "sending" or phase == "done" then
        for k, duck in ducks do
            duck.Position = UDim2.fromOffset(BoothMath.duckX(now, seed, k) * AREA_W, DUCK_BASE)
        end
    end
end

local function hudPoint(gui: GuiObject): (number, number)
    local d = deps :: Deps
    local canvas = d.HudGui
    local s = canvas:FindFirstChildOfClass("UIScale")
    local scale = if s ~= nil then s.Scale else 1
    local p = gui.AbsolutePosition + gui.AbsoluteSize / 2 - canvas.AbsolutePosition
    return p.X / scale, p.Y / scale
end

-- Cardul gheretei celei mai apropiate.
function BoothController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local best, bestDistance = nil :: { spot: string, game: string, label: string }?, BOOTH_DISTANCE
    for _, booth in FairLayout.BOOTHS do
        local x, y = FairScene.Spot(booth.spot)
        local distance = Focus.distance(px, py, x, y + 10)
        if distance <= bestDistance then
            best, bestDistance = booth, distance
        end
    end
    if best == nil then
        return nil
    end
    local booth = best :: { spot: string, game: string, label: string }
    local x, y, _, h = FairScene.Spot(booth.spot)
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = `booth:{booth.game}`,
        distance = bestDistance,
        x = x,
        y = y - h - 38, -- deasupra numelui gheretei
        action = Strings.boothCard(booth.game, keyHint),
        act = function()
            BoothController.Open(booth.game)
        end,
    }
end

-- Din FairState: cate jocuri cu premiu mai ai azi.
function BoothController.Apply(snap: Snapshot)
    left = snap.left
    if open then
        refreshTexts()
    end
end

local function buildSigns(world: Frame)
    -- numele fiecarei gherete, deasupra ei (aceeasi cutie ca in testul de asezare)
    for _, booth in FairLayout.BOOTHS do
        local x, y, _, h = FairScene.Spot(booth.spot)
        local sign =
            Widgets.Label(world, booth.label, Theme.TEXT.small, Theme.COLOR.onDark, "strong")
        local w = math.ceil(Theme.textWidth(booth.label, Theme.TEXT.small, "strong")) + 24
        sign.AnchorPoint = Vector2.new(0.5, 0)
        sign.Position = UDim2.fromOffset(x, y - h - 6 - 26)
        sign.Size = UDim2.fromOffset(w, 26)
        sign.TextXAlignment = Enum.TextXAlignment.Center
        sign.ZIndex = FairScene.Z.LABELS
        Theme.punch(sign, 2)
    end
end

function BoothController.Init(d: Deps)
    deps = d
    buildSigns(d.World)
    local root, body = Widgets.Window(d.HudGui, {
        name = "Booth",
        title = Strings.BOOTH_TITLES.ring,
        icon = "check",
        width = PANEL_W,
        height = PANEL_H,
        z = Z,
        onClose = BoothController.Close,
    })
    window = root
    window.AnchorPoint = Vector2.new(0.5, 0.5)
    window.Position = UDim2.fromScale(0.5, 0.5)
    window.Visible = false

    area = Instance.new("Frame")
    area.Name = "GameArea"
    area.Size = UDim2.fromOffset(AREA_W, AREA_H)
    area.BackgroundColor3 = Color3.fromRGB(30, 34, 46)
    area.BorderSizePixel = 0
    area.ClipsDescendants = true
    area.ZIndex = Z + 1
    area.Parent = body
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = area

    helpLabel = Widgets.Label(body, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "strong")
    helpLabel.Position = UDim2.fromOffset(0, AREA_H + 6)
    helpLabel.Size = UDim2.fromOffset(AREA_W, 20)
    helpLabel.TextXAlignment = Enum.TextXAlignment.Center
    helpLabel.ZIndex = Z + 1
    progressLabel = Widgets.Label(body, "", Theme.TEXT.small, Theme.COLOR.ink, "strong")
    progressLabel.Position = UDim2.fromOffset(0, AREA_H + 32)
    progressLabel.Size = UDim2.fromOffset(300, 22)
    progressLabel.ZIndex = Z + 1
    prizeLabel = Widgets.Label(body, "", Theme.TEXT.tiny, Theme.COLOR.goodInk, "strong")
    prizeLabel.Position = UDim2.fromOffset(0, AREA_H + 60)
    prizeLabel.Size = UDim2.fromOffset(300, 20)
    prizeLabel.TextTruncate = Enum.TextTruncate.AtEnd
    prizeLabel.ZIndex = Z + 1
    hintLabel = Widgets.Label(body, "", Theme.TEXT.tiny, Theme.COLOR.inkSoft, "body")
    hintLabel.Position = UDim2.fromOffset(0, AREA_H + 84)
    hintLabel.Size = UDim2.fromOffset(300, 18)
    hintLabel.TextTruncate = Enum.TextTruncate.AtEnd
    hintLabel.ZIndex = Z + 1
    actionButton = Widgets.Button(body, {
        text = "",
        width = 190,
        height = 52,
        z = Z + 2,
        onClick = function()
            if phase == "done" then
                start(game)
            else
                press()
            end
        end,
    })
    actionButton.Position = UDim2.fromOffset(AREA_W - 190, AREA_H + 64)

    d.Remotes.BoothStarted.OnClientEvent:Connect(
        function(which: unknown, newSeed: unknown, extra: unknown)
            if not open or which ~= game or phase ~= "waiting" then
                return
            end
            if typeof(newSeed) ~= "number" then
                phase = "done"
                helpLabel.Text =
                    Strings.boothRejected(if typeof(extra) == "string" then extra else "")
                refreshTexts()
                return
            end
            seed = newSeed
            if typeof(extra) == "number" then
                left = extra
            end
            t0 = os.clock()
            phase = "playing"
            refreshTexts()
        end
    )

    d.Remotes.BoothResult.OnClientEvent:Connect(
        function(ok: unknown, reason: unknown, result: unknown)
            if phase ~= "sending" then
                return
            end
            phase = "done"
            if ok ~= true or typeof(result) ~= "table" then
                helpLabel.Text =
                    Strings.boothRejected(if typeof(reason) == "string" then reason else "")
                refreshTexts()
                return
            end
            local r: any = result
            local prize = if typeof(r.prize) == "number" then r.prize else 0
            if typeof(r.left) == "number" then
                left = r.left
            end
            if typeof(r.score) == "number" then
                score = r.score
            end
            helpLabel.Text = Strings.boothResult(game, score, prize, r.prizeGame == true)
            refreshTexts()
            if prize > 0 then
                SoundController.Play("chime")
                local hx, hy = hudPoint(helpLabel)
                d.PearlFly(hx, hy, prize)
            end
            if r.title == true then
                task.delay(1, function()
                    d.OnToast(Strings.SHARPSHOOTER_UNLOCKED, Theme.COLOR.gold)
                end)
            end
        end
    )

    UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
        if processed or not open then
            return
        end
        if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
            if phase == "done" then
                start(game)
            else
                press()
            end
        end
    end)
    RunService.PreRender:Connect(update)
    Panels.Register("booth", { isOpen = BoothController.IsOpen, close = BoothController.Close })
end

return BoothController
