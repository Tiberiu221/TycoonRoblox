#!/usr/bin/env python3
"""[D67, propunere] ERA 3, „THE WIRE WORKS", derivata inainte de a o construi: schema Morii, oglindita inca o data.

Unealta de „ce-ar fi daca", ca sim_era2.py la D65: NU e in poarta si nu schimba nimic din joc. Incarca o copie proaspata
a simulatorului adevarat, ii adauga IN MEMORIE cartierul al treilea si joaca Era 1 -> Era 2 -> Era 3.

Schema e regula owner-ului (D64: incepi cu marfa de la finalul erei dinainte, spre final apare una noua cu plasa,
atelierul si oamenii ei, iar era isi vinde marfa la cladirea ei) si roadmap-ul lui (cupru -> sarma si bobine, apoi
curentul electric). Deblocare cu deblocare, in oglinda cu Moara:
    Water Wheel -> Sixth Net (scrap) -> cei cinci -> plasele 7-9     ->  Steam Engine -> Eleventh Net (minereu de cupru)
                                                                          -> cei cinci -> plasele 12-14
    Copper Furnace -> Tenth Net (minereu) -> Ore Shed -> cei patru     ->  Power House -> First Turbine (curent)
                                                                          -> Battery Shed -> cei patru
    Mill Bell                                                          ->  Works Bell
Cadrul e cel din D66: tot ce se masoara in monede in cartierul nou (valoarea bucatii, nivelurile, treptele) e de M ori
mai mare decat in Moara, deci de 3000 x M ori decat in sat; bucatile pe secunda raman ca in Era 1.

Rulare: python3 scripts/economy/sim_era3.py [--robust] [--table] [M=3000] [START=7.5]
  M      de cate ori valoreaza marfa Erei 3 mai mult decat a Morii
  START  unde porneste scara de asteptare a erei (Era 2: 7.5, vezi D66)
"""
import contextlib
import importlib.util
import io
import os
import sys

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")
DEFAULTS = {"M": 3000.0, "START": 7.5}

# Oamenii Erei 3, in aceeasi ordine ca ai Morii (ERA2_ROLES): cei patru ai bobinelor, vanzatorul Depoului, cei patru ai
# curentului. Fiecare isi ia baza si rafala de la perechea lui din Moara.
ERA3_ROLES = (
    "worksCollector", "worksPorter", "wiredrawer", "coilHauler", "clerk",
    "batteryCollector", "batteryPorter", "electrician", "powerHauler",
)
ROLE_NAMES3 = {
    "worksCollector": "Works Collector", "worksPorter": "Works Porter", "wiredrawer": "Wiredrawer",
    "coilHauler": "Coil Hauler", "clerk": "Clerk", "batteryCollector": "Battery Collector",
    "batteryPorter": "Battery Porter", "electrician": "Electrician", "powerHauler": "Power Hauler",
}
# veriga Morii -> veriga Erei 3 (pentru scutiri si rapoarte)
LINKS3 = {
    "millCollect": "worksCollect", "millPort": "worksPort", "foundry": "wireworks", "partsHaul": "coilHaul",
    "market": "depot", "oreCollect": "batteryCollect", "orePort": "batteryPort", "furnace": "powerhouse",
    "copperHaul": "powerHaul",
}


def load():
    spec = importlib.util.spec_from_file_location("sim_era3_whatif", SIM)
    sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sim)
    return sim


