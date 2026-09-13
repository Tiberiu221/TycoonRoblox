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

local TycoonMath = {}

-- Index-ul GOODS o singura data, ca income()/itemValue sa nu caute liniar de fiecare data.
local goodsById: { [string]: TycoonConfig.Good } = {}
for _, g in TycoonConfig.GOODS do
    goodsById[g.id] = g
end

function TycoonMath.newState(rebirths: number?, indexFound: number?): State
    return {
        nets = {},
        lanes = 1,
        sackBig = false,
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
        -- pragul de plase, exact ca in simulator: intai intra plasa, apoi se aplica sporul
        local bonus = TycoonConfig.NET_MILESTONES[#s.nets]
        if bonus ~= nil then
            s.rateMult *= bonus
        end
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
    elseif kind == "hire" then
        -- Nimic aici: oamenii intra in lant prin ChainMath, numarati din `data.Hands` [D49]. Un
        -- steag in starea asta ar fi o a doua sursa pentru acelasi lucru.
        return
    elseif kind == "upgrade" or kind == "refine" then
        -- Un upgrade fara statia lui de baza nu face nimic, nu crapa. `sawmill_2` a ramas fara baza
        -- cand gaterul s-a mutat in lantul Erei 1 [D48]: cumparat vreodata cu modelul vechi, ar fi
        -- indexat `nil` si ar fi oprit tot calculul starii.
        local st = s.stations[e.good :: string]
        if st ~= nil then
            if kind == "upgrade" then
                st.cap = st.cap * (e.factor :: number)
            else
                st.mult = st.mult * (e.factor :: number)
            end
        end
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

-- ---- SCOASE la trecerea pe lantul cu trei verigi (E1.3) ----------------------------------
-- `income`, `greedyRun`, `targetWait` si `nice` au plecat de-aici. Erau oglinda fidela a unui
-- simulator care nu mai exista in forma aia: venitul nu mai e o SUMA peste platforme detinute, e
-- MINIMUL a trei debite, si traieste in `ChainMath` (tot port bit-exact, tot cu teste de aur).
-- Preturile deblocarilor nu se mai derivata in Luau: ies din simulatorul Python si se transcriu in
-- TycoonConfig, unde `tests/TycoonConfig.test.luau` le verifica.
--
-- Ce a RAMAS aici e tot ce nu tine de venit: starea platformelor detinute (multiplicatori,
-- steaguri, benzi), pretul unui obiect, capacitatea traistei si prinderea determinista.
-- Campurile `flow`/`crank`/`stations`/`miller`/`boats` din State raman nefolosite pana cand Era 2
-- isi re-derivata modelul de energie -- nu le sterg ca sa nu pierd forma la care s-a lucrat.

-- Samanta prinderii cu numarul `caught` a plasei de pe platforma `padIndex`. Aceeasi pe server
-- (care decide) si pe client (care arata dinainte ce pluteste spre plasa) [D13, F1 D2].
function TycoonMath.catchSeed(userId: number, padIndex: number, caught: number): number
    return userId * 7919 + padIndex * 104729 + caught
end

-- Bunul unei prinderi, din PRIMA tragere a generatorului (roll in [0, 1)). Bunurile sub minLanes
-- cad pe driftwood, ca in income(). Serverul continua cu acelasi generator pentru tier-ul unui
-- obiect cu nume; clientul se opreste aici -- tier-ul ramane secret pana la prindere.
function TycoonMath.pickGood(roll: number, lanes: number): string
    local driftwoodShare = TycoonConfig.GOODS[1].share
    for _, g in TycoonConfig.GOODS do
        if g.minLanes and g.minLanes > lanes then
            driftwoodShare += g.share
        end
    end
    local acc = 0
    for i, g in TycoonConfig.GOODS do
        if g.minLanes and g.minLanes > lanes then
            continue
        end
        acc += if i == 1 then driftwoodShare else g.share
        if roll < acc then
            return g.id
        end
    end
    return TycoonConfig.GOODS[1].id -- plasa de siguranta pentru erori de rotunjire
end

function TycoonMath.sackCapacity(s: State): number
    return if s.sackBig then TycoonConfig.SACK_BIG_CAPACITY else TycoonConfig.SACK_CAPACITY
end

-- De cate ori mai repede prinde plasa asta acum [D51]: prima plasa, pana ai colectat primele bucati
-- din tutorial; oricare alta, sau dupa prag, 1. `collected` = Stats.collected (bucati, nu gesturi).
function TycoonMath.catchBoost(padId: string, collected: number): number
    local boost = TycoonConfig.FIRST_CATCH
    if padId == boost.pad and collected < boost.untilCollected then
        return boost.speed
    end
    return 1
end

-- [D51] Prima plasa, cat e grabita (tutorialul), se goleste abia PLINA. Owner-ul: "zice wait dar eu pot
-- sa iau si sa fug mai departe, ar trebui sa fie locked pana face 12/12". Aceeasi regula pe server
-- (Collect refuza) si pe client (cardul spune de ce, fara buton).
function TycoonMath.collectLocked(
    padId: string,
    collected: number,
    count: number,
    capacity: number
): boolean
    return TycoonMath.catchBoost(padId, collected) > 1 and count < capacity
end

-- Cat tine o plasa: cel putin NET_CAPACITY, dar niciodata sub NET_HOLD_SECONDS de prindere [D49]. O
-- plasa de nivel mare nu se mai umple in doua secunde ca sa stea apoi plina pana trece cineva.
-- `rate` = rata plasei cu nivelul ei (StationService.NetRate), bucati pe secunda.
function TycoonMath.netCapacity(rate: number): number
    local hold = math.ceil(rate * TycoonConfig.NET_HOLD_SECONDS)
    return math.max(TycoonConfig.NET_CAPACITY, hold)
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
-- Cate plase sunt cumparate: conditiile deblocarilor se scriu in raport cu ele.
local function netsOwned(bought: { [string]: boolean }, pads: { TycoonConfig.Pad }): number
    local n = 0
    for _, p in pads do
        if not bought[p.id] then
            continue
        end
        for _, e in p.effects do
            if e.kind == "net" then
                n += 1
                break
            end
        end
    end
    return n
end

-- Ultima plasa detinuta, in ordinea din tabel (First Net, Second Net, ...). Ordinea din PADS e chiar
-- ordinea lantului de plase: deblocarile care nu sunt plase stau intercalate, dar nu intra aici.
local function lastOwnedNet(bought: { [string]: boolean }, pads: { TycoonConfig.Pad }): string?
    local last: string? = nil
    for _, p in pads do
        if bought[p.id] then
            for _, e in p.effects do
                if e.kind == "net" then
                    last = p.id
                    break
                end
            end
        end
    end
    return last
end

-- E cumparabila ACUM platforma asta? Inainte raspunsul era doar "e urmatoarea din tabel", si asta
-- forta cumparaturi moarte: erai obligat sa iei a treia plasa (inutila cat timp caratul e gatuirea)
-- inainte sa poti angaja prima Mana. Acum fiecare deblocare isi spune conditia [TycoonConfig.Needs].
local function meetsNeeds(
    p: TycoonConfig.Pad,
    bought: { [string]: boolean },
    pads: { TycoonConfig.Pad },
    nets: number,
    levels: { [string]: number }?
): boolean
    local needs = p.needs
    if needs == nil then
        return true -- erele 2-4 inca merg pe ordinea din tabel
    end
    if needs.netsExactly ~= nil and nets ~= needs.netsExactly then
        return false
    end
    if needs.netsOwned ~= nil and nets < needs.netsOwned then
        return false
    end
    -- FARA tabel de niveluri, poarta nu blocheaza: un apelant vechi (sau o era fara niveluri inca)
    -- ar vedea altfel lumea incremenita, fara nicio eroare care sa spuna de ce.
    if needs.prevNetLevel ~= nil and levels ~= nil then
        local prev = lastOwnedNet(bought, pads)
        if prev ~= nil and ((levels :: { [string]: number })[prev] or 1) < needs.prevNetLevel then
            return false
        end
    end
    if needs.after ~= nil and not bought[needs.after :: string] then
        return false
    end
    if needs.all then
        for _, other in pads do
            if other.era == p.era and other.id ~= p.id and not bought[other.id] then
                return false
            end
        end
    end
    return true
end

-- [D53] CE TREBUIE FACUT INTAI langa o platforma inca incuiata: prima conditie neimplinita, in ordinea in
-- care jucatorul le rezolva -- omul cerut, plasa care lipseste, nivelul ultimei plase, restul erei. Aceleasi
-- conditii ca meetsNeeds, deci textul de langa o ruina nu poate spune altceva decat ce verifica jocul.
-- `name`, `hire` si `first` sunt deja rezolvate, ca Strings.padNeeds sa nu aiba nevoie de config.
export type Blocker = {
    kind: string, -- "after" | "net" | "level" | "all"
    padId: string?,
    name: string?,
    level: number?,
    hire: boolean?, -- platforma ceruta aduce un om (Hire a ...)
    first: boolean?, -- plasa ceruta e prima plasa (Cast your first net)
}

-- Plasele, in ordinea din PADS: a N-a plasa cumparata e mereu a N-a de aici (se cumpara in lant).
local function netIds(pads: { TycoonConfig.Pad }): { string }
    local ids: { string } = {}
    for _, p in pads do
        for _, e in p.effects do
            if e.kind == "net" then
                table.insert(ids, p.id)
                break
            end
        end
    end
    return ids
end

local function blockerFor(kind: string, padId: string?, level: number?, firstNet: string?): Blocker
    local target = if padId ~= nil then TycoonConfig.byId[padId] else nil
    return {
        kind = kind,
        padId = padId,
        name = if target ~= nil then target.name else nil,
        level = level,
        hire = padId ~= nil and TycoonConfig.CREW_OF_PAD[padId] ~= nil,
        first = padId ~= nil and padId == firstNet,
    }
end

function TycoonMath.padBlocker(
    p: TycoonConfig.Pad,
    bought: { [string]: boolean },
    levels: { [string]: number }?,
    pads: { TycoonConfig.Pad }?
): Blocker?
    local needs = p.needs
    if needs == nil or bought[p.id] then
        return nil
    end
    local list = pads or TycoonConfig.PADS
    local ids = netIds(list)
    if needs.after ~= nil and not bought[needs.after :: string] then
        return blockerFor("after", needs.after, nil, ids[1])
    end
    local nets = netsOwned(bought, list)
    local want = needs.netsExactly or needs.netsOwned
    -- plasa CERUTA, nu urmatoarea de cumparat: "Cast the Fourth Net first" spune toata conditia, iar
    -- plasa a patra isi spune singura, pe ruina ei, ce ii lipseste
    if want ~= nil and nets < want and ids[want] ~= nil then
        return blockerFor("net", ids[want], nil, ids[1])
    end
    if needs.prevNetLevel ~= nil and levels ~= nil then
        local last = lastOwnedNet(bought, list)
        if last ~= nil and ((levels :: { [string]: number })[last] or 1) < needs.prevNetLevel then
            return blockerFor("level", last, needs.prevNetLevel, ids[1])
        end
    end
    if needs.all then
        for _, other in list do
            if other.era == p.era and other.id ~= p.id and not bought[other.id] then
                return blockerFor("all", nil, nil, ids[1])
            end
        end
    end
    return nil
end

-- [D53] CEASUL PLASEI NU SE OPRESTE CAND E PLINA. Decizia unui tick, pura: cate prinderi se fac acum si
-- unde ramane ceasul. Cu loc, un bun pentru fiecare moment trecut, cel mult cat mai incape. Plina (sau
-- umpluta pe drum), ceasul sare la primul moment de DUPA `now`, in pasi intregi de interval: ritmul ramane
-- acelasi, deci clientul poate arata bustenii venind de departe, iar la golire nu vine nicio rafala.
-- Inainte, plina, ceasul statea pe loc, iar golirea il repornea la "acum + interval" -- prima prindere de
-- dupa golire nu putea fi vazuta venind.
function TycoonMath.netTick(
    nextCatchAt: number,
    interval: number,
    now: number,
    count: number,
    capacity: number
): (number, number)
    if not (interval > 0) or not math.isfinite(interval) or not math.isfinite(nextCatchAt) then
        return 0, nextCatchAt
    end
    local catches = 0
    local nextAt = nextCatchAt
    if now >= nextAt then
        local due = math.floor((now - nextAt) / interval) + 1
        catches = math.min(due, math.max(0, capacity - count))
        nextAt += catches * interval
    end
    if count + catches >= capacity and now >= nextAt then
        nextAt += (math.floor((now - nextAt) / interval) + 1) * interval
    end
    return catches, nextAt
end

function TycoonMath.padStatuses(
    bought: { [string]: boolean },
    pads: { TycoonConfig.Pad }?,
    levels: { [string]: number }?
): { [string]: string }
    local list = pads or TycoonConfig.PADS
    local result: { [string]: string } = {}
    local unbought: { TycoonConfig.Pad } = {}
    for _, p in list do
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
    local nets = netsOwned(bought, list)
    local eligible: { TycoonConfig.Pad } = {}
    local waiting: { TycoonConfig.Pad } = {} -- conditia inca neimplinita, dar in aceeasi era
    local blocker: TycoonConfig.Pad? = nil
    for _, p in unbought do
        if not p.live or p.era > era0 then
            blocker = p
            break
        end
        if meetsNeeds(p, bought, list, nets, levels) then
            table.insert(eligible, p)
        else
            table.insert(waiting, p)
        end
    end

    -- TOATE deblocarile cu conditia implinita sunt cumparabile deodata. Inainte erau doar primele
    -- doua din tabel; cu conditii, limita aia n-ar mai avea niciun sens -- ar ascunde exact
    -- alegerea pe care jocul o cere (ce repari intai).
    for _, p in eligible do
        result[p.id] = "available"
    end
    -- prima dintre cele care asteapta se vede conturata: se stie ce urmeaza, fara sa se poata lua
    if #waiting > 0 then
        result[waiting[1].id] = "outline"
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

-- [D52] Debitul PE MINUT, pentru meniul obiectului. Pe secunda, cu o zecimala, pasul de +3% al unui
-- nivel iesea "0.3/s -> 0.3/s +0.0": adevarat si inutil. Pe minut acelasi pas e "19.8 -> 20.4". Sub
-- 100, o zecimala (fara ".0" in coada); de la 100, intreg; de la 1000, K/M/B ca formatNumber. ROTUNJIT,
-- nu taiat ca formatNumber: 20.39 e "20.4", iar un nivel care chiar adauga ceva nu pare pe loc.
function TycoonMath.formatPerMinute(perSecond: number): string
    local perMinute = perSecond * 60
    if not math.isfinite(perMinute) or perMinute <= 0 then
        return "0"
    end
    if perMinute < 99.95 then
        local text = string.format("%.1f", perMinute)
        return (text:gsub("%.0$", ""))
    end
    local whole = math.floor(perMinute + 0.5)
    if whole < 1000 then
        return tostring(whole)
    end
    return TycoonMath.formatNumber(whole)
end

return TycoonMath
