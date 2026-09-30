#!/usr/bin/env python3
"""Motorul lantului chiar duce ORICATE linii, nu doar le reproduce pe cele doua ale Erei 1 [D64].

Cronologia Erei 1 si tabelul de aur dovedesc ca refactorul n-a schimbat nimic. Nu dovedesc insa ca tabelul LINES poate
primi o linie noua: cu doua linii, un motor scris de mana si unul generic dau aceleasi cifre. Aici se adauga, pe o COPIE
a simulatorului, doua linii de proba cu un al doilea vanzator, iar rezultatul se compara cu cifre socotite de mana.

Liniile de proba NU sunt ale jocului: `probeA` si `probeB`, vandute la o taraba (`stall`), cu nume care nu se pot
ciocni de liniile adevarate (Era 2 are de la D65 piesele, cuprul si Piata ei in simulator). In comentariile de mai jos,
"piesele" sunt probeA, "cuprul" e probeB, iar "Piata" e taraba. Cifrele sunt alese rotunde, ca socoteala de mana sa fie
exacta in virgula mobila. Liniile adevarate ale Erei 2 stau inchise in starile de aici, deci nu se amesteca.

[D70] UNIREA SI BARAJUL (docs/PLAN-MOTOR-UNIRE.md, pasul b), pe o alta copie: doua PIESE (`probeBat`, bateriile, si
`probeWire`, cablul) care merg intr-o UNIRE (`probeGrid`, curentul), vanduta la o taraba a orasului (`booth`), toate
trei in acelasi BAZIN al timpului tau; liniile Erelor 1-3 primesc pe copie `closeFlag`, ca la baraj. Forma e a Erei 4
din plan, cu nume care nu se pot ciocni de liniile ei (pasul d le aduce pe cele adevarate). Cifrele sunt ale startului
barajului din plan (drumurile 0.9, atelierul cablului 0.333, releul 0.467, livrat 0.33), cu bucata unita la 50.
Fiecare regula a motorului nou are aici o stare in care regula inversa da alta cifra: bazinul, trecerea inapoi,
egalitatea intre piese si intre o piesa si releu, veriga mostenita de la unire (si cea a pieselor unei uniri care nu
merge inca), `nets_line`, venitul doar pe liniile care vand, `closeFlag`, `options` si plasa de siguranta.
La sfarsit, doua unelte pe care Era 4 le cere: `unlock_net_ranked` si `nice()` peste 10^12.

Ruleaza odata cu simulatorul (`sim_tycoon.py` il cheama la sfarsit), deci e in poarta fara un rand nou. De mana:
    python3 scripts/economy/check_lines.py
"""
import importlib.util
import os
import sys

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")


def load():
    """O copie proaspata a simulatorului: tabelele ei se pot schimba fara sa atinga rularea adevarata."""
    spec = importlib.util.spec_from_file_location("sim_lines_probe", SIM)
    sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sim)
    return sim


def add_probe_lines(T):
    T.LINE_ORDER = T.LINE_ORDER + ("probeA", "probeB")
    T.LINES["probeA"] = {
        "netKind": "probeA", "openFlag": "kiln_a_owned", "seller": "stall",
        "steps": (("probeACollector", "probeACollect", "walk"), ("probeAPorter", "probeAPort", "walk"),
                  ("probeAMaker", "kilnA", "processor"), ("probeAHauler", "probeAHaul", "walk")),
    }
    T.LINES["probeB"] = {
        "netKind": "probeB", "openFlag": "kiln_b_owned", "seller": "stall",
        "steps": (("probeBCollector", "probeBCollect", "walk"), ("probeBPorter", "probeBPort", "walk"),
                  ("probeBMaker", "kilnB", "processor"), ("probeBHauler", "probeBHaul", "walk")),
    }
    T.PROCESSORS["kilnA"] = {"base": "KILN_A_BASE_RATE", "level": "kiln_a_level"}
    T.PROCESSORS["kilnB"] = {"base": "KILN_B_BASE_RATE", "level": "kiln_b_level"}
    T.SELLERS["stall"] = {
        "role": "stallkeeper", "base": "STALL_BASE_RATE", "level": "stall_level", "priority": ("probeB", "probeA"),
    }
    T.KILN_A_BASE_RATE = 2.0
    T.KILN_B_BASE_RATE = 2.0
    T.STALL_BASE_RATE = 5.0
    for kind in ("kilnA", "kilnB", "stall"):
        T.LEVEL_INC_BY_KIND[kind] = 0.06
    for role in ("probeACollector", "probeAPorter", "probeAHauler", "probeBCollector", "probeBPorter", "probeBHauler"):
        T.ROLE_BASE[role] = 3.0
    T.AVG["probeA"] = 8.0
    T.AVG["probeB"] = 12.0
    T.ROLES = T.ROLES + (
        "probeACollector", "probeAPorter", "probeAMaker", "probeAHauler",
        "probeBCollector", "probeBPorter", "probeBMaker", "probeBHauler", "stallkeeper",
    )
    rederive(T)


def rederive(T):
    """Tabelele derivate, din nou, dupa ce s-au schimbat LINES / SELLERS / ROLES pe copie."""
    (
        T.LINE_STEPS, T.LINE_LINKS, T.LINE_OF_ROLE, T.LINK_OF, T.LINKS, T.NET_LINE, T.CONSUMER_OF, T.POOL_LINES,
    ) = T.derive_tables(T.LINE_ORDER, T.LINES, T.SELLERS, T.ROLES)