def add_era3(T, knobs):
    """Cartierul al treilea, pe copia `T`. Tot ce e aici e oglinda randului Morii de langa el."""
    m3 = T.ERA2_MULT * knobs["M"]
    T.ERA3_MULT = m3
    # marfa: plasele prind minereu de cupru, Wire Works-ul il trage in bobine (bucata valoreaza cat minereul din care
    # iese, ca piesele din scrap); turbina umple baterii, Power House-ul le incarca. Bucata turbinei valoreaza cat media
    # plasei de minereu a Morii (3.55 = 95% minereu + 5% gasiri): o turbina nu prinde gasiri din rau.
    T.GOODS.update({"works_ore": 1.0 * m3, "coils": 1.0 * m3, "named3": 14.0 * m3, "charge": 3.55 * m3, "power": 3.55 * m3})
    T.CATCH["works"] = (("works_ore", 0.95), ("named3", 0.05))
    T.CATCH["turbine"] = (("charge", 1.0),)
    T.AVG.update({kind: sum(share * T.GOODS[good] for good, share in T.CATCH[kind]) for kind in ("works", "turbine")})
    T.NET_LANES = T.NET_LANES + (1, 1, 2, 2, 3)
    T.NET_KINDS = T.NET_KINDS + ("works", "works", "works", "works", "turbine")

    # cladirile: Wire Works cat turnatoria, Power House cat cuptorul de cupru, Depoul cat Piata
    T.WIREWORKS_BASE_RATE, T.WIREWORKS_UPGRADE_BASE = T.FOUNDRY_BASE_RATE, 7.0 * m3
    T.POWERHOUSE_BASE_RATE, T.POWERHOUSE_UPGRADE_BASE = T.FURNACE_BASE_RATE, 60.0 * m3
    T.DEPOT_BASE_RATE, T.DEPOT_UPGRADE_BASE = T.MARKET_BASE_RATE, 9.0 * m3
    for kind in ("wireworks", "powerhouse", "depot"):
        T.LEVEL_INC_BY_KIND[kind] = 0.06
    T.State.steam = False
    T.State.powerhouse = False
    T.State.battery_shed = False
    T.State.wireworks_level = 1
    T.State.powerhouse_level = 1
    T.State.depot_level = 1

    # oamenii
    mirror = dict(zip(ERA3_ROLES, T.ERA2_ROLES))
    for role in ERA3_ROLES:
        if mirror[role] in T.ROLE_BASE:
            T.ROLE_BASE[role] = T.ROLE_BASE[mirror[role]]
        T.ROLE_COST_MULT[role] = m3
    T.ROLE_NAMES.update(ROLE_NAMES3)
    T.ERA3_ROLES = ERA3_ROLES
    T.ROLES = T.ROLES + ERA3_ROLES

    # liniile, ca date [D64]
    T.LINE_ORDER = T.LINE_ORDER + ("coils", "power")
    T.ERA_LINES[3] = ("coils", "power")
    T.LINES["coils"] = {
        "netKind": "works", "openFlag": "steam", "seller": "depot",
        "steps": (("worksCollector", "worksCollect", "walk"), ("worksPorter", "worksPort", "walk"),
                  ("wiredrawer", "wireworks", "processor"), ("coilHauler", "coilHaul", "walk")),
    }
    T.LINES["power"] = {
        "netKind": "turbine", "openFlag": "powerhouse", "seller": "depot",
        "steps": (("batteryCollector", "batteryCollect", "walk"), ("batteryPorter", "batteryPort", "walk"),
                  ("electrician", "powerhouse", "processor"), ("powerHauler", "powerHaul", "walk")),
    }
    T.PROCESSORS["wireworks"] = {"base": "WIREWORKS_BASE_RATE", "level": "wireworks_level"}
    T.PROCESSORS["powerhouse"] = {"base": "POWERHOUSE_BASE_RATE", "level": "powerhouse_level"}
    T.SELLERS["depot"] = {"role": "clerk", "base": "DEPOT_BASE_RATE", "level": "depot_level", "priority": ("power", "coils")}
    T.LINE_STEPS, T.LINE_LINKS, T.LINE_OF_ROLE, T.LINK_OF, T.LINKS = T.derive_tables(
        T.LINE_ORDER, T.LINES, T.SELLERS, T.ROLES
    )
    T.ERA_LINKS = {
        era: ("nets",) + tuple(link for line in lines for link in T.LINE_LINKS[line])
        + tuple(seller for seller in T.SELLERS if any(T.LINES[line]["seller"] == seller for line in lines))
        for era, lines in T.ERA_LINES.items()
    }
    T.LATE_LINE[3] = "power"
    T.BOTTLENECK_EXEMPT |= {LINKS3[link] for link in T.BOTTLENECK_EXEMPT if link in LINKS3}
    T.BUILDINGS["wireworks"] = {"label": "Wire Works", "cost": "WIREWORKS_UPGRADE_BASE", "level": "wireworks_level", "owned": "steam"}
    T.BUILDINGS["depot"] = {"label": "Depot", "cost": "DEPOT_UPGRADE_BASE", "level": "depot_level", "owned": "steam"}
    T.BUILDINGS["powerhouse"] = {"label": "Power House", "cost": "POWERHOUSE_UPGRADE_BASE", "level": "powerhouse_level", "owned": "powerhouse"}

    n = T.NETS_PER_ERA

    def net_era_mult(k):
        return 1.0 if k <= n else (T.ERA2_MULT if k <= 2 * n else T.ERA3_MULT)

    T.net_era_mult = net_era_mult

    def era3_nets(s):
        return len(s.nets) - 2 * n

    people, hire, flag = T.people, T.hire, T.set_flag
    unlocks = [
        ("steam", "Steam Engine", "V", lambda s: not s.steam, flag("steam")),
        ("net11", "Eleventh Net", "C", lambda s: s.steam and era3_nets(s) == 0, T.unlock_net(11)),
        ("worksCollector", "Works Collector", "A",
         lambda s: era3_nets(s) >= 1 and people(s, "worksCollector") == 0, hire("worksCollector")),
        ("worksPorter", "Works Porter", "A",
         lambda s: people(s, "worksCollector") >= 1 and people(s, "worksPorter") == 0, hire("worksPorter")),
        ("wiredrawer", "Wiredrawer", "A",
         lambda s: people(s, "worksPorter") >= 1 and people(s, "wiredrawer") == 0, hire("wiredrawer")),
        ("coilHauler", "Coil Hauler", "A",
         lambda s: people(s, "wiredrawer") >= 1 and people(s, "coilHauler") == 0, hire("coilHauler")),
        ("clerk", "Clerk", "A", lambda s: people(s, "coilHauler") >= 1 and people(s, "clerk") == 0, hire("clerk")),
        ("net12", "Twelfth Net", "C",
         lambda s: era3_nets(s) == 1 and T.prev_net_ready(s) and people(s, "clerk") >= 1, T.unlock_net(12)),
        ("net13", "Thirteenth Net", "C", lambda s: era3_nets(s) == 2 and T.prev_net_ready(s), T.unlock_net(13)),
        ("net14", "Fourteenth Net", "C", lambda s: era3_nets(s) == 3 and T.prev_net_ready(s), T.unlock_net(14)),
        ("powerhouse", "Power House", "V", lambda s: era3_nets(s) >= 4 and not s.powerhouse, flag("powerhouse")),
        ("net15", "First Turbine", "C",
         lambda s: era3_nets(s) == 4 and T.prev_net_ready(s) and s.powerhouse, T.unlock_net(15)),
        ("batteryShed", "Battery Shed", "V", lambda s: era3_nets(s) == 5 and not s.battery_shed, flag("battery_shed")),
        ("batteryCollector", "Battery Collector", "A",
         lambda s: s.battery_shed and people(s, "batteryCollector") == 0, hire("batteryCollector")),
        ("batteryPorter", "Battery Porter", "A",
         lambda s: people(s, "batteryCollector") >= 1 and people(s, "batteryPorter") == 0, hire("batteryPorter")),
        ("electrician", "Electrician", "A",
         lambda s: people(s, "batteryPorter") >= 1 and people(s, "electrician") == 0, hire("electrician")),
        ("powerHauler", "Power Hauler", "A",
         lambda s: people(s, "electrician") >= 1 and people(s, "powerHauler") == 0, hire("powerHauler")),
    ]
    for role in ERA3_ROLES:
        unlocks.append((
            f"{role}2", f"Second {T.ROLE_NAMES[role]}", "A",
            (lambda s, r=role: people(s, r) == 1 and s.crews[r].tier >= T.SECOND_AT_TIER), hire(role),
        ))
    # al doilea om al erelor dinainte, ramas necumparat, se poate lua si acum, la pretul lui de atunci (`seed_prices`)
    older_seconds = {f"{r}2" for r in T.ERA1_ROLES + T.ERA2_ROLES}
    unlocks += [u for u in T.ERA2_UNLOCKS if u[0] in older_seconds]
    unlocks.append((
        "bell3", "Works Bell", "D",
        lambda s: era3_nets(s) == 5 and all(people(s, r) >= 1 for r in ERA3_ROLES) and s.powerhouse and s.battery_shed,
        T.unlock_bell,
    ))
    own = {u[0] for u in unlocks} - older_seconds

    T.UNLOCK_STAGE.update({
        "steam": "wireworks", "net11": "nets", "net12": "nets", "net13": "nets", "net14": "nets", "net15": "nets",
        "powerhouse": "powerhouse", "batteryShed": "batteryCollect", "bell3": "depot",
        **{role: T.LINK_OF[role] for role in ERA3_ROLES},
        **{f"{role}2": T.LINK_OF[role] for role in ERA3_ROLES},
    })
    T.BURST_WAIT.update({role: T.BURST_WAIT[mirror[role]] for role in ERA3_ROLES if mirror[role] in T.BURST_WAIT})
    T.BURST_WAIT["batteryShed"] = T.BURST_WAIT["oreShed"]
    T.LADDER_EXEMPT = {f"{r}2" for r in T.ROLES} | set(T.BURST_WAIT)

    start = knobs["START"]
    T.ERA3_UNLOCKS = unlocks
    T.ERA3 = {
        "name": "Era 3",
        "unlocks": unlocks,
        "chapter_hires": ("worksCollector", "worksPorter", "wiredrawer", "coilHauler", "clerk"),
        "quest_unlocks": (
            ("steam", lambda s: True),
            ("net11", lambda s: True),
            ("powerhouse", lambda s: era3_nets(s) >= 4 and s.nets[2 * n + 3].level >= T.PREV_NET_LEVEL),
            ("net15", lambda s: True),
            ("batteryShed", lambda s: True),
            ("batteryCollector", lambda s: True),
            ("batteryPorter", lambda s: True),
            ("electrician", lambda s: True),
            ("powerHauler", lambda s: True),
        ),
        "bell": "bell3",
        "first_net": 2 * n,
        "net_count": n,
        "step": lambda bought: len((bought & own) - T.LADDER_EXEMPT),
        "wait": lambda k: min(420.0, 20.0 * 1.17 ** (k + start)),
        "free_first": False,  # masina cu abur costa monede: poarta erei, ca roata de apa
        "free_units": ("net11",),  # prima plasa a erei e gratis, ca a sasea [D66]
    }
    return older_seconds


