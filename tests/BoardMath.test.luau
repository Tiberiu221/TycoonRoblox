--!strict
-- [D60] Tabela bâlciului: cum se scriu randurile, cine e primul si ce vede cel care nu incape pe panou.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local BoardMath = require("../src/Shared/Modules/BoardMath")
local Strings = require("../src/Shared/Config/Strings")

local function entry(id: number, name: string, value: number, extra: string?): BoardMath.Entry
    return { userId = id, name = name, value = value, extra = extra }
end

return function()
    test.suite("BoardMath", function()
        test.case("cifrele se scriu in unitati de om", function()
            check.equal(BoardMath.format("fish", 1874, "Sturgeon"), "Sturgeon 187.4 cm")
            check.equal(BoardMath.format("income", 11165), "111.65/s")
            check.equal(BoardMath.format("era1", 2512), "41m 52s")
            check.equal(BoardMath.format("era1", 45), "45s")
        end)

        test.case("la pescuit si la venit castiga cifra mare, la Era 1 timpul mic", function()
            check.is_true(BoardMath.better("fish", 900, 800))
            check.is_true(BoardMath.better("income", 900, 800))
            check.is_true(BoardMath.better("era1", 800, 900))
        end)

        test.case("randurile ies in ordine si nu trec de cate incap pe panou", function()
            local entries = {}
            for i = 1, 9 do
                table.insert(entries, entry(i, `P{i}`, i * 10))
            end
            local rows = BoardMath.rows("fish", entries, 3)
            check.equal(#rows, BoardMath.ROWS)
            check.equal(rows[1].name, "P9")
            check.equal(rows[1].rank, 1)
            check.is_false(rows[1].mine)
        end)

        test.case("la egalitate ordinea nu sare de la o citire la alta", function()
            local a = BoardMath.rows("fish", { entry(7, "B", 100), entry(2, "A", 100) }, nil)
            local b = BoardMath.rows("fish", { entry(2, "A", 100), entry(7, "B", 100) }, nil)
            check.equal(a[1].name, b[1].name)
            check.equal(a[1].name, "A")
        end)

        test.case("cine nu incape pe panou isi vede randul lui, cu locul adevarat", function()
            local entries = {}
            for i = 1, 10 do
                table.insert(entries, entry(i, `P{i}`, i * 10))
            end
            local mine = BoardMath.myLine("fish", entries, 1) -- cel mai slab din zece
            check.not_nil(mine)
            check.equal((mine :: any).rank, 10)
            check.is_true((mine :: any).mine)
            -- cine e deja pe panou nu primeste al doilea rand
            check.equal(BoardMath.myLine("fish", entries, 10), nil)
        end)

        test.case("saptamana se schimba lunea, nu in mijlocul zilei", function()
            -- 2026-09-14 a fost luni; 00:00 UTC = 1789344000 (verificat, nu ghicit)
            local monday = 1789344000
            check.equal(BoardMath.weekKey(monday), BoardMath.weekKey(monday + 86400 * 6 + 3600))
            check.is_false(BoardMath.weekKey(monday) == BoardMath.weekKey(monday + 86400 * 7))
            check.is_false(BoardMath.weekKey(monday) == BoardMath.weekKey(monday - 60))
        end)

        test.case("cifra scurta de pe scena, cu unitatea ei, incape in coloana panoului", function()
            check.equal(BoardMath.compact("fish", 1875), "187.5")
            check.equal(BoardMath.compact("income", 1234), "12.3")
            check.equal(BoardMath.compact("income", 12345600), "123.5K")
            check.equal(BoardMath.compact("income", 250000000), "2.5M")
            check.equal(BoardMath.compact("era1", 2512), "41:52")
            check.equal(BoardMath.compact("era1", 3723), "1:02:03")
            -- 999.95K s-ar rotunji la "1000.0K" si ar iesi din coloana: urca la M
            check.equal(BoardMath.compact("income", 99995000), "1.0M")
            check.equal(BoardMath.compact("income", 99994000), "999.9K")
            check.equal(BoardMath.compact("income", 99995), "1.0K")
            check.equal(BoardMath.compact("income", 250000000000), "2.5B")
            -- cu unitatea lipita de scena, cel mult opt litere, oricat de mare (cat se poate atinge) e cifra
            local worst: { [string]: { number } } = {
                fish = { 0, 40, 999, 2400, 9999 }, -- milimetri; cel mai mare peste are 240 cm
                -- sutimi pe secunda, pana la 999.9T pe secunda
                income = {
                    0,
                    99,
                    99995,
                    12345600,
                    99994999,
                    99995000,
                    99999999999,
                    99999999999999,
                    99994000000000000,
                },
                era1 = { 0, 59, 3599, 3600, 359999, 360000, 1e12 },
            }
            for _, kind in BoardMath.KINDS do
                for _, value in worst[kind] do
                    local text = BoardMath.compact(kind, value)
                        .. (Strings.STAGE_UNITS :: any)[kind]
                    if #text > BoardMath.STAGE_CHARS then
                        check.equal(`{kind} {value}: {text}`, "cel mult opt litere")
                    end
                end
            end
        end)
    end)
end
