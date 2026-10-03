#!/usr/bin/env python3
"""[D75, lotul A1, grupul "wall"] Zidul barajului de piatra (varianta A aprobata la A0) si cele doua suprapuneri animate.
Scrie DOAR in scratchpad-ul sesiunii (--out); nimic nu intra in assets/sprites si nimic nu se urca.

  prop_dam_wall   80x189  zidul de piatra, vazut de sus in 3/4, lumina din stanga-sus. De la stanga la dreapta: coama
                          (parapetul spre lacul linistit, lespezi mari de pavaj, balustrada de lemn spre aval), fata din aval
                          in unsprezece trepte (opt sub deversor, coloanele 16-63; ultimele trei, 64-79, sunt la picior; nasul
                          luminat, caderea in umbra, treapta; treptele se intunecă spre picior) si, pe deversor, panza de apa
                          ajunge pe un prag de APA (nu de piatra) pana la rau, cu gura intunecata a canalului turbinei (bolta
                          de piatra, cheia luminata) in coltul de jos.
                          De sus in jos: capatul de nord intra in mal (o buza de nisip cu inaltime lina), pragul de nord al
                          deversorului, deversorul (piatra USCATA sub panza, apa e alt strat), capatul de sud pe uscat, iar
                          fata de sud a capatului arata profilul zidului: inaltimea scade treapta cu treapta, ca sa se citeasca
                          drept baraj, nu pod. Imaginea are ~35 de culori, toate din rampe (nu amestecuri continue).
  prop_dam_spill 141x96   3 cadre de 47x96, unul langa altul: panza de apa care se varsa peste trepte spre dreapta (aval).
                          Se pune peste coloanele 17-63 si randurile 29-124 ale zidului (in joc: x = wall.x + 51, y = wall.y + 87
                          = lume 691 x 479, latime 141, ca sa cada pe grila artei). Structura (muchia nasului, umbra caderii)
                          sta pe loc; doar dungile de curent se deplaseaza cu 2 px pe cadru, iar perioada de 6 a treptelor
                          inchide bucla de 3 cadre fara salt.
  prop_dam_foam   52x96   2 cadre de 26x96: fierberea de la picior, in rau, imediat la dreapta zidului (lume x 874-952,
                          y 480-768): deasa langa zid, rupta spre dreapta, pe jumatate transparenta. Anvelopa e aceeasi in
                          ambele cadre (doar muchia se misca cu un pixel), iar ciorchinii din interior se deplaseaza cu un pixel.

Aceleasi reguli ca restul conductei: culorile din palette.ramp(), niciodata negru pur, umbre translucide, lumina din
stanga-sus. NU suprascrie nimic din assets/sprites.

Rulare: python3 scripts/art/a1_wall.py [--out DIR]
"""
import argparse
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

from buildings import C, png  # noqa: E402
from palette import LEAF, OUTLINE, SAND, WOOD, mix, ramp  # noqa: E402
import village_ground as VG  # noqa: E402

D = 3  # pixeli de lume pe pixel de arta (Assets.PIXEL_SCALE)
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a1"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---- geometria (TycoonConfig.WORLDS[2].wall, deversorul si turbina, prin village_ground) -------------------------------
G = VG.geometry(2)
WALL = G["dam"]["wall"]
SPILL = G["dam"]["water"]["spillway"]
TURB = G["dam"]["turbine"]
W, H = WALL["w"] // D, WALL["h"] // D  # 80 x 189
SP_C0 = 17  # deversorul: coloanele 17-63 (lume x 690-830), randurile 29-124 (lume y 480-768)
SP_C1 = 64
SP_R0 = round((SPILL["y"] - WALL["y"]) / D)
SP_R1 = SP_R0 + SPILL["h"] // D
SP_W, SP_H = SP_C1 - SP_C0, SP_R1 - SP_R0  # 47 x 96
CREST = 16  # coloanele 0-15: coama
STEP = 6  # latimea unei trepte; fata din aval incepe la coloana 16, opt trepte pana la 63
FACE = 16
TOE = 64  # de aici, pragul de la picior (apa lina pe care cade panza), apoi canalul turbinei
FRONT = 7  # randurile de jos ale capatului de sud, vazute din fata


def near_row(x):
    return int(round((G["near"]["y"][int(WALL["x"] / D) + x] - WALL["y"]) / D))


RIVER_END = max(near_row(x) for x in range(W))  # primul rand de uscat: ~123
TURB_R1 = round((TURB["y"] + TURB["h"] / 2 - WALL["y"]) / D)  # ~125
# turbina din joc: 56x56 lume centrata pe (852, 729), adica ~19x19 pixeli de arta pe coloanele 61-80, randurile 103-121;
# peste gura ei se vede doar bolta, deci coroana boltii trebuie sa stea cu ~9 randuri deasupra turbinei.
MOUTH_R0 = 94  # coroana boltii
MOUTH_RAD = 8  # raza: gura are 16 coloane (64-79)

