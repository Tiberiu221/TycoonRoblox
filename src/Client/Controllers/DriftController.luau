--!strict
-- [D62, pasul 3] DARURILE RAULUI, pe client. Un butoi (des), o lada (uneori) sau un bustean de aur (rar) trece pe rau,
-- dincolo de plase. Alergi pe punte in dreptul lui; cardul scrie `Grab it (E)`. Il scoti: vine spre tine, iar monedele
-- sar spre contor. Daca il scapi, pleaca pe rau si atat -- n-ai avut nimic, nu pierzi nimic.
--
-- Programul vine din DriftMath, determinist pe samanta raului si ceasul serverului: serverul nu trimite nimic cand apare
-- un dar, iar clientul nu cere nimic ca sa-l deseneze. Cand il scoti, serverul reface acelasi dar si verifica momentul.
--
-- Pe telefon, de pe punte (y ~800) raul din larg (y 520) iese din ecran: cat ai un dar in raza, camera se muta lin la
-- jumatatea drumului dintre tine si el, ca sa vezi ce scoti, si se intoarce cand pleci sau l-ai luat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local DriftMath = require(ReplicatedStorage.Shared.Modules.DriftMath)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)
local Focus = require(script.Parent.Parent.UI.Focus)
local Theme = require(script.Parent.Parent.UI.Theme)

export type Deps = {
    Plot: Frame,
    CharacterPos: () -> (number, number),
    RiverConfig: RemoteEvent, -- de aici vine samanta raului, ca la RiverRenderController
    Remotes: { GrabDrift: RemoteEvent, DriftGrabbed: RemoteEvent },
    OnToast: (string, Color3?) -> (),
}
-- Zborul monedelor spre contor are nevoie de panza HUD-ului, care in bootstrap apare mai tarziu decat raul: se leaga
-- dupa (SetHud). Init trebuie sa ruleze devreme, ca sa prinda configul raului (samanta).
local worldToHud: ((number, number) -> (number, number))? = nil
local coinFly: ((number, number, number) -> ())? = nil

local DriftController = {}
local deps: Deps? = nil
local seed: number? = nil

local SCALE = TycoonConfig.PROP_SCALE
local Z = 6 -- peste decorul din larg si peste plase
-- De unde il poti scoate: de pe punte si de pe ponton (nu din curtea gaterului).
local STAND_Y0, STAND_Y1 = 600, 880
local FOCUS_EASE = 0.35 -- secunde pana camera ajunge la jumatatea drumului (si inapoi)
local FLY_SECONDS = 0.45

type View = { holder: Frame, glow: Frame?, kind: string }
local views: { [number]: View } = {} -- fereastra darului -> desenul lui
local taken: { [number]: boolean } = {} -- scoase (sau cerute) de tine: nu se mai deseneaza si nu mai au card
local pending: { [number]: boolean } = {}
local announced: { [number]: boolean } = {}
local inReach: DriftMath.Gift? = nil
local focusBlend = 0
local ownsFocus = false
local focusX, focusY = 0, 0
local firstSeen = false
-- [D73] puntile de pe care se poate scoate un dar: ale cartierelor deschise (SetZones), ca pe server (DriftService)
local spans: { DriftMath.Span } = DriftMath.reaches(
    TycoonConfig.deckSpans(),
    function(era: number): boolean
        return era == 1
    end
)
-- [D73] cel mai nou dar platit: serverul nu mai da niciunul mai vechi (`Stats.lastDrift`), deci nici cardul nu-l ofera.
-- Din Era 3, darul de dinainte se poate ajunge din urma pe puntea Wire Works, dupa ce l-ai scos pe urmatorul.
local lastTaken = 0

