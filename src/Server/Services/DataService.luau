--!strict
-- Profilul jucatorului prin ProfileStore: session locking, autosave, Reconcile [DECIZII D11, D14]
-- In Studio fara acces la API, ProfileStore foloseste automat un store Mock (datele se pierd la Stop).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)

export type NetData = {
    id: number,
    slotId: number,
    tier: string,
    placedAt: number,
    lastCollectedAt: number,
    items: { string },
}
export type ProfileData = {
    Meta: { version: number, createdAt: number, lastSeenAt: number },
    Nets: { [string]: NetData }, -- cheie = tostring(netId) (DataStore nu accepta chei numerice sparse)
    NextNetId: number,
    Inventory: { [string]: number }, -- pastrat pentru compatibilitate; obiectele stau in Pile
    -- gramada nesortata, cheie = tostring(id). `catalog` = id din ItemConfig; lipseste la
    -- profilele facute inainte de Index si se completeaza la prima atingere.
    Pile: {
        [string]: { id: number, tier: string, caughtAt: number, catalog: string? },
    },
    NextItemId: number,
    Workshop: {
        repairs: {
            [string]: {
                itemId: number, -- id-ul din gramada, nu din catalog
                tier: string,
                startedAt: number,
                finishAt: number,
                catalog: string?, -- id din ItemConfig: ce obiect anume se repara
            },
        },
    }, -- cheie = slotIndex
    Repaired: { [string]: number }, -- cate obiecte reparate per tier (pastrat: profile vechi)
    -- INDEXUL [DECIZII D17]: de cate ori a fost reparat fiecare obiect din catalog. Asta e
    -- singurul lucru pe care reparatia il produce si dezmembrarea nu -- deci singurul motiv
    -- sa repari ceva. Inainte, reparatia scria un contor pe care nu-l citea nimeni.
    Index: { [string]: number },
    Materials: number,
    Buildings: {
        [string]: { id: number, defId: string, x: number, y: number, progress: number },
    },
    NextBuildingId: number,
    Stats: { [string]: number },
    Objectives: { index: number, done: { string } },
    Stores: { [string]: number },
    Settlers: { list: { { [string]: any } }, nextId: number },
    Firsts: { [string]: boolean },
}

local PROFILE_TEMPLATE: ProfileData = {
    Meta = { version = 1, createdAt = 0, lastSeenAt = 0 },
    Nets = {},
    NextNetId = 1,
    Inventory = {},
    Pile = {},
    NextItemId = 1,
    Workshop = { repairs = {} },
    Repaired = {},
    Index = {},
    Materials = 30, -- start: destul pentru un cort si un firepit
    Buildings = {},
    NextBuildingId = 1,
    Stats = {
        catches = 0,
        collects = 0,
        sessions = 0,
        repairs = 0,
        -- contori pentru lantul de obiective (RIVERKEEP 2)
        netsPlaced = 0,
        scraps = 0,
        buildsPlaced = 0,
        buildsFinished = 0,
        jobsAssigned = 0,
        settlersArrived = 0,
    },
    Objectives = { index = 1, done = {} },
    Stores = { food = 40 }, -- hrana coloniei [RIVERKEEP 5]
    -- Colonistii se salveaza cu tot cu nume, meserie, nevoi si trasaturi: o colonie crescuta
    -- in cateva sesiuni nu are voie sa se intoarca la un singur strain dupa o repornire.
    Settlers = { list = {}, nextId = 1 },
    Firsts = {},
}

local DataService = {}
local store = ProfileStore.New("PlayerData_v1", PROFILE_TEMPLATE)
local profiles: { [Player]: any } = {}
local loadedSignal = Instance.new("BindableEvent")
-- Semnatura: (player: Player). Fara tabel, din motivul explicat la Fire.
DataService.ProfileLoaded = loadedSignal.Event

function DataService.Get(player: Player): ProfileData?
    local profile = profiles[player]
    if profile ~= nil and profile:IsActive() then
        return profile.Data
    end
    return nil
end

local function onPlayerAdded(player: Player)
    local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    if profile == nil then
        player:Kick("Datele nu s-au putut incarca. Reincearca in cateva secunde.") -- gate de incarcare [MASTERPLAN 4.3.5]
        return
    end
    profile:AddUserId(player.UserId)
    profile:Reconcile()
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        if player.Parent == Players then
            player:Kick("Sesiunea de date s-a inchis (alt server a preluat profilul).")
        end
    end)
    if player.Parent ~= Players then
        profile:EndSession()
        return
    end
    local data: ProfileData = profile.Data
    if data.Meta.createdAt == 0 then
        data.Meta.createdAt = os.time()
    end
    data.Stats.sessions += 1
    profiles[player] = profile
    -- ATENTIE: se trimite DOAR jucatorul, niciodata tabelul de date.
    -- BindableEvent copiaza tabelele la trecerea prin el. Cand semnalul ducea si `data`,
    -- fiecare handler primea o COPIE: cladirile de start create acolo se scriau in copie si
    -- profilul real ramanea gol (de aici "0 paturi" si asezarea fara nicio cladire).
    -- Handlerele isi iau profilul cu DataService.Get(player).
    loadedSignal:Fire(player)
end

function DataService.Init(_deps: {})
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
    Players.PlayerRemoving:Connect(function(player: Player)
        local profile = profiles[player]
        if profile ~= nil then
            profile.Data.Meta.lastSeenAt = os.time()
            profile:EndSession()
        end
    end)
end

return DataService
