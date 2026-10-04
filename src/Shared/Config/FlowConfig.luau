--!strict
-- DRUMUL MARFII, CA DATE [D65]. Fiecare linie a lantului (StationConfig.LINES) isi duce marfa prin aceleasi patru
-- gramezi: MAGAZIA (unde varsa cine goleste plasele) -> INTRAREA atelierului -> IESIREA lui -> gramada VANZATORULUI.
--
--   lemnul:  depozit      -> gater               -> scanduri -> taverna
--   fierul:  Scrap Shed   -> forja               -> fier     -> taverna
--   piesele: Mill Store   -> turnatorie          -> piese    -> Piata
--   cuprul:  Ore Shed     -> cuptorul de cupru   -> cupru    -> Piata
--   bobinele: Works Store -> Wire Works          -> bobine   -> Depot     [D67]
--   curentul: Battery Shed -> Power House        -> celule   -> Depot
--
-- Pana la D65, EconomyService avea cate o functie pe cladire, scrisa de doua ori (UseStorage / UseShed, UseSawmill /
-- UseForge, saw / smelt, cinci instantanee): Era 2 ar fi fost a treia si a patra copie. Acum gesturile sunt in
-- Shared/Modules/FlowMath (pur, testat), iar aici sta doar CE difera intre linii: ce marfa e a ei, in ce camp din
-- profil ii stau gramezile, ce platforma ii deschide magazia si atelierul, ce numara in Stats, ce motiv de refuz da.
-- Cladirea cu niveluri, omul ei si vanzatorul NU se repeta aici: vin din StationConfig.LINES.
local StationConfig = require(script and script.Parent.StationConfig or "./StationConfig")
local TycoonConfig = require(script and script.Parent.TycoonConfig or "./TycoonConfig")

local FlowConfig = {}

-- [D70] O piesa a unei uniri: linia ei, bunul gata (iesirea liniei) si gramada ei la atelierul unirii.
export type Join = { line: string, good: string, pile: string }

export type Line = {
    line: string,
    era: number,
    raw: { string }, -- marfa bruta a liniei: ce lasi la magazia si la atelierul ei (gol la o unire)
    find: string?, -- gasirile erei ei: merg cu marfa si trec neschimbate prin atelier [D56]; nil = fara gasiri [D70]
    -- LOCURILE (numele din remote-uri, din drumurile oamenilor si din prezenta) si gramezile lor din profil
    store: string?, -- [D70] nil la o unire: n-are magazie
    storePile: string?,
    storePad: string?, -- platforma fara de care magazia nu exista (nil = e acolo de la inceput)
    processor: string,
    inputPile: string?, -- [D70] nil la o unire: fiecare piesa are gramada ei (`inputPiles`)
    inputPiles: { [string]: string }?, -- [D70] doar la unire: linia piesei -> campul gramezii ei din profil
    joins: { Join }?, -- [D70] DERIVAT din `inputPiles`, in ordinea StationConfig.LINES[line].inputs
    processorPad: string?, -- platforma fara de care atelierul nu merge
    output: string,
    outputPile: string,
    -- din StationConfig.LINES: cladirea cu niveluri (veriga), omul ei, vanzatorul
    station: string,
    role: string,
    seller: string?, -- [D70] nil la o piesa: se vinde doar unita
    into: string?, -- [D70] piesa: unirea in care merge
    partRefusal: string?, -- [D70] doar la unire: refuzul vanzatorului cand duci doar piesele ei
    -- Stats: bucatile trecute prin atelier; bucatile vandute (nil = doar `Stats.sold`, comun)
    processedStat: string,
    soldStat: string?,
    -- campul din gramada de la intrare cu clipa ultimei prelucrari (numele Erei 1 raman cele din profiluri)
    stamp: string,
    -- motivele de refuz pe care clientul le traduce in toast
    storeEmpty: string?,
    nothingDone: string,
    noStore: string?,
    noProcessor: string,
    -- cand n-ai ce face aici dar duci marfa bruta a liniei ASTEIA, locurile altei linii iti spun unde s-o duci; doar
    -- liniile din `hintedBy` o spun (in Era 1: depozitul si gaterul despre scrap, nu si invers)
    hint: string?,
    hintedBy: { string },
}

