--!strict
-- Graful drumurilor [D50]. Modul PUR, acelasi pe server (cat dureaza drumul unui om, deci cand ajunge
-- la plasa) si pe client (unde il desenezi mergand si pe unde curge dara de ghidaj).
--
-- Drumurile sunt dreptunghiuri care doar SE ATING: capatul unuia cade pe marginea altuia (legatura
-- depozitului se termina la y 856, exact unde incepe puntea). Din intersectii n-ar iesi niciun graf,
-- deci regula e alta: fiecare drum e linia lui de mijloc, iar un capat de linie care cade IN alt drum
-- (marginile incluse) se leaga printr-un ciot perpendicular de linia aceluia. Cel mai scurt drum iese
-- din Dijkstra, pe cateva zeci de noduri.
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")

export type Point = { x: number, y: number }
export type Rect = { x0: number, x1: number, y0: number, y1: number }
type Seg = { a: Point, b: Point, horizontal: boolean, nodes: { number } }
type Edge = { to: number, d: number }
-- [D70, dupa verificatorul j8] `blocked`: cutiile pe care nu se merge nici pe iarba (la baraj, zidul si canalul): scurtatura
-- si pasul de pe iarba pana la drum le ocolesc. In sat nu sunt.
export type Graph = {
    points: { Point },
    edges: { { Edge } },
    segs: { Seg },
    rects: { Rect },
    blocked: { Rect },
}

local RoadGraph = {}

-- Cat "costa" un pas pe iarba fata de unul pe drum. Drumul se ia doar cand scurtatura peste iarba ar fi
-- mai mult de jumatate din el: de la spawn la prima plasa (311 px in linie dreapta), drumul ar fi
-- coborat pana la drumul mare si ar fi urcat inapoi pe legatura tavernei -- 826 px, un ocol care arata
-- ca o greseala chiar la primul pas al tutorialului.
RoadGraph.GRASS_COST = 2

local function dist(a: Point, b: Point): number
    local dx, dy = b.x - a.x, b.y - a.y
    return math.sqrt(dx * dx + dy * dy)
end

local function same(a: Point, b: Point): boolean
    return math.abs(a.x - b.x) < 0.5 and math.abs(a.y - b.y) < 0.5
end

local function inside(p: Point, r: Rect): boolean
    return p.x >= r.x0 and p.x <= r.x1 and p.y >= r.y0 and p.y <= r.y1
end

local function addPoint(g: Graph, p: Point): number
    for i, q in g.points do
        if same(p, q) then
            return i
        end
    end
    table.insert(g.points, { x = p.x, y = p.y })
    table.insert(g.edges, {})
    return #g.points
end

local function link(g: Graph, i: number, j: number)
    if i == j then
        return
    end
    for _, e in g.edges[i] do
        if e.to == j then
            return
        end
    end
    local d = dist(g.points[i], g.points[j])
    table.insert(g.edges[i], { to = j, d = d })
    table.insert(g.edges[j], { to = i, d = d })
end

-- Punctul de pe linia unui drum cel mai apropiat de `p`.
local function project(s: Seg, p: Point): Point
    if s.horizontal then
        return { x = math.clamp(p.x, s.a.x, s.b.x), y = s.a.y }
    end
    return { x = s.a.x, y = math.clamp(p.y, s.a.y, s.b.y) }
end

local function along(s: Seg, p: Point): number
    return if s.horizontal then p.x else p.y
end

-- Segmentul a-b trece prin interiorul cutiei (atinsul marginii nu conteaza): Liang-Barsky.
local function cuts(a: Point, b: Point, r: Rect): boolean
    local dx, dy = b.x - a.x, b.y - a.y
    local t0, t1 = 0, 1
    for _, pq in
        { { -dx, a.x - r.x0 }, { dx, r.x1 - a.x }, { -dy, a.y - r.y0 }, { dy, r.y1 - a.y } }
    do
        local p, q = pq[1], pq[2]
        if p == 0 then
            if q <= 0 then
                return false
            end
        else
            local t = q / p
            if p < 0 then
                t0 = math.max(t0, t)
            else
                t1 = math.min(t1, t)
            end
            if t0 >= t1 then
                return false
            end
        end
    end
    return t0 < t1
end
-- Un pas drept de la a la b trece printr-o cutie blocata a grafului?
function RoadGraph.blockedBetween(g: Graph, a: Point, b: Point): boolean
    for _, r in g.blocked do
        if cuts(a, b, r) then
            return true
        end
    end
    return false
end

