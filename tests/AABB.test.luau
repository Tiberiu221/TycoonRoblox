local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local AABB = require("../src/Shared/Modules/AABB")

return function()
    test.suite("AABB.intersects", function()
        test.case("plasa prinde obiectul cand cutiile se suprapun", function()
            local net = { x = 100, y = 50, width = 40, height = 20 }
            local debris = { x = 120, y = 55, width = 10, height = 10 }
            check.is_true(AABB.intersects(net, debris))
        end)
        test.case("nu prinde daca obiectul e complet la dreapta plasei", function()
            local net = { x = 100, y = 50, width = 40, height = 20 }
            local debris = { x = 200, y = 55, width = 10, height = 10 }
            check.is_false(AABB.intersects(net, debris))
        end)
        test.case("marginile care se ating exact nu se considera coliziune", function()
            local net = { x = 0, y = 0, width = 10, height = 10 }
            local debris = { x = 10, y = 0, width = 10, height = 10 }
            check.is_false(AABB.intersects(net, debris))
        end)
        test.case("e simetrica", function()
            local a = { x = 0, y = 0, width = 10, height = 10 }
            local b = { x = 5, y = 5, width = 10, height = 10 }
            check.equal(AABB.intersects(a, b), AABB.intersects(b, a))
        end)
    end)
end
