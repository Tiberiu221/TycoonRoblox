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

# [owner, 2026-09-14] fara randul "Reward: 1 pearl": recompensa sta pe butonul Claim ("Claim 1 (perla)"), deci
# butonul e mai lat (130) si randul mai scund (60)
QUEST_ROW = dict(
    panel="Quests (QuestController)", panel_w=560, row_h=60,
    boxes=lambda w: [
        ("text", md, 10, 270, 20, "open"),
        ("counter", md + 334 - 60, 12, 60, 18, "open"),
        ("bar", md, 38, 290, 6, "open"),
        ("lockIcon", md, 21, 18, 18, "locked"),
        ("lock", md + 24, 19, 282, 22, "locked"),
        ("button", w - md - 130, 60 // 2 - 22, 130, 44, "open"),
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
        ("milestoneBar", 0, 169, w, 5, "building"),  # [D62] drumul pana la pragul urmator
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


# Cardul obiectului (InteractController) [D51]: actiunea SAU starea (niciodata amandoua) si Upgrade. [D58] Butonul
# Upgrade creste dupa eticheta (cel putin 180): cel mai lat text e "Upgrade (U) · 123.45K" (21 de caractere de 0.5586 em
# la 18 px = 211 px) -> 28 pictograma + 8 + 211 + 2 x 18 margine = 284.
UPGRADE_MAX_W = 284
INTERACT_CARD = dict(
    panel="Object card (InteractController)", width=240 + 8 + UPGRADE_MAX_W, row_h=44,
    boxes=lambda w: [
        ("action", 0, 2, 240, 40, "action"),
        ("status", 0, 2, 240, 40, "status"),
        ("upgrade", 248, 2, UPGRADE_MAX_W, 40, None),
    ],
)


# Panoul "Sound" (AudioPanel) [D54]: fereastra 520x240 -> corpul 480x144 (rama lg=20, antetul de 56).
# Doua randuri, la y 10 si 70: numele, "-", cele zece segmente (zona de apasare, 40 inalta; desenul, cel
# mult 24, sta in ea), "+", valoarea aliniata la dreapta. Fara muzica urcata ramane doar al doilea rand,
# mutat sus, intr-o fereastra cu 60 mai scunda -- aceleasi cutii.
def audio_row(y, tag):
    return [
        (f"{tag}.name", 0, y + 10, 96, 28, None),
        (f"{tag}.minus", 104, y + 4, 44, 40, None),
        (f"{tag}.segments", 158, y + 4, 10 * 14 + 9 * 4, 40, None),
        (f"{tag}.plus", 344, y + 4, 44, 40, None),
        (f"{tag}.value", 396, y + 10, 84, 28, None),
    ]


AUDIO_PANEL = dict(
    panel="Sound (AudioPanel)", width=520 - 20 * 2, row_h=240 - 20 * 2 - 56,
    boxes=lambda w: audio_row(10, "music") + audio_row(70, "sounds"),
)


# [D59] Roata (WheelController): fereastra 640x420 -> corpul 600x324 (rama lg=20, antetul de 56). Fata timonierului in
# stanga (220, sub ac), rezultatul sub ea; lista premiilor in dreapta (Widgets.List la x 260, 256 inalta), iar butonul
# Spin sau ceasul sub lista (butonul si ceasul nu apar niciodata deodata).
WHEEL_PANEL = dict(
    panel="Lucky Wheel (WheelController)", width=640 - 20 * 2, row_h=420 - 20 * 2 - 56,
    boxes=lambda w: [
        ("needle", 10 + 110 - 20, 0, 40, 30, None),
        ("face", 10, 30, 220, 220, None),
        ("result", 0, 262, 240, 44, None),
        ("list", 260, 0, w - 260, 256, None),
        ("spin", 260 + (w - 260) // 2 - 110, 324 - 52, 220, 52, "ready"),
        ("timer", 260 + (w - 260) // 2 - 160, 324 - 28, 320, 28, "wait"),
    ],
)

# [D59] Un rand din lista premiilor (WheelController): rand de 26 in lista de 340 (lista -16, bara, Row -10).
WHEEL_ROW = dict(
    panel="Lucky Wheel rows (WheelController)", width=340 - 16 - SCROLLBAR - 10, row_h=26,
    boxes=lambda w: [
        ("icon", SPACE["sm"], 3, 20, 20, None),
        ("label", SPACE["sm"] + 26, 2, 200, 22, None),
        ("odds", w - SPACE["sm"] - 52, 2, 52, 22, None),
    ],
)

# [D59] Avizierul satului (VillageController): randul de 64. Starea ("Built"/"Wearing") si butonul stau in acelasi loc,
# dar nu apar deodata.
BOARD_ROW = dict(
    panel="Village Board (VillageController)", panel_w=600, row_h=64,
    boxes=lambda w: [
        ("art", md, 6, 56, 52, None),
        ("name", 80, 10, 250, 22, None),
        ("sub", 80, 36, 250, 18, None),
        ("state", w - md - 150, 64 // 2 - 12, 150, 24, "owned"),
        ("button", w - md - 150, 64 // 2 - 22, 150, 44, "buy"),
    ],
)

# [D59] Jurnalul (JournalController): randul de 56. Un bilet ia tot randul in locul numelui, raritatii si cifrelor.
JOURNAL_ROW = dict(
    panel="Journal (JournalController)", panel_w=600, row_h=56,
    boxes=lambda w: [
        ("icon", md, 8, 50, 40, None),
        ("name", 74, 8, 200, 22, "fish"),
        ("sub", 74, 32, 200, 18, "fish"),
        ("right", w - md - 220, 56 // 2 - 20, 220, 40, "fish"),
        ("note", 74, 56 // 2 - 24, w - 86, 48, "note"),
    ],
)


# [D60] Titlurile (TitleController): rand de 56 in lista panoului de 600. Randurile de titlu de parte ("Earned") au doar
# textul lor, pe un rand de 28 -- verificate separat, ca sa nu se amestece starile.
TITLE_ROW = dict(
    panel="Titles (TitleController)", panel_w=600, row_h=56,
    boxes=lambda w: [
        ("icon", md, 14, 28, 28, None),
        ("name", 56, 8, 280, 22, None),
        ("sub", 56, 32, 280, 18, None),
        ("state", w - md - 150, 56 // 2 - 12, 150, 24, "wearing"),
        ("button", w - md - 150, 56 // 2 - 22, 150, 44, "wear"),
    ],
)
TITLE_HEAD = dict(
    panel="Titles, titlul de parte (TitleController)", panel_w=600, row_h=28,
    boxes=lambda w: [("head", SPACE["xs"], 4, w - SPACE["xs"] * 2, 20, None)],
)

# [D60] Vitrina negustorului (MarketController): randurile stau direct in corpul panoului (fara lista), 600 - rama.
MARKET_ROW = dict(
    panel="Market (MarketController)", panel_w=600, width=600 - SPACE["lg"] * 2, row_h=64,
    boxes=lambda w: [
        ("art", md, 6, 52, 52, None),
        ("name", 80, 10, 250, 22, None),
        ("sub", 80, 36, 250, 18, None),
        ("state", w - md - 150, 64 // 2 - 12, 150, 24, "owned"),
        ("button", w - md - 150, 64 // 2 - 22, 150, 44, "buy"),
    ],
)

# [D60] Panoul mare al clasamentelor (BoardController): rand de 30 in lista panoului de 640.
LEADERBOARD_ROW = dict(
    panel="Leaderboards (BoardController)", panel_w=640, row_h=30,
    boxes=lambda w: [
        ("rank", SPACE["sm"], 4, 40, 22, None),
        ("name", 52, 4, 250, 22, None),
        ("value", w - SPACE["sm"] - 240, 4, 240, 22, None),
    ],
)

# [D60] Un panou pictat pe scena (BoardController.buildPanels): 49 de pixeli de desen x3, randuri de 20. Locul sta in
# insigna de peste patratelul pictat (centrul la 15; 22 de lat cand are doua cifre), textul incepe dupa el, la 27.
STAGE_TEXT_X, STAGE_VALUE_W = 27, 60
STAGE_PANEL = dict(
    panel="Scena, un panou (BoardController)", width=49 * 3, row_h=20,
    boxes=lambda w: [
        ("rank", 15 - 22 // 2, 2, 22, 16, None),
        ("name", STAGE_TEXT_X, 0, (w - 4) - STAGE_VALUE_W - 2 - STAGE_TEXT_X, 20, None),
        ("value", (w - 4) - STAGE_VALUE_W, 0, STAGE_VALUE_W, 20, None),
    ],
)

# [D61] Panoul gheretelor (BoothController): fereastra fixa 560x470 -> corpul 520x374. Zona jocului sus, dedesubt
# ajutorul, progresul, jocurile cu premiu si nota (stanga), butonul (dreapta).
BOOTH_PANEL = dict(
    panel="Booth (BoothController)", width=560 - SPACE["lg"] * 2, row_h=470 - SPACE["lg"] * 2 - 56,
    boxes=lambda w: [
        ("area", 0, 0, 520, 250, None),
        ("help", 0, 256, w, 20, None),
        ("progress", 0, 282, 300, 22, None),
        ("prizeGames", 0, 310, 300, 20, None),
        ("hint", 0, 334, 300, 18, None),
        ("button", w - 190, 314, 190, 52, None),
    ],
)

# [D60] Cardul altui jucator (PlayerCardController): fereastra fixa 480x460 -> corpul 440x364 (rama lg, antetul 56).
PLAYER_CARD = dict(
    panel="Player card (PlayerCardController)", width=480 - SPACE["lg"] * 2, row_h=460 - SPACE["lg"] * 2 - 56,
    boxes=lambda w: [
        ("portrait", 0, 0, 96, 104, None),
        ("name", 112, 4, w - 112, 28, None),
        ("title", 112, 38, w - 112, 24, None),
        ("era", 112, 70, w - 112, 20, None),
    ] + [
        box
        for i in range(5)
        for box in (
            (f"label{i}", 0, 120 + i * 34, 200, 24, None),
            (f"value{i}", w - 220, 120 + i * 34, 220, 24, None),
        )
    ] + [("friend", w // 2 - 110, (460 - SPACE["lg"] * 2 - 56) - 48, 220, 48, None)],
)

# [D61, partea 2] Croitoreasa (TailorController): fereastra fixa 680x520 -> corpul 640x424. In stanga omul tau, eticheta
# si `Save look`; in dreapta filele si, dupa fila, fie cele patru randuri de infatisare, fie lista de tinute.
TAILOR_SIDE_X = 200 + 16
TAILOR_SIDE_W = 680 - SPACE["lg"] * 2 - TAILOR_SIDE_X
TAILOR_PANEL = dict(
    panel="Tailor (TailorController)", width=680 - SPACE["lg"] * 2, row_h=520 - SPACE["lg"] * 2 - 56,
    boxes=lambda w: [
        ("preview", 0, 0, 200, 300, None),
        ("trying", 0, 308, 200, 20, None),
        ("save", 0, 336, 200, 44, "look"),
        ("tabLook", TAILOR_SIDE_X, 0, 150, 40, None),
        ("tabOutfits", TAILOR_SIDE_X + 158, 0, 150, 40, None),
        ("outfits", TAILOR_SIDE_X, 52, TAILOR_SIDE_W, (520 - SPACE["lg"] * 2 - 56) - 52, "outfits"),
    ] + [
        (f"lookRow{i}", TAILOR_SIDE_X, 52 + i * 68, TAILOR_SIDE_W, 60, "look")
        for i in range(4)
    ],
)
# un rand de infatisare: numele campului, sageata, valoarea, pata de culoare, sageata
TAILOR_LOOK_ROW = dict(
    panel="Tailor, un rand de infatisare (TailorController)", width=TAILOR_SIDE_W, row_h=60,
    boxes=lambda w: [
        ("label", 14, 0, 140, 60, None),
        ("prev", 160, 8, 44, 44, None),
        ("value", 210, 0, w - 58 - 8 - 210 - 40, 60, None),
        ("swatch", w - 58 - 12 - 28, 16, 28, 28, None),
        ("next", w - 58, 8, 44, 44, None),
    ],
)
# un rand de tinuta, in lista din dreapta (Widgets.List: +8/-16, randul -10)
TAILOR_OUTFIT_ROW = dict(
    panel="Tailor, un rand de tinuta (TailorController)", width=TAILOR_SIDE_W - 16 - 10, row_h=64,
    boxes=lambda w: [
        ("art", 10, 4, 40, 56, None),
        ("name", 60, 10, 186, 22, None),
        ("sub", 60, 36, 186, 18, "buy"),
        ("subJournal", 60, 36, 326, 18, "journal"),
        ("state", w - md - 130, 64 // 2 - 12, 130, 24, "wearing"),
        ("button", w - md - 130, 64 // 2 - 22, 130, 44, "buy"),
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
    bad = sum(check(spec) for spec in (STATION_ROW, QUEST_ROW, APPROACH_CARD, STATION_MENU, INTERACT_CARD, AUDIO_PANEL,
                                      WHEEL_PANEL, WHEEL_ROW, BOARD_ROW, JOURNAL_ROW,
                                      TITLE_ROW, TITLE_HEAD, MARKET_ROW, LEADERBOARD_ROW, STAGE_PANEL,
                                      PLAYER_CARD, BOOTH_PANEL,
                                      TAILOR_PANEL, TAILOR_LOOK_ROW, TAILOR_OUTFIT_ROW))
    if bad:
        raise SystemExit(f"{bad} coliziuni de asezare")


if __name__ == "__main__":
    main()
