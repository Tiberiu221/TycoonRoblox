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

        -- [D70, dupa verificator] al doilea Works Porter e optional: clopotul Erei 3 nu-l cere. Fara el, satul ajungea
        -- la clopot oprit pe treapta 2 (fara tabla, geamuri, lumini, masa cu planurile barajului).
        test.case(
            "fara al doilea Works Porter, plasa a 14-a aduce tabla si satul ajunge la 5",
            function()
                local pads = { hire_clerk = true, thirteenth_net = true, fourteenth_net = true }
                check.equal(ModernMath.stage(facts(pads, { worksPorter = 1 })), 3)
                pads.power_house = true
                check.equal(ModernMath.stage(facts(pads, { worksPorter = 1 })), 4)
                check.equal(ModernMath.stage(facts(pads, { worksPorter = 1 }, true)), 5)
            end
        )

        test.case(
            "fiecare treapta de dupa Clerk vine si pe drumul obligatoriu spre clopot",
            function()
                -- orice treapta trebuie sa aiba o cale printr-o platforma a Erei 3 (clopotul le cere pe toate) sau prin
                -- primul curent vandut (Power House + turbina il aduc); o meserie singura nu ajunge
                for _, step in ModernMath.STAGES do
                    local mandatory = step.power == true
                    for _, id in { step.pad, step.orPad } do
                        local p = if id ~= nil then TycoonConfig.byId[id] else nil
                        if p ~= nil and p.era == 3 then
                            mandatory = true
                        end
                    end
                    check.is_true(mandatory)
                end
            end
        )

        test.case("fiecare treapta arata spre o platforma sau o meserie care exista", function()
            for _, step in ModernMath.STAGES do
                if step.pad ~= nil then
                    check.not_nil(TycoonConfig.byId[step.pad])
                end
                if step.orPad ~= nil then
                    check.not_nil(TycoonConfig.byId[step.orPad])
                end
                if step.crew ~= nil then
                    check.not_nil(TycoonConfig.CREWS[step.crew])
                end
            end
        end)

        test.case("stageOf: treapta care aduce o cheie", function()
            for i, step in ModernMath.STAGES do
                check.equal(ModernMath.stageOf(step.key), i)
            end
            check.equal(ModernMath.stageOf("lights"), #ModernMath.STAGES) -- felinarele: ultima treapta
            check.equal(ModernMath.stageOf("nimic"), nil)
        end)
    end)
end