-- Puntea fata de care se anunta un dar: cea pe care stai, altfel prima din fata ta (darurile merg spre aval), altfel
-- prima din lista. Anuntul la intrarea in The Landing nu folosea la nimic cuiva care asteapta pe puntea Wire Works.
local function announceX(px: number): number
    local ahead: number? = nil
    for _, span in spans do
        if px >= span.x0 - 120 and px <= span.x1 + 120 then
            return span.x0
        end
        if ahead == nil and span.x0 > px then
            ahead = span.x0
        end
    end
    local first = spans[1]
    return ahead or (if first ~= nil then first.x0 else DriftMath.REACH_X0)
end

-- acelasi getter cat tinem camera, ca ReleaseFocus sa stie ca e a noastra
local function focusGetter(): (number?, number?)
    return focusX, focusY
end

local SPRITE_OF: { [string]: () -> Assets.Sprite } = {
    barrel = function()
        return Assets.treasure.barrel_water
    end,
    crate = function()
        return Assets.treasure.crate_water
    end,
    golden = function()
        return Assets.treasure.golden_water
    end,
}
-- fara desen urcat: un butoi / o lada din dreptunghiuri, cat sa se vada ce trece [regula 6]
local FALLBACK: { [string]: { w: number, h: number, color: Color3 } } = {
    barrel = { w = 44, h = 24, color = Color3.fromRGB(134, 92, 56) },
    crate = { w = 36, h = 28, color = Color3.fromRGB(150, 110, 70) },
    golden = { w = 48, h = 20, color = Color3.fromRGB(232, 178, 60) },
}

local function serverNow(): number
    return Workspace:GetServerTimeNow()
end

local function buildView(plot: Frame, gift: DriftMath.Gift): View
    local holder = Instance.new("Frame")
    holder.Name = `Drift_{gift.id}`
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Size = UDim2.fromOffset(0, 0)
    holder.ZIndex = Z
    holder.Parent = plot

    -- lumina moale de sub dar: se vede de departe ca e altceva decat bustenii care trec
    local glow = Instance.new("Frame")
    glow.Name = "Glow"
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Size = UDim2.fromOffset(if gift.kind == "golden" then 96 else 72, 40)
    glow.BackgroundColor3 = if gift.kind == "golden"
        then Color3.fromRGB(255, 226, 120)
        else Color3.fromRGB(235, 246, 255)
    glow.BackgroundTransparency = 0.72
    glow.BorderSizePixel = 0
    glow.ZIndex = Z
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = glow
    glow.Parent = holder

    local spriteOf = SPRITE_OF[gift.kind]
    local sprite = if spriteOf ~= nil then spriteOf() else nil
    if sprite ~= nil and Assets.has(sprite) then
        local img = Instance.new("ImageLabel")
        img.Name = "Art"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sprite)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.Size = UDim2.fromOffset(sprite.width * SCALE, sprite.height * SCALE)
        img.ZIndex = Z + 1
        img.Parent = holder
    else
        local shape = FALLBACK[gift.kind] or FALLBACK.barrel
        local box = Instance.new("Frame")
        box.Name = "Art"
        box.AnchorPoint = Vector2.new(0.5, 0.5)
        box.Size = UDim2.fromOffset(shape.w, shape.h)
        box.BackgroundColor3 = shape.color
        box.BorderSizePixel = 0
        box.ZIndex = Z + 1
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, 6)
        c.Parent = box
        local stroke = Instance.new("UIStroke")
        stroke.Color = Theme.COLOR.woodDark
        stroke.Thickness = 2
        stroke.Parent = box
        box.Parent = holder
    end
    return { holder = holder, glow = glow, kind = gift.kind }
end

local function dropView(id: number)
    local view = views[id]
    if view ~= nil then
        view.holder:Destroy()
        views[id] = nil
    end
end

