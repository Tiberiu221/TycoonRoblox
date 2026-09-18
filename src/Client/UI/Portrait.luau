--!strict
-- [D61] PORTRETUL unui om intr-o tinuta: cadrul "sta pe loc, cu fata" (sau alt rand al foii), din cele trei straturi
-- [D44] -- corpul si parul colorate cu tint, tinuta deasupra. Pana la D61 acelasi desen era copiat in trei locuri
-- (avizierul satului, vitrina negustorului, cardul altui om), fiecare cu corpul "b", parul lung si doua culori batute
-- in cuie. Acum infatisarea vine din profil (LookMath), iar desenul sta intr-un singur loc.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local LookMath = require(ReplicatedStorage.Shared.Modules.LookMath)

local Portrait = {}

-- Randul din foaie (AnimConfig.ROWS) pentru fiecare fel de a sta: din fata, din profil, din spate.
Portrait.FACINGS = { "down", "side", "up" }
local ROW_OF: { [string]: string } = { down = "idle_down", side = "idle_side", up = "idle_up" }

local function rowIndex(facing: string): number
    local row = (AnimConfig.ROWS :: any)[ROW_OF[facing] or "idle_down"]
    return if row ~= nil then row.index else 3
end

-- Sterge portretul vechi din `holder` si il deseneaza pe cel nou, ancorat jos la mijloc. `look` nil = chipul de la
-- inceput. Intoarce false daca foile inca nu sunt urcate (nu deseneaza nimic: apelantul isi lasa fundalul).
function Portrait.draw(
    holder: GuiObject,
    outfit: string,
    look: LookMath.Look?,
    width: number,
    height: number,
    z: number,
    facing: string?
): boolean
    for _, child in holder:GetChildren() do
        if child:IsA("ImageLabel") and child.Name == "PortraitLayer" then
            child:Destroy()
        end
    end
    local r = LookMath.resolve(look)
    local bodySheet = (Assets.people.body :: any)[r.body]
    local outfitSheet = (Assets.people.outfit :: any)[outfit]
    if
        bodySheet == nil
        or outfitSheet == nil
        or not Assets.has(bodySheet)
        or not Assets.has(outfitSheet)
    then
        return false
    end
    local offset = Vector2.new(0, AnimConfig.FRAME_HEIGHT * rowIndex(facing or "down"))
    local function layer(sheet: Assets.Sprite, tint: Color3?, order: number)
        local img = Instance.new("ImageLabel")
        img.Name = "PortraitLayer"
        img.BackgroundTransparency = 1
        img.Image = Assets.url(sheet)
        img.ResampleMode = Enum.ResamplerMode.Pixelated
        img.ImageRectOffset = offset
        img.ImageRectSize = Vector2.new(AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT)
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromScale(0.5, 1)
        img.Size = UDim2.fromOffset(width, height)
        img.ImageColor3 = tint or Color3.new(1, 1, 1)
        img.ZIndex = z + order
        img.Parent = holder
    end
    layer(bodySheet, Color3.fromRGB(r.skin[1], r.skin[2], r.skin[3]), 0)
    -- o coafura fara foaie urcata ("bald") nu are strat, ca la oamenii din sat (UI/PersonView)
    local hairSheet = (Assets.people.hair :: any)[r.hair]
    if hairSheet ~= nil and Assets.has(hairSheet) then
        layer(hairSheet, Color3.fromRGB(r.hairColor[1], r.hairColor[2], r.hairColor[3]), 1)
    end
    layer(outfitSheet, nil, 2)
    return true
end

return Portrait
