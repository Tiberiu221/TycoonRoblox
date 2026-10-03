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
    "SetClock", -- C->S {offset}: fusul orar al jucatorului (secunde fata de UTC), pentru ziua seriei zilnice [D71]
    -- [D60] SpinWheel/WheelResult s-au mutat in balci (src/Fair/Net), odata cu roata
    "ClaimQuest", -- C->S: {questId} -- ia recompensa unui quest terminat
    "QuestRejected", -- S->C: {reason}
    "QuestClaimed", -- S->C {questId, paid}: ce s-a platit (quest + capitolul, daca l-a incheiat) [D62]
    "UpgradeStation", -- C->S: {kind, id, count} -- urca nivelul unei statii
    "UpgradeRejected", -- S->C: {reason} -- de ce n-a mers (coins/locked/unknown)
    "StationUpgraded", -- S->C {kind, id, level, count, milestone?, incomeDelta}: nivelul cumparat, pentru efect [D62]
    "CrewUpgraded", -- S->C {role, what, value, incomeDelta}: treapta noua ("tier") sau cati oameni ("hire") [D62]
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
    -- [D65] LOCURILE ORICAREI LINII, intr-o singura cerere: magazia ("millStore", "oreShed", ...), atelierul
    -- ("foundry", "furnace", ...) sau vanzatorul ("market"). Locurile sunt cele din Shared/Config/FlowConfig; cele ale
    -- Erei 1 merg si pe aici, si pe cererile lor de mai sus. Raspunsul vine tot pe `UseResult`.
    "UsePlace", -- C->S {place}: E la un loc -- magazie: lasi brutul sau iei; atelier: lasi si iei; vanzator: predai
    "AtPlace", -- C->S {place, present}: stai langa un atelier (fara omul lui, doar atunci lucreaza)
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
    -- [D62, pasul 3] darurile raului (DriftService): programul e determinist, deci clientul spune doar care dar
    "GrabDrift", -- C->S {giftId}: am scos darul ferestrei asteia (DriftMath)
    "DriftGrabbed", -- S->C {giftId, ok, reason, kind, coins}
    -- [D61, partea 2] coltul cu Robux: fereastra de cumparare o deschide serverul (PurchaseService.Prompt)
    "RobuxBuy", -- C->S {key}: vreau lucrul asta din catalog (MonetizationConfig)
    "RobuxResult", -- S->C {key, ok, reason, coins}: refuzul ("soon" | "owned" | "nothing" | ...) sau ce ai primit

    -- Noi la D60 (balciul de seara, place-ul al doilea)
    "RowUp", -- C->S: urci in barca de la ponton (dupa drumul pictat); serverul te duce in balci
    "FerryFailed", -- S->C {reason}: barca n-a plecat ("studio" | "closed" | "no_profile" | "failed" | "timeout")

    -- [D70, pasul j15] BARAJUL (DamService, doar in sat): ecranul „Build the Dam”, ridicarea, filmul
    "DamPreview", -- C->S: ce s-ar intampla acum (chitanta, din DamMath.preview)
    "DamPreviewResult", -- S->C {receipt?, reason?}: chitanta, sau de ce nu ("soon" | "bell" | "built" | "settling")
    "BuildDam", -- C->S {expectedKeep}: ridica barajul; `expectedKeep` = monedele cu care pornesti, din previzualizare
    "DamBuilt", -- S->C {receipt}: barajul e ridicat si salvat (clientul porneste filmul, apoi reincarcarea, k7-k8)
    "DamRejected", -- S->C {reason}: "soon" | "bell" | "built" | "settling" | "changed" | "busy" | "no_profile" | "save"
    "DamFilmSeen", -- C->S: filmul s-a vazut (sau s-a sarit); nu mai porneste singur
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
