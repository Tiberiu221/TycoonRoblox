-- Paritate cu simulatorul. ChainMath e un PORT al lui scripts/economy/sim_tycoon.py: daca cele
-- doua se despart fie si la ultimul bit, jocul incepe sa afiseze alte cifre decat cele pe care s-a
-- facut balansul. Valorile de mai jos le tipareste scripts/economy/golden_chain.py [D55, D56].
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local StationConfig = require("../src/Shared/Config/StationConfig")
local ChainMath = require("../src/Shared/Modules/ChainMath")

type CrewSpec = { [string]: { number } }

-- [D65] Starile Erei 2, in forma generica (pe linii): le tipareste `python3 scripts/economy/golden_chain.py --era2`.
-- Tabelul GOLDEN de mai jos ramane contractul Erei 1 si nu se atinge.
local GOLDEN_ERA2 = {
    {
        name = "Era 1 incheiata, Moara inca inchisa: liniile ei nu exista",
        nets = { 32, 30, 28, 26, 27 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = false,
        furnace = false,
        foundry = 1,
        furnaceLevel = 1,
        market = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 1.0499999999999998, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 66.88925090925,
    },
    {
        name = "roata de apa fara plasa a sasea: piesele nu exista",
        nets = { 32, 30, 28, 26, 27 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = false,
        foundry = 1,
        furnaceLevel = 1,
        market = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 1.0499999999999998, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 66.88925090925,
    },
    {
        name = "turul de mana al pieselor: patru pasi, timpul tau intreg pe ei",
        nets = { 32, 30, 28, 26, 27, 1 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = false,
        foundry = 1,
        furnaceLevel = 1,
        market = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 0.33,
                values = { 1.35, 1.35, 0.6, 1.35 },
                delivered = 0.33,
                bottleneck = "nets",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 1.0499999999999998, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 1700.38925090925,
    },
    {
        name = "Mill Collector si Mill Porter angajati: turnatoria de mana e gatuirea",
        nets = { 32, 30, 28, 26, 27, 10 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = false,
        foundry = 1,
        furnaceLevel = 1,
        market = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 1, 3 },
            millPorter = { 1, 3 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 0.8382000000000001,
                values = { 12.0, 18.0, 1.2, 2.7 },
                delivered = 0.8382000000000001,
                bottleneck = "nets",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 1.0499999999999998, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 4215.97925090925,
    },
    {
        name = "toti oamenii pieselor, fara Merchant: Piata merge la o treime",
        nets = { 32, 30, 28, 26, 27, 12, 9 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = false,
        foundry = 6,
        furnaceLevel = 1,
        market = 3,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 1, 2 },
            millPorter = { 1, 2 },
            founder = { 1, 1 },
            partsHauler = { 1, 1 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 1.4711400000000001,
                values = { 8.0, 12.0, 3.12, 9.0 },
                delivered = 1.176,
                bottleneck = "market",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 1.176, depot = 1.0499999999999998 },
        bottleneck = "market",
        income = 5888.08925090925,
    },
    {
        name = "patru plase ale Morii, oameni pe trepte diferite, cuptorul fara plasa de minereu",
        nets = { 32, 30, 28, 26, 27, 30, 28, 25, 20 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 14,
        furnaceLevel = 1,
        market = 12,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 1, 3 },
            founder = { 1, 2 },
            partsHauler = { 1, 4 },
            merchant = { 1, 2 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 13.865241225,
                values = { 40.0, 18.0, 17.088, 36.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            copper = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 19.919999999999998, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 68699.83331465925,
    },
    {
        name = "turul de mana al cuprului, langa piesele cu toti oamenii",
        nets = { 32, 30, 28, 26, 27, 30, 28, 25, 20, 1 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 30,
        furnaceLevel = 1,
        market = 30,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 13.865241225,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            copper = {
                catch = 1.4587670625,
                values = { 1.35, 1.35, 0.3, 1.35 },
                delivered = 0.3,
                bottleneck = "furnace",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 328.8, depot = 1.0499999999999998 },
        bottleneck = "furnace",
        income = 71894.83331465925,
    },
    {
        name = "Ore Collector si Ore Porter angajati: cuptorul de mana e gatuirea",
        nets = { 32, 30, 28, 26, 27, 30, 28, 25, 20, 10 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 30,
        furnaceLevel = 1,
        market = 30,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 1, 3 },
            orePorter = { 1, 3 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 13.865241225,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            copper = {
                catch = 3.70526833875,
                values = { 6.0, 7.5, 0.6, 2.7 },
                delivered = 0.6,
                bottleneck = "furnace",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 328.8, depot = 1.0499999999999998 },
        bottleneck = "furnace",
        income = 75089.83331465925,
    },
    {
        name = "Piata plina: cuprul intai, piesele din ce ramane",
        nets = { 32, 30, 28, 26, 27, 60, 60, 60, 60, 40 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 60,
        furnaceLevel = 60,
        market = 3,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 55.5855069,
                values = { 40.0, 60.0, 871.68, 90.0 },
                delivered = 20.9379018975,
                bottleneck = "market",
            },
            copper = {
                catch = 12.6620981025,
                values = { 20.0, 25.0, 435.84, 65.0 },
                delivered = 12.6620981025,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 33.6, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 238560.84843515925,
    },
    {
        name = "amandoi vanzatorii plini: taverna tine lemnul, Piata tine piesele",
        nets = { 60, 60, 60, 60, 40, 60, 60, 60, 60, 40 },
        saw = 60,
        dock = 3,
        forge = 60,
        wheel = true,
        furnace = true,
        foundry = 60,
        furnaceLevel = 60,
        market = 3,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 55.5855069,
                values = { 40.0, 60.0, 871.68, 90.0 },
                delivered = 20.9379018975,
                bottleneck = "dock",
            },
            iron = {
                catch = 12.6620981025,
                values = { 20.0, 25.0, 261.50399999999996, 52.0 },
                delivered = 12.6620981025,
                bottleneck = "nets",
            },
            parts = {
                catch = 55.5855069,
                values = { 40.0, 60.0, 871.68, 90.0 },
                delivered = 20.9379018975,
                bottleneck = "market",
            },
            copper = {
                catch = 12.6620981025,
                values = { 20.0, 25.0, 435.84, 65.0 },
                delivered = 12.6620981025,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 33.6, market = 33.6, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 238573.45717064475,
    },
    {
        name = "Copper Hauler-ul de mana e gatuirea cuprului",
        nets = { 32, 30, 28, 26, 27, 40, 40, 40, 40, 30 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 40,
        furnaceLevel = 60,
        market = 40,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 21.77266245,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 21.77266245,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 435.84, 5.4 },
                delivered = 5.4,
                bottleneck = "copperHaul",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.0499999999999998 },
        bottleneck = "copperHaul",
        income = 165351.56837840925,
    },
    {
        name = "prag 25 pe tot cartierul Morii, echipaj la maxim",
        nets = { 32, 30, 28, 26, 27, 25, 25, 25, 25, 25 },
        saw = 30,
        dock = 30,
        forge = 20,
        wheel = true,
        furnace = true,
        foundry = 25,
        furnaceLevel = 25,
        market = 25,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 17.2575942,
                values = { 40.0, 60.0, 234.24, 90.0 },
                delivered = 17.2575942,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.036317389999999,
                values = { 20.0, 25.0, 117.12, 65.0 },
                delivered = 10.036317389999999,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 292.8, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 192378.76074440923,
    },
}

-- [D67] Era 3: liniile Wire Works (bobine, curent) si Depoul, langa Moara incheiata. Regenerat cu
-- `python3 scripts/economy/golden_chain.py --era3`.
local GOLDEN_ERA3 = {
    {
        name = "Moara incheiata, Wire Works inca inchis: liniile lui nu exista",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30 },
        steam = false,
        powerhouse = false,
        wireworks = 1,
        powerhouseLevel = 1,
        depot = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 218247.33507628425,
    },
    {
        name = "masina cu abur fara plasa a unsprezecea: bobinele nu exista",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30 },
        steam = true,
        powerhouse = false,
        wireworks = 1,
        powerhouseLevel = 1,
        depot = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 218247.33507628425,
    },
    {
        name = "turul de mana al bobinelor: patru pasi, timpul tau intreg pe ei",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 1 },
        steam = true,
        powerhouse = false,
        wireworks = 1,
        powerhouseLevel = 1,
        depot = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.33,
                values = { 1.35, 1.35, 0.6, 1.35 },
                delivered = 0.33,
                bottleneck = "nets",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 5118747.335076285,
    },
    {
        name = "Works Collector si Works Porter angajati: Wire Works de mana e gatuirea",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 10 },
        steam = true,
        powerhouse = false,
        wireworks = 1,
        powerhouseLevel = 1,
        depot = 1,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 1, 3 },
            worksPorter = { 1, 3 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 0.8382000000000001,
                values = { 12.0, 18.0, 1.2, 2.7 },
                delivered = 0.8382000000000001,
                bottleneck = "nets",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.0499999999999998 },
        bottleneck = "nets",
        income = 12665517.335076284,
    },
    {
        name = "toti oamenii bobinelor, fara Clerk: Depoul merge la o treime",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 12, 9 },
        steam = true,
        powerhouse = false,
        wireworks = 6,
        powerhouseLevel = 1,
        depot = 3,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 1, 2 },
            worksPorter = { 1, 2 },
            wiredrawer = { 1, 1 },
            coilHauler = { 1, 1 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 1.4711400000000001,
                values = { 8.0, 12.0, 3.12, 9.0 },
                delivered = 1.176,
                bottleneck = "depot",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 1.176 },
        bottleneck = "depot",
        income = 17681847.335076284,
    },
    {
        name = "patru plase ale Wire Works, oameni pe trepte diferite, Power House fara turbina",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 30, 28, 25, 20 },
        steam = true,
        powerhouse = true,
        wireworks = 14,
        powerhouseLevel = 1,
        depot = 12,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 2, 5 },
            worksPorter = { 1, 3 },
            wiredrawer = { 1, 2 },
            coilHauler = { 1, 4 },
            clerk = { 1, 2 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 13.865241225,
                values = { 40.0, 18.0, 17.088, 36.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            power = {
                catch = 0.0,
                values = { 0.0, 0.0, 0.0, 0.0 },
                delivered = 0.0,
                bottleneck = "",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 19.919999999999998 },
        bottleneck = "nets",
        income = 206117079.52632627,
    },
    {
        name = "turul de mana al curentului, langa bobinele cu toti oamenii",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 30, 28, 25, 20, 1 },
        steam = true,
        powerhouse = true,
        wireworks = 30,
        powerhouseLevel = 1,
        depot = 30,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 2, 5 },
            worksPorter = { 2, 5 },
            wiredrawer = { 2, 5 },
            coilHauler = { 2, 5 },
            clerk = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 13.865241225,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            power = {
                catch = 1.4587670625,
                values = { 1.35, 1.35, 0.3, 1.35 },
                delivered = 0.3,
                bottleneck = "powerhouse",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 328.8 },
        bottleneck = "powerhouse",
        income = 215567079.52632627,
    },
    {
        name = "Battery Collector si Battery Porter angajati: Power House de mana e gatuirea",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 30, 28, 25, 20, 10 },
        steam = true,
        powerhouse = true,
        wireworks = 30,
        powerhouseLevel = 1,
        depot = 30,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 2, 5 },
            worksPorter = { 2, 5 },
            wiredrawer = { 2, 5 },
            coilHauler = { 2, 5 },
            clerk = { 2, 5 },
            batteryCollector = { 1, 3 },
            batteryPorter = { 1, 3 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 13.865241225,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 13.865241225,
                bottleneck = "nets",
            },
            power = {
                catch = 3.70526833875,
                values = { 6.0, 7.5, 0.6, 2.7 },
                delivered = 0.6,
                bottleneck = "powerhouse",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 328.8 },
        bottleneck = "powerhouse",
        income = 225017079.52632627,
    },
    {
        name = "Depoul plin: curentul intai, bobinele din ce ramane",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 60, 60, 60, 60, 40 },
        steam = true,
        powerhouse = true,
        wireworks = 60,
        powerhouseLevel = 60,
        depot = 3,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 2, 5 },
            worksPorter = { 2, 5 },
            wiredrawer = { 2, 5 },
            coilHauler = { 2, 5 },
            clerk = { 2, 5 },
            batteryCollector = { 2, 5 },
            batteryPorter = { 2, 5 },
            electrician = { 2, 5 },
            powerHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 55.5855069,
                values = { 40.0, 60.0, 871.68, 90.0 },
                delivered = 20.9379018975,
                bottleneck = "depot",
            },
            power = {
                catch = 12.6620981025,
                values = { 20.0, 25.0, 435.84, 65.0 },
                delivered = 12.6620981025,
                bottleneck = "nets",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 33.6 },
        bottleneck = "nets",
        income = 710002180.7417014,
    },
    {
        name = "prag 25 pe tot cartierul Wire Works, echipaj la maxim",
        nets = { 32, 30, 28, 26, 27, 40, 38, 36, 34, 30, 25, 25, 25, 25, 25 },
        steam = true,
        powerhouse = true,
        wireworks = 25,
        powerhouseLevel = 25,
        depot = 25,
        crews = {
            collector = { 2, 5 },
            porter = { 2, 5 },
            sawyer = { 2, 5 },
            hauler = { 2, 5 },
            trader = { 2, 5 },
            scrapCollector = { 2, 5 },
            scrapPorter = { 2, 5 },
            smelter = { 2, 3 },
            ironHauler = { 2, 4 },
            millCollector = { 2, 5 },
            millPorter = { 2, 5 },
            founder = { 2, 5 },
            partsHauler = { 2, 5 },
            merchant = { 2, 5 },
            oreCollector = { 2, 5 },
            orePorter = { 2, 5 },
            coppersmith = { 2, 5 },
            copperHauler = { 2, 5 },
            worksCollector = { 2, 5 },
            worksPorter = { 2, 5 },
            wiredrawer = { 2, 5 },
            coilHauler = { 2, 5 },
            clerk = { 2, 5 },
            batteryCollector = { 2, 5 },
            batteryPorter = { 2, 5 },
            electrician = { 2, 5 },
            powerHauler = { 2, 5 },
        },
        lines = {
            wood = {
                catch = 18.19239675,
                values = { 40.0, 60.0, 263.04, 90.0 },
                delivered = 18.19239675,
                bottleneck = "nets",
            },
            iron = {
                catch = 10.386421485,
                values = { 20.0, 25.0, 30.815999999999995, 52.0 },
                delivered = 10.386421485,
                bottleneck = "nets",
            },
            parts = {
                catch = 20.60043315,
                values = { 40.0, 60.0, 320.64, 90.0 },
                delivered = 20.60043315,
                bottleneck = "nets",
            },
            copper = {
                catch = 10.9115776275,
                values = { 20.0, 25.0, 160.32, 65.0 },
                delivered = 10.9115776275,
                bottleneck = "nets",
            },
            coils = {
                catch = 17.2575942,
                values = { 40.0, 60.0, 234.24, 90.0 },
                delivered = 17.2575942,
                bottleneck = "nets",
            },
            power = {
                catch = 10.036317389999999,
                values = { 20.0, 25.0, 117.12, 65.0 },
                delivered = 10.036317389999999,
                bottleneck = "nets",
            },
        },
        capacity = { dock = 328.8, market = 400.79999999999995, depot = 292.8 },
        bottleneck = "nets",
        income = 572637518.9900763,
    },
}

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

    -- [D65] Aceeasi paritate la bit, pe starile Erei 2: liniile Morii (piese, cupru) si Piata, langa Era 1 incheiata.
    test.suite("ChainMath - paritate cu simulatorul, Era 2 [D65]", function()
        for _, g in GOLDEN_ERA2 do
            test.case(g.name, function()
                local s = state(g.nets, g.saw, g.dock, true, g.crews :: any, { true, g.forge })
                s.wheel, s.furnace = g.wheel, g.furnace
                s.foundryLevel, s.furnaceLevel, s.marketLevel = g.foundry, g.furnaceLevel, g.market
                local f = ChainMath.flow(s)
                for line, want in g.lines :: { [string]: any } do
                    local got = f.lines[line]
                    check.equal(got.catch, want.catch)
                    check.equal(got.delivered, want.delivered)
                    check.equal(got.bottleneck, want.bottleneck)
                    check.equal(#got.values, #want.values)
                    for k, value in want.values do
                        check.equal(got.values[k], value)
                    end
                end
                for seller, capacity in g.capacity :: { [string]: number } do
                    check.equal(f.capacity[seller], capacity)
                end
                check.equal(f.bottleneck, g.bottleneck)
                check.equal(ChainMath.income(s), g.income)
                -- vederea plata a Erei 1 spune acelasi lucru despre liniile ei
                local r = ChainMath.ratesOf(f)
                check.equal(r.wood, g.lines.wood.delivered)
                check.equal(r.scrap, g.lines.iron.delivered)
                check.equal(r.sales, g.capacity.dock)
            end)
        end

        test.case(
            "plasele Erei 2: baza celei de-a k-a plase a Erei 1, nivelurile de ERA2_MULT ori mai scumpe",
            function()
                for k = 1, StationConfig.NETS_PER_ERA do
                    check.equal(ChainMath.netBase(k + 5), ChainMath.netBase(k))
                    check.equal(
                        ChainMath.netUpgradeBase(k + 5),
                        ChainMath.netUpgradeBase(k) * StationConfig.ERA2_MULT
                    )
                end
                local m = StationConfig.ERA2_MULT -- [D66] 3000
                check.equal(ChainMath.netUpgradeBase(6), 1 * m)
                check.equal(ChainMath.tierCost(1, "millCollector"), 25 * m)
                check.equal(ChainMath.tierCost(4, "copperHauler"), 675 * m)
                check.equal(ChainMath.tierCost(2, "collector"), 75)
                check.equal(ChainMath.tierCost(2), 75)
            end
        )
    end)

    -- [D67] Aceeasi paritate la bit, pe starile Erei 3: liniile Wire Works (bobine, curent) si Depoul, langa Moara.
    test.suite("ChainMath - paritate cu simulatorul, Era 3 [D67]", function()
        for _, g in GOLDEN_ERA3 do
            test.case(g.name, function()
                local s = state(g.nets, 30, 30, true, g.crews :: any, { true, 20 })
                s.wheel, s.furnace = true, true
                s.foundryLevel, s.furnaceLevel, s.marketLevel = 40, 40, 40
                s.steam, s.powerhouse = g.steam, g.powerhouse
                s.wireworksLevel, s.powerhouseLevel, s.depotLevel =
                    g.wireworks, g.powerhouseLevel, g.depot
                local f = ChainMath.flow(s)
                for line, want in g.lines :: { [string]: any } do
                    local got = f.lines[line]
                    check.equal(got.catch, want.catch)
                    check.equal(got.delivered, want.delivered)
                    check.equal(got.bottleneck, want.bottleneck)
                    check.equal(#got.values, #want.values)
                    for k, value in want.values do
                        check.equal(got.values[k], value)
                    end
                end
                for seller, capacity in g.capacity :: { [string]: number } do
                    check.equal(f.capacity[seller], capacity)
                end
                check.equal(f.bottleneck, g.bottleneck)
                check.equal(ChainMath.income(s), g.income)
            end)
        end

        test.case(
            "plasele Erei 3: baza celei de-a k-a plase a Erei 1, nivelurile de ERA3_MULT ori mai scumpe",
            function()
                for k = 1, StationConfig.NETS_PER_ERA do
                    check.equal(ChainMath.netBase(k + 10), ChainMath.netBase(k))
                    check.equal(
                        ChainMath.netUpgradeBase(k + 10),
                        ChainMath.netUpgradeBase(k) * StationConfig.ERA3_MULT
                    )
                end
                local m = StationConfig.ERA3_MULT -- 3000 x 3000
                check.equal(m, StationConfig.ERA2_MULT * 3000)
                check.equal(ChainMath.tierCost(1, "worksCollector"), 25 * m)
                check.equal(ChainMath.tierCost(4, "powerHauler"), 675 * m)
                check.equal(ChainMath.tierCost(1, "millCollector"), 25 * StationConfig.ERA2_MULT)
            end
        )
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
            for _, link in StationConfig.ERA_LINKS[1] do
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
            lines.probeA = {
                netKind = "probeA",
                openFlag = "kilnAOwned",
                seller = "stall",
                steps = {
                    { role = "probeACollector", link = "probeACollect", kind = "walk" },
                    { role = "probeAPorter", link = "probeAPort", kind = "walk" },
                    { role = "probeAMaker", link = "kilnA", kind = "processor" },
                    { role = "probeAHauler", link = "probeAHaul", kind = "walk" },
                },
            }
            lines.probeB = {
                netKind = "probeB",
                openFlag = "kilnBOwned",
                seller = "stall",
                steps = {
                    { role = "probeBCollector", link = "probeBCollect", kind = "walk" },
                    { role = "probeBPorter", link = "probeBPort", kind = "walk" },
                    { role = "probeBMaker", link = "kilnB", kind = "processor" },
                    { role = "probeBHauler", link = "probeBHaul", kind = "walk" },
                },
            }
            local processors: { [string]: ChainMath.Processor } = table.clone(GAME.processors)
            processors.kilnA = { base = 2.0, levelField = "kilnALevel" }
            processors.kilnB = { base = 2.0, levelField = "kilnBLevel" }
            local sellers: { [string]: ChainMath.Seller } = table.clone(GAME.sellers)
            sellers.stall = {
                role = "stallkeeper",
                base = 5.0,
                levelField = "stallLevel",
                priority = { "probeB", "probeA" },
            }
            local roleBase = table.clone(GAME.roleBase)
            for _, role in
                {
                    "probeACollector",
                    "probeAPorter",
                    "probeAHauler",
                    "probeBCollector",
                    "probeBPorter",
                    "probeBHauler",
                }
            do
                roleBase[role] = 3.0
            end
            local avg = table.clone(GAME.avg)
            avg.probeA = 8.0
            avg.probeB = 12.0
            return ChainMath.model(
                { "wood", "iron", "parts", "copper", "probeA", "probeB" },
                lines,
                processors,
                { "dock", "market", "stall" },
                sellers,
                roleBase,
                avg
            )
        end

        local PARTS = { "probeACollector", "probeAPorter", "probeAMaker", "probeAHauler" }
        local COPPER = { "probeBCollector", "probeBPorter", "probeBMaker", "probeBHauler" }

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
            s.kilnAOwned = partsNet ~= nil
            s.kilnBOwned = copperNet ~= nil
            s.kilnALevel, s.kilnBLevel, s.stallLevel = 1, 1, 1
            for _, role in PARTS do
                s.crews[role] = { count = 0, tier = 1 }
            end
            for _, role in COPPER do
                s.crews[role] = { count = 0, tier = 1 }
            end
            s.crews.stallkeeper = { count = 0, tier = 1 }
            if partsNet ~= nil then
                table.insert(s.nets, { base = partsNet, baseLane = 1, level = 1, kind = "probeA" })
            end
            if copperNet ~= nil then
                table.insert(s.nets, { base = copperNet, baseLane = 1, level = 1, kind = "probeB" })
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
                    "millCollect",
                    "millPort",
                    "foundry",
                    "partsHaul",
                    "oreCollect",
                    "orePort",
                    "furnace",
                    "copperHaul",
                    "worksCollect",
                    "worksPort",
                    "wireworks",
                    "coilHaul",
                    "batteryCollect",
                    "batteryPort",
                    "powerhouse",
                    "powerHaul",
                    "dock",
                    "market",
                    "depot",
                })
                check.table.equal(StationConfig.ERA_LINKS[1], {
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
                check.table.equal(StationConfig.ERA_LINKS[2], {
                    "nets",
                    "millCollect",
                    "millPort",
                    "foundry",
                    "partsHaul",
                    "oreCollect",
                    "orePort",
                    "furnace",
                    "copperHaul",
                    "market",
                })
                -- [D67] Era 3, The Wire Works
                check.table.equal(StationConfig.ERA_LINKS[3], {
                    "nets",
                    "worksCollect",
                    "worksPort",
                    "wireworks",
                    "coilHaul",
                    "batteryCollect",
                    "batteryPort",
                    "powerhouse",
                    "powerHaul",
                    "depot",
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
                    "millCollector",
                    "millPorter",
                    "founder",
                    "partsHauler",
                    "oreCollector",
                    "orePorter",
                    "coppersmith",
                    "copperHauler",
                    "worksCollector",
                    "worksPorter",
                    "wiredrawer",
                    "coilHauler",
                    "batteryCollector",
                    "batteryPorter",
                    "electrician",
                    "powerHauler",
                })
                check.equal(StationConfig.LINK_OF.merchant, "market")
                check.equal(StationConfig.LINK_OF.clerk, "depot")
                check.equal(StationConfig.LINE_OF.wireworks, "coils")
                check.equal(StationConfig.LINE_OF.powerhouse, "power")
                check.equal(StationConfig.LINE_OF.foundry, "parts")
                check.equal(StationConfig.LINE_OF.market, nil)
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
                s.kilnALevel = 7
                s.kilnAOwned = true
                local copy: any = ChainMath.clone(s)
                check.equal(copy.kilnALevel, 7)
                check.equal(copy.kilnAOwned, true)
                check.equal(copy.sawLevel, 3)
                -- tot clona adanca: ce schimbi in ea nu atinge originalul
                copy.nets[1].level = 40
                copy.crews.collector.count = 2
                copy.kilnALevel = 8
                check.equal(s.nets[1].level, 5)
                check.equal(s.crews.collector.count, 0)
                check.equal(s.kilnALevel, 7)
            end
        )

        test.case(
            "un model in care o linie lipseste din randul vanzatorului ei e refuzat",
            function()
                local lines: { [string]: ChainMath.Line } = table.clone(GAME.lines)
                lines.probeA = { netKind = "probeA", openFlag = nil, seller = "dock", steps = {} }
                local ok = pcall(function()
                    ChainMath.model(
                        { "wood", "iron", "parts", "copper", "probeA" },
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
            check.equal(f.lines.probeA.delivered, 0)
            check.equal(f.lines.probeB.delivered, 0)
            check.equal(f.lines.probeA.bottleneck, "")
            check.equal(f.lines.probeB.bottleneck, "")
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
            near(valueAt(f.lines.probeA, m, "probeA", "probeACollect"), 1.35)
            near(valueAt(f.lines.probeA, m, "probeA", "kilnA"), 0.5)
            near(f.lines.probeA.delivered, 0.5)
            check.equal(f.lines.probeA.bottleneck, "kilnA")
            near(f.capacity.stall, 1.75)
            near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 4.0)
            check.equal(f.lines.wood.delivered, before.wood)
            check.equal(f.lines.iron.delivered, before.scrap)
            check.equal(f.capacity.dock, before.sales)
            -- o bucata de piese (8.0) bate una de fier: veriga care tine venitul e acum turnatoria
            check.equal(f.bottleneck, "kilnA")
            -- fara tine, linia de mana sta
            local idle = ChainMath.flowWith(m, s, true)
            check.equal(idle.lines.probeA.delivered, 0)
            check.equal(idle.capacity.stall, 0)
        end)

        test.case("aceeasi linie cu oameni: plasa ei devine marginea", function()
            -- cate doi, treapta 5: drumurile 3 x 5 x 2 = 30, turnatoria 2 x 5 x 2 = 20, negustorul 5 x 5 x 2 = 50
            local m = probeModel()
            local s = probeState(1.0, nil)
            staff(s, PARTS, 2, 5)
            staff(s, { "stallkeeper" }, 2, 5)
            local f = ChainMath.flowWith(m, s)
            near(valueAt(f.lines.probeA, m, "probeA", "probeAHaul"), 30.0)
            near(valueAt(f.lines.probeA, m, "probeA", "kilnA"), 20.0)
            near(f.capacity.stall, 50.0)
            near(f.lines.probeA.delivered, 1.0)
            check.equal(f.lines.probeA.bottleneck, "nets")
            near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 8.0)
            -- cu toti oamenii ei, linia merge si fara tine
            near(ChainMath.flowWith(m, s, true).lines.probeA.delivered, 1.0)
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
                staff(s, { "stallkeeper" }, 1, 1)
                local before = ChainMath.rates(s)
                local f = ChainMath.flowWith(m, s)
                near(f.lines.probeB.delivered, 3.0)
                near(f.lines.probeA.delivered, 2.0)
                check.equal(f.lines.probeA.bottleneck, "stall")
                check.equal(f.lines.probeB.bottleneck, "nets")
                check.equal(f.bottleneck, "stall")
                near(ChainMath.valueWith(m, s, f) - ChainMath.income(s), 52.0)
                check.equal(f.lines.wood.delivered, before.wood)
                check.equal(f.lines.iron.delivered, before.scrap)
                -- Piata largita (negustor de treapta 2: 10.0): amandoua curg cat prind
                staff(s, { "stallkeeper" }, 1, 2)
                local wide = ChainMath.flowWith(m, s)
                near(wide.lines.probeA.delivered, 4.0)
                check.equal(wide.lines.probeA.bottleneck, "nets")
                near(ChainMath.valueWith(m, s, wide) - ChainMath.income(s), 68.0)
            end
        )
    end)
end
