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
local FlowConfig = require(ReplicatedStorage.Shared.Config.FlowConfig)
local FlowMath = require(ReplicatedStorage.Shared.Modules.FlowMath)
local PileMath = require(ReplicatedStorage.Shared.Modules.PileMath)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)
local PassMath = require(ReplicatedStorage.Shared.Modules.PassMath)
local WorldMath = require(ReplicatedStorage.Shared.Modules.WorldMath)
local DataService = require(script.Parent.DataService)
local Analytics = require(script.Parent.Analytics)

type Catch = DataService.Catch

local EconomyService = {}
local deps: {
    Pads: { StateFor: (Player) -> TycoonMath.State },
    Stations: { Income: (Player) -> number }?,
    PushState: ((Player) -> ())?,
    OnSold: ((Player, number, number, string) -> ())?, -- [D65] al patrulea: vanzatorul ("dock" | "market")
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
-- [D65] PE VANZATOR SI PE LINIE, nu pe cladire: restul fractionar dintre doua tick-uri (nicio bucata nu se pierde la
-- rotunjire), anuntul vanzarii si clipa ultimei trimiteri de stare. Cheile: `seller` / `line` din FlowConfig.
local drainCarry: { [Player]: { [string]: number } } = {}
local pendingTotal: { [Player]: { [string]: number } } = {}
local pendingCount: { [Player]: { [string]: number } } = {}
local lastSoldAt: { [Player]: { [string]: number } } = {}
-- ATELIERELE [D48, D55, D65]. Aceeasi idee ca la vanzator: rest fractionar intre tick-uri.
local processCarry: { [Player]: { [string]: number } } = {}
-- CAT DE DES SE TRIMITE STAREA CAT LUCREAZA UN ATELIER. Clientul nu simuleaza gramezile (le copiaza din
-- TycoonState). Fara trimiteri proprii, gramada atelierului ar sta inghetata si ar sari. 0.5 s e
-- destul de lin pentru ochi si de rar pentru retea.
local SAW_PUSH_GAP = 0.5
local lastProcessPushAt: { [Player]: { [string]: number } } = {}

local function slot(store: { [Player]: { [string]: number } }, player: Player): { [string]: number }
    local byKey = store[player]
    if byKey == nil then
        byKey = {}
        store[player] = byKey
    end
    return byKey
end

-- PREZENTA LA GATER [D49] SI LA FORJA [D56]. Fara Sawyer, gaterul taie doar cat stai langa el; fara Smelter,
-- forja topeste doar cat stai langa ea. Serverul nu stie unde esti, deci clientul spune "sunt aici" la intrarea
-- in raza si apoi la fiecare 2 s; prezenta tine 3 s si expira singura, ca un client care tace (inchis, lag) sa nu
-- taie la nesfarsit. PE LOC: statul la gater nu porneste forja (in D55 prezenta era una singura pe jucator).
EconomyService.PRESENCE_SECONDS = 3
-- [D65] toate atelierele din FlowConfig: gaterul, forja, turnatoria, cuptorul de cupru
local presencePlaces: { string } = {}
for _, line in StationConfig.LINE_ORDER do
    table.insert(presencePlaces, FlowConfig.LINES[line].processor)
end
EconomyService.PRESENCE_PLACES = presencePlaces
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

-- [D70, pasul j5] monedele cumparate cu Robux inca in mana nu trec niciodata peste monedele pe care le ai (PassMath)
function EconomyService.TrimBought(data: DataService.ProfileData)
    if typeof(data.Purchases) == "table" then
        data.Purchases.coinsBought = PassMath.afterCoins(data.Purchases.coinsBought, data.Coins)
    end
end

-- Singurul loc care aduna la Coins: clamp la 0, ca o scadere programata gresit sa nu duca la minus.
function EconomyService.AddCoins(player: Player, n: number, _reason: string)
    local data = DataService.Get(player)
    if data == nil or not math.isfinite(n) then
        return
    end
    data.Coins = math.max(0, data.Coins + n)
    if n < 0 then
        EconomyService.TrimBought(data)
    end
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
    EconomyService.TrimBought(data)
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
-- [D65] Ce e brut, ce e gasire si ce se vinde unde decide FlowMath, pe liniile din FlowConfig. Pana la D65 erau aici
-- patru functii de gest (UseStorage / UseShed / UseSawmill / UseForge), doua tick-uri (saw / smelt) si cinci
-- instantanee, fiecare scrisa pentru o cladire anume. Numele lor raman, ca invelis pentru locurile Erei 1.

local function pileOf(data: any, field: string): { counts: PileMath.Counts, [string]: any }
    local pile = data[field]
    if typeof(pile) ~= "table" or typeof(pile.counts) ~= "table" then
        -- un profil dinaintea erei careia ii apartine gramada: o primeste aici, goala (migrarea o adauga si ea)
        pile = { counts = {} }
        data[field] = pile
    end
    return pile
end

-- [D70] La o unire (Relay Station): gramada fiecarei piese, pe linia piesei (FlowConfig `inputPiles`). O unire n-are o
-- singura gramada de intrare, deci nimic de aici nu cheama `pileOf(data, spec.inputPile)` pe ea.
local function joinPiles(data: any, spec: FlowConfig.Line): FlowMath.JoinPiles
    local out: FlowMath.JoinPiles = {}
    for part, field in spec.inputPiles :: { [string]: string } do
        out[part] = pileOf(data, field).counts
    end
    return out
end

-- [D70, pasul j13a] O linie sau un vanzator al altei harti e INCHIS: nu lucreaza, nu se scurge, nu se foloseste. Gramezile
-- lui raman in profil (le goleste „Last cart” la ridicarea barajului). In sat, azi, toate liniile din joc sunt ale lui.
local function openFor(data: any, era: number): boolean
    return WorldMath.allowed(data.World, era)
end

local function capacityOf(player: Player): number
    return TycoonMath.sackCapacity(deps.Pads.StateFor(player))
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
    rawBy: { [string]: number },
    sellBy: { [string]: { count: number, value: number } },
    partBy: { [string]: number },
}
    local data = DataService.Get(player)
    local state = deps.Pads.StateFor(player)
    local rawBy: { [string]: number } = {}
    local sellBy: { [string]: { count: number, value: number } } = {}
    -- [D70] piesele gata ale unei uniri (butoaie, cablu), pe unirea lor: nu se vand nicaieri singure si nici nu mai sunt
    -- brute (altfel cardul magaziei ar fi oferit „Drop”, iar ghidajul le-ar fi trimis la atelierul lor)
    local partBy: { [string]: number } = {}
    for _, line in StationConfig.LINE_ORDER do
        rawBy[line] = 0
        if FlowConfig.LINES[line].joins ~= nil then
            partBy[line] = 0
        end
    end
    for _, seller in StationConfig.SELLER_ORDER do
        sellBy[seller] = { count = 0, value = 0 }
    end
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
            rawBy = rawBy,
            sellBy = sellBy,
            partBy = partBy,
        }
    end
    -- CE duce jucatorul, nu doar cat: gramezile se deseneaza pe feluri, deci si traista.
    local contents: { [string]: number } = {}
    local finds = 0
    local bySeller: { [string]: { Catch } } = {}
    for _, item: Catch in data.Sack.items do
        contents[item.g] = (contents[item.g] or 0) + 1
        local seller = FlowMath.sellerOf(item)
        if seller ~= nil then
            bySeller[seller] = bySeller[seller] or {}
            table.insert(bySeller[seller], item)
            if PileMath.isFindGood(item.g) and item.p ~= true then
                finds += 1
            end
        else
            local part = FlowMath.partOf(item)
            if part ~= nil then
                partBy[part] = (partBy[part] or 0) + 1
            else
                local line = FlowMath.lineOfGood(item.g)
                rawBy[line] = (rawBy[line] or 0) + 1
            end
        end
    end
    for seller, items in bySeller do
        sellBy[seller] = { count = #items, value = EconomyService.ValueOf(player, items) }
    end
    return {
        count = #data.Sack.items,
        capacity = TycoonMath.sackCapacity(state),
        value = EconomyService.ValueOf(player, data.Sack.items),
        contents = contents,
        -- [D55] `raw` = lemnul brut (merge la depozit / gater), `rawScrap` = scrap-ul brut (forja). [D65] Vederea Erei 1:
        -- toate liniile sunt in `rawBy`, iar ce cumpara fiecare vanzator acum, in `sellBy`.
        raw = rawBy.wood or 0,
        rawScrap = rawBy.iron or 0,
        finds = finds, -- [D56] gasirile neprelucrate: se vand si asa
        -- tot ce cumpara TAVERNA acum (scanduri, fier, gasiri)
        cut = sellBy.dock.count,
        -- doar ce se poate vinde acum: pastila de la debarcader nu promite bani pe busteni bruti [D40]
        cutValue = sellBy.dock.value,
        rawBy = rawBy,
        sellBy = sellBy,
        partBy = partBy,
    }
end

-- LA MAGAZIA unei linii (`place` = FlowConfig store: "storage", "shed", "millStore", "oreShed"): lasi marfa bruta a
-- liniei; daca n-ai, iei din magazie cat incape. Intoarce (ok, ce s-a intamplat, cate bucati). Motivele refuzului le
-- traduce clientul in toast.
-- [D70, pasul j10] un loc al altei harti nu se foloseste: refuzat cu motiv [D43]
local function closedFor(data: DataService.ProfileData, place: string): boolean
    return not WorldMath.allowed(data.World, WorldMath.eraOfPlace(place))
end

function EconomyService.UseStore(player: Player, place: string): (boolean, string, number)
    local data = DataService.Get(player)
    local spec = FlowConfig.BY_STORE[place]
    if data == nil or spec == nil then
        return false, "no_profile", 0
    end
    if closedFor(data, place) then
        return false, "closed", 0
    end
    if spec.storePad ~= nil and data.Pads[spec.storePad] ~= true then
        return false, spec.noStore, 0
    end
    local ok, what, n = FlowMath.useStore(
        data.Sack.items,
        pileOf(data, spec.storePile).counts,
        capacityOf(player),
        spec
    )
    if ok then
        push(player)
    end
    return ok, what, n
end

-- LA ATELIERUL unei linii (`place` = FlowConfig processor), un singur gest: lasi marfa bruta, apoi iei ce e gata cat
-- incape. Intoarce (ok, motiv, cate ai lasat, cate ai luat).
function EconomyService.UseProcessor(
    player: Player,
    place: string
): (boolean, string, number, number)
    local data = DataService.Get(player)
    local spec = FlowConfig.BY_PROCESSOR[place]
    if data == nil or spec == nil then
        return false, "no_profile", 0, 0
    end
    if closedFor(data, place) then
        return false, "closed", 0, 0
    end
    if spec.processorPad ~= nil and data.Pads[spec.processorPad] ~= true then
        return false, spec.noProcessor, 0, 0
    end
    local ok, why, dropped, taken
    if spec.joins ~= nil then
        -- [D70] la unire: lasi piesele, fiecare in gramada ei, apoi iei ce e unit
        ok, why, dropped, taken = FlowMath.useJoin(
            data.Sack.items,
            joinPiles(data, spec),
            pileOf(data, spec.outputPile).counts,
            capacityOf(player),
            spec
        )
    else
        ok, why, dropped, taken = FlowMath.useProcessor(
            data.Sack.items,
            pileOf(data, spec.inputPile :: string).counts,
            pileOf(data, spec.outputPile).counts,
            capacityOf(player),
            spec
        )
    end
    if ok then
        push(player)
    end
    return ok, why, dropped, taken
end

-- Ce numara o vanzare in Stats: gesturile, bucatile, si bucatile fiecarei linii care are un quest de vanzare.
local function countSale(data: any, items: { Catch })
    data.Stats.sells += 1
    data.Stats.sold = (data.Stats.sold or 0) + #items
    for stat, n in FlowMath.soldStats(items) do
        data.Stats[stat] = (data.Stats[stat] or 0) + n
    end
end

-- LA VANZATOR (`seller` = "dock" | "market"): lasi ce e prelucrat pe liniile lui si gasirile erei lui [D56]. Brutul
-- ramane in traista. `Stats.sold` numara BUCATILE predate (quest-urile "Sell the planks"), `Stats.sells` gesturile.
function EconomyService.Deliver(player: Player, seller: string): (boolean, string, number)
    local data = DataService.Get(player)
    local spec = FlowConfig.SELLERS[seller]
    if data == nil or spec == nil then
        return false, "no_profile", 0
    end
    if closedFor(data, seller) then
        return false, "closed", 0
    end
    local ok, why, sold = FlowMath.deliver(data.Sack.items, pileOf(data, spec.pile).counts, seller)
    if not ok then
        return false, why, 0
    end
    countSale(data, sold)
    push(player)
    return true, why, #sold
end

-- Locurile Erei 1, pe numele lor de dinainte de D65 (remote-urile UseStorage / UseSawmill / UseShed / UseForge /
-- DeliverDock le cheama asa).
function EconomyService.UseStorage(player: Player): (boolean, string, number)
    return EconomyService.UseStore(player, "storage")
end

function EconomyService.UseSawmill(player: Player): (boolean, string, number, number)
    return EconomyService.UseProcessor(player, "sawmill")
end

function EconomyService.UseShed(player: Player): (boolean, string, number)
    return EconomyService.UseStore(player, "shed")
end

function EconomyService.UseForge(player: Player): (boolean, string, number, number)
    return EconomyService.UseProcessor(player, "forge")
end

function EconomyService.DeliverDock(player: Player): (boolean, string, number)
    return EconomyService.Deliver(player, "dock")
end

-- ---- oamenii [D49] --------------------------------------------------------------------------

-- Un om lasa ce duce: cine goleste plasele la magazia liniei lui, cine cara de acolo la atelier, cine cara marfa gata
-- la vanzator. `place` = un loc din FlowConfig (magazie, atelier) sau un vanzator.
-- [D70, pasul j13a] Intoarce (cate a lasat, restul). Restul ramane la om (HandService): la unire, ce nu e piesa ei; la un
-- vanzator, piesele unei uniri (se vand doar unite); la un loc necunoscut, tot. Nimic nu se pierde.
function EconomyService.DropAt(player: Player, place: string, items: { Catch }): (number, { Catch })
    local data = DataService.Get(player)
    if data == nil or #items == 0 then
        return 0, items
    end
    local store, processor, seller =
        FlowConfig.BY_STORE[place], FlowConfig.BY_PROCESSOR[place], FlowConfig.SELLERS[place]
    local placed: { Catch } = items
    local rest: { Catch } = {}
    if store ~= nil then
        PileMath.addItems(pileOf(data, store.storePile :: string).counts, items)
    elseif processor ~= nil and processor.joins ~= nil then
        placed, rest = FlowMath.dropJoin(joinPiles(data, processor), items, processor)
    elseif processor ~= nil then
        PileMath.addItems(pileOf(data, processor.inputPile :: string).counts, items)
    elseif seller ~= nil then
        placed = {}
        for _, item in items do
            table.insert(if FlowMath.partOf(item) == nil then placed else rest, item)
        end
        PileMath.addItems(pileOf(data, seller.pile).counts, placed)
        if #placed > 0 then
            countSale(data, placed)
        end
    else
        return 0, items
    end
    if #placed > 0 then
        push(player)
    end
    return #placed, rest
end

-- Un om ia cel mult `n` bucati: din magazia liniei lui (brut) sau de la iesirea atelierului (gata: "planks", "iron",
-- "parts", "copper").
function EconomyService.TakeFrom(player: Player, place: string, n: number): { Catch }
    local data = DataService.Get(player)
    if data == nil or n < 1 then
        return {}
    end
    local store, output = FlowConfig.BY_STORE[place], FlowConfig.BY_OUTPUT[place]
    if store ~= nil then
        return PileMath.take(pileOf(data, store.storePile).counts, n)
    elseif output ~= nil then
        return PileMath.take(pileOf(data, output.outputPile).counts, n, true)
    end
    return {}
end

function EconomyService.SetPresence(player: Player, place: string, present: boolean)
    if table.find(EconomyService.PRESENCE_PLACES, place) == nil then
        return
    end
    -- [D70, pasul j10] prezenta la un atelier al altei harti nu conteaza (un semn de prezenta n-are raspuns)
    local data = DataService.Get(player)
    if present and data ~= nil and closedFor(data, place) then
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

export type StoreSnapshot = { count: number, contents: { [string]: number } }
-- Un atelier are DOUA gramezi: ce asteapta (`count`, la intrare) si ce a iesit (`out`). `rate` e cat lucreaza ACUM
-- (0 fara omul lui si fara tine, sau cu intrarea goala), `present` daca stai langa el, `staffed` daca are om.
export type ProcessorSnapshot = {
    count: number,
    contents: { [string]: number },
    out: number,
    outContents: { [string]: number },
    rate: number,
    present: boolean,
    staffed: boolean,
    -- [D70] doar la unire: cate piese asteapta din fiecare (linia piesei -> cate) si piesa care lipseste („Waiting for
    -- cable”), nil cand le are pe toate. `count` / `contents` sunt atunci toate piesele, laolalta.
    inputs: { [string]: number }?,
    waiting: string?,
}
export type SellerSnapshot = {
    count: number,
    value: number,
    rate: number,
    contents: { [string]: number },
}

-- Cat lucreaza ACUM atelierul unei linii: cu omul lui tot timpul, fara el doar cat stai langa el; nimic cu intrarea
-- goala sau fara platforma care il porneste.
local function processorSpeed(player: Player, data: any, spec: FlowConfig.Line, at: number): number
    if spec.joins ~= nil then
        -- [D70] unirea merge doar cu toate piesele (FlowMath.joinWaiting)
        if FlowMath.joinWaiting(joinPiles(data, spec), spec) ~= nil then
            return 0
        end
    elseif next(pileOf(data, spec.inputPile :: string).counts) == nil then
        return 0
    end
    if spec.processorPad ~= nil and data.Pads[spec.processorPad] ~= true then
        return 0
    end
    local crew = crewsOf(data)[spec.role]
    return ChainMath.buildingSpeed(
        spec.station,
        levelOf(data, spec.station),
        crew,
        isPresent(player, spec.processor, at)
    ) or 0
end

function EconomyService.StoreSnapshotOf(player: Player, line: string): StoreSnapshot
    local data = DataService.Get(player)
    local spec = FlowConfig.LINES[line]
    -- [D70] o unire n-are magazie
    if data == nil or spec == nil or spec.storePile == nil then
        return { count = 0, contents = {} }
    end
    local counts = pileOf(data, spec.storePile :: string).counts
    return { count = PileMath.total(counts), contents = PileMath.contents(counts) }
end

function EconomyService.ProcessorSnapshotOf(player: Player, line: string): ProcessorSnapshot
    local data = DataService.Get(player)
    local spec = FlowConfig.LINES[line]
    if data == nil or spec == nil then
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
    local at = now()
    local output = pileOf(data, spec.outputPile).counts
    local input: PileMath.Counts
    local inputs: { [string]: number }? = nil
    local waiting: string? = nil
    if spec.joins ~= nil then
        -- [D70] la unire: toate piesele laolalta, plus cate din fiecare si ce lipseste
        local piles = joinPiles(data, spec)
        input = {}
        local byPart: { [string]: number } = {}
        for part, counts in piles do
            byPart[part] = PileMath.total(counts)
            for key, n in counts do
                input[key] = (input[key] or 0) + n
            end
        end
        inputs = byPart
        waiting = FlowMath.joinWaiting(piles, spec)
    else
        input = pileOf(data, spec.inputPile :: string).counts
    end
    local crew = crewsOf(data)[spec.role]
    return {
        count = PileMath.total(input),
        contents = PileMath.contents(input),
        out = PileMath.total(output),
        outContents = PileMath.contents(output),
        rate = processorSpeed(player, data, spec, at),
        present = isPresent(player, spec.processor, at),
        staffed = crew ~= nil and crew.count > 0,
        inputs = inputs,
        waiting = waiting,
    }
end

function EconomyService.SellerSnapshotOf(player: Player, seller: string): SellerSnapshot
    local data = DataService.Get(player)
    local spec = FlowConfig.SELLERS[seller]
    if data == nil or spec == nil then
        return { count = 0, value = 0, rate = 0, contents = {} }
    end
    local counts = pileOf(data, spec.pile).counts
    return {
        count = PileMath.total(counts),
        value = EconomyService.ValueOfCounts(player, counts),
        rate = ChainMath.buildingSpeed(
            spec.station,
            levelOf(data, spec.station),
            crewsOf(data)[spec.role],
            true
        ) or 0,
        contents = PileMath.contents(counts),
    }
end

-- Instantaneele Erei 1, pe numele lor de dinainte de D65 (NetServer le pune in TycoonState sub aceleasi campuri).
function EconomyService.StorageSnapshot(player: Player): StoreSnapshot
    return EconomyService.StoreSnapshotOf(player, "wood")
end

function EconomyService.SawmillSnapshot(player: Player): ProcessorSnapshot
    return EconomyService.ProcessorSnapshotOf(player, "wood")
end

function EconomyService.ShedSnapshot(player: Player): StoreSnapshot
    return EconomyService.StoreSnapshotOf(player, "iron")
end

function EconomyService.ForgeSnapshot(player: Player): ProcessorSnapshot
    return EconomyService.ProcessorSnapshotOf(player, "iron")
end

function EconomyService.DockSnapshot(player: Player): SellerSnapshot
    return EconomyService.SellerSnapshotOf(player, "dock")
end

-- ---- ticurile --------------------------------------------------------------------------------

-- O prelucrare pe linia `spec`: cate bucati apuca atelierul in `dt` secunde. Marfa bruta iese prelucrata, restul trece
-- neschimbat, si totul ajunge la iesirea atelierului -- de acolo il duce cineva la vanzator [D49, D55, D65].
local function process(player: Player, spec: FlowConfig.Line, dt: number, at: number)
    local data = DataService.Get(player)
    if data == nil or not openFor(data, spec.era) then
        return
    end
    local carry = slot(processCarry, player)
    local output = pileOf(data, spec.outputPile).counts
    local speed = processorSpeed(player, data, spec, at)
    -- gramezile de intrare: una la un atelier, cate una pe piesa la unire [D70]
    local inputs: { { counts: PileMath.Counts, [string]: any } } = {}
    local left, made
    local emptied: boolean
    if spec.joins ~= nil then
        local piles = joinPiles(data, spec)
        left, made = FlowMath.assemble(piles, output, carry[spec.line] or 0, speed, dt, spec)
        for _, field in spec.inputPiles :: { [string]: string } do
            table.insert(inputs, pileOf(data, field))
        end
        emptied = FlowMath.joinWaiting(piles, spec) ~= nil
    else
        local input = pileOf(data, spec.inputPile :: string)
        left, made = FlowMath.process(input.counts, output, carry[spec.line] or 0, speed, dt, spec)
        table.insert(inputs, input)
        emptied = next(input.counts) == nil
    end
    carry[spec.line] = left
    if made <= 0 then
        return
    end
    for _, input in inputs do
        input[spec.stamp] = at
    end
    data.Stats[spec.processedStat] = (data.Stats[spec.processedStat] or 0) + made
    if spec.line == "wood" and not data.Firsts.FirstCut then
        data.Firsts.FirstCut = true
        Analytics.Funnel(player, "FirstCut")
    end
    local pushedAt = slot(lastProcessPushAt, player)
    if emptied or at - (pushedAt[spec.line] or 0) >= SAW_PUSH_GAP then
        pushedAt[spec.line] = at
        push(player)
    end
end

-- O scurgere la vanzatorul `spec`: cate bucati apuca in `dt` secunde. Restul sub 1 se pastreaza pentru
-- tick-ul urmator, deci nicio bucata nu se pierde la rotunjire.
local function drain(player: Player, spec: FlowConfig.Seller, dt: number, at: number)
    local data = DataService.Get(player)
    if data == nil or not openFor(data, spec.era) then
        return
    end
    local seller = spec.seller
    local pile = pileOf(data, spec.pile)
    local counts = pile.counts
    local carryBy = slot(drainCarry, player)
    local speed = ChainMath.buildingSpeed(
        spec.station,
        levelOf(data, spec.station),
        crewsOf(data)[spec.role],
        true
    ) or 0
    local carried = (carryBy[seller] or 0) + speed * dt
    local whole = math.floor(carried)
    carryBy[seller] = carried - whole
    if whole <= 0 or next(counts) == nil then
        return
    end
    -- [D70] ordinea scurgerii: la orasul, lingourile inaintea curentului (ca ChainMath); la ceilalti, a cheilor
    local batch = PileMath.take(counts, whole, nil, FlowMath.drainOrder(seller))
    local n = #batch
    local total = EconomyService.ValueOf(player, batch)
    EconomyService.SettleSale(player, total, n)
    local totals, sold, soldAt =
        slot(pendingTotal, player), slot(pendingCount, player), slot(lastSoldAt, player)
    totals[seller] = (totals[seller] or 0) + total
    sold[seller] = (sold[seller] or 0) + n
    pile.drainedAt = at

    -- monedele intra CONTINUU (contorul urca lin, asta e bine); doar ANUNTUL se aduna
    local sinceLast = at - (soldAt[seller] or 0)
    local emptied = next(counts) == nil
    local announce = (emptied and sinceLast >= SOLD_MIN_GAP) or sinceLast >= SOLD_MAX_GAP
    if announce and (sold[seller] or 0) > 0 then
        soldAt[seller] = at
        -- "First sale. The river pays." -- odata cu PRIMII bani, nu la predare [D40, D48].
        if not data.Firsts.FirstSell then
            data.Firsts.FirstSell = true
            Analytics.Funnel(player, "FirstSell")
        end
        local onSold = deps.OnSold
        if onSold ~= nil then
            onSold(player, totals[seller], sold[seller], seller)
        end
        totals[seller] = 0
        sold[seller] = 0
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
    -- [D65] orice loc din FlowConfig: magazia si intrarea atelierului primesc marfa bruta a liniei, iesirea lui si
    -- vanzatorul pe cea prelucrata ("sawmill" / "forge" raman numele intrarilor, "planks" / "iron" ale iesirilor)
    local target: { any }? = nil
    local store, processor, output, seller =
        FlowConfig.BY_STORE[place],
        FlowConfig.BY_PROCESSOR[place],
        FlowConfig.BY_OUTPUT[place],
        FlowConfig.SELLERS[place]
    if store ~= nil then
        target = { pileOf(data, store.storePile :: string).counts, store.raw[1] }
    elseif processor ~= nil and processor.joins ~= nil then
        -- [D70] la unire: cate `count` din fiecare piesa, gata facute, fiecare in gramada ei
        for _, join in processor.joins :: { FlowConfig.Join } do
            PileMath.add(pileOf(data, join.pile).counts, { g = join.good, p = true }, count)
        end
        push(player)
        return count
    elseif processor ~= nil then
        target = { pileOf(data, processor.inputPile :: string).counts, processor.raw[1] }
    elseif output ~= nil then
        target = { pileOf(data, output.outputPile).counts, output.output }
    elseif seller ~= nil then
        for _, line in StationConfig.LINE_ORDER do
            if FlowConfig.LINES[line].seller == place then
                target = { pileOf(data, seller.pile).counts, FlowConfig.LINES[line].output }
                break
            end
        end
    end
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
            -- intai atelierele, in ordinea liniilor (gaterul, forja [D55], turnatoria, cuptorul [D65]), apoi vanzatorii
            for _, line in StationConfig.LINE_ORDER do
                process(player, FlowConfig.LINES[line], step, at)
            end
            for _, seller in StationConfig.SELLER_ORDER do
                drain(player, FlowConfig.SELLERS[seller], step, at)
            end
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
        processCarry[player] = nil
        lastProcessPushAt[player] = nil
        pendingTotal[player] = nil
        pendingCount[player] = nil
        lastSoldAt[player] = nil
        presentUntil[player] = nil
    end)
end

return EconomyService
