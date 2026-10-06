#!/usr/bin/env python3
"""[D75, lotul A1] Stalpii de inalta tensiune si cristalul de pe rau, pentru barajul lumii 2 (Era 4).

Era 4 vinde curentul dus pe stalpi. Satul Erei 3 a avut stalpi de lemn gudronat (prop_wire_pole); barajul pune FIER:
turnuri de zabrele galvanizate, cu izolatori de portelan agatati sub brate. La fel ca la stalpii satului, bratele sunt
desenate IN PERSPECTIVA (capatul din fata mai jos, cel din spate mai sus), ca firele sa mearga paralel la inaltimi
diferite. Fiecare sprite are ancora jos-mijloc; punctele unde atinge firul izolatorul stau in WIRES (pixeli de foaie,
ca POLE_WIRES din d70_modern; x Assets.PIXEL_SCALE = pixeli de lume).

  prop_pylon_tall    16x67  (river_pylon, 48x200 de lume)  turnul de zabrele, doua brate cu izolatori agatati, becul
                                                           rosu de semnalizare in varf; cel mai inalt lucru construit
  prop_pylon_lane     8x40  (lane_pylon, 24x120)           stalp tubular subtire, un brat, doi izolatori pe pini
  prop_pylon_post     5x23  (bridge_pylon_*, 16x70)        stalpisorul de pe balustrada podului, un izolator
  prop_river_crystal 36x16  = 2 cadre de 18x16             un buchet de cristale albastru-violet pe o bucata de bustean,
                                                           plutind pe rau; primul semn al erei cristalelor. Cadrul 1 e
                                                           aprins, cadrul 2 doar mai stins (puls, fara dunga care sare). Ancora jos-mijloc, pe fiecare cadru.

SCARA IN JOC: DamTownController.drawFitted ia k = min(w / latime, h / inaltime) si pune imaginea cu ancora (0.5, 1) in (x, y)
(deci y = baza). Ca pixelii de arta sa ramana intregi (x3, fara un rand dublat sau pierdut, care ar ingrosa traversele de
1 px), cutiile din TycoonConfig.WORLDS[2].pylons trebuie sa fie multipli de 3: river_pylon h = 201 (nu 200: 200/67 = 2,985),
bridge_pylon_w / _e w = 15, h = 69 (nu 16 x 70: 70/23 = 3,043); lane_pylon (24 x 120) e deja exact x3.

Aceleasi reguli ca restul conductei: rampe din palette.ramp() si ale vecinilor (d67_works IRON, tycoon_e1 REDC), umbra
din elipse translucide, conturul trasat automat, lumina din stanga-sus, niciodata negru pur. Scrie DOAR in --out
(nu atinge assets/sprites).

Rulare: python3 scripts/art/a1_pylons.py [--out DIR]   (PNG-uri native + pylons_preview.png in scratchpad)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, png  # noqa: E402
from palette import STONE, FOAM, OUTLINE, ramp, mix  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import REDC, outline_trace  # noqa: E402
from tycoon_f3 import WEATHERED  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d67_works as W  # noqa: E402
from d59 import in_water  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a1")
GRASS_BG = (86, 128, 64, 255)
# conturul fierului: ACELASI maro ca la restul fierului din sat (felinarul, Power House); testat si cu unul neutru: pe
# iarba si pe piatra podului, maroul ramane in familia desenelor vecine, iar zabrelele galvanizate se desprind mai bine din el
STEEL_LINE = OUTLINE

IRON = W.IRON  # umbrele si zabrelele
# fierul galvanizat: gri-albastrui, mai luminos decat IRON ca sa se citeasca pe iarba (umbrele raman din IRON)
GALV = ramp(212, 0.18, 0.62, val_span=0.44)
# cristalul: albastru-violet, cu lumina spre ciclam-alb (hue rotit spre violet in umbra, spre cian in lumina)
CRYS = [(34, 36, 112, 255), (58, 62, 168, 255), (90, 96, 222, 255), (136, 142, 248, 255), (204, 214, 255, 255)]
# fatete mai violete; ridicate cu o treapta fata de prima versiune (adancul era (52,34,118): acum e al doilea ton), ca cele doua
# cristale laterale sa straluceasca, nu sa citeasca ca ametist inchis; [4] ramane sub albastrul cristalului din mijloc
CRYS_VIO = [(84, 52, 170, 255), (120, 78, 214, 255), (164, 118, 244, 255), (196, 150, 255, 255)]
CRYS_GLOW = (118, 132, 255)
CORE_BRIGHT = (186, 196, 255, 255)  # miezul cristalului mare, cadrul aprins
CORE_DIM = (154, 162, 252, 255)  # acelasi miez, cadrul stins: abia peste fateta luminata (136,142,248)


# ---------------------------------------------------------------------------------------------
# bucati comune


def thin(c, x0, y0, x1, y1, col, over=(OUTLINE,)):
    """O zabrea subtire, trasata DUPA contur: doar pe transparent sau peste conturul insusi (nu strica niciun stalp)."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        if 0 <= x < c.w and 0 <= y < c.h and (c.px[y][x][3] == 0 or c.px[y][x] in over):
            c.put(x, y, col)


