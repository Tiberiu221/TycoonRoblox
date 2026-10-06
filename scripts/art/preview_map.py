#!/usr/bin/env python3
"""Randeaza HARTA exact cum o deseneaza SceneArt.BuildBackground, ca sa o pot vedea singur
inainte sa fie deschis Studio.

DE CE: owner-ul mi-a reprosat, pe buna dreptate, ca defectele vizuale le vede el, nu eu. Un
screenshot din Studio costa si cere ca jocul sa ruleze; asta ruleaza in cateva secunde si
foloseste ACELEASI formule (Shoreline portat una la una) si ACELEASI fisiere din assets/sprites.
Daca aici arata prost, arata prost si in joc.

NU scrie in assets/: iese un singur PNG in folderul de lucru (scripts/art/scratch.py).
Rulare: python3 scripts/art/preview_map.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preview_tycoon import load, write_png  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEST = os.path.join(scratch.folder(), "map_preview.png")

# ---- aceleasi cifre ca in config -------------------------------------------------------------
W, H = 2880, 1920
RIVER_TOP, RIVER_BOTTOM = 480, 768
PIXEL_SCALE = 3
PATCH_SEED = 771104
FAR = {"seed": 20260912, "baseY": 488, "amp": 96, "side": -1, "beach": 58, "calm": None}
NEAR = {
    "seed": 20265154, "baseY": 758, "amp": 66, "side": 1, "beach": 46,
    "calm": {"x0": 150, "x1": 1960, "feather": 240, "amp": 12},
}
STEP = 32
OVER = 72
DECK = {"x0": 240, "x1": 1560, "y0": 772, "y1": 856}
# [D50] harta in bucla: aceleasi dreptunghiuri ca TycoonConfig.ROADS
ROADS = [
    {"x0": 240, "x1": 1800, "y0": 1100, "y1": 1160},  # drumul mare
    {"x0": 1470, "x1": 1520, "y0": 856, "y1": 1100},  # legatura depozitului
    {"x0": 520, "x1": 570, "y0": 856, "y1": 1100},  # legatura tavernei
    {"x0": 1570, "x1": 1630, "y0": 1160, "y1": 1480},  # drumul de est
    {"x0": 1300, "x1": 1630, "y0": 1480, "y1": 1560},  # curtea gaterului
    {"x0": 500, "x1": 1300, "y0": 1500, "y1": 1560},  # drumul de sud
    {"x0": 500, "x1": 560, "y0": 1160, "y1": 1500},  # pintenul de vest
]
# cladirile, prinse de baza: (centru x, baza y, latime, inaltime) -- doar contur, ca reper
STORAGE = (1600, 1020, 120, 96)
SAWMILL = (1420, 1480, 120, 96)
TAVERN = (400, 1080, 192, 144)
NET_XS = (620, 820, 1020, 1220, 1420)
FAR_CURRENT_Y = 516
LANE_YS = [516, 588, 660, 732]

DOWN = 2  # 1 pixel de previzualizare = 2 pixeli de lume
PW, PH = W // DOWN, H // DOWN

GRASS_TONES = [(152, 188, 106), (64, 102, 54), (146, 126, 84)]
STONE_TONES = [(152, 145, 132), (118, 110, 98), (172, 160, 142)]


# ---- Prng si Shoreline, portate una la una din Luau ------------------------------------------
class Prng:
    def __init__(self, seed):
        self.state = int(seed) & 0xFFFFFFFF or 0x9E3779B9

    def u32(self):
        x = self.state
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.state = x & 0xFFFFFFFF
        return self.state

    def number(self):
        return self.u32() / 4294967296

    def integer(self, lo, hi):
        return lo + int(self.number() * (hi - lo + 1))


def hash01(seed, i):
    r = Prng((seed + i * 2654435761) % 4294967296)
    r.u32()
    r.u32()
    return r.number()


def noise(seed, x, period):
    t = x / period
    i = math.floor(t)
    f = t - i
    s = f * f * (3 - 2 * f)
    a, b = hash01(seed, i), hash01(seed, i + 1)
    return a + (b - a) * s


def smoothstep(t):
    c = max(0.0, min(1.0, t))
    return c * c * (3 - 2 * c)


def contrast(v, k):
    return max(0.0, min(1.0, (v - 0.5) * k + 0.5))


def shape(seed, x):
    lo = noise(seed, x, 940)
    mid = noise(seed + 7777, x, 330)
    sh = noise(seed + 4242, x, 118)
    return contrast(lo * 0.58 + mid * 0.31 + sh * 0.11, 2.6)


def amplitude_at(e, x):
    calm = e.get("calm")
    if not calm:
        return e["amp"]
    if x < calm["x0"]:
        inside = 1 - smoothstep((calm["x0"] - x) / max(1, calm["feather"]))
    elif x > calm["x1"]:
        inside = 1 - smoothstep((x - calm["x1"]) / max(1, calm["feather"]))
    else:
        inside = 1
    return calm["amp"] + (e["amp"] - calm["amp"]) * (1 - inside)


def edge_y(e, x):
    return e["baseY"] + e["side"] * amplitude_at(e, x) * shape(e["seed"], x)


def beach_width(e, x):
    m = e.get("beach") or 0
    if m <= 0:
        return 0
    n = contrast(noise(e["seed"] + 1313, x, 270) * 0.7 + noise(e["seed"] + 2626, x, 91) * 0.3, 2.2)
    return max(0, min(m, n * m * 1.9 - m * 0.62))


def columns(e, width, step):
    out, x = [], 0
    while x < width:
        w = min(step, width - x)
        mid = x + w / 2
        out.append({"x": x, "w": w + 1, "y": edge_y(e, mid), "beach": beach_width(e, mid)})
        x += step
    return out


def patches(seed, area, count):
    out, rng = [], Prng(seed)
    for i in range(1, count + 1):
        huge = i % 4 == 0
        w = (620 + rng.number() * 680) if huge else (130 + rng.number() * 330)
        h = w * (0.42 + rng.number() * 0.46)
        x = area["x0"] + rng.number() * max(1, area["x1"] - area["x0"] - w)
        y = area["y0"] + rng.number() * max(1, area["y1"] - area["y0"] - h)
        out.append(
            {
                "x": round(x), "y": round(y), "w": round(w), "h": round(h),
                "rot": round((rng.number() - 0.5) * 40),
                "tone": rng.integer(1, max(1, area["tones"])),
            }
        )
    return out


def pebbles(e, width, count, spread, salt=0):
    out, rng = [], Prng(e["seed"] + 31337 + salt)
    for _ in range(count):
        x = rng.number() * width
        off = (rng.number() - 0.5) * 2 * spread
        out.append(
            {
                "x": round(x), "y": round(edge_y(e, x) + off),
                "r": 3 + rng.integer(0, 4), "tone": rng.integer(1, 3),
            }
        )
    return out


# ---- panza -----------------------------------------------------------------------------------
def blend(dst, i, rgb, a):
    if a <= 0:
        return
    if a >= 1:
        dst[i], dst[i + 1], dst[i + 2] = rgb
        return
    dst[i] = int(dst[i] + (rgb[0] - dst[i]) * a)
    dst[i + 1] = int(dst[i + 1] + (rgb[1] - dst[i + 1]) * a)
    dst[i + 2] = int(dst[i + 2] + (rgb[2] - dst[i + 2]) * a)


class Sheet:
    """Un tile, esantionat in coordonate de LUME, cu acelasi PIXEL_SCALE ca in joc."""

    def __init__(self, name):
        self.w, self.h, self.px = load(name)

    def at(self, wx, wy):
        sx = int(wx / PIXEL_SCALE) % self.w
        sy = int(wy / PIXEL_SCALE) % self.h
        return self.px[sy][sx]

    def at2(self, wx, wy):
        return self.at(wx, wy)


def main():
    grass, water, sand = Sheet("grass_tile"), Sheet("water_tile"), Sheet("sand_tile")
    deck, path = Sheet("deck_tile"), Sheet("path_tile")
    buf = bytearray(PW * PH * 3)

    far_cols = {c["x"] // STEP: c for c in columns(FAR, W, STEP)}
    near_cols = {c["x"] // STEP: c for c in columns(NEAR, W, STEP)}
    sand_h = sand.h * PIXEL_SCALE
    water_top, water_bot = 368, 848

    for py in range(PH):
        wy = py * DOWN
        for px in range(PW):
            wx = px * DOWN
            i = (py * PW + px) * 3
            # 1. iarba de baza
            g = grass.at(wx, wy)
            buf[i], buf[i + 1], buf[i + 2] = g[0], g[1], g[2]
            # a doua tesatura, la alta scara: sterge ritmul tile-ului de baza
            w2 = grass.at2((wx + 90) / 1.53, (wy + 140) / 1.37)
            blend(buf, i, (w2[0], w2[1], w2[2]), 0.28 * w2[3] / 255)
            # 2. apa (dreptunghiul extins)
            if water_top <= wy < water_bot:
                w0 = water.at(wx, wy)
                blend(buf, i, (w0[0], w0[1], w0[2]), w0[3] / 255)
                blend(buf, i, (w0[0], w0[1], w0[2]), 0.45 * w0[3] / 255)
                f = (wy - water_top) / (water_bot - water_top)
                dark = max(0.0, 1 - abs(f - 0.5) * 2) * 0.4
                blend(buf, i, (8, 34, 62), dark)
            # 3. malurile: coloana de iarba care musca din apa
            col = far_cols.get(wx // STEP)
            edge = round(col["y"]) if col else RIVER_TOP
            col_beach = col["beach"] if col else 0
            on_land = wy < edge
            if not on_land:
                colb = near_cols.get(wx // STEP)
                edge = round(colb["y"]) if colb else RIVER_BOTTOM
                col_beach = colb["beach"] if colb else 0
                on_land = wy >= edge
            if on_land and water_top <= wy < water_bot:
                blend(buf, i, (g[0], g[1], g[2]), 1)
            if on_land:
                d = wy - edge if wy >= edge else edge - wy
                bw = round(col_beach)
                if d < bw and bw > 2:
                    s = sand.at(wx, wy)
                    if s[3]:
                        wet = 1 - d / bw
                        rgb = (
                            int(s[0] * (1 - wet * 0.42)),
                            int(s[1] * (1 - wet * 0.41)),
                            int(s[2] * (1 - wet * 0.32)),
                        )
                        u = d / bw  # 0 la apa, 1 la iarba
                        fade = 1.0 if u < 0.45 else max(0.05, 1 - (u - 0.45) / 0.55 * 0.95)
                        blend(buf, i, rgb, (s[3] / 255) * fade)

    def dot(cx, cy, w, h, rgb, alpha):
        for yy in range(max(0, (cy) // DOWN), min(PH, (cy + h) // DOWN + 1)):
            for xx in range(max(0, cx // DOWN), min(PW, (cx + w) // DOWN + 1)):
                blend(buf, (yy * PW + xx) * 3, rgb, alpha)

    # 3b. petele de nuanta de pe malul de sud
    for pa in patches(PATCH_SEED, {"x0": 0, "y0": 860, "x1": W, "y1": H - 20, "tones": 3}, 84):
        cx, cy = pa["x"] + pa["w"] / 2, pa["y"] + pa["h"] / 2
        rx, ry = pa["w"] / 2, pa["h"] / 2
        rot = math.radians(pa["rot"])
        cs, sn = math.cos(-rot), math.sin(-rot)
        rgb = GRASS_TONES[pa["tone"] - 1]
        for wy in range(pa["y"] - 40, pa["y"] + pa["h"] + 40, DOWN):
            if wy < 0 or wy >= H:
                continue
            for wx in range(pa["x"] - 40, pa["x"] + pa["w"] + 40, DOWN):
                if wx < 0 or wx >= W:
                    continue
                dx, dy = wx - cx, wy - cy
                lx, ly = dx * cs - dy * sn, dx * sn + dy * cs
                # stadion: dreptunghi cu capetele rotunjite la raza min(w,h)/2
                rad = min(rx, ry)
                ex, ey = max(0.0, abs(lx) - (rx - rad)), max(0.0, abs(ly) - (ry - rad))
                if abs(lx) > rx or abs(ly) > ry or (ex * ex + ey * ey) > rad * rad:
                    continue
                a = 0.13 * (1 - abs(ly) / ry)  # gradient liniar pe axa scurta
                blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, rgb, a)

    # 4. pietre si spuma pe linia malului
    for e, side in ((FAR, -1), (NEAR, 1)):
        for p in pebbles(e, W, 70, 16):
            base = edge_y(e, p["x"])
            y = round(base + side * (5 + abs(p["y"] - base)))
            dot(p["x"], y, p["r"] * 2, max(3, p["r"]), STONE_TONES[p["tone"] - 1], 1)
        for p in pebbles(e, W, 64, 7, 991):
            if p["r"] % 2 == 0:
                continue
            h = max(3, p["r"] - 1)
            a = 1 - (0.3 + (p["r"] % 3) * 0.18)
            dot(p["x"], p["y"] - side * 4, p["r"] * (4 + p["tone"] * 2), h, (238, 249, 255), a)

    # 5. padurea de dincolo: masa compacta sus, coroane rotunde dedesubt
    for py in range(0, 150 // DOWN):
        f = (py * DOWN) / 150
        t = (0.1 + (0.3 - 0.1) * (f / 0.7)) if f < 0.7 else (0.3 + (0.8 - 0.3) * ((f - 0.7) / 0.3))
        for px in range(PW):
            blend(buf, (py * PW + px) * 3, (36, 62, 44), 1 - t)
    CROWNS = [(34, 60, 40), (46, 78, 48), (26, 48, 34)]
    tree_line = {"seed": 480917, "baseY": 312, "amp": 96, "side": -1, "calm": None}
    rng = Prng(480917)
    cx = -40
    while cx < W + 40:
        base = edge_y(tree_line, max(0, cx))
        for row in (0, 1, 2, 3):
            size = 54 + rng.integer(0, 66) - row * 6
            cy = base - row * 58 - rng.integer(0, 26)
            col = CROWNS[rng.integer(1, 3) - 1]
            rx2, ry2 = size / 2, size * 0.86 / 2
            for wy in range(int(cy - ry2), int(cy + ry2) + 1, DOWN):
                if wy < 0 or wy >= H:
                    continue
                for wx in range(int(cx - rx2), int(cx + rx2) + 1, DOWN):
                    if wx < 0 or wx >= W:
                        continue
                    if ((wx - cx) / rx2) ** 2 + ((wy - cy) / ry2) ** 2 > 1:
                        continue
                    blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, col, 1)
        cx += 22 + rng.integer(0, 12)

    # 6. constructiile: umbra, apoi scandurile
    def strip(sheet, r):
        for wy in range(r["y0"] + 6, r["y1"] + 6, DOWN):
            for wx in range(r["x0"] + 4, r["x1"] + 4, DOWN):
                blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, (26, 32, 24), 0.26)
        for wy in range(r["y0"], r["y1"], DOWN):
            for wx in range(r["x0"], r["x1"], DOWN):
                c = sheet.at(wx - r["x0"], wy - r["y0"])
                if c[3]:
                    blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, (c[0], c[1], c[2]), c[3] / 255)

    def ragged(sheet, r):
        seg, x, i = 64, r["x0"], 0
        while x < r["x1"]:
            segw = min(seg, r["x1"] - x)
            wob = math.floor(math.sin(i * 1.7) * 5 + math.sin(i * 0.6) * 4)
            strip(sheet, {"x0": x, "x1": x + segw, "y0": r["y0"] - wob, "y1": r["y1"] + wob})
            x += seg
            i += 1

    strip(deck, DECK)
    for road in ROADS:
        ragged(path, road)

    # 6b. contururile depozitului, gaterului si tavernei, ca reper: unde stau fata de drumuri
    for cx, base, bw, bh in (STORAGE, SAWMILL, TAVERN):
        x0, x1, y0, y1 = cx - bw // 2, cx + bw // 2, base - bh, base
        for wx in range(x0, x1, DOWN):
            for wy in (y0, y1 - 2):
                blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, (120, 60, 20), 0.95)
        for wy in range(y0, y1, DOWN):
            for wx in (x0, x1 - 2):
                blend(buf, ((wy // DOWN) * PW + wx // DOWN) * 3, (120, 60, 20), 0.95)


    # 7. repere de verificare: banda din larg si primele platforme, ca sa vad daca malul le musca
    for y in LANE_YS:
        for px in range(0, PW, 6):
            blend(buf, ((y // DOWN) * PW + px) * 3, (255, 80, 80), 0.55)
    for x in NET_XS:
        for wy in range(760, 900, 4):
            blend(buf, ((wy // DOWN) * PW + x // DOWN) * 3, (255, 220, 60), 0.9)

    rows = []
    for py in range(PH):
        row = []
        for px in range(PW):
            i = (py * PW + px) * 3
            row.append((buf[i], buf[i + 1], buf[i + 2], 255))
        rows.append(row)
    write_png(DEST, PW, PH, rows)
    print(f"scris {DEST} ({PW}x{PH})")
    print(f"linia FAR  min/max: {min(edge_y(FAR, x) for x in range(W)):.0f} / "
          f"{max(edge_y(FAR, x) for x in range(W)):.0f}  (banda din larg la {FAR_CURRENT_Y})")
    print(f"linia NEAR min/max: {min(edge_y(NEAR, x) for x in range(W)):.0f} / "
          f"{max(edge_y(NEAR, x) for x in range(W)):.0f}  (pontonul incepe la {DECK['y0']})")


if __name__ == "__main__":
    main()
