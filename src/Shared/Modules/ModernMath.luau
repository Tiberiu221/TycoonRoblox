--!strict
-- [D70] SATUL SE MODERNIZEAZA IN ERA 3. Owner-ul, 2026-09-24: "aș prefera ca de la Era 3 harta să se schimbe progresiv,
-- din ce în ce mai modernă." Satul vechi (Landing, Moara) isi schimba infatisarea pe trepte, legate de cumparaturile
-- Erei 3, pana la baraj. E doar desen: nicio cifra din simulator nu depinde de treapta. Modul pur: primeste starea,
-- spune treapta; se citeste la fel acasa si in satul vizitat din balci.
local ModernMath = {}

export type Facts = {
    pads: { [string]: boolean }, -- platformele cumparate
    crews: { [string]: number }, -- meseria -> cati oameni are
    powerSold: boolean, -- s-a vandut deja curent (TycoonState.firsts.power)
}

-- Treptele, in ordinea din simulator (minutele sunt ale jucatorului lacom, docs/PLAN-HARTA.md):
--   1 wire    Clerk angajat (~4 min)            stalpi cu sarma pe toate strazile
--   2 carts   Thirteenth Net (~14 min)          roabele devin carucioare de fier
--   3 brick   al doilea Works Porter (~19 min)  tabla si caramida pe cladirile vechi
--   4 glass   Power House (~41 min)             geamuri; tarusii topografilor, masa Dam Plans
--   5 lights  primul curent vandut (~48 min)    satul se lumineaza
ModernMath.STAGES =
    {
        { key = "wire", pad = "hire_clerk" },
        { key = "carts", pad = "thirteenth_net" },
        { key = "brick", crew = "worksPorter", count = 2 },
        { key = "glass", pad = "power_house" },
        { key = "lights", power = true },
    } :: { { key: string, pad: string?, crew: string?, count: number?, power: boolean? } }

local function holds(
    step: { pad: string?, crew: string?, count: number?, power: boolean? },
    f: Facts
): boolean
    if step.pad ~= nil then
        return f.pads[step.pad] == true
    elseif step.crew ~= nil then
        return (f.crews[step.crew] or 0) >= (step.count or 1)
    elseif step.power then
        return f.powerSold
    end
    return false
end

-- Treapta (0..5): cea mai inalta pentru care TOATE treptele de pana la ea sunt implinite. Asa satul nu sare o treapta
-- si nu da inapoi: cine angajeaza al doilea Works Porter inaintea plasei a 13-a asteapta plasa pentru tabla.
function ModernMath.stage(f: Facts): number
    local stage = 0
    for i, step in ModernMath.STAGES do
        if not holds(step, f) then
            break
        end
        stage = i
    end
    return stage
end

-- Treapta are cel putin cheia data ("brick" -> 3 sau mai mult).
function ModernMath.has(stage: number, key: string): boolean
    for i, step in ModernMath.STAGES do
        if step.key == key then
            return stage >= i
        end
    end
    return false
end

return ModernMath
