--!strict
-- Lantul cu sase verigi si scara nivelurilor. Modul PUR (fara `game`, fara ceas): aceleasi cifre
-- pe server, pe client si in Lune, deci se poate testa si nu poate sa se contrazica cu serverul.
--
-- PORT BIT-EXACT al lui `scripts/economy/sim_tycoon.py`: aceleasi formule, aceeasi ordine a
-- operatiilor. `tests/ChainMath.test.luau` verifica valorile una cate una fata de simulator.
--
-- IDEEA CENTRALA: venitul NU e o suma, e MINIMUL a sase debite [D49].
--     plasele -> adunatul (Collector) -> dusul la gater (Porter) -> taiatul (gaterul, Sawyer)
--             -> dusul la debarcader (Hauler) -> vanzarea (debarcaderul, Negustorul)
-- Fiecare pas fara om il faci TU, iar timpul tau se imparte intre ei. Veriga cea mai slaba decide
-- venitul -- si tocmai repararea ei e decizia jucatorului. Un upgrade pe o veriga care nu e
-- gatuirea da EXACT ZERO, si asta se si scrie pe ecran, nu se ascunde dupa o cifra frumoasa [D40].
--
-- [D55] RESTURILE AU DRUMUL LOR. Plasa a cincea prinde scrap: Collector-ul il lasa la shed, Porter-ul il
-- duce la atelier (forja, cu niveluri, merge singura), Hauler-ul duce fierul la taverna. Aceiasi oameni duc
-- ambele marfuri: capacitatea lor COMUNA (adunat, dus, dus la taverna, vandut) merge intai la scrap -- cat
-- poate forja topi, bucata lui valoreaza mai mult --, iar restul la lemn, cat poate gaterul taia. Orice
-- capacitate in plus doar largeste ce se poate, deci nicio cumparatura nu scade venitul. Fara scrap (S = 0)
-- totul iese exact ca minimul celor sase debite de mai sus.
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local ChainMath = {}

-- `kind`: ce prinde plasa [D55] -- "wood" (driftwood + finds) sau "scrap" (scrap + finds)
export type Net = { base: number, baseLane: number, level: number, kind: string }
export type Crew = { count: number, tier: number }

export type State = {
    nets: { Net },
    sawLevel: number,
    dockLevel: number,
    forgeLevel: number, -- [D55] forja atelierului
    workshop: boolean, -- atelierul e cumparat: fara el forja nu exista
    scrapShed: boolean, -- shed-ul de scrap: fara el plasa de scrap n-are unde lasa
    sackBig: boolean,
    -- cheile: collector, porter, sawyer, hauler, trader (StationConfig.ROLES), mereu toate cinci
    crews: { [string]: Crew },
    priceMult: number,
    bells: number,
    indexFound: number,
    rebirths: number,
}

export type Rates = {
    catch: number, -- tot ce prind plasele, lemn si scrap (pentru afisaj)
    woodCatch: number,
    scrapCatch: number, -- 0 fara shed
    collect: number,
    port: number,
    sawing: number,
    forging: number, -- 0 fara atelier
    haul: number,
    sales: number,
    wood: number, -- bucati de lemn livrate pe secunda
    scrap: number, -- bucati de scrap livrate (ca fier) pe secunda
    delivered: number, -- wood + scrap
    bottleneck: string, -- "nets" | "collect" | "port" | "saw" | "forge" | "haul" | "dock"
}

-- ---- scara nivelurilor -----------------------------------------------------------------------

function ChainMath.milestoneMult(level: number): number
    local m = 1.0
    for _, t in StationConfig.MILESTONES do
        if level >= t then
            m *= StationConfig.MILESTONE_MULT
        end
    end
    return m
end

-- Urmatorul prag, sau nil daca nu mai e niciunul. Panoul de nivel scrie "Next boost at level N"
-- si deseneaza bara pana acolo -- de aceea trebuie sa fie o cifra, nu un text.
function ChainMath.nextMilestone(level: number): number?
    for _, t in StationConfig.MILESTONES do
        if level < t then
            return t
        end
    end
    return nil
end

function ChainMath.levelOutput(base: number, level: number, kind: string): number
    local inc = StationConfig.LEVEL_INC[kind] or StationConfig.LEVEL_INC_DEFAULT
    return base * (1 + inc * (level - 1)) * ChainMath.milestoneMult(level)
end

-- Cat costa trecerea de la `level` la `level + 1`.
function ChainMath.levelCost(baseCost: number, level: number): number
    return baseCost * StationConfig.LEVEL_GROWTH ^ (level - 1)
end

-- Cat costa `count` niveluri la rand, pornind de la `level`. Butoanele x10/x50/Max cer suma, si
-- suma trebuie calculata la fel pe client (ca sa scrie pretul) si pe server (ca sa-l incaseze).
function ChainMath.bulkCost(baseCost: number, level: number, count: number): number
    local total = 0.0
    for i = 0, count - 1 do
        total += ChainMath.levelCost(baseCost, level + i)
    end
    return total
