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
--   "pending"    [verificatorul A0/k6-k8] un drum e deja in curs (doar ca rezultat al lui Depart, nu prin OnFailed);
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
-- cine e pe drum, de cand (os.clock) si cine afla daca n-a plecat: un al doilea RowUp in timpul drumului nu mai porneste
-- nimic
local departing: { [Player]: { at: number, onFailed: (Player, string) -> () } } = {}

local function settle(player: Player, reason: string)
    local trip = departing[player]
    departing[player] = nil
    DataService.MarkTeleporting(player, false)
    if trip ~= nil and player.Parent == Players then
        trip.onFailed(player, reason)
    end
end

-- [D70, pasul k8] Un drum altul decat al barcii: aceeasi plecare (profilul nu se inchide, MarkTeleporting, aceleasi motive),
-- dar spre `destination` ("village" = acelasi place: reincarcarea in lumea 2 dupa baraj), cu datele lui de drum si cu alt
-- ascultator al esecului (ecranul barajului, nu barca). nil = barca, ca inainte.
export type Trip = {
    destination: string?,
    travel: { [string]: any }?,
    onFailed: ((Player, string) -> ())?,
}

local function reasonOf(result: Enum.TeleportResult): string
    return if result == Enum.TeleportResult.Flooded then "busy" else "failed"
end

-- Porneste drumul. Raspunsul vine ca teleport (reusit) sau ca OnFailed (motivul). [verificatorul k6-k8] Intoarce un motiv
-- doar cand nu porneste nimic si n-a raspuns nimeni: "pending" (un drum e deja in curs; al lui raspunde tot prin OnFailed;
-- nu „busy”, care e Flooded-ul Roblox, dupa care nu mai e niciun drum) sau
-- "closed" (serviciul nu e pornit). Barca il ignora; barajul il trimite ecranului, ca a doua cerere sa aiba raspunsul ei.
function FerryService.Depart(player: Player, trip: Trip?): string?
    local d = deps
    if d == nil then
        return "closed"
    end
    if departing[player] ~= nil then
        return "pending"
    end
    local destination = if trip ~= nil and trip.destination ~= nil
        then trip.destination
        else d.Destination
    local onFailed = if trip ~= nil and trip.onFailed ~= nil then trip.onFailed else d.OnFailed
    if IS_STUDIO then
        onFailed(player, "studio")
        return nil
    end
    local places = PlaceConfig.forUniverse(game.GameId)
    local target: number? = nil
    if places ~= nil then
        target = if destination == "fair" then places.fair else places.village
    end
    if target == nil then
        onFailed(player, "closed")
        return nil
    end
    local data = DataService.Get(player)
    if data == nil then
        onFailed(player, "no_profile")
        return nil
    end
    local startedAt = os.clock()
    departing[player] = { at = startedAt, onFailed = onFailed }
    local onDepart = d.OnDepart
    if onDepart ~= nil then
        onDepart(player)
    end
    DataService.MarkTeleporting(player, true)
    if destination == "fair" and not data.Firsts.FirstRide then
        data.Firsts.FirstRide = true
        Analytics.FairStep(player, "FirstRide")
    end
    local options = Instance.new("TeleportOptions")
    local travel = d.TravelData
    if trip ~= nil and trip.travel ~= nil then
        options:SetTeleportData(trip.travel)
    elseif travel ~= nil then
        options:SetTeleportData(travel(player))
    end
    local placeId = target :: number
    local ok, err = pcall(function()
        TeleportService:TeleportAsync(placeId, { player }, options)
    end)
    if not ok then
        warn(`[Ferry] {player.Name} n-a plecat spre {destination}: {err}`)
        settle(player, "failed")
        return nil
    end
    task.delay(FerryService.TIMEOUT, function()
        local now = departing[player]
        if now ~= nil and now.at == startedAt then
            warn(`[Ferry] {player.Name}: teleportul n-a pornit in {FerryService.TIMEOUT} s`)
            settle(player, "timeout")
        end
    end)
    return nil
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
