--!strict
-- [D61] JOCURILE DE LA GHERETE. Modul PUR, acelasi pe client (care le deseneaza si le joaca) si pe server (care
-- socoteste scorul din apasarile trimise). Ca ReelMath: tot ce se misca e o functie de timp si de samanta, deci
-- serverul vede exact ce a vazut jucatorul fara sa-si trimita nimic in afara semintei si a clipelor de apasare.
--
-- In pasii jucatorului:
--   * Ring Toss: un inel se leagana deasupra a trei sticle; apesi si cade pe gatul sticlei daca era deasupra ei.
--     5 inele, fiecare mai repede.
--   * Hook a Duck: ratuste cu cifre (1, 1, 2, 2, 3, 5) trec pe sub un carlig fix; apesi si il agati pe cel de dedesubt.
--     3 carlige; cifrele mari inoata mai repede; ratusca agatata se intoarce in apa, deci 15 = de trei ori cea de 5.
--   * Jocurile sunt gratuite; premiu dau doar primele PRIZE_GAMES jocuri din ziua UTC, la un loc pentru ambele gherete.
--
-- Clipele de apasare sunt secunde de la inceputul jocului. Aruncarea i devine posibila la `windowStart` (prima dupa
-- `first`, urmatoarele la `gap` dupa apasarea dinainte) si trebuie tintita cel putin `minAim`: asa un pachet facut de
-- mana nu poate apasa de cinci ori in aceeasi clipa. Mizele sunt mici (cel mult 50 de perle pe zi), deci atat ajunge.
local Prng = require(script and script.Parent.Prng or "./Prng")

local BoothMath = {}

export type Game = { throws: number, first: number, gap: number, minAim: number }
BoothMath.GAMES = {
    ring = { throws = 5, first = 1.0, gap = 0.9, minAim = 0.25 },
    duck = { throws = 3, first = 1.0, gap = 1.1, minAim = 0.25 },
} :: { [string]: Game }

BoothMath.PRIZE_GAMES = 5
BoothMath.MAX_SECONDS = 90 -- un joc mai lung nu se crede
BoothMath.TOLERANCE = 1.0 -- cat pot intarzia pachetele fata de ceasul serverului

-- Ring Toss: sticlele stau la 1/4, 1/2 si 3/4 din raft; gatul unei sticle prinde inelul pe +- NECK.
BoothMath.BOTTLES = { 0.25, 0.5, 0.75 }
BoothMath.NECK = 0.06
BoothMath.RING_PRIZES = { 0, 1, 2, 4, 6, 10 } -- dupa cate inele au prins: 0, 1, ..., 5

-- Hook a Duck: cifrele ratustelor, in ordinea din canal; viteza (ture pe secunda) creste cu cifra.
BoothMath.DUCKS = { 1, 1, 2, 2, 3, 5 }
BoothMath.DUCK_SPEED = { [1] = 0.08, [2] = 0.11, [3] = 0.15, [5] = 0.28 }
BoothMath.HOOK_X = 0.5
BoothMath.HOOK_REACH = 0.03
BoothMath.DUCK_BANDS = {
    { upTo = 3, pearls = 1 },
    { upTo = 6, pearls = 2 },
    { upTo = 9, pearls = 4 },
    { upTo = 12, pearls = 6 },
    { upTo = 15, pearls = 10 },
}

local function phaseOf(seed: number, salt: number): number
    local rng = Prng.new((seed + salt * 2654435761) % 4294967296)
    rng:nextU32()
    return rng:nextNumber()
end

-- Unde e inelul `ring` (1..5) la `t` secunde de cand a aparut: 0..1 pe latimea raftului.
function BoothMath.ringX(t: number, seed: number, ring: number): number
    local omega = 1.4 + 0.4 * (ring - 1)
    return 0.5 + 0.45 * math.sin(omega * t + phaseOf(seed, ring) * 2 * math.pi)
end

-- Pe ce sticla cade inelul aflat la x (indexul ei), sau nil daca pica pe langa.
function BoothMath.ringHit(x: number): number?
    for i, bx in BoothMath.BOTTLES do
        if math.abs(x - bx) <= BoothMath.NECK then
            return i
        end
    end
    return nil
end

