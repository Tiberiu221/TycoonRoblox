--!strict
-- Forma malului si petele de teren. Modul PUR (fara `game`, fara ceas): aceleasi cifre pe client,
-- pe server si in Lune, deci malul arata identic la fiecare intrare si se poate testa.
--
-- DE CE EXISTA: pana acum apa era un dreptunghi, nisipul doua fasii drepte si iarba un singur
-- tile repetat -- de aceea harta parea "desenata in paint".
--
-- DOUA CONSTRANGERI CARE DAU TOATA FORMA:
--   1. Bunurile plutesc pe patru benzi FIXE (RiverConfig.LANE_YS, 516..732) pe TOATA latimea
--      hartii. Deci uscatul nu are voie sa intre niciodata peste ele: malul de nord poate urca
--      spre nord cat vrea, malul de sud poate cobori spre sud cat vrea, dar niciunul nu se poate
--      apropia de mijloc. De aici `side`: fiecare mal se departeaza doar in sensul lui.
--   2. In dreptul terenului construit (ponton, alee, platforme) malul trebuie sa fie aproape
--      drept -- altfel apa ar musca din scanduri. De aici `calm`: o portiune amenajata, cu
--      amplitudine mica, racordata lin la malul salbatic din rest. Nu e o scutire, e povestea
--      locului: bucata ta de mal e ingrijita, restul raului e salbatic.
local Prng = require(script and script.Parent.Prng or "./Prng")

local Shoreline = {}

-- Un numar stabil in [0,1) pentru perechea (seed, index). Xorshift-ul pornit din seed-uri
-- apropiate e corelat la primul pas, deci il lasam sa se invarta de doua ori inainte de citire.
local function hash01(seed: number, i: number): number
    local rng = Prng.new((seed + i * 2654435761) % 4294967296)
    Prng.nextU32(rng)
    Prng.nextU32(rng)
    return Prng.nextNumber(rng)
end

-- Zgomot neted de o dimensiune: valori intamplatoare in noduri, interpolate cu smoothstep.
-- Rezultat in [0,1), continuu -- fara colturi, deci malul nu are unghiuri drepte.
local function noise(seed: number, x: number, period: number): number
    local t = x / period
    local i = math.floor(t)
    local f = t - i
    local s = f * f * (3 - 2 * f)
    local a, b = hash01(seed, i), hash01(seed, i + 1)
    return a + (b - a) * s
end

local function smoothstep(t: number): number
    local c = math.clamp(t, 0, 1)
    return c * c * (3 - 2 * c)
end

export type Calm = { x0: number, x1: number, feather: number, amp: number }

export type Edge = {
    seed: number,
    baseY: number, -- linia de care malul NU trece niciodata (marginea dinspre apa)
    amp: number, -- cat de adanc poate intra uscatul, in sensul lui `side`
    side: number, -- +1 malul de sud (se retrage in jos), -1 cel de nord (se retrage in sus)
    calm: Calm?, -- portiunea amenajata, aproape dreapta
    beach: number?, -- latimea maxima a plajei; 0/nil = fara nisip
}

-- Trei straturi de zgomot: coturi lungi de rau, golfuri medii, si neregularitatea de aproape.
local LONG_PERIOD = 940
local MID_PERIOD = 330
local SHORT_PERIOD = 118

-- Suma a trei zgomote se strange in jurul mijlocului (media a trei valori e mai "cuminte" decat
-- fiecare in parte), deci malul ar iesi plat. `contrast` intinde rezultatul spre capete si il
-- lasa sa se lipeasca acolo: asa apar promontorii adevarate si golfuri adanci, nu unduiri egale.
local function contrast(v: number, k: number): number
    return math.clamp((v - 0.5) * k + 0.5, 0, 1)
end

local function shape(seed: number, x: number): number
    local long = noise(seed, x, LONG_PERIOD)
    local mid = noise(seed + 7777, x, MID_PERIOD)
    local short = noise(seed + 4242, x, SHORT_PERIOD)
    return contrast(long * 0.58 + mid * 0.31 + short * 0.11, 2.6)
end

-- Cata amplitudine are malul la x: mica in zona amenajata, intreaga in rest, racordate lin.
function Shoreline.amplitudeAt(e: Edge, x: number): number
    local calm = e.calm
    if calm == nil then
        return e.amp
    end
    local inside: number
    if x < calm.x0 then
        inside = 1 - smoothstep((calm.x0 - x) / math.max(1, calm.feather))
    elseif x > calm.x1 then
        inside = 1 - smoothstep((x - calm.x1) / math.max(1, calm.feather))
    else
        inside = 1
    end
    return calm.amp + (e.amp - calm.amp) * (1 - inside)
