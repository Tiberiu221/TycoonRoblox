--!strict
-- Wrapper minimal peste RemoteEvent-uri brute (pasul 1). Inlocuit de network.luau (Zap) la pasul 2 [DECIZII D11].
-- Contractele (payload, validare, raspunsuri) sunt in MASTERPLAN 4.3.2. Doar RemoteEvent, niciodata RemoteFunction [DECIZII D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
    "RiverConfig", -- S->C
    "PlaceNet", -- C->S
    "NetPlaced", -- S->C
    "NetRejected", -- S->C
    "CollectNet", -- C->S
    "NetCollected", -- S->C
    "ObjectCaught", -- S->C: serverul a decis ca plasa a prins un obiect
    "RequestState", -- C->S
    "StateSnapshot", -- S->C
    "WelcomeBack", -- S->C: rezumatul acumularii offline la login
    "RequestWorkshop", -- C->S
    "WorkshopState", -- S->C
    "StartRepair", -- C->S {itemId, slotIndex}
    "CollectRepair", -- C->S {slotIndex}
    "ScrapItem", -- C->S {itemId}
    "WorkshopRejected", -- S->C {reason}
    -- S->C {catalogId}: un obiect a intrat PERMANENT in colectie. E singura rasplata pe care
    -- dezmembrarea nu o da, deci trebuie sa se vada; pana acum se schimba doar o cifra, in tacere.
    "RepairDone",
    "SettlersFull", -- S->C: lista completa de colonisti (la join / la schimbare de numar)
    "SettlerPaths",
    "SettlerLeft",
    "BuildingsState", -- S->C: lista de cladiri + paturi
    "PlaceBuilding", -- C->S {defId, x, y}
    "BuildRejected", -- S->C {reason}
    "BuildingDone", -- S->C {label}
    "SettlerArrived",
    "SetSettlerJob", -- C->S {settlerId, job}
    "ColonyEvent", -- S->C: povestitorul a declansat un eveniment {id,title,body,tone,detail,at}
    "ColonyStats", -- S->C: tabloul coloniei (populatie, paturi, nevoi medii, materiale)
    "RequestColony", -- C->S: cere tabloul acum
    "DevCommand", -- C<->S: consola de dezvoltare, DOAR in Studio (poarta e pe server)
    "ObjectiveState", -- S->C: pasul curent, telurile lungi si ce parti de interfata sunt deschise
    "ObjectiveDone", -- S->C: un pas tocmai s-a terminat (moment de sarbatoare)
    "RequestObjectives", -- C->S
    "IntroBegin", -- S->C: incepe deschiderea; jucatorul e blocat pana se termina
    "IntroTalk", -- S->C: colonistul a ajuns langa jucator {name, sceneId}
    "IntroDone", -- C->S: jucatorul a terminat de citit
    -- S->C {name}
    -- S->C: un colonist a plecat pe apa
    -- S->C: waypoint-uri pentru colonistii care si-au schimbat drumul
}

local Net = {}
local folder: Folder

if RunService:IsServer() then
    folder = Instance.new("Folder")
    folder.Name = "Remotes"
    for _, name in REMOTE_NAMES do
        local remote = Instance.new("RemoteEvent")
        remote.Name = name
        remote.Parent = folder
    end
    folder.Parent = ReplicatedStorage
else
    folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.Get(name: string): RemoteEvent
    local remote = folder:WaitForChild(name, 10)
    assert(remote ~= nil and remote:IsA("RemoteEvent"), `Remote lipsa: {name}`)
    return remote :: RemoteEvent
end

return Net
