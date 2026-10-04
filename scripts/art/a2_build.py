#!/usr/bin/env python3
"""[D75, lotul A2, grupul "build"] Santierul filmului barajului (DamMath.FILM, faza "build", 11-14 s): schela peste rau, zidul
care creste din ambele maluri, cele doua capete neterminate, macaraua, caruciorul, gramada de piatra si praful de ciocan.
Arta e desenata in culori de ZI: jocul pune amurgul (70,34,52) la 45% peste tot. Scrie DOAR in scratchpad-ul sesiunii (--out);
nimic nu intra in assets/sprites si nimic nu se urca.

NUMERELE FILMULUI (DamFilmSet, in pixeli de arta = lume / 3): zidul sta pe x 213-293 si de la y 127 (malul de nord) la y 257 (malul
de sud), adica 130 de randuri. Fiecare jumatate creste pana la 65 de randuri (195 lume), deci jumatatea de nord arata randurile
0..n-1 ale zidului, iar cea de sud randurile (189-s)..188; la `built` = 1 se ating (n = s = 65: nord 0-64, sud 124-188).
Raul satului intra in zid pana la randul 185 al jumatatii de sud (malul de sud, y ~253).

  prop_film_wall         80x189  ZIDUL FILMULUI. Aceeasi piatra, aceleasi trepte si aceeasi coama ca prop_dam_wall (A1, aprobat; acelasi
                                 cod, importat din a1_wall; generatorul verifica la fiecare rulare ca zidul A1 e identic cu PNG-ul aprobat),
                                 DAR USCAT: fara panza deversorului, fara apa copta, fara gura canalului turbinei (randurile 29-124
                                 au fata de piatra, coama cu balustrada obisnuita). Cele doua ressalturi (randurile 24-28 si 125-127)
                                 raman. Randurile de apa din zid sunt facute pentru RAUL SATULUI: pana la randul 185 piatra se
                                 raceste spre dreapta si are linia luminata de apa pe coloana 79 si muchia dinspre lac (albastra) pe
                                 coloana 0, la AMBELE jumatati (zidul A1 avea apa doar pana la 123, restul era uscat). Jocul NU
                                 foloseste prop_dam_wall in film: taie jumatatea de nord (randurile 0..n-1) si pe cea de sud
                                 (randurile 189-s..188) din aceasta imagine, fara petece si fara decalaje.
                                 REGULI DE TAIERE: (1) fata de nord nu se opreste in ressaltul 24-28 (n sare de la 23 direct la 29), iar
                                 fata de sud nu se opreste in ressaltul 125-127 (prima linie a jumatatii de sud, 189-s, sare de la 128
                                 direct la 124); (2) randul 64 (ultimul al nordului) si randul 124 (primul al sudului) se vad DOAR cand
                                 jumatatile se ating: sunt randurile cusaturii (rost de asiza + muchie luminata), deci zidul inchis
                                 nu are o rana de mortar; (3) cand n + s >= 130 (cele doua jumatati se ating) jocul ASCUNDE capetele
                                 si schela (golul e 0).
  prop_film_scaffold      80x16  o treapta de schela de lemn pe toata latimea zidului (240 lume), REPETABILA PE VERTICALA: jocul
                                 o pune de mai multe ori una peste alta in golul dintre cele doua jumatati. Sus podeaua (cinci
                                 randuri de scanduri vazute de sus, cu rost si capete de scandura), dedesubt grinda (fata
                                 podelei), apoi golul prin care se vede raul: trei stalpi, contravantuiri de colt la 45 de
                                 grade de o parte si de alta a fiecarui stalp, legaturi de franghie. Sub podea cade o umbra
                                 translucida. Randul 15 si randul 0 al treptei urmatoare se leaga fara cusatura (stalpii merg
                                 intregi; contravantuirile se opresc in gol). Se intinde de la fata de nord pana la fata de sud (sub
                                 capete), ultima treapta taiata.
  prop_film_wall_edge_n   80x10  capatul de SUD, neterminat, al jumatatii de nord (frontul de zidire, vazut de sus). Se pune cu randul 0
                                 chiar sub ultimul rand al jumatatii (la y = fata de nord, deci in gol). Randurile 0-1 sunt randuri
                                 NEUTRE (tonul simplu al fiecarei trepte, fara rost de asiza, fara muschi, fara blocuri mai
                                 inchise sau mai deschise), asa ca la orice front arata ca o asiza proaspata, nu ca o cusatura
                                 gresita. Dedesubt, fiecare unitate de coloane se opreste la alt rand si arata fata taiata: acelasi
                                 profil ca zidul A1 (7 randuri pe coama, apoi 6,6,5,5,4,4,3,3,2,2,2 pe trepte), cu marginea de jos
                                 zdrentuita (transparenta). Pe suprafata (doar pe trepte, unde e loc): blocuri fatuite lasate jos, o
                                 copaie cu mortar, o scandura, un ciocan cu dalta.
  prop_film_wall_edge_s   80x10  capatul de NORD, neterminat, al jumatatii de sud. Se pune cu randul 9 chiar deasupra primului rand al
                                 jumatatii de sud (y = fata de sud - 10, deci in gol). Randurile 8-9 sunt NEUTRE (ca mai sus), marginea de
                                 sus e zdrentuita (fiecare treapta incepe la alt rand), cu muchia luminata a ultimei asize si o dunga de
                                 mortar proaspat; fata dinspre nord a unui zid nu se vede din sud, deci nu se deseneaza. Acelasi
                                 inventar pe suprafata.
  prop_film_crane         64x48  doua cadre de 32x48 ("derrick" de lemn: catargul, bratul, scripetele, franghia): cadrul 0
                                 piatra jos, cadrul 1 piatra sus. Partile fixe sunt identice. Ancorata jos-centru (talpa e centrata pe
                                 coloana 16; piatra atarna pe coloanele 2-10 in ambele cadre).
  prop_film_stone_cart    28x16  caruciorul cu doua roti si cu blocuri de piatra luate din casele vechi.
  prop_film_stone_pile    32x16  gramada de pietre fatuite si cateva grinzi de lemn, pe mal.
  prop_film_dust          48x12  trei cadre de 16x12: un nor mic de praf de piatra si aschii de dalta care urca si se estompeaza
                                 (alfa), in bucla (cadrul 2 e aproape stins; cadrul 0 e un nor nou).

Aceleasi reguli ca restul conductei: culorile din palette.ramp(), niciodata negru pur, umbre translucide, lumina din
stanga-sus, contur trasat automat pe recuzita. Piatra e RAMPA lui a1_wall (ST), deci capetele se potrivesc cu zidul aprobat la A1.

Rulare: python3 scripts/art/a2_build.py [--out DIR]
"""
import argparse
import contextlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFont, ImageOps  # noqa: E402

import a1_wall as AW  # noqa: E402  (zidul aprobat: rampa pietrei si functiile de pixel ale treptelor)
from buildings import C, png  # noqa: E402
from palette import OUTLINE, WOOD, ramp  # noqa: E402
from ruins_d53 import line  # noqa: E402
from tycoon_e1 import outline_trace  # noqa: E402
from world import soft_shadow  # noqa: E402
import village_ground as VG  # noqa: E402

D = 3  # pixeli de lume pe pixel de arta (Assets.PIXEL_SCALE)
ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a2"
A1_WALL_PNG = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a1/prop_dam_wall.png"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---- numerele filmului (DamFilmSet.wall(): x0 639, top 381, bottom 771 lume) --------------------------------------------------
FILM_X0, FILM_TOP, FILM_BOTTOM = 213, 127, 257  # in pixeli de arta
FILM_X0_W = 639  # aceeasi in lume (pentru pozitiile oamenilor)
WALL_W, WALL_H = AW.W, AW.H  # 80 x 189
HALF = (FILM_BOTTOM - FILM_TOP) // 2  # 65: pana unde creste fiecare jumatate
SOUTH_OFF = FILM_BOTTOM - WALL_H  # 68: randul r al zidului sta, in jumatatea de sud, la y de arta r + 68
SEAM_N, SEAM_S = HALF - 1, WALL_H - HALF  # 64 si 124: randurile cusaturii cand jumatatile se ating
LEDGE_N = (24, 28)  # ressaltul de nord (randurile din care jumatatea de nord nu se opreste)
LEDGE_S = (125, 127)  # ressaltul de sud


def _river_end():
    """Ultimul rand al zidului filmului care sta in apa: raul satului (malul de sud, ~y 253) intra in jumatatea de sud, deci
    randul r e in rau cat r + 68 <= rotunjit(mal / 3). Aceeasi regula ca a1_wall.RIVER_END (primul rand de uscat), pe lumea 1."""
    near = VG.geometry(1)["near"]["y"]
    return max(round(near[FILM_X0 + x] / D) for x in range(WALL_W)) - SOUTH_OFF


FR_END = _river_end()  # 185

# ---- paleta: piatra vine din zid (aprobata), restul din rampe -------------------------------------------------------------
ST = AW.ST  # piatra calda, gri-nisipie: ST[0] umbra ... ST[5] lumina
DEEP = AW.DEEP
INK = AW.INK
IRON = ramp(214, 0.20, 0.44, val_span=0.40)  # fierul: scripetele, cercurile copaiei, dalta
ROPE = ramp(39, 0.30, 0.60, steps=5, hue_shift=8, val_span=0.34)  # franghia (ca franghia stalpului de plasa)
MORTAR = ramp(36, 0.16, 0.68)  # mortarul proaspat: bej deschis
MORTAR_WET = ramp(34, 0.20, 0.52)
TIMBER = ramp(28, 0.50, 0.58, steps=5, hue_shift=10, val_span=0.44)  # lemnul schelei: bustean curatat, mijlociu
BOARD = ramp(33, 0.44, 0.70, steps=5, hue_shift=8, val_span=0.34)  # scandurile podelei (mai deschise decat stalpii)
OLD = ramp(30, 0.34, 0.60, steps=6, hue_shift=8, val_span=0.50)  # piatra veche din case: gresie calda, pentru cateva blocuri
DUST = ramp(40, 0.10, 0.86, steps=4, hue_shift=6, val_span=0.20)  # praf de piatra: gri cald, aproape alb sus
T = (0, 0, 0, 0)


