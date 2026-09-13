--!strict
-- Handlere de remote: valideaza input-ul (tip, isfinite, rate limit), apoi apeleaza Service-urile
-- [F0 spec 3.5]. Fara require-uri de servicii aici (doar Net/RateLimiter/TycoonConfig, module
-- fara stare de joc) -- totul altceva vine prin Init(deps), cablat de Bootstrap.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Net.Net)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local RateLimiter = require(script.Parent.RateLimiter)

export type Deps = {
    River: { GetConfigFor: (Player) -> { [string]: any }, Now: () -> number },
    -- Firsts: DOAR cele trei care nu se pot deduce din pads (collect/sell/named se repeta, deci
    -- au nevoie de un steag persistent) [F1 spec 2.1].
    Data: {
        ProfileLoaded: RBXScriptSignal,
        Firsts: (Player) -> { collect: boolean, sell: boolean, named: boolean },
        MusicOn: (Player) -> boolean,
        SetMusic: (Player, boolean) -> (),
    },
    Pads: {
        Buy: (Player, string) -> (boolean, string?),
        Statuses: (Player) -> { [string]: string },
        Deltas: (Player) -> ({ [string]: number }, string),
        Lanes: (Player) -> number,
    },
    Stations: {
        Snapshot: (Player) -> { [string]: any },
        Upgrade: (Player, string, string?, number) -> (boolean, string),
        UpgradeCrew: (Player, string, string) -> (boolean, string),
    },
    Quests: {
        Snapshot: (Player) -> { [string]: any }?,
        Claim: (Player, string) -> (boolean, string),
    },
    Wheel: {
        Snapshot: (Player) -> { [string]: any },
        Spin: (Player) -> (boolean, string, string?, number?, number?),
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
        UseStorage: (Player) -> (boolean, string, number),
        UseSawmill: (Player) -> (boolean, string, number, number),
        DeliverDock: (Player) -> (boolean, string, number),
        SetPresence: (Player, boolean) -> (),
    },
    Workshop: {
        Snapshot: (Player) -> { [string]: any },
        StartRepair: (Player, number, number) -> (boolean, string),
        CollectRepair: (Player, number) -> (boolean, string),
        ScrapItem: (Player, number) -> (boolean, string),
        PileCount: (Player) -> number,
    },
    Hands: { Snapshot: (Player) -> { any } },
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
local function buildTycoonState(player: Player): { [string]: any }
    local pads = deps.Pads.Statuses(player)
    local padDeltas, bottleneck = deps.Pads.Deltas(player)
    local firsts = deps.Data.Firsts(player)
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
        -- statiile cu niveluri: randurile panoului, veriga slaba si cele trei debite
        stations = deps.Stations.Snapshot(player),
        -- capitolul curent, lista de quest-uri si quest-ul activ (unicul obiectiv de ghidaj)
        quests = deps.Quests.Snapshot(player),
        wheel = deps.Wheel.Snapshot(player),
        lanes = deps.Pads.Lanes(player), -- pentru TycoonMath.pickGood pe client [D2]
        -- cat adauga la venit/s fiecare platforma inca necumparata, pentru cartonasul de la apropiere
        padDeltas = padDeltas,
        hands = deps.Hands.Snapshot(player),
        -- Mill se vede mereu (estompata, ingradita) si se deschide cu Landing Bell [B4, C].
        zones = {
            landing = "open",
            mill = if pads.landing_bell == "bought" then "open" else "locked",
        },
        workshop = pads.workshop == "bought",
        pile = deps.Workshop.PileCount(player),
        bottleneck = bottleneck,
        -- runner (= Collector-ul, id-ul vechi al platformei [D49]) / bell: doar "platforma asta e
        -- cumparata" (nu se pierde, deci echivaleaza cu un prim persistent); collect/sell/named sunt
        -- evenimente repetabile, vin din profil.
        firsts = {
            collect = firsts.collect,
            sell = firsts.sell,
            named = firsts.named,
            runner = pads.first_runner == "bought",
            bell = pads.landing_bell == "bought",
        },
        -- [D51] preferintele: muzica pornita sau oprita
        settings = { music = deps.Data.MusicOn(player) },
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
        deps.Economy.SetPresence(player, present :: boolean)
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
        local ok, reason = deps.Quests.Claim(player, questId :: string)
        if not ok then
            Net.Get("QuestRejected"):FireClient(player, reason)
        end
    end)

    -- [D51] Butonul de muzica: doar o preferinta, dar tot din client, deci tot validata si limitata.
    Net.Get("SetMusic").OnServerEvent:Connect(function(player: Player, on: any)
        if type(on) ~= "boolean" or not RateLimiter.Allow(player, "SetMusic") then
            return
        end
        deps.Data.SetMusic(player, on)
    end)

    -- Rotirea zilnica. Tragerea e pe server; clientul primeste premiul si abia apoi il animeaza.
    Net.Get("SpinWheel").OnServerEvent:Connect(function(player: Player)
        if not RateLimiter.Allow(player, "SpinWheel") then
            return
        end
        local ok, reason, prizeId, coins, pearls = deps.Wheel.Spin(player)
        if ok then
            Net.Get("WheelResult"):FireClient(player, prizeId, coins, pearls)
        else
            Net.Get("WheelResult"):FireClient(player, nil, 0, 0, reason)
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
            local ok, reason =
                deps.Stations.Upgrade(player, kind :: string, id :: string?, count :: number)
            if not ok then
                Net.Get("UpgradeRejected"):FireClient(player, reason)
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
            local ok, reason = deps.Stations.UpgradeCrew(player, role :: string, what :: string)
            if not ok then
                Net.Get("UpgradeRejected"):FireClient(player, reason)
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
