#!/usr/bin/env python3
"""Cardul de capitol asa cum iese pe ecran: ilustratia ca FUNDAL, voalurile in degrade, textul peste.

Randeaza exact cutiile si culorile din TutorialController, ca sa vad contrastul si asezarea inainte
de Studio. Fontul e cel de 5x7 al previzualizarilor, nu Fredoka -- deci verific POZITIA si
CONTRASTUL, nu forma literelor.

Rulare: python3 scripts/art/preview_chapter_card.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
from preview_tycoon import load, write_png, blit_scaled, draw_text, text_width  # noqa: E402

CARD_W, CARD_H = 600, 400
SCALE = 4

# Theme.COLOR, transcrise
ON_DARK = (240, 233, 218, 255)
ON_DARK_SOFT = (196, 186, 168, 255)
GOLD = (232, 178, 60, 255)
WOOD = (112, 78, 48, 255)
PUNCH = (38, 26, 18, 255)

# (text, x, y, scala_font, culoare) -- y e coltul de sus al etichetei, ca in Luau
LINES = [
    ("Chapter 1 - The Landing", 26, 20, 4, ON_DARK),
    ("This stretch of river is yours.", 26, 78, 3, ON_DARK),
    ("Everything that floats past is money.", 26, 112, 2, ON_DARK_SOFT),
]
HINT = ("Tap anywhere to continue", 2, GOLD)


def scrim(c, from_top, frac, stops):
    h = int(CARD_H * frac)
    for i in range(h):
        t = i / max(1, h - 1)
        # interpolare liniara intre punctele de transparenta, ca la UIGradient
        a = None
        for (p0, v0), (p1, v1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                a = v0 + (v1 - v0) * ((t - p0) / max(1e-6, p1 - p0))
                break
        if a is None:
            a = stops[-1][1]
        y = i if from_top else CARD_H - 1 - i
        c.rect(0, y, CARD_W, 1, (0, 0, 0, int(round((1 - a) * 255))))


def main():
    sw, sh, px = load("chapter_landing")
    assert (sw * SCALE, sh * SCALE) == (CARD_W, CARD_H), f"ilustratia e {sw}x{sh}, nu {CARD_W//SCALE}x{CARD_H//SCALE}"
    c = C(CARD_W, CARD_H)
    blit_scaled(c, sw, sh, px, 0, 0, SCALE)

    scrim(c, True, 0.44, [(0, 0.30), (0.55, 0.66), (1, 1.0)])
    scrim(c, False, 0.24, [(0, 1.0), (0.45, 0.70), (1, 0.28)])

    for text, x, y, fs, col in LINES:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx or dy:
                    draw_text(c, x + dx, y + dy, text, PUNCH, fs)
        draw_text(c, x, y, text, col, fs)
    c.rect(28, 62, 88, 3, GOLD)

    text, fs, col = HINT
    hx = (CARD_W - text_width(text, fs)) // 2
    hy = CARD_H - 18 - 24
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                draw_text(c, hx + dx, hy + dy, text, PUNCH, fs)
    draw_text(c, hx, hy, text, col, fs)

    for i in range(3):  # chenarul de lemn
        c.rect(i, 0, 1, CARD_H, WOOD)
        c.rect(CARD_W - 1 - i, 0, 1, CARD_H, WOOD)
        c.rect(0, i, CARD_W, 1, WOOD)
        c.rect(0, CARD_H - 1 - i, CARD_W, 1, WOOD)

    out = "/tmp/chapter_card.png"
    write_png(out, CARD_W, CARD_H, c.px)
    print(f"{out}  {CARD_W}x{CARD_H}")


if __name__ == "__main__":
    main()
