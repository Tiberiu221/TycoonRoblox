#!/usr/bin/env python3
"""[D75, lotul A2] PLANSA FILMULUI BARAJULUI, pentru aprobarea owner-ului. Scrie DOAR in scratchpad; nimic nu se urca.

Cadrele vin din codul jocului, exportat cu Lune: cronologia (DamMath.frameAt: benzile, amurgul, textul, Skip, camera care
trece pe strada si urca la rau, zidul care creste) si decorul (DamFilmSet: zidul pe linia barajului, jumatatile, siluetele,
oamenii de pe zid, macaraua, caruta, gramada, Works Bell, plasele care ies din apa). Peste satul de la sfarsitul Erei 3
(scripts/art/a0_dam.py village_image) se pun desenele lotului A2 (scripts/art/a2_build.py, a2_people.py, in scratchpad/a2)
si zidul lotului A1 (scratchpad/a1/prop_dam_wall.png).

  a2_dam_film.png -- sase cadre: clopotul, oamenii pleaca, oamenii la rau, zidul la jumatate, zidul inchis, cartonasul;
                     dedesubt foaia desenelor la x4 si sunetele (durata, varful).

Rulare: python3 scripts/art/a2_plate.py [--src DIR]
"""
import json
import math
import os
import subprocess
import sys
import wave

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import a0_dam as A0  # noqa: E402
import preview_d55 as P  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
D = 3
FONT = A0.FONT
DUSK = (70, 34, 52)

EXPORT = """
local serde = require("@lune/serde")
local T = require("../../src/Shared/Config/TycoonConfig")
local DamMath = require("../../src/Shared/Modules/DamMath")
local Set = require("../../src/Shared/Modules/DamFilmSet")
local districts = T.districtsOf(1)
local first, last = districts[1].deck, districts[#districts].deck
local bell = Set.bell()
local eastX = if bell ~= nil then bell.x else (last.x0 + last.x1) / 2
local westX = (first.x0 + first.x1) / 2
local riverX, riverY = Set.camera(810)
local peopleFrom = DamMath.FILM[3].from
local x0, x1 = Set.liftRange()
local out = { wall = Set.wall(), props = Set.props(), bell = Set.bell(), lift = { x0 = x0, x1 = x1 }, frames = {} }
local walkers = Set.walkers()
for _, t in { 1, 8.2, 10.6, 12.2, 13.7, 15 } do
    local f = DamMath.frameAt(t, false)
    local startY = Set.bellMidY() or 1100
    local x, y = eastX + (westX - eastX) * f.pan, startY + (1100 - startY) * f.pan
    local n, s = Set.halves(f.built)
    local people = {}
    if t >= peopleFrom then
        for i, w in walkers do
            local px, py, moving, facing = Set.walkerAt(w, t - peopleFrom)
            local step = if moving then math.floor((t + i * 0.13) * Set.WALK_FPS) % 4 else 0
            table.insert(people, { x = px, y = py, row = w.kind, frame = step, facing = facing })
        end
    end
    table.insert(out.frames, { t = t, phase = f.phase, text = f.text, bars = f.bars, skip = f.skip,
        dusk = if f.phase == "people" then f.progress elseif f.phase == "bells" or f.phase == "look" then 0 else 1,
        rise = f.rise, built = f.built, north = n, south = s, people = people, workers = Set.workers(f.built),
        bellFrame = Set.bellFrame(t), camX = x + (riverX - x) * f.rise, camY = y + (riverY - y) * f.rise })
end
print(serde.encode("json", out))
"""


def export():
    tmp = os.path.join(ROOT, "scripts", "_tmp_a2")
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "film.luau")
    with open(path, "w") as f:
        f.write(EXPORT)
    try:
        res = subprocess.run(["lune", "run", path], cwd=ROOT, capture_output=True, text=True)
        if res.returncode != 0:
            sys.exit("exportul filmului a picat:\n" + res.stderr)
        return json.loads(res.stdout)
    finally:
        os.remove(path)
        os.rmdir(tmp)


def load(src, name):
    for folder in (src, os.path.join(src, "..", "a1"), os.path.join(ROOT, "assets", "sprites")):
        path = os.path.join(folder, name + ".png")
        if os.path.exists(path):
            return Image.open(path).convert("RGBA")
    return None


def cell(sheet, n, k):
    w = sheet.width // n
    return sheet.crop((k * w, 0, (k + 1) * w, sheet.height))


def person(sheet, row, frame, facing):
    """Cadrul unui om (16 x 24) la scara jocului (x2,5 in lume = 2,5/3 pixeli de plansa), oglindit spre stanga."""
    c = sheet.crop((frame * 16, row * 24, frame * 16 + 16, row * 24 + 24))
    if facing == "left":
        c = c.transpose(Image.FLIP_LEFT_RIGHT)
    return c.resize((round(16 * 2.5 / D), round(24 * 2.5 / D)), Image.NEAREST)


