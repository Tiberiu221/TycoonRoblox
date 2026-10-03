#!/usr/bin/env python3
"""Era 4 "The Dam", lumea 2: harta sintetizata din cele trei propuneri, desenata la 1/2 (doar PIL).

Coordonatele sunt in px de teren, ca in src/Shared/Config/TycoonConfig.luau:
  - drumuri, curti, apa, zid: dreptunghi (x, y, w, h) cu (x, y) coltul din stanga-sus;
  - cladiri fixe, gramezi: punct de baza (x = mijloc, y = talpa), ca STORAGE / SAWMILL / TAVERN;
  - platforme (plase, case, Kiln, Crystal Shed, Dam Bell, taraba): centrul platformei, cladirea are baza la y + 56;
  - locuri (stand, inel, usa, oameni): punctul picioarelor.
Scriptul scrie si dam_layout.json, citit de synth_check.luau (verificatorul de asezare, ciclurile oamenilor).
Rulare: python3 preview_dam_layout.py  ->  dam_layout_preview.png
"""
import json
import os
import re

from PIL import Image, ImageDraw, ImageFont

# [2026-10-03] Propunerea de asezare a cartierului barajului (docs/PLAN-HARTA.md, sectiunea 9), NEAPROBATA. Planse in
# scratchpad, ca celelalte preview_*.py; nimic nu se urca.
SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad"
OUT_PNG = os.path.join(SCRATCH, "dam_layout_preview.png")
OUT_JSON = os.path.join(SCRATCH, "dam_layout.json")
OUT_ZOOM = os.path.join(SCRATCH, "dam_town_decor_zoom.png")
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

S = 0.5  # scara desenului
WORLD_W, WORLD_H = 3385, 1920
ZONE = (200, 3065)  # zona Erei 4 in lumea 2 (Dam Town + zid + cartier), ca Landing 200..1860
FOG = (3065, WORLD_W)  # ceata Erei 5


def P(x, y):
    return {"x": x, "y": y}


# ---------------------------------------------------------------- drumuri (x, y, w, h)
ROADS = [
    {"id": "lake_deck", "x": 240, "y": 772, "w": 400, "h": 84, "kind": "deck"},
    {"id": "town_lane", "x": 525, "y": 856, "w": 50, "h": 564, "kind": "lane"},
    {"id": "town_plaza", "x": 240, "y": 1090, "w": 310, "h": 80, "kind": "stone"},
    {"id": "street", "x": 240, "y": 1420, "w": 2825, "h": 60, "kind": "street"},
    {"id": "dam_lane", "x": 880, "y": 856, "w": 40, "h": 564, "kind": "lane"},
    {"id": "cable_lane", "x": 1300, "y": 856, "w": 40, "h": 564, "kind": "lane"},
    {"id": "pylon_lane", "x": 2465, "y": 856, "w": 40, "h": 564, "kind": "lane"},
    {"id": "switch_square", "x": 1879, "y": 1090, "w": 606, "h": 80, "kind": "stone"},
]
DECK = {"id": "deck", "x": 880, "y": 772, "w": 1880, "h": 84}

# ---------------------------------------------------------------- apa si zidul
RIVER = {"x": 880, "y": 480, "w": WORLD_W - 880, "h": 288}
LAKE = {"x": 0, "y": 480, "w": 640, "h": 288}
CANAL = {"x": 2193, "y": 768, "w": 64, "h": 468}  # apa deschisa 768..1236; sub Relay intra in stavila
CANAL_BLOCKED = [  # ce i se da lui WorldMap.blockedRects(extra) in lumea 2
    {"x": 2193, "y": 856, "w": 64, "h": 234},
    {"x": 2193, "y": 1170, "w": 64, "h": 66},
]
DAM_WALL = {"x": 640, "y": 392, "w": 240, "h": 568}
SPILLWAY = {"x": 690, "y": 480, "w": 140, "h": 288}

