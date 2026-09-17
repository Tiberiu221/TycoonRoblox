--!strict
-- [D61] Jocurile de la gherete: miscarea, scorul, pachetul de apasari si premiile.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local BoothMath = require("../src/Shared/Modules/BoothMath")

-- Un jucator fara greseala: pentru fiecare aruncare cauta, de la prima clipa permisa, momentul bun (asa cum ar
-- tinti cineva cu ochii pe ecran). Intoarce apasarile.
local function perfectRing(seed: number): { number }
    local presses: { number } = {}
    local spec = BoothMath.GAMES.ring
    for i = 1, spec.throws do
        local start = BoothMath.windowStart("ring", presses, i)
        local t = spec.minAim
        while BoothMath.ringHit(BoothMath.ringX(t, seed, i)) == nil do
            t += 0.005
        end
        presses[i] = start + t
    end
    return presses
end

local function perfectDucks(seed: number): { number }
    local presses: { number } = {}
    local spec = BoothMath.GAMES.duck
    local five = table.find(BoothMath.DUCKS, 5) :: number
    for i = 1, spec.throws do
        local p = BoothMath.windowStart("duck", presses, i) + spec.minAim
        while BoothMath.duckUnder(p, seed) ~= five do
            p += 0.005
        end
        presses[i] = p
    end
    return presses
end

return function()
    test.suite("BoothMath", function()
        test.case("inelul se leagana deasupra raftului, la fel pentru aceeasi samanta", function()
            for ring = 1, 5 do
                for t = 0, 10, 0.37 do
                    local x = BoothMath.ringX(t, 42, ring)
                    check.is_true(x >= 0.04 and x <= 0.96)
                    check.equal(x, BoothMath.ringX(t, 42, ring))
                end
            end
            check.is_false(BoothMath.ringX(1, 42, 1) == BoothMath.ringX(1, 43, 1))
        end)

        test.case("inelul cade pe gatul sticlei de sub el, altfel pe langa", function()
            check.equal(BoothMath.ringHit(0.25), 1)
            check.equal(BoothMath.ringHit(0.5), 2)
            check.equal(BoothMath.ringHit(0.75 + BoothMath.NECK * 0.99), 3)
            check.equal(BoothMath.ringHit(0.375), nil)
            check.equal(BoothMath.ringHit(0.02), nil)
        end)

        test.case(
            "cine tinteste bine ia 5 din 5 la orice samanta; cine apasa oricand, mai putin",
            function()
                for seed = 1, 40 do
                    local presses = perfectRing(seed * 7919)
                    check.is_true(BoothMath.valid("ring", presses, presses[#presses]))
                    local score = BoothMath.score("ring", seed * 7919, presses)
                    check.equal(score, 5)
                    check.is_true(BoothMath.perfect("ring", score))
                end
                -- apasat imediat ce se poate, fara sa te uiti: rar 5
                local lucky = 0
                for seed = 1, 60 do
                    local presses: { number } = {}
                    for i = 1, 5 do
                        presses[i] = BoothMath.windowStart("ring", presses, i)
                            + BoothMath.GAMES.ring.minAim
                    end
                    if BoothMath.score("ring", seed, presses) == 5 then
                        lucky += 1
                    end
                end
                check.is_true(lucky <= 3)
            end
        )

        test.case("ratustele trec pe sub carlig; de trei ori cea de 5 face 15", function()
            for seed = 1, 20 do
                local presses = perfectDucks(seed * 104729)
                check.is_true(BoothMath.valid("duck", presses, presses[#presses]))
                local score, results = BoothMath.score("duck", seed * 104729, presses)
                check.equal(score, 15)
                check.is_true(BoothMath.perfect("duck", score))
                check.equal(BoothMath.DUCKS[results[1]], 5)
            end
            -- ratusca de 5 e cea mai rapida
            check.is_true(BoothMath.DUCK_SPEED[5] > BoothMath.DUCK_SPEED[3])
            check.is_true(BoothMath.DUCK_SPEED[3] > BoothMath.DUCK_SPEED[1])
        end)

        test.case("un pachet de apasari facut de mana nu trece", function()
            local ok = perfectRing(5)
            local elapsed = ok[#ok]
            check.is_true(BoothMath.valid("ring", ok, elapsed))
            -- prea putine, prea multe, alt joc
            check.is_false(BoothMath.valid("ring", { 1, 2, 3 }, 60))
            check.is_false(BoothMath.valid("nope", ok, elapsed))
            check.is_false(BoothMath.valid("ring", "abc", elapsed))
            -- toate deodata, sau inainte sa apara inelul
            check.is_false(BoothMath.valid("ring", { 1.3, 1.3, 1.3, 1.3, 1.3 }, 60))
            check.is_false(BoothMath.valid("ring", { 0.1, 2, 4, 6, 8 }, 60))
            -- numere care nu sunt numere
            check.is_false(BoothMath.valid("ring", { 1.5, 0 / 0, 5, 7, 9 }, 60))
            check.is_false(BoothMath.valid("ring", { 1.5, 3, 5, 7, math.huge }, 60))
            -- apasari din viitor (dupa ceasul serverului) sau un joc prea lung
            check.is_false(BoothMath.valid("ring", ok, elapsed - BoothMath.TOLERANCE - 0.5))
            check.is_false(BoothMath.valid("ring", { 1.3, 3, 5, 7, 95 }, 200))
        end)

        test.case(
            "premiile: inelele 0/1/2/4/6/10, ratustele pe benzi; cel mult 50 de perle pe zi",
            function()
                local expect = { 0, 1, 2, 4, 6, 10 }
                for hits = 0, 5 do
                    check.equal(BoothMath.prize("ring", hits), expect[hits + 1])
                end
                check.equal(BoothMath.prize("duck", 0), 1)
                check.equal(BoothMath.prize("duck", 3), 1)
                check.equal(BoothMath.prize("duck", 4), 2)
                check.equal(BoothMath.prize("duck", 9), 4)
                check.equal(BoothMath.prize("duck", 12), 6)
                check.equal(BoothMath.prize("duck", 15), 10)
                check.equal(BoothMath.maxPrize(), 10)
                check.is_true(BoothMath.PRIZE_GAMES * BoothMath.maxPrize() <= 50)
                check.is_false(BoothMath.perfect("duck", 14))
            end
        )

        test.case("ziua jocurilor cu premiu e ziua UTC", function()
            local midnight = 1789344000
            check.equal(BoothMath.dayKey(midnight), BoothMath.dayKey(midnight + 86399))
            check.equal(BoothMath.dayKey(midnight + 86400), BoothMath.dayKey(midnight) + 1)
        end)
    end)
end