def paste_base(img, s, x, y):
    """Ancorat jos-mijloc, in coordonatele lumii."""
    img.alpha_composite(s, (round(x / D - s.width / 2), round(y / D - s.height)))


def frame_image(src, data, f, village_lifted, village):
    """Un cadru ca in joc: zidul, schela, recuzita si clopotul in lume, sub amurg; oamenii (siluetele si cei de pe zid) peste
    amurg, ca stratul lor din DamFilm (deps.Scroll), cu foile spre stanga cand exista."""
    base = village_lifted if f["phase"] in ("build", "card") else village
    world = base.copy()
    wall = data["wall"]
    at_river = f["phase"] in ("build", "card")
    building = f["phase"] == "build"
    north_front, south_front = wall["top"] + f["north"], wall["bottom"] - f["south"]
    gap = south_front - north_front
    if at_river:
        art = load(src, "prop_film_wall") or load(src, "prop_dam_wall")
        if art is not None:
            n, s = round(f["north"] / D), round(f["south"] / D)
            if n > 0:
                world.alpha_composite(art.crop((0, 0, art.width, n)), (wall["x0"] // D, wall["top"] // D))
            if s > 0:
                world.alpha_composite(art.crop((0, art.height - s, art.width, art.height)), (wall["x0"] // D, south_front // D))
    if building and gap > 0:
        scaffold = load(src, "prop_film_scaffold")
        if scaffold is not None:
            for y in range(north_front // D, south_front // D, scaffold.height):
                piece = scaffold.crop((0, 0, scaffold.width, min(scaffold.height, south_front // D - y)))
                world.alpha_composite(piece, (wall["x0"] // D, y))
        e = load(src, "prop_film_wall_edge_n")
        if e is not None and gap >= e.height * D:
            paste_base(world, e, (wall["x0"] + wall["x1"]) / 2, north_front + e.height * D)
        e = load(src, "prop_film_wall_edge_s")
        if e is not None:
            paste_base(world, e, (wall["x0"] + wall["x1"]) / 2, south_front)
        dust = load(src, "prop_film_dust")
        if dust is not None:
            for i, (dx, dy) in enumerate(((wall["x0"] + 100, north_front + 15), (wall["x0"] + 150, south_front))):
                paste_base(world, cell(dust, 3, (int(f["t"] / 0.12) + i + 1) % 3), dx, dy)
    if at_river:
        props = data["props"]
        crane = load(src, "prop_film_crane")
        if crane is not None:
            paste_base(world, cell(crane, 2, int(f["t"] / 0.9) % 2), props["crane"]["x"], props["crane"]["y"])
        for name, key in (("prop_film_stone_cart", "cart"), ("prop_film_stone_pile", "pile")):
            s = load(src, name)
            if s is not None:
                paste_base(world, s, props[key]["x"], props[key]["y"])
    if f["phase"] == "bells":
        bell = load(src, "prop_film_works_bell_swing")
        if bell is not None and data["bell"] is not None:
            paste_base(world, cell(bell, 3, f["bellFrame"]), data["bell"]["x"], data["bell"]["y"])
    img, (ox, oy) = A0.frame_view(world, f["camX"], f["camY"])
    if f["dusk"] > 0:
        img = A0.tint(img, DUSK, 0.45 * min(1, f["dusk"]))
    # oamenii, peste amurg (adancimea dupa talpi)
    people = []
    walkers, walkers_l = load(src, "prop_film_walkers"), load(src, "prop_film_walkers_l")
    if walkers is not None:
        for p in f["people"]:
            people.append((p["y"], walkers, walkers_l, p["row"], p["frame"], p["facing"], p["x"]))
    workers, workers_l = load(src, "prop_film_workers"), load(src, "prop_film_workers_l")
    if workers is not None and at_river:
        for i, wk in enumerate(f["workers"]):
            people.append((wk["y"], workers, workers_l, wk["kind"], int((f["t"] + (i + 1) * 0.21) * 7) % 4, wk["facing"], wk["x"]))
    for y, right, left, row, frame, facing, x in sorted(people, key=lambda q: q[0]):
        if facing == "left" and left is not None:
            fig = person(left, row, frame, "right")
        else:
            fig = person(right, row, frame, facing)
        img.alpha_composite(fig, (round(x / D - ox - fig.width / 2), round(y / D - oy - fig.height)))
    bar = round(img.height * 0.12 * f["bars"])
    A0.letterbox(img, f["bars"])
    if f.get("text") and f["phase"] != "card":
        A0.caption(img, f["text"], bar)
    if f["skip"]:
        A0.skip(img, bar)
    return img


def card(size):
    img = Image.new("RGBA", size, (0, 0, 0, 255))
    dr = ImageDraw.Draw(img)
    big, small = ImageFont.truetype(FONT, 24), ImageFont.truetype(FONT, 8)
    for text, font, y, col in (
        ("THE DAM", big, size[1] * 0.40, (240, 233, 218)),
        ("Your people built this", small, size[1] * 0.58, (196, 186, 168)),
    ):
        tw = dr.textlength(text, font=font)
        dr.text((round(size[0] / 2 - tw / 2), round(y)), text, font=font, fill=col + (255,))
    A0.skip(img, round(size[1] * 0.12))
    return img


def sound_lines(src):
    out = []
    for name in ("music_dam_film", "sfx_film_build", "sfx_film_close"):
        path = os.path.join(src, name + ".wav")
        if not os.path.exists(path):
            out.append(f"{name}: lipseste")
            continue
        with wave.open(path) as w:
            frames, rate, ch, width = w.getnframes(), w.getframerate(), w.getnchannels(), w.getsampwidth()
            raw = w.readframes(frames)
        import array

        a = array.array("h" if width == 2 else "i", raw)
        peak = max(1, max(abs(v) for v in a))
        full = 32768 if width == 2 else 2147483648
        out.append(f"{name}: {frames / rate:.1f} s, {'stereo' if ch == 2 else 'mono'}, peak {20 * math.log10(peak / full):.1f} dBFS")
    return out


def main():
    src = sys.argv[sys.argv.index("--src") + 1] if "--src" in sys.argv else os.path.join(P.SCRATCH, "a2")
    data = export()
    _, village = A0.village_image()
    # plasele de pe linia zidului ies din apa la „build” (NetController.SetFilmLift)
    props = A0.film_props()
    for net in props["nets"]:
        net["hidden"] = data["lift"]["x0"] <= net["x"] <= data["lift"]["x1"]
    _, lifted = A0.village_image()
    for net in props["nets"]:
        net["hidden"] = False
    labels = {
        1: ("0:01  BELLS", "the Works Bell swings while the bell rings"),
        8.2: ("0:08  PEOPLE", "dusk falls; the village walks to the river with beams, stones, lanterns"),
        10.6: ("0:10  PEOPLE", "they reach the Landing deck, in front of the wall line"),
        12.2: ("0:12  BUILD", "the camera rises to the river; the nets come out; scaffold, crane, the wall grows"),
        13.7: ("0:13  BUILD", "the two halves meet (the closing sound)"),
        15: ("0:15  CARD", "black card, then the reload into the Dam map"),
    }
    frames = []
    for f in data["frames"]:
        img = frame_image(src, data, f, lifted, village) if f["phase"] != "card" else None
        frames.append((f, img))
    size = next(img.size for _, img in frames if img is not None)
    frames = [(f, img if img is not None else card(size)) for f, img in frames]

    scale, gut, head = 2, 24, 44
    fw, fh = size[0] * scale, size[1] * scale
    cols = 2
    rows_n = math.ceil(len(frames) / cols)
    names = [
        ("prop_film_wall", 1), ("prop_film_scaffold", 1), ("prop_film_wall_edge_n", 1), ("prop_film_wall_edge_s", 1),
        ("prop_film_crane", 2), ("prop_film_walkers_l", 1), ("prop_film_workers_l", 1),
        ("prop_film_stone_cart", 1), ("prop_film_stone_pile", 1), ("prop_film_dust", 3), ("prop_film_walkers", 1),
        ("prop_film_workers", 1), ("prop_film_works_bell_swing", 3),
    ]
    tiles = []
    for name, _n in names:
        s = load(src, name)
        if s is not None:
            tiles.append((name.replace("prop_film_", ""), s.resize((s.width * 4, s.height * 4), Image.NEAREST)))
    width = cols * fw + (cols + 1) * gut
    rows, row, rw = [], [], 0
    for t in tiles:
        if rw + t[1].width + gut > width - 2 * gut and row:
            rows.append(row)
            row, rw = [], 0
        row.append(t)
        rw += t[1].width + gut
    if row:
        rows.append(row)
    sounds = sound_lines(src)
    sheet_h = head + sum(max(t[1].height for t in r) + 30 for r in rows) + head + len(sounds) * 16 + gut
    out = Image.new("RGBA", (width, rows_n * (fh + head) + (rows_n + 1) * gut + sheet_h), (24, 28, 30, 255))
    dr = ImageDraw.Draw(out)
    title, note = ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 8)
    for i, (f, img) in enumerate(frames):
        c, r = i % cols, i // cols
        x, y = gut + c * (fw + gut), gut + r * (fh + head + gut)
        label, desc = labels.get(f["t"], (f"{f['t']}", ""))
        dr.text((x, y), label, font=title, fill=(240, 233, 218))
        dr.text((x, y + 20), desc, font=note, fill=(170, 164, 152))
        out.paste(img.resize((fw, fh), Image.NEAREST), (x, y + head))
    y = rows_n * (fh + head) + (rows_n + 1) * gut
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
    dr.text((gut, y), "THE SOUNDS", font=title, fill=(240, 233, 218))
    y += 24
    for line in sounds:
        dr.text((gut, y), line, font=note, fill=(170, 164, 152))
        y += 16
    path = os.path.join(P.SCRATCH, "a2_dam_film.png")
    out.save(path)
    print("scris", path, out.size)


if __name__ == "__main__":
    main()
