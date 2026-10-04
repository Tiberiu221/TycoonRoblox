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
DamFilmSet.WALK_FPS = 8 -- ca walk_side (AnimConfig)
DamFilmSet.LIFT_MARGIN = 60 -- plasele de langa linia zidului ies din apa
DamFilmSet.BAR = 0.12 -- benzile negre ale filmului, sus si jos (DamFilm), din inaltimea ecranului
DamFilmSet.FADE_IN = 0.5 -- siluetele apar din amurg, nu dintr-odata
-- [verificatorul A2] pe punte: stalpii plaselor (desenul x2: 28 x 60 de lume, deasupra bazei) si insignele de nivel (56
-- de lume, sub baza) nu se calca; un om (40 x 60) sta la cel putin POST_CLEAR pe x de stalp
DamFilmSet.POST_CLEAR = 48
DamFilmSet.WALKER_GAP_X = 34
DamFilmSet.WALKER_ROWS = { 808, 828, 850 } -- talpile, pe punte (DECK y 772-856)

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
-- ramane zidul intreg, care e subiectul, iar puntea cu oamenii iese din cadru [verificatorul A2].
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

-- Oamenii care pleaca spre rau: urca in sir pe cele doua alei ale Landing-ului (a tavernei si a fierului) pana pe punte, apoi
-- merg pe punte la locul lor, in fata zidului [verificatorul A2: in linie dreapta treceau peste depozit, gramada lui si
-- gater]. `path`: drumul (talpile), pe drumuri si pe punte; `kind`: randul din foaia siluetelor (0 fara nimic, 1 grinda,
-- 2 piatra, 3 felinar). Determinist: acelasi film la fiecare vizionare.
export type Point = { x: number, y: number }
export type Walker = {
    path: { Point },
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    delay: number,
    kind: number,
}
DamFilmSet.ALLEYS = { "tavern_link", "iron_lane" } -- TycoonConfig.ROADS
DamFilmSet.DECK_WALK_Y = 864 -- pe marginea de jos a puntii, unde aleile intra in ea
DamFilmSet.COLUMN_STEP = 72 -- cat de departe merge un om de cel din fata lui, pe alee
DamFilmSet.ROW_SHIFT = { 0, 17, -9 } -- randurile de pe punte, decalate: nimeni nu sta exact in spatele altuia

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

-- Ce mai sta pe punte, in afara de stalpi: roata si avizierul satului (desenele lor, ancorate jos-mijloc).
function DamFilmSet.deckObstacles(): { Box }
    local out: { Box } = {}
    local wheel, board = TycoonConfig.WHEEL_STAND, TycoonConfig.VILLAGE_BOARD
    table.insert(out, { x0 = wheel.x - 40, x1 = wheel.x + 40, y0 = wheel.y - 96, y1 = wheel.y })
    table.insert(out, { x0 = board.x - 40, x1 = board.x + 40, y0 = board.y - 88, y1 = board.y })
    return out
end

local function alleyX(id: string): number
    for _, r in TycoonConfig.ROADS do
        if r.id == id then
            return (r.x0 + r.x1) / 2
        end
    end
    error("aleea lipseste: " .. id)
end
DamFilmSet.alleyX = alleyX

-- Un loc de pe punte e liber: departe de stalpi, de recuzita, de roata si de avizier.
local function spotFree(x: number, y: number, posts: { number }, blocked: { Box }): boolean
    for _, px in posts do
        if math.abs(x - px) < DamFilmSet.POST_CLEAR then
            return false
        end
    end
    local box = DamFilmSet.personBox(x, y)
    for _, b in blocked do
        if overlaps(box, b) then
            return false
        end
    end
    return true
end

