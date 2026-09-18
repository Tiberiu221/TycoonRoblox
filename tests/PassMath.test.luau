--!strict
-- [D61, partea 2] Ce fac pass-urile si produsele, in cifre; catalogul lor; chitantele onorate.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local PassMath = require("../src/Shared/Modules/PassMath")
local MonetizationConfig = require("../src/Shared/Config/MonetizationConfig")
local OfflineCalc = require("../src/Shared/Modules/OfflineCalc")
local Assets = require("../src/Shared/Config/Assets")

local function with(...: string): { [string]: any }
    local passes: { [string]: boolean } = {}
    for _, key in { ... } do
        passes[key] = true
    end
    return { Purchases = { ids = {}, passes = passes } }
end

return function()
    test.suite("PassMath", function()
        test.case(
            "fara pass-uri nimic nu se schimba; un profil stricat e un profil fara pass-uri",
            function()
                for _, data in
                    { {}, { Purchases = 4 }, { Purchases = { passes = "x" } }, with() } :: { any }
                do
                    check.equal(PassMath.flowFactor(data), 1)
                    check.equal(PassMath.speedFactor(data), 1)
                    check.equal(PassMath.offlineCapSeconds(data), 24 * 3600)
                end
                check.is_false(PassMath.has(nil, "flow2x"))
                check.is_false(PassMath.has("x", "flow2x"))
            end
        )

        test.case("fiecare pass face exact ce scrie pe el, si doar atat", function()
            check.equal(PassMath.flowFactor(with("flow2x")), 2)
            check.equal(PassMath.speedFactor(with("flow2x")), 1)
            check.equal(PassMath.speedFactor(with("swift")), 1.5)
            check.equal(PassMath.flowFactor(with("swift")), 1)
            check.equal(PassMath.offlineCapSeconds(with("nights")), 48 * 3600)
            check.equal(PassMath.offlineCapSeconds(with("flow2x", "swift", "supporter")), 24 * 3600)
            -- Supporter e doar aspect: niciun numar nu se misca
            check.equal(PassMath.flowFactor(with("supporter")), 1)
            check.equal(PassMath.speedFactor(with("supporter")), 1)
            -- doar `true` inseamna ca il ai
            check.is_false(PassMath.has({ Purchases = { passes = { flow2x = 1 } } }, "flow2x"))
        end)

        test.case("One Hour of Flow: o ora din venitul de acum, intreaga, cu un minim", function()
            check.equal(PassMath.hourOfFlow(10), 36000)
            check.equal(PassMath.hourOfFlow(0.5), 1800)
            check.equal(PassMath.hourOfFlow(111.65), math.floor(111.65 * 3600))
            check.equal(PassMath.hourOfFlow(0), PassMath.HOUR_MIN_COINS)
            check.equal(PassMath.hourOfFlow(0.001), PassMath.HOUR_MIN_COINS)
            check.equal(PassMath.hourOfFlow(-5), PassMath.HOUR_MIN_COINS)
            check.equal(PassMath.hourOfFlow(0 / 0), PassMath.HOUR_MIN_COINS)
        end)

        test.case(
            "Welcome Back x2: inca o data suma de la revenire; fara ea, nu ramai cu mana goala",
            function()
                check.equal(PassMath.welcomeDouble(1234.7, 10), 1234)
                check.equal(PassMath.welcomeDouble(0, 10), math.floor(36000 * 0.8))
                check.equal(
                    PassMath.welcomeDouble(0 / 0, 0),
                    math.floor(PassMath.HOUR_MIN_COINS * 0.8)
                )
                check.is_true(PassMath.welcomeDouble(0, 0) > 0)
            end
        )

        test.case("chitantele: aceeasi nu se tine de doua ori, iar lista ramane scurta", function()
            local ids: { string } = {}
            PassMath.rememberReceipt(ids, "a")
            PassMath.rememberReceipt(ids, "a")
            check.equal(#ids, 1)
            check.is_true(PassMath.hasReceipt(ids, "a"))
            check.is_false(PassMath.hasReceipt(ids, "b"))
            check.is_false(PassMath.hasReceipt(nil, "a"))
            for i = 1, PassMath.PURCHASE_IDS_KEPT + 20 do
                PassMath.rememberReceipt(ids, `p{i}`)
            end
            check.equal(#ids, PassMath.PURCHASE_IDS_KEPT)
            check.is_false(PassMath.hasReceipt(ids, "a")) -- cele mai vechi ies primele
            check.is_true(PassMath.hasReceipt(ids, `p{PassMath.PURCHASE_IDS_KEPT + 20}`))
        end)

        test.case(
            "Long Nights: satul lucreaza pana la 48 de ore, nu 24; fara pass, ca pana acum",
            function()
                local day = 24 * 3600
                local base = OfflineCalc.computeIdle(3 * day, 1, 2)
                check.equal(base.seconds, day)
                check.is_true(base.cappedByTime)
                local long = OfflineCalc.computeIdle(
                    3 * day,
                    1,
                    2,
                    PassMath.offlineCapSeconds(with("nights"))
                )
                check.equal(long.seconds, 2 * day)
                check.equal(long.coins, 2 * day * 2)
                check.is_true(long.cappedByTime)
                -- sub plafon nu se schimba nimic
                local short = OfflineCalc.computeIdle(3601, 1, 2, 2 * day)
                check.equal(short.seconds, 3600)
                check.is_false(short.cappedByTime)
                -- un plafon stricat cade pe cel implicit, niciodata pe "fara plafon"
                for _, cap in { 0, -5, 0 / 0 } do
                    check.equal(OfflineCalc.computeIdle(3 * day, 1, 2, cap).seconds, day)
                end
            end
        )
    end)

    test.suite("MonetizationConfig", function()
        test.case(
            "ce se vinde: viteza, spatiu, aspect -- niciodata noroc, perle sau lazi [D20, D46]",
            function()
                local keys: { [string]: boolean } = {}
                for _, item in MonetizationConfig.ITEMS do
                    check.is_false(keys[item.key] == true)
                    keys[item.key] = true
                    check.is_true(item.kind == "pass" or item.kind == "product")
                    check.is_true(
                        item.where == "shop" or item.where == "village" or item.where == "welcome"
                    )
                    check.is_true(#item.name > 0 and #item.blurb > 0)
                    check.is_true(item.suggested >= 1)
                    local text = string.lower(item.name .. " " .. item.blurb)
                    for _, banned in
                        {
                            "luck",
                            "chance",
                            "crate",
                            "chest",
                            "pearl",
                            "random",
                            "spin",
                            "only today",
                        }
                    do
                        check.equal(string.find(text, banned, 1, true), nil)
                    end
                    -- pictograma exista si e urcata: un rand fara desen ar arata stricat
                    local icon = (Assets.icons :: any)[item.icon]
                    check.not_nil(icon)
                    check.is_true(Assets.has(icon))
                end
                -- fiecare pass are un efect in PassMath sau e doar aspect; produsele pe monede se vand doar in sat
                check.equal(MonetizationConfig.byKey.hour.where, "village")
                check.equal(MonetizationConfig.byKey.welcome2x.where, "welcome")
            end
        )

        test.case("ID-urile: pe univers, toate cheile, 0 = inca necreat", function()
            for gameId, ids in MonetizationConfig.IDS do
                for _, item in MonetizationConfig.ITEMS do
                    check.equal(typeof(ids[item.key]), "number")
                    check.is_true(ids[item.key] >= 0)
                end
                for key in ids do
                    check.not_nil(MonetizationConfig.byKey[key])
                end
                check.equal(MonetizationConfig.idOf(gameId, "nu_exista"), 0)
            end
            check.equal(MonetizationConfig.idOf(1, "flow2x"), 0) -- univers necunoscut (Studio, fisier local)
            check.equal(MonetizationConfig.keyOf(1, "pass", 5), nil)
            check.equal(MonetizationConfig.keyOf(10765888327, "pass", 0), nil)
        end)

        test.case(
            "cheia se gaseste dupa ID si fel: o chitanta de produs nu poate acorda un pass",
            function()
                local gameId = 424242
                MonetizationConfig.IDS[gameId] = { flow2x = 111, hour = 222 }
                check.equal(MonetizationConfig.keyOf(gameId, "pass", 111), "flow2x")
                check.equal(MonetizationConfig.keyOf(gameId, "product", 222), "hour")
                check.equal(MonetizationConfig.keyOf(gameId, "product", 111), nil)
                check.equal(MonetizationConfig.keyOf(gameId, "pass", 222), nil)
                check.equal(MonetizationConfig.idOf(gameId, "flow2x"), 111)
                MonetizationConfig.IDS[gameId] = nil
            end
        )
    end)
end
