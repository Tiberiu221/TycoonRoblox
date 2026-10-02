--!strict
-- [D62, pasul 3] Darurile raului: program determinist, fereastra de prins, recompensa cu minim.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local DriftMath = require("../src/Shared/Modules/DriftMath")
local RiverConfig = require("../src/Shared/Config/RiverConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

local SEED = 12345

return function()
    test.suite("DriftMath", function()
        test.case(
            "aceeasi samanta si aceeasi fereastra dau acelasi dar, pe server si pe client",
            function()
                for window = 1000, 1040 do
                    local a = DriftMath.giftFor(SEED, window)
                    local b = DriftMath.giftFor(SEED, window)
                    check.equal(a.kind, b.kind)
                    check.equal(a.enterAt, b.enterAt)
                    check.equal(a.speed, b.speed)
                    check.equal(a.id, window)
                    check.not_nil(DriftMath.byId[a.kind])
                end
                -- alta samanta, alt program
                local differs = false
                for window = 1000, 1040 do
                    if
                        DriftMath.giftFor(SEED, window).enterAt
                        ~= DriftMath.giftFor(SEED + 1, window).enterAt
                    then
                        differs = true
                    end
                end
                check.is_true(differs)
            end
        )

        test.case(
            "un dar pe fereastra: intra in fereastra lui si nu sare peste cea de dupa",
            function()
                for window = 2000, 2200 do
                    local g = DriftMath.giftFor(SEED, window)
                    check.is_true(g.enterAt >= window * DriftMath.WINDOW)
                    check.is_true(g.enterAt <= window * DriftMath.WINDOW + DriftMath.START_JITTER)
                    check.is_true(g.speed >= DriftMath.SPEED_MIN and g.speed <= DriftMath.SPEED_MAX)
                    -- iese de pe harta inainte sa intre darul de peste doua ferestre: `activeAt` se uita doar la doua
                    local exitAt = g.enterAt + (DriftMath.EXIT_X - DriftMath.ENTER_X) / g.speed
                    check.is_true(exitAt < (window + 2) * DriftMath.WINDOW)
                end
            end
        )

        test.case(
            "[D73] darul trece pe la toate cartierele si se scoate de pe puntea oricarui cartier deschis",
            function()
                check.is_true(DriftMath.EXIT_X > RiverConfig.WORLD_WIDTH)
                local open = DriftMath.reaches(
                    TycoonConfig.deckSpans(),
                    function(era: number): boolean
                        return era <= 2
                    end
                )
                check.equal(#open, 2)
                -- prima e chiar puntea din The Landing de pana acum
                check.equal(open[1].x0, DriftMath.REACH_X0)
                check.equal(open[1].x1, DriftMath.REACH_X1)
                for window = 3003, 3030 do
                    local g = DriftMath.giftFor(SEED, window)
                    local from, to = DriftMath.reachWindow(g, open[2])
                    local mid = (from + to) / 2
                    check.is_true(DriftMath.xAt(g, mid) ~= nil) -- inca pe harta in dreptul Morii
                    check.is_true(DriftMath.canGrab(g, mid, open))
                    check.is_false(DriftMath.canGrab(g, mid)) -- fara punti, doar The Landing
                    check.is_false(DriftMath.canGrab(g, mid, { open[1] })) -- Moara inca inchisa
                    -- intre punti (in dreptul gardului) nu
                    local _, landingTo = DriftMath.reachWindow(g, open[1])
                    check.is_false(DriftMath.canGrab(g, (landingTo + from) / 2, open))
                end
                -- un cartier inchis nu da nicio punte
                check.equal(
                    #DriftMath.reaches(TycoonConfig.deckSpans(), function(_era: number): boolean
                        return false
                    end),
                    0
                )
            end
        )

        test.case("felurile: butoiul des, lada uneori, busteanul de aur rar", function()
            local counts: { [string]: number } = { barrel = 0, crate = 0, golden = 0 }
            local n = 4000
            for window = 1, n do
                local kind = DriftMath.giftFor(SEED, window).kind
                counts[kind] += 1
            end
            check.is_true(counts.barrel / n > 0.64 and counts.barrel / n < 0.80)
            check.is_true(counts.crate / n > 0.16 and counts.crate / n < 0.28)
            check.is_true(counts.golden / n > 0.03 and counts.golden / n < 0.10)
        end)

        test.case("pluteste in apa, dincolo de plase si sub malul de nord", function()
            check.is_true(DriftMath.Y - 16 >= RiverConfig.SHORE_FAR.baseY)
            for _, laneY in TycoonConfig.LANE_Y do
                check.is_true(DriftMath.Y + 16 < laneY - TycoonConfig.NET_DRAW.h / 2)
            end
            -- se poate scoate cat trece prin dreptul puntii
            check.is_true(DriftMath.REACH_X0 <= TycoonConfig.DECK.x0)
            check.is_true(DriftMath.REACH_X1 >= TycoonConfig.DECK.x1)
        end)

        test.case("pozitia: nil inainte sa intre si dupa ce iese, liniara intre", function()
            local g = DriftMath.giftFor(SEED, 3000)
            check.equal(DriftMath.xAt(g, g.enterAt - 0.1), nil)
            check.equal(DriftMath.xAt(g, g.enterAt), DriftMath.ENTER_X)
            local x = DriftMath.xAt(g, g.enterAt + 10) :: number
            check.is_true(math.abs(x - (DriftMath.ENTER_X + 10 * g.speed)) < 1e-6)
            check.equal(DriftMath.xAt(g, g.enterAt + 1000), nil)
        end)

        test.case(
            "fereastra de prins: doar cat e in dreptul puntii, cu putina ingaduinta",
            function()
                local g = DriftMath.giftFor(SEED, 3001)
                local from, to = DriftMath.reachWindow(g)
                check.is_true(to - from > 15) -- ai timp sa alergi pana la el
                check.is_true(DriftMath.canGrab(g, (from + to) / 2))
                check.is_true(DriftMath.canGrab(g, from - DriftMath.GRACE + 0.01))
                check.is_false(DriftMath.canGrab(g, from - DriftMath.GRACE - 0.5))
                check.is_false(DriftMath.canGrab(g, to + DriftMath.GRACE + 0.5))
                check.is_false(DriftMath.canGrab(g, g.enterAt - 100))
                local xFrom = DriftMath.xAt(g, from) :: number
                local xTo = DriftMath.xAt(g, to) :: number
                check.is_true(math.abs(xFrom - DriftMath.REACH_X0) < 1e-6)
                check.is_true(math.abs(xTo - DriftMath.REACH_X1) < 1e-6)
            end
        )

        test.case(
            "activeAt: darul ferestrei de acum si, cat mai pluteste, al celei dinainte",
            function()
                local window = 3002
                local g = DriftMath.giftFor(SEED, window)
                local active = DriftMath.activeAt(SEED, g.enterAt + 5)
                local found = false
                for _, a in active do
                    if a.id == window then
                        found = true
                    end
                    check.not_nil(DriftMath.xAt(a, g.enterAt + 5))
                end
                check.is_true(found)
                check.is_true(#active <= 2)
            end
        )

        test.case(
            "recompensa: secunde din venitul de acum, intreaga, cu minimul felului",
            function()
                check.equal(DriftMath.reward("barrel", 10), 100)
                check.equal(DriftMath.reward("crate", 10), 250)
                check.equal(DriftMath.reward("golden", 10), 750)
                check.equal(DriftMath.reward("barrel", 111.65), math.floor(111.65 * 10))
                -- in primul minut venitul e aproape zero: minimul inseamna un om angajat (5-10 monede)
                check.equal(DriftMath.reward("barrel", 0), 6)
                check.equal(DriftMath.reward("crate", 0.1), 15)
                check.equal(DriftMath.reward("golden", 0), 40)
                check.equal(DriftMath.reward("barrel", -3), 6)
                check.equal(DriftMath.reward("barrel", 0 / 0), 6)
                check.equal(DriftMath.reward("nu_exista", 10), 0)
            end
        )

        test.case("simulatorul afiseaza estimarea din ACELEASI cifre", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("scripts/economy/sim_tycoon.py")
            check.is_true(string.find(src, `DRIFT_WINDOW = {DriftMath.WINDOW}.0`, 1, true) ~= nil)
            local parts = {}
            for _, k in DriftMath.KINDS do
                table.insert(parts, `({k.weight}, {k.seconds}.0)`)
            end
            local kinds = `DRIFT_KINDS = ({table.concat(parts, ", ")})`
            check.is_true(string.find(src, kinds, 1, true) ~= nil)
        end)

        test.case("cat aduce in medie: ~30% cu toate prinse, ~15% cu jumatate", function()
            local all = DriftMath.expectedBonus(1)
            check.is_true(all > 0.27 and all < 0.34)
            check.is_true(math.abs(DriftMath.expectedBonus(0.5) - all / 2) < 1e-9)
            check.equal(DriftMath.expectedBonus(0), 0)
            check.equal(DriftMath.expectedBonus(7), all)
        end)
    end)
end