def play(T, knobs):
    """Era 1 si Era 2 exact ca in poarta, apoi Era 3 din starea de la finalul Morii."""
    older_seconds = add_era3(T, knobs)
    with contextlib.redirect_stdout(io.StringIO()):
        s1, _rows1, prices1, *_ = T.run()
        s2, rows2, prices2, _idle2, final2, *_ = T.run_era2(T.clone(s1), prices1)
    return s1, s2, rows2, {**prices1, **prices2}, final2, older_seconds


def run_era3(T, s2, prices12, older_seconds):
    era = dict(T.ERA3)
    era["seed_prices"] = {uid: p for uid, p in prices12.items() if uid in older_seconds and uid not in s2.bought}
    with contextlib.redirect_stdout(io.StringIO()):
        return T.run(era=era, start=T.clone(s2), max_seconds=200000)


def check_era3(T, rows, idle, shares, late_time, started_at, ended_at, income2, min_share=None):
    """Portile Morii (check_run_era2), pe Era 3, plus absenta de o noapte de la sfarsitul Morii [D66]."""
    min_share = T.MIN_BOTTLENECK_SHARE if min_share is None else min_share
    problems = []
    real = (ended_at - started_at) * T.REAL
    if not T.ERA2_MIN_REAL <= real <= T.ERA2_MAX_REAL:
        problems.append(f"Era 3 dureaza {T.fmt(real)} reali (intre {T.fmt(T.ERA2_MIN_REAL)} si {T.fmt(T.ERA2_MAX_REAL)})")
    five_min = [r for r in rows if (r[3] - started_at) * T.REAL <= 300]
    if len(five_min) < T.ERA2_MIN_FIRST_FIVE:
        problems.append(f"Era 3: primele 5 minute reale au doar {len(five_min)} cumparaturi (minim {T.ERA2_MIN_FIRST_FIVE})")
    hired = [(r[3] - started_at) * T.REAL for r in rows if r[0] == "unlock:Clerk"]
    if not hired or hired[0] > T.ERA2_CREW_BURST_REAL:
        problems.append(f"Era 3: cei cinci oameni sunt angajati abia la {T.fmt(hired[0]) if hired else 'niciodata'} real")
    if idle > 180:
        problems.append(f"Era 3: {T.fmt(idle)} fara nimic de apasat (maxim 3 min)")
    for link in T.ERA_LINKS[3]:
        if link in T.BOTTLENECK_EXEMPT or link == "nets":
            continue
        part = T.link_share(link, shares, late_time, era=3)
        if part < min_share:
            problems.append(f"Era 3: veriga `{link}` e gatuirea doar {part * 100:.1f}% din timp -- e decor")
    _b, _n, _nu, last, share = T.windfall(income2, rows, started_at, ended_at, T.OFFLINE_HOURS)
    if share > T.WINDFALL_MAX_SHARE:
        problems.append(f"o noapte de absenta la sfarsitul Morii sare {share * 100:.0f}% din Era 3 (pana la {last})")
    return problems


