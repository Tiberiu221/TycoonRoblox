#!/usr/bin/env python3
"""Era 2, "The Mill", derivata in simulator [D64]. PROPUNERE: nu e in poarta, nu atinge jocul si nu schimba Era 1.

REGULA OWNER-ULUI (D64): incepi cu marfa aparuta la finalul erei dinainte (scrap), o cresti, iar spre final apare una
noua (minereu de cupru) cu plasa, atelierul si oamenii ei; era isi vinde marfa la cladirea ei (Piata). Si, din noaptea de
2026-09-19: "poti incepe sa copiezi schemele si pentru era 2". Deci Era 2 e SCHEMA Erei 1, care a fost reglata si jucata:

    Era 1                                   Era 2
    plase de lemn (4)  -> scanduri          plase de scrap ale Morii (4) -> piese de masini, la turnatorie
    Collector, Porter, Sawyer, Hauler       Mill Collector, Mill Porter, Founder, Parts Hauler
    taverna + Innkeeper                     Piata + Merchant
    Forge -> Fifth Net (scrap) -> fier      Copper Furnace -> Tenth Net (minereu) -> cupru
    Scrap Shed + cei patru ai fierului      Ore Shed + cei patru ai cuprului
    Landing Bell                            Mill Bell
    (+ reperul erei, la inceput: Roata de apa, care invarte turnatoria)

CADRUL EREI e un singur numar, M: de cate ori valoreaza marfa erei mai mult decat cea a erei dinainte. TOT ce se masoara
in monede in cartierul nou se inmulteste cu M (valoarea bucatii, costul nivelurilor, costul treptelor), iar tot ce se
masoara in bucati pe secunda ramane ca in Era 1 (plasele, oamenii, cladirile). Asa cartierul nou repeta o curba deja
reglata, doar cu alte cifre pe ea, iar preturile deblocarilor ies, ca la Era 1, din venitul de atunci si scara de asteptare.

Ce se regleaza aici: M, scara de asteptare a erei (de unde porneste si unde se opreste) si cati oameni incap pe o meserie.
Ce se masoara: cat dureaza era, cea mai lunga pauza fara nimic de apasat, cat din timp tine fiecare veriga venitul, cat
mai conteaza cartierul vechi la final si daca vreo cumparatura scade venitul.

    python3 scripts/economy/sim_era2.py [--table] [--robust] [M=40] [A=20] [G=1.17] [START=5] [CAP=420] [PEOPLE=2]
                                        [EAGER=0] [PATIENCE=60]

CE AM AFLAT LA PRIMA DERIVARE (2026-09-19):
  * Schema oglindita da singura ~57 de minute reale (tinta owner-ului: cam o ora), fara sa reglez scara: aceeasi scara
    de asteptare ca la Era 1, repornita. Nicio cumparatura nu scade venitul. Venitul creste de ~45 de ori.
  * M: durata e STABILA pentru M de la 30 la 60 (55-57 de minute, ~398 de cumparaturi), dar sare la ~1h14m pentru
    M <= 28: acolo jucatorul simulat amana a saptea plasa 25 de minute, fiindca nivelurile ieftine au raport castig/pret
    mai bun. De aceea implicit e M = 40, in mijlocul zonei stabile, nu 30, care sta pe margine.
  * MODELUL JUCATORULUI conteaza mai mult decat M. Cel de aici e acelasi care da 33m36s la Era 1: ia oamenii
    capitolului la rand, urmeaza quest-urile, iar in rest cumpara dupa raportul castig/pret. Un om care alearga dupa
    deblocari si lasa nivelurile (EAGER=1: strange pentru o plasa cand e la cel mult PATIENCE secunde de venit de ea)
    termina era in ~23 de minute, cu venit mai mic. Adevarul e intre ele si se masoara la playtest, ca si REAL = 1.8.
  * Cartierul vechi ajunge la ~3% din bani la finalul erei. Al treilea om pe meserie (PEOPLE=3) nu-l ajuta (3.9%) si
    strica pornirea erei (6 cumparaturi in primele 5 minute in loc de 20), deci ramane la doi.
"""
import importlib.util
import os
import sys

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")

