#!/usr/bin/env python3
"""[D70] Plansele modernizarii Erei 3, inainte de urcare. Scrie DOAR in scratchpad-ul sesiunii.

  d70_stage1.png .. d70_stage5.png  -- fiecare treapta: INAINTE (desenul urcat azi, din assets/sprites) si DUPA (d70_modern,
                                       in memorie), la marimea din joc (x3 cladirile, x2 recuzita), pe iarba
  d70_village.png                   -- The Landing (x 200..1900, y 840..1700) la jumatate, in sase panouri: treptele 0..5
  d70_street.png                    -- o bucata din The Landing la 1:1 (pixel de lume), treapta 0 deasupra, 5 dedesubt
  d70_field.png                     -- curtea goala din mijlocul Wire Works, azi si cu recuzita optionala

Nu e jocul: pozitiile stalpilor, tarusilor si ale oamenilor cu roaba sunt alese aici de mana, ca propunere (le hotaraste
codul). Restul (cladirile, casele, felinarele, drumurile, pamantul copt) vine din aceleasi cifre ca jocul
(scripts/art/village_geometry.luau + un mic export Lune).

Rulare: python3 scripts/art/preview_d70.py [stages|village|street|field|all]
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import preview_tycoon  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
preview_tycoon.SPR = os.path.join(ROOT, "assets", "sprites")  # desenele de azi, din worktree-ul asta
from preview_tycoon import load, write_png  # noqa: E402
from buildings import C  # noqa: E402
import preview_d55 as P  # noqa: E402
import d55  # noqa: E402
import d70_modern as D  # noqa: E402

SCRATCH = P.SCRATCH
BG = P.GRASS_BG
INK = P.INK
_cache = {}


def sprite(name):
    """(w, h, px) dintr-un fisier urcat, sau dintr-o functie D70 (nume din D.SPRITES), cu cache."""
    if name not in _cache:
        if name in D.SPRITES:
            c = D.SPRITES[name]()
            _cache[name] = (c.w, c.h, c.px)
        else:
            _cache[name] = load(name)
    return _cache[name]


def of(c):
    return (c.w, c.h, c.px)


def blit(img, spr, x, y, scale, rect=None, flip=False):
    """Deseneaza `spr` (w, h, px) cu coltul stanga-sus la (x, y) si `scale` pixeli de imagine pe pixel de foaie (poate fi
    fractionar: esantionare pe cel mai apropiat pixel). `rect` = (rx, ry, rw, rh) din foaie; `flip` = oglindit."""
    w, h, px = spr
    rx, ry, rw, rh = rect or (0, 0, w, h)
    dw, dh = int(round(rw * scale)), int(round(rh * scale))
    x0, y0 = int(round(x)), int(round(y))
    for dy in range(dh):
        Y = y0 + dy
        if not (0 <= Y < img.h):
            continue
        sy = ry + min(rh - 1, int(dy / scale))
        row = px[sy]
        for dx in range(dw):
            X = x0 + dx
            if not (0 <= X < img.w):
                continue
            sx = min(rw - 1, int(dx / scale))
            p = row[rx + (rw - 1 - sx if flip else sx)]
            if not p[3]:
                continue
            a = p[3] / 255
            if a >= 1:
                img.px[Y][X] = (p[0], p[1], p[2], 255)
            else:
                bg = img.px[Y][X]
                img.px[Y][X] = (round(bg[0] * (1 - a) + p[0] * a), round(bg[1] * (1 - a) + p[1] * a),
                                round(bg[2] * (1 - a) + p[2] * a), 255)


def label(img, x, y, text):
    P.draw_text(img, int(x), int(y), text.upper(), INK, 1)


def wire(img, a, b, color, thick, sag_frac=0.06):
    """Firul dintre doi izolatori: o curba cu sageata la mijloc (asa l-ar desena codul)."""
    (xa, ya), (xb, yb) = a, b
    span = abs(xb - xa)
    sag = sag_frac * span
    n = max(2, int(span))
    for i in range(n + 1):
        t = i / n
        x = xa + (xb - xa) * t
        y = ya + (yb - ya) * t + sag * 4 * t * (1 - t)
        for k in range(thick):
            X, Y = int(round(x)), int(round(y)) + k
            if 0 <= X < img.w and 0 <= Y < img.h:
                img.px[Y][X] = color


# ---------------------------------------------------------------------------------------------
# oamenii cu roaba (din foile compuse in memorie, ca preview_d55)

ROSTER = [
    (("a", "short", "fisher", (28, 0.32, 1.05), (25, 0.55, 1.0)), "logs"),
    (("b", "long", "crafter", (26, 0.55, 0.85), (45, 0.60, 1.15)), "scrap"),
    (("a", "bun", "gardener", (22, 0.62, 0.58), (5, 0.65, 0.55)), "planks"),
]
_people = {}


def person_shot(i, row, f, view, left, iron, step=3):
    """Un cadru 56x60 (om + roaba + incarcatura), cu roaba de lemn sau de fier."""
    key = (i, row, f, view, left, iron, step)
    if key not in _people:
        look, kind = ROSTER[i]
        sheet = _people.get(("sheet", i))
        if sheet is None:
            sheet = P.person_frames(*look)
            _people[("sheet", i)] = sheet
        barrow = D.prop_barrow_iron() if iron else d55.prop_barrow()
        loads = {k: getattr(d55, f"prop_load_{k}")() for k in ("logs", "planks", "scrap", "iron", "crate")}
        _people[key] = P.scene(sheet, row, f, view, left, kind, step, barrow, loads)
    return _people[key]


# ---------------------------------------------------------------------------------------------
# plansele pe trepte


def sheet(w, h):
    img = C(w, h)
    img.rect(0, 0, img.w, img.h, BG)
    return img


def headline(img, text, y=8):
    label(img, 10, y, text)


def stage1():
    """Strada: azi (felinarul) si cu stalpii si firele. La x3, o deschidere de 100 de pixeli de foaie (300 de lume)."""
    s = 3
    span = 100  # pixeli de foaie intre doi stalpi
    width = 40 + (span * 2 + 60) * s
    img = sheet(width, 60 + 2 * (70 * s) + 40)
    headline(img, "STAGE 1  CLERK (~4 MIN)  WIRE COMES TO EVERY STREET  -  BEFORE (TOP) / AFTER (BOTTOM), X3")
    for k, after in enumerate((False, True)):
        top = 30 + k * (70 * s + 20)
        base = top + 62 * s  # baza obiectelor
        img.rect(0, base - 2 * s, img.w, 14 * s, (120, 92, 60, 255))  # strada (pamant)
        img.rect(0, base - 2 * s, img.w, 1 * s, (140, 110, 74, 255))
        lamp = sprite("prop_street_lamp")
        blit(img, lamp, 20 + (span + 20) * s, base - lamp[1] * s + 8 * s, s)
        if after:
            end = sprite("prop_wire_pole_end")
            pole = sprite("prop_wire_pole")
            xs = [60, 60 + (span // 2 + 5) * s, 60 + (span + 30) * s, 60 + (span * 2 + 10) * s]
            tops = []
            for i, x in enumerate(xs):
                spr = end if i == 0 else pole
                dxp = D.END_POLE_DX if i == 0 else 0
                y = base - spr[1] * s
                blit(img, spr, x - dxp * s, y, s)
                tops.append({n: (x + (D.POLE_WIRES[n][0]) * s, y + D.POLE_WIRES[n][1] * s) for n in ("near", "far")})
            for a, b in zip(tops, tops[1:]):
                wire(img, a["far"], b["far"], D.WIRE["color_far"], 2)
                wire(img, a["near"], b["near"], D.WIRE["color_near"], 2)
            label(img, 10, top, "AFTER: END POLE (WEST), LINE POLES, TWO WIRES DRAWN BY CODE (2 PX, SAG 6%)")
        else:
            label(img, 10, top, "BEFORE: THE STREET LAMP [D67] IS THE ONLY THING ON THE STREET")
    path = os.path.join(SCRATCH, "d70_stage1.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


def stage2():
    s = 3
    shots = [("push_side", "side", False, 1), ("push_side", "side", True, 2), ("push_down", "down", False, 0),
             ("push_up", "up", False, 1), ("load", "side", False, 2), ("tip", "side", False, 2)]
    cw = 56 * s
    img = sheet(160 + len(shots) * cw, 40 + 2 * (20 * 4 + 20) + 2 * 3 * (60 * s + 6) + 40)
    headline(img, "STAGE 2  THIRTEENTH NET (~14 MIN)  IRON CARTS  -  SAME SHEET, SAME ANCHORS")
    y = 30
    for title, strip in (("BEFORE: PROP_BARROW", sprite("prop_barrow")), ("AFTER: PROP_BARROW_IRON", sprite("prop_barrow_iron"))):
        label(img, 10, y + 30, title)
        blit(img, strip, 200, y, 4)
        y += 20 * 4 + 20
    for iron in (False, True):
        label(img, 10, y, "WITH PEOPLE, X3 (GAME: X2.5): " + ("AFTER, IRON" if iron else "BEFORE, WOOD"))
        y += 14
        for i in range(3):
            for k, (row, view, left, f) in enumerate(shots):
                shot = person_shot(i, row, f, view, left, iron, 3 if row != "load" else 2)
                blit(img, of(shot), 160 + k * cw, y, s)
            y += 60 * s + 6
    path = os.path.join(SCRATCH, "d70_stage2.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


def stage3():
    s = 3
    col_w, row_h = 64 * s + 24, 48 * s + 30
    img = sheet(20 + 4 * col_w, 40 + 4 * row_h)
    headline(img, "STAGE 3  SECOND WORKS PORTER (~19 MIN)  TIN ROOFS AND BRICK  -  BEFORE | AFTER, X3")
    for i, (name, _fn, base) in enumerate(D.MODERN):
        r, c = i // 2, i % 2
        x = 10 + c * 2 * col_w
        y = 34 + r * row_h
        for k, spr in enumerate((sprite(base), sprite(name))):
            blit(img, spr, x + k * col_w, y + (48 - spr[1]) * s, s)
        label(img, x, y + 48 * s + 4, base.replace("prop_", "") + "  ->  " + name.replace("prop_", ""))
    path = os.path.join(SCRATCH, "d70_stage3.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


def overlay_cell(atlas, cell):
    """Stratul unei case din atlas, ca (w, h, px) de marimea casei."""
    w, h, px = atlas
    return (cell["w"], cell["h"], [row[cell["x"]:cell["x"] + cell["w"]] for row in px[cell["y"]:cell["y"] + cell["h"]]])


def hut_row(img, names, y, s, atlas_name, gap=6):
    cells = D.window_cells()
    atlas = sprite(atlas_name) if atlas_name else None
    for k, name in enumerate(names):
        spr = sprite("prop_" + name)
        x = 10 + k * (40 * s + gap)
        yy = y + (34 - spr[1]) * s
        blit(img, spr, x, yy, s)
        if atlas is not None:
            blit(img, overlay_cell(atlas, cells[name]), x, yy, s)


SAMPLE_HUTS = ["hut_porter_2", "hut_sawyer_1", "hut_sawyer_2", "hut_hauler_2", "hut_scrap_porter_2", "hut_smelter_2",
               "hut_mill_porter_2", "hut_founder_2", "hut_ore_porter_1", "hut_works_porter_2"]


def stage4():
    s = 3
    n = len(SAMPLE_HUTS)
    img = sheet(20 + n * (40 * s + 6), 40 + 2 * (34 * s + 24) + 50 * 2 + 110)
    headline(img, "STAGE 4  POWER HOUSE (~41 MIN)  GLASS WINDOWS, DAM PLANS, SURVEY STAKES")
    y = 30
    label(img, 10, y, "BEFORE: WINDOWS TODAY (X3)")
    hut_row(img, SAMPLE_HUTS, y + 12, s, None)
    y += 34 * s + 24
    label(img, 10, y, "AFTER: SAME HOUSE + ITS CELL FROM PROP_WINDOWS_GLASS (ANYTHING IN FRONT STAYS IN FRONT)")
    hut_row(img, SAMPLE_HUTS, y + 12, s, "prop_windows_glass")
    y += 34 * s + 30
    label(img, 10, y, "NEW, X2: DAM PLANS (WIRE WORKS, EAST END)        SURVEY STAKES WITH THEIR STRING (NEAR THE PIER)")
    plans = sprite("prop_dam_plans")
    blit(img, plans, 10, y + 14, 2)
    stakes = sprite("prop_survey_stakes")
    xs = [160, 230, 300, 370, 440]
    frames = [0, 1, 0, 1, 2]
    base = y + 14 + 44 * 2
    pins = []
    for x, f in zip(xs, frames):
        blit(img, stakes, x, base - 26 * 2, 2, rect=(f * 12, 0, 12, 26))
        if f != 2:  # nivela nu tine sfoara
            sx, sy = D.STAKE_STRING[f]
            pins.append((x + sx * 2, base - 26 * 2 + sy * 2))
    for a, b in zip(pins, pins[1:]):
        wire(img, a, b, (222, 70, 60, 255), 1, 0.03)
    blit(img, stakes, 520, y + 14, 4)
    path = os.path.join(SCRATCH, "d70_stage4.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


def stage5():
    s = 3
    n = len(SAMPLE_HUTS)
    img = sheet(20 + n * (40 * s + 6), 40 + 2 * (34 * s + 24) + 3 * (48 * s + 30) + 40)
    headline(img, "STAGE 5  FIRST POWER SOLD (~48 MIN)  THE VILLAGE LIGHTS UP")
    y = 30
    label(img, 10, y, "STAGE 4 (GLASS)")
    hut_row(img, SAMPLE_HUTS, y + 12, s, "prop_windows_glass")
    y += 34 * s + 24
    label(img, 10, y, "STAGE 5: SAME HOUSE + ITS CELL FROM PROP_WINDOWS_LIT (ELECTRIC LIGHT + LIGHT ON THE WALL)")
    hut_row(img, SAMPLE_HUTS, y + 12, s, "prop_windows_lit")
    y += 34 * s + 30
    label(img, 10, y, "MODERN BUILDINGS, STAGE 3-4 | STAGE 5 (+ THEIR CELL FROM PROP_MODERN_LIT: SIGN BULBS, ELECTRIC LAMPS)")
    y += 14
    lit = sprite("prop_modern_lit")
    cells = D.modern_lit_cells()
    names = [m[0] for m in D.MODERN]
    col_w = 64 * s + 6
    for i, name in enumerate(names):
        r, c = i // 3, i % 3
        x, yy = 10 + c * (2 * col_w + 24), y + r * (48 * s + 30)
        spr = sprite(name)
        yy2 = yy + (48 - spr[1]) * s
        blit(img, spr, x, yy2, s)
        blit(img, spr, x + col_w, yy2, s)
        blit(img, overlay_cell(lit, cells[name.replace("prop_", "")]), x + col_w, yy2, s)
    path = os.path.join(SCRATCH, "d70_stage5.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


# ---------------------------------------------------------------------------------------------
# The Landing, treapta cu treapta

EXPORT = """
local serde = require("@lune/serde")
local T = require("../../../src/Shared/Config/TycoonConfig")
local out = { fixed = {}, lamps = T.streetLamps(), decor = T.DECOR, pier = T.PIER, lamp_base = T.LAMP_BASE_Y }
for _, key in { "TAVERN", "STORAGE", "SAWMILL", "WORKS_STORE", "WIRE_WORKS", "DEPOT" } do
    out.fixed[key] = T[key]
