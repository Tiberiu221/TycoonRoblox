#!/usr/bin/env python3
"""Arta pentru D67, lotul B: casele oamenilor Wire Works, taraba Clerk-ului, incarcaturile roabei si gramezile.

Aceeasi familie de colibe ca in sat si la Moara (mica 32x28 pentru un om, mare 40x34 pentru doi, prinse de baza), dar
din materialele Wire Works, ca sa se vada din rand ca esti in alt cartier: pereti de FIER NITUIT, acoperis de ardezie
gri-albastra, ferestre de sticla. Fiecare casa are semnul meseriei la usa: colacul de sarma, tamburul, stalpul cu
izolator, borcanele-baterii, celulele. Usa poarta culoarea tinutei omului (settlers.OUTFITS), ca in D55 / D65.

Incarcaturile roabei (fasie de 3 trepte, 16x9) si gramezile (fasie de 4 trepte, 40x28) au aceleasi panze ca ale erelor
dinainte. Minereul Wire Works poarta desenele minereului Morii (e aceeasi piatra), deci n-are incarcatura si gramada noi.

Rulare: python3 scripts/art/d67_crew.py [--force]   (apoi preview_d67.py crew)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, ramp  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import PLANK, STEEL, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402

OUT = d55.OUT

# culoarea usii = camasa tinutei (settlers.OUTFITS, D67)
DREDGER = ramp(212, 0.22, 0.46)  # Works Collector: fier albastrui
BARROWMAN = ramp(278, 0.28, 0.58)  # Works Porter: pruna
WIREDRAWER = ramp(344, 0.60, 0.56)  # Wiredrawer: visiniu
COILER = ramp(88, 0.58, 0.56)  # Coil Hauler: verde de muschi
CLERK = ramp(224, 0.56, 0.42)  # Clerk: bleumarin
LINEMAN = ramp(46, 0.80, 0.86)  # Battery Collector: galben de semnal
HODMAN = ramp(22, 0.64, 0.62)  # Battery Porter: pamant ars
ELECTRICIAN = ramp(214, 0.78, 0.80)  # Electrician: albastru electric
FREIGHTER = ramp(336, 0.62, 0.70)  # Power Hauler: zmeura
SLATE = W.IRON  # linia bobinelor: ardezie gri de fier
POWER_SLATE = ramp(196, 0.34, 0.46)  # linia curentului: ardezie albastru-verzuie, cu paratrasnet pe casele mari


# ---------------------------------------------------------------------------------------------
# bucati comune


def _iron_wall(c, x0, x1, y0, y1):
    W.iron_plates(c, x0, y0, x1 - x0 + 1, y1 - y0 + 1)
    c.rect(x0, y1, x1 - x0 + 1, 1, W.IRON[0])


def _pole(c, x, top, bottom):
    """Stalpul liniei (2 lat), cu o traversa si doi izolatori: semnul Battery Collector-ului."""
    c.rect(x, top, 2, bottom - top, WOOD[2])
    c.rect(x, top, 1, bottom - top, WOOD[4])
    c.rect(x - 3, top + 2, 8, 1, WOOD[1])
    W.insulator(c, x - 2, top)
    W.insulator(c, x + 3, top)


def _iron_chimney(c, x, top, bottom):
    c.rect(x, top, 3, bottom - top, W.SOOT[2])
    c.rect(x, top, 1, bottom - top, W.SOOT[4])
    c.rect(x - 1, top, 5, 1, W.SOOT[1])


def _cell(c, x, y, w=7):
    """O celula de energie culcata (w x 3): fier, capete de alama, scanteie."""
    c.rect(x, y, w, 3, W.IRON[2])
    c.rect(x, y, w, 1, W.IRON[3])
    c.put(x, y + 1, W.BRASS[3])
    c.put(x + w - 1, y + 1, W.SPARK[3])


def _cart(c, x, y, cargo):
    """Caruciorul (10x8) cu marfa deasupra: `cargo(c, x, y)` o deseneaza."""
    c.rect(x, y + 4, 10, 2, WOOD[2])
    c.rect(x, y + 4, 10, 1, WOOD[4])
    cargo(c, x, y)
    c.ellipse(x + 2, y + 7, 1.6, 1.6, d55.TIRE[0])
    c.ellipse(x + 8, y + 7, 1.6, 1.6, d55.TIRE[0])
    line(c, x + 9, y + 4, x + 12, y + 2, WOOD[1], 1)


def _hut(small, seed, door, extra, power=False):
    """O casa: mica (32x28) sau mare (40x34), pereti de fier, fronton de ardezie, usa in culoarea omului, `extra` = semnul
    meseriei (functie (c, rng) care deseneaza ce sta la usa). `power`: casele liniei curentului, cu ardezia lor si, cele
    mari, cu paratrasnet."""
    rng = Rng(seed)
    roof = POWER_SLATE if power else SLATE
    if small:
        c = C(32, 28)
        soft_shadow(c, 16, 26, 14, 2)
        _iron_wall(c, 5, 26, 14, 25)
        d55._gable(c, 2, 29, 3, 14, roof, "slate")
        d55._door(c, 15, 18, 5, 8, door)
        d55._window(c, 8, 17)
    else:
        c = C(40, 34)
        soft_shadow(c, 20, 32, 18, 2)
        _iron_wall(c, 4, 29, 17, 31)
        d55._gable(c, 1, 32, 4, 17, roof, "slate")
        d55._door(c, 12, 21, 6, 10, door)
        d55._window(c, 6, 21)
        d55._window(c, 21, 21)
        if power:
            c.rect(16, 0, 1, 5, STEEL[3])  # paratrasnetul, pe coama
            c.put(16, 0, W.BRASS[4])
    extra(c, rng)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# casele: linia bobinelor


def prop_hut_works_collector_1():
    return _hut(True, 6731, DREDGER, lambda c, rng: (d56._gaff(c, 27, 12), M.ore_rock(c, 23, 24, 2.4, 1.6, rng)))


def prop_hut_works_collector_2():
    def extra(c, rng):
        d56._gaff(c, 0, 18)
        for k in range(3):
            M.ore_rock(c, 33 + k * 2, 30 - k, 2.2, 1.6, rng)

    return _hut(False, 6732, DREDGER, extra)


def prop_hut_works_porter_1():
    def extra(c, rng):
        _cart(c, 21, 19, lambda cc, x, y: M.ore_rock(cc, x + 5, y + 3, 3, 1.8, rng))

    return _hut(True, 6733, BARROWMAN, extra)


def prop_hut_works_porter_2():
    def extra(c, rng):
        _cart(c, 28, 24, lambda cc, x, y: (M.ore_rock(cc, x + 3, y + 3, 2.4, 1.6, rng), M.ore_rock(cc, x + 7, y + 3, 2.4, 1.6, rng)))

    return _hut(False, 6734, BARROWMAN, extra)


def prop_hut_wiredrawer_1():
    def extra(c, rng):
        _iron_chimney(c, 21, 0, 8)
        W.coil(c, 21, 20, 8, 6)

    return _hut(True, 6735, WIREDRAWER, extra)


def prop_hut_wiredrawer_2():
    def extra(c, rng):
        _iron_chimney(c, 26, 0, 10)
        W.coil(c, 30, 24, 9, 8)

    return _hut(False, 6736, WIREDRAWER, extra)


def prop_hut_coil_hauler_1():
    return _hut(True, 6737, COILER, lambda c, rng: _cart(c, 21, 19, lambda cc, x, y: W.coil(cc, x + 2, y, 6, 4)))


def prop_hut_coil_hauler_2():
    def extra(c, rng):
        _cart(c, 28, 24, lambda cc, x, y: (W.coil(cc, x + 1, y, 5, 4), W.coil(cc, x + 5, y - 1, 5, 5)))

    return _hut(False, 6738, COILER, extra)


# ---------------------------------------------------------------------------------------------
# casele: linia curentului


def prop_hut_battery_collector_1():
    return _hut(True, 6741, LINEMAN, lambda c, rng: _pole(c, 28, 6, 26), power=True)


def prop_hut_battery_collector_2():
    def extra(c, rng):
        _pole(c, 35, 8, 32)
        W.jar(c, 30, 25)

    return _hut(False, 6742, LINEMAN, extra, power=True)


def prop_hut_battery_porter_1():
    def extra(c, rng):
        c.rect(21, 22, 9, 4, PLANK[1])
        c.rect(21, 22, 9, 1, PLANK[3])
        W.jar(c, 22, 16)
        W.jar(c, 26, 16, lit=False)

    return _hut(True, 6743, HODMAN, extra, power=True)


def prop_hut_battery_porter_2():
    def extra(c, rng):
        c.rect(29, 27, 11, 5, PLANK[1])
        c.rect(29, 27, 11, 1, PLANK[3])
        for k in range(2):
            W.jar(c, 30 + k * 5, 20, lit=k == 0)

    return _hut(False, 6744, HODMAN, extra, power=True)


def prop_hut_electrician_1():
    def extra(c, rng):
        _iron_chimney(c, 21, 0, 8)
        W.bolt(c, 23, 16)
        W.insulator(c, 28, 17)

    return _hut(True, 6745, ELECTRICIAN, extra, power=True)


def prop_hut_electrician_2():
    def extra(c, rng):
        _iron_chimney(c, 26, 0, 10)
        W.bolt(c, 31, 20, big=True)
        W.insulator(c, 36, 24)

    return _hut(False, 6746, ELECTRICIAN, extra, power=True)


def prop_hut_power_hauler_1():
    return _hut(
        True, 6747, FREIGHTER, lambda c, rng: _cart(c, 21, 19, lambda cc, x, y: _cell(cc, x + 1, y + 1, 8)), power=True
    )


def prop_hut_power_hauler_2():
    def extra(c, rng):
        _cart(c, 28, 24, lambda cc, x, y: (_cell(cc, x, y + 1, 8), _cell(cc, x + 1, y - 2, 8)))

    return _hut(False, 6748, FREIGHTER, extra, power=True)


# ---------------------------------------------------------------------------------------------
# taraba Clerk-ului (48x40 pentru unul, 64x40 pentru doi), ca a Negustorului, cu copertina bleumarin a Depoului


def _stall(width, posts, awnings, crates):
    c = C(width, 40)
    soft_shadow(c, width // 2, 37, width // 2 - 5, 3)
    for px in posts:
        c.rect(px, 14, 3, 21, W.IRON[1])
        c.rect(px, 14, 1, 21, W.IRON[3])
        c.rect(px + 2, 14, 1, 21, W.IRON[0])
    c.rect(2, 29, width - 4, 7, PLANK[2])  # tejgheaua
    c.rect(2, 29, width - 4, 1, PLANK[4])
    c.rect(2, 35, width - 4, 1, PLANK[0])
    for x in range(4, width - 2, 7):
        c.rect(x, 30, 1, 5, PLANK[0])
    for sx, span in awnings:
        for i in range(9):
            y, w, x0 = 6 + i, span - i * 2, sx + i
            for k in range(w):
                band = ((x0 + k) // 5) % 2
                c.put(x0 + k, y, CLERK[2] if band == 0 else CREAM[2])
        c.rect(sx, 6, span, 1, CLERK[3])
        c.rect(sx, 14, span, 1, CLERK[0])
        for i, x in enumerate(range(sx + 1, sx + span - 1, 6)):
            col = CLERK[1] if i % 2 == 0 else CREAM[1]
            c.rect(x, 15, 5, 2, col)
            c.put(x + 2, 17, col)
    for x, kind in crates:
        if kind == "coils":
            W.coil(c, x, 22, 7, 6)
        else:
            _cell(c, x, 25, 8)
            _cell(c, x + 1, 22, 8)
    outline_trace(c)
    return c


def prop_stall_clerk():
    return _stall(48, (5, 40), ((2, 44),), ((11, "coils"), (26, "cells")))


def prop_stall_clerk_2():
    return _stall(64, (5, 30, 56), ((2, 30), (32, 30)), ((10, "coils"), (20, "cells"), (38, "coils"), (48, "cells")))


# ---------------------------------------------------------------------------------------------
# incarcaturile roabei (3 trepte de 16x9)


def prop_load_coils():
    def draw(c, step):
        spots = [(3, 3), (9, 3), (6, 0)]
        for x, y in spots[:step]:
            W.coil(c, x, y, 5, 5)

    return d55._load(draw)


def prop_load_battery():
    def draw(c, step):
        spots = [(3, 2), (9, 2), (6, 0)]
        for x, y in spots[:step]:
            W.jar(c, x, y, lit=False)

    return d55._load(draw)


def prop_load_cell():
    def draw(c, step):
        spots = [(2, 5), (7, 5), (4, 2)]
        for x, y in spots[:step]:
            _cell(c, x, y, 7)

    return d55._load(draw)


# ---------------------------------------------------------------------------------------------
# gramezile (4 trepte de 40x28, baza pe randul 26)


def prop_pile_coils():
    """Bobinele gata: tamburi stivuiti, tot mai multi -- ordonat, ca orice iese dintr-un atelier."""

    def draw(c, step):
        soft_shadow(c, 20, 25, 8 + step * 3, 2)
        spots = [(14, 18), (5, 18), (23, 18), (10, 11), (19, 11), (14, 4)]
        for x, y in spots[: (1, 3, 5, 6)[step - 1]]:
            W.coil(c, x, y, 10, 7)

    return d55._pile(draw)


def prop_pile_battery():
    """Bateriile pline, pe randuri: borcane de sticla, fiecare cu scanteia ei."""

    def draw(c, step):
        soft_shadow(c, 20, 25, 8 + step * 3, 2)
        rows = (1, 2, 3, 4)[step - 1]
        for row in range(rows):
            count = 5 - row
            y = 18 - row * 5
            x0 = 20 - count * 3
            for k in range(count):
                W.jar(c, x0 + k * 6, y, lit=(k + row) % 2 == 0)

    return d55._pile(draw)


def prop_pile_cell():
    """Celulele de energie, in randuri decalate, ca stiva de fier, dar cu capete de alama si scanteie."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3, 2], 4: [4, 4, 3, 2]}

    def draw(c, step):
        soft_shadow(c, 20, 25, 16, 2)
        y = 22
        for i, count in enumerate(rows_by_step[step]):
            w, gap = 8, 1
            total = count * w + (count - 1) * gap
            x = 20 - total // 2 + (i % 2)
            for k in range(count):
                _cell(c, x + k * (w + gap), y, w)
            y -= 4

    return d55._pile(draw)


