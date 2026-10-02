--!strict
-- Cifrele lantului. Sursa lor e `scripts/economy/sim_tycoon.py` -- aici sunt transcrise, nu
-- inventate: testele din `tests/ChainMath.test.luau` verifica debitele la ultimul bit, iar
-- simulatorul citeste fisierul asta si pica daca o constanta a oamenilor s-a despartit [D49].
--
-- [D70] ERA 4 („The Dam”) STA AICI, dar jocul n-o ruleaza inca: vezi ENGINE_ERAS mai jos.
--
-- PATRU CLADIRI CU NIVELURI, fiecare de la 1 si fara capat:
--   nets   -- plasele. Cate una pe fiecare deblocare; toate urca separat.
--   saw    -- gaterul. Driftwood-ul iese scanduri.
--   forge  -- forja [D55, D56]. Scrap-ul plasei a cincea iese fier; merge cu Smelter, altfel cat stai langa ea.
--   dock   -- debarcaderul (taverna). Cat de repede se transforma gramada in monede.
-- SI NOUA MESERII [D49, D56], cu TREPTE putine si cel mult doi oameni pe meserie in Era 1, pe DOUA LINII:
--   lemnul: collector (plase -> depozit), porter (depozit -> gater), sawyer (taie la gater),
--           hauler (gater -> taverna);
--   fierul: scrapCollector (plasa de scrap -> shed), scrapPorter (shed -> forja), smelter (topeste la forja),
--           ironHauler (forja -> taverna);
--   trader (vinde la taverna, pentru amandoua).
-- Ce pas n-are om il faci tu, iar timpul tau se imparte intre pasii ramasi ai liniei lui.
--
-- De ce incrementele difera: plasele sunt cinci si cresc impreuna, dar gaterul si debarcaderul
-- sunt cate UNUL si trebuie sa tina pasul cu toate cinci. Cu acelasi increment peste tot,
-- debarcaderul ramanea gatuire zeci de niveluri la rand si jocul se transforma in macinat.
local StationConfig = {}

StationConfig.LEVEL_INC = {
    nets = 0.03,
    saw = 0.06,
    dock = 0.06,
    forge = 0.06,
    foundry = 0.06,
    market = 0.06,
    furnace = 0.06,
    wireworks = 0.06,
    depot = 0.06,
    powerhouse = 0.06,
    -- [D70] Era 4
    switchyard = 0.06,
    cableworks = 0.06,
    relay = 0.06,
    kiln = 0.06,
    town = 0.06,
}
StationConfig.LEVEL_INC_DEFAULT = 0.03
StationConfig.LEVEL_GROWTH = 1.09 -- cat se scumpeste fiecare nivel

-- Pragurile: la ele se DUBLEAZA. Ele sunt motivul pentru care esti mereu la cateva niveluri de
-- un salt, si de aceea ai mereu pe ce da banii [Idle Miner, "Next boost at level 10"].
StationConfig.MILESTONES = { 10, 25, 50, 100, 200, 300, 400, 500 }
StationConfig.MILESTONE_MULT = 2.0

-- Plasele. Fiecare plasa noua are baza mai mare decat cea dinainte: altfel o plasa noua ar fi mai
-- slaba decat un nivel pe una veche si n-ar mai avea rost sa deblochezi nimic.
StationConfig.NET_BASE_RATE = 0.33 -- prima plasa, nivel 1 (aceeasi cifra ca inainte de rescriere)
StationConfig.NET_BASE_GROWTH = 1.45
StationConfig.NET_UPGRADE_BASE_COST = 1.0
-- [D65] CADRUL EREI 2 E UN SINGUR NUMAR: de cate ori valoreaza marfa ei mai mult decat a Erei 1. Tot ce se masoara in
-- monede in cartierul nou se inmulteste cu el (valoarea bucatii, costul nivelurilor, costul treptelor); tot ce se
-- masoara in bucati pe secunda ramane ca in Era 1.
-- [D66] 3000, nu 40: o singura moneda, iar Moara pe o scara mult mai mare, ca minele unui continent din Idle Miner. Cu
-- 40, o noapte de absenta de la sfarsitul Erei 1 cumpara aproape toata Moara; cu 3000, doar inceputul ei (vezi
-- sim_tycoon.check_windfall).
StationConfig.ERA2_MULT = 3000.0
-- [D67] Era 3, „The Wire Works", pe aceeasi regula: de 3000 de ori Moara, deci de 3000 x 3000 de ori satul.
StationConfig.ERA3_MULT = 9000000.0
-- [D70] Era 4, „The Dam", tot pe regula asta: de 3000 de ori Wire Works (9e6 x 3000 = 2,7e10, exact).
StationConfig.ERA4_MULT = 27000000000.0
-- [D65] CINCI PLASE PE ERA, in aceeasi schema: patru pentru marfa cu care pornesti era si una, in larg, pentru marfa
-- noua. A k-a plasa a unei ere are baza celei de-a k-a plase a Erei 1; nivelurile ei costa de ERA2_MULT ori in Era 2
-- (si de ERA3_MULT ori in Era 3: `ERA_MULT`).
StationConfig.NETS_PER_ERA = 5
StationConfig.ERA_MULT =
    { 1.0, StationConfig.ERA2_MULT, StationConfig.ERA3_MULT, StationConfig.ERA4_MULT }