# ---------------------------------------------------------------- cladiri fixe (baza)
FIXED = [
    {"name": "damStore", "label": "Dam Store", "x": 1090, "y": 1010, "w": 120, "h": 96, "kind": "store"},
    {"name": "switchyard", "label": "Switchyard", "x": 1090, "y": 1380, "w": 120, "h": 96, "kind": "proc"},
    {"name": "cableStore", "label": "Cable Store", "x": 1510, "y": 1010, "w": 120, "h": 96, "kind": "store"},
    {"name": "cableworks", "label": "Cable Works", "x": 1510, "y": 1380, "w": 120, "h": 96, "kind": "proc"},
    {"name": "relay", "label": "RELAY", "x": 2225, "y": 1380, "w": 192, "h": 144, "kind": "union"},
    {"name": "switchHouse", "label": "SWITCH HOUSE", "x": 2039, "y": 1080, "w": 192, "h": 144, "kind": "seller"},
]
# decor de Dam Town si al zidului (fara rol in motor)
LANDMARKS = [
    {"name": "canteen", "label": "Canteen", "x": 400, "y": 1080, "w": 192, "h": 144, "kind": "decor"},
    {"name": "bell_tower", "label": "3 old bells", "x": 760, "y": 960, "w": 96, "h": 240, "kind": "bells"},
    {"name": "memory_wall", "label": "Memory Wall", "x": 760, "y": 1340, "w": 192, "h": 96, "kind": "decor"},
    {"name": "cottage_1", "label": "", "x": 290, "y": 1620, "w": 120, "h": 102, "kind": "cottage"},
    {"name": "cottage_2", "label": "", "x": 430, "y": 1620, "w": 120, "h": 102, "kind": "cottage"},
    {"name": "cottage_3", "label": "", "x": 570, "y": 1620, "w": 120, "h": 102, "kind": "cottage"},
]
# lucruri din coltul copilului, pastrate pe coordonatele lumii 1 (TycoonConfig.luau:299-314, 490-492)
KID_CORNER = [
    {"name": "pier", "x0": 252, "y0": 602, "x1": 348, "y1": 914},
    {"name": "ferry", "x0": 356, "y0": 732, "x1": 480, "y1": 792},
]

# ---------------------------------------------------------------- platforme (centru)
NETS = [
    {"id": "dam_turbine", "x": 980, "lane": 3, "label": "Dam Turbine", "note": "free, built into the wall"},
    {"id": "cable_net", "x": 1380, "lane": 1, "label": "Cable Net", "note": "free"},
    {"id": "second_cable_net", "x": 1580, "lane": 1, "label": "Cable Net II", "note": "bought"},
    {"id": "third_cable_net", "x": 1780, "lane": 2, "label": "Cable Net III", "note": "bought"},
    {"id": "crystal_net", "x": 2625, "lane": 3, "label": "Crystal Net", "note": "bought late"},
]
LANE_Y = {1: 732, 2: 660, 3: 588}
BUILD_PADS = [
    {"id": "hire_dispatcher", "x": 1770, "y": 1030, "w": 128, "h": 80, "home": True, "kind": "stall", "label": "Dispatcher"},
    {"id": "crystal_shed", "x": 2695, "y": 954, "w": 120, "h": 96, "kind": "store", "label": "Crystal Shed"},
    {"id": "crystal_kiln", "x": 2835, "y": 1324, "w": 192, "h": 144, "kind": "proc", "label": "Kiln"},
    {"id": "dam_bell", "x": 2985, "y": 954, "w": 120, "h": 168, "kind": "bell", "label": "Dam Bell"},
]
HUTS = [  # (id, x, nume sub casa, linia, veteran)
    ("hire_dam_collector", 760, "Dam Collector", "barrels", True),
    ("hire_dam_porter", 910, "Dam Porter", "barrels", True),
    ("hire_switchman", 1060, "Switchman", "barrels", True),
    ("hire_barrel_hauler", 1210, "Barrel Hauler", "barrels", True),
    ("hire_cable_collector", 1370, "Cable Collector", "cable", False),
    ("hire_cable_porter", 1520, "Cable Porter", "cable", False),
    ("hire_cablemaker", 1670, "Cablemaker", "cable", False),
    ("hire_cable_hauler", 1820, "Cable Hauler", "cable", False),
    ("hire_relay_keeper", 2190, "Relay Keeper", "grid", False),
    ("hire_pylon_runner", 2350, "Pylon Runner", "grid", False),
    ("hire_crystal_collector", 2510, "Crystal Collector", "crystal", False),
    ("hire_crystal_porter", 2660, "Crystal Porter", "crystal", False),
    ("hire_crystalsmith", 2810, "Crystalsmith", "crystal", False),
    ("hire_ingot_hauler", 2960, "Ingot Hauler", "crystal", False),
]
HUT_Y = 1564

