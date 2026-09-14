#!/usr/bin/env python3
"""Arta pentru D55: roaba oamenilor, gramezile pe trepte, shed-ul de scrap, fierul, colibele care cresc.

Owner-ul (2026-09-13): "npc-urile cara driftwood-ul intr-un sac, nu intr-o roaba", "texturile pentru cand
npc-ul pune jos lemnul respectiv plank-urile sunt patetice", "cand angajezi npc-ul as vrea sa se transforme
intr-o colibie mica... care cand se angajeaza mai multi npc, sa creasca in dimensiune... texturile facute cu
grija", plus lantul resturilor (shed separat, topit in atelier, vandut ca fier).

Aceleasi reguli ca restul conductei (buildings.py / tycoon*.py / ruins_d53.py):
  * culorile din palette.ramp() si din rampele pe care le folosesc deja cladirile vecine (lemnul, sindrila
    gaterului, scandurile depozitului, stuful colibei, ardezia tavernei), ca totul sa para aceeasi lume;
  * umbra din elipse translucide, conturul trasat automat (outline_trace), niciodata negru pur;
  * FASII: roaba (3 vederi), incarcaturile (3 trepte) si gramezile (4 trepte) sunt cadre de aceeasi marime
    puse una langa alta -- codul alege cadrul cu ImageRectOffset, deci un singur fisier urcat pe fel.

Rulare: python3 scripts/art/d55.py [--force]   (apoi preview_d55.py)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, T, png, shadow  # noqa: E402
from palette import WOOD, STONE, ramp, mix, hsv  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402
from tycoon import RUST, BURLAP, AWNING, CREAM  # noqa: E402
from tycoon_f2 import ROPE, THATCH  # noqa: E402
from tycoon_f3 import WEATHERED  # noqa: E402
from tycoon_e1 import PLANK, LOGW, SHINGLE, STEEL, GOLD, GOLD_HI, WARM, TAVERN_ROOF, outline_trace  # noqa: E402
from ruins_d53 import CHAR, MOSS, line, beam, weeds, erase  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

IRON = ramp(212, 0.24, 0.60)  # lingoul: otel albastrui, curat -- tabla scrap-ului e gri si patata
TIN = ramp(205, 0.08, 0.66)  # tabla acoperisului shed-ului
TIRE = ramp(24, 0.30, 0.26)  # obada si cauciucul de lemn ars al rotii
# culorile meseriilor, din tinutele lor (settlers.OUTFITS): coliba poarta culoarea omului care sta in ea
PORTER_CLOTH = ramp(16, 0.68, 0.58)  # crafter: ruginiu
SAWYER_CLOTH = ramp(48, 0.74, 0.86)  # builder: casca galbena
HAULER_CLOTH = ramp(124, 0.46, 0.54)  # gardener: verde


# ---------------------------------------------------------------------------------------------
# utilitare


def strip(frames):
    """Pune cadre de aceeasi marime una langa alta."""
    w, h = frames[0].w, frames[0].h
    out = C(w * len(frames), h)
    for i, f in enumerate(frames):
        for y in range(h):
            for x in range(w):
                p = f.px[y][x]
                if p[3]:
                    out.px[y][x + i * w] = p
    return out


def log_end(c, cx, cy, r=2.6):
    """Capatul unui bustean, spre tine: coaja, lemnul deschis, doua inele, miezul."""
    c.ellipse(cx, cy, r + 0.5, r + 0.5, LOGW[0])
    c.ellipse(cx, cy, r, r, LOGW[3])
    c.ellipse(cx, cy, r * 0.55, r * 0.55, LOGW[2])
    c.put(round(cx), round(cy), LOGW[1])


def log_side(c, x0, x1, cy, r=2):
    """Un bustean culcat, vazut din lateral, cu capatul taiat in stanga."""
    for x in range(x0, x1 + 1):
        c.rect(x, cy - r, 1, 2 * r + 1, LOGW[1])
        c.put(x, cy - r, LOGW[3])
        c.put(x, cy + r, LOGW[0])
        if (x * 7) % 5 == 0:
            c.put(x, cy, LOGW[0])
    c.ellipse(x0, cy, 1.2, r + 0.3, LOGW[4])
    c.put(x0, cy, LOGW[2])


def plank_flat(c, x0, x1, y, tone=2):
    """O scandura culcata, vazuta de sus-fata: fata de sus deschisa, muchia inchisa dedesubt."""
    c.rect(x0, y, x1 - x0 + 1, 1, PLANK[min(4, tone + 1)])
    c.rect(x0, y + 1, x1 - x0 + 1, 1, PLANK[max(0, tone - 1)])
    c.put(x0, y, PLANK[4])
    c.put(x1, y + 1, PLANK[0])


def ingot(c, x, y, w=8):
    """Un lingou de fier (4 randuri): fata de sus ingusta si luminata, fata din fata mai inchisa, muchia de
    jos in umbra. Trapezul se citeste "lingou" de la x2; o placa plata s-ar citi "piatra"."""
    c.rect(x + 1, y, w - 2, 1, IRON[4])
    c.rect(x + 1, y + 1, w - 2, 1, IRON[3])
    c.rect(x, y + 2, w, 1, IRON[2])
    c.rect(x, y + 3, w, 1, IRON[1])
    c.put(x, y + 3, IRON[0])
    c.put(x + w - 1, y + 3, IRON[0])
    c.put(x + 2, y, (255, 255, 255, 255))


def scrap_bits(c, rng, x0, y0, w, h, n):
    """Fier vechi, desenat din spate spre fata: placi de tabla (luminate sus, cu muchie inchisa), tevi cu
    capatul gol, colturi ruginite si suruburi. Luminos si unghiular -- un morman plin de umbra se citeste
    "bolovan", nu "fier vechi"."""
    for _ in range(n):
        kind = rng.i(0, 4)
        x, y = rng.i(x0, x0 + max(0, w - 4)), rng.i(y0, y0 + max(0, h - 2))
        if kind in (0, 1):  # placa de tabla, inclinata
            pw = rng.i(3, 5)
            c.rect(x, y, pw, 1, STONE[4])
            c.rect(x, y + 1, pw, 1, STONE[2])
            c.put(x + pw - 1, y + 1, STONE[1])
            if rng.n() < 0.5:
                c.put(x + rng.i(0, pw - 1), y + 1, RUST[2])
        elif kind == 2:  # teava
            pl = rng.i(4, 6)
            c.rect(x, y, pl, 1, STONE[3])
            c.rect(x, y + 1, pl, 1, STONE[1])
            c.put(x + pl - 1, y, STONE[0])
            c.put(x + pl - 1, y + 1, STONE[0])
        elif kind == 3:  # bucata ruginita
            c.rect(x, y, 3, 2, RUST[2])
            c.put(x, y, RUST[3])
            c.put(x + 2, y + 1, RUST[0])
        else:  # surub
            c.put(x, y, STEEL[4])
            c.put(x + 1, y, STEEL[2])


# ---------------------------------------------------------------------------------------------
# roaba: fasie cu trei vederi de 24x20 (lateral spre dreapta, spre tine, de la tine)
#
# ANCORELE (in pixeli de roaba), pe care codul le lipeste de mainile omului (settlers.push, randul oy+15):
#   lateral:   manerul la (0, 13), pamantul pe randul 19
#   spre tine: capetele manerelor la (9, 2) si (15, 2), roaba sub om, peste picioare
#   de la tine: capetele manerelor la (7|16, 19), cutia deasupra capului omului, in spatele lui

BW, BH = 24, 20


def _wheel_side(c, cx, cy, r):
    c.ellipse(cx, cy, r + 0.6, r + 0.6, TIRE[0])
    c.ellipse(cx, cy, r - 0.4, r - 0.4, WOOD[2])
    c.ellipse(cx, cy, r - 1.4, r - 1.4, WOOD[1])
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(1, int(r)):
            c.put(round(cx + dx * k), round(cy + dy * k), WOOD[3])
    c.put(round(cx), round(cy), STEEL[3])


def barrow_side():
    """Lateral, spre dreapta: roata in fata, cutia de scanduri cu buza ridicata, piciorul din spate si
    manerele care urca spre mainile omului."""
    c = C(BW, BH)
    soft_shadow(c, 13, 18, 9, 2)
    line(c, 8, 14, 1, 13, WOOD[1], 1)  # manerele: de la fundul cutiei spre spate, usor in sus
    line(c, 8, 15, 1, 14, WOOD[0], 1)
    c.rect(0, 13, 2, 2, WOOD[0])  # manerul, tocit de maini
    c.put(0, 13, WOOD[2])
    c.rect(9, 15, 2, 4, WOOD[1])  # piciorul din spate
    c.rect(9, 18, 2, 1, WOOD[0])
    for y in range(8, 15):  # cutia: trapez, lata sus, ingusta jos
        t = (y - 8) / 6
        xa = round(5 + 3 * t)
        xb = round(21 - 3 * t)
        c.rect(xa, y, xb - xa + 1, 1, WOOD[2] if y % 2 else WOOD[3])
    c.rect(5, 8, 17, 1, WOOD[4])  # buza
    c.put(21, 7, WOOD[4])
    c.put(22, 7, WOOD[3])  # buza din fata, iesita
    c.rect(6, 9, 15, 1, WOOD[1])  # peretele dinauntru, in umbra
    c.rect(13, 9, 1, 6, WOOD[1])  # imbinarea scandurilor pe lateral
    c.rect(8, 14, 12, 1, WOOD[0])
    _wheel_side(c, 19, 16, 3)
    outline_trace(c)
    return c


def barrow_front():
    """Spre tine: manerele coboara din mainile omului (sus) spre cutia vazuta din fata, roata ingusta jos, la
    mijloc. Cutia incepe sub mainile omului, peste picioarele lui, ca sa nu-i acopere pieptul."""
    c = C(BW, BH)
    soft_shadow(c, 12, 18, 6, 2)
    line(c, 9, 2, 9, 7, WOOD[1], 1)  # manerele, din maini spre cutie
    line(c, 15, 2, 15, 7, WOOD[1], 1)
    c.rect(9, 2, 1, 1, WOOD[0])
    c.rect(15, 2, 1, 1, WOOD[0])
    for y in range(7, 14):
        t = (y - 7) / 6
        xa = round(6 + 2 * t)
        xb = round(18 - 2 * t)
        c.rect(xa, y, xb - xa + 1, 1, WOOD[2] if y % 2 else WOOD[3])
    c.rect(6, 7, 13, 1, WOOD[4])
    c.rect(7, 8, 11, 1, WOOD[1])  # interiorul din spatele buzei
    c.rect(12, 8, 1, 6, WOOD[1])
    line(c, 9, 13, 11, 15, WOOD[0], 1)  # furca de la roata la cutie
    line(c, 15, 13, 13, 15, WOOD[0], 1)
    c.rect(11, 13, 2, 6, TIRE[0])  # roata, din fata
    c.rect(11, 14, 1, 4, TIRE[2])
    outline_trace(c)
    return c


def barrow_back():
    """De la tine: roaba e INAINTEA omului, deci mai sus pe ecran. Se vad manerele lungi care vin spre tine,
    peretii cutiei in U (buza din spate luminata, jos) si varful rotii dincolo de ea; incarcatura sta in
    cutie, in spatele buzei -- nu deasupra ei, altfel s-ar citi ca o povara pe cap."""
    c = C(BW, BH)
    soft_shadow(c, 12, 8, 7, 2)
    c.rect(11, 0, 2, 2, TIRE[0])  # varful rotii, departe
    c.put(11, 0, TIRE[2])
    for y in range(2, 9):  # peretii laterali, spre departe se strang
        t = (y - 2) / 6
        xa = round(5 + 1 * t)
        xb = round(18 - 1 * t)
        c.rect(xa, y, 2, 1, WOOD[2])
        c.rect(xb - 1, y, 2, 1, WOOD[1])
    c.rect(6, 2, 12, 1, WOOD[3])  # buza din fata (departe)
    c.rect(7, 3, 10, 5, WOOD[0])  # fundul cutiei, in umbra
    c.rect(5, 9, 14, 2, WOOD[3])  # buza din spate, spre tine
    c.rect(5, 9, 14, 1, WOOD[4])
    c.rect(6, 11, 12, 1, WOOD[1])
    for x0, x1 in ((8, 7), (15, 16)):  # manerele, lungi, spre mainile omului
        line(c, x0, 12, x1, 19, WOOD[2], 1)
        line(c, x0 + (1 if x0 < 12 else -1), 12, x1 + (1 if x1 < 12 else -1), 19, WOOD[1], 1)
    outline_trace(c)
    return c


def prop_barrow():
    return strip([barrow_side(), barrow_front(), barrow_back()])


# ---------------------------------------------------------------------------------------------
# incarcaturile din roaba: fasie cu 3 trepte de 16x9, puse de cod pe gura cutiei

LW, LH = 16, 9


def _load(draw):
    frames = []
    for step in (1, 2, 3):
        c = C(LW, LH)
        draw(c, step)
        outline_trace(c)
        frames.append(c)
    return strip(frames)


def prop_load_logs():
    def draw(c, step):
        if step >= 1:
            log_side(c, 3, 13, 6)
        if step >= 2:
            log_side(c, 2, 12, 4)
        if step >= 3:
            log_side(c, 4, 14, 2)

    return _load(draw)


def prop_load_planks():
    def draw(c, step):
        for i in range(step * 2):
            off = (i * 3) % 3 - 1
            plank_flat(c, 2 + off, 13 + off, 7 - i, tone=2 + (i % 2))

    return _load(draw)


def prop_load_scrap():
    def draw(c, step):
        rng = Rng(5511 + step)
        c.ellipse(8, 7, 2 + step * 2, 1 + step * 0.7, STONE[0])
        scrap_bits(c, rng, 4 - step, 7 - step * 2, 8 + step * 2, step * 2 + 1, 4 + step * 3)

    return _load(draw)


def prop_load_iron():
    def draw(c, step):
        spots = [(4, 5), (1, 3), (8, 3), (4, 1), (9, 5)]
        for x, y in spots[: (1, 3, 4)[step - 1]]:
            ingot(c, x, y, 7)

    return _load(draw)


def prop_load_crate():
    def draw(c, step):
        for k in range(step):
            x, y = (4, 3, 8)[k], (3, 0, 2)[k] + 1
            c.rect(x, y, 6, 5, WOOD[2])
            c.rect(x, y, 6, 1, WOOD[4])
            c.rect(x, y + 4, 6, 1, WOOD[0])
            c.rect(x + 2, y + 1, 1, 3, WOOD[1])

    return _load(draw)


# ---------------------------------------------------------------------------------------------
# gramezile: fasie cu 4 trepte de 40x28, baza pe randul 26 (codul le prinde de baza, la x2)
# Treptele dupa cifra (PileView): 1-4, 5-14, 15-39, 40+.

PW, PH = 40, 28


def _pile(draw):
    frames = []
    for step in (1, 2, 3, 4):
        c = C(PW, PH)
        draw(c, step)
        outline_trace(c)
        frames.append(c)
    return strip(frames)


def _stake(c, x, top):
    c.rect(x, top, 2, 26 - top, WOOD[1])
    c.rect(x, top, 1, 26 - top, WOOD[3])
    c.put(x, top, WOOD[4])


def prop_pile_logs():
    """Stiva de busteni: capetele spre tine, in piramida, cu inelele lor -- "lemn strans", ca la depozit.
    De la treapta 3 doi tarusi o tin sa nu se rostogoleasca."""
    rows_by_step = {
        1: [[(16, 22), (23.5, 22)]],
        2: [[(15, 22), (22, 22), (29, 22)], [(18.5, 16)]],
        3: [[(11, 22), (18, 22), (25, 22), (32, 22)], [(14.5, 16), (21.5, 16), (28.5, 16)], [(18, 10)]],
        4: [
            [(7, 22), (14, 22), (21, 22), (28, 22), (35, 22)],
            [(10.5, 16), (17.5, 16), (24.5, 16), (31.5, 16)],
            [(14, 10), (21, 10), (28, 10)],
            [(17.5, 4), (24.5, 4)],
        ],
    }

    def draw(c, step):
        soft_shadow(c, 20, 25, 6 + step * 4, 2)
        rows = rows_by_step[step]
        # masa din spate: trupul bustenilor, spre departe (sus-dreapta), sub capete
        for row in rows:
            for cx, cy in row:
                c.rect(round(cx) - 2, round(cy) - 4, 6, 4, LOGW[1])
                c.rect(round(cx) - 2, round(cy) - 4, 6, 1, LOGW[2])
        for row in rows:
            for cx, cy in row:
                log_end(c, cx, cy, 3.1)
        if step >= 3:
            _stake(c, 1 if step == 4 else 4, 12 if step == 4 else 16)
            _stake(c, 38 if step == 4 else 35, 12 if step == 4 else 16)

    return _pile(draw)


def prop_pile_planks():
    """Teancul de scanduri: doi dormeni pe jos, scandurile culcate de-a lungul, capetele deschise la
    culoare (taiate de curand), fiecare strat decalat cu un pixel -- un teanc facut de mana, nu un bloc."""
    layers_by_step = {1: 2, 2: 4, 3: 7, 4: 10}
    rng_off = [0, 1, 0, -1, 1, 0, -1, 0, 1, 0]

    def draw(c, step):
        soft_shadow(c, 20, 25, 17, 2)
        for x in (7, 29):  # dormenii
            c.rect(x, 23, 4, 3, WOOD[0])
            c.rect(x, 23, 4, 1, WOOD[1])
        for i in range(layers_by_step[step]):
            y = 21 - i * 2
            off = rng_off[i]
            x0, x1 = 3 + off, 36 + off
            c.rect(x0, y, x1 - x0 + 1, 1, PLANK[3] if i % 2 else PLANK[4])
            c.rect(x0, y + 1, x1 - x0 + 1, 1, PLANK[1])
            c.rect(x0, y, 1, 2, PLANK[4])  # capetele taiate
            c.rect(x1, y, 1, 2, PLANK[2])
            for k in range(x0 + 5, x1 - 2, 9):  # rosturile dintre scanduri
                c.put(k + (i * 3) % 4, y, PLANK[2])
        if step == 4:  # o chinga peste teanc
            c.rect(19, 3, 2, 21, ROPE[1])
            c.rect(19, 3, 1, 21, ROPE[3])

    return _pile(draw)


def prop_pile_scrap():
    """Mormanul de scrap: tabla, tevi, bucati ruginite, tot mai inalt; o roata dintata de la treapta 3, o
    roata de caruta rupta sus la treapta 4. Unghiular, luminos si ruginiu, ca sa nu semene nici cu stiva de
    busteni, nici cu un bolovan."""

    def draw(c, step):
        rx, ry = (7, 10, 14, 17)[step - 1], (3, 5, 8, 11)[step - 1]
        soft_shadow(c, 20, 25, rx + 2, 2)
        base = 25
        top = round(base - ry * 1.5)
        for y in range(top, base + 1):  # silueta in trepte: mai lata jos, zimtata sus
            t = (y - top) / max(1, base - top)
            half = round(rx * (0.35 + 0.65 * t ** 0.6))
            c.rect(20 - half, y, half * 2, 1, STONE[1] if (y + step) % 3 else STONE[0])
        rng = Rng(7300 + step)
        scrap_bits(c, rng, 20 - rx + 1, top, rx * 2 - 2, base - top - 1, 8 + step * 9)
        if step >= 2:  # o teava lunga, iesita din morman
            line(c, 20 - rx + 1, base - 2, 20 - rx // 3, top + 1, STONE[4], 1)
            line(c, 20 - rx + 2, base - 2, 20 - rx // 3 + 1, top + 1, STONE[1], 1)
        if step >= 3:  # roata dintata
            gx, gy = 23, top + 3
            c.ellipse(gx, gy, 3.2, 3.2, RUST[1])
            c.ellipse(gx, gy, 2.2, 2.2, RUST[3])
            for dx, dy in ((0, -4), (4, 0), (0, 4), (-4, 0)):
                c.put(gx + dx, gy + dy, RUST[2])
            c.put(gx, gy, STONE[0])
        if step == 4:  # o roata de caruta rupta, deasupra
            c.ellipse(14, top + 1, 3.4, 2.4, WOOD[1])
            c.ellipse(14, top + 1, 2.2, 1.3, T)
            erase(c, 13, top + 1, 3, 1)

    return _pile(draw)


def prop_pile_iron():
    """Lingourile de fier, in randuri: fiecare rand mai scurt, decalat pe jumatate, ca o stiva de caramizi
    -- ordonat si curat, se vede ca a trecut prin atelier."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3, 2], 4: [4, 4, 3, 2]}

    def draw(c, step):
        soft_shadow(c, 20, 25, 16, 2)
        y = 22
        for i, count in enumerate(rows_by_step[step]):
            w, gap = 8, 1
            total = count * w + (count - 1) * gap
            x = 20 - total // 2 + (i % 2)
            for k in range(count):
                ingot(c, x + k * (w + gap), y, w)
            y -= 4

    return _pile(draw)


