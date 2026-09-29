#!/usr/bin/env python3
"""[D62, pasul 5] PAMANTUL SATULUI, COPT INTR-O SINGURA IMAGINE.

De ce: harta satului e facuta din dale repetate si din `Frame`-uri (iarba dintr-un tile de 384 px, padurea din
discuri plate, drumurile din fasii cu muchii drepte, adancimea apei dintr-o banda dreapta). Balciul a aratat "super
cheap" din acelasi motiv si s-a reparat cu o singura imagine coapta (d60_ground.py). Aici e acelasi lucru pentru sat.

Ce iese: assets/sprites/prop_village_ground.png, 960x640 (un pixel de imagine = 3 pixeli de lume, ca toata arta), cu
ALFA:
  * uscatul e opac: iarba in pete de lumina, padurea de pe malul de nord, plajele cu nisip ud, malul amenajat din
    dreptul puntii, puntea, curtile, drumurile cu fagase, piata de piatra, cararile calcate intre case;
  * apa e transparenta, ca raul animat al jocului sa curga pe dedesubt; peste ea stau doar tente: apa mica, deschisa,
    langa maluri si canalul adanc la mijloc, amandoua dupa forma adevarata a malurilor.

Geometria NU e copiata aici: o scoate `village_geometry.luau` din modulele jocului (Shoreline, TycoonConfig,
WorldDecor). Puntea si piata folosesc dalele aprobate deja (deck_tile, tile_plaza).

Ruleaza-l din nou dupa orice mutare in TycoonConfig (DECK, ROADS, YARDS, DECOR) sau in malurile din RiverConfig.
Ca sa nu ramana la tinut minte: la fiecare coacere scrie amprenta geometriei in `village_ground.lock`, iar `--check`
(in poarta si in CI) pica daca geometria jocului nu mai e cea din care s-a copt imaginea. Dupa o recoacere, imaginea
trebuie si urcata din nou (python3 scripts/upload_assets.py prop_village_ground), cu acordul owner-ului.

Rulare: python3 scripts/art/village_ground.py [--preview cale.png] [--zoom cale.png x y]
        python3 scripts/art/village_ground.py --check
"""
import hashlib
import json
import math
import os
import random
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from preview_tycoon import load, write_png  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SPRITES = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(SPRITES, "prop_village_ground.png")


def tile_paths(G):
    """[D65] Feliile pamantului copt: Roblox micsoreaza orice imagine peste 1024 px, deci lumea (3840 / 3 = 1280 px) se
    coace pe felii de `tile` pixeli de lume (2880 -> 960 px). Prima isi tine numele de dinainte, urmatoarele primesc
    numarul lor: prop_village_ground.png, prop_village_ground_2.png. Intoarce [(cale, x0, latime)] in pixeli de imagine."""
    tile = G["tile"] // D
    total = G["world"]["w"] // D
    out, x0, k = [], 0, 1
    while x0 < total:
        name = "prop_village_ground.png" if k == 1 else f"prop_village_ground_{k}.png"
        out.append((os.path.join(SPRITES, name), x0, min(tile, total - x0)))
        x0 += tile
        k += 1
    return out
LOCK = os.path.join(HERE, "village_ground.lock")

D = 3
BAYER = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))

# ---- paleta: aceeasi familie ca dalele urcate (grass_tile 90,133,74; path_tile 133,106,80; sand_tile 212,200,150) ---
GRASS = ((62, 98, 56), (76, 116, 64), (90, 133, 74), (102, 148, 84), (118, 164, 94))
GRASS_BLADE_DARK = (58, 92, 50)
GRASS_BLADE_LIGHT = (134, 182, 108)
DIRT = ((98, 76, 56), (112, 88, 64), (126, 100, 74), (138, 112, 84), (152, 126, 96))
DIRT_RUT = (88, 68, 50)
DIRT_RIM = (84, 70, 48)
SAND = ((176, 160, 118), (198, 184, 136), (212, 200, 150), (226, 216, 168))
SAND_WET = ((120, 122, 110), (148, 142, 118))
STONE = ((92, 88, 84), (124, 118, 110), (156, 150, 138))
FOREST_FLOOR = (24, 44, 34)
CROWNS = (
    ((20, 38, 32), (30, 54, 38), (40, 70, 44), (54, 90, 54), (74, 114, 66)),  # foioase
    ((16, 34, 34), (24, 48, 42), (32, 62, 50), (44, 80, 60), (60, 102, 74)),  # brazi: mai reci, mai inchisi
    ((26, 42, 30), (40, 62, 36), (56, 84, 44), (76, 108, 54), (102, 134, 68)),  # mesteceni: spre galben
)
TIMBER = ((58, 46, 40), (96, 78, 60), (118, 96, 74), (142, 120, 94))
SHALLOW = (128, 196, 204)
DEEP = (8, 30, 58)
BANK_SHADE = (16, 40, 66)

