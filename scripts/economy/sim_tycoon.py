#!/usr/bin/env python3
"""Simulatorul economiei. Se ruleaza INAINTE de orice cod de balans [23].

MODELUL (2026-09-12 dupa Idle Miner Tycoon; oamenii din 2026-09-13, D49). Pana la D46 era o lista de
48 de platforme cumparate o singura data, iar venitul era o suma. Acum sunt DOUA axe si o GATUIRE:

  1. DEBLOCARI -- plasa noua, oamenii (Collector, Porter, Sawyer, Hauler, Negustorul), traista mare,
     clopotul. Rare, scumpe, deschid ceva ce nu exista.
  2. NIVELURI -- fiecare plasa, gaterul si debarcaderul urca la nesfarsit. Fiecare nivel da putin
     (+3..6%), dar la nivelurile 10/25/50/100 se dubleaza. Oamenii au in schimb TREPTE, putine, si
     un al doilea om pe aceeasi treaba [owner, 2026-09-13: "nu foarte multe pentru ca se presupune
     ca sunt oameni"].

  3. LANTUL. Venitul NU e o suma, e minimul a SASE debite [D49]:
         plasele -> adunatul (Collector) -> dusul la gater (Porter) -> taiatul (gaterul, Sawyer)
                 -> dusul la debarcader (Hauler) -> vanzarea (debarcaderul, Negustorul)
     Fiecare pas fara om il faci TU, iar timpul tau se imparte intre ei. Veriga cea mai slaba
     decide venitul, si tocmai repararea ei e decizia jucatorului.
  4. LINIA FIERULUI [D56]. Plasa a cincea prinde scrap, iar fierul are OAMENII LUI, pe aceiasi pasi ca lemnul:
         plasa de scrap -> Scrap Collector (la shed) -> Scrap Porter (la forja) -> forja (Smelter)
                        -> Iron Hauler (la taverna) -> vanzarea (aceeasi taverna)
     Cele doua linii impart doar taverna, care vinde intai fierul (bucata valoreaza mai mult). In D55 aceiasi
     trei oameni duceau ambele marfuri, iar forja mergea singura: owner-ul n-a vazut pe nimeni ocupandu-se de
     scrap. Fara Forge si Fifth Net, lantul e exact cel cu sase debite de mai sus.

Regulile pe care simulatorul le IMPUNE, nu doar le masoara:
  A. Preturile deblocarilor se DERIVA din tinte de ritm, nu se ghicesc.
  B. Regula celor patru motive, rescrisa pentru lant: orice cumparatura trebuie sa creasca
     venitul ATUNCI CAND tinteste veriga slaba, si niciodata nu-l scade. Un upgrade pe o veriga
     care nu e gatuirea da zero -- asta nu e o greseala, e lectia jocului (si in joc scrie asa,
     nu se inventeaza o cifra frumoasa [D40]).
  C. Primele cinci minute raman o rafala: cel putin 6 cumparaturi.
  D. Fiecare prag de nivel trebuie sa se simta: salt de peste 15%.
  E. Nicio veriga nu e decor de tot: fiecare e gatuirea macar 0.5% din timp. Era 5% [D48, D49]; cu
     toti cinci oamenii dupa prima vanzare, gaterul, Hauler-ul si taverna ies ~2-3% [D52].
  F. Portile tin si cu fiecare constanta a oamenilor cu 15% in sus sau in jos (--robust) [D49].

Jucatorul simulat e LACOM: cumpara imediat ce isi permite, mereu ce da cel mai mult pe moneda.
Un om real merge, citeste, exploreaza -- de aceea factorul REAL. Si urmeaza quest-urile, deci
simulatorul le urmeaza si el acolo unde lacomia singura s-ar bloca (vezi `run`).

Folosire:  python3 scripts/economy/sim_tycoon.py [--table] [--chain] [--robust]
"""
import os
import sys
from dataclasses import dataclass, field

REAL = 1.8  # un jucator real ~ de 1.8 ori mai lent decat cel lacom (IPOTEZA, de masurat)

# [D62, pasul 3] DARURILE RAULUI (src/Shared/Modules/DriftMath.luau): un butoi / o lada / un bustean de aur la 56 s,
# platite in secunde din venitul de acum. Cine le prinde pe TOATE castiga ~31% in plus; cine prinde jumatate, ~15%.
# E o ESTIMARE (nu stim cate prind jucatorii), deci NU intra in preturi si nici in portile de ritm: acelea raman pe
# jucatorul care nu prinde niciunul. Aici se afiseaza doar cat s-ar scurta Era 1.
DRIFT_WINDOW = 56.0
DRIFT_KINDS = ((72, 10.0), (22, 25.0), (6, 75.0))  # (pondere, secunde de venit): butoi, lada, bustean de aur
DRIFT_SHARE = 0.5  # cat din daruri prinde un jucator obisnuit (IPOTEZA, de masurat)


def drift_bonus(share=DRIFT_SHARE):
    total = sum(w for w, _ in DRIFT_KINDS)
    seconds = sum(w * sec for w, sec in DRIFT_KINDS) / total
    return share * seconds / DRIFT_WINDOW

# [D65] CADRUL EREI 2 E UN SINGUR NUMAR: de cate ori valoreaza marfa ei mai mult decat a Erei 1. Tot ce se masoara in
# monede in cartierul nou se inmulteste cu el (valoarea bucatii, costul nivelurilor, costul treptelor); tot ce se
# masoara in bucati pe secunda ramane ca in Era 1.
# [D66] 3000, NU 40: O SINGURA MONEDA, IAR MINA NOUA PE O SCARA MULT MAI MARE (ca minele unui continent din Idle Miner).
# Cu 40, o noapte de absenta de la sfarsitul Erei 1 platea 352 din cele 398 de cumparaturi ale Erei 2, iar o zi pe toate
# [owner, 2026-09-21: "am reusit sa deblochez cu acei bani toata era 2 dintr-un foc"]. Cu 3000, banii satului (si o
# noapte de-a lor) platesc doar inceputul Morii: roata, a sasea plasa, cei cinci oameni, a saptea plasa. Poarta
# `check_windfall` tine regula pentru orice era. (Separarea banilor pe cartiere a fost respinsa de owner.)
ERA2_MULT = 3000.0
# [D67] ERA 3, „THE WIRE WORKS", pe aceeasi regula: de 3000 de ori Moara, deci de 3000 x 3000 de ori satul. O noapte de
# absenta la sfarsitul Morii plateste tot doar inceputul erei (check_windfall).
ERA3_MULT = ERA2_MULT * 3000.0
# [D70] ERA 4, „THE DAM", tot pe regula asta: de 3000 de ori Wire Works (docs/PLAN-MOTOR-UNIRE.md). Barajul inchide
# satul vechi, deci o noapte de absenta nu mai e poarta erei: toti pornesc cu aceeasi suma (START_SUM, derivata mai jos).
ERA4_MULT = ERA3_MULT * 3000.0

GOODS = {  # valoarea de baza a unei bucati, in monede
    "driftwood": 1.0,
    "scrap": 3.0,  # [D55] se vinde doar topit: fierul valoreaza cat scrap-ul din care iese
    "named": 14.0,
    "planks": 1.0,
    "iron": 3.0,
    # [D65] Era 2. Plasele Morii prind tot scrap, dar turnatoria face din el PIESE DE MASINI: se vinde doar turnat,
    # piesa valoreaza cat scrap-ul din care iese. La fel minereul si cuprul. Gasirile cartierului nou: de ERA2_MULT ori.
    "mill_scrap": 1.0 * ERA2_MULT,
    "parts": 1.0 * ERA2_MULT,
    "ore": 3.0 * ERA2_MULT,
    "copper": 3.0 * ERA2_MULT,
    "named2": 14.0 * ERA2_MULT,
    # [D67] Era 3. Plasele Wire Works prind minereu de cupru, care iese BOBINE de sarma (bobina valoreaza cat minereul
    # din care iese). Turbina umple BATERII, care ies CELULE de energie. O turbina nu prinde gasiri din rau, deci bateria
    # valoreaza singura cat media plasei de minereu a Morii (3.55), rotunjita la 3.5 ca pretul sa fie exact.
    "works_ore": 1.0 * ERA3_MULT,
    "coils": 1.0 * ERA3_MULT,
    "battery": 3.5 * ERA3_MULT,
    "cell": 3.5 * ERA3_MULT,
    "named3": 14.0 * ERA3_MULT,
    # [D70] Era 4. PIESELE NU SE VAND (D70 Runda 4): sarcina turbinei iese butoi, minereul de cablu iese cablu, iar
    # amandoua valoreaza doar unite, ca unitate de curent livrata orasului. Valoarea unitatii e oglinda mediei primei
    # linii a fiecarei ere (1.65), scrisa ca produs (`1.65 * ERA4_MULT`), la fel in Luau: un literal ar muta un ulp.
    # Cristalul se vinde primul la oras, cat bateria din Era 3.
    "charge": 0.0,
    "barrel": 0.0,
    "cable_ore": 0.0,
    "cable": 0.0,
    "grid": 1.65 * ERA4_MULT,
    "crystal": 3.5 * ERA4_MULT,
    "ingot": 3.5 * ERA4_MULT,
}
# CE PRINDE O PLASA, dupa felul ei [D55]. Pana la D55 toate plasele prindeau acelasi amestec, iar banda cea
# mai departata decidea ce marfuri exista: dupa plasa a patra, si a doua prindea scrap, care trecea prin
# gater ca si cand ar fi fost lemn [owner, 2026-09-13: "scraps ar trebui sa poti prinde doar la ultimul
# net"]. Reeds si shards au iesit din Era 1 din acelasi motiv. (bun, pondere), in ordinea sumei.
CATCH = {
    "wood": (("driftwood", 0.95), ("named", 0.05)),
    "scrap": (("scrap", 0.95), ("named", 0.05)),
    "mill": (("mill_scrap", 0.95), ("named2", 0.05)),  # [D65] plasele Morii
    "ore": (("ore", 0.95), ("named2", 0.05)),  # [D65] plasa de minereu
    "works": (("works_ore", 0.95), ("named3", 0.05)),  # [D67] plasele Wire Works
    "turbine": (("battery", 1.0),),  # [D67] turbina: doar baterii
    # [D70] Era 4: turbina din baraj umple sarcina; plasele de sub baraj nu prind gasiri (D70 Runda 5): o gasire nu se
    # poate uni cu un butoi. Surprizele raman darurile raului si undita.
    "dam": (("charge", 1.0),),
    "cable_ore": (("cable_ore", 1.0),),
    "crystal": (("crystal", 1.0),),
}
# Valoarea medie a unei bucati prinse, pe fel de plasa. Aceeasi ordine a sumei ca in ChainMath.luau.
AVG = {kind: sum(share * GOODS[good] for good, share in parts) for kind, parts in CATCH.items()}

# ---- scara nivelurilor -----------------------------------------------------------------------
# Forma e copiata din Idle Miner si verificata pe capturi: acolo, un nivel adauga "+0.1" la un
# "3.3/s", adica vreo 3% -- crestere LINIARA, mica. Cresterea mare vine din praguri. Costul
# creste exponential, deci nivelurile devin tot mai scumpe pe unitatea de castig: exact motivul
# pentru care, la un moment dat, trebuie sa deblochezi ceva nou in loc sa tot urci acelasi lucru.
# Cat adauga un nivel, ca fractiune din baza. NU e aceeasi cifra peste tot: plasele sunt cinci si
# cresc impreuna, dar gaterul si debarcaderul sunt cate UNUL si trebuie sa tina pasul cu toate
# cinci. Cu acelasi increment peste tot, debarcaderul ramanea gatuire zeci de niveluri la rand si
# jocul se transforma in macinat.
LEVEL_INC = 0.03  # implicit (plasele)
LEVEL_INC_BY_KIND = {
    "nets": 0.03, "saw": 0.06, "dock": 0.06, "foundry": 0.06, "market": 0.06, "furnace": 0.06,
    "wireworks": 0.06, "depot": 0.06, "powerhouse": 0.06,
    # [D70] Era 4
    "switchyard": 0.06, "cableworks": 0.06, "relay": 0.06, "kiln": 0.06, "town": 0.06,
}
LEVEL_GROWTH = 1.09  # cat se scumpeste fiecare nivel
MILESTONES = (10, 25, 50, 100, 200, 300, 400, 500)
MILESTONE_MULT = 2.0


def milestone_mult(level: int) -> float:
    m = 1.0
    for t in MILESTONES:
        if level >= t:
            m *= MILESTONE_MULT
    return m


def next_milestone(level: int):
    for t in MILESTONES:
        if level < t:
            return t
    return None


def level_output(base: float, level: int, kind: str = "nets") -> float:
    inc = LEVEL_INC_BY_KIND.get(kind, LEVEL_INC)
    return base * (1 + inc * (level - 1)) * milestone_mult(level)


def level_cost(base_cost: float, level: int) -> float:
    """Cat costa trecerea de la `level` la `level + 1`."""
    return base_cost * LEVEL_GROWTH ** (level - 1)


# ---- cladirile -------------------------------------------------------------------------------
# Plasa k are baza mai mare decat k-1: altfel o plasa noua ar fi mai slaba decat un nivel pe una
# veche, si n-ar mai avea rost sa deblochezi nimic.
NET_BASE_RATE = 0.33  # prima plasa, nivel 1 -- aceeasi cifra ca azi, ca senzatia de start sa nu se schimbe
NET_BASE_GROWTH = 1.45
# [D65] CINCI PLASE PE ERA, in aceeasi schema: patru pentru marfa cu care pornesti era si una, in larg, pentru marfa
# noua. A k-a plasa a unei ere are baza celei de-a k-a plase a Erei 1; nivelurile ei costa de `net_era_mult` ori.
NETS_PER_ERA = 5
NET_LANES = (1, 1, 2, 2, 3, 1, 1, 2, 2, 3, 1, 1, 2, 2, 3)  # pe ce banda sta fiecare plasa: Era 1, Era 2, Era 3
# [D55] ultima plasa a Erei 1, cea din larg, prinde scrap; [D65] plasele Morii prind scrap pentru turnatorie, ultima minereu;
# [D67] plasele Wire Works prind minereu de cupru, iar in larg sta turbina
NET_KINDS = (
    "wood", "wood", "wood", "wood", "scrap", "mill", "mill", "mill", "mill", "ore",
    "works", "works", "works", "works", "turbine",
)

NET_UPGRADE_BASE_COST = 1.0  # nivelul 2 al primei plase; se scaleaza cu baza plasei

SACK_BONUS = 1.5  # traista mare: mai putine drumuri, pe tot ce duci tu

DOCK_BASE_RATE = 3.0  # bucati/s vandute, nivel 1 -- mult peste productia de inceput, deci
DOCK_UPGRADE_BASE = 9.0  # prima vanzare se scurge instant si se simte exact ca azi
# NEGUSTORUL FACE DEBARCADERUL SA MEARGA, NU SA PLATEASCA MAI BINE. Prima varianta ii dadea +20% la
# pret -- un bonus care nu se vede nicaieri pe ecran. Acum, fara el, debarcaderul merge la o treime;
# cu el, merge tot timpul. Se vede in cifra de pe randul "Dock", care sare la angajare, si se simte:
# ai scapat de o corvoada [motivul A]. E singurul pas pe care NU-l faci tu: vinde si singur, incet.
NO_TRADER_FACTOR = 0.35

# GATERUL [D48]. Nimic nu se vinde brut: tot ce aduci trece prin el, iar driftwood-ul iese scanduri.
# Scandura valoreaza cat valora bustenul -- gaterul e acolo de la inceput, deci un multiplicator ar
# umfla doar cifrele. Fara Sawyer taie doar cat stai langa el [D49].
# 2.4, nu 3.6 ca in D48: la 3.6 gaterul iesea gatuire 2-3% din timp, adica decor.
SAW_BASE_RATE = 2.4
SAW_UPGRADE_BASE = 7.0

# FORJA [D55, D56]: topeste scrap-ul in fier, cu niveluri ca gaterul. [D56] Ca gaterul: Smelter-ii o tin pornita
# tot timpul; fara ei topeste doar cat stai tu langa ea. Sub plasa a cincea proaspata (1.46/s), ca la inceput
# forja sa fie gatuirea fierului.
FORGE_BASE_RATE = 1.2
FORGE_UPGRADE_BASE = 60.0
LEVEL_INC_BY_KIND["forge"] = 0.06

# [D65] CLADIRILE EREI 2, in oglinda: turnatoria cat gaterul, cuptorul de cupru cat forja, Piata cat taverna (bucati pe
# secunda), iar nivelurile lor de ERA2_MULT ori mai scumpe.
FOUNDRY_BASE_RATE = 2.4
FOUNDRY_UPGRADE_BASE = 7.0 * ERA2_MULT
FURNACE_BASE_RATE = 1.2
FURNACE_UPGRADE_BASE = 60.0 * ERA2_MULT
MARKET_BASE_RATE = 3.0
MARKET_UPGRADE_BASE = 9.0 * ERA2_MULT
# [D67] CLADIRILE EREI 3, in oglinda cu ale Morii: Wire Works cat turnatoria, Power House cat cuptorul de cupru, Depoul
# cat Piata; nivelurile lor de ERA3_MULT ori mai scumpe.
WIREWORKS_BASE_RATE = 2.4
WIREWORKS_UPGRADE_BASE = 7.0 * ERA3_MULT
POWERHOUSE_BASE_RATE = 1.2
POWERHOUSE_UPGRADE_BASE = 60.0 * ERA3_MULT
DEPOT_BASE_RATE = 3.0
DEPOT_UPGRADE_BASE = 9.0 * ERA3_MULT
# [D70] CLADIRILE EREI 4 (plan, sectiunea 2): Switchyard-ul umple butoaiele din sarcina turbinei, Cable Works face cablul,
# Relay Station-ul le uneste (un butoi si o bucata de cablu fac o unitate de curent), Kiln-ul topeste cristalul, iar
# orasul (Switch House) cumpara. Relay-ul e mai iute decat Cable Works-ul, ca la startul barajului cablul sa tina unirea.
SWITCHYARD_BASE_RATE = 2.4
SWITCHYARD_UPGRADE_BASE = 7.0 * ERA4_MULT
CABLEWORKS_BASE_RATE = 2.0
CABLEWORKS_UPGRADE_BASE = 7.0 * ERA4_MULT
RELAY_BASE_RATE = 2.8
RELAY_UPGRADE_BASE = 8.0 * ERA4_MULT
KILN_BASE_RATE = 1.2
KILN_UPGRADE_BASE = 60.0 * ERA4_MULT
TOWN_BASE_RATE = 3.0
TOWN_UPGRADE_BASE = 9.0 * ERA4_MULT

# ---- oamenii [D49] ---------------------------------------------------------------------------
# FIECARE PAS E MUNCA DE OM. La inceput le faci tu pe toate; fiecare angajare iti ia un drum sau o
# statie de pe umeri, iar timpul tau se imparte intre ce a ramas. De-aici senzatia ca fiecare
# angajare grabeste TOT, nu doar pasul ei.
#
# TIMPUL TAU E 3.6, NU 1.2 (cat era caratul tau in D48). Cu 1.2 impartit la patru pasi, tu erai
# veriga slaba din prima secunda: 24 din 27 de cumparaturi din primele 5 minute nu dadeau nimic, iar
# nivelul plasei cerut de quest scria "No gain yet". In realitate e invers -- cu traista de 30 si
# viteza 320, plasa te limiteaza, nu picioarele. La 3.6 primele gatuiri sunt plasele, apoi gaterul.
PLAYER_LABOR = 3.6
# TREI MESERII CU ACEEASI VITEZA STAU LA EGALITATE. Cu toate la 3.0, o treapta pe una singura dadea
# zero pana le cumparai pe toate trei, iar "collect" iesea gatuire 78% din timp. Cifrele diferite
# rotesc gatuirea intre ele. Sawyer-ul si Negustorul n-au baza: inmultesc capacitatea cladirii lor.
# [D56] Oamenii de drum ai fierului au baze mai mici: plasa de scrap e una singura. Ultimul (Iron Hauler) trebuie
# sa duca macar cat tot timpul tau cu traista mare (5.4), altfel angajarea lui ar putea scadea venitul.
ROLE_BASE = {
    "collector": 4.0, "porter": 6.0, "hauler": 9.0, "scrapCollector": 2.0, "scrapPorter": 2.5, "ironHauler": 6.5,
    # [D65] oamenii de drum ai Erei 2, in oglinda cu ai Erei 1 (aceleasi bucati pe secunda)
    "millCollector": 4.0, "millPorter": 6.0, "partsHauler": 9.0, "oreCollector": 2.0, "orePorter": 2.5, "copperHauler": 6.5,
    # [D67] si ai Erei 3, in oglinda cu ai Morii
    "worksCollector": 4.0, "worksPorter": 6.0, "coilHauler": 9.0,
    "batteryCollector": 2.0, "batteryPorter": 2.5, "powerHauler": 6.5,
    # [D70] ai Erei 4 (plan, sectiunea 2): linia butoaielor (veteranii), a cablului, Pylon Runner-ul unirii, cristalul.
    # Cable Collector-ul la 4.0, nu 3.0: cu 3.0, venitul statea pe loc ~16 minute pe la minutul 29 (riscul 1; D70 Runda 5:
    # se repara din cifre). BAZE CARE NU SE EGALEAZA: pasii celor doua piese intra in ACELASI minim al unirii, deci doi
    # oameni cu aceeasi baza (sau cu produse egale pe trepte si oameni, 7.5 x 2 = 5.0 x 3) stau la egalitate, iar treapta
    # pe veriga aratata de joc da zero [verificator, 2026-09-30]. Bazele de aici n-au nicio egalitate intre ei (treapta x
    # oameni, 1-10) si cat mai putine cu cladirile Erei 4 (check_lines: `walker_ties`). Pylon Runner-ul, ultimul drum al
    # unirii, duce tot timpul tau (PLAYER_LABOR x SACK_BONUS) si la -15%, deci nu coboara sub 6.36 (check_hire_order).
    "damCollector": 4.7, "damPorter": 6.3, "barrelHauler": 7.3,
    "cableCollector": 4.0, "cablePorter": 5.4, "cableHauler": 6.7, "pylonRunner": 6.5,
    # Cristalul NU mai e in oglinda Erei 3 (Battery Collector 2.0 / Porter 2.5, compromisul D56): cu Kiln-ul devreme,
    # Collector-ul pe treapta 5 si Porter-ul pe treapta 4 (2.0 x 5 = 2.5 x 4) tineau linia la egalitate ~31 de minute
    # reale, iar orice cumparatura pe veriga aratata dadea zero [verificator, 2026-10-01]. In Erele 1-3 egalitatea tine
    # ~4 minute, la coada erei.
    "crystalCollector": 2.0, "crystalPorter": 2.7, "ingotHauler": 6.5,
}
TIER_STEP = 1.0  # fiecare treapta adauga inca o data baza: treapta 5 = de 5 ori
TIER_MAX = 5
TIER_COST_BASE = 25.0  # 25 / 75 / 225 / 675 -- fix, ca la ei uneltele unui om
TIER_COST_GROWTH = 3.0
SECOND_AT_TIER = 3  # al doilea om pe aceeasi treaba se deschide de la treapta asta
MAX_PEOPLE = 2  # in Era 1; "progresiv cu jocul" [owner, 2026-09-13]

ERA1_ROLES = ("collector", "porter", "sawyer", "hauler", "trader", "scrapCollector", "scrapPorter", "smelter", "ironHauler")
# [D65] Era 2, in aceeasi ordine: cei patru ai pieselor, negustorul Pietei, cei patru ai cuprului
ERA2_ROLES = ("millCollector", "millPorter", "founder", "partsHauler", "merchant", "oreCollector", "orePorter", "coppersmith", "copperHauler")
# [D67] Era 3, in aceeasi ordine: cei patru ai bobinelor, Clerk-ul Depoului, cei patru ai curentului
ERA3_ROLES = (
    "worksCollector", "worksPorter", "wiredrawer", "coilHauler", "clerk",
    "batteryCollector", "batteryPorter", "electrician", "powerHauler",
)
# [D70] Era 4: cei cinci veterani ai butoaielor (si Dispatcher-ul orasului, fostul hangiu), cei sase ai cablului si ai
# unirii (angajati in rafala, capitolul 10), cei patru ai cristalului
ERA4_ROLES = (
    "damCollector", "damPorter", "switchman", "barrelHauler", "dispatcher",
    "cableCollector", "cablePorter", "cablemaker", "cableHauler", "relayKeeper", "pylonRunner",
    "crystalCollector", "crystalPorter", "crystalsmith", "ingotHauler",
)
ROLES = ERA1_ROLES + ERA2_ROLES + ERA3_ROLES + ERA4_ROLES
ERA_ROLES = {1: ERA1_ROLES, 2: ERA2_ROLES, 3: ERA3_ROLES, 4: ERA4_ROLES}

