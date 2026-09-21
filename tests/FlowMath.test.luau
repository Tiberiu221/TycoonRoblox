-- [D65] Gesturile drumului marfii, pe orice linie. Prima jumatate tine pe loc ce facea EconomyService in Era 1 inainte
-- sa treaca pe FlowMath (aceleasi motive de refuz, aceleasi numere); a doua, liniile Erei 2 si cei doi vanzatori.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local FlowConfig = require("../src/Shared/Config/FlowConfig")
local StationConfig = require("../src/Shared/Config/StationConfig")
local FlowMath = require("../src/Shared/Modules/FlowMath")
local PileMath = require("../src/Shared/Modules/PileMath")

local L = FlowConfig.LINES

local function sack(spec: { [string]: number }, cut: { [string]: number }?): { PileMath.Catch }
    local items: { PileMath.Catch } = {}
    for good, n in spec do
        for _ = 1, n do
            table.insert(items, { g = good, t = if PileMath.isFindGood(good) then "rare" else nil })
        end
    end
    for good, n in cut or {} do
        for _ = 1, n do
            table.insert(items, { g = good, p = true })
        end
    end
    return items
end

local function count(items: { PileMath.Catch }, good: string, cut: boolean?): number
    local n = 0
    for _, item in items do
        if item.g == good and (cut == nil or (item.p == true) == cut) then
            n += 1
        end
    end
    return n
end

