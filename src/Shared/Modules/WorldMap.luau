--!strict
-- Modul PUR: coliziuni simple pe dreptunghiuri (raul, cladirile, marginile lumii) [DECIZII D09]
local WorldMap = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Config = {
    WORLD_WIDTH: number,
    WORLD_HEIGHT: number,
    RIVER_TOP: number,
    RIVER_BOTTOM: number,
}
-- [D59] O trecere prin rau: pontonul lung. De la malul raului in sus pana la `y0`, intre `x0` si `x1` (marginile nu).
export type Passage = { x0: number, x1: number, y0: number }

-- Doar raul blocheaza acum [F0 spec 4.6]: platformele, plasele si debarcaderul NU blocheaza --
-- jucatorul trebuie sa poata calca pe o platforma ca sa o cumpere. `extra` ramane un parametru
-- optional (nu mai vine din RiverConfig.BUILDINGS, care a disparut o data cu coliziunea de colonie)
-- pentru orice obstacol viitor care chiar trebuie sa opreasca mersul.
-- [D59] `passage`: pontonul intra in rau, iar jucatorul merge pe el pana la capat, unde pescuieste. Banda raului se
-- sparge atunci in trei: stanga pontonului, dreapta lui si apa de dincolo de capatul lui.
function WorldMap.blockedRects(cfg: Config, extra: { Rect }?, passage: Passage?): { Rect }
    local top, height = cfg.RIVER_TOP, cfg.RIVER_BOTTOM - cfg.RIVER_TOP
    local rects: { Rect }
    if passage == nil then
        rects = { { x = 0, y = top, w = cfg.WORLD_WIDTH, h = height } }
    else
        rects = {
            { x = 0, y = top, w = passage.x0, h = height },
            { x = passage.x1, y = top, w = cfg.WORLD_WIDTH - passage.x1, h = height },
            { x = passage.x0, y = top, w = passage.x1 - passage.x0, h = passage.y0 - top },
        }
    end
    for _, b in extra or {} do
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
