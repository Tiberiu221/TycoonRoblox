#!/usr/bin/env python3
"""Previzualizare pentru item_icons.png: toate cele 36 la scara 4x, id-ul sub fiecare.

Redeseneaza pictogramele direct din items.DRAW (acelasi cod, deterministic -- deci foaia de
previzualizare arata exact ce contine item_icons.png), le mareste fara antialiasing (fiecare
pixel devine un bloc 4x4) si scrie o eticheta cu font propriu, in blocuri, sub fiecare.

Rulare: python3 scripts/art/preview_items.py  (dupa items.py)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, hexc, png  # noqa: E402
from items import COLS, DRAW, ITEMS, SIZE, accent_ramp  # noqa: E402

SCALE = 4
TS = 1  # scara fontului de eticheta

# Font in blocuri, 5x7, doar literele mari si "_" -- atat cat au nevoie id-urile din ItemConfig
# (snake_case, fara cifre sau apostrof).
FONT = {
    "A": ["..#..", ".#.#.", "#...#", "#...#", "#####", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".####", "#....", "#....", "#..##", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
    "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "M": ["#...#", "##.##", "#.#.#", "#...#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
}
GLYPH_W, GLYPH_H = 5, 7


def text_width(text, scale=TS):
    return len(text) * (GLYPH_W + 1) * scale - scale


def draw_text(c, x, y, text, color, scale=TS):
    cx = x
    for ch in text.upper():
        glyph = FONT.get(ch)
        if glyph:
            for gy, row in enumerate(glyph):
                for gx, on in enumerate(row):
                    if on == "#":
                        c.rect(cx + gx * scale, y + gy * scale, scale, scale, color)
        cx += (GLYPH_W + 1) * scale


def blit_scaled(dst, icon, ox, oy, scale):
    for yy in range(icon.h):
        row = icon.px[yy]
        for xx in range(icon.w):
            p = row[xx]
            if not p[3]:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    dst.put(ox + xx * scale + dx, oy + yy * scale + dy, p)


BG = hexc("242226")
CARD = (255, 255, 255, 16)
INK = hexc("f0ead8")

ICON_PX = SIZE * SCALE
CELL_W = max(ICON_PX, text_width("W" * 19)) + 24
CELL_H = ICON_PX + 10 + GLYPH_H * TS + 20
MARGIN = 16


def build_preview():
    rows = (len(ITEMS) + COLS - 1) // COLS
    w = MARGIN * 2 + CELL_W * COLS
    h = MARGIN * 2 + CELL_H * rows
    prev = C(w, h)
    prev.rect(0, 0, w, h, BG)
    for idx, (item_id, family, accent) in enumerate(ITEMS):
        col, row = idx % COLS, idx // COLS
        cx = MARGIN + col * CELL_W
        cy = MARGIN + row * CELL_H
        prev.rect(cx + 4, cy + 4, CELL_W - 8, CELL_H - 8, CARD)
        icon = DRAW[family](accent_ramp(accent))
        ix = cx + (CELL_W - ICON_PX) // 2
        iy = cy + 8
        blit_scaled(prev, icon, ix, iy, SCALE)
        label = item_id
        tw = text_width(label)
        tx = cx + max(2, (CELL_W - tw) // 2)
        ty = iy + ICON_PX + 10
        draw_text(prev, tx, ty, label, INK)
    return prev


def main():
    prev = build_preview()
    png("_preview_items.png", prev.w, prev.h, prev.px)
    print(f"_preview_items.png: {prev.w}x{prev.h} px, {len(ITEMS)} pictograme la scara {SCALE}x")


if __name__ == "__main__":
    main()