def hang_insulator(c, x, y):
    """Lantul de izolatori agatat sub un brat (3 lat, 7 randuri): caciula de fier, doua discuri de portelan a cate
    doua randuri cu gatul dintre ele, cleama jos. (x, y) = mijlocul caciulii; intoarce punctul firului = cleama.
    Lumina din stanga-sus: coloana stanga mai deschisa, cea dreapta in umbra."""
    c.put(x, y, IRON[1])
    for yy in (y + 1, y + 4):
        c.rect(x - 1, yy, 3, 2, CREAM[3])
        c.rect(x - 1, yy, 3, 1, CREAM[4])
        c.rect(x - 1, yy + 1, 3, 1, CREAM[2])
        c.put(x - 1, yy + 1, CREAM[3])
        c.put(x + 1, yy, CREAM[2])
        c.put(x + 1, yy + 1, CREAM[1])
    c.put(x, y + 3, CREAM[0])
    c.put(x, y + 6, IRON[2])
    return (x, y + 6)


def ribbed_pin(c, x, y):
    """Izolatorul nervurat pe pin al stalpului de poteca (2 lat, 3 randuri): sapca luminata, un sant intunecat la mijloc,
    fusta. (x, y) = coltul stanga-sus. Se deseneaza INAINTE de contur, ca sa primeasca ramul intunecat al fierului
    (altfel crem pe iarba se citeste ca un glob de felinar). Intoarce punctul firului = granita dintre cele doua coloane."""
    c.put(x, y, CREAM[4])
    c.put(x + 1, y, CREAM[3])
    c.put(x, y + 1, CREAM[1])
    c.put(x + 1, y + 1, CREAM[0])  # santul
    c.put(x, y + 2, CREAM[3])
    c.put(x + 1, y + 2, CREAM[2])
    return (x + 1, y)


def footing(c, x, y, w):
    """Talpa de beton a unui picior: un bloc scund, cu fata luminata sus-stanga."""
    c.rect(x, y, w, 2, STONE[2])
    c.rect(x, y, w, 1, STONE[3])
    c.put(x + w - 1, y + 1, STONE[1])


def glow(c, pts, rows, col, top, power=1.2, floor=20):
    """O aureola moale in jurul unei lumini: alfa = `top` la distanta 1 de cel mai apropiat pixel din `pts`, scazand cu
    d**-power; sub `floor` nu se mai scrie nimic. Pusa doar pe transparent, dupa contur."""
    for y in rows:
        for x in range(c.w):
            if c.px[y][x][3] != 0:
                continue
            d = min(math.hypot(x - px, y - py) for px, py in pts)
            a = int(top * max(d, 1.0) ** -power)
            if a >= floor:
                c.put(x, y, (col[0], col[1], col[2], a))


# ---------------------------------------------------------------------------------------------
# turnul inalt (16 x 67)

TALL_W, TALL_H = 16, 67
TALL_BASE = 64  # randul de jos al talpilor

# capetele bratelor (mijlocul caciulii lantului de izolatori), capatul din fata (stanga) mai jos decat cel din spate;
# trase cu 1 px spre interior fata de prima versiune, ca lantul de 3 px lat sa-si primeasca ramul de contur pe 16 px
TALL_ARMS = {"high_near": (3, 18), "high_far": (12, 14), "low_near": (2, 33), "low_far": (13, 27)}
BULB = ((7, 1), (8, 1), (7, 2), (8, 2))  # becul de semnalizare: 2x2, cu un rand liber deasupra pentru aureola
# talia turnului: sub bratele de sus, pe randurile lantului de jos-stanga (33-39) picioarele raman de 1 px (x5 si x10), ca intre
# lant (ram la x4) si picior sa nu ramana nicio atingere, iar intre ele sa se vada interiorul (x6-9) cu zabrelele in X
WAIST_ROWS = (33, 39)
WAIST_LEGS = (5, 10)


def _leg_x(y, top_y=30, top_x=6.0, base_y=TALL_BASE - 2, base_x=1.0):
    """Marginea stanga a piciorului stang la randul y: talia (top_x) pana la randul 30, adica pe toata inaltimea bratelor si
    a lanturilor de izolatori, apoi o interpolare liniara spre talpa. Asa fiecare lant atarna liber sub capatul bratului, cu
    un rand de contur intre el si picior (lantul de jos-stanga are rama la x0 si x4; piciorul incepe la x5)."""
    t = (y - top_y) / (base_y - top_y)
    return top_x + (base_x - top_x) * max(0.0, min(1.0, t))