# ---------------------------------------------------------------- locurile liniilor (LinePlaces / JoinPlaces / SellerPlaces)
LINES = {
    "barrels": {
        "storeStand": P(930, 1010), "storePile": P(990, 1010),
        "processorIn": P(930, 1410), "inPile": P(990, 1380), "playerStand": P(1070, 1405),
        "outPile": P(1195, 1380), "processorOut": P(1255, 1412), "workerStand": P(1200, 1452),
        "secondOffset": P(-60, 0),
    },
    "cable": {
        "storeStand": P(1350, 1010), "storePile": P(1410, 1010),
        "processorIn": P(1350, 1410), "inPile": P(1410, 1380), "playerStand": P(1490, 1405),
        "outPile": P(1615, 1380), "processorOut": P(1675, 1412), "workerStand": P(1620, 1452),
        "secondOffset": P(-60, 0),
    },
    "crystal": {
        "storeStand": P(2535, 1010), "storePile": P(2595, 1010),
        "processorIn": P(2635, 1410), "inPile": P(2699, 1380), "playerStand": P(2815, 1405),
        "outPile": P(2971, 1380), "processorOut": P(3035, 1412), "workerStand": P(2895, 1452),
        "secondOffset": P(60, 0),
    },
}
JOIN = {
    "grid": {
        "inputIn": {"barrels": P(1897, 1410), "cable": P(2025, 1410)},
        "inPiles": {"barrels": P(1961, 1380), "cable": P(2089, 1380)},
        "processorOut": P(2425, 1412), "playerStand": P(2205, 1405), "workerStand": P(2285, 1452),
        "outPile": P(2361, 1380), "secondOffset": P(60, 0),
    }
}
_TAVERN_SPOTS = [(340, 1094, "up"), (380, 1098, "up"), (330, 1150, "right"), (282, 1160, "right"),
                 (385, 1180, "left"), (236, 1196, "right"), (318, 1212, "up"), (430, 1214, "left")]
_DX = 2059 - 420  # usa Switch House - usa tavernei: clientii stau ca la taverna (intrarea, mai jos, nu)
TOWN = {
    "door": P(2059, 1130), "stand": P(2109, 1152), "pile": P(1901, 1086),
    "building": {"x": 2039, "y": 1080, "w": 192, "h": 144}, "secondOffset": P(48, 0),
    "customerSpots": [{"x": x + _DX, "y": y, "facing": f} for x, y, f in _TAVERN_SPOTS],
    # [dupa verificatorul j7] intrarea pe iarba de sub piata, nu prin taraba Dispatcher-ului (in oglinda ar fi fost y 1130)
    "customerEntry": P(150 + _DX, 1240),
}
PILES = {  # numele din FlowConfig -> baza
    "DamStorePile": LINES["barrels"]["storePile"], "SwitchyardPile": LINES["barrels"]["inPile"],
    "BarrelPile": LINES["barrels"]["outPile"], "CableStorePile": LINES["cable"]["storePile"],
    "CableworksPile": LINES["cable"]["inPile"], "CablePile": LINES["cable"]["outPile"],
    "RelayBarrelPile": JOIN["grid"]["inPiles"]["barrels"], "RelayCablePile": JOIN["grid"]["inPiles"]["cable"],
    "GridPile": JOIN["grid"]["outPile"], "TownPile": TOWN["pile"],
    "CrystalPile": LINES["crystal"]["storePile"], "KilnPile": LINES["crystal"]["inPile"],
    "IngotPile": LINES["crystal"]["outPile"],
}

# ---------------------------------------------------------------- curti (pamant batatorit, x, y, w, h)
YARDS = [
    {"id": "dam_store_yard", "x": 922, "y": 968, "w": 244, "h": 72},
    {"id": "switchyard_yard", "x": 922, "y": 1326, "w": 353, "h": 92},
    {"id": "cable_store_yard", "x": 1342, "y": 968, "w": 244, "h": 72},
    {"id": "cableworks_yard", "x": 1342, "y": 1326, "w": 353, "h": 92},
    {"id": "dispatcher_yard", "x": 1690, "y": 1034, "w": 160, "h": 70},
    {"id": "switch_house_yard", "x": 1861, "y": 1040, "w": 324, "h": 156},
    {"id": "relay_yard", "x": 1877, "y": 1318, "w": 568, "h": 100},
    {"id": "pylon_yard", "x": 2300, "y": 1040, "w": 120, "h": 44},
    {"id": "crystal_shed_yard", "x": 2515, "y": 968, "w": 250, "h": 72},
    {"id": "kiln_yard", "x": 2619, "y": 1318, "w": 442, "h": 100},
    {"id": "dam_bell_yard", "x": 2917, "y": 984, "w": 136, "h": 52},
    {"id": "canteen_yard", "x": 222, "y": 1040, "w": 362, "h": 156},
    {"id": "memory_wall_yard", "x": 650, "y": 1326, "w": 220, "h": 30},
]
for _id, _x, _n, _l, _v in HUTS:
    YARDS.append({"id": f"{_id}_yard", "x": _x - 72, "y": 1594, "w": 144, "h": 44})
for _c in LANDMARKS:
    if _c["kind"] == "cottage":
        YARDS.append({"id": f"{_c['name']}_yard", "x": _c["x"] - 72, "y": 1594, "w": 144, "h": 44})