export type Seller = {
    seller: string,
    era: number,
    pile: string,
    station: string,
    role: string,
    find: string?, -- [D70] nil: vanzatorul n-are gasiri (orasul)
    -- [D70] DERIVAT: bunurile pe care scurgerea le ia intai, in ordinea `priority` (ca ChainMath). Doar cand ordinea
    -- cheilor (alfabetica, PileMath.take) n-o da singura: la orasul, „grid” < „ingot”, iar scurgerea ar fi vandut intai
    -- curentul (-28% in starea „orasul plin”). La vanzatorii Erelor 1-3 ordinea cheilor iese chiar `priority`: nil.
    takeOrder: { string }?,
}

export type Model = {
    lineOrder: { string },
    sellerOrder: { string },
    lines: { [string]: Line },
    sellers: { [string]: Seller },
    byStore: { [string]: Line },
    byProcessor: { [string]: Line },
    byOutput: { [string]: Line },
    piles: { string },
}

local function processorOf(line: string): (string, string)
    for _, step in StationConfig.LINES[line].steps do
        if step.kind == "processor" then
            return step.link, step.role
        end
    end
    error(`linia {line} n-are atelier`)
end

local function lineSpec(t: any): Line
    local station, role = processorOf(t.line)
    t.station, t.role = station, role
    t.seller = StationConfig.LINES[t.line].seller
    t.into = StationConfig.LINES[t.line].into -- [D70]
    return t
end