# ---------------------------------------------------------------------------------------------
# fierul, bunul (24x18), ca goods_planks


def goods_iron():
    """Trei lingouri de fier: doua jos, unul deasupra -- aceeasi forma ca in stiva de langa atelier."""
    c = C(24, 18)
    soft_shadow(c, 12, 15, 10, 2)
    ingot(c, 3, 10, 9)
    ingot(c, 12, 10, 9)
    ingot(c, 7, 6, 10)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# shed-ul de scrap (40x32, PIXEL_SCALE 3 -> 120x96), aceeasi amprenta ca depozitul


def _tin_roof(c, x0, x1, y_high, y_low, rng):
    """Acoperis de tabla ondulata, in panta spre dreapta: nervuri verticale, doua petice ruginite."""
    for x in range(x0, x1 + 1):
        t = (x - x0) / max(1, x1 - x0)
        top = round(y_high + (y_low - y_high) * t)
        ridge = (x - x0) % 3
        col = TIN[3] if ridge == 0 else (TIN[2] if ridge == 1 else TIN[1])
        c.rect(x, top, 1, 4, col)
        c.put(x, top, TIN[4] if ridge == 0 else TIN[3])
        c.put(x, top + 4, TIN[0])
    for px, py in ((x0 + 6, y_high + 2), (x1 - 9, y_low - 1)):
        for _ in range(7):
            xx, yy = px + rng.i(0, 5), py + rng.i(0, 2)
            if c.px[yy][xx][3]:
                c.put(xx, yy, RUST[rng.i(1, 3)])


