--!strict
-- Datele tycoon-ului tradus 1:1 din scripts/economy/sim_tycoon.py [F0 spec 1.1]. NU se editeaza
-- preturile aici de mana -- ele vin din simulator; acest fisier doar le transporta in joc.
-- Fara tipuri Roblox: fisierul e incarcat si de testele Lune.
--
-- Fraza jucatorului: "This stretch of river is yours. Everything that floats past is money."

export type Effect = {
    kind: string, -- "net" | "flag" | "mul" | "add" | "build" | "upgrade" | "refine" | "hire"
    rate: number?,
    lane: number?, -- net: items/s, banda (1 = cea mai apropiata de malul jucatorului)
    field: string?, -- flag/mul/add: campul din State (camelCase); hire: meseria (CREWS)
    factor: number?,
    amount: number?, -- mul/upgrade/refine: factor; add: cantitate
    good: string?,
    mult: number?,
    cap: number?,
    draw: number?, -- build/upgrade/refine
}

-- CONDITIA in care o deblocare devine cumparabila. Inainte era doar ordinea din tabel, si asta
-- forta cumparaturi moarte: erai obligat sa iei a treia plasa (care nu-ti folosea, caratul era
-- gatuirea) inainte sa poti angaja prima Mana. Acum plasele curg in ordine, iar restul se deschid
-- cand li se implineste conditia -- exact ca in simulator.
export type Needs = {
    netsExactly: number?, -- atatea plase detinute, nici mai multe nici mai putine (lantul de plase)
    netsOwned: number?, -- cel putin atatea plase detinute
    all: boolean?, -- tot restul erei cumparat (clopotul)
    -- ultima plasa detinuta trebuie sa fie cel putin la nivelul asta. Owner-ul: "vreau ca plasa sa
    -- ceara lv2 si apoi sa apara si a doua plasa de lv1, si tot asa pana la ultima plasa". Asa
    -- lumea nu mai ofera plasa urmatoare in timp ce quest-ul inca cere sa o urci pe cea de acum.
    prevNetLevel: number?,
    -- platforma asta trebuie sa fie deja cumparata. Oamenii vin in ordinea raului [D49]: Porter-ul
    -- dupa Collector, Sawyer-ul dupa Porter, Hauler-ul dupa Sawyer -- fiecare angajare scoate la
    -- iveala pasul urmator ca pe noua corvoada.
    after: string?,
    -- [D70] venitul pe secunda (fara 2x Flow) de la care se deschide platforma: clopotul barajului, la
    -- StationConfig.DAM_BELL_INCOME. Il citesc porțile abia la pasul j10; pana atunci Era 4 nu e in joc.
    income: number?,
}

export type Pad = {
    id: string,
    index: number,
    name: string,
    era: number,
    motive: string, -- "C" prinzi mai mult | "V" vinzi mai scump | "A" scapi de o corvoada | "D" deschide urmatorul
    blurb: string, -- o linie in engleza: CE e platforma asta, pe cartonasul de la apropiere
    note: string?, -- efectul care nu se vede in venit (spatiu, o banda noua, o zona deschisa)
    price: number,
    effects: { Effect },
    live: boolean, -- efectul e implementat in F0; altfel platforma exista doar in plan
    x: number?,
    y: number?,
    needs: Needs?,
    -- [D70] plasele barajului au RANGUL lor (baza si costul celei de-a r-a plase dintr-o era) si era cadrului, ca
    -- `unlock_net_ranked` din simulator: turbina si plasele de cablu se cumpara amestecat, deci locul in lista nu mai
    -- spune cat de mare e plasa. Erele 1-3 nu le au (rangul lor iese din index).
    netRank: number?,
    netEra: number?,
}

export type Good = { id: string, value: number }
-- [D55] O parte din ce prinde un fel de plasa: bunul si ponderea lui.
export type CatchPart = { id: string, share: number }

local StationConfig = require(script and script.Parent.StationConfig or "./StationConfig")
local WorldConfig = require(script and script.Parent.WorldConfig or "./WorldConfig")

local TycoonConfig = {}

-- Nivelul pe care trebuie sa-l atinga plasa dinainte ca sa apara urmatoarea. Aceeasi cifra e in
-- simulator (`PREV_NET_LEVEL`) si in quest-ul `net_two`; testul QuestConfig le tine impreuna, ca
-- banda de obiectiv si lumea sa nu se mai poata contrazice.
TycoonConfig.PREV_NET_LEVEL = 2

-- ---- efecte, in oglinda cu net()/mul()/on() din simulator ----
-- `good`: ce prinde plasa [D55] -- nil = lemn (CATCH.wood), "scrap" = CATCH.scrap
local function netEffect(rate: number, lane: number, good: string?): Effect
    return { kind = "net", rate = rate, lane = lane, good = good }
end
local function mulEffect(field: string, factor: number): Effect
    return { kind = "mul", field = field, factor = factor }
end
local function flagEffect(field: string): Effect
    return { kind = "flag", field = field }
end
-- (Efectele `add` / `build` / `upgrade` / `refine` ale erelor 2-4 de dinainte de D46 au iesit odata cu platformele lor
-- [D65]; TycoonMath.stateFor le mai intelege, pentru testele lui de paritate.)
-- Angajarea unui om [D49]. Nu schimba nimic in TycoonMath.State: oamenii intra in lant prin
-- ChainMath, numarati din `data.Hands`. Efectul spune doar CE aduce platforma.
local function hireEffect(role: string): Effect
    return { kind = "hire", field = role }
end

local function pad(t: Pad): Pad
    return t
end

-- [D55] VALOAREA fiecarui fel de marfa. Ordinea tine desenul gramezilor si al plaselor stabil intre doua
-- stari. Pana la D55 tabelul avea si ponderea fiecarui bun in prinderi si banda de la care apare: toate
-- plasele prindeau acelasi amestec, iar dupa plasa a patra si a doua prindea scrap, care trecea prin gater
-- ca si cand ar fi fost lemn. Acum ce prinde o plasa tine de felul ei (CATCH, mai jos).
TycoonConfig.GOODS = {
    { id = "driftwood", value = 1.0 },
    -- se vinde doar topit la atelier: fierul valoreaza cat scrap-ul din care iese (trei scanduri)
    { id = "scrap", value = 3.0 },
    { id = "named", value = 14.0 },
    -- SCANDURA [D48]: o face gaterul din driftwood. Valoreaza cat bustenul: gaterul e acolo de la inceput,
    -- deci un multiplicator ar umfla doar cifrele.
    { id = "planks", value = 1.0 },
    { id = "iron", value = 3.0 }, -- [D55] ce iese din forja atelierului
    -- [D55] nu se mai prind in Era 1 (treceau prin gater, ca scrap-ul); raman pentru ce e deja in profiluri
    { id = "reeds", value = 2.0 },
    { id = "shards", value = 2.5 },
    -- [D65] ERA 2. Plasele Morii prind tot scrap (pornesti cu marfa pe care o stii), dar e alta marfa in gramezi:
    -- merge la turnatorie si se vinde ca PIESE DE MASINI, de StationConfig.ERA2_MULT (3000) ori mai scumpe decat scandura
    -- [D66]. Se vinde doar turnat: piesa valoreaza cat scrap-ul din care iese. La fel minereul si cuprul (de 3000 de ori
    -- fierul).
    { id = "mill_scrap", value = 3000.0 },
    { id = "parts", value = 3000.0 },
    { id = "ore", value = 9000.0 },
    { id = "copper", value = 9000.0 },
    -- gasirile cartierului nou: aceleasi trepte ca `named`, de FIND_MULT ori mai scumpe (media ~42.000)
    { id = "named2", value = 42000.0 },
    -- [D67] ERA 3, de StationConfig.ERA3_MULT (9 000 000) ori Era 1. Plasele Wire Works prind minereu de cupru, care iese
    -- BOBINE de sarma (bobina valoreaza cat minereul). Turbina umple BATERII, care ies CELULE de energie: o turbina nu
    -- prinde gasiri din rau, deci bateria valoreaza singura cat media unei plase de minereu (3.5 x 9 000 000).
    { id = "works_ore", value = 9000000.0 },
    { id = "coils", value = 9000000.0 },
    { id = "battery", value = 31500000.0 },
    { id = "cell", value = 31500000.0 },
    { id = "named3", value = 126000000.0 },
    -- [D70] ERA 4, „The Dam", de StationConfig.ERA4_MULT (2,7e10) ori Era 1. PIESELE NU SE VAND (D70 Runda 4): sarcina
    -- turbinei din baraj iese BUTOAIE, minereul de cablu iese CABLU, iar amandoua valoreaza doar unite, ca unitate de curent
    -- livrata orasului (1,65 x: oglinda mediei primei linii a fiecarei ere). Cristalul iese LINGOU, cat bateria din Era 3,
    -- si se vinde primul la oras. Scrise ca produs, ca in simulator: un literal ar putea muta un ulp. In joc abia de la
    -- pasul j al planului motorului (StationConfig.ENGINE_ERAS).
    { id = "charge", value = 0.0 },
    { id = "barrel", value = 0.0 },
    { id = "cable_ore", value = 0.0 },
    { id = "cable", value = 0.0 },
    { id = "grid", value = 1.65 * 27000000000.0 },
    { id = "crystal", value = 3.5 * 27000000000.0 },
    { id = "ingot", value = 3.5 * 27000000000.0 },
} :: { Good }

-- [D55] CE PRINDE O PLASA, dupa felul ei. In ordinea simulatorului (`CATCH` din sim_tycoon.py): ordinea sumei
-- valorii medii conteaza pentru paritatea la bit. Plasele 1-4 prind lemn; ultima, cea din larg, scrap
-- [owner, 2026-09-13: "scraps ar trebui sa poti prinde doar la ultimul net"].
TycoonConfig.CATCH = {
    wood = { { id = "driftwood", share = 0.95 }, { id = "named", share = 0.05 } },
    scrap = { { id = "scrap", share = 0.95 }, { id = "named", share = 0.05 } },
    -- [D65] plasele Morii (scrap pentru turnatorie) si plasa de minereu; gasirile lor sunt ale Erei 2
    mill = { { id = "mill_scrap", share = 0.95 }, { id = "named2", share = 0.05 } },
    ore = { { id = "ore", share = 0.95 }, { id = "named2", share = 0.05 } },
    -- [D67] plasele Wire Works (minereu de cupru, gasirile Erei 3) si turbina (doar baterii)
    works = { { id = "works_ore", share = 0.95 }, { id = "named3", share = 0.05 } },
    turbine = { { id = "battery", share = 1.0 } },
    -- [D70] Era 4: turbina din baraj umple sarcina; plasele de sub baraj nu prind gasiri (D70 Runda 5: o gasire nu se poate
    -- uni cu un butoi). Surprizele raman darurile raului si undita.
    dam = { { id = "charge", share = 1.0 } },
    cable_ore = { { id = "cable_ore", share = 1.0 } },
    crystal = { { id = "crystal", share = 1.0 } },
} :: { [string]: { CatchPart } }

-- [D65] CUM SE DESENEAZA MARFA EREI 2 PANA LA ARTA EI (docs/PLAN-ERA2.md, pasul 7): cu desenele perechii din Era 1.
-- Gramezile (PileView), roabele (PersonView) si plasele (NetController) intreaba aici inainte sa-si caute desenul. Cand
-- o marfa isi primeste arta, randul ei iese de aici. `named2` ramane: o gasire se deseneaza ca lada, in orice era.
TycoonConfig.GOOD_LOOKS_LIKE = {
    mill_scrap = "scrap",
    parts = "iron",
    ore = "scrap",
    copper = "iron",
    named2 = "named",
    -- [D67] marfa Erei 3, pana la arta ei (docs/PLAN-ERA3.md, pasul 7): cu desenele Morii
    works_ore = "ore",
    coils = "copper",
    battery = "parts",
    cell = "parts",
    named3 = "named",
} :: { [string]: string }
function TycoonConfig.lookOf(good: string): string
    return TycoonConfig.GOOD_LOOKS_LIKE[good] or good
end

-- [D65] La fel PLATFORMELE Morii: pana la arta lor poarta casa, ruina si avizierul perechii din Era 1 (Moara e asezata
-- in oglinda, deci fiecare are una). Roata de apa n-are pereche; PadArt ii da un desen de imprumut. Cand o platforma isi
-- primeste arta, randul ei iese de aici.
TycoonConfig.PAD_LOOKS_LIKE = {
    hire_mill_collector = "first_runner",
    hire_mill_porter = "hire_porter",
    hire_founder = "hire_sawyer",
    hire_parts_hauler = "hire_hauler",
    hire_merchant = "dock_trader",
    copper_furnace = "workshop",
    ore_shed = "scrap_shed",
    hire_ore_collector = "hire_scrap_collector",
    hire_ore_porter = "hire_scrap_porter",
    hire_coppersmith = "hire_smelter",
    hire_copper_hauler = "hire_iron_hauler",
    mill_bell = "landing_bell",
    -- [D67] platformele Erei 3 poarta, pana la arta lor, desenele perechii din Moara
    hire_works_collector = "hire_mill_collector",
    hire_works_porter = "hire_mill_porter",
    hire_wiredrawer = "hire_founder",
    hire_coil_hauler = "hire_parts_hauler",
    hire_clerk = "hire_merchant",
    power_house = "copper_furnace",
    battery_shed = "ore_shed",
    hire_battery_collector = "hire_ore_collector",
    hire_battery_porter = "hire_ore_porter",
    hire_electrician = "hire_coppersmith",
    hire_power_hauler = "hire_copper_hauler",
    works_bell = "mill_bell",
    -- masina cu abur n-are pereche in Moara: poarta, pana la arta ei, cladirea de caramida a cuptorului de cupru
    steam_engine = "copper_furnace",
    -- [D70] platformele barajului poarta, pana la arta lor, desenele unei perechi din erele dinainte, fiecare alta (doua
    -- colibe identice una langa alta ar parea aceeasi meserie): butoaiele pe linia curentului, cablul pe linia bobinelor,
    -- unirea pe linia pieselor din Moara, cristalul pe linia cuprului
    hire_dam_collector = "hire_battery_collector",
    hire_dam_porter = "hire_battery_porter",
    hire_switchman = "hire_electrician",
    hire_barrel_hauler = "hire_power_hauler",
    hire_dispatcher = "hire_clerk",
    hire_cable_collector = "hire_works_collector",
    hire_cable_porter = "hire_works_porter",
    hire_cablemaker = "hire_wiredrawer",
    hire_cable_hauler = "hire_coil_hauler",
    hire_relay_keeper = "hire_founder",
    hire_pylon_runner = "hire_parts_hauler",
    crystal_kiln = "power_house",
    crystal_shed = "battery_shed",
    hire_crystal_collector = "hire_ore_collector",
    hire_crystal_porter = "hire_ore_porter",
    hire_crystalsmith = "hire_coppersmith",
    hire_ingot_hauler = "hire_copper_hauler",
    dam_bell = "works_bell",
} :: { [string]: string }

-- [D65] GASIRILE, pe ere: aceleasi trepte (NAMED_VALUE), inmultite cu cadrul erei. `named` e al Erei 1.
TycoonConfig.FIND_MULT = { named = 1, named2 = 3000, named3 = 9000000 } :: { [string]: number }
-- Ce iese din fiecare marfa bruta dupa atelierul ei (pentru nume si desene; valoarea e aceeasi, vezi GOODS).
TycoonConfig.PROCESSED = {
    driftwood = "planks",
    scrap = "iron",
    mill_scrap = "parts",
    ore = "copper",
    works_ore = "coils", -- [D67]
    battery = "cell",
    -- [D70] Era 4: sarcina iese butoi, minereul de cablu iese cablu, cristalul iese lingou
    charge = "barrel",
    cable_ore = "cable",
    crystal = "ingot",
} :: { [string]: string }
-- [D70] Ce se UNESTE la Relay Station: un butoi si o bucata de cablu fac o unitate de curent pentru oras (reteta 1:1,
-- StationConfig.LINES.grid.inputs). Il citeste unirea din FlowMath, la pasul i al planului motorului.
TycoonConfig.JOINED = { grid = { "barrel", "cable" } } :: { [string]: { string } }

-- Valoarea de vanzare a unui obiect cu nume, pe tier (ipoteza -- media ponderata ~14, cat cere GOODS.named)
TycoonConfig.NAMED_VALUE = {
    common = 6,
    uncommon = 11,
    rare = 22,
    epic = 45,
    legendary = 90,
    mythic = 180,
}

-- Toate constantele pe care income() din simulator le are batute in cuie. Un singur loc, ca sa nu
-- se dezalinieze de restul TycoonMath (sellMultiplier foloseste aceleasi trei de la coada).
TycoonConfig.MODEL = {
    manualEff = 0.70,
    manualEffBigSack = 0.82,
    manualCrowd = 0.08,
    netsPerRunner = 3,
    millerMult = 1.2,
    boatYield = 0.35,
    dockhandMult = 1.2,
    indexBonus = 0.01,
    rebirthBonus = 0.5,
}

TycoonConfig.REAL = 1.8 -- jucator real ~1.8x mai lent decat cel lacom (ipoteza, de masurat)
TycoonConfig.TARGET_WAIT = { base = 20, growth = 1.125, cap = 420 }
TycoonConfig.NICE =
    { 1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 7.5, 8, 9 }

-- Praguri pe plase [nota 43, pct.7]: a 4-a, a 8-a si a 12-a plasa dau un spor GRATUIT de rata,
-- peste efectul lor. A patra cumparare de acelasi fel e cea la care jucatorul incepe sa se
-- plictiseasca; tocmai acolo primeste mai mult decat a platit. Aceleasi cifre ca in simulator
-- (NET_MILESTONES din sim_tycoon.py) -- daca se schimba acolo, se schimba si aici, altfel
-- testul de paritate pica.
TycoonConfig.NET_MILESTONES = { [4] = 1.10, [8] = 1.10, [12] = 1.10 }

