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
LEVEL_INC_BY_KIND = {"nets": 0.03, "saw": 0.06, "dock": 0.06, "foundry": 0.06, "market": 0.06, "furnace": 0.06}
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
NET_LANES = (1, 1, 2, 2, 3, 1, 1, 2, 2, 3)  # pe ce banda sta fiecare plasa: Era 1, apoi Era 2
# [D55] ultima plasa a Erei 1, cea din larg, prinde scrap; [D65] plasele Morii prind scrap pentru turnatorie, ultima minereu
NET_KINDS = ("wood", "wood", "wood", "wood", "scrap", "mill", "mill", "mill", "mill", "ore")

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
ROLES = ERA1_ROLES + ERA2_ROLES

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
LINE_ORDER = ("wood", "iron", "parts", "copper")
ERA_LINES = {1: ("wood", "iron"), 2: ("parts", "copper")}
LINES = {
    "wood": {
        "netKind": "wood", "openFlag": None, "seller": "dock",
        "steps": (("collector", "collect", "walk"), ("porter", "port", "walk"),
                  ("sawyer", "saw", "processor"), ("hauler", "haul", "walk")),
    },
    "iron": {
        "netKind": "scrap", "openFlag": "workshop", "seller": "dock",
        "steps": (("scrapCollector", "scrapCollect", "walk"), ("scrapPorter", "scrapPort", "walk"),
                  ("smelter", "forge", "processor"), ("ironHauler", "ironHaul", "walk")),
    },
    # [D65] Era 2: piesele de masini (roata de apa porneste turnatoria) si cuprul (cuptorul de cupru), la Piata
    "parts": {
        "netKind": "mill", "openFlag": "wheel", "seller": "market",
        "steps": (("millCollector", "millCollect", "walk"), ("millPorter", "millPort", "walk"),
                  ("founder", "foundry", "processor"), ("partsHauler", "partsHaul", "walk")),
    },
    "copper": {
        "netKind": "ore", "openFlag": "furnace", "seller": "market",
        "steps": (("oreCollector", "oreCollect", "walk"), ("orePorter", "orePort", "walk"),
                  ("coppersmith", "furnace", "processor"), ("copperHauler", "copperHaul", "walk")),
    },
}
# Cladirile cu niveluri: numele constantei de baza si campul din State cu nivelul. Veriga e si felul din
# LEVEL_INC_BY_KIND.
PROCESSORS = {
    "saw": {"base": "SAW_BASE_RATE", "level": "saw_level"},
    "forge": {"base": "FORGE_BASE_RATE", "level": "forge_level"},
    "foundry": {"base": "FOUNDRY_BASE_RATE", "level": "foundry_level"},
    "furnace": {"base": "FURNACE_BASE_RATE", "level": "furnace_level"},
}
# Vanzatorii: omul lor nu are baza, inmulteste capacitatea cladirii (fara el merge la NO_TRADER_FACTOR).
SELLERS = {
    "dock": {"role": "trader", "base": "DOCK_BASE_RATE", "level": "dock_level", "priority": ("iron", "wood")},
    "market": {"role": "merchant", "base": "MARKET_BASE_RATE", "level": "market_level", "priority": ("copper", "parts")},
}



def derive_tables(line_order, lines, sellers, roles):
    """Tabelele de lucru, DERIVATE din LINES / SELLERS ca sa nu existe doua liste care sa se desparta. Intoarce
    (LINE_STEPS, LINE_LINKS, LINE_OF_ROLE, LINK_OF, LINKS) si pica pe un tabel care nu se leaga. E functie, nu cod de
    modul, pentru ca check_lines.py o cheama din nou dupa ce adauga linii de proba."""
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
        assert line in sellers[lines[line]["seller"]]["priority"], f"linia {line} lipseste din randul vanzatorului ei"
    for seller, spec in sellers.items():
        assert all(lines[l]["seller"] == seller for l in spec["priority"]), f"{seller}: o linie de-a altui vanzator"
    return line_steps, line_links, line_of_role, link_of, links


