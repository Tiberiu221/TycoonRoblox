#!/usr/bin/env python3
"""Pictogramele obiectelor de colectie: item_icons.png, 24x24 per obiect, 8 pe rand.

7 SILUETE (cate una per `family` din ItemConfig.FAMILIES) x rampa de 5 trepte construita din
`accent`-ul fiecarui obiect = 36 pictograme din 7 desene. Familia alege FORMA (recunoscuta
instant, diferita clar de celelalte sase); accentul aleg CULOAREA -- intreaga silueta e
recolorata cu rampa, nu doar umpluta plat. Asta e exact ce cere ItemConfig.luau: "un obiect
nou nu cere desen nou, alege o familie si o culoare".

Contur: OUTLINE din palette.py, trasat automat in jurul siluetei (aceeasi tehnica ca
`outline()` din settlers.py -- orice pixel transparent vecin cu un pixel opac devine contur),
nu desenat manual pixel cu pixel. Volumul vine din rampa: umbra (r0/r1), baza (r2), lumina
(r3/r4), plus 1-2 detalii mici (balama, snur, reflex) in fiecare desen.

Rulare: python3 scripts/art/items.py
"""
import colorsys
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, Rng, png  # noqa: E402
from palette import OUTLINE, ramp  # noqa: E402

SIZE = 24
COLS = 8

# Oglindeste (id, family, accent) din src/Shared/Config/ItemConfig.luau, in ordinea din
# ItemConfig.ITEMS. NU e sursa de adevar -- daca lista de-acolo se schimba, se actualizeaza si
# aici (fisierul .luau nu poate fi `import`-at direct din Python).
ITEMS = [
    ("nail_tin", "vessel", (150, 124, 96)),
    ("blunt_hatchet", "tool", (128, 132, 138)),
    ("cracked_jug", "vessel", (176, 136, 104)),
    ("sodden_ledger", "paper", (196, 182, 150)),
    ("one_good_boot", "cloth", (96, 70, 52)),
    ("copper_coil", "mech", (190, 118, 66)),
    ("chipped_plate", "vessel", (226, 228, 232)),
    ("painted_float", "trinket", (208, 84, 74)),
    ("rusted_hinge", "mech", (156, 92, 58)),
    ("barrel_staves", "tool", (158, 122, 78)),
    ("brass_padlock", "mech", (204, 164, 74)),
    ("surveyors_chain", "tool", (140, 146, 152)),
    ("tin_whistle", "instrument", (186, 190, 196)),
    ("glass_demijohn", "vessel", (120, 174, 158)),
    ("sailors_knife", "tool", (168, 172, 178)),
    ("wool_blanket", "cloth", (148, 96, 88)),
    ("seed_tin", "vessel", (128, 158, 94)),
    ("lamp_burner", "mech", (198, 150, 72)),
    ("ships_lantern", "vessel", (226, 186, 96)),
    ("brass_sextant", "instrument", (212, 168, 78)),
    ("clockwork_movement", "mech", (206, 176, 110)),
    ("printers_tray", "paper", (118, 110, 104)),
    ("annotated_map", "paper", (206, 190, 148)),
    ("still_coil", "mech", (196, 112, 60)),
    ("silver_locket", "trinket", (214, 218, 226)),
    ("music_box", "instrument", (158, 104, 176)),
    ("surgeons_case", "tool", (92, 76, 96)),
    ("brass_telescope", "instrument", (218, 172, 84)),
    ("ledger_of_debts", "paper", (172, 88, 84)),
    ("clockmakers_lathe", "mech", (132, 140, 156)),
    ("river_bell", "mech", (234, 190, 92)),
    ("orrery_fragment", "instrument", (224, 182, 104)),
    ("sealed_strongbox", "vessel", (108, 92, 78)),
    ("captains_coat", "cloth", (62, 78, 118)),
    ("drowned_organ_pipe", "instrument", (190, 200, 214)),
    ("upstream_charter", "paper", (222, 206, 158)),
]


def accent_ramp(accent):
    """5 trepte umbra->lumina din accentul rgb al obiectului, cu aceeasi deplasare de nuanta
    ca restul lumii (palette.ramp, parametrii impliciti -- cei folositi si pentru WOOD)."""
    h, s, v = colorsys.rgb_to_hsv(accent[0] / 255.0, accent[1] / 255.0, accent[2] / 255.0)
    return ramp(h * 360, s, v, steps=5)