-- [D70] uneltele unei ere pot costa mai mult decat cadrul ei (lipsa = 1). Ale barajului costa dublu (sim_tycoon.py,
-- `ERA_TOOL_MULT`): cu suma de start, la pretul cadrului colectorii ajungeau la treapta 5 in ~10 minute.
-- check_config_constants compara fiecare era din configuratie.
StationConfig.TOOL_COST_MULT = { [4] = 2.0 } :: { [number]: number }
-- pe ce banda sta fiecare plasa: Era 1, Era 2, Era 3
StationConfig.NET_LANES = { 1, 1, 2, 2, 3, 1, 1, 2, 2, 3, 1, 1, 2, 2, 3 }
-- [D55] ce prinde fiecare: ultima plasa a Erei 1, cea din larg, prinde scrap (TycoonConfig.CATCH). [D65] Plasele Morii
-- prind scrap pentru turnatorie (`mill`), iar ultima, minereu de cupru (`ore`). [D67] Plasele Wire Works prind minereu
-- de cupru (`works`), iar in larg sta prima turbina (`turbine`), care umple baterii.
StationConfig.NET_KINDS = {
    "wood",
    "wood",
    "wood",
    "wood",
    "scrap",
    "mill",
    "mill",
    "mill",
    "mill",
    "ore",
    "works",
    "works",
    "works",
    "works",
    "turbine",
}

StationConfig.SACK_BONUS = 1.5 -- traista mare: mai putine drumuri, pe tot ce duci tu

-- Gaterul [D48]. Scandura valoreaza cat valora bustenul: gaterul e acolo de la inceput, deci un
-- multiplicator ar umfla doar cifrele. 2.4, nu 3.6: la 3.6 gaterul iesea gatuire 2-3% din timp.
StationConfig.SAW_BASE_RATE = 2.4
StationConfig.SAW_UPGRADE_BASE = 7.0

-- [D55, D56] Forja: topeste scrap-ul in fier, cu niveluri ca gaterul; Smelter-ii o tin pornita, fara ei topeste
-- doar cat stai langa ea. Sub plasa a cincea proaspata (1.46/s), ca la inceput forja sa fie gatuirea fierului.
StationConfig.FORGE_BASE_RATE = 1.2
StationConfig.FORGE_UPGRADE_BASE = 60.0

-- Debarcaderul. Baza e mult peste productia de inceput, deci prima vanzare se scurge repede.
StationConfig.DOCK_BASE_RATE = 3.0
StationConfig.DOCK_UPGRADE_BASE = 9.0