-- Camera: lin spre jumatatea drumului dintre tine si dar, cat il ai in raza; lin inapoi dupa.
local function updateCamera(dt: number, gift: DriftMath.Gift?, giftX: number?)
    local d = deps :: Deps
    -- [2026-09-30] Altcineva tine camera ("Look (V)", tutorialul): incadrarea darului ramane la zero, ca sa intre iar lin
    -- dupa, nu dintr-un salt. Daca ne-a luat-o chiar din mana, n-o mai tinem (o reluam lin cand se elibereaza).
    if CameraController.HasFocus() and not CameraController.Holds(focusGetter) then
        ownsFocus = false
        focusBlend = 0
        return
    end
    if ownsFocus and not CameraController.Holds(focusGetter) then
        -- camera golita de altcineva: o reluam de la zero, lin
        ownsFocus = false
        focusBlend = 0
    end
    local target = if gift ~= nil then 1 else 0
    local step = if FOCUS_EASE > 0 then dt / FOCUS_EASE else 1
    focusBlend = if target > focusBlend
        then math.min(1, focusBlend + step)
        else math.max(0, focusBlend - step)
    if focusBlend <= 0 then
        if ownsFocus then
            ownsFocus = false
            CameraController.ReleaseFocus(focusGetter)
        end
        return
    end
    local px, py = d.CharacterPos()
    local gy = DriftMath.Y
    local gx = giftX or px
    local ease = focusBlend * focusBlend * (3 - 2 * focusBlend)
    focusX = px + (gx - px) * 0.25 * ease
    focusY = py + ((py + gy) / 2 - py) * ease
    if not ownsFocus then
        if CameraController.HasFocus() then
            return -- altcineva tine camera (tutorialul, o ceremonie): nu ne batem cu el
        end
        ownsFocus = true
        CameraController.SetFocus(focusGetter)
    end
end

local function render(dt: number)
    local d = deps
    local s = seed
    if d == nil or s == nil then
        return
    end
    local now = serverNow()
    local active = DriftMath.activeAt(s, now)
    local seen: { [number]: boolean } = {}
    local px, py = d.CharacterPos()
    local onDeck = py >= STAND_Y0 and py <= STAND_Y1
    local best: DriftMath.Gift? = nil
    local bestX: number? = nil
    for _, gift in active do
        if taken[gift.id] then
            continue
        end
        local x = DriftMath.xAt(gift, now)
        if x == nil then
            continue
        end
        seen[gift.id] = true
        local view = views[gift.id]
        if view == nil then
            view = buildView(d.Plot, gift)
            views[gift.id] = view
        end
        local bob = math.sin(now * 2.4 + gift.id) * 2
        view.holder.Position = UDim2.fromOffset(math.round(x), math.round(gift.y + bob))
        local glow = view.glow
        if glow ~= nil then
            glow.BackgroundTransparency = 0.7 + math.sin(now * 3.1 + gift.id) * 0.1
        end
        -- primul dar al sesiunii si orice bustean de aur se anunta: altfel, pe un ecran mic, nici nu stii ca trece
        if not announced[gift.id] and x >= announceX(px) - 120 then
            announced[gift.id] = true
            if gift.kind == "golden" then
                SoundController.Play("chime", 1.25)
                d.OnToast(Strings.DRIFT_GOLDEN, Theme.COLOR.gold)
            elseif not firstSeen then
                d.OnToast(Strings.driftSeen(gift.kind), Theme.COLOR.gold)
            end
            firstSeen = true
        end
        local reachable = onDeck
            and gift.id > lastTaken
            and DriftMath.canGrab(gift, now, spans)
            and math.abs(x - px) <= DriftMath.REACH
        if reachable and (best == nil or math.abs(x - px) < math.abs((bestX :: number) - px)) then
            best, bestX = gift, x
        end
    end
    for id in views do
        if not seen[id] then
            dropView(id)
        end
    end
    inReach = best
    updateCamera(dt, best, bestX)
end

