--!strict
-- [D70, pasul j15] Barajul pe server: ordinea Init, remote-urile, limita, garzile cererilor, uneltele de proba. Serviciile
-- au nevoie de `game`, deci se verifica textul lor; socoteala e in DamMath (tests/DamMath.test.luau).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local fs = require("@lune/fs")

local function has(text: string, needle: string): boolean
    return string.find(text, needle, 1, true) ~= nil
end

local function at(text: string, needle: string): number
    local i = string.find(text, needle, 1, true)
    if i == nil then
        print(`[DamService] lipseste: {needle}`)
    end
    check.not_nil(i)
    return i or 0
end

return function()
    test.suite("DamService - pe server [D70, pasul j15]", function()
        test.case(
            "ordinea Init: dupa serviciile citite, inaintea retelei si a profilelor",
            function()
                local boot = fs.readFile("src/Server/Bootstrap.server.luau")
                local dam = at(boot, "DamService.Init(")
                for _, before in
                    {
                        "EconomyService.Init(",
                        "StationService.Init(",
                        "PadService.Init(",
                        "RiverService.Init(",
                    }
                do
                    check.is_true(at(boot, before) < dam)
                end
                check.is_true(dam < at(boot, "NetServer.Init("))
                check.is_true(dam < at(boot, "DataService.Init("))
                check.is_true(has(boot, "Dam = DamService,"))
                check.is_true(has(boot, "Settled = StationService.Settled,"))
            end
        )

        test.case("doar in sat: balciul nu monteaza serviciul barajului", function()
            check.is_false(has(fs.readFile("fair.project.json"), "DamService"))
            local fairBoot = "src/Fair/Server/Bootstrap.server.luau"
            if fs.isFile(fairBoot) then
                check.is_false(has(fs.readFile(fairBoot), "DamService"))
            end
        end)

        test.case("remote-urile, limita si garzile cererilor", function()
            local net = fs.readFile("src/Shared/Net/Net.luau")
            for _, name in
                {
                    "DamPreview",
                    "DamPreviewResult",
                    "BuildDam",
                    "DamBuilt",
                    "DamRejected",
                    "DamFilmSeen",
                }
            do
                check.is_true(has(net, `"{name}"`))
            end
            local RateLimiter = require("../src/Server/Net/RateLimiter")
            check.not_nil(RateLimiter.LIMITS.Dam)
            local server = fs.readFile("src/Server/Net/NetServer.luau")
            local build = string.match(server, 'Net%.Get%("BuildDam"%).-\n    end%)') or ""
            check.is_true(has(build, 'RateLimiter.Allow(player, "Dam")'))
            check.is_true(has(build, "math.isfinite"))
            -- o cerere refuzata primeste mereu raspuns: ecranul asteapta unul [D43]
            check.is_true(has(build, '"DamRejected"):FireClient(player, "busy")'))
            local preview = string.match(server, 'Net%.Get%("DamPreview"%).-\n    end%)') or ""
            check.is_true(has(preview, 'RateLimiter.Allow(player, "Dam")'))
            check.is_true(has(preview, '"DamPreviewResult"):FireClient(player, nil, "busy")'))
        end)

        test.case(
            "ridicarea: garzile de sesiune inaintea socotelii, salvarea fortata dupa ea",
            function()
                local src = fs.readFile("src/Server/Services/DamService.luau")
                local body = string.match(src, "function DamService%.Build%(.-\nend") or ""
                local busy = at(body, '"busy"')
                local settling = at(body, '"settling"')
                local changed = at(body, '"changed"')
                local apply = at(body, "DamMath.build(data, ctx)")
                check.is_true(busy < apply and settling < apply and changed < apply)
                check.is_true(apply < at(body, "d.Invalidate(player)"))
                check.is_true(apply < at(body, 'player:SetAttribute("World", data.World)'))
                check.is_true(apply < at(body, "DataService.SaveNow(profile"))
                -- intre previzualizare si ridicare nimic nu cedeaza: salvarea (care cedeaza) vine abia dupa
                local between = string.sub(body, at(body, "DamMath.preview(data, ctx)"), apply)
                check.is_false(has(between, "task.wait"))
                check.is_false(has(between, "SaveNow"))
            end
        )

        test.case("salvarea fortata e una singura, comuna cu chitantele Robux", function()
            local purchase = fs.readFile("src/Server/Services/PurchaseService.luau")
            check.is_true(has(purchase, "DataService.SaveNow(profile, saved)"))
            check.is_false(has(purchase, "profile:Save()"))
            local data = fs.readFile("src/Server/Services/DataService.luau")
            check.is_true(has(data, "function DataService.SaveNow("))
            check.is_true(
                has(
                    data,
                    "SaveLoop.run(profile, isSaved, task.wait, DataService.SAVE_RETRY_SECONDS)"
                )
            )
        end)

        test.case("uneltele de proba: lumea doar 1..COUNT, barajul pe drumul adevarat", function()
            local dev = fs.readFile("src/Server/Services/DevService.luau")
            local world = string.match(dev, "\n    world = function%(.-\n    end,") or ""
            check.is_true(has(world, "w > WorldConfig.COUNT"))
            check.is_true(has(world, "w ~= math.floor(w)"))
            local dam = string.match(dev, "\n    dam = function%(.-\n    end,") or ""
            check.is_true(has(dam, "DamService.Preview(player)"))
            check.is_true(has(dam, "DamService.Build(player, receipt.coinsAfter)"))
        end)
        -- [D70, pasul k8] dupa ridicare (si film, la k9): acelasi place, harta noua, cu drumul barcii
        test.case(
            "reincarcarea in lumea 2: drumul barcii, spre acelasi place, cu raspunsul ei",
            function()
                local ferry = fs.readFile("src/Server/Services/FerryService.luau")
                check.is_true(
                    has(ferry, "function FerryService.Depart(player: Player, trip: Trip?)")
                )
                check.is_true(has(ferry, "trip.destination"))
                check.is_true(has(ferry, "trip.onFailed"))
                check.is_true(has(ferry, "trip.travel"))
                -- un drum esuat raspunde celui care l-a cerut (ecranul barajului, nu barca)
                check.is_true(has(ferry, "trip.onFailed(player, reason)"))
                local service = fs.readFile("src/Server/Services/DamService.luau")
                local film = string.match(service, "function DamService%.FilmSeen%(.-\nend") or ""
                check.is_true(has(film, "data.World ~= 1"))
                check.is_true(has(film, "reload(player)"))
                local boot = fs.readFile("src/Server/Bootstrap.server.luau")
                check.is_true(has(boot, 'destination = "village"'))
                check.is_true(has(boot, 'Net.Get("DamReloadFailed"):FireClient(p, why)'))
                -- [verificatorul k7-k8] in Studio conteaza „keep save”; cererea refuzata de limita primeste si ea raspuns
                check.is_true(has(boot, 'then "studio_kept"') and has(boot, 'else "studio_fresh"'))
                local net = fs.readFile("src/Server/Net/NetServer.luau")
                check.is_true(has(net, 'Net.Get("DamReloadFailed"):FireClient(player, "busy")'))
                local client = fs.readFile("src/Client/Controllers/DamController.luau")
                check.is_true(has(client, "DamReloadFailed.OnClientEvent"))
                local screen = fs.readFile("src/Client/Controllers/DamScreen.luau")
                check.is_true(has(screen, "TeleportService:SetTeleportGui(travelCard())"))
                -- in Studio barca nu pleaca: ecranul spune ce sa faci, fara „Try again”
                local Strings = require("../src/Shared/Config/Strings")
                check.is_true(has(Strings.damReloadFailed("studio_kept"), "Stop, then Play"))
                check.is_true(has(Strings.damReloadFailed("studio_fresh"), "keep save"))
            end
        )
    end)
end