def h01(x, y, salt=0):
    return VG.hash01(x, y, salt)


def a(col, al):
    return (col[0], col[1], col[2], al)


def shade_px(c, x, y, al):
    """O umbra translucida peste ce e deja acolo (sau peste nimic): negru cu alfa mica."""
    c.put(x, y, (0, 0, 0, al))


# ---------------------------------------------------------------------------------------------------------------------------
# bucati comune
# ---------------------------------------------------------------------------------------------------------------------------
def block(c, x, y, w, h, t=3, ramp_=None):
    """Bloc de piatra fatuit, vazut de sus in 3/4: fata de sus luminata, muchia stanga luminata, dreapta si jos in umbra.
    `t` = tonul de baza (2..4) din rampa; `ramp_` = alta rampa (piatra veche din case)."""
    r = ramp_ or ST
    c.rect(x, y, w, h, r[t])
    c.rect(x, y, w, 1, r[min(5, t + 2)])
    if h > 2:
        c.rect(x, y + 1, 1, h - 1, r[min(5, t + 1)])
    c.rect(x + w - 1, y + 1, 1, h - 1, r[max(0, t - 2)])
    c.rect(x + 1, y + h - 1, w - 1, 1, r[max(0, t - 2)])
    if w >= 6 and h >= 4:
        c.put(x + 1, y + 1, r[min(5, t + 2)])  # un colt luminat in plus


def block_shadow(c, x, y, w, h):
    """Umbra unui bloc de pe suprafata: o banda translucida la dreapta si dedesubt (lumina vine din stanga-sus)."""
    for yy in range(y + 1, y + h + 1):
        shade_px(c, x + w, yy, 46)
    for xx in range(x + 1, x + w + 1):
        shade_px(c, xx, y + h, 40)


def tub(c, x, y, h=5):
    """Copaie cu mortar (7 x h, h = 4 sau 5): doage de lemn cu un cerc de fier, deasupra mortarul, un mistrie infipt (un rand mai
    sus). Umbra cade pe randul y + h. Varianta joasa (h = 4) incape unde suprafata are putine randuri."""
    hoop = y + 3 if h == 5 else y + 2
    for yy in range(y + 2, y + h):
        for xx in range(x, x + 7):
            lit = WOOD[4] if xx == x else (WOOD[3] if xx < x + 4 else (WOOD[2] if xx < x + 6 else WOOD[1]))
            c.put(xx, yy, lit)
    c.rect(x, hoop, 7, 1, IRON[2])  # cercul
    c.put(x, hoop, IRON[4])
    c.put(x + 6, hoop, IRON[0])
    c.rect(x + 1, y + h - 1, 5, 1, WOOD[0])  # fundul, in umbra
    # gura: buza de lemn si mortarul
    c.rect(x + 1, y, 5, 1, WOOD[3])
    c.rect(x, y + 1, 7, 1, WOOD[4])
    c.rect(x + 1, y + 1, 5, 1, MORTAR[2])
    c.rect(x + 2, y, 3, 1, MORTAR[3])
    c.put(x + 3, y, MORTAR[4])
    # mistria infipta: coada de lemn si lama de fier
    c.put(x + 5, y - 1, WOOD[2])
    c.put(x + 6, y - 1, WOOD[4])
    c.put(x + 4, y, IRON[3])
    for xx in range(x + 1, x + 8):
        shade_px(c, xx, y + h, 40)


def plank_on_top(c, x, y, length):
    """O scandura lasata pe suprafata (lungime x 2): fata luminata, muchia de jos in umbra, capetele taiate mai deschise,
    doua cuie, umbra translucida dedesubt."""
    c.rect(x, y, length, 1, BOARD[3])
    c.rect(x, y + 1, length, 1, BOARD[1])
    c.put(x, y, BOARD[4])
    c.put(x, y + 1, BOARD[3])
    c.put(x + length - 1, y, BOARD[2])
    c.put(x + length - 1, y + 1, BOARD[0])
    for nx in (x + 3, x + length - 4):
        c.put(nx, y, BOARD[0])
    for xx in range(x + 1, x + length + 1):
        shade_px(c, xx, y + 2, 44)


def mallet_chisel(c, x, y):
    """Ciocan de lemn si dalta, lasate una langa alta (aprox. 6x3)."""
    c.rect(x, y, 3, 2, WOOD[2])  # capul ciocanului
    c.rect(x, y, 3, 1, WOOD[4])
    c.rect(x + 3, y + 1, 2, 1, WOOD[1])  # coada
    c.rect(x, y + 3, 4, 1, IRON[3])  # dalta
    c.put(x + 4, y + 3, WOOD[3])
    shade_px(c, x + 3, y + 2, 40)


# ---------------------------------------------------------------------------------------------------------------------------
# 0. zidul filmului (80x189): zidul A1, uscat, cu raul satului
# ---------------------------------------------------------------------------------------------------------------------------
def crest_plain(y):
    """Randul y al coamei nu cade pe un rost de bloc, pe un pilastru, pe un rost de lespede sau pe un stalp de balustrada: un rand
    'curat', bun ca rand de legatura al unui capat."""
    return (y + 3) % 6 != 0 and (y % 24) not in (10, 11, 12) and y % 9 != 0 and (y + 5) % 9 != 0 and (y % 8) not in (0, 1)


def plain_face(x, y, river, by=None):
    """Pixelul fetei de la coloana x, randul y, cu piatra CURATA: tonul de baza al treptei (fara blocuri mai inchise sau mai
    deschise), fara muschi. `by` (optional) forteaza randul din asiza (0 = rost, 1 = muchie luminata, 2+ = lespede). Foloseste
    chiar AW.face_pixel, doar cu block_at inlocuit pe moment, deci urmeaza orice schimbare a pietrei A1."""
    orig = AW.block_at

    def forced(k, yy):
        b, ln, _tone, _moss = orig(k, yy)
        return (b if by is None else by), ln, 0, False

    AW.block_at = forced
    try:
        return AW.face_pixel(x, y, river)
    finally:
        AW.block_at = orig


def film_wall():
    """Zidul filmului: ca AW.wall(), dar uscat si cu raul satului. Schimbarile fata de AW.wall() (restul e copiat intocmai): pe randurile
    deversorului (29-124) fata de piatra si coama obisnuita in loc de apron/gura turbinei/panza (nici mouth_pixels, nici bucla W5/W3
    de pe coloanele 15-16, nici randul W4 de sub prag); ressalturile (24-28 si 125-127) raman; raul intra pana la randul FR_END (185,
    raul satului) la AMBELE jumatati, nu doar pana la 123; randurile cusaturii (64 si 124) au rost si muchie luminata."""
    c = C(WALL_W, WALL_H)
    for y in range(WALL_H):
        river = y <= FR_END
        for x in range(WALL_W):
            if y >= WALL_H - AW.front_h(x):
                col = AW.front_pixel(x, y)
            elif x < AW.CREST:
                col = AW.crest_pixel(x, y, False, river)
            else:
                col = AW.face_pixel(x, y, river)
            c.put(x, y, col)
    # pragul de nord al fostului deversor: o asiza de piatra care taie fata (muchie luminata, fata in umbra), cu rosturi (ca in A1)
    for x in range(AW.FACE, WALL_W):
        jx = (x + 3) % 9 == 0
        c.put(x, AW.SP_R0 - 5, AW.ST[5] if x < AW.TOE else AW.ST[4])
        c.put(x, AW.SP_R0 - 4, AW.ST[4] if not jx else AW.ST[3])
        c.put(x, AW.SP_R0 - 3, AW.ST[3] if not jx else AW.ST[2])
        c.put(x, AW.SP_R0 - 2, AW.ST[2])
        c.put(x, AW.SP_R0 - 1, AW.ST[0])
    # pragul de sud: o lespede peste fata, pe linia fostului mal (ca in A1)
    for x in range(AW.FACE, WALL_W):
        jx = (x + 5) % 9 == 0
        c.put(x, AW.SP_R1, AW.ST[5])
        c.put(x, AW.SP_R1 + 1, AW.ST[4] if not jx else AW.ST[3])
        c.put(x, AW.SP_R1 + 2, AW.ST[3] if not jx else AW.ST[2])
    # cusatura: cand jumatatile se ating, randul 64 (nord) e un rost de asiza, iar randul 124 (sud) muchia luminata a asizei urmatoare
    for x in range(AW.FACE, WALL_W - 1):
        c.put(x, SEAM_N, plain_face(x, SEAM_N, True, by=0))
        c.put(x, SEAM_S, plain_face(x, SEAM_S, True, by=1))
    # capatul de nord intra in mal: o buza de nisip cu inaltime lina (1-3 randuri) si o umbra de un rand dedesubt (ca in A1; ditherul pe
    # aceeasi grila de lume: peretele lumii 2 sta la y 131, cel al filmului la y 127, iar pasul matricei Bayer e 4)
    wgx, wgy = FILM_X0, FILM_TOP
    for x in range(3, WALL_W):
        d = AW.clamp(int(round(2.0 + 0.9 * math.sin(x * 0.21 + 0.7) + 0.5 * math.sin(x * 0.47))), 1, 3)
        for y in range(d):
            light = 0.62 if y == 0 else 0.38
            tone = VG.SAND[2] if VG.dither(wgx + x, wgy + y) < light else VG.SAND[1]
            c.px[y][x] = (tone[0], tone[1], tone[2], 255)
        c.px[d][x] = ST[1]
    # placa de alama pe fata de sud (a coamei): piatra de temelie
    for x in range(5, 11):
        c.put(x, WALL_H - 5, AW.BRASS[1])
        c.put(x, WALL_H - 4, AW.BRASS[2])
    c.put(5, WALL_H - 5, AW.BRASS[0])
    # marginea din dreapta: unde zidul da in raul de aval e o linie luminata de apa (pana la FR_END), pe uscat o muchie in umbra
    for y in range(4, WALL_H):
        c.px[y][WALL_W - 1] = AW.WATERLINE if y <= FR_END else ST[1]
    for x in range(WALL_W):
        c.px[WALL_H - 1][x] = DEEP
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# 1. schela (80x16, repetabila pe verticala)
# ---------------------------------------------------------------------------------------------------------------------------
SC_W, SC_H = 80, 16
SC_POSTS = (2, 38, 75)  # coloana din stanga a fiecarui stalp (3 px latime)
DECK_ROWS = 5  # podeaua: randurile 0-4
LEDGER = (5, 6)  # grinda de sub podea
OPEN0 = 7  # de aici in jos: golul, prin care se vede raul


