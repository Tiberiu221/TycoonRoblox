#!/usr/bin/env python3
"""[D75, lotul A4, grupul "outfits"] Cele 15 foi de tinuta ale oamenilor barajului (Era 4). Scrie DOAR in --out (implicit
folderul de lucru (scripts/art/scratch.py)); nimic nu intra in assets/sprites si nimic nu se urca. Nu editeaza settlers.py: IMPORTA desenatorul lui
(`build_sheet`) si ii da 15 retete noi, adaugate in dictionarul OUTFITS doar in memorie (register()).

Fiecare foaie e 64x480 = 4 cadre de 16x24 x 20 randuri (settlers.ROWS), STRATUL tinutei, fara tinta de culoare, exact ca
assets/sprites/outfit_*.png (corpul, parul si pielea vin din body_*/hair_*, recolorate de joc la rulare; PersonView deseneaza
x2,5). Numele cheii din joc (people.outfit.<Nume>) -> fisierul `outfit_<nume>.png`.

  nume          meseria (HandConfig.ROLE_OUTFIT)   silueta     veteran?  desenul de imprumut de azi
  Turbineer     damCollector  (Collector)          brim        da        fisher
  Lugger        damPorter     (Porter)             dome        da        crafter
  Switchman     switchman     (omul de la gater)   hardhat     da        builder
  Cooper        barrelHauler  (Hauler)             kerchief    da        gardener
  Dispatcher    dispatcher    (vanzatorul)         band+haina  da        innkeeper
  Spooler       cableCollector                     brim        nu        dredger
  Packer        cablePorter                        dome        nu        barrowman
  Cablemaker    cablemaker    (atelier)            band+sort   nu        wiredrawer
  Reeler        cableHauler                        kerchief    nu        coiler
  Relayman      relayKeeper   (atelier)            hardhat+sort nu       founder
  Linewalker    pylonRunner                        kerchief    nu        wheelwright
  Gemfinder     crystalCollector                   brim        nu        prospector
  Bearer        crystalPorter                      dome        nu        mucker
  Crystalsmith  crystalsmith  (atelier)            band+sort   nu        coppersmith
  Bullioner     ingotHauler                        kerchief    nu        teamster

REGULA DE SILUETA (D56/D65/D67): culegator = bor, carator = caciula, hauler = basma, atelier = banda + sort (sau casca: Builder,
Electrician), vanzator = banda (+ haina). Nu se foloseste nicio silueta doar-a-jucatorului (bucket, cap, tophat, feathercap,
hood, wreath, tricorn), iar `player` nu apare. Pantalonii, cizmele, ciocanul si lada sunt globale: o tinuta se deosebeste doar prin
camasa, palarie, sort si haina.

TABELUL DE CULORI (conflictele din inventar, rezolvate intr-un singur loc; nuantele in HSV, grade). Lectia din calcul: spatiul de
camasi libere dintre cele 29 de tinute existente e mic si doar vioi (electric), deci Era 4 e rece si luminoasa, cu accente calde in
palarii; un neutru inchis nu mai are loc (Smith, Traveler, Dredger, Clerk, trei caciuli inchise le acopera).
  Turbineer    camasa jad 151, luminoasa                       bor de muselina uleiata, verde-ardezie (3d5248, ridicat din 2f3d38: la
               (inventarul propunea 'jade ~140': luat)         asta umbra borului era o treapta reala, nu un mat de contur). Nu seamana
                                                               cu Gleaner (174, bor nisip) si nici cu Dredger (213, bor galben-pal)
  Lugger       camasa lime 76 (hi-vis)                         caciula portocaliu de semnal; NU carbune (Barrowman, Hodman, Carter
                                                               poarta deja trei caciuli inchise si gri), nici bleumarin
  Switchman    camasa de beton cald, gri-bej (38, sat 0,10)    casca ROSIE; Builder e galben pe portocaliu, Electrician alb pe
                                                               albastru, deci rosu nu exista la casti
  Cooper       camasa albastru-violet luminos 244              basma de stejar auriu (c8a858, culoarea benzilor de alama de pe
                                                               butoaie; nu indigo-ul lui Ironmonger (236, mai inchis, basma gri) si
                                                               nu galbenul Freighter-ului, la dE 24 de el). Stejarul inchis de la
                                                               inceput (6a4020) era la dE 8,3 de parul castaniu si 6,3 de pielea 5:
                                                               nodul de la ceafa, silueta haulerului, se topea in cap
  Dispatcher   haina lunga maslinie de sef de gara (4c5c20, 76)  banda rosie de semnal (mai vie decat banda Innkeeper-ului, dE 28 de
                                                               ea): veteranul ramane 'rosu la cap', dar nu e aceeasi tinuta. Turcoazul
                                                               de la inceput (1f5a5a) era la dE 1,3 de haina pass-ului Supporter
                                                               (1f5a5c, doar a jucatorului): un jucator cu pass ar fi parut vanzatorul
  Spooler      camasa rosu intens 353 (nicio camasa de bor      bor bleumarin-regal; Era 4 nu mai are carbune: negrul lui Smith si
               nu e rosie)                                      otelul lui Dredger il inghit
  Packer       camasa cerulean 198, luminoasa                  caciula tricotata rosu de izolatie (c83048); galbenul-soare (f0c040)
                                                               cadea langa borul de paie al pescarului (Fisher, dE 18) si langa
                                                               camasa lui albastra (dE 20): dom si bor difera cu 1-2 px la x2,5
  Cablemaker   camasa verde-primavara 104, luminoasa           banda albastra (nicio alta banda nu e albastra), sort de otel zincat
                                                               (9aa4ae, materialul GALV al barajului); portocaliul de izolatie facea
                                                               cu verdele aceeasi pereche ca Coiler-ul (verde + portocaliu)
  Reeler       camasa magenta 311                              basma alba, nu alb curat (dedecf, lumina f6f6ea: altfel lumina se taie
                                                               la 255 si treapta dispare); Freighter e roz 338 cu basma galbena
  Relayman     camasa aqua 176 (30c4b8, nodul curentului)      casca ALBASTRA, sort de piele inchis; Electrician are casca alba.
                                                               Turcoazul mai inchis (183) cadea la dE 10 de Gleaner; 28d8c8 (sat. 0,81,
                                                               val. 0,85) era cea mai tipatoare camasa din oras
  Linewalker   camasa alb-cald (dcdad2, treptele de mana)     basma portocaliu-rosie de semnal (12); niciun haulier nu poarta
                                                               camasa alba. f0eee6 se taia la 255 in lumina (treapta dE 5,6)
  Gemfinder    camasa liliac deschis 263                       bor albastru-de-gheata (9ccbe6, lumina c2e2f6 de mana); Lineman are
                                                               bor alb pe galben
  Bearer       camasa coral 8, vie (cald, printre cele reci)   caciula violet de cristal (784ed6); visinia-adanca de la inceput era
                                                               la dE 1,2 marja de Hodman (portocaliu-ars, caciula gri-inchis)
  Crystalsmith camasa cian-gheata palida (9cd4ea, de mana)     sort violet de cristal (784ed6, CRYS_VIO[1] din lotul A1), banda
                                                               galben aprins (jarul cuptorului; nu ambra: Clerk are banda aurie la
                                                               dE 11 de ea); Coppersmith e crem cu sort verde de cupru. Sortul
                                                               violet-fumuriu de la inceput (4a3a68) avea dE 2 de pantaloni si
                                                               bustul, sortul si picioarele faceau o singura placa violeta
  Bullioner    jerseu de piele rosu-vin 733444 (piele de lingou) basma violet de cristal (784ed6); violetul-negru de la inceput
                                                               (2a1a50) avea nuanta pantalonilor si luminanta sub contur, iar bratele
                                                               dispareau, si era a patra basma albastru-violet (Wheelwright,
                                                               Ironmonger, Cooper). Maroul 6b4c3b era la dE 6,4 de drumul barajului
                                                               si 6,6 de pielea 5: bustul devenea o gaura in drum
Treptele de lumina / umbra: (0,10 / 0,15) pentru camasa si palarie (mai blande ca primele 0,15-0,17: echipa noua citea ca bomboana langa
retrasi si piatra barajului); pe culorile palide, unde shade(+) se taie la 255, lumina e data de mana in reteta (shirt_l / hat_l).
Culorile in clar sunt in RECIPES; `--emit` tipareste exact intrarile pentru settlers.OUTFITS (dupa freighter, inaintea lui
supporter) cand owner-ul aproba.

INTEGRARE (dupa aprobare; nimic din ele nu e facut aici): intrarile de la `--emit` in settlers.OUTFITS si numele in lista din
`__main__` a lui settlers.py; 15 randuri OVERRIDE `outfit_<nume>: <Nume>` in scripts/upload_assets.py; randurile
`sprite(0, 64, 480)` in Assets.people.outfit; HandConfig.OUTFIT_LOOKS_LIKE ramane ca rezerva pana cand id-urile sunt reale.
In ROLE_OUTFIT cheia e `<Nume>` cu litera mare (Turbineer ...), in fisier `outfit_turbineer.png`.

VERIFICARI (`check_*`, la fiecare rulare; pica cu eroare, nu cu avertisment; praguri in CIELAB dE76):
  - reteta: silueta permisa si cea a meseriei, fara `player`, haina doar la vanzator, sort doar la ateliere, nicio culoare cu
    LUMINANTA sub cea a conturului + 10 (nu canalul maxim: un albastru-violet inchis il trecea), trepte de lumina in ordine si de cel
    putin dE 8 de baza, umbra la cel putin dE 12 de contur; camasa la dE >= 30 de pantaloni, umbra camasii la >= 25, iar sortul si
    poala lui (apron[2], desenata peste coapse) la >= 25 de pantaloni; CAPUL SI DRUMUL: camasa la >= 12 de oricare din cele 6 pieli ale
    jocului (foaia gri a corpului x SettlerConfig.SKIN) si la >= 15 de cele doua culori ale drumului de pamant din prop_dam_ground
    (112,88,64) / (126,100,74); palaria (bor, caciula, casca, basma; nu banda) la >= 12 de piele si la >= 14 de oricare din cele 6
    culori de par (foaia gri a parului x SettlerConfig.HAIR_COLORS). 14 si nu 15: cel mai apropiat caz acceptat e Turbineer pe parul
    carunt (14,6); Cooper-ul vechi era la 8,3. Pragurile ar fi prins Cooper-ul cu basma 6a4020 (piele 6,3, par 8,3) si Bullioner-ul cu
    jerseu 6b4c3b (piele 6,6, drum 6,4);
  - DISTINCTIE fata de TOATE cele 29 de tinute ne-ale-jucatorului din settlers.OUTFITS (oamenii retrasi din toate erele umbla prin
    Dam Town), fata de cele 9 DOAR ale jucatorului (keeper, angler, captain, legend, cele patru ale croitoresei, supporter = pass-ul de
    Robux) si intre cele 15. Tinutele jucatorului nu poarta nicio silueta de meserie, deci conteaza doar camasa si haina: camasa
    >= 20 fata de orice tinuta a jucatorului cu aceeasi haina (Dispatcher-ul cu 1f5a5a trecea fiindca existing_outfits() le scotea:
    era la dE 1,3 de Supporter) si >= 12 fata de oricare. Aceeasi silueta: (camasa >= 22 SI palarie/sort >= 18) SAU (camasa >= 16 SI palarie/sort >= 40, pentru
    neutrele inchise); doua tinute din Era 4 cu aceeasi silueta: camasa >= 30; cu orice silueta: camasa >= 18 intre ele si >= 12 fata
    de orice tinuta existenta; alta silueta nu scuza gemenii (camasa < 12 SI palarie < 25 pica); banda unei tinute noi: >= 25 fata de
    orice alta banda. Rezultatul de la ultima rulare: cea mai apropiata camasa de una existenta dE 12,2 (Linewalker-Coppersmith, alta
    silueta si alt sort), intre cele 15 dE 19,3; la aceeasi silueta, cea mai mica marja e 1,28x pragul (Turbineer-Gleaner; Cooper-
    Ironmonger 1,31); fata de tinutele jucatorului: aceeasi haina dE 29,9 (Switchman-Angler; Dispatcher-Keeper 32,0, Dispatcher-Supporter 38,5), orice haina 15,8;
  - foaia: exact 64x480, fara pixeli negri opaci (umbra moale 0,0,0,70 din randul sleep e a desenatorului comun), fiecare celula (20 x 4)
    are tinuta desenata;
  - straturile: corp + par + tinuta, suprapuse, dau foaia "all" (settlers.verify_layers) cu doua corpuri si doua coafuri;
  - desenatorul chemat de mine da, pentru `fisher`, exact assets/sprites/outfit_fisher.png.

PREVIZUALIZARE (`outfits_preview.png`, in scratchpad, niciodata in --out). Capetele sunt colorate ca in joc: corpul si parul se
INMULTESC cu paletele din SettlerConfig.SKIN / HAIR_COLORS (PersonView: ImageColor3), nu se retinteaza in HSV; toate cele 6 pieli si
cele 6 culori de par apar printre cei 15. (A) fiecare foaie la x4 (in picioare + mers), langa cea de imprumut de azi; (B) toti 15, in picioare si mergand, la x2,5 pe pamantul barajului, in linie; (C) fiecare langa tinuta pe care
o inlocuieste, la x2,5; (D) tabelul de culori cu cei mai apropiati vecini (si cea mai apropiata tinuta a jucatorului).

Rulare: python3 scripts/art/a4_outfits.py [--out DIR] [--emit]
"""
import argparse
import colorsys
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from PIL import Image, ImageDraw, ImageFont  # noqa: E402

