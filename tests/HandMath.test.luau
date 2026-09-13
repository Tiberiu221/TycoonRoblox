local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local HandMath = require("../src/Shared/Modules/HandMath")

local CFG = { speed = 100, pauseNet = 1, pauseDock = 2 }
local DOCK = { x = 0, y = 0 }
-- doua plase la 300 si 700 pe axa x: drum 300 + 400 + 700 = 1400 px = 14 s, plus 1 + 1 + 2 de pauze
local STOPS = {
    { x = 300, y = 0, padId = "a" },
    { x = 700, y = 0, padId = "b" },
}

local function near(a: number, b: number): boolean
    return math.abs(a - b) < 1e-9
end

return function()
    test.suite("HandMath.runnerNets", function()
        test.case("fiecare alergator ia urmatoarele 3 plase detinute, in ordine", function()
            local owned = { "n1", "n2", "n3", "n4", "n5" }
            local r1 = HandMath.runnerNets(owned, 1, 3)
            local r2 = HandMath.runnerNets(owned, 2, 3)
            check.equal(#r1, 3)
            check.equal(r1[1], "n1")
            check.equal(r1[3], "n3")
            check.equal(#r2, 2)
            check.equal(r2[1], "n4")
            check.equal(#HandMath.runnerNets(owned, 3, 3), 0)
        end)
    end)

    test.suite("HandMath.cycle / sampleAt", function()
        test.case("durata = drumul / viteza + pauzele", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            check.is_true(near(c.duration, 14 + 1 + 1 + 2))
            check.equal(#c.legs, 6) -- walk, collect, walk, collect, walk, sell
        end)

        test.case("pe drumuri: ocolul intra in durata, dar pe drum nu se strange nimic", function()
            -- [D50] capat (0,0) -> via (0,100), (100,100) -> oprire (100,0) -> via (200,0) -> capat
            local stops = {
                {
                    x = 100,
                    y = 0,
                    padId = "a",
                    via = { { x = 0, y = 100 }, { x = 100, y = 100 } },
                },
            }
            local c = HandMath.cycle(stops, DOCK, CFG, { { x = 200, y = 0 } })
            local walk = 100 + 100 + 100 + 100 + 200
            check.is_true(near(c.duration, walk / CFG.speed + CFG.pauseNet + CFG.pauseDock))
            local events = HandMath.eventsBetween(c, 0, -1, c.duration)
            check.equal(#events, 2)
            check.equal(events[1].kind, "collect")
            check.equal(events[2].kind, "sell")
            -- pe drumul de dus nu duce nimic, pe cel de intors duce
            local x1, y1, s1, _, carrying1 = HandMath.sampleAt(c, 1.5)
            check.is_true(near(x1, 50) and near(y1, 100))
            check.equal(s1, "walk")
            check.is_false(carrying1)
            local x2, _, s2, _, carrying2 = HandMath.sampleAt(c, 3 + CFG.pauseNet + 0.5)
            check.is_true(near(x2, 150))
            check.equal(s2, "walk")
            check.is_true(carrying2)
        end)

        test.case("fara plase: ciclu gol, alergatorul sta", function()
            local c = HandMath.cycle({}, DOCK, CFG)
            check.equal(c.duration, 0)
            local _, _, state = HandMath.sampleAt(c, 5)
            check.equal(state, "idle")
        end)

        test.case("pozitia urmeaza drumul si pauzele", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            local x0, _, s0 = HandMath.sampleAt(c, 0)
            check.is_true(near(x0, 0))
            check.equal(s0, "walk")
            local x1, _, s1, f1 = HandMath.sampleAt(c, 1.5)
            check.is_true(near(x1, 150))
            check.equal(s1, "walk")
            check.equal(f1, "right")
            local x2, _, s2, _, carrying2 = HandMath.sampleAt(c, 3.5)
            check.is_true(near(x2, 300))
            check.equal(s2, "collect")
            check.is_true(carrying2)
            local _, _, s3, f3 = HandMath.sampleAt(c, 10) -- inapoi spre debarcader
            check.equal(s3, "walk")
            check.equal(f3, "left")
            local x4, _, s4, _, carrying4 = HandMath.sampleAt(c, 17)
            check.is_true(near(x4, 0))
            check.equal(s4, "sell")
            check.is_false(carrying4)
        end)

        test.case("ciclurile se repeta: t si t + durata dau acelasi punct", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            local xa, ya = HandMath.sampleAt(c, 6.25)
            local xb, yb = HandMath.sampleAt(c, 6.25 + 3 * c.duration)
            check.is_true(near(xa, xb) and near(ya, yb))
        end)
    end)

    test.suite("HandMath.eventsBetween", function()
        test.case("un ciclu: strange a, strange b, vinde -- la sosire", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            local ev = HandMath.eventsBetween(c, 1000, 1000, 1000 + c.duration)
            check.equal(#ev, 3)
            check.equal(ev[1].kind, "collect")
            check.equal(ev[1].padId, "a")
            check.is_true(near(ev[1].at, 1003))
            check.equal(ev[2].padId, "b")
            check.is_true(near(ev[2].at, 1000 + 3 + 1 + 4))
            check.equal(ev[3].kind, "sell")
            check.is_true(near(ev[3].at, 1000 + 16))
        end)

        test.case("intervale lipite nu pierd si nu dubleaza evenimente", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            local total = 0
            local t = 1000
            for _ = 1, 40 do
                total += #HandMath.eventsBetween(c, 1000, t, t + 0.9)
                t += 0.9
            end
            -- 36 s = doua cicluri de 18 s: 2 x 3 evenimente
            check.equal(total, 6)
        end)

        test.case("dupa o absenta lunga: cel mult un ciclu de evenimente", function()
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            local ev = HandMath.eventsBetween(c, 1000, 1000, 1000 + 10 * 3600)
            check.is_true(#ev <= 3)
            check.is_true(#ev >= 2)
        end)

        test.case("fara plase sau interval gol: niciun eveniment", function()
            check.equal(#HandMath.eventsBetween(HandMath.cycle({}, DOCK, CFG), 0, 0, 100), 0)
            local c = HandMath.cycle(STOPS, DOCK, CFG)
            check.equal(#HandMath.eventsBetween(c, 0, 50, 50), 0)
        end)
    end)
end
