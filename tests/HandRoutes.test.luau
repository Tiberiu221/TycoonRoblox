-- Rutele oamenilor si regulile meseriilor [D49]. Serverul muta marfa pe aceleasi rute pe care
-- clientul deseneaza oamenii mergand: daca s-ar desparti, ce vezi n-ar mai fi ce se intampla.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local StationConfig = require("../src/Shared/Config/StationConfig")
local HandRoutes = require("../src/Shared/Modules/HandRoutes")
local CrewMath = require("../src/Shared/Modules/CrewMath")

local function era1Nets(): { string }
    local ids = {}
    for _, p in TycoonConfig.PADS do
        if p.era == 1 then
            for _, e in p.effects do
                if e.kind == "net" then
                    table.insert(ids, p.id)
                    break
                end
            end
        end
    end
    return ids
end

return function()
    test.suite("HandRoutes", function()
        test.case("un singur Collector trece pe la TOATE plasele de lemn", function()
            -- in D46 un alergator avea doar primele trei; debitul unei meserii nu tine de numarul plaselor.
            -- [D56] Plasa de scrap e a Scrap Collector-ului, nu a lui.
            local nets = era1Nets()
            check.equal(#nets, 5)
            local route = HandRoutes.routeFor("collector", 1, 1, nets) :: HandRoutes.Route
            check.equal(#route.stops, 4)
            check.equal(route.stops[1].padId, "first_net")
            for _, st in route.stops do
                check.is_true(st.padId ~= HandRoutes.SCRAP_NET)
            end
            check.equal(route.endpoint.x, TycoonConfig.STORAGE_STAND.x)
            check.equal(route.endpoint.y, TycoonConfig.STORAGE_STAND.y)
        end)

        test.case(
            "doi Collectori isi impart plasele de lemn pe bucati de mal, fara sa se suprapuna",
            function()
                local nets = era1Nets()
                local wood = HandRoutes.collectorNets(nets, 1, 1)
                check.equal(#wood, 4)
                local a = HandRoutes.collectorNets(nets, 1, 2)
                local b = HandRoutes.collectorNets(nets, 2, 2)
                check.equal(#a + #b, #wood)
                check.equal(a[#a], wood[#a])
                check.equal(b[1], wood[#a + 1])
            end
        )

        test.case("Porter-ul si Hauler-ul fac naveta, cu exact o oprire", function()
            local porter = HandRoutes.routeFor("porter", 1, 1, {}) :: HandRoutes.Route
            check.equal(#porter.stops, 1)
            check.equal(porter.stops[1].padId, HandRoutes.STORAGE_STOP)
            check.equal(porter.endpoint.x, TycoonConfig.SAWMILL_IN.x)
            check.equal(porter.endpoint.y, TycoonConfig.SAWMILL_IN.y)
            local hauler = HandRoutes.routeFor("hauler", 2, 2, {}) :: HandRoutes.Route
            check.equal(#hauler.stops, 1)
            check.equal(hauler.stops[1].padId, HandRoutes.PLANKS_STOP)
            check.equal(hauler.stops[1].x, TycoonConfig.SAWMILL_OUT.x)
            check.equal(hauler.endpoint.x, TycoonConfig.DOCK.x)
            check.is_true(HandRoutes.cycleFor("porter", 1, 1, {}).duration > 0)
            check.is_true(HandRoutes.cycleFor("hauler", 1, 1, {}).duration > 0)
        end)

        test.case(
            "Sawyer-ul, Smelter-ul si Negustorul stau, iar al doilea nu sta peste primul",
            function()
                check.is_true(HandRoutes.routeFor("sawyer", 1, 1, {}) == nil)
                check.is_true(HandRoutes.routeFor("smelter", 1, 1, {}) == nil)
                check.equal(HandRoutes.cycleFor("trader", 1, 1, {}).duration, 0)
                for _, role in { "sawyer", "trader", "smelter" } do
                    local first = HandRoutes.standFor(role, 1) :: any
                    local second = HandRoutes.standFor(role, 2) :: any
                    check.not_nil(first)
                    check.is_true(
                        math.abs(first.x - second.x) >= 48 or math.abs(first.y - second.y) >= 72
                    )
                end
                check.is_true(HandRoutes.standFor("porter", 1) == nil)
            end
        )

        test.case("ce duce un om pe drum, impartit la drum, e chiar debitul meseriei", function()
            -- ce se vede mergand = cifra din meniu [D40]
            local ChainMath = require("../src/Shared/Modules/ChainMath")
            for _, role in
                { "collector", "porter", "hauler", "scrapCollector", "scrapPorter", "ironHauler" }
            do
                for tier = 1, StationConfig.TIER_MAX do
                    local rate = ChainMath.walkerRate(role, { count = 1, tier = tier })
                    local cycle = HandRoutes.cycleFor(role, 1, 1, era1Nets())
                    local load = HandRoutes.loadFor(rate, cycle.duration)
                    check.is_true(
                        math.abs(load / cycle.duration - rate) <= 0.5 / cycle.duration + 1e-9
                    )
                end
            end
            check.equal(HandRoutes.loadFor(0, 10), 0)
            check.equal(HandRoutes.loadFor(0.01, 1), 1)
        end)

        test.case("oamenii merg pe drumuri, nu peste cladiri", function()
            -- [D50] Fiecare picior de mers pleaca si ajunge pe un drum, in afara intrarii (de la usa
            -- la drum) si iesirii (de pe drum la oprire): exact ce se vede pe mal.
            local rects = { TycoonConfig.DECK }
            for _, r in TycoonConfig.ROADS do
                table.insert(rects, r)
            end
            local function onRoad(p): boolean
                for _, r in rects do
                    if
                        p.x >= r.x0 - 0.5
                        and p.x <= r.x1 + 0.5
                        and p.y >= r.y0 - 0.5
                        and p.y <= r.y1 + 0.5
                    then
                        return true
                    end
                end
                return false
            end
            for _, role in
                { "collector", "porter", "hauler", "scrapCollector", "scrapPorter", "ironHauler" }
            do
                local route = HandRoutes.routeFor(role, 1, 1, era1Nets()) :: HandRoutes.Route
                local points = {}
                for _, s in route.stops do
                    for _, p in s.via or {} do
                        table.insert(points, p)
                    end
                end
                for _, p in route.returnVia or {} do
                    table.insert(points, p)
                end
                for _, p in points do
                    check.is_true(onRoad(p))
                end
                local cycle = HandRoutes.cycleFor(role, 1, 1, era1Nets())
                print(`  {role}: {math.floor(cycle.duration * 10 + 0.5) / 10} s pe ciclu`)
            end
            -- Collector-ul chiar ocoleste: pe drum e mai lung decat in linie dreapta
            local HandMath = require("../src/Shared/Modules/HandMath")
            local route = HandRoutes.routeFor("collector", 1, 1, era1Nets()) :: HandRoutes.Route
            local bare = table.clone(route.stops)
            for i, s in bare do
                bare[i] = { x = s.x, y = s.y, padId = s.padId }
            end
            local direct = HandMath.cycle(bare, route.endpoint, TycoonConfig.RUNNER)
            check.is_true(
                HandRoutes.cycleFor("collector", 1, 1, era1Nets()).duration > direct.duration
            )
        end)

        test.case("ciclul oricarui Collector e sub cat tine o plasa", function()
            -- Daca ar trece mai rar, plasele lui s-ar umple si ar sta pline: ar prinde sub cifra din
            -- meniu, iar Collector-ul ar duce mai putin decat promite [D49]. [D56] Si Scrap Collector-ul.
            local all = era1Nets()
            for owned = 1, #all do
                local nets = table.move(all, 1, owned, 1, {})
                for count = 1, StationConfig.MAX_PEOPLE do
                    for index = 1, count do
                        for _, role in { "collector", "scrapCollector" } do
                            local cycle = HandRoutes.cycleFor(role, index, count, nets)
                            check.is_true(cycle.duration <= TycoonConfig.NET_HOLD_SECONDS)
                        end
                    end
                end
            end
        end)
    end)

    test.suite("HandRoutes - linia fierului [D56]", function()
        test.case("plasa de scrap e ultima plasa a Erei 1", function()
            local nets = era1Nets()
            check.equal(HandRoutes.SCRAP_NET, nets[#nets])
        end)

        test.case("Scrap Collector-ul goleste doar plasa de scrap si lasa la shed", function()
            local nets = era1Nets()
            local route = HandRoutes.routeFor("scrapCollector", 1, 1, nets) :: HandRoutes.Route
            check.equal(#route.stops, 1)
            check.equal(route.stops[1].padId, HandRoutes.SCRAP_NET)
            check.equal(route.endpoint.x, TycoonConfig.SCRAP_SHED_STAND.x)
            check.equal(route.endpoint.y, TycoonConfig.SCRAP_SHED_STAND.y)
            check.equal(route.face, "right") -- [D57] gramada shed-ului e in dreapta aleii
            check.equal(HandRoutes.endPlace("scrapCollector"), "shed")
            -- fara plasa de scrap n-are pe unde merge
            local woodOnly = table.move(nets, 1, 4, 1, {})
            check.equal(HandRoutes.cycleFor("scrapCollector", 1, 1, woodOnly).duration, 0)
            -- doi oameni pe o singura plasa: trec amandoi pe la ea
            check.equal(#HandRoutes.collectorNets(nets, 2, 2, "scrapCollector"), 1)
        end)

        test.case("Scrap Porter-ul: shed -> forja; Iron Hauler-ul: fier -> taverna", function()
            local porter = HandRoutes.routeFor("scrapPorter", 1, 1, {}) :: HandRoutes.Route
            check.equal(#porter.stops, 1)
            check.equal(porter.stops[1].padId, HandRoutes.SHED_STOP)
            check.equal(porter.endpoint.x, TycoonConfig.FORGE_IN.x)
            check.equal(HandRoutes.endPlace("scrapPorter"), "forge")
            local hauler = HandRoutes.routeFor("ironHauler", 1, 1, {}) :: HandRoutes.Route
            check.equal(#hauler.stops, 1)
            check.equal(hauler.stops[1].padId, HandRoutes.IRON_STOP)
            check.equal(hauler.stops[1].x, TycoonConfig.FORGE_OUT.x)
            check.equal(hauler.endpoint.x, TycoonConfig.DOCK.x)
            check.equal(HandRoutes.endPlace("ironHauler"), "dock")
            -- oamenii lemnului nu mai trec pe la shed sau pe la forja
            for _, role in { "collector", "porter", "hauler" } do
                local route = HandRoutes.routeFor(role, 1, 1, era1Nets()) :: HandRoutes.Route
                for _, st in route.stops do
                    check.is_true(
                        st.padId ~= HandRoutes.SHED_STOP and st.padId ~= HandRoutes.IRON_STOP
                    )
                end
            end
            check.equal(HandRoutes.endPlace("porter"), "sawmill")
        end)

        test.case(
            "la fiecare oprire si la capat, omul sta cu fata spre gramada lui [D57]",
            function()
                -- Cand s-a mutat satul, shed-ul a trecut in dreapta aleii: omul ar fi rasturnat roaba spre iarba.
                -- Regula, pentru orice asezare: "right" = gramada e in dreapta locului, "left" = in stanga.
                local P = TycoonConfig.PILES
                local pileAt = {
                    [HandRoutes.STORAGE_STOP] = P.storage,
                    [HandRoutes.PLANKS_STOP] = P.sawmillOut,
                    [HandRoutes.SHED_STOP] = P.shed,
                    [HandRoutes.IRON_STOP] = P.forgeOut,
                }
                local endPile = {
                    collector = P.storage,
                    porter = P.sawmillIn,
                    hauler = P.tavern,
                    scrapCollector = P.shed,
                    scrapPorter = P.forgeIn,
                    ironHauler = P.tavern,
                }
                local function facesPile(
                    at: { x: number },
                    face: string?,
                    pile: { x: number }
                ): boolean
                    if face == "right" then
                        return pile.x > at.x
                    elseif face == "left" then
                        return pile.x < at.x
                    end
                    return true
                end
                for role, pile in endPile do
                    local route = HandRoutes.routeFor(role, 1, 1, era1Nets()) :: HandRoutes.Route
                    check.is_true(facesPile(route.endpoint, route.face, pile))
                    for _, s in route.stops do
                        local stopPile = pileAt[s.padId]
                        if stopPile ~= nil then
                            check.is_true(facesPile(s, s.face, stopPile))
                        end
                    end
                end
            end
        )

        test.case("la oprire ia, la capat rastoarna, iar in pauza omul sta spre gramada", function()
            local HandMath = require("../src/Shared/Modules/HandMath")
            local cycle = HandRoutes.cycleFor("scrapPorter", 1, 1, {})
            local kinds = {}
            for _, ev in HandMath.eventsBetween(cycle, 0, 0, cycle.duration) do
                table.insert(kinds, `{ev.kind}:{ev.padId or "-"}`)
            end
            check.equal(table.concat(kinds, " "), "collect:shed sell:-")
            for _, leg in cycle.legs do
                if leg.kind ~= "walk" then
                    local _, _, state, facing = HandMath.sampleAt(cycle, (leg.t0 + leg.t1) / 2)
                    check.equal(state, leg.kind)
                    check.equal(facing, leg.face or "up")
                end
            end
        end)
    end)

    test.suite("CrewMath", function()
        test.case("cheia primului om e platforma lui, a celui de-al doilea are sufix", function()
            check.equal(CrewMath.personKey("collector", 1), "first_runner")
            check.equal(CrewMath.personKey("collector", 2), "first_runner_2")
            check.equal(CrewMath.personKey("trader", 1), "dock_trader")
            check.equal(CrewMath.indexOf("first_runner"), 1)
            check.equal(CrewMath.indexOf("hire_sawyer_2"), 2)
            check.is_true(CrewMath.personKey("nobody", 1) == nil)
        end)

        test.case(
            "meseriile se citesc din profil, iar o treapta stricata nu inventeaza debit",
            function()
                local crews = CrewMath.fromProfile({
                    first_runner = { role = "collector" },
                    first_runner_2 = { role = "collector" },
                    hire_sawyer = { role = "sawyer" },
                    stranger = { role = "juggler" },
                }, {
                    collector = { tier = 4 },
                    sawyer = { tier = 99 },
                    porter = { tier = 0 / 0 },
                })
                check.equal(crews.collector.count, 2)
                check.equal(crews.collector.tier, 4)
                check.equal(crews.sawyer.tier, StationConfig.TIER_MAX)
                check.equal(crews.porter.count, 0)
                check.equal(crews.porter.tier, 1)
                check.equal(crews.trader.count, 0)
            end
        )

        test.case("al doilea om: peste un prim om, de la treapta ceruta, cel mult doi", function()
            local ok, why = CrewMath.canHireSecond({ count = 0, tier = 5 })
            check.is_false(ok)
            check.equal(why, "no_person")
            ok, why = CrewMath.canHireSecond({ count = 1, tier = StationConfig.SECOND_AT_TIER - 1 })
            check.equal(why, "tier")
            ok = CrewMath.canHireSecond({ count = 1, tier = StationConfig.SECOND_AT_TIER })
            check.is_true(ok)
            ok, why = CrewMath.canHireSecond({ count = StationConfig.MAX_PEOPLE, tier = 5 })
            check.equal(why, "max_people")
        end)

        test.case(
            "treapta: nu fara om, nu peste maxim; echipaj la maxim = doi oameni la treapta 5",
            function()
                check.equal(
                    select(2, CrewMath.canUpgradeTier({ count = 0, tier = 1 })),
                    "no_person"
                )
                check.equal(
                    select(2, CrewMath.canUpgradeTier({ count = 1, tier = StationConfig.TIER_MAX })),
                    "max_tier"
                )
                check.is_true(CrewMath.canUpgradeTier({ count = 1, tier = 2 }))
                check.equal(CrewMath.tierPrice({ count = 1, tier = 2 }), 75)
                check.is_true(CrewMath.maxed({ count = 2, tier = 5 }))
                check.is_false(CrewMath.maxed({ count = 1, tier = 5 }))
                check.equal(CrewMath.secondPrice("porter"), TycoonConfig.CREWS.porter.secondPrice)
                -- [D65] oamenii Erei 2 platesc treptele de ERA2_MULT ori mai scump
                check.equal(
                    CrewMath.tierPrice({ count = 1, tier = 2 }, "founder"),
                    75 * StationConfig.ERA2_MULT
                )
                check.equal(CrewMath.tierPrice({ count = 1, tier = 2 }, "sawyer"), 75)
            end
        )
    end)

    -- [D65] Drumurile oamenilor Morii ies din aceleasi tabele ca ale Erei 1: nicio ramura pe nume de meserie.
    test.suite("HandRoutes - Era 2, The Mill [D65]", function()
        local FlowConfig = require("../src/Shared/Config/FlowConfig")
        local P = TycoonConfig.LINE_PLACES
        local millNets = { "sixth_net", "seventh_net", "eighth_net", "ninth_net" }
        local allNets = { "first_net", "second_net", "third_net", "far_lane_net", "fifth_net" }
        for _, id in millNets do
            table.insert(allNets, id)
        end
        table.insert(allNets, "tenth_net")

        test.case("fiecare meserie isi stie treaba, linia si locul unde lasa", function()
            local want = {
                collector = { "collect", "wood", "storage" },
                porter = { "port", "wood", "sawmill" },
                hauler = { "haul", "wood", "dock" },
                scrapCollector = { "collect", "iron", "shed" },
                ironHauler = { "haul", "iron", "dock" },
                millCollector = { "collect", "parts", "millStore" },
                millPorter = { "port", "parts", "foundry" },
                partsHauler = { "haul", "parts", "market" },
                oreCollector = { "collect", "copper", "oreShed" },
                orePorter = { "port", "copper", "furnace" },
                copperHauler = { "haul", "copper", "market" },
            }
            for role, w in want do
                local job = HandRoutes.jobOf(role)
                check.not_nil(job)
                check.equal((job :: any).job, w[1])
                check.equal((job :: any).line, w[2])
                check.equal(HandRoutes.endPlace(role), w[3])
                check.is_true(HandRoutes.isWalker(role))
            end
            for _, role in { "sawyer", "smelter", "trader", "founder", "coppersmith", "merchant" } do
                check.is_false(HandRoutes.isWalker(role))
                check.not_nil(HandRoutes.standFor(role, 1))
            end
            check.equal(HandRoutes.netKindOf("millCollector"), "mill")
            check.equal(HandRoutes.netKindOf("oreCollector"), "ore")
            check.equal(HandRoutes.netKindOf("millPorter"), nil)
        end)

        test.case("Mill Collector-ul goleste doar plasele Morii si lasa la magazia ei", function()
            local route = HandRoutes.routeFor("millCollector", 1, 1, allNets) :: HandRoutes.Route
            check.equal(#route.stops, 4)
            for i, st in route.stops do
                check.equal(st.padId, millNets[i])
            end
            check.equal(route.endpoint.x, P.parts.storeStand.x)
            check.equal(route.endpoint.y, P.parts.storeStand.y)
            local ore = HandRoutes.routeFor("oreCollector", 1, 1, allNets) :: HandRoutes.Route
            check.equal(#ore.stops, 1)
            check.equal(ore.stops[1].padId, "tenth_net")
            -- iar Collector-ul Erei 1 nu trece pe la plasele Morii
            local wood = HandRoutes.routeFor("collector", 1, 1, allNets) :: HandRoutes.Route
            check.equal(#wood.stops, 4)
        end)

        test.case(
            "carausii Morii iau din locurile din FlowConfig si ajung la atelier si la Piata",
            function()
                local porter = HandRoutes.routeFor("millPorter", 1, 1, allNets) :: HandRoutes.Route
                check.equal(porter.stops[1].padId, FlowConfig.LINES.parts.store)
                check.equal(porter.endpoint.x, P.parts.processorIn.x)
                local hauler = HandRoutes.routeFor("partsHauler", 1, 1, allNets) :: HandRoutes.Route
                check.equal(hauler.stops[1].padId, FlowConfig.LINES.parts.output)
                check.equal(hauler.endpoint.x, TycoonConfig.SELLER_PLACES.market.door.x)
                local copper =
                    HandRoutes.routeFor("copperHauler", 1, 1, allNets) :: HandRoutes.Route
                check.equal(copper.stops[1].padId, "copper")
                check.equal(copper.endpoint.x, TycoonConfig.SELLER_PLACES.market.door.x)
                for _, stopId in
                    {
                        "millStore",
                        "oreShed",
                        "parts",
                        "copper",
                        "storage",
                        "planks",
                        "shed",
                        "iron",
                    }
                do
                    check.equal(HandRoutes.takePlace(stopId), stopId)
                end
                check.equal(HandRoutes.takePlace("sixth_net"), nil)
            end
        )

        test.case(
            "drumurile Morii merg pe drumurile ei, fara sa taie prin cartierul vechi",
            function()
                for _, role in
                    {
                        "millCollector",
                        "millPorter",
                        "partsHauler",
                        "oreCollector",
                        "orePorter",
                        "copperHauler",
                    }
                do
                    local cycle = HandRoutes.cycleFor(role, 1, 1, allNets)
                    check.is_true(cycle.duration > 0)
                    for _, leg in cycle.legs do
                        for _, point in { leg.from, leg.to } do
                            if point ~= nil then
                                check.is_true(point.x >= 1860)
                            end
                        end
                    end
                end
            end
        )

        test.case("al doilea om al unui atelier sta alaturi de primul, pe orice linie", function()
            local first = HandRoutes.standFor("founder", 1) :: any
            local second = HandRoutes.standFor("founder", 2) :: any
            check.equal(second.x - first.x, P.parts.secondOffset.x)
            local sawyer1 = HandRoutes.standFor("sawyer", 1) :: any
            local sawyer2 = HandRoutes.standFor("sawyer", 2) :: any
            check.equal(sawyer2.x - sawyer1.x, TycoonConfig.SECOND_STAND_OFFSET.sawyer.x)
            local trader2 = HandRoutes.standFor("trader", 2) :: any
            check.equal(
                trader2.x - TycoonConfig.TRADER_STAND.x,
                TycoonConfig.SECOND_STAND_OFFSET.trader.x
            )
            local merchant = HandRoutes.standFor("merchant", 1) :: any
            check.equal(merchant.x, TycoonConfig.TRADER_STAND.x + TycoonConfig.MILL_DX)
        end)
    end)
end
