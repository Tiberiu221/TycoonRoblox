#!/usr/bin/env python3
"""Paleta comuna: rampe construite cu deplasare de nuanta, ca sa nu iasa culori noroioase.

Regula (din practica pixel-art): umbrele NU sunt doar versiunea intunecata a culorii de baza.
Pe masura ce cobori in valoare, roteste nuanta spre albastru/violet si ridici putin saturatia;
pe masura ce urci, roteste spre galben si scazi saturatia. Fara asta, o rampa arata ca o singura
culoare data prin filtru de gri.
"""
import colorsys


def hsv(h, s, v):
    r, g, b = colorsys.hsv_to_rgb((h % 360) / 360.0, s, v)
    return (int(r * 255 + 0.5), int(g * 255 + 0.5), int(b * 255 + 0.5), 255)


def ramp(hue, sat, val, steps=5, hue_shift=10, sat_curve=0.10, val_span=0.42):
    """O rampa de `steps` culori, de la umbra la lumina, in jurul unei culori de baza.

    hue_shift: cate grade se roteste nuanta per pas (spre albastru in jos, spre galben in sus).
    sat_curve: cat creste saturatia in umbra si cat scade in lumina.
    val_span:  cata valoare acopera rampa in total.
    """
    out = []
    mid = (steps - 1) / 2
    for i in range(steps):
        t = (i - mid) / max(1, mid)  # -1 in umbra, +1 in lumina
        h = hue + hue_shift * t * (1 if hue_shift >= 0 else -1)
        s = min(1.0, max(0.0, sat - sat_curve * t))
        v = min(1.0, max(0.0, val + val_span * t * 0.5))
        out.append(hsv(h, s, v))
    return out


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t + 0.5) for i in range(3)) + (255,)


def shade(c, amount):
    """Intuneca (amount<0) sau lumineaza (amount>0) pastrand deplasarea de nuanta."""
    r, g, b = c[0] / 255, c[1] / 255, c[2] / 255
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    h = (h * 360 + 14 * (1 if amount > 0 else -1) * abs(amount) * 3) % 360
    s = min(1.0, max(0.0, s - 0.10 * amount))
    v = min(1.0, max(0.0, v + amount))
    return hsv(h, s, v)


# --- rampele lumii ---------------------------------------------------------
# Nuantele stau apropiate intre materiale (verde 105, apa 200, nisip 40, lemn 28) ca scena sa
# arate ca o singura lume, nu ca patru asset-uri lipite.
GRASS = ramp(hue=104, sat=0.44, val=0.52, hue_shift=12, val_span=0.34)
GRASS_DARK = ramp(hue=112, sat=0.48, val=0.42, hue_shift=12, val_span=0.24)
WATER = ramp(hue=203, sat=0.58, val=0.55, hue_shift=14, val_span=0.44)
WATER_DEEP = ramp(hue=212, sat=0.62, val=0.38, hue_shift=14, val_span=0.30)
SAND = ramp(hue=44, sat=0.34, val=0.76, hue_shift=10, val_span=0.28)
DIRT = ramp(hue=30, sat=0.40, val=0.52, hue_shift=10, val_span=0.32)
WOOD = ramp(hue=28, sat=0.50, val=0.46, hue_shift=10, val_span=0.42)
STONE = ramp(hue=220, sat=0.10, val=0.52, hue_shift=8, val_span=0.36)
LEAF = ramp(hue=118, sat=0.46, val=0.44, hue_shift=14, val_span=0.38)
LEAF_WARM = ramp(hue=84, sat=0.50, val=0.50, hue_shift=14, val_span=0.36)
FOAM = ramp(hue=190, sat=0.10, val=0.92, hue_shift=8, val_span=0.14)

# Contur comun: nu negru pur, ci o culoare inchisa si calda, ca sa nu taie scena
OUTLINE = hsv(24, 0.42, 0.16)
SHADOW = (0, 0, 0, 70)

if __name__ == "__main__":
    for name in ("GRASS", "WATER", "SAND", "WOOD", "STONE", "LEAF"):
        colors = globals()[name]
        print(f"{name:10s}", " ".join(f"#{c[0]:02x}{c[1]:02x}{c[2]:02x}" for c in colors))
