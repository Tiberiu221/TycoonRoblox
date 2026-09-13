#!/usr/bin/env python3
"""Verificarea aritmetica a randurilor din panourile cu lista: nicio pereche de cutii nu se atinge.

De ce un script si nu ochiul: doua etichete suprapuse pe 14 pixeli arata "aproape bine" in Studio
si se vad abia in captura pe care o trimite owner-ul. Prima rulare a gasit sase coliziuni in
panoul de statii, dintre care patru existau de dinainte -- toate pentru ca latimea randului fusese
socotita cat panoul, uitand rama panoului, marginea listei si bara de derulare.

`state` marcheaza elementele care se exclud (un rand inchis arata lacatul, unul deschis arata
textul si contorul) -- doua cutii cu stari diferite n-au cum sa se atinga pe ecran.

Rulare: python3 scripts/art/check_panel_rows.py
"""
SPACE = {"xs": 4, "sm": 8, "md": 12, "lg": 20, "xl": 32}
SCROLLBAR = 8
md = SPACE["md"]


def row_width(panel_w):
    """Panou -> continut (rama lg pe ambele laturi) -> lista (Widgets.List: +8/-16) -> minus bara."""
    return panel_w - SPACE["lg"] * 2 - 16 - SCROLLBAR


# (nume, x, y, latime, inaltime, stare)
STATION_ROW = dict(
    panel="Upgrades (StationPanel)", panel_w=600, row_h=96,
    boxes=lambda w: [
        ("title", md, 6, 200, 22, None),
        ("level", md + 204, 6, 146, 22, None),
        ("now", md, 32, 180, 20, None),
        ("gainArrow", md + 184, 34, 16, 16, None),
        ("gain", md + 204, 32, 146, 20, None),
        ("bar", md, 60, 180, 6, None),
        ("milestone", md + 184, 56, 166, 18, None),
        ("warn", md, 96 - 22, 354, 18, None),
        ("costCoin", w - md - 150, 6, 16, 16, None),
        ("cost", w - md - 130, 4, 130, 20, None),
        ("button", w - md - 150, 96 // 2 + 4 - 23, 150, 46, None),
    ],
)

QUEST_ROW = dict(
    panel="Quests (QuestController)", panel_w=560, row_h=74,
    boxes=lambda w: [
        ("text", md, 10, 282, 20, "open"),
        ("counter", md + 290, 12, 60, 18, "open"),
        ("bar", md, 38, 290, 6, "open"),
        ("reward", md, 50, 180, 18, "open"),
        ("lockIcon", md, 28, 18, 18, "locked"),
        ("lock", md + 24, 26, 282, 22, "locked"),
        ("button", w - md - 120, 74 // 2 - 22, 120, 44, "open"),
    ],
)


# Cartonasul de la apropiere (HUDController): NU e un rand de lista -- e un cartonas fix, deci fara
# rama de panou, fara marginea listei si fara bara de derulare. 440x204 minus insetul 30/20.
# `gain` / `nogain`: cand platforma nu apasa pe veriga slaba, mesajul ia tot randul si nota se
# ascunde -- cele doua stari nu apar niciodata impreuna.
APPROACH_CARD = dict(
    panel="Approach card (HUDController)", width=440 - 30 * 2, row_h=204 - 20 * 2,
    boxes=lambda w: [
        ("eyebrow", 0, 0, w, 14, None),
        ("name", 0, 14, w, 24, None),
        ("blurb", 0, 38, w, 18, None),
        ("delta", 0, 60, 180, 20, "gain"),
        ("deltaWide", 0, 60, w, 20, "nogain"),
        ("note", w - (w - 180), 62, w - 180, 18, "gain"),
        ("coin", 0, 86, 18, 18, None),
        ("price", 24, 84, 180 - 24, 22, None),
        ("spend", w - (w - 180), 86, w - 180, 20, None),
        ("buyButton", 0, 114, w, 44, None),
    ],
)


# Meniul unui obiect (StationMenu), simplu [D52]: fereastra 600x432 -> corpul 560x336 (rama lg=20 pe
# laturi, antetul de 56). Cutii fixe, fara lista. Caseta debitului (0, 36, w, 104) e doar fundal: se
# verifica ce sta in ea (caption, rate, unit). `building` si `crew` sunt cele doua feluri de meniu --
# nu apar niciodata deodata, deci cutiile lor au voie sa stea una peste alta.
STATION_MENU = dict(
    panel="Station menu (StationMenu)", width=600 - 20 * 2, row_h=432 - 20 * 2 - 56,
    boxes=lambda w: [
        ("level", 0, 0, w, 28, None),
        ("caption", 16, 36 + 10, w - 32, 20, None),
        ("rate", 16, 36 + 32, w - 32, 38, None),
        ("unit", 16, 36 + 74, w - 32, 20, None),
        ("sub", 0, 148, w, 20, None),
        ("status", 0, 176, w - 200 - 12, 44, None),
        ("goButton", w - 200, 176, 200, 44, None),
        ("bulk1", 0, 232, 84, 36, "building"),
        ("bulk10", 92, 232, 84, 36, "building"),
        ("bulkMax", 184, 232, 84, 36, "building"),
        ("upgrade", 0, 280, w, 56, "building"),
        ("tierButton", 0, 228, w, 50, "crew"),
        ("hireButton", 0, 286, w, 50, "crew"),
    ],
)


# Cardul obiectului (InteractController) [D51]: actiunea SAU starea (niciodata amandoua) si Upgrade.
INTERACT_CARD = dict(
    panel="Object card (InteractController)", width=240 + 8 + 180, row_h=44,
    boxes=lambda w: [
        ("action", 0, 2, 240, 40, "action"),
        ("status", 0, 2, 240, 40, "status"),
        ("upgrade", 248, 2, 180, 40, None),
    ],
)


def overlap(a, b):
    if a[5] is not None and b[5] is not None and a[5] != b[5]:
        return None  # nu apar niciodata in acelasi timp
    ox = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    oy = min(a[2] + a[4], b[2] + b[4]) - max(a[2], b[2])
    return (ox, oy) if ox > 0 and oy > 0 else None


def check(spec):
    w = spec["width"] if "width" in spec else row_width(spec["panel_w"])
    boxes = spec["boxes"](w)
    origin = f"panou {spec['panel_w']}" if "panel_w" in spec else "cartonas fix"
    print(f"{spec['panel']}: {w}x{spec['row_h']} ({origin})")
    bad = 0
    for i, a in enumerate(boxes):
        if a[1] < 0 or a[1] + a[3] > w:
            print(f"  ! {a[0]} iese din rand pe orizontala: {a[1]}..{a[1] + a[3]} > {w}")
            bad += 1
        if a[2] < 0 or a[2] + a[4] > spec["row_h"]:
            print(f"  ! {a[0]} iese din rand pe verticala: {a[2]}..{a[2] + a[4]} > {spec['row_h']}")
            bad += 1
        for b in boxes[i + 1:]:
            hit = overlap(a, b)
            if hit:
                print(f"  ! {a[0]} x {b[0]} se suprapun pe {hit[0]}x{hit[1]} pixeli")
                bad += 1
    if not bad:
        print(f"  {len(boxes)} cutii, nicio suprapunere")
    return bad


def main():
    bad = sum(check(spec) for spec in (STATION_ROW, QUEST_ROW, APPROACH_CARD, STATION_MENU, INTERACT_CARD))
    if bad:
        raise SystemExit(f"{bad} coliziuni de asezare")


if __name__ == "__main__":
    main()
