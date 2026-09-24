#!/usr/bin/env python3
"""Arta pentru D67, lotul A: cladirile Wire Works, ruinele lor, turbina, marfa noua si felinarele.

Era 3 e Moara in oglinda, deci fiecare cladire are o pereche in Moara si ia EXACT panza ei (aceeasi amprenta pe harta,
aceleasi cutii in TycoonConfig). Dar Wire Works e alt loc si alta vreme: satul e lemn si paie, Moara e caramida, tabla
si cupru; Wire Works e FIER NITUIT, STICLA, ALAMA si PORTELAN, cu lumina albastra a curentului. De la prima privire
trebuie sa se vada ca ai trecut gardul:

  prop_works_store     40x32  (perechea: magazia Morii)    sopron de fier nituit, lazi cu minereu de cupru, cablu
  prop_wire_works      40x32  (perechea: turnatoria)       hala cu acoperis in dinti de fierastrau si luminatoare,
                                                           tamburul de sarma in fata, cureaua de la masina cu abur
  prop_depot           64x48  (perechea: Piata)            gara mica: acoperis lung, ceas in fronton, peron cu bobine
                                                           si borcane, firma cu fulger
  prop_steam_engine    48x48  (fara pereche)               cazanul nituit pe soclu de caramida, cosul negru, volantul,
                                                           manometrul de alama, un pufait de abur [D64: din piese si cupru]
  prop_power_house     64x48  (perechea: cuptorul de cupru) casa de caramida cu ferestre inalte luminate albastru,
                                                           izolatori pe coama, dinamul de cupru, fulgerul peste usa
  prop_battery_shed    40x32  (perechea: magazia de minereu) sopron cu raftul de borcane-baterii
  prop_works_bell      40x56  (perechea: clopotul Morii)   clopot de alama pe turn de zabrele, paratrasnet in varf
  prop_turbine         48x48  (fara pereche)               prima turbina: roata de fier cu dinamul de cupru la ax si
                                                           firul pe un stalp cu izolator [D64: "bobine + roata"]
  prop_ruin_*          aceeasi panza cu cladirea          ce a ramas din ele [D53]
  goods_coils / goods_battery / goods_cell  24x18         bobina de sarma, bateria (borcan), celula de energie
  prop_street_lamp / prop_street_lamp_lit   12x40         felinarul de pe strada, stins si aprins [D67]
  prop_lamp_glow       32x32                               lumina din jurul felinarului aprins (alfa moale)

Aceleasi reguli ca restul conductei: culorile din palette.ramp(), umbra din elipse translucide, conturul trasat automat,
niciodata negru pur. NU suprascrie un sprite existent fara --force.

Rulare: python3 scripts/art/d67_works.py [--force]   (apoi preview_d67.py pentru plansa)
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
from tycoon_e1 import PLANK, WARM, STEEL, outline_trace  # noqa: E402
from ruins_d53 import MOSS, CHAR, beam, line, weeds  # noqa: E402
import d65_mill as M  # noqa: E402

OUT = M.OUT

# materialele Wire Works
IRON = ramp(214, 0.20, 0.44, val_span=0.40)  # placile de fier nituit, gri-albastrui inchis
SOOT = ramp(28, 0.10, 0.28, val_span=0.30)  # cosul masinii cu abur
GLASS = ramp(190, 0.34, 0.80)  # luminatoarele si ferestrele
BRASS = ramp(44, 0.62, 0.76, hue_shift=6)  # manometrul, clopotul, niturile de pe firma
SPARK = ramp(198, 0.74, 0.96)  # lumina curentului: albastru-alb
SIGNAL = ramp(50, 0.86, 0.92)  # fulgerul de pe firme
COPPER, BRICK, MORTAR, VERDIGRIS = M.COPPER, M.BRICK, M.MORTAR, M.VERDIGRIS


# ---------------------------------------------------------------------------------------------
# bucati comune


def iron_plates(c, x, y, w, h, tones=IRON, rivet=None):
    """Perete de placi de fier: fasii de 6 px cu nituri pe rosturi. `rivet` = tonul niturilor (implicit un ton deschis)."""
    rivet = rivet or tones[3]
    c.rect(x, y, w, h, tones[2])
    for yy in range(y, y + h, 6):
        c.rect(x, yy, w, 1, tones[1])
        for xx in range(x + 2, x + w - 1, 4):
            c.put(xx, yy + 1, rivet)
    for xx in range(x + 9, x + w, 10):
        c.rect(xx, y, 1, h, tones[1])
    c.rect(x, y, 1, h, tones[3])
    c.rect(x + w - 1, y, 1, h, tones[0])


def insulator(c, x, y):
    """Un izolator de portelan (3x3) pe un picior de fier."""
    c.rect(x, y + 3, 1, 2, IRON[1])
    c.rect(x - 1, y, 3, 3, CREAM[3])
    c.put(x - 1, y, CREAM[4])
    c.put(x + 1, y + 2, CREAM[1])


def bolt(c, x, y, tones=SIGNAL, big=False):
    """Fulgerul (5x7, sau 7x10 cu `big`): semnul curentului pe firme."""
    pts = ((2, 0), (3, 0), (1, 1), (2, 1), (0, 2), (1, 2), (0, 3), (1, 3), (2, 3), (3, 3), (2, 4), (3, 4), (1, 5),
           (2, 5), (1, 6))
    k = 1.4 if big else 1.0
    for px, py in pts:
        c.rect(x + round(px * k), y + round(py * k), 2 if big else 1, 2 if big else 1, tones[3])
    c.put(x + round(2 * k), y, tones[4])


def coil(c, x, y, w, h, tones=COPPER, flange=WOOD):
    """Tamburul cu sarma de cupru: flanse de lemn la capete, spire de cupru la mijloc."""
    c.rect(x, y, 2, h, flange[2])
    c.rect(x, y, 1, h, flange[4])
    c.rect(x + w - 2, y, 2, h, flange[1])
    for i in range(x + 2, x + w - 2):
        c.rect(i, y + 1, 1, h - 2, tones[3] if (i - x) % 2 else tones[2])
    c.rect(x + 2, y + 1, w - 4, 1, tones[4])
    c.rect(x + 2, y + h - 2, w - 4, 1, tones[1])


def jar(c, x, y, lit=True):
    """Borcanul-baterie (5x7): sticla, doua placi (cupru si zinc), capacul de lemn, o scanteie deasupra."""
    c.rect(x, y + 1, 5, 6, GLASS[1])
    c.rect(x + 1, y + 2, 1, 4, COPPER[3])
    c.rect(x + 3, y + 2, 1, 4, STEEL[3])
    c.rect(x, y + 1, 1, 6, GLASS[3])
    c.rect(x, y, 5, 1, WOOD[2])
    c.put(x + 1, y - 1, COPPER[2])
    c.put(x + 3, y - 1, STEEL[2])
    if lit:
        c.put(x + 2, y - 2, SPARK[4])


def flywheel(c, cx, cy, r, tones=IRON, spokes=6):
    """Volantul: obada groasa, spite, butucul."""
    for k in range(spokes):
        a = 2 * math.pi * k / spokes + 0.3
        line(c, round(cx), round(cy), round(cx + math.cos(a) * (r - 1)), round(cy + math.sin(a) * (r - 1)), tones[1], 1)
    for rr, tone in ((r, tones[1]), (r - 1, tones[3]), (r - 2, tones[2])):
        for step in range(0, 360, 3):
            a = math.radians(step)
            c.put(round(cx + math.cos(a) * rr), round(cy + math.sin(a) * rr), tone)
    c.ellipse(cx, cy, 1.6, 1.6, BRASS[2])
    c.put(round(cx - 0.6), round(cy - 0.6), BRASS[4])


def steam_puff(c, cx, cy, r):
    """Un nor mic de abur, alb-cenusiu."""
    c.ellipse(cx, cy, r, r * 0.8, FOAM[3])
    c.ellipse(cx - r * 0.5, cy + r * 0.2, r * 0.7, r * 0.6, FOAM[4])
    c.ellipse(cx + r * 0.6, cy + r * 0.1, r * 0.6, r * 0.5, FOAM[2])


# ---------------------------------------------------------------------------------------------
# cladirile


def prop_works_store():
    """Works Store (40x32, perechea magaziei Morii): sopron de fier nituit cu acoperis intr-o apa, doua lazi cu minereu de
    cupru si un colac de cablu atarnat. Magazia Morii e tabla si scanduri; asta e fier."""
    c = C(40, 32)
    rng = Rng(6701)
    shadow(c, 20, 29, 18, 2)
    iron_plates(c, 5, 9, 30, 18)
    for px, top in ((3, 4), (35, 9)):  # stalpii de fier
        c.rect(px, top, 3, 28 - top, IRON[1])
        c.rect(px, top, 1, 28 - top, IRON[3])
    for i in range(40):  # acoperisul nituit, intr-o apa
        drop = int(5 * i / 39)
        c.rect(i, drop, 1, 7, IRON[2] if i % 4 else IRON[1])
        c.put(i, drop, IRON[4])
        c.put(i, drop + 6, IRON[0])
        if i % 4 == 2:
            c.put(i, drop + 3, BRASS[2])
    # colacul de cablu, in cui pe perete
    for step in range(0, 360, 20):
        a = math.radians(step)
        c.put(round(29 + math.cos(a) * 3), round(13 + math.sin(a) * 2), COPPER[2])
    c.put(29, 10, IRON[0])
    # doua lazi cu minereu
    for bx in (7, 20):
        c.rect(bx, 18, 12, 9, PLANK[1])
        c.rect(bx, 18, 12, 1, PLANK[3])
        c.rect(bx, 18, 1, 9, PLANK[2])
        c.rect(bx + 11, 18, 1, 9, PLANK[0])
        c.rect(bx, 23, 12, 1, IRON[1])  # cercul de fier
        for k in range(3):
            M.ore_rock(c, bx + 3 + k * 3, 17, 2.2, 1.6, rng)
    outline_trace(c)
    return c


def prop_wire_works():
    """Wire Works (40x32, perechea turnatoriei): hala cu acoperis in dinti de fierastrau, luminatoare de sticla pe fata
    abrupta a fiecarui dinte, hornul in dreapta, tamburul mare de sarma in fata si cureaua de la masina cu abur, din
    stanga. Turnatoria e foc inchis in caramida; asta e o fabrica luminoasa."""
    c = C(40, 32)
    shadow(c, 20, 29, 18, 2)
    iron_plates(c, 3, 12, 34, 16)
    # dintii acoperisului: trei, fiecare cu luminatorul lui
    for k, x0 in enumerate((3, 14, 25)):
        for i in range(11):
            h = 1 + int(i * 0.55)
            c.rect(x0 + i, 12 - h, 1, h, IRON[2] if i % 2 else IRON[3])
        c.rect(x0 + 10, 5, 1, 7, IRON[0])
        c.rect(x0 + 8, 6, 2, 6, GLASS[2])  # sticla pe fata abrupta
        c.put(x0 + 8, 6, GLASS[4])
    c.rect(2, 12, 36, 1, IRON[0])
    # hornul, subtire, de fier (fumul: LineController.SMOKE_AT.wireworks, 0.79 x 0.02)
    c.rect(30, 0, 4, 8, SOOT[2])
    c.rect(30, 0, 1, 8, SOOT[4])
    c.rect(29, 0, 6, 1, SOOT[1])
    # usa larga, cu lumina calda inauntru
    c.rect(24, 18, 9, 10, IRON[0])
    c.rect(25, 19, 7, 9, WARM[1])
    c.rect(25, 19, 7, 1, WARM[3])
    # tamburul de sarma, in fata
    coil(c, 6, 20, 14, 8)
    c.rect(12, 28, 2, 1, IRON[0])
    # cureaua de transmisie, din stanga (vine de la masina cu abur)
    line(c, 0, 15, 6, 22, SOOT[1], 1)
    line(c, 0, 17, 6, 26, SOOT[2], 1)
    outline_trace(c)
    return c


def prop_depot():
    """Depoul (64x48, perechea Pietei): o gara mica. Acoperis lung de ardezie, ceas in fronton, peron cu bobine si borcane
    gata de plecare, firma cu fulgerul si bobina. Piata e o taraba deschisa; Depoul e o cladire cu program."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    # corpul, caramida pe jos, scanduri deasupra
    M.bricks(c, 4, 30, 56, 15)
    c.rect(4, 17, 56, 13, WOOD[1])
    for y in range(19, 30, 3):
        c.rect(4, y, 56, 1, WOOD[0])
    # acoperisul lung, ardezie gri-albastra (in doua ape) si frontonul cu ceasul
    for i in range(12):
        x0 = 12 - i
        c.rect(x0, 3 + i, 64 - 2 * x0, 1, IRON[2] if i % 2 else IRON[3])
    c.rect(0, 15, 64, 2, IRON[0])
    c.rect(12, 2, 40, 1, IRON[4])
    c.ellipse(32, 9, 3.6, 3.6, CREAM[3])  # ceasul
    c.ellipse(32, 9, 2.6, 2.6, CREAM[4])
    c.rect(32, 7, 1, 2, IRON[0])
    c.rect(32, 9, 2, 1, IRON[0])
    # ferestrele inalte, luminate
    for wx in (9, 19, 41, 51):
        c.rect(wx, 20, 5, 8, GLASS[1])
        c.rect(wx, 20, 5, 1, GLASS[4])
        c.rect(wx + 2, 20, 1, 8, IRON[1])
    # usa mare, in mijloc
    c.rect(27, 21, 10, 24, IRON[1])
    c.rect(28, 22, 8, 23, WARM[1])
    c.rect(28, 22, 8, 2, WARM[3])
    # firma: fulgerul si o bobina, pe scandura cu nituri de alama
    c.rect(22, 16, 20, 5, (60, 40, 26, 255))
    c.rect(23, 17, 18, 3, WOOD[3])
    bolt(c, 25, 16)
    coil(c, 31, 17, 8, 3)
    for nx in (23, 40):
        c.put(nx, 17, BRASS[4])
    # peronul in fata: bobine si borcane gata de plecare
    c.rect(2, 40, 22, 5, PLANK[2])
    c.rect(2, 40, 22, 1, PLANK[4])
    coil(c, 4, 34, 7, 6)
    coil(c, 12, 35, 6, 5)
    c.rect(40, 40, 22, 5, PLANK[2])
    c.rect(40, 40, 22, 1, PLANK[4])
    for jx in (42, 48, 54):
        jar(c, jx, 33)
    # felinarul electric, in dreapta usii
    c.rect(38, 24, 1, 6, IRON[1])
    c.rect(37, 22, 3, 3, SPARK[3])
    c.put(38, 22, SPARK[4])
    outline_trace(c)
    return c


