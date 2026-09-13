#!/usr/bin/env python3
"""Mockup-ul de compunere pentru noul aranjament al malului (debarcader + plase + alee), cerut
de owner dupa ce a vazut jocul si a spus ca totul e asezat prost. E DOAR o imagine: nu atinge
niciun cod de joc din src/ sau tests/, scrie un singur PNG de aprobat inainte sa recodam layout-ul.

Foloseste sprite-urile REALE din assets/sprites, la marimile REALE (PIXEL_SCALE=3 ca in joc, cu
exceptia plaselor care vin explicit la scara 2 in cerinta -- ca sa incapa intre benzi). Reface
decodorul PNG si compozitorul din preview_tycoon.py (load/write_png/blit_scaled/draw_text) si
9-slice-ul din preview_tycoon_f2.py (slice_stretch) -- nu le rescrie.

Sub-blit-ul cu regiune (sx,sy,sw,sh), pentru foile de personaje in straturi, e copiat din
preview_scene.py, NU importat: acel fisier deseneaza la nivelul modulului (fara `if __name__ ==
"__main__"`), deci un import simplu ar scrie _scene_preview.png ca efect secundar (acelasi motiv
pentru care preview_tycoon.py isi copiaza propriul load()).

Rulare: python3 scripts/art/layout_preview.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, hexc, STONE  # noqa: E402
from preview_tycoon import load, write_png, blit_scaled, draw_text, text_width, FULL_FONT, GLYPH_H  # noqa: E402
from preview_tycoon_f2 import slice_stretch  # noqa: E402

SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
DEST = (
    "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/"
    "b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/layout_mockup.png"
)

# Cateva glife de punctuatie care nu existau in fontul in blocuri (litere + cifre): pretul,
# rata si etichetele plaselor au nevoie de "+", "." si "/". Adaugate in dictionarul PARTAJAT
# (acelasi obiect pe care preview_tycoon.draw_text il citeste), nu intr-o copie.
FULL_FONT["."] = [".....", ".....", ".....", ".....", ".....", ".##..", ".##.."]
FULL_FONT["+"] = [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."]
FULL_FONT["/"] = ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."]


# --------------------------------------------------------------- copiat din preview_scene.py
def blit(dst, src, ox, oy, scale=1, sx=0, sy=0, sw=None, sh=None):
    """Blit cu regiune sursa (pentru foile de personaje in randuri/cadre). Vezi nota din antet:
    NU se importa din preview_scene.py -- acel fisier are efecte secundare la import."""
    w, h, px = src
    sw = sw or w
    sh = sh or h
    for y in range(sh):
        row = px[sy + y]
        for x in range(sw):
            p = row[sx + x]
            if p[3] == 0:
                continue
            for dy in range(scale):
                for dx in range(scale):
                    dst.put(ox + x * scale + dx, oy + y * scale + dy, p)


# --------------------------------------------------------------- paleta (Theme.luau, portata)
INK = hexc("3a2a1e")
INK_SOFT = hexc("685442")
ON_DARK = hexc("f0e9da")
ON_DARK_SOFT = hexc("c4baa8")
GOLD = hexc("e8b23c")
GOLD_DARK = hexc("a97e2c")
GOLD_LIGHT = hexc("f5d888")
BAD = hexc("be4a3e")
ROPE_COLOR = hexc("3a2410")

# --------------------------------------------------------------- camera: scara 1.0, centrata pe
# range-ul cerut (200..1450 x, 440..1250 y). Range-ul cerut (1250x810) e mai mic decat canvasul
# (1920x1080) pe ambele axe -- deci nu trebuie taiat nimic, doar centrat; canvasul arata putin
# mai multa lume la margini (335px pe orizontala, 135px pe verticala), simetric.
CANVAS_W, CANVAS_H = 1920, 1080
VIEW_X0, VIEW_X1 = 200, 1450
VIEW_Y0, VIEW_Y1 = 440, 1250
OFFSET_X = CANVAS_W / 2 - (VIEW_X0 + VIEW_X1) / 2
OFFSET_Y = CANVAS_H / 2 - (VIEW_Y0 + VIEW_Y1) / 2


def w2s(x, y):
    """Coordonate de lume -> coordonate de ecran. Translatie pura (scara camerei = 1.0)."""
    return x + OFFSET_X, y + OFFSET_Y


# --------------------------------------------------------------- primitive de desen, in lume
def blit_scaled_clip(dst, w, h, px, ox, oy, scale, cx0, cy0, cx1, cy1):
    for yy in range(h):
        dy0 = oy + yy * scale
        if dy0 >= cy1 or dy0 + scale <= cy0:
            continue
        row = px[yy]
        for xx in range(w):
            p = row[xx]
            if not p[3]:
                continue
            dx0 = ox + xx * scale
            if dx0 >= cx1 or dx0 + scale <= cx0:
                continue
            for dy in range(scale):
                py = dy0 + dy
                if py < cy0 or py >= cy1:
                    continue
                for dx in range(scale):
                    pxx = dx0 + dx
                    if pxx < cx0 or pxx >= cx1:
                        continue
                    dst.put(pxx, py, p)


def tile_band(dst, spr, wx0, wy0, w, h, scale=3):
    """Un dreptunghi de lume acoperit cu un sprite repetat, ca ScaleType.Tile din Roblox
    (SceneArt.luau): coltul tine faza, marginea scurta e DECUPATA, nu comprimata -- asa arata
    un `Frame` cu `TileSize` mai mic decat dreptunghiul lui, nu o intindere."""
    sw, sh, px = spr
    tw, th = sw * scale, sh * scale
    sx0, sy0 = w2s(wx0, wy0)
    sx1, sy1 = sx0 + w, sy0 + h
    ny = int(h // th) + 2
    nx = int(w // tw) + 2
    for j in range(ny):
        ty0 = sy0 + j * th
        if ty0 >= sy1:
            break
        ty1 = ty0 + th
        for i in range(nx):
            tx0 = sx0 + i * tw
            if tx0 >= sx1:
                break
            tx1 = tx0 + tw
            if tx0 >= sx0 and ty0 >= sy0 and tx1 <= sx1 and ty1 <= sy1:
                blit_scaled(dst, sw, sh, px, tx0, ty0, scale)  # complet interior: drum rapid
            else:
                blit_scaled_clip(dst, sw, sh, px, tx0, ty0, scale, sx0, sy0, sx1, sy1)


def place_bottom(dst, spr, cx, bottom_y, scale):
    """Centrul X, ancorat jos -- obiectul "sta" pe teren, la fel ca SceneArt.luau (AnchorPoint
    0.5,1). Intoarce dreptunghiul de ECRAN (util pentru franghie/pastila agatate de el)."""
    w, h, px = spr
    ow, oh = w * scale, h * scale
    ox, oy = w2s(cx - ow / 2, bottom_y - oh)
    blit_scaled(dst, w, h, px, ox, oy, scale)
    return ox, oy, ow, oh


def place_center(dst, spr, cx, cy, scale):
    """Centrat pe ambele axe -- pentru plase, care plutesc (nu "stau" pe nimic)."""
    w, h, px = spr
    ow, oh = w * scale, h * scale
    ox, oy = w2s(cx - ow / 2, cy - oh / 2)
    blit_scaled(dst, w, h, px, ox, oy, scale)
    return ox, oy, ow, oh


def resize_nn(w, h, px, W, H):
    """Redimensionare nearest-neighbor (pentru scara 1.5 a bunurilor plutitoare -- nu un multiplu
    intreg, deci blit_scaled nu se aplica direct)."""
    out = []
    for Y in range(H):
        sy = min(h - 1, Y * h // H)
        srow = px[sy]
        out.append([srow[min(w - 1, X * w // W)] for X in range(W)])
    return out


def place_center_scaled_wh(dst, spr, cx, cy, target_w, target_h):
    w, h, px = spr
    resized = resize_nn(w, h, px, target_w, target_h)
    ox, oy = w2s(cx - target_w / 2, cy - target_h / 2)
    blit_scaled(dst, target_w, target_h, resized, ox, oy, 1)


def draw_line_world(dst, wx1, wy1, wx2, wy2, thickness, color):
    x1, y1 = w2s(wx1, wy1)
    x2, y2 = w2s(wx2, wy2)
    steps = max(1, int(math.hypot(x2 - x1, y2 - y1)))
    for i in range(steps + 1):
        t = i / steps
        x, y = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
        dst.rect(x - thickness / 2, y - thickness / 2, thickness, thickness, color)


def draw_text_world(dst, wx, wy, text, color, scale=1):
    x, y = w2s(wx, wy)
    draw_text(dst, x, y, text, color, scale)


def draw_text_outlined(dst, sx, sy, text, color, scale, outline):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx or dy:
                draw_text(dst, sx + dx, sy + dy, text, outline, scale)
    draw_text(dst, sx, sy, text, color, scale)


def draw_coin(dst, sx, sy, r):
    dst.ellipse(sx, sy, r, r, GOLD_DARK)
    dst.ellipse(sx, sy, r - 2, r - 2, GOLD)
    dst.ellipse(sx - r * 0.32, sy - r * 0.32, r * 0.32, r * 0.32, GOLD_LIGHT)


# --------------------------------------------------------------- pastile / cartonas 9-felii
def ninepatch(dst, sx, sy, w, h, sprite, border):
    sw, sh, px = sprite
    stretched = slice_stretch(sw, sh, px, border, int(w), int(h))
    blit_scaled(dst, int(w), int(h), stretched, sx, sy, 1)


def pill_screen(dst, pill_spr, sx, sy, w, h, text, color, scale=1):
    ninepatch(dst, sx, sy, w, h, pill_spr, 8)
    tw = text_width(text, scale)
    draw_text(dst, sx + (w - tw) / 2, sy + (h - GLYPH_H * scale) / 2, text, color, scale)


def pill_world(dst, pill_spr, wx, wy, w, h, text, color, scale=1):
    sx, sy = w2s(wx, wy)
    pill_screen(dst, pill_spr, sx, sy, w, h, text, color, scale)


# --------------------------------------------------------------- personaj: foile in straturi
FRAME_W, FRAME_H = 16, 24
IDLE_DOWN_ROW = 3  # AnimConfig.ROWS.idle_down.index; cadrul 0 al randului


def draw_character(dst, cx, bottom_y, body_name, hair_name, outfit_name, body_tint, hair_tint):
    scale = 3
    ow, oh = FRAME_W * scale, FRAME_H * scale  # 48x72, exact CHARACTER.WIDTH/HEIGHT din RiverConfig
    sx, sy = w2s(cx - ow / 2, bottom_y - oh)
    sy_src = IDLE_DOWN_ROW * FRAME_H

    def layer(name, tint):
        spr = load(name)
        w, h, px = spr
        for yy in range(FRAME_H):
            row = px[sy_src + yy]
            for xx in range(FRAME_W):
                p = row[xx]
                if not p[3]:
                    continue
                if tint is not None:
                    p = (p[0] * tint[0] // 255, p[1] * tint[1] // 255, p[2] * tint[2] // 255, p[3])
                for dy in range(scale):
                    for dx in range(scale):
                        dst.put(sx + xx * scale + dx, sy + yy * scale + dy, p)

    layer(body_name, body_tint)
    layer(hair_name, hair_tint)
    layer(outfit_name, None)


# ================================================================= scena
def main():
    scene = C(CANVAS_W, CANVAS_H)

    # ---- sprite-uri (incarcate o singura data) ----
    grass = load("grass_tile")
    water = load("water_tile")
    shore_s = load("shore_south")
    sand = load("sand_tile")
    path = load("path_tile")
    pier = load("prop_pier")
    bell = load("prop_bell")
    sack = load("prop_sack")
    stall = load("prop_stall")
    netpost = load("prop_netpost")
    runner_hut = load("prop_runner_hut")
    net = load("net")
    crate_common = load("crate_common")
    driftwood = load("prop_log")  # Assets.goods.driftwood reuseste bustenul de decor
    workshop = load("b_workshop")
    ui_pill = load("ui_pill")
    ui_card = load("ui_card")
    icon_crate = load("icon_crate")

    # ---- benzile lumii (fundal, in ordine, dinspre spate spre fata) ----
    tile_band(scene, grass, -135, 305, CANVAS_W, CANVAS_H, 3)  # baza, acopera tot canvas-ul
    tile_band(scene, water, -135, 480, CANVAS_W, 288, 3)  # apa: 480..768
    tile_band(scene, shore_s, -135, 768, CANVAS_W, 96, 3)  # malul, chiar la 768 (un rand)
    tile_band(scene, sand, -135, 856, CANVAS_W, 44, 3)  # nisip: 856..900
    tile_band(scene, path, 240, 772, 1160, 84, 3)  # NOU: puntea de lemn, 772..856, x240..1400
    tile_band(scene, path, 300, 856, 60, 184, 3)  # NOU: legatura debarcader -> alee, x300..360
    tile_band(scene, path, 300, 980, 1080, 60, 3)  # NOU: aleea din scanduri, 980..1040

    # ---- obiectele lumii, adunate si sortate dupa "adancime" (Y de jos, ca la SceneArt/WorldDecor:
    # ce e mai jos pe ecran se deseneaza peste ce e mai sus) ----
    draws = []  # (sort_y, functie fara argumente)

    NETS = [
        {"cx": 520, "cy": 732, "text": "2 / 12", "color": ON_DARK},
        {"cx": 700, "cy": 732, "text": "7 / 12", "color": ON_DARK},
        {"cx": 880, "cy": 732, "text": "0 / 12", "color": ON_DARK},
        {"cx": 1060, "cy": 732, "text": "FULL", "color": BAD},
        {"cx": 1240, "cy": 660, "text": "4 / 12", "color": ON_DARK},
    ]

    def make_net_fn(n):
        def fn():
            cx, cy = n["cx"], n["cy"]
            net_top, net_bottom = cy - 28, cy + 28
            post_top_y = 848 - 30 * 3  # bottom edge 848, scale3, native height 30 -> top 758
            place_center(scene, net, cx, cy, 2)  # 96x56, nu 144x84 [cerinta]
            # "pana la marginea apropiata a plasei" ar insemna marginea de JOS la banda 1 -- dar
            # acolo varful stalpului (758) e la 2px de ea (760): o franghie de 2px, nevazuta la
            # scara asta. Dusa pana in centrul plasei ramane vizibil o legatura clara la toate
            # cele 5 plase, nu doar la cea din larg (unde golul e oricum mare). Notat in raport.
            draw_line_world(scene, cx, post_top_y, cx, cy, 2, ROPE_COLOR)
            place_bottom(scene, netpost, cx, 848, 3)
            # "Chiar deasupra varfului stalpului" ar cadea PESTE plasa: la banda 1 varful
            # stalpului (758) e la 2px sub marginea de jos a plasei (760) -- geometria cerintei
            # nu lasa loc. Am mutat pastila deasupra plasei intregi (ansamblul stalp+plasa),
            # nu doar a stalpului -- ramane "atasata" vizual, dar nu se mai suprapune. Notat in
            # raport.
            pill_w, pill_h = 56, 22
            pill_bottom = net_top - 8
            pill_world(
                scene, ui_pill, cx - pill_w / 2, pill_bottom - pill_h, pill_w, pill_h,
                n["text"], n["color"], 1,
            )

        return fn

    for n in NETS:
        draws.append((848, make_net_fn(n)))

    def draw_pier():
        place_bottom(scene, pier, 300, 830, 3)

    draws.append((830, draw_pier))

    def draw_runner():
        # cerinta pune alergatorul la x700 -- exact peste stalpul plasei a doua (tot x700).
        # Mutat la x660 (pe punte, langa plasa lui) ca sa nu calce peste stalp. Notat in raport.
        draw_character(scene, 660, 850, "body_a", "hair_short", "outfit_fisher",
                        (219, 165, 133), (70, 50, 35))

    draws.append((850, draw_runner))

    def draw_bell():
        place_bottom(scene, bell, 1340, 852, 3)

    draws.append((852, draw_bell))

    def draw_player():
        draw_character(scene, 620, 960, "body_b", "hair_long", "outfit_keeper",
                        (231, 188, 150), (92, 62, 40))

    draws.append((960, draw_player))

    def draw_crate():
        place_bottom(scene, crate_common, 420, 1085, 2)

    draws.append((1085, draw_crate))

    def draw_sack():
        place_bottom(scene, sack, 600, 1085, 2)

    draws.append((1085, draw_sack))

    def draw_hut():
        place_bottom(scene, runner_hut, 780, 1085, 3)

    draws.append((1085, draw_hut))

    def draw_weights():
        ox, oy = w2s(960 - 20, 1085 - 28)
        scene.rect(ox + 12, oy + 2, 22, 20, STONE[1])
        scene.rect(ox + 12, oy + 2, 22, 3, STONE[2])
        scene.rect(ox, oy + 9, 22, 19, STONE[0])
        scene.rect(ox, oy + 9, 22, 3, STONE[1])
        scene.rect(ox, oy + 26, 22, 2, hexc("2c2d33"))

    draws.append((1085, draw_weights))

    def draw_stall():
        place_bottom(scene, stall, 1140, 1085, 2)

    draws.append((1085, draw_stall))

    def draw_workshop():
        place_bottom(scene, workshop, 1320, 1160, 3)

    draws.append((1160, draw_workshop))

    # bunuri plutitoare (scara 1.5 -- nu e multiplu intreg, resize NN) + un "+1" langa o plasa
    def draw_goods1():
        place_center_scaled_wh(scene, driftwood, 430, 685, 54, 27)

    def draw_goods2():
        place_center_scaled_wh(scene, driftwood, 980, 600, 54, 27)

    def draw_plus1():
        sx, sy = w2s(452, 712)
        draw_text_outlined(scene, sx, sy, "+1", GOLD, 2, hexc("2c1b10"))

    draws.append((600, draw_goods2))
    draws.append((685, draw_goods1))
    draws.append((720, draw_plus1))

    draws.sort(key=lambda t: t[0])
    for _, fn in draws:
        fn()

    # ================================================================= HUD (ecran, 1:1, peste tot)
    # -- pastila de monede --
    pill_screen(scene, ui_pill, 20, 12, 196, 48, "", ON_DARK)
    draw_coin(scene, 20 + 28, 12 + 24, 15)
    draw_text(scene, 20 + 52, 12 + (48 - GLYPH_H * 2) // 2, "1.53K", ON_DARK, 2)

    # -- pastila de rata, sub cea de monede --
    pill_screen(scene, ui_pill, 20, 72, 150, 32, "", ON_DARK)
    draw_text(scene, 20 + 14, 72 + (32 - GLYPH_H * 2) // 2, "+6.4/s", GOLD, 2)

    # -- pastila sacului, la dreapta celor doua --
    SACK_X, SACK_Y, SACK_W, SACK_H = 232, 12, 120, 52
    pill_screen(scene, ui_pill, SACK_X, SACK_Y, SACK_W, SACK_H, "", ON_DARK)
    ic_w, ic_h, ic_px = icon_crate
    blit_scaled(scene, ic_w, ic_h, ic_px, SACK_X + 10, SACK_Y + 12, 2)
    draw_text(scene, SACK_X + 46, SACK_Y + 8, "3/60", ON_DARK, 2)
    cap = "SACK"
    draw_text(scene, SACK_X + (SACK_W - text_width(cap, 1)) / 2, SACK_Y + SACK_H - 14, cap, ON_DARK_SOFT, 1)

    # ================================================================= cartonasul de apropiere
    CARD_W, CARD_H = 420, 120
    CARD_X = (CANVAS_W - CARD_W) // 2
    CARD_Y = CANVAS_H - 40 - CARD_H
    ninepatch(scene, CARD_X, CARD_Y, CARD_W, CARD_H, ui_card, 10)

    cx0 = CARD_X + 24
    cy0 = CARD_Y + 16
    draw_text(scene, cx0, cy0, "Bigger Sack", INK, 2)
    draw_text(scene, cx0, cy0 + 22, "Carry more before the walk to the dock.", INK_SOFT, 1)
    draw_text(scene, cx0, cy0 + 36, "+0.1/s", GOLD, 1)
    draw_text(scene, cx0 + 90, cy0 + 36, "Sack holds 60", INK_SOFT, 1)

    price_y = cy0 + 54
    draw_coin(scene, cx0 + 9, price_y + 8, 9)
    draw_text(scene, cx0 + 24, price_y, "18", INK, 2)

    cta = "Step on it to build"
    cta_w = text_width(cta, 1)
    draw_text(scene, CARD_X + CARD_W - 24 - cta_w, price_y + 4, cta, INK, 1)

    write_png(DEST, CANVAS_W, CANVAS_H, scene.px)
    print(f"{DEST}: {CANVAS_W}x{CANVAS_H}")


if __name__ == "__main__":
    main()
