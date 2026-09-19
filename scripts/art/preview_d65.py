#!/usr/bin/env python3
"""Previzualizarea artei D65 (Moara), inainte de urcare. Scrie DOAR in scratchpad-ul sesiunii.

  d65_buildings.png -- fiecare cladire a Morii la marimea din joc (x3), pe iarba, intre RUINA ei si PERECHEA din
                       Era 1 (al carei desen il poarta azi, de imprumut): se vede dintr-o privire ca e alt loc?
  d65_goods.png     -- marfa noua la x6, langa marfa Erei 1.

Rulare: python3 scripts/art/preview_d65.py [buildings|goods]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
import d65_mill as M  # noqa: E402
import preview_d55 as P  # noqa: E402
from preview_tycoon import load, write_png  # noqa: E402

SCRATCH = P.SCRATCH

# (numele din joc, cladirea, ruina, perechea din Era 1 -- fisier din assets/sprites, sau None)
BUILDINGS = [
    ("Water Wheel", M.prop_water_wheel, M.prop_ruin_water_wheel, None),
    ("Mill Store", M.prop_mill_store, M.prop_ruin_mill_store, "prop_storage"),
    ("Foundry", M.prop_foundry, M.prop_ruin_foundry, "prop_sawmill"),
    ("Market", M.prop_market, M.prop_ruin_market, "prop_tavern"),
    ("Copper Furnace", M.prop_copper_furnace, M.prop_ruin_copper_furnace, "prop_workshop_e1"),
    ("Ore Shed", M.prop_ore_shed, M.prop_ruin_ore_shed, "prop_scrap_shed"),
    ("Mill Bell", M.prop_mill_bell, M.prop_ruin_mill_bell, "prop_bell"),
]


def blit(img, px, w, h, x, y, scale):
    for yy in range(h):
        for xx in range(w):
            p = px[yy][xx]
            if p[3]:
                img.rect(x + xx * scale, y + yy * scale, scale, scale, p)


def buildings():
    scale = 3
    col_w, row_h = 64 * scale + 40, 56 * scale + 34
    img = C(150 + 3 * col_w, 40 + len(BUILDINGS) * row_h)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for k, title in enumerate(("RUIN", "THE MILL (NEW)", "ERA 1 TWIN (BORROWED TODAY)")):
        P.draw_text(img, 150 + k * col_w, 10, title, P.INK, 1)
    y = 34
    for name, draw, ruin, twin in BUILDINGS:
        P.draw_text(img, 8, y + row_h // 2 - 8, name.upper(), P.INK, 1)
        cells = [ruin(), draw()]
        for k, c in enumerate(cells):
            blit(img, c.px, c.w, c.h, 150 + k * col_w, y + (56 - c.h) * scale, scale)
        if twin is not None:
            w, h, px = load(twin)
            blit(img, px, w, h, 150 + 2 * col_w, y + (56 - h) * scale, scale)
        y += row_h
    path = os.path.join(SCRATCH, "d65_buildings.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def goods():
    scale = 6
    new = [("PARTS", M.goods_parts()), ("ORE", M.goods_ore()), ("COPPER", M.goods_copper())]
    old = [("SCRAP", "goods_scrap"), ("IRON", "goods_iron"), ("PLANKS", "goods_planks")]
    img = C(40 + 3 * (24 * scale + 30), 60 + 2 * (18 * scale + 40))
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for k, (label, c) in enumerate(new):
        x = 20 + k * (24 * scale + 30)
        P.draw_text(img, x, 12, label, P.INK, 1)
        blit(img, c.px, c.w, c.h, x, 30, scale)
    y2 = 30 + 18 * scale + 40
    for k, (label, name) in enumerate(old):
        x = 20 + k * (24 * scale + 30)
        P.draw_text(img, x, y2 - 18, label + " (ERA 1)", P.INK, 1)
        w, h, px = load(name)
        blit(img, px, w, h, x, y2, scale)
    path = os.path.join(SCRATCH, "d65_goods.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def crew():
    """Casele oamenilor Morii (mica | mare) langa perechea lor din Era 1, taraba, incarcaturile si gramezile."""
    import d65_crew as B

    scale = 3
    rows = [
        ("Mill Collector", B.prop_hut_mill_collector_1, B.prop_hut_mill_collector_2, "runner_hut"),
        ("Mill Porter", B.prop_hut_mill_porter_1, B.prop_hut_mill_porter_2, "hut_porter_2"),
        ("Founder", B.prop_hut_founder_1, B.prop_hut_founder_2, "hut_sawyer_2"),
        ("Parts Hauler", B.prop_hut_parts_hauler_1, B.prop_hut_parts_hauler_2, "hut_hauler_2"),
        ("Merchant", B.prop_stall_merchant, B.prop_stall_merchant_2, "stall_2"),
        ("Ore Collector", B.prop_hut_ore_collector_1, B.prop_hut_ore_collector_2, "hut_scrap_collector_2"),
        ("Ore Porter", B.prop_hut_ore_porter_1, B.prop_hut_ore_porter_2, "hut_scrap_porter_2"),
        ("Coppersmith", B.prop_hut_coppersmith_1, B.prop_hut_coppersmith_2, "hut_smelter_2"),
        ("Copper Hauler", B.prop_hut_copper_hauler_1, B.prop_hut_copper_hauler_2, "hut_iron_hauler_2"),
    ]
    col_w, row_h = 64 * scale + 30, 40 * scale + 22
    strips = [("LOADS", (B.prop_load_parts, B.prop_load_ore, B.prop_load_copper), 4),
              ("PILES", (B.prop_pile_parts, B.prop_pile_ore, B.prop_pile_copper), 3)]
    img = C(150 + 3 * col_w, 40 + len(rows) * row_h + 3 * (28 * 3 + 20) + 3 * (9 * 4 + 16) + 60)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for k, title in enumerate(("ONE PERSON", "TWO PEOPLE", "ERA 1 TWIN (BORROWED TODAY)")):
        P.draw_text(img, 150 + k * col_w, 10, title, P.INK, 1)
    y = 30
    for name, small, big, twin in rows:
        P.draw_text(img, 8, y + row_h // 2 - 8, name.upper(), P.INK, 1)
        for k, draw in enumerate((small, big)):
            c = draw()
            blit(img, c.px, c.w, c.h, 150 + k * col_w, y + (40 - c.h) * scale, scale)
        try:
            w, h, px = load("prop_" + twin)
            blit(img, px, w, h, 150 + 2 * col_w, y + (40 - h) * scale, scale)
        except (FileNotFoundError, AssertionError):
            pass
        y += row_h
    for title, draws, s in strips:
        for draw in draws:
            c = draw()
            P.draw_text(img, 8, y + c.h * s // 2 - 6, f"{title} {draw.__name__.split('_')[-1]}".upper(), P.INK, 1)
            blit(img, c.px, c.w, c.h, 150, y, s)
            y += c.h * s + 16
    path = os.path.join(SCRATCH, "d65_crew.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def lineup():
    """Cele 18 meserii una langa alta (fata si lateral), la x5: oamenii Morii se deosebesc de cei ai satului vechi?"""
    era1 = [
        ("Collector", "fisher"), ("Porter", "crafter"), ("Sawyer", "builder"), ("Hauler", "gardener"),
        ("Innkeeper", "innkeeper"), ("Scrap Col.", "scrapper"), ("Scrap Por.", "carter"), ("Smelter", "smith"),
        ("Iron Haul.", "ironmonger"),
    ]
    era2 = [
        ("Mill Col.", "gleaner"), ("Mill Por.", "drayman"), ("Founder", "founder"), ("Parts Haul.", "wheelwright"),
        ("Merchant", "merchant"), ("Ore Col.", "prospector"), ("Ore Por.", "mucker"), ("Coppersmith", "coppersmith"),
        ("Copper Haul.", "teamster"),
    ]
    scale = 5
    cw = 24 * scale
    band = 2 * 30 * scale + 40
    img = C(len(era1) * cw + 20, 2 * band + 40)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for b, (title, crew_list) in enumerate((("ERA 1 - THE LANDING", era1), ("ERA 2 - THE MILL (NEW)", era2))):
        y0 = 20 + b * band
        P.draw_text(img, 10, y0 - 14, title, P.INK, 1)
        for i, (label, outfit) in enumerate(crew_list):
            sheet = P.person_frames("a", "short", outfit, (26, 0.45, 0.95), (28, 0.55, 0.9))
            for r, row in enumerate(("idle_down", "walk_side")):
                person = P.cell(sheet, row, 1)
                canvas = C(20, 28)
                P.paste(canvas, person, 2, 2)
                P.outline_all(canvas)
                blit(img, canvas.px, canvas.w, canvas.h, 10 + i * cw, y0 + r * 30 * scale, scale)
            P.draw_text(img, 10 + i * cw, y0 + 2 * 30 * scale - 6, label.upper(), P.INK, 1)
    path = os.path.join(SCRATCH, "d65_lineup.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("all", "buildings"):
        buildings()
    if which in ("all", "goods"):
        goods()
    if which in ("all", "crew"):
        crew()
    if which in ("all", "lineup"):
        lineup()
