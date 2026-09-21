#!/usr/bin/env python3
"""„Ce-ar fi daca" pentru Era 3, „The Wire Works" [D67]: incarca simulatorul adevarat, schimba IN MEMORIE cadrul erei si
masoara, ca sim_era2.py pentru Moara. Nu scrie nimic in repo si nu e in poarta.

Era 3 traieste in `sim_tycoon.py` (liniile `coils` si `power`, cladirile, oamenii, `ERA3_UNLOCKS`, portile ei). Aici se
schimba doar butoanele si se joaca din nou, din starea (neschimbata) de la finalul Morii.

    python3 scripts/economy/sim_era3.py [--table] [M=3000] [START=7.5]

  M      de cate ori valoreaza marfa Erei 3 mai mult decat a Morii (si nivelurile, si treptele)
  START  unde porneste scara de asteptare a erei (Moara: 7.5, vezi D66)

CE S-A AFLAT LA DERIVARE (2026-09-21, D67): Moara in oglinda, pe scara x3000 fata de ea, trece din prima toate portile
Morii (53 de minute reale, 25 de cumparaturi in primele 5 minute, o noapte de absenta sare 17%), si la +-15% pe fiecare
constanta noua (43 min - 1h01m). Bateria valoreaza 3.5 x cadrul (media plasei de minereu a Morii, 3.55, rotunjita).
"""
import contextlib
import importlib.util
import io
import os
import sys

SIM = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_tycoon.py")
DEFAULTS = {"M": 3000.0, "START": 7.5}


def load():
    spec = importlib.util.spec_from_file_location("sim_era3_whatif", SIM)
    sim = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sim)
    return sim


def apply_frame(T, knobs):
    """Tot ce depinde de cadrul Erei 3, pus din nou pe copia `T`."""
    m3 = T.ERA2_MULT * knobs["M"]
    T.ERA3_MULT = m3
    for good, base in (("works_ore", 1.0), ("coils", 1.0), ("battery", 3.5), ("cell", 3.5), ("named3", 14.0)):
        T.GOODS[good] = base * m3
    T.AVG.update({kind: sum(share * T.GOODS[good] for good, share in parts) for kind, parts in T.CATCH.items()})
    T.WIREWORKS_UPGRADE_BASE, T.POWERHOUSE_UPGRADE_BASE, T.DEPOT_UPGRADE_BASE = 7.0 * m3, 60.0 * m3, 9.0 * m3
    for role in T.ERA3_ROLES:
        T.ROLE_COST_MULT[role] = m3
    T.ERA3_LADDER_START = knobs["START"]


def main():
    knobs = dict(DEFAULTS)
    for arg in sys.argv[1:]:
        if "=" in arg:
            key, value = arg.split("=", 1)
            knobs[key.upper()] = float(value)
    T = load()
    with contextlib.redirect_stdout(io.StringIO()):
        s1, _rows1, prices1, *_ = T.run()
        s2, _rows2, prices2, _idle2, income2, *_ = T.run_era(2, T.clone(s1), prices1)
    apply_frame(T, knobs)
    T.VIOLATIONS.clear()
    with contextlib.redirect_stdout(io.StringIO()):
        s3, rows, prices, idle, final, shares, _ = T.run_era(3, T.clone(s2), {**prices1, **prices2})
    print(f"cadrul Erei 3: M = {knobs['M']:g}, START = {knobs['START']:g}")
    if "--table" in sys.argv:
        for i, (label, kind, price, t, inc, bn) in enumerate(rows, 1):
            print(f"{i:>3} {label:<32} {kind:>8} {T.big(price):>8} {T.fmt((t - s2.t) * T.REAL):>8} {T.big(inc):>10} {bn:>14}")
    T.report_era(3, s2, s3, rows, prices, idle, final, shares, income2)
    problems = list(T.VIOLATIONS) + T.check_run_era(3, rows, idle, shares, s3.line_time[T.LATE_LINE[3]], s2.t, s3.t)
    problems += T.check_windfall(income2, rows, s2.t, s3.t, era=3)
    if problems:
        print("\nPORTILE NU TREC:")
        for p in problems:
            print("  " + p)
        sys.exit(1)
    print("\nportile Erei 3 trec")


if __name__ == "__main__":
    main()
