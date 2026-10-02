--!strict
-- [D67] FELINARELE DE PE STRADA, ca desen: stalpii dintre case (TycoonConfig.streetLamps), stinsi sau aprinsi cu lumina
-- lor calda dedesubt. Comun satului (LampController, care stie cand se aprind) si satului vizitat din balci
-- (VillageDiorama): [D67, audit] macheta nu avea deloc felinare, deci satul altuia ramanea mereu "dinainte de curent".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local StreetLamps = {}

-- `set`: aprinse sau stinse; `show`: se vad sau nu [D73]: apar odata cu stalpii si sarma, treapta "wire" a modernizarii
export type Lamps = { set: (on: boolean) -> (), show: (visible: boolean) -> (), count: number }

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

-- Deseneaza felinarele in `parent` (terenul, in coordonatele lui) si le aprinde sau stinge dupa `on`. Stau DIRECT pe
-- teren, fiecare cu adancimea bazei lui, pe aceeasi scara ca oamenii (PersonView) si cladirile liniilor
-- (LineController): ce e mai jos acopera ce e mai sus. [D67, audit] Intr-un strat comun cu z 5, felinarul de langa Foundry si Wire Works isi pierdea
-- varful sub cladire (z 26), desi sta in fata ei.
function StreetLamps.draw(parent: GuiObject, on: boolean): Lamps
    local spots = TycoonConfig.streetLamps()
    if #spots == 0 or not Assets.has(Assets.tycoon.street_lamp) then
        return {
            set = function(_on: boolean) end,
            show = function(_visible: boolean) end,
            count = 0,
        }
    end
    local posts: { ImageLabel } = {}
    local glows: { ImageLabel } = {}
    for _, spot in spots do
        -- stalpul pe scara oamenilor (PersonView: 6 + y/64): cine merge pe strada, in spatele lui (talpile mai sus),
        -- trece pe sub el; lumina ramane sub oameni
        local depth = math.clamp(math.floor(spot.y / 64), 0, 40)
        local z = 6 + depth
        local glow = image(parent, Assets.tycoon.lamp_glow, 5 + depth)
        glow.Name = "StreetLampGlow"
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.Position = UDim2.fromOffset(spot.x, spot.y - HEAD_ABOVE_BASE)
        glow.ResampleMode = Enum.ResamplerMode.Default -- lumina e moale, nu in pixeli
        glow.Visible = false
        local post = image(parent, Assets.tycoon.street_lamp, z)
        post.Name = "StreetLamp"
        post.AnchorPoint = Vector2.new(0.5, 1)
        post.Position = UDim2.fromOffset(spot.x, spot.y)
        table.insert(posts, post)
        table.insert(glows, glow)
    end
    local lit = on
    local shown = true
    local function apply()
        local sprite = if lit and Assets.has(Assets.tycoon.street_lamp_lit)
            then Assets.tycoon.street_lamp_lit
            else Assets.tycoon.street_lamp
        for i, post in posts do
            post.Image = Assets.url(sprite)
            post.Visible = shown
            glows[i].Visible = shown and lit and Assets.has(Assets.tycoon.lamp_glow)
        end
    end
    local function show(visible: boolean)
        shown = visible
        apply()
    end
    local function set(value: boolean)
        lit = value
        apply()
    end
    apply()
    return { set = set, show = show, count = #posts }
end

return StreetLamps
