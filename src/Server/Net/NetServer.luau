--!strict
-- Handlere de remote: valideaza input-ul (tip, isfinite, rate limit), apoi apeleaza Service-urile
-- [F0 spec 3.5]. Fara require-uri de servicii aici (doar Net/RateLimiter/TycoonConfig, module
-- fara stare de joc) -- totul altceva vine prin Init(deps), cablat de Bootstrap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net.Net)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local WorldMath = require(ReplicatedStorage.Shared.Modules.WorldMath)
local RateLimiter = require(script.Parent.RateLimiter)
local AudioLevels = require(ReplicatedStorage.Shared.Modules.AudioLevels)

-- [D67, D70 pasul j10] Zonele lumii jucatorului si clopotul care o deschide pe fiecare: regula e pura, in
-- WorldMath.zoneStatuses (testata).

export type Deps = {
    River: { GetConfigFor: (Player) -> { [string]: any }, Now: () -> number },
    -- Firsts: DOAR cele trei care nu se pot deduce din pads (collect/sell/named se repeta, deci
    -- au nevoie de un steag persistent) [F1 spec 2.1].
    Data: {
        ProfileLoaded: RBXScriptSignal,
        Firsts: (Player) -> { collect: boolean, sell: boolean, named: boolean },
        AudioLevels: (Player) -> (number, number),
        SetAudioLevel: (Player, string, number) -> (),
        FairVisits: (Player) -> number, -- [D60] barca arata Skip de la al doilea drum
        -- [D71] seria zilnica (StreakMath), curatata: o zi noua in timpul jocului se anunta pe client
        Streak: (Player) -> { day: number, run: number, best: number, total: number },
        SetStreakClock: (Player, unknown) -> boolean, -- [D71]
    },
    Pads: {
        Buy: (Player, string) -> (boolean, string?),
        Statuses: (Player) -> { [string]: string },
        Deltas: (Player) -> ({ [string]: number }, string),
        Lanes: (Player) -> number,
        World: (Player) -> number, -- [D70] lumea din profil, aceeasi ca a statusurilor
        Owns: (Player, string) -> boolean, -- [D70] platforma e a ta, in orice lume
    },
    Stations: {
        Snapshot: (Player) -> { [string]: any },
        Upgrade: (Player, string, string?, number) -> (boolean, string, { [string]: any }?),
        UpgradeCrew: (Player, string, string) -> (boolean, string, { [string]: any }?),
    },
    Quests: {
        Snapshot: (Player) -> { [string]: any }?,
        Claim: (Player, string) -> (boolean, string, { [string]: any }?),
    },
    -- [D60] roata se invarte in balci; aici doar ceasul ei, pentru indicatorul de pe punte
    Wheel: { Snapshot: (Player) -> { [string]: any } },
    -- [D59] pontonul
    Fish: {
        Snapshot: (Player) -> { [string]: any },
        Cast: (Player) -> (boolean, string, { [string]: any }?),
        Land: (Player, number) -> (boolean, string, { [string]: any }?, number?),
    },
    Treasures: { Snapshot: (Player) -> { [string]: any } },
    Village: {
        Snapshot: (Player) -> { [string]: any },
        BuyDecor: (Player, string) -> (boolean, string),
        BuyOutfit: (Player, string) -> (boolean, string),
        WearOutfit: (Player, string) -> (boolean, string),
    },
    -- [D62, pasul 3] darurile raului
    Drift: { Grab: (Player, number) -> (boolean, string, string?, number?) },
    -- [D61, partea 2] coltul cu Robux: pass-urile tale, ce ar aduce produsele acum, fereastra de cumparare
    Shop: {
        Snapshot: (Player) -> { [string]: any },
        Prompt: (Player, string) -> (boolean, string),
    },
    Nets: { Collect: (Player, string) -> (boolean, string?), Snapshot: (Player) -> { any } },
    Economy: {
        GetCoins: (Player) -> number,
        GetPearls: (Player) -> number,
        IncomePerSec: (Player) -> number,
        SellMult: (Player) -> number,
        SackSnapshot: (Player) -> { [string]: any },
        StorageSnapshot: (Player) -> { [string]: any },
        DockSnapshot: (Player) -> { [string]: any },
        SawmillSnapshot: (Player) -> { [string]: any },
        ShedSnapshot: (Player) -> { [string]: any },
        ForgeSnapshot: (Player) -> { [string]: any },
        UseStorage: (Player) -> (boolean, string, number),
        UseSawmill: (Player) -> (boolean, string, number, number),
        DeliverDock: (Player) -> (boolean, string, number),
        UseShed: (Player) -> (boolean, string, number),
        UseForge: (Player) -> (boolean, string, number, number),
        SetPresence: (Player, string, boolean) -> (),
        -- [D65] locurile oricarei linii si instantaneele lor
        UseStore: (Player, string) -> (boolean, string, number),
        UseProcessor: (Player, string) -> (boolean, string, number, number),
        Deliver: (Player, string) -> (boolean, string, number),
        StoreSnapshotOf: (Player, string) -> { [string]: any },
        ProcessorSnapshotOf: (Player, string) -> { [string]: any },
        SellerSnapshotOf: (Player, string) -> { [string]: any },
    },
    Workshop: {
        Snapshot: (Player) -> { [string]: any },
        StartRepair: (Player, number, number) -> (boolean, string),
        CollectRepair: (Player, number) -> (boolean, string),
        ScrapItem: (Player, number) -> (boolean, string),
        PileCount: (Player) -> number,
    },
    Hands: { Snapshot: (Player) -> { any } },
    -- [D60] barca spre balci
    Ferry: { Depart: (Player) -> () },
    -- [D70, pasul j15] barajul (DamService): previzualizarea, ridicarea, filmul
    Dam: {
        Preview: (Player) -> ({ [string]: any }?, string?),
        Build: (Player, number) -> ({ [string]: any }?, string?),
        FilmSeen: (Player) -> (),
    },
}

