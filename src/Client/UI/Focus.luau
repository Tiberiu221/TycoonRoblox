--!strict
-- Ce spune un obiect din lume despre sine cand esti langa el [D51]: cat de departe esti, unde sta
-- cardul, ce face E acum (daca face ceva) si ce meniu deschide Upgrade. Fiecare controller de obiect
-- da un `Focus(px, py)`; InteractController il alege pe cel mai apropiat si il deseneaza -- deci E
-- face exact ce scrie pe card, nu ce vine primul intr-o lista de prioritati.
export type Focus = {
    key: string, -- identitate stabila: "net:first_net", "storage", "sawmill", "dock", "pad:workshop"
    -- [2026-09-29] punctul din care se masoara `distance` (inelul, usa, plasa), in coordonatele terenului: ghidajul isi
    -- retrage sageata cand cardul de pe ecran e chiar al locului spre care arata (nil = nu se potriveste cu nimic)
    at: { x: number, y: number }?,
    distance: number,
    x: number, -- baza cardului, in coordonatele terenului
    y: number,
    action: string?, -- textul butonului de actiune, cu tasta pe tastatura; nil = nimic de facut
    act: (() -> ())?, -- ce fac E si butonul
    status: string?, -- in locul actiunii, cand nu se poate face nimic ("Sack full")
    upgradeKind: string?, -- meniul pe care il deschide Upgrade: "net" | "saw" | "forge" | "dock" | "crew"
    upgradeId: string?,
    -- [2026-09-30] o treaba in curs tine tasta E (undita aruncata: E mulineaza): nimic altceva nu ia E, cardul nu se vede
    holds: boolean?,
    -- [2026-09-30] ceva trecator (darul de pe rau): bate cardul tintei ghidajului, undita aruncata si cartonasul unei
    -- platforme
    urgent: boolean?,
}

local Focus = {}

function Focus.distance(ax: number, ay: number, bx: number, by: number): number
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

return Focus