PARTS_ROLES = ("millCollector", "millPorter", "founder", "partsHauler")
COPPER_ROLES = ("oreCollector", "orePorter", "coppersmith", "copperHauler")
ERA2_ROLES = PARTS_ROLES + ("merchant",) + COPPER_ROLES
ROLE_NAMES = {
    "millCollector": "Mill Collector", "millPorter": "Mill Porter", "founder": "Founder",
    "partsHauler": "Parts Hauler", "merchant": "Merchant", "oreCollector": "Ore Collector",
    "orePorter": "Ore Porter", "coppersmith": "Coppersmith", "copperHauler": "Copper Hauler",
}
# oglinda meseriilor Erei 1: aceleasi baze (bucati pe secunda), aceleasi secunde de venit la angajare
MIRROR = {
    "millCollector": "collector", "millPorter": "porter", "founder": "sawyer", "partsHauler": "hauler",
    "merchant": "trader", "oreCollector": "scrapCollector", "orePorter": "scrapPorter",
    "coppersmith": "smelter", "copperHauler": "ironHauler",
}


def load():
    spec = importlib.util.spec_from_file_location("sim_era2_base", SIM)
    sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sim)
    return sim


def era_nets(s, T):
    return [n for n in s.nets if n.kind in ("mill", "ore")]


EAGER = False
PATIENCE = 60.0


