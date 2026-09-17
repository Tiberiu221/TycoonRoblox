-- Limitarea de rata a remote-urilor. Testul apara doua lucruri: ca o limita chiar opreste un client
-- care trage in rafala, si ca un nume de bucket gresit NU mai inseamna "fara limita" [D49].
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local fs = require("@lune/fs")
local RateLimiter = require("../src/Server/Net/RateLimiter")

return function()
    test.suite("RateLimiter", function()
        test.case(
            "o rafala trece pana la capacitate, apoi se opreste si se reumple in timp",
            function()
                local player: any = {}
                local limit = RateLimiter.LIMITS.UsePlace
                local passed = 0
                for _ = 1, limit.capacity + 3 do
                    if RateLimiter.Allow(player, "UsePlace", 100) then
                        passed += 1
                    end
                end
                check.equal(passed, limit.capacity)
                -- dupa o secunda intra din nou cat se reumple
                check.is_true(RateLimiter.Allow(player, "UsePlace", 101))
                RateLimiter.Forget(player)
            end
        )

        test.case("un bucket necunoscut refuza, nu lasa totul sa treaca", function()
            -- pana in D49 intorcea `true`: SpinWheel imprumuta bucket-ul lui SellSack, iar scoaterea
            -- lui SellSack i-ar fi scos in tacere orice limita
            local player: any = {}
            check.is_false(RateLimiter.Allow(player, "NuExista", 5))
            RateLimiter.Forget(player)
        end)

        test.case("fiecare bucket cerut de NetServer si de FairNetServer exista", function()
            -- [D61] si serverul balciului: o greseala de scriere acolo ar fi refuzat in tacere orice cerere
            for _, path in
                { "src/Server/Net/NetServer.luau", "src/Fair/Server/Net/FairNetServer.luau" }
            do
                local src = fs.readFile(path)
                local seen = 0
                for name in string.gmatch(src, 'RateLimiter%.Allow%(player, "(%w+)"%)') do
                    seen += 1
                    if RateLimiter.LIMITS[name] == nil then
                        print(`  ! bucket lipsa in {path}: {name}`)
                    end
                    check.not_nil(RateLimiter.LIMITS[name])
                end
                check.is_true(seen >= 5)
            end
        end)
    end)
end
