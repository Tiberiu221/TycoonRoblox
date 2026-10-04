--!strict
-- [D75, lotul A2] DECORUL FILMULUI BARAJULUI, pur (fara `game`): unde creste zidul peste raul satului, cat s-a ridicat din
-- fiecare jumatate, pe unde merg siluetele spre rau, unde lucreaza oamenii de pe schele si unde stau macaraua, caruta si
-- gramada de piatra. DamFilm il deseneaza (cu arta lotului A2 cand e urcata; pana atunci zidul e piatra simpla, iar
-- camera tot urca la rau, ca pe cadrul A0 aprobat). Timpul vine din DamMath.frameAt.
--
-- Zidul sta pe aceeasi linie ca in lumea 2 (TycoonConfig.WORLDS[2].wall, x 640-880, pe grila de 3), de la malul de nord la
-- cel de sud al satului: barajul se ridica exact unde va sta.
local RiverConfig =
    require(script and script.Parent.Parent.Config.RiverConfig or "../Config/RiverConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local Shoreline = require(script and script.Parent.Shoreline or "./Shoreline")
local Assets = require(script and script.Parent.Parent.Config.Assets or "../Config/Assets")

local DamFilmSet = {}

DamFilmSet.SCALE = 3 -- un pixel de desen = 3 de lume (Assets.PIXEL_SCALE)
DamFilmSet.PERSON_SCALE = 2.5 -- oamenii: celula de 16 x 24, ca PersonView
DamFilmSet.CELL_W = 16
DamFilmSet.CELL_H = 24
DamFilmSet.BANK_OVERLAP = 12 -- cat intra zidul in fiecare mal
DamFilmSet.WALKERS = 14
DamFilmSet.WALK_SPEED = 120 -- px pe secunda: filmul strange drumul, dar nu alearga
DamFilmSet.WALK_DELAY = 1.0 -- cel mai tarziu pleaca un om, dupa inceputul fazei „people”
DamFilmSet.WALK_FPS = 8 -- ca walk_side (AnimConfig)
DamFilmSet.LIFT_MARGIN = 60 -- plasele de langa linia zidului ies din apa
DamFilmSet.BAR = 0.12 -- benzile negre ale filmului, sus si jos (DamFilm), din inaltimea ecranului
DamFilmSet.FADE_IN = 0.5 -- siluetele apar din amurg, nu dintr-odata
-- [verificatorul A2] pe punte: stalpii plaselor (desenul x2: 28 x 60 de lume, deasupra bazei) si insignele de nivel (56
-- de lume, sub baza) nu se calca; un om (40 x 60) sta la cel putin POST_CLEAR pe x de stalp
DamFilmSet.POST_CLEAR = 48
DamFilmSet.WALKER_GAP_X = 34
DamFilmSet.WALKER_ROWS = { 808, 828, 850 } -- talpile, pe punte (DECK y 772-856)
-- oamenii se strang langa zid, la rasarit de taverna (de acolo drumul spre punte o ocoleste)
DamFilmSet.SPOT_X0 = 540
-- unde nu trec oamenii in drum spre rau: taverna (TycoonConfig.TAVERN) si taraba negustorului de la Landing (desenul ei e
-- cel mult 64 x 44, la x2, pe baza platformei), cu cate 8 px de margine
local function avoidRects(): { { x0: number, x1: number, y0: number, y1: number } }
    local tav = TycoonConfig.TAVERN
    local out = {
        {
            x0 = tav.x - tav.w / 2 - 8,
            x1 = tav.x + tav.w / 2 + 8,
            y0 = tav.y - tav.h - 8,
            y1 = tav.y + 8,
        },
    }
    local stall = TycoonConfig.byId.dock_trader
    if stall ~= nil and stall.x ~= nil then
        local base = TycoonConfig.buildingBase(stall)
        table.insert(out, {
            x0 = (stall.x :: number) - 72,
            x1 = (stall.x :: number) + 72,
            y0 = base - 96,
            y1 = base + 8,
        })
    end
    return out
end
DamFilmSet.AVOID = avoidRects()

local function grid(v: number): number
    return math.round(v / DamFilmSet.SCALE) * DamFilmSet.SCALE
end

export type Wall = { x0: number, x1: number, top: number, bottom: number }

-- Zidul filmului, in coordonatele terenului satului.
function DamFilmSet.wall(): Wall
    local w = (TycoonConfig.WORLDS[2] :: any).wall :: { x: number, w: number }
    local x0 = grid(w.x)
    local x1 = x0 + w.w
    local river = (RiverConfig.WORLDS :: any)[1]
    local cx = (x0 + x1) / 2
    return {
        x0 = x0,
        x1 = x1,
        top = grid(Shoreline.edgeY(river.SHORE_FAR, cx) - DamFilmSet.BANK_OVERLAP),
        bottom = grid(Shoreline.edgeY(river.SHORE_NEAR, cx) + DamFilmSet.BANK_OVERLAP),
    }
end

-- [directorul A2] Randurile zidului filmului (film_wall) pe care un capat neterminat nu se opreste: la nord treapta de sub
-- coama (randurile 24-28 ar lasa o jumatate de treapta peste capatul neterminat), la sud cea de deasupra piciorului (primul
-- rand vazut, 189 - s, nu cade in 125-127). Se sare peste ele, la randul de dupa.
DamFilmSet.SKIP_NORTH = { from = 24, to = 28 }
DamFilmSet.SKIP_SOUTH = { from = 62, to = 64 }

-- Cat s-a ridicat din fiecare jumatate (nord, sud), pe grila, pentru `built` 0..1. La 1 se ating exact.
function DamFilmSet.halves(built: number): (number, number)
    local wall = DamFilmSet.wall()
    local S = DamFilmSet.SCALE
    local span = wall.bottom - wall.top
    local k = math.clamp(built, 0, 1)
    local n = math.round(span / 2 * k / S)
    local s = math.round(span / 2 * k / S)
    if n >= DamFilmSet.SKIP_NORTH.from and n <= DamFilmSet.SKIP_NORTH.to then
        n = DamFilmSet.SKIP_NORTH.to + 1
    end
    if s >= DamFilmSet.SKIP_SOUTH.from and s <= DamFilmSet.SKIP_SOUTH.to then
        s = DamFilmSet.SKIP_SOUTH.to + 1
    end
    local north = n * S
    local south = if k >= 1 then span - north else math.min(s * S, span - north)
    return north, south
end

-- Unde se uita camera cand urca la rau (faza „build”), dupa inaltimea de lume vazuta (`visibleH`, CameraController). Intre
-- benzile negre trebuie sa incapa zidul de la malul de nord pana la puntea cu oamenii; pe un ecran prea scund (telefonul)
-- ramane zidul intreg, care e subiectul, iar puntea iese pe jumatate [verificatorul A2].
function DamFilmSet.camera(visibleH: number?): (number, number)
    local wall = DamFilmSet.wall()
    local x = (wall.x0 + wall.x1) / 2
    local band = (visibleH or 900) * (1 - 2 * DamFilmSet.BAR)
    local top, bottom = wall.top - 12, TycoonConfig.DECK.y1
    if band >= bottom - top then
        return x, math.round((top + bottom) / 2)
    end
    return x, math.round((wall.top + wall.bottom) / 2)
end

-- Plasele care ies din apa cat urca zidul: cele de pe linia lui (First si Second Net).
function DamFilmSet.liftRange(): (number, number)
    local wall = DamFilmSet.wall()
    return wall.x0 - DamFilmSet.LIFT_MARGIN, wall.x1 + DamFilmSet.LIFT_MARGIN
end

-- Oamenii care pleaca spre rau, de pe strada si din curti, si se strang pe punte, in fata zidului. `kind`: randul din foaia
-- siluetelor (0 fara nimic, 1 grinda, 2 piatra, 3 felinar). Determinist: acelasi film la fiecare vizionare.
export type Walker = {
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    delay: number,
    kind: number,
}

-- Stalpii plaselor de pe puntea Landing-ului (x), din config.
function DamFilmSet.deckPosts(): { number }
    local deck = TycoonConfig.DECK
    local out: { number } = {}
    for _, p in TycoonConfig.padsOfWorld(1) do
        local net = false
        for _, e in p.effects do
            net = net or e.kind == "net"
        end
        if net and p.x ~= nil and p.x >= deck.x0 and p.x <= deck.x1 then
            table.insert(out, p.x :: number)
        end
    end
    table.sort(out)
    return out
end

-- Cutia unei recuzite (ancorata jos-mijloc), in lume.
export type Box = { x0: number, x1: number, y0: number, y1: number }
local function propBox(at: { x: number, y: number }, w: number, h: number): Box
    return { x0 = at.x - w / 2, x1 = at.x + w / 2, y0 = at.y - h, y1 = at.y }
end

function DamFilmSet.propBoxes(): { Box }
    local t = Assets.tycoon
    local S = DamFilmSet.SCALE
    local p = DamFilmSet.props()
    return {
        propBox(p.crane, t.film_crane.width / 2 * S, t.film_crane.height * S),
        propBox(p.cart, t.film_stone_cart.width * S, t.film_stone_cart.height * S),
        propBox(p.pile, t.film_stone_pile.width * S, t.film_stone_pile.height * S),
    }
end

-- Cutia unui om (talpile la x, y), la scara oamenilor.
function DamFilmSet.personBox(x: number, y: number): Box
    local w, h =
        DamFilmSet.CELL_W * DamFilmSet.PERSON_SCALE, DamFilmSet.CELL_H * DamFilmSet.PERSON_SCALE
    return { x0 = x - w / 2, x1 = x + w / 2, y0 = y - h, y1 = y }
end

local function overlaps(a: Box, b: Box): boolean
    return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

local function segmentHits(ax: number, ay: number, bx: number, by: number, r: Box): boolean
    for i = 0, 40 do
        local k = i / 40
        local x, y = ax + (bx - ax) * k, ay + (by - ay) * k
        if x > r.x0 and x < r.x1 and y > r.y0 and y < r.y1 then
            return true
        end
    end
    return false
end
DamFilmSet.segmentHits = segmentHits

-- Locurile de pe punte: cat mai aproape de piciorul zidului, departe de stalpi si de recuzita, nu unul peste altul.
function DamFilmSet.spots(): { { x: number, y: number } }
    local wall = DamFilmSet.wall()
    local deck = TycoonConfig.DECK
    local posts = DamFilmSet.deckPosts()
    local props = DamFilmSet.propBoxes()
    local cx = (wall.x0 + wall.x1) / 2
    local candidates: { { x: number, y: number, d: number } } = {}
    for x = math.max(deck.x0 + 24, DamFilmSet.SPOT_X0), deck.x1 - 24, 2 do
        local clear = true
        for _, px in posts do
            if math.abs(x - px) < DamFilmSet.POST_CLEAR then
                clear = false
                break
            end
        end
        if clear then
            for _, y in DamFilmSet.WALKER_ROWS do
                local box = DamFilmSet.personBox(x, y)
                local free = true
                for _, b in props do
                    if overlaps(box, b) then
                        free = false
                        break
                    end
                end
                if free then
                    table.insert(
                        candidates,
                        { x = x, y = y, d = math.abs(x - cx) + (y - 808) * 0.5 }
                    )
                end
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.d ~= b.d then
            return a.d < b.d
        end
        return a.x < b.x
    end)
    local out: { { x: number, y: number } } = {}
    for _, c in candidates do
        local ok = true
        for _, o in out do
            if math.abs(c.x - o.x) < DamFilmSet.WALKER_GAP_X and math.abs(c.y - o.y) < 18 then
                ok = false
                break
            end
        end
        if ok then
            table.insert(out, { x = c.x, y = c.y })
            if #out >= DamFilmSet.WALKERS then
                break
            end
        end
    end
    return out
