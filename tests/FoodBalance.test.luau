local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FoodBalance = require("../src/Shared/Modules/FoodBalance")
local SettlerConfig = require("../src/Shared/Config/SettlerConfig")

return function()
    test.suite("FoodBalance", function()
        test.case("consumul creste proportional cu populatia", function()
            local one = FoodBalance.consumptionPerMinute(1)
            check.is_true(one > 0)
            check.is_true(math.abs(FoodBalance.consumptionPerMinute(10) - one * 10) < 1e-6)
            check.equal(FoodBalance.consumptionPerMinute(0), 0)
        end)

        test.case("populatia negativa nu produce consum negativ", function()
            check.equal(FoodBalance.consumptionPerMinute(-5), 0)
        end)

        test.case("gradinarii produc doar daca au locuri in gradina", function()
            check.equal(FoodBalance.productionPerMinute(0, 4, 0), 0)
            check.is_true(FoodBalance.productionPerMinute(0, 4, 2) > 0)
        end)

        test.case("mai multi gradinari decat locuri nu produc mai mult", function()
            local full = FoodBalance.productionPerMinute(0, 2, 2)
            local crowded = FoodBalance.productionPerMinute(0, 8, 2)
            check.is_true(math.abs(full - crowded) < 1e-6)
        end)

        test.case("pescarii produc fara nicio cladire", function()
            check.is_true(FoodBalance.productionPerMinute(3, 0, 0) > 0)
        end)

        test.case("colonia de start se sustine singura", function()
            -- 12 oameni impartiti pe rand la 5 meserii inseamna 2-3 pescari si niciun gradinar
            -- pana nu se construieste gradina. Trebuie sa iasa pe plus, altfel primul minut de
            -- joc incepe cu o criza pe care jucatorul nu are cum sa o inteleaga.
            local production = FoodBalance.productionPerMinute(2, 0, 0)
            local consumption = FoodBalance.consumptionPerMinute(12)
            check.is_true(production > consumption)
        end)

        test.case("pescuitul are plafon: peste locurile de pe rau nu creste", function()
            -- Fara plafon, meseriile impartite pe rand faceau ca productia sa creasca odata cu
            -- populatia, deci raportul ramanea acelasi la orice marime si nu exista presiune.
            local atCap = FoodBalance.productionPerMinute(SettlerConfig.FISH_SPOTS, 0, 0)
            local over = FoodBalance.productionPerMinute(SettlerConfig.FISH_SPOTS * 4, 0, 0)
            check.is_true(math.abs(atCap - over) < 1e-6)
        end)

        test.case("pescuitul singur nu duce colonia oricat de departe", function()
            -- Acesta e testul care apara PRESIUNEA: la un moment dat trebuie sa construiesti
            -- gradini. Daca pica, inseamna ca cineva a facut hrana gratuita din nou.
            local fishingOnly = FoodBalance.productionPerMinute(99, 0, 0)
            local supported = FoodBalance.supportedPopulation(fishingOnly)
            check.is_true(supported < SettlerConfig.HARD_CAP)
            check.is_true(supported > 12) -- dar nici sa nu fie criza din primul minut
        end)

        test.case("gradinile ridica plafonul", function()
            local withoutGarden = FoodBalance.productionPerMinute(99, 4, 0)
            local withGarden = FoodBalance.productionPerMinute(99, 4, 4)
            check.is_true(withGarden > withoutGarden)
        end)

        test.case("supportedPopulation e inversul consumului", function()
            local production = FoodBalance.productionPerMinute(4, 0, 0)
            local supported = FoodBalance.supportedPopulation(production)
            check.is_true(supported > 0)
            check.is_true(FoodBalance.consumptionPerMinute(supported) <= production)
        end)
    end)
end