def era1_state(T):
    """Un sat de Era 1 la jumatatea drumului: ambele linii deschise, cativa oameni, taverna cu Innkeeper."""
    s = T.State()
    for i, level in enumerate((14, 11, 9, 6, 8)):
        s.nets.append(T.Net(T.NET_BASE_RATE * T.NET_BASE_GROWTH**i, T.NET_LANES[i], level, T.NET_KINDS[i]))
    s.saw_level, s.dock_level, s.forge_level = 8, 8, 4
    s.sack_big = True
    s.workshop = True
    for role, (count, tier) in {
        "collector": (2, 5), "porter": (1, 3), "sawyer": (1, 2), "hauler": (1, 4), "trader": (1, 2),
        "scrapCollector": (1, 2), "scrapPorter": (1, 1), "smelter": (1, 1), "ironHauler": (1, 1),
    }.items():
        s.crews[role] = T.Crew(count, tier)
    return s


def with_probe_fields(s, parts_net, copper_net, T):
    s.kiln_a_owned = parts_net is not None
    s.kiln_b_owned = copper_net is not None
    s.kiln_a_level = s.kiln_b_level = s.stall_level = 1
    if parts_net is not None:
        s.nets.append(T.Net(parts_net, 1, 1, "probeA"))
    if copper_net is not None:
        s.nets.append(T.Net(copper_net, 1, 1, "probeB"))
    return s


def staff(s, T, roles, count, tier):
    for role in roles:
        s.crews[role] = T.Crew(count, tier)


PARTS_ROLES = ("probeACollector", "probeAPorter", "probeAMaker", "probeAHauler")
COPPER_ROLES = ("probeBCollector", "probeBPorter", "probeBMaker", "probeBHauler")

# ---- [D70] unirea: bateriile si cablul fac curent, vandut orasului -------------------------------------------------
BAT_ROLES = ("probeBatCollector", "probeBatPorter", "probeSwitchman", "probeBatHauler")
WIRE_ROLES = ("probeWireCollector", "probeWirePorter", "probeWiremaker", "probeWireHauler")
GRID_ROLES = ("probeRelayKeeper", "probeRunner")
JOIN_LINES = ("probeBat", "probeWire", "probeGrid")
JOIN_BUILDINGS = {"probeYard": "Probe Yard", "probeWorks": "Probe Works", "probeRelay": "Probe Relay", "booth": "Booth"}


def add_join_lines(T):
    """Liniile vechi se inchid la baraj (`closeFlag`); piesele si unirea se deschid tot cu el (`openFlag`)."""
    for line in T.LINE_ORDER:
        T.LINES[line]["closeFlag"] = "probe_dam"
    # piesele INAINTEA unirii: ordinea in care se socoteste inainte
    T.LINE_ORDER = T.LINE_ORDER + JOIN_LINES
    T.LINES["probeBat"] = {
        "netKind": "probe_bat", "openFlag": "probe_dam", "into": "probeGrid", "pool": "probeDam",
        "steps": (("probeBatCollector", "probeBatCollect", "walk"), ("probeBatPorter", "probeBatPort", "walk"),
                  ("probeSwitchman", "probeYard", "processor"), ("probeBatHauler", "probeBatHaul", "walk")),
    }
    T.LINES["probeWire"] = {
        "netKind": "probe_wire", "openFlag": "probe_dam", "into": "probeGrid", "pool": "probeDam",
        "steps": (("probeWireCollector", "probeWireCollect", "walk"), ("probeWirePorter", "probeWirePort", "walk"),
                  ("probeWiremaker", "probeWorks", "processor"), ("probeWireHauler", "probeWireHaul", "walk")),
    }
    T.LINES["probeGrid"] = {
        "inputs": ("probeBat", "probeWire"), "openFlag": "probe_dam", "seller": "booth", "value": "probe_grid",
        "pool": "probeDam",
        "steps": (("probeRelayKeeper", "probeRelay", "processor"), ("probeRunner", "probeRun", "walk")),
    }
    T.PROCESSORS["probeYard"] = {"base": "PROBE_YARD_BASE_RATE", "level": "probe_yard_level"}
    T.PROCESSORS["probeWorks"] = {"base": "PROBE_WORKS_BASE_RATE", "level": "probe_works_level"}
    T.PROCESSORS["probeRelay"] = {"base": "PROBE_RELAY_BASE_RATE", "level": "probe_relay_level"}
    T.SELLERS["booth"] = {"role": "probeDispatcher", "base": "BOOTH_BASE_RATE", "level": "booth_level",
                          "priority": ("probeGrid",)}
    T.PROBE_YARD_BASE_RATE = 2.4  # cat Switchyard-ul din plan
    T.PROBE_WORKS_BASE_RATE = 2.0  # cat Cable Works
    T.PROBE_RELAY_BASE_RATE = 2.8  # cat Relay-ul
    T.BOOTH_BASE_RATE = 3.0
    for kind, label in JOIN_BUILDINGS.items():
        T.LEVEL_INC_BY_KIND[kind] = 0.06
        const = f"PROBE_{kind.upper()}_UPGRADE_BASE"
        setattr(T, const, 10.0)
        level = "booth_level" if kind == "booth" else T.PROCESSORS[kind]["level"]
        T.BUILDINGS[kind] = {"label": label, "cost": const, "level": level, "owned": "probe_dam"}
    T.ROLE_BASE.update({
        "probeBatCollector": 4.0, "probeBatPorter": 6.0, "probeBatHauler": 7.5,
        "probeWireCollector": 4.0, "probeWirePorter": 5.0, "probeWireHauler": 7.0, "probeRunner": 7.0,
    })
    T.GOODS["probe_grid"] = 50.0
    # Piesele NU se vand. Media lor e pusa intentionat ne-zero: un venit care le-ar numara ar iesi altul decat cel de mana.
    T.AVG["probe_bat"] = 5.0
    T.AVG["probe_wire"] = 7.0
    T.ROLES = T.ROLES + BAT_ROLES + WIRE_ROLES + GRID_ROLES + ("probeDispatcher",)
    for role in BAT_ROLES + WIRE_ROLES + GRID_ROLES + ("probeDispatcher",):
        T.ROLE_NAMES[role] = role
    rederive(T)


