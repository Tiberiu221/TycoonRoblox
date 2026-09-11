local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RiverConfig = require("../src/Shared/Config/RiverConfig")

return function()
    test.suite("RiverConfig", function()
        test.case("zona de platforme incape in lume", function()
            -- WorldDecor foloseste PLOT ca zona fara copaci/pietre pentru cele 12 platforme ale
            -- Erei 1 si debarcader (tests/WorldDecor.test.luau). Daca iese din lume, o parte din
            -- ea n-ar mai avea decor in jur, adica marginea lumii s-ar vedea taiata.
            local plot = RiverConfig.PLOT
            check.is_true(plot.x >= 0)
            check.is_true(plot.y > RiverConfig.RIVER_BOTTOM)
            check.is_true(plot.x + plot.w <= RiverConfig.WORLD_WIDTH)
            check.is_true(plot.y + plot.h <= RiverConfig.WORLD_HEIGHT)
        end)
    end)
end
