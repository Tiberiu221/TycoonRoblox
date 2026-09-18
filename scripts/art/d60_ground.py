#!/usr/bin/env python3
"""[D60] PAMANTUL BALCIULUI, COPT INTR-O SINGURA IMAGINE, si tot ce se aseaza peste el.

De ce: prima versiune din joc desena poiana din dreptunghiuri si discuri plate (un disc portocaliu cu margine taiata,
lumini din cercuri, fara padure); owner-ul, 2026-09-17: "arata super super cheap atm texturile, efectele acelea de
lumina, obiectele, pamantul ala circular, basically everything". Macheta aprobata (balci_aproape) arata bine pentru
ca era o singura imagine de noapte: iarba intunecata, pamant batatorit cu margini rupte, balti de lumina calda,
paie si pietricele, padure de jur imprejur. Scriptul asta face exact imaginea aceea, la pixelul jocului (1 pixel =
3 pixeli de lume), iar jocul o pune dedesubt (Assets.fair.ground). Peste ea raman doar ce se misca sau se acopera
cu oamenii: obiectele, copacii, ghirlandele, scanteile.

Iese:
  * assets/sprites/prop_fair_ground.png -- fundalul: harta plus o margine de padure (pe un ecran lat nu se vede golul)
  * assets/sprites/prop_fair_glow.png   -- lumina moale (alb, cu alfa care scade lin), colorata de joc
  * src/Shared/Config/FairScenery.luau  -- GENERAT: unde e fundalul, luminile (tenta obiectelor), focurile,
    copacii, ghirlandele cu becurile lor, capetele felinarelor -- aceleasi date din care e copt fundalul
  * cu --preview <fisier.png>: cum arata in joc (fundal + obiecte cu lumina lor + copaci + ghirlande + etichete)

Pozitiile obiectelor se citesc din src/Shared/Modules/FairLayout.luau (aceleasi pe care le verifica testul de asezare),
marimile desenelor din src/Shared/Config/Assets.luau.

Rulare: python3 scripts/art/d60_ground.py [--preview cale.png]
"""
import math
import os
import random
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from preview_tycoon import load, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
LAYOUT = os.path.join(ROOT, "src", "Shared", "Modules", "FairLayout.luau")
ASSETS = os.path.join(ROOT, "src", "Shared", "Config", "Assets.luau")
SCENERY = os.path.join(ROOT, "src", "Shared", "Config", "FairScenery.luau")
SPRITES = os.path.join(ROOT, "assets", "sprites")

D = 3  # un pixel de imagine = 3 pixeli de lume, ca toata arta jocului
# cat acopera fundalul: harta (1620x1680) plus padure pe margini; imaginea ramane sub 1024 pe latura (limita Roblox)
GX0, GY0, GX1, GY1 = -300, -240, 1920, 1920
W, H = (GX1 - GX0) // D, (GY1 - GY0) // D

NIGHT = (18, 24, 44)
WARM = (255, 186, 96)
DIRT = (74, 58, 44)
DIRT_WORN = (62, 50, 40)
STONE = (96, 78, 62)
WATER = (16, 30, 52)
COLD = (120, 132, 176)  # obiectele departe de lumina
LIT = (255, 226, 186)  # obiectele in lumina
TREE_COLD = (96, 112, 128)
BULB_COLORS = ((255, 214, 140), (196, 232, 255), (255, 176, 196))


# ---- ce stie jocul ------------------------------------------------------------------------------------------------
def read_layout():
    src = open(LAYOUT).read()

    def rect(name):
        m = re.search(rf"FairLayout\.{name} = \{{([^}}]*)\}}", src)
        return {k: float(v) for k, v in re.findall(r"(\w+) = (-?[\d.]+)", m.group(1))}

    spots = []
    for sid, sprite, x, y, scale in re.findall(
        r'\{ id = "(\w+)", sprite = "(\w+)", x = (-?\d+), y = (-?\d+), scale = (\d+) \}', src
    ):
        spots.append(dict(id=sid, sprite=sprite, x=int(x), y=int(y), scale=int(scale)))
    edges = []
    # [D61, partea 2] `tag = true` = marginea n-are firma ei, deci scena ii scrie numele si dupa ce se deschide
    for eid, label, x, y, open_, tag in re.findall(
        r'\{ id = "(\w+)", label = "([^"]+)", x = (-?\d+), y = (-?\d+), open = (true|false)(, tag = true)? \}', src
    ):
        edges.append(dict(id=eid, label=label, x=int(x), y=int(y), open=open_ == "true", tag=tag != ""))
    water = float(re.search(r"FairLayout\.WATER_Y = (\d+)", src).group(1))
    return dict(
        size=rect("SIZE"), center=rect("CENTER"), floor=rect("FLOOR"), pond=rect("POND"),
        spawn=rect("SPAWN"), water_y=water, spots=spots, edges=edges,
    )


