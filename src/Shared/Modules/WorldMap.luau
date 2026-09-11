--!strict
-- Modul PUR: coliziuni simple pe dreptunghiuri (raul, cladirile, marginile lumii) [DECIZII D09]
local WorldMap = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Config = {
    WORLD_WIDTH: number,
    WORLD_HEIGHT: number,
    RIVER_TOP: number,
    RIVER_BOTTOM: number,
    BUILDINGS: { { x: number, y: number, w: number, h: number } },
}

-- `buildings` sunt cladirile ASEZATE, din starea serverului. Cand lipsesc, se cade inapoi pe
-- lista din configuratie, care e o ramasita de la prototip: acolo sunt case care nu se deseneaza
-- nicaieri, deci jucatorul se lovea de ziduri invizibile, iar cladirile lui reale nu opreau deloc.
function WorldMap.blockedRects(cfg: Config, buildings: { Rect }?): { Rect }
    local rects: { Rect } =
        { { x = 0, y = cfg.RIVER_TOP, w = cfg.WORLD_WIDTH, h = cfg.RIVER_BOTTOM - cfg.RIVER_TOP } }
    for _, b in buildings or cfg.BUILDINGS do
        table.insert(rects, { x = b.x, y = b.y, w = b.w, h = b.h })
    end
    return rects
end

-- Punctul (picioarele personajului) e blocat daca e in afara lumii sau intr-un dreptunghi blocat
function WorldMap.isBlocked(rects: { Rect }, cfg: Config, x: number, y: number): boolean
    if x < 16 or y < 16 or x > cfg.WORLD_WIDTH - 16 or y > cfg.WORLD_HEIGHT - 16 then
        return true
    end
    for _, r in rects do
        if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
            return true
        end
    end
    return false
end

return WorldMap
