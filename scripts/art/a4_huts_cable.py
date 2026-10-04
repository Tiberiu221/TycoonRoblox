#!/usr/bin/env python3
"""[D75, lotul A4, grupul "huts_cable_crystal"] Casele oamenilor de pe linia CABLULUI si de pe linia CRISTALULUI din Era 4
(barajul, lumea 2). Azi imprumuta colibele Wire Works si ale Morii (TycoonConfig.PAD_LOOKS_LIKE); aici capata desenul lor.

Aceeasi familie de colibe ca in Erele 1-3 (mica 32x28 pentru un om, mare 40x34 pentru doi, prinse de baza, 1 px de arta = 3 px
de lume), dar din materialele BARAJULUI: piatra cioplita si calda, adusa din satul desfacut (A1: DSTONE, aceeasi cu zidul si
cu casutele din Dam Town), soclu de beton, foi de otel galvanizat, cupru, cauciuc negru, lemn gudronat, portelan. Casele
de angajare trebuie sa se citeasca drept case de MUNCITORI, nu drept casutele retrasilor (A1: lemn si tencuiala, olane): aici
peretele e piatra goala, cu o cornisa colorata sub streasina si un acoperis de tabla, nu de olane.

  LINIA CABLULUI (cupru + cauciuc negru): peretii de piatra calda, cornisa de CUPRU (sau de cauciuc, sub un acoperis de cupru),
  usa in culoarea tinutei omului. Fiecare meserie are acoperisul si semnul ei:
    prop_hut_cable_collector_1/_2  foaie de otel galvanizat (cusaturi), carligul si un cos de cauciuc cu minereu de cupru
    prop_hut_cable_porter_1/_2     cauciuc negru in randuri, caruciorul de FIER cu minereu (aceeasi roaba ca walkerii), minereu langa perete
    prop_hut_cablemaker_1/_2       foaie de CUPRU, horn de tabla cu capac de cupru, tamburul de cablu in leagan (cea mare: si un colac gol)
    prop_hut_cable_hauler_1/_2     sindrila de lemn gudronat, caruciorul de fier cu un tambur (doua, la cea mare) de cablu, flansa din
                                   spate la adancimea 2 (semiluna neagra a mantalei se vede si pe fierul gri al caruciorului)
  LINIA CRISTALULUI (violet): aceeasi piatra, putin mai rece, cornisa lila si, pe coama, un ciob de cristal (A1: CRYS)
  — hue-ul violet pe care niciun acoperis din joc nu-l foloseste inca:
    prop_hut_crystal_collector_1/_2  foaie de bronz patinat (verde-maslin: singurul acoperis verde al liniei), cosul de cioburi si carligul
    prop_hut_crystal_porter_1/_2     ardezie ametist, caruciorul de fier cu cristal
    prop_hut_crystalsmith_1/_2       tabla fumurie indigo, horn de piatra cu jar, cuptor, forme cu lingou LILA (ca al haulerului), cleste
                                     (cea mare: si butoiul de calire)
    prop_hut_ingot_hauler_1/_2       foaie de ALAMA LUSTRUITA (singurul acoperis cald din linie: lingourile lila ies din el; luciu in
                                     gradient, doua randuri de foi, nu paie), caruciorul de fier cu lingouri de cristal (unul, doua la
                                     cea mare), incadrate in prun ca sa nu se contopeasca cu cornisa lila

Canvas EXACT (testele si footprint-urile depind de el): _1 32x28, _2 40x34. Soclu pe randul de jos (baza = TycoonConfig.buildingBase,
pad.y + 56), umbra moale coapta (16,26,14,2) / (20,32,18,2), contur trasat la sfarsit (outline_trace; ciobul de cristal are
conturul lui indigo, ca in A1). Nimic nu iese din panza: caruciorul, carligul, horul si tamburul stau toate inauntru. Fiecare
casa are alt acoperis (materialul si latimea streasinii) fata de vecinele ei.

USA = CAMASA tinutei, CITITA din lotul de tinute (a4_outfits.RECIPES, prin OUTFIT_OF): cand lotul de tinute isi schimba o culoare, usa
o urmeaza singura la urmatoarea rulare. Marfa din semne e a lotului de marfa si se IMPORTA, deci cele doua loturi nu pot diverge:
tamburul de cablu (a4_goods.reel: tambur pe cant, flanse galvanizate, manta neagra infasurata, capat de cupru) si lingoul de cristal
(a4_goods.gem_bar, lila, conturul prun G.INGOT_LINE; forma Crystalsmith-ului toarna acelasi lingou lila); minereul e
d65_mill.ore_rock (cable_ore pastreaza desenul `ore`), iar cioburile (`shard`) folosesc aceleasi fatete A1 ca cristalul brut.
Caruciorul din semnele Porter-ului si Hauler-ului e cel de FIER (prop_barrow_iron, d70_modern), nu roaba de lemn: roata e INEL (otel
pe arcul luminat, cauciuc pe cel din umbra, butuc de alama), ca a walkerilor; la cele oglindite (haulerii) inelul se redeseneaza
dupa oglindire, ca arcul de otel sa ramana sus-stanga, spre lumina.

Fumul: PadArt.CHIMNEY.<sprite> = {(x horn + latime/2) / latimea panzei, 0.03}; valorile se tiparesc la fiecare rulare si stau in
CHIMNEYS. Doar procesatorii au horn (Cablemaker, Crystalsmith), la ambele variante; hornul porneste de la randul 1, ca sa-i
ramana loc de contur.

Aceleasi reguli ca restul conductei: culori din palette.ramp() si ale vecinilor, lumina din stanga-sus, niciodata negru pur.
Scrie DOAR in --out (implicit scratchpad-ul sesiunii), nu in assets/sprites. Verifica singur ca nimic nu iese din panza si nu
se lipeste de margine fara contur (mesajele ATENTIE).

Rulare: python3 scripts/art/a4_huts_cable.py [--out DIR] [--regen-ground]
        scrie PNG-urile native in --out si huts_cable_crystal_preview.png in scratchpad/a4 (fiecare desen la x4 langa cel de
        imprumut, apoi cele opt case pe pamantul copt al barajului, la pozitiile padurilor, prima si a doua angajare)
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from buildings import C, Rng, png  # noqa: E402
from palette import WOOD, STONE, OUTLINE, ramp, mix  # noqa: E402
from world import soft_shadow  # noqa: E402
from tycoon import CREAM  # noqa: E402
from tycoon_e1 import STEEL, outline_trace  # noqa: E402
from ruins_d53 import line  # noqa: E402
import d55  # noqa: E402
import d56  # noqa: E402
import d65_mill as M  # noqa: E402
import d67_works as W  # noqa: E402
import a1_town as T  # noqa: E402
import a1_pylons as P  # noqa: E402
import a4_goods as G  # noqa: E402  (marfa lotului de marfa: tamburul de cablu si lingoul de cristal sunt ale ei)
import a4_outfits as O  # noqa: E402  (tinutele lotului de tinute: usa fiecarei case e camasa omului ei)

SCRATCH = "/private/tmp/claude-501/-Users-tiberiubojan-Desktop-Driftwood/b9d4df87-0fc9-4d56-a2d7-bd3169d84806/scratchpad/a4"
SPR = os.path.join(os.path.dirname(os.path.dirname(HERE)), "assets", "sprites")
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---------------------------------------------------------------------------------------------
# materialele

DSTONE = T.DSTONE  # piatra calda a barajului (A1)
# linia cristalului: aceeasi piatra, impinsa 11% spre albastrul-violet al cristalului (sa se simta lumina lui pe pereti)
CSTONE = [mix(t, P.CRYS[2], 0.11) for t in DSTONE]
CONCRETE = ramp(214, 0.05, 0.64, val_span=0.36)  # soclul de beton: gri rece, mai deschis decat piatra calda
RUBBER = ramp(232, 0.12, 0.30, val_span=0.28)  # cauciucul negru al cablului: albastru-negru, cu luciu pe [4]
COPPER = M.COPPER  # cuprul curat
BRASS = W.BRASS
IRON = W.IRON
TIMBER = ramp(24, 0.50, 0.30, hue_shift=8, val_span=0.30)  # lemn gudronat: maro foarte inchis, cald
CRYS, CRYS_VIO, CRYS_LINE = P.CRYS, P.CRYS_VIO, P.CRYS_LINE

# acoperisurile: fiecare meserie al ei (materialul, nu doar nuanta)
GALV_SHEET = ramp(208, 0.15, 0.66, val_span=0.36)  # foaie de otel galvanizat: argintiu rece
RUBBER_ROOF = ramp(232, 0.10, 0.30, val_span=0.30)  # cauciuc negru in randuri
COPPER_ROOF = ramp(22, 0.66, 0.60, hue_shift=9, val_span=0.38)  # foaie de cupru nou, cu cusaturi
TAR_SHAKE = ramp(28, 0.44, 0.44, hue_shift=8, val_span=0.34)  # sindrila de lemn gudronat
BRONZE_SHEET = ramp(60, 0.44, 0.48, hue_shift=8, val_span=0.36)  # foaie de bronz patinat (verde-maslin, cald): mijlociu ca valoare, singurul acoperis verde al liniei; seteaza ciobul violet de pe coama si se desparte de zincul alb al lui Pylon Runner (2350) si de ametistul vecin
AMETHYST = ramp(268, 0.34, 0.50, hue_shift=8, val_span=0.40)  # ardezie ametist
SMOKED_INDIGO = ramp(252, 0.30, 0.42, hue_shift=8, val_span=0.30)  # tabla fumurie, indigo (streasina mai deschisa decat conturul)
BRASS_SHEET = ramp(40, 0.62, 0.64, hue_shift=7, val_span=0.52)  # foaie de alama LUSTRUITA (luciu in gradient, vezi roof(polished)): acoperisul lingourilor, cald, ca sa iasa lila lor; NU paie

# culoarea usii = camasa tinutei, CITITA din lotul de tinute (a4_outfits.RECIPES), ca cele doua loturi sa nu poata diverge.
# d55._door citeste cloth[1..3]: (umbra, umbra, camasa, lumina, lumina).
OUTFIT_OF = {
    "cable_collector": "spooler",
    "cable_porter": "packer",
    "cablemaker": "cablemaker",
    "cable_hauler": "reeler",
    "crystal_collector": "gemfinder",
    "crystal_porter": "bearer",
    "crystalsmith": "crystalsmith",
    "ingot_hauler": "bullioner",
}


def _door_cloth(key):
    r = O.RECIPES[OUTFIT_OF[key]]["recipe"]
    return (r["shirt_d"], r["shirt_d"], r["shirt"], r["shirt_l"], r["shirt_l"])


DOORS = {k: _door_cloth(k) for k in OUTFIT_OF}

# cornisa de sub streasina: marca liniei (cupru la cablu, lila la cristal). Cuprul cu cauciuc sub acoperisul de cupru.
COPPER_BAND = (COPPER[4], COPPER[3], COPPER[1])  # (nituri, fata, umbra)
RUBBER_BAND = (BRASS[3], RUBBER[3], RUBBER[1])
LILAC_BAND = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[0])


POLISH = (0.45, 0.16, 0.40, 0.68, -1, 1)  # foaia lustruita: (cat coboara luciul pe verticala, pragurile 4/3/2 ale gradientului, pasul santului, pasul muchiei)


def clamp(v, a, b):
    return max(a, min(b, v))


class Canvas(C):
    """C care tine minte ce a incercat sa deseneze in afara panzei (un semn taiat de margine nu se vede in joc)."""

    def __init__(self, w, h):
        super().__init__(w, h)
        self.clipped = 0

    def put(self, x, y, col):
        x, y = int(x), int(y)
        if not (0 <= x < self.w and 0 <= y < self.h) and col[3] >= 200:
            self.clipped += 1
            return
        super().put(x, y, col)


# ---------------------------------------------------------------------------------------------
# bucati comune


def roof(c, x0, x1, top, eave, tones, style, period=3, polished=False):
    """Acoperisul in doua ape, in trepte (aceeasi panta ca d55._gable), cu materialul vazut din fata. Lumina din stanga:
    primul sfert al fiecarui rand mai deschis, ultimul mai inchis. `style`: 'seam' = foaie cu cusaturi verticale la `period`
    px (otel, cupru), 'courses' = randuri de sindrila/cauciuc decalate, 'slate' = placi de ardezie in sah. Streasina
    (randul `eave`) e cel mai inchis ton; capacul coamei, cel mai deschis. `polished` (doar la 'seam'): foaie LUSTRUITA, fara
    suprapunerile de la fiecare cinci randuri (care dau aspect de paie): muchia cusaturii e luciu (tonul 4), santul ei cel mai
    inchis, iar in loc de dither un luciu lat pe primul sfert (al treilea) din stanga."""
    h = eave - top
    for i in range(h):
        inset = round((h - 1 - i) * ((x1 - x0) * 0.5 - 2) / max(1, h))
        xa, xb = x0 + inset, x1 - inset
        y = top + i
        span = max(1, xb - xa)
        for x in range(xa, xb + 1):
            u = (x - xa) / span
            t = 2
            if style == "seam" and polished:
                joint = h // 2  # o rostire orizontala la jumatatea apei: doua randuri de foi, cusaturile decalate (ca foi mari, nu fibre de paie)
                ph = (x - x0 + (period // 2 if i > joint else 0)) % period
                # luciul cade in diagonala (stanga-sus -> dreapta-jos), ca pe o foaie lustruita: gradient neted, nu dungi; cusatura e
                # doar un pas mai inchisa (sant) / mai luminoasa (muchie) decat campul
                v = u + POLISH[0] * (i / max(1, h - 1))
                base = 4 if v < POLISH[1] else (3 if v < POLISH[2] else (2 if v < POLISH[3] else 1))
                t = base + POLISH[4] if ph == 0 else (base + POLISH[5] if ph == 1 else base)
                if i == joint:
                    t = base - 1  # rostirea dintre cele doua randuri de foi
                c.put(x, y, tones[clamp(t, 0, len(tones) - 1)])
                continue
            if style == "seam":
                ph = (x - x0) % period
                if ph == 0:
                    t = 1  # santul dintre doua foi
                elif ph == 1:
                    t = 3  # muchia ridicata a foii
                if i % 5 == 4:
                    t -= 1  # suprapunerea foilor, la fiecare cinci randuri
            elif style == "courses":
                t = 2 if i % 2 == 0 else 1
                off = 2 if (i // 2) % 2 else 0
                if (x - x0 + off) % 4 == 0:
                    t -= 1
                elif i % 2 == 0 and (x - x0 + off) % 4 == 1:
                    t += 1
            elif style == "slate":
                g = i // 3
                off = 2 if g % 2 else 0
                t = 2
                if i % 3 == 2:
                    t = 1  # marginea de jos a placii
                elif (x - x0 + off) % 4 == 0:
                    t = 1
                elif i % 3 == 0:
                    t = 3
            dith = (x + y) % 2 == 0
            if u < 0.24 or (u < 0.32 and dith):
                t += 1
            elif u > 0.78 or (u > 0.68 and dith):
                t -= 1
            c.put(x, y, tones[clamp(t, 0, len(tones) - 1)])
    c.rect(x0, eave, x1 - x0 + 1, 1, tones[0])
    mid = x0 + (x1 - x0) // 2
    c.rect(mid - 1, top - 1, 3, 1, tones[4])  # capacul coamei


def wall(c, rng, x0, x1, y0, y1, stone):
    """Peretele de piatra cioplita (blocuri de 3 px) pe un soclu de beton (ultimele doua randuri, ceva mai lat decat zidul)."""
    T.ashlar(c, rng, lambda y: (x0, x1 + 1), y0, y1 - 1, x0, x1 + 1, tones=stone, ch=3, bw=(4, 6), lit=1, dark=2, base=(2, 3))
    c.rect(x0 - 1, y1 - 1, x1 - x0 + 3, 1, CONCRETE[4])
    c.rect(x0 - 1, y1, x1 - x0 + 3, 1, CONCRETE[2])
    c.put(x0 - 1, y1, CONCRETE[3])
    c.put(x1 + 1, y1, CONCRETE[1])
    c.put(x1 + 1, y1 - 1, CONCRETE[3])


def band(c, x0, x1, y, cols, porcelain=False):
    """Cornisa de sub streasina (2 randuri): fata luminata cu nituri, umbra dedesubt."""
    studs, face, shade = cols
    c.rect(x0, y, x1 - x0 + 1, 1, face)
    c.rect(x0, y + 1, x1 - x0 + 1, 1, shade)
    for x in range(x0 + 1, x1, 4):
        c.put(x, y, studs)
    if porcelain:  # capetele cornisei: doi izolatori de portelan (crem), ca pe linia de curent
        for x in (x0, x1):
            c.put(x, y, CREAM[4])
            c.put(x, y + 1, CREAM[2])


def sill(c, x, y, w=5):
    """Pervazul de beton de sub o fereastra (d55._window are cadrul pana la y + 4)."""
    c.rect(x - 1, y + 5, w + 2, 1, CONCRETE[4])
    c.put(x + w, y + 5, CONCRETE[2])


# --- marfa si semne -----------------------------------------------------------------------


# roata caruciorului de fier, 4x4 ca INEL ca a roabei walkerilor: janta de otel pe arcul luminat (sus-stanga), cauciuc pe cel din
# umbra (jos-dreapta), interiorul de fier, butucul de alama. (dx, dy, culoare), cadrul de 8 randuri (randurile y + 4 .. y + 7).
BARROW_WHEEL = (
    (2, 4, STEEL[3]), (3, 4, STEEL[2]),
    (1, 5, STEEL[3]), (2, 5, IRON[0]), (3, 5, IRON[1]), (4, 5, d55.TIRE[1]),
    (1, 6, STEEL[2]), (2, 6, IRON[1]), (3, 6, W.BRASS[3]), (4, 6, d55.TIRE[0]),
    (2, 7, d55.TIRE[1]), (3, 7, d55.TIRE[0]),
)


def barrow_wheel(c, x, y, shift):
    """Roata de 4x4 a caruciorului, cu coltul de sus-stanga la (x + 1 + shift, y + 4); `shift` 0 = roata din stanga, 7 = cea din
    dreapta a caruciorului oglindit. Tonurile raman cele ale luminii din stanga-sus, indiferent de partea pe care sta roata."""
    for dx, dy, col in BARROW_WHEEL:
        c.put(x + dx + shift, y + dy, col)


def iron_barrow(c, x, y):
    """Caruciorul de FIER (13x8), lateral spre stanga, sprijinit pe picior: aceeasi roaba cu care umbla oamenii baraju-
    lui (prop_barrow_iron, d70_modern): cuva de tabla presata cu buza lucioasa si nituri, roata cu cauciuc si butuc de
    alama, manerele imbracate in cauciuc. (x, y) = coltul stanga-sus al panzei de 13x8 (desenul ocupa x + 1 .. x + 11), buza la y."""
    c.rect(x + 2, y, 10, 1, STEEL[4])  # buza lucioasa
    for yy in range(1, 5):  # cuva, ingusta jos
        c.rect(x + 2 + yy // 2, y + yy, 10 - yy, 1, IRON[3] if yy < 3 else IRON[2])
    c.rect(x + 3, y + 1, 8, 1, IRON[0])  # interiorul, in umbra
    for rx in (x + 5, x + 8):
        c.put(rx, y + 2, IRON[4])  # nituri
    barrow_wheel(c, x, y, 0)  # roata din fata (stanga)
    line(c, x + 10, y + 4, x + 11, y + 7, STEEL[2], 1)  # manerul, lasat pe pamant
    c.put(x + 11, y + 7, d55.TIRE[1])
    c.rect(x + 8, y + 5, 1, 3, IRON[1])  # piciorul


def ore(c, x, y, rx, ry, rng):
    """Un bolovan de minereu de cupru (d65_mill.ore_rock: piatra maronie cu vine verzi-albastre)."""
    M.ore_rock(c, x, y, rx, ry, rng)


def rubber_bucket(c, x, y):
    """Cosul de cauciuc negru (7x6) cu un brau de cupru: unde Cable Collector-ul isi tine minereul."""
    c.rect(x, y + 1, 7, 5, G.SHEATH[2])
    c.rect(x, y + 1, 7, 1, G.SHEATH[4])
    c.rect(x, y + 1, 1, 5, G.SHEATH[3])
    c.rect(x + 6, y + 1, 1, 5, G.SHEATH[1])
    c.rect(x, y + 3, 7, 1, COPPER[3])
    c.put(x + 1, y + 3, COPPER[4])
    c.rect(x, y + 5, 7, 1, G.SHEATH[0])


def cradle(c, cx, cy, r, ground):
    """Leaganul de lemn gudronat al unui tambur pe cant (axa spre privitor): doi montanti de-o parte si de alta a flansei, de la
    nivelul axului pana jos, si o talpa pe randul `ground`. (cx, cy) = centrul flansei din fata, `r` = raza ei. Se deseneaza
    INAINTEA tamburului, ca flansa sa stea in fata montantilor."""
    xl, xr = int(cx - r) - 1, int(cx + r) + 1
    for lx, tone in ((xl, TIMBER[3]), (xr, TIMBER[2])):
        c.rect(lx, int(cy), 1, ground - int(cy), tone)
    c.rect(xl, ground, xr - xl + 1, 1, TIMBER[1])
    c.put(xl, ground, TIMBER[3])


def copper_ring(c, x, y):
    """Un colac de sarma de cupru lasat pe pamant (7x4), vazut putin de sus: INEL GOL (spirele alternate cupru deschis / mediu), cu
    gaura de 3x1 lasata transparenta ca outline_trace sa o inchida intr-o gaura adevarata (nu o portocala plina). Arcul din
    spate subtire (randul de sus), cel din fata gros (doua randuri); luciu in stanga-sus, umbra jos. (x, y) = coltul stanga-sus."""
    spec = [(1, 5), (0, 6), (0, 6), (1, 5)]  # (primul, ultimul) offset pe fiecare din cele patru randuri
    for r, (a, b) in enumerate(spec):
        for i in range(a, b + 1):
            if r == 1 and 2 <= i <= 4:
                continue  # gaura inelului, 3x1
            tone = COPPER[3] if (i + r) % 2 == 0 else COPPER[2]
            if r == 3:
                tone = COPPER[1] if i % 2 else COPPER[2]  # arcul de jos, in umbra
            c.put(x + i, y + r, tone)
    c.put(x + 1, y, COPPER[4])  # luciul, sus-stanga
    c.put(x, y + 1, COPPER[4])


def shard(c, x, y, size=3, tone="blue"):
    """Un ciob de cristal in picioare (A1: aceleasi trepte), `x` = coloana din stanga, `y` = randul de jos. size 2..5 randuri,
    de 3 px lat (2 la cele mici): fateta stanga luminata, cea dreapta in umbra."""
    tones = (CRYS[3], CRYS[2], CRYS[1], CRYS[0]) if tone == "blue" else (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    rows = {
        2: [(y - 1, x, x), (y, x, x + 1)],
        3: [(y - 2, x + 1, x + 1), (y - 1, x, x + 2), (y, x, x + 2)],
        4: [(y - 3, x + 1, x + 1), (y - 2, x, x + 2), (y - 1, x, x + 2), (y, x, x + 2)],
        5: [(y - 4, x + 1, x + 1), (y - 3, x + 1, x + 2), (y - 2, x, x + 2), (y - 1, x, x + 2), (y, x, x + 2)],
    }[size]
    P._facet_rows(c, rows, tones)


def finial(c, mid, base, big=False):
    """Ciobul de cristal de pe coama (marca liniei cristalului, vazuta de departe): unul albastru mai inalt, doua violete mai
    scunde, cu baza pe randul capacului coamei (`base`). Se deseneaza INAINTE de contur; conturul lui indigo il pune
    crystal_outline la sfarsit."""
    blue = (CRYS[3], CRYS[2], CRYS[1], CRYS[0])
    vio = (CRYS_VIO[3], CRYS_VIO[2], CRYS_VIO[1], CRYS_VIO[0])
    if big:
        P._facet_rows(c, [(base - 3, mid, mid), (base - 2, mid, mid + 1), (base - 1, mid - 1, mid + 1), (base, mid - 1, mid + 1)], blue)
        P._facet_rows(c, [(base - 2, mid - 4, mid - 4), (base - 1, mid - 4, mid - 3), (base, mid - 4, mid - 3)], vio)
        P._facet_rows(c, [(base - 1, mid + 3, mid + 3), (base, mid + 3, mid + 4)], vio)
    else:
        P._facet_rows(c, [(base - 2, mid, mid), (base - 1, mid, mid + 1), (base, mid - 1, mid + 1)], blue)
        P._facet_rows(c, [(base - 1, mid - 3, mid - 3), (base, mid - 3, mid - 2)], vio)
        P._facet_rows(c, [(base, mid + 3, mid + 3)], vio)


def crystal_outline(c):
    """Conturul cristalului din marfa (A1 / lotul de marfa): un pixel de contur care atinge DOAR pixeli de cristal brut devine
    CRYS_LINE (indigo), iar unul care atinge DOAR pixeli de lingou copt, G.INGOT_LINE (prun); ce atinge si piatra, tabla sau
    lemn ramane maro (conturul comun)."""
    raw = set(CRYS) | set(CRYS_VIO) | {(255, 255, 255, 255)}
    bar = set(G.LILAC) | {G.WHITE}
    out = []
    for y in range(c.h):
        for x in range(c.w):
            if c.px[y][x] != OUTLINE:
                continue
            touch = []
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < c.w and 0 <= ny < c.h and c.px[ny][nx][3] > 200 and c.px[ny][nx] != OUTLINE:
                    touch.append(c.px[ny][nx])
            if not touch:
                continue
            if all(p in raw for p in touch):
                out.append((x, y, CRYS_LINE))
            elif all(p in bar for p in touch):
                out.append((x, y, G.INGOT_LINE))
    for x, y, col in out:
        c.px[y][x] = col


def ingot_frame(c, x, y, w):
    """Cadru prun (G.INGOT_LINE) pe sus si pe stanga unui lingou gem_bar(c, x, y, w): cand lingoul sta lipit de cornisa lila, conturul
    automat nu are unde sa apara, iar lila se contopeste cu lila. Randul de deasupra (y - 1) si coloana din stanga (x - 1,
    randurile y .. y + 2) devin linia lingoului."""
    c.rect(x, y - 1, w, 1, G.INGOT_LINE)
    c.rect(x - 1, y, 1, 3, G.INGOT_LINE)


def mirrored(draw, w, h):
    """Deseneaza `draw(c)` pe o panza w x h si o intoarce oglindita pe orizontala (pentru caruciorul care priveste spre dreapta)."""
    t = Canvas(w, h)
    draw(t)
    return [row[::-1] for row in t.px]


def paste(c, px, x0, y0):
    for yy, row in enumerate(px):
        for xx, p in enumerate(row):
            if p[3]:
                c.put(x0 + xx, y0 + yy, p)


def iron_barrow_r(c, x, y):
    """Caruciorul de fier privind spre DREAPTA (13x8): roata in dreapta, manerele spre casa. Pentru hauleri. Oglindirea intoarce si
    inelul rotii (otelul ar ajunge sus-dreapta, cauciucul jos-stanga, impotriva luminii din stanga-sus), asa ca roata se redeseneaza
    dupa lipire pe coloanele oglindite (x + 8 .. x + 11), cu aceleasi tonuri ca a caruciorului din stanga."""
    paste(c, mirrored(lambda t: iron_barrow(t, 0, 0), 13, 8), x, y)
    barrow_wheel(c, x, y, 7)


def rope_basket(c, x, y, w=8):
    """Cosul de nuiele (w x 4) in care Crystal Collector-ul duce cioburile."""
    c.rect(x, y, w, 4, d55.ROPE[1])
    c.rect(x, y, w, 1, d55.ROPE[3])
    for xx in range(x + 1, x + w, 2):
        c.rect(xx, y + 1, 1, 3, d55.ROPE[0])
    c.put(x, y + 3, d55.ROPE[0])


# ---------------------------------------------------------------------------------------------
# casa


def hut(small, seed, key, cfg, extra):
    """O casa: mica (32x28) sau mare (40x34). `cfg`: stone, tones, style, period, band (culori), span ((x0, x1) mica, mare),
    walls ((x0, x1) mica, mare), door ((x) mica, mare), windows, finial. `extra(c, rng)` = semnul meseriei."""
    rng = Rng(seed)
    k = 0 if small else 1
    if small:
        c = Canvas(32, 28)
        soft_shadow(c, 16, 26, 14, 2)
        y0, y1, top, eave = 14, 25, 3 + cfg.get("lower", 0), 14
        door = (cfg["door"][0], 18, 5, 8)
        wins = [(cfg["win"][0], 17)]
    else:
        c = Canvas(40, 34)
        soft_shadow(c, 20, 32, 18, 2)
        y0, y1, top, eave = 17, 31, 4 + cfg.get("lower", 0), 17
        door = (cfg["door"][1], 21, 6, 10)
        wins = [(cfg["win"][1][0], 21), (cfg["win"][1][1], 21)]
    wx0, wx1 = cfg["walls"][k]
    sx0, sx1 = cfg["span"][k]
    wall(c, rng, wx0, wx1, y0, y1, cfg["stone"])
    band(c, wx0, wx1, eave + 1, cfg["band"], porcelain=cfg.get("porcelain", False))
    roof(c, sx0, sx1, top, eave, cfg["tones"], cfg["style"], cfg.get("period", 3), cfg.get("polished", False))
    for wxx, wyy in wins:
        d55._window(c, wxx, wyy)
        sill(c, wxx, wyy)
    d55._door(c, door[0], door[1], door[2], door[3], DOORS[key])
    if cfg.get("finial"):
        finial(c, sx0 + (sx1 - sx0) // 2, top - 1, big=not small)
    extra(c, rng)
    outline_trace(c)
    crystal_outline(c)
    return c


def chimney_pipe(c, x, top, bottom, cap=COPPER):
    """Hornul de tabla galvanizata (3 lat) cu un colier si capac de cupru: al Cablemaker-ului."""
    c.rect(x, top, 3, bottom - top, GALV_SHEET[2])
    c.rect(x, top, 1, bottom - top, GALV_SHEET[4])
    c.rect(x + 2, top, 1, bottom - top, GALV_SHEET[1])
    c.rect(x - 1, top, 5, 1, cap[3])
    c.put(x - 1, top, cap[4])
    c.rect(x, top + 3, 3, 1, GALV_SHEET[0])
    c.put(x + 1, top + 3, cap[3])


CHIMNEYS = {}  # nume sprite -> (x horn, latime, latimea panzei): cat sa se scrie in PadArt.CHIMNEY


def register_chimney(name, x, width, canvas_w):
    CHIMNEYS[name] = ((x + width / 2) / canvas_w, 0.03)


# ---------------------------------------------------------------------------------------------
# linia cablului


CABLE_COLLECTOR = dict(
    porcelain=True, stone=DSTONE, tones=GALV_SHEET, style="seam", period=3, band=COPPER_BAND,
    span=((2, 29), (1, 32)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_cable_collector_1():
    def extra(c, rng):
        d56._gaff(c, 26, 14)  # carligul cade pe randul intunecat al streasinii si pe aerul de langa perete, nu pe tabla argintie
        rubber_bucket(c, 21, 20)
        ore(c, 23, 20, 2.2, 1.5, rng)
        ore(c, 25.6, 20.4, 1.8, 1.3, rng)

    return hut(True, 7401, "cable_collector", CABLE_COLLECTOR, extra)


def prop_hut_cable_collector_2():
    def extra(c, rng):
        d56._gaff(c, 1, 20)  # pe piatra din stanga, nu pe cornisa
        c.rect(31, 28, 8, 3, TIMBER[2])  # lada de minereu, cu o gramada de bolovani deasupra
        c.rect(31, 28, 8, 1, TIMBER[4])
        for rx, ry in ((33, 27), (36, 27), (34.5, 25)):
            ore(c, rx, ry, 2.2, 1.6, rng)
        ore(c, 36.4, 24.4, 1.7, 1.3, rng)
        rubber_bucket(c, 29, 25)  # cosul de cauciuc, pe pamant, cu minereu proaspat

    return hut(False, 7402, "cable_collector", CABLE_COLLECTOR, extra)


CABLE_PORTER = dict(
    porcelain=True, stone=DSTONE, tones=RUBBER_ROOF, style="courses", band=COPPER_BAND,
    span=((3, 30), (4, 37)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_cable_porter_1():
    def extra(c, rng):
        iron_barrow(c, 19, 19)
        ore(c, 24, 19.0, 2.6, 1.7, rng)
        ore(c, 27.6, 19.4, 2.2, 1.5, rng)
        ore(c, 3.0, 24.5, 2.2, 1.5, rng)  # minereul adus, gramada langa perete (nu un colac: portarul duce minereu)
        ore(c, 5.6, 25.0, 1.8, 1.3, rng)

    return hut(True, 7403, "cable_porter", CABLE_PORTER, extra)


def prop_hut_cable_porter_2():
    def extra(c, rng):
        iron_barrow(c, 26, 25)
        ore(c, 31, 25.0, 2.4, 1.6, rng)
        ore(c, 34.6, 25.4, 2.2, 1.5, rng)
        ore(c, 32.6, 23.2, 2.0, 1.4, rng)
        ore(c, 3.0, 30.5, 2.2, 1.5, rng)  # minereul adus, gramada langa perete (nu un colac: portarul duce minereu)
        ore(c, 5.6, 31.0, 1.8, 1.3, rng)

    return hut(False, 7404, "cable_porter", CABLE_PORTER, extra)


CABLEMAKER = dict(
    porcelain=True, stone=DSTONE, tones=COPPER_ROOF, style="seam", period=4, band=RUBBER_BAND,
    span=((1, 28), (3, 36)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_cablemaker_1():
    def extra(c, rng):
        chimney_pipe(c, 21, 1, 8)
        register_chimney("hut_cablemaker_1", 21, 3, 32)
        cradle(c, 25.5, 20.0, 3.5, 25)
        G.reel(c, 25.5, 20.0, 3.5, depth=1, tail=(27, 24))

    return hut(True, 7405, "cablemaker", CABLEMAKER, extra)


def prop_hut_cablemaker_2():
    def extra(c, rng):
        chimney_pipe(c, 26, 1, 10)
        register_chimney("hut_cablemaker_2", 26, 3, 40)
        cradle(c, 31.5, 26.0, 4.0, 31)
        G.reel(c, 31.5, 26.0, 4.0, depth=2, tail=(34, 31))
        copper_ring(c, 1, 27)  # un colac de cupru gata, pe pamant, langa perete

    return hut(False, 7406, "cablemaker", CABLEMAKER, extra)


CABLE_HAULER = dict(
    porcelain=True, stone=DSTONE, tones=TAR_SHAKE, style="courses", band=COPPER_BAND,
    span=((3, 28), (2, 34)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_cable_hauler_1():
    def extra(c, rng):
        G.reel(c, 26.0, 19.0, 3.0, depth=2, tip=True)  # intai incarcatura, apoi roaba: peretele cuvei acopera jumatatea de jos
        iron_barrow_r(c, 19, 19)

    return hut(True, 7407, "cable_hauler", CABLE_HAULER, extra)


def prop_hut_cable_hauler_2():
    def extra(c, rng):
        G.reel(c, 33.5, 22.0, 3.5, depth=2, tip=True)  # al doilea, pe jumatate asezat peste primul si mutat spre dreapta (x >= 30: nu atinge cornisa)
        G.reel(c, 30.5, 25.0, 3.5, depth=2, tip=True)
        iron_barrow_r(c, 26, 25)

    return hut(False, 7408, "cable_hauler", CABLE_HAULER, extra)


# ---------------------------------------------------------------------------------------------
# linia cristalului


CRYSTAL_COLLECTOR = dict(
    lower=1, stone=CSTONE, tones=BRONZE_SHEET, style="seam", period=4, band=LILAC_BAND, finial=True,
    span=((2, 29), (1, 32)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_crystal_collector_1():
    def extra(c, rng):
        d56._gaff(c, 26, 14)
        rope_basket(c, 20, 22)
        shard(c, 21, 22, 4, "blue")
        shard(c, 23, 22, 5, "vio")
        shard(c, 25, 22, 3, "blue")

    return hut(True, 7411, "crystal_collector", CRYSTAL_COLLECTOR, extra)


def prop_hut_crystal_collector_2():
    def extra(c, rng):
        d56._gaff(c, 1, 20)
        c.rect(29, 29, 9, 2, TIMBER[2])  # banc
        c.rect(29, 29, 9, 1, TIMBER[4])
        rope_basket(c, 29, 25, 5)
        rope_basket(c, 34, 25, 4)
        shard(c, 29, 25, 4, "vio")
        shard(c, 31, 25, 5, "blue")
        shard(c, 34, 25, 4, "blue")
        shard(c, 36, 25, 3, "vio")

    return hut(False, 7412, "crystal_collector", CRYSTAL_COLLECTOR, extra)


CRYSTAL_PORTER = dict(
    lower=1, stone=CSTONE, tones=AMETHYST, style="slate", band=LILAC_BAND, finial=True,
    span=((3, 30), (4, 37)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_crystal_porter_1():
    def extra(c, rng):
        shard(c, 22, 19, 4, "blue")  # cioburile intai, apoi roaba (cuva le acopera baza)
        shard(c, 24, 19, 5, "vio")
        shard(c, 27, 19, 3, "blue")
        iron_barrow(c, 19, 19)

    return hut(True, 7413, "crystal_porter", CRYSTAL_PORTER, extra)


def prop_hut_crystal_porter_2():
    def extra(c, rng):
        shard(c, 29, 25, 4, "blue")
        shard(c, 31, 25, 5, "vio")
        shard(c, 34, 25, 3, "blue")
        iron_barrow(c, 26, 25)
        c.rect(1, 29, 7, 2, STONE[2])  # un bolovan de cristal langa perete, pe un soclu de piatra (cioburile mai scunde: nu ating pervazul)
        c.rect(1, 29, 7, 1, STONE[4])
        shard(c, 1, 29, 4, "blue")
        shard(c, 3, 29, 4, "vio")
        shard(c, 5, 29, 3, "blue")

    return hut(False, 7414, "crystal_porter", CRYSTAL_PORTER, extra)


def kiln_chimney(c, x, top, bottom):
    """Hornul de piatra al Crystalsmith-ului (5 lat): blocuri in randuri, un colier de fier, jar in gura."""
    for y in range(top, bottom):
        for xx in range(x, x + 5):
            t = 3 if xx < x + 2 else (2 if xx < x + 4 else 1)
            if (y - top) % 3 == 2:
                t -= 1
            c.put(xx, y, CSTONE[t])
    c.rect(x - 1, top, 7, 1, CSTONE[5])
    c.rect(x - 1, top + 1, 7, 1, CSTONE[1])
    c.put(x + 1, top, M.EMBER[2])
    c.put(x + 2, top, M.EMBER[3])
    c.put(x + 3, top, M.EMBER[2])
    c.rect(x, top + 5, 5, 1, IRON[1])


FIREBRICK = ramp(32, 0.34, 0.62, hue_shift=6, val_span=0.40)  # caramida refractara a cuptorului: bej cald, se desprinde de piatra violeta


def kiln(c, x, y, w=9, h=7):
    """Cuptorul mic de langa usa: cupola de piatra cu gura arcuita, jar si un ciob de cristal care se incinge inauntru."""
    for r in range(h):
        inset = 2 if r == 0 else (1 if r == 1 else 0)
        for xx in range(x + inset, x + w - inset):
            t = 3 if xx < x + 3 else (2 if xx < x + w - 3 else 1)
            if r == 0:
                t += 1
            if r == h - 1:
                t -= 1
            if (r + xx // 3) % 3 == 2 and 0 < r < h - 1:
                t -= 1  # rosturile caramizilor, decalate
            c.put(xx, y + r, FIREBRICK[clamp(t, 0, 4)])
    mid = x + w // 2
    for r in range(3, h):  # gura arcuita: ramul de fier, inauntru jar de jos in sus
        half = 1 if r == 3 else 2
        for xx in range(mid - half, mid + half + 1):
            tone = IRON[1] if (r == 3 or xx in (mid - half, mid + half)) else IRON[0]
            c.put(xx, y + r, tone)
    for r in range(4, h):
        for xx in range(mid - 1, mid + 2):
            c.put(xx, y + r, M.EMBER[1] if r == h - 1 else (M.EMBER[2] if r == h - 2 else M.EMBER[3]))
    c.put(mid, y + h - 2, M.EMBER[4])
    c.put(mid, y + 4, CRYS_VIO[2])  # cristalul din cuptor


def mould(c, x, y, w=7):
    """Forma de turnat din piatra (w x 3), cu lingoul de cristal inca fierbinte in ea. Lingoul e cel al lotului de marfa (G.LILAC,
    lila-argintiu), ca fierarul sa toarne ce duce haulerul mai departe, nu un cristal brut albastru; un pixel de jar la capatul
    drept ("inca fierbinte") si o sclipire alba pe fata de sus."""
    c.rect(x, y, w, 3, CSTONE[1])
    c.rect(x, y, w, 1, CSTONE[4])
    c.rect(x, y + 2, w, 1, CSTONE[0])
    c.rect(x + 1, y, w - 2, 1, G.LILAC[4])
    c.put(x + 3, y, G.WHITE)
    c.put(x + w - 2, y, M.EMBER[3])
    c.rect(x + 1, y + 1, w - 2, 1, G.LILAC[2])


def tongs(c, x, y, h):
    """Cleste de fierar (doua brate de 1 px) agatat de flancul cuptorului: manerele sus, desfacute (stanga luminat, dreapta in umbra,
    ca sa se vada si pe peretele inchis, si pe caramida deschisa a cuptorului), falcile jos, unite pe coloana `x`, cu un nit la o treime.
    (x, y) = falcile (coloana) si varful de sus; `h` = inaltimea."""
    line(c, x - 1, y, x, y + h - 1, STEEL[3], 1)
    line(c, x + 1, y, x, y + h - 1, IRON[1], 1)
    c.put(x - 1, y, STEEL[4])
    c.put(x, y + h // 3, STEEL[4])
    c.put(x, y + h - 1, IRON[0])


def quench_barrel(c, x, y):
    """Butoiul de calire (5x6): doage de lemn cald (nu lemnul gudronat al peretelui, care se pierde in umbra), doua cercuri de fier,
    un rand de apa (cristal albastru) deasupra."""
    c.rect(x, y + 1, 5, 5, WOOD[2])
    c.rect(x, y + 1, 1, 5, WOOD[3])
    c.rect(x + 4, y + 1, 1, 5, WOOD[1])
    c.rect(x, y + 2, 5, 1, IRON[1])  # cercuri
    c.rect(x, y + 4, 5, 1, IRON[1])
    c.rect(x, y, 5, 1, WOOD[4])  # gura butoiului
    c.rect(x + 1, y, 3, 1, CRYS[2])  # apa
    c.put(x + 1, y, CRYS[3])


CRYSTALSMITH = dict(
    lower=1, stone=CSTONE, tones=SMOKED_INDIGO, style="courses", band=LILAC_BAND, finial=True,
    span=((1, 28), (3, 36)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_crystalsmith_1():
    def extra(c, rng):
        kiln_chimney(c, 21, 1, 9)
        register_chimney("hut_crystalsmith_1", 21, 5, 32)
        kiln(c, 22, 19, 9, 7)
        tongs(c, 21, 20, 6)
        mould(c, 1, 23)

    return hut(True, 7415, "crystalsmith", CRYSTALSMITH, extra)


def prop_hut_crystalsmith_2():
    def extra(c, rng):
        kiln_chimney(c, 26, 1, 10)
        register_chimney("hut_crystalsmith_2", 26, 5, 40)
        kiln(c, 28, 23, 11, 9)
        tongs(c, 27, 23, 9)
        mould(c, 5, 26, 6)  # doua forme de 6 px, la stanga de tocul usii (x 11)
        mould(c, 5, 29, 6)
        quench_barrel(c, 1, 25)

    return hut(False, 7416, "crystalsmith", CRYSTALSMITH, extra)


INGOT_HAULER = dict(
    lower=1, stone=CSTONE, tones=BRASS_SHEET, style="seam", period=5, polished=True, band=LILAC_BAND, finial=True,
    span=((2, 29), (2, 34)), walls=((5, 26), (4, 29)), door=(15, 12), win=(8, (6, 21)),
)


def prop_hut_ingot_hauler_1():
    def extra(c, rng):
        ingot_frame(c, 21, 16, 8)  # lingoul incadrat in prun: sta IN FATA cornisei, nu se lipeste de ea
        G.gem_bar(c, 21, 16, 8)
        iron_barrow_r(c, 19, 19)

    return hut(True, 7417, "ingot_hauler", INGOT_HAULER, extra)


def prop_hut_ingot_hauler_2():
    def extra(c, rng):
        G.gem_bar(c, 28, 22, 5)  # doua lingouri (inventarul: "2 mari"); al treilea de sus se lipea de cornisa
        G.gem_bar(c, 33, 22, 5)
        iron_barrow_r(c, 26, 25)

    return hut(False, 7418, "ingot_hauler", INGOT_HAULER, extra)


SPRITES = {
    "prop_hut_cable_collector_1": prop_hut_cable_collector_1,
    "prop_hut_cable_collector_2": prop_hut_cable_collector_2,
    "prop_hut_cable_porter_1": prop_hut_cable_porter_1,
    "prop_hut_cable_porter_2": prop_hut_cable_porter_2,
    "prop_hut_cablemaker_1": prop_hut_cablemaker_1,
    "prop_hut_cablemaker_2": prop_hut_cablemaker_2,
    "prop_hut_cable_hauler_1": prop_hut_cable_hauler_1,
    "prop_hut_cable_hauler_2": prop_hut_cable_hauler_2,
    "prop_hut_crystal_collector_1": prop_hut_crystal_collector_1,
    "prop_hut_crystal_collector_2": prop_hut_crystal_collector_2,
    "prop_hut_crystal_porter_1": prop_hut_crystal_porter_1,
    "prop_hut_crystal_porter_2": prop_hut_crystal_porter_2,
    "prop_hut_crystalsmith_1": prop_hut_crystalsmith_1,
    "prop_hut_crystalsmith_2": prop_hut_crystalsmith_2,
    "prop_hut_ingot_hauler_1": prop_hut_ingot_hauler_1,
    "prop_hut_ingot_hauler_2": prop_hut_ingot_hauler_2,
}
SIZES = {n: ((32, 28) if n.endswith("_1") else (40, 34)) for n in SPRITES}


# ---------------------------------------------------------------------------------------------
# previzualizarea


# ce imprumuta azi fiecare meserie (TycoonConfig.PAD_LOOKS_LIKE): fisierul din assets/sprites, fara _1 / _2
BORROWED = {
    "cable_collector": "works_collector",
    "cable_porter": "works_porter",
    "cablemaker": "wiredrawer",
    "cable_hauler": "coil_hauler",
    "crystal_collector": "ore_collector",
    "crystal_porter": "ore_porter",
    "crystalsmith": "coppersmith",
    "ingot_hauler": "copper_hauler",
}
TRADES = list(BORROWED)
# (pad, x lume, imprumutul de azi) pentru colibele care NU sunt in lotul asta: le desenam estompat, ca sa se vada randul intreg
OTHER_PADS = [
    ("hire_barrel_hauler", 1210, "power_hauler"),
    ("hire_relay_keeper", 2190, "founder"),
    ("hire_pylon_runner", 2350, "parts_hauler"),
]
PAD_X = {
    "cable_collector": 1370, "cable_porter": 1520, "cablemaker": 1670, "cable_hauler": 1820,
    "crystal_collector": 2510, "crystal_porter": 2660, "crystalsmith": 2810, "ingot_hauler": 2960,
}
BASE_Y = 1620  # TycoonConfig.buildingBase: pad.y (1564) + 56


def edge_touch(c):
    """Pixeli de desen (nu de contur, nu de umbra) lipiti de marginea panzei: acolo conturul n-are loc si semnul pare taiat."""
    bad = []
    for y in range(c.h):
        for x in range(c.w):
            p = c.px[y][x]
            if p[3] > 200 and p not in (OUTLINE, CRYS_LINE, G.INGOT_LINE) and (x in (0, c.w - 1) or y == 0):
                bad.append((x, y))
    return bad


def to_image(c):
    img = Image.new("RGBA", (c.w, c.h))
    img.putdata([p for row in c.px for p in row])
    return img


def font(size):
    try:
        return ImageFont.truetype(FONT, size)
    except OSError:
        return ImageFont.load_default()


def load_sprite(name):
    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


def ground_strip(regen=False):
    """Pamantul copt al barajului (lumea 2), decupat pe randul colibelor: art px (1 px = 3 de lume), x 360..1010, y 470..560.
    Se coace o data (~5 s) si se tine in scratchpad."""
    cache = os.path.join(SCRATCH, "huts_cc", "ground_huts.png")
    if os.path.exists(cache) and not regen:
        return Image.open(cache).convert("RGBA")
    import a1_plate as A  # noqa: E402
    import village_ground as VG  # noqa: E402

    img = A.ground_image(VG.geometry(2)).crop((360, 470, 1010, 560))
    os.makedirs(os.path.dirname(cache), exist_ok=True)
    img.save(cache)
    return img


def preview(sprites, regen=False):
    lab = font(8)
    bg = (86, 128, 64, 255)
    S = 4
    pad = 14
    ink = (255, 255, 255, 255)
    # 1. foaia: pe fiecare meserie, noua _1 | imprumutata _1 | noua _2 | imprumutata _2, la x4
    cell_w = (32 + 32 + 40 + 40) * S + 5 * pad
    row_h = 34 * S + 26
    half = len(TRADES) // 2
    sheet = Image.new("RGBA", (2 * cell_w + pad, half * row_h + 22), (28, 32, 36, 255))
    d = ImageDraw.Draw(sheet)
    for n, trade in enumerate(TRADES):
        col, r = divmod(n, half)
        x0 = col * (cell_w + pad)
        y0 = 22 + r * row_h
        tile = Image.new("RGBA", (cell_w, row_h - 4), bg)
        x = pad
        for k in (1, 2):
            new = to_image(sprites[f"prop_hut_{trade}_{k}"])
            old = load_sprite(f"prop_hut_{BORROWED[trade]}_{k}")
            for im, tag in ((new, "NEW"), (old, "BORROWED")):
                big = im.resize((im.width * S, im.height * S), Image.NEAREST)
                tile.alpha_composite(big, (x, row_h - 4 - 6 - big.height))
                ImageDraw.Draw(tile).text((x, 3 if k == 1 else 3), f"{tag} {im.width}x{im.height}", font=lab, fill=ink)
                x += big.width + pad
        ImageDraw.Draw(tile).text((pad, 14), trade.replace("_", " ").upper(), font=lab, fill=(255, 236, 160, 255))
        sheet.alpha_composite(tile, (x0, y0))
    d.text((4, 6), "A4 huts: cable and crystal lines (x4): NEW next to the borrowed art it replaces", font=lab, fill=ink)

    # 2. in context: pe pamantul barajului, la pozitiile padurilor, la scara jocului (1 px de arta = 3 de lume), x3
    ground = ground_strip(regen)
    gx0, gy0 = 360, 470
    K = 3

    def strip(k, title):
        crop = ground.copy()
        for pad_id, wx, twin in OTHER_PADS:  # vecinii, estompati
            im = load_sprite(f"prop_hut_{twin}_{k}").copy()
            alpha = im.getchannel("A").point(lambda v: int(v * 0.45))
            im.putalpha(alpha)
            crop.alpha_composite(im, (round(wx / 3 - im.width / 2) - gx0, round(BASE_Y / 3 - im.height) - gy0))
        for trade in TRADES:
            im = to_image(sprites[f"prop_hut_{trade}_{k}"])
            crop.alpha_composite(im, (round(PAD_X[trade] / 3 - im.width / 2) - gx0, round(BASE_Y / 3 - im.height) - gy0))
        big = crop.resize((crop.width * K, crop.height * K), Image.NEAREST)
        out = Image.new("RGBA", (big.width, big.height + 14), (28, 32, 36, 255))
        out.alpha_composite(big, (0, 14))
        ImageDraw.Draw(out).text((4, 3), title, font=lab, fill=ink)
        return out

    s1 = strip(1, "IN CONTEXT, first hires (_1), game scale: cable x 1370-1820, crystal x 2510-2960; pale = other lots' huts (borrowed)")
    s2 = strip(2, "IN CONTEXT, second hires (_2)")
    W_ = max(sheet.width, s1.width)
    full = Image.new("RGBA", (W_, sheet.height + s1.height + s2.height), (28, 32, 36, 255))
    full.alpha_composite(sheet, (0, 0))
    full.alpha_composite(s1, (0, sheet.height))
    full.alpha_composite(s2, (0, sheet.height + s1.height))
    path = os.path.join(SCRATCH, "huts_cable_crystal_preview.png")
    full.save(path)
    return path


def main():
    out = SCRATCH
    if "--out" in sys.argv:
        out = sys.argv[sys.argv.index("--out") + 1]
    os.makedirs(out, exist_ok=True)
    built = {}
    for name, draw in SPRITES.items():
        c = draw()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        if c.clipped:
            print("  ATENTIE: iese din panza:", name, c.clipped)
        if edge_touch(c):
            print("  ATENTIE: lipit de margine (fara contur):", name, edge_touch(c)[:6])
        png(os.path.join(out, name + ".png"), c.w, c.h, c.px)
        print("  scris", name, f"{c.w}x{c.h}")
        built[name] = c
    print("PadArt.CHIMNEY (sprite = {(x horn + latime / 2) / latimea panzei, 0.03}):")
    for k, v in CHIMNEYS.items():
        print(f"    {k} = {{{v[0]:.3f}, {v[1]}}}")
    print("previzualizare:", preview(built, "--regen-ground" in sys.argv))


if __name__ == "__main__":
    main()
