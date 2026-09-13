--!strict
-- Platformele: cumparare, statusuri (bought/available/outline), starea tycoon cache-uita per
-- jucator [F0 spec 3.3]. StateFor e cel mai apelat lucru din tot server-ul (income, sell, net
-- interval) -- de-aici cache-ul, invalidat doar cand se schimba `Pads`/`Rebirths`/`Index`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RiverService = require(script.Parent.RiverService)
local Analytics = require(script.Parent.Analytics)

local PadService = {}
-- Hands: legatura catre HandService, pentru platformele de meserie -- ingusta si optionala, ca sa nu
-- fie nevoie de un require incrucisat (PadService <-> HandService) [F1 spec 3.4, CLAUDE.md "fara
-- require incrucisat intre servicii"]. HandService o cere pe a NOASTRA (StateFor); noi nu-l cerem
-- deloc, doar primim aici, prin Init, functia de care avem nevoie.
local deps: {
    PushState: ((Player) -> ())?,
    Hands: { Hire: (Player, string) -> boolean }?,
    -- delte si veriga slaba vin din lant; primite prin deps, nu cerute cu require (cerc)
    Stations: {
        Deltas: (Player, { string }) -> ({ [string]: number }, string),
        OnPadBought: (Player, string) -> (),
        Invalidate: (Player) -> (),
        Lanes: (Player) -> number,
        Interval: (Player, string) -> number,
        -- nivelul fiecarei plase detinute: plasa urmatoare apare abia cand cea dinainte e la
        -- TycoonConfig.PREV_NET_LEVEL, deci statusurile au nevoie de el
        NetLevels: (Player) -> { [string]: number },
    }?,
} =
    { PushState = nil, Hands = nil, Stations = nil }
local cache: { [Player]: TycoonMath.State } = {}

-- Rata/banda plasei acestei platforme, daca are una. Aceeasi oglinda mica exista si in
-- NetService: e date pure pe `Pad.effects`, nu merita un modul doar pentru atat.
local function netEffectOf(pad: TycoonConfig.Pad): (number?, number?)
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate, e.lane
        end
    end
    return nil, nil
end

local function indexCount(data: DataService.ProfileData): number
    local n = 0
    for _ in data.Index do
        n += 1
    end
    return n
end

function PadService.Invalidate(player: Player)
    cache[player] = nil
end

function PadService.StateFor(player: Player): TycoonMath.State
    local cached = cache[player]
    if cached ~= nil then
        return cached
    end
    local data = DataService.Get(player)
    if data == nil then
        return TycoonMath.newState(0, 0)
    end
    -- live=true: Indexul REAL (indexCount) inlocuieste proxy-ul din efectele platformelor
    -- (Workshop, Sorting Shed) -- niciuna live in F0, dar regula trebuie sa fie corecta oricum.
    local state = TycoonMath.stateFor(data.Pads, data.Rebirths, indexCount(data), true)
    cache[player] = state
    return state
end

-- Getter ingust pentru NetServer (D2 pe client: TycoonMath.pickGood are nevoie de numarul de
-- benzi) -- nu-i trebuie tot TycoonMath.State, doar atat [F1 spec 2.1].
-- Benzile atinse decid ce marfuri exista. Vin din LANT, nu din efectele platformelor: pragul de
-- nivel 10 al unei plase o duce cu o banda mai in larg, deci banda se poate schimba fara sa fi
-- cumparat nimic nou.
function PadService.Lanes(player: Player): number
    local stations = deps.Stations
    return if stations ~= nil then (stations :: any).Lanes(player) else 1
end

-- Cat venit/s adauga fiecare platforma NEcumparata, calculat exact cu aceeasi matematica din care
-- traieste economia -- cartonasul de la apropiere arata cifra adevarata, nu o estimare scrisa de
-- mana [F2 polish, D40: textul nu minte]. Doar pentru platformele vizibile: 2-3 la un moment dat.
-- Cat adauga la venit fiecare platforma inca necumparata, plus CARE e veriga slaba acum. Calculul
-- e in StationService, pe acelasi lant din care iese venitul real -- ca sa nu poata exista doua
-- raspunsuri la "cat imi da asta" [D40].
function PadService.Deltas(player: Player): ({ [string]: number }, string)
    local data = DataService.Get(player)
    if data == nil or deps.Stations == nil then
        return {}, "nets"
    end
    local ids: { string } = {}
    for padId, status in PadService.Statuses(player) do
        if status ~= "bought" then
            table.insert(ids, padId)
        end
    end
    return (deps.Stations :: any).Deltas(player, ids)
end

-- UN SINGUR loc care decide ce se poate cumpara: Buy, Deltas si ce vede clientul trec toate pe
-- aici. Daca Deltas si-ar calcula singur statusurile, ar putea anunta "+1.4/s" pentru o plasa pe
-- care Buy o refuza, pentru ca cea dinainte n-a ajuns inca la nivelul cerut.
function PadService.Statuses(player: Player): { [string]: string }
    local data = DataService.Get(player)
    if data == nil then
        return {}
    end
    local stations = deps.Stations
    local levels = if stations ~= nil then stations.NetLevels(player) else nil
    return TycoonMath.padStatuses(data.Pads, nil, levels)
end

local function pushState(player: Player)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
end

-- Marcheaza platforma cumparata si creeaza plasa daca are efect de plasa. Comuna intre Buy
-- (plateste) si DevGrant (unealta de dezvoltare, gratuit) -- restul logicii nu are voie sa se
-- dezalinieze intre ele.
local function grant(player: Player, data: DataService.ProfileData, pad: TycoonConfig.Pad)
    data.Pads[pad.id] = true
    data.Stats.padsBought += 1
    PadService.Invalidate(player)
    -- SI cache-ul lantului, nu doar al nostru. Fara linia asta, `Interval` de mai jos citea o stare
    -- construita INAINTE de cumparare: plasa noua nu exista in ea, rata iesea 0, intervalul 1e9
    -- secunde, si plasa nu prindea NICIODATA nimic. Tot aici i se creeaza nivelul 1.
    local stations = deps.Stations
    if stations ~= nil then
        stations.OnPadBought(player, pad.id)
    end
    local rate = netEffectOf(pad)
    if rate ~= nil then
        data.Nets[pad.id] = {
            goods = {},
            nextCatchAt = RiverService.Now() + (deps.Stations :: any).Interval(player, pad.id),
            caught = 0,
        }
    end
    -- O platforma de meserie aduce primul om al meseriei [D49] -- delegat: HandService stie numele,
    -- infatisarea si drumul lui; PadService doar anunta ce s-a cumparat. Legatura platforma -> meserie
    -- sta intr-un singur loc (TycoonConfig.CREWS), nu in cate o ramura pe id.
    local role = TycoonConfig.CREW_OF_PAD[pad.id]
    if role ~= nil and deps.Hands ~= nil then
        deps.Hands.Hire(player, role)
    end
    -- INCA O DATA la final: omul de mai sus schimba `data.Hands`, care intra in lant. Azi nimeni nu
    -- citeste starea intre ele si aici, deci ar merge si fara -- dar ordinea asta e exact felul de
    -- lucru care se strica la urmatoarea linie adaugata in mijloc.
    if stations ~= nil then
        stations.Invalidate(player)
    end
end

function PadService.Buy(player: Player, padId: string): (boolean, string?)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local pad = TycoonConfig.byId[padId]
    if pad == nil then
        return false, "locked"
    end
    if data.Pads[padId] then
        return false, "owned"
    end
    if PadService.Statuses(player)[padId] ~= "available" then
        return false, "locked"
    end
    if not EconomyService.TrySpend(player, pad.price, `buy_{padId}`) then
        return false, "coins"
    end
    grant(player, data, pad)
    -- Pas de funnel pentru fiecare platforma a Erei 1, in ordine [F1 spec 3.6]. Buy() ruleaza o
    -- SINGURA data per platforma (verificarea "owned" mai sus in aceasta functie), deci nu mai
    -- trebuie un steag separat per platforma doar ca sa nu se logheze de doua ori.
    if pad.era == 1 then
        -- Numele vine din index, nu din ce platforma a fost odata acolo: dupa reordonarea D52,
        -- indexul 2 e Collector-ul, iar un "BoughtSecondNet" ar fi mintit in rapoarte.
        local stepName = if pad.index == 1 then "BoughtFirstNet" else `BoughtPad{pad.index}`
        Analytics.Funnel(player, stepName)
    end
    pushState(player)
    return true, nil
end

-- UNEALTA DE DEZVOLTARE (buyto): acorda o platforma gratis. Fara analytics -- nu e o cumparare reala.
function PadService.DevGrant(player: Player, padId: string): boolean
    local data = DataService.Get(player)
    if data == nil then
        return false
    end
    local pad = TycoonConfig.byId[padId]
    if pad == nil or data.Pads[padId] then
        return false
    end
    grant(player, data, pad)
    pushState(player)
    return true
end

Players.PlayerRemoving:Connect(function(player: Player)
    cache[player] = nil
end)

function PadService.Init(d: typeof(deps))
    deps = d
    DataService.ProfileLoaded:Connect(function(player: Player)
        PadService.Invalidate(player)
    end)
end

return PadService
