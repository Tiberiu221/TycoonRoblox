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
                    check.equal(PassMath.offlineCurve(data).full, 8 * 3600) -- [D66, D71] o noapte, plin
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
            check.equal(PassMath.offlineCurve(with("nights")).full, 16 * 3600)
            check.equal(PassMath.offlineCurve(with("flow2x", "swift", "supporter")).full, 8 * 3600)
            -- [D71] oprirea de la 24 h e aceeasi pentru toti: revenirea zilnica nu se cumpara
            check.equal(PassMath.offlineCurve(with("nights")).stop, 24 * 3600)
            check.equal(PassMath.offlineCurve(with()).stop, 24 * 3600)
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
            "Long Nights: viteza intreaga 16 ore, nu 8; apoi aceeasi curba pana la 24 h [D66, D71]",
            function()
                local H = 3600
                local nights = PassMath.offlineCurve(with("nights"))
                local free = PassMath.offlineCurve(with())
                -- nimic platit nu se taie: Long Nights plateste macar cat inainte de D71 (plin pana la 16 h), la orice
                -- absenta, si mai mult decat fara pass de la 8 h incolo
                for h = 0, 40, 0.5 do
                    local long = OfflineCalc.paidSeconds(h * H, nights)
                    check.is_true(long >= math.min(h, 16) * H)
                    check.is_true(long >= OfflineCalc.paidSeconds(h * H, free))
                    if h > 8 then
                        check.is_true(long > OfflineCalc.paidSeconds(h * H, free))
                    end
                end
                local r = OfflineCalc.computeIdle(1 + 72 * H, 1, 2, nights)
                check.equal(r.paid, 16 * H + 8 * H * PassMath.OFFLINE_SLOW)
                check.equal(r.coins, r.paid * 2)
                check.equal(r.phase, "rested")
                -- implicitul modulului pur e chiar curba fara pass
                check.equal(OfflineCalc.DEFAULT_CURVE.full, free.full)
                check.equal(OfflineCalc.DEFAULT_CURVE.stop, free.stop)
                check.equal(OfflineCalc.DEFAULT_CURVE.slow, free.slow)
                -- iar fereastra "Welcome back" spune orele adevarate [D40]
                local Strings = require("../src/Shared/Config/Strings")
                check.equal(
                    Strings.welcomeSlow(PassMath.OFFLINE_HOURS, PassMath.OFFLINE_STOP_HOURS),
                    "Your village worked at full speed for 8 hours, then at quarter speed. It rests after 24 hours."
                )
                check.equal(
                    Strings.welcomeRested(PassMath.OFFLINE_HOURS_LONG, PassMath.OFFLINE_STOP_HOURS),
                    "Full speed for 16 hours, then quarter speed. After 24 hours your village rests until you come back."
                )
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
                    -- pictograma de rezerva exista si e urcata: un rand fara desen ar arata stricat
                    local icon = (Assets.icons :: any)[item.icon]
                    check.not_nil(icon)
                    check.is_true(Assets.has(icon))
                    -- [D63] pictograma proprie are intrare in Assets (urcata sau nu) si e a ofertei ei, nu a alteia
                    check.not_nil((Assets.icons :: any)[item.art])
                    check.equal(item.art, "shop_" .. item.key)
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
    -- [D70, pasul j5; R8] monedele cumparate cu Robux inca in mana (R): ultimele cheltuite
    test.suite("PassMath - monedele cumparate (R) [D70]", function()
        test.case("cumperi 10 si ai 20; cheltui 5: R ramane 10", function()
            local bought = PassMath.afterGrant(0, 10)
            check.equal(bought, 10)
            check.equal(PassMath.afterCoins(bought, 20 - 5), 10)
        end)

        test.case("monedele scad la 3: R scade la 3, si nu mai urca singur", function()
            local bought = PassMath.afterCoins(10, 3)
            check.equal(bought, 3)
            check.equal(PassMath.afterCoins(bought, 500), 3)
            check.equal(PassMath.afterGrant(bought, 7), 10)
        end)

        test.case("valori stricate din profil nu dau un R negativ sau infinit", function()
            check.equal(PassMath.afterGrant(nil, 5), 5)
            check.equal(PassMath.afterGrant(-4, 5), 5)
            check.equal(PassMath.afterCoins(0 / 0, 9), 0)
            check.equal(PassMath.afterCoins(math.huge, 9), 0)
            check.equal(PassMath.afterCoins(4, -1), 0)
        end)

        test.case("fiecare scadere a monedelor taie R, iar o cumparare il creste", function()
            local fs = require("@lune/fs")
            local economy = fs.readFile("src/Server/Services/EconomyService.luau")
            local spend =
                string.match(economy, "function EconomyService%.TrySpend%(.-\nend") :: string
            check.is_true(string.find(spend, "EconomyService.TrimBought(data)", 1, true) ~= nil)
            local add =
                string.match(economy, "function EconomyService%.AddCoins%(.-\nend") :: string
            check.is_true(string.find(add, "EconomyService.TrimBought(data)", 1, true) ~= nil)
            local dev = fs.readFile("src/Server/Services/DevService.luau")
            local setcoins = string.match(dev, "setcoins = function.-\n    end,") :: string
            check.is_true(string.find(setcoins, "EconomyService.TrimBought(data)", 1, true) ~= nil)
            -- o angajare rambursata pune contorul la loc (monedele s-au intors la cat erau)
            local station = fs.readFile("src/Server/Services/StationService.luau")
            local refund = string.match(station, "crew_hire_refund.-return false") :: string
            check.is_true(
                string.find(refund, "data.Purchases.coinsBought = boughtBefore", 1, true) ~= nil
            )
            local purchase = fs.readFile("src/Server/Services/PurchaseService.luau")
            check.is_true(
                string.find(
                    purchase,
                    "PassMath.afterGrant(data.Purchases.coinsBought, coins)",
                    1,
                    true
                ) ~= nil
            )
        end)
    end)
    -- [D70, verificator] meseriile barajului au rand in CREWS, dar nu sunt in lant: serverul le refuza, nu crapa
    test.suite("Meseriile barajului adormit [D70]", function()
        test.case("CrewMath nu le are; UpgradeCrew si Hire le refuza inainte de .count", function()
            local CrewMath = require("../src/Shared/Modules/CrewMath")
            local StationConfig = require("../src/Shared/Config/StationConfig")
            local crews = CrewMath.fromProfile({}, {})
            for _, role in StationConfig.ERA4_ROLES do
                check.equal(crews[role], nil)
            end
            local fs = require("@lune/fs")
            local station = fs.readFile("src/Server/Services/StationService.luau")
            local upgrade =
                string.match(station, "function StationService%.UpgradeCrew%(.-\nend") :: string
            local guard = string.find(upgrade, "if crew == nil then", 1, true) :: number
            check.not_nil(guard)
            check.is_true(guard < (string.find(upgrade, "canUpgradeTier", 1, true) :: number))
            local hands = fs.readFile("src/Server/Services/HandService.luau")
            local hire = string.match(hands, "function HandService%.Hire%(.-\nend") :: string
            check.is_true(string.find(hire, "if crew == nil then", 1, true) ~= nil)
            check.is_true(string.find(hire, "crews[role].count", 1, true) == nil)
            local dev = fs.readFile("src/Server/Services/DevService.luau")
            check.is_true(
                string.find(dev, "table.find(StationConfig.ROLES, role :: string) == nil", 1, true)
                    ~= nil
            )
        end)
    end)
end
