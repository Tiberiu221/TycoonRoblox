#!/usr/bin/env python3
"""Arta pentru D60: balciul de seara, hub-ul rotund la care ajungi cu barca in amonte.

Owner-ul (2026-09-16): "un hub circular in care ai in fiecare margine cate ceva de vazut/facut, harta mult mai mare",
"balci de seara cu lumini si scena", "scena mai mare sa incapa cat mai multe stats pentru etalare". Macheta aprobata
dupa trei runde (plan, aproape, piese), cu verificarea de asezare: 41 de obiecte, zero suprapuneri.

  * prop_fair_stage (200x112) -- scena care e si tabela balciului: trei panouri de clasament in rame, trepte,
    turnuri de lumina, banner cu feston
  * prop_fair_wheel (70x86) -- roata zilnica, mutata din sat in balci: obada din segmente, spite, baldachin
  * prop_fair_stall_1/2/3 (52x44) -- tarabele negustorului, in trei culori de copertina, cu marfa pe tejghea
  * prop_fair_shop (52x44) -- [D61, partea 2] taraba `Shop`, cu copertina aurie: monede, ghete, felinar
  * prop_fair_tent (60x54) -- cortul croitoresei, cu funii, tarusi si manechin
  * prop_fair_booth (46x40) -- ghereta de joc, cu panoul de tinte
  * prop_fair_arch (76x58) -- poarta satelor, cu felinare si tablita
  * prop_fair_dock (40x64) / prop_fair_ferry (62x30) -- debarcaderul si barca drumului in amonte
  * prop_fair_bonfire (40x34) / prop_fair_brazier (22x32) -- focul din mijloc si focurile mici de langa roata
  * prop_fair_table (40x22) / prop_fair_bench (26x14) -- mesele si bancile unde sta lumea
  * prop_fair_lamppost (16x48) -- felinarele inelului, care tin ghirlandele de becuri
  * prop_fair_plinth (28x42) -- soclul campionului saptamanii
  * prop_fair_flag (18x54) -- steagurile de langa scena
  * prop_fair_trophy (24x34) -- trofeul unei specii, in fata scenei
  * prop_fair_crate (20x18) / prop_fair_barrel (18x24) / prop_fair_reeds (18x26) -- recuzita si stuful iazului
  * prop_fair_miniature (32x26) -- satul altcuiva, in miniatura, pe panoul de la poarta
  * tile_fair (64x64) -- pamantul batatorit al balciului, cu paie si pietricele

Aceleasi reguli ca restul conductei: compunere alfa "over", conturul trasat prin vecinatate (outline_trace), muchia
de sus mai deschisa (rim), culorile din palette.ramp. Lumina calda o pune jocul, nu desenul.

Rulare: python3 scripts/art/d60.py [--force]
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, T, png  # noqa: E402
from palette import hsv, mix, ramp  # noqa: E402
from tycoon_e1 import outline_trace  # noqa: E402

import scratch  # noqa: E402  (scripts/art/scratch.py: radacina repo-ului, fara cai de pe Mac)
OUT_DIR = scratch.SPRITES  # `OUT` e culoarea conturului, mai jos

WOOD = ramp(hue=26, sat=0.52, val=0.46, val_span=0.42)
WOOD_D = ramp(hue=22, sat=0.50, val=0.30, val_span=0.32)
CLOTH_RED = ramp(hue=6, sat=0.58, val=0.62, val_span=0.36)
CLOTH_BLUE = ramp(hue=206, sat=0.50, val=0.58, val_span=0.36)
CLOTH_GREEN = ramp(hue=138, sat=0.44, val=0.52, val_span=0.36)
CLOTH_GOLD = ramp(hue=44, sat=0.66, val=0.78, val_span=0.34)  # [D61, partea 2] copertina tarabei `Shop`
LEATHER = ramp(hue=18, sat=0.50, val=0.40, val_span=0.34)
CREAM = ramp(hue=40, sat=0.22, val=0.90, val_span=0.22)
STONE = ramp(hue=214, sat=0.12, val=0.50, val_span=0.36)
SANDSTONE = ramp(hue=38, sat=0.26, val=0.62, val_span=0.34)  # soclurile si trofeele, ca sa prinda lumina calda
IRON = ramp(hue=210, sat=0.10, val=0.38, val_span=0.32)
FISH = ramp(hue=196, sat=0.34, val=0.66, val_span=0.34)
OUT = hsv(24, 0.45, 0.14)
GLASS = hsv(44, 0.70, 0.98)
GLASS_D = hsv(38, 0.72, 0.72)
FLAME = [hsv(46, 0.70, 1.0), hsv(36, 0.86, 0.98), hsv(22, 0.92, 0.88), hsv(12, 0.86, 0.66)]


# ---- unelte de desen ---------------------------------------------------------------------------
def rim(c: C, amount=0.30):
    """Muchia de sus a fiecarei forme, mai deschisa: fara ea, totul pare taiat din carton."""
    for y in range(1, c.h):
        for x in range(c.w):
            p = c.px[y][x]
            if p[3] == 0 or p == OUT:
                continue
            above = c.px[y - 1][x]
            if above[3] == 0 or above == OUT:
                c.px[y][x] = mix(p, (255, 244, 220), amount)


def planks_h(c, x, y, w, h, pal, step=4, seed=1, nails=True):
    """Scanduri orizontale: fiecare cu tonul ei, o custura inchisa dedesubt si cuie la capete."""
    r = Rng(seed)
    i = 0
    while i < h:
        th = min(step, h - i)
        tone = pal[1 + r.i(0, 2)]
        c.rect(x, y + i, w, th, tone)
        c.rect(x, y + i + th - 1, w, 1, mix(tone, OUT, 0.45))
        for k in range(r.i(0, 2)):  # noduri
            c.rect(x + 2 + r.i(0, max(1, w - 5)), y + i + 1, 1, 1, mix(tone, OUT, 0.55))
        if nails and th > 2:
            c.put(x + 1, y + i + 1, mix(tone, (255, 240, 210), 0.5))
            c.put(x + w - 2, y + i + 1, mix(tone, (255, 240, 210), 0.5))
        i += step


def planks_v(c, x, y, w, h, pal, step=4, seed=1):
    r = Rng(seed)
    i = 0
    while i < w:
        tw = min(step, w - i)
        tone = pal[1 + r.i(0, 2)]
        c.rect(x + i, y, tw, h, tone)
        c.rect(x + i + tw - 1, y, 1, h, mix(tone, OUT, 0.45))
        i += step


def logs_h(c, x, y, w, h, pal, step=5, seed=3):
    """Perete de barne, ca la colibele jocului: barna cu capat rotund si umbra sub ea."""
    r = Rng(seed)
    i = 0
    while i < h:
        th = min(step, h - i)
        tone = pal[2 + r.i(0, 1)]
        c.rect(x, y + i, w, th, tone)
        c.rect(x, y + i + th - 1, w, 1, mix(tone, OUT, 0.42))
        c.rect(x, y + i, 2, th - 1, mix(tone, OUT, 0.22))
        c.rect(x + w - 2, y + i, 2, th - 1, mix(tone, OUT, 0.22))
        i += step


def shingles(c, x, y, w, h, pal, step=3):
    for i in range(0, h, step):
        tone = pal[3 - (i // step) % 2]
        c.rect(x, y + i, w, min(step, h - i), tone)
        for k in range(x, x + w, 4):
            c.rect(k + (i // step % 2) * 2, y + i, 1, min(step, h - i), mix(tone, OUT, 0.35))
        c.rect(x, y + i + min(step, h - i) - 1, w, 1, mix(tone, OUT, 0.30))


def cloth(c, x, y, w, h, pal, fold=6, seed=5):
    """Panza cu falduri: trei tonuri alternate, cu o dunga mai inchisa la fiecare fald."""
    r = Rng(seed)
    for i in range(w):
        f = (i // fold) % 2
        tone = pal[2 + f]
        c.rect(x + i, y, 1, h, tone)
        if i % fold == 0:
            c.rect(x + i, y, 1, h, mix(tone, OUT, 0.35))
        elif i % fold == 1:
            c.rect(x + i, y, 1, h, mix(tone, (255, 245, 225), 0.18))
    for i in range(r.i(0, 1), w, 9):  # petice
        c.rect(x + i, y + h - 3, 3, 2, mix(pal[1], OUT, 0.2))


def scallop(c, x, y, w, pal, depth=3):
    """Festonul de sub copertina, ca la taraba din joc."""
    for i in range(w):
        d = depth if (i // 3) % 2 == 0 else depth - 1
        tone = pal[1] if (i // 3) % 2 == 0 else CREAM[2]
        for k in range(d):
            if abs((i % 3) - 1) + k < d:
                c.put(x + i, y + k, tone)


def stripes(c, x, y, w, h, pal):
    for i in range(w):
        c.rect(x + i, y, 1, h, pal[3] if (i // 4) % 2 == 0 else CREAM[4])
        c.rect(x + i, y + h - 1, 1, 1, mix(pal[1], OUT, 0.3))


def window(c, x, y, w, h, lit=True):
    c.rect(x, y, w, h, GLASS if lit else STONE[1])
    c.rect(x, y, w, 1, GLASS_D)
    c.rect(x, y + h // 2, w, 1, mix(WOOD_D[2], (0, 0, 0, 255), 0.1))
    c.rect(x + w // 2, y, 1, h, mix(WOOD_D[2], (0, 0, 0, 255), 0.1))
    c.rect(x - 1, y - 1, w + 2, 1, WOOD_D[3])
    c.rect(x - 1, y + h, w + 2, 1, WOOD_D[3])


def rope(c, x0, y0, x1, y1, col=None):
    col = col or mix(CREAM[1], WOOD_D[2], 0.4)
    n = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(n + 1):
        t = i / max(1, n)
        c.put(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t + math.sin(math.pi * t) * 2, col)


def flame(c, cx, base, size=6):
    for i, col in enumerate(FLAME):
        r = size - i * 1.4
        if r > 0:
            c.ellipse(cx, base - 2 - i * 2.2, max(1, r * 0.72), max(1, r), col)


# ---- piesele bâlciului -------------------------------------------------------------------------
def stage_big(w=200, h=112):
    """Scena-tabela: podium cu trepte, fundal de panza cu falduri si trei panouri de clasament in rame."""
    c = C(w, h)
    # podiumul
    planks_h(c, 8, h - 26, w - 16, 24, WOOD, step=4, seed=11)
    c.rect(8, h - 4, w - 16, 4, WOOD_D[1])
    for x in range(12, w - 12, 18):                       # grinzile de sub podium
        c.rect(x, h - 5, 3, 5, WOOD_D[2])
    for i, x in enumerate((w // 2 - 46, w // 2 + 22)):    # treptele
        for k in range(3):
            c.rect(x - k, h - 12 + k * 4, 24 + k * 2, 4, WOOD[2 - k % 2])
            c.rect(x - k, h - 9 + k * 4, 24 + k * 2, 1, WOOD_D[2])
    # fundalul de panza, intre doi stalpi
    cloth(c, 16, 16, w - 32, h - 44, CLOTH_RED, fold=7, seed=4)
    # panourile de clasament, in rame de lemn
    panel = (w - 52) // 3
    for i in range(3):
        x = 22 + i * (panel + 8)
        c.rect(x - 2, 22, panel + 4, h - 60, WOOD_D[3])   # rama
        c.rect(x, 24, panel, h - 64, CREAM[4])            # hartia
        c.rect(x, 24, panel, 6, CLOTH_BLUE[3])            # capul de tabel
        c.rect(x, 29, panel, 1, mix(CLOTH_BLUE[1], OUT, 0.3))
        for r_ in range(6):                               # randurile clasamentului
            yy = 33 + r_ * 7
            if yy + 3 > 24 + h - 64:
                break
            c.rect(x + 3, yy, 4, 4, (FISH[3], hsv(44, 0.66, 0.80), CLOTH_GREEN[3])[i])  # iconita
            c.rect(x + 9, yy + 1, panel - 16, 2, mix(CREAM[1], OUT, 0.42))
            c.rect(x + panel - 6, yy + 1, 3, 2, mix(CREAM[1], OUT, 0.55))
    # grinda, bannerul si turnurile de lumina
    c.rect(14, 12, w - 28, 5, WOOD[3])
    c.rect(14, 16, w - 28, 1, WOOD_D[2])
    for x in (6, w - 14):
        planks_v(c, x, 6, 8, h - 20, WOOD, step=4, seed=7)
        c.rect(x - 2, 2, 12, 6, IRON[3])
        c.rect(x - 1, 3, 10, 4, IRON[2])
        for k in range(3):
            c.rect(x + k * 3, 4, 2, 2, GLASS)
        c.rect(x - 3, h - 16, 14, 4, WOOD_D[3])           # contrafisele
    c.rect(w // 2 - 46, 2, 92, 10, CLOTH_BLUE[3])
    cloth(c, w // 2 - 46, 2, 92, 10, CLOTH_BLUE, fold=5, seed=9)
    scallop(c, w // 2 - 46, 12, 92, CLOTH_BLUE)
    outline_trace(c)
    rim(c, 0.26)
    for i, x in enumerate(range(22, w - 20, 11)):         # becurile de pe grinda
        c.rect(x, 13, 3, 3, GLASS if i % 2 == 0 else hsv(348, 0.50, 0.98))
        c.put(x + 1, 12, CREAM[4])
    return c


def wheel_stand(w=70, h=86):
    """Roata zilnica de bâlci: obada din segmente, spite, felii vopsite, baldachin cu feston."""
    c = C(w, h)
    planks_v(c, w // 2 - 5, h - 40, 10, 38, WOOD, step=5, seed=13)   # stalpul
    c.rect(w // 2 - 6, h - 6, 12, 5, WOOD_D[2])
    c.rect(w // 2 - 9, h - 3, 18, 3, STONE[2])                       # talpa de piatra
    for y in (h - 34, h - 18):                                       # inelele de fier
        c.rect(w // 2 - 6, y, 12, 2, IRON[3])
    cx, cy, r = w // 2, h - 52, 22
    c.ellipse(cx, cy, r, r, WOOD_D[2])                               # obada
    c.ellipse(cx, cy, r - 2, r - 2, CREAM[3])
    for i in range(8):                                               # feliile
        a0 = math.tau * i / 8
        col = (CLOTH_RED[3], CLOTH_BLUE[3], CLOTH_GREEN[3], hsv(44, 0.70, 0.86))[i % 4]
        for t in range(1, r - 3):
            for s in range(-4, 5):
                c.put(cx + math.cos(a0 + s * 0.045) * t, cy + math.sin(a0 + s * 0.045) * t, col)
    for i in range(8):                                               # spitele
        a0 = math.tau * (i + 0.5) / 8
        for t in range(2, r - 3):
            c.put(cx + math.cos(a0) * t, cy + math.sin(a0) * t, WOOD_D[3])
    c.ellipse(cx, cy, 5, 5, WOOD[3])
    c.ellipse(cx, cy, 2, 2, IRON[3])
    for i in range(8):                                               # cuiele de pe obada
        a0 = math.tau * i / 8 + 0.4
        c.put(cx + math.cos(a0) * (r - 1), cy + math.sin(a0) * (r - 1), IRON[4])
    # baldachinul
    top = 4
    for i in range(w - 10):
        d = abs((i - (w - 10) / 2) / ((w - 10) / 2))
        height = int(11 * (1 - d ** 1.9))
        col = CLOTH_RED[3] if (i // 5) % 2 == 0 else CREAM[4]
        c.rect(5 + i, top + 11 - height, 1, height + 1, col)
        c.put(5 + i, top + 11 - height, mix(col, (255, 245, 225), 0.3))
    scallop(c, 5, top + 12, w - 10, CLOTH_RED)
    c.rect(w // 2 - 1, 0, 2, 6, WOOD_D[3])
    outline_trace(c)
    rim(c, 0.22)
    c.rect(cx - 1, cy - r - 4, 3, 5, hsv(44, 0.90, 1.0))             # acul
    return c


def stall(pal, w=52, h=44):
    """Taraba: copertina vargata cu feston, tejghea de scanduri, marfa, felinar si tablita de pret."""
    c = C(w, h)
    for x in (6, w - 9):                                              # stalpii
        planks_v(c, x, 10, 3, h - 18, WOOD, step=3, seed=3)
    planks_h(c, 4, h - 16, w - 8, 14, WOOD, step=4, seed=17)          # tejgheaua
    c.rect(4, h - 3, w - 8, 3, WOOD_D[1])
    c.rect(2, h - 18, w - 4, 3, WOOD[3])                              # blatul
    stripes(c, 2, 4, w - 4, 8, pal)                                   # copertina
    scallop(c, 2, 12, w - 4, pal)
    # marfa pe tejghea: peste, borcane, lada
    c.ellipse(13, h - 22, 6, 3, FISH[3])
    c.ellipse(11, h - 22, 2, 2, CREAM[4])
    c.rect(17, h - 24, 1, 3, FISH[2])
    for i, x in enumerate((24, 29, 34)):
        c.rect(x, h - 25, 4, 7, (CLOTH_GREEN[3], CREAM[3], CLOTH_BLUE[3])[i])
        c.rect(x, h - 25, 4, 1, WOOD_D[2])
    c.rect(w - 16, h - 26, 10, 8, WOOD[2])                            # lada
    c.rect(w - 16, h - 22, 10, 1, WOOD_D[2])
    c.rect(w - 14, h - 24, 6, 2, CREAM[2])                            # eticheta
    outline_trace(c)
    rim(c, 0.24)
    c.rect(w - 7, 13, 4, 5, GLASS)                                    # felinarul agatat
    c.rect(w - 7, 12, 4, 1, IRON[3])
    return c


def shop_stall(w=52, h=44):
    """[D61, partea 2] Taraba `Shop` (coltul cu Robux): copertina aurie, deci nu se confunda cu ale negustorului.
    Pe tejghea, ce se vinde: un teanc de monede (2x Flow), o pereche de ghete (Swift Boots) si un felinar (Long Nights)."""
    c = C(w, h)
    for x in (6, w - 9):                                              # stalpii
        planks_v(c, x, 10, 3, h - 18, WOOD, step=3, seed=5)
    planks_h(c, 4, h - 16, w - 8, 14, WOOD, step=4, seed=23)          # tejgheaua
    c.rect(4, h - 3, w - 8, 3, WOOD_D[1])
    c.rect(2, h - 18, w - 4, 3, WOOD[3])                              # blatul
    stripes(c, 2, 4, w - 4, 8, CLOTH_GOLD)                            # copertina
    scallop(c, 2, 12, w - 4, CLOTH_GOLD)
    # teancul de monede
    for i in range(4):
        c.rect(11, h - 20 - i * 2, 8, 2, CLOTH_GOLD[3 if i % 2 == 0 else 4])
        c.rect(11, h - 19 - i * 2, 8, 1, CLOTH_GOLD[1])
    # ghetele
    for x in (23, 30):
        c.rect(x, h - 26, 4, 7, LEATHER[3])
        c.rect(x, h - 20, 6, 2, LEATHER[2])
        c.rect(x, h - 26, 4, 1, CREAM[3])
    # felinarul de pe tejghea
    c.rect(w - 15, h - 27, 6, 8, IRON[3])
    c.rect(w - 14, h - 26, 4, 6, GLASS)
    c.rect(w - 14, h - 28, 4, 1, IRON[4])
    outline_trace(c)
    rim(c, 0.24)
    c.rect(w - 7, 13, 4, 5, GLASS)                                    # felinarul agatat
    c.rect(w - 7, 12, 4, 1, IRON[3])
    return c


def tent(w=60, h=54):
    """Cortul croitoresei: panza in doua culori, cusaturi, funii, tarusi si un manechin cu rochie."""
    c = C(w, h)
    body = w - 10
    for i in range(body):
        d = abs((i - body / 2) / (body / 2))
        height = int((h - 18) * (1 - d ** 1.75))
        col = CLOTH_BLUE[3] if (i // 6) % 2 == 0 else CREAM[4]
        c.rect(5 + i, h - 12 - height, 1, height, col)
        if i % 6 == 0:
            c.rect(5 + i, h - 12 - height, 1, height, mix(col, OUT, 0.30))
        c.put(5 + i, h - 12 - height, mix(col, (255, 245, 225), 0.35))
    c.rect(5, h - 14, body, 3, CLOTH_BLUE[1])                         # poala cortului
    planks_h(c, 3, h - 12, w - 6, 10, WOOD, step=4, seed=19)          # podeaua
    rope(c, w // 2, 4, w - 3, h - 14)
    rope(c, w // 2, 4, 3, h - 14)
    c.rect(w // 2 - 1, 1, 2, 7, WOOD_D[3])
    c.rect(w // 2 + 1, 1, 8, 4, CLOTH_RED[3])                         # fanionul
    c.rect(w // 2 + 1, 5, 8, 1, CLOTH_RED[1])
    outline_trace(c)
    rim(c, 0.20)
    # manechinul cu rochie, in fata cortului
    c.rect(w - 15, h - 30, 7, 12, CREAM[3])
    c.rect(w - 16, h - 31, 9, 2, CLOTH_GREEN[3])
    c.rect(w - 13, h - 34, 3, 4, CREAM[2])
    c.rect(w - 12, h - 18, 1, 6, WOOD_D[3])
    c.rect(w - 14, h - 12, 5, 2, WOOD_D[2])
    return c


def booth(w=46, h=40):
    """Gheretă de joc: panou cu tinte, tejghea, premii atarnate."""
    c = C(w, h)
    planks_v(c, 3, 6, w - 6, h - 20, WOOD, step=4, seed=23)
    c.rect(3, 6, w - 6, 2, WOOD[3])
    for i, y in enumerate(range(11, h - 18, 7)):
        for j, x in enumerate(range(7, w - 9, 9)):
            col = CLOTH_RED[3] if (i + j) % 2 == 0 else CREAM[3]
            c.ellipse(x + 3, y + 3, 3, 3, col)
            c.ellipse(x + 3, y + 3, 1, 1, CREAM[4])
    planks_h(c, 2, h - 14, w - 4, 12, WOOD, step=4, seed=29)
    c.rect(2, h - 3, w - 4, 3, WOOD_D[1])
    for i, x in enumerate((8, 18, 28)):                               # premiile atarnate
        c.rect(x, 2, 3, 5, (CLOTH_BLUE[3], CLOTH_GREEN[3], hsv(44, 0.66, 0.84))[i])
    outline_trace(c)
    rim(c, 0.24)
    return c


def arch(w=76, h=58):
    """Poarta satelor: stalpi de barne, arcada de scanduri, felinare si o tablita."""
    c = C(w, h)
    for x in (5, w - 13):
        logs_h(c, x, 12, 8, h - 14, WOOD, step=5, seed=31)
        c.rect(x - 2, h - 5, 12, 5, WOOD_D[2])
    for i in range(w - 22):
        y = 12 - int(9 * math.sin(math.pi * i / (w - 23)))
        c.rect(11 + i, y, 1, 7, WOOD[2 + (i // 5) % 2])
        c.put(11 + i, y, mix(WOOD[3], (255, 240, 210), 0.25))
        c.put(11 + i, y + 6, mix(WOOD[1], OUT, 0.35))
    c.rect(w // 2 - 14, 4, 28, 8, WOOD_D[3])                          # tablita
    c.rect(w // 2 - 12, 6, 24, 4, CREAM[3])
    for i in range(w // 2 - 11, w // 2 + 11, 4):
        c.rect(i, 7, 2, 2, mix(CREAM[1], OUT, 0.45))
    outline_trace(c)
    rim(c, 0.22)
    for x in (13, w - 19):                                            # felinarele
        c.rect(x, 16, 5, 6, IRON[3])
        c.rect(x + 1, 17, 3, 4, GLASS)
    return c


def dock(w=40, h=64):
    """Debarcaderul: scanduri cu rosturi, tarusi cu funie infasurata, felinar de capat."""
    c = C(w, h)
    planks_h(c, 7, 0, w - 14, h, WOOD, step=5, seed=37)
    for x in (4, w - 10):
        planks_v(c, x, h - 26, 6, 24, WOOD_D, step=3, seed=41)
        for k in range(3):
            c.rect(x - 1, h - 24 + k * 4, 8, 2, mix(CREAM[1], WOOD_D[1], 0.4))  # funia
    c.rect(w // 2 - 4, 1, 8, 7, IRON[3])
    c.rect(w // 2 - 3, 2, 6, 5, GLASS)
    outline_trace(c)
    rim(c, 0.18)
    return c


def hull(c, w, h, sheer_mid, bow_rise, stern_rise, keel, upper, lower, stripe=None):
    """[2026-10-07] Coca vazuta din lateral si putin de sus, ca barca vanzarii (prop_boat): bordul de sus e o linie
    aproape dreapta care urca spre prova (dreapta) si spre pupa, sub ea scandurile bordului, iar fundul se strange spre
    chila. Intoarce, pe coloane, linia bordului (y), ca restul desenului sa stea pe ea."""
    tops = {}
    for x in range(w):
        t = x / (w - 1)  # 0 = pupa, 1 = prova
        rise = bow_rise * max(0.0, (t - 0.55) / 0.45) ** 2 + stern_rise * max(0.0, (0.25 - t) / 0.25) ** 2
        top = round(sheer_mid - rise)
        # fundul: rotunjit spre capete, prova mai ascutita (taie apa)
        d = (t - 0.47) / (0.53 if t > 0.47 else 0.47)
        bottom = round(keel - (keel - sheer_mid - 2) * max(0.0, abs(d)) ** (1.8 if t > 0.47 else 2.6))
        if bottom <= top + 1:
            continue
        tops[x] = top
        for y in range(top, bottom + 1):
            k = (y - top) / max(1, bottom - top)
            if y == top:
                col = mix(upper[3], (255, 244, 220), 0.25)  # muchia bordului prinde lumina
            elif y == top + 1:
                col = upper[2]
            elif stripe is not None and y in (top + 3, top + 4):
                col = stripe[2] if y == top + 3 else stripe[1]
            elif k < 0.62:
                col = upper[2 + (y - top) // 3 % 2]  # scandurile bordului, pe randuri de 3 px
            else:
                col = lower[2] if k < 0.85 else lower[1]  # sub linia apei, mai inchis
            c.put(x, y, col)
    return tops


def ferry(w=62, h=30):
    """[2026-10-07] Barca balciului (rescrisa: cea veche era o cupola, iar felinarul plutea in aer). Din lateral, ca
    barca vanzarii: bord drept care urca spre prova, interiorul inchis deasupra bordului (acolo sta omul, la x ~25),
    vasla sprijinita, la pupa un fanion, iar la prova un stalp cu brat de care atarna felinarul (x ~55, y 6-11: acolo
    pune codul lumina lui)."""
    c = C(w, h)
    tops = hull(c, w, h, sheer_mid=17, bow_rise=6, stern_rise=3, keel=27, upper=WOOD, lower=WOOD_D)
    # interiorul: bordul din partea cealalta se vede deasupra, inchis, cu doua banci luminate
    for x, top in tops.items():
        if 3 < x < w - 5:
            for y in range(top - 3, top):
                c.put(x, y, WOOD_D[1] if y > top - 3 else WOOD_D[2])
    for bx in (18, 36):
        c.rect(bx, tops[bx] - 3, 4, 1, WOOD[3])  # bancile
    c.rect(4, tops[4] - 1, w - 9, 1, WOOD_D[3])  # muchia bordului departat
    # vasla sprijinita peste bord, cu pana in apa spre pupa
    for i in range(16):
        c.put(30 - i, tops[30] - 4 + i * 0.6, WOOD[3] if i % 4 else WOOD[2])
    c.rect(11, 23, 5, 3, WOOD[2])
    # fanionul de la pupa: catarg mic si un triunghi rosu
    c.rect(4, 4, 1, tops[4] - 4, WOOD_D[3])
    for y in range(4, 10):
        c.rect(5, y, max(1, 6 - abs(y - 6) * 2 + (1 if y < 7 else 0)), 1, CLOTH_RED[2] if y < 7 else CLOTH_RED[1])
    # stalpul felinarului la prova, cu bratul spre inapoi; felinarul atarna de el
    c.rect(58, 3, 1, tops[58] - 3, WOOD_D[3])
    c.rect(54, 3, 5, 1, WOOD_D[3])
    c.rect(55, 4, 1, 1, IRON[2])  # carligul
    rope(c, 2, tops[2] + 1, 7, tops[7] + 3)
    outline_trace(c)
    rim(c, 0.16)
    c.rect(53, 5, 5, 7, IRON[3])  # felinarul, dupa contur ca sa ramana curat
    c.rect(54, 6, 3, 4, GLASS)
    c.rect(54, 10, 3, 1, GLASS_D)
    c.rect(54, 5, 3, 1, IRON[1])
    return c


# [2026-10-07] Barca barajului: o salupa cu aburi, vopsita (alb, dunga rosie, carena verde inchis), cu cabina si cos
# spre prova, cockpitul deschis la pupa (omul sta la x ~25) si felinarul la prova, in acelasi loc ca la barca balciului.
PAINT = ramp(hue=40, sat=0.10, val=0.86, val_span=0.26)
KEEL_GREEN = ramp(hue=160, sat=0.40, val=0.30, val_span=0.24)
BRASS = ramp(hue=42, sat=0.62, val=0.70, val_span=0.38)


def launch(w=62, h=30):
    c = C(w, h)
    tops = hull(c, w, h, sheer_mid=17, bow_rise=5, stern_rise=1, keel=27, upper=PAINT, lower=KEEL_GREEN,
                stripe=CLOTH_RED)
    # puntea si cockpitul: interior de lemn lacuit, cu balustrada de alama
    for x, top in tops.items():
        if 3 < x < w - 4:
            for y in range(top - 2, top):
                c.put(x, y, WOOD[1] if y == top - 1 else WOOD[2])
    for x in range(5, w - 6, 5):
        c.rect(x, tops[x] - 4, 1, 2, BRASS[2])
    c.rect(5, tops[5] - 5, w - 12, 1, BRASS[3])
    # cabina spre prova, cu doua ferestre luminate si acoperis cu streasina
    cx0, cx1 = 34, 49
    roof = 7
    c.rect(cx0, roof + 2, cx1 - cx0, tops[cx0] - roof - 2, PAINT[2])
    c.rect(cx0, roof + 2, 1, tops[cx0] - roof - 2, PAINT[1])
    for wx in (37, 43):
        c.rect(wx, roof + 4, 4, 3, GLASS)
        c.rect(wx, roof + 7, 4, 1, GLASS_D)
    c.rect(cx0 - 1, roof, cx1 - cx0 + 3, 2, KEEL_GREEN[2])
    c.rect(cx0 - 1, roof + 2, cx1 - cx0 + 3, 1, KEEL_GREEN[0])
    # cosul: negru, cu inel de alama, putin aplecat spre pupa (fumul il pune codul, din RideScene.FUNNEL = 40.5, 3);
    # incepe la y 3, ca placuta „Ferry to the Fair” (pana la y 678 in lume) sa nu-l atinga
    for y in range(3, roof):
        x = 40 - (roof - y) // 4
        c.rect(x, y, 3, 1, IRON[0] if y > 3 else IRON[1])
    c.rect(39, 4, 4, 1, BRASS[3])
    # pupa: fanion si roata carmei
    c.rect(3, 5, 1, tops[3] - 5, WOOD_D[3])
    for y in range(5, 10):
        c.rect(4, y, max(1, 5 - abs(y - 7) * 2 + (1 if y < 8 else 0)), 1, CLOTH_BLUE[2] if y < 8 else CLOTH_BLUE[1])
    c.ellipse(15, tops[15] - 4, 2, 2, BRASS[1])
    c.put(15, tops[15] - 4, BRASS[3])
    # felinarul de la prova, pe un catarg scurt
    c.rect(57, 3, 1, tops[57] - 3, IRON[1])
    c.rect(54, 3, 4, 1, IRON[1])
    outline_trace(c)
    rim(c, 0.14)
    c.rect(53, 5, 5, 7, BRASS[1])
    c.rect(54, 6, 3, 4, GLASS)
    c.rect(54, 10, 3, 1, GLASS_D)
    return c


def bonfire(w=40, h=34):
    """Focul: cerc de pietre, butuci cu inele, flacara pe patru tonuri si jar."""
    c = C(w, h)
    for i in range(10):                                                # cercul de pietre
        a = math.tau * i / 10
        c.ellipse(w // 2 + math.cos(a) * 16, h - 6 + math.sin(a) * 5, 3, 2, STONE[1 + i % 3])
    for i, (x, y, l) in enumerate(((6, h - 12, 28), (9, h - 16, 22), (13, h - 20, 14))):
        c.rect(x, y, l, 4, WOOD_D[1 + i % 3])
        c.rect(x, y, l, 1, mix(WOOD_D[3], (255, 230, 190), 0.2))
        c.ellipse(x, y + 2, 2, 2, WOOD[1])                             # capatul butucului
        c.ellipse(x + l, y + 2, 2, 2, WOOD[2])
    flame(c, w // 2, h - 14, 9)
    outline_trace(c)
    c.ellipse(w // 2, h - 9, 12, 4, hsv(18, 0.85, 0.66))               # jarul
    for i in range(6):
        c.put(w // 2 - 8 + i * 3, h - 9 + (i % 2), hsv(30, 0.90, 0.92))
    return c


def brazier(w=22, h=32):
    c = C(w, h)
    for x in (3, w // 2 - 1, w - 5):
        c.rect(x, h - 16, 2, 16, IRON[2])
        c.rect(x - 1, h - 2, 4, 2, IRON[1])
    c.rect(2, h - 21, w - 4, 6, IRON[3])
    c.rect(2, h - 21, w - 4, 1, IRON[4])
    for i in range(3, w - 4, 4):
        c.put(i, h - 19, IRON[4])                                      # nituri
    flame(c, w // 2, h - 21, 6)
    outline_trace(c)
    return c


def table(w=40, h=22):
    """Masa lunga cu halbe, castron si banci: viata bâlciului."""
    c = C(w, h)
    planks_h(c, 0, 5, w, 7, WOOD, step=4, seed=43, nails=False)
    c.rect(0, 11, w, 2, WOOD_D[2])
    for x in (3, w - 6):
        c.rect(x, 13, 3, 8, WOOD_D[3])
    for i, x in enumerate(range(5, w - 7, 10)):                        # halbele
        c.rect(x, 1, 5, 5, CREAM[3])
        c.rect(x, 1, 5, 1, CREAM[4])
        c.rect(x + 5, 2, 1, 3, CREAM[2])
    c.ellipse(w - 9, 4, 4, 2, CLOTH_GREEN[3])                          # castronul
    outline_trace(c)
    rim(c, 0.22)
    return c


def bench(w=26, h=14):
    c = C(w, h)
    planks_h(c, 0, 2, w, 5, WOOD, step=3, seed=47, nails=False)
    c.rect(0, 7, w, 2, WOOD_D[2])
    for x in (2, w - 5):
        c.rect(x, 9, 3, 5, WOOD_D[3])
    outline_trace(c)
    rim(c, 0.22)
    return c


def lamppost(w=16, h=48):
    c = C(w, h)
    c.rect(w // 2 - 2, 8, 4, h - 10, IRON[2])
    c.rect(w // 2 - 1, 8, 1, h - 10, IRON[4])
    c.rect(w // 2 - 5, h - 3, 11, 3, IRON[1])
    c.rect(w // 2 - 4, h - 6, 9, 3, IRON[2])
    c.rect(w // 2 - 5, 2, 11, 9, IRON[3])                              # cusca felinarului
    c.rect(w // 2 - 4, 3, 9, 7, GLASS)
    c.rect(w // 2 - 4, 6, 9, 1, IRON[3])
    c.rect(w // 2 - 1, 3, 1, 7, IRON[3])
    c.rect(w // 2 - 6, 1, 13, 2, IRON[4])
    outline_trace(c)
    return c


def plinth(w=28, h=42):
    """Soclul campionului: piatra cu placuta si statuia mica."""
    c = C(w, h)
    c.rect(3, h - 14, w - 6, 14, SANDSTONE[2])
    for i in range(3, w - 3, 6):
        c.rect(i, h - 14, 1, 14, mix(SANDSTONE[1], OUT, 0.3))
    c.rect(5, h - 24, w - 10, 11, SANDSTONE[3])
    c.rect(7, h - 21, w - 14, 5, hsv(44, 0.68, 0.80))                  # placuta
    c.rect(8, h - 20, w - 16, 1, hsv(44, 0.50, 0.95))
    c.rect(w // 2 - 4, h - 38, 8, 15, CREAM[3])                        # statuia
    c.rect(w // 2 - 4, h - 38, 3, 15, CREAM[2])
    c.ellipse(w // 2, h - 39, 4, 4, CREAM[4])
    c.rect(w // 2 + 2, h - 34, 4, 3, CREAM[2])
    outline_trace(c)
    rim(c, 0.26)
    return c


def flagpole(w=18, h=54):
    c = C(w, h)
    c.rect(3, 0, 3, h, WOOD[2])
    c.rect(4, 0, 1, h, WOOD[3])
    c.rect(1, h - 4, 7, 4, WOOD_D[2])
    for i in range(14):
        c.rect(6, 3 + i, 11 - abs(7 - i), 1, CLOTH_RED[3] if i % 2 else CLOTH_RED[2])
    c.rect(6, 3, 1, 14, mix(CLOTH_RED[1], OUT, 0.3))
    outline_trace(c)
    rim(c, 0.2)
    return c


def performer(w=18, h=30):
    c = C(w, h)
    c.rect(w // 2 - 4, 10, 8, 13, CLOTH_RED[3])
    c.rect(w // 2 - 4, 10, 2, 13, CLOTH_RED[2])
    c.rect(w // 2 - 2, 14, 4, 2, hsv(44, 0.70, 0.88))                  # cingatoarea
    c.ellipse(w // 2, 7, 4, 4, hsv(32, 0.42, 0.86))
    c.rect(w // 2 - 4, 3, 8, 3, WOOD_D[2])                             # palaria
    c.rect(w // 2 - 7, 7, 3, 9, CLOTH_RED[2])
    c.rect(w // 2 + 4, 7, 3, 9, CLOTH_RED[2])
    c.rect(w // 2 - 3, 23, 3, 7, WOOD_D[2])
    c.rect(w // 2 + 1, 23, 3, 7, WOOD_D[2])
    outline_trace(c)
    rim(c, 0.2)
    return c


def musician(w=20, h=30):
    c = C(w, h)
    c.rect(w // 2 - 3, 11, 8, 12, CLOTH_BLUE[3])
    c.ellipse(w // 2, 8, 4, 4, hsv(32, 0.42, 0.86))
    c.rect(w // 2 - 9, 13, 7, 9, WOOD[3])                              # toba
    c.rect(w // 2 - 9, 13, 7, 1, CREAM[3])
    c.rect(w // 2 - 9, 21, 7, 1, CREAM[2])
    c.rect(w // 2 - 10, 15, 1, 5, IRON[3])
    c.rect(w // 2 - 3, 23, 3, 7, WOOD_D[2])
    c.rect(w // 2 + 2, 23, 3, 7, WOOD_D[2])
    outline_trace(c)
    rim(c, 0.2)
    return c


def crate(w=20, h=18):
    c = C(w, h)
    planks_v(c, 0, 0, w, h, WOOD, step=5, seed=53)
    c.rect(0, h // 2 - 1, w, 2, WOOD_D[3])
    c.rect(0, 0, w, 2, WOOD[3])
    for x in (1, w - 3):
        c.rect(x, 0, 2, h, WOOD_D[2])
    c.rect(4, 3, w - 8, 4, CREAM[2])                                   # eticheta
    for i in range(5, w - 5, 3):
        c.rect(i, 4, 2, 1, mix(CREAM[1], OUT, 0.5))
    outline_trace(c)
    rim(c, 0.24)
    return c


def barrel(w=18, h=24):
    c = C(w, h)
    for i in range(h):
        d = abs(i - h / 2) / (h / 2)
        inset = int(2.5 * d * d)
        tone = WOOD[2 + (i // 6) % 2]
        c.rect(inset, i, w - inset * 2, 1, tone)
    for i in range(2, w - 2, 5):
        c.rect(i, 1, 1, h - 2, mix(WOOD[1], OUT, 0.35))       # doagele
    for y in (3, h - 6):
        c.rect(0, y, w, 3, IRON[2])
        c.rect(0, y, w, 1, IRON[4])
    c.ellipse(w // 2, 1, w // 2 - 2, 2, WOOD[3])
    outline_trace(c)
    rim(c, 0.24)
    return c


def trophy(w=24, h=34):
    """Trofeul unei specii: soclu de piatra, placuta si pestele de bronz deasupra."""
    c = C(w, h)
    c.rect(3, h - 12, w - 6, 12, SANDSTONE[2])
    c.rect(3, h - 12, w - 6, 1, SANDSTONE[4])
    c.rect(5, h - 18, w - 10, 7, SANDSTONE[3])
    c.rect(7, h - 16, w - 14, 3, hsv(44, 0.68, 0.78))
    body = hsv(36, 0.62, 0.74)
    c.ellipse(w // 2, h - 24, 8, 4, body)
    c.rect(w // 2 + 6, h - 27, 5, 6, hsv(36, 0.62, 0.62))              # coada
    c.ellipse(w // 2 - 4, h - 25, 1, 1, OUT)                           # ochiul
    c.rect(w // 2 - 2, h - 27, 5, 2, hsv(36, 0.70, 0.86))              # inotatoarea
    outline_trace(c)
    rim(c, 0.3)
    return c


def reeds(w=18, h=26):
    c = C(w, h)
    r = Rng(59)
    for i in range(5):
        x = 2 + i * 3
        hh = h - 6 - r.i(0, 6)
        c.rect(x, h - hh, 2, hh, CLOTH_GREEN[1 + i % 3])
        c.rect(x, h - hh, 1, hh, mix(CLOTH_GREEN[1], OUT, 0.3))
        c.rect(x - 1, h - hh - 4, 4, 5, WOOD_D[2])                     # papura
    outline_trace(c)
    rim(c, 0.2)
    return c


def miniature(w=32, h=26):
    """Satul altcuiva, in miniatura, pe panoul de la poarta."""
    c = C(w, h)
    c.rect(2, h - 9, w - 4, 9, hsv(104, 0.32, 0.38))
    c.rect(2, h - 9, w - 4, 1, hsv(104, 0.30, 0.48))
    for x, hh, col in ((4, 9, CLOTH_RED), (12, 11, CLOTH_BLUE), (22, 8, CLOTH_GREEN)):
        c.rect(x, h - 9 - hh, 7, hh, WOOD[2])
        c.rect(x, h - 9 - hh + 3, 7, 1, WOOD_D[2])
        shingles(c, x - 1, h - 12 - hh, 9, 4, col, step=2)
        c.rect(x + 2, h - 13, 2, 3, GLASS_D)
    c.rect(0, h - 4, w, 4, hsv(206, 0.52, 0.44))                        # raul
    for i in range(0, w, 5):
        c.rect(i, h - 3, 3, 1, hsv(206, 0.30, 0.70))
    c.rect(0, h - 26, w, 2, WOOD_D[3])                                  # rama panoului
    outline_trace(c)
    rim(c, 0.22)
    return c


def tile_fair(w=64, h=64):
    """Pamantul batatorit al balciului: pamant calcat, paie si pietricele, ca sa nu fie o suprafata moarta."""
    c = C(w, h)
    r = Rng(97)
    ground = ramp(hue=28, sat=0.34, val=0.42, val_span=0.26)
    for y in range(h):
        for x in range(w):
            c.put(x, y, ground[1 + r.i(0, 2)])
    for _ in range(90):                                    # paie
        x, y = r.i(0, w - 4), r.i(0, h - 2)
        col = mix(ground[4], hsv(44, 0.42, 0.72), 0.55)
        c.rect(x, y, 2 + r.i(0, 2), 1, col)
    for _ in range(40):                                    # pietricele
        x, y = r.i(0, w - 2), r.i(0, h - 2)
        c.rect(x, y, 2, 1, mix(ground[2], (170, 164, 150), 0.5))
    for _ in range(26):                                    # urme de calcat
        x, y = r.i(0, w - 3), r.i(0, h - 3)
        c.rect(x, y, 3, 2, mix(ground[0], (0, 0, 0, 255), 0.12))
    return c


SPRITES = {
    "prop_fair_stage": stage_big,
    "prop_fair_wheel": wheel_stand,
    "prop_fair_stall_1": lambda: stall(CLOTH_RED),
    "prop_fair_stall_2": lambda: stall(CLOTH_GREEN),
    "prop_fair_stall_3": lambda: stall(CLOTH_BLUE),
    "prop_fair_shop": shop_stall,  # [D61, partea 2]
    "prop_fair_tent": tent,
    "prop_fair_booth": booth,
    "prop_fair_arch": arch,
    "prop_fair_dock": dock,
    "prop_fair_ferry": ferry,
    "prop_fair_launch": launch,  # [2026-10-07] barca barajului spre balci
    "prop_fair_bonfire": bonfire,
    "prop_fair_brazier": brazier,
    "prop_fair_table": table,
    "prop_fair_bench": bench,
    "prop_fair_lamppost": lamppost,
    "prop_fair_plinth": plinth,
    "prop_fair_flag": flagpole,
    "prop_fair_trophy": trophy,
    "prop_fair_crate": crate,
    "prop_fair_barrel": barrel,
    "prop_fair_reeds": reeds,
    "prop_fair_miniature": miniature,
    "tile_fair": tile_fair,
}


def main():
    force = "--force" in sys.argv
    only = [a for a in sys.argv[1:] if not a.startswith("--")]
    names = only or list(SPRITES)
    for name in names:
        if os.path.exists(os.path.join(OUT_DIR, name + ".png")) and not force:
            sys.exit(f"{name}.png exista deja; --force ca sa-l rescrii")
    for name in names:
        c = SPRITES[name]()
        png(name + ".png", c.w, c.h, c.px)
        print(f"scris {name}.png ({c.w}x{c.h})")


if __name__ == "__main__":
    main()
