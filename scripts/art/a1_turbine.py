#!/usr/bin/env python3
"""[D75, lotul A1, grupul "turbine"] Fata turbinei BARAJULUI, desenata pe aceeasi grila de 3 px ca zidul de piatra.
Scrie DOAR in scratchpad-ul sesiunii (--out); nimic nu intra in assets/sprites si nimic nu se urca.

Pana acum jocul punea in gura boltii turbina Erei 3 (prop_turbine, 48x48, pixeli de 1 px de lume) la 48x48 de lume: pixelii ei
erau de trei ori mai fini decat piatra si arata ca un abtibild. Aici e turbina barajului insusi, la grila zidului (1 px de arta
= 3 px de lume).

  prop_dam_turbine       16x20  rotorul vazut prin bolta, dinspre aval: roata de fier ud cu 6 palete curbe, butucul de cupru/alama
                                cu lumina calda a generatorului din spate (guler de cupru stins + goluri calde langa butuc), spuma
                                luminoasa la intalnirea cu apa de aval. Lumina din stanga-sus. In joc: coltul stanga-sus la coloana 64,
                                randul 102 al zidului (lume 831 x 699), deci acopera coloanele 64-79 si randurile 102-121 ale zidului.
                                Gura boltii e libera intre coloanele 66 si 77 (cele doua coloane de la fiecare margine sunt piatra
                                zidului): roata sta in coloanele 2-13 ale sprite-ului; in jurul ei e transparent, ca sa se vada
                                interiorul intunecat al boltii. Fara pixeli semitransparenti: alfa exista doar in jurul rotii.
  prop_dam_turbine_spin  64x20  aceeasi roata, 4 cadre de 16x20: paletele inainteaza cu un sfert din distanta dintre ele pe cadru
                                (6 palete, deci 15 grade pe cadru; dupa 4 cadre se leaga fara salt). Butucul si gulerul (toti pixelii
                                cu centrul la r <= R_HUB) sunt identici in toate cadrele; in fiecare cadru se vad exact 6 fante curate
                                (golurile dintre palete) de cate 4 pixeli. Spuma si dungile apei de aval ciclu de 2 cadre: in cadrele
                                2 si 4, perechile W0/W1 de pe randul spumei isi schimba locul, iar dungile coboara un rand; cadrul 1
                                e identic cu prop_dam_turbine. Sensul: invers acelor de ceasornic, ca prop_turbine_spin din Era 3.

Aceleasi reguli ca restul conductei: culorile din listele IRON / COPPER / BRASS (Wire Works), CH si W (zidul), plus o singura culoare
calculata (WARM_GAP), 17 in toata foaia; niciodata negru pur; lumina din stanga-sus; un singur contur desenat de rotor (inelul), nu trasat.
Parametrii rotii (COVER, SWEEP, R_RIM, PHASE0) nu sunt alesi din ochi: sunt cautati pe o grila ca toate cele 4 cadre sa dea exact 6 fante
separate de cate 4 pixeli (cadrele 1 si 3 sunt una si aceeasi roata rotita cu 90 de grade, la fel 2 si 4, deci conteaza doua structuri).

Previzualizarea (turbine_preview.png) compune scena din prop_dam_wall / _spill / _foam, citite din --out (sau din scratchpad-ul A1).

Rulare: python3 scripts/art/a1_turbine.py [--out DIR]
"""
import argparse
import math
import os
import sys

sys.dont_write_bytecode = True  # scriptul scrie doar in scratchpad: nici un __pycache__ in repo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

from buildings import C, png  # noqa: E402
from palette import mix  # noqa: E402
from d67_works import BRASS, COPPER, GLASS, IRON  # noqa: E402
import a1_wall as AW  # noqa: E402  (doar geometria si incarcarea sprite-urilor pentru previzualizare)

D = 3  # pixeli de lume pe pixel de arta
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
SCRATCH = AW.SCRATCH
OUTDIR = SCRATCH  # unde se scriu sprite-urile; main() il schimba dupa --out


