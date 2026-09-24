local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ModernMath = require("../src/Shared/Modules/ModernMath")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

local function facts(
    pads: { [string]: boolean }?,
    crews: { [string]: number }?,
    power: boolean?
): ModernMath.Facts
    return { pads = pads or {}, crews = crews or {}, powerSold = power == true }
end

return function()
    test.suite("ModernMath [D70]", function()
        test.case("un sat fara Era 3 ramane cum e", function()
            check.equal(ModernMath.stage(facts()), 0)
        end)

        test.case("treptele urca in ordine, pe cumparaturile Erei 3", function()
            local pads = { hire_clerk = true }
            check.equal(ModernMath.stage(facts(pads)), 1)
            pads.thirteenth_net = true
            check.equal(ModernMath.stage(facts(pads)), 2)
            check.equal(ModernMath.stage(facts(pads, { worksPorter = 1 })), 2)
            check.equal(ModernMath.stage(facts(pads, { worksPorter = 2 })), 3)
            pads.power_house = true
            check.equal(ModernMath.stage(facts(pads, { worksPorter = 2 })), 4)
            check.equal(ModernMath.stage(facts(pads, { worksPorter = 2 }, true)), 5)
        end)

        test.case(
            "nu sare o treapta: fara plasa a 13-a, al doilea Porter nu aduce tabla",
            function()
                local stage = ModernMath.stage(
                    facts({ hire_clerk = true, power_house = true }, { worksPorter = 2 }, true)
                )
                check.equal(stage, 1)
                check.is_true(ModernMath.has(stage, "wire"))
                check.is_false(ModernMath.has(stage, "brick"))
            end
        )

        test.case("fiecare treapta arata spre o platforma sau o meserie care exista", function()
            for _, step in ModernMath.STAGES do
                if step.pad ~= nil then
                    check.not_nil(TycoonConfig.byId[step.pad])
                end
                if step.crew ~= nil then
                    check.not_nil(TycoonConfig.CREWS[step.crew])
                end
            end
        end)
    end)
end