-- Unde e ratusca k la `t` secunde de la inceputul jocului: 0..1 pe lungimea canalului (dupa 1 o ia de la 0).
function BoothMath.duckX(t: number, seed: number, k: number): number
    local value = BoothMath.DUCKS[k]
    local speed = BoothMath.DUCK_SPEED[value]
    local x = phaseOf(seed, 10 + k) + speed * t
    return x - math.floor(x)
end

-- Ratusca de sub carlig la `t`: cea mai apropiata; la egalitate, cifra mai mare. nil daca nu e niciuna.
function BoothMath.duckUnder(t: number, seed: number): number?
    local best, bestDistance = nil, math.huge
    for k in BoothMath.DUCKS do
        local d = math.abs(BoothMath.duckX(t, seed, k) - BoothMath.HOOK_X)
        d = math.min(d, 1 - d)
        if d <= BoothMath.HOOK_REACH then
            local better = d < bestDistance
                or (
                    d == bestDistance
                    and best ~= nil
                    and BoothMath.DUCKS[k] > BoothMath.DUCKS[best]
                )
            if better then
                best, bestDistance = k, d
            end
        end
    end
    return best
end

-- Cand devine posibila aruncarea i (1-based), dupa apasarile de dinainte.
function BoothMath.windowStart(game: string, presses: { number }, i: number): number
    local spec = BoothMath.GAMES[game]
    if i == 1 then
        return spec.first
    end
    return presses[i - 1] + spec.gap
end

-- Pachetul de apasari e credibil? Numarul exact, numere adevarate, in ordine, fiecare tintita, si nu dupa ceasul
-- serverului (`elapsed` = cat a trecut de la inceput, masurat de server).
function BoothMath.valid(game: string, presses: unknown, elapsed: number): boolean
    local spec = BoothMath.GAMES[game]
    if spec == nil or typeof(presses) ~= "table" then
        return false
    end
    local list = presses :: { any }
    if #list ~= spec.throws then
        return false
    end
    local clean: { number } = {}
    for i = 1, spec.throws do
        local p = list[i]
        if typeof(p) ~= "number" or not math.isfinite(p) then
            return false
        end
        if p < BoothMath.windowStart(game, clean, i) + spec.minAim then
            return false
        end
        clean[i] = p
    end
    local last = clean[spec.throws]
    return last <= math.min(elapsed + BoothMath.TOLERANCE, BoothMath.MAX_SECONDS)
end

-- Scorul si ce a facut fiecare aruncare: la inele, sticla nimerita (0 = pe langa); la ratuste, ratusca agatata
-- (0 = nimic). Scorul: inele pe sticle, respectiv suma cifrelor.
function BoothMath.score(game: string, seed: number, presses: { number }): (number, { number })
    local results: { number } = {}
    local total = 0
    for i, p in presses do
        if game == "ring" then
            local t = p - BoothMath.windowStart(game, presses, i)
            local hit = BoothMath.ringHit(BoothMath.ringX(t, seed, i))
            results[i] = hit or 0
            if hit ~= nil then
                total += 1
            end
        else
            local k = BoothMath.duckUnder(p, seed)
            results[i] = k or 0
            if k ~= nil then
                total += BoothMath.DUCKS[k]
            end
        end
    end
    return total, results
end

function BoothMath.prize(game: string, score: number): number
    if game == "ring" then
        return BoothMath.RING_PRIZES[math.clamp(math.floor(score), 0, 5) + 1]
    end
    for _, band in BoothMath.DUCK_BANDS do
        if score <= band.upTo then
            return band.pearls
        end
    end
    return BoothMath.DUCK_BANDS[#BoothMath.DUCK_BANDS].pearls
end

function BoothMath.perfect(game: string, score: number): boolean
    return if game == "ring" then score >= 5 else score >= 15
end

-- Cel mai mare premiu dintr-un joc, pentru bugetul perlelor.
function BoothMath.maxPrize(): number
    local best = 0
    for _, p in BoothMath.RING_PRIZES do
        best = math.max(best, p)
    end
    for _, band in BoothMath.DUCK_BANDS do
        best = math.max(best, band.pearls)
    end
    return best
end

-- Ziua UTC (numarul ei), pentru jocurile cu premiu.
function BoothMath.dayKey(now: number): number
    return math.floor(now / 86400)
end

return BoothMath
