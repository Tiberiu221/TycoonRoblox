-- Clientii tavernei [D50]: cati vin = cat vinzi chiar acum.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TavernCrowd = require("../src/Shared/Modules/TavernCrowd")

return function()
    test.suite("TavernCrowd", function()
        test.case("fara vanzari: un singur client, care asteapta", function()
            local w = TavernCrowd.new()
            check.equal(TavernCrowd.count(w, 100), 1)
            check.equal(TavernCrowd.rate(w, 100), 0)
        end)

        test.case("vanzarea constanta da un client in plus pe bucata pe secunda", function()
            local w = TavernCrowd.new()
            -- 3 bucati pe secunda, un lot pe secunda, 30 de secunde
            for t = 1, 30 do
                TavernCrowd.add(w, t, 3)
            end
            check.is_true(math.abs(TavernCrowd.rate(w, 30) - 3) < 1e-9)
            check.equal(TavernCrowd.count(w, 30), 4)
        end)

        test.case("plafonat la MAX, oricat de repede ai vinde", function()
            local w = TavernCrowd.new()
            for t = 1, 30 do
                TavernCrowd.add(w, t, 500)
            end
            check.equal(TavernCrowd.count(w, 30), TavernCrowd.MAX)
        end)

        test.case("cand se opreste vanzarea, taverna se goleste in WINDOW secunde", function()
            local w = TavernCrowd.new()
            for t = 1, 30 do
                TavernCrowd.add(w, t, 5)
            end
            check.equal(TavernCrowd.count(w, 30), 6)
            check.is_true(TavernCrowd.count(w, 40) < 6)
            check.equal(TavernCrowd.count(w, 30 + TavernCrowd.WINDOW), 1)
        end)

        test.case("bucati stricate de pe retea nu inventeaza clienti", function()
            local w = TavernCrowd.new()
            TavernCrowd.add(w, 1, 0 / 0)
            TavernCrowd.add(w, 1, math.huge)
            TavernCrowd.add(w, 1, -4)
            TavernCrowd.add(w, 1, 0)
            check.equal(#w.sales, 0)
            check.equal(TavernCrowd.count(w, 2), 1)
        end)
    end)
end
