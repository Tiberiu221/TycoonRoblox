local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local TycoonMath = require("../src/Shared/Modules/TycoonMath")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

-- Valorile de aur, din scripts/economy/sim_tycoon.py (tura 1, lacom) [F0 spec 1.2]. Daca vreuna
-- nu cade exact, se cauta diferenta de portare -- nu se relaxeaza testul si nu se atinge sim-ul.
local GOLD_PRICES = {
    0,
    9,
    18,
    25,
    40,
    50,
    80,
    130,
    200,
    220,
    300,
    450,
    550,
    750,
    1200,
    1500,
    2000,
    2500,
    3500,
    4000,
    6000,
    7500,
    9000,
    12000,
    15000,
    20000,
    25000,
    28000,
    30000,
    35000,
    40000,
    45000,
    50000,
    55000,
    60000,
    70000,
    75000,
    80000,
    90000,
    100000,
    110000,
    120000,
    130000,
    150000,
    160000,
    180000,
    200000,
    220000,
}
local GOLD_TIMES = {
    0,
    23,
    48,
    77,
    110,
    144,
    183,
    228,
    280,
    334,
    395,
    469,
    550,
    637,
    736,
    850,
    983,
    1124,
    1297,
    1477,
    1689,
    1924,
    2196,
    2487,
    2803,
    3189,
    3604,
    4045,
    4447,
    4867,
    5301,
    5708,
    6112,
    6551,
    7011,
    7516,
    7967,
    8400,
    8850,
    9327,
    9781,
    10241,
    10723,
    11244,
    11687,
    12156,
    12557,
    12971,
}
local GOLD_INCOMES = {
    0.39963,
    0.740056,
    0.866922,
    1.210702,
    1.452842,
    2.05524,
    2.941776,
    3.824309,
    4.053767,
    4.91314,
    6.141424,
    6.755567,
    8.636956,
    12.130964,
    13.166857,
    15.069944,
    17.718349,
    20.191911,
    22.310636,
    28.234388,
    31.999095,
    33.022928,
    41.27866,
    47.470459,
    51.858671,
    60.16882,
    63.574602,
    74.625642,
    83.406177,
    92.094947,
    110.513936,
    123.766427,
    125.25351,
    130.46402,
    138.578412,
    166.294094,
    185.038358,
    199.795691,
    210.001653,
    242.230074,
    260.974338,
    269.266683,
    288.431756,
    360.539695,
    383.970025,
    499.161032,
    531.233324,
    664.041656,
}

