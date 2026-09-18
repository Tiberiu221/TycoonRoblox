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
-- [D56] LINIA FIERULUI, CU OAMENII EI. Plasa a cincea prinde scrap, iar fierul merge pe aceiasi pasi ca lemnul:
--     plasa de scrap -> Scrap Collector (shed) -> Scrap Porter (forja) -> forja (Smelter) -> Iron Hauler
-- Cele doua linii impart doar taverna, care vinde intai fierul (bucata valoreaza mai mult) cat aduce linia lui;
-- lemnul ia restul. Orice capacitate in plus doar largeste ce se poate, deci nicio cumparatura nu scade venitul.
-- Fara Forge si Fifth Net totul iese exact ca minimul celor sase debite de mai sus. In D55 aceiasi trei oameni
-- duceau ambele marfuri, iar forja mergea singura.
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
    forgeLevel: number, -- [D55] forja
    workshop: boolean, -- Forge (platforma `workshop`) e cumparata: fara ea forja nu exista
    sackBig: boolean,
    -- cheile: toate meseriile din StationConfig.ROLES, mereu toate
    crews: { [string]: Crew },
    priceMult: number,
    bells: number,
    indexFound: number,
    rebirths: number,
}

export type Rates = {
    catch: number, -- tot ce prind plasele, lemn si scrap (pentru afisaj)
    woodCatch: number,
    scrapCatch: number, -- 0 cat linia fierului e inchisa (fara Forge sau fara plasa de scrap)
    collect: number,
    port: number,
    sawing: number,
    haul: number,
    scrapCollect: number, -- [D56] linia fierului; 0 cat e inchisa
    scrapPort: number,
    forging: number,
    ironHaul: number,
    sales: number,
    wood: number, -- bucati de lemn livrate pe secunda
    scrap: number, -- bucati de fier livrate pe secunda (scrap-ul topit)
    delivered: number, -- wood + scrap
    bottleneck: string, -- veriga care tine venitul: una din StationConfig.LINKS
    woodBottleneck: string, -- [D56] veriga slaba a lemnului: nets | collect | port | saw | haul | dock
    ironBottleneck: string, -- [D56] a fierului: nets | scrapCollect | scrapPort | forge | ironHaul | dock; "" inchisa
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

-- Cel mai mare prag trecut urcand de la `from` la `to` (from < prag <= to), sau nil. O cumparare x10 poate sari peste
-- un prag fara sa se opreasca pe el: tot acolo s-a dublat debitul, deci tot acolo se sarbatoreste.
function ChainMath.milestoneCrossed(from: number, to: number): number?
    local crossed: number? = nil
    for _, t in StationConfig.MILESTONES do
        if t > from and t <= to then
            crossed = t
        end
    end
    return crossed
end

-- [D62, pasul 5] RANGUL unui nivel, pentru ce se VEDE: 0 sub primul prag, apoi 1 / 2 / 3 la pragurile 10 / 25 / 50.
-- Plasa isi schimba desenul si insigna `Lv N` culoarea (bronz, argint, aur). Pragurile de dincolo de 50 dubleaza in
-- continuare debitul, dar nu mai au desen: rangul ramane 3.
ChainMath.RANK_MAX = 3
function ChainMath.rankOf(level: number): number
    local rank = 0
    for i = 1, ChainMath.RANK_MAX do
        local threshold = StationConfig.MILESTONES[i]
        if threshold ~= nil and level >= threshold then
            rank = i
        end
    end
    return rank
end

-- [D62, pasul 5] A doua infatisare a cladirilor lantului (gaterul, taverna, forja) vine la rangul 2, adica la pragul
-- 25: acelasi prag la care debitul se dubleaza a doua oara, deci cladirea se schimba exact cand simti saltul.
ChainMath.GRAND_RANK = 2
function ChainMath.isGrand(level: number): boolean
    return ChainMath.rankOf(level) >= ChainMath.GRAND_RANK
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

-- [D55] Cat topeste forja cand cineva sta la ea (Smelter sau tu), la treapta 1.
function ChainMath.forgeCap(level: number): number
    return ChainMath.levelOutput(StationConfig.FORGE_BASE_RATE, level, "forge")
end

-- [D56] Cat topeste forja ACUM, in lume -- ca `sawSpeed`: cu Smelter-i, tot timpul; fara, doar cat esti langa ea.
function ChainMath.forgeSpeed(level: number, crew: Crew, present: boolean): number
    local cap = ChainMath.forgeCap(level)
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return if present then cap else 0
end

-- [D56] Linia fierului e deschisa: ai Forge si plasa de scrap. Pana la shed, culesul si dusul scrap-ului sunt
-- pasii tai de mana, ca turul de lemn din capitolul 1.
function ChainMath.ironOpen(s: State): boolean
    if not s.workshop then
        return false
    end
    for _, n in s.nets do
        if n.kind == "scrap" then
            return true
        end
    end
    return false
end

-- ---- oamenii [D49] ---------------------------------------------------------------------------

function ChainMath.tierMult(tier: number): number
    return 1 + StationConfig.TIER_STEP * (tier - 1)
end

-- Cat costa trecerea de la treapta `tier` la `tier + 1` (25 / 75 / 225 / 675).
function ChainMath.tierCost(tier: number): number
    return StationConfig.TIER_COST_BASE * StationConfig.TIER_COST_GROWTH ^ (tier - 1)
end

-- Linia fiecarei meserii cu pasi de mana [D56]: "wood" sau "iron" (StationConfig.LINE_STEPS).
local lineOfRole: { [string]: string } = {}
for line, steps in StationConfig.LINE_STEPS do
    for _, role in steps do
        lineOfRole[role] = line
    end
end
ChainMath.LINE_OF_ROLE = lineOfRole

-- Cati din pasii unei linii n-au inca om [D56]; 0 cat linia fierului e inchisa. Fara `line`, lemnul.
function ChainMath.manualSteps(s: State, line: string?): number
    local which = line or "wood"
    if which == "iron" and not ChainMath.ironOpen(s) then
        return 0
    end
    local n = 0
    for _, role in StationConfig.LINE_STEPS[which] do
        if s.crews[role].count == 0 then
            n += 1
        end
    end
    return n
end

-- Cat face jucatorul pe fiecare pas fara om al unei linii: timpul lui, impartit la cati pasi a lasat nepreluati
-- in linia aia [D56 -- fiecare linie are timpul tau intreg]. Fara pasi de mana, 0. Fara `line`, lemnul.
function ChainMath.playerShare(s: State, line: string?): number
    local n = ChainMath.manualSteps(s, line)
    if n == 0 then
        return 0
    end
    local labor = StationConfig.PLAYER_LABOR * (if s.sackBig then StationConfig.SACK_BONUS else 1.0)
    return labor / n
end

-- Debitul unui pas de drum: oamenii lui, sau partea ta din timp pe linia lui.
local function walkRate(s: State, role: string): number
    local crew = s.crews[role]
    if crew.count > 0 then
        return StationConfig.ROLE_BASE[role] * ChainMath.tierMult(crew.tier) * crew.count
    end
    return ChainMath.playerShare(s, lineOfRole[role])
end

-- Veriga gaterului: Sawyerii il tin pornit tot timpul; fara ei taie doar cat stai tu langa el,
-- adica partea ta din timp [D49].
local function sawLink(s: State): number
    local cap = ChainMath.sawCap(s.sawLevel)
    local crew = s.crews.sawyer
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap / ChainMath.manualSteps(s, "wood")
end

-- [D56] Veriga forjei, ca a gaterului: Smelter-ii o tin pornita tot timpul; fara ei topeste doar cat stai tu langa
-- ea. Cat linia fierului e inchisa, nimic.
local function forgeLink(s: State): number
    if not ChainMath.ironOpen(s) then
        return 0
    end
    local cap = ChainMath.forgeCap(s.forgeLevel)
    local crew = s.crews.smelter
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap / ChainMath.manualSteps(s, "iron")
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
    elseif role == "smelter" then
        return forgeLink(s)
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

-- Verigile unei linii, in ordinea LINKS: (veriga, debit). `nets` = plasele liniei.
local function woodLinks(r: Rates): { { string | number } }
    return {
        { "nets", r.woodCatch },
        { "collect", r.collect },
        { "port", r.port },
        { "saw", r.sawing },
        { "haul", r.haul },
    }
end
local function ironLinks(r: Rates): { { string | number } }
    return {
        { "nets", r.scrapCatch },
        { "scrapCollect", r.scrapCollect },
        { "scrapPort", r.scrapPort },
        { "forge", r.forging },
        { "ironHaul", r.ironHaul },
    }
end

-- Primul minim dintr-o linie (la egalitate, cel dinainte).
local function firstAt(links: { { string | number } }, value: number): string
    for _, entry in links do
        if entry[2] :: number == value then
            return entry[1] :: string
        end
    end
    return links[1][1] :: string
end

-- [D56] (veriga care tine venitul, veriga slaba a lemnului, a fierului). Port litera cu litera al lui
-- `bottlenecks` din simulator. Veriga care tine venitul: cea al carei pas in plus ar aduce cei mai multi bani pe
-- bucata, la egalitate cea dinainte in LINKS; lemnul tinut de o veriga a lui valoreaza o bucata de lemn, fierul o
-- bucata de fier -- sau doar diferenta, cand taverna e plina si fierul ia locul lemnului; taverna, cand ea e
-- marginea, ce ar mai vinde. Veriga slaba a unei linii: primul minim din linie, sau taverna cand ea e marginea.
-- Fara linia fierului iese PRIMUL minim din cele sase -- regula de dinainte [D49].
local function pickBottlenecks(r: Rates): (string, string, string)
    local wl, il = woodLinks(r), ironLinks(r)
    local ironIsOpen = r.scrapCatch > 0
    local woodMax = math.min(r.woodCatch, r.collect, r.port, r.sawing, r.haul)
    local ironMax = math.min(r.scrapCatch, r.scrapCollect, r.scrapPort, r.forging, r.ironHaul)
    local woodByDock = r.wood == r.sales - r.scrap and r.wood < woodMax
    local ironByDock = ironIsOpen and r.scrap == r.sales and r.scrap < ironMax
    local swap = AVG.scrap - (if woodByDock then AVG.wood else 0)
    local gains: { [string]: number } = {}
    for _, link in LINKS do
        gains[link] = 0
    end
    if ironIsOpen and not ironByDock then
        for _, entry in il do
            local link, value = entry[1] :: string, entry[2] :: number
            if value == r.scrap then
                gains[link] = math.max(gains[link], swap)
            end
        end
    end
    if not woodByDock then
        for _, entry in wl do
            local link, value = entry[1] :: string, entry[2] :: number
            if value == r.wood then
                gains[link] = math.max(gains[link], AVG.wood)
            end
        end
    end
    if ironByDock then
        gains.dock = AVG.scrap
    elseif woodByDock then
        gains.dock = AVG.wood
    end
    local best = "nets"
    for _, link in LINKS do
        if gains[link] > gains[best] then
            best = link
        end
    end
    local woodBn = if woodByDock then "dock" else firstAt(wl, woodMax)
    local ironBn = ""
    if ironIsOpen then
        ironBn = if ironByDock then "dock" else firstAt(il, ironMax)
    end
    return best, woodBn, ironBn
end

-- Cele doua linii, din debitele verigilor [D56]. Fierul intai la taverna, cat aduce linia lui; lemnul din ce
-- ramane. `math.min` alege, nu calculeaza: da exact bitul pe care il da `min()` din Python.
local function allocate(r: Rates): Rates
    local ironMax = math.min(r.scrapCatch, r.scrapCollect, r.scrapPort, r.forging, r.ironHaul)
    local woodMax = math.min(r.woodCatch, r.collect, r.port, r.sawing, r.haul)
    r.scrap = math.min(ironMax, r.sales)
    r.wood = math.min(woodMax, r.sales - r.scrap)
    r.delivered = r.wood + r.scrap
    r.bottleneck, r.woodBottleneck, r.ironBottleneck = pickBottlenecks(r)
    return r
end

local function catches(s: State): (number, number)
    local wood, scrap = 0.0, 0.0
    local open = ChainMath.ironOpen(s)
    for _, n in s.nets do
        if n.kind == "scrap" then
            if open then
                scrap += ChainMath.netRate(n)
            end
        else
            wood += ChainMath.netRate(n)
        end
    end
    return wood, scrap
end

local function emptyRates(woodCatch: number, scrapCatch: number): Rates
    return {
        catch = woodCatch + scrapCatch,
        woodCatch = woodCatch,
        scrapCatch = scrapCatch,
        collect = 0,
        port = 0,
        sawing = 0,
        haul = 0,
        scrapCollect = 0,
        scrapPort = 0,
        forging = 0,
        ironHaul = 0,
        sales = 0,
        wood = 0,
        scrap = 0,
        delivered = 0,
        bottleneck = "nets",
        woodBottleneck = "nets",
        ironBottleneck = "",
    }
end

function ChainMath.rates(s: State): Rates
    local r = emptyRates(catches(s))
    r.collect = walkRate(s, "collector")
    r.port = walkRate(s, "porter")
    r.sawing = sawLink(s)
    r.haul = walkRate(s, "hauler")
    r.scrapCollect = walkRate(s, "scrapCollector")
    r.scrapPort = walkRate(s, "scrapPorter")
    r.forging = forgeLink(s)
    r.ironHaul = walkRate(s, "ironHauler")
    r.sales = ChainMath.dockSpeed(s.dockLevel, s.crews.trader)
    return allocate(r)
end

-- CE MERGE FARA TINE. Plasele se umplu singure, dar fiecare pas de dupa ele are nevoie de cineva:
-- fara tine, un pas fara om sta, iar debarcaderul fara Negustor nu vinde. Deci venitul pasiv cere
-- TOATE meseriile unei linii [D49] -- si de aceea pastila "IDLE" apare abia atunci: se CASTIGA. [D56] Forja
-- are si ea omul ei: fara Smelter, fara tine, sta.
function ChainMath.idleRates(s: State): Rates
    local function staffed(role: string, value: number): number
        return if s.crews[role].count > 0 then value else 0
    end
    local r = emptyRates(catches(s))
    r.collect = staffed("collector", walkRate(s, "collector"))
    r.port = staffed("porter", walkRate(s, "porter"))
    r.sawing = staffed("sawyer", sawLink(s))
    r.haul = staffed("hauler", walkRate(s, "hauler"))
    r.scrapCollect = staffed("scrapCollector", walkRate(s, "scrapCollector"))
    r.scrapPort = staffed("scrapPorter", walkRate(s, "scrapPorter"))
    r.forging = staffed("smelter", forgeLink(s))
    r.ironHaul = staffed("ironHauler", walkRate(s, "ironHauler"))
    r.sales = staffed("trader", ChainMath.dockSpeed(s.dockLevel, s.crews.trader))
    return allocate(r)
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
        sackBig = false,
        crews = ChainMath.emptyCrews(),
        priceMult = 1.0,
        bells = 1.0,
        indexFound = 0,
        rebirths = 0,
    }
end

return ChainMath