# ---- liniile, ca date [D64] --------------------------------------------------------------------
# Pana la D64 motorul era scris de mana pentru exact doua linii, lemnul si fierul. Era 2 aduce linii de ACEEASI forma
# (plasa -> om care aduna -> magazie -> om care duce -> atelier -> om care duce -> vanzator), asa ca forma devine
# tabel, iar functiile de mai jos merg peste el. Planul pe pasi: docs/PLAN-MOTOR-N-LINII.md.
#   * Un pas e (rol, veriga, fel). `walk` = un drum: oamenii lui duc ROLE_BASE[rol]; fara om, partea ta din timp pe
#     linia aceea. `processor` = o cladire cu niveluri (PROCESSORS[veriga]): oamenii ei o tin pornita tot timpul; fara
#     ei merge doar cat stai tu langa ea.
#   * Pasii stau IN ORDINEA ANGAJARILOR (conditiile deblocarilor o impun, iar `check_hire_order` se bazeaza pe ea).
#     [D56] Fiecare linie are timpul tau intreg: in joc nu ai niciodata pasi de mana pe doua linii odata (oamenii
#     lemnului vin toti inaintea Forge), iar asa deschiderea unei linii nu poate scadea alta in nicio stare.
#   * `openFlag`: campul din State care deschide linia (None = deschisa de la inceput). O linie cu conditie mai cere
#     si o plasa de felul ei: fara plasa, n-are ce sa curga pe ea.
#   * CONSTANTELE SE TIN DUPA NUME, nu dupa valoare ("SAW_BASE_RATE", nu 2.4): `--robust` si tune_tycoon.py le schimba
#     in memorie DUPA import, iar o copie facuta aici ar ramane pe cifra veche, in tacere.
#   * LINE_ORDER e ordinea in care se aduna ORICE suma pe linii (virgula mobila: alta ordine ar muta ultimii biti ai
#     venitului) si in care se departajeaza verigile la egalitate. `priority` e ALTA ordine, a vanzatorului: cine ia
#     primul din capacitatea lui (marfa mai scumpa intai, vezi verificarea de la sfarsit). Azi sunt una inversul
#     celeilalte doar din intamplare, deci raman doua liste.
#   * [D70] CHEILE PENTRU UNIRE SI BARAJ, toate OPTIONALE (docs/PLAN-MOTOR-UNIRE.md). O linie fara ele se poarta exact
#     ca pana acum, iar liniile Erelor 1-3 nu poarta niciuna:
#       - `closeFlag`: campul din State care INCHIDE linia (barajul opreste satul vechi). Inchisa, livreaza 0, n-are
#         veriga, iar `options` nu mai vinde nimic de pe ea. Plasele, nivelurile si oamenii ei raman in State.
#       - `inputs`: linia e o UNIRE, cu reteta 1:1 (o bucata din fiecare piesa face o bucata). N-are plase (`netKind`):
#         intra in ea cat aduce cea mai inceata dintre piese.
#       - `into`: linia e o PIESA si merge in unirea numita, nu la un vanzator. Livreaza cat ia unirea de la ea.
#       - `value`: cheia din GOODS a bucatii livrate (obligatorie la o unire). Fara ea, media plasei (`AVG[netKind]`).
#       - `pool`: liniile cu acelasi `pool` IMPART timpul tau: pasii de mana ai tuturor liniilor deschise din bazin.
#         Fara `pool`, linia e bazinul ei, adica regula de pana acum [D56].
#       - `source`: REZERVATA curierului din Era 5 (plan, sectiunea 4); `derive_tables` o refuza pana atunci.
# [D70] Era 4 la coada, cu piesele inaintea unirii lor (ordine topologica: trecerea inainte le stie marginea)
LINE_ORDER = ("wood", "iron", "parts", "copper", "coils", "power", "barrels", "cable", "grid", "crystal")
ERA_LINES = {1: ("wood", "iron"), 2: ("parts", "copper"), 3: ("coils", "power"), 4: ("barrels", "cable", "grid", "crystal")}
LINES = {
    "wood": {
        "netKind": "wood", "openFlag": None, "seller": "dock", "closeFlag": "dam",
        "steps": (("collector", "collect", "walk"), ("porter", "port", "walk"),
                  ("sawyer", "saw", "processor"), ("hauler", "haul", "walk")),
    },
    "iron": {
        "netKind": "scrap", "openFlag": "workshop", "seller": "dock", "closeFlag": "dam",
        "steps": (("scrapCollector", "scrapCollect", "walk"), ("scrapPorter", "scrapPort", "walk"),
                  ("smelter", "forge", "processor"), ("ironHauler", "ironHaul", "walk")),
    },
    # [D65] Era 2: piesele de masini (roata de apa porneste turnatoria) si cuprul (cuptorul de cupru), la Piata
    "parts": {
        "netKind": "mill", "openFlag": "wheel", "seller": "market", "closeFlag": "dam",
        "steps": (("millCollector", "millCollect", "walk"), ("millPorter", "millPort", "walk"),
                  ("founder", "foundry", "processor"), ("partsHauler", "partsHaul", "walk")),
    },
    "copper": {
        "netKind": "ore", "openFlag": "furnace", "seller": "market", "closeFlag": "dam",
        "steps": (("oreCollector", "oreCollect", "walk"), ("orePorter", "orePort", "walk"),
                  ("coppersmith", "furnace", "processor"), ("copperHauler", "copperHaul", "walk")),
    },
    # [D67] Era 3: bobinele (masina cu abur porneste Wire Works) si curentul (Power House), la Depot
    "coils": {
        "netKind": "works", "openFlag": "steam", "seller": "depot", "closeFlag": "dam",
        "steps": (("worksCollector", "worksCollect", "walk"), ("worksPorter", "worksPort", "walk"),
                  ("wiredrawer", "wireworks", "processor"), ("coilHauler", "coilHaul", "walk")),
    },
    "power": {
        "netKind": "turbine", "openFlag": "powerhouse", "seller": "depot", "closeFlag": "dam",
        "steps": (("batteryCollector", "batteryCollect", "walk"), ("batteryPorter", "batteryPort", "walk"),
                  ("electrician", "powerhouse", "processor"), ("powerHauler", "powerHaul", "walk")),
    },
    # [D70] Era 4, „The Dam" (docs/PLAN-MOTOR-UNIRE.md): doua PIESE (butoaiele si cablul) si UNIREA lor (curentul pentru
    # oras), toate trei in bazinul barajului, plus cristalul la coada. Barajul le deschide si inchide liniile vechi
    # (`closeFlag` de mai sus). Veteranii lucreaza butoaiele; cablul il faci tu, pana vin cei sase (D70 Runda 5).
    "barrels": {
        "netKind": "dam", "openFlag": "dam", "into": "grid", "pool": "dam",
        "steps": (("damCollector", "damCollect", "walk"), ("damPorter", "damPort", "walk"),
                  ("switchman", "switchyard", "processor"), ("barrelHauler", "barrelHaul", "walk")),
    },
    "cable": {
        "netKind": "cable_ore", "openFlag": "dam", "into": "grid", "pool": "dam",
        "steps": (("cableCollector", "cableCollect", "walk"), ("cablePorter", "cablePort", "walk"),
                  ("cablemaker", "cableworks", "processor"), ("cableHauler", "cableHaul", "walk")),
    },
    # Pylon Runner-ul duce curentul pe podul cu stalpi pana la Switch House (D70 Runda 5: fiecare pas are omul lui)
    "grid": {
        "inputs": ("barrels", "cable"), "openFlag": "dam", "seller": "town", "value": "grid", "pool": "dam",
        "steps": (("relayKeeper", "relay", "processor"), ("pylonRunner", "pylonRun", "walk")),
    },
    "crystal": {
        "netKind": "crystal", "openFlag": "kiln", "seller": "town", "pool": "dam",
        "steps": (("crystalCollector", "crystalCollect", "walk"), ("crystalPorter", "crystalPort", "walk"),
                  ("crystalsmith", "kiln", "processor"), ("ingotHauler", "ingotHaul", "walk")),
    },
}
# Cladirile cu niveluri: numele constantei de baza si campul din State cu nivelul. Veriga e si felul din
# LEVEL_INC_BY_KIND.
PROCESSORS = {
    "saw": {"base": "SAW_BASE_RATE", "level": "saw_level"},
    "forge": {"base": "FORGE_BASE_RATE", "level": "forge_level"},
    "foundry": {"base": "FOUNDRY_BASE_RATE", "level": "foundry_level"},
    "furnace": {"base": "FURNACE_BASE_RATE", "level": "furnace_level"},
    "wireworks": {"base": "WIREWORKS_BASE_RATE", "level": "wireworks_level"},
    "powerhouse": {"base": "POWERHOUSE_BASE_RATE", "level": "powerhouse_level"},
    # [D70] Era 4
    "switchyard": {"base": "SWITCHYARD_BASE_RATE", "level": "switchyard_level"},
    "cableworks": {"base": "CABLEWORKS_BASE_RATE", "level": "cableworks_level"},
    "relay": {"base": "RELAY_BASE_RATE", "level": "relay_level"},
    "kiln": {"base": "KILN_BASE_RATE", "level": "kiln_level"},
}
# Vanzatorii: omul lor nu are baza, inmulteste capacitatea cladirii (fara el merge la NO_TRADER_FACTOR).
SELLERS = {
    "dock": {"role": "trader", "base": "DOCK_BASE_RATE", "level": "dock_level", "priority": ("iron", "wood")},
    "market": {"role": "merchant", "base": "MARKET_BASE_RATE", "level": "market_level", "priority": ("copper", "parts")},
    "depot": {"role": "clerk", "base": "DEPOT_BASE_RATE", "level": "depot_level", "priority": ("power", "coils")},
    # [D70] orasul (Switch House), cu Dispatcher-ul, fostul hangiu: cristalul intai, apoi curentul unit
    "town": {"role": "dispatcher", "base": "TOWN_BASE_RATE", "level": "town_level", "priority": ("crystal", "grid")},
}



def derive_tables(line_order, lines, sellers, roles):
    """Tabelele de lucru, DERIVATE din LINES / SELLERS ca sa nu existe doua liste care sa se desparta. Intoarce
    (LINE_STEPS, LINE_LINKS, LINE_OF_ROLE, LINK_OF, LINKS, NET_LINE, CONSUMER_OF, POOL_LINES) si pica pe un tabel care
    nu se leaga. E functie, nu cod de modul, pentru ca check_lines.py o cheama din nou dupa ce adauga linii de proba.
      NET_LINE     felul de plasa -> linia ei (doar liniile cu plase)
      CONSUMER_OF  piesa -> unirea in care merge [D70]
      POOL_LINES   linia -> liniile care impart timpul tau cu ea, in LINE_ORDER (fara `pool`: doar ea) [D70]"""
    # [D70] INVARIANTELE CHEILOR NOI (aceleasi le va verifica ChainMath.model)
    for i, line in enumerate(line_order):
        spec = lines[line]
        assert spec.get("source") is None, f"linia {line}: `source` e rezervata curierului din Era 5 [D70]"
        assert (spec.get("netKind") is None) != (spec.get("inputs") is None), (
            f"linia {line}: are exact una dintre `netKind` (plase) si `inputs` (unire)"
        )
        assert (spec.get("seller") is None) != (spec.get("into") is None), (
            f"linia {line}: are exact unul dintre `seller` si `into`"
        )
        if spec.get("inputs") is not None:
            assert spec.get("value") is not None, f"unirea {line} n-are `value`"
            assert len(spec["inputs"]) > 0, f"unirea {line} n-are piese"
            for part in spec["inputs"]:
                assert part in line_order and lines[part].get("into") == line, (
                    f"unirea {line}: piesa {part} nu merge in ea (`into`)"
                )
        if spec.get("into") is not None:
            consumer = spec["into"]
            assert consumer in line_order and line in (lines[consumer].get("inputs") or ()), (
                f"piesa {line}: nu sta in `inputs` ale unirii {consumer}"
            )
            assert i < line_order.index(consumer), f"piesa {line} sta dupa unirea ei ({consumer}) in LINE_ORDER"
    net_line = {}
    for line in line_order:
        kind = lines[line].get("netKind")
        if kind is not None:
            assert kind not in net_line, f"doua linii prind acelasi fel de plasa ({kind}): {net_line.get(kind)}, {line}"
            net_line[kind] = line
    consumer_of = {line: lines[line]["into"] for line in line_order if lines[line].get("into") is not None}

    def pool_of(line):
        pool = lines[line].get("pool")
        return ("pool", pool) if pool is not None else ("line", line)

    pool_lines = {line: tuple(other for other in line_order if pool_of(other) == pool_of(line)) for line in line_order}
    line_steps = {line: tuple(role for role, _link, _kind in lines[line]["steps"]) for line in line_order}
    line_links = {line: tuple(link for _role, link, _kind in lines[line]["steps"]) for line in line_order}
    line_of_role = {r: line for line, steps in line_steps.items() for r in steps}
    link_of = {role: link for line in line_order for role, link, _kind in lines[line]["steps"]}
    link_of.update({spec["role"]: seller for seller, spec in sellers.items()})
    # ORDINEA e contractul cu ChainMath.luau: la egalitate castiga veriga dinainte (Luau-ul compara cu `>` strict in
    # exact aceeasi ordine). [D56] Plasele, apoi liniile in LINE_ORDER, apoi vanzatorii.
    links = ("nets",) + tuple(link for line in line_order for link in line_links[line]) + tuple(sellers)
    assert set(roles) == set(link_of), "ROLES si LINES/SELLERS nu au aceiasi oameni"
    assert len(set(links)) == len(links), "o veriga apare de doua ori"
    for line in line_order:
        seller = lines[line].get("seller")
        if seller is not None:  # o piesa n-are vanzator: se vinde doar prin unirea ei
            assert line in sellers[seller]["priority"], f"linia {line} lipseste din randul vanzatorului ei"
    for seller, spec in sellers.items():
        # [D70] in randul unui vanzator stau doar linii care vand (nicio piesa)
        assert all(lines[l].get("seller") == seller for l in spec["priority"]), f"{seller}: o linie de-a altui vanzator"
    return line_steps, line_links, line_of_role, link_of, links, net_line, consumer_of, pool_lines


(
    LINE_STEPS, LINE_LINKS, LINE_OF_ROLE, LINK_OF, LINKS, NET_LINE, CONSUMER_OF, POOL_LINES,
) = derive_tables(LINE_ORDER, LINES, SELLERS, ROLES)
ROLE_NAMES = {
    "collector": "Collector", "porter": "Porter", "sawyer": "Sawyer", "hauler": "Hauler", "trader": "Innkeeper",
    "scrapCollector": "Scrap Collector", "scrapPorter": "Scrap Porter", "smelter": "Smelter", "ironHauler": "Iron Hauler",
    "millCollector": "Mill Collector", "millPorter": "Mill Porter", "founder": "Founder", "partsHauler": "Parts Hauler",
    "merchant": "Merchant", "oreCollector": "Ore Collector", "orePorter": "Ore Porter", "coppersmith": "Coppersmith",
    "copperHauler": "Copper Hauler",
    "worksCollector": "Works Collector", "worksPorter": "Works Porter", "wiredrawer": "Wiredrawer",
    "coilHauler": "Coil Hauler", "clerk": "Clerk", "batteryCollector": "Battery Collector",
    "batteryPorter": "Battery Porter", "electrician": "Electrician", "powerHauler": "Power Hauler",
    # [D70] Era 4 (numele sunt propuneri, plan §6 intrebarea 12)
    "damCollector": "Dam Collector", "damPorter": "Dam Porter", "switchman": "Switchman",
    "barrelHauler": "Barrel Hauler", "dispatcher": "Dispatcher", "cableCollector": "Cable Collector",
    "cablePorter": "Cable Porter", "cablemaker": "Cablemaker", "cableHauler": "Cable Hauler",
    "relayKeeper": "Relay Keeper", "pylonRunner": "Pylon Runner", "crystalCollector": "Crystal Collector",
    "crystalPorter": "Crystal Porter", "crystalsmith": "Crystalsmith", "ingotHauler": "Ingot Hauler",
}
# Verigile fiecarei ere (plasele sunt ale tuturor): portile si rapoartele unei ere se uita doar la ale ei.
ERA_LINKS = {
    era: ("nets",) + tuple(link for line in lines for link in LINE_LINKS[line])
    + tuple(seller for seller in SELLERS if any(LINES[line].get("seller") == seller for line in lines))
    for era, lines in ERA_LINES.items()
}


def net_lane(base_lane: int, level: int) -> int:
    """Pragurile duc plasa mai in larg: la nivel 10 o banda, la 25 inca una. Se VEDE pe ecran --
    plasa se muta si incepe sa prinda altceva -- nu e doar o cifra care creste."""
    extra = (1 if level >= 10 else 0) + (1 if level >= 25 else 0)
    return min(3, base_lane + extra)


@dataclass
class Net:
    base: float
    base_lane: int
    level: int = 1
    kind: str = "wood"
    # [D64] Costul de baza al nivelurilor, daca plasa si-l aduce singura (liniile de proba din check_lines.py). None =
    # regula jocului, dupa locul plasei: `net_upgrade_base`.
    upgrade_base: float = None

    def rate(self) -> float:
        return level_output(self.base, self.level)

    def lane(self) -> int:
        return net_lane(self.base_lane, self.level)


@dataclass
class Crew:
    count: int = 0
    tier: int = 1


@dataclass
class State:
    t: float = 0.0
    coins: float = 0.0
    nets: list = field(default_factory=list)
    crews: dict = field(default_factory=lambda: {r: Crew() for r in ROLES})
    dock_level: int = 1
    saw_level: int = 1
    sack_big: bool = False
    workshop: bool = False
    scrap_shed: bool = False
    forge_level: int = 1
    # [D65] Era 2: roata de apa (porneste turnatoria), cuptorul de cupru, magazia de minereu, nivelurile cladirilor ei
    wheel: bool = False
    furnace: bool = False
    ore_shed: bool = False
    foundry_level: int = 1
    furnace_level: int = 1
    market_level: int = 1
    # [D67] Era 3: masina cu abur (porneste Wire Works), Power House, magazia de baterii, nivelurile cladirilor ei
    steam: bool = False
    powerhouse: bool = False
    battery_shed: bool = False
    wireworks_level: int = 1
    powerhouse_level: int = 1
    depot_level: int = 1
    # [D70] Era 4: barajul (inchide liniile vechi, deschide butoaiele, cablul si unirea), Kiln-ul (porneste cristalul),
    # magazia de cristal, nivelurile cladirilor ei
    dam: bool = False
    kiln: bool = False
    crystal_shed: bool = False
    switchyard_level: int = 1
    cableworks_level: int = 1
    relay_level: int = 1
    kiln_level: int = 1
    town_level: int = 1
    price_mult: float = 1.0
    bells: float = 1.0
    index_found: int = 0
    rebirths: int = 0
    bought: set = field(default_factory=set)


def tier_mult(tier: int) -> float:
    return 1 + TIER_STEP * (tier - 1)


# [D64] Treptele costa fix (25 / 75 / 225 / 675) pentru oamenii Erei 1. Oamenii unei ere noi muta marfa de zeci de ori
# mai scumpa, deci si uneltele lor costa pe masura: rolul -> de cate ori. Gol = toti la 1 (Era 1, neschimbata).
# [D70] UNELTELE UNEI ERE pot costa mai mult decat cadrul ei (`ERA_TOOL_MULT`, lipsa = 1). Ale barajului costa dublu: cu
# suma de start (35T), la pretul cadrului colectorii ajungeau la treapta 5 pe la minutul 9-11, iar venitul crestea sub 10%
# timp de 23m16s (poarta cere cel mult cat in Erele 1-3). Jocul trebuie sa aiba acelasi factor, cu nume:
# StationConfig.TOOL_COST_MULT (check_config_constants il compara pe erele din configuratie).
ERA_TOOL_MULT = {4: 2.0}
ROLE_COST_MULT = {
    **{role: ERA2_MULT for role in ERA2_ROLES},
    **{role: ERA3_MULT for role in ERA3_ROLES},
    **{role: ERA_TOOL_MULT[4] * ERA4_MULT for role in ERA4_ROLES},
}


def tier_cost(tier: int, role: str = None) -> float:
    """Cat costa trecerea de la treapta `tier` la `tier + 1`."""
    return TIER_COST_BASE * TIER_COST_GROWTH ** (tier - 1) * ROLE_COST_MULT.get(role, 1.0)


def line_closed(s: State, line: str) -> bool:
    """[D70] Linia e INCHISA de campul ei `closeFlag` (barajul opreste satul vechi). Fara cheie, niciodata."""
    flag = LINES[line].get("closeFlag")
    return flag is not None and bool(getattr(s, flag))


def line_open(s: State, line: str) -> bool:
    """O linie fara conditie e deschisa de la inceput. Una cu conditie cere campul ei din State si o plasa de felul
    ei. [D56] Pana la oamenii ei, culesul si dusul sunt pasii tai de mana, ca turul de lemn din capitolul 1.
    [D70] Una inchisa (`closeFlag`) nu e deschisa, orice ar zice restul; o unire cere in loc de plasa toate piesele ei
    deschise."""
    spec = LINES[line]
    close = spec.get("closeFlag")  # `line_closed`, scris pe loc: e cea mai des chemata functie a simulatorului
    if close is not None and getattr(s, close):
        return False
    flag = spec.get("openFlag")
    if spec.get("inputs") is not None:
        return (flag is None or bool(getattr(s, flag))) and all(line_open(s, part) for part in spec["inputs"])
    if flag is None:
        return True
    kind = spec["netKind"]
    return bool(getattr(s, flag)) and any(n.kind == kind for n in s.nets)


def manual_steps(s: State, line: str = "wood", is_open: bool = None) -> int:
    """Cati pasi n-au inca om in BAZINUL liniei (0 cat linia e inchisa). [D70] Bazinul = liniile care impart timpul tau
    (`pool`): se numara pasii fara om ai tuturor liniilor DESCHISE din el. O linie fara `pool` e bazinul ei, deci
    socoteala e cea de pana acum: pasii ei fara om. `is_open`, daca apelantul stie deja daca linia e deschisa."""
    if not (line_open(s, line) if is_open is None else is_open):
        return 0
    pool = POOL_LINES[line]
    if len(pool) == 1:  # acelasi rezultat ca mai jos, fara intrebarile despre celelalte linii (Erele 1-3)
        return sum(1 for r in LINE_STEPS[line] if s.crews[r].count == 0)
    return sum(
        1
        for other in pool
        if other == line or line_open(s, other)
        for r in LINE_STEPS[other]
        if s.crews[r].count == 0
    )


# [D70] CAT LIPSESTI (AWAY): pasii fara om nu merg, nici drumurile tale, nici cladirea langa care ai sta, iar vanzatorul
# fara omul lui nu vinde, ca `idleOnly` din ChainMath.luau (ce plateste offline-ul). `away_income` il pune doar cat
# socoteste; altfel e fals si nimic nu se schimba.
AWAY = False


def player_share(s: State, line: str, n: int = None) -> float:
    """Partea ta din timp pe fiecare pas fara om al liniei; 0 cand linia n-are pasi de mana. [D70] Timpul se imparte
    pe tot bazinul liniei (`manual_steps`; `n`, daca apelantul l-a socotit deja). Cat lipsesti (AWAY), 0."""
    if AWAY:
        return 0.0
    if n is None:
        n = manual_steps(s, line)
    if n == 0:
        return 0.0
    labor = PLAYER_LABOR * (SACK_BONUS if s.sack_big else 1.0)
    return labor / n


def walk_rate(s: State, role: str, n: int = None) -> float:
    """Un pas de drum: oamenii lui, sau partea ta din timp pe linia lui (`n` ca la `player_share`)."""
    crew = s.crews[role]
    if crew.count > 0:
        return ROLE_BASE[role] * tier_mult(crew.tier) * crew.count
    return player_share(s, LINE_OF_ROLE[role], n)


def processor_rate(s: State, line: str, role: str, link: str, n: int = None, is_open: bool = None) -> float:
    """O cladire cu niveluri (gaterul [D48], forja [D56]): oamenii ei o tin pornita tot timpul; fara ei merge doar cat
    stai tu langa ea (partea ei din pasii de mana ai bazinului [D70]). Cat linia e inchisa, nimic. Constanta de baza se
    citeste dupa nume, la fiecare apel. `n` si `is_open`, daca apelantul le-a socotit deja."""
    if not (line_open(s, line) if is_open is None else is_open):
        return 0.0
    spec = PROCESSORS[link]
    cap = level_output(globals()[spec["base"]], getattr(s, spec["level"]), link)
    crew = s.crews[role]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    if AWAY:
        return 0.0
    return cap / (manual_steps(s, line) if n is None else n)


def seller_rate(s: State, seller: str) -> float:
    """Un vanzator (taverna): singurul pas pe care NU-l faci tu. Fara omul lui vinde si singur, incet."""
    spec = SELLERS[seller]
    cap = level_output(globals()[spec["base"]], getattr(s, spec["level"]), seller)
    crew = s.crews[spec["role"]]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    if AWAY:
        return 0.0  # [D70] cat lipsesti, fara omul lui nu vinde (idleOnly din ChainMath)
    return cap * NO_TRADER_FACTOR


def line_avg(line: str) -> float:
    """Cat valoreaza, in medie, o bucata livrata pe linia asta. [D70] Cu `value`, bucata din GOODS (o unire o are
    mereu: n-are plase); fara, media plasei ei."""
    spec = LINES[line]
    value = spec.get("value")
    if value is not None:
        return GOODS[value]
    return AVG[spec["netKind"]]


