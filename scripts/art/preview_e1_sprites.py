#!/usr/bin/env python3
"""Coala de contact pentru sprite-urile E1.9: fiecare la 4x, pe pergament SI pe lemn inchis.

De ce ambele fundaluri: jumatate din pictogramele astea stau pe pastile inchise (HUD) si jumatate
pe panouri de pergament. O pictograma cu contur maro pe lemn maro dispare -- vreau sa vad asta
aici, nu in Studio.

Rulare: python3 scripts/art/preview_e1_sprites.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C  # noqa: E402
from preview_tycoon import load, write_png, blit_scaled, draw_text, text_width  # noqa: E402
from palette import hsv  # noqa: E402

NAMES = [
    "icon_coin", "icon_pearl", "icon_idle", "icon_lock",
    "icon_capacity", "icon_speed", "icon_carry", "icon_levelup",
    "ui_badge", "ui_levelbadge", "ui_book", "ui_hand",
    "ui_glow", "prop_wheel", "ui_wheel", "chapter_landing",
]
SCALE = 4
CELL = 4 + 96 * SCALE // 2  # destul pentru cel mai lat (96 la 2x) -- restul se centreaza
PARCH = hsv(40, 0.16, 0.93)
DARK = hsv(28, 0.34, 0.24)
INK = hsv(26, 0.45, 0.20)


def main():
    cols = 4
    cw, ch = 208, 232
    rows = (len(NAMES) + cols - 1) // cols
    w, h = cols * cw, rows * ch * 2
    c = C(w, h)
    for band, (bg, fg) in enumerate(((PARCH, INK), (DARK, hsv(40, 0.12, 0.96)))):
        c.rect(0, band * rows * ch, w, rows * ch, bg)
        for i, name in enumerate(NAMES):
            sw, sh, px = load(name)
            s = SCALE if max(sw, sh) <= 40 else 2
            ox = i % cols * cw + (cw - sw * s) // 2
            oy = band * rows * ch + i // cols * ch + 16 + (140 - sh * s) // 2
            blit_scaled(c, sw, sh, px, ox, oy, s)
            label = f"{name} {sw}x{sh}"
            draw_text(c, i % cols * cw + (cw - text_width(label, 2)) // 2,
                      band * rows * ch + i // cols * ch + 170, label, fg, 2)
    out = "/tmp/e1_sprites.png"
    write_png(out, w, h, c.px)
    print(f"{out}  {w}x{h}")


if __name__ == "__main__":
    main()
