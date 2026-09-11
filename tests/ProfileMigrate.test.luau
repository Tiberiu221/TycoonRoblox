local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ProfileMigrate = require("../src/Shared/Modules/ProfileMigrate")

return function()
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
end
