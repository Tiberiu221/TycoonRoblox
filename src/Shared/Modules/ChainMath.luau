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
--
-- [D64] LINIILE SUNT DATE, NU COD. Forma lor sta in StationConfig (LINE_ORDER / LINES / PROCESSORS / SELLERS), iar
-- motorul de mai jos (`flow`) merge peste un `Model`, deci duce oricate linii si oricati vanzatori: Era 2 adauga
-- randuri in tabel, nu ramuri in cod. `Rates` ramane VEDEREA PLATA a Erei 1 peste `Flow` (woodCatch, sawing, sales,
-- ...): asa o citesc serverul, meniurile si tabelul de aur al simulatorului. Planul: docs/PLAN-MOTOR-N-LINII.md.
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
    -- [D65] Era 2: roata de apa porneste turnatoria (linia pieselor), cuptorul de cupru linia cuprului
    wheel: boolean,
    furnace: boolean,
    foundryLevel: number,
    furnaceLevel: number,
    marketLevel: number,
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

-- [D64] Forma liniilor (oglinda tipurilor din StationConfig; `require`-ul cu doua cai nu le poate aduce de acolo).
export type Step = { role: string, link: string, kind: string } -- kind: "walk" | "processor"
export type Line = { netKind: string, openFlag: string?, seller: string, steps: { Step } }
export type Processor = { base: number, levelField: string }
export type Seller = { role: string, base: number, levelField: string, priority: { string } }

-- Tot ce-i trebuie motorului ca sa socoteasca un lant. Jocul foloseste unul singur, facut din StationConfig; testele
-- isi fac altele, cu linii de proba, ca sa dovedeasca faptul ca motorul chiar duce a treia linie si al doilea vanzator.
export type Model = {
    lineOrder: { string }, -- ordinea ORICAREI sume pe linii (virgula mobila) si a verigilor in `links`
    lines: { [string]: Line },
    processors: { [string]: Processor },
    sellerOrder: { string },
    sellers: { [string]: Seller },
    roleBase: { [string]: number },
    avg: { [string]: number }, -- valoarea medie a unei bucati, pe fel de plasa
    links: { string }, -- derivat: plasele, liniile in ordine, vanzatorii; la egalitate castiga veriga dinainte
    lineOfRole: { [string]: string }, -- derivat
    roleOfLink: { [string]: string }, -- derivat: omul fiecarei verigi (si al vanzatorilor)
    lineOfNetKind: { [string]: string }, -- derivat: pe ce linie curge ce prinde un fel de plasa
}

-- Ce curge pe o linie, pe secunda.
export type LineFlow = {
    catch: number, -- cat prind plasele ei (0 cat linia e inchisa)
    values: { number }, -- debitul fiecarui pas, in ordinea `lines[linie].steps`
    ownMax: number, -- marginea liniei inaintea vanzatorului: minimul dintre plase si pasi
    active: boolean, -- intra in socoteala verigilor: mereu pentru o linie fara conditie, altfel doar cat prinde ceva
    room: number, -- cat mai avea vanzatorul cand i-a venit randul
    delivered: number, -- bucati livrate
    bySeller: boolean, -- vanzatorul e marginea liniei
    bottleneck: string, -- veriga slaba a liniei; "" cat nu e activa
}

