--!strict
-- [D61, partea 2] Like-ul pe zi si satele scoase in fata portii.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local VisitMath = require("../src/Shared/Modules/VisitMath")

return function()
    test.suite("VisitMath", function()
        test.case("un like pe zi pentru fiecare sat; a doua zi se poate din nou", function()
            local day = VisitMath.dayOf(1_790_000_000)
            local liked: any = { day = 0, ids = {} }
            check.equal(VisitMath.refusal(liked, day, 1, 2), nil)
            liked = VisitMath.withLike(liked, day, 2)
            check.equal(VisitMath.refusal(liked, day, 1, 2), "already")
            -- alt sat, aceeasi zi: se poate
            check.equal(VisitMath.refusal(liked, day, 1, 3), nil)
            liked = VisitMath.withLike(liked, day, 3)
            check.is_true(VisitMath.likedToday(liked, day, 2))
            check.is_true(VisitMath.likedToday(liked, day, 3))
            -- a doua zi lista e goala
            check.equal(VisitMath.refusal(liked, day + 1, 1, 2), nil)
            local tomorrow = VisitMath.withLike(liked, day + 1, 2)
            check.equal(tomorrow.day, day + 1)
            check.is_false(VisitMath.likedToday(tomorrow, day + 1, 3))
        end)

        test.case("satului tau nu-i poti da like", function()
            check.equal(VisitMath.refusal({ day = 5, ids = {} }, 5, 9, 9), "self")
        end)

        test.case("withLike nu schimba tabelul primit; un camp stricat e o lista goala", function()
            local liked = { day = 5, ids = { ["2"] = true } }
            local out = VisitMath.withLike(liked, 5, 3)
            check.equal(liked.ids["3"], nil)
            check.is_true(out.ids["2"])
            check.is_true(out.ids["3"])
            check.equal(VisitMath.refusal(nil, 5, 1, 2), nil)
            check.equal(VisitMath.refusal({ day = 5, ids = "x" } :: any, 5, 1, 2), nil)
            check.equal(VisitMath.refusal("x" :: any, 5, 1, 2), nil)
        end)

        test.case("ziua se schimba la miezul noptii UTC", function()
            check.equal(VisitMath.dayOf(86399), 0)
            check.equal(VisitMath.dayOf(86400), 1)
        end)

        test.case("machetele: primele trei dupa decoruri, apoi like-uri, apoi userId", function()
            local hosts = {
                { userId = 5, name = "E", decor = 2, likes = 0 },
                { userId = 1, name = "A", decor = 7, likes = 1 },
                { userId = 2, name = "B", decor = 7, likes = 9 },
                { userId = 3, name = "C", decor = 0, likes = 50 },
                { userId = 4, name = "D", decor = 2, likes = 0 },
                { userId = 6, name = "F", decor = 1, likes = 0 },
            }
            local top = VisitMath.top(hosts)
            check.equal(#top, 3)
            check.equal(top[1].userId, 2)
            check.equal(top[2].userId, 1)
            check.equal(top[3].userId, 4)
            -- un sat fara decor nu are ce arata pe macheta
            check.equal(#VisitMath.top({ { userId = 3, name = "C", decor = 0, likes = 50 } }), 0)
            check.equal(#VisitMath.top(hosts, 10), 5)
        end)
    end)
end
