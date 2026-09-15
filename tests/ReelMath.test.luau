-- [D59] Bara de mulinat nu are esec. Regula care nu se negociaza e dovedita aici, nu presupusa: pe multe seminte si pe
-- toate dificultatile, doar tinand apasat tot timpul scoti pestele intr-un timp marginit; iar serverul nu crede o
-- scoatere mai rapida decat jocul perfect pe aceeasi bara.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ReelMath = require("../src/Shared/Modules/ReelMath")

local HOLD_LIMIT = 30 -- secunde: "doar tinut apasat" nu trebuie sa para niciodata un blocaj
local SEEDS = 300

local function seedOf(i: number): number
    return (i * 2654435761 + 97) % 4294967296
end

return function()
    test.suite("ReelMath - fara esec", function()
        test.case(
            "doar tinut apasat scoate orice peste, sub limita, pe toate dificultatile",
            function()
                local worst = 0
                for d = 1, #ReelMath.SPECS do
                    for i = 1, SEEDS do
                        worst = math.max(worst, ReelMath.simulate(seedOf(i), d, "hold"))
                    end
                end
                check.is_true(worst < HOLD_LIMIT)
            end
        )

        test.case("jocul perfect nu e niciodata mai lent decat tinutul apasat", function()
            local slower = 0
            for d = 1, #ReelMath.SPECS do
                for i = 1, 60 do
                    local s = seedOf(i)
                    if
                        ReelMath.simulate(s, d, "perfect")
                        > ReelMath.simulate(s, d, "hold") + 1e-9
                    then
                        slower += 1
                    end
                end
            end
            check.equal(slower, 0)
        end)

        test.case(
            "progresul nu scade sub zero si nu trece de unu; fara buton nu se misca",
            function()
                check.equal(ReelMath.step(0, 1, true, false, 5), 0)
                check.equal(ReelMath.step(0.99, 1, true, true, 1), 1)
                check.equal(ReelMath.step(0.4, 1, false, true, 3), 0.4)
                check.equal(ReelMath.step(0.4, 1, false, false, 3), 0.4)
            end
        )

        test.case("pestele ramane pe bara", function()
            local outside = 0
            for d = 1, #ReelMath.SPECS do
                for k = 0, 600 do
                    local pos = ReelMath.fishAt(k / 10, seedOf(d * 13), d)
                    if pos < 0 or pos > 1 then
                        outside += 1
                    end
                end
            end
            check.equal(outside, 0)
        end)
    end)

    test.suite("ReelMath - cat de repede se poate", function()
        test.case(
            "aceeasi samanta da aceeasi bara (clientul si serverul vad acelasi peste)",
            function()
                check.equal(ReelMath.fishAt(3.7, 12345, 4), ReelMath.fishAt(3.7, 12345, 4))
                check.equal(ReelMath.minSeconds(777, 2), ReelMath.minSeconds(777, 2))
            end
        )

        test.case("mai greu inseamna mai lung, in medie", function()
            local prev = 0
            for d = 1, #ReelMath.SPECS do
                local sum = 0
                for i = 1, 80 do
                    sum += ReelMath.minSeconds(seedOf(i), d)
                end
                local avg = sum / 80
                check.is_true(avg > prev)
                prev = avg
            end
        end)

        test.case("nici cel mai bun jucator nu termina sub doua secunde", function()
            local fastest = math.huge
            for d = 1, #ReelMath.SPECS do
                for i = 1, SEEDS do
                    fastest = math.min(fastest, ReelMath.minSeconds(seedOf(i), d))
                end
            end
            check.is_true(fastest >= 2)
        end)
    end)
end
