--!strict
-- [D60] Retelele BALCIULUI, separate de ale satului: fiecare place isi declara doar remote-urile pe care le foloseste,
-- ca `check_requires` sa poata cere, pe fiecare, ca oricare remote sa aiba si ascultator si trimitator.
-- Acelasi tipar ca Shared/Net/Net.luau: doar RemoteEvent, niciodata RemoteFunction [DECIZII D13].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local REMOTE_NAMES = {
    "RowHome", -- C->S: barca inapoi spre sat
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