# ---------------------------------------------------------------- decor: stalpii (doar desenati)
PYLONS = [  # (x, baza, inaltime, nume) baza-centru, 24-48 lat
    {"name": "river_pylon", "x": 2360, "y": 1070, "w": 48, "h": 200, "overRoad": False},
    {"name": "lane_pylon", "x": 2450, "y": 1300, "w": 24, "h": 120, "overRoad": False},
    {"name": "bridge_pylon_w", "x": 2190, "y": 1100, "w": 16, "h": 70, "overRoad": True},
    {"name": "bridge_pylon_e", "x": 2262, "y": 1100, "w": 16, "h": 70, "overRoad": True},
]
SPAWN = P(800, 1180)
CARDS = {"bell_tower": P(760, 990), "memory_wall": P(760, 1370)}


# ---------------------------------------------------------------- decorul cumparat cu perle (pasul k2b)
def _balanced(text, start):
    """textul dintre acolada de la `start` (un '{') si perechea ei"""
    depth = 0
    for i in range(start, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i]
    raise SystemExit("acolade neinchise in VillageConfig.luau")


def load_decor():
    """Decorul din VillageConfig.DECOR cu locurile LUMII 2 (spotsByWorld[2], altfel spots: ponton si apa stau pe loc) si
    marimea de pe ecran (Assets.decor[sprite] x scale). Citit din surse, nu copiat: planseta nu poate iesi din pas cu jocul."""
    cfg = open(os.path.join(ROOT, "src", "Shared", "Config", "VillageConfig.luau")).read()
    assets = open(os.path.join(ROOT, "src", "Shared", "Config", "Assets.luau")).read()
    block = re.search(r"\n    decor = \{(.*?)\n    \},", assets, re.S).group(1)
    sizes = {k: (int(w), int(h)) for k, w, h in re.findall(r"(\w+) = sprite\(\d+, (\d+), (\d+)\)", block)}
    starts = [(m.start(), m.group(1)) for m in re.finditer(r'\n    \{\n        id = "(\w+)",', cfg)]
    out = []
    for n, (at, ident) in enumerate(starts):
        end = starts[n + 1][0] if n + 1 < len(starts) else len(cfg)
        body = cfg[at:end]
        ground = re.search(r'ground = "(\w+)"', body).group(1)
        sprite = re.search(r'sprite = "(\w+)"', body).group(1)
        scale = int(re.search(r"scale = (\d+)", body).group(1))
        spots_at = re.search(r"spotsByWorld = \{", body)
        spots = None
        if spots_at is not None:
            inner = _balanced(body, spots_at.end() - 1)
            two = re.search(r"\[2\] = \{", inner)
            if two is not None:
                spots = re.findall(r"x = (\d+), y = (\d+)", _balanced(inner, two.end() - 1))
        if spots is None:
            plain = re.search(r"\bspots = \{", body)
            spots = re.findall(r"x = (\d+), y = (\d+)", _balanced(body, plain.end() - 1))
        w, h = sizes[sprite]
        out.append({"id": ident, "ground": ground, "overRoad": "overRoad = true" in body, "w": w * scale, "h": h * scale,
                    "spots": [P(int(x), int(y)) for x, y in spots]})
    return out


DECOR = load_decor()
DECOR_CODE = {"flowerbeds": "flowers", "pier_lamps": "lamp", "bench": "bench", "bunting": "bunting", "well": "well",
              "garden": "garden", "rowboat": "rowboat", "beehives": "hives", "fountain": "fountain", "statue": "statue"}

LAYOUT = {
    "worldWidth": WORLD_W, "zone": {"x0": ZONE[0], "x1": ZONE[1]}, "deck": DECK, "roads": ROADS,
    "canalBlocked": CANAL_BLOCKED, "fixed": FIXED, "landmarks": LANDMARKS, "kidCorner": KID_CORNER,
    "nets": [dict(n, y=812) for n in NETS], "buildPads": BUILD_PADS,
    "huts": [{"id": i, "x": x, "y": HUT_Y, "name": n, "line": l, "veteran": v} for i, x, n, l, v in HUTS],
    "lines": LINES, "join": JOIN, "town": TOWN, "piles": PILES, "yards": YARDS, "pylons": PYLONS,
    "spawn": SPAWN, "cards": CARDS, "decor": DECOR,
}


# ================================================================ desenul
def font(size, bold=False):
    names = (["Arial Bold.ttf"] if bold else []) + ["Arial Narrow.ttf", "Arial.ttf"]
    for n in names:
        for d in ("/System/Library/Fonts/Supplemental", "/Library/Fonts"):
            p = os.path.join(d, n)
            if os.path.exists(p):
                return ImageFont.truetype(p, size)
    return ImageFont.load_default()