def report(T, s2, s3, rows, prices, idle, final3, shares, income2):
    started = s2.t
    late = s3.line_time["power"]
    unlocks = [r for r in rows if r[1] == "unlock"]
    five_min = [r for r in rows if (r[3] - started) * T.REAL <= 300]
    c = T.chain(s3)
    money = {line: c.lines[line].delivered * T.line_avg(line) for line in T.LINE_ORDER}
    total = sum(money.values())
    old = sum(money[line] for line in T.ERA_LINES[1] + T.ERA_LINES[2])
    print(f"Era 3: {len(rows)} cumparaturi ({len(unlocks)} deblocari, {len(rows) - len(unlocks)} niveluri si trepte)")
    print(f"  terminata in {T.fmt(s3.t - started)} lacom  ->  {T.fmt((s3.t - started) * T.REAL)} real, de la clopotul Morii")
    print(f"  venit: {T.big(income2)}/s -> {T.big(final3)}/s  (x{final3 / income2:.1f})")
    print(f"  primele 5 minute reale: {len(five_min)} cumparaturi (minim {T.ERA2_MIN_FIRST_FIVE})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {T.fmt(idle)} (lacom)")
    print(
        "  gatuirea, ca parte din timp: "
        + " | ".join(f"{link} {T.link_share(link, shares, late, era=3) * 100:.1f}%" for link in T.ERA_LINKS[3])
        + f"  (curentul: din {T.fmt(late)} cu turbina)"
    )
    print(
        f"  la final: satul si Moara {old / total * 100:.1f}% din bani, bobinele {money['coils'] / total * 100:.1f}%,"
        f" curentul {money['power'] / total * 100:.1f}%"
    )
    print("  oamenii la final: " + ", ".join(
        f"{T.ROLE_NAMES[r]} {s3.crews[r].count}x treapta {s3.crews[r].tier}" for r in ERA3_ROLES))
    print("\npreturile deblocarilor Erei 3, in ordinea cumpararii (timpul: de la clopotul Morii):")
    for label, kind, price, t, inc, _bn in rows:
        if kind == "unlock":
            print(f"  {label[7:]:<24} {T.big(price):>9}   la {T.fmt(t - started):>7} lacom / "
                  f"{T.fmt((t - started) * T.REAL):>7} real   venit {T.big(inc):>8}/s")
    never = [uid for uid, *_ in T.ERA3_UNLOCKS if uid not in s3.bought]
    if never:
        print("  necumparate in Era 3: " + ", ".join(f"{uid} {T.big(prices[uid])}" for uid in never))
    print(f"\n[D66] absenta de la sfarsitul Morii ({T.big(income2)}/s), cat din Era 3 plateste:")
    for label, hours, mult in (
        (f"o noapte ({T.OFFLINE_HOURS:g} h)", T.OFFLINE_HOURS, 1.0),
        (f"Long Nights ({T.OFFLINE_HOURS_LONG:g} h)", T.OFFLINE_HOURS_LONG, 1.0),
        ("Long Nights si 2x Flow", T.OFFLINE_HOURS_LONG, 2.0),
    ):
        budget, n, nu, last, share = T.windfall(income2, rows, started, s3.t, hours, mult)
        print(f"  {label:26s} {T.big(budget):>8}: {n:3d} din {len(rows)} cumparaturi, {nu:2d} din {len(unlocks)} "
              f"deblocari (pana la {last}), {share * 100:4.1f}% din timpul erei")