def dam_fields(s, dam):
    s.probe_dam = dam
    s.probe_yard_level = s.probe_works_level = s.probe_relay_level = s.booth_level = 1
    return s


def dam_start(T):
    """Startul barajului, in mic: turbina din zid (rangul 5) si prima plasa de cablu (rangul 1), veteranii pe linia
    bateriilor si la oras; cablul si releul le faci tu."""
    s = dam_fields(era1_state(T), True)
    T.unlock_net_ranked("probe_bat", 5, 3, 1)(s)
    T.unlock_net_ranked("probe_wire", 1, 1, 1)(s)
    staff(s, T, BAT_ROLES + ("probeDispatcher",), 1, 1)
    return s


def join_problems(expect):
    base = load()
    before_state = era1_state(base)
    before, before_income = base.chain(before_state), base.income(before_state)
    no_unlocks = {"unlocks": []}
    before_labels = [o[0] for o in base.options(before_state, {}, no_unlocks)]

    T = load()
    add_join_lines(T)
    states = []  # pe fiecare: o piesa livreaza cat ia unirea

    # 0. INAINTE DE BARAJ: `closeFlag` pus, dar fals; piesele si unirea inca nedeschise. Totul ca pe copia neatinsa.
    s = dam_fields(era1_state(T), False)
    c = T.chain(s)
    states.append(c)
    expect("inainte de baraj: venitul", T.income(s), before_income)
    expect("inainte de baraj: veriga care tine venitul", c.bottleneck, before.bottleneck)
    expect("inainte de baraj: liniile vechi", tuple(c.lines[l].delivered for l in base.LINE_ORDER),
           tuple(before.lines[l].delivered for l in base.LINE_ORDER))
    expect("inainte de baraj: unirea nu livreaza", (c.lines["probeGrid"].delivered, c.lines["probeGrid"].bottleneck), (0.0, ""))
    expect("inainte de baraj: ce se poate cumpara", [o[0] for o in T.options(s, {}, no_unlocks)], before_labels)
    # venitul il tine forja, nu plasele: `nets_line` ramane gol chiar daca plasele au si ele un castig
    expect("inainte de baraj: ale cui plase (veriga nu e `nets`)", (c.bottleneck != "nets", c.nets_line), (True, ""))

    # 1. STARTUL BARAJULUI. Liniile vechi inchise. Pasii de mana ai bazinului: 4 ai cablului + 2 ai unirii = 6, deci
    #    fiecare drum 3.6 x 1.5 / 6 = 0.9, atelierul cablului 2.0 / 6, releul 2.8 / 6. Bateriile (veteranii) ar duce cat
    #    turbina, 0.33 x 1.45^4 = 1.4587670625; cablul, cat plasa lui, 0.33. Unirea ia 0.33 din fiecare: bateriile sunt
    #    tinute de unire, iar unirea de plasa cablului. Venitul: 0.33 x 50.
    s = dam_start(T)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("baraj: liniile vechi nu livreaza", tuple(c.lines[l].delivered for l in base.LINE_ORDER), (0.0,) * len(base.LINE_ORDER))
    expect("baraj: liniile vechi n-au veriga", tuple(c.lines[l].bottleneck for l in base.LINE_ORDER), ("",) * len(base.LINE_ORDER))
    expect("baraj: lemnul e inchis desi n-are openFlag", T.line_open(s, "wood"), False)
    expect("baraj: drumul cablului (bazinul de 6)", dict(wire.rates)["probeWireCollect"], 0.9)
    expect("baraj: atelierul cablului", dict(wire.rates)["probeWorks"], 2.0 / 6)
    expect("baraj: releul", dict(grid.rates)["probeRelay"], 2.8 / 6)
    expect("baraj: drumul curentului", dict(grid.rates)["probeRun"], 0.9)
    expect("baraj: turbina", bat.supply, 1.4587670625)
    expect("baraj: ce intra in unire", grid.supply, 0.33)
    expect("baraj: unirea n-are plase", grid.catch, 0.0)
    expect("baraj: livrat", (bat.delivered, wire.delivered, grid.delivered), (0.33, 0.33, 0.33))
    expect("baraj: bateriile tinute de unire", (bat.by_consumer, wire.by_consumer), (True, False))
    expect("baraj: verigile", (bat.bottleneck, wire.bottleneck, grid.bottleneck), ("nets", "nets", "nets"))
    expect("baraj: a cui e veriga", (bat.held_by, wire.held_by, grid.held_by), ("probeWire", "probeWire", "probeWire"))
    expect("baraj: veriga care tine venitul", (c.bottleneck, c.nets_line), ("nets", "probeWire"))
    expect("baraj: venitul (doar curentul se vinde)", T.income(s), 16.5)
    # un nivel la plasa cablului (0.3399) aduce doar pana la atelierul cablului (2.0 / 6): 50 x (2/6 - 0.33)
    expect("baraj: un nivel la plasa cablului", T.gain_of(s, lambda st: setattr(st.nets[6], "level", 2)), 50 * (2.0 / 6 - 0.33))
    expect("baraj: un nivel la turbina nu aduce nimic", T.gain_of(s, lambda st: setattr(st.nets[5], "level", 2)), 0.0)
    want = ["Net 6 lvl 2", "Net 7 lvl 2", "Probe Yard lvl 2", "Probe Works lvl 2", "Probe Relay lvl 2", "Booth lvl 2"]
    want += [f"{r} tier 2" for r in BAT_ROLES + ("probeDispatcher",)]
    expect("baraj: nimic de cumparat pe liniile inchise", [o[0] for o in T.options(s, {}, no_unlocks)], want)

    # 2. BAZINUL, fara niciun om pe baraj: 10 pasi de mana, deci drumurile 0.54, curtea 0.24, atelierul 0.2, releul
    #    0.28. Bateriile 0.24, cablul 0.2: unirea e tinuta de atelierul cablului.
    s = dam_start(T)
    staff(s, T, BAT_ROLES + ("probeDispatcher",), 0, 1)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("bazin: drumul bateriilor", dict(bat.rates)["probeBatCollect"], 0.54)
    expect("bazin: curtea", dict(bat.rates)["probeYard"], 0.24)
    expect("bazin: atelierul cablului", dict(wire.rates)["probeWorks"], 0.2)
    expect("bazin: releul", dict(grid.rates)["probeRelay"], 0.28)
    expect("bazin: livrat", grid.delivered, 0.2)
    expect("bazin: verigile", (bat.bottleneck, bat.held_by, grid.bottleneck, grid.held_by),
           ("probeWorks", "probeWire", "probeWorks", "probeWire"))
    expect("bazin: veriga care tine venitul", c.bottleneck, "probeWorks")
    expect("bazin: venitul", T.income(s), 10.0)
    # o linie din bazin care nu e deschisa (cablul fara plasa, deci nici unirea) nu ia din timpul tau: 5.4 / 4
    s = dam_fields(era1_state(T), True)
    T.unlock_net_ranked("probe_bat", 5, 3, 1)(s)
    c = T.chain(s)
    states.append(c)
    expect("bazin cu cablul inchis: drumul bateriilor", dict(c.lines["probeBat"].rates)["probeBatCollect"], 1.35)
    expect("bazin cu cablul inchis: curtea", dict(c.lines["probeBat"].rates)["probeYard"], 0.6)
    expect("bazin cu cablul inchis: drumul cablului", dict(c.lines["probeWire"].rates)["probeWireCollect"], 0.0)
    expect("bazin cu cablul inchis: nimic nu se vinde", (c.lines["probeGrid"].delivered, T.income(s)), (0.0, 0.0))
    # bateriile asteapta plasa cablului, nu "nimic" [D43]: veriga lor e plasa liniei care lipseste din unire
    bat = c.lines["probeBat"]
    expect("bazin cu cablul inchis: bateriile asteapta plasa cablului", (bat.active, bat.bottleneck, bat.held_by),
           (True, "nets", "probeWire"))
    # niciun castig nicaieri: veriga globala ramane "nets" din oficiu, dar nicio plasa nu o tine
    expect("bazin cu cablul inchis: ale cui plase", (c.bottleneck, c.nets_line), ("nets", ""))
    # regula ingusta din `options`: o cladire detinuta se urca si cat linia ei nu e inca deschisa (ca forja inaintea
    # plasei de scrap in joc); doar liniile inchise de `closeFlag` ies din lista
    expect("bazin cu cablul inchis: ce se poate cumpara", [o[0] for o in T.options(s, {}, no_unlocks)],
           ["Net 6 lvl 2", "Probe Yard lvl 2", "Probe Works lvl 2", "Probe Relay lvl 2", "Booth lvl 2"])

    # 3. EGALITATE INTRE PIESE. Intai pe plase: o turbina de rangul 1 prinde cat plasa cablului (0.33). Plasele
    #    amandurora duc castigul, iar `nets_line` numeste prima linie, in LINE_ORDER; unirea, prima piesa din `inputs`.
    s = dam_fields(era1_state(T), True)
    T.unlock_net_ranked("probe_bat", 1, 1, 1)(s)
    T.unlock_net_ranked("probe_wire", 1, 1, 1)(s)
    staff(s, T, BAT_ROLES + ("probeDispatcher",), 1, 1)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("egalitate pe plase: livrat", grid.delivered, 0.33)
    expect("egalitate pe plase: verigile", (bat.bottleneck, wire.bottleneck, grid.bottleneck, grid.held_by),
           ("nets", "nets", "nets", "probeBat"))
    expect("egalitate pe plase: ale cui plase", (c.bottleneck, c.nets_line), ("nets", "probeBat"))
    #    Apoi pe oameni. Turbina la nivel 25 (10.04) si plasa cablului la 50 (6.52); fiecare piesa tinuta de omul care
    #    aduna, la 4.0. Unirea si orasul, cu cate doi oameni pe treapta 5, sunt departe (28, 70, 30).
    s = dam_start(T)
    s.nets[5].level, s.nets[6].level = 25, 50
    staff(s, T, BAT_ROLES + WIRE_ROLES, 1, 1)
    staff(s, T, ("probeSwitchman",), 1, 2)  # 4.8
    staff(s, T, ("probeWiremaker",), 1, 3)  # 6.0
    staff(s, T, GRID_ROLES + ("probeDispatcher",), 2, 5)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("egalitate: marginile pieselor", (bat.own_max, wire.own_max), (4.0, 4.0))
    expect("egalitate: livrat", grid.delivered, 4.0)
    expect("egalitate: verigile (unirea: a primei piese)", (bat.bottleneck, wire.bottleneck, grid.bottleneck, grid.held_by),
           ("probeBatCollect", "probeWireCollect", "probeBatCollect", "probeBat"))
    expect("egalitate: nicio piesa tinuta de unire", (bat.by_consumer, wire.by_consumer), (False, False))
    expect("egalitate: amandoua piesele duc castigul", (c.gains["probeBatCollect"], c.gains["probeWireCollect"]), (50.0, 50.0))
    expect("egalitate: veriga care tine venitul (prima, in ordinea verigilor)", c.bottleneck, "probeBatCollect")
    expect("egalitate: venitul", T.income(s), 200.0)

    def tier_up(*roles):
        def f(st):
            for role in roles:
                st.crews[role].tier += 1
        return f

    expect("egalitate: doar Collector-ul bateriilor nu aduce nimic", T.gain_of(s, tier_up("probeBatCollector")), 0.0)
    expect("egalitate: doar Collector-ul cablului nu aduce nimic", T.gain_of(s, tier_up("probeWireCollector")), 0.0)
    expect("egalitate: amandoi aduc 0.8 x 50", T.gain_of(s, tier_up("probeBatCollector", "probeWireCollector")), 40.0)
    # amandoua piesele au castigul unei bucati in plus: dupa o treapta la bateriile, veriga ramasa e a cablului, iar
    # bateriile (acum 4.8, tinute de unire) o arata pe a lui, cu linia care o detine
    tier_up("probeBatCollector")(s)
    c = T.chain(s)
    states.append(c)
    bat = c.lines["probeBat"]
    expect("dupa egalitate: bateriile tinute de unire", (bat.own_max, bat.by_consumer), (4.8, True))
    expect("dupa egalitate: veriga bateriilor e a cablului", (bat.bottleneck, bat.held_by), ("probeWireCollect", "probeWire"))
    expect("dupa egalitate: veriga care tine venitul", c.bottleneck, "probeWireCollect")

    # 4. UNIREA TINUTA DE RELEU. Piesele cu toti oamenii lor (bateriile 1.4588, cablul 2.0 din atelier); unirea de mana:
    #    2 pasi in bazin, deci releul 2.8 / 2 = 1.4, drumul 2.7. Ambele piese livreaza 1.4 si arata releul.
    s = dam_start(T)
    s.nets[6].level = 50
    staff(s, T, WIRE_ROLES, 1, 1)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("releul: releul si drumul", (dict(grid.rates)["probeRelay"], dict(grid.rates)["probeRun"]), (1.4, 2.7))
    expect("releul: livrat", (bat.delivered, wire.delivered, grid.delivered), (1.4, 1.4, 1.4))
    expect("releul: verigile", (bat.bottleneck, wire.bottleneck, grid.bottleneck), ("probeRelay",) * 3)
    expect("releul: a cui e veriga", (bat.held_by, wire.held_by, grid.held_by), ("probeGrid",) * 3)
    expect("releul: veriga care tine venitul", (c.bottleneck, c.nets_line), ("probeRelay", ""))
    expect("releul: venitul", T.income(s), 70.0)
    #    ... APOI DE ORAS: Relay Keeper-ul (2.8) si orasul fara Dispatcher (3.0 x 0.35 = 1.05). Unirea ar duce 1.4588.
    staff(s, T, ("probeRelayKeeper",), 1, 1)
    staff(s, T, ("probeDispatcher",), 0, 1)
    c = T.chain(s)
    states.append(c)
    bat, wire, grid = c.lines["probeBat"], c.lines["probeWire"], c.lines["probeGrid"]
    expect("orasul: drumul (un pas de mana)", dict(grid.rates)["probeRun"], 5.4)
    expect("orasul: livrat", (bat.delivered, wire.delivered, grid.delivered), (1.05, 1.05, 1.05))
    expect("orasul: unirea tinuta de oras", (grid.by_seller, grid.bottleneck, grid.held_by), (True, "booth", "probeGrid"))
    expect("orasul: piesele arata orasul", (bat.bottleneck, wire.bottleneck, bat.held_by), ("booth", "booth", "probeGrid"))
    expect("orasul: veriga care tine venitul", c.bottleneck, "booth")
    expect("orasul: venitul", T.income(s), 52.5)

    # 5. RELEUL EXACT CAT CE INTRA (o copie cu releul de doua ori turbina, deci 2x / 2 = turbina, bit cu bit): la
    #    egalitate intre piese si pasii unirii, veriga e a pieselor, verificate inaintea pasilor (ca plasele in fata).
    R = load()
    add_join_lines(R)
    R.PROBE_RELAY_BASE_RATE = 2 * (R.NET_BASE_RATE * R.NET_BASE_GROWTH**4)
    s = dam_start(R)
    s.nets[6].level = 50
    staff(s, R, WIRE_ROLES, 1, 1)
    c = R.chain(s)
    states.append(c)
    grid = c.lines["probeGrid"]
    expect("releul cat turbina: egalitate", dict(grid.rates)["probeRelay"] == grid.supply == grid.own_max, True)
    expect("releul cat turbina: veriga unirii e a pieselor", (grid.bottleneck, grid.held_by), ("nets", "probeBat"))

    # 6. EGALITATE INTRE O PIESA SI RELEU (o copie cu Collector-ul cablului la 1.4): cablul duce 1.4, releul de mana
    #    2.8 / 2 = 1.4. Castigul il primesc amandoua verigile; veriga globala e prima in ordinea verigilor (a cablului).
    W = load()
    add_join_lines(W)
    W.ROLE_BASE["probeWireCollector"] = 1.4
    s = dam_start(W)
    s.nets[6].level = 50
    staff(s, W, WIRE_ROLES, 1, 1)
    c = W.chain(s)
    states.append(c)
    bat, grid = c.lines["probeBat"], c.lines["probeGrid"]
    expect("piesa cat releul: ce intra si releul", (grid.supply, dict(grid.rates)["probeRelay"]), (1.4, 1.4))
    expect("piesa cat releul: veriga unirii", (grid.bottleneck, grid.held_by), ("probeWireCollect", "probeWire"))
    expect("piesa cat releul: castigul pe amandoua", (c.gains["probeRelay"], c.gains["probeWireCollect"]), (50.0, 50.0))
    expect("piesa cat releul: veriga care tine venitul", c.bottleneck, "probeWireCollect")
    expect("piesa cat releul: bateriile tinute de unire", (bat.by_consumer, bat.bottleneck, bat.held_by),
           (True, "probeWireCollect", "probeWire"))

    for i, c in enumerate(states):
        grid = c.lines["probeGrid"]
        for part in ("probeBat", "probeWire"):
            expect(f"starea {i}: {part} livreaza cat unirea", c.lines[part].delivered, grid.delivered)
        expect(f"starea {i}: nicio linie activa fara veriga slaba", T.silent_lines(c), [])

    # 7. PLASA DE SIGURANTA: o unire oprita de campul ei, cu piesele deschise, le-ar lasa pe ele active fara veriga.
    #    Nicio forma din plan nu ajunge aici (piesele si unirea au acelasi `openFlag`); `silent_lines` o prinde.
    U = load()
    add_join_lines(U)
    U.LINES["probeGrid"]["openFlag"] = "probe_relay_built"
    s = dam_start(U)
    s.probe_relay_built = False
    expect("unire oprita de campul ei: plasa de siguranta", U.silent_lines(U.chain(s)), ["probeBat", "probeWire"])

    # 8. INVARIANTELE: derive_tables refuza un tabel care nu se leaga
    def refused(what, change):
        lines = {line: dict(spec) for line, spec in T.LINES.items()}
        sellers = {seller: dict(spec) for seller, spec in T.SELLERS.items()}
        order = change(lines, sellers)  # o schimbare a ordinii intoarce noua ordine; restul, ce intoarce `update`/`pop`
        order = order if isinstance(order, tuple) else T.LINE_ORDER
        try:
            T.derive_tables(order, lines, sellers, T.ROLES)
        except AssertionError:
            return
        expect(f"derive_tables primeste {what}", "primit", "refuzat")

    refused("`source` (e a curierului din Era 5)", lambda L, S: L["probeGrid"].update(source="probeGrid"))
    refused("o unire fara `value`", lambda L, S: L["probeGrid"].pop("value"))
    refused("o linie cu plase si piese deodata", lambda L, S: L["probeGrid"].update(netKind="probe_grid"))
    refused("o linie fara plase si fara piese", lambda L, S: L["probeWire"].pop("netKind"))
    refused("o piesa care si vinde", lambda L, S: L["probeWire"].update(seller="booth"))
    refused("o piesa in afara pieselor unirii", lambda L, S: L["probeGrid"].update(inputs=("probeBat",)))
    refused("o piesa in randul unui vanzator", lambda L, S: S["booth"].update(priority=("probeGrid", "probeWire")))
    refused("o piesa dupa unirea ei", lambda L, S: T.LINE_ORDER[:-3] + ("probeBat", "probeGrid", "probeWire"))
    refused("doua linii pe acelasi fel de plasa", lambda L, S: L["probeWire"].update(netKind="probe_bat"))


