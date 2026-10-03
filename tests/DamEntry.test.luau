--!strict
-- [D70, pasul k6] INTRAREA IN BARAJ, din sat: ce spun zona, fereastra de revenire si masa Dam Plans cand barajul se poate
-- ridica, si ca starea ajunge de la server la client (damAvailable, comingKind, damStart, awayStalled / unhired).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local fs = require("@lune/fs")

local Strings = require("../src/Shared/Config/Strings")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local WorldConfig = require("../src/Shared/Config/WorldConfig")
local WorldMath = require("../src/Shared/Modules/WorldMath")

local widths = require("./fonts/NunitoWidths") :: { [string]: number }

-- cate randuri ocupa un text in Nunito, rupt pe cuvinte la `width` px
local function lines(text: string, size: number, width: number): number
    local count, current = 1, 0
    local space = (widths[" "] or 258) * size / 1000
    for _, word in string.split(text, " ") do
        local w = 0
        for _, code in utf8.codes(word) do
            w += (widths[utf8.char(code)] or 1000) * size / 1000
        end
        if current > 0 and current + space + w > width then
            count += 1
            current = w
        else
            current += (if current > 0 then space else 0) + w
        end
    end
    return count
end

local function has(path: string, needle: string): boolean
    return string.find(fs.readFile(path), needle, 1, true) ~= nil
end

return function()
    test.suite("Intrarea in baraj, din sat [D70, pasul k6]", function()
        test.case("zona barajului din sat: unde se ridica, iar cand se poate, de unde", function()
            local dam: TycoonConfig.Zone? = nil
            for _, zone in TycoonConfig.zonesOf(1) do
                if zone.era == WorldConfig.FIRST_ERA[2] then
                    dam = zone
                end
            end
            assert(dam ~= nil, "satul are zona barajului")
            local live = function(_era: number): boolean
                return true
            end
            check.equal(WorldMath.zoneSign(dam, "locked", 1, live), Strings.zoneAway(dam.name))
            check.equal(
                WorldMath.zoneSign(dam, "locked", 1, live, true),
                "Build the Dam at the Dam Plans"
            )
            check.equal(
                WorldMath.fenceText(dam, 1, live, true),
                WorldMath.zoneSign(dam, "locked", 1, live, true)
            )
            -- adormit: „coming soon”, oricare ar fi `ready`
            local dormant = function(era: number): boolean
                return era < 4
            end
            check.equal(
                WorldMath.zoneSign(dam, "locked", 1, dormant, true),
                dam.soon or Strings.zoneSoon(dam.name)
            )
        end)

        test.case(
            "fereastra de revenire: AWAY 0 la baraj si regula sumei incap pe telefon",
            function()
                local longest = ""
                for role, crew in TycoonConfig.CREWS do
                    if WorldConfig.worldOfEra(TycoonConfig.byId[crew.pad].era) == 2 then
                        local text = Strings.welcomeStalled(crew.name)
                        if #text > #longest then
                            longest = text
                        end
                        check.not_nil(string.find(text, crew.name, 1, true))
                        check.not_nil(role)
                    end
                end
                check.is_true(#longest > 0)
                -- corpul ferestrei: 420 pe calculator, 200 pe cel mai ingust telefon (fitToCanvas: 240 - 2 x 20)
                check.is_true(lines(longest, 15, 420) <= 3)
                check.is_true(lines(longest, 15, 200) <= 6)
                -- regula sumei pe un singur rand, la 420
                -- [verificatorul k6] regula intreaga (monedele cumparate, restul in baraj, AWAY 0): se rupe pe randuri, fereastra
                -- creste dupa ea (WelcomeController)
                local rule = Strings.damStartRule("35T", 6)
                check.is_true(lines(rule, 15, 420) <= 4)
                check.is_true(lines(rule, 15, 200) <= 9)
                check.not_nil(string.find(rule, "coins you bought", 1, true))
                check.not_nil(string.find(rule, "6 new workers", 1, true))
                -- cati oameni noi cere barajul: cablul (4) si unirea (2), fara veterani
                local DamMath = require("../src/Shared/Modules/DamMath")
                check.equal(DamMath.newHires(), 6)
                -- cand lipsesc mai multi, un singur om nu-l porneste
                local many = Strings.welcomeStalled("Cable Collector", 6)
                check.not_nil(string.find(many, "It needs 6 new workers", 1, true))
                check.equal(string.find(many, "keep it running", 1, true), nil)
                check.not_nil(
                    string.find(
                        Strings.welcomeStalled("Pylon Runner", 1),
                        "keep it running",
                        1,
                        true
                    )
                )
                check.equal(
                    Strings.welcomeStalled("Pylon Runner"),
                    Strings.welcomeStalled("Pylon Runner")
                )
                check.not_nil(
                    string.find(Strings.welcomeStalled("Ingot Hauler"), "an Ingot Hauler", 1, true)
                )
            end
        )

        test.case("starea ajunge de la server la client, copiata explicit", function()
            check.is_true(
                has("src/Server/Services/DamService.luau", "DamMath.blocked(data) == nil")
            )
            check.is_true(
                has("src/Server/Net/NetServer.luau", "damAvailable = deps.Dam.Available(player)")
            )
            check.is_true(
                has("src/Client/Bootstrap.client.luau", "damAvailable = raw.damAvailable == true")
            )
            check.is_true(
                has("src/Server/Services/QuestService.luau", "comingKind = comingKind(facts.world)")
            )
            check.is_true(
                has(
                    "src/Client/Bootstrap.client.luau",
                    "comingKind = if typeof(rawQuests.comingKind)"
                )
            )
            check.is_true(
                has("src/Client/Controllers/QuestController.luau", 'paid.comingKind == "build"')
            )
            check.is_true(
                has(
                    "src/Server/Services/StationService.luau",
                    "damStart = if DamMath.blocked(data) == nil"
                )
            )
            check.is_true(
                has("src/Client/Controllers/WelcomeController.luau", "info.awayStalled == true")
            )
            check.is_true(
                has("src/Client/Controllers/WelcomeController.luau", "typeof(info.damStart)")
            )
            -- masa: cu barajul in joc, E il ridica (nu mai tace)
            check.is_true(
                has("src/Client/Controllers/ModernController.luau", "Strings.plansBuild(keyHint)")
            )
        end)
    end)
end
