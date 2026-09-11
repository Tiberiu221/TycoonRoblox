--!strict
-- Token bucket per jucator per tip de remote, dupa implementarea oficiala Roblox [nota: anti-exploit; MASTERPLAN 4.3.4]
local RateLimiter = {}

type Bucket = { tokens: number, lastRefill: number }
local buckets: { [Player]: { [string]: Bucket } } = {}
local LIMITS: { [string]: { capacity: number, refillPerSecond: number } } = {
    BuyPad = { capacity = 3, refillPerSecond = 1 },
    CollectNet = { capacity = 5, refillPerSecond = 2 },
    SellSack = { capacity = 3, refillPerSecond = 1 },
    RequestState = { capacity = 2, refillPerSecond = 0.2 },
}

function RateLimiter.Allow(player: Player, remoteName: string, now: number?): boolean
    local limit = LIMITS[remoteName]
    if limit == nil then
        return true
    end
    local t = now or os.clock()
    local perPlayer = buckets[player]
    if perPlayer == nil then
        perPlayer = {}
        buckets[player] = perPlayer
    end
    local bucket = perPlayer[remoteName]
    if bucket == nil then
        bucket = { tokens = limit.capacity, lastRefill = t }
        perPlayer[remoteName] = bucket
    end
    bucket.tokens =
        math.min(limit.capacity, bucket.tokens + (t - bucket.lastRefill) * limit.refillPerSecond)
    bucket.lastRefill = t
    if bucket.tokens >= 1 then
        bucket.tokens -= 1
        return true
    end
    return false
end

function RateLimiter.Forget(player: Player)
    buckets[player] = nil
end

return RateLimiter
