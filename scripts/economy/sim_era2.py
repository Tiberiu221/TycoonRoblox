#!/usr/bin/env python3
"""„Ce-ar fi daca" pentru Era 2 [D65]: incarca simulatorul adevarat, schimba IN MEMORIE cadrul erei si masoara.

Era 2 traieste in `sim_tycoon.py` (liniile, cladirile, oamenii, `ERA2_UNLOCKS`, portile ei). Aici nu se defineste nimic:
se schimba doar butoanele si se joaca din nou, ca `tune_tycoon.py` pentru Era 1. Nu scrie nimic in repo.

    python3 scripts/economy/sim_era2.py [--table] [M=3000] [A=20] [G=1.17] [START=7.5] [CAP=420] [EAGER=0] [PATIENCE=60]

  M        cadrul erei: de cate ori valoreaza marfa ei mai mult decat a Erei 1 (si nivelurile, si treptele)
  A, G, START, CAP   scara de asteptare a erei: min(CAP, A x G^(k + START)) secunde de venit la deblocarea k
  EAGER=1  un jucator care alearga dupa plase: le ia cum are banii si strange pentru ele cand e la cel mult PATIENCE
           secunde de venit de ele (implicit, acelasi jucator ca la Era 1: cumpara dupa raportul castig/pret)

[D66, 2026-09-21] CADRUL S-A MUTAT LA M = 3000 si START = 7.5 (a sasea plasa gratis, in sim_tycoon.py). Cu 40, o noapte de
absenta de la sfarsitul Erei 1 cumpara aproape toata Moara; pe scara mare, doar inceputul ei (sim_tycoon.check_windfall).
Ce urmeaza e ce s-a aflat cu cadrul vechi:

CE S-A AFLAT LA DERIVARE (2026-09-19):
  * Schema oglindita da singura ~57 de minute reale (tinta owner-ului: cam o ora), cu aceeasi scara de asteptare ca la
    Era 1, repornita. Nicio cumparatura nu scade venitul. Venitul creste de ~45 de ori.
  * M: durata e STABILA pentru M de la 30 la 60 (55-57 de minute, ~398 de cumparaturi), dar sare la ~1h14m pentru
    M <= 28: acolo jucatorul simulat amana a saptea plasa 25 de minute, fiindca nivelurile ieftine au raport castig/pret
    mai bun. De aceea M = 40, in mijlocul zonei stabile, nu 30, care sta pe margine.
  * MODELUL JUCATORULUI conteaza mai mult decat M. Cu EAGER=1 era se termina in ~23 de minute, cu venit mai mic.
    Adevarul e intre cele doua si se masoara la playtest, ca si REAL = 1.8.
  * Cartierul vechi ajunge la ~3% din bani la finalul erei. Al treilea om pe meserie nu-l ajuta (3.9%) si strica
    pornirea erei (6 cumparaturi in primele 5 minute in loc de 20), deci raman doi oameni pe meserie.
"""
import importlib.util
import os
import sys

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")
DEFAULTS = {"M": 3000.0, "A": 20.0, "G": 1.17, "START": 7.5, "CAP": 420.0, "EAGER": 0.0, "PATIENCE": 60.0}


def load():
    spec = importlib.util.spec_from_file_location("sim_era2_whatif", SIM)
    sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sim)
    return sim


def apply_frame(T, knobs):
    """Tot ce depinde de cadrul erei, pus din nou pe copia `T`."""
    m = knobs["M"]
    T.ERA2_MULT = m
    for good, base in (("mill_scrap", 1.0), ("parts", 1.0), ("ore", 3.0), ("copper", 3.0), ("named2", 14.0)):
        T.GOODS[good] = base * m
    T.AVG.update({kind: sum(share * T.GOODS[good] for good, share in parts) for kind, parts in T.CATCH.items()})
    T.FOUNDRY_UPGRADE_BASE, T.FURNACE_UPGRADE_BASE, T.MARKET_UPGRADE_BASE = 7.0 * m, 60.0 * m, 9.0 * m
    for role in T.ERA2_ROLES:
        T.ROLE_COST_MULT[role] = m
    a, g, start, cap = knobs["A"], knobs["G"], knobs["START"], knobs["CAP"]
    T.ERA2["wait"] = lambda k: min(cap, a * g ** (k + start))
    if knobs["EAGER"] > 0:
        T.ERA2["eager_unlocks"] = ("net7", "net8", "net9")
        T.ERA2["patience"] = knobs["PATIENCE"]


def main():
    args = sys.argv[1:]
    knobs = dict(DEFAULTS)
    for a in args:
        if "=" in a:
            k, v = a.split("=", 1)
            knobs[k] = float(v)
    T = load()
    apply_frame(T, knobs)
    s1, _rows1, prices1, _idle1, income1, _shares1, _scrap = T.run()
    T.VIOLATIONS.clear()
    s2, rows, prices, idle, final, shares, _ = T.run_era2(T.clone(s1), prices1)
    print(f"cadrul: M={knobs['M']:g}, scara {knobs['A']:g} x {knobs['G']:g}^(k+{knobs['START']:g}) pana la {knobs['CAP']:g}s"
          + (f", jucator grabit (rabdare {knobs['PATIENCE']:g}s)" if knobs["EAGER"] > 0 else ""))
    if "--table" in args:
        for i, (label, kind, price, t, inc, bn) in enumerate(rows, 1):
            print(f"{i:>3} {label:<30} {kind:>8} {T.big(price):>8} {T.fmt((t - s1.t) * T.REAL):>8} {inc:>10.2f} {bn:>12}")
    T.report_era2(s1, s2, rows, prices, idle, final, shares, income1)
    problems = list(T.VIOLATIONS) + T.check_run_era2(rows, idle, shares, s2.line_time[T.LATE_LINE[2]], s1.t, s2.t)
    if problems:
        print("\nportile Erei 2, cu cadrul asta:")
        for p in problems:
            print("  " + p)


if __name__ == "__main__":
    main()
