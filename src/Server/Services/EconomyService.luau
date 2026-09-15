--!strict
-- Moneda jucatorului si drumul marfii [F0 spec 3.2, D49]. Singurul loc care schimba Coins, ca sumele
-- sa nu poata scadea din greseala, si singurul loc care muta marfa intre gramezi:
--
--   plase -> traista / Collector -> DEPOZIT -> traista / Porter -> GATER (taie) -> iesirea gaterului
--         -> traista / Hauler -> DEBARCADER (vinde) -> monede
--   [D55] plasa de scrap -> traista / Collector -> SHED -> traista / Porter -> FORJA ATELIERULUI (topeste)
--         -> fierul -> traista / Hauler -> DEBARCADER
--
-- Serverul nu stie unde sta jucatorul: la cules, la predare si la cumparare decide clientul, iar
-- serverul verifica doar ca gestul are sens (ce ai in traista, ce e in gramada) [D49].
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local CrewMath = require(ReplicatedStorage.Shared.Modules.CrewMath)
local PileMath = require(ReplicatedStorage.Shared.Modules.PileMath)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

type Catch = DataService.Catch

local EconomyService = {}
local deps: {
    Pads: { StateFor: (Player) -> TycoonMath.State },
    Stations: { Income: (Player) -> number }?,
    PushState: ((Player) -> ())?,
    OnSold: ((Player, number, number) -> ())?,
    Now: (() -> number)?,
} =
    {
        Pads = nil :: any,
        Stations = nil,
        PushState = nil,
        OnSold = nil,
        Now = nil,
    }

-- GRAMADA DE LA DEBARCADER. Marfa adusa nu se preface instant in monede: intra intr-o gramada care
-- se scurge cu viteza debarcaderului. Cat timp debarcaderul e peste productie se goleste pe loc;
-- cand ramane in urma, gramada creste si SE VEDE -- asta e semnalul ca veriga slaba e vanzarea.
-- Nicio gramada nu are plafon: marfa nu se pierde niciodata [P2]. Blocajul se vede, nu costa.
local TICK_SECONDS = 0.1 -- acelasi ritm ca NetService
-- CASA DE MARCAT SUNA O SINGURA DATA PE INCARCATURA. Prima varianta anunta la fiecare 0.6s cat
-- timp se scurgea gramada -- pentru o traista de 12 bucati la 1 buc/s ieseau vreo 19 sunete si 19
-- rafale de monede pentru o singura vanzare. Acum anuntul vine cand gramada s-a GOLIT, adica o
-- data pe incarcatura, cu totalul intreg.
-- Supapa: daca gramada nu se goleste niciodata (tarziu in joc, cand oamenii aduc continuu), se
-- anunta oricum la fiecare `SOLD_MAX_GAP` secunde -- altfel n-ar mai suna nimic vreodata.
local SOLD_MAX_GAP = 8
-- ...dar nici mai des de-atat. Tarziu in joc gramada se poate goli la FIECARE tick (10 pe secunda),
-- si atunci "o data pe incarcatura" ar redeveni un bruiaj -- doar din alt motiv.
local SOLD_MIN_GAP = 1.2
local drainCarry: { [Player]: number } = {} -- bucati incepute, sub 1, intre doua tick-uri
-- GATERUL [D48]. Aceeasi idee ca la debarcader: rest fractionar intre tick-uri, ca nicio bucata sa
-- nu se piarda la rotunjire.
local sawCarry: { [Player]: number } = {}
-- CAT DE DES SE TRIMITE STAREA CAT TAIE GATERUL. Clientul nu simuleaza gramezile (le copiaza din
-- TycoonState). Fara trimiteri proprii, gramada gaterului ar sta inghetata si ar sari. 0.5 s e
-- destul de lin pentru ochi si de rar pentru retea.
local SAW_PUSH_GAP = 0.5
local lastSawPushAt: { [Player]: number } = {}
-- [D55] FORJA: acelasi rest fractionar si acelasi ritm de trimitere ca gaterul.
local smeltCarry: { [Player]: number } = {}
local lastSmeltPushAt: { [Player]: number } = {}
local pendingTotal: { [Player]: number } = {}
local pendingCount: { [Player]: number } = {}
local lastSoldAt: { [Player]: number } = {}

