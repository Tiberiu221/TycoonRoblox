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
}

export type Good = { id: string, value: number }
-- [D55] O parte din ce prinde un fel de plasa: bunul si ponderea lui.
export type CatchPart = { id: string, share: number }

local TycoonConfig = {}

-- Nivelul pe care trebuie sa-l atinga plasa dinainte ca sa apara urmatoarea. Aceeasi cifra e in
-- simulator (`PREV_NET_LEVEL`) si in quest-ul `net_two`; testul QuestConfig le tine impreuna, ca
-- banda de obiectiv si lumea sa nu se mai poata contrazice.
TycoonConfig.PREV_NET_LEVEL = 2

-- ---- efecte, in oglinda cu net()/mul()/on()/plus()/build()/upgrade()/refine() din simulator ----
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
local function addEffect(field: string, amount: number): Effect
    return { kind = "add", field = field, amount = amount }
end
local function buildEffect(good: string, mult: number, cap: number, draw: number): Effect
    return { kind = "build", good = good, mult = mult, cap = cap, draw = draw }
end
local function upgradeEffect(good: string, factor: number): Effect
    return { kind = "upgrade", good = good, factor = factor }
end
local function refineEffect(good: string, factor: number): Effect
    return { kind = "refine", good = good, factor = factor }
end
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
} :: { Good }

-- [D55] CE PRINDE O PLASA, dupa felul ei. In ordinea simulatorului (`CATCH` din sim_tycoon.py): ordinea sumei
-- valorii medii conteaza pentru paritatea la bit. Plasele 1-4 prind lemn; ultima, cea din larg, scrap
-- [owner, 2026-09-13: "scraps ar trebui sa poti prinde doar la ultimul net"].
TycoonConfig.CATCH = {
    wood = { { id = "driftwood", share = 0.95 }, { id = "named", share = 0.05 } },
    scrap = { { id = "scrap", share = 0.95 }, { id = "named", share = 0.05 } },
} :: { [string]: { CatchPart } }

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
export type Road = { id: string, x0: number, x1: number, y0: number, y1: number }

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
export type Yard = { id: string, x0: number, x1: number, y0: number, y1: number }
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
    -- felinarele strazii, pe marginea ei de sud
    { sprite = "lantern", x = 232, y = 1506, scale = 2 },
    { sprite = "lantern", x = 1215, y = 1506, scale = 2 },
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
}

-- [B5] Toate pozitiile de platforme, plase, debarcader si zone sunt LOCALE terenului. Lumea =
-- PLOT_ORIGIN + local. Azi originea e (0, 0), deci local = lume; conventia exista ca mai multe
-- terenuri pe acelasi server sa fie posibile mai tarziu (aria R) fara sa rescriem pozitiile.
TycoonConfig.PLOT_ORIGIN = { x = 0, y = 0 }

-- Cartierele terenului, de la vest la est (aval). Zona unei ere se vede de la inceput, estompata
-- si ingradita, si se deschide cu clopotul erei dinainte [B, B4].
TycoonConfig.ZONES = {
    { id = "landing", name = "The Landing", era = 1, x0 = 200, x1 = 1860 },
    { id = "mill", name = "The Mill", era = 2, x0 = 1860, x1 = 2880 },
}

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