local LINES_ALL = {
    wood = lineSpec({
        line = "wood",
        era = 1,
        -- reeds si shards nu se mai prind din D55; raman pentru ce e deja in profiluri. Orice marfa bruta pe care n-o
        -- cere nicio linie e tot a lemnului (vezi FlowMath.lineOfGood): nimic nu ramane blocat in traista.
        raw = { "driftwood", "reeds", "shards" },
        find = "named",
        store = "storage",
        storePile = "StoragePile",
        processor = "sawmill",
        inputPile = "SawmillPile",
        output = "planks",
        outputPile = "PlanksPile",
        processedStat = "sawn",
        stamp = "sawnAt",
        storeEmpty = "storage_empty",
        nothingDone = "nothing_cut",
        noStore = "no_storage",
        noProcessor = "no_sawmill",
        hint = "logs_to_sawmill",
        hintedBy = {},
    }),
    iron = lineSpec({
        line = "iron",
        era = 1,
        raw = { "scrap" },
        find = "named",
        store = "shed",
        storePile = "ScrapPile",
        storePad = "scrap_shed",
        processor = "forge",
        inputPile = "ForgePile",
        processorPad = "workshop",
        output = "iron",
        outputPile = "IronPile",
        processedStat = "smelted",
        stamp = "smeltedAt",
        soldStat = "ironSold",
        storeEmpty = "shed_empty",
        nothingDone = "nothing_smelted",
        noStore = "no_shed",
        noProcessor = "no_workshop",
        hint = "scrap_to_forge",
        hintedBy = { "wood" },
    }),
    -- [D65] ERA 2
    parts = lineSpec({
        line = "parts",
        era = 2,
        raw = { "mill_scrap" },
        find = "named2",
        store = "millStore",
        storePile = "MillPile",
        processor = "foundry",
        inputPile = "FoundryPile",
        processorPad = "water_wheel",
        output = "parts",
        outputPile = "PartsPile",
        processedStat = "cast",
        stamp = "processedAt",
        soldStat = "partsSold",
        storeEmpty = "mill_store_empty",
        nothingDone = "nothing_cast",
        noStore = "no_mill_store",
        noProcessor = "no_wheel",
        hint = "scrap_to_foundry",
        hintedBy = {},
    }),
    copper = lineSpec({
        line = "copper",
        era = 2,
        raw = { "ore" },
        find = "named2",
        store = "oreShed",
        storePile = "OrePile",
        storePad = "ore_shed",
        processor = "furnace",
        inputPile = "FurnacePile",
        processorPad = "copper_furnace",
        output = "copper",
        outputPile = "CopperPile",
        processedStat = "copperSmelted",
        stamp = "processedAt",
        soldStat = "copperSold",
        storeEmpty = "ore_shed_empty",
        nothingDone = "nothing_smelted_copper",
        noStore = "no_ore_shed",
        noProcessor = "no_furnace",
        hint = "ore_to_furnace",
        hintedBy = { "parts" },
    }),
    -- [D67] ERA 3: minereul de cupru al Wire Works iese bobine, bateriile turbinei ies celule de energie
    coils = lineSpec({
        line = "coils",
        era = 3,
        raw = { "works_ore" },
        find = "named3",
        store = "worksStore",
        storePile = "WorksPile",
        processor = "wireworks",
        inputPile = "WireworksPile",
        processorPad = "steam_engine",
        output = "coils",
        outputPile = "CoilsPile",
        processedStat = "drawn",
        stamp = "processedAt",
        soldStat = "coilsSold",
        storeEmpty = "works_store_empty",
        nothingDone = "nothing_drawn",
        noStore = "no_works_store",
        noProcessor = "no_steam",
        hint = "ore_to_wireworks",
        hintedBy = {},
    }),
    power = lineSpec({
        line = "power",
        era = 3,
        raw = { "battery" },
        find = "named3",
        store = "batteryShed",
        storePile = "BatteryPile",
        storePad = "battery_shed",
        processor = "powerhouse",
        inputPile = "PowerhousePile",
        processorPad = "power_house",
        output = "cell",
        outputPile = "CellPile",
        processedStat = "cellsMade",
        stamp = "processedAt",
        soldStat = "cellsSold",
        storeEmpty = "battery_shed_empty",
        nothingDone = "nothing_charged",
        noStore = "no_battery_shed",
        noProcessor = "no_powerhouse",
        hint = "batteries_to_powerhouse",
        hintedBy = { "coils" },
    }),
    -- [D70] ERA 4, „The Dam", ADORMITA pana la StationConfig.ENGINE_ERAS = 4 (pasul j): doua PIESE (butoaiele, cablul),
    -- UNIREA lor la Relay (curentul pentru oras) si cristalul. Fara gasiri (D70 Runda 5). Butoaiele, cablul si unirea
    -- sunt acolo de la baraj (fara platforma); cristalul are Kiln-ul si Crystal Shed-ul lui (pasul j2).
    barrels = lineSpec({
        line = "barrels",
        era = 4,
        raw = { "charge" },
        store = "damStore",
        storePile = "DamStorePile",
        processor = "switchyard",
        inputPile = "SwitchyardPile",
        output = "barrel",
        outputPile = "BarrelPile",
        processedStat = "barrelsLoaded",
        stamp = "processedAt",
        storeEmpty = "dam_store_empty",
        nothingDone = "nothing_loaded",
        noStore = "no_dam_store",
        noProcessor = "no_switchyard",
        -- [D70, pasul k4] bateriile duse la alt loc al barajului: locul spune unde merg
        hint = "batteries_to_switchyard",
        hintedBy = { "cable", "grid", "crystal" },
    }),
    cable = lineSpec({
        line = "cable",
        era = 4,
        raw = { "cable_ore" },
        store = "cableStore",
        storePile = "CableStorePile",
        processor = "cableworks",
        inputPile = "CableworksPile",
        output = "cable",
        outputPile = "CablePile",
        processedStat = "cableSpun",
        stamp = "processedAt",
        storeEmpty = "cable_store_empty",
        nothingDone = "nothing_spun",
        noStore = "no_cable_store",
        noProcessor = "no_cableworks",
        hint = "cable_ore_to_cableworks",
        hintedBy = { "barrels", "grid", "crystal" },
    }),
    -- unirea: n-are magazie si nici marfa bruta; fiecare piesa isi are gramada la Relay
    grid = lineSpec({
        line = "grid",
        era = 4,
        raw = {},
        processor = "relay",
        inputPiles = { barrels = "RelayBarrelPile", cable = "RelayCablePile" },
        output = "grid",
        outputPile = "GridPile",
        processedStat = "gridJoined",
        soldStat = "gridSold",
        stamp = "processedAt",
        nothingDone = "nothing_joined",
        noProcessor = "no_relay",
        partRefusal = "part_to_relay",
        hintedBy = {},
    }),
    crystal = lineSpec({
        line = "crystal",
        era = 4,
        raw = { "crystal" },
        store = "crystalShed",
        storePad = "crystal_shed",
        storePile = "CrystalPile",
        processor = "kiln",
        processorPad = "crystal_kiln",
        inputPile = "KilnPile",
        output = "ingot",
        outputPile = "IngotPile",
        processedStat = "ingotsFired",
        soldStat = "ingotsSold",
        stamp = "processedAt",
        storeEmpty = "crystal_shed_empty",
        nothingDone = "nothing_fired",
        noStore = "no_crystal_shed",
        noProcessor = "no_kiln",
        hint = "crystal_to_kiln",
        hintedBy = { "barrels", "cable", "grid" },
    }),
} :: { [string]: Line }
FlowConfig.LINES_ALL = LINES_ALL