def read_sizes():
    """Marimile din Assets.fair si ale copacilor (Assets.props), in pixeli de desen."""
    src = open(ASSETS).read()
    fair = src.split("fair = {", 1)[1].split("\n    },", 1)[0]
    sizes = {k: (int(w), int(h)) for k, _id, w, h in re.findall(r"(\w+) = sprite\((\d+), (\d+), (\d+)\)", fair)}
    props = src.split("props = {", 1)[1].split("\n    },", 1)[0]
    for k, _id, w, h in re.findall(r"(\w+) = sprite\((\d+), (\d+), (\d+)\)", props):
        sizes["props." + k] = (int(w), int(h))
    return sizes


def box(x, base, w, h):
    return (x - w / 2, x + w / 2, base - h, base)


def hit(a, b, pad=0):
    return a[0] - pad < b[1] and b[0] - pad < a[1] and a[2] - pad < b[3] and b[2] - pad < a[3]


# ---- zgomot, ca marginile sa fie rupte, nu desenate cu compasul -------------------------------------------------
def _h(ix, iy, seed):
    n = (ix * 374761393 + iy * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def noise(x, y, scale, seed=0):
    gx, gy = x / scale, y / scale
    ix, iy = math.floor(gx), math.floor(gy)
    fx, fy = gx - ix, gy - iy
    sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = _h(ix, iy, seed) + (_h(ix + 1, iy, seed) - _h(ix, iy, seed)) * sx
    b = _h(ix, iy + 1, seed) + (_h(ix + 1, iy + 1, seed) - _h(ix, iy + 1, seed)) * sx
    return a + (b - a) * sy  # 0..1


def fbm(x, y, seed=0):
    return 0.6 * noise(x, y, 90, seed) + 0.3 * noise(x, y, 34, seed + 1) + 0.1 * noise(x, y, 12, seed + 2)


# ---- datele comune: lumini, focuri, copaci, ghirlande ------------------------------------------------------------
LIGHT_KIND = {
    # sprite: [(dx, dy fata de baza, raza, culoare, tarie)]
    "bonfire": [(0, -24, 330, (255, 156, 70), 0.66)],
    "brazier": [(0, -30, 120, (255, 180, 100), 0.40)],
    "lamppost": [(0, -20, 150, WARM, 0.42)],
    "wheel": [(0, -40, 230, (255, 196, 120), 0.40)],
    "stage": [(0, -60, 320, (255, 170, 140), 0.34), (0, -60, 430, (255, 176, 140), 0.22)],
    # rampa din fata scenei: trofeele stau in lumina, nu in umbra
    "trophy": [(0, -30, 110, (255, 214, 160), 0.34)],
    "stall_1": [(-30, -40, 130, WARM, 0.34)],
    "stall_2": [(-30, -40, 130, WARM, 0.34)],
    "stall_3": [(-30, -40, 130, WARM, 0.34)],
    "table": [(0, -12, 140, WARM, 0.22)],
    "arch": [(0, -30, 140, WARM, 0.32)],
    "tent": [(0, -30, 120, WARM, 0.26)],
    # [D61, partea 2] taraba cu copertina aurie: lumina putin mai aurie si mai tare decat a gheretelor, ca sa se vada
    "shop": [(0, -40, 140, (255, 204, 110), 0.38)],
    "booth": [(0, -30, 120, WARM, 0.26)],
    "dock": [(0, -150, 150, WARM, 0.40)],
    "plinth": [(0, -20, 110, (255, 214, 160), 0.24)],
}


def build_lights(L):
    lights = []
    for s in L["spots"]:
        for dx, dy, r, rgb, strength in LIGHT_KIND.get(s["sprite"], []):
            # [D61] jetiul iazului s-a deschis: felinarul lui de capat arde, ca la debarcader
            lights.append(dict(x=s["x"] + dx, y=s["y"] + dy, r=r, rgb=rgb, strength=strength))
    p = L["pond"]
    lights.append(dict(x=p["x"] + 40, y=p["y"] - 90, r=120, rgb=WARM, strength=0.26))
    return lights


def build_fires(L):
    out = []
    for s in L["spots"]:
        if s["sprite"] == "bonfire":
            out.append(dict(x=s["x"], y=s["y"] - 40, size=260, sparks=26))
        elif s["sprite"] == "brazier":
            out.append(dict(x=s["x"], y=s["y"] - 78, size=120, sparks=6))
    return out


def build_lamps(L, sizes):
    out = []
    for s in L["spots"]:
        if s["sprite"] == "lamppost":
            h = sizes["lamppost"][1] * s["scale"]
            out.append(dict(x=s["x"], y=s["y"] - h + 18, base=s["y"]))
    return out


def build_garlands(L, sizes, lamps):
    by_id = {s["id"]: s for s in L["spots"]}

    def head(sid):
        s = by_id[sid]
        if s["sprite"] == "lamppost":
            return (s["x"], s["y"] - sizes["lamppost"][1] * s["scale"] + 22)
        return (s["x"] - 15, s["y"] - sizes[s["sprite"]][1] * s["scale"] + 12)  # varful stalpului steagului

    pairs = [
        ("lamp_5", "lamp_1"), ("lamp_1", "lamp_2"), ("lamp_2", "lamp_3"),
        ("flag_left", "lamp_4"), ("flag_right", "lamp_5"), ("flag_left", "flag_right"),
    ]
    out = []
    for i, (a, b) in enumerate(pairs):
        if a not in by_id or b not in by_id:
            continue
        (ax, ay), (bx, by) = head(a), head(b)
        length = math.hypot(bx - ax, by - ay)
        sag = max(18, min(60, length * 0.08))
        count = max(3, int(length / 44))
        bulbs = []
        for k in range(1, count):
            t = k / count
            x = ax + (bx - ax) * t
            y = ay + (by - ay) * t + math.sin(math.pi * t) * sag
            bulbs.append(dict(x=round(x), y=round(y), color=BULB_COLORS[(k + i) % len(BULB_COLORS)]))
        out.append(dict(ax=round(ax), ay=round(ay), bx=round(bx), by=round(by), sag=round(sag), bulbs=bulbs))
    return out


def object_boxes(L, sizes):
    out = []
    for s in L["spots"]:
        w, h = sizes[s["sprite"]]
        out.append((s["id"], box(s["x"], s["y"], w * s["scale"], h * s["scale"])))
    return out


def build_trees(L, sizes, labels):
    """Padurea din jur, din samanta: nu pe poiana, nu in apa, nu peste obiecte sau etichete, nu pe drumul debarcaderului."""
    rnd = random.Random(7)
    f, p, c = L["floor"], L["pond"], L["center"]
    objects = object_boxes(L, sizes)
    trees = []
    tries = 0
    while tries < 12000 and len(trees) < 150:
        tries += 1
        x = rnd.uniform(GX0 + 30, GX1 - 30)
        base = rnd.uniform(GY0 + 120, L["water_y"] - 30)
        fq = ((x - f["x"]) / f["rx"]) ** 2 + ((base - f["y"]) / f["ry"]) ** 2
        if fq < 1.45:
            continue
        # mai des spre margini: aproape de poiana, doar cativa
        far = math.hypot((x - c["x"]) / 900, (base - c["y"]) / 900)
        if rnd.random() > min(1.0, max(0.0, (far - 0.55) * 1.8)):
            continue
        if ((x - p["x"]) / (p["rx"] + 60)) ** 2 + ((base - p["y"]) / (p["ry"] + 70)) ** 2 < 1:
            continue
        if abs(x - L["spawn"]["x"]) < 170 and base > L["spawn"]["y"] - 260:
            continue  # drumul de la debarcader in poiana ramane liber
        kind = "tree_pine" if rnd.random() < 0.55 else "tree_round"
        w, h = sizes["props." + kind]
        b = box(x, base, w * 3 * 0.7, h * 3)
        if any(hit(b, ob, 18) for _, ob in objects):
            continue
        if any(hit(b, lb, 12) for lb in labels):
            continue
        if any(math.hypot(x - t["x"], base - t["y"]) < 70 for t in trees):
            continue
        trees.append(dict(sprite=kind, x=round(x), y=round(base)))
    trees.sort(key=lambda t: t["y"])
    return trees


def label_boxes(L, sizes):
    """Cutiile etichetelor din lume (FairScene/BoardController/MarketController), ca padurea sa nu le acopere."""
    out = []
    em = 0.5586
    for e in L["edges"]:
        if not e["open"]:
            w = max(len(e["label"]), len("Opens soon")) * em * 13 + 12
            out.append((e["x"] - w / 2, e["x"] + w / 2, e["y"] - 24, e["y"] + 24))
        elif e["tag"]:
            w = len(e["label"]) * em * 15 + 12  # doar numele, fara randul mic (FairScene.tag)
            out.append((e["x"] - w / 2, e["x"] + w / 2, e["y"] - 12, e["y"] + 12))
    # [D61] numele gheretelor, deasupra lor (BoothController), la fel ca firma negustorului
    for spot_id, label in (("booth_1", "Ring Toss"), ("booth_2", "Hook a Duck")):
        s = next(x for x in L["spots"] if x["id"] == spot_id)
        _w, h = sizes[s["sprite"]]
        top = s["y"] - h * s["scale"] - 6 - 26
        w = len(label) * em * 15 + 24
        out.append((s["x"] - w / 2, s["x"] + w / 2, top, top + 26))
    return out


# ---- coacerea ------------------------------------------------------------------------------------------------------
class Canvas:
    def __init__(self):
        self.px = [[0.0, 0.0, 0.0] for _ in range(W * H)]

    def idx(self, x, y):
        return y * W + x

    def blend(self, x, y, rgb, a):
        if a <= 0 or not (0 <= x < W and 0 <= y < H):
            return
        p = self.px[y * W + x]
        a = min(1.0, a)
        p[0] += (rgb[0] - p[0]) * a
        p[1] += (rgb[1] - p[1]) * a
        p[2] += (rgb[2] - p[2]) * a

    def tile(self, sprite, x0, y0, x1, y1, ox=0, oy=0, alpha=1.0):
        for y in range(max(0, y0), min(H, y1)):
            row = sprite.px[(y - y0 + oy) % sprite.h]
            for x in range(max(0, x0), min(W, x1)):
                q = row[(x + ox) % sprite.w]
                if q[3]:
                    self.blend(x, y, q, alpha * q[3] / 255)

    def blit(self, sprite, cx, base, scale=1.0, tint=None, alpha=1.0):
        """Desen prins jos-centru; `scale` in pixeli de imagine pe pixel de desen (1 = ca in joc)."""
        w, h = max(1, round(sprite.w * scale)), max(1, round(sprite.h * scale))
        x0, y0 = round(cx - w / 2), round(base - h)
        for yy in range(h):
            row = sprite.px[min(sprite.h - 1, int(yy / scale))]
            for xx in range(w):
                q = row[min(sprite.w - 1, int(xx / scale))]
                if q[3]:
                    rgb = q if tint is None else (q[0] * tint[0] / 255, q[1] * tint[1] / 255, q[2] * tint[2] / 255)
                    self.blend(x0 + xx, y0 + yy, rgb, alpha * q[3] / 255)

    def save(self, path):
        rows = []
        for y in range(H):
            row = []
            for x in range(W):
                p = self.px[y * W + x]
                row.append((int(max(0, min(255, p[0]))), int(max(0, min(255, p[1]))), int(max(0, min(255, p[2]))), 255))
            rows.append(row)
        write_png(path, W, H, rows)


def gx(x):
    return (x - GX0) / D


def gy(y):
    return (y - GY0) / D


def bake(L, sizes, lights, trees, garlands):
    cv = Canvas()
    grass, water, shore = load_sprite("grass_tile"), load_sprite("water_tile"), load_sprite("shore_north")
    f, p = L["floor"], L["pond"]
    wy = int(gy(L["water_y"]))

    # iarba de noapte, cu pete mai inchise si mai deschise (fara ele, verdele e o suprafata moarta)
    cv.tile(grass, 0, 0, W, wy)
    for y in range(wy):
        for x in range(W):
            wx, wyy = GX0 + x * D, GY0 + y * D
            n = fbm(wx, wyy, 3)
            cv.blend(x, y, NIGHT, 0.56 + (n - 0.5) * 0.16)
    # raul de jos, cu malul lui
    cv.tile(water, 0, wy, W, H)
    for y in range(wy, H):
        for x in range(W):
            cv.blend(x, y, WATER, 0.80)
    cv.tile(shore, 0, wy - shore.h + 12, W, wy + 12, alpha=0.9)
    for y in range(wy - shore.h + 12, wy + 12):
        for x in range(W):
            cv.blend(x, y, NIGHT, 0.50)

    # drumurile batatorite care ies din poiana: la debarcader, la poarta satelor, la jetiul iazului
    def worn_path(points, width, alpha):
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            steps = int(math.hypot(bx - ax, by - ay) / 6) + 1
            for k in range(steps + 1):
                t = k / steps
                cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
                r = width / 2 * (0.8 + 0.4 * noise(cx, cy, 40, 9))
                for yy in range(int(gy(cy - r)), int(gy(cy + r)) + 1):
                    for xx in range(int(gx(cx - r)), int(gx(cx + r)) + 1):
                        dx, dy = GX0 + xx * D - cx, GY0 + yy * D - cy
                        d = math.hypot(dx, dy) / r
                        if d < 1:
                            cv.blend(xx, yy, DIRT_WORN, alpha * min(1, (1 - d) * 3))

    spawn = L["spawn"]
    worn_path([(spawn["x"], f["y"] + f["ry"] - 40), (spawn["x"] + 10, spawn["y"]), (spawn["x"], L["water_y"] - 10)], 96, 0.78)
    worn_path([(f["x"] - f["rx"] * 0.7, f["y"] + f["ry"] * 0.6), (386, 1250)], 84, 0.70)
    worn_path([(f["x"] - f["rx"] + 30, f["y"] + 30), (p["x"] + p["rx"] - 10, p["y"] + 20)], 70, 0.62)
    # [D61] spre baza jetiului, pe malul de sud al iazului
    worn_path([(f["x"] - f["rx"] * 0.55, f["y"] + f["ry"] * 0.62), (300, 990)], 72, 0.66)
    worn_path([(f["x"], f["y"] - f["ry"] + 40), (f["x"], 372)], 120, 0.46)
    worn_path([(f["x"] + f["rx"] - 40, f["y"] - 60), (1330, 700)], 80, 0.66)
    # [D61, partea 2] spre cortul croitoresei si, mai departe, spre taraba cu copertina aurie: ocoleste cortul prin fata
    tent = next(s for s in L["spots"] if s["id"] == "tent")
    shop = next((s for s in L["spots"] if s["id"] == "shop"), None)
    route = [(f["x"] + f["rx"] * 0.6, f["y"] + f["ry"] * 0.62), (tent["x"] - 104, tent["y"] + 20), (tent["x"] + 16, tent["y"] + 42)]
    if shop is not None:
        route.append((shop["x"], shop["y"] + 40))
    worn_path(route, 76, 0.66)

    # poiana: pamant batatorit cu marginea rupta (zgomot, nu compas) si iarba care intra peste ea
    for y in range(int(gy(f["y"] - f["ry"] - 60)), int(gy(f["y"] + f["ry"] + 60)) + 1):
        for x in range(int(gx(f["x"] - f["rx"] - 60)), int(gx(f["x"] + f["rx"] + 60)) + 1):
            wx, wyy = GX0 + x * D, GY0 + y * D
            q = ((wx - f["x"]) / f["rx"]) ** 2 + ((wyy - f["y"]) / f["ry"]) ** 2
            q += (fbm(wx, wyy, 5) - 0.5) * 0.34
            if q < 1:
                edge = min(1.0, (1 - q) * 4.0)  # marginea se stinge in iarba, nu se taie
                shade = 0.86 + (noise(wx, wyy, 22, 6) - 0.5) * 0.22
                col = (DIRT[0] * shade, DIRT[1] * shade, DIRT[2] * shade)
                cv.blend(x, y, col, 0.94 * edge)
    # vatra: inel de pamant ars in jurul focului. Fara pietre pe cerc: in Studio (2026-09-17) cele 26 de pietre de 2x2
    # pixeli se vedeau ca puncte gri presarate pe poiana, nu ca pietre; focul are pietrele lui in desen.
    fire = next(s for s in L["spots"] if s["sprite"] == "bonfire")
    for y in range(int(gy(fire["y"] - 190)), int(gy(fire["y"] + 150))):
        for x in range(int(gx(fire["x"] - 190)), int(gx(fire["x"] + 190))):
            wx, wyy = GX0 + x * D, GY0 + y * D
            q = math.hypot((wx - fire["x"]) / 170, (wyy - (fire["y"] - 20)) / 150)
            if q < 1:
                cv.blend(x, y, STONE, 0.42 * min(1, (1 - q) * 2.5))

    # paie, pamant calcat si pietricele pe poiana
    rnd = random.Random(21)
    for _ in range(1500):
        a = rnd.uniform(0, math.tau)
        rad = math.sqrt(rnd.random()) * 0.98
        sx, sy = f["x"] + math.cos(a) * f["rx"] * rad, f["y"] + math.sin(a) * f["ry"] * rad
        r0 = rnd.random()
        col = (92, 74, 52) if r0 < 0.45 else ((52, 42, 34) if r0 < 0.75 else (104, 88, 64))
        cv.blend(int(gx(sx)), int(gy(sy)), col, 0.55)
        if r0 < 0.3:
            cv.blend(int(gx(sx)) + 1, int(gy(sy)), col, 0.35)

    # iazul de concurs: apa inchisa, cu mal rupt si o dunga de nisip ud
    for y in range(int(gy(p["y"] - p["ry"] - 30)), int(gy(p["y"] + p["ry"] + 30)) + 1):
        for x in range(int(gx(p["x"] - p["rx"] - 30)), int(gx(p["x"] + p["rx"] + 30)) + 1):
            wx, wyy = GX0 + x * D, GY0 + y * D
            q = ((wx - p["x"]) / p["rx"]) ** 2 + ((wyy - p["y"]) / p["ry"]) ** 2 + (fbm(wx, wyy, 11) - 0.5) * 0.18
            if q < 1.18 and q >= 1:
                cv.blend(x, y, (58, 54, 44), 0.7)
            elif q < 1:
                wq = water.px[y % water.h][x % water.w]
                cv.blend(x, y, wq, 1.0)
                cv.blend(x, y, WATER, 0.78 + (1 - q) * 0.1)

    # iarba care intra peste marginea poienii si smocuri pe intuneric
    rnd = random.Random(1)
    for _ in range(3800):
        x = rnd.uniform(GX0, GX1)
        y = rnd.uniform(GY0, L["water_y"] - 20)
        q = ((x - f["x"]) / f["rx"]) ** 2 + ((y - f["y"]) / f["ry"]) ** 2
        if q < 0.93:
            continue
        if ((x - p["x"]) / p["rx"]) ** 2 + ((y - p["y"]) / p["ry"]) ** 2 < 1.2:
            continue
        tone = (46, 72, 48) if rnd.random() < 0.5 else (30, 50, 36)
        px_, py_ = int(gx(x)), int(gy(y))
        cv.blend(px_, py_, tone, 0.9)
        cv.blend(px_, py_ - 1, tone, 0.6)

    # umbrele de contact: sub obiecte si sub copaci
    def shadow(cx, base, w, strength=0.36):
        rx, ry = w * 0.42, max(6, w * 0.12)
        for yy in range(int(gy(base - ry)), int(gy(base + ry)) + 1):
            for xx in range(int(gx(cx - rx)), int(gx(cx + rx)) + 1):
                q = ((GX0 + xx * D - cx) / rx) ** 2 + ((GY0 + yy * D - base) / ry) ** 2
                if q < 1:
                    cv.blend(xx, yy, (6, 8, 14), strength * (1 - q))

    for s in L["spots"]:
        w, _h = sizes[s["sprite"]]
        if s["sprite"] in ("dock", "ferry", "reeds"):
            continue
        shadow(s["x"], s["y"] - 2, w * s["scale"])
    for t in trees:
        w, _h = sizes["props." + t["sprite"]]
        shadow(t["x"], t["y"] - 2, w * 3 * 0.9, 0.42)

    # stuf in plus pe malul iazului (nu se poate calca acolo, deci poate fi copt)
    reeds = load_sprite("prop_fair_reeds")
    for i in range(6):
        a = math.pi * (0.2 + i * 0.12)
        rx, ry = p["x"] + math.cos(a) * (p["rx"] + 6), p["y"] + math.sin(a) * (p["ry"] + 4)
        cv.blit(reeds, gx(rx), gy(ry), 1.0, (120, 140, 150))

    # baltile de lumina calda si becurile ghirlandelor
    for l in lights:
        glow_on(cv, l["x"], l["y"], l["r"], l["rgb"], l["strength"])
    for g in garlands:
        for b in g["bulbs"]:
            glow_on(cv, b["x"], b["y"] + 60, 46, (255, 206, 140), 0.22)

    # marginile hartii se scufunda in noapte: pe un ecran lat, padurea din afara e mai intunecata
    size = L["size"]
    for y in range(H):
        for x in range(W):
            wx, wyy = GX0 + x * D, GY0 + y * D
            out = max(0, -wx, wx - size["w"], -wyy) / 300
            if out > 0:
                cv.blend(x, y, NIGHT, min(0.7, out * 0.7))
    return cv


def glow_on(cv, cx, cy, r, rgb, strength):
    for y in range(int(gy(cy - r)), int(gy(cy + r)) + 1):
        for x in range(int(gx(cx - r)), int(gx(cx + r)) + 1):
            wx, wyy = GX0 + x * D, GY0 + y * D
            q = math.hypot(wx - cx, (wyy - cy) * 1.35) / r
            if q < 1:
                cv.blend(x, y, rgb, strength * (1 - q) ** 2.1)


_cache = {}


def load_sprite(name):
    if name not in _cache:
        _cache[name] = Sprite(*load(name))
    return _cache[name]


class Sprite:
    def __init__(self, w, h, px):
        self.w, self.h, self.px = w, h, px


def lit_tint(lights, x, y, cold=COLD):
    """Aceeasi socoteala ca FairScene.LitTint: langa lumina e cald, departe e rece."""
    best = 0.0
    for l in lights:
        q = math.hypot(x - l["x"], (y - l["y"]) * 1.3) / l["r"]
        if q < 1:
            best = max(best, l["strength"] * (1 - q) ** 1.5)
    t = min(1.0, best * 1.7)
    return tuple(int(cold[i] + (LIT[i] - cold[i]) * t) for i in range(3))


def glow_sprite(path, size=64):
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            q = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            a = 0 if q >= 1 else (1 - q) ** 2
            row.append((255, 255, 255, int(round(a * 255))))
        rows.append(row)
    write_png(path, size, size, rows)


# ---- datele pentru joc ------------------------------------------------------------------------------------------
def lua_color(c):
    return f"{{ {c[0]}, {c[1]}, {c[2]} }}"


def write_scenery(lights, fires, lamps, trees, garlands):
    lines = [
        "--!strict",
        "-- [D60] GENERAT de scripts/art/d60_ground.py -- nu edita de mana: ruleaza scriptul (el coace si fundalul din",
        "-- aceleasi date). Ce se aseaza peste fundalul copt al balciului (Assets.fair.ground): luminile care coloreaza",
        "-- obiectele, focurile care palpaie si scot scantei, copacii din jur, ghirlandele cu becurile lor, capetele",
        "-- felinarelor. Coordonatele sunt ale lumii balciului (FairLayout); `y` e baza, ca peste tot.",
        "local FairScenery = {}",
        "",
        "export type Light = { x: number, y: number, r: number, strength: number }",
        "export type Fire = { x: number, y: number, size: number, sparks: number }",
        "export type Lamp = { x: number, y: number, base: number }",
        "export type Tree = { sprite: string, x: number, y: number }",
        "export type Bulb = { x: number, y: number, color: { number } }",
        "export type Garland = { ax: number, ay: number, bx: number, by: number, sag: number, bulbs: { Bulb } }",
        "",
        "-- unde sta fundalul copt (1 pixel de imagine = 3 de lume): harta plus padure pe margini",
        f"FairScenery.GROUND = {{ x = {GX0}, y = {GY0}, w = {GX1 - GX0}, h = {GY1 - GY0} }}",
        "",
        "FairScenery.LIGHTS = {",
    ]
    for l in lights:
        lines.append(f"    {{ x = {round(l['x'])}, y = {round(l['y'])}, r = {l['r']}, strength = {l['strength']} }},")
    lines += ["} :: { Light }", "", "FairScenery.FIRES = {"]
    for fi in fires:
        lines.append(f"    {{ x = {fi['x']}, y = {fi['y']}, size = {fi['size']}, sparks = {fi['sparks']} }},")
    lines += ["} :: { Fire }", "", "FairScenery.LAMPS = {"]
    for la in lamps:
        lines.append(f"    {{ x = {la['x']}, y = {la['y']}, base = {la['base']} }},")
    lines += ["} :: { Lamp }", "", "FairScenery.TREES = {"]
    for t in trees:
        lines.append(f'    {{ sprite = "{t["sprite"]}", x = {t["x"]}, y = {t["y"]} }},')
    lines += ["} :: { Tree }", "", "FairScenery.GARLANDS = {"]
    for g in garlands:
        lines.append(
            f"    {{\n        ax = {g['ax']},\n        ay = {g['ay']},\n        bx = {g['bx']},\n        by = {g['by']},"
            f"\n        sag = {g['sag']},\n        bulbs = {{"
        )
        for b in g["bulbs"]:
            lines.append(f"            {{ x = {b['x']}, y = {b['y']}, color = {lua_color(b['color'])} }},")
        lines.append("        },\n    },")
    lines += ["} :: { Garland }", "", "return FairScenery", ""]
    open(SCENERY, "w").write("\n".join(lines))
    # formatat ca restul codului, ca poarta (stylua --check) sa treaca pe fisierul generat
    try:
        import subprocess

        subprocess.run(["stylua", SCENERY], check=False)
    except FileNotFoundError:
        print("atentie: stylua lipseste, FairScenery.luau ramane neformatat")
    print(f"scris {SCENERY}: {len(lights)} lumini, {len(fires)} focuri, {len(trees)} copaci, {len(garlands)} ghirlande")


# ---- previzualizarea: cum arata in joc ----------------------------------------------------------------------------
def preview(path, L, sizes, lights, trees, garlands, ground_path, view=(10, 180, 1610, 1080), d=1):
    import struct
    import zlib

    gw, gh, gpx = load_path(ground_path)
    x0, y0, x1, y1 = view
    vw, vh = (x1 - x0) // d, (y1 - y0) // d
    img = [[list(NIGHT) for _ in range(vw)] for _ in range(vh)]

    def put(px, py, rgb, a):
        if 0 <= px < vw and 0 <= py < vh and a > 0:
            q = img[py][px]
            for i in range(3):
                q[i] += (rgb[i] - q[i]) * min(1, a)

    # fundalul, marit de 3 ori
    for py in range(vh):
        wy_ = y0 + py * d
        gyy = int((wy_ - GY0) // D)
        if not (0 <= gyy < gh):
            continue
        for px in range(vw):
            wx_ = x0 + px * d
            gxx = int((wx_ - GX0) // D)
            if 0 <= gxx < gw:
                q = gpx[gyy][gxx]
                img[py][px] = [q[0], q[1], q[2]]

    def sprite_at(name, cx, base, scale, tint, alpha=1.0):
        s = load_sprite(name)
        w, h = s.w * scale, s.h * scale
        for yy in range(int(h / d)):
            row = s.px[min(s.h - 1, int(yy * d / scale))]
            for xx in range(int(w / d)):
                q = row[min(s.w - 1, int(xx * d / scale))]
                if q[3]:
                    rgb = (q[0] * tint[0] / 255, q[1] * tint[1] / 255, q[2] * tint[2] / 255)
                    put(int((cx - w / 2 - x0) / d) + xx, int((base - h - y0) / d) + yy, rgb, alpha * q[3] / 255)

    items = []
    for s in L["spots"]:
        items.append((s["y"], "prop_fair_" + s["sprite"], s["x"], s["scale"], lit_tint(lights, s["x"], s["y"])))
    for t in trees:
        items.append((t["y"], "prop_" + t["sprite"], t["x"], 3, lit_tint(lights, t["x"], t["y"], TREE_COLD)))
    for base, name, x, scale, tint in sorted(items):
        sprite_at(name, x, base, scale, tint)

    # ghirlandele: firul si becurile, cu o aura mica
    for g in garlands:
        pts = [(g["ax"], g["ay"])] + [(b["x"], b["y"]) for b in g["bulbs"]] + [(g["bx"], g["by"])]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            steps = int(math.hypot(bx - ax, by - ay))
            for k in range(steps):
                t = k / max(1, steps)
                put(int((ax + (bx - ax) * t - x0) / d), int((ay + (by - ay) * t - y0) / d), (30, 24, 20), 0.8)
        for b in g["bulbs"]:
            for yy in range(-10, 11):
                for xx in range(-10, 11):
                    q = math.hypot(xx, yy) / 10
                    if q < 1:
                        put(int((b["x"] - x0) / d) + xx, int((b["y"] - y0) / d) + yy, b["color"], 0.35 * (1 - q) ** 2)
            for yy in range(-2, 3):
                for xx in range(-2, 3):
                    put(int((b["x"] - x0) / d) + xx, int((b["y"] - y0) / d) + yy, b["color"], 1.0)

    # scantei deasupra focului
    rnd = random.Random(21)
    fire = next(s for s in L["spots"] if s["sprite"] == "bonfire")
    for _ in range(60):
        a = rnd.uniform(0, math.tau)
        rad = rnd.uniform(10, 150)
        sx, sy = fire["x"] + math.cos(a) * rad * 0.6, fire["y"] - 90 - abs(math.sin(a)) * rad
        col = (255, 196, 120) if rnd.random() < 0.6 else (255, 148, 80)
        put(int((sx - x0) / d), int((sy - y0) / d), col, 1.0)
        put(int((sx - x0) / d) + 1, int((sy - y0) / d), col, 0.8)

    rows = [[(int(max(0, min(255, q[0]))), int(max(0, min(255, q[1]))), int(max(0, min(255, q[2]))), 255) for q in r] for r in img]
    write_png(path, vw, vh, rows)
    print(f"scris {path} ({vw}x{vh})")


def load_path(path):
    import struct
    import zlib

    d = open(path, "rb").read()
    pos, w, h, idat = 8, 0, 0, b""
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos + 4])[0]
        typ = d[pos + 4:pos + 8]
        body = d[pos + 8:pos + 8 + ln]
        if typ == b"IHDR":
            w, h = struct.unpack(">II", body[:8])
        elif typ == b"IDAT":
            idat += body
        pos += 12 + ln
    raw = zlib.decompress(idat)
    rows, prev, i, bpp = [], bytearray(w * 4), 0, 4
    for _ in range(h):
        f = raw[i]
        i += 1
        line = bytearray(raw[i:i + w * bpp])
        i += w * bpp
        for x in range(len(line)):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append([tuple(line[k:k + 4]) for k in range(0, len(line), 4)])
        prev = line
    return w, h, rows


def main():
    L = read_layout()
    sizes = read_sizes()
    lights = build_lights(L)
    fires = build_fires(L)
    lamps = build_lamps(L, sizes)
    garlands = build_garlands(L, sizes, lamps)
    labels = label_boxes(L, sizes)
    trees = build_trees(L, sizes, labels)
    ground_path = os.path.join(SPRITES, "prop_fair_ground.png")
    cv = bake(L, sizes, lights, trees, garlands)
    cv.save(ground_path)
    print(f"scris {ground_path} ({W}x{H})")
    glow_sprite(os.path.join(SPRITES, "prop_fair_glow.png"))
    write_scenery(lights, fires, lamps, trees, garlands)
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        preview(out, L, sizes, lights, trees, garlands, ground_path)
        south = out.replace(".png", "_sud.png")
        preview(south, L, sizes, lights, trees, garlands, ground_path, view=(10, 820, 1610, 1720))


if __name__ == "__main__":
    main()