TycoonConfig.NET_CAPACITY = 12
-- Cat tine o plasa, in secunde de prindere [D49]. Cu 12 locuri fixe, o plasa de nivel 50 se umplea
-- in 2 s si statea plina pana trecea cineva -- deci prindea mult sub cifra din meniu, iar
-- Collector-ul ar fi dus mai putin decat promite. Ciclul oricarui Collector sta sub pragul asta
-- (testul din HandRoutes). Capacitatea reala: TycoonMath.netCapacity.
TycoonConfig.NET_HOLD_SECONDS = 30
-- [D51] PRIMA PLASA, PRIMA DATA, SE UMPLE MAI REPEDE -- doar pentru tutorial. Primul quest cere o plasa
-- plina (12), iar la ritmul normal asta ar fi fost ~36 s de asteptare chiar in primul minut [owner,
-- 2026-09-13: "prima data vreau sa se umple mai repede, doar pentru tutorial"]. Tine pana ai colectat
-- `untilCollected` bucati; plasa poarta o eticheta cat tine, ca ritmul din meniu sa nu minta [D40].
TycoonConfig.FIRST_CATCH = { pad = "first_net", untilCollected = 12, speed = 3 }
TycoonConfig.SACK_CAPACITY = 30
TycoonConfig.SACK_BIG_CAPACITY = 60
TycoonConfig.PAD_SIZE = 96
-- Cladirea de pe o platforma sta cu baza la atatia px sub cadrul platformei (PadController o prinde acolo). Fumul,
-- firele si testele de asezare citesc baza tot de aici, prin `buildingBase`: cand fumul atelierelor de pe platforme o
-- socotea singur (pad.y + 8, fara jumatatea cadrului), iesea cu 48 px deasupra hornului.
TycoonConfig.BUILDING_DROP = 8

-- [D65] CARTIERUL MORII E ASEZAT CA THE LANDING [D57], mutat spre aval cu atat: fiecare lucru al Erei 2 sta fata de
-- cartierul lui unde sta perechea lui din Era 1 fata de al ei (plasele pe punte, magazia sub ele, atelierul cu fata la
-- strada, vanzatorul in capatul dinspre amonte, casele pe un rand peste strada). Strada Morii continua strada satului.
local MILL_DX = 1680
TycoonConfig.MILL_DX = MILL_DX
-- [D67] Cartierul Erei 3, The Wire Works, e asezat la fel, inca o data mai spre aval.
local WORKS_DX = 2 * MILL_DX
TycoonConfig.WORKS_DX = WORKS_DX

-- [D50] Locul de VANZARE: usa tavernei, pe drumul mare. Numele `DOCK` ramane (e si id-ul statiei, al
-- quest-urilor si al profilului), ca toti cititorii lui sa urmeze singuri locul nou. Pontonul cu barca
-- e acum separat (PIER): pana in D50 acelasi punct era si ponton, si loc de vanzare.
TycoonConfig.DOCK = { x = 420, y = 1130 }
-- [D59] PONTONUL LUNG: 32x104 la PIXEL_SCALE 3 (96x312), centrat, deci y 602..914 -- baza ramane unde era pier3, iar
-- capatul intra ~150 px in rau. Pe el mergi pana la capat (PIER_WALK), unde pescuiesti (FISH_STAND); plutitorul cade in
-- aval (BOBBER_AT), iar ce aduce raul asteapta in amonte (TREASURE_SLOTS). Owner-ul: "A si B cum recomanzi, apuca-te".
TycoonConfig.PIER = { x = 300, y = 758 }
-- Trecerea prin rau: scandurile pontonului, fara grinzile de pe margini (x 264..336), de la capat (y 612) pana la mal.
TycoonConfig.PIER_WALK = { x0 = 264, x1 = 336, y0 = 612 }
-- Picioarele tale cand pescuiesti: pe capat, spre dreapta, cu fata la apa.
TycoonConfig.FISH_STAND = { x = 318, y = 640 }
-- Unde cade plutitorul: in aval de capat, departe de plase (prima e la x 620) si sub curentul bustenilor (y 552).
TycoonConfig.BOBBER_AT = { x = 435, y = 652 }
-- [D60] BARCA BALCIULUI, legata in aval de ponton, intre plutitor si mal: 62x30 la x2 (124x60), prinsa de baza, deci
-- x 356..480, y 702..762 -- sub firul si plutitorul unditei (y <= 656), peste mal (768), fara sa atinga avizierul
-- (y >= 762) sau prima plasa (x >= 548). Bustenii trec pe curentul de sus (NEAR_CURRENT_Y), nu pe aici. Barca vanzarii
-- (DockController) pleaca din spatele ei. Pe apa nu se merge: urci din marginea pontonului, de la FERRY_BOARD.
TycoonConfig.FERRY = { x = 418, y = 762 }
TycoonConfig.FERRY_BOARD = { x = 330, y = 734 }
-- Locurile lucrurilor aduse de rau, in amonte, lipite de ponton: vin din stanga si se opresc in el. Centrele (cutia
-- cea mai mare, 60x48, nu atinge pontonul si nici vecinul).
TycoonConfig.TREASURE_SLOTS = { { x = 214, y = 610 }, { x = 214, y = 660 }, { x = 214, y = 710 } }
-- Taverna, prinsa de baza: sprite de 64x48 la PIXEL_SCALE 3 = 192x144, deci ocupa x 304..496 si
-- y 936..1080 -- sub ponton (care se termina la y 914), deasupra drumului mare (y >= 1100).
TycoonConfig.TAVERN = { x = 400, y = 1080, w = 192, h = 144 }
TycoonConfig.LANE_Y = { 732, 660, 588 } -- banda 1 e cea mai aproape de mal
TycoonConfig.FAR_CURRENT_Y = 516 -- curentul din larg: decorul, bunurile care inca nu se pot prinde [D53]
-- [D53] Curentul de langa plase: pe el vin bustenii care vor fi prinsi (CatchFloat). Sub decor, deasupra
-- oricarei plase din amonte (varful benzii 2 e la 633); bustean de 27 px inalt -> 533..572.
TycoonConfig.NEAR_CURRENT_Y = 552
-- [D57] Pe iarba curtii lemnului, langa aleea tavernei: personajul (48x72) nu apare intr-o cladire, iar prima plasa e
-- chiar deasupra lui, pe punte -- primul pas al tutorialului se vede din prima clipa.
TycoonConfig.SPAWN = { x = 660, y = 1200 }

export type Rect = { x0: number, x1: number, y0: number, y1: number }
-- `like`: drumul sau curtea din The Landing pe care o oglindeste [D65]. Pamantul copt (scripts/art/village_ground.py)
-- isi deseneaza detaliile dupa el: piata de piatra, potecile dintre case, zgura din curtea cuptorului.
export type Road = { id: string, x0: number, x1: number, y0: number, y1: number, like: string? }

-- [F3] Malul construit. Pontonul e fasia de scanduri de-a lungul apei, pe care stau stalpii plaselor.
-- Se termina la legatura depozitului: mai departe ar fi fost scanduri pe care nu calca nimeni [D50].
-- Totul in coordonate LOCALE terenului, ca restul pozitiilor [B5].
TycoonConfig.DECK = { x0 = 240, x1 = 1560, y0 = 772, y1 = 856 } :: Rect

-- [D50, D57] DRUMURILE. D57 -- SATUL PE FLUX [owner, 2026-09-14: "par foarte random plasate si fara cap"]: fiecare
-- linie are curtea ei sub plasele ei (lemnul langa taverna, fierul spre Moara); marfa bruta coboara de pe punte pe o
-- alee, cea gata iese pe strada satului si merge pe ea spre taverna. Patru drumuri, in loc de sapte: strada, doua
-- alei si piata tavernei. Dreptunghiuri care doar SE ATING, niciunul nu-l incruciseaza pe altul: capatul unuia cade pe
-- marginea altuia. Din ele (plus DECK) RoadGraph face graful pe care merg oamenii si dara de ghidaj, iar SceneArt le
-- deseneaza (piata din piatra, restul pamant).
TycoonConfig.ROADS = {
    { id = "street", x0 = 240, x1 = 1860, y0 = 1420, y1 = 1480 }, -- strada satului: marfa gata spre taverna
    { id = "tavern_link", x0 = 525, x1 = 575, y0 = 856, y1 = 1420 }, -- puntea -> strada, aleea curtii lemnului
    { id = "plaza", x0 = 240, x1 = 550, y0 = 1090, y1 = 1170 }, -- piata din fata tavernei, cu usa ei (DOCK)
    { id = "iron_lane", x0 = 1260, x1 = 1300, y0 = 856, y1 = 1420 }, -- puntea -> strada, aleea curtii fierului
} :: { Road }

-- [D57] PAMANTUL BATATORIT. Owner-ul, pe harta de azi: "texturile obiectelor... parca plutesc mereu, nu fac parte din
-- realul absolut al jocului"; pe previzualizarea satului: "si casele oamenilor ar trebui sa stea pe ceva pamant".
-- Nimic construit nu mai sta direct pe iarba: curtile de lucru, piata tavernei (pamant in jurul pietrei) si fiecare
-- casa au pamantul lor, cu iarba peste margini. Doar desen (SceneArt); nimeni nu merge altfel din cauza lor.
export type Yard = { id: string, x0: number, x1: number, y0: number, y1: number, like: string? }
TycoonConfig.YARDS = {
    { id = "tavern", x0 = 222, x1 = 584, y0 = 1040, y1 = 1196 },
    { id = "stall", x0 = 280, x1 = 440, y0 = 1248, y1 = 1318 },
    { id = "storage", x0 = 580, x1 = 836, y0 = 968, y1 = 1040 },
    { id = "sawmill", x0 = 820, x1 = 1190, y0 = 1326, y1 = 1418 },
    { id = "shed", x0 = 1310, x1 = 1560, y0 = 968, y1 = 1040 },
    { id = "forge", x0 = 1414, x1 = 1856, y0 = 1318, y1 = 1418 },
    { id = "bell", x0 = 1712, x1 = 1848, y0 = 984, y1 = 1036 },
    { id = "sack", x0 = 430, x1 = 512, y0 = 1598, y1 = 1638 },
    -- casele: putin mai late decat casa (cea mare), de la zidul din spate pana in fata usii. Id-urile NU sunt cele ale
    -- platformelor: simulatorul cauta pretul unei platforme dupa primul `id = "..."` din fisier.
    { id = "house_collector", x0 = 546, x1 = 714, y0 = 1594, y1 = 1638 },
    { id = "house_porter", x0 = 718, x1 = 862, y0 = 1594, y1 = 1638 },
    { id = "house_sawyer", x0 = 878, x1 = 1022, y0 = 1594, y1 = 1638 },
    { id = "house_hauler", x0 = 1038, x1 = 1182, y0 = 1594, y1 = 1638 },
    { id = "house_scrap_collector", x0 = 1228, x1 = 1372, y0 = 1594, y1 = 1638 },
    { id = "house_scrap_porter", x0 = 1378, x1 = 1522, y0 = 1594, y1 = 1638 },
    { id = "house_smelter", x0 = 1528, x1 = 1672, y0 = 1594, y1 = 1638 },
    { id = "house_iron_hauler", x0 = 1678, x1 = 1822, y0 = 1594, y1 = 1638 },
} :: { Yard }

-- [D57] DECORUL ASEZAT DE MANA, pe teren (in afara lui ramane decorul imprastiat din seed, WorldDecor). Fiecare lucru
-- spune ceva despre locul lui: butoiul si felinarele pietei, stiva de busteni si butucii curtii lemnului, pietrele si
-- butoaiele de langa forja, gardurile curtilor spre strada. `sprite` = cheia din Assets.props; `y` = baza.
export type DecorItem = { sprite: string, x: number, y: number, scale: number }
TycoonConfig.DECOR = {
    -- piata tavernei
    { sprite = "barrel", x = 500, y = 1084, scale = 2 },
    { sprite = "lantern", x = 256, y = 1190, scale = 2 },
    { sprite = "lantern", x = 598, y = 1190, scale = 2 }, -- peste alee: langa usa ar sta in spatele Negustorului
    { sprite = "flowers", x = 452, y = 1296, scale = 2 },
    { sprite = "flowers", x = 258, y = 1296, scale = 2 },
    { sprite = "tree_pine", x = 215, y = 1400, scale = 2 },
    -- curtea lemnului
    { sprite = "log", x = 880, y = 1046, scale = 2 },
    { sprite = "log", x = 902, y = 1066, scale = 2 },
    { sprite = "log", x = 874, y = 1086, scale = 2 },
    { sprite = "stump", x = 720, y = 1190, scale = 2 },
    { sprite = "stump", x = 760, y = 1212, scale = 2 },
    { sprite = "tree_round", x = 1130, y = 1130, scale = 2 },
    { sprite = "flowers", x = 1000, y = 1190, scale = 2 },
    { sprite = "bush", x = 660, y = 1262, scale = 2 },
    { sprite = "signpost", x = 612, y = 1414, scale = 2 },
    { sprite = "fence", x = 638, y = 1418, scale = 2 },
    { sprite = "fence", x = 734, y = 1418, scale = 2 },
    -- intre curti
    { sprite = "bush", x = 1205, y = 1390, scale = 2 },
    -- curtea fierului
    { sprite = "tree_round", x = 1450, y = 1180, scale = 2 },
    { sprite = "rock_small", x = 1580, y = 1170, scale = 3 },
    { sprite = "rock_large", x = 1636, y = 1196, scale = 2 },
    { sprite = "barrel", x = 1730, y = 1196, scale = 2 },
    { sprite = "barrel", x = 1756, y = 1214, scale = 2 },
    { sprite = "bush", x = 1836, y = 1220, scale = 2 },
    { sprite = "flowers", x = 1712, y = 1050, scale = 2 },
    { sprite = "signpost", x = 1334, y = 1414, scale = 2 },
    { sprite = "fence", x = 1358, y = 1418, scale = 2 },
    -- felinarele strazii, pe marginea ei de sud. [D67] Cel dintre curti (x 1215) a plecat: felinarul electric dintre
    -- Hauler si Scrap Collector (TycoonConfig.streetLamps, x 1205) statea chiar peste el.
    { sprite = "lantern", x = 232, y = 1506, scale = 2 },
    { sprite = "lantern", x = 1848, y = 1506, scale = 2 },
    -- flori intre case, bufnite de iarba la capetele randurilor (sudul ramane deschis)
    { sprite = "flowers", x = 716, y = 1606, scale = 2 },
    { sprite = "flowers", x = 1030, y = 1606, scale = 2 },
    { sprite = "flowers", x = 1375, y = 1606, scale = 2 },
    { sprite = "flowers", x = 1675, y = 1606, scale = 2 },
    { sprite = "bush", x = 520, y = 1650, scale = 2 },
    { sprite = "bush", x = 1840, y = 1650, scale = 2 },
} :: { DecorItem }

-- Un singur limbaj de marime: personajul (48x72) e etalonul. Recuzita mica se deseneaza la x2,
-- cladirile adevarate raman la x3 (PIXEL_SCALE). Plasa are marimea ei, mai mica decat cutia de
-- 144x84 de dinainte, care se citea ca o fereastra.
TycoonConfig.PROP_SCALE = 2
TycoonConfig.NET_DRAW = { w = 96, h = 54 }

-- Numele afisate ale bunurilor ("+1 Driftwood"). Separat de GOODS, ca GOODS sa ramana exact
-- tabelul simulatorului.
TycoonConfig.GOOD_NAMES = {
    driftwood = "Driftwood",
    scrap = "Scrap",
    reeds = "Reeds",
    shards = "Shards",
    named = "Find",
    planks = "Planks",
    iron = "Iron",
    -- [D65] Era 2: pe plasa scrie tot "Scrap" (e aceeasi marfa a raului), din turnatorie iese "Machine Part"
    mill_scrap = "Scrap",
    parts = "Machine Part",
    ore = "Copper Ore",
    copper = "Copper",
    named2 = "Find",
    -- [D67] Era 3: minereul de cupru al Wire Works, bobinele, bateriile turbinei, celulele de energie
    works_ore = "Copper Ore",
    coils = "Coil",
    battery = "Battery",
    cell = "Power Cell",
    named3 = "Find",
}

-- [B5] Toate pozitiile de platforme, plase, debarcader si zone sunt LOCALE terenului. Lumea =
-- PLOT_ORIGIN + local. Azi originea e (0, 0), deci local = lume; conventia exista ca mai multe
-- terenuri pe acelasi server sa fie posibile mai tarziu (aria R) fara sa rescriem pozitiile.
TycoonConfig.PLOT_ORIGIN = { x = 0, y = 0 }

-- Cartierele terenului, de la vest la est (aval). Zona unei ere se vede de la inceput, estompata
-- si ingradita, si se deschide cu clopotul erei dinainte [B, B4]. `soon`: ce scrie panoul cat era nu e in joc (fara el,
-- Strings.zoneSoon).
-- [D70] `fence = false`: zona n-are gard (Dam Town, lumea 2: e deschisa de cand ajungi acolo).
export type Zone = {
    id: string,
    name: string,
    era: number,
    x0: number,
    x1: number,
    soon: string?,
    fence: boolean?,
}
TycoonConfig.ZONES = {
    { id = "landing", name = "The Landing", era = 1, x0 = 200, x1 = 1860 },
    { id = "mill", name = "The Mill", era = 2, x0 = 1860, x1 = 3560 },
    -- [D67] Era 3, cat e in constructie: deschisa de clopotul Morii, dar estompata si cu "coming soon" (ZoneController)
    { id = "wire_works", name = "The Wire Works", era = 3, x0 = 3560, x1 = 5240 },
    -- [D67] Era 4 e doar anuntata: gardul si ceata ei, pana la marginea lumii (RiverConfig.WORLD_WIDTH). [D73] Barajul nu se
    -- va ridica aici, ci langa ponton (PLAN-HARTA, sectiunea 6 punctul 7): panoul spune unde, cat era nu e in joc.
    {
        id = "dam",
        name = "The Dam",
        era = 4,
        x0 = 5240,
        x1 = 5520,
        soon = "The Dam will rise by your pier — coming soon",
    },
} :: { Zone }

