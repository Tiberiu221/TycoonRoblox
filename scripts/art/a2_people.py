#!/usr/bin/env python3
"""[D75, lotul A2, grupul "people and bells"] Oamenii si clopotul filmului barajului (DamMath.FILM, DamFilm).
Scrie DOAR in scratchpad-ul sesiunii (--out); nimic nu intra in assets/sprites si nimic nu se urca.

  prop_film_walkers  64x96  4 randuri x 4 cadre de 16x24 (aceeasi grila ca foile oamenilor body_a / outfit_*; in joc, x2,5):
                            SILUETE la apus care merg spre DREAPTA. Corpul (38,24,42), bratul dinspre noi un pic mai deschis si
                            cel dinspre fund un pic mai inchis (ca sa se desprinda), marginea dinspre soare (STANGA) aprinsa
                            (255,170,96), marginea de sus mai slaba. Mers in 4 cadre ca walk_side: doua cadre de pas (picioarele
                            desfacute, trunchiul la randul 11) si doua de trecere (un picior plantat, celalalt indoit cu laba
                            ridicata in spate, trunchiul cu un rand mai sus); bratele se balanseaza invers fata de picioare.
                            Rand 0: mainile goale, par scurt. Rand 1: grinda pe umar (peste gat, sub barbie), sapca cu cozoroc.
                            Rand 2: bloc de piatra fatuita (aceeasi piatra ca prop_dam_wall, innegrita de apus) tinut in brate,
                            coc. Rand 3: felinar intins inainte, par lung si palton lung; felinarul (miez cald + aura in doua
                            trepte + o balta de lumina pe pamant) e singurul lucru aprins. Talpile stau pe randul 22 al celulei.
  prop_film_walkers_l 64x96 ACELASI continut, dar cu fata spre STANGA (fiecare celula 16x24 oglindita ORIZONTAL inainte de
                            lumina de margine): soarele joaca din stanga, deci un om care merge spre stanga are marginea aprinsa
                            pe FATA lui, nu pe ceafa. Jocul alege foaia dupa sens si taie cu ImageRectSize pozitiv (fara oglindire
                            la randare: o oglindire mutatoare lumina pe partea gresita a jumatate din multime).
  prop_film_workers  64x48  2 randuri x 4 cadre de 16x24, siluete la lucru pe podina schelei, cu fata spre dreapta, talpile pe
                            randul 22. Rand 0: ciocanul de piatra, omul ghemuit (ridica, varf, coboara, LOVITURA pe cadrul 3:
                            capul ciocanului pe blocul din fata, trunchiul aplecat, scanteie). Blocul de pe podina e desenat dupa
                            lumina de margine (acelasi pe toate cadrele, marginea aprinsa pe partea soarelui). Rand 1: tragerea unei funii mana
                            peste mana (trunchiul lasat pe spate, funia coboara din dreapta-sus, iese din celula spre un scripete
                            din afara ei, prin maini, si cade intr-un colac asezat la distanta de talpa; dungile funiei coboara
                            cu 1 px pe cadru, spre maini).
  prop_film_workers_l 64x48 la fel, cu fata spre STANGA (oglindit ca mai sus; scanteia, funia si colacul se oglindesc odata cu ei).
  prop_film_works_bell_swing 120x56  3 cadre de 40x56: Clopotul Works (copie exacta a lui prop_works_bell.png) cu clopotul si
                            jugul balansate: cadrul 1 STANGA, 2 CENTRU, 3 DREAPTA. Balansul e o rotatie mica in jurul capului
                            jugului, facuta din doua forfecari: pe randuri (pana la 3 px la buza) si pe coloane (partea din
                            fata a buzei urca cu 1 rand, cea din urma coboara cu 1), deci clopotul se INCLINA, nu doar se
                            leaga; batalul ramane putin in urma. Clopotul nu iese din fata dinauntru a montantilor (alama intre
                            coloanele 11-28), iar pe partea din fata are mereu o coloana de contur INTUNECAT (coloanele 10 / 29),
                            deci buza nu se lipeste de lumina montantului. Cadrul 2 e IDENTIC la pixel cu sprite-ul static; in 1 si
                            3, diferentele stau doar in amprenta clopotului (coloanele 10-30, randurile 13-37), iar locul clopotului
                            din imaginea statica ramane acoperit opac (golul e intunecat, ca interiorul clopotului), deci jocul
                            poate pune cadrul exact peste sprite-ul static. Locul lasat de clopot reia zabrelele si semnele de
                            pe montanti (se repeta din 8 in 8 randuri), nu o pata intunecata. Pe cadrele extreme, 3 dungi de
                            miscare de EXACT 2 pixeli (randurile 21 / 24 / 27), aceleasi pe STANGA si DREAPTA, pe partea din
                            urma. `check_bell()` verifica toate astea la fiecare rulare.

Aceleasi reguli ca restul conductei: culorile din tonuri fixe sau palette.mix(), niciodata negru pur, lumina de la soarele
jos din STANGA. NU suprascrie nimic din assets/sprites.

Rulare: python3 scripts/art/a2_people.py [--out DIR]
"""
import argparse
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

from buildings import C, png  # noqa: E402
from palette import mix  # noqa: E402,F401

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a2"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

CW, CH = 16, 24  # celula unui om (AnimConfig.FRAME_WIDTH / FRAME_HEIGHT)
T = (0, 0, 0, 0)

# ---- paleta siluetelor (lumina joasa a soarelui vine din STANGA) --------------------------------------------------------
BODY = (38, 24, 42, 255)  # corpul, tonul cerut de film
FAR = (29, 18, 34, 255)  # membrele dinspre fund, ca sa se desprinda de trunchi
ARM = (60, 40, 64, 255)  # bratul dinspre noi, putin mai deschis, ca sa se vada peste trunchi
RIM = (255, 170, 96, 255)  # marginea dinspre soare
RIM_TOP = (186, 112, 80, 255)  # marginea de sus, mai slaba (soarele e jos)
WOOD = (80, 54, 50, 255)  # grinda: ridicata peste BODY (38,24,42) ca sa se desprinda
WOOD_HI = (122, 84, 62, 255)  # fata de sus a lemnului
WOOD_END = (156, 110, 80, 255)  # capatul taiat al grinzii
# piatra fatuita = rampa de piatra a lui prop_dam_wall (a1_wall.ST: 61,54,47 / 90,82,73 / 118,111,101), innegrita pentru apus
STONE_TOP = (118, 111, 101, 255)  # fata de sus (ST[2])
STONE_FRONT = (76, 68, 60, 255)  # fata din fata (ST[1] innegrit)
STONE_LO = (58, 50, 48, 255)  # rostul si randul de jos
ROPE = (128, 88, 66, 255)  # funia
ROPE_HI = (172, 124, 86, 255)
SPARK = (255, 226, 160, 255)
SPARK_HOT = (255, 248, 214, 255)
LAMP_GLASS = (255, 232, 160, 255)
LAMP_CORE = (255, 250, 220, 255)
LAMP_FRAME = (30, 19, 32, 255)
GLOW = (255, 170, 96)


# ---------------------------------------------------------------------------------------------------------------------------
# unelte de desen
# ---------------------------------------------------------------------------------------------------------------------------
def line(c, x0, y0, x1, y1, col, w=1):
    """Segment gros de `w` pixeli (Bresenham, cu un patrat w x w pe fiecare pas; patratul are coltul stanga-sus pe punct)."""
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        c.rect(x0, y0, w, w, col)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def leg(c, hx, fx, y0, y1, col, w=3, toe=2):
    """Un picior de la sold (hx, y0) la laba piciorului (fx, y1); laba iese `toe` pixeli spre dreapta."""
    n = max(1, y1 - y0)
    for i in range(n + 1):
        c.rect(round(hx + (fx - hx) * i / n), y0 + i, w, 1, col)
    c.rect(fx, y1, w + toe, 1, col)


