local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RiverSim = require("../src/Shared/Modules/RiverSim")
local cfg = require("../src/Shared/Config/RiverConfig")

return function()
    test.suite("RiverSim", function()
        test.case("acelasi seed si aceeasi fereastra dau exact acelasi program", function()
            local a = RiverSim.schedule(12345, 7, cfg)
            local b = RiverSim.schedule(12345, 7, cfg)
            check.equal(#a, cfg.SPAWNS_PER_WINDOW)
            for i, obj in a do
                check.equal(obj.spawnAt, b[i].spawnAt)
                check.equal(obj.lane, b[i].lane)
                check.equal(obj.speed, b[i].speed)
            end
        end)
        test.case("ferestre diferite dau programe diferite, cu id-uri unice", function()
            local a = RiverSim.schedule(12345, 7, cfg)
            local b = RiverSim.schedule(12345, 8, cfg)
            check.not_equal(a[1].spawnAt, b[1].spawnAt)
            check.not_equal(a[1].id, b[1].id)
        end)
        test.case("obiectul nu exista inainte de spawn si se misca spre dreapta dupa", function()
            local obj = { id = 1, lane = 2, spawnAt = 100, speed = 120 }
            check.equal(RiverSim.box(obj, cfg, 99), nil)
            local b1 = RiverSim.box(obj, cfg, 101)
            local b2 = RiverSim.box(obj, cfg, 102)
            check.not_nil(b1)
            check.greater(b2.x, b1.x)
            check.equal(b1.y, cfg.LANE_YS[2] - cfg.OBJECT_HEIGHT / 2)
        end)
        test.case("fiecare obiect are un tier valid, determinist", function()
            local valid = {}
            for _, t in cfg.TIERS do
                valid[t.id] = true
            end
            local a = RiverSim.schedule(99, 3, cfg)
            local b = RiverSim.schedule(99, 3, cfg)
            for i, obj in a do
                check.is_true(valid[obj.tier] == true)
                check.equal(obj.tier, b[i].tier)
            end
        end)
        test.case("obiectul dispare dupa ce iese din ecran", function()
            local obj = { id = 1, lane = 1, spawnAt = 0, speed = 100 }
            check.equal(RiverSim.box(obj, cfg, 1000), nil)
        end)
    end)
end
