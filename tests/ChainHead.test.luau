--!strict
-- [D70, pasul k4, verificatorul k2] Capul panoului Stations (U): in sat ramane pe o coloana, cum era; la baraj (18 verigi)
-- trece pe doua, ca lista cladirilor sa aiba macar doua randuri. Aritmetica inaltimii, pe fiecare lume, si numele verigilor
-- in cutia lor.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local ChainHead = require("../src/Shared/Modules/ChainHead")
local StationConfig = require("../src/Shared/Config/StationConfig")
local WorldConfig = require("../src/Shared/Config/WorldConfig")

-- StationPanel: corpul ferestrei (720 minus bara de titlu), randul de cladire, comutatorul de cartier, marginea de jos
local BODY_H, ROW_H, TABS_H, FIRST_ROW_Y = 624, 96, 44, 250
local PIXEL_EM = 572 / 1024

-- latimea unui text in Nunito (corpul), la `size` px
local function nunito(text: string, size: number): number
    local widths = require("./fonts/NunitoWidths") :: { [string]: number }
    local px = 0
    for _, code in utf8.codes(text) do
        px += (widths[utf8.char(code)] or 1000) * size / 1000
    end
    return px
end

return function()
    test.suite("ChainHead - capul panoului Stations [D70, pasul k4]", function()
        test.case(
            "in sat, o coloana si exact verigile de dinainte (Era 1: 11, capul coboara cu 80)",
            function()
                local most = 0
                for era = 1, StationConfig.ENGINE_ERAS do
                    if WorldConfig.worldOfEra(era) == 1 then
                        local layout = ChainHead.layout(ChainHead.rowsFor(era))
                        check.equal(layout.columns, 1)
                        most = math.max(most, layout.rows)
                    end
                end
                check.equal(most, 11)
                check.equal(ChainHead.shift(most), 80)
                -- o coloana = cutiile de dinainte de k4
                local one = ChainHead.CELL[1]
                check.equal(one.name, 28)
                check.equal(one.value, 150)
                check.equal(one.warn, 282)
            end
        )

        test.case("pe fiecare lume, sub cap raman macar doua randuri de cladiri", function()
            for w = 1, WorldConfig.COUNT do
                local most, eras = 0, 0
                for era in StationConfig.ERA_LINES_ALL do
                    if WorldConfig.worldOfEra(era) == w then
                        eras += 1
                        local layout =
                            ChainHead.layout(ChainHead.rowsFor(era, StationConfig.ERA_LINES_ALL))
                        most = math.max(most, layout.rows)
                    end
                end
                if eras == 0 then
                    continue
                end
                local tabs = if eras > 1 then TABS_H else 0
                local list = BODY_H - (FIRST_ROW_Y + ChainHead.shift(most) + tabs) - 16
                if list < 2 * (ROW_H + 8) then
                    print(`  ! lumea {w}: {most} verigi pe coloana, lista are {list} px`)
                end
                check.is_true(list >= 2 * (ROW_H + 8))
            end
        end)

        test.case("barajul: doua coloane rupte intre doua linii, nu la mijlocul uneia", function()
            local rows = ChainHead.rowsFor(4, StationConfig.ERA_LINES_ALL)
            check.equal(#rows, 18)
            local layout = ChainHead.layout(rows)
            check.equal(layout.columns, 2)
            check.equal(layout.rows, 10) -- butoaiele si cablul; unirea, orasul si cristalul in a doua
            for i = 2, #rows do
                if layout.cells[i].column ~= layout.cells[i - 1].column then
                    check.is_true(rows[i].group ~= rows[i - 1].group)
                end
            end
        end)

        test.case(
            "pe doua coloane, numele, cifrele si semnul incap in cutiile lor, fara sa se calce",
            function()
                local cell = ChainHead.CELL[2]
                -- cutiile, in ordine, si a doua coloana in continutul panoului (560)
                check.is_true(cell.name >= cell.icon + 16)
                check.is_true(cell.value >= cell.name + cell.nameW)
                check.is_true(cell.warn >= cell.value + cell.valueW)
                check.is_true(ChainHead.SECOND_COLUMN_X >= cell.warn + cell.warnW + 8)
                check.is_true(ChainHead.SECOND_COLUMN_X + cell.warn + cell.warnW <= 560)
                -- semnul, in fontul de pixeli (13 px)
                check.is_true(utf8.len(cell.warnText) :: number * 13 * PIXEL_EM <= cell.warnW)
                -- cifra cea mai lata: cinci caractere (formatNumber) si "/s", in fontul de pixeli (15 px)
                check.is_true(7 * 15 * PIXEL_EM <= cell.valueW)
                for era in StationConfig.ERA_LINES_ALL do
                    local rows = ChainHead.rowsFor(era, StationConfig.ERA_LINES_ALL)
                    if ChainHead.layout(rows).columns == 2 then
                        for _, row in rows do
                            local px = nunito(row.label, 13)
                            if px > cell.nameW then
                                print(`  ! {row.label}: {math.floor(px)} px`)
                            end
                            check.is_true(px <= cell.nameW)
                        end
                    end
                end
            end
        )
    end)
end
