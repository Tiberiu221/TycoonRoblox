#!/usr/bin/env python3
"""Ce-ar fi daca: incarca simulatorul adevarat (sim_tycoon.py), suprascrie constante IN MEMORIE si masoara ritmul Erei 1
cu porti mai aspre decat cele din simulator [D62]. Nu scrie nimic in repo.

DE CE EXISTA: constantele economiei nu se schimba din ochi. In D62, "plasa de trei ori mai rapida, munca ta mai mica"
parea reparatia pentru primele cinci minute; masurata aici, strica toata curba (platou la 66/s zece minute). Reparatia
buna (oamenii in rafala) a iesit tot de aici.

Folosire:  python3 scripts/economy/tune_tycoon.py eval [NUME=valoare ...]
  NUME = orice constanta scalara din simulator, sau ROLE_BASE.<rol>, LEVEL_INC.<fel>, BURST.<id>, TW0/TWG/TWCAP (scara).
Portile masurate: G1 fiecare angajare a capitolului 1 creste venitul (azi nu: plasa e veriga slaba, de aceea vin in
rafala), G2 cumparaturi in primele 5 minute, G3 pauza intre deblocari, G4 cat a crescut venitul la 5 si 10 minute,
G5 platouri (ferestre de 5 minute cu crestere sub 12%), plus portile simulatorului.
"""
import sys, io, os, contextlib, importlib.util

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")

def load():
    spec = importlib.util.spec_from_file_location("sim", SIM)
    sim = importlib.util.module_from_spec(spec)
    src = open(SIM).read()
    sim.__dict__["__name__"] = "sim"
    with contextlib.redirect_stdout(io.StringIO()):
        exec(compile(src, SIM, "exec"), sim.__dict__)
    return sim

def apply(sim, over):
    tw = {k: over[k] for k in ("TW0", "TWG", "TWCAP") if k in over}
    if tw:
        a, g, cap = tw.get("TW0", 20.0), tw.get("TWG", 1.17), tw.get("TWCAP", 420.0)
        sim.__dict__["target_wait"] = lambda k, a=a, g=g, cap=cap: min(cap, a * g**k)
    for k, v in over.items():
        if k in ("TW0", "TWG", "TWCAP"):
            continue
        if k.startswith("ROLE_BASE."):
            sim.ROLE_BASE[k.split(".")[1]] = v
        elif k.startswith("LEVEL_INC."):
            sim.LEVEL_INC_BY_KIND[k.split(".")[1]] = v
        elif k.startswith("BURST."):
            sim.BURST_WAIT[k.split(".")[1]] = v
        else:
            sim.__dict__[k] = v

def measure(over):
    sim = load()
    apply(sim, over)
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            s, rows, prices, idle, final, shares, scrap_time = sim.run()
    except SystemExit as e:
        return None, [f"SIM: {e}"], None
    R = sim.REAL
    problems = list(sim.VIOLATIONS) + sim.check_hire_order() + sim.check_run(rows, idle, shares, prices, scrap_time)
    def inc_at(sec):
        last = rows[0][4]
        for r in rows:
            if r[3] * R <= sec: last = r[4]
        return last
    start = rows[0][4]
    end = rows[-1][3] * R
    # G1: fiecare angajare a capitolului 1 creste venitul
    for i, r in enumerate(rows):
        if r[1] == "unlock" and any(r[0].endswith(n) for n in ("Collector", "Porter", "Sawyer", "Hauler", "Innkeeper")) and not r[0].startswith("unlock:Second") and "Scrap" not in r[0] and "Iron" not in r[0]:
            before = rows[i - 1][4]
            if r[4] < before * 1.05:
                problems.append(f"G1 {r[0][7:]} nu creste venitul ({before:.2f} -> {r[4]:.2f})")
    first5 = sum(1 for r in rows if r[3] * R <= 300)
    if first5 < 12: problems.append(f"G2 doar {first5} cumparaturi in primele 5 min")
    unl = [r[3] * R for r in rows if r[1] == "unlock"]
    gaps = [(b - a, b) for a, b in zip(unl, unl[1:])]
    worst_early = max((g for g, t in gaps if t <= 900), default=0)
    worst = max((g for g, t in gaps), default=0)
    if worst_early > 150: problems.append(f"G3 pauza intre deblocari {worst_early:.0f}s in primele 15 min")
    if worst > 240: problems.append(f"G3 pauza intre deblocari {worst:.0f}s")
    if inc_at(300) < 5 * start: problems.append(f"G4 venitul la 5 min e doar x{inc_at(300)/start:.1f}")
    if inc_at(600) < 20 * start: problems.append(f"G4 venitul la 10 min e doar x{inc_at(600)/start:.1f}")
    t = 300
    while t + 300 <= end:
        g = inc_at(t + 300) / inc_at(t)
        if g < 1.12: problems.append(f"G5 platou {t//60}-{t//60+5} min: +{(g-1)*100:.0f}%")
        t += 150
    if not (25 * 60 <= end <= 40 * 60): problems.append(f"durata {end/60:.1f} min")
    info = dict(end=end, first5=first5, worst=worst, worst_early=worst_early, rows=rows, R=R, prices=prices,
                inc=[inc_at(m * 60) for m in (1, 2, 3, 5, 8, 10, 15, 20, 25, 30)], shares=shares, sim=sim, scrap_time=scrap_time)
    return info, problems, sim

def show(info, problems):
    rows, R = info["rows"], info["R"]
    print(f"Era 1: {len(rows)} cumparaturi, {info['end']/60:.1f} min real; primele 5 min: {info['first5']}; pauza max intre deblocari {info['worst']:.0f}s")
    print("venit la min 1,2,3,5,8,10,15,20,25,30: " + " ".join(f"{v:.1f}" for v in info["inc"]))
    prev = 0
    for r in rows:
        if r[1] == "unlock":
            t = r[3] * R
            print(f"  {int(t//60):2d}m{int(t%60):02d}s (+{t-prev:4.0f}s) {r[0][7:]:18s} {r[2]:7.0f}  venit {r[4]:7.2f}  gatuire {r[5]}")
            prev = t
    sim = info["sim"]
    print("gatuiri: " + " | ".join(f"{l} {sim.link_share(l, info['shares'], info['scrap_time'])*100:.1f}%" for l in sim.LINKS))
    print(f"{len(problems)} probleme:"); [print("   -", p) for p in problems[:30]]

if __name__ == "__main__":
    if sys.argv[1] == "eval":
        over = {}
        for a in sys.argv[2:]:
            k, v = a.split("=", 1); over[k] = float(v)
        info, problems, _ = measure(over)
        if info is None: print(problems)
        else: show(info, problems)
