--!strict
-- [D71] Seria zilnica: o zi pe ziua TA (fusul orar spus de client); o zi lipsa nu o rupe, doua da; cea mai lunga si
-- totalul nu scad niciodata.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StreakMath = require("../src/Shared/Modules/StreakMath")

return function()
    test.suite("StreakMath", function()
        test.case("prima zi numarata vreodata: seria 1, fara vreo veste de spus", function()
            local s, event = StreakMath.touch(nil, 100)
            check.equal(event, "first")
            check.equal(s.run, 1)
            check.equal(s.best, 1)
            check.equal(s.total, 1)
            check.equal(s.day, 100)
            check.is_false(StreakMath.worthTelling(s, event))
        end)

        test.case(
            "aceeasi zi nu numara de doua ori (drumurile cu barca reincarca profilul)",
            function()
                local s = StreakMath.touch(nil, 100)
                local again, event = StreakMath.touch(s, 100)
                check.equal(event, "same")
                check.equal(again.run, 1)
                check.equal(again.total, 1)
                -- nici un ceas dat inapoi
                local back, backEvent = StreakMath.touch(s, 99)
                check.equal(backEvent, "same")
                check.equal(back.run, 1)
            end
        )

        test.case(
            "ziua urmatoare creste seria, si se spune; recordul doar cand trece de cel vechi",
            function()
                local s = StreakMath.touch(nil, 100)
                local next, event, record = StreakMath.touch(s, 101)
                check.equal(event, "next")
                check.equal(next.run, 2)
                check.equal(next.best, 2)
                check.equal(next.total, 2)
                check.is_true(record)
                check.is_true(StreakMath.worthTelling(next, event))
                -- la egalitate cu cea mai lunga serie nu e "your best yet"
                local _, _, tie = StreakMath.touch({ day = 50, run = 8, best = 9, total = 20 }, 51)
                check.is_false(tie)
                local _, _, beat = StreakMath.touch({ day = 50, run = 9, best = 9, total = 20 }, 51)
                check.is_true(beat)
            end
        )

        test.case(
            "ziua e a ta: California, luni 15:00 si miercuri 18:00 au o zi lipsa intre ele",
            function()
                local pdt = -7 * 3600
                -- luni 2026-10-05 15:00 PDT = 22:00 UTC; miercuri 18:00 PDT = joi 2026-10-08 01:00 UTC
                local monday = StreakMath.dayOf(1791237600, pdt)
                local wednesday = StreakMath.dayOf(1791421200, pdt)
                check.equal(wednesday - monday, 2)
                local next, event =
                    StreakMath.touch({ day = monday, run = 6, best = 6, total = 9 }, wednesday)
                check.equal(event, "next")
                check.equal(next.run, 7)
                -- iar dupa-amiaza de luni ramane luni: ziua nu se schimba la 17:00, ca pe ziua UTC
                check.equal(StreakMath.dayOf(1791237600 + 3 * 3600, pdt), monday)
            end
        )

        test.case("doua zile lipsa o incep din nou; cea mai lunga si totalul raman [P2]", function()
            -- cine vine o data la trei zile nu tine seria (nici titlurile ei, ca unul care vine zilnic)
            local s = { day = 100, run = 9, best = 12, total = 30 }
            local again, event = StreakMath.touch(s, 103)
            check.equal(event, "broke")
            check.equal(again.run, 1)
            check.equal(again.best, 12)
            check.equal(again.total, 31)
            check.is_true(StreakMath.worthTelling(again, event))
            -- o serie de o zi care reincepe nu e o veste
            local short, shortEvent =
                StreakMath.touch({ day = 50, run = 1, best = 1, total = 1 }, 60)
            check.is_false(StreakMath.worthTelling(short, shortEvent))
        end)

        test.case("un profil stricat e o serie goala, niciodata NaN sau negativa", function()
            for _, raw in
                { "x", { run = -3 }, { run = 0 / 0, best = math.huge }, { day = "y", total = -1 } } :: { any }
            do
                local c = StreakMath.clean(raw)
                check.equal(c.run, 0)
                check.equal(c.best, 0)
                check.equal(c.total, 0)
                check.equal(c.day, 0)
            end
            -- cea mai lunga serie nu poate fi sub cea de acum
            check.equal(StreakMath.clean({ day = 5, run = 4, best = 2, total = 1 }).best, 4)
        end)

        test.case(
            "fusul orar de la client: validat, rotunjit, schimbat cel mult o data pe zi UTC",
            function()
                check.equal(StreakMath.cleanOffset(-25200), -25200)
                check.equal(StreakMath.cleanOffset(3 * 3600 + 7), 3 * 3600) -- rotunjit la 15 minute
                for _, bad in { 0 / 0, math.huge, -13 * 3600, 15 * 3600, "x" } :: { any } do
                    check.equal(StreakMath.cleanOffset(bad), nil)
                end
                local now = 1791237600
                local s, changed = StreakMath.setOffset(nil, -25200, now)
                check.is_true(changed)
                check.equal(s.offset, -25200)
                -- aceeasi zi UTC: o a doua schimbare nu trece (nimeni nu numara o zi de doua ori mutand ceasul)
                local again, changedAgain = StreakMath.setOffset(s, 9 * 3600, now + 60)
                check.is_false(changedAgain)
                check.equal(again.offset, -25200)
                -- a doua zi, da
                local later, changedLater = StreakMath.setOffset(s, 9 * 3600, now + 86400)
                check.is_true(changedLater)
                check.equal(later.offset, 9 * 3600)
                -- un fus stricat nu schimba nimic
                local _, broken = StreakMath.setOffset(s, 0 / 0, now + 2 * 86400)
                check.is_false(broken)
            end
        )

        test.case(
            "fusul care vine dupa ziua numarata pe UTC nu o numara din nou si nu pierde ziua de maine",
            function()
                local H = 3600
                -- Japonia (+9 h), prima intrare la 2026-10-05 20:00 UTC: incarcarea numara pe UTC, apoi vine fusul
                local now = 1791237600 - 2 * H
                local s, event = StreakMath.touch(nil, StreakMath.dayOf(now, 0))
                check.equal(event, "first")
                s = StreakMath.setOffset(s, 9 * H, now)
                local again, sameEvent = StreakMath.touch(s, StreakMath.dayOf(now + 60, s.offset))
                check.equal(sameEvent, "same") -- fara un „Day 2” fals in prima sesiune
                check.equal(again.run, 1)
                local tomorrow, nextEvent =
                    StreakMath.touch(again, StreakMath.dayOf(now + 86400, s.offset))
                check.equal(nextEvent, "next")
                check.equal(tomorrow.run, 2)
                -- California (-7 h), prima intrare joi 18:00 local = vineri 01:00 UTC
                local ca = 1791421200
                local c = StreakMath.touch(nil, StreakMath.dayOf(ca, 0))
                c = StreakMath.setOffset(c, -7 * H, ca)
                local friday, fridayEvent =
                    StreakMath.touch(c, StreakMath.dayOf(ca + 21 * H, c.offset))
                check.equal(fridayEvent, "next") -- vineri dupa-amiaza se numara
                check.equal(friday.run, 2)
            end
        )

        test.case("fara fus orar, ziua e cea UTC, ca la gherete si like-uri", function()
            check.equal(StreakMath.dayOf(0), 0)
            check.equal(StreakMath.dayOf(86399), 0)
            check.equal(StreakMath.dayOf(86400), 1)
        end)
    end)
end
