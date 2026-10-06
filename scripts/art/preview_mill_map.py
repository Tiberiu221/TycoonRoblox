#!/usr/bin/env python3
"""Moara, asa cum ar trebui sa arate in joc cu arta ei [D65]: pamantul copt (cele doua felii), cladirile si casele la
locurile din TycoonConfig, copacii imprastiati. Scrie DOAR in folderul de lucru (scripts/art/scratch.py).

Nu e jocul: fara oameni, fara gramezi, fara HUD, iar casele sunt cele MARI (doi oameni). E o proba de ASEZARE, facuta
din aceleasi cifre ca jocul (scripts/art/village_geometry.luau + un mic export Lune al locurilor Morii): roata de apa
sta in rau sau pe scanduri? un copac acopera un nume? cladirea incape in curtea ei?

Rulare: python3 scripts/art/preview_mill_map.py [scara]      (scara 1 = 1 pixel de imagine la 3 de lume; implicit 2)
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C  # noqa: E402
import preview_d55 as P  # noqa: E402
from preview_tycoon import load, write_png  # noqa: E402
from village_ground import geometry  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
D = 3  # pixeli de lume pe pixel de arta (Assets.PIXEL_SCALE)

# platforma -> (sprite, scara in pixeli de lume pe pixel de arta)
PAD_ART = {
    "water_wheel": ("prop_water_wheel", 3),
    "copper_furnace": ("prop_copper_furnace", 3),
    "ore_shed": ("prop_ore_shed", 3),
    "mill_bell": ("prop_mill_bell", 3),
    "hire_mill_collector": ("prop_hut_mill_collector_2", 3),
    "hire_mill_porter": ("prop_hut_mill_porter_2", 3),
    "hire_founder": ("prop_hut_founder_2", 3),
    "hire_parts_hauler": ("prop_hut_parts_hauler_2", 3),
    "hire_merchant": ("prop_stall_merchant_2", 2),
    "hire_ore_collector": ("prop_hut_ore_collector_2", 3),
    "hire_ore_porter": ("prop_hut_ore_porter_2", 3),
    "hire_coppersmith": ("prop_hut_coppersmith_2", 3),
    "hire_copper_hauler": ("prop_hut_copper_hauler_2", 3),
}
ART_OFFSET_Y = {"water_wheel": -92}  # PadArt.ART_OFFSET: baza la DECK.y0 + 4 (776), fata de baza cladirii (868)
BUILDING_BASE = 48 + 8  # TycoonConfig.buildingBase: y + PAD_SIZE/2 + BUILDING_DROP
FIXED = {"MILL_STORE": "prop_mill_store", "FOUNDRY": "prop_foundry", "MARKET": "prop_market"}
DECOR = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}

EXPORT = """
local serde = require("@lune/serde")
local T = require("../../src/Shared/Config/TycoonConfig")
local out = { fixed = {}, names = {} }
for _, key in { "MILL_STORE", "FOUNDRY", "MARKET" } do
    out.fixed[key] = T[key]
end
for _, p in T.PADS do
    if p.era == 2 then
        local role = T.CREW_OF_PAD[p.id]
        out.names[p.id] = if role ~= nil then T.CREWS[role].name else p.name
    end
end
print(serde.encode("json", out))
"""


def mill_places():
    tmp = os.path.join(ROOT, "scripts", "_tmp")
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "mill_places.luau")
    with open(path, "w") as f:
        f.write(EXPORT)
    try:
        res = subprocess.run(["lune", "run", path], cwd=ROOT, capture_output=True, text=True)
        if res.returncode != 0:
            sys.exit("exportul locurilor Morii a picat:\n" + res.stderr)
        return json.loads(res.stdout)
    finally:
        os.remove(path)
        os.rmdir(tmp)


def main():
    out_scale = int(sys.argv[1]) if len(sys.argv) > 1 else 2
    G = geometry()
    places = mill_places()
    # fereastra de lume: cartierul Morii, de la rau pana sub randul de case
    wx0, wx1, wy0, wy1 = 1860, 3700, 600, 1880
    w, h = (wx1 - wx0) // D, (wy1 - wy0) // D
    img = C(w * out_scale, h * out_scale)
    img.rect(0, 0, img.w, img.h, (70, 110, 150, 255))  # apa, sub pamantul cu alfa

    def blit(px, pw, ph, world_x, world_y_bottom, art_scale):
        """Deseneaza un sprite prins de baza (mijloc-jos) la un punct din lume."""
        k = art_scale / D * out_scale  # pixeli de imagine pe pixel de arta
        x0 = (world_x - wx0) / D * out_scale - pw * k / 2
        y0 = (world_y_bottom - wy0) / D * out_scale - ph * k
        for yy in range(ph):
            for xx in range(pw):
                p = px[yy][xx]
                if p[3]:
                    img.rect(round(x0 + xx * k), round(y0 + yy * k), max(1, round(k)), max(1, round(k)), p)

    # pamantul copt, din cele doua felii
    tile = G["tile"] // D
    for k, name in enumerate(("prop_village_ground", "prop_village_ground_2")):
        tw, th, px = load(name)
        for yy in range(th):
            wy = yy * D
            if not (wy0 <= wy < wy1):
                continue
            for xx in range(tw):
                wx = (k * tile + xx) * D
                if wx0 <= wx < wx1 and px[yy][xx][3]:
                    img.rect((wx - wx0) // D * out_scale, (wy - wy0) // D * out_scale, out_scale, out_scale, px[yy][xx])

    # tot ce sta pe pamant, sortat pe adancime (baza mai jos = peste)
    things = []
    for key, sprite in FIXED.items():
        box = places["fixed"][key]
        things.append((box["y"], sprite, box["x"], box["y"], 3, key.replace("_", " ").title()))
    for pad in G["pads"]:
        art = PAD_ART.get(pad["id"])
        if art is not None:
            base = pad["y"] + BUILDING_BASE + ART_OFFSET_Y.get(pad["id"], 0)
            things.append((pad["y"], art[0], pad["x"], base, art[1], places["names"].get(pad["id"], "")))
    for item in G["scattered"]:
        sprite = DECOR.get(item["kind"])
        if sprite is not None and wx0 - 100 < item["x"] < wx1 + 100:
            things.append((item["y"], sprite, item["x"], item["y"], 3, None))
    labels = []
    for _depth, sprite, x, base, scale, name in sorted(things, key=lambda t: t[0]):
        pw, ph, px = load(sprite)
        blit(px, pw, ph, x, base, scale)
        if name:
            labels.append((name, x, base))
    # numele, ca in joc: sub casa (sau pe cladire); desenate la urma doar ca sa se poata citi in proba -- in joc un
    # copac din fata le-ar acoperi, deci testul WorldDecor e cel care pazeste asta, nu imaginea de aici
    for name, x, base in labels:
        tx = (x - wx0) / D * out_scale - len(name) * 3
        ty = (base - wy0) / D * out_scale + 3
        P.draw_text(img, int(tx), int(ty), name.upper(), P.INK, 1)

    path = os.path.join(P.SCRATCH, "d65_mill_map.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


if __name__ == "__main__":
    main()
