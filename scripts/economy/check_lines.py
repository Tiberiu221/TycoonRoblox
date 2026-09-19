#!/usr/bin/env python3
"""Motorul lantului chiar duce ORICATE linii, nu doar le reproduce pe cele doua ale Erei 1 [D64].

Cronologia Erei 1 si tabelul de aur dovedesc ca refactorul n-a schimbat nimic. Nu dovedesc insa ca tabelul LINES poate
primi o linie noua: cu doua linii, un motor scris de mana si unul generic dau aceleasi cifre. Aici se adauga, pe o COPIE
a simulatorului, doua linii de proba cu un al doilea vanzator, iar rezultatul se compara cu cifre socotite de mana.

Liniile de proba NU sunt economia Erei 2 (aceea se deriva in simulator, ca la Era 1). Au doar forma ei: piese si cupru,
vandute la o Piata. Cifrele sunt alese rotunde, ca socoteala de mana sa fie exacta in virgula mobila.

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
    T.LINE_ORDER = ("wood", "iron", "parts", "copper")
    T.LINES["parts"] = {
        "netKind": "parts", "openFlag": "foundry_owned", "seller": "market",
        "steps": (("partsCollector", "partsCollect", "walk"), ("partsPorter", "partsPort", "walk"),
                  ("founder", "foundry", "processor"), ("partsHauler", "partsHaul", "walk")),
    }
    T.LINES["copper"] = {
        "netKind": "copper", "openFlag": "smithy_owned", "seller": "market",
        "steps": (("copperCollector", "copperCollect", "walk"), ("copperPorter", "copperPort", "walk"),
                  ("coppersmith", "smithy", "processor"), ("copperHauler", "copperHaul", "walk")),
    }
    T.PROCESSORS["foundry"] = {"base": "FOUNDRY_BASE_RATE", "level": "foundry_level"}
    T.PROCESSORS["smithy"] = {"base": "SMITHY_BASE_RATE", "level": "smithy_level"}
    T.SELLERS["market"] = {
        "role": "merchant", "base": "MARKET_BASE_RATE", "level": "market_level", "priority": ("copper", "parts"),
    }
    T.FOUNDRY_BASE_RATE = 2.0
    T.SMITHY_BASE_RATE = 2.0
    T.MARKET_BASE_RATE = 5.0
    for kind in ("foundry", "smithy", "market"):
        T.LEVEL_INC_BY_KIND[kind] = 0.06
    for role in ("partsCollector", "partsPorter", "partsHauler", "copperCollector", "copperPorter", "copperHauler"):
        T.ROLE_BASE[role] = 3.0
    T.AVG["parts"] = 8.0
    T.AVG["copper"] = 12.0
    T.ROLES = T.ROLES + (
        "partsCollector", "partsPorter", "founder", "partsHauler",
        "copperCollector", "copperPorter", "coppersmith", "copperHauler", "merchant",
    )
    T.LINE_STEPS, T.LINE_LINKS, T.LINE_OF_ROLE, T.LINK_OF, T.LINKS = T.derive_tables(
        T.LINE_ORDER, T.LINES, T.SELLERS, T.ROLES
    )


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
    s.foundry_owned = parts_net is not None
    s.smithy_owned = copper_net is not None
    s.foundry_level = s.smithy_level = s.market_level = 1
    if parts_net is not None:
        s.nets.append(T.Net(parts_net, 1, 1, "parts"))
    if copper_net is not None:
        s.nets.append(T.Net(copper_net, 1, 1, "copper"))
    return s


def staff(s, T, roles, count, tier):
    for role in roles:
        s.crews[role] = T.Crew(count, tier)


PARTS_ROLES = ("partsCollector", "partsPorter", "founder", "partsHauler")
COPPER_ROLES = ("copperCollector", "copperPorter", "coppersmith", "copperHauler")


def problems():
    bad = []

    def expect(what, got, want):
        if isinstance(want, float):
            ok = abs(got - want) < 1e-9
        else:
            ok = got == want
        if not ok:
            bad.append(f"check_lines: {what}: a iesit {got!r}, socotit de mana {want!r}")

    base = load()
    before = base.chain(era1_state(base))
    before_income = base.income(era1_state(base))

    T = load()
    add_probe_lines(T)

    # 0. Liniile noi, inchise: Era 1 nu simte nimic
    s = with_probe_fields(era1_state(T), None, None, T)
    c = T.chain(s)
    expect("liniile de proba inchise nu livreaza", (c.lines["parts"].delivered, c.lines["copper"].delivered), (0.0, 0.0))
    expect("liniile de proba inchise n-au veriga slaba", (c.lines["parts"].bottleneck, c.lines["copper"].bottleneck), ("", ""))
    expect("venitul Erei 1 cu liniile de proba inchise", T.income(s), before_income)
    expect("veriga care tine venitul, cu liniile de proba inchise", c.bottleneck, before.bottleneck)

    # 1. A treia linie, de mana, la vanzatorul ei fara om. Timpul tau intreg pe cei patru pasi ai ei: 3.6 x 1.5
    #    (traista mare) / 4 = 1.35 pe pas; turnatoria de mana 2.0 / 4 = 0.5; plasa 1.0 -> linia duce 0.5, tinuta de
    #    turnatorie. Piata fara negustor: 5.0 x 0.35 = 1.75, deci nu ea e marginea.
    s = with_probe_fields(era1_state(T), 1.0, None, T)
    c = T.chain(s)
    parts = c.lines["parts"]
    expect("piese de mana: pasii de drum", dict(parts.rates)["partsCollect"], 1.35)
    expect("piese de mana: turnatoria", dict(parts.rates)["foundry"], 0.5)
    expect("piese de mana: livrat", parts.delivered, 0.5)
    expect("piese de mana: veriga slaba", parts.bottleneck, "foundry")
    expect("piese de mana: Piata", c.capacity["market"], 1.75)
    expect("piese de mana: venitul creste cu 0.5 x 8", T.income(s) - before_income, 4.0)
    expect("piese de mana: lemnul neatins", c.lines["wood"].delivered, before.wood)
    expect("piese de mana: fierul neatins", c.lines["iron"].delivered, before.scrap)
    expect("piese de mana: taverna neatinsa", c.capacity["dock"], before.sales)
    # o bucata de piese (8.0) bate una de fier (3.55): veriga care tine venitul e acum turnatoria
    expect("piese de mana: veriga care tine venitul", c.bottleneck, "foundry")

    # 2. Aceeasi linie cu oameni (cate doi, treapta 5): drumurile 3 x 5 x 2 = 30, turnatoria 2 x 5 x 2 = 20, negustorul
    #    5 x 5 x 2 = 50 -> plasa (1.0) e marginea.
    staff(s, T, PARTS_ROLES + ("merchant",), 2, 5)
    c = T.chain(s)
    expect("piese cu oameni: drum", dict(c.lines["parts"].rates)["partsHaul"], 30.0)
    expect("piese cu oameni: turnatoria", dict(c.lines["parts"].rates)["foundry"], 20.0)
    expect("piese cu oameni: Piata", c.capacity["market"], 50.0)
    expect("piese cu oameni: livrat", c.lines["parts"].delivered, 1.0)
    expect("piese cu oameni: veriga slaba", c.lines["parts"].bottleneck, "nets")
    expect("piese cu oameni: venitul creste cu 1 x 8", T.income(s) - before_income, 8.0)

    # 3. Doua linii la ACELASI al doilea vanzator, el fiind marginea. Piata cu un negustor de treapta 1 duce 5.0.
    #    Cuprul (12 pe bucata) e primul la rand: plasa lui da 3.0 -> livreaza 3.0, raman 2.0. Piesele ar putea 4.0, dar
    #    primesc 2.0: Piata le tine. O bucata de cupru in plus ar lua locul uneia de piese: 12 - 8 = 4. Piata in plus
    #    ar vinde piese: 8. Deci veriga care tine venitul e Piata (8 > 4 > 3.55 > 1.65).
    s = with_probe_fields(era1_state(T), 4.0, 3.0, T)
    staff(s, T, PARTS_ROLES + COPPER_ROLES, 2, 5)
    staff(s, T, ("merchant",), 1, 1)
    c = T.chain(s)
    expect("doua linii la Piata: cuprul livrat", c.lines["copper"].delivered, 3.0)
    expect("doua linii la Piata: piesele livrate", c.lines["parts"].delivered, 2.0)
    expect("doua linii la Piata: piesele tinute de Piata", c.lines["parts"].bottleneck, "market")
    expect("doua linii la Piata: cuprul tinut de plasa lui", c.lines["copper"].bottleneck, "nets")
    expect("doua linii la Piata: veriga care tine venitul", c.bottleneck, "market")
    expect("doua linii la Piata: venitul creste cu 3 x 12 + 2 x 8", T.income(s) - before_income, 52.0)
    expect("doua linii la Piata: taverna neatinsa", (c.lines["wood"].delivered, c.lines["iron"].delivered), (before.wood, before.scrap))

    # 4. Piata largita (negustor de treapta 2: 10.0): amandoua liniile curg cat prind, nimeni nu mai e tinut de ea.
    staff(s, T, ("merchant",), 1, 2)
    c = T.chain(s)
    expect("Piata largita: piesele livrate", c.lines["parts"].delivered, 4.0)
    expect("Piata largita: piesele tinute de plasa lor", c.lines["parts"].bottleneck, "nets")
    expect("Piata largita: venitul creste cu 3 x 12 + 4 x 8", T.income(s) - before_income, 68.0)
    return bad


if __name__ == "__main__":
    found = problems()
    for line in found:
        print(line)
    if found:
        sys.exit(1)
    print("check_lines: motorul duce liniile de proba (a treia si a patra linie, al doilea vanzator) cum iese din socoteala de mana")
