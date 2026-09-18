--!strict
-- COMPILEAZA fiecare fisier Luau din src/. stylua si selene parseaza sintaxa, dar nu prind limitele compilatorului (de
-- ex. peste 200 de variabile locale intr-o functie, peste 255 de registre): un asemenea fisier trece toata poarta si
-- crapa abia in Roblox, unde scriptul pur si simplu nu porneste -- iar un Bootstrap care nu porneste inseamna ecran gol.
--
-- Rulare: lune run scripts/check_compile
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local failed = 0
local count = 0

local function walk(dir: string)
    for _, name in fs.readDir(dir) do
        local path = `{dir}/{name}`
        if fs.isDir(path) then
            walk(path)
        elseif string.sub(name, -5) == ".luau" or string.sub(name, -4) == ".lua" then
            count += 1
            local ok, err =
                pcall(luau.compile, fs.readFile(path), { optimizationLevel = 1, debugLevel = 1 })
            if not ok then
                failed += 1
                print(`EROARE DE COMPILARE  {path}\n    {tostring(err)}`)
            end
        end
    end
end

walk("src")
print(`fisiere compilate: {count}   ·   cu erori: {failed}`)
if failed > 0 then
    process.exit(1)
end