def lashing(c, x, y, wide=5):
    """Legatura de franghie in jurul unui stalp (wide x 2): spire in diagonala, un capat atarnand."""
    for i in range(wide):
        c.put(x + i, y, ROPE[3] if i % 2 == 0 else ROPE[1])
        c.put(x + i, y + 1, ROPE[1] if i % 2 == 0 else ROPE[3])
    c.put(x + wide - 1, y + 2, ROPE[2])  # capatul liber
    c.put(x, y, ROPE[4])


def knee_brace(c, x, y_bot, sgn):
    """Contravantuire de colt, la 45 de grade, de la stalp spre grinda de deasupra (sgn +1 spre dreapta, -1 spre stanga): 2 px
    grosime, muchia luminata pe stanga, 8 randuri pe inaltime. Se termina sub grinda (randul OPEN0), nu o atinge de mai multe ori."""
    n = y_bot - OPEN0 + 1
    for i in range(n):
        xx = x + sgn * i
        yy = y_bot - i
        c.put(xx, yy, TIMBER[3])
        c.put(xx + 1, yy, TIMBER[1])


def scaffold():
    c = C(SC_W, SC_H)
    # --- stalpii: trei, pe toata inaltimea (randul 15 se leaga de randul 0 al treptei urmatoare); lumina pe stanga ----------
    for k, px in enumerate(SC_POSTS):
        for y in range(SC_H):
            c.put(px, y, TIMBER[4] if y % 8 else TIMBER[3])
            c.put(px + 1, y, TIMBER[3] if y % 8 else TIMBER[2])
            c.put(px + 2, y, TIMBER[1])
        c.put(px + 1, 10 + (k * 2) % 3, TIMBER[1])  # un nod
        c.put(px + 1, 14, TIMBER[2])
    # --- contravantuiri de colt, in gol: arcade de o parte si de alta a fiecarui stalp ------------------------------------
    for k, px in enumerate(SC_POSTS):
        if px + 3 + 8 <= SC_W:
            knee_brace(c, px + 3, SC_H - 2, +1)
        if px - 1 - 8 >= 0:
            knee_brace(c, px - 2, SC_H - 2, -1)
    # --- podeaua: 5 randuri vazute de sus. r0 muchia din spate (inchisa, ca un contur), r1-2 scandura A (r1 luminata, r2 in umbra),
    # r3-4 scandura B; capetele scandurilor (rosturi verticale) decalate pe fiecare scandura. Tonurile luminate raman sub ST[5] (203):
    # la amurg podeaua nu trebuie sa fie cel mai luminos lucru din cadru, ci zidul ----------------------------------------------
    row_tone = {0: TIMBER[0], 1: BOARD[2], 2: BOARD[1], 3: BOARD[3], 4: BOARD[1]}
    for y in range(DECK_ROWS):
        for x in range(SC_W):
            c.put(x, y, row_tone[y])
    for (ya, yb), step, off in (((1, 2), 23, 9), ((3, 4), 19, 2)):
        for x in range(off, SC_W, step):
            c.put(x, ya, BOARD[0])
            c.put(x, yb, TIMBER[0])
    for x in (4, 21, 36, 55, 71):
        c.put(x, 4, TIMBER[0])  # capete de cui in scandura B
    for x in (12, 30, 49, 64):
        c.put(x, 2, BOARD[0])
    # --- grinda de sub podea (fata ei): muchia de sus luminata, jos in umbra, capetele taiate ----------------------------
    for x in range(SC_W):
        c.put(x, LEDGER[0], TIMBER[3] if x % 13 else TIMBER[2])
        c.put(x, LEDGER[1], TIMBER[1] if x % 6 else TIMBER[0])
    c.put(0, LEDGER[0], TIMBER[4])
    c.put(0, LEDGER[1], TIMBER[2])
    c.put(SC_W - 1, LEDGER[0], TIMBER[1])
    c.put(SC_W - 1, LEDGER[1], TIMBER[0])
    # stalpii in fata grinzii (stau in fata ei), cu legaturile de franghie la grinda si la piciorul contravantuirilor
    for k, px in enumerate(SC_POSTS):
        for y in range(DECK_ROWS + 2):
            c.put(px, y, TIMBER[4] if y % 8 else TIMBER[3])
            c.put(px + 1, y, TIMBER[3] if y % 8 else TIMBER[2])
            c.put(px + 2, y, TIMBER[1])
        lashing(c, px - 1, LEDGER[0])
        lashing(c, px - 1, SC_H - 4)
    # --- umbra podelei, translucida, peste golul de dedesubt (dupa lemne, ca sa le innegreasca si pe ele) ----------------
    for x in range(SC_W):
        shade_px(c, x, OPEN0, 80)
        shade_px(c, x, OPEN0 + 1, 50)
        shade_px(c, x, OPEN0 + 2, 24)
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# 2-3. capetele zidului (80x10)
# ---------------------------------------------------------------------------------------------------------------------------
E_W, E_H = 80, 10
# unitatile coloanelor, ca in zid: coama (parapet, pavaj, balustrada), coloana 15, apoi treptele de cate 6 (ultima are 4)
UNITS = [(0, 3), (3, 9), (9, 15), (15, 16)] + [(16 + 6 * k, min(80, 22 + 6 * k)) for k in range(11)]
# edge_n: unde se termina fiecare unitate (randul de jos, exclusiv: 8..10) si cat de inalta e fata taiata: profilul zidului A1 (front_h):
# 7 randuri pe coama, apoi 6,6,5,5,4,4,3,3,2,2,2 pe trepte. Suprafata ajunge deci pana la randul EN_E = jos - fata (cel putin 2).
EN_BOTTOM = [10, 9, 10, 9] + [10, 9, 10, 9, 10, 10, 10, 9, 10, 10, 9]
EN_FH = [AW.FRONT] * 4 + [AW.front_h(AW.FACE + AW.STEP * k) for k in range(11)]
EN_E = [b - f for b, f in zip(EN_BOTTOM, EN_FH)]
assert all(e >= 2 for e in EN_E) and all(e + f <= E_H for e, f in zip(EN_E, EN_FH)), (EN_E, EN_FH)
# edge_s: de la ce rand incepe suprafata fiecarei unitati (randurile 8-9 sunt de legatura, deci neatinse)
ES_START = [2, 2, 1, 2] + [3, 2, 1, 2, 1, 1, 2, 3, 2, 1, 2]
JOIN_N, JOIN_S = 2, 2  # cate randuri neutre are fiecare capat la legatura (0-1 la edge_n, 8-9 la edge_s)


def unit_of(x):
    for i, (x0, x1) in enumerate(UNITS):
        if x0 <= x < x1:
            return i
    return len(UNITS) - 1


def _by(y):
    return AW.block_at(0, y)[:2]  # (randul din asiza, lungimea asizei): la fel pentru toate treptele


def _find_join_n():
    """Randul de zid de la care incepe suprafata lui edge_n: asiza intr-un loc 'curat' (randul 2 al unei asize de cel putin 6 randuri)
    si coama la fel, ca randurile 0-1 sa fie neutre pe toata latimea."""
    for y in range(30, 170):
        by, ln = _by(y)
        if by == 2 and ln >= 6 and crest_plain(y) and crest_plain(y + 1):
            return y
    raise RuntimeError("fara rand de legatura pentru edge_n")


def _find_join_s():
    """Randul de zid care corespunde randului 9 al lui edge_s: randul 4 al unei asize de cel putin 6 randuri (randurile 8-9 = randurile
    3-4 ale asizei) si coama curata pe ambele."""
    for y in range(30, 180):
        by, ln = _by(y)
        if by == 4 and ln >= 6 and crest_plain(y) and crest_plain(y - 1):
            return y
    raise RuntimeError("fara rand de legatura pentru edge_s")


N0 = _find_join_n()  # edge_n: randul y al sprite-ului e randul de zid N0 + y
S1 = _find_join_s()  # edge_s: randul y al sprite-ului e randul de zid S1 - (9 - y)


def surf_pixel(x, yw):
    """Pixelul de suprafata al unui capat, la randul de zid `yw`: piatra curata (fara muschi si fara blocuri mai inchise/deschise),
    in rau (muchia dinspre lac, linia luminata de apa pe coloana 79), ca zidul filmului."""
    if x == AW.W - 1:
        return AW.WATERLINE
    if x < AW.CREST:
        return AW.crest_pixel(x, yw, False, True)
    return plain_face(x, yw, True)


