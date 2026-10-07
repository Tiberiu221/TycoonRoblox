#!/usr/bin/env python3
"""Arta pentru D58: butonul de inchidere al panourilor.

Owner-ul (2026-09-14), pe captura meniului Sawyer-ului: "hai sa rezolvam acel buton de X". Butonul scria "✕"
(U+2715) cu fontul de pixeli al jocului (`Arcade` = Press Start 2P), iar fontul n-are glifa asta -- nici fonturile de
rezerva din Studio (verificat pe tabelele cmap din fisierele fontului) -- deci pe ecran aparea patratelul
caracterului lipsa. Acum X-ul e desenat, ca restul trusei de interfata (ui.py): rama de lemn a butoanelor, fata
rosie, X-ul crem cu umbra lui.

  * ui_close        (20x20) -- normal
  * ui_close_hover  (20x20) -- sub maus: fata mai deschisa
  * ui_close_down   (20x20) -- apasat: fata mai inchisa, bizoul intors, X-ul coborat cu un pixel

Se deseneaza la x2 (40x40), ca ramele cu 9 felii (SliceScale 2).

Rulare: python3 scripts/art/d58.py [--force]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png  # noqa: E402
from palette import WOOD, ramp, hsv  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES
T = (0, 0, 0, 0)

# rosul semnalului "nu / inchide" (Theme.COLOR.bad 190,74,62), putin mai stins pe fata unui buton
RED = ramp(6, 0.60, 0.66)
CREAM = hsv(40, 0.14, 0.95)  # pergamentul panourilor, ca X-ul sa para din aceeasi hartie

SIZE = 20
FACE = 3  # rama: contur de 1 px + inel de lemn de 2 px


# X-ul de 8x8 cu trasaturi de 2 px, simetric pe ambele axe; se incruciseaza intr-un patrat de 2x2. O varianta cu
# randuri de 3 si 6 px la mijloc iesea o pata, nu un X (vazut pe previzualizarea marita).
X_ROWS = [
    "##....##",
    ".##..##.",
    "..####..",
    "...##...",
    "...##...",
    "..####..",
    ".##..##.",
    "##....##",
]


def x_pixels():
    """Pixelii X-ului, pe mijlocul fetei: de la (6,6) la (13,13), centrul la 9.5 ca al fetei."""
    return {(6 + col, 6 + row) for row, line in enumerate(X_ROWS) for col, ch in enumerate(line) if ch == "#"}


def close_button(state="normal"):
    if state == "hover":
        face, hi, lo = RED[3], RED[4], RED[1]
    elif state == "down":
        face, hi, lo = RED[1], RED[0], RED[2]
    else:
        face, hi, lo = RED[2], RED[3], RED[0]
    c = C(SIZE, SIZE)
    c.rect(0, 0, SIZE, SIZE, WOOD[0])
    c.rect(1, 1, SIZE - 2, SIZE - 2, WOOD[1])
    c.rect(1, 1, SIZE - 2, 1, WOOD[2])  # muchia de sus a ramei, luminata
    inner = SIZE - FACE * 2
    c.rect(FACE, FACE, inner, inner, face)
    # bizoul: apasat, lumina trece jos-dreapta si fata pare infundata
    top_left = lo if state == "down" else hi
    bottom_right = hi if state == "down" else lo
    c.rect(FACE, FACE, inner, 1, top_left)
    c.rect(FACE, FACE, 1, inner, top_left)
    c.rect(FACE, FACE + inner - 1, inner, 1, bottom_right)
    c.rect(FACE + inner - 1, FACE, 1, inner, bottom_right)
    # colturile rotunjite cu un pixel, ca la bulina si la insigna
    for x, y in ((0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)):
        c.px[y][x] = T

    drop = 1 if state == "down" else 0
    xs = {(x, y + drop) for x, y in x_pixels()}
    shadow = RED[0]
    for x, y in xs:
        if (x, y + 1) not in xs:
            c.put(x, y + 1, shadow)
    for x, y in xs:
        c.put(x, y, CREAM)
    return c


SPRITES = {
    "ui_close": lambda: close_button("normal"),
    "ui_close_hover": lambda: close_button("hover"),
    "ui_close_down": lambda: close_button("down"),
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
