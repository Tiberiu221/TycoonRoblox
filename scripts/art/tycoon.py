#!/usr/bin/env python3
"""Sprite-urile F1: bunurile plutitoare (goods_*) si recuzita Erei 1 (prop_pier/bell/sack/stall).

Acelasi pipeline ca buildings.py/world.py -- nu unul nou: rampe cu deplasare de nuanta din
palette.ramp(), umbra moale + conturul de baza din world.py (soft_shadow, outline_bottom),
aceeasi vedere de sus la 3/4. Cateva rampe noi (bronz, rugina, ceramica+smalt, panza de sac,
copertina) construite cu aceeasi functie palette.ramp(), pentru materiale care nu existau inca.

Rulare: python3 scripts/art/tycoon.py   (apoi preview_tycoon.py pentru foaia de comparatie)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, STONE, FOAM, LEAF_WARM, ramp, hsv  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES

# Rampe noi, aceeasi reteta (palette.ramp): material care nu exista inca in palette.py.
RUST = ramp(hue=18, sat=0.55, val=0.40, steps=5, hue_shift=9, val_span=0.40)     # scrap ruginit
BRONZE = ramp(hue=32, sat=0.50, val=0.48, steps=5, hue_shift=8, val_span=0.36)   # clopotul
CERAMIC = ramp(hue=36, sat=0.12, val=0.90, steps=5, hue_shift=6, val_span=0.18)  # cioburi de lut ars
GLAZE = ramp(hue=205, sat=0.55, val=0.50, steps=5, hue_shift=10, val_span=0.36)  # smalt pictat
BURLAP = ramp(hue=36, sat=0.30, val=0.50, steps=5, hue_shift=8, val_span=0.38)   # sacul de panza
AWNING = ramp(hue=6, sat=0.55, val=0.52, steps=5, hue_shift=6, val_span=0.32)    # copertina, dungi
CREAM = ramp(hue=42, sat=0.18, val=0.88, steps=5, hue_shift=6, val_span=0.20)    # copertina, dungi


def ripple(c, cx, cy, half_w):
    """Doua scanteieri scurte de spuma sub obiect: semnul ca pluteste pe apa, nu sta pe pamant.
    La fel ca foam_strip din world.py, dar redusa la doua bucati -- atat cat incape la 24x18."""
    for side in (-1, 1):
        x0 = cx + side * int(half_w * 0.55)
        c.put(x0, cy, FOAM[3])
        c.put(x0 + side, cy, FOAM[2])
        c.put(x0, cy + 1, FOAM[2])


# --------------------------------------------------------------- bunuri plutitoare (~24x18)
def goods_reeds():
    """Snop de papura: tulpini subtiri in evantai dintr-un punct legat la baza, nu o pata verde --
    prima varianta avea o banda de lemn care parea un par infipt in iarba, in loc de o legatura."""
    c = C(24, 18)
    soft_shadow(c, 12, 14, 8, 3)
    ripple(c, 12, 15, 14)
    base = (12, 16)
    tips = ((2, 4), (6, 1), (12, 0), (18, 2), (21, 5))
    tones = (LEAF_WARM[1], LEAF_WARM[2], LEAF_WARM[3], LEAF_WARM[2], LEAF_WARM[1])
    for (tx, ty), tone in zip(tips, tones):
        steps = max(1, abs(tx - base[0]), abs(base[1] - ty))
        for k in range(steps + 1):
            t = k / steps
            x = base[0] + (tx - base[0]) * t
            y = base[1] + (ty - base[1]) * t
            c.put(x, y, tone)
            if k < steps:
                c.put(x, y + 1, LEAF_WARM[0])  # umbra tulpinii, sub linia principala
    c.rect(7, 13, 10, 3, WOOD[1])  # legatura, peste baza tulpinilor
    c.rect(7, 13, 10, 1, WOOD[3])
    c.rect(7, 15, 10, 1, WOOD[0])
    c.put(12, 0, LEAF_WARM[4])  # varf luminat
    outline_bottom(c, 0, 0, 24, 18)
    return c


def goods_scrap():
    """Doua placi de tabla indoite, cu pete de rugina si un nit -- silueta unghiulara, nu rotunda,
    ca sa nu se confunde cu papura sau cioburile la 3x."""
    c = C(24, 18)
    soft_shadow(c, 12, 14, 8, 3)
    ripple(c, 12, 15, 14)
    for i in range(8):  # placa mare, indoita in trepte (aceeasi tehnica ca tri_roof)
        w = 14 - i
        c.rect(4 + i // 2, 4 + i, w, 2, STONE[1] if i % 2 == 0 else STONE[2])
    c.rect(4, 4, 11, 1, STONE[3])
    c.rect(5, 11, 9, 1, STONE[0])
    c.rect(13, 8, 7, 6, STONE[0])  # placa mica, in umbra, in spate
    c.rect(13, 8, 7, 1, STONE[2])
    c.rect(19, 8, 1, 6, STONE[0])
    rng = Rng(606)
    for _ in range(6):
        x, y = rng.i(5, 18), rng.i(5, 13)
        if c.px[y][x][3]:
            c.put(x, y, RUST[2] if rng.n() < 0.6 else RUST[1])
    c.put(9, 7, STONE[3])  # nit
    c.put(10, 7, STONE[4])
    outline_bottom(c, 0, 0, 24, 18)
    return c


def goods_shards():
    """Trei cioburi de lut smaltuit, unghiulare, cu tonuri departate pe rampa ca sa nu se topeasca
    intr-o singura pata (prima varianta, cu tonuri apropiate si margini rotunjite, arata ca un nor).
    Cel mai rar bun (4%, kiln -> ceramica): trebuie sa iasa in evidenta printre celelalte bunuri."""
    c = C(24, 18)
    soft_shadow(c, 12, 14, 8, 3)
    ripple(c, 12, 15, 14)

    def wedge(x0, y0, w0, rows, shrink_right, tone, edge):
        """Dreptunghi taperat intr-o pana: shrink_right True ingusteaza din dreapta, altfel stanga."""
        for i in range(rows):
            w = max(1, w0 - i)
            x = x0 if shrink_right else x0 + (w0 - w)
            c.rect(x, y0 + i, w, 1, tone)
        c.rect(x0 if shrink_right else x0 + 1, y0, w0 - (0 if shrink_right else 1), 1, edge)

    wedge(2, 4, 9, 8, True, CERAMIC[1], CERAMIC[3])  # ciobul din spate, cel mai mare
    wedge(8, 9, 8, 6, False, CERAMIC[0], CERAMIC[2])  # ciobul din umbra, jos
    wedge(13, 3, 7, 7, True, CERAMIC[3], CERAMIC[4])  # ciobul din fata, cel mai deschis

    c.rect(3, 8, 4, 1, GLAZE[2])  # accent de smalt, pe ciobul din spate
    c.rect(14, 6, 4, 1, GLAZE[3])  # accent, pe ciobul din fata
    c.put(16, 5, hsv(40, 0.05, 1.0))  # sclipire de raritate
    c.put(17, 5, GLAZE[4])
    outline_bottom(c, 0, 0, 24, 18)
    return c


# --------------------------------------------------------------- recuzita Erei 1
def prop_pier():
    """Debarcader de lemn care intra spre nord in apa: scanduri transversale intre doua lonjeroane,
    trei perechi de stalpi care ies in lateral, cu o scanteiere de apa la baza fiecaruia. Capatul de
    sus ramane deschis (fara contur) -- doar capatul de la mal e "la pamant"."""
    c = C(64, 40)
    dx, dw = 20, 24
    top, bot = 3, 35
    for i, py in enumerate((7, 16, 25)):  # stalpii, desenati primii (baza sub punte)
        for side in (dx - 3, dx + dw):
            c.rect(side, py, 3, 7, WOOD[1])
            c.rect(side, py, 1, 7, WOOD[2])
            c.rect(side, py + 6, 3, 1, WOOD[0])
            c.ellipse(side + 1, py + 8, 3, 1.3, FOAM[3])
            c.ellipse(side + 1, py + 8, 1.6, 0.7, FOAM[2])
    c.rect(dx - 1, top, 2, bot - top, WOOD[3])  # lonjeron stanga, luminat
    c.rect(dx + dw - 1, top, 2, bot - top, WOOD[0])  # lonjeron dreapta, in umbra
    for i, y in enumerate(range(top + 1, bot, 3)):  # scandurile transversale
        c.rect(dx + 1, y, dw - 2, 2, WOOD[2] if i % 2 == 0 else WOOD[1])
        c.rect(dx + 1, y, dw - 2, 1, WOOD[3] if i % 2 == 0 else WOOD[2])
    c.rect(dx, top - 1, dw, 1, WOOD[4])  # capatul de nord, deschis spre apa
    soft_shadow(c, dx + dw / 2, bot + 1, dw / 2 + 3, 3)
    outline_bottom(c, 0, 0, 64, 40)
    return c


def prop_bell():
    """Rama de lemn cu picioare evazate si contravantuire in X, clopot de bronz atarnat la mijloc
    cu limba si o sclipire -- Landing Bell (N2), tinta ceremoniei de final de era."""
    c = C(40, 56)
    soft_shadow(c, 20, 53, 13, 3)
    for px, foot in ((6, -3), (30, 3)):  # doi stalpi, cu picior evazat la baza
        c.rect(px, 10, 4, 35, WOOD[1])
        c.rect(px, 10, 1, 35, WOOD[3])
        c.rect(px + 3, 10, 1, 35, WOOD[0])
        c.rect(px + foot, 42, 4, 4, WOOD[0])
        c.rect(px + foot, 42, 4, 1, WOOD[2])
    for i in range(18):  # contravantuire in X, intre stalpi, in spatele clopotului
        c.put(10 + i, 40 - i, WOOD[0])
        c.put(29 - i, 40 - i, WOOD[0])
    c.rect(3, 6, 34, 6, WOOD[2])  # grinda de sus
    c.rect(3, 6, 34, 1, WOOD[4])
    c.rect(3, 11, 34, 1, WOOD[0])
    c.rect(18, 12, 4, 4, STONE[0])  # bratara de prindere
    c.ellipse(20, 23, 9, 10, BRONZE[1])  # corpul clopotului
    c.ellipse(17, 19, 5, 5, BRONZE[3])
    c.ellipse(20, 31, 11, 3, BRONZE[0])  # buza evazata
    c.ellipse(20, 30, 9, 2, BRONZE[2])
    c.rect(19, 32, 2, 5, BRONZE[0])  # tija limbii
    c.ellipse(20, 39, 2.4, 2.4, BRONZE[1])  # limba
    c.put(16, 16, BRONZE[4])
    c.put(17, 17, BRONZE[4])
    outline_bottom(c, 0, 0, 40, 56)
    return c


def prop_sack():
    """Sac de panza groasa, legat la gat cu franghie -- Bigger Sack (N1). Prima varianta avea gatul
    la fel de lat ca burta si un nod mare: arata ca o creatura pufoasa, nu ca un sac. Acum burta e
    rotunda, dar gatul se ingusteaza in trepte spre un nod mic, ca la draw_vessel din items.py."""
    c = C(24, 24)
    soft_shadow(c, 12, 21, 8, 3)
    c.ellipse(12, 16, 8, 6, BURLAP[1])  # burta, lata si joasa
    c.ellipse(9, 14, 4, 4, BURLAP[2])
    c.ellipse(8, 13, 2, 2, BURLAP[3])  # lumina din stanga-sus
    c.ellipse(15, 19, 4, 3, BURLAP[0])  # umbra din dreapta-jos
    for i in range(8):  # gatul, taperat -- ingust sus, larg jos, spre burta
        y = 12 - i
        w = max(2, 7 - i // 2)
        x = 12 - w // 2
        c.rect(x, y, w, 1, BURLAP[3] if i % 3 == 0 else BURLAP[2])
    for k in range(2):  # doua ture de franghie, peste gatul ingustat
        y = 8 + k * 2
        w = max(2, 7 - (12 - y) // 2)
        c.rect(12 - w // 2, y, w, 1, WOOD[1] if k else WOOD[0])
    c.ellipse(12, 4, 3, 2, WOOD[0])  # nodul, mic
    c.put(11, 3, WOOD[2])
    rng = Rng(4242)
    for _ in range(7):  # tesatura de sac, cateva fire, doar pe burta
        x, y = rng.i(6, 18), rng.i(13, 20)
        if c.px[y][x][3]:
            c.put(x, y, BURLAP[0] if rng.n() < 0.5 else BURLAP[3])
    outline_bottom(c, 0, 0, 24, 24)
    return c


def prop_stall():
    """Taraba de piata: doi stalpi, copertina in dungi (rosu-crem, ca ROOF_RED de la cottage/hall),
    tejghea de lemn cu o lada mica -- Dock Stall (N1)."""
    c = C(48, 40)
    soft_shadow(c, 24, 37, 19, 3)
    for px in (5, 39):  # stalpii
        c.rect(px, 14, 3, 21, WOOD[1])
        c.rect(px, 14, 1, 21, WOOD[3])
        c.rect(px + 2, 14, 1, 21, WOOD[0])
    c.rect(2, 29, 44, 7, WOOD[2])  # tejgheaua
    c.rect(2, 29, 44, 1, WOOD[4])
    c.rect(2, 35, 44, 1, WOOD[0])
    for x in range(4, 46, 7):  # cusaturile scandurilor
        c.rect(x, 30, 1, 5, WOOD[0])
    for i in range(9):  # copertina: taperata ca tri_roof, dar cu dungi VERTICALE pe fata inclinata
        y, w, x0 = 6 + i, 44 - i * 2, 2 + i
        for k in range(w):
            band = ((x0 + k) // 5) % 2
            c.put(x0 + k, y, AWNING[2] if band == 0 else CREAM[2])
    c.rect(2, 6, 44, 1, AWNING[3])  # creasta luminata
    c.rect(2, 14, 44, 1, AWNING[0])  # strasina in umbra
    for i, x in enumerate(range(3, 45, 6)):  # tivul zimtat
        col = AWNING[1] if i % 2 == 0 else CREAM[1]
        c.rect(x, 15, 5, 2, col)
        c.put(x + 2, 17, col)
    c.rect(28, 23, 9, 6, WOOD[1])  # o lada pe tejghea
    c.rect(28, 23, 9, 1, WOOD[3])
    c.rect(32, 23, 1, 6, WOOD[0])
    outline_bottom(c, 0, 0, 48, 40)
    return c


SPRITES = {
    "goods_reeds": goods_reeds,
    "goods_scrap": goods_scrap,
    "goods_shards": goods_shards,
    "prop_pier": prop_pier,
    "prop_bell": prop_bell,
    "prop_sack": prop_sack,
    "prop_stall": prop_stall,
}


def main():
    for name, fn in SPRITES.items():
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            raise SystemExit(f"refuz sa suprascriu {path} -- fisier existent")
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
        print(f"{name}.png: {img.w}x{img.h}")


if __name__ == "__main__":
    main()