def tool_problems(expect):
    """Doua unelte pe care Era 4 le cere: plasa cu rang explicit si pretul rotund peste 10^12."""
    T = load()
    # rangul 5 al Erei 3 e bit cu bit First Turbine (a 15-a plasa, pe locul ei)
    by_place, by_rank = T.State(), T.State()
    for k in range(1, 16):
        T.unlock_net(k)(by_place)
    T.unlock_net_ranked("turbine", 5, 3, 3)(by_rank)
    a, b = by_place.nets[14], by_rank.nets[0]
    expect("plasa cu rang: baza, banda, felul", (b.base, b.base_lane, b.kind) == (a.base, a.base_lane, a.kind), True)
    expect("plasa cu rang: costul nivelurilor", T.net_upgrade_base(by_rank, 0) == T.net_upgrade_base(by_place, 14), True)

    def old_nice(x, floor=0):
        """Regula de pana la D70, ca dovada ca pana la 10^12 nimic nu s-a mutat. None unde cadea pe `int(x)`."""
        if x < 10:
            v = max(0, int(round(x)))
            return v if v > floor else floor + 1
        for mag in (10**k for k in range(0, 13)):
            for n in T.NICE:
                v = int(n * mag)
                if v >= x * 0.93 and v > floor:
                    return v
        return None

    x, moved = 0.5, []
    while x < 9e12:
        for floor in (0, old_nice(x)):
            was = old_nice(x, floor)
            if was is not None and T.nice(x, floor) != was:
                moved.append((x, floor))
        x *= 1.013
    expect("nice: preturile pana la 10^12 raman bit cu bit", moved, [])

    def nice(x, floor=0):
        try:
            return T.nice(x, floor)
        except SystemExit:
            return "oprire"

    # unde regula veche cadea pe `int(x)` (un pret nerotunjit, si nici peste cel dinainte), acum urca la 10^13
    expect("nice: peste 9 x 10^12 cu podeaua 9 x 10^12", nice(8.8e12, 9 * 10**12), 10**13)
    expect("nice: 2.8 x 10^14 e rotund (virgula mobila dadea ...999)", nice(2.7e14), 280000000000000)
    expect("nice: 1.1 x 10^17 e rotund", nice(1.1e17), 110000000000000000)
    expect("nice: 5 x 10^24", nice(5e24), 5 * 10**24)
    expect("nice: peste 9 x 10^24 simulatorul se opreste", nice(1e26), "oprire")


