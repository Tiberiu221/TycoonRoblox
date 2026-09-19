-- Paritate cu simulatorul. ChainMath e un PORT al lui scripts/economy/sim_tycoon.py: daca cele
-- doua se despart fie si la ultimul bit, jocul incepe sa afiseze alte cifre decat cele pe care s-a
-- facut balansul. Valorile de mai jos le tipareste scripts/economy/golden_chain.py [D55, D56].
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StationConfig = require("../src/Shared/Config/StationConfig")
local ChainMath = require("../src/Shared/Modules/ChainMath")

type CrewSpec = { [string]: { number } }

-- `forge` = {Forge cumparata, nivelul forjei} [D56]; fara el, fara Forge (lantul lemnului de dinainte)
local function state(
    levels: { number },
    saw: number,
    dock: number,
    sack: boolean,
    crews: CrewSpec?,
    forge: { any }?
): ChainMath.State
    local s = ChainMath.empty()
    for i, lv in levels do
        table.insert(s.nets, {
            base = ChainMath.netBase(i),
            baseLane = StationConfig.NET_LANES[i],
            level = lv,
            kind = StationConfig.NET_KINDS[i],
        })
    end
    s.sawLevel = saw
    s.dockLevel = dock
    s.sackBig = sack
    for role, spec in crews or {} do
        s.crews[role] = { count = spec[1], tier = spec[2] }
    end
    if forge ~= nil then
        s.workshop = forge[1] :: boolean
        s.forgeLevel = forge[2] :: number
    end
    return s
end