def bent_leg(c, hx, y0, kx, ky, fx, y1, col, w=3, toe=1):
    """Picior indoit (cadrul de trecere): sold -> genunchi (inainte) -> laba ridicata."""
    for i in range(ky - y0 + 1):
        n = max(1, ky - y0)
        c.rect(round(hx + (kx - hx) * i / n), y0 + i, w, 1, col)
    for i in range(y1 - ky + 1):
        n = max(1, y1 - ky)
        c.rect(round(kx + (fx - kx) * i / n), ky + i, w, 1, col)
    c.rect(fx, y1, w + toe, 1, col)


HEAD = [(2, 7), (1, 8), (0, 9), (0, 10), (0, 9), (1, 9), (1, 8), (2, 7)]  # (x0, x1) pe randuri; fata spre dreapta, nasul pe randul 3
NECK = (3, 6)  # gatul: un rand, mai ingust, sub barbie; fara el capul si trunchiul se lipesc intr-o fasole


def head(c, hx, hy, kind, col=BODY, bun_dx=0.8):
    """Capul (10 x 8, nas spre dreapta) cu gat, plus coafura: scurta, sapca cu cozoroc, coc sau par lung. `bun_dx` = cu cat sta
    centrul cocului in spatele coloanei hx (0,8 la mergatori; 0,3 la omul cu funia, aplecat pe spate, ca sa nu-l taie marginea celulei)."""
    for i, (a, b) in enumerate(HEAD):
        c.rect(hx + a, hy + i, b - a + 1, 1, col)
    c.rect(hx + NECK[0], hy + 8, NECK[1] - NECK[0] + 1, 1, col)
    if kind == "short":
        c.rect(hx + 2, hy - 1, 6, 1, col)  # parul scurt, cu un smoc pe frunte
        c.put(hx + 8, hy - 1, col)
    elif kind == "cap":
        c.rect(hx + 1, hy - 1, 8, 1, col)  # calota sapcii
        c.rect(hx + 9, hy + 2, 4, 1, col)  # cozorocul, spre inainte
        c.rect(hx + 9, hy + 1, 2, 1, col)
    elif kind == "bun":
        c.ellipse(hx - bun_dx, hy + 1.2, 1.8, 1.8, col)  # cocul: o bila sus, in spatele capului, iese 2 pixeli in spate
        c.rect(hx + 2, hy - 1, 5, 1, col)
    elif kind == "long":
        c.rect(hx + 2, hy - 1, 6, 1, col)
        c.rect(hx - 2, hy + 2, 3, 7, col)  # parul lung, cazut pe spate pana la umar
        c.rect(hx - 1, hy + 9, 2, 1, col)


def torso(c, x, y, col=BODY, h=6, flare=True, coat=0, lean=0):
    """Trunchiul: 8 pixeli lat, h randuri, umerii rotunjiti; pe ultimul rand tunica se evazeaza. `coat` randuri de palton lung
    in plus. `lean` = cu cate coloane e mutat randul de sus fata de sold (inclinare spre inainte/inapoi, forfecare pe randuri)."""
    for i in range(h):
        dx = round(lean * (1 - i / max(1, h - 1)))
        if i == 0:
            c.rect(x + 1 + dx, y, 6, 1, col)
        else:
            c.rect(x + dx, y + i, 8, 1, col)
    if flare:
        c.rect(x - 1, y + h - 1, 10, 1, col)
    for i in range(coat):
        c.rect(x - 1 - (i + 1) // 2, y + h + i, 10 + (i + 1) // 2, 1, col)


def flip(c):
    """Oglindire orizontala pe loc a unei celule."""
    for row in c.px:
        row.reverse()


def rim_light(c):
    """Marginea dinspre soare. Soarele joaca din STANGA, deci un pixel opac e aprins pe stanga doar daca lumina chiar ajunge la el:
    sirul de pixeli transparenti de la stanga lui pe acelasi rand are cel putin 3 pixeli SAU ajunge la marginea celulei. Asa raman
    aprinse conturul adevarat si golurile late dintre picioare, iar mainile din fata trunchiului (1-2 pixeli de gol) nu mai
    stralucesc ca niste punctulete portocalii. Marginea de sus (pixel opac cu transparent deasupra), o nuanta mai slaba."""
    src = [row[:] for row in c.px]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3] < 200:
                continue
            n = 0
            while x - 1 - n >= 0 and src[y][x - 1 - n][3] < 40:
                n += 1
            reaches_edge = x - n == 0
            if x == 0 or n >= 3 or (n >= 1 and reaches_edge):
                c.px[y][x] = RIM
                continue
            up = src[y - 1][x] if y > 0 else T
            if up[3] < 40:
                c.px[y][x] = RIM_TOP


def over(dst, src, ox, oy):
    """Copie `src` (C) in `dst` (C) cu compunere alfa."""
    for y in range(src.h):
        for x in range(src.w):
            p = src.px[y][x]
            if p[3]:
                dst.put(ox + x, oy + y, p)


def finish(c, post, mirror):
    """Pasul final al unei celule: (oglindire) -> lumina de margine -> stratul `post` (ce se pune DUPA lumina: felinarul, funia,
    scanteile, mainile de pe funie; si el oglindit). Oglindirea vine INAINTE de lumina, ca marginea aprinsa sa ramana pe stanga
    figurii (adica pe fata unui om care merge spre stanga)."""
    if mirror:
        flip(c)
    rim_light(c)
    if mirror:
        flip(post)
    over(c, post, 0, 0)
    return c


# ---------------------------------------------------------------------------------------------------------------------------
# mersul: pozitia picioarelor si a bratelor pe cele 4 cadre (aceeasi ca walk_side: pas, trecere, pas opus, trecere)
# ---------------------------------------------------------------------------------------------------------------------------
LOW = (True, False, True, False)  # cadrele de pas: corpul mai jos (trunchiul la randul 11), la trecere mai sus (randul 10)


def walk_legs(c, f, ty, near=BODY, far=FAR):
    """Picioarele pe cadrul f (0 pas cu piciorul apropiat in fata, 1 trecere, 2 pas opus, 3 trecere opusa).
    ty = randul de sus al trunchiului; soldurile sunt la ty+6; labele pe randul 22. La trecere, piciorul care se balanseaza
    e indoit: genunchiul inainte, laba ridicata in spate (forma de "<"), iar celalalt sta drept sub trunchi."""
    hip = ty + 6
    if f == 0:
        leg(c, 5, 2, hip, 22, far)
        leg(c, 7, 10, hip, 22, near)
    elif f == 2:
        leg(c, 5, 2, hip, 22, near)
        leg(c, 7, 10, hip, 22, far)
    elif f == 1:
        bent_leg(c, 7, hip, 9, hip + 2, 3, 21, far, toe=0)
        leg(c, 6, 6, hip, 22, near)
    else:
        bent_leg(c, 7, hip, 9, hip + 2, 3, 21, near, toe=0)
        leg(c, 6, 6, hip, 22, far)


def walk_arms(f, ty):
    """Mainile (apropiata, departata) ca puncte (x, y): se balanseaza invers fata de picioarele de aceeasi parte."""
    if f == 0:
        return (3, ty + 6), (12, ty + 6)
    if f == 2:
        return (12, ty + 6), (3, ty + 6)
    if f == 1:  # fata de umar (x 7), mana apropiata: -4, -1, +5, +2 pe cele 4 cadre (balans egal, fara salt de 2 px apoi 7 px)
        return (6, ty + 7), (9, ty + 7)
    return (9, ty + 7), (6, ty + 7)


