--!strict
-- [D60] Titlurile: ce ai castigat, ce se cumpara, si ce se intampla cand pierzi lucrul din spatele titlului.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TitleMath = require("../src/Shared/Modules/TitleMath")

local function facts(over: { [string]: any }?): TitleMath.Facts
    local f: any = {
        era = 1,
        species = 0,
        speciesTotal = 12,
        record = nil,
        decor = {},
        champion = false,
        bought = {},
    }
    for k, v in (over or {}) :: any do
        f[k] = v
    end
    return f
end

return function()
    test.suite("TitleMath", function()
        test.case("toata lumea are titlul Erei la care a ajuns", function()
            check.equal(TitleMath.label("era", facts()), "Of the Landing")
            check.equal(TitleMath.label("era", facts({ era = 2 })), "Of the Mill")
            -- o era necunoscuta nu lasa omul fara titlu: se opreste la ultima scrisa
            check.equal(TitleMath.label("era", facts({ era = 9 })), "Of the Dam")
            -- [D67, audit] din TycoonConfig.ZONES, nu dintr-o lista ramasa la planul vechi ("Of the Yard")
            check.equal(TitleMath.label("era", facts({ era = 3 })), "Of the Wire Works")
            check.equal(TitleMath.eraTitle(1), "Of the Landing")
        end)

        test.case("[D61] iazul si gheretele dau titlurile lor, doar dupa prag", function()
            check.equal(TitleMath.label("pond", facts()), nil)
            check.equal(TitleMath.label("pond", facts({ pondWins = 2 })), nil)
            check.equal(TitleMath.label("pond", facts({ pondWins = 3 })), "Pond Champion")
            check.equal(TitleMath.label("sharpshooter", facts({ perfectGames = 4 })), nil)
            check.equal(
                TitleMath.label("sharpshooter", facts({ perfectGames = 5 })),
                "Sharpshooter"
            )
            local ids = {}
            for _, entry in TitleMath.earned(facts({ pondWins = 9, perfectGames = 9 })) do
                ids[entry.id] = true
            end
            check.is_true(ids.pond == true and ids.sharpshooter == true)
            check.is_true(TitleMath.canWear("pond", facts({ pondWins = 3 })))
            check.is_false(TitleMath.canWear("sharpshooter", facts()))
        end)

        test.case("[D61, partea 2] Supporter vine cu pass-ul si pleaca fara el", function()
            check.equal(TitleMath.label("supporter", facts()), nil)
            check.equal(TitleMath.label("supporter", facts({ supporter = true })), "Supporter")
            check.is_true(TitleMath.canWear("supporter", facts({ supporter = true })))
            check.is_false(TitleMath.canWear("supporter", facts({ supporter = false })))
            local ids = {}
            for _, entry in TitleMath.earned(facts({ supporter = true })) do
                ids[entry.id] = true
            end
            check.is_true(ids.supporter == true)
            -- nu se cumpara cu perle: e al pass-ului
            check.equal(TitleMath.priceOf("supporter"), nil)
        end)

        test.case("jurnalul complet da River Legend, jurnalul pe jumatate nu da nimic", function()
            check.equal(TitleMath.label("legend", facts({ species = 12 })), "River Legend")
            check.equal(TitleMath.label("legend", facts({ species = 11 })), nil)
        end)

        test.case("recordul se scrie cu specia si marimea lui, nu cu un text fix", function()
            local f = facts({ record = { fish = "Sturgeon", cm = 187.4 } })
            check.equal(TitleMath.label("record", f), "Sturgeon 187 cm")
            check.equal(TitleMath.label("record", facts()), nil)
        end)

        test.case("decorul cumparat aduce titlul lui, si il ia inapoi cand nu-l mai ai", function()
            local f = facts({ decor = { fountain = true } })
            check.equal(TitleMath.label("decor_fountain", f), "Fountain Patron")
            check.is_true(TitleMath.canWear("decor_fountain", f))
            check.is_false(TitleMath.canWear("decor_fountain", facts()))
        end)

        test.case("titlurile de vanzare exista doar dupa ce le-ai cumparat", function()
            check.equal(TitleMath.label("river_baron", facts()), nil)
            check.equal(
                TitleMath.label("river_baron", facts({ bought = { river_baron = true } })),
                "River Baron"
            )
            check.equal(TitleMath.priceOf("old_salt"), 600)
            check.equal(TitleMath.priceOf("lord_of_the_river"), 1600)
            check.equal(TitleMath.priceOf("nimic"), nil)
        end)

        test.case(
            "preturile de vanzare sunt peste tot catalogul de decor (1.460 de perle)",
            function()
                local cheapest = math.huge
                for _, entry in TitleMath.FOR_SALE do
                    cheapest = math.min(cheapest, entry.price)
                end
                check.is_true(cheapest >= 600)
                check.equal(#TitleMath.FOR_SALE, 3)
            end
        )

        test.case("lista celor castigate incepe cu Era si le are pe toate", function()
            local f = facts({
                era = 2,
                species = 12,
                record = { fish = "Pike", cm = 96 },
                decor = { statue = true },
                champion = true,
                bought = { old_salt = true },
            })
            local earned = TitleMath.earned(f)
            check.equal(earned[1].label, "Of the Mill")
            local labels = {}
            for _, entry in earned do
                table.insert(labels, entry.label)
            end
            check.equal(
                table.concat(labels, ", "),
                "Of the Mill, River Legend, Pike 96 cm, Champion of the Week, Statue Patron, Old Salt"
            )
        end)

        -- [D71] seria zilnica: din cea mai lunga serie, deci un titlu castigat nu cade cand seria reincepe
        test.case("titlurile seriei zilnice vin din cea mai lunga serie", function()
            local function facts(best: number?): any
                return {
                    era = 1,
                    species = 0,
                    speciesTotal = 12,
                    decor = {},
                    champion = false,
                    bought = {},
                    streakBest = best,
                }
            end
            check.equal(TitleMath.label("regular", facts(nil)), nil)
            check.equal(TitleMath.label("regular", facts(6)), nil)
            check.equal(TitleMath.label("regular", facts(TitleMath.STREAK_REGULAR)), "Regular")
            check.equal(TitleMath.label("old_friend", facts(29)), nil)
            check.equal(
                TitleMath.label("old_friend", facts(TitleMath.STREAK_OLD_FRIEND)),
                "Old Friend"
            )
            local labels = {}
            for _, entry in TitleMath.earned(facts(30)) do
                table.insert(labels, entry.label)
            end
            check.equal(table.concat(labels, ", "), "Of the Landing, Regular, Old Friend")
            -- se spune cand se castiga [D43]: o singura data, la trecerea pragului
            check.equal(TitleMath.streakTitleReached(6, 7), "Regular")
            check.equal(TitleMath.streakTitleReached(7, 8), nil)
            check.equal(TitleMath.streakTitleReached(29, 30), "Old Friend")
            check.equal(TitleMath.streakTitleReached(3, 2), nil)
        end)
    end)
end
