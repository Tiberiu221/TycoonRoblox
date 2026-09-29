--!strict
-- [D70] CE APARE PE HARTA CAT SATUL SE MODERNIZEAZA IN ERA 3: stalpii cu sarma pe toata strada (treapta 1), tamburii de
-- cablu din curtea goala a Wire Works (1), statia de transformare de langa ei, masa cu planurile barajului si tarusii
-- topografilor pe linia viitorului zid (4). Locurile sunt in TycoonConfig (testate: nu calca nimic), desenul in
-- ModernConfig. Comun satului (ModernController) si satului vizitat din balci (VillageDiorama). Totul se face o data,
-- apoi `set(treapta)` doar arata sau ascunde; fara arta urcata, nimic nu se deseneaza.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local ModernConfig = require(ReplicatedStorage.Shared.Config.ModernConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local ModernProps = {}

export type Props = { set: (stage: number) -> () }

local tycoon = Assets.tycoon :: any
local SCALE = Assets.PIXEL_SCALE -- stalpii, tamburii, statia: cladiri (x3)
local PROP = TycoonConfig.PROP_SCALE -- masa si tarusii: recuzita mica (x2)
local STRING_COLOR = Color3.fromRGB(196, 58, 44) -- sfoara rosie a topografilor

-- Adancimea dupa baza, pe aceeasi scara ca cladirile liniilor (5 + y/64): oamenii din fata (6 + y/64) trec peste.
local function depth(y: number): number
    return 5 + math.clamp(math.floor(y / 64), 0, 40)
end

local function image(parent: GuiObject, sprite: Assets.Sprite, scale: number, z: number): ImageLabel
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.Image = Assets.url(sprite)
    img.ResampleMode = Enum.ResamplerMode.Pixelated
    img.Size = UDim2.fromOffset(sprite.width * scale, sprite.height * scale)
    img.ZIndex = z
    img.Visible = false
    img.Parent = parent
    return img
end

-- O linie dreapta de grosime `t` intre doua puncte (un Frame rotit).
local function segment(
    parent: GuiObject,
    ax: number,
    ay: number,
    bx: number,
    by: number,
    t: number,
    color: Color3,
    z: number
): Frame
    local dx, dy = bx - ax, by - ay
    local line = Instance.new("Frame")
    line.Name = "Wire"
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
    line.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, t)
    line.Rotation = math.deg(math.atan2(dy, dx))
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.ZIndex = z
    line.Visible = false
    line.Parent = parent
    return line
end

-- Un fir lasat intre doua puncte (ModernConfig.wirePoint), din 8 bucati.
local function wire(
    parent: GuiObject,
    a: Vector2,
    b: Vector2,
    color: Color3,
    z: number,
    into: { GuiObject }
)
    local pieces = 8
    local px, py = a.X, a.Y
    for i = 1, pieces do
        local x, y = ModernConfig.wirePoint(a.X, a.Y, b.X, b.Y, i / pieces)
        table.insert(into, segment(parent, px, py, x, y, ModernConfig.WIRE.thickness, color, z))
        px, py = x, y
    end
end

local function rgb(c: { number }): Color3
    return Color3.fromRGB(c[1], c[2], c[3])
end

