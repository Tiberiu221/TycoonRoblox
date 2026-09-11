--!strict
-- Grila de tile-uri a asezarii: conversii lume<->celula si harta de mers [RIVERKEEP 4.3]
-- Modul PUR (fara game/os.time) ca sa poata fi testat cu Lune [DECIZII D09].
local Grid = {}

export type Cell = { x: number, y: number }
export type Map = {
    width: number,
    height: number,
    tile: number,
    blocked: { [number]: boolean }, -- cheie = index plat (y * width + x)
}

function Grid.new(width: number, height: number, tile: number): Map
    return { width = width, height = height, tile = tile, blocked = {} }
end

function Grid.index(map: Map, x: number, y: number): number
    return y * map.width + x
end

function Grid.inBounds(map: Map, x: number, y: number): boolean
    return x >= 0 and y >= 0 and x < map.width and y < map.height
end

function Grid.isWalkable(map: Map, x: number, y: number): boolean
    return Grid.inBounds(map, x, y) and not map.blocked[Grid.index(map, x, y)]
end

function Grid.setBlocked(map: Map, x: number, y: number, blocked: boolean)
    if Grid.inBounds(map, x, y) then
        map.blocked[Grid.index(map, x, y)] = blocked or nil
    end
end

-- Blocheaza un dreptunghi in coordonate de lume (ex. o cladire plasata)
function Grid.blockWorldRect(map: Map, x: number, y: number, w: number, h: number)
    local cx0, cy0 = math.floor(x / map.tile), math.floor(y / map.tile)
    local cx1, cy1 = math.floor((x + w - 1) / map.tile), math.floor((y + h - 1) / map.tile)
    for cy = cy0, cy1 do
        for cx = cx0, cx1 do
            Grid.setBlocked(map, cx, cy, true)
        end
    end
end

function Grid.toCell(map: Map, worldX: number, worldY: number): (number, number)
    return math.floor(worldX / map.tile), math.floor(worldY / map.tile)
end

-- Centrul celulei, in coordonate de lume: acolo se duc colonistii
function Grid.toWorld(map: Map, cellX: number, cellY: number): (number, number)
    return cellX * map.tile + map.tile / 2, cellY * map.tile + map.tile / 2
end

-- Cea mai apropiata celula libera (spirala), pentru cand tinta e chiar sub o cladire
function Grid.nearestWalkable(
    map: Map,
    x: number,
    y: number,
    maxRadius: number?
): (number?, number?)
    if Grid.isWalkable(map, x, y) then
        return x, y
    end
    for r = 1, maxRadius or 8 do
        for dy = -r, r do
            for dx = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    if Grid.isWalkable(map, x + dx, y + dy) then
                        return x + dx, y + dy
                    end
                end
            end
        end
    end
    return nil, nil
end

return Grid