-- (nume, plase, gater, taverna, traista, oameni {rol = {cati, treapta}}, Forge, nivelul forjei,
--  debite {lemn prins, scrap prins, adunat, dus, taiat, dus la taverna, scrap adunat, scrap dus, topit,
--  fier dus la taverna, vandut, lemn livrat, fier livrat}, gatuirea, a lemnului, a fierului, venit).
-- [D56] Tiparite de scripts/economy/golden_chain.py -- se regenereaza, nu se copiaza de mana. Primele opt stari
-- (fara Forge) dau exact cifrele din D55, bit cu bit.
local GOLDEN = {
    {
        name = "o plasa nivel 1, totul de mana",
        nets = { 1 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = {},
        forgeOwned = false,
        forge = 1,
        rates = { 0.33, 0.0, 0.9, 0.9, 0.6, 0.9, 0.0, 0.0, 0.0, 0.0, 1.0499999999999998, 0.33, 0.0 },
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
        income = 0.5445,
    },
    {
        name = "doua plase nivel 5",
        nets = { 5, 5 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = {},
        forgeOwned = false,
        forge = 1,
        rates = {
            0.9055200000000001,
            0.0,
            0.9,
            0.9,
            0.6,
            0.9,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0499999999999998,
            0.6,
            0.0,
        },
        bottleneck = "saw",
        woodBottleneck = "saw",
        ironBottleneck = "",
        income = 0.9899999999999999,
    },
    {
        name = "Collector angajat: restul pasilor primesc mai mult din timpul tau",
        nets = { 5, 5 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = { collector = { 1, 1 } },
        forgeOwned = false,
        forge = 1,
        rates = {
            0.9055200000000001,
            0.0,
            4.0,
            1.2,
            0.7999999999999999,
            1.2,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0499999999999998,
            0.7999999999999999,
            0.0,
        },
        bottleneck = "saw",
        woodBottleneck = "saw",
        ironBottleneck = "",
        income = 1.3199999999999998,
    },
    {
        name = "traista mare pe pasii de mana",
        nets = { 10, 8 },
        saw = 3,
        dock = 2,
        sack = true,
        crews = { collector = { 1, 1 }, porter = { 1, 1 } },
        forgeOwned = false,
        forge = 1,
        rates = { 1.417185, 0.0, 4.0, 6.0, 1.344, 2.7, 0.0, 0.0, 0.0, 0.0, 1.113, 1.113, 0.0 },
        bottleneck = "dock",
        woodBottleneck = "dock",
        ironBottleneck = "",
        income = 1.83645,
    },
    {
        name = "toti oamenii lemnului, trepte diferite, plasa a cincea fara Forge",
        nets = { 14, 11, 9, 6, 3 },
        saw = 8,
        dock = 8,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 1, 3 },
            sawyer = { 1, 2 },
            hauler = { 1, 4 },
            trader = { 1, 2 },
        },
        forgeOwned = false,
        forge = 1,
        rates = {
            4.178796187500001,
            0.0,
            40.0,
            18.0,
            6.816,
            36.0,
            0.0,
            0.0,
            0.0,
            0.0,
            8.52,
            4.178796187500001,
            0.0,
        },
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
        income = 6.895013709375001,
    },
    {
        name = "fara Negustor: debarcaderul merge la o treime",
        nets = { 10, 10 },
        saw = 20,
        dock = 5,
        sack = false,
        crews = { collector = { 1, 2 }, porter = { 1, 2 }, sawyer = { 1, 1 }, hauler = { 1, 1 } },
        forgeOwned = false,
        forge = 1,
        rates = {
            2.05359,
            0.0,
            8.0,
            12.0,
            10.271999999999998,
            9.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.3019999999999998,
            1.3019999999999998,
            0.0,
        },
        bottleneck = "dock",
        woodBottleneck = "dock",
        ironBottleneck = "",
        income = 2.1482999999999994,
    },
    {
        name = "gaterul de mana e gatuirea",
        nets = { 10, 10 },
        saw = 1,
        dock = 10,
        sack = false,
        crews = { collector = { 1, 1 }, porter = { 1, 1 }, hauler = { 1, 1 } },
        forgeOwned = false,
        forge = 1,
        rates = { 2.05359, 0.0, 4.0, 6.0, 2.4, 9.0, 0.0, 0.0, 0.0, 0.0, 3.234, 2.05359, 0.0 },
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
        income = 3.3884234999999996,
    },
    {
        name = "prag 25 pe toate, echipaj la maxim, fara Forge",
        nets = { 25, 25, 25, 25, 25 },
        saw = 25,
        dock = 25,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 5 },
            ironHauler = { 2, 5 },
        },
        forgeOwned = false,
        forge = 1,
        rates = {
            17.2575942,
            0.0,
            40.0,
            60.0,
            234.24,
            90.0,
            20.0,
            25.0,
            0.0,
            65.0,
            292.8,
            17.2575942,
            0.0,
        },
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
        income = 28.475030429999997,
    },
    {
        name = "Forge fara plasa de scrap: fierul nu exista",
        nets = { 30, 30, 25, 20 },
        saw = 30,
        dock = 30,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
        },
        forgeOwned = true,
        forge = 1,
        rates = {
            13.980081225000001,
            0.0,
            40.0,
            60.0,
            263.04,
            90.0,
            0.0,
            0.0,
            0.0,
            0.0,
            328.8,
            13.980081225000001,
            0.0,
        },
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
        income = 23.067134021250002,
    },
    {
        name = "turul de mana al fierului: patru pasi, timpul tau intreg pe ei",
        nets = { 30, 30, 25, 20, 1 },
        saw = 30,
        dock = 30,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
        },
        forgeOwned = true,
        forge = 1,
        rates = {
            13.980081225000001,
            1.4587670625,
            40.0,
            60.0,
            263.04,
            90.0,
            1.35,
            1.35,
            0.3,
            1.35,
            328.8,
            13.980081225000001,
            0.3,
        },
        bottleneck = "forge",
        woodBottleneck = "nets",
        ironBottleneck = "forge",
        income = 24.132134021250003,
    },
    {
        name = "Scrap Collector si Scrap Porter angajati: forja de mana e gatuirea",
        nets = { 30, 30, 25, 20, 10 },
        saw = 30,
        dock = 30,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 1, 3 },
            scrapPorter = { 1, 3 },
        },
        forgeOwned = true,
        forge = 1,
        rates = {
            13.980081225000001,
            3.70526833875,
            40.0,
            60.0,
            263.04,
            90.0,
            6.0,
            7.5,
            0.6,
            2.7,
            328.8,
            13.980081225000001,
            0.6,
        },
        bottleneck = "forge",
        woodBottleneck = "nets",
        ironBottleneck = "forge",
        income = 25.19713402125,
    },
    {
        name = "toti oamenii fierului, forja mare: Scrap Collector-ul tine fierul",
        nets = { 30, 30, 25, 20, 25 },
        saw = 30,
        dock = 30,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 1, 1 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 5 },
            ironHauler = { 2, 5 },
        },
        forgeOwned = true,
        forge = 40,
        rates = {
            13.980081225000001,
            10.036317389999999,
            40.0,
            60.0,
            263.04,
            90.0,
            2.0,
            25.0,
            160.32,
            65.0,
            328.8,
            13.980081225000001,
            2.0,
        },
        bottleneck = "scrapCollect",
        woodBottleneck = "nets",
        ironBottleneck = "scrapCollect",
        income = 30.16713402125,
    },
    {
        name = "taverna plina: fierul intai, lemnul din ce ramane",
        nets = { 60, 60, 60, 60, 40 },
        saw = 60,
        dock = 3,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 5 },
            ironHauler = { 2, 5 },
        },
        forgeOwned = true,
        forge = 60,
        rates = {
            55.5855069,
            12.6620981025,
            40.0,
            60.0,
            871.68,
            90.0,
            20.0,
            25.0,
            435.84,
            65.0,
            33.6,
            20.9379018975,
            12.6620981025,
        },
        bottleneck = "nets",
        woodBottleneck = "dock",
        ironBottleneck = "nets",
        income = 79.49798639475,
    },
    {
        name = "Iron Hauler-ul de mana e gatuirea fierului",
        nets = { 40, 40, 40, 40, 30 },
        saw = 40,
        dock = 40,
        sack = true,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 5 },
        },
        forgeOwned = true,
        forge = 60,
        rates = {
            21.77266245,
            10.9115776275,
            40.0,
            60.0,
            320.64,
            90.0,
            20.0,
            25.0,
            435.84,
            5.4,
            400.79999999999995,
            21.77266245,
            5.4,
        },
        bottleneck = "ironHaul",
        woodBottleneck = "nets",
        ironBottleneck = "ironHaul",
        income = 55.0948930425,
    },
}