-- [D65] CLADIRILE EREI 2, in oglinda: turnatoria cat gaterul, cuptorul de cupru cat forja, Piata cat taverna (bucati pe
-- secunda), iar nivelurile lor de ERA2_MULT ori mai scumpe (7 / 60 / 9 x 3000). Cifre scrise, nu socotite: simulatorul
-- le citeste de aici cu regex.
StationConfig.FOUNDRY_BASE_RATE = 2.4
StationConfig.FOUNDRY_UPGRADE_BASE = 21000.0
StationConfig.FURNACE_BASE_RATE = 1.2
StationConfig.FURNACE_UPGRADE_BASE = 180000.0
StationConfig.MARKET_BASE_RATE = 3.0
StationConfig.MARKET_UPGRADE_BASE = 27000.0
-- [D67] CLADIRILE EREI 3, in oglinda cu ale Morii: Wire Works cat turnatoria, Power House cat cuptorul de cupru, Depoul
-- cat Piata; nivelurile lor de ERA3_MULT ori mai scumpe (7 / 60 / 9 x 9 000 000).
StationConfig.WIREWORKS_BASE_RATE = 2.4
StationConfig.WIREWORKS_UPGRADE_BASE = 63000000.0
StationConfig.POWERHOUSE_BASE_RATE = 1.2
StationConfig.POWERHOUSE_UPGRADE_BASE = 540000000.0
StationConfig.DEPOT_BASE_RATE = 3.0
StationConfig.DEPOT_UPGRADE_BASE = 81000000.0
-- [D70] CLADIRILE EREI 4 (docs/PLAN-MOTOR-UNIRE.md, sectiunea 2): Switchyard-ul umple butoaiele din sarcina turbinei, Cable
-- Works face cablul, Relay Station-ul le uneste (un butoi si o bucata de cablu fac o unitate de curent), Kiln-ul topeste
-- cristalul, iar orasul (Switch House) cumpara. Nivelurile de ERA4_MULT ori mai scumpe (7 / 7 / 8 / 60 / 9 x 2,7e10).
StationConfig.SWITCHYARD_BASE_RATE = 2.4
StationConfig.SWITCHYARD_UPGRADE_BASE = 189000000000.0
StationConfig.CABLEWORKS_BASE_RATE = 2.0
StationConfig.CABLEWORKS_UPGRADE_BASE = 189000000000.0
StationConfig.RELAY_BASE_RATE = 2.8
StationConfig.RELAY_UPGRADE_BASE = 216000000000.0
StationConfig.KILN_BASE_RATE = 1.2
StationConfig.KILN_UPGRADE_BASE = 1620000000000.0
StationConfig.TOWN_BASE_RATE = 3.0
StationConfig.TOWN_UPGRADE_BASE = 243000000000.0
-- [D70] PRAGURILE DE VENIT ALE BARAJULUI (sim_tycoon.py): capitolul cere „Earn 1T coins a second" inaintea Kiln-ului, iar
-- Dam Bell se deschide la 4T pe secunda. In joc se inmultesc cu 2x Flow (PassMath.flowFactor), ca era sa-si pastreze
-- continutul. Scrise intregi, ca regex-ul simulatorului sa le citeasca la fel.
StationConfig.KILN_INCOME = 1000000000000.0
StationConfig.DAM_BELL_INCOME = 4000000000000.0
-- NEGUSTORUL FACE DEBARCADERUL SA MEARGA, NU SA PLATEASCA MAI BINE. Fara el, debarcaderul vinde
-- singur la o treime; cu el, merge tot timpul. E singurul pas pe care nu-l faci tu.
StationConfig.NO_TRADER_FACTOR = 0.35

-- ---- oamenii [D49] ---------------------------------------------------------------------------
-- Ordinea din LINE_STEPS e si ordinea angajarilor (conditiile platformelor o impun). [D56] Fiecare linie are
-- timpul tau intreg: in joc nu ai niciodata pasi de mana pe amandoua odata (oamenii lemnului vin toti inaintea
-- Forge), iar asa deschiderea fierului nu poate scadea lemnul in nicio stare.
StationConfig.ERA1_ROLES = {
    "collector",
    "porter",
    "sawyer",
    "hauler",
    "trader",
    "scrapCollector",
    "scrapPorter",
    "smelter",
    "ironHauler",
}
-- [D65] Era 2, in aceeasi ordine: cei patru ai pieselor, negustorul Pietei, cei patru ai cuprului. Fiecare e oglinda
-- celui de pe acelasi loc din Era 1 (aceleasi bucati pe secunda, aceleasi secunde de venit la angajare).
StationConfig.ERA2_ROLES = {
    "millCollector",
    "millPorter",
    "founder",
    "partsHauler",
    "merchant",
    "oreCollector",
    "orePorter",
    "coppersmith",
    "copperHauler",
}
-- [D67] Era 3, in aceeasi ordine: cei patru ai bobinelor, Clerk-ul Depoului, cei patru ai curentului.
StationConfig.ERA3_ROLES = {
    "worksCollector",
    "worksPorter",
    "wiredrawer",
    "coilHauler",
    "clerk",
    "batteryCollector",
    "batteryPorter",
    "electrician",
    "powerHauler",
}
-- [D70] Era 4: cei cinci veterani ai butoaielor (si Dispatcher-ul orasului, fostul hangiu), cei sase ai cablului si ai
-- unirii (angajati in rafala), cei patru ai cristalului.
StationConfig.ERA4_ROLES = {
    "damCollector",
    "damPorter",
    "switchman",
    "barrelHauler",
    "dispatcher",
    "cableCollector",
    "cablePorter",
    "cablemaker",
    "cableHauler",
    "relayKeeper",
    "pylonRunner",
    "crystalCollector",
    "crystalPorter",
    "crystalsmith",
    "ingotHauler",
}
-- [D70] ERELE PE CARE LE RULEAZA JOCUL AZI. Era 4 sta in tabele (liniile, cladirile, oamenii, cifrele), dar o porneste abia
-- serverul, la pasul j al planului motorului (docs/PLAN-MOTOR-UNIRE.md: barajul, profilul v19). Pana atunci listele pe care
-- le citesc serverul, meniurile si ghidajul (ERA_ROLES, ROLES, ERA_LINES, LINE_ORDER, SELLER_ORDER si tot ce se deriva din
-- ele) sunt ale Erelor 1-3, iar cele `_ALL` au si barajul: din ele socoteste ChainMath.FULL (testele de aur ale barajului).
StationConfig.ENGINE_ERAS = 3
StationConfig.ERA_ROLES_ALL = {
    StationConfig.ERA1_ROLES,
    StationConfig.ERA2_ROLES,
    StationConfig.ERA3_ROLES,
    StationConfig.ERA4_ROLES,
}
-- Meseriile fiecarei ere din joc, apoi toate, in ordinea erelor.
StationConfig.ERA_ROLES =
    table.move(StationConfig.ERA_ROLES_ALL, 1, StationConfig.ENGINE_ERAS, 1, {})
