#!/usr/bin/env python3
"""Foaie de comparatie pentru cele 7 sprite-uri noi din tycoon.py, la 4x, langa 3 sprite-uri
existente (b_workshop, prop_barrel, crate_common) ca sa se vada daca se potrivesc la stil.

Scrie DOAR in folderul de lucru (scripts/art/scratch.py), nu in assets/sprites -- e o previzualizare de lucru, nu un
sprite de joc. Foloseste load() din preview_scene.py (acelasi decodor PNG) si fontul in blocuri
din preview_items.py (aceeasi eticheta sub fiecare piesa).

Rulare: python3 scripts/art/preview_tycoon.py
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, hexc  # noqa: E402
from preview_items import FONT, GLYPH_H, GLYPH_W  # noqa: E402

# NU importam load() din preview_scene.py: acel fisier deseneaza o scena la nivelul modulului
# (fara `if __name__ == "__main__"`), deci un simplu import ar scrie _scene_preview.png ca efect
# secundar. Acelasi decodor PNG, copiat, ca sa ramana fara efecte secundare.
SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"


def load(name):
    d = open(os.path.join(SPR, name + ".png"), "rb").read()
    pos, w, h, idat = 8, 0, 0, b""
    while pos < len(d):
        ln = struct.unpack(">I", d[pos : pos + 4])[0]
        typ = d[pos + 4 : pos + 8]
        data = d[pos + 8 : pos + 8 + ln]
        if typ == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", data[:10])
            assert depth == 8 and ctype == 6, (name, depth, ctype)
        elif typ == b"IDAT":
            idat += data
        pos += 12 + ln
    raw = zlib.decompress(idat)
    px, stride, prev = [], w * 4, bytearray(w * 4)
    p = 0
    for _ in range(h):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p : p + stride])
        p += stride
        for i in range(stride):
            a = line[i - 4] if i >= 4 else 0
            b = prev[i]
            cc = prev[i - 4] if i >= 4 else 0
            if ft == 1:
                line[i] = (line[i] + a) & 255
            elif ft == 2:
                line[i] = (line[i] + b) & 255
            elif ft == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif ft == 4:
                pp = a + b - cc
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - cc)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else cc)
                line[i] = (line[i] + pr) & 255
        prev = line
        px.append([tuple(line[i * 4 : i * 4 + 4]) for i in range(w)])
    return w, h, px

# preview_items.FONT nu are cifre (id-urile din ItemConfig nu au nevoie) -- dimensiunile
# sprite-urilor (24x18 etc.) au, deci le adaugam local, acelasi bloc 5x7.
DIGITS = {
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".###."],
}
FULL_FONT = {**FONT, **DIGITS}


def text_width(text, scale=1):
    return len(text) * (GLYPH_W + 1) * scale - scale


def draw_text(c, x, y, text, color, scale=1):
    cx = x
    for ch in text.upper():
        glyph = FULL_FONT.get(ch)
        if glyph:
            for gy, row in enumerate(glyph):
                for gx, on in enumerate(row):
                    if on == "#":
                        c.rect(cx + gx * scale, y + gy * scale, scale, scale, color)
        cx += (GLYPH_W + 1) * scale

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEST = os.path.join(scratch.folder(), "art_f1_preview.png")
SCALE = 4
BG = hexc("242226")
CARD = (255, 255, 255, 16)
INK = hexc("f0ead8")
MARGIN = 16
GAP = 14

# (nume fisier, eticheta) -- intai cele 3 existente pentru comparatie, apoi cele 7 noi.
ITEMS = [
    ("b_workshop", "b_workshop (old)"),
    ("prop_barrel", "prop_barrel (old)"),
    ("crate_common", "crate_common (old)"),
    ("goods_reeds", "goods_reeds"),
    ("goods_scrap", "goods_scrap"),
    ("goods_shards", "goods_shards"),
    ("prop_pier", "prop_pier"),
    ("prop_bell", "prop_bell"),
    ("prop_sack", "prop_sack"),
    ("prop_stall", "prop_stall"),
]
COLS = 5


def write_png(path, w, h, px):
    raw = b"".join(b"\x00" + b"".join(struct.pack("BBBB", *p) for p in row) for row in px)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )


def blit_scaled(dst, w, h, px, ox, oy, scale):
    for yy in range(h):
        row = px[yy]
        for xx in range(w):
            p = row[xx]
            if not p[3]:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    dst.put(ox + xx * scale + dx, oy + yy * scale + dy, p)


def main():
    loaded = [(name, label, load(name)) for name, label in ITEMS]
    # celula = cel mai mare sprite la 4x (latime/inaltime), plus loc pentru eticheta
    cell_w = max(w for _, _, (w, h, px) in loaded) * SCALE + 20
    cell_h = max(h for _, _, (w, h, px) in loaded) * SCALE + 10 + GLYPH_H + 20
    rows = (len(loaded) + COLS - 1) // COLS
    W = MARGIN * 2 + cell_w * COLS
    H = MARGIN * 2 + cell_h * rows
    sheet = C(W, H)
    sheet.rect(0, 0, W, H, BG)

    for idx, (name, label, (w, h, px)) in enumerate(loaded):
        col, row = idx % COLS, idx // COLS
        cx = MARGIN + col * cell_w
        cy = MARGIN + row * cell_h
        sheet.rect(cx + 4, cy + 4, cell_w - 8, cell_h - 8, CARD)
        ix = cx + (cell_w - w * SCALE) // 2
        iy = cy + 8
        blit_scaled(sheet, w, h, px, ix, iy, SCALE)
        label_full = f"{label} {w}x{h}"
        tw = text_width(label_full)
        tx = cx + max(2, (cell_w - tw) // 2)
        ty = cy + cell_h - GLYPH_H - 12
        draw_text(sheet, tx, ty, label_full, INK)

    write_png(DEST, W, H, sheet.px)
    print(f"{DEST}: {W}x{H}")


if __name__ == "__main__":
    main()