import settlers as S  # noqa: E402
from buildings import C, hexc, png  # noqa: E402
from palette import hsv, shade  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
import scratch  # noqa: E402  (folderul de lucru: DRIFTWOOD_SCRATCH sau .scratch/)
SCRATCH = scratch.folder("a4")
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"
GROUND = os.path.join(SPR, "prop_dam_ground.png")

SHEET_W, SHEET_H = S.FW * S.COLS, S.FH * len(S.ROWS)  # 64 x 480

# silueta permisa (cele de meserie); cele doar-ale-jucatorului nu intra niciodata
ALLOWED_KINDS = ("brim", "dome", "hardhat", "kerchief", "band")

# ---------------------------------------------------------------------------------------------
# CAPUL SI DRUMUL pe care umbla oamenii: tot ce se verifica in plus fata de distinctia intre tinute.
# PALETELE JOCULUI, copiate din SettlerConfig.SKIN / HAIR_COLORS (nu din tintele HSV ale lui settlers._apply_tint, care dau capete mai
# luminoase decat in joc). PersonView pune pe foaia GRI a corpului si a parului `ImageColor3 = tint`, adica INMULTESTE fiecare pixel
# cu tint/255 (conturul si ochii la fel); tinuta nu se coloreaza. Blondul din joc pe parul gri 958c7c iese ~(120,93,47), carunt
# ~(104,98,84): toate capetele sunt inchise, iar o palarie intunecata si o basma palida se judeca pe asta, nu pe un par recolorat.
GAME_SKINS = [(246, 214, 184), (231, 188, 150), (205, 154, 112), (171, 120, 82), (128, 87, 60), (92, 62, 44)]
GAME_HAIRS = [(46, 36, 32), (92, 62, 40), (148, 104, 58), (206, 170, 96), (166, 82, 48), (178, 178, 172)]
# Pielea si parul gri ale foilor corp_* / par_* inmultite cu paletele jocului = ce se vede cu adevarat sub tinuta (PersonView, ImageColor3).
TINTED_SKINS = [tuple(round(b * t / 255) for b, t in zip(S.SKIN, tint)) for tint in GAME_SKINS]
TINTED_HAIRS = [tuple(round(b * t / 255) for b, t in zip(S.HAIR, tint)) for tint in GAME_HAIRS]
# cele doua culori ale drumului de pamant din prop_dam_ground (cele mai dese dupa iarba, pe drumul pe care umbla oamenii prin Dam Town)
DAM_ROAD = ((112, 88, 64), (126, 100, 74))
# palaria care acopera parul (banda e o fasie de un rand: nu se judeca)
COVERS_HAIR = ("brim", "dome", "hardhat", "kerchief")
# praguri (dE76): camasa fata de oricare din cele 6 pieli si fata de drum; palaria fata de piele si de par; camasa fata de o tinuta DOAR a
# jucatorului cu aceeasi haina (o copie a unei tinute platite nu mai trece), iar fata de orice tinuta a jucatorului ca de orice alta existenta.
# HAT_HAIR e 14, nu 15: cel mai apropiat caz acceptat e Turbineer pe parul carunt (14,6); Cooper-ul vechi (basma 6a4020) era la 8,3.
SHIRT_SKIN, HAT_SKIN, HAT_HAIR, SHIRT_ROAD, PLAYER_SHIRT = 12.0, 12.0, 14.0, 15.0, 20.0


