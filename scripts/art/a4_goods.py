#!/usr/bin/env python3
"""[D75, lotul A4, grupul "goods"] Marfa Erei 4 (barajul, lumea 2): cinci bunuri a cate trei desene.

Barajul poarta azi desenele Erelor 1-3 (GOOD_LOOKS_LIKE): barilul e o celula de energie, cablul o bobina de sarma, curentul un
lingou de cupru, cristalul o roata dintata (!), lingoul de cristal unul de fier. Aici fiecare bun primeste desenul lui, in cele
trei forme ale familiei (d55 / d65 / d67): pictograma (goods_X, 24x18), incarcatura din roaba (prop_load_X, 48x9 = 3 trepte de
16x9) si gramada (prop_pile_X, 160x28 = 4 trepte de 40x28, baza pe randul 26).

  barrel   baril de stejar cu cercuri de alama, plin de baterii: din gura lui ies capetele borcanelor (sticla, cupru, zinc) si o
           scanteie; pictograma e un singur baril drept, la mijloc (barilul culcat repeta darul raului), cu ambele cercuri de alama
           duse pana la capete, cel de sus peste buza gurii. Iesirea Switchyard-ului,
           spre Relay. Cald (stejar + alama), vertical, rotund. Gramada: barili in picioare, pe randuri care se pierd spre fund
           (randul din fata cu alama aprinsa si borcane, cele din spate mai intunecate, cu un singur cerc si un capat de sticla).
  cable    tambur de cablu pe cant, ca prop_cable_drums din Era 3 (d70_modern._drum_standing), dar din otel galvanizat: flansa
           rotunda din fata, deschisa, cu gauri de usurare, nituri si butuc intunecat; mantaua de cauciuc negru-albastrui se vede ca o
           semiluna inchisa sus-dreapta, intre flanse, cu spirele infasurate (pe marginea dinspre flansa din spate un pixel din doi
           mai deschis la pictograma, unul singur la tamburii gramezii); un capat de cupru iese jos-dreapta. Iesirea Cable Works-ului.
           Gri-albastrui, rotund. Gramada: tamburi pe cant stivuiti in piramida (1 / 2 / 3 / 3+2); in roaba, 1-3 tamburi mici, cu
           semiluna lata de 2 pixeli si un capat de cupru pe ea.
  grid     curentul: un bloc de condensatoare (carcasa galvanizata, trei tuburi care lumineaza cian, placa si borne de alama) cu un
           fulger opac (miez alb, umbra SPARK[3]) intre borne, fara aureola, peste un capac de izolator galvanizat (pictograma). Facut la Relay din baril + cablu, vandut la Switch
           House. Luminos, rece, dreptunghiular. Gramada: blocuri in rafturi, cu fulgere intre bornele randului de sus.
  crystal  cristalul brut, ca al raului (prop_river_crystal, A1): prisme albastru-violet cu fatete, conturul indigo (CRYS_LINE),
           un miez aprins, o sclipire cu patru brate opace, lipita de varful spirei inalte. In roaba: prisme scurte si groase cu
           varful alb-albastru. Gramada: un morman de ciobi in picioare si culcati la baza, tot mai inalt, inchis la margini cu
           ciobi scurti si grosi (nu cu lame aplecate), cu o aura albastra pe pamant, toata in cadru; sclipiri doar la treptele 3-4.
  ingot    cristalul copt la Kiln: bare turnate lila (trapez: fata de sus mai ingusta; nu otelul albastrui al fierului), cu fata de
           sus luminata, o dunga de cristal aprins pe fata din fata si conturul prun. Gramada: piramida de bare.

Aceeasi disciplina ca restul conductei: rampe din palette.ramp() si ale vecinilor (d67_works: BRASS / GLASS / SPARK / IRON,
a1_pylons: GALV / CRYS / CRYS_VIO), lumina din stanga-sus, umbra din elipse translucide, conturul trasat automat (maro la
baril, cablu si curent; indigo la cristal, prun la lingou), niciodata negru pur. Corpul fiecarei incarcaturi ramane in coloanele
1..14 ale cadrului de 16 px (conturul are loc pe 0 si 15), iar gramezile (cu contur, umbra si aura) nu ating marginile cadrului
de 40 px (coloanele 0 si 39 raman goale). Fiecare desen are marimea exacta din inventar (SIZES).

Ce se vede din fiecare, in joc: pictogramele doar pe avizierele de angajare, in sacul de plasa (0,75x) si pe plutitoare (1,5x);
incarcatura in roaba la 2,5x (si in oglinda cand omul merge spre stanga); gramada la x2 (80x56), prinsa de baza. In roaba din
vedere laterala doar primele 6 randuri ale cadrului de incarcatura se vad deasupra buzei cutiei, deci partea de sus a fiecarui
desen poarta citirea.

Rulare: python3 scripts/art/a4_goods.py [--out DIR]   (PNG-uri native + goods_preview.png, doar in scratchpad)
Scrie DOAR in --out; nu atinge assets/.
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, png  # noqa: E402
from palette import ramp, OUTLINE  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon_e1 import STEEL, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d55  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402
import a1_pylons as A1  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a4")
SPR = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites")

# ---------------------------------------------------------------------------------------------
# paleta: vecinii ca sa para aceeasi lume, plus ce e nou la baraj

OAK = ramp(22, 0.62, 0.52, hue_shift=8, val_span=0.46)  # stejarul barilului: mai rosiatic si mai lucios decat lemnul satului
BRASS = W.BRASS  # cercurile si capacele
GLASS = W.GLASS  # capetele borcanelor-baterii
SPARK = W.SPARK  # arcul electric
COPPER = M.COPPER
GALV = A1.GALV  # carcasa blocului de condensatoare
IRON = W.IRON
CRYS, CRYS_VIO, CRYS_LINE, CRYS_GLOW = A1.CRYS, A1.CRYS_VIO, A1.CRYS_LINE, A1.CRYS_GLOW
# mantaua cablului: cauciuc negru-albastrui, doar cat sa se desprinda din conturul maro (cel mai inchis ton ~ 0,20 din valoare)
SHEATH = ramp(222, 0.24, 0.44, hue_shift=6, val_span=0.54)
# lingoul de cristal copt: lila-argintiu, mai deschis si mai putin saturat decat cristalul brut, ca sa nu semene cu el
LILAC = ramp(268, 0.44, 0.68, hue_shift=10, val_span=0.52)
INGOT_LINE = (36, 24, 76, 255)  # conturul lingoului: prun inchis (cristalul are indigo, fierul maro)
WHITE = (246, 248, 255, 255)

GOODS = ("barrel", "cable", "grid", "crystal", "ingot")


# ---------------------------------------------------------------------------------------------
# fasii cu contur la alegere (d55._load / d55._pile scriu mereu conturul maro)


def _strip_of(draw, steps, w, h, line_col):
    frames = []
    for step in steps:
        c = C(w, h)
        draw(c, step)
        outline_trace(c, line_col)
        frames.append(c)
    return d55.strip(frames)


def load_strip(draw, line_col=OUTLINE):
    """Incarcatura din roaba: 3 trepte de 16x9."""
    return _strip_of(draw, (1, 2, 3), 16, 9, line_col)


def pile_shadow(c, step, cx=20):
    """Umbra moale a gramezii: creste cu treapta, dar ramane in cadrul de 40 px (x = 1..38), ca sa nu fie taiata la margine."""
    soft_shadow(c, cx, 25, min(8 + step * 3, 18), 2)


def pile_strip(draw, line_col=OUTLINE):
    """Gramada: 4 trepte de 40x28, baza pe randul 26."""
    return _strip_of(draw, (1, 2, 3, 4), 40, 28, line_col)


def icon_of(draw, line_col=OUTLINE):
    c = C(24, 18)
    draw(c)
    outline_trace(c, line_col)
    return c


# ---------------------------------------------------------------------------------------------
# BARIL: stejar cu cercuri de alama, plin de baterii


def _keg_half(w, nb, r):
    """Semilatimea (in pixeli, de la mijloc) a randului `r` din cele `nb` ale corpului: pantecele bombat."""
    t = (r + 0.5) / nb
    return (w - 1) / 2.0 * (0.88 + 0.12 * math.sin(math.pi * t) ** 0.7)


def keg(c, x0, y0, w, h, bands, batteries=True, lit=True, lid_h=3, dim=False, lugs=False):
    """Un baril vertical: capac eliptic deschis (cu capetele bateriilor), corp bombat din doage, cercuri de alama.
    (x0, y0) = coltul stanga-sus al capacului; w, h = latimea maxima si inaltimea (capac + corp); `lid_h` = randurile
    capacului (3 la cel mic, 5 la cel mare). `bands` = randurile corpului pe care stau cercurile. `dim` = baril din spatele
    gramezii: cercuri mai stinse (BRASS 1-2) si un singur capat de borcan pe capac, ca randurile din spate sa nu para un fagure
    auriu. `lugs` = cercul iese cate un pixel pe ambele laturi (doar la pictograma mare)."""
    cx = x0 + (w - 1) / 2.0
    cy = y0 + lid_h // 2
    nb = h - lid_h // 2  # randurile corpului, de la mijlocul capacului in jos
    xl, xr = x0, x0 + w - 1
    # corpul
    for r in range(nb):
        y = cy + r
        hw = _keg_half(w, nb, r)
        for x in range(xl, xr + 1):
            if abs(x - cx) > hw + 0.01:
                continue
            u = (x - xl) / max(1, xr - xl)
            k = 3 if u < 0.22 else 2 if u < 0.50 else 1 if u < 0.78 else 0
            if (x - xl) % 3 == 2 and u < 0.9:  # rostul dintre doage
                k = max(0, k - 1)
            if dim:  # randurile din spate se retrag: stejarul cu un ton mai inchis
                k = max(0, k - 1)
            c.put(x, y, OAK[k])
    # cercurile
    def hoop(r):
        y = cy + r
        hw = _keg_half(w, nb, r)
        for x in range(xl, xr + 1):
            if abs(x - cx) > hw + 0.01:
                continue
            u = (x - xl) / max(1, xr - xl)
            if dim:
                c.put(x, y, BRASS[2] if u < 0.40 else BRASS[1])
            else:
                c.put(x, y, BRASS[3] if u < 0.30 else BRASS[2] if u < 0.62 else BRASS[1])
        if lugs:  # cercul trece peste doage pe ambele parti (lumina stanga-sus: stanga luminata, dreapta in umbra)
            c.put(round(cx - hw), y, BRASS[4])
            c.put(round(cx + hw), y, BRASS[1])

    for r in bands:
        hoop(r)
    # capacul: la fel de lat ca primul rand al corpului (altfel iese in "urechi"), marginea luminata la stanga-sus, golul intunecat
    rx, ry = _keg_half(w, nb, 0), lid_h / 2.0
    for y in range(int(cy - lid_h // 2), int(cy + lid_h // 2) + 1):
        for x in range(xl, xr + 1):
            d = ((x - cx) / max(rx, 0.5)) ** 2 + ((y - cy) / ry) ** 2
            if d > 1.0 or abs(x - cx) > rx + 0.01:
                continue
            if lid_h == 3:
                inner = y == cy and abs(x - cx) <= rx - 1
            else:
                inner = d <= 0.50
            c.put(x, y, OAK[0] if inner else (OAK[4] if (x - cx) < 0 or (y - cy) < 0 else OAK[3]))
    for r in bands:  # un cerc care cade pe randurile capacului (pictograma mare) se repune peste buza: ca sa ocoleasca tot butoiul
        if cy + r <= cy + lid_h // 2:
            hoop(r)
    if not batteries:
        return
    if dim:  # un singur capat de sticla, putin spre stanga (doua puncte de culori diferite, la mijloc, aratau ca niste ochi)
        c.put(int(round(cx)) - 1, int(cy), GLASS[3])
        return
    if lid_h >= 5:  # capetele a trei borcane: sticla, capac de alama, borna de cupru / zinc; cel din mijloc iese mai sus
        for i, dx in enumerate((-3, 0, 3)):
            sx = int(round(cx + dx))
            top = int(cy) - 2 - (1 if i == 1 else 0)
            c.rect(sx - 1, top + 1, 2, 2, GLASS[2])
            c.put(sx - 1, top + 1, GLASS[4])
            c.rect(sx - 1, top, 2, 1, BRASS[3])
            c.put(sx - 1, top - 1, (COPPER[4], STEEL[4], COPPER[4])[i])
        if lit:
            c.put(int(round(cx)) + 1, int(cy) - 5, SPARK[4])
    else:  # trei borne pe randul intunecat al capacului: cupru, scanteie (sticla cand nu arde), zinc
        for i, dx in enumerate((-1, 0, 1)):
            tone = (COPPER[4], SPARK[4] if lit else GLASS[3], STEEL[4])[i]
            c.put(int(round(cx + dx)), int(cy), tone)


def goods_barrel():
    # un singur baril, drept, la mijloc (barilul culcat repeta darul raului, treasure_barrel_water): randurile 2..15, scanteia pe 2
    def draw(c):
        soft_shadow(c, 12, 15, 8, 2)
        keg(c, 6, 5, 13, 11, bands=(2, 6), lid_h=5, lugs=True)
        # [directorul A4] randurile 10 si 12, cat cercurile: burta dreapta de la randul 9 la 13 (nu un pieptene la x1,5)
        for yy in (10, 12):
            c.put(6, yy, OAK[3])
            c.put(18, yy, OAK[0])

    return icon_of(draw)


def prop_load_barrel():
    def draw(c, step):
        # in vedere laterala se vad doar primele 6 randuri: capacul, doagele de sus si primul cerc; tot corpul in coloanele 1..14
        if step == 1:
            keg(c, 5, 1, 7, 8, bands=(2, 5), lit=False)
        elif step == 2:
            keg(c, 1, 1, 7, 8, bands=(2, 5), lit=False)
            keg(c, 8, 1, 7, 8, bands=(2, 5), lit=False)
        else:
            keg(c, 4, 1, 7, 8, bands=(2, 5), lit=False, dim=True)  # cel din spate, sus, mai stins
            keg(c, 1, 3, 7, 8, bands=(2, 5), lit=False)
            keg(c, 8, 3, 7, 8, bands=(2, 5), lit=False)

    return load_strip(draw)


def prop_pile_barrel():
    """Barili in picioare, pe randuri care se pierd spre fund (fiecare rand mai sus cu 4 px): depozitul unui sat de curent.
    Randul din fata are alama aprinsa si borcane la vedere; cele din spate, cercuri stinse si un singur capat de sticla."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3, 2], 4: [4, 3, 4, 3]}

    def draw(c, step):
        pile_shadow(c, step)
        rows = rows_by_step[step]
        layout = []
        for i, count in enumerate(rows):  # i = 0 e randul din fata
            total = count * 9 - 2
            layout.append((count, 20 - total // 2, 17 - i * 4, i > 0))
        for count, x, y, back in reversed(layout):  # din spate spre fata
            for k in range(count):
                keg(c, x + k * 9, y, 7, 9, bands=(4,) if back else (2, 6), lit=False, dim=back)

    return pile_strip(draw)


# ---------------------------------------------------------------------------------------------
# CABLU: tambur pe cant, ca prop_cable_drums din Era 3 (d70_modern._drum_standing), dar din otel galvanizat cu manta neagra

# Bobina din Era 3 sta pe cant: flansa rotunda din fata, cablul ca o semiluna sus-dreapta. Aici flansele sunt de otel
# galvanizat (deschise, cu nituri si butuc intunecat), iar mantaua de cauciuc e cea mai inchisa piesa: semiluna neagra-albastruie
# se desprinde de ambele flanse, deci nu seamana nici cu piatra barajului, nici cu cilindrul gri al bateriei.


def _winding(c, pts, ox, oy, mode):
    """Infasurarea mantalei: pe marginea de sus-dreapta a semilunii (cea dinspre flansa din spate) tonul se schimba, ca sa se vada
    cauciuc infasurat, nu o umbra pe roata (fara asta, semiluna dintr-un singur ton, langa flansa galvanizata, se citea ca umbra).
    `pts` = pixelii mantalei acestui tambur; se coloreaza doar cei ramasi la vedere (flansa din fata e deja desenata), iar marginea
    dinspre flansa din fata ramane cea intunecata. `mode` = 2: un pixel din doi pe tot arcul (pictograma); 1: un singur pixel pe
    arcul de sus (tamburii din gramada); 0: nimic (incarcatura, unde semiluna e prea ingusta). (ox, oy) = centrul ultimei spire."""
    if mode == 0:
        return
    dark = (SHEATH[0][:3], SHEATH[1][:3])
    edge = []
    for x, y in pts:
        if c.px[y][x][:3] not in dark or c.px[y][x][3] < 255:
            continue  # acoperit de flansa din fata
        if any((x + dx, y + dy) not in pts for dx, dy in ((0, -1), (1, 0), (1, -1))):
            edge.append((math.atan2(y - oy, x - ox), x, y))
    edge.sort()
    if mode == 2:
        for i, (_, x, y) in enumerate(edge):
            if i % 2 == 1:
                c.put(x, y, SHEATH[2])
    elif edge:
        _, x, y = min(edge, key=lambda e: abs(e[0] + 1.0))  # pixelul cel mai aproape de directia sus-dreapta
        c.put(x, y, SHEATH[2])


def reel(c, cx, cy, r, depth=3, tail=None, tip=False):
    """Tambur de cablu pe cant (axa spre privitor): flansa din spate mutata sus-dreapta, mantaua infasurata ca semiluna intre
    flanse, flansa din fata rotunda (galvanizat, cu gauri de usurare si nituri) si butucul intunecat. (cx, cy) = centrul flansei din
    fata; `r` = raza; `depth` = adancimea (cu cat iese flansa din spate). `tail` = (x, y) in care ajunge capatul liber, cu cupru.
    `tip` = un capat de cupru taiat in semiluna (la tamburii mici, unde nu incape un capat intreg). La incarcatura (r = 3) spirele
    mantalei ajung pana la centrul flansei din spate, ca semiluna sa fie lata de 2 pixeli, iar capatul de cupru sta pe ea."""
    rim = 1.7 if r >= 5 else 1.0 if r >= 4 else 0.3  # la incarcatura (r = 3) manta ajunge aproape pana la marginea flansei din spate
    bx, by = cx + depth, cy - depth * 0.7
    c.ellipse(bx, by, r, r, GALV[0])  # flansa din spate, in umbra
    c.ellipse(bx - 0.5, by + 0.5, r - 0.9, r - 0.9, GALV[1])
    sheath = C(c.w, c.h)  # mantaua, spira dupa spira (doua tonuri alternate = infasurat), intai separat: ii trebuie multimea de pixeli
    for k in range(depth):
        rr = r - rim
        # la incarcatura (r = 3) spirele ajung pana la centrul flansei din spate, ca semiluna sa fie lata de 2 pixeli
        sh = 1.0 if r < 4 else 0.5
        sheath.ellipse(cx + k + sh, cy - (k + sh) * 0.7, rr, rr, SHEATH[1] if k % 2 else SHEATH[0])
    pts = {(x, y) for y in range(c.h) for x in range(c.w) if sheath.px[y][x][3] == 255}
    flange = (GALV[0][:3], GALV[1][:3])
    for y in range(c.h):  # un pixel de flansa intre doua de manta (spirele se rotunjesc) rupea semiluna in doua
        for x in range(1, c.w - 1):
            if c.px[y][x][:3] in flange and (x - 1, y) in pts and (x + 1, y) in pts and (x, y) not in pts:
                sheath.put(x, y, SHEATH[1])
                pts.add((x, y))
    for x, y in pts:
        c.put(x, y, sheath.px[y][x])
    if tail is not None:  # capatul liber: coboara de pe flansa din spate pana pe pamant
        sx, sy = round(bx + r - 1.4), round(by + 1)
        line(c, sx, sy, tail[0], tail[1], SHEATH[1], 1)
        c.put(tail[0] + 1, tail[1], COPPER[3])
        c.put(tail[0] + 2, tail[1], COPPER[4])
        c.put(tail[0] + 1, tail[1] - 1, COPPER[2])
    if tip:  # capatul taiat al cablului, pe semiluna sus-dreapta
        tx, ty = round(bx + r * 0.35), round(by - r * 0.55)
        if r < 4:  # la incarcatura capatul sta pe cauciuc, cu un rand de manta deasupra, nu pe contur
            tx, ty = tx - 1, ty + 1
        c.put(tx, ty, COPPER[3])
        c.put(tx + 1, ty, COPPER[4])
    c.ellipse(cx, cy, r, r, GALV[1])  # flansa din fata: margine, apoi corp, apoi lumina sus-stanga
    c.ellipse(cx - 0.4, cy - 0.4, r - 0.9, r - 0.9, GALV[2])
    c.ellipse(cx - 1.0, cy - 1.0, r - 2.2, r - 2.2, GALV[3])
    _winding(c, pts, cx + depth - 0.5, cy - (depth - 0.5) * 0.7, 2 if r >= 5 else 1 if r >= 4 else 0)
    for a in range(195, 265, 14):  # muchia luminata, sus-stanga
        c.put(round(cx + math.cos(math.radians(a)) * (r - 0.9)), round(cy + math.sin(math.radians(a)) * (r - 0.9)), GALV[4])
    if r >= 5:
        for a in range(0, 360, 60):  # gaurile de usurare: se vede mantaua prin ele
            gx, gy = round(cx + math.cos(math.radians(a + 30)) * r * 0.64), round(cy + math.sin(math.radians(a + 30)) * r * 0.64)
            c.put(gx, gy, SHEATH[0])
        for a in range(0, 360, 60):  # niturile, pe marginea flansei
            tone = GALV[4] if 180 <= a <= 300 else GALV[1]
            c.put(round(cx + math.cos(math.radians(a)) * (r - 1.2)), round(cy + math.sin(math.radians(a)) * (r - 1.2)), tone)
        c.ellipse(cx, cy, r * 0.30, r * 0.30, IRON[2])  # butucul
        c.ellipse(cx - 0.2, cy - 0.2, r * 0.18, r * 0.18, IRON[0])
    elif r >= 4:  # pile: butuc de 3x3 (centrul intunecat) si patru gauri pe diagonale
        hx, hy = round(cx - 0.5), round(cy - 0.5)
        c.rect(hx - 1, hy - 1, 3, 3, IRON[2])
        c.put(hx, hy, IRON[0])
        for dx, dy in ((-2, -2), (2, -2), (-2, 2), (2, 2)):
            c.put(hx + dx + (1 if dx > 0 else 0), hy + dy + (1 if dy > 0 else 0), SHEATH[0])
    else:  # incarcatura: un butuc de 2x2 intunecat
        hx, hy = round(cx - 0.5), round(cy - 0.5)
        c.rect(hx, hy, 2, 2, IRON[0])
        c.put(hx, hy, IRON[1])


def goods_cable():
    def draw(c):
        soft_shadow(c, 12, 15, 9, 2)
        reel(c, 9.0, 10.0, 6.5, depth=4, tail=(19, 15))

    return icon_of(draw)


def prop_load_cable():
    # tamburi pe cant de r = 3 (1 / 2 / 3), cu partea de sus peste buza roabei; tot corpul ramane in coloanele 1..14,
    # iar un capat de cupru iese din semiluna celor din fata, ca sa se citeasca "cablu" si nu "disc de piatra"
    def draw(c, step):
        if step == 1:
            reel(c, 6.5, 4.5, 3.0, depth=2, tip=True)
        elif step == 2:
            reel(c, 4.5, 4.5, 3.0, depth=2)
            reel(c, 9.5, 4.5, 3.0, depth=2, tip=True)
        else:
            reel(c, 6.5, 4.5, 3.0, depth=2)  # cel din spate, sus
            reel(c, 4.5, 5.5, 3.0, depth=2)
            reel(c, 9.5, 5.5, 3.0, depth=2, tip=True)  # [directorul A4] capatul de cupru pe tamburul din fata-dreapta, vizibil

    return load_strip(draw)


def prop_pile_cable():
    """Tamburi de cablu pe cant, stivuiti in piramida (1 / 2 / 3 / 3+2), cu flanse de otel si manta neagra: grei si rotunzi
    (barilul e cald si drept), cu un capat de cupru scos jos-dreapta si cate unul taiat in semiluna."""
    low = 21.5  # centrul randului de jos (baza pe randul 26)
    layouts = {
        1: ([(17.5, low)], (22, 25)),
        2: ([(12.0, low), (22.5, low)], (31, 25)),
        3: ([(8.0, low), (18.5, low), (29.0, low)], (34, 25)),
        4: ([(8.0, low), (18.5, low), (29.0, low), (13.0, low - 8), (23.5, low - 8)], (34, 25)),
    }

    def draw(c, step):
        pile_shadow(c, step, 19)
        drums, tail = layouts[step]
        for i, (x, y) in enumerate(sorted(drums, key=lambda d: d[1])):  # randul de sus intai
            last = i == len(drums) - 1  # ultimul de jos, din dreapta: are capatul liber
            reel(c, x, y, 4.5, depth=3, tail=tail if last else None, tip=(i % 2 == 0 and not last))

    return pile_strip(draw)


# ---------------------------------------------------------------------------------------------
# CURENT: blocuri de condensatoare cu tuburi cian si arc intre borne

def bolt(c, pts):
    """Un fulger opac pe doua randuri, intre punctele `pts` (linii drepte): miez alb, iar pe latura jos-dreapta o umbra SPARK[3].
    Fara aureola translucida: pe iarba sau pe avizier aureola iesea o spuma verzuie, iar fulgerul parea un sir de margele."""
    path = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(n + 1):
            path.append((round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)))
    for x, y in path:  # umbra, doar pe pixelii goi
        for dx, dy in ((1, 0), (0, 1)):
            if 0 <= x + dx < c.w and 0 <= y + dy < c.h and c.px[y + dy][x + dx][3] == 0:
                c.put(x + dx, y + dy, SPARK[3])
    for x, y in path:
        c.put(x, y, WHITE)


def spark_arc(c, x0, x1, y, rise=1):
    """Arcul dintre doua borne vecine: fulger opac, in zigzag de `rise` randuri, de la (x0, y) la (x1, y)."""
    pts = [(x0, y)]
    n = max(1, x1 - x0)
    for i in range(1, n):
        pts.append((x0 + i, y - rise if i % 2 == 1 else y))
    pts.append((x1, y))
    bolt(c, pts)


def power_pack(c, x, y, w, h, pins=True):
    """Un bloc de condensatoare, in picioare: placa de alama sub capac, carcasa galvanizata cu nituri si, in fereastra
    intunecata, tuburi care lumineaza cian; doua borne de alama deasupra, cu varful aprins. (x, y) = coltul stanga-sus al
    carcasei (bornele stau pe randurile y-2 .. y-1); w x h = carcasa. Lumina din stanga-sus. Intoarce (borna stanga, borna
    dreapta) = x-urile bornelor, ca sa se poata trage arcuri intre blocuri vecine."""
    c.rect(x, y, w, h, GALV[2])
    c.rect(x, y, w, 1, GALV[4])  # capacul, luminat
    c.rect(x, y, 1, h, GALV[3])
    c.rect(x + w - 1, y, 1, h, GALV[0])
    c.rect(x + 1, y + h - 1, w - 1, 1, GALV[0])
    c.rect(x + 1, y + 1, w - 2, 1, BRASS[2])  # placa de alama
    c.put(x + 1, y + 1, BRASS[4])
    c.put(x + w - 2, y + 1, BRASS[0])
    # fereastra: tuburile (latime 2 la fereastra larga, 1 la cea ingusta) cu spatiu intre ele
    wx0, wx1 = x + 2, x + w - 3
    wy0 = y + 3
    wy1 = y + h - 2 if h <= 8 else y + h - 3
    ww = wx1 - wx0 + 1
    if ww >= 2 and wy1 >= wy0:
        c.rect(wx0, wy0, ww, wy1 - wy0 + 1, IRON[0])
        if ww >= 8:
            cols = [(0, 2), (4, 2), (8, 2)][: (ww + 2) // 4]
        elif ww >= 5:
            cols = [(0, 1), (2, 1), (4, 1)][: (ww + 1) // 2]
        else:
            cols = [(0, 1)] if ww == 2 else [(0, 1), (2, 1)]
        for off, tw in cols:
            c.rect(wx0 + off, wy0, tw, wy1 - wy0 + 1, SPARK[3])
            c.put(wx0 + off, wy0, WHITE)
            if wy1 - wy0 >= 3:
                c.rect(wx0 + off, wy1, tw, 1, SPARK[1])
        if h >= 8:  # nituri jos pe carcasa
            c.put(x + 1, y + h - 2, GALV[4])
            c.put(x + w - 2, y + h - 2, GALV[1])
    bx = (x + 2, x + w - 3)
    if pins:
        for i, b in enumerate(bx):
            c.rect(b, y - 2, 2 if w >= 9 else 1, 2, BRASS[3])
            c.put(b, y - 2, BRASS[4])
    return bx


def goods_grid():
    def draw(c):
        soft_shadow(c, 12, 15, 10, 2)
        power_pack(c, 5, 6, 14, 10)
        # capacul dintre borne: un rand de izolator ridicat (galvanizat luminat, mai stins spre dreapta), ca sub fulger sa nu ramana
        # o bara de contur; conturul trasat inconjoara apoi doar fulgerul
        for x in range(9, 16):
            c.put(x, 5, GALV[4] if x <= 12 else GALV[3])
        # fulgerul opac, pe doua randuri, intre cele doua borne
        bolt(c, [(8, 4), (10, 2), (12, 3), (14, 1), (16, 4)])

    return icon_of(draw)


def pack_small(c, x, y, lit=0):
    """Blocul mic din roaba (6 x 7): bornele sus (una aprinsa), capacul, placa de alama, fereastra cu doua tuburi cian pe
    primele randuri (se vad deasupra buzei cutiei), talpa. `lit`: 0 = borna stanga scanteie, 1 = a dreapta."""
    c.rect(x, y + 1, 6, 6, GALV[2])
    c.rect(x, y + 1, 6, 1, GALV[4])
    c.rect(x, y + 1, 1, 6, GALV[3])
    c.rect(x + 5, y + 1, 1, 6, GALV[0])
    c.rect(x + 1, y + 6, 5, 1, GALV[0])
    c.rect(x + 1, y + 2, 4, 1, BRASS[2])
    c.put(x + 1, y + 2, BRASS[4])
    c.rect(x + 1, y + 3, 4, 3, IRON[0])
    for tx in (x + 1, x + 3):
        c.rect(tx, y + 3, 1, 3, SPARK[3])
        c.put(tx, y + 3, WHITE)
    c.put(x + 1, y, SPARK[4] if lit == 0 else BRASS[3])
    c.put(x + 4, y, BRASS[3] if lit == 0 else SPARK[4])


def prop_load_grid():
    # blocuri mici de 6 x 7, toate in coloanele 1..14 (conturul are loc pe 0 si 15)
    def draw(c, step):
        if step == 1:
            pack_small(c, 5, 1)
        elif step == 2:
            pack_small(c, 2, 1)
            pack_small(c, 8, 1, lit=1)
        else:
            pack_small(c, 5, 1)  # cel din spate, sus
            pack_small(c, 2, 3, lit=1)
            pack_small(c, 9, 3)

    return load_strip(draw)


def prop_pile_grid():
    """Blocuri de condensatoare in rafturi, ca niste lazi, cu bornele doar pe randul de sus si arcuri intre ele: se vede ca au
    curent, iar tuburile cian le despart de lingourile violete."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3], 4: [4, 3, 2]}

    def draw(c, step):
        pile_shadow(c, step)
        rows = rows_by_step[step]
        n = len(rows)
        pitch = 7 if n >= 3 else 8  # trei randuri: mai strans, ca bornele de sus sa nu iasa din cadru (randurile 2-3, cu contur pe 1)
        layout = []
        for i, count in enumerate(rows):
            total = count * 9 - 1
            x0 = 20 - total // 2
            if x0 + count * 9 >= 39:  # randul de patru: cu un pixel spre stanga, ca si conturul sa ramana in cadrul de 40 px
                x0 -= 1
            layout.append((count, x0, 25 - pitch * (i + 1) + 1, i == n - 1))
        for count, x, y, top in reversed(layout):  # randul de sus intai (bornele lui stau peste capacele de jos)
            bxs = []
            for k in range(count):
                bxs.append(power_pack(c, x + k * 9, y, 9, 8, pins=top))
            if top:
                for k in range(count - 1):  # arcul sare de la borna dreapta a unui bloc la cea stanga a urmatorului
                    if (k + step) % 2 == 0:
                        spark_arc(c, bxs[k][1] + 2, bxs[k + 1][0] - 1, y - 2, rise=1)
                c.put(bxs[0][0], y - 3, SPARK[4])  # varfurile celor doua capete ale randului, aprinse
                if count > 1:
                    c.put(bxs[-1][1] + 1, y - 3, WHITE)

    return pile_strip(draw)


# ---------------------------------------------------------------------------------------------
# CRISTAL: prisme cu fatete, ca la A1

BLUE_T = (CRYS[3], CRYS[2], CRYS[1], CRYS[0])  # fateta luminata, mijloc, umbra, adanc (ca la A1)
VIO_T = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])


def crystal(c, cx, base, h, w, lean=0, tones=BLUE_T, core=False, stub=False, bright=False):
    """O prisma de cristal cu varful ascutit, ca la A1 (a1_pylons._facet_rows): fateta stanga luminata, cea dreapta in umbra,
    un mijloc la cele late. `base` = randul de jos, `h` = inaltimea, `w` = latimea, `lean` = cu cate coloane se apleaca varful
    (negativ = spre stanga). `core` = un miez aprins pe mijloc. `stub` = prisma scurta si groasa (latimea creste cu 1 pe rand),
    ca partea colorata sa stea chiar sub varf. `bright` = varful si un rand de sub el in alb-albastru (CORE_BRIGHT)."""
    rows = []
    for i in range(h):  # i = 0 e varful
        y = base - h + 1 + i
        if stub:
            ww = min(w, 1 + i)
        else:
            ww = min(w, 1 + (i + 1) // 2) if i < 2 * (w - 1) else w
        shift = lean * (1.0 - i / max(1, h - 1))  # varful e cel mai departe de axa
        x0 = round(cx - (ww - 1) / 2.0 + shift)
        rows.append((y, x0, x0 + ww - 1))
    A1._facet_rows(c, rows, tones)
    if core and h >= 6:
        mid = [r for r in rows if r[0] >= base - h + 3 and r[0] <= base - 2]
        for y, x0, x1 in mid:
            c.put((x0 + x1) // 2, y, A1.CORE_BRIGHT)
    if bright:
        y, x0, x1 = rows[0]
        c.put(x0, y, A1.CORE_BRIGHT)  # varful
        if len(rows) > 2:
            y, x0, x1 = rows[2]  # si mijlocul celui de-al treilea rand, ca miezul sa se vada si cand roaba ascunde restul
            c.put((x0 + x1) // 2, y, A1.CORE_BRIGHT)


def lying(c, x, base, length, tones, flip=False):
    """Un cioc de cristal culcat pe pamant (prisma orizontala cu varful ascutit): sus lumina, la mijloc tonul de baza, jos umbra,
    cu un pixel aprins pe muchia de sus. `x` = capatul gros, `length` = pana la varf; `flip` = varful spre stanga."""
    sgn = -1 if flip else 1
    for y, a, b, tone in ((base - 2, 0, length - 3, tones[0]), (base - 1, 0, length - 1, tones[1]), (base, 1, length - 2, tones[2])):
        for dx in range(a, b + 1):
            c.put(x + sgn * dx, y, tone)
    c.put(x + sgn * length, base - 1, tones[1])  # varful
    c.put(x + sgn * (length - 3), base - 2, A1.CORE_BRIGHT)


def sparkle(c, x, y, big=True, solid=False):
    """O sclipire: centrul alb, bratele translucide albastre (sau, cu `solid`, opace si palide: la 0,75x bratele translucide
    dispar si ramane doar un punct)."""
    c.put(x, y, (240, 246, 255, 255))
    if big:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if c.px[y + dy][x + dx][3] < 200:
                c.put(x + dx, y + dy, CRYS[4] if solid else (CRYS_GLOW[0] + 50, CRYS_GLOW[1] + 50, 255, 180))


def glow_floor(c, cx, cy, rx, ry, a=46):
    """Lumina cristalului pe pamant: o elipse albastra translucida, sub umbra moale."""
    c.ellipse(cx, cy, rx, ry, (CRYS_GLOW[0], CRYS_GLOW[1], CRYS_GLOW[2], a))


def goods_crystal():
    c = C(24, 18)
    glow_floor(c, 12, 15, 11, 3, 50)
    soft_shadow(c, 12, 15, 9, 2)
    crystal(c, 6, 15, 9, 4, lean=-2, tones=VIO_T)
    crystal(c, 18, 15, 8, 4, lean=2, tones=VIO_T)
    crystal(c, 12, 14, 13, 5, tones=BLUE_T, core=True)
    crystal(c, 9, 16, 5, 3, lean=-1, tones=BLUE_T)
    crystal(c, 15, 16, 6, 3, lean=1, tones=VIO_T)
    outline_trace(c, CRYS_LINE)
    sparkle(c, 15, 2, solid=True)  # dupa contur, ca sa nu primeasca ram; bratul stang atinge varful spirei inalte (izolata, la 0,75x ramanea un punct)
    return c


def prop_load_crystal():
    # prisme scurte si groase (h 5-7, baza pe randul 7), ca partea colorata sa fie in primele randuri, cele de deasupra buzei roabei;
    # cristalul mare e albastru cu miez aprins, cele din fata violete cu fateta luminata; tot corpul in coloanele 1..14
    def draw(c, step):
        if step == 1:
            crystal(c, 7, 7, 6, 5, tones=BLUE_T, stub=True, bright=True)
            crystal(c, 4, 7, 4, 3, lean=-1, tones=VIO_T, stub=True)
            crystal(c, 10, 7, 4, 3, lean=1, tones=VIO_T, stub=True)
        elif step == 2:
            crystal(c, 9, 7, 6, 5, tones=BLUE_T, stub=True, bright=True)
            crystal(c, 4, 7, 6, 4, lean=-1, tones=VIO_T, stub=True, bright=True)
            crystal(c, 7, 7, 4, 3, tones=BLUE_T, stub=True)
            crystal(c, 12, 7, 4, 3, lean=1, tones=VIO_T, stub=True)
        else:
            crystal(c, 7, 7, 7, 5, tones=BLUE_T, stub=True, bright=True)  # cel din spate
            crystal(c, 3, 8, 6, 4, lean=-1, tones=VIO_T, stub=True, bright=True)
            crystal(c, 11, 8, 6, 4, lean=1, tones=VIO_T, stub=True, bright=True)
            crystal(c, 7, 8, 4, 3, tones=VIO_T, stub=True)

    return load_strip(draw, CRYS_LINE)


def prop_pile_crystal():
    """Un morman de ciobi de cristal, tot mai larg si mai inalt, cu lumina albastra pe pamant: ciobi in picioare, mai scunzi spre
    margini, si cativa culcati la baza (`lying`), ca sa arate depozit, nu un afloriment. La margini stau ciobi scurti si grosi
    (`stub`), nu lame subtiri aplecate, care in joc, la x2, se citeau ca fire de iarba si atingeau marginea cadrului. La treptele
    3-4 cate o sclipire. Fiecare cioc in picioare: (mijloc x, baza, inaltime, latime, aplecare, ton, miez[, True = cioc scurt si gros]);
    culcati: (capatul gros, lungime, ton, spre stanga)."""
    B, V = BLUE_T, VIO_T
    heaps = {
        1: (
            [(20, 26, 8, 4, 0, B, True), (15, 26, 5, 3, -1, V, False), (25, 26, 5, 3, 1, V, False), (10, 26, 3, 4, 0, B, False, True)],
            [(26, 5, V, True)],
        ),
        2: (
            [
                (20, 26, 11, 4, 0, B, True),
                (14, 26, 8, 4, -2, V, False),
                (26, 26, 8, 4, 2, V, False),
                (9, 26, 4, 4, 0, B, False, True),
                (31, 26, 4, 4, 0, B, False, True),
                (17, 26, 6, 3, -1, B, False),
                (23, 26, 6, 3, 1, V, False),
            ],
            [(13, 6, V, False), (28, 5, B, True)],
        ),
        3: (
            [
                (20, 26, 13, 5, 0, B, True),
                (14, 26, 10, 4, -2, V, False),
                (26, 26, 10, 4, 2, V, False),
                (9, 26, 8, 4, -2, B, False),
                (31, 26, 8, 4, 2, B, False),
                (6, 26, 5, 4, 0, V, False, True),
                (34, 26, 5, 4, 0, V, False, True),
                (17, 26, 7, 3, -1, B, False),
                (23, 26, 7, 3, 1, V, False),
            ],
            [(9, 6, B, False), (31, 6, V, True)],
        ),
        4: (
            [
                (20, 26, 17, 5, 0, B, True),
                (14, 26, 13, 5, -2, V, False),
                (26, 26, 13, 5, 2, B, False),
                (9, 26, 10, 4, -2, B, False),
                (31, 26, 10, 4, 2, V, False),
                (6, 26, 6, 4, 0, V, False, True),
                (34, 26, 6, 4, 0, B, False, True),
                (17, 26, 9, 4, -1, V, False),
                (23, 26, 9, 4, 1, B, False),
                (11, 26, 6, 3, -1, B, False),
                (29, 26, 6, 3, 1, V, False),
            ],
            [(8, 6, V, False), (14, 5, B, False), (32, 6, B, True), (26, 5, V, True)],
        ),
    }

    def draw(c, step):
        spread = {1: 7, 2: 12, 3: 17, 4: 19}[step]
        # aura si umbra raman in cadru (x = 3..37): la treptele 3-4 o elipsa mai larga ar fi taiata drept de marginea celor 40 px
        glow_floor(c, 20, 25, min(spread + 4, 16), 3, 52)
        soft_shadow(c, 20, 25, min(spread + 2, 17), 2)
        standing, lay = heaps[step]
        for cx, base, h, w, lean, tones, core, *flag in standing:  # flag = True: ciob scurt si gros (stub), la margine
            crystal(c, cx, base, h, w, lean=lean, tones=tones, core=core, stub=bool(flag))
        for x, length, tones, flip in lay:  # culcatii, la baza, peste picioarele celor in picioare
            lying(c, x, 26, length, tones, flip=flip)

    sheet = pile_strip(draw, CRYS_LINE)
    for step, (sx, sy) in ((2, (26, 8)), (3, (26, 4))):  # sclipirile, doar la treptele 3-4, dupa contur
        sparkle(sheet, step * 40 + sx, sy)
    return sheet


# ---------------------------------------------------------------------------------------------
# LINGOUL: cristal copt, bare in forma de gema


def gem_bar(c, x, y, w):
    """O bara de cristal copt (w x 4), turnata: fata de sus mai ingusta (cu un rand inset: 1 px, 2 la barele late), luminata, cu o
    sclipire de sticla; sub ea trei randuri pe toata latimea, cu o dunga de cristal aprins pe fata din fata; jos, randul cel mai
    lat si cel mai inchis, cu capatul din dreapta in umbra. Trapez, nu pastila: baza e mai lata decat fata de sus."""
    inset = 2 if w >= 9 else 1
    c.rect(x + inset, y, w - 2 * inset, 1, LILAC[4])
    c.rect(x, y + 1, w, 1, LILAC[3])
    c.put(x, y + 1, LILAC[4])
    c.rect(x, y + 2, w, 1, LILAC[2])
    c.rect(x, y + 3, w, 1, LILAC[1])
    c.put(x + w - 1, y + 2, LILAC[1])
    c.put(x + w - 1, y + 3, LILAC[0])
    c.put(x + inset + 1, y, WHITE)  # sticla
    if w >= 7:  # miezul aprins: o dunga de cristal pe fata din fata
        c.rect(x + 2, y + 2, w - 4, 1, CRYS[3])
        c.put(x + 2, y + 2, CRYS[4])


def goods_ingot():
    def draw(c):
        soft_shadow(c, 12, 15, 10, 2)
        gem_bar(c, 3, 10, 9)
        gem_bar(c, 12, 10, 9)
        gem_bar(c, 7, 6, 10)

    return icon_of(draw, INGOT_LINE)


def prop_load_ingot():
    # bare de 7-8 px, toate in coloanele 1..14 (conturul prun are loc pe 0 si 15)
    def draw(c, step):
        if step == 1:
            gem_bar(c, 4, 2, 8)
        elif step == 2:
            gem_bar(c, 1, 2, 7)
            gem_bar(c, 8, 2, 7)
        else:
            gem_bar(c, 1, 3, 7)
            gem_bar(c, 8, 3, 7)
            gem_bar(c, 4, 1, 7)  # cea din spate, peste cele doua

    return load_strip(draw, INGOT_LINE)


def prop_pile_ingot():
    """Bare de cristal copt in piramida (fierul sta in randuri dreptunghiulare): lila, cu fata de sus luminata si cate o dunga
    de miez aprins. Barele se ating (pas 7), ca sa incapa cinci pe randul de jos la treapta 4."""
    rows_by_step = {1: [2], 2: [3, 2], 3: [4, 3, 2], 4: [5, 4, 3, 2, 1]}

    def draw(c, step):
        pile_shadow(c, step)
        y = 22
        for i, count in enumerate(rows_by_step[step]):
            total = count * 7
            x = 20 - total // 2
            for k in range(count):
                gem_bar(c, x + k * 7, y, 7)
            y -= 4

    return pile_strip(draw, INGOT_LINE)


SPRITES = {}
SIZES = {}
for _n in GOODS:
    SPRITES["goods_" + _n] = globals()["goods_" + _n]
    SIZES["goods_" + _n] = (24, 18)
    SPRITES["prop_load_" + _n] = globals()["prop_load_" + _n]
    SIZES["prop_load_" + _n] = (48, 9)
    SPRITES["prop_pile_" + _n] = globals()["prop_pile_" + _n]
    SIZES["prop_pile_" + _n] = (160, 28)

# ---------------------------------------------------------------------------------------------
# previzualizarea: foaia x4 (desen nou langa cel imprumutat), incarcaturile in roaba si gramezile pe pamantul barajului

# ce desenau pana acum (GOOD_LOOKS_LIKE): bunul -> gemenul imprumutat
TWIN = {"barrel": "cell", "cable": "coils", "grid": "copper", "crystal": "parts", "ingot": "iron"}
# locurile gramezilor, in pixeli de lume (inventarul: LINE_PLACES / JOIN_PLACES / SELLER_PLACES, lumea 2)
PLACES = {
    "barrel": [("Switchyard out", 1195, 1380), ("Relay in", 1961, 1380)],
    "cable": [("Cable Works out", 1615, 1380), ("Relay in", 2089, 1380)],
    "grid": [("Relay out", 2361, 1380), ("Switch House pile", 1901, 1086)],
    "crystal": [("Crystal Shed store", 2595, 1010), ("Kiln in", 2699, 1380)],
    "ingot": [("Kiln out", 2971, 1380), ("Switch House pile", 1901, 1086)],
}
D = 3  # un pixel de arta = 3 de lume
PROP_SCALE = 2  # recuzita (gramezile) la x2
# unde sta incarcatura in cadrul roabei (24x20), dupa PersonView.BARROW_AT: vedere -> (cadrul roabei, x, y, desenata peste roaba?)
BARROW_AT = {"side": (0, 6, 2, False), "down": (1, 4, 3, False), "up": (2, 4, 0, True)}
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"


def _img(c):
    from PIL import Image

    im = Image.new("RGBA", (c.w, c.h))
    im.putdata([p for row in c.px for p in row])
    return im


def _spr(name):
    from PIL import Image

    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


def _ground():
    """Pamantul copt al barajului (doua felii) peste dala raului, un pixel de arta = 3 de lume."""
    from PIL import Image

    g1, g2 = _spr("prop_dam_ground"), _spr("prop_dam_ground_2")
    water = _spr("water_tile")
    base = Image.new("RGBA", (g1.width + g2.width, g1.height))
    for y in range(0, base.height, water.height):
        for x in range(0, base.width, water.width):
            base.paste(water, (x, y))
    base.alpha_composite(g1, (0, 0))
    base.alpha_composite(g2, (g1.width, 0))
    return base.resize((base.width * D, base.height * D), Image.NEAREST)


def _frame(sheet, n, k):
    w = sheet.width // n
    return sheet.crop((k * w, 0, (k + 1) * w, sheet.height))


def _barrow_cell(barrow, load, view, step):
    """Roaba (cadrul vederii) cu incarcatura la locul ei din PersonView: sub desenul roabei lateral si din fata, peste ea din spate."""
    from PIL import Image

    fr, lx, ly, over = BARROW_AT[view]
    cell = Image.new("RGBA", (24, 20))
    art = _frame(barrow, 3, fr)
    ld = _frame(load, 3, step - 1)
    if over:
        cell.alpha_composite(art)
        cell.alpha_composite(ld, (lx, ly))
    else:
        cell.alpha_composite(ld, (lx, ly))
        cell.alpha_composite(art)
    return cell


def build_preview(out, sprites):
    from PIL import Image, ImageDraw, ImageFont

    try:
        f8 = ImageFont.truetype(FONT, 8)
    except OSError:
        f8 = ImageFont.load_default()
    imgs = {n: _img(c) for n, c in sprites.items()}
    ground = _ground()
    barrow_wood, barrow_iron = _spr("prop_barrow"), _spr("prop_barrow_iron")
    GREEN, DIRT = (86, 128, 64, 255), (120, 88, 62, 255)

    def big(im, k):
        return im.resize((im.width * k, im.height * k), Image.NEAREST)

    W = 1500
    # --- A: foaia x4, desen nou | desen imprumutat
    rowh = 96 + 30 + 4 * 28 + 44
    sheetA = Image.new("RGBA", (W, 36 + rowh * 5), (44, 48, 56, 255))
    d = ImageDraw.Draw(sheetA)
    d.text((10, 10), "A  NEW GOODS X4 (LEFT) | THE BORROWED TWIN IT REPLACES (RIGHT)", font=f8, fill=(235, 235, 225, 255))
    for i, name in enumerate(GOODS):
        y0 = 36 + i * rowh
        tw = TWIN[name]
        d.text((10, y0), f"{name.upper()}  (now borrows {tw})", font=f8, fill=(255, 220, 120, 255))
        # pictograme
        for j, (im, tag) in enumerate(((imgs["goods_" + name], "goods_" + name), (_spr("goods_" + tw), "goods_" + tw))):
            x = 10 + j * 130
            d.rectangle([x, y0 + 16, x + 24 * 4 + 7, y0 + 16 + 18 * 4 + 7], fill=GREEN)
            sheetA.alpha_composite(big(im, 4), (x + 4, y0 + 20))
        # incarcaturi
        for j, im in enumerate((imgs["prop_load_" + name], _spr("prop_load_" + tw))):
            x = 290 + j * 220
            d.rectangle([x, y0 + 16, x + 48 * 4 + 7, y0 + 16 + 9 * 4 + 7], fill=GREEN)
            sheetA.alpha_composite(big(im, 4), (x + 4, y0 + 20))
        # gramezi
        for j, im in enumerate((imgs["prop_pile_" + name], _spr("prop_pile_" + tw))):
            x = 10 + j * 740
            y = y0 + 16 + 18 * 4 + 14
            d.rectangle([x, y, x + 160 * 4 + 7, y + 28 * 4 + 7], fill=DIRT)
            sheetA.alpha_composite(big(im, 4), (x + 4, y + 4))
    # --- B: incarcaturile in roaba (3 vederi x 3 trepte pe roaba de lemn, apoi 3 trepte pe cea de fier), x4
    cw, chh = 24 * 4 + 8, 20 * 4 + 8
    sheetB = Image.new("RGBA", (W, 36 + chh * 5 + 10), (44, 48, 56, 255))
    d = ImageDraw.Draw(sheetB)
    d.text((10, 10), "B  LOADS IN THE BARROW, X4 (SIDE / FRONT / BACK x STEPS 1-3, THEN THE IRON BARROW SIDE)", font=f8, fill=(235, 235, 225, 255))
    for i, name in enumerate(GOODS):
        y0 = 36 + i * chh
        d.text((4, y0 + 2), name[:3].upper(), font=f8, fill=(255, 220, 120, 255))
        k = 0
        load = imgs["prop_load_" + name]
        for view in ("side", "down", "up"):
            for step in (1, 2, 3):
                x = 40 + k * cw
                d.rectangle([x, y0, x + cw - 4, y0 + chh - 4], fill=GREEN)
                sheetB.alpha_composite(big(_barrow_cell(barrow_wood, load, view, step), 4), (x + 2, y0 + 2))
                k += 1
        for step in (1, 2, 3):
            x = 40 + k * cw
            d.rectangle([x, y0, x + cw - 4, y0 + chh - 4], fill=GREEN)
            sheetB.alpha_composite(big(_barrow_cell(barrow_iron, load, "side", step), 4), (x + 2, y0 + 2))
            k += 1
    # --- C: gramezile pe pamantul barajului, la locurile lor, x2 (patru trepte unele langa altele, apoi locul adevarat)
    zoom = 2
    rows = []
    for name in GOODS:
        for label, px, py in PLACES[name]:
            rows.append((name, label, px, py))
    cw_world, ch_world = 440, 150
    sheetC = Image.new("RGBA", (W, 36 + (ch_world * zoom + 28) * 5), (44, 48, 56, 255))
    d = ImageDraw.Draw(sheetC)
    d.text((10, 10), "C  PILES ON THE DAM GROUND AT THEIR REAL PLACES, X2 (STEPS 1-4 FROM LEFT, 100 WORLD PX APART)", font=f8, fill=(235, 235, 225, 255))
    for i, name in enumerate(GOODS):
        label, px, py = PLACES[name][0]
        y0 = 36 + i * (ch_world * zoom + 28)
        x0w, y0w = px - 190, py - 110
        crop = ground.crop((x0w, y0w, x0w + cw_world, y0w + ch_world)).copy()
        pile = imgs["prop_pile_" + name]
        for step in range(4):
            fr = _frame(pile, 4, step)
            fr = fr.resize((fr.width * PROP_SCALE, fr.height * PROP_SCALE), Image.NEAREST)
            cx = 190 - 150 + step * 100  # mijlocul gramezii in crop
            crop.alpha_composite(fr, (cx - fr.width // 2, 110 - fr.height))
        sheetC.alpha_composite(big(crop, zoom), (10, y0 + 14))
        d.text((10, y0), f"{name.upper()}  at {label} ({px},{py})", font=f8, fill=(255, 220, 120, 255))
        # al doilea loc, treapta 3, aceeasi scara
        label2, px2, py2 = PLACES[name][1]
        x0w2, y0w2 = px2 - 190, py2 - 110
        crop2 = ground.crop((x0w2, y0w2, x0w2 + cw_world, y0w2 + ch_world)).copy()
        for step, dx in ((2, -50), (3, 50)):
            fr = _frame(pile, 4, step)
            fr = fr.resize((fr.width * PROP_SCALE, fr.height * PROP_SCALE), Image.NEAREST)
            crop2.alpha_composite(fr, (190 + dx - fr.width // 2, 110 - fr.height))
        sheetC.alpha_composite(big(crop2, zoom), (10 + cw_world * zoom + 30, y0 + 14))
        d.text((10 + cw_world * zoom + 30, y0), f"also at {label2} ({px2},{py2}), steps 3 and 4", font=f8, fill=(255, 220, 120, 255))
    # --- D: scenele comune: Relay (baril + cablu la intrare, curentul la iesire) si Switch House (curent + lingou)
    sheetD = Image.new("RGBA", (W, 36 + 150 * 2 + 40 + 2 * (120 * 2 + 40) + 20), (44, 48, 56, 255))
    d = ImageDraw.Draw(sheetD)
    d.text((10, 10), "D  SHARED SPOTS, X2: THE RELAY (BARRELS + CABLE IN, POWER OUT) AND THE SWITCH HOUSE PILE (POWER + INGOTS)", font=f8, fill=(235, 235, 225, 255))

    def pile_at(crop, name, step, wx, wy, ox, oy, scale=PROP_SCALE):
        fr = _frame(imgs["prop_pile_" + name], 4, step - 1)
        fr = fr.resize((round(fr.width * scale), round(fr.height * scale)), Image.NEAREST)
        crop.alpha_composite(fr, (round(wx - ox - fr.width / 2), round(wy - oy - fr.height)))

    x0w, y0w, wd, ht = 1880, 1270, 560, 150
    relay = ground.crop((x0w, y0w, x0w + wd, y0w + ht)).copy()
    for name, step, wx in (("barrel", 3, 1961), ("cable", 3, 2089), ("grid", 3, 2361)):
        pile_at(relay, name, step, wx, 1380, x0w, y0w)
    sheetD.alpha_composite(big(relay, 2), (10, 36 + 14))
    d.text((10, 36), "RELAY: barrels (1961), cable (2089) in; power (2361) out, step 3 each", font=f8, fill=(255, 220, 120, 255))
    y1 = 36 + ht * 2 + 40
    for k, (main, second) in enumerate((("grid", "ingot"), ("ingot", "grid"))):
        x0t, y0t, wt, ht2 = 1780, 1000, 260, 120
        town = ground.crop((x0t, y0t, x0t + wt, y0t + ht2)).copy()
        for sstep in (1, 2):
            tc = town.copy()
            pile_at(tc, main, 3, 1901, 1086, x0t, y0t)
            # al doilea fel: la 70%, lipit in dreapta, cel mult treapta 2 (PileView)
            pile_at(tc, second, sstep, 1901 + 80 * 0.42, 1086 + 2, x0t, y0t, PROP_SCALE * 0.7)
            sheetD.alpha_composite(big(tc, 2), (10 + (sstep - 1) * (wt * 2 + 14), y1 + 14 + k * (ht2 * 2 + 40)))
        d.text((10, y1 + k * (ht2 * 2 + 40)), f"Switch House: {main} (step 3) + {second} second, steps 1 and 2", font=f8, fill=(255, 220, 120, 255))
    # --- E: pictogramele la scarile din joc (1,5x plutitor, 1,0x aviz, 0,75x plasa), pe iarba si pe pamant
    sheetE = Image.new("RGBA", (W, 36 + 5 * 96 + 10), (44, 48, 56, 255))
    d = ImageDraw.Draw(sheetE)
    d.text((10, 10), "E  ICONS AT THE IN-GAME SCALES (FLOATER 1.5X, BOARD 1X, NET STACK 0.75X), SHOWN X3", font=f8, fill=(235, 235, 225, 255))
    for i, name in enumerate(GOODS):
        im = imgs["goods_" + name]
        y0 = 36 + i * 96
        d.text((4, y0 + 40), name[:3].upper(), font=f8, fill=(255, 220, 120, 255))
        x = 50
        for sc in (1.5, 1.0, 0.75, 1.0):
            bg = GREEN if sc != 1.0 or x < 300 else DIRT
            sm = im.resize((round(im.width * sc), round(im.height * sc)), Image.NEAREST)
            d.rectangle([x, y0, x + 24 * 3 * 1.5 + 6, y0 + 94], fill=bg)
            sheetE.alpha_composite(big(sm, 3), (x + 3, y0 + 3))
            x += int(24 * 3 * 1.5 + 14)
    parts = (sheetA, sheetB, sheetC, sheetD, sheetE)
    total = sum(p.height for p in parts)
    plate = Image.new("RGBA", (W, total), (44, 48, 56, 255))
    y = 0
    for p in parts:
        plate.alpha_composite(p, (0, y))
        y += p.height
    plate.convert("RGB").save(os.path.join(out, "goods_preview.png"))
    for i, p in enumerate(parts):  # si cate o foaie, pentru citit pe rand
        p.convert("RGB").save(os.path.join(out, f"goods_preview_{'abcde'[i]}.png"))


def main():
    out = DEFAULT_OUT
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    made = {}
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        made[name] = c
        print(f"  {name}.png  {c.w}x{c.h}")
    build_preview(out, made)
    print("  preview:", os.path.join(out, "goods_preview.png"))


if __name__ == "__main__":
    main()