def cut_face_pixel(x, y, e, fh, ui):
    """Fata taiata a unei unitati (de la randul `e`): exact ca fata de sud a capatului din zid (front_pixel din a1_wall): muchia de
    sus luminata, blocuri cu rosturi verticale decalate, lumina pe prima coloana a treptei, umbra pe ultima, randul de jos
    in umbra (acolo n-ar fi pamant, dar jos se vede apa). Cateva blocuri mai calde: piatra luata din casele vechi."""
    r = y - e
    if r == 0:
        return ST[5]
    if r == fh - 1:
        return DEEP
    i = 3 if r % 2 else 2
    if (x + (r // 2) * 4 + ui * 3) % 8 == 0:
        i = 1
    if x >= AW.FACE:
        lc = (x - AW.FACE) % AW.STEP
        if lc == 0:
            i = min(5, i + 1)
        elif lc == AW.STEP - 1:
            i = max(0, i - 1)
    elif x == 0:
        i = max(0, i - 1)
    if h01(x // 4, ui + 3 * r, 8) < 0.14:
        return OLD[min(5, i + 1)]
    return ST[i]


def ok_n(x, w, y, h, mistrie=False):
    """Un obiect de la edge_n (cu umbra pe randul y + h si pe coloana x + w) sta intreg pe suprafata: de la randul 2 (0-1 sunt de
    legatura) pana la ultimul rand de suprafata al fiecarei unitati pe care o acopera."""
    top = y - 1 if mistrie else y
    for xx in range(x, min(E_W, x + w + 1)):
        assert top >= JOIN_N and y + h <= EN_E[unit_of(xx)] - 1, ("edge_n", x, w, y, h, xx, EN_E[unit_of(xx)])


def ok_s(x, w, y, h, mistrie=False):
    """La fel pentru edge_s: sub marginea de sus (randul de start + muchia luminata) si deasupra randurilor de legatura (8-9)."""
    top = y - 1 if mistrie else y
    for xx in range(x, min(E_W, x + w + 1)):
        assert top >= ES_START[unit_of(xx)] + 1 and y + h <= E_H - JOIN_S, ("edge_s", x, w, y, h, xx)


def wall_edge_n():
    c = C(E_W, E_H)
    for x in range(E_W):
        ui = unit_of(x)
        e, fh = EN_E[ui], EN_FH[ui]
        for y in range(E_H):
            if y < e:
                c.put(x, y, surf_pixel(x, N0 + y))
            elif y < e + fh:
                c.put(x, y, cut_face_pixel(x, y, e, fh, ui))
    # inventarul: doar pe trepte, unde suprafata are cateva randuri (pe coama fata taiata urca pana la randul 2-3)
    for x, y, w, h, kind in (
        (40, 2, 5, 3, "old"),
        (29, 2, 4, 2, "old"),
        (53, 2, 4, 3, "stone"),
    ):
        ok_n(x, w, y, h)
        block(c, x, y, w, h, 5 if kind == "old" else 4, OLD if kind == "old" else None)
        block_shadow(c, x, y, w, h)
    ok_n(46, 5, 3, 2)
    plank_on_top(c, 46, 3, 5)
    ok_n(59, 4, 2, 3)
    mallet_chisel(c, 59, 2)
    ok_n(65, 7, 3, 4, mistrie=True)
    tub(c, 65, 3, 4)
    ok_n(73, 4, 3, 2)
    block(c, 73, 3, 4, 2, 4)
    block_shadow(c, 73, 3, 4, 2)
    # mici aschii pe suprafata, doar unde e loc
    for i in range(14):
        x = 16 + int(h01(i, 4, 21) * 63)
        y = 2 + int(h01(i, 5, 22) * 6)
        if y <= EN_E[unit_of(x)] - 2 and c.px[y][x] == surf_pixel(x, N0 + y):  # doar pe piatra goala, nu peste un obiect
            c.put(x, y, ST[5] if h01(i, 6, 23) < 0.6 else ST[4])
    outline_bottom_only(c)
    return c


def wall_edge_s():
    c = C(E_W, E_H)
    for x in range(E_W):
        ui = unit_of(x)
        s = ES_START[ui]
        for y in range(s, E_H):
            col = surf_pixel(x, S1 - (E_H - 1 - y))
            r = y - s
            if r == 0:
                col = ST[5] if h01(x, ui, 5) > 0.25 else ST[4]  # muchia asizei, luminata
            elif r == 1 and y < E_H - JOIN_S and h01(x // 3, ui, 6) < 0.34:
                col = MORTAR_WET[2]  # mortar proaspat, o dunga scurta sub muchie
            c.put(x, y, col)
    # inventarul: doar unde e loc intre marginea de sus si randurile de legatura (8-9)
    ok_s(10, 5, 3, 3)
    mallet_chisel(c, 10, 3)
    ok_s(5, 5, 4, 3)
    block(c, 5, 4, 5, 3, 4, OLD)
    block_shadow(c, 5, 4, 5, 3)
    ok_s(22, 6, 4, 3)
    block(c, 22, 4, 6, 3, 4)
    block_shadow(c, 22, 4, 6, 3)
    ok_s(29, 4, 4, 2)
    block(c, 29, 4, 4, 2, 4, OLD)
    block_shadow(c, 29, 4, 4, 2)
    ok_s(40, 7, 3, 4, mistrie=True)
    tub(c, 40, 3, 4)
    ok_s(52, 10, 5, 2)
    plank_on_top(c, 52, 5, 10)
    ok_s(65, 5, 4, 3)
    block(c, 65, 4, 5, 3, 4, OLD)
    block_shadow(c, 65, 4, 5, 3)
    ok_s(72, 4, 4, 3)
    block(c, 72, 4, 4, 3, 3)
    block_shadow(c, 72, 4, 4, 3)
    # mici aschii de piatra imprastiate pe suprafata, pe langa margine (nu pe randurile de legatura)
    for i in range(18):
        x = int(h01(i, 1, 31) * 80)
        ui = unit_of(x)
        y = ES_START[ui] + 1 + int(h01(i, 2, 32) * 2)
        if y < E_H - JOIN_S:
            c.put(x, y, ST[5] if h01(i, 3, 33) < 0.6 else ST[4])
    outline_top_only(c)
    return c


def outline_bottom_only(c):
    """Conturul doar pe marginea de jos si pe laturile fetei taiate (spre gol), nu pe randul de sus: acolo se leaga de zid."""
    src = [row[:] for row in c.px]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3]:
                continue
            for dx, dy in ((0, -1), (1, 0), (-1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and src[ny][nx][3] > 200:
                    c.px[y][x] = INK
                    break


def outline_top_only(c):
    """Pentru edge_s: conturul pe marginea de sus (spre gol) si pe laturile ei; randul de jos se leaga de zid."""
    src = [row[:] for row in c.px]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3]:
                continue
            for dx, dy in ((0, 1), (1, 0), (-1, 0)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and src[ny][nx][3] > 200:
                    c.px[y][x] = INK
                    break


# ---------------------------------------------------------------------------------------------------------------------------
# 4. macaraua (2 x 32x48)
# ---------------------------------------------------------------------------------------------------------------------------
CR_W, CR_H = 32, 48
MAST_X = 18  # coloana din stanga a catargului (3 px)
MAST_TOP = 4
BASE_Y = 44  # pamantul, sub catarg
BOOM_FOOT = (19, 38)  # unde se prinde bratul de catarg
BOOM_TIP = (6, 9)  # varful bratului, cu scripetele: piatra atarna pe coloanele 2-10
SILL_X0, SILL_X1 = 6, 25  # talpile: cu conturul, coloanele 5-26, centrate pe coloana 16 (ancora jos-centru)


def crane_frame(stone_y):
    """Un cadru de macara: bratul inclinat spre stanga (spre zid), catargul la dreapta, franghia de la varful bratului pana la
    piatra. `stone_y` = randul de sus al pietrei atarnate (restul sta pe loc). Talpile sunt centrate pe coloana 16."""
    c = C(CR_W, CR_H)
    # umbra la sol: sub baza, si o umbra mai mica sub piatra (mai larga cand piatra e sus)
    soft_shadow(c, 16, BASE_Y + 1, 10, 2)
    sx = BOOM_TIP[0]
    lift = BASE_Y - (stone_y + 6)
    soft_shadow(c, sx + 3, BASE_Y + 1, 4 + min(2, lift // 12), 1)
    # talpile: o grinda culcata pe pamant, cu blocuri de contragreutate; un picior de sprijin in dreapta
    w = SILL_X1 - SILL_X0 + 1
    c.rect(SILL_X0, BASE_Y - 1, w, 3, TIMBER[2])
    c.rect(SILL_X0, BASE_Y - 1, w, 1, TIMBER[4])
    c.rect(SILL_X0, BASE_Y + 1, w, 1, TIMBER[0])
    c.put(SILL_X0, BASE_Y, TIMBER[4])
    c.rect(SILL_X1 - 4, BASE_Y - 3, 5, 2, TIMBER[1])
    for bx, bw in ((8, 5), (14, 4)):  # blocurile de contragreutate
        block(c, bx, BASE_Y - 4, bw, 3, 3)
    # troliul (vinciul): butoiul cu manivela, in fata catargului
    c.rect(10, BASE_Y - 8, 6, 4, TIMBER[2])
    c.rect(10, BASE_Y - 8, 6, 1, TIMBER[4])
    c.rect(10, BASE_Y - 5, 6, 1, TIMBER[0])
    for x in (11, 13, 15):
        c.put(x, BASE_Y - 7, ROPE[2])
        c.put(x, BASE_Y - 6, ROPE[1])
    c.rect(9, BASE_Y - 9, 1, 6, TIMBER[1])  # cadrul vinciului
    c.rect(16, BASE_Y - 9, 1, 6, TIMBER[1])
    line(c, 16, BASE_Y - 6, 20, BASE_Y - 10, WOOD[2], 1)  # manivela
    c.put(20, BASE_Y - 11, WOOD[4])
    # catargul: 3 px, de la baza pana sus; muchia din stanga luminata
    for y in range(MAST_TOP, BASE_Y):
        c.put(MAST_X, y, TIMBER[4] if y % 9 else TIMBER[3])
        c.put(MAST_X + 1, y, TIMBER[3])
        c.put(MAST_X + 2, y, TIMBER[1])
    c.rect(MAST_X - 1, MAST_TOP, 5, 2, TIMBER[0])  # capul catargului
    c.rect(MAST_X - 1, MAST_TOP, 5, 1, TIMBER[3])
    # contravantuirile catargului (doua sprijine pe pamant, in dreapta)
    line(c, MAST_X + 3, BASE_Y - 22, SILL_X1, BASE_Y - 2, TIMBER[1], 1)
    line(c, MAST_X + 3, BASE_Y - 21, SILL_X1, BASE_Y - 1, TIMBER[2], 1)
    # bratul: doua grinzi paralele, de la picior spre varf, gros de 2; lumina deasupra
    bx0, by0 = BOOM_FOOT
    bx1, by1 = BOOM_TIP
    line(c, bx0, by0 + 1, bx1, by1 + 1, TIMBER[0], 2)
    line(c, bx0, by0, bx1, by1, TIMBER[2], 2)
    line(c, bx0, by0 - 1, bx1, by1 - 1, TIMBER[4], 1)
    # franghia care sustine bratul: de la capul catargului pana aproape de varf (aproape orizontala)
    line(c, MAST_X, MAST_TOP + 1, bx1 + 2, by1 - 1, ROPE[2], 1)
    # scripetele de la varf: o roata rotunda de fier, 5 x 5 (randurile 6-10, coloanele 4-8, butucul la (6, 8)), cu colturile goale ca sa
    # citeasca rotund si nu ca o stea cu epi. Obada (12 pixeli): sus si stanga IRON[3] (lumina vine din stanga-sus), jos si dreapta
    # IRON[2]; in interior caneluri in umbra IRON[1], iar butucul de un pixel IRON[0]. Fara placa sub roata: franghia de ridicat
    # (de la randul 11) se prinde direct de obada de jos.
    wx, wy = bx1, by1 - 1
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if abs(dx) == 2 and abs(dy) == 2:
                continue  # coltul ramane transparent: outline_trace il inconjoara rotund
            on_rim = max(abs(dx), abs(dy)) == 2
            if not on_rim:
                col = IRON[0] if (dx, dy) == (0, 0) else IRON[1]
            else:
                col = IRON[3] if (dy == -2 or dx == -2) else IRON[2]
            c.put(wx + dx, wy + dy, col)
    # franghia de ridicat: de la scripete drept in jos pana la piatra, apoi spre vinci
    for y in range(by1 + 2, stone_y):
        c.put(bx1, y, ROPE[3])
    line(c, bx1, by1 + 2, 13, BASE_Y - 9, ROPE[1], 1)  # porneste de sub roata (randul 11), ca obada de jos sa ramana intreaga
    # piatra atarnata: un bloc fatuit legat cu doua franghii in V
    line(c, bx1, stone_y - 3, bx1 - 3, stone_y + 1, ROPE[3], 1)
    line(c, bx1, stone_y - 3, bx1 + 3, stone_y + 1, ROPE[3], 1)
    block(c, bx1 - 3, stone_y + 1, 7, 5, 4)
    c.put(bx1, stone_y - 4, IRON[3])  # carligul
    outline_trace(c)
    return c


def crane():
    c = C(CR_W * 2, CR_H)
    for f, sy in enumerate((33, 19)):
        fr = crane_frame(sy)
        for y in range(CR_H):
            for x in range(CR_W):
                c.px[y][f * CR_W + x] = fr.px[y][x]
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# 5. caruciorul cu piatra (28x16)
# ---------------------------------------------------------------------------------------------------------------------------
def stone_cart():
    c = C(28, 16)
    soft_shadow(c, 15, 14, 12, 2)
    # oiștea: doua prajini care coboara spre stanga, pana la pamant
    line(c, 9, 8, 1, 13, TIMBER[1], 1)
    line(c, 9, 7, 1, 12, TIMBER[3], 1)
    # patul: o lada joasa de scanduri; fata de sud spre noi
    c.rect(8, 5, 18, 3, TIMBER[2])
    c.rect(8, 5, 18, 1, TIMBER[4])
    c.rect(8, 7, 18, 1, TIMBER[0])
    c.rect(8, 5, 1, 3, TIMBER[4])
    c.rect(25, 5, 1, 3, TIMBER[1])
    # incarcatura: trei blocuri mari pe pat (cel din mijloc mai inalt); unul din gresie veche
    block(c, 9, 1, 5, 4, 3)
    block(c, 14, 0, 6, 5, 4)
    block(c, 20, 1, 5, 4, 3, OLD)
    # roata: obada de un pixel luminata sus-stanga, golul dintre spite in umbra, patru spite, butuc de fier; in fata patului
    cx, cy, r = 16.0, 11.0, 4.5
    for yy in range(int(cy - r) - 1, int(cy + r) + 2):
        for xx in range(int(cx - r) - 1, int(cx + r) + 2):
            dx, dy = xx - cx, yy - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            if d > r - 1.25:
                c.put(xx, yy, TIMBER[4] if (dx + dy) < 0 else TIMBER[2])
            else:
                spoke = abs(dx) < 0.7 or abs(dy) < 0.7
                c.put(xx, yy, TIMBER[2] if spoke else TIMBER[0])
    c.rect(15, 10, 3, 3, IRON[2])
    c.put(15, 10, IRON[4])
    c.put(16, 11, IRON[0])
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# 6. gramada de piatra (32x16)
# ---------------------------------------------------------------------------------------------------------------------------
def stone_pile():
    c = C(32, 16)
    soft_shadow(c, 16, 14, 14, 2)
    # grinzile culcata, in dreapta: trei, cu capetele taiate (miez deschis) si cate o scobitura de imbinare. Lumina vine din
    # stanga-sus: capatul din stanga (spre lumina) e cel mai luminos, cel din dreapta (spre est) e in umbra, cu inima lemnului doar
    # putin mai deschisa (BOARD[1] pe TIMBER[1]).
    for k, (x0, x1, y0) in enumerate(((16, 31, 11), (17, 29, 8), (18, 30, 5))):
        h = 3
        c.rect(x0, y0, x1 - x0 + 1, h, TIMBER[2])
        c.rect(x0, y0, x1 - x0 + 1, 1, TIMBER[4])
        c.rect(x0, y0 + h - 1, x1 - x0 + 1, 1, TIMBER[0])
        c.rect(x1, y0, 1, h, TIMBER[1])  # capatul taiat dinspre est: partea din umbra (lumina vine din stanga), deci inchis
        c.put(x1, y0 + 1, BOARD[1])  # inima lemnului: doar putin mai deschisa decat capatul, nicidecum cel mai luminos pixel al grinzii
        c.rect(x0, y0, 1, h - 1, TIMBER[4])  # capatul dinspre lumina: cel mai luminos
        c.rect(x0 + 4 + k * 3, y0 + 1, 2, 1, TIMBER[1])  # scobitura de dulgher
        c.put(x0 + 9, y0 + 1, TIMBER[0])  # un cui
    # pietrele: trei randuri, mai lat jos
    block(c, 1, 11, 6, 4, 3)
    block(c, 7, 11, 5, 4, 4)
    block(c, 12, 12, 5, 3, 2, OLD)
    block(c, 3, 7, 5, 4, 4)
    block(c, 8, 7, 6, 4, 3)
    block(c, 6, 3, 6, 4, 4)
    block(c, 0, 13, 3, 2, 2)  # o piatra mica, cazuta la baza
    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# 7. praful de piatra (3 x 16x12)
# ---------------------------------------------------------------------------------------------------------------------------
DU_W, DU_H = 16, 12


def dust_frame(f):
    """Un nor de praf care urca din punctul unde bate dalta: f0 mic, des, jos; f1 mai sus, mai larg; f2 imprastiat si ABIA vazut (cadrul
    de dinaintea unui nor nou: bucla se stinge, nu clipeste), cu aschiile cazand. Doua trepte de alfa (nor des / margine), plus puncte
    rare: nu o clatita translucida."""
    c = C(DU_W, DU_H)
    cx = 8
    base = DU_H - 2
    if f == 0:
        lobes = ((cx, base - 1, 2.6, 1.8), (cx - 2, base, 1.8, 1.3), (cx + 2.5, base, 1.6, 1.2))
        a_core, a_edge = 205, 120
    elif f == 1:
        lobes = ((cx - 1, base - 4, 3.2, 2.4), (cx + 2, base - 3, 2.6, 2.0), (cx - 3, base - 2, 2.0, 1.6))
        a_core, a_edge = 150, 84
    else:
        lobes = ((cx, base - 7, 3.4, 2.4), (cx - 3, base - 5, 2.2, 1.8), (cx + 3, base - 6, 2.4, 1.8))
        a_core, a_edge = 44, 22
    for lx, ly, rx, ry in lobes:
        for yy in range(int(ly - ry) - 1, int(ly + ry) + 2):
            for xx in range(int(lx - rx) - 1, int(lx + rx) + 2):
                d = ((xx - lx) / rx) ** 2 + ((yy - ly) / ry) ** 2
                if d <= 0.55:
                    # miezul: luminat sus-stanga, mai inchis jos-dreapta
                    tone = DUST[3] if (xx <= lx and yy <= ly) else DUST[2]
                    c.put(xx, yy, a(tone, a_core))
                elif d <= 1.0 and h01(xx, yy, 40 + f) < 0.78:
                    tone = DUST[1] if (xx <= lx) else DUST[0]
                    c.put(xx, yy, a(tone, a_edge))
    # aschii: pixeli luminati, mai tari decat norul; urca in f0-f1, cad si se sting in f2
    chips = {
        0: ((5, 8), (11, 7), (8, 5)),
        1: ((3, 6), (12, 4), (7, 2)),
        2: ((2, 8), (13, 7)),
    }[f]
    for i, (px, py) in enumerate(chips):
        c.put(px, py, a(ST[5] if i % 2 == 0 else ST[4], 235 if f < 2 else 110))
        if f == 1 and i == 1:
            c.put(px + 1, py + 1, a(ST[3], 150))
    return c


def dust():
    c = C(DU_W * 3, DU_H)
    for f in range(3):
        fr = dust_frame(f)
        for y in range(DU_H):
            for x in range(DU_W):
                c.px[y][f * DU_W + x] = fr.px[y][x]
    return c


SPRITES = {
    "prop_film_wall": film_wall,
    "prop_film_scaffold": scaffold,
    "prop_film_wall_edge_n": wall_edge_n,
    "prop_film_wall_edge_s": wall_edge_s,
    "prop_film_crane": crane,
    "prop_film_stone_cart": stone_cart,
    "prop_film_stone_pile": stone_pile,
    "prop_film_dust": dust,
}
SIZES = {
    "prop_film_wall": (80, 189),
    "prop_film_scaffold": (80, 16),
    "prop_film_wall_edge_n": (80, 10),
    "prop_film_wall_edge_s": (80, 10),
    "prop_film_crane": (64, 48),
    "prop_film_stone_cart": (28, 16),
    "prop_film_stone_pile": (32, 16),
    "prop_film_dust": (48, 12),
}


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


def world_wall():
    """Zidul aprobat la A1, generat din a1_wall (acelasi cod; la inceput se verifica identic cu PNG-ul din scratchpad)."""
    return to_image(AW.wall())


def river_bg(w, h):
    water = load_sprite("water_tile")
    bg = Image.new("RGBA", (w, h))
    for yy in range(0, h, water.height):
        for xx in range(0, w, water.width):
            bg.paste(water, (xx, yy))
    return bg


def ground_base():
    g = load_sprite("prop_village_ground")
    bg = river_bg(g.width, g.height)
    bg.alpha_composite(g)
    return bg


def frame_of(img, f, fw):
    return img.crop((f * fw, 0, (f + 1) * fw, img.height))


def dusk(img, rgb=(70, 34, 52), pct=0.45):
    over = Image.new("RGBA", img.size, rgb + (round(255 * pct),))
    out = img.copy()
    out.alpha_composite(over)
    return out


def silhouette(frame_img, sun_left=True):
    """Pentru scara: o silueta de om (16x24 -> 13x20 pixeli de arta), cu muchia stanga luminata de soarele jos."""
    px = frame_img.load()
    w, h = frame_img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 128:
                o[x, y] = (34, 22, 40, 255)
    for y in range(h):
        for x in range(w):
            if o[x, y][3] and (x == 0 or o[x - 1, y][3] == 0):
                o[x, y] = (232, 150, 70, 255)
    return out


def person(row=6, f=0, facing="right"):
    """Un om la lucru (randul `work`) din foile de strat: corp + tinuta, la 2.5x (= 5/6 din pixelul de arta). Randurile laterale
    privesc spre dreapta; spre stanga se oglindeste."""
    layers = []
    for n in ("body_a", "outfit_hodman", "hair_short"):
        sh = load_sprite(n)
        layers.append(sh.crop((f * 16, row * 24, f * 16 + 16, row * 24 + 24)))
    base = layers[0].copy()
    for l in layers[1:]:
        base.alpha_composite(l)
    small = base.resize((round(16 * 2.5 / D), round(24 * 2.5 / D)), Image.NEAREST)
    return ImageOps.mirror(small) if facing == "left" else small


# ---- compozitia in context: aceleasi numere ca DamFilmSet -------------------------------------------------------------------
def halves_rows(built):
    """Randurile de zid ridicate din fiecare jumatate (nord, sud) la `built` 0..1, ca DamFilmSet.halves (pe grila de 3 lume = 1 rand);
    la 1 se ating exact (65 + 65)."""
    k = max(0.0, min(1.0, built))
    n = int(math.floor(HALF * k + 0.5))
    span = FILM_BOTTOM - FILM_TOP
    s = span - n if k >= 1 else int(math.floor(HALF * k + 0.5))
    return n, s


def snap_n(n):
    """Fata de nord nu se opreste in ressaltul 24-28: sare de la 23 direct la 29."""
    return 29 if LEDGE_N[0] <= n <= LEDGE_N[1] else n


def snap_s(s):
    """Fata de sud nu se opreste in ressaltul 125-127: prima linie a jumatatii (189 - s) sare de la 128 direct la 124, deci s trece de
    la 61 la 65 (s = 62-64 inseamna linia 127-125)."""
    return HALF if LEDGE_S[0] <= WALL_H - s <= LEDGE_S[1] else s


def film_workers(n, s):
    """Oamenii de pe zid (DamFilmSet.workers), in pixeli de arta: talpile la fata de nord - 6 lume (pe jumatatea de nord) si la fata de
    sud + 24 lume (pe jumatatea de sud), cu foaia de lucru (0 ciocanul, 1 funia) si incotro privesc."""
    nf = FILM_TOP * D + n * D
    sf = FILM_BOTTOM * D - s * D
    return [
        ((FILM_X0_W + 60) / D, (nf - 6) / D, 0, "right"),
        ((FILM_X0_W + 172) / D, (nf - 6) / D, 1, "left"),
        ((FILM_X0_W + 84) / D, (sf + 24) / D, 1, "right"),
        ((FILM_X0_W + 190) / D, (sf + 24) / D, 0, "left"),
    ]


# pozitiile recuzitei (colt stanga-sus, in pixeli de arta): DamFilmSet.props() = baza jos-centru in lume, de la care se scade jumatatea
# latimii si inaltimea desenului
PROP_CRANE = (293, 222)  # (927, 811) lume, cadru 32 x 48
PROP_CART = (176, 258)  # (569, 823) lume, 28 x 16
PROP_PILE = (320, 261)  # (1009, 831) lume, 32 x 16


def blit_clipped(dst, src, pos, clip):
    """Pune `src` la `pos` in `dst`, taiat la dreptunghiul `clip` (x0, y0, x1, y1): ca un Frame cu ClipsDescendants."""
    x0, y0 = pos
    cx0, cy0, cx1, cy1 = clip
    ix0, iy0 = max(x0, cx0), max(y0, cy0)
    ix1, iy1 = min(x0 + src.width, cx1), min(y0 + src.height, cy1)
    if ix1 <= ix0 or iy1 <= iy0:
        return
    dst.alpha_composite(src.crop((ix0 - x0, iy0 - y0, ix1 - x0, iy1 - y0)), (ix0, iy0))


# praful (16 x 12, ancorat jos-centru in joc): coloana si randul de care sta lipit fiecare nor, fata de fata de nord / de sud. Nordul:
# coloana 33 (= x0 + 100 lume) cu talpa norului la 5 randuri sub fata, adica pe suprafata lui edge_n (acolo suprafata coloanei 33 se opreste
# la randul 5), nu pe zidul terminat. Sudul: coloana 50 (= x0 + 150 lume), talpa chiar la fata de sud (jos pe edge_s).
DUST_N = (33, 5)
DUST_S = (50, 0)


def composite(images, with_dusk, built, crane_frame_i=0, workers=True):
    """Zidul in sat, in joc: pamantul copt al lumii 1, jumatatea de nord de la malul de nord (randurile 0..n-1), jumatatea de sud de la
    malul de sud (randurile 189-s..188), capetele la fronturi (deasupra celor doua jumatati, in gol, taiate la gol cand mai are sub 20 de
    randuri), schela in gol, macaraua, caruciorul si gramada pe malul de sud (pozitiile din DamFilmSet), praful (cadrul 0) la ambele
    fronturi si patru oameni la lucru la locurile lor din DamFilmSet.workers. Cand jumatatile se ating (golul 0), capetele, schela si
    praful se ascund, DAR oamenii raman: in joc stau pe zidul inchis (`shown`, nu `building and gap > 0`), deci si pe placa."""
    box = (150, 105, 360, 285)
    bg = ground_base()
    wall = images["prop_film_wall"]
    n, s = halves_rows(built)
    n, s = snap_n(n), snap_s(s)
    if n:
        bg.alpha_composite(wall.crop((0, 0, WALL_W, n)), (FILM_X0, FILM_TOP))
    y_nf = FILM_TOP + n  # prima linie a golului (fata de nord)
    y_sf = FILM_BOTTOM - s  # prima linie a jumatatii de sud (fata de sud)
    gap = y_sf - y_nf
    if gap > 0:
        sc = images["prop_film_scaffold"]
        for ty in range(y_nf, y_sf, SC_H):
            bg.alpha_composite(sc.crop((0, 0, SC_W, min(SC_H, y_sf - ty))), (FILM_X0, ty))
    if s:
        bg.alpha_composite(wall.crop((0, WALL_H - s, WALL_W, WALL_H)), (FILM_X0, y_sf))
    if gap > 0:
        # edge_n cu randul 0 chiar pe fata de nord, edge_s cu randul 9 chiar deasupra fetei de sud; amandoua taiate la gol, ca la golul
        # ingust sa nu se calce peste jumatatile gata
        clip = (FILM_X0, y_nf, FILM_X0 + WALL_W, y_sf)
        blit_clipped(bg, images["prop_film_wall_edge_n"], (FILM_X0, y_nf), clip)
        blit_clipped(bg, images["prop_film_wall_edge_s"], (FILM_X0, y_sf - E_H), clip)
    # macaraua, caruciorul si gramada, pe malul de sud (pozitiile din DamFilmSet.props)
    bg.alpha_composite(frame_of(images["prop_film_crane"], crane_frame_i, CR_W), PROP_CRANE)
    bg.alpha_composite(images["prop_film_stone_cart"], PROP_CART)
    bg.alpha_composite(images["prop_film_stone_pile"], PROP_PILE)
    if gap > 0:
        du = frame_of(images["prop_film_dust"], 0, DU_W)
        bg.alpha_composite(du, (FILM_X0 + DUST_N[0] - DU_W // 2, y_nf + DUST_N[1] - DU_H))
        bg.alpha_composite(du, (FILM_X0 + DUST_S[0] - DU_W // 2, y_sf + DUST_S[1] - DU_H))
    # oamenii, la locurile din DamFilmSet.workers (pe jumatati, nu pe schela; ramasi si pe zidul inchis); la amurg, siluete
    for fx, fy, kind, facing in (film_workers(n, s) if workers else []):
        p = person(6, 0 if kind == 0 else 2, facing)
        if with_dusk:
            p = silhouette(p)
        bg.alpha_composite(p, (round(fx - p.width / 2), round(fy - p.height)))
    out = bg.crop(box)
    return dusk(out) if with_dusk else out


def front_samples(images, which, rows, scale=4):
    """Capatul pus la mai multe fronturi: pentru fiecare `n` (nord) sau `s0` (sud), cele 6 randuri de zid de pe langa front si capatul;
    ca sa se vada cum se leaga la rand diferit."""
    wall = images["prop_film_wall"]
    tiles = []
    for r in rows:
        if which == "n":
            t = river_bg(WALL_W, 6 + E_H + 2)
            t.alpha_composite(wall.crop((0, r - 6, WALL_W, r)), (0, 0))
            t.alpha_composite(images["prop_film_wall_edge_n"], (0, 6))
        else:
            t = river_bg(WALL_W, 2 + E_H + 6)
            t.alpha_composite(images["prop_film_wall_edge_s"], (0, 2))
            t.alpha_composite(wall.crop((0, r, WALL_W, r + 6)), (0, 2 + E_H))
        tiles.append(t.resize((t.width * scale, t.height * scale), Image.NEAREST))
    return tiles


def preview(images, outdir):
    S = 4
    lab = font(8)
    INK_BG = (86, 128, 64, 255)
    gut = 20
    tiles = []

    def tile(label, im, bg, scale=S):
        big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        t = Image.new("RGBA", (max(big.width, 200) + 16, big.height + 40), bg)
        ImageDraw.Draw(t).text((8, 10), label, font=lab, fill=(244, 238, 220, 255))
        t.alpha_composite(big, (8, 28))
        return t

    def on(im, bg_col=None, bg_img=None, pad=2):
        b = bg_img if bg_img is not None else Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), bg_col)
        b = b.copy()
        b.alpha_composite(im, (pad, pad))
        return b

    wall = images["prop_film_wall"]
    # randul 1: schela (o treapta + trei puse una peste alta, pe rau), capetele (cu cate 6 randuri de zid deasupra / dedesubt)
    sc = images["prop_film_scaffold"]
    stack = river_bg(80, 16 * 4)
    for k in range(4):
        stack.alpha_composite(sc, (0, k * 16))
    tiles.append(tile("prop_film_scaffold 80x16 (x4 stacked, on river)", stack, (0, 0, 0, 0)))
    tiles.append(tile("single, on river", on(sc, bg_img=river_bg(84, 20)), (0, 0, 0, 0)))
    en_ctx = river_bg(80, 18 + 10)
    en_ctx.alpha_composite(wall.crop((0, 33, 80, 39)), (0, 0))
    en_ctx.alpha_composite(images["prop_film_wall_edge_n"], (0, 6))
    tiles.append(tile("edge_n 80x10 (front n=39, 6 wall rows above)", en_ctx, (0, 0, 0, 0)))
    es_ctx = river_bg(80, 18 + 10)
    es_ctx.alpha_composite(images["prop_film_wall_edge_s"], (0, 0))
    es_ctx.alpha_composite(wall.crop((0, 150, 80, 156)), (0, 10))
    tiles.append(tile("edge_s 80x10 (front s0=150, 6 wall rows below)", es_ctx, (0, 0, 0, 0)))
    # randul 2: macaraua (2 cadre), caruciorul, gramada, praful (3 cadre)
    for label, name, bg in (
        ("crane 2 frames", "prop_film_crane", INK_BG),
        ("stone cart 28x16", "prop_film_stone_cart", INK_BG),
        ("stone pile 32x16", "prop_film_stone_pile", INK_BG),
        ("dust 3 frames", "prop_film_dust", (98, 86, 76, 255)),
    ):
        im = images[name]
        sc_ = 6 if name in ("prop_film_stone_cart", "prop_film_stone_pile", "prop_film_dust") else S
        tiles.append(tile(label, on(im, bg), bg, sc_))
    # randul 3: zidul filmului, jumatatile folosite (nord 0-64, sud 124-188) pe rau, si capetele la mai multe fronturi
    wn = wall.crop((0, 0, 80, HALF))
    ws = wall.crop((0, SEAM_S, 80, WALL_H))
    meet = river_bg(80, HALF * 2)
    meet.alpha_composite(wn, (0, 0))
    meet.alpha_composite(ws, (0, HALF))
    tiles.append(tile("prop_film_wall 80x189: rows 0-64 + 124-188 (the halves at the meet, built=1)", meet, (0, 0, 0, 0), 3))
    tiles.append(tile("prop_film_wall 80x189 (full, rows 29-124 unused)", wall, (0, 0, 0, 0), 2))
    # asezarea pe trei randuri
    rows = [tiles[:4], tiles[4:8], tiles[8:]]
    row_w = [sum(t.width for t in r) + gut * (len(r) + 1) for r in rows]
    row_h = [max(t.height for t in r) for r in rows]
    # randul 4: fronturile (edge_n la 4 fronturi, edge_s la 4 fronturi)
    jn = front_samples(images, "n", (10, 20, 33, 47, 58))
    js = front_samples(images, "s", (134, 150, 163, 176, 186))
    # compozitiile: patru panouri 2 x 2 (ziua / amurg, jumatatile la 60% si la 100%)
    CS = 3
    pans = {}
    for tag, built in (("A_built0.6", 0.6), ("B_built1.0", 1.0)):
        for dk in (False, True):
            im = composite(images, dk, built, 0 if built < 1 else 1)
            pans[(tag, dk)] = im
            im.save(os.path.join(outdir, f"build_context_{tag}_{'dusk' if dk else 'day'}.png"))
    # panoul B (golul inchis): oamenii TREBUIE sa se vada pe zidul inchis, ca in joc (`shown`); comparatia cu/fara ii masoara
    nob = composite(images, False, 1.0, 1, workers=False)
    diff = [(x, y) for y in range(nob.height) for x in range(nob.width) if nob.getpixel((x, y)) != pans[("B_built1.0", False)].getpixel((x, y))]
    assert diff, "panoul B n-are oameni pe zidul inchis"
    dx_, dy_ = [p[0] for p in diff], [p[1] for p in diff]
    print(f"panoul B (built=1, golul 0): oamenii se vad pe zidul inchis, {len(diff)} pixeli, in x {min(dx_)}-{max(dx_)}, y {min(dy_)}-{max(dy_)} (din cadrul 210x180); "
          f"golul = {FILM_BOTTOM - FILM_TOP - sum(snap_n(halves_rows(1.0)[0]) if i == 0 else snap_s(halves_rows(1.0)[1]) for i in (0, 1))} randuri, deci capetele, schela si praful sunt ascunse")
    cd = [pans[k].resize((pans[k].width * CS, pans[k].height * CS), Image.NEAREST) for k in pans]
    pw, ph = cd[0].size
    comp_w = 2 * pw + gut * 3
    front_w = max(sum(t.width for t in jn), sum(t.width for t in js)) + gut * 7
    out_w = max(max(row_w), comp_w, front_w)
    out_h = sum(row_h) + 2 * (ph + 24) + gut * 7 + jn[0].height + js[0].height + 50
    out = Image.new("RGBA", (out_w, out_h), (24, 30, 34, 255))
    y = gut
    d = ImageDraw.Draw(out)
    for r, rh in zip(rows, row_h):
        x = gut
        for t in r:
            out.alpha_composite(t, (x, y))
            x += t.width + gut
        y += rh + gut
    d.text((gut, y), "edge_n at fronts n = 10, 20, 33, 47, 58 (neutral join rows 0-1)", font=lab, fill=(244, 238, 220, 255))
    y += 16
    x = gut
    for t in jn:
        out.alpha_composite(t, (x, y))
        x += t.width + gut
    y += jn[0].height + gut
    d.text((gut, y), "edge_s at fronts s0 = 134, 150, 163, 176, 186 (neutral join rows 8-9)", font=lab, fill=(244, 238, 220, 255))
    y += 16
    x = gut
    for t in js:
        out.alpha_composite(t, (x, y))
        x += t.width + gut
    y += js[0].height + gut
    labels = [
        "A built=0.6 day (x3)",
        "A built=0.6 dusk tint (70,34,52) 45%",
        "B built=1 day: halves meet, workers stay on the closed wall",
        "B built=1 dusk",
    ]
    for i, im in enumerate(cd):
        col, row = i % 2, i // 2
        px_, py_ = gut + col * (pw + gut), y + row * (ph + 24)
        d.text((px_, py_), labels[i], font=lab, fill=(244, 238, 220, 255))
        out.alpha_composite(im, (px_, py_ + 14))
    path = os.path.join(outdir, "build_preview.png")
    out.save(path)
    print("scris", path, out.size)


def check_wall_identity():
    """Zidul generat de a1_wall trebuie sa fie exact cel aprobat (altfel capetele nu se leaga). Referinta: PNG-ul din scratchpad (cat
    tine sesiunea) sau, dupa urcarea lotului A1, assets/sprites/prop_dam_wall.png; fara niciuna se tipareste o nota, dar de
    cum exista una, o schimbare in a1_wall pica generatorul."""
    refs = [p for p in (A1_WALL_PNG, os.path.join(SPR, "prop_dam_wall.png")) if os.path.exists(p)]
    if not refs:
        print("nota: lipsesc", A1_WALL_PNG, "si assets/sprites/prop_dam_wall.png (nu se poate verifica identitatea zidului)")
        return
    got = list(world_wall().getdata())
    for path in refs:
        same = list(Image.open(path).convert("RGBA").getdata()) == got
        print("zidul din a1_wall == PNG-ul aprobat", path.replace(ROOT + os.sep, "") if path.startswith(ROOT) else "(scratchpad)" + ":", same)
        assert same, f"a1_wall nu mai produce zidul aprobat din {path}: capetele nu se mai potrivesc"


def luma(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def report(images):
    """Cifre de control: zidul filmului (apa, randurile folosite, ce difera de A1), nepotrivirea capetelor la fiecare front folosit,
    repetabilitatea schelei, macaraua, praful, culorile."""
    wall = images["prop_film_wall"]
    wpx = wall.load()
    a1 = world_wall().load()
    # (1) fara apa albastra in zid, pe coloanele 1-78, pe nicio linie (coloana 79 e linia luminata de apa, intentionat)
    blue = [(x, y) for y in range(WALL_H) for x in range(1, WALL_W - 1) if wpx[x, y][2] > wpx[x, y][0] + 40]
    print("prop_film_wall: pixeli cu b > r+40 pe coloanele 1-78:", len(blue), blue[:6])
    assert not blue, "apa copta a ramas in zid"
    # (2) ce difera de zidul A1: pe randuri
    diff_rows = sorted({y for y in range(WALL_H) for x in range(WALL_W) if wpx[x, y] != a1[x, y]})
    spans, start = [], None
    for y in range(WALL_H + 1):
        on = y in diff_rows
        if on and start is None:
            start = y
        if not on and start is not None:
            spans.append((start, y - 1))
            start = None
    print("  randuri diferite de zidul A1:", spans, "| randurile 0-28 identice:", all(y > 28 for y in diff_rows))
    # (3) jumatatile folosite: ce apa a ramas in randurile 0-64 si 124-188 pe coloana 79 / 0
    print(f"  raul satului in zid pana la randul {FR_END}; coloana 79 = linia luminata de apa pe randurile 4-{FR_END}:",
          all(wpx[79, y] == AW.WATERLINE for y in range(4, FR_END + 1)), "| coloana 0 DEEP_LAKE pe randurile 4-" + str(WALL_H - AW.FRONT - 1) + " (sub ele, fata de sud):",
          all(wpx[0, y] == AW.DEEP_LAKE for y in range(4, WALL_H - AW.FRONT)))
    # (4) nepotrivirea capetelor: edge_n randul 0 fata de randul n al zidului (frontul n), edge_s randul 9 fata de randul s0 - 1
    en = images["prop_film_wall_edge_n"].load()
    es = images["prop_film_wall_edge_s"].load()
    mn = [(n, sum(1 for x in range(80) if wpx[x, n] != en[x, 0])) for n in range(1, HALF) if not (LEDGE_N[0] <= n <= LEDGE_N[1])]
    ms = [(s0, sum(1 for x in range(80) if wpx[x, s0 - 1] != es[x, 9])) for s0 in range(SEAM_S + 4, WALL_H) if not (LEDGE_S[0] <= s0 <= LEDGE_S[1])]
    for name, m in (("edge_n randul 0 vs randul n al zidului, n = 1-64 (fara 24-28)", mn), ("edge_s randul 9 vs randul s0-1 al zidului, s0 = 128-188", ms)):
        vals = [v for _, v in m]
        worst = max(m, key=lambda t: t[1])
        print(f"  {name}: coloane diferite din 80: min {min(vals)}, medie {sum(vals) / len(vals):.1f}, max {max(vals)} (la {worst[0]}); "
              f"fronturi cu > 40: {sum(1 for v in vals if v > 40)} din {len(vals)}; cu 0: {sum(1 for v in vals if v == 0)}")
        print("    pe fronturi:", " ".join(f"{k}:{v}" for k, v in m))
    print(f"  randul de legatura: edge_n = randul de zid {N0}+ (asiza {_by(N0)}), edge_s = randul {S1} (asiza {_by(S1)}); "
          f"EN_E={EN_E} (suprafata), ES_START={ES_START}")
    # (5) repetabilitatea schelei: ce e opac pe randul 15 e legat de randul 0 (stalpii sunt intregi)
    sp = images["prop_film_scaffold"].load()
    cont = all(sp[x, 15][3] == 0 or sp[x, 0][3] != 0 for x in range(80))
    posts_ok = all(sp[x, 15][3] == sp[x, 0][3] for x in range(80) if sp[x, 15][3] == 255 and sp[x, 0][3] == 255)
    print("scheala: pixelii opaci de pe randul 15 au sub ei pixeli opaci pe randul 0:", cont, "| stalpi continui:", posts_ok)
    lit = [luma(p) for p in (BOARD[3], BOARD[2])]
    print(f"  podeaua: tonul cel mai luminos {max(lit):.0f} fata de ST[5] {luma(ST[5]):.0f} (piatra ramane cea mai luminoasa)")
    # (6) macaraua: cele doua cadre difera doar in franghie / piatra / umbra de sub piatra
    cr = images["prop_film_crane"]
    f0, f1 = frame_of(cr, 0, 32), frame_of(cr, 1, 32)
    box = [(x, y) for y in range(48) for x in range(32) if f0.getpixel((x, y)) != f1.getpixel((x, y))]
    xs, ys = [p[0] for p in box], [p[1] for p in box]
    print(f"prop_film_crane: cadrele difera in {len(box)} pixeli, x {min(xs)}-{max(xs)}, y {min(ys)}-{max(ys)} (restul e identic)")
    opaque = [x for x in range(32) for y in range(48) if f0.getpixel((x, y))[3] == 255]
    base = [x for x in range(32) if f0.getpixel((x, 44))[3] > 0 or f0.getpixel((x, 45))[3] > 0 or f0.getpixel((x, 43))[3] > 0]
    print(f"  talpa opaca pe coloanele {min(base)}-{max(base)} (centru {(min(base) + max(base)) / 2:.1f}); coloana cea mai din stanga opaca: {min(opaque)}")
    # (6b) scripetele: o roata rotunda 5 x 5 (randurile 6-10, coloanele 4-8, butuc la (6, 8)), identica in ambele cadre; colturile sunt conturul
    # (nu fier), deci nu mai ies epi in cele patru directii
    for f, fr in enumerate((f0, f1)):
        iron = {tuple(c[:3]) for c in IRON}
        grid = [[fr.getpixel((x, y)) for x in range(3, 10)] for y in range(5, 12)]
        corners = [fr.getpixel(pt)[:3] for pt in ((4, 6), (8, 6), (4, 10), (8, 10))]
        ring = [fr.getpixel((x, y))[:3] for y in range(6, 11) for x in range(4, 9) if not (abs(x - 6) == 2 and abs(y - 8) == 2)]
        assert all(cn == tuple(OUTLINE[:3]) for cn in corners), ("colt de scripete nu e contur", f, corners)
        assert all(px in iron for px in ring), ("scripetele nu e tot din fier", f)
        assert fr.getpixel((6, 8))[:3] == tuple(IRON[0][:3])
        if f == 0:
            print("prop_film_crane: scripetele 5x5 rotund, colturile (4,6) (8,6) (4,10) (8,10) = contur, 21 pixeli de fier, butuc IRON[0] la (6, 8); harta (7 x 7, # fier, o contur, . gol):")
            for row in grid:
                print("   ", "".join("." if px[3] == 0 else ("#" if tuple(px[:3]) in iron else "o") for px in row))
    print("  scripetele identic in ambele cadre:", all(f0.getpixel((x, y)) == f1.getpixel((x, y)) for y in range(0, 12) for x in range(0, 14)))
    # (6c) gramada: grinzile primesc lumina din stanga; cel mai luminos pixel al grinzilor trebuie sa fie la capatul de vest
    pile = images["prop_film_stone_pile"]
    beams = ((16, 31, 11), (17, 29, 8), (18, 30, 5))
    west = max(luma(pile.getpixel((x0, y))) for x0, _, y0 in beams for y in range(y0, y0 + 2))
    east = max(luma(pile.getpixel((x1, y))) for _, x1, y0 in beams for y in range(y0, y0 + 3))
    east_zone = max(luma(pile.getpixel((x, y))) for x0, x1, y0 in beams for x in range(x1 - 1, x1 + 1) for y in range(y0 + 1, y0 + 3))
    print(f"prop_film_stone_pile: cel mai luminos pixel al grinzilor: capat de vest (lumina) {west:.0f}, capat de est (umbra) {east:.0f}, "
          f"ultimele doua coloane din est {east_zone:.0f} | inima lemnului {tuple(BOARD[1][:3])} pe capatul {tuple(TIMBER[1][:3])}")
    assert east < west and east_zone < west, "capatul din umbra a ramas mai luminos decat cel luminat"
    # (7) praful: bucla se stinge
    du = images["prop_film_dust"]
    asum = [sum(p[3] for p in frame_of(du, f, 16).getdata()) for f in range(3)]
    cnt = [sum(1 for p in frame_of(du, f, 16).getdata() if p[3]) for f in range(3)]
    print("prop_film_dust: suma alfa pe cadre", asum, "| pixeli", cnt)
    # (8) culori: cel mai intunecat pixel opac nu coboara sub OUTLINE
    dark = min((p for im in images.values() for p in im.getdata() if p[3] == 255), key=luma)
    print("cel mai intunecat pixel opac din toate:", dark[:3], "| OUTLINE:", OUTLINE[:3], "| nu mai intunecat:", luma(dark) >= luma(OUTLINE) - 0.5)
    for name, im in images.items():
        cols = {p for p in im.getdata() if p[3]}
        print(f"{name}: {im.size[0]}x{im.size[1]} | culori distincte {len(cols)}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=SCRATCH)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    check_wall_identity()
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
