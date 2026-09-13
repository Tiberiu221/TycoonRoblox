#!/usr/bin/env python3
"""Sprite-urile F2 (finisaj): placuta+stalp de pret, rama cartonasului de apropiere, pastila
din HUD, stalpul de plasa cumparata, coliba Primului Alergator. Acelasi pipeline ca tycoon.py --
nu unul nou: C/Rng/png din buildings.py, rampele din palette.py, soft_shadow/outline_bottom din
world.py, familia parchament-pe-lemn din ui.py (PARCHMENT/INK), reluata ca sa ui_plaque/ui_card
ramana rude vizibile cu ui_panel.

Cele trei piese cu 9 felii (ui_plaque, ui_card, ui_pill) trec prin `panel9`: orice decor (nituri)
intra STRICT in patratul de colt (border x border, pe ambele axe) -- marginile intinse si centrul
raman complet plate (o singura culoare per rand/coloana). Un rand cu zgomot in banda care se
intinde arata bine la marimea nativa si se rupe vizibil cand Roblox il intinde cu ScaleType.Slice;
verificarea e in preview_tycoon_f2.py (cartonasul randat la 220x140).

Rulare: python3 scripts/art/tycoon_f2.py   (apoi preview_tycoon_f2.py pentru foaia de comparatie)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png  # noqa: E402
from palette import WOOD, STONE, SAND, LEAF_WARM, ramp, hsv, mix  # noqa: E402
from world import soft_shadow, outline_bottom  # noqa: E402
from ui import PARCHMENT, PARCHMENT_D, PARCHMENT_L  # noqa: E402

OUT = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"

# Rampe noi, aceeasi reteta (palette.ramp), pentru materiale care nu existau inca.
WOOD_LIGHT = ramp(hue=30, sat=0.38, val=0.60, steps=5, hue_shift=9, val_span=0.34)  # rama cardului
WOOD_DARK = ramp(hue=25, sat=0.42, val=0.30, steps=5, hue_shift=8, val_span=0.40)  # pastila HUD
ROPE = ramp(hue=39, sat=0.30, val=0.60, steps=5, hue_shift=8, val_span=0.34)  # franghia stalpului de plasa
# Papura uscata pentru streasina colibei: LEAF_WARM (acelasi verde ca goods_reeds) impinsa spre
# SAND, ca sa citeasca drept "stuf uscat", nu "iarba" -- si sa nu se confunde cu ROOF_GREEN.
THATCH = [mix(LEAF_WARM[i], SAND[i], 0.45) for i in range(5)]

PARCHMENT_LIGHT = hsv(45, 0.07, 0.99)  # cardul: aceeasi familie ca ui_panel, dar mai deschisa
PARCHMENT_LIGHT_HI = hsv(47, 0.04, 1.0)
PARCHMENT_LIGHT_LO = hsv(42, 0.11, 0.95)


# --------------------------------------------------------------- rama cu 9 felii, sigura la intindere
def panel9(w, h, border, wood, fill, fill_hi, fill_lo, studs=None, sheen=None):
    """Ca frame9 din ui.py, generalizata la w/h independente si FARA zgomot aleator: singurul
    decor (nituri) e plasat strict in patratul border x border din fiecare colt, ca nicio piesa
    sa nu se poata rupe cand banda intinsa (marginile + centrul) e scalata de Roblox."""
    c = C(w, h)
    c.rect(0, 0, w, h, wood[1])
    c.rect(1, 1, w - 2, h - 2, wood[2])
    c.rect(0, 0, w, 1, wood[3])
    c.rect(0, 0, 1, h, wood[3])
    c.rect(0, h - 1, w, 1, wood[0])
    c.rect(w - 1, 0, 1, h, wood[0])
    if sheen:
        c.rect(0, 0, w, 1, sheen)

    inner = border - 2
    c.rect(inner, inner, w - inner * 2, h - inner * 2, wood[0])  # santul dintre rama si fata
    fw, fh = w - (inner + 1) * 2, h - (inner + 1) * 2
    c.rect(inner + 1, inner + 1, fw, fh, fill)
    c.rect(inner + 1, inner + 1, fw, 1, fill_hi)  # ambele linii de accent raman in randul de
    c.rect(inner + 1, h - inner - 2, fw, 1, fill_lo)  # granita -- plate, deci sigure la intindere

    if studs:
        s_fill, s_hi, s_lo = studs
        for cx, cy in ((2, 2), (w - 4, 2), (2, h - 4), (w - 4, h - 4)):
            c.rect(cx, cy, 2, 2, s_fill)
            c.put(cx, cy, s_hi)
            c.put(cx + 1, cy + 1, s_lo)
    return c


def round_corners(c, w, h, cut):
    """Taie fiecare colt in trepte (alfa 0), ca patratul sa citeasca rotunjit -- taietura ramane
    STRICT sub `cut` pixeli de margine, deci nu atinge niciodata banda care se intinde."""
    T = (0, 0, 0, 0)
    for i in range(cut):
        n = cut - i
        for k in range(n):
            for xx, yy in ((k, i), (w - 1 - k, i), (k, h - 1 - i), (w - 1 - k, h - 1 - i)):
                c.px[yy][xx] = T


# --------------------------------------------------------------- placuta + stalp de pret (N?)
def ui_plaque():
    """Placuta de lemn cu pretul: aceeasi reteta ca ui_panel (rama de lemn, nituri de fier,
    fata de pergament), doar dreptunghiulara si mai joasa -- doua randuri de text (numele
    platformei, apoi pretul cu iconul de moneda), 9 felii cu colt de 8 px [spec F2]."""
    sheen = mix(WOOD[3], PARCHMENT_L, 0.35)
    return panel9(
        48, 24, 8, WOOD, PARCHMENT, PARCHMENT_L, PARCHMENT_D,
        studs=(STONE[2], STONE[3], STONE[0]), sheen=sheen,
    )


def prop_post():
    """Stalpul placutei: par de lemn infipt in mal, cu o talpa sus unde reazema placuta. NU e
    9 felii -- recuzita obisnuita de lume, ca stump/log din world.py."""
    c = C(8, 26)
    soft_shadow(c, 4, 24, 4, 2)
    c.rect(1, 1, 6, 3, WOOD[2])  # talpa de sus, unde se aseaza placuta
    c.rect(1, 1, 6, 1, WOOD[4])
    c.rect(1, 3, 6, 1, WOOD[0])
    c.rect(2, 4, 4, 16, WOOD[1])  # trunchiul
    c.rect(2, 4, 1, 16, WOOD[3])
    c.rect(5, 4, 1, 16, WOOD[0])
    for i in range(6):  # varf ascutit, infipt in mal
        w = max(1, 4 - i)
        x0 = 4 - w // 2 - 1
        c.rect(x0, 20 + i, w, 1, WOOD[0] if i % 2 else WOOD[1])
    outline_bottom(c, 0, 0, 8, 26)
    return c


# --------------------------------------------------------------- cartonasul de apropiere
def ui_card():
    """Rama cartonasului: aceeasi familie ca ui_panel (lemn + pergament + nituri), dar mai
    deschisa -- se ridica peste placuta cand jucatorul se apropie, 9 felii cu colt de 10 px."""
    sheen = mix(WOOD_LIGHT[3], PARCHMENT_LIGHT_HI, 0.35)
    return panel9(
        32, 32, 10, WOOD_LIGHT, PARCHMENT_LIGHT, PARCHMENT_LIGHT_HI, PARCHMENT_LIGHT_LO,
        studs=(STONE[2], STONE[3], STONE[1]), sheen=sheen,
    )


# --------------------------------------------------------------- pastila din HUD
def ui_pill():
    """Pastila din spatele monedelor / ratei / sacului: lemn inchis, coltul rotunjit (taiat in
    trepte) ca sa citeasca distinct de rama patrata a cartonasului -- 9 felii, colt de 8 px."""
    fill = WOOD_DARK[0]
    fill_hi = mix(WOOD_DARK[1], (255, 255, 255, 255), 0.10)
    fill_lo = mix(WOOD_DARK[0], (0, 0, 0, 255), 0.35)
    c = panel9(24, 24, 8, WOOD_DARK, fill, fill_hi, fill_lo, studs=None, sheen=None)
    c.rect(2, 1, 20, 1, mix(WOOD_DARK[3], (255, 255, 255, 255), 0.20))  # luciul de sus, plat
    round_corners(c, 24, 24, 3)
    return c


# --------------------------------------------------------------- stalpul de plasa cumparata
def prop_netpost():
    """Stalpul de pe mal dupa ce plasa e cumparata: acelasi lemn ca stalpul placutei, plus un
    capat de franghie infasurat sus si un capat scurt care atarna -- doar un CAPAT, nu toata
    plasa (aia ramane obiectul `net` existent, legat aici la randare)."""
    c = C(14, 30)
    soft_shadow(c, 7, 27, 5, 2)
    c.rect(5, 2, 4, 22, WOOD[1])  # trunchiul
    c.rect(5, 2, 1, 22, WOOD[3])
    c.rect(8, 2, 1, 22, WOOD[0])
    c.rect(4, 1, 6, 2, WOOD[2])  # cepul de sus, unde se leaga plasa
    c.rect(4, 1, 6, 1, WOOD[4])
    for idx, y in enumerate((6, 10, 14)):  # franghia infasurata, trei ture
        c.rect(3, y, 8, 2, ROPE[2] if idx % 2 == 0 else ROPE[1])
        c.rect(3, y, 8, 1, ROPE[3])
        c.put(3, y + 1, ROPE[0])
        c.put(10, y + 1, ROPE[0])
    for k in range(5):  # capatul care atarna, drept, lipit de stalp -- scurt, nu toata plasa
        c.put(8, 17 + k, ROPE[2] if k % 2 == 0 else ROPE[1])
    c.put(7, 21, ROPE[1])  # varful despletit, doua fire care se departeaza usor
    c.put(9, 21, ROPE[3])
    c.put(8, 22, ROPE[4])
    for i in range(5):  # talpa infipta in mal
        w = max(1, 4 - i)
        x0 = 6 - w // 2
        c.rect(x0, 24 + i, w, 1, WOOD[0] if i % 2 else WOOD[1])
    outline_bottom(c, 0, 0, 14, 30)
    return c


# --------------------------------------------------------------- coliba Primului Alergator
def prop_runner_hut():
    """Adapost mic pentru First Runner: doi stalpi in fata, deschisi, perete de scanduri vizibil
    in spate, acoperis din stuf uscat (THATCH, tras din LEAF_WARM ca la goods_reeds -- adapostul
    e facut din ce se prinde din rau -- dar impins spre SAND ca sa nu se confunde cu un acoperis
    ROOF_GREEN), o banca scurta inauntru cat sa citeasca drept loc de popas, nu magazie goala."""
    c = C(40, 36)
    soft_shadow(c, 20, 33, 15, 3)
    c.rect(9, 18, 22, 12, WOOD[2])  # perete din spate
    for y in range(21, 29, 3):
        c.rect(9, y, 22, 1, WOOD[1])
    c.rect(9, 18, 22, 1, WOOD[3])
    c.rect(9, 29, 22, 1, WOOD[0])
    for px in (5, 32):  # doi stalpi in fata, deschisi
        c.rect(px, 15, 3, 16, WOOD[1])
        c.rect(px, 15, 1, 16, WOOD[3])
        c.rect(px + 2, 15, 1, 16, WOOD[0])
        c.rect(px - 1, 30, 5, 2, WOOD[0])  # talpa
    c.tri_roof(1, 3, 38, 15, THATCH[2], THATCH[1], THATCH[4])
    c.rect(1, 17, 38, 1, THATCH[0])  # streasina, in umbra
    for i, x in enumerate(range(2, 38, 5)):  # franjurii de stuf, la streasina
        col = THATCH[1] if i % 2 == 0 else THATCH[2]
        c.rect(x, 18, 4, 2, col)
        c.put(x + 1, 20, col)
    c.rect(15, 27, 10, 3, WOOD[1])  # o banca / busten inauntru
    c.rect(15, 27, 10, 1, WOOD[3])
    c.rect(15, 29, 10, 1, WOOD[0])
    outline_bottom(c, 0, 0, 40, 36)
    return c


SPRITES = {
    "ui_plaque": ui_plaque,
    "prop_post": prop_post,
    "ui_card": ui_card,
    "ui_pill": ui_pill,
    "prop_netpost": prop_netpost,
    "prop_runner_hut": prop_runner_hut,
}


def main():
    for name, fn in SPRITES.items():
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path):
            raise SystemExit(f"refuz sa suprascriu {path} -- fisier existent")
        img = fn()
        png(f"{name}.png", img.w, img.h, img.px)
        print(f"{name}.png: {img.w}x{img.h}")


if __name__ == "__main__":
    main()
