--!strict
-- [D60] Cele doua locuri ale jocului, pe univers: satul (place-ul de start) si balciul de seara. Barca te duce dintr-unul
-- in celalalt cu TeleportService, deci fiecare parte trebuie sa stie id-ul celeilalte. Id-urile nu sunt secrete; cheia
-- de publicare, da, si ea nu sta aici [CLAUDE.md].
local PlaceConfig = {}

export type Places = { village: number, fair: number? }

PlaceConfig.BY_UNIVERSE = {
    -- staging: "Driftycoon (Staging)", balciul creat pe 2026-09-16
    [10765888327] = { village = 132381101591529, fair = 114983498774894 },
    -- productia: balciul nu e inca publicat acolo
    [10766553412] = { village = 101083147721008, fair = nil },
} :: { [number]: Places }

function PlaceConfig.forUniverse(gameId: number): Places?
    return PlaceConfig.BY_UNIVERSE[gameId]
end

return PlaceConfig
