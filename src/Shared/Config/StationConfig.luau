--!strict
-- Cifrele lantului. Sursa lor e `scripts/economy/sim_tycoon.py` -- aici sunt transcrise, nu
-- inventate: testele din `tests/ChainMath.test.luau` verifica debitele la ultimul bit, iar
-- simulatorul citeste fisierul asta si pica daca o constanta a oamenilor s-a despartit [D49].
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

StationConfig.LEVEL_INC = { nets = 0.03, saw = 0.06, dock = 0.06, forge = 0.06 }
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
StationConfig.NET_LANES = { 1, 1, 2, 2, 3 } -- pe ce banda sta fiecare din cele 5 plase ale Erei 1
-- [D55] ce prinde fiecare: ultima plasa, cea din larg, prinde scrap (TycoonConfig.CATCH)
StationConfig.NET_KINDS = { "wood", "wood", "wood", "wood", "scrap" }

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
-- NEGUSTORUL FACE DEBARCADERUL SA MEARGA, NU SA PLATEASCA MAI BINE. Fara el, debarcaderul vinde
-- singur la o treime; cu el, merge tot timpul. E singurul pas pe care nu-l faci tu.
StationConfig.NO_TRADER_FACTOR = 0.35

-- ---- oamenii [D49] ---------------------------------------------------------------------------
-- Ordinea din LINE_STEPS e si ordinea angajarilor (conditiile platformelor o impun). [D56] Fiecare linie are
-- timpul tau intreg: in joc nu ai niciodata pasi de mana pe amandoua odata (oamenii lemnului vin toti inaintea
-- Forge), iar asa deschiderea fierului nu poate scadea lemnul in nicio stare.
StationConfig.ROLES = {
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
StationConfig.LINE_STEPS = {
    wood = { "collector", "porter", "sawyer", "hauler" },
    iron = { "scrapCollector", "scrapPorter", "smelter", "ironHauler" },
}
StationConfig.MANUAL_ROLES = {
    "collector",
    "porter",
    "sawyer",
    "hauler",
    "scrapCollector",
    "scrapPorter",
    "smelter",
    "ironHauler",
}
StationConfig.LINK_OF = {
    collector = "collect",
    porter = "port",
    sawyer = "saw",
    hauler = "haul",
    trader = "dock",
    scrapCollector = "scrapCollect",
    scrapPorter = "scrapPort",
    smelter = "forge",
    ironHauler = "ironHaul",
}
-- ORDINEA e contractul cu simulatorul: la egalitate castiga veriga dinainte. [D56] Plasele, linia lemnului, linia
-- fierului, taverna (a amandurora).
StationConfig.LINKS = {
    "nets",
    "collect",
    "port",
    "saw",
    "haul",
    "scrapCollect",
    "scrapPort",
    "forge",
    "ironHaul",
    "dock",
}
-- [D56] Linia fiecarei verigi de oameni si cladiri. `nets` tine de felul plasei (TycoonMath.netKind), `dock` e a
-- amandurora: ele nu stau aici.
StationConfig.LINE_OF = {
    collect = "wood",
    port = "wood",
    saw = "wood",
    haul = "wood",
    scrapCollect = "iron",
    scrapPort = "iron",
    forge = "iron",
    ironHaul = "iron",
}

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
