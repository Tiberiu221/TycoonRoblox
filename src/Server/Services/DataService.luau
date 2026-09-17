--!strict
-- Profilul jucatorului prin ProfileStore: session locking, autosave, Reconcile [DECIZII D11, D14]
-- In Studio fara acces la API, ProfileStore foloseste automat un store Mock (datele se pierd la Stop).
-- [2026-09-15] Si CU acces la API, Play-ul din Studio porneste implicit de la zero (store-ul Mock); "keep save" din consola
-- de dev pastreaza salvarea reala pentru Play-urile urmatoare. Alegerea owner-ului: accesul la API ramane pornit (ca sa se
-- poata vedea revenirea: Welcome back, ce aduce raul cat lipsesti), dar testele de zi cu zi incep de la capat, ca inainte.
-- Schema v2 (pivotul D45 la tycoon) [F0 spec 1.3]: cheia de store ramane PlayerData_v1, doar
-- continutul se schimba; ProfileMigrate.toV2 goleste orice profil vechi inainte de Reconcile.
-- [D60] Acelasi modul ruleaza in AMBELE place-uri (satul si balciul), cu acelasi profil. Barca te muta dintr-unul in
-- celalalt fara sa inchida sesiunea inainte: daca teleportul pica, ramai unde erai, cu profilul in mana. Sesiunea o ia
-- apoi place-ul in care ajungi (ProfileStore cere, prin MessagingService, sesiunii vechi sa se inchida), iar cine e
-- "in drum" (MarkTeleporting) nu e dat afara cand se intampla asta.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ProfileStore = require(ServerStorage.ServerPackages.ProfileStore)
local ProfileMigrate = require(ReplicatedStorage.Shared.Modules.ProfileMigrate)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)
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
    -- A doua moneda [owner, 2026-09-12]. Pica din quest-uri, din roata, [D59] de la undita si din ce aduce raul.
    -- [D59] Se cheltuie DOAR pe aspect (decorul satului, tinutele): o faci cat vrei la undita, deci viteza sau spatiul
    -- cumparate cu ea ar ocoli simulatorul. Se schimba doar prin EconomyService.AddPearls / TrySpendPearls.
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
    -- [D55] `forge` e forja atelierului: topeste scrap-ul in fier.
    Stations: {
        carry: Station?,
        saw: Station,
        dock: Station,
        forge: Station,
        nets: { [string]: Station },
    },
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
    -- [D55] RESTURILE: scrap-ul lasat la shed, scrap-ul care asteapta topit la atelier, fierul iesit.
    ScrapPile: { counts: { [string]: number } },
    ForgePile: { counts: { [string]: number }, smeltedAt: number },
    IronPile: { counts: { [string]: number } },
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
        smelted: number, -- [D55] bucati de fier topite la forja
        ironSold: number, -- [D56] bucati de fier predate la taverna
        fished: number, -- [D59] pesti scosi la undita (quest-ul "Catch a fish at the pier")
        treasures: number, -- [D59] lucruri scoase din rau la ponton
        playSeconds: number, -- [D60] timpul jucat efectiv (fara zilele offline), pentru "Fastest Era 1"
        coinsEarned: number,
        padsBought: number,
        repairs: number, -- pentru WorkshopService (F1)
        scraps: number, -- pentru WorkshopService (F1)
    },
    Firsts: { [string]: boolean },
    -- [D51] preferintele jucatorului. [D54] nivelul muzicii si al efectelor, 0..10 (`music`, bool-ul vechi,
    -- ramane in profilurile migrate, necitit).
    Settings: { musicLevel: number, soundLevel: number, music: boolean? },
    -- [D59] UNDITA: samanta tragerilor, cate aruncari, momeli aurii ramase, jurnalul (specie -> cati si cea mai mare)
    Fishing: {
        seed: number,
        casts: number,
        bait: number,
        species: { [string]: { count: number, best: number } },
    },
    -- [D59] CE ADUCE RAUL (TreasureMath.State): ce asteapta la ponton, ceasul (os.time), samanta, cate au venit, bilete
    River: {
        started: boolean,
        waiting: { string },
        nextAt: number,
        seed: number,
        total: number,
        notes: number,
    },
    -- [D59] SATUL: decorul cumparat (id -> true), tinutele avute si cea purtata
    Village: { decor: { [string]: boolean }, outfits: { [string]: boolean }, outfit: string },
    -- [D60] BALCIUL: titlurile cumparate si cel purtat (TitleMath), cate vizite, si recordurile de pe tabela.
    -- `incomePerSec` e ultimul venit masurat in sat (sutimi): balciul n-are lantul, dar cardul jucatorului il arata.
    Titles: { bought: { [string]: boolean }, worn: string },
    Fair: { firstVisit: number, visits: number },
    Records: {
        era1Seconds: number,
        incomePerSec: number,
        weeklyFishMm: number,
        weeklyFishWeek: string,
    },
}