end

-- Cate niveluri isi permite jucatorul, pornind de la `level`, cu `coins` monede. Pentru "Max".
function ChainMath.affordableLevels(
    baseCost: number,
    level: number,
    coins: number,
    cap: number
): number
    local total, n = 0.0, 0
    while n < cap do
        local next = total + ChainMath.levelCost(baseCost, level + n)
        if next > coins then
            break
        end
        total = next
        n += 1
    end
    return n
end

-- ---- cladirile -------------------------------------------------------------------------------

-- Pragurile duc plasa mai in larg: la nivel 10 o banda, la 25 inca una. Se VEDE pe ecran (plasa se
-- muta si incepe sa prinda altceva), nu e doar o cifra care creste.
function ChainMath.netLane(baseLane: number, level: number): number
    local extra = (if level >= 10 then 1 else 0) + (if level >= 25 then 1 else 0)
    return math.min(3, baseLane + extra)
end

function ChainMath.netBase(index: number): number
    return StationConfig.NET_BASE_RATE * StationConfig.NET_BASE_GROWTH ^ (index - 1)
end

function ChainMath.netUpgradeBase(index: number): number
    return StationConfig.NET_UPGRADE_BASE_COST * StationConfig.NET_BASE_GROWTH ^ (index - 1)
end

function ChainMath.netRate(net: Net): number
    return ChainMath.levelOutput(net.base, net.level, "nets")
end

-- Cat taie gaterul cand cineva sta la el (Sawyer sau tu), la treapta 1.
function ChainMath.sawCap(level: number): number
    return ChainMath.levelOutput(StationConfig.SAW_BASE_RATE, level, "saw")
end

-- Cat vinde debarcaderul cu un Negustor de treapta 1.
function ChainMath.dockCap(level: number): number
    return ChainMath.levelOutput(StationConfig.DOCK_BASE_RATE, level, "dock")
end

-- [D55] Cat topeste forja atelierului: merge singura (fierarul vine cu atelierul); fara atelier, nimic.
function ChainMath.forgeCap(level: number): number
    return ChainMath.levelOutput(StationConfig.FORGE_BASE_RATE, level, "forge")
end

function ChainMath.forgeSpeed(workshop: boolean, level: number): number
    if not workshop then
        return 0
    end
    return ChainMath.forgeCap(level)
end

-- ---- oamenii [D49] ---------------------------------------------------------------------------

function ChainMath.tierMult(tier: number): number
    return 1 + StationConfig.TIER_STEP * (tier - 1)
end

-- Cat costa trecerea de la treapta `tier` la `tier + 1` (25 / 75 / 225 / 675).
function ChainMath.tierCost(tier: number): number
    return StationConfig.TIER_COST_BASE * StationConfig.TIER_COST_GROWTH ^ (tier - 1)
end

-- Cati din pasii jucatorului n-au inca om.
function ChainMath.manualSteps(s: State): number
    local n = 0
    for _, role in StationConfig.MANUAL_ROLES do
        if s.crews[role].count == 0 then
            n += 1
        end
    end
    return n
end

-- Cat face jucatorul pe fiecare pas fara om: timpul lui, impartit la cati pasi a lasat nepreluati.
-- Cu toti oamenii angajati nu mai face nimic, deci 0.
function ChainMath.playerShare(s: State): number
    local n = ChainMath.manualSteps(s)
    if n == 0 then
        return 0
    end
    local labor = StationConfig.PLAYER_LABOR * (if s.sackBig then StationConfig.SACK_BONUS else 1.0)
    return labor / n
end

-- Debitul unui pas de drum (collector, porter, hauler): oamenii lui, sau partea ta din timp.
local function walkRate(s: State, role: string): number
    local crew = s.crews[role]
    if crew.count > 0 then
        return StationConfig.ROLE_BASE[role] * ChainMath.tierMult(crew.tier) * crew.count
    end
    local labor = StationConfig.PLAYER_LABOR * (if s.sackBig then StationConfig.SACK_BONUS else 1.0)
    return labor / ChainMath.manualSteps(s)
end

-- Veriga gaterului: Sawyerii il tin pornit tot timpul; fara ei taie doar cat stai tu langa el,
-- adica partea ta din timp [D49].
local function sawLink(s: State): number
    local cap = ChainMath.sawCap(s.sawLevel)
    local crew = s.crews.sawyer
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap / ChainMath.manualSteps(s)
end

-- Cat taie gaterul ACUM, in lume: cu oameni, tot timpul; fara, doar cat esti langa el. Nu e
-- veriga din lant (aia e media pe timpul tau), e ce se vede pe gramada.
function ChainMath.sawSpeed(level: number, crew: Crew, present: boolean): number
    local cap = ChainMath.sawCap(level)
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return if present then cap else 0
end