@dataclass
class LineFlow:
    """Ce curge pe o linie, pe secunda."""
    catch: float  # cat prind plasele ei (0 cat linia e inchisa; 0 la o unire: plasele sunt doar ale liniilor de plase)
    rates: tuple  # ((veriga, debit), ...) in ordinea pasilor, fara plase
    own_max: float  # marginea liniei inaintea vanzatorului: minimul dintre ce intra (`supply`) si pasi
    active: bool  # intra in socoteala verigilor: mereu pentru o linie fara conditie, altfel doar cat intra ceva
    supply: float  # [D70] ce intra pe linie: plasele ei, sau la o unire cat aduce cea mai inceata piesa
    inputs: tuple  # [D70] piesele unei uniri (gol la o linie de plase)
    is_open: bool  # [D70] linia e deschisa (`line_open`): la o unire, si toate piesele ei
    room: float = 0.0  # cat mai avea vanzatorul cand i-a venit randul
    delivered: float = 0.0  # bucati livrate (la o piesa: cate ia unirea de la ea)
    by_seller: bool = False  # vanzatorul e marginea liniei
    bottleneck: str = ""  # veriga slaba a liniei ("" cat nu e activa)
    # [D70] piesele: tinute de unire, si a cui e veriga
    by_consumer: bool = False  # piesa e tinuta de unirea ei: unirea ia mai putin decat poate aduce piesa
    held_by: str = ""  # linia careia ii apartine veriga slaba ("" cat nu e activa)

    def links(self) -> tuple:
        """Toate verigile liniei, cu plasele in fata: ordinea in care se cauta primul minim. [D70] O unire n-are plase:
        in locul lor stau piesele (`supply`), socotite separat."""
        if self.inputs:
            return self.rates
        return (("nets", self.catch),) + self.rates


class Chain:
    """Lantul intreg. `lines` si `capacity` sunt adevarul; numele plate de mai jos (wood_catch, sawing, sales, ...) sunt
    VEDEREA Erei 1 peste ele: asa le citesc golden_chain.py (tabelul de aur din tests/ChainMath.test.luau) si raportul
    `--chain`. O linie noua nu primeste nume plat: se citeste din `lines`."""

    def __init__(self, lines: dict, capacity: dict):
        self.lines = lines  # {linie: LineFlow}
        self.capacity = capacity  # {vanzator: bucati pe secunda}
        self.bottleneck = "nets"  # veriga care tine venitul
        # [D70] ale cui plase tin venitul, cand veriga e "nets" (plasele sunt ale tuturor liniilor; "" altfel)
        self.nets_line = ""
        self.gains = {}  # [D70] castigul unei bucati in plus pe fiecare veriga (0 = "No gain yet"), din `bottlenecks`
        # [D70] verigile cu castig SINGURE: o bucata in plus doar pe ele aduce bani. La egalitate, `gains` le da castig
        # tuturor celor egale, dar fiecare singura da zero, iar jocul scrie "No gain yet" (ChainMath.gainOf, HeldBack).
        self.solo = set()

    def rate(self, line: str, link: str) -> float:
        return dict(self.lines[line].rates)[link]

    wood_catch = property(lambda self: self.lines["wood"].catch)
    scrap_catch = property(lambda self: self.lines["iron"].catch)  # 0 cat linia fierului e inchisa
    collect = property(lambda self: self.rate("wood", "collect"))
    port = property(lambda self: self.rate("wood", "port"))
    sawing = property(lambda self: self.rate("wood", "saw"))
    haul = property(lambda self: self.rate("wood", "haul"))
    scrap_collect = property(lambda self: self.rate("iron", "scrapCollect"))
    scrap_port = property(lambda self: self.rate("iron", "scrapPort"))
    forging = property(lambda self: self.rate("iron", "forge"))
    iron_haul = property(lambda self: self.rate("iron", "ironHaul"))
    sales = property(lambda self: self.capacity["dock"])
    wood = property(lambda self: self.lines["wood"].delivered)  # bucati de lemn livrate pe secunda
    scrap = property(lambda self: self.lines["iron"].delivered)  # bucati de fier livrate (scrap-ul topit)
    wood_bottleneck = property(lambda self: self.lines["wood"].bottleneck)
    iron_bottleneck = property(lambda self: self.lines["iron"].bottleneck)  # "" cat linia fierului e inchisa


def bottlenecks(c: Chain) -> str:
    """Scrie veriga slaba a fiecarei linii si intoarce veriga care tine venitul [D56].

    Veriga care tine venitul: cea al carei pas in plus ar aduce cei mai multi bani pe bucata, in ordinea LINKS la
    egalitate. O veriga "tine" o linie cand valoarea ei e chiar ce livreaza linia (min-ul exact):
      * o linie tinuta de o veriga a ei -> valoarea bucatii ei. Daca insa vanzatorul e plin, bucata in plus ia locul
        uneia de pe PRIMA linie de dupa ea (in randul vanzatorului) pe care o tine vanzatorul, deci doar diferenta.
        Cu lemnul si fierul: 1.65 pentru lemn; 3.55 pentru fier, sau 3.55 - 1.65 cand taverna e plina;
      * vanzatorul, cand el e marginea: ce ar mai vinde, adica bucata primei linii tinute de el.
    Veriga slaba a unei linii: primul minim din linie (plasele ei, oamenii, cladirea), sau vanzatorul cand el e
    marginea ei. Fara linia fierului iese PRIMUL minim din cele sase -- regula de dinainte [D49].

    Trei sau mai multe linii la acelasi vanzator nu exista inca nicaieri: regula "prima linie tinuta de dupa ea" e
    exacta pentru doua. Inainte de a treia, intai teste socotite de mana (docs/PLAN-MOTOR-N-LINII.md).

    [D70] UNIREA. Castigul unei bucati in plus pe o linie ajunge la verigile ei prin `credit`: fiecare veriga cu debitul
    egal cu ce livreaza linia il primeste (ca maxim), iar la o unire tinuta de piese (`supply` == livrat) il primeste si
    fiecare piesa cu marginea egala, mai departe prin verigile ei. La egalitate intre piese, il primesc amandoua (si
    fiecare singura da zero: e cinstit [D46], iar ecranul numeste linia cealalta). Veriga unei linii: "" daca e
    inactiva; vanzatorul, daca el e marginea; veriga unirii, daca piesa e tinuta de unirea ei (cat unirea nu merge
    inca, plasa piesei care lipseste); altfel primul minim al ei (`own_first`), care la o unire tinuta de piese e al
    primei piese, in ordinea din `inputs`, care o tine.
    `held_by` spune a cui e veriga, iar `Chain.nets_line` ale cui plase, cand venitul il tin plasele."""
    gains = {link: 0.0 for link in LINKS}
    nets_gain = {}  # [D70] linia -> castigul dus de plasele ei
    solo = set()

    def credit(line, x, g):
        f = c.lines[line]
        for link, value in f.links():
            if value == x:
                gains[link] = max(gains[link], g)
                if link == "nets":
                    nets_gain[line] = max(nets_gain.get(line, 0.0), g)
        if f.inputs and f.supply == x:
            for part in f.inputs:
                if c.lines[part].own_max == x:
                    credit(part, x, g)

    def credit_solo(line, x):
        """Ca `credit`, dar doar cand minimul e al unui singur lucru (o veriga, sau o piesa la unire): altfel nimeni."""
        f = c.lines[line]
        tied = [link for link, value in f.links() if value == x]
        parts = [part for part in f.inputs if c.lines[part].own_max == x] if f.inputs and f.supply == x else []
        if len(tied) + len(parts) != 1:
            return
        if tied:
            solo.add(tied[0])
        else:
            credit_solo(parts[0], x)

    for seller, spec in SELLERS.items():
        order = spec["priority"]
        for i, line in enumerate(order):
            f = c.lines[line]
            if not f.active or f.by_seller:
                continue
            displaced = next((other for other in order[i + 1:] if c.lines[other].by_seller), None)
            gain = line_avg(line) if displaced is None else line_avg(line) - line_avg(displaced)
            credit(line, f.delivered, gain)
            if gain > 0.0:
                credit_solo(line, f.delivered)
        held = next((line for line in order if c.lines[line].by_seller), None)
        if held is not None:
            gains[seller] = line_avg(held)
            if gains[seller] > 0.0:
                solo.add(seller)
    best = "nets"
    for link in LINKS:
        if gains[link] > gains[best]:
            best = link
    c.gains = gains
    c.solo = solo
    if best == "nets" and gains["nets"] > 0.0:
        c.nets_line = next(line for line in LINE_ORDER if nets_gain.get(line, 0.0) == gains["nets"])

    def own_first(line):
        """(veriga, linia ei): primul minim al liniei; la o unire tinuta de piese, al primei piese care o tine."""
        f = c.lines[line]
        if f.inputs and f.supply == f.own_max:
            return own_first(next(part for part in f.inputs if c.lines[part].own_max == f.supply))
        return next(link for link, value in f.links() if value == f.own_max), line

    # in LINE_ORDER inversat: unirea isi stie veriga inaintea pieselor care o mostenesc
    for line in reversed(LINE_ORDER):
        f = c.lines[line]
        if not f.active:
            f.bottleneck, f.held_by = "", ""
        elif f.by_seller:
            f.bottleneck, f.held_by = LINES[line]["seller"], line
        elif f.by_consumer:
            consumer = c.lines[LINES[line]["into"]]
            if consumer.active:
                f.bottleneck, f.held_by = consumer.bottleneck, consumer.held_by
            else:
                # [D70] Unirea nu merge inca: ii lipseste o piesa (turbina fara plasa de cablu). Piesa asta asteapta
                # dupa plasa celeilalte, nu dupa nimic [D43]: ecranul spune "cast the Cable Net first"
                # (Strings.lineNotOpen). Daca nu lipseste nicio piesa (unirea e oprita de campul ei), veriga ramane ""
                # si o prinde `silent_lines` in cronologie.
                missing = next((part for part in consumer.inputs if not c.lines[part].is_open), None)
                f.bottleneck, f.held_by = ("nets", missing) if missing is not None else ("", "")
        else:
            f.bottleneck, f.held_by = own_first(line)
    return best


def chain(s: State) -> Chain:
    """Liniile [D49, D56]: fiecare cu oamenii ei; cele care au acelasi vanzator impart doar capacitatea lui. El vinde
    in ordinea din `priority` (intai marfa mai scumpa) cat poate aduce fiecare linie, iar urmatoarea ia restul. Orice
    capacitate in plus doar largeste ce se poate, deci nicio cumparatura nu scade venitul.

    [D70] TREI TRECERI. Inainte, in LINE_ORDER (piesele stau inaintea unirii lor): ce intra pe fiecare linie (plasele
    ei, sau la o unire cat aduce cea mai inceata piesa) si marginea ei. Apoi vanzatorii, neschimbati. Inapoi, in
    LINE_ORDER inversat: o piesa livreaza cat ia unirea ei, si e tinuta de ea cand ar putea aduce mai mult. Fara piese
    (Erele 1-3), a treia trecere nu atinge nimic, iar `supply` e chiar `catch`."""
    lines = {}
    for line in LINE_ORDER:
        spec = LINES[line]
        is_open = line_open(s, line)
        manual = manual_steps(s, line, is_open)  # o data pe linie, nu la fiecare pas de mana
        inputs = spec.get("inputs") or ()
        catch = 0.0
        if is_open and not inputs:
            for n in s.nets:
                if n.kind == spec["netKind"]:
                    catch += n.rate()
        rates = tuple(
            (link, walk_rate(s, role, manual) if kind == "walk" else processor_rate(s, line, role, link, manual, is_open))
            for role, link, kind in spec["steps"]
        )
        if inputs:
            supply = min(lines[part].own_max for part in inputs) if is_open else 0.0
        else:
            supply = catch
        own_max = min([supply] + [value for _link, value in rates])
        active = is_open and (spec.get("openFlag") is None or supply > 0.0)
        lines[line] = LineFlow(catch, rates, own_max, active, supply, inputs, is_open)
    capacity = {}
    for seller, spec in SELLERS.items():
        capacity[seller] = seller_rate(s, seller)
        room = capacity[seller]
        for line in spec["priority"]:
            f = lines[line]
            f.room = room
            f.delivered = min(f.own_max, room)
            f.by_seller = f.active and f.delivered == room and f.delivered < f.own_max
            room = room - f.delivered
    if CONSUMER_OF:  # fara piese (Erele 1-3) nu e nimic de dus inapoi
        for line in reversed(LINE_ORDER):
            consumer = CONSUMER_OF.get(line)
            if consumer is None:
                continue
            f = lines[line]
            f.delivered = lines[consumer].delivered
            f.by_consumer = f.active and f.delivered < f.own_max
    c = Chain(lines, capacity)
    c.bottleneck = bottlenecks(c)
    return c


def silent_lines(c: Chain) -> list:
    """[D70] Liniile ACTIVE fara veriga slaba. Contractul lui LineFlow e ca "" inseamna "linia nu e activa"; o linie
    activa fara veriga ar lasa ecranul fara niciun motiv [D43]. `run` se opreste daca apare in cronologie."""
    return [line for line in LINE_ORDER if c.lines[line].active and not c.lines[line].bottleneck]


def income(s: State) -> float:
    c = chain(s)
    gross = 0.0
    for line in LINE_ORDER:  # ordine fixa: aceeasi suma, bit cu bit, la fiecare rulare si in ChainMath.luau
        if line in CONSUMER_OF:
            continue  # [D70] o piesa nu se vinde: bucata ei intra in venit doar prin unire
        gross += c.lines[line].delivered * line_avg(line)
    return (
        gross
        * s.price_mult
        * s.bells
        * (1 + 0.01 * s.index_found)
        * (1 + 0.5 * s.rebirths)
    )


def away_income(s: State) -> float:
    """[D70] Venitul cat lipsesti: doar pasii cu om, si vanzatorii cu omul lor."""
    global AWAY
    AWAY = True
    try:
        return income(s)
    finally:
        AWAY = False


# ---- deblocarile ------------------------------------------------------------------------------
# Fiecare are un MOTIV: C=prinzi mai mult, V=vinzi mai scump, A=scapi de o corvoada, D=deschizi.


def net_base(k: int) -> float:
    """Baza plasei k (de la 1): a k-a plasa a unei ere are baza celei de-a k-a plase a Erei 1 [D65]."""
    return NET_BASE_RATE * NET_BASE_GROWTH ** ((k - 1) % NETS_PER_ERA)


def era_mult(era: int) -> float:
    """[D67] Cadrul unei ere: 1 in Era 1, apoi ERA2_MULT, ERA3_MULT... Se citeste dupa nume la fiecare apel (uneltele
    de „ce-ar fi daca" il schimba in memorie)."""
    return 1.0 if era == 1 else globals()[f"ERA{era}_MULT"]