export type Flow = {
    lines: { [string]: LineFlow },
    capacity: { [string]: number }, -- cat vinde fiecare vanzator
    catch: number, -- tot ce prind plasele, pe toate liniile
    delivered: number, -- tot ce se livreaza
    bottleneck: string, -- veriga care tine venitul
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

-- [D65] CINCI PLASE PE ERA: a k-a plasa a unei ere are baza celei de-a k-a plase a Erei 1 (`index` numara toate
-- plasele, de la 1: a sasea e prima a Erei 2).
function ChainMath.netBase(index: number): number
    local inEra = (index - 1) % StationConfig.NETS_PER_ERA
    return StationConfig.NET_BASE_RATE * StationConfig.NET_BASE_GROWTH ^ inEra
end

-- De cate ori costa mai mult nivelurile plasei `index`: 1 in Era 1, ERA2_MULT in Era 2.
function ChainMath.netEraMult(index: number): number
    return if index <= StationConfig.NETS_PER_ERA then 1.0 else StationConfig.ERA2_MULT
end

function ChainMath.netUpgradeBase(index: number): number
    local inEra = (index - 1) % StationConfig.NETS_PER_ERA
    return StationConfig.NET_UPGRADE_BASE_COST
        * StationConfig.NET_BASE_GROWTH ^ inEra
        * ChainMath.netEraMult(index)
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

-- ---- oamenii [D49] ---------------------------------------------------------------------------

function ChainMath.tierMult(tier: number): number
    return 1 + StationConfig.TIER_STEP * (tier - 1)
end

-- Cat costa trecerea de la treapta `tier` la `tier + 1` (25 / 75 / 225 / 675). [D65] Oamenii unei ere noi muta marfa
-- de zeci de ori mai scumpa, deci si uneltele lor costa pe masura (StationConfig.ROLE_COST_MULT); fara `role`, Era 1.
function ChainMath.tierCost(tier: number, role: string?): number
    local mult = if role ~= nil then StationConfig.ROLE_COST_MULT[role] or 1.0 else 1.0
    return StationConfig.TIER_COST_BASE * StationConfig.TIER_COST_GROWTH ^ (tier - 1) * mult
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

-- ---- modelul [D64] ---------------------------------------------------------------------------

-- Face un model din tabelele liniilor si deriva ce se poate deriva. Pica pe un tabel care nu se leaga: o linie care
-- lipseste din randul vanzatorului ei n-ar livra niciodata nimic, in tacere.
function ChainMath.model(
    lineOrder: { string },
    lines: { [string]: Line },
    processors: { [string]: Processor },
    sellerOrder: { string },
    sellers: { [string]: Seller },
    roleBase: { [string]: number },
    avg: { [string]: number }
): Model
    local links: { string } = { "nets" }
    local lineOfRole: { [string]: string } = {}
    local roleOfLink: { [string]: string } = {}
    local lineOfNetKind: { [string]: string } = {}
    for _, line in lineOrder do
        local spec = lines[line]
        lineOfNetKind[spec.netKind] = line
        assert(
            table.find(sellers[spec.seller].priority, line) ~= nil,
            `linia {line} lipseste din randul vanzatorului ei`
        )
        for _, step in spec.steps do
            table.insert(links, step.link)
            lineOfRole[step.role] = line
            roleOfLink[step.link] = step.role
        end
    end
    for _, seller in sellerOrder do
        table.insert(links, seller)
        roleOfLink[seller] = sellers[seller].role
        for _, line in sellers[seller].priority do
            assert(lines[line].seller == seller, `{seller}: linia {line} e a altui vanzator`)
        end
    end
    return {
        lineOrder = lineOrder,
        lines = lines,
        processors = processors,
        sellerOrder = sellerOrder,
        sellers = sellers,
        roleBase = roleBase,
        avg = avg,
        links = links,
        lineOfRole = lineOfRole,
        roleOfLink = roleOfLink,
        lineOfNetKind = lineOfNetKind,
    }
end

-- Modelul jocului: liniile din StationConfig.
local GAME: Model = ChainMath.model(
    StationConfig.LINE_ORDER,
    StationConfig.LINES,
    StationConfig.PROCESSORS,
    StationConfig.SELLER_ORDER,
    StationConfig.SELLERS,
    StationConfig.ROLE_BASE,
    AVG
)
ChainMath.GAME = GAME

-- Linia fiecarei meserii cu pasi de mana [D56]: "wood" sau "iron".
ChainMath.LINE_OF_ROLE = GAME.lineOfRole

-- `State` ramane plat (sawLevel, workshop, ...): asa il fac serverul si testele. Motorul citeste campul dupa numele
-- din model (nivelul unei cladiri, conditia unei linii); o linie noua vine cu campurile ei.
local function field(s: State, name: string): any
    return (s :: any)[name]
end

-- O linie fara conditie e deschisa de la inceput. Una cu conditie cere campul ei din State si o plasa de felul ei.
-- [D56] Pana la oamenii ei, culesul si dusul sunt pasii tai de mana, ca turul de lemn din capitolul 1.
local function lineOpen(m: Model, s: State, line: string): boolean
    local spec = m.lines[line]
    local flag = spec.openFlag
    if flag == nil then
        return true
    end
    if field(s, flag) ~= true then
        return false
    end
    for _, n in s.nets do
        if n.kind == spec.netKind then
            return true
        end
    end
    return false
end

-- Cati din pasii unei linii n-au inca om; 0 cat linia e inchisa.
local function manualSteps(m: Model, s: State, line: string): number
    if not lineOpen(m, s, line) then
        return 0
    end
    local n = 0
    for _, step in m.lines[line].steps do
        if s.crews[step.role].count == 0 then
            n += 1
        end
    end
    return n
end

-- Cat face jucatorul pe fiecare pas fara om al unei linii: timpul lui, impartit la cati pasi a lasat nepreluati
-- in linia aia [D56 -- fiecare linie are timpul tau intreg]. Fara pasi de mana, 0.
local function playerShare(m: Model, s: State, line: string): number
    local n = manualSteps(m, s, line)
    if n == 0 then
        return 0
    end
    local labor = StationConfig.PLAYER_LABOR * (if s.sackBig then StationConfig.SACK_BONUS else 1.0)
    return labor / n
end

-- Debitul unui pas de drum: oamenii lui, sau partea ta din timp pe linia lui.
local function walkRate(m: Model, s: State, role: string): number
    local crew = s.crews[role]
    if crew.count > 0 then
        return m.roleBase[role] * ChainMath.tierMult(crew.tier) * crew.count
    end
    return playerShare(m, s, m.lineOfRole[role])
end

-- Veriga unei cladiri cu niveluri (gaterul [D49], forja [D56]): oamenii ei o tin pornita tot timpul; fara ei merge
-- doar cat stai tu langa ea, adica partea ta din timp. Cat linia e inchisa, nimic.
local function processorLink(m: Model, s: State, line: string, role: string, link: string): number
    if not lineOpen(m, s, line) then
        return 0
    end
    local spec = m.processors[link]
    local cap = ChainMath.levelOutput(spec.base, field(s, spec.levelField), link)
    local crew = s.crews[role]
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap / manualSteps(m, s, line)
end

-- Veriga unui vanzator (taverna): cu oamenii lui, tot timpul; fara, singur, la o treime. E singurul pas pe care
-- nu-l faci tu.
local function sellerLink(m: Model, s: State, seller: string): number
    local spec = m.sellers[seller]
    local cap = ChainMath.levelOutput(spec.base, field(s, spec.levelField), seller)
    local crew = s.crews[spec.role]
    if crew.count > 0 then
        return cap * ChainMath.tierMult(crew.tier) * crew.count
    end
    return cap * StationConfig.NO_TRADER_FACTOR
end

function ChainMath.lineOpen(s: State, line: string): boolean
    return lineOpen(GAME, s, line)
end

-- Cati din pasii unei linii n-au inca om [D56]; 0 cat linia e inchisa. Fara `line`, lemnul.
function ChainMath.manualSteps(s: State, line: string?): number
    return manualSteps(GAME, s, line or "wood")
end

-- Partea ta din timp pe fiecare pas fara om al unei linii. Fara `line`, lemnul.
function ChainMath.playerShare(s: State, line: string?): number
    return playerShare(GAME, s, line or "wood")
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

-- [D64] Cat merge ACUM, in lume, o cladire a lantului, dupa numele verigii ei (saw / forge / dock si ce mai aduce o
-- linie noua): un atelier ca `sawSpeed`, un vanzator ca `dockSpeed`. nil pentru un fel necunoscut: cine intreaba nu
-- imprumuta cifrele altei cladiri [D40].
function ChainMath.buildingSpeed(kind: string, level: number, crew: Crew, present: boolean): number?
    local processor = GAME.processors[kind]
    if processor ~= nil then
        local cap = ChainMath.levelOutput(processor.base, level, kind)
        if crew.count > 0 then
            return cap * ChainMath.tierMult(crew.tier) * crew.count
        end
        return if present then cap else 0
    end
    local seller = GAME.sellers[kind]
    if seller ~= nil then
        local cap = ChainMath.levelOutput(seller.base, level, kind)
        if crew.count > 0 then
            return cap * ChainMath.tierMult(crew.tier) * crew.count
        end
        return cap * StationConfig.NO_TRADER_FACTOR
    end
    return nil
end

-- [D64] Campul din State care tine nivelul unei cladiri a lantului (saw -> "sawLevel"), sau nil.
function ChainMath.levelField(kind: string): string?
    local spec = GAME.processors[kind] or GAME.sellers[kind]
    return if spec ~= nil then spec.levelField else nil
end

-- [D64] Veriga slaba care conteaza pentru un rand de meniu: a liniei lui (o plasa de lemn nu e tinuta de forja), iar
-- pentru un vanzator (linie nil), cea care tine venitul.
function ChainMath.lineBottleneck(f: Flow, line: string?): string
    local lf = if line ~= nil then f.lines[line] else nil
    return if lf ~= nil then lf.bottleneck else f.bottleneck
end

-- [D64] Pe ce linie curge ce prinde un fel de plasa ("scrap" -> "iron"); lemnul, pentru un fel necunoscut.
function ChainMath.lineOfNetKind(kind: string): string
    return GAME.lineOfNetKind[kind] or GAME.lineOrder[1]
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
    for _, seller in GAME.sellerOrder do
        if GAME.sellers[seller].role == role then
            return sellerLink(GAME, s, seller)
        end
    end
    local line = GAME.lineOfRole[role]
    for _, step in GAME.lines[line].steps do
        if step.role == role and step.kind == "processor" then
            return processorLink(GAME, s, line, role, step.link)
        end
    end
    return walkRate(GAME, s, role)
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

-- ---- lantul ----------------------------------------------------------------------------------

-- [D56] Scrie veriga slaba a fiecarei linii si intoarce veriga care tine venitul. Port al lui `bottlenecks` din
-- simulator.
--   Veriga care tine venitul: cea al carei pas in plus ar aduce cei mai multi bani pe bucata, la egalitate cea
--   dinainte in `links`. O veriga "tine" o linie cand debitul ei e chiar ce livreaza linia (min-ul exact):
--     * o linie tinuta de o veriga a ei -> valoarea bucatii ei. Daca insa vanzatorul e plin, bucata in plus ia locul
--       uneia de pe PRIMA linie de dupa ea (in randul vanzatorului) pe care o tine vanzatorul, deci doar diferenta.
--       Cu lemnul si fierul: o bucata de lemn; o bucata de fier, sau fier minus lemn cand taverna e plina;
--     * vanzatorul, cand el e marginea: ce ar mai vinde, adica bucata primei linii tinute de el.
--   Veriga slaba a unei linii: primul minim din linie (plasele ei, oamenii, cladirea), sau vanzatorul cand el e
--   marginea ei. Fara linia fierului iese PRIMUL minim din cele sase -- regula de dinainte [D49].
-- Trei sau mai multe linii la acelasi vanzator nu exista inca: regula "prima linie tinuta de dupa ea" e exacta
-- pentru doua. Inainte de a treia, intai teste socotite de mana.
local function pickBottlenecks(m: Model, f: Flow): string
    local gains: { [string]: number } = {}
    for _, link in m.links do
        gains[link] = 0
    end
    for _, seller in m.sellerOrder do
        local order = m.sellers[seller].priority
        for i, line in order do
            local lf = f.lines[line]
            if lf.active and not lf.bySeller then
                local gain = m.avg[m.lines[line].netKind]
                for j = i + 1, #order do
                    if f.lines[order[j]].bySeller then
                        gain -= m.avg[m.lines[order[j]].netKind]
                        break
                    end
                end
                if lf.catch == lf.delivered then
                    gains.nets = math.max(gains.nets, gain)
                end
                for k, step in m.lines[line].steps do
                    if lf.values[k] == lf.delivered then
                        gains[step.link] = math.max(gains[step.link], gain)
                    end
                end
            end
        end
        for _, line in order do
            if f.lines[line].bySeller then
                gains[seller] = m.avg[m.lines[line].netKind]
                break
            end
        end
    end
    local best = "nets"
    for _, link in m.links do
        if gains[link] > gains[best] then
            best = link
        end
    end
    for _, line in m.lineOrder do
        local lf = f.lines[line]
        if not lf.active then
            lf.bottleneck = ""
        elseif lf.bySeller then
            lf.bottleneck = m.lines[line].seller
        else
            -- primul minim din linie (la egalitate, cel dinainte), cu plasele in fata
            local first = "nets"
            if lf.catch ~= lf.ownMax then
                for k, step in m.lines[line].steps do
                    if lf.values[k] == lf.ownMax then
                        first = step.link
                        break
                    end
                end
            end
            lf.bottleneck = first
        end
    end
    return best
end

-- Lantul intreg, peste un model [D49, D56, D64]: fiecare linie cu oamenii ei; cele care au acelasi vanzator impart
-- doar capacitatea lui. El vinde in ordinea din `priority` (intai marfa mai scumpa) cat poate aduce fiecare linie,
-- iar urmatoarea ia restul. Orice capacitate in plus doar largeste ce se poate, deci nicio cumparatura nu scade
-- venitul. `math.min` alege, nu calculeaza: da exact bitul pe care il da `min()` din Python.
--
-- `idleOnly` = CE MERGE FARA TINE. Plasele se umplu singure, dar fiecare pas de dupa ele are nevoie de cineva: fara
-- tine, un pas fara om sta, iar vanzatorul fara omul lui nu vinde. Deci venitul pasiv cere TOATE meseriile unei linii
-- [D49] -- si de aceea pastila "AWAY" apare abia atunci: se CASTIGA.
function ChainMath.flowWith(m: Model, s: State, idleOnly: boolean?): Flow
    local lines: { [string]: LineFlow } = {}
    local totalCatch = 0.0
    for _, line in m.lineOrder do
        local spec = m.lines[line]
        local catch = 0.0
        if lineOpen(m, s, line) then
            for _, n in s.nets do
                if n.kind == spec.netKind then
                    catch += ChainMath.netRate(n)
                end
            end
        end
        local values: { number } = {}
        local ownMax = catch
        for k, step in spec.steps do
            local value: number
            if idleOnly and s.crews[step.role].count == 0 then
                value = 0
            elseif step.kind == "walk" then
                value = walkRate(m, s, step.role)
            else
                value = processorLink(m, s, line, step.role, step.link)
            end
            values[k] = value
            ownMax = math.min(ownMax, value)
        end
        lines[line] = {
            catch = catch,
            values = values,
            ownMax = ownMax,
            active = spec.openFlag == nil or catch > 0,
            room = 0,
            delivered = 0,
            bySeller = false,
            bottleneck = "",
        }
        totalCatch += catch
    end
    local capacity: { [string]: number } = {}
    for _, seller in m.sellerOrder do
        local spec = m.sellers[seller]
        local cap = if idleOnly and s.crews[spec.role].count == 0
            then 0
            else sellerLink(m, s, seller)
        capacity[seller] = cap
        local room = cap
        for _, line in spec.priority do
            local lf = lines[line]
            lf.room = room
            lf.delivered = math.min(lf.ownMax, room)
            lf.bySeller = lf.active and lf.delivered == room and lf.delivered < lf.ownMax
            room -= lf.delivered
        end
    end
    local delivered = 0.0
    for _, line in m.lineOrder do
        delivered += lines[line].delivered
    end
    local f: Flow = {
        lines = lines,
        capacity = capacity,
        catch = totalCatch,
        delivered = delivered,
        bottleneck = "nets",
    }
    f.bottleneck = pickBottlenecks(m, f)
    return f
end

function ChainMath.flow(s: State, idleOnly: boolean?): Flow
    return ChainMath.flowWith(GAME, s, idleOnly)
end

-- Venitul unui lant: fiecare linie, in ORDINEA FIXA a modelului (aceeasi suma, bit cu bit, ca in simulator).
function ChainMath.valueWith(m: Model, s: State, f: Flow): number
    local gross = 0.0
    for _, line in m.lineOrder do
        gross += f.lines[line].delivered * m.avg[m.lines[line].netKind]
    end
    return gross * s.priceMult * s.bells * (1 + 0.01 * s.indexFound) * (1 + 0.5 * s.rebirths)
end

-- Debitul unui pas dintr-o linie a jocului, dupa numele verigii.
local stepIndex: { [string]: { [string]: number } } = {}
for _, line in GAME.lineOrder do
    stepIndex[line] = {}
    for k, step in GAME.lines[line].steps do
        stepIndex[line][step.link] = k
    end
end

-- VEDEREA PLATA a Erei 1 peste `Flow`: numele pe care le citesc serverul, meniurile si tabelul de aur.
function ChainMath.ratesOf(f: Flow): Rates
    local wood, iron = f.lines.wood, f.lines.iron
    return {
        catch = f.catch,
        woodCatch = wood.catch,
        scrapCatch = iron.catch,
        collect = wood.values[stepIndex.wood.collect],
        port = wood.values[stepIndex.wood.port],
        sawing = wood.values[stepIndex.wood.saw],
        haul = wood.values[stepIndex.wood.haul],
        scrapCollect = iron.values[stepIndex.iron.scrapCollect],
        scrapPort = iron.values[stepIndex.iron.scrapPort],
        forging = iron.values[stepIndex.iron.forge],
        ironHaul = iron.values[stepIndex.iron.ironHaul],
        sales = f.capacity.dock,
        wood = wood.delivered,
        scrap = iron.delivered,
        delivered = f.delivered,
        bottleneck = f.bottleneck,
        woodBottleneck = wood.bottleneck,
        ironBottleneck = iron.bottleneck,
    }
end

function ChainMath.rates(s: State): Rates
    return ChainMath.ratesOf(ChainMath.flowWith(GAME, s, false))
end

-- [D65] VERIGA CARE TINE VENITUL UNUI SINGUR CARTIER. `Flow.bottleneck` e una pentru tot lantul, iar din Era 2 e mai
-- mereu una de la Moara (o bucata de acolo face de 40 de ori mai mult): panoul deschis pe The Landing ar fi trimis la
-- turnatorie. Liniile a doua ere nu impart nimic (fiecare vanzator e al erei lui), deci lantul unei ere socotit
-- singur da exact debitele ei din lantul intreg; cat Era 2 e inchisa, raspunsul pentru Era 1 e chiar `Flow.bottleneck`.
local ERA_MODELS: { Model } = {}
for era, eraLines in StationConfig.ERA_LINES do
    local sellerOrder: { string } = {}
    for _, seller in StationConfig.SELLER_ORDER do
        if table.find(eraLines, StationConfig.SELLERS[seller].priority[1]) ~= nil then
            table.insert(sellerOrder, seller)
        end
    end
    ERA_MODELS[era] = ChainMath.model(
        eraLines,
        StationConfig.LINES,
        StationConfig.PROCESSORS,
        sellerOrder,
        StationConfig.SELLERS,
        StationConfig.ROLE_BASE,
        AVG
    )
end

function ChainMath.eraBottleneck(s: State, era: number): string
    local m = ERA_MODELS[era]
    return if m ~= nil then ChainMath.flowWith(m, s, false).bottleneck else ""
end

-- CE MERGE FARA TINE (vezi `flowWith`). [D56] Forja are si ea omul ei: fara Smelter, fara tine, sta.
function ChainMath.idleRates(s: State): Rates
    return ChainMath.ratesOf(ChainMath.flowWith(GAME, s, true))
end

function ChainMath.idleIncome(s: State): number
    return ChainMath.valueWith(GAME, s, ChainMath.flowWith(GAME, s, true))
end

function ChainMath.income(s: State): number
    return ChainMath.valueWith(GAME, s, ChainMath.flowWith(GAME, s, false))
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
    -- TOATE campurile, nu o lista: o linie noua vine cu campurile ei (nivelul cladirii, conditia de deschidere), iar
    -- o clona care le-ar pierde ar face `gainOf` sa socoteasca pe o stare ciuntita, in tacere.
    local copy: any = table.clone(s :: any)
    local nets = table.create(#s.nets)
    for i, n in s.nets do
        nets[i] = { base = n.base, baseLane = n.baseLane, level = n.level, kind = n.kind }
    end
    local crews: { [string]: Crew } = {}
    for role, crew in s.crews do
        crews[role] = { count = crew.count, tier = crew.tier }
    end
    copy.nets = nets
    copy.crews = crews
    return copy
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
        wheel = false,
        furnace = false,
        foundryLevel = 1,
        furnaceLevel = 1,
        marketLevel = 1,
        sackBig = false,
        crews = ChainMath.emptyCrews(),
        priceMult = 1.0,
        bells = 1.0,
        indexFound = 0,
        rebirths = 0,
    }
end

return ChainMath
