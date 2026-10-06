#!/usr/bin/env python3
"""[D75, lotul A4, grupul "huts_power"] Casele oamenilor barajului (lumea 2, Era 4): linia butoaielor, Relay-ul si
orasul. Pana acum jocul le imprumuta de la Wire Works / Moara (PAD_LOOKS_LIKE); aici capata desene proprii, in
materialele barajului: piatra cioplita calda a zidului (a1_town.DSTONE), BETON la socluri si buiandrugi, TABLA
GALVANIZATA (a1_pylons.GALV) sau vopsita, izolatori de portelan, cupru, alama, barne gudronate. Peretii de fier nituit
ai Wire Works si caramida Morii nu mai apar. Fiecare meserie are alt perete, alt acoperis, alta usa si alt semn, ca
vecinii din rand (x 760 / 910 / 1060 / 1210) sa nu se repete:

  prop_hut_dam_collector_1/_2  32x28 / 40x34  Turbineer-ul: piatra cioplita, tabla galvanizata ondulata, usa jad; carligul
                                              de plasa si cosul cu doua borcane-baterii (a doua: raftul cu trei borcane)
  prop_hut_dam_porter_1/_2     32x28 / 40x34  Lugger-ul: soclu de piatra, scanduri gudronate, tabla rosie de oxid, usa verde
                                              de semnal; caruciorul de FIER cu borcane, la dreapta (a doua: si o lada)
  prop_hut_switchman_1/_2      32x28 / 40x34  Switchman-ul: beton turnat, tabla neagra cu falturi, horn de tabla (singurul
                                              cu fum); butoiul si maneta de macaz cu casca rosie agatata in varf si maner oblic (a doua: doua butoaie)
  prop_hut_barrel_hauler_1/_2  32x28 / 40x34  Cooper-ul: pereti de doage de stejar afumat cu cercuri de alama, sindrila
                                              gudronata inchisa, usa albastru-violet; caruciorul de fier cu un baril de
                                              baterii, la stanga (a doua: doua barili, al doilea mai sus)
  prop_stall_dispatcher        48x40          taraba Dispatcher-ului (desenata la x2): tejghea de piatra cu blat de beton,
                                              stalpi vopsiti in verdele-maslin al hainei lui, cu izolatori in varf, copertina
                                              in dungi charcoal si chihlimbar, felinar rosu de semnal; lingouri de cristal si blocuri de curent
  prop_stall_dispatcher_2      64x40          aceeasi taraba, pe trei stalpi, doua copertine si patru gramezi
  prop_hut_relay_keeper_1/_2   32x28 / 40x34  Relayman-ul: piatra inchisa, acoperis in patru ape de cupru inverzit, catarg cu
                                              doi izolatori (a doua: si paratrasnet), cutia de jonctiune cu doaga si capatul
                                              de cablu intr-o scanteie (a doua: si tamburul de cablu); fara horn
  prop_hut_pylon_runner_1/_2   32x28 / 40x34  Linewalker-ul: piatra deschisa, tabla de zinc cu coama si buiandrugi portocalii,
                                              usa alba; caruciorul de fier cu blocuri de curent (unul; in a doua trei), la
                                              stanga, si un stalp tubular cu izolatori la dreapta (ecou la prop_pylon_lane)

Marfa din carucioare si de pe tejghea e a lotului "goods" (a4_goods: keg, pack_small, power_pack, gem_bar, OAK), ca ce
vede jucatorul in hala si pe drum sa fie aceeasi; fara el, desene proprii mai simple (G = None). Barilul gol al
Switchman-ului (cel de cooperat) si stejarul peretilor Hauler-ului sunt de aici.

Reguli ca in d65_crew / d67_crew: panze exacte (mica 32x28 pentru un om, mare 40x34 pentru doi, prinse de baza; taraba
48x40 / 64x40 desenata la x2), culori din palette.ramp(), lumina din stanga-sus, umbra moale, contur trasat automat
(outline_trace), niciodata negru pur, semnele raman in panza. Usa poarta camasa omului, CITITA din lotul de tinute
(a4_outfits.RECIPES, prin OUTFIT_OF / _door_cloth, ca in a4_huts_cable.py): trepta de umbra, camasa si trepta de lumina a tinutei,
deci o usa nu mai poate ramane in urma tinutei ei; la fel haina Dispatcher-ului (stalpii tarabei, verde-maslin). Caruciorul din semnele Porter-ului, Hauler-ului si Linewalker-ului e cel de FIER
(prop_barrow_iron), nu roaba de lemn. Scrie DOAR in --out (implicit folderul de lucru (scripts/art/scratch.py)), nu in assets/sprites.

Dupa recenzia directorului de arta: conturul exterior e unul singur (`_trace` nu creste din inelele obiectelor, deci nu mai
apare contur dublu de 6 px de lume); catargul Relay-ului are doua randuri de tija libera intre traversa si coama (acoperisul
mai jos), iar semnele Collector-ului si maneta Switchman-ului stau sub streasina; hornul Switchman-ului _1 iese deasupra pantei
(caciula pe randul 0, ca la electrician_1); Pylon Runner _1 are geam aprins; acoperisul Porter-ului e tabla vopsita cu falturi
(nu tigla); usa Switchman-ului are buiandrug rosu, a Runner-ului n-are alb curat, iar sindrila Cooper-ului s-a deschis. Dupa recenzia
finala: usile si haina Dispatcher-ului vin din a4_outfits.RECIPES (Linewalker alb-cald dcdad2, Relayman 30c4b8, Dispatcher
maslin 4c5c20 in loc de turcoazul care semana cu Supporter-ul); maneta Switchman-ului are maner oblic (nu mai e o ciuperca rosie
pe un taburet), iar la a doua butoaiele au 8 randuri si lasa geamul din dreapta aprins pe trei din patru randuri; lingoul de
rezerva n-are alb curat.

Rulare: python3 scripts/art/a4_huts_power.py [--out DIR]   (PNG-uri native + huts_power_preview.png)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, Rng, png  # noqa: E402
from palette import OUTLINE, WOOD, ramp  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import PLANK, STEEL, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402
import a4_outfits as O  # noqa: E402  (tinutele lotului de tinute: usa fiecarei case e camasa omului ei)
from a1_town import DSTONE  # noqa: E402
from a1_pylons import GALV, CRYS, CRYS_VIO  # noqa: E402

try:  # marfa lotului "goods" (acelasi baril, aceleasi blocuri de curent, acelasi lingou); fara el, desene proprii mai simple
    import a4_goods as G  # noqa: E402
except ImportError:
    G = None

import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
DEFAULT_OUT = scratch.folder("a4")
SPR = "/Users/tiberiubojan/Desktop/Driftwood/assets/sprites"
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---------------------------------------------------------------------------------------------
# paleta: betonul si tabla barajului, pe langa piatra (DSTONE) si fierul galvanizat (GALV) din A1

IRON, BRASS, COPPER, SPARK = W.IRON, W.BRASS, M.COPPER, W.SPARK
CONC = ramp(206, 0.05, 0.72, val_span=0.36)  # betonul soclurilor: gri rece, deschis (piatra e calda, deci se desprind)
TAR = ramp(24, 0.40, 0.50, val_span=0.44)  # scandurile gudronate, maro inchis (nu negru: se citeste ca perete)
OAK = G.OAK if G else ramp(22, 0.62, 0.52, hue_shift=8, val_span=0.46)  # stejarul barilului: ca al lotului "goods"
SMOKED = ramp(26, 0.52, 0.42, val_span=0.36)  # stejarul afumat al peretilor Cooper-ului (butoaiele ies din el)
SHAKE = ramp(24, 0.42, 0.38, val_span=0.36)  # sindrila de stejar patinat a acoperisului lui (mai deschisa decat carbunele vecin, mai inchisa decat peretele)
OXIDE = ramp(8, 0.52, 0.50, val_span=0.38)  # tabla vopsita in rosu de oxid
CHARCOAL = ramp(216, 0.16, 0.34, val_span=0.34)  # tabla neagra cu falturi
ZINC = ramp(204, 0.10, 0.68, val_span=0.34)  # zincul nou, aproape alb
VERDI = M.VERDIGRIS  # cuprul inverzit al acoperisului Relay-ului
RED_PAINT = ramp(2, 0.66, 0.62)  # maneta si casca Switchman-ului
ORANGE = ramp(24, 0.86, 0.90)  # portocaliul de semnal al Linewalker-ului
AMBER = ramp(40, 0.82, 0.80)  # dungile tarabei: chihlimbar
SLATE_C = ramp(216, 0.14, 0.30, val_span=0.30)  # dungile tarabei: charcoal


# culoarea usii = camasa tinutei, CITITA din lotul de tinute (a4_outfits.RECIPES), ca cele doua loturi sa nu poata diverge (la fel
# face a4_huts_cable.py, prin OUTFIT_OF / _door_cloth). Cheia casei = cheia tinutei omului ei. d55._door citeste cloth[1..3]:
# (umbra, umbra, camasa, lumina, lumina), deci usa are exact trepta de camasa a omului.
OUTFIT_OF = {
    "turbineer": "turbineer",  # Dam Collector (palarie de ceara)
    "lugger": "lugger",  # Dam Porter (caciula portocalie)
    "switchman": "switchman",  # Switchman (casca rosie)
    "cooper": "cooper",  # Barrel Hauler (basma de stejar)
    "relayman": "relayman",  # Relay Keeper (casca albastra)
    "linewalker": "linewalker",  # Pylon Runner (basma portocalie de semnal)
    "dispatcher": "dispatcher",  # Dispatcher: haina (stalpii tarabei) si banda rosie
}


def _door_cloth(key):
    r = O.RECIPES[OUTFIT_OF[key]]["recipe"]
    return (r["shirt_d"], r["shirt_d"], r["shirt"], r["shirt_l"], r["shirt_l"])


DOORS = {k: _door_cloth(k) for k in OUTFIT_OF if k != "dispatcher"}
DISPATCHER_COAT = _door_cloth("dispatcher")  # haina Dispatcher-ului (verde-maslin, cu banda rosie de semnal): stalpii tarabei


def clamp(v, a, b):
    return max(a, min(b, v))


# ---------------------------------------------------------------------------------------------
# pereti: fiecare meserie cu materialul ei


def _ashlar(c, x0, x1, y0, y1, rng, base=(2, 3), ch=4, bw=(5, 8), tones=DSTONE):
    """Piatra cioplita calda a barajului, pe x0..x1 si y0..y1 inclusiv: randuri de `ch` px cu blocuri de latimi si tonuri
    diferite, rostul dintre randuri si dintre blocuri inchis (nu o dunga luminoasa: ca sa nu citeasca drept scandura),
    colturile din blocuri lungi si scurte pe rand (cheile colturilor), lumina din stanga-sus."""
    top = len(tones) - 1
    row, y = 0, y0
    while y <= y1:
        h = min(ch, y1 - y + 1)
        x = x0 - (rng.i(0, bw[1] - 1) if row % 2 else 0)
        while x <= x1:
            w = rng.i(bw[0], bw[1])
            tb = rng.i(base[0], base[1])
            for yy in range(y, y + h):
                for xx in range(max(x, x0), min(x + w, x1 + 1)):
                    t = tb
                    if yy == y + h - 1 and h == ch:
                        t = 1  # rostul de jos al randului
                    elif yy == y:
                        t = tb + (1 if rng.n() < 0.4 else 0)  # muchia de sus prinde lumina doar la unele blocuri
                    if xx == x + w - 1 and xx != x1:
                        t = 1  # rostul din dreapta blocului
                    if xx - x0 < 2:
                        t += 1
                    if x1 - xx < 2:
                        t -= 1
                    c.put(xx, yy, tones[clamp(t, 0, top)])
            x += w
        y += h
        row += 1


def _concrete(c, x0, x1, y0, y1):
    """Beton turnat in cofraje: fasii orizontale cu rost, gauri de tiranti, muchia din stanga luminata."""
    w, h = x1 - x0 + 1, y1 - y0 + 1
    c.rect(x0, y0, w, h, CONC[2])
    for y in range(y0 + 3, y1 + 1, 4):  # rosturile cofrajului
        c.rect(x0, y, w, 1, CONC[1])
    for y in range(y0 + 1, y1, 4):  # gaurile tirantilor, in sah
        for x in range(x0 + 3 + (y - y0) // 4 % 2 * 3, x1 - 1, 6):
            c.put(x, y, CONC[0])
    c.rect(x0, y0, 1, h, CONC[4])
    c.rect(x1, y0, 1, h, CONC[1])


def _tar_boards(c, x0, x1, y0, y1):
    """Scanduri gudronate puse vertical, cu sipci: perioada de 4 px (sipca luminata, doua scanduri, rostul)."""
    w, h = x1 - x0 + 1, y1 - y0 + 1
    c.rect(x0, y0, w, h, TAR[2])
    for x in range(x0, x1 + 1):
        k = (x - x0) % 4
        c.rect(x, y0, 1, h, (TAR[3], TAR[2], TAR[2], TAR[1])[k])
    c.rect(x0, y0 + h // 2 - 1, w, 1, TAR[1])  # rigla de la mijloc
    c.rect(x0, y0, 1, h, TAR[4])
    c.rect(x1, y0, 1, h, TAR[0])


def _oak_staves(c, x0, x1, y0, y1):
    """Peretele Cooper-ului: doage de stejar (3 px: lumina, corp, rost) si doua cercuri de alama de-a latul."""
    w, h = x1 - x0 + 1, y1 - y0 + 1
    for x in range(x0, x1 + 1):
        k = (x - x0) % 3
        c.rect(x, y0, 1, h, (SMOKED[3], SMOKED[2], SMOKED[1])[k])
    c.rect(x0, y0, 1, h, SMOKED[4])
    c.rect(x1, y0, 1, h, SMOKED[0])
    for y in (y0 + 2, y1 - 2):
        c.rect(x0, y, w, 1, BRASS[3])
        c.rect(x0, y + 1, w, 1, BRASS[1])
        c.rect(x0, y, 1, 1, BRASS[4])


def _footing(c, x0, x1, y0, y1):
    """Soclul de beton al casei (cu 1 px mai lat decat peretele), semnul comun al caselor barajului."""
    w = x1 - x0 + 3
    c.rect(x0 - 1, y0, w, y1 - y0 + 1, CONC[2])
    c.rect(x0 - 1, y0, w, 1, CONC[3])
    c.rect(x0 - 1, y1, w, 1, CONC[1])
    c.rect(x1 + 1, y0 + 1, 1, y1 - y0, CONC[1])
    c.put(x0 - 1, y0, CONC[4])


# ---------------------------------------------------------------------------------------------
# acoperisuri


def _roof(c, x0, x1, top, eave, tones, kind, hw_top=3.0, cap=None):
    """Acoperis in doua ape (sau in patru, cu `hw_top` mare), pe x0..x1, de la `top` la `eave`. `kind` = textura:
    corr = tabla ondulata (nervuri verticale), seam = tabla cu falturi, shingle = sindrila, laps = tabla cu suprapuneri,
    tin = tabla vopsita cu falturi in picioare (nu se confunda cu tigla rosie a casutelor A1). `cap` = culoarea capacului de coama (implicit cel mai luminos ton). Lumina din stanga-sus: marginea din
    stanga mai deschisa, cea din dreapta mai inchisa."""
    h = eave - top
    half = (x1 - x0 + 1) / 2
    mid = (x0 + x1 + 1) / 2
    for i in range(h):
        hw = hw_top + (half - hw_top) * i / max(1, h - 1)
        xl, xr = round(mid - hw), round(mid + hw) - 1
        for x in range(xl, xr + 1):
            if kind == "corr":
                t = (3, 2, 1)[(x - x0) % 3]
                if i % 5 == 4:
                    t -= 1  # suprapunerea foilor
            elif kind == "seam":
                t = (1, 3, 2, 2)[(x - x0) % 4]
                if i < 2:
                    t += 1
            elif kind == "shingle":
                t = 3 if i % 2 else 2
                if i % 2 == 0 and (x - xl + (i // 2) % 3) % 3 == 0:
                    t = 1
            elif kind == "tin":  # tabla vopsita: foi lungi, falt in picioare (1 px mai inchis) la 4 px, doua tonuri pe foaie
                k = (x - x0) % 4
                t = 1 if k == 3 else (3 if k == 0 else 2)
                if i % 6 == 5 and k != 3:
                    t -= 1  # capatul foii, rar (o tigla ar avea un rand la 3)
            else:  # laps
                t = (3, 2, 1)[i % 3]
                if (x - x0) % 7 == 3:
                    t -= 1
            if x - xl < 2:
                t += 1
            if xr - x < 2:
                t -= 1
            c.put(x, top + i, tones[clamp(t, 0, len(tones) - 1)])
    c.rect(x0, eave, x1 - x0 + 1, 1, tones[0])  # streasina, in umbra
    xl0, xr0 = round(mid - hw_top), round(mid + hw_top) - 1
    c.rect(xl0 + 1, top - 1, xr0 - xl0 - 1, 1, cap or tones[4])  # coama (capacul)


def _trace(c):
    """Conturul exterior al casei / tarabei, trasat doar din pixelii care NU sunt ei insisi contur: obiectele de la usa isi au
    deja inelul lor (`_item`, `_iron_barrow`, `_jar`, `_ingot_stack`), iar un al doilea inel peste el ar fi gros de 2 px (6 px
    de lume) oriunde un semn da in aer. Inelele interioare (obiect / perete) raman, cel exterior e unul singur."""
    rings = {OUTLINE[:3]}
    if G:
        rings.add(G.INGOT_LINE[:3])
    src = [row[:] for row in c.px]
    for y in range(c.h):
        for x in range(c.w):
            if src[y][x][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and src[ny][nx][3] > 200 and tuple(src[ny][nx][:3]) not in rings:
                    c.px[y][x] = OUTLINE
                    break


def _shade_eave(c, x0, x1, y):
    """Umbra streasinii pe perete, un rand translucid sub streasina."""
    c.rect(x0, y, x1 - x0 + 1, 1, (0, 0, 0, 70))


# ---------------------------------------------------------------------------------------------
# usa, fereastra


def _door(c, x, y, w, h, cloth, lintel=True, accent=None):
    """Usa (ca d55._door), cu pragul de beton in locul ultimului rand si buiandrug de beton deasupra."""
    d55._door(c, x, y, w, h - 1, cloth)
    c.rect(x - 1, y + h - 1, w + 2, 1, CONC[4])  # pragul
    if lintel:
        c.rect(x - 2, y - 2, w + 4, 1, accent or CONC[3])
        c.rect(x - 2, y - 2, 1, 1, CONC[4])


def _window(c, x, y, w=5, h=4, lintel=True, accent=None):
    """Fereastra aprinsa (d55._window), cu pervaz si buiandrug de beton."""
    d55._window(c, x, y, w, h)
    c.rect(x - 2, y + h + 1, w + 4, 1, CONC[3])
    c.rect(x - 1, y + h + 2, w + 2, 1, (0, 0, 0, 50))
    if lintel:
        c.rect(x - 2, y - 2, w + 4, 1, accent or CONC[3])
        c.rect(x - 2, y - 2, 1, 1, CONC[4])


# ---------------------------------------------------------------------------------------------
# obiectele de la usa: semnele meseriilor


def _blit(c, tmp, x, y, flip=False):
    """Lipeste un desen facut pe o panza de lucru (`tmp`), cu opozitie stanga-dreapta daca `flip`."""
    for yy in range(tmp.h):
        for xx in range(tmp.w):
            p = tmp.px[yy][xx]
            if p[3]:
                c.put(x + (tmp.w - 1 - xx if flip else xx), y + yy, p)


def _keg(c, x, y, w=7, h=9, bands=(2, 6), lit=False, lid_h=3):
    """Barilul de baterii al lotului "goods" (G.keg: stejar, cercuri de alama, capac deschis cu capetele borcanelor); fara
    lotul "goods", barilul simplu de aici. (x, y) = coltul stanga-sus al capacului."""
    if G:
        G.keg(c, x, y, w, h, bands, batteries=True, lit=lit, lid_h=lid_h)
    else:
        _barrel(c, x, y, w, h)


def _pack_small(c, x, y, lit=0):
    """Blocul mic de condensatoare din roaba (G.pack_small, 6x7); fara "goods", celula de curent de aici."""
    if G:
        G.pack_small(c, x, y, lit)
    else:
        _power_cell(c, x, y + 2, 6)


def _power_pack(c, x, y, w=9, h=8):
    """Blocul mare de condensatoare (G.power_pack): carcasa galvanizata, tuburi cian, borne de alama deasupra."""
    if G:
        G.power_pack(c, x, y, w, h)
    else:
        _power_cell(c, x, y + 3, w)


def _gem_bar(c, x, y, w=7):
    """Lingoul de cristal copt (G.gem_bar, w x 4, lila); fara "goods", lingoul de aici."""
    if G:
        G.gem_bar(c, x, y, w)
    else:
        _crystal_ingot(c, x, y + 1, w)


def _item(c, x, y, w, h, draw):
    """Un obiect cu conturul lui (ca sa se citeasca pe peretele din spate): `draw(t, ox, oy)` il deseneaza pe o panza de
    lucru in (ox, oy) = (1, 1), apoi se traseaza conturul si se lipeste la (x, y)."""
    t = C(w + 2, h + 2)
    draw(t, 1, 1)
    _trace(t)  # nu creste din inelele de dinauntru (un borcan cu conturul lui), ca sa nu iasa contur dublu
    _blit(c, t, x - 1, y - 1)


def _barrel(c, x, y, w=7, h=8, hoops=True, tone=OAK):
    """Un butoi de stejar vazut din lateral (w x h): burta, capacul luminat, doua cercuri de alama. (x, y) = coltul
    stanga-sus."""
    widths = [w - 2] + [w] * (h - 2) + [w - 2]
    for r, bw in enumerate(widths):
        x0 = x + (w - bw) // 2
        for k in range(bw):
            t = 2
            if k == 0:
                t = 4
            elif k == 1:
                t = 3
            elif k == bw - 1:
                t = 1
            if r == 0:
                t = 4 if k < bw - 1 else 3  # capacul
            c.put(x0 + k, y + r, tone[t])
    if hoops:
        for r in (2, h - 3):
            bw = widths[r]
            x0 = x + (w - bw) // 2
            for k in range(bw):
                c.put(x0 + k, y + r, BRASS[4] if k == 0 else (BRASS[3] if k < bw - 1 else BRASS[1]))


def _iron_barrow(c, x, y, flip=False, cargo=None):
    """Caruciorul de fier (ca prop_barrow_iron, 14x9): tava de otel cu nituri si buza lucioasa, roata cu butuc, picior si
    manere de teava. Fata spre stanga (roata in stanga); `flip` il oglindeste. `cargo(t, ox, oy)` isi deseneaza marfa pe
    panza de lucru, INAINTE de tava (ca partea de jos a marfii sa dispara in tava); (ox, oy) = coltul stanga-sus al
    caruciorului. (x, y) = coltul stanga-sus al caruciorului in desen; marfa urca pana la 9 randuri deasupra lui. Roata
    ajunge pe randul y + 8."""
    t = C(16, 18)
    ox, oy = 1, 9
    if cargo:
        cargo(t, ox, oy)
    t.rect(ox + 1, oy, 11, 1, STEEL[4])  # buza lucioasa
    for yy in range(1, 4):  # tava, ingusta jos
        t.rect(ox + 1 + (yy + 1) // 2, oy + yy, 11 - (yy + 1), 1, STEEL[3] if yy % 2 else STEEL[2])
    t.rect(ox + 3, oy + 1, 7, 1, IRON[1])  # interiorul, in umbra
    for rx in (ox + 5, ox + 8):  # nituri
        t.put(rx, oy + 2, STEEL[4])
    line(t, ox + 11, oy + 3, ox + 13, oy + 5, STEEL[2], 1)  # manerul
    t.rect(ox + 8, oy + 4, 2, 4, IRON[1])  # piciorul
    t.ellipse(ox + 3.5, oy + 6, 2.2, 2.2, IRON[0])  # roata
    t.rect(ox + 3, oy + 5, 2, 2, STEEL[3])  # butucul
    t.put(ox + 3, oy + 5, STEEL[4])
    _trace(t)  # conturul lui, ca sa se desprinda de peretele din spate
    _blit(c, t, x - ox, y - oy, flip)  # corpul ocupa 1..14 pe panza de 16, deci oglindit sta tot pe 1..14


def _jar(c, x, y, lit=True):
    """Un borcan-baterie cu conturul lui (5x7 + scanteia, in panza de 7x11): ca doua borcane lipite sa nu se piarda unul in altul."""
    t = C(7, 10)
    W.jar(t, 1, 3, lit=lit)
    _trace(t)
    _blit(c, t, x - 1, y - 3)


def _jar_basket(c, x, y):
    """Cosul de rachita cu doua borcane-baterii: (x, y) = coltul stanga-sus al panzei de 10x10 (scanteile includ); rachita
    de 3 randuri, ca tot semnul sa incapa sub streasina."""
    c.rect(x, y + 7, 10, 3, d55.ROPE[1])
    c.rect(x, y + 7, 10, 1, d55.ROPE[3])
    for xx in range(x + 1, x + 10, 2):
        c.rect(xx, y + 8, 1, 2, d55.ROPE[0])
    _jar(c, x, y + 2, lit=True)
    _jar(c, x + 5, y + 3, lit=False)
    c.rect(x, y + 7, 10, 1, d55.ROPE[3])


def _shelf(c, x, y, n, legs=4):
    """Raftul cu n borcane-baterii, pe doi stalpi scurti: (x, y) = coltul stanga-sus al panzei de (4n + 2) x (9 + legs)."""
    w = 4 * n + 2
    c.rect(x + 1, y + 9, 2, legs, WOOD[1])
    c.rect(x + w - 3, y + 9, 2, legs, WOOD[1])
    c.rect(x + 1, y + 9, 1, legs, WOOD[3])
    c.rect(x, y + 9, w, 2, PLANK[1])
    c.rect(x, y + 9, w, 1, PLANK[3])
    for k in range(n):
        _jar(c, x + 1 + k * 4, y + 2, lit=k != 1)


def _crate(c, x, y, w=9, h=6, jars=2):
    """Lada cu borcane: (x, y) = coltul stanga-sus al panzei de w x (h + 8)."""
    c.rect(x, y + 8, w, h, PLANK[1])
    c.rect(x, y + 8, w, 1, PLANK[3])
    c.rect(x + w // 2, y + 8, 1, h, PLANK[0])
    c.rect(x, y + 7 + h, w, 1, PLANK[0])
    for k in range(jars):
        W.jar(c, x + 1 + k * 4, y + 2, lit=k == 0)


def _stovepipe(c, x, top, bottom):
    """Hornul de tabla galvanizata (3 lat), cu doua coliere si caciula plata: Switchman-ul are vatra pentru cercuri."""
    c.rect(x, top, 3, bottom - top, GALV[2])
    c.rect(x, top, 1, bottom - top, GALV[4])
    c.rect(x + 2, top, 1, bottom - top, GALV[1])
    for y in (top + 3, top + 7):
        if y < bottom:
            c.rect(x - 1, y, 5, 1, IRON[2])
    c.rect(x - 1, top, 5, 1, GALV[3])
    c.rect(x, top + 1, 3, 1, IRON[0])  # gura, in umbra sub caciula


def _lever(c, x, y, pole=6):
    """Maneta de macaz cu casca rosie agatata in varf (5 x (5 + pole)), pe un bloc de beton; `pole` = randurile stalpului dintre
    casca si bloc. Bratul e un maner oblic de un pixel, care pleaca din stalp spre dreapta-sus (nu o bara plata: sub casca de 3 px
    o bara plata se citea ca ciuperca sau taburet). (x, y) = coltul stanga-sus."""
    by = y + 3 + pole  # blocul de beton
    c.rect(x, by, 5, 2, CONC[3])
    c.rect(x, by, 5, 1, CONC[4])
    c.rect(x + 4, by, 1, 2, CONC[1])
    c.rect(x + 2, y + 3, 1, pole, STEEL[3])
    c.put(x + 2, y + 3, STEEL[4])
    line(c, x + 2, by - 1, x + 4, by - 3, STEEL[3])  # manerul: oblic, din baza stalpului
    c.put(x + 4, by - 3, STEEL[4])  # varful manerului, luminat
    c.rect(x + 1, y, 3, 1, RED_PAINT[4])  # casca: calota, cupola, borul
    c.rect(x, y + 1, 5, 1, RED_PAINT[2])
    c.rect(x, y + 2, 5, 1, RED_PAINT[0])


def _power_cell(c, x, y, w=8, glow=0):
    """Celula de curent (w x 4): corp galvanizat, capete de alama, inel albastru-alb care straluceste (`glow` il muta)."""
    c.rect(x, y, w, 4, GALV[2])
    c.rect(x, y, w, 1, GALV[4])
    c.rect(x, y + 3, w, 1, GALV[0])
    c.rect(x, y, 1, 4, BRASS[3])
    c.rect(x + w - 1, y, 1, 4, BRASS[1])
    gx = x + w // 2 - 1 + glow
    c.rect(gx, y, 2, 4, SPARK[3])
    c.put(gx, y, SPARK[4])
    c.put(gx + 1, y + 1, SPARK[4])


def _junction_box(c, x, y):
    """Cutia de jonctiune (9x10): o doaga de stejar cu cerc de alama si un capat de cablu de cupru se intalnesc deasupra
    cutiei de tabla, intr-o scanteie. (x, y) = coltul stanga-sus."""
    c.rect(x, y + 5, 9, 5, GALV[2])
    c.rect(x, y + 5, 9, 1, GALV[4])
    c.rect(x + 8, y + 5, 1, 5, GALV[1])
    c.rect(x, y + 9, 9, 1, GALV[0])
    c.put(x + 1, y + 6, BRASS[4])
    c.put(x + 7, y + 6, BRASS[2])
    c.rect(x + 3, y + 7, 3, 1, IRON[1])  # gratia
    c.rect(x + 3, y + 5, 3, 1, BRASS[3])  # capacul cu borne
    c.rect(x + 1, y + 1, 2, 4, OAK[2])  # doaga
    c.rect(x + 1, y + 1, 1, 4, OAK[4])
    c.rect(x + 1, y + 3, 2, 1, BRASS[3])
    line(c, x + 6, y + 4, x + 5, y + 1, COPPER[3], 1)  # cablul
    c.put(x + 5, y + 1, COPPER[4])
    c.put(x + 3, y + 1, SPARK[4])  # scanteia dintre ele
    c.put(x + 4, y, SPARK[3])
    c.put(x + 4, y + 2, SPARK[4])


def _pin_insulator(c, x, y):
    """Izolatorul pe pin (3 lat, 4 inalt): caciula de fier, doua discuri de portelan, pinul."""
    c.rect(x, y, 3, 1, IRON[2])
    c.rect(x, y + 1, 3, 2, CREAM[3])
    c.rect(x, y + 1, 1, 2, CREAM[4])
    c.put(x + 2, y + 2, CREAM[1])
    c.put(x + 1, y + 3, IRON[1])


def _mast(c, cx, top, bottom):
    """Catargul de pe acoperis (2 lat), cu o traversa de tabla si doi izolatori de portelan pe pin. `top` = randul de sus al
    izolatorilor, `bottom` = unde intra in acoperis."""
    c.rect(cx, top + 4, 2, bottom - top - 4, GALV[3])
    c.rect(cx, top + 4, 1, bottom - top - 4, GALV[4])
    c.rect(cx - 4, top + 4, 10, 1, GALV[2])
    c.rect(cx - 4, top + 4, 10, 1, GALV[2])
    _pin_insulator(c, cx - 5, top)
    _pin_insulator(c, cx + 4, top)


def _rod(c, cx, top, bottom):
    """Paratrasnetul (1 lat, cu varf de alama): ramane in randurile de sus ale panzei."""
    c.rect(cx, top, 1, bottom - top, GALV[3])
    c.put(cx, top, BRASS[4])


def _lane_pole(c, x, top, bottom, left=3, right=4):
    """Stalpul tubular subtire (2 lat) cu un brat si doi izolatori de portelan pe pini, ca prop_pylon_lane, pe o talpa de
    beton. (x, top) = tubul si varful izolatorilor, `bottom` = randul de sub talpa; bratul merge de la x - left la x + right."""
    c.rect(x, top + 4, 2, bottom - top - 4, GALV[2])
    c.rect(x, top + 4, 1, bottom - top - 4, GALV[4])
    c.rect(x - left, top + 4, left + right + 1, 2, GALV[2])  # bratul
    c.rect(x - left, top + 4, left + right + 1, 1, GALV[4])
    c.rect(x - left, top + 5, left + right + 1, 1, GALV[1])
    for ix in (x - left, x + right - 1):
        c.rect(ix, top, 2, 1, IRON[2])  # caciula de fier
        c.rect(ix, top + 1, 2, 2, CREAM[3])  # discurile de portelan
        c.put(ix, top + 1, CREAM[4])
        c.put(ix + 1, top + 2, CREAM[1])
        c.put(ix, top + 3, IRON[1])  # pinul
    c.rect(x - 1, bottom - 2, 4, 2, CONC[3])  # talpa de beton
    c.rect(x - 1, bottom - 2, 4, 1, CONC[4])


# ---------------------------------------------------------------------------------------------
# casa: aceeasi familie ca in d65_crew / d67_crew (mica 32x28 pentru un om, mare 40x34 pentru doi, prinse de baza)

SMALL = dict(w=32, h=28, shadow=(16, 26, 14, 2), wall_y=(14, 25), foot=24, top=3, eave=14, door_y=18, door_h=8, door_w=5, win_y=17)
BIG = dict(w=40, h=34, shadow=(20, 32, 18, 2), wall_y=(17, 31), foot=30, top=4, eave=17, door_y=21, door_h=10, door_w=6, win_y=21)


def _hut(small, seed, wall, roof, door, lay, behind=None, extra=None, lintel=True, accent=None):
    """O casa. `wall(c, x0, x1, y0, y1, rng)` = materialul peretelui; `roof` = (tonurile, textura, hw_top, top sau None);
    `lay` = asezarea (peretele, acoperisul, usa, ferestrele), pe marimi; `behind` se deseneaza inaintea peretelui (stalp,
    horn), `extra` dupa usa si ferestre (semnele meseriei), `accent` = culoarea buiandrugilor (implicit betonul)."""
    g = SMALL if small else BIG
    lay = lay["small" if small else "big"]
    rng = Rng(seed)
    c = C(g["w"], g["h"])
    soft_shadow(c, *g["shadow"])
    wx0, wx1 = lay["wall"]
    y0, y1 = g["wall_y"]
    tones, kind, hw_top, top = roof[:4]
    cap = roof[4] if len(roof) > 4 else None
    top = g["top"] if top is None else (top[0] if small else top[1])
    if behind:
        behind(c, rng)
    wall(c, wx0, wx1, y0, g["foot"] - 1, rng)
    _footing(c, wx0, wx1, g["foot"], y1)
    rx0, rx1 = lay["roof"]
    _roof(c, rx0, rx1, top, g["eave"], tones, kind, hw_top, cap)
    _shade_eave(c, wx0, wx1, g["eave"] + 1)
    _door(c, lay["door"], g["door_y"], g["door_w"], g["door_h"], door, lintel, accent)
    for wx in lay["win"]:
        _window(c, wx, g["win_y"], lintel=lintel, accent=accent)
    if extra:
        extra(c, rng)
    _trace(c)
    return c


def _ashlar_wall(base=(2, 3), ch=4, bw=(5, 8)):
    return lambda c, x0, x1, y0, y1, rng: _ashlar(c, x0, x1, y0, y1, rng, base=base, ch=ch, bw=bw)


def _porter_wall(c, x0, x1, y0, y1, rng):
    """Soclu de piatra cioplita (4 randuri) si scanduri gudronate deasupra."""
    _tar_boards(c, x0, x1, y0, y1 - 4)
    _ashlar(c, x0, x1, y1 - 3, y1, rng, base=(2, 3), ch=4, bw=(5, 7))
    c.rect(x0, y1 - 4, x1 - x0 + 1, 1, DSTONE[4])  # coama soclului, luminata


def _concrete_wall(c, x0, x1, y0, y1, rng):
    _concrete(c, x0, x1, y0, y1)


def _oak_wall(c, x0, x1, y0, y1, rng):
    _oak_staves(c, x0, x1, y0, y1)


# ---------------------------------------------------------------------------------------------
# 1. Dam Collector (Turbineer): piatra, tabla galvanizata ondulata, usa jad


def _collector(small):
    lay = dict(small=dict(wall=(5, 26), roof=(2, 29), door=15, win=[8]), big=dict(wall=(4, 29), roof=(1, 32), door=11, win=[5, 19]))

    def extra(c, rng):
        if small:
            d56._gaff(c, 1, 12)
            _item(c, 20, 16, 10, 10, _jar_basket)  # scanteia la randul 16: streasina (14) ramane intreaga
        else:
            d56._gaff(c, 1, 17)
            _item(c, 25, 19, 14, 13, lambda t, ox, oy: _shelf(t, ox, oy, 3))  # scanteile de la randul 19: streasina (17) ramane intreaga

    return _hut(small, 7611 if small else 7612, _ashlar_wall(), (GALV, "corr", 3.0, None), DOORS["turbineer"], lay, extra=extra)


def prop_hut_dam_collector_1():
    return _collector(True)


def prop_hut_dam_collector_2():
    return _collector(False)


# ---------------------------------------------------------------------------------------------
# 2. Dam Porter (Lugger): soclu de piatra, scanduri gudronate, tabla rosie de oxid, usa verde de semnal


def _porter(small):
    lay = dict(small=dict(wall=(3, 24), roof=(1, 27), door=12, win=[5]), big=dict(wall=(3, 28), roof=(1, 30), door=16, win=[9]))

    def jars(t, ox, oy):
        W.jar(t, ox + 3, oy - 4, lit=True)
        W.jar(t, ox + 8, oy - 3, lit=False)

    def extra(c, rng):
        if small:
            _iron_barrow(c, 17, 18, flip=True, cargo=jars)
        else:
            _iron_barrow(c, 25, 24, flip=True, cargo=jars)
            _item(c, 1, 18, 8, 14, lambda t, ox, oy: _crate(t, ox, oy, 8, 6, jars=1))

    return _hut(small, 7621 if small else 7622, _porter_wall, (OXIDE, "tin", 3.0, None), DOORS["lugger"], lay, extra=extra, lintel=False)


def prop_hut_dam_porter_1():
    return _porter(True)


def prop_hut_dam_porter_2():
    return _porter(False)


# ---------------------------------------------------------------------------------------------
# 3. Switchman: beton turnat, tabla neagra cu falturi, horn de tabla; butoiul in cercuri de alama si maneta rosie


CHIMNEYS = {"hut_switchman_1": (21, 32), "hut_switchman_2": (24, 40)}  # (x hornului de 3 px, latimea panzei)


def _switchman(small):
    lay = dict(small=dict(wall=(5, 26), roof=(2, 29), door=13, win=[6]), big=dict(wall=(4, 29), roof=(1, 32), door=12, win=[6, 21]))

    def behind(c, rng):
        if small:
            _stovepipe(c, 21, 0, 9)
        else:
            _stovepipe(c, 24, 1, 11)

    def extra(c, rng):
        if small:
            _item(c, 19, 17, 7, 9, lambda t, ox, oy: _barrel(t, ox, oy, 7, 9))
            _item(c, 26, 17, 5, 9, lambda t, ox, oy: _lever(t, ox, oy, pole=4))  # casca pe randurile 17-19: streasina (14) ramane intreaga, blocul pe 24-25
        else:
            _item(c, 20, 25, 7, 8, lambda t, ox, oy: _barrel(t, ox, oy, 7, 8))  # 8 randuri, la y=25: geamul din dreapta (randurile 21-24) ramane aprins pe 21-23
            _item(c, 27, 25, 7, 8, lambda t, ox, oy: _barrel(t, ox, oy, 7, 8))
            _item(c, 34, 22, 5, 11, _lever)

    return _hut(small, 7631 if small else 7632, _concrete_wall, (CHARCOAL, "seam", 3.0, None), DOORS["switchman"], lay, behind=behind, extra=extra, accent=RED_PAINT[2])


def prop_hut_switchman_1():
    return _switchman(True)


def prop_hut_switchman_2():
    return _switchman(False)


# ---------------------------------------------------------------------------------------------
# 4. Barrel Hauler (Cooper): doage de stejar cu cercuri de alama, sindrila de stejar; caruciorul de fier cu butoaie


def _hauler(small):
    lay = dict(small=dict(wall=(6, 27), roof=(3, 30), door=16, win=[22]), big=dict(wall=(7, 34), roof=(4, 37), door=19, win=[28]))

    def one(t, ox, oy):
        _keg(t, ox + 2, oy - 6, 7, 8, bands=(2, 5))

    def two(t, ox, oy):
        _keg(t, ox + 5, oy - 8, 7, 8, bands=(2, 5))  # cel din spate, sus
        _keg(t, ox + 1, oy - 6, 7, 8, bands=(2, 5))

    def extra(c, rng):
        if small:
            _iron_barrow(c, 0, 18, cargo=one)
        else:
            _iron_barrow(c, 0, 24, cargo=two)

    return _hut(small, 7641 if small else 7642, _oak_wall, (SHAKE, "shingle", 3.0, None), DOORS["cooper"], lay, extra=extra, lintel=False)


def prop_hut_barrel_hauler_1():
    return _hauler(True)


def prop_hut_barrel_hauler_2():
    return _hauler(False)


# ---------------------------------------------------------------------------------------------
# 5. Relay Keeper (Relayman): piatra inchisa, acoperis in patru ape de cupru inverzit, catarg; cutia de jonctiune


MAST_ROOF_TOP = (9, 10)  # randul de sus al acoperisului in patru ape (mica, mare), cu coama pe randul de deasupra


def _relay(small):
    lay = dict(small=dict(wall=(5, 26), roof=(2, 29), door=15, win=[8]), big=dict(wall=(4, 29), roof=(1, 32), door=12, win=[6, 21]))
    top = (MAST_ROOF_TOP[0], MAST_ROOF_TOP[1])  # coama: traversa catargului e pe randul 5, deasupra coamei raman 2 randuri de tija libera

    def extra(c, rng):
        if small:
            _item(c, 21, 16, 9, 10, _junction_box)
            _mast(c, 15, 1, top[0] + 1)
        else:
            _item(c, 29, 21, 9, 10, _junction_box)
            _item(c, 1, 25, 8, 7, lambda t, ox, oy: W.coil(t, ox, oy, 8, 6))
            _mast(c, 19, 1, top[1] + 1)
            _rod(c, 19, 1, 5)  # paratrasnetul urca din traversa, intre cei doi izolatori

    return _hut(small, 7651 if small else 7652, _ashlar_wall(base=(1, 2), ch=4), (VERDI, "seam", 6.0, top), DOORS["relayman"], lay, extra=extra)


def prop_hut_relay_keeper_1():
    return _relay(True)


def prop_hut_relay_keeper_2():
    return _relay(False)


# ---------------------------------------------------------------------------------------------
# 6. Pylon Runner (Linewalker): piatra deschisa, tabla de zinc cu coama portocalie; caruciorul cu pachete de curent si stalpul


def _runner(small):
    lay = dict(small=dict(wall=(5, 24), roof=(2, 27), door=14, win=[]), big=dict(wall=(6, 33), roof=(3, 36), door=17, win=[25]))

    def packs(t, ox, oy):
        if small:
            _pack_small(t, ox + 3, oy - 6)
        else:  # a doua: trei blocuri, unul in spate, sus (ca treapta 3 a incarcaturii "grid")
            _pack_small(t, ox + 3, oy - 8)
            _pack_small(t, ox + 1, oy - 6, 1)
            _pack_small(t, ox + 6, oy - 6)

    def extra(c, rng):
        if small:  # singura coliba fara geam aprins ar parea magazie: fereastra de 4 px, buiandrugul pe randul buiandrugului usii
            _window(c, 20, 18, w=4, lintel=True, accent=ORANGE[3])
        _iron_barrow(c, 0, 18 if small else 24, cargo=packs)
        if small:
            _item(c, 24, 9, 7, 18, lambda t, ox, oy: _lane_pole(t, ox + 3, oy, oy + 17, 3, 3))
        else:
            _item(c, 32, 13, 7, 20, lambda t, ox, oy: _lane_pole(t, ox + 3, oy, oy + 19, 3, 3))

    return _hut(small, 7661 if small else 7662, _ashlar_wall(base=(3, 4), ch=4, bw=(6, 8)), (ZINC, "laps", 3.0, None, ORANGE[3]), DOORS["linewalker"], lay, extra=extra, accent=ORANGE[3])


def prop_hut_pylon_runner_1():
    return _runner(True)


def prop_hut_pylon_runner_2():
    return _runner(False)


# ---------------------------------------------------------------------------------------------
# 7. taraba Dispatcher-ului (48x40 pentru unul, 64x40 pentru doi, desenata la x2): ca _stall din d65 / d67, dar cu stalpi
# galvanizati, tejghea de piatra cu blat de beton si copertina in dungi charcoal si chihlimbar (nu rosu ca Innkeeper-ul,
# teal ca Merchant-ul, bleumarin ca Clerk-ul)


def _crystal_ingot(c, x, y, w=8):
    """Lingoul de cristal (w x 3): fata de sus luminata, fata din fata albastra, capatul violet; sclipire pe muchie."""
    c.rect(x, y, w, 3, CRYS[2])
    c.rect(x, y, w, 1, CRYS[4])
    c.rect(x + 1, y + 1, w - 2, 1, CRYS[3])
    c.rect(x, y + 2, w, 1, CRYS[1])
    c.rect(x + w - 2, y + 1, 2, 2, CRYS_VIO[1])
    c.put(x + w - 1, y, CRYS_VIO[0])
    c.put(x + 2, y, CREAM[4])  # sclipirea: crem cald, nu alb curat (250,246,230)


def _ingot_stack(c, x, y):
    """Trei lingouri de cristal copt, in piramida (14 x 8), cu conturul prun al lotului "goods": (x, y) = coltul stanga-sus."""
    t = C(16, 10)
    _gem_bar(t, 1, 5, 7)
    _gem_bar(t, 8, 5, 7)
    _gem_bar(t, 4, 1, 7)
    outline_trace(t, G.INGOT_LINE if G else OUTLINE)
    _blit(c, t, x - 1, y - 1)


def _stall(width, posts, awnings, goods, seed):
    rng = Rng(seed)
    c = C(width, 40)
    soft_shadow(c, width // 2, 37, width // 2 - 5, 3)
    for px in posts:  # stalpii: teava vopsita in verdele-maslin al hainei Dispatcher-ului (RECIPES), cu un izolator de portelan in varf
        c.rect(px, 14, 3, 21, DISPATCHER_COAT[2])
        c.rect(px, 14, 1, 21, DISPATCHER_COAT[3])
        c.rect(px + 2, 14, 1, 21, DISPATCHER_COAT[1])
    # tejgheaua: front de piatra cioplita, blat de beton cu muchie luminata, plinta de beton
    _ashlar(c, 2, width - 3, 31, 35, rng, base=(2, 3), ch=4, bw=(6, 9))
    c.rect(1, 28, width - 2, 3, CONC[3])
    c.rect(1, 28, width - 2, 1, CONC[4])
    c.rect(1, 30, width - 2, 1, CONC[1])
    c.rect(1, 35, width - 2, 1, CONC[1])
    for sx, span in awnings:
        for i in range(9):
            y, w, x0 = 6 + i, span - i * 2, sx + i
            for k in range(w):
                band = ((x0 + k) // 5) % 2
                c.put(x0 + k, y, AMBER[3] if band == 0 else SLATE_C[2])
        c.rect(sx, 6, span, 1, SLATE_C[4])
        c.rect(sx, 14, span, 1, SLATE_C[0])
        for i, x in enumerate(range(sx + 1, sx + span - 1, 6)):  # falcile de la streasina
            col = AMBER[1] if i % 2 == 0 else SLATE_C[1]
            c.rect(x, 15, 5, 2, col)
            c.put(x + 2, 17, col)
    for px in posts:  # varful stalpului iese deasupra copertinei, cu un izolator de portelan
        c.rect(px, 5, 3, 2, DISPATCHER_COAT[2])
        c.rect(px, 5, 1, 2, DISPATCHER_COAT[3])
        _pin_insulator(c, px, 1)
    lx = posts[-1] + 3  # felinarul de semnal, rosu ca banda Dispatcher-ului, agatat de ultimul stalp
    c.rect(lx, 19, 2, 1, IRON[2])
    c.rect(lx + 1, 20, 3, 4, RED_PAINT[3])
    c.rect(lx + 1, 20, 3, 1, RED_PAINT[4])
    c.put(lx + 3, 22, RED_PAINT[1])
    c.rect(lx + 1, 24, 3, 1, IRON[1])
    for x, kind in goods:  # marfa de pe tejghea (blatul e pe randul 28): lingouri de cristal si curent, ca la lotul "goods"
        if kind == "ingots":
            _ingot_stack(c, x, 20)
        elif kind == "pack":
            _item(c, x, 20, 6, 8, lambda t, ox, oy: _pack_small(t, ox, oy, 1))
        else:
            _item(c, x, 18, 9, 10, lambda t, ox, oy: _power_pack(t, ox, oy + 2))
    _trace(c)
    return c


def prop_stall_dispatcher():
    return _stall(48, (5, 40), ((2, 44),), ((9, "ingots"), (25, "power"), (34, "pack")), 7671)


def prop_stall_dispatcher_2():
    return _stall(64, (5, 30, 56), ((2, 30), (32, 30)), ((9, "ingots"), (23, "pack"), (34, "ingots"), (48, "pack")), 7672)


SPRITES = {
    "prop_hut_dam_collector_1": prop_hut_dam_collector_1,
    "prop_hut_dam_collector_2": prop_hut_dam_collector_2,
    "prop_hut_dam_porter_1": prop_hut_dam_porter_1,
    "prop_hut_dam_porter_2": prop_hut_dam_porter_2,
    "prop_hut_switchman_1": prop_hut_switchman_1,
    "prop_hut_switchman_2": prop_hut_switchman_2,
    "prop_hut_barrel_hauler_1": prop_hut_barrel_hauler_1,
    "prop_hut_barrel_hauler_2": prop_hut_barrel_hauler_2,
    "prop_hut_relay_keeper_1": prop_hut_relay_keeper_1,
    "prop_hut_relay_keeper_2": prop_hut_relay_keeper_2,
    "prop_hut_pylon_runner_1": prop_hut_pylon_runner_1,
    "prop_hut_pylon_runner_2": prop_hut_pylon_runner_2,
    "prop_stall_dispatcher": prop_stall_dispatcher,
    "prop_stall_dispatcher_2": prop_stall_dispatcher_2,
}
SIZES = {name: ((32, 28) if name.endswith("_1") else (40, 34)) for name in SPRITES}
SIZES["prop_stall_dispatcher"] = (48, 40)
SIZES["prop_stall_dispatcher_2"] = (64, 40)
# marimea panzei jocului, din inventarul A4: coliba mica 32x28, cea mare 40x34, taraba 48x40 / 64x40


# ---------------------------------------------------------------------------------------------
# previzualizarea: fiecare desen la x4 langa cel de imprumut, apoi casele la locurile lor de pe pamantul barajului


def to_image(c):
    img = Image.new("RGBA", (c.w, c.h))
    img.putdata([p for row in c.px for p in row])
    return img


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


BORROWED = {
    "prop_hut_dam_collector_1": "prop_hut_battery_collector_1",
    "prop_hut_dam_collector_2": "prop_hut_battery_collector_2",
    "prop_hut_dam_porter_1": "prop_hut_battery_porter_1",
    "prop_hut_dam_porter_2": "prop_hut_battery_porter_2",
    "prop_hut_switchman_1": "prop_hut_electrician_1",
    "prop_hut_switchman_2": "prop_hut_electrician_2",
    "prop_hut_barrel_hauler_1": "prop_hut_power_hauler_1",
    "prop_hut_barrel_hauler_2": "prop_hut_power_hauler_2",
    "prop_hut_relay_keeper_1": "prop_hut_founder_1",
    "prop_hut_relay_keeper_2": "prop_hut_founder_2",
    "prop_hut_pylon_runner_1": "prop_hut_parts_hauler_1",
    "prop_hut_pylon_runner_2": "prop_hut_parts_hauler_2",
    "prop_stall_dispatcher": "prop_stall_clerk",
    "prop_stall_dispatcher_2": "prop_stall_clerk_2",
}
BG = (86, 128, 64, 255)
PANEL = (28, 32, 36, 255)
TEXT = (230, 230, 230, 255)
# pozitiile din TycoonConfig.WORLDS[2] (x lume, baza = pad.y + 56), ca in a1_plate / village_ground
PADS = {
    "prop_hut_dam_collector": (760, 1620),
    "prop_hut_dam_porter": (910, 1620),
    "prop_hut_switchman": (1060, 1620),
    "prop_hut_barrel_hauler": (1210, 1620),
    "prop_hut_relay_keeper": (2190, 1620),
    "prop_hut_pylon_runner": (2350, 1620),
}
DISPATCHER_PAD = (1770, 1086)  # hire_dispatcher: x 1770, y 1030 + 56
SWITCH_HOUSE = (2039, 1080)  # baza cladirii de imprumut (prop_depot, cutie 192x144)


def _label(d, x, y, text):
    d.text((x, y), text, font=font(8), fill=TEXT)


def sheet_sprites(imgs):
    """Fiecare desen la x4, langa cel de imprumut: pe fiecare rand [nou _1][imprumutat][nou _2][imprumutat]."""
    S = 4
    trades = [n[:-2] for n in imgs if n.endswith("_1")]
    cell_w, cell_h = 40 * S + 12, 34 * S + 22
    cols = 2
    rows = (len(trades) + cols - 1) // cols
    w = cols * 4 * cell_w + 12
    stall_h = 40 * S + 30
    sheet = Image.new("RGBA", (w, rows * cell_h + stall_h + 14), PANEL)
    d = ImageDraw.Draw(sheet)
    for t, trade in enumerate(trades):
        r, k0 = divmod(t, cols)
        for k, name in enumerate((trade + "_1", BORROWED[trade + "_1"], trade + "_2", BORROWED[trade + "_2"])):
            x = 6 + (k0 * 4 + k) * cell_w
            y = 6 + r * cell_h
            tile = Image.new("RGBA", (cell_w - 6, cell_h - 4), BG)
            im = imgs.get(name)
            if im is None:
                im = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
            big = im.resize((im.width * S, im.height * S), Image.NEAREST)
            tile.alpha_composite(big, (4, cell_h - 8 - big.height))
            sheet.alpha_composite(tile, (x, y))
            _label(d, x + 2, y + 2, name.replace("prop_", "") + ("  (borrowed)" if k % 2 else ""))
    y = 6 + rows * cell_h
    x = 6
    for name in ("prop_stall_dispatcher", BORROWED["prop_stall_dispatcher"], "prop_stall_dispatcher_2", BORROWED["prop_stall_dispatcher_2"]):
        im = imgs.get(name)
        if im is None:
            im = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
        big = im.resize((im.width * S, im.height * S), Image.NEAREST)
        tile = Image.new("RGBA", (big.width + 8, stall_h - 4), BG)
        tile.alpha_composite(big, (4, stall_h - 8 - big.height))
        sheet.alpha_composite(tile, (x, y))
        _label(d, x + 2, y + 2, name.replace("prop_", "") + ("  (borrowed)" if name in BORROWED.values() else ""))
        x += tile.width + 6
    return sheet


def _ground():
    path = os.path.join(SPR, "prop_dam_ground.png")
    if not os.path.exists(path):
        return None
    return Image.open(path).convert("RGBA")


def stage_street(imgs, suffix, box, trades, extra=()):
    """Casele la locurile lor pe pamantul copt, 1 px de arta = 3 px de lume, apoi x`Z`: `box` = (x0, y0, x1, y1) in pixeli
    de arta. `extra` = (nume de fisier din assets/sprites, x lume, baza) pentru vecinii de context (casutele A1)."""
    ground = _ground()
    crop = (ground.crop(box).copy() if ground else Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), BG))
    things = []
    for name, wx, wy in extra:
        things.append((wy, Image.open(name).convert("RGBA"), wx))
    for trade in trades:
        wx, wy = PADS[trade]
        things.append((wy, imgs[trade + suffix], wx))
    for wy, im, wx in sorted(things, key=lambda t: t[0]):
        crop.alpha_composite(im, (round(wx / 3) - box[0] - im.width // 2, round(wy / 3) - box[1] - im.height))
    return crop


def stage_stall(imgs, name, box):
    """Taraba la locul ei de langa Switch House, la scara jocului (1 px de lume): pamantul x3, cladirea de imprumut x3, taraba
    x2 (PROP_SCALE). `box` in pixeli de lume."""
    ground = _ground()
    wx0, wy0, wx1, wy1 = box
    if ground:
        g = ground.crop((wx0 // 3, wy0 // 3, wx1 // 3, wy1 // 3))
        img = g.resize((g.width * 3, g.height * 3), Image.NEAREST)
    else:
        img = Image.new("RGBA", (wx1 - wx0, wy1 - wy0), BG)
    depot = Image.open(os.path.join(SPR, "prop_depot.png")).convert("RGBA")
    depot = depot.resize((depot.width * 3, depot.height * 3), Image.NEAREST)
    st = imgs[name].resize((imgs[name].width * 2, imgs[name].height * 2), Image.NEAREST)
    items = [(SWITCH_HOUSE[1], depot, SWITCH_HOUSE[0]), (DISPATCHER_PAD[1], st, DISPATCHER_PAD[0])]
    for wy, im, wx in sorted(items, key=lambda t: t[0]):
        img.alpha_composite(im, (wx - wx0 - im.width // 2, wy - wy0 - im.height))
    return img


def preview(out_dir, imgs):
    sheet = sheet_sprites(imgs)
    cott = [(scratch.sprite(f"prop_dam_cottage_{i}", "a1"), wx, 1620) for i, wx in ((1, 290), (2, 430), (3, 570))]
    cott = [(p, wx, wy) for p, wx, wy in cott if os.path.exists(p)]
    boxA = (70, 488, 432, 552)  # de la prima casuta A1 (x lume 290) pana dincolo de Cooper (1210)
    boxB = (676, 488, 832, 552)
    pieces = []
    for suffix in ("_1", "_2"):
        a = stage_street(imgs, suffix, boxA, ["prop_hut_dam_collector", "prop_hut_dam_porter", "prop_hut_switchman", "prop_hut_barrel_hauler"], cott)
        b = stage_street(imgs, suffix, boxB, ["prop_hut_relay_keeper", "prop_hut_pylon_runner"])
        pieces.append((a.resize((a.width * 3, a.height * 3), Image.NEAREST), b.resize((b.width * 3, b.height * 3), Image.NEAREST)))
    boxS = (1560, 920, 2200, 1100)
    stalls = [stage_stall(imgs, n, boxS) for n in ("prop_stall_dispatcher", "prop_stall_dispatcher_2")]
    pad = 8
    row_h = pieces[0][0].height
    w_street = pieces[0][0].width + pieces[0][1].width + 3 * pad
    W_ = max(sheet.width, w_street, 2 * stalls[0].width + 3 * pad)
    H_ = sheet.height + 2 * (row_h + 14) + stalls[0].height + 24 + 2 * pad
    out = Image.new("RGBA", (W_, H_), PANEL)
    d = ImageDraw.Draw(out)
    out.alpha_composite(sheet, (0, 0))
    y = sheet.height + pad
    for k, (a, b) in enumerate(pieces):
        _label(d, pad, y, "first hire (_1)" if k == 0 else "second hire (_2)")
        _label(d, pad + a.width + pad, y, "at their pads on dam_ground (1 art px = 3 world px = game scale)")
        out.alpha_composite(a, (pad, y + 12))
        out.alpha_composite(b, (pad + a.width + pad, y + 12))
        y += row_h + 14
    _label(d, pad, y, "Dispatcher stall at its pad beside the Switch House (borrowed depot), game scale: stall at x2")
    for k, st in enumerate(stalls):
        out.alpha_composite(st, (pad + k * (st.width + pad), y + 12))
    path = os.path.join(out_dir, "huts_power_preview.png")
    out.save(path)
    return path


def main():
    out = DEFAULT_OUT
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    out = os.path.abspath(out)  # buildings.png lipeste calea relativa de assets/sprites: cu o cale absoluta nu scrie acolo
    if out.startswith(SPR):
        sys.exit("refuz sa scriu in assets/sprites: aprobarea owner-ului vine inainte")
    os.makedirs(out, exist_ok=True)
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        print("  scris", name, f"{c.w}x{c.h}")
    print("previzualizare:", preview(out, {n: to_image(f()) for n, f in SPRITES.items()}))
    # PadArt.CHIMNEY = {(x hornului + jumatate din latime) / latimea panzei, 0.03}: doar procesorul cu horn (Switchman)
    print("PadArt.CHIMNEY:")
    for name, (cx, w) in CHIMNEYS.items():
        print(f'    {name} = {{{(cx + 1.5) / w:.4f}, 0.03}}  -- horn la x {cx}, panza de {w} px')


if __name__ == "__main__":
    main()
