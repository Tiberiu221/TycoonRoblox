--!strict
-- Cladirile cu niveluri (plasele, gaterul, debarcaderul) si meseriile cu trepte [D49]. Serverul e
-- singurul care stie ce nivel are fiecare si cat costa urmatorul [D13]; clientul doar cere si deseneaza.
--
-- Tot ce tine de CIFRE sta in ChainMath (modul pur, port al simulatorului). Aici sta doar ce are
-- nevoie de profil si de jucator: din ce e cumparat se construieste starea lantului, se verifica
-- daca o cumparatura e legala, si se incaseaza.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local CrewMath = require(ReplicatedStorage.Shared.Modules.CrewMath)
local StationConfig = require(ReplicatedStorage.Shared.Config.StationConfig)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local TycoonMath = require(ReplicatedStorage.Shared.Modules.TycoonMath)

local OfflineCalc = require(ReplicatedStorage.Shared.Modules.OfflineCalc)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local StationService = {}
local deps: {
    PushState: ((Player) -> ())?,
    Now: (() -> number)?,
    -- fereastra "cat ai lipsit"; nil = nu se arata nimic (tot se plateste)
    OnWelcome: ((Player, number, number, boolean) -> ())?,
    -- al doilea om al unei meserii se angajeaza tot prin HandService [D49]; primit, nu cerut (cerc)
    Hands: { Hire: (Player, string) -> boolean }?,
} =
    { PushState = nil, Now = nil, OnWelcome = nil, Hands = nil }

local SEEN_EVERY = 15 -- cat de des se noteaza ca jucatorul e inca aici

-- Starea lantului e cerută de zeci de ori pe secunda (venit, interval de prindere, delte), deci
-- se tine in cache si se arunca la orice cumparatura -- acelasi tipar ca PadService.StateFor.
local cache: { [Player]: ChainMath.State } = {}

local MAX_BULK = 500 -- cate niveluri poate lua o singura apasare; "Max" se opreste tot aici

-- Plasele, in ordinea din PADS. Ordinea da si indexul din care ChainMath deriva baza si costul:
-- a doua plasa e mai buna si mai scumpa decat prima, altfel n-ar avea rost sa o deblochezi.
local netPadIds: { string } = {}
local netPadLane: { [string]: number } = {}
local netPadKind: { [string]: string } = {} -- [D55] "wood" | "scrap"
for _, p in TycoonConfig.PADS do
    for _, e in p.effects do
        if e.kind == "net" then
            table.insert(netPadIds, p.id)
            netPadLane[p.id] = e.lane or 1
            netPadKind[p.id] = TycoonMath.netKind(p)
            break
        end
    end
end
StationService.NET_PAD_IDS = netPadIds

local function stationsOf(data: any)
    return data.Stations
end

function StationService.LevelOf(player: Player, kind: string, id: string?): number
    local data = DataService.Get(player)
    if data == nil then
        return 1
    end
    local st = stationsOf(data)
    if kind == "saw" then
        return if st.saw ~= nil then st.saw.level else 1
    elseif kind == "dock" then
        return st.dock.level
    elseif kind == "forge" then
        return if st.forge ~= nil then st.forge.level else 1
    elseif kind == "net" and id ~= nil then
        local entry = st.nets[id]
        return if entry ~= nil then entry.level else 1
    end
    return 1
end

-- Costul de baza al unui nivel. Pentru plase creste cu indexul plasei: o plasa mai buna costa mai
-- mult sa fie urcata, altfel toata lumea ar urca doar prima.
function StationService.UpgradeBase(kind: string, id: string?): number
    if kind == "saw" then
        return StationConfig.SAW_UPGRADE_BASE
    elseif kind == "dock" then
        return StationConfig.DOCK_UPGRADE_BASE
    elseif kind == "forge" then
        return StationConfig.FORGE_UPGRADE_BASE
    elseif kind == "net" and id ~= nil then
        local index = table.find(netPadIds, id)
        return ChainMath.netUpgradeBase(index or 1)
    end
    return math.huge
end