def build(T, M, A, G, START, CAP, PEOPLE):
    """Adauga Era 2 pe o copie a simulatorului si intoarce specificatia erei."""
    # ---- liniile ----
    T.LINE_ORDER = T.LINE_ORDER + ("parts", "copper")
    T.LINES["parts"] = {
        "netKind": "mill", "openFlag": "wheel", "seller": "market",
        "steps": (("millCollector", "millCollect", "walk"), ("millPorter", "millPort", "walk"),
                  ("founder", "foundry", "processor"), ("partsHauler", "partsHaul", "walk")),
    }
    T.LINES["copper"] = {
        "netKind": "ore", "openFlag": "furnace", "seller": "market",
        "steps": (("oreCollector", "oreCollect", "walk"), ("orePorter", "orePort", "walk"),
                  ("coppersmith", "smelt", "processor"), ("copperHauler", "copperHaul", "walk")),
    }
    T.PROCESSORS["foundry"] = {"base": "FOUNDRY_BASE_RATE", "level": "foundry_level"}
    T.PROCESSORS["smelt"] = {"base": "FURNACE_BASE_RATE", "level": "furnace_level"}
    T.SELLERS["market"] = {"role": "merchant", "base": "MARKET_BASE_RATE", "level": "market_level",
                           "priority": ("copper", "parts")}
    # bucati pe secunda: ca in Era 1 (gaterul, forja, taverna)
    T.FOUNDRY_BASE_RATE = T.SAW_BASE_RATE
    T.FURNACE_BASE_RATE = T.FORGE_BASE_RATE
    T.MARKET_BASE_RATE = T.DOCK_BASE_RATE
    for kind, like in (("foundry", "saw"), ("smelt", "forge"), ("market", "dock")):
        T.LEVEL_INC_BY_KIND[kind] = T.LEVEL_INC_BY_KIND[like]
    # monede: de M ori
    T.FOUNDRY_UPGRADE_BASE = T.SAW_UPGRADE_BASE * M
    T.FURNACE_UPGRADE_BASE = T.FORGE_UPGRADE_BASE * M
    T.MARKET_UPGRADE_BASE = T.DOCK_UPGRADE_BASE * M
    T.BUILDINGS["foundry"] = {"label": "Foundry", "cost": "FOUNDRY_UPGRADE_BASE", "level": "foundry_level", "owned": "wheel"}
    T.BUILDINGS["market"] = {"label": "Market", "cost": "MARKET_UPGRADE_BASE", "level": "market_level", "owned": "wheel"}
    T.BUILDINGS["smelt"] = {"label": "Furnace", "cost": "FURNACE_UPGRADE_BASE", "level": "furnace_level", "owned": "furnace"}
    T.AVG["mill"] = T.AVG["wood"] * M
    T.AVG["ore"] = T.AVG["scrap"] * M
    for role in ERA2_ROLES:
        like = MIRROR[role]
        if like in T.ROLE_BASE:
            T.ROLE_BASE[role] = T.ROLE_BASE[like]
        T.ROLE_COST_MULT[role] = M
        T.ROLE_NAMES[role] = ROLE_NAMES[role]
    T.ROLES = T.ROLES + ERA2_ROLES
    T.MAX_PEOPLE = PEOPLE
    T.LINE_STEPS, T.LINE_LINKS, T.LINE_OF_ROLE, T.LINK_OF, T.LINKS = T.derive_tables(
        T.LINE_ORDER, T.LINES, T.SELLERS, T.ROLES
    )

    # ---- deblocarile, in oglinda cu ERA1_UNLOCKS ----
    def people(s, role):
        return s.crews[role].count

    def set_flag(name):
        def f(s):
            setattr(s, name, True)
        return f

    def net(i, kind):
        # aceleasi baze ca plasele Erei 1 (a i-a plasa a cartierului = a i-a plasa a satului), costul nivelurilor de M ori
        def f(s):
            s.nets.append(T.Net(T.NET_BASE_RATE * T.NET_BASE_GROWTH ** i, T.NET_LANES[i], kind=kind,
                                upgrade_base=T.NET_UPGRADE_BASE_COST * T.NET_BASE_GROWTH ** i * M))
        return f

    def hire(role):
        def f(s):
            s.crews[role].count += 1
        return f

    def count(s):
        return len(era_nets(s, T))

    def ready(s):
        return s.nets[-1].level >= T.PREV_NET_LEVEL

    U = [
        ("wheel", "Water Wheel", "D", lambda s: not s.wheel, set_flag("wheel")),
        ("mnet1", "Sixth Net", "C", lambda s: s.wheel and count(s) == 0, net(0, "mill")),
        ("millCollector", "Mill Collector", "A", lambda s: count(s) >= 1 and people(s, "millCollector") == 0, hire("millCollector")),
        ("millPorter", "Mill Porter", "A", lambda s: people(s, "millCollector") >= 1 and people(s, "millPorter") == 0, hire("millPorter")),
        ("founder", "Founder", "A", lambda s: people(s, "millPorter") >= 1 and people(s, "founder") == 0, hire("founder")),
        ("partsHauler", "Parts Hauler", "A", lambda s: people(s, "founder") >= 1 and people(s, "partsHauler") == 0, hire("partsHauler")),
        ("merchant", "Merchant", "A", lambda s: people(s, "partsHauler") >= 1 and people(s, "merchant") == 0, hire("merchant")),
        ("mnet2", "Seventh Net", "C", lambda s: count(s) == 1 and ready(s) and people(s, "merchant") >= 1, net(1, "mill")),
        ("mnet3", "Eighth Net", "C", lambda s: count(s) == 2 and ready(s), net(2, "mill")),
        ("mnet4", "Ninth Net", "C", lambda s: count(s) == 3 and ready(s), net(3, "mill")),
        ("furnace", "Copper Furnace", "V", lambda s: count(s) >= 4 and not s.furnace, set_flag("furnace")),
        ("onet", "Tenth Net", "C", lambda s: count(s) == 4 and ready(s) and s.furnace, net(4, "ore")),
        ("oreShed", "Ore Shed", "V", lambda s: count(s) == 5 and not s.ore_shed, set_flag("ore_shed")),
        ("oreCollector", "Ore Collector", "A", lambda s: s.ore_shed and people(s, "oreCollector") == 0, hire("oreCollector")),
        ("orePorter", "Ore Porter", "A", lambda s: people(s, "oreCollector") >= 1 and people(s, "orePorter") == 0, hire("orePorter")),
        ("coppersmith", "Coppersmith", "A", lambda s: people(s, "orePorter") >= 1 and people(s, "coppersmith") == 0, hire("coppersmith")),
        ("copperHauler", "Copper Hauler", "A", lambda s: people(s, "coppersmith") >= 1 and people(s, "copperHauler") == 0, hire("copperHauler")),
    ]
    # al doilea om (si al treilea, daca incap trei) pe fiecare meserie, a ambelor ere: se cumpara din meniul omului
    extra = []
    for role in T.ROLES:
        for n in range(2, PEOPLE + 1):
            uid = f"{role}{n}"
            if n == 2 and role not in ERA2_ROLES:
                continue  # al doilea om al Erei 1 exista deja in ERA1_UNLOCKS, cu pretul lui
            extra.append((uid, f"{'Second' if n == 2 else 'Third'} {T.ROLE_NAMES[role]}", "A",
                          (lambda s, r=role, k=n: people(s, r) == k - 1 and s.crews[r].tier >= T.SECOND_AT_TIER + (k - 2) * 2),
                          hire(role)))
    era1_seconds = [u for u in T.ERA1_UNLOCKS if u[0].endswith("2")]
    U += extra + era1_seconds
    U.append(("bell2", "Mill Bell", "D",
              lambda s: count(s) == 5 and all(people(s, r) >= 1 for r in ERA2_ROLES) and s.furnace and s.ore_shed,
              lambda s: setattr(s, "bells", s.bells * 1.10)))

    for role in ERA2_ROLES:
        T.BURST_WAIT[role] = T.BURST_WAIT[MIRROR[role]]
    T.BURST_WAIT["oreShed"] = T.BURST_WAIT["shed"]
    T.LADDER_EXEMPT = T.LADDER_EXEMPT | {u[0] for u in extra} | set(T.BURST_WAIT)
    T.UNLOCK_STAGE.update({
        "wheel": "foundry", "mnet1": "nets", "mnet2": "nets", "mnet3": "nets", "mnet4": "nets", "onet": "nets",
        "furnace": "smelt", "oreShed": "oreCollect", "bell2": "market",
    })
    for uid, *_ in extra:
        T.UNLOCK_STAGE[uid] = T.LINK_OF[uid[:-1]]
    for role in ERA2_ROLES:
        T.UNLOCK_STAGE[role] = T.LINK_OF[role]

    era_uids = {u[0] for u in U} - {u[0] for u in era1_seconds}
    return {
        "name": "Era 2",
        "unlocks": U,
        "chapter_hires": ("millCollector", "millPorter", "founder", "partsHauler", "merchant"),
        "quest_unlocks": (
            ("wheel", lambda s: True),
            ("mnet1", lambda s: True),
            ("furnace", lambda s: count(s) >= 4 and era_nets(s, T)[3].level >= T.PREV_NET_LEVEL),
            ("onet", lambda s: True),
            ("oreShed", lambda s: True),
            ("oreCollector", lambda s: True),
            ("orePorter", lambda s: True),
            ("coppersmith", lambda s: True),
            ("copperHauler", lambda s: True),
        ),
        # plasele erei: un om le ia cum are banii (quest-ul le cere); vezi `eager_unlocks` in sim_tycoon.run
        "eager_unlocks": ("mnet2", "mnet3", "mnet4") if EAGER else (),
        "patience": PATIENCE,  # cate secunde de venit strange un om pentru o plasa, fara sa mai cumpere altceva
        "bell": "bell2",
        "first_net": 5,
        "net_count": 5,
        # scara erei: numara doar deblocarile ei de pe scara
        "step": lambda bought: len((bought & era_uids) - T.LADDER_EXEMPT),
        "wait": lambda k: min(CAP, A * G ** (k + START)),
        "free_first": False,
    }