end
print(serde.encode("json", out))
"""


def places():
    if "places" in _cache:
        return _cache["places"]
    tmp = os.path.join(HERE, "_tmp_d70")
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "places.luau")
    with open(path, "w") as f:
        f.write(EXPORT)
    try:
        res = subprocess.run(["lune", "run", path], cwd=ROOT, capture_output=True, text=True)
        if res.returncode != 0:
            sys.exit("exportul locurilor a picat:\n" + res.stderr)
        out = json.loads(res.stdout)
    finally:
        os.remove(path)
        os.rmdir(tmp)
    res = subprocess.run(["lune", "run", os.path.join("scripts", "art", "village_geometry")], cwd=ROOT,
                         capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit("village_geometry a picat:\n" + res.stderr)
    out["geometry"] = json.loads(res.stdout)
    _cache["places"] = out
    return out


# platforma Erei 1 -> (desenul, scara); casele mari (doi oameni), ca spre sfarsitul Erei 3
PAD_ART = {
    "first_runner": ("prop_runner_hut_2", 3), "hire_porter": ("prop_hut_porter_2", 3),
    "hire_sawyer": ("prop_hut_sawyer_2", 3), "hire_hauler": ("prop_hut_hauler_2", 3),
    "dock_trader": ("prop_stall_2", 2), "bigger_sack": ("prop_sack", 2),
    "hire_scrap_collector": ("prop_hut_scrap_collector_2", 3), "hire_scrap_porter": ("prop_hut_scrap_porter_2", 3),
    "hire_smelter": ("prop_hut_smelter_2", 3), "hire_iron_hauler": ("prop_hut_iron_hauler_2", 3),
    "scrap_shed": ("prop_scrap_shed", 3), "workshop": ("prop_workshop_e1", 3), "landing_bell": ("prop_bell", 3),
}
MODERN_OF = {base: name for name, _fn, base in D.MODERN}
# PROPUNERE: stalpii pe marginea de NORD a strazii (baza la y 1418), in golurile dintre curti, unde nu sta nimeni la
# lucru; capatul de vest cu stalpul de ancorare. Linia merge mai departe spre Moara si Wire Works (x 1880, ...).
POLES = [(248, True), (480, False), (786, False), (1222, False), (1556, False), (1882, False)]
POLE_BASE_Y = 1418
# PROPUNERE: tarusii pe iarba dintre punte si curtea depozitului, pe linia zidului (x 640..880)
STAKES = [(610, 2), (650, 0), (710, 1), (770, 0), (830, 1), (880, 0)]
STAKE_BASE_Y = 905
# oameni cu roaba pe strada (x, baza, cadru)
WALKERS = [(700, 1446, 0, "push_side", "side", False), (1340, 1470, 1, "push_side", "side", True),
           (1180, 1460, 2, "push_side", "side", True)]


def landing(stage, wx0, wx1, wy0, wy1, scale):
    """The Landing la treapta `stage` (0 = azi), fereastra de lume (wx0..wx1, wy0..wy1), `scale` pixeli de imagine pe
    pixel de lume."""
    pl = places()
    G = pl["geometry"]
    img = C(int((wx1 - wx0) * scale), int((wy1 - wy0) * scale))
    img.rect(0, 0, img.w, img.h, (70, 110, 150, 255))
    tw, th, gpx = sprite("prop_village_ground")
    gs = 3 * scale
    blit(img, (tw, th, gpx), -wx0 * scale, -wy0 * scale, gs)

    def at(spr, x, base, art_scale, rect=None, flip=False, anchor_x=None):
        w = (rect[2] if rect else spr[0])
        h = (rect[3] if rect else spr[1])
        ax = anchor_x if anchor_x is not None else w / 2
        blit(img, spr, (x - wx0 - ax * art_scale) * scale, (base - wy0 - h * art_scale) * scale, art_scale * scale,
             rect=rect, flip=flip)

    things = []  # (adancime, functie)

    def add(depth, fn):
        things.append((depth, len(things), fn))

    def building(name):
        if stage >= 3 and name in MODERN_OF:
            return MODERN_OF[name]
        return name

    fixed = pl["fixed"]
    for key, name in (("TAVERN", "prop_tavern"), ("STORAGE", "prop_storage"), ("SAWMILL", "prop_sawmill")):
        box = fixed[key]
        nm = building(name)
        add(box["y"], lambda nm=nm, box=box: draw_building(at, nm, box["x"], box["y"], stage))
    for pad in G["pads"]:
        art = PAD_ART.get(pad["id"])
        if art is None or pad["x"] > wx1 + 100:
            continue
        nm = building(art[0])
        base = pad["y"] + 56
        add(base, lambda nm=nm, pad=pad, base=base, sc=art[1]: draw_building(at, nm, pad["x"], base, stage, sc))
    for item in pl["decor"]:
        nm = "prop_" + item["sprite"]
        add(item["y"], lambda nm=nm, item=item: at(sprite(nm), item["x"], item["y"], item["scale"]))
    for item in G["scattered"]:
        nm = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}.get(item["kind"])
        if nm and wx0 - 100 < item["x"] < wx1 + 100:
            add(item["y"], lambda nm=nm, item=item: at(sprite(nm), item["x"], item["y"], 3))
    pier = pl["pier"]
    add(pier["y"] - 400, lambda: at(sprite("prop_pier_long"), pier["x"], pier["y"] + 156, 3))
    # felinarele strazii: aprinse de la treapta 5
    for lamp in pl["lamps"]:
        if lamp["era"] != 1:
            continue
        if stage >= 5:
            add(lamp["y"] - 0.5, lambda lamp=lamp: at(sprite("prop_lamp_glow"), lamp["x"], lamp["y"] - 99 + 48, 3))
        add(lamp["y"], lambda lamp=lamp: at(sprite("prop_street_lamp_lit" if stage >= 5 else "prop_street_lamp"),
                                             lamp["x"], lamp["y"], 3))
    # treapta 1: stalpii si firele
    if stage >= 1:
        tops = []
        for x, is_end in POLES:
            nm = "prop_wire_pole_end" if is_end else "prop_wire_pole"
            spr = sprite(nm)
            ax = 8 + (D.END_POLE_DX if is_end else 0)
            add(POLE_BASE_Y, lambda spr=spr, x=x, ax=ax: at(spr, x, POLE_BASE_Y, 3, anchor_x=ax))
            tops.append({n: (x + (D.POLE_WIRES[n][0] - 8) * 3, POLE_BASE_Y - (54 - D.POLE_WIRES[n][1]) * 3)
                         for n in ("near", "far")})

        def wires(tops=tops):
            for a, b in zip(tops, tops[1:]):
                for n, col in (("far", D.WIRE["color_far"]), ("near", D.WIRE["color_near"])):
                    pa = ((a[n][0] - wx0) * scale, (a[n][1] - wy0) * scale)
                    pb = ((b[n][0] - wx0) * scale, (b[n][1] - wy0) * scale)
                    wire(img, pa, pb, col, max(1, round(2 * scale)))

        add(POLE_BASE_Y + 0.5, wires)
    # treapta 4: tarusii pe linia zidului
    if stage >= 4:
        pins = []
        for x, f in STAKES:
            add(STAKE_BASE_Y, lambda x=x, f=f: at(sprite("prop_survey_stakes"), x, STAKE_BASE_Y, 2, rect=(f * 12, 0, 12, 26)))
            if f != 2:
                sx, sy = D.STAKE_STRING[f]
                pins.append((x + (sx - 6) * 2, STAKE_BASE_Y - (26 - sy) * 2))

        def string(pins=pins):
            for a, b in zip(pins, pins[1:]):
                wire(img, ((a[0] - wx0) * scale, (a[1] - wy0) * scale), ((b[0] - wx0) * scale, (b[1] - wy0) * scale),
                     (222, 70, 60, 255), 1, 0.03)

        add(STAKE_BASE_Y + 0.5, string)
    # oamenii cu roaba (de fier de la treapta 2)
    for x, base, who, row, view, left in WALKERS:
        shot = person_shot(who, row, 1, view, left, stage >= 2)
        # celula omului e la (20, 20) in cadrul de 56x60; talpile pe randul 43 (marginea de jos la 44)
        add(base, lambda shot=shot, x=x, base=base: at(of(shot), x, base + (60 - 44) * 2.5, 2.5, anchor_x=28))
    for _d, _i, fn in sorted(things, key=lambda t: (t[0], t[1])):
        fn()
    return img


def draw_building(at, name, x, base, stage, art_scale=3):
    spr = sprite(name)
    at(spr, x, base, art_scale)
    short = name.replace("prop_", "")
    if stage >= 4:
        cells = D.window_cells()
        if short in cells:
            atlas = sprite("prop_windows_lit" if stage >= 5 else "prop_windows_glass")
            at(overlay_cell(atlas, cells[short]), x, base, art_scale)
    if stage >= 5:
        cells = D.modern_lit_cells()
        if short in cells:
            at(overlay_cell(sprite("prop_modern_lit"), cells[short]), x, base, art_scale)


STAGE_TITLES = ["0  TODAY", "1  CLERK: WIRE ON EVERY STREET", "2  13TH NET: IRON CARTS",
                "3  2ND WORKS PORTER: TIN AND BRICK", "4  POWER HOUSE: GLASS, STAKES", "5  FIRST POWER: LIGHTS"]


def village():
    wx0, wx1, wy0, wy1 = 200, 1900, 840, 1700
    scale = 0.5
    pw, ph = int((wx1 - wx0) * scale), int((wy1 - wy0) * scale)
    img = sheet(2 * pw + 30, 3 * (ph + 22) + 20)
    for stage in range(6):
        panel = landing(stage, wx0, wx1, wy0, wy1, scale)
        x = 10 + (stage % 2) * (pw + 10)
        y = 20 + (stage // 2) * (ph + 22)
        blit(img, of(panel), x, y, 1)
        label(img, x, y - 12, "STAGE " + STAGE_TITLES[stage])
    path = os.path.join(SCRATCH, "d70_village.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


def street():
    wx0, wx1, wy0, wy1 = 560, 1500, 860, 1680
    pw, ph = wx1 - wx0, wy1 - wy0
    img = sheet(pw + 20, 2 * (ph + 20) + 20)
    for k, stage in enumerate((0, 5)):
        panel = landing(stage, wx0, wx1, wy0, wy1, 1)
        blit(img, of(panel), 10, 20 + k * (ph + 20), 1)
        label(img, 10, 8 + k * (ph + 20), "STAGE " + STAGE_TITLES[stage] + "  (1 IMAGE PX = 1 WORLD PX)")
    path = os.path.join(SCRATCH, "d70_street.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


# ---------------------------------------------------------------------------------------------
# curtea Wire Works

FIELD_PROPS = [("prop_substation", 4240, 1215), ("prop_cable_drums", 4040, 1300), ("prop_cable_drums", 4490, 1150)]


def works(with_props, wx0, wx1, wy0, wy1, scale):
    pl = places()
    G = pl["geometry"]
    img = C(int((wx1 - wx0) * scale), int((wy1 - wy0) * scale))
    img.rect(0, 0, img.w, img.h, (70, 110, 150, 255))
    tile = G["tile"]
    for k, name in enumerate(("prop_village_ground", "prop_village_ground_2")):
        blit(img, sprite(name), (k * tile - wx0) * scale, -wy0 * scale, 3 * scale)
    things = []

    def at(spr, x, base, art_scale):
        blit(img, spr, (x - wx0 - spr[0] / 2 * art_scale) * scale, (base - wy0 - spr[1] * art_scale) * scale,
             art_scale * scale)

    art = {"steam_engine": "prop_steam_engine", "power_house": "prop_power_house", "battery_shed": "prop_battery_shed",
           "works_bell": "prop_works_bell", "hire_works_collector": "prop_hut_works_collector_2",
           "hire_works_porter": "prop_hut_works_porter_2", "hire_wiredrawer": "prop_hut_wiredrawer_2",
           "hire_coil_hauler": "prop_hut_coil_hauler_2", "hire_battery_collector": "prop_hut_battery_collector_2",
           "hire_battery_porter": "prop_hut_battery_porter_2", "hire_electrician": "prop_hut_electrician_2",
           "hire_power_hauler": "prop_hut_power_hauler_2"}
    for key, name in (("WORKS_STORE", "prop_works_store"), ("WIRE_WORKS", "prop_wire_works"), ("DEPOT", "prop_depot")):
        box = pl["fixed"][key]
        things.append((box["y"], name, box["x"], box["y"], 3))
    for pad in G["pads"]:
        nm = art.get(pad["id"])
        if nm:
            things.append((pad["y"] + 56, nm, pad["x"], pad["y"] + 56, 3))
    if "hire_clerk" in [p["id"] for p in G["pads"]]:
        pad = [p for p in G["pads"] if p["id"] == "hire_clerk"][0]
        things.append((pad["y"] + 56, "prop_stall_clerk_2", pad["x"], pad["y"] + 56, 2))
    for lamp in pl["lamps"]:
        if lamp["era"] == 3:
            things.append((lamp["y"], "prop_street_lamp", lamp["x"], lamp["y"], 3))
    for item in G["scattered"]:
        nm = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}.get(item["kind"])
        if nm and wx0 - 100 < item["x"] < wx1 + 100:
            things.append((item["y"], nm, item["x"], item["y"], 3))
    if with_props:
        for nm, x, y in FIELD_PROPS:
            things.append((y, nm, x, y, 3))
    for _d, nm, x, y, sc in sorted(things, key=lambda t: t[0]):
        at(sprite(nm), x, y, sc)
    return img


def field():
    wx0, wx1, wy0, wy1 = 3560, 5240, 860, 1700
    scale = 0.5
    pw, ph = int((wx1 - wx0) * scale), int((wy1 - wy0) * scale)
    img = sheet(pw + 20, 2 * (ph + 22) + 20)
    for k, with_props in enumerate((False, True)):
        panel = works(with_props, wx0, wx1, wy0, wy1, scale)
        blit(img, of(panel), 10, 20 + k * (ph + 22), 1)
        label(img, 10, 8 + k * (ph + 22), "WIRE WORKS TODAY" if not with_props else
              "WITH THE OPTIONAL PROPS: SUBSTATION (4240, 1215), CABLE DRUMS (4040, 1300) AND (4490, 1150)")
    path = os.path.join(SCRATCH, "d70_field.png")
    write_png(path, img.w, img.h, img.px)
    print("scris", path, img.w, img.h)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    if which in ("stages", "all"):
        stage1()
        stage2()
        stage3()
        stage4()
        stage5()
    for name, fn in (("stage1", stage1), ("stage2", stage2), ("stage3", stage3), ("stage4", stage4),
                     ("stage5", stage5)):
        if which == name:
            fn()
    if which in ("village", "all"):
        village()
    if which in ("street", "all"):
        street()
    if which in ("field", "all"):
        field()