def prop_pylon_tall():
    """Turnul de zabrele (16x67): un trunchi de 4 px pana la randul 30 (cat tin bratele), o talie cu picioare de 1 px, apoi
    picioarele se desfac spre talpa, cu traverse si zabrele in X (otel galvanizat); doua brate in perspectiva (cel de sus mai
    scurt), un lant de izolatori agatat la fiecare capat, liber, cu un rand de contur intre el si picior (desenati inainte
    de contur), si becul rosu de semnalizare in varf, cu aureola. Punctele firului: WIRES."""
    c = C(TALL_W, TALL_H)
    soft_shadow(c, 8, TALL_BASE + 1, 8, 1.6)
    # picioarele: 2 px latime, lumina pe stanga; de la gat (y 11) la talpa
    for y in range(11, TALL_BASE - 1):
        xl = round(_leg_x(y))
        xr = 15 - xl
        if WAIST_ROWS[0] <= y <= WAIST_ROWS[1]:  # talia: picioare de 1 px, ca intre ele sa ramana loc pentru zabrele
            c.put(WAIST_LEGS[0], y, GALV[2])
            c.put(WAIST_LEGS[1], y, IRON[3])
            continue
        c.put(xl, y, GALV[3])
        c.put(xl + 1, y, GALV[2])
        c.put(xr - 1, y, IRON[3])
        c.put(xr, y, IRON[2])
    # catargul de deasupra bratelor: 2 px, cu coliere; becul sta direct pe el
    c.rect(7, 3, 2, 8, GALV[2])
    c.rect(7, 3, 1, 8, GALV[3])
    c.rect(8, 3, 1, 8, IRON[3])
    for y in (6, 9):
        c.rect(7, y, 2, 1, GALV[1])
    # becul: punctul fierbinte sus-stanga, restul rosu tot mai adanc (rosu real, nu somon)
    c.put(7, 1, (255, 150, 130, 255))
    c.put(8, 1, (230, 58, 48, 255))
    c.put(7, 2, (200, 44, 44, 255))
    c.put(8, 2, REDC[0])
    # traversele orizontale, intre panouri (de jos in sus, panourile se lasa tot mai late: 40-48, 48-55, 55-62)
    for y in (27, 40, 48, 55, 62):
        xl = round(_leg_x(y))
        c.rect(xl, y, 16 - 2 * xl, 1, GALV[1])
    # bratele: muchia de sus luminata, cea de jos in umbra; capatul din fata (stanga) mai jos
    (hnx, hny), (hfx, hfy) = TALL_ARMS["high_near"], TALL_ARMS["high_far"]
    (lnx, lny), (lfx, lfy) = TALL_ARMS["low_near"], TALL_ARMS["low_far"]
    line(c, hnx, hny - 1, hfx, hfy - 1, GALV[3], 1)
    line(c, hnx, hny, hfx, hfy, GALV[1], 1)
    # (fara contrafise sub bratele din fata: ar atinge lantul de izolatori, iar lantul trebuie sa atarne liber, cu ram)
    line(c, lnx, lny - 1, lfx, lfy - 1, GALV[3], 1)
    line(c, lnx, lny, lfx, lfy, GALV[1], 1)
    # talpile de beton
    footing(c, 0, TALL_BASE - 1, 4)
    footing(c, 12, TALL_BASE - 1, 4)
    # izolatorii, INAINTE de contur: gatul de 1 px al fiecarui disc primeste crestaturi de ram pe ambele parti
    for (x, y) in TALL_ARMS.values():
        hang_insulator(c, x, y)
    outline_trace(c, STEEL_LINE)
    # becul nu are ram intunecat (e o lumina, nu o piesa): ramul lui devine aureola
    for x, y in ((7, 0), (8, 0), (6, 1), (9, 1), (6, 2), (9, 2)):
        c.px[y][x] = (0, 0, 0, 0)
    # dupa contur: zabrelele in X, subtiri, galvanizate, in fiecare panou
    for y0, y1 in ((40, 48), (48, 55), (55, 62)):
        a0, a1 = round(_leg_x(y0)) + 2, round(_leg_x(y1)) + 2
        b0, b1 = 15 - a0, 15 - a1
        thin(c, a0, y0 + 1, b1, y1 - 1, GALV[1], (STEEL_LINE,))
        thin(c, b0, y0 + 1, a1, y1 - 1, GALV[1], (STEEL_LINE,))
    # panoul de talie (27-40): cu picioarele de 1 px, interiorul are 4 px (x6-9, dintre care x6 si x9 sunt ramul), deci o zabrea
    # in X pe 4 randuri (35-38), cu cate un rand liber deasupra si dedesubt; la 6 randuri ar iesi o coloana, nu un X
    thin(c, 6, 35, 9, 38, GALV[1], (STEEL_LINE,))
    thin(c, 9, 35, 6, 38, GALV[1], (STEEL_LINE,))
    # aureola becului: rosu moale, ~90 la distanta 1, ~40 la 2, nimic sub 20
    glow(c, BULB, range(0, 6), (255, 70, 60), 90)
    return c