# ---------------------------------------------------------------------------------------------------------------------------
# prop_film_walkers
# ---------------------------------------------------------------------------------------------------------------------------
def glow(c, cx, cy, r1=2.5, r2=4.0, a1=90, a2=45):
    """Aura felinarului in DOUA trepte de pixeli (nu o panta cu 16 niveluri de alfa, din care jumatate sunt zgomot): alfa a1 pana la
    distanta r1, a2 pana la r2, nimic dincolo. Cu r2 = 4 si felinarul la x 10-13, discul incape intreg in celula."""
    for y in range(c.h):
        for x in range(c.w):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r1:
                c.put(x, y, GLOW + (a1,))
            elif d <= r2:
                c.put(x, y, GLOW + (a2,))


def lantern(c, x, y):
    """Felinarul (4x5, coltul stanga-sus la (x, y)): aura in doua trepte, cadru intunecat, miez cald, maner; plus balta de lumina de
    pe pamant (5 x 1 pe randul 23, 3 x 1 pe randul 22 doar unde nu e talpa), ca sa lumineze drumul. Se pune in `post`."""
    glow(c, x + 2, y + 2.5)
    c.rect(x, y, 4, 5, LAMP_FRAME)
    c.rect(x + 1, y + 1, 2, 3, LAMP_GLASS)
    c.rect(x + 1, y + 2, 2, 1, LAMP_CORE)
    c.put(x + 1, y - 1, LAMP_FRAME)
    c.put(x + 2, y - 1, LAMP_FRAME)
    c.rect(x, 23, 5, 1, GLOW + (60,))
    for xx in range(x + 1, x + 4):
        if c.px[22][xx][3] == 0:
            c.put(xx, 22, GLOW + (40,))


def walker(kind, f, mirror=False):
    """Un mergator (celula 16x24), `kind` 0..3, cadrul f 0..3. Randul = rolul (cu ce poarta) si coafura (scurt, sapca, coc, lung).
    `mirror` = fata spre stanga (celula oglindita inainte de lumina)."""
    c = C(CW, CH)
    post = C(CW, CH)
    low = LOW[f]
    ty = 11 if low else 10
    hy = ty - 9
    nh, fh = walk_arms(f, ty)
    hair = ("short", "cap", "bun", "long")[kind]
    coat = 2 if kind == 3 else 0

    # in spate: bratul departat si picioarele
    if kind in (0, 3):
        line(c, 8, ty + 1, fh[0], fh[1], FAR, 2)
    elif kind == 1:
        line(c, 8, ty + 2, 12, ty + 3, FAR, 2)  # mana departata iese in fata, sub grinda
    else:
        line(c, 8, ty + 2, 12, ty + 5, FAR, 2)  # bratul de sub piatra
    walk_legs(c, f, ty)
    torso(c, 4, ty, BODY, flare=(kind != 1), coat=coat)
    head(c, 3, hy, hair)

    if kind == 0:  # mainile goale, balansate
        line(c, 7, ty + 1, nh[0], nh[1], ARM, 2)
        c.rect(nh[0], nh[1], 2, 2, ARM)
        c.rect(fh[0], fh[1], 2, 2, FAR)
    elif kind == 1:
        # grinda pe UMAR: sta peste gat, chiar sub barbie (randul ty-1), cu capatul din fata mai jos (ty..ty+2) si cel din spate mai
        # sus (ty-2..ty); fata de sus luminata, capatul taiat din fata deschis. Bratul apropiat o tine de dedesubt (cotul in jos,
        # pumnul pe sub grinda) si se deseneaza DUPA ea, ca priza sa se vada.
        line(c, 0, ty - 2, 15, ty, WOOD, 3)
        line(c, 0, ty - 2, 15, ty, WOOD_HI, 1)
        c.rect(14, ty, 2, 3, WOOD_END)
        line(c, 6, ty + 1, 6, ty + 4, ARM, 2)  # umarul -> cotul (jos)
        line(c, 7, ty + 4, 9, ty + 3, ARM, 2)  # antebratul urca spre grinda, in forma de "7"
        c.rect(10, ty + 2, 2, 2, ARM)  # pumnul, chiar sub grinda
        c.rect(13, ty + 3, 2, 2, FAR)  # mana departata, mai in fata, tot sub grinda
    elif kind == 2:  # bratul de sus; piatra si antebratul vin in `post`
        line(c, 7, ty + 1, 8, ty + 5, ARM, 2)
    else:  # felinarul intins inainte
        line(c, 7, ty + 1, 11, ty + 2, ARM, 2)
        c.rect(fh[0], fh[1], 2, 2, FAR)

    if kind == 2:
        # blocul de piatra fatuita, 7 lat x 5 inalt, mai lat decat inalt ca asizele zidului: 2 randuri de fata de sus (clara),
        # 2 de fata din fata, 1 de rost/talpa; coltul de sus-dreapta tesit; un rost vertical. Cele doua pixeli de sus din stanga
        # prind lumina soarelui. Dedesubt, antebratul apropiat (1 rand) si mana care se curbeaza in sus pe marginea blocului.
        sy = ty + 1
        post.rect(9, sy, 7, 2, STONE_TOP)
        post.rect(9, sy + 2, 7, 2, STONE_FRONT)
        post.rect(9, sy + 4, 7, 1, STONE_LO)
        post.rect(12, sy + 2, 1, 2, STONE_LO)
        post.px[sy][15] = T  # colt tesit (put() ar iesi din functie pe alfa 0, deci se scrie direct)
        if not mirror:  # spre dreapta, capatul dinspre soare (stanga) e cel din spatele bratului: doar coltul de sus prinde lumina
            post.put(9, sy, RIM)
            post.put(10, sy, RIM_TOP)
        post.rect(7, ty + 6, 8, 1, ARM)
        post.put(15, ty + 5, ARM)
    if kind == 3:
        lantern(post, 10, ty + 4)
    c = finish(c, post, mirror)
    if kind == 2 and mirror:
        # spre stanga, capatul liber al blocului (x 0) priveste soarele: coltul de sus-stanga (tesit, deci incepe la x 1) si fata lui
        # laterala sunt aprinse; spatele blocului, lipit de trunchi (x 5-6), ramane in umbra
        sy = ty + 1
        c.px[sy][1] = RIM
        c.px[sy][2] = RIM_TOP
        for yy in range(sy + 1, sy + 4):
            c.px[yy][0] = RIM
    return c


def sheet_walkers(mirror=False):
    s = C(64, 96)
    for r in range(4):
        for f in range(4):
            over(s, walker(r, f, mirror), f * CW, r * CH)
    return s


# ---------------------------------------------------------------------------------------------------------------------------
# prop_film_workers
# ---------------------------------------------------------------------------------------------------------------------------
MALLET_HEAD = (112, 104, 116, 255)  # fier, deschis ca sa se citeasca pe scandurile podinei
MALLET_HEAD_LO = (84, 74, 92, 255)
MALLET_HANDLE = (136, 94, 68, 255)  # coada, lemn luminat de soare: se citeste pe cap si pe podina