def prop_scrap_shed():
    """Shed-ul de scrap: un sopron strâmb din scanduri nepotrivite, cu acoperis de tabla ondulata, plin cu
    tabla, tevi si o roata dintata. Trebuie sa se citeasca altfel decat depozitul de alaturi (acoperis de
    scanduri, capete de busteni): aici e rece, cenusiu si ruginit -- "fier vechi"."""
    c = C(40, 32)
    rng = Rng(5520)
    shadow(c, 20, 29, 18, 2)
    for i, x in enumerate(range(5, 35, 3)):  # peretele din spate: scanduri de lungimi si tonuri diferite
        tone = (WEATHERED[1], WOOD[1], WEATHERED[2])[i % 3]
        top = 11 + (i * 5) % 3
        c.rect(x, top, 3, 27 - top, tone)
        c.rect(x, top, 1, 27 - top, WEATHERED[3] if i % 2 else WOOD[2])
    c.rect(5, 18, 30, 1, WOOD[0])  # o traversa
    for px in (3, 34):  # stalpii din fata
        c.rect(px, 9 + (1 if px > 20 else 0), 3, 19, WOOD[2])
        c.rect(px, 9, 1, 19, WOOD[3])
    _tin_roof(c, 0, 39, 3, 8, rng)
    # gramada dinauntru
    c.ellipse(19, 25, 11, 3, STONE[1])
    scrap_bits(c, rng, 8, 17, 22, 8, 30)
    c.ellipse(24, 19, 3.3, 3.3, RUST[1])  # roata dintata
    c.ellipse(24, 19, 2.2, 2.2, RUST[2])
    for dx, dy in ((0, -4), (4, 0), (0, 4), (-4, 0)):
        c.put(24 + dx, 19 + dy, RUST[1])
    c.put(24, 19, STONE[0])
    line(c, 9, 25, 15, 17, STONE[3], 1)  # o teava rezemata
    # butoiul ruginit, in stanga, afara
    c.rect(0, 20, 5, 8, RUST[1])
    c.rect(0, 20, 5, 1, RUST[3])
    c.rect(0, 23, 5, 1, STONE[1])
    c.rect(0, 26, 5, 1, STONE[1])
    # firma: o roata dintata alba pe o scandura
    c.rect(15, 9, 10, 5, WOOD[0])
    c.rect(16, 10, 8, 3, WOOD[1])
    c.ellipse(20, 11.5, 1.6, 1.6, CREAM[3])
    c.put(20, 11, WOOD[1])
    outline_trace(c)
    return c


