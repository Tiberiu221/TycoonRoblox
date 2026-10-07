#!/usr/bin/env python3
"""Dale de teren si recuzita pentru lume.

Doua reguli care fac diferenta intre "generat" si "desenat":
  1. Dalele mari se leaga fara cusatura. Zgomotul e PERIODIC (sume de sinusuri cu frecvente
     intregi), nu aleator, ca marginea din dreapta sa continue exact marginea din stanga.
  2. Nimic nu pluteste. Fiecare obiect asezat pe pamant primeste o umbra eliptica moale si
     un contur inchis pe partea de jos.

Rulare: python3 scripts/art/world.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png, Rng  # noqa: E402
from palette import (  # noqa: E402
    GRASS, GRASS_DARK, WATER, WATER_DEEP, SAND, DIRT, WOOD, STONE, LEAF, LEAF_WARM,
    FOAM, OUTLINE, mix, shade, hsv,
)

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT = scratch.SPRITES


class Tile(C):
    """Panza care se infasoara: orice desen care iese pe o margine reintra pe cealalta."""

    def put(self, x, y, c):
        super().put(int(x) % self.w, int(y) % self.h, c)


def periodic(x, y, w, h, waves):
    """Zgomot periodic in [-1,1]. `waves` = [(freq_x, freq_y, faza, amplitudine), ...]"""
    total, norm = 0.0, 0.0
    for fx, fy, phase, amp in waves:
        total += amp * math.sin(2 * math.pi * (fx * x / w + fy * y / h) + phase)
        norm += abs(amp)
    return total / max(norm, 1e-6)


# --------------------------------------------------------------- iarba
def scatter(rng, w, h, count, min_dist, tries=24):
    """Puncte imprastiate cu distanta minima intre ele, cu infasurare pe margini.

    Regula din practica pixel-art: gramezile de detaliu nu au voie sa se atinga pe muchie,
    altfel apar aglomerari care citesc ca zgomot. Imprastierea uniform aleatoare face exact asta,
    deci resping candidatii prea apropiati de ceva deja pus.
    """
    pts = []
    for _ in range(count):
        for _ in range(tries):
            x, y = rng.i(0, w - 1), rng.i(0, h - 1)
            ok = True
            for px, py in pts:
                dx = min(abs(x - px), w - abs(x - px))
                dy = min(abs(y - py), h - abs(y - py))
                if dx * dx + dy * dy < min_dist * min_dist:
                    ok = False
                    break
            if ok:
                pts.append((x, y))
                break
    return pts


def patch(t, rng, cx, cy, radius, color):
    """Pata neregulata din 3-5 elipse suprapuse: o singura elipsa citeste ca desen tehnic."""
    for _ in range(rng.i(3, 5)):
        ox, oy = rng.i(-radius // 2, radius // 2), rng.i(-radius // 2, radius // 2)
        rx = radius * (0.55 + rng.n() * 0.5)
        t.ellipse(cx + ox, cy + oy, rx, rx * (0.6 + rng.n() * 0.35), color)


def grass_tile(size=128):
    """Baza plata plus fire de iarba. Textura vine din fire, NU din pete de culoare: petele mari
    citesc ca blana de leopard, iar dala repetata se vede imediat."""
    t = Tile(size, size)
    soft_dark = mix(GRASS[2], GRASS[1], 0.26)     # variatii abia perceptibile
    soft_light = mix(GRASS[2], GRASS[3], 0.22)
    for y in range(size):
        for x in range(size):
            t.px[y][x] = GRASS[2]

    rng = Rng(4711)
    for cx, cy in scatter(rng, size, size, 5, 46):
        patch(t, rng, cx, cy, rng.i(14, 22), soft_dark)
    for cx, cy in scatter(rng, size, size, 4, 46):
        patch(t, rng, cx, cy, rng.i(12, 20), soft_light)

    for x, y in scatter(rng, size, size, 300, 5):  # firele: densitatea lor da senzatia de iarba
        base = GRASS[1] if rng.n() < 0.72 else GRASS[3]
        height = rng.i(2, 4)
        lean = 1 if rng.n() < 0.5 else 0
        for k in range(height):
            t.put(x + (lean if k == height - 1 else 0), y - k, base)
    for x, y in scatter(rng, size, size, 40, 12):  # varfuri luminate, rare
        t.put(x, y, GRASS[4])
        t.put(x, y - 1, GRASS[4])
    for x, y in scatter(rng, size, size, 16, 20):  # pietricele
        t.put(x, y, STONE[2])
        t.put(x + 1, y, STONE[1])
        t.put(x, y + 1, STONE[0])
    for x, y in scatter(rng, size, size, 10, 28):  # flori
        petal = [hsv(50, 0.55, 0.95), hsv(340, 0.30, 0.95), hsv(0, 0.02, 0.97)][rng.i(0, 2)]
        t.put(x, y - 2, petal)
        t.put(x, y - 1, GRASS[1])
        t.put(x, y, GRASS[1])
    return t


# --------------------------------------------------------------- apa
def water_tile(w=128, h=64):
    """Unde ORIZONTALE, nu pete rotunde: apa curge, iar liniile dau sensul curgerii."""
    t = Tile(w, h)
    for y in range(h):
        for x in range(w):
            t.px[y][x] = WATER[2]

    rng = Rng(90210)
    dark = mix(WATER[2], WATER[1], 0.55)
    light = mix(WATER[2], WATER[3], 0.50)
    for x, y in scatter(rng, w, h, 60, 7):  # unde lungi si joase
        length, col = rng.i(6, 16), dark if rng.n() < 0.55 else light
        for k in range(length):
            t.put(x + k, y, col)
        if rng.n() < 0.6:
            for k in range(max(1, length - 4)):
                t.put(x + 2 + k, y + 1, col)
    for x, y in scatter(rng, w, h, 30, 11):  # sclipiri scurte, luminoase
        for k in range(rng.i(2, 5)):
            t.put(x + k, y, WATER[4])
    for x, y in scatter(rng, w, h, 10, 22):  # spuma rara
        for k in range(rng.i(2, 4)):
            t.put(x + k, y, FOAM[3])
    return t


def foam_strip(w=128, h=16, facing="north"):
    """Marginea alba unde apa atinge malul: banda subtire, neregulata, cu bule rare."""
    t = Tile(w, h)
    waves = [(1, 0, 0.0, 1.0), (3, 0, 1.9, 0.5), (5, 0, 0.6, 0.28), (7, 0, 2.3, 0.16)]
    for x in range(w):
        edge = periodic(x, 0, w, 1, waves)
        thickness = 2.6 + edge * 1.8
        for k in range(int(max(1, thickness))):
            y = (h - 1 - k) if facing == "north" else k
            t.px[y % h][x] = FOAM[4] if k == 0 else (FOAM[3] if k == 1 else FOAM[2])
        if abs(edge) > 0.8:
            y2 = (h - 1 - int(thickness) - 1) if facing == "north" else int(thickness) + 1
            if 0 <= y2 < h:
                t.px[y2][x] = FOAM[2]
    return t


def sand_tile(w=128, h=48):
    """Nisip: doar puncte, fara pete. Orice pata mare citeste ca murdarie."""
    t = Tile(w, h)
    for y in range(h):
        for x in range(w):
            t.px[y][x] = SAND[3]
    rng = Rng(1337)
    for cx, cy in scatter(rng, w, h, 7, 26):
        patch(t, rng, cx, cy, rng.i(7, 12), mix(SAND[3], SAND[2], 0.45))
    for x, y in scatter(rng, w, h, 150, 5):
        t.put(x, y, SAND[2] if rng.n() < 0.6 else SAND[4])
    for x, y in scatter(rng, w, h, 20, 14):
        t.put(x, y, SAND[1])
        if rng.n() < 0.4:
            t.put(x + 1, y, SAND[1])
    for x, y in scatter(rng, w, h, 7, 22):  # pietre mici la mal
        t.put(x, y, STONE[2])
        t.put(x + 1, y, STONE[1])
        t.put(x, y + 1, STONE[0])
    return t


def path_tile(size=64):
    t = Tile(size, size)
    for y in range(size):
        for x in range(size):
            t.px[y][x] = DIRT[2]
    rng = Rng(2024)
    # pete mici si putin contrastante: la scara jocului, petele mari citesc ca noroi, nu ca drum
    for cx, cy in scatter(rng, size, size, 10, 16):
        patch(t, rng, cx, cy, rng.i(3, 5), mix(DIRT[2], DIRT[1], 0.30))
    for cx, cy in scatter(rng, size, size, 9, 16):
        patch(t, rng, cx, cy, rng.i(3, 5), mix(DIRT[2], DIRT[3], 0.26))
    for x, y in scatter(rng, size, size, 220, 3):
        t.put(x, y, DIRT[1] if rng.n() < 0.55 else DIRT[3])
    for x, y in scatter(rng, size, size, 14, 12):  # pietris calcat
        t.put(x, y, STONE[2])
        t.put(x + 1, y, STONE[1])
        t.put(x, y + 1, STONE[0])
    return t


# --------------------------------------------------------------- recuzita
def soft_shadow(c, cx, cy, rx, ry):
    c.ellipse(cx, cy, rx, ry + 1, (0, 0, 0, 22))
    c.ellipse(cx, cy, rx * 0.76, ry, (0, 0, 0, 30))
    c.ellipse(cx, cy, rx * 0.48, ry * 0.8, (0, 0, 0, 36))


def outline_bottom(c, x0, y0, w, h):
    """Contur doar unde obiectul atinge pamantul: leaga silueta de sol fara sa o incercuiasca."""
    for x in range(x0, x0 + w):
        for y in range(y0 + h - 1, y0 - 1, -1):
            if c.px[y][x][3] != 0 and c.px[y][x] != OUTLINE:
                below = c.px[y + 1][x] if y + 1 < c.h else (0, 0, 0, 0)
                if below[3] == 0:
                    c.put(x, y + 1, OUTLINE)
                break


def tree_round():
    c = C(48, 64)
    soft_shadow(c, 24, 58, 15, 5)
    c.rect(21, 40, 6, 18, WOOD[1])           # trunchi
    c.rect(21, 40, 2, 18, WOOD[2])
    c.rect(26, 40, 1, 18, WOOD[0])
    c.rect(19, 56, 10, 3, WOOD[0])           # radacini
    rng = Rng(77)
    for cx, cy, r in ((24, 26, 16), (15, 32, 10), (33, 32, 10), (24, 18, 11)):
        c.ellipse(cx, cy, r, r * 0.86, LEAF[1])
    for cx, cy, r in ((22, 24, 13), (16, 30, 7), (31, 29, 8)):
        c.ellipse(cx, cy, r, r * 0.84, LEAF[2])
    for cx, cy, r in ((21, 20, 9), (28, 26, 6)):
        c.ellipse(cx, cy, r, r * 0.82, LEAF[3])
    c.ellipse(20, 17, 5, 4, LEAF[4])         # lumina din stanga-sus
    for _ in range(40):                       # textura de frunze
        x, y = rng.i(8, 40), rng.i(8, 44)
        if c.px[y][x][3] != 0:
            c.put(x, y, LEAF[0] if rng.n() < 0.5 else LEAF[4])
    outline_bottom(c, 0, 0, 48, 63)
    return c


def tree_pine():
    """Brazi din triunghiuri pline, desenate de jos in sus ca etajele de sus sa acopere marginea
    celor de jos. Varianta cu randuri alternate colorate iesea ca dungi orizontale."""
    c = C(40, 76)
    soft_shadow(c, 20, 70, 13, 4)
    c.rect(17, 58, 6, 12, WOOD[1])
    c.rect(17, 58, 2, 12, WOOD[2])
    c.rect(15, 68, 10, 3, WOOD[0])
    tiers = ((62, 18, 20), (48, 15, 18), (34, 12, 17), (22, 8, 14))  # (baza, semi-latime, inaltime)
    for base_y, half, height in reversed(tiers):
        for i in range(height):
            t = i / max(1, height - 1)
            wsp = max(1, int(half * (1 - t)))
            y = base_y - i
            c.rect(20 - wsp, y, wsp * 2, 1, LEAF[1])
            c.rect(20 - wsp, y, max(1, wsp), 1, LEAF[2])       # jumatatea dinspre lumina
            c.rect(20 - wsp + 1, y, max(1, wsp // 2), 1, LEAF[3])
        c.rect(20 - half, base_y, half * 2, 1, LEAF[0])         # marginea de jos a etajului
    c.rect(19, 14, 2, 5, LEAF[3])
    c.put(19, 13, LEAF[4])
    outline_bottom(c, 0, 0, 40, 75)
    return c


def bush():
    c = C(32, 28)
    soft_shadow(c, 16, 25, 11, 3)
    for cx, cy, r in ((16, 16, 11), (9, 19, 7), (23, 19, 7)):
        c.ellipse(cx, cy, r, r * 0.8, LEAF[1])
    c.ellipse(14, 14, 8, 6, LEAF[2])
    c.ellipse(12, 12, 4, 3, LEAF[3])
    rng = Rng(31)
    for _ in range(8):
        x, y = rng.i(6, 26), rng.i(8, 22)
        if c.px[y][x][3] != 0:
            c.put(x, y, hsv(352, 0.55, 0.86))  # bobite
    outline_bottom(c, 0, 0, 32, 27)
    return c


def rock(big=False):
    size = 32 if big else 20
    c = C(size, size)
    h = size * 0.55
    soft_shadow(c, size / 2, size - 3, size * 0.4, 3)
    c.ellipse(size / 2, size - h / 2 - 2, size * 0.38, h / 2, STONE[1])
    c.ellipse(size / 2 - 2, size - h / 2 - 4, size * 0.28, h / 2.6, STONE[2])
    c.ellipse(size / 2 - 3, size - h / 2 - 6, size * 0.15, h / 4, STONE[3])
    c.ellipse(size / 2 + 3, size - 6, size * 0.18, h / 5, STONE[0])
    outline_bottom(c, 0, 0, size, size - 1)
    return c


def stump():
    c = C(24, 20)
    soft_shadow(c, 12, 17, 9, 3)
    c.ellipse(12, 12, 8, 6, WOOD[1])
    c.rect(4, 12, 16, 5, WOOD[1])
    c.rect(4, 15, 16, 2, WOOD[0])
    c.ellipse(12, 10, 8, 5, WOOD[3])
    c.ellipse(12, 10, 5, 3, WOOD[2])
    c.ellipse(12, 10, 2, 1, WOOD[1])
    outline_bottom(c, 0, 0, 24, 19)
    return c


def log_prop():
    c = C(36, 18)
    soft_shadow(c, 18, 15, 15, 3)
    c.rect(3, 6, 30, 8, WOOD[1])
    c.rect(3, 6, 30, 2, WOOD[3])
    c.rect(3, 12, 30, 2, WOOD[0])
    c.ellipse(4, 10, 3, 4, WOOD[2])
    c.ellipse(4, 10, 1.5, 2, WOOD[1])
    c.ellipse(32, 10, 3, 4, WOOD[0])
    outline_bottom(c, 0, 0, 36, 17)
    return c


def cattails():
    """Papura de la mal: tulpini groase de 2 pixeli, altfel dispar la scara jocului."""
    c = C(28, 38)
    rng = Rng(555)
    stems = ((6, 26), (12, 34), (18, 29), (23, 22))
    for bx, height in stems:
        top = 36 - height
        for k in range(height):
            lean = int(math.sin(k / 7.0) * 2)
            c.put(bx + lean, 36 - k, LEAF_WARM[1])
            c.put(bx + lean + 1, 36 - k, LEAF_WARM[2])
        c.rect(bx - 1, top, 4, 9, WOOD[1])                       # spicul
        c.rect(bx - 1, top, 2, 9, WOOD[2])
        c.rect(bx - 1, top, 4, 2, WOOD[0])
        for k in range(9):                                        # frunza lunga
            c.put(bx + 4 + k // 3, top + 10 + k, LEAF_WARM[2])
            c.put(bx - 2 - k // 4, top + 12 + k, LEAF_WARM[1])
    return c


def fence():
    c = C(48, 28)
    soft_shadow(c, 8, 25, 5, 2)
    soft_shadow(c, 40, 25, 5, 2)
    for px in (6, 38):
        c.rect(px, 6, 5, 19, WOOD[1])
        c.rect(px, 6, 2, 19, WOOD[3])
        c.rect(px, 5, 5, 2, WOOD[2])
    for ry in (11, 18):
        c.rect(0, ry, 48, 3, WOOD[2])
        c.rect(0, ry + 2, 48, 1, WOOD[0])
    outline_bottom(c, 0, 0, 48, 27)
    return c


def barrel():
    c = C(22, 28)
    soft_shadow(c, 11, 25, 9, 3)
    c.rect(3, 6, 16, 19, WOOD[1])
    c.rect(3, 6, 4, 19, WOOD[2])
    c.rect(16, 6, 3, 19, WOOD[0])
    for by in (9, 20):
        c.rect(2, by, 18, 3, STONE[1])
        c.rect(2, by, 18, 1, STONE[3])
    c.ellipse(11, 6, 8, 3, WOOD[3])
    c.ellipse(11, 6, 6, 2, WOOD[2])
    outline_bottom(c, 0, 0, 22, 27)
    return c


def lantern():
    c = C(20, 44)
    soft_shadow(c, 10, 41, 6, 3)
    c.rect(8, 14, 4, 27, WOOD[1])
    c.rect(8, 14, 2, 27, WOOD[2])
    c.rect(5, 38, 10, 3, WOOD[0])
    c.rect(4, 6, 12, 12, STONE[0])
    c.rect(5, 7, 10, 10, hsv(40, 0.70, 0.98))
    c.rect(6, 8, 8, 8, hsv(48, 0.45, 1.0))
    c.rect(4, 3, 12, 3, STONE[1])
    c.rect(4, 3, 12, 1, STONE[3])
    outline_bottom(c, 0, 0, 20, 43)
    return c


def signpost():
    c = C(28, 36)
    soft_shadow(c, 14, 33, 7, 3)
    c.rect(12, 12, 4, 21, WOOD[1])
    c.rect(12, 12, 2, 21, WOOD[2])
    c.rect(3, 8, 22, 11, WOOD[3])
    c.rect(3, 8, 22, 2, WOOD[4])
    c.rect(3, 17, 22, 2, WOOD[1])
    for k in range(3):
        c.rect(6, 11 + k * 3, 14 - k * 3, 1, WOOD[0])
    outline_bottom(c, 0, 0, 28, 35)
    return c


def flowers():
    """Buchet de flori: petale de 3x3, altfel la scara jocului raman niste puncte."""
    c = C(26, 22)
    rng = Rng(808)
    for x, y in ((5, 17), (12, 19), (19, 16), (9, 13), (16, 12)):
        for k in range(rng.i(3, 5)):
            c.put(x, y - k, GRASS[1])
        top = y - rng.i(3, 5)
        petal = [hsv(50, 0.62, 0.97), hsv(340, 0.45, 0.95), hsv(275, 0.34, 0.93)][rng.i(0, 2)]
        c.rect(x - 1, top - 1, 3, 3, petal)
        c.put(x, top, hsv(48, 0.30, 1.0))
        c.put(x - 1, top - 1, shade(petal, -0.12))
    for x, y in ((3, 20), (22, 19)):
        for k in range(3):
            c.put(x, y - k, GRASS[0])
    return c


def boat():
    """Barca vazuta usor din lateral: coca deschisa, banca, vasla. Fara ele arata ca o pata."""
    c = C(60, 30)
    soft_shadow(c, 30, 27, 24, 4)
    for i in range(11):                                          # coca, ingustata spre baza
        inset = int(i * 1.5)
        y = 12 + i
        c.rect(5 + inset, y, 50 - inset * 2, 1, WOOD[1] if i < 8 else WOOD[0])
    c.rect(5, 10, 50, 2, WOOD[3])                                # marginea de sus, luminata
    c.rect(5, 12, 50, 1, WOOD[4])
    c.rect(11, 13, 38, 5, mix(WOOD[0], OUTLINE, 0.45))           # interiorul, in umbra
    c.rect(24, 13, 12, 2, WOOD[2])                               # banca
    c.rect(2, 9, 6, 4, WOOD[2])                                  # prova ridicata
    c.rect(52, 9, 6, 4, WOOD[2])
    for k in range(14):                                          # vasla sprijinita
        c.put(38 + k, 11 - k // 2, WOOD[3])
    c.rect(50, 3, 5, 3, WOOD[1])
    c.rect(16, 13, 9, 4, SAND[3])                                # o lada in barca
    c.rect(16, 13, 9, 1, SAND[4])
    outline_bottom(c, 0, 0, 60, 29)
    return c


TILES = {
    "grass_tile": grass_tile,
    "water_tile": water_tile,
    "sand_tile": sand_tile,
    "path_tile": path_tile,
    "foam_north": lambda: foam_strip(facing="north"),
    "foam_south": lambda: foam_strip(facing="south"),
}

PROPS = {
    "prop_tree_round": tree_round,
    "prop_tree_pine": tree_pine,
    "prop_bush": bush,
    "prop_rock_small": lambda: rock(False),
    "prop_rock_large": lambda: rock(True),
    "prop_stump": stump,
    "prop_log": log_prop,
    "prop_cattails": cattails,
    "prop_fence": fence,
    "prop_barrel": barrel,
    "prop_lantern": lantern,
    "prop_signpost": signpost,
    "prop_flowers": flowers,
    "prop_boat": boat,
}


def main():
    for name, fn in list(TILES.items()) + list(PROPS.items()):
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
    print(f"{len(TILES)} dale + {len(PROPS)} obiecte de recuzita scrise in {OUT}")


if __name__ == "__main__":
    main()