def prop_steam_engine():
    """Masina cu abur (48x48, fara pereche): cazanul nituit culcat pe un soclu de caramida, cosul inalt si negru cu brau
    de alama, volantul mare in dreapta, manometrul si un pufait de abur. Se face din piese de masini si cupru: exact ce
    produce Moara [D64]."""
    c = C(48, 48)
    soft_shadow(c, 24, 45, 21, 3)
    M.bricks(c, 4, 36, 40, 9)  # soclul
    c.rect(3, 35, 42, 1, MORTAR[3])
    # cazanul: un cilindru culcat, nituit
    c.rect(8, 22, 26, 13, IRON[2])
    c.rect(8, 22, 26, 2, IRON[3])
    c.rect(8, 24, 26, 1, IRON[4])
    c.rect(8, 33, 26, 2, IRON[1])
    for x in (13, 20, 27):
        c.rect(x, 22, 1, 13, IRON[1])
        for y in range(23, 34, 3):
            c.put(x + 1, y, BRASS[3])
    c.ellipse(8, 28.5, 2.6, 6.4, IRON[1])  # capacul rotunjit din stanga
    c.ellipse(7.4, 27.5, 1.4, 4.6, IRON[3])
    # cosul, inalt, cu brau de alama
    c.rect(10, 2, 6, 20, SOOT[2])
    c.rect(10, 2, 1, 20, SOOT[4])
    c.rect(15, 2, 1, 20, SOOT[0])
    c.rect(9, 1, 8, 2, SOOT[1])
    c.rect(9, 12, 8, 2, BRASS[2])
    c.rect(9, 12, 8, 1, BRASS[4])
    steam_puff(c, 14, 0, 2.2)
    # volantul, in dreapta, cu biela spre cazan
    flywheel(c, 38, 26, 8.5)
    line(c, 33, 28, 38, 26, STEEL[3], 1)
    # manometrul de alama si supapa cu abur
    c.ellipse(24, 18.5, 2.6, 2.6, BRASS[2])
    c.ellipse(24, 18.5, 1.6, 1.6, CREAM[4])
    c.put(25, 18, IRON[0])
    c.rect(23, 21, 2, 1, BRASS[1])
    c.rect(29, 18, 2, 4, STEEL[2])
    steam_puff(c, 31, 15, 2.6)
    # cureaua spre Wire Works, pleaca spre dreapta
    line(c, 38, 18, 47, 16, SOOT[1], 1)
    line(c, 38, 34, 47, 32, SOOT[2], 1)
    outline_trace(c)
    return c