def mallet_worker(f, mirror=False):
    """Ciocanul de piatra pe cele 4 cadre: ridica (0), varf (1), coboara (2), LOVITURA pe blocul din fata (3).
    Omul sta ghemuit pe podina (trunchiul la randul 14-15, doar 2-3 randuri de picior): asa raman 4-5 randuri libere deasupra
    capului pentru ciocanul ridicat, care nu se mai lipeste de cap ca o palarie. Trunchiul se apleaca tot mai mult spre piatra."""
    c = C(CW, CH)
    post = C(CW, CH)
    ty = (14, 14, 14, 15)[f]
    lean = (0, -1, 1, 2)[f]  # trunchiul: inapoi la varf, inainte la lovitura
    hy = ty - 9
    # picioarele ghemuite: cel departat intins in spate, cel apropiat cu genunchiul in fata si laba pe podina (lana de rand, 1 px sus)
    hip = ty + 6
    if f < 3:
        c.rect(4, hip, 5, 1, FAR)
        c.rect(2, hip + 1, 5, 1, FAR)
        c.rect(1, 22, 5, 1, FAR)
        c.rect(6, hip, 5, 1, BODY)
        c.rect(8, hip + 1, 4, 1, BODY)
        c.rect(8, 22, 5, 1, BODY)
    else:
        c.rect(3, hip, 5, 1, FAR)
        c.rect(1, 22, 5, 1, FAR)
        c.rect(6, hip, 6, 1, BODY)
        c.rect(8, 22, 5, 1, BODY)
    # blocul de pe podina, in fata (aceeasi piatra ca blocul din brate): se deseneaza in `post`, DUPA lumina de margine; in `c` ar fi
    # prins lumina doar cand are cer deasupra (cadrele 1-3) si nu cand ciocanul e pe el (cadrul 4), deci ar palpai portocaliu-gri
    post.rect(13, 19, 3, 1, STONE_TOP)
    post.rect(13, 20, 3, 2, STONE_FRONT)
    post.rect(13, 22, 3, 1, STONE_LO)
    torso(c, 4, ty, BODY, flare=True, lean=lean)
    head(c, 3 + lean, hy, "short")
    # brate si ciocan: umarul, mana (patrat 2x2), capul ciocanului (dreptunghi); coada merge de la mana la centrul capului
    sh = (8 + lean, ty + 1)
    hand = ((9, 11), (12, 9), (11, 11), (10, 14))[f]
    mal = ((12, 1, 4, 3), (10, 0, 5, 3), (13, 14, 3, 3), (12, 16, 4, 3))[f]  # (x, y, latime, inaltime) capul ciocanului
    # raise: sus-dreapta, cu 1 rand si 2 coloane libere fata de cap; apex: drept deasupra, cu un rand liber intre ciocan si
    # cap; coboara: in fata, la piept; lovitura: capul pe blocul de pe podina
    end = ((13, 3), (12, 2), (13, 14), (12, 16))[f]  # unde intra coada in capul ciocanului
    line(c, sh[0], sh[1], hand[0], hand[1], ARM, 2)
    line(c, hand[0] + 1, hand[1], end[0], end[1], MALLET_HANDLE, 1)
    c.rect(mal[0], mal[1], mal[2], mal[3], MALLET_HEAD)
    c.rect(mal[0], mal[1] + mal[3] - 1, mal[2], 1, MALLET_HEAD_LO)
    c.rect(hand[0], hand[1], 2, 2, ARM)
    if f == 3:  # scanteia: sare din piatra la lovitura, in aerul liber de deasupra si din dreapta impactului (nu pe trunchi)
        for (x, y, col) in ((13, 15, SPARK_HOT), (15, 14, SPARK), (12, 14, SPARK), (14, 13, SPARK_HOT), (15, 12, SPARK)):
            post.put(x, y, col)
        post.put(14, 19, SPARK_HOT)
    c = finish(c, post, mirror)
    # lumina soarelui pe bloc: marginea de pe partea dinspre soare, la fel pe toate cadrele (spre dreapta x 13, spre stanga x 0)
    sx = 0 if mirror else 13
    for yy in (19, 20, 21):
        c.px[yy][sx] = RIM
    return c


def rope_worker(f, mirror=False):
    """Tragerea funiei mana peste mana: trunchiul lasat pe spate, funia coboara din dreapta-sus (iese din celula la randul 0, spre un
    scripete din afara ei) prin maini si cade intr-un colac. Dungile (2 randuri inchis / 2 deschis) coboara cu 1 pixel pe cadru, spre
    maini. Funia si mainile se pun in `post` (mainile ULTIMELE, ca priza sa nu fie acoperita de funie)."""
    c = C(CW, CH)
    post = C(CW, CH)
    ty = (11, 12, 12, 11)[f]
    hy = ty - 9
    lean = -2
    leg(c, 5, 1, ty + 6, 22, FAR, w=3, toe=1)
    leg(c, 7, 7, ty + 6, 22, BODY, w=3, toe=0)  # laba scurta: colacul sta la un pixel de ea
    torso(c, 4, ty, BODY, flare=True, lean=lean)
    head(c, 3 + lean, hy, "bun", bun_dx=0.3)  # cu lean = -2, hx = 1: la -0,8 marginea celulei taia cocul la 2 px latime

    def at(t):  # t = 0 la mana de jos, 1 sus; funia merge de la (11, 15) pana la (15, 0)
        return (11 + 4 * t, 15 - 15 * t)

    ta = (0.40, 0.18, 0.06, 0.28)[f]  # mana apropiata (trage in jos)
    tb = (0.08, 0.28, 0.44, 0.20)[f]  # mana departata (apuca mai sus)
    na, nb = at(ta), at(tb)
    line(c, 7 + lean, ty + 1, nb[0], nb[1], FAR, 2)
    line(c, 8 + lean, ty + 1, na[0], na[1], ARM, 2)
    # funia: un pixel pe rand; dungile se deplaseaza cu 1 pe cadru (descresc spre maini)
    for y in range(0, 16):
        t = (15 - y) / 15.0
        x = round(at(t)[0])
        post.put(x, y, ROPE_HI if ((15 - y) + f) % 4 < 2 else ROPE)
    line(post, 11, 15, 13, 19, ROPE, 1)  # coada cade in colac
    # colacul: inel plat, la 1 px de laba (laba: x 7-9, randul 22)
    for (x, y) in ((12, 20), (13, 20), (14, 20), (11, 21), (15, 21), (12, 22), (13, 22), (14, 22)):
        post.put(x, y, ROPE_HI if y == 20 else ROPE)
    # mainile, ultimele
    post.rect(round(nb[0]), round(nb[1]), 2, 2, FAR)
    post.rect(round(na[0]), round(na[1]), 2, 2, ARM)
    return finish(c, post, mirror)


def sheet_workers(mirror=False):
    s = C(64, 48)
    for f in range(4):
        over(s, mallet_worker(f, mirror), f * CW, 0)
        over(s, rope_worker(f, mirror), f * CW, CH)
    return s


# ---------------------------------------------------------------------------------------------------------------------------
# prop_film_works_bell_swing
# ---------------------------------------------------------------------------------------------------------------------------
def load_static(name):
    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


GOLD = {(167, 132, 55, 255), (140, 103, 39, 255), (194, 162, 74, 255), (221, 193, 95, 255), (247, 226, 119, 255)}
DARK = (41, 31, 24, 255)  # tonul "0" al clopotului: contur si interior intunecat
LATTICE = (65, 76, 87, 255)  # tonul "6": zabrelele si jugul
POST_L, POST_R = (8, 12), (28, 32)  # montantii cadrului (coloane), cu conturul lor
CLIP = (10, 30)  # amprenta cadrului balansat (coloanele in care difera de sprite-ul static)
GOLD_CLIP = (11, 28)  # alama nu iese din cat arata sprite-ul static (buza lui sta pe 11-28 la randul 30)
RING_CLIP = (10, 29)  # conturul de dincolo de alama
SHEAR_K = 0.13  # cati pixeli pe rand de sub capul jugului (randul 12): ~3 px la buza clopotului
TILT_K = 0.14  # sinusul unghiului (~8 grade): cu cat urca partea din fata a buzei fata de axa clopotului, pe pixel de distanta
AXIS_X = 19.5  # axa clopotului (buza sta pe 11-28)
PIVOT_ROW = 12
CLAPPER_ROW = 33  # de aici in jos e batalul (b b b, randurile 33-35)
DASH_ROWS = (21, 24, 27)  # randurile dungilor de miscare (cate 2 pixeli, pe partea din urma a clopotului)
LINE_CREAM = (250, 246, 230, 255)
LINE_SAND = (212, 195, 163, 255)