def prop_ruin_scrap_shed():
    """Ruina shed-ului (aceeasi amprenta): un stalp aplecat, tablele acoperisului cazute pe jos si ruginite,
    scanduri rupte, cateva bucati de fier vechi prin buruieni."""
    c = C(40, 32)
    rng = Rng(5521)
    shadow(c, 20, 29, 17, 2)
    for x, top in ((6, 18), (9, 22), (27, 20), (30, 24)):  # cioturile peretelui
        c.rect(x, top, 3, 27 - top, WEATHERED[1])
        c.rect(x, top, 1, 27 - top, WEATHERED[3])
    line(c, 5, 27, 12, 11, WOOD[1], 2)  # stalpul aplecat
    for k, (x0, y0, x1, y1) in enumerate(((10, 26, 26, 20), (18, 27, 36, 24))):  # tablele cazute
        for i in range(4):
            line(c, x0, y0 - i, x1, y1 - i, TIN[1 + (i + k) % 3], 1)
        for _ in range(8):
            xx, yy = rng.i(min(x0, x1), max(x0, x1)), rng.i(min(y0, y1) - 3, max(y0, y1))
            if c.px[yy][xx][3]:
                c.put(xx, yy, RUST[rng.i(1, 3)])
    beam(c, 22, 18, 34, 22, CHAR, 2)  # o grinda arsa
    scrap_bits(c, rng, 3, 22, 34, 5, 10)
    weeds(c, rng, 2, 38, 28, 9)
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# colibele oamenilor: mica (32x28) pentru un om, mare (40x34) pentru doi -- PIXEL_SCALE 3, prinse de baza,
# pe locul avizierului. Aceeasi familie (barne, acoperis in doua ape), dar fiecare meserie are acoperisul si
# culoarea usii ei si uneltele ei afara: Porter-ul roaba si franghia, Sawyer-ul butucul cu toporul si
# ferastraul, Hauler-ul stelajul cu scanduri si caruciorul.

