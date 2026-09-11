--!strict
-- A* pe grila, cu 8 directii si taiere de colturi interzisa. Modul PUR, testabil cu Lune.
-- Buget: cautarea se opreste dupa `maxNodes` celule expandate, ca un colonist blocat sa nu
-- consume tot bugetul de CPU al serverului [RIVERKEEP 9].
local Grid = require(script and script.Parent.Grid or "./Grid")

local Pathfind = {}

local DIRS = {
    { 1, 0, 10 },
    { -1, 0, 10 },
    { 0, 1, 10 },
    { 0, -1, 10 },
    { 1, 1, 14 },
    { 1, -1, 14 },
    { -1, 1, 14 },
    { -1, -1, 14 },
}

local function heuristic(ax: number, ay: number, bx: number, by: number): number
    -- distanta octila: exacta pentru miscare pe 8 directii, deci A* ramane optim
    local dx, dy = math.abs(ax - bx), math.abs(ay - by)
    return 10 * (dx + dy) + (14 - 2 * 10) * math.min(dx, dy)
end

-- Coada de prioritati minima (binary heap) — suficienta pentru harti de ordinul 10^4 celule
type Heap = { n: number, cost: { number }, node: { number } }

local function heapPush(h: Heap, cost: number, node: number)
    local i = h.n + 1
    h.n = i
    h.cost[i], h.node[i] = cost, node
    while i > 1 do
        local parent = i // 2
        if h.cost[parent] <= h.cost[i] then
            break
        end
        h.cost[parent], h.cost[i] = h.cost[i], h.cost[parent]
        h.node[parent], h.node[i] = h.node[i], h.node[parent]
        i = parent
    end
end

local function heapPop(h: Heap): number?
    if h.n == 0 then
        return nil
    end
    local top = h.node[1]
    h.cost[1], h.node[1] = h.cost[h.n], h.node[h.n]
    h.cost[h.n], h.node[h.n] = nil :: any, nil :: any
    h.n -= 1
    local i = 1
    while true do
        local l, r, best = i * 2, i * 2 + 1, i
        if l <= h.n and h.cost[l] < h.cost[best] then
            best = l
        end
        if r <= h.n and h.cost[r] < h.cost[best] then
            best = r
        end
        if best == i then
            break
        end
        h.cost[best], h.cost[i] = h.cost[i], h.cost[best]
        h.node[best], h.node[i] = h.node[i], h.node[best]
        i = best
    end
    return top
end

export type Path = { Grid.Cell }

-- Intoarce drumul de la (sx,sy) la (gx,gy), inclusiv capetele, sau nil daca nu exista.
-- `stats` (optional) primeste numarul de celule expandate, pentru masuratori.
function Pathfind.find(
    map: Grid.Map,
    sx: number,
    sy: number,
    gx: number,
    gy: number,
    maxNodes: number?,
    stats: { expanded: number }?
): Path?
    if not Grid.isWalkable(map, sx, sy) or not Grid.isWalkable(map, gx, gy) then
        return nil
    end
    local budget = maxNodes or 1200
    local startIdx = Grid.index(map, sx, sy)
    local goalIdx = Grid.index(map, gx, gy)
    if startIdx == goalIdx then
        return { { x = sx, y = sy } }
    end

    local gScore: { [number]: number } = { [startIdx] = 0 }
    local cameFrom: { [number]: number } = {}
    local closed: { [number]: boolean } = {}
    local open: Heap = { n = 0, cost = {}, node = {} }
    heapPush(open, heuristic(sx, sy, gx, gy), startIdx)

    local expanded = 0
    while open.n > 0 do
        local current = heapPop(open) :: number
        if closed[current] then
            continue
        end
        closed[current] = true
        expanded += 1
        if current == goalIdx then
            break
        end
        if expanded > budget then
            if stats then
                stats.expanded = expanded
            end
            return nil
        end

        local cx, cy = current % map.width, current // map.width
        local baseG = gScore[current] or 0
        for _, d in DIRS do
            local nx, ny = cx + d[1], cy + d[2]
            if not Grid.isWalkable(map, nx, ny) then
                continue
            end
            -- fara taiat colturi: diagonala cere ambele celule ortogonale libere
            if
                d[3] == 14
                and (
                    not Grid.isWalkable(map, cx + d[1], cy)
                    or not Grid.isWalkable(map, cx, cy + d[2])
                )
            then
                continue
            end
            local nIdx = Grid.index(map, nx, ny)
            if closed[nIdx] then
                continue
            end
            local tentative = baseG + d[3]
            if gScore[nIdx] == nil or tentative < gScore[nIdx] then
                gScore[nIdx] = tentative
                cameFrom[nIdx] = current
                heapPush(open, tentative + heuristic(nx, ny, gx, gy), nIdx)
            end
        end
    end

    if stats then
        stats.expanded = expanded
    end
    if not closed[goalIdx] then
        return nil
    end

    local path: Path = {}
    local node = goalIdx
    while node ~= nil do
        table.insert(path, 1, { x = node % map.width, y = node // map.width })
        if node == startIdx then
            break
        end
        node = cameFrom[node]
    end
    return path
end

-- Scoate punctele intermediare de pe segmentele drepte: mai putine waypoint-uri de trimis la client
function Pathfind.simplify(path: Path): Path
    if #path < 3 then
        return path
    end
    local out: Path = { path[1] }
    for i = 2, #path - 1 do
        local a, b, c = path[i - 1], path[i], path[i + 1]
        if (b.x - a.x) ~= (c.x - b.x) or (b.y - a.y) ~= (c.y - b.y) then
            table.insert(out, b)
        end
    end
    table.insert(out, path[#path])
    return out
end

return Pathfind
