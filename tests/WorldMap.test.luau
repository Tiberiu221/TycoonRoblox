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
        test.case("marginile lumii blocheaza", function()
            check.is_true(WorldMap.isBlocked(rects, cfg, -5, 100))
            check.is_true(WorldMap.isBlocked(rects, cfg, 100, cfg.WORLD_HEIGHT + 5))
        end)
        -- Platformele NU blocheaza [F0 spec 4.6]: jucatorul trebuie sa poata calca pe ele ca sa
        -- le cumpere. Testul apara exact asta -- fara `extra`, rects contine doar raul.
        test.case("o platforma nu blocheaza", function()
            check.is_false(WorldMap.isBlocked(rects, cfg, 500, 840))
        end)
        test.case("un obstacol suplimentar explicit tot blocheaza", function()
            local withExtra = WorldMap.blockedRects(cfg, { { x = 900, y = 900, w = 100, h = 100 } })
            check.is_true(WorldMap.isBlocked(withExtra, cfg, 910, 910))
        end)
    end)
end
