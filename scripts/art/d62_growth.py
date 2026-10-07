#!/usr/bin/env python3
"""[D62, pasul 5] Satul creste la vedere: ce se schimba pe ecran cand urci un nivel peste un prag (10 / 25 / 50).

  * prop_net_water_r1 / _r2 / _r3 (+ `_full`) (32x18) -- plasa pe ranguri: flotoare rosii pe rama (10), mai multe
    flotoare si ata mai deasa (25), flotoare si rama aurii (50). Aceeasi cutie ca plasa de azi: doar desenul se schimba.
  * ui_levelbadge_bronze / _silver / _gold (20x20, 9 felii) -- insigna `Lv N` pe rangul ei; cea albastra ramane sub 10.
  * prop_bird (16x8: doua cadre de 8x8) -- pasarea care trece peste sat, cu aripile sus si jos.

Acelasi stil si aceleasi unelte ca restul conductei. Rulare: python3 scripts/art/d62_growth.py [--force]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, T, png  # noqa: E402
from palette import ramp, hsv, mix  # noqa: E402
from tycoon_e1 import GOLD, GOLD_HI, STEEL  # noqa: E402
from tycoon_f3 import _net_water, NET_THREAD  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES

FLOAT_RED = ramp(6, 0.66, 0.70)
BRONZE = ramp(26, 0.58, 0.60)
SILVER = ramp(214, 0.10, 0.74)
INK = hsv(24, 0.45, 0.14)


def net_rank(rank, loaded):
    """Plasa de azi, plus ce aduce rangul. Flotoarele stau pe rama de sus (randurile 0-1), unde plasa iese din apa."""
    c = _net_water(loaded)
    if rank >= 2:  # ata mai deasa: o a treia familie de fire, mai deschisa, intre cele doua
        for k in range(-14, 40, 7):
            for y in range(3, 18):
                x = k + y
                if 1 <= x <= 30 and c.px[y][x][3]:
                    c.put(x, y, mix(c.px[y][x], NET_THREAD[3], 0.45))
    floats = {1: (5, 13, 21, 27), 2: (3, 8, 13, 18, 23, 28), 3: (3, 8, 13, 18, 23, 28)}[rank]
    body = GOLD if rank == 3 else FLOAT_RED
    for fx in floats:
        c.rect(fx - 1, 0, 3, 2, body[2])
        c.put(fx, 0, body[4])  # luciul
        c.put(fx - 1, 1, body[1])
        c.put(fx + 1, 1, body[0])
        if rank < 3:
            c.put(fx, 1, (248, 244, 232, 255))  # dunga alba a flotorului
    if rank == 3:  # rama aurie intre flotoare
        for x in range(2, 30):
            if x not in [f + d for f in floats for d in (-1, 0, 1)]:
                c.put(x, 1, GOLD_HI[3] if x % 2 else GOLD[2])
    return c


def levelbadge(pal, size=20, border=8):
    """Aceeasi forma ca ui_levelbadge (tycoon_e1), in culoarea rangului."""
    c = C(size, size)
    for y in range(size):
        col = pal[3] if y < 2 else (pal[0] if y >= size - 2 else pal[2])
        c.rect(0, y, size, 1, col)
    c.rect(0, 2, size, 1, pal[4])
    for cy in (0, 1):
        for cx in (0, 1):
            for y in range(border):
                for x in range(border):
                    if math.hypot(border - 0.5 - x, border - 0.5 - y) > border:
                        px = x if cx == 0 else size - 1 - x
                        py = y if cy == 0 else size - 1 - y
                        c.px[py][px] = T
    return c


def bird():
    """Doua cadre de 8x8: aripile sus (V) si aripile jos (acoperis). De departe, atat se vede dintr-o pasare."""
    c = C(16, 8)
    up = ((0, 1), (1, 2), (2, 3), (3, 4), (4, 3), (5, 2), (6, 1))
    down = ((0, 4), (1, 3), (2, 2), (3, 3), (4, 2), (5, 3), (6, 4))
    for ox, shape in ((0, up), (8, down)):
        for x, y in shape:
            c.put(ox + x, y, INK)
            c.put(ox + x, y + 1, (INK[0], INK[1], INK[2], 120))
        c.put(ox + 3, 4 if shape is up else 3, STEEL[1])  # trupul
    return c


SPRITES = {
    "ui_levelbadge_bronze": lambda: levelbadge(BRONZE),
    "ui_levelbadge_silver": lambda: levelbadge(SILVER),
    "ui_levelbadge_gold": lambda: levelbadge(GOLD),
    "prop_bird": bird,
}
for _rank in (1, 2, 3):
    SPRITES[f"prop_net_water_r{_rank}"] = (lambda r: lambda: net_rank(r, False))(_rank)
    SPRITES[f"prop_net_water_r{_rank}_full"] = (lambda r: lambda: net_rank(r, True))(_rank)


def main():
    force = "--force" in sys.argv
    for name in SPRITES:
        if os.path.exists(os.path.join(OUT, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name, make in SPRITES.items():
        c = make()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