def net_era_mult(k: int) -> float:
    """De cate ori costa mai mult nivelurile plasei k (de la 1): cadrul erei in care sta plasa."""
    return era_mult((k - 1) // NETS_PER_ERA + 1)


def unlock_net(k: int):
    def f(s: State):
        s.nets.append(Net(net_base(k), NET_LANES[k - 1], kind=NET_KINDS[k - 1]))

    return f


def unlock_net_ranked(kind: str, rank: int, lane: int, era: int):
    """[D70] O plasa cu RANG explicit, nu cu loc in lista: de la Era 4, turbinele barajului si plasele de cablu se
    cumpara amestecat, deci locul in `s.nets` nu mai spune cat de mare e plasa. Rangul r are baza si costul
    nivelurilor celei de-a r-a plase dintr-o era (`net_base`, `net_upgrade_base`), iar costul se inmulteste cu cadrul
    erei `era`. Aceleasi operatii, in aceeasi ordine: rangul 5 al Erei 3 e bit cu bit First Turbine (check_lines.py).
    Constantele se citesc dupa nume, in clipa cumpararii."""

    def f(s: State):
        grown = NET_BASE_GROWTH ** (rank - 1)
        s.nets.append(
            Net(
                NET_BASE_RATE * grown,
                lane,
                kind=kind,
                upgrade_base=NET_UPGRADE_BASE_COST * grown * era_mult(era),
            )
        )

    return f


def people(s: State, role: str) -> int:
    return s.crews[role].count


def hire(role: str):
    def f(s: State):
        s.crews[role].count += 1

    return f


def unlock_sack(s: State):
    s.sack_big = True


def unlock_workshop(s: State):
    """Forge (id-ul vechi `workshop`) [D56]. Pana la D56 atelierul mai dadea +6 la colectie (bonusul gasirilor
    reparate); colectia s-a pus deoparte, deci forja da doar ce topeste."""
    s.workshop = True


def unlock_shed(s: State):
    s.scrap_shed = True


def unlock_bell(s: State):
    s.bells *= 1.10


# DEBLOCARILE NU SUNT O COADA FIXA. Prima varianta le tinea intr-o singura lista ordonata, si
# atunci jucatorul era obligat sa cumpere a treia plasa (care nu-i folosea la nimic) inainte sa
# poata angaja prima Mana. Deci: plasele curg in ordine, restul se deschid cand li se implineste
# conditia. OAMENII vin in ordinea raului [D49]: fiecare angajare scoate la iveala pasul urmator ca
# pe noua corvoada, deci cel dinainte e o conditie fireasca, nu o piedica.
# TOTI CINCI, IMEDIAT DUPA PRIMA VANZARE, ABIA APOI PLASELE [D52]. Owner-ul: "o singura data un tur
# net - sawmill - tavern iar al doilea tur sa isi deblocheze treptat npc-urile". Collector-ul cere
# deci o singura plasa (banii vin oricum doar din vanzare), Innkeeper-ul vine dupa Hauler, iar plasa a
# doua asteapta Innkeeper-ul. Lista e in ordinea platformelor din TycoonConfig.
#
#   (id, nume, motiv, conditie, efect)
PREV_NET_LEVEL = 2
# Plasa urmatoare cere ca cea DINAINTE sa fie cel putin la nivelul asta [owner, 2026-09-12: "vreau ca
# plasa sa ceara lv2 si apoi sa apara si a doua plasa de lv1, si tot asa pana la ultima plasa"].
# Aceeasi cifra sta in TycoonConfig (`needs.prevNetLevel`) si in quest-ul `net_two`; testul
# QuestConfig verifica sa nu se desparta.


def prev_net_ready(s) -> bool:
    return len(s.nets) == 0 or s.nets[-1].level >= PREV_NET_LEVEL


ERA1_UNLOCKS = [
    ("net1", "First Net", "C", lambda s: len(s.nets) == 0, unlock_net(1)),
    ("collector", "Collector", "A", lambda s: len(s.nets) >= 1 and people(s, "collector") == 0, hire("collector")),
    ("porter", "Porter", "A", lambda s: people(s, "collector") >= 1 and people(s, "porter") == 0, hire("porter")),
    ("sawyer", "Sawyer", "A", lambda s: people(s, "porter") >= 1 and people(s, "sawyer") == 0, hire("sawyer")),
    ("hauler", "Hauler", "A", lambda s: people(s, "sawyer") >= 1 and people(s, "hauler") == 0, hire("hauler")),
    ("trader", "Innkeeper", "A", lambda s: people(s, "hauler") >= 1 and people(s, "trader") == 0, hire("trader")),
    (
        "net2",
        "Second Net",
        "C",
        lambda s: len(s.nets) == 1 and prev_net_ready(s) and people(s, "trader") >= 1,
        unlock_net(2),
    ),
    ("net3", "Third Net", "C", lambda s: len(s.nets) == 2 and prev_net_ready(s), unlock_net(3)),
    ("sack", "Bigger Sack", "A", lambda s: len(s.nets) >= 2 and not s.sack_big, unlock_sack),
    ("net4", "Fourth Net", "C", lambda s: len(s.nets) == 3 and prev_net_ready(s), unlock_net(4)),
    # [D56] LINIA FIERULUI, ca un capitol 1 al ei: forja, plasa care aduce scrap (turul de mana), shed-ul, apoi cei
    # patru oameni la rand, in ordinea raului (Scrap Collector, Scrap Porter, Smelter, Iron Hauler).
    ("workshop", "Forge", "V", lambda s: len(s.nets) >= 4 and not s.workshop, unlock_workshop),
    ("net5", "Fifth Net", "C", lambda s: len(s.nets) == 4 and prev_net_ready(s) and s.workshop, unlock_net(5)),
    ("shed", "Scrap Shed", "V", lambda s: len(s.nets) == 5 and not s.scrap_shed, unlock_shed),
    (
        "scrapCollector",
        "Scrap Collector",
        "A",
        lambda s: s.scrap_shed and people(s, "scrapCollector") == 0,
        hire("scrapCollector"),
    ),
    (
        "scrapPorter",
        "Scrap Porter",
        "A",
        lambda s: people(s, "scrapCollector") >= 1 and people(s, "scrapPorter") == 0,
        hire("scrapPorter"),
    ),
    ("smelter", "Smelter", "A", lambda s: people(s, "scrapPorter") >= 1 and people(s, "smelter") == 0, hire("smelter")),
    (
        "ironHauler",
        "Iron Hauler",
        "A",
        lambda s: people(s, "smelter") >= 1 and people(s, "ironHauler") == 0,
        hire("ironHauler"),
    ),
]
# Al doilea om pe fiecare meserie: se cumpara din meniul omului, nu de pe o platforma.
for _role in ERA1_ROLES:
    ERA1_UNLOCKS.append(
        (
            f"{_role}2",
            f"Second {ROLE_NAMES[_role]}",
            "A",
            (lambda s, r=_role: people(s, r) == 1 and s.crews[r].tier >= SECOND_AT_TIER),
            hire(_role),
        )
    )
# clopotul incheie era: cere TOT restul cumparat -- cate un om pe fiecare meserie (si ale fierului), nu doi
ERA1_UNLOCKS.append(
    (
        "bell",
        "Landing Bell",
        "D",
        lambda s: len(s.nets) == 5
        and all(people(s, r) >= 1 for r in ERA1_ROLES)
        and s.sack_big
        and s.workshop
        and s.scrap_shed,
        unlock_bell,
    )
)

# Oamenii ceruti de capitolul 1, in ordinea quest-urilor [D52]. `run` ii ia inaintea oricarei alte
# cumparaturi; aceeasi ordine sta in QuestConfig (capitolul 1) si in TycoonConfig.PADS.
CHAPTER1_HIRES = ("collector", "porter", "sawyer", "hauler", "trader")
# [D55] Deblocari fara castig propriu pe care le cere un quest, in ordinea quest-urilor, cu pasul dupa care
# le cere: traista mare dupa a treia plasa ("Get a Bigger Sack"). Fara ele lacomul le lua doar din intamplare:
# cu toti oamenii angajati traista nu mai aduce nimic, iar clopotul o cere -- intr-o varianta din --robust Era 1
# ajungea la 1h40m pentru o traista de 80 de monede.
# [D56] Si linia fierului, pas cu pas, cum o cere capitolul 3: forja singura nu aduce nimic (n-are ce topi),
# plasa a cincea aduce doar cat faci tu turul, shed-ul nimic, iar oamenii fierului putin fiecare -- un om le ia pe
# rand, pentru ca asa scrie in quest, nu pentru ca fiecare ar fi cel mai bun pe moneda.
QUEST_UNLOCKS = (
    ("sack", lambda s: len(s.nets) >= 3),
    ("workshop", lambda s: len(s.nets) >= 4 and s.nets[3].level >= PREV_NET_LEVEL),
    ("net5", lambda s: True),
    ("shed", lambda s: True),
    ("scrapCollector", lambda s: True),
    ("scrapPorter", lambda s: True),
    ("smelter", lambda s: True),
    ("ironHauler", lambda s: True),
)

# [D56] OAMENII FIERULUI VIN IN RAFALA, ca oamenii capitolului 1 [D52]: pretul lor e atatea secunde de venit din
# clipa in care se deschid, nu treapta urmatoare de pe scara deblocarilor, si nu trebuie sa coste mai mult decat
# ce s-a deschis inainte (podeaua lui `nice`). Pe scara, patru angajari la rand ar fi impins clopotul cu
# 1.17^4 mai departe (Era 1 peste o ora), pentru niste oameni care fac doar sa mearga o linie deja cumparata.
# Shed-ul vine cu ei: e locul in care lasa Scrap Collector-ul.
# [D62] RAFALA SCURTA: erau 45-60 de secunde de venit fiecare, adica ~1m30s reale de strans pentru o cumparatura care
# aduce 0-3% (linia fierului incepe sa plateasca abia cand are toti oamenii si i se urca nivelurile). Cinci la rand
# faceau, cu forja si plasa a cincea dinainte, 14 minute in care venitul crestea cu 7%. Acum oamenii fierului vin la
# ~25 de secunde reale unul de altul, iar nivelurile fierului (saltul de +80%) vin imediat dupa ei.
BURST_WAIT = {"shed": 12.0, "scrapCollector": 12.0, "scrapPorter": 14.0, "smelter": 16.0, "ironHauler": 18.0}
# [D62] SI OAMENII CAPITOLULUI 1 VIN IN RAFALA. Owner-ul a cerut in D52 ca "al doilea tur sa isi deblocheze treptat
# npc-urile"; pe scara deblocarilor ieseau insa la 41 / 49 / 59 / 67 / 83 de secunde reale unul de altul, pe un venit
# care nu se misca deloc (cu o singura plasa, plasa e veriga slaba: un om adauga zero). Adica primele cinci minute
# ale jocului erau cinci asteptari tot mai lungi pentru cinci cumparaturi care nu cresc nimic. Acum costa cateva
# secunde de venit fiecare: prima vanzare (12 monede) ii plateste pe primii doi pe loc, iar toti cinci sunt angajati
# in ~2 minute reale. Scara porneste de unde ajunsese dupa ei (`LADDER_START`), deci restul preturilor nu se schimba.
BURST_WAIT.update({"collector": 9.0, "porter": 11.0, "sawyer": 13.0, "hauler": 15.0, "trader": 18.0})

# uid -> pe ce veriga apasa deblocarea (pentru cazul in care nimic nu da castig imediat)
UNLOCK_STAGE = {
    "net1": "nets", "net2": "nets", "net3": "nets", "net4": "nets", "net5": "nets",
    "sack": "collect", "collector": "collect", "porter": "port", "sawyer": "saw", "hauler": "haul",
    "trader": "dock", "workshop": "forge", "bell": "dock", "shed": "scrapCollect",
    "scrapCollector": "scrapCollect", "scrapPorter": "scrapPort", "smelter": "forge", "ironHauler": "ironHaul",
}
for _role in ROLES:
    UNLOCK_STAGE[f"{_role}2"] = LINK_OF[_role]
UNLOCK_STAGE.update({
    "wheel": "foundry", "net6": "nets", "net7": "nets", "net8": "nets", "net9": "nets", "net10": "nets",
    "furnace": "furnace", "oreShed": "oreCollect", "bell2": "market",
    **{_role: LINK_OF[_role] for _role in ERA2_ROLES},
    # [D67] Era 3
    "steam": "wireworks", "net11": "nets", "net12": "nets", "net13": "nets", "net14": "nets", "net15": "nets",
    "powerhouse": "powerhouse", "batteryShed": "batteryCollect", "bell3": "depot",
    **{_role: LINK_OF[_role] for _role in ERA3_ROLES},
    # [D70] Era 4
    "cableNet2": "nets", "cableNet3": "nets", "crystalNet": "nets",
    "kiln": "kiln", "crystalShed": "crystalCollect", "bell4": "town",
    **{_role: LINK_OF[_role] for _role in ERA4_ROLES},
})


# CE NU URCA SCARA DE ASTEPTARE. `target_wait(k)` a fost calibrat pe deblocarile Erei 1: fiecare
# treapta face urmatoarea deblocare de 1.17 ori mai departe. In D48 Sawyer-ul era scutit -- un om
# care facea sa mearga o veriga existenta. In D49 angajarile SUNT deblocarile erei (cinci din cele
# treisprezece), deci urca scara: scutite, Era 1 scadea la 21 de minute reale. Al doilea om ramane
# scutit -- e o marire a unei meserii pe care o ai deja, nu o extindere.
# [D65] Oamenii Erei 2 vin in aceeasi rafala ca oglinda lor din Era 1 (aceleasi secunde de venit), si magazia la fel.
ERA2_MIRROR = dict(zip(ERA2_ROLES, ERA1_ROLES))
BURST_WAIT.update({_role: BURST_WAIT[ERA2_MIRROR[_role]] for _role in ERA2_ROLES})
BURST_WAIT["oreShed"] = BURST_WAIT["shed"]
# [D67] si ai Erei 3, ca oglinda lor din Moara
ERA3_MIRROR = dict(zip(ERA3_ROLES, ERA2_ROLES))
BURST_WAIT.update({_role: BURST_WAIT[ERA3_MIRROR[_role]] for _role in ERA3_ROLES})
BURST_WAIT["batteryShed"] = BURST_WAIT["oreShed"]
# [D70] Era 4: cei sase ai cablului si ai unirii vin in rafala, ca oamenii capitolului 1 (secunde de venit, ~2,5 minute
# reale pentru toti); magazia si oamenii cristalului ca oglinda lor din Wire Works
BURST_WAIT.update({
    "cableCollector": 9.0, "cablePorter": 11.0, "cablemaker": 13.0, "cableHauler": 15.0, "relayKeeper": 16.0,
    "pylonRunner": 18.0,
    "crystalShed": BURST_WAIT["batteryShed"], "crystalCollector": BURST_WAIT["batteryCollector"],
    "crystalPorter": BURST_WAIT["batteryPorter"], "crystalsmith": BURST_WAIT["electrician"],
    "ingotHauler": BURST_WAIT["powerHauler"],
})
LADDER_EXEMPT = {f"{r}2" for r in ROLES} | set(BURST_WAIT)
# [D55, D56] Shed-ul si oamenii fierului au pretul lor (BURST_WAIT), deci nu urca scara.


def ladder_step(bought: set) -> int:
    return len(bought - LADDER_EXEMPT)


def target_wait(k: int) -> float:
    """Asteptarea tinta (secunde, jucator lacom) inaintea deblocarii k.

    RITMUL LOR, masurat pe capturi: deschizi primul put in secunda 0, apoi urci NIVELURI cateva
    minute, iar "New Shaft" costa 2.6K cand tu ai 152 -- adica de vreo 20 de ori venitul tau de
    atunci. Deblocarea e o TINTA departata, nu urmatorul buton. Rafala de apasari din primele
    minute vine din niveluri, nu din deblocari.
    Prima varianta avea 20s si crestere 1.22: deblocarile ieseau atat de ieftine incat jucatorul
    lacom le lua pe toate la rand si nu urca niciun nivel pana in minutul 3."""
    return min(420.0, 20.0 * 1.17 ** (k + LADDER_START))


# [D62] Cele cinci angajari ale capitolului 1 urcau scara; acum au pretul lor (BURST_WAIT). Scara porneste de la treapta
# la care ajunsese dupa ele, ca plasele si tot ce urmeaza sa coste exact cat costau.
LADDER_START = 5


# ---- ERA 2, "THE MILL" [D64, D65] ------------------------------------------------------------------
# Regula owner-ului: incepi cu marfa aparuta la finalul erei dinainte (scrap), o cresti, iar spre final apare una noua
# (minereul de cupru) cu plasa, atelierul si oamenii ei; era isi vinde marfa la cladirea ei (Piata). Si: "poti incepe sa
# copiezi schemele si pentru era 2". Deci ERA2_UNLOCKS e ERA1_UNLOCKS in oglinda, platforma cu platforma:
#     First Net, cei cinci oameni, plasele 2-4 (fara traista: o ai deja)   ->  Sixth Net, cei cinci, plasele 7-9
#     Forge -> Fifth Net -> Scrap Shed -> cei patru ai fierului               ->  Copper Furnace -> Tenth Net -> Ore Shed -> cei patru
#     Landing Bell                                                            ->  Mill Bell
# plus reperul erei, la inceput: Water Wheel, care porneste turnatoria (costa monede: jocul are o singura moneda).


ERA2_LADDER_START = 7.5  # [D66] vezi ERA2["wait"]


def era2_nets(s) -> int:
    return len(s.nets) - NETS_PER_ERA


def set_flag(name: str):
    def f(s: State):
        setattr(s, name, True)

    return f


ERA2_UNLOCKS = [
    ("wheel", "Water Wheel", "V", lambda s: not s.wheel, set_flag("wheel")),  # nu "D": D e clopotul erei
    ("net6", "Sixth Net", "C", lambda s: s.wheel and era2_nets(s) == 0, unlock_net(6)),
    ("millCollector", "Mill Collector", "A", lambda s: era2_nets(s) >= 1 and people(s, "millCollector") == 0, hire("millCollector")),
    ("millPorter", "Mill Porter", "A", lambda s: people(s, "millCollector") >= 1 and people(s, "millPorter") == 0, hire("millPorter")),
    ("founder", "Founder", "A", lambda s: people(s, "millPorter") >= 1 and people(s, "founder") == 0, hire("founder")),
    ("partsHauler", "Parts Hauler", "A", lambda s: people(s, "founder") >= 1 and people(s, "partsHauler") == 0, hire("partsHauler")),
    ("merchant", "Merchant", "A", lambda s: people(s, "partsHauler") >= 1 and people(s, "merchant") == 0, hire("merchant")),
    ("net7", "Seventh Net", "C", lambda s: era2_nets(s) == 1 and prev_net_ready(s) and people(s, "merchant") >= 1, unlock_net(7)),
    ("net8", "Eighth Net", "C", lambda s: era2_nets(s) == 2 and prev_net_ready(s), unlock_net(8)),
    ("net9", "Ninth Net", "C", lambda s: era2_nets(s) == 3 and prev_net_ready(s), unlock_net(9)),
    ("furnace", "Copper Furnace", "V", lambda s: era2_nets(s) >= 4 and not s.furnace, set_flag("furnace")),
    ("net10", "Tenth Net", "C", lambda s: era2_nets(s) == 4 and prev_net_ready(s) and s.furnace, unlock_net(10)),
    ("oreShed", "Ore Shed", "V", lambda s: era2_nets(s) == 5 and not s.ore_shed, set_flag("ore_shed")),
    ("oreCollector", "Ore Collector", "A", lambda s: s.ore_shed and people(s, "oreCollector") == 0, hire("oreCollector")),
    ("orePorter", "Ore Porter", "A", lambda s: people(s, "oreCollector") >= 1 and people(s, "orePorter") == 0, hire("orePorter")),
    ("coppersmith", "Coppersmith", "A", lambda s: people(s, "orePorter") >= 1 and people(s, "coppersmith") == 0, hire("coppersmith")),
    ("copperHauler", "Copper Hauler", "A", lambda s: people(s, "coppersmith") >= 1 and people(s, "copperHauler") == 0, hire("copperHauler")),
]
for _role in ERA2_ROLES:
    ERA2_UNLOCKS.append(
        (
            f"{_role}2",
            f"Second {ROLE_NAMES[_role]}",
            "A",
            (lambda s, r=_role: people(s, r) == 1 and s.crews[r].tier >= SECOND_AT_TIER),
            hire(_role),
        )
    )
# Al doilea om al Erei 1, ramas necumparat, se poate lua si acum, la pretul lui de atunci (`seed_prices`).
ERA2_UNLOCKS += [u for u in ERA1_UNLOCKS if u[0] in {f"{r}2" for r in ERA1_ROLES}]
ERA2_UNLOCKS.append(
    (
        "bell2",
        "Mill Bell",
        "D",
        lambda s: era2_nets(s) == 5 and all(people(s, r) >= 1 for r in ERA2_ROLES) and s.furnace and s.ore_shed,
        unlock_bell,
    )
)
ERA2_OWN = {u[0] for u in ERA2_UNLOCKS} - {f"{r}2" for r in ERA1_ROLES}


# [D64] O ERA, CA DATE. `run` juca pana acum doar Era 1, cu listele ei batute in cuie. Acum primeste era: ce deblocari
# are, pe care le cere capitolul la rand, pe care le cere quest-ul desi singure nu aduc nimic, care ii e clopotul, care
# ii sunt plasele (quest-ul cere nivelul 2 pe ultima inaintea urmatoarei) si scara ei de asteptare. O era noua se joaca
# din starea in care a lasat-o cea dinainte (`run(era=..., start=...)`): vezi scripts/economy/sim_era2.py.
#   step(bought) = a cata deblocare de pe scara e urmatoarea; wait(k) = cate secunde de venit costa; free_first = prima
#   e gratis (First Net). `target_wait` se cauta dupa nume la fiecare apel: tune_tycoon.py il inlocuieste in memorie.
ERA1 = {
    "name": "Era 1",
    "unlocks": ERA1_UNLOCKS,
    "chapter_hires": CHAPTER1_HIRES,
    "quest_unlocks": QUEST_UNLOCKS,
    "bell": "bell",
    "first_net": 0,
    "net_count": 5,
    "step": lambda bought: ladder_step(bought),
    "wait": lambda k: target_wait(k),
    "free_first": True,
}
# [D65] Era 2 se joaca din starea in care a lasat-o Era 1. Scara ei de asteptare e ACEEASI (`target_wait`), repornita:
# numara doar deblocarile erei. Roata si prima plasa le cere quest-ul pe rand, apoi linia cuprului pas cu pas, ca
# linia fierului in capitolul 3.
ERA2 = {
    "name": "Era 2",
    "unlocks": ERA2_UNLOCKS,
    "chapter_hires": ("millCollector", "millPorter", "founder", "partsHauler", "merchant"),
    "quest_unlocks": (
        ("wheel", lambda s: True),
        ("net6", lambda s: True),
        ("furnace", lambda s: era2_nets(s) >= 4 and s.nets[NETS_PER_ERA + 3].level >= PREV_NET_LEVEL),
        ("net10", lambda s: True),
        ("oreShed", lambda s: True),
        ("oreCollector", lambda s: True),
        ("orePorter", lambda s: True),
        ("coppersmith", lambda s: True),
        ("copperHauler", lambda s: True),
    ),
    "bell": "bell2",
    "first_net": NETS_PER_ERA,
    "net_count": NETS_PER_ERA,
    "step": lambda bought: len((bought & ERA2_OWN) - LADDER_EXEMPT),
    # [D66] aceeasi scara ca Era 1, pornita mai sus: fara banii satului care sa-i subventioneze inceputul, Moara pe
    # scara x3000 se termina in ~43 de minute cu scara Erei 1 (START 5), la marginea portii de ritm; cu START 7.5 ~48 si
    # trece --robust. Peste 7.7 apar pauze de peste 3 minute inaintea cuptorului de cupru.
    "wait": lambda k: min(420.0, 20.0 * 1.17 ** (k + ERA2_LADDER_START)),
    "free_first": False,  # roata de apa costa monede (D65): poarta erei
    # [D66] Moara porneste ca satul: prima ei plasa e gratis. Cu scara x3000, banii satului nu mai subventioneaza
    # nivelurile ieftine ale Morii: platita (8K), plasa asta se astepta ~2 minute reale fara nimic de apasat, iar primele
    # 5 minute ale erei aveau doar 5 cumparaturi (poarta cere 15).
    "free_units": ("net6",),
}


# ---- ERA 3, "THE WIRE WORKS" [D67] --------------------------------------------------------------
# Moara in oglinda, platforma cu platforma (docs/PLAN-ERA3.md):
#     Water Wheel -> Sixth Net -> cei cinci -> plasele 7-9     ->  Steam Engine -> Eleventh Net (minereu de cupru)
#                                                                  -> cei cinci -> plasele 12-14
#     Copper Furnace -> Tenth Net -> Ore Shed -> cei patru      ->  Power House -> First Turbine -> Battery Shed -> cei patru
#     Mill Bell                                                 ->  Works Bell
# Scara de asteptare e a Morii (START 7.5): Era 3 e Moara pe scara x3000, iar derivarea din sim_era3.py a trecut
# portile Morii cu ea, si la +-15% pe fiecare constanta noua.
ERA3_LADDER_START = 7.5


def era3_nets(s) -> int:
    return len(s.nets) - 2 * NETS_PER_ERA


ERA3_UNLOCKS = [
    ("steam", "Steam Engine", "V", lambda s: not s.steam, set_flag("steam")),
    ("net11", "Eleventh Net", "C", lambda s: s.steam and era3_nets(s) == 0, unlock_net(11)),
    ("worksCollector", "Works Collector", "A", lambda s: era3_nets(s) >= 1 and people(s, "worksCollector") == 0, hire("worksCollector")),
    ("worksPorter", "Works Porter", "A", lambda s: people(s, "worksCollector") >= 1 and people(s, "worksPorter") == 0, hire("worksPorter")),
    ("wiredrawer", "Wiredrawer", "A", lambda s: people(s, "worksPorter") >= 1 and people(s, "wiredrawer") == 0, hire("wiredrawer")),
    ("coilHauler", "Coil Hauler", "A", lambda s: people(s, "wiredrawer") >= 1 and people(s, "coilHauler") == 0, hire("coilHauler")),
    ("clerk", "Clerk", "A", lambda s: people(s, "coilHauler") >= 1 and people(s, "clerk") == 0, hire("clerk")),
    ("net12", "Twelfth Net", "C", lambda s: era3_nets(s) == 1 and prev_net_ready(s) and people(s, "clerk") >= 1, unlock_net(12)),
    ("net13", "Thirteenth Net", "C", lambda s: era3_nets(s) == 2 and prev_net_ready(s), unlock_net(13)),
    ("net14", "Fourteenth Net", "C", lambda s: era3_nets(s) == 3 and prev_net_ready(s), unlock_net(14)),
    ("powerhouse", "Power House", "V", lambda s: era3_nets(s) >= 4 and not s.powerhouse, set_flag("powerhouse")),
    ("net15", "First Turbine", "C", lambda s: era3_nets(s) == 4 and prev_net_ready(s) and s.powerhouse, unlock_net(15)),
    ("batteryShed", "Battery Shed", "V", lambda s: era3_nets(s) == 5 and not s.battery_shed, set_flag("battery_shed")),
    ("batteryCollector", "Battery Collector", "A", lambda s: s.battery_shed and people(s, "batteryCollector") == 0, hire("batteryCollector")),
    ("batteryPorter", "Battery Porter", "A", lambda s: people(s, "batteryCollector") >= 1 and people(s, "batteryPorter") == 0, hire("batteryPorter")),
    ("electrician", "Electrician", "A", lambda s: people(s, "batteryPorter") >= 1 and people(s, "electrician") == 0, hire("electrician")),
    ("powerHauler", "Power Hauler", "A", lambda s: people(s, "electrician") >= 1 and people(s, "powerHauler") == 0, hire("powerHauler")),
]
for _role in ERA3_ROLES:
    ERA3_UNLOCKS.append(
        (
            f"{_role}2",
            f"Second {ROLE_NAMES[_role]}",
            "A",
            (lambda s, r=_role: people(s, r) == 1 and s.crews[r].tier >= SECOND_AT_TIER),
            hire(_role),
        )
    )
# Al doilea om al erelor dinainte, ramas necumparat, se poate lua si acum, la pretul lui de atunci (`seed_prices`).
ERA3_UNLOCKS += [u for u in ERA2_UNLOCKS if u[0] in {f"{r}2" for r in ERA1_ROLES + ERA2_ROLES}]
ERA3_UNLOCKS.append(
    (
        "bell3",
        "Works Bell",
        "D",
        lambda s: era3_nets(s) == 5 and all(people(s, r) >= 1 for r in ERA3_ROLES) and s.powerhouse and s.battery_shed,
        unlock_bell,
    )
)
ERA3_OWN = {u[0] for u in ERA3_UNLOCKS} - {f"{r}2" for r in ERA1_ROLES + ERA2_ROLES}
ERA3 = {
    "name": "Era 3",
    "unlocks": ERA3_UNLOCKS,
    "chapter_hires": ("worksCollector", "worksPorter", "wiredrawer", "coilHauler", "clerk"),
    "quest_unlocks": (
        ("steam", lambda s: True),
        ("net11", lambda s: True),
        ("powerhouse", lambda s: era3_nets(s) >= 4 and s.nets[2 * NETS_PER_ERA + 3].level >= PREV_NET_LEVEL),
        ("net15", lambda s: True),
        ("batteryShed", lambda s: True),
        ("batteryCollector", lambda s: True),
        ("batteryPorter", lambda s: True),
        ("electrician", lambda s: True),
        ("powerHauler", lambda s: True),
    ),
    "bell": "bell3",
    "first_net": 2 * NETS_PER_ERA,
    "net_count": NETS_PER_ERA,
    "step": lambda bought: len((bought & ERA3_OWN) - LADDER_EXEMPT),
    "wait": lambda k: min(420.0, 20.0 * 1.17 ** (k + ERA3_LADDER_START)),
    "free_first": False,  # masina cu abur costa monede: poarta erei, ca roata de apa
    "free_units": ("net11",),  # prima plasa a erei e gratis, ca a sasea [D66]
}
# ---- ERA 4, "THE DAM" [D70] ----------------------------------------------------------------------------------------
# Planul: docs/PLAN-MOTOR-UNIRE.md (sectiunile 2 si 5), cu hotararile owner-ului din D70 Runda 4 si 5. Barajul nu e o
# deblocare de pe scara: e schimbarea de harta pe care o alegi dupa Works Bell. `dam_transform` face din starea de la
# clopot starea de la baraj, iar era se joaca de acolo, de trei ori (`play_era4`: fara bani, cu suma, capitolul).
#     cei cinci veterani lucreaza butoaiele; turbina din zid si Cable Net 1 vin gratis; tu faci turul cablului
#     -> cei sase ai cablului si ai unirii, in rafala (capitolul 10) -> plasele de cablu 2 si 3
#     -> Kiln (doar cu toti cei 11, ca bazinul sa nu-ti imparta timpul) -> Crystal Net -> Crystal Shed -> cei patru
#     -> Dam Bell, la DAM_BELL_INCOME
DAM_VETERANS = ("damCollector", "damPorter", "switchman", "barrelHauler", "dispatcher")
DAM_HIRES = ("cableCollector", "cablePorter", "cablemaker", "cableHauler", "relayKeeper", "pylonRunner")
DAM_CREW = DAM_VETERANS + DAM_HIRES
# cate plase are fiecare familie la Dam Bell. [owner, 2026-10-01, varianta 1 din PLAN-MOTOR-UNIRE §11] Fara a doua
# turbina si a patra plasa de cablu: nu aduceau nimic (+0.10% / 0%, colectorii erau deja plini), iar pe harta deschideau
# clopotul pe la minutul 27.
DAM_NETS = {"dam": 1, "cable_ore": 3, "crystal": 1}
# RISCUL 1 DIN PLAN, PLATOUL: cei doi colectori (butoaie si cablu) ajung la maxim (2 oameni x treapta 5) si tin unirea,
# iar venitul se taraste (niveluri de plasa de +0.3%) pana la cristal. Cu Kiln-ul dupa a patra plasa de cablu, venitul
# crestea sub 10% timp de 22-30 de minute (Erele 1-3: cel mult 20m58s), oricum ar fi fost scara sau uneltele. Dupa a
# treia, cristalul vine inaintea zidului: platoul 6m32s, "tararea" 17m38s (cu uneltele la pret dublu, ERA_TOOL_MULT, si
# scara de la 6.5). A treia plasa e acum ultima de cablu.
KILN_CABLE_NETS = 3
# [verificator, 2026-10-01] PASII DE VENIT AI CAPITOLULUI. A treia plasa de cablu (16T) se cumpara din suma de start in
# primul minut. Daca dupa ea capitolul ar cere Kiln-ul (110T), cine strange pentru el (regula quest-urilor) ar sta la
# ~86B/s: era peste o ora si jumatate, platoul peste o ora. Intre plasa si Kiln capitolul cere deci un venit ("Earn 1T
# coins a second"): cat tine pasul, ghidajul arata veriga slaba, nu pretul Kiln-ului, iar quest-ul Kiln-ului vine abia
# dupa. Pasul Kiln-ului e doar al capitolului: Kiln-ul ramane de cumparat oricand ai banii. Lacomul e deja peste 1T/s
# inaintea celei de-a treia plase (1.07T/s -> 1.11T/s), deci cronologia lui nu se schimba. Rularea capitolului e a treia
# din DamRun.
# DAM BELL SE DESCHIDE LA UN VENIT, scris pe cartonas ("Opens at 4T coins a second") [owner, 2026-10-01, varianta 1]:
# venitul erei se apropie de plafon (dam_ceiling, 4.89T/s) pe la minutul 40, iar clopotul nu mai are alta platforma care
# sa-l tina. Si capitolul cere pragul inaintea clopotului ("Earn 4T coins a second"), altfel "Ring the Dam Bell" ar sta
# ~16 minute pe un clopot incuiat, fara contor (capcana Kiln-ului, verificator). Pragul sta la ~82% din plafon: la 4.5T
# (92%), cu o constanta cu 15% mai jos plafonul cobora la 4.51T si pasul abia se mai misca. check_dam cere ca plafonul
# fiecarui prag sa fie cu DAM_STEP_MARGIN peste el, si la --robust. In joc pragurile se compara cu venitul din HUD si se
# inmultesc cu 2x Flow (ca era sa-si pastreze continutul, iar pass-ul sa dea tot jumatate din timp): rândul f din plan.
KILN_INCOME = 1e12
DAM_BELL_INCOME = 4e12
DAM_STEP_MARGIN = 1.10
# La +-15% pe o constanta (--robust), platoul si "tararea" pot iesi cu cel mult atat peste cele mai lungi din Erele 1-3,
# cum pragul verigilor e pe jumatate la Erele 2-3. Poarta prinde o prapastie, nu zgomotul de +-15%. (Marja a fost aleasa
# dupa ce se vazuse cel mai rau caz al primei variante, 14m04s: e o marja de zgomot, nu o dovada.)
ROBUST_FLAT_SLACK = 1.35
# vezi KILN_CABLE_NETS; 8.5 din 2026-10-01: fara turbina a doua si a patra plasa, clopotul ajungea mai ieftin (450T) si
# Era 4 tinea 38m49s, sub cele 40 de minute ale unei ere. La 8.5: 44m07s-1h03m la +-15% (cele lungi stau la
# 3.4-3.55T/s, sub pragul de 4T); la 10, 1h12m pe cifrele de baza.
ERA4_LADDER_START = 8.5
# al doilea om al Erei 4: macar atatea trepte 5 ale meseriei lui (ERA4["price_floor"]), inainte de rotunjire; check_dam
# cere doar ce conteaza pentru meniu: mai scump decat treapta 5. Scara preturilor e strict crescatoare, deci podeaua poate
# urca si deblocarile de dupa cei sapte oameni. Cu scara de la 6.5 lega: fara ea, al doilea Dam Collector ar fi costat 35T
# si al doilea Cable Collector 30T, sub treapta 5 (36.45T), iar Kiln-ul urca 80T -> 100T. Cu scara de la 8.5 aproape nu
# mai leaga (Era 4: 45m12s fara, 45m16s cu); ramane plasa de siguranta.
SECOND_FLOOR = 1.25


def dam_nets(s: State, kind: str) -> int:
    return sum(1 for n in s.nets if n.kind == kind)


def family_ready(s: State, kind: str) -> bool:
    """Plasa urmatoare a unei familii cere ca ultima de acelasi fel sa fie la nivelul 2 (quest-ul, pe familii)."""
    last = next((n for n in reversed(s.nets) if n.kind == kind), None)
    return last is None or last.level >= PREV_NET_LEVEL


def dam_transform(s3: State, coins: float) -> State:
    """[D70] Barajul, pe o clona a starii de la Works Bell (plan, sectiunea 5): liniile vechi se inchid (plasele, nivelurile
    si oamenii lor raman in stare, ca in profil), cei cinci veterani intra pe treapta 1 cate unul, turbina zidita in baraj
    (rang 5) si Cable Net 1 vin gratis, iar Switchyard, Cable Works, Relay si orasul exista de la baraj. Clopotele,
    traista, pass-urile, indexul si renasterile raman. Monedele sunt suma de start."""
    s = clone(s3)
    s.dam = True
    for role in DAM_VETERANS:
        s.crews[role].count = 1
    unlock_net_ranked("dam", 5, 3, 4)(s)
    unlock_net_ranked("cable_ore", 1, 1, 4)(s)
    s.coins = coins
    return s


ERA4_UNLOCKS = [
    ("cableCollector", "Cable Collector", "A", lambda s: s.dam and people(s, "cableCollector") == 0, hire("cableCollector")),
    ("cablePorter", "Cable Porter", "A", lambda s: people(s, "cableCollector") >= 1 and people(s, "cablePorter") == 0, hire("cablePorter")),
    ("cablemaker", "Cablemaker", "A", lambda s: people(s, "cablePorter") >= 1 and people(s, "cablemaker") == 0, hire("cablemaker")),
    ("cableHauler", "Cable Hauler", "A", lambda s: people(s, "cablemaker") >= 1 and people(s, "cableHauler") == 0, hire("cableHauler")),
    ("relayKeeper", "Relay Keeper", "A", lambda s: people(s, "cableHauler") >= 1 and people(s, "relayKeeper") == 0, hire("relayKeeper")),
    ("pylonRunner", "Pylon Runner", "A", lambda s: people(s, "relayKeeper") >= 1 and people(s, "pylonRunner") == 0, hire("pylonRunner")),
    (
        "cableNet2", "Second Cable Net", "C",
        lambda s: dam_nets(s, "cable_ore") == 1 and family_ready(s, "cable_ore") and people(s, "pylonRunner") >= 1,
        unlock_net_ranked("cable_ore", 2, 1, 4),
    ),
    (
        "cableNet3", "Third Cable Net", "C",
        lambda s: dam_nets(s, "cable_ore") == 2 and family_ready(s, "cable_ore"),
        unlock_net_ranked("cable_ore", 3, 2, 4),
    ),
    (
        "kiln", "Kiln", "V",
        lambda s: dam_nets(s, "cable_ore") >= KILN_CABLE_NETS and all(people(s, r) >= 1 for r in DAM_CREW) and not s.kiln,
        set_flag("kiln"),
    ),
    ("crystalNet", "Crystal Net", "C", lambda s: s.kiln and dam_nets(s, "crystal") == 0, unlock_net_ranked("crystal", 5, 3, 4)),
    ("crystalShed", "Crystal Shed", "V", lambda s: dam_nets(s, "crystal") == 1 and not s.crystal_shed, set_flag("crystal_shed")),
    ("crystalCollector", "Crystal Collector", "A", lambda s: s.crystal_shed and people(s, "crystalCollector") == 0, hire("crystalCollector")),
    ("crystalPorter", "Crystal Porter", "A", lambda s: people(s, "crystalCollector") >= 1 and people(s, "crystalPorter") == 0, hire("crystalPorter")),
    ("crystalsmith", "Crystalsmith", "A", lambda s: people(s, "crystalPorter") >= 1 and people(s, "crystalsmith") == 0, hire("crystalsmith")),
    ("ingotHauler", "Ingot Hauler", "A", lambda s: people(s, "crystalsmith") >= 1 and people(s, "ingotHauler") == 0, hire("ingotHauler")),
]
for _role in ERA4_ROLES:
    ERA4_UNLOCKS.append(
        (
            f"{_role}2",
            f"Second {ROLE_NAMES[_role]}",
            "A",
            (lambda s, r=_role: people(s, r) == 1 and s.crews[r].tier >= SECOND_AT_TIER),
            hire(_role),
        )
    )
# Al doilea om al erelor dinainte nu mai e de cumparat: liniile lor sunt inchise de baraj.
ERA4_UNLOCKS.append(
    (
        "bell4",
        "Dam Bell",
        "D",
        lambda s: all(dam_nets(s, kind) == n for kind, n in DAM_NETS.items())
        and all(people(s, r) >= 1 for r in ERA4_ROLES)
        and s.kiln
        and s.crystal_shed
        and income(s) >= DAM_BELL_INCOME,
        unlock_bell,
    )
)
ERA4_OWN = {u[0] for u in ERA4_UNLOCKS}


def era4_quest_net(s: State):
    """Quest-ul "nivelul 2 pe ultima plasa", pe familii: ultima plasa de cablu la nivelul 2. Ca in Erele 2-3, capitolul
    cere nivelul 2 si pe plasa dinaintea atelierului erei (a treia de cablu, KILN_CABLE_NETS, ultima), apoi Kiln-ul
    (quest-ul lui)."""
    cable = [i for i, n in enumerate(s.nets) if n.kind == "cable_ore"]
    if 1 <= len(cable) <= DAM_NETS["cable_ore"] and s.nets[cable[-1]].level < PREV_NET_LEVEL:
        return cable[-1]
    return None


ERA4 = {
    "name": "Era 4",
    "unlocks": ERA4_UNLOCKS,
    "chapter_hires": DAM_HIRES,
    # [D70, verificator] Plasele de cablu NU sunt aici: lacomul le ia cand aduc ceva, iar preturile se
    # fixeaza pe cronologia lui. Modelate ca quest-uri, cu preturile derivate din nou, Era 4 cadea la 11 minute: suma de
    # start cumpara tot. Capitolele Erei 4 (pasul k) le cer totusi in ordinea DAM_CHAPTER, cu pasii de venit
    # (KILN_INCOME), iar cine le ia cum are banii e a treia rulare din DamRun.
    "quest_unlocks": (
        # pasul de capitol "Earn 1T coins a second" sta inaintea Kiln-ului (KILN_INCOME)
        ("kiln", lambda s: dam_nets(s, "cable_ore") >= KILN_CABLE_NETS and family_ready(s, "cable_ore") and income(s) >= KILN_INCOME),
        ("crystalNet", lambda s: True),
        ("crystalShed", lambda s: True),
        ("crystalCollector", lambda s: True),
        ("crystalPorter", lambda s: True),
        ("crystalsmith", lambda s: True),
        ("ingotHauler", lambda s: True),
    ),
    "bell": "bell4",
    "quest_net": era4_quest_net,
    # [D70, verificator] al doilea om costa macar SECOND_FLOOR x treapta 5 a meseriei lui: cu uneltele la pret dublu,
    # scara il dadea mai ieftin decat treapta, iar meniul lauda treapta (in Erele 1-3 primul al doilea om al erei costa de
    # 1.6-2.5 ori cat treapta 5, ceilalti mult mai mult)
    "price_floor": lambda uid: (
        SECOND_FLOOR * tier_cost(TIER_MAX - 1, uid[:-1])
        if uid.endswith("2") and uid[:-1] in ERA4_ROLES
        else 0.0
    ),
    "step": lambda bought: len((bought & ERA4_OWN) - LADDER_EXEMPT),
    "wait": lambda k: min(420.0, 20.0 * 1.17 ** (k + ERA4_LADDER_START)),
    "free_first": False,
}

# Erele de dupa prima, in ordine; fiecare se joaca din starea in care a lasat-o cea dinainte. [D70] Era 4 se joaca prin
# `play_era4` (barajul, apoi doua rulari), nu prin `run_era`.
LATER_ERAS = {2: ERA2, 3: ERA3, 4: ERA4}


def run_era(n: int, start: State, prior_prices: dict, max_seconds=200000):
    """[D67] Joaca era `n` din starea in care s-a terminat cea dinainte. Al doilea om al erelor dinainte, ramas
    necumparat, isi tine pretul de atunci (`prior_prices`: preturile tuturor erelor jucate pana acum)."""
    if n == 4:
        raise SystemExit("EROARE: Era 4 se joaca prin play_era4 (barajul si cele doua rulari), nu prin run_era [D70]")
    era = dict(LATER_ERAS[n])
    older = {f"{r}2" for k in range(1, n) for r in ERA_ROLES[k]}
    era["seed_prices"] = {uid: price for uid, price in prior_prices.items() if uid not in start.bought and uid in older}
    return run(era=era, start=start, max_seconds=max_seconds)


def run_era2(start: State, era1_prices: dict, max_seconds=200000):
    """Joaca Era 2 din starea in care s-a terminat Era 1. Al doilea om al Erei 1, ramas necumparat, isi tine pretul."""
    return run_era(2, start, era1_prices, max_seconds)


NICE = (1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 7.5, 8, 9)


NICE_MAX_MAG = 24  # [D70] pana la 9 x 10^24: o noapte la Dam Bell face ~96Qa (~10^17), iar erele de dupa urca mai sus


def nice(x: float, floor: int = 0) -> int:
    """Pret 'rotund' pe care il citeste un copil dintr-o privire, si STRICT mai mare decat
    pretul deblocarii anterioare.
    [D70] Pana la 10^24, in intregi: `int(2.8 * 10**14)` iese 279999999999999 (virgula mobila), deci pretul se face
    din zecimi exacte. Pana la 10^12 cifrele sunt aceleasi ca inainte, bit cu bit; peste scara, simulatorul se opreste
    (inainte intorcea `int(x)`, un pret nerotunjit)."""
    if x < 10:
        v = max(0, int(round(x)))
        return v if v > floor else floor + 1
    for mag in (10**k for k in range(0, NICE_MAX_MAG + 1)):
        for n in NICE:
            v = round(n * 10) * mag // 10
            if v >= x * 0.93 and v > floor:
                return v
    raise SystemExit(f"EROARE: pretul {x:.3g} trece de scara preturilor (9 x 10^{NICE_MAX_MAG})")


def nice_up(x: float) -> int:
    """[D70] Cel mai mic pret rotund care nu e sub `x` (suma de start la baraj: nu se rotunjeste in jos, ca `nice`)."""
    for mag in (10**k for k in range(0, NICE_MAX_MAG + 1)):
        for n in NICE:
            v = round(n * 10) * mag // 10
            if v >= x:
                return v
    raise SystemExit(f"EROARE: suma {x:.3g} trece de scara preturilor (9 x 10^{NICE_MAX_MAG})")


# ---- optiunile de cumparare la un moment dat --------------------------------------------------


# [D64] Cladirile cu niveluri, IN ORDINEA in care intra in lista de optiuni (la castig egal pe moneda, sortarea stabila
# o pastreaza pe cea dinainte: gaterul, taverna, forja). Costul de baza se tine dupa nume (vezi LINES); `owned` e campul
# din State fara de care cladirea nu exista inca (None = de la inceput). O era noua isi adauga cladirile la coada.
BUILDINGS = {
    "saw": {"label": "Saw", "cost": "SAW_UPGRADE_BASE", "level": "saw_level", "owned": None},
    "dock": {"label": "Dock", "cost": "DOCK_UPGRADE_BASE", "level": "dock_level", "owned": None},
    "forge": {"label": "Forge", "cost": "FORGE_UPGRADE_BASE", "level": "forge_level", "owned": "workshop"},  # [D55]
    # [D65] Era 2: turnatoria si Piata pornesc odata cu roata de apa, cuptorul cand il cumperi
    "foundry": {"label": "Foundry", "cost": "FOUNDRY_UPGRADE_BASE", "level": "foundry_level", "owned": "wheel"},
    "market": {"label": "Market", "cost": "MARKET_UPGRADE_BASE", "level": "market_level", "owned": "wheel"},
    "furnace": {"label": "Furnace", "cost": "FURNACE_UPGRADE_BASE", "level": "furnace_level", "owned": "furnace"},
    # [D67] Era 3: Wire Works si Depoul pornesc odata cu masina cu abur, Power House cand il cumperi
    "wireworks": {"label": "Wire Works", "cost": "WIREWORKS_UPGRADE_BASE", "level": "wireworks_level", "owned": "steam"},
    "depot": {"label": "Depot", "cost": "DEPOT_UPGRADE_BASE", "level": "depot_level", "owned": "steam"},
    "powerhouse": {"label": "Power House", "cost": "POWERHOUSE_UPGRADE_BASE", "level": "powerhouse_level", "owned": "powerhouse"},
    # [D70] Era 4: Switchyard, Cable Works, Relay si orasul exista de la baraj; Kiln-ul cand il cumperi
    "switchyard": {"label": "Switchyard", "cost": "SWITCHYARD_UPGRADE_BASE", "level": "switchyard_level", "owned": "dam"},
    "cableworks": {"label": "Cable Works", "cost": "CABLEWORKS_UPGRADE_BASE", "level": "cableworks_level", "owned": "dam"},
    "relay": {"label": "Relay Station", "cost": "RELAY_UPGRADE_BASE", "level": "relay_level", "owned": "dam"},
    "town": {"label": "Switch House", "cost": "TOWN_UPGRADE_BASE", "level": "town_level", "owned": "dam"},
    "kiln": {"label": "Kiln", "cost": "KILN_UPGRADE_BASE", "level": "kiln_level", "owned": "kiln"},
}


def net_upgrade_base(s: State, i: int) -> float:
    """Costul de baza al nivelurilor plasei de pe locul `i` (de la 0): creste cu locul ei in era, de `net_era_mult` ori
    in erele noi. Plasele se cumpara in ordine, deci locul in `s.nets` e si numarul plasei."""
    own = s.nets[i].upgrade_base
    if own is not None:
        return own
    return NET_UPGRADE_BASE_COST * NET_BASE_GROWTH ** (i % NETS_PER_ERA) * net_era_mult(i + 1)


def link_closed(link: str, closed: set) -> bool:
    """[D70] Veriga apartine liniilor inchise: un pas al unei linii inchise, sau un vanzator cu toate liniile inchise."""
    if link in SELLERS:
        return all(line in closed for line in SELLERS[link]["priority"])
    return any(link in LINE_LINKS[line] for line in closed)


def options(s: State, prices: dict, era=None):
    """Tot ce poate cumpara jucatorul ACUM: deblocarile erei a caror conditie e implinita, un nivel pe
    orice cladire detinuta si o treapta pe orice meserie cu oameni. Intoarce (eticheta, pret, efect,
    fel, uid). [D70] Fara plasele, cladirile si treptele liniilor INCHISE (`closeFlag`): raman in State, dar nu mai
    lucreaza, deci nu se mai vand. O linie inca nedeschisa (forja inaintea plasei de scrap) ramane de vanzare."""
    era = era or ERA1
    out = []
    closed = {line for line in LINE_ORDER if line_closed(s, line)}
    for uid, name, _why, cond, effect in era["unlocks"]:
        if uid in s.bought or not cond(s):
            continue
        if uid in prices:
            out.append((f"unlock:{name}", prices[uid], effect, "unlock", uid))

    for i, n in enumerate(s.nets):
        if closed and NET_LINE.get(n.kind) in closed:
            continue
        base_cost = net_upgrade_base(s, i)

        def up_net(st, idx=i):
            st.nets[idx].level += 1

        out.append(
            (f"Net {i + 1} lvl {n.level + 1}", level_cost(base_cost, n.level), up_net, "nets", None)
        )

    for kind, spec in BUILDINGS.items():
        if spec["owned"] is not None and not getattr(s, spec["owned"]):
            continue
        if closed and link_closed(kind, closed):
            continue
        level = getattr(s, spec["level"])

        def up_building(st, field=spec["level"]):
            setattr(st, field, getattr(st, field) + 1)

        out.append((f"{spec['label']} lvl {level + 1}", level_cost(globals()[spec["cost"]], level), up_building, kind, None))

    for role in ROLES:
        crew = s.crews[role]
        if crew.count == 0 or crew.tier >= TIER_MAX:
            continue
        if closed and link_closed(LINK_OF[role], closed):
            continue

        def up_tier(st, r=role):
            st.crews[r].tier += 1

        out.append((f"{ROLE_NAMES[role]} tier {crew.tier + 1}", tier_cost(crew.tier, role), up_tier, LINK_OF[role], None))
    return out


def clone(s: State) -> State:
    # [D64] TOATE campurile, si cele pe care dataclass-ul nu le stie: o era noua isi aduce campurile ei (nivelul
    # turnatoriei, conditia liniei), iar o clona care le-ar pierde ar face `gain_of` sa socoteasca pe o stare ciuntita.
    known = State.__dataclass_fields__
    c = State(**{k: v for k, v in s.__dict__.items() if k in known and k not in ("nets", "bought", "crews")})
    for k, v in s.__dict__.items():
        if k not in known:
            setattr(c, k, v)
    c.nets = [Net(n.base, n.base_lane, n.level, n.kind, n.upgrade_base) for n in s.nets]
    c.crews = {r: Crew(v.count, v.tier) for r, v in s.crews.items()}
    c.bought = set(s.bought)
    return c


def gain_of(s: State, effect, before: float = None) -> float:
    """Cat adauga o cumparatura la venit. Poate fi ZERO: un upgrade pe o veriga care nu e
    gatuirea nu schimba nimic. Vezi regula B din antet. `before` = venitul de acum, daca apelantul il are deja
    (bucla de cumparare intreaba pentru zeci de optiuni pe aceeasi stare; e aceeasi cifra, socotita o data)."""
    if before is None:
        before = income(s)
    probe = clone(s)
    effect(probe)
    return income(probe) - before


# ---- simularea --------------------------------------------------------------------------------

VIOLATIONS = []


SAVE_THRESHOLD = 0.40
"""Cat de buna trebuie sa fie o cumparatura accesibila ca sa n-o amani. Sub pragul asta fata de
cea mai buna optiune din tabel, jucatorul prefera sa STRANGA. Fara regula asta, simularea cheltuia
fiecare moneda pe cel mai ieftin nivel si nu ajungea niciodata la o deblocare; cu ea = 1, statea cu
banii in mana si nu apasa nimic minute intregi. Amandoua sunt false: un om apasa ce e aproape la
fel de bun si strange pentru ce e clar mai bun."""


def run(rebirths=0, index_found=0, max_seconds=36000, era=None, start=None):
    """Simulare pe pasi de o secunda. In fiecare secunda intra venitul, apoi jucatorul cumpara
    tot ce merita cumparat acum. Asa ies si rafalele de apasari, si rabdarea pentru o deblocare.
    [D64] `era` = ce era se joaca (implicit Era 1); `start` = starea din care porneste (sfarsitul erei dinainte)."""
    era = era or ERA1
    unlocks = era["unlocks"]
    s = start if start is not None else State(rebirths=rebirths, index_found=index_found)
    started_at = s.t
    rows = []
    # o era noua mosteneste preturile ramase din cea dinainte (al doilea om necumparat isi tine pretul de atunci)
    prices: dict = dict(era.get("seed_prices") or {})
    last_price = 0
    # POARTA E TIMPUL MORT, NU GATUIREA. Prima varianta masura "cat timp a stat aceeasi veriga
    # gatuita" -- dar aia poate fi lunga si sanatoasa, daca in tot timpul ala o repari nivel cu
    # nivel. Ce chiar strica jocul e sa nu ai NIMIC de apasat. Deci masuram pauza dintre doua
    # cumparaturi.
    last_buy_at = s.t
    longest_idle = 0.0
    shares = {link: 0 for link in LINKS}
    # [D55] secundele in care fiecare linie e deschisa: verigile ei exista doar atunci (fierul apare la coada Erei 1)
    line_time = {line: 0 for line in LINE_ORDER}
    # [D70] secundele in care fiecare veriga are un castig real SINGURA (o bucata in plus doar pe ea aduce bani, fara
    # egalitate): meniul ei nu scrie "No gain yet". Doar pentru poarta "decor" a Erei 4 (vezi check_run_era); nu schimba
    # nimic din rulare.
    gain_time = {link: 0 for link in LINKS}

    def reprice():
        # pretul unei deblocari se fixeaza cand devine PRIMA DATA accesibila, din venitul de-atunci
        nonlocal last_price
        for uid, _name, _why, cond, _effect in unlocks:
            if uid in s.bought or uid in prices or not cond(s):
                continue
            if uid in era.get("free_units", ()):
                prices[uid] = 0  # [D66] prima plasa a unei ere noi e gratis, ca prima plasa a satului
                continue
            if uid in BURST_WAIT:  # [D56] oamenii fierului: secunde de venit, fara scara si fara podea
                prices[uid] = nice(income(s) * BURST_WAIT[uid])
                continue
            k = era["step"](s.bought)
            free = k == 0 and era["free_first"]
            want = income(s) * era["wait"](k)
            floor_of = era.get("price_floor")  # [D70] o podea pe deblocare (al doilea om al Erei 4); fara ea, ca pana acum
            if floor_of is not None:
                want = max(want, floor_of(uid))
            prices[uid] = 0 if free else nice(want, last_price)
            last_price = max(last_price, prices[uid])

    def buy(label, kind, price, effect, uid):
        nonlocal last_buy_at, longest_idle
        before = income(s)
        s.coins -= price
        effect(s)
        if uid is not None:
            s.bought.add(uid)
        after = income(s)
        if after < before - 1e-9:
            VIOLATIONS.append(f"{label}: venitul SCADE {before:.2f} -> {after:.2f}")
        longest_idle = max(longest_idle, s.t - last_buy_at)
        last_buy_at = s.t
        rows.append((label, kind, price, s.t, after, chain(s).bottleneck))

    scanned = -1  # cate cumparaturi avea starea scanata ultima data (monotonia, mai jos)
    while era["bell"] not in s.bought:
        reprice()

        # cumpara tot ce merita, cat timp merita
        while True:
            # [D70, plan §8] MONOTONIA PE STARILE ATINSE: nicio optiune de pe ecran nu scade venitul, nu doar cele pe care
            # le cumpara lacomul (verificarea din `buy`). O data pe fiecare stare noua (dupa fiecare cumparatura), inaintea
            # scurtaturilor capitolului si ale quest-urilor, si o singura data pe era, fel si deblocare in raport.
            if len(rows) != scanned:
                scanned = len(rows)
                income_now = income(s)
                for label, _price, effect, kind, uid in options(s, prices, era):
                    g = gain_of(s, effect, income_now)
                    if g < -1e-9 * max(1.0, income_now):
                        tag = f"[monotonie {era['name']} {kind} {uid}]"
                        if not any(tag in v for v in VIOLATIONS):  # VIOLATIONS se goleste intre variantele --robust
                            VIOLATIONS.append(f"{tag} {label} ar SCADEA venitul cu {big(-g)}/s")
            # OAMENII CAPITOLULUI 1, IN ORDINE, INAINTEA ORICAREI ALTE CUMPARATURI [D52]. Cu o singura
            # plasa, un om adauga ZERO venit (plasa e veriga slaba), deci lacomul nu l-ar lua niciodata;
            # iar fara sa strangi, nivelurile de 1-2 monede ale plasei ar manca banii la nesfarsit. Deci:
            # cat lipseste un om al capitolului si conditia lui e implinita, il iei cand ai banii si nu
            # cumperi nimic altceva pana atunci. Sta inaintea nivelului 2: in quest-uri, nivelul vine dupa.
            pending = next((uid for uid in era["chapter_hires"] if uid not in s.bought), None)
            if pending is not None:
                _uid, name, _why, cond, effect = next(e for e in unlocks if e[0] == pending)
                if cond(s) and pending in prices:
                    if prices[pending] <= s.coins:
                        buy(f"unlock:{name}", "unlock", prices[pending], effect, pending)
                        reprice()
                        continue
                    break

            # [D55, D56] DEBLOCARILE CERUTE DE QUEST (traista, linia fierului pas cu pas). Singure aduc putin sau
            # nimic, deci lacomul nu le-ar lua; un om urmeaza quest-ul si strange pentru ele.
            quested = next((uid for uid, ready in era["quest_unlocks"] if uid not in s.bought and ready(s)), None)
            if quested is not None:
                _uid, name, _why, cond, effect = next(e for e in unlocks if e[0] == quested)
                if cond(s) and quested in prices:
                    if prices[quested] <= s.coins:
                        buy(f"unlock:{name}", "unlock", prices[quested], effect, quested)
                        reprice()
                        continue
                    break

            # [D64] DEBLOCARILE PE CARE UN OM LE IA CUM ARE BANII, fara sa se opreasca din cumparat pana atunci (plasele
            # unei ere noi: quest-ul le cere, iar o plasa noua e cumparatura pe care o astepti). Lacomul le amana dupa
            # raportul castig/pret, iar durata erei sarea cu 20 de minute la o schimbare mica de cadru. Era 1 n-are
            # asemenea lista: ramane cum a fost reglata si jucata.
            # Si STRANGE pentru ele cand sunt aproape: daca banii care lipsesc vin in cel mult `patience` secunde de
            # venit, nu mai cumpara nimic altceva. Fara asta, nivelurile ieftine mananca fiecare moneda si plasa nu mai
            # vine niciodata (aceeasi capcana ca la oamenii capitolului 1 [D52]); cu o rabdare fara margine, ar sta cu
            # banii in mana sapte minute pentru o plasa scumpa, ceea ce nici un om nu face.
            eager = next((uid for uid in era.get("eager_unlocks", ()) if uid not in s.bought and uid in prices), None)
            if eager is not None:
                _uid, name, _why, cond, effect = next(e for e in unlocks if e[0] == eager)
                if cond(s):
                    if prices[eager] <= s.coins:
                        buy(f"unlock:{name}", "unlock", prices[eager], effect, eager)
                        reprice()
                        continue
                    if prices[eager] - s.coins <= income(s) * era.get("patience", 0.0):
                        break

            # QUEST-UL CERE NIVELUL 2 PE ULTIMA PLASA, iar un om il urmeaza. Singur, nivelul 2 nu da
            # nimic cand plasele nu sunt gatuirea, deci lacomul nu-l lua niciodata -- si plasa
            # urmatoare, pe care o deschide, venea cu 32 de minute mai tarziu [D49].
            # [D70] De la Era 4 plasele se cumpara amestecat (turbinele si plasele de cablu), deci quest-ul merge pe
            # familii: era isi spune singura ce plasa cere (`quest_net`). Fara ea, ultima plasa a erei, ca pana acum.
            quest_net = era.get("quest_net")
            if quest_net is not None:
                qi = quest_net(s)
            else:
                first_net, net_count = era["first_net"], era["net_count"]
                qi = (
                    len(s.nets) - 1
                    if first_net + 1 <= len(s.nets) < first_net + net_count and s.nets[-1].level < PREV_NET_LEVEL
                    else None
                )
            if qi is not None:
                i = qi
                cost = level_cost(net_upgrade_base(s, i), s.nets[i].level)
                if cost <= s.coins:

                    def up_last(st, idx=i):
                        st.nets[idx].level += 1

                    buy(f"Net {i + 1} lvl {PREV_NET_LEVEL} (quest)", "nets", cost, up_last, None)
                    continue

            opts = options(s, prices, era)
            scored = []
            income_now = income(s)
            for label, price, effect, kind, uid in opts:
                g = gain_of(s, effect, income_now)
                if price <= 0:
                    scored.append((float("inf"), label, price, effect, kind, uid, g))
                elif g > 1e-9:
                    scored.append((g / price, label, price, effect, kind, uid, g))
            pick = None
            if scored:
                scored.sort(key=lambda r: -r[0])
                best_ratio = scored[0][0]
                for r in scored:
                    if r[2] <= s.coins and (
                        r[0] >= SAVE_THRESHOLD * best_ratio or best_ratio == float("inf")
                    ):
                        pick = r
                        break
            else:
                # DOUA VERIGI LA FEL DE SLABE SE BLOCHEAZA RECIPROC. Cu min() dur, daca doua verigi
                # stau la aceeasi cifra, a urca doar una dintre ele da exact zero -- deci lacomia
                # ingheata. Un om nu se blocheaza asa: vede ce e gatuirea si baga acolo.
                bn = chain(s).bottleneck
                same = [
                    o
                    for o in opts
                    if o[1] <= s.coins
                    and (o[3] == bn if o[4] is None else UNLOCK_STAGE.get(o[4]) == bn)
                ]
                if not same:
                    # ECHIPAJ LA MAXIM PE VERIGA SLABA: nu mai e nimic de cumparat pe ea. Un om
                    # urmeaza quest-ul spre deblocarea urmatoare, nu cheltuie pe niveluri care nu
                    # dau nimic. Fara regula asta, cu 15% mai putin timp al jucatorului Era 1
                    # trecea de la 23 de minute la 1h03m [D49].
                    same = [o for o in opts if o[1] <= s.coins and o[4] is not None]
                if same:
                    same.sort(key=lambda o: o[1])
                    label, price, effect, kind, uid = same[0]
                    pick = (0.0, label, price, effect, kind, uid, gain_of(s, effect))
            if pick is None:
                break
            _, label, price, effect, kind, uid, _gain = pick
            buy(label, kind, price, effect, uid)
            # o deblocare noua poate deschide alte deblocari: re-evalueaza preturile
            reprice()

        if era["bell"] in s.bought:
            break
        now_chain = chain(s)
        silent = silent_lines(now_chain)
        if silent:
            raise SystemExit(f"EROARE: linia activa {silent[0]} n-are veriga slaba la {fmt(s.t)} lacom [D43, D70]")
        shares[now_chain.bottleneck] += 1
        for link in now_chain.solo:
            gain_time[link] += 1
        for line in LINE_ORDER:
            if now_chain.lines[line].supply > 0:  # [D70] `supply`: la o unire intra piesele, nu plase
                line_time[line] += 1
        inc = income(s)
        if inc <= 0:
            raise SystemExit("EROARE: venit zero, simularea nu poate avansa")
        s.coins += inc
        s.t += 1
        if s.t - started_at > max_seconds:
            raise SystemExit(f"EROARE: peste {max_seconds}s fara sa termine {era['name']}")

    # Ce n-a devenit accesibil in rulare (un al doilea Sawyer, daca treapta 3 n-a venit) are totusi
    # nevoie de un pret in config: se deriva din starea de la final, ca si cand s-ar fi deschis atunci.
    for uid, _name, _why, _cond, _effect in unlocks:
        if uid not in prices:
            prices[uid] = nice(income(s) * era["wait"](era["step"](s.bought)), last_price)
            last_price = max(last_price, prices[uid])

    # [D64] timpul fiecarei linii ramane pe stare, pentru erele care au alte linii decat fierul; al saptelea rezultat
    # ramane timpul fierului, cum il asteapta portile Erei 1 si tune_tycoon.py
    s.line_time = line_time
    s.gain_time = gain_time
    return s, rows, prices, longest_idle, income(s), shares, line_time["iron"]


# Linia care apare la coada fiecarei ere (fierul, cuprul): verigile ei se masoara doar pe timpul in care e deschisa.
LATE_LINE = {1: "iron", 2: "copper", 3: "power", 4: "crystal"}


def link_share(link, shares, late_time, era=1):
    """Cat din timp a fost `link` gatuirea. Verigile liniei tarzii a erei [D55, D56, D65] se masoara pe timpul in care
    linia e deschisa: ea apare abia la coada erei, iar pe toata era ar parea decor chiar daca tine venitul cand exista."""
    if link in LINE_LINKS[LATE_LINE[era]]:
        return shares[link] / late_time if late_time else 0.0
    total = sum(shares.values())
    return shares[link] / total if total else 0.0


def fmt(sec):
    m, x = divmod(int(sec), 60)
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m{x:02d}s"


def big(n):
    for unit, d in (("Qi", 1e18), ("Qa", 1e15), ("T", 1e12), ("B", 1e9), ("M", 1e6), ("K", 1e3)):
        if n >= d:
            return f"{n / d:.2f}".rstrip("0").rstrip(".") + unit
    return str(int(n))


def check_milestones():
    """Fiecare prag trebuie sa se SIMTA: un salt de peste 15% pe statia lui."""
    bad = []
    for level in MILESTONES[:3]:
        before = level_output(1.0, level - 1)
        after = level_output(1.0, level)  # cel mai mic increment: daca trece aici, trece peste tot
        if after / before < 1.15:
            bad.append(f"pragul {level}: salt de doar {(after / before - 1) * 100:.0f}%")
    return bad


def check_hire_order():
    """NICIO ANGAJARE NU SCADE VENITUL, oricand ar veni. Cand angajezi, pasul trece de la partea ta
    din timp (cu traista mare, in cel mai rau caz) la omul nou. Ca ultim pas fara om ii dadeai TOT
    timpul tau: cu ROLE_BASE 1.5, Hauler-ul scadea venitul de la 3.35 la 2.79/s [D49]. Sawyer-ul
    trece mereu (capacitatea intreaga e peste o parte din ea)."""
    bad = []
    labor = PLAYER_LABOR * SACK_BONUS
    for steps in LINE_STEPS.values():  # [D56] pe linii: fiecare linie are timpul tau intreg
        for i, role in enumerate(steps):
            n = len(steps) - i
            if role in ROLE_BASE and ROLE_BASE[role] < labor / n:
                bad.append(f"{role}: baza {ROLE_BASE[role]} sub partea ta din timp {labor / n:.2f} -> angajarea scade venitul")
    return bad


# 0.5%, NU 5% [D52]. Pana la D52 fiecare veriga trebuia sa fie gatuirea macar 5% din timp. Cu toti
# cinci oamenii angajati imediat dupa prima vanzare, un om la treapta 1 lucreaza de 7-12 ori mai repede
# decat o plasa: gaterul, Hauler-ul si taverna ies gatuire ~2-3% din Era 1 (0.7% in cel mai rau caz din
# --robust), iar ~200 de variante de constante n-au tinut 5% la +-15%. Owner-ul a ales ordinea stiind
# asta ("gaterul si taverna nu mai merita urcate in Era 1"). Pragul ramane ca sa prinda o veriga care
# nu e NICIODATA gatuirea.
MIN_BOTTLENECK_SHARE = 0.005
# [D62] Primele cinci minute: rafala de angajari, apoi nivelurile plasei si a doua plasa. Era 6 (cate una pe minut).
MIN_FIRST_FIVE = 20
CREW_BURST_REAL = 150
# [D56] COMPROMISUL LINIEI FIERULUI, ca in D52: pe linia fierului pasul cel mai lent e aproape mereu forja (~66% din
# timpul cu fier) sau Scrap Collector-ul (~30%). Iron Hauler-ul e ultimul om de drum, deci baza lui trebuie sa
# duca macar cat tot timpul tau (altfel angajarea lui ar putea scadea venitul): la baza asta e cel mai lent 0-0.5%
# din timp, iar Scrap Porter-ul la egalitate cu Scrap Collector-ul pierde alegerea. Treptele lor rar aduc ceva in
# Era 1 (meniul spune de ce). Owner-ul: "fierul este intr-adevar ceva care se face mai greu la inceput dar care
# aduce mai multi bani". Poarta de 0.5% ramane pentru toate celelalte verigi.
# [D65] Era 2 e in oglinda, deci si scutirile: Ore Porter si Copper Hauler. [D67] La fel Era 3: Battery Porter si Power
# Hauler.
BOTTLENECK_EXEMPT = {"scrapPort", "ironHaul", "orePort", "copperHaul", "batteryPort", "powerHaul", "crystalPort", "ingotHaul"}


def check_run(rows, longest_idle, shares, prices, scrap_time):
    """Portile care se masoara pe o rulare (si pe fiecare rulare din --robust)."""
    problems = []
    five_min = [r for r in rows if r[3] * REAL <= 300]
    if len(five_min) < MIN_FIRST_FIVE:
        problems.append(f"primele 5 minute reale au doar {len(five_min)} cumparaturi (minim {MIN_FIRST_FIVE}) [L1]")
    # [D62] Toti oamenii capitolului 1, in cel mult CREW_BURST_REAL secunde reale de la prima plasa
    hired = [r[3] * REAL for r in rows if r[1] == "unlock" and r[0] == "unlock:Innkeeper"]
    if not hired or hired[0] > CREW_BURST_REAL:
        when = fmt(hired[0]) if hired else "niciodata"
        problems.append(f"cei cinci oameni ai capitolului 1 sunt angajati abia la {when} real (maxim {fmt(CREW_BURST_REAL)})")
    if longest_idle > 180:
        problems.append(f"{fmt(longest_idle)} fara nimic de apasat (maxim 3 min)")
    # O veriga care e rar cea mai slaba e decor: jucatorul n-are de ce s-o urce, iar meniul ei ar
    # scrie "No gain yet" toata era [D48]. "Macar o data" nu ajungea: o veriga gatuire 1% din timp
    # trecea poarta si tot decor era.
    for link in ERA_LINKS[1]:
        if link in BOTTLENECK_EXEMPT:
            continue
        part = link_share(link, shares, scrap_time)
        if part < MIN_BOTTLENECK_SHARE:
            problems.append(f"veriga `{link}` e gatuirea doar {part * 100:.1f}% din timp (minim {MIN_BOTTLENECK_SHARE * 100:.1f}%) -- e decor")
    if prices.get("collector", 0) <= 0:
        problems.append("Collector-ul iese gratis: conditia lui e adevarata inainte de prima cumparatura")
    return problems


# [D65] PORTILE EREI 2, in oglinda cu ale Erei 1. Tinta owner-ului: cam o ora. Roata si a sasea plasa vin inaintea
# oamenilor, deci rafala celor cinci se masoara de la clopotul Erei 1 cu loc pentru ele.
ERA2_MIN_REAL, ERA2_MAX_REAL = 40 * 60, 75 * 60
# [D66, D71] CAT LUCREAZA SATUL FARA TINE (PassMath, OfflineCalc): viteza intreaga o noapte (16 h cu Long Nights), apoi un
# sfert din viteza pana la 24 h, apoi nimic pana revii (owner, 2026-10-01). Absenta de la sfarsitul unei ere, platita cu
# venitul de atunci, poate cumpara cel mult inceputul erei urmatoare: poarta se masoara pe cea mai lunga absenta platita,
# o zi intreaga fara pass-uri (12 h la viteza intreaga).
OFFLINE_HOURS = 8.0
OFFLINE_HOURS_LONG = 16.0
OFFLINE_STOP_HOURS = 24.0
OFFLINE_SLOW = 0.25
# [D70 Runda 4] "o noapte fara pass-uri la Works Bell", din care vine suma de start a barajului (35T): opt ore la viteza
# intreaga, oricum s-ar schimba curba de mai sus.
NIGHT_HOURS = 8.0
WINDFALL_MAX_SHARE = 0.25  # partea din timpul erei urmatoare pe care o poate sari cea mai lunga absenta


def offline_equiv_hours(away_hours: float, long_nights: bool = False) -> float:
    """[D71] Orele platite la viteza intreaga pentru o absenta de `away_hours` (ca OfflineCalc.paidSeconds)."""
    full = OFFLINE_HOURS_LONG if long_nights else OFFLINE_HOURS
    away = max(0.0, away_hours)
    return min(away, full) + max(0.0, min(away, OFFLINE_STOP_HOURS) - full) * OFFLINE_SLOW
ERA2_MIN_FIRST_FIVE = 15
ERA2_CREW_BURST_REAL = 360


def check_run_era(n, rows, longest_idle, shares, late_time, started_at, ended_at, min_share=None, gain_time=None):
    """Portile unei ere de dupa prima [D65, D67], aceleasi pentru toate: durata, primele 5 minute, rafala celor cinci
    oameni ai capitolului ei, pauza, verigile. `rows` sunt doar cumparaturile erei; timpii se numara de la clopotul erei
    dinainte. `min_share`: cat din timp trebuie sa fie fiecare veriga gatuirea (implicit MIN_BOTTLENECK_SHARE).
    [D70] `gain_time` (Era 4): o veriga e decor doar daca e rar cea mai slaba din sat SI rar are un castig real. Cu doua
    marfuri care aduc bani deodata (curentul unit si cristalul, mai scump), dupa ce se deschide cristalul veriga globala e
    aproape mereu a lui, desi pasii unirii aduc in continuare bani cand ii urci: masura veche le numara drept decor."""
    min_share = MIN_BOTTLENECK_SHARE if min_share is None else min_share
    problems = []
    real = (ended_at - started_at) * REAL
    if not ERA2_MIN_REAL <= real <= ERA2_MAX_REAL:
        problems.append(f"Era {n} dureaza {fmt(real)} reali (intre {fmt(ERA2_MIN_REAL)} si {fmt(ERA2_MAX_REAL)})")
    five_min = [r for r in rows if (r[3] - started_at) * REAL <= 300]
    if len(five_min) < ERA2_MIN_FIRST_FIVE:
        problems.append(f"Era {n}: primele 5 minute reale au doar {len(five_min)} cumparaturi (minim {ERA2_MIN_FIRST_FIVE})")
    last_hire = "unlock:" + ROLE_NAMES[LATER_ERAS[n]["chapter_hires"][-1]]
    hired = [(r[3] - started_at) * REAL for r in rows if r[0] == last_hire]
    if not hired or hired[0] > ERA2_CREW_BURST_REAL:
        when = fmt(hired[0]) if hired else "niciodata"
        problems.append(f"Era {n}: cei cinci oameni sunt angajati abia la {when} real (maxim {fmt(ERA2_CREW_BURST_REAL)})")
    if longest_idle > 180:
        problems.append(f"Era {n}: {fmt(longest_idle)} fara nimic de apasat (maxim 3 min)")
    for link in ERA_LINKS[n]:
        if link in BOTTLENECK_EXEMPT or link == "nets":
            continue
        part = link_share(link, shares, late_time, era=n)
        if gain_time is not None:
            # pe acelasi timp ca `link_share`: verigile liniei tarzii pe timpul ei, celelalte pe toata era
            span = late_time if link in LINE_LINKS[LATE_LINE[n]] else sum(shares.values())
            if span and gain_time[link] / span >= min_share:
                continue  # are castig real destul de des: meniul lui nu scrie "No gain yet"
        if part < min_share:
            problems.append(f"Era {n}: veriga `{link}` e gatuirea doar {part * 100:.1f}% din timp (minim {min_share * 100:.2f}%) -- e decor")
    return problems


def check_run_era2(rows, longest_idle, shares, late_time, started_at, ended_at, min_share=None):
    return check_run_era(2, rows, longest_idle, shares, late_time, started_at, ended_at, min_share)


# Id-ul platformei din TycoonConfig pentru fiecare deblocare de aici. Tine cele doua nume legate:
# fara el, verificarea de mai jos n-ar sti ce pret sa compare cu ce. Id-urile vechi raman [D49]:
# `first_runner` e acum platforma Collector-ului.
PAD_IDS = {
    "net1": "first_net", "net2": "second_net", "sack": "bigger_sack", "net3": "third_net",
    "collector": "first_runner", "porter": "hire_porter", "sawyer": "hire_sawyer", "hauler": "hire_hauler",
    "net4": "far_lane_net", "trader": "dock_trader", "net5": "fifth_net",
    "workshop": "workshop", "bell": "landing_bell", "shed": "scrap_shed",
    "scrapCollector": "hire_scrap_collector", "scrapPorter": "hire_scrap_porter", "smelter": "hire_smelter",
    "ironHauler": "hire_iron_hauler",
}
# [D65] platformele Erei 2
PAD_IDS_ERA2 = {
    "wheel": "water_wheel", "net6": "sixth_net", "millCollector": "hire_mill_collector",
    "millPorter": "hire_mill_porter", "founder": "hire_founder", "partsHauler": "hire_parts_hauler",
    "merchant": "hire_merchant", "net7": "seventh_net", "net8": "eighth_net", "net9": "ninth_net",
    "furnace": "copper_furnace", "net10": "tenth_net", "oreShed": "ore_shed",
    "oreCollector": "hire_ore_collector", "orePorter": "hire_ore_porter", "coppersmith": "hire_coppersmith",
    "copperHauler": "hire_copper_hauler", "bell2": "mill_bell",
}
# [D67] platformele Erei 3
PAD_IDS_ERA3 = {
    "steam": "steam_engine", "net11": "eleventh_net", "worksCollector": "hire_works_collector",
    "worksPorter": "hire_works_porter", "wiredrawer": "hire_wiredrawer", "coilHauler": "hire_coil_hauler",
    "clerk": "hire_clerk", "net12": "twelfth_net", "net13": "thirteenth_net", "net14": "fourteenth_net",
    "powerhouse": "power_house", "net15": "first_turbine", "batteryShed": "battery_shed",
    "batteryCollector": "hire_battery_collector", "batteryPorter": "hire_battery_porter",
    "electrician": "hire_electrician", "powerHauler": "hire_power_hauler", "bell3": "works_bell",
}


def _config_source(name: str) -> str:
    import os

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "Shared", "Config", name)
    return open(path, encoding="utf-8").read()