-- PREZENTA LA GATER [D49] SI LA FORJA [D56]. Fara Sawyer, gaterul taie doar cat stai langa el; fara Smelter,
-- forja topeste doar cat stai langa ea. Serverul nu stie unde esti, deci clientul spune "sunt aici" la intrarea
-- in raza si apoi la fiecare 2 s; prezenta tine 3 s si expira singura, ca un client care tace (inchis, lag) sa nu
-- taie la nesfarsit. PE LOC: statul la gater nu porneste forja (in D55 prezenta era una singura pe jucator).
EconomyService.PRESENCE_SECONDS = 3
EconomyService.PRESENCE_PLACES = { "sawmill", "forge" }
local presentUntil: { [Player]: { [string]: number } } = {}

local function now(): number
    local nowFn = deps.Now
    return if nowFn ~= nil then nowFn() else os.clock()
end

local function push(player: Player)
    if deps.PushState ~= nil then
        deps.PushState(player)
    end
end

-- Cladirile citite DIRECT din profil. Nu prin StationService: el il cere deja pe EconomyService,
-- deci invers ar fi require circular.
local function levelOf(data: any, kind: string): number
    local stations = data.Stations
    if typeof(stations) == "table" and typeof(stations[kind]) == "table" then
        return stations[kind].level or 1
    end
    return 1
end

local function crewsOf(data: any): { [string]: ChainMath.Crew }
    return CrewMath.fromProfile(data.Hands, data.Crews)
end

local function isPresent(player: Player, place: string, at: number): boolean
    local byPlace = presentUntil[player]
    return byPlace ~= nil and (byPlace[place] or 0) > at
end

function EconomyService.GetPearls(player: Player): number
    local data = DataService.Get(player)
    return if data ~= nil then data.Pearls else 0
end

-- [D59] Singurele doua locuri care schimba perlele: undita, raul, roata si quest-urile adauga prin AddPearls, avizierul
-- satului cheltuie prin TrySpendPearls. Ce vede jucatorul e `floor` -- deci se cheltuie doar din perle intregi.
function EconomyService.AddPearls(player: Player, n: number, _reason: string)
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) or n <= 0 then
        return
    end
    data.Pearls = math.max(0, data.Pearls + n)
end

function EconomyService.TrySpendPearls(player: Player, n: number, _reason: string): boolean
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) or n < 0 then
        return false
    end
    if math.floor(data.Pearls) < n then
        return false
    end
    data.Pearls -= n
    return true
end

function EconomyService.GetCoins(player: Player): number
    local data = DataService.Get(player)
    return if data ~= nil then data.Coins else 0
end

-- Singurul loc care aduna la Coins: clamp la 0, ca o scadere programata gresit sa nu duca la minus.
function EconomyService.AddCoins(player: Player, n: number, _reason: string)
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) then
        return
    end
    data.Coins = math.max(0, data.Coins + n)
end

function EconomyService.TrySpend(player: Player, n: number, _reason: string): boolean
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) or n < 0 then
        return false
    end
    if data.Coins < n then
        return false
    end
    data.Coins -= n
    return true
end

function EconomyService.SellMult(player: Player): number
    local state = deps.Pads.StateFor(player)
    return TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
end

function EconomyService.IncomePerSec(player: Player): number
    local stations = deps.Stations
    return if stations ~= nil then stations.Income(player) else 0
end

-- Valoarea unei liste de prinderi la multiplicatorul curent al lui `player` -- ACELASI calcul pentru
-- traista, pentru ce arata HUD-ul si pentru gramada de la debarcader: un singur loc care stie pretul,
-- ca sa nu poata exista doua preturi pentru acelasi obiect.
function EconomyService.ValueOf(player: Player, items: { Catch }): number
    local state = deps.Pads.StateFor(player)
    local mult = TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
    local total = 0
    for _, catch: Catch in items do
        total += TycoonMath.itemValue(catch.g, catch.t, state) * mult
    end
    return total