local PROFILE_TEMPLATE: ProfileData = {
    Meta = { version = 11, createdAt = 0, lastSeenAt = 0 },
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
        -- [D56] linia fierului -- ACELEASI campuri ca ProfileMigrate.toV8
        scrapCollector = { tier = 1 },
        scrapPorter = { tier = 1 },
        smelter = { tier = 1 },
        ironHauler = { tier = 1 },
    },
    -- ACELEASI campuri ca ProfileMigrate.toV7 [D55]: sablonul la v7 nu mai trece prin migrare.
    Stations = { saw = { level = 1 }, dock = { level = 1 }, forge = { level = 1 }, nets = {} },
    StoragePile = { counts = {} },
    SawmillPile = { counts = {}, sawnAt = 0 },
    PlanksPile = { counts = {} },
    DockPile = { counts = {}, drainedAt = 0 },
    ScrapPile = { counts = {} },
    ForgePile = { counts = {}, smeltedAt = 0 },
    IronPile = { counts = {} },
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
        smelted = 0,
        ironSold = 0, -- [D56] fier predat la taverna (quest-ul "Sell the iron at the tavern")
        fished = 0, -- [D59] ACELEASI campuri ca ProfileMigrate.toV9
        treasures = 0,
        playSeconds = 0, -- [D60] ACELEASI campuri ca ProfileMigrate.toV10
        coinsEarned = 0,
        padsBought = 0,
        repairs = 0,
        scraps = 0,
    },
    Firsts = {},
    Settings = { musicLevel = AudioLevels.DEFAULT_MUSIC, soundLevel = AudioLevels.DEFAULT_SOUND },
    -- [D59] ACELEASI campuri ca ProfileMigrate.toV9: un profil nou nu trece prin migrare
    Fishing = { seed = 0, casts = 0, bait = 0, species = {} },
    River = { started = false, waiting = {}, nextAt = 0, seed = 0, total = 0, notes = 0 },
    Village = { decor = {}, outfits = { keeper = true }, outfit = "keeper" },
    -- [D60] ACELEASI campuri ca ProfileMigrate.toV10
    Titles = { bought = {}, worn = "era" },
    Fair = {
        firstVisit = 0,
        visits = 0,
        -- [D61] ACELEASI campuri ca ProfileMigrate.toV11
        pond = { wins = 0, rounds = 0 },
        booth = { day = 0, prizeGames = 0, perfect = 0 },
    },
    Records = { era1Seconds = 0, incomePerSec = 0, weeklyFishMm = 0, weeklyFishWeek = "" },
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
local IS_STUDIO = RunService:IsStudio()
-- Comutatorul "keep save" din Studio sta intr-un store al lui, pe utilizator: trebuie citit INAINTE de profil, la
-- Play-ul urmator, iar in joc nu exista si nici nu se citeste.
local STUDIO_STORE = "StudioDevSettings_v1"
local studioFresh: { [Player]: boolean } = {}
-- [D60] cand a inceput sesiunea asta, ca la plecare sa se adune timpul jucat efectiv (Stats.playSeconds)
local sessionStartedAt: { [Player]: number } = {}
-- [D60] cine a urcat in barca: sesiunea lui o va lua celalalt place, deci pierderea ei nu e o eroare de aratat
local teleporting: { [Player]: boolean } = {}
-- [D60] "village" (satul, place-ul de start) sau "fair" (balciul). Balciul nu simuleaza satul: nu atinge `lastSeenAt`,
-- ca la intoarcere satul sa plateasca, ca offline, tot timpul cat ai lipsit din el. Se alege la Init.
local place = "village"