# ---------------------------------------------------------------------------------------------
# stalpul de pe poteca (8 x 40)

# izolatorii nervurati 2x3, cate unul la fiecare capat al bratului (coltul stanga-sus); intre ei si teava ramane cate o
# coloana libera (x2, x5) pentru ramul de contur, ca sa nu se mai lipeasca intr-o singura gluma ca un felinar cu doua globuri
LANE_INS = {"near": (0, 8), "far": (6, 5)}
LANE_PINS = {"near": (1, 8), "far": (7, 5)}  # punctul firului: granita dintre cele doua coloane de portelan


def prop_pylon_lane():
    """Stalpul subtire (8x40): teava de otel pe o flansa de beton, cu un manson (flansa de la schimbarea de grosime), un brat
    in perspectiva si doi izolatori nervurati. Teava se opreste intr-un singur rand de capac, sub izolatori."""
    c = C(8, 40)
    soft_shadow(c, 4, 38, 4, 1.2)
    for y in range(9, 36):  # teava, mai groasa spre baza
        if y > 26:
            c.rect(2, y, 4, 1, GALV[1] if y == 27 else GALV[2])  # randul 27 = flansa mansonului
            if y > 27:
                c.put(2, y, GALV[3])
                c.put(5, y, IRON[2])
        else:
            c.rect(3, y, 2, 1, GALV[2])
            c.put(3, y, GALV[3])
            c.put(4, y, IRON[3])
    c.put(3, 9, GALV[4])  # capacul: un singur rand, mai luminos
    c.put(4, 9, GALV[3])
    for y in range(12, 26, 4):  # colierele
        c.rect(3, y, 2, 1, GALV[1])
    line(c, 0, 12, 7, 9, GALV[3], 1)  # bratul, in perspectiva
    line(c, 0, 13, 7, 10, GALV[1], 1)
    footing(c, 1, 36, 6)
    for (x, y) in LANE_INS.values():  # inainte de contur
        ribbed_pin(c, x, y)
    c.put(1, 11, IRON[1])  # pinii scurti, intre portelan si brat
    c.put(6, 8, IRON[1])
    outline_trace(c, STEEL_LINE)
    return c


# ---------------------------------------------------------------------------------------------
# stalpisorul de pe pod (5 x 23)


def prop_pylon_post():
    """Stalpisorul de pe balustrada podului (5x23): teava scurta cu colier, pe o placa nituita cu doua consolele, un
    izolator nervurat in varf (sapca, fusta, gat, fusta, pin), cu ram de contur. Fara umbra mare: sta pe pod."""
    c = C(5, 23)
    c.rect(1, 6, 3, 13, GALV[2])
    c.rect(1, 6, 1, 13, GALV[3])
    c.rect(3, 6, 1, 13, IRON[2])
    c.rect(1, 6, 3, 1, GALV[3])  # capacul
    c.rect(1, 12, 3, 1, GALV[1])  # colierul
    c.put(0, 19, IRON[2])  # consolele
    c.put(4, 19, IRON[1])
    c.rect(0, 20, 5, 2, IRON[2])
    c.rect(0, 20, 5, 1, GALV[3])
    c.put(1, 21, GALV[4])  # niturile
    c.put(3, 21, IRON[0])
    # izolatorul nervurat, desenat inainte de contur; randul 0 ramane liber pentru ramul de deasupra
    c.put(2, 1, CREAM[4])  # sapca
    for dx, col in zip((1, 2, 3), (CREAM[4], CREAM[3], CREAM[2])):  # prima fusta
        c.put(dx, 2, col)
    c.put(2, 3, CREAM[0])  # gatul
    for dx, col in zip((1, 2, 3), (CREAM[3], CREAM[2], CREAM[1])):  # a doua fusta
        c.put(dx, 4, col)
    c.put(2, 5, IRON[1])  # pinul
    outline_trace(c, STEEL_LINE)
    return c


# ---------------------------------------------------------------------------------------------
# cristalul de pe rau (2 x 18 x 16)

CRYS_W, CRYS_H = 18, 16
WATERLINE = 14  # randul liniei apei, pe fiecare cadru
CRYS_LINE = (22, 24, 84, 255)  # conturul cristalului: indigo, nu maro (lumina albastra se simte pana la margine)
LOG_TOP = 11  # bustenul are trei randuri (11-13); cristalele stau pe randurile 1-10, cu randul 0 pentru conturul varfului


def _facet_rows(c, rows, tones):
    """Un cristal din randuri (y, x0, x1): fateta stanga lumina, fateta dreapta in umbra, iar la cele de 5 pixeli un
    mijloc. `tones` = (lumina, mijloc, umbra, adanc). Latimea 1-2 ia lumina si umbra, fara mijloc."""
    for y, x0, x1 in rows:
        w = x1 - x0 + 1
        for x in range(x0, x1 + 1):
            if w == 1:
                tone = tones[1]
            elif w == 2:
                tone = tones[0] if x == x0 else tones[2]
            elif w == 3:
                tone = tones[0] if x == x0 else (tones[1] if x == x0 + 1 else tones[2])
            elif w == 4:
                tone = tones[0] if x < x0 + 2 else tones[2]
            else:
                tone = tones[0] if x < x0 + 2 else (tones[1] if x == x0 + 2 else tones[2])
            c.put(x, y, tone)
        if w >= 3:
            c.put(x1, y, tones[3])


