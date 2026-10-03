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
                check.equal(WorldMath.zoneStatuses(1, works).dam, "open")
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
                check.equal(TycoonMath.padStatuses(bought, pads, nil, 5e12, 1).dam_bell, nil)
                -- conditia insasi (padBlocker o citeste la fel ca meetsNeeds)
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