function RoadGraph.build(rects: { Rect }, blocked: { Rect }?): Graph
    local g: Graph = { points = {}, edges = {}, segs = {}, rects = rects, blocked = blocked or {} }
    for _, r in rects do
        if r.x1 - r.x0 >= r.y1 - r.y0 then
            local y = (r.y0 + r.y1) / 2
            table.insert(g.segs, {
                a = { x = r.x0, y = y },
                b = { x = r.x1, y = y },
                horizontal = true,
                nodes = {},
            })
        else
            local x = (r.x0 + r.x1) / 2
            table.insert(g.segs, {
                a = { x = x, y = r.y0 },
                b = { x = x, y = r.y1 },
                horizontal = false,
                nodes = {},
            })
        end
    end
    for _, s in g.segs do
        table.insert(s.nodes, addPoint(g, s.a))
        table.insert(s.nodes, addPoint(g, s.b))
    end
    -- cioturile: capatul unei linii care cade intr-un alt drum se leaga de linia aceluia
    for i, s in g.segs do
        for _, tip in { s.a, s.b } do
            for j, r in rects do
                if j ~= i and inside(tip, r) then
                    local other = g.segs[j]
                    local foot = addPoint(g, project(other, tip))
                    table.insert(other.nodes, foot)
                    link(g, addPoint(g, tip), foot)
                end
            end
        end
    end
    for _, s in g.segs do
        table.sort(s.nodes, function(u: number, v: number): boolean
            return along(s, g.points[u]) < along(s, g.points[v])
        end)
        for k = 2, #s.nodes do
            link(g, s.nodes[k - 1], s.nodes[k])
        end
    end
    return g
end

-- Un drum care nu se leaga de restul ar trimite oamenii si dara pe nicaieri, fara nicio eroare.
function RoadGraph.connected(g: Graph): boolean
    if #g.points == 0 then
        return true
    end
    local seen: { [number]: boolean } = { [1] = true }
    local stack = { 1 }
    local count = 1
    while #stack > 0 do
        local u = table.remove(stack) :: number
        for _, e in g.edges[u] do
            if not seen[e.to] then
                seen[e.to] = true
                count += 1
                table.insert(stack, e.to)
            end
        end
    end
    return count == #g.points
end

function RoadGraph.length(points: { Point }): number
    local total = 0
    for i = 2, #points do
        total += dist(points[i - 1], points[i])
    end
    return total
end

