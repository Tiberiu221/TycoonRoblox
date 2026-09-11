--!strict
-- Ordinea explicita de Init(deps): fara require incrucisat intre servicii [MASTERPLAN 3.5]
-- Ordine F0: River -> Economy -> Pads -> Nets -> Workshop -> Dev -> NetServer (asculta
-- ProfileLoaded, deci se conecteaza inainte) -> DataService (ultimul, el declanseaza ProfileLoaded).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Services = script.Parent:WaitForChild("Services")
local NetFolder = script.Parent:WaitForChild("Net")

local Net = require(ReplicatedStorage.Net.Net)
local RiverService = require(Services:WaitForChild("RiverService"))
local EconomyService = require(Services:WaitForChild("EconomyService"))
local PadService = require(Services:WaitForChild("PadService"))
local NetService = require(Services:WaitForChild("NetService"))
local WorkshopService = require(Services:WaitForChild("WorkshopService"))
local DevService = require(Services:WaitForChild("DevService"))
local DataService = require(Services:WaitForChild("DataService"))
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
EconomyService.Init({ Pads = PadService, PushState = NetServer.PushState })
PadService.Init({ PushState = NetServer.PushState })
NetService.Init({
    Remotes = { NetCaught = Net.Get("NetCaught") },
    PushState = NetServer.PushState,
})
WorkshopService.Init({
    Remotes = { WorkshopState = Net.Get("WorkshopState") },
    PushState = NetServer.PushState,
})
-- Consola de dezvoltare se conecteaza doar in Studio; verificarea e in DevService
DevService.Init({
    Remotes = { DevCommand = Net.Get("DevCommand") },
    PushState = NetServer.PushState,
})

-- NetServer se conecteaza la `ProfileLoaded` INAINTE ca DataService sa porneasca: DataService e cel
-- care il declanseaza, iar un jucator aflat deja in server la pornire si-ar incarca profilul fara
-- ca cineva sa asculte -- n-ar primi nici raul, nici instantaneul initial.
NetServer.Init({
    River = RiverService,
    Data = DataService,
    Pads = PadService,
    Nets = NetService,
    Economy = EconomyService,
    Workshop = WorkshopService,
})
DataService.Init({})

print("[Driftwood] server bootstrap complet")