return function()
    test.suite("TycoonMath - paritate cu simulatorul", function()
        local rows = TycoonMath.greedyRun()

        test.case("48 de randuri, un rand per platforma", function()
            check.equal(#rows, 48)
        end)

        test.case("preturile cad exact ca in simulator", function()
            for i, row in rows do
                check.equal(row.price, GOLD_PRICES[i])
            end
        end)

        test.case("timpii de cumparare (secunde, lacom) cad exact", function()
            for i, row in rows do
                check.equal(row.t, GOLD_TIMES[i])
            end
        end)

        test.case("venitul dupa fiecare cumparare e in limita de 1e-6", function()
            for i, row in rows do
                check.is_true(math.abs(row.income - GOLD_INCOMES[i]) < 1e-6)
            end
        end)

        test.case(
            "regula celor patru motive: fiecare platforma k>1 creste venitul cu >0.5%",
            function()
                for i = 2, #rows do
                    check.is_true(rows[i].income > rows[i].before * 1.005)
                end
            end
        )

        test.case("preturile cresc strict", function()
            for i = 2, #rows do
                check.is_true(rows[i].price > rows[i - 1].price)
            end
        end)

        test.case("primele 5 platforme in cel mult 110s lacom [spec 18/24]", function()
            check.is_true(rows[5].t <= 110)
        end)

        test.case("cea mai lunga asteptare intre doua cumparari e sub 540s lacom", function()
            local longest = 0
            for i = 2, #rows do
                longest = math.max(longest, rows[i].t - rows[i - 1].t)
            end
            check.is_true(longest <= 540)
        end)

        test.case("scara renasterii: tura 2 si tura 3 termina sub 2 ore lacom", function()
            local r2 = TycoonMath.greedyRun(1, 12, 3, GOLD_PRICES)
            local r3 = TycoonMath.greedyRun(2, 24, 4, GOLD_PRICES)
            check.equal(#r2, 36) -- se opreste dupa Era 3
            check.equal(#r3, 48) -- se opreste dupa Era 4
            check.is_true(r2[#r2].t <= 7200)
            check.is_true(r3[#r3].t <= 7200)
            -- valori exacte, verificate separat cu simulatorul (1h15m15s si 1h28m48s)
            check.equal(r2[#r2].t, 4515)
            check.equal(r3[#r3].t, 5328)
        end)
    end)

    test.suite("TycoonMath.income - reteaua de energie", function()
        test.case(
            "doua statii active: energia merge la castigul cel mai mare pe unitate",
            function()
                -- comparat manual cu sim_tycoon.py: State(lanes=2, nets=[.33,.33,.33,.4,.4,.45], flow=5,
                -- stations={driftwood:[3,1.6,4], scrap:[3,1,5]}) -> income() = 4.323200000000001
                local s = TycoonMath.newState()
                s.lanes = 2
                s.nets = { 0.33, 0.33, 0.33, 0.4, 0.4, 0.45 }
                s.flow = 5
                s.stations.driftwood = { mult = 3.0, cap = 1.6, draw = 4.0 }
                s.stations.scrap = { mult = 3.0, cap = 1.0, draw = 5.0 }
                local inc = TycoonMath.income(s)
                check.is_true(math.abs(inc - 4.323200000000001) < 1e-6)
            end
        )

        test.case("fara plase, venitul e zero", function()
            check.equal(TycoonMath.income(TycoonMath.newState()), 0)
        end)
    end)

    test.suite("TycoonMath.stateFor", function()
        test.case("live=true ignora efectele indexFound (Index-ul real le inlocuieste)", function()
            local bought = { workshop = true } -- Workshop: plus(index_found, 6)
            local sLive = TycoonMath.stateFor(bought, 0, 100, true)
            check.equal(sLive.indexFound, 100)

            local sSim = TycoonMath.stateFor(bought, 0, 100, false)
            check.equal(sSim.indexFound, 106)
        end)

        test.case("aplica efectele in ordinea PADS (Sawmill inainte de Sawmill II)", function()
            local bought = { sawmill = true, sawmill_2 = true }
            local s = TycoonMath.stateFor(bought, 0, 0)
            check.equal(s.stations.driftwood.cap, 1.6 * 2.0) -- upgrade dupa build
        end)
    end)

    test.suite("TycoonMath.padStatuses", function()
        test.case("profil proaspat: primele doua plase available, Bigger Sack outline", function()
            local statuses = TycoonMath.padStatuses({})
            check.equal(statuses.first_net, "available")
            check.equal(statuses.second_net, "available")
            check.equal(statuses.bigger_sack, "outline")
            check.equal(statuses.third_net, nil) -- ascunsa, dupa a treia eligibila
        end)

        test.case("dupa primele 5, drumul se opreste la First Runner (outline)", function()
            local bought = {
                first_net = true,
                second_net = true,
                bigger_sack = true,
                third_net = true,
                sorting_crate = true,
            }
            local statuses = TycoonMath.padStatuses(bought)
            check.equal(statuses.first_runner, "outline")
            check.equal(statuses.far_lane_net, nil) -- nu s-a ajuns la ea
        end)

        test.case(
            "clopotul e eligibil doar cand e ultima necumparata; nimic din era 2 inainte",
            function()
                local bought = {}
                for _, p in TycoonConfig.PADS do
                    if p.era == 1 and p.id ~= "landing_bell" then
                        bought[p.id] = true
                    end
                end
                local statuses = TycoonMath.padStatuses(bought)
                check.equal(statuses.landing_bell, "outline")
                check.equal(statuses.sawmill, nil)
            end
        )

        -- In F0 clopotele nu sunt live, deci testul de mai sus le vede doar ca "opritor". Aici toate
        -- platformele sunt live, ca in fazele urmatoare: clopotul nu are voie sa sara coada erei.
        local allLive: { TycoonConfig.Pad } = {}
        for _, p in TycoonConfig.PADS do
            local copy = table.clone(p)
            copy.live = true
            table.insert(allLive, copy)
        end
        local function boughtEra1Except(...: string): { [string]: boolean }
            local skip = {}
            for _, id in { ... } do
                skip[id] = true
            end
            local bought = {}
            for _, p in TycoonConfig.PADS do
                if p.era == 1 and not skip[p.id] then
                    bought[p.id] = true
                end
            end
            return bought
        end

        test.case("clopot live: nu se cumpara cat timp mai e ceva din era lui", function()
            local statuses =
                TycoonMath.padStatuses(boughtEra1Except("dock_stall", "landing_bell"), allLive)
            check.equal(statuses.dock_stall, "available")
            check.equal(statuses.landing_bell, "outline")
            check.equal(statuses.sawmill, nil)
        end)

        test.case("clopot live: devine available cand e ultima din era", function()
            local statuses = TycoonMath.padStatuses(boughtEra1Except("landing_bell"), allLive)
            check.equal(statuses.landing_bell, "available")
            check.equal(statuses.sawmill, nil) -- era 2 se deschide abia dupa clopot
        end)

        test.case("clopot live: dupa el se deschide era urmatoare", function()
            local statuses = TycoonMath.padStatuses(boughtEra1Except(), allLive)
            check.equal(statuses.sawmill, "available")
            check.equal(statuses.water_wheel, "available")
            check.equal(statuses.flume, "outline")
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
            check.equal(n, 48) -- toate "bought", nimic altceva
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
            check.equal(TycoonMath.itemValue("scrap", nil, s), 2.0)
            check.equal(TycoonMath.itemValue("named", "rare", s), 22)
            check.equal(TycoonMath.itemValue("named", nil, s), 14) -- fallback fara tier
            s.namedMult = 1.5
            check.is_true(math.abs(TycoonMath.itemValue("named", "rare", s) - 33) < 1e-9)
        end)

        test.case("formatNumber: floor, plain sub 1000, K/M/B ca big()", function()
            check.equal(TycoonMath.formatNumber(0), "0")
            check.equal(TycoonMath.formatNumber(950.7), "950")
            check.equal(TycoonMath.formatNumber(999), "999")
            check.equal(TycoonMath.formatNumber(1000), "1K")
            check.equal(TycoonMath.formatNumber(1200), "1.2K")
            check.equal(TycoonMath.formatNumber(12000), "12K")
            check.equal(TycoonMath.formatNumber(1500000), "1.5M")
        end)

        test.case("formatRate: sub 10 cu o zecimala, altfel ca formatNumber", function()
            check.equal(TycoonMath.formatRate(0.39963), "0.4")
            check.equal(TycoonMath.formatRate(5), "5.0")
            check.equal(TycoonMath.formatRate(15), "15")
        end)
    end)
end
