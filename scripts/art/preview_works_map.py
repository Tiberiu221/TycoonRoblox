#!/usr/bin/env python3
"""[D67] Wire Works, asa cum ar trebui sa arate in joc cu arta ei (dupa preview_mill_map.py [D65]): pamantul copt (cele doua felii), cladirile si casele la
locurile din TycoonConfig, copacii imprastiati. Scrie DOAR in scratchpad-ul sesiunii.

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
    "steam_engine": ("prop_steam_engine", 3),
    "power_house": ("prop_power_house", 3),
    "battery_shed": ("prop_battery_shed", 3),
    "works_bell": ("prop_works_bell", 3),
    "hire_works_collector": ("prop_hut_works_collector_2", 3),
    "hire_works_porter": ("prop_hut_works_porter_2", 3),
    "hire_wiredrawer": ("prop_hut_wiredrawer_2", 3),
    "hire_coil_hauler": ("prop_hut_coil_hauler_2", 3),
    "hire_clerk": ("prop_stall_clerk_2", 2),
    "hire_battery_collector": ("prop_hut_battery_collector_2", 3),
    "hire_battery_porter": ("prop_hut_battery_porter_2", 3),
    "hire_electrician": ("prop_hut_electrician_2", 3),
    "hire_power_hauler": ("prop_hut_power_hauler_2", 3),
}
ART_OFFSET_Y = {}  # nimic in rau (turbina o deseneaza NetController, in larg)
FIXED = {"WORKS_STORE": "prop_works_store", "WIRE_WORKS": "prop_wire_works", "DEPOT": "prop_depot"}
DECOR = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}

EXPORT = """
local serde = require("@lune/serde")
local T = require("../../src/Shared/Config/TycoonConfig")
local out = { fixed = {}, names = {}, lamps = T.streetLamps() }
for _, key in { "WORKS_STORE", "WIRE_WORKS", "DEPOT" } do
    out.fixed[key] = T[key]
end
for _, p in T.PADS do
    if p.era == 3 then
        local role = T.CREW_OF_PAD[p.id]
        out.names[p.id] = if role ~= nil then T.CREWS[role].name else p.name
    end
end
print(serde.encode("json", out))
"""


def mill_places():
    tmp = os.path.join(ROOT, "scripts", "_tmp_works")
    os.makedirs(tmp, exist_ok=True)
    path = os.path.join(tmp, "works_places.luau")
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
    wx0, wx1, wy0, wy1 = 3540, 5380, 600, 1880
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
            base = pad["y"] + 8 + ART_OFFSET_Y.get(pad["id"], 0)
            things.append((pad["y"], art[0], pad["x"], base, art[1], places["names"].get(pad["id"], "")))
    for lamp in places.get("lamps", []):  # felinarele aprinse (TycoonConfig.streetLamps)
        if wx0 <= lamp["x"] <= wx1:
            things.append((lamp["y"], "prop_street_lamp_lit", lamp["x"], lamp["y"], 3, None))
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

    path = os.path.join(P.SCRATCH, "d67_works_map.png")
    write_png(path, img.w, img.h, img.px)
    print(f"scris {path} ({img.w}x{img.h})")


if __name__ == "__main__":
    main()