ROBUST_KNOBS3 = (
    "WIREWORKS_BASE_RATE", "POWERHOUSE_BASE_RATE", "DEPOT_BASE_RATE", "ROLE_BASE.worksCollector",
    "ROLE_BASE.worksPorter", "ROLE_BASE.coilHauler", "ROLE_BASE.batteryCollector", "ROLE_BASE.batteryPorter",
    "ROLE_BASE.powerHauler",
)


def robust(T, s2, prices12, older_seconds, income2):
    failures = []
    print("\n--robust, Era 3: fiecare constanta a cartierului nou x0.85 si x1.15 (Era 1 si Moara neschimbate)")
    for knob in ROBUST_KNOBS3:
        for factor in (0.85, 1.15):
            role = knob.split(".")[1] if knob.startswith("ROLE_BASE.") else None
            original = T.ROLE_BASE[role] if role else getattr(T, knob)
            if role:
                T.ROLE_BASE[role] = original * factor
            else:
                setattr(T, knob, original * factor)
            T.VIOLATIONS.clear()
            tag = f"{knob} x{factor}"
            try:
                s3, rows, _p, idle, _f, shares, _ = run_era3(T, s2, prices12, older_seconds)
                problems = list(T.VIOLATIONS) + T.check_hire_order() + check_era3(
                    T, rows, idle, shares, s3.line_time["power"], s2.t, s3.t, income2, T.MIN_BOTTLENECK_SHARE / 2)
                print(f"  {tag:<30} {T.fmt((s3.t - s2.t) * T.REAL):>7} real, {len(rows)} cumparaturi, pauza {T.fmt(idle)}")
            except SystemExit as e:
                problems = [str(e)]
                print(f"  {tag:<30} {e}")
            finally:
                if role:
                    T.ROLE_BASE[role] = original
                else:
                    setattr(T, knob, original)
            failures += [f"{tag}: {p}" for p in problems]
    T.VIOLATIONS.clear()
    return failures


