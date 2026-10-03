#!/usr/bin/env python3
"""[D75, lotul A1, grupul "town"] Cladirile din Dam Town: clopotnita, Memory Wall si cele trei casute ale oamenilor
retrasi. Barajul e de piatra (varianta A din a0_dam.py), deci orasul de langa el e zidit din aceeasi piatra calda.

  prop_old_bells        32x80  "Old Bells": turn de piatra subtire, la capatul de sud al zidului (baza la 760, 960). Fusul si
                               stalpii clopotariei sunt cu un pas mai inchisi decat zidul, ca sa se desprinda de el, si
                               arunca o umbra scurta la dreapta. Clopotaria deschisa tine cele TREI clopote ale satului,
                               atarnate de grinzi: sus cel de bronz de la Landing (umar rotunjit, buza evazata); jos, alaturi,
                               cel de CUPRU de la Moara (cu brau de verdigris si rotita dintata pe grinda de deasupra) si cel
                               de ALAMA de la Works. Acoperis ascutit de olane, bila de alama, firida cu placuta, usa mica.
                               Nu seamana cu prop_bell (cadru de barne) si nici cu prop_works_bell (zabrele de fier).
  prop_memory_wall      64x32  "Memory Wall": un zid scund de piatra, intre doi stalpi mai deschisi care se ridica peste
                               streasina de lemn si incadreaza tablourile: o casuta, o placuta de alama cu un clopotel si
                               doua randuri de scris, satul pe rau, o plasa; lumanari pe soclu, flori la picior. Cald si
                               demn; fara picioare si fara hartii, deci nu e Village Board.
  prop_dam_cottage_1/2/3 40x34 casutele celor retrasi: soclu de piatra, pereti de barne cu umplutura de tencuiala,
                               acoperis de olane (ardezie albastra / rosu cald / verde de muschi), cos, fereastra aprinsa,
                               usa, ladita cu flori. Aceeasi familie, dar nu sunt colibele de angajare (prop_hut_*_2),
                               care sunt de busteni cu stuf.

Aceleasi reguli ca restul conductei: culori din palette.ramp(), umbra moale, contur trasat automat (outline_trace),
lumina din stanga-sus, niciodata negru pur. Scrie DOAR in --out (implicit scratchpad-ul sesiunii), nu in assets/sprites.

Rulare: python3 scripts/art/a1_town.py [--out DIR]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, FOAM, WATER, LEAF, ramp  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import WARM, PLANK, outline_trace  # noqa: E402
from ruins_d53 import MOSS, line  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402

SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a1"
SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---------------------------------------------------------------------------------------------
# paleta: piatra calda a barajului (aceeasi familie cu STONE din a0_dam.py), clopotele, olanele, tencuielile

DSTONE = ramp(36, 0.16, 0.56, steps=6, hue_shift=6, val_span=0.54)  # piatra calda a zidului, de la umbra la lumina
BRONZE = ramp(30, 0.52, 0.48, hue_shift=8, val_span=0.40)  # clopotul de la Landing (mai inchis decat cuprul)
COPPER, VERDIGRIS = M.COPPER, M.VERDIGRIS  # clopotul Morii
BRASS = W.BRASS  # clopotul de la Works
IRON = W.IRON
ROOF_TILE = ramp(10, 0.58, 0.56, hue_shift=6, val_span=0.42)  # olane rosii, mai calde decat TILE al Pietei
SLATE = ramp(214, 0.34, 0.50, hue_shift=8, val_span=0.40)  # ardezie albastra
MOSSROOF = ramp(108, 0.40, 0.40, hue_shift=10, val_span=0.40)  # olane acoperite de muschi, mai inchise decat iarba
PLASTER_CREAM = ramp(42, 0.16, 0.90, hue_shift=6, val_span=0.30)
PLASTER_SAND = ramp(36, 0.30, 0.82, hue_shift=6, val_span=0.30)
PLASTER_MIST = ramp(196, 0.10, 0.88, hue_shift=6, val_span=0.30)  # alb-albastrui, var spalat
TIMBER = ramp(24, 0.50, 0.34, hue_shift=8, val_span=0.34)  # barnele aparente, maro inchis
INK = (58, 40, 30, 255)
FLAME = ((255, 244, 176, 255), (255, 206, 96, 255))
RED_F, YEL_F, BLUE_F, WHITE_F, PINK_F = (
    (214, 70, 66, 255),
    (246, 206, 70, 255),
    (92, 130, 214, 255),
    (246, 242, 230, 255),
    (232, 130, 160, 255),
)


def clamp(v, a, b):
    return max(a, min(b, v))


# ---------------------------------------------------------------------------------------------
# bucati comune


def ashlar(c, rng, bounds, y0, y1, xmin, xmax, tones=DSTONE, ch=4, bw=(5, 8), lit=2, dark=4, base=(2, 3)):
    """Zid de blocuri cioplite, in randuri de `ch` px, cu rosturi decalate. `bounds(y)` da (stanga, dreapta) la fiecare
    rand (ca turnul sa se poata ingusta spre varf). Lumina vine din stanga-sus: primii `lit` px din stanga si randul de
    sus al blocului sunt mai deschisi, ultimii `dark` px din dreapta mai inchisi (fata umbrita), rosturile, cele mai
    inchise. `base` = tonul de baza al blocurilor, tras la sorti intre cele doua capete (mai mic = piatra mai inchisa)."""
    top = len(tones) - 1
    row = 0
    y = y0
    while y < y1:
        h = min(ch, y1 - y)
        x = xmin - (rng.i(0, bw[1] - 1) if row % 2 else 0)
        while x < xmax:
            w = rng.i(bw[0], bw[1])
            tb = rng.i(base[0], base[1])  # tonul blocului
            for yy in range(y, y + h):
                xl, xr = bounds(yy)
                for xx in range(max(x, xl), min(x + w, xr)):
                    t = tb
                    if yy == y:
                        t += 1  # muchia de sus prinde lumina
                    if yy == y + h - 1:
                        t -= 2  # rostul de jos
                    elif xx == x:
                        t -= 1  # rostul din stanga
                    if xx - xl < lit:
                        t += 1
                    if xr - 1 - xx < dark:
                        t -= 1
                    c.put(xx, yy, tones[clamp(t, 0, top)])
            x += w
        y += h
        row += 1


def bell(c, cx, top, hws, tones, band=None, band_tones=None):
    """Un clopot mic, dupa un profil explicit: `hws[i]` = jumatate din latimea randului i (latimea e para, deci clopotul sta
    pe marginea dintre doi pixeli: x de la cx - hw la cx + hw). Umar rotunjit, corp drept, buza evazata; un brau mai
    inchis la `band` (in rampa `band_tones`, daca e data: verdigris pe cupru). Lumina din stanga: coloana din stanga
    luminata, din dreapta in umbra. Deasupra, urechea de care atarna; dedesubt, limba."""
    last = len(hws) - 1
    for i, hw in enumerate(hws):
        xl, xr = cx - hw, cx + hw
        for x in range(xl, xr):
            tn = tones
            t = 2
            if x == xl:
                t = 4
            elif x == xl + 1 and hw > 1:
                t = 3
            elif x == xr - 1:
                t = 1
            if i == 0:
                t = 3 if x < xr - 1 else 2
            if i == band:
                if band_tones is not None:
                    tn = band_tones
                    t = 4 if x == xl else (3 if x < xr - 1 else 2)
                else:
                    t = 1 if x > xl else 2
            if i == last:
                t = 1 if x > xl else 3  # buza
            c.put(x, top + i, tn[t])
    c.rect(cx - 1, top + last + 1, 2, 1, tones[0])  # limba
    c.rect(cx - 1, top - 1, 2, 1, IRON[2])  # urechea de care atarna


def cog(c, cx, cy):
    """Rotita dintata a Morii (5x5), prinsa pe grinda: inel de fier cu gaura la mijloc si patru dinti. Lumina din stanga-sus:
    marginea din stanga-sus mai deschisa, cea din dreapta-jos mai inchisa. `(cx, cy)` = centrul (gaura)."""
    ring = ((-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1))
    for dx, dy in ring:
        t = 3  # corpul inelului
        if dx < 0 or dy < 0:
            t = 4  # marginea din stanga-sus, luminata
        if dx > 0 and dy > 0:
            t = 2  # coltul din dreapta-jos, in umbra
        c.put(cx + dx, cy + dy, IRON[t])
    c.put(cx, cy, IRON[0])  # gaura osiei
    for dx, dy in ((0, -2), (-2, 0), (2, 0), (0, 2)):  # dintii
        c.put(cx + dx, cy + dy, IRON[4] if dx <= 0 and dy <= 0 else IRON[2])


def tile_roof(c, rows, left_of, right_of, y0, tones, tile=4):
    """Acoperis de olane in vedere frontala: `rows` randuri, de la y0, intre left_of(i) si right_of(i). Randurile de olane
    se decaleaza, fiecare olan are un rost intunecat in stanga si o buza luminata sus; stanga acoperisului prinde
    lumina, dreapta e mai inchisa. Ultimul rand e streasina (mai inchisa), cu umbra pe rand."""
    for i in range(rows):
        y = y0 + i
        xl, xr = left_of(i), right_of(i)
        span = max(1, xr - xl)
        course = i // 2
        for x in range(xl, xr):
            t = 2
            u = (x - xl) / span
            dith = (x + y) % 2 == 0  # trecerea dintre benzi se face cu cadru de sah, nu cu dunga dreapta
            if u < 0.26 or (u < 0.34 and dith):
                t = 3
            elif u > 0.76 or (u > 0.66 and dith):
                t = 1
            if i % 2 == 1:
                t -= 1  # a doua jumatate a olanului, in umbra celui de deasupra
            else:
                if (x + (tile // 2 if course % 2 else 0)) % tile == 0:
                    t -= 1  # rostul dintre olane
                elif (x + (tile // 2 if course % 2 else 0)) % tile == 1:
                    t += 1  # buza luminata
            if i == rows - 1:
                t = 0 if u > 0.30 else 1
            c.put(x, y, tones[clamp(t, 0, len(tones) - 1)])
        c.put(xl, y, tones[min(4, 3 if i % 2 == 0 else 2)])  # muchia laterala luminata
        c.put(xr - 1, y, tones[0])


def flower_cluster(c, x, y, colors, w=5, leaf=True):
    """Un buchet de flori scunde: frunze verzi dedesubt, capete colorate deasupra. `y` = randul de jos (pe pamant)."""
    if leaf:
        for k in range(w):
            c.put(x + k, y, LEAF[1])
            if k % 2 == 0:
                c.put(x + k, y - 1, LEAF[2])
    for k in range(0, w, 2):
        col = colors[(k // 2) % len(colors)]
        c.put(x + k, y - 2, col)
        c.put(x + k, y - 1, LEAF[2])
    c.put(x + 1, y - 1, colors[-1])


def candle(c, x, y):
    """O lumanare (2x4) cu para si o raza calda; `y` = baza."""
    c.rect(x, y - 3, 2, 3, CREAM[3])
    c.put(x, y - 3, CREAM[4])
    c.put(x + 1, y - 1, CREAM[1])
    c.put(x, y - 4, FLAME[0])
    c.put(x, y - 5, FLAME[1])
    for dx, dy in ((-1, -4), (2, -4), (0, -6), (-1, -5), (1, -5)):
        c.put(x + dx, y + dy, (255, 214, 120, 70))


# ---------------------------------------------------------------------------------------------
# 1. Old Bells


def prop_old_bells():
    """Old Bells (32x80): turn de piatra, subtire, la capatul de sud al zidului. Clopotaria deschisa, intunecata la interior ca
    sa iasa clopotele, tine cele trei clopote ale satului: sus, pe grinda de lemn, cel de bronz de la Landing; jos, alaturi,
    cel de cupru de la Moara (cu rotita dintata pe burta) si cel de alama de la Works. Acoperis ascutit de olane cu bila de
    alama, firida cu placuta, usa mica de lemn si un soclu in trepte."""
    c = C(32, 80)
    rng = Rng(7501)
    soft_shadow(c, 16, 78, 14, 1.5)

    # soclul, in doua trepte
    ashlar(c, rng, lambda y: (3, 29), 74, 77, 3, 29, ch=3, bw=(6, 9), lit=2, dark=4)
    ashlar(c, rng, lambda y: (5, 27), 71, 74, 5, 27, ch=3, bw=(6, 9), lit=2, dark=4)
    c.rect(5, 71, 22, 1, DSTONE[4])
    c.rect(3, 74, 26, 1, DSTONE[4])

    # fusul turnului: mai ingust decat clopotaria, se latesc 1 px spre baza. Piatra lui e cu un pas mai inchisa (si mai calda)
    # decat a zidului din spate, ca turnul sa nu se topeasca in baraj: contur de 1 px nu ajunge.
    def shaft(y):
        return (8, 24) if y < 60 else (7, 25)

    ashlar(c, rng, shaft, 44, 71, 7, 25, ch=4, bw=(5, 8), lit=2, dark=4, base=(1, 2))
    # cornisa de sub clopotarie (iese in afara fusului)
    c.rect(4, 42, 24, 2, DSTONE[4])
    c.rect(4, 42, 24, 1, DSTONE[5])
    c.rect(4, 44, 24, 1, DSTONE[0])
    for x in range(5, 27, 3):
        c.put(x, 43, DSTONE[3])

    # clopotaria: stalpii colturilor, ziditi, tot cu piatra mai inchisa
    ashlar(c, rng, lambda y: (5, 9), 15, 42, 5, 9, ch=4, bw=(4, 4), lit=1, dark=2, base=(1, 2))
    ashlar(c, rng, lambda y: (23, 27), 15, 42, 23, 27, ch=4, bw=(4, 4), lit=1, dark=2, base=(1, 2))
    # golul dintre ei: umbra rece a interiorului, ca bronzul si cuprul sa iasa din ea
    c.rect(9, 15, 14, 25, IRON[0])
    c.rect(10, 17, 12, 22, (50, 60, 68, 255))
    for y in range(22, 40, 5):  # rosturile peretelui din spate
        for x in range(11 + (y // 5 % 2) * 3, 22, 6):
            c.put(x, y, IRON[1])
    c.rect(22, 15, 1, 25, DSTONE[2])  # fata dinspre lumina a stalpului din dreapta
    # pervazul de jos al golului
    c.rect(9, 40, 14, 2, DSTONE[4])
    c.rect(9, 40, 14, 1, DSTONE[5])
    # grinda de sus (jugul clopotului de la Landing), din lemn: randurile 16-18
    c.rect(10, 16, 12, 2, WOOD[3])
    c.rect(10, 16, 12, 1, WOOD[4])
    c.rect(10, 18, 12, 1, WOOD[0])
    # grinda de la mijloc, tine cele doua clopote de jos: randurile 29-31
    c.rect(9, 29, 14, 2, WOOD[3])
    c.rect(9, 29, 14, 1, WOOD[4])
    c.rect(9, 31, 14, 1, WOOD[0])
    # clopotele, atarnate de grinzi (urechea la grinda, limba lasa aer sub ea):
    # Landing, sus: urechea 19, corpul 20-26 (umar rotunjit, corp drept, buza evazata), limba 27, aer la 28
    bell(c, 16, 20, [2, 3, 3, 3, 4, 4, 5], BRONZE, band=5)
    # Moara si Works, jos: urechile 32, corpurile 33-38, limbile 39, apoi pervazul de la 40
    bell(c, 13, 33, [1, 2, 2, 2, 2, 3], COPPER, band=4, band_tones=VERDIGRIS)  # Moara: cupru cu brau de verdigris
    bell(c, 20, 33, [1, 2, 2, 2, 2, 3], BRASS)  # Works: alama
    cog(c, 13, 30)  # rotita Morii, pe grinda de deasupra clopotului de cupru (ca la prop_mill_bell, pe crestet)

    # acoperisul ascutit, de olane rosii, cu streasina larga
    tile_roof(c, 12, lambda i: 14 - i, lambda i: 18 + i, 3, ROOF_TILE, tile=4)
    c.rect(5, 15, 22, 1, (0, 0, 0, 70))  # umbra streasinii pe clopotarie
    c.rect(6, 16, 20, 1, (0, 0, 0, 34))
    c.rect(14, 3, 4, 1, ROOF_TILE[3])  # coama
    # bila de alama de pe varf (randurile 1-2: randul 0 ramane liber, ca sa-l poata contura outline_trace)
    c.ellipse(15.5, 1.6, 1.5, 1.4, BRASS[3])
    c.put(15, 1, BRASS[4])
    c.put(16, 2, BRASS[1])

    # firida cu placuta de alama
    c.rect(11, 51, 10, 8, DSTONE[1])  # cadrul firidei
    c.rect(11, 51, 10, 1, DSTONE[4])
    c.rect(12, 52, 8, 6, BRASS[1])
    c.rect(12, 52, 8, 1, BRASS[4])
    c.rect(12, 53, 1, 4, BRASS[3])
    c.rect(13, 53, 6, 4, IRON[0])  # campul placutei, cu randurile de scris
    c.rect(14, 54, 4, 1, BRASS[3])
    c.rect(14, 56, 3, 1, BRASS[2])
    c.rect(11, 58, 10, 1, DSTONE[0])
    # lucarna ingusta, mai sus
    c.rect(15, 46, 2, 4, DSTONE[0])
    c.rect(15, 45, 2, 1, DSTONE[4])
    c.put(15, 47, IRON[1])
    # usa mica, cu cadru de piatra si feronerie
    c.rect(12, 62, 8, 9, DSTONE[4])
    c.rect(13, 63, 6, 8, WOOD[1])
    c.put(13, 63, DSTONE[4])
    c.put(18, 63, DSTONE[3])
    for x in (14, 16, 18):  # scandurile
        c.rect(x, 64, 1, 7, WOOD[2])
    c.rect(13, 66, 6, 1, IRON[1])  # bandajul de fier
    c.put(18, 68, BRASS[4])  # clanta
    c.rect(11, 71, 10, 1, DSTONE[5])  # pragul
    # muschi si un pic de iarba la baza
    for x, y in ((6, 70), (7, 69), (25, 70), (8, 72), (24, 72), (6, 73)):
        c.put(x, y, MOSS[2 if (x + y) % 2 else 3])
    flower_cluster(c, 20, 73, (WHITE_F, YEL_F), w=4)

    outline_trace(c)
    # umbra aruncata la dreapta (lumina vine din stanga-sus): doua pixeli translucizi dupa marginea turnului, pe fiecare rand.
    # Se pune DUPA outline_trace, altfel pixelii cu alfa > 0 i-ar bloca conturul. Pe baraj, din spate, dezlipeste turnul de zid.
    for y in range(16, 74):
        xr = max((x for x in range(c.w) if c.px[y][x][3] > 200), default=None)
        if xr is None:
            continue
        for x in range(xr + 1, min(xr + 3, c.w)):
            if c.px[y][x][3] == 0:
                c.put(x, y, (0, 0, 0, 56))
    return c


# ---------------------------------------------------------------------------------------------
# 2. Memory Wall


def _art(c, x, y, rows, key):
    """Deseneaza un tablou din sir de caractere: fiecare caracter e o culoare din `key`, '.' = nu desena."""
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                c.put(x + i, y + j, key[ch])


def _frame(c, x, y, w, h):
    """Rama de lemn a unui tablou: muchia de sus si din stanga luminate, cea de jos si din dreapta in umbra."""
    c.rect(x, y, w, h, WOOD[1])
    c.rect(x, y, w, 1, WOOD[3])
    c.rect(x, y, 1, h, WOOD[2])
    c.rect(x, y + h - 1, w, 1, WOOD[0])
    c.rect(x + w - 1, y, 1, h, WOOD[0])


SKY, SKY2 = (170, 208, 228, 255), (200, 228, 240, 255)
ART_KEY = {
    "s": SKY, "S": SKY2, "y": WARM[4], "w": WHITE_F, "r": ROOF_TILE[2], "R": ROOF_TILE[1], "b": SLATE[3], "B": SLATE[1],
    "p": PLANK[2], "P": PLANK[4], "d": WOOD[0], "l": WARM[3], "g": LEAF[2], "G": LEAF[3], "h": DSTONE[3], "H": DSTONE[1],
    "v": WATER[2], "V": WATER[3], "f": FOAM[4], "t": TIMBER[1], "c": CREAM[3], "n": TIMBER[3], "o": RED_F,
}
HOUSE = (  # 9x9: o casuta cu acoperis rosu pe un deal, soare si un nor (satul de dinainte)
    "SSSSSSSSS",
    "SwwSSSSyS",
    "SSSSrSSSS",
    "SSSrrrSSS",
    "SSrRrRrSS",
    "SSpppPpSS",
    "gGplpdpGg",
    "gggpppggg",
    "gGgggGggg",
)
VILLAGE = (  # 11x9: satul pe rau, cu doua case si clopotnita
    "SSSSSSSSSSS",
    "SwwSSSSSrSS",
    "SSSSSSSShhS",
    "SSrrrSbbhHS",
    "SSplpSBlhhS",
    "gGpppGBppgG",
    "ggggggggggg",
    "vvVvvvvVvvv",
    "vfvvvvvvfvv",
)
def _net_rows(ox=0, oy=0):
    """6x9: o plasa intinsa pe un par (sus), cu doua plute rosii si o alba (jos). Ochiurile sunt un zabrelaj adevarat in
    diamant: franghia trece pe diagonalele x+y = 0 si x-y = 0 (mod 4), asa ca dreptele se incruciseaza in randuri
    decalate, nu in tabla de sah."""
    rows = ["tttttt"]
    for j in range(6):
        rows.append("".join("n" if (i + ox + j + oy) % 4 == 0 or (i + ox - j - oy) % 4 == 0 else "c" for i in range(6)))
    rows.append("ocwcoc")  # plutele
    rows.append("cccccc")
    return tuple(rows)


NET = _net_rows()


def prop_memory_wall():
    """Memory Wall (64x32): zid scund de piatra, intre doi stalpi, cu o streasina mica de lemn. In zid: un tablou cu o casuta,
    o placuta de alama, panoul mare cu satul pe rau si un tablou cu o plasa; sub ele lumanari pe soclu si flori la picior.
    E zid plin, de piatra, fara picioare si fara hartii: nu seamana cu Village Board."""
    c = C(64, 32)
    rng = Rng(7502)
    soft_shadow(c, 32, 30, 30, 1.6)

    # peretele, intre stalpii de capat
    ashlar(c, rng, lambda y: (2, 62), 8, 26, 2, 62, ch=4, bw=(6, 9), lit=1, dark=2)
    # soclul care iese in fata, cu lumanarile pe el
    c.rect(3, 25, 58, 4, DSTONE[3])
    c.rect(3, 25, 58, 1, DSTONE[5])
    c.rect(3, 28, 58, 1, DSTONE[0])
    for x in range(5, 60, 7):
        c.put(x, 26, DSTONE[2])

    # streasina de lemn: o apa subtire cu sindrila, intre stalpii de capat (care o depasesc), sprijinita pe console
    for i in range(5):
        y = 3 + i
        inset = max(0, 2 - i)
        c.rect(7 + inset, y, 50 - 2 * inset, 1, WOOD[3] if i % 2 == 0 else WOOD[2])
        for x in range(8 + inset + (i % 2) * 2, 57 - inset, 4):
            c.put(x, y, WOOD[1])
    c.rect(7, 8, 50, 1, WOOD[0])
    c.rect(7, 9, 50, 1, (0, 0, 0, 80))  # umbra pe zid
    c.rect(7, 10, 50, 1, (0, 0, 0, 36))
    for kx in (9, 54):  # consolele de sub streasina
        c.rect(kx, 9, 1, 3, WOOD[1])
        c.put(kx + 1, 9, WOOD[2])
    for x, n in ((19, 3), (32, 2), (47, 3)):  # iedera atarnata din streasina
        for k in range(n):
            c.put(x, 9 + k, LEAF[1 if k % 2 else 2])
        c.put(x + 1, 9, LEAF[3])

    # stalpii de capat: cu un ton mai deschisi decat zidul, cu coping de piatra care se ridica cu un rand deasupra streasinii,
    # ca sa incadreze tablourile; la interior, cate un rost de 1 px
    for px0 in (2, 58):
        ashlar(c, rng, lambda y, px0=px0: (px0, px0 + 4), 4, 26, px0, px0 + 4, ch=5, bw=(4, 4), lit=1, dark=1, base=(3, 4))
        c.rect(px0 - 1, 2, 6, 1, DSTONE[5])  # coping-ul, cu 1 px mai lat decat stalpul
        c.rect(px0 - 1, 3, 6, 1, DSTONE[3])
    c.rect(6, 4, 1, 22, DSTONE[1])  # rosturile dinspre zid
    c.rect(57, 4, 1, 22, DSTONE[1])

    # tablourile si placutele: toate cu varful la y 12
    _frame(c, 7, 12, 11, 11)  # casuta
    _art(c, 8, 13, HOUSE, ART_KEY)
    # placuta de alama: fond inchis, rama de alama, un clopotel (3x3) ca titlu si doua randuri de scris, aliniate la stanga
    c.rect(21, 14, 9, 9, BRASS[1])
    c.rect(21, 14, 9, 1, BRASS[4])
    c.rect(21, 14, 1, 9, BRASS[3])
    c.rect(22, 15, 7, 7, IRON[0])
    # clopotelul (3x3): creastet de 1 px si doua randuri pline; coloana din dreapta in umbra
    c.put(25, 16, BRASS[4])
    c.rect(24, 17, 3, 2, BRASS[4])
    c.rect(26, 17, 1, 2, BRASS[2])
    c.put(25, 17, BRASS[3])
    c.put(25, 18, BRASS[3])
    for x in (23, 24, 26, 27):  # randul de scris: doua cuvinte
        c.put(x, 20, BRASS[3])
    for x in (23, 24, 25):  # al doilea rand, mai scurt
        c.put(x, 21, BRASS[2])
    _frame(c, 33, 12, 13, 11)  # satul pe rau
    _art(c, 34, 13, VILLAGE, ART_KEY)
    _frame(c, 49, 12, 8, 11)  # plasa
    _art(c, 50, 13, NET, ART_KEY)
    # placutele mici de sub tablouri
    for x, w in ((9, 7), (36, 7), (51, 4)):
        c.rect(x, 23, w, 1, BRASS[3])
        c.put(x, 23, BRASS[4])
    # lumanari pe soclu, in golurile dintre tablouri
    for x in (19, 31, 47):
        candle(c, x, 25)
    # un ghiveci mic cu flori, pe pamant, in umbra din fata soclului (baza la randul 30), intre primele doua buchete
    c.rect(15, 29, 4, 2, ROOF_TILE[1])
    c.rect(15, 29, 4, 1, ROOF_TILE[2])
    c.put(15, 29, ROOF_TILE[3])
    c.put(15, 28, PINK_F)
    c.put(16, 27, WHITE_F)
    c.put(16, 28, LEAF[2])
    c.put(17, 28, LEAF[2])
    c.put(18, 28, PINK_F)
    # flori la picior, in fata soclului
    flower_cluster(c, 8, 30, (RED_F, WHITE_F), w=6)
    flower_cluster(c, 22, 30, (YEL_F, WHITE_F), w=5)
    flower_cluster(c, 37, 30, (BLUE_F, WHITE_F), w=5)
    flower_cluster(c, 51, 30, (PINK_F, YEL_F), w=6)

    outline_trace(c)
    return c


# ---------------------------------------------------------------------------------------------
# 3. Casutele


COTTAGES = {
    # roof: rampa olanelor; plaster: umplutura peretilor; accent: obloanele; door: usa; flowers: ladita cu flori;
    # mirror: usa si fereastra schimbate; chimney: x-ul cosului; extra: o mica insusire proprie;
    # layout: lipsa = usa + fereastra, "centre" = usa la mijloc, intre doua ferestre mici
    1: dict(roof=SLATE, plaster=PLASTER_CREAM, accent=ramp(190, 0.46, 0.50, hue_shift=8), door=WOOD, flowers=(RED_F, WHITE_F),
            mirror=False, chimney=21, extra="barrel"),
    2: dict(roof=ROOF_TILE, plaster=PLASTER_SAND, accent=ramp(130, 0.40, 0.40, hue_shift=8), door=ramp(190, 0.46, 0.46, hue_shift=8),
            flowers=(YEL_F, WHITE_F), mirror=True, chimney=13, extra="logs"),
    3: dict(roof=MOSSROOF, plaster=PLASTER_MIST, accent=ramp(8, 0.52, 0.52, hue_shift=6), door=WOOD, flowers=(BLUE_F, WHITE_F, PINK_F),
            mirror=False, chimney=18, extra="fence", layout="centre"),
}


def _log_end(c, x, y):
    """Un bustean vazut pe capat (4x4): disc cu colturile taiate (outline_trace il rotunjeste), coaja de lemn pe margine,
    fata taiata deschisa in mijloc si un punct de miez inchis. Lumina din stanga-sus: coaja de sus/stanga mai deschisa,
    cea de jos/dreapta in umbra, ca fiecare disc sa se desprinda de vecini."""
    for dx, dy, t in (
        (1, 0, WOOD[3]), (2, 0, WOOD[3]),  # coaja de sus
        (0, 1, WOOD[3]), (0, 2, WOOD[2]),  # coaja din stanga
        (3, 1, WOOD[1]), (3, 2, WOOD[0]),  # coaja din dreapta
        (1, 3, WOOD[1]), (2, 3, WOOD[0]),  # coaja de jos
        (1, 1, PLANK[4]), (2, 1, PLANK[3]), (1, 2, PLANK[3]),  # fata taiata
        (2, 2, WOOD[1]),  # miezul
    ):
        c.put(x + dx, y + dy, t)


def _cottage(n):
    cfg = COTTAGES[n]
    c = C(40, 34)
    rng = Rng(7510 + n)
    roof, plaster, accent, door_t = cfg["roof"], cfg["plaster"], cfg["accent"], cfg["door"]
    mir = cfg["mirror"]

    def mx(x, w=1):
        """Oglindeste un x (cu latimea w) in jurul centrului casei, cand varianta o cere."""
        return 40 - x - w if mir else x

    soft_shadow(c, 20, 31, 18, 2)
    # soclul de piatra
    ashlar(c, rng, lambda y: (4, 36), 27, 32, 4, 36, ch=3, bw=(5, 7), lit=1, dark=3)
    c.rect(4, 27, 32, 1, DSTONE[4])

    # peretii: tencuiala cu barne aparente
    c.rect(5, 15, 30, 12, plaster[2])
    for y in range(17, 27, 3):  # pete usoare in tencuiala
        for x in range(7 + (y % 2) * 3, 34, 6):
            c.put(x, y, plaster[3])
    c.rect(5, 15, 30, 2, plaster[1])  # umbra streasinii
    c.rect(5, 26, 30, 1, TIMBER[1])  # talpa
    for px0 in (5, 33):  # stalpii din colturi
        c.rect(px0, 15, 2, 12, TIMBER[2])
        c.rect(px0, 15, 1, 12, TIMBER[3])
    centre = cfg.get("layout") == "centre"
    if not centre:
        c.rect(mx(20, 2), 15, 2, 12, TIMBER[2])  # stalpul dintre fereastra si usa
        c.rect(mx(20, 2), 15, 1, 12, TIMBER[3])
        # contrafisa in capatul liber
        far = mx(31, 2)
        line(c, far, 25, far + 1, 20, TIMBER[2], 1)

    fl = cfg["flowers"]
    if centre:
        # doua ferestre mici aprinse, de-o parte si de alta a usei: obloane de 1 px, rama 5x8, sticla 3x6 cu o traversa
        for x0 in (9, 26):  # rama (x0..x0+4); golul dintre stalp si toc are 9 px, cu cate 1 px de tencuiala la margini
            c.rect(x0 - 1, 18, 1, 6, accent[3])  # obloanele
            c.rect(x0 + 5, 18, 1, 6, accent[1])
            c.rect(x0, 17, 5, 8, TIMBER[0])  # rama
            c.rect(x0 + 1, 18, 3, 6, WARM[3])
            c.rect(x0 + 1, 18, 3, 2, WARM[4])
            c.rect(x0 + 1, 22, 3, 1, WARM[2])
            c.rect(x0 + 1, 21, 3, 1, TIMBER[1])  # traversa
            c.put(x0 + 1, 18, (255, 250, 210, 255))
            c.rect(x0 - 1, 24, 7, 3, WOOD[2])  # ladita cu flori
            c.rect(x0 - 1, 24, 7, 1, WOOD[4])
            c.rect(x0 - 1, 26, 7, 1, WOOD[0])
            c.put(x0 + 1, 23, fl[0])
            c.put(x0 + 2, 23, LEAF[1])
            c.put(x0 + 3, 23, fl[1 % len(fl)])
            c.put(x0 + 2, 22, LEAF[2])
    else:
        # fereastra aprinsa, cu obloane
        wx = mx(9, 8)
        c.rect(wx - 2, 18, 2, 7, accent[2])  # obloanele
        c.rect(wx + 8, 18, 2, 7, accent[1])
        c.rect(wx - 2, 18, 1, 7, accent[3])
        c.rect(wx, 17, 8, 8, TIMBER[0])  # rama
        c.rect(wx + 1, 18, 6, 6, WARM[3])
        c.rect(wx + 1, 18, 6, 2, WARM[4])
        c.rect(wx + 1, 22, 6, 2, WARM[2])
        c.rect(wx + 3, 18, 2, 6, TIMBER[1])  # sprosul
        c.rect(wx + 1, 21, 6, 1, TIMBER[1])
        c.put(wx + 2, 19, (255, 250, 210, 255))
        # ladita cu flori sub fereastra
        c.rect(wx - 1, 24, 10, 3, WOOD[2])
        c.rect(wx - 1, 24, 10, 1, WOOD[4])
        c.rect(wx - 1, 26, 10, 1, WOOD[0])
        for k in range(5):
            c.put(wx + k * 2 - 0, 23, LEAF[2])
            c.put(wx + k * 2 - 0, 22, fl[k % len(fl)])
        for k in range(4):
            c.put(wx + 1 + k * 2, 23, LEAF[1])

    # usa, cu arcul tesit, clanta de alama si piatra de prag
    dx = 17 if centre else mx(24, 6)  # centrata: toc x16..23, simetric fata de mijlocul casei (19,5)
    c.rect(dx - 1, 18, 8, 9, TIMBER[0])  # toc
    c.rect(dx, 19, 6, 8, door_t[2])
    c.rect(dx, 19, 6, 1, door_t[3])
    c.put(dx, 19, TIMBER[0])
    c.put(dx + 5, 19, TIMBER[0])
    for k in (1, 3):
        c.rect(dx + k, 20, 1, 7, door_t[1])
    c.rect(dx, 22, 6, 1, door_t[1])
    c.put(dx + (1 if mir else 4), 24, BRASS[4])
    c.rect(dx - 2, 27, 10, 2, DSTONE[4])  # pragul, mai lat decat usa
    c.rect(dx - 2, 27, 10, 1, DSTONE[5])
    if not centre:  # felinarul de langa usa, aprins (la casuta centrata nu mai e loc intre fereastra si stalp)
        lx = mx(32, 2) if not mir else mx(31, 2)
        c.rect(lx, 19, 2, 1, IRON[1])
        c.rect(lx, 20, 2, 3, WARM[3])
        c.put(lx, 20, WARM[4])
        c.put(lx, 23, IRON[1])
        c.put(lx + 1, 23, IRON[1])

    # acoperisul de olane, in vedere frontala, cu streasina larga
    cx0, cx1 = 12, 28
    # panta 1:1 exacta (cate un pixel pe rand, fara popas), prinsa la 1 si 39 pe ultimele randuri
    tile_roof(c, 13, lambda i: max(1, cx0 - i), lambda i: min(39, cx1 + i), 3, roof, tile=4)
    c.rect(cx0, 3, cx1 - cx0, 1, roof[4])  # coama
    c.rect(cx0, 4, cx1 - cx0, 1, roof[3])
    # umbra streasinii pe perete
    c.rect(5, 16, 30, 1, (0, 0, 0, 60))
    c.rect(5, 17, 30, 1, (0, 0, 0, 28))

    # cosul de piatra, cu gura inchisa la culoare; capacul la randurile 1-2 (randul 0 ramane liber, ca sa-l poata contura
    # outline_trace), corpul de la randul 3
    cx = cfg["chimney"]
    for y in range(3, 12):
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
    c.rect(cx, 11, 6, 1, (0, 0, 0, 70))  # umbra de la baza, pe olane

    # insusirea proprie a fiecarei casute
    if cfg["extra"] == "barrel":  # butoi de ploaie langa stalpul de colt
        c.rect(1, 25, 5, 7, WOOD[2])  # baza la randul 31 = linia pamantului (talpa soclului)
        c.rect(1, 25, 1, 7, WOOD[4])
        c.rect(5, 25, 1, 7, WOOD[0])
        c.rect(1, 27, 5, 1, IRON[1])
        c.rect(1, 30, 5, 1, IRON[1])
        c.rect(2, 25, 3, 1, WATER[2])  # apa, intre doua pixeli de margine de lemn (x1 si x5)
        c.put(2, 25, WATER[4])  # sclipirea
        c.put(1, 25, WOOD[3])
        c.put(5, 25, WOOD[1])
    elif cfg["extra"] == "logs":  # o stiva de busteni taiati, vazuti pe capat, in fata soclului (3 jos, 2 deasupra)
        for lx, ly in ((27, 28), (31, 28), (35, 28), (29, 25), (33, 25)):  # randul de jos primul, cel de sus il acopera
            _log_end(c, lx, ly)
        c.rect(27, 32, 12, 1, (0, 0, 0, 50))  # umbra de sub stiva, pe pamant
    elif cfg["extra"] == "fence":  # un gard scund de nuiele si o floare inalta, in fata soclului
        c.rect(29, 30, 10, 1, WOOD[2])
        for px in range(29, 39, 2):
            c.rect(px, 28, 1, 5, WOOD[3])
            c.put(px, 28, WOOD[4])
        c.rect(36, 24, 1, 5, LEAF[2])
        c.rect(35, 23, 3, 2, PINK_F)
        c.put(36, 23, WHITE_F)

    outline_trace(c)
    return c


def prop_dam_cottage_1():
    """Casuta 1 (40x34): acoperis de ardezie albastra, tencuiala crem, obloane albastre, ladita cu flori rosii, un butoi
    de ploaie la colt; usa la dreapta, cosul la dreapta."""
    return _cottage(1)


def prop_dam_cottage_2():
    """Casuta 2 (40x34): acoperis de olane rosii, tencuiala de nisip, obloane verzi, usa albastra, flori galbene, o stiva de busteni;
    planul e oglindit (usa la stanga, fereastra la dreapta, cosul la stanga)."""
    return _cottage(2)


def prop_dam_cottage_3():
    """Casuta 3 (40x34): acoperis verde de muschi, tencuiala alb-albastruie, obloane rosii, flori albastre si roz, un gard
    scund de nuiele cu o floare inalta in dreapta. Singura cu usa la mijloc, intre doua ferestre mici aprinse (fara felinar
    si fara contrafisa: pe fatada nu mai e loc)."""
    return _cottage(3)


SPRITES = {
    "prop_old_bells": prop_old_bells,
    "prop_memory_wall": prop_memory_wall,
    "prop_dam_cottage_1": prop_dam_cottage_1,
    "prop_dam_cottage_2": prop_dam_cottage_2,
    "prop_dam_cottage_3": prop_dam_cottage_3,
}
SIZES = {
    "prop_old_bells": (32, 80),
    "prop_memory_wall": (64, 32),
    "prop_dam_cottage_1": (40, 34),
    "prop_dam_cottage_2": (40, 34),
    "prop_dam_cottage_3": (40, 34),
}


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


def preview(out_dir):
    imgs = {name: to_image(fn()) for name, fn in SPRITES.items()}
    ground = Image.open(os.path.join(SPR, "prop_dam_ground.png")).convert("RGBA")
    bg = (86, 128, 64, 255)
    S = 4
    pad = 14
    lab = font(8)
    # randul de sus: cele cinci, la x4, pe verde, cu eticheta
    sizes = [(n, im.width * S, im.height * S) for n, im in imgs.items()]
    top_w = sum(w for _, w, _ in sizes) + pad * (len(sizes) + 1)
    top_h = max(h for _, _, h in sizes) + 2 * pad + 14
    top = Image.new("RGBA", (top_w, top_h), bg)
    d = ImageDraw.Draw(top)
    x = pad
    for name, im in imgs.items():
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        top.alpha_composite(big, (x, top_h - pad - big.height))
        d.text((x, 4), f"{name.replace('prop_', '')} {im.width}x{im.height}", font=lab, fill=(255, 255, 255, 255))
        x += big.width + pad
    # randul de jos: cele trei casute pe pamantul copt (1 px de arta = 1 px; apoi x3 = scara din joc: 1 px de arta = 3 de lume)
    def stage(box, items):
        crop = ground.crop(box).copy()
        for name, wx, wy in items:  # (nume, x lume, y lume = baza)
            im = imgs[name]
            crop.alpha_composite(im, (round(wx / 3) - box[0] - im.width // 2, round(wy / 3) - box[1] - im.height))
        return crop.resize((crop.width * 3, crop.height * 3), Image.NEAREST)

    cott = stage((50, 482, 240, 560), [(f"prop_dam_cottage_{i + 1}", 290 + 140 * i, 1620) for i in range(3)])
    tower = stage((196, 230, 316, 330), [("prop_old_bells", 760, 960)])
    mem = stage((190, 400, 316, 470), [("prop_memory_wall", 760, 1340)])
    # comparatia cu desenele vechi (x3): trebuie sa se vada ca sunt altceva
    def strip(pairs):
        ims = [(Image.open(os.path.join(SPR, n + ".png")).convert("RGBA") if isinstance(n, str) else n) for n in pairs]
        w_ = sum(i.width * 3 + 10 for i in ims) + 10
        h_ = max(i.height * 3 for i in ims) + 20
        sp = Image.new("RGBA", (w_, h_), bg)
        x_ = 10
        for i in ims:
            sp.alpha_composite(i.resize((i.width * 3, i.height * 3), Image.NEAREST), (x_, h_ - 10 - i.height * 3))
            x_ += i.width * 3 + 10
        return sp

    cmp_bells = strip([imgs["prop_old_bells"], "prop_bell", "prop_works_bell", "prop_mill_bell"])
    cmp_board = strip([imgs["prop_memory_wall"], "prop_village_board"])
    cmp_huts = strip([imgs["prop_dam_cottage_1"], imgs["prop_dam_cottage_2"], "prop_hut_porter_2", "prop_runner_hut_2"])
    bottom_w = cott.width + max(tower.width, cmp_bells.width) + pad * 3
    bottom_h = max(cott.height + cmp_huts.height + cmp_board.height + pad * 3, tower.height + mem.height + pad) + 2 * pad + 12
    bottom_h = max(bottom_h, tower.height + mem.height + pad * 3 + 12 + cmp_bells.height)
    bottom = Image.new("RGBA", (bottom_w, bottom_h), (28, 32, 36, 255))
    bd = ImageDraw.Draw(bottom)
    bd.text((pad, 4), "cottages at 1x on dam_ground (x3 = in game)", font=lab, fill=(230, 230, 230, 255))
    bottom.alpha_composite(cott, (pad, pad + 10))
    bd.text((pad * 2 + cott.width, 4), "old bells + memory wall at their places", font=lab, fill=(230, 230, 230, 255))
    bottom.alpha_composite(tower, (pad * 2 + cott.width, pad + 10))
    bottom.alpha_composite(mem, (pad * 2 + cott.width, pad * 2 + 10 + tower.height))
    bd.text((pad, pad * 2 + 10 + cott.height - 2), "vs the old huts / board / bells (x3)", font=lab, fill=(230, 230, 230, 255))
    yy = pad * 2 + 12 + cott.height + 10
    bottom.alpha_composite(cmp_huts, (pad, yy))
    yy += cmp_huts.height + 4
    bottom.alpha_composite(cmp_board, (pad, yy))
    bottom.alpha_composite(cmp_bells, (pad * 2 + cott.width, pad * 3 + 10 + tower.height + mem.height))
    # turnul pe zidul din grupul "wall" (prop_dam_wall, 80x189; baza turnului la (760, 960) = centrul x 40, jos 189), daca exista:
    # arata daca fusul se desprinde de piatra din spate
    wall_tower = None
    wall_path = os.path.join(out_dir, "prop_dam_wall.png")
    if os.path.exists(wall_path):
        wall = Image.open(wall_path).convert("RGBA")
        comp = Image.new("RGBA", wall.size, bg)
        comp.alpha_composite(wall)
        comp.alpha_composite(imgs["prop_old_bells"], (40 - 16, wall.height - 80))
        comp = comp.crop((0, wall.height - 110, wall.width, wall.height))
        wall_tower = comp.resize((comp.width * 3, comp.height * 3), Image.NEAREST)
    extra_w = (wall_tower.width + pad) if wall_tower else 0
    W_ = max(top.width + extra_w, bottom.width)
    sheet = Image.new("RGBA", (W_, top.height + bottom.height), (28, 32, 36, 255))
    sheet.alpha_composite(top, (0, 0))
    if wall_tower:
        sheet.alpha_composite(wall_tower, (top.width + pad, 14))
        ImageDraw.Draw(sheet).text((top.width + pad, 2), "old bells on prop_dam_wall (x3)", font=lab, fill=(230, 230, 230, 255))
    sheet.alpha_composite(bottom, (0, top.height))
    path = os.path.join(out_dir, "town_preview.png")
    sheet.save(path)
    return path


def main():
    out = SCRATCH
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        print("  scris", name, f"{c.w}x{c.h}")
    print("previzualizare:", preview(SCRATCH))


if __name__ == "__main__":
    main()