def prop_power_house():
    """Power House (64x48, perechea cuptorului de cupru): casa de caramida cu trei ferestre inalte, boltite, luminate
    albastru dinauntru, izolatori pe coama si firele care pleaca spre dreapta, dinamul de cupru pe soclu in stanga,
    fulgerul galben peste usa, hornul la mijloc (acolo iese fumul: LineController.SMOKE_AT.powerhouse, 0.5 x 0.0)."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    c.rect(4, 40, 56, 5, STONE[1])  # platforma de piatra
    c.rect(4, 40, 56, 1, STONE[3])
    M.bricks(c, 16, 16, 40, 24)
    # acoperisul in doua ape, fier
    for i in range(7):
        inset = 6 - i
        c.rect(14 + inset, 9 + i, 44 - 2 * inset, 1, IRON[2] if i % 2 else IRON[3])
    c.rect(13, 16, 46, 1, IRON[0])
    # hornul, la mijloc
    c.rect(30, 0, 5, 10, SOOT[2])
    c.rect(30, 0, 1, 10, SOOT[4])
    c.rect(29, 0, 7, 1, SOOT[1])
    # izolatorii de pe coama si firele
    for ix in (20, 44, 52):
        insulator(c, ix, 5)
    line(c, 44, 5, 52, 5, IRON[0], 1)
    line(c, 52, 5, 63, 8, IRON[0], 1)
    # ferestrele inalte, boltite, luminate de curent
    for wx in (20, 36):
        c.ellipse(wx + 3, 22, 3.2, 3, SPARK[2])
        c.rect(wx, 22, 7, 10, SPARK[2])
        c.rect(wx + 1, 23, 5, 8, SPARK[3])
        c.rect(wx + 3, 20, 1, 12, IRON[1])
        c.rect(wx, 26, 7, 1, IRON[1])
        c.put(wx + 1, 23, SPARK[4])
    # usa, cu fulgerul deasupra
    c.rect(46, 25, 7, 15, IRON[1])
    c.rect(47, 26, 5, 14, IRON[0])
    bolt(c, 47, 17, big=True)
    # dinamul de cupru, pe soclul lui in stanga
    c.rect(2, 34, 14, 6, STONE[2])
    c.rect(2, 34, 14, 1, STONE[3])
    coil(c, 3, 24, 12, 10, flange=IRON)
    c.rect(14, 28, 3, 2, STEEL[2])  # axul, spre casa
    line(c, 9, 24, 16, 18, COPPER[1], 1)  # cablul, in perete
    outline_trace(c)
    return c


def prop_battery_shed():
    """Battery Shed (40x32, perechea magaziei de minereu): sopron uscat cu acoperis de fier intr-o apa, raftul de lemn pe
    doua randuri cu borcane-baterii, fiecare cu scanteia ei."""
    c = C(40, 32)
    shadow(c, 20, 29, 18, 2)
    c.rect(5, 12, 30, 15, WEATHERED[1])
    for y in range(14, 27, 3):
        c.rect(5, y, 30, 1, WEATHERED[0])
    for px in (3, 35):
        c.rect(px, 7, 3, 21, IRON[1])
        c.rect(px, 7, 1, 21, IRON[3])
    for i in range(40):  # acoperisul
        drop = int(3 * (39 - i) / 39)
        c.rect(i, 3 + drop, 1, 6, IRON[2] if i % 3 else IRON[3])
        c.put(i, 3 + drop, IRON[4])
    c.rect(0, 9, 40, 1, IRON[0])
    # raftul si borcanele
    for ry in (18, 25):
        c.rect(6, ry, 28, 1, PLANK[3])
        c.rect(6, ry + 1, 28, 1, PLANK[1])
    for k in range(5):
        jar(c, 8 + k * 5, 11)
        jar(c, 8 + k * 5, 18, lit=k % 2 == 0)
    outline_trace(c)
    return c


def prop_works_bell():
    """Works Bell (40x56, perechea clopotului Morii): clopot de ALAMA pe un turn de zabrele de fier, izolator si
    paratrasnet in varf, soclu de piatra. Clopotul satului e pe barne, al Morii pe barne cu roata dintata; asta e fier."""
    c = C(40, 56)
    soft_shadow(c, 20, 53, 16, 3)
    c.rect(6, 46, 28, 6, STONE[2])
    c.rect(6, 46, 28, 1, STONE[3])
    for x in range(8, 34, 5):
        c.put(x, 49, STONE[0])
    # cele doua picioare si zabrelele dintre ele
    for px in (9, 29):
        c.rect(px, 12, 3, 34, IRON[2])
        c.rect(px, 12, 1, 34, IRON[4])
    for y0 in range(14, 44, 8):
        line(c, 11, y0, 29, y0 + 7, IRON[1], 1)
        line(c, 29, y0, 11, y0 + 7, IRON[1], 1)
    c.rect(6, 10, 29, 3, IRON[3])
    c.rect(6, 10, 29, 1, IRON[4])
    # paratrasnetul, cu izolatorul lui
    c.rect(20, 0, 1, 9, STEEL[3])
    c.put(20, 0, BRASS[4])
    insulator(c, 20, 5)
    c.rect(19, 13, 3, 4, IRON[1])  # jugul
    M._bell_shape(c, 20, 17, BRASS)
    outline_trace(c)
    return c


def prop_turbine(phase=0.0):
    """Prima turbina (48x48, fara pereche): o roata de fier cu palete, in apa, cu DINAMUL DE CUPRU la ax (bobinele pe
    care le trage Wire Works) si firul care urca pe un stalp cu izolator. Roadmap-ul: "bobine + roata" [D64]."""
    c = C(48, 48)
    soft_shadow(c, 24, 45, 20, 3)
    # stalpul cu izolatorul si firul, in dreapta
    c.rect(40, 6, 2, 38, WOOD[2])
    c.rect(40, 6, 1, 38, WOOD[4])
    c.rect(37, 8, 8, 1, WOOD[1])
    insulator(c, 38, 4)
    insulator(c, 44, 4)
    line(c, 24, 25, 38, 5, COPPER[2], 1)
    # roata, fier, cu palete
    M._wheel_body(c, 20, 25, 16, IRON, paddles=12, phase=phase)
    # dinamul de cupru la ax: spire concentrice, capac de alama
    for rr, tone in ((5.2, COPPER[1]), (4.4, COPPER[3]), (3.4, COPPER[2]), (2.4, COPPER[4])):
        c.ellipse(20, 25, rr, rr, tone)
    c.ellipse(20, 25, 1.4, 1.4, BRASS[3])
    c.put(19, 24, SPARK[4])  # o scanteie: curentul se face aici
    # apa din jur si spuma
    for x in range(4, 38, 2):
        c.put(x, 44, FOAM[4] if (x // 2) % 2 else WATER[4])
        c.put(x + 1, 45, WATER[3])
    c.rect(2, 45, 36, 1, WATER[2])
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# ruinele: aceeasi amprenta, cazuta si napadita [D53]


def prop_ruin_works_store():
    c = C(40, 32)
    rng = Rng(6711)
    soft_shadow(c, 20, 29, 17, 2)
    c.rect(3, 15, 3, 13, IRON[1])  # un stalp de fier inca in picioare, ruginit
    c.rect(3, 15, 1, 13, RUST[3])
    c.rect(34, 22, 3, 6, RUST[1])
    for i in range(24):  # placa de acoperis cazuta, ruginita
        tone = RUST[2] if i % 3 == 0 else (IRON[1] if i % 3 == 1 else RUST[1])
        c.rect(8 + i, 20 + i // 6, 1, 4, tone)
    beam(c, 6, 26, 32, 20, WEATHERED, 2)
    c.rect(23, 23, 10, 5, CHAR[1])  # o lada sparta cu minereu
    c.rect(23, 23, 10, 1, CHAR[3])
    M.ore_rock(c, 27, 23, 2.4, 1.6, rng)
    weeds(c, rng, 2, 38, 28, 10)
    c.put(12, 19, MOSS[3])
    c.put(20, 21, MOSS[2])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_wire_works():
    c = C(40, 32)
    rng = Rng(6712)
    soft_shadow(c, 20, 29, 17, 2)
    # un dinte de acoperis ramas, cu sticla sparta
    for i in range(10):
        h = 1 + int(i * 0.5)
        c.rect(4 + i, 20 - h, 1, h, RUST[1] if i % 2 else IRON[1])
    c.rect(4, 20, 12, 8, IRON[1])
    c.rect(12, 14, 2, 4, GLASS[0])
    c.put(12, 14, GLASS[2])
    c.rect(28, 19, 8, 9, IRON[0])  # coltul halei
    c.rect(28, 19, 8, 1, RUST[3])
    # tamburul rasturnat, cu sarma desirata
    c.ellipse(21, 25, 4, 3, WOOD[1])
    c.ellipse(21, 25, 2.4, 1.8, RUST[2])
    for k in range(6):
        c.put(24 + k, 26 + (k % 2), COPPER[1])
    weeds(c, rng, 2, 38, 28, 11)
    c.put(6, 21, MOSS[3])
    c.put(30, 20, MOSS[2])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_depot():
    c = C(64, 48)
    rng = Rng(6713)
    soft_shadow(c, 32, 45, 28, 2)
    M.bricks(c, 4, 36, 18, 9, CHAR)  # soclul, pe bucati
    M.bricks(c, 40, 38, 20, 7, CHAR)
    for px, top in ((5, 24), (57, 28)):  # stalpii ramasi
        c.rect(px, top, 3, 45 - top, WEATHERED[1])
        c.rect(px, top, 1, 45 - top, WEATHERED[3])
    beam(c, 6, 26, 36, 36, WEATHERED, 2)  # grinda acoperisului, cazuta
    # ceasul cazut, cu cadranul crapat
    c.ellipse(30, 41, 3.4, 3.4, CREAM[1])
    c.ellipse(30, 41, 2.4, 2.4, CREAM[3])
    line(c, 28, 40, 32, 42, CHAR[0], 1)
    # ardezie cazuta
    for x, y in ((24, 43), (36, 44), (44, 43), (15, 44), (50, 44)):
        c.rect(x, y, 3, 1, IRON[2])
        c.put(x, y, IRON[4])
    weeds(c, rng, 2, 62, 45, 18)
    for x, y in ((6, 30), (58, 33), (12, 37)):
        c.put(x, y, MOSS[3])
    outline_bottom(c, 0, 0, 64, 47)
    return c


def prop_ruin_steam_engine():
    c = C(48, 48)
    rng = Rng(6714)
    soft_shadow(c, 24, 45, 19, 3)
    M.bricks(c, 6, 39, 30, 6, CHAR)  # soclul surpat
    # cazanul, culcat pe o parte, ruginit
    c.rect(10, 30, 22, 9, RUST[1])
    c.rect(10, 30, 22, 2, RUST[3])
    for x in (15, 22):
        c.rect(x, 30, 1, 9, RUST[0])
    c.ellipse(10, 34.5, 2, 4.4, RUST[0])
    # cosul cazut
    beam(c, 30, 44, 46, 30, SOOT, 3)
    # volantul, cu spite rupte, in iarba
    for step in range(0, 360, 4):
        a = math.radians(step)
        if 200 < step < 330:
            continue
        c.put(round(38 + math.cos(a) * 5), round(39 + math.sin(a) * 5), IRON[1])
    weeds(c, rng, 2, 46, 45, 14)
    for x, y in ((12, 29), (24, 31), (8, 38)):
        c.put(x, y, MOSS[3])
    outline_bottom(c, 0, 0, 48, 46)
    return c


def prop_ruin_power_house():
    c = C(64, 48)
    rng = Rng(6715)
    soft_shadow(c, 32, 45, 28, 2)
    c.rect(4, 41, 56, 4, STONE[0])
    c.rect(4, 41, 56, 1, STONE[2])
    M.bricks(c, 16, 28, 12, 13, CHAR)  # coltul zidului
    M.bricks(c, 44, 32, 12, 9, CHAR)
    # o fereastra boltita goala
    c.ellipse(22, 31, 2.6, 2.4, (34, 30, 30, 255))
    c.rect(20, 31, 5, 7, (34, 30, 30, 255))
    # dinamul rasturnat, cu sarma desirata
    c.ellipse(9, 38, 5, 3.4, COPPER[1])
    c.ellipse(9, 37.4, 3.4, 2.2, VERDIGRIS[2])
    for k in range(7):
        c.put(14 + k, 39 + (k % 2), COPPER[1])
    # izolatori sparti, in iarba
    for x, y in ((34, 42), (38, 43), (52, 42)):
        c.rect(x, y, 2, 1, CREAM[2])
    beam(c, 30, 40, 42, 34, WEATHERED, 2)
    weeds(c, rng, 2, 62, 45, 18)
    for x, y in ((18, 29), (46, 33)):
        c.put(x, y, MOSS[3])
    outline_bottom(c, 0, 0, 64, 47)
    return c


def prop_ruin_battery_shed():
    c = C(40, 32)
    rng = Rng(6716)
    soft_shadow(c, 20, 29, 17, 2)
    c.rect(35, 14, 3, 14, IRON[1])
    c.rect(35, 14, 1, 14, RUST[3])
    c.rect(3, 22, 3, 6, IRON[0])
    beam(c, 5, 19, 33, 25, WEATHERED, 3)  # raftul cazut
    # borcane sparte: cioburi de sticla si placi
    for x, y in ((10, 26), (16, 27), (24, 26), (29, 27)):
        c.rect(x, y, 3, 2, GLASS[0])
        c.put(x, y, GLASS[3])
        c.put(x + 1, y + 1, COPPER[1])
    weeds(c, rng, 2, 38, 28, 10)
    c.put(14, 21, MOSS[3])
    c.put(27, 23, MOSS[2])
    outline_bottom(c, 0, 0, 40, 31)
    return c


def prop_ruin_works_bell():
    c = C(40, 56)
    rng = Rng(6717)
    soft_shadow(c, 20, 53, 16, 3)
    c.rect(6, 47, 28, 5, STONE[1])
    c.rect(6, 47, 28, 1, STONE[3])
    c.rect(29, 26, 3, 21, RUST[1])  # un picior ramas, ruginit
    c.rect(29, 26, 1, 21, RUST[3])
    beam(c, 5, 50, 30, 34, IRON, 2)  # turnul cazut
    # clopotul de alama, pe o parte, patat
    c.ellipse(17, 44, 6.4, 5, BRASS[1])
    c.ellipse(15.6, 42.6, 3.2, 2.4, BRASS[3])
    c.ellipse(23, 45, 2.2, 5.4, VERDIGRIS[1])
    c.put(13, 41, BRASS[4])
    weeds(c, rng, 2, 38, 52, 10)
    outline_bottom(c, 0, 0, 40, 55)
    return c


# ---------------------------------------------------------------------------------------------
# marfa (24x18, ca restul din Assets.goods)


def goods_coils():
    """Bobinele de sarma: un tambur mare cu spire de cupru si unul mic, rasturnat."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 9, 2)
    coil(c, 3, 5, 12, 10)
    c.ellipse(18.5, 12, 3.4, 2.6, WOOD[2])
    c.ellipse(18.5, 12, 2.2, 1.6, COPPER[3])
    c.put(18, 11, COPPER[4])
    outline_trace(c)
    return c


