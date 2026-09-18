-- [D59] Bugetul perlelor. Monedele isi au simulatorul (sim_tycoon.py); perlele cumpara doar aspect, deci n-au nevoie de
-- unul -- dar cifrele lor tot trebuie sa se tina intre ele: ce aduce un minut la undita, un lucru adus de rau, o rotire,
-- si cat costa ce cumperi. Benzile de aici sunt tabelul din plan (§7); o cifra schimbata in config care iese din ele
-- pica aici, nu pe ecranul unui jucator care strange doua ore pentru o banca.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FishConfig = require("../src/Shared/Config/FishConfig")
local FishMath = require("../src/Shared/Modules/FishMath")
local ReelMath = require("../src/Shared/Modules/ReelMath")
local TreasureConfig = require("../src/Shared/Config/TreasureConfig")
local WheelConfig = require("../src/Shared/Config/WheelConfig")
local VillageConfig = require("../src/Shared/Config/VillageConfig")
local MonetizationConfig = require("../src/Shared/Config/MonetizationConfig")
local QuestConfig = require("../src/Shared/Config/QuestConfig")
local PondMath = require("../src/Shared/Modules/PondMath")
local BoothMath = require("../src/Shared/Modules/BoothMath")

-- Perle pe minut de pescuit continuu, cu bara tinuta apasat tot timpul (varianta lenta, deci cifra e cinstita).
local function fishingPerMinute(): number
    local reel = 0
    for _, tier in FishConfig.TIERS do
        local sum = 0
        for i = 1, 40 do
            sum += ReelMath.simulate((i * 2654435761 + 97) % 4294967296, tier.difficulty, "hold")
        end
        reel += FishMath.tierWeight(tier) * sum / 40
    end
    local cycle = FishConfig.CAST_SECONDS
        + (FishConfig.BITE_MIN + FishConfig.BITE_MAX) / 2
        + reel
        + FishConfig.RESULT_SECONDS
    return 60 / cycle * FishMath.expectedPearls()
end

local function treasureValue(): number
    local total, sum = 0, 0
    for _, k in TreasureConfig.KINDS do
        total += k.weight
        sum += k.weight * k.pearls
    end
    return sum / total
end

return function()
    test.suite("PearlBudget - cat aduce fiecare sursa", function()
        test.case("pescuitul continuu aduce intre 5 si 10 perle pe minut", function()
            local ppm = fishingPerMinute()
            check.is_true(ppm >= 5 and ppm <= 10)
        end)

        test.case("ce aduce raul: in medie 8-14 perle, cam o data la 4-8 minute", function()
            local ev = treasureValue()
            check.is_true(ev >= 8 and ev <= 14)
            local minutes = (TreasureConfig.INTERVAL_MIN + TreasureConfig.INTERVAL_MAX) / 2 / 60
            check.is_true(minutes >= 4 and minutes <= 8)
        end)

        test.case(
            "o rotire valoreaza in medie 8-16 perle, iar nimic de pe roata nu da monede",
            function()
                local total, value = 0, 0
                for _, p in WheelConfig.PRIZES do
                    total += p.weight
                    local worth = 0
                    if p.pearls ~= nil then
                        worth = p.pearls
                    elseif p.treasure ~= nil then
                        worth = TreasureConfig.byId[p.treasure].pearls
                    elseif p.bait ~= nil then
                        worth = p.bait
                            * FishMath.expectedPearls()
                            * (FishConfig.BAIT_MULTIPLIER - 1)
                    end
                    check.is_true(worth > 0)
                    check.is_true((p :: any).incomeSeconds == nil and (p :: any).coins == nil)
                    value += p.weight * worth
                end
                local perSpin = value / total
                check.is_true(perSpin >= 8 and perSpin <= 16)
            end
        )
    end)

    test.suite("PearlBudget - balciul [D61]", function()
        test.case(
            "concursul de la iaz: cine castiga toate rundele ia cel mult jumatate din cat aduce pescuitul",
            function()
                check.is_true(PondMath.bestPerMinute() <= 0.5 * fishingPerMinute())
            end
        )

        test.case("gheretele: cel mult 50 de perle pe zi", function()
            check.is_true(BoothMath.PRIZE_GAMES * BoothMath.maxPrize() <= 50)
        end)
    end)

    test.suite("PearlBudget - cat costa ce cumperi", function()
        test.case("primul decor se ia chiar din perlele capitolului 1 [D62]", function()
            -- quest-urile si recompensa capitolului (platita de la D62): la sfarsitul capitolului 1 ai exact cat
            -- costa primul lucru de la avizier, fara sa fi pescuit
            local chapterOne = QuestConfig.CHAPTERS[1].reward.pearls or 0
            for _, q in QuestConfig.CHAPTERS[1].quests do
                chapterOne += q.reward.pearls or 0
            end
            local cheapest = math.huge
            for _, d in VillageConfig.DECOR do
                cheapest = math.min(cheapest, d.price)
            end
            check.is_true(cheapest <= chapterOne)
        end)

        -- [D61, partea 2] Cele patru tinute ale croitoresei au urcat catalogul de la 2.010 la 3.310, deci plafonul a
        -- urcat de la 3.000 la 4.000. De la D61 perlele vin si din iaz si din gherete, nu doar din undita de acasa;
        -- ce vinde satul (avizierul) ramane sub vechiul plafon, ca bucla de acasa sa nu se lungeasca.
        test.case(
            "tot ce se vinde costa 1.500-4.000 de perle: 2-8 ore de pescuit continuu",
            function()
                local total, atHome = 0, 0
                for _, d in VillageConfig.DECOR do
                    check.is_true(d.price > 0)
                    total += d.price
                    atHome += d.price
                end
                for _, o in VillageConfig.OUTFITS do
                    total += o.price or 0
                    if not o.tailor then
                        atHome += o.price or 0
                    end
                end
                check.is_true(total >= 1500 and total <= 4000)
                check.is_true(atHome <= 3000)
                local hours = total / (fishingPerMinute() * 60)
                check.is_true(hours >= 2 and hours <= 8)
            end
        )

        test.case(
            "decorul e in ordinea pretului, iar o tinuta fie se vinde, fie vine din jurnal",
            function()
                local prev = 0
                for _, d in VillageConfig.DECOR do
                    check.is_true(d.price >= prev)
                    prev = d.price
                end
                -- [D61, partea 2] ...sau cu un pass: niciodata doua cai pentru aceeasi tinuta
                for _, o in VillageConfig.OUTFITS do
                    local ways = (if o.price ~= nil then 1 else 0)
                        + (if o.journal == true then 1 else 0)
                        + (if o.pass ~= nil then 1 else 0)
                    check.equal(ways, 1)
                    if o.pass ~= nil then
                        check.not_nil(MonetizationConfig.byKey[o.pass])
                        check.equal(MonetizationConfig.byKey[o.pass].kind, "pass")
                    end
                end
                check.not_nil(VillageConfig.outfitById[VillageConfig.DEFAULT_OUTFIT])
                check.equal(VillageConfig.outfitById[VillageConfig.DEFAULT_OUTFIT].price, 0)
            end
        )
    end)
end
