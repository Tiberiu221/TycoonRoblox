#!/usr/bin/env python3
"""[D75, lotul A4, grupul "halls"] Cladirile mari si speciale ale barajului (Era 4, lumea 2), care pana acum imprumutau
desenele Erelor 1-3. Barajul e de piatra (varianta A din a0_dam.py), curentul se vinde pe stalpi de otel unui orasel de
peste rau, deci materialele sunt: piatra calda cioplita (DSTONE, aceeasi cu zidul si cu Dam Town), beton turnat, tabla
galvanizata, otel nituit, portelan, cupru si alama, lemn gudronat; linia cristalelor straluceste albastru-violet (CRYS /
CRYS_VIO din a1_pylons). Un pas dupa Wire Works (caramida, tabla, fier nituit): aici betonul si piatra tin locul caramizii.

  prop_relay_station  64x48  "Relay Station" (inlocuieste cuptorul de cupru): casa-pod peste capatul canalului. Apa vine de
                             sus, prin mijloc (coloanele 21-41, cele ale canalului copt in sol), trece pe sub o pasarela de
                             otel cu roata stavilei (butuc de alama) si se opreste la grilajul unei case de beton cu un
                             hublou de alama aprins, cu roata turbinei in silueta. Jos, in mijloc, o usa-galerie in arc de
                             piatra (interior intunecat, podea de pamant batut, prag de alama). Stanga: hala de primire cu
                             usa de rulou ridicata pe jumatate si o macara cu cangea (de acolo vin butoaiele si cablul).
                             Dreapta: hala de comutare, cu un portal de otel pe acoperis (panou de tabla, trei siruri de
                             izolatori de portelan) si bara de cupru care pleaca spre stalp prin trecerea de portelan.
                             Nu are horn si nu scoate fum.
  prop_switch_house   64x48  "Switch House" (inlocuieste Depoul): cumparatorul de curent al orasului. Piatra si beton,
                             cu un turn de contor in dreapta centrului (usa de vanzare e la +20 px lume): fronton in
                             trepte cu un panou-contor cu rama de alama si patru coloane de lampi calde, un catarg cu bec
                             in varf, usa dubla in arc, cu luminator si felinare cu brate de fier; aripa lunga in stanga cu
                             trei ferestre calde in arc si trei izolatori de portelan pe parapet; pe anexa joasa din
                             dreapta, un transformator cu radiator si trei borne de portelan.
  prop_canteen        64x48  "Canteen" (inlocuieste taverna Erei 1): casa mare a orasului, cald si locuita. Parter de
                             piatra calda, etaj de barne si tencuiala iesit in consola (obloane, ladite cu flori), acoperis de
                             olane rosii cu lucarna, horn de piatra, un portic de lemn peste usa, doua ferestre mari
                             aprinse cu oameni la masa, un butoi si lazi, firma-bol cu aburi.
  prop_crystal_kiln   64x48  "Kiln" (inlocuieste Power House): cuptor ghemuit in forma de stup, din caramida refractara
                             cu cercuri de fier, gura boltita aprinsa violet-alb, cos inalt de otel separat, in dreapta,
                             legat printr-o teava; un vagonet cu cristal brut la stanga, lingouri violete pe sina la dreapta.
                             Banda de zid de la randurile 10-15 (sub varful cupolei) ramane curata: acolo pune jocul numele
                             "Kiln" (firma coboara 30 px lume = 10 randuri de arta sub varf si are 18 px lume = 6 randuri).
  prop_crystal_shed   40x32  "Crystal Shed" (inlocuieste Battery Shed): magazie de piatra cu acoperis-bolta de tabla si, pe
                             creasta, o coroana de cristale intr-un guler de otel; in fata, o deschidere boltita cu un raft
                             si un maldar de cristale albastre si violete, un cos cu cristale in stanga si un vagonet in dreapta.
                             Silueta (bolta + varfuri) se citeste si aproape neagra.
  prop_dam_bell       40x56  "Dam Bell" (inlocuieste clopotul Works): clopotnita-perete de piatra ("espadana"), lata si
                             masiva, cu un arc mare, deschis (iarba se vede prin el), in care atarna un clopot de otel
                             galvanizat cu brau si limba de alama; contraforturi, benzi de otel, placuta cu barajul, iar in
                             varf o coroana de cristale albastru-violet intr-un guler de otel, plus doi pinioni cu cristale
                             pe colturile cornisei. Nu seamana cu cadrul de barne (Landing), cu plinta de caramida (Moara),
                             cu turnul de zabrele (Works) si nici cu turnul subtire Old Bells.

Aceleasi reguli ca restul conductei: culori din palette.ramp(), umbra moale, contur trasat automat (outline_trace),
lumina din stanga-sus, niciodata negru pur. Scrie DOAR in --out (implicit folderul de lucru (scripts/art/scratch.py)), nu in assets/sprites.

Rulare: python3 scripts/art/a4_halls.py [--out DIR] [--only NUME]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, FOAM, WATER, OUTLINE, ramp, mix  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import WARM, PLANK, STEEL, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402
import a1_town as T  # noqa: E402
import a1_pylons as P  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a4")
SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---------------------------------------------------------------------------------------------
# paleta: familia barajului (piatra calda, tabla galvanizata, cristalul) + betonul si ce mai e nevoie

DSTONE = T.DSTONE  # piatra calda cioplita a zidului si a orasului
GALV = P.GALV  # tabla galvanizata: gri-albastrui luminos
IRON = W.IRON
BRASS = W.BRASS
COPPER, VERDIGRIS, EMBER = M.COPPER, M.VERDIGRIS, M.EMBER
CRYS, CRYS_VIO, CRYS_GLOW, CRYS_LINE = P.CRYS, P.CRYS_VIO, P.CRYS_GLOW, P.CRYS_LINE
TIMBER = T.TIMBER
ROOF_TILE = T.ROOF_TILE
PLASTER_SAND, PLASTER_CREAM = T.PLASTER_SAND, T.PLASTER_CREAM
RED_F, YEL_F, BLUE_F, WHITE_F, PINK_F = T.RED_F, T.YEL_F, T.BLUE_F, T.WHITE_F, T.PINK_F
LEAF = T.LEAF
CONC = ramp(206, 0.06, 0.72, steps=6, hue_shift=5, val_span=0.50)  # beton turnat: gri rece, mai deschis decat IRON
CONC_WARM = ramp(40, 0.09, 0.66, steps=6, hue_shift=5, val_span=0.48)  # beton cu praf de piatra calda (cladirile orasului), o treapta mai inchis ca sa nu bata usa de vanzare
FIREBRICK = ramp(34, 0.28, 0.62, steps=6, hue_shift=6, val_span=0.46)  # caramida refractara: galben-ocru palid
CANAL = ramp(207, 0.62, 0.46, steps=5, hue_shift=8, val_span=0.34)  # apa canalului, ca cea copta in sol
GLOW_VIO = (150, 100, 255)  # lumina cristalului topit (aureole translucide)
HOT = [(52, 30, 120, 255), (96, 58, 196, 255), (150, 104, 255, 255), (206, 176, 255, 255), (246, 238, 255, 255)]
SKIN_T = (226, 168, 128, 255)
SKIN_L = (244, 196, 156, 255)
GLASS_PALE = ramp(200, 0.30, 0.86, steps=5, hue_shift=6, val_span=0.20)
INK = (58, 40, 30, 255)
SIGNAL = W.SIGNAL
CAUTION = (236, 196, 52, 255)


def clamp(v, a, b):
    return max(a, min(b, v))


# ---------------------------------------------------------------------------------------------
# bucati comune


def concrete(c, x, y, w, h, rng, tones=CONC, board=5):
    """Beton turnat in cofraje: fasii orizontale de `board` px cu rost mai inchis intre ele, gauri de tiranti la mijlocul
    fiecarei fasii, o granulatie rara. Lumina din stanga-sus: coloana din stanga mai deschisa, cea din dreapta in umbra."""
    c.rect(x, y, w, h, tones[3])
    for yy in range(y, y + h):
        k = (yy - y) % board
        for xx in range(x, x + w):
            t = 3
            if k == 0:
                t = 4 if yy > y else 3  # muchia de sus a fasiei, prinde lumina
            elif k == board - 1:
                t = 2
            if rng.n() < 0.07:
                t += rng.i(-1, 1)
            c.put(xx, yy, tones[clamp(t, 0, len(tones) - 1)])
    for yy in range(y + board - 1, y + h, board):  # rostul intre fasii
        c.rect(x, yy, w, 1, tones[1])
    for yy in range(y + 2, y + h, board):  # tirantii: gauri mici, din 9 in 9
        for xx in range(x + 3, x + w - 2, 9):
            c.put(xx, yy, tones[1])
    c.rect(x, y, 1, h, tones[4])
    c.rect(x + w - 1, y, 1, h, tones[1])
    c.rect(x + w - 2, y, 1, h, tones[2])


def galv(c, x, y, w, h, slope=0, crest=True):
    """Tabla galvanizata ondulata, dungi verticale deschis / inchis. `slope` = cu cati pixeli coboara spre dreapta."""
    for i in range(w):
        drop = int(round(slope * i / max(1, w - 1)))
        tone = GALV[3] if i % 3 == 0 else (GALV[2] if i % 3 == 1 else GALV[1])
        c.rect(x + i, y + drop, 1, h, tone)
        if crest:
            c.put(x + i, y + drop, GALV[4])
        c.put(x + i, y + drop + h - 1, GALV[0])


def coping(c, x, y, w, tones=DSTONE):
    """Coronament de piatra: un rand luminat, un rand de corp, o buza inchisa dedesubt."""
    c.rect(x, y, w, 1, tones[5])
    c.rect(x, y + 1, w, 1, tones[3])
    c.rect(x, y + 2, w, 1, tones[1])


def arch_fill(c, x0, x1, y_top, y_bot, fn):
    """Un arc intreg (semicerc deasupra, dreptunghi dedesubt) in coloanele x0..x1 si randurile y_top..y_bot. `fn(x, y)`
    da culoarea fiecarui pixel (sau None, ca sa-l lase)."""
    r = (x1 - x0 + 1) / 2.0
    cx = (x0 + x1 + 1) / 2.0
    spring = y_top + r
    for y in range(y_top, y_bot + 1):
        for x in range(x0, x1 + 1):
            if y < spring:
                dy = spring - (y + 0.5)
                dx = abs(x + 0.5 - cx)
                if dx * dx + dy * dy > r * r:
                    continue
            col = fn(x, y)
            if col is not None:
                c.put(x, y, col)


def stone_arch(c, x0, x1, y_top, y_bot, inner, ring=1, tones=DSTONE):
    """Arc cu ghirlanda de piatra de `ring` px in jur: intai arcul mare, in tonuri de piatra (stanga mai deschis), apoi golul."""
    arch_fill(
        c, x0 - ring, x1 + ring, y_top - ring, y_bot,
        lambda x, y: tones[4] if x < (x0 + x1) // 2 else tones[3],
    )
    arch_fill(c, x0, x1, y_top, y_bot, inner)


def glow(c, cx, cy, rx, ry, rgb, a0=60, steps=4):
    """Aureola moale: elipse translucide concentrice, care se aduna spre centru. Doar peste pixeli deja desenati (nu
    umple golurile din jurul siluetei, ca sa nu strice conturul)."""
    for k in range(steps):
        t = 1.0 - k / steps
        a = int(a0 * (0.35 + 0.65 * (1 - t)) / steps * 1.8)
        for yy in range(int(cy - ry * t) - 1, int(cy + ry * t) + 2):
            for xx in range(int(cx - rx * t) - 1, int(cx + rx * t) + 2):
                if ((xx - cx) / max(rx * t, 0.5)) ** 2 + ((yy - cy) / max(ry * t, 0.5)) ** 2 <= 1:
                    if 0 <= xx < c.w and 0 <= yy < c.h and c.px[yy][xx][3] == 255:
                        c.put(xx, yy, (rgb[0], rgb[1], rgb[2], a))


def crystal_spike(c, cx, base, h, w=3, tones=None, lean=0):
    """Un cristal in picioare: baza lata de `w` px, se ingusteaza in trepte spre un varf de 1 px; fateta din stanga luminata,
    cea din dreapta in umbra, un rand de miez mai deschis. `tones` = (lumina, mijloc, umbra, adanc). `lean` = cu cati
    pixeli se muta varful spre dreapta (negativ = stanga). `base` = randul de jos."""
    tones = tones or (CRYS[3], CRYS[2], CRYS[1], CRYS[0])
    for i in range(h):
        y = base - i
        t = i / max(1, h - 1)
        ww = max(1, round(w * (1 - t * 0.78)))
        x0 = cx - ww // 2 + int(round(lean * t))
        for k in range(ww):
            x = x0 + k
            if ww == 1:
                tone = tones[1]
            elif ww == 2:
                tone = tones[0] if k == 0 else tones[2]
            else:
                tone = tones[0] if k == 0 else (tones[1] if k < ww - 1 else tones[2])
            c.put(x, y, tone)
        if ww >= 3:
            c.put(x0 + ww - 1, y, tones[3])
    c.put(cx + int(round(lean)), base - h + 1, mix(tones[0], (255, 255, 255, 255), 0.55))


def porcelain(c, x, y, h=9):
    """Un izolator mare de portelan pe pin de fier (`h` randuri, axa la coloana x, varful la y): capac de alama, un gat,
    doua talere suprapuse (3 si 5 px), fiecare cu fata de sus luminata si o buza inchisa dedesubt, apoi pinul si placa
    de baza. Lumina din stanga: stanga crem deschis, dreapta mai inchisa."""
    dk = mix(CREAM[1], INK, 0.40)
    c.put(x, y, BRASS[3])
    c.put(x - 1, y + 1, BRASS[4])
    c.put(x, y + 1, BRASS[2])
    c.put(x + 1, y + 1, BRASS[1])
    for dy, hw, under in ((2, 1, False), (3, 1, True), (4, 2, False), (5, 2, True)):
        for xx in range(x - hw, x + hw + 1):
            if under:
                c.put(x if False else xx, y + dy, CREAM[1] if xx < x else dk)
            else:
                c.put(xx, y + dy, CREAM[4] if xx < x else (CREAM[3] if xx == x else CREAM[2]))
    for yy in range(y + 6, y + h - 1):
        c.put(x, yy, IRON[2])
    c.rect(x - 1, y + h - 1, 3, 1, IRON[1])
    c.put(x - 1, y + h - 1, IRON[3])


def insulator_string(c, x, y, n=4):
    """Un sir de izolatori atarnat: `n` talere de portelan de 3 px (un rand fiecare) legate printr-o tija de fier de 1 px, clema
    de fier sus si cea de alama jos. Axa la coloana x, clema de sus la randul y; sirul are 2 * n + 1 randuri. Lumina din
    stanga: stanga crem deschis, dreapta mai inchisa."""
    dk = mix(CREAM[1], INK, 0.40)
    c.put(x, y, IRON[3])
    for i in range(n):
        yy = y + 1 + 2 * i
        c.put(x - 1, yy, CREAM[4])
        c.put(x, yy, CREAM[3])
        c.put(x + 1, yy, dk)
        c.put(x, yy + 1, IRON[1])
    c.put(x, y + 2 * n + 1, BRASS[3])
    c.put(x - 1, y + 2 * n + 1, BRASS[4])
    c.put(x + 1, y + 2 * n + 1, BRASS[1])


def lamp_post_bulb(c, x, y, tone=WARM):
    """Un bec cu bratul lui (3x3): lumina calda."""
    c.put(x, y, tone[4])
    c.put(x - 1, y, tone[2])
    c.put(x + 1, y, tone[2])
    c.put(x, y + 1, tone[3])
    c.put(x, y - 1, IRON[1])


def plain_window(c, x, y, w, h, rng, tones=WARM, mullion=True, frame=INK):
    """Fereastra aprinsa dintr-o casa: rama de 1 px, sticla calda cu degrade (sus mai pal), un montant, strop de lumina."""
    c.rect(x - 1, y - 1, w + 2, h + 2, frame)
    for yy in range(h):
        t = 4 if yy < h * 0.3 else (3 if yy < h * 0.6 else 2)
        c.rect(x, y + yy, w, 1, tones[t])
    if mullion and w >= 4:
        c.rect(x + w // 2, y, 1, h, TIMBER[1])
    if h >= 5:
        c.rect(x, y + h // 2, w, 1, TIMBER[1])
    c.put(x, y, (255, 250, 214, 255))




CRYSTAL_TONES = set(CRYS) | set(CRYS_VIO)


def outline_crystal(c):
    """Dupa outline_trace: conturul care inconjoara DOAR cristale devine indigo (ca la cristalul de pe rau din A1), nu maro;
    conturul care atinge si altceva ramane maro."""
    for y in range(c.h):
        for x in range(c.w):
            if c.px[y][x] != OUTLINE:
                continue
            kinds = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h:
                    p = c.px[ny][nx]
                    if p[3] == 255 and p != OUTLINE and p != CRYS_LINE:
                        kinds.append(p in CRYSTAL_TONES or p == (232, 238, 255, 255))
            if kinds and all(kinds):
                c.px[y][x] = CRYS_LINE
# ---------------------------------------------------------------------------------------------
# 1. Relay Station


def _canal_water(c, x0, x1, y0, y1, rng):
    """Apa canalului care curge in jos: baza, fire scurte verticale (curentul), umbra zidului din stanga pe primele
    doua coloane (lumina vine din stanga-sus)."""
    c.rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, CANAL[2])
    for _ in range(((x1 - x0 + 1) * (y1 - y0 + 1)) // 9):
        x, y = rng.i(x0, x1), rng.i(y0, y1 - 2)
        tone = CANAL[3] if rng.n() < 0.7 else CANAL[1]
        for k in range(rng.i(2, 4)):
            c.put(x, min(y + k, y1), tone)
    for yy in range(y0, y1 + 1):
        c.put(x0, yy, CANAL[1])
        c.put(x0 + 1, yy, CANAL[2] if yy % 2 else CANAL[1])
        c.put(x1, yy, CANAL[3] if yy % 3 else CANAL[2])


def prop_relay_station():
    c = C(64, 48)
    rng = Rng(7701)
    soft_shadow(c, 32, 45, 30, 2)

    # --- canalul: apa intra pe sus, la mijloc, intre doi pereti de piatra (cei copti in sol: coloanele 20 si 42)
    _canal_water(c, 21, 41, 0, 15, rng)
    for y in range(0, 17):  # fetele interioare, cu lumina din stanga-sus: peretele din stanga la umbra, cel din dreapta luminat
        c.put(20, y, DSTONE[1])
        c.put(42, y, DSTONE[3])

    # --- aripa din stanga: hala de primire, acoperis intr-o apa (mai jos la stanga, deasupra usii), perete de beton
    galv(c, 5, 15, 13, 7, slope=-4)  # coloana 5 la randul 15, coloana 17 la 11
    c.rect(5, 19, 13, 1, GALV[0])  # streasina
    concrete(c, 6, 20, 12, 21, rng)
    c.rect(6, 20, 12, 1, (0, 0, 0, 70))  # umbra streasinii pe perete
    c.rect(6, 21, 12, 1, (0, 0, 0, 30))
    # usa de rulou ridicata pe jumatate: sub lamele se vede interiorul cald, cu un butoi si un tambur de cablu
    c.rect(8, 26, 8, 15, IRON[0])
    c.rect(9, 28, 6, 13, (84, 58, 42, 255))
    c.rect(9, 28, 6, 3, WARM[1])  # lumina dinauntru, pe tavan
    # butoiul: doage de lemn cu doua cercuri de otel
    c.rect(9, 35, 4, 6, WOOD[2])
    c.rect(9, 35, 1, 6, WOOD[4])
    c.rect(12, 35, 1, 6, WOOD[0])
    c.rect(9, 36, 4, 1, STEEL[2])
    c.rect(9, 39, 4, 1, STEEL[1])
    # tamburul de cablu (doua flanse de lemn, spire de cupru la mijloc)
    c.rect(13, 37, 2, 4, WOOD[1])
    c.rect(13, 37, 1, 4, WOOD[3])
    c.put(14, 38, COPPER[3])
    c.put(14, 39, COPPER[2])
    # lamelele rulourii (sus): 5 randuri de otel galvanizat
    for k in range(5):
        c.rect(8, 26 + k, 8, 1, GALV[3] if k % 2 == 0 else GALV[2])
    c.rect(8, 26, 8, 1, GALV[4])
    c.rect(8, 31, 8, 1, GALV[0])
    c.rect(7, 25, 10, 1, IRON[1])  # cutia rulourii
    c.rect(7, 25, 1, 16, IRON[3])  # tocul din stanga
    c.rect(16, 25, 1, 16, IRON[0])
    # macaraua cu cangea: bratul de otel iese in stanga, sub streasina (de acolo vin butoaiele si cablul)
    c.rect(1, 23, 8, 2, GALV[3])
    c.rect(1, 23, 8, 1, GALV[4])
    c.rect(1, 25, 8, 1, IRON[0])
    c.rect(6, 21, 2, 2, IRON[1])  # consola de care e prins
    line(c, 3, 25, 7, 22, IRON[2], 1)  # contrafisa
    c.ellipse(2.5, 27.2, 1.2, 1.2, IRON[3])  # scripetele
    c.rect(2, 28, 1, 5, IRON[2])  # lantul
    c.rect(2, 28, 1, 1, IRON[4])
    c.rect(1, 33, 3, 1, BRASS[3])  # cangea
    c.put(1, 34, BRASS[2])
    c.put(3, 34, BRASS[1])
    # burlan de scurgere
    c.rect(17, 21, 1, 19, IRON[2])
    c.rect(17, 21, 1, 1, IRON[4])

    # --- aripa din dreapta: hala de comutare, parapet de beton, trei izolatori de portelan
    concrete(c, 45, 17, 15, 24, rng)
    c.rect(44, 14, 17, 3, DSTONE[3])  # parapet de piatra
    c.rect(44, 14, 17, 1, DSTONE[5])
    c.rect(44, 16, 17, 1, DSTONE[1])
    c.rect(45, 17, 15, 1, (0, 0, 0, 70))
    c.rect(45, 18, 15, 1, (0, 0, 0, 30))
    # cadrul de otel (portal) de pe acoperis: doi stalpi, o grinda, trei siruri de izolatori de portelan atarnate, iar bara
    # de cupru de sub ele pleaca spre dreapta, in sus, spre stalp
    for px in (46, 59):
        c.rect(px, 3, 2, 11, GALV[2])
        c.rect(px, 3, 1, 11, GALV[4])
    c.rect(46, 3, 15, 2, GALV[3])
    c.rect(46, 3, 15, 1, GALV[4])
    c.rect(46, 5, 15, 1, IRON[1])
    # panoul din spate al portalului, din tabla galvanizata (altfel sirurile, lipite unul de altul, lasa goluri pe randurile
    # tijelor, iar conturul le face o grila neagra): talerele de portelan se vad pe otel gri, nu pe cerneala
    c.rect(48, 6, 11, 7, GALV[1])
    for ix in (50, 53, 56):
        insulator_string(c, ix, 6, 3)
        for ry in (6, 8, 10, 12):  # pe randurile tijelor, de o parte si de alta a axei: tabla mai inchisa, in umbra sirului
            c.put(ix - 1, ry, GALV[0])
            c.put(ix + 1, ry, GALV[0])
    line(c, 50, 13, 56, 13, COPPER[3], 1)
    line(c, 56, 13, 60, 11, COPPER[3], 1)
    line(c, 50, 14, 56, 14, COPPER[1], 1)
    line(c, 56, 14, 60, 12, COPPER[1], 1)
    # trecerea de portelan prin care bara iese spre stalp: capac de alama sus, stanga crem deschis, dreapta mai inchisa
    c.rect(60, 9, 3, 1, BRASS[3])
    c.put(60, 9, BRASS[4])
    for yy in range(10, 13):
        c.put(60, yy, CREAM[4])
        c.put(61, yy, CREAM[3])
        c.put(62, yy, CREAM[2])
    # doua ferestre inguste, cu jaluzele de tabla, luminate palid
    for wx in (47, 53):
        c.rect(wx - 1, 21, 5, 12, IRON[1])
        c.rect(wx, 22, 3, 10, GLASS_PALE[2])
        c.rect(wx, 22, 1, 10, GLASS_PALE[4])
        for yy in range(23, 32, 3):
            c.rect(wx, yy, 3, 1, IRON[2])
    # usa de otel, cu banda de avertizare galben-inchis deasupra
    c.rect(54, 29, 6, 12, IRON[0])
    c.rect(55, 30, 4, 11, IRON[2])
    c.rect(55, 30, 1, 11, IRON[3])
    c.rect(55, 36, 4, 1, IRON[1])
    c.put(58, 35, BRASS[4])
    for k in range(6):
        c.put(54 + k, 27, CAUTION if k % 2 == 0 else IRON[0])
        c.put(54 + k, 28, CAUTION if k % 2 == 1 else IRON[0])

    # --- grilajul de la capatul canalului: bare verticale, apa se opreste in spuma
    c.rect(21, 11, 21, 5, CANAL[0])
    for x in range(21, 42, 2):
        c.rect(x, 11, 1, 5, IRON[3] if x % 4 == 1 else IRON[2])
        c.put(x, 11, IRON[4])
    c.rect(21, 11, 21, 1, IRON[3])
    c.rect(21, 15, 21, 1, IRON[1])
    for x in range(22, 41, 3):
        c.put(x, 10, FOAM[4])
        c.put(x + 1, 10, FOAM[3])
        c.put(x, 9, WATER[4])

    # --- casa din mijloc: gate-house, beton cu colturi de piatra, coronament, hublou aprins, cap de tunel jos
    concrete(c, 18, 19, 27, 22, rng)
    coping(c, 17, 16, 29)
    c.rect(18, 19, 27, 1, (0, 0, 0, 60))
    c.rect(18, 20, 27, 1, (0, 0, 0, 28))
    T.ashlar(c, rng, lambda y: (18, 21), 19, 41, 18, 21, ch=4, bw=(3, 3), lit=1, dark=1, base=(2, 3))
    T.ashlar(c, rng, lambda y: (41, 45), 19, 41, 41, 45, ch=4, bw=(3, 3), lit=1, dark=1, base=(2, 3))
    # hubloul: inel de alama cu nituri, sticla alb-albastruie, o roata de turbina in silueta si un butuc de cupru
    cx, cy = 31, 26
    c.ellipse(cx, cy, 7, 7, BRASS[1])
    c.ellipse(cx - 0.5, cy - 0.5, 6.6, 6.6, BRASS[3])
    c.ellipse(cx, cy, 5.4, 5.4, BRASS[1])
    c.ellipse(cx, cy, 4.6, 4.6, WARM[2])  # sala masinilor, aprinsa: sticla calda
    for yy in range(cy - 5, cy + 6):  # semiluna din dreapta-jos, mai inchisa (volumul sticlei)
        for xx in range(cx - 5, cx + 6):
            if math.hypot(xx + 0.5 - cx, yy + 0.5 - cy) <= 4.6 and math.hypot(xx + 0.5 - cx + 1.3, yy + 0.5 - cy + 1.3) > 4.9:
                c.put(xx, yy, WARM[1])
    c.ellipse(cx - 1.2, cy - 1.2, 1.7, 1.7, WARM[3])  # lumina din stanga-sus
    # roata turbinei din spatele sticlei: trei palete curbe de 1 px (2 px drepte din butuc, apoi 2 px indoite cu ~35 grade, spre
    # dreapta); a doua jumatate a fiecareia are un pixel mai inchis alaturi, ca sa se citeasca drept lama, nu drept ac de ceas
    for k in range(3):
        a0 = 2 * math.pi * k / 3 - 0.9
        for i in range(0, 17):
            r = 1.2 + i * 0.2
            a = a0 + (0.0 if r < 3.2 else math.radians(35) * (r - 3.2) / 1.2)
            bx, by = cx + math.cos(a) * r, cy + math.sin(a) * r
            c.put(int(math.floor(bx)), int(math.floor(by)), IRON[1])
            if r >= 3.2:
                nx, ny = -math.sin(a), math.cos(a)
                px_, py_ = int(math.floor(bx + nx * 0.9)), int(math.floor(by + ny * 0.9))
                if c.px[py_][px_] != IRON[1]:
                    c.put(px_, py_, WARM[0])
    c.put(cx - 2, cy - 2, (232, 244, 255, 255))  # sclipirea sticlei, peste palete
    c.put(cx - 1, cy - 2, (232, 244, 255, 255))
    c.ellipse(cx, cy, 1.4, 1.4, COPPER[2])
    c.put(cx - 1, cy - 1, COPPER[4])
    for k in range(8):  # niturile inelului
        a = 2 * math.pi * k / 8
        c.put(round(cx + math.cos(a) * 6), round(cy + math.sin(a) * 6), BRASS[4] if k < 4 else BRASS[0])
    # usa-galerie de jos (pe aici intra omul care sta la inel): arc de piatra, interior de fier intunecat, podea de pamant
    arch_fill(c, 25, 37, 33, 44, lambda x, y: DSTONE[4] if x < 31 else DSTONE[3])
    arch_fill(c, 26, 36, 34, 44, lambda x, y: IRON[0] if y < 40 else (66, 54, 46, 255))

    # --- soclul de piatra din fata, peste toata latimea
    T.ashlar(c, rng, lambda y: (6, 60), 41, 45, 6, 60, ch=4, bw=(5, 8), lit=2, dark=4)
    c.rect(6, 41, 54, 1, DSTONE[4])
    # usa taie soclul: podeaua ei (pamant batut) se vede pana la prag; pragul e o fasie de alama, iar soclul de piatra continua de o parte si de alta
    c.rect(26, 41, 11, 3, (66, 54, 46, 255))
    c.rect(26, 41, 11, 1, (84, 70, 58, 255))  # lumina din usa pe podea, la inceput
    c.rect(26, 44, 11, 1, BRASS[2])
    c.put(26, 44, BRASS[4])

    # --- pasarela de otel peste canal (aici e "podul"): doua grinzi de tablier, picioare pe aripi, roata stavilei
    c.rect(15, 6, 33, 2, IRON[3])
    c.rect(15, 6, 33, 1, IRON[4])
    c.rect(15, 8, 33, 1, IRON[0])
    for px in range(17, 47, 6):  # montantii zabrelei, doar sub grinda
        c.rect(px, 8, 1, 1, IRON[2])
    c.rect(15, 4, 5, 1, GALV[3])  # mana curenta, doar peste aripi
    c.rect(43, 4, 5, 1, GALV[3])
    for px in (15, 19, 43, 47):
        c.rect(px, 4, 1, 3, IRON[2])
    c.rect(16, 9, 2, 3, IRON[1])
    c.rect(45, 9, 2, 5, IRON[1])
    # roata stavilei, pe un montant, deasupra apei, cu tija care coboara spre grilaj
    c.rect(31, 3, 1, 3, IRON[2])
    c.ellipse(31.5, 2.0, 2.6, 2.0, IRON[3])
    c.ellipse(31.5, 2.0, 1.4, 1.0, CANAL[2])
    c.put(31, 2, BRASS[4])  # butucul de alama...
    c.put(32, 2, IRON[1])  # ...si jumatatea lui de otel: roata se citeste plina, nu ca un ochi cu pupila
    c.put(30, 1, IRON[4])  # lumina din stanga-sus pe obada
    c.rect(31, 8, 1, 4, IRON[3])
    c.put(31, 11, BRASS[3])

    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 2. Switch House


def _meter(c, x, y, w, h):
    """Contorul mare din fronton: un panou cu rama de alama (colturile taiate) si fata inchisa, pe care curentul vandut se
    vede ca patru coloane de lampi aprinse, din ce in ce mai inalte, toate in lumina calda a becurilor (varful aprins, fara rosu
    de supraincarcare), cu o linie de baza
    crem. Nu e un ceas (Depoul are ceas in fronton) si nici un cadran cu ac. `(x, y)` = coltul stanga-sus, `w` x `h`
    = cu tot cu rama."""
    c.rect(x, y, w, h, BRASS[1])
    c.rect(x + 1, y, w - 2, 1, BRASS[4])
    c.rect(x, y + 1, 1, h - 2, BRASS[3])
    c.rect(x + 1, y + h - 1, w - 2, 1, BRASS[0])
    for cx0, cy0 in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)):
        c.px[cy0][cx0] = (0, 0, 0, 0)
    c.rect(x + 1, y + 1, w - 2, h - 2, (30, 34, 48, 255))
    c.rect(x + 1, y + 1, w - 2, 1, (46, 52, 70, 255))  # reflexia din stanga-sus a sticlei
    lamp = (WARM[3], WARM[1])
    bars = ((2, 3, lamp), (5, 5, lamp), (8, 7, lamp), (11, 8, lamp))
    base = y + h - 3
    for bx, bh, (lit, dark) in bars:
        for k in range(bh):
            c.put(x + bx, base - k, lit)
            c.put(x + bx + 1, base - k, dark)
        c.put(x + bx, base - bh + 1, WARM[4])  # lampa de sus, cea mai aprinsa
        c.put(x + bx + 1, base - bh + 1, WARM[3])
    c.rect(x + 1, base + 1, w - 2, 1, CREAM[3])


def _transformer(c, x, y, w, h):
    """Un transformator: cuva de otel verde-cenusie cu nervuri verticale (radiatorul) si trei borne de portelan deasupra, cu
    capace de alama. `(x, y)` = coltul stanga-sus al cuvei, `h` = inaltimea cuvei."""
    tank = ramp(150, 0.16, 0.52, steps=5, hue_shift=8, val_span=0.40)
    c.rect(x, y, w, h, tank[2])
    c.rect(x, y, w, 1, tank[4])
    c.rect(x, y, 1, h, tank[3])
    c.rect(x + w - 1, y, 1, h, tank[0])
    for xx in range(x + 2, x + w - 1, 2):  # nervurile
        c.rect(xx, y + 2, 1, h - 3, tank[1])
        c.put(xx - 1, y + 2, tank[3])
    c.rect(x, y + h - 1, w, 1, tank[0])
    for bx in (x + 1, x + w // 2, x + w - 2):  # bornele
        porcelain(c, bx, y - 7, h=8)


def prop_switch_house():
    c = C(64, 48)
    rng = Rng(7702)
    soft_shadow(c, 32, 45, 30, 2)

    # --- aripa lunga din stanga: hala de beton cu acoperis plat, trei ferestre inalte, calde, si patru izolatori pe parapet
    concrete(c, 3, 24, 27, 17, rng, tones=CONC_WARM)
    coping(c, 2, 21, 28)
    c.rect(3, 24, 27, 1, (0, 0, 0, 64))
    c.rect(3, 25, 27, 1, (0, 0, 0, 28))
    for wx in (6, 13, 20):
        stone_arch(
            c, wx, wx + 4, 28, 36,
            lambda x, y: WARM[4] if y < 31 else (WARM[3] if y < 33 else WARM[2]),
        )
        c.rect(wx + 2, 28, 1, 9, TIMBER[1])  # montantul
        c.rect(wx, 32, 5, 1, TIMBER[1])  # traversa
        c.put(wx, 29, (255, 250, 214, 255))
        c.rect(wx - 1, 37, 7, 1, DSTONE[4])  # pervazul
        c.rect(wx - 1, 38, 7, 1, DSTONE[1])
    for px in (8, 16, 24):  # izolatori de portelan pe parapet, legati cu un fir de cupru care intra in turn
        porcelain(c, px, 13, h=8)
    line(c, 8, 12, 24, 13, COPPER[3], 1)
    line(c, 24, 13, 29, 14, COPPER[3], 1)

    # --- anexa joasa din dreapta, cu transformatorul pe acoperis
    concrete(c, 49, 33, 13, 8, rng, tones=CONC_WARM)
    coping(c, 48, 30, 15)
    c.rect(49, 33, 13, 1, (0, 0, 0, 64))
    _transformer(c, 51, 25, 10, 5)
    plain_window(c, 52, 35, 3, 4, rng, mullion=False)
    c.rect(57, 35, 4, 6, IRON[0])  # usa de serviciu
    c.rect(58, 36, 2, 5, IRON[2])
    for k in range(4):
        c.put(57 + k, 34, CAUTION if k % 2 == 0 else IRON[0])
    line(c, 52, 19, 49, 14, COPPER[2], 1)  # de la borna, spre bara din turn

    # --- turnul contorului (usa de vanzare e in el): piatra calda cioplita, fronton in trepte, cadran, usa dubla
    steps = ((7, 34, 43), (10, 32, 45), (13, 30, 47), (16, 29, 48))
    for k, (y0, x0, x1) in enumerate(steps):
        y1 = steps[k + 1][0] if k + 1 < len(steps) else 41
        T.ashlar(c, rng, lambda y, x0=x0, x1=x1: (x0, x1 + 1), y0, y1, x0, x1 + 1, ch=3, bw=(4, 7), lit=2, dark=3, base=(2, 3))
        c.rect(x0 - (1 if k else 0), y0, x1 - x0 + 1 + (2 if k else 0), 1, DSTONE[5])  # coronamentul fiecarei trepte
        if k:
            c.rect(x0 - 1, y0 + 1, x1 - x0 + 3, 1, DSTONE[1])
    c.rect(28, 41, 22, 1, DSTONE[4])
    # catargul cu becul electric, in varf (lumina calda: aici se cumpara curentul)
    c.rect(38, 3, 1, 4, IRON[2])
    c.put(38, 3, IRON[4])
    c.ellipse(38.5, 2.2, 1.5, 1.5, WARM[3])
    c.put(38, 1, (255, 250, 214, 255))
    # contorul
    _meter(c, 31, 12, 15, 12)
    # cornisa de sub cadran
    c.rect(28, 26, 22, 1, DSTONE[5])
    c.rect(28, 27, 22, 1, DSTONE[3])
    c.rect(29, 28, 20, 1, DSTONE[0])
    # usa dubla, in arc de piatra, cu luminator cald
    stone_arch(
        c, 35, 42, 30, 41,
        lambda x, y: (WARM[3] if y < 33 else (WOOD[2] if (x - 35) // 4 == 0 else WOOD[1])),
    )
    c.rect(39, 34, 4, 7, WARM[2])  # canatul din dreapta, aprins: locul spre care merg clientii e cel mai luminos
    c.rect(39, 34, 4, 1, WARM[3])
    c.rect(38, 33, 1, 9, WOOD[0])  # rostul dintre canaturi
    c.rect(35, 33, 8, 1, DSTONE[1])  # traversa luminatorului
    for yy in (36, 39):  # benzi de fier si nituri de alama
        c.rect(35, yy, 8, 1, IRON[1])
    c.put(37, 38, BRASS[4])
    c.put(40, 38, BRASS[3])
    # trepte
    c.rect(33, 42, 12, 1, DSTONE[4])
    c.rect(32, 43, 14, 1, DSTONE[3])
    c.rect(31, 44, 16, 1, DSTONE[2])
    # felinare cu brate de fier
    for lx, d in ((45, 1), (32, -1)):
        c.rect(lx, 28, 1, 5, IRON[2])
        c.rect(lx + d, 27, 1, 1, IRON[2])
        c.rect(lx + d, 28, 1, 2, WARM[3])
        c.put(lx + d, 28, WARM[4])

    # --- soclul de piatra din fata
    T.ashlar(c, rng, lambda y: (2, 62), 41, 45, 2, 62, ch=4, bw=(5, 8), lit=2, dark=4)
    c.rect(2, 41, 60, 1, DSTONE[4])
    # treptele peste soclu
    c.rect(33, 42, 12, 1, DSTONE[4])
    c.rect(32, 43, 14, 1, DSTONE[3])
    c.rect(31, 44, 16, 1, DSTONE[2])
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 3. Canteen


def _flower_box(c, x, y, w, colors):
    """O ladita cu flori sub o fereastra: lemn (lumina sus), frunze si capete colorate deasupra."""
    c.rect(x, y, w, 2, WOOD[2])
    c.rect(x, y, w, 1, WOOD[4])
    c.rect(x, y + 1, w, 1, WOOD[0])
    for k in range(w):
        c.put(x + k, y - 1, LEAF[2] if k % 2 else LEAF[1])
        if k % 2 == 0:
            c.put(x + k, y - 2, colors[(k // 2) % len(colors)])


def _bowl_sign(c, x, y):
    """Firma de langa usa, atarnata de un brat de fier: scandura de 6x7 cu un bol crem si aburi galbeni. `(x, y)` = coltul
    stanga-sus al scandurii."""
    c.rect(x, y, 6, 7, TIMBER[0])
    c.rect(x + 1, y + 1, 4, 5, WOOD[3])
    c.rect(x + 1, y + 1, 4, 1, WOOD[4])
    c.rect(x + 1, y + 4, 4, 1, CREAM[4])  # bolul: buza si trupul
    c.rect(x + 2, y + 5, 2, 1, CREAM[2])
    c.put(x + 2, y + 2, YEL_F)  # aburii
    c.put(x + 4, y + 2, YEL_F)
    c.put(x + 3, y + 3, (255, 250, 214, 255))
    c.put(x + 1, y - 1, IRON[2])  # lanturile
    c.put(x + 4, y - 1, IRON[2])


def prop_canteen():
    c = C(64, 48)
    rng = Rng(7703)
    soft_shadow(c, 31, 45, 30, 2)

    # --- acoperisul mare de olane rosii, cu streasina larga (aceeasi familie ca Old Bells si casuta 2)
    T.tile_roof(c, 17, lambda i: max(1, 18 - i), lambda i: min(63, 46 + i), 4, ROOF_TILE, tile=4)
    c.rect(18, 4, 28, 1, ROOF_TILE[4])
    c.rect(18, 5, 28, 1, ROOF_TILE[3])
    c.rect(3, 21, 56, 1, (0, 0, 0, 70))  # umbra streasinii pe etaj
    c.rect(3, 22, 56, 1, (0, 0, 0, 30))

    # --- etajul: barne si tencuiala, iese cu un pixel in consola peste parter
    c.rect(3, 21, 56, 10, PLASTER_SAND[2])
    for y in range(23, 30, 3):  # pete usoare in tencuiala
        for x in range(5 + (y % 2) * 3, 58, 7):
            c.put(x, y, PLASTER_SAND[3])
    c.rect(3, 21, 56, 1, PLASTER_SAND[1])
    for px in (3, 14, 26, 35, 46, 57):  # stalpii
        c.rect(px, 21, 2, 10, TIMBER[2])
        c.rect(px, 21, 1, 10, TIMBER[3])
    c.rect(3, 29, 56, 1, TIMBER[1])  # talpa etajului
    c.rect(3, 30, 56, 1, TIMBER[0])  # grinda de consola
    line(c, 28, 28, 34, 22, TIMBER[2], 1)  # contrafisele in X din travee de mijloc
    line(c, 34, 28, 28, 22, TIMBER[1], 1)
    shut = ramp(188, 0.46, 0.48, hue_shift=8)
    for wx in (7, 18, 39, 50):
        c.rect(wx - 2, 23, 1, 5, shut[3])  # obloanele
        c.rect(wx + 6, 23, 1, 5, shut[1])
        plain_window(c, wx, 23, 5, 5, rng, mullion=True)
        _flower_box(c, wx - 1, 28, 7, (RED_F, YEL_F, PINK_F, WHITE_F))
    # sub etaj: umbra grinzii pe peretele de piatra
    c.rect(4, 31, 54, 1, (0, 0, 0, 80))
    c.rect(4, 32, 54, 1, (0, 0, 0, 40))

    # --- lucarna cu fereastra aprinsa
    c.rect(28, 13, 10, 8, PLASTER_SAND[2])
    c.rect(28, 13, 1, 8, TIMBER[3])
    c.rect(37, 13, 1, 8, TIMBER[1])
    plain_window(c, 30, 14, 6, 4, rng, mullion=True)
    c.rect(29, 18, 8, 1, WOOD[2])  # pervazul
    T.tile_roof(c, 5, lambda i: 31 - i, lambda i: 35 + i, 8, ROOF_TILE, tile=4)
    c.rect(30, 8, 5, 1, ROOF_TILE[4])
    c.rect(28, 12, 10, 1, (0, 0, 0, 60))

    # --- cosul de piatra, peste coama
    cx = 41
    for y in range(3, 11):
        for x in range(cx, cx + 6):
            t = 3
            if x == cx:
                t = 4
            elif x >= cx + 4:
                t = 2
            if y % 3 == 0:
                t -= 1
            c.put(x, y, DSTONE[t])
    c.rect(cx - 1, 1, 8, 2, DSTONE[4])
    c.rect(cx - 1, 1, 8, 1, DSTONE[5])
    c.rect(cx + 1, 2, 4, 1, DSTONE[0])
    c.rect(cx - 1, 3, 8, 1, DSTONE[1])
    c.rect(cx, 10, 6, 1, (0, 0, 0, 70))

    # --- parterul: piatra calda cioplita, usa mare in arc, doua ferestre mari aprinse
    T.ashlar(c, rng, lambda y: (4, 58), 31, 45, 4, 58, ch=4, bw=(5, 8), lit=2, dark=4)
    c.rect(4, 44, 54, 1, DSTONE[1])
    # ferestrele mari: arc de piatra, sticla calda cu degrade, o masa si capetele celor care mananca
    for wx in (9, 44):
        stone_arch(
            c, wx, wx + 9, 34, 42,
            lambda x, y: WARM[4] if y < 37 else (WARM[3] if y < 40 else WARM[2]),
        )
        c.rect(wx + 4, 34, 1, 9, TIMBER[1])  # montantul
        c.rect(wx, 38, 10, 1, TIMBER[1])  # traversa
        c.rect(wx, 40, 10, 1, WOOD[0])  # masa, vazuta in silueta
        for hx, cloth in ((wx + 1, BLUE_F), (wx + 6, RED_F)):  # doi mesenii: cap, umeri
            c.rect(hx, 37, 2, 2, SKIN_T)
            c.put(hx, 37, SKIN_L)
            c.rect(hx - 1, 39, 4, 1, cloth)
        for bx in (wx + 3, wx + 5, wx + 8):  # boluri si o cana pe masa
            c.put(bx, 39, CREAM[4])
        c.put(wx + 4, 38, CREAM[3])  # ulciorul de pe masa
        c.put(wx + 1, 35, (255, 250, 214, 255))
        c.rect(wx - 1, 43, 12, 1, DSTONE[4])  # pervazul
        c.rect(wx - 1, 44, 12, 1, DSTONE[1])

    # --- porticul de lemn peste usa
    stone_arch(
        c, 28, 34, 33, 44,
        lambda x, y: (WARM[3] if y < 36 else (WOOD[2] if x < 31 else WOOD[1])),
    )
    c.rect(31, 36, 1, 9, WOOD[0])  # rostul dintre canaturi
    c.rect(28, 36, 7, 1, TIMBER[1])
    for yy in (39, 42):
        c.rect(28, yy, 7, 1, IRON[1])
    c.put(30, 41, BRASS[4])
    c.put(33, 41, BRASS[3])
    c.put(30, 33, (255, 250, 214, 255))
    for px in (23, 37):  # stalpii portic
        c.rect(px, 32, 2, 12, TIMBER[2])
        c.rect(px, 32, 1, 12, TIMBER[3])
    T.tile_roof(c, 5, lambda i: 25 - i, lambda i: 37 + i, 28, ROOF_TILE, tile=3)
    c.rect(21, 33, 20, 1, (0, 0, 0, 70))  # umbra pe usa
    c.rect(22, 34, 18, 1, (0, 0, 0, 34))
    for lx in (27, 35):  # felinare atarnate de portic
        c.rect(lx, 33, 1, 2, IRON[2])
        c.rect(lx - 1, 35, 3, 3, WARM[3])
        c.put(lx - 1, 35, WARM[4])
        c.put(lx, 38, IRON[1])
    # trepte
    c.rect(26, 44, 11, 1, DSTONE[4])
    c.rect(25, 45, 13, 1, DSTONE[2])

    # --- un butoi in stanga, lazi in dreapta, un banc scund
    c.rect(5, 39, 4, 6, WOOD[2])
    c.rect(5, 39, 1, 6, WOOD[4])
    c.rect(8, 39, 1, 6, WOOD[0])
    c.rect(5, 41, 4, 1, STEEL[2])
    c.rect(5, 43, 4, 1, STEEL[1])
    for bx, by, bw in ((53, 40, 5), (54, 36, 4)):  # doua lazi suprapuse, din lemn mai inchis decat piatra
        c.rect(bx, by, bw, 5, WOOD[2])
        c.rect(bx, by, bw, 1, WOOD[4])
        c.rect(bx, by + 4, bw, 1, WOOD[0])
        c.rect(bx, by, 1, 5, WOOD[3])
        c.rect(bx + bw - 1, by, 1, 5, WOOD[0])
        line(c, bx + 1, by + 1, bx + bw - 2, by + 3, WOOD[1], 1)
    c.put(58, 43, LEAF[2])  # o tufa de iarba intre lazi si perete
    c.put(58, 42, LEAF[3])

    # --- firma-bol, pe un brat de fier, in dreapta
    c.rect(55, 24, 8, 1, IRON[2])
    c.put(55, 25, IRON[1])
    line(c, 57, 27, 55, 25, IRON[1], 1)
    _bowl_sign(c, 57, 26)

    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 4. Crystal Kiln


def _dome_hw(y, rx=17, spring=31, ry=24.0):
    """Jumatatea latimii cuptorului-stup la randul y: tambur drept pana la `spring`, apoi o cupola eliptica."""
    if y >= spring:
        return float(rx)
    t = (spring - y - 0.5) / ry
    return rx * math.sqrt(max(0.0, 1 - t * t))


def _kiln_body(c, cx, y0, y1, rng, tones=FIREBRICK):
    """Corpul cuptorului: caramida refractara in randuri de 3 px urmand cupola, rosturi decalate, volum din lumina de
    stanga-sus (stanga luminata, dreapta in umbra, mijloc intre ele, cu trecere in cadru de sah)."""
    for y in range(y0, y1 + 1):
        hw = _dome_hw(y)
        xl, xr = int(round(cx - hw)), int(round(cx + hw))
        row = (y - y0) // 3
        for x in range(xl, xr):
            u = (x + 0.5 - cx) / max(hw, 1.0)
            dith = (x + y) % 2 == 0
            t = 3
            if u < -0.55 or (u < -0.38 and dith):
                t = 4
            elif u > 0.5 or (u > 0.32 and dith):
                t = 1
            elif u > 0.15:
                t = 2
            if (y - y0) % 3 == 2:
                t -= 1  # rostul orizontal
            elif (x + (2 if row % 2 else 0)) % 5 == 0 and not (8 <= y <= 16 and 21 <= x <= 43):
                t -= 1  # rostul vertical (banda 8-16 ramane curata: acolo scrie jocul Kiln)
            if x == xl:
                t = min(5, t + 1)
            if x == xr - 1:
                t = 0
            c.put(x, y, tones[clamp(t, 0, len(tones) - 1)])


def _hoop(c, cx, y, rx, rivets=True):
    """Un cerc de otel pe corp, la randul y: latime 2 * rx, lumina din stanga, nituri de alama din 5 in 5."""
    xl, xr = int(round(cx - rx)), int(round(cx + rx))
    c.rect(xl, y, xr - xl, 1, IRON[3])
    c.rect(xl, y + 1, xr - xl, 1, IRON[1])
    c.put(xl, y, GALV[4])
    c.put(xr - 1, y, IRON[1])
    if rivets:
        for x in range(xl + 3, xr - 1, 5):
            c.put(x, y, BRASS[3])


def prop_crystal_kiln():
    c = C(64, 48)
    rng = Rng(7704)
    soft_shadow(c, 32, 45, 30, 2)
    cx = 32

    # --- soclul de piatra al cuptorului
    T.ashlar(c, rng, lambda y: (11, 54), 41, 45, 11, 54, ch=4, bw=(5, 8), lit=2, dark=4)
    c.rect(11, 41, 43, 1, DSTONE[4])

    # --- cos inalt, de otel, separat: soclu de piatra, plachi nituite, cercuri, buza; fumul pleaca din varful lui
    T.ashlar(c, rng, lambda y: (51, 62), 35, 41, 51, 62, ch=3, bw=(4, 7), lit=2, dark=3)
    c.rect(51, 35, 11, 1, DSTONE[4])
    for x in range(53, 60):
        t = GALV[4] if x == 53 else (GALV[3] if x == 54 else (GALV[2] if x < 58 else (GALV[1] if x == 58 else GALV[0])))
        c.rect(x, 1, 1, 35, t)
    for y in range(3, 35, 6):  # rosturile plachilor si niturile
        c.rect(53, y, 7, 1, IRON[1])
        for x in (54, 56, 58):
            c.put(x, y + 1, GALV[4])
    for y in (11, 25):  # doua cercuri mai groase, de alama
        c.rect(52, y, 9, 2, BRASS[2])
        c.rect(52, y, 9, 1, BRASS[4])
        c.rect(52, y + 1, 9, 1, BRASS[0])
    c.rect(52, 1, 9, 2, IRON[1])  # buza (randul 0 ramane liber pentru contur)
    c.rect(52, 1, 9, 1, IRON[3])
    c.rect(54, 2, 5, 1, IRON[0])  # gura inchisa la culoare
    # scara de fier lipita de cos, pana sus
    c.rect(61, 3, 1, 32, IRON[2])
    for y in range(5, 35, 3):
        c.rect(60, y, 3, 1, IRON[3])

    # --- corpul cupolei, cu gura cuptorului
    _kiln_body(c, cx, 7, 41, rng)
    # cercurile de otel: sus pe cupola, la mijloc, la baza tamburului
    _hoop(c, cx, 17, _dome_hw(17) + 0.5, rivets=False)
    _hoop(c, cx, 24, _dome_hw(24) + 0.5)
    _hoop(c, cx, 33, 17.5)
    # conducta de fum, de otel galvanizat, de la umarul cupolei la cos
    c.rect(46, 19, 8, 3, GALV[3])
    c.rect(46, 19, 8, 1, GALV[4])
    c.rect(46, 21, 8, 1, IRON[1])
    c.rect(48, 18, 1, 5, IRON[2])  # cureaua de prindere
    c.rect(52, 18, 2, 5, IRON[2])
    # gura cuptorului: arc cu rama de fier, interior fierbinte (indigo la margini, violet, miez alb-violet)
    arch_fill(c, 24, 40, 28, 41, lambda x, y: IRON[3] if x < 32 else IRON[1])
    arch_fill(c, 25, 39, 29, 41, lambda x, y: _mouth_color(x, y))
    c.rect(25, 39, 15, 1, IRON[0])  # o singura bara orizontala de gratar, in fata jarului (barele verticale citeau ca dinti)
    # aureola violet care se rasfrange pe caramida din jurul gurii
    glow(c, 32, 36, 14, 12, GLOW_VIO, a0=130, steps=5)
    # incarcarea din stanga: la baza, un vagonet cu cristal brut pe o sina scurta (palnia plutitoare a fost scoasa: vagonetul arata intrarea)
    c.rect(1, 44, 14, 1, IRON[1])
    for x in range(2, 15, 3):
        c.rect(x, 45, 2, 1, WOOD[1])
    c.rect(2, 37, 11, 6, IRON[1])  # vagonetul: cutie de otel cu doua benzi de lemn
    c.rect(2, 37, 11, 1, IRON[3])
    c.rect(2, 42, 11, 1, IRON[0])
    c.rect(2, 37, 1, 6, IRON[3])
    for x in (5, 9):
        c.rect(x, 38, 1, 4, WOOD[1])
    for wx in (4, 11):
        c.ellipse(wx, 43.5, 1.5, 1.5, IRON[2])
        c.put(wx, 43, IRON[4])
    crystal_spike(c, 4, 36, 5, w=2, tones=(CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0]), lean=-1)
    crystal_spike(c, 7, 36, 7, w=3)
    crystal_spike(c, 10, 36, 5, w=2, tones=(CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0]), lean=1)
    crystal_spike(c, 12, 36, 3, w=2)

    # --- sina din dreapta cu vagonetul de lingouri violete, in fata soclului cosului
    c.rect(48, 44, 15, 1, IRON[1])
    for x in range(49, 62, 3):
        c.rect(x, 45, 2, 1, WOOD[1])
    c.rect(52, 40, 11, 3, IRON[1])
    c.rect(52, 40, 11, 1, IRON[3])
    c.rect(52, 42, 11, 1, IRON[0])
    for wx in (54, 60):
        c.ellipse(wx, 43.5, 1.4, 1.4, IRON[2])
        c.put(wx, 43, IRON[4])
    for k, (ix, iy) in enumerate(((53, 38), (58, 38), (55, 36))):  # lingouri violete, in piramida
        c.rect(ix, iy, 5, 2, HOT[1])
        c.rect(ix, iy, 5, 1, HOT[3])
        c.rect(ix, iy + 1, 5, 1, HOT[0])
        c.put(ix, iy, HOT[4])
    glow(c, 56, 38, 7, 4, GLOW_VIO, a0=50, steps=3)

    outline_trace(c)
    outline_crystal(c)
    # lumina violet care se revarsa din gura pe pamantul din fata (dupa contur: doar pe pixeli liberi)
    for y in range(45, 48):
        for x in range(21, 44):
            if c.px[y][x][3] == 0:
                d = math.hypot((x - 32) / 11.0, (y - 44) / 3.0)
                a = int(max(0, 70 * (1 - d)))
                if a >= 6:
                    c.put(x, y, (GLOW_VIO[0], GLOW_VIO[1], GLOW_VIO[2], a))
    return c


def _mouth_color(x, y):
    """Culoarea interiorului gurii cuptorului: un degrade radial, miezul alb-violet jos la mijloc, indigo spre margini."""
    d = math.sqrt(((x + 0.5 - 32) / 7.5) ** 2 + ((y + 0.5 - 40) / 12.0) ** 2)
    if d < 0.30:
        return HOT[4]
    if d < 0.52:
        return HOT[3]
    if d < 0.78:
        return HOT[2]
    if d < 1.0:
        return HOT[1]
    return HOT[0]


# ---------------------------------------------------------------------------------------------
# 5. Crystal Shed


def _vault_top(x, cx=19.5, rx=19.0, base=14.0, ry=8.5):
    """Randul de sus al acoperisului-bolta in coloana x (jumatate de elipsa)."""
    t = (x + 0.5 - cx) / rx
    return base - ry * math.sqrt(max(0.0, 1 - t * t))


def prop_crystal_shed():
    c = C(40, 32)
    rng = Rng(7705)
    soft_shadow(c, 20, 29, 18, 2)

    # --- peretele din fata, piatra calda cioplita, si soclul
    T.ashlar(c, rng, lambda y: (4, 36), 13, 27, 4, 36, ch=4, bw=(5, 8), lit=2, dark=4)
    # deschiderea boltita: ghirlanda de piatra de 2 px, interior indigo, un raft in spate si un maldar de cristale pe jos
    stone_arch(c, 11, 28, 18, 27, lambda x, y: (26, 24, 62, 255) if y < 26 else (38, 34, 90, 255), ring=2)
    c.rect(12, 21, 16, 1, WOOD[2])  # raftul din spate
    c.rect(12, 22, 16, 1, WOOD[0])
    VIO = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    BLU = (CRYS[3], CRYS[2], CRYS[1], CRYS[0])
    for x, h1, tn in ((13, 2, BLU), (16, 3, VIO), (19, 2, BLU), (22, 3, VIO), (25, 2, BLU)):  # pe raft
        crystal_spike(c, x, 20, h1, w=2, tones=tn)
    for x, h1, tn in ((13, 3, VIO), (15, 5, BLU), (18, 6, BLU), (20, 4, VIO), (22, 6, VIO), (24, 4, BLU), (26, 3, VIO)):  # maldarul
        crystal_spike(c, x, 26, h1, w=3 if h1 >= 5 else 2, tones=tn)
    c.rect(12, 27, 16, 1, (86, 70, 190, 255))  # lumina de pe podea
    glow(c, 20, 25, 10, 6, GLOW_VIO, a0=80, steps=4)
    # soclul
    T.ashlar(c, rng, lambda y: (3, 37), 27, 30, 3, 37, ch=3, bw=(5, 8), lit=2, dark=4)
    c.rect(3, 27, 34, 1, DSTONE[4])

    # --- acoperisul-bolta de tabla galvanizata, nervuri de otel, streasina
    for x in range(1, 39):
        top = int(round(_vault_top(x)))
        for y in range(top, 15):
            tone = GALV[3] if x % 3 == 0 else (GALV[2] if x % 3 == 1 else GALV[1])
            u = (y - top)
            if u == 0:
                tone = GALV[4]
            c.put(x, y, tone)
        c.put(x, 14, GALV[0])
    for x in (8, 19, 30):  # nervurile
        top = int(round(_vault_top(x)))
        c.rect(x, top, 1, 15 - top, IRON[1])
    c.rect(4, 15, 32, 1, (0, 0, 0, 70))  # umbra streasinii pe piatra (doar unde e perete: coloanele 4-35)
    c.rect(4, 16, 32, 1, (0, 0, 0, 30))

    # --- coroana de pe creasta: un guler de otel in care se infig cristalele (randul 0 ramane liber pentru contur)
    c.rect(14, 5, 12, 2, IRON[1])
    c.rect(14, 5, 12, 1, IRON[3])
    for x in (17, 22):
        c.put(x, 6, IRON[2])
    VIO = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    crystal_spike(c, 15, 5, 3, w=2, tones=VIO, lean=-1)
    crystal_spike(c, 17, 5, 4, w=3, tones=VIO, lean=-1)
    crystal_spike(c, 20, 5, 5, w=4)
    crystal_spike(c, 23, 5, 4, w=3, tones=VIO, lean=1)
    crystal_spike(c, 25, 5, 3, w=2, tones=VIO, lean=1)
    glow(c, 20, 5, 8, 4, GLOW_VIO, a0=60, steps=3)

    # --- un cos cu cristale in stanga si un vagonet in dreapta
    c.rect(1, 24, 6, 5, WOOD[2])
    c.rect(1, 24, 1, 5, WOOD[4])
    c.rect(6, 24, 1, 5, WOOD[0])
    c.rect(1, 26, 6, 1, IRON[1])
    crystal_spike(c, 3, 24, 4, w=2)
    crystal_spike(c, 5, 24, 3, w=2, tones=(CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0]))
    c.rect(31, 24, 8, 4, IRON[1])
    c.rect(31, 24, 8, 1, IRON[3])
    c.rect(31, 27, 8, 1, IRON[0])
    for wx in (33, 37):
        c.ellipse(wx, 28.4, 1.3, 1.3, IRON[2])
    crystal_spike(c, 33, 23, 4, w=2, tones=(CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0]))
    crystal_spike(c, 36, 23, 5, w=3)

    outline_trace(c)
    outline_crystal(c)
    return c


# ---------------------------------------------------------------------------------------------
# 6. Dam Bell


def _bell_hw(y):
    """Jumatatea latimii clopotnitei-perete la randul y (axa intre coloanele 19 si 20): fronton triunghiular deasupra, apoi
    peretele care se largeste usor spre baza (batiu, ca zidul barajului)."""
    if y < 9:
        return 0
    if y < 17:
        return 1 + (y - 9)
    return 9 + int(round(2 * (y - 17) / 32.0))


def _pinnacle(c, x, y):
    """Un pinion mic de piatra cu un cristal violet in varf: 3 px lat la baza, `y` = randul de sus al cristalului."""
    c.rect(x, y + 3, 3, 4, DSTONE[3])
    c.rect(x, y + 3, 1, 4, DSTONE[5])
    c.rect(x + 2, y + 3, 1, 4, DSTONE[1])
    c.rect(x - 1, y + 6, 5, 1, DSTONE[4])
    crystal_spike(c, x + 1, y + 3, 4, w=2, tones=(CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0]))


def prop_dam_bell():
    c = C(40, 56)
    rng = Rng(7706)
    soft_shadow(c, 20, 53, 17, 3)

    def bounds(y):
        hw = _bell_hw(y)
        return 20 - hw, 20 + hw

    # --- soclul in trepte
    T.ashlar(c, rng, lambda y: (3, 37), 51, 53, 3, 37, ch=2, bw=(5, 8), lit=2, dark=4)
    T.ashlar(c, rng, lambda y: (5, 35), 49, 51, 5, 35, ch=2, bw=(5, 8), lit=2, dark=4)
    c.rect(5, 49, 30, 1, DSTONE[5])
    c.rect(3, 51, 34, 1, DSTONE[4])
    # --- contraforturile: piatra cu varful in panta, care se ridica spre perete
    for side in (0, 1):
        for y in range(30, 49):
            reach = max(1, min(4, (y - 30 + 1) * 4 // 5))
            xl, xr = (9 - reach, 9) if side == 0 else (31, 31 + reach)
            T.ashlar(c, rng, lambda yy, xl=xl, xr=xr: (xl, xr), y, y + 1, xl, xr, ch=1, bw=(4, 6), lit=1, dark=2, base=(2, 3))
        for y in range(34, 49, 4):  # rosturile orizontale
            xl, xr = (5, 9) if side == 0 else (31, 35)
            c.rect(xl, y + 3, xr - xl, 1, DSTONE[1])
        for y in range(30, 35):  # muchia luminata a pantei
            reach = max(1, min(4, (y - 30 + 1) * 4 // 5))
            c.put(9 - reach if side == 0 else 30 + reach, y, DSTONE[5])
        c.rect(5 if side == 0 else 31, 34, 4, 1, DSTONE[5])
    # --- peretele si frontonul, din piatra cioplita
    T.ashlar(c, rng, bounds, 9, 49, 9, 31, ch=4, bw=(5, 8), lit=2, dark=4)
    # muchiile frontonului: coronament luminat pe panta din stanga, in umbra pe cea din dreapta
    for y in range(9, 17):
        xl, xr = bounds(y)
        c.put(xl, y, DSTONE[5])
        c.put(xl + 1, y, DSTONE[4])
        c.put(xr - 1, y, DSTONE[1])
    # cornisa: iese cu un pixel in afara frontonului si cu un pixel in afara peretelui
    c.rect(8, 17, 24, 1, DSTONE[5])
    c.rect(8, 18, 24, 1, DSTONE[3])
    c.rect(11, 19, 18, 1, (0, 0, 0, 70))  # umbra cornisei doar pe perete (coloanele 11-28)
    c.rect(11, 20, 18, 1, (0, 0, 0, 30))
    # banda de otel galvanizat peste perete, sub arc, cu capete de buloane de alama
    c.rect(9, 40, 22, 2, GALV[3])
    c.rect(9, 40, 22, 1, GALV[4])
    c.rect(9, 42, 22, 1, GALV[0])
    for x in (11, 15, 25, 29):
        c.put(x, 41, BRASS[3])

    # --- arcul mare, cu ghirlanda de piatra si interiorul in umbra rece
    stone_arch(c, 13, 26, 21, 38, lambda x, y: None, ring=2)

    def hole(x, y):  # golul arcului ramane transparent (ca la clopotele Landing, Moara si Works): iarba se vede prin el
        c.px[y][x] = (0, 0, 0, 0)

    arch_fill(c, 13, 26, 21, 38, lambda x, y: hole(x, y))
    # grinda-jug de otel pe care atarna clopotul, prinsa in zid
    c.rect(12, 25, 16, 2, IRON[3])
    c.rect(12, 25, 16, 1, IRON[4])
    c.rect(12, 27, 16, 1, IRON[0])
    for x in (14, 19, 25):
        c.put(x, 26, BRASS[3])
    # clopotul: otel galvanizat cu brau de alama (urechea la jug, limba lasa aer sub el)
    T.bell(c, 20, 29, [2, 3, 3, 4, 4, 4, 4, 5, 6, 6], GALV, band=8, band_tones=BRASS)
    c.rect(19, 39, 2, 1, BRASS[3])  # limba de alama, sub buza

    # --- placuta de alama cu barajul, intre banda si soclu
    c.rect(14, 43, 12, 6, BRASS[1])
    c.rect(14, 43, 12, 1, BRASS[4])
    c.rect(14, 44, 1, 4, BRASS[3])
    c.rect(15, 44, 10, 4, IRON[0])
    c.rect(18, 44, 4, 1, CREAM[4])  # barajul: un trapez crem, cu valuri dedesubt
    c.rect(17, 45, 6, 1, CREAM[3])
    c.rect(16, 46, 8, 1, CREAM[2])
    c.rect(15, 47, 10, 1, WATER[3])
    c.put(17, 47, WATER[4])
    c.put(21, 47, WATER[4])
    c.put(24, 47, WATER[4])
    c.rect(14, 48, 12, 1, BRASS[0])

    # --- coroana din varf: soclu de piatra cu guler de otel, iar deasupra un buchet de cristale albastru-violet
    c.rect(17, 7, 6, 2, DSTONE[3])
    c.rect(17, 7, 6, 1, DSTONE[5])
    c.rect(18, 8, 5, 1, DSTONE[1])
    c.rect(16, 6, 8, 1, GALV[3])
    c.rect(16, 6, 8, 1, GALV[4])
    c.put(23, 6, GALV[1])
    VIO = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    crystal_spike(c, 17, 5, 4, w=3, tones=VIO, lean=-1)
    crystal_spike(c, 22, 5, 4, w=3, tones=VIO, lean=1)
    crystal_spike(c, 19, 5, 5, w=4)
    crystal_spike(c, 21, 5, 4, w=3)
    # --- doi pinioni cu cristale, pe colturile cornisei
    _pinnacle(c, 7, 11)
    _pinnacle(c, 30, 11)

    outline_trace(c)
    outline_crystal(c)
    # aureola felinarului, doar pe pixelii liberi din jur (dupa contur, ca sa nu-l inlocuiasca)
    for y in range(0, 10):
        for x in range(10, 30):
            if c.px[y][x][3] == 0:
                d = math.hypot((x - 19.5) * 0.9, (y - 3.0))
                a = int(max(0, 64 - d * 10))
                if a >= 8:
                    c.put(x, y, (CRYS_GLOW[0], CRYS_GLOW[1], CRYS_GLOW[2], a))
    return c


SPRITES = {
    "prop_relay_station": prop_relay_station,
    "prop_switch_house": prop_switch_house,
    "prop_canteen": prop_canteen,
    "prop_crystal_kiln": prop_crystal_kiln,
    "prop_crystal_shed": prop_crystal_shed,
    "prop_dam_bell": prop_dam_bell,
}
SIZES = {
    "prop_relay_station": (64, 48),
    "prop_switch_house": (64, 48),
    "prop_canteen": (64, 48),
    "prop_crystal_kiln": (64, 48),
    "prop_crystal_shed": (40, 32),
    "prop_dam_bell": (40, 56),
}
# ce imprumuta fiecare azi (de comparat) si unde sta in lume (x centru, y baza), in pixeli de lume; 1 px de arta = 3 de lume
BORROWED = {
    "prop_relay_station": "prop_copper_furnace",
    "prop_switch_house": "prop_depot",
    "prop_canteen": "prop_tavern",
    "prop_crystal_kiln": "prop_power_house",
    "prop_crystal_shed": "prop_battery_shed",
    "prop_dam_bell": "prop_works_bell",
}
WORLD_AT = {
    "prop_relay_station": (2225, 1380),
    "prop_switch_house": (2039, 1080),
    "prop_canteen": (400, 1080),
    "prop_crystal_kiln": (2835, 1380),
    "prop_crystal_shed": (2695, 1010),
    "prop_dam_bell": (2985, 1010),
}
# in joc, locurile mai au o grija: SMOKE_AT (fractii x / latime, y / inaltime) pentru Kiln, masurate pe foaia noua
GHOSTED = ("prop_crystal_kiln", "prop_crystal_shed", "prop_dam_bell")
WATER_BG = (56, 112, 168, 255)


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


def smoke_at(c):
    """Fractiile (x / latime, y / inaltime) ale gurii cosului, pentru SMOKE_AT: primul rand cu pixeli de piatra/otel din cosul cel
    mai inalt (coloanele cosului sunt cele de la x >= 51 pe randul 0 al Kiln-ului)."""
    top = None
    for y in range(c.h):
        xs = [x for x in range(c.w) if c.px[y][x][3] == 255 and c.px[y][x] != OUTLINE]
        if xs:
            top = (y, xs)
            break
    y, xs = top
    return (min(xs) + max(xs) + 1) / 2.0 / c.w, y / float(c.h)


def ground_image():
    g1 = Image.open(os.path.join(SPR, "prop_dam_ground.png")).convert("RGBA")
    g2 = Image.open(os.path.join(SPR, "prop_dam_ground_2.png")).convert("RGBA")
    full = Image.new("RGBA", (g1.width + g2.width, g1.height), WATER_BG)  # apa e transparenta in imaginea coapta
    full.alpha_composite(g1, (0, 0))
    full.alpha_composite(g2, (g1.width, 0))
    return full


def ghost_of(im):
    """Cum arata sprite-ul ca stafie: PadController il vopseste GHOST_TINT (26, 32, 42), la transparenta 0,48 (blocat)."""
    out = im.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            px[x, y] = (r * 26 // 255, g * 32 // 255, b * 42 // 255, int(a * 0.52))
    return out


def place(ground, im, name):
    """Pune sprite-ul pe pamant, la pozitia lui din lume (ancora jos-mijloc), in pixeli de arta ai pamantului."""
    wx, wy = WORLD_AT[name]
    left = round((wx - im.width * 3 / 2.0) / 3.0)
    top = round(wy / 3.0) - im.height
    ground.alpha_composite(im, (left, top))
    return left, top


def preview(out_dir, imgs):
    S = 4
    pad = 12
    lab = font(8)
    bg = (86, 128, 64, 255)
    names = list(SPRITES)
    # --- sectiunea 1: perechi (nou / imprumutat), cate doua pe rand
    cells = []
    for n in names:
        new = imgs[n]
        old = Image.open(os.path.join(SPR, BORROWED[n] + ".png")).convert("RGBA")
        cells.append((n, new, old))
    cw = max(max(new.width, old.width) for _, new, old in cells) * S
    ch = max(max(new.height, old.height) for _, new, old in cells) * S
    colw = cw * 2 + pad * 3
    sec1 = Image.new("RGBA", (colw * 2 + pad, (ch + pad + 14) * 3 + pad), (28, 32, 36, 255))
    d1 = ImageDraw.Draw(sec1)
    for i, (n, new, old) in enumerate(cells):
        col, row = i % 2, i // 2
        x0 = col * (colw + pad)
        y0 = pad + row * (ch + pad + 14)
        d1.rectangle([x0, y0 + 12, x0 + colw - 1, y0 + 12 + ch], fill=bg)
        d1.text((x0 + 4, y0), f"{n.replace('prop_', '')} {new.width}x{new.height}  NEW  |  was: {BORROWED[n].replace('prop_', '')}", font=lab, fill=(235, 235, 235, 255))
        bn = new.resize((new.width * S, new.height * S), Image.NEAREST)
        bo = old.resize((old.width * S, old.height * S), Image.NEAREST)
        sec1.alpha_composite(bn, (x0 + pad, y0 + 12 + ch - bn.height))
        sec1.alpha_composite(bo, (x0 + pad * 2 + cw, y0 + 12 + ch - bo.height))
    # --- sectiunea 2: fiecare pe pamantul copt, la locul lui, x3 (1 px de arta = 3 px de lume = scara jocului)
    ground = ground_image()
    placed = ground.copy()
    boxes = {}
    for n in names:
        boxes[n] = place(placed, imgs[n], n)
    # stalpul de culoar (A1), ca sa se vada unde pleaca curentul din Relay
    pl = os.path.join(out_dir, "prop_pylon_lane.png")
    pl_a1 = scratch.sprite("prop_pylon_lane", "a1")
    pyl = None
    for cand in (pl, pl_a1):
        if os.path.exists(cand):
            pyl = Image.open(cand).convert("RGBA")
            break
    if pyl is not None:
        placed.alpha_composite(pyl, (round(2450 / 3.0) - pyl.width // 2, round(1300 / 3.0) - pyl.height))
    crops = []
    for n in names:
        left, top = boxes[n]
        im = imgs[n]
        m = 22
        box = (max(0, left - m), max(0, top - m // 2), left + im.width + m, top + im.height + m // 2 + 6)
        crop = placed.crop(box)
        crops.append((n, crop.resize((crop.width * 3, crop.height * 3), Image.NEAREST)))
    cw2 = max(cr.width for _, cr in crops)
    chh = max(cr.height for _, cr in crops)
    sec2 = Image.new("RGBA", ((cw2 + pad) * 3 + pad, (chh + pad + 12) * 2 + pad), (28, 32, 36, 255))
    d2 = ImageDraw.Draw(sec2)
    for i, (n, cr) in enumerate(crops):
        col, row = i % 3, i // 3
        x0 = pad + col * (cw2 + pad)
        y0 = pad + row * (chh + pad + 12)
        d2.text((x0, y0 - 2), f"{n.replace('prop_', '')} on the Dam ground, x3 (game scale)", font=lab, fill=(235, 235, 235, 255))
        sec2.alpha_composite(cr, (x0, y0 + 10))
    # --- sectiunea 3: fasia de est (Shed, Bell, Kiln) la x3, in fata si ca stafii (cum se vad blocate), si cele doua halle din centru
    strip_box = (round(2480 / 3.0), round(780 / 3.0), round(3070 / 3.0), round(1440 / 3.0))
    east = placed.crop(strip_box)
    ghosts = ground.copy()
    for n in GHOSTED:
        place(ghosts, ghost_of(imgs[n]), n)
    east_g = ghosts.crop(strip_box)
    ew = east.width * 3
    sec3 = Image.new("RGBA", (ew * 2 + pad * 3, east.height * 3 + pad * 2 + 12), (28, 32, 36, 255))
    d3 = ImageDraw.Draw(sec3)
    d3.text((pad, 2), "east strip, bought (x3)", font=lab, fill=(235, 235, 235, 255))
    d3.text((ew + pad * 2, 2), "east strip, ghost (locked: tint 26,32,42 at 48%)", font=lab, fill=(235, 235, 235, 255))
    sec3.alpha_composite(east.resize((ew, east.height * 3), Image.NEAREST), (pad, 12 + pad // 2))
    sec3.alpha_composite(east_g.resize((ew, east.height * 3), Image.NEAREST), (ew + pad * 2, 12 + pad // 2))
    W_ = max(sec1.width, sec2.width, sec3.width)
    sheet = Image.new("RGBA", (W_, sec1.height + sec2.height + sec3.height), (28, 32, 36, 255))
    sheet.alpha_composite(sec1, (0, 0))
    sheet.alpha_composite(sec2, (0, sec1.height))
    sheet.alpha_composite(sec3, (0, sec1.height + sec2.height))
    path = os.path.join(out_dir, "halls_preview.png")
    sheet.save(path)
    return path


def main():
    out = DEFAULT_OUT
    only = None
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1]
    os.makedirs(out, exist_ok=True)
    imgs = {}
    for name, draw in SPRITES.items():
        if only and only not in name:
            continue
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png_to(os.path.join(out, name + ".png"), c)
        imgs[name] = to_image(c)
        print("  scris", name, f"{c.w}x{c.h}")
        if name == "prop_crystal_kiln":
            sx, sy = smoke_at(c)
            print(f"    SMOKE_AT.kiln.own = {{{sx:.3f}, {sy:.3f}}}")
    if len(imgs) == len(SPRITES):
        print("previzualizare:", preview(out, imgs))


def png_to(path, c):
    """Scrie PNG-ul nativ (RGBA, 8 biti) cu acelasi scriitor ca restul conductei; calea absoluta ocoleste OUT din buildings."""
    png(path, c.w, c.h, c.px)


if __name__ == "__main__":
    main()