local NetServer = {}
local deps: Deps
local pending: { [Player]: boolean } = {}

local function isInteger(value: unknown): boolean
    return typeof(value) == "number"
        and math.isfinite(value :: number)
        and (value :: number) % 1 == 0
end

local function isValidPadId(value: unknown): boolean
    return typeof(value) == "string"
        and #(value :: string) <= 40
        and TycoonConfig.byId[value :: string] ~= nil
end

-- Instantaneul complet trimis clientului [F1 spec 2.1]. Fiecare camp e prezent la FIECARE push
-- (niciodata nil) -- clientul copiaza starea asta orbeste, un camp lipsa ar insemna o coliziune cu
-- valoarea veche ramasa de la push-ul anterior.
-- [D65] Magazia si atelierul fiecarei linii din StationConfig.LINE_ORDER, gramada fiecarui vanzator.
local function flowSnapshot(player: Player): { [string]: any }
    local lines: { [string]: any } = {}
    for _, line in StationConfig.LINE_ORDER do
        lines[line] = {
            store = deps.Economy.StoreSnapshotOf(player, line),
            processor = deps.Economy.ProcessorSnapshotOf(player, line),
        }
    end
    local sellers: { [string]: any } = {}
    for _, seller in StationConfig.SELLER_ORDER do
        sellers[seller] = deps.Economy.SellerSnapshotOf(player, seller)
    end
    return { lines = lines, sellers = sellers }
end