end

-- Acelasi pret, pentru o gramada tinuta ca numaratori.
function EconomyService.ValueOfCounts(player: Player, counts: PileMath.Counts): number
    local state = deps.Pads.StateFor(player)
    local mult = TycoonMath.sellMultiplier(state, state.indexFound, state.rebirths)
    local total = 0
    for key, n in counts do
        local item = PileMath.itemOf(key)
        total += TycoonMath.itemValue(item.g, item.t, state) * mult * n
    end
    return total
end

-- Aplica o vanzare DEJA calculata: adauga monedele, tine Stats la zi.
function EconomyService.SettleSale(player: Player, total: number, itemCount: number)
    local data = DataService.Get(player)
    if data == nil or itemCount <= 0 then
        return
    end
    EconomyService.AddCoins(player, total, "sell")
    data.Stats.coinsEarned += total
end

-- ---- traista: brut sau taiat [D49] -----------------------------------------------------------

local function isCut(item: Catch): boolean
    return item.p == true
end

-- [D56] O gasire cu nume, neprelucrata. Colectia e pusa deoparte, deci gasirea n-are drum propriu: merge cu marfa
-- (locul unde lasi lemnul sau scrap-ul o ia si pe ea, iar ea trece neschimbata prin gater sau forja) si se vinde
-- oricand la taverna -- toastul primei gasiri spune "The tavern pays well for it" [D40]. Pana in D56 era "lemn brut":
-- taverna o refuza, iar una prinsa in plasa de scrap ar fi trimis jucatorul cu ea la gater.
local function isFind(item: Catch): boolean
    return item.g == "named" and item.p ~= true
end

-- [D55, D56] Traista pe patru: lemnul brut (si ce a ramas vechi: reeds, shards), scrap-ul brut, gasirile, ce e gata
-- de vandut (scanduri, fier). Scrap-ul are drumul lui: nu intra nici in depozit, nici in gater.
local function split4(items: { Catch }): ({ Catch }, { Catch }, { Catch }, { Catch })
    local logs, scrap, finds, cut = {}, {}, {}, {}
    for _, item in items do
        if isCut(item) then
            table.insert(cut, item)
        elseif isFind(item) then
            table.insert(finds, item)
        elseif item.g == "scrap" then
            table.insert(scrap, item)
        else
            table.insert(logs, item)
        end
    end
    return logs, scrap, finds, cut
end