-- Starea lantului, construita din profil. Nu foloseste TycoonMath.stateFor pentru plase: acolo
-- plasele sunt doar o lista de rate, iar aici fiecare are nevoie de identitate (ca sa-si poata
-- tine propriul nivel).
-- Starea lantului pentru un set de platforme dat. `bought` e parametru (nu se citeste direct din
-- profil) ca sa se poata intreba si "cum ar arata DACA as cumpara platforma asta" -- de acolo vin
-- deltele de pe fantome, calculate cu exact aceeasi formula ca venitul real [D40].
function StationService.StateFrom(data: any, bought: { [string]: boolean }): ChainMath.State
    local s = ChainMath.empty()
    local st = stationsOf(data)
    for i, padId in netPadIds do
        if bought[padId] ~= true then
            continue
        end
        local entry = st.nets[padId]
        table.insert(s.nets, {
            base = ChainMath.netBase(i),
            baseLane = netPadLane[padId] or 1,
            level = if entry ~= nil then entry.level else 1,
            kind = netPadKind[padId] or "wood",
        })
    end
    -- `or 1`: o stare construita dintr-un profil necompletat nu are voie sa crape pe aritmetica cu nil.
    s.sawLevel = if st.saw ~= nil then st.saw.level else 1
    s.dockLevel = if st.dock ~= nil then st.dock.level else 1
    -- [D55] lantul resturilor: forja atelierului si shed-ul, din aceleasi platforme ca intrebarea "daca"
    s.forgeLevel = if st.forge ~= nil then st.forge.level else 1
    s.workshop = bought.workshop == true
    s.scrapShed = bought.scrap_shed == true
    -- OAMENII [D49]: cati sunt se numara din `data.Hands` (dupa rol), treapta vine din `data.Crews`.
    -- O platforma de meserie din `bought` fara om inca (intrebarea "daca as cumpara-o") numara un om:
    -- altfel cartonasul de la apropiere ar arata castig zero pe fiecare angajare.
    s.crews = CrewMath.fromProfile(data.Hands, data.Crews)
    for role, crew in s.crews do
        local def = TycoonConfig.CREWS[role]
        if crew.count == 0 and def ~= nil and bought[def.pad] == true then
            crew.count = 1
        end
    end
    -- Multiplicatorii raman de unde erau: sunt efecte de platforma, nu niveluri de statie.
    local old = TycoonMath.stateFor(bought, data.Rebirths, StationService.IndexCount(data))
    s.sackBig = old.sackBig
    s.priceMult = old.priceMult
    s.bells = old.bells
    s.indexFound = old.indexFound
    s.rebirths = old.rebirths
    return s
end

function StationService.StateFor(player: Player): ChainMath.State
    local cached = cache[player]
    if cached ~= nil then
        return cached
    end
    local data = DataService.Get(player)
    if data == nil then
        return ChainMath.empty()
    end
    local s = StationService.StateFrom(data, data.Pads)
    cache[player] = s
    return s
end

-- Cat adauga la venit fiecare platforma inca necumparata, si CARE e veriga slaba. Delta poate fi
-- zero -- cand platforma nu apasa pe gatuire -- si atunci ecranul spune de ce, in loc sa inventeze
-- o cifra frumoasa.
function StationService.Deltas(player: Player, ids: { string }): ({ [string]: number }, string)
    local data = DataService.Get(player)
    if data == nil then
        return {}, "nets"
    end
    local base = StationService.StateFor(player)
    local baseIncome = ChainMath.income(base)
    local out: { [string]: number } = {}
    for _, padId in ids do
        local bought = table.clone(data.Pads)
        bought[padId] = true
        out[padId] = ChainMath.income(StationService.StateFrom(data, bought)) - baseIncome
    end
    return out, ChainMath.rates(base).bottleneck
end

function StationService.Income(player: Player): number
    return ChainMath.income(StationService.StateFor(player))
end

function StationService.IndexCount(data: any): number
    local n = 0
    for _ in data.Index do
        n += 1
    end
    return n
end

-- Nivelurile plaselor, pe padId -- pentru quest-uri si pentru insignele din lume.
function StationService.NetLevels(player: Player): { [string]: number }
    local out: { [string]: number } = {}
    local data = DataService.Get(player)
    if data == nil then
        return out
    end
    for _, padId in netPadIds do
        if data.Pads[padId] == true then
            local entry = data.Stations.nets[padId]
            out[padId] = if entry ~= nil then entry.level else 1
        end
    end
    return out
end

function StationService.Idle(player: Player): number
    return ChainMath.idleIncome(StationService.StateFor(player))
end

function StationService.Invalidate(player: Player)
    cache[player] = nil
end

