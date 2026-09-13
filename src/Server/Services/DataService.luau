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

-- Catch = ce a prins o plasa: id-ul bunului; pentru "named", id-ul din catalog + tier-ul. `p` = trecut
-- prin gater [D49] -- doar in traista si in spinarea unui om, unde brutul si taiatul se amesteca.
export type Catch = { g: string, c: string?, t: string?, p: boolean? }
export type Station = { level: number }
export type NetState = { goods: { Catch }, nextCatchAt: number, caught: number }
export type PileItem = { id: number, tier: string, caughtAt: number, catalog: string? }
export type RepairSlot = {
    itemId: number,
    tier: string,
    startedAt: number,
    finishAt: number,
    catalog: string?,
}
-- Un om [F1, aria I; D49]. `padId` = platforma meseriei lui; `id` e cheia lui in Hands (primul om =
-- id-ul platformei, al doilea = "<platforma>_2", vezi CrewMath.personKey). Traseul NU e aici -- se
-- recalculeaza mereu din platformele detinute (HandRoutes), ca sa nu poata ramane invechit.
export type Hand = {
    id: string,
    role: string, -- "collector" | "porter" | "sawyer" | "hauler" | "trader" [D49]
    padId: string,
    name: string,
    appearance: {
        body: string,
        hair: string,
        skin: { number },
        hairColor: { number },
        outfit: string,
    },
    cycleStartAt: number,
    lastEventAt: number,
    carry: { Catch },
}

export type ProfileData = {
    Meta: { version: number, createdAt: number, lastSeenAt: number },
    Coins: number,
    -- A doua moneda [owner, 2026-09-12]. Pica din quest-uri si din roata; cu Robux mai tarziu.
    -- Se cheltuie pe viteza, spatiu si aspect -- niciodata pe putere.
    Pearls: number, -- float; interfata arata floor
    Pads: { [string]: boolean },
    Nets: { [string]: NetState },
    Sack: { items: { Catch } },
    Pile: { [string]: PileItem }, -- pastrat pentru WorkshopService (F1)
    NextItemId: number,
    Workshop: { repairs: { [string]: RepairSlot } },
    Index: { [string]: number }, -- PASTRAT din v1: de cate ori a fost reparat fiecare obiect din catalog
    Hands: { [string]: Hand }, -- oamenii, cate o intrare pe om [F1, D49]
    -- Treapta fiecarei meserii [D49], comuna oamenilor din ea. Cati oameni sunt se numara din Hands.
    Crews: { [string]: { tier: number } },
    -- Nivelurile cladirilor (E1.2/E1.3). `nets` e padId -> nivel, ca o plasa sa-si poata urca
    -- nivelul separat de celelalte; `saw` e gaterul [D48], `dock` vanzarea. `carry` e statia din D48,
    -- scoasa in D49: ramane in profilurile vechi, necitita (nivelurile ei s-au rambursat la migrare).
    Stations: { carry: Station?, saw: Station, dock: Station, nets: { [string]: Station } },
    -- GRAMEZILE [D49], ca numaratori (PileMath): nu se pierde nimic si n-au plafon -- cand o veriga
    -- e cea slaba, gramada din fata ei creste si se vede [P2, D43].
    -- Ce aduna Collectorii din plase, pana il duce cineva la gater.
    StoragePile: { counts: { [string]: number } },
    -- Bustenii de la gater care ASTEAPTA sa fie taiati.
    SawmillPile: { counts: { [string]: number }, sawnAt: number },
    -- Ce a iesit din gater, pana il duce cineva la debarcader.
    PlanksPile: { counts: { [string]: number } },
    -- Marfa taiata de la debarcader care ASTEAPTA sa fie vanduta.
    DockPile: { counts: { [string]: number }, drainedAt: number },
    -- ce recompense de quest au fost deja luate; progresul NU se salveaza, se citeste din stare
    Quests: { claimed: { [string]: boolean } },
    -- roata zilnica: cand a fost ultima rotire, samanta si cate s-au facut [D46]
    Wheel: { lastSpinAt: number, seed: number, spins: number },
    Vault: { stored: number, updatedAt: number },
    Rebirths: number,
    Stats: {
        sessions: number,
        catches: number,
        collects: number, -- gesturi de colectare (statistica)
        sells: number, -- predari la debarcader (statistica)
        sawn: number, -- bucati taiate la gater, de oricine [D49]
        -- [D51] numaratori de BUCATI, pentru quest-urile buclei: gesturile de mai sus nu spun cat
        collected: number, -- bucati colectate de jucator din plase (nu de Collector)
        sold: number, -- bucati predate la taverna, de jucator sau de Hauler
        coinsEarned: number,
        padsBought: number,
        repairs: number, -- pentru WorkshopService (F1)
        scraps: number, -- pentru WorkshopService (F1)
    },
    Firsts: { [string]: boolean },
    -- [D51] preferintele jucatorului; muzica pornita implicit. Reconcile le adauga conturilor vechi.
    Settings: { music: boolean },
}