def shear(row, side):
    """Cu cate coloane e mutat randul `row` al clopotului cand balansul e `side` (-1 stanga, 0 centru, 1 dreapta)."""
    return side * int(round(SHEAR_K * (row - PIVOT_ROW)))


def tilt(x, side):
    """Cu cate randuri e mutata coloana `x` a clopotului: partea din FATA a balansului urca, cea din URMA coboara (rotatie in jurul
    capului jugului: x' = x cos - y sin, y' = x sin + y cos). Cu ~8 grade, cel mult 1 rand la capetele buzei."""
    return int(math.floor(-side * TILT_K * (x - AXIS_X) + 0.5))


def bell_layers(im):
    """Imparte clopotul din imaginea statica in straturi: corpul (alama + conturul lui), jugul (tija de zabrele care il tine)
    si batalul. Intoarce seturi de (x, y)."""
    get = lambda x, y: tuple(im.getpixel((x, y))) if 0 <= x < im.width and 0 <= y < im.height else T
    gold = {(x, y) for y in range(17, 36) for x in range(POST_L[0], POST_R[1] + 1) if get(x, y) in GOLD}
    clap = {p for p in gold if p[1] >= CLAPPER_ROW}
    body = gold - clap

    def ring(of, exclude):
        out = set()
        for (x, y) in of:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q not in of and q not in exclude and get(*q) == DARK:
                        out.add(q)
        return out

    body_ring = ring(body, clap)
    clap_ring = ring(clap, body | body_ring) - body_ring
    yoke = {(x, y) for y in (14, 15, 16) for x in (19, 20, 21) if get(x, y) == LATTICE}
    return body | body_ring, clap | clap_ring, yoke, body, clap


def outline(gold, skip=()):
    """Conturul (8 vecini) unui set de pixeli de alama, doar in RING_CLIP; pixelii din `skip` si cei de alama raman neatinsi."""
    out = set()
    for (x, y) in gold:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (x + dx, y + dy)
                if q not in gold and q not in skip and RING_CLIP[0] <= q[0] <= RING_CLIP[1]:
                    out.add(q)
    return out


def backdrop(im, bell, x, y, in_post):
    """Ce se vede in locul (x, y) dupa ce clopotul a plecat de acolo: zabrelele cadrului si semnele de pe montanti, nu un pal de
    intuneric. Tot ce e in afara clopotului se repeta din 8 in 8 randuri (verificat pe fiecare coloana 8-32), iar zabrelele dintre
    montanti sunt si simetrice fata de coloana 20 (x <-> 40 - x, verificat pe fiecare pixel vizibil). Deci pixelul vine din aceeasi
    coloana cu 8 sau 16 randuri mai jos / mai sus (pentru zabrele si oglindit), cu conditia sa fie opac si sa nu fie el insusi clopot.
    Daca nu se gaseste nimic (centrul clopotului, unde si cel de sus, si cel de jos sunt clopot), ramane intunericul din interiorul
    cadrului (zabrelele) sau montantul ca pe randul 25 (montantii)."""
    if in_post:
        cands = ((x, y + 8), (x, y - 8), (x, y + 16), (x, y - 16))
    else:
        cands = ((x, y + 8), (x, y - 8), (40 - x, y), (40 - x, y + 8), (40 - x, y - 8), (x, y + 16), (x, y - 16))
    for qx, qy in cands:
        if 14 <= qy <= 44 and (in_post or 13 <= qx <= 27) and (qx, qy) not in bell and im.getpixel((qx, qy))[3] == 255:
            return tuple(im.getpixel((qx, qy)))
    return tuple(im.getpixel((x, 25))) if in_post else DARK


def bell_frame(side, im=None):
    """Un cadru de 40x56 (C): copia exacta a lui prop_works_bell, cu clopotul inclinat. side: -1 stanga, 0 centru, 1 dreapta."""
    im = im or load_static("prop_works_bell")
    c = C(im.width, im.height)
    for y in range(im.height):
        for x in range(im.width):
            c.px[y][x] = tuple(im.getpixel((x, y)))
    if side == 0:
        return c  # centrul e sprite-ul static, pixel cu pixel
    col = lambda p: tuple(im.getpixel(p))
    body_all, clap_all, yoke, body_gold, clap_gold = bell_layers(im)
    # 1. fundalul: locul clopotului, jugului si batalului se reface (montantii ca pe randul 25, in rest zabrelele repetate din 8 in 8
    # randuri: clopotul se balanseaza IN FATA zabrelelor si nu lasa in urma o pata intunecata)
    static_bell = body_all | clap_all | yoke
    for (x, y) in static_bell:
        in_post = POST_L[0] <= x <= POST_L[1] or POST_R[0] <= x <= POST_R[1]
        c.px[y][x] = backdrop(im, static_bell, x, y, in_post)
    # 2. alama mutata: fiecare rand cu forfecarea lui, apoi fiecare coloana cu inclinarea ei; clopotul nu iese din alama statica
    body_new = {}
    for (x, y) in body_gold:
        x1 = x + shear(y, side)
        body_new[(x1, y + tilt(x1, side))] = col((x, y))
    body_new = {p: v for p, v in body_new.items() if GOLD_CLIP[0] <= p[0] <= GOLD_CLIP[1]}
    clap_dx = int(round(0.35 * shear(CLAPPER_ROW, side)))  # batalul se misca mai putin si in urma clopotului
    clap_new = {(x + clap_dx, y): col((x, y)) for (x, y) in clap_gold}
    clap_new = {p: v for p, v in clap_new.items() if p not in body_new and GOLD_CLIP[0] <= p[0] <= GOLD_CLIP[1]}

    def put(p, v):
        if CLIP[0] <= p[0] <= CLIP[1]:
            c.put(p[0], p[1], v)

    for p in sorted(outline(clap_new, skip=set(body_new))):
        put(p, DARK)
    for p, v in sorted(clap_new.items()):
        put(p, v)
    for (x, y) in sorted(yoke):
        put((x + shear(y, side), y), col((x, y)))
    # conturul corpului: peste zabrele si montanti, dar nu peste jug / zabrelele de sus, ca alama sa se leaga de jug ca in sprite-ul static
    for p in sorted(outline(body_new)):
        if c.px[p[1]][p[0]] == LATTICE and p[1] <= 16:
            continue
        put(p, DARK)
    for p, v in sorted(body_new.items()):
        put(p, v)
    # 3. liniile de miscare, pe cadrele extreme: pe partea din urma a clopotului, in golul lasat de el. Trei dungi de EXACT 2 pixeli
    # (crem, apoi nisip), pe randurile 21, 24 si 27: aceste randuri au loc pentru 2 pixeli si cand clopotul se balanseaza la stanga, si
    # cand se balanseaza la dreapta (randurile 29-31 nu aveau, iar dungile taiate de fereastra lasau puncte singure). Asa cele doua
    # cadre extreme au acelasi numar de dungi, oglindite. Nu se pun peste alama; raman in interiorul cadrului (coloanele 13-27).
    way = 1 if side < 0 else -1  # spre partea din urma
    for row in DASH_ROWS:
        xs = [x for (x, y) in body_new if y == row]
        edge = max(xs) if side < 0 else min(xs)
        for i in range(2):
            x = edge + way * (2 + i)
            assert 13 <= x <= 27 and c.px[row][x] not in GOLD, ("dunga nu are loc", side, row, x)
            c.put(x, row, LINE_CREAM if i == 0 else LINE_SAND)
    return c