F_TITLE, F_BIG, F_MED, F_SMALL, F_TINY = font(22, True), font(13, True), font(12), font(11), font(10)

GRASS = (126, 168, 92)
NORTH = (110, 150, 84)
WATER = (64, 124, 186)
LAKE_C = (52, 104, 168)
CANAL_C = (78, 140, 200)
DECK_C = (150, 106, 62)
ROAD_C = (214, 190, 140)
STONE_C = (186, 186, 180)
YARD_C = (176, 146, 100)
WALL_C = (150, 150, 158)
LINE_C = {"barrels": (230, 120, 20), "cable": (190, 70, 40), "grid": (240, 200, 0), "crystal": (150, 80, 200)}
KIND_C = {"store": (222, 196, 150), "proc": (160, 110, 70), "union": (150, 120, 200), "seller": (236, 200, 90),
          "stall": (230, 170, 120), "bell": (190, 140, 60), "decor": (200, 200, 200), "bells": (170, 170, 180),
          "cottage": (214, 196, 168)}

im = Image.new("RGB", (int(WORLD_W * S), int(WORLD_H * S)), GRASS)
d = ImageDraw.Draw(im, "RGBA")


def sx(v):
    return v * S


def rect(x, y, w, h, fill=None, outline=None, width=1):
    d.rectangle([sx(x), sx(y), sx(x + w), sx(y + h)], fill=fill, outline=outline, width=width)


def box_base(cx, base, w, h):
    return cx - w / 2, base - h, w, h


def text_c(x, y, s, f=F_SMALL, fill=(0, 0, 0), bg=None):
    """text centrat pe (x, y) in coordonate de teren"""
    l, t, r, b = d.textbbox((0, 0), s, font=f)
    tw, th = r - l, b - t
    px, py = sx(x) - tw / 2, sx(y) - th / 2
    if bg is not None:
        d.rectangle([px - 2, py - 1, px + tw + 2, py + th + 2], fill=bg)
    d.text((px - l, py - t), s, font=f, fill=fill)


def arrow(pts, color, width=3, head=7):
    q = [(sx(x), sx(y)) for x, y in pts]
    d.line(q, fill=color, width=width, joint="curve")
    (x0, y0), (x1, y1) = q[-2], q[-1]
    import math
    a = math.atan2(y1 - y0, x1 - x0)
    p1 = (x1 - head * math.cos(a - 0.45), y1 - head * math.sin(a - 0.45))
    p2 = (x1 - head * math.cos(a + 0.45), y1 - head * math.sin(a + 0.45))
    d.polygon([(x1, y1), p1, p2], fill=color)


# cer/mal de nord si orasul pictat
rect(0, 0, WORLD_W, 488, NORTH)
for i, x in enumerate(range(1880, 2560, 70)):
    hgt = 40 + (i * 17) % 30
    rect(x, 470 - hgt, 50, hgt, (205, 190, 160), (90, 80, 60))
    rect(x + 18, 470 - hgt + 12, 12, 10, (255, 230, 120))
text_c(2220, 395, "painted town (north bank, not walkable) - windows light up", F_SMALL, (40, 40, 40), (235, 235, 220))
# apa
rect(**RIVER, fill=WATER)
rect(**LAKE, fill=LAKE_C)
rect(**CANAL, fill=CANAL_C)
rect(2185, 768, 8, 468, (120, 120, 120))
rect(2257, 768, 8, 468, (120, 120, 120))
d.rectangle([sx(2193), sx(1236), sx(2257), sx(1380)], outline=(40, 70, 120), width=1)
text_c(2225, 1000, "canal", F_TINY, (255, 255, 255))
text_c(320, 520, "THE LAKE", F_BIG, (230, 240, 255))
text_c(2000, 520, "river below the dam (floats start at the spillway, x 880)", F_SMALL, (230, 240, 255))
# curentul plutitorilor
d.line([sx(880), sx(552), sx(2700), sx(552)], fill=(200, 225, 255), width=1)
# zidul
rect(**DAM_WALL, fill=WALL_C, outline=(60, 60, 70), width=2)
rect(**SPILLWAY, fill=(225, 238, 250))
text_c(760, 620, "spillway", F_TINY, (40, 60, 90))
text_c(760, 430, "DAM", F_BIG, (20, 20, 30))
# zona, ceata
rect(FOG[0], 488, FOG[1] - FOG[0], WORLD_H - 488, (60, 60, 70, 150))
text_c((FOG[0] + FOG[1]) / 2, 1250, "Era 5 fog", F_BIG, (240, 240, 240))
d.line([sx(ZONE[1]), sx(800), sx(ZONE[1]), sx(1650)], fill=(60, 40, 20), width=3)

