#!/usr/bin/env python3
"""Previzualizarea artei D55, inainte de urcare. Scrie DOAR in folderul de lucru (scripts/art/scratch.py).

  d55_people.png  -- un Collector, un Porter si un Hauler cu roaba: mersul in cele patru directii, incarcatul
                     si rasturnatul, cadru cu cadru, cu fiecare incarcatura -- la x4, pe iarba;
  d55_props.png   -- fiecare sprite nou la marimea din joc (x2 recuzita, x3 cladirile), cu treptele lor;
  d55_map.png     -- malul Erei 1 cu pozitiile noi (gramezile langa gater, shed-ul, colibele), la jumatate.

Oamenii se compun din foile in straturi desenate IN MEMORIE de settlers.py (corp -> par -> tinuta, apoi
conturul), cu tenta pielii si a parului aplicata ca in joc. Ancorele roabei sunt aceleasi ca in cod
(PersonView): daca aici mainile nu stau pe manere, nici in joc nu stau.

Rulare: python3 scripts/art/preview_d55.py [people|props|map]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
from preview_tycoon import load, write_png, draw_text, text_width  # noqa: E402
import settlers as S  # noqa: E402
import d55  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
SCRATCH = scratch.folder()
INK = (240, 234, 216, 255)
GRASS_BG = (86, 128, 64, 255)

# ---- ancorele roabei, in pixeli de celula a omului (16x24) -> coltul roabei (24x20) ------------------
# lateral: manerul (0, 13) pe mana (13, 15); spre tine: manerele (9|15, 2) pe mainile (4|10, 15);
# de la tine: capetele manerelor (9|15, 19) pe capetele bratelor (4|10, 13). `front` = roaba peste om.
BARROW_AT = {
    "side": (13, 2, True),
    "down": (-5, 15, True),
    "up": (-5, -12, False),
}
VIEW_FRAME = {"side": 0, "down": 1, "up": 2}
# unde sta incarcatura (16x9) in cadrul roabei; `over` = peste roaba (vederea de la tine)
LOAD_AT = {"side": (6, 2, False), "down": (4, 3, False), "up": (4, 0, True)}


def person_frames(body, hair, outfit, skin, hair_tone):
    """Foaia completa a unui om, compusa din straturi, cu tenta aplicata (ca in joc)."""
    layers = []
    for layer in ("body", "hair", "outfit"):
        sheet = S.build_sheet(layer, body=body, outfit=outfit, hair=hair)
        if layer != "outfit":
            sheet = S._apply_tint(sheet, skin, hair_tone)
        layers.append(sheet)
    combo = C(layers[0].w, layers[0].h)
    for part in layers:
        for y in range(combo.h):
            for x in range(combo.w):
                p = part.px[y][x]
                if p[3]:
                    combo.put(x, y, p)
    return combo


def cell(sheet, row, f):
    r = S.ROWS.index(row)
    out = C(S.FW, S.FH)
    for y in range(S.FH):
        for x in range(S.FW):
            out.px[y][x] = sheet.px[r * S.FH + y][f * S.FW + x]
    return out


def sub(src, x0, y0, w, h):
    out = C(w, h)
    for y in range(h):
        for x in range(w):
            out.px[y][x] = src.px[y0 + y][x0 + x]
    return out


def mirror(c):
    out = C(c.w, c.h)
    for y in range(c.h):
        out.px[y] = list(reversed(c.px[y]))
    return out


def paste(dst, src, ox, oy):
    for y in range(src.h):
        for x in range(src.w):
            p = src.px[y][x]
            if p[3]:
                dst.put(ox + x, oy + y, p)


def outline_all(c):
    S.outline(c, 0, 0, c.w, c.h)


def scene(sheet, row, f, view, facing_left, load_kind, step, barrow, loads):
    """Un cadru: omul + roaba + incarcatura, pe o panza de 56x60 (celula omului la (20, 20))."""
    canvas = C(56, 60)
    px, py = 20, 20
    person = cell(sheet, row, f)
    bx, by, front = BARROW_AT[view]
    if row in ("load", "tip"):
        bx, by, front = BARROW_AT["side"]
    frame = sub(barrow, VIEW_FRAME[view if row not in ("load", "tip") else "side"] * d55.BW, 0, d55.BW, d55.BH)
    load_img = None
    if load_kind is not None and step > 0:
        load_img = sub(loads[load_kind], (step - 1) * d55.LW, 0, d55.LW, d55.LH)
    lx, ly, over = LOAD_AT[view if row not in ("load", "tip") else "side"]
    if row == "tip":
        by -= [0, 3, 5, 2][f]  # manerele urca cu mainile (in joc roaba se si inclina)
    layers = []
    rig = C(d55.BW, d55.BH)
    if load_img is not None and not over:
        paste(rig, load_img, lx, ly)
    paste(rig, frame, 0, 0)
    if load_img is not None and over:
        paste(rig, load_img, lx, ly)
    if front:
        layers = [(person, px, py), (rig, px + bx, py + by)]
    else:
        layers = [(rig, px + bx, py + by), (person, px, py)]
    for img, x, y in layers:
        paste(canvas, img, x, y)
    outline_all(canvas)
    return mirror(canvas) if facing_left else canvas


def people(only=None):
    barrow = d55.prop_barrow()
    loads = {k: getattr(d55, f"prop_load_{k}")() for k in ("logs", "planks", "scrap", "iron", "crate")}
    roster = [
        ("Collector", ("a", "short", "fisher", (28, 0.32, 1.05), (25, 0.55, 1.0)), "logs"),
        ("Porter", ("b", "long", "crafter", (26, 0.55, 0.85), (45, 0.60, 1.15)), "scrap"),
        ("Hauler", ("a", "bun", "gardener", (22, 0.62, 0.58), (5, 0.65, 0.55)), "planks"),
    ]
    if only is not None:
        roster = [r for r in roster if r[0].lower() == only.lower()]
    shots = [
        ("push_side", "side", False),
        ("push_side", "side", True),
        ("push_down", "down", False),
        ("push_up", "up", False),
        ("load", "side", False),
        ("tip", "side", False),
    ]
    scale = 4
    cw, ch = 56 * scale, 60 * scale
    width = 150 + 4 * cw
    height = 20 + len(roster) * len(shots) * (ch + 6) + 40
    img = C(width, height)
    img.rect(0, 0, width, height, GRASS_BG)
    y = 20
    for name, look, load_kind in roster:
        sheet = person_frames(*look)
        for row, view, left in shots:
            label = f"{name} {row}{' <' if left else ''}"
            draw_text(img, 8, y + ch // 2 - 6, label.upper(), INK, 1)
            for f in range(4):
                step = 3 if row != "load" else (0, 1, 2, 3)[f]
                kind = load_kind if row != "push_up" else "iron"
                shot = scene(sheet, row, f, view, left, kind, step, barrow, loads)
                for yy in range(shot.h):
                    for xx in range(shot.w):
                        p = shot.px[yy][xx]
                        if p[3]:
                            img.rect(150 + f * cw + xx * scale, y + yy * scale, scale, scale, p)
            y += ch + 6
    path = os.path.join(SCRATCH, f"d55_people{'_' + only.lower() if only else ''}.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def zoom():
    """Cate un cadru din fiecare miscare, pentru cele trei meserii, la x6: detaliile, nu ritmul."""
    barrow = d55.prop_barrow()
    loads = {k: getattr(d55, f"prop_load_{k}")() for k in ("logs", "planks", "scrap", "iron", "crate")}
    roster = [
        (("a", "short", "fisher", (28, 0.32, 1.05), (25, 0.55, 1.0)), "logs"),
        (("b", "long", "crafter", (26, 0.55, 0.85), (45, 0.60, 1.15)), "scrap"),
        (("a", "bun", "gardener", (22, 0.62, 0.58), (5, 0.65, 0.55)), "planks"),
    ]
    shots = [("push_side", "side", False, 1), ("push_down", "down", False, 0), ("push_up", "up", False, 1),
             ("load", "side", False, 0), ("tip", "side", False, 2)]
    scale = 6
    cw, ch = 56 * scale, 60 * scale
    img = C(len(shots) * cw, len(roster) * ch)
    img.rect(0, 0, img.w, img.h, GRASS_BG)
    for r, (look, kind) in enumerate(roster):
        sheet = person_frames(*look)
        for i, (row, view, left, f) in enumerate(shots):
            shot = scene(sheet, row, f, view, left, kind, 3 if row != "load" else 1, barrow, loads)
            for yy in range(shot.h):
                for xx in range(shot.w):
                    p = shot.px[yy][xx]
                    if p[3]:
                        img.rect(i * cw + xx * scale, r * ch + yy * scale, scale, scale, p)
    path = os.path.join(SCRATCH, "d55_people_zoom.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


class Sheet:
    def __init__(self, c):
        self.w, self.h, self.px = c.w, c.h, c.px


def existing(name):
    w, h, px = load(name)
    c = C(w, h)
    c.px = [[tuple(p) for p in row] for row in px]
    return c


def blit(dst, src, x, y, scale):
    for yy in range(src.h):
        for xx in range(src.w):
            p = src.px[yy][xx]
            if p[3]:
                a = p[3] / 255
                for dy in range(scale):
                    for dx in range(scale):
                        dst.put(x + xx * scale + dx, y + yy * scale + dy, (p[0], p[1], p[2], p[3]))


def props():
    """Fiecare sprite nou la marimea din joc, pe iarba: gramezile x2 (si x4, ca sa se vada treptele), shed-ul
    si ruina lui x3 langa depozit si gater, fierul langa scanduri."""
    grass = existing("grass_tile")
    W, H = 1500, 1400
    img = C(W, H)
    for y in range(H):
        for x in range(W):
            img.px[y][x] = grass.px[(y // 3) % grass.h][(x // 3) % grass.w]
    y = 16
    for name in ("prop_pile_logs", "prop_pile_planks", "prop_pile_scrap", "prop_pile_iron"):
        strip_img = d55.SPRITES[name]()
        draw_text(img, 12, y, name.upper(), INK, 2)
        for k in range(4):
            frame = sub(strip_img, k * d55.PW, 0, d55.PW, d55.PH)
            blit(img, frame, 12 + k * 100, y + 24, 2)  # marimea din joc
            blit(img, frame, 440 + k * 170, y + 24 - 30, 4)
        y += 150
    draw_text(img, 12, y, "SHED / RUIN / STORAGE / SAWMILL  X3", INK, 2)
    row = [d55.prop_scrap_shed(), d55.prop_ruin_scrap_shed(), existing("prop_storage"), existing("prop_sawmill")]
    for k, spr in enumerate(row):
        blit(img, spr, 12 + k * 140, y + 30, 3)
    draw_text(img, 620, y, "IRON / PLANKS  X3", INK, 2)
    blit(img, d55.goods_iron(), 620, y + 40, 3)
    blit(img, existing("goods_planks"), 720, y + 40, 3)
    y += 170
    draw_text(img, 12, y, "HUTS X3: BOARD / 1 PERSON / 2 PEOPLE", INK, 2)
    x = 12
    for role in ("porter", "sawyer", "hauler"):
        blit(img, existing("prop_board_old"), x, y + 30 + 108 - 64, 2)
        blit(img, d55.SPRITES[f"prop_hut_{role}_1"](), x + 60, y + 30 + 102 - 84, 3)
        blit(img, d55.SPRITES[f"prop_hut_{role}_2"](), x + 170, y + 30, 3)
        x += 310
    y += 170
    draw_text(img, 12, y, "COLLECTOR 1/2 X3, INNKEEPER 1/2 X2", INK, 2)
    blit(img, existing("prop_runner_hut"), 12, y + 30 + 12, 3)
    blit(img, d55.prop_runner_hut_2(), 150, y + 30, 3)
    blit(img, existing("prop_stall"), 330, y + 30 + 0, 2)
    blit(img, d55.prop_stall_2(), 440, y + 30, 2)
    path = os.path.join(SCRATCH, "d55_props.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


# ---- harta: pozitiile noi (oglinda a ce intra in TycoonConfig) -------------------------------------
# cladirile platformelor: baza = pad.y + 56 (PadController); gramezile: centru-jos, x2; oamenii: picioarele
LAYOUT = {
    "pads": {  # id -> (x, y, sprite, scale)
        "first_runner": (1785, 975, "prop_runner_hut_2", 3),
        "hire_porter": (1705, 1234, "prop_hut_porter_2", 3),
        "hire_sawyer": (1420, 1316, "prop_hut_sawyer_2", 3),
        "hire_hauler": (648, 1234, "prop_hut_hauler_2", 3),
        "dock_trader": (660, 1000, "prop_stall_2", 2),
        "scrap_shed": (1400, 964, "prop_scrap_shed", 3),
        "workshop": (820, 1380, "prop_workshop_e1", 3),
        "bigger_sack": (1060, 1300, "prop_sack", 2),
        "landing_bell": (1770, 1420, "prop_bell", 3),
    },
    "piles": {  # nume -> (x, baza, fel, treapta) -- TycoonConfig.PILES
        "storage": (1600, 1096, "logs", 3),
        "shed": (1290, 1024, "scrap", 3),
        "sawmillIn": (1318, 1482, "logs", 4),
        "sawmillOut": (1525, 1482, "planks", 4),
        "forgeIn": (680, 1440, "scrap", 3),
        "forgeOut": (960, 1440, "iron", 3),
        "tavern": (262, 1086, "planks", 2),
    },
    "stands": {  # unde se opresc oamenii (picioarele) -- TycoonConfig
        "storage": (1540, 1122), "shed": (1350, 1080), "sawmillIn": (1260, 1512), "sawmillOut": (1600, 1515),
        "forgeIn": (620, 1515), "forgeOut": (1020, 1515), "player_saw": (1390, 1540),
        "sawyer1": (1450, 1552), "sawyer2": (1510, 1556), "trader1": (470, 1152), "trader2": (530, 1152),
    },
}


def world_map():
    """Malul Erei 1 (x 200..1960, y 540..1620) la jumatate: toate cladirile construite, colibele MARI (cele
    mai late amprente), gramezile pe treapta 3-4, oamenii statici si opririle marcate cu un punct."""
    import preview_ruins as R

    grass, water, deck, path = (R.existing(n) for n in ("grass_tile", "water_tile", "deck_tile", "path_tile"))
    X0, Y0, X1, Y1, D = 200, 540, 1960, 1620, 2
    W, H = (X1 - X0) // D, (Y1 - Y0) // D
    img = R.Img(W, H, (86, 128, 64))

    def sx(x):
        return (x - X0) // D

    def sy(y):
        return (y - Y0) // D

    img.tile(grass, 0, 0, W, H, X0, Y0, D)
    img.tile(water, 0, 0, W, sy(772), X0, Y0, D)
    img.tile(deck, sx(240), sy(772), sx(1560), sy(856), 240, 772, D)
    roads = [
        (240, 1800, 1100, 1160), (1470, 1520, 856, 1100), (520, 570, 856, 1100), (1570, 1630, 1160, 1480),
        (1300, 1630, 1480, 1560), (500, 1300, 1500, 1560), (500, 560, 1160, 1500),
    ]
    for x0, x1, y0, y1 in roads:
        img.tile(path, sx(x0), sy(y0), sx(x1), sy(y1), x0, y0, D)
    img.blit(R.existing("prop_tavern"), sx(400), sy(1080), 3, down=D)
    img.blit(R.existing("prop_storage"), sx(1600), sy(1020), 3, down=D)
    img.blit(R.existing("prop_sawmill"), sx(1420), sy(1480), 3, down=D)
    img.blit(R.existing("prop_wheel"), sx(330), sy(1360), 3, down=D)
    for pid, x in (("n1", 620), ("n2", 820), ("n3", 1020), ("n4", 1220), ("n5", 1420)):
        img.blit(R.existing("prop_netpost"), sx(x), sy(812), 2, None, D)
    for pid, (x, y, name, scale) in LAYOUT["pads"].items():
        spr = R.Sprite(*load(name)) if os.path.exists(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "sprites", name + ".png")) and name not in d55.SPRITES else None
        if spr is None:
            c = d55.SPRITES[name]()
            spr = R.Sprite(c.w, c.h, c.px)
        img.blit(spr, sx(x), sy(y + 56), scale, None, D)
    piles = {k: d55.SPRITES[f"prop_pile_{k}"]() for k in ("logs", "planks", "scrap", "iron")}
    order = sorted(LAYOUT["piles"].items(), key=lambda kv: kv[1][1])
    for name, (x, base, kind, step) in order:
        frame = sub(piles[kind], (step - 1) * d55.PW, 0, d55.PW, d55.PH)
        img.blit(R.Sprite(frame.w, frame.h, frame.px), sx(x), sy(base), 2, None, D)
        img.rect(sx(x) - 13, sy(base) - 34, 26, 12, (40, 30, 22, 200))
    for name, (x, y) in LAYOUT["stands"].items():
        img.rect(sx(x) - 2, sy(y) - 2, 5, 5, (240, 60, 60, 255) if name.startswith(("saw", "trader", "player")) else (250, 220, 70, 255))
    img.save("d55_map.png")


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "people"
    if what == "people":
        people(sys.argv[2] if len(sys.argv) > 2 else None)
    elif what == "zoom":
        zoom()
    elif what == "props":
        props()
    elif what == "map":
        world_map()
