--!strict
-- Port fidel al scripts/economy/sim_tycoon.py, plus ajutoare pentru jocul viu [F0 spec 1.2].
-- Rezultatele in virgula mobila trebuie sa iasa BIT LA BIT ca simulatorul: aceeasi ordine de
-- operatii, GOODS parcurs in ordinea simulatorului, semantica Python de sortare pe tuplu pentru
-- energie, round-half-to-even in nice() pentru x < 10. TycoonMath.test.luau e dovada, cu valorile
-- de aur din simulator; daca nu pica exact, se cauta diferenta de portare, nu se relaxeaza testul.
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")

export type Station = { mult: number, cap: number, draw: number }
export type State = {
    nets: { number },
    lanes: number,
    sackBig: boolean,
    scrapShed: boolean, -- [D55] shed-ul de scrap (steagul platformei lui)
    forge: boolean, -- [D56] Forge (platforma `workshop`): fara ea nu se topeste nimic
    -- [D65] Era 2: roata de apa (porneste turnatoria si Piata), cuptorul de cupru, magazia de minereu
    wheel: boolean,
    furnace: boolean,
    oreShed: boolean,
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
        scrapShed = false,
        forge = false,
        wheel = false,
        furnace = false,
        oreShed = false,
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

-- [D55] Ce prinde plasa unei platforme: "scrap" pentru plasa din larg (efectul ei poarta `good = "scrap"`),
-- "wood" pentru restul. Un singur loc, citit si de server (NetService), si de client (NetController).
function TycoonMath.netKind(pad: TycoonConfig.Pad): string
    for _, e in pad.effects do
        -- [D65] felul e chiar `good`-ul efectului: "scrap" (Fifth Net), "mill" (plasele Morii), "ore" (minereul)
        if e.kind == "net" and e.good ~= nil then
            return e.good
        end
    end
    return "wood"
end

-- Bunul unei prinderi, din PRIMA tragere a generatorului (roll in [0, 1)), dupa felul plasei [D55]:
-- ponderile din TycoonConfig.CATCH, in ordinea lor. Serverul continua cu acelasi generator pentru tier-ul
-- unui obiect cu nume; clientul se opreste aici -- tier-ul ramane secret pana la prindere.
function TycoonMath.pickGood(roll: number, kind: string): string
    local parts = TycoonConfig.CATCH[kind] or TycoonConfig.CATCH.wood
    local acc = 0
    for _, part in parts do
        acc += part.share
        if roll < acc then
            return part.id
        end
    end
    return parts[1].id -- plasa de siguranta pentru erori de rotunjire
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
-- [D65] O gasire cu nume, a oricarei ere (`named`, `named2`): are treapta ei si merge cu marfa [D56].
function TycoonMath.isFind(good: string): boolean
    return TycoonConfig.FIND_MULT[good] ~= nil
end

function TycoonMath.itemValue(good: string, tier: string?, s: State): number
    -- [D65] gasirile, pe ere: aceleasi trepte, inmultite cu cadrul erei (FIND_MULT: named = 1, named2 = 40)
    local findMult = TycoonConfig.FIND_MULT[good]
    if findMult ~= nil then
        local base = if tier ~= nil then TycoonConfig.NAMED_VALUE[tier] else nil
        return (base or 14) * findMult * s.namedMult
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
-- [D70, pasul j10] PRAGUL DE VENIT al unei conditii (Dam Bell: 4T/s), in moneda pe care o vede jucatorul: cu 2x Flow
-- venitul afisat e dublu, deci si pragul (altfel pass-ul ar cumpara clopotul, D46). Un singur loc, citit de statusuri,
-- de cartonasul conditiei si de quest-uri (pasul j11).
function TycoonMath.incomeGoal(base: number, flowFactor: number?): number
    return base * (flowFactor or 1)
end

local function meetsNeeds(
    p: TycoonConfig.Pad,
    bought: { [string]: boolean },
    pads: { TycoonConfig.Pad },
    nets: number,
    levels: { [string]: number }?,
    income: number?,
    flowFactor: number?
): boolean
    local needs = p.needs
    if needs == nil then
        return true -- erele 2-4 inca merg pe ordinea din tabel
    end
    -- [D70] fara venitul cunoscut, o conditie de venit nu e implinita (cine nu-l stie nu deschide clopotul)
    if
        needs.income ~= nil
        and (income == nil or income < TycoonMath.incomeGoal(needs.income, flowFactor))
    then
        return false
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
    kind: string, -- "after" | "net" | "level" | "all" | "income"
    padId: string?,
    name: string?,
    level: number?,
    hire: boolean?, -- platforma ceruta aduce un om (Hire a ...)
    first: boolean?, -- plasa ceruta e prima plasa (Cast your first net)
    ring: boolean?, -- [D65] platforma ceruta e un clopot (Ring the ...)
    zone: string?, -- [D65] la "all": cartierul platformei care intreaba ("The Mill")
    -- [D70, pasul k4] la "all": platforma e a unei lumi noi (barajul), unde n-a fost nimic de reconstruit
    fresh: boolean?,
    goalText: string?, -- [D70] la "income": pragul, scris ca pe HUD ("4T")
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

-- [D70, pasul k4] cartierul erei, din zonele LUMII ei (barajul n-are zona in ZONES-ul satului)
local function zoneNameOf(era: number): string?
    for _, zone in TycoonConfig.zonesOf(WorldConfig.worldOfEra(era)) do
        if zone.era == era then
            return zone.name
        end
    end
    return nil
end

local function blockerFor(
    kind: string,
    padId: string?,
    level: number?,
    firstNet: string?,
    asking: TycoonConfig.Pad?
): Blocker
    local target = if padId ~= nil then TycoonConfig.byId[padId] else nil
    return {
        kind = kind,
        padId = padId,
        name = if target ~= nil then target.name else nil,
        level = level,
        hire = padId ~= nil and TycoonConfig.CREW_OF_PAD[padId] ~= nil,
        first = padId ~= nil and padId == firstNet,
        ring = target ~= nil and target.motive == "D",
        zone = if asking ~= nil then zoneNameOf(asking.era) else nil,
        -- doar cand e adevarat: in sat cheia lipseste, ca blocajele lumii 1 sa ramana exact cele din martor
        fresh = if asking ~= nil and WorldConfig.worldOfEra(asking.era) ~= 1 then true else nil,
    }
end

function TycoonMath.padBlocker(
    p: TycoonConfig.Pad,
    bought: { [string]: boolean },
    levels: { [string]: number }?,
    pads: { TycoonConfig.Pad }?,
    income: number?,
    flowFactor: number?
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
                return blockerFor("all", nil, nil, ids[1], p)
            end
        end
    end
    -- [D70] ultima: venitul (Dam Bell), dupa tot restul erei
    if needs.income ~= nil then
        local goal = TycoonMath.incomeGoal(needs.income, flowFactor)
        if income == nil or income < goal then
            local b = blockerFor("income", nil, nil, ids[1], p)
            b.goalText = TycoonMath.formatNumber(goal)
            return b
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
    levels: { [string]: number }?,
    income: number?,
    flowFactor: number?
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
        if meetsNeeds(p, bought, list, nets, levels, income, flowFactor) then
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
    -- [D67] doar o platforma aflata in joc: una a unei ere inca in constructie (`live = false`) nu se arata ca pas
    -- urmator, fiindca n-ar putea fi luata [D40]. Cine a terminat Moara nu vede Steam Engine-ul pana e Era 3 in joc.
    if #waiting > 0 then
        result[waiting[1].id] = "outline"
    elseif blocker ~= nil and blocker.era == era0 and blocker.live then
        result[blocker.id] = "outline"
    end
    return result
end

-- floor; sub 1000 simplu ("950"); altfel K/M/B ca big() din simulator: 1200 -> "1.2K".
-- [D60] Era la care a ajuns jucatorul: a primei platforme necumparate, in ordinea tabelului -- aceeasi regula ca `era0`
-- din padStatuses. Cu toate cumparate, ultima era din tabel. Din ea iese titlul "Of the Landing" din balci.
-- [D67] Doar platformele `live`: cat o era noua e in constructie (platformele ei stau in tabel, dar nu in joc), cine a
-- terminat-o pe cea dinainte ramane in ea, nu intr-o era pe care n-o poate juca [D40].
function TycoonMath.era(bought: { [string]: boolean }, pads: { TycoonConfig.Pad }?): number
    local list = pads or TycoonConfig.PADS
    local last = 1
    for _, p in list do
        if not p.live then
            continue
        end
        if not bought[p.id] then
            return p.era
        end
        last = math.max(last, p.era)
    end
    return last
end

-- TREI CIFRE, cel mult cinci caractere: "1.25K", "12.3K", "232K". [D63] Pana acum erau mereu doua zecimale, deci
-- "232.95K" -- sapte caractere, care la marimea contorului de monede ieseau din pastila lui (vazut cu sonda in Studio, pe
-- salvarea owner-ului). Trei cifre sunt si mai usor de citit pentru un copil. Se TAIE, nu se rotunjeste: contorul nu arata
-- niciodata mai mult decat ai, iar "999.9K" nu sare la "1000K".
-- [D66] Moara e pe scara x3000: o noapte acolo inseamna miliarde, iar fiecare era noua inca un ordin de marime.
-- [D70, 2026-09-29] Dupa Qi, sufixele din simulatoarele Roblox (Sx, Sp, Oc, No, Dc, Ud, Dd, Td), tot de cel mult doua
-- litere, ca numarul sa ramana in cinci caractere pana la Era 8. De la 1000 Td in sus: scriere stiintifica ("1e45").
TycoonMath.UNITS = {
    { "K", 1e3 },
    { "M", 1e6 },
    { "B", 1e9 },
    { "T", 1e12 },
    { "Qa", 1e15 },
    { "Qi", 1e18 },
    { "Sx", 1e21 },
    { "Sp", 1e24 },
    { "Oc", 1e27 },
    { "No", 1e30 },
    { "Dc", 1e33 },
    { "Ud", 1e36 },
    { "Dd", 1e39 },
    { "Td", 1e42 },
} :: { { any } }

-- Cat se poate insela o impartire la un numar care nu e exact in virgula mobila (10^23 si mai sus nu sunt: 5^23 > 2^53):
-- cu mult peste eroarea ei (~3e-16), cu mult sub o cifra aratata. Se pune DOAR acolo: la o impartire exacta (un intreg
-- sub 2^53 la 10^k, k <= 22) toleranta ar muta textul cu o moneda de pe la 870T in sus ("Need 968T more" cand lipseau
-- 968T si o moneda). Fara ea, 3.2e24 taiat in jos iesea "3.1Sp", iar 5e48 iesea "4e48".
local ROUND_SLACK = 1e-15
local EXACT_STEP = 1e22

-- Peste 1000 din cea mai mare unitate: o cifra si puterea lui zece ("1e45", "9e99", "1e100"), in jos sau in sus.
local function scientific(v: number, up: boolean): string
    -- log10 poate gresi cu o unitate chiar pe o putere a lui zece: exponentul se indreapta pe valoarea insasi
    local e = math.floor(math.log10(v))
    if 10 ^ (e + 1) <= v then
        e += 1
    elseif 10 ^ e > v then
        e -= 1
    end
    local m = v / 10 ^ e -- in [1, 10), cu eroarea lui 10^e (niciodata exact aici)
    local digit = if up then math.ceil(m * (1 - ROUND_SLACK)) else math.floor(m * (1 + ROUND_SLACK))
    if digit >= 10 then
        digit, e = 1, e + 1 -- 9.3e45 in sus e "1e46"
    end
    return `{math.max(1, digit)}e{e}`
end

local function formatWith(n: number, up: boolean): string
    local v = if up then math.ceil(n) else math.floor(n)
    if v < 1000 or not math.isfinite(v) then
        return tostring(v)
    end
    for i = #TycoonMath.UNITS, 1, -1 do
        local u = TycoonMath.UNITS[i]
        local suffix, d = u[1] :: string, u[2] :: number
        if v >= d then
            local x = v / d
            -- cel mult cinci caractere [D63]: un sufix de doua litere (Qa, Qi) ia o zecimala
            local decimals =
                math.max(0, (if x < 10 then 2 elseif x < 100 then 1 else 0) - (#suffix - 1))
            local scale = 10 ^ decimals
            -- in sus, pe pasi intregi de monede: 119e9 + 1 lipsa trebuie sa scrie "120B", nu "119B". Amandoua sensurile
            -- impart la acelasi pas; toleranta doar cand pasul nu e exact (vezi ROUND_SLACK)
            local step = d / scale
            local slack = if step > EXACT_STEP then ROUND_SLACK else 0
            local shown = if up
                then math.ceil(v / step * (1 - slack)) / scale
                else math.floor(v / step * (1 + slack)) / scale
            if shown >= 1000 then
                -- 999.5K rotunjit in sus e "1M", nu "1000K"; dupa cea mai mare unitate, scrierea stiintifica. Unitatea
                -- urmatoare se ia din tabel, nu d * 1000: 1e21 * 1000 nu e exact literalul 1e24, iar apelul s-ar fi
                -- intors la nesfarsit pe aceeasi unitate
                local nextUnit = TycoonMath.UNITS[i + 1]
                return if nextUnit ~= nil
                    then formatWith(nextUnit[2] :: number, up)
                    else scientific(v, up)
            end
            local s = string.format(`%.{decimals}f`, shown)
            if decimals > 0 then
                s = s:gsub("0+$", ""):gsub("%.$", "")
            end
            return s .. suffix
        end
    end
    return tostring(v)
end

function TycoonMath.formatNumber(n: number): string
    return formatWith(n, false)
end

-- [D67, audit] Ca formatNumber, dar rotunjit IN SUS la cifra aratata: pentru "cat mai lipseste". Taiat in jos, placa scria
-- "Need 119B more" cand lipseau 119.38B; strangeai 119B si tot nu ajungea [D40].
function TycoonMath.formatNumberUp(n: number): string
    return formatWith(n, true)
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
