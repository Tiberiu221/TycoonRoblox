#!/usr/bin/env python3
"""Sprite-urile clădirilor (b_*.png). Rulează apoi settlers.py pentru foaia de animație.
Folosire: python3 scripts/art/buildings.py && python3 scripts/art/settlers.py"""
import zlib, struct, os, math

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"


def png(path, w, h, px):
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *p) for p in row) for row in px)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    open(os.path.join(OUT, path), "wb").write(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


class Rng:
    def __init__(s, seed): s.s = seed & 0xffffffff or 1
    def n(s):
        x = s.s; x ^= (x << 13) & 0xffffffff; x ^= x >> 17; x ^= (x << 5) & 0xffffffff
        s.s = x; return x / 4294967296
    def i(s, a, b): return a + int(s.n() * (b - a + 1))


T = (0, 0, 0, 0)
def hexc(s, a=255): return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


class C:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[T for _ in range(w)] for _ in range(h)]
    def put(self, x, y, c):
        """Compunere alfa corecta ("over"). Varianta veche forta alfa 255 la orice suprapunere,
        ceea ce transforma doua umbre translucide intr-o bara neagra opaca."""
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h): return
        if c[3] == 255:
            self.px[y][x] = c; return
        if c[3] == 0: return
        b = self.px[y][x]
        ca, ba = c[3] / 255, b[3] / 255
        oa = ca + ba * (1 - ca)
        if oa <= 0: self.px[y][x] = T; return
        self.px[y][x] = tuple(
            int(round((c[i] * ca + b[i] * ba * (1 - ca)) / oa)) for i in range(3)
        ) + (int(round(oa * 255)),)
    def rect(self, x, y, w, h, c):
        for yy in range(int(y), int(y+h)):
            for xx in range(int(x), int(x+w)): self.put(xx, yy, c)
    def ellipse(self, cx, cy, rx, ry, c):
        for yy in range(int(cy-ry), int(cy+ry+1)):
            for xx in range(int(cx-rx), int(cx+rx+1)):
                if ((xx-cx)/max(rx,.5))**2 + ((yy-cy)/max(ry,.5))**2 <= 1: self.put(xx, yy, c)
    def tri_roof(self, x, y, w, h, light, dark, ridge):
        for i in range(h):
            inset = int(i * (w * 0.5 - 1) / max(1, h))
            self.rect(x + inset, y + h - 1 - i, w - 2*inset, 1, light if i % 2 == 0 else dark)
        self.rect(x + w//2 - 1, y, 2, 2, ridge)


WOOD = [hexc("4a2e18"), hexc("6b4322"), hexc("8a5a30"), hexc("b58652"), hexc("d3a46c")]
STONE = [hexc("55565e"), hexc("6b6c75"), hexc("83848d"), hexc("9fa0a8")]
CLOTH = [hexc("9c8b6a"), hexc("bda986"), hexc("d8c8a4")]
ROOF_RED = [hexc("8f2f2f"), hexc("a63a3a"), hexc("c05050")]
ROOF_BLUE = [hexc("2f4a7a"), hexc("3a5c94"), hexc("4f78b4")]
ROOF_GREEN = [hexc("2f5c3a"), hexc("3a7448"), hexc("4f9460")]
LEAF = [hexc("26401c"), hexc("32582b"), hexc("3e703d"), hexc("508855"), hexc("67a172")]


def shadow(c, cx, cy, rx, ry):
    """Umbra moale in trei straturi: una plata si opaca arata ca o bara neagra."""
    c.ellipse(cx, cy, rx, max(2, ry + 2), (0, 0, 0, 26))
    c.ellipse(cx, cy, rx * 0.78, max(1.5, ry + 0.5), (0, 0, 0, 34))
    c.ellipse(cx, cy, rx * 0.5, max(1, ry - 0.5), (0, 0, 0, 40))


def b_tent():
    c = C(32, 32); shadow(c, 16, 29, 12, 3)
    for i in range(14):
        halfw = 13 - i
        c.rect(16 - halfw, 27 - i, halfw * 2, 1, CLOTH[1] if i % 3 else CLOTH[2])
    c.rect(3, 27, 26, 2, WOOD[1])
    for i in range(9):  # intrare triunghiulara intunecata
        c.rect(16 - (6 - i//2), 27 - i, max(1, (6 - i//2) * 2), 1, hexc("3a3024"))
    c.rect(15, 13, 2, 15, WOOD[2]); c.rect(15, 12, 2, 2, WOOD[0])
    for x in (4, 28): c.rect(x, 25, 1, 4, WOOD[0])
    return c


def b_cottage():
    c = C(48, 48); shadow(c, 24, 45, 20, 3)
    c.rect(6, 26, 36, 18, WOOD[3])
    for y in range(28, 44, 3): c.rect(6, y, 36, 1, WOOD[2])
    c.rect(6, 26, 2, 18, WOOD[4]); c.rect(40, 26, 2, 18, WOOD[1]); c.rect(6, 43, 36, 2, WOOD[0])
    c.tri_roof(2, 12, 44, 15, ROOF_RED[1], ROOF_RED[0], ROOF_RED[2])
    c.rect(2, 26, 44, 2, hexc("5e2222")); c.rect(2, 28, 44, 1, (0, 0, 0, 70))
    c.rect(33, 6, 5, 8, STONE[1]); c.rect(33, 6, 5, 2, STONE[2])
    c.rect(21, 33, 7, 11, WOOD[1]); c.rect(22, 34, 5, 10, WOOD[2]); c.put(26, 39, hexc("f0d070"))
    for wx in (10, 33):
        c.rect(wx, 30, 6, 6, hexc("f5d98a")); c.rect(wx, 30, 6, 1, hexc("fff3c4"))
        c.rect(wx+2, 30, 1, 6, WOOD[1]); c.rect(wx, 32, 6, 1, WOOD[1])
    return c


def b_bunkhouse():
    c = C(64, 48); shadow(c, 32, 45, 27, 3)
    c.rect(4, 24, 56, 20, WOOD[3])
    for y in range(26, 44, 3): c.rect(4, y, 56, 1, WOOD[2])
    c.rect(4, 24, 2, 20, WOOD[4]); c.rect(58, 24, 2, 20, WOOD[1]); c.rect(4, 43, 56, 2, WOOD[0])
    for i in range(10):  # acoperis lung, in doua ape joase
        c.rect(2 + i, 14 + i, 60 - 2*i, 1, ROOF_BLUE[1] if i % 2 else ROOF_BLUE[0])
    c.rect(0, 23, 64, 2, hexc("22355c")); c.rect(0, 25, 64, 1, (0, 0, 0, 70))
    c.rect(29, 32, 8, 12, WOOD[1]); c.rect(30, 33, 6, 11, WOOD[2]); c.put(34, 38, hexc("f0d070"))
    for wx in (9, 20, 42, 51):
        c.rect(wx, 28, 5, 5, hexc("cfe4f5")); c.rect(wx, 28, 5, 1, hexc("eef8ff"))
        c.rect(wx+2, 28, 1, 5, WOOD[1])
    return c


def b_kitchen():
    c = C(48, 48); shadow(c, 24, 45, 20, 3)
    c.rect(5, 24, 38, 20, hexc("c9b48e"))
    for y in range(26, 44, 4): c.rect(5, y, 38, 1, hexc("b09a76"))
    c.rect(5, 24, 2, 20, hexc("ddcaa6")); c.rect(41, 24, 2, 20, hexc("a08b68")); c.rect(5, 43, 38, 2, hexc("7a6a50"))
    c.tri_roof(1, 10, 46, 14, ROOF_GREEN[1], ROOF_GREEN[0], ROOF_GREEN[2])
    c.rect(1, 23, 46, 2, hexc("22422c")); c.rect(1, 25, 46, 1, (0, 0, 0, 70))
    c.rect(8, 2, 7, 9, STONE[1]); c.rect(8, 2, 7, 2, STONE[2])  # horn mare
    c.rect(19, 32, 9, 12, WOOD[1]); c.rect(20, 33, 7, 11, WOOD[2])
    c.rect(31, 29, 9, 8, hexc("2a2018"))  # cuptor deschis
    c.rect(32, 33, 7, 4, hexc("e0703a")); c.rect(33, 34, 5, 3, hexc("f5a24a"))
    return c


def b_smokehouse():
    c = C(64, 48); shadow(c, 32, 45, 26, 3)
    c.rect(6, 22, 52, 22, hexc("6b5540"))
    for y in range(24, 44, 3): c.rect(6, y, 52, 1, hexc("54422f"))
    c.rect(6, 22, 2, 22, hexc("806851")); c.rect(56, 22, 2, 22, hexc("4a3a2a")); c.rect(6, 43, 52, 2, hexc("35281c"))
    for i in range(9): c.rect(4 + i, 13 + i, 56 - 2*i, 1, hexc("3a2f24") if i % 2 else hexc("4a3c2e"))
    c.rect(2, 21, 60, 2, hexc("2a2018"))
    for hx in (16, 44):
        c.rect(hx, 4, 6, 10, STONE[0]); c.rect(hx, 4, 6, 2, STONE[2])
    c.rect(28, 30, 8, 14, hexc("2a2018")); c.rect(29, 31, 6, 13, hexc("3d2f22"))
    for wx in (12, 46):
        c.rect(wx, 27, 6, 5, hexc("e0703a")); c.rect(wx, 27, 6, 1, hexc("f5a24a"))
    return c


def b_workshop():
    c = C(64, 64); shadow(c, 32, 61, 27, 3)
    c.rect(4, 30, 56, 28, WOOD[2])
    for y in range(32, 58, 3): c.rect(4, y, 56, 1, WOOD[1])
    c.rect(4, 30, 2, 28, WOOD[3]); c.rect(58, 30, 2, 28, WOOD[0]); c.rect(4, 57, 56, 2, WOOD[0])
    for i in range(14): c.rect(2 + i, 16 + i, 60 - 2*i, 1, hexc("6b6c75") if i % 2 else hexc("55565e"))
    c.rect(0, 29, 64, 2, hexc("3a3b42"))
    c.rect(44, 6, 7, 11, STONE[1]); c.rect(44, 6, 7, 2, STONE[2])
    c.rect(20, 38, 24, 20, hexc("2f251c"))  # gura mare de atelier
    c.rect(21, 39, 22, 18, hexc("3d3024"))
    c.rect(24, 46, 7, 7, hexc("e0703a")); c.rect(25, 47, 5, 5, hexc("f5c04a"))  # forja
    c.rect(34, 44, 8, 2, WOOD[3]); c.rect(34, 48, 8, 2, WOOD[3])  # banc de lucru
    for wx in (8, 50):
        c.rect(wx, 34, 6, 6, hexc("cfe4f5")); c.rect(wx, 34, 6, 1, hexc("eef8ff"))
    return c


def b_hall():
    c = C(64, 64); shadow(c, 32, 61, 28, 3)
    c.rect(4, 28, 56, 30, hexc("caa87e"))
    for y in range(30, 58, 4): c.rect(4, y, 56, 1, hexc("a98a63"))
    c.rect(4, 28, 2, 30, hexc("e0c096")); c.rect(58, 28, 2, 30, hexc("8f7452")); c.rect(4, 57, 56, 2, hexc("6b543a"))
    c.tri_roof(0, 8, 64, 20, ROOF_RED[1], ROOF_RED[0], hexc("f0c060"))
    c.rect(0, 27, 64, 2, hexc("5e2222")); c.rect(0, 29, 64, 1, (0, 0, 0, 70))
    c.rect(26, 40, 12, 18, WOOD[1]); c.rect(27, 41, 10, 17, WOOD[2])  # usa dubla
    c.rect(31, 41, 1, 17, WOOD[0]); c.put(29, 49, hexc("f0d070")); c.put(34, 49, hexc("f0d070"))
    for wx in (9, 20, 40, 51):
        c.rect(wx, 33, 5, 8, hexc("f5d98a")); c.rect(wx, 33, 5, 1, hexc("fff3c4"))
    for fx in (8, 55): c.rect(fx, 22, 2, 8, WOOD[0])  # stalpi de steag
    c.rect(6, 18, 6, 5, hexc("c05050")); c.rect(53, 18, 6, 5, hexc("4f78b4"))
    return c


def b_firepit():
    c = C(32, 32); shadow(c, 16, 28, 12, 3)
    for a in range(10):
        ang = a / 10 * 2 * math.pi
        c.ellipse(16 + math.cos(ang) * 10, 24 + math.sin(ang) * 4.5, 3, 2.2, STONE[1])
        c.ellipse(16 + math.cos(ang) * 10, 23 + math.sin(ang) * 4.5, 2, 1.4, STONE[2])
    c.ellipse(16, 24, 8, 3.6, hexc("2a2018"))
    for lx, ly, w in ((10, 22, 12), (12, 24, 9)):
        c.rect(lx, ly, w, 2, WOOD[1]); c.rect(lx, ly, w, 1, WOOD[2])
    c.ellipse(16, 21, 5, 3, hexc("e0703a")); c.ellipse(16, 20, 3, 2, hexc("f5c04a"))
    c.ellipse(16, 18, 2, 3, hexc("ffe08a"))
    return c


def b_scaffold():
    c = C(64, 64); shadow(c, 32, 61, 24, 3)
    for x in (8, 24, 40, 54): c.rect(x, 20, 3, 38, WOOD[2])
    for y in (24, 38, 52): c.rect(6, y, 52, 3, WOOD[3])
    for i in range(20):  # diagonala
        c.rect(10 + i * 2, 54 - i * 1.6, 3, 2, WOOD[1])
    c.rect(18, 44, 26, 14, hexc("b9ac93"))  # zid pe jumatate ridicat
    for y in range(46, 58, 3): c.rect(18, y, 26, 1, hexc("9b8f78"))
    return c


def b_garden():
    """Gradina: brazde arate cu rasaduri, gard scund, o galeata. 3x2 celule = 48x32 pixeli."""
    c = C(48, 32)
    shadow(c, 24, 30, 21, 2)
    c.rect(3, 8, 42, 21, hexc("6b4a30"))                      # pamant intors
    c.rect(3, 8, 42, 1, hexc("815c3c"))
    c.rect(3, 28, 42, 1, hexc("4e3522"))
    for row in range(3):                                       # brazde
        y = 11 + row * 6
        c.rect(4, y, 40, 3, hexc("7a563a"))
        c.rect(4, y, 40, 1, hexc("8d6947"))
        c.rect(4, y + 3, 40, 1, hexc("543a25"))
        for k in range(5):                                     # rasaduri
            x = 7 + k * 8
            c.rect(x, y - 2, 2, 3, LEAF[2])
            c.put(x - 1, y - 2, LEAF[1])
            c.put(x + 2, y - 2, LEAF[3])
            c.put(x, y - 3, LEAF[3])
    for px in (2, 45):                                         # stalpi de gard
        c.rect(px, 5, 2, 25, WOOD[1])
        c.rect(px, 5, 1, 25, WOOD[3])
    c.rect(0, 7, 48, 2, WOOD[2])
    c.rect(0, 9, 48, 1, WOOD[0])
    c.rect(38, 24, 5, 5, STONE[1])                             # galeata
    c.rect(38, 24, 5, 1, STONE[3])
    c.rect(39, 25, 3, 3, hexc("3a6a8c"))
    return c


BUILDINGS = {
    "b_garden": b_garden,
    "b_tent": b_tent, "b_cottage": b_cottage, "b_bunkhouse": b_bunkhouse,
    "b_kitchen": b_kitchen, "b_smokehouse": b_smokehouse, "b_workshop": b_workshop,
    "b_hall": b_hall, "b_firepit": b_firepit, "b_scaffold": b_scaffold,
}

if __name__ == "__main__":
    for name, fn in BUILDINGS.items():
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
    print(f"{len(BUILDINGS)} sprite-uri de cladiri scrise in {OUT}")
    print("acum: python3 scripts/art/settlers.py   (foaia de animatie)")
