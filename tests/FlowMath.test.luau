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
    -- [D70] Pasul i al planului motorului: barajul sta in tabele (FlowConfig.FULL, FlowMath.FULL), iar jocul vede doar
    -- erele lui (StationConfig.ENGINE_ERAS). Pasul j il porneste.
    test.suite("FlowConfig - barajul adormit [D70, pasul i]", function()
        test.case("jocul vede doar liniile, vanzatorii si gramezile erelor din joc", function()
            local n = 0
            for line, spec in FlowConfig.LINES do
                n += 1
                check.is_true(table.find(StationConfig.LINE_ORDER, line) ~= nil)
                check.is_true(spec == FlowConfig.LINES_ALL[line]) -- aceleasi tabele, nu copii
            end
            check.equal(n, #StationConfig.LINE_ORDER)
            local sellers = 0
            for seller in FlowConfig.SELLERS do
                sellers += 1
                check.is_true(table.find(StationConfig.SELLER_ORDER, seller) ~= nil)
            end
            check.equal(sellers, #StationConfig.SELLER_ORDER)
            if StationConfig.ENGINE_ERAS < 4 then
                check.is_true(FlowConfig.SELLERS.town == nil)
                check.is_true(FlowConfig.LINES.grid == nil)
                check.is_true(FlowConfig.BY_PROCESSOR.relay == nil)
                check.is_true(FlowConfig.BY_STORE.damStore == nil)
                check.is_true(FlowConfig.BY_OUTPUT.barrel == nil)
                check.equal(#FlowConfig.PILES, 6 * 3 + 3)
            end
            check.is_true(FlowConfig.BY_STORE == FlowConfig.GAME.byStore)
            check.is_true(FlowConfig.PILES == FlowConfig.GAME.piles)
        end)

        test.case("FULL are toate erele, cu locuri si gramezi care nu se calca", function()
            local F = FlowConfig.FULL
            local ChainMath = require("../src/Shared/Modules/ChainMath")
            local places: { [string]: string } = {}
            local function claim(place: string?, owner: string)
                if place ~= nil then
                    check.is_true(places[place] == nil)
                    places[place] = owner
                end
            end
            for _, seller in StationConfig.SELLER_ORDER_ALL do
                claim(seller, seller) -- NetServer.UsePlace si DropAt cauta locul intai in linii, apoi la vanzatori
            end
            for _, line in StationConfig.LINE_ORDER_ALL do
                local spec = F.lines[line]
                check.not_nil(spec)
                check.equal(spec.line, line)
                check.equal(spec.seller, StationConfig.LINES[line].seller)
                check.equal(spec.into, StationConfig.LINES[line].into)
                check.equal(ChainMath.FULL.roleOfLink[spec.station], spec.role)
                check.not_nil(StationConfig.PROCESSORS[spec.station])
                claim(spec.store, line)
                claim(spec.processor, line)
                claim(spec.output, line)
                -- o linie are magazie si o singura intrare, sau e o unire (piesele ei, fara magazie)
                check.is_true((spec.joins == nil) == (spec.store ~= nil and spec.inputPile ~= nil))
            end
            local piles: { [string]: boolean } = {}
            for _, pile in F.piles do
                check.is_true(piles[pile] == nil)
                piles[pile] = true
            end
            -- 6 linii vechi + 3 linii ale barajului cu magazie (3 gramezi), unirea (2 intrari + iesirea), 4 vanzatori
            check.equal(#F.piles, 6 * 3 + 3 * 3 + 3 + 4)
            check.equal(F.sellers.town.role, StationConfig.SELLERS.town.role)
        end)

        test.case(
            "unirea: piesele ei, in ordinea retetei, sunt chiar bunurile din JOINED",
            function()
                local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
                local LA = FlowConfig.LINES_ALL
                local grid = LA.grid
                local recipe = StationConfig.LINES.grid.inputs :: { string }
                local goods = TycoonConfig.JOINED[StationConfig.LINES.grid.value :: string]
                check.equal(#(grid.joins :: any), #recipe)
                for i, join in grid.joins :: { FlowConfig.Join } do
                    check.equal(join.line, recipe[i])
                    check.equal(join.good, goods[i])
                    check.equal(join.good, LA[join.line].output)
                    check.equal(TycoonConfig.PROCESSED[LA[join.line].raw[1]], join.good)
                end
                check.equal(#grid.raw, 0)
                check.is_true(grid.store == nil and grid.inputPile == nil)
                check.equal(grid.seller, "town")
                check.equal(grid.partRefusal, "part_to_relay")
                for _, line in StationConfig.LINE_ORDER_ALL do
                    check.equal(LA[line].partRefusal ~= nil, LA[line].joins ~= nil)
                end
            end
        )

        test.case("barajul nu prinde gasiri, iar numaratorile lui nu se calca cu altele", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            for _, line in StationConfig.ERA_LINES_ALL[4] do
                check.is_true(FlowConfig.LINES_ALL[line].find == nil)
                local kind = StationConfig.LINES[line].netKind
                for _, part in (if kind ~= nil then TycoonConfig.CATCH[kind] else {}) :: any do
                    check.is_false(PileMath.isFindGood(part.id))
                end
            end
            check.is_true(FlowConfig.SELLERS_ALL.town.find == nil)
            local stats: { [string]: boolean } = {}
            for _, spec in FlowConfig.LINES_ALL do
                for _, stat in { spec.processedStat, spec.soldStat } do
                    check.is_true(stats[stat] == nil)
                    stats[stat] = true
                end
            end
        end)
    end)

    test.suite("FlowMath - Erele 1-3 neschimbate de baraj [D70, pasul i]", function()
        test.case("fiecare marfa veche isi pastreaza linia si vanzatorul in FULL", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local FULL = FlowMath.FULL
            local goods: { string } = { "ceva_vechi", "named", "named2", "named3" }
            for _, line in StationConfig.ERA_LINES_ALL[1] do
                table.insert(goods, line)
            end
            for era = 1, 3 do
                for _, line in StationConfig.ERA_LINES_ALL[era] do
                    for _, g in FlowConfig.LINES_ALL[line].raw do
                        table.insert(goods, g)
                        table.insert(goods, TycoonConfig.PROCESSED[g] or g)
                    end
                end
            end
            for _, g in goods do
                check.equal(FlowMath.lineOfGood(g), FlowMath.lineOfGood(g, FULL))
                for _, cut in { false, true } do
                    local item = { g = g, p = cut }
                    check.equal(FlowMath.sellerOf(item), FlowMath.sellerOf(item, FULL))
                    check.is_true(
                        FlowMath.partOf(item) == nil and FlowMath.partOf(item, FULL) == nil
                    )
                end
            end
            -- gasirile Erei 3 raman ale Depoului: orasul n-are gasiri
            check.equal(FlowMath.sellerOf({ g = "named3" }, FULL), "depot")
        end)

        test.case(
            "jocul nu stie inca de baraj: o marfa a lui cade pe lemn, ca orice marfa necunoscuta",
            function()
                if StationConfig.ENGINE_ERAS < 4 then
                    check.equal(FlowMath.lineOfGood("charge"), "wood")
                    check.is_true(FlowMath.partOf({ g = "barrel", p = true }) == nil)
                end
            end
        )
    end)

    test.suite("FlowMath - unirea [D70, pasul i]", function()
        local F = FlowMath.FULL
        local LA = FlowConfig.LINES_ALL

        -- gramezile unirii, pe linia fiecarei piese (cheia din gramada: bunul ei)
        local function inputs(barrel: number, cable: number): FlowMath.JoinPiles
            return {
                barrels = if barrel > 0 then { barrel = barrel } else {},
                cable = if cable > 0 then { cable = cable } else {},
            }
        end

        test.case("piesele nu se vand: sellerOf(piesa) = nil, iar partOf spune unirea", function()
            check.equal(FlowMath.lineOfGood("charge", F), "barrels")
            check.equal(FlowMath.lineOfGood("barrel", F), "barrels")
            check.equal(FlowMath.lineOfGood("cable_ore", F), "cable")
            check.equal(FlowMath.lineOfGood("cable", F), "cable")
            check.equal(FlowMath.lineOfGood("grid", F), "grid")
            check.equal(FlowMath.lineOfGood("crystal", F), "crystal")
            check.equal(FlowMath.lineOfGood("ingot", F), "crystal")
            for _, g in { "barrel", "cable" } do
                check.is_true(FlowMath.sellerOf({ g = g, p = true }, F) == nil)
                check.equal(FlowMath.partOf({ g = g, p = true }, F), "grid")
            end
            check.equal(FlowMath.sellerOf({ g = "grid", p = true }, F), "town")
            check.equal(FlowMath.sellerOf({ g = "ingot", p = true }, F), "town")
            check.is_true(FlowMath.sellerOf({ g = "charge" }, F) == nil)
            check.is_true(FlowMath.partOf({ g = "charge" }, F) == nil)
            check.is_true(FlowMath.partOf({ g = "grid", p = true }, F) == nil)
            local stats =
                FlowMath.soldStats({ { g = "grid", p = true }, { g = "ingot", p = true } }, F)
            check.equal(stats.gridSold, 1)
            check.equal(stats.ingotsSold, 1)
        end)

        -- [D70, pasul k4] marfa bruta a barajului dusa la alt loc al lui: locul spune unde merge, nu „No cable yet”
        test.case("bateriile, minereul de cablu si cristalul duse gresit spun unde merg", function()
            local _, a = FlowMath.useProcessor(sack({ charge = 2 }), {}, {}, 60, LA.cable, F)
            check.equal(a, "batteries_to_switchyard")
            local _, b = FlowMath.useProcessor(sack({ cable_ore = 2 }), {}, {}, 60, LA.barrels, F)
            check.equal(b, "cable_ore_to_cableworks")
            local _, c = FlowMath.useProcessor(sack({ crystal = 2 }), {}, {}, 60, LA.barrels, F)
            check.equal(c, "crystal_to_kiln")
            -- la Relay, cu baterii in traista (nicio piesa de lasat, nimic de luat)
            local _, d = FlowMath.useJoin(sack({ charge = 2 }), inputs(0, 0), {}, 60, LA.grid, F)
            check.equal(d, "batteries_to_switchyard")
        end)

        test.case(
            "la oras: doar piese -> part_to_relay; cu lingouri si curent, piesele raman",
            function()
                local _, why = FlowMath.deliver(sack({}, { barrel = 3, cable = 2 }), {}, "town", F)
                check.equal(why, "part_to_relay")
                -- o piesa nu se vinde nicaieri: refuzul ei bate "other_seller"
                local _, why2 =
                    FlowMath.deliver(sack({}, { barrel = 1, planks = 1 }), {}, "town", F)
                check.equal(why2, "part_to_relay")
                local _, why3 = FlowMath.deliver(sack({ cable_ore = 2 }), {}, "town", F)
                check.equal(why3, "raw_only")
                local _, why4 = FlowMath.deliver(sack({}, { grid = 2 }), {}, "dock", F)
                check.equal(why4, "other_seller")
                local items = sack({}, { ingot = 2, grid = 1, barrel = 1 })
                local pile: PileMath.Counts = {}
                local ok, what, sold = FlowMath.deliver(items, pile, "town", F)
                check.is_true(ok)
                check.equal(what, "delivered")
                check.equal(#sold, 3)
                check.equal(#items, 1)
                check.equal(count(items, "barrel", true), 1)
                check.is_true(pile.barrel == nil)
            end
        )

        test.case("la Relay iei piesele gata; brutul, gasirile si restul raman", function()
            local items = sack(
                { cable_ore = 2, named3 = 1, charge = 1 },
                { barrel = 3, cable = 2, ingot = 1, planks = 1 }
            )
            local mine, finds, rest = FlowMath.split(items, LA.grid, F)
            check.equal(#mine, 5)
            check.equal(#finds, 0)
            check.equal(#rest, 6)
            -- la Switchyard: doar bateriile brute; butoaiele gata si gasirile raman
            local mine2, finds2, rest2 = FlowMath.split(items, LA.barrels, F)
            check.equal(#mine2, 1)
            check.equal(mine2[1].g, "charge")
            check.equal(#finds2, 0)
            check.equal(#rest2, #items - 1)
        end)

        test.case("dropJoin pune fiecare piesa in gramada ei si intoarce restul", function()
            local piles = inputs(0, 0)
            local items = sack({ charge = 1 }, { barrel = 3, cable = 2, grid = 1 })
            local dropped, rest = FlowMath.dropJoin(piles, items, LA.grid, F)
            check.equal(#dropped + #rest, #items)
            check.equal(#dropped, 5)
            check.equal(piles.barrels.barrel, 3)
            check.equal(piles.cable.cable, 2)
            check.equal(PileMath.total(piles.barrels), 3) -- o gramada tine un singur fel de marfa
            check.equal(PileMath.total(piles.cable), 2)
            check.equal(#items, 7) -- traista n-o atinge dropJoin
        end)

        test.case("la Relay, un singur gest: lasi piesele, iei curentul cat incape", function()
            local piles = inputs(0, 0)
            local output: PileMath.Counts = { grid = 40 }
            local items = sack({ cable_ore = 1 }, { barrel = 2, cable = 1 })
            local ok, why, dropped, taken = FlowMath.useJoin(items, piles, output, 30, LA.grid, F)
            check.is_true(ok)
            check.equal(why, "ok")
            check.equal(dropped, 3)
            check.equal(taken, 29)
            check.equal(#items, 30)
            check.equal(count(items, "grid", true), 29)
            check.equal(output.grid, 11)
            local _, full = FlowMath.useJoin(
                sack({}, { ingot = 30 }),
                inputs(0, 0),
                { grid = 3 },
                30,
                LA.grid,
                F
            )
            check.equal(full, "sack_full")
            local _, none = FlowMath.useJoin(sack({}), inputs(0, 0), {}, 30, LA.grid, F)
            check.equal(none, "nothing_joined")
        end)

        test.case("assemble: perechi = min(intregi, butoaie, cablu); nimic nu se pierde", function()
            local piles = inputs(5, 2)
            local output: PileMath.Counts = {}
            local carry, made = FlowMath.assemble(piles, output, 0, 3, 1, LA.grid)
            check.equal(made, 2)
            check.equal(carry, 0) -- capacitatea nefolosita nu se strange
            check.equal(piles.barrels.barrel, 3)
            check.is_true(next(piles.cable) == nil) -- cheia golita dispare, ca la PileMath.take
            check.equal(output.grid, 2)
            local carry2, made2 = FlowMath.assemble(inputs(9, 9), output, 0.5, 2.5, 1, LA.grid)
            check.equal(made2, 3)
            check.equal(carry2, 0)
        end)

        test.case("assemble se opreste cu o intrare goala si nu aduna restul", function()
            local piles = inputs(4, 0)
            local output: PileMath.Counts = {}
            check.equal(FlowMath.joinWaiting(piles, LA.grid), "cable")
            check.equal(FlowMath.joinWaiting(inputs(0, 0), LA.grid), "barrels")
            check.is_true(FlowMath.joinWaiting(inputs(1, 1), LA.grid) == nil)
            local carry, made = FlowMath.assemble(piles, output, 0.7, 3, 1, LA.grid)
            check.equal(carry, 0)
            check.equal(made, 0)
            check.equal(piles.barrels.barrel, 4)
            check.is_true(next(output) == nil)
            local carry2, made2 = FlowMath.assemble(inputs(4, 4), output, 0.7, 0, 1, LA.grid)
            check.equal(carry2, 0)
            check.equal(made2, 0)
            local carry3, made3 = FlowMath.assemble(inputs(4, 4), output, 0.2, 3, 0.1, LA.grid)
            check.equal(made3, 0)
            check.is_true(math.abs(carry3 - 0.5) < 1e-9)
        end)

        test.case(
            "pe multe tick-uri unirea face min(viteza, sosiri), fara sa piarda o bucata",
            function()
                local HandRoutes = require("../src/Shared/Modules/HandRoutes")
                for _, case in
                    {
                        { speed = 0.467, barrels = 1.46, cable = 0.9 }, -- Relay-ul tine
                        { speed = 2.8, barrels = 1.46, cable = 0.9 }, -- cablul tine, butoaiele asteapta
                        { speed = 2.8, barrels = 0.6, cable = 0.9 }, -- butoaiele tin
                    }
                do
                    local piles = inputs(0, 0)
                    local output: PileMath.Counts = {}
                    local carry, made, inB, inC = 0, 0, 0, 0
                    local cycle = 20 -- un om aduce la 20 s, cat a carat: loadFor = debit x durata
                    local loadB = HandRoutes.loadFor(case.barrels, cycle)
                    local loadC = HandRoutes.loadFor(case.cable, cycle)
                    local dt = 0.5
                    local seconds = 4000
                    for tick = 1, seconds / dt do
                        local t = tick * dt
                        if t % cycle == 0 then
                            PileMath.add(piles.barrels, { g = "barrel" }, loadB)
                            PileMath.add(piles.cable, { g = "cable" }, loadC)
                            inB += loadB
                            inC += loadC
                        end
                        local n
                        carry, n = FlowMath.assemble(piles, output, carry, case.speed, dt, LA.grid)
                        made += n
                        check.is_true(carry >= 0 and carry < 1)
                        check.equal((piles.barrels.barrel or 0) + made, inB)
                        check.equal((piles.cable.cable or 0) + made, inC)
                    end
                    check.equal(output.grid, made)
                    local want = math.min(case.speed, loadB / cycle, loadC / cycle)
                    check.is_true(math.abs(made / seconds - want) <= 0.02 * want)
                end
            end
        )
    end)

    test.suite("FlowMath - gardurile unirii [D70, pasul i]", function()
        local F = FlowMath.FULL
        local LA = FlowConfig.LINES_ALL

        test.case(
            "un rand al barajului cerut cu modelul jocului pica, nu „nu face nimic”",
            function()
                local items = sack({}, { barrel = 1 })
                check.is_false((pcall(FlowMath.split, items, LA.grid)))
                check.is_true((pcall(FlowMath.split, items, LA.grid, F)))
            end
        )

        test.case(
            "o gramada de piesa lipsa e o greseala a serverului: pica, nu pierde bucati",
            function()
                local items = sack({}, { barrel = 1, cable = 1 })
                local barrels: PileMath.Counts = {}
                local ok = pcall(FlowMath.dropJoin, { barrels = barrels }, items, LA.grid, F)
                check.is_false(ok)
                check.equal(#items, 2)
                -- nimic pus pe jumatate: gramada butoaielor a ramas goala
                check.is_true(next(barrels) == nil)
            end
        )

        test.case("o cheie straina din gramada unei piese nu intra in unire", function()
            local piles: FlowMath.JoinPiles =
                { barrels = { barrel = 1, ["named3|x|1"] = 2 }, cable = { cable = 5 } }
            local output: PileMath.Counts = {}
            local _, made = FlowMath.assemble(piles, output, 0, 5, 1, LA.grid)
            check.equal(made, 1)
            check.equal(piles.barrels["named3|x|1"], 2)
            check.equal(piles.cable.cable, 4)
            check.equal(output.grid, 1)
        end)

        test.case("orasul plin, pe gramezi: cristalul intai, ca GOLDEN_ERA4 (x1000)", function()
            local order = FlowMath.drainOrder("town", F)
            local pile: PileMath.Counts = { grid = 7939, ingot = 4581 }
            local batch = PileMath.take(pile, 9000, true, order)
            check.equal(count(batch, "ingot", true), 4581)
            check.equal(count(batch, "grid", true), 4419)
            -- fara ordine, in ordinea cheilor, s-ar fi vandut intai curentul (mai ieftin)
            local plain = PileMath.take({ grid = 7939, ingot = 4581 }, 9000, true)
            check.equal(count(plain, "grid", true), 7939)
        end)

        test.case("refuzul pieselor sta doar pe uniri; ordinea de scurgere doar la oras", function()
            for _, line in StationConfig.LINE_ORDER_ALL do
                check.equal(LA[line].partRefusal ~= nil, StationConfig.LINES[line].inputs ~= nil)
            end
            for _, seller in StationConfig.SELLER_ORDER_ALL do
                check.equal(FlowConfig.SELLERS_ALL[seller].takeOrder ~= nil, seller == "town")
            end
        end)
    end)

    test.suite("FlowMath - ordinea in care vinde un vanzator [D70, pasul i]", function()
        test.case("orasul vinde intai lingourile, apoi curentul, ca ChainMath", function()
            local order = FlowMath.drainOrder("town", FlowMath.FULL) :: { string }
            check.equal(#order, 2)
            check.equal(order[1], "ingot")
            check.equal(order[2], "grid")
            local pile: PileMath.Counts = { grid = 5, ingot = 3 }
            local batch = PileMath.take(pile, 4, true, order)
            check.equal(count(batch, "ingot", true), 3)
            check.equal(count(batch, "grid", true), 1)
            check.equal(pile.grid, 4)
            check.is_true(pile.ingot == nil)
        end)

        test.case(
            "vanzatorii Erelor 1-3 scurg exact ca azi: ordinea cheilor e chiar `priority`",
            function()
                for _, seller in { "dock", "market", "depot" } do
                    check.is_true(FlowMath.drainOrder(seller) == nil)
                    check.is_true(FlowMath.drainOrder(seller, FlowMath.FULL) == nil)
                    local outs: { string } = {}
                    for _, line in StationConfig.SELLERS[seller].priority do
                        table.insert(outs, FlowConfig.LINES_ALL[line].output)
                    end
                    local sorted = table.clone(outs)
                    table.sort(sorted)
                    for i = 1, #outs do
                        check.equal(outs[i], sorted[i])
                    end
                end
                local a: PileMath.Counts = { planks = 2, iron = 1, ["named|boot|rare"] = 1 }
                local b = table.clone(a)
                local ta, tb = PileMath.take(a, 3, true), PileMath.take(b, 3, true, nil)
                for i = 1, 3 do
                    check.equal(ta[i].g, tb[i].g)
                end
            end
        )
    end)
end