ROBUST_KNOBS = ("PLAYER_LABOR", "FOUNDRY_BASE_RATE", "FURNACE_BASE_RATE", "MARKET_BASE_RATE", "ROLE_BASE.millCollector",
                "ROLE_BASE.millPorter", "ROLE_BASE.partsHauler", "ROLE_BASE.oreCollector", "ROLE_BASE.orePorter",
                "ROLE_BASE.copperHauler")


def play(knobs, tweak=None):
    """Joaca Era 1 si apoi Era 2 pe o copie proaspata. `tweak(T)` schimba constante dupa ce Era 2 e adaugata."""
    global EAGER, PATIENCE
    EAGER, PATIENCE = knobs["EAGER"] > 0, knobs["PATIENCE"]
    T = load()
    s1, _rows1, prices1, _idle1, income1, _shares1, _scrap = T.run()
    end1 = s1.t
    era = build(T, knobs["M"], knobs["A"], knobs["G"], knobs["START"], knobs["CAP"], int(knobs["PEOPLE"]))
    if tweak is not None:
        tweak(T)
    for name in ("wheel", "furnace", "ore_shed"):
        setattr(s1, name, False)
    s1.foundry_level = s1.market_level = s1.furnace_level = 1
    for role in ERA2_ROLES:
        s1.crews[role] = T.Crew()
    T.VIOLATIONS.clear()
    seeded = {uid: price for uid, price in prices1.items() if uid.endswith("2") and uid not in s1.bought}
    s2, rows, prices, idle, final, shares, _ = run_with_prices(T, era, s1, seeded)
    return T, era, s1, end1, income1, s2, rows, prices, idle, final, shares


def robust(knobs):
    print("\n--robust: fiecare constanta a cartierului nou x0.85 si x1.15")
    bad = 0
    for knob in ROBUST_KNOBS:
        for factor in (0.85, 1.15):
            def tweak(T, knob=knob, factor=factor):
                if knob.startswith("ROLE_BASE."):
                    T.ROLE_BASE[knob.split(".")[1]] *= factor
                else:
                    setattr(T, knob, getattr(T, knob) * factor)
            try:
                T, _era, _s1, end1, _i1, s2, rows, _p, idle, final, _sh = play(knobs, tweak)
                real = (s2.t - end1) * T.REAL
                flag = "" if not T.VIOLATIONS and real <= 5400 else "   <-- PROBLEMA"
                bad += 1 if flag else 0
                print(f"  {knob + ' x' + str(factor):<32}{T.fmt(real):>8} real, {len(rows)} cumparaturi, pauza {T.fmt(idle)}, "
                      f"final {final:.0f}/s, scaderi de venit: {len(T.VIOLATIONS)}{flag}")
            except SystemExit as e:
                bad += 1
                print(f"  {knob + ' x' + str(factor):<32}{e}   <-- PROBLEMA")
    return bad


