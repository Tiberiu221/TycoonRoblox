--!strict
-- [D59] Bara de mulinat. Modul PUR, acelasi pe client (care o deseneaza si o joaca) si pe server (care afla doar cat de
-- repede ar fi putut-o termina cel mai bun jucator).
--
-- Cum se joaca, in pasii jucatorului: peste apa e o bara cu o zona luminoasa la mijloc, iar pestele se plimba pe ea.
--   * tii apasat cat pestele e in zona -> firul se strange;
--   * tii apasat cat e afara -> firul se desface putin, niciodata sub zero;
--   * dai drumul -> nu se schimba nimic.
-- NU EXISTA ESEC: doar tinand apasat tot timpul scoti orice peste (testul o dovedeste pe mii de seminte, sub 30 s), iar
-- daca dai drumul cand iese din zona termini mai repede. Buton tinut, nu apasat repede [owner: fara presiune].
--
-- Pozitia pestelui e o FUNCTIE de timp, samanta si dificultate (doua sinusoide cu faze din samanta), nu un mers
-- intamplator: clientul si serverul vad aceeasi bara fara sa-si trimita nimic in afara samantei.
local Prng = require(script and script.Parent.Prng or "./Prng")

local ReelMath = {}

-- zone = jumatatea zonei luminoase; fill/slip = cat se strange/desface firul pe secunda; a1/a2 = cat de departe se
-- duce pestele; speed = cat de repede. Reglate pe 2.500 de seminte: jocul perfect ~2,6 / 3,6 / 4,9 / 6,5 / 8,1 s in medie,
-- doar tinut apasat cel mult ~22 s la dificultatea 5.
export type Spec =
    { zone: number, fill: number, slip: number, a1: number, a2: number, speed: number }
ReelMath.SPECS = {
    { zone = 0.22, fill = 0.45, slip = 0.12, a1 = 0.20, a2 = 0.07, speed = 0.9 },
    { zone = 0.20, fill = 0.40, slip = 0.12, a1 = 0.23, a2 = 0.08, speed = 1.05 },
    { zone = 0.18, fill = 0.36, slip = 0.11, a1 = 0.25, a2 = 0.09, speed = 1.2 },
    { zone = 0.17, fill = 0.33, slip = 0.09, a1 = 0.27, a2 = 0.09, speed = 1.35 },
    { zone = 0.16, fill = 0.30, slip = 0.07, a1 = 0.28, a2 = 0.10, speed = 1.5 },
} :: { Spec }

ReelMath.DT = 1 / 60 -- pasul simularii jocului perfect
ReelMath.MAX_SECONDS = 120 -- plasa de siguranta a simularii; testul cere mult sub

function ReelMath.spec(difficulty: number): Spec
    return ReelMath.SPECS[math.clamp(math.floor(difficulty), 1, #ReelMath.SPECS)]
end

type Waves = { w1: number, w2: number, p1: number, p2: number }
local wavesCache: { [number]: Waves } = {}

local function waves(seed: number): Waves
    local cached = wavesCache[seed]
    if cached ~= nil then
        return cached
    end
    local rng = Prng.new(seed)
    local r1, r2, r3, r4 = rng:nextNumber(), rng:nextNumber(), rng:nextNumber(), rng:nextNumber()
    local w =
        { w1 = 1.0 + 0.35 * r1, w2 = 2.2 + 0.7 * r2, p1 = 2 * math.pi * r3, p2 = 2 * math.pi * r4 }
    wavesCache[seed] = w
    return w
end

-- Pozitia pestelui pe bara, in [0, 1] (0.5 = mijlocul zonei), la t secunde de la muscatura.
function ReelMath.fishAt(t: number, seed: number, difficulty: number): number
    local s = ReelMath.spec(difficulty)
    local w = waves(seed)
    return 0.5
        + s.a1 * math.sin(w.w1 * s.speed * t + w.p1)
        + s.a2 * math.sin(w.w2 * s.speed * t + w.p2)
end

function ReelMath.inZone(position: number, difficulty: number): boolean
    return math.abs(position - 0.5) <= ReelMath.spec(difficulty).zone
end

-- Un pas al firului. Intoarce progresul nou, in [0, 1].
function ReelMath.step(
    progress: number,
    dt: number,
    holding: boolean,
    inZone: boolean,
    difficulty: number
): number
    if not holding then
        return progress
    end
    local s = ReelMath.spec(difficulty)
    local delta = if inZone then s.fill * dt else -s.slip * dt
    return math.clamp(progress + delta, 0, 1)
end

-- Cat dureaza bara cu o strategie: "perfect" tine apasat doar cat pestele e in zona, "hold" tine apasat tot timpul.
function ReelMath.simulate(seed: number, difficulty: number, strategy: string): number
    local progress, t = 0, 0
    local dt = ReelMath.DT
    while progress < 1 and t < ReelMath.MAX_SECONDS do
        local inside = ReelMath.inZone(ReelMath.fishAt(t, seed, difficulty), difficulty)
        local holding = if strategy == "perfect" then inside else true
        progress = ReelMath.step(progress, dt, holding, inside, difficulty)
        t += dt
    end
    return t
end

-- Cel mai repede posibil pe exact aceasta bara: sub atat de la muscatura, serverul nu crede scoaterea.
function ReelMath.minSeconds(seed: number, difficulty: number): number
    return ReelMath.simulate(seed, difficulty, "perfect")
end

return ReelMath
