--!strict
-- [D60] Retelele BALCIULUI, separate de ale satului: fiecare place isi declara doar remote-urile pe care le foloseste,
-- ca `check_requires` sa poata cere, pe fiecare, ca oricare remote sa aiba si ascultator si trimitator.
-- Acelasi tipar ca Shared/Net/Net.luau: doar RemoteEvent, niciodata RemoteFunction [DECIZII D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
    "RequestState", -- C->S: trimite-mi starea (la pornire, de cateva ori, ca in sat)
    "FairState", -- S->C: perlele, satul (decor, tinute), roata, cate vizite; clientul INLOCUIESTE starea
    "RowHome", -- C->S: barca inapoi spre sat
    "FerryFailed", -- S->C {reason}: barca n-a plecat (aceleasi motive ca in sat, FerryService)
    -- roata zilnica, mutata din sat [D60]: aceleasi doua remote-uri, acelasi raspuns
    "SpinWheel", -- C->S
    "WheelResult", -- S->C {prizeId, pearls, converted} sau {nil, 0, false, reason}
    "SetAudio", -- C->S {kind, level}: panoul "Sound", acelasi profil ca in sat [D54]
    -- titlurile (TitleService)
    "BuyTitle", -- C->S {titleId}: unul din cele trei de vanzare, pe perle (il si porti)
    "WearTitle", -- C->S {titleId}: schimbi intre titlurile tale
    "MarketBuy", -- C->S {key}: un lucru din vitrina zilei ("decor:fountain", "outfit:angler", "title:old_salt")
    "ShopResult", -- S->C {what, id, ok, reason}: raspunsul, ca la avizierul satului
    -- oamenii din balci (PresenceService)
    "LookAt", -- C->S {userId}: cardul cuiva de pe server
    "LookAtResult", -- S->C {card} sau {nil, userId}: ce a facut (PlayerCardService), sau ca a plecat
    "BoardState", -- S->C: clasamentele saptamanii, campionul, trofeele (BoardService), din minut in minut
    "People", -- S->C {{slot, userId, name, outfit, title}}: cine e aici, cand se schimba ceva; C->S: trimite-mi-o
    -- [D61] iazul de concurs: aceeasi undita ca la pontonul din sat (FishService), alte nume, plus tabla rundei
    "PondCast", -- C->S: arunc de pe jetiu
    "PondCastResult", -- S->C {castId, biteAt, kind, difficulty, reelSeed} sau {nil, reason}
    "PondLand", -- C->S {castId}: bara e plina
    "PondLandResult", -- S->C {castId, ok, reason, result, wait}
    "PondState", -- S->C: runda (faza, ore absolute), clasamentul ei, podiumul rundei trecute (PondService)
    "PondResult", -- S->C {index, place, count, prize, contest, won, wins, title}: al tau, la sfarsitul rundei
}

-- [D60] Pozitiile, de zece ori pe secunda: un pachet pierdut nu conteaza, urmatorul vine imediat. Aceeasi regula ca
-- mai sus in check_requires (ascultator si trimitator pe fiecare).
local UNRELIABLE_REMOTE_NAMES = {
    "Where", -- C->S {x, y, facing, moving, fishing}: unde esti (validat: numere, drum, pas; undita doar pe jetiu)
    "Crowd", -- S->C buffer, 6 octeti de om: slot u8, x u16, y u16, directie + mers u8
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
    for _, name in UNRELIABLE_REMOTE_NAMES do
        local remote = Instance.new("UnreliableRemoteEvent")
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

function Net.GetUnreliable(name: string): UnreliableRemoteEvent
    local remote = folder:WaitForChild(name, 10)
    assert(remote ~= nil and remote:IsA("UnreliableRemoteEvent"), `Remote nesigur lipsa: {name}`)
    return remote :: UnreliableRemoteEvent
end

return Net
