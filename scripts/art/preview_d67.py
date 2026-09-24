#!/usr/bin/env python3
"""Previzualizarea artei D67 (Wire Works), inainte de urcare. Scrie DOAR in scratchpad-ul sesiunii.

  d67_buildings.png -- fiecare cladire a Erei 3 la marimea din joc (x3), pe iarba, intre RUINA ei si PERECHEA din
                       Moara (al carei desen il poarta azi, de imprumut): se vede dintr-o privire ca e alt loc?
  d67_goods.png     -- marfa noua la x6, langa marfa Morii, si felinarul stins / aprins cu lumina lui.

Rulare: python3 scripts/art/preview_d67.py [buildings|goods]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
import d67_works as W  # noqa: E402
import preview_d55 as P  # noqa: E402
from preview_tycoon import load, write_png  # noqa: E402

SCRATCH = P.SCRATCH

# (numele din joc, cladirea, ruina, perechea din Moara -- fisier din assets/sprites, sau None)
BUILDINGS = [
    ("Steam Engine", W.prop_steam_engine, W.prop_ruin_steam_engine, "prop_copper_furnace"),
    ("Works Store", W.prop_works_store, W.prop_ruin_works_store, "prop_mill_store"),
    ("Wire Works", W.prop_wire_works, W.prop_ruin_wire_works, "prop_foundry"),
    ("Depot", W.prop_depot, W.prop_ruin_depot, "prop_market"),
    ("Power House", W.prop_power_house, W.prop_ruin_power_house, "prop_copper_furnace"),
    ("Battery Shed", W.prop_battery_shed, W.prop_ruin_battery_shed, "prop_ore_shed"),
    ("Works Bell", W.prop_works_bell, W.prop_ruin_works_bell, "prop_mill_bell"),
    ("First Turbine", W.prop_turbine, None, "prop_water_wheel"),
]


def blit(img, px, w, h, x, y, scale):
    """Deseneaza foaia la `scale`, cu alfa amestecat peste fundal (umbrele si lumina felinarului sunt translucide)."""
    for yy in range(h):
        for xx in range(w):
            p = px[yy][xx]
            if not p[3]:
                continue
            a = p[3] / 255
            for dy in range(scale):
                for dx in range(scale):
                    X, Y = x + xx * scale + dx, y + yy * scale + dy
                    if 0 <= X < img.w and 0 <= Y < img.h:
                        bg = img.px[Y][X]
                        img.px[Y][X] = tuple(round(bg[i] * (1 - a) + p[i] * a) for i in range(3)) + (255,)


def buildings():
    scale = 3
    col_w, row_h = 64 * scale + 40, 56 * scale + 34
    img = C(150 + 3 * col_w, 40 + len(BUILDINGS) * row_h)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for k, title in enumerate(("RUIN", "WIRE WORKS (NEW)", "MILL TWIN (BORROWED TODAY)")):
        P.draw_text(img, 150 + k * col_w, 10, title, P.INK, 1)
    y = 34
    for name, draw, ruin, twin in BUILDINGS:
        P.draw_text(img, 8, y + row_h // 2 - 8, name.upper(), P.INK, 1)
        cells = [ruin() if ruin is not None else None, draw()]
        for k, c in enumerate(cells):
            if c is not None:
                blit(img, c.px, c.w, c.h, 150 + k * col_w, y + (56 - c.h) * scale, scale)
        if twin is not None:
            w, h, px = load(twin)
            blit(img, px, w, h, 150 + 2 * col_w, y + (56 - h) * scale, scale)
        y += row_h
    path = os.path.join(SCRATCH, "d67_buildings.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def goods():
    scale = 6
    img = C(24 * scale * 3 + 60, 18 * scale * 2 + 40 * 3 + 80)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    P.draw_text(img, 10, 8, "NEW: COILS / BATTERY / POWER CELL", P.INK, 1)
    for k, draw in enumerate((W.goods_coils, W.goods_battery, W.goods_cell)):
        c = draw()
        blit(img, c.px, c.w, c.h, 10 + k * (24 * scale + 20), 24, scale)
    y = 24 + 18 * scale + 16
    P.draw_text(img, 10, y, "THE MILL: PARTS / ORE / COPPER", P.INK, 1)
    for k, name in enumerate(("goods_parts", "goods_ore", "goods_copper")):
        w, h, px = load(name)
        blit(img, px, w, h, 10 + k * (24 * scale + 20), y + 16, scale)
    y += 18 * scale + 32
    P.draw_text(img, 10, y, "STREET LAMP: OFF / ON", P.INK, 1)
    glow = W.prop_lamp_glow()
    blit(img, glow.px, glow.w, glow.h, 150 + 18 - 48, y + 16 + 21 - 48, 3)  # centrul luminii pe capul felinarului
    for k, draw in enumerate((W.prop_street_lamp, W.prop_street_lamp_lit)):
        c = draw()
        blit(img, c.px, c.w, c.h, 30 + k * 120, y + 16, 3)
    path = os.path.join(SCRATCH, "d67_goods.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


# (meseria, casele noi, perechea din Moara)
HUTS = [
    ("Works Collector", "works_collector", "hut_mill_collector"),
    ("Works Porter", "works_porter", "hut_mill_porter"),
    ("Wiredrawer", "wiredrawer", "hut_founder"),
    ("Coil Hauler", "coil_hauler", "hut_parts_hauler"),
    ("Battery Collector", "battery_collector", "hut_ore_collector"),
    ("Battery Porter", "battery_porter", "hut_ore_porter"),
    ("Electrician", "electrician", "hut_coppersmith"),
    ("Power Hauler", "power_hauler", "hut_copper_hauler"),
]


def crew():
    import d67_crew as K

    scale = 3
    col_w, row_h = 40 * scale + 24, 40 * scale + 20
    img = C(170 + 3 * (40 * 2 * 4 + 16), 40 + (len(HUTS) + 3) * row_h)  # destul de lat pentru cele trei gramezi
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for k, title in enumerate(("NEW: 1 PERSON", "NEW: 2 PEOPLE", "MILL TWIN: 1", "MILL TWIN: 2")):
        P.draw_text(img, 170 + k * col_w, 10, title, P.INK, 1)
    y = 34
    for name, key, twin in HUTS:
        P.draw_text(img, 8, y + row_h // 2 - 8, name.upper(), P.INK, 1)
        for k, suffix in enumerate(("_1", "_2")):
            c = getattr(K, f"prop_hut_{key}{suffix}")()
            blit(img, c.px, c.w, c.h, 170 + k * col_w, y + (40 - c.h) * scale, scale)
            w, h, px = load(f"prop_{twin}{suffix}")
            blit(img, px, w, h, 170 + (2 + k) * col_w, y + (40 - h) * scale, scale)
        y += row_h
    P.draw_text(img, 8, y + row_h // 2 - 8, "CLERK", P.INK, 1)
    for k, draw in enumerate((K.prop_stall_clerk, K.prop_stall_clerk_2)):
        c = draw()
        blit(img, c.px, c.w, c.h, 170 + k * (64 * scale + 20), y + (40 - c.h) * scale, scale)
    y += row_h
    P.draw_text(img, 8, y + 30, "LOADS", P.INK, 1)
    for k, draw in enumerate((K.prop_load_coils, K.prop_load_battery, K.prop_load_cell)):
        c = draw()
        blit(img, c.px, c.w, c.h, 170 + k * (c.w * 4 + 20), y + 10, 4)
    y += row_h
    P.draw_text(img, 8, y + 30, "PILES", P.INK, 1)
    for k, draw in enumerate((K.prop_pile_coils, K.prop_pile_battery, K.prop_pile_cell)):
        c = draw()
        blit(img, c.px, c.w, c.h, 170 + k * (c.w * 2 + 16), y, 2)
    path = os.path.join(SCRATCH, "d67_crew.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def audit():
    """[D67, dupa auditul din 2026-09-24] Ce se schimba, inainte / dupa: colibele Wire Works cu acoperisul fiecarei
    meserii (sus: cate una; jos: toata strada, in ordinea din joc) si cele patru cadre ale turbinei si ale rotii de apa."""
    import d67_crew as K
    import d65_mill as M

    scale = 3
    order = [key for _name, key, _twin in HUTS]
    street_w = len(order) * (40 * scale + 6)
    img = C(max(20 + street_w, 900), 40 + 2 * (34 * scale + 40) + 2 * (34 * scale + 34) + 48 * 4 + 90)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    y = 10
    for title, loader in (
        ("WIRE WORKS HOUSES TODAY (UPLOADED)", lambda key: load(f"prop_hut_{key}_2")),
        ("WIRE WORKS HOUSES NEW (EACH TRADE ITS OWN ROOF)", lambda key: getattr(K, f"prop_hut_{key}_2")()),
    ):
        P.draw_text(img, 10, y, title, P.INK, 1)
        y += 18
        for k, key in enumerate(order):
            got = loader(key)
            w, h, px = (got if isinstance(got, tuple) else (got.w, got.h, got.px))
            blit(img, px, w, h, 10 + k * (40 * scale + 6), y + (34 - h) * scale, scale)
        y += 34 * scale + 22
    P.draw_text(img, 10, y, "ONE-PERSON HOUSES: TODAY / NEW", P.INK, 1)
    y += 18
    for k, key in enumerate(order):
        w, h, px = load(f"prop_hut_{key}_1")
        blit(img, px, w, h, 10 + k * (40 * scale + 6), y + (28 - h) * scale, scale)
        c = getattr(K, f"prop_hut_{key}_1")()
        blit(img, c.px, c.w, c.h, 10 + k * (40 * scale + 6), y + 30 * scale + (28 - c.h) * scale, scale)
    y += 60 * scale + 20
    for title, sheet in (("FIRST TURBINE, 4 FRAMES (SPINS)", W.prop_turbine_spin()), ("WATER WHEEL, 4 FRAMES (SPINS)", M.prop_water_wheel_spin())):
        P.draw_text(img, 10, y, title, P.INK, 1)
        for i in range(4):
            frame = [row[i * 48:(i + 1) * 48] for row in sheet.px]
            blit(img, frame, 48, 48, 10 + i * (48 * 3 + 10) + (0 if title.startswith("FIRST") else 0), y + 16, 3)
        y += 48 * 3 + 30
    path = os.path.join(SCRATCH, "d67_audit.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which == "audit":
        audit()
    if which in ("buildings", "all"):
        buildings()
    if which in ("goods", "all"):
        goods()
    if which in ("crew", "all"):
        crew()
