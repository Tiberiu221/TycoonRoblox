--!strict
-- [D61, partea 2] Fotografia unui sat, scoasa din profil: doar ce se vede, doar chei din config.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local VillageLook = require("../src/Shared/Modules/VillageLook")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local VillageConfig = require("../src/Shared/Config/VillageConfig")

local function hand(role: string, padId: string, id: string, carry: { { g: string } }?): any
    return {
        id = id,
        role = role,
        padId = padId,
        name = "Mara",
        appearance = {
            body = "a",
            hair = "bun",
            skin = { 1, 2, 3 },
            hairColor = { 4, 5, 6 },
            outfit = "Fisher",
        },
        cycleStartAt = 100,
        lastEventAt = 0,
        carry = carry or {},
    }
end

local function profile(): { [string]: any }
    return {
        Coins = 123456,
        Pearls = 77,
        Pads = { first_net = true, first_runner = true, hire_porter = true, nu_exista = true },
        Stations = {
            saw = { level = 7 },
            dock = { level = 3 },
            forge = { level = 1 },
            nets = { first_net = { level = 12 } },
        },
        Hands = {
            first_runner = hand("collector", "first_runner", "first_runner", {
                { g = "driftwood" },
                { g = "driftwood" },
                { g = "scrap" },
            }),
            first_runner_2 = hand("collector", "first_runner", "first_runner_2"),
            hire_porter = hand("porter", "hire_porter", "hire_porter"),
        },
        Crews = { collector = { tier = 3 }, porter = { tier = 1 } },
        Village = { decor = { nu_exista = true }, outfits = { keeper = true }, outfit = "keeper" },
        Quests = { claimed = { first = true } },
    }
end

return function()
    test.suite("VillageLook", function()
        test.case(
            "fotografia are doar ce se vede: nicio moneda, nicio perla, niciun quest",
            function()
                local snap: any = VillageLook.of(profile())
                check.equal(snap.Coins, nil)
                check.equal(snap.coins, nil)
                check.equal(snap.pearls, nil)
                check.equal(snap.quests, nil)
                check.equal(snap.era, 1)
            end
        )

        test.case("platformele: doar cele cumparate, din config si cu loc pe harta", function()
            local snap = VillageLook.of(profile())
            check.is_true(snap.pads.first_net)
            check.is_true(snap.pads.first_runner)
            check.equal(snap.pads.nu_exista, nil)
            check.equal(snap.pads.second_net, nil)
            for id in snap.pads do
                local pad = TycoonConfig.byId[id]
                check.not_nil(pad)
                check.not_nil(pad.x)
            end
        end)

        test.case("nivelurile: plasa cumparata cu nivelul ei, cladirile cu ale lor", function()
            local snap = VillageLook.of(profile())
            check.equal(snap.netLevels.first_net, 12)
            check.equal(snap.stations.saw, 7)
            check.equal(snap.stations.dock, 3)
            check.equal(snap.stations.forge, 1)
            -- un nivel stricat nu ajunge la alt jucator ca atare
            local broken = profile()
            broken.Stations.saw = { level = 0 / 0 }
            broken.Stations.nets.first_net = "x"
            local s2 = VillageLook.of(broken)
            check.equal(s2.stations.saw, 1)
            check.equal(s2.netLevels.first_net, 1)
        end)

        test.case("oamenii: cati pe meserie, al catelea e fiecare, treapta, ce duc", function()
            local snap = VillageLook.of(profile())
            check.equal(snap.crews.collector, 2)
            check.equal(snap.crews.porter, 1)
            check.equal(snap.crews.hauler, nil)
            check.equal(#snap.hands, 3)
            local byId: { [string]: VillageLook.HandSnap } = {}
            for _, h in snap.hands do
                byId[h.id] = h
            end
            local first = byId.first_runner
            check.equal(first.index, 1)
            check.equal(first.count, 2)
            check.equal(first.tier, 3)
            check.equal(first.carrying, 3)
            check.equal(first.carryKind, "driftwood")
            check.equal(first.nets[1], "first_net")
            check.is_true(first.capacity > 0)
            check.equal(byId.first_runner_2.index, 2)
            check.equal(first.appearance.outfit, "Fisher")
        end)

        test.case("cine sta pe loc are locul lui; cine merge nu", function()
            local data = profile()
            data.Pads.hire_sawyer = true
            data.Hands.hire_sawyer = hand("sawyer", "hire_sawyer", "hire_sawyer")
            local snap = VillageLook.of(data)
            for _, h in snap.hands do
                if h.role == "sawyer" then
                    check.not_nil(h.x)
                    check.not_nil(h.y)
                    check.equal(#h.nets, 0)
                else
                    check.equal(h.x, nil)
                end
            end
        end)

        test.case("decorul: doar ce e in catalog, numarat la fel", function()
            local data = profile()
            local firstDecor = VillageConfig.DECOR[1].id
            local secondDecor = VillageConfig.DECOR[2].id
            data.Village.decor[firstDecor] = true
            data.Village.decor[secondDecor] = true
            local snap = VillageLook.of(data)
            check.is_true(snap.decor[firstDecor])
            check.equal(snap.decor.nu_exista, nil)
            check.equal(snap.decorCount, 2)
            check.equal(VillageLook.decorCount(data), 2)
        end)

        test.case("un profil gol (sau stricat) da un sat gol, nu o eroare", function()
            local snap = VillageLook.of({})
            check.equal(snap.era, 1)
            check.equal(#snap.hands, 0)
            check.equal(snap.decorCount, 0)
            check.equal(next(snap.pads), nil)
            local odd =
                VillageLook.of({ Pads = "x", Stations = 4, Hands = false, Village = 1 } :: any)
            check.equal(#odd.hands, 0)
        end)

        test.case("plasele detinute vin in ordinea platformelor", function()
            local nets =
                VillageLook.ownedNets({ second_net = true, first_net = true, first_runner = true })
            check.equal(#nets, 2)
            check.equal(nets[1], "first_net")
            check.equal(nets[2], "second_net")
        end)
    end)
end
