--!strict
-- Modul PUR: fara game/os.time() in interior; primeste timpul ca parametru [DECIZII D09, D15]
local BACKSTOP_SECONDS = 24 * 3600 -- back-stop orar [DECIZII D15]
local ABS_MAX_ELAPSED = 30 * 24 * 3600 -- clamp de siguranta [DECIZII D14]

export type OfflineResult =
    { itemsCaught: number, cappedByTime: boolean, cappedByCapacity: boolean }

local function computeOffline(
    now: number,
    lastCollectedAt: number,
    secondsPerItem: number,
    slotsFree: number
): OfflineResult
    local elapsed = math.clamp(now - lastCollectedAt, 0, ABS_MAX_ELAPSED)
    local elapsedCap = math.min(elapsed, BACKSTOP_SECONDS)
    local byTime = math.floor(elapsedCap / secondsPerItem)
    local itemsCaught = math.min(byTime, slotsFree)
    return {
        itemsCaught = itemsCaught,
        cappedByTime = elapsed > BACKSTOP_SECONDS,
        cappedByCapacity = itemsCaught == slotsFree and byTime >= slotsFree,
    }
end

-- CASTIGUL DE CAT AI LIPSIT, pentru modelul cu lant. Functia de mai sus numara bucati prinse pana
-- se umple plasa; aici conteaza altceva: cat a mers LANTUL fara tine. Fara Mana si fara Negustor,
-- `idleRate` e zero si castigul e zero -- nu ca pedeapsa, ci pentru ca n-avea cine sa care si cine
-- sa vanda. Nimic nu se pierde [P2], dar nici nu apare de nicaieri.
export type IdleResult = { seconds: number, coins: number, cappedByTime: boolean }

local function computeIdle(now: number, lastSeenAt: number, idleRate: number): IdleResult
    if lastSeenAt <= 0 or idleRate <= 0 then
        return { seconds = 0, coins = 0, cappedByTime = false }
    end
    local elapsed = math.clamp(now - lastSeenAt, 0, ABS_MAX_ELAPSED)
    local counted = math.min(elapsed, BACKSTOP_SECONDS)
    return {
        seconds = counted,
        coins = counted * idleRate,
        cappedByTime = elapsed > BACKSTOP_SECONDS,
    }
end

return {
    computeOffline = computeOffline,
    computeIdle = computeIdle,
    BACKSTOP_SECONDS = BACKSTOP_SECONDS,
}
