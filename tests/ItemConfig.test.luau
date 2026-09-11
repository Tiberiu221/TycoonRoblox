local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ItemConfig = require("../src/Shared/Config/ItemConfig")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local RepairConfig = require("../src/Shared/Config/RepairConfig")

return function()
    test.suite("ItemConfig", function()
        test.case("fiecare obiect are un tier real si o familie reala", function()
            -- Bugul pe care il apara testul: catalogul creste spre 200 de obiecte scrise de mana.
            -- Un tier scris gresit face obiectul de neprins (nu intra in niciun bazin) si un
            -- generator de pictograme care nu stie familia il deseneaza gol. Niciuna din cele
            -- doua greseli nu da eroare la rulare -- obiectul pur si simplu nu apare niciodata.
            local tiers, families = {}, {}
            for _, t in RiverConfig.TIERS do
                tiers[t.id] = true
            end
            for _, f in ItemConfig.FAMILIES do
                families[f] = true
            end
            for _, it in ItemConfig.ITEMS do
                check.is_true(tiers[it.tier] == true)
                check.is_true(families[it.family] == true)
                check.is_true(#it.name > 0)
                check.is_true(#it.flavour > 0)
                check.equal(#it.accent, 3)
            end
        end)

        test.case("id-urile sunt unice", function()
            -- Doua obiecte cu acelasi id: al doilea il ascunde pe primul din cautare, iar in
            -- Index ar conta ca acelasi lucru. Colectia ar fi imposibil de terminat.
            local seen = {}
            for _, it in ItemConfig.ITEMS do
                check.is_true(seen[it.id] == nil)
                seen[it.id] = true
            end
        end)

        test.case("fiecare tier are cel putin un obiect", function()
            -- Un tier gol inseamna ca raul poate rola o raritate pentru care nu exista nimic
            -- de prins. Prinderea ar cadea inapoi pe numele tierului -- exact ce am scos.
            for _, t in RiverConfig.TIERS do
                check.is_true(#ItemConfig.ofTier(t.id) > 0)
            end
        end)

        test.case("alegerea e determinista si acopera tot bazinul", function()
            -- Serverul si clientul aleg obiectul separat, din acelasi id. Daca alegerea n-ar fi
            -- determinista, mesajul "Caught: X" si ce ajunge in gramada ar fi lucruri diferite.
            for _, t in RiverConfig.TIERS do
                local first = ItemConfig.pickFor(t.id, 12345)
                local again = ItemConfig.pickFor(t.id, 12345)
                check.is_true(first ~= nil)
                check.equal((first :: any).id, (again :: any).id)

                local bucket = ItemConfig.ofTier(t.id)
                local hit = {}
                for seed = 1, #bucket * 60 do
                    local picked = ItemConfig.pickFor(t.id, seed)
                    hit[(picked :: any).id] = true
                end
                local n = 0
                for _ in hit do
                    n += 1
                end
                check.equal(n, #bucket) -- niciun obiect nu e imposibil de prins
            end
        end)

        test.case("obiectele comune sunt mai multe decat cele rare", function()
            -- Frecventa de prindere e 53.7% comun si 0.45% mitic. Daca ar fi la fel de multe
            -- obiecte in ambele bazine, cele comune s-ar repeta din a doua prindere, iar cele
            -- mitice n-ar fi niciodata de gasit toate.
            check.is_true(#ItemConfig.ofTier("common") > #ItemConfig.ofTier("rare"))
            check.is_true(#ItemConfig.ofTier("rare") > #ItemConfig.ofTier("mythic"))
        end)

        test.case("pragurile de slot sunt atinse inainte de a termina colectia", function()
            -- Un prag peste 100% ar fi un slot pe care nu-l poate deschide nimeni, iar textul
            -- din interfata ("Opens at N% of the Index") ar fi o promisiune imposibila.
            for _, gate in RepairConfig.SLOT_GATES do
                check.is_true(gate > 0)
                check.is_true(gate < 1)
            end
        end)
    end)
end
