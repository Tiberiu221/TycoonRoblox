#!/usr/bin/env python3
"""Arta pentru D75, lotul A1, grupul "orasul pictat": orasul de pe malul de nord al lumii 2 (barajul).

Orasul e primul cumparator din afara satului tau, dar nu se viziteaza niciodata: sta in departare, dincolo de apa,
privit de la ferestrele Relay Station-ului (docs/PLAN-ERA4.md, liniile 29 si 89). Cu fiecare Pylon vandut i se aprind
ferestrele, una cate una, de la stanga la dreapta. Doua panze IDENTICE ca marime, suprapuse pixel cu pixel, ancorate jos-mijloc
la (2202, 405) in lume, ca in `TycoonConfig.WORLDS[2].paintedTown` (un pixel de arta = 3 pixeli de lume; coltul de sus-stanga
cade pe (564, 91) in prop_dam_ground):

  prop_painted_town       340x44  orasul stins: doua randuri de case mici cu acoperisuri si cosuri, o biserica cu clopotnita
                                  si turla, o primarie cu turnul cu ceas, un castel de apa, copaci intre ele, un chei cu
                                  felinare si un mal de iarba usor, prin care se vede malul copt de dedesubt. Totul e tras spre albastru-cenusiu
                                  (perspectiva atmosferica): cu cat randul e mai in spate, cu atat ceata e mai deasa. Ferestrele
                                  sunt intunecate. Castelul de apa are un cadru deschis (picioare, o bara, cate un X pe travee), iar
                                  prin el se vede padurea.
  prop_painted_town_lit   340x44  DOAR luminile, transparent in rest: gemurile calde ale ferestrelor (aceleasi dreptunghiuri
                                  ca in panza de baza, pixel cu pixel), felinarele cheiului, cadranul ceasului, baliza rosie din
                                  varful castelului de apa si cate un halou moale cu alfa in jurul fiecaruia. Jocul il
                                  descopera treptat, de la stanga la dreapta, pe masura ce vinzi curent.

Ambele ies din acelasi apel de desen (`build()`): ferestrele si felinarele se noteaza o singura data, cand se deseneaza casele,
iar panza luminata se scrie din lista aceea, deci nu au cum sa nu se suprapuna.

Lumina vine de sus-stanga. Culorile, din palette.ramp(); conturul se traseaza automat pe fiecare piesa, in culoarea ei
vazuta prin ceata (niciodata negru pur). Nu atinge assets/sprites: scrie doar in --out.

Rulare: python3 scripts/art/a1_painted.py [--out DIR]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import GRASS, LEAF, LEAF_WARM, OUTLINE, SAND, WOOD, mix, ramp  # noqa: E402
from tycoon_e1 import outline_trace  # noqa: E402
from world import soft_shadow  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a1")
GROUND_PNG = os.path.join(scratch.SPRITES, "prop_dam_ground.png")

W, H = 340, 44  # panza finala (px de arta; 1 px = 3 px de lume)
ANCHOR = (2202, 405)  # jos-mijloc, in coordonate de lume (la fel ca TycoonConfig.WORLDS[2].paintedTown)
PAD = 3  # marginea unei piese (loc pentru contur si streasina)
BL = 37  # randul de baza in panza unei piese
PH = 40  # inaltimea panzei unei piese

# ceata de departare: tot ce se vede prin ea se amesteca cu aceasta culoare, cu atat mai mult cu cat e mai in spate
HAZE = (152, 174, 200, 255)
F_BACK, F_MID, F_FRONT = 0.54, 0.47, 0.42
GRASS_ALPHA = 150  # iarba orasului lasa sa se vada malul copt; doar drumul de nisip e opac


def hz(col, f):
    return mix(col, HAZE, f)


def hzr(tones, f):
    return [hz(c, f) for c in tones]


# ---------------------------------------------------------------------------------------------
# materiale: tencuieli deschise si acoperisuri colorate, ca intr-o panza pictata; ceata le aduce impreuna

WALLS = [
    ramp(42, 0.26, 0.84),  # crem
    ramp(30, 0.36, 0.80),  # piersica
    ramp(14, 0.30, 0.78),  # roz-teracota palid
    ramp(58, 0.22, 0.80),  # salvie-crem
    ramp(205, 0.12, 0.86),  # alb albastrui
    ramp(36, 0.44, 0.74),  # ocru
]
ROOFS = [
    ramp(12, 0.60, 0.60),  # tigla
    ramp(214, 0.24, 0.52),  # ardezie
    ramp(22, 0.48, 0.50),  # maro
    ramp(168, 0.32, 0.56),  # verde-patina
    ramp(6, 0.52, 0.52),  # caramiziu
    ramp(40, 0.44, 0.68),  # paie
]
BRICK_R = ramp(12, 0.52, 0.52)
STONE_R = ramp(46, 0.14, 0.84)  # piatra calda a bisericii
SLATE = ramp(214, 0.24, 0.50)
METAL = ramp(205, 0.16, 0.64)  # castelul de apa
WIN_DARK = (44, 58, 90, 255)
WIN_GLINT = (92, 116, 152, 255)
CLOCK_FACE = (236, 230, 206, 255)
CLOCK_HAND = (60, 52, 56, 255)
BEACON_RAW = (120, 70, 62, 255)  # capul stins al balizei din varful castelului de apa
LAMP_CAP_RAW = (220, 204, 150, 255)  # capacul felinarelor de chei (singurul crem; sticla stinsa are culoarea ferestrelor)


class Piece:
    """O piesa desenata pe panza ei (case, copaci, turnuri), cu contur propriu; ferestrele ei se tin in coordonate locale."""

    def __init__(self, w, f):
        self.c = C(w + 2 * PAD, PH)
        self.f = f
        self.wins = []
        self.unders = []  # peretele de dedesubt al fiecarei ferestre: [(x, y, culoare)], ca o fereastra acoperita sa poata fi readusa la perete
        self.lamps = []  # felinare in varful pieselor (castelul de apa): (x, y)
        self.clocks = []  # cadrane care se aprind: (x, y, w, h)
        self.chims = []  # varful cosurilor, pentru fum: (x, y)

    def window(self, x, y, w, h):
        self.unders.append([(xx, yy, self.c.px[yy][xx]) for yy in range(y, y + h) for xx in range(x, x + w)])
        self.c.rect(x, y, w, h, hz(WIN_DARK, self.f * 0.55))
        self.c.put(x, y, hz(WIN_GLINT, self.f * 0.55))
        self.wins.append((x, y, w, h, self.f))

    def finish(self):
        outline_trace(self.c, hz(OUTLINE, min(0.8, self.f + 0.14)))
        return self


def roof_rows(w, rh, slope, ox):
    """Intinderea fiecarui rand de acoperis, de sus in jos: [(x0, x1)) cu x1 exclusiv. Streasina depaseste peretele cu 1 px."""
    full = w + 2
    out = []
    for r in range(rh):
        k = rh - 1 - r
        ins = round(slope * k)
        out.append((ox - 1 + ins, ox - 1 + full - ins))
    return out


def fill_roof(t, rows, y0, ox, w, Rf, texture=True):
    """Umple acoperisul: jumatatea din stanga in lumina, cea din dreapta in umbra, randuri alternante ca tigla,
    muchia stanga luminata, streasina intunecata."""
    mid = ox + w / 2.0
    for r, (x0, x1) in enumerate(rows):
        y = y0 + r
        alt = texture and r % 2 == 1
        for x in range(x0, x1):
            if x < mid:
                tone = Rf[2] if alt else Rf[3]
            else:
                tone = Rf[1] if alt else Rf[2]
            t.put(x, y, tone)
        t.put(x0, y, Rf[4])  # muchia stanga prinde lumina
        t.put(x1 - 1, y, Rf[0])
    xl, xr = rows[-1]
    t.rect(xl, y0 + len(rows) - 1, xr - xl, 1, Rf[1])  # streasina
    t.put(xl, y0 + len(rows) - 1, Rf[2])


def chimney(t, rows, y0, ox, w, frac, f, extra=0):
    """Un cos pe panta acoperisului (2 px lat), cu varful mai deschis. Se pune pe randul in care panta ii cuprinde coloanele."""
    cx = ox + int(w * frac)
    for r, (x0, x1) in enumerate(rows):
        if x0 <= cx and cx + 2 <= x1:
            edge = y0 + r
            break
    else:
        return None
    B = hzr(BRICK_R, f)
    top = edge - 3 - extra
    t.rect(cx, top, 2, 4 + extra, B[2])
    t.put(cx, top, B[3])
    t.put(cx + 1, top, B[1])
    t.rect(cx - 0, top, 1, 4 + extra, B[3])
    t.rect(cx + 1, top + 1, 1, 3 + extra, B[1])
    t.rect(cx, top - 1, 2, 1, B[0])  # gura
    return (cx, top - 1)


def house(w, wh, rh, wall, roof, f, kind="hip", slope=1.0, floors=1, chim=0.66, door=True):
    """Casa: perete cu ferestre si usa, acoperis `hip` (trapez), `gable` (triunghi) sau `gablewall` (fronton cu tencuiala vazuta).
    `chim` = pozitia cosului pe acoperis (0..1), sau None pentru o casa fara cos."""
    p = Piece(w, f)
    t, ox, base = p.c, PAD, BL
    Wl, Rf = hzr(wall, f), hzr(roof, f)
    top = base - wh
    t.rect(ox, top, w, wh, Wl[2])
    t.rect(ox, top, 1, wh, Wl[3])
    t.rect(ox + w - 1, top, 1, wh, Wl[1])
    t.rect(ox, base - 1, w, 1, Wl[1])
    full = w + 2
    if kind == "hip":
        max_rh = int((full - 4) / (2.0 * slope)) + 1
        rh = max(2, min(rh, max_rh))
    else:
        rh = int((full - 2) / (2.0 * slope)) + 1
    rows = roof_rows(w, rh, slope, ox)
    y0 = top - rh
    if kind == "gablewall":
        # fronton: tencuiala in triunghi, cu doua scanduri de acoperis pe margini
        mid = ox + w / 2.0
        for r, (x0, x1) in enumerate(rows):
            y = y0 + r
            for x in range(x0 + 1, x1 - 1):
                t.put(x, y, Wl[3] if x < mid else Wl[2])
            t.put(x0, y, Rf[3])
            t.put(x1 - 1, y, Rf[1])
            if r + 1 < len(rows):  # scandura de sub streasina e mai groasa
                t.put(x0 + 1, y, Rf[3])
                t.put(x1 - 2, y, Rf[1])
        xl, xr = rows[-1]
        t.rect(xl, y0 + rh - 1, xr - xl, 1, Rf[1])
        if rh >= 6:  # fereastra de pod, in fronton
            p.window(ox + w // 2 - 1, y0 + rh - 4, 2, 2)
    else:
        fill_roof(t, rows, y0, ox, w, Rf)
        ch = chimney(t, rows, y0, ox, w, chim, f, extra=rng_extra(w, wh)) if chim is not None else None
        if ch:
            p.chims.append(ch)
    t.rect(ox, top, w, 1, Wl[1])  # umbra streasinii pe perete
    # ferestre si usa: parter cu usa la mijloc, iar la casele inalte un etaj de ferestre deasupra
    n = max(1, (w - 1) // 4)
    slots = n + (1 if door else 0)
    door_slot = slots // 2 if door else -1
    dh = 4 if wh >= 8 else 3
    for i in range(slots):
        cxs = int(round(ox + w * (i + 0.5) / slots - 1))
        if i == door_slot:
            t.rect(cxs, base - 1 - dh, 2, dh, hz(WOOD[1], f))
            t.put(cxs, base - 1 - dh, hz(WOOD[2], f))
        elif floors == 1:
            p.window(cxs, top + 2, 2, 3 if wh >= 9 else 2)
        else:
            p.window(cxs, base - 1 - dh, 2, 2)
    if floors == 2:
        for i in range(n):
            cxs = int(round(ox + w * (i + 0.5) / n - 1))
            p.window(cxs, top + 2, 2, 2)
    return p.finish()


def rng_extra(w, wh):
    return 1 if (w + wh) % 3 == 0 else 0


def tree_round(r, f, warm=False):
    p = Piece(2 * r + 1, f)
    t = p.c
    L = hzr(LEAF_WARM if warm else LEAF, f + 0.06)
    cx = PAD + r
    trunk = 3
    t.rect(cx, BL - trunk, 1, trunk, hz(WOOD[1], f))
    cy = BL - trunk - r + 2
    t.ellipse(cx, cy, r, r * 0.92, L[1])
    t.ellipse(cx - r * 0.12, cy - r * 0.14, r * 0.82, r * 0.76, L[2])
    t.ellipse(cx - r * 0.34, cy - r * 0.34, r * 0.5, r * 0.44, L[3])
    t.put(int(cx - r * 0.45), int(cy - r * 0.5), L[4])
    t.ellipse(cx + r * 0.4, cy + r * 0.5, r * 0.45, r * 0.3, L[0])
    return p.finish()


def tree_conifer(h, f):
    wmax = max(5, h // 2 + 1)
    p = Piece(wmax + 2, f)
    t = p.c
    L = hzr(ramp(150, 0.40, 0.40, val_span=0.36), f + 0.06)
    cx = PAD + wmax // 2 + 1
    t.rect(cx, BL - 2, 1, 2, hz(WOOD[0], f))
    tiers = 3 if h >= 11 else 2
    tier_h = max(2, h // tiers)
    for r in range(h):
        grow = 1 + (wmax - 3) * r / max(1, h - 1)
        wid = int(round(grow)) + (2 if r % tier_h == tier_h - 1 and r < h - 1 else 0)
        wid = max(1, min(wmax, wid))
        y = BL - 2 - h + r + 1
        x0 = cx - wid // 2
        for x in range(x0, x0 + wid):
            t.put(x, y, L[3] if x < cx else (L[2] if x == cx else L[1]))
        t.put(x0, y, L[4] if wid > 2 else L[3])
        t.put(x0 + wid - 1, y, L[0])
    return p.finish()


def bush(w, f):
    p = Piece(w, f)
    t = p.c
    L = hzr(LEAF, f + 0.05)
    t.ellipse(PAD + w / 2.0, BL - 1, w / 2.0, 2.2, L[1])
    t.ellipse(PAD + w / 2.0 - 0.5, BL - 2, w / 2.0 - 1, 1.6, L[2])
    t.put(PAD + 1, BL - 3, L[3])
    return p.finish()


# ---------------------------------------------------------------------------------------------
# reperele: biserica, primaria cu ceas, castelul de apa


def church(f):
    """Biserica (28x ~35): turnul din stanga cu clopotnita si turla ascutita cu cruce, nava cu trei ferestre inalte si acoperis
    de ardezie. Ferestrele navei si rozeta turnului se aprind."""
    p = Piece(30, f)
    t, ox, base = p.c, PAD, BL
    S, Sl = hzr(STONE_R, f), hzr(SLATE, f)
    nave_x, nave_w, nave_h = ox + 8, 22, 8
    # nava
    t.rect(nave_x, base - nave_h, nave_w, nave_h, S[2])
    t.rect(nave_x + nave_w - 1, base - nave_h, 1, nave_h, S[1])
    t.rect(nave_x, base - 1, nave_w, 1, S[1])
    rows = roof_rows(nave_w, 5, 1.0, nave_x)
    fill_roof(t, rows, base - nave_h - 5, nave_x, nave_w, Sl)
    t.rect(nave_x, base - nave_h, nave_w, 1, S[1])
    for wx in (nave_x + 3, nave_x + 9, nave_x + 15):  # ferestre inalte; fara varf separat, ca sa se aprinda intregi
        p.window(wx, base - 7, 2, 4)
    t.rect(nave_x + 19, base - 4, 2, 3, hz(WOOD[1], f))  # usa
    # turnul
    tw, th = 9, 17
    tx = ox
    t.rect(tx, base - th, tw, th, S[2])
    t.rect(tx, base - th, 1, th, S[3])
    t.rect(tx + tw - 1, base - th, 1, th, S[1])
    t.rect(tx, base - 1, tw, 1, S[1])
    t.rect(tx - 1, base - th + 5, tw + 2, 1, S[1])  # brau sub clopotnita
    t.rect(tx, base - th, tw, 1, S[3])
    p.window(tx + 4, base - th + 7, 2, 3)  # fereastra turnului (se aprinde)
    t.rect(tx + 3, base - th + 2, 3, 3, hz(WIN_DARK, f * 0.5))  # gura clopotnitei
    t.put(tx + 4, base - th + 3, hz(ramp(44, 0.6, 0.74)[2], f * 0.7))  # clopotul
    t.rect(tx + 3, base - 4, 3, 3, hz(WOOD[1], f))  # usa mare
    # turla
    sh = 11
    for r in range(sh):
        wid = int(round(1 + 10 * r / (sh - 1)))
        y = base - th - sh + r
        x0 = tx + 4 - wid // 2
        for x in range(x0, x0 + wid):
            t.put(x, y, Sl[3] if x <= tx + 3 else (Sl[2] if x == tx + 4 else Sl[1]))
        t.put(x0, y, Sl[4])
        t.put(x0 + wid - 1, y, Sl[0])
    ty = base - th - sh
    t.rect(tx + 4, ty - 3, 1, 3, hz(ramp(44, 0.6, 0.74)[2], f * 0.7))  # cruce
    t.rect(tx + 3, ty - 2, 3, 1, hz(ramp(44, 0.6, 0.74)[2], f * 0.7))
    return p.finish()


def hall(f):
    """Primaria (26 lat): corp scund cu acoperis in patru ape, cinci ferestre si usa mare, iar din mijloc un turn cu ceas si
    acoperis ascutit. Ceasul se aprinde odata cu ferestrele."""
    p = Piece(26, f)
    t, ox, base = p.c, PAD, BL
    wl = hzr(ramp(44, 0.30, 0.80), f)
    rf = hzr(ramp(8, 0.52, 0.52), f)
    w, wh, rh = 26, 9, 5
    t.rect(ox, base - wh, w, wh, wl[2])
    t.rect(ox, base - wh, 1, wh, wl[3])
    t.rect(ox + w - 1, base - wh, 1, wh, wl[1])
    t.rect(ox, base - 1, w, 1, wl[1])
    rows = roof_rows(w, rh, 1.0, ox)
    fill_roof(t, rows, base - wh - rh, ox, w, rf)
    t.rect(ox, base - wh, w, 1, wl[1])
    # turnul cu ceas
    tw, tth = 8, 13
    tx = ox + w // 2 - tw // 2
    tb = base - wh - 1
    t.rect(tx, tb - tth, tw, tth + 1, wl[2])
    t.rect(tx, tb - tth, 1, tth + 1, wl[3])
    t.rect(tx + tw - 1, tb - tth, 1, tth + 1, wl[1])
    t.rect(tx - 1, tb - tth, tw + 2, 1, wl[1])
    # cadranul: cerc 5x5
    ccx, ccy = tx + 4, tb - tth + 5
    face = hz(CLOCK_FACE, f * 0.6)
    t.ellipse(ccx, ccy, 2.3, 2.3, face)
    t.put(ccx, ccy - 1, hz(CLOCK_HAND, f))
    t.put(ccx, ccy, hz(CLOCK_HAND, f))
    t.put(ccx + 1, ccy, hz(CLOCK_HAND, f))
    p.clocks.append((ccx, ccy))  # cadranul se aprinde odata cu ferestrele
    # acoperisul turnului: ascutit
    pr = 7
    for r in range(pr):
        wid = int(round(2 + (tw + 2) * r / (pr - 1)))
        y = tb - tth - pr + r + 1
        x0 = tx + 4 - wid // 2
        for x in range(x0, x0 + wid):
            t.put(x, y, rf[3] if x < tx + 4 else rf[2])
        t.put(x0, y, rf[4])
        t.put(x0 + wid - 1, y, rf[0])
    t.rect(tx + 3, tb - tth - pr - 2, 1, 3, hz(ramp(44, 0.6, 0.74)[3], f * 0.7))  # varf
    # ferestre si usa
    for wx in (ox + 2, ox + 6, ox + 17, ox + 21):
        p.window(wx, base - wh + 2, 2, 3)
    t.rect(ox + 11, base - 5, 4, 4, hz(WOOD[1], f))
    t.rect(ox + 11, base - 5, 4, 1, hz(WOOD[2], f))
    t.rect(ox + 10, base - 1, 6, 1, wl[0])  # treapta
    return p.finish()


def water_tower(f):
    """Castelul de apa (15 lat): rezervor cilindric cu acoperis conic pe un cadru deschis (doua picioare departate, unul in
    mijloc, o bara si cate un X pe travee), cu o baliza rosie-calda in varf. Cadrul se deseneaza DUPA contur, ca golurile de
    1 px dintre bare sa nu se umple cu contur: prin el se vede padurea."""
    p = Piece(15, f)
    t, ox, base = p.c, PAD, BL
    M = hzr(METAL, f)
    leg_h = 13
    tank_b = base - leg_h
    tank_h = 9
    # rezervorul
    t.rect(ox, tank_b - tank_h, 15, tank_h, M[2])
    t.rect(ox, tank_b - tank_h, 2, tank_h, M[3])
    t.rect(ox + 13, tank_b - tank_h, 2, tank_h, M[1])
    t.rect(ox + 14, tank_b - tank_h, 1, tank_h, M[0])
    for by in (tank_b - tank_h + 3, tank_b - tank_h + 6):  # chingi
        t.rect(ox, by, 15, 1, M[1])
    t.rect(ox, tank_b - tank_h, 15, 1, M[4])
    t.rect(ox, tank_b - 1, 15, 1, M[0])
    # acoperis conic
    ch = 4
    for r in range(ch):
        wid = int(round(3 + 14 * r / (ch - 1)))
        x0 = ox + 7 - wid // 2
        y = tank_b - tank_h - ch + r
        for x in range(x0, x0 + wid):
            t.put(x, y, M[3] if x < ox + 7 else M[1])
        t.put(x0, y, M[4])
    # baliza: capul de 3x2 sta pe randurile (ly-1, ly), ca felinarele cheiului; tija coboara pana la acoperis
    ly = tank_b - tank_h - ch - 3
    t.rect(ox + 7, ly, 1, 3, M[1])
    t.rect(ox + 6, ly - 1, 3, 2, hz(BEACON_RAW, f * 0.5))
    p.lamps.append((ox + 7, ly))
    p.finish()
    # cadrul de sub rezervor: dupa contur, fara contur
    def leg_left(r):
        return ox + 2 - int(round(2 * r / (leg_h - 1.0)))

    def leg_right(r):
        return ox + 12 + int(round(2 * r / (leg_h - 1.0)))

    for r in range(leg_h):
        t.put(leg_left(r), tank_b + r, M[3] if r % 3 else M[2])
        t.put(leg_right(r), tank_b + r, M[0])
        t.put(ox + 7, tank_b + r, M[2])
    rail = 6
    t.rect(leg_left(rail), tank_b + rail, leg_right(rail) - leg_left(rail) + 1, 1, M[1])
    top_r, bot_r = 1, 5
    for (xa, xb) in ((leg_left, lambda r: ox + 7), (lambda r: ox + 7, leg_right)):  # un X pe travee
        x_tl, x_tr = xa(top_r) + 1, xb(top_r) - 1
        x_bl, x_br = xa(bot_r) + 1, xb(bot_r) - 1
        steps = bot_r - top_r
        for i in range(steps + 1):
            t.put(x_tl + (x_br - x_tl) * i // steps, tank_b + top_r + i, M[1])
            t.put(x_tr + (x_bl - x_tr) * i // steps, tank_b + top_r + i, M[1])
    return p


# ---------------------------------------------------------------------------------------------
# panza


class Town:
    def __init__(self):
        self.c = C(W, H)
        self.wins = []  # (x, y, w, h, ceata) in panza finala
        self.unders = []  # pentru fiecare fereastra din `wins`, in aceeasi ordine: peretele de dedesubt [(x, y, culoare)]
        self.lamps = []  # (x, y) = capul unui felinar de varf (castelul de apa)
        self.quay = []  # (x, y) = capul unui felinar de chei (stalp dedesubt)
        self.clocks = []  # (x, y) = centrul unui cadran
        self.chims = []  # (x, y) = gura unui cos
        self.dropped = 0  # ferestre acoperite de alte case, scoase din lista
        self.healed = 0  # pixeli ramasi vizibili din ferestrele scoase, readusi la culoarea peretelui
        self.rng = Rng(7511)

    def place(self, piece, x, base):
        """Pune piesa cu coltul stang al zidului la x si randul de baza pe `base`."""
        gx, gy = x - PAD, base - BL
        src = piece.c
        for yy in range(src.h):
            for xx in range(src.w):
                pxl = src.px[yy][xx]
                if pxl[3]:
                    self.c.put(gx + xx, gy + yy, pxl)
        for (wx, wy, ww, wh, wf), under in zip(piece.wins, piece.unders):
            self.wins.append((gx + wx, gy + wy, ww, wh, wf))
            self.unders.append([(gx + ux, gy + uy, col) for (ux, uy, col) in under])
        for (lx, ly) in piece.lamps:
            self.lamps.append((gx + lx, gy + ly))
        for (cx, cy) in piece.clocks:
            self.clocks.append((gx + cx, gy + cy))
        for (cx, cy) in piece.chims:
            self.chims.append((gx + cx, gy + cy))


def ground(town):
    """Malul de nord: iarba abia trasa spre albastru si translucida (malul copt de dedesubt se vede printre case), cu un drum de
    nisip la mal, opac; marginea de sus si cea de jos se sting in alfa, iar capetele panzei se subtiaza, ca orasul sa intre fara
    cusatura in malul de dedesubt."""
    c, rng = town.c, Rng(404)
    G = hzr([GRASS[0], GRASS[1], GRASS[2], GRASS[3], GRASS[4]], 0.12)
    SD = hzr(SAND, 0.32)
    bot = [255, 235, 190, 130, 70, 28]  # alfa de la randul 38 in jos, pana la 43
    for x in range(W):
        ax = min(1.0, (x + 1) / 9.0, (W - x) / 9.0)
        ax = max(0.0, ax)
        top = 28 + int(round(1.6 * math.sin(x * 0.045 + 0.7) + 1.2 * math.sin(x * 0.13)))
        for y in range(top - 2, H):
            if y < top:
                a = 70 if y == top - 1 else 34
            elif y < top + 2:
                a = 120
            else:
                a = GRASS_ALPHA if y < 38 else 255
            if y >= 38:
                a = min(a, bot[min(5, y - 38)])
            a = int(a * ax)
            if a <= 0:
                continue
            n = rng.n()
            tone = G[2]
            if n < 0.10:
                tone = G[1]
            elif n > 0.90:
                tone = G[3]
            if y < top + 3:
                tone = G[3] if n > 0.4 else G[2]
            if y in (38, 39) and 3 < x < W - 4:  # drumul de la mal
                tone = SD[2] if n > 0.25 else SD[3]
                if y == 38:
                    tone = SD[3]
            c.put(x, y, tone[:3] + (a,))


def reeds(town, rng):
    """Cateva smocuri de stuf si pietre pe marginea de jos, ca baza sa nu fie o linie dreapta."""
    c = town.c
    R = hzr(ramp(70, 0.40, 0.52), 0.34)
    for x in (9, 31, 64, 130, 176, 244, 268, 312, 329):
        h = rng.i(2, 4)
        for k in range(rng.i(2, 3)):
            xx = x + k * 2 - 1
            for i in range(h - (k % 2)):
                c.put(xx, 41 - i, R[2 + (k % 2)][:3] + (max(40, 210 - i * 40),))


ZONES = [(84, 118), (204, 234), (288, 307)]  # unde stau reperele (biserica, primaria, castelul de apa): randul din fata le ocoleste
LAND = {"church": (86, 34), "hall": (206, 34), "tower": (290, 33)}  # x al coltului stang, randul de baza
QUAY_LAMPS = (14, 47, 78, 124, 170, 199, 249, 282, 316)  # x-ul felinarelor de chei


def pick(rng, seq):
    return seq[rng.i(0, len(seq) - 1)]


def back_row(town, rng):
    """Randul din spate: case mici si cetoase, vazute printre cele din fata (mai ales acoperisurile si cosurile)."""
    x = 6
    n = 0  # a cata casa din spate; cos doar la fiecare a doua si doar la cele late, ca sa nu iasa o rand de dinti peste acoperisurile din fata
    while x < 326:
        w = pick(rng, (10, 11, 12, 13))
        z = next((z for z in ZONES if x + w > z[0] and x < z[1]), None)
        if z:
            x = z[1] + 1
            continue
        kind = pick(rng, ("hip", "gable", "gablewall"))
        slope = 1.0 if kind != "hip" else pick(rng, (1.0, 1.0, 0.7))
        wh, rh, wall, roof = rng.i(5, 7), rng.i(3, 5), pick(rng, WALLS), pick(rng, ROOFS)
        cf = 0.3 + 0.4 * rng.n()  # se trage mereu, ca asezarea caselor sa ramana aceeasi chiar daca nu primesc cos
        h = house(w, wh, rh, wall, roof, F_BACK, kind=kind, slope=slope, chim=cf if (n % 2 == 0 and w > 11) else None)
        n += 1
        town.place(h, x, 31)
        x += w + rng.i(2, 5)


def front_row(town, rng):
    """Randul din fata: case de toate marimile, copaci intre ele, tufisuri sub repere. Latimile se aleg dupa locul ramas pana la
    urmatorul reper sau pana la capatul malului, ca nimic sa nu se taie sau sa acopere turnurile."""
    END = 331
    x = 9
    while x < END - 9:
        z = next((z for z in ZONES if z[0] - 1 <= x < z[1]), None)
        if z:  # sub un reper: tufisuri joase
            xx = max(x, z[0] + 1)
            while xx < z[1] - 5:
                town.place(bush(rng.i(5, 8), F_FRONT), xx, 37)
                xx += rng.i(8, 13)
            x = z[1] + 1
            continue
        nxt = min([z[0] for z in ZONES if z[0] > x] + [END])
        room = nxt - x - 1
        if room < 10:  # prea putin pentru o casa: un tufis si mai departe
            town.place(bush(max(4, room), F_FRONT), x, 37)
            x = nxt
            continue
        if rng.n() < 0.30 and room >= 12:  # un copac intre case
            if rng.n() < 0.5:
                r = rng.i(4, 5)
                town.place(tree_round(r, F_FRONT, warm=rng.n() < 0.4), x, 37)
                x += 2 * r + 2
            else:
                hgt = rng.i(11, 15)
                town.place(tree_conifer(hgt, F_FRONT), x, 37)
                x += hgt // 2 + 4
            continue
        w = pick(rng, [v for v in (11, 12, 13, 14, 15, 16, 18) if v <= room])
        wh = pick(rng, (6, 7, 8, 8, 9, 10, 10, 11))
        floors = 2 if wh >= 10 else 1
        kind = pick(rng, ("hip", "gable", "gablewall", "hip"))
        slope = 1.0 if kind != "hip" else pick(rng, (1.0, 1.0, 0.7))
        soft_shadow(town.c, x + w / 2.0, 38, w / 2.0 + 1, 1)
        h = house(w, wh, rng.i(4, 7), pick(rng, WALLS), pick(rng, ROOFS), F_FRONT, kind=kind, slope=slope, floors=floors,
                  chim=0.3 + 0.45 * rng.n())
        town.place(h, x, 37)
        x += w + rng.i(1, 4)


def build():
    """Intoarce (panza de baza, panza luminata, orasul cu listele de lumini)."""
    town = Town()
    rng = town.rng
    ground(town)
    # copaci din spate, cei mai cetosi, deasupra caselor din spate
    for k, x in enumerate((14, 58, 150, 186, 262, 324)):
        town.place(tree_conifer(12, F_BACK + 0.04) if k % 2 == 0 else tree_round(4, F_BACK + 0.04), x, 32)
    back_row(town, rng)
    town.place(church(F_MID), *LAND["church"])
    town.place(hall(F_MID), *LAND["hall"])
    town.place(water_tower(F_MID), *LAND["tower"])
    # copaci la capetele malului: orasul se subtiaza in loc sa se opreasca
    town.place(tree_conifer(14, F_FRONT), 1, 37)
    town.place(tree_round(4, F_FRONT), 329, 37)
    front_row(town, rng)
    keep_visible(town)
    reeds(town, rng)
    town.quay = [(free_lamp_x(town, lx), 34) for lx in QUAY_LAMPS]
    lamp_dark(town)
    base = town.c
    lit = C(W, H)
    lit_lights(lit, town)
    return base, lit, town


def keep_visible(town):
    """Pastreaza doar ferestrele care se vad la final: o casa din spate are ferestre pe care le acopera casele din fata, iar
    lumina nu are voie sa treaca prin zid. O fereastra ramane daca TOATE pixelii ei sunt inca ai ei in panza de baza.
    La o fereastra scoasa, pixelii ei care se mai vad (o margine iesita de sub casa din fata) se repara in culoarea peretelui,
    altfel ar ramane pete intunecate care nu se aprind niciodata."""
    keep = []
    healed = 0
    for (x, y, w, h, f), under in zip(town.wins, town.unders):
        mine = (hz(WIN_DARK, f * 0.55), hz(WIN_GLINT, f * 0.55))
        if all(town.c.px[yy][xx] in mine for yy in range(y, y + h) for xx in range(x, x + w)):
            keep.append((x, y, w, h))
            continue
        for (xx, yy, wall) in under:
            if town.c.px[yy][xx] in mine:
                town.c.put(xx, yy, wall)
                healed += 1
    town.dropped = len(town.wins) - len(keep)
    town.healed = healed
    town.wins = keep


def free_lamp_x(town, lx):
    """Cel mai apropiat x de `lx` unde stalpul si capul felinarului nu cad peste o fereastra (ferestrele ramase)."""
    for d in (0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6):
        x = lx + d
        if 4 < x < W - 5 and all(not (wx < x + 3 and x - 2 < wx + ww and wy < 38 and 31 < wy + wh)
                                 for (wx, wy, ww, wh) in town.wins):
            return x
    return lx


def lamp_head(f=F_FRONT):
    """Culoarea capului unui felinar de chei, stins: aceeasi ca a ferestrelor intunecate (nu mai pare aprins la lumina zilei)."""
    return hz(WIN_DARK, f * 0.55)


def lamp_dark(town):
    """Stalpul si capul felinarelor de chei, stinse, in panza de baza (baliza din varful castelului de apa e desenata de piesa
    ei). Stalpul are culoarea caselor din fata si se opreste pe drum (randul 39); doar capacul de deasupra e crem."""
    c = town.c
    P = hz(WOOD[0], F_FRONT)
    for (lx, ly) in town.quay:
        c.rect(lx, ly + 1, 1, 5, P)
        c.rect(lx - 1, ly - 1, 3, 2, lamp_head())
        c.put(lx, ly - 2, hz(LAMP_CAP_RAW, 0.35))


def glow_rect(c, x, y, w, h, bands, color, top_fade=()):
    """Haloul unui dreptunghi luminos: alfa pe benzi, cu distanta pana la marginea dreptunghiului. `top_fade` = factorii alfa
    pe primele randuri ale panzei (randul 0, randul 1, ...), ca un halo care ajunge la margine sa se stinga in loc sa fie taiat drept."""
    R = int(bands[-1][0]) + 1
    for yy in range(y - R, y + h + R):
        for xx in range(x - R, x + w + R):
            dx = max(x - xx, 0, xx - (x + w - 1))
            dy = max(y - yy, 0, yy - (y + h - 1))
            d = math.hypot(dx, dy)
            if d == 0:
                continue
            for lim, a in bands:
                if d <= lim:
                    if 0 <= yy < len(top_fade):
                        a = int(round(a * top_fade[yy]))
                    c.put(xx, yy, color[:3] + (a,))
                    break


def lit_lights(lit, town):
    """Panza luminata: din listele orasului, nu din panza de baza, deci ferestrele nu au cum sa nu se suprapuna. Intai haloul
    (alfa moale, pe benzi), apoi nucleele calde, ca sa ramana curate. TOATE ferestrele se aprind: jocul le descopera de la stanga la
    dreapta, iar ultima nu are voie sa ramana stinsa. Haloul balizei, care ajunge la marginea de sus, se stinge pe primele doua
    randuri. Felinarele de chei si ferestrele sunt galbene; baliza din varful castelului de apa e rosie-calda, ca sa se citeasca drept
    baliza si nu drept inca o fereastra."""
    GLOW = (255, 196, 92, 255)
    CORE, TOP, BOT = (255, 224, 122, 255), (255, 244, 182, 255), (240, 176, 84, 255)
    B_GLOW, B_CORE, B_TOP = (255, 120, 80, 255), (255, 150, 100, 255), (255, 200, 160, 255)
    on = town.wins  # toate ferestrele: la 100% orasul trebuie sa se termine pe o fereastra aprinsa, nu pe una ramasa intunecata
    for (x, y, w, h) in on:
        bands = [(1.0, 70), (2.2, 46), (3.4, 26), (4.6, 12)]
        if max(w, h) >= 4:
            bands.append((5.6, 6))
        glow_rect(lit, x, y, w, h, bands, GLOW)
    for (cx, cy) in town.clocks:
        glow_rect(lit, cx - 2, cy - 2, 5, 5, [(1.0, 60), (2.4, 36), (3.8, 16), (5.0, 7)], GLOW)
    big = [(1.0, 84), (2.2, 56), (3.4, 32), (4.8, 14), (6.0, 6)]
    for (lx, ly) in town.quay:
        glow_rect(lit, lx - 1, ly - 1, 3, 2, big, GLOW)
    for (lx, ly) in town.lamps:
        glow_rect(lit, lx - 1, ly - 1, 3, 2, big, B_GLOW, top_fade=(0.25, 0.6))
    for (x, y, w, h) in on:
        lit.rect(x, y, w, h, CORE)
        lit.rect(x, y, w, 1, TOP)
        if h >= 3:
            lit.rect(x, y + h - 1, w, 1, BOT)
    for (cx, cy) in town.clocks:  # cadranul: disc palid cu limbile ramase intunecate
        for dx, dy in ((-2, -2), (2, -2), (-2, 2), (2, 2)):  # colturile cutiei 5x5: fara ele ar ramane un inel stins intre cadran si halo
            lit.put(cx + dx, cy + dy, GLOW[:3] + (70,))
        lit.ellipse(cx, cy, 2.3, 2.3, (255, 238, 170, 255))
        for dx, dy in ((0, -1), (0, 0), (1, 0)):
            lit.put(cx + dx, cy + dy, (150, 104, 52, 255))
    for (lx, ly) in town.quay:
        lit.rect(lx - 1, ly - 1, 3, 2, CORE)
        lit.put(lx, ly - 1, TOP)
    for (lx, ly) in town.lamps:
        lit.rect(lx - 1, ly - 1, 3, 2, B_CORE)
        lit.put(lx, ly - 1, B_TOP)
    for (lx, ly) in town.quay:  # balta de lumina pe drumul de la mal
        for dx in range(-5, 6):
            a = int(34 * (1 - abs(dx) / 6.0))
            lit.put(lx + dx, 38, GLOW[:3] + (a,))
            lit.put(lx + dx, 39, GLOW[:3] + (a // 2,))


# ---------------------------------------------------------------------------------------------

SPRITES = {}


def prop_painted_town():
    return build()[0]


def prop_painted_town_lit():
    return build()[1]


SPRITES["prop_painted_town"] = prop_painted_town
SPRITES["prop_painted_town_lit"] = prop_painted_town_lit


# ---------------------------------------------------------------------------------------------
# previzualizare


def to_img(c):
    from PIL import Image

    im = Image.new("RGBA", (c.w, c.h))
    im.putdata([c.px[y][x] for y in range(c.h) for x in range(c.w)])
    return im


def preview(out):
    from PIL import Image, ImageDraw, ImageEnhance

    base, lit = to_img(SPRITES["prop_painted_town"]()), to_img(SPRITES["prop_painted_town_lit"]())
    green = (86, 128, 64, 255)
    night = (24, 30, 52, 255)
    ground = Image.open(GROUND_PNG).convert("RGBA")
    # taiere din pamantul barajului: lumea x 1690-2720 (/3), y 240-480 (/3): orasul sta la y 273-405, cu padurea deasupra si raul sub el
    gx0, gx1 = 1690 // 3, 2720 // 3
    gy0, gy1 = 240 // 3, 480 // 3
    crop = ground.crop((gx0, gy0, gx1, gy1))
    # sub apa pamantul copt e transparent (raul viu curge dedesubt): il punem pe un rau de proba
    stage = Image.new("RGBA", crop.size, (80, 124, 160, 255))
    stage.alpha_composite(crop)
    px = ANCHOR[0] // 3 - W // 2 - gx0
    py = int(round((ANCHOR[1] - 3 * H) / 3.0)) - gy0  # coltul de sus-stanga: arta (564, 91) in prop_dam_ground
    margin, label_h = 12, 14
    rows = []

    def sheet_item(title, img, scale, bgc):
        im = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
        canvas = Image.new("RGBA", im.size, bgc)
        canvas.alpha_composite(im)
        return title, canvas

    both = base.copy()
    both.alpha_composite(lit)
    rows.append(sheet_item("prop_painted_town  340x44  (x2)", base, 2, green))
    rows.append(sheet_item("prop_painted_town_lit  340x44  (x2)  on grass", lit, 2, green))
    rows.append(sheet_item("prop_painted_town_lit  (x2)  on night", lit, 2, night))
    rows.append(sheet_item("base + lit  (x2)", both, 2, green))

    def on_ground(with_lit, dusk):
        st = stage.copy()
        if dusk:
            st = ImageEnhance.Brightness(st).enhance(0.48)
            tint = Image.new("RGBA", st.size, (20, 32, 80, 70))
            st.alpha_composite(tint)
        st.alpha_composite(base, (px, py))
        if with_lit:
            st.alpha_composite(lit, (px, py))
        return st

    rows.append(("on dam_ground crop  1x  (real scale)  base", on_ground(False, False)))
    rows.append(("on dam_ground crop  1x  base + lit", on_ground(True, False)))
    rows.append(("same  x3  base", on_ground(False, False).resize((crop.width * 3, crop.height * 3), Image.NEAREST)))
    rows.append(("same  x3  dusk, base + lit", on_ground(True, True).resize((crop.width * 3, crop.height * 3), Image.NEAREST)))
    wmax = max(im.width for _, im in rows)
    total = sum(im.height + label_h + margin for _, im in rows) + margin
    sheet = Image.new("RGBA", (wmax + 2 * margin, total), (40, 40, 44, 255))
    d = ImageDraw.Draw(sheet)
    y = margin
    for title, im in rows:
        d.text((margin, y), title, fill=(235, 235, 235, 255))
        y += label_h
        sheet.alpha_composite(im, (margin, y))
        y += im.height + margin
    path = os.path.join(out, "painted_town_preview.png")
    sheet.save(path)
    return path


def selfcheck(base, lit, town):
    """Verificari: aceleasi dimensiuni; fiecare fereastra aprinsa sta peste o fereastra intunecata din panza de baza; FIECARE
    pixel opac din panza luminata (ferestre, capete de felinar, cadran, baliza) sta peste un pixel de lumina al panzei de baza
    (fereastra intunecata, cap de felinar stins, cadran, cap de baliza); felinarele de chei si baliza au capul 3x2 exact pe capul
    din baza; panza luminata e transparenta in rest; nimic opac nu atinge marginile de sus, stanga, dreapta; niciun pixel opac
    negru."""
    assert (base.w, base.h) == (lit.w, lit.h) == (W, H)
    for (x, y, w, h) in town.wins:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                b = base.px[yy][xx]
                assert b[3] == 255 and b[2] > b[0] and b[0] < 120, ("fereastra nu e intunecata in baza", x, y, b)
    heads = {lamp_head(F_FRONT), hz(BEACON_RAW, F_MID * 0.5)}
    for (lx, ly) in town.quay:
        for yy in (ly - 1, ly):
            for xx in range(lx - 1, lx + 2):
                assert base.px[yy][xx] == lamp_head(F_FRONT), ("capul felinarului de chei nu e in baza", lx, ly, xx, yy)
    for (lx, ly) in town.lamps:
        for yy in (ly - 1, ly):
            for xx in range(lx - 1, lx + 2):
                assert base.px[yy][xx] == hz(BEACON_RAW, F_MID * 0.5), ("capul balizei nu e in baza", lx, ly, xx, yy)
    light_ok = set(heads)
    for f in (F_BACK, F_MID, F_FRONT):
        light_ok |= {hz(WIN_DARK, f * 0.55), hz(WIN_GLINT, f * 0.55)}
    light_ok |= {hz(CLOCK_FACE, F_MID * 0.6), hz(CLOCK_HAND, F_MID)}
    for yy in range(H):
        for xx in range(W):
            if lit.px[yy][xx][3] == 255:
                assert base.px[yy][xx] in light_ok, ("pixel luminat peste ceva ce nu e lumina in baza", xx, yy, base.px[yy][xx])
    clear = sum(1 for yy in range(H) for xx in range(W) if lit.px[yy][xx][3] == 0)
    assert clear > 0.6 * W * H, "panza luminata nu e destul de transparenta"
    for yy in range(H):
        for xx in range(W):
            b = base.px[yy][xx]
            if b[3] == 255:
                assert max(b[:3]) > 30, ("pixel opac aproape negru", xx, yy, b)
            if (xx in (0, W - 1) or yy == 0) and b[3] > 200:
                raise AssertionError(("piesa taiata de margine", xx, yy))
    print(f"  verificari ok: {len(town.wins)} ferestre aprinse (+{town.dropped} acoperite, scoase), {len(town.quay)} felinare de chei,"
          f" {len(town.lamps)} de varf, {len(town.clocks)} ceas")


def main():
    out = DEFAULT_OUT
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    base, lit, town = build()
    selfcheck(base, lit, town)
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == (W, H), (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")
    print("  previzualizare:", preview(out))


if __name__ == "__main__":
    main()
