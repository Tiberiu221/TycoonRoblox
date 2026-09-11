--!strict
-- Modul PUR: programul de spawn al unei ferestre, derivat din (seed, windowIndex); acelasi pe server si client [DECIZII D13]
local Prng = require(script and script.Parent.Prng or "./Prng")
local AABB = require(script and script.Parent.AABB or "./AABB")

export type Config = {
    WINDOW_SECONDS: number,
    LANE_YS: { number },
    SPAWNS_PER_WINDOW: number,
    SPEED_MIN: number,
    SPEED_MAX: number,
    OBJECT_WIDTH: number,
    OBJECT_HEIGHT: number,
    WORLD_WIDTH: number,
    TIERS: { { id: string, weight: number } },
}
export type RiverObject = { id: number, lane: number, spawnAt: number, speed: number, tier: string }

local RiverSim = {}

local function pickTier(roll: number, tiers: { { id: string, weight: number } }): string
    local acc = 0
    for _, tier in tiers do
        acc += tier.weight
        if roll < acc then
            return tier.id
        end
    end
    return tiers[1].id -- restul masei (rotunjiri) cade pe tierul comun
end

function RiverSim.seedFor(baseSeed: number, windowIndex: number): number
    return bit32.bxor(bit32.band(baseSeed, 0xFFFFFFFF), bit32.band(windowIndex * 40503, 0xFFFFFFFF))
end

function RiverSim.schedule(baseSeed: number, windowIndex: number, cfg: Config): { RiverObject }
    local rng = Prng.new(RiverSim.seedFor(baseSeed, windowIndex))
    local windowStart = windowIndex * cfg.WINDOW_SECONDS
    local objects: { RiverObject } = table.create(cfg.SPAWNS_PER_WINDOW)
    for i = 1, cfg.SPAWNS_PER_WINDOW do
        objects[i] = {
            id = windowIndex * 1000 + i,
            lane = rng:nextInteger(1, #cfg.LANE_YS),
            spawnAt = windowStart + rng:nextNumber() * cfg.WINDOW_SECONDS,
            speed = cfg.SPEED_MIN + rng:nextNumber() * (cfg.SPEED_MAX - cfg.SPEED_MIN),
            tier = pickTier(rng:nextNumber(), cfg.TIERS),
        }
    end
    table.sort(objects, function(a, b)
        return a.spawnAt < b.spawnAt
    end)
    return objects
end

-- Cutia obiectului la momentul `now`, sau nil daca nu e pe ecran
function RiverSim.box(obj: RiverObject, cfg: Config, now: number): AABB.Box?
    local t = now - obj.spawnAt
    if t < 0 then
        return nil
    end
    local x = -cfg.OBJECT_WIDTH + t * obj.speed
    if x > cfg.WORLD_WIDTH then
        return nil
    end
    return {
        x = x,
        y = cfg.LANE_YS[obj.lane] - cfg.OBJECT_HEIGHT / 2,
        width = cfg.OBJECT_WIDTH,
        height = cfg.OBJECT_HEIGHT,
    }
end

function RiverSim.activeWindows(now: number, cfg: Config): { number }
    local current = math.floor(now / cfg.WINDOW_SECONDS)
    return { current - 1, current }
end

return RiverSim
