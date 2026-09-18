--!strict
-- [D61] Infatisarea jucatorului: indici in paletele oamenilor, validati; implicitul e chipul de dinainte.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local LookMath = require("../src/Shared/Modules/LookMath")
local SettlerConfig = require("../src/Shared/Config/SettlerConfig")

return function()
    test.suite("LookMath", function()
        test.case("infatisarea implicita e exact cea desenata pana la D61", function()
            local r = LookMath.resolve(nil)
            check.equal(r.body, "b")
            check.equal(r.hair, "long")
            -- culorile batute in cuie in SceneArt.MakeCharacter: pielea (231,188,150), parul (92,62,40)
            check.equal(table.concat(r.skin, ","), "231,188,150")
            check.equal(table.concat(r.hairColor, ","), "92,62,40")
            check.is_true(LookMath.valid(LookMath.DEFAULT))
        end)

        test.case("paletele sunt cele ale oamenilor din sat", function()
            check.equal(LookMath.count("body"), #SettlerConfig.BUILDS)
            check.equal(LookMath.count("hair"), #SettlerConfig.HAIR_STYLES)
            check.equal(LookMath.count("skin"), #SettlerConfig.SKIN)
            check.equal(LookMath.count("hairColor"), #SettlerConfig.HAIR_COLORS)
            check.equal(LookMath.count("nu_exista"), 0)
        end)

        test.case("ce vine de la client se valideaza: intregi, in paleta, toate patru", function()
            check.is_true(LookMath.valid({ body = 1, hair = 4, skin = 6, hairColor = 1 }))
            check.is_false(LookMath.valid(nil))
            check.is_false(LookMath.valid("b"))
            check.is_false(LookMath.valid({ body = 1, hair = 4, skin = 6 })) -- lipseste un camp
            check.is_false(LookMath.valid({ body = 0, hair = 1, skin = 1, hairColor = 1 }))
            check.is_false(LookMath.valid({ body = 3, hair = 1, skin = 1, hairColor = 1 })) -- doar doua siluete
            check.is_false(LookMath.valid({ body = 1.5, hair = 1, skin = 1, hairColor = 1 }))
            check.is_false(LookMath.valid({ body = 1, hair = 1, skin = 0 / 0, hairColor = 1 }))
            check.is_false(LookMath.valid({ body = 1, hair = 1, skin = math.huge, hairColor = 1 }))
            check.is_false(LookMath.valid({ body = "1", hair = 1, skin = 1, hairColor = 1 }))
        end)

        test.case(
            "clean pastreaza ce e valid si pune implicitul in rest, fara campuri in plus",
            function()
                local l = LookMath.clean({
                    body = 1,
                    hair = 99,
                    skin = "x",
                    hairColor = 6,
                    altceva = true,
                })
                check.equal(l.body, 1)
                check.equal(l.hair, LookMath.DEFAULT.hair)
                check.equal(l.skin, LookMath.DEFAULT.skin)
                check.equal(l.hairColor, 6)
                check.is_true((l :: any).altceva == nil)
                -- un tabel nou: implicitul nu se poate strica prin el
                l.body = 2
                check.equal(LookMath.DEFAULT.body, LookMath.clean(nil).body)
            end
        )

        test.case("sagetile din panou merg in cerc, in ambele sensuri", function()
            local l = LookMath.clean({ body = 1, hair = 1, skin = 1, hairColor = 1 })
            check.equal(LookMath.step(l, "hair", 1).hair, 2)
            check.equal(LookMath.step(l, "hair", -1).hair, #SettlerConfig.HAIR_STYLES)
            local last =
                LookMath.clean({ body = 1, hair = 1, skin = #SettlerConfig.SKIN, hairColor = 1 })
            check.equal(LookMath.step(last, "skin", 1).skin, 1)
            -- un camp necunoscut nu schimba nimic
            check.is_true(LookMath.same(LookMath.step(l, "nas", 1), l))
            -- pasul nu schimba tabelul primit
            check.equal(l.hair, 1)
        end)

        test.case("same compara cele patru campuri", function()
            local a = LookMath.clean({ body = 1, hair = 2, skin = 3, hairColor = 4 })
            check.is_true(
                LookMath.same(a, LookMath.clean({ body = 1, hair = 2, skin = 3, hairColor = 4 }))
            )
            check.is_false(
                LookMath.same(a, LookMath.clean({ body = 1, hair = 2, skin = 3, hairColor = 5 }))
            )
        end)
    end)
end
