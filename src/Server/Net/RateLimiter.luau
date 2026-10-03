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
    AtForge = { capacity = 3, refillPerSecond = 1 }, -- [D56] la fel ca la gater
    -- [D65] prezenta la atelierele oricarei linii: pot fi doua ateliere in raza unul dupa altul, deci putin mai larg
    AtPlace = { capacity = 4, refillPerSecond = 1.5 },
    SpinWheel = { capacity = 3, refillPerSecond = 1 },
    -- [D54] panoul "Sound", dupa 0.6 s de liniste pe fiecare canal; fara bucket propriu, un nume
    -- necunoscut ar fi refuzat in tacere
    SetAudio = { capacity = 6, refillPerSecond = 2 },
    -- [D71] fusul orar, o data la intrare (si la o reincercare); serverul il schimba oricum cel mult o data pe zi
    Clock = { capacity = 2, refillPerSecond = 0.05 },
    RequestState = { capacity = 2, refillPerSecond = 0.2 },
    -- [D59] undita: aruncarea si scoaterea (cu reincercarea cand scoaterea vine prea devreme) -- cel mai des la o
    -- secunda si ceva, deci 4 in rafala ajung si cu reincercari
    Fishing = { capacity = 4, refillPerSecond = 1 },
    -- [D59] avizierul satului: cumparat, imbracat
    Shop = { capacity = 4, refillPerSecond = 2 },
    -- [D60] barca dintre sat si balci: un drum dureaza secunde, deci doua cereri in rafala ajung si pentru o reincercare
    Ferry = { capacity = 3, refillPerSecond = 0.5 },
    -- [D60] cardul altui om din balci: un E pe cineva, cel mult unul pe secunda dupa primele trei
    LookAt = { capacity = 3, refillPerSecond = 1 },
    -- [D61] gheretele: inceputul si sfarsitul unui joc (un joc tine cateva secunde)
    Booth = { capacity = 4, refillPerSecond = 1 },
    -- [D61] mesele: te asezi, te ridici, faci cu mana (Wave are si pauza lui de 2 s pe server)
    Seat = { capacity = 4, refillPerSecond = 1 },
    -- [D61, partea 2] poarta satelor: lista, fotografia unui sat, like-ul
    Visit = { capacity = 4, refillPerSecond = 1 },
    -- [D62, pasul 3] darurile raului: unul la ~56 s; doua cereri la rand acopera un E apasat de doua ori
    Drift = { capacity = 2, refillPerSecond = 0.2 },
    -- [D61, partea 2] coltul cu Robux: cererea ferestrei de cumparare
    Robux = { capacity = 3, refillPerSecond = 0.5 },
    -- [D70, pasul j15] barajul: previzualizarea (la deschiderea ecranului si dupa un "changed"), ridicarea, filmul
    Dam = { capacity = 4, refillPerSecond = 0.5 },
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