-- Rata de prindere a unei plase ACUM, cu nivelul ei. NetService o cere ca sa stie la cate secunde
-- pica urmatoarea bucata.
function StationService.NetRate(player: Player, padId: string): number
    local data = DataService.Get(player)
    if data == nil then
        return 0
    end
    local s = StationService.StateFor(player)
    -- `s.nets` contine DOAR plasele cumparate, in ordinea din PADS: pozitia unei plase in el e
    -- cate plase cumparate sunt pana la ea inclusiv.
    local pos = 0
    for _, id in netPadIds do
        if data.Pads[id] ~= true then
            continue
        end
        pos += 1
        if id == padId then
            local net = s.nets[pos]
            return if net ~= nil then ChainMath.netRate(net) else 0
        end
    end
    return 0
end

-- La cate secunde pica urmatoarea bucata in plasa asta. O plasa fara rata (nu exista sau nu e
-- cumparata) primeste un interval urias in loc de zero: o impartire la zero ar scoate `inf` si
-- ceasul plasei ar ramane blocat pentru totdeauna.
local warnedInterval: { [string]: boolean } = {}

function StationService.Interval(player: Player, padId: string): number
    local rate = StationService.NetRate(player, padId)
    if rate <= 0 then
        -- O plasa DETINUTA cu rata zero inseamna ca starea lantului e invechita, si atunci plasa
        -- nu mai prinde niciodata nimic -- am pierdut o sesiune de testare pe exact asta, pentru ca
        -- se intampla in tacere. Acum se aude [D43].
        local data = DataService.Get(player)
        local key = `{player.UserId}:{padId}`
        if data ~= nil and data.Pads[padId] == true and not warnedInterval[key] then
            warnedInterval[key] = true
            warn(
                `[Driftwood] plasa {padId} e cumparata dar are rata 0 -- starea lantului e invechita`
            )
        end
        return 1e9
    end
    -- [D51] prima plasa, in tutorial, prinde mai repede; ritmul din meniu ramane cel normal, iar
    -- plasa poarta eticheta care spune de ce (NetController)
    local data = DataService.Get(player)
    local collected = if data ~= nil then data.Stats.collected or 0 else 0
    return 1 / (rate * TycoonMath.catchBoost(padId, collected))
end

-- Cate bucati tine plasa asta acum: ~30 s din prinderea ei, dar cel putin 12 [D49]. O plasa urcata
-- nu se mai umple in doua secunde ca sa stea apoi plina pana trece cineva.
function StationService.NetCapacity(player: Player, padId: string): number
    return TycoonMath.netCapacity(StationService.NetRate(player, padId))
end

-- Cea mai departata banda atinsa. [D55] Nu mai decide ce se prinde (asta tine de felul plasei).
function StationService.Lanes(player: Player): number
    return ChainMath.lanesReached(StationService.StateFor(player))
end

export type Row = {
    kind: string,
    id: string?,
    name: string,
    level: number,
    output: number,
    nextOutput: number,
    nextMilestone: number?,
    costs: { number }, -- cost pentru fiecare pas din StationConfig.BULK_STEPS
    maxCount: number, -- cate niveluri isi permite acum ("Max")
    maxCost: number,
    bottleneck: boolean,
    -- [D52] cat creste venitul cu UN nivel aici, cu tot lantul de acum; 0 = nu aduce nimic pe loc
    gain: number,
}

-- O meserie in meniul ei [D49]. `output` = debitul verigii ACUM (cu partea ta din timp, daca n-are om),
-- `nextOutput` = cu o treapta in plus, `secondOutput` = cu al doilea om. Motivele de blocare sunt
-- cuvintele din CrewMath, pe care clientul le traduce: meniul nu promite ce serverul ar refuza.
export type CrewRow = {
    role: string,
    name: string,
    plural: string,
    pad: string,
    count: number,
    tier: number,
    maxTier: number,
    maxPeople: number,
    output: number,
    nextOutput: number?,
    secondOutput: number?,
    tierCost: number?,
    tierGain: number,
    tierBlock: string?,
    secondPrice: number?,
    secondGain: number,
    hireBlock: string?,
    tierAffordable: boolean,
    secondAffordable: boolean,
    maxed: boolean,
    bottleneck: boolean,
}