-- Toate cumparaturile posibile intr-o stare: fiecare trebuie sa nu scada venitul.
local function purchases(s: ChainMath.State): { (ChainMath.State) -> () }
    local out: { (ChainMath.State) -> () } = {
        function(st)
            st.nets[1].level += 1
        end,
        function(st)
            st.sawLevel += 1
        end,
        function(st)
            st.dockLevel += 1
        end,
        function(st)
            st.sackBig = true
        end,
        -- [D55, D56] forja si Forge
        function(st)
            st.forgeLevel += 1
        end,
        function(st)
            st.workshop = true
        end,
    }
    local last = s.nets[#s.nets]
    if last ~= nil then
        table.insert(out, function(st)
            st.nets[#st.nets].level += 1
        end)
    end
    -- urmatoarea angajare, in ordinea raului, pe fiecare linie
    for _, steps in StationConfig.LINE_STEPS do
        for _, role in steps do
            if s.crews[role].count == 0 then
                table.insert(out, function(st)
                    st.crews[role].count = 1
                end)
                break
            end
        end
    end
    for _, role in StationConfig.ROLES do
        local crew = s.crews[role]
        if role == "trader" and crew.count == 0 then
            table.insert(out, function(st)
                st.crews.trader.count = 1
            end)
        end
        if crew.count > 0 and crew.tier < StationConfig.TIER_MAX then
            table.insert(out, function(st)
                st.crews[role].tier += 1
            end)
        end
        if crew.count == 1 and crew.tier >= StationConfig.SECOND_AT_TIER then
            table.insert(out, function(st)
                st.crews[role].count = 2
            end)
        end
    end
    return out
end

local function allCrews(count: number, tier: number, except: string?): CrewSpec
    local crews: CrewSpec = {}
    for _, role in StationConfig.ROLES do
        if role ~= except then
            crews[role] = { count, tier }
        end
    end
    return crews
end

return function()
    test.suite("ChainMath - paritate cu simulatorul", function()
        for _, g in GOLDEN do
            test.case(g.name, function()
                local s =
                    state(g.nets, g.saw, g.dock, g.sack, g.crews :: any, { g.forgeOwned, g.forge })
                local r = ChainMath.rates(s)
                check.equal(r.woodCatch, g.rates[1])
                check.equal(r.scrapCatch, g.rates[2])
                check.equal(r.collect, g.rates[3])
                check.equal(r.port, g.rates[4])
                check.equal(r.sawing, g.rates[5])
                check.equal(r.haul, g.rates[6])
                check.equal(r.scrapCollect, g.rates[7])
                check.equal(r.scrapPort, g.rates[8])
                check.equal(r.forging, g.rates[9])
                check.equal(r.ironHaul, g.rates[10])
                check.equal(r.sales, g.rates[11])
                check.equal(r.wood, g.rates[12])
                check.equal(r.scrap, g.rates[13])
                check.equal(r.bottleneck, g.bottleneck)
                check.equal(r.woodBottleneck, g.woodBottleneck)
                check.equal(r.ironBottleneck, g.ironBottleneck)
                check.equal(ChainMath.income(s), g.income)
            end)
        end
    end)

    test.suite("ChainMath - scara nivelurilor si treptele", function()
        test.case("pragurile dubleaza, restul cresc liniar", function()
            check.equal(ChainMath.milestoneMult(9), 1)
            check.equal(ChainMath.milestoneMult(10), 2)
            check.equal(ChainMath.milestoneMult(24), 2)
            check.equal(ChainMath.milestoneMult(25), 4)
            check.equal(ChainMath.milestoneMult(50), 8)
        end)

        test.case("fiecare prag se SIMTE: salt de peste 15%", function()
            -- daca un prag nu se vede, tot mecanismul care te tine apasand se pierde
            local worst = math.huge
            for _, kind in { "nets", "saw", "dock" } do
                for _, t in { 10, 25, 50 } do
                    local before = ChainMath.levelOutput(1, t - 1, kind)
                    local after = ChainMath.levelOutput(1, t, kind)
                    worst = math.min(worst, after / before)
                end
            end
            check.is_true(worst > 1.15)
        end)

        test.case(
            "[D62] rangul unui nivel, pentru ce se vede: 0 sub 10, apoi 1 / 2 / 3 la 10 / 25 / 50",
            function()
                check.equal(ChainMath.rankOf(1), 0)
                check.equal(ChainMath.rankOf(9), 0)
                check.equal(ChainMath.rankOf(10), 1)
                check.equal(ChainMath.rankOf(24), 1)
                check.equal(ChainMath.rankOf(25), 2)
                check.equal(ChainMath.rankOf(49), 2)
                check.equal(ChainMath.rankOf(50), 3)
                -- pragurile de dincolo de 50 dubleaza mai departe debitul, dar nu mai au desen
                check.equal(ChainMath.rankOf(500), ChainMath.RANK_MAX)
                -- rangurile sunt chiar primele praguri ale scarii nivelurilor
                for rank = 1, ChainMath.RANK_MAX do
                    check.equal(ChainMath.rankOf(StationConfig.MILESTONES[rank]), rank)
                    check.equal(ChainMath.rankOf(StationConfig.MILESTONES[rank] - 1), rank - 1)
                end
            end
        )

        test.case("isGrand: a doua infatisare a cladirilor vine exact la pragul 25", function()
            check.is_false(ChainMath.isGrand(1))
            check.is_false(ChainMath.isGrand(24))
            check.is_true(ChainMath.isGrand(25))
            check.is_true(ChainMath.isGrand(500))
            -- pragul e chiar al doilea din scara nivelurilor: acolo se dubleaza debitul a doua oara
            check.equal(StationConfig.MILESTONES[ChainMath.GRAND_RANK], 25)
        end)

        test.case(
            "milestoneCrossed: pragul trecut de o cumparare, si cand sare peste el",
            function()
                check.is_true(ChainMath.milestoneCrossed(1, 2) == nil)
                check.is_true(ChainMath.milestoneCrossed(8, 9) == nil)
                check.equal(ChainMath.milestoneCrossed(9, 10), 10)
                check.is_true(ChainMath.milestoneCrossed(10, 11) == nil) -- pragul se sarbatoreste o singura data
                check.equal(ChainMath.milestoneCrossed(5, 15), 10) -- x10 sare peste prag
                check.equal(ChainMath.milestoneCrossed(9, 30), 25) -- doua praguri: cel mai mare
                check.is_true(ChainMath.milestoneCrossed(500, 600) == nil)
            end
        )

        test.case("nextMilestone arata unde e urmatorul salt", function()
            check.equal(ChainMath.nextMilestone(1), 10)
            check.equal(ChainMath.nextMilestone(10), 25)
            check.equal(ChainMath.nextMilestone(499), 500)
            check.is_true(ChainMath.nextMilestone(500) == nil)
        end)

        test.case("costul creste exponential, niciodata invers", function()
            local prev = 0
            local rising = true
            for lv = 1, 60 do
                local c = ChainMath.levelCost(StationConfig.NET_UPGRADE_BASE_COST, lv)
                if c <= prev then
                    rising = false
                end
                prev = c
            end
            check.is_true(rising)
        end)

        test.case("bulkCost e chiar suma nivelurilor luate unul cate unul", function()
            local one = 0.0
            for i = 0, 9 do
                one += ChainMath.levelCost(5, 3 + i)
            end
            check.is_true(math.abs(ChainMath.bulkCost(5, 3, 10) - one) < 1e-9)
        end)

        test.case("affordableLevels nu depaseste niciodata punga", function()
            local coins = 100
            local n = ChainMath.affordableLevels(5, 1, coins, 200)
            check.is_true(ChainMath.bulkCost(5, 1, n) <= coins)
            check.is_true(ChainMath.bulkCost(5, 1, n + 1) > coins)
        end)

        test.case("treptele costa 25 / 75 / 225 / 675, ca in simulator", function()
            check.equal(ChainMath.tierCost(1), 25)
            check.equal(ChainMath.tierCost(2), 75)
            check.equal(ChainMath.tierCost(3), 225)
            check.equal(ChainMath.tierCost(4), 675)
            check.equal(ChainMath.tierMult(StationConfig.TIER_MAX), 5)
        end)
    end)

    test.suite("ChainMath - regulile care nu se negociaza", function()
        test.case("nicio cumparatura nu SCADE venitul, in nicio etapa a angajarilor", function()
            -- inclusiv fiecare angajare, cu si fara traista mare: ca ultim pas fara om, Hauler-ul
            -- primea tot timpul tau, iar cu o baza prea mica angajarea lui taia venitul [D49]. [D56] Si pe
            -- linia fierului, inclusiv in stari la care in joc nu se ajunge (pasi de mana pe amandoua liniile):
            -- fiecare linie are timpul tau intreg, deci deschiderea fierului nu poate scadea lemnul.
            local drops = 0
            local checked = 0
            for hired = 0, #StationConfig.MANUAL_ROLES do
                for _, sack in { false, true } do
                    for _, tier in { 1, 3, 5 } do
                        for _, trader in { false, true } do
                            local crews: CrewSpec = {}
                            for i = 1, hired do
                                crews[StationConfig.MANUAL_ROLES[i]] = { 1, tier }
                            end
                            if trader then
                                crews.trader = { 1, tier }
                            end
                            for _, big in { 1, 40 } do
                                for _, forge in { false, true } do
                                    local levels = { 8 * big, 6 * big, 4 * big, 3 * big, 2 * big }
                                    local s = state(
                                        levels,
                                        big,
                                        big,
                                        sack,
                                        crews,
                                        if forge then { true, big } else nil
                                    )
                                    local before = ChainMath.income(s)
                                    for _, apply in purchases(s) do
                                        local probe = ChainMath.clone(s)
                                        apply(probe)
                                        checked += 1
                                        if ChainMath.income(probe) < before - 1e-9 then
                                            drops += 1
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            check.is_true(checked > 1000)
            check.equal(drops, 0)
        end)

        test.case("fiecare angajare iti da inapoi timp pentru ceilalti pasi ai liniei", function()
            local s = state({ 40, 40 }, 40, 40, false)
            local share = ChainMath.playerShare(s)
            check.equal(share, StationConfig.PLAYER_LABOR / 4)
            s.crews.collector.count = 1
            check.is_true(ChainMath.playerShare(s) > share)
            for _, role in StationConfig.LINE_STEPS.wood do
                s.crews[role].count = 1
            end
            check.equal(ChainMath.playerShare(s), 0)
            -- [D56] linia fierului n-are pasi de mana cat e inchisa; deschisa, are timpul tau intreg
            check.equal(ChainMath.playerShare(s, "iron"), 0)
            local open = state({ 40, 40, 40, 40, 40 }, 40, 40, false, allCrews(0, 1), { true, 1 })
            check.equal(ChainMath.playerShare(open, "iron"), StationConfig.PLAYER_LABOR / 4)
            check.equal(ChainMath.playerShare(open, "wood"), StationConfig.PLAYER_LABOR / 4)
        end)

        test.case("Negustorul face debarcaderul sa mearga, nu sa plateasca mai bine", function()
            -- fara el, o treime din viteza; angajarea trebuie sa se vada in CIFRA de pe rand
            local without = state({ 10, 10 }, 20, 5, false)
            local with = state({ 10, 10 }, 20, 5, false, { trader = { 1, 1 } })
            check.is_true(ChainMath.rates(with).sales > ChainMath.rates(without).sales * 2.5)
            -- si nu atinge pretul: la aceeasi cantitate livrata, valoarea bucatii e aceeasi
            check.equal(ChainMath.avgValue(with), ChainMath.avgValue(without))
        end)

        test.case("fara Sawyer gaterul taie doar cat stai langa el", function()
            local sawyer = { count = 0, tier = 1 }
            check.equal(ChainMath.sawSpeed(4, sawyer, false), 0)
            check.equal(ChainMath.sawSpeed(4, sawyer, true), ChainMath.sawCap(4))
            local hired = { count = 2, tier = 3 }
            -- cu oameni merge tot timpul, fie ca esti acolo sau nu
            check.equal(ChainMath.sawSpeed(4, hired, false), ChainMath.sawCap(4) * 3 * 2)
            check.equal(ChainMath.sawSpeed(4, hired, true), ChainMath.sawSpeed(4, hired, false))
        end)

        test.case("fara Smelter forja topeste doar cat stai langa ea [D56]", function()
            local smelter = { count = 0, tier = 1 }
            check.equal(ChainMath.forgeSpeed(4, smelter, false), 0)
            check.equal(ChainMath.forgeSpeed(4, smelter, true), ChainMath.forgeCap(4))
            local hired = { count = 2, tier = 3 }
            check.equal(ChainMath.forgeSpeed(4, hired, false), ChainMath.forgeCap(4) * 3 * 2)
            check.equal(ChainMath.forgeSpeed(4, hired, true), ChainMath.forgeSpeed(4, hired, false))
        end)

        test.case("un upgrade pe veriga care NU e gatuirea da exact zero", function()
            -- asta nu e un bug, e lectia jocului -- si de aceea trebuie sa fie sigur, nu noroc
            local s = state({ 30, 30, 30 }, 30, 30, false, {
                collector = { 1, 1 },
                porter = { 2, 5 },
                sawyer = { 2, 5 },
                hauler = { 2, 5 },
                trader = { 2, 5 },
            })
            check.equal(ChainMath.rates(s).bottleneck, "collect")
            local gain = ChainMath.gainOf(s, function(st)
                st.nets[1].level += 5
            end)
            check.equal(gain, 0)
            local helps = ChainMath.gainOf(s, function(st)
                st.crews.collector.tier += 1
            end)
            check.is_true(helps > 0)
        end)

        test.case("la egalitate castiga veriga dinainte, ca min() din Python", function()
            -- trei pasi de drum fara om primesc aceeasi parte din timpul tau
            local s = state({ 60, 60 }, 60, 60, false, { sawyer = { 1, 1 }, trader = { 1, 1 } })
            local r = ChainMath.rates(s)
            check.equal(r.collect, r.port)
            check.equal(r.port, r.haul)
            check.equal(r.bottleneck, "collect")
            s.crews.collector.count = 1
            check.equal(ChainMath.rates(s).bottleneck, "port")
            s.crews.porter.count = 1
            check.equal(ChainMath.rates(s).bottleneck, "haul")
        end)

        test.case("gatuirea chiar se roteste intre toate verigile, si ale fierului", function()
            -- daca o veriga nu ajunge niciodata gatuire, semnul de avertizare de pe ea e decor --
            -- iar pentru o meserie, un meniu intreg care ar scrie "No gain yet" toata era
            local seen = {}
            for lv = 1, 40, 3 do
                for _, dock in { 1, 6, 30 } do
                    for _, saw in { 1, 8, 40 } do
                        for hired = 0, #StationConfig.MANUAL_ROLES do
                            for _, tier in { 1, 5 } do
                                local crews: CrewSpec = { trader = { 1, 1 } }
                                for i = 1, hired do
                                    crews[StationConfig.MANUAL_ROLES[i]] = { 1, tier }
                                end
                                local s = state({ lv, lv }, saw, dock, false, crews)
                                seen[ChainMath.rates(s).bottleneck] = true
                                -- [D56] cu Forge si plasa de scrap, forja mica si mare: verigile fierului ajung si
                                -- ele gatuire
                                for _, forge in { 1, 20 } do
                                    local withIron = state(
                                        { lv, lv, lv, lv, lv },
                                        saw,
                                        dock,
                                        false,
                                        crews,
                                        { true, forge }
                                    )
                                    seen[ChainMath.rates(withIron).bottleneck] = true
                                end
                            end
                        end
                    end
                end
            end
            for _, link in StationConfig.LINKS do
                check.is_true(seen[link] == true)
            end
        end)

        test.case("venitul pasiv cere toti oamenii liniei lui [D49, D56]", function()
            -- fara oricare om al lemnului (sau fara Negustor), lantul lemnului e taiat; fara oricare om al fierului,
            -- doar fierul sta -- lemnul merge mai departe
            local levels = { 12, 12, 12, 12, 12 }
            local full =
                ChainMath.idleIncome(state(levels, 8, 8, false, allCrews(1, 1), { true, 8 }))
            check.is_true(full > 0)
            for _, missing in StationConfig.LINE_STEPS.wood do
                check.equal(
                    ChainMath.idleIncome(state({ 12, 12 }, 8, 8, false, allCrews(1, 1, missing))),
                    0
                )
            end
            check.equal(
                ChainMath.idleIncome(state({ 12, 12 }, 8, 8, false, allCrews(1, 1, "trader"))),
                0
            )
            for _, missing in StationConfig.LINE_STEPS.iron do
                local s = state(levels, 8, 8, false, allCrews(1, 1, missing), { true, 8 })
                local idle = ChainMath.idleRates(s)
                check.equal(idle.scrap, 0)
                check.is_true(idle.wood > 0)
                check.is_true(ChainMath.idleIncome(s) < full)
            end
        end)

        test.case("venitul pasiv nu il depaseste niciodata pe cel activ", function()
            -- tu te ADAUGI pe pasii fara om, deci prezenta ta nu poate scadea nimic
            local worse = 0
            for hired = 0, #StationConfig.MANUAL_ROLES do
                for _, tier in { 1, 4 } do
                    for _, forge in { false, true } do
                        local crews: CrewSpec = { trader = { 1, tier } }
                        for i = 1, hired do
                            crews[StationConfig.MANUAL_ROLES[i]] = { 1, tier }
                        end
                        local s = state(
                            { 10, 8, 6, 5, 4 },
                            6,
                            6,
                            false,
                            crews,
                            if forge then { true, 3 } else nil
                        )
                        if ChainMath.idleIncome(s) > ChainMath.income(s) + 1e-9 then
                            worse += 1
                        end
                    end
                end
            end
            check.equal(worse, 0)
        end)

        test.case("pragul 10 duce plasa cu o banda mai in larg", function()
            check.equal(ChainMath.netLane(1, 9), 1)
            check.equal(ChainMath.netLane(1, 10), 2)
            check.equal(ChainMath.netLane(1, 25), 3)
            check.equal(ChainMath.netLane(3, 25), 3) -- nu trece niciodata de banda 3
        end)

        test.case("bucata de fier valoreaza mai mult decat una de lemn [D55]", function()
            -- taverna vinde intai fierul: e cea mai buna impartire doar cat asta e adevarat
            check.is_true(ChainMath.AVG.scrap > ChainMath.AVG.wood)
        end)

        test.case("fara Forge, lantul e exact minimul celor sase debite [D55, D56]", function()
            for _, levels in { { 1 }, { 5, 5 }, { 30, 20, 10 }, { 40, 40, 40, 40, 40 } } do
                for _, saw in { 1, 10, 60 } do
                    local s =
                        state(levels, saw, 12, true, { collector = { 1, 2 }, trader = { 1, 1 } })
                    local r = ChainMath.rates(s)
                    local six = math.min(r.woodCatch, r.collect, r.port, r.sawing, r.haul, r.sales)
                    check.equal(r.wood, six)
                    check.equal(r.scrap, 0)
                    check.equal(r.ironBottleneck, "")
                end
            end
        end)

        test.case("fierul exista doar cu Forge si plasa de scrap -- si fara shed [D56]", function()
            local crews = allCrews(2, 5)
            check.equal(
                ChainMath.rates(state({ 20, 20, 20, 20, 20 }, 20, 20, true, crews)).scrap,
                0
            )
            check.equal(
                ChainMath.rates(state({ 20, 20, 20, 20 }, 20, 20, true, crews, { true, 5 })).scrap,
                0
            )
            -- turul de mana: fara niciun om al fierului, cu timpul tau
            local byHand = state({ 20, 20, 20, 20, 20 }, 20, 20, true, allCrews(2, 5), { true, 5 })
            for _, role in StationConfig.LINE_STEPS.iron do
                byHand.crews[role] = { count = 0, tier = 1 }
            end
            check.is_true(ChainMath.rates(byHand).scrap > 0)
        end)

        test.case("taverna plina vinde intai fierul, lemnul ia ce ramane [D56]", function()
            local s = state({ 60, 60, 60, 60, 40 }, 60, 1, true, allCrews(2, 5), { true, 60 })
            local r = ChainMath.rates(s)
            local ironMax =
                math.min(r.scrapCatch, r.scrapCollect, r.scrapPort, r.forging, r.ironHaul)
            check.equal(r.scrap, math.min(ironMax, r.sales))
            check.equal(r.wood + r.scrap, r.sales)
            check.equal(r.woodBottleneck, "dock")
        end)
    end)

    -- [D64] MOTORUL CHIAR DUCE ORICATE LINII. Tabelul de aur dovedeste ca refactorul n-a schimbat Era 1, dar cu doua
    -- linii un motor scris de mana si unul generic dau aceleasi cifre. Aici modelul primeste doua linii de proba cu un al
    -- doilea vanzator, iar rezultatul se compara cu cifre socotite de mana. OGLINDA lui scripts/economy/check_lines.py:
    -- aceleasi linii, aceleasi cifre (rotunde, ca socoteala sa fie exacta in virgula mobila). Nu e economia Erei 2.
    test.suite("ChainMath - liniile ca date [D64]", function()
        local GAME = ChainMath.GAME

        local function probeModel(): ChainMath.Model
            local lines: { [string]: ChainMath.Line } = table.clone(GAME.lines)
            lines.parts = {
                netKind = "parts",
                openFlag = "foundryOwned",
                seller = "market",
                steps = {
                    { role = "partsCollector", link = "partsCollect", kind = "walk" },
                    { role = "partsPorter", link = "partsPort", kind = "walk" },
                    { role = "founder", link = "foundry", kind = "processor" },
                    { role = "partsHauler", link = "partsHaul", kind = "walk" },
                },
            }
            lines.copper = {
                netKind = "copper",
                openFlag = "smithyOwned",
                seller = "market",
                steps = {
                    { role = "copperCollector", link = "copperCollect", kind = "walk" },
                    { role = "copperPorter", link = "copperPort", kind = "walk" },
                    { role = "coppersmith", link = "smithy", kind = "processor" },
                    { role = "copperHauler", link = "copperHaul", kind = "walk" },
                },
            }
            local processors: { [string]: ChainMath.Processor } = table.clone(GAME.processors)
            processors.foundry = { base = 2.0, levelField = "foundryLevel" }
            processors.smithy = { base = 2.0, levelField = "smithyLevel" }
            local sellers: { [string]: ChainMath.Seller } = table.clone(GAME.sellers)
            sellers.market = {
                role = "merchant",
                base = 5.0,
                levelField = "marketLevel",
                priority = { "copper", "parts" },
            }
            local roleBase = table.clone(GAME.roleBase)
            for _, role in
                {
                    "partsCollector",
                    "partsPorter",
                    "partsHauler",
                    "copperCollector",
                    "copperPorter",
                    "copperHauler",
                }
            do
                roleBase[role] = 3.0
            end
            local avg = table.clone(GAME.avg)
            avg.parts = 8.0
            avg.copper = 12.0
            return ChainMath.model(
                { "wood", "iron", "parts", "copper" },
                lines,
                processors,
                { "dock", "market" },
                sellers,
                roleBase,
                avg
            )
        end

        local PARTS = { "partsCollector", "partsPorter", "founder", "partsHauler" }
        local COPPER = { "copperCollector", "copperPorter", "coppersmith", "copperHauler" }

        -- Un sat de Era 1 la jumatatea drumului, plus campurile liniilor de proba (starea e plata: o linie noua vine cu
        -- campurile ei).
        local function probeState(partsNet: number?, copperNet: number?): any
            local s: any = state({ 14, 11, 9, 6, 8 }, 8, 8, true, {
                collector = { 2, 5 },
                porter = { 1, 3 },
                sawyer = { 1, 2 },
                hauler = { 1, 4 },
                trader = { 1, 2 },
                scrapCollector = { 1, 2 },
                scrapPorter = { 1, 1 },
                smelter = { 1, 1 },
                ironHauler = { 1, 1 },
            }, { true, 4 })
            s.foundryOwned = partsNet ~= nil
            s.smithyOwned = copperNet ~= nil
            s.foundryLevel, s.smithyLevel, s.marketLevel = 1, 1, 1
            for _, role in PARTS do
                s.crews[role] = { count = 0, tier = 1 }
            end
            for _, role in COPPER do
                s.crews[role] = { count = 0, tier = 1 }
            end
            s.crews.merchant = { count = 0, tier = 1 }
            if partsNet ~= nil then
                table.insert(s.nets, { base = partsNet, baseLane = 1, level = 1, kind = "parts" })
            end
            if copperNet ~= nil then
                table.insert(s.nets, { base = copperNet, baseLane = 1, level = 1, kind = "copper" })
            end
            return s
        end

        local function staff(s: any, roles: { string }, count: number, tier: number)
            for _, role in roles do
                s.crews[role] = { count = count, tier = tier }
            end
        end

        local function near(got: number, want: number)
            check.is_true(math.abs(got - want) < 1e-9)
        end

        local function valueAt(
            flow: ChainMath.LineFlow,
            m: ChainMath.Model,
            line: string,
            link: string
        ): number
            for k, step in m.lines[line].steps do
                if step.link == link then
                    return flow.values[k]
                end
            end
            error("veriga necunoscuta: " .. link)
        end

        test.case(
            "modelul jocului e cel din StationConfig, cu verigile in ordinea de aur",
            function()
                check.table.equal(GAME.links, {
                    "nets",
                    "collect",
                    "port",
                    "saw",
                    "haul",
                    "scrapCollect",
                    "scrapPort",
                    "forge",
                    "ironHaul",
                    "dock",
                })
                check.table.equal(StationConfig.LINKS, GAME.links)
                check.table.equal(StationConfig.MANUAL_ROLES, {
                    "collector",
                    "porter",
                    "sawyer",
                    "hauler",
                    "scrapCollector",
                    "scrapPorter",
                    "smelter",
                    "ironHauler",
                })
                check.equal(StationConfig.LINK_OF.trader, "dock")
                check.equal(StationConfig.LINK_OF.smelter, "forge")
                check.equal(StationConfig.LINE_OF.saw, "wood")
                check.equal(StationConfig.LINE_OF.ironHaul, "iron")
                check.equal(StationConfig.LINE_OF.dock, nil)
                check.equal(StationConfig.LINE_OF.nets, nil)
            end
        )

        test.case(
            "cladirile lantului se citesc dupa tabel, cu aceleasi cifre ca functiile lor cu nume",
            function()
                for _, level in { 1, 9, 10, 25, 37 } do
                    for _, crew in
                        {
                            { count = 0, tier = 1 },
                            { count = 1, tier = 3 },
                            { count = 2, tier = 5 },
                        }
                    do
                        for _, present in { true, false } do
                            check.equal(
                                ChainMath.buildingSpeed("saw", level, crew, present),
                                ChainMath.sawSpeed(level, crew, present)
                            )
                            check.equal(
                                ChainMath.buildingSpeed("forge", level, crew, present),
                                ChainMath.forgeSpeed(level, crew, present)
                            )
                            check.equal(
                                ChainMath.buildingSpeed("dock", level, crew, present),
                                ChainMath.dockSpeed(level, crew)
                            )
                        end
                    end
                end
                -- un fel necunoscut nu imprumuta cifrele altei cladiri [D40]
                check.equal(ChainMath.buildingSpeed("net", 3, { count = 1, tier = 1 }, true), nil)
                check.equal(ChainMath.levelField("saw"), "sawLevel")
                check.equal(ChainMath.levelField("forge"), "forgeLevel")
                check.equal(ChainMath.levelField("dock"), "dockLevel")
                check.equal(ChainMath.levelField("net"), nil)
                check.equal(ChainMath.lineOfNetKind("wood"), "wood")
                check.equal(ChainMath.lineOfNetKind("scrap"), "iron")
                check.equal(GAME.roleOfLink.saw, "sawyer")
                check.equal(GAME.roleOfLink.forge, "smelter")
                check.equal(GAME.roleOfLink.dock, "trader")
            end
        )

        test.case(
            "veriga slaba a unui rand: a liniei lui, iar pentru taverna cea care tine venitul",
            function()
                local s = state({ 60, 60, 60, 60, 40 }, 60, 1, true, allCrews(2, 5), { true, 60 })
                local f = ChainMath.flow(s)
                local r = ChainMath.ratesOf(f)
                check.equal(ChainMath.lineBottleneck(f, "wood"), r.woodBottleneck)
                check.equal(ChainMath.lineBottleneck(f, "iron"), r.ironBottleneck)
                check.equal(ChainMath.lineBottleneck(f, nil), r.bottleneck)
                -- linia fierului inchisa: "" -- niciun rand al ei nu e marcat drept veriga slaba
                local closed = ChainMath.flow(state({ 5, 5 }, 1, 1, false))
                check.equal(ChainMath.lineBottleneck(closed, "iron"), "")
            end
        )

        test.case(
            "clona tine si campurile pe care nu le cunoaste: o linie noua vine cu ale ei",
            function()
                local s: any = state({ 5, 5 }, 3, 2, true)
                s.foundryLevel = 7
                s.foundryOwned = true
                local copy: any = ChainMath.clone(s)
                check.equal(copy.foundryLevel, 7)
                check.equal(copy.foundryOwned, true)
                check.equal(copy.sawLevel, 3)
                -- tot clona adanca: ce schimbi in ea nu atinge originalul
                copy.nets[1].level = 40
                copy.crews.collector.count = 2
                copy.foundryLevel = 8
                check.equal(s.nets[1].level, 5)
                check.equal(s.crews.collector.count, 0)
                check.equal(s.foundryLevel, 7)
            end
        )

        test.case(
            "un model in care o linie lipseste din randul vanzatorului ei e refuzat",
            function()
                local lines: { [string]: ChainMath.Line } = table.clone(GAME.lines)
                lines.parts = { netKind = "parts", openFlag = nil, seller = "dock", steps = {} }
                local ok = pcall(function()
                    ChainMath.model(
                        { "wood", "iron", "parts" },
                        lines,
                        GAME.processors,
                        GAME.sellerOrder,
                        GAME.sellers,
                        GAME.roleBase,
                        GAME.avg
                    )
                end)
                check.is_false(ok)
            end
        )

        test.case("liniile de proba, inchise: Era 1 nu simte nimic", function()
            local m = probeModel()
            local s = probeState(nil, nil)
            local f = ChainMath.flowWith(m, s)
            check.equal(f.lines.parts.delivered, 0)
            check.equal(f.lines.copper.delivered, 0)
            check.equal(f.lines.parts.bottleneck, "")
            check.equal(f.lines.copper.bottleneck, "")
            check.equal(ChainMath.valueWith(m, s, f), ChainMath.income(s))
            check.equal(f.bottleneck, ChainMath.rates(s).bottleneck)
        end)

        test.case("a treia linie, de mana, la vanzatorul ei fara om", function()
            -- timpul tau intreg pe cei patru pasi ai ei: 3.6 x 1.5 (traista mare) / 4 = 1.35; turnatoria de mana
            -- 2.0 / 4 = 0.5; plasa 1.0 -> linia duce 0.5, tinuta de turnatorie. Piata fara negustor: 5 x 0.35 = 1.75.
            local m = probeModel()
            local s = probeState(1.0, nil)
            local before = ChainMath.rates(s)
            local f = ChainMath.flowWith(m, s)
            near(valueAt(f.lines.parts, m, "parts", "partsCollect"), 1.35)
            near(valueAt(f.lines.parts, m, "parts", "foundry"), 0.5)
            near(f.lines.parts.delivered, 0.5)
            check.equal(f.lines.parts.bottleneck, "foundry")
            near(f.capacity.market, 1.75)
            near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 4.0)
            check.equal(f.lines.wood.delivered, before.wood)
            check.equal(f.lines.iron.delivered, before.scrap)
            check.equal(f.capacity.dock, before.sales)
            -- o bucata de piese (8.0) bate una de fier: veriga care tine venitul e acum turnatoria
            check.equal(f.bottleneck, "foundry")
            -- fara tine, linia de mana sta
            local idle = ChainMath.flowWith(m, s, true)
            check.equal(idle.lines.parts.delivered, 0)
            check.equal(idle.capacity.market, 0)
        end)

        test.case("aceeasi linie cu oameni: plasa ei devine marginea", function()
            -- cate doi, treapta 5: drumurile 3 x 5 x 2 = 30, turnatoria 2 x 5 x 2 = 20, negustorul 5 x 5 x 2 = 50
            local m = probeModel()
            local s = probeState(1.0, nil)
            staff(s, PARTS, 2, 5)
            staff(s, { "merchant" }, 2, 5)
            local f = ChainMath.flowWith(m, s)
            near(valueAt(f.lines.parts, m, "parts", "partsHaul"), 30.0)
            near(valueAt(f.lines.parts, m, "parts", "foundry"), 20.0)
            near(f.capacity.market, 50.0)
            near(f.lines.parts.delivered, 1.0)
            check.equal(f.lines.parts.bottleneck, "nets")
            near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 8.0)
            -- cu toti oamenii ei, linia merge si fara tine
            near(ChainMath.flowWith(m, s, true).lines.parts.delivered, 1.0)
        end)

        test.case(
            "doua linii la acelasi al doilea vanzator: cea scumpa intai, cealalta ia restul",
            function()
                -- Piata cu un negustor de treapta 1 duce 5.0. Cuprul (12) e primul: plasa lui da 3.0, raman 2.0. Piesele
                -- ar putea 4.0, dar primesc 2.0: Piata le tine. Cupru in plus ar lua locul pieselor: 12 - 8 = 4. Piata in
                -- plus ar vinde piese: 8. Deci veriga care tine venitul e Piata.
                local m = probeModel()
                local s = probeState(4.0, 3.0)
                staff(s, PARTS, 2, 5)
                staff(s, COPPER, 2, 5)
                staff(s, { "merchant" }, 1, 1)
                local before = ChainMath.rates(s)
                local f = ChainMath.flowWith(m, s)
                near(f.lines.copper.delivered, 3.0)
                near(f.lines.parts.delivered, 2.0)
                check.equal(f.lines.parts.bottleneck, "market")
                check.equal(f.lines.copper.bottleneck, "nets")
                check.equal(f.bottleneck, "market")
                near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 52.0)
                check.equal(f.lines.wood.delivered, before.wood)
                check.equal(f.lines.iron.delivered, before.scrap)
                -- Piata largita (negustor de treapta 2: 10.0): amandoua curg cat prind
                staff(s, { "merchant" }, 1, 2)
                local wide = ChainMath.flowWith(m, s)
                near(wide.lines.parts.delivered, 4.0)
                check.equal(wide.lines.parts.bottleneck, "nets")
                near(ChainMath.valueWith(m, s, wide) - ChainMath.income(s), 68.0)
            end
        )
    end)
end
