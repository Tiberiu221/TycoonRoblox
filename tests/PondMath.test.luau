--!strict
-- [D61] Concursul de la iaz: runda dupa ceas, clasamentul si premiile.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local PondMath = require("../src/Shared/Modules/PondMath")

-- 2026-09-17 00:00 UTC (verificat: 1789344000 era luni, 2026-09-14)
local DAY = 1789344000 + 3 * 86400

local function catch(id: number, cm: number, at: number): PondMath.Catch
    return { userId = id, name = `P{id}`, species = "roach", cm = cm, at = at }
end

return function()
    test.suite("PondMath", function()
        test.case(
            "runda: 4 minute de pescuit, apoi 2 de rezultate, la fel pe orice server",
            function()
                local r = PondMath.roundAt(DAY)
                check.equal(r.index, 1)
                check.equal(r.phase, "fishing")
                check.equal(r.startsAt, DAY)
                check.equal(r.fishingEndsAt, DAY + 240)
                check.equal(r.nextAt, DAY + 360)
                check.equal(PondMath.roundAt(DAY + 239).phase, "fishing")
                check.equal(PondMath.roundAt(DAY + 240).phase, "results")
                check.equal(PondMath.roundAt(DAY + 359).id, r.id)
                local next = PondMath.roundAt(DAY + 360)
                check.equal(next.id, r.id + 1)
                check.equal(next.index, 2)
                check.equal(next.phase, "fishing")
                -- ultima runda din zi e a 240-a, iar ziua urmatoare incepe iar de la 1
                check.equal(PondMath.roundAt(DAY + 86400 - 1).index, 240)
                check.equal(PondMath.roundAt(DAY + 86400).index, 1)
            end
        )

        test.case("se tine minte doar cel mai mare peste al fiecaruia", function()
            local best: { [number]: PondMath.Catch } = {}
            check.is_true(PondMath.record(best, catch(1, 20, 5)))
            check.is_false(PondMath.record(best, catch(1, 20, 6)))
            check.is_false(PondMath.record(best, catch(1, 12, 7)))
            check.is_true(PondMath.record(best, catch(1, 31, 8)))
            check.equal(best[1].cm, 31)
            check.equal(best[1].at, 8)
        end)

        test.case("castiga pestele cel mai mare; la egalitate, cine l-a scos primul", function()
            local best: { [number]: PondMath.Catch } = {}
            PondMath.record(best, catch(7, 40, 30))
            PondMath.record(best, catch(3, 40, 10))
            PondMath.record(best, catch(9, 55, 50))
            PondMath.record(best, catch(4, 12, 1))
            local ranked = PondMath.rank(best)
            check.equal(ranked[1].userId, 9)
            check.equal(ranked[2].userId, 3)
            check.equal(ranked[3].userId, 7)
            check.equal(ranked[4].userId, 4)
            check.equal(PondMath.placeOf(ranked, 7), 3)
            check.equal(PondMath.placeOf(ranked, 99), nil)
        end)

        test.case("premiile: 20/12/8 si 3 pentru ceilalti; singur, doar 3", function()
            local alone = PondMath.prizes({ catch(1, 10, 1) })
            check.equal(alone[1], PondMath.TAKE_PART)
            local two = PondMath.prizes({ catch(1, 10, 1), catch(2, 9, 1) })
            check.equal(two[1], 20)
            check.equal(two[2], 12)
            local five = PondMath.prizes({
                catch(1, 50, 1),
                catch(2, 40, 1),
                catch(3, 30, 1),
                catch(4, 20, 1),
                catch(5, 10, 1),
            })
            check.equal(five[3], 8)
            check.equal(five[4], 3)
            check.equal(five[5], 3)
            check.equal(#PondMath.prizes({}), 0)
            -- cel mai mic loc cu premiu da mai mult decat simpla participare
            check.is_true(PondMath.PRIZES[#PondMath.PRIZES] > PondMath.TAKE_PART)
        end)
    end)
end
