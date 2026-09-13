--!strict
-- Token bucket per jucator per tip de remote, dupa implementarea oficiala Roblox [nota: anti-exploit; MASTERPLAN 4.3.4]
local RateLimiter = {}

type Bucket = { tokens: number, lastRefill: number }
local buckets: { [Player]: { [string]: Bucket } } = {}
local LIMITS: { [string]: { capacity: number, refillPerSecond: number } } = {
    BuyPad = { capacity = 3, refillPerSecond = 1 },
    CollectNet = { capacity = 5, refillPerSecond = 2 },
    -- gesturile de predare [D49]: depozit, gater, debarcader -- cate unul pe apasare de E
    UsePlace = { capacity = 5, refillPerSecond = 2 },
    -- "sunt la gater": la intrarea in raza, la iesire si o data la 2 s cat stai [D49]
    AtSawmill = { capacity = 3, refillPerSecond = 1 },
    SpinWheel = { capacity = 3, refillPerSecond = 1 },
    -- [D54] panoul "Sound", dupa 0.6 s de liniste pe fiecare canal; fara bucket propriu, un nume
    -- necunoscut ar fi refuzat in tacere
    SetAudio = { capacity = 6, refillPerSecond = 2 },
    RequestState = { capacity = 2, refillPerSecond = 0.2 },
}
RateLimiter.LIMITS = LIMITS

-- UN NUME NECUNOSCUT NU INSEAMNA "FARA LIMITA". Pana in D49 intorcea `true`: SpinWheel imprumuta
-- bucket-ul lui SellSack, iar scoaterea lui SellSack i-ar fi scos in tacere orice limita. Acum
-- refuza si se aude [D43] -- o greseala de nume se vede la prima apasare, nu intr-un exploit.
local warned: { [string]: boolean } = {}

function RateLimiter.Allow(player: Player, remoteName: string, now: number?): boolean
    local limit = LIMITS[remoteName]
    if limit == nil then
        if not warned[remoteName] then
            warned[remoteName] = true
            warn(`[RateLimiter] bucket necunoscut: {remoteName} -- cererea e refuzata`)
        end
        return false
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