def dam_gate_problems(expect):
    """[D70] Uneltele portilor barajului (pasul d), cu cifre socotite de mana: suma de start, platoul, "tararea",
    cheltuiala unui buget, venitul cat lipsesti si treptele moarte."""
    T = load()
    # nice_up: cel mai mic pret rotund care nu e sub x (nu rotunjeste in jos, ca nice)
    expect("nice_up: o noapte la Works Bell -> 35T", T.nice_up(34.86e12), 35 * 10**12)
    expect("nice_up: fix pe treapta", T.nice_up(35e12), 35 * 10**12)
    expect("nice_up: intre trepte, in sus", T.nice_up(35.1e12), 40 * 10**12)
    # randuri de proba: (eticheta, fel, pret, t, venit dupa, veriga)
    rows = [
        ("a", "nets", 1, 10, 100.0, "nets"),
        ("b", "nets", 1, 20, 100.0, "nets"),  # nicio crestere
        ("c", "nets", 1, 30, 101.0, "nets"),  # +1%
        ("d", "nets", 1, 70, 112.0, "nets"),  # +10.9% fata de 101
    ]
    # platoul: de la 10 (100) pana la 30 (101): 20 de secunde; apoi 30..70: 40; la coada 70..100: 30
    expect("longest_flat: tronsonul cel mai lung", T.longest_flat(rows, 0, 50.0, 100), 40)
    expect("longest_flat: coada cea mai lunga", T.longest_flat(rows, 0, 50.0, 200), 130)
    expect("longest_flat: fara cumparaturi, toata era", T.longest_flat([], 5, 50.0, 25), 20)
    # tararea (<10%): din 10 (100) abia la 70 (112) trece de 110: 60 de secunde; din 70 pana la capat (100): 30
    expect("longest_crawl: +1% nu opreste numaratoarea", T.longest_crawl(rows, 0, 50.0, 100), 60)
    # un buget care se opreste la prima cumparatura prea scumpa, chiar daca una de dupa ar incapea
    spend = [("x", "nets", 5, 10, 1.0, "nets"), ("y", "nets", 10, 20, 1.0, "nets"), ("z", "nets", 1, 30, 1.0, "nets")]
    expect("spend_share: se opreste la prima prea scumpa", T.spend_share(12, spend, 0, 40), (1, "x", 0.25))
    # venitul cat lipsesti: fara om nu merge nimic, iar AWAY redevine fals si dupa o eroare
    s = T.State()
    T.unlock_net(1)(s)
    expect("away_income: fara oameni, zero", T.away_income(s), 0.0)
    expect("away_income: AWAY redevine fals", T.AWAY, False)
    broken = T.State()
    broken.nets = None  # income crapa pe drum
    try:
        T.away_income(broken)
    except Exception:
        pass
    expect("away_income: AWAY redevine fals si dupa o eroare", T.AWAY, False)
    # treptele moarte: doar cele luate cat meseria era veriga slaba aratata
    tiers = [
        ("Collector tier 2", "collect", 1, 1, 10.0, "collect"),
        ("Collector tier 3", "collect", 1, 2, 10.0, "port"),  # zero, luata pe veriga aratata (collect)
        ("Porter tier 2", "port", 1, 3, 12.0, "saw"),  # luata pe veriga aratata (port), cu crestere
        ("Porter tier 3", "port", 1, 4, 12.0, "saw"),  # zero, dar veriga aratata era saw: nu se numara
    ]
    expect("dead_tiers: doar pe veriga aratata", T.dead_tiers(tiers, ("collector", "porter"), "collect"),
           {"collector": (1, 2), "porter": (0, 1)})
    expect("too_many_dead: 2 din 5 trec, 3 din 5 nu", (T.too_many_dead(2, 5), T.too_many_dead(3, 5)), (False, True))