SPRITES = {
    "prop_hut_works_collector_1": prop_hut_works_collector_1,
    "prop_hut_works_collector_2": prop_hut_works_collector_2,
    "prop_hut_works_porter_1": prop_hut_works_porter_1,
    "prop_hut_works_porter_2": prop_hut_works_porter_2,
    "prop_hut_wiredrawer_1": prop_hut_wiredrawer_1,
    "prop_hut_wiredrawer_2": prop_hut_wiredrawer_2,
    "prop_hut_coil_hauler_1": prop_hut_coil_hauler_1,
    "prop_hut_coil_hauler_2": prop_hut_coil_hauler_2,
    "prop_hut_battery_collector_1": prop_hut_battery_collector_1,
    "prop_hut_battery_collector_2": prop_hut_battery_collector_2,
    "prop_hut_battery_porter_1": prop_hut_battery_porter_1,
    "prop_hut_battery_porter_2": prop_hut_battery_porter_2,
    "prop_hut_electrician_1": prop_hut_electrician_1,
    "prop_hut_electrician_2": prop_hut_electrician_2,
    "prop_hut_power_hauler_1": prop_hut_power_hauler_1,
    "prop_hut_power_hauler_2": prop_hut_power_hauler_2,
    "prop_stall_clerk": prop_stall_clerk,
    "prop_stall_clerk_2": prop_stall_clerk_2,
    "prop_load_coils": prop_load_coils,
    "prop_load_battery": prop_load_battery,
    "prop_load_cell": prop_load_cell,
    "prop_pile_coils": prop_pile_coils,
    "prop_pile_battery": prop_pile_battery,
    "prop_pile_cell": prop_pile_cell,
}


def main():
    force = "--force" in sys.argv
    for name, draw in SPRITES.items():
        path = os.path.join(OUT, name + ".png")
        if os.path.exists(path) and not force:
            print("  exista deja, sarit:", name)
            continue
        c = draw()
        png(path, c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")


if __name__ == "__main__":
    main()
