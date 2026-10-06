#!/usr/bin/env python3
"""[D75, lotul A4, grupul "works"] Cele patru cladiri de linie ale barajului, in doua coloane: magaziile pe drumul malului
si atelierele pe strada. Pana acum jocul le dadea desenele erelor 2-3 (works_store, wire_works, mill_store, foundry).
Barajul e de piatra (A1), deci cladirile lui sunt piatra cioplita reutilizata din satul vechi, beton turnat, fier nituit si
tabla galvanizata, portelan, cupru si alama, lemn gudronat. Se citesc ca UN pas dupa Wire Works (caramida, tabla, fier
nituit), iar fiecare are alta silueta decat perechea imprumutata si decat vecinele de pe harta.

Fiecare magazie sta la 370 px direct deasupra atelierului ei (baze 1010 si 1380): perechea imparte un accent de material
(linia butoaielor: alama si stejar; linia cablului: cupru si negru de cauciuc), dar au forme diferite (magazia e un sopron
cu usa mare, cu gramada jocului pe peretele din stanga; atelierul are masinarie si horn).

  prop_dam_store   40x32  "Battery Store": hambar de piatra cu fronton triunghiular (silueta: triunghi cu o grinda iesita la
                          coama), la capatul grinzii un scripete de alama cu o celula-baterie agatata de franghie; lucarna
                          de stejar in fronton; usa mare boltita, deschisa: inauntru, pe doua polite de stejar, celule-baterie
                          ca marfa jocului (borcan de sticla verzuie, banda de cupru, capac de cupru, borna albastra). O ladita
                          de stejar cu banda de alama langa usa.
  prop_switchyard  40x32  "Switchyard": hala joasa de beton turnat cu placa plata (silueta: orizontala cu doua intepaturi).
                          Pe acoperis, in stanga, un stalp de zabrele galvanizate cu un brat, doi izolatori de portelan
                          agatati si intre ei un conductor lasat in arc, trecut prin fata catargului; in dreapta hornul de fier
                          nituit (rampa IRON, mai inchisa decat betonul) cu brau de alama. La parter: dulapul de comutatie
                          (maner de alama, doi izolatori scurti din acelasi portelan crem ca cei agatati),
                          usa cu doua foi de stejar (rost de fier la mijloc, doar balamale de alama, buiandrug de beton),
                          o fereastra luminata albastru (curentul) si o stiva de trei butoaie de stejar cu cercuri de alama.
                          Fum: gura hornului masurata pe foaie, SMOKE_AT.switchyard.own = {0.80, 0.05}.
  prop_cable_store 40x32  "Cable Store": hangar BOLTIT (silueta: arc cu un ventilator de coama) din tabla ondulata galvanizata
                          pe soclu de piatra, cu cercul de cupru la margine, un fus de tabla cu capac de cupru pe coroana
                          (urca pana la randul 2, ca eticheta sa nu plutesca departe de arc), usa mare boltita cu
                          garnitura neagra de cauciuc si o foaie glisanta de tabla trasa peste jumatatea din stanga; in
                          cealalta jumatate, gramezi de minereu de cupru. Deasupra usii, o tablita de stejar cu trei bucati
                          de minereu.
  prop_cable_works 40x32  "Cable Works": turn de tras sarma in stanga (silueta: turn cu acoperis piramidal de cupru, apoi o
                          panta joasa si un horn), din lemn gudronat pe soclu de piatra, cu roata scripetelui de tabla pe
                          fata (butuc de tabla, jumatatea de jos-dreapta a obezii infasurata in cablu de cauciuc, iar din ea
                          cablul iese pe peretele halei pana in usa); hala cu acoperis intr-o apa de tabla, usa luminata
                          cald cu masina de tras, tamburul de cablu pe cant in dreapta, ca marfa jocului (a4_goods.reel) si
                          hornul de piatra cu brau de cupru.
                          Fum: SMOKE_AT.cableworks.own = {0.84, 0.05}. (Si SMOKE_AT.cableworks.borrowed e gresit azi: {0.79, 0.06}
                          e valoarea gaterului; turnatoria de imprumut are hornul la {0.79, 0.02}.)

Aceleasi reguli ca restul conductei: culori din palette.ramp(), umbra moale, contur trasat automat (outline_trace), lumina
din stanga-sus, niciodata negru pur. Scrie DOAR in --out (implicit folderul de lucru (scripts/art/scratch.py)), nu in assets/sprites.

Rulare: python3 scripts/art/a4_works.py [--out DIR] [--zoom nume ...]
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, Rng, png  # noqa: E402
from palette import ramp, OUTLINE  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import WARM, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402
import a1_town as T  # noqa: E402
import a4_goods as G  # noqa: E402  [directorul A4] tamburul de cablu, acelasi ca marfa jocului

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
SCRATCH = scratch.folder("a4")
SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---------------------------------------------------------------------------------------------
# materialele barajului

DSTONE = T.DSTONE  # piatra calda a zidului (A1), 6 trepte
ashlar = T.ashlar
GALV = ramp(212, 0.18, 0.62, val_span=0.44)  # tabla galvanizata, ca stalpii din a1_pylons.py
# beton turnat, rece (piatra e calda), dar cu un fir de nuanta si in varf: nu plastic alb (treapta de sus ~ 207, usor albastra)
CONCRETE = ramp(206, 0.10, 0.58, steps=6, hue_shift=6, sat_curve=0.04, val_span=0.46)
OAK = ramp(28, 0.60, 0.48, hue_shift=8, val_span=0.46)  # stejar, mai cald decat PLANK
TAR = ramp(22, 0.30, 0.30, hue_shift=8, val_span=0.34)  # lemn gudronat
# negru de cauciuc, usor albastru: nu negru pur si nici mai inchis decat conturul (cea mai inchisa treapta ~ (44,44,51))
RUBBER = ramp(236, 0.14, 0.30, hue_shift=6, val_span=0.20)
BRASS, COPPER, IRON = W.BRASS, M.COPPER, W.IRON
GLASS = W.GLASS  # sticla verzuie a borcanelor-baterie, ca goods_battery
TERMINAL = (92, 179, 255, 255)  # borna albastra a bateriei (goods_battery)
ROPE = (176, 150, 112, 255)
ROPE_D = (128, 104, 76, 255)
CRYS = [(34, 36, 112, 255), (58, 62, 168, 255), (90, 96, 222, 255), (136, 142, 248, 255), (204, 214, 255, 255)]


# ---------------------------------------------------------------------------------------------
# bucati comune


def cell(c, x, y, h=5):
    """Celula-baterie, aceeasi cu marfa jocului (goods_battery / prop_pile_battery): borcan de sticla verzuie (3 lat, `h` randuri),
    borna albastra deasupra, capac de cupru de 3 px, banda de cupru pe mijloc. `y` = randul bornei; `h` >= 4 (borna, capac,
    apoi h - 2 randuri de sticla). Lumina din stanga: coloana din stanga deschisa, cea din dreapta mai inchisa."""
    c.put(x + 1, y, TERMINAL)
    c.rect(x, y + 1, 3, 1, COPPER[2])
    for yy in range(y + 2, y + h):
        c.put(x, yy, GLASS[3])
        c.put(x + 1, yy, COPPER[3])
        c.put(x + 2, yy, GLASS[1])


def barrel(c, x, y, w=6, h=7):
    """Butoi de stejar cu doua cercuri de alama (w x h). Lumina din stanga: coloana din stanga deschisa, cea din dreapta
    inchisa; capetele sunt cu un pixel mai inguste, ca sa umfle burta."""
    for i in range(h):
        inset = 1 if i in (0, h - 1) else 0
        c.rect(x + inset, y + i, w - 2 * inset, 1, OAK[2])
        c.put(x + inset, y + i, OAK[4])
        c.put(x + w - 1 - inset, y + i, OAK[0])
        if w > 5:
            c.put(x + inset + 1, y + i, OAK[3])
    c.rect(x, y, w, 1, OAK[3])
    for by in (y + 1, y + h - 2):  # cercurile
        c.rect(x, by, w, 1, BRASS[3])
        c.put(x, by, BRASS[4])
        c.put(x + w - 1, by, BRASS[1])


def concrete(c, x, y, w, h, rng):
    """Beton turnat: panouri de cofraj de cate 4 randuri, cu gauri de tirant, muchia din stanga luminata."""
    c.rect(x, y, w, h, CONCRETE[3])
    for yy in range(y, y + h, 4):
        c.rect(x, yy, w, 1, CONCRETE[2])
        if yy + 2 < y + h:
            for xx in range(x + 3 + ((yy - y) // 4 % 2) * 4, x + w - 2, 8):
                c.put(xx, yy + 2, CONCRETE[1])
    for xx in range(x, x + w):  # pete usoare de apa, ca sa nu fie un perete de plastic
        if rng.n() < 0.07:
            c.put(xx, y + rng.i(0, h - 1), CONCRETE[2])
    c.rect(x, y, 2, h, CONCRETE[4])
    c.rect(x + w - 3, y, 3, h, CONCRETE[2])
    c.rect(x + w - 1, y, 1, h, CONCRETE[1])


def corrugated(c, x, y, w, h, tones=GALV):
    """Tabla ondulata, in vedere frontala: dungi verticale de trei tonuri (creasta, panta, vale)."""
    for i in range(w):
        tone = (tones[3], tones[2], tones[1])[(x + i) % 3]
        c.rect(x + i, y, 1, h, tone)


def thin(c, x0, y0, x1, y1, col, over=None):
    """O zabrea subtire de 1 px, trasata DUPA contur (conductorul, cablul). `over=None`: se pune peste orice (trece prin fata
    catargului, a peretelui); altfel doar pe transparent sau peste unul dintre tonurile din `over` (nu strica restul)."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        if 0 <= x < c.w and 0 <= y < c.h and (over is None or c.px[y][x][3] == 0 or c.px[y][x] in over):
            c.put(x, y, col)


