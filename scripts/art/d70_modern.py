#!/usr/bin/env python3
"""[D70] Satul vechi se modernizeaza in Era 3, in cinci trepte (docs/PLAN-HARTA.md, sectiunea 5). Doar desen: treapta
se citeste din stare (ModernMath.stage), simulatorul nu se atinge.

Regula de aspect: e ACELASI sat care primeste tabla, caramida, fier si sticla, nu alt joc. Fiecare cladire isi pastreaza
silueta, firma, continutul si culoarea acoperisului (taverna ramane albastra, gaterul rosiatic, forja verde), iar
lucrurile de care se leaga codul stau pe aceiasi pixeli: hornul tavernei (47, 0) si al forjei (49, 0), usa tavernei
(x 35..45, locul de vanzare), golul forjei (x 29..58, focul si scanteile), panza gaterului (29.5, 17.5).

  Treapta 1, Clerk (~4 min): "Wire comes to every street"
    prop_wire_pole         16x54  x3  stalpul liniei: lemn gudronat, traversa in perspectiva, doi izolatori de portelan
    prop_wire_pole_end     28x54  x3  stalpul de capat: acelasi, cu transformatorul si ancora (sarma de ancorare)
                                      spre STANGA; doar la capatul de vest (la est linia se opreste pe un stalp de
                                      linie si urca la Power House; oglindirea ramane pentru alta harta)
    firul dintre stalpi il deseneaza codul (vezi WIRE mai jos)
  Treapta 2, Thirteenth Net (~14 min): "Iron carts"
    prop_barrow_iron       72x20      inlocuieste prop_barrow pixel-la-pixel ca geometrie: aceleasi trei cadre de 24x20
                                      (lateral / spre tine / de la tine), aceleasi manere, roata la (19, 16), gura cutiei
                                      pe aceleasi randuri (incarcatura 16x9 cade la fel)
  Treapta 3, Second Works Porter (~19 min): "Tin roofs and brick"
    prop_storage_modern         40x32  (inlocuieste prop_storage)
    prop_sawmill_modern         40x32  (prop_sawmill)          prop_sawmill_grand_modern   40x32 (prop_sawmill_grand)
    prop_tavern_modern          64x48  (prop_tavern)           prop_tavern_grand_modern    64x48 (prop_tavern_grand)
    prop_scrap_shed_modern      40x32  (prop_scrap_shed)
    prop_workshop_modern        64x48  (prop_workshop_e1)      prop_workshop_grand_modern  64x48 (prop_workshop_grand)
  Treapta 4, Power House (~41 min): geamuri, planurile barajului, tarusii
    prop_windows_glass    320x204      ATLAS: pentru fiecare casa (Era 1, Moara, Wire Works) un strat de aceeasi marime cu
                                       casa, cu DOAR ferestrele ei noi (rama alba, sticla). Se pune peste casa, pe acelasi
                                       loc; ce statea in fata ferestrei (roaba, franghia) ramane in fata. WINDOW_CELLS.
    prop_dam_plans         48x44  x2  masa de desen cu planul barajului (albastru), lampa, rulourile
    prop_survey_stakes     36x26  x2  fasie de 3 cadre de 12x26: tarus cu stegulet rosu, tarus cu panglica, nivela
  Treapta 5, primul curent vandut (~48 min): "The village lights up"
    prop_windows_lit      320x204      ATLAS ca mai sus: ferestrele aprinse (lumina electrica) si lumina lor pe perete
    prop_modern_lit       256x96       ATLAS: pentru fiecare cladire moderna un strat cu becurile firmelor si lampile
                                       aprinse. MODERN_LIT_CELLS.
  Optional, curtea goala din mijlocul Wire Works (x ~3940..4620, y ~1040..1320):
    prop_cable_drums       48x32  x3  tamburi de cablu, unul in picioare, unul culcat, cabluri desfacute
    prop_substation        56x48  x3  statia mica: transformatorul pe soclu de caramida, portalul cu izolatori, gardul

Aceleasi reguli ca restul conductei: culorile din palette.ramp() si din rampele vecinilor (d67_works, d65_mill), umbra din
elipse translucide, conturul trasat automat, lumina din stanga-sus, niciodata negru pur.
Scrie DOAR nume noi in assets/sprites si nu suprascrie nimic (nici macar cu --force un nume care nu e al lui D70).

Rulare: python3 scripts/art/d70_modern.py [--force] [nume ...]   (scrie PNG-urile)
        python3 scripts/art/d70_modern.py luau                   (tabelele pentru cod: celulele atlaselor, ancorele)
        apoi: python3 scripts/art/preview_d70.py                 (plansele, in scratchpad)
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, Rng, shadow  # noqa: E402
from palette import WOOD, STONE, OUTLINE, ramp, mix  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import RUST, CREAM, AWNING, GLAZE  # noqa: E402
from tycoon_e1 import PLANK, LOGW, STEEL, GOLD, GOLD_HI, WARM, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import tycoon_e1  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import d62_grand as G  # noqa: E402
import d65_crew  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_crew  # noqa: E402
import d67_works as W  # noqa: E402

# in worktree-ul in care ruleaza scriptul (nu in calea scrisa de mana a Mac-ului, ca d55 / d65_mill)
OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites")

# ---------------------------------------------------------------------------------------------
# materialele: ale vecinilor, plus tablele vopsite in culoarea acoperisului vechi (identitatea ramane)

IRON, SOOT, GLASS, BRASS, SPARK, SIGNAL = W.IRON, W.SOOT, W.GLASS, W.BRASS, W.SPARK, W.SIGNAL
BRICK, MORTAR, TIN, COPPER = M.BRICK, M.MORTAR, M.TIN, M.COPPER
TIRE = d55.TIRE
# caramida noua a satului: mai deschisa si mai portocalie decat a Morii (M.BRICK), ca zidurile sa ramana la fel de luminoase
# ca barnele de azi si satul sa nu devina a doua Moara
NEW_BRICK = ramp(18, 0.50, 0.64, hue_shift=8)
BLUE_TIN = ramp(208, 0.30, 0.54, val_span=0.40)  # taverna: ardezia albastra devine tabla faltuita albastra
RED_TIN = ramp(10, 0.46, 0.54, val_span=0.40)  # gaterul: sindrila rosiatica devine tabla ondulata rosie
GREEN_TIN = ramp(150, 0.26, 0.48, val_span=0.40)  # forja: acoperisul verde ramane verde, din tabla
CREOSOTE = ramp(26, 0.42, 0.34, val_span=0.30)  # stalpul liniei: lemn gudronat
PAPER = ramp(212, 0.66, 0.66, hue_shift=6, val_span=0.30)  # planul barajului: hartie albastra
FLAG = G.FLAG_RED
ENAMEL = ramp(218, 0.52, 0.34, val_span=0.30)  # firmele emailate: bleumarin inchis, becurile ies pe el
BULB_OFF = (138, 134, 126, 255)  # bec stins: sticla fumurie (se vede ca e stins, nu doar mai palid)
BULB_ON = (255, 240, 168, 255)  # bec aprins, cald
LIGHT = ramp(46, 0.52, 0.98, val_span=0.14)  # lumina electrica din ferestre: mai alba decat flacara (WARM)


def canvas(w, h):
    return C(w, h)


def rivets(c, x0, x1, y, tone, step=3):
    for x in range(x0, x1 + 1, step):
        c.put(x, y, tone)


def quoins(c, x_left, x_right, y0, y1):
    """Coltarii de piatra ai unui zid de caramida: blocuri de 3 randuri, alternativ lungi si scurte."""
    for k, y in enumerate(range(y0, y1, 3)):
        wl = 3 if k % 2 == 0 else 2
        h = min(2, y1 - y)
        c.rect(x_left, y, wl, h, STONE[3])
        c.put(x_left, y, STONE[4])
        c.rect(x_right - wl + 1, y, wl, h, STONE[2])
        c.put(x_right, y, STONE[1])


def plinth(c, x0, x1, y, rows=2):
    """Soclul de piatra (acelasi desen ca temelia din d62_grand)."""
    G.foundation(c, x0, x1, y, rows)


def seam_roof(c, spans, tones):
    """Tabla faltuita (standing seam): faltul luminat la fiecare 4 px, fata plata, umbra dinaintea faltului urmator.
    `spans` = [(y, x0, x1_exclusiv)] de sus in jos; randurile de jos sunt putin mai inchise (streasina)."""
    n = len(spans)
    for i, (y, x0, x1) in enumerate(spans):
        low = i >= n * 0.6
        for x in range(x0, x1):
            k = x % 4
            if k == 0:
                tone = tones[4] if not low else tones[3]
            elif k == 3:
                tone = tones[1]
            else:
                tone = tones[2] if low else tones[3]
            c.put(x, y, tone)


def corrugated(c, x0, x1, y0, rows, tones=TIN, slope=0):
    """Tabla ondulata (nervuri la 3 px). `slope`: cu cati pixeli coboara spre dreapta."""
    for x in range(x0, x1):
        drop = int(slope * (x - x0) / max(1, x1 - x0 - 1))
        k = (x - x0) % 3
        tone = tones[3] if k == 0 else (tones[2] if k == 1 else tones[1])
        c.rect(x, y0 + drop, 1, rows, tone)
        c.put(x, y0 + drop, tones[4] if k == 0 else tones[3])


def glass_pane(c, x, y, w, h, inside=None):
    """Sticla: reflexia cerului sus, `inside` (lumina din casa) jos, o sclipire in diagonala in coltul stang-sus."""
    for yy in range(h):
        if inside is not None and yy >= h // 2:
            tone = inside[3] if yy == h // 2 else inside[2]
        else:
            tone = GLASS[3] if yy == 0 else GLASS[2]
        c.rect(x, y + yy, w, 1, tone)
    c.put(x, y, GLASS[4])
    if w > 2 and h > 1:
        c.put(x + 1, y, GLASS[4])
        c.put(x, y + 1, GLASS[4])


def bulb(c, x, y, lit):
    c.put(x, y, BULB_ON if lit else BULB_OFF)


def pendant(c, x, y, lit, cord=2):
    """Bec cu abajur de fier, atarnat: firul, abajurul (3 lat) si becul sub el."""
    c.rect(x, y, 1, cord, IRON[0])
    c.rect(x - 1, y + cord, 3, 1, IRON[3])
    c.put(x - 1, y + cord, IRON[4])
    c.put(x, y + cord + 1, BULB_ON if lit else BULB_OFF)
    if lit:
        c.put(x - 1, y + cord + 1, mix(BULB_ON, WARM[3], 0.5))
        c.put(x + 1, y + cord + 1, mix(BULB_ON, WARM[3], 0.5))


def glow(c, cx, cy, r, strength=0.45, tone=None):
    """Lumina pe perete: amesteca pixelii OPACI din jur spre cald, cu cat mai aproape, cu atat mai mult."""
    tone = tone or LIGHT[4]
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if not (0 <= x < c.w and 0 <= y < c.h):
                continue
            p = c.px[y][x]
            if p[3] < 255:
                continue
            d = math.hypot(x - cx, y - cy) / r
            if d < 1:
                c.px[y][x] = mix(p, tone, strength * (1 - d) ** 1.5)


def sign_bulbs(c, x0, y0, x1, y1, lit, step=2):
    """Becurile de pe rama unei firme (x0..x1, y0..y1 inclusiv), unul din doi pixeli."""
    for x in range(x0, x1 + 1, step):
        bulb(c, x, y0, lit)
        bulb(c, x, y1, lit)
    for y in range(y0 + step, y1, step):
        bulb(c, x0, y, lit)
        bulb(c, x1, y, lit)


# ---------------------------------------------------------------------------------------------
# TREAPTA 1: stalpii liniei. Firul il trage codul intre izolatori.
#
# Traversa e desenata IN PERSPECTIVA (capatul din fata mai jos si la stanga, cel din spate mai sus si la dreapta), ca
# cele doua fire sa mearga paralel pe strada la inaltimi diferite. O traversa frontala ar fi pus firele unul peste altul.

POLE_W, POLE_H = 16, 54
# punctele de prindere ale firelor, in pixeli de foaie (varful izolatorului, unde sta firul)
POLE_WIRES = {"near": (3, 11), "far": (12, 6)}
END_W = 28
END_POLE_DX = 12  # stalpul de capat e mutat 12 px spre dreapta in foaia lui (ancora sta in stanga)


def _pole(c, px, lit=False):
    """Stalpul, cu mijlocul la x=px+1 (3 lat), de la randul 6 pana la baza (53)."""
    soft_shadow(c, px + 1, 52, 5, 1.4)
    c.rect(px, 7, 3, 46, CREOSOTE[2])
    c.rect(px, 7, 1, 46, CREOSOTE[4])
    c.rect(px + 2, 7, 1, 46, CREOSOTE[0])
    for y in range(12, 50, 5):  # crapaturile lemnului
        c.put(px + 1, y, CREOSOTE[1])
    c.rect(px, 6, 3, 1, IRON[2])  # capacul de tabla
    c.put(px + 1, 5, IRON[3])
    for k, y in enumerate(range(24, 48, 4)):  # treptele de urcat (pironii)
        c.put(px - 1 if k % 2 == 0 else px + 3, y, IRON[1])
    c.rect(px, 49, 3, 4, CREOSOTE[1])  # talpa, mai inchisa (umeda)
    # placuta emailata cu numarul stalpului
    c.rect(px, 30, 3, 3, ENAMEL[3])
    c.put(px + 1, 31, CREAM[4])
    # traversa: de la (px-6, 15) la (px+6, 10), 2 groasa, cu contrafisele de fier
    tx0, tx1 = px - 5, px + 7
    line(c, tx0, 14, tx1, 9, WOOD[1], 2)
    line(c, tx0, 14, tx1, 9, WOOD[3], 1)
    line(c, px - 3, 14, px, 19, IRON[1], 1)
    line(c, px + 5, 11, px + 2, 18, IRON[1], 1)
    # izolatorii pe pini, la capete
    W.insulator(c, POLE_WIRES["near"][0], POLE_WIRES["near"][1] - 1)
    W.insulator(c, POLE_WIRES["far"][0], POLE_WIRES["far"][1] - 1)


def prop_wire_pole():
    c = canvas(POLE_W, POLE_H)
    _pole(c, 7)
    outline_trace(c)
    return c


def _thin_line(c, x0, y0, x1, y1, col):
    """O sarma subtire, trasa DUPA contur si doar pe transparent: trasa inainte, conturul ar fi facut-o de trei pixeli."""
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(steps + 1):
        t = i / steps
        x, y = round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t)
        if 0 <= x < c.w and 0 <= y < c.h and c.px[y][x][3] == 0:
            c.put(x, y, col)


def prop_wire_pole_end():
    """Stalpul de capat: acelasi stalp, cu transformatorul (cutia de fier cu doi izolatori mici) prins pe dreapta si
    sarma de ancorare spre stanga, cu izolatorul-ou pe ea si ancora in pamant."""
    c = canvas(END_W, POLE_H)
    dx = END_POLE_DX
    soft_shadow(c, 4, 51, 4, 1.0)
    c.rect(2, 50, 4, 2, STONE[2])  # blocul ancorei
    c.rect(2, 50, 4, 1, STONE[3])
    base = canvas(POLE_W, POLE_H)
    _pole(base, 7)
    for y in range(POLE_H):
        for x in range(POLE_W):
            p = base.px[y][x]
            if p[3]:
                c.put(x + dx, y, p)
    # transformatorul: cutie de fier cu nervuri, prinsa cu doua coliere, doi izolatori mici pe capac
    px = dx + 7
    tx, ty = px + 3, 20
    c.rect(px + 3, ty + 1, 1, 1, IRON[1])
    c.rect(px + 3, ty + 8, 1, 1, IRON[1])
    c.rect(tx + 1, ty, 6, 11, IRON[2])
    c.rect(tx + 1, ty, 6, 1, IRON[4])
    c.rect(tx + 1, ty, 1, 11, IRON[3])
    c.rect(tx + 6, ty, 1, 11, IRON[0])
    for x in (tx + 3, tx + 5):
        c.rect(x, ty + 2, 1, 8, IRON[1])
    c.rect(tx + 1, ty + 10, 6, 1, IRON[0])
    c.put(tx + 2, ty + 4, BRASS[3])
    for bx in (tx + 2, tx + 5):
        c.rect(bx, ty - 2, 1, 2, CREAM[3])
        c.put(bx, ty - 2, CREAM[4])
    outline_trace(c)
    # dupa contur: sarma de ancorare (cu izolatorul-ou) si legatura de cupru a transformatorului, subtiri
    gx0, gy0, gx1, gy1 = px - 1, 16, 4, 49
    _thin_line(c, gx0, gy0, gx1, gy1, IRON[0])
    ex, ey = round(gx0 + (gx1 - gx0) * 0.33), round(gy0 + (gy1 - gy0) * 0.33)  # izolatorul-ou, pe sarma
    c.rect(ex - 1, ey - 1, 2, 3, CREAM[3])
    c.put(ex - 1, ey - 1, CREAM[4])
    c.put(ex, ey + 1, CREAM[1])
    c.put(4, 49, IRON[2])
    _thin_line(c, tx + 5, ty - 3, POLE_WIRES["far"][0] + dx + 1, POLE_WIRES["far"][1] + 1, COPPER[1])
    return c


# Firul, pentru cod (pixeli de foaie x Assets.PIXEL_SCALE = pixeli de lume):
WIRE = {
    "color_near": IRON[0],  # firul din fata (izolatorul de jos)
    "color_far": IRON[1],  # firul din spate, putin mai deschis (e mai departe)
    "thickness_world_px": 2,
    "sag_fraction": 0.03,  # sageata la mijloc = 3% din deschidere (la 300 px: 9 px); la 6% atingea numele tarabelor
}


# ---------------------------------------------------------------------------------------------
# TREAPTA 2: caruciorul de fier. Aceeasi fasie ca d55.prop_barrow (3 x 24x20), aceleasi ancore:
#   lateral:   manerul la (0, 13), piciorul la (9..10, 15..18), roata (19, 16) r3, gura cutiei pe randul 8 (x 5..21)
#   spre tine: capetele manerelor (9|15, 2), gura pe randul 7 (x 6..18), roata (11..12, 13..18)
#   de la tine: varful rotii (11, 0), gura din spate pe randurile 9..10, manerele pana la (7|16, 19)

BW, BH = d55.BW, d55.BH


def _iron_wheel_side(c, cx, cy, r):
    """Roata cu spite de fier si banda de cauciuc: obada inchisa, janta de otel, patru spite, butucul de alama."""
    c.ellipse(cx, cy, r + 0.6, r + 0.6, TIRE[0])
    c.ellipse(cx, cy, r - 0.4, r - 0.4, STEEL[1])
    c.ellipse(cx, cy, r - 1.2, r - 1.2, TIRE[1])
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for k in range(1, int(r)):
            c.put(round(cx + dx * k), round(cy + dy * k), STEEL[3])
    c.put(round(cx), round(cy), BRASS[3])
    c.put(round(cx - 1), round(cy - 3), STEEL[4])  # lumina pe obada, sus-stanga


def barrow_iron_side():
    c = canvas(BW, BH)
    soft_shadow(c, 13, 18, 9, 2)
    line(c, 8, 14, 1, 13, STEEL[2], 1)  # manerele: teava de otel
    line(c, 8, 15, 1, 14, IRON[1], 1)
    c.rect(0, 13, 2, 2, TIRE[1])  # manerul imbracat in cauciuc
    c.put(0, 13, TIRE[3])
    c.rect(9, 15, 2, 4, IRON[1])  # piciorul, platbanda de fier
    c.put(9, 15, IRON[3])
    c.rect(8, 18, 3, 1, IRON[0])
    for y in range(8, 15):  # cuva de tabla presata: aceeasi forma, rotunjita jos
        t = (y - 8) / 6
        xa = round(5 + 3 * t)
        xb = round(21 - 3 * t)
        c.rect(xa, y, xb - xa + 1, 1, IRON[3] if y < 11 else IRON[2])
    c.rect(5, 8, 17, 1, STEEL[4])  # buza rasfranta, lucioasa
    c.put(21, 7, STEEL[4])
    c.put(22, 7, STEEL[3])
    c.rect(6, 9, 15, 1, IRON[0])  # interiorul, in umbra
    rivets(c, 7, 19, 11, IRON[4], 4)  # niturile de pe flanc
    c.rect(6, 12, 14, 1, IRON[2])
    c.rect(9, 13, 11, 1, IRON[1])
    c.rect(8, 14, 12, 1, IRON[0])
    c.put(8, 13, IRON[1])
    line(c, 17, 14, 19, 16, STEEL[1], 1)  # furca rotii
    _iron_wheel_side(c, 19, 16, 3)
    outline_trace(c)
    return c


def barrow_iron_front():
    c = canvas(BW, BH)
    soft_shadow(c, 12, 18, 6, 2)
    line(c, 9, 2, 9, 7, STEEL[2], 1)
    line(c, 15, 2, 15, 7, STEEL[2], 1)
    c.put(9, 2, TIRE[1])  # capetele imbracate in cauciuc
    c.put(15, 2, TIRE[1])
    c.put(9, 3, TIRE[1])
    c.put(15, 3, TIRE[1])
    for y in range(7, 14):
        t = (y - 7) / 6
        xa = round(6 + 2 * t)
        xb = round(18 - 2 * t)
        c.rect(xa, y, xb - xa + 1, 1, IRON[3] if y < 10 else IRON[2])
        c.put(xa, y, IRON[4])  # muchia stanga, in lumina
        c.put(xb, y, IRON[1])
    c.rect(6, 7, 13, 1, STEEL[4])
    c.rect(7, 8, 11, 1, IRON[0])
    rivets(c, 8, 17, 10, IRON[4], 3)
    c.rect(9, 13, 7, 1, IRON[1])
    line(c, 9, 13, 11, 15, STEEL[1], 1)  # furca
    line(c, 15, 13, 13, 15, STEEL[1], 1)
    c.rect(11, 13, 2, 6, TIRE[0])  # roata, din fata: cauciuc cu janta
    c.rect(11, 14, 1, 4, STEEL[3])
    outline_trace(c)
    return c


def barrow_iron_back():
    c = canvas(BW, BH)
    soft_shadow(c, 12, 8, 7, 2)
    c.rect(11, 0, 2, 2, TIRE[0])  # varful rotii, departe
    c.put(11, 0, STEEL[3])
    for y in range(2, 9):
        t = (y - 2) / 6
        xa = round(5 + 1 * t)
        xb = round(18 - 1 * t)
        c.rect(xa, y, 2, 1, IRON[3])
        c.rect(xb - 1, y, 2, 1, IRON[1])
    c.rect(6, 2, 12, 1, STEEL[3])  # buza din fata (departe)
    c.rect(7, 3, 10, 5, IRON[0])  # fundul cuvei, in umbra
    c.rect(8, 4, 8, 1, IRON[1])  # nervura presata din fund
    c.rect(5, 9, 14, 2, IRON[3])  # buza din spate, spre tine
    c.rect(5, 9, 14, 1, STEEL[4])
    c.rect(6, 11, 12, 1, IRON[1])
    for x0, x1 in ((8, 7), (15, 16)):  # manerele, teava de otel
        line(c, x0, 12, x1, 19, STEEL[2], 1)
        line(c, x0 + (1 if x0 < 12 else -1), 12, x1 + (1 if x1 < 12 else -1), 19, IRON[1], 1)
    for x in (7, 16):  # capetele imbracate in cauciuc
        c.put(x, 18, TIRE[1])
        c.put(x, 19, TIRE[1])
    outline_trace(c)
    return c


def prop_barrow_iron():
    return d55.strip([barrow_iron_side(), barrow_iron_front(), barrow_iron_back()])


# ---------------------------------------------------------------------------------------------
# TREAPTA 3: cladirile. Fiecare functie primeste `lit` (treapta 5: firmele si lampile electrice aprinse); atlasul
# prop_modern_lit e diferenta dintre cele doua desene.


def prop_storage_modern(lit=False):
    """Depozitul (40x32): aceeasi stiva de busteni sub acelasi acoperis, dar pe stalpi de fier, cu peretele din spate de
    caramida, acoperis de tabla ondulata cu jgheab si burlan, pardoseala de piatra si un bec in cusca sub streasina."""
    c = canvas(40, 32)
    shadow(c, 20, 29, 18, 2)
    M.bricks(c, 5, 13, 30, 14, NEW_BRICK)
    c.rect(3, 26, 34, 2, STONE[2])  # pardoseala
    c.rect(3, 26, 34, 1, STONE[3])
    for px in (3, 35):  # stalpii de fier, cu nituri
        c.rect(px, 8, 3, 20, IRON[2])
        c.rect(px, 8, 1, 20, IRON[4])
        c.rect(px + 2, 8, 1, 20, IRON[0])
        for y in range(11, 26, 4):
            c.put(px + 1, y, IRON[4])
    corrugated(c, 1, 39, 2, 6, TIN)  # acoperisul
    c.rect(0, 8, 40, 1, TIN[0])
    c.rect(0, 9, 40, 1, IRON[2])  # jgheabul
    rivets(c, 1, 39, 9, IRON[4], 5)
    c.rect(38, 10, 1, 17, IRON[1])  # burlanul, pe stalpul din dreapta
    c.put(38, 26, IRON[3])
    # becul in cusca, sub streasina, la mijloc
    c.rect(20, 10, 1, 1, IRON[1])
    c.rect(19, 11, 3, 2, IRON[1])
    c.put(20, 11, BULB_ON if lit else BULB_OFF)
    c.put(20, 12, BULB_ON if lit else BULB_OFF)
    if lit:
        glow(c, 20, 14, 7, 0.45)

    def log_end(cx, cy):
        c.ellipse(cx, cy, 3.1, 3.1, LOGW[0])
        c.ellipse(cx, cy, 2.5, 2.5, LOGW[3])
        c.ellipse(cx, cy, 1.4, 1.4, LOGW[2])
        c.put(round(cx), round(cy), LOGW[1])

    for x in (9, 15, 21, 27, 31):
        log_end(x, 24)
    for x in (12, 18, 24, 30):
        log_end(x, 19)
    for x in (15, 21, 27):
        log_end(x, 14.5)
    outline_trace(c)
    return c


def prop_sawmill_modern(lit=False, grand=False):
    """Gaterul (40x32): aceeasi hala deschisa, acum cu peretele din spate de caramida si o fereastra cu geam, stalpi de
    fier, acoperis de tabla ondulata ROSIE (fosta sindrila) cu jgheab, capra de fier, pardoseala de piatra. Panza sta
    exact unde era. `grand` (nivel 25+): steguletul, al doilea bustean, stiva de scanduri, lampa de pe stalp."""
    c = canvas(40, 32)
    shadow(c, 20, 29, 18, 2)
    M.bricks(c, 4, 10, 32, 17, NEW_BRICK)
    # fereastra din peretele din spate, deasupra busteanului
    c.rect(9, 11, 8, 6, CREAM[2])
    glass_pane(c, 10, 12, 6, 4)
    c.rect(13, 12, 1, 4, CREAM[3])
    c.rect(9, 17, 8, 1, STONE[3])
    plinth(c, 2, 38, 26, 2)
    for px in (3, 35):  # stalpii de fier
        c.rect(px, 9, 3, 19, IRON[2])
        c.rect(px, 9, 1, 19, IRON[4])
        c.rect(px + 2, 9, 1, 19, IRON[0])
        for y in range(12, 26, 4):
            c.put(px + 1, y, IRON[4])
    # acoperisul: aceeasi forma in trepte, din tabla ondulata rosie
    for i in range(8):
        inset = max(0, 6 - i)
        x0, x1 = 1 + inset // 2, 1 + inset // 2 + 38 - inset
        for x in range(x0, x1):
            k = x % 3
            tone = RED_TIN[3] if k == 0 else (RED_TIN[2] if k == 1 else RED_TIN[1])
            if i == 0:
                tone = RED_TIN[4] if k == 0 else RED_TIN[3]
            c.put(x, 2 + i, tone)
    c.rect(0, 9, 40, 1, RED_TIN[0])
    c.rect(0, 10, 40, 1, IRON[2])  # jgheabul
    rivets(c, 1, 39, 10, IRON[4], 5)
    if grand:
        c.rect(4, 2, 32, 1, RED_TIN[4])  # coama de tabla lucioasa
        G.pennant(c, 8, 0, G.FLAG_RED)
    # capra de fier si busteanul
    c.rect(8, 22, 2, 5, IRON[1])
    c.rect(19, 22, 2, 5, IRON[1])
    c.rect(7, 21, 15, 2, IRON[3])
    c.rect(7, 21, 15, 1, IRON[4])
    c.ellipse(15, 19, 8, 2.6, LOGW[1])
    c.ellipse(15, 18.4, 7, 1.8, LOGW[2])
    c.rect(9, 17, 13, 1, LOGW[3])
    c.ellipse(8, 19, 2.0, 2.6, LOGW[4])
    c.ellipse(8, 19, 1.0, 1.4, LOGW[2])
    # panza, cu axul de fier si carcasa motorului dedesubt
    c.rect(29, 14, 1, 13, IRON[0])
    c.rect(27, 23, 6, 3, IRON[2])
    c.rect(27, 23, 6, 1, IRON[4])
    c.put(28, 24, BRASS[3])
    tycoon_e1._blade(c, 29.5, 17.5, 4.6, teeth=8)
    # scandurile gata
    if grand:
        c.ellipse(15, 25.5, 7, 1.8, LOGW[1])  # al doilea bustean, la rand
        c.ellipse(15, 25.0, 6, 1.2, LOGW[2])
        c.ellipse(9, 25.5, 1.6, 1.8, LOGW[4])
        for i in range(2):
            c.rect(23 + i, 25 - i * 2, 12 - i, 2, PLANK[3] if i % 2 else PLANK[2])
            c.rect(23 + i, 25 - i * 2, 12 - i, 1, PLANK[4])
            c.put(23 + i, 26 - i * 2, PLANK[1])
            c.put(34, 26 - i * 2, PLANK[1])
    else:
        c.rect(24, 24, 9, 2, PLANK[3])
        c.rect(24, 24, 9, 1, PLANK[4])
    # lampa cu abajur, atarnata de grinda, deasupra capra (electrica: se aprinde la treapta 5)
    pendant(c, 15, 11, lit, cord=2)
    if lit:
        glow(c, 15, 15, 7, 0.4)
    if grand:
        G.lantern(c, 4, 12)  # felinarul de pe stalp ramane: e al nivelului 25
    outline_trace(c)
    return c


def prop_sawmill_grand_modern(lit=False):
    return prop_sawmill_modern(lit, grand=True)


def prop_tavern_modern(lit=False, grand=False):
    """Taverna (64x48): aceeasi casa si acelasi acoperis albastru, dar din caramida cu coltari de piatra si tabla
    faltuita, cu jgheab si burlan; hornul de caramida pe acelasi loc (fumul: 47, 0); fereastra-tejghea cu geamuri, rama de
    fier si o copertina in dungi ca la taraba Innkeeper-ului; usa pe acelasi loc (x 35..45), cu geam in ea; firma cu cana
    si moneda pe email bleumarin, cu becuri pe rama (aprinse la treapta 5). `grand`: lucarna luminata, stegulete,
    jardiniera, al doilea felinar, steag pe coama."""
    c = canvas(64, 48)
    shadow(c, 32, 45, 30, 2)
    M.bricks(c, 4, 18, 56, 25, NEW_BRICK)
    quoins(c, 3, 60, 19, 43)
    plinth(c, 3, 61, 43, 2)
    # acoperisul: acelasi trapez in trepte, tabla faltuita albastra
    seam_roof(c, [(4 + i, 14 - i, 64 - (14 - i)) for i in range(14)], BLUE_TIN)
    c.rect(1, 17, 62, 1, BLUE_TIN[0])
    c.rect(1, 18, 62, 1, IRON[2])  # jgheabul
    rivets(c, 2, 62, 18, IRON[4], 5)
    c.rect(14, 3, 36, 1, BLUE_TIN[4])  # coama
    c.rect(2, 19, 1, 25, IRON[1])  # burlanul, in coltul din stanga
    c.put(2, 19, IRON[3])
    c.rect(1, 43, 2, 1, IRON[2])
    # hornul: caramida, capac de piatra, acelasi loc
    M.bricks(c, 44, 1, 6, 8, NEW_BRICK)
    c.rect(43, 0, 8, 1, STONE[3])
    c.rect(44, 1, 6, 1, STONE[1])
    if grand:
        # lucarna: fronton mic de tabla, fereastra aprinsa, in stanga hornului
        for i in range(6):  # fronton mic de tabla, cu muchiile luminate
            c.rect(22 - i, 6 + i, 2 + 2 * i, 1, BLUE_TIN[1] if i % 2 else BLUE_TIN[0])
            c.put(22 - i, 6 + i, BLUE_TIN[4])
            c.put(23 + i, 6 + i, BLUE_TIN[2])
        c.rect(18, 12, 10, 5, CREAM[2])
        c.rect(18, 12, 10, 1, CREAM[4])
        c.rect(19, 13, 8, 4, WARM[3])  # fereastra aprinsa (lampa din pod)
        c.rect(19, 13, 8, 1, WARM[4])
        c.put(19, 13, GLASS[4])
        c.rect(23, 13, 1, 4, CREAM[3])
        G.pennant(c, 30, 0, G.FLAG_BLUE)
    # fereastra-tejghea: rama de fier, geamuri cu lumina calda dinauntru, bara de sus cu ochiuri mici
    c.rect(8, 24, 19, 11, IRON[1])
    c.rect(9, 25, 17, 9, WARM[3])
    c.rect(9, 25, 17, 2, WARM[4])
    for x0 in (9, 18):  # sclipirea geamului, in coltul fiecarui ochi mare
        c.put(x0, 28, GLASS[4])
        c.put(x0 + 1, 28, mix(GLASS[4], WARM[4], 0.5))
        c.put(x0, 29, mix(GLASS[4], WARM[4], 0.5))
    c.rect(9, 27, 17, 1, IRON[2])  # bara ferestruicilor de sus
    for x in (13, 21):
        c.rect(x, 25, 1, 2, IRON[2])
    c.rect(17, 25, 1, 9, IRON[2])
    c.rect(7, 34, 21, 2, STONE[3])  # tejgheaua de piatra
    c.rect(7, 34, 21, 1, STONE[4])
    for mx in (11, 20):  # canile, la locul lor
        c.rect(mx, 31, 3, 3, PLANK[2])
        c.rect(mx, 31, 3, 1, tycoon_e1.FOAM[4])
        c.put(mx + 3, 32, PLANK[1])
    # copertina in dungi deasupra ferestrei (rosu si crem, ca taraba)
    for i in range(4):
        y, x0, w = 20 + i, 7 - (i // 2), 21 + (i // 2) * 2
        for k in range(w):
            band = ((x0 + k) // 3) % 2
            c.put(x0 + k, y, AWNING[2 + (1 if i == 0 else 0)] if band == 0 else CREAM[3 if i == 0 else 2])
    for k, x in enumerate(range(6, 29, 3)):  # marginea cu festoane
        col = AWNING[1] if k % 2 == 0 else CREAM[1]
        c.rect(x, 24, 2, 1, col)
    c.rect(6, 20, 1, 4, IRON[1])  # bratele copertinei
    c.rect(28, 20, 1, 4, IRON[1])
    # usa: acelasi loc, ancadrament de piatra, usa verde-inchis cu geam sus si clanta de alama
    c.rect(35, 29, 10, 16, STONE[3])
    c.rect(35, 29, 10, 1, STONE[4])
    c.rect(36, 30, 8, 15, ramp(160, 0.40, 0.30)[2])
    c.rect(36, 30, 1, 15, ramp(160, 0.40, 0.30)[3])
    c.rect(37, 31, 6, 5, IRON[1])
    glass_pane(c, 38, 32, 4, 3, inside=WARM)
    for y in (38, 42):
        c.rect(37, y, 6, 1, ramp(160, 0.40, 0.30)[1])
    c.put(42, 37, BRASS[4])
    # felinarul de langa usa ramane (flacara, nu bec)
    c.rect(32, 28, 2, 1, IRON[0])
    c.rect(32, 29, 2, 3, WARM[4])
    c.put(32, 32, IRON[0])
    # firma: bratul de fier, lanturile, email bleumarin cu cana si moneda, rama de alama cu becuri
    c.rect(46, 19, 14, 1, IRON[1])
    c.put(48, 20, IRON[0])
    c.put(57, 20, IRON[0])
    c.rect(46, 21, 14, 10, BRASS[1])
    c.rect(47, 22, 12, 8, ENAMEL[2])
    c.rect(47, 22, 12, 1, ENAMEL[3])
    c.rect(48, 23, 4, 5, tycoon_e1.FOAM[3])
    c.rect(48, 23, 4, 1, tycoon_e1.FOAM[4])
    c.rect(52, 24, 1, 3, tycoon_e1.FOAM[1])
    c.ellipse(55.5, 25.5, 2.2, 2.2, GOLD[2])
    c.ellipse(55.5, 25.5, 1.4, 1.4, GOLD_HI[3])
    c.put(55, 25, GOLD_HI[4])
    sign_bulbs(c, 46, 21, 59, 30, lit)
    if lit:
        c.rect(47, 22, 12, 1, ENAMEL[4])  # emailul prinde lumina becurilor
    # butoaiele, cu cercuri de otel
    for bx, by, h in ((48, 36, 9), (55, 38, 7)):
        c.rect(bx - 1, by - 1, 8, h + 1, OUTLINE)
        c.rect(bx, by, 6, h, LOGW[2])
        c.rect(bx + 1, by, 2, h, LOGW[3])
        c.rect(bx, by + 1, 6, 1, STEEL[2])
        c.rect(bx, by + h - 3, 6, 1, STEEL[2])
    # banca: scandura pe picioare de fier
    c.rect(8, 40, 18, 2, WOOD[3])
    c.rect(8, 40, 18, 1, WOOD[4])
    for x in (9, 24):
        c.rect(x, 42, 1, 3, IRON[1])
    if grand:
        # steguletele intre copertina si firma, jardiniera sub tejghea, al doilea felinar, coltul auriu al firmei
        G.bunting(c, 29, 44, 19)
        c.rect(8, 36, 19, 2, WOOD[1])
        for x in range(9, 26, 2):
            c.put(x, 36, G.LEAF[3])
            c.put(x + 1, 36, G.LEAF[2])
        for x, tone in ((10, G.FLAG_RED[4]), (14, GOLD_HI[4]), (18, G.FLAG_RED[4]), (22, GOLD_HI[4]), (25, G.FLAG_RED[4])):
            c.put(x, 35, tone)
        G.lantern(c, 6, 27)
    if lit:
        glow(c, 52.5, 25.5, 10, 0.3)
    outline_trace(c)
    return c


def prop_tavern_grand_modern(lit=False):
    return prop_tavern_modern(lit, grand=True)


def prop_scrap_shed_modern(lit=False):
    """Scrap Shed (40x32): acelasi sopron cu aceeasi gramada, dar drept si curat: pereti de tabla ondulata pe un brau de
    caramida, stalpi de fier, acoperis nou de tabla (fara rugina) cu jgheab, butoiul de otel, firma emailata cu roata
    dintata si doua becuri."""
    c = canvas(40, 32)
    rng = Rng(5520)  # aceeasi samanta ca shed-ul vechi: aceeasi gramada
    shadow(c, 20, 29, 18, 2)
    corrugated(c, 5, 35, 11, 9, TIN)  # peretii de tabla
    M.bricks(c, 5, 20, 30, 7, NEW_BRICK)
    for px in (3, 34):  # stalpii de fier, drepti acum
        c.rect(px, 9, 3, 19, IRON[2])
        c.rect(px, 9, 1, 19, IRON[4])
        c.rect(px + 2, 9, 1, 19, IRON[0])
    # acoperisul: aceeasi panta (3 -> 8), tabla noua
    for x in range(0, 40):
        top = round(3 + 5 * x / 39)
        k = x % 3
        c.rect(x, top, 1, 4, TIN[3] if k == 0 else (TIN[2] if k == 1 else TIN[1]))
        c.put(x, top, TIN[4] if k == 0 else TIN[3])
        c.put(x, top + 4, IRON[2])  # jgheabul, pe streasina
    # gramada dinauntru (aceleasi apeluri, aceeasi samanta)
    c.ellipse(19, 25, 11, 3, STONE[1])
    d55.scrap_bits(c, rng, 8, 17, 22, 8, 30)
    c.ellipse(24, 19, 3.3, 3.3, RUST[1])
    c.ellipse(24, 19, 2.2, 2.2, RUST[2])
    for dx, dy in ((0, -4), (4, 0), (0, 4), (-4, 0)):
        c.put(24 + dx, 19 + dy, RUST[1])
    c.put(24, 19, STONE[0])
    line(c, 9, 25, 15, 17, STONE[3], 1)
    # butoiul de otel, cu cercuri
    c.rect(0, 20, 5, 8, IRON[2])
    c.rect(0, 20, 5, 1, IRON[4])
    c.rect(0, 20, 1, 8, IRON[3])
    c.rect(0, 23, 5, 1, STEEL[3])
    c.rect(0, 26, 5, 1, STEEL[3])
    # firma emailata: roata dintata crem pe bleumarin, nituri de alama, doua becuri deasupra
    c.rect(15, 9, 10, 5, BRASS[1])
    c.rect(16, 10, 8, 3, ENAMEL[2])
    c.ellipse(20, 11.5, 1.6, 1.6, CREAM[3])
    c.put(20, 11, ENAMEL[2])
    for x in (15, 24):
        c.put(x, 9, BRASS[4])
    for x in (17, 22):
        bulb(c, x, 8, lit)
    if lit:
        glow(c, 20, 11, 5, 0.25)
    outline_trace(c)
    return c


def prop_workshop_modern(lit=False, grand=False):
    """Forja (64x48): aceeasi casa si acelasi acoperis verde, din caramida cu coltari si tabla faltuita; hornul de caramida
    pe acelasi loc (fumul: 49, 0); vitrina gasirilor cu rama de fier si geam; golul atelierului pe acelasi loc, acum cu
    grinda de fier nituita si oblonul rulat sus, cu un bec cu abajur (aprins la treapta 5); firma cu ciocanul pe email,
    cu becuri. `grand`: focul in vatra, lingoul incins, nicovala, steagul."""
    c = canvas(64, 48)
    shadow(c, 32, 45, 30, 2)
    M.bricks(c, 4, 19, 56, 24, NEW_BRICK)
    quoins(c, 3, 60, 20, 43)
    plinth(c, 3, 61, 43, 2)
    seam_roof(c, [(5 + i, 13 - i, 64 - (13 - i)) for i in range(14)], GREEN_TIN)
    c.rect(1, 18, 62, 1, GREEN_TIN[0])
    c.rect(1, 19, 62, 1, IRON[2])  # jgheabul
    rivets(c, 2, 62, 19, IRON[4], 5)
    c.rect(13, 4, 38, 1, GREEN_TIN[4])
    c.rect(61, 20, 1, 15, IRON[1])  # burlanul, in dreapta
    # hornul de caramida, cu brau de fier
    M.bricks(c, 46, 1, 6, 9, NEW_BRICK)
    c.rect(45, 0, 8, 1, STONE[3])
    c.rect(46, 5, 6, 1, IRON[2])
    if grand:
        G.pennant(c, 24, 1, G.FLAG_RED)
    # vitrina gasirilor
    c.rect(8, 25, 18, 11, IRON[1])
    c.rect(9, 26, 16, 9, WARM[2])
    c.rect(9, 26, 16, 2, WARM[3])
    c.put(9, 26, GLASS[4])
    c.put(10, 26, mix(GLASS[4], WARM[3], 0.5))
    c.rect(9, 31, 16, 1, IRON[2])  # polita de fier
    c.rect(11, 28, 2, 3, STEEL[2])
    c.put(11, 28, STEEL[4])
    c.ellipse(16, 29.5, 1.5, 1.5, GLAZE[2])
    c.put(15, 29, GLAZE[4])
    c.ellipse(21, 29, 1.8, 1.8, GOLD[2])
    c.put(20, 28, GOLD_HI[4])
    for sx, sy in ((23, 27), (19, 26), (24, 30)):
        c.put(sx, sy, GOLD_HI[3])
    c.rect(11, 33, 4, 1, PLANK[2])
    c.rect(18, 33, 5, 1, STEEL[1])
    c.rect(7, 35, 20, 2, STONE[3])  # pervazul de piatra
    c.rect(7, 35, 20, 1, STONE[4])
    # golul atelierului: interiorul in umbra (acelasi), rama de fier, grinda nituita, oblonul rulat
    c.rect(30, 25, 27, 20, WOOD[0])
    for y in range(28, 44, 4):
        c.rect(30, y, 27, 1, mix(WOOD[0], WOOD[1], 0.5))
    c.rect(29, 23, 2, 22, IRON[2])
    c.rect(29, 23, 1, 22, IRON[4])
    c.rect(56, 23, 2, 22, IRON[1])
    c.rect(28, 23, 31, 2, IRON[3])
    c.rect(28, 23, 31, 1, IRON[4])
    rivets(c, 30, 56, 24, IRON[1], 3)
    c.rect(31, 25, 25, 2, TIN[2])  # oblonul rulat
    c.rect(31, 25, 25, 1, TIN[3])
    c.rect(33, 28, 8, 2, STEEL[3])  # uneltele, la locul lor
    c.rect(33, 29, 8, 1, STEEL[1])
    c.rect(41, 28, 2, 2, WOOD[2])
    c.rect(46, 27, 1, 6, WOOD[3])
    c.rect(44, 27, 5, 2, STEEL[2])
    c.rect(51, 27, 2, 3, WARM[4])  # felinarul
    c.put(51, 30, WOOD[0])
    c.rect(31, 36, 25, 3, PLANK[3])  # bancul de lemn, cu muchie de fier
    c.rect(31, 36, 25, 1, PLANK[4])
    c.rect(31, 38, 25, 1, IRON[2])
    for x in (33, 53):
        c.rect(x, 39, 2, 6, IRON[1])
    c.rect(34, 32, 4, 4, STEEL[2])  # menghina
    c.rect(34, 32, 4, 1, STEEL[4])
    c.rect(38, 33, 2, 1, STEEL[1])
    if grand:
        c.rect(50, 31, 6, 5, STONE[1])  # vatra, cu focul
        c.rect(51, 32, 4, 4, G.EMBER[1])
        c.rect(51, 33, 4, 3, G.EMBER[3])
        c.rect(52, 34, 2, 2, GOLD_HI[4])
        c.put(51, 30, G.EMBER[4])
        c.put(54, 29, G.EMBER[3])
        c.rect(41, 34, 11, 2, WOOD[0])  # lingoul incins
        c.rect(43, 34, 7, 2, G.EMBER[2])
        c.rect(43, 34, 7, 1, G.EMBER[4])
        for x, y in ((40, 44), (45, 43), (48, 44), (37, 43)):
            c.put(x, y, G.EMBER[4])
    else:
        c.rect(41, 34, 11, 2, PLANK[2])  # scandura in lucru
        c.rect(41, 34, 11, 1, PLANK[4])
        for x, y in ((40, 44), (45, 43), (48, 44), (37, 43)):
            c.put(x, y, PLANK[4])
    c.rect(30, 43, 27, 2, STONE[1])  # pragul de piatra al golului
    c.rect(30, 43, 27, 1, STONE[2])
    # becul cu abajur, atarnat de grinda
    pendant(c, 38, 25, lit, cord=3)
    if lit:
        glow(c, 38, 30, 6, 0.3)
    # firma: email bleumarin, ciocanul de aur, rama de alama cu becuri
    c.rect(36, 19, 14, 6, BRASS[1])
    c.rect(37, 20, 12, 4, ENAMEL[2])
    c.rect(39, 22, 7, 1, GOLD[2])
    c.rect(44, 20, 3, 4, GOLD_HI[3])
    c.put(44, 20, GOLD_HI[4])
    for x in range(36, 50, 2):
        bulb(c, x, 19, lit)
    if lit:
        glow(c, 43, 21, 6, 0.2)
    if grand:
        c.rect(11, 40, 9, 2, STEEL[3])  # nicovala, in fata vitrinei
        c.rect(11, 40, 9, 1, STEEL[4])
        c.rect(19, 40, 3, 1, STEEL[3])
        c.rect(13, 42, 5, 1, STEEL[1])
        c.rect(12, 43, 7, 2, STEEL[2])
    outline_trace(c)
    return c


def prop_workshop_grand_modern(lit=False):
    return prop_workshop_modern(lit, grand=True)


# (numele fisierului, functia, cladirea de azi pe care o inlocuieste) -- aceeasi ordine in atlasul prop_modern_lit
MODERN = [
    ("prop_storage_modern", prop_storage_modern, "prop_storage"),
    ("prop_sawmill_modern", prop_sawmill_modern, "prop_sawmill"),
    ("prop_sawmill_grand_modern", prop_sawmill_grand_modern, "prop_sawmill_grand"),
    ("prop_tavern_modern", prop_tavern_modern, "prop_tavern"),
    ("prop_tavern_grand_modern", prop_tavern_grand_modern, "prop_tavern_grand"),
    ("prop_scrap_shed_modern", prop_scrap_shed_modern, "prop_scrap_shed"),
    ("prop_workshop_modern", prop_workshop_modern, "prop_workshop_e1"),
    ("prop_workshop_grand_modern", prop_workshop_grand_modern, "prop_workshop_grand"),
]


# ---------------------------------------------------------------------------------------------
# TREPTELE 4 si 5: ferestrele caselor, ca ATLAS. Toate casele deseneaza fereastra cu d55._window (5x4 + rama), dar
# fiecare meserie o are in alt loc, iar la unele ceva sta in fata ei (roaba parcata, franghia, caruciorul). De aceea
# stratul nu e o fereastra pusa de cod la o pozitie: e casa desenata din nou cu fereastra noua, minus casa de azi. Ce
# era in fata ferestrei ramane in fata, iar stratul are exact marimea casei, deci se pune peste ea pe acelasi loc.

ATLAS_CELL = (40, 34)  # casa mare; cea mica (32x28) sta in coltul stang-sus al celulei ei
ATLAS_COLS = 8
HUT_MODULES = [
    ("landing", d55, ["porter", "sawyer", "hauler"]),
    ("landing", d56, ["scrap_collector", "scrap_porter", "smelter", "iron_hauler"]),
    ("mill", d65_crew, ["mill_collector", "mill_porter", "founder", "parts_hauler", "ore_collector", "ore_porter",
                        "coppersmith", "copper_hauler"]),
    ("works", d67_crew, ["works_collector", "works_porter", "wiredrawer", "coil_hauler", "battery_collector",
                         "battery_porter", "electrician", "power_hauler"]),
]


def huts():
    """[(district, numele foii fara 'prop_', modulul, functia)] pentru fiecare casa care are ferestre."""
    out = []
    for district, mod, keys in HUT_MODULES:
        for key in keys:
            for size in (1, 2):
                out.append((district, f"hut_{key}_{size}", mod, getattr(mod, f"prop_hut_{key}_{size}")))
    return out


def window_glass(c, x, y, w=5, h=4):
    """Fereastra noua: rama vopsita alb, sticla cu reflexia cerului, crucea ferestrei."""
    c.rect(x - 1, y - 1, w + 2, h + 2, CREAM[3])
    c.rect(x - 1, y - 1, w + 2, 1, CREAM[4])
    c.rect(x + w, y - 1, 1, h + 2, CREAM[1])
    c.rect(x - 1, y + h, w + 2, 1, CREAM[2])
    for yy in range(h):
        c.rect(x, y + yy, w, 1, GLASS[2] if yy == 0 else GLASS[1])
    c.put(x, y, (236, 248, 252, 255))  # la sticla, sclipirea spune "sticla"
    c.put(x + 1, y, GLASS[4])
    c.put(x, y + 2, GLASS[3])
    c.put(x + w // 2 + 1, y + 2, GLASS[4])
    c.put(x + w // 2 + 2, y + 3, GLASS[3])
    c.rect(x + w // 2, y, 1, h, CREAM[3])
    c.rect(x, y + 1, w, 1, CREAM[3])


def window_lit(c, x, y, w=5, h=4):
    """Fereastra aprinsa: aceeasi rama si cruce, sticla plina de lumina electrica (mai alba decat flacara de azi)."""
    c.rect(x - 1, y - 1, w + 2, h + 2, CREAM[3])
    c.rect(x - 1, y - 1, w + 2, 1, CREAM[4])
    c.rect(x + w, y - 1, 1, h + 2, CREAM[1])
    c.rect(x - 1, y + h, w + 2, 1, CREAM[2])
    for yy in range(h):
        c.rect(x, y + yy, w, 1, LIGHT[4] if yy < h - 1 else LIGHT[3])
    c.put(x + 1, y + 2, BULB_ON)
    c.put(x + w - 2, y + 2, BULB_ON)
    c.rect(x + w // 2, y, 1, h, CREAM[3])
    c.rect(x, y + 1, w, 1, CREAM[3])


def _hut_with(fn, draw_window, glow_r=0.0):
    """Casa desenata cu `draw_window` in locul ferestrei de azi (si, cu `glow_r`, lumina pe peretele din jur)."""
    real = d55._window
    calls = []

    def patched(c, x, y, w=5, h=4):
        calls.append((x, y, w, h))
        draw_window(c, x, y, w, h)

    d55._window = patched
    try:
        c = fn()
    finally:
        d55._window = real
    if glow_r > 0:
        for x, y, w, h in calls:
            cx, cy = x + (w - 1) / 2, y + (h - 1) / 2
            for yy in range(y - 2, y + h + 1 + int(glow_r)):  # nu urca pe streasina
                for xx in range(x - 1 - int(glow_r), x + w + 1 + int(glow_r)):
                    if not (0 <= xx < c.w and 0 <= yy < c.h):
                        continue
                    if x - 1 <= xx <= x + w and y - 1 <= yy <= y + h:
                        continue  # rama si sticla raman cum sunt
                    p = c.px[yy][xx]
                    if p[3] < 255 or p == OUTLINE:
                        continue
                    ddx = max(abs(xx - cx) - (w + 1) / 2, 0)
                    ddy = max(abs(yy - cy) - (h + 1) / 2, 0)
                    d = math.hypot(ddx, ddy) / glow_r
                    if d < 1:
                        c.px[yy][xx] = mix(p, LIGHT[4], 0.32 * (1 - d) ** 1.4)
    return c, calls


def _diff(new, old):
    """Stratul: pixelii lui `new` care difera de `old`, restul transparent."""
    out = C(new.w, new.h)
    for y in range(new.h):
        for x in range(new.w):
            if tuple(new.px[y][x]) != tuple(old.px[y][x]):
                out.px[y][x] = new.px[y][x]
    return out


def _atlas(layers):
    cw, ch = ATLAS_CELL
    rows = (len(layers) + ATLAS_COLS - 1) // ATLAS_COLS
    out = C(cw * ATLAS_COLS, ch * rows)
    for i, layer in enumerate(layers):
        ox, oy = (i % ATLAS_COLS) * cw, (i // ATLAS_COLS) * ch
        for y in range(layer.h):
            for x in range(layer.w):
                if layer.px[y][x][3]:
                    out.px[oy + y][ox + x] = layer.px[y][x]
    return out


def window_cells():
    """{numele casei: (x, y, w, h)} in atlasele de ferestre, plus districtul; casele fara fereastra lipsesc."""
    cells = {}
    i = 0
    for district, name, _mod, fn in huts():
        old = fn()
        _new, calls = _hut_with(fn, window_glass)
        if not calls:
            continue
        cw, ch = ATLAS_CELL
        cells[name] = {"x": (i % ATLAS_COLS) * cw, "y": (i // ATLAS_COLS) * ch, "w": old.w, "h": old.h,
                       "district": district, "windows": calls}
        i += 1
    return cells


def _windows_atlas(draw_window, glow_r):
    layers = []
    for _district, _name, _mod, fn in huts():
        old = fn()
        new, calls = _hut_with(fn, draw_window, glow_r)
        if calls:
            layers.append(_diff(new, old))
    return _atlas(layers)


def prop_windows_glass():
    return _windows_atlas(window_glass, 0)


def prop_windows_lit():
    return _windows_atlas(window_lit, 3.2)


# atlasul cladirilor moderne aprinse: celule de 64x48, in ordinea MODERN
LIT_CELL = (64, 48)
LIT_COLS = 4


def modern_lit_cells():
    out = {}
    for i, (name, fn, _base) in enumerate(MODERN):
        c = fn()
        out[name.replace("prop_", "")] = {"x": (i % LIT_COLS) * LIT_CELL[0], "y": (i // LIT_COLS) * LIT_CELL[1],
                                          "w": c.w, "h": c.h}
    return out


def prop_modern_lit():
    rows = (len(MODERN) + LIT_COLS - 1) // LIT_COLS
    out = C(LIT_CELL[0] * LIT_COLS, LIT_CELL[1] * rows)
    for i, (_name, fn, _base) in enumerate(MODERN):
        layer = _diff(fn(lit=True), fn(lit=False))
        ox, oy = (i % LIT_COLS) * LIT_CELL[0], (i // LIT_COLS) * LIT_CELL[1]
        for y in range(layer.h):
            for x in range(layer.w):
                if layer.px[y][x][3]:
                    out.px[oy + y][ox + x] = layer.px[y][x]
    return out


# ---------------------------------------------------------------------------------------------
# TREAPTA 4: masa cu planurile barajului si tarusii topografilor


def prop_dam_plans():
    """Masa de desen (48x44, x2): planseta inclinata pe doua capre, cu planul barajului pe hartie albastra (zidul vazut
    din fata, apa lacului in stanga, deversorul cu trei guri, cotele), prinsa cu pioneze de alama; lampa electrica pe
    brat, echerul T, un rulou rezemat si lada cu planuri. Aici se apasa "Build the Dam"."""
    c = canvas(48, 44)
    soft_shadow(c, 24, 41, 21, 2.2)
    # caprele: doua A-uri de lemn, cu o traversa
    for x0 in (8, 34):
        line(c, x0 + 3, 26, x0, 41, WOOD[2], 2)
        line(c, x0 + 3, 26, x0 + 6, 41, WOOD[1], 2)
        c.rect(x0 + 1, 34, 6, 1, WOOD[1])
    c.rect(10, 37, 28, 1, WOOD[1])  # bara de jos, intre capre
    # lada cu planuri, in dreapta jos, si ruloul rezemat
    c.rect(37, 33, 10, 8, PLANK[2])
    c.rect(37, 33, 10, 1, PLANK[4])
    c.rect(37, 36, 10, 1, PLANK[1])
    for k, x in enumerate((38, 41, 44)):
        c.rect(x, 30 - k % 2, 2, 4 + k % 2, CREAM[3])
        c.put(x, 30 - k % 2, PAPER[3])
    line(c, 3, 40, 7, 27, CREAM[3], 2)
    c.put(7, 27, PAPER[3])
    c.put(8, 27, PAPER[2])
    # planseta: trapez inclinat spre tine (sus mai ingusta), cu muchia groasa jos
    for y in range(8, 27):
        t = (y - 8) / 18
        x0 = round(7 - 3 * t)
        x1 = round(41 + 3 * t)
        c.rect(x0, y, x1 - x0 + 1, 1, WOOD[3] if y < 26 else WOOD[1])
    c.rect(4, 26, 41, 2, WOOD[1])
    c.rect(4, 26, 41, 1, WOOD[2])
    # hartia albastra
    for y in range(9, 25):
        t = (y - 9) / 15
        x0 = round(9 - 3 * t)
        x1 = round(39 + 3 * t)
        c.rect(x0, y, x1 - x0 + 1, 1, PAPER[2])
        if y % 4 == 1:
            c.rect(x0, y, x1 - x0 + 1, 1, PAPER[3])  # caroiajul
        for x in range(x0 + 3, x1, 5):
            if c.px[y][x] == PAPER[2]:
                c.put(x, y, PAPER[3])
    ink = (236, 244, 252, 255)
    # desenul: barajul vazut din aval, intre doua maluri. Lacul se vede peste coama, zidul are contraforti, trei guri
    # de deversor, iar apa cade dedesubt.
    for y in range(10, 13):  # lacul, peste coama: apa mai deschisa, cu valuri albe
        c.rect(10 + (y - 10) // 3, y, 29, 1, PAPER[3])
    for x in range(11, 38, 3):
        c.put(x, 11, ink)
        c.put(x + 1, 10, PAPER[4])
    line(c, 9, 10, 13, 21, ink, 1)  # malul din stanga
    line(c, 39, 10, 35, 21, ink, 1)  # malul din dreapta
    c.rect(11, 13, 27, 1, ink)  # coama
    for x in range(13, 36, 4):  # contrafortii
        c.rect(x, 14, 1, 6, PAPER[4])
    c.rect(12, 20, 25, 1, ink)  # talpa
    for gx in (18, 23, 28):  # gurile deversorului si apa care cade
        c.rect(gx, 16, 3, 2, PAPER[0])
        c.rect(gx, 15, 3, 1, ink)
        for k in range(3):
            c.put(gx + (k % 2), 21 + k, ink)
            c.put(gx + 2 - (k % 2), 21 + k, PAPER[4])
    c.rect(33, 21, 6, 3, PAPER[1])  # cartusul, in colt
    c.rect(34, 22, 4, 1, ink)
    for px, py in ((9, 9), (39, 9), (6, 24), (42, 24)):  # pionezele de alama
        c.put(px, py, BRASS[4])
    # echerul T, pe marginea de jos
    c.rect(10, 25, 26, 1, CREAM[4])
    c.rect(10, 22, 1, 4, CREAM[3])
    # lampa electrica: bratul de fier din coltul stang, abajurul verde, lumina pe hartie
    c.rect(6, 7, 1, 20, IRON[1])
    line(c, 6, 7, 12, 3, IRON[1], 1)
    c.rect(11, 2, 6, 2, ramp(150, 0.46, 0.44)[2])
    c.rect(11, 2, 6, 1, ramp(150, 0.46, 0.44)[3])
    c.rect(13, 4, 2, 1, BULB_ON)
    glow(c, 14, 10, 8, 0.28)
    # stegulet rosu (acelasi ca pe tarusi) infipt in coltul plansetei: planul si tarusii sunt aceeasi poveste
    c.rect(42, 0, 1, 9, WOOD[1])
    c.rect(43, 0, 4, 2, FLAG[3])
    c.rect(43, 2, 2, 1, FLAG[2])
    outline_trace(c)
    return c


STAKE_W, STAKE_H = 12, 26
# unde se leaga sfoara de la un tarus la altul, in pixeli de cadru (x2 in joc); nivela (cadrul 2) nu tine sfoara
STAKE_STRING = {0: (6, 15), 1: (6, 14)}


def _stake_post(c, x, top):
    c.rect(x, top, 2, 24 - top, WOOD[3])
    c.rect(x + 1, top, 1, 24 - top, WOOD[1])
    c.put(x, 24, WOOD[1])  # varful, in pamant
    c.rect(x, top, 2, 2, FLAG[3])  # capul vopsit rosu si alb
    c.rect(x, top + 2, 2, 1, CREAM[4])
    c.rect(x, top + 3, 2, 1, FLAG[2])


def stake_flag():
    c = canvas(STAKE_W, STAKE_H)
    soft_shadow(c, 6, 24, 3, 1)
    _stake_post(c, 5, 7)
    c.rect(6, 1, 1, 6, IRON[1])  # sarma steguletului
    for i in range(4):
        c.rect(7, 1 + i, 4 - i, 1, FLAG[3] if i < 2 else FLAG[2])
    c.put(7, 1, FLAG[4])
    c.put(6, 15, IRON[3])  # cuiul pentru sfoara
    outline_trace(c)
    return c


def stake_ribbon():
    c = canvas(STAKE_W, STAKE_H)
    soft_shadow(c, 6, 24, 3, 1)
    _stake_post(c, 5, 9)
    for k, (x, y) in enumerate(((7, 13), (8, 14), (9, 13), (10, 15), (4, 13), (3, 14))):  # panglica legata, in vant
        c.put(x, y, FLAG[3] if k % 2 == 0 else CREAM[4])
    c.rect(4, 12, 4, 1, FLAG[2])
    c.put(6, 14, IRON[3])
    outline_trace(c)
    return c


def stake_level():
    """Nivela topografului pe trepied: luneta de alama pe un disc, trei picioare de lemn."""
    c = canvas(STAKE_W, STAKE_H)
    soft_shadow(c, 6, 24, 5, 1)
    line(c, 6, 12, 1, 24, WOOD[3], 1)
    line(c, 6, 12, 11, 24, WOOD[2], 1)
    line(c, 6, 12, 6, 24, WOOD[1], 1)
    c.rect(4, 11, 5, 2, IRON[2])  # discul
    c.rect(4, 11, 5, 1, IRON[3])
    c.rect(3, 8, 7, 3, BRASS[2])  # luneta
    c.rect(3, 8, 7, 1, BRASS[4])
    c.rect(2, 8, 1, 3, BRASS[1])
    c.put(9, 9, GLASS[4])
    c.put(6, 7, BRASS[3])
    outline_trace(c)
    return c


def prop_survey_stakes():
    return d55.strip([stake_flag(), stake_ribbon(), stake_level()])


# ---------------------------------------------------------------------------------------------
# OPTIONAL: curtea goala din mijlocul Wire Works


def _drum_standing(c, cx, cy, r, depth=4):
    """Tambur de cablu in picioare, vazut din fata si putin de sus: flansa din spate (mutata sus-dreapta), cablul de cupru
    infasurat intre flanse (se vede ca o semiluna sus-dreapta), flansa din fata din scanduri, butucul de fier."""
    c.ellipse(cx + depth, cy - depth * 0.7, r, r, WOOD[1])  # flansa din spate
    c.ellipse(cx + depth - 0.6, cy - depth * 0.7 + 0.4, r - 0.8, r - 0.8, WOOD[2])
    for k in range(depth):  # cablul, spira dupa spira
        rr = r - 1.6
        ox, oy = cx + k + 0.5, cy - (k + 0.5) * 0.7
        c.ellipse(ox, oy, rr, rr, COPPER[2] if k % 2 else COPPER[3])
    for a in range(200, 340, 12):  # dungile spirelor, pe semiluna
        x = round(cx + depth * 0.5 + math.cos(math.radians(a)) * (r - 1.2))
        y = round(cy - depth * 0.35 + math.sin(math.radians(a)) * (r - 1.2))
        c.put(x, y, COPPER[1])
    c.ellipse(cx, cy, r, r, WOOD[1])  # flansa din fata
    c.ellipse(cx - 0.5, cy - 0.5, r - 1, r - 1, WOOD[3])
    for dy in range(-int(r) + 2, int(r) - 1, 3):  # rosturile scandurilor
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + dy ** 2 <= (r - 1.6) ** 2:
                c.put(x, round(cy + dy), WOOD[2])
    c.ellipse(cx, cy, r * 0.34, r * 0.34, IRON[2])  # butucul
    c.ellipse(cx - 0.3, cy - 0.3, r * 0.2, r * 0.2, IRON[0])
    for a in (45, 135, 225, 315):
        c.put(round(cx + math.cos(math.radians(a)) * r * 0.55), round(cy + math.sin(math.radians(a)) * r * 0.55), IRON[3])


def _insulator_crate(c, x, y):
    """Lada cu izolatori de portelan in paie (12x7)."""
    c.rect(x, y, 12, 7, PLANK[2])
    c.rect(x, y, 12, 1, PLANK[4])
    c.rect(x, y + 3, 12, 1, PLANK[1])
    c.rect(x, y, 1, 7, PLANK[3])
    c.rect(x + 11, y, 1, 7, PLANK[0])
    for k, ix in enumerate((x + 2, x + 5, x + 8)):
        c.rect(ix, y - 3, 3, 3, CREAM[3])
        c.put(ix, y - 3, CREAM[4])
        c.put(ix + 2, y - 1, CREAM[1])
        c.put(ix + 1, y - 1, (212, 186, 110, 255))  # paiele


def prop_cable_drums():
    """Tamburi de cablu (48x32, x3): unul mare si unul mic, in picioare, cu cuprul infasurat; o pana sub cel mare, o
    lada cu izolatori de portelan si un capat de cablu desfacut pe iarba. Marfa Wire Works, gata de dus pe strazi."""
    c = canvas(48, 32)
    soft_shadow(c, 23, 29, 22, 2.2)
    _drum_standing(c, 33, 19, 7, 3)
    _drum_standing(c, 14, 17, 11, 4)
    c.rect(5, 26, 5, 2, PLANK[2])  # pana
    c.rect(5, 26, 5, 1, PLANK[4])
    _insulator_crate(c, 33, 23)
    outline_trace(c)
    pts = [(24, 28), (28, 29), (32, 30), (36, 30), (40, 29), (44, 29), (46, 30)]  # cablul desfacut, dupa contur
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        _thin_line(c, x0, y0, x1, y1, COPPER[2])
    c.put(46, 30, COPPER[4])
    return c


def prop_substation():
    """Statia mica (56x48, x3): pe o platforma de pietris, un transformator de fier cu nervuri pe soclu de caramida, trei
    izolatori de portelan pe capac, portalul de zabrele cu izolatorii care duc firele spre linie (in dreapta sus),
    gardul jos de fier cu poarta si tabla galbena cu fulgerul."""
    c = canvas(56, 48)
    rng = Rng(7001)
    soft_shadow(c, 28, 44, 26, 3)
    # platforma de pietris
    for y in range(35, 45):
        for x in range(3, 53):
            if ((x - 28) / 25.5) ** 2 + ((y - 40) / 5.6) ** 2 <= 1:
                c.put(x, y, STONE[2] if rng.n() < 0.7 else (STONE[3] if rng.n() < 0.5 else STONE[1]))
    # portalul de zabrele, in spate
    for px in (8, 45):
        c.rect(px, 3, 2, 34, IRON[2])
        c.rect(px, 3, 1, 34, IRON[4])
    c.rect(7, 4, 41, 2, IRON[3])
    c.rect(7, 4, 41, 1, IRON[4])
    for x0 in range(10, 44, 6):
        line(c, x0, 6, x0 + 5, 9, IRON[1], 1)
        line(c, x0 + 5, 6, x0, 9, IRON[1], 1)
    c.rect(7, 9, 41, 1, IRON[2])
    for ix in (16, 28, 40):  # izolatorii atarnati de portal
        c.rect(ix, 10, 1, 1, IRON[1])
        for k in range(3):
            c.rect(ix - 1, 11 + k, 3, 1, CREAM[3] if k % 2 == 0 else CREAM[1])
        c.put(ix - 1, 11, CREAM[4])
    # firele: de la izolatori spre dreapta, afara din foaie (spre linie)
    line(c, 40, 14, 55, 9, IRON[0], 1)
    line(c, 28, 14, 55, 11, IRON[0], 1)
    # soclul de caramida si transformatorul
    M.bricks(c, 13, 31, 26, 6)
    c.rect(12, 30, 28, 1, STONE[3])
    c.rect(15, 16, 22, 14, IRON[2])  # cuva
    c.rect(15, 16, 22, 2, IRON[3])
    c.rect(15, 16, 1, 14, IRON[4])
    c.rect(36, 16, 1, 14, IRON[0])
    for x in range(12, 15):  # nervurile de racire, pe laturi
        c.rect(x, 19, 1, 10, IRON[3] if x % 2 == 0 else IRON[1])
    for x in range(37, 40):
        c.rect(x, 19, 1, 10, IRON[1] if x % 2 == 0 else IRON[0])
    c.rect(20, 21, 12, 5, SIGNAL[3])  # tabla galbena cu fulgerul
    c.rect(20, 21, 12, 1, SIGNAL[4])
    W.bolt(c, 24, 20, tones=ramp(24, 0.30, 0.20))
    for bx in (19, 26, 33):  # izolatorii de pe capac
        for k in range(4):
            c.rect(bx - 1, 12 + k, 3, 1, CREAM[3] if k % 2 == 0 else CREAM[1])
        c.put(bx - 1, 12, CREAM[4])
        c.rect(bx, 11, 1, 1, COPPER[3])
    line(c, 19, 11, 16, 14, COPPER[2], 1)  # legaturile spre portal
    line(c, 26, 11, 28, 14, COPPER[2], 1)
    line(c, 33, 11, 40, 14, COPPER[2], 1)
    # gardul din fata: stalpi de fier, doua bare, poarta cu tabla
    for x in range(4, 53, 6):
        c.rect(x, 35, 1, 9, IRON[1])
        c.put(x, 35, IRON[3])
    for y in (37, 41):
        c.rect(4, y, 49, 1, IRON[2])
    c.rect(24, 37, 8, 5, IRON[1])  # poarta
    c.rect(26, 38, 4, 3, SIGNAL[3])
    c.put(27, 39, ramp(24, 0.30, 0.20)[2])
    c.put(28, 38, ramp(24, 0.30, 0.20)[2])
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------

SPRITES = {
    # treapta 1
    "prop_wire_pole": prop_wire_pole,
    "prop_wire_pole_end": prop_wire_pole_end,
    # treapta 2
    "prop_barrow_iron": prop_barrow_iron,
    # treapta 3
    **{name: fn for name, fn, _base in MODERN},
    # treapta 4
    "prop_windows_glass": prop_windows_glass,
    "prop_dam_plans": prop_dam_plans,
    "prop_survey_stakes": prop_survey_stakes,
    # treapta 5
    "prop_windows_lit": prop_windows_lit,
    "prop_modern_lit": prop_modern_lit,
    # optional
    "prop_cable_drums": prop_cable_drums,
    "prop_substation": prop_substation,
}
STAGE = {
    "prop_wire_pole": 1, "prop_wire_pole_end": 1, "prop_barrow_iron": 2, **{n: 3 for n, _f, _b in MODERN},
    "prop_windows_glass": 4, "prop_dam_plans": 4, "prop_survey_stakes": 4, "prop_windows_lit": 5, "prop_modern_lit": 5,
    "prop_cable_drums": 0, "prop_substation": 0,
}


def luau():
    """Tabelele de care are nevoie codul, gata de lipit (PadArt / un modul nou ModernArt)."""
    lines = ["-- [D70] generat de scripts/art/d70_modern.py luau (pixeli de foaie; x Assets.PIXEL_SCALE = pixeli de lume)"]
    lines.append("MODERN_OF = { -- desenul de azi -> varianta moderna (treapta 3); lipsa = ramane desenul de azi")
    for name, _fn, base in MODERN:
        lines.append(f'    {base.replace("prop_", "")} = "{name.replace("prop_", "")}",')
    lines.append("}")
    lines.append(f"WINDOW_ATLAS_CELL = {{ w = {ATLAS_CELL[0]}, h = {ATLAS_CELL[1]} }} -- prop_windows_glass / prop_windows_lit")
    lines.append("WINDOW_CELLS = { -- casa -> dreptunghiul stratului ei in atlas (aceeasi marime cu casa)")
    for name, cell in window_cells().items():
        lines.append(f'    {name} = {{ x = {cell["x"]}, y = {cell["y"]}, w = {cell["w"]}, h = {cell["h"]} }}, -- {cell["district"]}')
    lines.append("}")
    lines.append("MODERN_LIT_CELLS = { -- cladirea moderna -> stratul ei aprins in prop_modern_lit (treapta 5)")
    for name, cell in modern_lit_cells().items():
        lines.append(f'    {name} = {{ x = {cell["x"]}, y = {cell["y"]}, w = {cell["w"]}, h = {cell["h"]} }},')
    lines.append("}")
    lines.append("WIRE_POLE = { -- foaia 16x54, prinsa de baza (mijlocul stalpului la x 8)")
    lines.append(f'    near = {{ x = {POLE_WIRES["near"][0]}, y = {POLE_WIRES["near"][1]} }}, far = {{ x = {POLE_WIRES["far"][0]}, y = {POLE_WIRES["far"][1]} }},')
    lines.append("}")
    lines.append(f"WIRE_POLE_END = {{ -- foaia {END_W}x54: stalpul e mutat cu {END_POLE_DX} px spre dreapta; doar la capatul de vest (oglindirea ramane pentru alta harta)")
    lines.append(f'    near = {{ x = {POLE_WIRES["near"][0] + END_POLE_DX}, y = {POLE_WIRES["near"][1]} }}, far = {{ x = {POLE_WIRES["far"][0] + END_POLE_DX}, y = {POLE_WIRES["far"][1]} }}, postX = {8 + END_POLE_DX},')
    lines.append("}")
    lines.append("SURVEY_STAKE = { -- x2, prinse de baza; cadrul 0 stegulet, 1 panglica, 2 nivela (fara sfoara)")
    lines.append("    frame = { w = 12, h = 26 }, frames = 3, string = { " + ", ".join(
        f"[{k}] = {{ x = {x}, y = {y} }}" for k, (x, y) in STAKE_STRING.items()) + " },")
    lines.append("}")
    lines.append("WIRE = { -- firul dintre stalpi: near cu near, far cu far; sageata = sag * deschiderea")
    for key in ("color_near", "color_far"):
        r, g, b, _a = WIRE[key]
        lines.append(f"    {key} = Color3.fromRGB({r}, {g}, {b}),")
    lines.append(f'    thickness = {WIRE["thickness_world_px"]}, sag = {WIRE["sag_fraction"]},')
    lines.append("}")
    return "\n".join(lines)


def main():
    args = sys.argv[1:]
    if args and args[0] == "luau":
        print(luau())
        return
    force = "--force" in args
    names = [a for a in args if not a.startswith("--")] or list(SPRITES)
    for name in names:
        if name not in SPRITES:
            sys.exit(f"{name}: nu e un desen D70")
        path = os.path.join(OUT, name + ".png")
        if os.path.exists(path) and not force:
            print(f"  {name}.png  exista deja, sarit (--force ca sa-l rescrii)")
            continue
        c = SPRITES[name]()
        write(path, c)
        print(f"  {name}.png  {c.w}x{c.h}")


def write(path, c):
    """Ca buildings.png, dar cu calea intreaga (buildings.png scrie in calea fixa a Mac-ului)."""
    import struct
    import zlib

    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *p) for p in row) for row in c.px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", c.w, c.h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    main()