return function()
    test.suite("FlowConfig - drumul marfii, ca date", function()
        test.case(
            "fiecare linie a lantului isi are drumul, cu cladirea, omul si vanzatorul din StationConfig",
            function()
                for _, line in StationConfig.LINE_ORDER do
                    local spec = L[line]
                    check.not_nil(spec)
                    check.equal(spec.line, line)
                    check.equal(spec.seller, StationConfig.LINES[line].seller)
                    check.equal(StationConfig.LINK_OF[spec.role], spec.station)
                    check.not_nil(StationConfig.PROCESSORS[spec.station])
                end
                check.equal(L.wood.station, "saw")
                check.equal(L.iron.role, "smelter")
                check.equal(L.parts.station, "foundry")
                check.equal(L.copper.role, "coppersmith")
                for _, seller in StationConfig.SELLER_ORDER do
                    local s = FlowConfig.SELLERS[seller]
                    check.equal(s.role, StationConfig.SELLERS[seller].role)
                end
            end
        )

        test.case("locurile si gramezile nu se repeta", function()
            local seen: { [string]: boolean } = {}
            for _, spec in L do
                for _, place in { spec.store, spec.processor, spec.output } do
                    check.is_true(seen[place] == nil)
                    seen[place] = true
                end
            end
            local piles: { [string]: boolean } = {}
            for _, pile in FlowConfig.PILES do
                check.is_true(piles[pile] == nil)
                piles[pile] = true
            end
            check.equal(#FlowConfig.PILES, 6 * 3 + 3) -- [D67] sase linii, trei vanzatori
            -- gramezile Erei 1 sunt campurile pe care le are deja profilul
            for _, pile in
                {
                    "StoragePile",
                    "SawmillPile",
                    "PlanksPile",
                    "ScrapPile",
                    "ForgePile",
                    "IronPile",
                    "DockPile",
                }
            do
                check.is_true(piles[pile] == true)
            end
        end)
    end)

    test.suite("FlowMath - Era 1, exact ca inainte de D65", function()
        test.case(
            "la depozit lasi lemnul si gasirile; scrap-ul si scandurile raman in traista",
            function()
                local items = sack({ driftwood = 5, scrap = 2, named = 1 }, { planks = 3 })
                local pile: PileMath.Counts = {}
                local ok, what, n = FlowMath.useStore(items, pile, 30, L.wood)
                check.is_true(ok)
                check.equal(what, "dropped")
                check.equal(n, 6)
                check.equal(PileMath.total(pile), 6)
                check.equal(#items, 5)
                check.equal(count(items, "scrap"), 2)
                check.equal(count(items, "planks", true), 3)
            end
        )

        test.case("fara lemn in traista iei din depozit cat incape", function()
            local items = sack({}, { planks = 4 })
            local pile: PileMath.Counts = { driftwood = 50 }
            local ok, what, n = FlowMath.useStore(items, pile, 30, L.wood)
            check.is_true(ok)
            check.equal(what, "took")
            check.equal(n, 26)
            check.equal(#items, 30)
            check.equal(pile.driftwood, 24)
            -- ce iei din depozit e tot brut
            check.equal(count(items, "driftwood", false), 26)
        end)

        test.case(
            "refuzurile depozitului: plin, gol, iar cu scrap in traista spune unde sa-l duci",
            function()
                local full = sack({}, { planks = 30 })
                local ok, why = FlowMath.useStore(full, { driftwood = 9 }, 30, L.wood)
                check.is_false(ok)
                check.equal(why, "sack_full")
                local ok2, why2 = FlowMath.useStore(sack({}), {}, 30, L.wood)
                check.is_false(ok2)
                check.equal(why2, "storage_empty")
                local ok3, why3 = FlowMath.useStore(sack({ scrap = 3 }), {}, 30, L.wood)
                check.is_false(ok3)
                check.equal(why3, "scrap_to_forge")
                local ok4, why4 =
                    FlowMath.useStore(sack({ scrap = 30 }), { driftwood = 9 }, 30, L.wood)
                check.is_false(ok4)
                check.equal(why4, "scrap_to_forge")
            end
        )

        test.case("shed-ul ia scrap-ul si gasirile, nu spune nimic despre busteni", function()
            local items = sack({ driftwood = 5, scrap = 2, named = 1 })
            local pile: PileMath.Counts = {}
            local ok, what, n = FlowMath.useStore(items, pile, 30, L.iron)
            check.is_true(ok)
            check.equal(what, "dropped")
            check.equal(n, 3)
            check.equal(count(items, "driftwood"), 5)
            local ok2, why2 = FlowMath.useStore(sack({ driftwood = 30 }), { scrap = 4 }, 30, L.iron)
            check.is_false(ok2)
            check.equal(why2, "sack_full")
            local ok3, why3 = FlowMath.useStore(sack({ driftwood = 3 }), {}, 30, L.iron)
            check.is_false(ok3)
            check.equal(why3, "shed_empty")
        end)

        test.case("la gater, un singur gest: lasi lemnul, iei scandurile cat incape", function()
            local items = sack({ driftwood = 10, scrap = 5 })
            local input: PileMath.Counts = {}
            local output: PileMath.Counts = { planks = 40 }
            local ok, why, dropped, taken = FlowMath.useProcessor(items, input, output, 30, L.wood)
            check.is_true(ok)
            check.equal(why, "ok")
            check.equal(dropped, 10)
            check.equal(taken, 25)
            check.equal(#items, 30)
            check.equal(count(items, "planks", true), 25)
            check.equal(input.driftwood, 10)
            check.equal(output.planks, 15)
        end)

        test.case("refuzurile gaterului si ale forjei, in ordinea de dinainte", function()
            local _, why = FlowMath.useProcessor(
                sack({}, { planks = 30 }),
                {},
                { planks = 5 },
                30,
                L.wood
            )
            check.equal(why, "sack_full")
            local _, why2 = FlowMath.useProcessor(sack({ scrap = 2 }), {}, {}, 30, L.wood)
            check.equal(why2, "scrap_to_forge")
            local _, why3 = FlowMath.useProcessor(sack({}), {}, {}, 30, L.wood)
            check.equal(why3, "nothing_cut")
            local _, why4 = FlowMath.useProcessor(sack({ driftwood = 2 }), {}, {}, 30, L.iron)
            check.equal(why4, "nothing_smelted")
            local _, why5 = FlowMath.useProcessor(
                sack({ driftwood = 30 }),
                {},
                { iron = 3 },
                30,
                L.iron
            )
            check.equal(why5, "sack_full")
        end)

        test.case("taverna cumpara ce e taiat si gasirile; brutul ramane", function()
            local items = sack({ driftwood = 4, scrap = 1, named = 2 }, { planks = 6, iron = 3 })
            local pile: PileMath.Counts = {}
            local ok, why, sold = FlowMath.deliver(items, pile, "dock")
            check.is_true(ok)
            check.equal(why, "delivered")
            check.equal(#sold, 11)
            check.equal(#items, 5)
            check.equal(PileMath.total(pile), 11)
            check.equal(FlowMath.soldStats(sold).ironSold, 3)
            local _, empty = FlowMath.deliver(sack({}), {}, "dock")
            check.equal(empty, "empty")
            local _, raw = FlowMath.deliver(sack({ driftwood = 2 }), {}, "dock")
            check.equal(raw, "raw_only")
        end)

        test.case(
            "gaterul face scanduri din busteni; gasirile si marfa veche trec neschimbate",
            function()
                local input: PileMath.Counts = {}
                PileMath.addItems(input, sack({ driftwood = 5, reeds = 2, named = 1 }))
                local output: PileMath.Counts = {}
                local carry, made = FlowMath.process(input, output, 0, 2.5, 1, L.wood)
                check.equal(made, 2)
                check.equal(carry, 0.5)
                local carry2, made2 = FlowMath.process(input, output, carry, 2.5, 3, L.wood)
                check.equal(made2, 6)
                check.equal(carry2, 0) -- 0.5 + 7.5 = 8, toate cele 6 ramase
                check.equal(next(input), nil)
                check.equal(output.planks, 5)
                check.equal(output.reeds, 2)
                check.equal(PileMath.total(output), 8)
            end
        )

        test.case(
            "atelier gol sau oprit: nu se aduna taieturi pentru marfa care nu se taie",
            function()
                local carry, made = FlowMath.process({}, {}, 0.7, 3, 1, L.wood)
                check.equal(carry, 0)
                check.equal(made, 0)
                local carry2, made2 = FlowMath.process({ driftwood = 4 }, {}, 0.7, 0, 1, L.wood)
                check.equal(carry2, 0)
                check.equal(made2, 0)
                local carry3, made3 = FlowMath.process({ driftwood = 4 }, {}, 0.2, 3, 0.1, L.wood)
                check.equal(made3, 0)
                check.is_true(math.abs(carry3 - 0.5) < 1e-9)
            end
        )
    end)

    test.suite("FlowMath - Era 2: piesele, cuprul si Piata [D65]", function()
        test.case("fiecare marfa isi stie linia; una necunoscuta e a lemnului", function()
            check.equal(FlowMath.lineOfGood("driftwood"), "wood")
            check.equal(FlowMath.lineOfGood("planks"), "wood")
            check.equal(FlowMath.lineOfGood("scrap"), "iron")
            check.equal(FlowMath.lineOfGood("iron"), "iron")
            check.equal(FlowMath.lineOfGood("mill_scrap"), "parts")
            check.equal(FlowMath.lineOfGood("parts"), "parts")
            check.equal(FlowMath.lineOfGood("ore"), "copper")
            check.equal(FlowMath.lineOfGood("copper"), "copper")
            check.equal(FlowMath.lineOfGood("ceva_vechi"), "wood")
        end)

        test.case(
            "Mill Store ia scrap-ul Morii si gasirile erei ei; ale Erei 1 raman in traista",
            function()
                local items = sack({ mill_scrap = 6, scrap = 2, named = 1, named2 = 2, ore = 3 })
                local pile: PileMath.Counts = {}
                local ok, what, n = FlowMath.useStore(items, pile, 60, L.parts)
                check.is_true(ok)
                check.equal(what, "dropped")
                check.equal(n, 8)
                check.equal(pile.mill_scrap, 6)
                check.equal(count(items, "scrap"), 2)
                check.equal(count(items, "named"), 1)
                check.equal(count(items, "ore"), 3)
                check.equal(count(items, "named2"), 0)
            end
        )

        test.case(
            "turnatoria face piese, cuptorul face cupru; locurile pieselor spun unde se duce minereul",
            function()
                local input: PileMath.Counts = { mill_scrap = 4 }
                local output: PileMath.Counts = {}
                local _, made = FlowMath.process(input, output, 0, 10, 1, L.parts)
                check.equal(made, 4)
                check.equal(output.parts, 4)
                local oreIn: PileMath.Counts = { ore = 3 }
                local oreOut: PileMath.Counts = {}
                FlowMath.process(oreIn, oreOut, 0, 10, 1, L.copper)
                check.equal(oreOut.copper, 3)
                local _, why = FlowMath.useProcessor(sack({ ore = 2 }), {}, {}, 60, L.parts)
                check.equal(why, "ore_to_furnace")
                local _, why2 = FlowMath.useProcessor(
                    sack({ mill_scrap = 2 }),
                    {},
                    {},
                    60,
                    L.copper
                )
                check.equal(why2, "nothing_smelted_copper")
            end
        )

        test.case("fiecare vanzator cumpara marfa liniilor lui si gasirile erei lui", function()
            local items = sack(
                { named = 1, named2 = 2, mill_scrap = 1 },
                { planks = 3, iron = 1, parts = 4, copper = 2 }
            )
            local market: PileMath.Counts = {}
            local ok, _, sold = FlowMath.deliver(items, market, "market")
            check.is_true(ok)
            check.equal(#sold, 8) -- 4 piese, 2 cupru, 2 gasiri ale Erei 2
            local stats = FlowMath.soldStats(sold)
            check.equal(stats.partsSold, 4)
            check.equal(stats.copperSold, 2)
            check.equal(stats.ironSold, nil)
            local dock: PileMath.Counts = {}
            local ok2, _, sold2 = FlowMath.deliver(items, dock, "dock")
            check.is_true(ok2)
            check.equal(#sold2, 5) -- 3 scanduri, 1 fier, 1 gasire a Erei 1
            check.equal(#items, 1) -- ramane scrap-ul brut al Morii
        end)

        test.case("la vanzatorul gresit refuzul spune ca marfa se vinde in alta parte", function()
            local _, why = FlowMath.deliver(sack({}, { planks = 3 }), {}, "market")
            check.equal(why, "other_seller")
            local _, why2 = FlowMath.deliver(sack({}, { parts = 3 }), {}, "dock")
            check.equal(why2, "other_seller")
            local _, why3 = FlowMath.deliver(sack({ ore = 3 }), {}, "market")
            check.equal(why3, "raw_only")
        end)

        test.case("o gramada tine gasirile pe ere, cu catalogul si treapta lor", function()
            local pile: PileMath.Counts = {}
            PileMath.add(pile, { g = "named", c = "boot", t = "rare" })
            PileMath.add(pile, { g = "named2", c = "gear", t = "epic" }, 2)
            check.equal(pile["named|boot|rare"], 1)
            check.equal(pile["named2|gear|epic"], 2)
            local contents = PileMath.contents(pile)
            check.equal(contents.named, 1)
            check.equal(contents.named2, 2)
            local taken = PileMath.take(pile, 3)
            check.equal(#taken, 3)
            local seen2 = 0
            for _, item in taken do
                if item.g == "named2" then
                    seen2 += 1
                    check.equal(item.c, "gear")
                    check.equal(item.t, "epic")
                end
            end
            check.equal(seen2, 2)
        end)
    end)
end