# ---- paleta: tot ce apare in imagine vine de aici (rampe si cateva tonuri fixe) ----------------------------------------
# piatra calda, gri-nisipie (varianta A din A0): ST[0] umbra ... ST[5] lumina
ST = ramp(38, 0.13, 0.52, steps=6, hue_shift=8, val_span=0.56)
INK = OUTLINE
DEEP = mix(ST[0], INK, 0.55)  # rosturi adanci, contactul cu pamantul, muchia dinspre lac
RISER = mix(ST[0], ST[1], 0.5)  # prima coloana a caderii de pe fiecare treapta: cea mai intunecata
DEEP_LAKE = mix(DEEP, (36, 78, 104, 255), 0.45)  # muchia dinspre lac, unde e in apa
WET_T = (52, 92, 120, 255)  # tinta apei pe piatra scaldata (WET)
WET = [mix(ST[i], WET_T, 0.38) for i in range(6)]  # piatra scaldata, pe ultimele coloane
MOSS = (mix(ST[1], LEAF[1], 0.55), mix(ST[2], LEAF[2], 0.50))
WATERLINE = (150, 196, 220, 255)  # linia luminata unde piatra intalneste raul de aval
# apa: de la spuma la umbra caderii
W0 = (246, 251, 253, 255)  # spuma
W1 = (212, 236, 246, 255)
W2 = (162, 208, 232, 255)
W3 = (114, 168, 208, 255)
W4 = (78, 128, 176, 255)  # umbra caderii
W5 = (58, 100, 150, 255)  # apa in umbra, sub pod
# apa intunecata din canalul turbinei, de sus in jos
CH = ((22, 42, 58, 255), (30, 56, 76, 255), (42, 76, 98, 255), (56, 98, 118, 255), (96, 140, 160, 255))
BRASS = ((214, 178, 108, 255), (172, 134, 70, 255), (130, 96, 48, 255))
SHEET_ALPHA = 240


def h01(x, y, salt=0):
    return VG.hash01(x, y, salt)


def clamp(v, a, b):
    return max(a, min(b, v))


# ---------------------------------------------------------------------------------------------------------------------------
# zidul
# ---------------------------------------------------------------------------------------------------------------------------
def step_info(x):
    k, lc = divmod(x - FACE, STEP)
    return k, lc


# treapta k are lespezile ei la ST[TREAD[k]]; se intunecă treapta cu treapta spre picior (nasul e cu un pas mai sus)
TREAD = (4, 4, 3, 3, 3, 2, 2, 2, 2, 2, 2)

_COURSES = []


def courses():
    """Asizele (randuri de blocuri) ale fetei: aceleasi pentru toate treptele, ca rosturile sa taie fata dintr-o parte in alta
    si fata sa se citeasca drept zidarie in trepte, nu opt stalpi. Lungimi de 5-8 randuri: (inceput, lungime)."""
    if not _COURSES:
        y, i = -4, 0
        while y < H + 12:
            ln = 5 + int(h01(i, 3, 13) * 4)
            _COURSES.append((y, ln))
            y += ln
            i += 1
    return _COURSES


def block_at(k, y):
    """(rand in asiza, lungimea asizei, ton -1/0/+1, muschi) pentru blocul treptei k de pe randul y. Tonul si muschiul tin de
    bloc (treapta x asiza), nu de pixel."""
    for i, (b0, ln) in enumerate(courses()):
        if b0 <= y < b0 + ln:
            r = h01(k, i, 14)
            tone = -1 if r < 0.12 else (1 if r > 0.88 else 0)
            return y - b0, ln, tone, h01(k, i, 15) < 0.07
    return 1, 6, 0, False


def crest_pixel(x, y, spill_rows, river):
    """Coama: x 0 muchia dinspre lac, 1-2 coronamentul parapetului, 3 umbra lui pe pavaj, 4-12 pavajul (doua siruri de lespezi
    mari, 4-8 si 9-12, cu rosturi ST[3]), 13 bordura, 14 balustrada de lemn (stalpi la 8 randuri), 15 umbra balustradei."""
    if x == 0:
        return DEEP_LAKE if river else DEEP
    # pilastri in parapet: la fiecare 24 de randuri, trei randuri mai groși
    pil = (y % 24) in (10, 11, 12)
    if x in (1, 2):
        # coronamentul: blocuri de 6 randuri, cu rost si muchie luminata in stanga
        blk = (y + 3) // 6
        r = (y + 3) % 6
        top = ST[5] if (blk % 3 != 1) else ST[4]
        if r == 0:
            return ST[3]  # rostul dintre blocuri
        if pil:
            return ST[5] if x == 1 else ST[4]
        return top if x == 1 else ST[4]
    if x == 3:
        return ST[3] if pil else ST[2]
    if 4 <= x <= 12:
        # doua sirui de lespezi lungi (8-10 randuri): coloanele 4-8 si 9-12, decalate intre ele
        lane = 0 if x <= 8 else 1
        if x == 4:
            return ST[3]  # umbra usoara a parapetului
        off = 0 if lane == 0 else 5
        ln = 9
        slab, r = divmod(y + off, ln)
        if r == 0:
            return ST[3]  # rostul dintre lespezi
        if x == 9:
            return ST[3]  # rostul dintre cele doua sirui
        return ST[5] if h01(slab, lane, 6) > 0.72 else ST[4]
    if x == 13:
        return ST[4]
    if x == 14:
        step = 16 if spill_rows else 8  # pe deversor balustrada are stalpi mai rari: apa trece pe sub pod
        if (y % step) in (0, 1):
            return WOOD[4] if y % step == 0 else WOOD[3]
        return WOOD[2]
    # x == 15: umbra balustradei pe fata; pe deversor e deja apa, in umbra podului
    return W5 if spill_rows else ST[1]


