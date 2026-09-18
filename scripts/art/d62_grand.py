#!/usr/bin/env python3
"""[D62, pasul 5] CLADIRILE LANTULUI LA NIVELUL 25: a doua infatisare a gaterului, a tavernei si a forjei.

De ce: nivelurile cladirilor urca fara capat, dar cladirea arata la nivelul 40 exact ca la nivelul 1 (auditul D62: "nimic
din ce cumperi nu se vede"). La pragul 25 (ChainMath.rankOf = 2, acelasi prag la care venitul se dubleaza) cladirea se
schimba: temelie de piatra, felinare aprinse, stegulete, marfa mai multa, lucarna tavernei, focul forjei.

Fiecare varianta PORNESTE din desenul aprobat (aceeasi functie, aceeasi marime de foaie) si doar adauga peste el. Asa
raman la locul lor lucrurile de care se leaga jocul: panza gaterului (pictograma care se invarte), hornul tavernei si al
forjei (fumul), usa tavernei (locul de vanzare), golul forjei (focul si scanteile). Depozitul nu are niveluri in joc,
deci nu are varianta.

NU suprascrie un fisier existent decat cu --force.

Rulare: python3 scripts/art/d62_grand.py [--force] [nume ...]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ruins_d53  # noqa: E402
import tycoon_e1  # noqa: E402
from buildings import png  # noqa: E402
from palette import STONE, WOOD, ramp  # noqa: E402
from tycoon_e1 import GOLD, GOLD_HI, LOGW, PLANK, STEEL, WARM, outline_trace  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites")

FLAG_RED = ramp(6, 0.66, 0.84)
FLAG_BLUE = ramp(212, 0.50, 0.80)
LEAF = ramp(104, 0.48, 0.62)
EMBER = ramp(22, 0.86, 0.98)
MORTAR = STONE[0]


def base(module, fn):
    """Desenul aprobat, FARA contur: conturul se traseaza o singura data, la sfarsit, peste tot ce s-a adaugat (trasat
    de doua ori, ar iesi gros de doi pixeli)."""
    real = module.outline_trace
    module.outline_trace = lambda c, col=None: None
    try:
        return fn()
    finally:
        module.outline_trace = real


def foundation(c, x0, x1, y, rows=2):
    """Temelie de piatra: blocuri de cate 4 pixeli, cu rostul decalat de la un rand la altul."""
    for r in range(rows):
        for x in range(x0, x1):
            joint = (x - x0 + r * 2) % 4 == 0
            c.put(x, y + r, MORTAR if joint else (STONE[3] if r == 0 else STONE[2]))


def lantern(c, x, y):
    c.put(x, y - 1, WOOD[0])
    c.rect(x - 1, y, 3, 3, WARM[4])
    c.put(x, y + 1, GOLD_HI[4])
    c.rect(x - 1, y + 3, 3, 1, WOOD[0])


def bunting(c, x0, x1, y):
    """Stegulete pe o sfoara: rosu, auriu, albastru, cu un pixel de sfoara intre ele."""
    tones = (FLAG_RED[3], GOLD[3], FLAG_BLUE[3])
    for i, x in enumerate(range(x0, x1, 3)):
        c.put(x, y, WOOD[0])
        c.rect(x + 1, y, 2, 1, WOOD[0])
        c.rect(x + 1, y + 1, 2, 1, tones[i % 3])
        c.put(x + 1, y + 2, tones[i % 3])


def pennant(c, x, y, tone):
    """Un stegulet pe acoperis: batul si panza in vant, spre dreapta."""
    c.rect(x, y, 1, 4, WOOD[0])
    c.rect(x + 1, y, 3, 1, tone[3])
    c.rect(x + 1, y + 1, 2, 1, tone[2])


def prop_sawmill_grand():
    """Gaterul la nivelul 25 (40x32): stalpii pe temelie de piatra, felinar pe stalpul din stanga, coama acoperisului
    batuta in scandura deschisa, stegulet, al doilea bustean la rand si o stiva adevarata de scanduri gata."""
    c = base(tycoon_e1, tycoon_e1.prop_sawmill)
    # coama acoperisului si un rand de sindrila mai deschis sub ea
    c.rect(4, 2, 32, 1, PLANK[4])
    c.rect(3, 3, 34, 1, PLANK[2])
    pennant(c, 8, 0, FLAG_RED)
    # temelia: sub stalpi si sub peretele din spate
    foundation(c, 2, 38, 26, 2)
    for px in (3, 35):  # stalpii coboara peste temelie, cu o legatura de fier
        c.rect(px, 24, 3, 1, STEEL[1])
    lantern(c, 4, 12)
    # al doilea bustean, jos, asteptand la rand
    c.ellipse(15, 25.5, 7, 1.8, LOGW[1])
    c.ellipse(15, 25.0, 6, 1.2, LOGW[2])
    c.ellipse(9, 25.5, 1.6, 1.8, LOGW[4])
    # stiva de scanduri gata: doua randuri late, nu o singura scandura. Se opreste SUB panza (care ajunge pana la randul
    # 22): in joc peste ea se invarte pictograma panzei, iar o stiva mai inalta ar fi ajuns in spatele ei.
    for i in range(2):
        c.rect(23 + i, 25 - i * 2, 12 - i, 2, PLANK[3] if i % 2 else PLANK[2])
        c.rect(23 + i, 25 - i * 2, 12 - i, 1, PLANK[4])
        c.put(23 + i, 26 - i * 2, PLANK[1])
        c.put(34, 26 - i * 2, PLANK[1])
    outline_trace(c)
    return c


def prop_tavern_grand():
    """Taverna la nivelul 25 (64x48): lucarna luminata in acoperis, stegulete sub streasina, jardiniera cu flori sub
    tejghea, al doilea felinar, temelie de piatra, rama aurie la firma. Hornul, usa si tejgheaua raman unde erau."""
    c = base(tycoon_e1, tycoon_e1.prop_tavern)
    roof = tycoon_e1.TAVERN_ROOF
    # lucarna: un mic fronton cu fereastra aprinsa, in stanga hornului
    for i in range(5):
        c.rect(22 - i, 7 + i, 2 + 2 * i, 1, roof[1] if i % 2 else roof[0])
    c.rect(18, 12, 10, 5, WOOD[2])
    c.rect(18, 12, 10, 1, WOOD[3])
    c.rect(20, 13, 6, 4, WARM[3])
    c.rect(20, 13, 6, 1, WARM[4])
    c.rect(23, 13, 1, 4, WOOD[0])
    # coama de tabla deschisa
    c.rect(14, 3, 30, 1, roof[4])
    pennant(c, 30, 0, FLAG_BLUE)
    # steguletele, pe toata latimea fatadei, sub streasina
    bunting(c, 5, 44, 19)
    # jardiniera sub tejghea
    c.rect(8, 36, 19, 2, WOOD[1])
    for x in range(9, 26, 2):
        c.put(x, 36, LEAF[3])
        c.put(x + 1, 36, LEAF[2])
    for x, tone in ((10, FLAG_RED[4]), (14, GOLD_HI[4]), (18, FLAG_RED[4]), (22, GOLD_HI[4]), (25, FLAG_RED[4])):
        c.put(x, 35, tone)
    lantern(c, 6, 27)
    # rama aurie la firma cu cana si moneda
    for x in range(46, 60):
        c.put(x, 21, GOLD[2])
        c.put(x, 30, GOLD[1])
    for y in range(21, 31):
        c.put(46, y, GOLD[2])
        c.put(59, y, GOLD[1])
    foundation(c, 4, 60, 43, 2)
    # usa si butoaiele stau PESTE temelie
    c.rect(35, 43, 10, 2, PLANK[1])
    c.rect(36, 43, 8, 2, WOOD[0])
    for x in (38, 41):
        c.rect(x, 43, 1, 2, WOOD[1])
    for bx, by, h in ((48, 36, 9), (55, 38, 7)):
        c.rect(bx, 43, 6, by + h - 43, LOGW[2])
        c.rect(bx + 1, 43, 2, by + h - 43, LOGW[3])
    outline_trace(c)
    return c


def prop_workshop_grand():
    """Forja la nivelul 25 (64x48): focul aprins in fundul atelierului, un lingou incins pe banc in locul scandurii,
    nicovala in fata, horn cu guler de fier, temelie de piatra, stegulet. Golul si hornul raman unde erau."""
    c = base(ruins_d53, ruins_d53.prop_workshop_e1)
    roof = ruins_d53.WORKSHOP_ROOF
    c.rect(13, 4, 33, 1, roof[4])
    pennant(c, 24, 1, FLAG_RED)
    # hornul: guler si capac de fier
    c.rect(45, 0, 8, 1, STEEL[1])
    c.rect(46, 7, 6, 1, STEEL[1])
    # vatra: gura de foc in peretele din fund, in dreapta
    c.rect(50, 31, 6, 5, STONE[1])
    c.rect(51, 32, 4, 4, EMBER[1])
    c.rect(51, 33, 4, 3, EMBER[3])
    c.rect(52, 34, 2, 2, GOLD_HI[4])
    c.put(51, 30, EMBER[4])
    c.put(54, 29, EMBER[3])
    # lingoul incins pe banc, in locul scandurii in lucru
    c.rect(41, 34, 11, 2, WOOD[0])
    c.rect(43, 34, 7, 2, EMBER[2])
    c.rect(43, 34, 7, 1, EMBER[4])
    for x, y in ((40, 44), (45, 43), (48, 44), (37, 43)):  # scantei pe jos, nu rumegus
        c.put(x, y, EMBER[4])
    # nicovala, in fata ferestrei
    c.rect(11, 40, 9, 2, STEEL[3])
    c.rect(11, 40, 9, 1, STEEL[4])
    c.rect(19, 40, 3, 1, STEEL[3])
    c.rect(13, 42, 5, 1, STEEL[1])
    c.rect(12, 43, 7, 2, STEEL[2])
    foundation(c, 4, 60, 43, 2)
    c.rect(12, 43, 7, 2, STEEL[2])  # piciorul nicovalei, peste temelie
    c.rect(30, 43, 27, 2, WOOD[0])  # pragul golului ramane in umbra
    for x in (33, 53):
        c.rect(x, 43, 2, 2, WOOD[1])
    outline_trace(c)
    return c


SPRITES = {
    "prop_sawmill_grand": prop_sawmill_grand,
    "prop_tavern_grand": prop_tavern_grand,
    "prop_workshop_grand": prop_workshop_grand,
}


def main():
    args = sys.argv[1:]
    force = "--force" in args
    names = [a for a in args if not a.startswith("--")] or list(SPRITES)
    for name in names:
        path = os.path.join(OUT, f"{name}.png")
        if os.path.exists(path) and not force:
            print(f"  {name}.png  exista deja, sarit (--force ca sa-l rescrii)")
            continue
        c = SPRITES[name]()
        png(path, c.w, c.h, c.px)
        print(f"  {name}.png  {c.w}x{c.h}")


if __name__ == "__main__":
    main()