-- [inventarul A4] Ce duce acasa clientul unui vanzator: marfa ultimei linii din preferintele lui (Piata: piesa de masina;
-- Depoul: colacul de sarma; Switch House: curentul). nil pentru un vanzator necunoscut.
function FlowConfig.customerGood(seller: string): string?
    local spec = StationConfig.SELLERS[seller]
    local order = if spec ~= nil then spec.priority else nil
    local last = if order ~= nil then order[#order] else nil
    local line = if last ~= nil then LINES_ALL[last] else nil
    return if line ~= nil then line.output else nil
end

local SELLERS_ALL = {
    dock = {
        seller = "dock",
        era = 1,
        pile = "DockPile",
        station = "dock",
        role = "trader",
        find = "named",
    },
    market = {
        seller = "market",
        era = 2,
        pile = "MarketPile",
        station = "market",
        role = "merchant",
        find = "named2",
    },
    depot = {
        seller = "depot",
        era = 3,
        pile = "DepotPile",
        station = "depot",
        role = "clerk",
        find = "named3",
    },
    -- [D70] orasul (Switch House): cristalul intai, apoi curentul unit; fara gasiri
    town = {
        seller = "town",
        era = 4,
        pile = "TownPile",
        station = "town",
        role = "dispatcher",
    },
} :: { [string]: Seller }
FlowConfig.SELLERS_ALL = SELLERS_ALL

-- [D70] LA INCARCARE, pe toate erele (si barajul adormit): un rand care nu se leaga pica aici, nu in joc.
for _, line in StationConfig.LINE_ORDER_ALL do
    local spec = LINES_ALL[line]
    assert(spec ~= nil and spec.line == line, `FlowConfig: lipseste linia {line}`)
    assert(
        (spec.store == nil) == (spec.storePile == nil),
        `FlowConfig: {line}: magazia si gramada ei`
    )
    assert(
        spec.store == nil or (spec.storeEmpty ~= nil and spec.noStore ~= nil),
        `FlowConfig: {line}: magazia fara motivele ei de refuz`
    )
    assert(#spec.hintedBy == 0 or spec.hint ~= nil, `FlowConfig: {line}: hintedBy fara hint`)
    local inputs = StationConfig.LINES[line].inputs
    if inputs ~= nil then
        -- o UNIRE: fara magazie, fara marfa bruta si fara gasiri; produsul ei e `value` din StationConfig, iar piesele,
        -- in ordinea retetei (TycoonConfig.JOINED), sunt iesirile liniilor lor
        assert(
            spec.store == nil and spec.inputPile == nil and spec.find == nil and #spec.raw == 0,
            `FlowConfig: unirea {line} are magazie, intrare simpla, gasiri sau marfa bruta`
        )
        assert(spec.partRefusal ~= nil, `FlowConfig: unirea {line} n-are refuzul pieselor`)
        assert(
            spec.output == StationConfig.LINES[line].value,
            `FlowConfig: unirea {line}: produsul nu e value`
        )
        local recipe = TycoonConfig.JOINED[spec.output]
        local piles = spec.inputPiles
        assert(
            recipe ~= nil and piles ~= nil and #recipe == #inputs,
            `FlowConfig: unirea {line}: reteta`
        )
        local joins: { Join } = {}
        for i, part in inputs do
            local partSpec = LINES_ALL[part]
            assert(
                partSpec ~= nil
                    and partSpec.into == line
                    and partSpec.output == recipe[i]
                    and piles[part] ~= nil,
                `FlowConfig: piesa {part} a unirii {line}`
            )
            table.insert(joins, { line = part, good = partSpec.output, pile = piles[part] })
        end
        spec.joins = joins
    else
        assert(spec.inputPile ~= nil, `FlowConfig: {line} n-are intrarea atelierului`)
        assert(
            spec.inputPiles == nil and spec.partRefusal == nil,
            `FlowConfig: {line}: chei de unire pe o linie simpla`
        )
    end
end
for _, seller in StationConfig.SELLER_ORDER_ALL do
    local spec = SELLERS_ALL[seller]
    assert(
        spec ~= nil and spec.role == StationConfig.SELLERS[seller].role,
        `FlowConfig: vanzatorul {seller}`
    )
    local outs: { string } = {}
    for _, line in StationConfig.SELLERS[seller].priority do
        table.insert(outs, LINES_ALL[line].output)
    end
    local sorted = table.clone(outs)
    table.sort(sorted)
    local same = true
    for i, good in outs do
        same = same and sorted[i] == good
    end
    if not same then
        spec.takeOrder = outs
    end
end

-- [D70] UN MODEL = liniile si vanzatorii unei liste de ere, cu locurile si gramezile lor. Ca ChainMath.GAME / FULL: jocul
-- citeste GAME (erele din joc, StationConfig.ENGINE_ERAS), testele barajului FULL. Un loc necunoscut nu e al nimanui:
-- serverul il refuza.
function FlowConfig.model(lineOrder: { string }, sellerOrder: { string }): Model
    local lines: { [string]: Line } = {}
    local sellers: { [string]: Seller } = {}
    local byStore: { [string]: Line } = {}
    local byProcessor: { [string]: Line } = {}
    local byOutput: { [string]: Line } = {}
    -- toate campurile de gramezi din profil (sablon, migrare, teste), in ordinea liniilor: magazia, intrarea (sau
    -- intrarile unirii), iesirea; apoi vanzatorii
    local piles: { string } = {}
    -- un loc e cautat dupa nume (NetServer.UsePlace: magazie, atelier, iesire, vanzator): numele nu se repeta
    local claimed: { [string]: boolean } = {}
    local function claim(place: string)
        assert(not claimed[place], `FlowConfig: locul {place} apare de doua ori`)
        claimed[place] = true
    end
    for _, line in lineOrder do
        local spec = LINES_ALL[line]
        assert(spec ~= nil, `FlowConfig: lipseste linia {line}`)
        lines[line] = spec
        local store = spec.store
        if store ~= nil then
            claim(store)
            byStore[store] = spec
        end
        claim(spec.processor)
        byProcessor[spec.processor] = spec
        claim(spec.output)
        byOutput[spec.output] = spec
        if spec.storePile ~= nil then
            table.insert(piles, spec.storePile)
        end
        if spec.inputPile ~= nil then
            table.insert(piles, spec.inputPile)
        end
        for _, join in spec.joins or {} do
            table.insert(piles, join.pile)
        end
        table.insert(piles, spec.outputPile)
    end
    for _, seller in sellerOrder do
        local spec = SELLERS_ALL[seller]
        assert(spec ~= nil, `FlowConfig: lipseste vanzatorul {seller}`)
        claim(seller)
        sellers[seller] = spec
        table.insert(piles, spec.pile)
    end
    local seenPile: { [string]: boolean } = {}
    for _, pile in piles do
        assert(not seenPile[pile], `FlowConfig: gramada {pile} apare de doua ori`)
        seenPile[pile] = true
    end
    return {
        lineOrder = lineOrder,
        sellerOrder = sellerOrder,
        lines = lines,
        sellers = sellers,
        byStore = byStore,
        byProcessor = byProcessor,
        byOutput = byOutput,
        piles = piles,
    }
end
FlowConfig.GAME = FlowConfig.model(StationConfig.LINE_ORDER, StationConfig.SELLER_ORDER)
FlowConfig.FULL = FlowConfig.model(StationConfig.LINE_ORDER_ALL, StationConfig.SELLER_ORDER_ALL)
-- Ce citeste jocul: doar erele lui. Barajul se deschide singur cand ENGINE_ERAS trece pe 4.
FlowConfig.LINES = FlowConfig.GAME.lines
FlowConfig.SELLERS = FlowConfig.GAME.sellers
FlowConfig.BY_STORE = FlowConfig.GAME.byStore
FlowConfig.BY_PROCESSOR = FlowConfig.GAME.byProcessor
FlowConfig.BY_OUTPUT = FlowConfig.GAME.byOutput
FlowConfig.PILES = FlowConfig.GAME.piles

return FlowConfig
