--!strict
-- Wrapper minimal peste RemoteEvent-uri brute (pasul 1). Inlocuit de network.luau (Zap) la pasul 2 [DECIZII D11].
-- Contractele (payload, validare, raspunsuri) sunt in MASTERPLAN 4.3.2. Doar RemoteEvent, niciodata RemoteFunction [DECIZII D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
    -- Pastrate din pasul anterior [F0 spec 1.4]
    "RiverConfig", -- S->C
    "RequestState", -- C->S
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
    "DevCommand", -- C<->S: consola de dezvoltare, DOAR in Studio (poarta e pe server)

    -- Noi la pivotul tycoon (D45) [F0 spec 1.4]
    "TycoonState", -- S->C: instantaneul complet; clientul INLOCUIESTE starea, nu o combina
    "BuyPad", -- C->S {padId}
    "PadRejected", -- S->C {padId, reason}: "locked" | "owned" | "coins" | "no_profile"
    "PadBought", -- S->C {padId}: doar semnalul pentru efectul de constructie; starea vine separat
    "CollectNet", -- C->S {padId}
    "NetCaught", -- S->C {padId, count, capacity, good, catalog?}
    "SellSack", -- C->S
    "Sold", -- S->C {total, itemCount}
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
