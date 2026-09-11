local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local RiverConfig = require("../src/Shared/Config/RiverConfig")

return function()
    test.suite("RiverConfig", function()
        test.case("debarcaderul e pe apa", function()
            -- Bugul pe care il apara testul: barca de sosire si sageata de la pasul
            -- "uita-te la apa" citesc amandoua LANDING. Daca punctul iese din banda apei,
            -- barca pluteste pe iarba si indiciul devine mincinos.
            check.is_true(RiverConfig.LANDING.y > RiverConfig.RIVER_TOP)
            check.is_true(RiverConfig.LANDING.y < RiverConfig.RIVER_BOTTOM)
        end)

        test.case("debarcaderul e in dreptul terenului", function()
            -- Daca ar fi in alta parte a lumii, jucatorul ar trebui sa alerge dupa o barca
            -- pe care nu o vede pornind. Sosirea trebuie sa se intample sub ochii lui.
            local plot = RiverConfig.PLOT
            check.is_true(RiverConfig.LANDING.x >= plot.x)
            check.is_true(RiverConfig.LANDING.x <= plot.x + plot.w)
        end)

        test.case("terenul incape in lume", function()
            -- BuildService refuza acum orice constructie in afara terenului. Daca terenul
            -- iese din lume, o parte din el nu se poate atinge niciodata.
            local plot = RiverConfig.PLOT
            check.is_true(plot.x >= 0)
            check.is_true(plot.y > RiverConfig.RIVER_BOTTOM)
            check.is_true(plot.x + plot.w <= RiverConfig.WORLD_WIDTH)
            check.is_true(plot.y + plot.h <= RiverConfig.WORLD_HEIGHT)
        end)
    end)
end
