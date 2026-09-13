--!strict
-- Un om desenat din straturi [D44]: umbra, corp, par, tinuta, plus un obiect tinut (sacul unui om care
-- cara, scandura unui client). Doar desenul si animatia: unde sta, ce face si daca se poate atinge
-- decide cine il foloseste -- oamenii tai (HandRenderController) si clientii tavernei
-- (DockController) [D50]. Scos din HandRenderController, ca un client sa nu fie o copie a lui.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AnimConfig = require(ReplicatedStorage.Shared.Config.AnimConfig)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)

export type Appearance = {
    body: string,
    hair: string,
    skin: { number },
    hairColor: { number },
    outfit: string,
}

export type View = {
    frame: Frame,
    -- x, y = picioarele; task = "working" | "idle"; facing = "left" | "right" | "up" | "down"
    Pose: (x: number, y: number, task: string, facing: string, moving: boolean, dt: number) -> (),
    SetAppearance: (appearance: Appearance) -> (),
    -- 0 = nu tine nimic; 1..4 = treapta sacului (creste cu ce duce), la scandura doar 0/1
    SetHeld: (step: number) -> (),
    Destroy: () -> (),
}

local PersonView = {}

PersonView.WIDTH, PersonView.HEIGHT = 40, 60 -- aceeasi cutie ca la colonisti
local W, H = AnimConfig.FRAME_WIDTH, AnimConfig.FRAME_HEIGHT

-- Sacul creste in TREPTE, ca cel al jucatorului (NetController) [research 42 pct.3].
local SACK_STEP_SCALE = { 0.6, 0.85, 1.05, 1.3 }

local function rgbOf(triple: { number }): Color3
    return Color3.fromRGB(triple[1] or 255, triple[2] or 255, triple[3] or 255)
end

local function setIfChanged(inst: Instance, prop: string, value: any)
    if (inst :: any)[prop] ~= value then
        (inst :: any)[prop] = value
    end
end

-- Decupeaza un cadru din foaia de 16x24: randurile "side" se oglindesc pentru mers spre stanga.
local function setFrame(img: ImageLabel, row: AnimConfig.Row, frameIndex: number, facing: string)
    local mirror = row.side and facing == "left"
    local offset = if mirror
        then Vector2.new(W * frameIndex + W, H * row.index)
        else Vector2.new(W * frameIndex, H * row.index)
    local size = if mirror then Vector2.new(-W, H) else Vector2.new(W, H)
    setIfChanged(img, "ImageRectOffset", offset)
    setIfChanged(img, "ImageRectSize", size)
end

