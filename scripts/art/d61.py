#!/usr/bin/env python3
"""Arta pentru D61 (partea 1): iazul de concurs, gheretele de joc, mesele cu muzicantii.

Owner-ul (2026-09-17) a ales "Iazul si jocurile"; machetele d61_iaz / d61_jocuri / d61_mese au fost aprobate odata cu
planul. Ce desenez aici:

  * prop_fair_pond_board (60x52) -- tabla concursului, pe malul de nord al iazului: scanduri, cap albastru cu un peste,
    hartie curata (clasamentul il scrie jocul, ca pe scena), stalpi in stuf
  * prop_fair_performer / prop_fair_performer_b (18x30) -- scripcarul, doua cadre (arcusul sus / jos)
  * prop_fair_musician / prop_fair_musician_b (20x30) -- tobosarul, doua cadre (bata sus / pe toba)
  * ui_booth_bottle (10x24) / ui_booth_ring (14x6) / ui_booth_duck (12x10) -- piesele celor doua jocuri de gheretă
  * ui_wave_hand (9x10) -- mana de deasupra celui care face cu mana
  * ui_music_note (6x8) -- notele care se ridica deasupra muzicantilor

Cadrele muzicantilor sunt imagini separate, cu aceeasi marime: asa cutia din FairLayout ramane cea a unui om, nu a
unei foi cu doua cadre (testul de asezare ar fi vazut doi muzicanti suprapusi).

Aceleasi reguli ca d60.py: compunere "over", conturul trasat prin vecinatate, muchia de sus mai deschisa.
Rulare: python3 scripts/art/d61.py [--force] [nume ...]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png  # noqa: E402
from d60 import CLOTH_BLUE, CLOTH_GREEN, CLOTH_RED, CREAM, OUT, WOOD, WOOD_D, planks_h, rim  # noqa: E402
from palette import hsv, mix  # noqa: E402
from tycoon_e1 import outline_trace  # noqa: E402

OUT_DIR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
SKIN = hsv(28, 0.40, 0.88)
SKIN_D = hsv(24, 0.46, 0.72)
GOLD = hsv(44, 0.70, 0.90)
GOLD_D = hsv(38, 0.74, 0.70)
GLASS_G = hsv(146, 0.46, 0.56)
GLASS_GD = hsv(150, 0.52, 0.40)
DUCK = hsv(48, 0.76, 0.98)
DUCK_D = hsv(40, 0.80, 0.82)
BEAK = hsv(24, 0.84, 0.94)


def line(c, x0, y0, x1, y1, col):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for k in range(n + 1):
        t = k / max(1, n)
        c.put(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), col)


# ---- iazul -------------------------------------------------------------------------------------------------------
def pond_board(w=60, h=52):
    """Tabla concursului: doi stalpi in stuf, scanduri, capul albastru cu pestele, hartia pe care scrie jocul."""
    c = C(w, h)
    for x in (7, w - 10):
        c.rect(x, 30, 3, h - 30, WOOD_D[2])
        c.rect(x, 30, 1, h - 30, WOOD_D[3])
        c.rect(x - 1, h - 2, 5, 2, WOOD_D[1])
    planks_h(c, 1, 5, w - 2, 30, WOOD, step=5, seed=61)
    c.rect(1, 5, w - 2, 1, WOOD[4])
    c.rect(4, 8, w - 8, 6, CLOTH_BLUE[3])  # capul tablei
    c.rect(4, 13, w - 8, 1, CLOTH_BLUE[1])
    for i in range(4, w - 4, 6):  # valuri mici pe cap
        c.rect(i, 10, 3, 1, CLOTH_BLUE[4])
    c.rect(4, 14, w - 8, 18, CREAM[3])  # hartia
    c.rect(4, 14, w - 8, 1, CREAM[4])
    c.rect(4, 31, w - 8, 1, CREAM[1])
    # pestele cioplit de deasupra: auriu, cu coada
    fx = w // 2
    c.ellipse(fx - 1, 3, 6, 2, GOLD)
    c.rect(fx + 5, 1, 2, 5, GOLD_D)
    c.put(fx - 5, 2, OUT)
    c.rect(fx - 3, 4, 5, 1, GOLD_D)
    # stufurile de la baza stalpilor
    for x0, heights in ((3, (9, 12, 7)), (w - 14, (8, 11, 10))):
        for k, hh in enumerate(heights):
            x = x0 + k * 2 + (1 if k == 1 else 0)
            c.rect(x, h - hh, 1, hh, CLOTH_GREEN[2 + k % 2])
            c.rect(x, h - hh, 1, 2, CLOTH_GREEN[4])
    outline_trace(c)
    rim(c, 0.2)
    return c


# ---- muzicantii --------------------------------------------------------------------------------------------------
def _musician_body(c, cx, coat, top=10):
    """Picioare, haina, cingatoare, cap: partea comuna a celor doi muzicanti."""
    c.rect(cx - 3, 23, 3, 7, WOOD_D[2])
    c.rect(cx + 1, 23, 3, 7, WOOD_D[2])
    c.rect(cx - 3, 29, 3, 1, WOOD_D[1])
    c.rect(cx + 1, 29, 3, 1, WOOD_D[1])
    c.rect(cx - 4, top, 9, 14, coat[3])
    c.rect(cx - 4, top, 2, 14, coat[2])
    c.rect(cx + 3, top, 2, 14, coat[4])
    c.rect(cx - 4, top + 6, 9, 2, GOLD_D)
    c.ellipse(cx, top - 3, 3.5, 3.5, SKIN)
    c.rect(cx - 2, top - 1, 5, 1, SKIN_D)


def fiddler(bow_up=True, w=18, h=30):
    """Scripcarul: vioara la piept, pe stanga, cu gatul spre mana ridicata; arcusul o traverseaza, sus sau jos.
    Nimic nu trece peste fata (prima incercare, cu vioara sub barbie, arata ca o masca la marimea asta)."""
    c = C(w, h)
    cx = w // 2
    _musician_body(c, cx, CLOTH_RED)
    c.rect(cx - 5, 1, 11, 3, WOOD_D[2])  # palaria, cu boruri
    c.rect(cx - 3, 0, 7, 2, WOOD_D[3])
    c.rect(cx - 7, 11, 3, 6, CLOTH_RED[2])  # bratul stang
    line(c, cx - 6, 12, cx - 8, 8, WOOD_D[3])  # gatul viorii, spre mana
    c.rect(cx - 9, 7, 2, 2, SKIN)
    c.rect(cx - 6, 11, 5, 4, WOOD[4])  # corpul viorii, la piept
    c.rect(cx - 6, 14, 5, 1, WOOD[2])
    c.put(cx - 4, 12, OUT)
    c.rect(cx + 4, 11, 3, 6, CLOTH_RED[2])  # bratul drept, cu arcusul
    if bow_up:
        c.rect(cx + 6, 10, 2, 2, SKIN)
        line(c, cx + 8, 10, cx - 6, 14, CREAM[4])
    else:
        c.rect(cx + 6, 15, 2, 2, SKIN)
        line(c, cx + 8, 16, cx - 5, 11, CREAM[4])
    outline_trace(c)
    rim(c, 0.2)
    return c


def drummer(stick_up=True, w=20, h=30):
    """Tobosarul: toba la sold, pe stanga, cu curea; bata in mana dreapta, sus sau pe toba."""
    c = C(w, h)
    cx = w // 2 + 1
    _musician_body(c, cx, CLOTH_BLUE, top=11)
    c.rect(cx - 4, 3, 9, 3, CLOTH_GREEN[2])  # boneta
    c.rect(cx - 2, 2, 5, 2, CLOTH_GREEN[3])
    line(c, cx - 3, 11, cx + 3, 20, WOOD_D[3])  # cureaua tobei
    c.rect(1, 13, 8, 10, WOOD[3])  # toba
    c.rect(1, 13, 8, 2, CREAM[4])
    c.rect(1, 21, 8, 2, CREAM[2])
    for x in (2, 5, 8):
        line(c, x, 15, x - 1 if x > 2 else x, 20, mix(WOOD[3], OUT, 0.4))
    if stick_up:
        c.rect(cx + 4, 11, 3, 5, CLOTH_BLUE[2])
        c.rect(cx + 5, 9, 2, 2, SKIN)
        line(c, cx + 6, 9, cx + 8, 4, WOOD[4])
    else:
        c.rect(cx - 6, 14, 5, 3, CLOTH_BLUE[2])
        c.rect(cx - 8, 13, 2, 2, SKIN)
        line(c, cx - 8, 13, cx - 12, 13, WOOD[4])
    outline_trace(c)
    rim(c, 0.2)
    return c


# ---- gheretele ---------------------------------------------------------------------------------------------------
def bottle(w=10, h=24):
    c = C(w, h)
    c.rect(3, 2, 4, 7, GLASS_G)
    c.rect(1, 8, 8, 16, GLASS_G)
    c.rect(1, 8, 8, 1, GLASS_GD)
    c.rect(7, 9, 2, 15, GLASS_GD)
    c.rect(2, 10, 2, 12, mix(GLASS_G, (255, 255, 255), 0.45))  # luciul
    c.rect(3, 0, 4, 3, WOOD[3])  # dopul
    c.rect(2, 14, 6, 5, CREAM[3])  # eticheta
    c.rect(3, 16, 4, 1, CLOTH_RED[3])
    outline_trace(c)
    return c


def ring(w=14, h=6):
    c = C(w, h)
    for x in range(1, w - 1):
        top = 0 if 3 <= x <= w - 4 else 1
        c.put(x, top, GOLD)
        c.put(x, h - 1 - top, GOLD_D)
    for y in range(1, h - 1):
        c.put(0, y, GOLD)
        c.put(w - 1, y, GOLD_D)
    c.rect(3, 1, 3, 1, (255, 244, 210, 255))  # luciul
    return c


def duck(w=12, h=10):
    c = C(w, h)
    c.ellipse(5, 6, 5, 3, DUCK)
    c.rect(1, 8, 9, 1, DUCK_D)
    c.ellipse(8, 3, 2.5, 2.5, DUCK)
    c.rect(10, 3, 2, 2, BEAK)
    c.put(8, 2, OUT)
    c.rect(3, 5, 3, 1, (255, 250, 220, 255))  # aripa luminata
    outline_trace(c)
    return c


# ---- mesele ------------------------------------------------------------------------------------------------------
def wave_hand(w=9, h=10):
    c = C(w, h)
    for i, hh in enumerate((4, 6, 6, 5)):  # degetele, departate
        c.rect(1 + i * 2, 6 - hh, 1, hh, SKIN)
    c.rect(1, 5, 7, 4, SKIN)
    c.rect(1, 8, 7, 1, SKIN_D)
    c.rect(7, 3, 1, 3, SKIN)  # degetul mare
    outline_trace(c)
    return c


def music_note(w=6, h=8):
    c = C(w, h)
    col = (255, 232, 176, 255)
    c.rect(3, 0, 1, 6, col)
    c.rect(3, 0, 3, 1, col)
    c.rect(4, 1, 2, 1, col)
    c.ellipse(1.5, 6, 1.5, 1, col)
    return c


SPRITES = {
    "prop_fair_pond_board": pond_board,
    "prop_fair_performer": lambda: fiddler(True),
    "prop_fair_performer_b": lambda: fiddler(False),
    "prop_fair_musician": lambda: drummer(True),
    "prop_fair_musician_b": lambda: drummer(False),
    "ui_booth_bottle": bottle,
    "ui_booth_ring": ring,
    "ui_booth_duck": duck,
    "ui_wave_hand": wave_hand,
    "ui_music_note": music_note,
}


def main():
    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = only or list(SPRITES)
    for name in names:
        if os.path.exists(os.path.join(OUT_DIR, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name in names:
        c = SPRITES[name]()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