NET_THREAD_L = ramp(75, 0.20, 0.62)


def _cabin(c, x0, x1, y0, y1):
    """Peretii din barne, cu capetele barnelor la colturi."""
    c.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, WOOD[2])
    for y in range(y0, y1 + 1, 3):
        c.rect(x0, y, x1 - x0 + 1, 1, WOOD[3])
        if y + 2 <= y1:
            c.rect(x0, y + 2, x1 - x0 + 1, 1, WOOD[1])
        for x in (x0 - 1, x1):
            c.rect(x, y, 2, 2, LOGW[3])
            c.put(x if x < x0 else x + 1, y, LOGW[4])
    c.rect(x0, y1, x1 - x0 + 1, 1, WOOD[0])


def _gable(c, x0, x1, top, eave, tones, texture):
    """Acoperis in doua ape, in trepte, cu streasina in umbra si textura materialului."""
    h = eave - top
    for i in range(h):
        inset = round((h - 1 - i) * ((x1 - x0) * 0.5 - 2) / max(1, h))
        y = top + i
        c.rect(x0 + inset, y, x1 - x0 + 1 - 2 * inset, 1, tones[3] if i % 2 else tones[2])
        if texture == "shingle" and i % 2 == 0:
            for x in range(x0 + inset + (i // 2) % 3, x1 - inset, 3):
                c.put(x, y, tones[1])
        elif texture == "plank":
            for x in range(x0 + inset + 2, x1 - inset, 5):
                c.put(x, y, tones[1])
        elif texture == "slate" and i % 2 == 1:
            for x in range(x0 + inset + (i // 2) % 2 * 2, x1 - inset, 4):
                c.put(x, y, tones[1])
    c.rect(x0, eave, x1 - x0 + 1, 1, tones[0])
    c.rect(x0 + (x1 - x0) // 2 - 1, top - 1, 3, 1, tones[4])


def _door(c, x, y, w, h, cloth):
    c.rect(x - 1, y - 1, w + 2, h + 1, WOOD[0])
    c.rect(x, y, w, h, cloth[2])
    c.rect(x, y, 1, h, cloth[3])
    c.rect(x + w - 1, y, 1, h, cloth[1])
    for yy in range(y + 2, y + h, 3):
        c.rect(x, yy, w, 1, cloth[1])
    c.put(x + w - 2, y + h // 2, GOLD[3])


def _window(c, x, y, w=5, h=4):
    c.rect(x - 1, y - 1, w + 2, h + 2, WOOD[0])
    c.rect(x, y, w, h, WARM[2])
    c.rect(x, y, w, 1, WARM[4])
    c.rect(x + w // 2, y, 1, h, WOOD[1])


def _chimney(c, x, top, bottom):
    c.rect(x, top, 4, bottom - top, STONE[2])
    c.rect(x, top, 4, 1, STONE[3])
    c.rect(x + 3, top + 1, 1, bottom - top - 1, STONE[1])
    c.put(x + 1, top - 1, (220, 220, 225, 150))
    c.put(x + 2, top - 3, (220, 220, 225, 110))


def _mini_barrow(c, x, y):
    """Roaba parcata (13x8), lateral spre stanga, sprijinita pe picior: aceeasi roaba cu care umbla omul,
    in lemn deschis ca sa iasa din peretele de barne din spate."""
    c.rect(x + 2, y, 10, 1, PLANK[4])  # buza
    for yy in range(1, 5):  # cutia, ingusta jos
        c.rect(x + 2 + yy // 2, y + yy, 10 - yy, 1, PLANK[3] if yy % 2 else PLANK[2])
    c.rect(x + 3, y + 1, 8, 1, WOOD[1])  # interiorul
    c.ellipse(x + 3, y + 6, 1.8, 1.8, TIRE[0])  # roata, in fata (stanga)
    c.put(x + 3, y + 6, PLANK[4])
    line(c, x + 10, y + 4, x + 12, y + 7, WOOD[1], 1)  # manerul, lasat pe pamant
    c.rect(x + 8, y + 5, 1, 3, WOOD[1])  # piciorul


def _rope_coil(c, x, y):
    c.ellipse(x, y, 2.2, 2.2, ROPE[2])
    c.ellipse(x, y, 1.2, 1.2, ROPE[0])
    c.put(x - 1, y - 2, ROPE[4])


def _stump_axe(c, x, y):
    """Butucul de despicat cu toporul infipt."""
    c.rect(x, y, 6, 4, LOGW[1])
    c.rect(x, y, 6, 1, LOGW[4])
    c.put(x + 2, y, LOGW[2])
    line(c, x + 3, y, x + 6, y - 4, WOOD[3], 1)
    c.rect(x + 1, y - 2, 3, 2, STEEL[3])
    c.put(x + 1, y - 2, STEEL[4])


def _bow_saw(c, x, y):
    """Ferastraul cu arc, agatat pe perete."""
    line(c, x, y + 3, x + 3, y, WOOD[3], 1)
    line(c, x + 3, y, x + 7, y, WOOD[3], 1)
    line(c, x + 7, y, x + 8, y + 3, WOOD[3], 1)
    c.rect(x, y + 3, 9, 1, STEEL[3])


def _plank_rack(c, x, y, n):
    """Scanduri rezemate de perete, pe un stelaj."""
    for k in range(n):
        line(c, x + k * 2, y + 9, x + 2 + k * 2, y, PLANK[3 if k % 2 else 2], 1)
        c.put(x + 2 + k * 2, y, PLANK[4])
    c.rect(x - 1, y + 9, n * 2 + 3, 1, WOOD[0])


def prop_hut_porter_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _cabin(c, 5, 26, 14, 25)
    _gable(c, 2, 29, 3, 14, PLANK, "plank")
    _door(c, 15, 18, 5, 8, PORTER_CLOTH)
    _window(c, 22, 17)
    _rope_coil(c, 22, 23)
    _mini_barrow(c, 0, 18)
    outline_trace(c)
    return c


def prop_hut_porter_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _chimney(c, 25, 1, 9)
    _cabin(c, 4, 29, 17, 31)
    _gable(c, 1, 32, 4, 17, PLANK, "plank")
    for y in range(20, 31):  # sopronul lipit in dreapta, cu lazi
        c.rect(30, y, 9, 1, WEATHERED[1] if y % 3 else WEATHERED[0])
    for i in range(4):
        c.rect(29, 17 + i, 11 - i, 1, PLANK[2] if i % 2 else PLANK[3])
    c.rect(31, 24, 6, 6, WOOD[2])
    c.rect(31, 24, 6, 1, WOOD[4])
    c.rect(33, 24, 1, 6, WOOD[0])
    _door(c, 12, 21, 6, 10, PORTER_CLOTH)
    _window(c, 6, 21)
    _window(c, 21, 21)
    _rope_coil(c, 26, 27)
    _mini_barrow(c, 0, 24)
    outline_trace(c)
    return c


def prop_hut_sawyer_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _cabin(c, 4, 25, 14, 25)
    _gable(c, 1, 28, 3, 14, SHINGLE, "shingle")
    _door(c, 7, 18, 5, 8, SAWYER_CLOTH)
    _bow_saw(c, 15, 16)
    _window(c, 19, 19)
    _stump_axe(c, 25, 22)
    outline_trace(c)
    return c


def prop_hut_sawyer_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _chimney(c, 8, 1, 9)
    _cabin(c, 6, 33, 17, 31)
    _gable(c, 3, 36, 4, 17, SHINGLE, "shingle")
    _door(c, 17, 21, 6, 10, SAWYER_CLOTH)
    _window(c, 9, 21)
    _bow_saw(c, 25, 19)
    _window(c, 27, 24)
    for k in range(3):  # lemne de foc, stivuite pe peretele din stanga
        for j in range(3 - k):
            log_end(c, 2 + j * 3 + k * 1.5, 29 - k * 3, 1.4)
    _stump_axe(c, 33, 28)
    outline_trace(c)
    return c


def prop_hut_hauler_1():
    c = C(32, 28)
    soft_shadow(c, 16, 26, 14, 2)
    _cabin(c, 6, 27, 14, 25)
    _gable(c, 3, 30, 3, 14, TAVERN_ROOF, "slate")
    _door(c, 17, 18, 5, 8, HAULER_CLOTH)
    _window(c, 9, 17)
    _plank_rack(c, 0, 16, 3)
    outline_trace(c)
    return c


def prop_hut_hauler_2():
    c = C(40, 34)
    soft_shadow(c, 20, 32, 18, 2)
    _chimney(c, 28, 1, 9)
    _cabin(c, 7, 34, 17, 31)
    _gable(c, 4, 37, 4, 17, TAVERN_ROOF, "slate")
    _door(c, 19, 21, 6, 10, HAULER_CLOTH)
    _window(c, 10, 21)
    _window(c, 28, 21)
    _plank_rack(c, 0, 20, 4)
    # caruciorul cu scanduri, in fata, dreapta
    c.rect(29, 27, 10, 2, WOOD[2])
    c.rect(29, 27, 10, 1, WOOD[4])
    for k in range(2):
        c.rect(30, 25 - k * 2, 9, 1, PLANK[4])
        c.rect(30, 26 - k * 2, 9, 1, PLANK[2])
    c.ellipse(31, 30, 1.6, 1.6, TIRE[0])
    c.ellipse(37, 30, 1.6, 1.6, TIRE[0])
    outline_trace(c)
    return c


def prop_runner_hut_2():
    """Coliba Collector-ului, cand sunt doi (48x40): acelasi adapost deschis din stuf, dar cu doua travee,
    o plasa pusa la uscat intre stalpii din dreapta si un cos cu prinderi."""
    c = C(48, 40)
    soft_shadow(c, 24, 37, 21, 3)
    c.rect(8, 20, 32, 14, WOOD[2])  # peretele din spate
    for y in range(23, 33, 3):
        c.rect(8, y, 32, 1, WOOD[1])
    c.rect(8, 20, 32, 1, WOOD[3])
    for px in (4, 22, 41):  # trei stalpi
        c.rect(px, 17, 3, 18, WOOD[1])
        c.rect(px, 17, 1, 18, WOOD[3])
        c.rect(px - 1, 34, 5, 2, WOOD[0])
    for i in range(16):  # stuful, lat
        inset = round((15 - i) * 20 / 16)
        c.rect(1 + inset, 3 + i, 46 - 2 * inset, 1, THATCH[2] if i % 2 else THATCH[1])
    c.rect(1, 19, 46, 1, THATCH[0])
    for i, x in enumerate(range(2, 46, 5)):
        col = THATCH[1] if i % 2 == 0 else THATCH[2]
        c.rect(x, 20, 4, 2, col)
        c.put(x + 1, 22, col)
    for yy in range(24, 33):  # plasa la uscat, intre stalpii din dreapta
        for xx in range(26, 40):
            if (xx + yy) % 3 == 0 or (xx - yy) % 3 == 0:
                c.put(xx, yy, NET_THREAD_L[2])
    c.rect(26, 24, 14, 1, ROPE[2])
    c.rect(10, 29, 9, 5, BURLAP[2])  # cosul cu prinderi, in traveea din stanga
    c.rect(10, 29, 9, 1, BURLAP[4])
    log_side(c, 11, 17, 28, 1)
    outline_trace(c)
    return c


def prop_stall_2():
    """Taraba Innkeeper-ului, cand sunt doi (64x40): aceeasi copertina in dungi, dar in doua bucati pe trei
    stalpi, tejghea lunga cu doua lazi si un butoi."""
    c = C(64, 40)
    soft_shadow(c, 32, 37, 27, 3)
    for px in (5, 30, 56):
        c.rect(px, 14, 3, 21, WOOD[1])
        c.rect(px, 14, 1, 21, WOOD[3])
        c.rect(px + 2, 14, 1, 21, WOOD[0])
    c.rect(2, 29, 60, 7, WOOD[2])  # tejgheaua
    c.rect(2, 29, 60, 1, WOOD[4])
    c.rect(2, 35, 60, 1, WOOD[0])
    for x in range(4, 62, 7):
        c.rect(x, 30, 1, 5, WOOD[0])
    for sx in (2, 32):  # doua copertine
        for i in range(9):
            y, w, x0 = 6 + i, 30 - i * 2, sx + i
            for k in range(w):
                band = ((x0 + k) // 5) % 2
                c.put(x0 + k, y, AWNING[2] if band == 0 else CREAM[2])
        c.rect(sx, 6, 30, 1, AWNING[3])
        c.rect(sx, 14, 30, 1, AWNING[0])
        for i, x in enumerate(range(sx + 1, sx + 29, 6)):
            col = AWNING[1] if i % 2 == 0 else CREAM[1]
            c.rect(x, 15, 5, 2, col)
            c.put(x + 2, 17, col)
    for x in (12, 42):  # doua lazi pe tejghea
        c.rect(x, 23, 9, 6, WOOD[1])
        c.rect(x, 23, 9, 1, WOOD[3])
        c.rect(x + 4, 23, 1, 6, WOOD[0])
    c.rect(24, 22, 5, 7, WOOD[2])  # un butoias
    c.rect(24, 24, 5, 1, STONE[1])
    c.rect(24, 27, 5, 1, STONE[1])
    outline_trace(c)
    return c


SPRITES = {
    "prop_barrow": prop_barrow,
    "prop_load_logs": prop_load_logs,
    "prop_load_planks": prop_load_planks,
    "prop_load_scrap": prop_load_scrap,
    "prop_load_iron": prop_load_iron,
    "prop_load_crate": prop_load_crate,
    "prop_pile_logs": prop_pile_logs,
    "prop_pile_planks": prop_pile_planks,
    "prop_pile_scrap": prop_pile_scrap,
    "prop_pile_iron": prop_pile_iron,
    "goods_iron": goods_iron,
    "prop_scrap_shed": prop_scrap_shed,
    "prop_ruin_scrap_shed": prop_ruin_scrap_shed,
    "prop_hut_porter_1": prop_hut_porter_1,
    "prop_hut_porter_2": prop_hut_porter_2,
    "prop_hut_sawyer_1": prop_hut_sawyer_1,
    "prop_hut_sawyer_2": prop_hut_sawyer_2,
    "prop_hut_hauler_1": prop_hut_hauler_1,
    "prop_hut_hauler_2": prop_hut_hauler_2,
    "prop_runner_hut_2": prop_runner_hut_2,
    "prop_stall_2": prop_stall_2,
}


def main():
    force = "--force" in sys.argv
    for name, fn in SPRITES.items():
        path = os.path.join(OUT, name + ".png")
        if os.path.exists(path) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
        c = fn()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