# curti
for y_ in YARDS:
    rect(y_["x"], y_["y"], y_["w"], y_["h"], YARD_C)
# drumuri
for r_ in ROADS:
    c = {"deck": DECK_C, "stone": STONE_C}.get(r_["kind"], ROAD_C)
    rect(r_["x"], r_["y"], r_["w"], r_["h"], c)
rect(DECK["x"], DECK["y"], DECK["w"], DECK["h"], DECK_C)
for x in range(DECK["x"], DECK["x"] + DECK["w"], 24):
    d.line([sx(x), sx(772), sx(x), sx(856)], fill=(120, 84, 48), width=1)
rect(2185, 1090, 80, 80, (160, 160, 150), (90, 90, 90), 2)  # podul cu stalpi
text_c(2225, 1112, "pylon", F_TINY, (30, 30, 30))
text_c(2225, 1150, "bridge", F_TINY, (30, 30, 30))
rect(2185, 1236, 80, 184, (150, 150, 150, 120))  # stavila sub Relay
# zidul pe uscat: ce se vede de pe mal
text_c(780, 1450, "STREET", F_TINY, (90, 70, 40))
text_c(900, 1180, "dam\nlane", F_TINY, (90, 70, 40))
text_c(1320, 1180, "cable\nlane", F_TINY, (90, 70, 40))
text_c(550, 1300, "town\nlane", F_TINY, (90, 70, 40))
text_c(1600, 814, "DECK", F_TINY, (240, 220, 190))
text_c(2485, 960, "pylon\nlane", F_TINY, (60, 50, 30))
text_c(2225, 1270, "sluice", F_TINY, (230, 240, 255))
text_c(2160, 1200, "Switch Square", F_TINY, (40, 40, 40))
d.text((sx(2465) + 2, sx(860)), "", fill=(0, 0, 0))

# drumul oamenilor (sagetile marfii), sub cladiri
L, J, T = LINES, JOIN["grid"], TOWN
arrow([(980, 812), (900, 812), (900, 1000), (925, 1010)], LINE_C["barrels"])
arrow([(925, 1020), (925, 1400)], LINE_C["barrels"])
arrow([(1255, 1440), (1880, 1440)], LINE_C["barrels"], 4)
arrow([(1780, 800), (1320, 800), (1320, 1000), (1345, 1010)], LINE_C["cable"])
arrow([(1345, 1020), (1345, 1400)], LINE_C["cable"])
arrow([(1675, 1462), (2010, 1462)], LINE_C["cable"], 4)
arrow([(2425, 1440), (2485, 1440), (2485, 1135), (2075, 1135)], LINE_C["grid"], 4)
arrow([(2625, 812), (2485, 812), (2485, 1000), (2530, 1010)], LINE_C["crystal"])
arrow([(2530, 1020), (2510, 1020), (2510, 1400), (2630, 1400)], LINE_C["crystal"])
arrow([(3035, 1470), (2500, 1470), (2500, 1150), (2075, 1150)], LINE_C["crystal"], 3)

# platformele plaselor si corpul plasei pe banda ei
for n in NETS:
    x, ly = n["x"], LANE_Y[n["lane"]]
    rect(x - 48, 764, 96, 96, None, (255, 255, 255), 2)
    if n["id"] == "dam_turbine":
        rect(824, 690, 56, 78, (70, 70, 90), (20, 20, 30), 2)  # turbina zidita in fata zidului, nu pe banda plutitorilor
        text_c(852, 729, "turb.", F_TINY, (255, 255, 255))
        d.line([sx(880), sx(740), sx(x), sx(764)], fill=(255, 255, 255), width=1)
    else:
        rect(x - 48, ly - 27, 96, 54, (240, 236, 200), (30, 30, 30))
        d.line([sx(x), sx(ly + 27), sx(x), sx(764)], fill=(240, 236, 200), width=1)
    text_c(x, 790, n["label"], F_TINY, (255, 255, 255), (60, 40, 20))
    text_c(x, 838, n["note"], F_TINY, (255, 240, 200))

# cladiri fixe, repere, platforme de cladiri
for b in FIXED + LANDMARKS:
    x0, y0, w, h = box_base(b["x"], b["y"], b["w"], b["h"])
    rect(x0, y0, w, h, KIND_C[b["kind"]], (30, 30, 30), 2)
    if b["label"]:
        text_c(b["x"], y0 + h / 2, b["label"], F_BIG if b["kind"] in ("union", "seller") else F_SMALL, (10, 10, 10))
