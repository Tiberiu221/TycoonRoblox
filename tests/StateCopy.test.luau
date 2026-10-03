--!strict
-- [D70, pasul k3, verificatorul j13a/j13b] Copia starii pe linii (StateCopy), pe ordinea FULL (cu barajul): fiecare camp
-- al instantaneelor serverului (EconomyService.ProcessorSnapshot, piesele din traista, StationService.LineView) ajunge
-- dincoace, iar liniile Erelor 1-3 ies cu aceleasi chei ca inainte de k3 [CLAUDE.md capcana 3].
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check
local fs = require("@lune/fs")

local FlowConfig = require("../src/Shared/Config/FlowConfig")
local StateCopy = require("../src/Shared/Modules/StateCopy")

-- Numele campurilor unui `export type Nume = { ... }` dintr-un fisier (doar primul nivel).
local function typeFields(path: string, name: string): { string }
    local src = fs.readFile(path)
    local body = string.match(src, "export type " .. name .. " = (%b{})")
    assert(body ~= nil, path .. ": lipseste tipul " .. name)
    local inner = string.sub(body, 2, -2)
    -- intai comentariile, apoi tabelele imbricate ({ [string]: number }): n-au campuri de primul nivel
    inner = string.gsub(inner, "%-%-[^\n]*", "")
    inner = string.gsub(inner, "%b{}", "")
    local out: { string } = {}
    for field in string.gmatch(inner, "([%a_][%w_]*)%s*:") do
        table.insert(out, field)
    end
    return out
end

local FULL = FlowConfig.FULL
local PARTS = StateCopy.partsOf(FULL.lines)