-- Cat taie/vinde cladirea la un nivel, cu oamenii pe care ii are acum. Gaterul fara Sawyer: cat taie
-- cand stai tu langa el -- meniul spune asta in cuvinte, cifra ramane cea adevarata [D40].
local function buildingOutput(s: ChainMath.State, kind: string, id: string?, level: number): number
    if kind == "net" then
        local index = table.find(netPadIds, id or "") or 1
        return ChainMath.levelOutput(ChainMath.netBase(index), level, "nets")
    elseif kind == "saw" then
        local crew = s.crews.sawyer
        return ChainMath.sawSpeed(level, crew, true)
    elseif kind == "forge" then
        return ChainMath.forgeSpeed(s.workshop, level) -- [D55] merge singura, cat e atelierul
    elseif kind == "dock" then
        return ChainMath.dockSpeed(level, s.crews.trader)
    end
    return 0 -- un fel necunoscut nu imprumuta cifrele altei cladiri [D40]
end

-- Cat adauga venitului UN nivel pe cladirea asta. Meniul nu se poate sprijini pe `bottleneck`: la
-- egalitate intre doua verigi, cea marcata slaba da tot zero la un nivel, iar un "Upgrading earns"
-- verde ar minti [D40]. Acelasi calcul ca `tierGain` al meseriilor. `netSlot` = locul plasei in
-- `s.nets` (doar plasele cumparate, in ordinea din PADS).
local function levelGain(s: ChainMath.State, kind: string, netSlot: number?): number
    local probe = ChainMath.clone(s)
    if kind == "net" then
        local net = if netSlot ~= nil then probe.nets[netSlot] else nil
        if net == nil then
            return 0
        end
        net.level += 1
    elseif kind == "saw" then
        probe.sawLevel += 1
    elseif kind == "forge" then
        probe.forgeLevel += 1
    elseif kind == "dock" then
        probe.dockLevel += 1
    else
        return 0
    end
    local gain = ChainMath.income(probe) - ChainMath.income(s)
    -- zgomotul de virgula mobila de la egalitate nu e castig
    return if gain > 1e-9 then gain else 0
end

local function rowFor(
    s: ChainMath.State,
    kind: string,
    id: string?,
    name: string,
    level: number,
    coins: number,
    bn: string,
    netSlot: number?
): Row
    local base = StationService.UpgradeBase(kind, id)
    local costs = {}
    for _, step in StationConfig.BULK_STEPS do
        table.insert(costs, ChainMath.bulkCost(base, level, step))
    end
    local maxCount = ChainMath.affordableLevels(base, level, coins, MAX_BULK)
    return {
        kind = kind,
        id = id,
        name = name,
        level = level,
        output = buildingOutput(s, kind, id, level),
        nextOutput = buildingOutput(s, kind, id, level + 1),
        nextMilestone = ChainMath.nextMilestone(level),
        costs = costs,
        maxCount = maxCount,
        maxCost = ChainMath.bulkCost(base, level, maxCount),
        -- felul cladirii (net/saw/forge/dock) nu e acelasi cuvant cu veriga lantului (nets/saw/forge/dock)
        bottleneck = bn == (if kind == "net" then "nets" else kind),
        gain = levelGain(s, kind, netSlot),
    }
end

local function crewRow(s: ChainMath.State, role: string, bn: string, coins: number): CrewRow
    local def = TycoonConfig.CREWS[role]
    local crew = s.crews[role]
    local canTier, tierBlock = CrewMath.canUpgradeTier(crew)
    local canHire, hireBlock = CrewMath.canHireSecond(crew)
    local nextOutput, tierGain = nil, 0
    if canTier then
        local probe = ChainMath.clone(s)
        probe.crews[role].tier += 1
        nextOutput = ChainMath.roleLink(probe, role)
        tierGain = ChainMath.income(probe) - ChainMath.income(s)
    end
    local secondOutput, secondGain = nil, 0
    if canHire then
        local probe = ChainMath.clone(s)
        probe.crews[role].count += 1
        secondOutput = ChainMath.roleLink(probe, role)
        secondGain = ChainMath.income(probe) - ChainMath.income(s)
    end
    local tierCost = if canTier then CrewMath.tierPrice(crew) else nil
    local secondPrice = if canHire then CrewMath.secondPrice(role) else nil
    return {
        role = role,
        name = def.name,
        plural = def.plural,
        pad = def.pad,
        count = crew.count,
        tier = crew.tier,
        maxTier = StationConfig.TIER_MAX,
        maxPeople = StationConfig.MAX_PEOPLE,
        output = ChainMath.roleLink(s, role),
        nextOutput = nextOutput,
        secondOutput = secondOutput,
        tierCost = tierCost,
        tierGain = tierGain,
        tierBlock = tierBlock,
        secondPrice = secondPrice,
        secondGain = secondGain,
        hireBlock = hireBlock,
        tierAffordable = tierCost ~= nil and coins >= tierCost,
        secondAffordable = secondPrice ~= nil and coins >= (secondPrice :: number),
        maxed = CrewMath.maxed(crew),
        bottleneck = bn == StationConfig.LINK_OF[role],
    }
