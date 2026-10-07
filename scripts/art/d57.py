#!/usr/bin/env python3
"""Arta pentru D57: satul pe flux.

Owner-ul (2026-09-14), pe harta de azi: "texturile obiectelor (taverna sawmill forge etc) parca plutesc mereu, nu fac
parte din realul absolut al jocului", apoi, pe previzualizarea satului: case pe pamant batatorit, iar taverna cu
piata ei de piatra si pamant in jur. Doua lucruri noi, amandoua dale care se repeta (ScaleType.Tile, x3):

  * tile_plaza    (64x64) -- piatra pietei din fata tavernei: pietre rotunjite pe randuri decalate, rosturi
                             mai inchise, lumina din stanga-sus (aceeasi ca umbrele de pe harta);
  * grass_edge_h  (64x8)  -- smocuri de iarba care rup linia dreapta dintre iarba si pamant (marginile drumurilor si
    grass_edge_v  (8x64)     ale curtilor): se pun peste margine, jumatate pe iarba, jumatate pe pamant.

Culorile iese din dalele existente: iarba din grass_tile (90,133,74 si vecinii ei), piatra din deck_tile si
path_tile, ca piata sa para din acelasi pamant. Dalele se repeta fara cusatura (nimic nu trece peste margine).

Rulare: python3 scripts/art/d57.py [--force]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES

# iarba: exact nuantele din grass_tile (cele mai dese), plus varfurile luminate
GRASS_DARK = (77, 111, 57, 255)
GRASS_MID = (90, 133, 74, 255)
GRASS_MID2 = (93, 138, 78, 255)
GRASS_LIGHT = (104, 154, 94, 255)
GRASS_TIP = (120, 176, 116, 255)

# piatra pietei: intre scandurile puntii (148,135,118) si pamantul drumului (133,106,80)
STONE_LIGHT = (176, 166, 148, 255)
STONE_MID = (156, 146, 128, 255)
STONE_MID2 = (146, 136, 119, 255)
STONE_DARK = (124, 114, 99, 255)
GROUT = (98, 88, 74, 255)


def _tuft(c, x, y, rng, vertical=False):
    """Un smoc: 3-5 fire care pleaca din acelasi punct, cel din mijloc mai inalt, varfurile mai deschise."""
    blades = rng.i(3, 5)
    for k in range(blades):
        off = k - blades // 2
        height = 3 - abs(off) + rng.i(0, 1)
        for t in range(height):
            col = GRASS_DARK if t == 0 else (GRASS_MID if t < height - 1 else (GRASS_TIP if off == 0 else GRASS_LIGHT))
            if vertical:
                c.put(x + (t if off >= 0 else -t), y + off, col)
            else:
                c.put(x + off, y - t, col)


def grass_edge_h():
    c = C(64, 8)
    rng = Rng(57101)
    x = 2
    while x < 62:
        # smocuri pe doua randuri: unele urca peste pamant (jos), altele raman pe iarba (sus)
        _tuft(c, x, rng.i(4, 6), rng)
        if rng.n() < 0.45:
            c.put(x + rng.i(-1, 1), 7, GRASS_DARK)  # un fir cazut peste marginea pamantului
        x += rng.i(4, 8)
    return c


def grass_edge_v():
    c = C(8, 64)
    rng = Rng(57202)
    y = 2
    while y < 62:
        _tuft(c, rng.i(2, 4), y, rng, vertical=True)
        if rng.n() < 0.45:
            c.put(rng.i(5, 7), y + rng.i(-1, 1), GRASS_DARK)
        y += rng.i(4, 8)
    return c


def tile_plaza():
    """Pietre pe 6 randuri (64/6 ~ 10-11 px), fiecare rand cu latimi care insumeaza exact 64 si alt decalaj, ca dala sa
    se repete fara cusatura si fara sa se vada tiparul."""
    c = C(64, 64)
    rng = Rng(57303)
    c.rect(0, 0, 64, 64, GROUT)
    rows = [11, 10, 11, 11, 10, 11]
    y = 0
    for ri, rh in enumerate(rows):
        widths = []
        total = 0
        while total < 64:
            w = rng.i(10, 15)
            if 64 - total - w < 9:
                w = 64 - total
            widths.append(w)
            total += w
        shift = rng.i(0, 12)
        x = shift
        for w in widths:
            base = [STONE_MID, STONE_MID2, STONE_MID, STONE_LIGHT if rng.n() < 0.15 else STONE_MID2][rng.i(0, 3)]
            # piatra: dreptunghi cu colturile rotunjite (1 px), rost de 1 px pe dreapta si jos
            for yy in range(y, y + rh - 1):
                for xx in range(x, x + w - 1):
                    corner = (yy in (y, y + rh - 2)) and (xx in (x, x + w - 2))
                    if corner:
                        continue
                    col = base
                    if yy == y or xx == x:
                        col = STONE_LIGHT  # muchia luminata, stanga-sus
                    elif yy == y + rh - 2 or xx == x + w - 2:
                        col = STONE_DARK  # muchia din umbra, dreapta-jos
                    elif rng.n() < 0.05:
                        col = STONE_DARK  # o ciupitura
                    c.put(xx % 64, yy, col)
            x += w
        y += rh
    return c


SPRITES = {
    "tile_plaza": tile_plaza,
    "grass_edge_h": grass_edge_h,
    "grass_edge_v": grass_edge_v,
}


def main():
    force = "--force" in sys.argv
    for name in SPRITES:
        if os.path.exists(os.path.join(OUT, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name, fn in SPRITES.items():
        c = fn()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
