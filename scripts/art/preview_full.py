#!/usr/bin/env python3
"""Previzualizare: lumea cu decor + o simulare a interfetei peste ea."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png  # noqa: E402
from palette import hsv  # noqa: E402
from preview_scene import load, blit  # noqa: E402

S = 3
W, H = 1500, 780


def slice9(dst, src, x, y, w, h, border, scale=2):
    """Deseneaza o imagine cu 9 felii: coltul ramane, marginea si mijlocul se intind."""
    sw, sh, px = src
    b = border * scale

    def block(sx0, sy0, sx1, sy1, dx0, dy0, dx1, dy1):
        sw2, sh2 = max(1, sx1 - sx0), max(1, sy1 - sy0)
        dw2, dh2 = max(0, dx1 - dx0), max(0, dy1 - dy0)
        for yy in range(dh2):
            for xx in range(dw2):
                p = px[sy0 + min(sh2 - 1, yy * sh2 // max(1, dh2))][
                    sx0 + min(sw2 - 1, xx * sw2 // max(1, dw2))
                ]
                if p[3]:
                    dst.put(dx0 + xx, dy0 + yy, p)

    block(0, 0, border, border, x, y, x + b, y + b)
    block(sw - border, 0, sw, border, x + w - b, y, x + w, y + b)
    block(0, sh - border, border, sh, x, y + h - b, x + b, y + h)
    block(sw - border, sh - border, sw, sh, x + w - b, y + h - b, x + w, y + h)
    block(border, 0, sw - border, border, x + b, y, x + w - b, y + b)
    block(border, sh - border, sw - border, sh, x + b, y + h - b, x + w - b, y + h)
    block(0, border, border, sh - border, x, y + b, x + b, y + h - b)
    block(sw - border, border, sw, sh - border, x + w - b, y + b, x + w, y + h - b)
    block(border, border, sw - border, sh - border, x + b, y + b, x + w - b, y + h - b)


def plate(dst, x, y, w, h, alpha=76):
    for yy in range(h):
        for xx in range(w):
            dst.put(x + xx, y + yy, (0, 0, 0, alpha))


scene = C(W, H)
grass, water, sand, foam_n, foam_s, path = (
    load(n) for n in ("grass_tile", "water_tile", "sand_tile", "foam_north", "foam_south", "path_tile")
)

for y in range(0, H, grass[1] * S):
    for x in range(0, W, grass[0] * S):
        blit(scene, grass, x, y, S)

RIVER_TOP, RIVER_H = 60, 190
for x in range(0, W, sand[0] * S):
    blit(scene, sand, x, RIVER_TOP - sand[1] * S + 20, S)
    blit(scene, sand, x, RIVER_TOP + RIVER_H - 20, S)
for x in range(0, W, water[0] * S):
    for y in range(RIVER_TOP, RIVER_TOP + RIVER_H, water[1] * S):
        blit(scene, water, x, y, S)
for x in range(0, W, foam_n[0] * S):
    blit(scene, foam_s, x, RIVER_TOP, S)
    blit(scene, foam_n, x, RIVER_TOP + RIVER_H - foam_n[1] * S, S)
for y in range(RIVER_TOP + RIVER_H + 30, H, path[1] * S):
    blit(scene, path, 470, y, S)
for x in range(470, W, path[0] * S):
    blit(scene, path, x, 470, S)

DECOR = [
    ("prop_tree_pine", 70, 430), ("prop_tree_round", 190, 400), ("prop_bush", 300, 330),
    ("prop_rock_large", 380, 300), ("prop_cattails", 120, 290), ("prop_cattails", 900, 285),
    ("prop_log", 640, 320), ("prop_tree_round", 1290, 420), ("prop_tree_pine", 1400, 350),
    ("prop_flowers", 250, 560), ("prop_flowers", 1150, 600), ("prop_stump", 1000, 340),
    ("prop_fence", 690, 620), ("prop_barrel", 620, 610), ("prop_lantern", 470, 560),
    ("prop_signpost", 880, 545), ("prop_rock_small", 1080, 500), ("prop_boat", 760, 215),
]
BUILDINGS = [
    ("b_cottage", 560, 430), ("b_kitchen", 760, 420), ("b_workshop", 960, 400),
    ("b_tent", 480, 500), ("b_firepit", 700, 560), ("b_bunkhouse", 1100, 470),
    ("b_garden", 300, 690),
]
SETTLERS = [(0, 0, 620, 560), (2, 1, 840, 520), (6, 2, 990, 560), (11, 0, 170, 270), (7, 1, 1050, 620)]

items = [(n, x, y, "prop") for n, x, y in DECOR] + [(n, x, y, "b") for n, x, y in BUILDINGS]
items.sort(key=lambda t: t[2])
for name, x, y, _ in items:
    img = load(name)
    blit(scene, img, x, y - img[1] * S, S)

sheet = load("character_anim")
for row, frame, x, y in SETTLERS:
    blit(scene, sheet, x, y - 24 * S, S, sx=frame * 16, sy=row * 24, sw=16, sh=24)

# ---- interfata peste lume ----
panel, button, slot = load("ui_panel"), load("ui_button"), load("ui_slot")
icons = {n: load(f"icon_{n}") for n in ("materials", "crate", "people", "bed", "build", "hammer", "colony", "arrow")}

x = 26
for key in ("materials", "crate", "people", "bed"):
    plate(scene, x, 20, 128, 48, 80)
    blit(scene, icons[key], x + 12, 30, 2)
    x += 136

slice9(scene, panel, 26, 150, 430, 156, 8, 2)          # cartonasul de obiectiv
for i in range(4):                                      # bara de butoane din dreapta
    slice9(scene, button, W - 100, 250 + i * 76, 68, 68, 7, 2)
    key = ("build", "people", "hammer", "colony")[i]
    blit(scene, icons[key], W - 100 + 18, 250 + i * 76 + 18, 2)

marker = icons["arrow"]                                 # semnul de obiectiv, peste tinta
for yy in range(marker[1]):
    for xx in range(marker[0]):
        p = marker[2][marker[1] - 1 - yy][xx]
        if p[3]:
            for dy in range(3):
                for dx in range(3):
                    scene.put(760 + xx * 3 + dx, 120 + yy * 3 + dy, p)

png("_preview_full.png", W, H, scene.px)
print(f"scena completa {W}x{H}")
