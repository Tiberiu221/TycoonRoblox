--!strict
-- [D63] Tinta fara sfarsit de pe linia NEXT: pragul urmator pe veriga care tine venitul in loc.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local AmbitionMath = require("../src/Shared/Modules/AmbitionMath")
local StationConfig = require("../src/Shared/Config/StationConfig")
local Strings = require("../src/Shared/Config/Strings")

local M = StationConfig.MILESTONES

local function net(
    id: string,
    level: number,
    bottleneck: boolean?,
    gain: number?
): AmbitionMath.StationRow
    local nextAt: number? = nil
    for _, t in M do
        if level < t then
            nextAt = t
            break
        end
    end
    return {
        kind = "net",
        id = id,
        name = id,
        level = level,
        nextMilestone = nextAt,
        bottleneck = bottleneck,
        gain = gain,
    }
end

local function crew(
    role: string,
    tier: number,
    count: number,
    bottleneck: boolean?,
    tierBlock: string?,
    hireBlock: string?
): AmbitionMath.CrewRow
    return {
        role = role,
        name = role,
        count = count,
        tier = tier,
        maxTier = 5,
        maxPeople = 2,
        tierBlock = tierBlock,
        hireBlock = hireBlock,
        bottleneck = bottleneck,
    }
end

return function()
    test.suite("AmbitionMath", function()
        test.case(
            "veriga slaba e o plasa: tinta e pragul ei urmator, masurat de la ultimul prag",
            function()
                local a = AmbitionMath.pick(
                    { net("first_net", 3), net("second_net", 12, true, 0.4) },
                    {},
                    M
                )
                local got = a :: AmbitionMath.Ambition
                check.equal(got.what, "milestone")
                check.equal(got.id, "second_net")
                check.equal(got.target, 25)
                -- de la pragul 10 la 25 sunt 15 niveluri, iar la nivelul 12 ai facut 2
                check.equal(got.progress, 2)
                check.equal(got.goal, 15)
            end
        )

        test.case(
            "[D65] mai multe linii, mai multe verigi slabe: cea al carei nivel aduce cel mai mult",
            function()
                -- gaterul tine lemnul (+0.3/s), turnatoria tine piesele (+12/s): tinta e turnatoria, desi vine a doua
                local saw = net("saw_row", 4, true, 0.3)
                saw.kind, saw.id = "saw", nil
                local foundry = net("foundry_row", 6, true, 12)
                foundry.kind, foundry.id = "foundry", nil
                local got = AmbitionMath.pick({ saw, foundry }, {}, M) :: AmbitionMath.Ambition
                check.equal(got.kind, "foundry")
                check.equal(got.target, 10)
                -- la castig egal ramane prima (ordinea randurilor), ca inainte de D65
                foundry.gain = 0.3
                local tie = AmbitionMath.pick({ saw, foundry }, {}, M) :: AmbitionMath.Ambition
                check.equal(tie.kind, "saw")
            end
        )

        test.case(
            "o cladire marcata slaba, dar fara castig, nu e o tinta adevarata [D40]",
            function()
                -- `gain` 0 = nivelul nu aduce nimic acum (alta veriga tine venitul): cade pe cel mai apropiat prag
                local a = AmbitionMath.pick(
                    { net("first_net", 8), net("second_net", 12, true, 0) },
                    {},
                    M
                )
                local got = a :: AmbitionMath.Ambition
                check.equal(got.id, "first_net") -- 2 niveluri pana la 10, fata de 13 pana la 25
                check.equal(got.target, 10)
            end
        )

        test.case("veriga slaba e o meserie: nivelul ei urmator, apoi al doilea om", function()
            local rows = { net("first_net", 30) }
            local up =
                AmbitionMath.pick(rows, { crew("porter", 2, 1, true) }, M) :: AmbitionMath.Ambition
            check.equal(up.what, "crewLevel")
            check.equal(up.kind, "porter")
            check.equal(up.target, 3)
            check.equal(up.goal, 5)
            local second =
                AmbitionMath.pick(rows, { crew("porter", 5, 1, true, "max_tier") }, M) :: AmbitionMath.Ambition
            check.equal(second.what, "secondHire")
            check.equal(second.target, 2)
            -- la maxim pe amandoua: nu mai e nimic de cumparat acolo, deci cel mai apropiat prag
            local maxed = AmbitionMath.pick(
                rows,
                { crew("porter", 5, 2, true, "max_tier", "max_people") },
                M
            ) :: AmbitionMath.Ambition
            check.equal(maxed.what, "milestone")
            check.equal(maxed.target, 50)
            -- o meserie fara niciun om angajat nu e o tinta de nivel (intai se angajeaza, de la platforma ei)
            local nobody =
                AmbitionMath.pick(rows, { crew("porter", 1, 0, true) }, M) :: AmbitionMath.Ambition
            check.equal(nobody.what, "milestone")
        end)

        test.case(
            "exista mereu o tinta cat mai e vreun prag; dincolo de ultimul, niciuna",
            function()
                local last = M[#M]
                check.equal(AmbitionMath.pick({ net("first_net", last) }, {}, M), nil)
                check.not_nil(AmbitionMath.pick({ net("first_net", last - 1) }, {}, M))
                check.equal(AmbitionMath.pick({}, {}, M), nil)
            end
        )

        test.case("textul de pe linia NEXT, pe fiecare fel de tinta", function()
            check.equal(
                Strings.ambitionText("milestone", "Second Net", 25),
                "Second Net to level 25"
            )
            check.equal(Strings.ambitionText("crewLevel", "Porter", 3), "Porter to level 3")
            check.equal(Strings.ambitionText("secondHire", "Porter", 2), "Hire a second Porter")
        end)
        -- [verificatorul k5] pasul unui quest de venit cere castig: fara veriga care tine venitul, nimic (nu pragul de oriunde)
        test.case("gainOnly: fara pasul 3 (cel mai apropiat prag, oriunde)", function()
            local row = {
                kind = "saw",
                name = "Sawmill",
                level = 9,
                nextMilestone = 10,
                bottleneck = false,
                gain = 0,
            }
            check.not_nil(AmbitionMath.pick({ row }, {}, M))
            check.equal(AmbitionMath.pick({ row }, {}, M, true), nil)
            row.bottleneck = true
            row.gain = 5
            check.not_nil(AmbitionMath.pick({ row }, {}, M, true))
        end)

        -- [l1] la baraj: veriga slaba e un om la maxim, iar Switch House (vanzator, fara linie) nu e marcat, desi un nivel
        -- acolo chiar urca venitul. Pasul quest-ului de venit il numeste; un rand fara castig nu.
        test.case("gainOnly: veriga slaba la maxim, un nivel care aduce totusi ceva", function()
            local town = {
                kind = "town",
                name = "Switch House",
                level = 1,
                nextMilestone = 10,
                bottleneck = false,
                gain = 1.8e12,
            }
            local kiln = {
                kind = "kiln",
                name = "Kiln",
                level = 10,
                nextMilestone = 25,
                bottleneck = false,
                gain = 0,
            }
            local maxed = crew("crystalCollector", 5, 2, true)
            local a = AmbitionMath.pick({ kiln, town }, { maxed }, M, true)
            check.not_nil(a)
            check.equal((a :: AmbitionMath.Ambition).kind, "town")
            check.equal((a :: AmbitionMath.Ambition).target, 10)
            -- niciun castig nicaieri: tot nimic
            town.gain = 0
            check.equal(AmbitionMath.pick({ kiln, town }, { maxed }, M, true), nil)
        end)
    end)
end
