#!/usr/bin/env python3
"""Sprite-urile F3: patru corecturi de lizibilitate cerute de owner dupa ce a vazut jocul, plus
piesa noua pentru upgrade-ul Weighted Nets.

  - prop_net_water(_full): plasa vazuta de sus, pe jumatate in apa -- net.png vechi citea ca o
    fereastra (rama de lemn pe toate 4 laturile + grila de bare deschise pe fond inchis). Aici:
    rama de plutitori DOAR sus, ata fina in diagonala (romb, nu patrat), umplutura tinde spre apa
    (nu spre negru) si se adanceste spre baza, colturi rotunjite (round_corners din tycoon_f2).
  - deck_tile: scanduri ORIZONTALE de-a lungul malului, in lemn DECOLORAT (WEATHERED) -- WOOD si
    DIRT stau prea aproape in nuanta (28 vs 30) ca sa se deosebeasca de path_tile doar din desen.
  - prop_platform: soclu de scanduri pentru statiile de pe uscat, cu muchie vizibila si umbra.
  - prop_pier2: debarcaderul vechi (prop_pier.png) avea doua lonjeroane subtiri cu trepte intre
    ele -- exact desenul unei scari. Aici puntea e PLINA si mai lata, stalpii stau doar la
    colturile din apa cu freamat moale (nu elipse albe opace), plus babord + franghie incolacita.
    APROBAT (2026-09-12), dar pastrat: dupa evaluare, prop_pier2 citea ca o LADA CU CAPAC vazuta
    de sus (babordul + franghia centrate = maner de lada, canava aproape patrata). Nu se
    suprascrie -- vezi prop_pier3 mai jos, piesa noua care il inlocuieste in joc.
  - prop_pier3: al doilea rescris, canava inalta (32x56, nu 64x48 -- o alee, nu un patrat).
    Scandurile TRAVERSEAZA latimea (randuri orizontale) cu rost de 1px intre ele -- se vede
    "se merge de-a lungul ei". Capatul de jos (spre punte) se termina in plina scandura, FARA
    contur/soclu, ca sa continue puntea, nu sa stea pe ea. Un singur babord, subtire, in coltul
    stanga al capatului dinspre larg -- nu unul central sau simetric, ca sa nu mai citeasca a
    maner. Doua bucle de franghie culcate pe punte (nu un colac central).
  - prop_weights: gramada mica de discuri de fier.

Acelasi pipeline ca tycoon.py/tycoon_f2.py -- nu unul nou: C/Rng/png din buildings.py, rampele din
palette.py, soft_shadow/outline_bottom/Tile/scatter din world.py, round_corners si ROPE din
tycoon_f2.py (aceeasi franghie ca la prop_netpost, acelasi decupaj de colt ca la ui_pill).

De ce fisiere noi, nu inlocuiri: net.png/prop_pier.png/path_tile.png raman legate de codul
existent (SceneArt/layout_preview le incarca pe nume) -- cablarea in scena e pasul urmator, dupa
ce owner-ul verifica piesele astea in Studio. Vezi raportul sesiunii.

Rulare: python3 scripts/art/tycoon_f3.py   (apoi preview_tycoon_f3.py pentru foaia de comparatie)
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, STONE, WATER, WATER_DEEP, FOAM, ramp, hsv, mix  # noqa: E402
from world import soft_shadow, outline_bottom, Tile, scatter  # noqa: E402
from tycoon_f2 import round_corners, ROPE  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

# Rampe noi (aceeasi reteta palette.ramp), pentru materiale care nu existau inca.
WEATHERED = ramp(hue=34, sat=0.20, val=0.58, steps=5, hue_shift=8, val_span=0.32)  # lemn de doc
NET_THREAD = ramp(hue=75, sat=0.28, val=0.20, steps=5, hue_shift=10, val_span=0.26)  # ata plasei
GAP_LINE = mix(WEATHERED[0], (20, 14, 10, 255), 0.5)  # rostul dintre scanduri la prop_pier3


def water_ripple(c, cx, cy, rx, ry):
    """Freamat la baza unui stalp in apa: acelasi principiu ca soft_shadow (straturi moi, alfa
    partial), dar in tonuri de spuma -- NU elipse albe opace (asta a fost problema la prop_pier.png
    vechi: cu alfa 255 arata ca stropi de vopsea, nu ca apa tulburata)."""
    c.ellipse(cx, cy, rx, ry, (FOAM[2][0], FOAM[2][1], FOAM[2][2], 46))
    c.ellipse(cx, cy, rx * 0.6, ry * 0.6, (FOAM[3][0], FOAM[3][1], FOAM[3][2], 90))
    c.put(cx, cy, FOAM[4])


# --------------------------------------------------------------- plasa, pe jumatate in apa
def _net_water(loaded):
    c = C(32, 18)
    x0, x1 = 1, 31
    waterline = 6 if loaded else 9  # incarcata: sta mai jos -- mai multa plasa sub linia apei

    for y in range(2, 18):  # umplutura: apa sub plasa, mai adanca spre fund
        t = max(0.0, min(1.0, (y - waterline) / max(1, 17 - waterline)))
        tone = mix(WATER[2], WATER_DEEP[1], t)
        bx0, bx1 = (x0, x1) if y < 13 else (x0 - 1, x1 + 1)  # incarcata: burduseala jos [loaded]
        if loaded and y >= 13:
            bx0, bx1 = max(0, x0 - 1), min(31, x1 + 1)
        c.rect(bx0, y, bx1 - bx0, 1, tone)

    if loaded:  # capturi: cateva contururi de peste, prinse SUB ata (firele trec peste ele)
        for fx, fy, flip in ((10, 12, 1), (20, 14, -1), (16, 9, 1)):
            body = mix((232, 214, 182, 255), WATER[4], 0.25)  # cald -- iese din albastrul apei
            c.ellipse(fx, fy, 2.1, 1.2, body)
            c.ellipse(fx - flip * 0.6, fy, 1.1, 0.7, mix(body, (255, 255, 255, 255), 0.3))
            c.put(fx - 2 * flip, fy, NET_THREAD[0])
            c.put(fx + 1, fy - 1, hsv(30, 0.35, 0.18))

    for i, k in enumerate(range(-18, 36, 7)):  # ata: doua familii diagonale -> romburi, nu patrate
        tone = NET_THREAD[1] if i % 2 == 0 else NET_THREAD[0]  # rara -- se vede apa printre ochiuri
        for y in range(2, 18):
            c.put(k + y, y, tone)
            c.put(k - y, y, tone)

    foam_xs = (5, 12, 19, 25) if not loaded else (4, 10, 17, 23, 27)  # spuma, la linia apei
    for fx in foam_xs:
        c.put(fx, waterline, FOAM[3])
        c.put(fx + 1, waterline - 1, FOAM[2])

    c.rect(4, 0, 24, 1, WOOD[3])  # rama de plutitori -- DOAR sus, nu incercuieste plasa
    c.rect(2, 1, 28, 1, WOOD[1])
    for fx in (6, 12, 18, 24):
        c.put(fx, 0, WOOD[0])
    c.put(9, 0, WOOD[4])

    round_corners(c, 32, 18, 3)  # colturi taiate -- siluetă rotunjita, nu dreptunghi de geam
    return c


# --------------------------------------------------------------- puntea de scanduri, de-a lungul malului
def deck_tile(size=48):
    """Scanduri ORIZONTALE, cusaturi orizontale intre randuri (fiecare rand = o scandura), cuie la
    pozitii fixe (se leaga exact la marimea dalei), fibra scurta orizontala. Wraparound-ul vine
    gratuit din Tile.put (mod w/h) -- scatter() poate pune orice langa margine fara sa rupa dala."""
    t = Tile(size, size)
    plank_h = 8
    row_tones = [
        WEATHERED[2],
        mix(WEATHERED[2], WEATHERED[1], 0.32),
        mix(WEATHERED[2], WEATHERED[3], 0.26),
        WEATHERED[2],
        mix(WEATHERED[2], WEATHERED[1], 0.20),
        mix(WEATHERED[2], WEATHERED[3], 0.16),
    ]
    for i in range(size // plank_h):
        y0 = i * plank_h
        tone = row_tones[i % len(row_tones)]
        t.rect(0, y0, size, plank_h, tone)
        t.rect(0, y0, size, 1, mix(tone, WEATHERED[4], 0.5))  # luciu, sus de fiecare scandura
        t.rect(0, y0 + plank_h - 1, size, 1, WEATHERED[0])  # cusatura, jos de fiecare scandura

    rng = Rng(4848)
    for cx, cy in scatter(rng, size, size, 46, 5):  # fibra: dasuri scurte, orizontale
        length = rng.i(2, 4)
        tone = WEATHERED[1] if rng.n() < 0.5 else WEATHERED[3]
        for k in range(length):
            t.put(cx + k, cy, tone)

    for i in range(size // plank_h):  # cuie -- pozitii FIXE, ca sa se lege intre dale
        y0 = i * plank_h + plank_h // 2
        xs = (8, 40) if i % 2 == 0 else (14, 34)
        for x in xs:
            t.put(x, y0, STONE[0])
            t.put(x + 1, y0, STONE[2])
    return t


# --------------------------------------------------------------- platforma statiei
def prop_platform():
    """Soclu de scanduri pentru o statie de pe uscat: muchie vizibila (soclu mai inchis pe fata,
    da grosime), umbra moale dedesubt -- ca o lada asezata deasupra sa arate construita, nu lasata
    pe iarba goala. WOOD (nu WEATHERED): statiile de pe uscat sunt din acelasi lemn ca lada/taraba
    care sta pe ele, nu lemnul decolorat al docului din apa."""
    c = C(48, 24)
    soft_shadow(c, 24, 22, 21, 3)
    top, bot = 3, 17
    c.rect(2, top, 44, bot - top, WOOD[2])
    c.rect(2, top, 44, 1, WOOD[3])
    for i, y in enumerate(range(top + 4, bot, 4)):
        c.rect(2, y, 44, 1, WOOD[0])
        c.rect(2, y + 1, 44, 1, mix(WOOD[2], WOOD[1], 0.3) if i % 2 == 0 else WOOD[2])
    c.rect(1, top, 1, bot - top, WOOD[1])
    c.rect(46, top, 1, bot - top, WOOD[0])
    c.rect(2, bot, 44, 5, WOOD[0])  # soclul -- fata vizibila, da grosime platformei
    c.rect(2, bot, 44, 1, WOOD[1])
    for x in range(4, 46, 8):
        c.rect(x, bot + 1, 1, 3, mix(WOOD[0], (0, 0, 0, 255), 0.3))
    outline_bottom(c, 0, 0, 48, 24)
    return c


# --------------------------------------------------------------- debarcaderul, corectat
def prop_pier2():
    """Puntea PLINA (fara goluri intre "trepte" -- asta era scara), mai lata decat prop_pier
    vechi (38/64 fata de 24/64) ca sa incapa de mers pe ea, muchii stanga/dreapta mai inchise
    decat centrul. Patru stalpi doar la colturile din portiunea de apa, cu freamat moale la baza.
    Babord de legare + franghie incolacita la capatul dinspre larg."""
    c = C(64, 48)
    dx, dw = 13, 38
    top, bot = 3, 44

    for py in (5, 24):  # stalpii, desenati primii (baza sub punte)
        for side in (dx - 3, dx + dw):
            c.rect(side, py, 3, 8, WEATHERED[1])
            c.rect(side, py, 1, 8, WEATHERED[2])
            c.rect(side + 2, py, 1, 8, WEATHERED[0])
            c.rect(side, py + 7, 3, 1, WEATHERED[0])
            water_ripple(c, side + 1, py + 8, 4.5, 1.8)

    c.rect(dx, top, dw, bot - top, WEATHERED[2])  # puntea plina
    c.rect(dx, top, 2, bot - top, WEATHERED[1])  # muchia stanga, mai inchisa decat centrul
    c.rect(dx + dw - 2, top, 2, bot - top, WEATHERED[0])  # muchia dreapta, si mai inchisa

    for i, y in enumerate(range(top + 5, bot, 5)):  # scandurile TRANSVERSALE -- cusatura, nu gol
        c.rect(dx + 2, y, dw - 4, 1, WEATHERED[0])
        band = mix(WEATHERED[2], WEATHERED[3], 0.4) if i % 2 == 0 else WEATHERED[2]
        c.rect(dx + 2, y + 1, dw - 4, 1, band)

    c.rect(dx + 2, top, dw - 4, 1, WEATHERED[4])  # luciu, pe capatul dinspre apa

    mx, my = dx + dw - 10, 3  # babordul de legare -- stalp mai gros, mai inalt, cu un capac plat
    c.rect(mx, my, 4, 11, WEATHERED[2])
    c.rect(mx, my, 1, 11, WEATHERED[3])
    c.rect(mx + 3, my, 1, 11, WEATHERED[0])
    c.ellipse(mx + 1.5, my, 2.6, 1.6, WEATHERED[1])  # capacul -- un singur ton, nu o stea

    rx, ry = dx + 8, top + 6  # franghia incolacita, pe punte, langa babord
    c.ellipse(rx, ry, 4, 2.8, ROPE[1])
    c.ellipse(rx, ry, 2.6, 1.9, ROPE[2])
    c.ellipse(rx, ry, 1.2, 0.9, ROPE[0])

    soft_shadow(c, dx + dw / 2, bot + 1, dw / 2 + 3, 3)
    outline_bottom(c, 0, 0, 64, 48)
    return c


# --------------------------------------------------------------- debarcaderul, al doilea rescris
def prop_pier3():
    """prop_pier2 a citit ca o LADA CU CAPAC: canava aproape patrata, babord+franghie centrate =
    maner. Corectii: canava inalta (o alee ce urca spre nord, nu un patrat), scandurile
    TRAVERSEAZA latimea cu un rost real de 1px intre ele (nu doar o cusatura de culoare), capatul
    de jos se termina in plina scandura -- FARA contur, fara soclu -- ca sa continue puntea, nu
    sa stea pe ea ca un obiect incadrat. Un singur babord subtire, in coltul stanga al capatului
    dinspre larg (nu centrat, nu in pereche) + doua bucle de franghie culcate pe punte (nu un
    colac) -- nimic simetric care sa mai poata citi a maner de lada."""
    c = C(32, 56)
    dx, dw = 4, 24
    top, bot = 2, 56

    for py in (top + 10, top + 30):  # stalpii de sprijin, in ambele laturi, in doua puncte
        for side in (dx - 3, dx + dw):
            c.rect(side, py, 3, 7, WEATHERED[1])
            c.rect(side, py, 1, 7, WEATHERED[2])
            c.rect(side + 2, py, 1, 7, WEATHERED[0])
            c.rect(side, py + 6, 3, 1, WEATHERED[0])
            water_ripple(c, side + 1, py + 7, 4, 1.6)

    plank_tones = [
        WEATHERED[2],
        mix(WEATHERED[2], WEATHERED[1], 0.3),
        mix(WEATHERED[2], WEATHERED[3], 0.22),
        WEATHERED[2],
    ]
    y, i = top, 0
    while y < bot:
        remaining = bot - y
        fill_h = remaining if remaining <= 6 else 5  # ultima: ocupa tot ce ramane, FARA rost dupa
        tone = plank_tones[i % len(plank_tones)]
        if y < top + 18:  # treimea dinspre larg -- mai inchisa, apa trece peste ea
            tone = mix(tone, WATER_DEEP[0], 0.32)
        c.rect(dx, y, dw, fill_h, tone)
        c.rect(dx, y, dw, 1, mix(tone, WEATHERED[4], 0.35))  # luciu, sus de fiecare scandura
        y += fill_h
        if y < bot:
            c.rect(dx, y, dw, 1, GAP_LINE)  # rostul -- 1px, opac (umbra intre scanduri, nu gaura)
            y += 1
        i += 1

    c.rect(dx, top, 2, bot - top, WEATHERED[1])  # grinda stanga -- continua, PESTE rosturi
    c.rect(dx + dw - 2, top, 2, bot - top, WEATHERED[0])  # grinda dreapta, mai inchisa

    for fx, fy in ((8, top + 4), (13, top + 9), (10, top + 14), (18, top + 6)):  # spuma, treimea din apa
        c.put(fx, fy, FOAM[3])

    mx, my = dx - 1, 0  # UN SINGUR babord, subtire, in coltul stanga -- nu un maner central
    c.rect(mx, my, 2, 8, WEATHERED[2])
    c.rect(mx, my, 1, 8, WEATHERED[3])
    c.ellipse(mx + 0.5, my, 1.5, 1, WEATHERED[1])

    def rope_loop(cx, cy):
        """Bucla culcata: CONTUR subtire (nu inel plin) -- un inel plin, chiar decentrat, tot
        citea a maner/balama de fier (vezi raportul). Un contur neuniform de franghie lasata
        moale pe punte nu se confunda cu o piesa de fierarie."""
        pts = 16
        for k in range(pts):
            ang = 2 * math.pi * k / pts
            wobble = 1.0 + 0.12 * math.sin(3 * ang)  # usor neregulat -- franghie, nu cerc geometric
            x = cx + math.cos(ang) * 2.6 * wobble
            y = cy + math.sin(ang) * 1.3 * wobble
            c.put(x, y, ROPE[1] if k % 2 == 0 else ROPE[0])
        c.put(cx - 1, cy, ROPE[3])  # un capat scurt, scapat din bucla

    rope_loop(dx + 7, top + 26)
    rope_loop(dx + 17, top + 41)

    return c


# --------------------------------------------------------------- greutatile de fier
def prop_weights():
    """Gramada mica de discuri de fier turtite, usor decalate -- upgrade-ul Weighted Nets."""
    c = C(24, 16)
    soft_shadow(c, 12, 14, 9, 2)
    plates = ((12, 12, 8, 2.8), (11.5, 9, 7, 2.4), (13, 6.2, 6, 2.0))
    for i, (px, py, rx, ry) in enumerate(plates):
        c.ellipse(px, py, rx, ry, STONE[0])  # muchia discului
        face = STONE[2] if i < 2 else STONE[1]
        c.ellipse(px, py - 0.6, rx - 1.2, ry - 0.7, face)  # fata, luminata din varf
    c.ellipse(12.5, 5.0, 1.6, 0.7, STONE[3])  # luciu de metal, pe discul de sus
    c.put(11.5, 4.8, hsv(205, 0.08, 0.95))
    outline_bottom(c, 0, 0, 24, 16)
    return c


TILES = {
    "deck_tile": deck_tile,
}

SPRITES = {
    "prop_net_water": lambda: _net_water(False),
    "prop_net_water_full": lambda: _net_water(True),
    "prop_platform": prop_platform,
    "prop_pier2": prop_pier2,
    "prop_pier3": prop_pier3,
    "prop_weights": prop_weights,
}


def main():
    for name, fn in list(TILES.items()) + list(SPRITES.items()):
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            raise SystemExit(f"refuz sa suprascriu {path} -- fisier existent")
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
        print(f"{name}.png: {img.w}x{img.h}")


if __name__ == "__main__":
    main()
