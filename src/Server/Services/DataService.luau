--!strict
-- Profilul jucatorului prin ProfileStore: session locking, autosave, Reconcile [DECIZII D11, D14]
-- In Studio fara acces la API, ProfileStore foloseste automat un store Mock (datele se pierd la Stop).
-- Schema v2 (pivotul D45 la tycoon) [F0 spec 1.3]: cheia de store ramane PlayerData_v1, doar
-- continutul se schimba; ProfileMigrate.toV2 goleste orice profil vechi inainte de Reconcile.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local ProfileMigrate = require(ReplicatedStorage.Shared.Modules.ProfileMigrate)
local Analytics = require(script.Parent.Analytics)

-- Catch = ce a prins o plasa: id-ul bunului; pentru "named", id-ul din catalog + tier-ul.
export type Catch = { g: string, c: string?, t: string? }
export type NetState = { goods: { Catch }, nextCatchAt: number, caught: number }
export type PileItem = { id: number, tier: string, caughtAt: number, catalog: string? }
export type RepairSlot = {
    itemId: number,
    tier: string,
    startedAt: number,
    finishAt: number,
    catalog: string?,
}

export type ProfileData = {
    Meta: { version: number, createdAt: number, lastSeenAt: number },
    Coins: number, -- float; interfata arata floor
    Pads: { [string]: boolean },
    Nets: { [string]: NetState },
    Sack: { items: { Catch } },
    Pile: { [string]: PileItem }, -- pastrat pentru WorkshopService (F1)
    NextItemId: number,
    Workshop: { repairs: { [string]: RepairSlot } },
    Index: { [string]: number }, -- PASTRAT din v1: de cate ori a fost reparat fiecare obiect din catalog
    Hands: { [string]: any }, -- runners/maini: vine in F1
    Stations: { [string]: any }, -- build/upgrade/refine per jucator: vine mai tarziu
    Vault: { stored: number, updatedAt: number },
    Rebirths: number,
    Stats: {
        sessions: number,
        catches: number,
        collects: number,
        sells: number,
        coinsEarned: number,
        padsBought: number,
        repairs: number, -- pentru WorkshopService (F1)
        scraps: number, -- pentru WorkshopService (F1)
    },
    Firsts: { [string]: boolean },
}

local PROFILE_TEMPLATE: ProfileData = {
    Meta = { version = 2, createdAt = 0, lastSeenAt = 0 },
    Coins = 0,
    Pads = {},
    Nets = {},
    Sack = { items = {} },
    Pile = {},
    NextItemId = 1,
    Workshop = { repairs = {} },
    Index = {},
    Hands = {},
    Stations = {},
    Vault = { stored = 0, updatedAt = 0 },
    Rebirths = 0,
    Stats = {
        sessions = 0,
        catches = 0,
        collects = 0,
        sells = 0,
        coinsEarned = 0,
        padsBought = 0,
        repairs = 0,
        scraps = 0,
    },
    Firsts = {},
}

local function deepCopy(value: any): any
    if typeof(value) ~= "table" then
        return value
    end
    local copy = {}
    for k, v in value do
        copy[k] = deepCopy(v)
    end
    return copy
end

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

-- UNEALTA DE DEZVOLTARE (reset): goleste profilul si il reumple din sablon, pastrand Indexul.
-- Muteaza tabelul EXISTENT (nu il inlocuieste): ProfileStore tine o referinta la profile.Data.
function DataService.Reset(player: Player): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    local raw = data :: any
    local keptIndex = data.Index
    local createdAt = data.Meta.createdAt
    for key in raw do
        raw[key] = nil
    end
    for key, value in PROFILE_TEMPLATE :: any do
        raw[key] = deepCopy(value)
    end
    data.Index = keptIndex
    data.Meta.createdAt = createdAt
    data.Meta.lastSeenAt = os.time()
    return true
end

local function onPlayerAdded(player: Player)
    local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
        Cancel = function()
            return player.Parent ~= Players
        end,
    })
    if profile == nil then
        player:Kick("Could not load your save. Please rejoin in a few seconds.") -- gate de incarcare [MASTERPLAN 4.3.5]
        return
    end
    profile:AddUserId(player.UserId)
    ProfileMigrate.toV2(profile.Data) -- inainte de Reconcile: goleste orice profil sub v2 [F0 spec 1.3]
    profile:Reconcile()
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        if player.Parent == Players then
            player:Kick("Your save session ended (another server took over your profile).")
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
    if not data.Firsts.Joined then
        data.Firsts.Joined = true
        Analytics.Funnel(player, "Joined")
    end
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