# ---------------------------------------------------------------------------------------------
# retetele. Culoarea de baza + palette.shade() da treptele (lumina in stanga-sus, umbra spre dreapta); sortul are trei trepte.
def _lum(c):
    """Luminanta (Rec.601, 0..255): aceeasi masura la reteta, la verificare si la plafonul umbrelor."""
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


LUM_FLOOR = _lum(S.OUT) + 10  # o culoare mai intunecata decat asta se pierde in contur (OUT are luminanta ~28)


def _tri(hexs, up, down, floor=0.20, lit=None, dark=None):
    """(baza, lumina, umbra). Umbra nu coboara sub `floor` (valoare HSV) si nici sub LUM_FLOOR in luminanta: conturul (36,26,18)
    are v 0.14, iar o umbra mai neagra decat conturul ar disparea in el. Plafonul pe luminanta prinde si albastrul-violet, unde
    canalul maxim ramane sus desi culoarea e deja neagra la ochi. `lit` / `dark` (hex) fixeaza o treapta de mana: lumina lui
    shade(+) se taie la 255 pe culorile palide si treapta dispare (alb 255,254,248 la dE 5 de baza)."""
    base = hexc(hexs)
    lo = hexc(dark) if dark else shade(base, -down)
    if not dark:
        h, s, v = colorsys.rgb_to_hsv(*(x / 255 for x in lo[:3]))
        v = max(v, floor)
        lo = hsv(h * 360, s, v)
        while _lum(lo) < LUM_FLOOR and v < 1.0:
            v += 0.01
            lo = hsv(h * 360, s, v)
    hi = hexc(lit) if lit else shade(base, up)
    return base, hi, lo


# treptele de lumina / umbra: mai blande decat primele (0,15 / 0,17 si 0,14 / 0,16 dadeau trepte de dE 13-18, fata de ~10 la cele
# 29 de foi aprobate; cu mediana valorii la .78 contra .56 a satului, echipa noua citea ca bomboana langa retrasi si piatra)
SHIRT_STEP, HAT_STEP = (0.10, 0.15), (0.10, 0.15)


def _recipe(shirt, hat, kind, coat=False, apron=None, shirt_l=None, shirt_d=None, hat_l=None, hat_d=None):
    s, sl, sd = _tri(shirt, *SHIRT_STEP, lit=shirt_l, dark=shirt_d)
    h, hl, hd = _tri(hat, *HAT_STEP, lit=hat_l, dark=hat_d)
    r = dict(shirt=s, shirt_l=sl, shirt_d=sd, hat=h, hat_d=hd, hat_l=hl, hat_kind=kind, coat=coat)
    if apron is not None:
        a, al, ad = _tri(apron, 0.12, 0.16)
        r["apron"] = (a, al, ad)
    return r


# cheia = numele din Assets.people.outfit (cu litera mica in fisier); meseria, veteranul si desenul de azi sunt in clar
RECIPES = {
    "turbineer": dict(
        name="Turbineer", hire="damCollector", job="empties the turbine nets", veteran=True, replaces="fisher",
        recipe=_recipe("3fae78", "3d5248", "brim")),
    "lugger": dict(
        name="Lugger", hire="damPorter", job="barrows batteries to the Switchyard", veteran=True, replaces="crafter",
        recipe=_recipe("a4cf2e", "e0782a", "dome")),
    "switchman": dict(
        name="Switchman", hire="switchman", job="loads charge into barrels", veteran=True, replaces="builder",
        recipe=_recipe("9a948a", "c8392c", "hardhat")),
    "cooper": dict(
        name="Cooper", hire="barrelHauler", job="rolls barrels to the Relay", veteran=True, replaces="gardener",
        recipe=_recipe("5a52c8", "c8a858", "kerchief")),
    "dispatcher": dict(
        name="Dispatcher", hire="dispatcher", job="sells power at the Switch House", veteran=True, replaces="innkeeper",
        recipe=_recipe("4c5c20", "e83a3a", "band", coat=True)),
    "spooler": dict(
        name="Spooler", hire="cableCollector", job="empties the cable-ore nets", veteran=False, replaces="dredger",
        recipe=_recipe("c8283a", "2c4090", "brim")),
    "packer": dict(
        name="Packer", hire="cablePorter", job="barrows ore to the Cable Works", veteran=False, replaces="barrowman",
        recipe=_recipe("3aa6d6", "c83048", "dome")),
    "cablemaker": dict(
        name="Cablemaker", hire="cablemaker", job="spins cable at the Cable Works", veteran=False, replaces="wiredrawer",
        recipe=_recipe("66b848", "3aa0f0", "band", apron="9aa4ae")),
    "reeler": dict(
        name="Reeler", hire="cableHauler", job="carts cable to the Relay", veteran=False, replaces="coiler",
        recipe=_recipe("c040a8", "dedecf", "kerchief", shirt_l="df4db7", hat_l="f6f6ea")),
    "relayman": dict(
        name="Relayman", hire="relayKeeper", job="joins barrels and cable into power", veteran=False, replaces="founder",
        recipe=_recipe("30c4b8", "3a78c8", "hardhat", apron="4a3424")),
    "linewalker": dict(
        name="Linewalker", hire="pylonRunner", job="walks power up the pylon lane", veteran=False, replaces="wheelwright",
        recipe=_recipe("dcdad2", "e8502a", "kerchief", shirt_l="f6f5f0", shirt_d="b0aca0")),
    "gemfinder": dict(
        name="Gemfinder", hire="crystalCollector", job="empties the crystal net", veteran=False, replaces="prospector",
        recipe=_recipe("b9a0e0", "9ccbe6", "brim", hat_l="c2e2f6")),
    "bearer": dict(
        name="Bearer", hire="crystalPorter", job="barrows crystal to the Kiln", veteran=False, replaces="mucker",
        recipe=_recipe("e0614c", "784ed6", "dome")),
    "crystalsmith": dict(
        name="Crystalsmith", hire="crystalsmith", job="fires crystal into ingots", veteran=False, replaces="coppersmith",
        recipe=_recipe("9cd4ea", "f0e040", "band", apron="784ed6", shirt_l="c4ecfa", shirt_d="74aac4")),
    "bullioner": dict(
        name="Bullioner", hire="ingotHauler", job="carts ingots to the Switch House", veteran=False, replaces="teamster",
        recipe=_recipe("733444", "784ed6", "kerchief")),
}