local function layer(parent: Instance, name: string, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.Name = name
    img.BackgroundTransparency = 1
    img.Size = UDim2.fromScale(1, 1)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.ZIndex = z
    img.Parent = parent
    return img
end

-- `held` = "sack" | "plank" | nil
function PersonView.new(parent: Instance, name: string, held: string?): View
    local holder = Instance.new("Frame")
    holder.Name = name
    holder.Size = UDim2.fromOffset(PersonView.WIDTH, PersonView.HEIGHT)
    holder.AnchorPoint = Vector2.new(0.5, 1)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 6
    holder.Parent = parent

    if Assets.has(Assets.shadow) then
        local sh = Instance.new("ImageLabel")
        sh.Name = "Shadow"
        sh.Image = Assets.url(Assets.shadow)
        sh.ResampleMode = Enum.ResamplerMode.Pixelated
        sh.BackgroundTransparency = 1
        sh.AnchorPoint = Vector2.new(0.5, 0.5)
        sh.Position = UDim2.new(0.5, 0, 1, -2)
        sh.Size = UDim2.fromOffset(28, 10)
        sh.ImageTransparency = 0.25
        sh.ZIndex = 5
        sh.Parent = holder
    end

    -- Straturile [D44] pornesc doar daca foile chiar exista. Fara ele, o silueta simpla tinuta.
    local layered = Assets.has(Assets.people.body.a) and Assets.has(Assets.people.outfit.Fisher)
    local body = layer(holder, "Body", 6)
    if layered then
        body.ImageRectSize = Vector2.new(W, H)
    else
        body.BackgroundTransparency = 0
        body.BackgroundColor3 = Color3.fromRGB(63, 127, 191) -- rezerva cat timp lipsesc foile
    end
    local hair = if layered then layer(holder, "Hair", 7) else nil
    local outfit = if layered then layer(holder, "Outfit", 8) else nil

    -- Obiectul tinut: sacul pe spate (creste in trepte), scandura in brate.
    local item: ImageLabel? = nil
    local itemScale: UIScale? = nil
    local sprite = if held == "sack"
        then Assets.tycoon.sack
        elseif held == "plank" then Assets.goods.planks
        else nil
    if sprite ~= nil and Assets.has(sprite) then
        local s = Instance.new("ImageLabel")
        s.Name = if held == "sack" then "Sack" else "Plank"
        s.BackgroundTransparency = 1
        s.Image = Assets.url(sprite)
        s.ResampleMode = Enum.ResamplerMode.Pixelated
        s.AnchorPoint = Vector2.new(0.5, 1)
        if held == "sack" then
            s.Position = UDim2.fromScale(0.5, 0.65)
            s.Size = UDim2.fromOffset(
                sprite.width * Assets.PIXEL_SCALE * 0.55,
                sprite.height * Assets.PIXEL_SCALE * 0.55
            )
        else
            s.Position = UDim2.fromScale(0.5, 0.8)
            s.Size = UDim2.fromOffset(sprite.width * 1.5, sprite.height * 1.5)
        end
        s.ZIndex = 9
        s.Visible = false
        s.Parent = holder
        item = s
        if held == "sack" then
            local scale = Instance.new("UIScale")
            scale.Parent = s
            itemScale = scale
        end
    end

    local appearance: Appearance? = nil
    local animTime = 0
    local rowId = ""

    local view: View = {
        frame = holder,
        SetAppearance = function(a: Appearance)
            appearance = a
        end,
        SetHeld = function(step: number)
            local img = item
            if img == nil then
                return
            end
            setIfChanged(img, "Visible", step > 0)
            local scale = itemScale
            if scale ~= nil then
                setIfChanged(scale, "Scale", SACK_STEP_SCALE[math.clamp(step, 1, 4)])
            end
        end,
        Pose = function(
            x: number,
            y: number,
            task: string,
            facing: string,
            moving: boolean,
            dt: number
        )
            holder.Position = UDim2.fromOffset(math.round(x), math.round(y))
            setIfChanged(holder, "ZIndex", 6 + math.clamp(math.floor(y / 64), 0, 40))

            local row = AnimConfig.rowFor(task, facing, moving, nil, nil)
            if row.id ~= rowId then
                rowId = row.id
                animTime = 0
            else
                animTime += dt * row.fps
            end
            local frameIndex = math.floor(animTime) % AnimConfig.FRAMES_PER_ROW
            setFrame(body, row, frameIndex, facing)

            local a = appearance
            if a == nil then
                return
            end
            if hair ~= nil or outfit ~= nil then
                local bodySheet = (Assets.people.body :: any)[a.body]
                if bodySheet ~= nil then
                    setIfChanged(body, "Image", Assets.url(bodySheet))
                end
                setIfChanged(body, "ImageColor3", rgbOf(a.skin))
            end
            if hair ~= nil then
                local hairSheet = (Assets.people.hair :: any)[a.hair]
                if hairSheet ~= nil and Assets.has(hairSheet) then
                    setIfChanged(hair, "Image", Assets.url(hairSheet))
                    setIfChanged(hair, "ImageTransparency", 0)
                    setIfChanged(hair, "ImageColor3", rgbOf(a.hairColor))
                    setFrame(hair, row, frameIndex, facing)
                else
                    setIfChanged(hair, "ImageTransparency", 1) -- chel: foaia nu s-a incarcat (id 0)
                end
            end
            if outfit ~= nil then
                local outfitSheet = (Assets.people.outfit :: any)[a.outfit]
                if outfitSheet ~= nil and Assets.has(outfitSheet) then
                    setIfChanged(outfit, "Image", Assets.url(outfitSheet))
                    setIfChanged(outfit, "ImageTransparency", 0)
                    setFrame(outfit, row, frameIndex, facing)
                else
                    setIfChanged(outfit, "ImageTransparency", 1)
                end
            end
        end,
        Destroy = function()
            holder:Destroy()
        end,
    }
    return view
end

return PersonView
