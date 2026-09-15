#!/usr/bin/env python3
"""Arta pentru D59: pontonul ca loc unde astepti -- undita, ce aduce raul, roata la ponton, avizierul satului si
decorul cumparat cu perle.

Owner-ul (2026-09-15): "A si B cum recomanzi, apuca-te. si sa slefuim lucky wheel, nu prea se integreaza cu cap".
Planul aprobat: pontonul se prelungeste in rau si devine locul de pescuit; lucrurile aduse de rau stau langa el;
roata devine un timonier de lemn pe punte; perlele cumpara aspect (decorul satului, tinutele din settlers.py).

  * prop_pier_long (32x104) -- pontonul lung: jumatatea de sus peste apa (stalpi cu freamat), cea de jos pe mal
  * prop_bobber (8x10) -- plutitorul; firul il deseneaza codul, din varful batului pana aici
  * fish_<specie> (20x16) -- cele 12 specii ale jurnalului, pe profil (capul la stanga)
  * treasure_<fel> si treasure_<fel>_water -- sticla (16x16), cufarul (20x16), Golden Driftwood (24x12): intregi
    (jurnalul, rezultatul) si pe jumatate in apa (cand plutesc si cand asteapta la ponton)
  * prop_helm (40x48) -- roata zilnica in lume: timonier de lemn pe un stalp, pe punte
  * ui_helm (64x64) -- fata roatii din panou: spitele la multipli de 45 de grade (una sus), iconitele premiilor le
    pune codul intre ele, din WheelConfig -- desenul nu stie ce premii exista
  * prop_village_board (40x44) -- avizierul satului, cu biletele prinse in cuie
  * icon_bait / icon_note / icon_spin (16x16) -- momeala aurie, biletul din sticla, roata din bara de meniu
  * decor_* -- cele zece imbunatatiri ale satului (VillageConfig.DECOR)

Aceleasi reguli ca restul conductei: compunere alfa "over", conturul trasat prin vecinatate (outline_trace) sau
doar unde obiectul atinge pamantul (outline_bottom), umbra din elipse translucide, culori din palette.ramp.

Rulare: python3 scripts/art/d59.py [--force]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, T, png  # noqa: E402
from palette import WOOD, STONE, WATER, WATER_DEEP, FOAM, LEAF, LEAF_WARM, DIRT, OUTLINE, ramp, hsv, mix  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402
from tycoon import AWNING, CREAM, BURLAP  # noqa: E402
from tycoon_f2 import ROPE, THATCH  # noqa: E402
from tycoon_f3 import WEATHERED, GAP_LINE, water_ripple  # noqa: E402
from tycoon_e1 import outline_trace, GOLD, GOLD_HI, PEARL, STEEL, BRASS, PARCH, PARCH_D, INK, WARM, SHINGLE, PLANK  # noqa: E402
from ruins_d53 import line, MOSS  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

GLASS = ramp(158, 0.34, 0.62)  # sticla verzuie a sticlei
BLUE_PAINT = ramp(206, 0.46, 0.62)  # vopseaua barcii legate: alta decat barca vanzarii (lemn gol)
FLAG_COLORS = (AWNING[3], GOLD[3], ramp(210, 0.52, 0.70)[3], ramp(130, 0.46, 0.60)[3])


def lit(tones, t):
    """Tonul dintr-o rampa pentru o lumina t in [0, 1] (0 = umbra)."""
    return tones[min(len(tones) - 1, max(0, int(t * len(tones))))]


# --------------------------------------------------------------- pontonul lung
def prop_pier_long():
    """prop_pier3 prelungit: aceleasi scanduri transversale cu rost de 1 px si aceleasi grinzi pe margini, dar de doua ori
    mai lung, ca personajul sa mearga pe el pana deasupra apei. Jumatatea de sus (WET) e peste rau: stalpi cu freamat,
    scanduri mai inchise spre capat, unde apa trece peste ele. La capat, o galeata de momeala: locul de pescuit se
    recunoaste inainte sa citesti cardul."""
    c = C(32, 104)
    dx, dw = 4, 24
    top, bot = 2, 104
    wet = 58
    for py in (top + 8, top + 27, top + 46):
        for side in (dx - 3, dx + dw):
            c.rect(side, py, 3, 7, WEATHERED[1])
            c.rect(side, py, 1, 7, WEATHERED[2])
            c.rect(side + 2, py, 1, 7, WEATHERED[0])
            c.rect(side, py + 6, 3, 1, WEATHERED[0])
            water_ripple(c, side + 1, py + 7, 4, 1.6)
    tones = [WEATHERED[2], mix(WEATHERED[2], WEATHERED[1], 0.3), mix(WEATHERED[2], WEATHERED[3], 0.22), WEATHERED[2]]
    y, i = top, 0
    while y < bot:
        fill_h = bot - y if bot - y <= 6 else 5
        tone = tones[i % len(tones)]
        if y < wet:  # spre capat, lemnul ud se intuneca treptat
            tone = mix(tone, WATER_DEEP[0], 0.34 * (1 - y / wet) + 0.06)
        c.rect(dx, y, dw, fill_h, tone)
        c.rect(dx, y, dw, 1, mix(tone, WEATHERED[4], 0.35))
        y += fill_h
        if y < bot:
            c.rect(dx, y, dw, 1, GAP_LINE)
            y += 1
        i += 1
    c.rect(dx, top, 2, bot - top, WEATHERED[1])
    c.rect(dx + dw - 2, top, 2, bot - top, WEATHERED[0])
    for fx, fy in ((9, top + 5), (14, top + 13), (11, top + 22), (19, top + 9), (22, top + 31), (8, top + 38)):
        c.put(fx, fy, FOAM[3])
    # babordul din coltul stang al capatului, ca la pier3
    c.rect(dx - 1, 0, 2, 8, WEATHERED[2])
    c.rect(dx - 1, 0, 1, 8, WEATHERED[3])
    c.ellipse(dx - 0.5, 0, 1.5, 1, WEATHERED[1])
    # galeata de momeala, pe capat, in stanga (pescuitul e pe partea dreapta)
    bx, by = dx + 3, top + 4
    c.rect(bx, by + 1, 5, 5, STEEL[1])
    c.rect(bx, by + 1, 1, 5, STEEL[2])
    c.rect(bx + 4, by + 1, 1, 5, STEEL[0])
    c.rect(bx, by, 5, 1, STEEL[3])
    c.rect(bx + 1, by + 1, 3, 1, hsv(24, 0.45, 0.30))  # momeala din galeata
    c.put(bx + 2, by - 1, STEEL[2])
    # franghii culcate pe partea de pe mal
    for cx, cy in ((dx + 16, top + 66), (dx + 8, top + 86)):
        for k in range(16):
            ang = 2 * math.pi * k / 16
            wob = 1.0 + 0.12 * math.sin(3 * ang)
            c.put(cx + math.cos(ang) * 2.6 * wob, cy + math.sin(ang) * 1.3 * wob, ROPE[1] if k % 2 == 0 else ROPE[0])
        c.put(cx - 1, cy, ROPE[3])
    return c


# --------------------------------------------------------------- plutitorul
def prop_bobber():
    c = C(8, 10)
    red = ramp(4, 0.72, 0.82)
    c.ellipse(3.5, 8.2, 3.6, 1.2, (FOAM[2][0], FOAM[2][1], FOAM[2][2], 110))
    c.rect(3, 0, 1, 2, INK)
    c.ellipse(3.5, 3.8, 2.5, 2.1, red[2])
    c.rect(2, 2, 2, 1, red[3])
    c.put(2, 3, red[4])
    c.rect(1, 5, 6, 1, hsv(40, 0.05, 0.98))
    c.ellipse(3.5, 6.6, 2.2, 1.1, hsv(40, 0.08, 0.86))
    outline_trace(c)
    return c


# --------------------------------------------------------------- pestii jurnalului
FISH = {
    # x0 = botul, x1 = baza cozii; half = jumatatea inaltimii maxime; snout = cat de bont e botul (0 ascutit)
    "minnow": dict(x0=4, x1=13, half=2.4, snout=0.10, tail="fork", tail_len=3, back=ramp(88, 0.30, 0.56),
                   belly=hsv(90, 0.08, 0.88), fin=hsv(80, 0.26, 0.62), pattern="stripe", mark=hsv(96, 0.40, 0.30)),
    "roach": dict(x0=2, x1=14, half=3.8, snout=0.10, tail="fork", tail_len=4, back=ramp(206, 0.26, 0.58),
                  belly=hsv(200, 0.05, 0.93), fin=hsv(6, 0.64, 0.80), eye=hsv(4, 0.70, 0.78)),
    "perch": dict(x0=2, x1=14, half=4.2, snout=0.14, tail="fork", tail_len=4, back=ramp(76, 0.52, 0.62),
                  belly=hsv(50, 0.38, 0.88), fin=hsv(16, 0.72, 0.86), pattern="bars", mark=hsv(96, 0.50, 0.28),
                  spiny=True),
    "bream": dict(x0=3, x1=14, half=5.3, snout=0.18, tail="fork", tail_len=4, back=ramp(40, 0.50, 0.58),
                  belly=hsv(44, 0.30, 0.86), fin=hsv(30, 0.40, 0.40)),
    "trout": dict(x0=2, x1=15, half=3.8, snout=0.10, tail="fork", tail_len=3, back=ramp(60, 0.36, 0.50),
                  belly=hsv(40, 0.18, 0.90), fin=hsv(40, 0.30, 0.55), band=hsv(356, 0.36, 0.80), pattern="spots",
                  mark=hsv(20, 0.50, 0.18), mark2=hsv(2, 0.66, 0.74)),
    "chub": dict(x0=2, x1=15, half=4.2, snout=0.34, tail="fork", tail_len=3, back=ramp(50, 0.16, 0.46),
                 belly=hsv(55, 0.06, 0.82), fin=hsv(20, 0.30, 0.36), pattern="scales", mark=hsv(40, 0.20, 0.30)),
    "carp": dict(x0=2, x1=15, half=4.6, snout=0.22, tail="fork", tail_len=4, back=ramp(36, 0.62, 0.58),
                 belly=hsv(44, 0.45, 0.90), fin=hsv(28, 0.55, 0.64), pattern="scales", mark=hsv(30, 0.60, 0.38),
                 barbels=True),
    "eel": dict(x0=1, x1=18, half=2.0, snout=0.06, tail="point", tail_len=0, back=ramp(80, 0.40, 0.36),
                belly=hsv(58, 0.40, 0.68), fin=hsv(70, 0.35, 0.28), wavy=True),
    "pike": dict(x0=1, x1=15, half=3.3, snout=0.02, tail="fork", tail_len=4, back=ramp(100, 0.42, 0.44),
                 belly=hsv(70, 0.26, 0.82), fin=hsv(30, 0.45, 0.56), pattern="light_spots", mark=hsv(64, 0.30, 0.84),
                 bill=True, dorsal_back=True),
    "catfish": dict(x0=4, x1=16, half=3.9, snout=0.40, tail="round", tail_len=3, back=ramp(220, 0.10, 0.36),
                    belly=hsv(40, 0.08, 0.68), fin=hsv(220, 0.10, 0.26), whiskers=True, small_eye=True),
    "sturgeon": dict(x0=1, x1=15, half=3.2, snout=0.02, tail="hetero", tail_len=4, back=ramp(210, 0.22, 0.48),
                     belly=hsv(200, 0.06, 0.86), fin=hsv(210, 0.20, 0.36), pattern="scutes", mark=hsv(40, 0.10, 0.92),
                     barbels=True),
    "goldcarp": dict(x0=2, x1=15, half=4.6, snout=0.22, tail="fork", tail_len=4, back=ramp(44, 0.80, 0.88),
                     belly=hsv(52, 0.46, 1.0), fin=hsv(24, 0.80, 0.92), pattern="scales", mark=GOLD[1],
                     barbels=True, sparkle=True),
}


def eel_icon(s):
    """Tiparul nu e un peste cu profil de lacrima: corp lung, in val, cu inotatoarea continua pe spate si pe burta.
    Varianta cu profilul pestilor iesea un bat drept, verde, fara nimic de tipar."""
    c = C(20, 16)
    back, belly, fin = s["back"], s["belly"], s["fin"]
    pts = []
    for x in range(1, 19):
        t = (x - 1) / 17
        cy = 8 + 2.6 * math.sin(t * 2.3 * math.pi + 0.6)
        half = 2.3 * (1 - 0.55 * t) if t > 0.15 else 1.6 + 4.5 * t
        pts.append((x, cy, max(0.9, half)))
    for x, cy, half in pts:  # inotatoarea continua, mai lata decat corpul
        if x > 5:
            c.rect(x, round(cy - half - 1), 1, round(2 * half + 2) + 1, fin)
    for x, cy, half in pts:
        ytop, ybot = round(cy - half), round(cy + half)
        for yy in range(ytop, ybot + 1):
            v = (yy - ytop) / max(1, ybot - ytop)
            c.put(x, yy, lit(back, 0.3 + v) if v < 0.55 else belly)
    x, cy, _ = pts[1]
    c.put(x, round(cy - 1), hsv(40, 0.05, 0.98))
    c.put(x + 1, round(cy - 1), INK)
    c.put(1, round(pts[0][1] + 1), back[0])
    outline_trace(c)
    return c


def fish_icon(s):
    if s.get("wavy"):
        return eel_icon(s)
    c = C(20, 16)
    cy = 8
    x0, x1, half = s["x0"], s["x1"], s["half"]
    back, belly, fin = s["back"], s["belly"], s["fin"]
    span = max(1, x1 - x0)
    prof = {}
    for x in range(x0, x1 + 1):
        t = (x - x0) / span
        h = half * math.sin(math.pi * (s["snout"] * 0.5 + 0.08 + (0.84 - s["snout"] * 0.5) * t ** 0.75))
        if s.get("flat"):
            h = max(1.2, half * (0.9 if t < 0.9 else 0.6))
        prof[x] = max(0.8, h)

    # inotatoarele din spate: dorsala si ventrala, desenate inaintea corpului
    dstart = x0 + int(span * (0.55 if s.get("dorsal_back") else 0.32))
    dlen = max(3, int(span * 0.28))
    for k in range(dlen):
        x = dstart + k
        top = cy - prof.get(x, 1)
        hgt = 2 if k < dlen - 1 else 1
        if s.get("spiny") and k % 2 == 0:
            hgt += 1
        c.rect(x, int(top - hgt), 1, hgt + 1, fin)
        if s.get("spiny") and k % 2 == 0:
            c.put(x, int(top - hgt), s["mark"])
    vx = x0 + int(span * 0.48)
    c.rect(vx, int(cy + prof[vx] - 0.2), 2, 2, fin)
    if s.get("flat"):  # tiparul: inotatoare continua pe spate si pe burta
        for x in range(x0 + span // 3, x1 + 1):
            c.put(x, int(cy - prof[x] - 1), fin)
            c.put(x, int(cy + prof[x] + 1), fin)

    # coada
    tl = s["tail_len"]
    ped = prof[x1]
    if s["tail"] == "point":
        for k in range(3):
            c.put(x1 + 1 + k, cy, fin)
    else:
        for k in range(tl):
            spread = ped + 0.9 + k * 1.05
            notch = 0 if s["tail"] == "round" else max(0.0, (k - 1) * 0.75)
            up = spread * (1.35 if s["tail"] == "hetero" else 1.0)
            for yy in range(int(cy - up), int(cy + spread) + 1):
                if abs(yy - cy) >= notch or s["tail"] == "round":
                    c.put(x1 + 1 + k, yy, fin)

    # corpul, cu spatele inchis si burta deschisa
    for x in range(x0, x1 + 1):
        h = prof[x]
        ytop, ybot = int(round(cy - h)), int(round(cy + h))
        for yy in range(ytop, ybot + 1):
            v = (yy - ytop) / max(1, ybot - ytop)
            if v < 0.5:
                col = lit(back, 0.35 + v * 1.1)
            else:
                col = mix(back[3], belly, min(1.0, (v - 0.45) * 2.2))
            c.put(x, yy, col)
        c.put(x, ytop, back[1])
    if s.get("band"):
        for x in range(x0 + 3, x1):
            c.put(x, cy, s["band"])
            if prof[x] > 2.5:
                c.put(x, cy + 1, mix(s["band"], belly, 0.5))

    rng = Rng(sum(ord(ch) for ch in s.get("mark_seed", str(x0 * 31 + x1 * 7 + int(half * 10)))))
    pat = s.get("pattern")
    if pat == "stripe":
        for x in range(x0 + 3, x1 + 1):
            c.put(x, cy, s["mark"])
    elif pat == "bars":
        for bx in range(x0 + 4, x1 - 1, 3):
            h = prof[bx]
            c.rect(bx, int(cy - h), 1, max(1, int(h * 1.3)), s["mark"])
    elif pat == "spots":
        for _ in range(9):
            x = rng.i(x0 + 4, x1 - 1)
            h = prof[x]
            y = rng.i(int(cy - h + 1), int(cy + h * 0.3))
            c.put(x, y, s["mark"] if rng.n() < 0.6 else s["mark2"])
    elif pat == "light_spots":
        for x in range(x0 + 4, x1, 2):
            h = prof[x]
            c.put(x, int(cy - h * 0.4), s["mark"])
            if x % 4 == 0:
                c.put(x + 1, int(cy + h * 0.2), s["mark"])
    elif pat == "scales":
        for x in range(x0 + 4, x1):
            h = prof[x]
            for yy in range(int(cy - h + 1), int(cy + h * 0.2)):
                if (x + yy) % 3 == 0:
                    c.put(x, yy, s["mark"])
    elif pat == "scutes":
        for x in range(x0 + 4, x1 + 1, 3):
            c.put(x, int(cy - prof[x]), s["mark"])
            c.put(x + 1, cy, s["mark"])

    # branhia, ochiul, mustatile
    gx = x0 + (4 if half > 3 else 3)
    gill = mix(back[1], belly, 0.35)
    for yy in range(int(cy - prof[gx] * 0.35), int(cy + prof[gx] * 0.45) + 1):
        c.put(gx, yy, gill)
    c.put(gx + 1, int(cy + prof[gx] * 0.4), fin)
    ex, ey = x0 + (2 if half > 2.5 else 1), int(round(cy - prof[x0 + 2] * 0.35))
    if s.get("small_eye") or half <= 2.5:
        c.put(ex, ey, INK)
    else:
        c.put(ex, ey, s.get("eye", hsv(40, 0.05, 0.98)))
        c.put(ex + 1, ey, INK)
    if s.get("bill"):
        c.rect(x0 - 1, cy, 2, 1, back[2])
    if s.get("barbels"):
        c.put(x0, cy + 2, fin)
        c.put(x0 - 1, cy + 3, fin)
    outline_trace(c)
    if s.get("whiskers"):
        line(c, x0 - 1, cy, x0 - 4, cy - 3, STONE[3])
        line(c, x0 - 1, cy + 1, x0 - 4, cy + 4, STONE[3])
    if s.get("sparkle"):
        for sx, sy in ((6, 5), (12, 7)):
            c.put(sx, sy, hsv(50, 0.05, 1.0))
        c.put(17, 2, hsv(50, 0.10, 1.0))
        c.put(16, 2, GOLD_HI[4])
        c.put(18, 2, GOLD_HI[4])
        c.put(17, 1, GOLD_HI[4])
        c.put(17, 3, GOLD_HI[4])
    return c


# --------------------------------------------------------------- ce aduce raul
def rot_fill(c, cx, cy, length, width, ang, color_at):
    """Un dreptunghi rotit, colorat pe coordonatele lui locale (u de-a lungul, v de-a latul, ambele in [0, 1])."""
    ca, sa = math.cos(ang), math.sin(ang)
    r = int(math.hypot(length, width) / 2) + 2
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            dx, dy = x - cx, y - cy
            u = dx * ca + dy * sa
            v = -dx * sa + dy * ca
            if abs(u) <= length / 2 and abs(v) <= width / 2:
                col = color_at(u / length + 0.5, v / width + 0.5)
                if col is not None:
                    c.put(x, y, col)


def treasure_bottle():
    """Sticla culcata in diagonala, cu dopul spre dreapta-sus si biletul rulat inauntru."""
    c = C(16, 16)
    ang = -0.62

    def body(u, v):
        if u > 0.80:  # gatul, mai ingust
            if abs(v - 0.5) > 0.24:
                return None
            return WOOD[3] if u > 0.90 else GLASS[2]
        if abs(v - 0.5) > 0.5:
            return None
        base = lit(GLASS, 0.25 + (1 - v) * 0.7)
        if 0.22 < u < 0.66 and 0.30 < v < 0.72:  # biletul
            return PARCH if (int(u * 20) % 3) else PARCH_D
        if v < 0.2:
            return mix(base, (240, 250, 245, 255), 0.45)  # luciul sticlei
        return base

    rot_fill(c, 7.5, 8.5, 14, 6.4, ang, body)
    outline_trace(c)
    return c


def treasure_chest():
    """Cufarul, din fata si putin de sus: capac boltit, doua benzi de fier, broasca de alama."""
    c = C(20, 16)
    for y in range(7, 15):  # trupul
        c.rect(2, y, 16, 1, WOOD[2] if (y - 7) % 3 else WOOD[1])
    c.rect(2, 7, 16, 1, WOOD[3])
    c.rect(17, 7, 1, 8, WOOD[0])
    for y in range(2, 7):  # capacul boltit
        inset = max(0, 2 - y) if y < 4 else 0
        w = 16 - 2 * (1 if y == 2 else 0)
        x = 2 + (1 if y == 2 else 0)
        c.rect(x + inset, y, w - 2 * inset, 1, WOOD[3] if y < 4 else WOOD[2])
    c.rect(3, 2, 14, 1, WOOD[4])
    c.rect(2, 6, 16, 1, WOOD[0])
    for bx in (5, 14):  # benzile de fier
        c.rect(bx, 2, 2, 13, STEEL[1])
        c.rect(bx, 2, 1, 13, STEEL[2])
    c.rect(8, 6, 4, 4, BRASS[3])  # broasca
    c.rect(8, 6, 4, 1, BRASS[4])
    c.rect(9, 8, 2, 1, INK)
    c.put(15, 3, hsv(50, 0.05, 1.0))  # luciu pe fier
    c.put(4, 12, WATER[4])  # stropi: a stat in rau
    c.put(12, 13, WATER[4])
    outline_trace(c)
    return c


def treasure_golden():
    """Golden Driftwood: bustean de lemn plutitor, auriu. Drept, cu fibra lemnului pe lungime, inelele pe capatul taiat
    si un ciot subtire de creanga -- varianta arcuita, groasa la un capat, se citea ca un pantof de aur."""
    c = C(24, 12)
    for x in range(3, 22):
        for y in range(4, 10):
            v = (y - 4) / 5
            col = lit(GOLD, 0.95 - v * 0.8)
            c.put(x, y, col)
    for y, x0, x1 in ((5, 5, 12), (7, 9, 19), (8, 4, 9), (6, 14, 20)):  # fibra
        c.rect(x0, y, x1 - x0, 1, GOLD[1])
    c.rect(4, 4, 16, 1, GOLD_HI[4])
    line(c, 13, 4, 16, 1, GOLD[2])  # ciotul crengii, subtire
    c.put(16, 1, GOLD_HI[3])
    c.ellipse(3, 6.5, 1.8, 3.1, GOLD[2])  # capatul taiat, cu inelele lui
    c.ellipse(3, 6.5, 0.9, 1.7, GOLD_HI[3])
    c.put(3, 6, GOLD[1])
    c.ellipse(21.5, 6.5, 1.3, 3.0, GOLD[1])
    outline_trace(c)
    for sx, sy in ((6, 1), (17, 2), (21, 10)):  # scanteile, peste contur
        c.put(sx, sy, hsv(50, 0.05, 1.0))
        for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.put(sx + ddx, sy + ddy, GOLD_HI[3])
    return c


def in_water(src, waterline):
    """Varianta care pluteste: sub linia apei obiectul se vede prin apa (atenuat spre albastru), iar pe linie e spuma --
    obiectul sta IN rau, nu lipit peste el."""
    c = C(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            p = src.px[y][x]
            if not p[3]:
                continue
            if y >= waterline:
                depth = min(1.0, (y - waterline + 1) / 4)
                q = mix(p, WATER[1], 0.35 + 0.35 * depth)
                c.put(x, y, (q[0], q[1], q[2], int(p[3] * (0.85 - 0.35 * depth))))
            else:
                c.put(x, y, p)
    for x in range(src.w):
        if any(src.px[y][x][3] for y in range(max(0, waterline - 1), min(src.h, waterline + 2))):
            c.put(x, waterline, FOAM[3] if x % 3 else FOAM[4])
    for x in range(0, src.w):  # freamatul din jur, mai lat decat obiectul
        if x % 4 == 1:
            c.put(x, min(src.h - 1, waterline + 2), (FOAM[2][0], FOAM[2][1], FOAM[2][2], 120))
    return c


# --------------------------------------------------------------- roata zilnica: timonierul
def ship_wheel(c, cx, cy, r_in, r_out, r_knob, r_hub, knob, thick=2):
    """Roata de carma: spitele trec prin obada si se termina in manere; obada e mai deschisa sus-stanga."""
    for k in range(8):
        a = k * math.pi / 4 - math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        r = r_hub
        while r <= r_knob:
            x, y = cx + ca * r, cy + sa * r
            c.rect(round(x - thick / 2 + 0.5), round(y - thick / 2 + 0.5), thick, thick, WOOD[1])
            r += 0.5
        kx, ky = cx + ca * r_knob, cy + sa * r_knob
        c.ellipse(kx, ky, knob, knob, WOOD[2])
        c.put(round(kx - 0.5), round(ky - 0.5), WOOD[4])
    for y in range(int(cy - r_out - 1), int(cy + r_out + 2)):
        for x in range(int(cx - r_out - 1), int(cx + r_out + 2)):
            d = math.hypot(x - cx, y - cy)
            if r_in <= d <= r_out:
                light = (-(x - cx) - (y - cy)) / (2 * r_out) + 0.5
                c.put(x, y, lit(WOOD, 0.15 + light * 0.8))
    c.ellipse(cx, cy, r_hub, r_hub, BRASS[2])
    c.ellipse(cx - r_hub * 0.25, cy - r_hub * 0.25, r_hub * 0.55, r_hub * 0.55, BRASS[3])
    c.put(round(cx - r_hub * 0.4), round(cy - r_hub * 0.4), GOLD_HI[4])


def prop_helm():
    """Roata zilnica in lume: timonier de lemn pe un stalp, pe puntea de langa ponton. Inlocuieste roata de cazino cu
    felii curcubeu (prop_wheel), care nu era din lumea asta."""
    c = C(40, 48)
    soft_shadow(c, 20, 45, 12, 3)
    c.rect(11, 42, 18, 4, WEATHERED[1])  # talpa
    c.rect(11, 42, 18, 1, WEATHERED[3])
    c.rect(18, 20, 4, 23, WOOD[1])  # stalpul
    c.rect(18, 20, 1, 23, WOOD[3])
    c.rect(21, 20, 1, 23, WOOD[0])
    c.rect(16, 38, 8, 2, BRASS[2])  # inelul de alama de pe stalp
    ship_wheel(c, 20, 15, 8.4, 11.4, 14.2, 2.8, 1.7)
    outline_trace(c)
    return c


def ui_helm():
    """Fata roatii din panou: timonierul mare, cu interiorul deschis la culoare -- intre spite codul pune iconitele
    premiilor. Spitele stau la multipli de 45 de grade, una chiar sus, sub ac: pe mijlocul unei felii nu e spita."""
    c = C(64, 64)
    cx = cy = 31.5
    c.ellipse(cx, cy, 21.5, 21.5, PLANK[3])  # discul interior, lemn deschis
    for y in range(64):
        for x in range(64):
            d = math.hypot(x - cx, y - cy)
            if d <= 21.5 and int(d) % 5 == 0:
                c.put(x, y, PLANK[2])  # inelele lemnului
    ship_wheel(c, cx, cy, 21, 26, 29.5, 5.5, 2.4, thick=2)
    outline_trace(c)
    return c


# --------------------------------------------------------------- avizierul satului
def prop_village_board():
    c = C(40, 44)
    soft_shadow(c, 20, 41, 16, 3)
    for px in (6, 31):  # stalpii
        c.rect(px, 9, 3, 32, WOOD[1])
        c.rect(px, 9, 1, 32, WOOD[3])
    for i in range(7):  # acoperisul mic, in doua ape
        c.rect(3 + i, 8 - i, 34 - 2 * i, 1, SHINGLE[2] if i % 2 else SHINGLE[1])
    c.rect(2, 8, 36, 2, SHINGLE[0])
    c.rect(4, 11, 32, 21, WOOD[1])  # tabla
    c.rect(5, 12, 30, 19, PLANK[2])
    for y in range(14, 31, 4):
        c.rect(5, y, 30, 1, PLANK[1])
    notes = ((7, 14, 9, 7, AWNING[3]), (18, 13, 8, 9, GOLD[3]), (27, 15, 7, 6, ramp(210, 0.52, 0.70)[3]), (9, 23, 10, 6, AWNING[3]))
    for nx, ny, nw, nh, pin in notes:
        c.rect(nx, ny, nw, nh, PARCH)
        c.rect(nx, ny + nh - 1, nw, 1, PARCH_D)
        for k in range(1, nh - 2, 2):
            c.rect(nx + 1, ny + k + 1, nw - 3, 1, mix(PARCH, INK, 0.45))
        c.put(nx + nw // 2, ny, pin)
    c.ellipse(24, 26, 2.6, 2.6, PEARL[2])  # perla desenata pe un bilet: aici se platesc perle
    c.ellipse(23.4, 25.4, 1.2, 1.2, PEARL[4])
    outline_bottom(c, 0, 0, 40, 43)
    return c


# --------------------------------------------------------------- pictograme
def ic(draw, size=16):
    c = C(size, size)
    draw(c)
    outline_trace(c)
    return c


def _bait(c):
    """Momeala aurie: lingurita de pescuit, cu inelul sus si carligul jos."""
    c.ellipse(8, 3, 1.6, 1.6, STEEL[3])
    c.px[3][8] = T
    c.ellipse(8, 8.4, 3.4, 4.2, GOLD[2])
    c.ellipse(7.3, 7.6, 2.2, 2.8, GOLD[3])
    c.ellipse(6.8, 6.8, 0.9, 1.3, GOLD_HI[4])
    c.rect(8, 12, 1, 3, STEEL[2])
    c.rect(9, 14, 2, 1, STEEL[2])
    c.put(10, 13, STEEL[3])


def _note(c):
    """Biletul din sticla: sul de hartie cu panglica rosie."""
    c.rect(3, 5, 10, 7, PARCH)
    c.rect(3, 5, 10, 1, hsv(44, 0.10, 0.99))
    for k in (7, 9):
        c.rect(5, k, 6, 1, mix(PARCH, INK, 0.45))
    c.rect(1, 4, 3, 9, PARCH_D)
    c.rect(12, 4, 3, 9, PARCH_D)
    c.rect(2, 4, 1, 9, PARCH)
    c.rect(7, 4, 2, 9, AWNING[3])


def _spin(c):
    """Roata din bara de meniu: timonierul, mic."""
    ship_wheel(c, 7.5, 7.5, 3.6, 5.2, 6.6, 1.6, 1.0, thick=1)


# --------------------------------------------------------------- decorul satului (VillageConfig.DECOR)
def decor_flowerbed():
    """Straturi de flori in fata caselor: rama joasa de lemn, pamant, flori de trei culori."""
    c = C(32, 14)
    soft_shadow(c, 16, 12, 14, 2)
    c.rect(1, 7, 30, 6, WOOD[1])
    c.rect(1, 7, 30, 1, WOOD[3])
    c.rect(2, 8, 28, 3, DIRT[1])
    rng = Rng(5901)
    for i, x in enumerate(range(4, 29, 4)):
        top = 2 + rng.i(0, 2)
        c.rect(x, top + 2, 1, 7 - top, LEAF[2])
        c.put(x + 1, top + 4, LEAF[3])
        petal = (hsv(50, 0.62, 0.97), hsv(340, 0.45, 0.95), hsv(275, 0.34, 0.93))[i % 3]
        c.rect(x - 1, top, 3, 3, petal)
        c.put(x, top + 1, hsv(48, 0.30, 1.0))
    outline_bottom(c, 0, 0, 32, 13)
    return c


def decor_pier_lamp():
    """Felinar pe ponton: stalp de lemn decolorat, brat, felinarul atarnat cu lumina calda."""
    c = C(12, 32)
    c.rect(3, 29, 6, 2, WEATHERED[1])
    c.rect(4, 5, 2, 25, WEATHERED[2])
    c.rect(4, 5, 1, 25, WEATHERED[3])
    c.rect(4, 5, 6, 1, WEATHERED[1])
    c.rect(8, 6, 1, 2, STEEL[1])
    c.rect(6, 8, 5, 7, STEEL[0])
    c.rect(7, 9, 3, 5, WARM[3])
    c.put(7, 9, WARM[4])
    c.rect(6, 8, 5, 1, STEEL[2])
    outline_trace(c)
    return c


def decor_bench():
    """Banca, vazuta de sus si din fata: sezutul adanc, luminat (altfel banca se citea gard), spatarul scund in spate,
    picioarele sub muchia din fata."""
    c = C(32, 20)
    soft_shadow(c, 16, 18, 14, 2)
    for px in (4, 26):  # stalpii spatarului
        c.rect(px, 2, 2, 9, WOOD[1])
    c.rect(3, 3, 26, 2, WOOD[2])  # spatarul
    c.rect(3, 3, 26, 1, WOOD[3])
    for y, tone in ((8, WOOD[3]), (10, WOOD[4]), (12, WOOD[3])):  # sezutul, trei scanduri
        c.rect(2, y, 28, 2, tone)
        c.rect(2, y + 1, 28, 1, mix(tone, WOOD[2], 0.5))
    c.rect(2, 14, 28, 1, WOOD[0])  # muchia din fata, in umbra
    for px in (4, 26):
        c.rect(px, 15, 2, 4, WOOD[1])
    for ax in (1, 29):  # bratele
        c.rect(ax, 6, 2, 8, WOOD[2])
        c.rect(ax, 6, 2, 1, WOOD[4])
    outline_bottom(c, 0, 0, 32, 19)
    return c


def decor_bunting():
    """Ghirlanda de steaguri peste strada: doi stalpi subtiri, franghia lasata, steaguri in patru culori."""
    c = C(64, 24)
    for px in (1, 61):
        soft_shadow(c, px + 1, 22, 3, 1)
        c.rect(px, 1, 2, 21, WOOD[1])
        c.rect(px, 1, 1, 21, WOOD[3])
    prev = None
    for x in range(3, 61):
        t = (x - 3) / 58
        y = 3 + int(round(5 * math.sin(math.pi * t)))
        c.put(x, y, ROPE[1])
        if prev is not None and abs(prev - y) > 1:
            c.put(x, (prev + y) // 2, ROPE[1])
        prev = y
    for i, x in enumerate(range(6, 58, 7)):
        t = (x + 2 - 3) / 58
        y = 4 + int(round(5 * math.sin(math.pi * t)))
        col = FLAG_COLORS[i % len(FLAG_COLORS)]
        for k in range(5):
            w = 5 - k
            c.rect(x + k // 2, y + k, max(1, w - k // 2), 1, col)
        c.put(x, y, mix(col, (255, 255, 255, 255), 0.35))
    outline_bottom(c, 0, 0, 64, 23)
    return c


def decor_well():
    """Put de piatra cu acoperis, manivela si galeata."""
    c = C(32, 40)
    soft_shadow(c, 16, 37, 14, 3)
    c.rect(4, 26, 24, 10, STONE[1])  # fata zidului
    for y in (29, 32):
        c.rect(4, y, 24, 1, STONE[0])
    for i, x in enumerate(range(6, 27, 5)):
        c.rect(x + (2 if i % 2 else 0), 26, 1, 3, STONE[0])
        c.rect(x, 30, 1, 2, STONE[0])
    c.ellipse(16, 26, 12, 3.4, STONE[3])  # buza
    c.ellipse(16, 26, 9, 2.2, WATER_DEEP[0])
    c.ellipse(14, 25.6, 3, 0.8, WATER_DEEP[2])
    for px in (5, 25):  # stalpii
        c.rect(px, 8, 2, 19, WOOD[1])
        c.rect(px, 8, 1, 19, WOOD[3])
    for i in range(7):  # acoperisul
        c.rect(1 + i, 8 - i, 30 - 2 * i, 1, SHINGLE[2] if i % 2 else SHINGLE[1])
    c.rect(0, 8, 32, 2, SHINGLE[0])
    c.rect(7, 13, 18, 2, WOOD[2])  # osia
    c.rect(24, 12, 2, 5, WOOD[1])  # manivela
    c.rect(26, 16, 2, 1, WOOD[3])
    c.rect(15, 15, 1, 5, ROPE[1])
    c.rect(13, 20, 5, 4, WOOD[2])  # galeata
    c.rect(13, 21, 5, 1, STEEL[2])
    outline_bottom(c, 0, 0, 32, 39)
    return c


def decor_veggie_patch():
    """Gradina cu sperietoare: brazde, varze si morcovi, sperietoarea in spate cu palarie de paie."""
    c = C(48, 40)
    soft_shadow(c, 24, 37, 22, 3)
    c.rect(2, 22, 44, 15, DIRT[1])
    c.rect(2, 22, 44, 1, DIRT[2])
    for y in range(25, 37, 4):
        c.rect(3, y, 42, 1, DIRT[0])
    rng = Rng(5906)
    for row, y in enumerate(range(24, 36, 4)):
        for x in range(6, 44, 6):
            if row % 2 == 0:
                c.ellipse(x, y, 2.2, 1.4, LEAF[2])
                c.put(x - 1, y - 1, LEAF[3])
            else:
                c.rect(x, y - 2, 1, 2, LEAF_WARM[2])
                c.put(x - 1, y - 2, LEAF_WARM[3])
                c.put(x + 1, y - 2, LEAF_WARM[1])
                c.put(x, y, hsv(24, 0.80, 0.90))
    c.rect(12, 8, 2, 22, WOOD[1])  # sperietoarea
    c.rect(4, 12, 18, 2, WOOD[2])
    c.rect(9, 11, 8, 8, AWNING[2])
    c.rect(10, 13, 3, 3, ramp(210, 0.40, 0.60)[2])  # petic
    c.ellipse(13, 7, 2.6, 2.6, BURLAP[3])
    c.put(12, 7, INK)
    c.put(14, 7, INK)
    c.rect(8, 3, 11, 2, THATCH[3])
    c.rect(10, 1, 7, 2, THATCH[2])
    for sx in (3, 22):
        c.rect(sx, 11, 2, 3, THATCH[3])
    outline_bottom(c, 0, 0, 48, 39)
    return c


def decor_rowboat():
    """Barca legata la ponton, vopsita albastru si alb -- barca vanzarii e lemn gol, ca sa nu le confunzi."""
    c = C(40, 20)
    c.ellipse(20, 16, 18, 3, (WATER[1][0], WATER[1][1], WATER[1][2], 120))
    c.rect(6, 3, 28, 5, mix(WOOD[0], OUTLINE, 0.4))  # interiorul, vazut de sus
    c.rect(17, 3, 6, 5, WOOD[2])  # banca
    c.rect(17, 3, 6, 1, WOOD[3])
    line(c, 7, 6, 30, 4, WOOD[3])  # vaslele, culcate in barca
    line(c, 8, 4, 31, 6, WOOD[2])
    c.rect(2, 2, 36, 2, BLUE_PAINT[3])  # bordul
    c.rect(2, 2, 36, 1, BLUE_PAINT[4])
    for i in range(8):  # coca, in doua culori, ingustata spre linia apei
        inset = int(i * 1.5)
        col = BLUE_PAINT[2] if i < 3 else (CREAM[2] if i < 5 else BLUE_PAINT[1])
        c.rect(2 + inset, 8 + i, 36 - inset * 2, 1, col)
    c.rect(2, 4, 4, 4, BLUE_PAINT[2])  # prova si pupa
    c.rect(34, 4, 4, 4, BLUE_PAINT[2])
    for fx in (4, 11, 20, 29, 35):
        c.put(fx, 16, FOAM[3])
    outline_trace(c)
    return c


def decor_beehives():
    c = C(40, 28)
    soft_shadow(c, 20, 26, 18, 2)
    c.rect(3, 20, 34, 3, WOOD[2])
    c.rect(3, 20, 34, 1, WOOD[3])
    for lx in (5, 34):
        c.rect(lx, 23, 2, 4, WOOD[1])
    straw = ramp(40, 0.52, 0.78)  # paiele stupului: galben-auriu, nu verdele acoperisurilor de paie
    for hx in (12, 28):
        for y in range(7, 20):
            t = (y - 7) / 13
            half = 1.5 + 5.6 * math.sin(math.pi * 0.5 * min(1.0, t * 1.6))
            col = straw[3] if (y % 2 == 0) else straw[2]
            c.rect(round(hx - half), y, round(half * 2), 1, col)
            c.put(round(hx - half), y, straw[4] if y % 2 == 0 else straw[3])
            c.put(round(hx + half) - 1, y, straw[1])
        c.rect(hx - 1, 17, 3, 2, INK)
    for bx, by in ((20, 6), (24, 3), (33, 7), (7, 5)):
        c.put(bx, by, GOLD[3])
        c.put(bx + 1, by, INK)
    for fx in (2, 19, 37):
        c.rect(fx, 24, 2, 2, hsv(340, 0.45, 0.95))
    outline_bottom(c, 0, 0, 40, 27)
    return c


def decor_fountain():
    """Fantana arteziana: bazin rotund de piatra cu apa, stalp cu un bol si jetul care cade in picaturi."""
    c = C(48, 40)
    soft_shadow(c, 24, 37, 22, 3)
    c.rect(3, 29, 42, 7, STONE[1])  # fata bazinului
    c.rect(3, 29, 42, 1, STONE[2])
    for x in range(7, 44, 8):
        c.rect(x, 30, 1, 6, STONE[0])
    c.ellipse(24, 29, 21.5, 5.5, STONE[3])  # buza
    c.ellipse(24, 29, 18, 4, WATER[2])
    c.ellipse(19, 28, 6, 1.4, WATER[3])
    c.rect(21, 13, 6, 16, STONE[2])  # stalpul
    c.rect(21, 13, 2, 16, STONE[3])
    c.ellipse(24, 13, 7.5, 2.4, STONE[3])
    c.ellipse(24, 12.6, 5.5, 1.4, WATER[3])
    c.rect(23, 3, 2, 10, FOAM[3])  # jetul
    c.put(23, 2, FOAM[4])
    for side in (-1, 1):
        for k in range(10):
            x = 24 + side * (2 + k * 1.3)
            y = 4 + (k * k) * 0.24
            c.put(round(x), round(y), FOAM[3] if k % 2 == 0 else FOAM[4])
    for fx in (14, 30, 36):
        c.put(fx, 29, FOAM[4])
    outline_bottom(c, 0, 0, 48, 39)
    return c


def decor_statue():
    """Statuia raului: pazitorul pontonului ridicand un peste mare, pe un soclu cu placa de alama si putin muschi."""
    c = C(32, 56)
    soft_shadow(c, 16, 54, 13, 2)
    c.rect(7, 40, 18, 14, STONE[1])  # soclul
    c.rect(7, 40, 2, 14, STONE[2])
    c.rect(5, 38, 22, 3, STONE[3])
    c.rect(5, 38, 22, 1, hsv(220, 0.06, 0.82))
    c.rect(11, 45, 10, 5, BRASS[3])
    c.rect(12, 47, 8, 1, BRASS[1])
    stone = ramp(215, 0.08, 0.68)
    c.rect(13, 29, 3, 9, stone[1])  # picioarele
    c.rect(17, 29, 3, 9, stone[1])
    c.rect(12, 17, 9, 13, stone[2])  # haina
    c.rect(12, 17, 3, 13, stone[3])
    c.ellipse(16, 13, 3, 3, stone[3])  # capul
    c.rect(11, 9, 10, 2, stone[1])  # palaria
    c.rect(13, 7, 6, 2, stone[2])
    c.rect(9, 8, 2, 10, stone[2])  # bratele ridicate
    c.rect(22, 8, 2, 10, stone[2])
    for x in range(7, 25):  # pestele de piatra, tinut deasupra capului: corp de lacrima, coada in V, ochi
        t = (x - 7) / 17
        h = 2.8 * math.sin(math.pi * (0.08 + 0.84 * t ** 0.75))
        for y in range(round(4.5 - h), round(4.5 + h) + 1):
            c.put(x, y, stone[3] if y < 4.5 else stone[2])
    for k in range(4):
        c.put(25 + k, 3 - k, stone[2])
        c.put(25 + k, 6 + k, stone[2])
    c.rect(25, 3, 1, 4, stone[2])
    c.put(9, 3, INK)
    c.rect(12, 3, 1, 3, stone[1])  # branhia
    for mx, my in ((8, 52), (22, 50), (24, 43), (13, 36)):
        c.put(mx, my, MOSS[2])
    outline_bottom(c, 0, 0, 32, 55)
    return c


SPRITES = {
    "prop_pier_long": prop_pier_long,
    "prop_bobber": prop_bobber,
    "prop_helm": prop_helm,
    "ui_helm": ui_helm,
    "prop_village_board": prop_village_board,
    "icon_bait": lambda: ic(_bait),
    "icon_note": lambda: ic(_note),
    "icon_spin": lambda: ic(_spin),
    "treasure_bottle": treasure_bottle,
    "treasure_chest": treasure_chest,
    "treasure_golden": treasure_golden,
    "treasure_bottle_water": lambda: in_water(treasure_bottle(), 10),
    "treasure_chest_water": lambda: in_water(treasure_chest(), 11),
    "treasure_golden_water": lambda: in_water(treasure_golden(), 8),
    "decor_flowerbed": decor_flowerbed,
    "decor_pier_lamp": decor_pier_lamp,
    "decor_bench": decor_bench,
    "decor_bunting": decor_bunting,
    "decor_well": decor_well,
    "decor_veggie_patch": decor_veggie_patch,
    "decor_rowboat": decor_rowboat,
    "decor_beehives": decor_beehives,
    "decor_fountain": decor_fountain,
    "decor_statue": decor_statue,
}
for _name, _spec in FISH.items():
    SPRITES[f"fish_{_name}"] = (lambda s: (lambda: fish_icon(s)))(_spec)


def main():
    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = only or list(SPRITES)
    for name in names:
        if os.path.exists(os.path.join(OUT, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name in names:
        c = SPRITES[name]()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