def _crystal_layer():
    """Cele trei cristale si ciobul, fara bustean (conturul indigo se traseaza peste aceste randuri). Toate se opresc pe
    randul 10; varful celui mare e la randul 1, ca sa-i ramana loc ramului de deasupra."""
    k = C(CRYS_W, CRYS_H)
    blue = (CRYS[3], CRYS[2], CRYS[1], CRYS[0])
    vio = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    # cel din stanga, violet, inclinat spre stanga
    _facet_rows(k, [(2, 3, 3), (3, 3, 4), (4, 3, 5), (5, 3, 5), (6, 4, 6), (7, 4, 6), (8, 5, 7), (9, 5, 7), (10, 5, 7)], vio)
    # cel din dreapta, mai scund, violet, inclinat spre dreapta
    _facet_rows(k, [(4, 15, 15), (5, 14, 15), (6, 13, 15), (7, 13, 15), (8, 12, 14), (9, 12, 14), (10, 12, 14)], vio)
    # cristalul mare, la mijloc, albastru: varf de 1 px la randul 1
    _facet_rows(k, [(1, 9, 9), (2, 9, 10), (3, 8, 10), (4, 8, 11), (5, 8, 11), (6, 8, 11), (7, 8, 11), (8, 8, 11),
                    (9, 8, 11), (10, 8, 11)], blue)
    # un ciob mic, in picioare, pe capatul bustenului
    _facet_rows(k, [(8, 1, 1), (9, 1, 2), (10, 1, 2)], blue)
    return k


def _paste(dst, src):
    for y in range(src.h):
        for x in range(src.w):
            if src.px[y][x][3]:
                dst.put(x, y, src.px[y][x])


def _driftwood():
    """Bucata de bustean pe care stau cristalele: trei randuri vizibile (11-13), mai deschis sus, mai adanc jos, cu doua
    dungi de scoarta pe randul din mijloc; capatul taiat din stanga (x1-2) arata inelul: o margine deschisa in jurul unui
    miez mai intunecat. Un cioc de creanga iese pe dreapta. Conturul intai, apoi apa (ca bustenul de aur)."""
    w = C(CRYS_W, CRYS_H)
    for x in range(3, 17):
        w.put(x, 11, WEATHERED[2])
        w.put(x, 12, WEATHERED[1])
        w.put(x, 13, WEATHERED[0])
    for x in (7, 12):  # doua dungi de scoarta pe randul din mijloc
        w.put(x, 12, WEATHERED[0])
        w.put(x + 1, 12, WEATHERED[0])
    w.put(5, 11, WEATHERED[3])  # o pata de lumina pe muchia de sus, spre stanga (lumina din stanga-sus)
    # capatul taiat: inelul deschis in jurul miezului
    for x, y in ((1, 11), (2, 11), (1, 12), (1, 13), (2, 13)):
        w.put(x, y, WEATHERED[4])
    w.put(2, 12, WEATHERED[2])
    w.put(16, 10, WEATHERED[2])  # ciocul de creanga
    outline_trace(w)
    return in_water(w, WATERLINE)  # ca bustenul de aur: conturul intai, apoi apa


def _alpha_at(d):
    """Aureola cristalului: 110 la distanta 1 de cel mai apropiat pixel de cristal (inclusiv conturul indigo), 55 la 2, 22
    la 3, apoi nimic; intre ele, liniar (pe diagonala, d = 1,41, iese ~85)."""
    for (d0, a0), (d1, a1) in (((1.0, 110.0), (2.0, 55.0)), ((2.0, 55.0), (3.0, 22.0)), ((3.0, 22.0), (3.6, 0.0))):
        if d <= d1:
            return int(a0 + (a1 - a0) * (max(d, d0) - d0) / (d1 - d0))
    return 0


