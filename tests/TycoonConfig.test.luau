local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

return function()
    test.suite("TycoonConfig", function()
        test.case("48 de platforme, index = pozitia in lista", function()
            -- Bugul pe care il apara testul: daca `index` se dezalinieaza de pozitia reala,
            -- padStatuses (care merge prin PADS in ordine) si greedyRun (care citeste PRICES[k])
            -- ar arata/cumpara platforma gresita fara nicio eroare.
            check.equal(#TycoonConfig.PADS, 48)
            for i, p in TycoonConfig.PADS do
                check.equal(p.index, i)
            end
        end)

        test.case("12 platforme pe fiecare din cele 4 ere", function()
            local perEra = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
            for _, p in TycoonConfig.PADS do
                perEra[p.era] = (perEra[p.era] or 0) + 1
            end
            check.equal(perEra[1], 12)
            check.equal(perEra[2], 12)
            check.equal(perEra[3], 12)
            check.equal(perEra[4], 12)
        end)

        test.case("id-urile sunt unice", function()
            -- Un id duplicat ar insemna ca al doilea suprascrie primul in byId, si o platforma
            -- ar deveni imposibil de cumparat (numele ar exista, dar id-ul ar duce la alta).
            local seen = {}
            for _, p in TycoonConfig.PADS do
                check.is_true(seen[p.id] == nil)
                seen[p.id] = true
            end
        end)

        test.case("byId gaseste exact aceeasi platforma", function()
            for _, p in TycoonConfig.PADS do
                check.is_true(TycoonConfig.byId[p.id] == p)
            end
        end)

        test.case("motivul e unul din C/V/A/D", function()
            local valid = { C = true, V = true, A = true, D = true }
            for _, p in TycoonConfig.PADS do
                check.is_true(valid[p.motive] == true)
            end
        end)

        test.case("fiecare era se termina cu propriul clopot (motiv D)", function()
            -- Regula celor patru motive: D deschide urmatorul. Daca clopotul nu e ultimul,
            -- padStatuses ar putea arata platforme din era urmatoare inainte de a termina asta.
            for _, p in TycoonConfig.PADS do
                local isLastOfEra = p.index % 12 == 0
                check.equal(p.motive == "D", isLastOfEra)
            end
        end)

        test.case("fiecare platforma are cel putin un efect", function()
            -- O platforma fara efect n-ar misca venitul deloc -- exact ce interzice regula
            -- celor patru motive in simulator.
            for _, p in TycoonConfig.PADS do
                check.is_true(#p.effects >= 1)
            end
        end)

        test.case("ponderile GOODS insumeaza 1", function()
            local sum = 0
            for _, g in TycoonConfig.GOODS do
                sum += g.share
            end
            check.is_true(math.abs(sum - 1) < 1e-9)
        end)

        test.case("primul bun (driftwood) nu are minLanes", function()
            -- income() presupune ca GOODS[1] e bunul pe care cad ponderile celorlalte -- daca
            -- driftwood ar avea minLanes, portul din TycoonMath s-ar rupe in tacere.
            check.equal(TycoonConfig.GOODS[1].id, "driftwood")
            check.equal(TycoonConfig.GOODS[1].minLanes, nil)
        end)

        test.case("platformele live au pozitie in lume", function()
            -- O platforma jucabila fara pozitie n-ar avea unde sa fie desenata/atinsa.
            for _, p in TycoonConfig.PADS do
                if p.live then
                    check.is_true(p.x ~= nil)
                    check.is_true(p.y ~= nil)
                end
            end
        end)

        test.case("doar cele 9 platforme din F0 sunt live", function()
            local liveIds = {
                "first_net",
                "second_net",
                "bigger_sack",
                "third_net",
                "sorting_crate",
                "far_lane_net",
                "weighted_nets",
                "fifth_net",
                "dock_stall",
            }
            local expected = {}
            for _, id in liveIds do
                expected[id] = true
            end
            local liveCount = 0
            for _, p in TycoonConfig.PADS do
                check.equal(p.live, expected[p.id] == true)
                if p.live then
                    liveCount += 1
                end
            end
            check.equal(liveCount, #liveIds)
        end)

        test.case("preturile din PADS sunt exact cele din simulator", function()
            local prices = {
                0,
                9,
                18,
                25,
                40,
                50,
                80,
                130,
                200,
                220,
                300,
                450,
                550,
                750,
                1200,
                1500,
                2000,
                2500,
                3500,
                4000,
                6000,
                7500,
                9000,
                12000,
                15000,
                20000,
                25000,
                28000,
                30000,
                35000,
                40000,
                45000,
                50000,
                55000,
                60000,
                70000,
                75000,
                80000,
                90000,
                100000,
                110000,
                120000,
                130000,
                150000,
                160000,
                180000,
                200000,
                220000,
            }
            for i, p in TycoonConfig.PADS do
                check.equal(p.price, prices[i])
            end
        end)
    end)
end
