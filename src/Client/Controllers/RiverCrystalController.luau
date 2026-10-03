--!strict
-- [D68, D75 lotul A1] CRISTALUL DE PE RAU, de la finalul Erei 3: dupa Works Bell, din cand in cand, un cristal care
-- lumineaza pluteste din amonte pe banda cea mai departata a raului. E primul semn al erei cristalelor (barajul): nu se
-- prinde, nu da nimic si nu are card (D68: „se vede plutind pe rau”). Doar in sat; la baraj cristalele vin in plasa lor.
-- Fara desenul urcat (Assets.tycoon.river_crystal, doua cadre de 18 x 16), nu exista.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)

local RiverCrystalController = {}

local SCALE = Assets.PIXEL_SCALE
local SPEED = 38 -- px pe secunda, cam cat un butoi pe rau
local GAP_MIN, GAP_MAX = 45, 90 -- secunde intre doua cristale
local GLINT_SECONDS = 0.45 -- cat tine un cadru al sclipirii
local LANE_Y = RiverConfig.LANE_YS[1] -- banda cea mai departata de mal (D28)

local plot: Frame? = nil
local active = false
local crystal: ImageLabel? = nil
local x = 0
local nextAt = 0
local rng = Random.new()

local function spawn()
    local host = plot
    local sprite = Assets.tycoon.river_crystal
    if host == nil or not Assets.has(sprite) then
        return
    end
    local frameW = sprite.width / 2
    local img = Instance.new("ImageLabel")
    img.Name = "RiverCrystal"
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.ImageRectSize = Vector2.new(frameW, sprite.height)
    img.AnchorPoint = Vector2.new(0.5, 1)
    img.Size = UDim2.fromOffset(frameW * SCALE, sprite.height * SCALE)
    img.ZIndex = 5 + math.clamp(math.floor(LANE_Y / 64), 0, 40)
    img.Parent = host
    crystal = img
    x = -frameW * SCALE
end

-- Pornit dupa Works Bell, doar in sat (Bootstrap). Oprit: cristalul de pe apa pleaca pe loc.
function RiverCrystalController.SetActive(on: boolean)
    if on == active then
        return
    end
    active = on
    nextAt = os.clock() + rng:NextNumber(5, 20)
    if not on then
        local img = crystal
        if img ~= nil then
            img:Destroy()
        end
        crystal = nil
    end
end

function RiverCrystalController.Init(deps: { Plot: Frame })
    plot = deps.Plot
    local width = RiverConfig.WORLD_WIDTH
    local t = 0
    RunService.PreRender:Connect(function(dt: number)
        t += dt
        if not active then
            return
        end
        local img = crystal
        if img == nil then
            if os.clock() >= nextAt then
                spawn()
            end
            return
        end
        x += SPEED * dt
        -- se leagana putin pe val; sclipirea schimba cadrul
        local bob = math.sin(t * 1.7) * 3
        img.Position = UDim2.fromOffset(x, LANE_Y + 12 + bob)
        img.ImageRectOffset =
            Vector2.new(math.floor(t / GLINT_SECONDS) % 2 * img.ImageRectSize.X, 0)
        if x > width + img.Size.X.Offset then
            img:Destroy()
            crystal = nil
            nextAt = os.clock() + rng:NextNumber(GAP_MIN, GAP_MAX)
        end
    end)
end

return RiverCrystalController