local allRoles: { string } = {}
-- [D65] Treptele costa fix (25 / 75 / 225 / 675) pentru oamenii Erei 1; ai erelor noi muta marfa de ERA_MULT ori mai
-- scumpa, deci si uneltele lor costa pe masura.
local roleCostMult: { [string]: number } = {}
-- [D67] Era fiecarei meserii.
local eraOfRole: { [string]: number } = {}
local everyRole: { string } = {}
for era, roles in StationConfig.ERA_ROLES_ALL do
    for _, role in roles do
        table.insert(everyRole, role)
        if era <= StationConfig.ENGINE_ERAS then
            table.insert(allRoles, role)
        end
        eraOfRole[role] = era
        if era > 1 then
            roleCostMult[role] = StationConfig.ERA_MULT[era]
                * (StationConfig.TOOL_COST_MULT[era] or 1)
        end
    end
end
StationConfig.ROLES = allRoles
StationConfig.ROLES_ALL = everyRole
StationConfig.ROLE_COST_MULT = roleCostMult
StationConfig.ERA_OF_ROLE = eraOfRole
-- ---- liniile, ca date [D64] --------------------------------------------------------------------
-- Pana la D64 motorul (ChainMath) era scris de mana pentru exact doua linii. Era 2 aduce linii de ACEEASI forma
-- (plasa -> om care aduna -> magazie -> om care duce -> atelier -> om care duce -> vanzator), asa ca forma e tabel.
-- Oglinda lui LINE_ORDER / LINES / PROCESSORS / SELLERS din scripts/economy/sim_tycoon.py.
--   * Un pas e { role, link, kind }. `walk` = un drum: oamenii lui duc ROLE_BASE[role]; fara om, partea ta din timp
--     pe linia aceea. `processor` = o cladire cu niveluri (PROCESSORS[link]): oamenii ei o tin pornita tot timpul;
--     fara ei merge doar cat stai tu langa ea.
--   * `openFlag`: campul din ChainMath.State care deschide linia (nil = deschisa de la inceput). O linie cu conditie
--     mai cere si o plasa de felul ei.
--   * [D70] CHEILE PENTRU UNIRE SI BARAJ, toate optionale (oglinda din sim_tycoon.py; docs/PLAN-MOTOR-UNIRE.md):
--       - `closeFlag`: campul care INCHIDE linia (barajul opreste satul vechi);
--       - `inputs`: linia e o UNIRE, cu reteta 1:1 (o bucata din fiecare piesa face una); n-are `netKind`;
--       - `into`: linia e o PIESA si merge in unirea numita, nu la un vanzator; n-are `seller`;
--       - `value`: bunul (TycoonConfig.GOODS) livrat de linie; obligatoriu la o unire, altfel media plasei ei;
--       - `pool`: liniile cu acelasi `pool` IMPART timpul tau (pasii de mana ai tuturor celor deschise din bazin).
--   * `levelField`: campul din ChainMath.State cu nivelul cladirii.
--   * CIFRELE NU SE COPIAZA AICI: `base` trimite la constanta de mai sus (simulatorul o citeste de acolo, cu regex).
--   * LINE_ORDER e ordinea in care se aduna ORICE suma pe linii (virgula mobila: alta ordine ar muta ultimii biti ai
--     venitului) si in care stau verigile in LINKS. `priority` e ALTA ordine, a vanzatorului: cine ia primul din
--     capacitatea lui (marfa mai scumpa intai). Azi sunt una inversul celeilalte doar din intamplare.
--   * [D70] `job` (optional): meseria omului pasului (HandRoutes). Fara ea, dupa pozitie: collect, port, work, haul. O
--     unire are doar doi pasi (atelierul, drumul la vanzator), deci ii scrie.
export type Step = { role: string, link: string, kind: string, job: string? }
export type Line = {
    netKind: string?,
    openFlag: string?,
    closeFlag: string?,
    seller: string?,
    inputs: { string }?,
    into: string?,
    value: string?,
    pool: string?,
    steps: { Step },
}
export type Processor = { base: number, levelField: string }
export type Seller = { role: string, base: number, levelField: string, priority: { string } }