def check_config_prices(prices, pad_ids=None, roles=None):
    """Preturile din TycoonConfig.luau trebuie sa fie EXACT cele derivate aici. Implicit Era 1; Era 2 vine cu
    platformele si oamenii ei (`PAD_IDS_ERA2`, `ERA2_ROLES`).

    Pana la verificarea asta, testul Luau "preturile sunt exact cele din simulator" compara config-ul
    cu o lista scrisa de mana -- si pe 2026-09-12 config-ul avea Fifth Net 2500, Workshop 2800 si
    Landing Bell 13000 in timp ce simulatorul deriva 1500 / 1600 / 10000. Ambele treceau. Acum
    simulatorul citeste chiar fisierul Luau, deci o reglare facuta doar intr-o parte pica in CI.
    Al doilea om nu sta pe o platforma, deci pretul lui se citeste din `TycoonConfig.CREWS`.
    """
    import re

    src = _config_source("TycoonConfig.luau")
    bad = []
    for uid, pad_id in (pad_ids or PAD_IDS).items():
        m = re.search(r'id = "' + re.escape(pad_id) + r'",.*?price = (\d+),', src, re.S)
        if m is None:
            bad.append(f"TycoonConfig: nu gasesc pretul lui {pad_id}")
            continue
        have, want = int(m.group(1)), int(prices.get(uid, -1))
        if have != want:
            bad.append(f"TycoonConfig: {pad_id} costa {have}, simulatorul deriva {want}")
    crews = re.search(r"TycoonConfig\.CREWS = \{(.*?)\n\}", src, re.S)
    for role in roles or ERA1_ROLES:
        m = re.search(r"\b" + role + r" = \{[^}]*?secondPrice = (\d+)", crews.group(1)) if crews else None
        if m is None:
            bad.append(f"TycoonConfig.CREWS: nu gasesc secondPrice pentru {role}")
            continue
        have, want = int(m.group(1)), int(prices.get(f"{role}2", -1))
        if have != want:
            bad.append(f"TycoonConfig.CREWS.{role}: al doilea om costa {have}, simulatorul deriva {want}")
    return bad


