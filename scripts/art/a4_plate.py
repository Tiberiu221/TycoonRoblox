#!/usr/bin/env python3
"""[D75, lotul A4] PLANSA cladirilor, caselor, marfii si tinutelor barajului, pentru aprobarea owner-ului. Scrie DOAR in
scratchpad; nimic nu se urca.

Desenele vin din generatoarele lotului (scripts/art/a4_works.py, a4_halls.py, a4_goods.py, a4_huts_power.py, a4_huts_cable.py,
a4_outfits.py, in scratchpad/a4), reperele din lotul A1 (scratchpad/a1), restul din assets/sprites. Locurile vin din jocul
adevarat (scripts/art/village_geometry.luau prin village_ground.geometry(2)).

  a4_dam_plate.png -- (1) harta barajului cu cladirile si casele noi la locul lor (primul om); (2) aceeasi harta cu al doilea
                      om pe fiecare meserie; (3) foile: cladirile, casele, marfa (pictograma, caruciorul, gramada), tinutele
                      (stand si mers), fiecare langa desenul de imprumut pe care il inlocuieste.

Rulare: python3 scripts/art/a4_plate.py
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import a1_plate as A1P  # noqa: E402
import preview_d55 as P  # noqa: E402
import village_ground as VG  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
D = 3
FONT = A1P.FONT
A4 = os.path.join(P.SCRATCH, "a4")
A1 = os.path.join(P.SCRATCH, "a1")

BUILDING_ART = {  # TycoonConfig.WORLDS[2].buildings -> desenul propriu (Bootstrap WORLD_BUILDING_ART, DamTownController.OWN)
    "damStore": ("prop_dam_store", "prop_works_store"),
    "switchyard": ("prop_switchyard", "prop_wire_works"),
    "cableStore": ("prop_cable_store", "prop_mill_store"),
    "cableworks": ("prop_cable_works", "prop_foundry"),
    "relay": ("prop_relay_station", "prop_copper_furnace"),
    "switchHouse": ("prop_switch_house", "prop_depot"),
    "canteen": ("prop_canteen", "prop_tavern"),
    "bellTower": ("prop_old_bells", "prop_bell"),
    "memoryWall": ("prop_memory_wall", "prop_board_old"),
}
PAD_ART = {"crystal_shed": "prop_crystal_shed", "crystal_kiln": "prop_crystal_kiln", "dam_bell": "prop_dam_bell"}
STALLS = {"hire_dispatcher"}  # x2, ca taraba Clerk-ului (PadArt.HOME_SCALE)


def load(name):
    for folder in (A4, A1, SPR):
        path = os.path.join(folder, name + ".png")
        if os.path.exists(path):
            return Image.open(path).convert("RGBA")
    return None


def hut_name(pad_id, second):
    role = pad_id[len("hire_"):]
    if pad_id in STALLS:
        return "prop_stall_" + role + ("_2" if second else "")
    return f"prop_hut_{role}_{2 if second else 1}"


def compose(second):
    """Pamantul copt al barajului, cu cladirile, casele (primul om sau al doilea), reperele A1 si turbina din zid."""
    G = VG.geometry(2)
    img = A1P.ground_image(G)
    dam = G["dam"]
    wall, sp = dam["wall"], dam["water"]["spillway"]
    wx, wy = round(wall["x"] / D), round(wall["y"] / D)
    img.alpha_composite(load("prop_dam_wall"), (wx, wy))
    img.alpha_composite(A1P.frame(load("prop_dam_spill"), 3, 0), (wx + round((sp["x"] - wall["x"]) / D), wy + round((sp["y"] - wall["y"]) / D)))
    things = []

    def fitted(s, box, base=None):
        k = min(box["w"] / D / s.width, box["h"] / D / s.height)
        if abs(k - 1) > 0.02:
            s = s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))), Image.NEAREST)
        things.append((base if base is not None else box["y"], s, box["x"]))

    for key, (own, borrowed) in BUILDING_ART.items():
        box = dam["buildings"].get(key)
        if box is not None:
            fitted(load(own) or load(borrowed), box)
    for i, c in enumerate(dam["cottages"]):
        fitted(load(f"prop_dam_cottage_{i % 3 + 1}"), c)
    for p in dam["pylons"]:
        art = {"river_pylon": "prop_pylon_tall", "lane_pylon": "prop_pylon_lane"}.get(p["name"], "prop_pylon_post")
        fitted(load(art), p)
    for p in G["pads"]:
        if p["net"]:
            continue
        base = p["y"] + 56  # TycoonConfig.buildingBase
        name = PAD_ART.get(p["id"])
        scale = 1.0
        if name is None and p["id"].startswith("hire_"):
            name = hut_name(p["id"], second)
            if p["id"] in STALLS:
                scale = 2 / D
        s = load(name) if name else None
        if s is None:
            continue
        if scale != 1.0:
            s = s.resize((round(s.width * scale), round(s.height * scale)), Image.NEAREST)
        things.append((base, s, p["x"]))
    for item in G["scattered"]:
        name = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}.get(item["kind"])
        if name:
            things.append((item["y"], load(name), item["x"]))
    for base, s, x in sorted(things, key=lambda t: t[0]):
        img.alpha_composite(s, (round(x / D - s.width / 2), round(base / D - s.height)))
    tb = dam["turbine"]
    face = load("prop_dam_turbine")
    if face is not None:
        img.alpha_composite(face, (round(tb["x"] / D - face.width / 2), round(tb["y"] / D - face.height / 2)))
    town = {"x": 2202, "y": 405, "w": 1020, "h": 132}
    img.alpha_composite(load("prop_painted_town"), (round((town["x"] - town["w"] / 2) / D), round((town["y"] - town["h"]) / D)))
    return img


def crop(img, x0, y0, x1, y1, scale):
    c = img.crop((x0 // D, y0 // D, x1 // D, y1 // D))
    return c.resize((c.width * scale, c.height * scale), Image.NEAREST)


def pair_tiles(names_pairs, scale=4):
    """(nume, desenul nou, desenul de imprumut) -> placi x`scale`, noul langa vechi."""
    tiles = []
    for label, new, old in names_pairs:
        a, b = load(new), load(old) if old else None
        if a is None:
            continue
        w = a.width * scale + (b.width * scale + 6 if b is not None else 0)
        h = max(a.height, b.height if b is not None else 0) * scale
        t = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        t.alpha_composite(a.resize((a.width * scale, a.height * scale), Image.NEAREST), (0, h - a.height * scale))
        if b is not None:
            bb = b.resize((b.width * scale, b.height * scale), Image.NEAREST)
            bb.putalpha(bb.getchannel("A").point(lambda v: v * 55 // 100))
            t.alpha_composite(bb, (a.width * scale + 6, h - bb.height))
        tiles.append((label, t))
    return tiles


def outfit_tiles(names, scale=4):
    """Fiecare tinuta: stand (idle_down, randul 3) si mers (walk_side, randul 2), peste corpul a si parul short."""
    body, hair = load("body_a"), load("hair_short")
    tiles = []
    for name in names:
        sheet = load("outfit_" + name.lower())
        if sheet is None:
            continue
        t = Image.new("RGBA", (16 * 2 + 4, 24), (0, 0, 0, 0))
        for k, (row, frame) in enumerate(((3, 0), (2, 1))):
            cell = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
            for layer in (body, sheet, hair):
                if layer is not None:
                    cell.alpha_composite(layer.crop((frame * 16, row * 24, frame * 16 + 16, row * 24 + 24)))
            t.alpha_composite(cell, (k * 20, 0))
        tiles.append((name, t.resize((t.width * scale, t.height * scale), Image.NEAREST)))
    return tiles


def main():
    first, second = compose(False), compose(True)
    W = 1100
    panels = [
        ("THE DAM, FIRST HIRES", "A4 buildings and huts at their places (crop x 200-3300, y 840-1700)", crop(first, 200, 840, 3300, 1700, 1)),
        ("THE DAM, SECOND HIRES", "the huts grow with the second hire", crop(second, 200, 840, 3300, 1700, 1)),
        ("THE RELAY BANK", "Switch House, Relay Station, Kiln, Crystal Shed, Dam Bell (x2)", crop(first, 1850, 860, 3150, 1480, 2)),
        ("DAM TOWN", "the canteen among the A1 landmarks and cottages (x2)", crop(first, 150, 860, 1000, 1700, 2)),
    ]
    huts = ["dam_collector", "dam_porter", "switchman", "barrel_hauler", "relay_keeper", "pylon_runner", "cable_collector",
            "cable_porter", "cablemaker", "cable_hauler", "crystal_collector", "crystal_porter", "crystalsmith", "ingot_hauler"]
    borrowed_hut = {"dam_collector": "battery_collector", "dam_porter": "battery_porter", "switchman": "electrician",
                    "barrel_hauler": "power_hauler", "relay_keeper": "founder", "pylon_runner": "parts_hauler",
                    "cable_collector": "works_collector", "cable_porter": "works_porter", "cablemaker": "wiredrawer",
                    "cable_hauler": "coil_hauler", "crystal_collector": "ore_collector", "crystal_porter": "ore_porter",
                    "crystalsmith": "coppersmith", "ingot_hauler": "copper_hauler"}
    sections = [
        ("BUILDINGS (x4, borrowed art faded on the right)", pair_tiles(
            [(k, own, old) for k, (own, old) in BUILDING_ART.items() if k not in ("bellTower", "memoryWall")]
            + [("crystal_shed", "prop_crystal_shed", "prop_battery_shed"), ("crystal_kiln", "prop_crystal_kiln", "prop_power_house"),
               ("dam_bell", "prop_dam_bell", "prop_works_bell")])),
        ("HUTS (x4: first hire, second hire, borrowed)", pair_tiles(
            [(h, f"prop_hut_{h}_1", f"prop_hut_{borrowed_hut[h]}_1") for h in huts]
            + [(h + " 2", f"prop_hut_{h}_2", f"prop_hut_{borrowed_hut[h]}_2") for h in huts]
            + [("dispatcher", "prop_stall_dispatcher", "prop_stall_clerk"), ("dispatcher 2", "prop_stall_dispatcher_2", "prop_stall_clerk_2")])),
        ("GOODS (x4: icon, barrow load, pile; borrowed faded)", pair_tiles(
            [(g, f"goods_{g}", f"goods_{o}") for g, o in (("barrel", "cell"), ("cable", "coils"), ("grid", "copper"), ("crystal", "parts"), ("ingot", "iron"))]
            + [(g + " load", f"prop_load_{g}", None) for g in ("barrel", "cable", "grid", "crystal", "ingot")]
            + [(g + " pile", f"prop_pile_{g}", None) for g in ("barrel", "cable", "grid", "crystal", "ingot")])),
        ("OUTFITS (x4: standing, walking)", outfit_tiles(
            ["Turbineer", "Lugger", "Switchman", "Cooper", "Dispatcher", "Spooler", "Packer", "Cablemaker", "Reeler", "Relayman",
             "Linewalker", "Gemfinder", "Bearer", "Crystalsmith", "Bullioner"])),
    ]
    gut, head = 24, 44
    width = max(W, max(p[2].width for p in panels)) + 2 * gut
    inner = width - 2 * gut
    laid = []
    for title, tiles in sections:
        rows, row, rw = [], [], 0
        for t in tiles:
            if rw + t[1].width + gut > inner and row:
                rows.append(row)
                row, rw = [], 0
            row.append(t)
            rw += t[1].width + gut
        if row:
            rows.append(row)
        laid.append((title, rows))
    height = sum(p[2].height + head + gut for p in panels) + gut
    for _title, rows in laid:
        height += head + sum(max(t[1].height for t in r) + 30 for r in rows) + gut
    out = Image.new("RGBA", (width, height), (24, 28, 30, 255))
    dr = ImageDraw.Draw(out)
    title_f, note_f = ImageFont.truetype(FONT, 14), ImageFont.truetype(FONT, 8)
    y = gut
    for t, desc, im in panels:
        dr.text((gut, y), t, font=title_f, fill=(240, 233, 218))
        dr.text((gut, y + 20), desc, font=note_f, fill=(170, 164, 152))
        out.paste(im, (gut, y + head))
        y += im.height + head + gut
    for title, rows in laid:
        dr.text((gut, y), title, font=title_f, fill=(240, 233, 218))
        y += head
        for r in rows:
            x = gut
            rh = max(t[1].height for t in r)
            for name, im in r:
                out.paste(im, (x, y + rh - im.height), im)
                dr.text((x, y + rh + 8), name, font=note_f, fill=(170, 164, 152))
                x += im.width + gut
            y += rh + 30
        y += gut
    path = os.path.join(P.SCRATCH, "a4_dam_plate.png")
    out.save(path)
    print("scris", path, out.size)


if __name__ == "__main__":
    main()
