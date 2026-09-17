--!strict
-- [D60] BARCA dintre sat si balci, pe server. Acelasi modul in ambele place-uri: din sat te duce in balci, din balci te
-- aduce acasa (`Destination`).
--
-- Sesiunea profilului NU se inchide inainte de plecare: daca teleportul pica, ramai unde erai, cu profilul in mana, si
-- jocul merge mai departe. Sesiunea o ia place-ul in care ajungi, iar DataService.MarkTeleporting impiedica un Kick
-- cand se intampla asta. Orice drum care nu pleaca se spune (OnFailed -> FerryFailed), cu motivul [D43]:
--   "studio"     TeleportService nu merge in Studio (drumul pictat s-a vazut oricum);
--   "closed"     universul asta n-are inca celalalt place (PlaceConfig);
--   "no_profile" profilul inca se incarca;
--   "busy"       prea multe cereri deodata (limita, sau Roblox a raspuns Flooded);
--   "failed"     TeleportAsync a crapat sau Roblox a refuzat teleportul;
--   "timeout"    n-a plecat nici dupa TIMEOUT secunde.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local PlaceConfig = require(ReplicatedStorage.Shared.Config.PlaceConfig)

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)

local FerryService = {}

export type Deps = {
    Destination: string, -- "fair" | "village"
    OnFailed: (Player, string) -> (),
    -- ce duce barca pentru desenul din timpul incarcarii (tinuta, titlul); sursa de adevar ramane profilul
    TravelData: ((Player) -> { [string]: any })?,
    -- chemat chiar inainte de plecare, cat profilul e inca aici (satul noteaza venitul de acum)
    OnDepart: ((Player) -> ())?,
}
local deps: Deps? = nil

FerryService.TIMEOUT = 20
local IS_STUDIO = RunService:IsStudio()
-- cine e pe drum si de cand (os.clock): un al doilea RowUp in timpul drumului nu mai porneste nimic
local departing: { [Player]: number } = {}

local function settle(player: Player, reason: string)
    departing[player] = nil
    DataService.MarkTeleporting(player, false)
    local d = deps
    if d ~= nil and player.Parent == Players then
        d.OnFailed(player, reason)
    end
end

local function reasonOf(result: Enum.TeleportResult): string
    return if result == Enum.TeleportResult.Flooded then "busy" else "failed"
end

-- Porneste drumul. Raspunsul vine ca teleport (reusit) sau ca OnFailed (motivul).
function FerryService.Depart(player: Player)
    local d = deps
    if d == nil or departing[player] ~= nil then
        return
    end
    if IS_STUDIO then
        d.OnFailed(player, "studio")
        return
    end
    local places = PlaceConfig.forUniverse(game.GameId)
    local target: number? = nil
    if places ~= nil then
        target = if d.Destination == "fair" then places.fair else places.village
    end
    if target == nil then
        d.OnFailed(player, "closed")
        return
    end
    local data = DataService.Get(player)
    if data == nil then
        d.OnFailed(player, "no_profile")
        return
    end
    local startedAt = os.clock()
    departing[player] = startedAt
    local onDepart = d.OnDepart
    if onDepart ~= nil then
        onDepart(player)
    end
    DataService.MarkTeleporting(player, true)
    if d.Destination == "fair" and not data.Firsts.FirstRide then
        data.Firsts.FirstRide = true
        Analytics.FairStep(player, "FirstRide")
    end
    local options = Instance.new("TeleportOptions")
    local travel = d.TravelData
    if travel ~= nil then
        options:SetTeleportData(travel(player))
    end
    local placeId = target :: number
    local ok, err = pcall(function()
        TeleportService:TeleportAsync(placeId, { player }, options)
    end)
    if not ok then
        warn(`[Ferry] {player.Name} n-a plecat spre {d.Destination}: {err}`)
        settle(player, "failed")
        return
    end
    task.delay(FerryService.TIMEOUT, function()
        if departing[player] == startedAt then
            warn(`[Ferry] {player.Name}: teleportul n-a pornit in {FerryService.TIMEOUT} s`)
            settle(player, "timeout")
        end
    end)
end

function FerryService.Init(d: Deps)
    deps = d
    -- teleportul poate pica si dupa ce TeleportAsync s-a intors: atunci vine aici
    TeleportService.TeleportInitFailed:Connect(
        function(player: Player, result: Enum.TeleportResult, message: string)
            if departing[player] ~= nil then
                warn(`[Ferry] {player.Name}: {result.Name} {message}`)
                settle(player, reasonOf(result))
            end
        end
    )
    Players.PlayerRemoving:Connect(function(player: Player)
        departing[player] = nil
    end)
end

return FerryService
