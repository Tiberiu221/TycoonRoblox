--!strict
-- Reguli de reparatie REPLICATE (clientul le afiseaza; serverul le aplica). Valori de PROTOTIP, scurtate
-- fata de tabelul 6.3b (Comun 5-15 min ... Secret 21 zile) ca sa se poata testa intr-o sesiune [DECIZII D16].
local RepairConfig = {
    WORKSHOP_SLOTS_FREE = 3, -- [DECIZII D16]
    -- Praguri de Index care mai deschid cate un slot de reparatie [DECIZII D16, D17]. Replicate,
    -- fiindca interfata trebuie sa scrie pragul adevarat, nu "Unlocks with progress".
    SLOT_GATES = { 0.25, 0.5 },
    TIERS = {
        common = { repairSeconds = 45, materialsCost = 0, scrapYield = 1 },
        uncommon = { repairSeconds = 120, materialsCost = 1, scrapYield = 2 },
        rare = { repairSeconds = 300, materialsCost = 2, scrapYield = 3 },
        epic = { repairSeconds = 900, materialsCost = 3, scrapYield = 5 },
        legendary = { repairSeconds = 1800, materialsCost = 5, scrapYield = 8 },
        mythic = { repairSeconds = 3600, materialsCost = 8, scrapYield = 12 },
    },
}
return RepairConfig