def goods_battery():
    """Bateria: un borcan de sticla cu placa de cupru si de zinc, capac de lemn si o scanteie."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 8, 2)
    c.rect(7, 5, 10, 10, GLASS[1])
    c.rect(7, 5, 2, 10, GLASS[3])
    c.rect(10, 6, 2, 8, COPPER[3])
    c.rect(13, 6, 2, 8, STEEL[3])
    c.rect(6, 4, 12, 2, WOOD[2])
    c.rect(6, 4, 12, 1, WOOD[4])
    c.rect(10, 2, 1, 2, COPPER[2])
    c.rect(14, 2, 1, 2, STEEL[2])
    c.put(12, 1, SPARK[4])
    outline_trace(c)
    return c


def goods_cell():
    """Celula de energie: un cilindru sigilat cu capete de alama, fulgerul pe el, lumina albastra la capat."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 9, 2)
    c.rect(4, 6, 16, 8, IRON[2])
    c.rect(4, 6, 16, 2, IRON[3])
    c.rect(4, 12, 16, 2, IRON[1])
    c.rect(3, 6, 2, 8, BRASS[2])
    c.rect(3, 6, 1, 8, BRASS[4])
    c.rect(19, 6, 2, 8, BRASS[1])
    c.rect(21, 8, 1, 4, SPARK[3])
    bolt(c, 10, 6)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# felinarele de pe strada [D67: "cu primul curent vandut, satul se lumineaza"]