local function joined(a: { Catch }, b: { Catch }): { Catch }
    local out = table.clone(a)
    table.move(b, 1, #b, #out + 1, out)
    return out
end

function EconomyService.SackSnapshot(player: Player): {
    count: number,
    capacity: number,
    value: number,
    contents: { [string]: number },
    raw: number,
    rawScrap: number,
    finds: number,
    cut: number,
    cutValue: number,
}
    local data = DataService.Get(player)
    local state = deps.Pads.StateFor(player)
    if data == nil then
        return {
            count = 0,
            capacity = TycoonMath.sackCapacity(state),
            value = 0,
            contents = {},
            raw = 0,
            rawScrap = 0,
            finds = 0,
            cut = 0,
            cutValue = 0,
        }
    end
    -- CE duce jucatorul, nu doar cat: gramezile se deseneaza pe feluri, deci si traista.
    local contents: { [string]: number } = {}
    local logs, scrap, finds, cut = split4(data.Sack.items)
    for _, item: Catch in data.Sack.items do
        contents[item.g] = (contents[item.g] or 0) + 1
    end
    local sellable = joined(cut, finds)
    return {
        count = #data.Sack.items,
        capacity = TycoonMath.sackCapacity(state),
        value = EconomyService.ValueOf(player, data.Sack.items),
        contents = contents,
        -- [D55] `raw` = lemnul brut (merge la depozit / gater), `rawScrap` = scrap-ul brut (forja)
        raw = #logs,
        rawScrap = #scrap,
        finds = #finds, -- [D56] gasirile neprelucrate: se vand si asa
        -- tot ce cumpara taverna acum (scanduri, fier, gasiri)
        cut = #sellable,
        -- doar ce se poate vinde acum: pastila de la debarcader nu promite bani pe busteni bruti [D40]
        cutValue = EconomyService.ValueOf(player, sellable),
    }
end

-- E LA DEPOZIT: lasi tot lemnul brut din traista; daca n-ai, iei brut din depozit cat incape.
-- Intoarce (ok, ce s-a intamplat, cate bucati). Motivele refuzului le traduce clientul in toast. [D55]
-- Scrap-ul ramane in traista: locul lui e forja [D56], si refuzul o spune ("scrap_to_forge").
function EconomyService.UseStorage(player: Player): (boolean, string, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0
    end
    local logs, scrap, finds, cut = split4(data.Sack.items)
    if #logs > 0 then
        local dropped = joined(logs, finds) -- [D56] gasirile merg cu lemnul
        PileMath.addItems(data.StoragePile.counts, dropped)
        data.Sack.items = joined(scrap, cut)
        push(player)
        return true, "dropped", #dropped
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    if room <= 0 then
        return false, if #scrap > 0 then "scrap_to_forge" else "sack_full", 0
    end
    local taken = PileMath.take(data.StoragePile.counts, room)
    if #taken == 0 then
        return false, if #scrap > 0 then "scrap_to_forge" else "storage_empty", 0
    end
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    push(player)
    return true, "took", #taken
end

-- E LA GATER, un singur gest: lasi lemnul brut, apoi iei ce e taiat cat incape.
-- Intoarce (ok, motiv, cate ai lasat, cate ai luat). [D55] Scrap-ul nu se taie: ramane in traista.
function EconomyService.UseSawmill(player: Player): (boolean, string, number, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0, 0
    end
    local logs, scrap, finds, cut = split4(data.Sack.items)
    local dropped: { Catch } = {}
    if #logs > 0 then
        dropped = joined(logs, finds) -- [D56] gasirile merg cu lemnul si trec neschimbate
        PileMath.addItems(data.SawmillPile.counts, dropped)
        data.Sack.items = joined(scrap, cut)
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    local taken = if room > 0 then PileMath.take(data.PlanksPile.counts, room, true) else {}
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    if #dropped == 0 and #taken == 0 then
        local reason = if room <= 0
            then "sack_full"
            elseif #scrap > 0 then "scrap_to_forge"
            else "nothing_cut"
        return false, reason, 0, 0
    end
    push(player)
    return true, "ok", #dropped, #taken
end

-- [D55] E LA SHED-UL DE SCRAP: lasi scrap-ul brut din traista; daca n-ai, iei scrap cat incape.
-- Intoarce (ok, ce s-a intamplat, cate bucati), ca la depozit.
function EconomyService.UseShed(player: Player): (boolean, string, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0
    end
    if data.Pads.scrap_shed ~= true then
        return false, "no_shed", 0
    end
    local logs, scrap, finds, cut = split4(data.Sack.items)
    if #scrap > 0 then
        local dropped = joined(scrap, finds) -- [D56] gasirile merg cu scrap-ul
        PileMath.addItems(data.ScrapPile.counts, dropped)
        data.Sack.items = joined(logs, cut)
        push(player)
        return true, "dropped", #dropped
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    if room <= 0 then
        return false, "sack_full", 0
    end
    local taken = PileMath.take(data.ScrapPile.counts, room)
    if #taken == 0 then
        return false, "shed_empty", 0
    end
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    push(player)
    return true, "took", #taken
end

-- [D55] E LA ATELIER, un singur gest ca la gater: lasi scrap-ul la forja, apoi iei fierul gata cat incape.
-- Intoarce (ok, motiv, cate ai lasat, cate ai luat).
function EconomyService.UseForge(player: Player): (boolean, string, number, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0, 0
    end
    if data.Pads.workshop ~= true then
        return false, "no_workshop", 0, 0
    end
    local logs, scrap, finds, cut = split4(data.Sack.items)
    local dropped: { Catch } = {}
    if #scrap > 0 then
        dropped = joined(scrap, finds) -- [D56] gasirile merg cu scrap-ul si trec neschimbate
        PileMath.addItems(data.ForgePile.counts, dropped)
        data.Sack.items = joined(logs, cut)
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    local taken = if room > 0 then PileMath.take(data.IronPile.counts, room, true) else {}
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    if #dropped == 0 and #taken == 0 then
        return false, if room <= 0 then "sack_full" else "nothing_smelted", 0, 0
    end
    push(player)
    return true, "ok", #dropped, #taken
end

-- [D56] Cate bucati de fier sunt intr-o mana de marfa (pentru `Stats.ironSold`).
local function countIron(items: { Catch }): number
    local n = 0
    for _, item in items do
        if item.g == "iron" then
            n += 1
        end
    end
    return n
end

-- E LA TAVERNA: lasi ce e taiat (si gasirile [D56]). Brutul ramane in traista -- taverna cumpara doar marfa trecuta
-- prin gater sau forja. `Stats.sold` numara BUCATILE predate (quest-urile "Sell the planks"), `Stats.sells` gesturile.
function EconomyService.DeliverDock(player: Player): (boolean, string, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0
    end
    local logs, scrap, finds, cut = split4(data.Sack.items)
    local sold = joined(cut, finds)
    if #sold == 0 then
        return false, if #logs + #scrap > 0 then "raw_only" else "empty", 0
    end
    PileMath.addItems(data.DockPile.counts, sold)
    data.Sack.items = joined(logs, scrap)
    data.Stats.sells += 1
    data.Stats.sold = (data.Stats.sold or 0) + #sold
    data.Stats.ironSold = (data.Stats.ironSold or 0) + countIron(sold) -- [D56] "Sell the iron at the tavern"
    push(player)
    return true, "delivered", #sold
end

-- ---- oamenii [D49] --------------------------------------------------------------------------

-- Un om lasa ce duce: Collector-ul la depozit, Porter-ul la gater, Hauler-ul la taverna; [D56] Scrap Collector-ul
-- la shed, Scrap Porter-ul la forja, Iron Hauler-ul la taverna.
function EconomyService.DropAt(player: Player, place: string, items: { Catch }): number
    local data = DataService.Get(player)
    if data == nil or #items == 0 then
        return 0
    end
    if place == "storage" then
        PileMath.addItems(data.StoragePile.counts, items)
    elseif place == "shed" then
        PileMath.addItems(data.ScrapPile.counts, items)
    elseif place == "sawmill" then
        PileMath.addItems(data.SawmillPile.counts, items)
    elseif place == "forge" then
        PileMath.addItems(data.ForgePile.counts, items)
    elseif place == "dock" then
        PileMath.addItems(data.DockPile.counts, items)
        data.Stats.sells += 1
        data.Stats.sold = (data.Stats.sold or 0) + #items
        data.Stats.ironSold = (data.Stats.ironSold or 0) + countIron(items)
    else
        return 0
    end
    push(player)
    return #items
end

-- Un om ia cel mult `n` bucati: Porter-ul din depozit, Hauler-ul de la iesirea gaterului.
function EconomyService.TakeFrom(player: Player, place: string, n: number): { Catch }
    local data = DataService.Get(player)
    if data == nil or n < 1 then
        return {}
    end
    if place == "storage" then
        return PileMath.take(data.StoragePile.counts, n)
    elseif place == "shed" then
        return PileMath.take(data.ScrapPile.counts, n)
    elseif place == "planks" then
        return PileMath.take(data.PlanksPile.counts, n, true)
    elseif place == "iron" then
        return PileMath.take(data.IronPile.counts, n, true)
    end
    return {}
end

function EconomyService.SetPresence(player: Player, place: string, present: boolean)
    if table.find(EconomyService.PRESENCE_PLACES, place) == nil then
        return
    end
    local was = isPresent(player, place, now())
    local byPlace = presentUntil[player]
    if byPlace == nil then
        byPlace = {}
        presentUntil[player] = byPlace
    end
    if present then
        byPlace[place] = now() + EconomyService.PRESENCE_SECONDS
    else
        byPlace[place] = nil
    end
    -- doar la schimbare: clientul trebuie sa vada ca taie (sau ca s-a oprit) fara sa astepte un lot
    if was ~= present then
        push(player)
    end
end

-- ---- instantaneele ---------------------------------------------------------------------------

function EconomyService.StorageSnapshot(
    player: Player
): { count: number, contents: { [string]: number } }
    local data = DataService.Get(player)
    if data == nil then
        return { count = 0, contents = {} }
    end
    return {
        count = PileMath.total(data.StoragePile.counts),
        contents = PileMath.contents(data.StoragePile.counts),
    }
end

-- Gaterul are DOUA gramezi: ce asteapta taiat (`count`, la intrare) si ce a iesit (`out`). `rate` e
-- cat taie ACUM (0 fara Sawyer si fara tine), `present` daca stai langa el.
function EconomyService.SawmillSnapshot(player: Player): {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
    present: boolean,
    staffed: boolean,
}
    local data = DataService.Get(player)
    if data == nil then
        return {
            count = 0,
            contents = {},
            out = 0,
            outContents = {},
            rate = 0,
            present = false,
            staffed = false,
        }
    end
    local crews = crewsOf(data)
    local present = isPresent(player, "sawmill", now())
    return {
        count = PileMath.total(data.SawmillPile.counts),
        contents = PileMath.contents(data.SawmillPile.counts),
        out = PileMath.total(data.PlanksPile.counts),
        outContents = PileMath.contents(data.PlanksPile.counts),
        rate = ChainMath.sawSpeed(levelOf(data, "saw"), crews.sawyer, present),
        present = present,
        staffed = crews.sawyer.count > 0,
    }
end

-- [D55] Shed-ul de scrap: cat asteapta acolo.
function EconomyService.ShedSnapshot(
    player: Player
): { count: number, contents: { [string]: number } }
    local data = DataService.Get(player)
    if data == nil then
        return { count = 0, contents = {} }
    end
    return {
        count = PileMath.total(data.ScrapPile.counts),
        contents = PileMath.contents(data.ScrapPile.counts),
    }
end

-- [D55] Forja: scrap-ul care asteapta (`count`), fierul iesit (`out`) si cat topeste ACUM. [D56] Ca la gater:
-- `present` daca stai langa ea, `staffed` daca are Smelter.
function EconomyService.ForgeSnapshot(player: Player): {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
    present: boolean,
    staffed: boolean,
}
    local data = DataService.Get(player)
    if data == nil then
        return {
            count = 0,
            contents = {},
            out = 0,
            outContents = {},
            rate = 0,
            present = false,
            staffed = false,
        }
    end
    local crews = crewsOf(data)
    local present = isPresent(player, "forge", now())
    local waiting = PileMath.total(data.ForgePile.counts)
    return {
        count = waiting,
        contents = PileMath.contents(data.ForgePile.counts),
        out = PileMath.total(data.IronPile.counts),
        outContents = PileMath.contents(data.IronPile.counts),
        rate = if waiting > 0 and data.Pads.workshop == true
            then ChainMath.forgeSpeed(levelOf(data, "forge"), crews.smelter, present)
            else 0,
        present = present,
        staffed = crews.smelter.count > 0,
    }
end

function EconomyService.DockSnapshot(player: Player): {
    count: number,
    value: number,
    rate: number,
    contents: { [string]: number },
}
    local data = DataService.Get(player)
    if data == nil then
        return { count = 0, value = 0, rate = 0, contents = {} }
    end
    return {
        count = PileMath.total(data.DockPile.counts),
        value = EconomyService.ValueOfCounts(player, data.DockPile.counts),
        rate = ChainMath.dockSpeed(levelOf(data, "dock"), crewsOf(data).trader),
        contents = PileMath.contents(data.DockPile.counts),
    }
end

-- ---- ticurile --------------------------------------------------------------------------------

-- O taietura: cate bucati apuca gaterul in `dt` secunde. Bustenii ies scanduri, restul trece
-- neschimbat, si totul ajunge la iesirea gaterului -- de acolo il duce cineva la debarcader [D49].
local function saw(player: Player, dt: number, at: number)
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    local pile = data.SawmillPile.counts
    local waiting = PileMath.total(pile)
    local speed = if waiting > 0
        then ChainMath.sawSpeed(
            levelOf(data, "saw"),
            crewsOf(data).sawyer,
            isPresent(player, "sawmill", at)
        )
        else 0
    if speed <= 0 then
        -- gater gol sau oprit: nu se aduna "taieturi" pentru o marfa care nu se taie acum
        sawCarry[player] = 0
        return
    end
    local carried = (sawCarry[player] or 0) + speed * dt
    local whole = math.floor(carried)
    sawCarry[player] = carried - whole
    if whole <= 0 then
        return
    end
    local items = PileMath.take(pile, whole)
    for _, item in items do
        if item.g == "driftwood" then
            item.g = "planks"
        end
        PileMath.add(data.PlanksPile.counts, item)
    end
    data.SawmillPile.sawnAt = at
    data.Stats.sawn += #items
    if not data.Firsts.FirstCut then
        data.Firsts.FirstCut = true
        Analytics.Funnel(player, "FirstCut")
    end

    local emptied = PileMath.total(pile) == 0
    if emptied or at - (lastSawPushAt[player] or 0) >= SAW_PUSH_GAP then
        lastSawPushAt[player] = at
        push(player)
    end
end

-- [D55] O topitura: cate bucati de scrap apuca forja in `dt` secunde. Scrap-ul iese fier; orice altceva (gasirile
-- venite cu scrap-ul) trece neschimbat, ca la gater -- nimic nu se pierde. [D56] Cu Smelter tot timpul, fara el doar
-- cat stai langa forja.
local function smelt(player: Player, dt: number, at: number)
    local data = DataService.Get(player)
    if data == nil or data.ForgePile == nil then
        return
    end
    local pile = data.ForgePile.counts
    local waiting = PileMath.total(pile)
    local speed = if waiting > 0 and data.Pads.workshop == true
        then ChainMath.forgeSpeed(
            levelOf(data, "forge"),
            crewsOf(data).smelter,
            isPresent(player, "forge", at)
        )
        else 0
    if speed <= 0 then
        smeltCarry[player] = 0
        return
    end
    local carried = (smeltCarry[player] or 0) + speed * dt
    local whole = math.floor(carried)
    smeltCarry[player] = carried - whole
    if whole <= 0 then
        return
    end
    local items = PileMath.take(pile, whole)
    for _, item in items do
        if item.g == "scrap" then
            item.g = "iron"
        end
        PileMath.add(data.IronPile.counts, item)
    end
    data.ForgePile.smeltedAt = at
    data.Stats.smelted = (data.Stats.smelted or 0) + #items
    local emptied = PileMath.total(pile) == 0
    if emptied or at - (lastSmeltPushAt[player] or 0) >= SAW_PUSH_GAP then
        lastSmeltPushAt[player] = at
        push(player)
    end
end

-- O scurgere: cate bucati apuca debarcaderul in `dt` secunde. Restul sub 1 se pastreaza pentru
-- tick-ul urmator, deci nicio bucata nu se pierde la rotunjire.
local function drain(player: Player, dt: number, at: number)
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    local pile = data.DockPile.counts
    local carried = (drainCarry[player] or 0)
        + ChainMath.dockSpeed(levelOf(data, "dock"), crewsOf(data).trader) * dt
    local whole = math.floor(carried)
    drainCarry[player] = carried - whole
    if whole <= 0 or next(pile) == nil then
        return
    end
    local batch = PileMath.take(pile, whole)
    local n = #batch
    local total = EconomyService.ValueOf(player, batch)
    EconomyService.SettleSale(player, total, n)
    pendingTotal[player] = (pendingTotal[player] or 0) + total
    pendingCount[player] = (pendingCount[player] or 0) + n
    data.DockPile.drainedAt = at

    -- monedele intra CONTINUU (contorul urca lin, asta e bine); doar ANUNTUL se aduna
    local sinceLast = at - (lastSoldAt[player] or 0)
    local emptied = next(pile) == nil
    local announce = (emptied and sinceLast >= SOLD_MIN_GAP) or sinceLast >= SOLD_MAX_GAP
    if announce and (pendingCount[player] or 0) > 0 then
        lastSoldAt[player] = at
        -- "First sale. The river pays." -- odata cu PRIMII bani, nu la predare [D40, D48].
        if not data.Firsts.FirstSell then
            data.Firsts.FirstSell = true
            Analytics.Funnel(player, "FirstSell")
        end
        local onSold = deps.OnSold
        if onSold ~= nil then
            onSold(player, pendingTotal[player], pendingCount[player])
        end
        pendingTotal[player] = 0
        pendingCount[player] = 0
        push(player)
    end
end

-- ---- unelte de dezvoltare -----------------------------------------------------------------

-- Umple sacul cu driftwood, ca sa se poata testa "sack full"/predarea fara sa astepti raul.
function EconomyService.DevFillSack(player: Player): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local capacity = TycoonMath.sackCapacity(deps.Pads.StateFor(player))
    local added = 0
    while #data.Sack.items < capacity do
        table.insert(data.Sack.items, { g = "driftwood" })
        added += 1
    end
    push(player)
    return added
end

-- Pune `n` busteni (sau scanduri, la iesirea gaterului si la debarcader) direct intr-o gramada, ca
-- gatuirea ei sa se poata vedea in Studio fara zece drumuri. Intoarce cate a pus, sau 0.
function EconomyService.DevFillPile(player: Player, place: string, n: number): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local count = math.clamp(math.floor(n), 1, 5000)
    local piles = {
        storage = { data.StoragePile.counts, "driftwood" },
        sawmill = { data.SawmillPile.counts, "driftwood" },
        planks = { data.PlanksPile.counts, "planks" },
        dock = { data.DockPile.counts, "planks" },
        -- [D55] lantul resturilor
        shed = { data.ScrapPile.counts, "scrap" },
        forge = { data.ForgePile.counts, "scrap" },
        iron = { data.IronPile.counts, "iron" },
    }
    local target = piles[place]
    if target == nil then
        return 0
    end
    PileMath.add(target[1], { g = target[2] }, count)
    push(player)
    return count
end

function EconomyService.Init(d: typeof(deps))
    deps = d
    local acc = 0
    RunService.Heartbeat:Connect(function(dt: number)
        acc += dt
        if acc < TICK_SECONDS then
            return
        end
        local step = acc
        acc = 0
        local at = now()
        for _, player in Players:GetPlayers() do
            saw(player, step, at) -- intai gaterul
            smelt(player, step, at) -- [D55] apoi forja
            drain(player, step, at)
            -- prezenta a expirat intre doua semnale: clientul trebuie sa vada ca gaterul (sau forja) s-a oprit
            local byPlace = presentUntil[player]
            if byPlace ~= nil then
                local expired = false
                for place, until_ in byPlace do
                    if until_ <= at then
                        byPlace[place] = nil
                        expired = true
                    end
                end
                if expired then
                    push(player)
                end
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        drainCarry[player] = nil
        sawCarry[player] = nil
        lastSawPushAt[player] = nil
        smeltCarry[player] = nil
        lastSmeltPushAt[player] = nil
        pendingTotal[player] = nil
        pendingCount[player] = nil
        lastSoldAt[player] = nil
        presentUntil[player] = nil
    end)
end

return EconomyService