return function()
    test.suite("StateCopy - copia starii pe linii [D70, pasul k3]", function()
        test.case(
            "fiecare camp al atelierului trimis de server ajunge copiat, pe ordinea FULL",
            function()
                local fields =
                    typeFields("src/Server/Services/EconomyService.luau", "ProcessorSnapshot")
                check.is_true(#fields >= 9) -- count, contents, out, outContents, rate, present, staffed, inputs, waiting
                check.is_true(
                    table.find(fields, "inputs") ~= nil and table.find(fields, "waiting") ~= nil
                )
                local unions = 0
                for _, line in FULL.lineOrder do
                    local parts = PARTS[line]
                    local inputs: { [string]: number } = {}
                    for i, part in parts or {} do
                        inputs[part] = 10 + i
                    end
                    local raw = {
                        store = { count = 5, contents = { charge = 5 } },
                        processor = {
                            count = 7,
                            contents = { barrel = 4, cable = 3 },
                            out = 3,
                            outContents = { grid = 3 },
                            rate = 1.5,
                            present = true,
                            staffed = true,
                            inputs = inputs,
                            waiting = if parts ~= nil then parts[#parts] else nil,
                        },
                    }
                    local copy = StateCopy.flowLine(raw, parts)
                    local pr: any = copy.processor
                    for _, field in fields do
                        local isJoinField = field == "inputs" or field == "waiting"
                        if parts ~= nil or not isJoinField then
                            check.is_true(pr[field] ~= nil)
                        else
                            -- o linie simpla iese cu cheile de dinainte de k3
                            check.equal(pr[field], nil)
                        end
                    end
                    if parts ~= nil then
                        unions += 1
                        for i, part in parts do
                            check.equal(pr.inputs[part], 10 + i)
                        end
                        check.equal(pr.waiting, parts[#parts])
                    end
                    check.equal(copy.store.count, 5)
                    check.equal(pr.count, 7)
                    check.equal(pr.rate, 1.5)
                    -- copiile sunt tabele noi: clientul nu tine referinte in starea primita
                    check.is_true(pr.contents ~= raw.processor.contents)
                end
                check.is_true(unions >= 1) -- Relay-ul barajului e in FULL
            end
        )

        test.case(
            "fiecare camp al vederii pe linie (StationService.LineView) ajunge copiat",
            function()
                local fields = typeFields("src/Server/Services/StationService.luau", "LineView")
                check.is_true(#fields >= 8)
                local raw = {
                    catch = 4,
                    delivered = 3,
                    bottleneck = "relay",
                    playerShare = 0.25,
                    supply = 6,
                    heldBy = "cable",
                    isOpen = false,
                    waiting = "cable",
                }
                local copy: any = StateCopy.lineView(raw, "grid")
                for _, field in fields do
                    check.equal(copy[field], (raw :: any)[field])
                end
            end
        )

        test.case("valorile implicite ale vederii sunt cele cinstite", function()
            local copy = StateCopy.lineView({ catch = 2 }, "barrels")
            check.equal(copy.supply, 2) -- ce prind plasele ei
            check.equal(copy.heldBy, "barrels") -- linia insasi
            check.is_true(copy.isOpen)
            check.equal(copy.waiting, nil)
            check.equal(copy.bottleneck, "")
        end)

        test.case(
            "traista: marfa bruta pe fiecare linie, vanzatorii si piesele pe fiecare unire",
            function()
                local unions: { [string]: boolean } = {}
                for line in PARTS do
                    unions[line] = true
                end
                local rawBy: { [string]: number } = {}
                local partBy: { [string]: number } = {}
                for i, line in FULL.lineOrder do
                    rawBy[line] = i
                    if unions[line] then
                        partBy[line] = 20 + i
                    end
                end
                local sellBy: { [string]: any } = {}
                for i, seller in FULL.sellerOrder do
                    sellBy[seller] = { count = i, value = 100 * i }
                end
                local copy = StateCopy.sackBy(
                    { rawBy = rawBy, sellBy = sellBy, partBy = partBy },
                    FULL.lineOrder,
                    FULL.sellerOrder,
                    unions
                )
                for i, line in FULL.lineOrder do
                    check.equal(copy.rawBy[line], i)
                    check.equal(copy.partBy[line], if unions[line] then 20 + i else nil)
                end
                for i, seller in FULL.sellerOrder do
                    check.equal(copy.sellBy[seller].count, i)
                    check.equal(copy.sellBy[seller].value, 100 * i)
                end
                -- fara nimic de la server: zero peste tot, nu nil
                local empty = StateCopy.sackBy({}, FULL.lineOrder, FULL.sellerOrder, unions)
                for line in unions do
                    check.equal(empty.partBy[line], 0)
                end
                check.equal(empty.rawBy[FULL.lineOrder[1]], 0)
            end
        )

        -- [verificatorul k3] o singura regula pentru „cate uniri se pot face” (inelul Relay-ului si ghidajul) si ce piesa duci
        test.case(
            "joinable: linia simpla, unirea cu toate piesele, unirea care asteapta",
            function()
                check.equal(StateCopy.joinable({ count = 7 }), 7)
                check.equal(
                    StateCopy.joinable({ count = 9, inputs = { barrels = 5, cable = 4 } }),
                    4
                )
                check.equal(
                    StateCopy.joinable({
                        count = 5,
                        inputs = { barrels = 5, cable = 0 },
                        waiting = "cable",
                    }),
                    0
                )
                check.equal(StateCopy.joinable({ count = 0, inputs = {} }), 0)
                local joins =
                    { { line = "barrels", good = "barrel" }, { line = "cable", good = "cable" } }
                local only = StateCopy.partsCarried({ cable = 3, driftwood = 2 }, joins)
                check.equal(only.cable, 3)
                check.equal(only.barrels, nil)
                local both = StateCopy.partsCarried({ cable = 1, barrel = 2 }, joins)
                check.equal(both.barrels, 2)
                check.equal(both.cable, 1)
                -- LineController si Overlay o folosesc pe aceasta, nu o copie a lor
                check.not_nil(
                    string.find(
                        fs.readFile("src/Client/Controllers/LineController.luau"),
                        "StateCopy.joinable(state)",
                        1,
                        true
                    )
                )
                check.not_nil(
                    string.find(
                        fs.readFile("src/Client/Controllers/Overlay.luau"),
                        "StateCopy.joinable(processor)",
                        1,
                        true
                    )
                )
            end
        )

        test.case(
            "serverul trimite piesele din traista, iar clientul le copiaza prin StateCopy",
            function()
                local economy = fs.readFile("src/Server/Services/EconomyService.luau")
                local sackType = string.match(
                    economy,
                    "function EconomyService%.SackSnapshot%(player: Player%): (%b{})"
                )
                check.is_true(
                    sackType ~= nil and string.find(sackType :: string, "partBy", 1, true) ~= nil
                )
                local boot = fs.readFile("src/Client/Bootstrap.client.luau")
                for _, needle in
                    {
                        "StateCopy.sackBy(",
                        "partBy = sackBy.partBy",
                        "StateCopy.flowLine(entry, PARTS_OF[line])",
                        "StateCopy.flowSeller(entry)",
                        "StateCopy.lineView(entry, line)",
                        "netsLine = if typeof(rawStations.netsLine)",
                        "partBy = sackState.partBy",
                    }
                do
                    check.is_true(string.find(boot, needle, 1, true) ~= nil)
                end
            end
        )
    end)
end
