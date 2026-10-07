#!/usr/bin/env python3
"""[D62, pasul 3] Darurile raului: butoiul si lada care trec pe rau, plutind (bustenul de aur exista: treasure_golden_water).

  * treasure_barrel_water (22x16) -- butoi culcat, cu doua cercuri de fier, pe jumatate in apa
  * treasure_crate_water  (20x16) -- lada de scanduri cu colturi de fier, pe jumatate in apa

Acelasi stil si aceleasi unelte ca lucrurile aduse de rau din D59 (`in_water`: sub linia apei obiectul se vede prin apa,
pe linie e spuma). Rulare: python3 scripts/art/d62.py [--force]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png  # noqa: E402
from palette import WOOD, WATER  # noqa: E402
from tycoon_e1 import outline_trace, STEEL  # noqa: E402
from d59 import in_water  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES


def barrel():
    """Butoi culcat, vazut dintr-o parte: doage pe lungime, doua cercuri de fier, capatul cu fundul lui."""
    c = C(22, 16)
    for y in range(3, 13):
        bulge = 1 if y in (3, 12) else 0  # burta butoiului: randurile de la margini sunt mai scurte
        shade = WOOD[3] if y < 6 else (WOOD[2] if y < 10 else WOOD[1])
        c.rect(2 + bulge, y, 18 - 2 * bulge, 1, shade)
    for y in (5, 8, 10):  # rosturile dintre doage
        c.rect(3, y, 16, 1, WOOD[1])
    c.rect(3, 3, 16, 1, WOOD[4])  # lumina de sus
    for bx in (6, 14):  # cercurile de fier
        c.rect(bx, 3, 2, 10, STEEL[1])
        c.rect(bx, 3, 1, 10, STEEL[2])
    c.rect(2, 5, 1, 6, WOOD[0])  # capatul din umbra
    c.rect(19, 5, 1, 6, WOOD[4])
    c.put(9, 4, (255, 250, 235, 255))  # luciu ud
    c.put(16, 11, WATER[4])
    outline_trace(c)
    return c


def crate():
    """Lada de scanduri, din fata: trei scanduri late, o scandura in cruce, colturi de fier."""
    c = C(20, 16)
    c.rect(3, 2, 14, 12, WOOD[2])
    for y in (5, 9):  # rosturile scandurilor
        c.rect(3, y, 14, 1, WOOD[0])
    c.rect(3, 2, 14, 1, WOOD[4])
    c.rect(16, 3, 1, 11, WOOD[1])
    for i in range(10):  # scandura in cruce
        c.put(5 + i, 3 + i, WOOD[3])
        c.put(6 + i, 3 + i, WOOD[1])
    for x, y in ((3, 2), (15, 2), (3, 12), (15, 12)):  # colturile de fier
        c.rect(x, y, 2, 2, STEEL[2])
        c.put(x, y, STEEL[3])
    c.put(8, 12, WATER[4])
    outline_trace(c)
    return c


SPRITES = {
    "treasure_barrel_water": lambda: in_water(barrel(), 9),
    "treasure_crate_water": lambda: in_water(crate(), 10),
}


def main():
    force = "--force" in sys.argv
    for name, make in SPRITES.items():
        path = os.path.join(OUT, name + ".png")
        if os.path.exists(path) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name, make in SPRITES.items():
        c = make()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