def _crystal_frame(phase):
    """Un cadru de 18x16. `phase` 0 = aprins (dunga, miez, scanteie intreaga, aureola plina), 1 = stins (fara dunga, miezul si
    scanteia mai slabe, aureola ~70%); inelul de apa se muta."""
    img = _driftwood()
    k = _crystal_layer()
    # conturul indigo al cristalelor: doar pe transparent sau peste conturul maro al bustenului, nu peste lemnul insusi
    for y in range(CRYS_H):
        for x in range(CRYS_W):
            if k.px[y][x][3] == 0 and (img.px[y][x][3] == 0 or img.px[y][x] == OUTLINE):
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < CRYS_W and 0 <= ny < CRYS_H and k.px[ny][nx][3] == 255:
                        img.px[y][x] = CRYS_LINE
                        break
    _paste(img, k)
    # aureola: bazata pe distanta fiecarui pixel transparent pana la cel mai apropiat pixel de cristal (miez sau contur
    # indigo), doar pe randurile 0-13 (sub ele e apa si spuma). Cade moale pe apa inchisa a raului si chiar o lumineaza.
    crystal_px = [
        (x, y) for y in range(CRYS_H) for x in range(CRYS_W) if k.px[y][x][3] == 255 or img.px[y][x] == CRYS_LINE
    ]
    for y in range(WATERLINE):
        for x in range(CRYS_W):
            if img.px[y][x][3] != 0:
                continue
            d = min(math.hypot(x - px, y - py) for px, py in crystal_px)
            a = int(_alpha_at(d) * (1.0 if phase == 0 else 0.7))  # aureola respira odata cu miezul
            if a >= 8:
                img.put(x, y, (CRYS_GLOW[0], CRYS_GLOW[1], CRYS_GLOW[2], a))
    # lumina cade si pe fata bustenului (o tenta slaba spre albastru), fara conturul lui
    for y in range(LOG_TOP, WATERLINE):
        for x in range(CRYS_W):
            p = img.px[y][x]
            if p[3] == 255 and p != OUTLINE and p != CRYS_LINE:
                img.px[y][x] = mix(p, CRYS[3], 0.14)
    # linia apei: spuma se domoleste (FOAM[2], 235), iar sub ea, pe randul 15, inelul de apa, translucid, se muta
    for x in range(CRYS_W):
        if img.px[WATERLINE][x][0] > 220:  # spuma alba de la linia apei -> o spuma mai moale
            img.px[WATERLINE][x] = (FOAM[2][0], FOAM[2][1], FOAM[2][2], 235)
    ring = (FOAM[3][0], FOAM[3][1], FOAM[3][2])
    for x in range(CRYS_W):
        on = (x + 2 * phase) % 5 in (0, 1)
        img.px[CRYS_H - 1][x] = (ring[0], ring[1], ring[2], 130 if on else 0)
    # apa reflecta cristalul: spuma de pe randul 14 si pixelii inelului de pe randul 15, sub buchet (x 3..15), se
    # amesteca 45% spre albastrul-violet
    for y in (WATERLINE, CRYS_H - 1):
        for x in range(3, 16):
            p = img.px[y][x]
            if p[3] > 0:
                q = mix(p, CRYS[3], 0.45)
                img.px[y][x] = (q[0], q[1], q[2], p[3])
    # pulsul (jocul schimba cadrele la 0,45 s): cadrul 0 e cel aprins, cadrul 1 doar mai stins, pe loc, fara nimic care sa sara.
    # Aprins: scanteia de la (14,2) cu crucea intreaga, o dunga luminata pe fateta stanga a cristalului mare (x8, randurile
    # 3-4) si un miez de 1 px pe mijlocul lui (x9, randurile 3-8). Stins: nicio dunga, doar centrul scanteii mai slab, iar
    # miezul coboara la o treapta peste fateta (ramane acolo, ca sa nu para ca a disparut cristalul).
    sx, sy = 14, 2
    if phase == 0:
        img.put(sx, sy, (240, 246, 255, 255))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if img.px[sy + dy][sx + dx][3] < 200:
                img.px[sy + dy][sx + dx] = (CRYS_GLOW[0] + 50, CRYS_GLOW[1] + 50, 255, 180)
        img.put(8, 3, CRYS[4])
        img.put(8, 4, (226, 236, 255, 255))
        core = CORE_BRIGHT
    else:
        img.put(sx, sy, mix(CRYS[3], CRYS[4], 0.4))
        core = CORE_DIM
    for y in range(3, 9):
        img.put(9, y, core)
    return img


def prop_river_crystal():
    """Cristalul de pe rau (36x16 = 2 cadre de 18x16): un buchet de trei cristale albastru-violet pe o bucata de bustean
    care pluteste, cu aureola moale si inelul de apa. Cele doua cadre sunt un PULS (jocul le schimba la 0,45 s): cadrul 1 e aprins
    (dunga, miezul, scanteia intreaga), cadrul 2 doar mai stins pe loc; inelul de apa se muta. Ancora: jos-mijloc, pe cadru."""
    sheet = C(CRYS_W * 2, CRYS_H)
    for i in range(2):
        f = _crystal_frame(i)
        for y in range(f.h):
            for x in range(f.w):
                sheet.px[y][i * CRYS_W + x] = f.px[y][x]
    return sheet


SPRITES = {
    "prop_pylon_tall": prop_pylon_tall,
    "prop_pylon_lane": prop_pylon_lane,
    "prop_pylon_post": prop_pylon_post,
    "prop_river_crystal": prop_river_crystal,
}
SIZES = {
    "prop_pylon_tall": (16, 67),
    "prop_pylon_lane": (8, 40),
    "prop_pylon_post": (5, 23),
    "prop_river_crystal": (36, 16),
}