-- Cele 48 de platforme, in ordine. Preturile NU se calculeaza aici -- vin exact din simulator
-- (sim_tycoon.py, tura 1, lacom). Pozitii doar pentru Era 1; erele urmatoare nu au inca lume construita.
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
        blurb = "Someone to empty your nets into the storage.",
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
        blurb = "Someone to carry logs from the storage to the sawmill.",
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
        blurb = "Someone to work the saw so you don't have to stand there.",
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
        blurb = "Someone to take the planks from the sawmill to the tavern.",
        note = "Planks reach the tavern on their own",
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
        blurb = "Someone to run the tavern while you walk the bank.",
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
        blurb = "Someone to carry scrap from the Scrap Shed to the Forge.",
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
        blurb = "Someone to work the forge so you don't have to stand there.",
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
        blurb = "Someone to take the iron from the Forge to the tavern.",
        note = "Iron reaches the tavern on its own",
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
    -- ---- Era 2 · The Mill ----
    pad({
        id = "water_wheel",
        index = 19,
        blurb = "The river turns the wheel, the wheel runs your stations.",
        note = "+10 power",
        name = "Water Wheel",
        era = 2,
        motive = "V",
        price = 900,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "flume",
        index = 20,
        blurb = "A wooden chute carries every catch to the dock on its own.",
        note = "No more walking",
        name = "Flume",
        era = 2,
        motive = "A",
        price = 1300,
        effects = { flagEffect("flume") },
        live = false,
    }),
    pad({
        id = "sixth_net",
        index = 21,
        blurb = "One more net, one more line of income.",
        name = "Sixth Net",
        era = 2,
        motive = "C",
        price = 1600,
        effects = { netEffect(0.45, 2) },
        live = false,
    }),
    pad({
        id = "smelter",
        index = 22,
        blurb = "Melt scrap into iron. Iron sells for three times the rust.",
        name = "Smelter",
        era = 2,
        motive = "V",
        price = 2000,
        effects = { buildEffect("scrap", 3.0, 1.0, 5.0) },
        live = false,
    }),
    pad({
        id = "miller",
        index = 23,
        blurb = "A miller who knows his trade. Everything processed is worth more.",
        note = "+20% on processed goods",
        name = "Miller",
        era = 2,
        motive = "V",
        price = 2800,
        effects = { flagEffect("miller") },
        live = false,
    }),
    pad({
        id = "loom",
        index = 24,
        blurb = "Reeds go in, cloth comes out.",
        name = "Loom",
        era = 2,
        motive = "V",
        price = 3500,
        effects = { buildEffect("reeds", 3.0, 0.8, 6.0) },
        live = false,
    }),
    pad({
        id = "wide_nets",
        index = 25,
        blurb = "Wider mouths, same river.",
        note = "+40% catch rate",
        name = "Wide Nets",
        era = 2,
        motive = "C",
        price = 4500,
        effects = { mulEffect("rateMult", 1.40) },
        live = false,
    }),
    pad({
        id = "seventh_net",
        index = 26,
        blurb = "The bank fills with nets. So does your sack.",
        name = "Seventh Net",
        era = 2,
        motive = "C",
        price = 6000,
        effects = { netEffect(0.50, 1) },
        live = false,
    }),
    pad({
        id = "second_wheel",
        index = 27,
        blurb = "A second wheel for the stations you just built.",
        note = "+10 power",
        name = "Second Wheel",
        era = 2,
        motive = "V",
        price = 8000,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "market",
        index = 28,
        blurb = "A proper market at the dock.",
        note = "+25% sale price",
        name = "Market",
        era = 2,
        motive = "V",
        price = 9000,
        effects = { mulEffect("priceMult", 1.25) },
        live = false,
    }),
    pad({
        id = "mill_bell",
        index = 29,
        blurb = "The Mill is finished. Ring it.",
        note = "+15% forever, opens The Yard",
        name = "Mill Bell",
        era = 2,
        motive = "D",
        price = 13000,
        effects = { mulEffect("bells", 1.15) },
        live = false,
    }),

    -- ---- Era 3 · The Yard ----
    pad({
        id = "crane",
        index = 30,
        blurb = "Heavy finds stop breaking your back, and start paying better.",
        note = "+50% on named finds",
        name = "Crane",
        era = 3,
        motive = "V",
        price = 18000,
        effects = { mulEffect("namedMult", 1.5) },
        live = false,
    }),
    pad({
        id = "eighth_net",
        index = 31,
        blurb = "Another net where the current runs hard.",
        name = "Eighth Net",
        era = 3,
        motive = "C",
        price = 20000,
        effects = { netEffect(0.55, 2) },
        live = false,
    }),
    pad({
        id = "sorting_shed",
        index = 32,
        blurb = "Six more shapes you can name. The Index grows.",
        name = "Sorting Shed",
        era = 3,
        motive = "V",
        price = 28000,
        effects = { addEffect("indexFound", 6) },
        live = false,
    }),
    pad({
        -- BAZA LUI E ACUM STATIA DIN ERA 1 [D48]: pad-ul `sawmill` din Era 2 a fost scos cand gaterul
        -- a intrat in lantul Erei 1. Modelul vechi de efecte (buildEffect/upgradeEffect) e oricum
        -- scos din uz (TycoonMath); se re-deriva odata cu Era 2/3.
        id = "sawmill_2",
        index = 33,
        blurb = "Twice the planks from the same saw.",
        note = "Sawmill capacity x2",
        name = "Sawmill II",
        era = 3,
        motive = "V",
        price = 30000,
        effects = { upgradeEffect("driftwood", 2.0) },
        live = false,
    }),
    pad({
        id = "ninth_net",
        index = 34,
        blurb = "Nine nets. The river barely passes you now.",
        name = "Ninth Net",
        era = 3,
        motive = "C",
        price = 35000,
        effects = { netEffect(0.55, 1) },
        live = false,
    }),
    pad({
        id = "fine_ingots",
        index = 35,
        blurb = "Cleaner iron, higher price.",
        note = "+50% on iron",
        name = "Fine Ingots",
        era = 3,
        motive = "V",
        price = 40000,
        effects = { refineEffect("scrap", 1.5) },
        live = false,
    }),
    pad({
        id = "dockhand",
        index = 36,
        blurb = "A dockhand who haggles so you do not have to.",
        note = "+20% sale price",
        name = "Dockhand",
        era = 3,
        motive = "V",
        price = 45000,
        effects = { flagEffect("dockhand") },
        live = false,
    }),
    pad({
        id = "deep_channel",
        index = 37,
        blurb = "Dig into the deep channel, where shards and rare finds ride.",
        note = "Opens the third lane",
        name = "Deep Channel",
        era = 3,
        motive = "C",
        price = 50000,
        effects = { netEffect(0.60, 3), addEffect("lanes", 1) },
        live = false,
    }),
    pad({
        id = "kiln",
        index = 38,
        blurb = "Fire the shards into pottery.",
        name = "Kiln",
        era = 3,
        motive = "V",
        price = 55000,
        effects = { buildEffect("shards", 3.0, 0.6, 8.0) },
        live = false,
    }),
    pad({
        id = "third_wheel",
        index = 39,
        blurb = "Power for the yard, before it slows down.",
        note = "+10 power",
        name = "Third Wheel",
        era = 3,
        motive = "V",
        price = 60000,
        effects = { addEffect("flow", 10) },
        live = false,
    }),
    pad({
        id = "salvage_hall",
        index = 40,
        blurb = "Named finds get a room of their own, and a better price.",
        note = "+30% on named finds",
        name = "Salvage Hall",
        era = 3,
        motive = "V",
        price = 70000,
        effects = { mulEffect("namedMult", 1.3) },
        live = false,
    }),
    pad({
        id = "yard_bell",
        index = 41,
        blurb = "The Yard is finished. Ring it.",
        note = "+20% forever, opens The Harbor",
        name = "Yard Bell",
        era = 3,
        motive = "D",
        price = 75000,
        effects = { mulEffect("bells", 1.20) },
        live = false,
    }),

    -- ---- Era 4 · The Harbor ----
    pad({
        id = "boathouse",
        index = 42,
        blurb = "A boat that goes upstream and comes back loaded.",
        name = "Boathouse",
        era = 4,
        motive = "C",
        price = 80000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "tenth_net",
        index = 43,
        blurb = "Ten nets across the harbour mouth.",
        name = "Tenth Net",
        era = 4,
        motive = "C",
        price = 90000,
        effects = { netEffect(0.65, 3) },
        live = false,
    }),
    pad({
        id = "fine_cloth",
        index = 44,
        blurb = "Tighter weave, better cloth.",
        note = "+50% on cloth",
        name = "Fine Cloth",
        era = 4,
        motive = "V",
        price = 100000,
        effects = { refineEffect("reeds", 1.5) },
        live = false,
    }),
    pad({
        id = "deep_nets",
        index = 45,
        blurb = "Nets that reach the riverbed.",
        note = "+30% catch rate",
        name = "Deep Nets",
        era = 4,
        motive = "C",
        price = 110000,
        effects = { mulEffect("rateMult", 1.30) },
        live = false,
    }),
    pad({
        id = "second_boat",
        index = 46,
        blurb = "A second boat, a second run upstream.",
        name = "Second Boat",
        era = 4,
        motive = "C",
        price = 120000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "glazed_pottery",
        index = 47,
        blurb = "Glaze it and it leaves the kiln worth half again more.",
        note = "+50% on pottery",
        name = "Glazed Pottery",
        era = 4,
        motive = "V",
        price = 130000,
        effects = { refineEffect("shards", 1.5) },
        live = false,
    }),
    pad({
        id = "eleventh_net",
        index = 48,
        blurb = "Almost every lane is yours.",
        name = "Eleventh Net",
        era = 4,
        motive = "C",
        price = 150000,
        effects = { netEffect(0.70, 2) },
        live = false,
    }),
    pad({
        id = "lighthouse",
        index = 49,
        blurb = "Ships find your dock at night.",
        note = "+25% sale price",
        name = "Lighthouse",
        era = 4,
        motive = "V",
        price = 160000,
        effects = { mulEffect("priceMult", 1.25) },
        live = false,
    }),
    pad({
        id = "third_boat",
        index = 50,
        blurb = "Three boats, three cargoes.",
        name = "Third Boat",
        era = 4,
        motive = "C",
        price = 180000,
        effects = { addEffect("boats", 1) },
        live = false,
    }),
    pad({
        id = "grand_market",
        index = 51,
        blurb = "Traders come to you now.",
        note = "+30% sale price",
        name = "Grand Market",
        era = 4,
        motive = "V",
        price = 200000,
        effects = { mulEffect("priceMult", 1.30) },
        live = false,
    }),
    pad({
        id = "twelfth_net",
        index = 52,
        blurb = "The last net. Nothing floats past unclaimed.",
        name = "Twelfth Net",
        era = 4,
        motive = "C",
        price = 250000,
        effects = { netEffect(0.75, 3) },
        live = false,
    }),
    pad({
        id = "the_charter",
        index = 53,
        blurb = "The whole river is yours, on paper and in fact.",
        note = "+25% forever",
        name = "The Charter",
        era = 4,
        motive = "D",
        price = 280000,
        effects = { mulEffect("bells", 1.25) },
        live = false,
    }),
} :: { Pad }

-- Index construit o singura data la incarcare, ca PadService sa nu caute liniar prin 48 de intrari
-- la fiecare cumparare.
local byId: { [string]: Pad } = {}
for _, p in TycoonConfig.PADS do
    byId[p.id] = p
end
TycoonConfig.byId = byId

-- [D63] VERBUL unei platforme, acelasi pe butonul cartonasului si in textul quest-ului ei: o plasa se arunca ("cast"),
-- un om se angajeaza ("hire"), traista se ia ("get"), clopotul se trage ("ring"), restul se construiesc ("build").
-- Un test tine verbul legat de textele din QuestConfig.
function TycoonConfig.verbOf(p: Pad): string
    for _, effect in p.effects do
        if effect.kind == "net" then
            return "cast"
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

return TycoonConfig