local function keepSaveKey(player: Player): string
    return `keepSave_{player.UserId}`
end

local function readKeepSave(player: Player): boolean
    local ok, value = pcall(function()
        return DataStoreService:GetDataStore(STUDIO_STORE):GetAsync(keepSaveKey(player))
    end)
    return ok and value == true -- fara acces la API citirea cade, deci Play-ul porneste de la zero, ca ProfileStore
end
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

-- [D54] Nivelurile sunetului (muzica, efecte), 0..10, tinute minte intre sesiuni. O valoare stricata din
-- profil cade pe implicit, nu ajunge la client.
function DataService.AudioLevels(player: Player): (number, number)
    local data = DataService.Get(player)
    local settings: any = if data ~= nil then data.Settings else nil
    if settings == nil then
        return AudioLevels.DEFAULT_MUSIC, AudioLevels.DEFAULT_SOUND
    end
    local music = if AudioLevels.valid(settings.musicLevel)
        then settings.musicLevel
        else AudioLevels.DEFAULT_MUSIC
    local sound = if AudioLevels.valid(settings.soundLevel)
        then settings.soundLevel
        else AudioLevels.DEFAULT_SOUND
    return music, sound
end

function DataService.SetAudioLevel(player: Player, kind: string, level: number)
    local data = DataService.Get(player)
    if data == nil or not AudioLevels.valid(level) then
        return
    end
    data.Settings = data.Settings
        or { musicLevel = AudioLevels.DEFAULT_MUSIC, soundLevel = AudioLevels.DEFAULT_SOUND }
    if kind == "music" then
        data.Settings.musicLevel = level
    elseif kind == "sound" then
        data.Settings.soundLevel = level
    end
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

-- [D60] De cate ori ai ajuns in balci (0 = niciodata): barca arata Skip abia de la al doilea drum.
function DataService.FairVisits(player: Player): number
    local data = DataService.Get(player)
    local fair: any = if data ~= nil then data.Fair else nil
    return if typeof(fair) == "table" and typeof(fair.visits) == "number" then fair.visits else 0
end

-- [D60] Urci in barca (on = true) sau barca n-a plecat (on = false). La urcare se noteaza timpul jucat si ora plecarii:
-- daca celalalt place ia sesiunea inainte ca plecarea sa fie vazuta aici, salvarea lui are deja amandoua.
function DataService.MarkTeleporting(player: Player, on: boolean)
    if not on then
        teleporting[player] = nil
        return
    end
    teleporting[player] = true
    local data = DataService.Get(player)
    local started = sessionStartedAt[player]
    if data == nil then
        return
    end
    local now = os.time()
    if started ~= nil then
        data.Stats.playSeconds = (data.Stats.playSeconds or 0) + math.max(0, now - started)
        sessionStartedAt[player] = now
    end
    if place == "village" then
        data.Meta.lastSeenAt = now
    end
end

-- [D60] Timpul jucat efectiv pana acum: cel strans in sesiunile trecute plus sesiunea asta.
function DataService.PlaySeconds(player: Player): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local started = sessionStartedAt[player]
    local now = if started ~= nil then math.max(0, os.time() - started) else 0
    return (data.Stats.playSeconds or 0) + now
end

function DataService.IsTeleporting(player: Player): boolean
    return teleporting[player] == true
end

-- [2026-09-15] "fresh" = Play-ul din Studio a pornit de la zero (store Mock), "kept" = pe salvarea reala, nil = in joc.
function DataService.StudioSave(player: Player): string?
    if not IS_STUDIO then
        return nil
    end
    return if studioFresh[player] == false then "kept" else "fresh"
end

