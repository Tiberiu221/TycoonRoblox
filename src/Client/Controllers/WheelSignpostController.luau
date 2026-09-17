--!strict
-- [D60] UNDE STATEA ROATA. Roata zilnica s-a mutat in balci; pe punte, in locul timonierului, sta un indicator cu
-- "Wheel moved to the fair", ca nimeni sa n-o caute degeaba [D43]. Cand rotirea zilnica e gata, indicatorul are inelul
-- auriu al locurilor care te cheama, cardul lui spune ca rotirea te asteapta in balci, iar un toast o spune o data, cand
-- devine gata. Barca spre balci e chiar langa el.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local Strings = require(ReplicatedStorage.Shared.Config.Strings)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local Focus = require(script.Parent.Parent.UI.Focus)
local GroundShadow = require(script.Parent.Parent.UI.GroundShadow)
local Theme = require(script.Parent.Parent.UI.Theme)
local Widgets = require(script.Parent.Parent.UI.Widgets)

export type Deps = { Plot: Frame, OnToast: (string, Color3?) -> () }
export type Snapshot = { ready: boolean, secondsLeft: number, spins: number }

local WheelSignpostController = {}
local deps: Deps? = nil

local STAND = TycoonConfig.WHEEL_STAND
local SPRITE = Assets.props.signpost
local SCALE = 2
local W, H = SPRITE.width * SCALE, SPRITE.height * SCALE

local ring: ImageLabel? = nil
local secondsLeft = math.huge -- pana la prima stare: nu se aprinde nimic
local wasReady: boolean? = nil

local function isReady(): boolean
    return secondsLeft <= 0
end

local function refresh()
    local ready = isReady()
    local r = ring
    if r ~= nil then
        r.Visible = ready
    end
    local d = deps
    if wasReady == false and ready and d ~= nil then
        d.OnToast(Strings.WHEEL_READY_AT_FAIR, Theme.COLOR.gold)
    end
    wasReady = ready
end

-- Din TycoonState: ceasul rotirii zilnice (profilul e acelasi; roata o invarti in balci).
function WheelSignpostController.Apply(snap: Snapshot?)
    if snap == nil then
        return
    end
    secondsLeft = if snap.ready then 0 else math.max(1, snap.secondsLeft)
    refresh()
end

-- Cardul: doar spune unde e roata acum (E il repeta ca toast). Actiunea e barca de alaturi.
function WheelSignpostController.Focus(px: number, py: number): Focus.Focus?
    if deps == nil then
        return nil
    end
    local distance = Focus.distance(px, py, STAND.x, STAND.y - 20)
    if distance > RiverConfig.INTERACT_DISTANCE then
        return nil
    end
    return {
        key = "wheel_moved",
        distance = distance,
        x = STAND.x,
        y = STAND.y - H - 8,
        status = if isReady() then Strings.WHEEL_READY_AT_FAIR else Strings.WHEEL_MOVED,
    }
end

function WheelSignpostController.Init(d: Deps)
    deps = d
    GroundShadow.add(d.Plot, UDim2.fromOffset(STAND.x, STAND.y), W * 0.8, 3, 0.35)
    if Assets.has(Assets.ui.groundring) then
        local r = Instance.new("ImageLabel")
        r.Name = "WheelMovedRing"
        r.BackgroundTransparency = 1
        r.Image = Assets.url(Assets.ui.groundring)
        r.ResampleMode = Enum.ResamplerMode.Pixelated
        r.ImageColor3 = Theme.COLOR.gold
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.fromOffset(STAND.x, STAND.y - 4)
        r.Size = UDim2.fromOffset(Assets.ui.groundring.width * 3, Assets.ui.groundring.height * 3)
        r.ZIndex = 3
        r.Visible = false
        r.Parent = d.Plot
        ring = r
    end

    local post = Instance.new("ImageLabel")
    post.Name = "WheelMoved"
    post.BackgroundTransparency = 1
    post.AnchorPoint = Vector2.new(0.5, 1)
    post.Position = UDim2.fromOffset(STAND.x, STAND.y)
    post.Size = UDim2.fromOffset(W, H)
    post.ZIndex = 4
    if Assets.has(SPRITE) then
        post.Image = Assets.url(SPRITE)
        post.ResampleMode = Enum.ResamplerMode.Pixelated
    else
        post.BackgroundTransparency = 0
        post.BackgroundColor3 = Theme.COLOR.wood
    end
    post.Parent = d.Plot

    local tag =
        Widgets.Label(post, Strings.WHEEL_MOVED_TAG, Theme.TEXT.tiny, Theme.COLOR.onDark, "strong")
    tag.AnchorPoint = Vector2.new(0.5, 0)
    tag.Position = UDim2.new(0.5, 0, 1, 2)
    tag.Size = UDim2.fromOffset(W + 104, 30) -- doua randuri
    tag.TextXAlignment = Enum.TextXAlignment.Center
    tag.ZIndex = 5
    Theme.punch(tag, 2)

    -- ceasul coboara pe client intre doua stari, ca inelul sa se aprinda la timp si fara o stare noua
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        local r = ring
        if r ~= nil and r.Visible then
            r.ImageTransparency = 0.25 + 0.25 * (math.sin(os.clock() * 3.2) + 1) / 2
        end
        if secondsLeft <= 0 or secondsLeft == math.huge then
            return
        end
        acc += dt
        if acc < 1 then
            return
        end
        secondsLeft = math.max(0, secondsLeft - acc)
        acc = 0
        refresh()
    end)
end

return WheelSignpostController
