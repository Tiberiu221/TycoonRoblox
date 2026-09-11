--!strict
-- Port fidel al scripts/economy/sim_tycoon.py, plus ajutoare pentru jocul viu [F0 spec 1.2].
-- Rezultatele in virgula mobila trebuie sa iasa BIT LA BIT ca simulatorul: aceeasi ordine de
-- operatii, GOODS parcurs in ordinea simulatorului, semantica Python de sortare pe tuplu pentru
-- energie, round-half-to-even in nice() pentru x < 10. TycoonMath.test.luau e dovada, cu valorile
-- de aur din simulator; daca nu pica exact, se cauta diferenta de portare, nu se relaxeaza testul.
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

export type Station = { mult: number, cap: number, draw: number }
export type State = {
    nets: { number },
    lanes: number,
    sackBig: boolean,
    runners: number,
    flume: boolean,
    rateMult: number,
    priceMult: number,
    namedMult: number,
    flow: number,
    crank: number,
    stations: { [string]: Station },
    miller: boolean,
    dockhand: boolean,
    boats: number,
    indexFound: number,
    rebirths: number,
    bells: number,
}
export type RunRow = { id: string, price: number, t: number, income: number, before: number }

type ActiveGood = { id: string, value: number, share: number }
type Offer = { gainPerDraw: number, good: string, possible: number, gain: number, draw: number }

local TycoonMath = {}

-- Index-ul GOODS o singura data, ca income()/itemValue sa nu caute liniar de fiecare data.
local goodsById: { [string]: TycoonConfig.Good } = {}
for _, g in TycoonConfig.GOODS do
    goodsById[g.id] = g
end
local namedGood = goodsById["named"] :: TycoonConfig.Good

-- Ordinea Python pentru sort(reverse=True) pe tuplul (castig/energie, id, posibil, castig, energie):
-- descrescator pe fiecare camp, in ordine; al doilea camp e string, comparat ca octeti (id-urile
-- sunt ascii, deci la fel ca ordinea Python).
local function offerGreater(a: Offer, b: Offer): boolean
    if a.gainPerDraw ~= b.gainPerDraw then
        return a.gainPerDraw > b.gainPerDraw
    end
    if a.good ~= b.good then
        return a.good > b.good
    end
    if a.possible ~= b.possible then
        return a.possible > b.possible
    end
    if a.gain ~= b.gain then
        return a.gain > b.gain
    end
    return a.draw > b.draw
end

-- round() din Python: jumatate rotunjeste spre para, nu mereu in sus. Doar pentru nice(x<10);
-- diferenta se vede in preturile mici (2 vs 3 la un venit de 2.5).
local function roundHalfEven(x: number): number
    local f = math.floor(x)
    local diff = x - f
    if diff < 0.5 then
        return f
    elseif diff > 0.5 then
        return f + 1
    elseif f % 2 == 0 then
        return f
    else
        return f + 1
    end
end

function TycoonMath.newState(rebirths: number?, indexFound: number?): State
    return {
        nets = {},
        lanes = 1,
        sackBig = false,
        runners = 0,
        flume = false,
        rateMult = 1.0,
        priceMult = 1.0,
        namedMult = 1.0,
        flow = 0.0,
        crank = 0.0,
        stations = {},
        miller = false,
        dockhand = false,
        boats = 0,
        indexFound = indexFound or 0,
        rebirths = rebirths or 0,
        bells = 1.0,
    }
end

-- Muteaza state-ul dupa un singur efect. `dyn` e state-ul vazut ca `any`: campurile flag/mul/add
-- vin din date (Effect.field), nu se poate scrie o ramura separata pentru fiecare din cele 12.
function TycoonMath.applyEffect(s: State, e: TycoonConfig.Effect)
    local dyn: any = s
    local kind = e.kind
    if kind == "net" then
        table.insert(s.nets, e.rate :: number)
    elseif kind == "flag" then
        dyn[e.field] = true
    elseif kind == "mul" then
        local field = e.field :: string
        dyn[field] = dyn[field] * (e.factor :: number)
    elseif kind == "add" then
        local field = e.field :: string
        dyn[field] = dyn[field] + (e.amount :: number)
    elseif kind == "build" then
        s.stations[e.good :: string] =
            { mult = e.mult :: number, cap = e.cap :: number, draw = e.draw :: number }
    elseif kind == "upgrade" then
        local st = s.stations[e.good :: string] :: Station
        st.cap = st.cap * (e.factor :: number)
    elseif kind == "refine" then
        local st = s.stations[e.good :: string] :: Station
        st.mult = st.mult * (e.factor :: number)
    end
end

-- Starea unui jucator care detine `bought`. Aplica efectele in ordinea PADS (conteaza: Sawmill II
-- presupune ca Sawmill exista deja). `live=true`: Index-ul real inlocuieste proxy-ul indexFound
-- din platforme (Workshop, Sorting Shed) -- altfel am numara de doua ori.
function TycoonMath.stateFor(
    bought: { [string]: boolean },
    rebirths: number,
    indexFound: number,
    live: boolean?
): State
    local s = TycoonMath.newState(rebirths, indexFound)
    for _, p in TycoonConfig.PADS do
        if bought[p.id] then
            for _, e in p.effects do
                if live and e.field == "indexFound" then
                    continue
                end
                TycoonMath.applyEffect(s, e)
            end
        end
    end
    return s