-- Cat vinde debarcaderul: cu Negustori, tot timpul; fara, singur, la o treime.
function ChainMath.dockSpeed(level: number, crew: Crew): number
    local cap = ChainMath.dockCap(level)
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap * StationConfig.NO_TRADER_FACTOR
end

-- Cat duce un om de pe o meserie de drum, pe secunda (fara partea ta). 0 fara om.
function ChainMath.walkerRate(role: string, crew: Crew): number
    local base = StationConfig.ROLE_BASE[role]
    if base == nil or crew.count == 0 then
        return 0
    end
    return base * ChainMath.tierMult(crew.tier)
end

-- Debitul verigii pe care o tine meseria `role`, in starea `s`.
function ChainMath.roleLink(s: State, role: string): number
    if role == "sawyer" then
        return sawLink(s)
    elseif role == "trader" then
        return ChainMath.dockSpeed(s.dockLevel, s.crews.trader)
    end
    return walkRate(s, role)
end

-- Cea mai departata banda atinsa de vreo plasa. [D55] Nu mai decide ce se prinde (asta tine de felul
-- plasei); ramane pentru desen: pragurile 10 / 25 muta plasa mai in larg.
function ChainMath.lanesReached(s: State): number
    local best = 1
    for _, n in s.nets do
        best = math.max(best, ChainMath.netLane(n.baseLane, n.level))
    end
    return best
end

-- Valoarea medie a unei bucati prinse, pe fel de plasa [D55]. ORDINEA SUMEI e cea din simulator
-- (`AVG` din sim_tycoon.py): altfel ultimul bit difera si testul de paritate cade.
local goodValue: { [string]: number } = {}
for _, g in TycoonConfig.GOODS do
    goodValue[g.id] = g.value
end
local AVG: { [string]: number } = {}
for kind, parts in TycoonConfig.CATCH do
    local total = 0
    for _, part in parts do
        total += part.share * goodValue[part.id]
    end
    AVG[kind] = total
end
ChainMath.AVG = AVG

-- Valoarea medie a unei bucati de LEMN prinse (numele vechi, pentru cititorii de dinainte de D55).
function ChainMath.avgValue(_s: State): number
    return AVG.wood
end

-- ---- lantul ----------------------------------------------------------------------------------

local LINKS = StationConfig.LINKS

-- Veriga care tine venitul: cea al carei pas in plus ar aduce cei mai multi bani pe bucata, la egalitate
-- cea dinainte in LINKS. Port litera cu litera al lui `bottleneck_of` din simulator. Fara scrap, orice
-- veriga care tine lemnul valoreaza la fel, deci iese PRIMUL minim din cele sase -- regula de dinainte.
local function pickBottleneck(r: Rates): string
    local shared = math.min(r.collect, r.port, r.haul, r.sales)
    local scrapMax = math.min(r.scrapCatch, r.forging)
    local woodByShared = r.wood == shared - r.scrap
    local scrapSwap = AVG.scrap - (if woodByShared then AVG.wood else 0)
    local gains: { [string]: number } = {}
    for _, link in LINKS do
        gains[link] = 0
    end
    if r.wood == r.woodCatch then
        gains.nets = AVG.wood
    end
    if r.scrapCatch > 0 and r.scrap == r.scrapCatch then
        gains.nets = math.max(gains.nets, scrapSwap)
    end
    if r.wood == r.sawing then
        gains.saw = AVG.wood
    end
    if r.scrapCatch > 0 and r.scrap == r.forging then
        gains.forge = scrapSwap
    end
    local sharedLinks: { { string | number } } = {
        { "collect", r.collect },
        { "port", r.port },
        { "haul", r.haul },
        { "dock", r.sales },
    }
    for _, entry in sharedLinks do
        local link, value = entry[1] :: string, entry[2] :: number
        if value == shared then
            if r.scrap == shared and r.scrap < scrapMax then
                gains[link] = AVG.scrap
            elseif woodByShared then
                gains[link] = AVG.wood
            end
        end
    end
    local best = "nets"
    for _, link in LINKS do
        if gains[link] > gains[best] then
            best = link
        end
    end
    return best
end

-- Cele doua fluxuri prin aceiasi oameni, din debitele verigilor [D55]. `scrap` intai, cat poate forja topi;
-- `wood` din ce ramane. `math.min` alege, nu calculeaza: da exact bitul pe care il da `min()` din Python.
local function allocate(r: Rates): Rates
    local shared = math.min(r.collect, r.port, r.haul, r.sales)
    r.scrap = math.min(math.min(r.scrapCatch, r.forging), shared)
    r.wood = math.min(math.min(r.woodCatch, r.sawing), shared - r.scrap)
    r.delivered = r.wood + r.scrap
    r.bottleneck = pickBottleneck(r)
    return r