local PROFILE_TEMPLATE: ProfileData = {
    Meta = { version = 5, createdAt = 0, lastSeenAt = 0 },
    Coins = 0,
    Pearls = 0,
    Pads = {},
    Nets = {},
    Sack = { items = {} },
    Pile = {},
    NextItemId = 1,
    Workshop = { repairs = {} },
    Index = {},
    Hands = {},
    -- ACELEASI campuri ca ProfileMigrate.toV5: un profil NOU nu trece prin migrare, deci daca ar
    -- lipsi aici, primul jucator nou ar crapa la primul tick al gaterului.
    Crews = {
        collector = { tier = 1 },
        porter = { tier = 1 },
        sawyer = { tier = 1 },
        hauler = { tier = 1 },
        trader = { tier = 1 },
    },
    Stations = { saw = { level = 1 }, dock = { level = 1 }, nets = {} },
    StoragePile = { counts = {} },
    SawmillPile = { counts = {}, sawnAt = 0 },
    PlanksPile = { counts = {} },
    DockPile = { counts = {}, drainedAt = 0 },
    Quests = { claimed = {} },
    Wheel = { lastSpinAt = 0, seed = 0, spins = 0 },
    Vault = { stored = 0, updatedAt = 0 },
    Rebirths = 0,
    Stats = {
        sessions = 0,
        catches = 0,
        collects = 0,
        sells = 0,
        sawn = 0,
        collected = 0,
        sold = 0,
        coinsEarned = 0,
        padsBought = 0,
        repairs = 0,
        scraps = 0,
    },
    Firsts = {},
    Settings = { music = true },
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

-- Getter ingust pentru NetServer (care nu are voie sa ceara servicii de stare, deci nici tot
-- ProfileData): doar cele trei prime care NU se pot deduce din alta stare replicata [F1 spec 3.5].
-- runner/bell nu sunt aici -- ele sunt doar "platforma asta e cumparata", se citesc din `pads`.
function DataService.Firsts(player: Player): { collect: boolean, sell: boolean, named: boolean }
    local data = DataService.Get(player)
    if data == nil then
        return { collect = false, sell = false, named = false }
    end
    return {
        collect = data.Firsts.FirstCollect == true,
        sell = data.Firsts.FirstSell == true,
        named = data.Firsts.FirstNamed == true,
    }
end

-- [D51] Muzica pornita sau oprita, tinuta minte intre sesiuni. Implicit pornita.
function DataService.MusicOn(player: Player): boolean
    local data = DataService.Get(player)
    return data == nil or data.Settings == nil or data.Settings.music ~= false
end

function DataService.SetMusic(player: Player, on: boolean)
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    data.Settings = data.Settings or { music = true }
    data.Settings.music = on
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
    ProfileMigrate.toV2(profile.Data)
    ProfileMigrate.toV3(profile.Data) -- inainte de Reconcile: goleste orice profil sub v2 [F0 spec 1.3]
    ProfileMigrate.toV4(profile.Data) -- gaterul [D48]: nivelul lui si gramada, aditiv
    ProfileMigrate.toV5(profile.Data) -- oamenii [D49]: gramezi ca numaratori, trepte, Carry rambursat
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
