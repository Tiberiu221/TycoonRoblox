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
local FairNetServer = require(NetFolder:WaitForChild("FairNetServer"))

VillageService.Init({ PushState = FairNetServer.PushState })
WheelService.Init({ PushState = FairNetServer.PushState })
-- FishService: doar momeala de la roata (AddBait); undita e in sat. Init leaga doar curatenia de la plecare.
FishService.Init({ PushState = FairNetServer.PushState })
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
})
DataService.Init({ Place = "fair" })

print(
    `[Fair] balciul e deschis: {#FairLayout.SPOTS} obiecte, cel mult {FairLayout.MAX_PLAYERS} de oameni`
)