def register():
    """Pune cele 15 retete in settlers.OUTFITS (doar in memorie). Daca owner-ul le-a lipit deja in settlers.py, trebuie sa fie
    IDENTICE cu astea, altfel foaia din joc si cea de aici ar diverge in tacere."""
    for key, meta in RECIPES.items():
        if key in S.OUTFITS:
            assert S.OUTFITS[key] == meta["recipe"], f"settlers.OUTFITS['{key}'] difera de reteta din a4_outfits.py"
        S.OUTFITS[key] = meta["recipe"]


def existing_outfits():
    """Tinutele de meserie/clienti deja existente (fara cele 15 si fara cele doar-ale-jucatorului)."""
    return {n: o for n, o in S.OUTFITS.items() if n not in RECIPES and not o.get("player")}


def player_outfits():
    """Tinutele DOAR ale jucatorului (keeper, angler, captain, legend, cele ale croitoresei, supporter = pass-ul de Robux). Nu intra in
    distinctia pe siluete (nicio tinuta noua nu poarta palaria lor), dar o camasa + haina copiate de la ele ar face dintr-un om al
    satului un jucator cu pass platit: de aceea intra in distinctia de culoare."""
    return {n: o for n, o in S.OUTFITS.items() if n not in RECIPES and o.get("player")}


# ---------------------------------------------------------------------------------------------
# foile: o functie pe tinuta, fiecare intoarce o panza de EXACT 64x480
def _sheet(key):
    c = S.build_sheet("outfit", body="a", outfit=key, hair="short")
    assert (c.w, c.h) == (SHEET_W, SHEET_H), (key, c.w, c.h)
    return c


def outfit_turbineer():
    return _sheet("turbineer")


def outfit_lugger():
    return _sheet("lugger")


def outfit_switchman():
    return _sheet("switchman")


def outfit_cooper():
    return _sheet("cooper")


def outfit_dispatcher():
    return _sheet("dispatcher")


def outfit_spooler():
    return _sheet("spooler")


def outfit_packer():
    return _sheet("packer")


def outfit_cablemaker():
    return _sheet("cablemaker")


def outfit_reeler():
    return _sheet("reeler")


def outfit_relayman():
    return _sheet("relayman")


def outfit_linewalker():
    return _sheet("linewalker")


def outfit_gemfinder():
    return _sheet("gemfinder")


def outfit_bearer():
    return _sheet("bearer")


def outfit_crystalsmith():
    return _sheet("crystalsmith")


def outfit_bullioner():
    return _sheet("bullioner")


SPRITES = {
    "outfit_turbineer": outfit_turbineer,
    "outfit_lugger": outfit_lugger,
    "outfit_switchman": outfit_switchman,
    "outfit_cooper": outfit_cooper,
    "outfit_dispatcher": outfit_dispatcher,
    "outfit_spooler": outfit_spooler,
    "outfit_packer": outfit_packer,
    "outfit_cablemaker": outfit_cablemaker,
    "outfit_reeler": outfit_reeler,
    "outfit_relayman": outfit_relayman,
    "outfit_linewalker": outfit_linewalker,
    "outfit_gemfinder": outfit_gemfinder,
    "outfit_bearer": outfit_bearer,
    "outfit_crystalsmith": outfit_crystalsmith,
    "outfit_bullioner": outfit_bullioner,
}
SIZES = {name: (SHEET_W, SHEET_H) for name in SPRITES}


# ---------------------------------------------------------------------------------------------
# culoare: CIELAB (dE76) pentru distinctie
def _lab(c):
    r, g, b = [x / 255 for x in c[:3]]

    def lin(u):
        return ((u + 0.055) / 1.055) ** 2.4 if u > 0.04045 else u / 12.92

    r, g, b = lin(r), lin(g), lin(b)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116

    fx, fy, fz = f(x), f(y), f(z)
    return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)


def de(a, b):
    la, lb = _lab(a), _lab(b)
    return math.sqrt(sum((p - q) ** 2 for p, q in zip(la, lb)))


