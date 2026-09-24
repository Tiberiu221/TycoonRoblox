local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonMath = require("../src/Shared/Modules/TycoonMath")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local StationConfig = require("../src/Shared/Config/StationConfig")

-- Paritatea cu simulatorul s-a MUTAT in tests/ChainMath.test.luau odata cu trecerea pe lantul cu
-- trei verigi (E1.3): venitul nu mai e o suma peste platforme, deci `greedyRun`/`income`/`nice`
-- n-au mai avut ce oglindi si au fost scoase din TycoonMath. Aici a ramas ce nu tine de venit.

return function()
    test.suite("TycoonMath.stateFor", function()
        -- [D65] Testele de aici foloseau platforme ale erelor 3-4 de dinainte de D46 (Sorting Shed, Smelter, Fine
        -- Ingots, Sawmill II), iesite din config odata cu rescrierea Erei 2. Efectele lor (`add`, `build`, `refine`,
        -- `upgrade`) n-au ramas pe nicio platforma; se verifica direct, pe `applyEffect`.
        test.case("un upgrade fara statia lui de baza nu crapa", function()
            local s = TycoonMath.newState(0, 0)
            TycoonMath.applyEffect(s, { kind = "upgrade", good = "driftwood", factor = 2 })
            check.is_true(s.stations.driftwood == nil)
            TycoonMath.applyEffect(
                s,
                { kind = "build", good = "scrap", mult = 3.0, cap = 1, draw = 1 }
            )
            TycoonMath.applyEffect(s, { kind = "refine", good = "scrap", factor = 1.5 })
            check.equal(s.stations.scrap.mult, 3.0 * 1.5) -- rafinarea dupa constructie
        end)

        test.case("steagurile Erei 2 vin din platformele ei [D65]", function()
            local s = TycoonMath.stateFor({ water_wheel = true, copper_furnace = true }, 0, 0)
            check.is_true(s.wheel)
            check.is_true(s.furnace)
            check.is_false(s.oreShed)
            check.is_false(TycoonMath.stateFor({}, 0, 0).wheel)
        end)

        test.case(
            "felul plasei e cel scris pe efectul ei; gasirile au cadrul erei lor [D65]",
            function()
                check.equal(TycoonMath.netKind(TycoonConfig.byId.first_net), "wood")
                check.equal(TycoonMath.netKind(TycoonConfig.byId.fifth_net), "scrap")
                check.equal(TycoonMath.netKind(TycoonConfig.byId.sixth_net), "mill")
                check.equal(TycoonMath.netKind(TycoonConfig.byId.tenth_net), "ore")
                local s = TycoonMath.newState(0, 0)
                check.equal(TycoonMath.itemValue("named", "rare", s), 22)
                -- [D66] cadrul Morii: de StationConfig.ERA2_MULT ori marfa (si gasirile) Erei 1
                local m = StationConfig.ERA2_MULT
                check.equal(TycoonMath.itemValue("named2", "rare", s), 22 * m)
                check.equal(TycoonMath.itemValue("parts", nil, s), 1 * m)
                check.equal(TycoonMath.itemValue("copper", nil, s), 3 * m)
                check.is_true(TycoonMath.isFind("named2"))
                check.is_false(TycoonMath.isFind("parts"))
            end
        )
    end)

    test.suite("TycoonMath.era [D60]", function()
        test.case("un profil nou e in Era 1", function()
            check.equal(TycoonMath.era({}), 1)
        end)

        test.case("Era e cea a primei platforme necumparate, in ordinea tabelului", function()
            local bought = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    bought[p.id] = true
                end
            end
            check.equal(TycoonMath.era(bought), 2) -- clopotul Erei 1 sunat: esti la Moara
            bought.landing_bell = nil
            check.equal(TycoonMath.era(bought), 1)
        end)

        test.case("cu totul cumparat, ramai in ultima era aflata in joc", function()
            local bought = {}
            local last = 1
            for _, p in TycoonConfig.PADS do
                bought[p.id] = true
                if p.live then
                    last = math.max(last, p.era)
                end
            end
            check.equal(TycoonMath.era(bought), last)
        end)

        test.case("[D67] o era inca in constructie nu se arata ca pas urmator", function()
            -- cine a terminat Moara n-are ce cumpara in Era 3 pana e in joc: nicio platforma a ei nu se contureaza
            local bought: { [string]: boolean } = {}
            for _, p in TycoonConfig.PADS do
                if p.era <= 2 then
                    bought[p.id] = true
                end
            end
            local statuses = TycoonMath.padStatuses(bought)
            for _, p in TycoonConfig.PADS do
                if not p.live then
                    check.equal(statuses[p.id], nil)
                end
            end
        end)

        test.case("[D67] o era inca in constructie nu te muta in ea", function()
            -- platformele ei stau in tabel, dar nu in joc: cine a terminat era dinainte ramane acolo [D40]
            local pads = {
                { id = "a", era = 1, live = true },
                { id = "b", era = 2, live = true },
                { id = "c", era = 3, live = false },
            } :: any
            check.equal(TycoonMath.era({ a = true, b = true }, pads), 2)
            check.equal(TycoonMath.era({ a = true }, pads), 2)
        end)
    end)

    test.suite("TycoonMath.padStatuses", function()
        -- Regula s-a schimbat la E1.3: nu mai e "primele doua din tabel", ci "toate cele care si-au
        -- implinit conditia". Fara asta, jucatorul era obligat sa cumpere a treia plasa (inutila
        -- cat timp caratul e gatuirea) inainte sa poata angaja prima Mana.
        -- [D52] Toti cinci oamenii vin dupa prima plasa, iar plasele abia dupa ei: profilurile de mai
        -- jos au de aceea oamenii deja angajati cand vorbesc despre plase.
        local function withCrew(extra: { [string]: boolean }): { [string]: boolean }
            local bought = {
                first_net = true,
                first_runner = true,
                hire_porter = true,
                hire_sawyer = true,
                hire_hauler = true,
                dock_trader = true,
            }
            for id, value in extra do
                bought[id] = value
            end
            return bought
        end

        test.case("profil proaspat: doar prima plasa, si se vede ce urmeaza", function()
            local statuses = TycoonMath.padStatuses({})
            check.equal(statuses.first_net, "available")
            check.equal(statuses.first_runner, "outline") -- Collector-ul cere o plasa detinuta [D52]
            check.equal(statuses.second_net, nil)
            check.equal(statuses.bigger_sack, nil)
        end)

        test.case("cu prima plasa se deschide Collector-ul, nu a doua plasa [D52]", function()
            -- chiar cu nivelul 2 facut: plasa a doua asteapta Innkeeper-ul
            local statuses = TycoonMath.padStatuses(
                { first_net = true },
                nil,
                { first_net = TycoonConfig.PREV_NET_LEVEL }
            )
            check.equal(statuses.first_runner, "available")
            check.equal(statuses.hire_porter, "outline") -- Porter-ul vine dupa Collector [D49]
            check.equal(statuses.second_net, nil)
        end)

        test.case("Innkeeper-ul vine dupa Hauler, nu la trei plase [D52]", function()
            local bought: { [string]: boolean } =
                { first_net = true, first_runner = true, hire_porter = true, hire_sawyer = true }
            local before = TycoonMath.padStatuses(bought, nil, { first_net = 5 })
            check.equal(before.hire_hauler, "available")
            check.equal(before.dock_trader, "outline")
            bought.hire_hauler = true
            local after = TycoonMath.padStatuses(bought, nil, { first_net = 5 })
            check.equal(after.dock_trader, "available")
            check.equal(after.second_net, "outline") -- nivelul e facut, lipseste doar Innkeeper-ul
        end)

        test.case(
            "cu oamenii si doua plase: se deschid deodata traista si a treia plasa",
            function()
                local statuses = TycoonMath.padStatuses(withCrew({ second_net = true }))
                check.equal(statuses.bigger_sack, "available") -- cere cel putin 2 plase
                check.equal(statuses.third_net, "available") -- cere exact 2
                check.equal(statuses.far_lane_net, "outline") -- cere exact 3: inca nu, dar urmeaza
            end
        )

        test.case("o plasa in plus INCHIDE deblocarea care cerea exact atatea", function()
            -- `netsExactly` tine lantul de plase in ordine: nu poti sari peste a treia
            local statuses =
                TycoonMath.padStatuses(withCrew({ second_net = true, third_net = true }))
            check.equal(statuses.third_net, "bought")
            check.equal(statuses.far_lane_net, "available")
            check.is_true(statuses.fifth_net ~= "available") -- cere exact 4
        end)

        test.case("plasa urmatoare apare abia cand cea dinainte e la nivelul cerut", function()
            -- Owner-ul, in Studio: quest-ul cerea sa urce First Net, dar a doua plasa se putea deja
            -- cumpara. Acum lumea asteapta nivelul -- aceeasi cifra din quest-ul `net_two`.
            local bought = withCrew({})
            local low = TycoonMath.padStatuses(bought, nil, { first_net = 1 })
            check.equal(low.second_net, "outline") -- se vede ce urmeaza, dar nu se poate lua
            local ready =
                TycoonMath.padStatuses(bought, nil, { first_net = TycoonConfig.PREV_NET_LEVEL })
            check.equal(ready.second_net, "available")

            -- si mai departe, pe ULTIMA plasa detinuta, nu pe prima
            local three = withCrew({ second_net = true, third_net = true })
            local stale =
                TycoonMath.padStatuses(three, nil, { first_net = 9, second_net = 9, third_net = 1 })
            check.is_true(stale.far_lane_net ~= "available")
            local fresh =
                TycoonMath.padStatuses(three, nil, { first_net = 1, second_net = 1, third_net = 2 })
            check.equal(fresh.far_lane_net, "available")
        end)

        test.case("fara tabel de niveluri, poarta nu blocheaza nimic", function()
            -- Un apelant care nu stie de niveluri (erele fara niveluri, testele vechi) nu trebuie sa
            -- vada lumea incremenita -- ar fi un blocaj fara nicio eroare care sa spuna de ce.
            local statuses = TycoonMath.padStatuses(withCrew({}))
            check.equal(statuses.second_net, "available")
        end)

        test.case("clopotul cere TOT restul erei cumparat", function()
            local bought = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 and p.id ~= "landing_bell" and p.id ~= "workshop" then
                    bought[p.id] = true
                end
            end
            local statuses = TycoonMath.padStatuses(bought)
            check.equal(statuses.workshop, "available")
            check.equal(statuses.landing_bell, "outline") -- se vede, dar nu se poate lua
            check.equal(statuses.sawmill, nil) -- era 2 nu e live
        end)

        test.case("clopotul devine available cand chiar e ultimul", function()
            local bought = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 and p.id ~= "landing_bell" then
                    bought[p.id] = true
                end
            end
            local statuses = TycoonMath.padStatuses(bought)
            check.equal(statuses.landing_bell, "available")
        end)

        test.case("dupa clopot se deschide era urmatoare", function()
            local allLive: { TycoonConfig.Pad } = {}
            for _, p in TycoonConfig.PADS do
                local copy = table.clone(p)
                copy.live = true
                table.insert(allLive, copy)
            end
            local bought = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    bought[p.id] = true
                end
            end
            local statuses = TycoonMath.padStatuses(bought, allLive)
            -- erele 2-4 n-au inca `needs`, deci merg pe ordinea din tabel: toate eligibile. Prima
            -- platforma a Erei 2 se cauta, nu se scrie de mana -- era `sawmill`, care s-a mutat [D48].
            local firstEra2: string? = nil
            for _, p in TycoonConfig.PADS do
                if p.era == 2 then
                    firstEra2 = p.id
                    break
                end
            end
            check.equal(statuses[firstEra2 :: string], "available")
        end)

        test.case("toate platformele cumparate: rezultat gol, fara eroare", function()
            local bought = {}
            for _, p in TycoonConfig.PADS do
                bought[p.id] = true
            end
            local statuses = TycoonMath.padStatuses(bought)
            local n = 0
            for _ in statuses do
                n += 1
            end
            check.equal(n, #TycoonConfig.PADS)
        end)
    end)

    test.suite("TycoonMath - prinderea prezisa (D2)", function()
        test.case("pickGood: plasele de lemn prind lemn, cea din larg scrap [D55]", function()
            -- lemn: 0,95 driftwood, apoi 0,05 finds; scrap: 0,95 scrap, apoi finds. Niciun alt bun.
            check.equal(TycoonMath.pickGood(0.0, "wood"), "driftwood")
            check.equal(TycoonMath.pickGood(0.9499, "wood"), "driftwood")
            check.equal(TycoonMath.pickGood(0.951, "wood"), "named")
            check.equal(TycoonMath.pickGood(0.0, "scrap"), "scrap")
            check.equal(TycoonMath.pickGood(0.9499, "scrap"), "scrap")
            check.equal(TycoonMath.pickGood(0.9999, "scrap"), "named")
            -- un fel necunoscut cade pe lemn, nu crapa
            check.equal(TycoonMath.pickGood(0.2, "nope"), "driftwood")
        end)

        test.case("pickGood: frecventele pe 20.000 de trageri urmeaza CATCH", function()
            for kind, parts in TycoonConfig.CATCH do
                local counts: { [string]: number } = {}
                local n = 20000
                for i = 0, n - 1 do
                    local g = TycoonMath.pickGood((i + 0.5) / n, kind)
                    counts[g] = (counts[g] or 0) + 1
                end
                for _, part in parts do
                    check.is_true(math.abs((counts[part.id] or 0) / n - part.share) < 0.001)
                end
            end
        end)

        test.case("doar plasa a cincea e plasa de scrap [D55]", function()
            local scrapNets = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 and TycoonMath.netKind(p) == "scrap" then
                    table.insert(scrapNets, p.id)
                end
            end
            check.equal(#scrapNets, 1)
            check.equal(scrapNets[1], "fifth_net")
        end)

        test.case("catchSeed e determinist si diferit pe plasa si pe prindere", function()
            local a = TycoonMath.catchSeed(123, 1, 0)
            check.equal(a, TycoonMath.catchSeed(123, 1, 0))
            check.is_true(a ~= TycoonMath.catchSeed(123, 1, 1))
            check.is_true(a ~= TycoonMath.catchSeed(123, 2, 0))
        end)
    end)

    test.suite("TycoonMath - prima plasa grabita (D51)", function()
        test.case("doar prima plasa, doar pana la prag", function()
            local boost = TycoonConfig.FIRST_CATCH
            check.equal(TycoonMath.catchBoost(boost.pad, 0), boost.speed)
            check.equal(TycoonMath.catchBoost(boost.pad, boost.untilCollected - 1), boost.speed)
            check.equal(TycoonMath.catchBoost(boost.pad, boost.untilCollected), 1)
            check.equal(TycoonMath.catchBoost("second_net", 0), 1)
            -- tine exact cat cere primul quest de colectare: o plasa plina
            local QuestConfig = require("../src/Shared/Config/QuestConfig")
            check.equal(QuestConfig.byId.collect_once.goal, boost.untilCollected)
            check.equal(boost.untilCollected, TycoonConfig.NET_CAPACITY)
        end)

        test.case("cat e grabita, prima plasa nu se goleste decat plina", function()
            local boost = TycoonConfig.FIRST_CATCH
            check.is_true(TycoonMath.collectLocked(boost.pad, 0, 8, 12))
            check.is_false(TycoonMath.collectLocked(boost.pad, 0, 12, 12))
            -- dupa primii 12 colectati, sau pe alta plasa, se goleste oricand
            check.is_false(TycoonMath.collectLocked(boost.pad, boost.untilCollected, 3, 12))
            check.is_false(TycoonMath.collectLocked("second_net", 0, 3, 12))
        end)
    end)

    test.suite("TycoonMath - ajutoare live", function()
        test.case("sackCapacity urmeaza flag-ul sackBig", function()
            local s = TycoonMath.newState()
            check.equal(TycoonMath.sackCapacity(s), TycoonConfig.SACK_CAPACITY)
            s.sackBig = true
            check.equal(TycoonMath.sackCapacity(s), TycoonConfig.SACK_BIG_CAPACITY)
        end)

        test.case("netInterval = 1 / (rate * rateMult)", function()
            local s = TycoonMath.newState()
            check.is_true(math.abs(TycoonMath.netInterval(0.33, s) - 1 / 0.33) < 1e-12)
            s.rateMult = 1.3
            check.is_true(math.abs(TycoonMath.netInterval(0.33, s) - 1 / (0.33 * 1.3)) < 1e-12)
        end)

        test.case(
            "sellMultiplier combina priceMult, dockhand, bells, index si renasteri",
            function()
                local s = TycoonMath.newState()
                s.priceMult = 1.5
                s.dockhand = true
                s.bells = 1.1
                local expected = 1.5 * 1.2 * 1.1 * (1 + 0.01 * 10) * (1 + 0.5 * 2)
                check.is_true(math.abs(TycoonMath.sellMultiplier(s, 10, 2) - expected) < 1e-9)
            end
        )

        test.case("itemValue: bunuri brute dupa GOODS, named dupa tier x namedMult", function()
            local s = TycoonMath.newState()
            check.equal(TycoonMath.itemValue("driftwood", nil, s), 1.0)
            check.equal(TycoonMath.itemValue("scrap", nil, s), 3.0)
            check.equal(TycoonMath.itemValue("iron", nil, s), 3.0)
            check.equal(TycoonMath.itemValue("named", "rare", s), 22)
            check.equal(TycoonMath.itemValue("named", nil, s), 14) -- fallback fara tier
            s.namedMult = 1.5
            check.is_true(math.abs(TycoonMath.itemValue("named", "rare", s) - 33) < 1e-9)
        end)

        test.case(
            "[D67, audit] formatNumberUp: cat mai lipseste, rotunjit in sus la cifra aratata",
            function()
                check.equal(TycoonMath.formatNumberUp(45.2), "46")
                check.equal(TycoonMath.formatNumberUp(1099), "1.1K")
                check.equal(TycoonMath.formatNumberUp(109.38e9), "110B")
                check.equal(TycoonMath.formatNumberUp(119.7e9), "120B")
                check.equal(TycoonMath.formatNumberUp(1.201e6), "1.21M")
                check.equal(TycoonMath.formatNumberUp(999.5e3), "1M") -- nu "1000K"
                check.equal(TycoonMath.formatNumberUp(120e9), "120B") -- exact: nu sare la urmatoarea cifra
                check.equal(TycoonMath.formatNumberUp(0), "0")
                check.equal(TycoonMath.formatNumberUp(119e9 + 1), "120B") -- o moneda peste o cifra
                check.equal(TycoonMath.formatNumberUp(119e12 + 1), "120T")
                check.equal(TycoonMath.formatNumberUp(9995), "10K")
                check.equal(TycoonMath.formatNumberUp(999.6e15), "1Qi")
                -- si niciodata mai putin decat lipseste: citit inapoi, textul acopera suma
                local mult = { K = 1e3, M = 1e6, B = 1e9, T = 1e12, Qa = 1e15, Qi = 1e18 }
                local seed = 12345
                for _ = 1, 20000 do
                    seed = (seed * 1103515245 + 12345) % 2147483648
                    local n = (seed / 2147483648) * 10 ^ (seed % 19)
                    local s = TycoonMath.formatNumberUp(n)
                    check.is_true(#s <= 5)
                    local num, suffix = string.match(s, "^([%d%.]+)(%a*)$")
                    local factor = if suffix == "" then 1 else mult[suffix :: string]
                    local shown = (tonumber(num) :: number) * factor
                    if shown < math.ceil(n) * (1 - 1e-12) then
                        error(`formatNumberUp({n}) = {s}, sub suma lipsa`)
                    end
                end
            end
        )

        test.case("formatNumber: floor, plain sub 1000, K/M/B ca big()", function()
            check.equal(TycoonMath.formatNumber(0), "0")
            check.equal(TycoonMath.formatNumber(950.7), "950")
            check.equal(TycoonMath.formatNumber(999), "999")
            check.equal(TycoonMath.formatNumber(1000), "1K")
            check.equal(TycoonMath.formatNumber(1200), "1.2K")
            check.equal(TycoonMath.formatNumber(12000), "12K")
            check.equal(TycoonMath.formatNumber(1500000), "1.5M")
            -- [D63] trei cifre, cel mult cinci caractere, taiat (nu rotunjit): contorul nu arata mai mult decat ai
            check.equal(TycoonMath.formatNumber(1250), "1.25K")
            check.equal(TycoonMath.formatNumber(12345), "12.3K")
            check.equal(TycoonMath.formatNumber(232954), "232K")
            check.equal(TycoonMath.formatNumber(999999), "999K")
            check.equal(TycoonMath.formatNumber(1999999), "1.99M")
            -- [D66] Moara e pe scara x3000: trilioane si mai departe, tot in cinci caractere
            check.equal(TycoonMath.formatNumber(1.5e12), "1.5T")
            check.equal(TycoonMath.formatNumber(2.5e15), "2.5Qa")
            check.equal(TycoonMath.formatNumber(1.25e15), "1.2Qa")
            check.equal(TycoonMath.formatNumber(4.2e19), "42Qi")
            for _, n in
                {
                    1000,
                    9999,
                    10000,
                    99999,
                    100000,
                    999999,
                    1e6,
                    5.5e7,
                    9.99e8,
                    1e9,
                    7.25e10,
                    9.99e11,
                    1.23e13,
                    9.99e14,
                    1.23e15,
                    9.99e17,
                    9.99e20,
                }
            do
                check.is_true(#TycoonMath.formatNumber(n) <= 5)
            end
        end)

        test.case("formatRate: sub 10 cu o zecimala, altfel ca formatNumber", function()
            check.equal(TycoonMath.formatRate(0.39963), "0.4")
            check.equal(TycoonMath.formatRate(5), "5.0")
            check.equal(TycoonMath.formatRate(15), "15")
        end)

        test.case("formatPerMinute: pe minut, o zecimala sub 100, rotunjit [D52]", function()
            check.equal(TycoonMath.formatPerMinute(0.33), "19.8") -- prima plasa, nivel 1
            check.equal(TycoonMath.formatPerMinute(0.33 * 1.03), "20.4") -- un nivel: +3% se vede
            check.equal(TycoonMath.formatPerMinute(0.5), "30") -- fara ".0" in coada
            check.equal(TycoonMath.formatPerMinute(1.6663), "100") -- 99.98 urca la 100, nu "100.0"
            check.equal(TycoonMath.formatPerMinute(4), "240")
            check.equal(TycoonMath.formatPerMinute(40), "2.4K")
            check.equal(TycoonMath.formatPerMinute(0), "0")
            check.equal(TycoonMath.formatPerMinute(-1), "0")
            check.equal(TycoonMath.formatPerMinute(math.huge), "0")
        end)
    end)

    test.suite("TycoonMath.netTick [D53]", function()
        test.case("inainte de moment: nimic, ceasul pe loc", function()
            local n, nextAt = TycoonMath.netTick(100, 3, 99, 0, 12)
            check.equal(n, 0)
            check.equal(nextAt, 100)
        end)

        test.case("un moment trecut, cu loc: o prindere, ceasul un pas", function()
            local n, nextAt = TycoonMath.netTick(100, 3, 100, 0, 12)
            check.equal(n, 1)
            check.equal(nextAt, 103)
        end)

        test.case("restante cu loc: toate, iar ceasul ramane in fata lui now", function()
            local n, nextAt = TycoonMath.netTick(100, 3, 109.5, 0, 12)
            check.equal(n, 4)
            check.equal(nextAt, 112)
        end)

        test.case(
            "se umple pe drum: prinde cat incape, apoi sare la primul moment de dupa now",
            function()
                local n, nextAt = TycoonMath.netTick(100, 3, 109.5, 10, 12)
                check.equal(n, 2)
                check.equal(nextAt, 112)
            end
        )

        test.case("plina ore intregi: nicio prindere, ceasul ramane in ritm", function()
            local now = 100 + 5 * 3600 + 1
            local n, nextAt = TycoonMath.netTick(100, 3, now, 12, 12)
            check.equal(n, 0)
            check.is_true(nextAt > now and nextAt - now <= 3)
            check.equal((nextAt - 100) % 3, 0)
        end)

        test.case(
            "plina ore intregi, apoi golita: cel mult o prindere pe moment, fara rafala",
            function()
                local now = 100 + 5 * 3600 + 1
                local _, nextAt = TycoonMath.netTick(100, 3, now, 12, 12)
                -- golita chiar acum: pana la momentul urmator nu prinde nimic
                local early = TycoonMath.netTick(nextAt, 3, now + 0.01, 0, 12)
                check.equal(early, 0)
                local atSlot, after = TycoonMath.netTick(nextAt, 3, nextAt, 0, 12)
                check.equal(atSlot, 1)
                check.equal(after, nextAt + 3)
            end
        )

        test.case(
            "nivel urcat cat e plina: sare in pasii noului interval, fara prinderi",
            function()
                local _, nextAt = TycoonMath.netTick(100, 3, 150, 12, 12)
                check.equal(nextAt, 151)
                local n, later = TycoonMath.netTick(nextAt, 2, 155, 12, 12)
                check.equal(n, 0)
                check.equal(later, 157)
            end
        )

        test.case("interval nul sau nedefinit: nu prinde nimic si nu strica ceasul", function()
            local n, nextAt = TycoonMath.netTick(100, 0, 500, 0, 12)
            check.equal(n, 0)
            check.equal(nextAt, 100)
            local m = TycoonMath.netTick(100, 0 / 0, 500, 0, 12)
            check.equal(m, 0)
        end)
    end)

    test.suite("TycoonMath.padBlocker + Strings.padNeeds [D53]", function()
        local Strings = require("../src/Shared/Config/Strings")
        local function needs(
            id: string,
            bought: { [string]: boolean },
            levels: { [string]: number }?
        ): string?
            local b = TycoonMath.padBlocker(TycoonConfig.byId[id], bought, levels)
            return if b ~= nil then Strings.padNeeds(b) else nil
        end

        test.case("profil nou: fiecare platforma a Erei 1 spune ce ii lipseste", function()
            local want = {
                first_net = nil, -- se ia pe loc
                first_runner = "Cast your first net",
                hire_porter = "Hire a Collector first",
                hire_sawyer = "Hire a Porter first",
                hire_hauler = "Hire a Sawyer first",
                dock_trader = "Hire a Hauler first",
                second_net = "Hire an Innkeeper first",
                third_net = "Cast the Second Net first",
                bigger_sack = "Cast the Second Net first",
                far_lane_net = "Cast the Third Net first",
                workshop = "Cast the Fourth Net first",
                -- [D56] intai conditia `after`: plasa a cincea cere Forge; shed-ul cere plasa a cincea (prin
                -- `netsOwned`, deci "Cast"), oamenii fierului pe cel dinainte
                fifth_net = "Build the Forge first",
                scrap_shed = "Cast the Fifth Net first",
                hire_scrap_collector = "Build the Scrap Shed first",
                hire_scrap_porter = "Hire a Scrap Collector first",
                hire_smelter = "Hire a Scrap Porter first",
                hire_iron_hauler = "Hire a Smelter first",
                landing_bell = "Rebuild everything else on The Landing first",
            }
            local seen = 0
            for _, p in TycoonConfig.PADS do
                if p.era == 1 then
                    seen += 1
                    check.equal(needs(p.id, {}, {}), want[p.id])
                end
            end
            check.equal(seen, 18)
        end)

        test.case("[D65] Era 2: clopotul se trage, iar cartierul isi spune numele", function()
            local era1: { [string]: boolean } = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 and p.id ~= "landing_bell" then
                    era1[p.id] = true
                end
            end
            -- roata de apa cere clopotul Erei 1: un clopot se trage, nu se construieste
            check.equal(needs("water_wheel", era1, {}), "Ring the Landing Bell first")
            era1.landing_bell = true
            check.equal(needs("water_wheel", era1, {}), nil)
            check.equal(needs("mill_bell", era1, {}), "Rebuild everything else on The Mill first")
            -- fiecare platforma a Erei 2 are ce spune cat e incuiata (sau e chiar de luat)
            for _, p in TycoonConfig.PADS do
                if p.era == 2 and p.id ~= "water_wheel" then
                    check.is_true(needs(p.id, era1, {}) ~= nil)
                end
            end
        end)

        test.case("doua conditii: intai omul, apoi nivelul plasei", function()
            local crew = {
                first_net = true,
                first_runner = true,
                hire_porter = true,
                hire_sawyer = true,
                hire_hauler = true,
            }
            check.equal(needs("second_net", crew, { first_net = 1 }), "Hire an Innkeeper first")
            crew.dock_trader = true
            check.equal(
                needs("second_net", crew, { first_net = 1 }),
                "Upgrade First Net to level 2 first"
            )
            check.equal(needs("second_net", crew, { first_net = 2 }), nil)
        end)

        test.case(
            "textul spune exact ce verifica jocul: fara conditie, platforma e cumparabila",
            function()
                -- orice platforma fara blocaj trebuie sa fie chiar "available" (sau cumparata)
                local bought = { first_net = true, first_runner = true }
                local levels = { first_net = 1 }
                local statuses = TycoonMath.padStatuses(bought, nil, levels)
                for _, p in TycoonConfig.PADS do
                    if p.era == 1 and not bought[p.id] then
                        local blocked = TycoonMath.padBlocker(p, bought, levels) ~= nil
                        check.equal(blocked, statuses[p.id] ~= "available")
                    end
                end
            end
        )

        test.case("cumparata: nimic de spus", function()
            check.equal(needs("first_net", { first_net = true }, {}), nil)
        end)
    end)
end