# punctele firului, in pixeli de foaie (originea = coltul stanga-sus al sprite-ului); "near" = capatul din fata (mai jos)
WIRES = {
    "prop_pylon_tall": {k: (x, y + 6) for k, (x, y) in TALL_ARMS.items()},  # cleama de jos a fiecarui lant
    "prop_pylon_lane": dict(LANE_PINS),  # varful portelanului
    "prop_pylon_post": {"top": (2, 1)},
}


# ---------------------------------------------------------------------------------------------
# previzualizarea (PIL; doar in scratchpad)

GROUND = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites", "prop_dam_ground.png")
POLE = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites", "prop_wire_pole.png")
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"
# unde stau in lumea 2 (TycoonConfig.WORLDS[2].pylons). DamTownController.drawFitted pune imaginea cu AnchorPoint (0.5, 1)
# in (x, y): deci y e CHIAR baza sprite-ului (nu y + h), iar x e mijlocul; 3 pixeli de lume pe pixel de arta
REAL_PLACES = (
    ("prop_pylon_post", 2190 / 3, 1100 / 3),
    ("prop_pylon_post", 2262 / 3, 1100 / 3),
    ("prop_pylon_tall", 2360 / 3, 1070 / 3),
    ("prop_pylon_lane", 2450 / 3, 1300 / 3),
)
WATER_TILE = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites", "water_tile.png")
GOLD = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites", "treasure_golden_water.png")
RIVER = (33, 72, 102, 255)


def _img(c):
    from PIL import Image

    im = Image.new("RGBA", (c.w, c.h))
    im.putdata([c.px[y][x] for y in range(c.h) for x in range(c.w)])
    return im


def _font(size=8):
    from PIL import ImageFont

    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def _river(w, h):
    """O bucata de rau: albastru intunecat cu cateva dungi mai deschise (ca raul din joc, la scara pixelilor de arta)."""
    from PIL import Image

    im = Image.new("RGBA", (w, h), RIVER)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if (x * 7 + y * 13) % 29 == 0 and (x + y) % 3 == 0:
                px[x, y] = (58, 107, 133, 255)
            elif (x * 5 + y * 11) % 31 == 0:
                px[x, y] = (40, 84, 115, 255)
    return im


def _wire(im, a, b, color, sag_frac=0.03):
    """Firul dintre doi izolatori, cu sageata la mijloc, pe imaginea 1x (asa l-ar desena codul)."""
    (xa, ya), (xb, yb) = a, b
    sag = sag_frac * abs(xb - xa)
    n = max(2, int(abs(xb - xa)))
    for i in range(n + 1):
        t = i / n
        im.putpixel((int(round(xa + (xb - xa) * t)), int(round(ya + (yb - ya) * t + sag * 4 * t * (1 - t)))), color)


