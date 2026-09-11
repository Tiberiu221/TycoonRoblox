local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local Grid = require("../src/Shared/Modules/Grid")
local Pathfind = require("../src/Shared/Modules/Pathfind")

return function()
    test.suite("Pathfind", function()
        test.case("drum drept pe teren liber", function()
            local map = Grid.new(10, 10, 48)
            local path = Pathfind.find(map, 0, 0, 5, 0)
            check.not_nil(path)
            check.equal(#path, 6)
            check.equal(path[1].x, 0)
            check.equal(path[6].x, 5)
        end)
        test.case("ocoleste un zid, nu trece prin el", function()
            local map = Grid.new(12, 12, 48)
            for y = 0, 9 do
                Grid.setBlocked(map, 5, y, true)
            end
            local path = Pathfind.find(map, 2, 5, 8, 5)
            check.not_nil(path)
            for _, cell in path do
                check.is_false(cell.x == 5 and cell.y <= 9)
            end
        end)
        test.case("intoarce nil cand tinta e complet inchisa", function()
            local map = Grid.new(10, 10, 48)
            for _, c in
                { { 4, 3 }, { 5, 3 }, { 6, 3 }, { 4, 4 }, { 6, 4 }, { 4, 5 }, { 5, 5 }, { 6, 5 } }
            do
                Grid.setBlocked(map, c[1], c[2], true)
            end
            check.equal(Pathfind.find(map, 0, 0, 5, 4), nil)
        end)
        test.case("nu taie coltul intre doua ziduri", function()
            local map = Grid.new(6, 6, 48)
            Grid.setBlocked(map, 1, 0, true)
            Grid.setBlocked(map, 0, 1, true)
            local path = Pathfind.find(map, 0, 0, 2, 2)
            -- (0,0) e inchis diagonal, deci nu exista drum
            check.equal(path, nil)
        end)
        test.case("respecta bugetul de noduri", function()
            local map = Grid.new(60, 60, 48)
            for y = 0, 58 do
                Grid.setBlocked(map, 30, y, true)
            end
            local stats = { expanded = 0 }
            check.equal(Pathfind.find(map, 0, 0, 59, 0, 50, stats), nil)
            check.is_true(stats.expanded <= 51)
        end)
        test.case("simplify pastreaza capetele si taie punctele de mijloc", function()
            local map = Grid.new(10, 10, 48)
            local path = Pathfind.find(map, 0, 0, 7, 0)
            local simple = Pathfind.simplify(path)
            check.equal(#simple, 2)
            check.equal(simple[1].x, 0)
            check.equal(simple[2].x, 7)
        end)
        test.case("nearestWalkable gaseste o celula libera langa una blocata", function()
            local map = Grid.new(10, 10, 48)
            Grid.setBlocked(map, 5, 5, true)
            local x, y = Grid.nearestWalkable(map, 5, 5)
            check.not_nil(x)
            check.is_true(math.abs(x - 5) <= 1 and math.abs(y - 5) <= 1)
        end)
        test.case("blockWorldRect blocheaza celulele acoperite de o cladire", function()
            local map = Grid.new(20, 20, 48)
            Grid.blockWorldRect(map, 96, 96, 96, 48) -- 2x1 tile-uri de la (2,2)
            check.is_false(Grid.isWalkable(map, 2, 2))
            check.is_false(Grid.isWalkable(map, 3, 2))
            check.is_true(Grid.isWalkable(map, 4, 2))
            check.is_true(Grid.isWalkable(map, 2, 3))
        end)
    end)
end