local function buildTycoonState(player: Player): { [string]: any }
    local pads = deps.Pads.Statuses(player)
    local padDeltas, bottleneck = deps.Pads.Deltas(player)
    local firsts = deps.Data.Firsts(player)
    local musicLevel, soundLevel = deps.Data.AudioLevels(player)
    return {
        coins = deps.Economy.GetCoins(player),
        pearls = deps.Economy.GetPearls(player),
        incomePerSec = deps.Economy.IncomePerSec(player),
        sellMult = deps.Economy.SellMult(player),
        serverTime = deps.River.Now(),
        pads = pads,
        nets = deps.Nets.Snapshot(player),
        sack = deps.Economy.SackSnapshot(player),
        -- depozitul de langa plase: ce a strans Collector-ul (sau tu) [D49]
        storage = deps.Economy.StorageSnapshot(player),
        -- gaterul: ce asteapta sa fie taiat, ce a iesit, cat taie acum si daca stai langa el [D49]
        sawmill = deps.Economy.SawmillSnapshot(player),
        -- gramada de la debarcader: ce asteapta sa fie vandut si cat de repede se scurge
        dock = deps.Economy.DockSnapshot(player),
        -- [D55] resturile: shed-ul de scrap si forja atelierului (scrap de topit, fier iesit, cat topeste)
        shed = deps.Economy.ShedSnapshot(player),
        forge = deps.Economy.ForgeSnapshot(player),
        -- [D65] DRUMUL MARFII PE LINII: magazia si atelierul fiecarei linii, gramada fiecarui vanzator. Campurile de
        -- mai sus raman vederea Erei 1 (aceleasi cifre); clientul Morii citeste de aici.
        flow = flowSnapshot(player),
        -- statiile cu niveluri: randurile panoului, veriga slaba si cele trei debite
        stations = deps.Stations.Snapshot(player),
        -- capitolul curent, lista de quest-uri si quest-ul activ (unicul obiectiv de ghidaj)
        quests = deps.Quests.Snapshot(player),
        wheel = deps.Wheel.Snapshot(player),
        -- [D59] undita (momeala, jurnalul, cati pesti), ce asteapta la ponton, satul (decor, tinute)
        fishing = deps.Fish.Snapshot(player),
        river = deps.Treasures.Snapshot(player),
        village = deps.Village.Snapshot(player),
        lanes = deps.Pads.Lanes(player), -- banda cea mai departata: desenul plaselor [D55: nu mai decide marfa]
        -- cat adauga la venit/s fiecare platforma inca necumparata, pentru cartonasul de la apropiere
        padDeltas = padDeltas,
        hands = deps.Hands.Snapshot(player),
        -- Mill se vede mereu (estompata, ingradita) si se deschide cu Landing Bell [B4, C].
        -- [D65, D67] La fel zona fiecarei ere urmatoare, cu clopotul erei dinainte (ZONE_BELL). Una deschisa dar inca
        -- nefacuta (platformele ei nu sunt `live`) ramane estompata si scrie "coming soon": asta o decide clientul.
        zones = WorldMath.zoneStatuses(deps.Pads.World(player), pads),
        workshop = pads.workshop == "bought",
        -- [D56] parcat odata cu colectia: clientul nu-l mai citeste (insigna atelierului a iesit)
        pile = deps.Workshop.PileCount(player),
        bottleneck = bottleneck,
        -- runner (= Collector-ul, id-ul vechi al platformei [D49]) / bell: doar "platforma asta e
        -- cumparata" (nu se pierde, deci echivaleaza cu un prim persistent); collect/sell/named sunt
        -- evenimente repetabile, vin din profil.
        firsts = {
            collect = firsts.collect,
            sell = firsts.sell,
            named = firsts.named,
            -- [D70] din profil: statusurile sunt doar ale hartii de acum, iar la baraj n-au platformele satului
            runner = deps.Pads.Owns(player, "first_runner"),
            bell = deps.Pads.Owns(player, "landing_bell"),
            power = firsts.power, -- [D67] felinarele de pe strada
        },
        -- [D54] preferintele: nivelul muzicii si al efectelor, 0..10
        settings = { musicLevel = musicLevel, soundLevel = soundLevel },
        -- [D60] de cate ori ai ajuns in balci
        fair = (function()
            local streak = deps.Data.Streak(player)
            return {
                visits = deps.Data.FairVisits(player),
                streak = { run = streak.run, best = streak.best },
            }
        end)(),
        -- [D61, partea 2] pass-urile tale, ce ar aduce produsele acum, cat de repede mergi
        robux = deps.Shop.Snapshot(player),
    }
end

-- Un singur push pe cadru per jucator: Buy/Collect/Sell/tick-ul de plase pot cere fiecare o
-- retrimitere in aceeasi bucla, dar clientul are nevoie doar de ULTIMA stare, nu de una per apel.
function NetServer.PushState(player: Player)
    if pending[player] then
        return
    end
    pending[player] = true
    task.defer(function()
        pending[player] = nil
        if player.Parent ~= Players then
            return
        end
        -- [D70, dupa verificator] Nu inainte de profil: fara el, starea ar pleca goala (nicio platforma, niciun curent
        -- vandut), iar clientul ar lua starea adevarata de dupa drept o schimbare, cu felinarele si treptele satului
        -- anuntate din nou la fiecare intrare si la fiecare intoarcere din balci. ProfileLoaded o trimite imediat dupa.
        if player:GetAttribute("SaveLoaded") ~= true then
            return
        end
        Net.Get("TycoonState"):FireClient(player, buildTycoonState(player))
    end)
