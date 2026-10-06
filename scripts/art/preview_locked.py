#!/usr/bin/env python3
"""Cum arata o platforma NECUMPARATA acum ca nu mai exista pancarda: obiectul insusi, stins.

DE CE: schimbarea asta se judeca doar cu ochiul -- "se vede ce cumperi?" si "se deosebeste
`n-am banii` de `am banii`?". Randez aici exact cele trei stari, la scara 1:1, peste ponton si
apa, ca sa le pot compara eu inainte sa fie deschis Studio.

Cifrele si tintele sunt copiate din PadController (GHOST_TINT, GHOST_FADE, READY_FADE).
Scrie un singur PNG in folderul de lucru (scripts/art/scratch.py). Rulare: python3 scripts/art/preview_locked.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preview_tycoon import load, write_png, draw_text, text_width  # noqa: E402

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEST = os.path.join(scratch.folder(), "locked_preview.png")

PIXEL_SCALE, PROP_SCALE = 3, 2
PAD_SIZE, HALF = 96, 48
NET_W, NET_H = 96, 54
LANE_Y = [732, 660, 588]
DECK_Y0, DECK_Y1 = 772, 856
PAD_Y = 812

GHOST_TINT = (26, 32, 42)
GHOST_FADE, READY_FADE, OUTLINE_FADE = 0.48, 0.12, 0.72
GOLD = (232, 178, 60)
ON_DARK = (240, 233, 218)
BAD = (190, 74, 62)
WOOD_DARK = (66, 44, 27)

# fereastra randata, in coordonate de lume
X0, X1, Y0, Y1 = 420, 1360, 520, 940
W, H = X1 - X0, Y1 - Y0

# cele trei stari, fiecare la alt x: asa se compara direct, una langa alta
CASES = [
    (560, "outline", 0),
    (860, "locked", 25),
    (1160, "ready", 9),
]


class Sheet:
    def __init__(self, name):
        self.w, self.h, self.px = load(name)


def main():
    grass, water = Sheet("grass_tile"), Sheet("water_tile")
    deck, post, net = Sheet("deck_tile"), Sheet("prop_netpost"), Sheet("prop_net_water")
    buf = bytearray(W * H * 3)

    def put(x, y, rgb, a=1.0):
        if x < 0 or y < 0 or x >= W or y >= H or a <= 0:
            return
        i = (y * W + x) * 3
        if a >= 1:
            buf[i], buf[i + 1], buf[i + 2] = rgb
            return
        buf[i] = int(buf[i] + (rgb[0] - buf[i]) * a)
        buf[i + 1] = int(buf[i + 1] + (rgb[1] - buf[i + 1]) * a)
        buf[i + 2] = int(buf[i + 2] + (rgb[2] - buf[i + 2]) * a)

    # fundal: apa deasupra liniei malului, iarba dedesubt, ponton peste ea
    for y in range(H):
        wy = Y0 + y
        for x in range(W):
            wx = X0 + x
            src = water if wy < 758 else grass
            p = src.px[(wy // PIXEL_SCALE) % src.h][(wx // PIXEL_SCALE) % src.w]
            put(x, y, (p[0], p[1], p[2]))
    for wy in range(DECK_Y0, DECK_Y1):
        for wx in range(X0, X1):
            p = deck.px[((wy - DECK_Y0) // PIXEL_SCALE) % deck.h][
                ((wx - X0) // PIXEL_SCALE) % deck.w
            ]
            if p[3]:
                put(wx - X0, wy - Y0, (p[0], p[1], p[2]), p[3] / 255)

    class Canvas:
        """Adaptorul cerut de draw_text din preview_tycoon: put() pentru pixel, rect() pentru glifa."""

        @staticmethod
        def put(x, y, c):
            put(x, y, (c[0], c[1], c[2]))

        @staticmethod
        def rect(x, y, w, h, c):
            for yy in range(int(h)):
                for xx in range(int(w)):
                    put(int(x) + xx, int(y) + yy, (c[0], c[1], c[2]))

    canvas = Canvas()

    def ghost(sheet, cx, cy, w, h, tint, fade, anchor_bottom=False):
        """Un sprite intins la (w,h), colorat ca in joc: ImageColor3 inmulteste, fade = alfa."""
        x0 = cx - w // 2
        y0 = cy - (h if anchor_bottom else h // 2)
        for yy in range(h):
            for xx in range(w):
                p = sheet.px[yy * sheet.h // h][xx * sheet.w // w]
                if not p[3]:
                    continue
                rgb = (
                    p[0] * tint[0] // 255,
                    p[1] * tint[1] // 255,
                    p[2] * tint[2] // 255,
                )
                put(x0 + xx - X0, y0 + yy - Y0, rgb, (1 - fade) * p[3] / 255)

    for cx, state, price in CASES:
        affordable = state == "ready"
        tint = (255, 255, 255) if affordable else GHOST_TINT
        fade = READY_FADE if affordable else (OUTLINE_FADE if state == "outline" else GHOST_FADE)

        post_w, post_h = post.w * PROP_SCALE, post.h * PROP_SCALE
        ghost(post, cx, PAD_Y, post_w, post_h, tint, fade, anchor_bottom=True)
        net_y = LANE_Y[0]
        ghost(net, cx, net_y, NET_W, NET_H, tint, fade)
        # funia
        rope_top, rope_bottom = PAD_Y - post_h, net_y - NET_H // 2
        rope_rgb = WOOD_DARK if affordable else GHOST_TINT
        for wy in range(rope_top, rope_bottom):
            for dx in (-1, 0, 1):
                put(cx + dx - X0, wy - Y0, rope_rgb, 1 - fade)

        if state == "outline":
            continue
        # pretul, deasupra plasei
        top = net_y - NET_H // 2
        label = str(price)
        col = GOLD if affordable else ON_DARK
        tw = text_width(label, 2) + 22
        tx = cx - tw // 2 - X0
        ty = top - 6 - 20 - Y0
        # placa
        for yy in range(-6, 24):
            for xx in range(-12, tw + 12):
                put(tx + xx, ty + yy, (0, 0, 0), 0.7)
        for yy in range(-1, 17):  # moneda
            for xx in range(-1, 17):
                if (xx - 8) ** 2 + (yy - 8) ** 2 <= 64:
                    put(tx + xx, ty + yy, GOLD)
        draw_text(canvas, tx + 22, ty, label, col + (255,), 2)
        if not affordable:
            need = f"NEED {price - 3} MORE"
            nw = text_width(need, 1)
            for yy in range(-5, 13):
                for xx in range(-8, nw + 8):
                    put(cx - nw // 2 - X0 + xx, ty - 34 + yy, (0, 0, 0), 0.7)
            draw_text(canvas, cx - nw // 2 - X0, ty - 34, need, BAD + (255,), 1)
            # bara de progres
            for xx in range(152):
                frac = xx < 152 * 0.4
                put(cx - 76 + xx - X0, ty - 18, (74, 58, 44) if not frac else GOLD)

        tag = {"locked": "LOCKED", "ready": "READY"}[state]
        draw_text(canvas, cx - text_width(tag, 1) // 2 - X0, H - 16, tag, (255, 255, 255, 255), 1)

    rows = [
        [(buf[(y * W + x) * 3], buf[(y * W + x) * 3 + 1], buf[(y * W + x) * 3 + 2], 255)
         for x in range(W)]
        for y in range(H)
    ]
    write_png(DEST, W, H, rows)
    print(f"scris {DEST} ({W}x{H})")


if __name__ == "__main__":
    main()
