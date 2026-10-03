#!/usr/bin/env python3
"""[D70, R10] Comutatorul LOCAL al Erei 4, pentru probe. NU SE COMITE NICIODATA.

    python3 scripts/era4_flip.py on       # ENGINE_ERAS = 4 si cele 23 de platforme ale barajului `live`
    python3 scripts/era4_flip.py off      # inapoi, exact cum era (doar randurile marcate de el)
    python3 scripts/era4_flip.py status   # ce e pornit acum

Jocul porneste Era 4 abia la pasul l3 (PLAN-MOTOR-UNIRE §16). Pana atunci, proba pe server si in Studio (j13, k, l1)
se face cu acest comutator, pe un profil de proba. Poarta pica pe un comutator comis (testele de adormire din
ChainMath.test), iar `status` iese cu cod 1 cand e pornit, ca sa se poata pune intr-un hook.

Schimba doar doua lucruri, fiecare marcat cu `-- era4_flip`, ca `off` sa le gaseasca fara sa ghiceasca:
  * src/Shared/Config/StationConfig.luau: `StationConfig.ENGINE_ERAS = 3`  ->  `= 4 -- era4_flip`
  * src/Shared/Config/TycoonConfig.luau: in fiecare `pad({ ... })` cu `era = 4,`, `live = false,` -> `live = true, -- era4_flip`
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATION = ROOT / "src/Shared/Config/StationConfig.luau"
TYCOON = ROOT / "src/Shared/Config/TycoonConfig.luau"
MARK = "-- era4_flip"
ENGINE_OFF = "StationConfig.ENGINE_ERAS = 3\n"
ENGINE_ON = f"StationConfig.ENGINE_ERAS = 4 {MARK}\n"
LIVE_OFF = "        live = false,\n"
LIVE_ON = f"        live = true, {MARK}\n"
ERA4_PADS = 23


def pad_blocks(lines):
    """(inceput, sfarsit) pentru fiecare `pad({` ... `}),` de pe indentarea 4."""
    start = None
    for i, line in enumerate(lines):
        if line == "    pad({\n":
            start = i
        elif start is not None and line == "    }),\n":
            yield start, i
            start = None


def flip_pads(on: bool) -> int:
    lines = TYCOON.read_text(encoding="utf-8").splitlines(keepends=True)
    changed = 0
    for a, b in pad_blocks(lines):
        block = lines[a : b + 1]
        if "        era = 4,\n" not in block:
            continue
        for i in range(a, b + 1):
            if on and lines[i] == LIVE_OFF:
                lines[i] = LIVE_ON
                changed += 1
            elif not on and lines[i] == LIVE_ON:
                lines[i] = LIVE_OFF
                changed += 1
    TYCOON.write_text("".join(lines), encoding="utf-8")
    return changed


def flip_engine(on: bool) -> bool:
    text = STATION.read_text(encoding="utf-8")
    old, new = (ENGINE_OFF, ENGINE_ON) if on else (ENGINE_ON, ENGINE_OFF)
    if text.count(old) != 1:
        return False
    STATION.write_text(text.replace(old, new), encoding="utf-8")
    return True


def status() -> tuple[bool, int]:
    engine = ENGINE_ON in STATION.read_text(encoding="utf-8")
    pads = TYCOON.read_text(encoding="utf-8").count(LIVE_ON)
    return engine, pads


def main() -> int:
    what = sys.argv[1] if len(sys.argv) > 1 else "status"
    engine, pads = status()
    if what == "status":
        on = engine or pads > 0
        print(f"era4_flip: {'PORNIT' if on else 'oprit'} (ENGINE_ERAS 4: {engine}, platforme live: {pads}/{ERA4_PADS})")
        return 1 if on else 0
    if what == "on":
        if engine and pads == ERA4_PADS:
            print("era4_flip: era deja pornit")
            return 0
        ok = flip_engine(True) or engine
        n = flip_pads(True)
        engine, pads = status()
        if not ok or pads != ERA4_PADS:
            print(f"era4_flip: pornit doar pe jumatate (ENGINE_ERAS 4: {engine}, platforme: {pads}/{ERA4_PADS})")
            return 2
        print(f"era4_flip: PORNIT ({n} platforme). NU COMITE. Opreste cu: python3 scripts/era4_flip.py off")
        return 0
    if what == "off":
        flip_engine(False)
        flip_pads(False)
        engine, pads = status()
        if engine or pads > 0:
            print(f"era4_flip: n-a putut opri tot (ENGINE_ERAS 4: {engine}, platforme: {pads})")
            return 2
        print("era4_flip: oprit")
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
