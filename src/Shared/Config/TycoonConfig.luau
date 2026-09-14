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
TycoonConfig.PIER = { x = 300, y = 830 } -- pontonul inalt (pier3) si barca vanzarii, pe punte
-- Taverna, prinsa de baza: sprite de 64x48 la PIXEL_SCALE 3 = 192x144, deci ocupa x 304..496 si
-- y 936..1080 -- sub ponton (care se termina la y 914), deasupra drumului mare (y >= 1100).
TycoonConfig.TAVERN = { x = 400, y = 1080, w = 192, h = 144 }
TycoonConfig.LANE_Y = { 732, 660, 588 } -- banda 1 e cea mai aproape de mal
TycoonConfig.FAR_CURRENT_Y = 516 -- curentul din larg: decorul, bunurile care inca nu se pot prinde [D53]
-- [D53] Curentul de langa plase: pe el vin bustenii care vor fi prinsi (CatchFloat). Sub decor, deasupra
-- oricarei plase din amonte (varful benzii 2 e la 633); bustean de 27 px inalt -> 533..572.
TycoonConfig.NEAR_CURRENT_Y = 552
-- Pe iarba dintre punte si drumul mare, la dreapta tarabei Negustorului (x <= 708), ca personajul
-- (48x72) sa nu apara intr-o cladire; de aici se vad si plasele, si drumul.
TycoonConfig.SPAWN = { x = 860, y = 1010 }

export type Rect = { x0: number, x1: number, y0: number, y1: number }
export type Road = { id: string, x0: number, x1: number, y0: number, y1: number }

-- [F3] Malul construit. Pontonul e fasia de scanduri de-a lungul apei, pe care stau stalpii plaselor.
-- Se termina la legatura depozitului: mai departe ar fi fost scanduri pe care nu calca nimeni [D50].
-- Totul in coordonate LOCALE terenului, ca restul pozitiilor [B5].
TycoonConfig.DECK = { x0 = 240, x1 = 1560, y0 = 772, y1 = 856 } :: Rect

-- [D50] DRUMURILE, harta in bucla: plasele pe rau -> depozitul la est -> gaterul la sud-est ->
-- taverna la vest, fiecare om pe drumul lui. Dreptunghiuri care doar SE ATING, niciunul nu-l
-- incruciseaza pe altul: capatul unuia cade pe marginea altuia. Din ele (plus DECK) RoadGraph face
-- graful pe care merg oamenii si dara de ghidaj, iar SceneArt le deseneaza.
TycoonConfig.ROADS = {
    { id = "main", x0 = 240, x1 = 1800, y0 = 1100, y1 = 1160 }, -- drumul mare, de la taverna la depozit
    { id = "storage_link", x0 = 1470, x1 = 1520, y0 = 856, y1 = 1100 }, -- puntea -> drumul mare
    { id = "tavern_link", x0 = 520, x1 = 570, y0 = 856, y1 = 1100 }, -- puntea -> taverna
    { id = "east", x0 = 1570, x1 = 1630, y0 = 1160, y1 = 1480 }, -- depozitul -> gaterul (Porter)
    { id = "yard", x0 = 1300, x1 = 1630, y0 = 1480, y1 = 1560 }, -- curtea gaterului
    { id = "south", x0 = 500, x1 = 1300, y0 = 1500, y1 = 1560 }, -- gaterul -> vest (Hauler)
    { id = "west", x0 = 500, x1 = 560, y0 = 1160, y1 = 1500 }, -- pintenul de vest, spre taverna
} :: { Road }

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

