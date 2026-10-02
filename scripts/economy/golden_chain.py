#!/usr/bin/env python3
"""Tipareste valorile de aur pentru tests/ChainMath.test.luau, direct din simulator [D55, D56].

Pana la D55 tabelul GOLDEN din test era copiat de mana din repr-urile simulatorului. Cu doua linii si mai
multe campuri, copiatul de mana devenea locul in care se strecoara o greseala; acum se regenereaza:

    python3 scripts/economy/golden_chain.py > /tmp/golden.luau
    python3 scripts/economy/golden_chain.py --era2 > /tmp/golden_era2.luau     # [D65] blocul `local GOLDEN_ERA2`
    python3 scripts/economy/golden_chain.py --era3 > /tmp/golden_era3.luau     # [D67] blocul `local GOLDEN_ERA3`
    python3 scripts/economy/golden_chain.py --era4 > /tmp/golden_era4.luau     # [D70] blocul `local GOLDEN_ERA4`

si blocul `local GOLDEN = { ... }` din test se inlocuieste cu iesirea. Starile sunt construite exact ca
`state()` din test: plasa i are baza NET_BASE_RATE * NET_BASE_GROWTH^(i-1), banda si felul din NET_LANES /
NET_KINDS.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sim_tycoon as T  # noqa: E402

ALL_WOOD = {"collector": (2, 5), "porter": (2, 5), "sawyer": (2, 5), "hauler": (2, 5), "trader": (2, 5)}

# (nume, niveluri plase, gater, taverna, traista, oameni {rol: (cati, treapta)}, Forge, nivelul forjei)
CASES = [
    ("o plasa nivel 1, totul de mana", [1], 1, 1, False, {}, False, 1),
    ("doua plase nivel 5", [5, 5], 1, 1, False, {}, False, 1),
    ("Collector angajat: restul pasilor primesc mai mult din timpul tau", [5, 5], 1, 1, False,
     {"collector": (1, 1)}, False, 1),
    ("traista mare pe pasii de mana", [10, 8], 3, 2, True, {"collector": (1, 1), "porter": (1, 1)}, False, 1),
    ("toti oamenii lemnului, trepte diferite, plasa a cincea fara Forge", [14, 11, 9, 6, 3], 8, 8, True,
     {"collector": (2, 5), "porter": (1, 3), "sawyer": (1, 2), "hauler": (1, 4), "trader": (1, 2)}, False, 1),
    ("fara Negustor: debarcaderul merge la o treime", [10, 10], 20, 5, False,
     {"collector": (1, 2), "porter": (1, 2), "sawyer": (1, 1), "hauler": (1, 1)}, False, 1),
    ("gaterul de mana e gatuirea", [10, 10], 1, 10, False, {"collector": (1, 1), "porter": (1, 1), "hauler": (1, 1)},
     False, 1),
    ("prag 25 pe toate, echipaj la maxim, fara Forge", [25, 25, 25, 25, 25], 25, 25, True,
     {r: (2, 5) for r in T.ERA1_ROLES}, False, 1),
    # ---- [D56] linia fierului ----
    ("Forge fara plasa de scrap: fierul nu exista", [30, 30, 25, 20], 30, 30, True, dict(ALL_WOOD), True, 1),
    ("turul de mana al fierului: patru pasi, timpul tau intreg pe ei", [30, 30, 25, 20, 1], 30, 30, True,
     dict(ALL_WOOD), True, 1),
    ("Scrap Collector si Scrap Porter angajati: forja de mana e gatuirea", [30, 30, 25, 20, 10], 30, 30, True,
     dict(ALL_WOOD, scrapCollector=(1, 3), scrapPorter=(1, 3)), True, 1),
    ("toti oamenii fierului, forja mare: Scrap Collector-ul tine fierul", [30, 30, 25, 20, 25], 30, 30, True,
     dict(ALL_WOOD, scrapCollector=(1, 1), scrapPorter=(2, 5), smelter=(2, 5), ironHauler=(2, 5)), True, 40),
    ("taverna plina: fierul intai, lemnul din ce ramane", [60, 60, 60, 60, 40], 60, 3, True,
     dict(ALL_WOOD, scrapCollector=(2, 5), scrapPorter=(2, 5), smelter=(2, 5), ironHauler=(2, 5)), True, 60),
    ("Iron Hauler-ul de mana e gatuirea fierului", [40, 40, 40, 40, 30], 40, 40, True,
     dict(ALL_WOOD, scrapCollector=(2, 5), scrapPorter=(2, 5), smelter=(2, 5)), True, 60),
]


def build(levels, saw, dock, sack, crews, forge_owned, forge):
    s = T.State()
    for i, lv in enumerate(levels):
        s.nets.append(T.Net(T.NET_BASE_RATE * T.NET_BASE_GROWTH ** i, T.NET_LANES[i], lv, T.NET_KINDS[i]))
    s.saw_level, s.dock_level, s.sack_big = saw, dock, sack
    for role, (count, tier) in crews.items():
        s.crews[role] = T.Crew(count, tier)
    s.workshop, s.forge_level = forge_owned, forge
    return s


# [D70] TABELELE DE AUR ALE ERELOR 1-3 TIPARESC DOAR LINIILE SI VANZATORII LOR. Liniile erelor noi (Era 4: bateriile,
# cablul, curentul, cristalul, orasul) se adauga la coada lui LINE_ORDER si stau inchise in starile de aici; tiparite,
# ar schimba textul tabelelor din tests/ChainMath.test.luau desi nicio cifra de-a lor nu se misca.
GOLDEN_ERAS = (1, 2, 3)
GOLDEN_LINES = tuple(line for line in T.LINE_ORDER if any(line in T.ERA_LINES[era] for era in GOLDEN_ERAS))
GOLDEN_SELLERS = tuple(
    seller for seller in T.SELLERS if any(T.LINES[line].get("seller") == seller for line in GOLDEN_LINES)
)


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    return repr(float(v))


# ---- [D65] Era 2: stari cu liniile Morii, in forma generica (pe linii), pentru `ChainMath.flow` ----
ERA1_DONE = dict(ALL_WOOD, scrapCollector=(2, 5), scrapPorter=(2, 5), smelter=(2, 3), ironHauler=(2, 4))
ALL_PARTS = {"millCollector": (2, 5), "millPorter": (2, 5), "founder": (2, 5), "partsHauler": (2, 5), "merchant": (2, 5)}
ALL_COPPER = {"oreCollector": (2, 5), "orePorter": (2, 5), "coppersmith": (2, 5), "copperHauler": (2, 5)}
E1 = [32, 30, 28, 26, 27]  # plasele Erei 1 la finalul ei

# (nume, niveluri plase 1..n, gater, taverna, forja, oameni, roata, cuptor, nivel turnatorie, nivel cuptor, nivel Piata)
CASES_ERA2 = [
    ("Era 1 incheiata, Moara inca inchisa: liniile ei nu exista", E1, 30, 30, 20, dict(ERA1_DONE), False, False, 1, 1, 1),
    ("roata de apa fara plasa a sasea: piesele nu exista", E1, 30, 30, 20, dict(ERA1_DONE), True, False, 1, 1, 1),
    ("turul de mana al pieselor: patru pasi, timpul tau intreg pe ei", E1 + [1], 30, 30, 20, dict(ERA1_DONE), True, False, 1, 1, 1),
    ("Mill Collector si Mill Porter angajati: turnatoria de mana e gatuirea", E1 + [10], 30, 30, 20,
     dict(ERA1_DONE, millCollector=(1, 3), millPorter=(1, 3)), True, False, 1, 1, 1),
    ("toti oamenii pieselor, fara Merchant: Piata merge la o treime", E1 + [12, 9], 30, 30, 20,
     dict(ERA1_DONE, millCollector=(1, 2), millPorter=(1, 2), founder=(1, 1), partsHauler=(1, 1)), True, False, 6, 1, 3),
    ("patru plase ale Morii, oameni pe trepte diferite, cuptorul fara plasa de minereu", E1 + [30, 28, 25, 20], 30, 30, 20,
     dict(ERA1_DONE, millCollector=(2, 5), millPorter=(1, 3), founder=(1, 2), partsHauler=(1, 4), merchant=(1, 2)),
     True, True, 14, 1, 12),
    ("turul de mana al cuprului, langa piesele cu toti oamenii", E1 + [30, 28, 25, 20, 1], 30, 30, 20,
     dict(ERA1_DONE, **ALL_PARTS), True, True, 30, 1, 30),
    ("Ore Collector si Ore Porter angajati: cuptorul de mana e gatuirea", E1 + [30, 28, 25, 20, 10], 30, 30, 20,
     dict(ERA1_DONE, **ALL_PARTS, oreCollector=(1, 3), orePorter=(1, 3)), True, True, 30, 1, 30),
    ("Piata plina: cuprul intai, piesele din ce ramane", E1 + [60, 60, 60, 60, 40], 30, 30, 20,
     dict(ERA1_DONE, **ALL_PARTS, **ALL_COPPER), True, True, 60, 60, 3),
    ("amandoi vanzatorii plini: taverna tine lemnul, Piata tine piesele", [60, 60, 60, 60, 40, 60, 60, 60, 60, 40], 60, 3, 60,
     dict(ERA1_DONE, **ALL_PARTS, **ALL_COPPER), True, True, 60, 60, 3),
    ("Copper Hauler-ul de mana e gatuirea cuprului", E1 + [40, 40, 40, 40, 30], 30, 30, 20,
     dict(ERA1_DONE, **ALL_PARTS, oreCollector=(2, 5), orePorter=(2, 5), coppersmith=(2, 5)), True, True, 40, 60, 40),
    ("prag 25 pe tot cartierul Morii, echipaj la maxim", E1 + [25, 25, 25, 25, 25], 30, 30, 20,
     dict(ERA1_DONE, **ALL_PARTS, **ALL_COPPER), True, True, 25, 25, 25),
]


def build_era2(levels, saw, dock, forge, crews, wheel, furnace, foundry, furnace_level, market):
    s = T.State()
    for i, lv in enumerate(levels):
        s.nets.append(T.Net(T.net_base(i + 1), T.NET_LANES[i], lv, T.NET_KINDS[i]))
    s.saw_level, s.dock_level, s.forge_level, s.sack_big, s.workshop = saw, dock, forge, True, True
    s.wheel, s.furnace = wheel, furnace
    s.foundry_level, s.furnace_level, s.market_level = foundry, furnace_level, market
    for role, (count, tier) in crews.items():
        s.crews[role] = T.Crew(count, tier)
    return s


def main_era2():
    print("local GOLDEN_ERA2 = {")
    for name, levels, saw, dock, forge, crews, wheel, furnace, foundry, furnace_level, market in CASES_ERA2:
        s = build_era2(levels, saw, dock, forge, crews, wheel, furnace, foundry, furnace_level, market)
        c = T.chain(s)
        crews_lua = ", ".join(f"{r} = {{ {n}, {t} }}" for r, (n, t) in crews.items())
        print("    {")
        print(f'        name = "{name}",')
        print(f"        nets = {{ {', '.join(str(x) for x in levels)} }},")
        print(f"        saw = {saw},")
        print(f"        dock = {dock},")
        print(f"        forge = {forge},")
        print(f"        wheel = {lua(wheel)},")
        print(f"        furnace = {lua(furnace)},")
        print(f"        foundry = {foundry},")
        print(f"        furnaceLevel = {furnace_level},")
        print(f"        market = {market},")
        print(f"        crews = {{ {crews_lua} }},")
        print("        lines = {")
        for line in GOLDEN_LINES:
            f = c.lines[line]
            values = ", ".join(lua(v) for _link, v in f.rates)
            print(f"            {line} = {{ catch = {lua(f.catch)}, values = {{ {values} }}, delivered = {lua(f.delivered)},"
                  f' bottleneck = "{f.bottleneck}" }},')
        print("        },")
        print(f"        capacity = {{ {', '.join(f'{k} = {lua(c.capacity[k])}' for k in GOLDEN_SELLERS)} }},")
        print(f'        bottleneck = "{c.bottleneck}",')
        print(f"        income = {lua(T.income(s))},")
        print("    },")
    print("}")


# ---- [D67] Era 3: stari cu liniile Wire Works (bobine, curent) si Depoul, langa Moara incheiata ----
ERA2_DONE = dict(ERA1_DONE, **ALL_PARTS, **ALL_COPPER)
ALL_COILS = {"worksCollector": (2, 5), "worksPorter": (2, 5), "wiredrawer": (2, 5), "coilHauler": (2, 5), "clerk": (2, 5)}
ALL_POWER = {"batteryCollector": (2, 5), "batteryPorter": (2, 5), "electrician": (2, 5), "powerHauler": (2, 5)}
E12 = E1 + [40, 38, 36, 34, 30]  # plasele Erei 1 si ale Morii la finalul Morii

# (nume, niveluri plase 1..n, oameni, masina cu abur, Power House, nivel Wire Works, nivel Power House, nivel Depot)
CASES_ERA3 = [
    ("Moara incheiata, Wire Works inca inchis: liniile lui nu exista", E12, dict(ERA2_DONE), False, False, 1, 1, 1),
    ("masina cu abur fara plasa a unsprezecea: bobinele nu exista", E12, dict(ERA2_DONE), True, False, 1, 1, 1),
    ("turul de mana al bobinelor: patru pasi, timpul tau intreg pe ei", E12 + [1], dict(ERA2_DONE), True, False, 1, 1, 1),
    ("Works Collector si Works Porter angajati: Wire Works de mana e gatuirea", E12 + [10],
     dict(ERA2_DONE, worksCollector=(1, 3), worksPorter=(1, 3)), True, False, 1, 1, 1),
    ("toti oamenii bobinelor, fara Clerk: Depoul merge la o treime", E12 + [12, 9],
     dict(ERA2_DONE, worksCollector=(1, 2), worksPorter=(1, 2), wiredrawer=(1, 1), coilHauler=(1, 1)), True, False, 6, 1, 3),
    ("patru plase ale Wire Works, oameni pe trepte diferite, Power House fara turbina", E12 + [30, 28, 25, 20],
     dict(ERA2_DONE, worksCollector=(2, 5), worksPorter=(1, 3), wiredrawer=(1, 2), coilHauler=(1, 4), clerk=(1, 2)),
     True, True, 14, 1, 12),
    ("turul de mana al curentului, langa bobinele cu toti oamenii", E12 + [30, 28, 25, 20, 1],
     dict(ERA2_DONE, **ALL_COILS), True, True, 30, 1, 30),
    ("Battery Collector si Battery Porter angajati: Power House de mana e gatuirea", E12 + [30, 28, 25, 20, 10],
     dict(ERA2_DONE, **ALL_COILS, batteryCollector=(1, 3), batteryPorter=(1, 3)), True, True, 30, 1, 30),
    ("Depoul plin: curentul intai, bobinele din ce ramane", E12 + [60, 60, 60, 60, 40],
     dict(ERA2_DONE, **ALL_COILS, **ALL_POWER), True, True, 60, 60, 3),
    ("prag 25 pe tot cartierul Wire Works, echipaj la maxim", E12 + [25, 25, 25, 25, 25],
     dict(ERA2_DONE, **ALL_COILS, **ALL_POWER), True, True, 25, 25, 25),
]


def build_era3(levels, crews, steam, powerhouse, wireworks, powerhouse_level, depot):
    s = build_era2(levels, 30, 30, 20, crews, True, True, 40, 40, 40)
    s.steam, s.powerhouse = steam, powerhouse
    s.wireworks_level, s.powerhouse_level, s.depot_level = wireworks, powerhouse_level, depot
    return s


def main_era3():
    print("local GOLDEN_ERA3 = {")
    for name, levels, crews, steam, powerhouse, wireworks, powerhouse_level, depot in CASES_ERA3:
        s = build_era3(levels, crews, steam, powerhouse, wireworks, powerhouse_level, depot)
        c = T.chain(s)
        crews_lua = ", ".join(f"{r} = {{ {n}, {t} }}" for r, (n, t) in crews.items())
        print("    {")
        print(f'        name = "{name}",')
        print(f"        nets = {{ {', '.join(str(x) for x in levels)} }},")
        print(f"        steam = {lua(steam)},")
        print(f"        powerhouse = {lua(powerhouse)},")
        print(f"        wireworks = {wireworks},")
        print(f"        powerhouseLevel = {powerhouse_level},")
        print(f"        depot = {depot},")
        print(f"        crews = {{ {crews_lua} }},")
        print("        lines = {")
        for line in GOLDEN_LINES:
            f = c.lines[line]
            values = ", ".join(lua(v) for _link, v in f.rates)
            print(f"            {line} = {{ catch = {lua(f.catch)}, values = {{ {values} }}, delivered = {lua(f.delivered)},"
                  f' bottleneck = "{f.bottleneck}" }},')
        print("        },")
        print(f"        capacity = {{ {', '.join(f'{k} = {lua(c.capacity[k])}' for k in GOLDEN_SELLERS)} }},")
        print(f'        bottleneck = "{c.bottleneck}",')
        print(f"        income = {lua(T.income(s))},")
        print("    },")
    print("}")


# ---- [D70] Era 4, "The Dam": stari pe liniile barajului (butoaiele si cablul, piese; curentul, unirea lor; cristalul),
# pornite din Era 3 incheiata si trecute prin `dam_transform` (liniile vechi se inchid, veteranii trec pe butoaie).
# Plasele barajului au RANG (unlock_net_ranked), nu loc in lista: fiecare stare le spune pe ale ei. Pasul g al planului
# (ChainMath) le reface in Luau din campurile de aici. Oamenii de drum ai Erei 4 n-au egalitati intre ei (`walker_ties`),
# dar cladirile pot avea: Switchyard-ul cu un Switchman pe treapta 5 face 12/s, cat Cable Works-ul cu doi Cablemaker pe
# treapta 3. Starea aceea e aici, cu castigul si verigile cu castig singure (`solo`): fiecare singura da 0 [D46], iar
# ecranul numeste linia cealalta.
ERA3_DONE = dict(ERA2_DONE, **ALL_COILS, **ALL_POWER)
E123 = E12 + [40, 38, 36, 34, 30]  # plasele Erelor 1-3 la Works Bell
SIX = {"cableCollector": (1, 1), "cablePorter": (1, 1), "cablemaker": (1, 1), "cableHauler": (1, 1),
       "relayKeeper": (1, 1), "pylonRunner": (1, 1)}
VETERANS = {"damCollector": (1, 1), "damPorter": (1, 1), "switchman": (1, 1), "barrelHauler": (1, 1), "dispatcher": (1, 1)}
ALL_DAM = {r: (2, 5) for r in T.DAM_CREW}
ALL_CRYSTAL = {"crystalCollector": (2, 5), "crystalPorter": (2, 5), "crystalsmith": (2, 5), "ingotHauler": (2, 5)}
START_NETS = [("dam", 5, 3, 1), ("cable_ore", 1, 1, 1)]
THREE_CABLE = [("dam", 5, 3, 30), ("cable_ore", 1, 1, 30), ("cable_ore", 2, 1, 25), ("cable_ore", 3, 2, 20)]
WITH_CRYSTAL = THREE_CABLE + [("crystal", 5, 3, 20)]
B1 = {"switchyard": 1, "cableworks": 1, "relay": 1, "kiln": 1, "town": 1}

# (nume, plasele barajului (fel, rang, banda, nivel), oamenii Erei 4, nivelurile cladirilor, Kiln, Crystal Shed)
CASES_ERA4 = [
    ("startul barajului: veteranii pe butoaie, cablul de mana", START_NETS, dict(VETERANS), dict(B1), False, False),
    ("dupa cei sase si a doua plasa de cablu: cablul si unirea au oameni, pe treapta 1",
     [("dam", 5, 3, 1), ("cable_ore", 1, 1, 2), ("cable_ore", 2, 1, 1)], dict(VETERANS, **SIX), dict(B1), False, False),
    ("butoaiele tin unirea: cablul cu oameni pe treapta 5, butoaiele pe 1", THREE_CABLE,
     dict(VETERANS, **{r: (2, 5) for r in SIX}), dict(B1, cableworks=25, relay=25, town=25), False, False),
    ("cablul tine unirea: butoaiele asteapta (tinute de unire)", THREE_CABLE,
     dict({r: (2, 5) for r in VETERANS}, **SIX), dict(B1, switchyard=25, relay=25, town=25), False, False),
    ("egalitate intre cladiri: Switchyard si Cable Works duc la fel, fiecare singura nu aduce nimic",
     [("dam", 5, 3, 50), ("cable_ore", 1, 1, 50), ("cable_ore", 2, 1, 50), ("cable_ore", 3, 2, 50)],
     {**{r: (2, 5) for r in VETERANS}, **{r: (2, 5) for r in SIX}, "switchman": (1, 5), "cablemaker": (2, 3)},
     dict(B1, relay=25, town=25), False, False),
    ("Kiln fara Crystal Net: cristalul nu exista", THREE_CABLE, dict(ALL_DAM), dict(B1, switchyard=25, cableworks=25,
     relay=25, town=25), True, False),
    ("turul de mana al cristalului: patru pasi, timpul tau intreg pe ei", WITH_CRYSTAL, dict(ALL_DAM),
     dict(B1, switchyard=25, cableworks=25, relay=25, town=25), True, True),
    ("orasul plin: cristalul intai, curentul din ce ramane", WITH_CRYSTAL, dict(ALL_DAM, **ALL_CRYSTAL, dispatcher=(1, 3)),
     dict(B1, switchyard=40, cableworks=40, relay=40, kiln=40, town=1), True, True),
    ("toti oamenii la maxim, prag 25 pe tot barajul", WITH_CRYSTAL, dict(ALL_DAM, **ALL_CRYSTAL),
     dict(switchyard=25, cableworks=25, relay=25, kiln=25, town=25), True, True),
]


def build_era4(nets, crews, buildings, kiln, crystal_shed):
    # chiar barajul jocului (`dam_transform`): liniile vechi inchise, veteranii, turbina din zid si Cable Net 1 gratis;
    # apoi cazul isi pune nivelurile pe cele doua plase date si isi adauga restul
    s = T.dam_transform(build_era3(E123, dict(ERA3_DONE), True, True, 40, 40, 40), 0.0)
    given = s.nets[-2:]
    assert [(n.kind, n.base_lane) for n in given] == [(k, ln) for k, _r, ln, _lv in nets[:2]], "plasele date de baraj"
    for net, (_kind, _rank, _lane, level) in zip(given, nets[:2]):
        net.level = level
    for kind, rank, lane, level in nets[2:]:
        T.unlock_net_ranked(kind, rank, lane, 4)(s)
        s.nets[-1].level = level
    s.kiln, s.crystal_shed = kiln, crystal_shed
    for role, (count, tier) in crews.items():
        s.crews[role] = T.Crew(count, tier)
    for name, level in buildings.items():
        attr = T.SELLERS[name]["level"] if name in T.SELLERS else T.PROCESSORS[name]["level"]
        setattr(s, attr, level)
    return s


def main_era4():
    lines = ("wood",) + T.ERA_LINES[4]  # lemnul: o linie veche, inchisa de baraj
    print("local GOLDEN_ERA4 = {")
    for name, nets, crews, buildings, kiln, crystal_shed in CASES_ERA4:
        s = build_era4(nets, crews, buildings, kiln, crystal_shed)
        c = T.chain(s)
        crews_lua = ", ".join(f"{r} = {{ {n}, {t} }}" for r, (n, t) in crews.items())
        nets_lua = ", ".join(f'{{ kind = "{k}", rank = {r}, lane = {ln}, level = {lv} }}' for k, r, ln, lv in nets)
        print("    {")
        print(f'        name = "{name}",')
        print(f"        damNets = {{ {nets_lua} }},")
        print(f"        crews = {{ {crews_lua} }},")
        print(f"        buildings = {{ {', '.join(f'{k} = {v}' for k, v in buildings.items())} }},")
        print(f"        kiln = {lua(kiln)},")
        print(f"        crystalShed = {lua(crystal_shed)},")
        print("        lines = {")
        for line in lines:
            f = c.lines[line]
            values = ", ".join(lua(v) for _link, v in f.rates)
            print(f"            {line} = {{ catch = {lua(f.catch)}, supply = {lua(f.supply)}, values = {{ {values} }},"
                  f" delivered = {lua(f.delivered)}, bottleneck = \"{f.bottleneck}\", heldBy = \"{f.held_by}\","
                  f" byConsumer = {lua(f.by_consumer)} }},")
        print("        },")
        print(f"        capacity = {{ town = {lua(c.capacity['town'])} }},")
        print(f'        bottleneck = "{c.bottleneck}",')
        print(f'        netsLine = "{c.nets_line}",')
        # castigul unei bucati in plus pe verigile cu castig, si cele care il aduc si singure, in ordinea LINKS
        gains = ", ".join(f"{link} = {lua(c.gains[link])}" for link in T.LINKS if c.gains[link] != 0.0)
        solo = ", ".join(f'"{link}"' for link in T.LINKS if link in c.solo)
        print(f"        gains = {{ {gains} }},")
        print(f"        solo = {{ {solo} }},")
        print(f"        income = {lua(T.income(s))},")
        print("    },")
    print("}")


def main():
    if "--era2" in sys.argv:
        return main_era2()
    if "--era3" in sys.argv:
        return main_era3()
    if "--era4" in sys.argv:
        return main_era4()
    print("local GOLDEN = {")
    for name, levels, saw, dock, sack, crews, forge_owned, forge in CASES:
        s = build(levels, saw, dock, sack, crews, forge_owned, forge)
        c = T.chain(s)
        crews_lua = ", ".join(f"{r} = {{ {n}, {t} }}" for r, (n, t) in crews.items())
        print("    {")
        print(f'        name = "{name}",')
        print(f"        nets = {{ {', '.join(str(x) for x in levels)} }},")
        print(f"        saw = {saw},")
        print(f"        dock = {dock},")
        print(f"        sack = {lua(sack)},")
        print(f"        crews = {{ {crews_lua} }},")
        print(f"        forgeOwned = {lua(forge_owned)},")
        print(f"        forge = {forge},")
        fields = (
            c.wood_catch, c.scrap_catch, c.collect, c.port, c.sawing, c.haul,
            c.scrap_collect, c.scrap_port, c.forging, c.iron_haul, c.sales, c.wood, c.scrap,
        )
        print(f"        rates = {{ {', '.join(lua(x) for x in fields)} }},")
        print(f'        bottleneck = "{c.bottleneck}",')
        print(f'        woodBottleneck = "{c.wood_bottleneck}",')
        print(f'        ironBottleneck = "{c.iron_bottleneck}",')
        print(f"        income = {lua(T.income(s))},")
        print("    },")
    print("}")


if __name__ == "__main__":
    main()
