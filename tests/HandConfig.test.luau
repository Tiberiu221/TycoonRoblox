local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local HandConfig = require("../src/Shared/Config/HandConfig")
local SettlerConfig = require("../src/Shared/Config/SettlerConfig")

local function contains(list: { any }, value: any): boolean
    for _, v in list do
        if v == value then
            return true
        end
    end
    return false
end

return function()
    test.suite("HandConfig", function()
        test.case(
            "fiecare meserie are tinuta ei, iar Collector-ul poarta ce purta alergatorul",
            function()
                check.equal(HandConfig.ROLE_OUTFIT.collector, "Fisher")
                local StationConfig = require("../src/Shared/Config/StationConfig")
                local Assets = require("../src/Shared/Config/Assets")
                for _, role in StationConfig.ROLES do
                    local outfit = HandConfig.ROLE_OUTFIT[role]
                    check.not_nil(outfit)
                    check.not_nil((Assets.people.outfit :: any)[outfit])
                end
            end
        )

        test.case(
            "clientii tavernei nu poarta hainele niciunei meserii si nici ale tale",
            function()
                -- [D50, D44] un client in hainele unui om al tau ar parea un om care sta degeaba
                local Assets = require("../src/Shared/Config/Assets")
                check.is_true(#HandConfig.CUSTOMER_OUTFITS >= 1)
                for _, outfit in HandConfig.CUSTOMER_OUTFITS do
                    check.not_nil((Assets.people.outfit :: any)[outfit])
                    check.is_true(outfit ~= "keeper")
                    for _, roleOutfit in HandConfig.ROLE_OUTFIT do
                        check.is_true(outfit ~= roleOutfit)
                    end
                end
            end
        )

        test.case("appearanceFor e deterministic: acelasi seed, acelasi angajat", function()
            local a = HandConfig.appearanceFor(12345)
            local b = HandConfig.appearanceFor(12345)
            check.equal(a.body, b.body)
            check.equal(a.hair, b.hair)
            check.equal(a.skin[1], b.skin[1])
            check.equal(a.hairColor[1], b.hairColor[1])
        end)

        test.case("appearanceFor produce mereu valori din palete", function()
            for seed = 1, 20 do
                local id = HandConfig.appearanceFor(seed * 991)
                check.is_true(contains(SettlerConfig.BUILDS, id.body))
                check.is_true(contains(SettlerConfig.HAIR_STYLES, id.hair))
                check.equal(#id.skin, 3)
                check.equal(#id.hairColor, 3)
            end
        end)

        test.case("nameFor e determinist si vine din bazinul satenilor", function()
            local n1 = HandConfig.nameFor(777)
            local n2 = HandConfig.nameFor(777)
            check.equal(n1, n2)
            check.is_true(contains(SettlerConfig.FIRST, n1))
        end)

        test.case("[D65] un om nou nu ia prenumele altuia din sat", function()
            local StationConfig = require("../src/Shared/Config/StationConfig")
            -- liber: exact prenumele de pana acum (satele existente isi pastreaza oamenii)
            check.equal(HandConfig.nameAvoiding(777, {}), HandConfig.nameFor(777))
            -- luat: altul, tot determinist
            local taken = { [HandConfig.nameFor(777)] = true }
            local other = HandConfig.nameAvoiding(777, taken)
            check.is_true(other ~= HandConfig.nameFor(777))
            check.equal(other, HandConfig.nameAvoiding(777, taken))
            -- un sat intreg, cu doi oameni pe fiecare meserie: niciun prenume de doua ori
            local used: { [string]: boolean } = {}
            local people = #StationConfig.ROLES * StationConfig.MAX_PEOPLE
            for i = 1, people do
                local name = HandConfig.nameAvoiding(i * 7919, used)
                check.is_true(used[name] == nil)
                used[name] = true
            end
            -- prenumele in plus nu le dubleaza pe ale satenilor
            for _, name in HandConfig.MORE_NAMES do
                check.is_false(contains(SettlerConfig.FIRST, name))
            end
        end)

        test.case("nameFor nu e mereu acelasi ca primul camp tras de appearanceFor", function()
            -- garda impotriva bug-ului "acelasi rng, acelasi prim numar": corpul si numele ar fi
            -- mereu cuplate (tot angajatii cu corp "a" ar avea acelasi nume)
            local seenNamesForBodyA: { [string]: boolean } = {}
            local variety = 0
            for seed = 1, 40 do
                local id = HandConfig.appearanceFor(seed)
                if id.body == "a" then
                    local name = HandConfig.nameFor(seed)
                    if not seenNamesForBodyA[name] then
                        seenNamesForBodyA[name] = true
                        variety += 1
                    end
                end
            end
            check.is_true(variety > 1)
        end)
    end)
end
