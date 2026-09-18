--!strict
-- BALCIUL CA FISIER LOCAL, gata de incercat in Studio: construieste `Balci.rbxl` din fair.project.json si pune pe
-- Workspace atributele de proba pe care serverul le citeste DOAR in Studio:
--   DevPearls (numar)  -- perle la pornire; fisierul local incepe mereu cu profil proaspat, deci cu 0
--   DevPasses (text)   -- pass-uri de proba, de ex. "swift,supporter" (PassService)
-- Atributele stau doar in fisierul local: place-ul publicat se construieste direct din proiect, fara ele.
--
-- Rulare: lune run scripts/build_balci [perle] [pass-uri]
--   lune run scripts/build_balci                       -> 1000 de perle, fara pass-uri
--   lune run scripts/build_balci 1000 swift,supporter  -> si cu Swift Boots si Supporter
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local OUT = "Balci.rbxl"
local pearls = tonumber(process.args[1]) or 1000
local passes = process.args[2] or ""

local built = process.exec("rojo", { "build", "fair.project.json", "-o", OUT })
if not built.ok then
    error("rojo build a picat:\n" .. built.stderr)
end

local game = roblox.deserializePlace(fs.readFile(OUT))
local workspace = game:GetService("Workspace")
workspace:SetAttribute("DevPearls", pearls)
if passes ~= "" then
    workspace:SetAttribute("DevPasses", passes)
end
fs.writeFile(OUT, roblox.serializePlace(game))
print(`{OUT}: DevPearls = {pearls}` .. (if passes ~= "" then `, DevPasses = "{passes}"` else ""))