-- Comuta "keep save" pentru Play-urile urmatoare; Play-ul de acum ramane cum a pornit. Intoarce (ok, keep).
function DataService.ToggleKeepSave(player: Player): (boolean, boolean)
    if not IS_STUDIO then
        return false, false
    end
    local keep = not readKeepSave(player)
    local ok = pcall(function()
        DataStoreService:GetDataStore(STUDIO_STORE):SetAsync(keepSaveKey(player), keep)
    end)
    return ok, keep
end

local function onPlayerAdded(player: Player)
    local fresh = IS_STUDIO and not readKeepSave(player)
    studioFresh[player] = fresh
    -- Mock.StartSessionAsync nu primeste `Cancel`: se incarca pe loc, iar iesirea din joc o prinde verificarea de dupa
    local source: any = if fresh then store.Mock else store
    local profile = source:StartSessionAsync(`Player_{player.UserId}`, {
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
    ProfileMigrate.toV6(profile.Data) -- nivelurile sunetului [D54]: muzica oprita ramane la 0
    ProfileMigrate.toV7(profile.Data) -- resturile [D55]: shed, forja, fierul -- aditiv, nimic nu se muta
    ProfileMigrate.toV8(profile.Data) -- linia fierului [D56]: meseriile noi; scrap-ul/fierul din roabe in gramezi
    ProfileMigrate.toV9(profile.Data) -- pontonul [D59]: undita, ce aduce raul, satul -- aditiv
    ProfileMigrate.toV10(profile.Data) -- balciul [D60]: titluri, vizite, recorduri, timpul jucat -- aditiv
    ProfileMigrate.toV11(profile.Data) -- iazul si gheretele [D61]: runde, jocuri cu premiu -- aditiv
    profile:Reconcile()
    profile.OnSessionEnd:Connect(function()
        profiles[player] = nil
        -- [D60] in drum spre celalalt place: acolo e sesiunea lui acum, iar un Kick aici ar opri teleportul
        if player.Parent == Players and not teleporting[player] then
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
    if place == "fair" then
        -- [D60] o vizita in balci nu e o sesiune noua de joc: satul le numara doar pe ale lui
        local fair = data.Fair
        fair.visits += 1
        if fair.firstVisit == 0 then
            fair.firstVisit = os.time()
        end
        if not data.Firsts.FirstFairVisit then
            data.Firsts.FirstFairVisit = true
            Analytics.FairStep(player, "FirstFairVisit")
        end
    else
        data.Stats.sessions += 1
        if not data.Firsts.Joined then
            data.Firsts.Joined = true
            Analytics.Funnel(player, "Joined")
        end
    end
    profiles[player] = profile
    sessionStartedAt[player] = os.time()
    -- [D60] ecranul de incarcare (ReplicatedFirst) il asteapta: pana aici, dupa o calatorie cu barca, profilul inca era
    -- in celalalt place
    player:SetAttribute("SaveLoaded", true)
    -- ATENTIE: se trimite DOAR jucatorul, niciodata tabelul de date.
    -- BindableEvent copiaza tabelele la trecerea prin el. Cand semnalul ducea si `data`,
    -- fiecare handler primea o COPIE: cladirile de start create acolo se scriau in copie si
    -- profilul real ramanea gol (de aici "0 paturi" si asezarea fara nicio cladire).
    -- Handlerele isi iau profilul cu DataService.Get(player).
    loadedSignal:Fire(player)
end

function DataService.Init(deps: { Place: string? })
    place = if deps.Place == "fair" then "fair" else "village"
    Players.PlayerAdded:Connect(onPlayerAdded)
    for _, player in Players:GetPlayers() do
        task.spawn(onPlayerAdded, player)
    end
    Players.PlayerRemoving:Connect(function(player: Player)
        studioFresh[player] = nil
        teleporting[player] = nil
        local profile = profiles[player]
        local started = sessionStartedAt[player]
        sessionStartedAt[player] = nil
        if profile ~= nil then
            if started ~= nil then
                local stats = profile.Data.Stats
                stats.playSeconds = (stats.playSeconds or 0) + math.max(0, os.time() - started)
            end
            if place == "village" then
                profile.Data.Meta.lastSeenAt = os.time()
            end
            profile:EndSession()
        end
    end)
end

return DataService
