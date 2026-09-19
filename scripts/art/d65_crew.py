#!/usr/bin/env python3
"""Arta pentru D65, lotul B: casele oamenilor Morii, taraba negustorului, incarcaturile roabei si gramezile.

Aceeasi familie de colibe ca in satul vechi (d55 / d56: mica 32x28 pentru un om, mare 40x34 pentru doi, prinse de
baza), dar din materialele Morii, ca sa se vada din rand ca esti in alt cartier:
  * linia pieselor sta in CARAMIDA (Mill Collector: acoperis de tabla; Mill Porter: olane; Founder: horn inalt si vatra;
    Parts Hauler: ardezie albastra, lada cu roti dintate);
  * linia cuprului sta in PIATRA cu acoperis de CUPRU INVERZIT (Ore Collector, Ore Porter, Coppersmith cu hornul incins
    in cupru); Copper Hauler-ul are singurul acoperis de cupru NOU, portocaliu;
  * negustorul are taraba cu copertina in dungile Pietei (verde-albastrui si crem), nu rosii ca a Innkeeper-ului.
Usa fiecarei case poarta culoarea tinutei omului ei (settlers.OUTFITS), ca in D55 / D56.

Incarcaturile roabei (fasie de 3 trepte, 16x9) si gramezile (fasie de 4 trepte, 40x28) au aceleasi panze ca ale Erei 1.

Rulare: python3 scripts/art/d65_crew.py [--force]   (apoi preview_d65.py crew)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, STONE, ramp  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import RUST, CREAM  # noqa: E402
from tycoon_f3 import WEATHERED  # noqa: E402
from tycoon_e1 import PLANK, STEEL, outline_trace  # noqa: E402
from ruins_d53 import CHAR, line  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import d65_mill as M  # noqa: E402

OUT = d55.OUT

# culoarea usii = camasa tinutei (settlers.OUTFITS)
GLEANER = ramp(174, 0.62, 0.56)  # Mill Collector: verde-albastrui
DRAYMAN = ramp(46, 0.70, 0.78)  # Mill Porter: mustar
FOUNDER = ramp(10, 0.72, 0.66)  # Founder: rosu-caramiziu
WHEELWRIGHT = ramp(210, 0.56, 0.66)  # Parts Hauler: albastru de otel
MERCHANT = ramp(154, 0.62, 0.50)  # Merchant: smarald
PROSPECTOR = ramp(36, 0.56, 0.54)  # Ore Collector: pamantiu
MUCKER = ramp(42, 0.22, 0.72)  # Ore Porter: praf de piatra
COPPERSMITH = ramp(40, 0.18, 0.84)  # Coppersmith: camasa crem, sort verde
TEAMSTER = ramp(22, 0.80, 0.82)  # Copper Hauler: portocaliu de cupru
SLATE_BLUE = ramp(212, 0.30, 0.52)


# ---------------------------------------------------------------------------------------------
# bucati comune


def _brick_wall(c, x0, x1, y0, y1):
    M.bricks(c, x0, y0, x1 - x0 + 1, y1 - y0 + 1)
    for y in range(y0, y1, 4):  # colturile din piatra deschisa
        for x in (x0 - 1, x1):
            c.rect(x, y, 2, 2, M.MORTAR[3])
            c.put(x, y + 1, M.MORTAR[1])
    c.rect(x0, y1, x1 - x0 + 1, 1, M.BRICK[0])


def copper_ingot(c, x, y, w=8):
    c.rect(x, y, w, 3, M.COPPER[2])
    c.rect(x + 1, y, w - 2, 1, M.COPPER[4])
    c.rect(x, y + 2, w, 1, M.COPPER[0])
    c.put(x + w - 1, y + 1, M.COPPER[1])


def _gear_crate(c, x, y):
    """Lada cu roti dintate (9x7), la usa Parts Hauler-ului."""
    c.rect(x, y + 2, 9, 5, PLANK[1])
    c.rect(x, y + 2, 9, 1, PLANK[3])
    c.rect(x + 4, y + 2, 1, 5, PLANK[0])
    M.gear(c, x + 2.5, y + 1.5, 2.0, STEEL, teeth=6)
    M.gear(c, x + 6.5, y + 1, 1.6, STEEL, teeth=6, hole=False)


def _ore_basket(c, x, y, rng):
    """Cosul cu minereu (8x7)."""
    c.rect(x, y + 3, 8, 4, d55.ROPE[1])
    c.rect(x, y + 3, 8, 1, d55.ROPE[3])
    for xx in range(x + 1, x + 8, 2):
        c.rect(xx, y + 4, 1, 3, d55.ROPE[0])
    M.ore_rock(c, x + 2.5, y + 2, 2.4, 1.8, rng)
    M.ore_rock(c, x + 5.5, y + 1.6, 2.2, 1.6, rng)


def _ore_barrow(c, x, y, rng):
    d55._mini_barrow(c, x, y)
    M.ore_rock(c, x + 5, y - 0.4, 2.6, 1.6, rng)
    M.ore_rock(c, x + 8.6, y, 2.2, 1.4, rng)


def _scrap_barrow(c, x, y, rng):
    d56._scrap_barrow(c, x, y, rng)


def _net_hook(c, x, y):
    d56._gaff(c, x, y)


def _copper_chimney(c, x, top, bottom):
    """Hornul Coppersmith-ului: piatra, cu doua braie de cupru si jar in gura."""
    c.rect(x, top, 5, bottom - top, STONE[2])
    c.rect(x + 4, top + 1, 1, bottom - top - 1, STONE[1])
    c.rect(x, top, 5, 1, CHAR[1])
    for y in (top + 2, top + 6):
        c.rect(x - 1, y, 7, 1, M.COPPER[3])
    c.put(x + 2, top, M.EMBER[3])


def _brick_chimney(c, x, top, bottom):
    M.bricks(c, x, top, 5, bottom - top)
    c.rect(x - 1, top, 7, 1, M.BRICK[0])
    c.put(x + 2, top - 1, M.EMBER[3])


def _mold(c, x, y):
    """Forma de turnat, cu metalul inca rosu (6x3)."""
    c.rect(x, y, 6, 3, M.MORTAR[1])
    c.rect(x, y, 6, 1, M.MORTAR[3])
    c.rect(x + 1, y + 1, 4, 1, M.EMBER[2])


def _cart(c, x, y, cargo):
    """Caruciorul (10x8) cu marfa deasupra: `cargo(c, x, y)` o deseneaza."""
    c.rect(x, y + 4, 10, 2, WOOD[2])
    c.rect(x, y + 4, 10, 1, WOOD[4])
    cargo(c, x, y)
    c.ellipse(x + 2, y + 7, 1.6, 1.6, d55.TIRE[0])
    c.ellipse(x + 8, y + 7, 1.6, 1.6, d55.TIRE[0])
    line(c, x + 9, y + 4, x + 12, y + 2, WOOD[1], 1)


# ---------------------------------------------------------------------------------------------
# casele: linia pieselor, in caramida


def prop_hut_mill_collector_1():
    c = C(32, 28)
    rng = Rng(6531)
    soft_shadow(c, 16, 26, 14, 2)
    _brick_wall(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, M.TIN, "slate")
    d55._door(c, 15, 18, 5, 8, GLEANER)
    d55._window(c, 8, 17)
    d56._scrap_bucket(c, 22, 20, rng)
    _net_hook(c, 27, 12)
    outline_trace(c)
    return c


def prop_hut_mill_collector_2():
    c = C(40, 34)
    rng = Rng(6532)
    soft_shadow(c, 20, 32, 18, 2)
    _brick_wall(c, 4, 29, 17, 31)
    d55._gable(c, 1, 32, 4, 17, M.TIN, "slate")
    for px in (30, 37):  # sopronul cu plase la uscat
        c.rect(px, 21, 2, 11, WOOD[1])
        c.rect(px, 21, 1, 11, WOOD[3])
    for i in range(4):
        c.rect(29, 18 + i, 11, 1, M.TIN[2] if i % 2 else M.TIN[3])
    for k in range(5):
        c.rect(31 + k, 22 + (k % 2), 1, 7, d55.ROPE[2 + k % 2])
    d55._door(c, 12, 21, 6, 10, GLEANER)
    d55._window(c, 6, 21)
    d55._window(c, 21, 21)
    _net_hook(c, 0, 18)
    d56._scrap_bucket(c, 22, 27, rng)
    outline_trace(c)
    return c


def prop_hut_mill_porter_1():
    c = C(32, 28)
    rng = Rng(6533)
    soft_shadow(c, 16, 26, 14, 2)
    _brick_wall(c, 6, 27, 14, 25)
    d55._gable(c, 3, 30, 3, 14, M.TILE, "shingle")
    d55._door(c, 17, 18, 5, 8, DRAYMAN)
    d55._window(c, 9, 17)
    _scrap_barrow(c, 0, 19, rng)
    d55._rope_coil(c, 27, 23)
    outline_trace(c)
    return c


def prop_hut_mill_porter_2():
    c = C(40, 34)
    rng = Rng(6534)
    soft_shadow(c, 20, 32, 18, 2)
    _brick_chimney(c, 28, 1, 9)
    _brick_wall(c, 7, 34, 17, 31)
    d55._gable(c, 4, 37, 4, 17, M.TILE, "shingle")
    d55._door(c, 19, 21, 6, 10, DRAYMAN)
    d55._window(c, 10, 21)
    d55._window(c, 28, 21)
    _scrap_barrow(c, 0, 25, rng)
    c.rect(29, 27, 7, 5, PLANK[1])  # lada cu fier vechi
    c.rect(29, 27, 7, 1, PLANK[3])
    M.scrap_heap(c, rng, 30, 27, 5)
    outline_trace(c)
    return c


def prop_hut_founder_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _brick_chimney(c, 19, 0, 10)
    _brick_wall(c, 4, 25, 14, 25)
    d55._gable(c, 1, 28, 3, 14, CHAR, "slate")
    d56._hearth(c, 7, 19, 6, 6)
    d55._door(c, 16, 18, 5, 8, FOUNDER)
    _mold(c, 23, 23)
    outline_trace(c)
    return c


def prop_hut_founder_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _brick_chimney(c, 25, 0, 11)
    _brick_wall(c, 6, 33, 17, 31)
    d55._gable(c, 3, 36, 4, 17, CHAR, "slate")
    d56._hearth(c, 10, 23, 8, 8)
    d55._door(c, 22, 21, 6, 10, FOUNDER)
    d55._window(c, 29, 21)
    _mold(c, 0, 29)
    _mold(c, 30, 29)
    outline_trace(c)
    return c


def prop_hut_parts_hauler_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _brick_wall(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, SLATE_BLUE, "slate")
    d55._door(c, 15, 18, 5, 8, WHEELWRIGHT)
    d55._window(c, 8, 17)
    _gear_crate(c, 22, 19)
    outline_trace(c)
    return c


def prop_hut_parts_hauler_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    d55._chimney(c, 9, 1, 9)
    _brick_wall(c, 5, 31, 17, 31)
    d55._gable(c, 2, 34, 4, 17, SLATE_BLUE, "slate")
    d55._door(c, 15, 21, 6, 10, WHEELWRIGHT)
    d55._window(c, 8, 21)
    d55._window(c, 24, 21)
    _cart(c, 28, 24, lambda cc, x, y: (M.gear(cc, x + 3, y + 1.5, 2.2, STEEL, 6), M.gear(cc, x + 7, y + 2, 1.8, STEEL, 6)))
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# casele: linia cuprului, in piatra cu cupru inverzit


def prop_hut_ore_collector_1():
    c = C(32, 28)
    rng = Rng(6541)
    soft_shadow(c, 16, 26, 14, 2)
    d56._stone_wall(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, M.VERDIGRIS, "plank")
    d55._door(c, 15, 18, 5, 8, PROSPECTOR)
    d55._window(c, 8, 17)
    _ore_basket(c, 22, 19, rng)
    _net_hook(c, 27, 12)
    outline_trace(c)
    return c


def prop_hut_ore_collector_2():
    c = C(40, 34)
    rng = Rng(6542)
    soft_shadow(c, 20, 32, 18, 2)
    d56._stone_wall(c, 4, 29, 17, 31)
    d55._gable(c, 1, 32, 4, 17, M.VERDIGRIS, "plank")
    d55._door(c, 12, 21, 6, 10, PROSPECTOR)
    d55._window(c, 6, 21)
    d55._window(c, 21, 21)
    _net_hook(c, 0, 18)
    _ore_basket(c, 23, 25, rng)
    _ore_basket(c, 31, 25, rng)
    outline_trace(c)
    return c


def prop_hut_ore_porter_1():
    c = C(32, 28)
    rng = Rng(6543)
    soft_shadow(c, 16, 26, 14, 2)
    d56._stone_wall(c, 6, 27, 14, 25)
    d55._gable(c, 3, 30, 3, 14, M.VERDIGRIS, "shingle")
    d55._door(c, 17, 18, 5, 8, MUCKER)
    d55._window(c, 9, 17)
    _ore_barrow(c, 0, 19, rng)
    outline_trace(c)
    return c


def prop_hut_ore_porter_2():
    c = C(40, 34)
    rng = Rng(6544)
    soft_shadow(c, 20, 32, 18, 2)
    d55._chimney(c, 28, 1, 9)
    d56._stone_wall(c, 7, 34, 17, 31)
    d55._gable(c, 4, 37, 4, 17, M.VERDIGRIS, "shingle")
    d55._door(c, 19, 21, 6, 10, MUCKER)
    d55._window(c, 10, 21)
    d55._window(c, 28, 21)
    _ore_barrow(c, 0, 25, rng)
    M.ore_rock(c, 33, 29.6, 3.4, 2.2, rng)
    outline_trace(c)
    return c


def prop_hut_coppersmith_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _copper_chimney(c, 19, 0, 10)
    d56._stone_wall(c, 4, 25, 14, 25)
    d55._gable(c, 1, 28, 3, 14, M.VERDIGRIS, "slate")
    d56._hearth(c, 7, 19, 6, 6)
    d55._door(c, 16, 18, 5, 8, COPPERSMITH)
    d56._anvil(c, 22, 20)
    outline_trace(c)
    return c


def prop_hut_coppersmith_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _copper_chimney(c, 25, 0, 11)
    d56._stone_wall(c, 6, 33, 17, 31)
    d55._gable(c, 3, 36, 4, 17, M.VERDIGRIS, "slate")
    d56._hearth(c, 10, 23, 8, 8)
    d55._door(c, 22, 21, 6, 10, COPPERSMITH)
    d55._window(c, 29, 21)
    d56._anvil(c, 30, 26)
    d56._quench_barrel(c, 0, 24)
    outline_trace(c)
    return c


def prop_hut_copper_hauler_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    d56._stone_wall(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, M.COPPER, "slate")  # singurul acoperis de cupru nou
    d55._door(c, 15, 18, 5, 8, TEAMSTER)
    d55._window(c, 8, 17)
    copper_ingot(c, 22, 23, 6)
    copper_ingot(c, 24, 20, 6)
    outline_trace(c)
    return c


def prop_hut_copper_hauler_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    d55._chimney(c, 9, 1, 9)
    d56._stone_wall(c, 5, 31, 17, 31)
    d55._gable(c, 2, 34, 4, 17, M.COPPER, "slate")
    d55._door(c, 15, 21, 6, 10, TEAMSTER)
    d55._window(c, 8, 21)
    d55._window(c, 24, 21)
    _cart(c, 28, 24, lambda cc, x, y: (copper_ingot(cc, x, y + 1, 5), copper_ingot(cc, x + 5, y + 1, 5)))
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# taraba negustorului (48x40 pentru unul, 64x40 pentru doi), ca a Innkeeper-ului, in dungile Pietei


def _stall(width, posts, awnings, crates):
    c = C(width, 40)
    soft_shadow(c, width // 2, 37, width // 2 - 5, 3)
    for px in posts:
        c.rect(px, 14, 3, 21, WOOD[1])
        c.rect(px, 14, 1, 21, WOOD[3])
        c.rect(px + 2, 14, 1, 21, WOOD[0])
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
                c.put(x0 + k, y, M.TEAL[2] if band == 0 else CREAM[2])
        c.rect(sx, 6, span, 1, M.TEAL[3])
        c.rect(sx, 14, span, 1, M.TEAL[0])
        for i, x in enumerate(range(sx + 1, sx + span - 1, 6)):
            col = M.TEAL[1] if i % 2 == 0 else CREAM[1]
            c.rect(x, 15, 5, 2, col)
            c.put(x + 2, 17, col)
    for x, kind in crates:
        if kind == "gears":
            M.gear(c, x + 2, 26, 2.4, STEEL, 8)
            M.gear(c, x + 7, 27, 1.8, STEEL, 6)
        else:
            copper_ingot(c, x, 26, 7)
            copper_ingot(c, x + 2, 23, 7)
    outline_trace(c)
    return c


def prop_stall_merchant():
    return _stall(48, (5, 40), ((2, 44),), ((11, "gears"), (26, "copper")))


def prop_stall_merchant_2():
    return _stall(64, (5, 30, 56), ((2, 30), (32, 30)), ((10, "gears"), (20, "copper"), (38, "gears"), (48, "copper")))


# ---------------------------------------------------------------------------------------------
# incarcaturile roabei (3 trepte de 16x9)


def prop_load_parts():
    def draw(c, step):
        spots = [(5, 5, 2.6), (10, 5.4, 2.2), (7.5, 2.6, 2.0)]
        for cx, cy, r in spots[:step]:
            M.gear(c, cx, cy, r, STEEL, teeth=6)

    return d55._load(draw)


def prop_load_ore():
    def draw(c, step):
        rng = Rng(6551 + step)
        spots = [(5, 6, 3.2, 2.2), (10.5, 6.2, 3, 2), (7.6, 3.4, 3, 2)]
        for cx, cy, rx, ry in spots[:step]:
            M.ore_rock(c, cx, cy, rx, ry, rng)

    return d55._load(draw)


def prop_load_copper():
    def draw(c, step):
        spots = [(4, 5), (1, 3), (8, 3), (4, 1), (9, 5)]
        for x, y in spots[: (1, 3, 4)[step - 1]]:
            copper_ingot(c, x, y, 7)

    return d55._load(draw)


# ---------------------------------------------------------------------------------------------
# gramezile (4 trepte de 40x28, baza pe randul 26)


def prop_pile_parts():
    """Piesele gata: roti dintate stivuite in lazi, tot mai multe -- ordonat, ca orice iese dintr-un atelier."""

    def draw(c, step):
        soft_shadow(c, 20, 25, 8 + step * 3, 2)
        crates = [(14, 19), (5, 19), (23, 19), (10, 12), (19, 12), (14, 5)]
        n = (1, 3, 5, 6)[step - 1]
        for x, y in crates[:n]:
            c.rect(x, y + 2, 11, 5, PLANK[1])
            c.rect(x, y + 2, 11, 1, PLANK[3])
            c.rect(x, y + 6, 11, 1, PLANK[0])
            c.rect(x + 5, y + 2, 1, 5, PLANK[0])
            M.gear(c, x + 3, y + 1.4, 2.2, STEEL, teeth=6)
            M.gear(c, x + 8, y + 1.2, 1.8, STEEL, teeth=6, hole=False)

    return d55._pile(draw)


def prop_pile_ore():
    """Mormanul de minereu: bolovani maronii cu vine verzi, tot mai inalt."""

    def draw(c, step):
        rng = Rng(6561 + step)
        rx = (7, 10, 14, 17)[step - 1]
        soft_shadow(c, 20, 25, rx + 2, 2)
        rows = (1, 2, 3, 4)[step - 1]
        for row in range(rows):
            count = rows - row + (1 if step > 1 else 0)
            y = 23 - row * 4
            width = count * 7
            for k in range(count):
                cx = 20 - width / 2 + 3.5 + k * 7 + (row % 2) * 1.5
                M.ore_rock(c, cx, y, 4.2, 2.8, rng)

    return d55._pile(draw)


def prop_pile_copper():
    """Lingourile de cupru, in randuri decalate, ca stiva de fier, dar portocalii."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3, 2], 4: [4, 4, 3, 2]}

    def draw(c, step):
        soft_shadow(c, 20, 25, 16, 2)
        y = 22
        for i, count in enumerate(rows_by_step[step]):
            w, gap = 8, 1
            total = count * w + (count - 1) * gap
            x = 20 - total // 2 + (i % 2)
            for k in range(count):
                copper_ingot(c, x + k * (w + gap), y, w)
            y -= 4

    return d55._pile(draw)