def _hsv(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return round(h * 360), round(s, 2), round(v, 2)


def _second(o):
    """Al doilea element care deosebeste doua tinute de aceeasi silueta: palaria, sau sortul cand ambele au sort (la banda, palaria
    e doar o fasie de un rand, iar sortul si haina fac silueta)."""
    return o["apron"][0] if "apron" in o else o["hat"]


def second_dist(a, b):
    """dE al celui de-al doilea element (palarie; la banda: sort), 60 daca structura diferita (sort / haina lunga se vad dintr-o privire)."""
    if a["hat_kind"] == "band":
        if ("apron" in a) != ("apron" in b) or a["coat"] != b["coat"]:
            return 60.0
        return de(_second(a), _second(b))
    return de(a["hat"], b["hat"])


# PRAGURI (CIELAB dE76). Doua tinute cu ACEEASI silueta se deosebesc daca
#   (camasa >= 22 SI al doilea element >= 18)  SAU  (camasa >= 16 SI al doilea element >= 40):
# a doua varianta e pentru neutrele inchise, unde dE e comprimat (carbune, bleumarin, vinisiu) si palaria face diferenta.
# Alta silueta: gemene doar daca camasa < 12 SI palaria < 25. Doua tinute din Era 4 cu aceeasi silueta: camasa >= 30; cu orice
# silueta: camasa >= 18. Nicio camasa noua mai aproape de 12 de ORICE tinuta existenta, oricare ar fi palaria.
SAME_A, SAME_B, DIFF_LIM, ERA4_SHIRT = (22.0, 18.0), (16.0, 40.0), (12.0, 25.0), 30.0
ERA4_ANY, ANY_MIN = 18.0, 12.0
SHIRT_PANTS, APRON_PANTS, STEP_MIN = (30.0, 25.0), 25.0, (8.0, 8.0)  # (camasa, umbra camasii) fata de pantaloni; sort/poala; (lumina, umbra)
BAND_MIN = 25.0  # la banda, palaria e o fasie de un rand: culoarea ei trebuie sa fie clar alta decat a oricarei alte benzi


def pair_margin(ds, d2):
    """>= 1 inseamna ca perechea trece; cu cat mai mic, cu atat mai apropiate."""
    return max(min(ds / SAME_A[0], d2 / SAME_A[1]), min(ds / SAME_B[0], d2 / SAME_B[1]))


def distinction_rows():
    """Pentru fiecare tinuta noua: perechea cea mai apropiata si vecinii, ca date (verificare, tabel, previzualizare)."""
    old = existing_outfits()
    players = player_outfits()
    everyone = dict(old)
    everyone.update({k: m["recipe"] for k, m in RECIPES.items()})
    rows = []
    for key, meta in RECIPES.items():
        o = meta["recipe"]
        same = [(n, p, de(o["shirt"], p["shirt"]), second_dist(o, p)) for n, p in everyone.items()
                if n != key and p["hat_kind"] == o["hat_kind"]]
        diff = [(n, de(o["shirt"], p["shirt"]), de(o["hat"], p["hat"])) for n, p in everyone.items()
                if n != key and p["hat_kind"] != o["hat_kind"]]
        worst = min(same, key=lambda t: pair_margin(t[2], t[3]))
        near_shirt = min(same, key=lambda t: t[2])
        era4 = [t for t in same if t[0] in RECIPES]
        era4_near = min(era4, key=lambda t: t[2]) if era4 else None
        any_near = min(((de(o["shirt"], p["shirt"]), n) for n, p in everyone.items() if n != key))
        era4_any = min(((de(o["shirt"], p["shirt"]), n) for n, p in everyone.items() if n != key and n in RECIPES))
        twins = [(n, ds, dh) for n, ds, dh in diff if ds < DIFF_LIM[0] and dh < DIFF_LIM[1]]
        # tinutele doar ale jucatorului: cea mai apropiata camasa cu ACEEASI haina (copia pass-ului) si cea mai apropiata, oricare ar fi haina
        player_same = min(((de(o["shirt"], p["shirt"]), n) for n, p in players.items() if p["coat"] == o["coat"]), default=None)
        player_any = min((de(o["shirt"], p["shirt"]), n) for n, p in players.items())
        band_near = (min((de(o["hat"], p["hat"]), n) for n, p in everyone.items() if n != key and p["hat_kind"] == "band")
                     if o["hat_kind"] == "band" else None)
        rows.append(dict(key=key, worst=worst[:1] + worst[2:], near_shirt=near_shirt[:1] + near_shirt[2:],
                         era4=(era4_near[0], era4_near[2]) if era4_near else None, any=any_near, era4_any=era4_any,
                         twins=twins, band_near=band_near, player_same=player_same, player_any=player_any,
                         margin=pair_margin(worst[2], worst[3])))
    return rows


# ---------------------------------------------------------------------------------------------
# verificari
def check_recipes():
    for key, meta in RECIPES.items():
        o = meta["recipe"]
        assert o["hat_kind"] in ALLOWED_KINDS, (key, o["hat_kind"])
        assert not o.get("player"), key
        if o["coat"]:
            assert key == "dispatcher", f"{key}: haina lunga e doar a vanzatorului"
        if "apron" in o:
            assert key in ("cablemaker", "relayman", "crystalsmith"), f"{key}: sortul e doar al atelierelor"
        cols = [o["shirt"], o["shirt_l"], o["shirt_d"], o["hat"], o["hat_l"], o["hat_d"]] + list(o.get("apron", ()))
        for c in cols:
            # luminanta, nu canalul maxim: un albastru-violet intunecat (2a1a50) trece de "max >= 51" si totusi se topeste in contur
            assert _lum(c) > LUM_FLOOR, f"{key}: culoare mai inchisa decat conturul {c} (luminanta {_lum(c):.0f} <= {LUM_FLOOR:.0f})"
        assert _lum(o["shirt_l"]) > _lum(o["shirt"]) > _lum(o["shirt_d"]), (key, "trepte camasa")
        if o["hat_kind"] != "band":  # banda e un singur rand, din `hat`: treptele ei nu se deseneaza
            assert _lum(o["hat_l"]) > _lum(o["hat"]) > _lum(o["hat_d"]), (key, "trepte palarie")
        # camasa nu se contopeste cu pantalonii (altfel bratele si talia dispar intr-o coloana): atat camasa, cat si umbra ei
        assert de(o["shirt"], S.PANTS) >= SHIRT_PANTS[0], (key, "camasa prea aproape de pantaloni", de(o["shirt"], S.PANTS))
        assert de(o["shirt_d"], S.PANTS) >= SHIRT_PANTS[1], (key, "umbra camasii prea aproape de pantaloni", de(o["shirt_d"], S.PANTS))
        # CAPUL SI DRUMUL: camasa nu se pierde in nicio piele a jocului si nici pe drumul de pamant pe care umbla; palaria (cu excep. benzii)
        # nu se pierde in piele si nici in par (Cooper-ul cu basma 6a4020 si Bullioner-ul cu jerseu 6b4c3b treceau de toate celelalte praguri)
        assert min(de(o["shirt"], c) for c in TINTED_SKINS) >= SHIRT_SKIN, (key, "camasa se pierde in piele", min(de(o["shirt"], c) for c in TINTED_SKINS))
        assert min(de(o["shirt"], c) for c in DAM_ROAD) >= SHIRT_ROAD, (key, "camasa se pierde pe drumul barajului", min(de(o["shirt"], c) for c in DAM_ROAD))
        if o["hat_kind"] in COVERS_HAIR:
            assert min(de(o["hat"], c) for c in TINTED_SKINS) >= HAT_SKIN, (key, "palaria se pierde in piele", min(de(o["hat"], c) for c in TINTED_SKINS))
            assert min(de(o["hat"], c) for c in TINTED_HAIRS) >= HAT_HAIR, (key, "palaria se pierde in par", min(de(o["hat"], c) for c in TINTED_HAIRS))
        if "apron" in o:  # sortul si poala lui (apron[2], desenata peste coapse) se deosebesc de pantaloni
            assert de(o["apron"][0], S.PANTS) >= APRON_PANTS, (key, "sortul e culoarea pantalonilor", de(o["apron"][0], S.PANTS))
            assert de(o["apron"][2], S.PANTS) >= APRON_PANTS, (key, "poala sortului e culoarea pantalonilor", de(o["apron"][2], S.PANTS))
        # treptele se vad: lumina si umbra la cel putin dE 8 de baza (foile aprobate: ~8-11 lumina, 12-17 umbra), umbra si la dE 12 de contur
        for part, base, lit, dark in (("camasa", "shirt", "shirt_l", "shirt_d"), ("palarie", "hat", "hat_l", "hat_d")):
            if part == "palarie" and o["hat_kind"] == "band":
                continue
            assert de(o[base], o[lit]) >= STEP_MIN[0], (key, part, "treapta de lumina se pierde", de(o[base], o[lit]))
            assert de(o[base], o[dark]) >= STEP_MIN[1], (key, part, "treapta de umbra se pierde", de(o[base], o[dark]))
            assert de(o[dark], S.OUT) >= 12, (key, part, "umbra se topeste in contur", de(o[dark], S.OUT))
        # silueta ceruta de meserie
        expect = {"damCollector": "brim", "cableCollector": "brim", "crystalCollector": "brim",
                  "damPorter": "dome", "cablePorter": "dome", "crystalPorter": "dome",
                  "barrelHauler": "kerchief", "cableHauler": "kerchief", "pylonRunner": "kerchief", "ingotHauler": "kerchief",
                  "switchman": "hardhat", "relayKeeper": "hardhat",
                  "cablemaker": "band", "crystalsmith": "band", "dispatcher": "band"}
        assert expect[meta["hire"]] == o["hat_kind"], (key, "silueta nu e a meseriei")
    print("reteta: silueta, luminanta peste contur, trepte de lumina, camasa/sort fata de pantaloni, camasa/palarie fata de piele, par si drum: OK (15)")


def check_distinct(verbose=True):
    rows = distinction_rows()
    bad = []
    if verbose:
        print(f"{'tinuta':13s} {'silueta':9s} cea mai apropiata pereche de aceeasi silueta (camasa dE / palarie-sort dE, marja)"
              f"{'':3s}{'camasa cea mai apropiata':30s}{'Era 4':18s}{'oricare':17s}jucator (aceeasi haina)")
    for r in rows:
        key = r["key"]
        kind = RECIPES[key]["recipe"]["hat_kind"]
        wn, wds, wd2 = r["worst"]
        if r["margin"] < 1.0:
            bad.append(f"{key}: perechea cu {wn} (camasa dE {wds:.1f}, palarie/sort dE {wd2:.1f}) nu trece de praguri")
        if r["era4"] and r["era4"][1] < ERA4_SHIRT:
            bad.append(f"{key}: camasa dE {r['era4'][1]:.1f} fata de {r['era4'][0]}, ambele din Era 4 (minim {ERA4_SHIRT})")
        if r["band_near"] and r["band_near"][0] < BAND_MIN:
            bad.append(f"{key}: banda dE {r['band_near'][0]:.1f} fata de banda lui {r['band_near'][1]} (minim {BAND_MIN})")
        if r["any"][0] < ANY_MIN:
            bad.append(f"{key}: camasa dE {r['any'][0]:.1f} fata de {r['any'][1]} (orice silueta, minim {ANY_MIN})")
        if r["era4_any"][0] < ERA4_ANY:
            bad.append(f"{key}: camasa dE {r['era4_any'][0]:.1f} fata de {r['era4_any'][1]} (ambele din Era 4, orice silueta, minim {ERA4_ANY})")
        for n, ds, dh in r["twins"]:
            bad.append(f"{key}: camasa dE {ds:.1f} si palarie dE {dh:.1f} fata de {n} (alta silueta, dar tot gemene)")
        if r["player_same"] and r["player_same"][0] < PLAYER_SHIRT:
            bad.append(f"{key}: camasa dE {r['player_same'][0]:.1f} fata de tinuta jucatorului {r['player_same'][1]}, ambele cu aceeasi haina"
                       f" (minim {PLAYER_SHIRT}: ar fi o copie a unei tinute doar a jucatorului)")
        if r["player_any"][0] < ANY_MIN:
            bad.append(f"{key}: camasa dE {r['player_any'][0]:.1f} fata de tinuta jucatorului {r['player_any'][1]} (orice haina, minim {ANY_MIN})")
        if verbose:
            e4 = f"{r['era4'][0]} {r['era4'][1]:.0f}" if r["era4"] else "-"
            print(f"{key:13s} {kind:9s} {wn:12s} {wds:5.1f} / {wd2:5.1f}  marja {r['margin']:.2f}   "
                  f"{r['near_shirt'][0]:11s} {r['near_shirt'][1]:5.1f}   {e4:17s} {r['any'][1]:11s} {r['any'][0]:4.1f}   "
                  f"{r['player_same'][1]:11s} {r['player_same'][0]:5.1f}")
    if bad:
        raise SystemExit("DISTINCTIE ESUATA:\n  " + "\n  ".join(bad))
    print(f"distinctie (dE76, praguri {SAME_A} sau {SAME_B}, Era 4 intre ele {ERA4_SHIRT}): OK (15 fata de {len(existing_outfits())} existente "
          f"+ {len(player_outfits())} ale jucatorului)")
    bands = ", ".join(f"{r['key']} {r['band_near'][0]:.0f} (fata de {r['band_near'][1]})" for r in rows if r["band_near"])
    print(f"  benzi (dE fata de cea mai apropiata alta banda): {bands}")
    worst_any = min(r["any"][0] for r in rows)
    worst_e4 = min(r["era4_any"][0] for r in rows)
    print(f"  camasa cea mai apropiata de o tinuta existenta, orice silueta: dE {worst_any:.1f}; intre cele 15, orice silueta: dE {worst_e4:.1f}")
    ps = min(r["player_same"][0] for r in rows if r["player_same"])
    pa = min(r["player_any"][0] for r in rows)
    print(f"  fata de cele {len(player_outfits())} tinute doar ale jucatorului (supporter, keeper, ...): aceeasi haina dE {ps:.1f} (minim {PLAYER_SHIRT}), orice haina dE {pa:.1f} (minim {ANY_MIN})")


def check_sheets(sheets):
    for name, c in sheets.items():
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        for y in range(c.h):
            for x in range(c.w):
                p = c.px[y][x]
                # umbra moale de pe randul `sleep` (0,0,0,70) e a desenatorului comun si e in toate foile aprobate; conteaza doar negrul opac
                assert not (p[3] == 255 and p[:3] == (0, 0, 0)), f"{name}: negru pur la {x},{y}"
        for r, row in enumerate(S.ROWS):
            for f in range(S.COLS):
                n = sum(1 for yy in range(S.FH) for xx in range(S.FW) if c.px[r * S.FH + yy][f * S.FW + xx][3] > 0)
                assert n >= 12, f"{name}: celula {row}/{f} aproape goala ({n} px)"
    print(f"foile: {len(sheets)} x {SHEET_W}x{SHEET_H}, fara negru opac, toate cele 80 de celule desenate: OK")


def check_layers():
    for key in RECIPES:
        for body, hair in (("a", "short"), ("b", "long")):
            assert S.verify_layers(body, hair, key), f"{key}: straturile corp+par+tinuta nu dau foaia 'all' ({body}/{hair})"
    print("straturi: corp + par + tinuta == foaia 'all', cu doua corpuri si doua coafuri, pentru toate 15: OK")


def check_renderer_matches_assets():
    path = os.path.join(SPR, "outfit_fisher.png")
    if not os.path.exists(path):
        print("renderer: outfit_fisher.png lipseste, sarit")
        return
    im = Image.open(path).convert("RGBA")
    mine = S.build_sheet("outfit", outfit="fisher")
    for y in range(mine.h):
        for x in range(mine.w):
            assert tuple(im.getpixel((x, y))) == tuple(mine.px[y][x]), f"fisher difera de assets la {x},{y}"
    print("renderer: S.build_sheet('outfit', 'fisher') == assets/sprites/outfit_fisher.png la pixel: OK")


def emit():
    """Intrarile pentru settlers.OUTFITS, in aceeasi forma ca cele existente (de lipit dupa freighter)."""
    def h(c):
        return f'hexc("{c[0]:02x}{c[1]:02x}{c[2]:02x}")'

    for key, meta in RECIPES.items():
        o = meta["recipe"]
        print(f'    "{key}": dict(shirt={h(o["shirt"])}, shirt_l={h(o["shirt_l"])}, shirt_d={h(o["shirt_d"])},')
        print(f'                       hat={h(o["hat"])}, hat_d={h(o["hat_d"])}, hat_l={h(o["hat_l"])},')
        tail = f'hat_kind="{o["hat_kind"]}", coat={o["coat"]}'
        if "apron" in o:
            print(f"                       {tail},")
            print(f'                       apron=({h(o["apron"][0])}, {h(o["apron"][1])}, {h(o["apron"][2])})),')
        else:
            print(f"                       {tail}),")


# ---------------------------------------------------------------------------------------------
# previzualizarea
# cine poarta tinuta in previzualizare: (corp, coafura, piele, par), indici in GAME_SKINS / GAME_HAIRS. Veteranii pastreaza corpul si
# parul vechi; perechea de imprumut se arata cu ACEEASI persoana, ca sa se vada doar haina schimbata. Cele 15 acopera toate cele 6
# pieli si toate cele 6 culori de par, iar tinutele cu palarie inchisa (Turbineer, Spooler) sunt pe parul cel mai apropiat de ea.
WHO = {
    "turbineer": ("a", "short", 0, 1), "lugger": ("b", "bun", 1, 3), "switchman": ("a", "long", 2, 4),
    "cooper": ("b", "short", 3, 0), "dispatcher": ("a", "bun", 1, 5), "spooler": ("b", "long", 4, 2),
    "packer": ("a", "short", 5, 1), "cablemaker": ("b", "short", 0, 4), "reeler": ("a", "long", 2, 0),
    "relayman": ("b", "bun", 3, 3), "linewalker": ("a", "short", 4, 2), "gemfinder": ("b", "long", 1, 5),
    "bearer": ("a", "bun", 5, 0), "crystalsmith": ("b", "short", 2, 1), "bullioner": ("a", "long", 3, 4),
}
_LAYERS = {}


def _layers(outfit, body, hair):
    k = (outfit, body, hair)
    if k not in _LAYERS:
        _LAYERS[k] = [S.build_sheet(layer, body=body, outfit=outfit, hair=hair) for layer in ("body", "hair", "outfit")]
    return _LAYERS[k]


def _multiply(sheet, tint):
    """ImageColor3 din Roblox: fiecare pixel RGB x tint/255, alfa neatins."""
    out = C(sheet.w, sheet.h)
    for y in range(sheet.h):
        for x in range(sheet.w):
            p = sheet.px[y][x]
            if p[3]:
                out.px[y][x] = (round(p[0] * tint[0] / 255), round(p[1] * tint[1] / 255), round(p[2] * tint[2] / 255), p[3])
    return out


_TINTED = {}


def person(outfit, who_key, row="idle_down", f=0):
    """Un cadru 16x24, ca in joc: corp (x piele), par (x par), tinuta (netintata) peste. Tinta e inmultirea din PersonView, nu retinta HSV."""
    body, hair, si, hi = WHO[who_key]
    lay = _layers(outfit, body, hair)
    r = S.ROWS.index(row)
    out = C(S.FW, S.FH)
    for i, sheet in enumerate(lay):
        if i < 2:  # corpul si parul se coloreaza la rulare; tinuta nu
            tk = (outfit, body, hair, si, hi, i)
            if tk not in _TINTED:
                _TINTED[tk] = _multiply(sheet, GAME_SKINS[si] if i == 0 else GAME_HAIRS[hi])
            sheet = _TINTED[tk]
        for y in range(S.FH):
            for x in range(S.FW):
                p = sheet.px[r * S.FH + y][f * S.FW + x]
                if p[3]:
                    out.put(x, y, p)
    return out


def _img(c, w, h):
    im = Image.new("RGBA", (c.w, c.h))
    im.putdata([p for row in c.px for p in row])
    return im.resize((w, h), Image.NEAREST)


def person_img(outfit, who_key, row, f, scale):
    """scale = pixeli de lume pe pixel de arta (4 la planse, 2,5 in joc). Marimea se rotunjeste ca in Roblox (40x60 la 2,5)."""
    c = person(outfit, who_key, row, f)
    return _img(c, round(S.FW * scale), round(S.FH * scale))


def _font(sz):
    return ImageFont.truetype(FONT, sz)


BG = (58, 84, 52, 255)
INK = (240, 234, 216, 255)
DIM = (196, 210, 180, 255)


def ground_band(w_world, h_world, ox=330, oy=452):
    """Pamantul barajului (prop_dam_ground, 1 px de arta = 3 de lume), cu drumul de pamant pe care umbla oamenii, la scara lumii."""
    g = Image.open(GROUND).convert("RGBA")
    cw, ch = math.ceil(w_world / 3), math.ceil(h_world / 3)
    crop = g.crop((ox, oy, ox + cw, oy + ch))
    base = Image.new("RGBA", crop.size, BG)
    base.alpha_composite(crop)
    return base.resize((cw * 3, ch * 3), Image.NEAREST).crop((0, 0, w_world, h_world))


def _text(d, xy, txt, fill=INK, size=8, anchor="la"):
    d.text(xy, txt, font=_font(size), fill=fill, anchor=anchor)


def section_x4(width):
    """(A) fiecare foaie la x4: in picioare + mers (cadrul 0), langa cea de imprumut de azi."""
    cols, cw, ch = 6, 290, 168
    rows = math.ceil(len(RECIPES) / cols)
    im = Image.new("RGBA", (width, 40 + rows * ch), (46, 64, 44, 255))
    d = ImageDraw.Draw(im)
    _text(d, (14, 12), "A  EACH SHEET AT X4: NEW (LEFT), BORROWED TODAY (RIGHT). STANDING + WALKING", INK, 8)
    for i, (key, meta) in enumerate(RECIPES.items()):
        x0, y0 = 14 + (i % cols) * cw, 40 + (i // cols) * ch
        _text(d, (x0, y0), meta["name"].upper() + (" *" if meta["veteran"] else ""), INK, 8)
        _text(d, (x0, y0 + 12), meta["job"][:34], DIM, 8)
        for j, (outfit, tag) in enumerate(((key, "NEW"), (meta["replaces"], "WAS " + meta["replaces"].upper()))):
            for k, (row, f) in enumerate((("idle_down", 0), ("walk_side", 0))):
                px = x0 + j * 140 + k * 66
                d.rectangle((px - 2, y0 + 26, px + 65, y0 + 26 + 97), fill=BG)
                im.alpha_composite(person_img(outfit, key, row, f, 4), (px, y0 + 27))
            _text(d, (x0 + j * 140, y0 + 130), tag[:15], INK if j == 0 else DIM, 8)
    return im


def _line(img_w, who_rows, label_rows, scale=2.5, zoom=2, spacing=56):
    """O linie de oameni pe pamantul barajului, la scara jocului (x2,5) afisata x2: who_rows = [(outfit, who_key, row, f)]."""
    n = len(who_rows)
    w_world = spacing * n + 40
    h_world = 150
    ground = ground_band(w_world, h_world)
    for i, (outfit, who, row, f) in enumerate(who_rows):
        p = person_img(outfit, who, row, f, scale)
        ground.alpha_composite(p, (20 + i * spacing + (spacing - p.width) // 2, 112 - p.height))
    big = ground.resize((w_world * zoom, h_world * zoom), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i, lab in enumerate(label_rows):
        _text(d, ((20 + i * spacing + spacing // 2) * zoom, 126 * zoom), lab, INK, 8, "ma")
    return big


def section_line():
    """(B) toti 15 in linie, in picioare si mergand, pe pamantul barajului, la x2,5."""
    keys = list(RECIPES)
    names = [RECIPES[k]["name"][:12] for k in keys]
    stand = _line(0, [(k, k, "idle_down", 0) for k in keys], names)
    walk = _line(0, [(k, k, "walk_side", 1) for k in keys], [""] * len(keys))
    im = Image.new("RGBA", (stand.width, 40 + stand.height + 14 + walk.height), (46, 64, 44, 255))
    d = ImageDraw.Draw(im)
    _text(d, (14, 12), "B  ALL 15 IN THE DAM TOWN, X2.5: STANDING (IDLE_DOWN) AND WALKING (WALK_SIDE)", INK, 8)
    im.alpha_composite(stand, (0, 40))
    im.alpha_composite(walk, (0, 40 + stand.height + 14))
    return im


def _pairs(keys, row, f, zoom=2, scale=2.5):
    spacing = 118
    w_world, h_world = spacing * 8 + 40, 162  # latime fixa (8 perechi), ca cele patru benzi sa se aseze la fel
    ground = ground_band(w_world, h_world)
    for i, key in enumerate(keys):
        meta = RECIPES[key]
        for j, outfit in enumerate((meta["replaces"], key)):
            p = person_img(outfit, key, row, f, scale)
            ground.alpha_composite(p, (24 + i * spacing + j * 46, 112 - p.height))
    big = ground.resize((w_world * zoom, h_world * zoom), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i, key in enumerate(keys):
        cx = (24 + i * spacing + 43) * zoom
        _text(d, (cx, 124 * zoom), RECIPES[key]["name"][:12], INK, 8, "ma")
        _text(d, (cx, 124 * zoom + 12), "was " + RECIPES[key]["replaces"][:9], DIM, 8, "ma")
    return big


def section_pairs():
    """(C) fiecare langa tinuta pe care o inlocuieste (aceeasi persoana, alta haina), in picioare si mergand, x2,5."""
    keys = list(RECIPES)
    bands = [_pairs(keys[:8], "idle_down", 0), _pairs(keys[8:], "idle_down", 0),
             _pairs(keys[:8], "walk_side", 1), _pairs(keys[8:], "walk_side", 1)]
    w = max(b.width for b in bands)
    h = 40 + sum(b.height + 10 for b in bands)
    im = Image.new("RGBA", (w, h), (46, 64, 44, 255))
    d = ImageDraw.Draw(im)
    _text(d, (14, 12), "C  EACH NEXT TO THE OUTFIT IT REPLACES (LEFT = WAS, RIGHT = NEW), X2.5, STANDING THEN WALKING", INK, 8)
    y = 40
    for b in bands:
        im.alpha_composite(b, (0, y))
        y += b.height + 10
    return im


def section_table(width):
    """(D) tabelul de culori: camasa / palarie / sort cu treptele lor si cel mai apropiat vecin de aceeasi silueta."""
    rows = distinction_rows()
    rh = 26
    im = Image.new("RGBA", (width, 64 + rh * len(rows)), (46, 64, 44, 255))
    d = ImageDraw.Draw(im)
    _text(d, (14, 12), "D  COLOUR TABLE: SHIRT / HAT / APRON (LIGHT, BASE, SHADE) AND NEAREST NEIGHBOURS (CIELAB DE)", INK, 8)
    heads = ((14, "OUTFIT"), (140, "KIND"), (236, "SHIRT"), (330, "HAT"), (424, "APRON"), (500, "NEAREST SHIRT, SAME KIND"),
             (790, "CLOSEST PAIR: SHIRT/HAT-APRON DE"), (1190, "NEAREST ERA 4"), (1440, "NEAREST ANY"),
             (1600, "NEAREST PLAYER-ONLY"))
    for x, t in heads:
        _text(d, (x, 40), t, DIM, 8)
    for i, r in enumerate(rows):
        key = r["key"]
        o = RECIPES[key]["recipe"]
        y = 60 + i * rh
        d.rectangle((8, y - 3, width - 8, y + rh - 5), fill=(52, 72, 50, 255) if i % 2 else (46, 64, 44, 255))
        _text(d, (14, y), RECIPES[key]["name"][:12], INK, 8)
        _text(d, (140, y), o["hat_kind"] + ("+coat" if o["coat"] else "") + ("+apron" if "apron" in o else ""), DIM, 8)
        for x, cols in ((236, (o["shirt_l"], o["shirt"], o["shirt_d"])), (330, (o["hat_l"], o["hat"], o["hat_d"])),
                        (424, o.get("apron", ()))):
            for k, c in enumerate(cols):
                d.rectangle((x + k * 24, y - 2, x + k * 24 + 21, y + 14), fill=tuple(c[:3]))
        _text(d, (500, y), f"{r['near_shirt'][0][:11]} {r['near_shirt'][1]:4.1f}", INK, 8)
        wn, wds, wd2 = r["worst"]
        _text(d, (790, y), f"{wn[:11]} {wds:4.1f}/{wd2:4.1f} x{r['margin']:.2f}", INK, 8)
        _text(d, (1190, y), f"{r['era4'][0][:11]} {r['era4'][1]:4.1f}" if r["era4"] else "-", INK, 8)
        _text(d, (1440, y), f"{r['any'][1][:11]} {r['any'][0]:4.1f}", INK, 8)
        _text(d, (1600, y), f"{r['player_any'][1][:10]} {r['player_any'][0]:4.1f}", INK, 8)
    return im


def build_preview(path):
    width = 1760
    parts = [section_x4(width), section_line(), section_pairs(), section_table(width)]
    w = max(width, *(p.width for p in parts))
    h = sum(p.height + 8 for p in parts)
    im = Image.new("RGBA", (w, h), (30, 42, 30, 255))
    y = 0
    for p in parts:
        im.alpha_composite(p, (0, y))
        y += p.height + 8
    im.convert("RGB").save(path)
    for name, p in zip(("x4", "line", "pairs", "table"), parts):
        p.convert("RGB").save(path.replace("_preview.png", f"_{name}.png"))
    return im.size


# ---------------------------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=SCRATCH)
    ap.add_argument("--emit", action="store_true", help="tipareste intrarile pentru settlers.OUTFITS si iese")
    a = ap.parse_args()
    register()
    if a.emit:
        emit()
        return
    os.makedirs(a.out, exist_ok=True)
    check_recipes()
    check_renderer_matches_assets()
    sheets = {}
    for name, fn in SPRITES.items():
        c = fn()
        assert (c.w, c.h) == SIZES[name], (name, c.w, c.h)
        sheets[name] = c
        png(os.path.join(a.out, name + ".png"), c.w, c.h, c.px)
        print("scris", name, c.w, c.h)
    check_sheets(sheets)
    check_layers()
    os.makedirs(SCRATCH, exist_ok=True)
    size = build_preview(os.path.join(SCRATCH, "outfits_preview.png"))  # nu ajunge niciodata in --out (poate fi assets/sprites)
    print("previzualizare:", os.path.join(SCRATCH, "outfits_preview.png"), size)
    check_distinct()  # ultima: cand pica, previzualizarea a fost deja scrisa si arata de ce


if __name__ == "__main__":
    main()
