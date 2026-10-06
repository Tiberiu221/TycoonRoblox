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

-- Felurile de decor pe zone (mal, camp, margine). Fara ele, cele ale satului de mai sus.
export type Kinds = { bank: { string }, field: { string }, edge: { string } }
WorldDecor.VILLAGE_KINDS = { bank = BANK_KINDS, field = FIELD_KINDS, edge = EDGE_KINDS } :: Kinds
-- [owner, 2026-10-06: „tot iarba ramane? parca nu a evoluat deloc jocul"] La baraj, padurea s-a taiat pentru zid si
-- pentru case: pe camp raman cioturi, busteni, pietre si butoaie, fara flori; copacii mai stau doar spre margini.
WorldDecor.DAM_KINDS = {
    bank = { "rock_small", "rock_large", "log", "stump", "cattails" },
    field = { "stump", "stump", "log", "rock_small", "rock_large", "barrel" },
    edge = { "tree_pine", "tree_round", "tree_pine", "stump" },
} :: Kinds

-- [D65] Cat ocupa pe ecran fiecare fel de decor (latime, inaltime, in pixeli de lume): desenul lui din Assets.props la
-- PIXEL_SCALE 3, prins de baza. Modulul ramane pur, deci cifrele stau aici; un test le tine legate de Assets.
WorldDecor.FOOTPRINT = {
    tree_round = { 144, 192 },
    tree_pine = { 120, 228 },
    bush = { 96, 84 },
    rock_small = { 60, 60 },
    stump = { 72, 60 },
    log = { 108, 54 },
    cattails = { 84, 114 },
    flowers = { 78, 66 },
    rock_large = { 96, 96 },
    barrel = { 66, 84 },
} :: { [string]: { number } }

-- Un loc pe care decorul n-are voie sa-l ACOPERE (casa unui om si numele de sub ea): un lucru e scos daca desenul lui
-- intra peste dreptunghi si sta IN FATA lui (baza mai jos decat `frontOf`); in spatele casei, un copac e la locul lui.
export type Clear = { x0: number, x1: number, y0: number, y1: number, frontOf: number }

local function covers(item: Item, clear: Clear): boolean
    local size = WorldDecor.FOOTPRINT[item.kind]
    if size == nil or item.y <= clear.frontOf then
        return false
    end
    local x0, x1 = item.x - size[1] / 2, item.x + size[1] / 2
    local y0, y1 = item.y - size[2], item.y
    return x0 < clear.x1 and x1 > clear.x0 and y0 < clear.y1 and y1 > clear.y0
end

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
function WorldDecor.build(seed: number, b: Bounds, count: number, kindsOf: Kinds?): { Item }
    local zones = kindsOf or WorldDecor.VILLAGE_KINDS
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
            kinds, minDist = zones.bank, 120
        elseif edge > 0.55 or rng:nextNumber() < edge then
            kinds, minDist = zones.edge, 130
        else
            kinds, minDist = zones.field, 190
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

-- [D65] DECORUL SATULUI, acelasi pentru joc (SceneArt) si pentru pamantul copt (scripts/art/village_geometry.luau).
-- Generatorul isi alege x-ul ca `aleator x latime`, deci a lati lumea ar fi mutat FIECARE copac al satului pe care
-- jucatorii il stiu deja. De aceea partea veche se genereaza exact ca inainte (latimea si terenul de dinainte de D65,
-- aceeasi samanta si acelasi numar), apoi:
--   * se scot lucrurile cazute pe terenul cartierelor noi (acolo se construieste);
--   * fasia noua de lume isi primeste decorul ei, cu alta samanta, proportional cu latimea ei;
--   * la urma se scot lucrurile care ar ACOPERI un loc din `clear` (casele oamenilor si numele lor): terenul fara
--     decor se opreste sub randul de case, iar un copac inalt cu baza chiar sub el le acoperea numele [vazut de owner
--     la Moara, 2026-09-21]. In satul vechi nu cade niciunul pe o casa, deci ramane cum era (test).
-- `river` = { riverTop, riverBottom }, ca la `build`.
-- [D67] `world.strips`: fasiile de dupa partea veche, fiecare cu marginea ei din dreapta si terenul ei fara decor, in
-- ordinea in care au venit (Moara, apoi Wire Works). Fasia k are samanta `seed + k` si numarul ei de lucruri, deci una
-- noua nu muta nimic din cele de dinainte. Fara `strips`: o singura fasie pana la `width`, cu `plot` (ca pana la D67).
export type Strip = { x1: number, plot: { x: number, y: number, w: number, h: number } }
function WorldDecor.village(
    seed: number,
    count: number,
    world: {
        width: number,
        height: number,
        oldWidth: number,
        strips: { Strip }?,
    },
    river: { riverTop: number, riverBottom: number },
    plot: { x: number, y: number, w: number, h: number },
    oldPlot: { x: number, y: number, w: number, h: number },
    clear: { Clear }?,
    kindsOf: Kinds?
): { Item }
    local items: { Item } = {}
    local old = WorldDecor.build(seed, {
        width = world.oldWidth,
        height = world.height,
        riverTop = river.riverTop,
        riverBottom = river.riverBottom,
        plot = oldPlot,
    }, count, kindsOf)
    for _, item in old do
        if not inRect(item.x, item.y, plot, KEEP_CLEAR) then
            table.insert(items, item)
        end
    end
    local strips: { Strip } = world.strips or { { x1 = world.width, plot = plot } }
    local x0 = world.oldWidth
    for k, strip in strips do
        local width = strip.x1 - x0
        if width > 0 then
            local extra = WorldDecor.build(seed + k, {
                width = width,
                height = world.height,
                riverTop = river.riverTop,
                riverBottom = river.riverBottom,
                -- terenul fasiei, vazut din ea (x-ul ei porneste de la 0)
                plot = {
                    x = strip.plot.x - x0,
                    y = strip.plot.y,
                    w = strip.plot.w,
                    h = strip.plot.h,
                },
            }, math.floor(count * width / world.oldWidth + 0.5), kindsOf)
            for _, item in extra do
                -- [D67] ca la partea veche: ce cade pe terenul de azi (un cartier construit dupa fasia asta) se scoate
                local wx = item.x + x0
                if not inRect(wx, item.y, plot, KEEP_CLEAR) then
                    table.insert(items, { kind = item.kind, x = wx, y = item.y, z = item.z })
                end
            end
        end
        x0 = math.max(x0, strip.x1)
    end
    if clear ~= nil then
        local kept: { Item } = {}
        for _, item in items do
            local hides = false
            for _, c in clear do
                if covers(item, c) then
                    hides = true
                    break
                end
            end
            if not hides then
                table.insert(kept, item)
            end
        end
        items = kept
    end
    return items
end

return WorldDecor