def face_pixel(x, y, river):
    """Fata din aval: pe fiecare treapta, 2 coloane de cadere in umbra (cea dintai cea mai intunecata), 3 de lespede si
    nasul (cu un pas mai luminos). Lespedea coboara cu treptele: [4,4,3,3,3,2,2,2,...]; rosturile sunt un pas mai jos decat
    lespedea si numai pe ea, deci cele mai tari linii sunt caderile, nu rosturile."""
    k, lc = step_info(x)
    by, bl, bt, moss = block_at(k, y)
    t = TREAD[min(k, len(TREAD) - 1)]
    t = clamp(t + bt, 2, 4)
    joint = by == 0
    lvl = 0
    if river and k >= 9:
        lvl = 1 if k == 9 else 2  # spre rau: intai lespezile se intuneca (treapta 9, cols 70-75), apoi se racesc in albastru (76-79)

    def tone(i):
        if lvl == 2:
            return WET[i]
        return ST[i - 1] if (lvl == 1 and i >= 2) else ST[i]

    if lc == 0:
        c = WET[0] if lvl == 2 else RISER
        if moss and by < 3 and not lvl and k >= 1:
            c = MOSS[0]
    elif lc == 1:
        c = tone(1)
        if moss and by < 3 and not lvl and k >= 1:
            c = MOSS[1]
    elif lc == 5:
        c = tone(min(5, t + 1))
        if joint:
            c = tone(t)
    else:
        c = tone(t)
        if joint:
            c = tone(t - 1)
        elif by == 1 and t <= 3:
            c = tone(t + 1)  # muchia luminata de sub rost (lumina din stanga-sus)
    return c


def front_h(x):
    """Inaltimea fetei de sud la coloana x: scade pe masura ce treptele coboara, ca profilul zidului."""
    if x < CREST:
        return FRONT
    k = (x - FACE) // STEP
    return (6, 6, 5, 5, 4, 4, 3, 3, 2, 2, 2)[min(k, 10)]