def build_preview(out):
    from PIL import Image, ImageDraw

    f8 = _font(8)
    sprites = {n: _img(fn()) for n, fn in SPRITES.items()}
    tall, lane, post, crystal = (sprites[n] for n in ("prop_pylon_tall", "prop_pylon_lane", "prop_pylon_post", "prop_river_crystal"))
    pole = Image.open(POLE).convert("RGBA")
    sheet = Image.new("RGBA", (1560, 1010), (40, 44, 52, 255))
    d = ImageDraw.Draw(sheet)

    def grass(x, y, w, h):
        d.rectangle([x, y, x + w - 1, y + h - 1], fill=GRASS_BG)

    def put(im, x, y, k=1):
        big = im if k == 1 else im.resize((im.width * k, im.height * k), Image.NEAREST)
        sheet.alpha_composite(big, (int(x), int(y)))

    def text(x, y, t):
        d.text((x, y), t, font=f8, fill=(235, 235, 225, 255))

    # --- A: x4 pe iarba, ancora jos-mijloc la o linie comuna
    text(12, 8, "A  X4, ON GRASS")
    grass(12, 24, 470, 300)
    base_y = 24 + 288
    x = 28
    for name, im in (("prop_pylon_tall", tall), ("prop_pylon_lane", lane), ("prop_pylon_post", post), ("prop_river_crystal", crystal)):
        put(im, x, base_y - im.height * 4, 4)
        text(x, base_y + 10, f"{im.width}x{im.height}")
        x += im.width * 4 + 26
    text(28, 24 + 4, "TALL  LANE  POST  CRYSTAL (2 FRAMES)")
    # --- B: cristalul pe apa jocului (water_tile.png), x8, ambele cadre, langa bustenul de aur ca etalon
    text(500, 8, "B  CRYSTAL ON THE GAME WATER, X8 (GOLD LOG FOR COMPARISON)")
    tile = Image.open(WATER_TILE).convert("RGBA")
    pw, ph = 18 * 2 + 2, 16 + 2
    water = Image.new("RGBA", (pw, ph))
    for ty in range(0, ph, tile.height):
        for tx in range(0, pw, tile.width):
            water.alpha_composite(tile, (tx, ty))
    water = water.crop((0, 0, pw, ph))
    rv = water.resize((pw * 8, ph * 8), Image.NEAREST)
    sheet.alpha_composite(rv, (500, 24))
    for i in range(2):
        fr = crystal.crop((i * 18, 0, i * 18 + 18, 16))
        put(fr, 500 + 8 + i * 18 * 8, 24 + 8, 8)
    text(508, 24 + ph * 8 + 6, "FRAME 1")
    text(508 + 144, 24 + ph * 8 + 6, "FRAME 2")
    gold = Image.open(GOLD).convert("RGBA")  # etalonul: bustenul de aur, pe aceeasi apa
    gw = Image.new("RGBA", (gold.width + 2, gold.height + 2))
    for ty in range(0, gw.height, tile.height):
        for tx in range(0, gw.width, tile.width):
            gw.alpha_composite(tile, (tx, ty))
    gw = gw.crop((0, 0, gold.width + 2, gold.height + 2))
    gw.alpha_composite(gold, (1, 1))
    sheet.alpha_composite(gw.resize((gw.width * 8, gw.height * 8), Image.NEAREST), (500, 24 + ph * 8 + 30))
    text(500, 24 + ph * 8 + 30 + gw.height * 8 + 6, "GOLDEN LOG (TREASURE_GOLDEN_WATER)")
    # --- C: scara: stalpul de lemn al satului langa cei de fier, 1x apoi x3
    text(12, 344, "C  SCALE: WIRE POLE, TALL, LANE, POST   1X | X3 (IN GAME)")
    row = [("pole", pole), ("tall", tall), ("lane", lane), ("post", post)]
    grass(12, 360, 150, 90)
    x = 22
    for _n, im in row:
        put(im, x, 360 + 80 - im.height, 1)
        x += im.width + 12
    grass(180, 360, 330, 220)
    x = 190
    for _n, im in row:
        put(im, x, 360 + 210 - im.height * 3, 3)
        x += im.width * 3 + 22
    # --- D: firele: doua turnuri si doi stalpi de poteca, 1x apoi x3
    text(12, 600, "D  WIRES BETWEEN ATTACH POINTS (NEAR-NEAR, FAR-FAR), X3")
    demo = Image.new("RGBA", (270, 120), GRASS_BG)
    gap = 90
    for (img, ox, oy) in ((tall, 14, 120 - 67 - 4), (tall, 14 + gap, 120 - 67 - 4)):
        demo.alpha_composite(img, (ox, oy))
    names = list(WIRES["prop_pylon_tall"])
    for key in names:
        ax, ay = WIRES["prop_pylon_tall"][key]
        col = IRON[0] if "near" in key else IRON[1]
        _wire(demo, (14 + ax, 120 - 71 + ay), (14 + gap + ax, 120 - 71 + ay), col)
    lx = 14 + gap + 40
    for i in range(2):
        demo.alpha_composite(lane, (lx + i * 70, 120 - 40 - 2))
    for key, col in (("near", IRON[0]), ("far", IRON[1])):
        ax, ay = WIRES["prop_pylon_lane"][key]
        _wire(demo, (lx + ax, 120 - 42 + ay), (lx + 70 + ax, 120 - 42 + ay), col)
    sheet.alpha_composite(demo.resize((demo.width * 3, demo.height * 3), Image.NEAREST), (12, 618))
    # --- E: la locul lor pe pamantul lumii 2 (1x pe crop, apoi x4)
    ground = Image.open(GROUND).convert("RGBA")
    gx0, gy0, gx1, gy1 = 695, 280, 855, 440
    crop = ground.crop((gx0, gy0, gx1, gy1))
    for name, cx, by in REAL_PLACES:
        im = sprites[name]
        crop.alpha_composite(im, (int(round(cx - im.width / 2)) - gx0, int(round(by)) - im.height - gy0))
    text(1010 - 500 + 500, 8, "E  AT THEIR REAL PLACES ON THE WORLD 2 GROUND, X4")
    big = crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST)
    sheet.alpha_composite(big, (840, 24))
    text(840, 24 + big.height + 8, "BRIDGE POSTS, RIVER PYLON, LANE PYLON (TYCOONCONFIG.WORLDS[2].PYLONS)")
    sheet.convert("RGB").save(out)


def main():
    out = DEFAULT_OUT
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")
    for name, pts in WIRES.items():
        print(f"  wires {name}: {pts}")
    print("  config x3 intreg: river_pylon h=201; bridge_pylon_w/_e w=15 h=69 (lane_pylon 24x120 e deja exact)")
    build_preview(os.path.join(out, "pylons_preview.png"))
    print("  preview:", os.path.join(out, "pylons_preview.png"))


if __name__ == "__main__":
    main()
