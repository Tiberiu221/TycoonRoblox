#!/usr/bin/env python3
"""Sprite-urile Erei 1 rescrise (E1.8 roata, E1.9 restul): tot ce se desena pana acum in cod.

Pana la pasul asta, moneda era un cerc auriu facut din `Frame`+`UICorner`, perla un punct albastru,
bulina de quest un cerc rosu, iar mana din tutorial nu exista deloc. Un cerc cu colturi rotunjite
arata la fel in orice joc; sprite-urile de aici apartin aceleiasi lumi ca malul si cladirile.

Aceleasi reguli ca restul conductei (buildings.py / world.py / tycoon_f*.py):
  * compunere alpha-`over`, niciodata alfa fortat la 255;
  * conturul se TRASEAZA automat prin vecinatate, in maro cald, nu in negru pur;
  * umbra din elipse translucide suprapuse, nu o pata plata;
  * culorile ies din palette.ramp(), cu deplasarea de nuanta spre albastru in umbra;
  * NU suprascrie un sprite existent -- iese cu eroare daca fisierul e deja acolo.

Rulare: python3 scripts/art/tycoon_e1.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png, hexc, shadow  # noqa: E402
from palette import ramp, hsv, mix, OUTLINE, SHADOW, WOOD, STONE  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

# Rampe noi, toate prin ramp(): opt felii trebuie sa se deosebeasca la 40x40, deci nuantele sunt
# departate, dar saturatia si valoarea raman in aceeasi familie ca restul jocului.
WEDGES = [
    ramp(18, 0.62, 0.86),   # rosu-caramiziu
    ramp(42, 0.70, 0.92),   # auriu
    ramp(96, 0.48, 0.74),   # verde
    ramp(196, 0.52, 0.80),  # albastru-apa
    ramp(268, 0.42, 0.72),  # violet
    ramp(340, 0.55, 0.84),  # zmeuriu
    ramp(60, 0.30, 0.90),   # galben palid
    ramp(210, 0.30, 0.62),  # albastru-cenusiu
]
RIM = ramp(28, 0.45, 0.60)   # rama de lemn
HUB = ramp(40, 0.35, 0.88)   # butucul din mijloc


def outline_trace(c, col=OUTLINE):
    """Conturul exterior, trasat prin vecinatate -- niciodata desenat de mana."""
    src = [row[:] for row in c.px]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3]:
                continue
            touching = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and src[ny][nx][3] > 200:
                    touching = True
                    break
            if touching:
                c.px[y][x] = col


def wheel(size, wedges=8, with_shadow=True):
    c = C(size, size)
    cx = cy = (size - 1) / 2.0
    r_out = size / 2.0 - 1.5
    r_rim = r_out - max(1.5, size * 0.07)
    r_hub = size * 0.13

    if with_shadow:
        # umbra: trei elipse translucide, ca la orice obiect asezat pe pamant
        for i, (a, shrink) in enumerate(((26, 0.0), (34, 0.12), (40, 0.22))):
            rx = r_out * (1 - shrink)
            ry = rx * 0.28
            for y in range(size):
                for x in range(size):
                    dx, dy = x - cx, y - (size - ry - 1)
                    if (dx / max(rx, 0.001)) ** 2 + (dy / max(ry, 0.001)) ** 2 <= 1:
                        c.put(x, y, (SHADOW[0], SHADOW[1], SHADOW[2], a))

    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            d = math.hypot(dx, dy)
            if d > r_out:
                continue
            if d > r_rim:
                # rama: mai deschisa sus-stanga, mai inchisa jos-dreapta
                lit = (-dx - dy) / (r_out * 2) + 0.5
                c.put(x, y, RIM[min(len(RIM) - 1, max(0, int(lit * len(RIM))))])
                continue
            if d <= r_hub:
                c.put(x, y, HUB[2])
                continue
            ang = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
            k = int(ang * wedges) % wedges
            ramp_k = WEDGES[k % len(WEDGES)]
            # umbra spre marginea feliei: da volum fara sa strice culoarea
            edge = abs((ang * wedges) % 1.0 - 0.5) * 2
            step = 1 if edge > 0.82 else 2
            c.put(x, y, ramp_k[step])

    outline_trace(c)
    return c



# --- rampe pentru pictograme -----------------------------------------------
# Aceeasi familie ca lumea: auriul sta langa nisip (44), perla langa apa (198), lemnul la 28.
GOLD = ramp(44, 0.72, 0.78)
GOLD_HI = ramp(48, 0.55, 0.96)
PEARL = ramp(198, 0.16, 0.90)
STEEL = ramp(212, 0.14, 0.60)
BRASS = ramp(38, 0.52, 0.62)
REDC = ramp(6, 0.62, 0.76)
BLUEC = ramp(214, 0.56, 0.68)
GREENC = ramp(140, 0.54, 0.62)
SKIN = ramp(28, 0.34, 0.86)
CLOTH = ramp(206, 0.40, 0.50)
BASKET = ramp(34, 0.44, 0.58)
PARCH = hsv(40, 0.16, 0.93)
PARCH_D = hsv(38, 0.22, 0.82)
INK = hsv(26, 0.45, 0.20)
T = (0, 0, 0, 0)


def ic(draw, size=16):
    """O pictograma: panza goala, desenul, apoi conturul trasat automat."""
    c = C(size, size)
    draw(c)
    outline_trace(c)
    return c


# --- monedele ---------------------------------------------------------------
def _coin(c):
    """Moneda: disc auriu cu un val stampilat. Valul nu e ornament -- e singurul lucru care o
    leaga de raul din care vin banii, si se citeste si la 16 pixeli."""
    c.ellipse(8, 8, 6.6, 6.6, GOLD[0])
    c.ellipse(8, 8, 5.8, 5.8, GOLD[2])
    c.ellipse(7.3, 7.3, 4.8, 4.8, GOLD[3])
    c.ellipse(6.5, 6.5, 2.6, 2.6, GOLD[4])
    c.ellipse(5.8, 5.8, 1.2, 1.2, GOLD_HI[4])
    for x in range(4, 12):
        y = 9 - int(round(math.sin((x - 4) / 7.0 * 2 * math.pi) * 1.3))
        c.put(x, y, GOLD[0])
        c.put(x, y + 1, GOLD[1])


def _pearl(c):
    """Perla: sfera rece cu doua lumini -- una tare sus-stanga, una slaba jos-dreapta (lumina
    intoarsa de suprafata pe care sta). Fara a doua, arata ca un buton, nu ca o perla."""
    c.ellipse(8, 8, 6.2, 6.2, PEARL[0])
    c.ellipse(8, 8, 5.5, 5.5, PEARL[2])
    c.ellipse(7.4, 7.4, 4.4, 4.4, PEARL[3])
    c.ellipse(6.6, 6.6, 2.8, 2.8, PEARL[4])
    c.ellipse(6.0, 6.0, 1.3, 1.3, hsv(50, 0.04, 1.0))
    c.ellipse(10.2, 10.6, 1.7, 1.1, PEARL[3])


# --- pictogramele de statistica ---------------------------------------------
def _idle(c):
    """Fulgerul de pe pastila IDLE: venit care curge fara tine."""
    rows = {
        2: (9, 3), 3: (8, 4), 4: (7, 4), 5: (6, 5), 6: (5, 7),
        7: (5, 6), 8: (7, 4), 9: (6, 4), 10: (5, 4), 11: (4, 4), 12: (4, 3), 13: (4, 2),
    }
    for y, (x0, w) in rows.items():
        c.rect(x0, y, w, 1, GOLD[3] if y < 8 else GOLD[2])
        c.put(x0, y, GOLD_HI[4])


def _lock(c):
    """Lacatul de pe quest-urile inchise. Belciugul se deseneaza pe randuri, nu ca arc de cerc:
    un inel taiat la y<=7 lasa deasupra corpului doar o felie lata si plata, si la 16 pixeli asta
    se citea 'geanta'. Aici arcul URCA peste corp, cu doua picioare subtiri."""
    c.rect(6, 2, 4, 1, STEEL[4])
    c.rect(5, 3, 6, 1, STEEL[3])
    c.rect(5, 4, 2, 4, STEEL[3])
    c.rect(9, 4, 2, 4, STEEL[1])
    c.rect(3, 7, 10, 8, BRASS[3])
    c.rect(3, 7, 10, 1, BRASS[4])
    c.rect(3, 14, 10, 1, BRASS[1])
    c.rect(3, 7, 1, 8, BRASS[4])
    c.rect(12, 7, 1, 8, BRASS[1])
    keyhole = hsv(30, 0.60, 0.22)
    c.ellipse(8, 10, 1.6, 1.6, keyhole)
    c.rect(7, 10, 2, 4, keyhole)


def _capacity(c):
    """Capacitatea: galeata pe jumatate plina. Ordinea conteaza -- intai trupul, apoi interiorul
    INTUNECAT, apoi umplutura deschisa, abia la final buza. Prima varianta avea umplutura maro pe
    cos maro si arata goala; un simbol care spune 'gol' langa randul 'capacity 12' minte [D40]."""
    inner = hsv(26, 0.52, 0.26)
    fill = hsv(38, 0.30, 0.84)
    for i in range(10):
        inset = i // 4
        c.rect(2 + inset, 5 + i, 12 - 2 * inset, 1, BASKET[3] if i % 3 else BASKET[2])
    for i in range(9):
        inset = i // 4
        c.rect(3 + inset, 5 + i, 10 - 2 * inset, 1, inner)
    for i in range(5):
        inset = (i + 4) // 4
        c.rect(3 + inset, 9 + i, 10 - 2 * inset, 1, fill if i else hsv(42, 0.18, 0.94))
    c.rect(2, 4, 12, 2, BASKET[4])
    c.rect(2, 4, 12, 1, hsv(36, 0.30, 0.80))


def _speed(c):
    """Viteza: cronometru cu dungi de miscare in stanga. Ceasul simplu exista deja (icon_clock)
    si inseamna 'asteapta'; asta trebuie sa insemne 'mai repede', de-aici dungile."""
    c.rect(1, 5, 3, 1, STEEL[3])
    c.rect(0, 8, 4, 1, STEEL[3])
    c.rect(1, 11, 3, 1, STEEL[3])
    c.rect(8, 1, 3, 2, STEEL[2])
    c.ellipse(10, 9, 5.6, 5.6, STEEL[1])
    c.ellipse(10, 9, 4.6, 4.6, PARCH)
    c.ellipse(9.4, 8.4, 3.0, 3.0, hsv(44, 0.10, 0.99))
    c.rect(9, 5, 2, 5, INK)
    c.rect(10, 9, 4, 2, INK)


def _carry(c):
    """Caratul: traista in miscare. Aceeasi forma ca prop_sack, ca jucatorul sa lege randul din
    panou de obiectul pe care il vede pe mal."""
    c.rect(0, 6, 3, 1, BASKET[3])
    c.rect(1, 10, 2, 1, BASKET[3])
    c.ellipse(10, 10, 4.6, 4.4, BASKET[2])
    c.ellipse(9.2, 9.2, 3.4, 3.2, BASKET[3])
    c.rect(8, 3, 4, 3, BASKET[1])
    c.rect(7, 5, 6, 1, ramp(20, 0.40, 0.40)[2])
    c.rect(8, 3, 1, 3, BASKET[2])


def _levelup(c):
    """Sageata de nivel: varf plin + talpa. Verdele e singurul din joc care inseamna 'creste'."""
    for i in range(6):
        c.rect(8 - i, 2 + i, 1 + 2 * i, 1, GREENC[3] if i < 2 else GREENC[2])
    c.rect(6, 8, 5, 4, GREENC[2])
    c.rect(6, 8, 1, 4, GREENC[3])
    c.rect(3, 13, 11, 2, GREENC[1])
    c.rect(3, 13, 11, 1, GREENC[2])


# --- bucatile de interfata ---------------------------------------------------
def ui_book():
    """Cartea de quest-uri (28x28): coperta vazuta usor din unghi, cotor la stanga, taietura de
    pagini la dreapta, semn de carte rosu. Din profil ar fi fost o dunga -- din unghi se vede ca
    e o carte si la 28 de pixeli."""
    c = C(28, 28)
    shadow(c, 14, 25, 10, 2)
    cover = ramp(12, 0.44, 0.40)
    c.rect(8, 5, 15, 19, hsv(42, 0.12, 0.96))
    for y in range(6, 24, 3):
        c.rect(19, y, 4, 1, PARCH_D)
    c.rect(4, 4, 17, 20, cover[2])
    c.rect(4, 4, 17, 1, cover[3])
    c.rect(4, 23, 17, 1, cover[0])
    c.rect(4, 4, 4, 20, cover[1])
    c.rect(7, 4, 1, 20, cover[0])
    c.rect(10, 9, 8, 2, GOLD[3])
    c.rect(10, 9, 8, 1, GOLD[4])
    c.rect(10, 14, 8, 1, GOLD[2])
    c.rect(10, 17, 5, 1, GOLD[2])
    c.rect(17, 4, 3, 9, REDC[2])
    c.rect(17, 4, 1, 9, REDC[3])
    outline_trace(c)
    return c


def ui_badge():
    """Bulina rosie cu cifra. NU e cu 9 felii: e mereu patrata pe ecran, deci se intinde intreaga
    si ramane cerc. Cu 9 felii ar fi trebuit sa aiba raza egala cu felia de colt, adica un patrat
    rotunjit -- alta forma."""
    c = C(16, 16)
    c.ellipse(8, 8, 7.2, 7.2, REDC[0])
    c.ellipse(8, 8, 6.4, 6.4, REDC[2])
    c.ellipse(7.4, 7.0, 5.2, 5.0, REDC[3])
    c.ellipse(6.6, 6.0, 2.6, 2.0, REDC[4])
    return c


def ui_levelbadge(size=20, border=8):
    """Insigna albastra `Level N` de pe obiectele din lume, cu 9 felii. Coltul rotunjit are exact
    raza feliei de colt, altfel taietura ar intra in banda care se intinde si s-ar deforma."""
    c = C(size, size)
    for y in range(size):
        if y < 2:
            col = BLUEC[3]
        elif y >= size - 2:
            col = BLUEC[0]
        else:
            col = BLUEC[2]
        c.rect(0, y, size, 1, col)
    c.rect(0, 2, size, 1, BLUEC[4])
    # colturi taiate in trepte, strict in patratul border x border
    for cy in (0, 1):
        for cx in (0, 1):
            for y in range(border):
                for x in range(border):
                    if math.hypot(border - 0.5 - x, border - 0.5 - y) > border:
                        px = x if cx == 0 else size - 1 - x
                        py = y if cy == 0 else size - 1 - y
                        c.px[py][px] = T
    return c


def ui_hand():
    """Mana care arata, pentru tutorial (24x28). Degetul sta pe STANGA pumnului, nu centrat, si
    degetul mare se vede dedesubt: centrat pe pumn, silueta se citea ambiguu -- exact felul de
    lucru care se vede abia dupa ce te uiti la sprite marit, nu in cod."""
    c = C(24, 28)
    shadow(c, 12, 26, 8, 2)
    c.ellipse(14, 19, 6.4, 5.6, SKIN[2])
    c.rect(8, 15, 13, 8, SKIN[2])
    c.ellipse(13, 17, 5.2, 4.2, SKIN[3])
    c.rect(7, 3, 5, 13, SKIN[2])
    c.ellipse(9.5, 3.5, 2.5, 2.5, SKIN[3])
    c.ellipse(8.7, 2.9, 1.5, 1.5, SKIN[4])
    c.rect(7, 3, 1, 13, SKIN[3])
    c.rect(11, 5, 1, 10, SKIN[1])
    c.ellipse(6.0, 18.0, 2.6, 3.4, SKIN[2])
    c.ellipse(5.6, 17.6, 1.8, 2.6, SKIN[3])
    for k in range(3):
        c.rect(17, 15 + k * 3, 4, 1, SKIN[1])
    c.rect(8, 22, 13, 4, CLOTH[2])
    c.rect(8, 22, 13, 1, CLOTH[3])
    c.rect(8, 25, 13, 1, CLOTH[0])
    outline_trace(c)
    return c


def ui_glow(size=32, border=12):
    """Inelul de reflector, cu 9 felii. Mijlocul e complet transparent (acolo sta lucrul aprins),
    iar alfa depinde DOAR de distanta pana la dreptunghiul interior -- asa felia de sus e constanta
    pe orizontala si nu apare o cusatura acolo unde se intinde."""
    c = C(size, size)
    lo, hi = border, size - 1 - border
    col = hsv(44, 0.50, 1.0)
    for y in range(size):
        for x in range(size):
            dx = max(0, lo - x, x - hi)
            dy = max(0, lo - y, y - hi)
            d = math.hypot(dx, dy)
            if d <= 0:
                continue
            t = min(1.0, d / float(border))
            a = 205 if d <= 1.6 else int(168 * (1.0 - t) ** 1.7)
            if a > 0:
                c.px[y][x] = (col[0], col[1], col[2], a)
    return c


def chapter_landing():
    """Ilustratia capitolului 1 (150x100). NU mai e o poza lipita in card: e FUNDALUL cardului, la
    exact 4x (600x400), cu textul scris peste ea. De-aia s-a marit de la 96x64 -- intinsa pe tot
    cardul, cea veche ajungea la 6-7x si fiecare pixel devenea o caramida.

    Compozitia e facuta pentru text: sus-stanga ramane cer curat (acolo cade titlul si cele doua
    randuri), jos ramane apa linistita (acolo cade indemnul), iar tot ce se intampla -- pontonul,
    plasa, bustanul -- sta in banda de mijloc. Soarele e impins in dreapta, ca sa nu bata sub titlu.
    """
    W, H = 150, 100
    c = C(W, H)
    grass = ramp(104, 0.44, 0.50)
    sand = ramp(44, 0.32, 0.76)
    water = ramp(203, 0.56, 0.54)
    reedc = ramp(92, 0.40, 0.46)

    def shore(x):
        return 55 + int(round(1.6 * math.sin(x / 13.0) + 0.8 * math.sin(x / 5.0)))

    # --- cerul de rasarit: albastru palid sus, auriu spre linia apei
    for y in range(0, 56):
        t = (y / 55.0) ** 0.85
        c.rect(0, y, W, 1, mix(hsv(206, 0.28, 0.93), hsv(32, 0.32, 1.0), t))
    for cx, cy, rx in ((30, 13, 15), (48, 16, 10), (120, 9, 12), (16, 27, 9), (98, 24, 8)):
        c.ellipse(cx, cy, rx, rx * 0.30, (255, 252, 244, 80))
        c.ellipse(cx - rx * 0.2, cy - 1, rx * 0.6, rx * 0.20, (255, 255, 250, 70))
    c.ellipse(118, 25, 12, 12, (255, 244, 214, 55))
    c.ellipse(118, 25, 8, 8, hsv(44, 0.20, 1.0))
    c.ellipse(118, 25, 5.5, 5.5, hsv(50, 0.05, 1.0))
    for bx, by in ((58, 19), (66, 15), (72, 21)):
        c.put(bx, by, hsv(24, 0.30, 0.30))
        c.put(bx - 1, by - 1, hsv(24, 0.30, 0.30))
        c.put(bx + 1, by - 1, hsv(24, 0.30, 0.30))

    # --- doua creste de dealuri, a doua mai calda si mai jos
    far = ramp(158, 0.22, 0.50)
    near = ramp(118, 0.36, 0.40)
    for x in range(W):
        h = 40 + int(round(3.5 * math.sin(x / 24.0) + 2.0 * math.sin(x / 9.0 + 2.1)))
        c.rect(x, h, 1, 60 - h, far[1])
        c.rect(x, h, 1, 1, far[2])
    for x in range(W):
        h = 47 + int(round(3.0 * math.sin(x / 17.0 + 1.0) + 1.8 * math.sin(x / 6.5)))
        c.rect(x, h, 1, 60 - h, near[1])
        c.rect(x, h, 1, 1, near[2])

    # --- apa, apoi malul desenat peste ea pana la linia de tarm
    for y in range(50, H):
        f = (y - 50) / float(H - 50)
        c.rect(0, y, W, 1, mix(water[3], water[0], min(1.0, f * 1.05)))
    for x in range(W):
        e = shore(x)
        c.rect(x, 51, 1, e - 51, grass[1])
        c.rect(x, 51, 1, 1, grass[3])
        if (x * 7 + (x // 3) * 5) % 11 == 0:
            c.put(x, 52 + (x % 2), grass[2])
        c.rect(x, e, 1, 3, sand[2])
        c.put(x, e + 3, mix(sand[1], water[2], 0.55))

    # --- valurile: liniute scurte, mai rare spre fund
    for k in range(26):
        yy = 62 + (k * 7) % 36
        xx = (k * 29 + (k % 3) * 11) % (W - 12)
        c.rect(xx, yy, 5 + (k % 4), 1, (255, 255, 255, 46 if yy > 80 else 62))

    # --- pontonul, la stanga, cu figura pe el
    for px in (17, 29, 41):
        c.rect(px, 58, 3, 22, WOOD[0])
        c.rect(px, 58, 1, 22, WOOD[1])
        c.ellipse(px + 1, 80, 5, 1.2, (255, 255, 255, 60))
    c.rect(11, 52, 42, 6, WOOD[2])
    for k in range(11):
        c.rect(12 + k * 4, 52, 1, 6, WOOD[1])
    c.rect(11, 52, 42, 1, WOOD[3])
    c.rect(11, 57, 42, 1, WOOD[0])

    hair = ramp(22, 0.46, 0.28)
    c.ellipse(27, 42, 3.0, 3.2, SKIN[3])
    c.ellipse(27, 40.4, 3.1, 2.1, hair[1])
    c.rect(24, 45, 7, 6, CLOTH[2])
    c.rect(24, 45, 1, 6, CLOTH[3])
    c.rect(24, 50, 7, 1, CLOTH[0])
    c.rect(25, 51, 2, 2, ramp(28, 0.44, 0.30)[1])
    c.rect(28, 51, 2, 2, ramp(28, 0.44, 0.30)[1])

    # --- plasa, la dreapta: atarna, cu tivul cazut la mijloc
    for px in (86, 124):
        c.rect(px, 43, 3, 21, WOOD[1])
        c.rect(px, 43, 1, 21, WOOD[3])
    c.rect(86, 45, 41, 3, WOOD[2])
    c.rect(86, 45, 41, 1, WOOD[3])
    mesh = hsv(44, 0.10, 0.93)[:3] + (185,)

    def hem(x):
        return 60 + int(round(5.0 * math.sin(math.pi * (x - 89) / 36.0)))

    for x in range(89, 125, 4):
        for y in range(48, hem(x) + 1):
            c.put(x, y, mesh)
    for y in range(48, 66, 4):
        for x in range(89, 125):
            if y <= hem(x):
                c.put(x, y, mesh)
    for x in range(89, 125):
        c.put(x, hem(x), mesh)

    # --- bustanul care pluteste spre plasa: motivul pentru care sunt puse acolo
    c.ellipse(104, 78, 11, 3.4, WOOD[1])
    c.ellipse(104, 76.4, 9.5, 2.2, WOOD[2])
    c.ellipse(101, 75.6, 2.0, 1.2, WOOD[3])
    c.ellipse(90, 79, 13, 1.5, (255, 255, 255, 85))
    c.ellipse(78, 81, 10, 1.2, (255, 255, 255, 58))

    # --- papura in prim-plan, stanga-jos: da adancime fara sa intre peste text
    for rx, rh in ((5, 24), (10, 18), (15, 27), (20, 15), (26, 20)):
        tipx = rx
        for i in range(rh):
            bend = int(i * i / (rh * 3.4))
            tipx = rx + bend
            c.put(tipx, H - 1 - i, reedc[1 + (i % 2)])
            if i % 5 == 2:
                c.put(tipx + 1, H - 1 - i, reedc[0])
        c.ellipse(tipx, H - 1 - rh, 1.4, 2.8, ramp(26, 0.52, 0.36)[1])
    return c


# --- D48: gaterul, scandurile, panza ----------------------------------------------------------
STEELB = ramp(210, 0.10, 0.74)
PLANK = ramp(34, 0.40, 0.80)
LOGW = ramp(30, 0.42, 0.70)  # mai deschis decat peretele din spate, altfel busteanul se pierde
SHINGLE = ramp(14, 0.42, 0.50)


def _blade(c, cx, cy, r, teeth=12):
    """Panza circulara: disc de otel cu dinti MARUNTI pe margine, butuc inchis, lumina sus-stanga.
    Prima varianta avea opt dinti lungi, radiali, si la 16 pixeli se citea 'mina de mare', nu
    'gater'. Un gater are multi dinti mici: aici sunt un pixel, pe tot conturul, ca un zimt."""
    c.ellipse(cx, cy, r + 0.9, r + 0.9, STEELB[0])
    for k in range(teeth):
        a = 2 * math.pi * (k + 0.5) / teeth
        c.put(round(cx + (r + 1.4) * math.cos(a)), round(cy + (r + 1.4) * math.sin(a)), STEELB[1])
    c.ellipse(cx, cy, r, r, STEELB[2])
    c.ellipse(cx - 0.3, cy - 0.3, r - 1.0, r - 1.0, STEELB[3])
    c.ellipse(cx - r * 0.3, cy - r * 0.3, r * 0.38, r * 0.38, STEELB[4])
    c.ellipse(cx, cy, max(1.0, r * 0.26), max(1.0, r * 0.26), INK)


def _music(c):
    """Butonul de muzica [D51]: doua note legate, in lemn si auriu -- nu difuzorul din telefon, care ar
    spune "volum", nu "muzica"."""
    c.rect(4, 11, 4, 3, GOLD[3])
    c.rect(4, 11, 4, 1, GOLD_HI[4])
    c.rect(10, 9, 4, 3, GOLD[3])
    c.rect(10, 9, 4, 1, GOLD_HI[4])
    c.rect(7, 3, 1, 9, WOOD[1])
    c.rect(13, 2, 1, 8, WOOD[1])
    c.rect(7, 2, 7, 2, WOOD[1])
    c.rect(7, 4, 7, 1, WOOD[2])


def _saw_icon(c):
    """Pictograma gaterului: panza singura. La 16 pixeli, discul cu dinti se citeste 'gater'
    mai sigur decat orice cladire micsorata."""
    _blade(c, 7.5, 7.5, 5.2, teeth=8)


def goods_planks():
    """Scandurile (24x18): trei scanduri stivuite, capetele mai inchise. Fara spuma la baza, spre
    deosebire de bunurile din rau -- scandurile stau pe debarcader, nu plutesc."""
    c = C(24, 18)
    shadow(c, 12, 15, 10, 2)
    for i, (x, y) in enumerate(((3, 10), (5, 6), (2, 2))):
        c.rect(x, y, 18, 4, PLANK[2])
        c.rect(x, y, 18, 1, PLANK[4])
        c.rect(x, y + 3, 18, 1, PLANK[1])
        c.rect(x, y, 2, 4, PLANK[0])
        c.rect(x + 16, y, 2, 4, PLANK[1])
        c.put(x + 6 + i * 3, y + 2, PLANK[1])
    outline_trace(c)
    return c


def prop_sawmill():
    """Gaterul (40x32, PIXEL_SCALE 3 -> 120x96): sopron deschis, capra cu un bustean, panza la
    dreapta. Deschis in fata, ca sa se vada ce se intampla inauntru -- un gater inchis ar fi doar o
    casa. Acoperisul e din sindrila rosiatica, nu din paiele alergatorului: alta cladire, alta treaba."""
    c = C(40, 32)
    shadow(c, 20, 29, 18, 2)
    # peretele din spate
    c.rect(4, 10, 32, 17, WOOD[1])
    for y in range(12, 27, 3):
        c.rect(4, y, 32, 1, WOOD[0])
    # stalpii din fata
    for px in (3, 35):
        c.rect(px, 9, 3, 19, WOOD[2])
        c.rect(px, 9, 1, 19, WOOD[3])
    # acoperisul: sindrila in trepte, streasina iese peste stalpi
    for i in range(8):
        inset = max(0, 6 - i)
        c.rect(1 + inset // 2, 2 + i, 38 - inset, 1, SHINGLE[2] if i % 2 else SHINGLE[3])
    c.rect(0, 9, 40, 2, SHINGLE[1])
    c.rect(0, 9, 40, 1, SHINGLE[2])
    # capra si busteanul pe ea
    c.rect(8, 22, 2, 6, WOOD[0])
    c.rect(19, 22, 2, 6, WOOD[0])
    c.rect(7, 21, 15, 2, WOOD[2])
    c.ellipse(15, 19, 8, 2.6, LOGW[1])
    c.ellipse(15, 18.4, 7, 1.8, LOGW[2])
    c.rect(9, 17, 13, 1, LOGW[3])
    # capatul taiat, cu inelele lui: se vede ca e un bustean, nu o scandura groasa
    c.ellipse(8, 19, 2.0, 2.6, LOGW[4])
    c.ellipse(8, 19, 1.0, 1.4, LOGW[2])
    # panza la dreapta, cu axul ei
    c.rect(29, 14, 1, 13, WOOD[0])
    _blade(c, 29.5, 17.5, 4.6, teeth=8)
    # doua scanduri gata, rezemate
    c.rect(24, 24, 9, 2, PLANK[3])
    c.rect(24, 24, 9, 1, PLANK[4])
    outline_trace(c)
    return c


def prop_storage():
    """Depozitul [D49] (40x32, PIXEL_SCALE 3 -> 120x96): stiva de busteni sub un acoperis de scanduri
    pe patru stalpi. Trebuie sa se citeasca altfel decat gaterul de la prima privire: fara panza,
    fara sindrila rosiatica, cu CAPETELE bustenilor spre tine -- cercurile cu inele spun "lemn
    strans aici", nu "lemn taiat aici". Deschis in fata, ca gramada sa se vada."""
    c = C(40, 32)
    shadow(c, 20, 29, 18, 2)
    # peretele din spate, doar pana la jumatate: e un sopron, nu o casa
    c.rect(5, 14, 30, 12, WOOD[1])
    for y in range(16, 26, 3):
        c.rect(5, y, 30, 1, WOOD[0])
    # stalpii
    for px in (3, 35):
        c.rect(px, 8, 3, 20, WOOD[2])
        c.rect(px, 8, 1, 20, WOOD[3])
    # acoperisul: scanduri late, in panta, cu streasina scurta -- lemn deschis, nu sindrila
    for i in range(6):
        c.rect(1, 2 + i, 38, 1, PLANK[3] if i % 2 else PLANK[2])
    c.rect(0, 8, 40, 2, PLANK[1])
    c.rect(0, 8, 40, 1, PLANK[2])
    for x in range(4, 38, 6):
        c.rect(x, 2, 1, 6, PLANK[1])
    # stiva: trei randuri de capete de bustean, in piramida
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


