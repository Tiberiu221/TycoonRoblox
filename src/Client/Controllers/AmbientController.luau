--!strict
-- [D62, pasul 5] VIATA DIN SAT care nu tine de economie: pasarile care trec peste harta. Auditul D62: "sprite-urile sunt
-- bune, dar lumea sta pe loc" -- in afara oamenilor tai si a apei, nimic nu se misca.
--
-- O pasare (uneori doua-trei, in sir) trece de la vest la est, la cateva zeci de secunde. Zboara PESTE tot (copaci,
-- case, oameni), iar umbra ei aluneca pe pamant, putin mai jos: asa se citeste ca e sus, intr-o lume vazuta de sus.
-- Doar desen: nu se atinge, nu da nimic, nu are sunet. Fara desenul urcat (Assets.props.bird), nu exista pasari.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)

local AmbientController = {}

local SCALE = 3
local FRAME = 8 -- foaia are doua cadre de 8x8: aripile sus, aripile jos
local FLAP_HZ = 5
local SPEED_MIN, SPEED_MAX = 95, 135
local GAP_MIN, GAP_MAX = 22, 48 -- secunde intre doua treceri
local SHADOW_DROP = 46 -- cat de jos cade umbra: cat de sus pare pasarea
local Z = 60 -- peste tot ce e in lume (personajul are 6, decorul pana la 45)

type Bird = { img: ImageLabel, shadow: Frame, x: number, y: number, speed: number, phase: number }
local birds: { Bird } = {}
local layer: Frame? = nil
local nextAt = 0
local rng = Random.new()

local function spawn(y: number, x: number, speed: number)
    local host = layer
    if host == nil then
        return
    end
    local shadow = Instance.new("Frame")
    shadow.Name = "BirdShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.Size = UDim2.fromOffset(14, 5)
    shadow.BackgroundColor3 = Color3.fromRGB(20, 26, 18)
    shadow.BackgroundTransparency = 0.72
    shadow.BorderSizePixel = 0
    shadow.ZIndex = Z - 1
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = shadow
    shadow.Parent = host

    local img = Instance.new("ImageLabel")
    img.Name = "Bird"
    img.BackgroundTransparency = 1
    img.Image = Assets.url(Assets.props.bird)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.ImageRectSize = Vector2.new(FRAME, FRAME)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Size = UDim2.fromOffset(FRAME * SCALE, FRAME * SCALE)
    img.ZIndex = Z
    img.Parent = host
    table.insert(birds, {
        img = img,
        shadow = shadow,
        x = x,
        y = y,
        speed = speed,
        phase = rng:NextNumber() * 10,
    })
end

local function step(dt: number)
    local now = os.clock()
    if now >= nextAt then
        nextAt = now + rng:NextNumber(GAP_MIN, GAP_MAX)
        -- una, sau un sir scurt, pe aceeasi linie, usor decalate
        local count = if rng:NextNumber() < 0.35 then rng:NextInteger(2, 3) else 1
        local y = rng:NextNumber(260, RiverConfig.WORLD_HEIGHT - 260)
        local speed = rng:NextNumber(SPEED_MIN, SPEED_MAX)
        for i = 1, count do
            spawn(y + (i - 1) * 22 * (if i % 2 == 0 then 1 else -1), -40 - (i - 1) * 46, speed)
        end
    end
    for i = #birds, 1, -1 do
        local b = birds[i]
        b.x += b.speed * dt
        if b.x > RiverConfig.WORLD_WIDTH + 60 then
            b.img:Destroy()
            b.shadow:Destroy()
            table.remove(birds, i)
            continue
        end
        local glide = math.sin((now + b.phase) * 0.9) * 6 -- un mic val in zbor, nu o linie trasa cu rigla
        local frame = math.floor((now + b.phase) * FLAP_HZ) % 2
        b.img.ImageRectOffset = Vector2.new(frame * FRAME, 0)
        b.img.Position = UDim2.fromOffset(math.round(b.x), math.round(b.y + glide))
        b.shadow.Position = UDim2.fromOffset(math.round(b.x + 10), math.round(b.y + SHADOW_DROP))
    end
end

function AmbientController.Init(deps: { Scroll: Frame })
    if not Assets.has(Assets.props.bird) then
        return -- desenul inca neurcat: fara pasari, fara nimic de calculat
    end
    local host = Instance.new("Frame")
    host.Name = "Ambient"
    host.BackgroundTransparency = 1
    host.Size = UDim2.fromScale(1, 1)
    host.ZIndex = Z
    host.Parent = deps.Scroll
    layer = host
    nextAt = os.clock() + 6 -- prima trece repede dupa intrare, ca lumea sa para vie din primul minut
    RunService.PreRender:Connect(step)
end

return AmbientController