-- Unde sta Negustorul: la tejgheaua tavernei, pe drumul mare, in dreapta usii (DOCK). Picioarele la
-- y 1152, deci capul (y 1080) atinge baza tavernei fara sa intre peste ea: amandoua se ating cu
-- degetul, iar doua lucruri apasabile care se suprapun isi fura clicurile.
-- Un rol static are nevoie de o pozitie fixa -- nu are ciclu din care sa iasa una.
TycoonConfig.TRADER_STAND = { x = 470, y = 1152 }
-- Roata zilnica, ca OBIECT in lume, nu doar ca intrare in bara de meniu: la ei se vede in mina, si
-- de-aia se stie ca exista. Sprite de 40 la PIXEL_SCALE 3 = 120x120, prins de baza, deci ocupa
-- x 270..390 si y 1240..1360: sub taverna, la stanga pintenului de vest (x >= 500).
TycoonConfig.WHEEL_STAND = { x = 330, y = 1360 }

-- OAMENII CARE MERG [D49]: Collector, Porter, Hauler. Aceeasi viteza (jumatate din a jucatorului)
-- si aceleasi pauze pentru toti; unde merge fiecare vine din HandRoutes. Merg in linie dreapta, ca
-- alergatorul de dinainte: cladirile nu blocheaza mersul (WorldMap.blockedRects = doar raul).
TycoonConfig.RUNNER = {
    speed = 150,
    pauseNet = 0.6, -- la fiecare oprire: plasa, depozitul, gura gaterului
    pauseDock = 1.0, -- la capat, unde lasa marfa
}

-- DEPOZITUL [D49]: unde Collector-ul varsa ce strange din plase, iar Porter-ul ia de acolo. La
-- capatul de est al puntii [D50], unde se leaga de drumul mare. Prins de baza; sprite de 40x32 la
-- PIXEL_SCALE 3 = 120x96, deci ocupa x 1540..1660 si y 924..1020: la dreapta legaturii (x <= 1520),
-- deasupra drumului mare (y >= 1100).
TycoonConfig.STORAGE = { x = 1600, y = 1020, w = 120, h = 96 }
-- [D55] pe drumul mare, la stanga gramezii: omul sta cu fata spre ea si rastoarna roaba peste ea
TycoonConfig.STORAGE_STAND = { x = 1540, y = 1122 }

