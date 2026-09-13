-- Paritate cu simulatorul. ChainMath e un PORT al lui scripts/economy/sim_tycoon.py: daca cele
-- doua se despart fie si la ultimul bit, jocul incepe sa afiseze alte cifre decat cele pe care s-a
-- facut balansul. Valorile de mai jos sunt tiparite de simulator (repr) si copiate aici ca atare.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StationConfig = require("../src/Shared/Config/StationConfig")
local ChainMath = require("../src/Shared/Modules/ChainMath")

type CrewSpec = { [string]: { number } }

local function state(
    levels: { number },
    saw: number,
    dock: number,
    sack: boolean,
    crews: CrewSpec?
): ChainMath.State
    local s = ChainMath.empty()
    for i, lv in levels do
        table.insert(s.nets, {
            base = ChainMath.netBase(i),
            baseLane = StationConfig.NET_LANES[i],
            level = lv,
        })
    end
    s.sawLevel = saw
    s.dockLevel = dock
    s.sackBig = sack
    for role, spec in crews or {} do
        s.crews[role] = { count = spec[1], tier = spec[2] }
    end
    return s
end

-- (nume, plase, gater, debarcader, traista, oameni {rol = {cati, treapta}},
--  debite {prindere, adunat, dus la gater, taiat, dus la debarcader, vandut, livrat},
--  gatuire, valoare medie, venit)
local GOLDEN = {
    {
        name = "o plasa nivel 1, totul de mana",
        nets = { 1 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = {},
        rates = { 0.33, 0.9, 0.9, 0.6, 0.9, 1.0499999999999998, 0.33 },
        bottleneck = "nets",
        avg = 1.73,
        income = 0.5709000000000001,
    },
    {
        name = "doua plase nivel 5",
        nets = { 5, 5 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = {},
        rates = { 0.9055200000000001, 0.9, 0.9, 0.6, 0.9, 1.0499999999999998, 0.6 },
        bottleneck = "saw",
        avg = 1.73,
        income = 1.038,
    },
    {
        name = "Collector angajat: restul pasilor primesc mai mult din timpul tau",
        nets = { 5, 5 },
        saw = 1,
        dock = 1,
        sack = false,
        crews = { collector = { 1, 1 } },
        rates = {
            0.9055200000000001,
            4.0,
            1.2,
            0.7999999999999999,
            1.2,
            1.0499999999999998,
            0.7999999999999999,
        },
        bottleneck = "saw",
        avg = 1.73,
        income = 1.384,
    },
    {
        name = "traista mare pe pasii de mana",
        nets = { 10, 8 },
        saw = 3,
        dock = 2,
        sack = true,
        crews = { collector = { 1, 1 }, porter = { 1, 1 } },
        rates = { 1.417185, 4.0, 6.0, 1.344, 2.7, 1.113, 1.113 },
        bottleneck = "dock",
        avg = 1.8599999999999999,
        income = 2.0701799999999997,
    },
    {
        name = "toti oamenii, trepte diferite",
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
        rates = { 5.725089273750001, 40.0, 18.0, 6.816, 36.0, 8.52, 5.725089273750001 },
        bottleneck = "nets",
        avg = 1.92,
        income = 10.9921714056,
    },
    {
        name = "fara Negustor: debarcaderul merge la o treime",
        nets = { 10, 10 },
        saw = 20,
        dock = 5,
        sack = false,
        crews = { collector = { 1, 2 }, porter = { 1, 2 }, sawyer = { 1, 1 }, hauler = { 1, 1 } },
        rates = {
            2.05359,
            8.0,
            12.0,
            10.271999999999998,
            9.0,
            1.3019999999999998,
            1.3019999999999998,
        },
        bottleneck = "dock",
        avg = 1.8599999999999999,
        income = 2.4217199999999997,
    },
    {
        name = "gaterul de mana e gatuirea",
        nets = { 10, 10 },
        saw = 1,
        dock = 10,
        sack = false,
        crews = { collector = { 1, 1 }, porter = { 1, 1 }, hauler = { 1, 1 } },
        rates = { 2.05359, 4.0, 6.0, 2.4, 9.0, 3.234, 2.05359 },
        bottleneck = "nets",
        avg = 1.8599999999999999,
        income = 3.8196773999999993,
    },
    {
        name = "prag 25 pe toate, echipaj la maxim",
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
        },
        rates = { 27.29391159, 40.0, 60.0, 234.24, 90.0, 292.8, 27.29391159 },
        bottleneck = "nets",
        avg = 1.92,
        income = 52.4043102528,
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
    }
    -- urmatoarea angajare, in ordinea raului
    for _, role in StationConfig.MANUAL_ROLES do
        if s.crews[role].count == 0 then
            table.insert(out, function(st)
                st.crews[role].count = 1
            end)
            break
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

return function()
    test.suite("ChainMath - paritate cu simulatorul", function()
        for _, g in GOLDEN do
            test.case(g.name, function()
                local s = state(g.nets, g.saw, g.dock, g.sack, g.crews :: any)
                local r = ChainMath.rates(s)
                check.equal(r.catch, g.rates[1])
                check.equal(r.collect, g.rates[2])
                check.equal(r.port, g.rates[3])
                check.equal(r.sawing, g.rates[4])
                check.equal(r.haul, g.rates[5])
                check.equal(r.sales, g.rates[6])
                check.equal(r.delivered, g.rates[7])
                check.equal(r.bottleneck, g.bottleneck)
                check.equal(ChainMath.avgValue(s), g.avg)
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
            -- primea tot timpul tau, iar cu o baza prea mica angajarea lui taia venitul [D49]
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
                            -- cladirile mari: gatuirea sta pe pasii oamenilor, unde e riscul
                            for _, big in { 1, 40 } do
                                local s =
                                    state({ 8 * big, 6 * big, 4 * big }, big, big, sack, crews)
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
            check.is_true(checked > 200)
            check.equal(drops, 0)
        end)

        test.case("fiecare angajare iti da inapoi timp pentru ceilalti pasi", function()
            local s = state({ 40, 40 }, 40, 40, false)
            local share = ChainMath.playerShare(s)
            check.equal(share, StationConfig.PLAYER_LABOR / 4)
            s.crews.collector.count = 1
            check.is_true(ChainMath.playerShare(s) > share)
            for _, role in StationConfig.MANUAL_ROLES do
                s.crews[role].count = 1
            end
            check.equal(ChainMath.playerShare(s), 0)
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

        test.case("gatuirea chiar se roteste intre toate sase verigile", function()
            -- daca o veriga nu ajunge niciodata gatuire, semnul de avertizare de pe ea e decor --
            -- iar pentru o meserie, un meniu intreg care ar scrie "No gain yet" toata era
            local seen = {}
            for lv = 1, 40, 3 do
                for _, dock in { 1, 6, 30 } do
                    for _, saw in { 1, 8, 40 } do
                        for hired = 0, #StationConfig.MANUAL_ROLES do
                            local crews: CrewSpec = { trader = { 1, 1 } }
                            for i = 1, hired do
                                crews[StationConfig.MANUAL_ROLES[i]] = { 1, 1 }
                            end
                            local s = state({ lv, lv }, saw, dock, false, crews)
                            seen[ChainMath.rates(s).bottleneck] = true
                        end
                    end
                end
            end
            for _, link in StationConfig.LINKS do
                check.is_true(seen[link] == true)
            end
        end)

        test.case("venitul pasiv cere toate cinci meseriile", function()
            -- fara oricare om, lantul e taiat: plasele se umplu, dar n-are cine sa adune, sa duca,
            -- sa taie sau sa vanda [D49]
            local all: CrewSpec = {}
            for _, role in StationConfig.ROLES do
                all[role] = { 1, 1 }
            end
            check.is_true(ChainMath.idleIncome(state({ 12, 12 }, 8, 8, false, all)) > 0)
            for _, missing in StationConfig.ROLES do
                local crews: CrewSpec = {}
                for _, role in StationConfig.ROLES do
                    if role ~= missing then
                        crews[role] = { 1, 1 }
                    end
                end
                check.equal(ChainMath.idleIncome(state({ 12, 12 }, 8, 8, false, crews)), 0)
            end
        end)

        test.case("venitul pasiv nu il depaseste niciodata pe cel activ", function()
            -- tu te ADAUGI pe pasii fara om, deci prezenta ta nu poate scadea nimic
            local worse = 0
            for hired = 0, #StationConfig.MANUAL_ROLES do
                for _, tier in { 1, 4 } do
                    local crews: CrewSpec = { trader = { 1, tier } }
                    for i = 1, hired do
                        crews[StationConfig.MANUAL_ROLES[i]] = { 1, tier }
                    end
                    local s = state({ 10, 8, 6 }, 6, 6, false, crews)
                    if ChainMath.idleIncome(s) > ChainMath.income(s) + 1e-9 then
                        worse += 1
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

        test.case("benzile mai departate aduc marfuri mai valoroase", function()
            local near = state({ 1 }, 1, 1, false)
            local far = state({ 25 }, 1, 1, false)
            check.is_true(ChainMath.avgValue(far) > ChainMath.avgValue(near))
        end)
    end)
end
