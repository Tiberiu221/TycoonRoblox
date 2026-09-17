--!strict
-- [D60] Serverul BALCIULUI DE SEARA (place-ul al doilea). Refoloseste, montate fisier cu fisier din sat (fair.project.json),
-- serviciile care tin de profil si de aspect: DataService (acelasi profil), EconomyService (doar perlele: fara Init, deci
-- fara bucla lantului -- satul nu se simuleaza aici, il plateste la intoarcere, ca offline), VillageService (decorul,
-- tinutele), WheelService (roata, mutata aici) cu FishService si TreasureService (premiile ei: momeala, ce vine la
-- ponton). TreasureService NU porneste nici el: raul tau aduce mai departe pe ceasul lui, iar ce a venit cat ai lipsit se
-- numara la intoarcere, pe ecranul de bun venit din sat.
--
-- Ordinea Init-urilor: serviciile, apoi FairNetServer (asculta ProfileLoaded), apoi DataService (el il declanseaza).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Services = script.Parent:WaitForChild("Services")
local NetFolder = script.Parent:WaitForChild("Net")

local Net = require(ReplicatedStorage.Net.Net)
local FairLayout = require(ReplicatedStorage.Shared.Modules.FairLayout)
local DataService = require(Services:WaitForChild("DataService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local VillageService = require(Services:WaitForChild("VillageService"))
local WheelService = require(Services:WaitForChild("WheelService"))
local FishService = require(Services:WaitForChild("FishService"))
local FerryService = require(Services:WaitForChild("FerryService"))
local TitleService = require(Services:WaitForChild("TitleService"))
local PresenceService = require(Services:WaitForChild("PresenceService"))
local PlayerCardService = require(Services:WaitForChild("PlayerCardService"))
local BoardService = require(Services:WaitForChild("BoardService"))
local MarketService = require(Services:WaitForChild("MarketService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local PondService = require(Services:WaitForChild("PondService"))
local BoothService = require(Services:WaitForChild("BoothService"))
local FairNetServer = require(NetFolder:WaitForChild("FairNetServer"))

VillageService.Init({ PushState = FairNetServer.PushState })
WheelService.Init({ PushState = FairNetServer.PushState })
-- [D61] FishService: momeala de la roata si undita de la iaz. Ceasul e al serverului, ca in sat (RiverService.Now):
-- clientul asteapta muscatura pe GetServerTimeNow. Un peste scos intra pe tabla saptamanii (ca in sat) si in concurs.
LeaderboardService.Init({ Income = nil })
FishService.Init({
    PushState = FairNetServer.PushState,
    Now = function(): number
        return Workspace:GetServerTimeNow()
    end,
    OnLanded = function(player: Player, speciesId: string, cm: number)
        LeaderboardService.FishLanded(player, speciesId, cm)
        PondService.Landed(player, speciesId, cm)
    end,
})
FerryService.Init({
    Destination = "village",
    OnFailed = function(player: Player, reason: string)
        Net.Get("FerryFailed"):FireClient(player, reason)
    end,
    TravelData = function(player: Player)
        return { from = "fair", outfit = VillageService.Snapshot(player).outfit }
    end,
})

-- tabela de pe scena: citita din minut in minut si trimisa tuturor; campionul saptamanii trecute are titlul lui
BoardService.Init({
    Push = function(state)
        Net.Get("BoardState"):FireAllClients(state)
    end,
    OnChampion = function()
        for _, player in Players:GetPlayers() do
            FairNetServer.PushState(player)
        end
    end,
})
TitleService.Init({ PushState = FairNetServer.PushState, Champion = BoardService.IsChampion })
-- oamenii din balci: pozitiile (nesigur, de zece ori pe secunda) si cine e fiecare (tinuta si titlul, din profil)
PresenceService.Init({
    Where = Net.GetUnreliable("Where"),
    Crowd = Net.GetUnreliable("Crowd"),
    People = Net.Get("People"),
    Describe = function(player: Player): (string, string)
        local _, title = TitleService.Worn(player)
        return VillageService.Snapshot(player).outfit, title
    end,
})

-- [D61] concursul de la iaz: runda dupa ceas, tabla la toti, rezultatul fiecaruia
PondService.Init({
    Push = function(player: Player?, state: { [string]: any })
        if player ~= nil then
            Net.Get("PondState"):FireClient(player, state)
        else
            Net.Get("PondState"):FireAllClients(state)
        end
    end,
    Result = function(player: Player, result: { [string]: any })
        Net.Get("PondResult"):FireClient(player, result)
    end,
    PushState = FairNetServer.PushState,
    PositionOf = PresenceService.PositionOf,
})

-- [D61] gheretele de joc
BoothService.Init({ PushState = FairNetServer.PushState, PositionOf = PresenceService.PositionOf })

FairNetServer.Init({
    Data = DataService,
    Economy = EconomyService,
    Village = VillageService,
    Wheel = WheelService,
    Ferry = FerryService,
    Titles = TitleService,
    Presence = PresenceService,
    Cards = PlayerCardService,
    Board = BoardService,
    Market = MarketService,
    Fish = FishService,
    Pond = PondService,
    Booth = BoothService,
})
DataService.Init({ Place = "fair" })

print(
    `[Fair] balciul e deschis: {#FairLayout.SPOTS} obiecte, cel mult {FairLayout.MAX_PLAYERS} de oameni`
)
