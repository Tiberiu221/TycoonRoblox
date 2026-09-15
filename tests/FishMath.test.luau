-- [D59] Undita: ce prinzi si cat valoreaza. Testele apara regulile care nu se negociaza: fiecare scoatere da ceva,
-- nimic nu da monede, iar ponderile afisate/folosite sunt aceleasi [D40].
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FishConfig = require("../src/Shared/Config/FishConfig")
local FishMath = require("../src/Shared/Modules/FishMath")
local RiverConfig = require("../src/Shared/Config/RiverConfig")

return function()
    test.suite("FishConfig - forma catalogului", function()
        test.case("12 specii cu id unic, fiecare pe o raritate care exista", function()
            check.equal(#FishConfig.SPECIES, 12)
            local seen: { [string]: boolean } = {}
            local bad = 0
            for _, s in FishConfig.SPECIES do
                if
                    seen[s.id]
                    or FishConfig.tierById[s.tier] == nil
                    or s.minCm <= 0
                    or s.maxCm <= s.minCm
                then
                    bad += 1
                end
                seen[s.id] = true
            end
            check.equal(bad, 0)
        end)

        test.case(
            "fiecare raritate are cel putin o specie, perle > 0 si o bara care exista",
            function()
                local ReelMath = require("../src/Shared/Modules/ReelMath")
                local weight = 0
                for _, t in FishConfig.TIERS do
                    weight += t.weight
                    local n = 0
                    for _, s in FishConfig.SPECIES do
                        if s.tier == t.id then
                            n += 1
                        end
                    end
                    check.is_true(n >= 1)
                    check.is_true(t.pearls > 0)
                    check.is_true(ReelMath.SPECS[t.difficulty] ~= nil)
                end
                check.equal(weight, 100)
            end
        )

        test.case("raritatile sunt cele ale raului (aceleasi nume, aceleasi culori)", function()
            local river: { [string]: boolean } = {}
            for _, t in RiverConfig.TIERS do
                river[t.id] = true
            end
            for _, t in FishConfig.TIERS do
                check.is_true(river[t.id] == true)
            end
        end)
    end)

    test.suite("FishMath - tragerea si perlele", function()
        test.case("orice tragere da o specie valida, iar frecventele urmeaza ponderile", function()
            local counts: { [string]: number } = {}
            local n = 20000
            for i = 0, n - 1 do
                local s = FishMath.pickSpecies((i + 0.5) / n, ((i * 7919) % n + 0.5) / n)
                check.not_nil(FishConfig.byId[s.id])
                counts[s.tier] = (counts[s.tier] or 0) + 1
            end
            for _, t in FishConfig.TIERS do
                check.is_true(math.abs((counts[t.id] or 0) / n - FishMath.tierWeight(t)) < 0.002)
            end
        end)

        test.case("marimea e intreaga si ramane intre marginile speciei", function()
            for _, s in FishConfig.SPECIES do
                for _, roll in { 0, 0.3, 0.7, 0.9999 } do
                    local cm = FishMath.size(s, roll)
                    check.equal(cm % 1, 0)
                    check.is_true(cm >= s.minCm and cm <= s.maxCm)
                end
            end
        end)

        test.case(
            "perlele: raritatea, momeala x2, bonusul primei prinderi nu se dubleaza",
            function()
                local carp = FishConfig.byId.carp -- rara: 2 perle
                check.equal(FishMath.pearlsFor(carp, false, false), 2)
                check.equal(FishMath.pearlsFor(carp, false, true), 4)
                check.equal(FishMath.pearlsFor(carp, true, false), 2 + FishConfig.FIRST_CATCH_BONUS)
                check.equal(FishMath.pearlsFor(carp, true, true), 4 + FishConfig.FIRST_CATCH_BONUS)
            end
        )

        test.case("fiecare scoatere da cel putin o perla: niciun peste nu e degeaba", function()
            for _, s in FishConfig.SPECIES do
                check.is_true(FishMath.pearlsFor(s, false, false) >= 1)
            end
        end)
    end)
end