-- Unde sta Negustorul: la tejgheaua tavernei, in piata din fata ei [D57], in dreapta usii (DOCK). Picioarele la
-- y 1152, deci capul (y 1080) atinge baza tavernei fara sa intre peste ea: amandoua se ating cu
-- degetul, iar doua lucruri apasabile care se suprapun isi fura clicurile.
-- Un rol static are nevoie de o pozitie fixa -- nu are ciclu din care sa iasa una.
TycoonConfig.TRADER_STAND = { x = 470, y = 1152 }
-- Roata zilnica, ca OBIECT in lume, nu doar ca intrare in bara de meniu: la ei se vede in mina, si
-- de-aia se stie ca exista. [D59] Nu mai sta in coltul de jos al satului, pe unde nu trece nicio bucla: e un timonier de
-- lemn pe punte, langa ponton, unde astepti -- iar darurile ei (perle, ce aduce raul, momeala) sunt ale pontonului.
-- Sprite 40x48 la x2 (80x96), prins de baza: x 360..440, y 754..850. Pe punte nu umbla nimeni la vest de aleea tavernei.
TycoonConfig.WHEEL_STAND = { x = 400, y = 850 }
-- [D59] Avizierul satului (perlele cumpara aspect), langa roata: 40x44 la x2 (80x88), x 446..526, y 762..850.
TycoonConfig.VILLAGE_BOARD = { x = 486, y = 850 }

-- OAMENII CARE MERG [D49]: Collector, Porter, Hauler. Aceeasi viteza (jumatate din a jucatorului)
-- si aceleasi pauze pentru toti; unde merge fiecare vine din HandRoutes. Merg in linie dreapta, ca
-- alergatorul de dinainte: cladirile nu blocheaza mersul (WorldMap.blockedRects = doar raul).
TycoonConfig.RUNNER = {
    speed = 150,
    pauseNet = 0.6, -- la fiecare oprire: plasa, depozitul, gura gaterului
    pauseDock = 1.0, -- la capat, unde lasa marfa
}

-- DEPOZITUL [D49]: unde Collector-ul varsa ce strange din plase, iar Porter-ul ia de acolo. [D57] Sus in curtea
-- lemnului, sub primele plase, langa aleea tavernei. Prins de baza; sprite de 40x32 la PIXEL_SCALE 3 = 120x96, deci
-- ocupa x 700..820 si y 914..1010.
TycoonConfig.STORAGE = { x = 760, y = 1010, w = 120, h = 96 }
-- [D55] la stanga gramezii, pe marginea aleii: omul sta cu fata spre ea si rastoarna roaba peste ea
TycoonConfig.STORAGE_STAND = { x = 600, y = 1010 }