def main():
    knobs = dict(DEFAULTS)
    for arg in sys.argv[1:]:
        if "=" in arg:
            k, v = arg.split("=", 1)
            knobs[k.upper()] = float(v)
    T = load()
    s1, s2, rows2, prices12, income2, older_seconds = play(T, knobs)
    era2_violations = list(T.VIOLATIONS)
    T.VIOLATIONS.clear()
    s3, rows3, prices3, idle3, final3, shares3, _ = run_era3(T, s2, prices12, older_seconds)
    print(f"Moara, ca in poarta: {len(rows2)} cumparaturi, {T.fmt((s2.t - s1.t) * T.REAL)} real, venit final "
          f"{income2:.2f}/s  (cadrul Erei 3: M = {knobs['M']:g}, START = {knobs['START']:g})\n")
    problems = era2_violations + list(T.VIOLATIONS) + T.check_hire_order()
    problems += check_era3(T, rows3, idle3, shares3, s3.line_time["power"], s2.t, s3.t, income2)
    if T.line_avg("power") < T.line_avg("coils"):
        problems.append("Depoul vinde intai curentul, dar bucata lui valoreaza sub a bobinelor")
    if "--table" in sys.argv:
        for i, (label, kind, price, t, inc, bn) in enumerate(rows3, 1):
            print(f"{i:>3} {label:<32} {kind:>9} {T.big(price):>8} {T.fmt((t - s2.t) * T.REAL):>8} {T.big(inc):>9} {bn:>14}")
        print()
    report(T, s2, s3, rows3, prices3, idle3, final3, shares3, income2)
    if "--robust" in sys.argv:
        problems += robust(T, s2, prices12, older_seconds, income2)
    if problems:
        print("\nEROARE -- Era 3 nu trece portile Morii:")
        for p in problems:
            print("  " + p)
        sys.exit(1)
    print("\nEra 3 trece portile Morii (durata, primele 5 minute, rafala celor cinci, pauza, verigile, o noapte de absenta).")


if __name__ == "__main__":
    main()
