--!strict
-- Umbra de sub un obiect asezat pe pamant [D57]. Owner-ul, pe harta: "texturile obiectelor (taverna sawmill forge etc)
-- parca plutesc mereu, nu fac parte din realul absolut al jocului". Oamenii si copacii aveau umbra, cladirile nu: un
-- obiect fara umbra pare lipit deasupra fundalului, chiar asezat corect [docs/research/44-harta-vie.md; Slynyrd,
-- "Cast shadows help make objects feel like they actually connect with the ground"].
--
-- Elipsa moale de sub oameni (Assets.shadow), lata cat obiectul si turtita, impinsa putin spre dreapta (lumina din
-- stanga-sus, ca pe toata harta). Fara arta, un Frame rotunjit si transparent tine locul.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local GroundShadow = {}

-- `position` = baza obiectului (mijlocul ei), in coordonatele lui `parent`; `width` = latimea obiectului; `z` = sub el.
-- `strength` 0..1: cat de intunecata (implicit 0.55; ruinele si recuzita mica, mai slab).
function GroundShadow.add(
    parent: Instance,
    position: UDim2,
    width: number,
    z: number,
    strength: number?
): GuiObject
    local alpha = strength or 0.55
    local w = math.floor(width * 1.18)
    local h = math.max(10, math.floor(width * 0.22))
    local shadow: GuiObject
    if Assets.has(Assets.shadow) then
        local img = Instance.new("ImageLabel")
        img.BackgroundTransparency = 1
        img.Image = Assets.url(Assets.shadow)
        img.ImageTransparency = 1 - alpha
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        shadow = img
    else
        local f = Instance.new("Frame")
        f.BackgroundColor3 = Color3.fromRGB(20, 30, 18)
        f.BackgroundTransparency = 1 - alpha * 0.6
        f.BorderSizePixel = 0
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = f
        shadow = f
    end
    shadow.Name = "GroundShadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    -- centrul putin sub baza si spre dreapta: umbra "cade" din obiect, nu il inconjoara
    shadow.Position = position + UDim2.fromOffset(math.floor(width * 0.06), 2)
    shadow.Size = UDim2.fromOffset(w, h)
    shadow.ZIndex = z
    shadow.Parent = parent
    return shadow
end

return GroundShadow
