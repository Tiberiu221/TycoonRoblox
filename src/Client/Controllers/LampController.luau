--!strict
-- [D67] FELINARELE DE PE STRADA. Roadmap-ul owner-ului (D64): cu curentul electric, "satul se lumineaza". Stau intre
-- case, pe marginea de sud a strazii fiecarui cartier in joc (TycoonConfig.streetLamps): stinse pana la primul curent
-- vandut, apoi aprinse, cu lumina lor calda dedesubt. Prima aprindere se anunta, ca nimic sa nu se intample in tacere
-- [D43]; cine intra in joc cu ele deja aprinse nu mai primeste anuntul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local LampController = {}

type Lamp = { post: ImageLabel, glow: ImageLabel }

local lamps: { Lamp } = {}
local lit: boolean? = nil -- nil = inca nicio stare de la server
local onFirstLight: (() -> ())? = nil

-- capul felinarului, de la baza: foaia are 40 px, iar sticla sta pe randurile 4..11 (scripts/art/d67_works.py)
local HEAD_ABOVE_BASE = (40 - 7) * Assets.PIXEL_SCALE

local function image(parent: GuiObject, sprite: Assets.Sprite, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size =
        UDim2.fromOffset(sprite.width * Assets.PIXEL_SCALE, sprite.height * Assets.PIXEL_SCALE)
    img.ZIndex = z
    img.Parent = parent
    return img
end

function LampController.Init(deps: { Plot: GuiObject, OnFirstLight: (() -> ())? })
    onFirstLight = deps.OnFirstLight
    local spots = TycoonConfig.streetLamps()
    if #spots == 0 or not Assets.has(Assets.tycoon.street_lamp) then
        return
    end
    local layer = Instance.new("Frame")
    layer.Name = "LampLayer"
    layer.BackgroundTransparency = 1
    layer.Size = UDim2.fromScale(1, 1)
    layer.ZIndex = 5
    layer.Parent = deps.Plot
    for _, spot in spots do
        -- aceeasi adancime ca decorul imprastiat (SceneArt): ce e mai jos acopera ce e mai sus
        local z = 5 + math.clamp(math.floor(spot.y / 64), 0, 40)
        local glow = image(layer, Assets.tycoon.lamp_glow, z - 1)
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.fromOffset(spot.x, spot.y - HEAD_ABOVE_BASE)
        glow.ResampleMode = Enum.ResamplerMode.Default -- lumina e moale, nu in pixeli
        glow.Visible = false
        local post = image(layer, Assets.tycoon.street_lamp, z)
        post.AnchorPoint = Vector2.new(0.5, 1)
        post.Position = UDim2.fromOffset(spot.x, spot.y)
        table.insert(lamps, { post = post, glow = glow })
    end
end

-- `on` = s-a vandut deja curent (TycoonState.firsts.power).
function LampController.Apply(on: boolean)
    if lit == on then
        return
    end
    local justNow = lit == false and on -- aprinse chiar acum, nu gasite aprinse la intrare
    lit = on
    local sprite = if on and Assets.has(Assets.tycoon.street_lamp_lit)
        then Assets.tycoon.street_lamp_lit
        else Assets.tycoon.street_lamp
    for _, lamp in lamps do
        lamp.post.Image = Assets.url(sprite)
        lamp.glow.Visible = on and Assets.has(Assets.tycoon.lamp_glow)
    end
    if justNow and #lamps > 0 and onFirstLight ~= nil then
        onFirstLight()
    end
end

return LampController
