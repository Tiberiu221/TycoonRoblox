--!strict
-- Valori care NU se replica la client [MASTERPLAN 4.3.1]. Ipoteze de tuning; live prin ConfigService (chei snake_case, 6.7).
return {
    profile_autosave_seconds = 120, -- [DECIZII D14]
    prototype_unlocked_net_slots = 3, -- pasul 1: toate sloturile deblocate pentru playtest; progresia D28 vine cu Indexul
    net_offline_backstop_hours = 24, -- [DECIZII D15]
    -- ponderi de loot pe tier, recalibrate pentru T = 25 prinderi/zi [DECIZII D17]
    rarity_weights = {
        common = 0.537,
        uncommon = 0.248,
        rare = 0.128,
        epic = 0.061,
        legendary = 0.021,
        mythic = 0.0045,
    },
}