# [D70] Erele scrise in configuratia jocului (StationConfig). Era 4 a intrat la pasul f al planului motorului, cu liniile si
# constantele ei; jocul o porneste abia la pasul j (StationConfig.ENGINE_ERAS), iar platformele ei vin cu harta barajului.
CONFIG_ERAS = (1, 2, 3, 4)


def check_config_constants():
    """Constantele oamenilor si ale gaterului din StationConfig.luau = cele de aici. Debitele le
    prind si testele de aur din ChainMath; costul treptelor si pragul celui de-al doilea om nu intra
    in debite, deci fara verificarea asta s-ar putea desparti in tacere."""
    import re

    src = _config_source("StationConfig.luau")
    bad = []
    scalars = {
        "PLAYER_LABOR": PLAYER_LABOR, "TIER_STEP": TIER_STEP, "TIER_MAX": TIER_MAX,
        "TIER_COST_BASE": TIER_COST_BASE, "TIER_COST_GROWTH": TIER_COST_GROWTH,
        "SECOND_AT_TIER": SECOND_AT_TIER, "MAX_PEOPLE": MAX_PEOPLE, "SACK_BONUS": SACK_BONUS,
        "SAW_BASE_RATE": SAW_BASE_RATE, "SAW_UPGRADE_BASE": SAW_UPGRADE_BASE,
        "DOCK_BASE_RATE": DOCK_BASE_RATE, "DOCK_UPGRADE_BASE": DOCK_UPGRADE_BASE,
        "NO_TRADER_FACTOR": NO_TRADER_FACTOR,
        "FORGE_BASE_RATE": FORGE_BASE_RATE, "FORGE_UPGRADE_BASE": FORGE_UPGRADE_BASE,
        # [D65] Era 2
        "ERA2_MULT": ERA2_MULT, "NETS_PER_ERA": NETS_PER_ERA,
        "FOUNDRY_BASE_RATE": FOUNDRY_BASE_RATE, "FOUNDRY_UPGRADE_BASE": FOUNDRY_UPGRADE_BASE,
        "FURNACE_BASE_RATE": FURNACE_BASE_RATE, "FURNACE_UPGRADE_BASE": FURNACE_UPGRADE_BASE,
        "MARKET_BASE_RATE": MARKET_BASE_RATE, "MARKET_UPGRADE_BASE": MARKET_UPGRADE_BASE,
        # [D67] Era 3
        "ERA3_MULT": ERA3_MULT,
        "WIREWORKS_BASE_RATE": WIREWORKS_BASE_RATE, "WIREWORKS_UPGRADE_BASE": WIREWORKS_UPGRADE_BASE,
        "POWERHOUSE_BASE_RATE": POWERHOUSE_BASE_RATE, "POWERHOUSE_UPGRADE_BASE": POWERHOUSE_UPGRADE_BASE,
        "DEPOT_BASE_RATE": DEPOT_BASE_RATE, "DEPOT_UPGRADE_BASE": DEPOT_UPGRADE_BASE,
        # [D70] Era 4: cadrul, cladirile, pragurile de venit ale capitolului si ale clopotului
        "ERA4_MULT": ERA4_MULT,
        "SWITCHYARD_BASE_RATE": SWITCHYARD_BASE_RATE, "SWITCHYARD_UPGRADE_BASE": SWITCHYARD_UPGRADE_BASE,
        "CABLEWORKS_BASE_RATE": CABLEWORKS_BASE_RATE, "CABLEWORKS_UPGRADE_BASE": CABLEWORKS_UPGRADE_BASE,
        "RELAY_BASE_RATE": RELAY_BASE_RATE, "RELAY_UPGRADE_BASE": RELAY_UPGRADE_BASE,
        "KILN_BASE_RATE": KILN_BASE_RATE, "KILN_UPGRADE_BASE": KILN_UPGRADE_BASE,
        "TOWN_BASE_RATE": TOWN_BASE_RATE, "TOWN_UPGRADE_BASE": TOWN_UPGRADE_BASE,
        "KILN_INCOME": KILN_INCOME, "DAM_BELL_INCOME": DAM_BELL_INCOME,
    }
    for name, want in scalars.items():
        # cu exponent: 1e12 s-ar fi citit 1
        m = re.search(r"StationConfig\." + name + r" = ([0-9.]+(?:[eE][+-]?[0-9]+)?)\b", src)
        if m is None:
            bad.append(f"StationConfig: lipseste {name}")
        elif float(m.group(1)) != float(want):
            bad.append(f"StationConfig.{name} = {m.group(1)}, simulatorul are {want}")
    passmath = open(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "Shared", "Modules", "PassMath.luau"),
        encoding="utf-8",
    ).read()
    for name, want in (
        ("OFFLINE_HOURS", OFFLINE_HOURS),
        ("OFFLINE_HOURS_LONG", OFFLINE_HOURS_LONG),
        ("OFFLINE_STOP_HOURS", OFFLINE_STOP_HOURS),  # [D71]
        ("OFFLINE_SLOW", OFFLINE_SLOW),
    ):
        m = re.search(r"PassMath\." + name + r" = ([0-9.]+)", passmath)
        if m is None or float(m.group(1)) != want:
            bad.append(f"PassMath.{name} = {m.group(1) if m else 'lipseste'}, simulatorul are {want:g} [D66, D71]")
    # [D70] factorul uneltelor, pe fiecare era din configuratie (lipsa = 1, de ambele parti)
    m = re.search(r"StationConfig\.TOOL_COST_MULT = \{([^}]*)\}", src)
    if m is None:
        bad.append("StationConfig: lipseste TOOL_COST_MULT")
    else:
        tools = {int(k): float(v) for k, v in re.findall(r"\[(\d+)\] = ([0-9.]+)", m.group(1))}
        for era in CONFIG_ERAS:
            if tools.get(era, 1.0) != float(ERA_TOOL_MULT.get(era, 1.0)):
                bad.append(f"StationConfig.TOOL_COST_MULT[{era}] = {tools.get(era, 1.0):g}, simulatorul are {ERA_TOOL_MULT.get(era, 1.0):g}")
    m = re.search(r"StationConfig\.ROLE_BASE = \{([^}]*)\}", src)
    have = dict((k, float(v)) for k, v in re.findall(r"(\w+) = ([0-9.]+)", m.group(1))) if m else {}
    want = {role: v for role, v in ROLE_BASE.items() if any(role in ERA_ROLES[era] for era in CONFIG_ERAS)}
    if have != want:
        bad.append(f"StationConfig.ROLE_BASE = {have}, simulatorul are {want}")
    return bad


