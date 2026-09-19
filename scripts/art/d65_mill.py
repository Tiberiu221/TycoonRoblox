#!/usr/bin/env python3
"""Arta pentru D65, lotul A: cladirile Morii, ruinele lor si marfa noua.

Era 2 e schema Erei 1 in oglinda, deci fiecare cladire are o pereche in satul vechi si ia EXACT panza ei (aceeasi
amprenta pe harta, aceleasi cutii in TycoonConfig). Dar Moara e alt loc si alta vreme: satul vechi e lemn, paie si
sindrila; Moara e CARAMIDA, TABLA si CUPRU. De la prima privire trebuie sa se vada ca ai trecut gardul:

  prop_mill_store      40x32  (perechea: depozitul)     sopron cu acoperis de tabla intr-o apa, lazi cu fier vechi
  prop_foundry         40x32  (perechea: gaterul)       hala de caramida cu gura cuptorului aprinsa si horn
  prop_market          64x48  (perechea: taverna)       hala cu copertina in dungi, tejghea cu marfa, firma cu roata dintata
  prop_water_wheel     48x48  (fara pereche)            roata de lemn pe picior de piatra, jgheabul si apa care cade
  prop_copper_furnace  64x48  (perechea: forja)         turn de piatra cu gluga de cupru inverzit, gura aprinsa, foale
  prop_ore_shed        40x32  (perechea: Scrap Shed)    sopron cu gramezi de minereu (piatra cu vine verzi), tarnacop
  prop_mill_bell       40x56  (perechea: clopotul)      clopot de cupru pe cadru de barne, cu roata dintata in varf
  prop_ruin_*          aceeasi panza cu cladirea        ce a ramas din ele [D53]: amprenta cladirii, cazuta si napadita
  goods_parts / goods_ore / goods_copper  24x18         piesa de masina (roata dintata), minereul, lingoul de cupru

Aceleasi reguli ca restul conductei (buildings.py / tycoon*.py / ruins_d53.py): culorile din palette.ramp(), umbra din
elipse translucide, conturul trasat automat, niciodata negru pur. NU suprascrie un sprite existent fara --force.

Rulare: python3 scripts/art/d65_mill.py [--force]   (apoi preview_d65.py pentru plansa)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png, shadow  # noqa: E402
from palette import WOOD, STONE, FOAM, WATER, ramp, mix  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402
from tycoon import RUST, CREAM  # noqa: E402
from tycoon_f3 import WEATHERED  # noqa: E402
from tycoon_e1 import PLANK, WARM, GOLD, GOLD_HI, STEEL, outline_trace  # noqa: E402
from ruins_d53 import MOSS, PATINA, CHAR, beam, line, weeds  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

# materialele Morii
BRICK = ramp(12, 0.50, 0.56, hue_shift=8)  # caramida arsa: rosu-caramiziu, nu sindrila gaterului
MORTAR = ramp(34, 0.14, 0.70)
TIN = ramp(205, 0.10, 0.66, val_span=0.36)  # tabla ondulata, gri-albastrui
COPPER = ramp(22, 0.70, 0.80, hue_shift=12)  # cuprul curat: portocaliu cald
VERDIGRIS = ramp(162, 0.42, 0.60)  # cuprul inverzit de vreme (gluga cuptorului, clopotul vechi)
EMBER = ramp(18, 0.90, 0.92, hue_shift=14)  # jarul: rosu inchis -> galben
ROCK = ramp(26, 0.20, 0.44)  # piatra minereului
VEIN = ramp(168, 0.58, 0.66)  # vinele verzi-albastre de cupru din piatra
TEAL = ramp(176, 0.46, 0.56)  # dungile copertinei Pietei (taverna are ardezie albastra, colibele au paie)
TILE = ramp(8, 0.52, 0.58)  # olanele Pietei


# ---------------------------------------------------------------------------------------------
# bucati comune


def bricks(c, x, y, w, h, tones=BRICK):
    """Zid de caramida: randuri de 2 px, rosturi decalate din doua in doua randuri."""
    c.rect(x, y, w, h, tones[2])
    for row, yy in enumerate(range(y, y + h, 2)):
        c.rect(x, yy + 1, w, 1, tones[1])
        for xx in range(x + (2 if row % 2 else 0), x + w, 4):
            c.put(xx, yy, tones[1])
    c.rect(x, y, 1, h, tones[3])  # muchia luminata, din stanga
    c.rect(x + w - 1, y, 1, h, tones[0])


def tin_roof(c, x, y, w, h, slope=0):
    """Tabla ondulata: dungi verticale deschis / inchis. `slope` = cu cati pixeli coboara spre dreapta."""
    for i in range(w):
        drop = int(slope * i / max(1, w - 1))
        tone = TIN[3] if i % 3 == 0 else (TIN[2] if i % 3 == 1 else TIN[1])
        c.rect(x + i, y + drop, 1, h, tone)
        c.put(x + i, y + drop, TIN[4])
        c.put(x + i, y + drop + h - 1, TIN[0])


def gear(c, cx, cy, r, tones, teeth=8, hole=True):
    """Roata dintata: semnul Morii (firma Pietei, varful clopotului, piesa de masina)."""
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        c.rect(round(cx + math.cos(a) * r - 0.5), round(cy + math.sin(a) * r - 0.5), 2, 2, tones[1])
    c.ellipse(cx, cy, r - 0.6, r - 0.6, tones[2])
    c.ellipse(cx - 0.6, cy - 0.6, r - 1.8, r - 1.8, tones[3])
    if hole:
        c.ellipse(cx, cy, max(0.8, r * 0.3), max(0.8, r * 0.3), tones[0])


def scrap_heap(c, rng, x, y, w):
    """Fier vechi peste buza unei lazi: aceleasi tonuri ca marfa `scrap`."""
    for i in range(w):
        h = 1 + (i * 7 + rng.i(0, 2)) % 3
        tone = (RUST[2], STONE[3], STEEL[3], RUST[3], STONE[2])[(i + rng.i(0, 1)) % 5]
        c.rect(x + i, y - h, 1, h, tone)


def ore_rock(c, cx, cy, rx, ry, rng):
    """Un bolovan de minereu: piatra maronie cu vine verzi-albastre."""
    c.ellipse(cx, cy, rx, ry, ROCK[1])
    c.ellipse(cx - 0.6, cy - 0.6, rx - 0.8, ry - 0.8, ROCK[2])
    c.put(round(cx - rx * 0.4), round(cy - ry * 0.5), ROCK[4])
    for _ in range(max(2, int(rx))):
        vx = round(cx + (rng.n() - 0.5) * rx * 1.3)
        vy = round(cy + (rng.n() - 0.5) * ry * 1.1)
        c.put(vx, vy, VEIN[3])
        if rng.n() < 0.6:
            c.put(vx + 1, vy, VEIN[2])


def ingot(c, x, y, w=6, tones=COPPER):
    c.rect(x, y, w, 2, tones[2])
    c.rect(x + 1, y, w - 2, 1, tones[4])
    c.rect(x, y + 1, w, 1, tones[1])


# ---------------------------------------------------------------------------------------------
# cladirile


def prop_mill_store():
    """Magazia Morii (40x32, perechea depozitului): sopron cu acoperis de tabla INTR-O APA (mai inalt in stanga), doua
    lazi mari cu fier vechi si o roata dintata rezemata. Depozitul are busteni cu capetele spre tine; aici e metal."""
    c = C(40, 32)
    rng = Rng(6501)
    shadow(c, 20, 29, 18, 2)
    c.rect(5, 9, 30, 18, WEATHERED[1])  # peretele din spate, scanduri vechi
    for y in range(11, 27, 3):
        c.rect(5, y, 30, 1, WEATHERED[0])
    c.rect(5, 9, 30, 1, WEATHERED[3])
    for px, top in ((3, 4), (35, 9)):  # stalpii: cel din stanga e mai inalt
        c.rect(px, top, 3, 28 - top, WOOD[2])
        c.rect(px, top, 1, 28 - top, WOOD[3])
    tin_roof(c, 0, 0, 40, 7, slope=5)
    for i in range(40):  # streasina, pe panta
        c.put(i, 7 + int(5 * i / 39), TIN[0])
    # doua lazi cu fier vechi
    for bx in (7, 21):
        c.rect(bx, 18, 12, 9, PLANK[1])
        c.rect(bx, 18, 12, 1, PLANK[3])
        c.rect(bx, 22, 12, 1, PLANK[0])
        c.rect(bx, 18, 1, 9, PLANK[2])
        c.rect(bx + 11, 18, 1, 9, PLANK[0])
        c.rect(bx + 2, 24, 8, 1, STEEL[1])  # cercul de fier al lazii
        scrap_heap(c, rng, bx + 1, 18, 10)
    gear(c, 34, 23, 3.4, STEEL, teeth=8)  # o roata veche, rezemata de stalp
    outline_trace(c)
    return c


def prop_foundry():
    """Turnatoria (40x32, perechea gaterului): hala scunda de caramida, gura cuptorului boltita si aprinsa, hornul in
    dreapta, doua forme de turnat in fata. Gaterul e lemn deschis cu o panza; asta e foc inchis in zid."""
    c = C(40, 32)
    shadow(c, 20, 29, 18, 2)
    bricks(c, 3, 10, 34, 18)
    # acoperisul in doua ape, tabla inchisa
    for i in range(7):
        inset = 6 - i
        c.rect(1 + inset, 3 + i, 38 - 2 * inset, 1, TIN[1] if i % 2 else TIN[2])
    c.rect(0, 10, 40, 1, TIN[0])
    c.rect(7, 3, 26, 1, TIN[4])
    # hornul
    bricks(c, 29, 0, 6, 9)
    c.rect(28, 0, 8, 1, BRICK[0])
    # gura cuptorului: bolta, jarul
    c.ellipse(15, 22, 7.5, 7, BRICK[0])
    c.rect(8, 22, 15, 6, BRICK[0])
    c.ellipse(15, 22.5, 6, 5.6, EMBER[0])
    c.rect(9, 23, 12, 5, EMBER[0])
    c.ellipse(15, 24.5, 4.6, 3.6, EMBER[2])
    c.ellipse(15, 25.6, 3, 2.2, EMBER[3])
    c.rect(13, 26, 4, 1, EMBER[4])
    for k, bx in enumerate(range(8, 23, 2)):  # caramizile boltii
        c.put(bx, 15 + (abs(k - 3.5) > 2) + (abs(k - 3.5) > 3), MORTAR[2])
    # oala de turnat, pe un brat
    c.rect(25, 17, 9, 1, STEEL[1])
    c.rect(27, 18, 5, 4, STEEL[2])
    c.rect(27, 18, 5, 1, EMBER[3])
    c.put(27, 18, STEEL[4])
    # formele de turnat, in fata
    for fx in (25, 31):
        c.rect(fx, 25, 5, 3, MORTAR[1])
        c.rect(fx, 25, 5, 1, MORTAR[3])
        c.rect(fx + 1, 26, 3, 1, EMBER[2])
    outline_trace(c)
    return c


def prop_market():
    """Piata (64x48, perechea tavernei): hala deschisa cu olane rosii, copertina lata in dungi verzi-albastre, tejghea
    cu roti dintate si lingouri de cupru, firma cu roata dintata si moneda. Taverna e o casa inchisa cu firma cu cana;
    Piata e o taraba mare, deschisa, cu marfa la vedere."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    # stalpii si peretele din spate
    c.rect(5, 20, 54, 25, WOOD[1])
    for y in range(22, 45, 3):
        c.rect(5, y, 54, 1, WOOD[0])
    for px in (4, 30, 57):
        c.rect(px, 17, 3, 28, WOOD[2])
        c.rect(px, 17, 1, 28, WOOD[3])
    # acoperisul de olane, in trepte
    for i in range(12):
        x0 = 12 - i
        c.rect(x0, 3 + i, 64 - 2 * x0, 1, TILE[2] if i % 2 else TILE[3])
        if i % 2 == 0:
            for x in range(x0 + (i // 2) % 3, 64 - x0, 3):
                c.put(x, 3 + i, TILE[1])
    c.rect(12, 2, 40, 1, TILE[4])
    c.rect(0, 15, 64, 2, TILE[0])
    # copertina in dungi, peste tejghea
    for i in range(7):
        for x in range(2, 62):
            stripe = ((x - 2) // 5) % 2 == 0
            tone = (TEAL[3] if i < 5 else TEAL[1]) if stripe else (CREAM[3] if i < 5 else CREAM[1])
            c.put(x, 17 + i, tone)
    for x in range(2, 62, 5):  # franjurii
        c.rect(x + 1, 24, 3, 1, TEAL[2] if ((x - 2) // 5) % 2 == 0 else CREAM[2])
    # interiorul in umbra, deasupra tejghelei
    c.rect(7, 25, 23, 9, WOOD[0])
    c.rect(33, 25, 24, 9, WOOD[0])
    # tejgheaua
    c.rect(6, 34, 52, 3, PLANK[3])
    c.rect(6, 34, 52, 1, PLANK[4])
    c.rect(6, 36, 52, 1, PLANK[1])
    c.rect(6, 37, 52, 8, PLANK[2])
    for x in range(6, 58, 7):
        c.rect(x, 37, 1, 8, PLANK[1])
    # marfa pe tejghea: roti dintate, lingouri
    gear(c, 12, 31, 2.6, STEEL, teeth=8)
    gear(c, 20, 31.5, 2.0, STEEL, teeth=6)
    gear(c, 26, 32, 1.6, RUST, teeth=6, hole=False)
    for k, (ix, iy) in enumerate(((36, 32), (43, 32), (39, 30), (50, 32))):
        ingot(c, ix, iy, 6)
    c.rect(52, 28, 3, 6, WARM[3])  # felinarul
    c.put(53, 27, WOOD[0])
    # firma atarnata: roata dintata si moneda
    c.rect(24, 7, 16, 9, (60, 40, 26, 255))
    c.rect(25, 8, 14, 7, WOOD[1])
    gear(c, 30, 11.5, 2.8, GOLD, teeth=8)
    c.ellipse(36, 11.5, 2, 2, GOLD[2])
    c.ellipse(35.6, 11.1, 1.2, 1.2, GOLD_HI[4])
    # butoi si lada, in dreapta
    c.rect(59, 37, 4, 8, WOOD[2])
    c.rect(59, 39, 4, 1, STEEL[1])
    c.rect(59, 42, 4, 1, STEEL[1])
    c.rect(0, 39, 4, 6, PLANK[2])
    c.rect(0, 39, 4, 1, PLANK[4])
    outline_trace(c)
    return c


def _wheel_body(c, cx, cy, r, tones, paddles=10, missing=()):
    """Roata de apa: obada dubla, spite, palete. `missing` = paletele care lipsesc (ruina)."""
    for k in range(paddles):
        if k in missing:
            continue
        a = 2 * math.pi * k / paddles
        x0, y0 = cx + math.cos(a) * (r - 4), cy + math.sin(a) * (r - 4)
        x1, y1 = cx + math.cos(a) * (r + 1.5), cy + math.sin(a) * (r + 1.5)
        line(c, round(x0), round(y0), round(x1), round(y1), tones[1], 2)
        line(c, round(x0), round(y0), round(x1), round(y1), tones[3], 1)
    for rr, tone in ((r, tones[2]), (r - 1, tones[3]), (r - 4, tones[1])):
        for step in range(0, 360, 2):
            a = math.radians(step)
            c.put(round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), tone)
    for k in range(paddles // 2):
        a = math.pi * k / (paddles // 2)
        line(
            c,
            round(cx - math.cos(a) * (r - 4)),
            round(cy - math.sin(a) * (r - 4)),
            round(cx + math.cos(a) * (r - 4)),
            round(cy + math.sin(a) * (r - 4)),
            tones[2],
            1,
        )
    c.ellipse(cx, cy, 2.6, 2.6, STEEL[1])
    c.ellipse(cx - 0.4, cy - 0.4, 1.4, 1.4, STEEL[3])


def prop_water_wheel():
    """Roata de apa (48x48, fara pereche in satul vechi): reperul Erei 2. Roata mare de lemn pe un picior de piatra, jgheabul
    care aduce apa de sus si spuma de la baza. Se face din scanduri si fier: exact ce produci deja [D64]."""
    c = C(48, 48)
    soft_shadow(c, 24, 45, 20, 3)
    # piciorul de piatra, in spate
    c.rect(27, 22, 14, 23, STONE[1])
    for y in range(24, 45, 4):
        c.rect(27, y, 14, 1, STONE[0])
        for x in range(27 + (y // 4) % 2 * 3, 41, 6):
            c.put(x, y + 2, STONE[0])
    c.rect(27, 22, 14, 1, STONE[3])
    c.rect(27, 22, 1, 23, STONE[2])
    # jgheabul, de sus din dreapta
    c.rect(24, 5, 24, 3, WOOD[2])
    c.rect(24, 5, 24, 1, WOOD[4])
    c.rect(26, 6, 22, 1, WATER[3])
    for px in (38, 45):
        c.rect(px, 8, 2, 14, WOOD[1])
    # roata
    _wheel_body(c, 20, 25, 17, WOOD)
    # apa care cade din jgheab si spuma de la baza
    for y in range(8, 14):
        c.put(25, y, WATER[4] if y % 2 else FOAM[4])
        c.put(24, y + 1, WATER[3])
    for x in range(6, 36, 2):
        c.put(x, 44, FOAM[4] if (x // 2) % 2 else WATER[4])
        c.put(x + 1, 45, WATER[3])
    c.rect(4, 45, 34, 1, WATER[2])
    outline_trace(c)
    return c


def prop_copper_furnace():
    """Cuptorul de cupru (64x48, perechea forjei): turn rotund de piatra cu gluga de cupru inverzit, gura aprinsa la baza,
    foalele in stanga, lingourile de cupru stivuite in dreapta, cos inalt cu brau de cupru. Forja e o casa de barne cu
    banc; asta e un furnal."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    # platforma de piatra
    c.rect(4, 40, 56, 5, STONE[1])
    c.rect(4, 40, 56, 1, STONE[3])
    for x in range(6, 60, 7):
        c.put(x, 42, STONE[0])
    # corpul furnalului
    c.rect(18, 17, 28, 24, STONE[2])
    for y in range(19, 41, 3):
        c.rect(18, y, 28, 1, STONE[1])
        for x in range(18 + (y // 3) % 2 * 3, 46, 6):
            c.put(x, y + 1, STONE[1])
    c.rect(18, 17, 2, 24, STONE[3])
    c.rect(44, 17, 2, 24, STONE[0])
    # gluga de cupru inverzit, in trepte, si cosul
    for i in range(8):
        inset = i * 2
        c.rect(15 + inset // 2, 16 - i, 34 - inset, 1, VERDIGRIS[2] if i % 2 else VERDIGRIS[3])
    c.rect(14, 16, 36, 2, VERDIGRIS[1])
    c.rect(14, 16, 36, 1, VERDIGRIS[4])
    c.rect(28, 0, 8, 9, STONE[2])
    c.rect(28, 0, 8, 1, STONE[3])
    c.rect(35, 1, 1, 8, STONE[0])
    c.rect(27, 4, 10, 2, COPPER[2])  # braul de cupru
    c.rect(27, 4, 10, 1, COPPER[4])
    # gura aprinsa
    c.ellipse(32, 33, 7.5, 7, STONE[0])
    c.rect(25, 33, 15, 8, STONE[0])
    c.ellipse(32, 33.5, 6, 5.6, EMBER[0])
    c.rect(26, 34, 12, 7, EMBER[0])
    c.ellipse(32, 36, 4.6, 4, EMBER[2])
    c.ellipse(32, 37.4, 3, 2.6, EMBER[3])
    c.rect(30, 38, 4, 2, EMBER[4])
    # jgheabul pe care curge cuprul topit, spre forma
    line(c, 38, 39, 47, 42, COPPER[3], 1)
    c.rect(46, 42, 6, 2, STONE[1])
    c.rect(47, 42, 4, 1, EMBER[3])
    # foalele, in stanga
    c.rect(5, 30, 11, 8, WOOD[2])
    c.rect(5, 30, 11, 1, WOOD[4])
    for y in (32, 34, 36):
        c.rect(5, y, 11, 1, WOOD[0])
    c.rect(16, 33, 3, 2, STEEL[2])
    c.rect(3, 28, 2, 12, WOOD[1])
    # lingourile de cupru, stivuite in dreapta
    for row, (n, y) in enumerate(((3, 38), (2, 36), (1, 34))):
        for k in range(n):
            ingot(c, 51 + k * 4 + row * 2, y, 5)
    outline_trace(c)
    return c


def prop_ore_shed():
    """Magazia de minereu (40x32, perechea Scrap Shed-ului): sopron jos cu acoperis de scanduri inverzite la streasina,
    trei gramezi de minereu cu vine verzi, tarnacopul rezemat."""
    c = C(40, 32)
    rng = Rng(6507)
    shadow(c, 20, 29, 18, 2)
    c.rect(5, 14, 30, 13, WEATHERED[1])
    for y in range(16, 27, 3):
        c.rect(5, y, 30, 1, WEATHERED[0])
    for px in (3, 35):
        c.rect(px, 8, 3, 20, WOOD[2])
        c.rect(px, 8, 1, 20, WOOD[3])
    for i in range(6):  # acoperisul de scanduri
        c.rect(1, 3 + i, 38, 1, WEATHERED[3] if i % 2 else WEATHERED[2])
    for x in range(4, 38, 6):
        c.rect(x, 3, 1, 6, WEATHERED[1])
    c.rect(0, 9, 40, 1, VERDIGRIS[1])  # streasina patata de cupru
    c.rect(0, 8, 40, 1, VERDIGRIS[3])
    # gramezile de minereu
    for cx, cy, rx, ry in ((11, 24, 5, 3.4), (20, 23, 6, 4.2), (29, 24.4, 5, 3), (15, 21, 3, 2.2), (25, 20.6, 3, 2)):
        ore_rock(c, cx, cy, rx, ry, rng)
    # tarnacopul
    line(c, 33, 27, 36, 14, WOOD[3], 1)
    c.rect(33, 13, 6, 1, STEEL[3])
    c.put(32, 14, STEEL[2])
    c.put(39, 14, STEEL[2])
    outline_trace(c)
    return c


def _bell_shape(c, cx, top, tones):
    """Clopotul (14 lat, 16 inalt), cu buza evazata."""
    for i in range(14):
        half = 3 + int(i * 0.32) + (2 if i >= 11 else 0)
        c.rect(cx - half, top + i, half * 2, 1, tones[2] if i % 5 else tones[1])
        c.put(cx - half + 1, top + i, tones[4])
        c.put(cx + half - 1, top + i, tones[0])
    c.rect(cx - 8, top + 14, 16, 2, tones[1])
    c.rect(cx - 8, top + 14, 16, 1, tones[3])
    c.ellipse(cx, top + 17, 1.6, 1.6, tones[0])  # limba


def prop_mill_bell():
    """Clopotul Morii (40x56, perechea clopotului Debarcaderului): clopot de CUPRU (nu de bronz) pe un cadru de barne prins
    in scoabe de fier, cu roata dintata a Morii in varf si soclu de caramida."""
    c = C(40, 56)
    soft_shadow(c, 20, 53, 16, 3)
    bricks(c, 6, 46, 28, 6)
    c.rect(5, 45, 30, 1, MORTAR[3])
    for px in (8, 29):
        c.rect(px, 12, 4, 34, WOOD[2])
        c.rect(px, 12, 1, 34, WOOD[4])
        c.rect(px + 3, 12, 1, 34, WOOD[0])
        c.rect(px - 1, 24, 6, 1, STEEL[1])
        c.rect(px - 1, 38, 6, 1, STEEL[1])
    c.rect(5, 10, 31, 4, WOOD[3])
    c.rect(5, 10, 31, 1, WOOD[4])
    c.rect(5, 13, 31, 1, WOOD[0])
    gear(c, 20, 6, 4.2, STEEL, teeth=8)
    c.rect(19, 14, 2, 4, STEEL[1])  # jugul
    _bell_shape(c, 20, 18, COPPER)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# ruinele: aceeasi amprenta, cazuta si napadita [D53]


def prop_ruin_mill_store():
    c = C(40, 32)
    rng = Rng(6511)
    soft_shadow(c, 20, 29, 17, 2)
    c.rect(3, 16, 3, 12, WEATHERED[1])  # un stalp inca in picioare
    c.rect(3, 16, 1, 12, WEATHERED[3])
    c.rect(34, 22, 3, 6, WEATHERED[0])  # ciotul celuilalt
    # foaia de tabla cazuta, ruginita
    for i in range(22):
        tone = RUST[2] if i % 3 == 0 else (TIN[1] if i % 3 == 1 else RUST[1])
        c.rect(9 + i, 21 + i // 5, 1, 4, tone)
    beam(c, 6, 26, 30, 18, WEATHERED, 2)
    c.rect(24, 23, 9, 5, CHAR[1])  # o lada sparta
    c.rect(24, 23, 9, 1, CHAR[3])
    scrap_heap(c, rng, 25, 23, 6)
    gear(c, 14, 26, 2.4, RUST, teeth=6)
    weeds(c, rng, 2, 38, 28, 10)
    c.put(12, 20, MOSS[3])
    c.put(20, 22, MOSS[2])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_foundry():
    c = C(40, 32)
    rng = Rng(6512)
    soft_shadow(c, 20, 29, 17, 2)
    bricks(c, 3, 19, 10, 9, CHAR)  # colt de zid, innegrit
    bricks(c, 27, 22, 10, 6, CHAR)
    for x, y in ((4, 18), (7, 17), (28, 21), (33, 21)):
        c.put(x, y, CHAR[2])
    # bolta rece, pe jumatate cazuta
    c.ellipse(19, 24, 6, 5, CHAR[0])
    c.rect(13, 24, 12, 4, CHAR[0])
    c.ellipse(19, 25, 4.4, 3.4, (34, 30, 30, 255))
    # caramizi cazute
    for x, y in ((14, 27), (17, 26), (23, 27), (25, 25), (10, 27)):
        c.rect(x, y, 3, 2, BRICK[1])
        c.put(x, y, BRICK[3])
    c.rect(30, 14, 4, 8, CHAR[1])  # ciotul hornului
    c.rect(30, 14, 4, 1, CHAR[3])
    weeds(c, rng, 2, 38, 28, 11)
    c.put(6, 20, MOSS[3])
    c.put(31, 16, MOSS[2])
    c.put(20, 21, MOSS[3])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_market():
    c = C(64, 48)
    rng = Rng(6513)
    soft_shadow(c, 32, 45, 28, 2)
    for px, top in ((4, 22), (30, 30), (57, 26)):  # stalpii ramasi, la inaltimi diferite
        c.rect(px, top, 3, 45 - top, WEATHERED[1])
        c.rect(px, top, 1, 45 - top, WEATHERED[3])
    beam(c, 5, 24, 34, 31, WEATHERED, 2)  # grinda de sus, cazuta la un capat
    # copertina rupta: fasii decolorate care atarna
    for k, x in enumerate(range(8, 28, 5)):
        h = 4 + (k * 3) % 5
        tone = mix(TEAL[2], WEATHERED[2], 0.55) if k % 2 == 0 else mix(CREAM[2], WEATHERED[2], 0.45)
        c.rect(x, 26 + k, 4, h, tone)
        c.put(x + 1, 26 + k + h, tone)
    # tejgheaua rupta in doua
    c.rect(8, 38, 20, 3, WEATHERED[2])
    c.rect(8, 38, 20, 1, WEATHERED[4])
    beam(c, 32, 44, 54, 37, WEATHERED, 3)
    # olane cazute si o roata dintata ruginita
    for x, y in ((36, 43), (40, 44), (45, 43), (22, 43), (14, 44)):
        c.rect(x, y, 3, 1, TILE[1])
        c.put(x, y, TILE[3])
    gear(c, 50, 41, 2.6, RUST, teeth=8)
    weeds(c, rng, 2, 62, 45, 18)
    for x, y in ((5, 30), (31, 33), (58, 30), (12, 37)):
        c.put(x, y, MOSS[3])
    outline_bottom(c, 0, 0, 64, 47)
    return c


def prop_ruin_water_wheel():
    """Roata cazuta: jumatate ingropata, cu palete lipsa, piciorul de piatra surpat, jgheabul rupt."""
    c = C(48, 48)
    rng = Rng(6514)
    soft_shadow(c, 24, 45, 19, 3)
    c.rect(29, 32, 12, 13, STONE[1])  # piciorul, surpat
    c.rect(29, 32, 12, 1, STONE[3])
    for x, y in ((31, 31), (34, 30), (38, 31)):
        c.put(x, y, STONE[2])
    for x, y in ((24, 43), (27, 44), (43, 44)):  # pietre cazute
        c.rect(x, y, 3, 2, STONE[1])
        c.put(x, y, STONE[3])
    _wheel_body(c, 19, 33, 14, WEATHERED, paddles=10, missing=(0, 1, 5, 8))
    # partea de jos a rotii e in pamant: o stergem sub linia solului
    for y in range(45, 48):
        for x in range(48):
            c.px[y][x] = (0, 0, 0, 0)
    beam(c, 30, 22, 46, 30, WEATHERED, 2)  # jgheabul rupt
    weeds(c, rng, 2, 46, 45, 14)
    for x, y in ((12, 24), (22, 21), (9, 35), (27, 38)):
        c.put(x, y, MOSS[3])
        c.put(x + 1, y, MOSS[2])
    outline_bottom(c, 0, 0, 48, 46)
    return c


def prop_ruin_copper_furnace():
    c = C(64, 48)
    rng = Rng(6515)
    soft_shadow(c, 32, 45, 28, 2)
    c.rect(4, 41, 56, 4, STONE[0])  # platforma, crapata
    c.rect(4, 41, 56, 1, STONE[2])
    for x in (16, 33, 47):
        c.rect(x, 41, 1, 4, (44, 44, 50, 255))
    # inelul de la baza furnalului, rupt
    c.rect(19, 30, 9, 11, STONE[1])
    c.rect(19, 30, 9, 1, STONE[3])
    c.rect(37, 34, 8, 7, STONE[1])
    c.rect(37, 34, 8, 1, STONE[3])
    c.ellipse(32, 38, 5, 3.4, (34, 30, 30, 255))  # gura rece
    # gluga de cupru, cazuta pe o parte, verde de tot
    for i in range(7):
        c.rect(42 + i, 26 + i, 12 - i, 1, VERDIGRIS[1] if i % 2 else VERDIGRIS[2])
    c.rect(41, 33, 16, 2, VERDIGRIS[0])
    c.put(44, 27, VERDIGRIS[4])
    for x, y in ((12, 39), (15, 40), (29, 40), (50, 39), (9, 40)):  # pietre risipite
        c.rect(x, y, 3, 2, STONE[2])
        c.put(x, y, STONE[3])
    beam(c, 5, 38, 17, 33, CHAR, 2)  # bratul foalelor
    weeds(c, rng, 2, 62, 45, 18)
    for x, y in ((21, 31), (39, 35), (25, 33)):
        c.put(x, y, MOSS[3])
    outline_bottom(c, 0, 0, 64, 47)
    return c


def prop_ruin_ore_shed():
    c = C(40, 32)
    rng = Rng(6516)
    soft_shadow(c, 20, 29, 17, 2)
    c.rect(35, 15, 3, 13, WEATHERED[1])
    c.rect(35, 15, 1, 13, WEATHERED[3])
    c.rect(3, 23, 3, 5, WEATHERED[0])
    beam(c, 4, 20, 34, 26, WEATHERED, 3)  # acoperisul cazut
    beam(c, 8, 24, 30, 27, WEATHERED, 2)
    for cx, cy, rx, ry in ((12, 26, 4, 2.4), (27, 25, 3, 2)):
        ore_rock(c, cx, cy, rx, ry, rng)
    weeds(c, rng, 2, 38, 28, 10)
    c.put(15, 21, MOSS[3])
    c.put(28, 24, MOSS[2])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_mill_bell():
    c = C(40, 56)
    rng = Rng(6517)
    soft_shadow(c, 20, 53, 16, 3)
    bricks(c, 6, 47, 28, 5, CHAR)
    c.rect(29, 28, 4, 19, WEATHERED[1])  # un stalp ramas
    c.rect(29, 28, 1, 19, WEATHERED[3])
    c.rect(8, 42, 4, 5, WEATHERED[0])
    beam(c, 5, 50, 33, 36, WEATHERED, 3)
    # clopotul, pe o parte, inverzit
    c.ellipse(19, 44, 7, 5.4, VERDIGRIS[1])
    c.ellipse(17, 42.4, 3.6, 2.6, VERDIGRIS[3])
    c.ellipse(26, 45, 2.4, 6, VERDIGRIS[0])
    c.ellipse(25.4, 45, 1.4, 4.4, VERDIGRIS[2])
    c.put(15, 41, VERDIGRIS[4])
    gear(c, 9, 50, 2.4, RUST, teeth=6)
    weeds(c, rng, 2, 38, 52, 10)
    outline_bottom(c, 0, 0, 40, 55)
    return c


# ---------------------------------------------------------------------------------------------
# marfa (24x18, ca restul din Assets.goods)


def goods_parts():
    """Piese de masini: o roata dintata mare, una mica si un surub -- otel curat, nu fier vechi."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 9, 2)
    gear(c, 9, 8, 5.4, STEEL, teeth=10)
    gear(c, 17, 11, 3.2, STEEL, teeth=8)
    c.rect(18, 3, 2, 5, STEEL[2])  # surubul
    c.rect(17, 2, 4, 2, STEEL[3])
    c.put(17, 2, STEEL[4])
    outline_trace(c)
    return c


def goods_ore():
    """Minereu de cupru: doi bolovani maronii cu vine verzi-albastre."""
    c = C(24, 18)
    rng = Rng(6521)
    soft_shadow(c, 12, 15, 9, 2)
    ore_rock(c, 9, 10, 6.4, 4.6, rng)
    ore_rock(c, 17, 11.4, 4.2, 3.2, rng)
    ore_rock(c, 13, 6, 3.4, 2.6, rng)
    outline_trace(c)
    return c


def goods_copper():
    """Cupru: trei lingouri portocalii, stivuite."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 9, 2)
    for x, y in ((3, 11), (12, 11), (7, 7)):
        c.rect(x, y, 9, 4, COPPER[2])
        c.rect(x + 1, y, 7, 1, COPPER[4])
        c.rect(x, y + 1, 9, 1, COPPER[3])
        c.rect(x, y + 3, 9, 1, COPPER[0])
        c.put(x + 8, y + 1, COPPER[1])
    outline_trace(c)
    return c


SPRITES = {
    "prop_mill_store": prop_mill_store,
    "prop_foundry": prop_foundry,
    "prop_market": prop_market,
    "prop_water_wheel": prop_water_wheel,
    "prop_copper_furnace": prop_copper_furnace,
    "prop_ore_shed": prop_ore_shed,
    "prop_mill_bell": prop_mill_bell,
    "prop_ruin_mill_store": prop_ruin_mill_store,
    "prop_ruin_foundry": prop_ruin_foundry,
    "prop_ruin_market": prop_ruin_market,
    "prop_ruin_water_wheel": prop_ruin_water_wheel,
    "prop_ruin_copper_furnace": prop_ruin_copper_furnace,
    "prop_ruin_ore_shed": prop_ruin_ore_shed,
    "prop_ruin_mill_bell": prop_ruin_mill_bell,
    "goods_parts": goods_parts,
    "goods_ore": goods_ore,
    "goods_copper": goods_copper,
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
