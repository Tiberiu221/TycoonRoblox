#!/usr/bin/env python3
"""Compune o scena de proba din PNG-urile reale, ca sa vedem cum arata impreuna."""
import zlib, struct, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png, hexc

SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"


def load(name):
    d = open(os.path.join(SPR, name + ".png"), "rb").read()
    pos, w, h, idat = 8, 0, 0, b""
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos+4])[0]
        typ = d[pos+4:pos+8]
        data = d[pos+8:pos+8+ln]
        if typ == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", data[:10])
            assert depth == 8 and ctype == 6, (name, depth, ctype)
        elif typ == b"IDAT":
            idat += data
        pos += 12 + ln
    raw = zlib.decompress(idat)
    px, stride, prev = [], w * 4, bytearray(w * 4)
    p = 0
    for _ in range(h):
        ft = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        for i in range(stride):
            a = line[i-4] if i >= 4 else 0
            b = prev[i]
            c = prev[i-4] if i >= 4 else 0
            if ft == 1: line[i] = (line[i] + a) & 255
            elif ft == 2: line[i] = (line[i] + b) & 255
            elif ft == 3: line[i] = (line[i] + (a + b) // 2) & 255
            elif ft == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        prev = line
        px.append([tuple(line[i*4:i*4+4]) for i in range(w)])
    return w, h, px


def blit(dst, src, ox, oy, scale=1, sx=0, sy=0, sw=None, sh=None):
    w, h, px = src
    sw = sw or w; sh = sh or h
    for y in range(sh):
        for x in range(sw):
            p = px[sy+y][sx+x]
            if p[3] == 0: continue
            for dy in range(scale):
                for dx in range(scale):
                    dst.put(ox + x*scale + dx, oy + y*scale + dy, p)


S = 3
W, H = 1180, 620
scene = C(W, H)
grass, water, shore_n, shore_s, path = (load(n) for n in
    ("grass_tile", "water_tile", "shore_north", "shore_south", "path_tile"))

for y in range(0, H, grass[1]*S):
    for x in range(0, W, grass[0]*S):
        blit(scene, grass, x, y, S)
RIVER_TOP, RIVER_H = 40, 150
for x in range(0, W, water[0]*S):
    for y in range(RIVER_TOP, RIVER_TOP+RIVER_H, water[1]*S):
        blit(scene, water, x, y, S)
for x in range(0, W, shore_n[0]*S):
    blit(scene, shore_n, x, RIVER_TOP - shore_n[1]*S + 24, S)
    blit(scene, shore_s, x, RIVER_TOP + RIVER_H - 24, S)
for y in range(RIVER_TOP+RIVER_H+30, H, path[1]*S):
    blit(scene, path, 430, y, S)
for x in range(430, W, path[0]*S):
    blit(scene, path, x, 400, S)

placements = [
    ("b_tent", 60, 300), ("b_cottage", 160, 270), ("b_bunkhouse", 330, 265),
    ("b_kitchen", 570, 270), ("b_smokehouse", 720, 265), ("b_workshop", 930, 240),
    ("b_hall", 150, 430), ("b_firepit", 400, 300), ("b_scaffold", 620, 430),
]
for name, x, y in placements:
    blit(scene, load(name), x, y, S)

sheet = load("character_anim")
FW, FH = 16, 24
poses = [(0,0),(2,0),(2,1),(6,2),(7,1),(8,2),(9,1),(10,2),(11,0)]
spots = [(120,260),(250,370),(420,250),(700,400),(560,380),(640,250),(230,255),(300,470),(880,215)]
for (row, frame), (x, y) in zip(poses, spots):
    blit(scene, sheet, x, y, S, sx=frame*FW, sy=row*FH, sw=FW, sh=FH)

png("_scene_preview.png", W, H, scene.px)
print(f"scena {W}x{H} gata")