def _lamp(lit):
    c = C(12, 40)
    soft_shadow(c, 6, 38, 4, 1.4)
    c.rect(4, 36, 4, 3, IRON[1])  # talpa
    c.rect(4, 36, 4, 1, IRON[3])
    c.rect(5, 12, 2, 25, IRON[2])  # stalpul
    c.rect(5, 12, 1, 25, IRON[4])
    c.rect(3, 12, 6, 1, IRON[1])
    # capul felinarului: cutia de sticla sub o palarie de fier
    c.rect(2, 2, 8, 2, IRON[2])
    c.rect(2, 2, 8, 1, IRON[4])
    c.put(5, 1, IRON[3])
    c.put(6, 1, IRON[3])
    glass = (CREAM[4], WARM[4], WARM[3]) if lit else (GLASS[1], GLASS[0], GLASS[1])
    c.rect(3, 4, 6, 7, glass[1])
    c.rect(4, 5, 4, 5, glass[0] if lit else glass[2])
    c.rect(3, 4, 1, 7, IRON[1])
    c.rect(8, 4, 1, 7, IRON[1])
    c.rect(3, 11, 6, 1, IRON[1])
    outline_trace(c)
    return c


def prop_street_lamp():
    return _lamp(False)


def prop_street_lamp_lit():
    return _lamp(True)