def src_png(name):
    """Zidul, panza si spuma pentru previzualizare: din --out daca sunt acolo, altfel din scratchpad-ul A1."""
    p = os.path.join(OUTDIR, name + ".png")
    return Image.open(p if os.path.exists(p) else os.path.join(SCRATCH, name + ".png")).convert("RGBA")

# ---- locul in zid (coloana 64, randul 102 = lume 831 x 699) -------------------------------------------------------------------
TW, TH = 16, 20
AT_COL, AT_ROW = 64, 102
FRAMES = 4

# ---- geometria rotii, in coordonate continue de sprite (centrul pixelului x este x + 0.5) -------------------------------------
# gura boltii: coloanele 2-13 ale sprite-ului (12 px), deci centrul pe x = 8.0 si raza 6.0 ating cele doua coloane de piatra
CX, CY = 8.0, 8.0
R_OUT = 6.0  # muchia exterioara a inelului
R_RIM = 4.9  # unde incepe inelul (grosime ~1 px)
R_HUB = 2.2  # butucul si gulerul lui: toti pixelii cu centrul la r <= 2.2 (patratul de 4x4 din mijloc, colturile diagonale incluse)
N_BLADES = 6
SWEEP = 0.8  # cat se rasucesc paletele de la radacina la varf (radiani)
COVER = 0.60  # cat din distanta dintre palete e palet (restul: golul din spate, o fanta curata de ~1 px)
PHASE0 = math.radians(10.0)  # faza cadrului 1 (= sprite-ul fix)
WATERLINE = 13  # primul rand de apa de aval: roata intra in ea cu ultimul rand
WARM_R = 2.9  # golurile mai aproape de butuc de atat prind lumina calda a generatorului

# ---- paleta: totul din listele IRON / COPPER / BRASS / GLASS / CH (zid) / W (apa), plus o singura culoare derivata ---------------
CH = AW.CH
COOL_GAP = CH[1]  # golul dintre palete: canalul intunecat al boltii, acelasi pe care il vezi deasupra rotii
WARM_GAP = mix(COPPER[0], CH[0], 0.35)  # golul de langa butuc: cupru stins in canal; singura culoare calculata, o data
W0, W1, W2, W3, W4 = AW.W0, AW.W1, AW.W2, AW.W3, AW.W4  # apa/spuma, ca in zid


def clamp(v, a, b):
    return max(a, min(b, v))


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def wrap(a):
    """Unghi in (-pi, pi]."""
    return (a + math.pi) % (2 * math.pi) - math.pi


# ---------------------------------------------------------------------------------------------------------------------------
# rotorul
# ---------------------------------------------------------------------------------------------------------------------------
LIGHT = (-0.7071, -0.7071)  # spre lumina (stanga-sus), in coordonate de ecran (y in jos)


def light_term(dx, dy, r):
    """-1 .. +1: cat de aproape e punctul de partea luminata (stanga-sus) a rotii."""
    if r < 1e-6:
        return 0.0
    return clamp((dx * LIGHT[0] + dy * LIGHT[1]) / (R_OUT * 0.9), -1.0, 1.0)


def hub_colour(dx, dy):
    """Butucul: blocul de 2x2 pixeli din centru, un dom de cupru cu capac de alama luminat din stanga-sus; identic in toate cadrele."""
    if dx < 0:
        return BRASS[4] if dy < 0 else COPPER[3]
    return COPPER[4] if dy < 0 else COPPER[2]


# cele patru colturi diagonale ale gulerului (centrul la r = 2.12) sunt culori FIXE: nu sunt nici palet, nici gol, deci nu se rotesc
# [directorul A1] colturile sunt din fier, ca butucul de cupru sa para rotund (un bloc patrat de cupru citea ca o cutie)
COLLAR_CORNERS = {(-1, -1): IRON[3], (1, -1): IRON[2], (-1, 1): IRON[2], (1, 1): IRON[1]}