MAT_WATER, MAT_GRASS, MAT_SAND, MAT_DIRT, MAT_BUILT, MAT_FOREST = 0, 1, 2, 3, 4, 5


# ---- zgomot cu retea tinuta minte: acelasi tip ca in d60_ground, dar de ~4 ori mai iute pe 600.000 de pixeli -------
class Noise:
    def __init__(self, seed):
        self.seed = seed
        self.cache = {}

    def _h(self, ix, iy):
        key = (ix, iy)
        v = self.cache.get(key)
        if v is None:
            n = (ix * 374761393 + iy * 668265263 + self.seed * 2147483647) & 0xFFFFFFFF
            n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
            v = ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
            self.cache[key] = v
        return v

    def at(self, x, y, scale):
        gx, gy = x / scale, y / scale
        ix, iy = math.floor(gx), math.floor(gy)
        fx, fy = gx - ix, gy - iy
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        a = self._h(ix, iy)
        a += (self._h(ix + 1, iy) - a) * sx
        b = self._h(ix, iy + 1)
        b += (self._h(ix + 1, iy + 1) - b) * sx
        return a + (b - a) * sy


def hash01(x, y, salt=0):
    n = (x * 73856093 ^ y * 19349663 ^ salt * 83492791) & 0xFFFFFFFF
    n = ((n ^ (n >> 15)) * 2246822519) & 0xFFFFFFFF
    return ((n ^ (n >> 13)) & 0xFFFF) / 65535.0


def dither(ix, iy):
    return (BAYER[iy & 3][ix & 3] + 0.5) / 16.0


def geometry():
    res = subprocess.run(
        ["lune", "run", os.path.join("scripts", "art", "village_geometry")],
        cwd=ROOT, capture_output=True, text=True,
    )
    if res.returncode != 0:
        sys.exit("village_geometry a picat:\n" + res.stderr)
    return json.loads(res.stdout)


def fingerprint(G):
    """Amprenta geometriei: JSON canonic, cu zecimalele rotunjite (un ultim bit diferit intre doua masini nu e o
    mutare pe harta)."""
    def canon(v):
        if isinstance(v, float):
            return round(v, 2)
        if isinstance(v, list):
            return [canon(x) for x in v]
        if isinstance(v, dict):
            return {k: canon(x) for k, x in v.items()}
        return v

    return hashlib.sha256(json.dumps(canon(G), sort_keys=True).encode()).hexdigest()