def front_pixel(x, y):
    """Fata de sud a capatului, vazuta din fata: blocuri cu rosturi, lumina pe stanga, contact intunecat jos."""
    hk = front_h(x)
    r = y - (H - hk)  # 0 sus .. hk-1 jos
    if r == 0:
        return ST[5]  # muchia de sus, luminata
    if r == hk - 1:
        return DEEP  # contactul cu pamantul
    i = 3 if r % 2 else 2
    # rosturi verticale decalate pe doua randuri
    if (x + (r // 2) * 4) % 8 == 0:
        i = 1
    # coloana din stanga a fiecarui bloc de treapta prinde lumina, cea din dreapta e in umbra
    if x >= FACE:
        lc = (x - FACE) % STEP
        if lc == 0:
            i = min(5, i + 1)
        elif lc == STEP - 1:
            i = max(0, i - 1)
    elif x == 0:
        i = max(0, i - 1)
    return ST[i]


def apron_pixel(x, y):
    """Pragul de la picior, pe randurile deversorului (coloanele 64-79): apa lina pe care cade panza, nu piatra. Primele doua
    randuri sunt umbra pragului de nord; apoi baza W2 cu jgheaburi W3 si dungi scurte W1/W0, rare; deasa langa panza
    (coloanele 64-65, unde aterizeaza) si spre spuma (75-79), ca sa se uneasca cu marginea deasa a spumei fara cusatura."""
    r = y - SP_R0
    xx = x - TOE
    if r < 2:
        return W4
    if xx <= 1:
        # unde aterizeaza panza: alb des, cu goluri albastre
        q = h01(x, y, 18)
        if xx == 0:
            return W0 if q < 0.62 else W1
        return W1 if q < 0.70 else (W2 if q < 0.92 else W0)
    if xx >= 11:
        # spre spuma: rampa spre W1/W0
        q = h01(x, y, 19)
        if xx >= 14:
            return W0 if q < 0.55 else W1
        if xx == 13:
            return W1 if q < 0.60 else (W0 if q < 0.85 else W2)
        if xx == 12:
            return W1 if q < 0.35 else (W2 if q < 0.90 else W0)
        return W1 if q < 0.18 else W2
    # mijloc (xx 2-10): jgheaburi W3 si dungi albe de 3-5, doua cate doua pe latime, rare, fara rosturi si sclipiri
    c = W2
    for slot in range(2):
        s0 = 2 + slot * 5
        q = h01(slot, y, 24)
        if q < 0.42:
            st = s0 + int(h01(slot, y, 25) * 3)
            ln = 3 + int(h01(slot, y, 26) * 3)
            if st <= xx < st + ln:
                c = W3
        q2 = h01(slot, y, 27)
        if q2 < 0.20:
            st = s0 + int(h01(slot, y, 28) * 3)
            ln = 3 + int(h01(slot, y, 29) * 2)
            if st <= xx < st + ln:
                c = W0 if (ln >= 4 and st < xx < st + ln - 1) else W1
    return c


def mouth_pixels(c):
    """Gura intunecata a canalului turbinei, cu bolta de piatra (voussoirs si cheia), in coltul de jos al deversorului. Coroana
    sta la randul 94 si naste la 102: turbina din joc acopera randurile 103-121, deci se vad coroana si doua randuri de
    inel de sus, iar gura intunecata continua pana la prag."""
    x0, x1 = TOE, W - 1  # 64..79
    r0 = MOUTH_R0
    r1 = TURB_R1 - 1  # 124 (inclusiv); pragul ramane dedesubt
    cx = (x0 + x1 + 1) / 2 - 0.5
    rad = float(MOUTH_RAD)
    spring = r0 + int(rad)  # unde incepe bolta: 102
    ring = 2.2
    for y in range(r0, r1 + 1):
        for x in range(x0, x1 + 1):
            dx = x - cx
            if y < spring:
                d = math.hypot(dx, y - spring + 0.5)
                inside = d <= rad
                inner = d <= rad - ring
            else:
                inside = True
                inner = abs(dx) <= rad - ring
            if not inside:
                continue
            if not inner:
                # inelul de piatra: boltari alternand luminat / umbrit
                ang = math.atan2(y - spring + 0.5, dx) if y < spring else (math.pi / 2 if dx > 0 else -math.pi / 2)
                seg = int((ang + math.pi) / (math.pi / 6)) if y < spring else (y // 4)
                col = ST[4] if seg % 2 == 0 else ST[3]
                # lumina din stanga-sus: partea stanga a inelului mai luminoasa, cea dreapta mai umbrita
                if dx < -rad + ring + 0.1:
                    col = ST[5] if (y % 4) else ST[4]
                elif dx > rad - ring - 0.1:
                    col = ST[2]
                if y < r0 + 2 and abs(dx) < 1.6:
                    col = ST[5]  # cheia boltii
                c.put(x, y, col)
            else:
                # apa intunecata din canal: mai adanca sus, mai limpede jos, pe benzi
                t = (y - r0) / max(1, r1 - r0)
                band = 0 if t < 0.28 else (1 if t < 0.55 else (2 if t < 0.80 else 3))
                if y >= r1 - 1:
                    band = 4
                c.put(x, y, CH[band])
    # pragul canalului: o lespede luminata sub gura
    for x in range(x0, x1 + 1):
        c.put(x, r1 + 1, ST[4] if x < x1 - 2 else ST[2])


def wall():
    c = C(W, H)
    for y in range(H):
        for x in range(W):
            river = y <= RIVER_END
            spill_rows = SP_R0 <= y < SP_R1
            if y >= H - front_h(x):
                col = front_pixel(x, y)
            elif x < CREST:
                col = crest_pixel(x, y, spill_rows, river)
            elif x >= TOE and spill_rows:
                col = apron_pixel(x, y)
            else:
                col = face_pixel(x, y, river)
            c.put(x, y, col)
    # pragul de nord al deversorului: o asiza de piatra care taie fata (muchie luminata, fata in umbra), cu rosturi
    for x in range(FACE, W):
        jx = (x + 3) % 9 == 0
        c.put(x, SP_R0 - 5, ST[5] if x < TOE else ST[4])
        c.put(x, SP_R0 - 4, ST[4] if not jx else ST[3])
        c.put(x, SP_R0 - 3, ST[3] if not jx else ST[2])
        c.put(x, SP_R0 - 2, ST[2])
        c.put(x, SP_R0 - 1, ST[0])
    # pragul de sud: o lespede peste fata, pe linia malului
    for x in range(FACE, W):
        jx = (x + 5) % 9 == 0
        c.put(x, SP_R1, ST[5])
        c.put(x, SP_R1 + 1, ST[4] if not jx else ST[3])
        c.put(x, SP_R1 + 2, ST[3] if not jx else ST[2])
    mouth_pixels(c)
    # marginea stanga a deversorului: apa iese de sub pod. Col 15 e apa in umbra, col 16 umbra caderii cu cate un W3 la 4-5 randuri
    for y in range(SP_R0, SP_R1):
        c.put(15, y, W5)
        c.put(16, y, W3 if (y - SP_R0) % 5 == 2 else W4)
    # randul 29 sub pragul de nord: aceeasi umbra ca primul rand al panzei, ca sa nu ramana nicio dunga de piatra
    for x in range(16, TOE):
        c.put(x, SP_R0, W4)
    # capatul de nord intra in mal: o buza de nisip cu inaltime lina (1-3 randuri) si o umbra de un rand dedesubt;
    # parapetul (coloanele 0-2) continua in mal ca piatra
    # (culorile: cele doua tonuri deschise ale pamantului copt, VG.SAND[1] / [2], in acelasi punctat Bayer si pe aceeasi grila de lume
    # ca el, ca buza sa se piarda in nisipul de deasupra; nu SAND din palette, prea saturat si plat)
    wgx, wgy = round(WALL["x"] / D), round(WALL["y"] / D)
    for x in range(3, W):
        d = clamp(int(round(2.0 + 0.9 * math.sin(x * 0.21 + 0.7) + 0.5 * math.sin(x * 0.47))), 1, 3)
        for y in range(d):
            light = 0.62 if y == 0 else 0.38  # partea de sus (spre nisipul copt) mai deschisa, spre piatra mai umbrita
            tone = VG.SAND[2] if VG.dither(wgx + x, wgy + y) < light else VG.SAND[1]
            c.px[y][x] = (tone[0], tone[1], tone[2], 255)
        c.px[d][x] = ST[1]
    # placa de alama pe fata de sud (a coamei): piatra de temelie
    for x in range(5, 11):
        c.put(x, H - 5, BRASS[1])
        c.put(x, H - 4, BRASS[2])
    c.put(5, H - 5, BRASS[0])
    # marginea din dreapta: unde zidul da in raul de aval e o linie luminata de apa, pe uscat o muchie in umbra
    for y in range(4, H):
        if SP_R0 <= y < SP_R1:
            continue  # pe deversor apa lina si spuma duc mai departe
        if y <= RIVER_END:
            c.px[y][W - 1] = WATERLINE
        else:
            c.px[y][W - 1] = ST[1]
    for x in range(W):
        c.px[H - 1][x] = DEEP
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# panza deversorului (3 cadre) si spuma (2 cadre)
# ---------------------------------------------------------------------------------------------------------------------------
def with_alpha(col, a):
    return (col[0], col[1], col[2], a)


def sheet_frame(f):
    """Un cadru 47x96 al panzei. Structura sta pe loc, ca treptele: pe fiecare treapta (perioada 6) caderea (lc 0-1) in
    albastru de umbra, apa care se limpezeste pe treapta (lc 2-4) si, la nas (lc 5), o banda alba rupta de 1-3 px (latimea
    aleasa pe rand). Pete de cate 2-3 randuri sparg uniformitatea, nu zgomot pe pixel. Peste ele curg dungi de un rand si 3-4 px
    (W1/W0 pe baza W3), cu faza pe coloana globala (gx - 2f) mod 6 si decalajul tinut doar de rand: trec peste muchii. Singura
    schimbare de la un cadru la altul e deplasarea de 2 px a dungilor; perioada e 6 si sunt 3 cadre, deci bucla se inchide."""
    c = C(SP_W, SP_H)
    for y in range(SP_H):
        g3 = y // 3
        # dunga de curent a randului: prezenta si decalajul tin doar de rand (nu de cadru)
        has_streak = h01(y, 0, 76) < 0.46
        off = int(h01(y, 0, 77) * STEP)
        for sx in range(SP_W):
            gx = SP_C0 + sx
            k, lc = step_info(gx)
            w = k / 7.0  # 0 la coama .. 1 la picior
            # banda alba de la nas: 1-3 px, latimea aleasa pe randul de 2 si pe treapta; intra pe lc 4 si lc 3
            bw = 1 + (h01(y // 2, k, 74) < 0.50 + 0.20 * w) + (h01(y // 2, k, 75) < 0.14 + 0.16 * w)
            if lc == 0:
                # umbra caderii: W4, cu pete W3 de 3 randuri (la fiecare 3-4 pete)
                tone = W3 if h01(y // 2, k, 70) < 0.30 + 0.14 * w else W4
                a = SHEET_ALPHA
            elif lc == 1:
                tone = W4 if h01(g3, k, 71) < 0.34 - 0.24 * w else W3
                a = SHEET_ALPHA
            elif lc == 2:
                # unde apa aterizeaza: W2, cu pete W1 mai deschise spre picior
                tone = W1 if h01(g3, k, 72) < 0.16 + 0.34 * w else W2
                a = 250
            elif lc == 5:
                tone, a = (W0 if h01(y, k, 82) < 0.80 else W1), 255
            elif lc == 4 and bw >= 2:
                tone, a = W1, 255
            elif lc == 3 and bw >= 3:
                tone, a = W1, 255
            else:
                tone = W3
                if h01(g3, k, 73) < 0.10 + 0.22 * w:
                    tone = W2  # pete de apa mai limpede
                a = SHEET_ALPHA
            # dungile de curent: doar pe lc 1-4, ca muchiile sa ramana pe loc; fiecare treapta le poate intrerupe sau scurta
            if has_streak and 1 <= lc <= 4 and h01(y, k, 80) > 0.30:
                ln = 3 + (h01(y, k, 81) < 0.55)
                if (gx - 2 * f - off) % STEP < ln:
                    tone, a = (W0 if (ln == 4 and (gx - 2 * f - off) % STEP in (1, 2)) else W1), 255
            col = with_alpha(tone, a)
            # umbra pragului de nord pe primele doua randuri
            if y == 0:
                col = with_alpha(W4, 255)
            elif y == 1:
                col = with_alpha(W4 if tone in (W3, W4) else W3, 255)
            if y >= SP_H - 2:
                # sfarsitul panzei, la mal: stropi albi OPACI, stransi langa zidul de sud (W1/W0, fara goluri, ca sa nu se vada
                # piatra uscata a fetei printre pixelii de apa); aceiasi in toate cadrele, deci bucla ramane inchisa
                q = h01(sx, y, 90)
                if y == SP_H - 2:
                    col = with_alpha(W1 if q < 0.55 else W0, 255)
                else:
                    col = with_alpha(W0 if q < 0.78 else W1, 255)
            c.put(sx, y, col)
    return c


def spill():
    c = C(SP_W * 3, SP_H)
    for f in range(3):
        fr = sheet_frame(f)
        for y in range(SP_H):
            for x in range(SP_W):
                c.px[y][f * SP_W + x] = fr.px[y][x]
    return c


FOAM_W = 26
FOAM_JIT = 0.085  # cat se misca muchia anvelopei de la un cadru la altul
FOAM_KSCALE = 2.6  # marimea ciorchinilor (px)
FOAM_KTHR = 0.47  # cu cat mai mic, cu atat mai plin e W0
FOAM_KSHIFT = (1.0, 1.0)  # cu cat se deplaseaza partea mobila a ciorchinilor pe cadru
FOAM_KMOVE = 0.20  # cat din forma ciorchinilor se misca (restul sta pe loc)


def foam_frame(f):
    """Fierberea de la picior: 26 coloane (lume x 874-952), alba si deasa langa zid, destramata spre dreapta.
    Anvelopa (unde e spuma) vine dintr-un camp de zgomot FARA cadru; de la un cadru la altul i se schimba doar muchia (cu
    cel mult un pixel). Interiorul e facut din ciorchini de 2-3 px: W0 plat, cu W1 pe marginea de jos-dreapta si W2 in
    golurile de sub ei; ciorchinii se deplaseaza cu un pixel pe cadru, ca fierberea sa se rastoarne, nu sa palpaie."""
    w, h = FOAM_W, SP_H
    nE = VG.Noise(77)
    nF = VG.Noise(31)
    nJ = VG.Noise(53)
    nK = VG.Noise(19)
    nK2 = VG.Noise(23)

    def edge(yy):
        return min(1.0, (yy + 1) / 14.0, (h - yy) / 8.0)  # spre capatul de nord si spre mal se subtiaza

    def env(x, y):
        t = x / (w - 1)
        boil = nE.at(x, y * 0.85, 2.7)
        fine = nF.at(x, y, 1.5)
        val = 0.62 * boil + 0.38 * fine - 0.92 * t + 0.46
        if x < 5:
            val += 0.11 * (1 - x / 5.0)  # langa zid e aproape plin
        return val * (0.32 + 0.68 * edge(y))

    THR = 0.40
    e = [[env(x, y) for x in range(w)] for y in range(h)]

    def jit(x, y):
        return (nJ.at(x + 13.0 * f, y + 7.0 * f, 2.0) - 0.5) * 2 * FOAM_JIT

    mask = [[e[y][x] + jit(x, y) > THR for x in range(w)] for y in range(h)]

    def M(x, y):
        return 0 <= x < w and 0 <= y < h and mask[y][x]

    def K(x, y):
        # ciorchinele: zgomot de scara ~2.4 px, deplasat cu (f, f); mai pline langa zid
        thr = FOAM_KTHR - 0.14 * max(0.0, 1 - x / 6.0)
        v = (1 - FOAM_KMOVE) * nK.at(x, y, FOAM_KSCALE) + FOAM_KMOVE * nK2.at(
            x - f * FOAM_KSHIFT[0], y - f * FOAM_KSHIFT[1], FOAM_KSCALE
        )
        return v > thr

    c = C(w, h)
    for y in range(h):
        for x in range(w):
            if M(x, y):
                if K(x, y):
                    low = (not K(x + 1, y)) or (not K(x, y + 1))
                    col, a = (W1, 255) if low else (W0, 255)
                else:
                    shaded = K(x - 1, y) or K(x, y - 1)
                    col, a = (W2, 235) if shaded else (W1, 235)
                if x == 0:
                    a = 190 if h01(x, y, 64) < 0.7 else 235  # muchia dinspre zid se topeste in prag
                c.put(x, y, with_alpha(col, a))
            elif e[y][x] > THR - 0.10 and h01(x, y, 63) < 0.55:
                c.put(x, y, with_alpha(W1, 105))  # franjuri translucide
    # coada: dungi scurte de spuma duse de curent spre dreapta, mai rare cu cat te departezi de zid; cu un pixel pe cadru
    for y in range(h):
        for xs in range(9, w - 1, 3):
            t = xs / (w - 1)
            if h01(xs, y, 110) < 0.085 * (1.15 - t) * edge(y):
                ln = 2 + int(h01(xs, y, 111) * 3)
                for dx in range(ln):
                    px = xs + dx + f
                    if px < w and c.px[y][px][3] == 0:
                        c.put(px, y, with_alpha(W1 if dx else W0, 150 if dx else 190))
    # cateva bule izolate mai departe de zid (pe loc)
    for i in range(10):
        bx = 9 + int(h01(i, 0, 51) * 12)
        by = 4 + int(h01(i, 0, 52) * (h - 10))
        if e[by][bx] > 0.22:
            c.put(bx, by, with_alpha(W0, 235))
            if h01(i, 0, 53) > 0.5:
                c.put(bx + 1, by, with_alpha(W1, 150))
    return c


def foam():
    c = C(FOAM_W * 2, SP_H)
    for f in range(2):
        fr = foam_frame(f)
        for y in range(SP_H):
            for x in range(FOAM_W):
                c.px[y][f * FOAM_W + x] = fr.px[y][x]
    return c


SPRITES = {"prop_dam_wall": wall, "prop_dam_spill": spill, "prop_dam_foam": foam}
SIZES = {"prop_dam_wall": (80, 189), "prop_dam_spill": (141, 96), "prop_dam_foam": (52, 96)}


# ---------------------------------------------------------------------------------------------------------------------------
# previzualizarea
# ---------------------------------------------------------------------------------------------------------------------------
def to_image(c):
    img = Image.new("RGBA", (c.w, c.h))
    img.putdata([p for row in c.px for p in row])
    return img


def load_sprite(name):
    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


def font(n):
    try:
        return ImageFont.truetype(FONT, n)
    except OSError:
        return ImageFont.load_default()


def ground_composite(images, frame_spill=0, frame_foam=0, with_bell=False):
    """Satul la locul zidului: apa (animata in joc, aici un mozaic), pamantul copt, zidul, panza si spuma la pozitiile lor.
    Turbina e pusa ca in joc: 56x56 lume, centrata pe (852, 729)."""
    g = load_sprite("prop_dam_ground")
    water = load_sprite("water_tile")
    bg = Image.new("RGBA", g.size)
    for yy in range(0, g.height, water.height):
        for xx in range(0, g.width, water.width):
            bg.paste(water, (xx, yy))
    bg.alpha_composite(g)
    wx, wy = round(WALL["x"] / D), round(WALL["y"] / D)
    bg.alpha_composite(images["prop_dam_wall"], (wx, wy))
    sp = images["prop_dam_spill"].crop((frame_spill * SP_W, 0, (frame_spill + 1) * SP_W, SP_H))
    bg.alpha_composite(sp, (wx + SP_C0, wy + SP_R0))
    fo = images["prop_dam_foam"].crop((frame_foam * FOAM_W, 0, (frame_foam + 1) * FOAM_W, SP_H))
    bg.alpha_composite(fo, (round((WALL["x"] + WALL["w"]) / D) - 2, round(SPILL["y"] / D)))
    tur = load_sprite("prop_turbine")
    tw = th = max(1, round(56 / D))  # 56 lume = ~19 px de arta
    small = tur.resize((tw, th), Image.NEAREST)
    bg.alpha_composite(small, (round(TURB["x"] / D - tw / 2), round(TURB["y"] / D - th / 2)))
    if with_bell:
        bell = load_sprite("prop_bell")
        spb = G["dam"]["buildings"]["bellTower"]
        bg.alpha_composite(bell, (round(spb["x"] / D - bell.width / 2), round(spb["y"] / D - bell.height)))
    return bg


def preview(images, outdir):
    GRASS_BG = (86, 128, 64, 255)
    S = 4
    lab = font(8)
    items = [
        ("prop_dam_wall 80x189", images["prop_dam_wall"]),
        ("prop_dam_spill 3 frames 47x96", images["prop_dam_spill"]),
        ("prop_dam_foam 2 frames 26x96", images["prop_dam_foam"]),
    ]
    gut = 20
    tiles = []
    for label, im in items:
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        t = Image.new("RGBA", (big.width + 16, big.height + 40), GRASS_BG)
        ImageDraw.Draw(t).text((8, 10), label, font=lab, fill=(244, 238, 220, 255))
        t.alpha_composite(big, (8, 28))
        tiles.append(t)
    row1_h = max(t.height for t in tiles)
    row1_w = sum(t.width for t in tiles) + gut * (len(tiles) + 1)
    # randul 2: in joc, pe pamant, la 3x, cadrele 0 / 1 / 2
    crops = []
    box = (150, 100, 360, 340)
    for f in range(3):
        comp = ground_composite(images, f, f % 2).crop(box)
        crops.append(comp.resize((comp.width * 3, comp.height * 3), Image.NEAREST))
    one = ground_composite(images, 0, 0, with_bell=True).crop(box)
    row2_h = crops[0].height + 40
    row2_w = sum(cr.width for cr in crops) + gut * 4
    out = Image.new("RGBA", (max(row1_w, row2_w), row1_h + row2_h + gut * 3 + one.height), GRASS_BG)
    d = ImageDraw.Draw(out)
    x = gut
    for t in tiles:
        out.alpha_composite(t, (x, gut))
        x += t.width + gut
    y2 = gut * 2 + row1_h
    x = gut
    for f, cr in enumerate(crops):
        d.text((x, y2), f"in joc x3: cadrul de panza {f}, spuma {f % 2}", font=lab, fill=(244, 238, 220, 255))
        out.alpha_composite(cr, (x, y2 + 16))
        x += cr.width + gut
    y3 = y2 + row2_h + gut
    d.text((gut, y3 - 14), "in joc 1x (cadrul 0)", font=lab, fill=(244, 238, 220, 255))
    out.alpha_composite(one, (gut, y3))
    path = os.path.join(outdir, "wall_preview.png")
    out.save(path)
    print("scris", path, out.size)


def report(images):
    """Cifre de control: culori, cadre de panza si de spuma (cat se schimba de la un cadru la altul)."""
    wl = images["prop_dam_wall"]
    cols = {p for p in wl.getdata()}
    print("prop_dam_wall: culori distincte", len(cols), "| cea mai intunecata", min(cols, key=lambda p: p[0] + p[1] + p[2])[:3])
    print("  pixeli cu alfa<255:", sum(1 for p in wl.getdata() if p[3] != 255))
    sp = images["prop_dam_spill"]
    fr = [list(sp.crop((i * SP_W, 0, (i + 1) * SP_W, SP_H)).getdata()) for i in range(3)]
    c3 = sheet_frame(3)  # cadrul 3 trebuie sa fie identic cu cadrul 0: bucla se inchide
    closes = list(to_image(c3).getdata()) == fr[0]
    print("  panza: bucla se inchide (cadrul 3 == cadrul 0):", closes)
    assert closes
    for i in range(3):
        j = (i + 1) % 3
        ch = sum(1 for a, b in zip(fr[i], fr[j]) if a != b)
        print(f"  panza cadrul {i}->{j}: {ch} din {len(fr[i])} pixeli schimbati ({100 * ch / len(fr[i]):.0f}%)")
    fo = images["prop_dam_foam"]
    ff = [list(fo.crop((i * FOAM_W, 0, (i + 1) * FOAM_W, SP_H)).getdata()) for i in range(2)]
    op = [sum(1 for p in f if p[3] > 0) for f in ff]
    chg = sum(1 for a, b in zip(ff[0], ff[1]) if (a[3] > 0) != (b[3] > 0))
    chc = sum(1 for a, b in zip(ff[0], ff[1]) if a != b)
    print(f"  spuma: opace {op[0]} / {op[1]} ({100 * abs(op[0] - op[1]) / max(op):.1f}% diferenta); masca schimbata {chg} "
          f"({100 * chg / max(op):.0f}% din opace); orice schimbare {chc} ({100 * chc / max(op):.0f}%)")
    rch = [max((x for x in range(FOAM_W) for y in range(SP_H) if f[y * FOAM_W + x][3] > 0), default=0) for f in ff]
    print("  spuma: cea mai din dreapta coloana", rch)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=SCRATCH)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    images = {}
    for name, fn in SPRITES.items():
        c = fn()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h, SIZES[name])
        png(os.path.join(args.out, name + ".png"), c.w, c.h, c.px)
        images[name] = to_image(c)
        print("scris", name, c.w, c.h)
    preview(images, args.out)
    report(images)


if __name__ == "__main__":
    main()