# --robust: fiecare constanta a oamenilor, cu 15% in jos si in sus. Prima forma a modelului avea o
# prapastie la -15% (Era 1 de la 23 de minute la 1h44m) care nu se vedea pe cifrele de baza.
ROBUST_KNOBS = (
    "PLAYER_LABOR", "SAW_BASE_RATE", "TIER_STEP", "ROLE_BASE.collector", "ROLE_BASE.porter", "ROLE_BASE.hauler",
    "FORGE_BASE_RATE", "ROLE_BASE.scrapCollector", "ROLE_BASE.scrapPorter", "ROLE_BASE.ironHauler",
)
ROBUST_FACTORS = (0.85, 1.15)
ROBUST_MAX_REAL = 3600  # peste o ora reala = prapastia, nu o era mai lunga


def robust():
    failures = []
    module = sys.modules[__name__]
    print("\n--robust: fiecare constanta x0.85 si x1.15")
    for knob in ROBUST_KNOBS:
        for factor in ROBUST_FACTORS:
            if knob.startswith("ROLE_BASE."):
                role = knob.split(".")[1]
                original = ROLE_BASE[role]
                ROLE_BASE[role] = original * factor
            else:
                original = getattr(module, knob)
                setattr(module, knob, original * factor)
            VIOLATIONS.clear()
            tag = f"{knob} x{factor}"
            try:
                _s, rows, prices, idle, _final, shares, scrap_time = run()
                problems = list(VIOLATIONS) + check_hire_order() + check_run(rows, idle, shares, prices, scrap_time)
                real = rows[-1][3] * REAL
                if real > ROBUST_MAX_REAL:
                    problems.append(f"Era 1 dureaza {fmt(real)} reali (maxim {fmt(ROBUST_MAX_REAL)})")
                low = min(link_share(link, shares, scrap_time) for link in ERA_LINKS[1] if link not in BOTTLENECK_EXEMPT)
                print(f"  {tag:<24} {fmt(real):>7} real, cea mai slaba veriga {low * 100:4.1f}% din timp, pauza {fmt(idle)}")
            except SystemExit as e:
                problems = [str(e)]
                print(f"  {tag:<24} {e}")
            finally:
                if knob.startswith("ROLE_BASE."):
                    ROLE_BASE[knob.split(".")[1]] = original
                else:
                    setattr(module, knob, original)
            failures += [f"{tag}: {p}" for p in problems]
    VIOLATIONS.clear()
    return failures


# [D65] Constantele cartierului nou, cu 15% in jos si in sus, pe Era 2 jucata din finalul (neschimbat) al Erei 1:
# preturile Erei 1 sunt deja in joc, deci ea nu se mai misca odata cu ele.
ROBUST_KNOBS_ERA2 = (
    "FOUNDRY_BASE_RATE", "FURNACE_BASE_RATE", "MARKET_BASE_RATE", "ROLE_BASE.millCollector", "ROLE_BASE.millPorter",
    "ROLE_BASE.partsHauler", "ROLE_BASE.oreCollector", "ROLE_BASE.orePorter", "ROLE_BASE.copperHauler",
)


# [D67] si ale Erei 3, pe Era 3 jucata din finalul (neschimbat) al Morii
ROBUST_KNOBS_ERA3 = (
    "WIREWORKS_BASE_RATE", "POWERHOUSE_BASE_RATE", "DEPOT_BASE_RATE", "ROLE_BASE.worksCollector",
    "ROLE_BASE.worksPorter", "ROLE_BASE.coilHauler", "ROLE_BASE.batteryCollector", "ROLE_BASE.batteryPorter",
    "ROLE_BASE.powerHauler",
)
ROBUST_KNOBS_LATER = {2: ROBUST_KNOBS_ERA2, 3: ROBUST_KNOBS_ERA3}


def robust_era2(s1: State, prices1: dict):
    return robust_era(2, s1, prices1)


def robust_era(n: int, s_prev: State, prior_prices: dict):
    """Constantele cartierului erei `n`, cu 15% in jos si in sus, pe era jucata din finalul (neschimbat) al celei
    dinainte: preturile erelor dinainte sunt deja in joc, deci ele nu se mai misca odata cu ele."""
    failures = []
    module = sys.modules[__name__]
    print(f"\n--robust, Era {n}: fiecare constanta a cartierului nou x0.85 si x1.15")
    for knob in ROBUST_KNOBS_LATER[n]:
        for factor in ROBUST_FACTORS:
            if knob.startswith("ROLE_BASE."):
                role = knob.split(".")[1]
                original = ROLE_BASE[role]
                ROLE_BASE[role] = original * factor
            else:
                original = getattr(module, knob)
                setattr(module, knob, original * factor)
            VIOLATIONS.clear()
            tag = f"{knob} x{factor}"
            try:
                s_n, rows, _prices, idle, _final, shares, _ = run_era(n, clone(s_prev), prior_prices)
                problems = list(VIOLATIONS) + check_hire_order()
                # LA +-15% PRAGUL E PE JUMATATE. Poarta prinde o veriga care nu e NICIODATA gatuirea. Parts Hauler-ul e
                # ultimul om de drum (baza 9.0, ca Hauler-ul Erei 1, care la +15% tine venitul 0.6% din timp): cu 15% mai
                # iute il tine 0.4%. Rar, dar nu niciodata: meniul lui spune de ce, ca la gater si taverna in Era 1 [D52].
                problems += check_run_era(
                    n, rows, idle, shares, s_n.line_time[LATE_LINE[n]], s_prev.t, s_n.t, MIN_BOTTLENECK_SHARE / 2
                )
                print(f"  {tag:<28} {fmt((s_n.t - s_prev.t) * REAL):>7} real, {len(rows)} cumparaturi, pauza {fmt(idle)}")
            except SystemExit as e:
                problems = [str(e)]
                print(f"  {tag:<28} {e}")
            finally:
                if knob.startswith("ROLE_BASE."):
                    ROLE_BASE[knob.split(".")[1]] = original
                else:
                    setattr(module, knob, original)
            failures += [f"{tag}: {p}" for p in problems]
    VIOLATIONS.clear()
    return failures


def windfall(income_at_end, rows, started_at, ended_at, hours, mult=1.0):
    """[D66] Absenta de `hours` ore la sfarsitul unei ere (venitul de atunci, inmultit cu `mult` pentru 2x Flow):
    cate cumparaturi si deblocari ale erei urmatoare plateste, si ce parte din timpul ei sare."""
    budget = income_at_end * mult * hours * 3600
    spent, n, n_unlock, last_t, last_unlock = 0.0, 0, 0, started_at, "-"
    for label, kind, price, t, _after, _bn in rows:
        if spent + price > budget:
            break
        spent += price
        n += 1
        last_t = t
        if kind == "unlock":
            n_unlock, last_unlock = n_unlock + 1, label[7:]
    share = (last_t - started_at) / max(1, ended_at - started_at)
    return budget, n, n_unlock, last_unlock, share


def check_windfall(income1, rows, started_at, ended_at, era=2):
    """[D66] O ABSENTA NU CUMPARA ERA URMATOARE. Cu cadrul de dinainte (40), la sfarsitul Erei 1 o noapte platea 352 din
    398 de cumparaturi ale Erei 2. Regula tine pentru orice era noua: cel mult WINDFALL_MAX_SHARE din timpul ei, platit
    de cea mai lunga absenta (o zi, fara pass-uri; [D71] curba ii plateste OFFLINE_STOP_HOURS) din venitul erei dinainte.
    `era` = era platita."""
    hours = offline_equiv_hours(OFFLINE_STOP_HOURS)
    _budget, _n, _nu, last, share = windfall(income1, rows, started_at, ended_at, hours)
    if share > WINDFALL_MAX_SHARE:
        return [
            f"o zi de absenta ({OFFLINE_STOP_HOURS:g} h, cat {hours:g} h la viteza intreaga) la sfarsitul Erei {era - 1} sare "
            f"{share * 100:.0f}% din Era {era} (pana la {last}; maxim {WINDFALL_MAX_SHARE * 100:.0f}%)"
        ]
    return []


# ---- ERA 4: cele trei rulari si portile barajului [D70] ------------------------------------------------------------
class DamRun:
    """Era 4, jucata de trei ori din starea de la Works Bell (plan, sectiunea 5): fara bani, cu suma, capitolul."""

    def __init__(self, s3, prior_prices, max_seconds=200000):
        self.s3 = s3
        # 1. FARA BANI: preturile se fixeaza ca la orice era, din venitul din clipa in care devine accesibila deblocarea
        self.start_zero = dam_transform(s3, 0.0)
        (self.s_zero, self.rows_zero, self.prices, self.idle_zero, self.final_zero, self.shares_zero,
         _) = run(era=ERA4, start=clone(self.start_zero), max_seconds=max_seconds)
        # suma de start: cea mai mare dintre costul primelor 5 minute reale ale erei si o noapte fara pass-uri la clopot
        # (regula owner-ului, D70 Runda 4), rotunjita in sus
        self.c5 = sum(r[2] for r in self.rows_zero if (r[3] - self.start_zero.t) * REAL <= 300)
        self.night = income(s3) * NIGHT_HOURS * 3600
        self.start_sum = nice_up(max(self.c5, self.night))
        # 2. CU SUMA: cronologia adevarata, pe aceleasi preturi
        era = dict(ERA4)
        era["seed_prices"] = dict(self.prices)
        self.start = dam_transform(s3, float(self.start_sum))
        (self.s4, self.rows, _prices, self.idle, self.final, self.shares,
         _) = run(era=era, start=clone(self.start), max_seconds=max_seconds)
        self.late_time = self.s4.line_time[LATE_LINE[4]]
        # 3. CAPITOLUL (pasul k): plasele de cablu 2 si 3 luate cum ai banii, in ordinea capitolului, pe aceleasi preturi
        # (suma de start le cumpara din primul minut); Kiln-ul asteapta pasul de venit, clopotul pragul lui.
        chapter = dict(era)
        chapter["eager_unlocks"] = DAM_CHAPTER
        chapter["patience"] = DAM_CHAPTER_PATIENCE
        (self.s_chapter, self.rows_chapter, _prices, self.idle_chapter,
         *_) = run(era=chapter, start=clone(self.start), max_seconds=max_seconds)


def play_era4(s3: State, prior_prices: dict, max_seconds=200000) -> DamRun:
    return DamRun(s3, prior_prices, max_seconds)


# ce cumpara capitolul Erei 4 cum are banii, in ordine (Kiln-ul si cristalul sunt quest-urile erei)
DAM_CHAPTER = ("cableNet2", "cableNet3")
# cine urmeaza capitolul strange pentru pasul lui cand banii vin in cel mult atatea secunde de venit. Azi nu schimba nimic
# (0-120 s: aceeasi cronologie; ambele plase vin din suma de start). Cand capitolul avea si turbina a doua, fara rabdare
# ea venea la 47m, desi pasul de venit era atins la 37m.
DAM_CHAPTER_PATIENCE = 60.0
ERA_JUMP_MIN, ERA_JUMP_MAX = 8.0, 30.0  # venitul la baraj / venitul la Works Bell
DAM_HIRES_MAX_SHARE = 0.10  # cei sase costa cel mult atat din suma de start


def spend_share(budget, rows, started_at, ended_at):
    """Cate cumparaturi ale unei rulari plateste `budget`, in ordine, si ce parte din timpul ei sare."""
    spent, n, last_t, last_label = 0.0, 0, started_at, "-"
    for label, _kind, price, t, _after, _bn in rows:
        if spent + price > budget:
            break
        spent += price
        n += 1
        last_t, last_label = t, label
    return n, last_label, (last_t - started_at) / max(1, ended_at - started_at)


def longest_flat(rows, started_at, start_income, ended_at):
    """[D70] Cel mai lung tronson (secunde lacome) in care venitul nu creste: intre doua cumparaturi care il urca."""
    best, last_t, last_inc = 0.0, started_at, start_income
    for _label, _kind, _price, t, after, _bn in rows:
        if after > last_inc * (1 + 1e-9):
            best = max(best, t - last_t)
            last_t, last_inc = t, after
    return max(best, ended_at - last_t)


def longest_crawl(rows, started_at, start_income, ended_at, growth=0.10):
    """[D70] Cel mai lung tronson (secunde lacome) in care venitul creste sub `growth`: din orice punct, cat pana ajunge
    la (1 + growth) ori venitul de atunci. `longest_flat` vede doar cresterea exact zero; un sir de niveluri de plasa de
    +0.3% ar reporni-o la fiecare cumparatura, desi pe ecran cifra abia se misca [verificator, 2026-09-30]."""
    points = [(started_at, start_income)] + [(r[3], r[4]) for r in rows]
    best = 0.0
    for i, (t0, v0) in enumerate(points):
        target = v0 * (1 + growth) * (1 - 1e-9)
        t1 = next((t for t, v in points[i + 1:] if v >= target), ended_at)
        best = max(best, t1 - t0)
    return best


def dead_tiers(rows, roles, start_bottleneck=""):
    """[D70] Pentru fiecare meserie: cate trepte (si "al doilea om") cumparate CAT EA ERA VERIGA SLABA aratata de joc au
    dat castig zero, din cate cumparate asa. Cumparaturile facute doar ca sa inaintezi cand nimic nu mai aduce (ramura
    "ECHIPAJ LA MAXIM" din `run`) nu intra: nu le arata jocul ca pas urmator. Veriga dinaintea unei cumparaturi e cea de
    dupa cumparatura precedenta (intre doua cumparaturi starea nu se schimba)."""
    out = {}
    prev_income, prev_bn = None, start_bottleneck
    for label, _kind, _price, _t, after, bn in rows:
        for role in roles:
            name = ROLE_NAMES[role]
            if (label.startswith(name + " tier ") or label == "unlock:Second " + name) and prev_bn == LINK_OF[role]:
                dead, n = out.get(role, (0, 0))
                out[role] = (dead + (1 if prev_income is not None and after <= prev_income * (1 + 1e-12) else 0), n + 1)
        prev_income, prev_bn = after, bn
    return out


# O treapta pe veriga aratata poate da zero la o EGALITATE intre piese (unirea e tinuta de amandoua deodata): e cinstit
# [D46, riscul 3 din plan], iar ecranul numeste linia cealalta. O egalitate PERMANENTA (baze egale) le omoara insa pe
# toate: poarta pica daca mai mult de jumatate din treptele luate pe veriga aratata dau zero (Erele 1-3: cel mult 1 din 5).
def too_many_dead(dead: int, n: int) -> bool:
    return dead * 2 > n


def dam_ceiling(d: DamRun, before_kiln: bool = False) -> float:
    """[verificator, 2026-10-01] Plafonul spre care urca un pas de venit al capitolului; unul pus prea aproape se
    taraste. Dupa Kiln (pragul Dam Bell): toti oamenii Erei 4 la 2 x treapta 5, plasele si cladirile ei
    la nivelul 400, fara clopotul erei (x1.10). Inainte de Kiln (pasul lui): doar cei 11, trei plase de cablu, o turbina,
    fara cristal."""
    if before_kiln:
        c = clone(d.start)
        for uid in ("cableNet2", "cableNet3"):
            next(u[4] for u in ERA4_UNLOCKS if u[0] == uid)(c)
        roles = DAM_CREW
    else:
        c = clone(d.s4)
        c.bells = d.start.bells
        roles = ERA4_ROLES
    for role in roles:
        c.crews[role] = Crew(MAX_PEOPLE, TIER_MAX)
    for net in c.nets:
        if net.kind in DAM_NETS:
            net.level = max(net.level, 400)
    for name in ("switchyard", "cableworks", "relay", "kiln"):
        setattr(c, PROCESSORS[name]["level"], max(getattr(c, PROCESSORS[name]["level"]), 400))
    c.town_level = max(c.town_level, 400)
    return income(c)


# [D74] MONEDELE CUMPARATE CU ROBUX trec intregi peste suma de start (nimic platit nu se taie, D70). Ce le tine in frau e
# poarta asta, nu o taiere la jucator: in cel mai rau caz (Welcome Back x2 dupa o zi, cu Long Nights si 2x Flow) nu sar
# mai mult de atat din Era 4. Daca ar trece, se regleaza preturile aici.
PAID_COINS_MAX_SHARE = 0.40


def paid_coin_cases(d) -> list:
    """(eticheta, monedele platite peste suma de start) pe care le poate aduce un jucator la baraj."""
    bell = income(d.s3)
    return [
        ("+1 h Flow", bell * 3600),
        # [D71] cea mai lunga absenta platita: o zi (24 h) pe curba; Welcome Back x2 o mai da o data
        ("Welcome Back x2 dupa o zi", bell * offline_equiv_hours(OFFLINE_STOP_HOURS) * 3600),
        ("o zi cu Long Nights si 2x Flow", bell * 2 * offline_equiv_hours(OFFLINE_STOP_HOURS, True) * 3600),
    ]


def check_hire_guard(s3: State) -> list:
    """[D70, plan §8] PAZA NEGATIVA. Monotonia (nicio optiune nu scade venitul, `run`) o tine ORDINEA angajarilor, nu
    cifrele singure: Cable Collector-ul angajat ultimul, cand drumul lui e singurul pas de mana al bazinului (partea ta
    5.4 > baza lui 4.0), chiar scade venitul. Daca regula ar tine si fara ordine, verificarea monotoniei n-ar dovedi nimic
    despre conditiile platformelor; daca n-ar mai scadea, poarta se poate scoate. Si conditiile chiar opresc ordinea asta:
    Cable Porter-ul cere Cable Collector-ul."""
    problems = []
    s = dam_transform(s3, 0.0)
    unlock_net_ranked("cable_ore", 2, 1, 4)(s)
    unlock_net_ranked("cable_ore", 3, 2, 4)(s)
    for n in s.nets:
        if n.kind in ("dam", "cable_ore"):
            n.level = 30
    for role in DAM_HIRES:
        if role != "cableCollector":
            s.crews[role].count = 1
    s.crews["cablemaker"].tier = s.crews["relayKeeper"].tier = TIER_MAX
    for role in DAM_VETERANS:
        s.crews[role].tier = TIER_MAX
    before = income(s)
    late = clone(s)
    late.crews["cableCollector"].count = 1
    if not income(late) < before:
        problems.append("Era 4, paza negativa: Cable Collector-ul angajat ultimul nu mai scade venitul (poarta se poate scoate)")
    porter = next(u for u in ERA4_UNLOCKS if u[0] == "cablePorter")
    fresh = dam_transform(s3, 0.0)
    if porter[3](fresh):
        problems.append("Era 4: Cable Porter-ul se poate angaja inaintea Cable Collector-ului (ordinea tine monotonia)")
    return problems


