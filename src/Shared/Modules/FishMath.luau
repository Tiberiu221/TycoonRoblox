--!strict
-- [D59] Ce prinzi la undita si cat valoreaza. Modul PUR: primeste tragerile in [0, 1) si intoarce specia, marimea si
-- perlele. Trage serverul (FishService), la aruncare, din samanta profilului; clientul afla abia la scoatere [D13].
local FishConfig =
    require(script and script.Parent.Parent.Config.FishConfig or "../Config/FishConfig")

local FishMath = {}

local function totalWeight(): number
    local total = 0
    for _, t in FishConfig.TIERS do
        total += t.weight
    end
    return total
end

function FishMath.tierOf(species: FishConfig.Species): FishConfig.Tier
    return FishConfig.tierById[species.tier]
end

function FishMath.pickTier(roll: number): FishConfig.Tier
    local target = math.clamp(roll, 0, 0.9999999) * totalWeight()
    local acc = 0
    for _, t in FishConfig.TIERS do
        acc += t.weight
        if target < acc then
            return t
        end
    end
    return FishConfig.TIERS[#FishConfig.TIERS]
end

-- Specia: intai raritatea (ponderile ei), apoi una din speciile raritatii, la fel de probabile.
function FishMath.pickSpecies(tierRoll: number, speciesRoll: number): FishConfig.Species
    local tier = FishMath.pickTier(tierRoll)
    local pool = {}
    for _, s in FishConfig.SPECIES do
        if s.tier == tier.id then
            table.insert(pool, s)
        end
    end
    local i = 1 + math.floor(math.clamp(speciesRoll, 0, 0.9999999) * #pool)
    return pool[i]
end

-- Marimea in centimetri, intreaga: mai des spre mica (un record trebuie sa insemne ceva).
function FishMath.size(species: FishConfig.Species, roll: number): number
    local t = math.clamp(roll, 0, 1) ^ 1.6
    return math.floor(species.minCm + (species.maxCm - species.minCm) * t + 0.5)
end

-- Perlele unui peste: ale raritatii, x2 cu momeala aurie, plus bonusul primei prinderi a speciei (nu se dubleaza).
function FishMath.pearlsFor(species: FishConfig.Species, isNew: boolean, baited: boolean): number
    local base = FishMath.tierOf(species).pearls
    if baited then
        base *= FishConfig.BAIT_MULTIPLIER
    end
    return base + (if isNew then FishConfig.FIRST_CATCH_BONUS else 0)
end

-- Media perlelor pe peste, fara bonusuri: din ponderi, pentru bugetul perlelor.
function FishMath.expectedPearls(): number
    local total = totalWeight()
    local sum = 0
    for _, t in FishConfig.TIERS do
        sum += t.weight / total * t.pearls
    end
    return sum
end

function FishMath.tierWeight(tier: FishConfig.Tier): number
    return tier.weight / totalWeight()
end

return FishMath
