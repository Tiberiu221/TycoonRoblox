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
end
