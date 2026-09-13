--!strict
-- [D53] Bustenii care vin pe rau spre plasa, inainte sa fie prinsi. Modul PUR: aceleasi pozitii pe orice
-- client, doar ca sa arate UNDE e fiecare bun acum -- nu decide CE bun e (TycoonMath.pickGood + catchSeed)
-- si nu decide CAND se prinde (serverul, pe ceasul plasei, care acum nu se opreste nici cand e plina).
--
-- Owner-ul: "apar asa de nicaieri, ceva mai realistic din punct de vedere al logicii". Pana acum bunul
-- aparea brusc la 300 px in susul raului si mergea in linie dreapta in plasa, in 0.4-2.2 s. Acum:
--   * porneste de la marginea din stanga a lumii si pluteste cu curentul (SPEED), pe curentul de langa
--     plase (TycoonConfig.NEAR_CURRENT_Y) -- deasupra oricarei plase din amonte;
--   * pe ultimii px coteste lin, in jos, in plasa; cotul creste cu coborarea, altfel banda de langa mal ar
--     fi un plonjon de 66 de grade;
--   * ajunge exact la momentul prinderii, se micsoreaza si intra in plasa;
--   * la o plasa plina merge mai departe drept si se stinge.
-- Plasele rapide nu primesc un bustean pe fiecare prindere: cel mult MAX_IN_FLIGHT pe drum, la cel putin
-- MIN_GAP unul de altul (pastila cu numarul numara in continuare fiecare prindere).
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local CatchFloat = {}

CatchFloat.SPEED = 130 -- px/s, curentul; decorul din larg merge la fel, ca nimic sa nu depaseasca nimic
CatchFloat.SPAWN_X = -64 -- marginea din stanga a lumii, ca RiverSim
CatchFloat.JITTER = 4 -- px: fiecare bustean pe linia lui, nu toti pe acelasi fir
CatchFloat.BOB = 2 -- px: leganarea pe apa
CatchFloat.FADE_IN = 0.6 -- s: nu apare niciodata brusc, nici cand e creat pe drum
CatchFloat.SINK = 0.2 -- s: intra in plasa micsorandu-se
CatchFloat.PASS = 200 -- px dupa o plasa plina, pana se stinge de tot
CatchFloat.MIN_GAP = 0.9 -- s intre doi busteni desenati spre aceeasi plasa
CatchFloat.MAX_IN_FLIGHT = 6
CatchFloat.TURN_PER_DROP = 1.2 -- cotul, pe orizontala, fata de cat coboara
CatchFloat.TURN_MIN = 120
CatchFloat.TURN_MAX = 220
-- cat mai traieste un bustean dupa momentul lui: cel care trece pe langa o plasa plina are nevoie de mai mult
CatchFloat.LINGER = math.max(CatchFloat.SINK, CatchFloat.PASS / CatchFloat.SPEED)

-- Cat dureaza drumul de la marginea lumii pana la plasa.
function CatchFloat.travel(netX: number): number
    return math.max(0, netX - CatchFloat.SPAWN_X) / CatchFloat.SPEED
end

-- Pe cati px, pe orizontala, coteste bustenul in plasa: pe masura coborarii de pe curent pana la ea.
function CatchFloat.turnFor(netY: number): number
    local drop = math.max(0, netY - TycoonConfig.NEAR_CURRENT_Y)
    return math.clamp(drop * CatchFloat.TURN_PER_DROP, CatchFloat.TURN_MIN, CatchFloat.TURN_MAX)
end

-- Din cate momente de prindere se deseneaza unul (1 = toate).
function CatchFloat.stride(interval: number, travel: number): number
    if not (interval > 0) then
        return 1
    end
    local gap = math.max(CatchFloat.MIN_GAP, travel / CatchFloat.MAX_IN_FLIGHT)
    return math.max(1, math.ceil(gap / interval - 1e-9))
end

-- Linia unui bustean pe curent: aceeasi pentru acelasi moment, la fiecare cadru.
function CatchFloat.lineY(seed: number): number
    local span = 2 * CatchFloat.JITTER + 1
    return TycoonConfig.NEAR_CURRENT_Y + (math.floor(seed * 37) % span) - CatchFloat.JITTER
end

-- Momentele de prindere care au acum un bustean pe drum: de la cel care inca intra in plasa (sau trece pe
-- langa ea) pana la cel care abia porneste de la marginea lumii. Ceasul are pasi intregi de interval, deci
-- numarul unui moment e `round(t / interval)`; se aleg doar cele cu numarul multiplu de `stride` -- aceleasi
-- de la un cadru la altul, oricat ar avansa ceasul.
function CatchFloat.slots(
    nextCatchAt: number,
    interval: number,
    travel: number,
    now: number,
    stride: number
): { number }
    local out: { number } = {}
    if not (interval > 0) or not math.isfinite(interval) or not math.isfinite(nextCatchAt) then
        return out
    end
    local step = math.max(1, math.floor(stride))
    local first = math.ceil((now - CatchFloat.LINGER - nextCatchAt) / interval)
    local last = math.floor((now + travel - nextCatchAt) / interval)
    local base = math.round(nextCatchAt / interval)
    local n = first + (-(base + first) % step)
    while n <= last do
        table.insert(out, nextCatchAt + n * interval)
        n += step
    end
    return out
end

-- A intrat bustenul momentului `t` in cot? Acolo se hotaraste o singura data daca intra sau trece.
function CatchFloat.inTurn(netX: number, netY: number, t: number, now: number): boolean
    return netX - (t - now) * CatchFloat.SPEED > netX - CatchFloat.turnFor(netY)
end

-- Unde e bustenul momentului `t` acum. `mode`: "turn" (intra in plasa) sau "pass" (plasa plina, trece);
-- `seed` = numarul momentului (linia si leganarea lui); `bornAt` = cand a aparut (estomparea). Intoarce x, y,
-- transparenta (0 = vizibil, 1 = stins) si scara (1 pe drum, 0.4 la capatul intrarii in plasa).
function CatchFloat.at(
    netX: number,
    netY: number,
    t: number,
    now: number,
    mode: string,
    seed: number,
    bornAt: number
): (number, number, number, number)
    local lineY = CatchFloat.lineY(seed)
    local x = netX - (t - now) * CatchFloat.SPEED
    local bob = math.sin(now * 2.6 + seed * 1.7) * CatchFloat.BOB
    local fade = 1 - math.clamp((now - bornAt) / CatchFloat.FADE_IN, 0, 1)
    local turn = CatchFloat.turnFor(netY)
    local startX = netX - turn
    if mode == "pass" or x <= startX then
        local alpha = fade
        if mode == "pass" and x > netX then
            alpha = math.max(alpha, math.clamp((x - netX) / CatchFloat.PASS, 0, 1))
        end
        return x, lineY + bob, alpha, 1
    end
    if now >= t then
        local k = math.clamp((now - t) / CatchFloat.SINK, 0, 1)
        return netX, netY, math.max(fade, k), 1 - 0.6 * k
    end
    local u = math.clamp((x - startX) / turn, 0, 1)
    local s = u * u * (3 - 2 * u)
    return x, lineY + (netY - lineY) * s + bob * (1 - s), fade, 1
end

return CatchFloat