def collar_colour(dx, dy, r):
    """Gulerul butucului (cei doisprezece pixeli din jurul blocului, patratul 4x4 minus miezul): cupru inchis, mai luminos in stanga-sus,
    cu colturile fixe; identic in toate cadrele. Radacinile paletelor ies de sub el."""
    if abs(dx) > 1.0 and abs(dy) > 1.0:
        return COLLAR_CORNERS[(1 if dx > 0 else -1, 1 if dy > 0 else -1)]
    L = light_term(dx, dy, r)
    return COPPER[1] if L > 0.15 else (COPPER[0] if L > -0.1 else WARM_GAP)


def rim_colour(dx, dy, r):
    """Inelul de fier: gros de ~1 px, luminat in stanga-sus, in umbra jos-dreapta (dar nu mai jos de IRON[1], ca sa se desprinda de
    canalul intunecat). Doar trepte din IRON; reflexele de apa se pun separat (draw_glints)."""
    L = light_term(dx, dy, r)
    # [directorul A1] cel mai inchis pas al inelului e IRON[2]: IRON[1] se pierdea pe canalul boltii (randurile 9-12)
    return IRON[clamp(int(round(2.0 + 1.9 * L)), 2, 4)]


def blade_at(theta, r, phase):
    """u in [-1, 1] peste latimea paletei daca punctul e pe o palet, altfel None."""
    s = (r - R_HUB) / (R_RIM - R_HUB)
    spacing = 2 * math.pi / N_BLADES
    centre = phase + SWEEP * s
    off = wrap(theta - centre)
    off = (off + spacing / 2) % spacing - spacing / 2  # fata de cea mai apropiata palet
    hw = COVER * spacing / 2
    if abs(off) <= hw:
        return off / hw
    return None


def blade_colour(dx, dy, r, theta, u):
    """Paleta: fier ud, trepte pure din IRON (fara tenta calda); muchia dinspre lumina prinde o treapta mai sus, cea opusa una mai jos."""
    L = light_term(dx, dy, r)
    # tangenta cercului in acest punct; muchia paletei dinspre lumina e cea a carei normala priveste spre lumina
    tx, ty = -math.sin(theta), math.cos(theta)
    edge = (tx * LIGHT[0] + ty * LIGHT[1]) * u  # >0: muchia luminata
    idx = clamp(int(round(2.5 + 0.8 * L + 1.5 * edge)), 1, 3)
    if edge > 0.55 and L > 0.1:
        idx = 4  # reflexul muchiei dinspre lumina, doar pe partea luminata a rotii
    return IRON[idx]


def kind_at(px, py, phase):
    """Ce e in punctul (px, py) al rotii: 'rim' (inel), 'blade' (palet), 'gap' (gol) sau None (in afara rotii)."""
    dx, dy = px - CX, py - CY
    r = math.hypot(dx, dy)
    if r > R_OUT:
        return None
    if r >= R_RIM:
        return "rim"
    return "blade" if blade_at(math.atan2(dy, dx), r, phase) is not None else "gap"


def wheel_pixel(x, y, phase):
    """Un pixel al rotii. Butucul si gulerul se decid pe centrul pixelului (identice in toate cadrele). Restul: vot majoritar pe 3x3
    subpuncte asupra TIPULUI (inel / palet / gol), apoi o singura culoare pe tip, fara amestecuri: inel si palet din IRON, golul
    cald (WARM_GAP) la r < WARM_R, altfel golul rece (COOL_GAP)."""
    cx, cy = x + 0.5, y + 0.5
    dx, dy = cx - CX, cy - CY
    r = math.hypot(dx, dy)
    if r <= 1.0:
        return hub_colour(dx, dy)
    if r <= R_HUB:
        return collar_colour(dx, dy, r)
    votes = {}
    us = []
    for sy in (0.17, 0.5, 0.83):
        for sx in (0.17, 0.5, 0.83):
            k = kind_at(x + sx, y + sy, phase)
            votes[k] = votes.get(k, 0) + 1
            if k == "blade":
                px, py = x + sx - CX, y + sy - CY
                us.append(blade_at(math.atan2(py, px), math.hypot(px, py), phase))
    if votes.get(None, 0) >= 5:
        return None
    centre = kind_at(cx, cy, phase)
    kind = max((k for k in votes if k is not None), key=lambda k: (votes[k], k == centre))
    if kind == "rim":
        return rim_colour(dx, dy, r)
    if kind == "gap":
        # [directorul A1] golurile de langa guler raman reci: calde, se roteau cu paletele si halo-ul pulsa intre cadre
        return COOL_GAP
    return blade_colour(dx, dy, r, math.atan2(dy, dx), sum(us) / len(us))