-- Face tot ce apare pe teren in `parent` (in coordonatele terenului) si il arata dupa treapta.
function ModernProps.draw(parent: GuiObject, stage: number): Props
    local byStage: { { stage: number, items: { GuiObject } } } = {}
    local function group(from: number): { GuiObject }
        local items: { GuiObject } = {}
        table.insert(byStage, { stage = from, items = items })
        return items
    end
    if not TycoonConfig.eraIsLive(3) then
        return { set = function(_stage: number) end }
    end

    -- treapta 1: stalpii si firele
    local wireItems = group(1)
    local line, lineEnd = tycoon.wire_pole, tycoon.wire_pole_end
    if Assets.has(line) and Assets.has(lineEnd) then
        local poles = TycoonConfig.wirePoles()
        for _, pole in poles do
            local isEnd = pole.kind == "end"
            local sprite: Assets.Sprite = if isEnd then lineEnd else line
            local postX = if isEnd
                then ModernConfig.WIRE_POLE_END.postX
                else ModernConfig.WIRE_POLE_POST_X
            local img = image(parent, sprite, SCALE, depth(pole.y))
            img.Name = "WirePole"
            -- prins de baza, cu stalpul (nu marginea foii) pe x-ul lui
            local anchorPx = if pole.mirror then sprite.width - postX else postX
            img.AnchorPoint = Vector2.new(anchorPx / sprite.width, 1)
            img.Position = UDim2.fromOffset(pole.x, pole.y)
            if pole.mirror then
                img.ImageRectOffset = Vector2.new(sprite.width, 0)
                img.ImageRectSize = Vector2.new(-sprite.width, sprite.height)
            end
            table.insert(wireItems, img)
        end
        -- firele dintre stalpi; de la treapta 4, si cel pana la izolatorul de pe acoperisul Power House
        local feed: { x: number, y: number }? = nil
        local house = TycoonConfig.byId[ModernConfig.POWER_FEED.pad]
        local houseArt = tycoon.power_house
        if
            house ~= nil
            and house.live
            and house.x ~= nil
            and house.y ~= nil
            and houseArt ~= nil
            and Assets.has(houseArt)
        then
            local fx, fy = ModernConfig.feedPoint(
                house.x :: number,
                TycoonConfig.buildingBase(house),
                houseArt.width,
                houseArt.height,
                SCALE
            )
            feed = { x = fx, y = fy }
        end
        local z = depth(TycoonConfig.WIRE_POLE_BASE_Y)
        for _, span in ModernConfig.wireSpans(poles, line.height, SCALE, feed) do
            local color = if span.which == "near"
                then ModernConfig.WIRE.colorNear
                else ModernConfig.WIRE.colorFar
            wire(
                parent,
                Vector2.new(span.ax, span.ay),
                Vector2.new(span.bx, span.by),
                rgb(color),
                z,
                if span.stage <= 1 then wireItems else group(span.stage)
            )
        end
    end

    -- recuzita curtii Wire Works: tamburii de la treapta lor, statia de la a ei
    for _, prop in TycoonConfig.FIELD_PROPS do
        local art = tycoon[prop.sprite]
        if art ~= nil and Assets.has(art) then
            local img = image(parent, art, SCALE, depth(prop.y))
            img.Name = "FieldProp"
            img.AnchorPoint = Vector2.new(0.5, 1)
            img.Position = UDim2.fromOffset(prop.x, prop.y)
            table.insert(group(prop.stage), img)
        end
    end

    -- treapta 4: masa cu planurile barajului si tarusii topografilor, cu sfoara intre ei
    local damItems = group(4)
    local plans = tycoon.dam_plans
    if Assets.has(plans) then
        local img = image(parent, plans, PROP, depth(TycoonConfig.DAM_PLANS.y))
        img.Name = "DamPlans"
        img.AnchorPoint = Vector2.new(0.5, 1)
        img.Position = UDim2.fromOffset(TycoonConfig.DAM_PLANS.x, TycoonConfig.DAM_PLANS.y)
        table.insert(damItems, img)
    end
    local stakes = tycoon.survey_stakes
    if Assets.has(stakes) then
        local frame = ModernConfig.SURVEY_STAKE.frame
        local knots: { Vector2 } = {}
        for _, stake in TycoonConfig.SURVEY_STAKES do
            local img = image(parent, stakes, PROP, depth(stake.y))
            img.Name = "SurveyStake"
            img.Size = UDim2.fromOffset(frame.w * PROP, frame.h * PROP)
            img.ImageRectOffset = Vector2.new(stake.frame * frame.w, 0)
            img.ImageRectSize = Vector2.new(frame.w, frame.h)
            img.AnchorPoint = Vector2.new(0.5, 1)
            img.Position = UDim2.fromOffset(stake.x, stake.y)
            table.insert(damItems, img)
            local knot = ModernConfig.SURVEY_STAKE.string[stake.frame]
            if knot ~= nil then
                table.insert(
                    knots,
                    Vector2.new(
                        stake.x + (knot.x - frame.w / 2) * PROP,
                        stake.y - (frame.h - knot.y) * PROP
                    )
                )
            end
        end
        for i = 2, #knots do
            local a, b = knots[i - 1], knots[i]
            table.insert(
                damItems,
                segment(
                    parent,
                    a.X,
                    a.Y,
                    b.X,
                    b.Y,
                    2,
                    STRING_COLOR,
                    depth(TycoonConfig.SURVEY_STAKES[1].y)
                )
            )
        end
    end

    local function set(s: number)
        for _, g in byStage do
            local show = s >= g.stage
            for _, item in g.items do
                if item.Visible ~= show then
                    item.Visible = show
                end
            end
        end
    end
    set(stage)
    return { set = set }
end

return ModernProps
