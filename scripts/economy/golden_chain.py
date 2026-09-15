#!/usr/bin/env python3
"""Tipareste valorile de aur pentru tests/ChainMath.test.luau, direct din simulator [D55, D56].

Pana la D55 tabelul GOLDEN din test era copiat de mana din repr-urile simulatorului. Cu doua linii si mai
multe campuri, copiatul de mana devenea locul in care se strecoara o greseala; acum se regenereaza:

    python3 scripts/economy/golden_chain.py > /tmp/golden.luau

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
     {r: (2, 5) for r in T.ROLES}, False, 1),
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


def lua(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    return repr(float(v))


def main():
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
