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

return { computeOffline = computeOffline, BACKSTOP_SECONDS = BACKSTOP_SECONDS }
