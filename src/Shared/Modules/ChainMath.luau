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
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local ChainMath = {}

export type Net = { base: number, baseLane: number, level: number }
export type Crew = { count: number, tier: number }

export type State = {
    nets: { Net },
    sawLevel: number,
    dockLevel: number,
    sackBig: boolean,
    -- cheile: collector, porter, sawyer, hauler, trader (StationConfig.ROLES), mereu toate cinci
    crews: { [string]: Crew },
    priceMult: number,
    bells: number,
    indexFound: number,
    rebirths: number,
}

export type Rates = {
    catch: number,
    collect: number,
    port: number,
    sawing: number,
    haul: number,
    sales: number,
    delivered: number,
    bottleneck: string, -- "nets" | "collect" | "port" | "saw" | "haul" | "dock"
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

-- Cea mai departata banda atinsa de vreo plasa. Ea decide ce marfuri exista in joc.
function ChainMath.lanesReached(s: State): number
    local best = 1
    for _, n in s.nets do
        best = math.max(best, ChainMath.netLane(n.baseLane, n.level))
    end
    return best
end

-- Valoarea medie a unei bucati prinse. Marfurile bune cer benzi mai departe de mal: pana ajungi
-- acolo, ponderea lor se varsa in lemn (nu dispare, doar nu apare inca).
function ChainMath.avgValue(s: State): number
    local lanes = ChainMath.lanesReached(s)
    -- ORDINEA OPERATIILOR e cea din Python, litera cu litera: intai se varsa in lemn ponderile
    -- marfurilor inca inaccesibile, in ordinea din GOODS, si abia apoi se aduna tot. Alta ordine
    -- da alt ultim bit si testul de paritate cade. Scandurile (share 0) adauga 0.
    local goods = TycoonConfig.GOODS
    local driftShare = goods[1].share
    for i = 2, #goods do
        local g = goods[i]
        if g.minLanes ~= nil and (g.minLanes :: number) > lanes then
            driftShare += g.share
        end
    end
    local total = driftShare * goods[1].value
    for i = 2, #goods do
        local g = goods[i]
        if not (g.minLanes ~= nil and (g.minLanes :: number) > lanes) then
            total += g.share * g.value
        end
    end
    return total
end

-- ---- lantul ----------------------------------------------------------------------------------

local function pickBottleneck(r: Rates): string
    -- ORDINEA E CONTRACTUL cu simulatorul: `min()` din Python intoarce PRIMUL minim din
    -- (nets, collect, port, saw, haul, dock), iar `<` strict in exact ordinea asta pastreaza la
    -- egalitate tot primul.
    local bottleneck, worst = "nets", r.catch
    if r.collect < worst then
        bottleneck, worst = "collect", r.collect
    end
    if r.port < worst then
        bottleneck, worst = "port", r.port
    end
    if r.sawing < worst then
        bottleneck, worst = "saw", r.sawing
    end
    if r.haul < worst then
        bottleneck, worst = "haul", r.haul
    end
    if r.sales < worst then
        bottleneck = "dock"
    end
    return bottleneck
end

function ChainMath.rates(s: State): Rates
    local catch = 0.0
    for _, n in s.nets do
        catch += ChainMath.netRate(n)
    end
    local r: Rates = {
        catch = catch,
        collect = walkRate(s, "collector"),
        port = walkRate(s, "porter"),
        sawing = sawLink(s),
        haul = walkRate(s, "hauler"),
        sales = ChainMath.dockSpeed(s.dockLevel, s.crews.trader),
        delivered = 0,
        bottleneck = "nets",
    }
    -- `math.min` alege, nu calculeaza: da exact bitul pe care il da `min()` din Python
    r.delivered = math.min(r.catch, r.collect, r.port, r.sawing, r.haul, r.sales)
    r.bottleneck = pickBottleneck(r)
    return r
end

-- CE MERGE FARA TINE. Plasele se umplu singure, dar fiecare pas de dupa ele are nevoie de cineva:
-- fara tine, un pas fara om sta, iar debarcaderul fara Negustor nu vinde. Deci venitul pasiv cere
-- TOATE CINCI meseriile [D49] -- si de aceea pastila "IDLE" apare abia atunci: se CASTIGA.
function ChainMath.idleRates(s: State): Rates
    local catch = 0.0
    for _, n in s.nets do
        catch += ChainMath.netRate(n)
    end
    local function staffed(role: string, value: number): number
        return if s.crews[role].count > 0 then value else 0
    end
    local r: Rates = {
        catch = catch,
        collect = staffed("collector", walkRate(s, "collector")),
        port = staffed("porter", walkRate(s, "porter")),
        sawing = staffed("sawyer", sawLink(s)),
        haul = staffed("hauler", walkRate(s, "hauler")),
        sales = staffed("trader", ChainMath.dockSpeed(s.dockLevel, s.crews.trader)),
        delivered = 0,
        bottleneck = "nets",
    }
    r.delivered = math.min(r.catch, r.collect, r.port, r.sawing, r.haul, r.sales)
    r.bottleneck = pickBottleneck(r)
    return r
end

function ChainMath.idleIncome(s: State): number
    local r = ChainMath.idleRates(s)
    return r.delivered
        * ChainMath.avgValue(s)
        * s.priceMult
        * s.bells
        * (1 + 0.01 * s.indexFound)
        * (1 + 0.5 * s.rebirths)
end

function ChainMath.income(s: State): number
    local r = ChainMath.rates(s)
    return r.delivered
        * ChainMath.avgValue(s)
        * s.priceMult
        * s.bells
        * (1 + 0.01 * s.indexFound)
        * (1 + 0.5 * s.rebirths)
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
        nets[i] = { base = n.base, baseLane = n.baseLane, level = n.level }
    end
    local crews: { [string]: Crew } = {}
    for role, crew in s.crews do
        crews[role] = { count = crew.count, tier = crew.tier }
    end
    return {
        nets = nets,
        sawLevel = s.sawLevel,
        dockLevel = s.dockLevel,
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
        sackBig = false,
        crews = ChainMath.emptyCrews(),
        priceMult = 1.0,
        bells = 1.0,
        indexFound = 0,
        rebirths = 0,
    }
end

return ChainMath