def outline_silhouette(c, col=OUTLINE):
    """Contur inchis in jurul siluetei desenate (ca `outline()` din settlers.py): orice pixel
    transparent vecin ortogonal cu un pixel opac devine culoarea de contur. Nu atinge muchiile
    interne dintre doua zone opace -- doar conturul exterior."""
    src = [row[:] for row in c.px]
    h, w = c.h, c.w
    for y in range(h):
        for x in range(w):
            if src[y][x][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[ny][nx][3] != 0:
                    c.px[y][x] = col
                    break


# ------------------------------------------------------------------ cele 7 siluete de familie
def draw_tool(r):
    """Ciocan: cap dreptunghiular sus (cu brida de metal unde intra coada), coada verticala
    jos. Silueta in T, axe drepte -- se citeste sigur ca "unealta", spre deosebire de o pana
    de topor in unghi, care la 24px se putea confunda cu o duza."""
    c = C(SIZE, SIZE)
    c.rect(4, 3, 16, 9, r[2])    # capul ciocanului
    c.rect(4, 3, 16, 1, r[4])
    c.rect(4, 11, 16, 1, r[0])
    c.rect(4, 3, 1, 9, r[3])
    c.rect(19, 3, 1, 9, r[0])
    c.rect(10, 3, 4, 9, r[1])    # brida de metal, la imbinarea cu coada
    c.rect(10, 3, 1, 9, r[3])
    c.rect(13, 3, 1, 9, r[0])
    c.rect(10, 11, 4, 11, r[1])  # coada
    c.rect(10, 11, 1, 11, r[3])
    c.rect(13, 11, 1, 11, r[0])
    c.rect(10, 20, 4, 2, r[0])   # maner infasurat la baza
    c.rect(10, 20, 4, 1, r[3])
    c.put(6, 5, r[4])            # sclipire pe capetele metalice
    c.put(17, 5, r[4])
    outline_silhouette(c)
    return c


def draw_vessel(r):
    """Ulcior: burta rotunda, gat ingust cu buza rasfranta, toarta pe dreapta."""
    c = C(SIZE, SIZE)
    c.ellipse(11, 15, 7, 6, r[1])
    c.ellipse(9, 13, 4, 4, r[3])
    c.ellipse(13, 18, 3, 3, r[0])
    c.rect(9, 5, 5, 7, r[2])
    c.rect(9, 5, 2, 7, r[3])
    c.rect(12, 5, 2, 7, r[1])
    c.rect(8, 3, 7, 2, r[3])
    c.rect(8, 4, 7, 1, r[0])
    c.rect(13, 6, 3, 2, r[2])
    c.rect(15, 6, 2, 8, r[2])
    c.rect(13, 13, 4, 2, r[2])
    c.rect(15, 8, 1, 4, r[0])
    c.rect(6, 20, 10, 2, r[0])
    c.put(9, 12, r[4])  # reflex pe smalt/sticla
    outline_silhouette(c)
    return c


def draw_mech(r):
    """Angrenaj: roata dintata, 4 dinti drepti (N/S/E/V) + 4 dinti de colt, bolt central.
    Dintii sunt dreptunghiuri crude, nu un cerc cu varfuri -- altfel se citeste ca o floare."""
    c = C(SIZE, SIZE)
    c.rect(10, 2, 4, 4, r[3])    # dinte sus (lumina)
    c.rect(10, 18, 4, 4, r[0])   # dinte jos (umbra)
    c.rect(2, 10, 4, 4, r[3])    # dinte stanga (lumina)
    c.rect(18, 10, 4, 4, r[0])   # dinte dreapta (umbra)
    c.rect(5, 5, 4, 4, r[2])     # dinte colt stanga-sus
    c.rect(15, 5, 4, 4, r[2])    # dinte colt dreapta-sus
    c.rect(5, 15, 4, 4, r[1])    # dinte colt stanga-jos
    c.rect(15, 15, 4, 4, r[1])   # dinte colt dreapta-jos
    c.ellipse(12, 12, 7, 7, r[2])
    c.ellipse(11, 11, 6, 6, r[1])
    c.ellipse(10, 10, 4, 4, r[3])
    c.ellipse(13, 13, 3, 3, r[0])
    c.ellipse(12, 12, 2, 2, r[0])
    c.put(11, 11, r[4])  # sclipire pe bolt
    outline_silhouette(c)
    return c


def draw_cloth(r):
    """Camasa impaturita: maneci pliate in lateral, guler, cusaturi -- o silueta cu "umeri",
    limpede diferita de dreptunghiul neted al hartiei legate (paper)."""
    c = C(SIZE, SIZE)
    c.rect(3, 8, 5, 5, r[2])       # maneca stanga, pliata peste piept
    c.rect(3, 8, 5, 1, r[3])
    c.rect(3, 12, 5, 1, r[0])
    c.rect(16, 8, 5, 5, r[2])      # maneca dreapta
    c.rect(16, 8, 5, 1, r[3])
    c.rect(16, 12, 5, 1, r[0])
    c.rect(10, 6, 4, 3, r[0])      # gulerul, intre maneci
    c.rect(7, 8, 10, 13, r[1])     # trunchiul (piept + poale)
    c.rect(7, 8, 10, 1, r[3])
    c.rect(7, 20, 10, 1, r[0])
    for yy in (11, 14, 17):        # cusaturi orizontale
        c.rect(7, yy, 10, 1, r[0])
    rng = Rng(7331)
    for _ in range(7):             # tesatura, cateva fire mai deschise
        x, y = rng.i(8, 15), rng.i(12, 19)
        c.put(x, y, r[3] if rng.n() < 0.5 else r[0])
    c.put(11, 9, r[4])             # doi nasturi
    c.put(11, 16, r[4])
    outline_silhouette(c)
    return c


def draw_paper(r):
    """Sul de hartie: capete rulate vizibile, snur legat la mijloc."""
    c = C(SIZE, SIZE)
    c.ellipse(5, 12, 3, 7, r[1])
    c.ellipse(5, 12, 2, 5, r[3])
    c.rect(5, 5, 14, 14, r[2])
    c.rect(5, 5, 14, 1, r[3])
    c.rect(5, 18, 14, 1, r[0])
    for yy in (9, 12, 15):
        c.rect(6, yy, 12, 1, r[1])
    c.ellipse(19, 12, 3, 7, r[1])
    c.rect(10, 4, 4, 16, r[0])
    c.rect(11, 4, 2, 16, r[1])
    c.put(6, 9, r[4])  # reflex pe hartie
    outline_silhouette(c)
    return c


def draw_trinket(r):
    """Medalion mic: lant in zigzag, inel de prindere, corp oval cu fateta."""
    c = C(SIZE, SIZE)
    for i in range(3):
        c.rect(10 + (i % 2), 2 + i * 2, 2, 2, r[0])
    c.ellipse(11, 9, 3, 3, r[1])
    c.ellipse(11, 9, 2, 2, r[2])
    c.ellipse(11, 9, 1, 1, r[0])
    c.ellipse(11, 16, 5, 5, r[1])
    c.ellipse(10, 15, 3, 3, r[3])
    c.ellipse(12, 17, 2, 2, r[0])
    c.rect(9, 15, 4, 1, r[4])
    c.put(9, 14, r[4])  # fateta
    outline_silhouette(c)
    return c


def draw_instrument(r):
    """Luneta: tub orizontal, pavilion evazat spre obiectiv (stanga, cu lentila), ocular
    ingust in inele (dreapta). Evazarea e o coloana-cu-coloana (ca acoperisurile din
    buildings.py), nu blocuri mari suprapuse -- altfel taparea iese in trepte, nu in con."""
    c = C(SIZE, SIZE)
    heights = [6, 7, 8, 9, 10]
    for i, hh in enumerate(heights):
        x = 7 - i
        y = 12 - hh // 2
        c.rect(x, y, 1, hh, r[1] if i % 2 == 0 else r[2])
    c.rect(8, 10, 11, 5, r[2])
    c.rect(8, 10, 11, 1, r[3])
    c.rect(8, 14, 11, 1, r[0])
    c.rect(19, 10, 4, 5, r[1])
    c.rect(19, 10, 4, 1, r[3])
    c.rect(19, 14, 4, 1, r[0])
    c.rect(22, 10, 1, 5, r[0])
    for x in (12, 16, 19):  # inele de imbinare
        c.rect(x, 10, 1, 5, r[0])
    c.ellipse(2, 12, 2, 3, r[0])  # deschiderea lentilei, la capatul evazat
    c.put(1, 10, r[4])  # sclipirea lentilei
    outline_silhouette(c)
    return c


DRAW = {
    "tool": draw_tool,
    "vessel": draw_vessel,
    "mech": draw_mech,
    "cloth": draw_cloth,
    "paper": draw_paper,
    "trinket": draw_trinket,
    "instrument": draw_instrument,
}

assert set(DRAW) == {
    "tool", "vessel", "mech", "cloth", "paper", "trinket", "instrument",
}, "DRAW trebuie sa acopere exact ItemConfig.FAMILIES"


def build_sheet():
    """Deseneaza toate obiectele si le aseaza pe foaie, COLS pe rand, in ordinea ITEMS."""
    rows = (len(ITEMS) + COLS - 1) // COLS
    sheet = C(SIZE * COLS, SIZE * rows)
    mapping = {}
    for idx, (item_id, family, accent) in enumerate(ITEMS):
        draw_fn = DRAW.get(family)
        if draw_fn is None:
            raise ValueError(
                f"familie necunoscuta '{family}' pentru '{item_id}' -- "
                f"vezi ItemConfig.FAMILIES ({sorted(DRAW)})"
            )
        icon = draw_fn(accent_ramp(accent))
        col, row = idx % COLS, idx // COLS
        ox, oy = col * SIZE, row * SIZE
        for yy in range(SIZE):
            for xx in range(SIZE):
                p = icon.px[yy][xx]
                if p[3]:
                    sheet.put(ox + xx, oy + yy, p)
        mapping[item_id] = (col, row)
    return sheet, mapping


def main():
    sheet, mapping = build_sheet()
    png("item_icons.png", sheet.w, sheet.h, sheet.px)
    print(f"item_icons.png: {sheet.w}x{sheet.h} px ({len(ITEMS)} obiecte, {COLS} pe rand)")
    print("mapping id -> (coloana, rand):")
    for item_id, (col, row) in mapping.items():
        print(f"  {item_id:22s} -> ({col}, {row})")


if __name__ == "__main__":
    main()
