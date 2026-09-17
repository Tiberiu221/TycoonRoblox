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
    "SetAudio", -- C->S {kind, level}: nivelul muzicii sau al efectelor, 0..10, tinut minte in profil [D54]
    -- [D60] SpinWheel/WheelResult s-au mutat in balci (src/Fair/Net), odata cu roata
    "ClaimQuest", -- C->S: {questId} -- ia recompensa unui quest terminat
    "QuestRejected", -- S->C: {reason}
    "UpgradeStation", -- C->S: {kind, id, count} -- urca nivelul unei statii
    "UpgradeRejected", -- S->C: {reason} -- de ce n-a mers (coins/locked/unknown)
    "BuyPad", -- C->S {padId}
    "PadRejected", -- S->C {padId, reason}: "locked" | "owned" | "coins" | "no_profile"
    "PadBought", -- S->C {padId}: doar semnalul pentru efectul de constructie; starea vine separat
    "CollectNet", -- C->S {padId}
    "NetCaught", -- S->C {padId, count, capacity, good, catalog?, tier?}
    "Sold", -- S->C {total, itemCount}

    -- Noi la F1 (Era 1 completa) [F1 spec 2.2]
    "HandDelivered", -- S->C {handId, itemCount, place}: un om si-a lasat marfa (depozit/gater/debarcader)

    -- Noi la D49 (lantul pe oameni)
    "UseStorage", -- C->S: E la depozit -- lasi brutul, sau iei brut
    "UseSawmill", -- C->S: E la gater -- lasi brutul, apoi iei ce e taiat
    "DeliverDock", -- C->S: E la debarcader -- lasi ce e taiat
    "UseShed", -- C->S: E la shed-ul de scrap -- lasi scrap-ul, sau iei scrap [D55]
    "UseForge", -- C->S: E la atelier -- lasi scrap-ul la forja, apoi iei fierul gata [D55]
    "UseResult", -- S->C {place, ok, reason, dropped, taken}: ce a facut gestul, pentru toast
    "AtSawmill", -- C->S {present}: stai langa gater (fara Sawyer, doar atunci taie)
    "AtForge", -- C->S {present}: stai langa forja (fara Smelter, doar atunci topeste) [D56]
    "UpgradeCrew", -- C->S {role, what}: "tier" sau "hire" (al doilea om)

    -- Noi la D59 (pontonul: undita, ce aduce raul, satul)
    "Cast", -- C->S: arunci undita la capatul pontonului
    "CastResult", -- S->C {castId, biteAt, kind, difficulty, reelSeed, treasure?} sau {nil, reason}
    "Land", -- C->S {castId}: bara s-a umplut, scoti ce e pe fir
    "LandResult", -- S->C {castId, ok, reason, result?, wait?}: pestele/lucrul scos, sau cat mai ai de asteptat
    "TreasureArrived", -- S->C {kind, slot}: ceva a venit pe rau si s-a oprit la ponton
    "BuyDecor", -- C->S {decorId}: o imbunatatire a satului, pe perle
    "BuyOutfit", -- C->S {outfitId}: o tinuta, pe perle (o si imbraci)
    "WearOutfit", -- C->S {outfitId}: schimbi intre tinutele pe care le ai
    "ShopResult", -- S->C {what, id, ok, reason}: raspunsul avizierului

    -- Noi la D60 (balciul de seara, place-ul al doilea)
    "RowUp", -- C->S: urci in barca de la ponton (dupa drumul pictat); serverul te duce in balci
    "FerryFailed", -- S->C {reason}: barca n-a plecat ("studio" | "closed" | "no_profile" | "failed" | "timeout")
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