end

local function catches(s: State): (number, number)
    local wood, scrap = 0.0, 0.0
    for _, n in s.nets do
        if n.kind == "scrap" then
            if s.scrapShed then
                scrap += ChainMath.netRate(n)
            end
        else
            wood += ChainMath.netRate(n)
        end
    end
    return wood, scrap
end

function ChainMath.rates(s: State): Rates
    local woodCatch, scrapCatch = catches(s)
    return allocate({
        catch = woodCatch + scrapCatch,
        woodCatch = woodCatch,
        scrapCatch = scrapCatch,
        collect = walkRate(s, "collector"),
        port = walkRate(s, "porter"),
        sawing = sawLink(s),
        forging = ChainMath.forgeSpeed(s.workshop, s.forgeLevel),
        haul = walkRate(s, "hauler"),
        sales = ChainMath.dockSpeed(s.dockLevel, s.crews.trader),
        wood = 0,
        scrap = 0,
        delivered = 0,
        bottleneck = "nets",
    })
end

-- CE MERGE FARA TINE. Plasele se umplu singure, dar fiecare pas de dupa ele are nevoie de cineva:
-- fara tine, un pas fara om sta, iar debarcaderul fara Negustor nu vinde. Deci venitul pasiv cere
-- TOATE CINCI meseriile [D49] -- si de aceea pastila "IDLE" apare abia atunci: se CASTIGA. Forja
-- merge singura [D55].
function ChainMath.idleRates(s: State): Rates
    local woodCatch, scrapCatch = catches(s)
    local function staffed(role: string, value: number): number
        return if s.crews[role].count > 0 then value else 0
    end
    return allocate({
        catch = woodCatch + scrapCatch,
        woodCatch = woodCatch,
        scrapCatch = scrapCatch,
        collect = staffed("collector", walkRate(s, "collector")),
        port = staffed("porter", walkRate(s, "porter")),
        sawing = staffed("sawyer", sawLink(s)),
        forging = ChainMath.forgeSpeed(s.workshop, s.forgeLevel),
        haul = staffed("hauler", walkRate(s, "hauler")),
        sales = staffed("trader", ChainMath.dockSpeed(s.dockLevel, s.crews.trader)),
        wood = 0,
        scrap = 0,
        delivered = 0,
        bottleneck = "nets",
    })
end

local function valueOf(s: State, r: Rates): number
    return (r.wood * AVG.wood + r.scrap * AVG.scrap)
        * s.priceMult
        * s.bells
        * (1 + 0.01 * s.indexFound)
        * (1 + 0.5 * s.rebirths)
end

function ChainMath.idleIncome(s: State): number
    return valueOf(s, ChainMath.idleRates(s))
end

function ChainMath.income(s: State): number
    return valueOf(s, ChainMath.rates(s))
end

-- Cat adauga o cumparatura la venit. Poate fi ZERO -- vezi antetul. Cine afiseaza cifra asta
-- trebuie sa afiseze si `bottleneck`, ca jucatorul sa stie DE CE e zero.
function ChainMath.gainOf(s: State, apply: (State) -> ()): number
    local before = ChainMath.income(s)
    local probe = ChainMath.clone(s)
    apply(probe)
    return ChainMath.income(probe) - before
end

function ChainMath.clone(s: State): State
    local nets = table.create(#s.nets)
    for i, n in s.nets do
        nets[i] = { base = n.base, baseLane = n.baseLane, level = n.level, kind = n.kind }
    end
    local crews: { [string]: Crew } = {}
    for role, crew in s.crews do
        crews[role] = { count = crew.count, tier = crew.tier }
    end
    return {
        nets = nets,
        sawLevel = s.sawLevel,
        dockLevel = s.dockLevel,
        forgeLevel = s.forgeLevel,
        workshop = s.workshop,
        scrapShed = s.scrapShed,
        sackBig = s.sackBig,
        crews = crews,
        priceMult = s.priceMult,
        bells = s.bells,
        indexFound = s.indexFound,
        rebirths = s.rebirths,
    }
end

function ChainMath.emptyCrews(): { [string]: Crew }
    local crews: { [string]: Crew } = {}
    for _, role in StationConfig.ROLES do
        crews[role] = { count = 0, tier = 1 }
    end
    return crews
end

function ChainMath.empty(): State
    return {
        nets = {},
        sawLevel = 1,
        dockLevel = 1,
        forgeLevel = 1,
        workshop = false,
        scrapShed = false,
        sackBig = false,
        crews = ChainMath.emptyCrews(),
        priceMult = 1.0,
        bells = 1.0,
        indexFound = 0,
        rebirths = 0,
    }
end

return ChainMath
