--!strict
-- ROTILE CARE SE INVART [D67, dupa auditul din 2026-09-24]. Turbina si roata de apa aveau un singur desen, deci stateau
-- pe loc, desi planul Erei 3 promitea "palete care se invart". Foaia lor de miscare (scripts/art: d65_mill.spin_sheet)
-- are cadre patrate alaturate, in care se misca doar roata; aici se muta fereastra imaginii (ImageRectOffset) pe cadrul
-- ceasului. Cat foaia nu e urcata (id 0), desenul ramane cel fix: nimic nu se strica.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Spin = {}

-- [verificatorul A1] `frameW`: latimea unui cadru = latimea desenului fix (turbina barajului are cadre de 16 x 20, nu patrate)
export type Sheet = { sprite: Assets.Sprite, frames: number, fps: number, frameW: number }

-- desenul fix -> foaia lui de miscare; cadre pe secunda: turbina e iute, roata de apa grea
local SHEETS: { { still: string, sheet: string, fps: number } } = {
    { still = "turbine", sheet = "turbine_spin", fps = 8 },
    { still = "water_wheel", sheet = "water_wheel_spin", fps = 5 },
    { still = "dam_turbine", sheet = "dam_turbine_spin", fps = 8 }, -- [verificatorul A1] turbina din zidul barajului
}

-- Foaia de miscare a unui desen fix, daca exista si e urcata.
function Spin.sheetOf(still: Assets.Sprite?): Sheet?
    if still == nil then
        return nil
    end
    local tycoon = Assets.tycoon :: any
    for _, row in SHEETS do
        local sheet: Assets.Sprite? = tycoon[row.sheet]
        if tycoon[row.still] == still and sheet ~= nil and Assets.has(sheet) then
            local frameW = math.max(1, still.width)
            return {
                sprite = sheet,
                frames = math.max(1, sheet.width // frameW),
                fps = row.fps,
                frameW = frameW,
            }
        end
    end
    return nil
end

-- Pune foaia pe imagine, pe primul cadru. Marimea imaginii ramane a desenului fix (cadrul e cat el).
function Spin.apply(img: ImageLabel, sheet: Sheet)
    img.Image = Assets.url(sheet.sprite)
    img.ImageRectSize = Vector2.new(sheet.frameW, sheet.sprite.height)
    img.ImageRectOffset = Vector2.zero
end

-- Cadrul ceasului `now` (secunde); scrie doar cand cadrul se schimba.
function Spin.step(img: ImageLabel, sheet: Sheet, now: number)
    local frame = math.floor(now * sheet.fps) % sheet.frames
    local x = frame * sheet.frameW
    if img.ImageRectOffset.X ~= x then
        img.ImageRectOffset = Vector2.new(x, 0)
    end
end

return Spin
