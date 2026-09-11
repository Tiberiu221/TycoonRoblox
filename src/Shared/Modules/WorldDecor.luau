--!strict
-- Unde stau copacii, tufele, pietrele si papura. Modul PUR: aceeasi lume la fiecare intrare,
-- fara sa fie salvata nicaieri, pentru ca totul se recalculeaza din acelasi seed.
-- Decorul NU blocheaza trecerea: altfel un copac aparut langa o usa ar bloca coloniștii,
-- iar jucatorul nu are cum sa-l taie inca.
local Prng = require(script and script.Parent.Prng or "./Prng")

export type Item = { kind: string, x: number, y: number, z: number }
export type Bounds = {
    width: number,
    height: number,
    riverTop: number,
    riverBottom: number,
    plot: { x: number, y: number, w: number, h: number },
}

local WorldDecor = {}

-- Cat de des apare fiecare fel de decor, pe zone. Padurea se ingroasa spre marginile hartii,
-- ca lumea sa se simta inchisa fara un zid vizibil.
local BANK_KINDS = { "cattails", "cattails", "rock_small", "log", "stump" }
local FIELD_KINDS =
    { "tree_round", "tree_pine", "bush", "bush", "rock_small", "flowers", "flowers" }
local EDGE_KINDS = { "tree_pine", "tree_round", "tree_round", "bush" }

local BANK_MARGIN = 150 -- cat de departe de apa se mai considera mal
local KEEP_CLEAR = 90 -- distanta minima fata de drum si fata de terenul jucatorului

local function inRect(
    x: number,
    y: number,
    r: { x: number, y: number, w: number, h: number },
    pad: number
): boolean
    return x > r.x - pad and x < r.x + r.w + pad and y > r.y - pad and y < r.y + r.h + pad
end

-- Cat de aproape e punctul de marginea hartii, 0 in centru si 1 pe margine
local function edgeness(x: number, y: number, b: Bounds): number
    local dx = math.min(x, b.width - x) / (b.width / 2)
    local dy = math.min(y, b.height - y) / (b.height / 2)
    return 1 - math.min(1, math.min(dx, dy))
end

-- Toate obiectele de decor, in ordinea in care trebuie desenate (mai sus = mai in spate).
function WorldDecor.build(seed: number, b: Bounds, count: number): { Item }
    local rng = Prng.new(seed)
    local items: { Item } = {}
    local placed: { Item } = {}

    local function farEnough(x: number, y: number, minDist: number): boolean
        for _, it in placed do
            local dx, dy = it.x - x, it.y - y
            if dx * dx + dy * dy < minDist * minDist then
                return false
            end
        end
        return true
    end

    local attempts = count * 6
    while #items < count and attempts > 0 do
        attempts -= 1
        local x = rng:nextNumber() * b.width
        local y = rng:nextNumber() * b.height

        -- niciodata in apa, pe drum sau pe terenul unde construieste jucatorul
        if y > b.riverTop - 40 and y < b.riverBottom + 40 then
            continue
        end
        if inRect(x, y, b.plot, KEEP_CLEAR) then
            continue
        end

        local nearBank = (y >= b.riverBottom + 40 and y < b.riverBottom + BANK_MARGIN)
            or (y <= b.riverTop - 40 and y > b.riverTop - BANK_MARGIN)
        local edge = edgeness(x, y, b)

        local kinds: { string }
        local minDist: number
        if nearBank then
            kinds, minDist = BANK_KINDS, 120
        elseif edge > 0.55 or rng:nextNumber() < edge then
            kinds, minDist = EDGE_KINDS, 130
        else
            kinds, minDist = FIELD_KINDS, 190
        end

        if not farEnough(x, y, minDist) then
            continue
        end
        local item: Item = {
            kind = kinds[rng:nextInteger(1, #kinds)],
            x = math.round(x),
            y = math.round(y),
            z = 0,
        }
        table.insert(items, item)
        table.insert(placed, item)
    end

    -- sortate dupa y: ce e mai jos pe ecran se deseneaza peste ce e mai sus, ca sa apara adancime
    table.sort(items, function(p: Item, q: Item): boolean
        if p.y == q.y then
            return p.x < q.x
        end
        return p.y < q.y
    end)
    for i, it in items do
        it.z = i
    end
    return items
end

return WorldDecor
