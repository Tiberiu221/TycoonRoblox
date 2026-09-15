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
        -- [D59] Pontonul lung: pe el mergi pana la capat, unde pescuiesti; in rest raul blocheaza la fel ca inainte.
        test.case("pe ponton mergi pana la capat, nu mai departe si nu pe laterale", function()
            local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
            local walk = TycoonConfig.PIER_WALK
            local pier = WorldMap.blockedRects(cfg, nil, walk)
            local stand = TycoonConfig.FISH_STAND
            check.is_false(WorldMap.isBlocked(pier, cfg, stand.x, stand.y)) -- locul de pescuit
            check.is_false(
                WorldMap.isBlocked(pier, cfg, (walk.x0 + walk.x1) / 2, cfg.RIVER_BOTTOM - 5)
            )
            check.is_true(WorldMap.isBlocked(pier, cfg, stand.x, walk.y0 - 20)) -- apa de dincolo de capat
            check.is_true(WorldMap.isBlocked(pier, cfg, walk.x0 - 10, stand.y)) -- apa din stanga
            check.is_true(WorldMap.isBlocked(pier, cfg, walk.x1 + 10, stand.y)) -- apa din dreapta
            check.is_true(
                WorldMap.isBlocked(pier, cfg, 1000, (cfg.RIVER_TOP + cfg.RIVER_BOTTOM) / 2)
            ) -- raul in rest
            check.is_false(WorldMap.isBlocked(pier, cfg, 1000, cfg.RIVER_BOTTOM + 100)) -- malul
        end)
    end)
end