for p in BUILD_PADS:
    rect(p["x"] - 48, p["y"] - 48, 96, 96, None, (255, 255, 255), 1)
    x0, y0, w, h = box_base(p["x"], p["y"] + 56, p["w"], p["h"])
    rect(x0, y0, w, h, KIND_C[p["kind"]], (30, 30, 30), 2)
    text_c(p["x"], y0 + h / 2, p["label"], F_SMALL, (10, 10, 10))
text_c(2225, 1340, "2 in  ->  1 out", F_SMALL, (20, 10, 40))
text_c(2039, 1050, "sells power + ingots", F_TINY, (40, 30, 0))
# case
for i, x, n, l, v in HUTS:
    rect(x - 60, 1518, 120, 102, (226, 206, 170) if not v else (210, 196, 180), LINE_C[l], 3)
    first, _, rest = n.partition(" ")
    text_c(x, 1555, first, F_SMALL)
    if rest:
        text_c(x, 1572, rest, F_SMALL)
    if v:
        text_c(x, 1598, "veteran", F_TINY, (90, 60, 30))
text_c(2005, 1690, "hut row y 1564: each group under its own line (orange barrels, red cable, yellow grid, violet crystal)", F_SMALL,
       (30, 30, 30), (230, 225, 200))
# gramezi
for name, p in PILES.items():
    rect(p["x"] - 40, p["y"] - 56, 80, 56, (120, 90, 50, 220), (20, 20, 20))
    short = name.replace("Pile", "")
    text_c(p["x"], p["y"] - 28, short, F_TINY, (255, 255, 255))
# locuri: E = loc de predare, R = inel, oameni
STAND_C = (200, 20, 20)
WORK_C = (30, 50, 200)


def stand(p, tag):
    x, y = p["x"], p["y"]
    d.ellipse([sx(x) - 4, sx(y) - 4, sx(x) + 4, sx(y) + 4], fill=STAND_C)
    text_c(x, y + 18, tag, F_TINY, STAND_C, (255, 255, 255, 170))


def person(p, tag=""):
    x, y = p["x"], p["y"]
    rect(x - 24, y - 72, 48, 72, (40, 60, 210, 120), WORK_C)
    if tag:
        text_c(x, y - 36, tag, F_TINY, (255, 255, 255))


def ring(p):
    x, y = p["x"], p["y"]
    d.ellipse([sx(x - 48), sx(y - 28), sx(x + 48), sx(y + 20)], outline=(255, 230, 0), width=2)


for name, pl in LINES.items():
    stand(pl["storeStand"], "st")
    stand(pl["processorIn"], "in")
    stand(pl["processorOut"], "out")
    ring(pl["playerStand"])
    w, so = pl["workerStand"], pl["secondOffset"]
    person(w, "1")
    person({"x": w["x"] + so["x"], "y": w["y"] + so["y"]}, "2")
stand(J["inputIn"]["barrels"], "barrels in")
stand(J["inputIn"]["cable"], "cable in")
stand(J["processorOut"], "out")
ring(J["playerStand"])
person(J["workerStand"], "1")
person({"x": J["workerStand"]["x"] + 60, "y": J["workerStand"]["y"]}, "2")
stand(T["door"], "door")
person(T["stand"], "D")
person({"x": T["stand"]["x"] + 60, "y": T["stand"]["y"]}, "2")
for c in T["customerSpots"]:
    d.ellipse([sx(c["x"]) - 3, sx(c["y"]) - 3, sx(c["x"]) + 3, sx(c["y"]) + 3], fill=(250, 250, 250), outline=(60, 60, 60))
stand(T["customerEntry"], "customers in")
# stalpii si firul
for pyl in PYLONS:
    x0, y0, w, h = box_base(pyl["x"], pyl["y"], pyl["w"], pyl["h"])
    rect(x0, y0, w, h, (90, 90, 100), (20, 20, 20))
wire = [(2225, 1236), (2262, 1030), (2360, 870), (2360, 470)]
d.line([(sx(x), sx(y)) for x, y in wire], fill=(30, 30, 30), width=2)
d.line([(sx(2190), sx(1030)), (sx(2135), sx(960))], fill=(30, 30, 30), width=2)
text_c(2360, 455, "wire to town", F_TINY, (20, 20, 20), (235, 235, 220))
# felinarele strazii (regula streetLamps, cu oamenii Relay-ului ocoliti)
for lx_ in (835, 1290, 1445, 1745, 2585, 2735):
    rect(lx_ - 3, 1372, 6, 120, (250, 215, 0), (90, 70, 0))
