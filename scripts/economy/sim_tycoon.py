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
import sys
from dataclasses import dataclass, field

REAL = 1.8  # un jucator real ~ de 1.8 ori mai lent decat cel lacom (IPOTEZA, de masurat)

GOODS = {  # valoarea de baza a unei bucati, in monede
    "driftwood": 1.0,
    "scrap": 3.0,  # [D55] se vinde doar topit: fierul valoreaza cat scrap-ul din care iese
    "named": 14.0,
    "planks": 1.0,
    "iron": 3.0,
}
# CE PRINDE O PLASA, dupa felul ei [D55]. Pana la D55 toate plasele prindeau acelasi amestec, iar banda cea
# mai departata decidea ce marfuri exista: dupa plasa a patra, si a doua prindea scrap, care trecea prin
# gater ca si cand ar fi fost lemn [owner, 2026-09-13: "scraps ar trebui sa poti prinde doar la ultimul
# net"]. Reeds si shards au iesit din Era 1 din acelasi motiv. (bun, pondere), in ordinea sumei.
CATCH = {
    "wood": (("driftwood", 0.95), ("named", 0.05)),
    "scrap": (("scrap", 0.95), ("named", 0.05)),
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
LEVEL_INC_BY_KIND = {"nets": 0.03, "saw": 0.06, "dock": 0.06}
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
NET_LANES = (1, 1, 2, 2, 3)  # pe ce banda sta fiecare din cele 5 plase ale Erei 1
NET_KINDS = ("wood", "wood", "wood", "wood", "scrap")  # [D55] ultima plasa, cea din larg, prinde scrap

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
ROLE_BASE = {"collector": 4.0, "porter": 6.0, "hauler": 9.0, "scrapCollector": 2.0, "scrapPorter": 2.5, "ironHauler": 6.5}
TIER_STEP = 1.0  # fiecare treapta adauga inca o data baza: treapta 5 = de 5 ori
TIER_MAX = 5
TIER_COST_BASE = 25.0  # 25 / 75 / 225 / 675 -- fix, ca la ei uneltele unui om
TIER_COST_GROWTH = 3.0
SECOND_AT_TIER = 3  # al doilea om pe aceeasi treaba se deschide de la treapta asta
MAX_PEOPLE = 2  # in Era 1; "progresiv cu jocul" [owner, 2026-09-13]

ROLES = ("collector", "porter", "sawyer", "hauler", "trader", "scrapCollector", "scrapPorter", "smelter", "ironHauler")
# Pasii pe care ii poate face jucatorul, PE LINII, IN ORDINEA ANGAJARILOR (conditiile de mai jos o impun, iar
# `check_hire_order` se bazeaza pe ea). [D56] Fiecare linie are timpul tau intreg: in joc nu ai niciodata pasi de
# mana pe amandoua odata (oamenii lemnului vin toti inaintea Forge), iar asa deschiderea fierului nu poate scadea
# lemnul in nicio stare.
LINE_STEPS = {
    "wood": ("collector", "porter", "sawyer", "hauler"),
    "iron": ("scrapCollector", "scrapPorter", "smelter", "ironHauler"),
}
MANUAL_ROLES = LINE_STEPS["wood"] + LINE_STEPS["iron"]
LINE_OF_ROLE = {r: line for line, steps in LINE_STEPS.items() for r in steps}
LINK_OF = {
    "collector": "collect", "porter": "port", "sawyer": "saw", "hauler": "haul", "trader": "dock",
    "scrapCollector": "scrapCollect", "scrapPorter": "scrapPort", "smelter": "forge", "ironHauler": "ironHaul",
}
ROLE_NAMES = {
    "collector": "Collector", "porter": "Porter", "sawyer": "Sawyer", "hauler": "Hauler", "trader": "Innkeeper",
    "scrapCollector": "Scrap Collector", "scrapPorter": "Scrap Porter", "smelter": "Smelter", "ironHauler": "Iron Hauler",
}
# ORDINEA e contractul cu ChainMath.luau: la egalitate castiga veriga dinainte (Luau-ul compara cu `>` strict in
# exact aceeasi ordine). [D56] Plasele, linia lemnului, linia fierului, taverna (a amandurora).
LINKS = ("nets", "collect", "port", "saw", "haul", "scrapCollect", "scrapPort", "forge", "ironHaul", "dock")
LINE_LINKS = {
    "wood": ("collect", "port", "saw", "haul"),
    "iron": ("scrapCollect", "scrapPort", "forge", "ironHaul"),
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
    price_mult: float = 1.0
    bells: float = 1.0
    index_found: int = 0
    rebirths: int = 0
    bought: set = field(default_factory=set)


def tier_mult(tier: int) -> float:
    return 1 + TIER_STEP * (tier - 1)


def tier_cost(tier: int) -> float:
    """Cat costa trecerea de la treapta `tier` la `tier + 1`."""
    return TIER_COST_BASE * TIER_COST_GROWTH ** (tier - 1)


def iron_open(s: State) -> bool:
    """[D56] Linia fierului e deschisa: ai Forge si plasa de scrap. Pana la shed, culesul si dusul scrap-ului sunt
    pasii tai de mana, ca turul de lemn din capitolul 1."""
    return s.workshop and any(n.kind == "scrap" for n in s.nets)


def manual_steps(s: State, line: str = "wood") -> int:
    """Cati din pasii unei linii n-au inca om (0 cat linia fierului e inchisa)."""
    if line == "iron" and not iron_open(s):
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


def saw_rate(s: State) -> float:
    """Gaterul: Sawyerii il tin pornit tot timpul; fara ei taie doar cat stai tu langa el."""
    cap = level_output(SAW_BASE_RATE, s.saw_level, "saw")
    crew = s.crews["sawyer"]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    return cap / manual_steps(s, "wood")


def dock_rate(s: State) -> float:
    cap = level_output(DOCK_BASE_RATE, s.dock_level, "dock")
    crew = s.crews["trader"]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    return cap * NO_TRADER_FACTOR


def forge_rate(s: State) -> float:
    """Forja [D56]: Smelter-ii o tin pornita tot timpul; fara ei topeste doar cat stai tu langa ea. Cat linia
    fierului e inchisa (fara Forge sau fara plasa de scrap), nimic."""
    if not iron_open(s):
        return 0.0
    cap = level_output(FORGE_BASE_RATE, s.forge_level, "forge")
    crew = s.crews["smelter"]
    if crew.count > 0:
        return cap * tier_mult(crew.tier) * crew.count
    return cap / manual_steps(s, "iron")


@dataclass
class Chain:
    wood_catch: float
    scrap_catch: float  # 0 cat linia fierului e inchisa
    collect: float
    port: float
    sawing: float
    haul: float
    scrap_collect: float
    scrap_port: float
    forging: float
    iron_haul: float
    sales: float
    wood: float  # bucati de lemn livrate pe secunda
    scrap: float  # bucati de fier livrate pe secunda (scrap-ul topit)
    bottleneck: str = "nets"
    wood_bottleneck: str = "nets"
    iron_bottleneck: str = ""  # "" cat linia fierului e inchisa


def bottlenecks(c: Chain) -> tuple:
    """(veriga care tine venitul, veriga slaba a lemnului, veriga slaba a fierului) [D56].

    Veriga care tine venitul: cea al carei pas in plus ar aduce cei mai multi bani pe bucata, in ordinea LINKS la
    egalitate. O veriga "tine" o linie cand valoarea ei e chiar marginea liniei (min-ul exact):
      * lemnul, tinut de o veriga a lui -> 1.65 pe bucata;
      * fierul, tinut de o veriga a lui -> 3.55, dar cand taverna e plina o bucata de fier in plus ia locul
        uneia de lemn, deci doar diferenta (3.55 - 1.65);
      * taverna, cand ea e marginea: ce ar mai vinde (fier daca fierul asteapta, altfel lemn).
    Veriga slaba a unei linii: primul minim din linie (plasele ei, oamenii, cladirea), sau taverna cand ea e
    marginea liniei. Fara linia fierului iese PRIMUL minim din cele sase -- regula de dinainte [D49]."""
    aw, ai = AVG["wood"], AVG["scrap"]
    wood_links = (("nets", c.wood_catch), ("collect", c.collect), ("port", c.port), ("saw", c.sawing), ("haul", c.haul))
    iron_links = (
        ("nets", c.scrap_catch), ("scrapCollect", c.scrap_collect), ("scrapPort", c.scrap_port),
        ("forge", c.forging), ("ironHaul", c.iron_haul),
    )
    iron_open_ = c.scrap_catch > 0.0
    wood_max = min(v for _, v in wood_links)
    iron_max = min(v for _, v in iron_links)
    wood_by_dock = c.wood == c.sales - c.scrap and c.wood < wood_max  # taverna e marginea lemnului
    iron_by_dock = iron_open_ and c.scrap == c.sales and c.scrap < iron_max
    swap = ai - (aw if wood_by_dock else 0.0)  # o bucata de fier in plus ia locul uneia de lemn
    gains = {link: 0.0 for link in LINKS}
    if iron_open_ and not iron_by_dock:
        for link, value in iron_links:
            if value == c.scrap:
                gains[link] = max(gains[link], swap)
    if not wood_by_dock:
        for link, value in wood_links:
            if value == c.wood:
                gains[link] = max(gains[link], aw)
    if iron_by_dock:
        gains["dock"] = ai
    elif wood_by_dock:
        gains["dock"] = aw
    best = "nets"
    for link in LINKS:
        if gains[link] > gains[best]:
            best = link
    wood_bn = "dock" if wood_by_dock else next(link for link, value in wood_links if value == wood_max)
    iron_bn = ""
    if iron_open_:
        iron_bn = "dock" if iron_by_dock else next(link for link, value in iron_links if value == iron_max)
    return best, wood_bn, iron_bn


def chain(s: State) -> Chain:
    """Cele doua linii [D49, D56]: fiecare cu oamenii ei; impart doar taverna, care vinde intai fierul (bucata
    valoreaza mai mult) cat poate linia lui aduce, iar lemnul ia restul. Orice capacitate in plus doar largeste
    ce se poate, deci nicio cumparatura nu scade venitul."""
    open_ = iron_open(s)
    wood_catch = 0.0
    scrap_catch = 0.0
    for n in s.nets:
        if n.kind == "scrap":
            if open_:
                scrap_catch += n.rate()
        else:
            wood_catch += n.rate()
    collect = walk_rate(s, "collector")
    port = walk_rate(s, "porter")
    sawing = saw_rate(s)
    haul = walk_rate(s, "hauler")
    scrap_collect = walk_rate(s, "scrapCollector")
    scrap_port = walk_rate(s, "scrapPorter")
    forging = forge_rate(s)
    iron_haul = walk_rate(s, "ironHauler")
    sales = dock_rate(s)
    iron_max = min(scrap_catch, scrap_collect, scrap_port, forging, iron_haul)
    wood_max = min(wood_catch, collect, port, sawing, haul)
    scrap = min(iron_max, sales)
    wood = min(wood_max, sales - scrap)
    c = Chain(wood_catch, scrap_catch, collect, port, sawing, haul, scrap_collect, scrap_port, forging, iron_haul,
              sales, wood, scrap)
    c.bottleneck, c.wood_bottleneck, c.iron_bottleneck = bottlenecks(c)
    return c


def income(s: State) -> float:
    c = chain(s)
    return (
        (c.wood * AVG["wood"] + c.scrap * AVG["scrap"])
        * s.price_mult
        * s.bells
        * (1 + 0.01 * s.index_found)
        * (1 + 0.5 * s.rebirths)
    )


# ---- deblocarile ------------------------------------------------------------------------------
# Fiecare are un MOTIV: C=prinzi mai mult, V=vinzi mai scump, A=scapi de o corvoada, D=deschizi.


def unlock_net(k: int):
    def f(s: State):
        s.nets.append(Net(NET_BASE_RATE * NET_BASE_GROWTH ** (k - 1), NET_LANES[k - 1], kind=NET_KINDS[k - 1]))

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
for _role in ROLES:
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
        and all(people(s, r) >= 1 for r in ROLES)
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
BURST_WAIT = {"shed": 45.0, "scrapCollector": 45.0, "scrapPorter": 50.0, "smelter": 55.0, "ironHauler": 60.0}

# uid -> pe ce veriga apasa deblocarea (pentru cazul in care nimic nu da castig imediat)
UNLOCK_STAGE = {
    "net1": "nets", "net2": "nets", "net3": "nets", "net4": "nets", "net5": "nets",
    "sack": "collect", "collector": "collect", "porter": "port", "sawyer": "saw", "hauler": "haul",
    "trader": "dock", "workshop": "forge", "bell": "dock", "shed": "scrapCollect",
    "scrapCollector": "scrapCollect", "scrapPorter": "scrapPort", "smelter": "forge", "ironHauler": "ironHaul",
}
for _role in ROLES:
    UNLOCK_STAGE[f"{_role}2"] = LINK_OF[_role]


# CE NU URCA SCARA DE ASTEPTARE. `target_wait(k)` a fost calibrat pe deblocarile Erei 1: fiecare
# treapta face urmatoarea deblocare de 1.17 ori mai departe. In D48 Sawyer-ul era scutit -- un om
# care facea sa mearga o veriga existenta. In D49 angajarile SUNT deblocarile erei (cinci din cele
# treisprezece), deci urca scara: scutite, Era 1 scadea la 21 de minute reale. Al doilea om ramane
# scutit -- e o marire a unei meserii pe care o ai deja, nu o extindere.
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
    return min(420.0, 20.0 * 1.17**k)


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


def options(s: State, prices: dict):
    """Tot ce poate cumpara jucatorul ACUM: deblocarile a caror conditie e implinita, un nivel pe
    orice cladire detinuta si o treapta pe orice meserie cu oameni. Intoarce (eticheta, pret, efect,
    fel, uid)."""
    out = []
    for uid, name, _why, cond, effect in ERA1_UNLOCKS:
        if uid in s.bought or not cond(s):
            continue
        if uid in prices:
            out.append((f"unlock:{name}", prices[uid], effect, "unlock", uid))

    for i, n in enumerate(s.nets):
        base_cost = NET_UPGRADE_BASE_COST * NET_BASE_GROWTH**i

        def up_net(st, idx=i):
            st.nets[idx].level += 1

        out.append(
            (f"Net {i + 1} lvl {n.level + 1}", level_cost(base_cost, n.level), up_net, "nets", None)
        )

    def up_saw(st):
        st.saw_level += 1

    out.append((f"Saw lvl {s.saw_level + 1}", level_cost(SAW_UPGRADE_BASE, s.saw_level), up_saw, "saw", None))

    def up_dock(st):
        st.dock_level += 1

    out.append((f"Dock lvl {s.dock_level + 1}", level_cost(DOCK_UPGRADE_BASE, s.dock_level), up_dock, "dock", None))

    if s.workshop:  # [D55] forja atelierului

        def up_forge(st):
            st.forge_level += 1

        out.append((f"Forge lvl {s.forge_level + 1}", level_cost(FORGE_UPGRADE_BASE, s.forge_level), up_forge, "forge", None))

    for role in ROLES:
        crew = s.crews[role]
        if crew.count == 0 or crew.tier >= TIER_MAX:
            continue

        def up_tier(st, r=role):
            st.crews[r].tier += 1

        out.append((f"{ROLE_NAMES[role]} tier {crew.tier + 1}", tier_cost(crew.tier), up_tier, LINK_OF[role], None))
    return out


def clone(s: State) -> State:
    c = State(**{k: v for k, v in s.__dict__.items() if k not in ("nets", "bought", "crews")})
    c.nets = [Net(n.base, n.base_lane, n.level, n.kind) for n in s.nets]
    c.crews = {r: Crew(v.count, v.tier) for r, v in s.crews.items()}
    c.bought = set(s.bought)
    return c


def gain_of(s: State, effect) -> float:
    """Cat adauga o cumparatura la venit. Poate fi ZERO: un upgrade pe o veriga care nu e
    gatuirea nu schimba nimic. Vezi regula B din antet."""
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


def run(rebirths=0, index_found=0, max_seconds=36000):
    """Simulare pe pasi de o secunda. In fiecare secunda intra venitul, apoi jucatorul cumpara
    tot ce merita cumparat acum. Asa ies si rafalele de apasari, si rabdarea pentru o deblocare."""
    s = State(rebirths=rebirths, index_found=index_found)
    rows = []
    prices: dict = {}
    last_price = 0
    # POARTA E TIMPUL MORT, NU GATUIREA. Prima varianta masura "cat timp a stat aceeasi veriga
    # gatuita" -- dar aia poate fi lunga si sanatoasa, daca in tot timpul ala o repari nivel cu
    # nivel. Ce chiar strica jocul e sa nu ai NIMIC de apasat. Deci masuram pauza dintre doua
    # cumparaturi.
    last_buy_at = 0.0
    longest_idle = 0.0
    shares = {link: 0 for link in LINKS}
    scrap_time = 0  # [D55] secundele in care linia fierului e deschisa: verigile ei exista doar atunci

    def reprice():
        # pretul unei deblocari se fixeaza cand devine PRIMA DATA accesibila, din venitul de-atunci
        nonlocal last_price
        for uid, _name, _why, cond, _effect in ERA1_UNLOCKS:
            if uid in s.bought or uid in prices or not cond(s):
                continue
            if uid in BURST_WAIT:  # [D56] oamenii fierului: secunde de venit, fara scara si fara podea
                prices[uid] = nice(income(s) * BURST_WAIT[uid])
                continue
            k = ladder_step(s.bought)
            prices[uid] = 0 if k == 0 else nice(income(s) * target_wait(k), last_price)
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

    while "bell" not in s.bought:
        reprice()

        # cumpara tot ce merita, cat timp merita
        while True:
            # OAMENII CAPITOLULUI 1, IN ORDINE, INAINTEA ORICAREI ALTE CUMPARATURI [D52]. Cu o singura
            # plasa, un om adauga ZERO venit (plasa e veriga slaba), deci lacomul nu l-ar lua niciodata;
            # iar fara sa strangi, nivelurile de 1-2 monede ale plasei ar manca banii la nesfarsit. Deci:
            # cat lipseste un om al capitolului si conditia lui e implinita, il iei cand ai banii si nu
            # cumperi nimic altceva pana atunci. Sta inaintea nivelului 2: in quest-uri, nivelul vine dupa.
            pending = next((uid for uid in CHAPTER1_HIRES if uid not in s.bought), None)
            if pending is not None:
                _uid, name, _why, cond, effect = next(e for e in ERA1_UNLOCKS if e[0] == pending)
                if cond(s) and pending in prices:
                    if prices[pending] <= s.coins:
                        buy(f"unlock:{name}", "unlock", prices[pending], effect, pending)
                        reprice()
                        continue
                    break

            # [D55, D56] DEBLOCARILE CERUTE DE QUEST (traista, linia fierului pas cu pas). Singure aduc putin sau
            # nimic, deci lacomul nu le-ar lua; un om urmeaza quest-ul si strange pentru ele.
            quested = next((uid for uid, ready in QUEST_UNLOCKS if uid not in s.bought and ready(s)), None)
            if quested is not None:
                _uid, name, _why, cond, effect = next(e for e in ERA1_UNLOCKS if e[0] == quested)
                if cond(s) and quested in prices:
                    if prices[quested] <= s.coins:
                        buy(f"unlock:{name}", "unlock", prices[quested], effect, quested)
                        reprice()
                        continue
                    break

            # QUEST-UL CERE NIVELUL 2 PE ULTIMA PLASA, iar un om il urmeaza. Singur, nivelul 2 nu da
            # nimic cand plasele nu sunt gatuirea, deci lacomul nu-l lua niciodata -- si plasa
            # urmatoare, pe care o deschide, venea cu 32 de minute mai tarziu [D49].
            if 1 <= len(s.nets) < 5 and s.nets[-1].level < PREV_NET_LEVEL:
                i = len(s.nets) - 1
                cost = level_cost(NET_UPGRADE_BASE_COST * NET_BASE_GROWTH**i, s.nets[i].level)
                if cost <= s.coins:

                    def up_last(st, idx=i):
                        st.nets[idx].level += 1

                    buy(f"Net {i + 1} lvl {PREV_NET_LEVEL} (quest)", "nets", cost, up_last, None)
                    continue

            opts = options(s, prices)
            scored = []
            for label, price, effect, kind, uid in opts:
                g = gain_of(s, effect)
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

        if "bell" in s.bought:
            break
        now_chain = chain(s)
        shares[now_chain.bottleneck] += 1
        if now_chain.scrap_catch > 0:
            scrap_time += 1
        inc = income(s)
        if inc <= 0:
            raise SystemExit("EROARE: venit zero, simularea nu poate avansa")
        s.coins += inc
        s.t += 1
        if s.t > max_seconds:
            raise SystemExit(f"EROARE: peste {max_seconds}s fara sa termine Era 1")

    # Ce n-a devenit accesibil in rulare (un al doilea Sawyer, daca treapta 3 n-a venit) are totusi
    # nevoie de un pret in config: se deriva din starea de la final, ca si cand s-ar fi deschis atunci.
    for uid, _name, _why, _cond, _effect in ERA1_UNLOCKS:
        if uid not in prices:
            prices[uid] = nice(income(s) * target_wait(ladder_step(s.bought)), last_price)
            last_price = max(last_price, prices[uid])

    return s, rows, prices, longest_idle, income(s), shares, scrap_time


def link_share(link, shares, scrap_time):
    """Cat din timp a fost `link` gatuirea. Verigile fierului [D55, D56] se masoara pe timpul in care linia lui
    e deschisa: ea apare abia la coada erei, iar pe toata era ar parea decor chiar daca tine venitul cand exista."""
    if link in LINE_LINKS["iron"]:
        return shares[link] / scrap_time if scrap_time else 0.0
    total = sum(shares.values())
    return shares[link] / total if total else 0.0


def fmt(sec):
    m, x = divmod(int(sec), 60)
    h, m = divmod(m, 60)
    return f"{h}h{m:02d}m" if h else f"{m}m{x:02d}s"


def big(n):
    for unit, d in (("B", 1e9), ("M", 1e6), ("K", 1e3)):
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
# [D56] COMPROMISUL LINIEI FIERULUI, ca in D52: pe linia fierului pasul cel mai lent e aproape mereu forja (~66% din
# timpul cu fier) sau Scrap Collector-ul (~30%). Iron Hauler-ul e ultimul om de drum, deci baza lui trebuie sa
# duca macar cat tot timpul tau (altfel angajarea lui ar putea scadea venitul): la baza asta e cel mai lent 0-0.5%
# din timp, iar Scrap Porter-ul la egalitate cu Scrap Collector-ul pierde alegerea. Treptele lor rar aduc ceva in
# Era 1 (meniul spune de ce). Owner-ul: "fierul este intr-adevar ceva care se face mai greu la inceput dar care
# aduce mai multi bani". Poarta de 0.5% ramane pentru toate celelalte verigi.
BOTTLENECK_EXEMPT = {"scrapPort", "ironHaul"}


def check_run(rows, longest_idle, shares, prices, scrap_time):
    """Portile care se masoara pe o rulare (si pe fiecare rulare din --robust)."""
    problems = []
    five_min = [r for r in rows if r[3] * REAL <= 300]
    if len(five_min) < 6:
        problems.append(f"primele 5 minute reale au doar {len(five_min)} cumparaturi (minim 6) [L1]")
    if longest_idle > 180:
        problems.append(f"{fmt(longest_idle)} fara nimic de apasat (maxim 3 min)")
    # O veriga care e rar cea mai slaba e decor: jucatorul n-are de ce s-o urce, iar meniul ei ar
    # scrie "No gain yet" toata era [D48]. "Macar o data" nu ajungea: o veriga gatuire 1% din timp
    # trecea poarta si tot decor era.
    for link in LINKS:
        if link in BOTTLENECK_EXEMPT:
            continue
        part = link_share(link, shares, scrap_time)
        if part < MIN_BOTTLENECK_SHARE:
            problems.append(f"veriga `{link}` e gatuirea doar {part * 100:.1f}% din timp (minim {MIN_BOTTLENECK_SHARE * 100:.1f}%) -- e decor")
    if prices.get("collector", 0) <= 0:
        problems.append("Collector-ul iese gratis: conditia lui e adevarata inainte de prima cumparatura")
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


def _config_source(name: str) -> str:
    import os

    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "src", "Shared", "Config", name)
    return open(path, encoding="utf-8").read()


def check_config_prices(prices):
    """Preturile din TycoonConfig.luau trebuie sa fie EXACT cele derivate aici.

    Pana la verificarea asta, testul Luau "preturile sunt exact cele din simulator" compara config-ul
    cu o lista scrisa de mana -- si pe 2026-09-12 config-ul avea Fifth Net 2500, Workshop 2800 si
    Landing Bell 13000 in timp ce simulatorul deriva 1500 / 1600 / 10000. Ambele treceau. Acum
    simulatorul citeste chiar fisierul Luau, deci o reglare facuta doar intr-o parte pica in CI.
    Al doilea om nu sta pe o platforma, deci pretul lui se citeste din `TycoonConfig.CREWS`.
    """
    import re

    src = _config_source("TycoonConfig.luau")
    bad = []
    for uid, pad_id in PAD_IDS.items():
        m = re.search(r'id = "' + re.escape(pad_id) + r'",.*?price = (\d+),', src, re.S)
        if m is None:
            bad.append(f"TycoonConfig: nu gasesc pretul lui {pad_id}")
            continue
        have, want = int(m.group(1)), int(prices.get(uid, -1))
        if have != want:
            bad.append(f"TycoonConfig: {pad_id} costa {have}, simulatorul deriva {want}")
    crews = re.search(r"TycoonConfig\.CREWS = \{(.*?)\n\}", src, re.S)
    for role in ROLES:
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
    }
    for name, want in scalars.items():
        m = re.search(r"StationConfig\." + name + r" = ([0-9.]+)", src)
        if m is None:
            bad.append(f"StationConfig: lipseste {name}")
        elif float(m.group(1)) != float(want):
            bad.append(f"StationConfig.{name} = {m.group(1)}, simulatorul are {want}")
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
                low = min(link_share(link, shares, scrap_time) for link in LINKS if link not in BOTTLENECK_EXEMPT)
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
    if AVG["scrap"] < AVG["wood"]:
        # lantul da capacitatea comuna intai scrap-ului; asta e cea mai buna impartire doar cat bucata lui
        # valoreaza macar cat una de lemn [D55]
        problems.append(f"bucata de scrap ({AVG['scrap']:.2f}) valoreaza sub una de lemn ({AVG['wood']:.2f})")
    if "--robust" in sys.argv:
        problems += robust()

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
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim 6)")
    print(f"  cea mai lunga pauza fara nimic de apasat: {fmt(longest_idle)}")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {link_share(link, shares, scrap_time) * 100:.1f}%" for link in LINKS)
        + f"  (forja: din {fmt(scrap_time)} cu scrap)"
    )
    print("  oamenii la final: " + ", ".join(f"{ROLE_NAMES[r]} {c.count}x treapta {c.tier}" for r, c in s1.crews.items()))
    print(f"  venit final: {final_income:.2f}/s")
    print("\npreturile deblocarilor, in ordinea cumpararii:")
    for label, kind, price, t, inc, bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<18} {big(price):>9}   la {fmt(t):>7} lacom / {fmt(t * REAL):>7} real   venit {inc:>7.2f}/s")
    never = [uid for uid, *_ in ERA1_UNLOCKS if uid not in s1.bought]
    if never:
        print("  necumparate in Era 1 (pret din starea de la final): " + ", ".join(f"{uid} {big(prices[uid])}" for uid in never))
