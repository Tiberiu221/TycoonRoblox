#!/usr/bin/env python3
"""Foaie de comparatie pentru cele 6 sprite-uri noi din tycoon_f2.py, la 4x, langa 3 sprite-uri
existente (ui_panel, prop_signpost, b_workshop) ca sa se vada daca se potrivesc la stil -- plus
un bloc separat care INTINDE cele trei piese cu 9 felii (ui_plaque, ui_card, ui_pill) la marimi
mari, exact cum ar face Roblox cu ScaleType.Slice. Asta e verificarea ceruta de spec: o rama cu 9
felii gresita se vede abia cand e intinsa, nu la marimea nativa.

Scrie DOAR in folderul de lucru (scripts/art/scratch.py), nu in assets/sprites -- e o previzualizare de lucru.
Refoloseste load()/write_png()/blit_scaled()/draw_text() din preview_tycoon.py (F1) in loc sa le
copieze din nou.

Rulare: python3 scripts/art/preview_tycoon_f2.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, hexc  # noqa: E402
from preview_tycoon import load, write_png, blit_scaled, draw_text, text_width, GLYPH_H  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
SPR = scratch.SPRITES
DEST = os.path.join(scratch.folder(), "art_f2_preview.png")
SCALE = 4
BG = hexc("242226")
CARD = (255, 255, 255, 16)
INK = hexc("f0ead8")
WARN = hexc("f0c060")
MARGIN = 16
GAP = 14

# (nume fisier, eticheta) -- intai cele 3 existente pentru comparatie, apoi cele 6 noi.
COMPARE = [
    ("ui_panel", "ui_panel (old)"),
    ("prop_signpost", "prop_signpost (old)"),
    ("b_workshop", "b_workshop (old)"),
    ("ui_plaque", "ui_plaque"),
    ("prop_post", "prop_post"),
    ("ui_card", "ui_card"),
    ("ui_pill", "ui_pill"),
    ("prop_netpost", "prop_netpost"),
    ("prop_runner_hut", "prop_runner_hut"),
]
COLS = 5

# (nume fisier, slice/border din UI_SLICE, latime tinta, inaltime tinta) -- cartonasul la 220x140
# e cel cerut explicit in spec; celelalte doua, la o intindere tipica de HUD/placuta.
STRETCH = [
    ("ui_plaque", 8, 216, 56),
    ("ui_card", 10, 220, 140),
    ("ui_pill", 8, 200, 40),
]


def slice_stretch(w, h, px, border, W, H):
    """Acelasi algoritm ca ScaleType.Slice din Roblox: cele 4 colturi raman la marimea nativa
    (border x border), marginile se intind pe o singura axa, centrul pe amandoua -- nearest
    neighbor, ca sa iasa la vedere exact orice zgomot care s-ar rupe la intindere."""

    def stretch_index(d, dst_len, src_len):
        return min(src_len - 1, int(d * src_len / max(1, dst_len)))

    mid_w, mid_h = w - 2 * border, h - 2 * border
    MW, MH = W - 2 * border, H - 2 * border
    out = [[(0, 0, 0, 0)] * W for _ in range(H)]
    for Y in range(H):
        if Y < border:
            sy = Y
        elif Y >= H - border:
            sy = h - (H - Y)
        else:
            sy = border + stretch_index(Y - border, MH, mid_h)
        row_out = out[Y]
        src_row = px[sy]
        for X in range(W):
            if X < border:
                sx = X
            elif X >= W - border:
                sx = w - (W - X)
            else:
                sx = border + stretch_index(X - border, MW, mid_w)
            row_out[X] = src_row[sx]
    return out


def main():
    loaded = [(name, label, load(name)) for name, label in COMPARE]
    for name, label, (w, h, px) in loaded:
        print(f"{name}: {w}x{h}")

    # --- blocul 1: grila de comparatie la 4x (acelasi cod ca preview_tycoon.py) ------------
    cell_w = max(w for _, _, (w, h, px) in loaded) * SCALE + 20
    cell_h = max(h for _, _, (w, h, px) in loaded) * SCALE + 10 + GLYPH_H + 20
    rows = (len(loaded) + COLS - 1) // COLS
    grid_w = MARGIN * 2 + cell_w * COLS
    grid_h = MARGIN * 2 + cell_h * rows

    # --- blocul 2: cele trei piese cu 9 felii, intinse la marimea din STRETCH --------------
    stretch_loaded = [(name, b, W, H, load(name)) for name, b, W, H in STRETCH]
    strip_h = max(H for _, _, _, H, _ in stretch_loaded) + GLYPH_H + 44
    strip_w = MARGIN * 2 + sum(W + GAP for _, _, W, _, _ in stretch_loaded)

    W_total = max(grid_w, strip_w)
    H_total = grid_h + strip_h
    sheet = C(W_total, H_total)
    sheet.rect(0, 0, W_total, H_total, BG)

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

    # titlu + piesele intinse, sub grila
    ty0 = grid_h + 6
    draw_text(sheet, MARGIN, ty0, "9-SLICE STRETCH TEST (ScaleType.Slice, nearest neighbor)", WARN)
    ox = MARGIN
    oy = ty0 + GLYPH_H + 14
    for name, border, W, H, (w, h, px) in stretch_loaded:
        stretched = slice_stretch(w, h, px, border, W, H)
        sheet.rect(ox - 2, oy - 2, W + 4, H + 4, CARD)
        blit_scaled(sheet, W, H, stretched, ox, oy, 1)
        label_full = f"{name}: {w}x{h} -> {W}x{H} ({border}px)"
        draw_text(sheet, ox, oy + H + 6, label_full, INK)
        ox += W + GAP

    write_png(DEST, W_total, H_total, sheet.px)
    print(f"{DEST}: {W_total}x{H_total}")


if __name__ == "__main__":
    main()