end

-- Venitul pe secunda al unui state, exact ca income() din simulator.
function TycoonMath.income(s: State): number
    local perNet: { number } = table.create(#s.nets)
    for i, r in s.nets do
        perNet[i] = r * s.rateMult
    end
    local netCount = #perNet
    local auto = if s.flume
        then netCount
        else math.min(netCount, s.runners * TycoonConfig.MODEL.netsPerRunner)
    local manual = netCount - auto
    local baseEff = if s.sackBig
        then TycoonConfig.MODEL.manualEffBigSack
        else TycoonConfig.MODEL.manualEff
    local eff = baseEff / (1 + TycoonConfig.MODEL.manualCrowd * math.max(0, manual - 1))

    local sumAuto = 0.0
    for i = 1, auto do
        sumAuto += perNet[i]
    end
    local sumManual = 0.0
    for i = auto + 1, netCount do
        sumManual += perNet[i]
    end
    local items = sumAuto + sumManual * eff

    -- bunurile sub minLanes cad pe driftwood, in ordinea GOODS -- suma nu e asociativa, deci
    -- ordinea (scrap inainte de shards) trebuie sa fie exact ca in simulator
    local driftwoodShare = TycoonConfig.GOODS[1].share
    local active: { ActiveGood } = {}
    for _, g in TycoonConfig.GOODS do
        if g.minLanes and g.minLanes > s.lanes then
            driftwoodShare += g.share
        else
            table.insert(active, { id = g.id, value = g.value, share = g.share })
        end
    end
    active[1].share = driftwoodShare -- driftwood e mereu primul in GOODS si nu are minLanes

    local total = 0.0
    local offers: { Offer } = {}
    for _, g in active do
        local inflow = items * g.share
        local base = g.value * (if g.id == "named" then s.namedMult else 1.0)
        total += inflow * base
        local st = s.stations[g.id]
        if st ~= nil then
            local m = st.mult * (if s.miller then TycoonConfig.MODEL.millerMult else 1.0)
            local gain = base * (m - 1)
            table.insert(offers, {
                gainPerDraw = gain / st.draw,
                good = g.id,
                possible = math.min(inflow, st.cap),
                gain = gain,
                draw = st.draw,
            })
        end
    end
    table.sort(offers, offerGreater)

    -- reteaua de energie: merge intai la statiile cu cel mai mare castig pe unitate de energie
    local flow = s.flow
    for i, o in offers do
        local free = if i == 1 and s.crank > 0 then o.possible * s.crank else 0.0
        local powered = if o.draw > 0
            then math.min(o.possible - free, flow / o.draw)
            else o.possible - free
        flow -= powered * o.draw
        total += (free + powered) * o.gain
    end
    total += s.boats * TycoonConfig.MODEL.boatYield * namedGood.value
    local price = s.priceMult * (if s.dockhand then TycoonConfig.MODEL.dockhandMult else 1.0)
    return total
        * price
        * s.bells
        * (1 + TycoonConfig.MODEL.indexBonus * s.indexFound)
        * (1 + TycoonConfig.MODEL.rebirthBonus * s.rebirths)
end

-- Asteptarea tinta (secunde) inaintea platformei k (0-based, ca in simulator).
function TycoonMath.targetWait(k: number): number
    return math.min(
        TycoonConfig.TARGET_WAIT.cap,
        TycoonConfig.TARGET_WAIT.base * TycoonConfig.TARGET_WAIT.growth ^ k
    )
end

-- Pretul "rotund" strict mai mare decat `floor` (pretul platformei anterioare).
function TycoonMath.nice(x: number, floor: number): number
    if x < 10 then
        local v = math.max(0, roundHalfEven(x))
        if v > floor then
            return v
        end
        return floor + 1
    end
    local mag = 1 -- 10^k, calculat prin inmultire repetata ca sa fie exact acelasi numar ca in Python
    for _ = 1, 13 do
        for _, n in TycoonConfig.NICE do
            local v = math.floor(n * mag)
            if v >= x * 0.93 and v > floor then
                return v
            end
        end
        mag *= 10
    end
    return math.floor(x)
end

-- Drumul lacom: cumpara imediat ce isi permite. `prices`, cand e dat (renasteri), inlocuieste
-- calculul din nice() -- pretul e acelasi meniu ca la tura 1, doar atins mai repede.
function TycoonMath.greedyRun(
    rebirths: number?,
    indexFound: number?,
    stopAfterEra: number?,
    prices: { number }?
): { RunRow }
    local s = TycoonMath.newState(rebirths, indexFound)
    local coins = 0.0
    local t = 0
    local rows: { RunRow } = {}
    local prevPrice = 0
    local k = 0
    for i, p in TycoonConfig.PADS do
        local price: number
        if prices ~= nil then
            price = prices[k + 1]
        elseif k == 0 then
            price = 0
        else
            price = TycoonMath.nice(TycoonMath.income(s) * TycoonMath.targetWait(k), prevPrice)
        end
        prevPrice = price

        while coins < price do
            coins += TycoonMath.income(s)
            t += 1
        end
        local before = TycoonMath.income(s)
        coins -= price
        for _, e in p.effects do
            TycoonMath.applyEffect(s, e)
        end
        local after = TycoonMath.income(s)
        table.insert(rows, { id = p.id, price = price, t = t, income = after, before = before })

        k += 1
        if stopAfterEra ~= nil and p.era == stopAfterEra then
            local nextPad = TycoonConfig.PADS[i + 1]
            if nextPad == nil or nextPad.era ~= p.era then
                break
            end
        end
    end
    return rows
end

function TycoonMath.sackCapacity(s: State): number
    return if s.sackBig then TycoonConfig.SACK_BIG_CAPACITY else TycoonConfig.SACK_CAPACITY
end

function TycoonMath.netInterval(rate: number, s: State): number
    return 1 / (rate * s.rateMult)
end

-- Multiplicatorul de vanzare la debarcader: acelasi "coada" ca in income(), dar cu index-ul si
-- renasterile REALE ale jucatorului (state.indexFound e doar proxy-ul de simulare).
function TycoonMath.sellMultiplier(s: State, indexCount: number, rebirths: number): number
    local dockhandFactor = if s.dockhand then TycoonConfig.MODEL.dockhandMult else 1.0
    return s.priceMult
        * dockhandFactor
        * s.bells
        * (1 + TycoonConfig.MODEL.indexBonus * indexCount)
        * (1 + TycoonConfig.MODEL.rebirthBonus * rebirths)
end

-- Valoarea unui obiect din gramada. "named": pretul tine de tier, nu de bunul brut.
function TycoonMath.itemValue(good: string, tier: string?, s: State): number
    if good == "named" then
        local base = if tier ~= nil then TycoonConfig.NAMED_VALUE[tier] else nil
        return (base or 14) * s.namedMult
    end
    local g = goodsById[good]
    if g == nil then
        return 0
    end
    return g.value
end

-- Statutul fiecarei platforme pentru un profil: "bought" | "available" | "outline"; absenta = ascunsa.
-- Se merge prin platformele NEcumparate in ordine si se opreste la prima care nu e `live` sau e
-- dintr-o era mai departe decat prima platforma necumparata (era0). Un clopot (motiv D) inchide era:
-- se poate cumpara doar cand e PRIMA platforma necumparata, adica restul erei e deja cumparat.
-- Pana atunci se vede ca pas urmator ("outline"), dar nu ia locul unei platforme cumparabile.
-- Primele DOUA eligibile: "available"; apoi "outline" pentru a treia eligibila, altfel clopotul care
-- asteapta, altfel platforma din era0 care a oprit mersul. `pads` exista doar pentru teste.
function TycoonMath.padStatuses(
    bought: { [string]: boolean },
    pads: { TycoonConfig.Pad }?
): { [string]: string }
    local result: { [string]: string } = {}
    local unbought: { TycoonConfig.Pad } = {}
    for _, p in pads or TycoonConfig.PADS do
        if bought[p.id] then
            result[p.id] = "bought"
        else
            table.insert(unbought, p)
        end
    end
    if #unbought == 0 then
        return result
    end

    local era0 = unbought[1].era
    local eligible: { TycoonConfig.Pad } = {}
    local waitingBell: TycoonConfig.Pad? = nil
    local blocker: TycoonConfig.Pad? = nil
    for i, p in unbought do
        if not p.live or p.era > era0 then
            blocker = p
            break
        end
        if p.motive == "D" and i > 1 then
            waitingBell = p
            continue
        end
        table.insert(eligible, p)
    end

    for i = 1, math.min(2, #eligible) do
        result[eligible[i].id] = "available"
    end
    if #eligible >= 3 then
        result[eligible[3].id] = "outline"
    elseif waitingBell ~= nil then
        result[waitingBell.id] = "outline"
    elseif blocker ~= nil and blocker.era == era0 then
        result[blocker.id] = "outline"
    end
    return result
end

-- floor; sub 1000 simplu ("950"); altfel K/M/B ca big() din simulator: 1200 -> "1.2K".
function TycoonMath.formatNumber(n: number): string
    local v = math.floor(n)
    if v < 1000 then
        return tostring(v)
    end
    local units = { { "B", 1e9 }, { "M", 1e6 }, { "K", 1e3 } }
    for _, u in units do
        local suffix, d = u[1] :: string, u[2] :: number
        if v >= d then
            local s = string.format("%.2f", v / d)
            s = s:gsub("0+$", ""):gsub("%.$", "")
            return s .. suffix
        end
    end
    return tostring(v)
end

-- Rata pe secunda: sub 10, o zecimala ("0.4"); altfel ca formatNumber.
function TycoonMath.formatRate(n: number): string
    if n < 10 then
        return string.format("%.1f", n)
    end
    return TycoonMath.formatNumber(n)
end

return TycoonMath
