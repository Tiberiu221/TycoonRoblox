-- [D70, pasul j6] Lumile: satul de pe rau (1) si barajul (2). Lumea vine din era; orice valoare stricata inseamna satul.
local frktest = require("@frktest/frktest")
local test = frktest.test
local check = frktest.assert.check

local fs = require("@lune/fs")

local WorldConfig = require("../src/Shared/Config/WorldConfig")
local TycoonConfig = require("../src/Shared/Config/TycoonConfig")

-- toate fisierele .luau de sub un director
local function luauFiles(dir: string, out: { string }): { string }
    for _, name in fs.readDir(dir) do
        local path = dir .. "/" .. name
        if fs.isDir(path) then
            luauFiles(path, out)
        elseif string.sub(name, -5) == ".luau" then
            table.insert(out, path)
        end
    end
    return out
end

return function()
    test.suite("WorldConfig [D70]", function()
        test.case("lumea unei ere", function()
            for era = 1, 3 do
                check.equal(WorldConfig.worldOfEra(era), 1)
            end
            for era = 4, 7 do
                check.equal(WorldConfig.worldOfEra(era), 2)
            end
        end)

        test.case("o lume stricata e satul", function()
            check.equal(WorldConfig.sanitize(1), 1)
            check.equal(WorldConfig.sanitize(2), 2)
            for _, bad in { nil, 0, 3, -1, 1.5, 0 / 0, math.huge, "2", true, {} } :: { any } do
                check.equal(WorldConfig.sanitize(bad), 1)
            end
        end)

        test.case("lumea 2: platformele si locurile barajului", function()
            local pads = TycoonConfig.padsOfWorld(2)
            check.equal(#pads, 23)
            for _, p in pads do
                check.equal(p.era, 4)
            end
            check.equal(#TycoonConfig.padsOfWorld(1) + #pads, #TycoonConfig.PADS)
            -- o lume care nu exista e satul (sanitize), nu o lista goala
            check.is_true(TycoonConfig.padsOfWorld(9) == TycoonConfig.padsOfWorld(1))
            -- [j7] locurile liniilor, unirii si vanzatorului barajului sunt toate ale lumii 2
            local lines = TycoonConfig.linePlacesOf(2)
            for _, line in { "barrels", "cable", "crystal" } do
                check.is_true(lines[line] == TycoonConfig.LINE_PLACES[line])
            end
            check.is_true(TycoonConfig.joinPlacesOf(2).grid == TycoonConfig.JOIN_PLACES.grid)
            check.is_true(TycoonConfig.sellerPlacesOf(2).town == TycoonConfig.SELLER_PLACES.town)
            check.equal(TycoonConfig.linePlacesOf(2).wood, nil)
            check.equal(TycoonConfig.sellerPlacesOf(2).dock, nil)
        end)

        test.case(
            "fiecare loc e al unei linii sau al unui vanzator stiut; fiecare are loc in lumea lui",
            function()
                local StationConfig = require("../src/Shared/Config/StationConfig")
                for line in TycoonConfig.LINE_PLACES do
                    check.not_nil(table.find(StationConfig.LINE_ORDER_ALL, line))
                end
                for line in TycoonConfig.JOIN_PLACES do
                    check.not_nil(table.find(StationConfig.LINE_ORDER_ALL, line))
                    check.not_nil(StationConfig.LINES[line].inputs)
                end
                for seller in TycoonConfig.SELLER_PLACES do
                    check.not_nil(table.find(StationConfig.SELLER_ORDER_ALL, seller))
                end
                -- fiecare linie a erelor scrise are locul ei, in lumea erei ei
                for era, lines in StationConfig.ERA_LINES_ALL do
                    local w = WorldConfig.worldOfEra(era)
                    for _, line in lines do
                        local isJoin = StationConfig.LINES[line].inputs ~= nil
                        local places = if isJoin
                            then TycoonConfig.joinPlacesOf(w)
                            else TycoonConfig.linePlacesOf(w)
                        check.not_nil(places[line])
                    end
                end
                for _, seller in StationConfig.SELLER_ORDER_ALL do
                    local found = 0
                    for w = 1, WorldConfig.COUNT do
                        if TycoonConfig.sellerPlacesOf(w)[seller] ~= nil then
                            found += 1
                        end
                    end
                    check.equal(found, 1)
                end
            end
        )

        test.case("raul lumii 1 e raul de azi, cheie cu cheie", function()
            local RiverConfig = require("../src/Shared/Config/RiverConfig")
            local one = RiverConfig.WORLDS[1] :: any
            for key, value in RiverConfig :: any do
                if key ~= "WORLDS" then
                    check.is_true(one[key] == value)
                end
            end
            for key in one do
                check.not_nil((RiverConfig :: any)[key])
            end
        end)

        test.case(
            "comutatorul local al Erei 4 nu e niciodata comis (scripts/era4_flip.py)",
            function()
                for _, path in luauFiles("src", {}) do
                    local src = fs.readFile(path)
                    if string.find(src, "-- era4_flip", 1, true) ~= nil then
                        print(
                            `[WorldConfig] {path}: comutatorul era4_flip e pornit; opreste-l inainte de commit`
                        )
                    end
                    check.equal(string.find(src, "-- era4_flip", 1, true), nil)
                end
            end
        )

        test.case("niciun modul nu citeste lumea jucatorului la incarcare", function()
            -- Atributul World il pune serverul inainte de SaveLoaded; un `require` care l-ar citi in corpul modulului ar
            -- prinde lumea de dinainte de profil (sau nimic). Se citeste doar din functii (randuri indentate).
            local files = luauFiles("src", {})
            check.is_true(#files > 100)
            for _, path in files do
                -- scriptul de pornire al clientului citeste lumea o data, dupa SaveLoaded, si o da controllerelor (k1)
                if string.find(path, "Bootstrap.client.luau", 1, true) ~= nil then
                    continue
                end
                local src = fs.readFile(path)
                for line in string.gmatch(src, "[^\n]+") do
                    if string.find(line, 'GetAttribute("World")', 1, true) ~= nil then
                        if string.sub(line, 1, 1) ~= " " then
                            print(`[WorldConfig] {path}: lumea citita la incarcare: {line}`)
                        end
                        check.equal(string.sub(line, 1, 1), " ")
                    end
                end
            end
        end)
    end)
end