-- Scoate punctele din mijlocul unei linii drepte parcurse in acelasi sens: ocolul ramane acelasi,
-- dar un om nu se mai opreste in dreptul fiecarui nod. O intoarcere pe aceeasi linie ramane.
local function simplify(points: { Point }): { Point }
    if #points <= 2 then
        return points
    end
    local out = { points[1] }
    for i = 2, #points - 1 do
        local a, b, c = out[#out], points[i], points[i + 1]
        local cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
        local dot = (b.x - a.x) * (c.x - b.x) + (b.y - a.y) * (c.y - b.y)
        if math.abs(cross) > 1e-6 or dot <= 0 then
            table.insert(out, b)
        end
    end
    table.insert(out, points[#points])
    return out
end

-- Drumul de la `from` la `to`: intri pe drum in cel mai apropiat punct, mergi pe drumuri, iesi in
-- dreptul tintei. Primul punct e `from`, ultimul `to`. Cand drumurile ar ocoli prea mult (vezi
-- GRASS_COST), linie dreapta.
-- [D70, pasul k10] `roadsOnly`: fara scurtatura pe iarba (oamenii la plimbare prin oras nu calca straturile de flori);
-- implicit, ca inainte.
function RoadGraph.route(g: Graph, from: Point, to: Point, roadsOnly: boolean?): { Point }
    local direct = { { x = from.x, y = from.y }, { x = to.x, y = to.y } }
    if #g.segs == 0 then
        return direct
    end
    -- amandoua capetele pe acelasi drum: linia dreapta E pe drum. Fara asta, intre doua plase de pe
    -- punte omul cobora 2 px pana la linia de mijloc si urca inapoi, la fiecare plasa.
    for _, r in g.rects do
        if inside(from, r) and inside(to, r) then
            return direct
        end
    end

    -- [D70] cel mai apropiat punct de drum la care ajungi pe iarba fara sa treci printr-o cutie blocata (altfel, cel mai
    -- apropiat oricum: un punct inchis intre cutii n-are alta iesire)
    local function nearest(p: Point): (Point, number)
        local best, bestSeg, bestD = p, 1, math.huge
        local free, freeSeg, freeD = p, 1, math.huge
        for i, s in g.segs do
            local q = project(s, p)
            local d = dist(p, q)
            if d < bestD then
                best, bestSeg, bestD = q, i, d
            end
            if d < freeD and not RoadGraph.blockedBetween(g, p, q) then
                free, freeSeg, freeD = q, i, d
            end
        end
        if freeD < math.huge then
            return free, freeSeg
        end
        return best, bestSeg
    end

    -- intrarea si iesirea devin noduri temporare, legate de vecinii lor de pe linie
    local n = #g.points
    local S, T = n + 1, n + 2
    local entry, entrySeg = nearest(from)
    local exit, exitSeg = nearest(to)
    local extra: { [number]: { Edge } } = {}
    local function pointAt(k: number): Point
        return if k == S then entry elseif k == T then exit else g.points[k]
    end
    local function extraLink(i: number, j: number)
        local d = dist(pointAt(i), pointAt(j))
        extra[i] = extra[i] or {}
        extra[j] = extra[j] or {}
        table.insert(extra[i], { to = j, d = d })
        table.insert(extra[j], { to = i, d = d })
    end
    local function attach(k: number, segIndex: number)
        local s = g.segs[segIndex]
        local at = along(s, pointAt(k))
        local before: number? = nil
        local after: number? = nil
        for _, u in s.nodes do
            local v = along(s, g.points[u])
            if v <= at then
                before = u
            end
            if v >= at and after == nil then
                after = u
            end
        end
        if before ~= nil then
            extraLink(k, before)
        end
        if after ~= nil and after ~= before then
            extraLink(k, after)
        end
    end
    attach(S, entrySeg)
    attach(T, exitSeg)
    if entrySeg == exitSeg then
        extraLink(S, T)
    end

    local best: { [number]: number } = { [S] = 0 }
    local prev: { [number]: number } = {}
    local done: { [number]: boolean } = {}
    while true do
        local u: number? = nil
        local du = math.huge
        for k, d in best do
            if not done[k] and d < du then
                u, du = k, d
            end
        end
        if u == nil or u == T then
            break
        end
        local here = u :: number
        done[here] = true
        local function relax(list: { Edge }?)
            if list == nil then
                return
            end
            for _, e in list do
                local nd = du + e.d
                if nd < (best[e.to] or math.huge) then
                    best[e.to] = nd
                    prev[e.to] = here
                end
            end
        end
        if here <= n then
            relax(g.edges[here])
        end
        relax(extra[here])
    end
    if best[T] == nil then
        return direct
    end
    -- intrarea si iesirea sunt pe iarba; restul pe drum
    local viaRoads = (dist(from, entry) + dist(exit, to)) * RoadGraph.GRASS_COST + best[T]
    if
        not roadsOnly
        and dist(from, to) * RoadGraph.GRASS_COST <= viaRoads
        and not RoadGraph.blockedBetween(g, from, to)
    then
        return direct
    end

    local chain: { Point } = {}
    local k: number? = T
    while k ~= nil do
        table.insert(chain, 1, pointAt(k :: number))
        k = prev[k :: number]
    end
    local out: { Point } = { { x = from.x, y = from.y } }
    for _, p in chain do
        if not same(out[#out], p) then
            table.insert(out, { x = p.x, y = p.y })
        end
    end
    if not same(out[#out], to) then
        table.insert(out, { x = to.x, y = to.y })
    end
    return simplify(out)
end

-- Graful din config, construit o singura data: puntea si drumurile FIECARUI cartier [D65]. Strada Morii atinge
-- strada satului, deci graful e unul singur si oamenii pot trece dintr-un cartier in altul.
-- [D70, pasul j8] Un graf pe LUME: drumurile barajului nu se leaga de ale satului (sunt alte harti). `fromConfig` e
-- graful lumii 1, ca inainte.
local worldGraphs: { [number]: Graph } = {}
function RoadGraph.forWorld(w: number?): Graph
    local world = WorldConfig.sanitize(w)
    local g = worldGraphs[world]
    if g == nil then
        local rects: { Rect } = {}
        for _, district in TycoonConfig.districtsOf(world) do
            table.insert(rects, district.deck)
            for _, r in district.roads do
                table.insert(rects, { x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 })
            end
        end
        -- [D70, dupa verificatorul j8] zidul si canalul barajului: pe acolo nu se taie nici pe iarba
        local blocked: { Rect } = {}
        local data = TycoonConfig.WORLDS[world]
        for _, b in if data ~= nil and data.blocked ~= nil then data.blocked else {} do
            table.insert(blocked, { x0 = b.x, x1 = b.x + b.w, y0 = b.y, y1 = b.y + b.h })
        end
        g = RoadGraph.build(rects, blocked)
        worldGraphs[world] = g
    end
    return g :: Graph
end
function RoadGraph.fromConfig(): Graph
    return RoadGraph.forWorld(1)
end

return RoadGraph