LINE_STEPS, LINE_LINKS, LINE_OF_ROLE, LINK_OF, LINKS = derive_tables(LINE_ORDER, LINES, SELLERS, ROLES)
ROLE_NAMES = {
    "collector": "Collector", "porter": "Porter", "sawyer": "Sawyer", "hauler": "Hauler", "trader": "Innkeeper",
    "scrapCollector": "Scrap Collector", "scrapPorter": "Scrap Porter", "smelter": "Smelter", "ironHauler": "Iron Hauler",
    "millCollector": "Mill Collector", "millPorter": "Mill Porter", "founder": "Founder", "partsHauler": "Parts Hauler",
    "merchant": "Merchant", "oreCollector": "Ore Collector", "orePorter": "Ore Porter", "coppersmith": "Coppersmith",
    "copperHauler": "Copper Hauler",
}
# Verigile fiecarei ere (plasele sunt ale tuturor): portile si rapoartele unei ere se uita doar la ale ei.
ERA_LINKS = {
    era: ("nets",) + tuple(link for line in lines for link in LINE_LINKS[line])
    + tuple(seller for seller in SELLERS if any(LINES[line]["seller"] == seller for line in lines))
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
    price_mult: float = 1.0
    bells: float = 1.0
    index_found: int = 0
    rebirths: int = 0
    bought: set = field(default_factory=set)


def tier_mult(tier: int) -> float:
    return 1 + TIER_STEP * (tier - 1)


# [D64] Treptele costa fix (25 / 75 / 225 / 675) pentru oamenii Erei 1. Oamenii unei ere noi muta marfa de zeci de ori
# mai scumpa, deci si uneltele lor costa pe masura: rolul -> de cate ori. Gol = toti la 1 (Era 1, neschimbata).
ROLE_COST_MULT = {role: ERA2_MULT for role in ERA2_ROLES}


def tier_cost(tier: int, role: str = None) -> float:
    """Cat costa trecerea de la treapta `tier` la `tier + 1`."""
    return TIER_COST_BASE * TIER_COST_GROWTH ** (tier - 1) * ROLE_COST_MULT.get(role, 1.0)


def line_open(s: State, line: str) -> bool:
    """O linie fara conditie e deschisa de la inceput. Una cu conditie cere campul ei din State si o plasa de felul
    ei. [D56] Pana la oamenii ei, culesul si dusul sunt pasii tai de mana, ca turul de lemn din capitolul 1."""
    flag = LINES[line]["openFlag"]
    if flag is None:
        return True
    kind = LINES[line]["netKind"]
    return bool(getattr(s, flag)) and any(n.kind == kind for n in s.nets)


def manual_steps(s: State, line: str = "wood") -> int:
    """Cati din pasii unei linii n-au inca om (0 cat linia e inchisa)."""
    if not line_open(s, line):
        return 0
    return sum(1 for r in LINE_STEPS[line] if s.crews[r].count == 0)


def player_share(s: State, line: str) -> float:
    """Partea ta din timp pe fiecare pas fara om al liniei; 0 cand linia n-are pasi de mana."""
    n = manual_steps(s, line)
    if n == 0:
        return 0.0
    labor = PLAYER_LABOR * (SACK_BONUS if s.sack_big else 1.0)
    return labor / n


def walk_rate(s: State, role: str) -> float:
    """Un pas de drum: oamenii lui, sau partea ta din timp pe linia lui."""
    crew = s.crews[role]
    if crew.count > 0:
        return ROLE_BASE[role] * tier_mult(crew.tier) * crew.count
    return player_share(s, LINE_OF_ROLE[role])


def processor_rate(s: State, line: str, role: str, link: str) -> float:
    """O cladire cu niveluri (gaterul [D48], forja [D56]): oamenii ei o tin pornita tot timpul; fara ei merge doar cat
    stai tu langa ea. Cat linia e inchisa, nimic. Constanta de baza se citeste dupa nume, la fiecare apel."""
    if not line_open(s, line):
        return 0.0
    spec = PROCESSORS[link]
    cap = level_output(globals()[spec["base"]], getattr(s, spec["level"]), link)
    crew = s.crews[role]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    return cap / manual_steps(s, line)


def seller_rate(s: State, seller: str) -> float:
    """Un vanzator (taverna): singurul pas pe care NU-l faci tu. Fara omul lui vinde si singur, incet."""
    spec = SELLERS[seller]
    cap = level_output(globals()[spec["base"]], getattr(s, spec["level"]), seller)
    crew = s.crews[spec["role"]]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    return cap * NO_TRADER_FACTOR


def line_avg(line: str) -> float:
    """Cat valoreaza, in medie, o bucata livrata pe linia asta."""
    return AVG[LINES[line]["netKind"]]


@dataclass
class LineFlow:
    """Ce curge pe o linie, pe secunda."""
    catch: float  # cat prind plasele ei (0 cat linia e inchisa)
    rates: tuple  # ((veriga, debit), ...) in ordinea pasilor, fara plase
    own_max: float  # marginea liniei inaintea vanzatorului: minimul dintre plase si pasi
    active: bool  # intra in socoteala verigilor: mereu pentru o linie fara conditie, altfel doar cat prinde ceva
    room: float = 0.0  # cat mai avea vanzatorul cand i-a venit randul
    delivered: float = 0.0  # bucati livrate
    by_seller: bool = False  # vanzatorul e marginea liniei
    bottleneck: str = ""  # veriga slaba a liniei ("" cat nu e activa)

    def links(self) -> tuple:
        """Toate verigile liniei, cu plasele in fata: ordinea in care se cauta primul minim."""
        return (("nets", self.catch),) + self.rates


class Chain:
    """Lantul intreg. `lines` si `capacity` sunt adevarul; numele plate de mai jos (wood_catch, sawing, sales, ...) sunt
    VEDEREA Erei 1 peste ele: asa le citesc golden_chain.py (tabelul de aur din tests/ChainMath.test.luau) si raportul
    `--chain`. O linie noua nu primeste nume plat: se citeste din `lines`."""

    def __init__(self, lines: dict, capacity: dict):
        self.lines = lines  # {linie: LineFlow}
        self.capacity = capacity  # {vanzator: bucati pe secunda}
        self.bottleneck = "nets"  # veriga care tine venitul

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
    exacta pentru doua. Inainte de a treia, intai teste socotite de mana (docs/PLAN-MOTOR-N-LINII.md)."""
    gains = {link: 0.0 for link in LINKS}
    for seller, spec in SELLERS.items():
        order = spec["priority"]
        for i, line in enumerate(order):
            f = c.lines[line]
            if not f.active or f.by_seller:
                continue
            displaced = next((other for other in order[i + 1:] if c.lines[other].by_seller), None)
            gain = line_avg(line) if displaced is None else line_avg(line) - line_avg(displaced)
            for link, value in f.links():
                if value == f.delivered:
                    gains[link] = max(gains[link], gain)
        held = next((line for line in order if c.lines[line].by_seller), None)
        if held is not None:
            gains[seller] = line_avg(held)
    best = "nets"
    for link in LINKS:
        if gains[link] > gains[best]:
            best = link
    for line in LINE_ORDER:
        f = c.lines[line]
        if not f.active:
            f.bottleneck = ""
        elif f.by_seller:
            f.bottleneck = LINES[line]["seller"]
        else:
            f.bottleneck = next(link for link, value in f.links() if value == f.own_max)
    return best


def chain(s: State) -> Chain:
    """Liniile [D49, D56]: fiecare cu oamenii ei; cele care au acelasi vanzator impart doar capacitatea lui. El vinde
    in ordinea din `priority` (intai marfa mai scumpa) cat poate aduce fiecare linie, iar urmatoarea ia restul. Orice
    capacitate in plus doar largeste ce se poate, deci nicio cumparatura nu scade venitul."""
    lines = {}
    for line in LINE_ORDER:
        spec = LINES[line]
        catch = 0.0
        if line_open(s, line):
            for n in s.nets:
                if n.kind == spec["netKind"]:
                    catch += n.rate()
        rates = tuple(
            (link, walk_rate(s, role) if kind == "walk" else processor_rate(s, line, role, link))
            for role, link, kind in spec["steps"]
        )
        own_max = min([catch] + [value for _link, value in rates])
        lines[line] = LineFlow(catch, rates, own_max, spec["openFlag"] is None or catch > 0.0)
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
    c = Chain(lines, capacity)
    c.bottleneck = bottlenecks(c)
    return c


def income(s: State) -> float:
    c = chain(s)
    gross = 0.0
    for line in LINE_ORDER:  # ordine fixa: aceeasi suma, bit cu bit, la fiecare rulare si in ChainMath.luau
        gross += c.lines[line].delivered * line_avg(line)
    return (
        gross
        * s.price_mult
        * s.bells
        * (1 + 0.01 * s.index_found)
        * (1 + 0.5 * s.rebirths)
    )


# ---- deblocarile ------------------------------------------------------------------------------
# Fiecare are un MOTIV: C=prinzi mai mult, V=vinzi mai scump, A=scapi de o corvoada, D=deschizi.


def net_base(k: int) -> float:
    """Baza plasei k (de la 1): a k-a plasa a unei ere are baza celei de-a k-a plase a Erei 1 [D65]."""
    return NET_BASE_RATE * NET_BASE_GROWTH ** ((k - 1) % NETS_PER_ERA)


def net_era_mult(k: int) -> float:
    """De cate ori costa mai mult nivelurile plasei k (de la 1): 1 in Era 1, ERA2_MULT in Era 2."""
    return 1.0 if k <= NETS_PER_ERA else ERA2_MULT


def unlock_net(k: int):
    def f(s: State):
        s.nets.append(Net(net_base(k), NET_LANES[k - 1], kind=NET_KINDS[k - 1]))

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


def run_era2(start: State, era1_prices: dict, max_seconds=200000):
    """Joaca Era 2 din starea in care s-a terminat Era 1. Al doilea om al Erei 1, ramas necumparat, isi tine pretul."""
    era = dict(ERA2)
    era["seed_prices"] = {uid: price for uid, price in era1_prices.items() if uid not in start.bought and uid in {f"{r}2" for r in ERA1_ROLES}}
    return run(era=era, start=start, max_seconds=max_seconds)


NICE = (1, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3, 3.5, 4, 4.5, 5, 5.5, 6, 7, 7.5, 8, 9)


def nice(x: float, floor: int = 0) -> int:
    """Pret 'rotund' pe care il citeste un copil dintr-o privire, si STRICT mai mare decat
    pretul deblocarii anterioare."""
    if x < 10:
        v = max(0, int(round(x)))
        return v if v > floor else floor + 1
    for mag in (10**k for k in range(0, 13)):
        for n in NICE:
            v = int(n * mag)
            if v >= x * 0.93 and v > floor:
                return v
    return int(x)


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
}


def net_upgrade_base(s: State, i: int) -> float:
    """Costul de baza al nivelurilor plasei de pe locul `i` (de la 0): creste cu locul ei in era, de `net_era_mult` ori
    in erele noi. Plasele se cumpara in ordine, deci locul in `s.nets` e si numarul plasei."""
    own = s.nets[i].upgrade_base
    if own is not None:
        return own
    return NET_UPGRADE_BASE_COST * NET_BASE_GROWTH ** (i % NETS_PER_ERA) * net_era_mult(i + 1)


def options(s: State, prices: dict, era=None):
    """Tot ce poate cumpara jucatorul ACUM: deblocarile erei a caror conditie e implinita, un nivel pe
    orice cladire detinuta si o treapta pe orice meserie cu oameni. Intoarce (eticheta, pret, efect,
    fel, uid)."""
    era = era or ERA1
    out = []
    for uid, name, _why, cond, effect in era["unlocks"]:
        if uid in s.bought or not cond(s):
            continue
        if uid in prices:
            out.append((f"unlock:{name}", prices[uid], effect, "unlock", uid))

    for i, n in enumerate(s.nets):
        base_cost = net_upgrade_base(s, i)

        def up_net(st, idx=i):
            st.nets[idx].level += 1

        out.append(
            (f"Net {i + 1} lvl {n.level + 1}", level_cost(base_cost, n.level), up_net, "nets", None)
        )

    for kind, spec in BUILDINGS.items():
        if spec["owned"] is not None and not getattr(s, spec["owned"]):
            continue
        level = getattr(s, spec["level"])

        def up_building(st, field=spec["level"]):
            setattr(st, field, getattr(st, field) + 1)

        out.append((f"{spec['label']} lvl {level + 1}", level_cost(globals()[spec["cost"]], level), up_building, kind, None))

    for role in ROLES:
        crew = s.crews[role]
        if crew.count == 0 or crew.tier >= TIER_MAX:
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
            prices[uid] = 0 if free else nice(income(s) * era["wait"](k), last_price)
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

    while era["bell"] not in s.bought:
        reprice()

        # cumpara tot ce merita, cat timp merita
        while True:
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
            first_net, net_count = era["first_net"], era["net_count"]
            if first_net + 1 <= len(s.nets) < first_net + net_count and s.nets[-1].level < PREV_NET_LEVEL:
                i = len(s.nets) - 1
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
        shares[now_chain.bottleneck] += 1
        for line in LINE_ORDER:
            if now_chain.lines[line].catch > 0:
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
    return s, rows, prices, longest_idle, income(s), shares, line_time["iron"]


# Linia care apare la coada fiecarei ere (fierul, cuprul): verigile ei se masoara doar pe timpul in care e deschisa.
LATE_LINE = {1: "iron", 2: "copper"}


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
# [D65] Era 2 e in oglinda, deci si scutirile: Ore Porter si Copper Hauler.
BOTTLENECK_EXEMPT = {"scrapPort", "ironHaul", "orePort", "copperHaul"}


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
# [D66] CAT LUCREAZA SATUL FARA TINE: o noapte (PassMath.OFFLINE_HOURS), dubla cu Long Nights. Absenta de la
# sfarsitul unei ere, platita cu venitul de atunci, poate cumpara cel mult inceputul erei urmatoare.
OFFLINE_HOURS = 8.0
OFFLINE_HOURS_LONG = 16.0
WINDFALL_MAX_SHARE = 0.25  # partea din timpul erei urmatoare pe care o poate sari o noapte de absenta
ERA2_MIN_FIRST_FIVE = 15
ERA2_CREW_BURST_REAL = 360


def check_run_era2(rows, longest_idle, shares, late_time, started_at, ended_at, min_share=None):
    """Portile Erei 2 pe o rulare. `rows` sunt doar cumparaturile erei; timpii se numara de la clopotul Erei 1.
    `min_share`: cat din timp trebuie sa fie fiecare veriga gatuirea (implicit MIN_BOTTLENECK_SHARE)."""
    min_share = MIN_BOTTLENECK_SHARE if min_share is None else min_share
    problems = []
    real = (ended_at - started_at) * REAL
    if not ERA2_MIN_REAL <= real <= ERA2_MAX_REAL:
        problems.append(f"Era 2 dureaza {fmt(real)} reali (intre {fmt(ERA2_MIN_REAL)} si {fmt(ERA2_MAX_REAL)})")
    five_min = [r for r in rows if (r[3] - started_at) * REAL <= 300]
    if len(five_min) < ERA2_MIN_FIRST_FIVE:
        problems.append(f"Era 2: primele 5 minute reale au doar {len(five_min)} cumparaturi (minim {ERA2_MIN_FIRST_FIVE})")
    hired = [(r[3] - started_at) * REAL for r in rows if r[0] == "unlock:Merchant"]
    if not hired or hired[0] > ERA2_CREW_BURST_REAL:
        when = fmt(hired[0]) if hired else "niciodata"
        problems.append(f"Era 2: cei cinci oameni sunt angajati abia la {when} real (maxim {fmt(ERA2_CREW_BURST_REAL)})")
    if longest_idle > 180:
        problems.append(f"Era 2: {fmt(longest_idle)} fara nimic de apasat (maxim 3 min)")
    for link in ERA_LINKS[2]:
        if link in BOTTLENECK_EXEMPT or link == "nets":
            continue
        part = link_share(link, shares, late_time, era=2)
        if part < min_share:
            problems.append(f"Era 2: veriga `{link}` e gatuirea doar {part * 100:.1f}% din timp (minim {min_share * 100:.2f}%) -- e decor")
    return problems


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
    }
    for name, want in scalars.items():
        m = re.search(r"StationConfig\." + name + r" = ([0-9.]+)", src)
        if m is None:
            bad.append(f"StationConfig: lipseste {name}")
        elif float(m.group(1)) != float(want):
            bad.append(f"StationConfig.{name} = {m.group(1)}, simulatorul are {want}")
    passmath = open(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "Shared", "Modules", "PassMath.luau"),
        encoding="utf-8",
    ).read()
    for name, want in (("OFFLINE_HOURS", OFFLINE_HOURS), ("OFFLINE_HOURS_LONG", OFFLINE_HOURS_LONG)):
        m = re.search(r"PassMath\." + name + r" = ([0-9.]+)", passmath)
        if m is None or float(m.group(1)) != want:
            bad.append(f"PassMath.{name} = {m.group(1) if m else 'lipseste'}, simulatorul are {want:g} [D66]")
    m = re.search(r"StationConfig\.ROLE_BASE = \{([^}]*)\}", src)
    have = dict((k, float(v)) for k, v in re.findall(r"(\w+) = ([0-9.]+)", m.group(1))) if m else {}
    if have != ROLE_BASE:
        bad.append(f"StationConfig.ROLE_BASE = {have}, simulatorul are {ROLE_BASE}")
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


def robust_era2(s1: State, prices1: dict):
    failures = []
    module = sys.modules[__name__]
    print("\n--robust, Era 2: fiecare constanta a cartierului nou x0.85 si x1.15")
    for knob in ROBUST_KNOBS_ERA2:
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
                s2, rows, _prices, idle, _final, shares, _ = run_era2(clone(s1), prices1)
                problems = list(VIOLATIONS) + check_hire_order()
                # LA +-15% PRAGUL E PE JUMATATE. Poarta prinde o veriga care nu e NICIODATA gatuirea. Parts Hauler-ul e
                # ultimul om de drum (baza 9.0, ca Hauler-ul Erei 1, care la +15% tine venitul 0.6% din timp): cu 15% mai
                # iute il tine 0.4%. Rar, dar nu niciodata: meniul lui spune de ce, ca la gater si taverna in Era 1 [D52].
                problems += check_run_era2(
                    rows, idle, shares, s2.line_time[LATE_LINE[2]], s1.t, s2.t, MIN_BOTTLENECK_SHARE / 2
                )
                print(f"  {tag:<28} {fmt((s2.t - s1.t) * REAL):>7} real, {len(rows)} cumparaturi, pauza {fmt(idle)}")
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


def check_windfall(income1, rows, started_at, ended_at):
    """[D66] O NOAPTE DE ABSENTA NU CUMPARA ERA URMATOARE. Cu cadrul de dinainte (40), la sfarsitul Erei 1 o noapte
    platea 352 din 398 de cumparaturi ale Erei 2. Regula tine pentru orice era noua: cel mult WINDFALL_MAX_SHARE din
    timpul ei, platit de o noapte (fara pass-uri) din venitul erei dinainte."""
    _budget, _n, _nu, last, share = windfall(income1, rows, started_at, ended_at, OFFLINE_HOURS)
    if share > WINDFALL_MAX_SHARE:
        return [
            f"o noapte de absenta ({OFFLINE_HOURS:g} h) la sfarsitul Erei 1 sare {share * 100:.0f}% din Era 2 "
            f"(pana la {last}; maxim {WINDFALL_MAX_SHARE * 100:.0f}%)"
        ]
    return []


def report_era2(s1, s2, rows, prices, longest_idle, final_income, shares, income1):
    started = s1.t
    late = s2.line_time[LATE_LINE[2]]
    unlocks = [r for r in rows if r[1] == "unlock"]
    five_min = [r for r in rows if (r[3] - started) * REAL <= 300]
    c = chain(s2)
    money = {line: c.lines[line].delivered * line_avg(line) for line in LINE_ORDER}
    total = sum(money.values())
    old = sum(money[line] for line in ERA_LINES[1])
    print(f"\nEra 2: {len(rows)} cumparaturi ({len(unlocks)} deblocari, {len(rows) - len(unlocks)} niveluri si trepte)")
    print(f"  terminata in {fmt(s2.t - started)} lacom  ->  {fmt((s2.t - started) * REAL)} real, de la clopotul Erei 1")
    print(f"  venit: {income1:.2f}/s -> {final_income:.2f}/s  (x{final_income / income1:.1f})")
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim {ERA2_MIN_FIRST_FIVE})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {fmt(longest_idle)}")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {link_share(link, shares, late, era=2) * 100:.1f}%" for link in ERA_LINKS[2])
        + f"  (cuprul: din {fmt(late)} cu minereu)"
    )
    print(
        f"  la final: cartierul vechi {old / total * 100:.1f}% din bani, piesele {money['parts'] / total * 100:.1f}%,"
        f" cuprul {money['copper'] / total * 100:.1f}%"
    )
    print("  oamenii la final: " + ", ".join(f"{ROLE_NAMES[r]} {s2.crews[r].count}x treapta {s2.crews[r].tier}" for r in ERA2_ROLES))
    print("\npreturile deblocarilor Erei 2, in ordinea cumpararii (timpul: de la clopotul Erei 1):")
    for label, kind, price, t, inc, bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<22} {big(price):>9}   la {fmt(t - started):>7} lacom / {fmt((t - started) * REAL):>7} real   venit {inc:>8.2f}/s")
    never = [uid for uid, *_ in ERA2_UNLOCKS if uid not in s2.bought]
    if never:
        print("  necumparate in Era 2 (pret din starea de la final): " + ", ".join(f"{uid} {big(prices[uid])}" for uid in never))
    print(f"\n[D66] absenta de la sfarsitul Erei 1 ({income1:.1f}/s), cat din Era 2 plateste:")
    for label, hours, mult in (
        (f"o noapte ({OFFLINE_HOURS:g} h)", OFFLINE_HOURS, 1.0),
        (f"Long Nights ({OFFLINE_HOURS_LONG:g} h)", OFFLINE_HOURS_LONG, 1.0),
        (f"Long Nights si 2x Flow", OFFLINE_HOURS_LONG, 2.0),
    ):
        budget, n, nu, last, share = windfall(income1, rows, started, s2.t, hours, mult)
        print(f"  {label:26s} {big(budget):>8}: {n:3d} din {len(rows)} cumparaturi, {nu:2d} din {len(unlocks)} deblocari"
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
        problems += robust_era2(s1, prices)

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
    report_era2(s1, s2, rows2, prices2, idle2, final2, shares2, final_income)