-- Liniile fiecarei ere: in fiecare, a doua apare spre final, cu plasa, atelierul si oamenii ei [D64]. [D70] Barajul are
-- doua piese (butoaiele si cablul), unirea lor (curentul pentru oras) si cristalul; piesele stau inaintea unirii.
StationConfig.ERA_LINES_ALL = {
    { "wood", "iron" },
    { "parts", "copper" },
    { "coils", "power" },
    { "barrels", "cable", "grid", "crystal" },
}
StationConfig.ERA_LINES =
    table.move(StationConfig.ERA_LINES_ALL, 1, StationConfig.ENGINE_ERAS, 1, {})
local function concat(eras: { { string } }): { string }
    local out: { string } = {}
    for _, lines in eras do
        for _, line in lines do
            table.insert(out, line)
        end
    end
    return out
end
-- ordinea liniilor: a erelor, una dupa alta (Erele 1-3: wood, iron, parts, copper, coils, power)
StationConfig.LINE_ORDER = concat(StationConfig.ERA_LINES)
StationConfig.LINE_ORDER_ALL = concat(StationConfig.ERA_LINES_ALL)
local LINES: { [string]: Line } = {
    wood = {
        netKind = "wood",
        openFlag = nil,
        closeFlag = "dam",
        seller = "dock",
        steps = {
            { role = "collector", link = "collect", kind = "walk" },
            { role = "porter", link = "port", kind = "walk" },
            { role = "sawyer", link = "saw", kind = "processor" },
            { role = "hauler", link = "haul", kind = "walk" },
        },
    },
    iron = {
        netKind = "scrap",
        openFlag = "workshop",
        closeFlag = "dam",
        seller = "dock",
        steps = {
            { role = "scrapCollector", link = "scrapCollect", kind = "walk" },
            { role = "scrapPorter", link = "scrapPort", kind = "walk" },
            { role = "smelter", link = "forge", kind = "processor" },
            { role = "ironHauler", link = "ironHaul", kind = "walk" },
        },
    },
    -- [D65] Era 2: piesele de masini (roata de apa porneste turnatoria) si cuprul (cuptorul de cupru), la Piata
    parts = {
        netKind = "mill",
        openFlag = "wheel",
        closeFlag = "dam",
        seller = "market",
        steps = {
            { role = "millCollector", link = "millCollect", kind = "walk" },
            { role = "millPorter", link = "millPort", kind = "walk" },
            { role = "founder", link = "foundry", kind = "processor" },
            { role = "partsHauler", link = "partsHaul", kind = "walk" },
        },
    },
    copper = {
        netKind = "ore",
        openFlag = "furnace",
        closeFlag = "dam",
        seller = "market",
        steps = {
            { role = "oreCollector", link = "oreCollect", kind = "walk" },
            { role = "orePorter", link = "orePort", kind = "walk" },
            { role = "coppersmith", link = "furnace", kind = "processor" },
            { role = "copperHauler", link = "copperHaul", kind = "walk" },
        },
    },
    -- [D67] Era 3: bobinele (masina cu abur porneste Wire Works) si curentul (Power House), la Depot
    coils = {
        netKind = "works",
        openFlag = "steam",
        closeFlag = "dam",
        seller = "depot",
        steps = {
            { role = "worksCollector", link = "worksCollect", kind = "walk" },
            { role = "worksPorter", link = "worksPort", kind = "walk" },
            { role = "wiredrawer", link = "wireworks", kind = "processor" },
            { role = "coilHauler", link = "coilHaul", kind = "walk" },
        },
    },
    power = {
        netKind = "turbine",
        openFlag = "powerhouse",
        closeFlag = "dam",
        seller = "depot",
        steps = {
            { role = "batteryCollector", link = "batteryCollect", kind = "walk" },
            { role = "batteryPorter", link = "batteryPort", kind = "walk" },
            { role = "electrician", link = "powerhouse", kind = "processor" },
            { role = "powerHauler", link = "powerHaul", kind = "walk" },
        },
    },
    -- [D70] Era 4, „The Dam": doua PIESE (butoaiele si cablul) si UNIREA lor (curentul pentru oras), toate in bazinul
    -- barajului, plus cristalul. Barajul le deschide si inchide liniile vechi (`closeFlag` de mai sus). Veteranii lucreaza
    -- butoaiele; cablul il faci tu, pana vin cei sase.
    barrels = {
        netKind = "dam",
        openFlag = "dam",
        into = "grid",
        pool = "dam",
        steps = {
            { role = "damCollector", link = "damCollect", kind = "walk" },
            { role = "damPorter", link = "damPort", kind = "walk" },
            { role = "switchman", link = "switchyard", kind = "processor" },
            { role = "barrelHauler", link = "barrelHaul", kind = "walk" },
        },
    },
    cable = {
        netKind = "cable_ore",
        openFlag = "dam",
        into = "grid",
        pool = "dam",
        steps = {
            { role = "cableCollector", link = "cableCollect", kind = "walk" },
            { role = "cablePorter", link = "cablePort", kind = "walk" },
            { role = "cablemaker", link = "cableworks", kind = "processor" },
            { role = "cableHauler", link = "cableHaul", kind = "walk" },
        },
    },
    -- Pylon Runner-ul duce curentul pe podul cu stalpi pana la Switch House (fiecare pas are omul lui)
    grid = {
        inputs = { "barrels", "cable" },
        openFlag = "dam",
        seller = "town",
        value = "grid",
        pool = "dam",
        steps = {
            { role = "relayKeeper", link = "relay", kind = "processor", job = "work" },
            { role = "pylonRunner", link = "pylonRun", kind = "walk", job = "haul" },
        },
    },
    crystal = {
        netKind = "crystal",
        openFlag = "kiln",
        seller = "town",
        pool = "dam",
        steps = {
            { role = "crystalCollector", link = "crystalCollect", kind = "walk" },
            { role = "crystalPorter", link = "crystalPort", kind = "walk" },
            { role = "crystalsmith", link = "kiln", kind = "processor" },
            { role = "ingotHauler", link = "ingotHaul", kind = "walk" },
        },
    },
}
StationConfig.LINES = LINES
local PROCESSORS: { [string]: Processor } = {
    saw = { base = StationConfig.SAW_BASE_RATE, levelField = "sawLevel" },
    forge = { base = StationConfig.FORGE_BASE_RATE, levelField = "forgeLevel" },
    foundry = { base = StationConfig.FOUNDRY_BASE_RATE, levelField = "foundryLevel" },
    furnace = { base = StationConfig.FURNACE_BASE_RATE, levelField = "furnaceLevel" },
    wireworks = { base = StationConfig.WIREWORKS_BASE_RATE, levelField = "wireworksLevel" },
    powerhouse = { base = StationConfig.POWERHOUSE_BASE_RATE, levelField = "powerhouseLevel" },
    -- [D70] Era 4
    switchyard = { base = StationConfig.SWITCHYARD_BASE_RATE, levelField = "switchyardLevel" },
    cableworks = { base = StationConfig.CABLEWORKS_BASE_RATE, levelField = "cableworksLevel" },
    relay = { base = StationConfig.RELAY_BASE_RATE, levelField = "relayLevel" },
    kiln = { base = StationConfig.KILN_BASE_RATE, levelField = "kilnLevel" },
}
StationConfig.PROCESSORS = PROCESSORS
-- Vanzatorii, cu ordinea lor (o harta cu chei text n-are ordine in Luau; in simulator e ordinea din dictionar).
StationConfig.SELLER_ORDER_ALL = { "dock", "market", "depot", "town" }
-- vanzatorii erelor din joc (ENGINE_ERAS): cei ai caror linii sunt in LINE_ORDER
StationConfig.SELLER_ORDER = {} :: { string }
local SELLERS: { [string]: Seller } = {
    dock = {
        role = "trader",
        base = StationConfig.DOCK_BASE_RATE,
        levelField = "dockLevel",
        priority = { "iron", "wood" },
    },
    -- [D65] Piata Erei 2: vinde intai cuprul (bucata valoreaza mai mult), piesele iau restul
    market = {
        role = "merchant",
        base = StationConfig.MARKET_BASE_RATE,
        levelField = "marketLevel",
        priority = { "copper", "parts" },
    },
    -- [D67] Depoul Erei 3: vinde intai celulele de energie, bobinele iau restul
    depot = {
        role = "clerk",
        base = StationConfig.DEPOT_BASE_RATE,
        levelField = "depotLevel",
        priority = { "power", "coils" },
    },
    -- [D70] orasul (Switch House), cu Dispatcher-ul, fostul hangiu: cristalul intai, apoi curentul unit
    town = {
        role = "dispatcher",
        base = StationConfig.TOWN_BASE_RATE,
        levelField = "townLevel",
        priority = { "crystal", "grid" },
    },
}
StationConfig.SELLERS = SELLERS
for _, seller in StationConfig.SELLER_ORDER_ALL do
    if table.find(StationConfig.LINE_ORDER, SELLERS[seller].priority[1]) ~= nil then
        table.insert(StationConfig.SELLER_ORDER, seller)
    end
