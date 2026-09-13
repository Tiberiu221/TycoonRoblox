#!/usr/bin/env python3
"""Previzualizarea ruinelor si a atelierului nou [D53], inainte de urcare.

Doua imagini, in scratchpad-ul sesiunii (nimic in assets/):
  1. ruins_pairs.png -- fiecare ruina langa ce devine, la marimea din joc (x2 recuzita, x3 cladirile),
     pe iarba, iar plasele pe ponton si apa; atelierul vechi (b_workshop) langa cel nou, pentru comparatie;
  2. ruins_shore.png -- malul din primul minut, cu toate ruinele pe locul lor, la jumatate din marime:
     judeca daca e prea incarcat.

Sprite-urile noi se deseneaza direct din scripts/art/ruins_d53.py (in memorie), cele existente se citesc
din assets/sprites. Pozitiile si ancorele sunt copiate din TycoonConfig / PadController.
Rulare: python3 scripts/art/preview_ruins.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from preview_tycoon import load, write_png, draw_text, text_width  # noqa: E402
import ruins_d53  # noqa: E402

SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad"
PIXEL_SCALE, PROP_SCALE = 3, 2
LANE_Y = {1: 732, 2: 660, 3: 588}
DECK = (240, 1560, 772, 856)
LOCKED_TINT = (200, 196, 188)


class Sprite:
    def __init__(self, w, h, px):
        self.w, self.h, self.px = w, h, px


def existing(name):
    return Sprite(*load(name))


def fresh(name):
    c = ruins_d53.SPRITES[name]()
    return Sprite(c.w, c.h, c.px)


class Img:
    def __init__(self, w, h, rgb):
        self.w, self.h = w, h
        self.buf = bytearray(bytes(rgb) * (w * h))

    def blend(self, x, y, rgb, a):
        if a <= 0 or x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        i = (y * self.w + x) * 3
        if a >= 1:
            self.buf[i], self.buf[i + 1], self.buf[i + 2] = rgb[0], rgb[1], rgb[2]
            return
        for k in range(3):
            self.buf[i + k] = int(self.buf[i + k] + (rgb[k] - self.buf[i + k]) * a)

    # adaptorul pentru draw_text
    def put(self, x, y, c):
        self.blend(int(x), int(y), c, 1)

    def rect(self, x, y, w, h, c):
        for yy in range(int(h)):
            for xx in range(int(w)):
                self.blend(int(x) + xx, int(y) + yy, c, (c[3] / 255) if len(c) > 3 else 1)

    def tile(self, sheet, x0, y0, x1, y1, world_x0, world_y0, down=1):
        """Umple dreptunghiul cu textura, la scara de pixel a jocului; `down` = cati px de lume pe px."""
        for y in range(y0, y1):
            wy = world_y0 + (y - y0) * down
            for x in range(x0, x1):
                wx = world_x0 + (x - x0) * down
                p = sheet.px[(wy // PIXEL_SCALE) % sheet.h][(wx // PIXEL_SCALE) % sheet.w]
                if p[3]:
                    self.blend(x, y, p, p[3] / 255)

    def blit(self, s, cx, bottom, scale, tint=None, down=1, center_y=False):
        """Sprite ancorat jos-centru (sau centru), la `scale` px de lume pe px de sprite."""
        w, h = s.w * scale // down, s.h * scale // down
        x0 = cx - w // 2
        y0 = bottom - (h // 2 if center_y else h)
        for yy in range(h):
            for xx in range(w):
                p = s.px[yy * s.h // h][xx * s.w // w]
                if not p[3]:
                    continue
                rgb = p if tint is None else tuple(p[k] * tint[k] // 255 for k in range(3))
                self.blend(x0 + xx, y0 + yy, rgb, p[3] / 255)

    def save(self, name):
        rows = []
        for y in range(self.h):
            row = []
            for x in range(self.w):
                i = (y * self.w + x) * 3
                row.append((self.buf[i], self.buf[i + 1], self.buf[i + 2], 255))
            rows.append(row)
        path = os.path.join(SCRATCH, name)
        write_png(path, self.w, self.h, rows)
        print(f"scris {path} ({self.w}x{self.h})")


INK = (240, 234, 216, 255)
INK_SOFT = (190, 182, 166, 255)


def pairs():
    grass, water, deck = existing("grass_tile"), existing("water_tile"), existing("deck_tile")
    items = [
        # (eticheta, [(sprite, scara), ...] in ordine: ruina, construit[, vechi])
        ("NETS", "net"),
        ("COLLECTOR HUT", [("prop_ruin_hut", 3, True), ("prop_runner_hut", 3, False)]),
        ("INNKEEPER STALL", [("prop_ruin_stall", 2, True), ("prop_stall", 2, False)]),
        ("BIGGER SACK", [("prop_ruin_sack", 2, True), ("prop_sack", 2, False)]),
        ("LANDING BELL", [("prop_ruin_bell", 3, True), ("prop_bell", 3, False)]),
        ("WORKSHOP", [("prop_ruin_workshop", 3, True), ("prop_workshop_e1", 3, True), ("b_workshop", 3, False)]),
        ("HELP WANTED", "boards"),
    ]
    W, H = 1500, 1080
    img = Img(W, H, (36, 34, 38))
    cells = [(20, 20), (520, 20), (1020, 20), (20, 380), (520, 380), (1020, 380), (20, 740)]
    for (label, spec), (cx0, cy0) in zip(items, cells):
        cw = 1460 if label == "WORKSHOP" else 460
        ch = 320
        if label == "WORKSHOP":
            cx0, cy0, cw = 20, 740, 1000
        if label == "HELP WANTED":
            cx0, cy0, cw = 1040, 740, 440
        draw_text(img, cx0 + 8, cy0 + 6, label, INK, 2)
        if spec == "net":
            img.tile(water, cx0, cy0 + 28, cx0 + cw, cy0 + 220, 0, 600)
            img.tile(deck, cx0, cy0 + 220, cx0 + cw, cy0 + ch, 0, 772)
            for k, (post, net, tag) in enumerate(
                (("prop_ruin_netpost", "prop_ruin_net", "RUIN"), ("prop_netpost", "prop_net_water", "BUILT"))
            ):
                px = cx0 + 120 + k * 220
                ps = fresh(post) if post.startswith("prop_ruin") else existing(post)
                ns = fresh(net) if net.startswith("prop_ruin") else existing(net)
                img.blit(ns, px, cy0 + 110, PIXEL_SCALE, center_y=True)
                img.blit(ps, px, cy0 + 262, PROP_SCALE)
                draw_text(img, px - text_width(tag, 2) // 2, cy0 + ch - 20, tag, INK_SOFT, 2)
            continue
        img.tile(grass, cx0, cy0 + 28, cx0 + cw, cy0 + ch, 0, 1200)
        if spec == "boards":
            old, new = fresh("prop_board_old"), fresh("prop_board")
            icons = [existing("prop_log"), existing("icon_saw"), existing("goods_planks")]
            img.blit(old, cx0 + 70, cy0 + 280, PROP_SCALE)
            draw_text(img, cx0 + 70 - text_width("BEFORE", 2) // 2, cy0 + 294, "BEFORE", INK_SOFT, 2)
            for k, icon in enumerate(icons):
                bx = cx0 + 170 + k * 90
                img.blit(new, bx, cy0 + 280, PROP_SCALE)
                # pictograma, centrata pe hartie (x 12, y 15 din 24x32): 34 px deasupra bazei
                scale = 1 if icon.w > 20 else 1.4
                w = int(icon.w * scale)
                img.blit(icon, bx, cy0 + 280 - 34, 1, center_y=True) if scale == 1 else img.blit(icon, bx, cy0 + 280 - 34 + w // 2, 1)
            draw_text(img, cx0 + 260 - text_width("HIRED", 2) // 2, cy0 + 294, "HIRED", INK_SOFT, 2)
            continue
        slots = len(spec)
        for k, (name, scale, new) in enumerate(spec):
            s = fresh(name) if name in ruins_d53.SPRITES else existing(name)
            px = cx0 + cw * (2 * k + 1) // (2 * slots)
            img.blit(s, px, cy0 + 280, scale)
            tag = ("RUIN" if "ruin" in name else ("NEW" if name == "prop_workshop_e1" else ("OLD" if name == "b_workshop" else "BUILT")))
            draw_text(img, px - text_width(tag, 2) // 2, cy0 + 294, tag, INK_SOFT, 2)
    img.save("ruins_pairs.png")


def shore():
    """Malul din primul minut, la jumatate: lumea x 200..1960, y 540..1600."""
    grass, water, deck, path = existing("grass_tile"), existing("water_tile"), existing("deck_tile"), existing("path_tile")
    X0, Y0, X1, Y1, D = 200, 540, 1960, 1600, 2
    W, H = (X1 - X0) // D, (Y1 - Y0) // D
    img = Img(W, H, (86, 128, 64))

    def sx(x):
        return (x - X0) // D

    def sy(y):
        return (y - Y0) // D

    img.tile(grass, 0, 0, W, H, X0, Y0, D)
    img.tile(water, 0, 0, W, sy(772), X0, Y0, D)
    img.tile(deck, sx(DECK[0]), sy(DECK[2]), sx(DECK[1]), sy(DECK[3]), DECK[0], DECK[2], D)
    roads = [
        (240, 1800, 1100, 1160), (1470, 1520, 856, 1100), (520, 570, 856, 1100), (1570, 1630, 1160, 1480),
        (1300, 1630, 1480, 1560), (500, 1300, 1500, 1560), (500, 560, 1160, 1500),
    ]
    for x0, x1, y0, y1 in roads:
        img.tile(path, sx(x0), sy(y0), sx(x1), sy(y1), x0, y0, D)
    # lantul, construit de la inceput
    img.blit(existing("prop_tavern"), sx(400), sy(1080), PIXEL_SCALE, down=D)
    img.blit(existing("prop_storage"), sx(1600), sy(1020), PIXEL_SCALE, down=D)
    img.blit(existing("prop_sawmill"), sx(1420), sy(1480), PIXEL_SCALE, down=D)
    img.blit(existing("prop_wheel"), sx(330), sy(1420), PIXEL_SCALE, down=D)
    # ruinele, pe platformele Erei 1 (baza cladirii = pad.y + 56; plasele: stalpul la pad.y, plasa pe banda)
    nets = [("first_net", 620, 1), ("second_net", 820, 1), ("third_net", 1020, 2), ("far_lane_net", 1220, 2), ("fifth_net", 1420, 3)]
    ruin_post, ruin_net = fresh("prop_ruin_netpost"), fresh("prop_ruin_net")
    for pid, x, lane in nets:
        tint = None if pid == "first_net" else LOCKED_TINT
        img.blit(ruin_net, sx(x), sy(LANE_Y[lane]), PIXEL_SCALE, tint, D, center_y=True)
        img.blit(ruin_post, sx(x), sy(812), PROP_SCALE, tint, D)
    buildings = [
        ("prop_ruin_hut", 1760, 975, 3), ("prop_ruin_stall", 660, 1000, 2), ("prop_ruin_sack", 1060, 1300, 2),
        ("prop_ruin_workshop", 820, 1380, 3), ("prop_ruin_bell", 1770, 1420, 3),
        ("prop_board_old", 1720, 1220, 2), ("prop_board_old", 1420, 1270, 2), ("prop_board_old", 1220, 1410, 2),
    ]
    for name, x, y, scale in buildings:
        img.blit(fresh(name), sx(x), sy(y + 56), scale, LOCKED_TINT, D)
    # plasa care se ia acum: placuta cu pretul, ca in joc
    tx, ty = sx(620), sy(812 - 72)
    img.rect(tx - 20, ty - 7, 40, 14, (0, 0, 0, 180))
    draw_text(img, tx - text_width("FREE", 1) // 2, ty - 3, "FREE", (232, 178, 60, 255), 1)
    img.save("ruins_shore.png")


if __name__ == "__main__":
    pairs()
    shore()
