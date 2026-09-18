#!/usr/bin/env python3
"""[D63] PICTOGRAMELE MAGAZINULUI: cate una pentru fiecare lucru din coltul cu Robux.

De ce: randurile din Shop refoloseau moneda, cronometrul, luna, oamenii si ceasul din restul jocului. Un copil care nu
citeste inca usor deosebeste ofertele dupa DESEN, nu dupa fraza de sub nume -- iar doua randuri cu aceeasi moneda
("2x Flow" si "Welcome Back x2") aratau la fel. Fiecare oferta are acum desenul ei, care spune ce primesti:
  flow2x     doua monede si "x2"            venitul se dubleaza
  swift      gheata cu aripa                mergi mai repede
  nights     luna deasupra casei luminate   satul lucreaza si cat dormi
  supporter  inima cu stea                  ii sustii pe cei care fac jocul
  hour       clepsidra cu nisip de aur      o ora de venit, pe loc
  welcome2x  sacul de monede si "x2"        dublezi ce s-a strans cat ai lipsit

Iese, pentru fiecare: assets/sprites/icon_shop_<cheie>.png (20x20: in randul de 40 px din panou se mareste exact de 2
ori, deci pixelii raman patrati) si, cu --hub, assets/store/<cheie>_512.png -- iconita de 512x512 ceruta de Creator Hub
la crearea pass-ului sau a produsului (aceeasi pictograma, marita de 20 de ori pe o placa de culoarea jocului).

NU suprascrie un fisier existent decat cu --force.

Rulare: python3 scripts/art/d63_shop_icons.py [--force] [--hub] [--preview cale.png]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, png  # noqa: E402
from palette import STONE, WOOD, hsv, ramp  # noqa: E402
from tycoon_e1 import GOLD, GOLD_HI, PLANK, STEEL, WARM, outline_trace  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "assets", "sprites")
HUB = os.path.join(ROOT, "assets", "store")
SIZE = 20

WHITE = (250, 248, 240, 255)
INK = (52, 38, 30, 255)
NIGHT = ramp(228, 0.52, 0.46)
MOON = ramp(52, 0.30, 0.98)
HEART = ramp(356, 0.70, 0.90)
LEATHER = ramp(24, 0.55, 0.62)
BURLAP = ramp(38, 0.36, 0.78)
WING = ramp(205, 0.10, 0.98)
BADGE = (190, 58, 50, 255)


def coin(c, cx, cy, r):
    c.ellipse(cx, cy, r, r, GOLD[0])
    c.ellipse(cx, cy, r - 0.8, r - 0.8, GOLD[2])
    c.ellipse(cx - 0.5, cy - 0.5, r - 1.8, r - 1.8, GOLD[3])
    c.ellipse(cx - 1.2, cy - 1.2, max(0.8, r - 3.4), max(0.8, r - 3.4), GOLD_HI[4])


def x2(c, x, y):
    """ "x2" alb pe o placuta rosie: singurul text dintr-o pictograma, fiindca e chiar oferta."""
    glyphs = {
        "x": ("1.1", ".1.", "1.1", "...", "..."),
        "2": ("11.", "..1", ".1.", "1..", "111"),
    }
    # pe o placuta rosie cu margine inchisa: alb direct pe auriu sau pe sac nu se citea la marimea din panou
    c.rect(x - 2, y - 2, 11, 9, INK)
    c.rect(x - 1, y - 1, 9, 7, BADGE)
    cx = x
    for ch, top in (("x", 2), ("2", 0)):
        for ry, row in enumerate(glyphs[ch]):
            for rx, bit in enumerate(row):
                if bit == "1":
                    c.put(cx + rx, y + ry + top, WHITE)
        cx += 4


def icon_flow2x(c):
    coin(c, 7, 7, 6.2)
    coin(c, 12.5, 9.5, 5.6)
    x2(c, 10, 12)


def icon_swift(c):
    # gheata: carambul, talpa, varful
    c.rect(7, 3, 6, 9, LEATHER[2])
    c.rect(7, 3, 2, 9, LEATHER[3])
    c.rect(7, 3, 6, 1, LEATHER[4])
    c.rect(7, 11, 11, 4, LEATHER[2])
    c.rect(13, 10, 5, 2, LEATHER[3])
    c.rect(16, 11, 2, 3, LEATHER[1])
    c.rect(6, 15, 13, 2, WOOD[0])
    c.rect(6, 15, 13, 1, WOOD[1])
    for y in (6, 8):  # sireturi
        c.rect(10, y, 3, 1, PLANK[4])
    # aripa de la calcai, in trei pene
    for i, (x, y, w) in enumerate(((1, 6, 6), (2, 9, 5), (3, 12, 4))):
        c.rect(x, y, w, 2, WING[4] if i < 2 else WING[3])
        c.rect(x, y + 1, w, 1, WING[3])
    # dungile de viteza
    c.rect(0, 16, 4, 1, WING[4])
    c.rect(1, 18, 6, 1, WING[3])


def icon_nights(c):
    c.ellipse(10, 10, 9.4, 9.4, NIGHT[1])
    c.ellipse(10, 10, 8.4, 8.4, NIGHT[2])
    # luna: disc din care musca un disc de culoarea cerului
    c.ellipse(12.5, 6.5, 3.6, 3.6, MOON[4])
    c.ellipse(14.0, 5.6, 3.0, 3.0, NIGHT[2])
    for sx, sy in ((5, 5), (8, 3), (4, 9)):
        c.put(sx, sy, MOON[4])
    # casa cu fereastra aprinsa
    for i in range(4):
        c.rect(6 - i + 3, 10 + i, 2 + 2 * i, 1, STONE[1])
    c.rect(6, 14, 8, 4, WOOD[2])
    c.rect(6, 14, 8, 1, WOOD[3])
    c.rect(9, 15, 2, 2, WARM[4])


def icon_supporter(c):
    # inima: doi lobi si un varf, cu lumina sus-stanga
    for cx in (6.5, 13.5):
        c.ellipse(cx, 7.5, 4.6, 4.4, HEART[2])
    for i in range(8):
        c.rect(3 + i, 9 + i, 14 - 2 * i, 1, HEART[2])
    c.ellipse(6.0, 6.8, 2.4, 2.0, HEART[3])
    c.put(5, 5, HEART[4])
    c.put(6, 5, HEART[4])
    for i in range(6):  # umbra de jos-dreapta
        c.put(15 - i, 10 + i, HEART[1])
    # steaua aurie, in coltul din dreapta-jos
    for dx, dy in ((0, -2), (0, -1), (0, 0), (0, 1), (0, 2), (-2, 0), (-1, 0), (1, 0), (2, 0)):
        c.put(15 + dx, 14 + dy, GOLD_HI[4])
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        c.put(15 + dx, 14 + dy, GOLD[3])


def icon_hour(c):
    c.rect(4, 1, 12, 2, WOOD[1])
    c.rect(4, 1, 12, 1, WOOD[3])
    c.rect(4, 17, 12, 2, WOOD[1])
    c.rect(4, 17, 12, 1, WOOD[3])
    glass = hsv(200, 0.14, 0.96)
    for i in range(7):  # conul de sus, apoi cel de jos
        c.rect(5 + i // 1 * 0 + min(i, 4), 3 + i, 10 - 2 * min(i, 4), 1, glass)
        c.rect(5 + min(i, 4), 16 - i, 10 - 2 * min(i, 4), 1, glass)
    for i in range(3):  # nisipul ramas sus
        c.rect(7 + i, 6 + i, 6 - 2 * i, 1, GOLD[3])
    c.rect(9, 9, 2, 3, GOLD_HI[4])  # firul care curge
    for i in range(4):  # gramada de jos
        c.rect(9 - i, 13 + i, 2 + 2 * i, 1, GOLD[3] if i else GOLD_HI[4])
    for x in (4, 15):
        c.rect(x, 3, 1, 14, STEEL[1])


def icon_welcome2x(c):
    # sacul: burduf rotund, gura legata, doua monede care ies
    c.ellipse(9, 12.5, 7.2, 6.2, BURLAP[2])
    c.ellipse(8, 11.5, 5.4, 4.6, BURLAP[3])
    c.rect(6, 4, 6, 3, BURLAP[2])
    c.rect(5, 6, 8, 1, WOOD[0])
    c.rect(6, 3, 6, 1, BURLAP[3])
    coin(c, 13.5, 4.5, 2.6)
    for i in range(4):  # umbra burdufului
        c.put(14 - i, 16 + min(i, 1), BURLAP[1])
    x2(c, 10, 12)


ICONS = {
    "flow2x": icon_flow2x,
    "swift": icon_swift,
    "nights": icon_nights,
    "supporter": icon_supporter,
    "hour": icon_hour,
    "welcome2x": icon_welcome2x,
}


def draw(key):
    c = C(SIZE, SIZE)
    ICONS[key](c)
    outline_trace(c)
    return c


def hub_icon(c, scale=20):
    """512x512 pentru Creator Hub: pictograma marita, pe o placa in culorile jocului, cu loc liber pe margini (unele
    vederi ale Roblox taie iconita rotund)."""
    size = 512
    plate = (44, 62, 80, 255)
    inner = (58, 82, 104, 255)
    rows = [[plate for _ in range(size)] for _ in range(size)]
    for y in range(24, size - 24):
        for x in range(24, size - 24):
            rows[y][x] = inner
    off = (size - c.w * scale) // 2
    for y in range(c.h * scale):
        for x in range(c.w * scale):
            q = c.px[y // scale][x // scale]
            if q[3]:
                a = q[3] / 255
                b = rows[off + y][off + x]
                rows[off + y][off + x] = tuple(round(b[i] + (q[i] - b[i]) * a) for i in range(3)) + (255,)
    return rows


def main():
    args = sys.argv[1:]
    force = "--force" in args
    for key in ICONS:
        c = draw(key)
        path = os.path.join(OUT, f"icon_shop_{key}.png")
        if os.path.exists(path) and not force:
            print(f"  icon_shop_{key}.png  exista deja, sarit (--force ca sa-l rescrii)")
        else:
            png(path, c.w, c.h, c.px)
            print(f"  icon_shop_{key}.png  {c.w}x{c.h}")
        if "--hub" in args:
            os.makedirs(HUB, exist_ok=True)
            png(os.path.join(HUB, f"{key}_512.png"), 512, 512, hub_icon(c))
    if "--preview" in args:
        path = args[args.index("--preview") + 1]
        k, pad = 8, 16
        w = pad + len(ICONS) * (SIZE * k + pad)
        h = SIZE * k + 2 * pad
        rows = [[(58, 82, 104, 255) for _ in range(w)] for _ in range(h)]
        for i, key in enumerate(ICONS):
            c = draw(key)
            ox = pad + i * (SIZE * k + pad)
            for y in range(SIZE * k):
                for x in range(SIZE * k):
                    q = c.px[y // k][x // k]
                    if q[3]:
                        rows[pad + y][ox + x] = q
        png(path, w, h, rows)
        print("  previzualizare:", path)


if __name__ == "__main__":
    main()
