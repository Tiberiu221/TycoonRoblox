--!strict
-- Podul de dezvoltare: serverul intreaba un server local la fiecare cateva secunde daca are ceva
-- de facut, si executa comenzile consolei de dezvoltare fara ca cineva sa apese ceva in joc.
--
-- DE CE EXISTA: nu pot juca jocul cu tastatura -- clientul Roblox ignora intrarea sintetica
-- (masura anti-macro), deci nici tastele, nici clicurile pe coordonate nu ajung in joc. Pot insa
-- sa ma uit la ecran si sa cer actiuni de-aici. Asa verific singur bucla (cumpara, strange,
-- vinde) in loc sa-i cer owner-ului sa joace de fiecare data cand schimb ceva.
--
-- SIGURANTA: porneste DOAR in Studio (aceeasi poarta ca DevService) si DOAR spre 127.0.0.1.
-- In joc publicat, `DevState.Enabled()` e fals si modulul nu face absolut nimic.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local DevState = require(script.Parent.DevState)
local DevService = require(script.Parent.DevService)

local DevBridge = {}

local POLL_SECONDS = 2
local URL = "http://127.0.0.1:8787/cmd?who=bridge" -- coada podului; editorul si sonda au cozile lor (probe_server.py)

-- Comanda vine ca text: "coins:500", "buyto:6", "fill", "sell", "collect:first_net", "state".
-- Acelasi vocabular ca in consola din joc -- nimic in plus, ca sa nu existe doua adevaruri.
local function run(player: Player, raw: string)
    local verb, arg = string.match(raw, "^(%w+):?(.*)$")
    if verb == nil then
        return
    end
    local value: any = tonumber(arg)
    if value == nil and arg ~= "" then
        value = arg
    end
    local reply = DevService.Run(player, verb, value)
    print(`[DevBridge] {raw} -> {reply}`)
end

function DevBridge.Init()
    if not DevState.Enabled() then
        return
    end
    task.spawn(function()
        while true do
            task.wait(POLL_SECONDS)
            local player = Players:GetPlayers()[1]
            if player == nil then
                continue -- nimeni in joc: n-are pe cine sa se aplice o comanda
            end
            local ok, response = pcall(function()
                return HttpService:RequestAsync({ Url = URL, Method = "GET" })
            end)
            if not ok or response == nil or not response.Success then
                continue -- serverul local nu ruleaza; nu e o eroare, doar n-avem comenzi
            end
            local body = response.Body
            if body == "" or body == "[]" then
                continue
            end
            local decoded: any
            local okDecode = pcall(function()
                decoded = HttpService:JSONDecode(body)
            end)
            if not okDecode or typeof(decoded) ~= "table" then
                continue
            end
            for _, cmd in decoded do
                if typeof(cmd) == "string" then
                    pcall(run, player, cmd)
                end
            end
        end
    end)
    print("[Driftwood] DevBridge activ (doar Studio): asculta comenzi pe 127.0.0.1:8787")
end

return DevBridge
