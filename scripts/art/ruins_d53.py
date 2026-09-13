#!/usr/bin/env python3
"""Ruinele malului, avizierele si atelierul nou [D53].

Owner-ul: "in locul acestor chestii cu negru care urmeaza a fi deblocate, sa fie de fapt niste ruine sau
lucruri stricate pe jos", "change the texture to the workshop, looks awful". Fiecare ruina are AMPRENTA
cladirii ei (acelasi canvas, aceeasi baza), ca la cumparare cladirea sa rasara exact pe locul ruinei.
Pentru Porter, Sawyer si Hauler nu e ruina, ci un avizier: pe oameni ii angajezi, nu ii reconstruiesti.

Aceleasi reguli ca restul conductei (buildings.py / tycoon*.py):
  * culorile din palette.ramp() si din rampele deja folosite de cladirile construite (lemnul vechi e
    WEATHERED, lemnul de doc din tycoon_f3), ca ruina si cladirea sa para acelasi obiect, alta vreme;
  * umbra din elipse translucide, conturul trasat automat;
  * NU suprascrie un sprite existent.

Rulare: python3 scripts/art/ruins_d53.py   (apoi preview_ruins.py pentru previzualizare)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, T, png, shadow  # noqa: E402
from palette import WOOD, STONE, FOAM, LEAF_WARM, ramp, mix  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402
from tycoon import BRONZE, BURLAP, AWNING, CREAM, RUST, GLAZE  # noqa: E402
from tycoon_f2 import ROPE, THATCH  # noqa: E402
from tycoon_f3 import WEATHERED, NET_THREAD  # noqa: E402
from tycoon_e1 import PLANK, LOGW, WARM, GOLD, GOLD_HI, STEEL, outline_trace  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

MOSS = ramp(98, 0.42, 0.44)  # muschi pe lemnul si pe piatra vechi
PATINA = ramp(165, 0.34, 0.54)  # bronzul clopotului, verzui de vreme (BRONZE e clopotul intreg)
CHAR = ramp(24, 0.34, 0.36)  # barne arse, maro inchis -- nu negre: negrul e exact ce owner-ul n-a vrut
# acoperisul atelierului: sindrila verde-cenusie -- nici ardezia tavernei, nici sindrila rosiatica a
# gaterului, nici stuful colibei, nici scandurile depozitului
WORKSHOP_ROOF = ramp(150, 0.22, 0.46)
PAPER = ramp(44, 0.14, 0.90)  # hartia anuntului


def erase(c, x, y, w=1, h=1):
    """Scoate pixeli (put() nu poate: alfa 0 nu schimba nimic)."""
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            if 0 <= xx < c.w and 0 <= yy < c.h:
                c.px[yy][xx] = T


def line(c, x0, y0, x1, y1, col, thick=1):
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        c.rect(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), thick, thick, col)


def beam(c, x0, y0, x1, y1, tones, thick=2):
    """Grinda cazuta, in diagonala: umbra dedesubt, lumina pe muchia de sus."""
    line(c, x0, y0 + 1, x1, y1 + 1, tones[0], thick)
    line(c, x0, y0, x1, y1, tones[2], thick)
    line(c, x0, y0, x1, y1, tones[3], 1)


def weeds(c, rng, x0, x1, y, n):
    """Buruieni scurte la baza: ruina sta de mult acolo."""
    for _ in range(n):
        x = rng.i(x0, x1)
        h = rng.i(1, 3)
        c.rect(x, y - h, 1, h, LEAF_WARM[rng.i(1, 3)])
        if rng.n() < 0.4:
            c.put(x + 1, y - h + 1, LEAF_WARM[2])


# --------------------------------------------------------------- plasele
def prop_ruin_netpost():
    """Stalpul plasei (14x30, ca prop_netpost), rupt la jumatate, cu o tura de franghie ramasa si capatul
    ei atarnand. Talpa infipta in ponton e aceeasi: acolo va sta stalpul nou."""
    c = C(14, 30)
    soft_shadow(c, 7, 27, 5, 2)
    c.rect(5, 12, 4, 12, WEATHERED[1])
    c.rect(5, 12, 1, 12, WEATHERED[3])
    c.rect(8, 12, 1, 12, WEATHERED[0])
    for x, h in ((5, 3), (6, 1), (7, 4), (8, 2)):  # capatul rupt, in zimti
        c.rect(x, 12 - h, 1, h, WEATHERED[2] if x % 2 else WEATHERED[1])
    c.put(7, 8, WEATHERED[4])
    c.rect(3, 16, 8, 2, ROPE[1])  # o tura de franghie
    c.rect(3, 16, 8, 1, ROPE[2])
    c.put(3, 17, ROPE[0])
    c.put(10, 17, ROPE[0])
    for k in range(5):  # capatul rupt, care atarna
        c.put(10 + (k % 2), 18 + k, ROPE[1] if k % 2 else ROPE[2])
    c.rect(5, 22, 2, 2, MOSS[2])
    c.put(8, 23, MOSS[1])
    for i in range(5):  # talpa, ca la stalpul nou
        w = max(1, 4 - i)
        c.rect(6 - w // 2, 24 + i, w, 1, WEATHERED[0] if i % 2 else WEATHERED[1])
    outline_bottom(c, 0, 0, 14, 30)
    return c


def prop_ruin_net():
    """Plasa rupta (32x18, ca prop_net_water), pe banda ei. Fara fundal de apa: prin gaura se vede raul
    adevarat, nu o pata inchisa. Doar o bucata de plasa agatata de rama din stanga, lasata spre apa, fire
    rupte care atarna si rama de plutitori franta, cu capatul din dreapta scufundat."""
    c = C(32, 18)
    # plasa ramasa: un triunghi lasat, prins sus in stanga, rupt spre dreapta-jos
    for i, k in enumerate(range(-18, 36, 7)):
        tone = NET_THREAD[2] if i % 2 == 0 else NET_THREAD[1]
        for y in range(2, 16):
            for x in (k + y, k - y):
                if 1 <= x < 31 and x < 22 - (y - 2) * 0.9:
                    c.put(x, y, tone)
    for x, y, n in ((20, 3, 5), (17, 6, 6), (13, 10, 5), (9, 13, 4)):  # fire rupte, care atarna
        for k in range(n):
            c.put(x + (k % 2), y + k, NET_THREAD[1] if k % 2 else NET_THREAD[2])
    for fx, fy in ((6, 15), (12, 14), (24, 9), (28, 11)):  # spuma unde plasa atinge apa
        c.put(fx, fy, FOAM[3])
        c.put(fx + 1, fy - 1, FOAM[2])
    c.rect(2, 1, 14, 1, WEATHERED[1])  # rama: bucata din stanga, inca pe loc
    c.rect(3, 0, 11, 1, WEATHERED[3])
    for fx in (5, 10):
        c.put(fx, 0, WEATHERED[0])
    for yy, xx in ((3, 19), (5, 22), (7, 25), (9, 28)):  # bucata din dreapta, franta si scufundata
        c.rect(xx, yy, 3, 1, WEATHERED[1])
        c.put(xx, yy - 1, WEATHERED[3])
    return c


# --------------------------------------------------------------- recuzita construita
def prop_ruin_hut():
    """Coliba Collector-ului (40x36, ca prop_runner_hut), prabusita: peretele din spate cu scanduri lipsa,
    un stalp in picioare, celalalt cazut, acoperisul de stuf lasat pe o parte, paie imprastiate."""
    c = C(40, 36)
    rng = Rng(5301)
    soft_shadow(c, 20, 33, 16, 3)
    for i, y in enumerate(range(18, 30, 3)):
        c.rect(9, y, 22, 2, WEATHERED[2] if i % 2 == 0 else WEATHERED[1])
        c.rect(9, y + 2, 22, 1, WEATHERED[0])
    for gx, gy, gw in ((12, 18, 5), (24, 21, 4), (18, 24, 3)):
        erase(c, gx, gy, gw, 2)
    c.rect(5, 17, 3, 14, WEATHERED[1])  # stalpul din stanga, rupt sus
    c.rect(5, 17, 1, 14, WEATHERED[3])
    c.rect(7, 17, 1, 14, WEATHERED[0])
    c.put(5, 16, WEATHERED[2])
    c.put(6, 15, WEATHERED[3])
    c.rect(4, 30, 5, 2, WEATHERED[0])
    beam(c, 34, 30, 22, 15, WEATHERED, 2)  # stalpul din dreapta, cazut peste perete
    for i in range(10):  # acoperisul de stuf, prabusit pe dreapta
        y = 22 + i
        x0 = 14 + max(0, 6 - i)
        x1 = 39 - max(0, 3 - i // 2)
        c.rect(x0, y, x1 - x0, 1, THATCH[2] if i % 2 == 0 else THATCH[1])
    c.rect(16, 21, 18, 1, THATCH[3])
    for x in range(15, 38, 4):
        c.put(x, 20, THATCH[3])
        c.put(x + 1, 21, THATCH[4])
    c.rect(14, 31, 25, 1, THATCH[0])
    for _ in range(9):
        c.put(rng.i(2, 13), rng.i(29, 33), THATCH[rng.i(1, 3)])
    c.rect(9, 28, 5, 2, WEATHERED[1])  # banca, rupta
    c.rect(9, 28, 5, 1, WEATHERED[3])
    weeds(c, rng, 2, 38, 33, 7)
    outline_bottom(c, 0, 0, 40, 36)
    return c


def prop_ruin_stall():
    """Taraba de langa taverna (48x40, ca prop_stall), cazuta: un stalp rupt, tejgheaua franta la mijloc,
    copertina in dungi rupta si lasata pe tejghea, o lada sparta."""
    c = C(48, 40)
    rng = Rng(5302)
    soft_shadow(c, 24, 37, 20, 3)
    c.rect(5, 14, 3, 21, WEATHERED[1])  # stalpul din stanga, in picioare
    c.rect(5, 14, 1, 21, WEATHERED[3])
    c.rect(7, 14, 1, 21, WEATHERED[0])
    c.rect(39, 24, 3, 11, WEATHERED[1])  # stalpul din dreapta, rupt
    c.rect(39, 24, 1, 11, WEATHERED[3])
    c.put(39, 23, WEATHERED[2])
    c.put(41, 22, WEATHERED[3])
    beam(c, 30, 36, 44, 33, WEATHERED, 2)  # bucata lui de sus, pe jos
    c.rect(2, 29, 20, 6, WEATHERED[2])  # jumatatea din stanga a tejghelei
    c.rect(2, 29, 20, 1, WEATHERED[4])
    c.rect(2, 34, 20, 1, WEATHERED[0])
    for x in range(4, 22, 7):
        c.rect(x, 30, 1, 4, WEATHERED[0])
    beam(c, 22, 30, 36, 35, WEATHERED, 3)  # jumatatea din dreapta, cazuta
    for i in range(12):  # copertina rupta, lasata de pe stalpul din stanga
        y = 13 + i
        x0 = 4 + i // 3
        w = max(4, 30 - i * 2)
        for k in range(w):
            if (k + i) % 9 == 0:
                continue  # gauri in panza
            band = ((x0 + k) // 5) % 2
            col = AWNING[2] if band == 0 else CREAM[2]
            c.put(x0 + k, y, mix(col, WEATHERED[1], 0.25))
    c.rect(4, 13, 28, 1, AWNING[3])
    for x in (10, 18, 25):  # zdrente care atarna
        for k in range(rng.i(3, 6)):
            c.put(x + (k % 2), 25 + k, CREAM[1] if k % 2 else AWNING[1])
    c.rect(26, 30, 8, 5, WOOD[1])  # lada sparta
    c.rect(26, 30, 8, 1, WOOD[3])
    erase(c, 29, 30, 3, 2)
    c.put(34, 34, WOOD[2])
    c.put(35, 35, WOOD[1])
    weeds(c, rng, 1, 46, 37, 8)
    outline_bottom(c, 0, 0, 48, 40)
    return c


def prop_ruin_sack():
    """Traista mare (24x24, ca prop_sack), rupta si turtita, cu ce s-a varsat din ea, langa o lada sparta.
    Panza calda, nu cenusie: altfel de departe parea o piatra."""
    c = C(24, 24)
    rng = Rng(5303)
    soft_shadow(c, 12, 21, 10, 3)
    c.rect(13, 9, 8, 7, WOOD[2])  # lada sparta, in spate
    c.rect(13, 9, 8, 1, WOOD[4])
    c.rect(16, 9, 1, 7, WOOD[0])
    erase(c, 18, 10, 2, 2)
    beam(c, 3, 13, 10, 10, WOOD, 2)  # o scandura de lada, cazuta
    c.ellipse(10, 18, 8, 4.5, BURLAP[2])  # sacul, pe o parte
    c.ellipse(8, 16.5, 4, 2, BURLAP[3])
    c.ellipse(13, 20, 4, 2, BURLAP[1])
    c.ellipse(15, 17, 2.5, 1.5, BURLAP[0])  # ruptura
    for x, y in ((18, 19), (20, 18), (19, 21), (21, 20)):  # ce s-a varsat
        c.put(x, y, LOGW[2])
    c.rect(2, 16, 3, 3, BURLAP[2])  # gura desfacuta, cu franghia rupta
    c.put(1, 17, ROPE[1])
    c.put(0, 18, ROPE[0])
    weeds(c, rng, 1, 22, 22, 4)
    outline_bottom(c, 0, 0, 24, 24)
    return c


def prop_ruin_bell():
    """Clopotul Debarcaderului (40x56, ca prop_bell), cazut: un stalp rupt, grinda de sus la pamant,
    clopotul pe o parte in iarba, verzui de vreme. Totul sta jos, in treimea de jos a canvasului."""
    c = C(40, 56)
    rng = Rng(5304)
    soft_shadow(c, 20, 53, 16, 3)
    c.rect(6, 30, 4, 15, WEATHERED[1])  # stalpul din stanga, rupt
    c.rect(6, 30, 1, 15, WEATHERED[3])
    c.rect(9, 30, 1, 15, WEATHERED[0])
    c.put(7, 29, WEATHERED[2])
    c.put(8, 28, WEATHERED[3])
    c.rect(3, 42, 4, 4, WEATHERED[0])
    c.rect(30, 41, 4, 4, WEATHERED[1])  # ciotul celuilalt
    c.rect(30, 41, 4, 1, WEATHERED[3])
    beam(c, 4, 49, 36, 38, WEATHERED, 3)  # grinda de sus, la pamant
    c.ellipse(22, 44, 8, 6, PATINA[1])  # clopotul, pe o parte
    c.ellipse(19, 42, 4, 3, PATINA[3])
    c.ellipse(30, 45, 2.5, 7, PATINA[0])  # buza, spre dreapta
    c.ellipse(29, 45, 1.5, 5, PATINA[2])
    c.ellipse(34, 50, 2, 2, BRONZE[0])  # limba, iesita
    c.put(17, 40, PATINA[4])
    weeds(c, rng, 2, 38, 51, 9)
    outline_bottom(c, 0, 0, 40, 56)
    return c


# --------------------------------------------------------------- atelierul
def prop_workshop_e1():
    """Atelierul [D53] (64x48, PIXEL_SCALE 3 -> 192x144), in locul lui b_workshop din era coloniei. Aceeasi
    familie cu taverna (barne, acoperis in trepte, 64x48), dar alt material pe acoperis si o fata care
    spune ATELIER dintr-o privire: in stanga fereastra-raft cu gasirile de pe rau (una straluceste -- de
    aici se completeaza colectia), in dreapta golul deschis cu bancul, menghina, o scandura in lucru si
    uneltele pe perete; deasupra, firma cu ciocanul; hornul de piatra al fierariei."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    c.rect(4, 19, 56, 26, WOOD[2])  # peretii din barne
    for y in range(19, 45, 3):
        c.rect(4, y + 2, 56, 1, WOOD[1])
        c.rect(4, y, 56, 1, WOOD[3])
        for x in (3, 60):
            c.rect(x, y, 2, 2, LOGW[3])
            c.put(x if x == 3 else x + 1, y, LOGW[4])
    for i in range(14):  # acoperisul, in trepte
        x0 = 13 - i
        c.rect(x0, 5 + i, 64 - 2 * x0, 1, WORKSHOP_ROOF[2] if i % 2 else WORKSHOP_ROOF[3])
        if i % 2 == 0:
            for x in range(x0 + (i // 2) % 3, 64 - x0, 4):
                c.put(x, 5 + i, WORKSHOP_ROOF[1])
    c.rect(1, 18, 62, 2, WORKSHOP_ROOF[0])
    c.rect(13, 4, 38, 1, WORKSHOP_ROOF[4])
    c.rect(46, 0, 6, 10, STONE[2])  # hornul
    c.rect(46, 0, 6, 1, STONE[3])
    c.rect(46, 5, 6, 1, STONE[1])
    c.rect(51, 1, 1, 9, STONE[1])
    # fereastra-raft: gasirile
    c.rect(8, 25, 18, 11, WOOD[0])
    c.rect(9, 26, 16, 9, WARM[2])
    c.rect(9, 26, 16, 2, WARM[3])
    c.rect(9, 31, 16, 1, WOOD[1])  # polita
    c.rect(11, 28, 2, 3, STEEL[2])  # o sticla veche
    c.put(11, 28, STEEL[4])
    c.ellipse(16, 29.5, 1.5, 1.5, GLAZE[2])  # un ciob pictat
    c.put(15, 29, GLAZE[4])
    c.ellipse(21, 29, 1.8, 1.8, GOLD[2])  # gasirea care straluceste
    c.put(20, 28, GOLD_HI[4])
    for sx, sy in ((23, 27), (19, 26), (24, 30)):
        c.put(sx, sy, GOLD_HI[3])
    c.rect(11, 33, 4, 1, PLANK[2])  # pe raftul de jos: o scandura, o cheie
    c.rect(18, 33, 5, 1, STEEL[1])
    c.rect(7, 35, 20, 2, PLANK[3])  # pervazul
    c.rect(7, 35, 20, 1, PLANK[4])
    # golul atelierului: interior in umbra
    c.rect(30, 25, 27, 20, WOOD[0])
    for y in range(28, 44, 4):
        c.rect(30, y, 27, 1, mix(WOOD[0], WOOD[1], 0.5))
    c.rect(29, 24, 2, 21, WOOD[3])  # rama
    c.rect(56, 24, 2, 21, WOOD[3])
    c.rect(29, 24, 29, 1, WOOD[4])
    c.rect(33, 28, 8, 2, STEEL[3])  # ferastraul pe perete
    c.rect(33, 29, 8, 1, STEEL[1])
    c.rect(41, 28, 2, 2, WOOD[2])
    c.rect(46, 27, 1, 6, WOOD[3])  # ciocanul
    c.rect(44, 27, 5, 2, STEEL[2])
    c.rect(51, 27, 2, 3, WARM[4])  # felinarul
    c.put(51, 30, WOOD[0])
    c.rect(31, 36, 25, 3, PLANK[3])  # bancul
    c.rect(31, 36, 25, 1, PLANK[4])
    c.rect(31, 38, 25, 1, PLANK[1])
    for x in (33, 53):
        c.rect(x, 39, 2, 6, WOOD[1])
    c.rect(34, 32, 4, 4, STEEL[2])  # menghina
    c.rect(34, 32, 4, 1, STEEL[4])
    c.rect(38, 33, 2, 1, STEEL[1])
    c.rect(41, 34, 11, 2, PLANK[2])  # scandura in lucru
    c.rect(41, 34, 11, 1, PLANK[4])
    for x, y in ((40, 44), (45, 43), (48, 44), (37, 43)):  # rumegus
        c.put(x, y, PLANK[4])
    # firma: ciocanul auriu pe o scandura inchisa
    c.rect(36, 19, 14, 6, (60, 40, 26, 255))
    c.rect(37, 20, 12, 4, WOOD[1])
    c.rect(39, 22, 7, 1, GOLD[2])  # coada
    c.rect(44, 20, 3, 4, GOLD_HI[3])  # capul
    c.put(44, 20, GOLD_HI[4])
    c.rect(0, 36, 3, 9, PLANK[2])  # scanduri rezemate, in stanga
    c.rect(1, 35, 2, 10, PLANK[3])
    outline_trace(c)
    return c


def prop_ruin_workshop():
    """Ruina atelierului (64x48, aceeasi amprenta): temelia de piatra, doua colturi de zid, ciotul hornului,
    barne cazute si innegrite, bancul rupt cu menghina ruginita, firma cu ciocanul la pamant."""
    c = C(64, 48)
    rng = Rng(5305)
    shadow(c, 32, 45, 30, 2)
    for x in range(3, 61, 4):  # temelia
        h = 3 + (rng.i(0, 2) if 20 < x < 50 else rng.i(1, 4))
        c.rect(x, 44 - h, 4, h, STONE[2] if (x // 4) % 2 else STONE[1])
        c.rect(x, 44 - h, 4, 1, STONE[3])
    c.rect(3, 43, 58, 2, STONE[0])
    c.rect(3, 30, 6, 14, STONE[1])  # coltul din stanga
    c.rect(3, 30, 6, 1, STONE[3])
    c.rect(8, 30, 1, 14, STONE[0])
    c.rect(55, 34, 6, 10, STONE[1])  # coltul din dreapta
    c.rect(55, 34, 6, 1, STONE[3])
    c.rect(46, 26, 6, 18, STONE[2])  # ciotul hornului
    c.rect(46, 26, 6, 1, STONE[3])
    c.rect(51, 27, 1, 17, STONE[1])
    c.put(47, 25, STONE[2])
    c.put(49, 24, STONE[3])
    beam(c, 10, 41, 40, 24, CHAR, 3)  # barnele cazute
    beam(c, 22, 43, 58, 33, WEATHERED, 3)
    beam(c, 12, 30, 30, 38, CHAR, 2)
    c.rect(28, 38, 12, 3, WEATHERED[2])  # bancul rupt
    c.rect(28, 38, 12, 1, WEATHERED[4])
    c.rect(30, 41, 2, 3, WEATHERED[0])
    c.rect(34, 35, 4, 3, RUST[2])  # menghina ruginita
    c.rect(34, 35, 4, 1, RUST[3])
    c.rect(14, 42, 12, 4, WEATHERED[1])  # firma, la pamant
    c.rect(17, 43, 5, 1, GOLD[1])
    c.rect(21, 42, 2, 3, GOLD[0])
    weeds(c, rng, 2, 62, 46, 16)
    for _ in range(8):  # muschi pe pietre
        x, y = rng.i(4, 60), rng.i(34, 43)
        if c.px[y][x][3]:
            c.put(x, y, MOSS[2])
    outline_trace(c)
    return c


# --------------------------------------------------------------- avizierele
def prop_board_old():
    """Avizierul unde se angajeaza un om, inainte (24x32): panou strâmb pe doi stalpi, unul aplecat, un
    anunt rupt cu scrisul sters -- "aici se cauta cineva", fara un cuvant pe el."""
    c = C(24, 32)
    rng = Rng(5306)
    soft_shadow(c, 12, 29, 9, 2)
    c.rect(4, 12, 2, 18, WOOD[1])  # stalpul din stanga
    c.rect(4, 12, 1, 18, WOOD[3])
    line(c, 19, 30, 20, 12, WOOD[1], 2)  # cel din dreapta, aplecat
    for yy in range(12):  # panoul, strâmb, lemn vechi dar cald
        for xx in range(18):
            c.put(3 + xx, 8 + yy + xx // 8, mix(WEATHERED[2], WOOD[2], 0.5) if yy % 4 else WOOD[1])
    for yy in range(7):  # anuntul, cu un colt rupt
        for xx in range(9):
            if xx + yy > 12:
                continue
            c.put(7 + xx, 10 + yy + (xx + 4) // 8, PAPER[2] if (xx + yy) % 5 else PAPER[1])
    for k in range(3):  # scrisul, sters
        c.rect(8, 12 + k * 2, 5 - k, 1, PAPER[0])
    c.put(11, 10, STEEL[3])  # cuiul
    weeds(c, rng, 2, 22, 30, 5)
    outline_bottom(c, 0, 0, 24, 32)
    return c


def prop_board():
    """Avizierul dupa angajare (24x32): drept, cu un mic acoperis de scanduri si o hartie curata prinsa in
    doua cuie. Pictograma meseriei (bustean / ferastrau / scanduri) o pune codul, pe hartie (centrul ei e
    la x 12, y 15)."""
    c = C(24, 32)
    soft_shadow(c, 12, 29, 9, 2)
    for px in (4, 18):
        c.rect(px, 10, 2, 20, WOOD[1])
        c.rect(px, 10, 1, 20, WOOD[3])
    for i in range(3):  # acoperisul mic
        c.rect(2 + i, 5 - i, 20 - 2 * i, 1, PLANK[3] if i % 2 == 0 else PLANK[2])
    c.rect(1, 6, 22, 1, PLANK[1])
    c.rect(3, 8, 18, 14, WOOD[2])  # panoul
    c.rect(3, 8, 18, 1, WOOD[4])
    c.rect(3, 21, 18, 1, WOOD[0])
    c.rect(5, 9, 14, 12, PAPER[3])  # hartia
    c.rect(5, 9, 14, 1, PAPER[4])
    c.rect(5, 20, 14, 1, PAPER[1])
    c.put(6, 10, STEEL[3])
    c.put(17, 10, STEEL[3])
    outline_bottom(c, 0, 0, 24, 32)
    return c


SPRITES = {
    "prop_ruin_netpost": prop_ruin_netpost,
    "prop_ruin_net": prop_ruin_net,
    "prop_ruin_hut": prop_ruin_hut,
    "prop_ruin_stall": prop_ruin_stall,
    "prop_ruin_sack": prop_ruin_sack,
    "prop_ruin_bell": prop_ruin_bell,
    "prop_workshop_e1": prop_workshop_e1,
    "prop_ruin_workshop": prop_ruin_workshop,
    "prop_board_old": prop_board_old,
    "prop_board": prop_board,
}


def main():
    names = sys.argv[1:] or list(SPRITES)
    for name in names:
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            print(f"  {name}.png  exista deja, sarit")
            continue
        c = SPRITES[name]()
        png(f"{name}.png", c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")


if __name__ == "__main__":
    main()