end

function DamFilmSet.walkers(): { Walker }
    local out: { Walker } = {}
    for i, spot in DamFilmSet.spots() do
        local k = (i - 1) // 2
        local dir = if i % 2 == 1 then -1 else 1
        local fromY = 1180 + (k * 53) % 260
        local fromX = spot.x + dir * (130 + (k % 3) * 50)
        -- drumul ocoleste taverna si taraba: intai pe partea cealalta, apoi mai departe
        for _ = 1, 6 do
            local hit = false
            for _, r in DamFilmSet.AVOID do
                hit = hit or segmentHits(fromX, fromY, spot.x, spot.y, r)
            end
            if not hit then
                break
            end
            dir = -dir
            fromX = spot.x + dir * (130 + (k % 3) * 50 + 60)
        end
        table.insert(out, {
            fromX = fromX,
            fromY = fromY,
            toX = spot.x,
            toY = spot.y,
            delay = ((i * 0.6180339887) % 1) * DamFilmSet.WALK_DELAY,
            kind = (i - 1) % 4,
        })
    end
    return out
end

-- Unde e omul `w` la `t` secunde de la inceputul fazei „people”: pozitia (talpile), daca merge si incotro priveste.
function DamFilmSet.walkerAt(w: Walker, t: number): (number, number, boolean, string)
    local dx, dy = w.toX - w.fromX, w.toY - w.fromY
    local d = math.sqrt(dx * dx + dy * dy)
    local s = math.clamp((t - w.delay) * DamFilmSet.WALK_SPEED, 0, d)
    local k = if d > 0 then s / d else 1
    return w.fromX + dx * k, w.fromY + dy * k, s > 0 and s < d, if dx >= 0 then "right" else "left"
