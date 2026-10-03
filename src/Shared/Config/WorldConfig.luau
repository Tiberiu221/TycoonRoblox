--!strict
-- [D70, pasul j6] LUMILE. Satul de pe rau (Erele 1-3) e lumea 1; barajul, cu Erele 4-7 spre dreapta, e lumea 2 (D74).
-- Lumea unui lucru se deriva din era lui (R3 din PLAN-MOTOR-UNIRE §16), fara un camp nou pe platforme. Modul pur.
local WorldConfig = {}

-- prima era a fiecarei lumi, in ordine
WorldConfig.FIRST_ERA = { 1, 4 } :: { number }
WorldConfig.COUNT = #WorldConfig.FIRST_ERA

-- Lumea unei ere: ultima lume a carei prima era nu e dupa ea.
function WorldConfig.worldOfEra(era: number): number
    local world = 1
    for w, first in WorldConfig.FIRST_ERA do
        if era >= first then
            world = w
        end
    end
    return world
end

-- Lumea dintr-o valoare de incredere indoielnica (profil, atribut, argument lipsa): un intreg intre 1 si COUNT, altfel 1.
function WorldConfig.sanitize(w: any): number
    if typeof(w) == "number" and w == w and w % 1 == 0 and w >= 1 and w <= WorldConfig.COUNT then
        return w
    end
    return 1
end

return WorldConfig