def wire(c, pts, col):
    """O linie franta de 1 px prin punctele date (conductor lasat in arc, cablu care coboara)."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        thin(c, x0, y0, x1, y1, col)


def hang_insulator(c, x, y):
    """Izolatorul agatat sub un brat (5 lat, 4 randuri): caciula de fier, UN disc de portelan in clopot (3 px sus, 5 jos), clema de
    alama jos. (x, y) = mijlocul caciulii; conductorul se prinde de clema (x, y + 3), dupa contur. Lumina din stanga-sus:
    partea stanga mai deschisa, cea dreapta in umbra."""
    c.put(x, y, IRON[1])
    c.rect(x - 1, y + 1, 3, 1, CREAM[4])
    c.rect(x - 2, y + 2, 5, 1, CREAM[2])
    c.put(x - 1, y + 1, CREAM[4])
    c.put(x + 1, y + 1, CREAM[2])
    c.put(x - 2, y + 2, CREAM[3])
    c.put(x - 1, y + 2, CREAM[3])
    c.put(x + 2, y + 2, CREAM[1])
    c.put(x, y + 3, BRASS[3])


def sheave(c, cx, cy, r):
    """Roata scripetelui, pe pixeli (centrul `cx, cy` poate cadea intre pixeli): obada de tabla galvanizata (1 px), sase spite,
    butuc de tabla (NU de alama: alama + cerc in patrat intunecat = ceas), iar pe jumatatea de jos-dreapta a obezii cablul
    de cauciuc infasurat, 2 px, ca un scripete care duce ceva, nu ca o fata de ceas. Rama de cauciuc mai groasa pe dreapta."""
    spokes = [2 * math.pi * k / 6 + 0.3 for k in range(6)]
    for y in range(math.floor(cy - r - 2), math.ceil(cy + r + 3)):
        for x in range(math.floor(cx - r - 2), math.ceil(cx + r + 3)):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            lower_right = dx + dy > 0.2
            if r - 1.0 <= d < r:  # obada
                s_ = dx + dy
                c.put(x, y, GALV[4] if s_ < -2.4 else (GALV[1] if s_ > 2.4 else GALV[3]))
            elif r <= d < r + 1.1 and lower_right:  # cablul infasurat, in jgheabul din jurul obezii, cu dungi diagonale deschise
                c.put(x, y, RUBBER[4] if (x + y) % 2 == 0 else RUBBER[3])
            elif d < r - 1.0:
                for a in spokes:  # spitele: pixelul cel mai apropiat de fiecare raza
                    t = dx * math.cos(a) + dy * math.sin(a)
                    if t > 0 and abs(-dx * math.sin(a) + dy * math.cos(a)) < 0.55:
                        c.put(x, y, GALV[1])
    for x in (math.floor(cx), math.ceil(cx)):  # butucul de 2x2, din tabla
        for y in (math.floor(cy), math.ceil(cy)):
            c.put(x, y, GALV[3] if (x, y) == (math.floor(cx), math.floor(cy)) else GALV[1])


def prop_dam_store():
    c = C(40, 32)
    rng = Rng(7601)
    soft_shadow(c, 20, 29, 18, 2)

    def half(y):
        return 2 + round((y - 3) * 16 / 10)

    def bounds(y):
        return (20 - half(y), 20 + half(y))

    # frontonul: piatra cioplita, in triunghi
    ashlar(c, rng, bounds, 3, 14, 2, 38, ch=4, bw=(6, 9), lit=2, dark=3, base=(2, 3))
    # marginile acoperisului (tabla galvanizata): panta din stanga prinde lumina, cea din dreapta e in umbra
    for y in range(3, 14):
        xl, xr = bounds(y)
        c.put(xl, y, GALV[4])
        c.put(xl + 1, y, GALV[3])
        c.put(xl + 2, y, GALV[3])
        c.put(xr - 1, y, GALV[1])
        c.put(xr - 2, y, GALV[2])
        c.put(xr - 3, y, GALV[2])
    c.rect(18, 3, 4, 1, GALV[3])
    # streasina: grinda de stejar care iese in afara peretilor
    c.rect(1, 14, 38, 2, OAK[2])
    c.rect(1, 14, 38, 1, OAK[3])
    c.rect(1, 15, 38, 1, OAK[1])
    for x in (4, 12, 20, 28, 35):  # capetele de capriori
        c.put(x, 14, OAK[4])
    # peretii de piatra
    ashlar(c, rng, lambda y: (4, 36), 16, 28, 4, 36, ch=4, bw=(6, 9), lit=2, dark=3, base=(2, 3))
    c.rect(4, 16, 32, 1, (0, 0, 0, 70))  # umbra streasinii
    c.rect(4, 25, 32, 3, DSTONE[1])  # soclul, mai inchis
    c.rect(4, 25, 32, 1, DSTONE[3])
    for x in range(6, 36, 6):
        c.put(x, 26, DSTONE[0])
    # lucarna din fronton: usita de stejar sub un buiandrug de piatra, cu balamale de alama
    c.rect(17, 6, 6, 1, DSTONE[5])
    c.rect(18, 7, 4, 5, IRON[0])
    c.rect(18, 7, 2, 5, OAK[2])
    c.rect(20, 7, 2, 5, OAK[1])
    c.put(18, 7, OAK[4])
    for by in (8, 10):
        c.rect(18, by, 4, 1, BRASS[2])
    # usa mare boltita, deschisa: golul, rama de piatra, doua foi de stejar rasucite spre perete
    def opening(y):
        return (15, 25) if y == 17 else ((13, 27) if y == 18 else (12, 28))

    for y in range(17, 28):
        xl, xr = opening(y)
        c.rect(xl - 1, y, xr - xl + 2, 1, DSTONE[5] if y <= 18 else DSTONE[4])
        c.rect(xl, y, xr - xl, 1, IRON[0])
    c.rect(11, 19, 1, 9, DSTONE[5])  # rama din stanga prinde lumina
    c.rect(29, 19, 1, 9, DSTONE[1])
    # peretele din spate, cu rosturi, apoi doua polite de stejar cu celule-baterie (borcane de 4 randuri, patru pe polita)
    for y in (19, 22, 25):
        for x in range(14 + (y // 3 % 2) * 3, 27, 6):
            c.put(x, y, IRON[1])
    c.rect(12, 22, 16, 1, OAK[3])  # polita de sus (randurile 22-23), cu o muchie luminata
    c.rect(12, 23, 16, 1, OAK[0])
    for x in (13, 17, 21, 25):
        cell(c, x, 18, 4)  # sus: randurile 18-21, sprijinite pe polita
        cell(c, x, 24, 4)  # jos: randurile 24-27, pe podea
    # foile usii, deschise spre perete (strapuri de alama cu nituri)
    for lx, face in ((9, OAK[3]), (29, OAK[1])):
        c.rect(lx, 18, 2, 10, OAK[2])
        c.rect(lx, 18, 1, 10, face)
        for by in (20, 24):
            c.rect(lx, by, 2, 1, BRASS[3])
    c.put(10, 20, BRASS[4])
    # ladita de stejar cu banda de alama, langa usa
    c.rect(31, 22, 5, 5, OAK[2])
    c.rect(31, 22, 5, 1, OAK[4])
    c.rect(31, 22, 1, 5, OAK[3])
    c.rect(35, 22, 1, 5, OAK[0])
    c.rect(31, 24, 5, 1, BRASS[3])
    c.put(33, 24, BRASS[4])
    # grinda de la coama (iese spre dreapta), scripetele de alama, franghia si o celula agatata de carlig
    c.rect(18, 1, 19, 2, OAK[2])
    c.rect(18, 1, 19, 1, OAK[4])
    c.rect(18, 2, 19, 1, OAK[1])
    c.ellipse(35, 4.4, 1.6, 1.6, BRASS[3])
    c.put(34, 3, BRASS[4])
    c.put(35, 4, IRON[0])
    c.rect(35, 6, 1, 3, ROPE)
    c.put(35, 7, ROPE_D)
    cell(c, 34, 9)
    c.rect(33, 11, 1, 3, OUTLINE)  # celula atarna in fata frontonului: o linie de contur o desparte de panta acoperisului
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 2. Switchyard


def prop_switchyard():
    c = C(40, 32)
    rng = Rng(7602)
    soft_shadow(c, 20, 29, 18, 2)
    # hala de beton si placa plata a acoperisului
    concrete(c, 4, 15, 32, 13, rng)
    c.rect(4, 26, 32, 2, CONCRETE[1])  # soclul
    c.rect(4, 26, 32, 1, CONCRETE[3])
    c.rect(2, 12, 36, 1, CONCRETE[4])  # doar buza placii e treapta cea mai deschisa
    c.rect(2, 13, 36, 1, CONCRETE[3])  # fata placii
    c.rect(2, 14, 36, 1, CONCRETE[1])  # fata de dedesubt, in umbra
    c.rect(4, 15, 32, 1, (0, 0, 0, 56))  # umbra aruncata pe perete: doar pe perete (4-35), ca sub streasina sa se traseze conturul
    c.rect(2, 11, 36, 1, GALV[3])  # solinul de tabla de pe marginea placii
    # stalpul de pe acoperis: bratul de sus cu doi izolatori agatati; conductorul dintre ei se traseaza dupa contur
    c.rect(2, 2, 20, 2, GALV[3])  # bratul, simetric fata de catarg (x 2-21, axa la 11,5)
    c.rect(2, 2, 20, 1, GALV[4])
    c.rect(2, 3, 20, 1, GALV[1])
    hang_insulator(c, 4, 4)
    hang_insulator(c, 19, 4)
    for y in range(4, 12):  # catargul: se largeste spre baza, cu travers de zabrele din trei in trei randuri
        hw = 2 + (y - 4) // 4
        c.rect(12 - hw, y, 2 * hw, 1, GALV[2])
        c.put(12 - hw, y, GALV[4])
        c.put(12 + hw - 1, y, GALV[1])
        if (y - 4) % 3 == 2:
            c.rect(12 - hw + 1, y, 2 * hw - 2, 1, GALV[1])
    # hornul, de fier nituit (rampa IRON, mai inchisa decat placa de beton din spate ca sa se desprinda de ea), cu brau de alama
    # si gura mai larga
    c.rect(29, 2, 6, 10, IRON[2])
    c.rect(29, 2, 1, 10, IRON[4])
    c.rect(30, 2, 1, 10, IRON[3])
    c.rect(34, 2, 1, 10, IRON[0])
    for ry in (4, 9):  # randuri de nituri
        c.put(31, ry, IRON[4])
        c.put(32, ry, IRON[4])
    c.rect(28, 1, 8, 2, IRON[1])
    c.rect(28, 1, 8, 1, IRON[3])
    c.rect(28, 6, 8, 2, BRASS[2])
    c.rect(28, 6, 8, 1, BRASS[4])
    # dulapul de comutatie, in stanga: galvanizat, maner de alama, doi izolatori scurti deasupra
    c.rect(6, 19, 7, 9, GALV[2])
    c.rect(6, 19, 1, 9, GALV[4])
    c.rect(12, 19, 1, 9, GALV[0])
    c.rect(6, 19, 7, 1, GALV[4])
    c.rect(8, 21, 3, 5, IRON[0])
    c.rect(9, 22, 1, 3, BRASS[3])  # manerul
    c.put(9, 22, BRASS[4])
    for ix in (7, 11):  # acelasi portelan crem ca izolatorii agatati (hang_insulator): nimic alb, ca sa nu se citeasca drept becuri
        c.put(ix, 17, CREAM[3])
        c.put(ix, 18, CREAM[1])
    # usa cu doua foi de stejar, cu rama de fier, rost de fier la mijloc, doar balamale de alama (nu cercuri de butoi) si buiandrug de beton
    c.rect(15, 18, 10, 10, IRON[1])
    c.rect(16, 19, 8, 9, OAK[2])
    for x in range(17, 24, 2):
        c.rect(x, 19, 1, 9, OAK[1])
    c.rect(16, 19, 1, 9, OAK[3])
    c.rect(20, 19, 1, 9, IRON[1])  # rostul dintre foi
    for by in (21, 25):  # balamale: banda scurta pe fiecare foaie, cu un nit la capatul dinspre mijloc
        c.rect(16, by, 3, 1, BRASS[3])
        c.put(16, by, BRASS[4])
        c.put(18, by, BRASS[4])
        c.rect(22, by, 3, 1, BRASS[2])
        c.put(22, by, BRASS[4])
    c.rect(15, 18, 10, 1, IRON[3])
    c.rect(14, 17, 12, 1, CONCRETE[4])  # buiandrugul
    # fereastra luminata albastru: curentul
    c.rect(26, 17, 3, 7, IRON[1])
    c.rect(27, 18, 1, 5, CRYS[3])
    c.put(27, 18, CRYS[4])
    # stiva de trei butoaie, in dreapta
    barrel(c, 29, 22, 6, 6)
    barrel(c, 34, 22, 5, 6)
    barrel(c, 31, 16, 6, 6)
    outline_trace(c)
    # conductorul, DUPA contur: de la clema din stanga la cea din dreapta, lasat in arc (randul 9 intre x 10 si 13) si trecut prin
    # fata catargului
    wire(c, [(4, 7), (6, 8), (9, 9), (14, 9), (17, 8), (19, 7)], IRON[0])
    return c


# ---------------------------------------------------------------------------------------------
# 3. Cable Store


def prop_cable_store():
    c = C(40, 32)
    rng = Rng(7603)
    soft_shadow(c, 20, 29, 18, 2)
    cy, rx, ry = 18, 17, 11  # centrul si semiaxele arcului (coroana pe randul 7)

    def arch(y, rxx=rx, ryy=ry):
        """Jumatatea de latime a arcului pe randul y (centrul la 20: pixeli de la 20 - n la 20 + n - 1)."""
        if y >= cy:
            return rxx
        t = (cy - (y + 0.5)) / ryy
        return max(0, round(rxx * math.sqrt(max(0.0, 1 - t * t))))

    for y in range(cy - ry, 28):
        n = arch(y)
        for x in range(20 - n, 20 + n):
            tone = (GALV[3], GALV[2], GALV[1])[x % 3]
            rel = (x - (20 - n)) / max(1, 2 * n)
            if rel < 0.22:
                tone = (GALV[4], GALV[3], GALV[2])[x % 3]
            elif rel > 0.78:
                tone = (GALV[2], GALV[1], GALV[0])[x % 3]
            c.put(x, y, tone)
    # cercul de cupru de la margine: un rand de pixeli pe conturul arcului, un pic mai gros pe coroana
    for y in range(cy - ry, 28):
        n = arch(y)
        inner = arch(y, rx - 1.4, ry - 1.4) if y >= cy - ry + 2 else 0
        for x in range(20 - n, 20 + n):
            if x < 20 - inner or x >= 20 + inner or y <= cy - ry + 1:
                c.put(x, y, COPPER[3] if x < 20 else COPPER[1])
    c.rect(19, cy - ry, 2, 1, COPPER[4])
    # ventilatorul de coama: un fus de tabla care urca din cercul de cupru (randurile 3-6) si un capac de cupru de 4 px (randul 2);
    # tine silueta pana sus, ca eticheta de deasupra sa nu pluteasca peste un arc scund, si da cuprului al liniei un varf
    for vy in range(3, cy - ry):
        c.put(19, vy, GALV[4])
        c.put(20, vy, GALV[1])
    c.rect(18, 2, 2, 1, COPPER[4])
    c.rect(20, 2, 2, 1, COPPER[2])
    # soclul de piatra
    ashlar(c, rng, lambda y: (3, 37), 23, 28, 3, 37, ch=3, bw=(6, 9), lit=2, dark=3, base=(1, 3))
    c.rect(3, 23, 34, 1, DSTONE[4])
    # usa mare boltita, garnitura neagra de cauciuc si golul intunecat
    ocx, ocy, orx, ory = 20, 21, 9, 7

    def door(y, extra=0):
        if y >= ocy:
            return orx + extra
        t = (ocy - (y + 0.5)) / ory
        return max(0, round((orx + extra) * math.sqrt(max(0.0, 1 - t * t))))

    for y in range(ocy - ory - 1, 28):
        n = door(y, 1)
        c.rect(ocx - n, y, 2 * n, 1, RUBBER[2])
    for y in range(ocy - ory, 28):
        n = door(y)
        c.rect(ocx - n, y, 2 * n, 1, IRON[0])
    # gramezile de minereu de cupru din hangar, in jumatatea ramasa deschisa
    for rcx, rcy, rrx, rry in ((24, 24.4, 5, 3.0), (27.6, 24.2, 3.6, 2.6), (24.6, 21.8, 3.6, 2.6), (21.4, 23.6, 2.6, 2.0)):
        M.ore_rock(c, rcx, rcy, rrx, rry, rng)
    # foaia usii glisante, trasa peste jumatatea din stanga: tabla ondulata, cant de cauciuc, maner de cupru
    for y in range(ocy - ory, 28):
        n = door(y)
        for x in range(ocx - n, 20):
            tone = (GALV[4], GALV[3], GALV[2])[x % 3] if x < 15 else (GALV[3], GALV[2], GALV[1])[x % 3]
            c.put(x, y, tone)
        c.put(19, y, RUBBER[3])
        c.put(18, y, RUBBER[1] if y % 2 else RUBBER[2])
    c.rect(16, 22, 1, 3, COPPER[3])  # mania
    c.put(16, 22, COPPER[4])
    # firida de deasupra: tablita de stejar cu trei bucati de minereu
    c.rect(15, 11, 10, 3, OAK[2])
    c.rect(15, 11, 10, 1, OAK[4])
    c.rect(15, 13, 10, 1, OAK[0])
    for sx in (17, 20, 23):
        c.put(sx, 12, COPPER[3])
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 4. Cable Works


def prop_cable_works():
    c = C(40, 32)
    rng = Rng(7604)
    soft_shadow(c, 20, 29, 18, 2)

    def tar(x, y, w, h):
        c.rect(x, y, w, h, TAR[2])
        for xx in range(x + 3, x + w - 1, 4):  # scanduri cu rost: o dunga mai inchisa, apoi una mai deschisa
            c.rect(xx, y, 1, h, TAR[1])
            c.rect(xx + 1, y, 1, h, TAR[3])
        c.rect(x, y, 1, h, TAR[3])
        c.rect(x + w - 1, y, 1, h, TAR[1])  # fata din umbra: TAR[0] ar iesi mai inchis decat conturul

    # hala, in dreapta: lemn gudronat sub un acoperis intr-o apa de tabla
    tar(14, 14, 24, 14)
    for x in range(13, 39):
        drop = round(3 * (x - 13) / 25)
        for y in range(11 + drop, 15 + drop):
            tone = (GALV[3], GALV[2], GALV[1])[x % 3]
            c.put(x, y, tone)
        c.put(x, 11 + drop, GALV[4])
        c.put(x, 14 + drop, GALV[0])
    # turnul de tras sarma, in stanga: lemn gudronat pe soclu de piatra, acoperis de cupru in patru ape cu falturi
    tar(3, 8, 12, 20)
    for i, n in enumerate((1, 2, 4, 5, 6, 7, 8)):  # randurile de sus in jos (centrul la 9)
        y = 2 + i
        for x in range(9 - n, 9 + n):
            tone = COPPER[3] if x % 3 else COPPER[2]
            if x < 9 - n + 2:
                tone = COPPER[4]
            elif x >= 9 + n - 2:
                tone = COPPER[1]
            c.put(x, y, tone)
    c.rect(1, 9, 16, 1, COPPER[0])
    c.rect(1, 8, 16, 1, COPPER[1])
    c.put(9, 1, BRASS[4])
    # soclul de piatra
    ashlar(c, rng, lambda y: (3, 38), 24, 28, 3, 38, ch=3, bw=(6, 9), lit=2, dark=3, base=(1, 3))
    c.rect(3, 24, 35, 1, DSTONE[4])
    # luminarul scripetelui: gol intunecat (de fier, nu mai inchis decat conturul), roata de tabla cu butuc de tabla si cablul de
    # cauciuc infasurat pe jumatatea de jos-dreapta a obezii; centrul roatei cade intre pixeli, deci cercul iese simetric in gol
    c.rect(4, 10, 10, 10, IRON[0])
    sheave(c, 8.5, 14.5, 4.0)
    # fereastra luminata, in turn, sub roata
    c.rect(7, 21, 4, 2, IRON[1])
    c.rect(8, 21, 2, 1, WARM[3])
    c.put(8, 21, WARM[4])
    # hornul de piatra, cu brau de cupru
    ashlar(c, rng, lambda y: (31, 36), 1, 14, 31, 36, ch=3, bw=(3, 5), lit=1, dark=1, base=(1, 3))  # pana in randul 13: intra in acoperis
    c.rect(30, 1, 7, 2, COPPER[2])
    c.rect(30, 1, 7, 1, COPPER[4])
    # usa larga, luminata cald: masina de tras sarma
    c.rect(18, 17, 10, 11, IRON[1])
    c.rect(19, 18, 8, 10, WARM[1])
    c.rect(19, 18, 8, 1, WARM[3])
    c.rect(20, 23, 6, 5, IRON[0])
    line(c, 19, 21, 26, 21, COPPER[3], 1)
    c.rect(18, 17, 10, 1, IRON[3])
    # [directorul A4] tamburul de cablu pe cant, ca marfa jocului (a4_goods.reel; gramada de langa atelier e la fel)
    G.reel(c, 32.5, 23.5, 3.8, depth=2, tail=(36, 27))
    outline_trace(c)
    # cablul care leaga roata de masina, DUPA contur: iese din obada pe dreapta, merge pe peretele halei (randul 16) si intra in usa luminata
    wire(c, [(13, 15), (14, 16), (17, 16), (19, 18)], RUBBER[4])
    return c


# ---------------------------------------------------------------------------------------------

SPRITES = {
    "prop_dam_store": prop_dam_store,
    "prop_switchyard": prop_switchyard,
    "prop_cable_store": prop_cable_store,
    "prop_cable_works": prop_cable_works,
}
SIZES = {name: (40, 32) for name in SPRITES}
# cladirea de imprumut din joc, de care se compara fiecare
BORROWED = {
    "prop_dam_store": "prop_works_store",
    "prop_switchyard": "prop_wire_works",
    "prop_cable_store": "prop_mill_store",
    "prop_cable_works": "prop_foundry",
}
# baza fiecarei cladiri in lume (TycoonConfig.WORLDS[2].buildings): mijloc x, y jos
WORLD_AT = {
    "prop_dam_store": (1090, 1010),
    "prop_switchyard": (1090, 1380),
    "prop_cable_store": (1510, 1010),
    "prop_cable_works": (1510, 1380),
}
# gramezile jocului, langa cladiri (pozitii de lume; desenate la x2 in joc): (pile sprite, x, y)
PILES = [
    ("prop_pile_battery", 990, 1010),
    ("prop_pile_ore", 1410, 1010),
    ("prop_pile_battery", 990, 1380),
    ("prop_pile_planks", 1195, 1380),
    ("prop_pile_ore", 1410, 1380),
    ("prop_pile_copper", 1615, 1380),
]


# unde cautam gura hornului pe fiecare atelier (coloanele in care nu mai e nimic inalt in afara hornului)
CHIMNEY_COLS = {"prop_switchyard": (26, 38), "prop_cable_works": (28, 38)}


def measure_smoke(c, x_lo, x_hi):
    """Masoara gura hornului pe desenul gata: primul rand (de sus) care are pixeli de desen, nu contur, in coloanele date.
    Intoarce fractiunile pentru SceneArt.AddSmoke: x = mijlocul gurii / latime, y = (rand + 0.5) / inaltime."""
    for y in range(c.h):
        xs = [x for x in range(x_lo, x_hi) if c.px[y][x][3] > 200 and c.px[y][x] != OUTLINE]
        if xs:
            return round((min(xs) + max(xs) + 1) / 2 / c.w, 2), round((y + 0.5) / c.h, 2)
    raise ValueError("fara horn")


# ---------------------------------------------------------------------------------------------
# previzualizarea


def to_image(c):
    img = Image.new("RGBA", (c.w, c.h))
    img.putdata([p for row in c.px for p in row])
    return img


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def load(name):
    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


def preview(out_dir, imgs):
    D = 3
    bg = (86, 128, 64, 255)
    lab = font(8)
    S = 4
    pad = 14
    # randul de sus: fiecare desen nou, langa cel de imprumut pe care il inlocuieste (x4)
    cols = []
    for name, im in imgs.items():
        old = load(BORROWED[name])
        cols.append((name, im, old))
    w = len(cols) * (2 * 40 * S + pad * 3) + pad
    h = 32 * S + 2 * pad + 16
    top = Image.new("RGBA", (w, h), bg)
    d = ImageDraw.Draw(top)
    x = pad
    for name, im, old in cols:
        d.text((x, 4), name.replace("prop_", "") + " (new | old)", font=lab, fill=(255, 255, 255, 255))
        top.alpha_composite(im.resize((im.width * S, im.height * S), Image.NEAREST), (x, h - pad - im.height * S))
        x += im.width * S + pad
        top.alpha_composite(old.resize((old.width * S, old.height * S), Image.NEAREST), (x, h - pad - old.height * S))
        x += old.width * S + pad * 2

    # compusul: cele patru la locurile lor de pe pamantul copt, x3 = scara din joc
    ground = Image.open(os.path.join(SPR, "prop_dam_ground.png")).convert("RGBA")
    box = (900 // D, 880 // D, 1720 // D, 1460 // D)

    def stage(items, with_piles=True):
        crop = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), (40, 88, 120, 255))
        crop.alpha_composite(ground.crop(box))
        things = []
        if with_piles:
            for pname, px, py in PILES:
                pile = load(pname).crop((40, 0, 80, 28))  # cadrul 2 din 4
                things.append((py, pile, px, 2))
        for name, im in items:
            wx, wy = WORLD_AT[name]
            things.append((wy, im, wx, 3))
        for base, im, wx, k in sorted(things, key=lambda t: t[0]):
            # k = cati pixeli de lume are un pixel de arta; in compus 1 px de arta = D px de lume
            s = im.resize((round(im.width * k / D), round(im.height * k / D)), Image.NEAREST) if k != D else im
            crop.alpha_composite(s, (round(wx / D - s.width / 2) - box[0], round(base / D - s.height) - box[1]))
        return crop.resize((crop.width * 3, crop.height * 3), Image.NEAREST)

    new = stage([(n, im) for n, im in imgs.items()])
    new.save(os.path.join(out_dir, "works_in_context.png"))
    old = stage([(n, load(BORROWED[n])) for n in imgs])
    sheet_w = max(top.width, new.width + pad * 2)
    sheet = Image.new("RGBA", (sheet_w, top.height + new.height + old.height + pad * 6 + 24), (28, 32, 36, 255))
    sheet.alpha_composite(top, (0, 0))
    sd = ImageDraw.Draw(sheet)
    y = top.height + pad
    sd.text((pad, y - 11), "in game (x3), dam_ground at the real world positions", font=lab, fill=(230, 230, 230, 255))
    sheet.alpha_composite(new, (pad, y))
    y += new.height + pad * 2
    sd.text((pad, y - 11), "before: the borrowed Era 2-3 buildings", font=lab, fill=(230, 230, 230, 255))
    sheet.alpha_composite(old, (pad, y))
    path = os.path.join(out_dir, "works_preview.png")
    sheet.save(path)
    return path


def zoom(out_dir, name, imgs, k=12):
    im = imgs[name]
    bg = Image.new("RGBA", im.size, (86, 128, 64, 255))
    bg.alpha_composite(im)
    big = bg.resize((im.width * k, im.height * k), Image.NEAREST)
    path = os.path.join(out_dir, f"zoom_{name}.png")
    big.save(path)
    return path


def main():
    out = SCRATCH
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    os.makedirs(SCRATCH, exist_ok=True)  # previzualizarea, fumul si zoom-urile stau mereu in scratchpad, niciodata in --out
    imgs = {}
    smoke = {}
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)  # doar cele patru desene merg in --out
        imgs[name] = to_image(c)
        extra = ""
        if name in CHIMNEY_COLS:
            sx, sy = measure_smoke(c, *CHIMNEY_COLS[name])
            smoke[name] = [sx, sy]
            extra = f"  fum (SMOKE_AT own) = {{{sx}, {sy}}}"
        print("  scris", name, f"{c.w}x{c.h}" + extra)
    with open(os.path.join(SCRATCH, "works_smoke.json"), "w") as f:
        json.dump(smoke, f)
    print("previzualizare:", preview(SCRATCH, imgs))
    if "--zoom" in sys.argv:
        for name in sys.argv[sys.argv.index("--zoom") + 1 :]:
            if name in imgs:
                print("zoom:", zoom(SCRATCH, name, imgs))


if __name__ == "__main__":
    main()