-- GATERUL [D49]: departe de plase [owner, 2026-09-13: "sawmill-ul este prea aproape de nets"]. [D57] Jos in curtea
-- lemnului, cu fata la strada: Porter-ul coboara aleea si merge pe strada pana la el (~820 px), iar scandurile pleaca
-- direct pe strada spre taverna. Prins de baza: ocupa x 940..1060, y 1284..1380.
TycoonConfig.SAWMILL = { x = 1000, y = 1380, w = 120, h = 96 }
-- Unde stai ca sa tai si ca sa predai tu, in fata usii, pe marginea strazii.
TycoonConfig.SAWMILL_STAND = { x = 980, y = 1405 }
-- [D55] Bustenii STANGA, scandurile DREAPTA, lipite de cladire -- exact sensul din desenul gaterului
-- (bustenul intra din stanga, panza e in dreapta) [owner: "ar trebui sa fie macar langa sawmill in stanga
-- respectiv in dreapta, nu mai jos de poteca"]. Porter-ul sta la stanga gramezii de busteni, Hauler-ul la dreapta
-- celei de scanduri, amandoi pe marginea strazii, fiecare cu fata spre gramada lui.
TycoonConfig.SAWMILL_IN = { x = 840, y = 1410 }
TycoonConfig.SAWMILL_OUT = { x = 1165, y = 1412 }
-- Sawyer-ul, pe strada, in dreapta panzei. Omul (48x72, prins de picioare) incepe la y 1380, sub gramada de scanduri:
-- mai sus ar intra peste ea si doua lucruri apasabile s-ar calca.
TycoonConfig.SAWYER_STAND = { x = 1110, y = 1452 }

-- [D50] GRAMEZILE, ca locuri fixe. [D55] `x` = mijlocul, `y` = BAZA gramezii (desenul pe trepte, 80x56, se
-- prinde de baza, ca o cladire); cifra sta deasupra. Verificate de testul de asezare.
export type PileSpot = { x: number, y: number, pill: string? }
TycoonConfig.PILES = {
    storage = { x = 660, y = 1010 }, -- [D57] lipita de stanga depozitului, intre el si alee
    shed = { x = 1390, y = 1010 }, -- [D55, D57] lipita de stanga shed-ului, intre el si aleea fierului
    sawmillIn = { x = 900, y = 1380 }, -- bustenii, lipiti de stanga gaterului
    sawmillOut = { x = 1105, y = 1380 }, -- scandurile, lipite de dreapta lui
    forgeIn = { x = 1494, y = 1380 }, -- [D55] scrap-ul de topit, la stanga forjei
    forgeOut = { x = 1766, y = 1380 }, -- [D55] fierul, la dreapta ei
    tavern = { x = 262, y = 1086 }, -- la stanga tavernei, langa butoaie
} :: { [string]: PileSpot }

-- [D55, D56] LINIA FIERULUI. Unde se opresc oamenii ei la shed si la forja (pe drum, in fata gramezilor) si unde stai
-- tu la forja. [D56] Limitele de adunare din D55 (`SCRAP_BACKLOG`) au iesit: ele tineau aceiasi oameni sa nu care
-- scrap in locul lemnului; acum fiecare linie are oamenii ei, deci n-au ce imparti.
-- [D57] Curtea fierului: shed-ul sus, sub plasa de scrap, langa aleea fierului; forja jos, cu fata la strada. Scrap
-- Porter-ul coboara aleea si merge pe strada pana la forja (~680 px); fierul pleaca pe strada spre taverna.
TycoonConfig.SCRAP_SHED_STAND = { x = 1330, y = 1010 }
TycoonConfig.FORGE_IN = { x = 1430, y = 1410 }
TycoonConfig.FORGE_OUT = { x = 1830, y = 1412 }
TycoonConfig.WORKSHOP_STAND = { x = 1610, y = 1405 } -- [D56] locul tau la forja: inelul ei, cat n-ai Smelter
-- [D56, D57] Smelter-ul sta pe strada, in fata forjei, spre gramada de fier
TycoonConfig.SMELTER_STAND = { x = 1690, y = 1452 }

-- ---- [D65] LOCURILE, CA TABEL ------------------------------------------------------------------
-- Pana la D65 fiecare loc era o constanta cu nume (STORAGE_STAND, SAWMILL_IN, FORGE_OUT, ...) citita de cate un
-- `elseif` pe meserie (HandRoutes) sau de controllerul cladirii ei. Era 2 are aceleasi locuri pentru alte cladiri, deci
-- locurile devin tabel pe LINIE (StationConfig.LINES) si pe VANZATOR; constantele Erei 1 raman si sunt chiar valorile
-- din tabel, ca tot ce le citeste sa mearga mai departe.
--   storeStand    unde sta omul (sau tu) la magazia liniei: cine goleste plasele lasa aici, cine cara ia de aici
--   processorIn   unde se lasa marfa bruta la atelier;  processorOut  de unde se ia marfa gata
--   playerStand   inelul tau la atelier, cat n-are om;   workerStand   unde sta omul atelierului
--   storePile / inPile / outPile   unde se deseneaza gramezile (mijlocul, baza)
--   secondOffset  unde sta al doilea om al atelierului fata de primul
export type LinePlaces = {
    storeStand: { x: number, y: number },
    processorIn: { x: number, y: number },
    processorOut: { x: number, y: number },
    playerStand: { x: number, y: number },
    workerStand: { x: number, y: number },
    storePile: { x: number, y: number },
    inPile: { x: number, y: number },
    outPile: { x: number, y: number },
    secondOffset: { x: number, y: number },
}
-- [D70] LOCURILE UNEI UNIRI (Relay-ul): n-are magazie; fiecare piesa isi are intrarea (unde o lasa omul ei) si gramada.
-- Cheile din `inputIn` / `inPiles` sunt liniile pieselor (StationConfig.LINES[unire].inputs). Datele vin cu harta
-- barajului (pasul j); pana atunci HandRoutes primeste locuri inventate, in teste.
export type JoinPlaces = {
    inputIn: { [string]: { x: number, y: number } },
    inPiles: { [string]: { x: number, y: number } },
    processorOut: { x: number, y: number },
    playerStand: { x: number, y: number },
    workerStand: { x: number, y: number },
    outPile: { x: number, y: number },
    secondOffset: { x: number, y: number },
}
export type SellerPlaces = {
    door: { x: number, y: number }, -- locul de vanzare: usa cladirii, pe drum
    stand: { x: number, y: number }, -- unde sta omul vanzatorului
    pile: { x: number, y: number },
    building: { x: number, y: number, w: number, h: number },
    secondOffset: { x: number, y: number },
    -- [D50, D65] CLIENTII: unde asteapta (picioarele, cu fata spre cine stau) si de unde vin / pe unde pleaca
    customerSpots: { { x: number, y: number, facing: string } },
    customerEntry: { x: number, y: number },
}
local function shifted(p: { x: number, y: number }, dx: number?): { x: number, y: number }
    return { x = p.x + (dx or MILL_DX), y = p.y }
end
-- Clientii tavernei: doi la fereastra-tejghea, restul pe drum si sub el, la cel putin o latime de om unul de altul, pe
-- langa usa (unde se lasa marfa), Innkeeper (x 446..494) si gramada (x <= 293, y <= 1092). Vin de la capatul de vest al
-- drumului mare, putin dincolo de teren. Piata ii are in aceleasi locuri, mutate cu MILL_DX: ai ei vin dinspre sat.
local TAVERN_CUSTOMER_SPOTS = {
    { x = 340, y = 1094, facing = "up" },
    { x = 380, y = 1098, facing = "up" },
    { x = 330, y = 1150, facing = "right" },
    { x = 282, y = 1160, facing = "right" },
    { x = 385, y = 1180, facing = "left" },
    { x = 236, y = 1196, facing = "right" },
    { x = 318, y = 1212, facing = "up" },
    { x = 430, y = 1214, facing = "left" },
}
local TAVERN_CUSTOMER_ENTRY = { x = 150, y = 1130 }
local marketCustomerSpots: { { x: number, y: number, facing: string } } = {}
local depotCustomerSpots: { { x: number, y: number, facing: string } } = {}
-- [D70] clientii tavernei, mutati cu `dx` (orasul barajului)
-- [D70, pasul j7] cladirea Switch House (orasul barajului, lumea 2): o singura copie, a vanzatorului si a lumii
TycoonConfig.DAM_SWITCH_HOUSE = { x = 2039, y = 1080, w = 192, h = 144 }
local function shiftedSpots(dx: number): { { x: number, y: number, facing: string } }
    local out = {}
    for _, spot in TAVERN_CUSTOMER_SPOTS do
        table.insert(out, { x = spot.x + dx, y = spot.y, facing = spot.facing })
    end
    return out
end
for _, spot in TAVERN_CUSTOMER_SPOTS do
    table.insert(marketCustomerSpots, { x = spot.x + MILL_DX, y = spot.y, facing = spot.facing })
    table.insert(depotCustomerSpots, { x = spot.x + WORKS_DX, y = spot.y, facing = spot.facing })
end
TycoonConfig.LINE_PLACES = {
    wood = {
        storeStand = TycoonConfig.STORAGE_STAND,
        processorIn = TycoonConfig.SAWMILL_IN,
        processorOut = TycoonConfig.SAWMILL_OUT,
        playerStand = TycoonConfig.SAWMILL_STAND,
        workerStand = TycoonConfig.SAWYER_STAND,
        storePile = TycoonConfig.PILES.storage,
        inPile = TycoonConfig.PILES.sawmillIn,
        outPile = TycoonConfig.PILES.sawmillOut,
        secondOffset = { x = -60, y = 0 },
    },
    iron = {
        storeStand = TycoonConfig.SCRAP_SHED_STAND,
        processorIn = TycoonConfig.FORGE_IN,
        processorOut = TycoonConfig.FORGE_OUT,
        playerStand = TycoonConfig.WORKSHOP_STAND,
        workerStand = TycoonConfig.SMELTER_STAND,
        storePile = TycoonConfig.PILES.shed,
        inPile = TycoonConfig.PILES.forgeIn,
        outPile = TycoonConfig.PILES.forgeOut,
        secondOffset = { x = 60, y = 0 },
    },
    -- Era 2, in oglinda: magazia Morii si turnatoria pe locul depozitului si al gaterului, magazia de minereu si
    -- cuptorul de cupru pe locul shed-ului si al forjei
    parts = {
        storeStand = shifted(TycoonConfig.STORAGE_STAND),
        processorIn = shifted(TycoonConfig.SAWMILL_IN),
        processorOut = shifted(TycoonConfig.SAWMILL_OUT),
        playerStand = shifted(TycoonConfig.SAWMILL_STAND),
        workerStand = shifted(TycoonConfig.SAWYER_STAND),
        storePile = shifted(TycoonConfig.PILES.storage),
        inPile = shifted(TycoonConfig.PILES.sawmillIn),
        outPile = shifted(TycoonConfig.PILES.sawmillOut),
        secondOffset = { x = -60, y = 0 },
    },
    copper = {
        storeStand = shifted(TycoonConfig.SCRAP_SHED_STAND),
        processorIn = shifted(TycoonConfig.FORGE_IN),
        processorOut = shifted(TycoonConfig.FORGE_OUT),
        playerStand = shifted(TycoonConfig.WORKSHOP_STAND),
        workerStand = shifted(TycoonConfig.SMELTER_STAND),
        storePile = shifted(TycoonConfig.PILES.shed),
        inPile = shifted(TycoonConfig.PILES.forgeIn),
        outPile = shifted(TycoonConfig.PILES.forgeOut),
        secondOffset = { x = 60, y = 0 },
    },
    -- [D67] Era 3, la fel: Works Store si Wire Works pe locul depozitului si al gaterului, Battery Shed si Power House
    -- pe locul shed-ului si al forjei
    coils = {
        storeStand = shifted(TycoonConfig.STORAGE_STAND, WORKS_DX),
        processorIn = shifted(TycoonConfig.SAWMILL_IN, WORKS_DX),
        processorOut = shifted(TycoonConfig.SAWMILL_OUT, WORKS_DX),
        playerStand = shifted(TycoonConfig.SAWMILL_STAND, WORKS_DX),
        workerStand = shifted(TycoonConfig.SAWYER_STAND, WORKS_DX),
        storePile = shifted(TycoonConfig.PILES.storage, WORKS_DX),
        inPile = shifted(TycoonConfig.PILES.sawmillIn, WORKS_DX),
        outPile = shifted(TycoonConfig.PILES.sawmillOut, WORKS_DX),
        secondOffset = { x = -60, y = 0 },
    },
    power = {
        storeStand = shifted(TycoonConfig.SCRAP_SHED_STAND, WORKS_DX),
        processorIn = shifted(TycoonConfig.FORGE_IN, WORKS_DX),
        processorOut = shifted(TycoonConfig.FORGE_OUT, WORKS_DX),
        playerStand = shifted(TycoonConfig.WORKSHOP_STAND, WORKS_DX),
        workerStand = shifted(TycoonConfig.SMELTER_STAND, WORKS_DX),
        storePile = shifted(TycoonConfig.PILES.shed, WORKS_DX),
        inPile = shifted(TycoonConfig.PILES.forgeIn, WORKS_DX),
        outPile = shifted(TycoonConfig.PILES.forgeOut, WORKS_DX),
        secondOffset = { x = 60, y = 0 },
    },
    -- [D70, pasul j7] BARAJUL (lumea 2, docs/PLAN-HARTA.md §9, aprobata in D74). Coordonatele sunt ale lumii 2: le citesc
    -- doar cei care stiu de lumi (TycoonConfig.linePlacesOf(2)); felinarele si martorul lumii 1 le sar.
    barrels = {
        storeStand = { x = 930, y = 1010 },
        processorIn = { x = 930, y = 1410 },
        processorOut = { x = 1255, y = 1412 },
        playerStand = { x = 1070, y = 1405 },
        workerStand = { x = 1200, y = 1452 },
        storePile = { x = 990, y = 1010 },
        inPile = { x = 990, y = 1380 },
        outPile = { x = 1195, y = 1380 },
        secondOffset = { x = -60, y = 0 },
    },
    cable = {
        storeStand = { x = 1350, y = 1010 },
        processorIn = { x = 1350, y = 1410 },
        processorOut = { x = 1675, y = 1412 },
        playerStand = { x = 1490, y = 1405 },
        workerStand = { x = 1620, y = 1452 },
        storePile = { x = 1410, y = 1010 },
        inPile = { x = 1410, y = 1380 },
        outPile = { x = 1615, y = 1380 },
        secondOffset = { x = -60, y = 0 },
    },
    crystal = {
        storeStand = { x = 2535, y = 1010 },
        processorIn = { x = 2635, y = 1410 },
        processorOut = { x = 3035, y = 1412 },
        playerStand = { x = 2815, y = 1405 },
        workerStand = { x = 2895, y = 1452 },
        storePile = { x = 2595, y = 1010 },
        inPile = { x = 2699, y = 1380 },
        outPile = { x = 2971, y = 1380 },
        secondOffset = { x = 60, y = 0 },
    },
} :: { [string]: LinePlaces }
-- Cladirile fixe ale Morii (ca depozitul si gaterul Erei 1: nu sunt platforme, sunt acolo cand se deschide cartierul)
TycoonConfig.MILL_STORE =
    { x = TycoonConfig.STORAGE.x + MILL_DX, y = TycoonConfig.STORAGE.y, w = 120, h = 96 }
TycoonConfig.FOUNDRY =
    { x = TycoonConfig.SAWMILL.x + MILL_DX, y = TycoonConfig.SAWMILL.y, w = 120, h = 96 }
TycoonConfig.MARKET =
    { x = TycoonConfig.TAVERN.x + MILL_DX, y = TycoonConfig.TAVERN.y, w = 192, h = 144 }
-- [D67] si ale Erei 3
TycoonConfig.WORKS_STORE =
    { x = TycoonConfig.STORAGE.x + WORKS_DX, y = TycoonConfig.STORAGE.y, w = 120, h = 96 }
TycoonConfig.WIRE_WORKS =
    { x = TycoonConfig.SAWMILL.x + WORKS_DX, y = TycoonConfig.SAWMILL.y, w = 120, h = 96 }
TycoonConfig.DEPOT =
    { x = TycoonConfig.TAVERN.x + WORKS_DX, y = TycoonConfig.TAVERN.y, w = 192, h = 144 }
TycoonConfig.SELLER_PLACES = {
    dock = {
        door = TycoonConfig.DOCK,
        stand = TycoonConfig.TRADER_STAND,
        pile = TycoonConfig.PILES.tavern,
        building = TycoonConfig.TAVERN,
        secondOffset = { x = 60, y = 0 },
        customerSpots = TAVERN_CUSTOMER_SPOTS,
        customerEntry = TAVERN_CUSTOMER_ENTRY,
    },
    market = {
        door = shifted(TycoonConfig.DOCK),
        stand = shifted(TycoonConfig.TRADER_STAND),
        pile = shifted(TycoonConfig.PILES.tavern),
        building = TycoonConfig.MARKET,
        secondOffset = { x = 60, y = 0 },
        customerSpots = marketCustomerSpots,
        customerEntry = shifted(TAVERN_CUSTOMER_ENTRY),
    },
    depot = {
        door = shifted(TycoonConfig.DOCK, WORKS_DX),
        stand = shifted(TycoonConfig.TRADER_STAND, WORKS_DX),
        pile = shifted(TycoonConfig.PILES.tavern, WORKS_DX),
        building = TycoonConfig.DEPOT,
        secondOffset = { x = 60, y = 0 },
        customerSpots = depotCustomerSpots,
        customerEntry = shifted(TAVERN_CUSTOMER_ENTRY, WORKS_DX),
    },
    -- [D70, pasul j7] Switch House, orasul barajului (lumea 2): clientii in oglinda tavernei, mutati cu usa ei.
    -- [dupa verificatorul j7] Doua mici abateri de la oglinda: al doilea Dispatcher sta la 48 px de primul (la 60 i-ar fi
    -- iesit stalpul de vest al podului din cap), iar clientii vin de pe iarba de sub piata (y 1240), nu prin taraba
    -- Dispatcher-ului si numele ei, unde ar fi cazut intrarea in oglinda (y 1130).
    town = {
        door = { x = 2059, y = 1130 },
        stand = { x = 2109, y = 1152 },
        pile = { x = 1901, y = 1086 },
        building = TycoonConfig.DAM_SWITCH_HOUSE,
        secondOffset = { x = 48, y = 0 },
        customerSpots = shiftedSpots(2059 - TycoonConfig.DOCK.x),
        customerEntry = { x = 150 + 2059 - TycoonConfig.DOCK.x, y = 1240 },
    },
} :: { [string]: SellerPlaces }
-- [D70] Locurile fiecarei UNIRI (Relay-ul barajului), dupa linia ei. Nu sta in LINE_PLACES: n-are magazie, iar fiecare
-- piesa isi are intrarea si gramada. Felinarele (lampBlocked) le ocolesc pe ale lumii lor. [pasul j7] Relay-ul, casa-pod de la capatul canalului (lumea 2, PLAN-HARTA §9):
-- butoaiele si cablul intra pe stanga, curentul iese pe dreapta, spre podul cu stalpi.
TycoonConfig.JOIN_PLACES = {
    grid = {
        inputIn = { barrels = { x = 1897, y = 1410 }, cable = { x = 2025, y = 1410 } },
        inPiles = { barrels = { x = 1961, y = 1380 }, cable = { x = 2089, y = 1380 } },
        processorOut = { x = 2425, y = 1412 },
        playerStand = { x = 2205, y = 1405 },
        workerStand = { x = 2285, y = 1452 },
        outPile = { x = 2361, y = 1380 },
        secondOffset = { x = 60, y = 0 },
    },
} :: { [string]: JoinPlaces }

-- CARTIERELE: puntea, drumurile si curtile fiecaruia. Primul e The Landing, cu tabelele lui de mai sus (DECK, ROADS,
-- YARDS); al doilea e Moara, aceeasi asezare mutata cu MILL_DX. Strada Morii incepe unde se termina strada satului
-- (x 1860), deci oamenii si dara de ghidaj trec dintr-un cartier in altul pe ea. RoadGraph ia drumurile din toate.
export type District = { id: string, era: number, deck: Rect, roads: { Road }, yards: { Yard } }
local function shiftedRect(r: Rect, dx: number?): Rect
    local d = dx or MILL_DX
    return { x0 = r.x0 + d, x1 = r.x1 + d, y0 = r.y0, y1 = r.y1 }
end
-- Curtile unui cartier nou: cele ale satului, mutate cu `dx`, fiecare cu numele ei (`like` = perechea din sat).
local function districtYards(pairs: { { string } }, dx: number): { Yard }
    local out: { Yard } = {}
    for _, pair in pairs do
        for _, yard in TycoonConfig.YARDS do
            if yard.id == pair[1] then
                local r = shiftedRect(yard, dx)
                table.insert(
                    out,
                    { id = pair[2], like = pair[1], x0 = r.x0, x1 = r.x1, y0 = r.y0, y1 = r.y1 }
                )
            end
        end
    end
    return out
end
local millYards = districtYards({
    { "tavern", "market" },
    { "stall", "merchant" },
    { "storage", "mill_store" },
    { "sawmill", "foundry" },
    { "shed", "ore_shed" },
    { "forge", "furnace" },
    { "bell", "mill_bell" },
    { "house_collector", "house_mill_collector" },
    { "house_porter", "house_mill_porter" },
    { "house_sawyer", "house_founder" },
    { "house_hauler", "house_parts_hauler" },
    { "house_scrap_collector", "house_ore_collector" },
    { "house_scrap_porter", "house_ore_porter" },
    { "house_smelter", "house_coppersmith" },
    { "house_iron_hauler", "house_copper_hauler" },
}, MILL_DX)
-- [D67] si ale Wire Works
local worksYards = districtYards({
    { "tavern", "depot" },
    { "stall", "clerk" },
    { "storage", "works_store" },
    { "sawmill", "wireworks" },
    { "shed", "battery_shed" },
    { "forge", "powerhouse" },
    { "bell", "works_bell" },
    { "house_collector", "house_works_collector" },
    { "house_porter", "house_works_porter" },
    { "house_sawyer", "house_wiredrawer" },
    { "house_hauler", "house_coil_hauler" },
    { "house_scrap_collector", "house_battery_collector" },
    { "house_scrap_porter", "house_battery_porter" },
    { "house_smelter", "house_electrician" },
    { "house_iron_hauler", "house_power_hauler" },
}, WORKS_DX)
-- [D65] Cartierele pe care imaginea coapta URCATA a pamantului (Assets.tycoon.village_ground*) le contine deja. Restul
-- isi primesc puntea, curtile si drumurile din dale, peste imagine (SceneArt). Se schimba DOAR la urcarea unei coaceri
-- noi (scripts/art/village_ground.py, cu acordul owner-ului), nu la coacere.
-- [2026-09-21] Coacerea cu Moara e urcata (ambele felii), deci si cartierul ei vine din imagine.
-- [D67] La fel Wire Works: felia 2, recoapta cu cartierul, e urcata (880 px, pana la capatul lumii).
TycoonConfig.BAKED_DISTRICTS =
    { landing = true, mill = true, works = true } :: { [string]: boolean }

TycoonConfig.DISTRICTS = {
    {
        id = "landing",
        era = 1,
        deck = TycoonConfig.DECK,
        roads = TycoonConfig.ROADS,
        yards = TycoonConfig.YARDS,
    },
    {
        id = "mill",
        era = 2,
        deck = shiftedRect(TycoonConfig.DECK),
        roads = {
            -- strada Morii: de unde se termina strada satului pana la capatul cartierului
            {
                id = "mill_street",
                like = "street",
                x0 = 1860,
                x1 = 1860 + MILL_DX,
                y0 = 1420,
                y1 = 1480,
            },
            {
                id = "market_link",
                like = "tavern_link",
                x0 = 525 + MILL_DX,
                x1 = 575 + MILL_DX,
                y0 = 856,
                y1 = 1420,
            },
            {
                id = "market_plaza",
                like = "plaza",
                x0 = 240 + MILL_DX,
                x1 = 550 + MILL_DX,
                y0 = 1090,
                y1 = 1170,
            },
            {
                id = "copper_lane",
                like = "iron_lane",
                x0 = 1260 + MILL_DX,
                x1 = 1300 + MILL_DX,
                y0 = 856,
                y1 = 1420,
            },
        },
        yards = millYards,
    },
    -- [D67] Wire Works, la fel, mutat cu WORKS_DX; strada lui continua strada Morii
    {
        id = "works",
        era = 3,
        deck = shiftedRect(TycoonConfig.DECK, WORKS_DX),
        roads = {
            {
                id = "works_street",
                like = "street",
                x0 = 1860 + MILL_DX,
                x1 = 1860 + WORKS_DX,
                y0 = 1420,
                y1 = 1480,
            },
            {
                id = "depot_link",
                like = "tavern_link",
                x0 = 525 + WORKS_DX,
                x1 = 575 + WORKS_DX,
                y0 = 856,
                y1 = 1420,
            },
            {
                id = "depot_plaza",
                like = "plaza",
                x0 = 240 + WORKS_DX,
                x1 = 550 + WORKS_DX,
                y0 = 1090,
                y1 = 1170,
            },
            {
                id = "power_lane",
                like = "iron_lane",
                x0 = 1260 + WORKS_DX,
                x1 = 1300 + WORKS_DX,
                y0 = 856,
                y1 = 1420,
            },
        },
        yards = worksYards,
    },
} :: { District }

-- MESERIILE [D49], pe pasii lantului. `pad` = platforma de pe care se angajeaza primul om; id-urile
-- vechi raman (`first_runner` e acum Collector-ul, `dock_trader` Negustorul), fiindca id-ul e si
-- cheia omului in profil si samanta numelui si a infatisarii lui. Al doilea om se cumpara din
-- meniul meseriei; pretul lui vine din simulator (`check_config_prices` il citeste de aici).
-- Fara tabele imbricate in intrari: expresia din simulator se opreste la prima acolada.
TycoonConfig.CREWS = {
    collector = {
        pad = "first_runner",
        name = "Collector",
        plural = "Collectors",
        secondPrice = 1100,
    },
    porter = { pad = "hire_porter", name = "Porter", plural = "Porters", secondPrice = 1600 },
    sawyer = { pad = "hire_sawyer", name = "Sawyer", plural = "Sawyers", secondPrice = 16000 },
    hauler = { pad = "hire_hauler", name = "Hauler", plural = "Haulers", secondPrice = 2500 },
    trader = {
        pad = "dock_trader",
        name = "Innkeeper",
        plural = "Innkeepers",
        secondPrice = 4000,
    },
    -- [D56] LINIA FIERULUI, cu oamenii ei, pe aceiasi pasi ca lemnul
    scrapCollector = {
        pad = "hire_scrap_collector",
        name = "Scrap Collector",
        plural = "Scrap Collectors",
        secondPrice = 10000,
    },
    scrapPorter = {
        pad = "hire_scrap_porter",
        name = "Scrap Porter",
        plural = "Scrap Porters",
        secondPrice = 11000,
    },
    smelter = { pad = "hire_smelter", name = "Smelter", plural = "Smelters", secondPrice = 9000 },
    ironHauler = {
        pad = "hire_iron_hauler",
        name = "Iron Hauler",
        plural = "Iron Haulers",
        secondPrice = 18000,
    },
    -- [D65] ERA 2, in oglinda: cei patru ai pieselor, negustorul Pietei, cei patru ai cuprului
    millCollector = {
        pad = "hire_mill_collector",
        name = "Mill Collector",
        plural = "Mill Collectors",
        secondPrice = 4500000,
    },
    millPorter = {
        pad = "hire_mill_porter",
        name = "Mill Porter",
        plural = "Mill Porters",
        secondPrice = 8000000,
    },
    founder = {
        pad = "hire_founder",
        name = "Founder",
        plural = "Founders",
        secondPrice = 80000000,
    },
    partsHauler = {
        pad = "hire_parts_hauler",
        name = "Parts Hauler",
        plural = "Parts Haulers",
        secondPrice = 12000000,
    },
    merchant = {
        pad = "hire_merchant",
        name = "Merchant",
        plural = "Merchants",
        secondPrice = 20000000,
    },
    oreCollector = {
        pad = "hire_ore_collector",
        name = "Ore Collector",
        plural = "Ore Collectors",
        secondPrice = 55000000,
    },
    orePorter = {
        pad = "hire_ore_porter",
        name = "Ore Porter",
        plural = "Ore Porters",
        secondPrice = 60000000,
    },
    coppersmith = {
        pad = "hire_coppersmith",
        name = "Coppersmith",
        plural = "Coppersmiths",
        secondPrice = 50000000,
    },
    copperHauler = {
        pad = "hire_copper_hauler",
        name = "Copper Hauler",
        plural = "Copper Haulers",
        secondPrice = 90000000,
    },
    -- [D67] ERA 3, in oglinda cu Moara: cei patru ai bobinelor, Clerk-ul Depoului, cei patru ai curentului
    worksCollector = {
        pad = "hire_works_collector",
        name = "Works Collector",
        plural = "Works Collectors",
        secondPrice = 15000000000,
    },
    worksPorter = {
        pad = "hire_works_porter",
        name = "Works Porter",
        plural = "Works Porters",
        secondPrice = 28000000000,
    },
    wiredrawer = {
        pad = "hire_wiredrawer",
        name = "Wiredrawer",
        plural = "Wiredrawers",
        secondPrice = 280000000000,
    },
    coilHauler = {
        pad = "hire_coil_hauler",
        name = "Coil Hauler",
        plural = "Coil Haulers",
        secondPrice = 45000000000,
    },
    clerk = {
        pad = "hire_clerk",
        name = "Clerk",
        plural = "Clerks",
        secondPrice = 55000000000,
    },
    batteryCollector = {
        pad = "hire_battery_collector",
        name = "Battery Collector",
        plural = "Battery Collectors",
        secondPrice = 180000000000,
    },
    batteryPorter = {
        pad = "hire_battery_porter",
        name = "Battery Porter",
        plural = "Battery Porters",
        secondPrice = 200000000000,
    },
    electrician = {
        pad = "hire_electrician",
        name = "Electrician",
        plural = "Electricians",
        secondPrice = 160000000000,
    },
    powerHauler = {
        pad = "hire_power_hauler",
        name = "Power Hauler",
        plural = "Power Haulers",
        secondPrice = 300000000000,
    },
    -- [D70] ERA 4, „The Dam”, ADORMITA (platformele ei au `live = false`): cei cinci veterani ai butoaielor (si
    -- Dispatcher-ul orasului), cei sase ai cablului si ai unirii, cei patru ai cristalului. Al doilea om, din simulator
    -- (`DamRun.prices`), verificat de `check_config_prices`.
    damCollector = {
        pad = "hire_dam_collector",
        name = "Dam Collector",
        plural = "Dam Collectors",
        secondPrice = 50000000000000,
    },
    damPorter = {
        pad = "hire_dam_porter",
        name = "Dam Porter",
        plural = "Dam Porters",
        secondPrice = 70000000000000,
    },
    switchman = {
        pad = "hire_switchman",
        name = "Switchman",
        plural = "Switchmen",
        secondPrice = 800000000000000,
    },
    barrelHauler = {
        pad = "hire_barrel_hauler",
        name = "Barrel Hauler",
        plural = "Barrel Haulers",
        secondPrice = 90000000000000,
    },
    dispatcher = {
        pad = "hire_dispatcher",
        name = "Dispatcher",
        plural = "Dispatchers",
        secondPrice = 900000000000000,
    },
    cableCollector = {
        pad = "hire_cable_collector",
        name = "Cable Collector",
        plural = "Cable Collectors",
        secondPrice = 45000000000000,
    },
    cablePorter = {
        pad = "hire_cable_porter",
        name = "Cable Porter",
        plural = "Cable Porters",
        secondPrice = 55000000000000,
    },
    cablemaker = {
        pad = "hire_cablemaker",
        name = "Cablemaker",
        plural = "Cablemakers",
        secondPrice = 1000000000000000,
    },
    cableHauler = {
        pad = "hire_cable_hauler",
        name = "Cable Hauler",
        plural = "Cable Haulers",
        secondPrice = 80000000000000,
    },
    relayKeeper = {
        pad = "hire_relay_keeper",
        name = "Relay Keeper",
        plural = "Relay Keepers",
        secondPrice = 1100000000000000,
    },
    pylonRunner = {
        pad = "hire_pylon_runner",
        name = "Pylon Runner",
        plural = "Pylon Runners",
        secondPrice = 75000000000000,
    },
    crystalCollector = {
        pad = "hire_crystal_collector",
        name = "Crystal Collector",
        plural = "Crystal Collectors",
        secondPrice = 250000000000000,
    },
    crystalPorter = {
        pad = "hire_crystal_porter",
        name = "Crystal Porter",
        plural = "Crystal Porters",
        secondPrice = 280000000000000,
    },
    crystalsmith = {
        pad = "hire_crystalsmith",
        name = "Crystalsmith",
        plural = "Crystalsmiths",
        secondPrice = 220000000000000,
    },
    ingotHauler = {
        pad = "hire_ingot_hauler",
        name = "Ingot Hauler",
        plural = "Ingot Haulers",
        secondPrice = 500000000000000,
    },
}
-- Unde sta al doilea om al unei meserii statice, fata de primul. Sawyer-ul al doilea: in dreapta
-- primului si putin mai jos, departe de gramada de busteni. Innkeeper-ul al doilea tot in dreapta: in
-- stanga ar fi stat chiar in usa tavernei, unde se lasa marfa si unde asteapta clientii.
-- [D55] Sawyer-ul al doilea, in dreapta primului, sub gramada de scanduri: mai la est ar sta pe locul unde ia
-- Hauler-ul, iar in stanga in fata gramezii de busteni.
-- [D56] Smelter-ul al doilea, in dreapta primului, sub gramada de fier.
-- [D57] Sawyer-ul al doilea, in stanga primului, in fata usii gaterului: in dreapta ar sta pe locul Hauler-ului.
TycoonConfig.SECOND_STAND_OFFSET =
    { sawyer = { x = -60, y = 0 }, trader = { x = 60, y = 0 }, smelter = { x = 60, y = 0 } }
local crewOfPad: { [string]: string } = {}
for role, crew in TycoonConfig.CREWS do
    crewOfPad[crew.pad] = role
end
TycoonConfig.CREW_OF_PAD = crewOfPad

-- [D70, D74] Suma cu care porneste oricine la baraj (lumea 2): din simulator (`DamRun.start_sum`, cea mai mare dintre
-- costul primelor 5 minute ale erei si o noapte la Works Bell), verificata de `check_config_dam`. Monedele cumparate cu
-- Robux trec intregi peste ea (D74, punctul 8).
TycoonConfig.DAM_START_COINS = 35000000000000

-- Platformele, in ordine. Preturile NU se calculeaza aici -- vin exact din simulator (sim_tycoon.py, lacom), care le
-- si verifica la fiecare rulare. Era 1, Era 2 si Era 3 [D67]; erele urmatoare nu exista inca [D64].
TycoonConfig.PADS = {
    -- ---- Era 1 · The Landing ----
    -- Preturile vin din `scripts/economy/sim_tycoon.py` (modelul cu niveluri si gatuire), nu sunt
    -- alese de mana. Cele doua platforme vechi care lipsesc de aici n-au disparut, s-au mutat:
    -- Sorting Crate si Dock Stall au devenit NIVELURI ale debarcaderului, iar Weighted Nets a
    -- devenit pragul de nivel 10 al plaselor (plasa se muta o banda mai in larg).
    -- ORDINEA [D52]: prima plasa, cei cinci oameni la rand (owner-ul: un tur de mana, apoi oamenii),
    -- apoi restul in ordinea cumpararilor din simulator. Indexul nu e salvat in profil (platformele
    -- se tin pe id).
    pad({
        id = "first_net",
        index = 1,
        blurb = "Your first net. Whatever floats into it is yours.",
        name = "First Net",
        era = 1,
        motive = "C",
        price = 0,
        effects = { netEffect(0.33, 1) },
        live = true,
        x = 620,
        y = 812,
        needs = { netsExactly = 0 },
    }),
    pad({
        id = "first_runner", -- id-ul vechi: e cheia omului in profil [D49]
        index = 2,
        blurb = "Someone to empty your nets into the Storage.",
        note = "Your nets get emptied, forever",
        name = "Collector",
        era = 1,
        motive = "A",
        price = 5,
        effects = { hireEffect("collector") },
        live = true,
        -- [D57] Casele oamenilor stau pe un rand, peste strada de curtea liniei lor, fiecare pe pamantul ei (YARDS).
        -- Coliba mare a Collector-ului (144x120) ocupa x 558..702, y 1500..1620.
        x = 630,
        y = 1564,
        -- o singura plasa: banii vin oricum doar din vanzare, deci tot dupa primul tur [D52]
        needs = { netsOwned = 1 },
    }),
    pad({
        id = "hire_porter",
        index = 3,
        blurb = "Someone to carry logs from the Storage to the Sawmill.",
        note = "The storage empties itself",
        name = "Porter",
        era = 1,
        motive = "A",
        price = 6,
        effects = { hireEffect("porter") },
        live = true,
        -- [D57] in randul caselor lemnului, dupa Collector: coliba mare (120x102) ocupa x 730..850
        x = 790,
        y = 1564,
        needs = { after = "first_runner" },
    }),
    pad({
        id = "hire_sawyer",
        index = 4,
        blurb = "Works the saw so you don't have to stand there.",
        note = "The sawmill runs without you",
        name = "Sawyer",
        era = 1,
        motive = "A",
        price = 7,
        effects = { hireEffect("sawyer") },
        live = true,
        -- [D57] in randul caselor lemnului, peste strada de gater; omul insusi sta la panza (SAWYER_STAND)
        x = 950,
        y = 1564,
        needs = { after = "hire_porter" },
    }),
    pad({
        id = "hire_hauler",
        index = 5,
        blurb = "Takes the planks from the Sawmill to the Tavern.",
        note = "Planks reach the Tavern on their own",
        name = "Hauler",
        era = 1,
        motive = "A",
        price = 8,
        effects = { hireEffect("hauler") },
        live = true,
        -- [D57] ultima casa a lemnului, spre curtea fierului: coliba mare (120x102) ocupa x 1050..1170
        x = 1110,
        y = 1564,
        needs = { after = "hire_sawyer" },
    }),
    pad({
        id = "dock_trader",
        index = 6,
        blurb = "Someone to run the Tavern while you walk the bank.",
        note = "The tavern sells without you",
        name = "Innkeeper",
        era = 1,
        motive = "A",
        price = 10,
        effects = { hireEffect("trader") },
        live = true,
        -- LANGA TAVERNA, nu in randul statiilor: un Innkeeper departe de taverna nu se leaga. [D57] Taraba (128x80) sta
        -- pe latura de sud a pietei, cu fata spre taverna: ocupa x 296..424, y 1220..1300.
        x = 360,
        y = 1244,
        -- ultimul din cei cinci: dupa Hauler, nu la trei plase [D52]
        needs = { after = "hire_hauler" },
    }),
    pad({
        id = "second_net",
        index = 7,
        blurb = "A second net. Twice the river, same walk.",
        name = "Second Net",
        era = 1,
        motive = "C",
        price = 28,
        effects = { netEffect(0.33, 1) },
        live = true,
        x = 820,
        y = 812,
        -- abia dupa toti cinci oamenii: plasele vin dupa ei [D52]
        needs = {
            netsExactly = 1,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "dock_trader",
        },
    }),
    pad({
        id = "third_net",
        index = 8,
        blurb = "Three nets working while you walk the bank.",
        name = "Third Net",
        era = 1,
        motive = "C",
        price = 90,
        effects = { netEffect(0.33, 2) },
        live = true,
        x = 1020,
        y = 812,
        needs = { netsExactly = 2, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        id = "bigger_sack",
        index = 9,
        blurb = "Twice the sack, half the walking.",
        note = "Carry more on every trip",
        name = "Bigger Sack",
        era = 1,
        motive = "A",
        price = 80,
        effects = { flagEffect("sackBig") },
        live = true,
        -- [D57] langa roata zilnica, peste strada de piata tavernei
        x = 470,
        y = 1564,
        needs = { netsOwned = 2 },
    }),
    pad({
        id = "far_lane_net",
        index = 10,
        blurb = "A fourth net, further out where the logs run thick.",
        name = "Fourth Net",
        era = 1,
        motive = "C",
        price = 900,
        effects = { netEffect(0.40, 2) },
        live = true,
        x = 1220,
        y = 812,
        needs = { netsExactly = 3, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        -- [D56] FORGE. Id-ul vechi (`workshop`) e cheia din profil. Pana la D56 cladirea era si atelierul de reparat
        -- gasiri (colectia, pusa deoparte) si dadea +6 la colectie; acum topeste doar scrap-ul in fier.
        id = "workshop",
        index = 11,
        blurb = "Scrap goes in, iron comes out. Iron sells for three planks.",
        note = "Smelts scrap into iron",
        name = "Forge",
        era = 1,
        motive = "V",
        price = 5500,
        effects = { flagEffect("forge") },
        live = true,
        -- [D57] jos in curtea fierului, cu fata la strada: cladirea (192x144) ocupa x 1534..1726, y 1236..1380
        x = 1630,
        y = 1324,
        needs = { netsOwned = 4 },
    }),
    pad({
        -- [D56] linia fierului incepe aici: plasa aduce scrap, pe care il duci tu la forja pana ai oameni
        id = "fifth_net",
        index = 12,
        blurb = "The deep channel, where the scrap sinks.",
        note = "Catches scrap",
        name = "Fifth Net",
        era = 1,
        motive = "C",
        price = 7000,
        effects = { netEffect(0.40, 3, "scrap") },
        live = true,
        x = 1420,
        y = 812,
        needs = {
            netsExactly = 4,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "workshop",
        },
    }),
    pad({
        -- [D55] al doilea depozit, doar pentru scrap: Scrap Collector-ul il lasa aici, Scrap Porter-ul il ia de aici.
        -- [D56] Cere plasa a cincea prin `netsOwned`, nu `after`: cartonasul ruinei ar fi scris "Build the Fifth Net".
        id = "scrap_shed",
        index = 13,
        blurb = "A shed for scrap, so it never mixes with the logs.",
        note = "Opens the Scrap Collector's job",
        name = "Scrap Shed",
        era = 1,
        motive = "V",
        price = 700,
        effects = { flagEffect("scrapShed") },
        live = true,
        -- [D57] sus in curtea fierului, sub plasa a cincea: sopronul (120x96) ocupa x 1430..1550, y 914..1010
        x = 1490,
        y = 954,
        needs = { netsOwned = 5 },
    }),
    pad({
        id = "hire_scrap_collector",
        index = 14,
        blurb = "Someone to empty the Fifth Net into the Scrap Shed.",
        note = "Scrap reaches the shed on its own",
        name = "Scrap Collector",
        era = 1,
        motive = "A",
        price = 700,
        effects = { hireEffect("scrapCollector") },
        live = true,
        -- [D57] prima casa a fierului, peste strada de curtea lui: coliba mare (120x102) ocupa x 1240..1360
        x = 1300,
        y = 1564,
        needs = { after = "scrap_shed" },
    }),
    pad({
        id = "hire_scrap_porter",
        index = 15,
        blurb = "Carries scrap from the Scrap Shed to the Forge.",
        note = "The shed empties itself",
        name = "Scrap Porter",
        era = 1,
        motive = "A",
        price = 800,
        effects = { hireEffect("scrapPorter") },
        live = true,
        -- [D57] in randul caselor fierului: coliba mare (120x102) ocupa x 1390..1510
        x = 1450,
        y = 1564,
        needs = { after = "hire_scrap_collector" },
    }),
    pad({
        id = "hire_smelter",
        index = 16,
        blurb = "Works the Forge so you don't have to stand there.",
        note = "The forge runs without you",
        name = "Smelter",
        era = 1,
        motive = "A",
        price = 900,
        effects = { hireEffect("smelter") },
        live = true,
        -- [D57] in randul caselor fierului, peste strada de forja: coliba mare (120x102) ocupa x 1540..1660
        x = 1600,
        y = 1564,
        needs = { after = "hire_scrap_porter" },
    }),
    pad({
        id = "hire_iron_hauler",
        index = 17,
        blurb = "Someone to take the iron from the Forge to the Tavern.",
        note = "Iron reaches the Tavern on its own",
        name = "Iron Hauler",
        era = 1,
        motive = "A",
        price = 1100,
        effects = { hireEffect("ironHauler") },
        live = true,
        -- [D57] ultima casa a fierului, spre poarta Morii: coliba mare (120x102) ocupa x 1690..1810
        x = 1750,
        y = 1564,
        needs = { after = "hire_smelter" },
    }),
    pad({
        id = "landing_bell",
        index = 18,
        blurb = "Ring it and The Landing is finished.",
        note = "+10% forever, opens The Mill",
        name = "Landing Bell",
        era = 1,
        motive = "D",
        price = 8000,
        effects = { mulEffect("bells", 1.10) },
        live = true,
        -- [D57] in coltul de sus, langa gardul Morii pe care il deschide: se vede de pe punte si de pe strada;
        -- cladirea (120x168) ocupa x 1720..1840, y 842..1010
        x = 1780,
        y = 954,
        needs = { all = true },
    }),
    -- ---- Era 2 · The Mill [D64, D65] ----
    -- SCHEMA EREI 1, IN OGLINDA, platforma cu platforma: reperul erei (roata de apa, care porneste turnatoria), prima
    -- plasa a cartierului si turul de mana, cei cinci oameni in rafala, plasele 7-9, apoi "Forja" erei (cuptorul de
    -- cupru), plasa de minereu, magazia lui si cei patru oameni ai cuprului, clopotul. Preturile vin din simulator
    -- (`ERA2_UNLOCKS`, cadrul StationConfig.ERA2_MULT = 40) si sunt verificate de el la fiecare rulare.
    -- Pana pe 2026-09-19 aici stateau 35 de platforme ale erelor 2-4 in forma de dinainte de D46 (roti de energie,
    -- jgheab, razboi de tesut); n-au fost niciodata `live`, deci niciun profil nu le are.
    -- LOCURILE: cartierul e asezat ca The Landing [D57], mutat cu MILL_DX spre aval. `live = false` pana cand serverul
    -- si clientul stiu sa-l joace (docs/PLAN-ERA2.md): pana atunci nici uneltele de dev nu le dau.
    pad({
        id = "water_wheel",
        index = 19,
        blurb = "Built from planks and iron. It wakes the old foundry.",
        note = "Starts the Foundry and the Market",
        name = "Water Wheel",
        era = 2,
        motive = "V",
        price = 7000,
        effects = { flagEffect("wheel") },
        live = true,
        x = MILL_DX + 330,
        y = 812,
        needs = { after = "landing_bell" },
    }),
    pad({
        id = "sixth_net",
        index = 20,
        blurb = "More scrap from the river, this time for the Foundry.",
        note = "Catches scrap for machine parts",
        name = "Sixth Net",
        era = 2,
        motive = "C",
        price = 0,
        effects = { netEffect(0.33, 1, "mill") },
        live = true,
        x = MILL_DX + 620,
        y = 812,
        needs = { netsExactly = 5, after = "water_wheel" },
    }),
    pad({
        id = "hire_mill_collector",
        index = 21,
        blurb = "Someone to empty the Mill's nets into the Mill Store.",
        note = "Scrap reaches the store on its own",
        name = "Mill Collector",
        era = 2,
        motive = "A",
        price = 16000,
        effects = { hireEffect("millCollector") },
        live = true,
        x = MILL_DX + 630,
        y = 1564,
        needs = { netsOwned = 6 },
    }),
    pad({
        id = "hire_mill_porter",
        index = 22,
        blurb = "Carries scrap from the Mill Store to the Foundry.",
        note = "The Foundry is fed on its own",
        name = "Mill Porter",
        era = 2,
        motive = "A",
        price = 20000,
        effects = { hireEffect("millPorter") },
        live = true,
        x = MILL_DX + 790,
        y = 1564,
        needs = { after = "hire_mill_collector" },
    }),
    pad({
        id = "hire_founder",
        index = 23,
        blurb = "Keeps the Foundry casting while you are away from it.",
        note = "Machine parts cast on their own",
        name = "Founder",
        era = 2,
        motive = "A",
        price = 25000,
        effects = { hireEffect("founder") },
        live = true,
        x = MILL_DX + 950,
        y = 1564,
        needs = { after = "hire_mill_porter" },
    }),
    pad({
        id = "hire_parts_hauler",
        index = 24,
        blurb = "Hauls machine parts from the Foundry to the Market.",
        note = "Parts reach the Market on their own",
        name = "Parts Hauler",
        era = 2,
        motive = "A",
        price = 28000,
        effects = { hireEffect("partsHauler") },
        live = true,
        x = MILL_DX + 1110,
        y = 1564,
        needs = { after = "hire_founder" },
    }),
    pad({
        id = "hire_merchant",
        index = 25,
        blurb = "Runs the Market all day, so it never sells slowly.",
        note = "The Market sells at full speed",
        name = "Merchant",
        era = 2,
        motive = "A",
        price = 35000,
        effects = { hireEffect("merchant") },
        live = true,
        x = MILL_DX + 360,
        y = 1244,
        needs = { after = "hire_parts_hauler" },
    }),
    pad({
        id = "seventh_net",
        index = 26,
        blurb = "A second net for the Mill.",
        name = "Seventh Net",
        era = 2,
        motive = "C",
        price = 180000,
        effects = { netEffect(0.33, 1, "mill") },
        live = true,
        x = MILL_DX + 820,
        y = 812,
        needs = {
            netsExactly = 6,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "hire_merchant",
        },
    }),
    pad({
        id = "eighth_net",
        index = 27,
        blurb = "Further out, where the current carries more.",
        name = "Eighth Net",
        era = 2,
        motive = "C",
        price = 900000,
        effects = { netEffect(0.33, 2, "mill") },
        live = true,
        x = MILL_DX + 1020,
        y = 812,
        needs = { netsExactly = 7, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        id = "ninth_net",
        index = 28,
        blurb = "The last of the Mill's scrap nets.",
        name = "Ninth Net",
        era = 2,
        motive = "C",
        price = 7500000,
        effects = { netEffect(0.40, 2, "mill") },
        live = true,
        x = MILL_DX + 1220,
        y = 812,
        needs = { netsExactly = 8, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        id = "copper_furnace",
        index = 29,
        blurb = "The Foundry's fire is finally hot enough for copper.",
        note = "Smelts copper ore into copper",
        name = "Copper Furnace",
        era = 2,
        motive = "V",
        price = 30000000,
        effects = { flagEffect("furnace") },
        live = true,
        x = MILL_DX + 1630,
        y = 1324,
        needs = { netsOwned = 9 },
    }),
    pad({
        id = "tenth_net",
        index = 30,
        blurb = "The deep channel again. This time it brings copper ore.",
        note = "Catches copper ore",
        name = "Tenth Net",
        era = 2,
        motive = "C",
        price = 35000000,
        effects = { netEffect(0.40, 3, "ore") },
        live = true,
        x = MILL_DX + 1420,
        y = 812,
        needs = {
            netsExactly = 9,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "copper_furnace",
        },
    }),
    pad({
        id = "ore_shed",
        index = 31,
        blurb = "A shed for copper ore, so it never mixes with the scrap.",
        note = "Opens the Ore Collector's job",
        name = "Ore Shed",
        era = 2,
        motive = "V",
        price = 2500000,
        effects = { flagEffect("oreShed") },
        live = true,
        x = MILL_DX + 1490,
        y = 954,
        needs = { netsOwned = 10 },
    }),
    pad({
        id = "hire_ore_collector",
        index = 32,
        blurb = "Someone to empty the Tenth Net into the Ore Shed.",
        note = "Ore reaches the shed on its own",
        name = "Ore Collector",
        era = 2,
        motive = "A",
        price = 2500000,
        effects = { hireEffect("oreCollector") },
        live = true,
        x = MILL_DX + 1300,
        y = 1564,
        needs = { after = "ore_shed" },
    }),
    pad({
        id = "hire_ore_porter",
        index = 33,
        blurb = "Carries ore from the Ore Shed to the Copper Furnace.",
        note = "The furnace is fed on its own",
        name = "Ore Porter",
        era = 2,
        motive = "A",
        price = 3000000,
        effects = { hireEffect("orePorter") },
        live = true,
        x = MILL_DX + 1450,
        y = 1564,
        needs = { after = "hire_ore_collector" },
    }),
    pad({
        id = "hire_coppersmith",
        index = 34,
        blurb = "Keeps the Copper Furnace burning when you're away.",
        note = "Copper smelts on its own",
        name = "Coppersmith",
        era = 2,
        motive = "A",
        price = 3500000,
        effects = { hireEffect("coppersmith") },
        live = true,
        x = MILL_DX + 1600,
        y = 1564,
        needs = { after = "hire_ore_porter" },
    }),
    pad({
        id = "hire_copper_hauler",
        index = 35,
        blurb = "Hauls copper from the furnace to the Market.",
        note = "Copper reaches the Market on its own",
        name = "Copper Hauler",
        era = 2,
        motive = "A",
        price = 4000000,
        effects = { hireEffect("copperHauler") },
        live = true,
        x = MILL_DX + 1750,
        y = 1564,
        needs = { after = "hire_coppersmith" },
    }),
    pad({
        id = "mill_bell",
        index = 36,
        blurb = "Ring it and The Mill is finished.",
        -- [D73] ca Landing Bell: Era 3 e in joc, deci clopotul chiar deschide Wire Works (pana la D67 cartonasul tacea, ca
        -- sa nu promita ce nu exista [D40]). Works Bell tace mai departe: Era 4 nu e in joc.
        note = "+10%, opens The Wire Works",
        name = "Mill Bell",
        era = 2,
        motive = "D",
        price = 45000000,
        effects = { mulEffect("bells", 1.10) },
        live = true,
        x = MILL_DX + 1780,
        y = 954,
        needs = { all = true },
    }),
    -- ---- Era 3 · The Wire Works [D67] ----
    -- SCHEMA MORII, IN OGLINDA, platforma cu platforma (docs/PLAN-ERA3.md): masina cu abur (porneste Wire Works), prima
    -- plasa a cartierului, gratis, si turul de mana, cei cinci oameni in rafala, plasele 12-14, apoi Power House, prima
    -- turbina, magazia de baterii si cei patru oameni ai curentului, clopotul. Preturile vin din simulator (`ERA3_UNLOCKS`,
    -- cadrul StationConfig.ERA3_MULT) si sunt verificate de el la fiecare rulare. LOCURILE: cartierul e asezat ca The
    -- Landing [D57], mutat cu WORKS_DX spre aval. `live = false` pana cand serverul si clientul stiu sa-l joace.
    pad({
        id = "steam_engine",
        index = 37,
        blurb = "Built from parts and copper. It runs the Wire Works.",
        note = "Starts the Wire Works and the Depot",
        name = "Steam Engine",
        era = 3,
        motive = "V",
        price = 25000000,
        effects = { flagEffect("steam") },
        live = true,
        x = WORKS_DX + 330,
        y = 812,
        needs = { after = "mill_bell" },
    }),
    pad({
        id = "eleventh_net",
        index = 38,
        blurb = "Copper ore from the river, this time for the Wire Works.",
        note = "Catches copper ore for wire",
        name = "Eleventh Net",
        era = 3,
        motive = "C",
        price = 0,
        effects = { netEffect(0.33, 1, "works") },
        live = true,
        x = WORKS_DX + 620,
        y = 812,
        needs = { netsExactly = 10, after = "steam_engine" },
    }),
    pad({
        id = "hire_works_collector",
        index = 39,
        blurb = "Empties the Works' nets into the Works Store.",
        note = "Ore reaches the store on its own",
        name = "Works Collector",
        era = 3,
        motive = "A",
        price = 55000000,
        effects = { hireEffect("worksCollector") },
        live = true,
        x = WORKS_DX + 630,
        y = 1564,
        needs = { netsOwned = 11 },
    }),
    pad({
        id = "hire_works_porter",
        index = 40,
        blurb = "Carries ore from the Works Store to the Wire Works.",
        note = "The Wire Works is fed on its own",
        name = "Works Porter",
        era = 3,
        motive = "A",
        price = 70000000,
        effects = { hireEffect("worksPorter") },
        live = true,
        x = WORKS_DX + 790,
        y = 1564,
        needs = { after = "hire_works_collector" },
    }),
    pad({
        id = "hire_wiredrawer",
        index = 41,
        blurb = "Keeps the Wire Works drawing when you're away.",
        note = "Coils are drawn on their own",
        name = "Wiredrawer",
        era = 3,
        motive = "A",
        price = 80000000,
        effects = { hireEffect("wiredrawer") },
        live = true,
        x = WORKS_DX + 950,
        y = 1564,
        needs = { after = "hire_works_porter" },
    }),
    pad({
        id = "hire_coil_hauler",
        index = 42,
        blurb = "Hauls coils from the Wire Works to the Depot.",
        note = "Coils reach the Depot on their own",
        name = "Coil Hauler",
        era = 3,
        motive = "A",
        price = 90000000,
        effects = { hireEffect("coilHauler") },
        live = true,
        x = WORKS_DX + 1110,
        y = 1564,
        needs = { after = "hire_wiredrawer" },
    }),
    pad({
        id = "hire_clerk",
        index = 43,
        blurb = "Runs the Depot all day, so it never sells slowly.",
        note = "The Depot sells at full speed",
        name = "Clerk",
        era = 3,
        motive = "A",
        price = 110000000,
        effects = { hireEffect("clerk") },
        live = true,
        x = WORKS_DX + 360,
        y = 1244,
        needs = { after = "hire_coil_hauler" },
    }),
    pad({
        id = "twelfth_net",
        index = 44,
        blurb = "A second net for the Wire Works.",
        name = "Twelfth Net",
        era = 3,
        motive = "C",
        price = 550000000,
        effects = { netEffect(0.33, 1, "works") },
        live = true,
        x = WORKS_DX + 820,
        y = 812,
        needs = {
            netsExactly = 11,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "hire_clerk",
        },
    }),
    pad({
        id = "thirteenth_net",
        index = 45,
        blurb = "Further out, where the current carries more.",
        name = "Thirteenth Net",
        era = 3,
        motive = "C",
        price = 3000000000,
        effects = { netEffect(0.33, 2, "works") },
        live = true,
        x = WORKS_DX + 1020,
        y = 812,
        needs = { netsExactly = 12, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        id = "fourteenth_net",
        index = 46,
        blurb = "The last of the Works' ore nets.",
        name = "Fourteenth Net",
        era = 3,
        motive = "C",
        price = 40000000000,
        effects = { netEffect(0.40, 2, "works") },
        live = true,
        x = WORKS_DX + 1220,
        y = 812,
        needs = { netsExactly = 13, prevNetLevel = TycoonConfig.PREV_NET_LEVEL },
    }),
    pad({
        id = "power_house",
        index = 47,
        blurb = "Where batteries from the turbine become power cells.",
        note = "Turns batteries into power cells",
        name = "Power House",
        era = 3,
        motive = "V",
        price = 100000000000,
        effects = { flagEffect("powerhouse") },
        live = true,
        x = WORKS_DX + 1630,
        y = 1324,
        needs = { netsOwned = 14 },
    }),
    pad({
        id = "first_turbine",
        index = 48,
        blurb = "Coils on a wheel in the deep channel. It fills batteries.",
        note = "Makes electric power",
        name = "First Turbine",
        era = 3,
        motive = "C",
        price = 120000000000,
        effects = { netEffect(0.40, 3, "turbine") },
        live = true,
        x = WORKS_DX + 1420,
        y = 812,
        needs = {
            netsExactly = 14,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "power_house",
        },
    }),
    pad({
        id = "battery_shed",
        index = 49,
        blurb = "A dry shed for full batteries.",
        note = "Opens the Battery Collector's job",
        name = "Battery Shed",
        era = 3,
        motive = "V",
        price = 9000000000,
        effects = { flagEffect("batteryShed") },
        live = true,
        x = WORKS_DX + 1490,
        y = 954,
        needs = { netsOwned = 15 },
    }),
    pad({
        id = "hire_battery_collector",
        index = 50,
        blurb = "Takes full batteries from the turbine to the Battery Shed.",
        note = "Batteries reach the shed on their own",
        name = "Battery Collector",
        era = 3,
        motive = "A",
        price = 9000000000,
        effects = { hireEffect("batteryCollector") },
        live = true,
        x = WORKS_DX + 1300,
        y = 1564,
        needs = { after = "battery_shed" },
    }),
    pad({
        id = "hire_battery_porter",
        index = 51,
        blurb = "Carries batteries from the shed to the Power House.",
        note = "The Power House is fed on its own",
        name = "Battery Porter",
        era = 3,
        motive = "A",
        price = 10000000000,
        effects = { hireEffect("batteryPorter") },
        live = true,
        x = WORKS_DX + 1450,
        y = 1564,
        needs = { after = "hire_battery_collector" },
    }),
    pad({
        id = "hire_electrician",
        index = 52,
        blurb = "Keeps the Power House running when you're away.",
        note = "Power cells are made on their own",
        name = "Electrician",
        era = 3,
        motive = "A",
        price = 12000000000,
        effects = { hireEffect("electrician") },
        live = true,
        x = WORKS_DX + 1600,
        y = 1564,
        needs = { after = "hire_battery_porter" },
    }),
    pad({
        id = "hire_power_hauler",
        index = 53,
        blurb = "Hauls power cells from the Power House to the Depot.",
        note = "Cells reach the Depot on their own",
        name = "Power Hauler",
        era = 3,
        motive = "A",
        price = 13000000000,
        effects = { hireEffect("powerHauler") },
        live = true,
        x = WORKS_DX + 1750,
        y = 1564,
        needs = { after = "hire_electrician" },
    }),
    pad({
        id = "works_bell",
        index = 54,
        blurb = "Ring it and The Wire Works is finished.",
        note = "+10% on every sale, forever",
        name = "Works Bell",
        era = 3,
        motive = "D",
        price = 150000000000,
        effects = { mulEffect("bells", 1.10) },
        live = true,
        x = WORKS_DX + 1780,
        y = 954,
        needs = { all = true },
    }),
    -- ---- Era 4 · The Dam [D70, D74] ----
    -- ADORMITA (`live = false`) pana la comutatorul din pasul l3 (PLAN-MOTOR-UNIRE §16). Barajul o porneste pe a doua
    -- harta: turbina zidita in baraj, Cable Net si casele celor cinci veterani vin gratis cu el (pret 0, le da
    -- `WorldMath.buildDam` la pasul j14), restul se cumpara in ordinea capitolului (`ERA4_UNLOCKS` din simulator, care
    -- verifica preturile, conditiile `after` si rangurile plaselor). Conditiile pe plase se numara pe lista LUMII 2
    -- (turbina si Cable Net incluse), de la pasul j10. Locurile (x/y) vin cu datele lumii 2, la pasul j7.
    pad({
        id = "dam_turbine",
        index = 55,
        blurb = "Built into the dam wall. The river turns it to fill batteries.",
        note = "Comes with the Dam",
        name = "Dam Turbine",
        era = 4,
        motive = "C",
        price = 0,
        effects = { netEffect(0.40, 3, "dam") },
        live = false,
        x = 980,
        y = 812,
        netRank = 5,
        netEra = 4,
    }),
    pad({
        id = "cable_net",
        index = 56,
        blurb = "Copper ore for cable, caught below the dam.",
        note = "Comes with the Dam",
        name = "Cable Net",
        era = 4,
        motive = "C",
        price = 0,
        effects = { netEffect(0.33, 1, "cable_ore") },
        live = false,
        x = 1380,
        y = 812,
        netRank = 1,
        netEra = 4,
    }),
    pad({
        id = "hire_dam_collector",
        index = 57,
        blurb = "Empties the turbine into the Battery Store.",
        note = "A veteran from the old village",
        name = "Dam Collector",
        era = 4,
        motive = "A",
        price = 0,
        effects = { hireEffect("damCollector") },
        live = false,
        x = 760,
        y = 1564,
    }),
    pad({
        id = "hire_dam_porter",
        index = 58,
        blurb = "Carries batteries from the store to the Switchyard.",
        note = "A veteran from the old village",
        name = "Dam Porter",
        era = 4,
        motive = "A",
        price = 0,
        effects = { hireEffect("damPorter") },
        live = false,
        x = 910,
        y = 1564,
    }),
    pad({
        id = "hire_switchman",
        index = 59,
        blurb = "Keeps the Switchyard loading when you're away.",
        note = "A veteran from the old village",
        name = "Switchman",
        era = 4,
        motive = "A",
        price = 0,
        effects = { hireEffect("switchman") },
        live = false,
        x = 1060,
        y = 1564,
    }),
    pad({
        id = "hire_barrel_hauler",
        index = 60,
        blurb = "Hauls barrels from the Switchyard to the Relay Station.",
        note = "A veteran from the old village",
        name = "Barrel Hauler",
        era = 4,
        motive = "A",
        price = 0,
        effects = { hireEffect("barrelHauler") },
        live = false,
        x = 1210,
        y = 1564,
    }),
    pad({
        id = "hire_dispatcher",
        index = 61,
        blurb = "Runs the Switch House, so the town buys at full speed.",
        note = "A veteran from the old village",
        name = "Dispatcher",
        era = 4,
        motive = "A",
        price = 0,
        effects = { hireEffect("dispatcher") },
        live = false,
        x = 1770,
        y = 1030,
    }),
    pad({
        id = "hire_cable_collector",
        index = 62,
        blurb = "Empties the cable nets into the Cable Store.",
        note = "Ore reaches the store on its own",
        name = "Cable Collector",
        era = 4,
        motive = "A",
        price = 180000000000,
        effects = { hireEffect("cableCollector") },
        live = false,
        x = 1370,
        y = 1564,
        needs = { after = "cable_net" },
    }),
    pad({
        id = "hire_cable_porter",
        index = 63,
        blurb = "Carries ore from the Cable Store to the Cable Works.",
        note = "The Cable Works is fed on its own",
        name = "Cable Porter",
        era = 4,
        motive = "A",
        price = 220000000000,
        effects = { hireEffect("cablePorter") },
        live = false,
        x = 1520,
        y = 1564,
        needs = { after = "hire_cable_collector" },
    }),
    pad({
        id = "hire_cablemaker",
        index = 64,
        blurb = "Keeps the Cable Works spinning when you're away.",
        note = "Cable is spun on its own",
        name = "Cablemaker",
        era = 4,
        motive = "A",
        price = 250000000000,
        effects = { hireEffect("cablemaker") },
        live = false,
        x = 1670,
        y = 1564,
        needs = { after = "hire_cable_porter" },
    }),
    pad({
        id = "hire_cable_hauler",
        index = 65,
        blurb = "Hauls cable from the Cable Works to the Relay Station.",
        note = "Cable reaches the Relay on its own",
        name = "Cable Hauler",
        era = 4,
        motive = "A",
        price = 280000000000,
        effects = { hireEffect("cableHauler") },
        live = false,
        x = 1820,
        y = 1564,
        needs = { after = "hire_cablemaker" },
    }),
    pad({
        id = "hire_relay_keeper",
        index = 66,
        blurb = "Joins barrels and cable into power at the Relay Station.",
        note = "Power is joined on its own",
        name = "Relay Keeper",
        era = 4,
        motive = "A",
        price = 300000000000,
        effects = { hireEffect("relayKeeper") },
        live = false,
        x = 2190,
        y = 1564,
        needs = { after = "hire_cable_hauler" },
    }),
    pad({
        id = "hire_pylon_runner",
        index = 67,
        blurb = "Runs power over the pylon bridge to the Switch House.",
        note = "Power reaches the town on its own",
        name = "Pylon Runner",
        era = 4,
        motive = "A",
        price = 350000000000,
        effects = { hireEffect("pylonRunner") },
        live = false,
        x = 2350,
        y = 1564,
        needs = { after = "hire_relay_keeper" },
    }),
    pad({
        id = "second_cable_net",
        index = 68,
        blurb = "A second net for cable ore.",
        name = "Cable Net II",
        era = 4,
        motive = "C",
        price = 1500000000000,
        effects = { netEffect(0.33, 1, "cable_ore") },
        live = false,
        x = 1580,
        y = 812,
        netRank = 2,
        netEra = 4,
        needs = {
            netsExactly = 2,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "hire_pylon_runner",
        },
    }),
    pad({
        id = "third_cable_net",
        index = 69,
        blurb = "The last of the cable nets, further out.",
        name = "Cable Net III",
        era = 4,
        motive = "C",
        price = 16000000000000,
        effects = { netEffect(0.33, 2, "cable_ore") },
        live = false,
        x = 1780,
        y = 812,
        netRank = 3,
        netEra = 4,
        needs = {
            netsExactly = 3,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "second_cable_net",
        },
    }),
    pad({
        id = "crystal_kiln",
        index = 70,
        blurb = "Fires river crystal into ingots for the town.",
        note = "Starts the crystal line",
        name = "Kiln",
        era = 4,
        motive = "V",
        price = 110000000000000,
        effects = { flagEffect("kiln") },
        live = false,
        x = 2835,
        y = 1324,
        needs = { netsOwned = 4, after = "third_cable_net" },
    }),
    pad({
        id = "crystal_net",
        index = 71,
        blurb = "Catches the crystal that drifts down from upstream.",
        note = "Catches crystal",
        name = "Crystal Net",
        era = 4,
        motive = "C",
        price = 130000000000000,
        effects = { netEffect(0.40, 3, "crystal") },
        live = false,
        x = 2625,
        y = 812,
        netRank = 5,
        netEra = 4,
        needs = { after = "crystal_kiln" },
    }),
    pad({
        id = "crystal_shed",
        index = 72,
        blurb = "A dry shed for crystal.",
        note = "Opens the Crystal Collector's job",
        name = "Crystal Shed",
        era = 4,
        motive = "V",
        price = 13000000000000,
        effects = { flagEffect("crystalShed") },
        live = false,
        x = 2695,
        y = 954,
        needs = { netsOwned = 5, after = "crystal_net" },
    }),
    pad({
        id = "hire_crystal_collector",
        index = 73,
        blurb = "Takes crystal from the net to the Crystal Shed.",
        note = "Crystal reaches the shed on its own",
        name = "Crystal Collector",
        era = 4,
        motive = "A",
        price = 13000000000000,
        effects = { hireEffect("crystalCollector") },
        live = false,
        x = 2510,
        y = 1564,
        needs = { after = "crystal_shed" },
    }),
    pad({
        id = "hire_crystal_porter",
        index = 74,
        blurb = "Carries crystal from the Crystal Shed to the Kiln.",
        note = "The Kiln is fed on its own",
        name = "Crystal Porter",
        era = 4,
        motive = "A",
        price = 16000000000000,
        effects = { hireEffect("crystalPorter") },
        live = false,
        x = 2660,
        y = 1564,
        needs = { after = "hire_crystal_collector" },
    }),
    pad({
        id = "hire_crystalsmith",
        index = 75,
        blurb = "Keeps the Kiln firing while you are away from it.",
        note = "Ingots are fired on their own",
        name = "Crystalsmith",
        era = 4,
        motive = "A",
        price = 18000000000000,
        effects = { hireEffect("crystalsmith") },
        live = false,
        x = 2810,
        y = 1564,
        needs = { after = "hire_crystal_porter" },
    }),
    pad({
        id = "hire_ingot_hauler",
        index = 76,
        blurb = "Hauls ingots from the Kiln to the Switch House.",
        note = "Ingots reach the town on their own",
        name = "Ingot Hauler",
        era = 4,
        motive = "A",
        price = 22000000000000,
        effects = { hireEffect("ingotHauler") },
        live = false,
        x = 2960,
        y = 1564,
        needs = { after = "hire_crystalsmith" },
    }),
    pad({
        id = "dam_bell",
        index = 77,
        blurb = "Ring it and The Dam is finished.",
        note = "+10% on every sale, forever",
        name = "Dam Bell",
        era = 4,
        motive = "D",
        price = 600000000000000,
        effects = { mulEffect("bells", 1.10) },
        live = false,
        x = 2985,
        y = 954,
        needs = { all = true, income = 4000000000000 },
    }),
} :: { Pad }

-- Index construit o singura data la incarcare, ca PadService sa nu caute liniar prin 48 de intrari
-- la fiecare cumparare.
local byId: { [string]: Pad } = {}
for _, p in TycoonConfig.PADS do
    byId[p.id] = p
end
TycoonConfig.byId = byId

-- [D65] O era e IN JOC cand platformele ei sunt `live`: de ea tin capitolele de quest-uri, ruinele si uneltele de dev.
local liveEras: { [number]: boolean } = {}
for _, p in TycoonConfig.PADS do
    if p.live then
        liveEras[p.era] = true
    end
end
function TycoonConfig.eraIsLive(era: number): boolean
    return liveEras[era] == true
end

-- [D70, pasul j6] LUMILE (WorldConfig): satul de pe rau (lumea 1, Erele 1-3) si barajul (lumea 2, de la Era 4). Lumea
-- unui lucru vine din era lui. Geometria lumii 2 intra in WORLDS[2] (pasul j7), niciodata in DISTRICTS / ZONES / DECOR,
-- care raman ale lumii 1 (R4: altfel drumurile ei s-ar lega de ale satului, iar pamantul copt s-ar schimba). Fiecare
-- accesoriu primeste lumea; fara ea, lumea 1, deci cine nu stie inca de lumi vede satul de azi, neschimbat.
-- `Box`: x, y, w, h. La `blocked` / `water` (x, y) e coltul din stanga-sus, ca la WorldMap.blockedRects; la cladiri si
-- casute (x, y) e mijlocul bazei, ca STORAGE / TAVERN.
export type Box = { x: number, y: number, w: number, h: number }
export type Pylon = { name: string, x: number, y: number, w: number, h: number, overRoad: boolean }
export type World = {
    districts: { District },
    zones: { Zone },
    decor: { DecorItem },
    spawn: { x: number, y: number },
    lamps: { Lamp }?,
    poles: { WirePole }?,
    -- [D70, pasul j7] doar lumea 2 (lumea 1 le are in RiverConfig si in constantele de mai sus)
    width: number?,
    height: number?,
    blocked: { Box }?, -- unde nu se merge pe uscat: zidul si canalul (raul il pune WorldMap)
    water: { [string]: Box }?, -- lacul, deversorul, canalul (desen)
    wall: Box?,
    buildings: { [string]: Box }?,
    cottages: { Box }?,
    pylons: { Pylon }?,
    cards: { [string]: { x: number, y: number } }?,
}
TycoonConfig.WORLDS = {
    [1] = {
        districts = TycoonConfig.DISTRICTS,
        zones = TycoonConfig.ZONES,
        decor = TycoonConfig.DECOR,
        spawn = TycoonConfig.SPAWN,
    },
} :: { [number]: World }
local function worldOf(w: number?): World?
    return TycoonConfig.WORLDS[WorldConfig.sanitize(w)]
end

local padsByWorld: { [number]: { Pad } } = {}
for _, p in TycoonConfig.PADS do
    local w = WorldConfig.worldOfEra(p.era)
    local list = padsByWorld[w]
    if list == nil then
        list = {}
        padsByWorld[w] = list
    end
    table.insert(list, p)
end
-- Platformele unei lumi, in ordinea tabelului (aceleasi obiecte ca in PADS).
function TycoonConfig.padsOfWorld(w: number?): { Pad }
    return padsByWorld[WorldConfig.sanitize(w)] or {}
end
function TycoonConfig.districtsOf(w: number?): { District }
    local world = worldOf(w)
    return if world ~= nil then world.districts else {}
end
function TycoonConfig.zonesOf(w: number?): { Zone }
    local world = worldOf(w)
    return if world ~= nil then world.zones else {}
end
function TycoonConfig.decorOf(w: number?): { DecorItem }
    local world = worldOf(w)
    return if world ~= nil then world.decor else {}
end
function TycoonConfig.spawnOf(w: number?): { x: number, y: number }
    local world = worldOf(w)
    return if world ~= nil then world.spawn else TycoonConfig.SPAWN
end

-- Lumea fiecarei linii (dupa era ei, din toate erele scrise) si a fiecarui vanzator (dupa liniile pe care le vinde).
local worldOfLine: { [string]: number } = {}
for era, lines in StationConfig.ERA_LINES_ALL do
    for _, line in lines do
        worldOfLine[line] = WorldConfig.worldOfEra(era)
    end
end
local worldOfSeller: { [string]: number } = {}
for line, spec in StationConfig.LINES do
    if spec.seller ~= nil and worldOfLine[line] ~= nil then
        worldOfSeller[spec.seller :: string] = worldOfLine[line]
    end
end
local function placesOfWorld<T>(
    places: { [string]: T },
    worldOfKey: { [string]: number },
    w: number?
): { [string]: T }
    local world = WorldConfig.sanitize(w)
    local out: { [string]: T } = {}
    for key, value in places do
        -- [verificator] o cheie fara linie sau vanzator cunoscut nu e a nimanui (un test cere ca toate sa fie cunoscute)
        if worldOfKey[key] == world then
            out[key] = value
        end
    end
    return out
end
-- Locurile liniilor, ale unirilor si ale vanzatorilor unei lumi (aceleasi obiecte ca in LINE_PLACES / JOIN_PLACES /
-- SELLER_PLACES). Un loc fara linie cunoscuta nu e al niciunei lumi.
function TycoonConfig.linePlacesOf(w: number?): { [string]: LinePlaces }
    return placesOfWorld(TycoonConfig.LINE_PLACES, worldOfLine, w)
end
function TycoonConfig.joinPlacesOf(w: number?): { [string]: JoinPlaces }
    return placesOfWorld(TycoonConfig.JOIN_PLACES, worldOfLine, w)
end
function TycoonConfig.sellerPlacesOf(w: number?): { [string]: SellerPlaces }
    return placesOfWorld(TycoonConfig.SELLER_PLACES, worldOfSeller, w)
end

-- [D73] Puntea fiecarui cartier, pe X, cu era lui (darurile raului se scot de pe puntea oricarui cartier deschis).
function TycoonConfig.deckSpans(w: number?): { { era: number, x0: number, x1: number } }
    local out: { { era: number, x0: number, x1: number } } = {}
    for _, d in TycoonConfig.districtsOf(w) do
        table.insert(out, { era = d.era, x0 = d.deck.x0, x1 = d.deck.x1 })
    end
    return out
end

-- Clopotul unei ere: platforma ei cu motivul D (Landing Bell pentru Era 1); nil pentru o era fara clopot. Zona erei
-- `era + 1` o deschide clopotul asta.
function TycoonConfig.bellOf(era: number): Pad?
    for _, p in TycoonConfig.PADS do
        if p.era == era and p.motive == "D" then
            return p
        end
    end
    return nil
end

-- Numele zonei unei ere ("The Wire Works"), din ZONES; nil pentru o era fara zona.
function TycoonConfig.eraName(era: number): string?
    for _, zone in TycoonConfig.ZONES do
        if zone.era == era then
            return zone.name
        end
    end
    return nil
end

-- [2026-09-30] FINALUL CE E IN JOC. Era care urmeaza si nu e inca in joc (numele zonei ei: "The Dam"), sau nil cand toate
-- erele cu zona sunt in joc. Finalul erei de acum spune ce vine (bannerul de dupa clopot, capitolul, lista de quest-uri,
-- masa cu planurile), nu tace.
function TycoonConfig.comingEra(w: number?): { era: number, name: string }?
    for _, zone in TycoonConfig.zonesOf(w) do
        if not TycoonConfig.eraIsLive(zone.era) then
            return { era = zone.era, name = zone.name }
        end
    end
    return nil
end

-- [D65] CASELE OAMENILOR SI NUMELE DE SUB ELE, ca locuri pe care decorul imprastiat (copaci, tufe) n-are voie sa le
-- acopere (WorldDecor.village). Casa mare are 120 x 102 cu baza la TycoonConfig.buildingBase, patratelele treptei stau
-- la 10 + 6 px deasupra acoperisului, numele imediat sub ea [D58], pana la baza + 20. [2026-09-29] Dreptunghiul era
-- socotit cu baza la pad.y + 8: numele si partea de jos a casei ramaneau afara din el.
-- Doar cartierele de DUPA The Landing: satul vechi a fost asezat si vazut cu decorul lui (niciun nume acoperit), iar
-- dreptunghiul unui brad e mai lat decat varful lui -- regula ar fi scos de acolo un brad pe care jucatorii il stiu.
export type HomeClear = { x0: number, x1: number, y0: number, y1: number, frontOf: number }
function TycoonConfig.homeClearRects(w: number?): { HomeClear }
    local out = {}
    for _, p in TycoonConfig.padsOfWorld(w) do
        if p.live and p.era > 1 and crewOfPad[p.id] ~= nil and p.x ~= nil and p.y ~= nil then
            local x, y = p.x :: number, p.y :: number
            local base = TycoonConfig.buildingBase(p)
            table.insert(
                out,
                { x0 = x - 80, x1 = x + 80, y0 = base - 130, y1 = base + 20, frontOf = y }
            )
        end
    end
    return out
end

-- [D67] FELINARELE DE PE STRADA: pe marginea de sud a strazii fiecarui cartier, in golul dintre doua case vecine (casa
-- mare are 120 px, casele stau la 150-190 px una de alta, felinarul are 36). Se aprind cu primul curent vandut. Doar
-- cartierele in joc; si doar cand Era 3 e in joc (felinarele sunt ale ei, nu ale satului de dinainte de curent).
TycoonConfig.LAMP_BASE_Y = 1492 -- baza felinarului: chiar sub strada (y 1420..1480), deasupra casei (baza la 1564)
export type Lamp = { x: number, y: number, era: number }
-- [D67, audit] Un felinar nu sta unde lucreaza cineva: Smelter-ul, Coppersmith-ul si Electrician-ul stau pe strada in
-- fata atelierului lor, al doilea om de la gater / Foundry / Wire Works langa primul, iar Porter-ul isi rastoarna roaba
-- la gura atelierului (processorIn, cu fata la dreapta) si Hauler-ul o incarca la iesire (processorOut, spre stanga).
-- Acolo capul felinarului le-ar taia fata sau roaba oricum le-ai aseza in adancime, deci golul acela ramane fara
-- felinar. Cutiile: capul felinarului x+-15, y 1372..1414; stalpul x+-6 pana la baza; omul 40x60, prins de talpi, cu
-- roaba de 60x50 in fata lui (PersonView: celula 13, x2.5).
-- [D70, dupa verificator] O SINGURA REGULA, publica: o citeste si testul de asezare al lumii 2.
function TycoonConfig.lampBlocked(x: number, w: number?): boolean
    local function hits(bx0: number, by0: number, bx1: number, by1: number): boolean
        local head = x - 15 < bx1 and bx0 < x + 15 and 1372 < by1 and by0 < 1414
        local post = x - 6 < bx1 and bx0 < x + 6 and 1414 < by1 and by0 < TycoonConfig.LAMP_BASE_Y
        return head or post
    end
    -- [D70, pasul j6] doar locurile lumii felinarului: oamenii altei harti nu stau pe strada asta
    for _, union in TycoonConfig.joinPlacesOf(w) do
        local stand = union.workerStand
        for _, spot in
            { stand, { x = stand.x + union.secondOffset.x, y = stand.y + union.secondOffset.y } }
        do
            if hits(spot.x - 20, spot.y - 60, spot.x + 20, spot.y) then
                return true
            end
        end
        -- roabele: cine aduce o piesa o rastoarna la intrarea ei, Pylon Runner-ul incarca la iesire
        for _, pin in union.inputIn do
            if hits(pin.x - 20, pin.y - 60, pin.x + 73, pin.y) then
                return true
            end
        end
        local pout = union.processorOut
        if hits(pout.x - 73, pout.y - 60, pout.x + 20, pout.y) then
            return true
        end
    end
    for _, place in TycoonConfig.linePlacesOf(w) do
        local stand = place.workerStand
        for _, spot in
            { stand, { x = stand.x + place.secondOffset.x, y = stand.y + place.secondOffset.y } }
        do
            if hits(spot.x - 20, spot.y - 60, spot.x + 20, spot.y) then
                return true
            end
        end
        local pin, pout = place.processorIn, place.processorOut
        if
            hits(pin.x - 20, pin.y - 60, pin.x + 73, pin.y)
            or hits(pout.x - 73, pout.y - 60, pout.x + 20, pout.y)
        then
            return true
        end
    end
    return false
end
function TycoonConfig.streetLamps(w: number?): { Lamp }
    local world = WorldConfig.sanitize(w)
    if world ~= 1 then
        -- [D70] felinarele lumii 2 sunt scrise de mana in WORLDS[2] (pasul j7), trecute prin aceeasi regula: niciunul peste
        -- un om care lucreaza pe loc sau peste roaba lui
        local other = worldOf(world)
        local kept: { Lamp } = {}
        for _, lamp in if other ~= nil and other.lamps ~= nil then other.lamps else {} do
            if not TycoonConfig.lampBlocked(lamp.x, world) then
                table.insert(kept, lamp)
            end
        end
        return kept
    end
    local out: { Lamp } = {}
    if not TycoonConfig.eraIsLive(3) then
        return out
    end
    for _, district in TycoonConfig.districtsOf(world) do
        if not TycoonConfig.eraIsLive(district.era) then
            continue
        end
        local xs: { number } = {}
        for _, p in TycoonConfig.padsOfWorld(world) do
            if p.era == district.era and crewOfPad[p.id] ~= nil and p.y == 1564 and p.x ~= nil then
                table.insert(xs, p.x :: number)
            end
        end
        table.sort(xs)
        for i = 1, #xs - 1 do
            local x = (xs[i] + xs[i + 1]) / 2
            if not TycoonConfig.lampBlocked(x, world) then
                table.insert(out, { x = x, y = TycoonConfig.LAMP_BASE_Y, era = district.era })
            end
        end
    end
    return out
end

-- Numele cartierului unei ere ("The Wire Works"), din ZONES: singura lista de nume de era. [D67, audit] Balciul avea
-- doua liste proprii ramase din planul vechi ("The Yard", "The Harbor") si scria "Era 3: The Yard" pe cardul cuiva
-- ajuns la Wire Works [D40]. O era necunoscuta ia numele ultimei scrise, ca nimeni sa nu ramana fara nume.
function TycoonConfig.zoneName(era: number): string
    local best = TycoonConfig.ZONES[1]
    for _, zone in TycoonConfig.ZONES do
        if zone.era <= era and zone.era >= best.era then
            best = zone
        end
    end
    return best.name
end

-- [D67] Cheia din Strings.BUILDING_WORDS pentru randul unei statii: serverul trimite `kind = "net"` si pentru turbina
-- (se urca, se rutează si se socoteste ca o plasa), dar ea nu prinde, umple baterii. Fara asta meniul si bannerul de
-- prag ar scrie "Catches twice as much now" pe turbina [D40].
-- [D70, verificator] TURBINELE: First Turbine (Era 3, `good = "turbine"`) si turbina zidita in baraj (`good = "dam"`). O
-- singura intrebare, citita de cuvinte, verb, desen si plasa din rau, ca turbina barajului sa nu fie luata drept plasa.
TycoonConfig.TURBINE_GOODS = { turbine = true, dam = true } :: { [string]: boolean }
function TycoonConfig.isTurbine(p: Pad): boolean
    for _, effect in p.effects do
        if
            effect.kind == "net"
            and effect.good ~= nil
            and TycoonConfig.TURBINE_GOODS[effect.good :: string]
        then
            return true
        end
    end
    return false
end

function TycoonConfig.wordsKindOf(kind: string, id: string?): string
    local station = if kind == "net" and id ~= nil then TycoonConfig.byId[id] else nil
    if station ~= nil and TycoonConfig.isTurbine(station) then
        return "turbine"
    end
    return kind
end

-- [D70] STALPII CU SARMA ("Wire comes to every street", treapta 1 a modernizarii din Era 3). Stau pe marginea de NORD a
-- strazii, in golurile unde nu se lucreaza: pe acolo sunt curtile gaterului si ale forjei, cu grameziile, roabele si
-- oamenii lor, deci tiparul unui cartier are doar patru locuri libere (masurate, testul TycoonConfig le tine). Strada e
-- una singura prin toate cartierele (240..5220), deci stalpii se leaga la inceputul fiecarui cartier nou, iar stalpul de
-- capat (cu transformator si ancora) sta doar la vest, unde incepe strada. Sarma cea mai lunga trece peste curtea
-- forjei. Numai cu Era 3 in joc, ca felinarele: sarma e a ei.
-- Ancora stalpului de capat coboara 60 px spre margine. La vest singurul loc liber e intre bradul de la capatul strazii
-- si taraba Innkeeper-ului: ancora se prinde in pamant in fata bradului, care sta cu 18 px mai in spate (testul o
-- stie). La est linia se opreste la ultimul stalp al cartierului, in fata curtii Power House: de acolo pana la gard
-- (x 5240) curtea e plina (gramezile, inelul, oamenii, caruciorul Power Hauler-ului), iar gardul Erei 4 e desenat
-- peste tot ce sta la 42 px de el (ZoneController, Z 201), deci si peste traversa unui stalp pus acolo.
TycoonConfig.WIRE_POLE_BASE_Y = 1418
TycoonConfig.WIRE_POLE_XS = { 480, 760, 1234, 1400 } -- in cartierul satului; celelalte, mutate cu MILL_DX
export type WirePole = { x: number, y: number, kind: string, mirror: boolean }
function TycoonConfig.wirePoles(w: number?): { WirePole }
    local world = WorldConfig.sanitize(w)
    if world ~= 1 then
        -- [D70] stalpii lumii 2 sunt scrisi de mana in WORLDS[2] (pasul j7); acestia sunt ai modernizarii Erei 3
        local other = worldOf(world)
        return if other ~= nil and other.poles ~= nil then other.poles else {}
    end
    local out: { WirePole } = {}
    if not TycoonConfig.eraIsLive(3) then
        return out
    end
    local y = TycoonConfig.WIRE_POLE_BASE_Y
    local live = 0
    for _, district in TycoonConfig.districtsOf(world) do
        if TycoonConfig.eraIsLive(district.era) then
            live += 1
        end
    end
    table.insert(out, { x = 272, y = y, kind = "end", mirror = false })
    for k = 1, live do
        local dx = (k - 1) * MILL_DX
        if k > 1 then
            table.insert(
                out,
                { x = 1860 + (k - 2) * MILL_DX, y = y, kind = "line", mirror = false }
            )
        end
        for _, x in TycoonConfig.WIRE_POLE_XS do
            table.insert(out, { x = x + dx, y = y, kind = "line", mirror = false })
        end
    end
    return out
end

-- [D70] Recuzita modernizarii, pe harta (x, baza y): masa cu planurile barajului la capatul Wire Works (treapta 4),
-- tarusii topografilor pe linia viitorului zid, intre punte si curtea depozitului (treapta 4), si curtea goala din
-- mijlocul Wire Works: tamburii de cablu (treapta 1) si statia de transformare (treapta 4). Toate in spatele firelor,
-- cu baza deasupra lor (testul recuzitei): o recuzita prin care trece sarma pare agatata de ea.
-- `era`: a cui sunt planurile (barajul, Era 4): cardul mesei tace cand era aceea intra in joc
TycoonConfig.DAM_PLANS = { x = 5150, y = 1200, era = 4 }
TycoonConfig.SURVEY_STAKES = {
    { x = 620, y = 905, frame = 2 },
    { x = 690, y = 905, frame = 0 },
    { x = 760, y = 905, frame = 1 },
    { x = 830, y = 905, frame = 0 },
} :: { { x: number, y: number, frame: number } }
-- [D70] "Look (V)": unde se uita camera cand vine o treapta a modernizarii (sau se aprind felinarele), in satul vechi
-- (Landing), unde se vede schimbarea. `x, y` pe un ecran lat (1600 x 900 de lume: intra tot ce s-a schimbat); `narrow` pe
-- unul ingust (telefonul, ~990 x 460), unde nu intra tot: acolo, lucrul din anunt. Testul privirii le masoara pe amandoua.
TycoonConfig.LOOK_NARROW_W = 1300 -- sub atata lume pe latime, ecranul e ingust
export type LookPoint = { x: number, y: number, narrow: { x: number, y: number }? }
TycoonConfig.MODERN_LOOK_AT = {
    { x = 1060, y = 1340 }, -- 1, sarma: stalpii de pe strada satului
    { x = 1060, y = 1340 }, -- 2, carucioarele: oamenii pe strada si pe alei
    -- 3, tabla si caramida: depozitul, gaterul, taverna, Scrap Shed, forja; pe telefon, gaterul si forja intregi, cu
    -- strada sub ele (toate trei nu incap: de la acoperisul magaziei la talpa gaterului sunt 466 px)
    { x = 1060, y = 1180, narrow = { x = 1330, y = 1310 } },
    -- 4, geamurile: casele meseriilor (si tarusii de langa punte); pe telefon, casele din mijloc, deasupra joystick-ului si
    -- a butonului E (toate sapte nu incap: se intind pe ~1080 px)
    { x = 1100, y = 1300, narrow = { x = 1270, y = 1560 } },
    -- 5, luminile: cladirile cu firmele, casele, felinarele strazii; pe telefon, casele si strada
    { x = 1100, y = 1300, narrow = { x = 1270, y = 1540 } },
} :: { LookPoint }

-- Punctul privirii pentru o treapta, pe un ecran cu `visibleW` px de lume pe latime (nil = treapta n-are privire).
function TycoonConfig.modernLookAt(stage: number, visibleW: number): { x: number, y: number }?
    local at = TycoonConfig.MODERN_LOOK_AT[stage]
    if at == nil then
        return nil
    end
    local narrow = at.narrow
    if narrow ~= nil and visibleW < TycoonConfig.LOOK_NARROW_W then
        return narrow
    end
    return { x = at.x, y = at.y }
end
TycoonConfig.FIELD_PROPS = {
    { sprite = "cable_drums", x = 4020, y = 1250, stage = 1 },
    { sprite = "cable_drums", x = 4490, y = 1150, stage = 1 },
    { sprite = "substation", x = 4240, y = 1215, stage = 4 },
} :: { { sprite: string, x: number, y: number, stage: number } }

-- Linia de jos a cladirii de pe o platforma (y in lume): marginea de jos a cadrului, plus BUILDING_DROP. Fara
-- PadArt.ART_OFFSET: roata de apa, care sta in rau, isi muta singura desenul.
function TycoonConfig.buildingBase(p: Pad): number
    return (p.y :: number) + TycoonConfig.PAD_SIZE / 2 + TycoonConfig.BUILDING_DROP
end

-- [D63] VERBUL unei platforme, acelasi pe butonul cartonasului si in textul quest-ului ei: o plasa se arunca ("cast"),
-- un om se angajeaza ("hire"), traista se ia ("get"), clopotul se trage ("ring"), restul se construiesc ("build").
-- Un test tine verbul legat de textele din QuestConfig.
function TycoonConfig.verbOf(p: Pad): string
    for _, effect in p.effects do
        if effect.kind == "net" then
            -- [D67] turbina sta in rau ca o plasa, dar nu se arunca: se construieste
            return if TycoonConfig.isTurbine(p) then "build" else "cast"
        end
    end
    if crewOfPad[p.id] ~= nil then
        return "hire"
    elseif p.id == "bigger_sack" then
        return "get"
    elseif p.motive == "D" then
        return "ring" -- clopotele de sfarsit de era
    end
    return "build"
end

-- [D70, pasul j7] LUMEA 2, BARAJUL (docs/PLAN-HARTA.md §9, aprobata in D74; planseta: scripts/art/preview_dam_layout.py).
-- 3.385 px: lacul si Dam Town la vest (pontonul, barca, roata, avizierul si comorile raman pe coordonatele satului),
-- zidul la x 640-880, cartierul barajului la x 880-3065, ceata Erei 5 dupa el. Doua cartiere, fiecare cu puntea lui:
-- puntea lacului (x 240-640) si puntea barajului (x 880-2760); strada le leaga. Nimic de aici nu e citit de lumea 1:
-- ajunge la joc doar prin accesoriile cu lumea 2 (districtsOf(2), zonesOf(2), ...).
-- Curtile au id-uri cu `_yard` / `house_`: simulatorul cauta pretul unei platforme dupa primul `id = "..."` din fisier.
TycoonConfig.WORLDS[2] = {
    width = 3385,
    height = 1920,
    districts = {
        {
            id = "dam_town",
            era = 4,
            deck = { x0 = 240, x1 = 640, y0 = 772, y1 = 856 },
            roads = {
                { id = "town_lane", x0 = 525, x1 = 575, y0 = 856, y1 = 1420, like = "tavern_link" },
                { id = "town_plaza", x0 = 240, x1 = 550, y0 = 1090, y1 = 1170, like = "plaza" },
            },
            yards = {
                { id = "canteen_yard", x0 = 222, x1 = 584, y0 = 1040, y1 = 1196, like = "tavern" },
                { id = "memory_wall_yard", x0 = 650, x1 = 870, y0 = 1326, y1 = 1356 },
                {
                    id = "cottage_1_yard",
                    x0 = 218,
                    x1 = 362,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "cottage_2_yard",
                    x0 = 358,
                    x1 = 502,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "cottage_3_yard",
                    x0 = 498,
                    x1 = 642,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
            },
        },
        {
            id = "dam",
            era = 4,
            deck = { x0 = 880, x1 = 2760, y0 = 772, y1 = 856 },
            roads = {
                { id = "dam_street", x0 = 240, x1 = 3065, y0 = 1420, y1 = 1480, like = "street" },
                { id = "dam_lane", x0 = 880, x1 = 920, y0 = 856, y1 = 1420, like = "iron_lane" },
                {
                    id = "cable_lane",
                    x0 = 1300,
                    x1 = 1340,
                    y0 = 856,
                    y1 = 1420,
                    like = "iron_lane",
                },
                {
                    id = "pylon_lane",
                    x0 = 2465,
                    x1 = 2505,
                    y0 = 856,
                    y1 = 1420,
                    like = "iron_lane",
                },
                {
                    id = "switch_square",
                    x0 = 1879,
                    x1 = 2485,
                    y0 = 1090,
                    y1 = 1170,
                    like = "plaza",
                },
            },
            yards = {
                {
                    id = "dam_store_yard",
                    x0 = 922,
                    x1 = 1166,
                    y0 = 968,
                    y1 = 1040,
                    like = "storage",
                },
                {
                    id = "switchyard_yard",
                    x0 = 922,
                    x1 = 1275,
                    y0 = 1326,
                    y1 = 1418,
                    like = "sawmill",
                },
                {
                    id = "cable_store_yard",
                    x0 = 1342,
                    x1 = 1586,
                    y0 = 968,
                    y1 = 1040,
                    like = "shed",
                },
                {
                    id = "cableworks_yard",
                    x0 = 1342,
                    x1 = 1695,
                    y0 = 1326,
                    y1 = 1418,
                    like = "forge",
                },
                {
                    id = "dispatcher_yard",
                    x0 = 1690,
                    x1 = 1850,
                    y0 = 1034,
                    y1 = 1104,
                    like = "stall",
                },
                {
                    id = "switch_house_yard",
                    x0 = 1861,
                    x1 = 2185,
                    y0 = 1040,
                    y1 = 1196,
                    like = "tavern",
                },
                { id = "relay_yard", x0 = 1877, x1 = 2445, y0 = 1318, y1 = 1418, like = "forge" },
                { id = "pylon_yard", x0 = 2300, x1 = 2420, y0 = 1040, y1 = 1084 },
                {
                    id = "crystal_shed_yard",
                    x0 = 2515,
                    x1 = 2765,
                    y0 = 968,
                    y1 = 1040,
                    like = "shed",
                },
                { id = "kiln_yard", x0 = 2619, x1 = 3061, y0 = 1318, y1 = 1418, like = "forge" },
                { id = "dam_bell_yard", x0 = 2917, x1 = 3053, y0 = 984, y1 = 1036, like = "bell" },
                {
                    id = "house_dam_collector",
                    x0 = 688,
                    x1 = 832,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_dam_porter",
                    x0 = 838,
                    x1 = 982,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_switchman",
                    x0 = 988,
                    x1 = 1132,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_barrel_hauler",
                    x0 = 1138,
                    x1 = 1282,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_cable_collector",
                    x0 = 1298,
                    x1 = 1442,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_cable_porter",
                    x0 = 1448,
                    x1 = 1592,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_cablemaker",
                    x0 = 1598,
                    x1 = 1742,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_cable_hauler",
                    x0 = 1748,
                    x1 = 1892,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_relay_keeper",
                    x0 = 2118,
                    x1 = 2262,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_pylon_runner",
                    x0 = 2278,
                    x1 = 2422,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_crystal_collector",
                    x0 = 2438,
                    x1 = 2582,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_crystal_porter",
                    x0 = 2588,
                    x1 = 2732,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_crystalsmith",
                    x0 = 2738,
                    x1 = 2882,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
                {
                    id = "house_ingot_hauler",
                    x0 = 2888,
                    x1 = 3032,
                    y0 = 1594,
                    y1 = 1638,
                    like = "house_collector",
                },
            },
        },
    },
    zones = {
        { id = "dam_town", name = "The Dam", era = 4, x0 = 200, x1 = 3065, fence = false },
        -- ceata Erei 5: text neutru, fara numele erei (O1, PLAN-MOTOR-UNIRE §16). [dupa verificatorul j7] Fara gard: gardul
        -- (~42 px spre vest de x0) ar fi acoperit marginea Dam Bell si pe Ingot Hauler la iesirea Kiln-ului.
        {
            id = "fog5",
            name = "The river beyond",
            era = 5,
            x0 = 3065,
            x1 = 3385,
            soon = "More river lies beyond the dam",
            fence = false,
        },
    },
    decor = {},
    spawn = { x = 800, y = 1180 },
    blocked = {
        { x = 640, y = 768, w = 240, h = 192 }, -- zidul barajului, pe uscat (in rau il blocheaza raul)
        { x = 2193, y = 856, w = 64, h = 234 }, -- canalul de sub Relay, intre punte si piata Switch House
        { x = 2193, y = 1170, w = 64, h = 66 }, -- si de sub piata pana la stavila
    },
    water = {
        lake = { x = 0, y = 480, w = 640, h = 288 },
        spillway = { x = 690, y = 480, w = 140, h = 288 },
        canal = { x = 2193, y = 768, w = 64, h = 468 }, -- apa deschisa 768..1236; sub Relay intra in stavila
    },
    wall = { x = 640, y = 392, w = 240, h = 568 },
    buildings = {
        damStore = { x = 1090, y = 1010, w = 120, h = 96 }, -- Battery Store (D74, punctul 7)
        switchyard = { x = 1090, y = 1380, w = 120, h = 96 },
        cableStore = { x = 1510, y = 1010, w = 120, h = 96 },
        cableworks = { x = 1510, y = 1380, w = 120, h = 96 },
        relay = { x = 2225, y = 1380, w = 192, h = 144 },
        switchHouse = TycoonConfig.DAM_SWITCH_HOUSE,
        canteen = { x = 400, y = 1080, w = 192, h = 144 },
        bellTower = { x = 760, y = 960, w = 96, h = 240 },
        memoryWall = { x = 760, y = 1340, w = 192, h = 96 },
    },
    cottages = {
        { x = 290, y = 1620, w = 120, h = 102 },
        { x = 430, y = 1620, w = 120, h = 102 },
        { x = 570, y = 1620, w = 120, h = 102 },
    },
    -- felinarele strazii: regula streetLamps (intre case vecine), ocolind oamenii Relay-ului
    lamps = {
        { x = 835, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
        { x = 1290, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
        { x = 1445, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
        { x = 1745, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
        { x = 2585, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
        { x = 2735, y = TycoonConfig.LAMP_BASE_Y, era = 4 },
    },
    pylons = {
        { name = "river_pylon", x = 2360, y = 1070, w = 48, h = 200, overRoad = false },
        { name = "lane_pylon", x = 2450, y = 1300, w = 24, h = 120, overRoad = false },
        { name = "bridge_pylon_w", x = 2190, y = 1100, w = 16, h = 70, overRoad = true },
        { name = "bridge_pylon_e", x = 2262, y = 1100, w = 16, h = 70, overRoad = true },
    },
    cards = { bellTower = { x = 760, y = 990 }, memoryWall = { x = 760, y = 1370 } },
}

return TycoonConfig