def check_dam(d: DamRun, flat_before: float, crawl_before: float):
    """[D70] Portile barajului (plan, sectiunea 5), pe cele doua rulari."""
    problems = check_hire_guard(d.s3)
    # [D74] monedele platite, peste suma, sar cel mult PAID_COINS_MAX_SHARE din era
    for label, extra in paid_coin_cases(d):
        _n, last, share = spend_share(d.start_sum + extra, d.rows_zero, d.start_zero.t, d.s_zero.t)
        if share > PAID_COINS_MAX_SHARE:
            problems.append(
                f"Era 4: {label} ({big(extra)} platite peste suma) sare {share * 100:.0f}% din era "
                f"(pana la {last}; maxim {PAID_COINS_MAX_SHARE * 100:.0f}%) [D74]"
            )
    # suma sare cel mult WINDFALL_MAX_SHARE din cronologia fara bani
    _n, last, share = spend_share(d.start_sum, d.rows_zero, d.start_zero.t, d.s_zero.t)
    if share > WINDFALL_MAX_SHARE:
        problems.append(
            f"Era 4: suma de start ({big(d.start_sum)}) sare {share * 100:.0f}% din era (pana la {last}; "
            f"maxim {WINDFALL_MAX_SHARE * 100:.0f}%)"
        )
    # saltul de venit la baraj
    jump = income(d.start) / income(d.s3)
    if not ERA_JUMP_MIN <= jump <= ERA_JUMP_MAX:
        problems.append(f"Era 4: la baraj venitul sare de {jump:.1f} ori (intre {ERA_JUMP_MIN:g} si {ERA_JUMP_MAX:g})")
    # AWAY: dupa cei sase, cat lipsesti castigi macar cat la Works Bell; iar cei sase costa putin din suma
    hired = clone(d.start)
    for role in DAM_HIRES:
        hired.crews[role].count = 1
    away_bell, away_hired = away_income(d.s3), away_income(hired)
    if away_hired < away_bell:
        problems.append(f"Era 4: cu cei sase angajati, AWAY e {big(away_hired)}/s, sub Works Bell ({big(away_bell)}/s)")
    hires = sum(d.prices[uid] for uid in DAM_HIRES)
    if hires > DAM_HIRES_MAX_SHARE * d.start_sum:
        problems.append(f"Era 4: cei sase costa {big(hires)}, peste {DAM_HIRES_MAX_SHARE * 100:.0f}% din {big(d.start_sum)}")
    # platoul: cel mai lung tronson fara crestere, cel mult cat in Erele 1-3 (aceeasi rulare)
    flat = longest_flat(d.rows, d.start.t, income(d.start), d.s4.t)
    if flat > flat_before:
        problems.append(
            f"Era 4: venitul sta pe loc {fmt(flat * REAL)} reali (maxim {fmt(flat_before * REAL)}, cel mai lung din Erele 1-3)"
        )
    # si "tararea": cel mai lung tronson cu crestere sub 10%, cel mult cat in Erele 1-3
    crawl = longest_crawl(d.rows, d.start.t, income(d.start), d.s4.t)
    if crawl > crawl_before:
        problems.append(
            f"Era 4: venitul creste sub 10% timp de {fmt(crawl * REAL)} reali (maxim {fmt(crawl_before * REAL)}, cel mai "
            f"lung din Erele 1-3)"
        )
    # jucatorul care urmeaza capitolul (plasele cum are banii): platoul, "tararea", durata si pauza, ca la lacom
    for what, measure, limit in (("sta pe loc", longest_flat, flat_before), ("creste sub 10%", longest_crawl, crawl_before)):
        got = measure(d.rows_chapter, d.start.t, income(d.start), d.s_chapter.t)
        if got > limit:
            problems.append(
                f"Era 4, capitolul (plasele cum ai banii): venitul {what} {fmt(got * REAL)} reali (maxim {fmt(limit * REAL)})"
            )
    steps = (("Earn coins (Kiln)", KILN_INCOME, dam_ceiling(d, before_kiln=True)),
             ("Dam Bell", DAM_BELL_INCOME, dam_ceiling(d)))
    for what, need, ceiling in steps:
        if ceiling < need * DAM_STEP_MARGIN:
            problems.append(
                f"Era 4, capitolul: pasul {what} cere {big(need)}/s, prea aproape de plafonul lui "
                f"({big(ceiling)}/s; minim x{DAM_STEP_MARGIN:g})"
            )
    real = (d.s_chapter.t - d.start.t) * REAL
    if not ERA2_MIN_REAL <= real <= ERA2_MAX_REAL:
        problems.append(f"Era 4, capitolul: dureaza {fmt(real)} reali (intre {fmt(ERA2_MIN_REAL)} si {fmt(ERA2_MAX_REAL)})")
    if d.idle_chapter > 180:
        problems.append(f"Era 4, capitolul: {fmt(d.idle_chapter)} fara nimic de apasat (maxim 3 min)")
    # nicio meserie a erei cu trepte moarte in sir: veriga aratata de joc trebuie sa aduca ceva cand o urci [D46]
    for role, (dead, n) in dead_tiers(d.rows, ERA4_ROLES, chain(d.start).bottleneck).items():
        if too_many_dead(dead, n):
            problems.append(
                f"Era 4: {ROLE_NAMES[role]}: {dead} din {n} trepte si angajari luate cat era veriga slaba dau castig zero "
                f"(maxim jumatate)"
            )
    # al doilea om costa mai mult decat treapta 5 a meseriei lui, ca meniul sa nu-l arate drept treapta mai ieftina.
    # Podeaua (SECOND_FLOOR) e 1.25 x treapta 5 inainte de rotunjire; nice() poate lua pana la 7% (Cable Collector: 1.23x).
    for role in ERA4_ROLES:
        uid = role + "2"
        if uid in d.prices and d.prices[uid] <= tier_cost(TIER_MAX - 1, role):
            problems.append(
                f"Era 4: al doilea {ROLE_NAMES[role]} costa {big(d.prices[uid])}, nu peste treapta 5 "
                f"({big(tier_cost(TIER_MAX - 1, role))})"
            )
    return problems


ROBUST_KNOBS_ERA4 = (
    "SWITCHYARD_BASE_RATE", "CABLEWORKS_BASE_RATE", "RELAY_BASE_RATE", "KILN_BASE_RATE", "TOWN_BASE_RATE",
    "ROLE_BASE.damCollector", "ROLE_BASE.damPorter", "ROLE_BASE.barrelHauler", "ROLE_BASE.cableCollector",
    "ROLE_BASE.cablePorter", "ROLE_BASE.cableHauler", "ROLE_BASE.pylonRunner", "ROLE_BASE.crystalCollector",
    "ROLE_BASE.crystalPorter", "ROLE_BASE.ingotHauler",
)


def robust_era4(s3: State, prior_prices: dict, flat_before: float, crawl_before: float):
    """Constantele barajului, cu 15% in jos si in sus, pe Era 4 jucata din finalul (neschimbat) al Wire Works. Ca la
    Erele 2-3, pragul verigilor e pe jumatate; platoul are marja ROBUST_FLAT_SLACK."""
    failures = []
    module = sys.modules[__name__]
    print("\n--robust, Era 4: fiecare constanta a barajului x0.85 si x1.15")
    for knob in ROBUST_KNOBS_ERA4:
        for factor in ROBUST_FACTORS:
            if knob.startswith("ROLE_BASE."):
                role = knob.split(".")[1]
                original = ROLE_BASE[role]
                ROLE_BASE[role] = original * factor
            else:
                original = getattr(module, knob)
                setattr(module, knob, original * factor)
            VIOLATIONS.clear()
            tag = f"{knob} x{factor}"
            try:
                d = play_era4(clone(s3), prior_prices)
                problems = list(VIOLATIONS) + check_hire_order()
                problems += check_run_era(
                    4, d.rows, d.idle, d.shares, d.late_time, d.start.t, d.s4.t, MIN_BOTTLENECK_SHARE / 2,
                    gain_time=d.s4.gain_time,
                )
                problems += [
                    p for p in check_dam(d, flat_before * ROBUST_FLAT_SLACK, crawl_before * ROBUST_FLAT_SLACK)
                    if "trepte si angajari" not in p  # treptele moarte: doar pe cifrele de baza
                ]
                flat = longest_flat(d.rows, d.start.t, income(d.start), d.s4.t)
                crawl = longest_crawl(d.rows, d.start.t, income(d.start), d.s4.t)
                print(
                    f"  {tag:<28} {fmt((d.s4.t - d.start.t) * REAL):>7} real, start {big(d.start_sum)}, {len(d.rows)} "
                    f"cumparaturi, pauza {fmt(d.idle)}, platou {fmt(flat * REAL)}, tarare {fmt(crawl * REAL)}; capitolul "
                    f"{fmt((d.s_chapter.t - d.start.t) * REAL)}, pauza {fmt(d.idle_chapter)} lacom"
                )
            except SystemExit as e:
                problems = [str(e)]
                print(f"  {tag:<28} {e}")
            finally:
                if knob.startswith("ROLE_BASE."):
                    ROLE_BASE[knob.split(".")[1]] = original
                else:
                    setattr(module, knob, original)
            failures += [f"{tag}: {p}" for p in problems]
    VIOLATIONS.clear()
    return failures


def report_era4(d: DamRun, flats: dict, crawls: dict):
    rows, started = d.rows, d.start.t
    unlocks = [r for r in rows if r[1] == "unlock"]
    five_min = [r for r in rows if (r[3] - started) * REAL <= 300]
    c = chain(d.s4)
    money = {line: c.lines[line].delivered * line_avg(line) for line in LINE_ORDER if line not in CONSUMER_OF}
    total = sum(money.values()) or 1.0
    print(f"\nEra 4: {len(rows)} cumparaturi ({len(unlocks)} deblocari, {len(rows) - len(unlocks)} niveluri si trepte)")
    print(f"  terminata in {fmt(d.s4.t - started)} lacom  ->  {fmt((d.s4.t - started) * REAL)} real, de la baraj "
          f"(fara bani: {fmt((d.s_zero.t - d.start_zero.t) * REAL)} real)")
    print(f"  suma de start: {big(d.start_sum)} = max(primele 5 minute {big(d.c5)}, o noapte la Works Bell {big(d.night)}), "
          f"rotunjita in sus")
    print(f"  venit: la Works Bell {rate_txt(income(d.s3))}/s -> la baraj {rate_txt(income(d.start))}/s "
          f"(x{income(d.start) / income(d.s3):.1f}) -> la Dam Bell {rate_txt(d.final)}/s")
    hired = clone(d.start)
    for role in DAM_HIRES:
        hired.crews[role].count = 1
    hires = sum(d.prices[uid] for uid in DAM_HIRES)
    print(f"  AWAY: la Works Bell {rate_txt(away_income(d.s3))}/s, la baraj {rate_txt(away_income(d.start))}/s, "
          f"dupa cei sase {rate_txt(away_income(hired))}/s; cei sase costa {big(hires)} ({hires / d.start_sum * 100:.1f}% din suma)")
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim {ERA2_MIN_FIRST_FIVE})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {fmt(d.idle)}")
    kiln_at = next((r[3] for r in d.rows_chapter if r[0] == "unlock:Kiln"), d.s_chapter.t)
    print(
        f"  capitolul (plasele cum ai banii): {fmt((d.s_chapter.t - started) * REAL)} real, Kiln la "
        f"{fmt((kiln_at - started) * REAL)}, platou {fmt(longest_flat(d.rows_chapter, started, income(d.start), d.s_chapter.t) * REAL)}, "
        f"tarare {fmt(longest_crawl(d.rows_chapter, started, income(d.start), d.s_chapter.t) * REAL)}, "
        f"pauza {fmt(d.idle_chapter)} lacom ({fmt(d.idle_chapter * REAL)} reali); pasii de venit {big(KILN_INCOME)}/s "
        f"si Dam Bell {big(DAM_BELL_INCOME)}/s, plafoanele lor {big(dam_ceiling(d, before_kiln=True))}/s si {big(dam_ceiling(d))}/s"
    )
    print("  venitul sta pe loc cel mai mult: " + " | ".join(f"Era {n} {fmt(v * REAL)}" for n, v in flats.items()) + " (real)")
    print("  venitul creste sub 10% cel mai mult: " + " | ".join(f"Era {n} {fmt(v * REAL)}" for n, v in crawls.items()) + " (real)")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {link_share(link, d.shares, d.late_time, era=4) * 100:.1f}%" for link in ERA_LINKS[4])
        + f"  (cristalul: din {fmt(d.late_time)} cu Crystal Net)"
    )
    print("  la final: " + ", ".join(f"{LINE_WORDS.get(line, line)} {money[line] / total * 100:.1f}%" for line in ERA_LINES[4] if line in money))
    print("  oamenii la final: " + ", ".join(f"{ROLE_NAMES[r]} {d.s4.crews[r].count}x treapta {d.s4.crews[r].tier}" for r in ERA4_ROLES))
    print("\npreturile deblocarilor Erei 4, in ordinea cumpararii (timpul: de la baraj, cu suma de start):")
    for label, kind, price, t, inc, _bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<22} {big(price):>9}   la {fmt(t - started):>7} lacom / {fmt((t - started) * REAL):>7} real   venit {rate_txt(inc):>8}/s")
    never = [uid for uid, *_ in ERA4_UNLOCKS if uid not in d.s4.bought]
    if never:
        print("  necumparate in Era 4 (pret din starea de la final): " + ", ".join(f"{uid} {big(d.prices[uid])}" for uid in never))
    print(
        f"\n[D70, D74] suma de start si monedele Robux pastrate peste ea: cat din Era 4 (fara bani) sare "
        f"(poarta: {PAID_COINS_MAX_SHARE * 100:.0f}%)"
    )
    for label, extra in [("doar suma", 0.0)] + paid_coin_cases(d):
        n, last, share = spend_share(d.start_sum + extra, d.rows_zero, d.start_zero.t, d.s_zero.t)
        print(f"  {label:34s} {big(d.start_sum + extra):>8}: {n:3d} cumparaturi (pana la {last[7:] if last.startswith('unlock:') else last}), {share * 100:4.1f}% din timpul erei")


# [D67] Cum se cheama in raport marfa fiecarei linii si ce aduce linia tarzie a fiecarei ere
LINE_WORDS = {
    "parts": "piesele", "copper": "cuprul", "coils": "bobinele", "power": "curentul",
    "grid": "curentul unit", "crystal": "cristalul",  # [D70]
}
LATE_WORDS = {2: "cuprul: din {} cu minereu", 3: "curentul: din {} cu turbina"}


def rate_txt(v: float) -> str:
    """Un venit pe secunda in raport: cu doua zecimale sub un milion (asa l-a scris mereu raportul Morii), apoi scurt."""
    return f"{v:.2f}" if v < 1e6 else big(v)


def report_era2(s1, s2, rows, prices, longest_idle, final_income, shares, income1):
    report_era(2, s1, s2, rows, prices, longest_idle, final_income, shares, income1)


def report_era(n, s_prev, s_n, rows, prices, longest_idle, final_income, shares, income_prev):
    started = s_prev.t
    late = s_n.line_time[LATE_LINE[n]]
    unlocks = [r for r in rows if r[1] == "unlock"]
    five_min = [r for r in rows if (r[3] - started) * REAL <= 300]
    c = chain(s_n)
    money = {line: c.lines[line].delivered * line_avg(line) for line in LINE_ORDER}
    total = sum(money.values())
    old = sum(money[line] for k in range(1, n) for line in ERA_LINES[k])
    first, second = ERA_LINES[n]
    print(f"\nEra {n}: {len(rows)} cumparaturi ({len(unlocks)} deblocari, {len(rows) - len(unlocks)} niveluri si trepte)")
    print(f"  terminata in {fmt(s_n.t - started)} lacom  ->  {fmt((s_n.t - started) * REAL)} real, de la clopotul Erei {n - 1}")
    print(f"  venit: {rate_txt(income_prev)}/s -> {rate_txt(final_income)}/s  (x{final_income / income_prev:.1f})")
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim {ERA2_MIN_FIRST_FIVE})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {fmt(longest_idle)}")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {link_share(link, shares, late, era=n) * 100:.1f}%" for link in ERA_LINKS[n])
        + "  (" + LATE_WORDS[n].format(fmt(late)) + ")"
    )
    print(
        f"  la final: {'cartierul vechi' if n == 2 else 'cartierele vechi'} {old / total * 100:.1f}% din bani, "
        f"{LINE_WORDS[first]} {money[first] / total * 100:.1f}%, {LINE_WORDS[second]} {money[second] / total * 100:.1f}%"
    )
    print("  oamenii la final: " + ", ".join(f"{ROLE_NAMES[r]} {s_n.crews[r].count}x treapta {s_n.crews[r].tier}" for r in ERA_ROLES[n]))
    print(f"\npreturile deblocarilor Erei {n}, in ordinea cumpararii (timpul: de la clopotul Erei {n - 1}):")
    for label, kind, price, t, inc, bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<22} {big(price):>9}   la {fmt(t - started):>7} lacom / {fmt((t - started) * REAL):>7} real   venit {rate_txt(inc):>8}/s")
    never = [uid for uid, *_ in LATER_ERAS[n]["unlocks"] if uid not in s_n.bought]
    if never:
        print(f"  necumparate in Era {n} (pret din starea de la final): " + ", ".join(f"{uid} {big(prices[uid])}" for uid in never))
    print(f"\n[D66] absenta de la sfarsitul Erei {n - 1} ({income_prev:.1f}/s), cat din Era {n} plateste:")
    day, day_long = offline_equiv_hours(OFFLINE_STOP_HOURS), offline_equiv_hours(OFFLINE_STOP_HOURS, True)
    for label, hours, mult in (
        (f"o noapte ({OFFLINE_HOURS:g} h)", offline_equiv_hours(OFFLINE_HOURS), 1.0),
        (f"o zi ({OFFLINE_STOP_HOURS:g} h, cat {day:g} h)", day, 1.0),  # [D71] poarta
        (f"o zi cu Long Nights ({day_long:g} h)", day_long, 1.0),
        ("o zi cu Long Nights si 2x Flow", day_long, 2.0),
    ):
        budget, k, nu, last, share = windfall(income_prev, rows, started, s_n.t, hours, mult)
        print(f"  {label:32s} {big(budget):>8}: {k:3d} din {len(rows)} cumparaturi, {nu:2d} din {len(unlocks)} deblocari"
              f" (pana la {last}), {share * 100:4.1f}% din timpul erei")


if __name__ == "__main__":
    s1, rows, prices, longest_idle, final_income, shares, scrap_time = run()

    problems = (
        list(VIOLATIONS)
        + check_milestones()
        + check_hire_order()
        + check_config_prices(prices)
        + check_config_constants()
        + check_run(rows, longest_idle, shares, prices, scrap_time)
    )
    # [D65] Era 2, jucata din finalul Erei 1 (pe o clona: rapoartele Erei 1 de mai jos se uita tot la `s1`)
    era1_violations = len(VIOLATIONS)
    s2, rows2, prices2, idle2, final2, shares2, _ = run_era2(clone(s1), prices)
    problems += list(VIOLATIONS[era1_violations:])
    problems += check_run_era2(rows2, idle2, shares2, s2.line_time[LATE_LINE[2]], s1.t, s2.t)
    problems += check_windfall(final_income, rows2, s1.t, s2.t)
    problems += check_config_prices({**prices, **prices2}, PAD_IDS_ERA2, ERA2_ROLES)
    # [D67] Era 3, jucata din finalul Morii (tot pe o clona)
    prices12 = {**prices, **prices2}
    era2_violations = len(VIOLATIONS)
    s3, rows3, prices3, idle3, final3, shares3, _ = run_era(3, clone(s2), prices12)
    problems += list(VIOLATIONS[era2_violations:])
    problems += check_run_era(3, rows3, idle3, shares3, s3.line_time[LATE_LINE[3]], s2.t, s3.t)
    problems += check_windfall(final2, rows3, s2.t, s3.t, era=3)
    problems += check_config_prices({**prices12, **prices3}, PAD_IDS_ERA3, ERA3_ROLES)
    # [D70] Era 4, barajul, jucat din finalul Wire Works: doua rulari (fara bani, apoi cu suma de start)
    prices123 = {**prices12, **prices3}
    flats = {
        1: longest_flat(rows, 0.0, 0.0, s1.t),
        2: longest_flat(rows2, s1.t, final_income, s2.t),
        3: longest_flat(rows3, s2.t, final2, s3.t),
    }
    flat_before = max(flats.values())
    crawls = {
        1: longest_crawl(rows, 0.0, 0.0, s1.t),
        2: longest_crawl(rows2, s1.t, final_income, s2.t),
        3: longest_crawl(rows3, s2.t, final2, s3.t),
    }
    crawl_before = max(crawls.values())
    era3_violations = len(VIOLATIONS)
    dam = play_era4(clone(s3), prices123)
    flats[4] = longest_flat(dam.rows, dam.start.t, income(dam.start), dam.s4.t)
    crawls[4] = longest_crawl(dam.rows, dam.start.t, income(dam.start), dam.s4.t)
    problems += list(VIOLATIONS[era3_violations:])
    problems += check_run_era(
        4, dam.rows, dam.idle, dam.shares, dam.late_time, dam.start.t, dam.s4.t, gain_time=dam.s4.gain_time
    )
    problems += check_dam(dam, flat_before, crawl_before)
    # [D64] motorul chiar duce oricate linii: linii de proba pe o COPIE a modulului, comparate cu cifre socotite de mana
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import check_lines

    problems += check_lines.problems()
    for _seller, _spec in SELLERS.items():
        # vanzatorul da capacitatea comuna in ordinea din `priority`; asta e cea mai buna impartire doar cat bucata
        # fiecarei linii valoreaza macar cat a celei de dupa ea [D55]
        for _first, _then in zip(_spec["priority"], _spec["priority"][1:]):
            if line_avg(_first) < line_avg(_then):
                problems.append(
                    f"{_seller}: bucata liniei {_first} ({line_avg(_first):.2f}) valoreaza sub a liniei {_then}"
                    f" ({line_avg(_then):.2f}), desi se vinde inaintea ei"
                )
    if "--robust" in sys.argv:
        problems += robust()
        problems += robust_era(2, s1, prices)
        problems += robust_era(3, s2, prices12)
        problems += robust_era4(s3, prices123, flat_before, crawl_before)

    if problems:
        print("EROARE -- economia nu trece portile:")
        for p in problems:
            print("  " + p)
        sys.exit(1)

    five_min = [r for r in rows if r[3] * REAL <= 300]

    if "--table" in sys.argv:
        print(f"{'#':>3} {'cumparatura':<26} {'fel':>7} {'pret':>8} {'lacom':>8} {'real~':>8} {'venit/s':>9} {'gatuire':>8}")
        for i, (label, kind, price, t, inc, bn) in enumerate(rows, 1):
            print(
                f"{i:>3} {label:<26} {kind:>7} {big(price):>8} {fmt(t):>8} {fmt(t * REAL):>8} {inc:>9.2f} {bn:>8}"
            )

    if "--chain" in sys.argv:
        c = chain(s1)
        print(
            f"\nlantul la finalul Erei 1:  lemn prins {c.wood_catch:.2f}/s | adunat {c.collect:.2f}/s | dus {c.port:.2f}/s"
            f" | taiat {c.sawing:.2f}/s | dus la taverna {c.haul:.2f}/s"
        )
        print(
            f"  fierul: scrap prins {c.scrap_catch:.2f}/s | adunat {c.scrap_collect:.2f}/s | dus {c.scrap_port:.2f}/s"
            f" | topit {c.forging:.2f}/s | dus la taverna {c.iron_haul:.2f}/s | vandut (amandoua) {c.sales:.2f}/s"
        )
        share = c.scrap * AVG["scrap"] / max(1e-9, c.wood * AVG["wood"] + c.scrap * AVG["scrap"])
        print(
            f"  livrat: lemn {c.wood:.2f}/s, fier {c.scrap:.2f}/s ({share * 100:.0f}% din bani); veriga slaba: {c.bottleneck}"
            f" (lemn {c.wood_bottleneck}, fier {c.iron_bottleneck})"
        )

    unlocks = [r for r in rows if r[1] == "unlock"]
    levels = [r for r in rows if r[1] != "unlock"]
    total = sum(shares.values())
    print(f"\nEra 1: {len(rows)} cumparaturi ({len(unlocks)} deblocari, {len(levels)} niveluri si trepte)")
    print(f"  terminata in {fmt(rows[-1][3])} lacom  ->  {fmt(rows[-1][3] * REAL)} real")
    print(
        f"  cu darurile raului prinse pe jumatate (+{drift_bonus() * 100:.0f}% venit, estimare): "
        f"~{fmt(rows[-1][3] * REAL / (1 + drift_bonus()))} real; cu toate (+{drift_bonus(1.0) * 100:.0f}%): "
        f"~{fmt(rows[-1][3] * REAL / (1 + drift_bonus(1.0)))}"
    )
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim {MIN_FIRST_FIVE})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {fmt(longest_idle)}")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {link_share(link, shares, scrap_time) * 100:.1f}%" for link in ERA_LINKS[1])
        + f"  (forja: din {fmt(scrap_time)} cu scrap)"
    )
    print("  oamenii la final: " + ", ".join(f"{ROLE_NAMES[r]} {s1.crews[r].count}x treapta {s1.crews[r].tier}" for r in ERA1_ROLES))
    print(f"  venit final: {final_income:.2f}/s")
    print("\npreturile deblocarilor, in ordinea cumpararii:")
    for label, kind, price, t, inc, bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<18} {big(price):>9}   la {fmt(t):>7} lacom / {fmt(t * REAL):>7} real   venit {inc:>7.2f}/s")
    never = [uid for uid, *_ in ERA1_UNLOCKS if uid not in s1.bought]
    if never:
        print("  necumparate in Era 1 (pret din starea de la final): " + ", ".join(f"{uid} {big(prices[uid])}" for uid in never))

    if "--table" in sys.argv:
        print(f"\n{'#':>3} {'cumparatura (Era 2)':<30} {'fel':>8} {'pret':>8} {'real~':>8} {'venit/s':>10} {'gatuire':>12}")
        for i, (label, kind, price, t, inc, bn) in enumerate(rows2, 1):
            print(f"{i:>3} {label:<30} {kind:>8} {big(price):>8} {fmt((t - s1.t) * REAL):>8} {inc:>10.2f} {bn:>12}")
    report_era(2, s1, s2, rows2, prices2, idle2, final2, shares2, final_income)
    if "--table" in sys.argv:
        print(f"\n{'#':>3} {'cumparatura (Era 3)':<30} {'fel':>8} {'pret':>8} {'real~':>8} {'venit/s':>10} {'gatuire':>14}")
        for i, (label, kind, price, t, inc, bn) in enumerate(rows3, 1):
            print(f"{i:>3} {label:<30} {kind:>8} {big(price):>8} {fmt((t - s2.t) * REAL):>8} {big(inc):>10} {bn:>14}")
    report_era(3, s2, s3, rows3, prices3, idle3, final3, shares3, final2)
    if "--table" in sys.argv:
        print(f"\n{'#':>3} {'cumparatura (Era 4)':<30} {'fel':>8} {'pret':>8} {'real~':>8} {'venit/s':>10} {'gatuire':>14}")
        for i, (label, kind, price, t, inc, bn) in enumerate(dam.rows, 1):
            print(f"{i:>3} {label:<30} {kind:>8} {big(price):>8} {fmt((t - dam.start.t) * REAL):>8} {big(inc):>10} {bn:>14}")
    report_era4(dam, flats, crawls)