-- GATERUL [D49]: departe de plase [owner, 2026-09-13: "sawmill-ul este prea aproape de nets"], la
-- sud-est, cu usa spre curte [D50]. Prins de baza: ocupa x 1360..1480, y 1384..1480, iar curtea
-- (ROADS.yard) incepe exact la baza lui. Verificat de testul de asezare.
TycoonConfig.SAWMILL = { x = 1420, y = 1480, w = 120, h = 96 }
-- Unde stai ca sa tai si ca sa predai tu, in curte, in fata usii.
TycoonConfig.SAWMILL_STAND = { x = 1390, y = 1540 }
-- [D55] Bustenii STANGA, scandurile DREAPTA, lipite de cladire -- exact sensul din desenul gaterului
-- (bustenul intra din stanga, panza e in dreapta) [owner: "ar trebui sa fie macar langa sawmill in stanga
-- respectiv in dreapta, nu mai jos de poteca"]. Porter-ul sta la stanga gramezii de busteni (pe drumul de sud),
-- Hauler-ul la dreapta celei de scanduri (in coltul curtii), fiecare cu fata spre gramada lui.
TycoonConfig.SAWMILL_IN = { x = 1260, y = 1512 }
TycoonConfig.SAWMILL_OUT = { x = 1600, y = 1515 }
-- Sawyer-ul, in curte, in fata panzei. Omul (48x72, prins de picioare) incepe la y 1476, sub cladire:
-- mai sus ar intra peste fata gaterului si doua lucruri apasabile s-ar calca.
TycoonConfig.SAWYER_STAND = { x = 1450, y = 1552 }

-- [D50] GRAMEZILE, ca locuri fixe. [D55] `x` = mijlocul, `y` = BAZA gramezii (desenul pe trepte, 80x56, se
-- prinde de baza, ca o cladire); cifra sta deasupra. Verificate de testul de asezare.
export type PileSpot = { x: number, y: number, pill: string? }
TycoonConfig.PILES = {
    -- in fata usii depozitului, pe iarba dintre el si drumul mare; cifra in dreapta, deasupra e depozitul
    storage = { x = 1600, y = 1096, pill = "right" },
    shed = { x = 1290, y = 1024 }, -- [D55] la stanga shed-ului de scrap
    sawmillIn = { x = 1318, y = 1482 }, -- bustenii, lipiti de stanga gaterului
    sawmillOut = { x = 1525, y = 1482 }, -- scandurile, lipite de dreapta lui
    forgeIn = { x = 680, y = 1440 }, -- [D55] scrap-ul de topit, la stanga atelierului
    forgeOut = { x = 960, y = 1440 }, -- [D55] fierul, la dreapta lui
    tavern = { x = 262, y = 1086 }, -- la stanga tavernei, langa butoaie
} :: { [string]: PileSpot }

-- [D55] RESTURILE. Unde se opresc oamenii la shed si la atelier (pe drum, in fata gramezilor), unde stai tu
-- la atelier, si cat lasa sa se adune inainte sa se opreasca: Collector-ul lasa scrap-ul in plasa cand
-- shed-ul are deja `shed`, Porter-ul nu mai ia de la shed cand atelierul are deja `forge` de topit -- altfel
-- ar cara fier vechi pe care forja nu-l poate topi, in locul lemnului pe care gaterul l-ar taia.
TycoonConfig.SCRAP_SHED_STAND = { x = 1350, y = 1080 }
TycoonConfig.FORGE_IN = { x = 620, y = 1515 }
TycoonConfig.FORGE_OUT = { x = 1020, y = 1515 }
TycoonConfig.WORKSHOP_STAND = { x = 820, y = 1490 }
TycoonConfig.SCRAP_BACKLOG = { shed = 60, forge = 40 }

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
    sawyer = { pad = "hire_sawyer", name = "Sawyer", plural = "Sawyers", secondPrice = 12000 },
    hauler = { pad = "hire_hauler", name = "Hauler", plural = "Haulers", secondPrice = 2500 },
    trader = {
        pad = "dock_trader",
        name = "Innkeeper",
        plural = "Innkeepers",
        secondPrice = 4000,
    },
}
-- Unde sta al doilea om al unei meserii statice, fata de primul. Sawyer-ul al doilea: in dreapta
-- primului si putin mai jos, departe de gramada de busteni. Innkeeper-ul al doilea tot in dreapta: in
-- stanga ar fi stat chiar in usa tavernei, unde se lasa marfa si unde asteapta clientii.
-- [D55] Sawyer-ul al doilea, in dreapta primului, sub gramada de scanduri: mai la est ar sta pe locul unde ia
-- Hauler-ul, iar in stanga in fata gramezii de busteni.
TycoonConfig.SECOND_STAND_OFFSET = { sawyer = { x = 60, y = 4 }, trader = { x = 60, y = 0 } }
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
        price = 12,
        effects = { hireEffect("collector") },
        live = true,
        -- langa depozit, la capatul de est al puntii: coliba lui sta la dreapta usii. [D55] Cu doi oameni
        -- coliba mare (144x120) ocupa x 1713..1857 -- sub gardul Morii (x 1860).
        x = 1785,
        y = 975,
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
        price = 15,
        effects = { hireEffect("porter") },
        live = true,
        -- [D55] La capatul de sus al drumului lui, in dreapta drumului de est, sub drumul mare: avizierul, apoi
        -- coliba (cea mare, 120x102, ocupa x 1645..1765, y 1188..1290 -- deasupra clopotului, y >= 1308).
        x = 1705,
        y = 1234,
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
        price = 18,
        effects = { hireEffect("sawyer") },
        live = true,
        -- [D55] Lipit de spatele gaterului: coliba mare (120x102) ocupa y 1270..1372, gaterul incepe la 1384.
        -- Omul insusi sta in curte (SAWYER_STAND).
        x = 1420,
        y = 1316,
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
        price = 20,
        effects = { hireEffect("hauler") },
        live = true,
        -- [D55] La capatul lui de la taverna: in dreapta pintenului de vest (x >= 560), sub drumul mare, unde
        -- ajunge cu scandurile. Coliba mare (120x102) ocupa x 588..708, y 1188..1290 -- atelierul incepe la 724.
        x = 648,
        y = 1234,
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
        price = 25,
        effects = { hireEffect("trader") },
        live = true,
        -- LANGA TAVERNA, nu in randul statiilor: un Innkeeper departe de taverna nu se leaga. Taraba
        -- (96x80) sta la dreapta legaturii tavernei (x >= 570), deasupra drumului mare.
        x = 660,
        y = 1000,
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
        -- intre atelier (x <= 916) si platforma Hauler-ului (x >= 1172), sub drumul mare
        x = 1060,
        y = 1300,
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
        id = "workshop",
        index = 11,
        blurb = "A bench, a vise and a forge: finds get restored, scrap becomes iron.",
        note = "Smelts scrap into iron",
        name = "Workshop",
        era = 1,
        motive = "V",
        price = 5500,
        effects = { addEffect("indexFound", 6) },
        live = true,
        -- in mijlocul terenului, sub drumul mare; cladirea (192x192) se termina deasupra drumului de sud
        x = 820,
        y = 1380,
        needs = { netsOwned = 4 },
    }),
    pad({
        -- [D55] al doilea depozit, doar pentru scrap: Collector-ul il lasa aici, Porter-ul il duce la atelier
        id = "scrap_shed",
        index = 12,
        blurb = "A shed for scrap, so it never mixes with the logs.",
        note = "Opens the Fifth Net",
        name = "Scrap Shed",
        era = 1,
        motive = "V",
        price = 7500,
        effects = { flagEffect("scrapShed") },
        live = true,
        -- la stanga drumului depozitului, sub plasa a cincea: sopronul (120x96) ocupa x 1340..1460, y 924..1020
        x = 1400,
        y = 964,
        needs = { after = "workshop" },
    }),
    pad({
        id = "fifth_net",
        index = 13,
        blurb = "The deep channel, where the scrap sinks.",
        note = "Catches scrap",
        name = "Fifth Net",
        era = 1,
        motive = "C",
        price = 8000,
        effects = { netEffect(0.40, 3, "scrap") },
        live = true,
        x = 1420,
        y = 812,
        -- [D55] scrap-ul ei are nevoie de shed: fara el n-ar avea unde sa-l lase nimeni
        needs = {
            netsExactly = 4,
            prevNetLevel = TycoonConfig.PREV_NET_LEVEL,
            after = "scrap_shed",
        },
    }),
    pad({
        id = "landing_bell",
        index = 14,
        blurb = "Ring it and The Landing is finished.",
        note = "+10% forever, opens The Mill",
        name = "Landing Bell",
        era = 1,
        motive = "D",
        price = 9000,
        effects = { mulEffect("bells", 1.10) },
        live = true,
        -- langa gardul Morii, pe care il deschide; cladirea (120x168) sta la 30 px de gard
        x = 1770,
        y = 1420,
        needs = { all = true },
    }),
    -- ---- Era 2 · The Mill ----
    pad({
        id = "water_wheel",
        index = 15,
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
        index = 16,
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
        index = 17,
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
        index = 18,
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
        index = 19,
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
        index = 20,
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
        index = 21,
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
        index = 22,
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
        index = 23,
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
        index = 24,
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
        index = 25,
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
        index = 26,
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
        index = 27,
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
        index = 28,
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
        index = 29,
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
        index = 30,
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
        index = 31,
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
        index = 32,
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
        index = 33,
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
        index = 34,
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
        index = 35,
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
        index = 36,
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
        index = 37,
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
        index = 38,
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
        index = 39,
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
        index = 40,
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
        index = 41,
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
        index = 42,
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
        index = 43,
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
        index = 44,
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
        index = 45,
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
        index = 46,
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
        index = 47,
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
        index = 48,
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
        index = 49,
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

return TycoonConfig