SPRITES = {
    "prop_hut_mill_collector_1": prop_hut_mill_collector_1,
    "prop_hut_mill_collector_2": prop_hut_mill_collector_2,
    "prop_hut_mill_porter_1": prop_hut_mill_porter_1,
    "prop_hut_mill_porter_2": prop_hut_mill_porter_2,
    "prop_hut_founder_1": prop_hut_founder_1,
    "prop_hut_founder_2": prop_hut_founder_2,
    "prop_hut_parts_hauler_1": prop_hut_parts_hauler_1,
    "prop_hut_parts_hauler_2": prop_hut_parts_hauler_2,
    "prop_hut_ore_collector_1": prop_hut_ore_collector_1,
    "prop_hut_ore_collector_2": prop_hut_ore_collector_2,
    "prop_hut_ore_porter_1": prop_hut_ore_porter_1,
    "prop_hut_ore_porter_2": prop_hut_ore_porter_2,
    "prop_hut_coppersmith_1": prop_hut_coppersmith_1,
    "prop_hut_coppersmith_2": prop_hut_coppersmith_2,
    "prop_hut_copper_hauler_1": prop_hut_copper_hauler_1,
    "prop_hut_copper_hauler_2": prop_hut_copper_hauler_2,
    "prop_stall_merchant": prop_stall_merchant,
    "prop_stall_merchant_2": prop_stall_merchant_2,
    "prop_load_parts": prop_load_parts,
    "prop_load_ore": prop_load_ore,
    "prop_load_copper": prop_load_copper,
    "prop_pile_parts": prop_pile_parts,
    "prop_pile_ore": prop_pile_ore,
    "prop_pile_copper": prop_pile_copper,
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
