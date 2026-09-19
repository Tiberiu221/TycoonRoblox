--!strict
-- Meseriile unui jucator [D49]. Modul PUR: aceleasi reguli pe server (care incaseaza si angajeaza),
-- pe client (care arata butoanele din meniul meseriei) si in teste -- un buton care promite ce
-- serverul refuza ar fi un text care minte [D40].
--
-- In profil, oamenii stau in `data.Hands` (cate o intrare pe om, cu rolul lui), iar treapta meseriei
-- in `data.Crews[rol].tier` -- una pe meserie, comuna oamenilor din ea (uneltele meseriei).
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local CrewMath = {}

-- Cheia unui om in `data.Hands`. Primul = id-ul platformei, ca in D46-D48 (e si samanta numelui si a
-- infatisarii lui, deci nimeni nu-si schimba fata la migrare); al doilea = "<platforma>_2".
function CrewMath.personKey(role: string, index: number): string?
    local crew = TycoonConfig.CREWS[role]
    if crew == nil then
        return nil
    end
    return if index <= 1 then crew.pad else `{crew.pad}_{index}`
end

-- Al catelea om din meseria lui e cel cu cheia asta (1 sau 2).
function CrewMath.indexOf(handId: string): number
    local n = string.match(handId, "_(%d+)$")
    return if n ~= nil then tonumber(n) :: number else 1
end

-- Meseriile din profil: cati oameni (numarati din Hands, dupa rol) si ce treapta (din Crews, taiata
-- la 1..TIER_MAX -- un profil stricat nu are voie sa dea un debit inventat).
function CrewMath.fromProfile(
    hands: { [string]: { role: string } },
    crews: { [string]: { tier: number } }?
): { [string]: ChainMath.Crew }
    local out = ChainMath.emptyCrews()
    for _, hand in hands do
        local crew = out[hand.role]
        if crew ~= nil then
            crew.count += 1
        end
    end
    for role, crew in out do
        local saved = if crews ~= nil then crews[role] else nil
        if saved ~= nil and type(saved.tier) == "number" and saved.tier == saved.tier then
            crew.tier = math.clamp(math.floor(saved.tier), 1, StationConfig.TIER_MAX)
        end
    end
    return out
end

-- Se poate urca treapta? Motivul refuzului e un cuvant pe care il traduc meniul si toast-ul.
function CrewMath.canUpgradeTier(crew: ChainMath.Crew): (boolean, string?)
    if crew.count == 0 then
        return false, "no_person"
    end
    if crew.tier >= StationConfig.TIER_MAX then
        return false, "max_tier"
    end
    return true, nil
end

-- Se poate angaja al doilea om? Doar peste un prim om, de la SECOND_AT_TIER, cel mult MAX_PEOPLE.
function CrewMath.canHireSecond(crew: ChainMath.Crew): (boolean, string?)
    if crew.count == 0 then
        return false, "no_person"
    end
    if crew.count >= StationConfig.MAX_PEOPLE then
        return false, "max_people"
    end
    if crew.tier < StationConfig.SECOND_AT_TIER then
        return false, "tier"
    end
    return true, nil
end

-- [D65] `role`: oamenii Erei 2 platesc treptele de ERA2_MULT ori mai scump; fara el, pretul Erei 1.
function CrewMath.tierPrice(crew: ChainMath.Crew, role: string?): number
    return ChainMath.tierCost(crew.tier, role)
end

function CrewMath.secondPrice(role: string): number?
    local crew = TycoonConfig.CREWS[role]
    return if crew ~= nil then crew.secondPrice else nil
end

-- Nimic de cumparat pe meseria asta in Era 1: doi oameni, treapta maxima. Daca tocmai ea e veriga
-- slaba, ecranul trebuie sa trimita la clopot, nu sa scrie "No gain yet" [D49].
function CrewMath.maxed(crew: ChainMath.Crew): boolean
    return crew.count >= StationConfig.MAX_PEOPLE and crew.tier >= StationConfig.TIER_MAX
end

return CrewMath
