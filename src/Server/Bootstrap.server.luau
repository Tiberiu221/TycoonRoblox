--!strict
-- Ordinea explicita de Init(deps): fara require incrucisat intre servicii [MASTERPLAN 3.5]
-- Ordine F1: River -> Economy -> Pads -> Nets -> Workshop -> Hands -> Dev -> NetServer (asculta
-- ProfileLoaded, deci se conecteaza inainte) -> DataService (ultimul, el declanseaza ProfileLoaded).
-- Hands (HandService) trebuie si el inainte de DataService, din acelasi motiv ca NetServer -- isi
-- reporneste alergatorul la ProfileLoaded.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")
local NetFolder = script.Parent:WaitForChild("Net")

local Net = require(ReplicatedStorage.Net.Net)
local RiverService = require(Services:WaitForChild("RiverService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PadService = require(Services:WaitForChild("PadService"))
local NetService = require(Services:WaitForChild("NetService"))
local WorkshopService = require(Services:WaitForChild("WorkshopService"))
local HandService = require(Services:WaitForChild("HandService"))
local DevService = require(Services:WaitForChild("DevService"))
local DevBridge = require(Services:WaitForChild("DevBridge"))
local DataService = require(Services:WaitForChild("DataService"))
local StationService = require(Services:WaitForChild("StationService"))
local QuestService = require(Services:WaitForChild("QuestService"))
local WheelService = require(Services:WaitForChild("WheelService"))
local FishService = require(Services:WaitForChild("FishService"))
local TreasureService = require(Services:WaitForChild("TreasureService"))
local VillageService = require(Services:WaitForChild("VillageService"))
local FerryService = require(Services:WaitForChild("FerryService"))
local LeaderboardService = require(Services:WaitForChild("LeaderboardService"))
local NetServer = require(NetFolder:WaitForChild("NetServer"))

RiverService.Init({
    OnConfigChanged = function()
        for _, player in game:GetService("Players"):GetPlayers() do
            Net.Get("RiverConfig"):FireClient(player, RiverService.GetConfigFor(player))
        end
    end,
})
-- NetServer.PushState exista deja acum (functie definita la incarcarea modulului), desi
-- NetServer.Init ruleaza ultimul -- deps-urile de mai jos doar retin o referinta la functie,
-- nu o apeleaza inainte de vreme [F0 spec 3.5: "services receive it as a dep"].
EconomyService.Init({
    Pads = PadService,
    PushState = NetServer.PushState,
    Now = RiverService.Now,
    Stations = StationService,
    -- casa de marcat suna cand se scurge un lot din gramada, nu cand apesi Sell
    OnSold = function(player: Player, total: number, itemCount: number)
        Net.Get("Sold"):FireClient(player, total, itemCount)
    end,
})
StationService.Init({
    PushState = NetServer.PushState,
    Hands = HandService, -- al doilea om al unei meserii se angajeaza prin HandService [D49]
    -- "Raul tau a castigat N cat ai lipsit": banii sunt deja dati, asta e doar vestea. [D59] Si cate lucruri au venit pe rau.
    OnWelcome = function(
        player: Player,
        coins: number,
        seconds: number,
        capped: boolean,
        arrived: number
    )
        Net.Get("WelcomeBack"):FireClient(player, coins, seconds, capped, arrived)
    end,
    Treasures = TreasureService,
})
QuestService.Init({ PushState = NetServer.PushState, Stations = StationService })
-- [D60] roata se invarte in balci: aici WheelService da doar ceasul ei (Snapshot), fara Init
-- [D59] pontonul: ce aduce raul (vestea ca ceva a venit, cat esti in joc), undita (pe ora serverului), satul.
-- ORDINEA CONTEAZA: StationService.Init (mai sus) se leaga primul la ProfileLoaded, iar handler-ul lui cere
-- TreasureService.SettleOffline si pune numarul pe ecranul de bun venit; handler-ul lui TreasureService, legat aici, vine
-- dupa si primeste 0 (socoteala se face o singura data pe sesiune).
TreasureService.Init({
    PushState = NetServer.PushState,
    OnArrived = function(player: Player, kind: string, slot: number)
        Net.Get("TreasureArrived"):FireClient(player, kind, slot)
    end,
})
-- [D60] clasamentele balciului se scriu de aici: pestele scos, clopotul Erei 1, venitul din minut in minut
LeaderboardService.Init({ Income = EconomyService.IncomePerSec })
FishService.Init({
    PushState = NetServer.PushState,
    Now = RiverService.Now,
    OnLanded = LeaderboardService.FishLanded,
})
VillageService.Init({ PushState = NetServer.PushState })
-- [D60] barca spre balci: tinuta ta pleaca cu ea, doar pentru desenul din timpul incarcarii
FerryService.Init({
    Destination = "fair",
    OnFailed = function(player: Player, reason: string)
        Net.Get("FerryFailed"):FireClient(player, reason)
    end,
    TravelData = function(player: Player)
        return { from = "village", outfit = VillageService.Snapshot(player).outfit }
    end,
    OnDepart = LeaderboardService.SampleIncome,
})
PadService.Init({
    PushState = NetServer.PushState,
    Hands = HandService,
    Stations = StationService,
    OnBought = LeaderboardService.EraBell,
})
NetService.Init({
    Remotes = { NetCaught = Net.Get("NetCaught") },
    PushState = NetServer.PushState,
})
WorkshopService.Init({
    Remotes = { WorkshopState = Net.Get("WorkshopState") },
    PushState = NetServer.PushState,
    Stations = StationService,
})
HandService.Init({
    Remotes = { HandDelivered = Net.Get("HandDelivered") },
    PushState = NetServer.PushState,
})
-- Consola de dezvoltare se conecteaza doar in Studio; verificarea e in DevService
DevService.Init({
    Remotes = { DevCommand = Net.Get("DevCommand") },
    PushState = NetServer.PushState,
})
-- Podul: aceleasi comenzi, cerute din afara Studio-ului. Tot doar in Studio (vezi DevBridge).
DevBridge.Init()

-- NetServer se conecteaza la `ProfileLoaded` INAINTE ca DataService sa porneasca: DataService e cel
-- care il declanseaza, iar un jucator aflat deja in server la pornire si-ar incarca profilul fara
-- ca cineva sa asculte -- n-ar primi nici raul, nici instantaneul initial.
NetServer.Init({
    River = RiverService,
    Data = DataService,
    Pads = PadService,
    Stations = StationService,
    Quests = QuestService,
    Wheel = WheelService,
    Fish = FishService,
    Treasures = TreasureService,
    Village = VillageService,
    Nets = NetService,
    Economy = EconomyService,
    Workshop = WorkshopService,
    Hands = HandService,
    Ferry = FerryService,
})
DataService.Init({ Place = "village" })

print("[Driftwood] server bootstrap complet")
