--!strict
-- Valori REPLICATE (ajung la client): tiere de plasa, sezoane. Ipoteze de tuning [DECIZII D28, D19].
-- Ratele secrete (ponderi de loot, praguri anti-exploit) stau in ServerStorage/Config, nu aici.
export type NetTier = { id: string, capacity: number, ratePerHour: number }

local EconomyConfig = {
    REFERENCE_RESOLUTION = Vector2.new(1920, 1080), -- [DECIZII D06]
    NET_TIERS = {
        start = { id = "start", capacity = 8, ratePerHour = 1.0 } :: NetTier,
        crafted = { id = "crafted", capacity = 12, ratePerHour = 1.4 } :: NetTier,
        deep = { id = "deep", capacity = 16, ratePerHour = 1.8 } :: NetTier,
    },
    NET_SLOTS_MAX = 3, -- [DECIZII D28]
    RIVER_LANES = 4, -- [DECIZII D28]; a patra banda ramane mereu neacoperita
    SEASON_LENGTH_SECONDS = 28 * 24 * 3600, -- [DECIZII D19]
    SEASONS = { "spring", "summer", "autumn", "winter" },
    SEASON_RATE_MODIFIERS = { spring = 1.0, summer = 1.4, autumn = 0.8, winter = 0.35 },
}

return EconomyConfig
