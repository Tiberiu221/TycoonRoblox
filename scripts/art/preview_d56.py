#!/usr/bin/env python3
"""Previzualizarea artei D56, inainte de urcare. Scrie DOAR in folderul de lucru (scripts/art/scratch.py).

  d56_people.png  -- Scrap Collector, Scrap Porter si Iron Hauler cu roaba (mersul in trei directii, incarcatul,
                     rasturnatul), Smelter-ul la ciocan si stand -- la x4, pe iarba, compusi din straturi ca in joc;
  d56_lineup.png  -- toate cele noua meserii una langa alta (fata si lateral), la x6: se deosebesc dintr-o privire?
  d56_props.png   -- colibele noi la marimea din joc (x3), langa cele ale oamenilor de lemn, si fumul forjei;
  d56_map.png     -- malul Erei 1 cu tot construit, colibele MARI, gramezile, inelele si locurile oamenilor, cu
                     pozitiile CITITE din TycoonConfig.luau (nu copiate de mana, ca in D55).

Rulare: python3 scripts/art/preview_d56.py [people|lineup|props|map]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import preview_d55 as P  # noqa: E402

SCRATCH = P.SCRATCH

# (nume, (corp, par, tinuta, piele, par-ton), incarcatura)
WALKERS = [
    ("Scrap Collector", ("a", "short", "scrapper", (28, 0.32, 1.05), (25, 0.55, 1.0)), "scrap"),
    ("Scrap Porter", ("b", "long", "carter", (26, 0.55, 0.85), (45, 0.60, 1.15)), "scrap"),
    ("Iron Hauler", ("a", "bun", "ironmonger", (22, 0.62, 0.58), (5, 0.65, 0.55)), "iron"),
]
SMITH = ("Smelter", ("b", "short", "smith", (24, 0.45, 0.95), (30, 0.50, 0.70)))
ALL_CREW = [
    ("Collector", "fisher"), ("Porter", "crafter"), ("Sawyer", "builder"), ("Hauler", "gardener"),
    ("Innkeeper", "innkeeper"), ("Scrap Col.", "scrapper"), ("Scrap Por.", "carter"), ("Smelter", "smith"),
    ("Iron Haul.", "ironmonger"),
]


def blit_scaled(img, shot, x, y, scale):
    for yy in range(shot.h):
        for xx in range(shot.w):
            p = shot.px[yy][xx]
            if p[3]:
                img.rect(x + xx * scale, y + yy * scale, scale, scale, p)


def people():
    barrow = d55.prop_barrow()
    loads = {k: getattr(d55, f"prop_load_{k}")() for k in ("logs", "planks", "scrap", "iron", "crate")}
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
    rows = len(WALKERS) * len(shots) + 2
    img = C(170 + 4 * cw, 20 + rows * (ch + 6) + 20)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    y = 20
    for name, look, load_kind in WALKERS:
        sheet = P.person_frames(*look)
        for row, view, left in shots:
            P.draw_text(img, 8, y + ch // 2 - 6, f"{name} {row}{' <' if left else ''}".upper(), P.INK, 1)
            for f in range(4):
                step = 3 if row != "load" else (0, 1, 2, 3)[f]
                shot = P.scene(sheet, row, f, view, left, load_kind, step, barrow, loads)
                blit_scaled(img, shot, 170 + f * cw, y, scale)
            y += ch + 6
    name, look = SMITH
    sheet = P.person_frames(*look)
    for row in ("work", "idle_down"):
        P.draw_text(img, 8, y + ch // 2 - 6, f"{name} {row}".upper(), P.INK, 1)
        for f in range(4):
            person = P.cell(sheet, row, f)
            canvas = C(56, 60)
            P.paste(canvas, person, 20, 20)
            P.outline_all(canvas)
            blit_scaled(img, canvas, 170 + f * cw, y, scale)
        y += ch + 6
    path = os.path.join(SCRATCH, "d56_people.png")
    P.write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def lineup():
    scale = 6
    cw = 22 * scale
    img = C(len(ALL_CREW) * cw + 20, 2 * 30 * scale + 60)
    img.rect(0, 0, img.w, img.h, P.GRASS_BG)
    for i, (label, outfit) in enumerate(ALL_CREW):
        sheet = P.person_frames("a", "short", outfit, (26, 0.45, 0.95), (28, 0.55, 0.9))
        for r, row in enumerate(("idle_down", "walk_side")):
            person = P.cell(sheet, row, 1)
            canvas = C(20, 28)
            P.paste(canvas, person, 2, 2)
            P.outline_all(canvas)
            blit_scaled(img, canvas, 10 + i * cw, 10 + r * 30 * scale, scale)
        P.draw_text(img, 10 + i * cw, img.h - 40, label.upper(), P.INK, 1)
    path = os.path.join(SCRATCH, "d56_lineup.png")
    P.write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


def props():
    grass = P.existing("grass_tile")
    W, H = 1400, 860
    img = C(W, H)
    for y in range(H):
        for x in range(W):
            img.px[y][x] = grass.px[(y // 3) % grass.h][(x // 3) % grass.w]
    y = 12
    P.draw_text(img, 12, y, "WOOD LINE HUTS X3 (D55): 1 PERSON / 2 PEOPLE", P.INK, 2)
    x = 12
    for role in ("porter", "sawyer", "hauler"):
        P.blit(img, d55.SPRITES[f"prop_hut_{role}_1"](), x, y + 30 + 102 - 84, 3)
        P.blit(img, d55.SPRITES[f"prop_hut_{role}_2"](), x + 110, y + 30, 3)
        x += 250
    y += 170
    P.draw_text(img, 12, y, "IRON LINE HUTS X3 (D56): 1 PERSON / 2 PEOPLE", P.INK, 2)
    for r, roles in enumerate((("scrap_collector", "scrap_porter"), ("smelter", "iron_hauler"))):
        x = 12
        for role in roles:
            P.draw_text(img, x, y + 26 + r * 150, role.upper(), P.INK, 1)
            P.blit(img, d56.SPRITES[f"prop_hut_{role}_1"](), x, y + 40 + r * 150 + 102 - 84, 3)
            P.blit(img, d56.SPRITES[f"prop_hut_{role}_2"](), x + 110, y + 40 + r * 150, 3)
            x += 300
    y += 330
    P.draw_text(img, 12, y, "FORGE SMOKE X3 / X6, OVER THE FORGE", P.INK, 2)
    smoke = d56.prop_forge_smoke()
    for k in range(3):
        frame = P.sub(smoke, k * d56.SMOKE_W, 0, d56.SMOKE_W, d56.SMOKE_H)
        P.blit(img, frame, 12 + k * 40, y + 40, 3)
        P.blit(img, frame, 150 + k * 70, y + 30, 6)
    forge = P.existing("prop_workshop_e1")
    P.blit(img, forge, 420, y + 60, 3)
    for k, (dx, dy) in enumerate(((0, 0), (4, -16), (-6, -34))):
        frame = P.sub(smoke, k * d56.SMOKE_W, 0, d56.SMOKE_W, d56.SMOKE_H)
        P.blit(img, frame, 420 + 147 - 15 + dx, y + 60 - 30 + dy, 3)
    path = os.path.join(SCRATCH, "d56_props.png")
    P.write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


# ---- harta: pozitiile din TycoonConfig.luau ------------------------------------------------------------------
CONFIG = os.path.join(os.path.dirname(__file__), "..", "..", "src", "Shared", "Config", "TycoonConfig.luau")
# platforma -> (sprite, scara); cladirea sta cu baza la pad.y + 56 (PadController)
PAD_SPRITES = {
    "first_runner": ("prop_runner_hut_2", 3),
    "hire_porter": ("prop_hut_porter_2", 3),
    "hire_sawyer": ("prop_hut_sawyer_2", 3),
    "hire_hauler": ("prop_hut_hauler_2", 3),
    "dock_trader": ("prop_stall_2", 2),
    "scrap_shed": ("prop_scrap_shed", 3),
    "workshop": ("prop_workshop_e1", 3),
    "bigger_sack": ("prop_sack", 2),
    "landing_bell": ("prop_bell", 3),
    "hire_scrap_collector": ("prop_hut_scrap_collector_2", 3),
    "hire_scrap_porter": ("prop_hut_scrap_porter_2", 3),
    "hire_smelter": ("prop_hut_smelter_2", 3),
    "hire_iron_hauler": ("prop_hut_iron_hauler_2", 3),
}
PILE_KIND = {
    "storage": "logs", "shed": "scrap", "sawmillIn": "logs", "sawmillOut": "planks",
    "forgeIn": "scrap", "forgeOut": "iron", "tavern": "planks",
}


def read_layout():
    text = open(CONFIG).read()
    pads = {}
    chunks = text.split('id = "')
    for chunk in chunks[1:]:
        pid = chunk.split('"', 1)[0]
        head = chunk.split('id = "', 1)[0]
        mx = re.search(r"\n\s+x = (\d+),\n\s+y = (\d+),", head)
        if mx and pid not in pads:
            pads[pid] = (int(mx.group(1)), int(mx.group(2)))
    block = text.split("TycoonConfig.PILES = {", 1)[1].split("}\n", 1)[0] + "}"
    piles = {m.group(1): (int(m.group(2)), int(m.group(3))) for m in re.finditer(r"(\w+) = \{ x = (\d+), y = (\d+)", block)}
    points = {
        m.group(1): (int(m.group(2)), int(m.group(3)))
        for m in re.finditer(r"TycoonConfig\.(\w+) = \{ x = (\d+), y = (\d+)", text)
    }
    offsets = {}
    line = text.split("TycoonConfig.SECOND_STAND_OFFSET =", 1)[1].split("\nlocal ", 1)[0]
    for m in re.finditer(r"(\w+) = \{ x = (-?\d+), y = (-?\d+) \}", line):
        offsets[m.group(1)] = (int(m.group(2)), int(m.group(3)))
    assert {"sawyer", "trader", "smelter"} <= set(offsets), offsets
    return pads, piles, points, offsets


def world_map(X0=200, Y0=540, X1=1960, Y1=1620, D=2, out="d56_map.png"):
    """Malul Erei 1 (x 200..1960, y 540..1620) la jumatate, ca in D55: toate cladirile construite, colibele MARI,
    gramezile pe treapta 3-4, inelele tale (gater, forja) si locurile oamenilor statici, cu pozitiile din config.
    Cu alte margini si D=1: o bucata la marimea din joc."""
    import preview_ruins as R

    pads, piles, points, offsets = read_layout()
    grass, water, deck, path = (R.existing(n) for n in ("grass_tile", "water_tile", "deck_tile", "path_tile"))
    W, H = (X1 - X0) // D, (Y1 - Y0) // D
    img = R.Img(W, H, (86, 128, 64))

    def sx(x):
        return (x - X0) // D

    def sy(y):
        return (y - Y0) // D

    img.tile(grass, 0, 0, W, H, X0, Y0, D)
    img.tile(water, 0, 0, W, sy(772), X0, Y0, D)
    img.tile(deck, sx(240), sy(772), sx(1560), sy(856), 240, 772, D)
    roads = re.findall(
        r"x0 = (\d+), x1 = (\d+), y0 = (\d+), y1 = (\d+) \}",
        open(CONFIG).read().split("TycoonConfig.ROADS = {", 1)[1].split("\n}", 1)[0],
    )
    for x0, x1, y0, y1 in ((int(a), int(b), int(c), int(d)) for a, b, c, d in roads):
        img.tile(path, sx(x0), sy(y0), sx(x1), sy(y1), x0, y0, D)
    img.blit(R.existing("prop_tavern"), sx(400), sy(1080), 3, down=D)
    img.blit(R.existing("prop_storage"), sx(1600), sy(1020), 3, down=D)
    img.blit(R.existing("prop_sawmill"), sx(1420), sy(1480), 3, down=D)
    img.blit(R.existing("prop_wheel"), sx(330), sy(1360), 3, down=D)
    for pid in ("first_net", "second_net", "third_net", "far_lane_net", "fifth_net"):
        x, y = pads[pid]
        img.blit(R.existing("prop_netpost"), sx(x), sy(y), 2, None, D)
    # de sus in jos, ca in joc: ce e mai jos pe ecran se deseneaza peste
    drawn = []
    for pid, (name, scale) in PAD_SPRITES.items():
        x, y = pads[pid]
        drawn.append((y + 56, "pad", pid, x, name, scale))
    for name, (x, base) in piles.items():
        drawn.append((base, "pile", name, x, PILE_KIND.get(name, "logs"), 3))
    pile_art = {k: d55.SPRITES[f"prop_pile_{k}"]() for k in ("logs", "planks", "scrap", "iron")}
    for base, what, name, x, sprite, scale in sorted(drawn):
        if what == "pad":
            img.blit(R.existing(sprite), sx(x), sy(base), scale, None, D)
        else:
            frame = P.sub(pile_art[sprite], 2 * d55.PW, 0, d55.PW, d55.PH)
            img.blit(R.Sprite(frame.w, frame.h, frame.px), sx(x), sy(base), 2, None, D)
    # inelele tale (96x48) si locurile oamenilor statici (rosu), opririle celor care umbla (galben)
    for key in ("SAWMILL_STAND", "WORKSHOP_STAND"):
        x, y = points[key]
        for a in range(0, 360, 4):
            import math

            px = x + 48 * math.cos(math.radians(a))
            py = y - 4 + 24 * math.sin(math.radians(a))
            img.rect(sx(px), sy(py), 2, 2, (250, 214, 80, 255))
    statics = {"SAWYER_STAND": "sawyer", "TRADER_STAND": "trader", "SMELTER_STAND": "smelter"}
    for key, role in statics.items():
        x, y = points[key]
        dx, dy = offsets.get(role, (60, 0))
        for px, py in ((x, y), (x + dx, y + dy)):
            img.rect(sx(px) - 6, sy(py) - 30, 12, 30, (200, 60, 60, 220))
    for key in ("STORAGE_STAND", "SCRAP_SHED_STAND", "SAWMILL_IN", "SAWMILL_OUT", "FORGE_IN", "FORGE_OUT", "DOCK"):
        x, y = points[key]
        img.rect(sx(x) - 3, sy(y) - 3, 7, 7, (250, 230, 70, 255))
    img.save(out)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("people", "all"):
        people()
    if what in ("lineup", "all"):
        lineup()
    if what in ("props", "all"):
        props()
    if what in ("map", "all"):
        world_map()
    if what == "crop":
        # python3 preview_d56.py crop x0 y0 x1 y1 [nume]
        x0, y0, x1, y1 = (int(v) for v in sys.argv[2:6])
        world_map(x0, y0, x1, y1, 1, sys.argv[6] if len(sys.argv) > 6 else "d56_crop.png")