end

-- Tot ce au nevoie meniurile. Se trimite intreg la fiecare TycoonState: e mic si asa clientul nu poate
-- ramane cu un pret invechit in mana.
function StationService.Snapshot(player: Player): {
    rows: { Row },
    crews: { CrewRow },
    bottleneck: string,
    rates: ChainMath.Rates,
    idle: number,
    playerShare: number,
}
    local s = StationService.StateFor(player)
    local rates = ChainMath.rates(s)
    local data = DataService.Get(player)
    local coins = if data ~= nil then data.Coins else 0
    local rows: { Row } = {}
    local netSlot = 0 -- locul plasei in `s.nets`: StateFrom le pune in aceeasi ordine, doar pe cele cumparate
    for _, padId in netPadIds do
        if data ~= nil and data.Pads[padId] == true then
            netSlot += 1
            local padName = TycoonConfig.byId[padId].name
            table.insert(
                rows,
                rowFor(
                    s,
                    "net",
                    padId,
                    padName,
                    StationService.LevelOf(player, "net", padId),
                    coins,
                    rates.bottleneck,
                    netSlot
                )
            )
        end
    end
    -- in ordinea lantului: gaterul, forja atelierului (cat e cumparat) [D55], apoi taverna
    table.insert(rows, rowFor(s, "saw", nil, "Sawmill", s.sawLevel, coins, rates.bottleneck))
    if s.workshop then
        table.insert(
            rows,
            rowFor(s, "forge", nil, "Workshop", s.forgeLevel, coins, rates.bottleneck)
        )
    end
    table.insert(rows, rowFor(s, "dock", nil, "Tavern", s.dockLevel, coins, rates.bottleneck))
    local crews: { CrewRow } = {}
    for _, role in StationConfig.ROLES do
        table.insert(crews, crewRow(s, role, rates.bottleneck, coins))
    end
    return {
        rows = rows,
        crews = crews,
        bottleneck = rates.bottleneck,
        rates = rates,
        -- ce ar merge fara tine: apare in HUD abia cand toate cinci meseriile au om [D49]
        idle = ChainMath.idleIncome(s),
        -- cat faci tu pe fiecare pas fara om ("No Collector — you do this yourself")
        playerShare = ChainMath.playerShare(s),
    }
end

-- O cumparatura de nivel pe o cladire. Intoarce (reusit, motiv). Motivul ajunge la client ca text,
-- deci nu minte niciodata: "coins" chiar inseamna ca n-au ajuns banii, nu altceva [D40].
function StationService.Upgrade(
    player: Player,
    kind: string,
    id: string?,
    count: number
): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if kind ~= "saw" and kind ~= "dock" and kind ~= "net" and kind ~= "forge" then
        return false, "unknown"
    end
    if kind == "forge" and data.Pads.workshop ~= true then
        return false, "locked" -- [D55] forja e a atelierului: fara el n-ai ce urca
    end
    if kind == "net" then
        if id == nil or table.find(netPadIds, id) == nil then
            return false, "unknown"
        end
        if data.Pads[id] ~= true then
            return false, "locked" -- nu urci o plasa pe care n-ai cumparat-o
        end
    end
    local n = math.clamp(math.floor(count), 1, MAX_BULK)
    local level = StationService.LevelOf(player, kind, id)
    local cost = ChainMath.bulkCost(StationService.UpgradeBase(kind, id), level, n)
    if not EconomyService.TrySpend(player, cost, "upgrade") then
        return false, "coins"
    end

    local st = stationsOf(data)
    if kind == "saw" then
        if st.saw == nil then
            st.saw = { level = 1 }
        end
        st.saw.level += n
    elseif kind == "dock" then
        st.dock.level += n
    elseif kind == "forge" then
        if st.forge == nil then
            st.forge = { level = 1 }
        end
        st.forge.level += n
    else
        local entry = st.nets[id :: string]
        if entry == nil then
            entry = { level = 1 }
            st.nets[id :: string] = entry
        end
        entry.level += n
    end
    StationService.Invalidate(player)
    if deps.PushState ~= nil then
        (deps.PushState :: (Player) -> ())(player)
    end
    return true, "ok"