end

-- Cand ajunge omul `w` (secunde de la inceputul fazei „people”).
function DamFilmSet.arrivesAt(w: Walker): number
    local dx, dy = w.toX - w.fromX, w.toY - w.fromY
    return w.delay + math.sqrt(dx * dx + dy * dy) / DamFilmSet.WALK_SPEED
end

-- Oamenii de pe zid, la capetele neterminate ale celor doua jumatati (talpile), cu randul lor din foaia de lucru (0
-- ciocanul, 1 funia) si incotro privesc.
export type Worker = { x: number, y: number, kind: number, facing: string }

function DamFilmSet.workers(built: number): { Worker }
    local wall = DamFilmSet.wall()
    local north, south = DamFilmSet.halves(built)
    local northFront = wall.top + north
    local southFront = wall.bottom - south
    return {
        { x = wall.x0 + 60, y = northFront - 6, kind = 0, facing = "right" },
        { x = wall.x0 + 172, y = northFront - 6, kind = 1, facing = "left" },
        { x = wall.x0 + 84, y = southFront + 24, kind = 1, facing = "right" },
        { x = wall.x0 + 190, y = southFront + 24, kind = 0, facing = "left" },
    }
end

-- Unde stau lucrurile de pe mal (baza, ancorate jos-mijloc), pe punte, in golurile dintre stalpii plaselor
-- [verificatorul A2]: macaraua langa piciorul de est al zidului (intre Second si Third Net), gramada spre apus (inainte de
-- First Net), caruta dupa Far Lane Net; oamenii au locurile dintre First si Second Net si dintre Third si Far Lane Net.
export type Prop = { x: number, y: number }
function DamFilmSet.props(): { crane: Prop, cart: Prop, pile: Prop }
    local wall = DamFilmSet.wall()
    return {
        crane = { x = 920, y = wall.bottom + 40 },
        cart = { x = 1320, y = wall.bottom + 52 },
        pile = { x = 520, y = wall.bottom + 60 },
    }
end

-- Clopotul care suna la inceput (faza „bells”): Works Bell, ultimul clopot al satului; foaia lui de leganat se pune exact
-- peste desenul platformei (ancorat jos-mijloc, la baza cladirii).
function DamFilmSet.bell(): Prop?
    local pad = TycoonConfig.byId.works_bell
    if pad == nil or pad.x == nil or pad.y == nil then
        return nil
    end
    return { x = pad.x :: number, y = TycoonConfig.buildingBase(pad) }
end

-- Cadrul leganarii la `t` secunde (0 stanga, 1 mijloc, 2 dreapta): dus-intors, cate 0,18 s pe cadru.
function DamFilmSet.bellFrame(t: number): number
    local seq = { 1, 0, 1, 2 }
    return seq[math.floor(math.max(0, t) / 0.18) % #seq + 1]
end

return DamFilmSet