-- Locurile de pe punte, pe grupuri: cei de pe aleea tavernei stau cat mai aproape de piciorul zidului, cei de pe aleea
-- fierului cat mai aproape de aleea lor. Nu unul peste altul, iar pe randuri vecine nu exact unul in spatele altuia.
export type Spot = { x: number, y: number, alley: string }
function DamFilmSet.spots(): { Spot }
    local wall = DamFilmSet.wall()
    local deck = TycoonConfig.DECK
    local posts = DamFilmSet.deckPosts()
    local blocked = DamFilmSet.propBoxes()
    for _, b in DamFilmSet.deckObstacles() do
        table.insert(blocked, b)
    end
    local out: { Spot } = {}
    local per = math.ceil(DamFilmSet.WALKERS / #DamFilmSet.ALLEYS)
    for g, alley in DamFilmSet.ALLEYS do
        local anchor = if g == 1 then (wall.x0 + wall.x1) / 2 else alleyX(alley)
        local candidates: { { x: number, y: number, d: number } } = {}
        for row, y in DamFilmSet.WALKER_ROWS do
            local shift = DamFilmSet.ROW_SHIFT[row] or 0
            for x = deck.x0 + 24 + shift, deck.x1 - 24, 2 do
                if spotFree(x, y, posts, blocked) then
                    table.insert(
                        candidates,
                        { x = x, y = y, d = math.abs(x - anchor) + (row - 1) * 10 }
                    )
                end
            end
        end
        table.sort(candidates, function(a, b)
            if a.d ~= b.d then
                return a.d < b.d
            end
            return a.x < b.x
        end)
        local taken = 0
        for _, c in candidates do
            local ok = true
            for _, o in out do
                local dy = math.abs(c.y - o.y)
                local dx = math.abs(c.x - o.x)
                if (dy < 18 and dx < DamFilmSet.WALKER_GAP_X) or (dy < 30 and dx < 12) then
                    ok = false
                    break
                end
            end
            if ok then
                table.insert(out, { x = c.x, y = c.y, alley = alley })
                taken += 1
                if taken >= per or #out >= DamFilmSet.WALKERS then
                    break
                end
            end
        end
    end
    return out
end

function DamFilmSet.walkers(): { Walker }
    local out: { Walker } = {}
    local column: { [string]: number } = {}
    for i, spot in DamFilmSet.spots() do
        local ax = alleyX(spot.alley)
        -- in sir pe aleea lui: primul loc (cel mai bun) e al primului om din sir
        local k = column[spot.alley] or 0
        column[spot.alley] = k + 1
        local fromY = DamFilmSet.DECK_WALK_Y + 120 + k * DamFilmSet.COLUMN_STEP
        table.insert(out, {
            path = {
                { x = ax, y = fromY },
                { x = ax, y = DamFilmSet.DECK_WALK_Y },
                { x = spot.x, y = spot.y },
            },
            fromX = ax,
            fromY = fromY,
            toX = spot.x,
            toY = spot.y,
            delay = 0,
            kind = (i - 1) % 4,
        })
    end
    return out
end

local function pathLength(path: { Point }): number
    local total = 0
    for i = 2, #path do
        total += math.sqrt((path[i].x - path[i - 1].x) ^ 2 + (path[i].y - path[i - 1].y) ^ 2)
    end
    return total
end

-- Unde e omul `w` la `t` secunde de la inceputul fazei „people”: pozitia (talpile), daca merge si incotro priveste (pe
-- alee, spre locul lui de pe punte).
function DamFilmSet.walkerAt(w: Walker, t: number): (number, number, boolean, string)
    local total = pathLength(w.path)
    local s = math.clamp((t - w.delay) * DamFilmSet.WALK_SPEED, 0, total)
    local moving = s > 0 and s < total
    local facing = if w.toX >= w.fromX then "right" else "left"
    for i = 2, #w.path do
        local a, b = w.path[i - 1], w.path[i]
        local len = math.sqrt((b.x - a.x) ^ 2 + (b.y - a.y) ^ 2)
        if s <= len or i == #w.path then
            local k = if len > 0 then math.min(1, s / len) else 1
            if math.abs(b.x - a.x) >= 1 then
                facing = if b.x > a.x then "right" else "left"
            end
            return a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, moving, facing
        end
        s -= len
    end
    return w.toX, w.toY, false, facing
end

-- Cand ajunge omul `w` (secunde de la inceputul fazei „people”).
function DamFilmSet.arrivesAt(w: Walker): number
    return w.delay + pathLength(w.path) / DamFilmSet.WALK_SPEED
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
-- [verificatorul A2]: macaraua langa piciorul de est al zidului (intre Second si Third Net), caruta dupa Far Lane Net, gramada
-- dupa Fifth Net (inainte de First Net ar fi stat peste avizierul satului); oamenii au locurile dintre First si Second Net si
-- dintre Third si Far Lane Net.
export type Prop = { x: number, y: number }
function DamFilmSet.props(): { crane: Prop, cart: Prop, pile: Prop }
    local wall = DamFilmSet.wall()
    return {
        crane = { x = 920, y = wall.bottom + 40 },
        cart = { x = 1320, y = wall.bottom + 52 },
        pile = { x = 1500, y = wall.bottom + 60 },
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

-- [verificatorul A2] Inaltimea de la care porneste camera la clopot: mijlocul desenului lui Works Bell (pe telefon, la
-- strada, banda neagra de sus ii taia corpul); de acolo coboara lin spre strada cat trece privirea.
function DamFilmSet.bellMidY(): number?
    local bell = DamFilmSet.bell()
    if bell == nil then
        return nil
    end
    return bell.y - Assets.tycoon.works_bell.height * DamFilmSet.SCALE / 2
end

-- Cadrul leganarii la `t` secunde (0 stanga, 1 mijloc, 2 dreapta): dus-intors, cate 0,18 s pe cadru.
function DamFilmSet.bellFrame(t: number): number
    local seq = { 1, 0, 1, 2 }
    return seq[math.floor(math.max(0, t) / 0.18) % #seq + 1]
end

return DamFilmSet