end

local function sendWorkshop(player: Player)
    Net.Get("WorkshopState"):FireClient(player, deps.Workshop.Snapshot(player))
end

function NetServer.Init(d: Deps)
    deps = d

    -- La incarcarea profilului: raul (vizual) + instantaneul tycoon complet. Firs-ul "Joined" e
    -- decis de DataService, nu de aici -- el e cel care are deja `data` in mana la momentul asta.
    deps.Data.ProfileLoaded:Connect(function(player: Player)
        Net.Get("RiverConfig"):FireClient(player, deps.River.GetConfigFor(player))
        NetServer.PushState(player)
    end)

    Net.Get("RequestState").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "RequestState") then
            return
        end
        Net.Get("RiverConfig"):FireClient(player, deps.River.GetConfigFor(player))
        NetServer.PushState(player)
    end)

    Net.Get("BuyPad").OnServerEvent:Connect(function(player: Player, padId: unknown)
        if not RateLimiter.Allow(player, "BuyPad") or not isValidPadId(padId) then
            return
        end
        local ok, reason = deps.Pads.Buy(player, padId :: string)
        if ok then
            Net.Get("PadBought"):FireClient(player, padId)
        else
            Net.Get("PadRejected"):FireClient(player, padId, reason)
        end
    end)

    Net.Get("CollectNet").OnServerEvent:Connect(function(player: Player, padId: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isValidPadId(padId) then
            return
        end
        -- Un colect care nu incape nicaieri (sack_full) nu are remote de refuz: clientul isi
        -- verifica singur sacul. Nu se trimite nimic pe ramura aia [F0 spec: not spelled out].
        deps.Nets.Collect(player, padId :: string)
    end)

    -- GESTURILE DE PREDARE [D49]. Serverul nu stie unde stai (nici la cules, nici aici): clientul
    -- trage gestul cand esti in raza, serverul verifica doar ca are sens. Rezultatul se intoarce
    -- mereu, reusit sau nu, ca un E apasat sa nu treaca niciodata in tacere [D43].
    Net.Get("UseStorage").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        local ok, reason, n = deps.Economy.UseStorage(player)
        Net.Get("UseResult"):FireClient(player, "storage", ok, reason, n, 0)
    end)
    Net.Get("UseSawmill").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        local ok, reason, dropped, taken = deps.Economy.UseSawmill(player)
        Net.Get("UseResult"):FireClient(player, "sawmill", ok, reason, dropped, taken)
    end)
    -- [D55] shed-ul de scrap si atelierul: aceleasi gesturi, aceeasi limita ca depozitul si gaterul
    Net.Get("UseShed").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        local ok, reason, n = deps.Economy.UseShed(player)
        Net.Get("UseResult"):FireClient(player, "shed", ok, reason, n, 0)
    end)
    Net.Get("UseForge").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        local ok, reason, dropped, taken = deps.Economy.UseForge(player)
        Net.Get("UseResult"):FireClient(player, "forge", ok, reason, dropped, taken)
    end)
    Net.Get("DeliverDock").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        -- `Sold` NU se trage aici: vanzarea vine din scurgerea gramezii, lot cu lot (EconomyService)
        local ok, reason, n = deps.Economy.DeliverDock(player)
        Net.Get("UseResult"):FireClient(player, "dock", ok, reason, n, 0)
    end)
    Net.Get("AtSawmill").OnServerEvent:Connect(function(player: Player, present: unknown)
        if not RateLimiter.Allow(player, "AtSawmill") or typeof(present) ~= "boolean" then
            return
        end
        deps.Economy.SetPresence(player, "sawmill", present :: boolean)
    end)
    -- [D56] forja, ca gaterul: fara Smelter topeste doar cat stai langa ea
    Net.Get("AtForge").OnServerEvent:Connect(function(player: Player, present: unknown)
        if not RateLimiter.Allow(player, "AtForge") or typeof(present) ~= "boolean" then
            return
        end
        deps.Economy.SetPresence(player, "forge", present :: boolean)
    end)
    -- [D65] LOCURILE ORICAREI LINII (FlowConfig). Un loc necunoscut e refuzat fara raspuns, ca orice cerere stricata;
    -- unul cunoscut primeste mereu `UseResult`, reusit sau nu [D43].
    Net.Get("UsePlace").OnServerEvent:Connect(function(player: Player, place: unknown)
        if typeof(place) ~= "string" or #(place :: string) > 24 then
            return
        end
        if not RateLimiter.Allow(player, "UsePlace") then
            return
        end
        local where = place :: string
        if FlowConfig.BY_STORE[where] ~= nil then
            local ok, reason, n = deps.Economy.UseStore(player, where)
            Net.Get("UseResult"):FireClient(player, where, ok, reason, n, 0)
        elseif FlowConfig.BY_PROCESSOR[where] ~= nil then
            local ok, reason, dropped, taken = deps.Economy.UseProcessor(player, where)
            Net.Get("UseResult"):FireClient(player, where, ok, reason, dropped, taken)
        elseif FlowConfig.SELLERS[where] ~= nil then
            -- `Sold` NU se trage aici: vanzarea vine din scurgerea gramezii, lot cu lot (EconomyService)
            local ok, reason, n = deps.Economy.Deliver(player, where)
            Net.Get("UseResult"):FireClient(player, where, ok, reason, n, 0)
        end
    end)
    Net.Get("AtPlace").OnServerEvent
        :Connect(function(player: Player, place: unknown, present: unknown)
            if typeof(place) ~= "string" or typeof(present) ~= "boolean" then
                return
            end
            if
                FlowConfig.BY_PROCESSOR[place :: string] == nil
                or not RateLimiter.Allow(player, "AtPlace")
            then
                return
            end
            deps.Economy.SetPresence(player, place :: string, present :: boolean)
        end)

    -- Revendicarea unei recompense de quest. Serverul verifica el ca e chiar terminata si ca n-a
    -- fost luata deja -- e o tranzactie de moneda, deci n-are ce cauta pe client [D13].
    Net.Get("ClaimQuest").OnServerEvent:Connect(function(player: Player, questId: unknown)
        if not RateLimiter.Allow(player, "BuyPad") then
            return
        end
        if typeof(questId) ~= "string" or #(questId :: string) > 40 then
            return
        end
        local ok, reason, paid = deps.Quests.Claim(player, questId :: string)
        if not ok then
            Net.Get("QuestRejected"):FireClient(player, reason)
        elseif paid ~= nil then
            -- [D62] ce s-a platit, ca perlele sa zboare spre contor si capitolul incheiat sa se vada
            Net.Get("QuestClaimed"):FireClient(player, questId, paid)
        end
    end)

    -- [D54] Nivelul muzicii sau al efectelor, din panoul "Sound": doar o preferinta, dar tot din client,
    -- deci tot validata (fel cunoscut, intreg finit 0..10) si limitata.
    Net.Get("SetAudio").OnServerEvent:Connect(function(player: Player, kind: any, level: any)
        if kind ~= "music" and kind ~= "sound" then
            return
        end
        if not AudioLevels.valid(level) or not RateLimiter.Allow(player, "SetAudio") then
            return
        end
        deps.Data.SetAudioLevel(player, kind, level)
    end)

    -- [D71] Fusul orar al jucatorului, pentru ziua seriei zilnice: numar validat (StreakMath.cleanOffset) si limitat; se
    -- schimba cel mult o data pe zi UTC. Daca a numarat ziua de azi dupa el, starea pleaca din nou.
    Net.Get("SetClock").OnServerEvent:Connect(function(player: Player, offset: any)
        if typeof(offset) ~= "number" or not RateLimiter.Allow(player, "Clock") then
            return
        end
        if deps.Data.SetStreakClock(player, offset) then
            NetServer.PushState(player)
        end
    end)

    -- [D59] UNDITA. Aruncarea nu are argumente: ce e in apa hotaraste serverul. Raspunsul spune doar clipa muscaturii si
    -- bara (dificultatea, samanta) -- nu si pestele.
    Net.Get("Cast").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Fishing") then
            return
        end
        local ok, reason, cast = deps.Fish.Cast(player)
        if ok and cast ~= nil then
            Net.Get("CastResult"):FireClient(
                player,
                cast.castId,
                cast.biteAt,
                cast.kind,
                cast.difficulty,
                cast.reelSeed,
                cast.treasure
            )
        else
            Net.Get("CastResult"):FireClient(player, nil, reason)
        end
    end)
    Net.Get("Land").OnServerEvent:Connect(function(player: Player, castId: unknown)
        if not RateLimiter.Allow(player, "Fishing") or not isInteger(castId) then
            return
        end
        local ok, reason, result, wait = deps.Fish.Land(player, castId :: number)
        Net.Get("LandResult"):FireClient(player, castId, ok, reason, result, wait)
    end)

    -- [D59] AVIZIERUL SATULUI: id-uri scurte, verificate apoi de VillageService fata de VillageConfig.
    local function shopHandler(what: string, act: (Player, string) -> (boolean, string))
        return function(player: Player, id: unknown)
            if not RateLimiter.Allow(player, "Shop") then
                return
            end
            if typeof(id) ~= "string" or #(id :: string) > 24 then
                return
            end
            local ok, reason = act(player, id :: string)
            Net.Get("ShopResult"):FireClient(player, what, id, ok, reason)
        end
    end
    Net.Get("BuyDecor").OnServerEvent:Connect(shopHandler("decor", deps.Village.BuyDecor))
    Net.Get("BuyOutfit").OnServerEvent:Connect(shopHandler("outfit", deps.Village.BuyOutfit))
    Net.Get("WearOutfit").OnServerEvent:Connect(shopHandler("wear", deps.Village.WearOutfit))

    -- [D62, pasul 3] DARURILE RAULUI. Clientul spune care dar (fereastra de timp); serverul il reface din acelasi
    -- program si verifica momentul si ca n-a mai fost scos. Raspunde mereu: clientul a pornit deja zborul spre tine.
    Net.Get("GrabDrift").OnServerEvent:Connect(function(player: Player, giftId: unknown)
        if not RateLimiter.Allow(player, "Drift") then
            return
        end
        if not isInteger(giftId) then
            return
        end
        local ok, reason, kind, coins = deps.Drift.Grab(player, giftId :: number)
        Net.Get("DriftGrabbed"):FireClient(player, giftId, ok, reason, kind, coins)
    end)

    -- [D61, partea 2] COLTUL CU ROBUX. Clientul cere un lucru din catalog; fereastra Roblox o deschide serverul, daca
    -- lucrul exista pe universul asta si are rost acum. Un refuz se spune [D43]; ce ai primit vine tot pe RobuxResult,
    -- dupa plata (PassService / PurchaseService).
    Net.Get("RobuxBuy").OnServerEvent:Connect(function(player: Player, key: unknown)
        if not RateLimiter.Allow(player, "Robux") then
            return
        end
        if typeof(key) ~= "string" or #(key :: string) > 24 then
            return
        end
        local ok, reason = deps.Shop.Prompt(player, key :: string)
        if not ok then
            Net.Get("RobuxResult"):FireClient(player, key, false, reason, 0)
        end
    end)

    -- [D60] BARCA SPRE BALCI. Clientul o cere la capatul drumului pictat; raspunsul e teleportul sau FerryFailed. Si o
    -- cerere refuzata de limita primeste raspuns: clientul sta pe negru si asteapta unul.
    Net.Get("RowUp").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Ferry") then
            Net.Get("FerryFailed"):FireClient(player, "busy")
            return
        end
        deps.Ferry.Depart(player)
    end)

    -- [D70, pasul j15] BARAJUL. Previzualizarea si ridicarea raspund mereu (chitanta sau motivul), si la o cerere refuzata
    -- de limita: ecranul „Build the Dam” asteapta un raspuns [D43].
    Net.Get("DamPreview").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "Dam") then
            Net.Get("DamPreviewResult"):FireClient(player, nil, "busy")
            return
        end
        local receipt, why = deps.Dam.Preview(player)
        Net.Get("DamPreviewResult"):FireClient(player, receipt, why)
    end)
    Net.Get("BuildDam").OnServerEvent:Connect(function(player: Player, expectedKeep: unknown)
        if not RateLimiter.Allow(player, "Dam") then
            Net.Get("DamRejected"):FireClient(player, "busy")
            return
        end
        if typeof(expectedKeep) ~= "number" or not math.isfinite(expectedKeep :: number) then
            Net.Get("DamRejected"):FireClient(player, "changed")
            return
        end
        local receipt, why = deps.Dam.Build(player, expectedKeep :: number)
        if receipt == nil then
            Net.Get("DamRejected"):FireClient(player, why or "changed")
            return
        end
        Net.Get("DamBuilt"):FireClient(player, receipt)
    end)
    Net.Get("DamFilmSeen").OnServerEvent:Connect(function(player: Player)
        if RateLimiter.Allow(player, "Dam") then
            deps.Dam.FilmSeen(player)
        end
    end)

    Net.Get("UpgradeStation").OnServerEvent
        :Connect(function(player: Player, kind: unknown, id: unknown, count: unknown)
            if not RateLimiter.Allow(player, "BuyPad") then
                return
            end
            if typeof(kind) ~= "string" or #(kind :: string) > 16 then
                return
            end
            if id ~= nil and (typeof(id) ~= "string" or #(id :: string) > 40) then
                return
            end
            if not isInteger(count) or (count :: number) < 1 then
                return
            end
            local ok, reason, done =
                deps.Stations.Upgrade(player, kind :: string, id :: string?, count :: number)
            if not ok then
                Net.Get("UpgradeRejected"):FireClient(player, reason)
            elseif done ~= nil then
                -- [D62] reusita se anunta si ea: pana acum un nivel cumparat trecea in tacere [D43]
                Net.Get("StationUpgraded"):FireClient(
                    player,
                    kind,
                    id,
                    done.level,
                    done.count,
                    done.milestone,
                    done.incomeDelta
                )
            end
        end)

    -- O treapta sau al doilea om pe o meserie [D49]. Validarea regulilor e in StationService.UpgradeCrew
    -- (aceleasi reguli ca meniul, din CrewMath); aici doar forma cererii.
    Net.Get("UpgradeCrew").OnServerEvent
        :Connect(function(player: Player, role: unknown, what: unknown)
            if not RateLimiter.Allow(player, "BuyPad") then
                return
            end
            if typeof(role) ~= "string" or #(role :: string) > 16 then
                return
            end
            if what ~= "tier" and what ~= "hire" then
                return
            end
            local ok, reason, done =
                deps.Stations.UpgradeCrew(player, role :: string, what :: string)
            if not ok then
                Net.Get("UpgradeRejected"):FireClient(player, reason)
            elseif done ~= nil then
                Net.Get("CrewUpgraded"):FireClient(player, role, what, done.level, done.incomeDelta)
            end
        end)

    -- Atelierul: neschimbat fata de pasul anterior, doar mutat sub noile deps.
    Net.Get("RequestWorkshop").OnServerEvent:Connect(function(player: Player)
        if RateLimiter.Allow(player, "RequestState") then
            sendWorkshop(player)
        end
    end)
    Net.Get("StartRepair").OnServerEvent
        :Connect(function(player: Player, itemId: unknown, slotIndex: unknown)
            if
                not RateLimiter.Allow(player, "CollectNet")
                or not isInteger(itemId)
                or not isInteger(slotIndex)
            then
                return
            end
            local ok, reason =
                deps.Workshop.StartRepair(player, itemId :: number, slotIndex :: number)
            if not ok then
                Net.Get("WorkshopRejected"):FireClient(player, reason)
            end
            sendWorkshop(player)
        end)
    Net.Get("CollectRepair").OnServerEvent:Connect(function(player: Player, slotIndex: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isInteger(slotIndex) then
            return
        end
        local ok, reason = deps.Workshop.CollectRepair(player, slotIndex :: number)
        if ok then
            Net.Get("RepairDone"):FireClient(player, reason)
        else
            Net.Get("WorkshopRejected"):FireClient(player, reason)
        end
        sendWorkshop(player)
    end)
    Net.Get("ScrapItem").OnServerEvent:Connect(function(player: Player, itemId: unknown)
        if not RateLimiter.Allow(player, "CollectNet") or not isInteger(itemId) then
            return
        end
        local ok, reason = deps.Workshop.ScrapItem(player, itemId :: number)
        if not ok then
            Net.Get("WorkshopRejected"):FireClient(player, reason)
        end
        sendWorkshop(player)
    end)

    Players.PlayerRemoving:Connect(function(player: Player)
        RateLimiter.Forget(player)
        pending[player] = nil
    end)
end

return NetServer
