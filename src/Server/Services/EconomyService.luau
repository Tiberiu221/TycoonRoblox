--!strict
-- Moneda jucatorului si drumul marfii [F0 spec 3.2, D49]. Singurul loc care schimba Coins, ca sumele
-- sa nu poata scadea din greseala, si singurul loc care muta marfa intre gramezi:
--
--   plase -> traista / Collector -> DEPOZIT -> traista / Porter -> GATER (taie) -> iesirea gaterului
--         -> traista / Hauler -> DEBARCADER (vinde) -> monede
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
local pendingTotal: { [Player]: number } = {}
local pendingCount: { [Player]: number } = {}
local lastSoldAt: { [Player]: number } = {}

-- PREZENTA LA GATER [D49]. Fara Sawyer, gaterul taie doar cat stai langa el. Serverul nu stie unde
-- esti, deci clientul spune "sunt aici" la intrarea in raza si apoi la fiecare 2 s; prezenta tine
-- 3 s si expira singura, ca un client care tace (inchis, lag) sa nu taie la nesfarsit.
EconomyService.PRESENCE_SECONDS = 3
local presentUntil: { [Player]: number } = {}

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

local function isPresent(player: Player, at: number): boolean
    return (presentUntil[player] or 0) > at
end

function EconomyService.GetPearls(player: Player): number
    local data = DataService.Get(player)
    return if data ~= nil then data.Pearls else 0
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

local function split(items: { Catch }): ({ Catch }, { Catch })
    local raw, cut = {}, {}
    for _, item in items do
        table.insert(if isCut(item) then cut else raw, item)
    end
    return raw, cut
end

function EconomyService.SackSnapshot(player: Player): {
    count: number,
    capacity: number,
    value: number,
    contents: { [string]: number },
    raw: number,
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
            cut = 0,
            cutValue = 0,
        }
    end
    -- CE duce jucatorul, nu doar cat: gramezile se deseneaza pe feluri, deci si traista.
    local contents: { [string]: number } = {}
    local _raw, cut = split(data.Sack.items)
    for _, item: Catch in data.Sack.items do
        contents[item.g] = (contents[item.g] or 0) + 1
    end
    return {
        count = #data.Sack.items,
        capacity = TycoonMath.sackCapacity(state),
        value = EconomyService.ValueOf(player, data.Sack.items),
        contents = contents,
        raw = #data.Sack.items - #cut,
        cut = #cut,
        -- doar ce se poate vinde acum: pastila de la debarcader nu promite bani pe busteni bruti [D40]
        cutValue = EconomyService.ValueOf(player, cut),
    }
end

-- E LA DEPOZIT: lasi tot brutul din traista; daca n-ai brut, iei brut din depozit cat incape.
-- Intoarce (ok, ce s-a intamplat, cate bucati). Motivele refuzului le traduce clientul in toast.
function EconomyService.UseStorage(player: Player): (boolean, string, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0
    end
    local raw, cut = split(data.Sack.items)
    if #raw > 0 then
        PileMath.addItems(data.StoragePile.counts, raw)
        data.Sack.items = cut
        push(player)
        return true, "dropped", #raw
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    if room <= 0 then
        return false, "sack_full", 0
    end
    local taken = PileMath.take(data.StoragePile.counts, room)
    if #taken == 0 then
        return false, "storage_empty", 0
    end
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    push(player)
    return true, "took", #taken
end

-- E LA GATER, un singur gest: lasi brutul, apoi iei ce e taiat cat incape.
-- Intoarce (ok, motiv, cate ai lasat, cate ai luat).
function EconomyService.UseSawmill(player: Player): (boolean, string, number, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0, 0
    end
    local raw, cut = split(data.Sack.items)
    if #raw > 0 then
        PileMath.addItems(data.SawmillPile.counts, raw)
        data.Sack.items = cut
    end
    local room = TycoonMath.sackCapacity(deps.Pads.StateFor(player)) - #data.Sack.items
    local taken = if room > 0 then PileMath.take(data.PlanksPile.counts, room, true) else {}
    table.move(taken, 1, #taken, #data.Sack.items + 1, data.Sack.items)
    if #raw == 0 and #taken == 0 then
        return false, if room <= 0 then "sack_full" else "nothing_cut", 0, 0
    end
    push(player)
    return true, "ok", #raw, #taken
end

-- E LA TAVERNA: lasi ce e taiat. Brutul ramane in traista -- taverna cumpara doar marfa trecuta prin
-- gater. `Stats.sold` numara BUCATILE predate (quest-urile "Sell the planks"), `Stats.sells` gesturile.
function EconomyService.DeliverDock(player: Player): (boolean, string, number)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile", 0
    end
    local raw, cut = split(data.Sack.items)
    if #cut == 0 then
        return false, if #raw > 0 then "raw_only" else "empty", 0
    end
    PileMath.addItems(data.DockPile.counts, cut)
    data.Sack.items = raw
    data.Stats.sells += 1
    data.Stats.sold = (data.Stats.sold or 0) + #cut
    push(player)
    return true, "delivered", #cut
end

-- ---- oamenii [D49] --------------------------------------------------------------------------

-- Un om lasa ce duce: Collector-ul la depozit, Porter-ul la gater, Hauler-ul la debarcader.
function EconomyService.DropAt(player: Player, place: string, items: { Catch }): number
    local data = DataService.Get(player)
    if data == nil or #items == 0 then
        return 0
    end
    if place == "storage" then
        PileMath.addItems(data.StoragePile.counts, items)
    elseif place == "sawmill" then
        PileMath.addItems(data.SawmillPile.counts, items)
    elseif place == "dock" then
        PileMath.addItems(data.DockPile.counts, items)
        data.Stats.sells += 1
        data.Stats.sold = (data.Stats.sold or 0) + #items
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
    elseif place == "planks" then
        return PileMath.take(data.PlanksPile.counts, n, true)
    end
    return {}
end

function EconomyService.SetPresence(player: Player, present: boolean)
    local was = isPresent(player, now())
    if present then
        presentUntil[player] = now() + EconomyService.PRESENCE_SECONDS
    else
        presentUntil[player] = nil
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
    local present = isPresent(player, now())
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
        then ChainMath.sawSpeed(levelOf(data, "saw"), crewsOf(data).sawyer, isPresent(player, at))
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
            drain(player, step, at)
            -- prezenta a expirat intre doua semnale: clientul trebuie sa vada ca gaterul s-a oprit
            local until_ = presentUntil[player]
            if until_ ~= nil and until_ <= at then
                presentUntil[player] = nil
                push(player)
            end
        end
    end)
    Players.PlayerRemoving:Connect(function(player: Player)
        drainCarry[player] = nil
        sawCarry[player] = nil
        lastSawPushAt[player] = nil
        pendingTotal[player] = nil
        pendingCount[player] = nil
        lastSoldAt[player] = nil
        presentUntil[player] = nil
    end)
end

return EconomyService