TAVERN_ROOF = ramp(208, 0.24, 0.50)  # ardezie albastruie: nici sindrila gaterului, nici paiele colibei
WARM = ramp(40, 0.78, 0.98)  # lumina din fereastra
FOAM = ramp(48, 0.10, 0.98)


def prop_tavern():
    """Taverna [D50] (64x48, PIXEL_SCALE 3 -> 192x144), fostul debarcader. Owner-ul: "nu se intelege
    nimic de acolo ca ar trebui sa vinzi ceva, imi imaginez o taverna". Trebuie sa spuna VANZARE de la
    prima privire: firma cu cana si moneda, fereastra-tejghea luminata cu doua cani pe ea, butoaie.
    Casa de barne cu acoperis de ardezie -- alt material decat gaterul (sindrila) si depozitul
    (scanduri), ca cele trei cladiri ale lantului sa nu se confunde. Usa e usor la dreapta mijlocului:
    acolo e locul de vanzare (TycoonConfig.DOCK, x 420 fata de mijlocul 400)."""
    c = C(64, 48)
    shadow(c, 32, 45, 30, 2)
    # peretii din barne: randuri de cate 3 pixeli, cu capetele barnelor iesite la colturi
    c.rect(4, 18, 56, 27, WOOD[2])
    for y in range(18, 45, 3):
        c.rect(4, y + 2, 56, 1, WOOD[1])
        c.rect(4, y, 56, 1, WOOD[3])
        for x in (3, 60):
            c.rect(x, y, 2, 2, LOGW[3])
            c.put(x if x == 3 else x + 1, y, LOGW[4])
    # acoperisul: trapez in trepte, cu streasina lata peste pereti
    for i in range(14):
        x0 = 14 - i
        c.rect(x0, 4 + i, 64 - 2 * x0, 1, TAVERN_ROOF[2] if i % 2 else TAVERN_ROOF[3])
        if i % 2 == 0:
            for x in range(x0 + (i // 2) % 3, 64 - x0, 4):
                c.put(x, 4 + i, TAVERN_ROOF[1])
    c.rect(1, 17, 62, 2, TAVERN_ROOF[0])
    c.rect(14, 3, 36, 1, TAVERN_ROOF[4])
    # hornul, din piatra
    c.rect(44, 0, 6, 9, STONE[2])
    c.rect(44, 0, 6, 1, STONE[4])
    c.rect(44, 4, 6, 1, STONE[1])
    c.rect(49, 1, 1, 8, STONE[1])
    # fereastra-tejghea, in stanga: lumina calda, doua cani pe tejghea
    c.rect(8, 24, 19, 11, WOOD[0])
    c.rect(9, 25, 17, 9, WARM[3])
    c.rect(9, 25, 17, 2, WARM[4])
    c.rect(17, 25, 1, 9, WOOD[1])
    c.rect(7, 34, 21, 2, PLANK[3])
    c.rect(7, 34, 21, 1, PLANK[4])
    for mx in (11, 20):
        c.rect(mx, 31, 3, 3, PLANK[2])
        c.rect(mx, 31, 3, 1, FOAM[4])
        c.put(mx + 3, 32, PLANK[1])
    # usa, usor la dreapta mijlocului, cu rama deschisa si clanta
    c.rect(35, 29, 10, 16, PLANK[1])
    c.rect(36, 30, 8, 15, WOOD[0])
    for x in (38, 41):
        c.rect(x, 30, 1, 15, WOOD[1])
    c.put(42, 37, GOLD[3])
    # felinarul de langa usa
    c.rect(32, 28, 2, 1, WOOD[0])
    c.rect(32, 29, 2, 3, WARM[4])
    c.put(32, 32, WOOD[0])
    # firma atarnata: cana si moneda -- "aici se vinde"
    c.rect(46, 19, 14, 1, WOOD[0])
    c.put(48, 20, WOOD[0])
    c.put(57, 20, WOOD[0])
    c.rect(46, 21, 14, 10, OUTLINE)
    c.rect(47, 22, 12, 8, PLANK[3])
    c.rect(48, 23, 4, 5, FOAM[3])
    c.rect(48, 23, 4, 1, FOAM[4])
    c.rect(52, 24, 1, 3, FOAM[1])
    c.ellipse(55.5, 25.5, 2.2, 2.2, GOLD[2])
    c.ellipse(55.5, 25.5, 1.4, 1.4, GOLD_HI[3])
    c.put(55, 25, GOLD_HI[4])
    # butoaiele din dreapta, cu contur propriu: pe peretele de barne s-ar pierde
    for bx, by, h in ((48, 36, 9), (55, 38, 7)):
        c.rect(bx - 1, by - 1, 8, h + 1, OUTLINE)
        c.rect(bx, by, 6, h, LOGW[2])
        c.rect(bx + 1, by, 2, h, LOGW[3])
        c.rect(bx, by + 1, 6, 1, STEEL[1])
        c.rect(bx, by + h - 3, 6, 1, STEEL[1])
    c.rect(8, 40, 18, 2, WOOD[3])
    c.rect(8, 40, 18, 1, WOOD[4])
    for x in (9, 24):
        c.rect(x, 42, 1, 3, WOOD[0])
    outline_trace(c)
    return c


def ui_chevron():
    """Sageata de pe drum [D50] (16x16, arata spre dreapta; codul o roteste). Dara de ghidaj e facuta
    din ele, una la 56 px: groasa si aurie, ca sa se vada si pe iarba, si pe drumul de pamant."""
    c = C(16, 16)
    for y in range(2, 14):
        d = abs(y - 7.5)
        x0 = round(3 + (5.5 - d))
        c.rect(x0, y, 4, 1, GOLD_HI[3])
        c.put(x0, y, GOLD_HI[4])
    outline_trace(c)
    return c


def ui_groundring():
    """Inelul de pe jos [D50] (32x16, in perspectiva): unde stai ca sa tai la gater si unde duce dara
    de ghidaj. Alb, ca sa-l coloreze codul (ImageColor3): auriu pentru tinta, verde cand gaterul taie."""
    c = C(32, 16)
    white = (250, 250, 250, 255)
    for yy in range(16):
        for xx in range(32):
            ox, oy = (xx + 0.5 - 16) / 15.0, (yy + 0.5 - 8) / 7.2
            ix, iy = (xx + 0.5 - 16) / 11.0, (yy + 0.5 - 8) / 4.4
            if ox * ox + oy * oy <= 1 and ix * ix + iy * iy > 1:
                c.put(xx, yy, white)
    outline_trace(c, (120, 120, 120, 255))
    return c


SPRITES = {
    "prop_wheel": lambda: wheel(40),
    "ui_wheel": lambda: wheel(64, with_shadow=False),
    # E1.9: tot ce se desena procedural in client
    "icon_coin": lambda: ic(_coin),
    "icon_pearl": lambda: ic(_pearl),
    "icon_idle": lambda: ic(_idle),
    "icon_lock": lambda: ic(_lock),
    "icon_capacity": lambda: ic(_capacity),
    "icon_speed": lambda: ic(_speed),
    "icon_carry": lambda: ic(_carry),
    "icon_levelup": lambda: ic(_levelup),
    "ui_book": ui_book,
    "ui_badge": ui_badge,
    "ui_levelbadge": ui_levelbadge,
    "ui_hand": ui_hand,
    "ui_glow": ui_glow,
    "chapter_landing": chapter_landing,
    # D48
    "prop_sawmill": prop_sawmill,
    "goods_planks": goods_planks,
    "icon_saw": lambda: ic(_saw_icon),
    # D49
    "prop_storage": prop_storage,
    # D51
    "icon_music": lambda: ic(_music),
    # D50
    "prop_tavern": prop_tavern,
    "ui_chevron": ui_chevron,
    "ui_groundring": ui_groundring,
}


def main():
    names = sys.argv[1:] or list(SPRITES)
    for name in names:
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            print(f"  {name}.png  exista deja, sarit")
            continue
        c = SPRITES[name]()
        png(path, c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")


if __name__ == "__main__":
    main()
