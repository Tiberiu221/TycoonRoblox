-- [D65] CUVINTELE LANTULUI AU DEVENIT TABEL (Strings.LINK_WORDS, NET_WORDS, BUILDING_WORDS). Textele Erei 1 sunt cele
-- jucate si reglate cu owner-ul [D52, D56, D63]: testul le tine litera cu litera. Pentru Era 2 verifica doar ca fiecare
-- veriga, plasa si cladire din tabelul liniilor are cuvintele ei -- altfel meniul ar scrie despre taverna la Piata.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StationConfig = require("../src/Shared/Config/StationConfig")
local Strings = require("../src/Shared/Config/Strings")

return function()
    test.suite("Cuvintele lantului - Era 1 neschimbata", function()
        test.case("cine te tine pe loc", function()
            local expect = {
                { "nets", "wood", "No gain yet — your nets are slower" },
                { "nets", "iron", "No gain yet — the scrap net is slower" },
                { "collect", "wood", "No gain yet — collecting is slower" },
                { "port", "wood", "No gain yet — carrying logs is slower" },
                { "saw", "wood", "No gain yet — the Sawmill is slower" },
                { "haul", "wood", "No gain yet — hauling planks is slower" },
                { "scrapCollect", "iron", "No gain yet — collecting scrap is slower" },
                { "scrapPort", "iron", "No gain yet — carrying scrap is slower" },
                { "forge", "iron", "No gain yet — the Forge is slower" },
                { "ironHaul", "iron", "No gain yet — hauling iron is slower" },
                { "dock", nil, "No gain yet — the Tavern is slower" },
            }
            for _, e in expect do
                check.equal(Strings.menuHeldBack(e[1], false, e[2]), e[3])
            end
            check.equal(
                Strings.menuHeldBack("saw", true, "wood"),
                "No gain yet — the Sawmill is just as slow"
            )
            check.equal(
                Strings.menuHeldBack("nets", true, "wood"),
                "No gain yet — your nets are just as slow"
            )
        end)

        test.case("cartonasul fara veriga a lui si linia inchisa", function()
            check.equal(Strings.stationNoEffect("nets"), "No gain yet — nets are slowest")
            check.equal(Strings.stationNoEffect("port"), "No gain yet — carrying logs is slowest")
            check.equal(Strings.stationNoEffect("forge"), "No gain yet — the Forge is slowest")
            check.equal(Strings.stationNoEffect("dock"), "No gain yet — the Tavern is slowest")
            check.equal(Strings.lineNotOpen("iron"), "No gain yet — cast the Fifth Net first")
        end)

        test.case("butonul Go to", function()
            local expect = {
                nets = "Go to Nets",
                collect = "Go to Collector",
                port = "Go to Porter",
                saw = "Go to Sawmill",
                haul = "Go to Hauler",
                scrapCollect = "Go to Scrap Collector",
                scrapPort = "Go to Scrap Porter",
                forge = "Go to Forge",
                ironHaul = "Go to Iron Hauler",
                dock = "Go to Tavern",
            }
            for link, text in expect do
                check.equal(Strings.menuGoTo(link), text)
            end
        end)

        test.case("ce face cladirea, unitatea si pragurile", function()
            check.equal(Strings.menuDoes("net", true), "Catches")
            check.equal(Strings.menuDoes("saw", true), "Cuts")
            check.equal(Strings.menuDoes("saw", false), "Cuts only while you stand here")
            check.equal(Strings.menuDoes("forge", true), "Smelts scrap into iron")
            check.equal(Strings.menuDoes("forge", false), "Smelts only while you stand here")
            check.equal(Strings.menuDoes("dock", true), "Sells")
            check.equal(Strings.menuDoes("dock", false), "Sells at 35% until you hire an Innkeeper")

            check.equal(Strings.menuUnit("wood", true), "logs a minute")
            check.equal(Strings.menuUnit("wood", false), "planks a minute")
            check.equal(Strings.menuUnit("iron", true), "scrap a minute")
            check.equal(Strings.menuUnit("iron", false), "iron a minute")

            check.equal(Strings.milestoneNow("net", 2), "Catches twice as much now")
            check.equal(Strings.milestoneNow("saw", 2), "Cuts twice as fast now")
            check.equal(Strings.milestoneNow("forge", 2), "Smelts twice as fast now")
            check.equal(Strings.milestoneNow("dock", 2), "Sells twice as fast now")
            check.equal(Strings.menuMilestone("net", 10, 2), "Level 10: catches twice as much")
            check.equal(Strings.menuMilestone("saw", 25, 2), "Level 25: cuts twice as fast")
            check.equal(Strings.menuMilestone("forge", 10, 3), "Level 10: smelts 3x as fast")
            check.equal(Strings.menuMilestone("dock", 50, 2), "Level 50: sells twice as fast")
            check.equal(
                Strings.menuMilestoneDone("saw", 10, 2),
                "Level 10 reached! Cuts twice as fast now"
            )
        end)

        test.case("sfatul din panoul Upgrades", function()
            check.equal(
                Strings.stationsAdvice("nets"),
                "Right now that is the nets — upgrade one to earn more."
            )
            check.equal(
                Strings.stationsAdvice("collect"),
                "Right now that is collecting — hire or upgrade Collectors."
            )
            check.equal(
                Strings.stationsAdvice("scrapCollect"),
                "Right now that is scrap pickup — hire or upgrade Scrap Collectors."
            )
            check.equal(
                Strings.stationsAdvice("forge"),
                "Right now that is the Forge — upgrade it or its Smelters."
            )
            check.equal(
                Strings.stationsAdvice("dock"),
                "Right now that is the Tavern — upgrade it to earn more."
            )
        end)

        test.case("echipajul la maxim trimite la clopotul erei lui", function()
            check.equal(
                Strings.crewMaxed("Porters", "Landing Bell"),
                "Porters are at their best here — ring the Landing Bell"
            )
        end)
    end)

    test.suite("Cuvintele lantului - fiecare veriga din tabel le are [D65]", function()
        test.case("verigile, plasele si cladirile tuturor liniilor", function()
            for _, line in StationConfig.LINE_ORDER do
                check.is_true(Strings.NET_WORDS[line] ~= nil)
                check.is_true(Strings.LINE_WORDS[line] ~= nil)
                for _, step in StationConfig.LINES[line].steps do
                    check.is_true(Strings.LINK_WORDS[step.link] ~= nil)
                    if step.kind == "processor" then
                        check.is_true(Strings.BUILDING_WORDS[step.link] ~= nil)
                    end
                end
            end
            for _, seller in StationConfig.SELLER_ORDER do
                check.is_true(Strings.LINK_WORDS[seller] ~= nil)
                check.is_true(Strings.BUILDING_WORDS[seller] ~= nil)
            end
        end)

        test.case(
            "[D70] si barajul: verigile, plasele, cladirile si orasul au cuvintele lor",
            function()
                for _, line in StationConfig.LINE_ORDER_ALL do
                    local spec = StationConfig.LINES[line]
                    check.is_true(Strings.LINE_WORDS[line] ~= nil)
                    -- o unire n-are plase: intra ce aduc piesele ei
                    check.equal(Strings.NET_WORDS[line] ~= nil, spec.netKind ~= nil)
                    for _, step in spec.steps do
                        check.is_true(Strings.LINK_WORDS[step.link] ~= nil)
                        if step.kind == "processor" then
                            check.is_true(Strings.BUILDING_WORDS[step.link] ~= nil)
                        end
                    end
                    -- o piesa sau o unire se numeste dupa linia ei („the Cable line is slower”)
                    if spec.into ~= nil or spec.inputs ~= nil then
                        check.is_true(Strings.LINE_WORDS[line].name ~= nil)
                    end
                end
                for _, seller in StationConfig.SELLER_ORDER_ALL do
                    check.is_true(Strings.LINK_WORDS[seller] ~= nil)
                    check.is_true(Strings.BUILDING_WORDS[seller] ~= nil)
                    -- fara ele, refuzul unui vanzator ar fi spus textul Pietei
                    check.is_true(Strings.SELLER_WORDS[seller] ~= nil)
                    -- randul are 560 la marimea mica: 66 de litere de pixeli [2026-09-15]
                    check.is_true(#Strings.stationsAdvice(seller) <= 72)
                end
                for _, line in StationConfig.LINE_ORDER_ALL do
                    for _, step in StationConfig.LINES[line].steps do
                        check.is_true(#Strings.stationsAdvice(step.link) <= 72)
                    end
                end
            end
        )

        test.case(
            "[D70] „No gain yet” incape pe randul panoului Upgrades, pe orice veriga a oricarei ere",
            function()
                -- randul de avertisment: 354 px la 13, fontul de pixeli are 0,56 em pe litera
                local function fits(text: string)
                    local n = utf8.len(text) :: number
                    if n * 13 * 0.5585 > 354 then
                        print(`nu incape: {text}`)
                    end
                    check.is_true(n * 13 * 0.5585 <= 354)
                end
                for _, line in StationConfig.LINE_ORDER_ALL do
                    for _, step in StationConfig.LINES[line].steps do
                        fits(Strings.menuHeldBack(step.link, true, line))
                    end
                    if StationConfig.LINES[line].netKind ~= nil then
                        fits(Strings.menuHeldBack("nets", true, line))
                    end
                    local name = Strings.LINE_WORDS[line].name
                    if name ~= nil then
                        fits(Strings.menuHeldBack("relay", true, line, line))
                    end
                end
                for _, seller in StationConfig.SELLER_ORDER_ALL do
                    fits(Strings.menuHeldBack(seller, true, nil))
                end
            end
        )

        test.case("sfatul panoului incape pe randul lui si numeste veriga intrebata", function()
            -- randul are 560 la marimea mica: 66 de litere de pixeli [2026-09-15]
            for _, link in StationConfig.LINKS do
                local text = Strings.stationsAdvice(link)
                check.is_true(#text <= 72)
                if link ~= "nets" and link ~= "dock" then
                    check.is_true(text ~= Strings.stationsAdvice("dock"))
                end
            end
        end)

        test.case("Moara: cuvintele ei, nu ale satului vechi", function()
            check.equal(
                Strings.menuHeldBack("foundry", false, "parts"),
                "No gain yet — the Foundry is slower"
            )
            check.equal(
                Strings.menuHeldBack("nets", false, "copper"),
                "No gain yet — the ore net is slower"
            )
            check.equal(
                Strings.menuHeldBack("nets", true, "parts"),
                "No gain yet — the Mill nets are just as slow"
            )
            check.equal(
                Strings.menuHeldBack("market", false, nil),
                "No gain yet — the Market is slower"
            )
            check.equal(Strings.menuGoTo("furnace"), "Go to Copper Furnace")
            check.equal(Strings.lineNotOpen("parts"), "No gain yet — cast the Sixth Net first")
            check.equal(Strings.lineNotOpen("copper"), "No gain yet — cast the Tenth Net first")
            check.equal(Strings.menuUnit("parts", true), "scrap a minute")
            check.equal(Strings.menuUnit("parts", false), "parts a minute")
            check.equal(Strings.menuUnit("copper", true), "ore a minute")
            check.equal(Strings.menuUnit("copper", false), "copper a minute")
            check.equal(Strings.menuDoes("market", false), "Sells at 35% until you hire a Merchant")
            check.equal(Strings.menuMilestone("foundry", 10, 2), "Level 10: casts twice as fast")
            check.equal(
                Strings.crewNone("merchant", "Merchant"),
                "No Merchant — the Market sells slowly"
            )
        end)

        test.case(
            "[D67] turbina umple baterii, nu prinde: meniul si bannerul de prag spun asta",
            function()
                local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
                check.equal(TycoonConfig.wordsKindOf("net", "first_turbine"), "turbine")
                check.equal(TycoonConfig.wordsKindOf("net", "first_net"), "net")
                check.equal(TycoonConfig.wordsKindOf("saw", nil), "saw")
                check.equal(Strings.milestoneNow("turbine", 2), "Fills twice as much now")
                check.equal(
                    Strings.menuMilestone("turbine", 10, 2),
                    "Level 10: fills twice as much"
                )
                check.equal(Strings.menuDoes("turbine", true), "Fills batteries")
                -- orice platforma cu plasa (si turbina) are cuvintele ei in tabel, nu cade pe ale tavernei
                for _, pad in TycoonConfig.PADS do
                    for _, effect in pad.effects do
                        if effect.kind == "net" then
                            check.not_nil(
                                Strings.BUILDING_WORDS[TycoonConfig.wordsKindOf("net", pad.id)]
                            )
                        end
                    end
                end
            end
        )
    end)
end
