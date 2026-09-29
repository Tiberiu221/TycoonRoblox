-- [D70] Tabelele desenului modernizarii se tin de foile adevarate: o celula gresita ar lipi geamurile altei case peste
-- casa ta, iar o varianta de alta marime ar sari din loc cand satul trece la tabla si caramida.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Assets = require("../src/Shared/Config/Assets")
local ModernConfig = require("../src/Shared/Config/ModernConfig")

local tycoon = Assets.tycoon :: any

return function()
    test.suite("ModernConfig [D70]", function()
        test.case("fiecare cladire moderna are marimea celei de azi", function()
            for base, modern in ModernConfig.MODERN_OF do
                local a, b = tycoon[base], tycoon[modern]
                check.not_nil(a)
                check.not_nil(b)
                check.equal(`{base}:{b.width}x{b.height}`, `{base}:{a.width}x{a.height}`)
            end
        end)

        test.case("celulele geamurilor au marimea casei lor si stau in atlas", function()
            local atlas = tycoon.windows_glass
            check.equal(tycoon.windows_lit.width, atlas.width)
            check.equal(tycoon.windows_lit.height, atlas.height)
            for hut, cell in ModernConfig.WINDOW_CELLS do
                local sprite = tycoon[hut]
                check.not_nil(sprite)
                check.equal(`{hut}:{cell.w}x{cell.h}`, `{hut}:{sprite.width}x{sprite.height}`)
                check.is_true(cell.x >= 0 and cell.y >= 0)
                check.is_true(cell.x + cell.w <= atlas.width and cell.y + cell.h <= atlas.height)
            end
        end)

        test.case("luminile cladirilor moderne au marimea cladirii si stau in atlas", function()
            local atlas = tycoon.modern_lit
            for modern, cell in ModernConfig.MODERN_LIT_CELLS do
                local sprite = tycoon[modern]
                check.not_nil(sprite)
                check.equal(`{modern}:{cell.w}x{cell.h}`, `{modern}:{sprite.width}x{sprite.height}`)
                check.is_true(cell.x + cell.w <= atlas.width and cell.y + cell.h <= atlas.height)
            end
        end)

        test.case("stalpii si tarusii au ancorele in foaia lor", function()
            check.is_true(ModernConfig.WIRE_POLE.near.x < tycoon.wire_pole.width)
            check.is_true(ModernConfig.WIRE_POLE_END.postX < tycoon.wire_pole_end.width)
            local frame = ModernConfig.SURVEY_STAKE.frame
            check.equal(frame.w * ModernConfig.SURVEY_STAKE.frames, tycoon.survey_stakes.width)
            check.equal(frame.h, tycoon.survey_stakes.height)
        end)
    end)
end
