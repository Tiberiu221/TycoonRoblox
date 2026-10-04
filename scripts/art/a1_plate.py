#!/usr/bin/env python3
"""[D75, lotul A1] PLANSA reperelor lumii 2, pentru aprobarea owner-ului. Scrie DOAR in scratchpad; nimic nu se urca.

Pune desenele lotului A1 (PNG-urile native scrise de scripts/art/a1_wall.py, a1_town.py, a1_pylons.py, a1_painted.py in
scratchpad-ul sesiunii) la locurile lor din TycoonConfig.WORLDS[2], pe pamantul copt al barajului, cu cladirile de imprumut
ale jocului unde arta lor (lotul A4) inca lipseste:

  a1_dam_plate.png  -- (1) zidul cu deversorul si spuma, clopotnita, Memory Wall si casutele din Dam Town;
                       (2) canalul, Relay Station, stalpii si oraselul pictat de pe malul de nord, stins si aprins;
                       (3) foaia desenelor la x4, cu cadrele animatiilor.

Rulare: python3 scripts/art/a1_plate.py [--src DIR]
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import preview_d55 as P  # noqa: E402
import village_ground as VG  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
D = 3
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"


def load(src, name):
    path = os.path.join(src, name + ".png")
    if not os.path.exists(path):
        path = os.path.join(SPR, name + ".png")
    return Image.open(path).convert("RGBA")


def frame(img, n, k):
    """Cadrul k dintr-o foaie cu n cadre pe orizontala."""
    w = img.width // n
    return img.crop((k * w, 0, (k + 1) * w, img.height))


def ground_image(G, lake=True):
    """Pamantul copt peste dala raului, cu tenta lacului (ca SceneArt)."""
    W, H = G["world"]["w"] // D, G["world"]["h"] // D
    water = Image.open(os.path.join(SPR, "water_tile.png")).convert("RGBA")
    img = Image.new("RGBA", (W, H))
    for y in range(0, H, water.height):
        for x in range(0, W, water.width):
            img.paste(water, (x, y))
    if lake:
        tint = Image.new("RGBA", (round(G["dam"]["wall"]["x"] / D), (848 - 368) // D), (40, 88, 120, 115))
        img.alpha_composite(tint, (0, 368 // D))
    rows = VG.bake(G).rows()
    ground = Image.new("RGBA", (W, H))
    ground.putdata([p for row in rows for p in row])
    img.alpha_composite(ground)
    return img


def compose(src, lit, turbine_art=True):
    G = VG.geometry(2)
    img = ground_image(G)
    dam = G["dam"]
    wall, sp = dam["wall"], dam["water"]["spillway"]
    # zidul si apa lui, pe grila zidului (SceneArt)
    wx, wy = round(wall["x"] / D), round(wall["y"] / D)
    sx = wx + round((sp["x"] - wall["x"]) / D)
    sy = wy + round((sp["y"] - wall["y"]) / D)
    img.alpha_composite(load(src, "prop_dam_wall"), (wx, wy))
    img.alpha_composite(frame(load(src, "prop_dam_spill"), 3, 0), (sx, sy))
    things = []  # (baza in lume, imagine, x mijloc in lume)

    def fitted(name, box, n=1):
        s = load(src, name)
        if n > 1:
            s = frame(s, n, 0)
        k = min(box["w"] / D / s.width, box["h"] / D / s.height)
        if abs(k - 1) > 0.02:
            s = s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))), Image.NEAREST)
        things.append((box["y"], s, box["x"]))

    b = dam["buildings"]
    fitted("prop_tavern", b["canteen"])
    fitted("prop_old_bells", b["bellTower"])
    fitted("prop_memory_wall", b["memoryWall"])
    for i, c in enumerate(dam["cottages"]):
        fitted(f"prop_dam_cottage_{i % 3 + 1}", c)
    for key, name in (
        ("damStore", "prop_works_store"),
        ("switchyard", "prop_wire_works"),
        ("cableStore", "prop_mill_store"),
        ("cableworks", "prop_foundry"),
        ("relay", "prop_copper_furnace"),
        ("switchHouse", "prop_depot"),
    ):
        fitted(name, b[key])
    for p in dam["pylons"]:
        art = {"river_pylon": "prop_pylon_tall", "lane_pylon": "prop_pylon_lane"}.get(p["name"], "prop_pylon_post")
        fitted(art, p)
    for p in G["pads"]:
        if p["net"]:
            continue
        name = VG.DAM_PAD_ART.get(p["id"])
        if name is None and p["id"].startswith("hire_"):
            name = "prop_runner_hut"
        if name is not None:
            s = load(src, name)
            things.append((p["y"] + 56, s, p["x"]))
    for item in G["scattered"]:
        name = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}.get(item["kind"])
        if name:
            things.append((item["y"], load(src, name), item["x"]))
    for base, s, x in sorted(things, key=lambda t: t[0]):
        img.alpha_composite(s, (round(x / D - s.width / 2), round(base / D - s.height)))
    # turbina zidita si spuma (stratul Plot), apoi oraselul pictat
    tb = dam["turbine"]
    foam = frame(load(src, "prop_dam_foam"), 2, 0)
    img.alpha_composite(foam, (wx + round(wall["w"] / D) - 2, sy))
    if turbine_art:
        # [verificatorul A1] ca NetController: mijlocul la (tb.x, tb.y); aici, la scara plansei (detaliul la rezolutia
        # jocului e in turbine_inset)
        turbine = load(src, "prop_turbine")
        k = min(tb["w"] / D / turbine.width, tb["h"] / D / turbine.height)
        turbine = turbine.resize((round(turbine.width * k), round(turbine.height * k)), Image.NEAREST)
        img.alpha_composite(turbine, (round(tb["x"] / D - turbine.width / 2), round(tb["y"] / D - turbine.height / 2)))
    town = {"x": 2202, "y": 405, "w": 1020, "h": 132}  # TycoonConfig.WORLDS[2].paintedTown
    tx, ty = round((town["x"] - town["w"] / 2) / D), round((town["y"] - town["h"]) / D)
    img.alpha_composite(load(src, "prop_painted_town"), (tx, ty))
    if lit:
        img.alpha_composite(load(src, "prop_painted_town_lit"), (tx, ty))
    return img


def turbine_inset(src, G, img_no_turbine):
    """[verificatorul A1] Gura turbinei la rezolutia jocului: piatra zidului are pixeli de 3 px de lume, iar turbina din
    zid (desenul de 48 px al turbinei Erei 3, TURBINE_SCALE 2, potrivit in cutia ei: 56 x 56) are pixeli de ~1,2 px. Asa
    o deseneaza NetController, cu mijlocul la (tb.x, tb.y)."""
    tb = G["dam"]["turbine"]
    x0, y0, x1, y1 = 760, 630, 960, 820
    part = img_no_turbine.crop((x0 // D, y0 // D, x1 // D, y1 // D))
    part = part.resize((part.width * D, part.height * D), Image.NEAREST)
    turbine = load(src, "prop_turbine")
    k = min(tb["w"] / turbine.width, tb["h"] / turbine.height)
    turbine = turbine.resize((round(turbine.width * k), round(turbine.height * k)), Image.NEAREST)
    part.alpha_composite(turbine, (round(tb["x"] - x0 - turbine.width / 2), round(tb["y"] - y0 - turbine.height / 2)))
    return part.resize((part.width * 3, part.height * 3), Image.NEAREST)


def crop(img, x0, y0, x1, y1, scale):
    c = img.crop((x0 // D, y0 // D, x1 // D, y1 // D))
    return c.resize((c.width * scale, c.height * scale), Image.NEAREST)


def main():
    src = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else os.path.join(P.SCRATCH, "a1")
    dark, lit = compose(src, False), compose(src, True)
    inset = turbine_inset(src, VG.geometry(2), compose(src, False, turbine_art=False))
    panels = [
        ("DAM TOWN AND THE WALL", "stone wall A, spillway, foam, Old Bells, Memory Wall, cottages", crop(dark, 120, 300, 1260, 1700, 2)),
        ("THE RELAY BANK, DARK", "canal, Relay (borrowed art), pylons; painted town before any power is sold", crop(dark, 1560, 240, 2860, 1480, 2)),
        ("THE RELAY BANK, LIT", "after the first power is sold at the Switch House (lights reveal left to right)", crop(lit, 1560, 240, 2860, 1480, 2)),
        ("THE TURBINE ARCH, GAME PIXELS (x3)", "the Era 3 turbine drawn in the wall as the game does: finer pixels than the stone", inset),
    ]
    sheet_names = [
        ("prop_dam_wall", 1), ("prop_dam_spill", 3), ("prop_dam_foam", 2), ("prop_old_bells", 1), ("prop_memory_wall", 1),
        ("prop_dam_cottage_1", 1), ("prop_dam_cottage_2", 1), ("prop_dam_cottage_3", 1), ("prop_pylon_tall", 1),
        ("prop_pylon_lane", 1), ("prop_pylon_post", 1), ("prop_river_crystal", 2),
    ]
    tiles = []
    for name, n in sheet_names:
        s = load(src, name)
        tiles.append((name.replace("prop_", ""), s.resize((s.width * 4, s.height * 4), Image.NEAREST)))
    gut, head = 24, 44
    width = max(p[2].width for p in panels) + 2 * gut
    sheet_w = width - 2 * gut
    # randuri pentru foaie
    rows, row, rw = [], [], 0
    for t in tiles:
        if rw + t[1].width + gut > sheet_w and row:
            rows.append(row)
            row, rw = [], 0
        row.append(t)
        rw += t[1].width + gut
    if row:
        rows.append(row)
    sheet_h = sum(max(t[1].height for t in r) + 30 for r in rows) + gut
    height = sum(p[2].height + head + gut for p in panels) + sheet_h + head + gut
    out = Image.new("RGBA", (width, height), (24, 28, 30, 255))
    dr = ImageDraw.Draw(out)
    title, note = ImageFont.truetype(FONT, 14), ImageFont.truetype(FONT, 8)
    y = gut
    for t, desc, im in panels:
        dr.text((gut, y), t, font=title, fill=(240, 233, 218))
        dr.text((gut, y + 20), desc, font=note, fill=(170, 164, 152))
        out.paste(im, (gut, y + head))
        y += im.height + head + gut
    dr.text((gut, y), "THE SPRITES (x4)", font=title, fill=(240, 233, 218))
    y += head
    for r in rows:
        x = gut
        rh = max(t[1].height for t in r)
        for name, im in r:
            out.paste(im, (x, y + rh - im.height), im)
            dr.text((x, y + rh + 8), name, font=note, fill=(170, 164, 152))
            x += im.width + gut
        y += rh + 30
    path = os.path.join(P.SCRATCH, "a1_dam_plate.png")
    out.save(path)
    print("scris", path, out.size)


if __name__ == "__main__":
    main()
