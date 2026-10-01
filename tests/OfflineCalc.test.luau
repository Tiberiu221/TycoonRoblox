local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local OfflineCalc = require("../src/Shared/Modules/OfflineCalc")
local H = 3600

return function()
    test.suite("OfflineCalc.computeIdle - cat ai lipsit [D71]", function()
        test.case("fara automatizare nu se castiga nimic, dar se stie cat ai lipsit", function()
            -- nu e o pedeapsa: n-avea cine sa care si cine sa vanda [P2]
            local r = OfflineCalc.computeIdle(10000, 1000, 0)
            check.equal(r.coins, 0)
            check.equal(r.paid, 0)
            -- fereastra scrie cat ai lipsit cu adevarat (a venit ceva pe rau), nu "a moment"
            check.equal(r.away, 9000)
        end)

        test.case("pana la 8 ore: viteza intreaga, exact rata x timpul", function()
            local r = OfflineCalc.computeIdle(1000 + 600, 1000, 2.5)
            check.equal(r.paid, 600)
            check.equal(r.coins, 1500)
            check.equal(r.phase, "full")
            check.equal(OfflineCalc.computeIdle(1000 + 8 * H, 1000, 1).phase, "full")
        end)

        test.case("intre 8 si 24 de ore: un sfert din viteza", function()
            local r = OfflineCalc.computeIdle(1000 + 12 * H, 1000, 1)
            check.equal(r.paid, 8 * H + 4 * H * 0.25)
            check.equal(r.away, 12 * H)
            check.equal(r.phase, "slow")
        end)

        test.case("dupa 24 de ore satul se odihneste: nimic in plus, si o spune", function()
            local day = OfflineCalc.computeIdle(1000 + 24 * H, 1000, 1)
            check.equal(day.paid, 8 * H + 16 * H * 0.25) -- 12 h la viteza intreaga
            check.equal(day.phase, "slow")
            local r = OfflineCalc.computeIdle(1000 + 72 * H, 1000, 1)
            check.equal(r.paid, day.paid)
            check.equal(r.away, 72 * H)
            check.equal(r.phase, "rested")
        end)

        test.case("plata nu scade niciodata cand lipsesti mai mult [P2]", function()
            local last = -1
            for h = 0, 40, 0.5 do
                local paid = OfflineCalc.paidSeconds(h * H)
                check.is_true(paid >= last)
                last = paid
            end
        end)

        test.case(
            "nicio absenta nu plateste mai putin decat inainte de D71 (plin pana la 8 h, apoi nimic)",
            function()
                for h = 0, 40, 0.5 do
                    check.is_true(OfflineCalc.paidSeconds(h * H) >= math.min(h, 8) * H)
                end
            end
        )

        test.case("o curba stricata cade pe cea implicita, niciodata pe 'fara plafon'", function()
            local base = OfflineCalc.computeIdle(1 + 72 * H, 1, 2).paid
            for _, curve in
                {
                    { full = 0, stop = 24 * H, slow = 0.25 },
                    { full = -5, stop = 24 * H, slow = 0.25 },
                    { full = 0 / 0, stop = 24 * H, slow = 0.25 },
                    { full = 8 * H, stop = 4 * H, slow = 0.25 },
                    { full = 8 * H, stop = 24 * H, slow = 2 },
                    { full = 8 * H, stop = math.huge, slow = 0.25 },
                } :: { any }
            do
                check.equal(OfflineCalc.computeIdle(1 + 72 * H, 1, 2, curve).paid, base)
            end
        end)

        test.case("un ceas dat inapoi nu produce castig negativ", function()
            local r = OfflineCalc.computeIdle(500, 1000, 3)
            check.equal(r.coins, 0)
            check.equal(r.away, 0)
        end)

        test.case("un profil fara lastSeenAt (prima intrare) nu primeste nimic", function()
            local r = OfflineCalc.computeIdle(99999, 0, 5)
            check.equal(r.coins, 0)
            check.equal(r.away, 0)
        end)

        test.case(
            "dupa luni de absenta: plata e tot o zi, iar textul spune cat ai lipsit cu adevarat [D14, D40]",
            function()
                local r = OfflineCalc.computeIdle(1 + 400 * 24 * H, 1, 1)
                check.equal(r.away, 400 * 24 * H)
                check.equal(r.paid, 12 * H)
                check.equal(r.phase, "rested")
            end
        )
    end)
end