def problems():
    bad = []

    def expect(what, got, want):
        if isinstance(want, float):
            ok = abs(got - want) < 1e-9
        elif isinstance(want, tuple) and any(isinstance(w, float) for w in want):
            ok = len(got) == len(want) and all(
                abs(g - w) < 1e-9 if isinstance(w, float) else g == w for g, w in zip(got, want)
            )
        else:
            ok = got == want
        if not ok:
            bad.append(f"check_lines: {what}: a iesit {got!r}, socotit de mana {want!r}")

    join_problems(expect)
    tool_problems(expect)
    dam_gate_problems(expect)

    base = load()
    before = base.chain(era1_state(base))
    before_income = base.income(era1_state(base))

    T = load()
    add_probe_lines(T)

    # 0. Liniile noi, inchise: Era 1 nu simte nimic
    s = with_probe_fields(era1_state(T), None, None, T)
    c = T.chain(s)
    expect("liniile de proba inchise nu livreaza", (c.lines["probeA"].delivered, c.lines["probeB"].delivered), (0.0, 0.0))
    expect("liniile de proba inchise n-au veriga slaba", (c.lines["probeA"].bottleneck, c.lines["probeB"].bottleneck), ("", ""))
    expect("venitul Erei 1 cu liniile de proba inchise", T.income(s), before_income)
    expect("veriga care tine venitul, cu liniile de proba inchise", c.bottleneck, before.bottleneck)

    # 1. A treia linie, de mana, la vanzatorul ei fara om. Timpul tau intreg pe cei patru pasi ai ei: 3.6 x 1.5
    #    (traista mare) / 4 = 1.35 pe pas; turnatoria de mana 2.0 / 4 = 0.5; plasa 1.0 -> linia duce 0.5, tinuta de
    #    turnatorie. Piata fara negustor: 5.0 x 0.35 = 1.75, deci nu ea e marginea.
    s = with_probe_fields(era1_state(T), 1.0, None, T)
    c = T.chain(s)
    parts = c.lines["probeA"]
    expect("piese de mana: pasii de drum", dict(parts.rates)["probeACollect"], 1.35)
    expect("piese de mana: turnatoria", dict(parts.rates)["kilnA"], 0.5)
    expect("piese de mana: livrat", parts.delivered, 0.5)
    expect("piese de mana: veriga slaba", parts.bottleneck, "kilnA")
    expect("piese de mana: Piata", c.capacity["stall"], 1.75)
    expect("piese de mana: venitul creste cu 0.5 x 8", T.income(s) - before_income, 4.0)
    expect("piese de mana: lemnul neatins", c.lines["wood"].delivered, before.wood)
    expect("piese de mana: fierul neatins", c.lines["iron"].delivered, before.scrap)
    expect("piese de mana: taverna neatinsa", c.capacity["dock"], before.sales)
    # o bucata de piese (8.0) bate una de fier (3.55): veriga care tine venitul e acum turnatoria
    expect("piese de mana: veriga care tine venitul", c.bottleneck, "kilnA")

    # 2. Aceeasi linie cu oameni (cate doi, treapta 5): drumurile 3 x 5 x 2 = 30, turnatoria 2 x 5 x 2 = 20, negustorul
    #    5 x 5 x 2 = 50 -> plasa (1.0) e marginea.
    staff(s, T, PARTS_ROLES + ("stallkeeper",), 2, 5)
    c = T.chain(s)
    expect("piese cu oameni: drum", dict(c.lines["probeA"].rates)["probeAHaul"], 30.0)
    expect("piese cu oameni: turnatoria", dict(c.lines["probeA"].rates)["kilnA"], 20.0)
    expect("piese cu oameni: Piata", c.capacity["stall"], 50.0)
    expect("piese cu oameni: livrat", c.lines["probeA"].delivered, 1.0)
    expect("piese cu oameni: veriga slaba", c.lines["probeA"].bottleneck, "nets")
    expect("piese cu oameni: venitul creste cu 1 x 8", T.income(s) - before_income, 8.0)

    # 3. Doua linii la ACELASI al doilea vanzator, el fiind marginea. Piata cu un negustor de treapta 1 duce 5.0.
    #    Cuprul (12 pe bucata) e primul la rand: plasa lui da 3.0 -> livreaza 3.0, raman 2.0. Piesele ar putea 4.0, dar
    #    primesc 2.0: Piata le tine. O bucata de cupru in plus ar lua locul uneia de piese: 12 - 8 = 4. Piata in plus
    #    ar vinde piese: 8. Deci veriga care tine venitul e Piata (8 > 4 > 3.55 > 1.65).
    s = with_probe_fields(era1_state(T), 4.0, 3.0, T)
    staff(s, T, PARTS_ROLES + COPPER_ROLES, 2, 5)
    staff(s, T, ("stallkeeper",), 1, 1)
    c = T.chain(s)
    expect("doua linii la Piata: cuprul livrat", c.lines["probeB"].delivered, 3.0)
    expect("doua linii la Piata: piesele livrate", c.lines["probeA"].delivered, 2.0)
    expect("doua linii la Piata: piesele tinute de Piata", c.lines["probeA"].bottleneck, "stall")
    expect("doua linii la Piata: cuprul tinut de plasa lui", c.lines["probeB"].bottleneck, "nets")
    expect("doua linii la Piata: veriga care tine venitul", c.bottleneck, "stall")
    expect("doua linii la Piata: venitul creste cu 3 x 12 + 2 x 8", T.income(s) - before_income, 52.0)
    expect("doua linii la Piata: taverna neatinsa", (c.lines["wood"].delivered, c.lines["iron"].delivered), (before.wood, before.scrap))

    # 4. Piata largita (negustor de treapta 2: 10.0): amandoua liniile curg cat prind, nimeni nu mai e tinut de ea.
    staff(s, T, ("stallkeeper",), 1, 2)
    c = T.chain(s)
    expect("Piata largita: piesele livrate", c.lines["probeA"].delivered, 4.0)
    expect("Piata largita: piesele tinute de plasa lor", c.lines["probeA"].bottleneck, "nets")
    expect("Piata largita: venitul creste cu 3 x 12 + 4 x 8", T.income(s) - before_income, 68.0)
    return bad


if __name__ == "__main__":
    found = problems()
    for line in found:
        print(line)
    if found:
        sys.exit(1)
    print(
        "check_lines: motorul duce liniile de proba (a treia si a patra linie, al doilea vanzator) si unirea de la baraj"
        " (doua piese, bazinul, liniile inchise) cum iese din socoteala de mana"
    )