def bell_frames():
    """Trei cadre de 40x56: stanga, centru, dreapta."""
    im = load_static("prop_works_bell")
    return [bell_frame(s, im) for s in (-1, 0, 1)]


def sheet_bell():
    s = C(120, 56)
    for i, fr in enumerate(bell_frames()):
        over(s, fr, i * 40, 0)
    return s


def check_bell():
    """Verificarea cerutei: centrul e identic cu sprite-ul static; in celelalte, diferentele stau doar in amprenta clopotului; alama
    ramane in GOLD_CLIP; fiecare rand de alama de pe marginea din fata are conturul intunecat chiar langa ea."""
    im = load_static("prop_works_bell")
    frames = bell_frames()
    body_all, clap_all, yoke, _, _ = bell_layers(im)
    for name, fr, side in zip(("stanga", "centru", "dreapta"), frames, (-1, 0, 1)):
        diff = [(x, y) for y in range(56) for x in range(40) if tuple(im.getpixel((x, y))) != tuple(fr.px[y][x])]
        if name == "centru":
            assert not diff, ("centrul difera de sprite-ul static", diff[:5])
        else:
            xs, ys = [p[0] for p in diff], [p[1] for p in diff]
            assert min(xs) >= CLIP[0] and max(xs) <= CLIP[1] and min(ys) >= 13 and max(ys) <= 37, (name, min(xs), max(xs), min(ys), max(ys))
            # dungile de miscare: exact 2 pixeli pe fiecare rand din DASH_ROWS, la fel pe STANGA si pe DREAPTA (nu apar in sprite-ul static)
            dash = [(x, y) for y in range(56) for x in range(40)
                    if tuple(fr.px[y][x]) in (LINE_CREAM, LINE_SAND) and tuple(im.getpixel((x, y))) != tuple(fr.px[y][x])]
            assert sorted(y for _, y in dash) == sorted(r for r in DASH_ROWS for _ in range(2)), (name, "dungile", dash)
            print("clopot", name, "dungi de miscare:", len(dash), "pixeli pe randurile", sorted(set(y for _, y in dash)))
            # alama doar in GOLD_CLIP, in tot cadrul
            for y in range(56):
                for x in range(40):
                    if tuple(fr.px[y][x]) in GOLD:
                        assert GOLD_CLIP[0] <= x <= GOLD_CLIP[1], (name, "alama in afara", x, y)
            # marginea din fata: unde alama atinge coloana de margine, vecinul de afara e contur intunecat continuu
            edge_x, out_x = (GOLD_CLIP[0], GOLD_CLIP[0] - 1) if side < 0 else (GOLD_CLIP[1], GOLD_CLIP[1] + 1)
            for y in range(56):
                if tuple(fr.px[y][edge_x]) in GOLD:
                    assert tuple(fr.px[y][out_x]) == DARK, (name, "fara contur intunecat langa alama", out_x, y)
        print("clopot", name, "pixeli diferiti:", len(diff))
        # clopotul static trebuie sa fie acoperit opac in fiecare cadru
        for (x, y) in body_all | clap_all:
            assert fr.px[y][x][3] == 255, (name, x, y)