def draw_wheel(c, phase):
    for y in range(TH):
        for x in range(TW):
            col = wheel_pixel(x, y, phase)
            if col is not None:
                c.put(x, y, col)


# apa de aval la baza rotii, in limba zidului: dungi orizontale OPACE de 2-3 px (cum e apa lui: W1/W0 peste W3), fara punct
# semitransparent; intre dungi se vede canalul boltii. Randul 13 e pata de spuma sub roata (identica in cadrele 1 si 2; in 3 si 4
# W0/W1 isi schimba locul pe coloanele 5-6 si 9-10); dungile de mai jos coboara un rand in cadrele 3 si 4 (cate doua cadre, ca spuma zidului).
FOAM_ROW = (  # (coloana, culoare) pe randul WATERLINE, cadrele 1 si 2
    (4, W2), (5, W1), (6, W0), (7, W0), (8, W0), (9, W0), (10, W1), (11, W2),
)
FOAM_ROW_BOB = (  # aceleasi coloane, cadrele 3 si 4
    (4, W2), (5, W0), (6, W1), (7, W0), (8, W0), (9, W1), (10, W0), (11, W2),
)
WAKE = (  # (rand, coloana stanga, coloana dreapta, culoare), cadrele 1 si 2
    (14, 4, 6, W1), (14, 9, 11, W1),
    (15, 3, 5, W2), (15, 10, 12, W2),
    (16, 5, 6, W3), (16, 9, 10, W3),
    (17, 2, 3, CH[4]), (17, 12, 13, CH[4]),
    (18, 7, 8, CH[4]),
)


def draw_water(c, bob):
    """Apa de aval: roata intra in apa cu ultimul rand (randul WATERLINE e spuma, nu fier). `bob` = 0 in cadrele 1 si 2, 1 in 3 si 4:
    pata de spuma isi schimba perechile W0/W1, iar dungile coboara un rand. Totul opac."""
    for x, col in FOAM_ROW_BOB if bob else FOAM_ROW:
        c.put(x, WATERLINE, col)
    for y, x0, x1, col in WAKE:
        for x in range(x0, x1 + 1):
            if y + bob < TH:
                c.put(x, y + bob, col)


def draw_glints(c):
    """Reflexe de apa pe inelul de fier, in stanga-sus (unde bate lumina): trei puncte pe inel, fixe, identice in toate cadrele."""
    for (x, y), col in (((4, 4), W1), ((5, 3), W2), ((3, 5), W2)):
        if c.px[y][x][3]:
            c.px[y][x] = rgba(col)


def turbine(phase=0.0, bob=0):
    c = C(TW, TH)
    draw_wheel(c, phase)
    draw_glints(c)
    draw_water(c, bob)
    return c


def turbine_still():
    return turbine(PHASE0, 0)


STEP = -2 * math.pi / N_BLADES / FRAMES  # un sfert din distanta dintre palete pe cadru, invers acelor de ceasornic