end

-- Inaltimea liniei de mal la x. Mereu de aceeasi parte a lui baseY: vezi constrangerea 1.
function Shoreline.edgeY(e: Edge, x: number): number
    return e.baseY + e.side * Shoreline.amplitudeAt(e, x) * shape(e.seed, x)
end

-- Latimea plajei la x. Zero pe portiuni intregi: asa iarba ajunge pe alocuri pana in apa, si
-- nisipul inceteaza sa mai fie o autostrada bej de-a lungul intregii harti.
function Shoreline.beachWidth(e: Edge, x: number): number
    local maxW = e.beach or 0
    if maxW <= 0 then
        return 0
    end
    local n = contrast(noise(e.seed + 1313, x, 270) * 0.7 + noise(e.seed + 2626, x, 91) * 0.3, 2.2)
    return math.max(0, math.min(maxW, n * maxW * 1.9 - maxW * 0.62))
end

export type Column = { x: number, w: number, y: number, beach: number }

-- Malul, taiat in coloane verticale: asa se poate desena cu dreptunghiuri decupate, fara shader.
-- Coloanele se suprapun cu un pixel ca sa nu ramana fire de fundal intre ele.
function Shoreline.columns(e: Edge, width: number, step: number): { Column }
    local out: { Column } = {}
    local x = 0
    while x < width do
        local w = math.min(step, width - x)
        local mid = x + w / 2
        table.insert(out, {
            x = x,
            w = w + 1,
            y = Shoreline.edgeY(e, mid),
            beach = Shoreline.beachWidth(e, mid),
        })
        x += step
    end
    return out
end

export type Patch = { x: number, y: number, w: number, h: number, rot: number, tone: number }

export type PatchArea = { x0: number, y0: number, x1: number, y1: number, tones: number }

-- Petele de nuanta de pe iarba: mari, rare si mereu in acelasi loc. Nu sunt obiecte, sunt doar
-- culoare -- rolul lor e ca ochiul sa nu mai vada un singur tile repetat la infinit. Marimile
-- merg de la pata de tufa la pata cat un sfert de ecran, ca sa se rupa si repetitia mare.
function Shoreline.patches(seed: number, area: PatchArea, count: number): { Patch }
    local out: { Patch } = {}
    local rng = Prng.new(seed)
    for i = 1, count do
        -- una din patru e uriasa si foarte palida: ea rupe tiparul tile-ului la scara mare
        local huge = i % 4 == 0
        local w = if huge
            then 620 + Prng.nextNumber(rng) * 680
            else 130 + Prng.nextNumber(rng) * 330
        local h = w * (0.42 + Prng.nextNumber(rng) * 0.46)
        local x = area.x0 + Prng.nextNumber(rng) * math.max(1, area.x1 - area.x0 - w)
        local y = area.y0 + Prng.nextNumber(rng) * math.max(1, area.y1 - area.y0 - h)
        table.insert(out, {
            x = math.round(x),
            y = math.round(y),
            w = math.round(w),
            h = math.round(h),
            rot = math.round((Prng.nextNumber(rng) - 0.5) * 40),
            tone = Prng.nextInteger(rng, 1, math.max(1, area.tones)),
        })
    end
    return out
end

export type Pebble = { x: number, y: number, r: number, tone: number }

-- Pietricelele de pe plaja: se aseaza PE linia malului, deci urmeaza golfurile automat.
-- `salt` cere alta imprastiere pe ACEEASI linie -- asa spuma nu cade exact peste pietre.
function Shoreline.pebbles(
    e: Edge,
    width: number,
    count: number,
    spread: number,
    salt: number?
): { Pebble }
    local out: { Pebble } = {}
    local rng = Prng.new(e.seed + 31337 + (salt or 0))
    for _ = 1, count do
        local x = Prng.nextNumber(rng) * width
        local off = (Prng.nextNumber(rng) - 0.5) * 2 * spread
        table.insert(out, {
            x = math.round(x),
            y = math.round(Shoreline.edgeY(e, x) + off),
            r = 3 + Prng.nextInteger(rng, 0, 4),
            tone = Prng.nextInteger(rng, 1, 3),
        })
    end
    return out
end

return Shoreline