end

-- Tabelele de mai jos se DERIVA din LINES / SELLERS, ca sa nu existe doua liste care sa se desparta.
-- LINE_STEPS: meseriile fiecarei linii, in ordinea angajarilor. MANUAL_ROLES: toti pasii pe care ii poti face tu.
-- LINK_OF: veriga fiecarei meserii. LINE_OF: linia fiecarei verigi de oameni si cladiri (`nets` tine de felul
-- plasei, iar vanzatorul e al tuturor liniilor lui: ele nu stau aici).
local lineSteps: { [string]: { string } } = {}
local manualRoles: { string } = {}
local linkOf: { [string]: string } = {}
local lineOf: { [string]: string } = {}
-- ORDINEA e contractul cu simulatorul: la egalitate castiga veriga dinainte. [D56] Plasele, apoi liniile in
-- LINE_ORDER, apoi vanzatorii.
local links: { string } = { "nets" }
for _, line in StationConfig.LINE_ORDER do
    local roles: { string } = {}
    for _, step in LINES[line].steps do
        table.insert(roles, step.role)
        table.insert(manualRoles, step.role)
        table.insert(links, step.link)
        linkOf[step.role] = step.link
        lineOf[step.link] = line
    end
    lineSteps[line] = roles
end
for _, seller in StationConfig.SELLER_ORDER do
    table.insert(links, seller)
    linkOf[SELLERS[seller].role] = seller