def turbine_spin():
    c = C(TW * FRAMES, TH)
    for f in range(FRAMES):
        # [directorul A1] dungile apei coboara in cadrele 3 si 4 (cate 0,25 s la 8 cadre pe secunda, ca spuma zidului)
        fr = turbine(PHASE0 + f * STEP, (f // 2) % 2)
        for y in range(TH):
            for x in range(TW):
                c.px[y][f * TW + x] = fr.px[y][x]
    return c


SPRITES = {"prop_dam_turbine": turbine_still, "prop_dam_turbine_spin": turbine_spin}
SIZES = {"prop_dam_turbine": (16, 20), "prop_dam_turbine_spin": (64, 20)}


# ---------------------------------------------------------------------------------------------------------------------------
# previzualizarea
# ---------------------------------------------------------------------------------------------------------------------------
def to_image(c):
    img = Image.new("RGBA", (c.w, c.h))
    img.putdata([p for row in c.px for p in row])
    return img


def font(n):
    try:
        return ImageFont.truetype(AW.FONT, n)
    except OSError:
        return ImageFont.load_default()


BG = (86, 128, 64, 255)
LABEL = (244, 238, 220, 255)


def arch_backdrop():
    """Interiorul boltii asa cum e in zid (coloanele 64-79, randurile 102-121), ca fundal sub sprite."""
    wall = src_png("prop_dam_wall")
    return wall.crop((AT_COL, AT_ROW, AT_COL + TW, AT_ROW + TH))


def sprite_tile(im, scale, backdrop):
    """Sprite-ul pe fundalul boltii, cu un cadru de lungime egala; transparenta se vede ca interiorul boltii."""
    bg = backdrop.copy()
    bg.alpha_composite(im)
    return bg.resize((bg.width * scale, bg.height * scale), Image.NEAREST)


def scene_base():
    """Satul la locul zidului: apa, pamantul copt, zidul, panza (cadrul 0) si spuma (cadrul 0), FARA turbina."""
    g = AW.load_sprite("prop_dam_ground")
    water = AW.load_sprite("water_tile")
    bg = Image.new("RGBA", g.size)
    for yy in range(0, g.height, water.height):
        for xx in range(0, g.width, water.width):
            bg.paste(water, (xx, yy))
    bg.alpha_composite(g)
    wall, spill, foam = src_png("prop_dam_wall"), src_png("prop_dam_spill"), src_png("prop_dam_foam")
    wx, wy = 213, 131  # zidul la lume (639, 393)
    bg.alpha_composite(wall, (wx, wy))
    bg.alpha_composite(spill.crop((0, 0, AW.SP_W, AW.SP_H)), (wx + AW.SP_C0, wy + AW.SP_R0))
    bg.alpha_composite(foam.crop((0, 0, AW.FOAM_W, AW.SP_H)), (round((AW.WALL["x"] + AW.WALL["w"]) / D) - 2, round(AW.SPILL["y"] / D)))
    return bg, wx, wy


def composite(new_img, old_img, scale=4, box=(30, 84, 96, 140)):
    """Scena la `scale` px pe pixel de arta, taiata pe `box` (coloane si randuri ale zidului: x0, y0, x1, y1). Turbina noua sta pe
    grila zidului; cea veche e cum e azi in joc: 48x48 de lume = 16x16 de arta, cu pixelii ei de 1 px de lume (4x mai fini decat
    pe grila zidului la x4 se vad la o treime). Una din cele doua e None."""
    base, wx, wy = scene_base()
    big = base.resize((base.width * scale, base.height * scale), Image.NEAREST)
    if new_img is not None:
        sp = new_img.resize((new_img.width * scale, new_img.height * scale), Image.NEAREST)
        big.alpha_composite(sp, ((wx + AT_COL) * scale, (wy + AT_ROW) * scale))
    if old_img is not None:
        # 48 px de lume pe 48 px de sprite = o treime de pixel de zid pe pixel de sprite; centrata pe (855, 729): coloana 64, randul 104
        side = 16 * scale
        up = old_img.resize((old_img.width * 4, old_img.height * 4), Image.NEAREST)
        small = up.resize((side, side), Image.BOX)
        big.alpha_composite(small, ((wx + AT_COL) * scale, (wy + 104) * scale))
    x0, y0, x1, y1 = box
    return big.crop(((wx + x0) * scale, (wy + y0) * scale, (wx + x1) * scale, (wy + y1) * scale))


def preview(images, outdir):
    lab = font(8)
    back = arch_backdrop()
    still = images["prop_dam_turbine"]
    spin = images["prop_dam_turbine_spin"]
    S = 8
    gut = 20
    # randul 1: sprite-ul fix x8 pe fundalul boltii si pe verde, apoi cele 4 cadre x8
    tiles = []
    cap = ["prop_dam_turbine 16x20 (pe bolta)"]
    tiles.append(sprite_tile(still, S, back))
    for f in range(FRAMES):
        fr = spin.crop((f * TW, 0, (f + 1) * TW, TH))
        tiles.append(sprite_tile(fr, S, back))
        cap.append(f"spin cadrul {f + 1}")
    # sprite-ul singur pe tabla de sah (transparenta) x8
    chk = Image.new("RGBA", (TW * S, TH * S))
    cd = ImageDraw.Draw(chk)
    for yy in range(TH * 2):
        for xx in range(TW * 2):
            cd.rectangle((xx * S // 2, yy * S // 2, (xx + 1) * S // 2 - 1, (yy + 1) * S // 2 - 1),
                         fill=(150, 150, 150, 255) if (xx + yy) % 2 else (190, 190, 190, 255))
    chk.alpha_composite(still.resize((TW * S, TH * S), Image.NEAREST))
    tiles.append(chk)
    cap.append("sprite singur")
    row1_w = sum(t.width for t in tiles) + gut * (len(tiles) + 1)
    row1_h = max(t.height for t in tiles) + 30
    # randul 2: scena la x4, noua / veche
    new_c = composite(still, None)
    old_c = composite(None, Image.open(os.path.join(SPR, "prop_turbine.png")).convert("RGBA"))
    sc_w = new_c.width + old_c.width + gut * 3
    # randul 3: aceeasi scena, x8, doar turbina noua (jocul la 8 fps: cele 4 cadre pe rand)
    zoom_frames = []
    for f in range(FRAMES):
        fr = spin.crop((f * TW, 0, (f + 1) * TW, TH))
        zoom_frames.append(composite(fr, None, 8, (50, 88, 82, 130)))
    out_w = max(row1_w, sc_w, sum(z.width for z in zoom_frames) + gut * 5)
    out_h = row1_h + new_c.height + 30 + zoom_frames[0].height + 40 + gut * 3
    out = Image.new("RGBA", (out_w, out_h), BG)
    d = ImageDraw.Draw(out)
    x = gut
    for t, cp in zip(tiles, cap):
        d.text((x, gut - 6), cp, font=lab, fill=LABEL)
        out.alpha_composite(t, (x, gut + 8))
        x += t.width + gut
    y2 = gut + row1_h
    d.text((gut, y2 - 8), "NOU: turbina barajului pe grila zidului (x4)", font=lab, fill=LABEL)
    out.alpha_composite(new_c, (gut, y2 + 8))
    d.text((gut * 2 + new_c.width, y2 - 8), "VECHI: turbina Erei 3 la 48x48 de lume (x4)", font=lab, fill=LABEL)
    out.alpha_composite(old_c, (gut * 2 + new_c.width, y2 + 8))
    y3 = y2 + new_c.height + 30
    x = gut
    for f, z in enumerate(zoom_frames):
        d.text((x, y3 - 8), f"in joc x8, cadrul {f + 1}", font=lab, fill=LABEL)
        out.alpha_composite(z, (x, y3 + 8))
        x += z.width + gut
    path = os.path.join(outdir, "turbine_preview.png")
    out.save(path)
    print("scris", path, out.size)


def ascii_dump(c, title):
    print(title)
    for y in range(c.h):
        row = ""
        for x in range(c.w):
            p = c.px[y][x]
            row += "." if p[3] == 0 else ("#" if p[3] == 255 else "+")
        print("  ", row)


GAP_RGB = {COOL_GAP[:3], WARM_GAP[:3]}


def slit_sizes(pixels):
    """Marimile fantelor intunecate (golurile dintre palete, 8-conexe) dintr-un cadru dat ca lista de TW*TH pixeli RGBA, pe randurile rotii
    (2-12), fara butuc si guler (r <= R_HUB). Un cadru curat are exact N_BLADES fante, fiecare de 3-4 pixeli."""
    cells = set()
    for y in range(2, WATERLINE):
        for x in range(TW):
            p = pixels[y * TW + x]
            if p[3] and p[:3] in GAP_RGB and math.hypot(x + 0.5 - CX, y + 0.5 - CY) > R_HUB:
                cells.add((x, y))
    seen, sizes = set(), []
    for cell in sorted(cells):
        if cell in seen:
            continue
        stack, n = [cell], 0
        seen.add(cell)
        while stack:
            x, y = stack.pop()
            n += 1
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if q in cells and q not in seen:
                        seen.add(q)
                        stack.append(q)
        sizes.append(n)
    return sorted(sizes)


def report(images):
    st = images["prop_dam_turbine"]
    sp = images["prop_dam_turbine_spin"]
    f0 = sp.crop((0, 0, TW, TH))
    print("cadrul 1 == sprite-ul fix:", list(f0.getdata()) == list(st.getdata()))
    assert list(f0.getdata()) == list(st.getdata()), "cadrul 1 nu e identic cu sprite-ul fix"
    frames = [list(sp.crop((f * TW, 0, (f + 1) * TW, TH)).getdata()) for f in range(FRAMES)]
    # cadrul 5 (= faza completa, cu apa din cadrul 1) trebuie sa fie identic cu cadrul 1: bucla se inchide
    wrap_frame = to_image(turbine(PHASE0 + FRAMES * STEP, 0))
    closed = list(wrap_frame.getdata()) == frames[0]
    print("bucla se inchide (cadrul 5 == cadrul 1):", closed)
    assert closed, "bucla nu se inchide"
    # cate fante intunecate, de ce marime: exact N_BLADES in fiecare cadru, fara fante lipite
    for f in range(FRAMES):
        sizes = slit_sizes(frames[f])
        print(f"  cadrul {f + 1}: fante {len(sizes)} marimi {sizes}")
        assert len(sizes) == N_BLADES, (f + 1, sizes)
        assert all(3 <= n <= 4 for n in sizes), (f + 1, sizes)
    # cate pixeli se schimba pe pas, pe roata (fara apa: randurile 0-12) si in total
    for f in range(FRAMES):
        g = (f + 1) % FRAMES
        wheel = sum(1 for i, (a, b) in enumerate(zip(frames[f], frames[g])) if a != b and i // TW < WATERLINE)
        allpx = sum(1 for a, b in zip(frames[f], frames[g]) if a != b)
        print(f"  cadrul {f + 1}->{g + 1}: {wheel} pixeli de roata schimbati, {allpx} cu apa, din {TW * TH}")
    # butucul si gulerul (r <= R_HUB) identice in toate cadrele
    diff = 0
    for y in range(TH):
        for x in range(TW):
            if math.hypot(x + 0.5 - CX, y + 0.5 - CY) <= R_HUB:
                diff += len({frames[f][y * TW + x] for f in range(FRAMES)}) > 1
    print("pixeli de butuc/guler care difera intre cadre:", diff)
    assert diff == 0, "butucul se schimba intre cadre"
    cols = {p[:3] for fr in frames for p in fr if p[3] > 0}
    print("culori distincte (rgb) in foaia de rotire:", len(cols), "| cea mai intunecata:", min(cols, key=sum))
    assert len(cols) <= 20, len(cols)
    semi = sum(1 for fr in frames for p in fr if 0 < p[3] < 255)
    print("pixeli semitransparenti in foaia de rotire:", semi)
    assert semi == 0, "au ramas pixeli semitransparenti"
    opaque = sum(1 for p in st.getdata() if p[3] == 255)
    print(f"sprite-ul fix: pixeli opaci {opaque}, transparenti {TW * TH - opaque}")
    cols_used = {x for y in range(TH) for x in range(TW) if st.getpixel((x, y))[3] > 0}
    print("coloane folosite:", min(cols_used), "-", max(cols_used))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=SCRATCH)
    args = ap.parse_args()
    global OUTDIR
    OUTDIR = args.out
    os.makedirs(args.out, exist_ok=True)
    images = {}
    for name, fn in SPRITES.items():
        c = fn()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h, SIZES[name])
        png(os.path.join(args.out, name + ".png"), c.w, c.h, c.px)
        images[name] = to_image(c)
        print("scris", name, c.w, c.h)
    ascii_dump(turbine(0.0), "prop_dam_turbine:")
    preview(images, args.out)
    report(images)


if __name__ == "__main__":
    main()
