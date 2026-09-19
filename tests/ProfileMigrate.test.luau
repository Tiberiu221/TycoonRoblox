local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ProfileMigrate = require("../src/Shared/Modules/ProfileMigrate")

local function v2Profile(): { [string]: any }
    return {
        Meta = { version = 2, createdAt = 111, lastSeenAt = 222 },
        Coins = 500,
        Pads = { first_net = true, second_net = true },
        Nets = { first_net = { goods = {}, nextCatchAt = 0, caught = 3 } },
        Index = { lamp = 2 },
    }
end

local PileMath = require("../src/Shared/Modules/PileMath")
local ChainMath = require("../src/Shared/Modules/ChainMath")
local StationConfig = require("../src/Shared/Config/StationConfig")

return function()
    test.suite("PileMath - gramezile ca numaratori", function()
        test.case("o bucata cu nume isi pastreaza catalogul si tier-ul prin gramada", function()
            local counts = {}
            PileMath.addItems(counts, {
                { g = "driftwood" },
                { g = "named", c = "lamp", t = "rare" },
                { g = "driftwood" },
            })
            check.equal(PileMath.total(counts), 3)
            check.equal(counts.driftwood, 2)
            local all = PileMath.take(counts, 10)
            check.equal(#all, 3)
            check.equal(PileMath.total(counts), 0)
            local named = nil
            for _, item in all do
                if item.g == "named" then
                    named = item
                end
            end
            check.not_nil(named)
            check.equal((named :: any).c, "lamp")
            check.equal((named :: any).t, "rare")
        end)

        test.case(
            "take ia cel mult cat se cere, marcheaza taiatul si nu lasa chei goale",
            function()
                local counts = { planks = 3, reeds = 2 }
                local some = PileMath.take(counts, 4, true)
                check.equal(#some, 4)
                for _, item in some do
                    check.is_true(item.p == true)
                end
                check.equal(PileMath.total(counts), 1)
                check.equal(#PileMath.take(counts, 0), 0)
                PileMath.take(counts, 5)
                check.is_true(next(counts) == nil)
            end
        )

        test.case("contents numara pe feluri, fara catalog", function()
            local counts = PileMath.fromItems({
                { g = "named", c = "a", t = "common" },
                { g = "named", c = "b", t = "epic" },
                { g = "reeds" },
                "gunoi" :: any,
            })
            local contents = PileMath.contents(counts)
            check.equal(contents.named, 2)
            check.equal(contents.reeds, 1)
        end)
    end)

    test.suite("ProfileMigrate.toV5 - lantul pe oameni", function()
        local function v4Profile(): { [string]: any }
            return {
                Meta = { version = 4, createdAt = 111, lastSeenAt = 222 },
                Coins = 100,
                Pads = { first_net = true, first_runner = true, dock_trader = true },
                Hands = {
                    first_runner = {
                        id = "first_runner",
                        role = "runner",
                        carry = { { g = "reeds" } },
                    },
                    dock_trader = { id = "dock_trader", role = "trader", carry = {} },
                },
                Stations = {
                    carry = { level = 6 },
                    saw = { level = 3 },
                    dock = { level = 5 },
                    nets = { first_net = { level = 9 } },
                },
                SawmillPile = { items = { { g = "driftwood" }, { g = "driftwood" } }, sawnAt = 7 },
                DockPile = {
                    items = { { g = "planks" }, { g = "named", c = "lamp", t = "rare" } },
                    drainedAt = 8,
                },
                Stats = { sells = 4 },
            }
        end

        test.case("marfa din gramezi se muta intreaga in numaratori", function()
            local data = v4Profile()
            ProfileMigrate.toV5(data)
            check.equal(data.Meta.version, 5)
            check.equal(PileMath.total(data.SawmillPile.counts), 2)
            check.equal(data.SawmillPile.sawnAt, 7)
            check.equal(PileMath.total(data.DockPile.counts), 2)
            check.equal(data.DockPile.counts["named|lamp|rare"], 1)
            check.equal(PileMath.total(data.StoragePile.counts), 0)
            check.equal(PileMath.total(data.PlanksPile.counts), 0)
        end)

        test.case("nivelurile de Carry se dau inapoi in monede, o singura data", function()
            local data = v4Profile()
            local refund = ChainMath.bulkCost(StationConfig.LEGACY_CARRY_UPGRADE_BASE, 1, 5)
            ProfileMigrate.toV5(data)
            check.is_true(refund > 0)
            check.equal(data.Coins, 100 + refund)
            -- Carry ramane in profil, marcata; o a doua trecere nu mai plateste nimic
            check.equal(data.Stations.carry.refunded, refund)
            data.Meta.version = 4
            ProfileMigrate.toV5(data)
            check.equal(data.Coins, 100 + refund)
        end)

        test.case("alergatorul devine Collector si isi pastreaza ce ducea", function()
            local data = v4Profile()
            ProfileMigrate.toV5(data)
            check.equal(data.Hands.first_runner.role, "collector")
            check.equal(#data.Hands.first_runner.carry, 1)
            check.equal(data.Hands.dock_trader.role, "trader")
        end)

        test.case("meseriile pornesc de la treapta 1, nivelurile cladirilor raman", function()
            local data = v4Profile()
            ProfileMigrate.toV5(data)
            for _, role in StationConfig.ROLES do
                check.equal(data.Crews[role].tier, 1)
            end
            check.equal(data.Stations.saw.level, 3)
            check.equal(data.Stations.dock.level, 5)
            check.equal(data.Stations.nets.first_net.level, 9)
            check.equal(data.Stats.sawn, 0)
            check.equal(data.Stats.sells, 4)
        end)

        test.case("e idempotenta si nu atinge un profil deja v5", function()
            local data = v4Profile()
            ProfileMigrate.toV5(data)
            data.Crews.porter.tier = 4
            data.StoragePile.counts.driftwood = 50
            ProfileMigrate.toV5(data)
            check.equal(data.Crews.porter.tier, 4)
            check.equal(data.StoragePile.counts.driftwood, 50)
        end)

        test.case("un profil v2 trece prin toate migrarile si ajunge v5 intreg", function()
            local data: { [string]: any } = {
                Meta = { version = 2, createdAt = 1, lastSeenAt = 2 },
                Coins = 9,
                Pads = { first_net = true },
                Nets = { first_net = { goods = {}, nextCatchAt = 0, caught = 0 } },
            }
            ProfileMigrate.toV3(data)
            ProfileMigrate.toV4(data)
            ProfileMigrate.toV5(data)
            check.equal(data.Meta.version, 5)
            check.equal(data.Coins, 9) -- Carry la nivelul 1: nimic de rambursat
            check.is_true(data.StoragePile ~= nil and data.PlanksPile ~= nil)
            check.equal(data.Crews.collector.tier, 1)
        end)
    end)
    test.suite("ProfileMigrate.toV4 - gaterul", function()
        local function v3Profile(): { [string]: any }
            return {
                Meta = { version = 3, createdAt = 111, lastSeenAt = 222 },
                Coins = 700,
                Pads = { first_net = true },
                Stations = {
                    carry = { level = 4 },
                    dock = { level = 6 },
                    nets = { first_net = { level = 9 } },
                },
                DockPile = { items = { { g = "driftwood" }, { g = "reeds" } }, drainedAt = 5 },
            }
        end

        test.case(
            "NU atinge nimic din ce exista: niveluri, monede, gramada debarcaderului",
            function()
                local data = v3Profile()
                ProfileMigrate.toV4(data)
                check.equal(data.Meta.version, 4)
                check.equal(data.Coins, 700)
                check.equal(data.Stations.carry.level, 4)
                check.equal(data.Stations.dock.level, 6)
                check.equal(data.Stations.nets.first_net.level, 9)
                -- marfa deja livrata se vinde ca pana acum, nu se muta inapoi la gater
                check.equal(#data.DockPile.items, 2)
            end
        )

        test.case("gaterul porneste de la nivelul 1, cu gramada goala", function()
            local data = v3Profile()
            ProfileMigrate.toV4(data)
            check.equal(data.Stations.saw.level, 1)
            check.equal(#data.SawmillPile.items, 0)
        end)

        test.case("e idempotenta", function()
            local data = v3Profile()
            ProfileMigrate.toV4(data)
            data.Stations.saw.level = 12
            data.SawmillPile.items = { { g = "driftwood" } }
            ProfileMigrate.toV4(data)
            check.equal(data.Stations.saw.level, 12)
            check.equal(#data.SawmillPile.items, 1)
        end)

        test.case("un profil v2 trece prin v3 si v4 si ajunge intreg", function()
            local data: { [string]: any } = {
                Meta = { version = 2, createdAt = 1, lastSeenAt = 2 },
                Coins = 9,
                Pads = { first_net = true },
                Nets = { first_net = { goods = {}, nextCatchAt = 0, caught = 0 } },
            }
            ProfileMigrate.toV3(data)
            ProfileMigrate.toV4(data)
            check.equal(data.Meta.version, 4)
            check.equal(data.Stations.carry.level, 1)
            check.equal(data.Stations.saw.level, 1)
            check.equal(data.Stations.nets.first_net.level, 1)
            check.is_true(data.SawmillPile ~= nil)
            check.is_true(data.DockPile ~= nil)
        end)
    end)

    test.suite("ProfileMigrate.toV3 - statii si gramada", function()
        test.case("NU arunca profilul: monedele si platformele raman", function()
            local data = v2Profile()
            ProfileMigrate.toV3(data)
            check.equal(data.Meta.version, 3)
            check.equal(data.Coins, 500)
            check.equal(data.Pads.first_net, true)
            check.equal(data.Index.lamp, 2)
            check.equal(data.Meta.createdAt, 111)
        end)

        test.case("fiecare plasa detinuta primeste nivelul 1", function()
            local data = v2Profile()
            ProfileMigrate.toV3(data)
            check.equal(data.Stations.carry.level, 1)
            check.equal(data.Stations.dock.level, 1)
            check.equal(data.Stations.nets.first_net.level, 1)
        end)

        test.case("gramada porneste goala", function()
            local data = v2Profile()
            ProfileMigrate.toV3(data)
            check.equal(#data.DockPile.items, 0)
        end)

        test.case("e idempotenta: a doua rulare nu schimba nimic", function()
            local data = v2Profile()
            ProfileMigrate.toV3(data)
            data.Stations.dock.level = 7
            data.DockPile.items = { { g = "driftwood" } }
            ProfileMigrate.toV3(data)
            check.equal(data.Stations.dock.level, 7)
            check.equal(#data.DockPile.items, 1)
        end)

        test.case("un profil v1 trece prin v2 si ajunge la v3 curat", function()
            local data: { [string]: any } =
                { Meta = { version = 1, createdAt = 5 }, Index = { a = 1 }, Junk = true }
            ProfileMigrate.toV2(data)
            ProfileMigrate.toV3(data)
            check.equal(data.Meta.version, 3)
            check.is_true(data.Junk == nil)
            check.equal(data.Index.a, 1)
            check.equal(data.Stations.carry.level, 1)
        end)
    end)

    test.suite("ProfileMigrate.toV2", function()
        test.case("un profil v1 pierde tot in afara de Index si Meta.createdAt", function()
            -- Bugul pe care il apara testul: daca Reconcile ar gasi campuri vechi (Materials,
            -- Buildings, Settlers...) alaturi de sablonul v2, ar ramane amestecate in profil si
            -- orice cod care citeste un camp v2 nou ar gasi lipsa, nu un tabel gol.
            local data = {
                Meta = { version = 1, createdAt = 1000, lastSeenAt = 2000 },
                Materials = 42,
                Buildings = { ["1"] = { id = 1 } },
                Settlers = { list = { {} }, nextId = 2 },
                Index = { river_bell = 1, tin_whistle = 2 },
            }
            ProfileMigrate.toV2(data)
            check.equal(data.Meta.version, 2)
            check.equal(data.Meta.createdAt, 1000)
            check.equal(data.Meta.lastSeenAt, 0)
            check.equal(data.Materials, nil)
            check.equal(data.Buildings, nil)
            check.equal(data.Settlers, nil)
            check.equal(data.Index.river_bell, 1)
            check.equal(data.Index.tin_whistle, 2)
        end)

        test.case("un profil fara Meta e tratat ca v1", function()
            local data = { Pile = { ["1"] = {} } }
            ProfileMigrate.toV2(data)
            check.equal(data.Meta.version, 2)
            check.equal(data.Meta.createdAt, 0)
            check.equal(data.Pile, nil)
        end)

        test.case("fara Index, migrarea pune unul gol, nu nil", function()
            -- DataService citeste data.Index direct dupa migrare (inainte de Reconcile); un nil
            -- aici ar rupe orice numarare de chei facuta prematur.
            local data = { Meta = { version = 1, createdAt = 500 } }
            ProfileMigrate.toV2(data)
            check.is_true(data.Index ~= nil)
            check.equal(next(data.Index), nil)
        end)

        test.case("idempotent: a doua trecere nu mai atinge nimic", function()
            local data = {
                Meta = { version = 1, createdAt = 10 },
                Index = { a = 1 },
            }
            ProfileMigrate.toV2(data)
            data.Coins = 99 -- simuleaza joc normal dupa migrare
            ProfileMigrate.toV2(data)
            check.equal(data.Meta.version, 2)
            check.equal(data.Meta.createdAt, 10)
            check.equal(data.Coins, 99)
            check.equal(data.Index.a, 1)
        end)

        test.case("un profil deja v2 nu e atins", function()
            local sack = { items = {} }
            local data = {
                Meta = { version = 2, createdAt = 5, lastSeenAt = 6 },
                Coins = 123,
                Sack = sack,
                Index = {},
            }
            ProfileMigrate.toV2(data)
            check.equal(data.Coins, 123)
            check.equal(data.Meta.lastSeenAt, 6)
            check.is_true(data.Sack == sack)
        end)
    end)

    test.suite("ProfileMigrate.toV6 - nivelurile sunetului [D54]", function()
        local function v5(settings: { [string]: any }?): { [string]: any }
            return { Meta = { version = 5, createdAt = 1, lastSeenAt = 2 }, Settings = settings }
        end

        test.case("muzica oprita ramane oprita: nivelul 0, nu repornita", function()
            local data = v5({ music = false })
            ProfileMigrate.toV6(data)
            check.equal(data.Settings.musicLevel, 0)
            check.equal(data.Settings.soundLevel, 10)
            check.equal(data.Meta.version, 6)
            check.equal(data.Settings.music, false) -- nimic nu se sterge
        end)

        test.case("muzica pornita: nivelul implicit, de fundal", function()
            local data = v5({ music = true })
            ProfileMigrate.toV6(data)
            check.equal(data.Settings.musicLevel, 4)
            check.equal(data.Settings.soundLevel, 10)
        end)

        test.case("fara Settings (profil dinaintea D51): implicitele", function()
            local data = v5(nil)
            ProfileMigrate.toV6(data)
            check.equal(data.Settings.musicLevel, 4)
            check.equal(data.Settings.soundLevel, 10)
        end)

        test.case("idempotenta: a doua trecere si un profil v6 nu schimba nimic", function()
            local data = v5({ music = false })
            ProfileMigrate.toV6(data)
            data.Settings.musicLevel = 7
            ProfileMigrate.toV6(data)
            check.equal(data.Settings.musicLevel, 7)
            local fresh = { Meta = { version = 6 }, Settings = { musicLevel = 2, soundLevel = 3 } }
            ProfileMigrate.toV6(fresh)
            check.equal(fresh.Settings.musicLevel, 2)
            check.equal(fresh.Settings.soundLevel, 3)
        end)
    end)

    test.suite("ProfileMigrate.toV7 - resturile [D55]", function()
        local function v6(): { [string]: any }
            return {
                Meta = { version = 6, createdAt = 1, lastSeenAt = 2 },
                Stations = { saw = { level = 4 }, dock = { level = 3 }, nets = {} },
                StoragePile = { counts = { scrap = 5, driftwood = 9 } },
                Stats = { sawn = 12 },
            }
        end

        test.case("adauga gramezile, forja si numaratoarea, fara sa mute nimic", function()
            local data = v6()
            ProfileMigrate.toV7(data)
            check.equal(data.Meta.version, 7)
            check.equal(next(data.ScrapPile.counts), nil)
            check.equal(next(data.IronPile.counts), nil)
            check.equal(data.ForgePile.smeltedAt, 0)
            check.equal(data.Stations.forge.level, 1)
            check.equal(data.Stats.smelted, 0)
            -- scrap-ul deja prins ramane in depozit: trece prin gater si se vinde, ca inainte
            check.equal(data.StoragePile.counts.scrap, 5)
            check.equal(data.StoragePile.counts.driftwood, 9)
            check.equal(data.Stations.saw.level, 4)
        end)

        test.case("nu atinge ce exista si e idempotenta", function()
            local data = v6()
            data.ScrapPile = { counts = { scrap = 3 } }
            data.Stations.forge = { level = 8 }
            ProfileMigrate.toV7(data)
            check.equal(data.ScrapPile.counts.scrap, 3)
            check.equal(data.Stations.forge.level, 8)
            ProfileMigrate.toV7(data)
            check.equal(data.Meta.version, 7)
        end)

        test.case("un profil deja la v7 ramane neatins", function()
            local fresh = { Meta = { version = 7 }, ScrapPile = { counts = { scrap = 1 } } }
            ProfileMigrate.toV7(fresh)
            check.equal(fresh.ScrapPile.counts.scrap, 1)
            check.equal(fresh.IronPile, nil)
        end)
    end)

    test.suite("ProfileMigrate.toV8 - linia fierului [D56]", function()
        local function v7(): { [string]: any }
            return {
                Meta = { version = 7, createdAt = 1, lastSeenAt = 2 },
                Crews = { collector = { tier = 3 }, porter = { tier = 2 } },
                ScrapPile = { counts = { scrap = 4 } },
                IronPile = { counts = {} },
                Stats = { smelted = 6 },
                Hands = {
                    first_runner = {
                        role = "collector",
                        carry = {
                            { g = "driftwood" },
                            { g = "scrap" },
                            { g = "named", c = "x", t = "rare" },
                        },
                    },
                    hire_hauler = {
                        role = "hauler",
                        carry = { { g = "iron", p = true }, { g = "planks", p = true } },
                    },
                    hire_sawyer = { role = "sawyer", carry = {} },
                },
            }
        end

        test.case(
            "meseriile noi, numaratoarea fierului, iar scrap-ul si fierul din roabe in gramezi",
            function()
                local data = v7()
                ProfileMigrate.toV8(data)
                check.equal(data.Meta.version, 8)
                for _, role in StationConfig.LINE_STEPS.iron do
                    check.equal(data.Crews[role].tier, 1)
                end
                check.equal(data.Crews.collector.tier, 3)
                check.equal(data.Stats.ironSold, 0)
                check.equal(data.Stats.smelted, 6)
                -- nimic nu se pierde: scrap-ul brut la shed (4 + 1), fierul la gramada de fier a forjei
                check.equal(data.ScrapPile.counts.scrap, 5)
                check.equal(data.IronPile.counts.iron, 1)
                check.equal(#data.Hands.first_runner.carry, 2)
                check.equal(data.Hands.first_runner.carry[1].g, "driftwood")
                check.equal(data.Hands.first_runner.carry[2].g, "named")
                check.equal(#data.Hands.hire_hauler.carry, 1)
                check.equal(data.Hands.hire_hauler.carry[1].g, "planks")
            end
        )

        test.case("idempotenta si nu atinge un profil deja la v8", function()
            local data = v7()
            ProfileMigrate.toV8(data)
            ProfileMigrate.toV8(data)
            check.equal(data.ScrapPile.counts.scrap, 5)
            local fresh = { Meta = { version = 8 }, Crews = {} }
            ProfileMigrate.toV8(fresh)
            check.equal(fresh.Crews.smelter, nil)
        end)
    end)

    test.suite("ProfileMigrate.toV9 - pontonul [D59]", function()
        local function v8(): { [string]: any }
            return {
                Meta = { version = 8, createdAt = 1, lastSeenAt = 2 },
                Pearls = 12,
                Stats = { sold = 40, ironSold = 3 },
                Wheel = { lastSpinAt = 99, seed = 7, spins = 2 },
            }
        end

        test.case("undita, raul si satul se adauga; nimic din ce era nu se atinge", function()
            local data = v8()
            ProfileMigrate.toV9(data)
            check.equal(data.Meta.version, 9)
            check.equal(data.Stats.fished, 0)
            check.equal(data.Stats.treasures, 0)
            check.equal(data.Stats.sold, 40)
            check.equal(data.Pearls, 12)
            check.equal(data.Wheel.spins, 2)
            check.equal(data.Fishing.bait, 0)
            check.not_nil(data.Fishing.species)
            check.is_false(data.River.started)
            check.equal(#data.River.waiting, 0)
            check.equal(data.Village.outfit, "keeper")
            check.is_true(data.Village.outfits.keeper)
        end)

        test.case("idempotenta, si un profil deja la v9 ramane neatins", function()
            local data = v8()
            ProfileMigrate.toV9(data)
            data.Fishing.bait = 4
            data.Meta.version = 8 -- chiar si chemata iar pe un profil care are deja campurile
            ProfileMigrate.toV9(data)
            check.equal(data.Fishing.bait, 4)
            local fresh = { Meta = { version = 9 }, Stats = {} }
            ProfileMigrate.toV9(fresh)
            check.equal(fresh.Fishing, nil)
            check.equal(fresh.Stats.fished, nil)
        end)

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            -- Sablonul din DataService nu se poate incarca in Lune (cere ServerStorage); il citim ca text si
            -- verificam ca fiecare camp adaugat de toV9 apare si acolo, cu aceeasi valoare de pornire.
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "fished = 0",
                    "treasures = 0",
                    "Fishing = { seed = 0, casts = 0, bait = 0, species = {} }",
                    "River = { started = false, waiting = {}, nextAt = 0, seed = 0, total = 0, notes = 0 }",
                    -- [D61] satul a primit si infatisarea (toV12), deci sablonul lui sta pe mai multe randuri
                    "outfits = { keeper = true },",
                    'outfit = "keeper",',
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV10 - balciul [D60]", function()
        local function v9(): { [string]: any }
            return {
                Meta = { version = 9, createdAt = 1, lastSeenAt = 2 },
                Pearls = 30,
                Stats = { fished = 5, treasures = 1 },
                Village = {
                    decor = { fountain = true },
                    outfits = { keeper = true },
                    outfit = "keeper",
                },
            }
        end

        test.case(
            "titlurile, vizitele, recordurile si timpul jucat se adauga; restul ramane",
            function()
                local data = v9()
                ProfileMigrate.toV10(data)
                check.equal(data.Meta.version, 10)
                check.equal(data.Stats.playSeconds, 0)
                check.equal(data.Stats.fished, 5)
                check.equal(data.Pearls, 30)
                check.is_true(data.Village.decor.fountain)
                check.equal(data.Titles.worn, "era")
                check.not_nil(data.Titles.bought)
                check.equal(data.Fair.visits, 0)
                check.equal(data.Records.era1Seconds, 0)
                check.equal(data.Records.weeklyFishWeek, "")
            end
        )

        test.case("idempotenta, si un profil deja la v10 ramane neatins", function()
            local data = v9()
            ProfileMigrate.toV10(data)
            data.Titles.worn = "legend"
            data.Meta.version = 9
            ProfileMigrate.toV10(data)
            check.equal(data.Titles.worn, "legend")
            local fresh = { Meta = { version = 10 }, Stats = {} }
            ProfileMigrate.toV10(fresh)
            check.equal(fresh.Titles, nil)
            check.equal(fresh.Stats.playSeconds, nil)
        end)

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "playSeconds = 0",
                    'Titles = { bought = {}, worn = "era" }',
                    "firstVisit = 0",
                    "visits = 0",
                    'Records = { era1Seconds = 0, incomePerSec = 0, weeklyFishMm = 0, weeklyFishWeek = "" }',
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV11 - iazul si gheretele [D61]", function()
        local function v10(): { [string]: any }
            return {
                Meta = { version = 10, createdAt = 1, lastSeenAt = 2 },
                Pearls = 40,
                Fair = { firstVisit = 5, visits = 3 },
                Titles = { bought = {}, worn = "legend" },
            }
        end

        test.case("rundele si jocurile se adauga in Fair; vizitele si restul raman", function()
            local data = v10()
            ProfileMigrate.toV11(data)
            check.equal(data.Meta.version, 11)
            check.equal(data.Fair.visits, 3)
            check.equal(data.Fair.firstVisit, 5)
            check.equal(data.Fair.pond.wins, 0)
            check.equal(data.Fair.pond.rounds, 0)
            check.equal(data.Fair.booth.day, 0)
            check.equal(data.Fair.booth.prizeGames, 0)
            check.equal(data.Fair.booth.perfect, 0)
            check.equal(data.Pearls, 40)
            check.equal(data.Titles.worn, "legend")
        end)

        test.case("un profil fara Fair primeste tot; migrarea e idempotenta", function()
            local data: { [string]: any } = { Meta = { version = 9 } }
            ProfileMigrate.toV10(data)
            ProfileMigrate.toV11(data)
            check.equal(data.Fair.visits, 0)
            check.equal(data.Fair.pond.wins, 0)
            data.Fair.pond.wins = 2
            data.Meta.version = 10
            ProfileMigrate.toV11(data)
            check.equal(data.Fair.pond.wins, 2)
            local fresh: { [string]: any } = { Meta = { version = 11 }, Fair = { visits = 1 } }
            ProfileMigrate.toV11(fresh)
            check.equal(fresh.Fair.pond, nil)
        end)

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "pond = { wins = 0, rounds = 0 }",
                    "booth = { day = 0, prizeGames = 0, perfect = 0 }",
                    "ProfileMigrate.toV11(profile.Data)",
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV12 - infatisarea jucatorului [D61]", function()
        local LookMath = require("../src/Shared/Modules/LookMath")

        test.case(
            "cine n-a ales nimic ramane cu chipul de dinainte; restul satului neatins",
            function()
                local data: { [string]: any } = {
                    Meta = { version = 11 },
                    Village = {
                        decor = { well = true },
                        outfits = { keeper = true, angler = true },
                        outfit = "angler",
                    },
                }
                ProfileMigrate.toV12(data)
                check.equal(data.Meta.version, 12)
                check.is_true(LookMath.same(data.Village.look, LookMath.DEFAULT))
                check.equal(data.Village.outfit, "angler")
                check.is_true(data.Village.decor.well)
            end
        )

        test.case(
            "o infatisare aleasa nu se pierde; migrarea e idempotenta; un profil fara sat primeste tot",
            function()
                local data: { [string]: any } = {
                    Meta = { version = 11 },
                    Village = {
                        decor = {},
                        outfits = { keeper = true },
                        outfit = "keeper",
                        look = { body = 1, hair = 4, skin = 6, hairColor = 3 },
                    },
                }
                ProfileMigrate.toV12(data)
                check.equal(data.Village.look.hair, 4)
                ProfileMigrate.toV12(data)
                check.equal(data.Village.look.skin, 6)
                local bare: { [string]: any } = { Meta = { version = 8 } }
                ProfileMigrate.toV9(bare)
                ProfileMigrate.toV10(bare)
                ProfileMigrate.toV11(bare)
                ProfileMigrate.toV12(bare)
                check.equal(bare.Meta.version, 12)
                check.is_true(LookMath.valid(bare.Village.look))
            end
        )

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "look = { body = 2, hair = 2, skin = 2, hairColor = 2 }",
                    "ProfileMigrate.toV12(profile.Data)",
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV13 - like-urile satului [D61]", function()
        test.case("un profil v12 primeste like-urile; vizitele si iazul raman neatinse", function()
            local data: { [string]: any } = {
                Meta = { version = 12 },
                Fair = { firstVisit = 5, visits = 3, pond = { wins = 2, rounds = 4 } },
            }
            ProfileMigrate.toV13(data)
            check.equal(data.Meta.version, 13)
            check.equal(data.Fair.likes, 0)
            check.equal(data.Fair.liked.day, 0)
            check.equal(data.Fair.visits, 3)
            check.equal(data.Fair.pond.wins, 2)
        end)

        test.case("like-urile stranse nu se pierd; migrarea e idempotenta", function()
            local data: { [string]: any } = {
                Meta = { version = 12 },
                Fair = {
                    firstVisit = 0,
                    visits = 1,
                    likes = 7,
                    liked = { day = 9, ids = { a = true } },
                },
            }
            ProfileMigrate.toV13(data)
            ProfileMigrate.toV13(data)
            check.equal(data.Fair.likes, 7)
            check.equal(data.Fair.liked.day, 9)
            check.is_true(data.Fair.liked.ids.a)
            local bare: { [string]: any } = { Meta = { version = 8 } }
            ProfileMigrate.toV9(bare)
            ProfileMigrate.toV10(bare)
            ProfileMigrate.toV11(bare)
            ProfileMigrate.toV12(bare)
            ProfileMigrate.toV13(bare)
            check.equal(bare.Meta.version, 13)
            check.equal(bare.Fair.likes, 0)
        end)

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "likes = 0,",
                    "liked = { day = 0, ids = {} },",
                    "ProfileMigrate.toV13(profile.Data)",
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV14 - coltul cu Robux [D61]", function()
        test.case(
            "un profil v13 primeste chitantele, pass-urile si suma ultimei reveniri",
            function()
                local data: { [string]: any } =
                    { Meta = { version = 13, lastSeenAt = 77 }, Coins = 500 }
                ProfileMigrate.toV14(data)
                check.equal(data.Meta.version, 14)
                check.equal(data.Meta.lastWelcome, 0)
                check.equal(data.Meta.lastSeenAt, 77)
                check.equal(#data.Purchases.ids, 0)
                check.equal(next(data.Purchases.passes), nil)
                check.equal(data.Coins, 500)
            end
        )

        test.case("ce ai platit nu se pierde; migrarea e idempotenta", function()
            local data: { [string]: any } = {
                Meta = { version = 13, lastWelcome = 321 },
                Purchases = { ids = { "p1" }, passes = { flow2x = true } },
            }
            ProfileMigrate.toV14(data)
            ProfileMigrate.toV14(data)
            check.is_true(data.Purchases.passes.flow2x)
            check.equal(data.Purchases.ids[1], "p1")
            check.equal(data.Meta.lastWelcome, 321)
            -- un camp pe jumatate stricat se repara fara sa stearga restul
            local half: { [string]: any } = {
                Meta = { version = 13 },
                Purchases = { passes = { swift = true } },
            }
            ProfileMigrate.toV14(half)
            check.is_true(half.Purchases.passes.swift)
            check.equal(#half.Purchases.ids, 0)
        end)

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "Purchases = { ids = {}, passes = {} },",
                    "lastWelcome = 0",
                    "ProfileMigrate.toV14(profile.Data)",
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV15 - darurile raului [D62]", function()
        test.case("un profil v14 primeste numaratorii; restul statisticilor raman", function()
            local data: { [string]: any } = {
                Meta = { version = 14 },
                Stats = { fished = 9, sold = 120 },
            }
            ProfileMigrate.toV15(data)
            check.equal(data.Meta.version, 15)
            check.equal(data.Stats.drifts, 0)
            check.equal(data.Stats.lastDrift, 0)
            check.equal(data.Stats.fished, 9)
            check.equal(data.Stats.sold, 120)
        end)

        test.case(
            "ce ai scos nu se pierde; migrarea e idempotenta; un profil fara Stats primeste tot",
            function()
                local data: { [string]: any } = {
                    Meta = { version = 14 },
                    Stats = { drifts = 4, lastDrift = 31000000 },
                }
                ProfileMigrate.toV15(data)
                ProfileMigrate.toV15(data)
                check.equal(data.Stats.drifts, 4)
                check.equal(data.Stats.lastDrift, 31000000)
                local bare: { [string]: any } = { Meta = { version = 14 } }
                ProfileMigrate.toV15(bare)
                check.equal(bare.Stats.drifts, 0)
            end
        )

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            for _, needle in
                {
                    "drifts = 0,",
                    "lastDrift = 0,",
                    "ProfileMigrate.toV15(profile.Data)",
                }
            do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)

    test.suite("ProfileMigrate.toV16 - Era 2, The Mill [D65]", function()
        local FlowConfig = require("../src/Shared/Config/FlowConfig")

        test.case(
            "un profil v15 primeste cladirile, gramezile, oamenii si numaratorii Morii",
            function()
                local data: { [string]: any } = {
                    Meta = { version = 15 },
                    Stations = {
                        saw = { level = 12 },
                        dock = { level = 9 },
                        forge = { level = 4 },
                        nets = {},
                    },
                    Crews = { collector = { tier = 5 } },
                    Stats = { sold = 900, ironSold = 40 },
                    DockPile = { counts = { planks = 7 }, drainedAt = 5 },
                }
                ProfileMigrate.toV16(data)
                check.equal(data.Meta.version, 16)
                for _, kind in { "foundry", "furnace", "market" } do
                    check.equal(data.Stations[kind].level, 1)
                end
                -- fiecare gramada din drumul marfii (FlowConfig) exista dupa migrare
                for _, line in { "parts", "copper" } do
                    local spec = FlowConfig.LINES[line]
                    check.equal(next(data[spec.storePile].counts), nil)
                    check.equal(next(data[spec.inputPile].counts), nil)
                    check.equal(data[spec.inputPile].processedAt, 0)
                    check.equal(next(data[spec.outputPile].counts), nil)
                end
                check.equal(data.MarketPile.drainedAt, 0)
                for _, role in StationConfig.ERA2_ROLES do
                    check.equal(data.Crews[role].tier, 1)
                end
                for _, stat in { "cast", "partsSold", "copperSmelted", "copperSold" } do
                    check.equal(data.Stats[stat], 0)
                end
                -- Era 1 ramane neatinsa
                check.equal(data.Stations.saw.level, 12)
                check.equal(data.Crews.collector.tier, 5)
                check.equal(data.Stats.ironSold, 40)
                check.equal(data.DockPile.counts.planks, 7)
            end
        )

        test.case(
            "ce ai deja nu se pierde; migrarea e idempotenta; un profil gol primeste tot",
            function()
                local data: { [string]: any } = {
                    Meta = { version = 15 },
                    Stations = { foundry = { level = 8 } },
                    Crews = { founder = { tier = 3 } },
                    Stats = { cast = 77 },
                    PartsPile = { counts = { parts = 5 } },
                }
                ProfileMigrate.toV16(data)
                ProfileMigrate.toV16(data)
                check.equal(data.Stations.foundry.level, 8)
                check.equal(data.Crews.founder.tier, 3)
                check.equal(data.Stats.cast, 77)
                check.equal(data.PartsPile.counts.parts, 5)
                local bare: { [string]: any } = { Meta = { version = 15 } }
                ProfileMigrate.toV16(bare)
                check.equal(bare.Stations.market.level, 1)
                check.equal(bare.Crews.merchant.tier, 1)
            end
        )

        test.case("sablonul si migrarea adauga aceleasi campuri", function()
            local fs = require("@lune/fs")
            local src = fs.readFile("src/Server/Services/DataService.luau")
            local needles = {
                "foundry = { level = 1 },",
                "furnace = { level = 1 },",
                "market = { level = 1 },",
                "MarketPile = { counts = {}, drainedAt = 0 },",
                "FoundryPile = { counts = {}, processedAt = 0 },",
                "FurnacePile = { counts = {}, processedAt = 0 },",
                "cast = 0,",
                "copperSold = 0,",
                "version = 16",
                "ProfileMigrate.toV16(profile.Data)",
            }
            for _, pile in FlowConfig.PILES do
                table.insert(needles, pile .. " = { counts = {}")
            end
            for _, role in StationConfig.ERA2_ROLES do
                table.insert(needles, role .. " = { tier = 1 },")
            end
            for _, needle in needles do
                check.is_true(string.find(src, needle, 1, true) ~= nil)
            end
        end)
    end)
end
