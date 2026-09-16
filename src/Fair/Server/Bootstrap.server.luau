--!strict
-- [D60] Serverul balciului de seara (place-ul al doilea). Deocamdata SCHELETUL: te primeste si te trimite inapoi in sat
-- cand ceri. Profilul, prezenta, titlurile, clasamentele si roata vin in pasii urmatori ai planului D60.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Net.Net)
local PlaceConfig = require(ReplicatedStorage.Shared.Config.PlaceConfig)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)

local ASK_EVERY = 5 -- secunde intre doua cereri: un teleport in curs nu se mai porneste o data
local lastAsk: { [Player]: number } = {}

Net.Get("RowHome").OnServerEvent:Connect(function(player: Player)
    local now = os.clock()
    if now - (lastAsk[player] or -math.huge) < ASK_EVERY then
        return
    end
    lastAsk[player] = now
    local places = PlaceConfig.forUniverse(game.GameId)
    if places == nil then
        warn("[Fair] universul acesta nu are un sat cunoscut; drumul inapoi nu pleaca")
        return
    end
    -- In Studio teleportul nu merge deloc; greseala se scrie in Output, nu opreste serverul
    local ok, err = pcall(function()
        TeleportService:TeleportAsync(places.village, { player })
    end)
    if not ok then
        warn(`[Fair] drumul inapoi n-a plecat: {err}`)
    end
end)

Players.PlayerRemoving:Connect(function(player: Player)
    lastAsk[player] = nil
end)

print(
    `[Fair] balciul e deschis: {#FairLayout.SPOTS} obiecte, cel mult {FairLayout.MAX_PLAYERS} de oameni`
)
