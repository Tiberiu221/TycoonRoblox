--!strict
-- Ordinea explicita de Init(deps): fara require incrucisat intre servicii [MASTERPLAN 3.5]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")
local NetFolder = script.Parent:WaitForChild("Net")

local Net = require(ReplicatedStorage.Net.Net)
local RiverService = require(Services:WaitForChild("RiverService"))
local DataService = require(Services:WaitForChild("DataService"))
local NetService = require(Services:WaitForChild("NetService"))
local SettlerService = require(Services:WaitForChild("SettlerService"))
local BuildService = require(Services:WaitForChild("BuildService"))
local Grid = require(ReplicatedStorage.Shared.Modules.Grid)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local WorkshopService = require(Services:WaitForChild("WorkshopService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local StorytellerService = require(Services:WaitForChild("StorytellerService"))
local ColonyService = require(Services:WaitForChild("ColonyService"))
local DevService = require(Services:WaitForChild("DevService"))
local ObjectiveService = require(Services:WaitForChild("ObjectiveService"))
local StoreService = require(Services:WaitForChild("StoreService"))
local IntroService = require(Services:WaitForChild("IntroService"))
local NetServer = require(NetFolder:WaitForChild("NetServer"))

RiverService.Init({
    OnConfigChanged = function()
        for _, player in game:GetService("Players"):GetPlayers() do
            Net.Get("RiverConfig"):FireClient(player, RiverService.GetConfigFor(player))
        end
    end,
})
NetService.Init({
    River = RiverService,
    Remotes = {
        ObjectCaught = Net.Get("ObjectCaught"),
        RiverConfig = Net.Get("RiverConfig"),
        StateSnapshot = Net.Get("StateSnapshot"),
        WelcomeBack = Net.Get("WelcomeBack"),
    },
})
local colonyMap = Grid.new(
    RiverConfig.WORLD_WIDTH // RiverConfig.TILE,
    RiverConfig.WORLD_HEIGHT // RiverConfig.TILE,
    RiverConfig.TILE
)
BuildService.Init({
    Map = colonyMap,
    Remotes = {
        BuildingsState = Net.Get("BuildingsState"),
        BuildingDone = Net.Get("BuildingDone"),
    },
})
StoreService.Init({})
SettlerService.Init({
    Remotes = {
        SettlersFull = Net.Get("SettlersFull"),
        SettlerPaths = Net.Get("SettlerPaths"),
        SettlerLeft = Net.Get("SettlerLeft"),
        SettlerArrived = Net.Get("SettlerArrived"),
        SetSettlerJob = Net.Get("SetSettlerJob"),
    },
})
WorkshopService.Init({ Remotes = { WorkshopState = Net.Get("WorkshopState") } })
EconomyService.Init({})
-- Povestitorul intra dupa colonisti si cladiri: efectele lui apeleaza direct in ele
StorytellerService.Init({
    Remotes = {
        ColonyEvent = Net.Get("ColonyEvent"),
    },
})
ColonyService.Init({
    Remotes = {
        ColonyStats = Net.Get("ColonyStats"),
        RequestColony = Net.Get("RequestColony"),
    },
})
-- Consola de dezvoltare se conecteaza doar in Studio; verificarea e in DevService
ObjectiveService.Init({
    Remotes = {
        ObjectiveState = Net.Get("ObjectiveState"),
        ObjectiveDone = Net.Get("ObjectiveDone"),
        RequestObjectives = Net.Get("RequestObjectives"),
    },
})
-- Deschiderea intra ULTIMA: are nevoie de colonisti si de profil deja incarcate
IntroService.Init({
    Remotes = {
        IntroBegin = Net.Get("IntroBegin"),
        IntroTalk = Net.Get("IntroTalk"),
        IntroDone = Net.Get("IntroDone"),
    },
})
DevService.Init({ Remotes = { DevCommand = Net.Get("DevCommand") } })

-- DataService PORNESTE ULTIMUL. El e cel care declanseaza `ProfileLoaded`, iar toate serviciile
-- care asculta trebuie sa fie deja conectate: altfel un jucator aflat deja in server la pornire
-- ar incarca profilul inainte ca cineva sa asculte, si nu s-ar crea nici cladirile, nici oamenii.
DataService.Init({})
NetServer.Init({
    River = RiverService,
    Nets = NetService,
    Workshop = WorkshopService,
    Build = BuildService,
})

print("[Driftwood] server bootstrap complet")