local function grab()
    local d = deps
    local gift = inReach
    local s = seed
    if d == nil or gift == nil or s == nil or pending[gift.id] or taken[gift.id] then
        return
    end
    pending[gift.id] = true
    taken[gift.id] = true -- optimist: darul pleaca spre tine pe loc; la refuz se intoarce pe apa
    SoundController.Play("splash")
    local view = views[gift.id]
    if view ~= nil then
        views[gift.id] = nil
        local px, py = d.CharacterPos()
        TweenService:Create(
            view.holder,
            TweenInfo.new(FLY_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Position = UDim2.fromOffset(px, py - 30) }
        ):Play()
        task.delay(FLY_SECONDS, function()
            view.holder:Destroy()
        end)
    end
    d.Remotes.GrabDrift:FireServer(gift.id)
    -- fara raspuns (pachet pierdut): dupa 3 s darul reapare, daca mai e pe rau
    local id = gift.id
    task.delay(3, function()
        if pending[id] then
            pending[id] = nil
            taken[id] = nil
        end
    end)
end

-- Cardul `Grab it (E)`. Distanta e micsorata: cat ai un dar in raza, el castiga in fata plasei de langa tine -- trece
-- in douazeci de secunde, plasa ramane acolo.
function DriftController.Focus(px: number, _py: number): Focus.Focus?
    local gift = inReach
    local s = seed
    if deps == nil or gift == nil or s == nil or taken[gift.id] then
        return nil
    end
    local x = DriftMath.xAt(gift, serverNow())
    if x == nil then
        return nil
    end
    local keyHint = if UserInputService.KeyboardEnabled then " (E)" else ""
    return {
        key = `drift:{gift.id}`,
        distance = math.abs(x - px) * 0.25,
        x = x,
        y = gift.y - 30,
        action = Strings.driftCard(keyHint),
        act = grab,
        urgent = true, -- [2026-09-30] trece o singura data: bate si cardul tintei ghidajului, si cartonasul platformei
    }
end

function DriftController.SetHud(
    toHud: (number, number) -> (number, number),
    fly: (number, number, number) -> ()
)
    worldToHud = toHud
    coinFly = fly
end

function DriftController.Init(d: Deps)
    deps = d
    d.RiverConfig.OnClientEvent:Connect(function(config: { [string]: any })
        if typeof(config) == "table" and typeof(config.seed) == "number" then
            seed = config.seed
        end
    end)
    d.Remotes.DriftGrabbed.OnClientEvent:Connect(
        function(giftId: unknown, ok: unknown, reason: unknown, kind: unknown, coins: unknown)
            if typeof(giftId) ~= "number" then
                return
            end
            pending[giftId] = nil
            if ok == true and typeof(coins) == "number" then
                taken[giftId] = true
                lastTaken = math.max(lastTaken, giftId)
                local px, py = d.CharacterPos()
                local toHud, fly = worldToHud, coinFly
                if toHud ~= nil and fly ~= nil then
                    local hx, hy = toHud(px, py - 40)
                    fly(hx, hy, coins)
                end
                SoundController.Play(if kind == "golden" then "chime" else "coin")
            else
                -- refuzat ("gone": a iesit din dreptul puntii; "taken": ai scos deja unul mai nou, sau pe el): fara monede,
                -- dar spus [D43]
                taken[giftId] = if reason == "taken" then true else nil
                if reason == "taken" then
                    d.OnToast(Strings.DRIFT_NEWER)
                elseif reason == "gone" then
                    d.OnToast(Strings.DRIFT_GONE)
                end
            end
        end
    )
    RunService.PreRender:Connect(render)
end

-- [D73] Starea cartierelor (TycoonState.zones: "open" | "locked"), la fiecare stare: din The Mill si din Wire Works se
-- poate scoate darul care trece pe la puntea lor, cat cartierul e deschis.
function DriftController.SetZones(zones: { [string]: string })
    spans = DriftMath.reaches(TycoonConfig.deckSpans(), function(era: number): boolean
        if not TycoonConfig.eraIsLive(era) then
            return false
        end
        for _, zone in TycoonConfig.ZONES do
            if zone.era == era then
                return zones[zone.id] == "open"
            end
        end
        return era == 1
    end)
end

return DriftController
