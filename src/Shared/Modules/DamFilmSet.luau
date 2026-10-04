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

-- Cat s-a ridicat din fiecare jumatate (nord, sud), pe grila, pentru `built` 0..1. La 1 se ating exact.
function DamFilmSet.halves(built: number): (number, number)
    local wall = DamFilmSet.wall()
    local span = wall.bottom - wall.top
    local k = math.clamp(built, 0, 1)
    local north = grid(span / 2 * k)
    local south = if k >= 1 then span - north else grid(span / 2 * k)
    return north, south
end

-- Unde se uita camera cand urca la rau (faza „build”): mijlocul zidului, putin spre sud, ca puntea cu oamenii sa ramana in
-- cadru.
function DamFilmSet.camera(): (number, number)
    local wall = DamFilmSet.wall()
    return (wall.x0 + wall.x1) / 2, math.round((wall.top + wall.bottom) / 2 + 90)
end

-- Plasele care ies din apa cat urca zidul: cele de pe linia lui (First si Second Net).
function DamFilmSet.liftRange(): (number, number)
    local wall = DamFilmSet.wall()
    return wall.x0 - DamFilmSet.LIFT_MARGIN, wall.x1 + DamFilmSet.LIFT_MARGIN
end

-- Oamenii care pleaca spre rau: jumatate din partea tavernei (spre dreapta), jumatate dinspre curtea fierului (spre
-- stanga), si se strang pe punte, in fata zidului. `kind`: randul din foaia siluetelor (0 fara nimic, 1 grinda, 2 piatra,
-- 3 felinar). Determinist: acelasi film la fiecare vizionare.
export type Walker = {
    fromX: number,
    fromY: number,
    toX: number,
    toY: number,
    delay: number,
    kind: number,
}

function DamFilmSet.walkers(): { Walker }
    local out: { Walker } = {}
    for i = 1, DamFilmSet.WALKERS do
        local left = i % 2 == 1
        local k = (i - 1) // 2
        table.insert(out, {
            fromX = if left then 260 + k * 38 else 1500 - k * 48,
            fromY = 1440 - (k * 53) % 260,
            toX = if left then 520 + k * 34 else 1000 - k * 30,
            toY = 806 + (k % 3) * 18,
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

-- Unde stau lucrurile de pe mal (baza, ancorate jos-mijloc), langa piciorul de sud al zidului, pe punte.
export type Prop = { x: number, y: number }
function DamFilmSet.props(): { crane: Prop, cart: Prop, pile: Prop }
    local wall = DamFilmSet.wall()
    return {
        crane = { x = wall.x1 + 48, y = wall.bottom + 40 },
        cart = { x = wall.x0 - 70, y = wall.bottom + 52 },
        pile = { x = wall.x1 + 130, y = wall.bottom + 60 },
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