end

-- O cumparatura pe o meserie [D49]: o treapta ("tier") sau al doilea om ("hire"). Regulile sunt cele
-- din CrewMath, aceleasi pe care le arata meniul. Intoarce (reusit, motiv).
function StationService.UpgradeCrew(player: Player, role: string, what: string): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    if TycoonConfig.CREWS[role] == nil or (what ~= "tier" and what ~= "hire") then
        return false, "unknown"
    end
    local crews = CrewMath.fromProfile(data.Hands, data.Crews)
    local crew = crews[role]
    if what == "tier" then
        local ok, why = CrewMath.canUpgradeTier(crew)
        if not ok then
            return false, why :: string
        end
        if not EconomyService.TrySpend(player, CrewMath.tierPrice(crew), "crew_tier") then
            return false, "coins"
        end
        local saved = data.Crews[role]
        if saved == nil then
            saved = { tier = crew.tier }
            data.Crews[role] = saved
        end
        saved.tier = crew.tier + 1
    else
        local ok, why = CrewMath.canHireSecond(crew)
        if not ok then
            return false, why :: string
        end
        local hands = deps.Hands
        local price = CrewMath.secondPrice(role) :: number
        if hands == nil or not EconomyService.TrySpend(player, price, "crew_hire") then
            return false, if hands == nil then "unknown" else "coins"
        end
        if not hands.Hire(player, role) then
            -- nu s-a putut angaja (cheia deja luata, profil stricat): banii se dau inapoi, nimic
            -- nu se pierde [P2]
            EconomyService.AddCoins(player, price, "crew_hire_refund")
            return false, "unknown"
        end
    end
    StationService.Invalidate(player)
    if deps.PushState ~= nil then
        (deps.PushState :: (Player) -> ())(player)
    end
    return true, "ok"
end

-- Cand se cumpara o plasa noua, ea porneste de la nivelul 1 si starea se reface.
function StationService.OnPadBought(player: Player, padId: string)
    local data = DataService.Get(player)
    if data ~= nil and table.find(netPadIds, padId) ~= nil then
        local st = stationsOf(data)
        if st.nets[padId] == nil then
            st.nets[padId] = { level = 1 }
        end
    end
    StationService.Invalidate(player)
end

-- CAT AI CASTIGAT CAT AI LIPSIT. Se cheama o singura data, la incarcarea profilului. Plateste
-- intai, arata dupa: daca fereastra n-ar apuca sa se deschida (client lent, deconectare), banii
-- tot sunt ai tai.
local function settleOffline(player: Player)
    local data = DataService.Get(player)
    if data == nil then
        return
    end
    StationService.Invalidate(player)
    local now = os.time()
    local result = OfflineCalc.computeIdle(now, data.Meta.lastSeenAt, StationService.Idle(player))
    data.Meta.lastSeenAt = now
    if result.coins <= 0 then
        return
    end
    EconomyService.AddCoins(player, result.coins, "offline")
    local onWelcome = deps.OnWelcome
    if onWelcome ~= nil then
        onWelcome(player, result.coins, result.seconds, result.cappedByTime)
    end
end

function StationService.Init(d: typeof(deps))
    deps = d
    DataService.ProfileLoaded:Connect(settleOffline)

    local Players = game:GetService("Players")
    -- `lastSeenAt` la iesire il scrie DataService (acolo se inchide si sesiunea de profil); daca
    -- l-am scrie si noi, campul ar avea doi stapani si ordinea dintre doua handlere de
    -- PlayerRemoving nu e garantata.
    Players.PlayerRemoving:Connect(StationService.Invalidate)

    -- `lastSeenAt` se noteaza si din cand in cand, nu doar la iesire: la o cadere de server nu se
    -- mai executa nimic la plecare, si fara asta jucatorul ar primi ore de castig offline pentru
    -- timp in care de fapt juca.
    task.spawn(function()
        while true do
            task.wait(SEEN_EVERY)
            local now = os.time()
            for _, player in Players:GetPlayers() do
                local data = DataService.Get(player)
                if data ~= nil then
                    data.Meta.lastSeenAt = now
                end
            end
        end
    end)
end

return StationService