text_c(395, 1700, "Dam Town cottages (retired villagers)", F_TINY, (40, 30, 20), (230, 220, 190))
# spawn, cardurile zidului
for nm, p in CARDS.items():
    d.ellipse([sx(p["x"]) - 4, sx(p["y"]) - 4, sx(p["x"]) + 4, sx(p["y"]) + 4], fill=(255, 255, 255), outline=(0, 0, 0))
text_c(760, 1005, "E: Ring your old bells", F_TINY, (0, 0, 0), (255, 255, 255, 190))
x, y = SPAWN["x"], SPAWN["y"]
d.polygon([(sx(x), sx(y - 30)), (sx(x - 12), sx(y)), (sx(x + 12), sx(y))], fill=(255, 255, 255), outline=(0, 0, 0))
text_c(x, y + 14, "you appear", F_TINY, (0, 0, 0), (255, 255, 255, 190))
# pontonul si barca (coltul copilului, neschimbat)
for k in KID_CORNER:
    rect(k["x0"], k["y0"], k["x1"] - k["x0"], k["y1"] - k["y0"], (170, 120, 70), (60, 40, 20))
text_c(300, 690, "pier", F_TINY, (255, 255, 255))
text_c(440, 800, "ferry, wheel, board", F_TINY, (255, 255, 255))
text_c(395, 1130, "DAM TOWN", F_BIG, (40, 30, 20), (230, 220, 190))

# decorul cumparat cu perle: fiecare loc cu marimea lui reala (baza-centru), cu eticheta lui
DECOR_C = {"land": (236, 90, 160), "pier": (255, 170, 40), "water": (40, 200, 220)}
for dec in DECOR:
    for k, sp in enumerate(dec["spots"], 1):
        x0, y0, w, h = box_base(sp["x"], sp["y"], dec["w"], dec["h"])
        c = DECOR_C[dec["ground"]]
        rect(x0, y0, w, h, c + (150,), (120, 20, 80) if dec["ground"] == "land" else (60, 60, 60), 2 if dec["overRoad"] else 1)
        d.ellipse([sx(sp["x"]) - 2, sx(sp["y"]) - 2, sx(sp["x"]) + 2, sx(sp["y"]) + 2], fill=(120, 20, 80))
        tag = DECOR_CODE[dec["id"]] + (f" {k}" if len(dec["spots"]) > 1 else "")
        text_c(sp["x"], sp["y"] + 24, tag, F_TINY, (90, 10, 60), (255, 255, 255, 190))

# titlul si legenda
d.text((14, 10), "Era 4 'The Dam' - world 2, synthesized layout (1/2 scale)", font=F_TITLE, fill=(20, 20, 20))
d.text((14, 40), "district x 880..3065 (2185 px), Era-4 zone 200..3065, world 3385 px; gold = player ring, red dot = hand-off "
                 "stand, blue box = worker (1 / 2)", font=F_MED, fill=(20, 20, 20))
lx = 14
for name, col in LINE_C.items():
    d.rectangle([lx, 64, lx + 26, 72], fill=col)
    d.text((lx + 32, 60), {"barrels": "barrels (veterans)", "cable": "cable (your hand tour)", "grid": "power: Relay -> bridge -> "
                           "Switch House", "crystal": "crystal (late)"}[name], font=F_MED, fill=(20, 20, 20))
    lx += 250
d.rectangle([14, 90, 40, 98], fill=DECOR_C["land"] + (150,), outline=(120, 20, 80))
d.text((46, 86), "village-board decor on land (real footprint, base-centred; frame = over the road): 12 spots in Dam Town; "
                 "orange = pier, cyan = lake (same spots as the village)", font=F_MED, fill=(20, 20, 20))
# scara
d.line([(14, 120), (14 + 500 * S, 120)], fill=(0, 0, 0), width=3)
d.text((14, 124), "500 px of world", font=F_SMALL, fill=(0, 0, 0))
# riglele x
for x in range(0, WORLD_W, 250):
    d.line([(sx(x), sx(1890)), (sx(x), sx(1910))], fill=(40, 40, 40), width=1)
    d.text((sx(x) + 2, sx(1870)), str(x), font=F_TINY, fill=(40, 40, 40))

im.save(OUT_PNG)
# Dam Town cu decorul, de aproape (x 200..900, y 720..1700, de doua ori marit fata de planseta) pentru judecat locurile
im.crop((int(200 * S), int(720 * S), int(900 * S), int(1700 * S))).resize((int(700 * S) * 2, int(980 * S) * 2), Image.NEAREST).save(OUT_ZOOM)
with open(OUT_JSON, "w") as fh:
    json.dump(LAYOUT, fh, indent=1)
print(OUT_PNG, im.size)
