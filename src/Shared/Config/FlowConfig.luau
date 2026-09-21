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

local FlowConfig = {}

export type Line = {
    line: string,
    era: number,
    raw: { string }, -- marfa bruta a liniei: ce lasi la magazia si la atelierul ei
    find: string, -- gasirile erei ei: merg cu marfa si trec neschimbate prin atelier [D56]
    -- LOCURILE (numele din remote-uri, din drumurile oamenilor si din prezenta) si gramezile lor din profil
    store: string,
    storePile: string,
    storePad: string?, -- platforma fara de care magazia nu exista (nil = e acolo de la inceput)
    processor: string,
    inputPile: string,
    processorPad: string?, -- platforma fara de care atelierul nu merge
    output: string,
    outputPile: string,
    -- din StationConfig.LINES: cladirea cu niveluri (veriga), omul ei, vanzatorul
    station: string,
    role: string,
    seller: string,
    -- Stats: bucatile trecute prin atelier; bucatile vandute (nil = doar `Stats.sold`, comun)
    processedStat: string,
    soldStat: string?,
    -- campul din gramada de la intrare cu clipa ultimei prelucrari (numele Erei 1 raman cele din profiluri)
    stamp: string,
    -- motivele de refuz pe care clientul le traduce in toast
    storeEmpty: string,
    nothingDone: string,
    noStore: string,
    noProcessor: string,
    -- cand n-ai ce face aici dar duci marfa bruta a liniei ASTEIA, locurile altei linii iti spun unde s-o duci; doar
    -- liniile din `hintedBy` o spun (in Era 1: depozitul si gaterul despre scrap, nu si invers)
    hint: string,
    hintedBy: { string },
}

export type Seller = {
    seller: string,
    era: number,
    pile: string,
    station: string,
    role: string,
    find: string,
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
    return t
end

FlowConfig.LINES = {
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
} :: { [string]: Line }

FlowConfig.SELLERS = {
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
} :: { [string]: Seller }

-- Locul -> linia lui, pe feluri. Un loc necunoscut nu e al nimanui: serverul il refuza.
local byStore: { [string]: Line } = {}
local byProcessor: { [string]: Line } = {}
local byOutput: { [string]: Line } = {}
for _, line in StationConfig.LINE_ORDER do
    local spec = FlowConfig.LINES[line]
    assert(spec ~= nil, `FlowConfig: lipseste linia {line}`)
    byStore[spec.store] = spec
    byProcessor[spec.processor] = spec
    byOutput[spec.output] = spec
end
FlowConfig.BY_STORE = byStore
FlowConfig.BY_PROCESSOR = byProcessor
FlowConfig.BY_OUTPUT = byOutput

-- Toate campurile de gramezi din profil (pentru sablon, migrare si teste), in ordinea liniilor.
local piles: { string } = {}
for _, line in StationConfig.LINE_ORDER do
    local spec = FlowConfig.LINES[line]
    table.insert(piles, spec.storePile)
    table.insert(piles, spec.inputPile)
    table.insert(piles, spec.outputPile)
end
for _, seller in StationConfig.SELLER_ORDER do
    table.insert(piles, FlowConfig.SELLERS[seller].pile)
end
FlowConfig.PILES = piles

return FlowConfig