def check_people():
    """Verificari pe foile de oameni: fara negru pur; alfa binara cu exceptia luminii felinarului (aura 90/45, balta 60/40); talpile pe
    randul 22 al fiecarei celule si nimic opac pe randul 23; foile _l sunt oglinda EXACTA (masca de alfa) a celor spre dreapta."""
    allowed_alpha = {0, 255, 90, 45, 60, 40}
    for tag, fn in (("walkers", sheet_walkers), ("workers", sheet_workers)):
        r, l = fn(False), fn(True)
        for y in range(r.h):
            for x in range(r.w):
                p = r.px[y][x]
                assert p[3] in allowed_alpha, (tag, x, y, p)
                assert p[3] != 255 or max(p[:3]) >= 20, (tag, "negru pur", x, y, p)
        for cy in range(r.h // CH):
            for cx in range(r.w // CW):
                x0, y0 = cx * CW, cy * CH
                assert any(r.px[y0 + 22][x0 + x][3] == 255 for x in range(CW)), (tag, "fara talpa pe randul 22", cx, cy)
                assert all(r.px[y0 + 23][x0 + x][3] != 255 for x in range(CW)), (tag, "opac pe randul 23", cx, cy)
                for y in range(CH):
                    for x in range(CW):
                        a, b = r.px[y0 + y][x0 + x], l.px[y0 + y][x0 + CW - 1 - x]
                        assert a[3] == b[3], (tag, "foaia _l nu e oglinda", cx, cy, x, y)
        # lumina de margine e pe partea soarelui (STANGA) in ambele foi: niciun pixel aprins nu are in celula un vecin opac in stanga
        # si gol in dreapta (adica o margine aprinsa pe ceafa) si, in foaia _l, marginea e desenata nativ pe stanga figurii oglindite
        lit = {}
        for nume, foaie in (("dreapta", r), ("stanga", l)):
            n_lit = n_open = 0
            for cy in range(foaie.h // CH):
                for cx in range(foaie.w // CW):
                    for y in range(CH):
                        for x in range(CW):
                            if foaie.px[cy * CH + y][cx * CW + x] != RIM:
                                continue
                            left = foaie.px[cy * CH + y][cx * CW + x - 1] if x > 0 else T
                            right = foaie.px[cy * CH + y][cx * CW + x + 1] if x < CW - 1 else T
                            assert not (left[3] == 255 and right[3] < 255), (tag, nume, "margine aprinsa pe partea gresita", cx, cy, x, y)
                            n_lit += 1
                            n_open += left[3] < 255
            lit[nume] = (n_lit, n_open)
        print("oameni", tag, "lumina de margine (aprinsi / cu cer in stanga): dreapta", lit["dreapta"], "stanga", lit["stanga"])
        n = sum(1 for row in r.px for p in row if p[3] == 255)
        print("oameni", tag, "pixeli opaci:", n, "- fara negru pur, alfa in", sorted(allowed_alpha), "OK")


SPRITES = {
    "prop_film_walkers": lambda: sheet_walkers(False),
    "prop_film_walkers_l": lambda: sheet_walkers(True),
    "prop_film_workers": lambda: sheet_workers(False),
    "prop_film_workers_l": lambda: sheet_workers(True),
    "prop_film_works_bell_swing": sheet_bell,
}
SIZES = {
    "prop_film_walkers": (64, 96),
    "prop_film_walkers_l": (64, 96),
    "prop_film_workers": (64, 48),
    "prop_film_workers_l": (64, 48),
    "prop_film_works_bell_swing": (120, 56),
}


# ---------------------------------------------------------------------------------------------------------------------------
# previzualizarea
# ---------------------------------------------------------------------------------------------------------------------------
DUSK = (70, 34, 52)  # amurgul filmului (DamFilm): un strat plat la 45%
DUSK_A = 0.45
W1_SCALE = 3  # pixeli de lume pe pixel de arta
PEOPLE_SCALE = 2.5  # oamenii se deseneaza la x2,5 (16x24 -> 40x60 pixeli de lume)


def to_image(c):
    im = Image.new("RGBA", (c.w, c.h), (0, 0, 0, 0))
    px = im.load()
    for y in range(c.h):
        for x in range(c.w):
            px[x, y] = tuple(c.px[y][x])
    return im


def tint(img, alpha=DUSK_A):
    over_ = Image.new("RGBA", img.size, DUSK + (round(alpha * 255),))
    return Image.alpha_composite(img, over_)


def ground_crop(ax0, ay0, aw, ah):
    """O felie din pamantul copt al lumii 1 (prop_village_ground.png), la scara lumii (x3)."""
    g = Image.open(os.path.join(SPR, "prop_village_ground.png")).convert("RGBA")
    base = Image.new("RGBA", g.size, (88, 118, 64, 255))  # sub apa transparenta
    base.alpha_composite(g)
    return base.crop((ax0, ay0, ax0 + aw, ay0 + ah)).resize((aw * W1_SCALE, ah * W1_SCALE), Image.NEAREST)


def figure(sheet, row, frame):
    cell = sheet.crop((frame * CW, row * CH, frame * CW + CW, row * CH + CH))
    return cell.resize((round(CW * PEOPLE_SCALE), round(CH * PEOPLE_SCALE)), Image.NEAREST)


def stamp(img, fig, x, feet_y):
    """Pune figura cu talpile pe y (lume); randul 22 al celulei e solul."""
    img.alpha_composite(fig, (round(x - fig.width / 2), round(feet_y - 23 * PEOPLE_SCALE)))


def label(dr, xy, text, size=8, fill=(236, 230, 214, 255)):
    dr.text(xy, text, font=ImageFont.truetype(FONT, size), fill=fill)


class Sheets:
    """Cele patru foi de oameni ca imagini PIL, alese dupa sens (ca jocul: foaia _l cu ImageRectSize pozitiv)."""

    def __init__(self):
        self.w = {"right": to_image(sheet_walkers(False)), "left": to_image(sheet_walkers(True))}
        self.k = {"right": to_image(sheet_workers(False)), "left": to_image(sheet_workers(True))}

    def walker(self, row, frame, facing):
        return figure(self.w[facing], row, frame)

    def worker(self, row, frame, facing):
        return figure(self.k[facing], row, frame)


def crowd_panel(sh):
    """Siluetele pe strada de la Landing (lume x 480-1050, y 1215-1455) mergand in AMBELE sensuri (jumatate spre stanga, cu foaia _l),
    plus cativa muncitori: fara amurg, cu amurg doar pe pamant (siluetele deasupra: cum ar arata daca jocul le-ar desena peste
    amurg) si cu amurg peste tot (cum face DamFilm acum: stratul Dusk e deasupra Plot-ului)."""
    ax0, ay0, aw, ah = 160, 405, 190, 80
    ground = ground_crop(ax0, ay0, aw, ah)
    rng = random.Random(11)
    placed = []
    for i in range(16):
        kind = (0, 0, 1, 2, 3, 0, 2, 1, 0, 3, 0, 1, 2, 0, 3, 1)[i]
        facing = "left" if i % 2 == 0 else "right"
        placed.append((kind, i % 4, 40 + i * 33 + rng.randint(-8, 8), 85 + rng.randint(0, 120) * 0.9, facing))
    placed.sort(key=lambda p: p[3])
    figs = []
    for kind, f, x, y, facing in placed:
        figs.append((sh.walker(kind, f, facing), x, y))
    # si cativa muncitori (2 cu ciocanul, 2 cu funia), unii spre dreapta, altii spre stanga, in capatul strazii
    for row, f, x, y, facing in ((0, 3, 150, 232, "right"), (1, 1, 205, 232, "left"), (0, 0, 262, 232, "left"), (1, 2, 320, 232, "right")):
        figs.append((sh.worker(row, f, facing), x, y))
    figs.sort(key=lambda t: t[2])  # cei mai din spate intai
    out = []
    for mode in ("plain", "dusk_ground", "dusk_all"):
        img = tint(ground) if mode == "dusk_ground" else ground.copy()
        for fig, x, y in figs:
            stamp(img, fig, x, y)
        if mode == "dusk_all":
            img = tint(img)
        out.append((mode, img))
    return out


def film_panel(sh):
    """Ce face DamFilm EXACT: cei 14 de mergatori ai lui DamFilmSet.walkers() (jumatate vin din stanga spre dreapta, jumatate din
    dreapta spre stanga, `kind` = (i-1) % 4, tinta pe malul de sud, lume x 520-1000, y 806-842), la scara lumii 1:1, cu stratul
    Dusk (70,34,52) la 45% DEASUPRA a tot ce e pe Plot, siluetele inclusiv. Aici se judeca daca se citesc in joc."""
    ax0, ay0, aw, ah = 160, 245, 190, 62  # lume x 480-1050, y 735-921: malul de sud, la linia zidului
    ground = ground_crop(ax0, ay0, aw, ah)
    figs = []
    for i in range(1, 15):
        left_group = i % 2 == 1
        k = (i - 1) // 2
        to_x = 520 + k * 34 if left_group else 1000 - k * 30
        to_y = 806 + (k % 3) * 18
        facing = "right" if left_group else "left"
        back = 0 if i % 3 == 0 else 60 + (i * 37) % 120  # unii au ajuns, altii mai sunt in drum
        x = to_x - back if left_group else to_x + back
        y = to_y + back * 0.16
        figs.append((sh.walker((i - 1) % 4, (i + back // 10) % 4, facing), x - ax0 * W1_SCALE, y - ay0 * W1_SCALE))
    figs.sort(key=lambda t: t[2])
    img = ground.copy()
    for fig, x, y in figs:
        stamp(img, fig, x, y)
    return tint(img)


def deck_panel(sh):
    """Podina schelei (scanduri) cu muncitorii pe ea, la x2,5, fara si cu amurg peste podina; cei de pe a doua jumatate a zidului
    (kind 1 si 3 in DamFilmSet.workers) privesc spre stanga si folosesc foaia _l."""
    aw, ah = 190, 40
    deck = C(aw, ah)
    plank = [(104, 70, 44, 255), (122, 84, 52, 255), (88, 58, 38, 255)]
    for y in range(ah):
        deck.rect(0, y, aw, 1, plank[(y // 5) % 2])
        if y % 5 == 4:
            deck.rect(0, y, aw, 1, plank[2])
    for x in range(7, aw, 23):
        for y in range(0, ah, 5):
            deck.rect(x + (y // 5) * 7 % 23, y, 1, 4, plank[2])
    ground = to_image(deck).resize((aw * W1_SCALE, ah * W1_SCALE), Image.NEAREST)
    pos = [(60, 0, 0, "right"), (150, 0, 1, "left"), (250, 0, 2, "right"), (340, 0, 3, "left"),
           (110, 1, 0, "right"), (200, 1, 1, "left"), (300, 1, 2, "right"), (400, 1, 3, "left")]
    out = []
    for mode in ("plain", "dusk"):
        img = tint(ground) if mode == "dusk" else ground.copy()
        for x, row, f, facing in pos:
            stamp(img, sh.worker(row, f, facing), x + 40, 100)
        out.append((mode, img))
    return out


def bell_panel(frames):
    """Clopotul static si cele trei cadre, pe pamant de seara, x4."""
    static = load_static("prop_works_bell")
    w = 40 * 4
    img = Image.new("RGBA", (w * 4 + 5 * 12, 56 * 4 + 24), (80, 94, 66, 255))
    dr = ImageDraw.Draw(img)
    items = [("STATIC", static)] + [(n, to_image(fr)) for n, fr in zip(("LEFT", "CENTRE", "RIGHT"), frames)]
    for i, (name, im) in enumerate(items):
        x = 12 + i * (w + 12)
        img.alpha_composite(im.resize((w, 56 * 4), Image.NEAREST), (x, 20))
        label(dr, (x, 6), name)
    return img


def bell_zoom(frames):
    """Doar clopotul, x10, ca sa se vada buza si conturul de pe margine."""
    static = load_static("prop_works_bell")
    items = [("STATIC", static)] + [(n, to_image(fr)) for n, fr in zip(("LEFT", "CENTRE", "RIGHT"), frames)]
    sc = 10
    box = (6, 12, 34, 40)  # coloanele 6-33, randurile 12-39
    cw, ch = (box[2] - box[0]) * sc, (box[3] - box[1]) * sc
    img = Image.new("RGBA", (4 * (cw + 12) + 12, ch + 30), (22, 24, 30, 255))
    dr = ImageDraw.Draw(img)
    for i, (name, im) in enumerate(items):
        bg = Image.new("RGBA", im.size, (80, 94, 66, 255))
        bg.alpha_composite(im)
        x = 12 + i * (cw + 12)
        img.paste(bg.crop(box).resize((cw, ch), Image.NEAREST), (x, 22))
        label(dr, (x, 6), name)
    return img


def build_preview(out, sh, frames):
    sc = 4
    pad = 16
    sections = []

    # 1. foile (x4, cu etichete), pe pamant de seara si pe amurg
    def sheet_on(sheet, bgcol, rows):
        """Foaia x4 pe fundal, cu grila celulelor 16x24, numarul cadrului deasupra si numele randului la stanga."""
        lm, tm = 112, 16
        im = Image.new("RGBA", (lm + sheet.width * sc, tm + sheet.height * sc), (22, 24, 30, 255))
        im.paste(bgcol, (lm, tm, lm + sheet.width * sc, tm + sheet.height * sc))
        im.alpha_composite(sheet.resize((sheet.width * sc, sheet.height * sc), Image.NEAREST), (lm, tm))
        dr = ImageDraw.Draw(im)
        for x in range(0, sheet.width + 1, CW):
            dr.line([(lm + x * sc, tm), (lm + x * sc, tm + sheet.height * sc)], fill=(255, 255, 255, 28))
        for y in range(0, sheet.height + 1, CH):
            dr.line([(lm, tm + y * sc), (lm + sheet.width * sc, tm + y * sc)], fill=(255, 255, 255, 28))
        for f in range(sheet.width // CW):
            label(dr, (lm + f * CW * sc + 4, 4), "F%d" % (f + 1), 8)
        for r, name in enumerate(rows):
            label(dr, (6, tm + r * CH * sc + 6), name, 8)
        return im

    dusk_bg = (86, 98, 70, 255)
    light_bg = (150, 170, 120, 255)
    wrows = ["0 EMPTY", "1 BEAM", "2 STONE", "3 LANTERN"]
    krows = ["0 MALLET", "1 ROPE"]
    for facing, tag in (("right", ""), ("left", "_l")):
        wsheet, ksheet = sh.w[facing], sh.k[facing]
        top = Image.new("RGBA", (1700, 560), (22, 24, 30, 255))
        dr = ImageDraw.Draw(top)
        label(dr, (pad, 10), "prop_film_walkers%s 64x96 x4: dusk ground (left), plain ground (right)" % tag, 8)
        a = sheet_on(wsheet, dusk_bg, wrows)
        b = sheet_on(wsheet, light_bg, wrows)
        top.alpha_composite(a, (pad, 30))
        top.alpha_composite(b, (pad + a.width + 24, 30))
        x2 = pad + 2 * (a.width + 24)
        label(dr, (x2, 10), "prop_film_workers%s 64x48 (dusk / plain)" % tag, 8)
        c = sheet_on(ksheet, dusk_bg, krows)
        d = sheet_on(ksheet, light_bg, krows)
        top.alpha_composite(c, (x2, 30))
        top.alpha_composite(d, (x2, 30 + c.height + 16))
        sections.append(top)

    # 2. clopotul
    bp = bell_panel(frames)
    belt = Image.new("RGBA", (max(1700, bp.width), bp.height + 32), (22, 24, 30, 255))
    dr = ImageDraw.Draw(belt)
    label(dr, (pad, 10), "prop_film_works_bell_swing 120x56: static si cadrele STANGA / CENTRU / DREAPTA (x4)", 8)
    belt.alpha_composite(bp, (0, 28))
    sections.append(belt)
    bz = bell_zoom(frames)
    bzt = Image.new("RGBA", (bz.width, bz.height + 22), (22, 24, 30, 255))
    label(ImageDraw.Draw(bzt), (pad, 8), "clopotul x10: inclinarea buzei si conturul intunecat de pe marginea din fata", 8)
    bzt.alpha_composite(bz, (0, 22))
    sections.append(bzt)

    # 3. in context (la scara lumii): strada de la Landing, mers in ambele sensuri
    names = {
        "plain": "in context, scara jocului (x2,5): fara amurg, mers in ambele sensuri (foile _l pentru cei spre stanga)",
        "dusk_ground": "amurg (70,34,52) la 45% doar peste pamant, siluetele deasupra (tinta, daca jocul pune Dusk SUB figuri)",
        "dusk_all": "amurg peste tot, inclusiv peste siluete (cum face DamFilm acum, cu Dusk deasupra Plot-ului)",
    }
    for mode, img in crowd_panel(sh):
        t = Image.new("RGBA", (img.width + 2 * pad, img.height + 34), (22, 24, 30, 255))
        label(ImageDraw.Draw(t), (pad, 10), names[mode], 8)
        t.alpha_composite(img, (pad, 28))
        sections.append(t)
    fp = film_panel(sh)
    t = Image.new("RGBA", (fp.width + 2 * pad, fp.height + 34), (22, 24, 30, 255))
    label(ImageDraw.Draw(t), (pad, 10), "DamFilm EXACT: cei 14 mergatori ai lui DamFilmSet.walkers() pe malul de sud, lume 1:1, Dusk 45% deasupra a tot", 8)
    t.alpha_composite(fp, (pad, 28))
    sections.append(t)
    for mode, img in deck_panel(sh):
        t = Image.new("RGBA", (img.width + 2 * pad, img.height + 34), (22, 24, 30, 255))
        label(ImageDraw.Draw(t), (pad, 10), "muncitorii pe podina schelei, scara jocului (x2,5): " + ("fara amurg" if mode == "plain" else "cu amurg"), 8)
        t.alpha_composite(img, (pad, 28))
        sections.append(t)

    W = max(s.width for s in sections)
    H = sum(s.height for s in sections)
    full = Image.new("RGBA", (W, H), (22, 24, 30, 255))
    y = 0
    for s in sections:
        full.alpha_composite(s, (0, y))
        y += s.height
    full.save(os.path.join(out, "a2_people_preview.png"))
    print("scris", os.path.join(out, "a2_people_preview.png"), full.size)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=SCRATCH)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for name, fn in SPRITES.items():
        c = fn()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(a.out, name + ".png"), c.w, c.h, c.px)
        print("scris", name, c.w, c.h)
    check_people()
    check_bell()
    os.makedirs(SCRATCH, exist_ok=True)
    build_preview(SCRATCH, Sheets(), bell_frames())  # previzualizarea de 1700 x 3000+ nu ajunge niciodata in --out (poate fi assets/sprites)


if __name__ == "__main__":
    main()
