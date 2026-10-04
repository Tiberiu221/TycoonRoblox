--!strict
-- [PLAN §16, l1] Profilul dus de la un Play de proba la urmatorul: exportul refuza orice profil pe care JSON l-ar schimba.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ProbeCarry = require("../src/Shared/Modules/ProbeCarry")

return function()
    test.suite("ProbeCarry", function()
        test.case("doua profiluri la fel n-au nicio diferenta, oricat de adanc", function()
            local a = {
                Coins = 35e12,
                World = 2,
                Stations = { nets = { first_net = { level = 25 } } },
                Ids = { "a", "b" },
            }
            local b = {
                Coins = 35e12,
                World = 2,
                Stations = { nets = { first_net = { level = 25 } } },
                Ids = { "a", "b" },
            }
            check.equal(ProbeCarry.firstDiff(a, b), nil)
        end)

        test.case("spune calea primei diferente", function()
            local a = { Stations = { nets = { first_net = { level = 25 } } } }
            local b = { Stations = { nets = { first_net = { level = 24 } } } }
            check.equal(ProbeCarry.firstDiff(a, b), "Stations.nets.first_net.level")
        end)

        test.case("o cheie numerica scrisa ca text nu e aceeasi cheie", function()
            local a = { Memories = { [3] = true } }
            local b = { Memories = { ["3"] = true } }
            check.equal(ProbeCarry.firstDiff(a, b), "Memories.[3]")
        end)

        test.case("o cheie in plus sau in minus se vede", function()
            check.equal(ProbeCarry.firstDiff({ x = 1 }, { x = 1, y = 2 }), "y")
            check.equal(ProbeCarry.firstDiff({ x = 1, y = 2 }, { x = 1 }), "y")
        end)

        test.case("un tabel gol e la fel cu altul gol (JSON nu deosebeste [] de {})", function()
            check.equal(ProbeCarry.firstDiff({ passes = {} }, { passes = {} }), nil)
        end)

        test.case("NaN si o cifra rotunjita nu trec", function()
            local nan = 0 / 0
            check.equal(ProbeCarry.firstDiff({ v = nan }, { v = nan }), "v")
            check.equal(ProbeCarry.firstDiff({ v = 0.1 + 0.2 }, { v = 0.3 }), "v")
        end)

        test.case("un tip schimbat se vede la radacina si mai jos", function()
            check.equal(ProbeCarry.firstDiff({}, "x"), "(root)")
            check.equal(ProbeCarry.firstDiff({ v = 1 }, { v = "1" }), "v")
        end)
    end)
end
