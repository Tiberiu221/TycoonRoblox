local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local EraWords = require("../src/Shared/Modules/EraWords")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

return function()
    test.suite("EraWords [2026-09-30, finalul Erei 3]", function()
        local function bought(ids: { string }): (string) -> boolean
            local set: { [string]: boolean } = {}
            for _, id in ids do
                set[id] = true
            end
            return function(id: string): boolean
                return set[id] == true
            end
        end
        local landing = TycoonConfig.CREWS.collector.pad
        local mill = TycoonConfig.CREWS.millCollector.pad
        local works = TycoonConfig.CREWS.worksCollector.pad

        test.case("clopotul erei netras: trimite la el", function()
            check.equal(
                EraWords.maxedCrew("Collectors", landing, bought({})),
                "Collectors are at their best here — ring the Landing Bell"
            )
            check.equal(
                EraWords.maxedCrew(
                    "Works Collectors",
                    works,
                    bought({ "landing_bell", "mill_bell" })
                ),
                "Works Collectors are at their best here — ring the Works Bell"
            )
        end)

        test.case("clopotul tras: frontiera, nu era de alaturi", function()
            check.equal(
                EraWords.maxedCrew("Collectors", landing, bought({ "landing_bell" })),
                "Collectors are at their best here — build up The Mill"
            )
            -- in Era 3, cei din Landing trimit la Wire Works, unde e cresterea, nu la Moara terminata
            local era3 = bought({ "landing_bell", "mill_bell" })
            check.equal(
                EraWords.maxedCrew("Collectors", landing, era3),
                "Collectors are at their best here — build up The Wire Works"
            )
            check.equal(
                EraWords.maxedCrew("Mill Collectors", mill, era3),
                "Mill Collectors are at their best here — build up The Wire Works"
            )
        end)

        test.case("toate clopotele din joc trase: era care vine, din orice cartier", function()
            local all = bought({ "landing_bell", "mill_bell", "works_bell" })
            for _, pad in { landing, mill, works } do
                check.equal(
                    EraWords.maxedCrew("Collectors", pad, all),
                    "Collectors are at their best — more comes with The Dam"
                )
            end
        end)
    end)
end