def main():
    args = sys.argv[1:]
    global EAGER, PATIENCE
    knobs = {"M": 40.0, "A": 20.0, "G": 1.17, "START": 5.0, "CAP": 420.0, "PEOPLE": 2.0, "EAGER": 0.0, "PATIENCE": 60.0}
    for a in args:
        if "=" in a:
            k, v = a.split("=")
            knobs[k] = float(v)
    EAGER = knobs["EAGER"] > 0
    PATIENCE = knobs["PATIENCE"]
    M, A, G, START, CAP, PEOPLE = (knobs[k] for k in ("M", "A", "G", "START", "CAP", "PEOPLE"))
    T, era, s1, end1, income1, s2, rows, prices, idle, final, shares = play(knobs)

    R = T.REAL
    dur = s2.t - end1
    print(f"Era 2 (M={M:g}, scara {A:g} x {G:g}^(k+{START:g}) pana la {CAP:g}s, {int(PEOPLE)} oameni pe meserie)")
    print(f"  {len(rows)} cumparaturi, {T.fmt(dur)} lacom -> {T.fmt(dur * R)} real   (Era 1: {T.fmt(end1 * R)} real)")
    print(f"  venit: {income1:.1f}/s -> {final:.1f}/s   (x{final / income1:.1f})")
    print(f"  cea mai lunga pauza fara nimic de apasat: {T.fmt(idle)} lacom / {T.fmt(idle * R)} real")
    first5 = sum(1 for r in rows if (r[3] - end1) * R <= 300)
    print(f"  primele 5 minute reale ale erei: {first5} cumparaturi")
    c = T.chain(s2)
    old = sum(c.lines[l].delivered * T.line_avg(l) for l in ("wood", "iron"))
    new = sum(c.lines[l].delivered * T.line_avg(l) for l in ("parts", "copper"))
    print(f"  la final: cartierul vechi {old / (old + new) * 100:.1f}% din bani, piesele "
          f"{c.lines['parts'].delivered * T.line_avg('parts') / (old + new) * 100:.1f}%, cuprul "
          f"{c.lines['copper'].delivered * T.line_avg('copper') / (old + new) * 100:.1f}%")
    total = sum(shares.values())
    lt = s2.line_time
    parts_links, copper_links = T.LINE_LINKS["parts"], T.LINE_LINKS["copper"]
    def share(link):
        if link in copper_links:
            return shares[link] / lt["copper"] if lt["copper"] else 0.0
        return shares[link] / total if total else 0.0
    print("  veriga care tine venitul, ca parte din timp: "
          + " | ".join(f"{l} {share(l) * 100:.1f}%" for l in T.LINKS if shares[l] > 0 or l in parts_links + copper_links + ("market",)))
    print(f"  (cuprul: din {T.fmt(lt['copper'])} cu minereu)")
    crews = ", ".join(f"{T.ROLE_NAMES[r]} {s2.crews[r].count}x treapta {s2.crews[r].tier}" for r in T.ROLES)
    print(f"  oamenii la final: {crews}")
    if T.VIOLATIONS:
        print("  !! venit scazut de o cumparatura:")
        for v in T.VIOLATIONS[:8]:
            print("     ", v)
    print("\n  deblocarile, in ordinea cumpararii:")
    for label, kind, price, t, after, bn in rows:
        if kind == "unlock":
            print(f"    {label[7:]:<22}{T.big(price):>8}   la {T.fmt((t - end1) * R):>8} real   venit {after:>10.1f}/s   tine: {bn}")
    never = [u[0] for u in era["unlocks"] if u[0] not in s2.bought]
    if never:
        print("  necumparate: " + ", ".join(f"{uid} {T.big(prices[uid])}" for uid in never))
    if "--table" in args:
        print()
        for label, kind, price, t, after, bn in rows:
            print(f"    {T.fmt((t - end1) * R):>8}  {label:<34}{T.big(price):>8}  {after:>10.1f}/s  {bn}")
    if "--robust" in args and robust(knobs) > 0:
        sys.exit(1)


def run_with_prices(T, era, start, seeded):
    """`run` isi face preturile din mers; al doilea om al Erei 1, ramas necumparat, vine cu pretul lui de atunci."""
    era = dict(era)
    # preturile mostenite: o deblocare care le are deja nu se mai reevalueaza (vezi `reprice`: sare ce e in `prices`)
    era["seed_prices"] = seeded
    return T.run(era=era, start=start, max_seconds=200000)


if __name__ == "__main__":
    main()
