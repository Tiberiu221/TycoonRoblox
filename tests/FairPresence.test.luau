--!strict
-- [D60] Prezenta din balci: serverul primeste doar pozitii adevarate, pe unde se poate merge, fara salturi.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FairPresence = require("../src/Shared/Modules/FairPresence")
local FairLayout = require("../src/Shared/Modules/FairLayout")

return function()
    test.suite("FairPresence", function()
        test.case("doar cele patru directii ale omului desenat", function()
            for _, facing in { "up", "down", "left", "right" } do
                check.is_true(FairPresence.isValidFacing(facing))
            end
            check.is_false(FairPresence.isValidFacing("north"))
            check.is_false(FairPresence.isValidFacing(1))
            check.is_false(FairPresence.isValidFacing(nil))
        end)

        test.case("numerele stricate si locurile fara drum se resping", function()
            local s = FairLayout.SPAWN
            check.is_true(FairPresence.accept(nil, s.x, s.y, 0))
            check.is_false(FairPresence.accept(nil, 0 / 0, s.y, 0))
            check.is_false(FairPresence.accept(nil, s.x, math.huge, 0))
            check.is_false(FairPresence.accept(nil, "810", s.y, 0))
            check.is_false(FairPresence.accept(nil, s.x, FairLayout.WATER_Y + 40, 0)) -- in rau
            check.is_false(FairPresence.accept(nil, FairLayout.POND.x, FairLayout.POND.y, 0)) -- in iaz
            check.is_false(FairPresence.accept(nil, -5, s.y, 0))
        end)

        test.case(
            "un pas cat alergi trece, un salt nu; dupa o pauza lunga, pasul creste",
            function()
                local s = FairLayout.SPAWN
                local prev = { x = s.x, y = s.y, t = 10 }
                local run = FairPresence.SPEED * 0.1
                check.is_true(FairPresence.accept(prev, s.x, s.y - run, 10.1))
                check.is_false(FairPresence.accept(prev, s.x, s.y - 600, 10.1))
                check.is_true(FairPresence.accept(prev, s.x, s.y - 600, 11.5))
                -- doua pachete lipite (acelasi t) au totusi marja unui pachet intreg
                check.equal(FairPresence.maxStep(0), FairPresence.maxStep(1 / FairPresence.RATE))
                check.is_true(FairPresence.accept(prev, s.x + run, s.y, 10))
            end
        )

        test.case("ceilalti se misca lin intre pachete, fara sa treaca de capete", function()
            local x, y = FairPresence.lerp(0, 0, 100, 50, 0.5)
            check.equal(x, 50)
            check.equal(y, 25)
            x, y = FairPresence.lerp(0, 0, 100, 50, 3)
            check.equal(x, 100)
            check.equal(y, 50)
            x, y = FairPresence.lerp(10, 20, 100, 50, -1)
            check.equal(x, 10)
            check.equal(y, 20)
        end)
    end)
end