end
-- Verigile fiecarei ere (plasele sunt ale tuturor), in ordinea LINKS: plasele, liniile erei, vanzatorul lor. Portile
-- si ecranele unei ere se uita doar la ale ei.
local eraLinks: { { string } } = {}
for era, eraLines in StationConfig.ERA_LINES do
    local list: { string } = { "nets" }
    local sellersSeen: { [string]: boolean } = {}
    for _, line in eraLines do
        for _, step in LINES[line].steps do
            table.insert(list, step.link)
        end
    end
    for _, line in eraLines do
        local seller = LINES[line].seller -- [D70] o piesa n-are vanzator: se vinde doar prin unirea ei
        if seller ~= nil and not sellersSeen[seller] then
            sellersSeen[seller] = true
            table.insert(list, seller)
        end
    end
    eraLinks[era] = list
end
StationConfig.ERA_LINKS = eraLinks
-- [D65] Era fiecarei verigi (plasele n-au una: sunt ale tuturor) si a fiecarei linii: meniurile unui cartier arata doar
-- ce e al lui.
local eraOfLink: { [string]: number } = {}
local eraOfLine: { [string]: number } = {}
for era, list in eraLinks do
    for _, link in list do
        if link ~= "nets" then
            eraOfLink[link] = era
        end
    end
    for _, line in StationConfig.ERA_LINES[era] do
        eraOfLine[line] = era
    end
end
StationConfig.ERA_OF_LINK = eraOfLink
StationConfig.ERA_OF_LINE = eraOfLine
-- Pasii dinaintea atelierului unei linii: acolo marfa e inca bruta (busteni, nu scanduri).
local beforeProcessor: { [string]: boolean } = {}
for _, line in StationConfig.LINE_ORDER do
    for _, step in LINES[line].steps do
        if step.kind == "processor" then
            break
        end
        beforeProcessor[step.link] = true
    end
end
StationConfig.BEFORE_PROCESSOR = beforeProcessor
StationConfig.LINE_STEPS = lineSteps
StationConfig.MANUAL_ROLES = manualRoles
StationConfig.LINK_OF = linkOf
StationConfig.LINKS = links
StationConfig.LINE_OF = lineOf

-- [D70] CE FACE OMUL FIECARUI PAS (HandRoutes): `step.job`, sau dupa pozitie (collect, port, work, haul). `courier` e
-- rezervat curierului din Era 5 (plan, sectiunea 4). Toate liniile, si cele ale barajului, trec pe aici la incarcare:
-- o unire viitoare fara `job` ar fi primit in tacere „collect” pe atelier si ar fi golit plasele de lemn.
StationConfig.JOB_OF_STEP = { "collect", "port", "work", "haul" }
local JOBS = { collect = true, port = true, work = true, haul = true }
-- Meseriile pe pozitii, sau nil si de ce nu se leaga. Pur, ca testele sa-l poata intreba pe linii de proba.
function StationConfig.stepJobs(spec: Line): ({ string }, string?)
    local out: { string } = {}
    local seen: { [string]: boolean } = {}
    local workAt: number? = nil
    for i, step in spec.steps do
        local job = step.job or StationConfig.JOB_OF_STEP[i]
        if job == nil or not JOBS[job] then
            return out, `pasul {i} ({step.role}): meserie necunoscuta {job}`
        end
        if seen[job] then
            return out, `pasul {i} ({step.role}): {job} de doua ori`
        end
        if (job == "work") ~= (step.kind == "processor") then
            return out, `pasul {i} ({step.role}): doar atelierul are „work”`
        end
        seen[job] = true
        if job == "work" then
            workAt = i
        end
        out[i] = job
    end
    if workAt == nil or not seen.haul then
        return out, "linia n-are atelier sau drum spre capat"
    end
    for i, job in out do
        if (job == "collect" or job == "port") and (i > workAt or spec.netKind == nil) then
            return out, `pasul {i}: {job} doar inaintea atelierului, pe o linie cu plase`
        end
        if job == "haul" and i < workAt then
            return out, `pasul {i}: haul doar dupa atelier`
        end
    end
    return out, nil
