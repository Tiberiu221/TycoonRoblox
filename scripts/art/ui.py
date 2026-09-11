#!/usr/bin/env python3
"""Trusa de interfata: rame cu 9 felii, butoane in 3 stari, pictograme.

De ce sprite-uri si nu `Frame` + `UICorner`: un dreptunghi gri cu colturi rotunjite arata la fel
in orice joc si nu are nicio legatura cu lumea desenata. O rama de lemn cu pergament in interior
apartine aceleiasi lumi ca si cladirile, si asta e diferenta dintre "interfata generica" si
"interfata acestui joc".

Cele 9 felii: coltul se deseneaza o data, marginea se intinde, mijlocul se umple. In Roblox se
foloseste ImageLabel cu ScaleType = Slice si SliceCenter.

Rulare: python3 scripts/art/ui.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png, Rng  # noqa: E402
from palette import WOOD, SAND, STONE, GRASS, WATER, OUTLINE, mix, shade, hsv  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

PARCHMENT = hsv(40, 0.16, 0.93)
PARCHMENT_D = hsv(38, 0.22, 0.84)
PARCHMENT_L = hsv(44, 0.10, 0.98)
INK = hsv(26, 0.45, 0.20)


def frame9(size=24, border=8, fill=PARCHMENT, wood=None, grain=True):
    """Rama de lemn cu interior de pergament. `border` = latimea feliei de colt."""
    wood = wood or WOOD
    c = C(size, size)
    c.rect(0, 0, size, size, wood[1])
    c.rect(1, 1, size - 2, size - 2, wood[2])          # fata scandurii
    c.rect(0, 0, size, 1, wood[3])                      # muchia de sus, luminata
    c.rect(0, 0, 1, size, wood[3])
    c.rect(0, size - 1, size, 1, wood[0])               # muchia de jos, in umbra
    c.rect(size - 1, 0, 1, size, wood[0])
    c.rect(0, 0, size, 1, mix(wood[3], PARCHMENT_L, 0.35))

    inner = border - 2
    c.rect(inner, inner, size - inner * 2, size - inner * 2, wood[0])   # santul dintre rama si fata
    c.rect(inner + 1, inner + 1, size - (inner + 1) * 2, size - (inner + 1) * 2, fill)
    c.rect(inner + 1, inner + 1, size - (inner + 1) * 2, 1, PARCHMENT_L)
    c.rect(inner + 1, size - inner - 2, size - (inner + 1) * 2, 1, PARCHMENT_D)

    if grain:
        rng = Rng(9001)
        for _ in range(size * 2):
            x, y = rng.i(1, size - 2), rng.i(1, size - 2)
            if inner <= x < size - inner and inner <= y < size - inner:
                continue
            c.put(x, y, wood[1] if rng.n() < 0.5 else wood[3])
    # colturi: cuie de fier, semnal ca rama e un obiect, nu un chenar
    for cx, cy in ((2, 2), (size - 4, 2), (2, size - 4), (size - 4, size - 4)):
        c.rect(cx, cy, 2, 2, STONE[2])
        c.put(cx, cy, STONE[3])
        c.put(cx + 1, cy + 1, STONE[0])
    return c


def button9(state="normal", size=20, border=7):
    """Buton in 3 stari. Diferenta se citeste din bizou, nu doar din culoare: la apasare
    muchia luminata trece sus-in-jos, ca butonul sa para infundat."""
    if state == "hover":
        face, edge_hi, edge_lo = SAND[3], SAND[4], SAND[1]
    elif state == "down":
        face, edge_hi, edge_lo = SAND[1], SAND[0], SAND[3]
    else:
        face, edge_hi, edge_lo = SAND[2], SAND[4], SAND[0]

    c = C(size, size)
    c.rect(0, 0, size, size, WOOD[0])
    c.rect(1, 1, size - 2, size - 2, WOOD[1])
    inner = border - 3
    c.rect(inner, inner, size - inner * 2, size - inner * 2, face)
    if state == "down":
        c.rect(inner, inner, size - inner * 2, 1, edge_lo)
        c.rect(inner, inner, 1, size - inner * 2, edge_lo)
        c.rect(inner, size - inner - 1, size - inner * 2, 1, edge_hi)
    else:
        c.rect(inner, inner, size - inner * 2, 1, edge_hi)
        c.rect(inner, inner, 1, size - inner * 2, edge_hi)
        c.rect(inner, size - inner - 1, size - inner * 2, 1, edge_lo)
        c.rect(size - inner - 1, inner, 1, size - inner * 2, edge_lo)
    return c


def slot9(size=16, border=6):
    """Casuta scobita, pentru liste si campuri: interiorul e mai inchis decat fundalul."""
    c = C(size, size)
    c.rect(0, 0, size, size, mix(PARCHMENT_D, INK, 0.30))
    inner = border - 4
    c.rect(inner, inner, size - inner * 2, size - inner * 2, mix(PARCHMENT_D, INK, 0.12))
    c.rect(inner, inner, size - inner * 2, 1, mix(PARCHMENT_D, INK, 0.40))
    c.rect(inner, inner, 1, size - inner * 2, mix(PARCHMENT_D, INK, 0.40))
    c.rect(inner, size - inner - 1, size - inner * 2, 1, PARCHMENT_L)
    return c


def ribbon9(size=20, border=7, color=None):
    """Banderola pentru titluri si obiective: capete taiate in unghi, corp colorat."""
    color = color or (hsv(14, 0.55, 0.62), hsv(14, 0.55, 0.74), hsv(14, 0.45, 0.86))
    c = C(size, size)
    c.rect(0, 0, size, size, color[0])
    c.rect(0, 1, size, size - 3, color[1])
    c.rect(0, 1, size, 1, color[2])
    c.rect(0, size - 2, size, 2, shade(color[0], -0.10))
    return c


# ------------------------------------------------------------------ pictograme
def icon(draw):
    c = C(16, 16)
    draw(c)
    return c


def _icon_materials(c):
    c.rect(2, 8, 12, 6, WOOD[1])
    c.rect(2, 8, 12, 1, WOOD[3])
    c.rect(2, 13, 12, 1, WOOD[0])
    c.rect(4, 4, 8, 4, WOOD[2])
    c.rect(4, 4, 8, 1, WOOD[4])
    c.rect(7, 4, 2, 10, WOOD[0])


def _icon_people(c):
    c.ellipse(5, 5, 2.5, 2.5, SAND[4])
    c.rect(2, 8, 7, 6, WATER[3])
    c.rect(2, 8, 2, 6, WATER[4])
    c.ellipse(11, 6, 2, 2, SAND[3])
    c.rect(9, 9, 5, 5, WATER[2])


def _icon_bed(c):
    c.rect(1, 6, 14, 7, WOOD[1])
    c.rect(1, 6, 14, 1, WOOD[3])
    c.rect(1, 12, 14, 2, WOOD[0])
    c.rect(2, 7, 5, 4, PARCHMENT_L)
    c.rect(7, 7, 7, 4, hsv(150, 0.35, 0.55))
    c.rect(1, 4, 2, 9, WOOD[2])
    c.rect(13, 4, 2, 9, WOOD[2])


def _icon_food(c):
    c.ellipse(8, 9, 6, 4, WOOD[1])
    c.ellipse(8, 8, 5, 3, hsv(30, 0.45, 0.80))
    c.ellipse(8, 7, 4, 2, hsv(38, 0.50, 0.92))
    c.rect(2, 11, 12, 2, WOOD[0])
    c.rect(7, 1, 2, 4, STONE[2])


def _icon_rest(c):
    for k, (x, y, w) in enumerate(((3, 10, 4), (6, 6, 5), (9, 2, 6))):
        col = hsv(205, 0.20, 0.95 - k * 0.05)
        c.rect(x, y, w, 1, col)
        c.put(x + w // 2, y + 1, col)
        c.rect(x, y + 2, w, 1, col)


def _icon_joy(c):
    c.ellipse(8, 8, 6, 6, hsv(48, 0.60, 0.95))
    c.ellipse(8, 8, 5, 5, hsv(45, 0.45, 1.0))
    c.rect(5, 6, 2, 2, INK)
    c.rect(9, 6, 2, 2, INK)
    c.rect(5, 10, 6, 1, INK)
    c.put(4, 9, INK)
    c.put(11, 9, INK)


def _icon_hammer(c):
    c.rect(6, 8, 3, 7, WOOD[1])
    c.rect(6, 8, 1, 7, WOOD[3])
    c.rect(3, 3, 10, 5, STONE[2])
    c.rect(3, 3, 10, 1, STONE[3])
    c.rect(3, 7, 10, 1, STONE[0])


def _icon_fish(c):
    c.ellipse(7, 8, 5, 3.5, WATER[3])
    c.ellipse(6, 7, 4, 2.5, WATER[4])
    c.put(4, 7, INK)
    for k in range(4):
        c.rect(12, 5 + k, 3 - abs(k - 1), 1, WATER[2])
    c.rect(12, 8, 3, 1, WATER[2])


def _icon_build(c):
    c.rect(2, 7, 12, 7, SAND[2])
    c.rect(2, 7, 12, 1, SAND[4])
    for i in range(7):
        inset = i
        c.rect(1 + inset, 6 - i, 14 - inset * 2, 1, hsv(8, 0.50, 0.60 + i * 0.02))
    c.rect(6, 10, 4, 4, WOOD[1])


def _icon_colony(c):
    c.rect(1, 9, 5, 5, SAND[2])
    c.rect(1, 8, 5, 1, hsv(8, 0.50, 0.62))
    c.rect(6, 6, 6, 8, SAND[3])
    c.rect(6, 5, 6, 1, hsv(8, 0.50, 0.62))
    c.rect(12, 10, 3, 4, SAND[2])
    c.rect(8, 9, 2, 3, WOOD[1])


def _icon_net(c):
    c.rect(2, 3, 12, 2, WOOD[2])
    for x in range(3, 14, 3):
        for k in range(9):
            c.put(x, 5 + k, PARCHMENT_L)
    for y in range(6, 14, 3):
        c.rect(3, y, 11, 1, PARCHMENT_L)
    c.rect(2, 3, 12, 1, WOOD[3])


def _icon_crate(c):
    c.rect(2, 4, 12, 10, WOOD[1])
    c.rect(2, 4, 12, 1, WOOD[3])
    c.rect(2, 13, 12, 1, WOOD[0])
    c.rect(2, 8, 12, 1, WOOD[0])
    c.rect(7, 4, 2, 10, WOOD[2])


def _icon_check(c):
    for k in range(4):
        c.rect(3 + k, 8 + k, 2, 2, hsv(140, 0.55, 0.70))
    for k in range(7):
        c.rect(6 + k, 11 - k, 2, 2, hsv(140, 0.55, 0.70))


def _icon_arrow(c):
    for k in range(6):
        c.rect(8 - k, 3 + k, k * 2 + 1, 1, hsv(45, 0.70, 0.98))
    c.rect(6, 9, 5, 5, hsv(45, 0.70, 0.98))
    c.rect(6, 9, 5, 1, hsv(48, 0.40, 1.0))


def _icon_clock(c):
    c.ellipse(8, 8, 6.5, 6.5, STONE[1])
    c.ellipse(8, 8, 5.5, 5.5, PARCHMENT)
    c.rect(7, 4, 2, 5, INK)
    c.rect(8, 8, 4, 2, INK)


ICONS = {
    "icon_materials": _icon_materials,
    "icon_people": _icon_people,
    "icon_bed": _icon_bed,
    "icon_food": _icon_food,
    "icon_rest": _icon_rest,
    "icon_joy": _icon_joy,
    "icon_hammer": _icon_hammer,
    "icon_fish": _icon_fish,
    "icon_build": _icon_build,
    "icon_colony": _icon_colony,
    "icon_net": _icon_net,
    "icon_crate": _icon_crate,
    "icon_check": _icon_check,
    "icon_arrow": _icon_arrow,
    "icon_clock": _icon_clock,
}

SHEETS = {
    "ui_panel": lambda: frame9(),
    "ui_button": lambda: button9("normal"),
    "ui_button_hover": lambda: button9("hover"),
    "ui_button_down": lambda: button9("down"),
    "ui_slot": lambda: slot9(),
    "ui_ribbon": lambda: ribbon9(),
}


def main():
    for name, fn in SHEETS.items():
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
    for name, draw in ICONS.items():
        img = icon(draw)
        png(f"{name}.png", img.w, img.h, img.px)
    print(f"{len(SHEETS)} rame + {len(ICONS)} pictograme scrise in {OUT}")


if __name__ == "__main__":
    main()
