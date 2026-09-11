local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local WorldMap = require("../src/Shared/Modules/WorldMap")
local cfg = require("../src/Shared/Config/RiverConfig")

return function()
    test.suite("WorldMap", function()
        local rects = WorldMap.blockedRects(cfg)
        test.case("raul blocheaza, iarba nu", function()
            check.is_true(
                WorldMap.isBlocked(rects, cfg, 1000, (cfg.RIVER_TOP + cfg.RIVER_BOTTOM) / 2)
            )
            check.is_false(WorldMap.isBlocked(rects, cfg, 1000, cfg.RIVER_BOTTOM + 100))
        end)
        test.case("cladirile si marginile blocheaza", function()
            local b = cfg.BUILDINGS[1]
            check.is_true(WorldMap.isBlocked(rects, cfg, b.x + 10, b.y + 10))
            check.is_true(WorldMap.isBlocked(rects, cfg, -5, 100))
            check.is_true(WorldMap.isBlocked(rects, cfg, 100, cfg.WORLD_HEIGHT + 5))
        end)
    end)
end
