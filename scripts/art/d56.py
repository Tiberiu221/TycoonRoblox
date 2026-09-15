#!/usr/bin/env python3
"""Arta pentru D56: linia fierului cu oamenii ei.

Owner-ul (2026-09-14): "scraps nu are om npc care se ocupa de transport la storage, dupa transport la workshop,
dupa cineva care prelucreaza, dupa cineva care le duce la tavern". Patru meserii noi -- Scrap Collector, Scrap
Porter, Smelter, Iron Hauler -- fiecare cu tinuta ei (foile in straturi din settlers.py) si coliba ei, mica
pentru un om si mare pentru doi, ca la D55. Plus fumul hornului forjei, care pana acum era desenat din cod.

Aceleasi reguli ca d55.py: culorile din rampele vecinilor (tabla shed-ului, piatra, lemnul, fierul lingourilor),
umbra din elipse translucide, conturul trasat automat, niciodata negru pur. Colibele sunt din aceeasi familie
cu cele ale oamenilor de lemn (`_cabin`, `_gable`, `_door`, `_window` din d55), dar fiecare meserie are
acoperisul, culoarea usii si uneltele ei afara:
  * Scrap Collector -- acoperis de tabla (ca shed-ul lui), galeata cu fier vechi, carligul de plasa;
  * Scrap Porter    -- scanduri vechi, roaba parcata plina cu scrap, franghia;
  * Smelter         -- ziduri de piatra, horn inalt, vatra care arde in perete, nicovala;
  * Iron Hauler     -- ardezie albastruie ca fierul, lingourile stivuite, caruciorul cu lingouri.

Rulare: python3 scripts/art/d56.py [--force]   (apoi preview_d56.py)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, STONE, ramp  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import RUST  # noqa: E402
from tycoon_f2 import ROPE  # noqa: E402
from tycoon_f3 import WEATHERED  # noqa: E402
from tycoon_e1 import GOLD, STEEL, outline_trace  # noqa: E402
from ruins_d53 import CHAR, line  # noqa: E402
import d55  # noqa: E402

OUT = d55.OUT

# culorile meseriilor, din tinutele lor (settlers.OUTFITS): usa colibei poarta culoarea omului
SCRAPPER_CLOTH = ramp(58, 0.52, 0.50)  # scrapper: masliniu
CARTER_CLOTH = ramp(338, 0.52, 0.66)  # carter: trandafiriu
SMITH_CLOTH = ramp(26, 0.78, 0.82)  # smith: banda portocalie, ca jarul
IRON_CLOTH = ramp(235, 0.55, 0.56)  # ironmonger: indigo
EMBER = ramp(18, 0.90, 0.92, hue_shift=14)  # jarul din vatra: rosu inchis -> galben


# ---------------------------------------------------------------------------------------------
# uneltele de la usa


def _gaff(c, x, y):
    """Carligul de plasa (1x13), rezemat de perete: prajina de lemn, carligul de fier sus."""
    line(c, x, y + 12, x + 2, y + 2, WOOD[3], 1)
    c.put(x + 2, y + 1, STEEL[3])
    c.put(x + 3, y, STEEL[4])
    c.put(x + 4, y + 1, STEEL[2])


def _scrap_bucket(c, x, y, rng):
    """Galeata de tabla (6x6) cu fier vechi care iese peste buza."""
    c.rect(x, y + 2, 6, 4, STONE[2])
    c.rect(x, y + 2, 6, 1, STONE[4])
    c.rect(x + 5, y + 3, 1, 3, STONE[1])
    c.rect(x + 1, y + 4, 4, 1, STONE[1])  # cercul din mijloc
    c.put(x + 1, y + 1, RUST[2])
    c.put(x + 2, y, STONE[4])
    c.put(x + 3, y + 1, STEEL[3])
    c.put(x + 4, y, RUST[3])
    if rng.n() < 0.5:
        c.put(x + 5, y + 1, STONE[3])


def _scrap_barrow(c, x, y, rng):
    """Roaba parcata (d55._mini_barrow), plina cu scrap: aceeasi roaba cu care umbla omul."""
    d55._mini_barrow(c, x, y)
    for k in range(5):
        xx = x + 3 + k * 2
        c.put(xx, y - 1, STONE[4] if k % 2 else RUST[2])
        c.put(xx + 1, y, STONE[2])
    c.put(x + 6, y - 2, STEEL[4])


def _anvil(c, x, y):
    """Nicovala (10x6): fata de sus luminata, cornul in stanga, talia ingusta, talpa pe butuc."""
    c.rect(x + 2, y, 7, 1, STEEL[4])
    c.rect(x + 1, y + 1, 8, 1, STEEL[2])
    c.rect(x, y, 2, 1, STEEL[3])  # cornul
    c.rect(x + 4, y + 2, 3, 1, STEEL[1])  # talia
    c.rect(x + 3, y + 3, 5, 1, STEEL[2])
    c.rect(x + 2, y + 4, 7, 2, WOOD[1])  # butucul
    c.rect(x + 2, y + 4, 7, 1, WOOD[3])


def _quench_barrel(c, x, y):
    """Butoiul cu apa de racit (5x7), cu doua cercuri de fier si apa inchisa sus."""
    c.rect(x, y, 5, 7, WOOD[2])
    c.rect(x, y, 5, 1, STONE[0])
    c.rect(x + 1, y, 3, 1, (54, 80, 104, 255))
    c.rect(x, y + 2, 5, 1, STONE[1])
    c.rect(x, y + 5, 5, 1, STONE[1])
    c.rect(x + 4, y + 1, 1, 6, WOOD[0])


def _stone_wall(c, x0, x1, y0, y1):
    """Zid de piatra: blocuri decalate pe randuri, rostul inchis, muchia de sus luminata."""
    c.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, STONE[2])
    for row, y in enumerate(range(y0, y1 + 1, 3)):
        c.rect(x0, y, x1 - x0 + 1, 1, STONE[3])
        off = 2 if row % 2 else 0
        for x in range(x0 + off, x1 + 1, 5):
            c.rect(x, y, 1, 3, STONE[0])
    c.rect(x0, y1, x1 - x0 + 1, 1, STONE[0])


def _hearth(c, x, y, w, h):
    """Vatra din perete: gura arcuita cu jar -- se vede de departe ca aici arde ceva."""
    c.rect(x - 1, y - 1, w + 2, h + 1, STONE[0])
    c.rect(x, y, w, h, (46, 30, 26, 255))
    c.rect(x + 1, y + h - 2, w - 2, 2, EMBER[1])
    c.rect(x + 2, y + h - 3, w - 4, 1, EMBER[3])
    c.put(x + w // 2, y + h - 4, EMBER[4])
    c.put(x, y - 1, STONE[1])
    c.put(x + w - 1, y - 1, STONE[1])


def _tall_chimney(c, x, top, bottom):
    """Hornul forjei: mai lat si mai inalt decat al colibelor, cu gura innegrita si jar sus."""
    c.rect(x, top, 5, bottom - top, STONE[2])
    c.rect(x, top, 5, 1, CHAR[1])
    c.rect(x + 4, top + 1, 1, bottom - top - 1, STONE[1])
    for y in range(top + 3, bottom, 3):
        c.rect(x, y, 5, 1, STONE[3])
    c.put(x + 2, top, EMBER[3])


def _ingot_stack(c, x, y):
    """Doua lingouri jos, unul deasupra (d55.ingot) -- stiva de langa usa Iron Hauler-ului."""
    d55.ingot(c, x, y + 3, 6)
    d55.ingot(c, x + 5, y + 3, 6)
    d55.ingot(c, x + 2, y, 7)


def _iron_cart(c, x, y):
    """Caruciorul cu lingouri (10x8): platforma, doua roti, doua lingouri."""
    c.rect(x, y + 4, 10, 2, WOOD[2])
    c.rect(x, y + 4, 10, 1, WOOD[4])
    d55.ingot(c, x, y, 5)
    d55.ingot(c, x + 5, y, 5)
    c.ellipse(x + 2, y + 7, 1.6, 1.6, d55.TIRE[0])
    c.ellipse(x + 8, y + 7, 1.6, 1.6, d55.TIRE[0])
    line(c, x + 9, y + 4, x + 12, y + 2, WOOD[1], 1)  # manerul


def _rust_spots(c, rng, x0, x1, y0, y1, n):
    for _ in range(n):
        xx, yy = rng.i(x0, x1), rng.i(y0, y1)
        if c.px[yy][xx][3]:
            c.put(xx, yy, RUST[rng.i(1, 3)])


# ---------------------------------------------------------------------------------------------
# colibele: mica (32x28) pentru un om, mare (40x34) pentru doi -- PIXEL_SCALE 3, prinse de baza


def prop_hut_scrap_collector_1():
    c = C(32, 28)
    rng = Rng(5601)
    soft_shadow(c, 16, 26, 14, 2)
    d55._cabin(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, d55.TIN, "slate")
    _rust_spots(c, rng, 4, 27, 5, 12, 9)
    d55._door(c, 15, 18, 5, 8, SCRAPPER_CLOTH)
    d55._window(c, 8, 17)
    _scrap_bucket(c, 22, 20, rng)
    _gaff(c, 27, 12)
    outline_trace(c)
    return c


def prop_hut_scrap_collector_2():
    c = C(40, 34)
    rng = Rng(5602)
    soft_shadow(c, 20, 32, 18, 2)
    d55._cabin(c, 4, 29, 17, 31)
    d55._gable(c, 1, 32, 4, 17, d55.TIN, "slate")
    _rust_spots(c, rng, 3, 30, 6, 15, 12)
    # sopronul deschis din dreapta: doi stalpi, tabla, gramada de fier vechi
    for px in (30, 37):
        c.rect(px, 21, 2, 11, WOOD[1])
        c.rect(px, 21, 1, 11, WOOD[3])
    for i in range(4):
        c.rect(29, 18 + i, 11, 1, d55.TIN[2] if i % 2 else d55.TIN[3])
    c.ellipse(34, 30, 4, 1.6, STONE[1])
    d55.scrap_bits(c, rng, 31, 25, 7, 5, 9)
    d55._door(c, 12, 21, 6, 10, SCRAPPER_CLOTH)
    d55._window(c, 6, 21)
    d55._window(c, 21, 21)
    _gaff(c, 0, 18)
    _scrap_bucket(c, 22, 27, rng)
    outline_trace(c)
    return c


def prop_hut_scrap_porter_1():
    c = C(32, 28)
    rng = Rng(5603)
    soft_shadow(c, 16, 26, 14, 2)
    d55._cabin(c, 6, 27, 14, 25)
    d55._gable(c, 3, 30, 3, 14, WEATHERED, "plank")
    d55._door(c, 17, 18, 5, 8, CARTER_CLOTH)
    d55._window(c, 9, 17)
    _scrap_barrow(c, 0, 19, rng)
    d55._rope_coil(c, 27, 23)
    outline_trace(c)
    return c


def prop_hut_scrap_porter_2():
    c = C(40, 34)
    rng = Rng(5604)
    soft_shadow(c, 20, 32, 18, 2)
    d55._chimney(c, 28, 1, 9)
    d55._cabin(c, 7, 34, 17, 31)
    d55._gable(c, 4, 37, 4, 17, WEATHERED, "plank")
    d55._door(c, 19, 21, 6, 10, CARTER_CLOTH)
    d55._window(c, 10, 21)
    d55._window(c, 28, 21)
    _scrap_barrow(c, 0, 25, rng)
    # lada cu scrap, in dreapta usii
    c.rect(29, 27, 7, 5, WOOD[1])
    c.rect(29, 27, 7, 1, WOOD[3])
    c.rect(32, 27, 1, 5, WOOD[0])
    d55.scrap_bits(c, rng, 29, 25, 6, 2, 5)
    for k in range(3):
        c.put(36 + k % 2, 24 + k * 2, ROPE[2 + k % 2])
    outline_trace(c)
    return c


def prop_hut_smelter_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _tall_chimney(c, 19, 0, 10)
    _stone_wall(c, 4, 25, 14, 25)
    d55._gable(c, 1, 28, 3, 14, CHAR, "slate")
    _hearth(c, 7, 19, 6, 6)
    d55._door(c, 16, 18, 5, 8, SMITH_CLOTH)
    _anvil(c, 22, 20)
    outline_trace(c)
    return c


def prop_hut_smelter_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _tall_chimney(c, 25, 0, 11)
    _stone_wall(c, 6, 33, 17, 31)
    d55._gable(c, 3, 36, 4, 17, CHAR, "slate")
    _hearth(c, 10, 23, 8, 8)
    d55._door(c, 22, 21, 6, 10, SMITH_CLOTH)
    d55._window(c, 29, 21)
    _anvil(c, 29, 26)
    _quench_barrel(c, 0, 24)
    # clestele si ciocanul agatate langa vatra
    c.rect(19, 21, 1, 4, STEEL[2])
    c.put(19, 25, STEEL[4])
    c.put(8, 20, GOLD[2])
    outline_trace(c)
    return c


def prop_hut_iron_hauler_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    d55._cabin(c, 5, 26, 14, 25)
    d55._gable(c, 2, 29, 3, 14, d55.IRON, "slate")
    d55._door(c, 8, 18, 5, 8, IRON_CLOTH)
    d55._window(c, 17, 17)
    _ingot_stack(c, 20, 20)
    outline_trace(c)
    return c


def prop_hut_iron_hauler_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    d55._chimney(c, 9, 1, 9)
    d55._cabin(c, 4, 31, 17, 31)
    d55._gable(c, 1, 34, 4, 17, d55.IRON, "slate")
    d55._door(c, 14, 21, 6, 10, IRON_CLOTH)
    d55._window(c, 7, 21)
    d55._window(c, 24, 21)
    _ingot_stack(c, 20, 27)
    _iron_cart(c, 27, 24)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# fumul hornului forjei: fasie cu trei nori de 10x10 (mic, mijlociu, mare), fara contur -- in joc un nor iese
# din horn, creste si se stinge (ForgeController); pana acum era un cerc gri desenat din cod.

SMOKE_W, SMOKE_H = 10, 10


def _puff(r, alpha):
    c = C(SMOKE_W, SMOKE_H)
    cx, cy = 4.5, 5.0
    c.ellipse(cx + 0.6, cy + 0.8, r, r * 0.9, (150, 148, 152, alpha))
    c.ellipse(cx, cy, r * 0.92, r * 0.82, (196, 194, 192, alpha))
    c.ellipse(cx - r * 0.3, cy - r * 0.35, r * 0.5, r * 0.4, (230, 228, 224, alpha))
    return c


def prop_forge_smoke():
    return d55.strip([_puff(2.2, 235), _puff(3.3, 215), _puff(4.4, 190)])


SPRITES = {
    "prop_hut_scrap_collector_1": prop_hut_scrap_collector_1,
    "prop_hut_scrap_collector_2": prop_hut_scrap_collector_2,
    "prop_hut_scrap_porter_1": prop_hut_scrap_porter_1,
    "prop_hut_scrap_porter_2": prop_hut_scrap_porter_2,
    "prop_hut_smelter_1": prop_hut_smelter_1,
    "prop_hut_smelter_2": prop_hut_smelter_2,
    "prop_hut_iron_hauler_1": prop_hut_iron_hauler_1,
    "prop_hut_iron_hauler_2": prop_hut_iron_hauler_2,
    "prop_forge_smoke": prop_forge_smoke,
}

# Tinutele noi: foile in straturi (64x480) desenate de settlers.py, cu numele din Assets.people.outfit.
OUTFIT_SHEETS = ("scrapper", "carter", "smith", "ironmonger")


def main():
    import settlers as S

    force = "--force" in sys.argv
    names = list(SPRITES) + [f"outfit_{o}" for o in OUTFIT_SHEETS]
    for name in names:
        if os.path.exists(os.path.join(OUT, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name, fn in SPRITES.items():
        c = fn()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")
    for outfit in OUTFIT_SHEETS:
        sheet = S.build_sheet("outfit", outfit=outfit)
        png(f"outfit_{outfit}.png", sheet.w, sheet.h, sheet.px)
        print(f"scris outfit_{outfit}.png ({sheet.w}x{sheet.h})")


if __name__ == "__main__":
    main()