def prop_lamp_glow():
    """Lumina din jurul felinarului aprins: un disc cald, cu alfa care scade spre margine (se pune sub felinar)."""
    c = C(32, 32)
    for y in range(32):
        for x in range(32):
            d = math.hypot(x - 15.5, y - 15.5) / 15.5
            if d < 1:
                a = int(150 * (1 - d) ** 2)
                c.px[y][x] = (255, 226, 150, a)
    return c


def prop_turbine_spin():
    """[D68] Turbina care se invarte (4 cadre de 48x48): raul curge spre dreapta si impinge paletele de jos, deci roata
    merge invers acelor de ceasornic. 12 palete: 30 de grade pe perioada, 7,5 pe cadru. Stalpul si firul stau pe loc."""
    return M.spin_sheet(prop_turbine, 4, -2 * math.pi / 12 / 4)


SPRITES = {
    "prop_works_store": prop_works_store,
    "prop_wire_works": prop_wire_works,
    "prop_depot": prop_depot,
    "prop_steam_engine": prop_steam_engine,
    "prop_power_house": prop_power_house,
    "prop_battery_shed": prop_battery_shed,
    "prop_works_bell": prop_works_bell,
    "prop_turbine": prop_turbine,
    "prop_turbine_spin": prop_turbine_spin,
    "prop_ruin_works_store": prop_ruin_works_store,
    "prop_ruin_wire_works": prop_ruin_wire_works,
    "prop_ruin_depot": prop_ruin_depot,
    "prop_ruin_steam_engine": prop_ruin_steam_engine,
    "prop_ruin_power_house": prop_ruin_power_house,
    "prop_ruin_battery_shed": prop_ruin_battery_shed,
    "prop_ruin_works_bell": prop_ruin_works_bell,
    "goods_coils": goods_coils,
    "goods_battery": goods_battery,
    "goods_cell": goods_cell,
    "prop_street_lamp": prop_street_lamp,
    "prop_street_lamp_lit": prop_street_lamp_lit,
    "prop_lamp_glow": prop_lamp_glow,
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