end
-- linia -> meseria pe pozitie; linia -> meserie -> pas
local stepJobs: { [string]: { string } } = {}
local stepOfJob: { [string]: { [string]: Step } } = {}
for _, line in StationConfig.LINE_ORDER_ALL do
    local spec = LINES[line]
    local jobs, err = StationConfig.stepJobs(spec)
    assert(err == nil, `StationConfig: linia {line}: {err}`)
    stepJobs[line] = jobs
    local byJob: { [string]: Step } = {}
    for i, step in spec.steps do
        byJob[jobs[i]] = step
    end
    stepOfJob[line] = byJob
end
StationConfig.STEP_JOBS = stepJobs
StationConfig.STEP_OF_JOB = stepOfJob

-- Timpul tau, impartit la pasii fara om. 3.6, nu 1.2 (caratul tau din D48): cu 1.2 impartit la
-- patru, tu erai veriga slaba din prima secunda si 24 din 27 de cumparaturi din primele 5 minute
-- nu dadeau nimic -- inclusiv nivelul de plasa cerut de quest.
StationConfig.PLAYER_LABOR = 3.6
-- Baze DIFERITE pe meseriile de drum: cu toate egale, o treapta pe una singura dadea zero pana le
-- cumparai pe toate trei. Sawyer-ul si Negustorul n-au baza: inmultesc capacitatea cladirii.
-- [D56] Oamenii de drum ai fierului au baze mai mici (plasa de scrap e una singura); Iron Hauler-ul, ultimul, duce
-- macar cat tot timpul tau cu traista mare, altfel angajarea lui ar putea scadea venitul.
StationConfig.ROLE_BASE = {
    collector = 4.0,
    porter = 6.0,
    hauler = 9.0,
    scrapCollector = 2.0,
    scrapPorter = 2.5,
    ironHauler = 6.5,
    millCollector = 4.0,
    millPorter = 6.0,
    partsHauler = 9.0,
    oreCollector = 2.0,
    orePorter = 2.5,
    copperHauler = 6.5,
    worksCollector = 4.0,
    worksPorter = 6.0,
    coilHauler = 9.0,
    batteryCollector = 2.0,
    batteryPorter = 2.5,
    powerHauler = 6.5,
    -- [D70] Era 4 (sim_tycoon.py): baze fara egalitati intre oamenii de drum (check_lines, `walker_ties`); Pylon
    -- Runner-ul duce macar tot timpul tau (check_hire_order); Crystal Porter-ul la 2.7, nu 2.5: Collector-ul pe treapta
    -- cinci ducea cat Porter-ul pe patru si tinea linia la egalitate jumatate de era
    damCollector = 4.7,
    damPorter = 6.3,
    barrelHauler = 7.3,
    cableCollector = 4.0,
    cablePorter = 5.4,
    cableHauler = 6.7,
    pylonRunner = 6.5,
    crystalCollector = 2.0,
    crystalPorter = 2.7,
    ingotHauler = 6.5,
}
StationConfig.TIER_STEP = 1.0 -- fiecare treapta adauga inca o data baza: treapta 5 = de 5 ori
StationConfig.TIER_MAX = 5
StationConfig.TIER_COST_BASE = 25.0 -- 25 / 75 / 225 / 675
StationConfig.TIER_COST_GROWTH = 3.0
StationConfig.SECOND_AT_TIER = 3 -- al doilea om pe aceeasi treaba se deschide de la treapta asta
StationConfig.MAX_PEOPLE = 2 -- in Era 1

-- Statia "Carry" din D48 nu mai exista. Baza ei ramane DOAR pentru migrarea v5, care da inapoi
-- o singura data monedele platite pe nivelurile ei [D49, "nimic nu se pierde"].
StationConfig.LEGACY_CARRY_UPGRADE_BASE = 5.0

-- Cate niveluri urca butoanele de cumparare in bloc [Idle Miner: x1/x10/x50/Max]
StationConfig.BULK_STEPS = { 1, 10, 50 }

return StationConfig
