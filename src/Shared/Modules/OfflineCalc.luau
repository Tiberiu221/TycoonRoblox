--!strict
-- Modul PUR: fara game/os.time() in interior; primeste timpul ca parametru [DECIZII D09, D15]
--
-- CASTIGUL DE CAT AI LIPSIT, pentru modelul cu lant: cat a mers LANTUL fara tine. Fara Mana si fara Negustor,
-- `idleRate` e zero si castigul e zero -- nu ca pedeapsa, ci pentru ca n-avea cine sa care si cine sa vanda. Nimic nu
-- se pierde [P2], dar nici nu apare de nicaieri.
--
-- [D71] SATUL LUCREAZA FARA TINE PE O CURBA IN TREI BUCATI (owner, 2026-10-01: "dupa 8 ore doar incetineste, dupa 24 de
-- ore se opreste"; o revenire pe zi e rasplatita):
--   * pana la `full` secunde (8 h; 16 h cu Long Nights): viteza intreaga;
--   * de acolo pana la `stop` (24 h): `slow` din viteza (un sfert);
--   * dupa `stop`: satul se odihneste si nu mai castiga nimic pana revii.
-- Nicio absenta nu plateste mai putin decat inainte (D66: plin pana la 8 h, 16 h cu Long Nights, apoi nimic).
-- [D71] `computeOffline` (plasele pe sloturi, D15) era cod mort, cu un al doilea "24 h": a iesit.
local ABS_MAX_ELAPSED = 30 * 24 * 3600 -- clamp de siguranta [DECIZII D14]

export type Curve = { full: number, stop: number, slow: number }
-- "full": a lucrat tot timpul la viteza intreaga; "slow": a trecut si prin bucata mai lenta; "rested": a ajuns la oprire
export type Phase = "full" | "slow" | "rested"
-- `away`: cat ai lipsit cu adevarat (secunde, pentru textul ferestrei); `paid`: secundele platite la viteza intreaga
export type IdleResult = { away: number, paid: number, coins: number, phase: Phase }

-- La fel ca PassMath.offlineCurve fara pass-uri (un test le tine legate).
local DEFAULT_CURVE: Curve = table.freeze({ full = 8 * 3600, stop = 24 * 3600, slow = 0.25 })

local function finite(x: unknown): boolean
    return typeof(x) == "number" and x == x and x > -math.huge and x < math.huge
end

-- O curba stricata cade pe cea implicita, niciodata pe "fara plafon" [D61, partea 2].
local function validCurve(curve: Curve?): Curve
    if curve == nil then
        return DEFAULT_CURVE
    end
    local full, stop, slow = curve.full, curve.stop, curve.slow
    if not (finite(full) and finite(stop) and finite(slow)) then
        return DEFAULT_CURVE
    end
    if full <= 0 or stop < full or slow < 0 or slow > 1 then
        return DEFAULT_CURVE
    end
    return {
        full = math.min(full, ABS_MAX_ELAPSED),
        stop = math.min(stop, ABS_MAX_ELAPSED),
        slow = slow,
    }
end

-- Secundele platite la viteza intreaga pentru o absenta de `elapsed` secunde.
local function paidSeconds(elapsed: number, curve: Curve?): number
    local c = validCurve(curve)
    local e = if finite(elapsed) then math.clamp(elapsed, 0, ABS_MAX_ELAPSED) else 0
    return math.min(e, c.full) + math.max(0, math.min(e, c.stop) - c.full) * c.slow
end

local function phaseOf(elapsed: number, curve: Curve?): Phase
    local c = validCurve(curve)
    if elapsed <= c.full then
        return "full"
    end
    return if elapsed <= c.stop then "slow" else "rested"
end

local function computeIdle(
    now: number,
    lastSeenAt: number,
    idleRate: number,
    curve: Curve?
): IdleResult
    if not (finite(now) and finite(lastSeenAt)) or lastSeenAt <= 0 then
        return { away = 0, paid = 0, coins = 0, phase = "full" }
    end
    -- cat ai lipsit se spune si cand satul n-a castigat nimic (a venit ceva pe rau, D59): altfel scria "a moment". Si se
    -- spune adevarat: clampul de 30 de zile [D14] tine doar socoteala platii (paidSeconds), nu textul.
    local away = math.max(0, now - lastSeenAt)
    local phase = phaseOf(away, curve)
    if not finite(idleRate) or idleRate <= 0 then
        return { away = away, paid = 0, coins = 0, phase = phase }
    end
    local paid = paidSeconds(away, curve)
    return { away = away, paid = paid, coins = paid * idleRate, phase = phase }
end

return {
    computeIdle = computeIdle,
    paidSeconds = paidSeconds,
    phaseOf = phaseOf,
    DEFAULT_CURVE = DEFAULT_CURVE,
    ABS_MAX_ELAPSED = ABS_MAX_ELAPSED,
}
