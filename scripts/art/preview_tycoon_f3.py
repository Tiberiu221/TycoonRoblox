#!/usr/bin/env python3
"""Foaie de comparatie pentru cele 7 sprite-uri noi din tycoon_f3.py, la 4x: intai o grila cu
fiecare piesa singura (plus net.png/prop_pier.png vechi, pentru comparatie directa -- exact
piesele pe care owner-ul le-a numit ca citesc prost), apoi patru panouri "in context": plasa
peste apa, puntea placuta 4x2 cu un stalp pe ea, platforma cu lada existenta deasupra, si
debarcaderul peste apa langa punte -- prop_pier (vechi), prop_pier2 SI prop_pier3, toate trei in
aceeasi compunere, ca diferenta sa se vada direct, nu doar una langa alta in grila. (prop_pier2 a
fost aprobat initial, apoi respins la evaluare -- citea ca o lada cu capac; prop_pier3 e al doilea
rescris.)

Scrie DOAR in scratchpad-ul sesiunii, nu in assets/sprites -- e o previzualizare de lucru.
Refoloseste load()/write_png()/blit_scaled()/draw_text() din preview_tycoon.py, nu le copiaza.

Rulare: python3 scripts/art/preview_tycoon_f3.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, hexc  # noqa: E402
from preview_tycoon import load, write_png, blit_scaled, draw_text, text_width, GLYPH_H  # noqa: E402

DEST = (
    "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/"
    "b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/art_f3_preview.png"
)
SCALE = 4
BG = hexc("242226")
CARD = (255, 255, 255, 16)
INK = hexc("f0ead8")
WARN = hexc("f0c060")
MARGIN = 16
GAP = 14

# (nume fisier, eticheta) -- intai cele doua piese vechi numite in cerinta, apoi cele 7 noi.
COMPARE = [
    ("net", "net (old)"),
    ("prop_pier", "prop_pier (old)"),
    ("prop_net_water", "prop_net_water"),
    ("prop_net_water_full", "prop_net_water_full"),
    ("deck_tile", "deck_tile"),
    ("prop_platform", "prop_platform"),
    ("prop_pier2", "prop_pier2 (rejected)"),
    ("prop_pier3", "prop_pier3"),
    ("prop_weights", "prop_weights"),
]
COLS = 4


def blit(sheet, spr, ox, oy, scale=SCALE):
    w, h, px = spr
    blit_scaled(sheet, w, h, px, ox, oy, scale)
    return ox, oy, w * scale, h * scale


def bottom_anchor(sheet, spr, cx, bottom_y, scale=SCALE):
    w, h, px = spr
    ox, oy = cx - (w * scale) // 2, bottom_y - h * scale
    blit_scaled(sheet, w, h, px, ox, oy, scale)
    return ox, oy, w * scale, h * scale


def tile_block(sheet, spr, ox, oy, nx, ny, scale=SCALE):
    w, h, px = spr
    for j in range(ny):
        for i in range(nx):
            blit_scaled(sheet, w, h, px, ox + i * w * scale, oy + j * h * scale, scale)
    return ox, oy, w * scale * nx, h * scale * ny


def panel_frame(sheet, x, y, w, h, title):
    sheet.rect(x - 4, y - 4, w + 8, h + 8 + GLYPH_H + 10, CARD)
    draw_text(sheet, x, y - 2 + h + 8, title, INK)


def main():
    loaded = [(name, label, load(name)) for name, label in COMPARE]

    # --- blocul 1: grila la 4x, aceeasi reteta ca preview_tycoon.py -----------------------
    cell_w = max(w for _, _, (w, h, px) in loaded) * SCALE + 20
    cell_h = max(h for _, _, (w, h, px) in loaded) * SCALE + 10 + GLYPH_H + 20
    rows = (len(loaded) + COLS - 1) // COLS
    grid_w = MARGIN * 2 + cell_w * COLS
    grid_h = MARGIN * 2 + cell_h * rows

    # --- blocul 2: patru panouri "in context" ----------------------------------------------
    water = load("water_tile")
    deck = load("deck_tile")
    netpost = load("prop_netpost")
    crate = load("crate_common")
    pier_old = load("prop_pier")
    pier2 = load("prop_pier2")
    pier3 = load("prop_pier3")
    net_e = load("prop_net_water")
    net_f = load("prop_net_water_full")
    platform = load("prop_platform")

    P1_W, P1_H = water[0] * SCALE, water[1] * SCALE  # plasa peste apa
    P2_W, P2_H = deck[0] * SCALE * 4, deck[1] * SCALE * 2  # puntea 4x2 + stalp
    P3_W, P3_H = platform[0] * SCALE, platform[1] * SCALE + crate[1] * SCALE  # platforma + lada

    # panoul 4: cele trei debarcadere, peste un fundal apa+punte pe toata inaltimea nativa a
    # dalelor (nu o felie arbitrara -- asa nu mai trebuie decupat nimic ca sa incapa cel mai
    # inalt dintre ele, prop_pier3 la 56 nativ).
    piers4 = [("prop_pier (old)", pier_old), ("prop_pier2 (rejected)", pier2), ("prop_pier3", pier3)]
    pier_gap = 28
    P4_W = sum(spr[0] * SCALE for _, spr in piers4) + pier_gap * (len(piers4) - 1) + 24
    water_h4 = water[1] * SCALE
    deck_h4 = deck[1] * SCALE
    P4_H = water_h4 + deck_h4

    panel_row_h = max(P1_H, P2_H, P3_H, P4_H) + GLYPH_H + 40
    panels_top = grid_h + 30
    W_total = max(
        grid_w,
        MARGIN * 2 + P1_W + GAP + P2_W + GAP + P3_W + GAP + P4_W + 24,
    )
    H_total = panels_top + panel_row_h + MARGIN

    sheet = C(W_total, H_total)
    sheet.rect(0, 0, W_total, H_total, BG)

    # --- randare blocul 1 --------------------------------------------------------------
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

    draw_text(sheet, MARGIN, panels_top - 20, "IN CONTEXT", WARN)

    # --- panoul 1: plasele peste apa -----------------------------------------------------
    px1 = MARGIN
    panel_frame(sheet, px1, panels_top, P1_W, P1_H, "net over water_tile")
    blit(sheet, water, px1, panels_top)
    bottom_anchor(sheet, net_e, px1 + P1_W // 3, panels_top + P1_H // 2 + 70)
    bottom_anchor(sheet, net_f, px1 + 2 * P1_W // 3, panels_top + P1_H // 2 + 90)

    # --- panoul 2: puntea 4x2 cu un stalp -------------------------------------------------
    px2 = px1 + P1_W + GAP
    panel_frame(sheet, px2, panels_top, P2_W, P2_H, "deck_tile x4x2 + prop_netpost")
    tile_block(sheet, deck, px2, panels_top, 4, 2)
    bottom_anchor(sheet, netpost, px2 + P2_W // 2, panels_top + P2_H - 20)

    # --- panoul 3: platforma cu lada existenta ---------------------------------------------
    px3 = px2 + P2_W + GAP
    panel_frame(sheet, px3, panels_top, P3_W, P3_H, "prop_platform + crate_common")
    plat_oy = panels_top + P3_H - platform[1] * SCALE
    blit(sheet, platform, px3, plat_oy)
    # lada, asezata pe muchia din fata a platformei (top=3 native -> rand de sus al puntii)
    crate_bottom = plat_oy + 17 * SCALE + 6
    bottom_anchor(sheet, crate, px3 + P3_W // 2, crate_bottom)

    # --- panoul 4: cele trei debarcadere, peste apa langa punte ----------------------------
    px4 = px3 + P3_W + GAP
    panel_frame(
        sheet, px4, panels_top, P4_W, P4_H,
        "prop_pier (old) vs prop_pier2 (rejected) vs prop_pier3, over water+deck",
    )
    boundary_y = panels_top + water_h4  # unde apa se termina si incepe puntea
    tile_block(sheet, water, px4, panels_top, (P4_W // (water[0] * SCALE)) + 1, 1)
    tile_block(sheet, deck, px4, boundary_y, (P4_W // (deck[0] * SCALE)) + 1, 1)

    # etichete individuale DEASUPRA fiecarui debarcader (pe banda de apa, nu peste puntea placuta
    # -- textul pe fondul dungat al deck_tile era greu de citit) -- ordinea stanga-dreapta
    # se potriveste cu titlul panoului: old, pier2, pier3.
    join_y = boundary_y + 20  # toate trei se ancoreaza pe ACEEASI linie, 20px in banda de punte
    ox = px4 + 12
    for label, spr in piers4:
        cx = ox + spr[0] * SCALE // 2
        bottom_anchor(sheet, spr, cx, join_y)
        tw = text_width(label)
        draw_text(sheet, cx - tw // 2, panels_top + 6, label, INK)
        ox += spr[0] * SCALE + pier_gap

    write_png(DEST, W_total, H_total, sheet.px)
    print(f"{DEST}: {W_total}x{H_total}")


if __name__ == "__main__":
    main()