def check(G):
    problems = []
    try:
        locked = open(LOCK).read().strip()
    except FileNotFoundError:
        locked = ""
    if locked != fingerprint(G):
        problems.append(
            "geometria satului (maluri, punte, drumuri, curti, decor) s-a schimbat de la ultima coacere a pamantului"
        )
    # Marimea se citeste direct din antetul PNG (IHDR), cu calea relativa la repo: `preview_tycoon.load` are scrisa in el
    # calea de pe Mac-ul owner-ului, iar verificarea asta ruleaza si in CI.
    for path, _x0, width in tile_paths(G):
        name = os.path.basename(path)
        try:
            with open(path, "rb") as f:
                head = f.read(24)
            w, h = struct.unpack(">II", head[16:24])
            if (w, h) != (width, G["world"]["h"] // D):
                problems.append(f"{name} are {w}x{h}, nu {width}x{G['world']['h'] // D}")
        except (FileNotFoundError, struct.error):
            problems.append(f"lipseste assets/sprites/{name}")
    if problems:
        print("village_ground: " + "; ".join(problems))
        print("  -> ruleaza: python3 scripts/art/village_ground.py   (apoi imaginea trebuie urcata din nou)")
        sys.exit(1)
    print("village_ground: imaginea coapta e la zi cu harta")


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = [[0.0, 0.0, 0.0] for _ in range(w * h)]
        self.a = [0.0] * (w * h)
        self.mat = [MAT_WATER] * (w * h)

    def inside(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def set(self, x, y, rgb, mat=None):
        if not self.inside(x, y):
            return
        i = y * self.w + x
        p = self.rgb[i]
        p[0], p[1], p[2] = rgb[0], rgb[1], rgb[2]
        self.a[i] = 1.0
        if mat is not None:
            self.mat[i] = mat

    def blend(self, x, y, rgb, alpha):
        """Peste uscat amesteca culoarea; peste apa (alfa < 1) compune o tenta translucida."""
        if alpha <= 0 or not self.inside(x, y):
            return
        i = y * self.w + x
        alpha = min(1.0, alpha)
        a0 = self.a[i]
        p = self.rgb[i]
        if a0 >= 1.0:
            p[0] += (rgb[0] - p[0]) * alpha
            p[1] += (rgb[1] - p[1]) * alpha
            p[2] += (rgb[2] - p[2]) * alpha
            return
        out = alpha + a0 * (1 - alpha)
        for k in range(3):
            p[k] = (rgb[k] * alpha + p[k] * a0 * (1 - alpha)) / out
        self.a[i] = out

    def rows(self):
        out = []
        for y in range(self.h):
            row = []
            for x in range(self.w):
                i = y * self.w + x
                p = self.rgb[i]
                row.append((
                    int(max(0, min(255, round(p[0])))), int(max(0, min(255, round(p[1])))),
                    int(max(0, min(255, round(p[2])))), int(max(0, min(255, round(self.a[i] * 255)))),
                ))
            out.append(row)
        return out


def ramp_pick(ramp, v, ix, iy, spread=0.9):
    """Treapta din rampa pentru valoarea v (0..1), cu trecerile intre trepte facute din puncte (Bayer), nu din
    degradeuri: asa arata o umbra pictata in pixeli."""
    n = len(ramp)
    k = int(v * n + (dither(ix, iy) - 0.5) * spread)
    return ramp[max(0, min(n - 1, k))]


def rounded_sdf(wx, wy, r, radius):
    """Distanta cu semn pana la un dreptunghi cu colturi rotunjite (negativ = inauntru), in pixeli de lume."""
    cx, cy = (r["x0"] + r["x1"]) / 2, (r["y0"] + r["y1"]) / 2
    hx, hy = (r["x1"] - r["x0"]) / 2 - radius, (r["y1"] - r["y0"]) / 2 - radius
    qx, qy = abs(wx - cx) - hx, abs(wy - cy) - hy
    return math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0) - radius


def bake(G):
    W, H = G["world"]["w"] // D, G["world"]["h"] // D
    cv = Canvas(W, H)
    far, near = G["far"], G["near"]
    tree = G["treeLine"]
    # [D65] LUMEA S-A LATIT, DAR SATUL VECHI NU SE MISCA. Tot ce se imprastie la intamplare (pietricele, coroanele
    # padurii, smocuri, flori) isi alegea locul ca `aleator x latime`, deci o lume mai lata ar fi mutat fiecare pixel al
    # partii deja aprobate si urcate. De aceea fiecare imprastiere se face in doi timpi: intai pe latimea veche, cu
    # aceeasi samanta si acelasi numar (iese exact ca inainte), apoi pe fasia noua, cu samanta ei.
    W_OLD = min(W, G["tile"] // D)
    # [D67] si fasiile de dupa satul vechi, fiecare cu marginea ei (Moara pana la 1280, Wire Works pana la capat): fasia
    # k isi imprastie lucrurile cu samanta ei, ca latirea lumii sa nu mute smocurile si pietricelele Morii.
    STRIP_ENDS = [min(W, x1 // D) for x1 in G.get("strips", [W * D])]

    def strips(base_seed, old_share):
        """(samanta, x_from, x_to, parte) pentru satul vechi si pentru fiecare fasie; prima fasie are samanta de
        dinainte de D67 (`base_seed`), urmatoarele cate una noua."""
        out, x0 = [], W_OLD
        for k, x1 in enumerate(STRIP_ENDS):
            if x1 > x0:
                out.append((base_seed + 100 * k, x0, x1, (x1 - x0) / W_OLD * old_share))
            x0 = max(x0, x1)
        return out
    n_tone, n_mid, n_fine, n_edge = Noise(11), Noise(12), Noise(13), Noise(14)

    def world(ix, iy):
        return ix * D + D / 2, iy * D + D / 2

    # ---- 1. iarba: pete mari de lumina si umbra, in cinci trepte -------------------------------------------------
    for iy in range(H):
        for ix in range(W):
            wx, wy = world(ix, iy)
            if far["y"][ix] <= wy <= near["y"][ix]:
                continue
            v = 0.52 * n_tone.at(wx, wy, 430) + 0.32 * n_mid.at(wx, wy, 150) + 0.16 * n_fine.at(wx, wy, 46)
            v = (v - 0.5) * 2.3 + 0.5
            # malul de nord sta in umbra padurii: cu cat mai aproape de copaci, cu atat mai inchis
            if wy < far["y"][ix]:
                shade = 1 - min(1.0, max(0.0, (wy - tree[ix]) / 70))
                v -= 0.34 * shade
            col = ramp_pick(GRASS, max(0.0, min(0.999, v)), ix, iy)
            h = hash01(ix, iy, 1)
            if h < 0.014:
                col = GRASS_BLADE_DARK
            elif h > 0.988:
                col = GRASS_BLADE_LIGHT
            cv.set(ix, iy, col, MAT_GRASS)

    # ---- 2. plajele: nisip uscat spre iarba, ud langa apa; unde nu e plaja, mal de pamant ---------------------
    for ix in range(W):
        for side, edge in ((-1, far), (1, near)):
            ey, width = edge["y"][ix], edge["beach"][ix]
            wx = ix * D + D / 2
            width *= 0.8 + 0.4 * n_edge.at(wx, 0 if side < 0 else 999, 70)
            reach = int(max(width, 8) / D) + 3
            y_edge = int(ey // D)
            for k in range(reach):
                iy = y_edge - k - 1 if side < 0 else y_edge + k + 1
                if not cv.inside(ix, iy) or cv.mat[iy * W + ix] == MAT_WATER:
                    continue
                wy = iy * D + D / 2
                dw = (ey - wy) if side < 0 else (wy - ey)
                if width < 6:
                    if dw < 5:
                        cv.set(ix, iy, DIRT_RIM if dw < 3 else DIRT[0], MAT_DIRT)
                    continue
                t = dw / width
                if t > 1 or (t > 0.72 and hash01(ix, iy, 31) < (t - 0.72) / 0.28):
                    continue
                if dw < 4:
                    col = SAND_WET[0]
                elif dw < 10:
                    col = SAND_WET[1] if dither(ix, iy) < 0.6 else SAND[0]
                else:
                    col = ramp_pick(SAND, 0.35 + 0.6 * n_fine.at(wx, wy, 40), ix, iy, 1.4)
                cv.set(ix, iy, col, MAT_SAND)

    # pietricele pe plaje, cu umbra lor dedesubt
    # [D65] FIECARE INCERCARE ARE ZARUL EI (`each_try`): pana acum un singur sir de numere trecea prin toate, iar o
    # incercare respinsa tragea mai putine numere decat una primita. Un drum nou la Moara respingea cateva si muta
    # astfel TOATE pietricelele si smocurile de dupa ele, inclusiv din satul vechi (567 de pixeli la prima coacere cu
    # Moara). Asa, ce se schimba intr-un cartier nu mai atinge nimic din celelalte.
    def each_try(seed, tries):
        for k in range(tries):
            yield random.Random(seed * 1000003 + k)

    for seed, x_from, x_to, tries in [(62, 0, W_OLD, 900)] + [
        (seed, x_from, x_to, 900 * (x_to - x_from) // W_OLD) for seed, x_from, x_to, _share in strips(6202, 1.0)
    ]:
        for rnd in each_try(seed, tries):
            ix, iy = x_from + rnd.randrange(x_to - x_from), rnd.randrange(H)
            if cv.mat[iy * W + ix] != MAT_SAND or not cv.inside(ix + 1, iy + 1):
                continue
            tone = STONE[rnd.randrange(1, 3)]
            cv.set(ix, iy, tone)
            if rnd.random() < 0.5 and cv.mat[iy * W + ix + 1] == MAT_SAND:
                cv.set(ix + 1, iy, STONE[1])
            if cv.mat[(iy + 1) * W + ix] == MAT_SAND:
                cv.blend(ix, iy + 1, STONE[0], 0.55)

    # ---- 3. padurea de pe malul de nord: podea intunecata, apoi coroane pe randuri, cu lumina din stanga-sus ----
    for ix in range(W):
        wx = ix * D + D / 2
        limit = tree[ix] + (n_edge.at(wx, 40, 36) - 0.5) * 30
        for iy in range(int(limit // D) + 1):
            if cv.mat[iy * W + ix] != MAT_WATER:
                cv.set(ix, iy, FOREST_FLOOR, MAT_FOREST)

    def crown(cx, cy, r, salt, ramp):
        """O coroana: disc cu marginea rupta, cinci trepte de verde, mai deschise spre stanga-sus."""
        r_i = int(r) + 2
        for yy in range(-r_i, r_i + 1):
            for xx in range(-r_i, r_i + 1):
                ix, iy = int(cx) + xx, int(cy) + yy
                if not cv.inside(ix, iy) or cv.mat[iy * W + ix] == MAT_WATER:
                    continue
                wob = 1 + (n_fine.at(ix * 5.0 + salt, iy * 5.0, 22) - 0.5) * 0.5
                d = math.hypot(xx, yy * 1.12) / (r * wob)
                if d > 1:
                    continue
                lit = (-xx * 0.62 - yy * 0.78) / r  # -1 (jos-dreapta) .. 1 (sus-stanga)
                v = 0.46 + lit * 0.44 - d * d * 0.22 + (hash01(ix, iy, salt) - 0.5) * 0.14
                if d > 0.86 and yy > 0:
                    v = 0.0  # muchia de jos, inchisa: desparte coroana de cea de sub ea
                cv.set(ix, iy, ramp_pick(ramp, max(0.0, min(0.999, v)), ix, iy, 0.7), MAT_FOREST)

    # coroanele: intai toate randurile pe latimea veche, cu un singur generator (exact ca inainte de D65), tinand minte
    # unde s-a oprit fiecare rand; apoi fiecare rand continua pe fasia noua, cu generatorul lui. Randurile se deseneaza
    # tot de sus in jos, deci cele doua treceri se aduna in aceeasi lista si se deseneaza o data.
    rows = 9
    planned = {row: [] for row in range(rows + 1)}
    stopped = {}
    rnd = random.Random(480917)
    for row in range(rows, -1, -1):
        cx = -6.0 - (row % 2) * 5
        while cx < W_OLD + 8:
            planned[row].append((cx, rnd.uniform(8.0, 16.0), rnd.uniform(0, 6), rnd.random()))
            cx += rnd.uniform(11, 19)
        stopped[row] = cx
    for row in range(rows, -1, -1):
        rnd = random.Random(480917 + 1000 + row)
        cx = stopped[row]
        while cx < W + 8:
            planned[row].append((cx, rnd.uniform(8.0, 16.0), rnd.uniform(0, 6), rnd.random()))
            cx += rnd.uniform(11, 19)
    for row in range(rows, -1, -1):  # de sus in jos: randul de jos se deseneaza ultimul, peste celelalte
        for cx, size, drop, kind in planned[row]:
            ix = max(0, min(W - 1, int(cx)))
            base = tree[ix] / D
            r = size - row * 0.3
            cy = base - row * 11.5 - drop + 2
            ramp = CROWNS[0] if kind < 0.62 else (CROWNS[1] if kind < 0.88 else CROWNS[2])
            if cy > -r:
                crown(cx, cy, r, row * 131 + int(cx), ramp)

    # luminisuri: decorul imprastiat din seed cade si in padure, iar o piatra pe coroane n-are cum sa stea
    for item in G["scattered"]:
        if item["kind"] in ("tree_pine", "tree_round", "bush"):
            continue
        ix0 = max(0, min(W - 1, int(item["x"] // D)))
        if item["y"] > tree[ix0] + 24:
            continue
        rx, ry = 40, 24
        cx, cy = item["x"], item["y"] - 8
        for iy in range(int((cy - ry - 6) // D), int((cy + ry + 6) // D) + 1):
            for ix in range(int((cx - rx - 6) // D), int((cx + rx + 6) // D) + 1):
                if not cv.inside(ix, iy) or cv.mat[iy * W + ix] != MAT_FOREST:
                    continue
                wx, wy = world(ix, iy)
                q = ((wx - cx) / rx) ** 2 + ((wy - cy) / ry) ** 2 + (n_fine.at(wx, wy, 18) - 0.5) * 0.5
                if q < 1:
                    shade = GRASS[0] if q > 0.55 or wy < cy - 6 else GRASS[1]
                    cv.set(ix, iy, shade if hash01(ix, iy, 4) > 0.05 else GRASS_BLADE_DARK, MAT_GRASS)

    # umbra padurii pe iarba de sub ea
    for ix in range(W):
        y0 = int(tree[ix] // D)
        for k in range(1, 9):
            iy = y0 + k + 3
            if cv.inside(ix, iy) and cv.mat[iy * W + ix] == MAT_GRASS:
                cv.blend(ix, iy, (18, 36, 30), 0.30 * (1 - k / 9))

    # ---- 4. pamantul batatorit: curtile, apoi drumurile peste ele ---------------------------------------------
    def dirt_area(r, radius, ragged, darker, ruts=None, flavour=None):
        pad = 14
        for iy in range(int((r["y0"] - pad) // D), int((r["y1"] + pad) // D) + 1):
            for ix in range(int((r["x0"] - pad) // D), int((r["x1"] + pad) // D) + 1):
                if not cv.inside(ix, iy) or cv.mat[iy * W + ix] in (MAT_WATER, MAT_BUILT):
                    continue
                wx, wy = world(ix, iy)
                d = rounded_sdf(wx, wy, r, radius)
                d += (n_edge.at(wx, wy, 34) - 0.5) * ragged + (n_fine.at(wx, wy, 11) - 0.5) * ragged * 0.4
                if d > 0:
                    if d < 6 and hash01(ix, iy, 7) < 0.16:
                        cv.set(ix, iy, DIRT[1], MAT_DIRT)  # pamant scapat in iarba
                    continue
                if d > -7 and hash01(ix, iy, 8) < 0.30:
                    continue  # iarba intra peste margine
                v = 0.30 + 0.55 * n_mid.at(wx, wy, 90) + 0.25 * (n_fine.at(wx, wy, 20) - 0.5) - darker
                v += min(0.0, (d + 16) / 60)  # spre mijloc e mai calcat, deci mai deschis; la margine mai inchis
                col = DIRT_RIM if d > -3 else ramp_pick(DIRT, max(0.0, min(0.999, v)), ix, iy, 1.1)
                if ruts is not None:
                    axis, centre, half = ruts
                    off = abs((wy if axis == "h" else wx) - centre)
                    along = wx if axis == "h" else wy
                    if abs(off - half) < 2.4 and n_fine.at(along, centre, 52) > 0.34:
                        col = DIRT_RUT
                h = hash01(ix, iy, 9)
                if flavour == "sawmill" and h < 0.06:
                    col = (204, 178, 128)  # rumegus
                elif flavour == "forge" and h < 0.07:
                    col = (66, 58, 54)  # zgura si cenusa
                elif h < 0.018:
                    col = STONE[1]
                elif h > 0.985:
                    col = DIRT[4]
                cv.set(ix, iy, col, MAT_DIRT)

    all_yards = [y for dist in G["districts"] for y in dist["yards"]]
    all_roads = [r for dist in G["districts"] for r in dist["roads"]]
    for yard in all_yards:
        dirt_area(yard, 16, 12, 0.0, None, yard["id"])
    for road in all_roads:
        wide = (road["x1"] - road["x0"]) >= (road["y1"] - road["y0"])
        if wide:
            ruts = ("h", (road["y0"] + road["y1"]) / 2, (road["y1"] - road["y0"]) * 0.24)
        else:
            ruts = ("v", (road["x0"] + road["x1"]) / 2, (road["x1"] - road["x0"]) * 0.24)
        dirt_area(road, 8, 10, 0.10, None if road["id"] == "plaza" else ruts)

    # cararile calcate: nu sunt drumuri (pe ele nu merge niciun om al satului), doar iarba roasa pe unde ai trece tu
    def worn(points, width, strength):
        for (ax, ay), (bx, by) in zip(points, points[1:]):
            steps = int(math.hypot(bx - ax, by - ay) / 4) + 1
            for k in range(steps + 1):
                t = k / steps
                cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
                cx += (n_edge.at(cx, cy, 120) - 0.5) * 16
                r = width / 2 * (0.75 + 0.5 * n_mid.at(cx, cy, 60))
                for iy in range(int((cy - r) // D), int((cy + r) // D) + 1):
                    for ix in range(int((cx - r) // D), int((cx + r) // D) + 1):
                        if not cv.inside(ix, iy) or cv.mat[iy * W + ix] != MAT_GRASS:
                            continue
                        wx, wy = world(ix, iy)
                        q = math.hypot(wx - cx, wy - cy) / r
                        if q < 1 and hash01(ix, iy, 17) < strength * (1 - q * q) * 1.9:
                            cv.set(ix, iy, ramp_pick(DIRT, 0.25 + 0.4 * n_fine.at(wx, wy, 24), ix, iy), MAT_DIRT)

    # [D65] o data pe CARTIER: id-urile curtilor si ale drumurilor vin canonice (cele din The Landing), deci Moara isi
    # primeste aceleasi poteci intre case, spre taraba negustorului si spre clopot
    def district_paths(dist):
        yards = {y["id"]: y for y in dist["yards"]}
        street = next(r for r in dist["roads"] if r["id"] == "street")
        houses = [y for y in dist["yards"] if y["id"].startswith("house_") or y["id"] == "sack"]
        lane_y = max(h["y1"] for h in houses) + 14
        worn([(min(h["x0"] for h in houses) - 10, lane_y), (max(h["x1"] for h in houses) + 10, lane_y)], 30, 0.62)
        left, right = min(h["x0"] for h in houses) - 24, max(h["x1"] for h in houses) + 24
        hauler, scrap = yards["house_hauler"], yards["house_scrap_collector"]
        for x in (left, (hauler["x1"] + scrap["x0"]) / 2, right):
            worn([(x, street["y1"] - 4), (x, lane_y)], 26, 0.66)
        tav, stall = yards["tavern"], yards["stall"]
        sx = (stall["x0"] + stall["x1"]) / 2
        worn([(sx, tav["y1"] - 6), (sx, stall["y0"] + 6)], 34, 0.7)
        worn([(sx, stall["y1"] - 6), (sx, street["y0"] + 6)], 30, 0.66)
        shed, bell = yards["shed"], yards["bell"]
        worn([(shed["x1"] - 8, (shed["y0"] + shed["y1"]) / 2), (bell["x0"] + 8, (bell["y0"] + bell["y1"]) / 2)], 28, 0.6)

    for dist in G["districts"]:
        district_paths(dist)

    # ---- 5. piata de piatra si puntea: dalele aprobate, la pixelul lor -------------------------------------------
    def tile_rect(sprite, r, worn_edge):
        x0, y0 = round(r["x0"] / D), round(r["y0"] / D)
        x1, y1 = round(r["x1"] / D), round(r["y1"] / D)
        for iy in range(y0, y1):
            for ix in range(x0, x1):
                if not cv.inside(ix, iy):
                    continue
                border = min(ix - x0, x1 - 1 - ix, iy - y0, y1 - 1 - iy)
                if worn_edge and border < 2 and hash01(ix, iy, 21) < (0.55 if border == 0 else 0.2):
                    continue  # pietre lipsa la margine: piata se pierde in pamantul curtii
                q = sprite.px[(iy - y0) % sprite.h][(ix - x0) % sprite.w]
                if q[3]:
                    cv.set(ix, iy, q, MAT_BUILT)
        return x0, y0, x1, y1

    def district_built(dist):
        plaza = next(r for r in dist["roads"] if r["id"] == "plaza")
        deck = dist["deck"]
        tile_rect(Sprite("tile_plaza"), plaza, True)

        # malul amenajat: intre apa si punte, un zid de barne batute in mal, cu capetele lor
        dx0, dy0, dx1, dy1 = round(deck["x0"] / D), round(deck["y0"] / D), round(deck["x1"] / D), round(deck["y1"] / D)
        for ix in range(dx0 - 3, dx1 + 3):
            if not 0 <= ix < W:
                continue
            top = int(near["y"][ix] // D) + 1
            for iy in range(top, dy0):
                k = iy - top
                pile = (ix // 2) % 2 == 0
                col = TIMBER[0] if k == 0 else (TIMBER[2] if pile else TIMBER[1])
                if k == 1 and ix % 8 == 0:
                    col = TIMBER[3]
                cv.set(ix, iy, col, MAT_BUILT)
        tile_rect(Sprite("deck_tile"), deck, False)
        for ix in range(dx0, dx1):
            cv.set(ix, dy1 - 1, TIMBER[0], MAT_BUILT)  # muchia scandurilor dinspre sat
            for k, a in ((0, 0.34), (1, 0.18)):
                if cv.inside(ix, dy1 + k) and cv.mat[(dy1 + k) * W + ix] != MAT_BUILT:
                    cv.blend(ix, dy1 + k, (20, 26, 22), a)
        for iy in range(dy0, dy1):
            for ix in (dx0 - 1, dx1):
                if cv.inside(ix, iy):
                    cv.set(ix, iy, TIMBER[0], MAT_BUILT)

    for dist in G["districts"]:
        district_built(dist)

    # ---- 6. smocuri si flori pe iarba ramasa ----------------------------------------------------------------------
    flowers = ((244, 240, 226), (250, 214, 96), (236, 150, 170), (170, 190, 250))
    flower_top = int(near["y"][0] // D) + 30
    # in doi timpi, ca la pietricele: satul vechi isi tine smocurile si florile, fasia noua le primeste pe ale ei
    for seed, x_from, x_to, share in [(5, 0, W_OLD, 1.0)] + strips(505, 1.0):
        span = x_to - x_from
        if span <= 2:
            continue
        for rnd in each_try(seed, int(2400 * share)):
            ix, iy = x_from + rnd.randrange(1, span - 1), rnd.randrange(2, H)
            i = iy * W + ix
            if cv.mat[i] != MAT_GRASS or cv.mat[i - 1] != MAT_GRASS or cv.mat[i + 1] != MAT_GRASS:
                continue
            cv.set(ix, iy, GRASS_BLADE_DARK)
            cv.set(ix - 1, iy - 1, GRASS_BLADE_DARK)
            cv.set(ix + 1, iy - 1, GRASS_BLADE_LIGHT if rnd.random() < 0.5 else GRASS_BLADE_DARK)
        for rnd in each_try(seed + 7, int(260 * share)):
            cx, cy = x_from + rnd.randrange(span), rnd.randrange(flower_top, H)
            wx, wy = world(cx, cy)
            if n_tone.at(wx, wy, 430) < 0.52:
                continue  # florile cresc in petele de soare
            tone = flowers[rnd.randrange(len(flowers))]
            for _k in range(rnd.randrange(3, 8)):
                ix, iy = cx + rnd.randrange(-6, 7), cy + rnd.randrange(-4, 5)
                if cv.inside(ix, iy + 1) and cv.mat[iy * W + ix] == MAT_GRASS and cv.mat[(iy + 1) * W + ix] == MAT_GRASS:
                    cv.set(ix, iy, tone)
                    cv.set(ix, iy + 1, GRASS_BLADE_DARK)

    # umbra moale sub copacii si tufele imprastiate (desenele lor vin peste, din joc)
    for item in list(G["scattered"]) + [dict(kind=d["sprite"], x=d["x"], y=d["y"]) for d in G["decor"]]:
        if item["kind"] not in ("tree_pine", "tree_round", "bush"):
            continue
        rx, ry = (44, 15) if item["kind"] != "bush" else (24, 9)
        bx, by = item["x"] + 8, item["y"] - 2
        for iy in range(int((by - ry) // D), int((by + ry) // D) + 1):
            for ix in range(int((bx - rx) // D), int((bx + rx) // D) + 1):
                if not cv.inside(ix, iy) or cv.mat[iy * W + ix] in (MAT_WATER, MAT_BUILT):
                    continue
                wx, wy = world(ix, iy)
                q = ((wx - bx) / rx) ** 2 + ((wy - by) / ry) ** 2
                if q < 1 and dither(ix, iy) < 0.9 * (1 - q) + 0.25:
                    cv.blend(ix, iy, (22, 40, 30), 0.34)

    # ---- 7. apa: doar tente peste raul animat -- apa mica langa maluri, canalul adanc la mijloc ---------------
    for ix in range(W):
        fy, ny = far["y"][ix], near["y"][ix]
        for iy in range(int(fy // D) - 1, int(ny // D) + 2):
            if not cv.inside(ix, iy) or cv.mat[iy * W + ix] != MAT_WATER:
                continue
            wy = iy * D + D / 2
            t = (wy - fy) / max(1.0, ny - fy)
            bump = 1 - abs(2 * t - 1) ** 1.5
            level = int(bump * 6)
            if level > 0:
                cv.blend(ix, iy, DEEP, 0.075 * min(level, 6))
            ds = min(wy - fy, ny - wy)  # pana la cel mai apropiat mal
            if ds < 36:
                step = 3 - int(ds // 12)  # trei trepte de apa mica, fiecare de 12 px de lume
                cv.blend(ix, iy, SHALLOW, 0.11 * step)
            if wy - fy < 7:
                cv.blend(ix, iy, BANK_SHADE, 0.38)  # malul de nord isi lasa umbra pe apa
    return cv


class Sprite:
    def __init__(self, name):
        self.w, self.h, self.px = load(name)


# ---- previzualizarea: cum se vede in joc, cu raul dedesubt si cu desenele asezate peste ---------------------------
def compose(G, ground_rows):
    W, H = G["world"]["w"] // D, G["world"]["h"] // D
    water = Sprite("water_tile")
    out = [[water.px[y % water.h][x % water.w] for x in range(W)] for y in range(H)]

    def over(x, y, q):
        if not (0 <= x < W and 0 <= y < H) or q[3] == 0:
            return
        a = q[3] / 255
        p = out[y][x]
        out[y][x] = (
            round(p[0] + (q[0] - p[0]) * a), round(p[1] + (q[1] - p[1]) * a), round(p[2] + (q[2] - p[2]) * a), 255,
        )

    for y in range(H):
        for x in range(W):
            over(x, y, ground_rows[y][x])

    def stamp(name, cx, base, scale=1.0):
        try:
            s = Sprite(name)
        except FileNotFoundError:
            return
        w, h = max(1, round(s.w * scale)), max(1, round(s.h * scale))
        x0, y0 = round(cx / D - w / 2), round(base / D - h)
        for yy in range(h):
            for xx in range(w):
                over(x0 + xx, y0 + yy, s.px[min(s.h - 1, int(yy / scale))][min(s.w - 1, int(xx / scale))])

    things = [(i["y"], "prop_" + i["kind"], i["x"], 1.0) for i in G["scattered"]]
    things += [(d["y"], "prop_" + d["sprite"], d["x"], d["scale"] / D) for d in G["decor"]]
    sp = G["spots"]
    for key, name in (("tavern", "prop_tavern"), ("storage", "prop_storage"), ("sawmill", "prop_sawmill")):
        r = sp[key]
        things.append((r["y"], name, r["x"], 1.0))  # y-ul cladirilor fixe e deja baza lor (TycoonConfig)
    for p in G["pads"]:
        if p["net"]:
            continue
        name = "prop_workshop_e1" if p["id"] == "workshop" else ("prop_scrap_shed" if p["id"] == "scrap_shed" else None)
        if p["id"].startswith("hire_") or p["id"] == "first_runner":
            name = "prop_runner_hut"
        if name:
            # baza cladirii de pe platforma, ca in joc: TycoonConfig.buildingBase = y + PAD_SIZE/2 + BUILDING_DROP
            things.append((p["y"] + 48 + 8, name, p["x"], 1.0))
    for _y, name, x, scale in sorted(things):
        stamp(name, x, _y, scale)
    return out


def zoom(rows, cx, cy, path, w=320, h=213, k=3):
    x0, y0 = max(0, int(cx / D - w / 2)), max(0, int(cy / D - h / 2))
    out = []
    for yy in range(h * k):
        src = rows[min(len(rows) - 1, y0 + yy // k)]
        out.append([src[min(len(src) - 1, x0 + xx // k)] for xx in range(w * k)])
    write_png(path, w * k, h * k, out)


def main():
    G = geometry()
    args = sys.argv[1:]
    if "--check" in args:
        check(G)
        return
    cv = bake(G)
    rows = cv.rows()
    for path, x0, width in tile_paths(G):
        write_png(path, width, cv.h, [row[x0 : x0 + width] for row in rows])
        print(f"  {os.path.basename(path)}  {width}x{cv.h}")
    with open(LOCK, "w") as f:
        f.write(fingerprint(G) + "\n")
    if "--preview" in args or "--zoom" in args:
        full = compose(G, rows)
        if "--preview" in args:
            path = args[args.index("--preview") + 1]
            write_png(path, len(full[0]), len(full), full)
            print("  previzualizare:", path)
        while "--zoom" in args:
            i = args.index("--zoom")
            zoom(full, float(args[i + 2]), float(args[i + 3]), args[i + 1])
            print("  aproape:", args[i + 1])
            del args[i : i + 4]


if __name__ == "__main__":
    main()
