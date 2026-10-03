-- [D70, pasul j10] Ce se poate face in fiecare lume: poarta (WorldMath.allowed), era fiecarui lucru cerut de jucator,
-- zonele pe lume si conditia de venit a clopotului barajului (TycoonMath.incomeGoal).
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local fs = require("@lune/fs")

local TycoonConfig = require("../src/Shared/Config/TycoonConfig")
local TycoonMath = require("../src/Shared/Modules/TycoonMath")
local WorldMath = require("../src/Shared/Modules/WorldMath")
local Strings = require("../src/Shared/Config/Strings")

local function allBought(pads: { TycoonConfig.Pad }, except: string?): { [string]: boolean }
    local out: { [string]: boolean } = {}
    for _, p in pads do
        if p.id ~= except then
            out[p.id] = true
        end
    end
    return out
end

local function damLive(era: number): boolean
    return era <= 4 -- barajul pornit, ca dupa comutatorul l3
end

return function()
    test.suite("WorldMath [D70, pasul j10]", function()
        test.case(
            "poarta: un lucru al erelor 1-3 doar in sat, al barajului doar la baraj",
            function()
                for era = 1, 3 do
                    check.is_true(WorldMath.allowed(1, era))
                    check.is_false(WorldMath.allowed(2, era))
                end
                check.is_true(WorldMath.allowed(2, 4))
                check.is_false(WorldMath.allowed(1, 4))
                -- era necunoscuta: hotarasc serviciile, ca pana acum; o lume stricata e satul
                check.is_true(WorldMath.allowed(1, nil))
                check.is_true(WorldMath.allowed(2, nil))
                check.is_true(WorldMath.allowed("2", 1))
                check.is_true(WorldMath.allowed(nil, 3))
            end
        )

        test.case("era fiecarei cladiri, a fiecarui loc si a fiecarei meserii", function()
            check.equal(WorldMath.eraOfStation("saw"), 1)
            check.equal(WorldMath.eraOfStation("dock"), 1)
            check.equal(WorldMath.eraOfStation("foundry"), 2)
            check.equal(WorldMath.eraOfStation("depot"), 3)
            check.equal(WorldMath.eraOfStation("relay"), 4)
            check.equal(WorldMath.eraOfStation("town"), 4)
            check.equal(WorldMath.eraOfStation("net", "first_net"), 1)
            check.equal(WorldMath.eraOfStation("net", "dam_turbine"), 4)
            check.equal(WorldMath.eraOfStation("net", nil), nil)
            check.equal(WorldMath.eraOfPlace("storage"), 1)
            check.equal(WorldMath.eraOfPlace("sawmill"), 1)
            check.equal(WorldMath.eraOfPlace("damStore"), 4)
            check.equal(WorldMath.eraOfPlace("relay"), 4)
            check.equal(WorldMath.eraOfPlace("town"), 4)
            check.equal(WorldMath.eraOfRole("collector"), 1)
            check.equal(WorldMath.eraOfRole("relayKeeper"), 4)
        end)

        test.case(
            "zonele pe lume: zona barajului din sat se incuie cand barajul e in joc",
            function()
                local none: { [string]: string } = {}
                local village = WorldMath.zoneStatuses(1, none)
                check.equal(village.landing, "open")
                check.equal(village.mill, "locked")
                check.equal(village.dam, "locked")
                local works =
                    { works_bell = "bought", mill_bell = "bought", landing_bell = "bought" }
                -- azi: dupa Works Bell zona barajului se deschide (si scrie „coming soon”), ca pana acum
                local today = function(era: number): boolean
                    return era <= 3 -- fara comutator
                end
                check.equal(WorldMath.zoneStatuses(1, works, today).dam, "open")
                -- si pe calea pe care o cheama serverul (fara `eraIsLive`), de o parte si de alta a comutatorului
                check.equal(
                    WorldMath.zoneStatuses(1, works).dam,
                    if TycoonConfig.eraIsLive(4) then "locked" else "open"
                )
                -- cu barajul in joc ramane incuiata: barajul se ridica pe alta harta
                check.equal(WorldMath.zoneStatuses(1, works, damLive).dam, "locked")
                check.equal(WorldMath.zoneStatuses(1, works, damLive).wire_works, "open")
                -- la baraj: Dam Town deschisa de la inceput, ceata Erei 5 dupa Dam Bell
                local dam = WorldMath.zoneStatuses(2, none, damLive)
                check.equal(dam.dam_town, "open")
                check.equal(dam.fog5, "locked")
                check.equal(dam.landing, nil)
                check.equal(
                    WorldMath.zoneStatuses(2, { dam_bell = "bought" }, damLive).fog5,
                    "open"
                )
            end
        )

        test.case(
            "clopotul barajului cere venitul, dublu cu 2x Flow; cartonasul spune pragul",
            function()
                check.equal(TycoonMath.incomeGoal(4e12, nil), 4e12)
                check.equal(TycoonMath.incomeGoal(4e12, 2), 8e12)
                local pads = TycoonConfig.padsOfWorld(2)
                local bought = allBought(pads, "dam_bell")
                local bell = TycoonConfig.byId.dam_bell
                -- Era 4 adormita: nicio platforma a ei nu e de cumparat inca (padStatuses le sare)
                -- dupa comutator (l3), da
                check.equal(
                    TycoonMath.padStatuses(bought, pads, nil, 5e12, 1).dam_bell,
                    if TycoonConfig.eraIsLive(4) then "available" else nil
                )
                -- [verificatorul j10] poarta pe care se sprijina BuyPad, ca dupa comutatorul l3: copii `live` ale platformelor
                -- barajului. Cartonasul (padBlocker) si cumpararea (padStatuses) spun acelasi lucru la fiecare prag.
                local livePads: { TycoonConfig.Pad } = {}
                for _, p in pads do
                    local q = table.clone(p)
                    q.live = true
                    table.insert(livePads, q)
                end
                for _, case in
                    {
                        { 3.9e12, 1, "outline" },
                        { 4e12, 1, "available" },
                        { 5e12, 2, "outline" },
                        { 8e12, 2, "available" },
                        { nil, 1, "outline" },
                    } :: { { any } }
                do
                    local income, flow, want = case[1], case[2], case[3]
                    local got = TycoonMath.padStatuses(bought, livePads, nil, income, flow).dam_bell
                    check.equal(`{income}/{flow}: {got}`, `{income}/{flow}: {want}`)
                    local stops = TycoonMath.padBlocker(bell, bought, nil, livePads, income, flow)
                    check.equal(stops == nil, want == "available")
                end
                -- conditia insasi, pe cartonas
                local function blocker(income: number?, flow: number?): TycoonMath.Blocker?
                    return TycoonMath.padBlocker(bell, bought, nil, pads, income, flow)
                end
                check.equal(blocker(5e12, 1), nil)
                check.equal(blocker(4e12, 1), nil)
                local low = blocker(3.9e12, 1) :: TycoonMath.Blocker
                check.equal(low.kind, "income")
                check.equal(low.goalText, "4T")
                check.equal(Strings.padNeeds(low), "Earn 4T coins a second first")
                local doubled = blocker(5e12, 2) :: TycoonMath.Blocker
                check.equal(doubled.kind, "income")
                check.equal(doubled.goalText, "8T")
                check.equal(blocker(8e12, 2), nil)
                -- fara venit cunoscut, conditia nu e implinita
                check.equal((blocker(nil, 1) :: TycoonMath.Blocker).kind, "income")
                -- restul erei inaintea venitului
                local missing =
                    TycoonMath.padBlocker(bell, {}, nil, pads, 9e12, 1) :: TycoonMath.Blocker
                check.is_true(missing.kind ~= "income")
            end
        )

        test.case("clopotul de dinaintea unei ere, pe lumea jucatorului", function()
            -- in sat, fiecare era asteapta clopotul celei dinainte; zona barajului vazuta din sat, tot Works Bell
            check.equal(WorldMath.bellBefore(1, 1), nil)
            check.equal((WorldMath.bellBefore(2, 1) :: TycoonConfig.Pad).id, "landing_bell")
            check.equal((WorldMath.bellBefore(3, 1) :: TycoonConfig.Pad).id, "mill_bell")
            check.equal((WorldMath.bellBefore(4, 1) :: TycoonConfig.Pad).id, "works_bell")
            -- la baraj, Era 4 e prima: n-asteapta clopotul sunat in satul vechi; ceata Erei 5 asteapta Dam Bell
            check.equal(WorldMath.bellBefore(4, 2), nil)
            check.equal((WorldMath.bellBefore(5, 2) :: TycoonConfig.Pad).id, "dam_bell")
        end)

        test.case("ce scrie o zona: panoul si gardul, inainte si dupa comutatorul l3", function()
            local function zone(id: string): TycoonConfig.Zone
                for w = 1, 2 do
                    for _, z in TycoonConfig.zonesOf(w) do
                        if z.id == id then
                            return z
                        end
                    end
                end
                error(id)
            end
            local today = function(era: number): boolean
                return era <= 3
            end
            local mill, works, dam = zone("mill"), zone("wire_works"), zone("dam")
            -- azi, in sat: exact textele de dinainte (ZoneController si Overlay le scriau pe loc)
            check.equal(
                WorldMath.zoneSign(mill, "locked", 1, today),
                Strings.zoneLocked("The Mill", "Landing Bell")
            )
            check.equal(WorldMath.zoneSign(mill, "open", 1, today), "")
            check.equal(
                WorldMath.zoneSign(works, "locked", 1, today),
                Strings.zoneLocked("The Wire Works", "Mill Bell")
            )
            check.equal(WorldMath.fenceText(works, 1, today), Strings.refuseZoneLocked("Mill Bell"))
            check.equal(WorldMath.zoneSign(dam, "locked", 1, today), dam.soon)
            check.equal(WorldMath.zoneSign(dam, "open", 1, today), dam.soon)
            check.equal(WorldMath.fenceText(dam, 1, today), dam.soon)
            -- fara lume si fara `eraIsLive`: satul si erele din joc de acum
            check.equal(
                WorldMath.zoneSign(dam, "open", nil, nil),
                if TycoonConfig.eraIsLive(4) then Strings.zoneAway("The Dam") else dam.soon
            )
            -- dupa l3, in sat: barajul nu se mai deschide cu niciun clopot si nu mai „vine”; spune unde se ridica
            for _, status in { "locked", "open" } do
                local sign = WorldMath.zoneSign(dam, status, 1, damLive)
                check.equal(sign, Strings.zoneAway("The Dam"))
                check.equal(string.find(sign, "Bell", 1, true), nil)
                check.equal(string.find(sign, "soon", 1, true), nil)
            end
            check.equal(WorldMath.fenceText(dam, 1, damLive), Strings.zoneAway("The Dam"))
            -- la baraj: Dam Town n-are panou, ceata Erei 5 „vine” cat Era 5 nu e in joc
            check.equal(WorldMath.zoneSign(zone("dam_town"), "open", 2, damLive), "")
            local fog = zone("fog5")
            check.equal(
                WorldMath.zoneSign(fog, "locked", 2, damLive),
                fog.soon or Strings.zoneSoon(fog.name)
            )
            -- cu Era 5 in joc, ceata spune clopotul ei (al barajului), nu Works Bell
            local five = function(era: number): boolean
                return era <= 5
            end
            check.equal(WorldMath.fenceText(fog, 2, five), Strings.refuseZoneLocked("Dam Bell"))
        end)

        test.case("[pasul k2] ce scrie ruina unei platforme, pe harta ta", function()
            -- la baraj, totul cumparat in afara de Dam Bell: venitul e conditia, nu Works Bell-ul satului
            local statuses: { [string]: string } = {}
            for _, p in TycoonConfig.padsOfWorld(2) do
                statuses[p.id] = if p.id == "dam_bell" then "outline" else "bought"
            end
            local bell = TycoonConfig.byId.dam_bell
            check.equal(
                WorldMath.ruinNeeds(bell, statuses, 2, nil, 3.9e12, 1),
                "Earn 4T coins a second first"
            )
            check.equal(
                WorldMath.ruinNeeds(bell, statuses, 2, nil, 5e12, 2),
                "Earn 8T coins a second first"
            )
            check.equal(WorldMath.ruinNeeds(bell, statuses, 2, nil, 8e12, 2), nil)
            -- in sat, o platforma a Morii cu Landing Bell nesunat: clopotul intai
            local mill = TycoonConfig.byId.water_wheel
            check.equal(
                WorldMath.ruinNeeds(mill, {}, 1, nil, 0, 1),
                Strings.refuseZoneLocked("Landing Bell")
            )
        end)

        test.case("acordarea barajului nu angajeaza pe nimeni", function()
            local src = fs.readFile("src/Server/Services/PadService.luau")
            local grantBody = string.match(src, "function PadService%.Grant%(.-\nend") or ""
            check.not_nil(string.find(grantBody, "grant(player, data, pad, false)", 1, true))
            local buyBody = string.match(src, "function PadService%.Buy%(.-\nend") or ""
            check.not_nil(string.find(buyBody, "grant(player, data, pad, true)", 1, true))
            local devBody = string.match(src, "function PadService%.DevGrant%(.-\nend") or ""
            check.not_nil(string.find(devBody, "grant(player, data, pad, true)", 1, true))
        end)

        test.case("era jucatorului, pe lista lumii lui", function()
            local village = TycoonConfig.padsOfWorld(1)
            check.equal(TycoonMath.era({}, village), 1)
            check.equal(TycoonMath.era(allBought(village), village), 3)
            -- statusurile satului: la fel pe lista lumii 1 ca pe toata lista (barajul adormit nu apare)
            local some = { first_net = true, first_runner = true }
            local a = TycoonMath.padStatuses(some, village)
            local b = TycoonMath.padStatuses(some)
            for id, status in b do
                check.equal(a[id], status)
            end
            for id, status in a do
                check.equal(b[id], status)
            end
        end)

        test.case("fiecare cerere a jucatorului trece prin poarta lumii, pe server", function()
            local function body(path: string, pattern: string): string
                local src = fs.readFile(path)
                local found = string.match(src, pattern)
                check.not_nil(found)
                return found or ""
            end
            local pads = "src/Server/Services/PadService.luau"
            check.is_true(
                string.find(
                    body(pads, "function PadService%.Buy%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            check.is_true(
                string.find(
                    body(pads, "function PadService%.DevGrant%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            local stations = "src/Server/Services/StationService.luau"
            check.is_true(
                string.find(
                    body(stations, "function StationService%.Upgrade%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            check.is_true(
                string.find(
                    body(stations, "function StationService%.UpgradeCrew%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            local nets = "src/Server/Services/NetService.luau"
            check.is_true(
                string.find(
                    body(nets, "function NetService%.Collect%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            check.is_true(
                string.find(
                    body(nets, "function NetService%.Snapshot%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            check.is_true(
                string.find(
                    body(nets, "local function tick%(.-\nend"),
                    "WorldMath.allowed",
                    1,
                    true
                ) ~= nil
            )
            local economy = "src/Server/Services/EconomyService.luau"
            for _, fn in { "UseStore", "UseProcessor", "Deliver", "SetPresence" } do
                check.is_true(
                    string.find(
                        body(economy, `function EconomyService%.{fn}%(.-\nend`),
                        "closedFor",
                        1,
                        true
                    ) ~= nil
                )
            end
            check.equal(Strings.upgradeRejected("closed"), Strings.CLOSED_HERE)
            check.equal(
                Strings.useResult("storage", false, "closed", 0, 0, false),
                Strings.CLOSED_HERE
            )
        end)
    end)
end
