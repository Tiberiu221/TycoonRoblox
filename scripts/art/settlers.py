#!/usr/bin/env python3
"""Foaie de animatie pentru colonisti: 20 randuri x 4 cadre, 16x24 per cadru (12 de baza + 3 de alergare
+ 5 cu roaba [D55]). Randurile noi stau la COADA: primele 15 raman bit cu bit cele urcate deja."""
import sys, os, colorsys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import C, png, hexc, T

FW, FH, COLS = 16, 24, 4
ROWS = [
    "walk_down", "walk_up", "walk_side",
    "idle_down", "idle_up", "idle_side",
    "work", "carry", "eat", "sleep", "cheer", "fish",
    "run_down", "run_up", "run_side",
    # [D55] oamenii care cara imping o roaba: mersul in trei directii, incarcatul si rasturnatul
    "push_side", "push_down", "push_up", "load", "tip",
]

# Piele si par: gri-neutru-cald (NU tonuri finale) - la rulare se inmultesc cu un tint
# global ca sa dea orice culoare de piele/par curat. Astea raman GLOBALE (nu tin de
# meserie): pielea si parul se recoloreaza la rulare, indiferent de tinuta aleasa.
SKIN   = hexc("d8d0c3"); SKIN_D = hexc("ada593")
HAIR   = hexc("958c7c"); HAIR_D = hexc("655d50")
EYE    = hexc("2a2119")
OUT    = hexc("241a12")
PANTS  = hexc("4c3d6e"); PANTS_D= hexc("362a50")
BOOT   = hexc("3b2a1a")
TOOL   = hexc("8a5a30"); METAL = hexc("a8aab4"); METAL_D = hexc("7b7d86")
FOOD   = hexc("e8b45a"); CRATE = hexc("a5713c"); CRATE_D = hexc("7d5329")
BLANKET= hexc("4a7a5c"); BLANKET_L = hexc("5f9673")
ROD    = hexc("c9a06a"); LINE = hexc("dfe7ef")

# --- tinuta per meserie: o culoare dominanta (camasa) + o silueta de acoperamant de cap,
# ambele distincte intre meserii - cerinta centrala a owner-ului (doi oameni cu aceeasi
# meserie dar build/par/piele diferite trebuie recunoscuti dintr-o privire).
# hat_kind: brim (bor lat plat, fisher), dome (caciula tricotata, crafter), hardhat
# (casca rotunjita + bor ingust uniform, builder), kerchief (basma innodata la ceafa,
# gardener), band (o singura fasie pe frunte, restul capului descoperit - innkeeper,
# ca sa existe o meserie unde coafura se vede intreaga), tricorn (bor lat + pana, doar
# jucatorul - keeper). coat=True intinde tinuta 3 randuri mai jos (pulpana lunga).
OUTFITS = {
    "fisher":    dict(shirt=hexc("3f7fbf"), shirt_l=hexc("5b9ad8"), shirt_d=hexc("2b5c8f"),
                       hat=hexc("dba54c"), hat_d=hexc("a97a2f"), hat_l=hexc("efc477"),
                       hat_kind="brim", coat=False),
    "crafter":   dict(shirt=hexc("8a4a2c"), shirt_l=hexc("a8623f"), shirt_d=hexc("623218"),
                       hat=hexc("5a4a3c"), hat_d=hexc("3d3025"), hat_l=hexc("786452"),
                       hat_kind="dome", coat=False),
    "builder":   dict(shirt=hexc("c97a2a"), shirt_l=hexc("e0973f"), shirt_d=hexc("955c1c"),
                       hat=hexc("e8c93a"), hat_d=hexc("b39c22"), hat_l=hexc("f5e376"),
                       hat_kind="hardhat", coat=False),
    "gardener":  dict(shirt=hexc("4a8f4f"), shirt_l=hexc("64ac6a"), shirt_d=hexc("336637"),
                       hat=hexc("7ba33f"), hat_d=hexc("587526"), hat_l=hexc("9cc25e"),
                       hat_kind="kerchief", coat=False),
    "innkeeper": dict(shirt=hexc("8a3a3a"), shirt_l=hexc("a85252"), shirt_d=hexc("642626"),
                       hat=hexc("c05050"), hat_d=hexc("903a3a"), hat_l=hexc("d87070"),
                       hat_kind="band", coat=False),
    "keeper":    dict(shirt=hexc("1f6b5c"), shirt_l=hexc("328a77"), shirt_d=hexc("134a3f"),
                       hat=hexc("2c4a70"), hat_d=hexc("1c3450"), hat_l=hexc("4a6d96"),
                       hat_kind="tricorn", coat=True),
    # [D50] clientii tavernei: FARA acoperamant de cap, in culori pe care nu le poarta nicio
    # meserie (prun si ardezie). Tinuta spune meseria [D44]: in hainele unui om al tau, un client
    # ar parea inca un Collector care sta degeaba.
    "townsfolk": dict(shirt=hexc("6a4c93"), shirt_l=hexc("8566ad"), shirt_d=hexc("4b3470"),
                       hat=hexc("6a4c93"), hat_d=hexc("4b3470"), hat_l=hexc("8566ad"),
                       hat_kind="none", coat=False),
    "traveler":  dict(shirt=hexc("5f6b7a"), shirt_l=hexc("7a8696"), shirt_d=hexc("434c58"),
                       hat=hexc("5f6b7a"), hat_d=hexc("434c58"), hat_l=hexc("7a8696"),
                       hat_kind="none", coat=False),
}
_CUR = dict(OUTFITS["fisher"])


def set_outfit(name):
    """Seteaza tinuta curenta (culori + silueta palariei) pentru desenele urmatoare."""
    _CUR.clear(); _CUR.update(OUTFITS[name])


# --- forma corpului: DOAR silueta (latimea/inaltimea fetei, mana), niciodata culoare -
# body_b se citeste ca alt gen prin fata mai ingusta si mai scunda cu 1px si o mana usor
# mai mica (un colt taiat), nu prin nuanta - SKIN ramane acelasi gri neutru ca la body_a.
BODY_SHAPES = {
    "a": dict(face_w=6, face_dx=0, face_h=5, hand_notch=False),
    "b": dict(face_w=5, face_dx=1, face_h=4, hand_notch=True),
}
_BODY = dict(BODY_SHAPES["a"])


def set_body(name):
    _BODY.clear(); _BODY.update(BODY_SHAPES[name])


# --- coafuri: conteaza doar ce iese PE LANGA palarie (tample/ceafa/umeri) - ce e sub ea
# nu se vede niciodata. "bald" nu deseneaza nimic, dar foaia tot se genereaza (64x360).
_HAIR = "short"


def set_hair(name):
    global _HAIR
    _HAIR = name


def L(layer, want):
    """True daca stratul cerut trebuie sa deseneze categoria `want` ("body"/"hair"/
    "outfit"). layer="all" deseneaza tot, exact ca inainte de separarea pe straturi."""
    return layer == "all" or layer == want


def punch(c, x0, y0, w, h):
    """Goleste un dreptunghi inapoi la transparent. O bucata de piele (mana, de-obicei)
    se deseneaza uneori peste o zona unde tinuta a desenat deja (maneca, poala camasii,
    patura) - in modul vechi "all" nu conta, pielea era desenata ultima si acoperea
    tinuta. Dar la separarea pe straturi, tinuta e mereu ULTIMUL strat suprapus, deci
    daca ramane acolo, ar acoperi pielea la loc. Golim exact acea zona chiar inainte
    sa desenam pielea, indiferent ce a desenat tinuta dedesubt - rezultatul in modul
    "all" nu se schimba (pielea redeseneaza peste), dar pe straturi separate gaura
    ramane goala si lasa pielea sa se vada prin ea la suprapunere."""
    for y in range(int(y0), int(y0 + h)):
        if 0 <= y < c.h:
            row = c.px[y]
            for x in range(int(x0), int(x0 + w)):
                if 0 <= x < c.w:
                    row[x] = T


def outline(c, x0, y0, w, h, col=OUT):
    """Contur intunecat in jurul siluetei; face personajul lizibil pe iarba."""
    src = [[c.px[y0 + y][x0 + x] for x in range(w)] for y in range(h)]
    for y in range(h):
        for x in range(w):
            if src[y][x][3] != 0:
                continue
            near = False
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[ny][nx][3] != 0:
                    near = True
                    break
            if near:
                c.px[y0 + y][x0 + x] = col


def draw_hat(c, ox, y, facing, layer):
    """Acoperamantul de cap curent (_CUR["hat_kind"]) - singurul lucru desenat pe stratul
    "outfit" in head(). Toate siluetele stau in y+0..y+4 (niciodata sub 0) ca sa nu
    "sara" in randul anterior din foaie la bob negativ (vezi nota de la RUN_SIDE)."""
    if not L(layer, "outfit"):
        return
    k = _CUR["hat_kind"]
    if k == "none":
        return
    hat, hat_d, hat_l = _CUR["hat"], _CUR["hat_d"], _CUR["hat_l"]
    if k == "band":                                    # doar o fasie pe frunte (innkeeper)
        # un singur rand, la y+4 - fata (stratul "body") incepe la y+5 (fy), niciodata mai
        # jos: la separarea pe straturi tinuta se suprapune mereu ultima (vezi punch()),
        # deci orice s-ar intinde pana la y+5 ar acoperi fata in loc sa piarda in fata ei
        x0 = ox + 3 if facing == "side" else ox + 4
        w = 9 if facing == "side" else 8
        c.rect(x0, y + 4, w, 1, hat)
    elif k == "dome":                                   # caciula tricotata, fara bor (crafter)
        w = 7 if facing == "side" else 8
        c.rect(ox + 4, y, w, 5, hat); c.rect(ox + 4, y + 4, w, 1, hat_d)
        c.rect(ox + 5, y, 3, 1, hat_l)
    elif k == "hardhat":                                # casca rotunjita + bor ingust uniform
        c.rect(ox + 4, y + 1, 8, 3, hat); c.rect(ox + 3, y + 4, 10, 1, hat_d)
        c.rect(ox + 6, y + 1, 4, 1, hat_l); c.rect(ox + 7, y, 2, 1, hat_l)
    elif k == "kerchief":                                # basma innodata la ceafa (gardener)
        if facing == "side":
            c.rect(ox + 4, y + 1, 7, 4, hat); c.rect(ox + 3, y + 3, 2, 3, hat_d)
            c.rect(ox + 5, y + 1, 4, 1, hat_l)
        else:
            c.rect(ox + 4, y + 1, 8, 4, hat); c.rect(ox + 5, y + 1, 4, 1, hat_l)
            c.rect(ox + 4, y + 4, 8, 1, hat_d)
    elif k == "tricorn":                                 # bor lat + pana - doar jucatorul
        if facing == "side":
            c.rect(ox + 2, y + 1, 12, 3, hat); c.rect(ox + 5, y, 6, 2, hat)
            c.rect(ox + 2, y + 4, 12, 1, hat_d); c.rect(ox + 2, y + 1, 3, 1, hat_l)
            c.put(ox + 14, y, hat_l); c.put(ox + 15, y + 1, hat_l)
        else:
            c.rect(ox + 1, y + 1, 14, 3, hat); c.rect(ox + 5, y, 6, 2, hat)
            c.rect(ox + 1, y + 4, 14, 1, hat_d); c.rect(ox + 5, y, 5, 1, hat_l)
    else:                                                 # "brim" - bor lat plat (fisher)
        if facing == "side":
            c.rect(ox + 4, y + 2, 9, 3, hat); c.rect(ox + 5, y, 6, 2, hat)
            c.rect(ox + 4, y + 4, 9, 1, hat_d); c.rect(ox + 5, y, 5, 1, hat_l)
        else:
            c.rect(ox + 3, y + 2, 10, 3, hat); c.rect(ox + 5, y, 6, 2, hat)
            c.rect(ox + 3, y + 4, 10, 1, hat_d); c.rect(ox + 5, y, 5, 1, hat_l)


def draw_hair(c, ox, y, facing, layer):
    """Coafura curenta (_HAIR) - doar ce iese PE LANGA palarie (tample/ceafa/umeri); ce e
    sub ea nu se deseneaza, palaria oricum il acopera. "bald" nu deseneaza nimic."""
    if not L(layer, "hair") or _HAIR == "bald":
        return
    open_top = _CUR["hat_kind"] in ("none", "band")     # nimic nu acopera crestetul
    fw, fdx = _BODY["face_w"], _BODY["face_dx"]
    fx = ox + 5 + fdx
    if facing == "up":                                  # din spate: tot capul e par
        c.rect(ox + 5, y + 5, 6, 5, HAIR)
        c.rect(ox + 5, y + 5, 6, 1, HAIR_D); c.rect(ox + 5, y + 9, 6, 1, HAIR_D)
        if _HAIR == "long":
            c.rect(ox + 4, y + 8, 8, 2, HAIR); c.rect(ox + 4, y + 9, 8, 1, HAIR_D)  # pe umeri
        elif _HAIR == "bun":
            c.rect(ox + 7, y + 5, 3, 3, HAIR_D); c.rect(ox + 7, y + 5, 2, 2, HAIR)  # coc
        return
    if facing == "side":
        if open_top:
            c.rect(ox + 5, y + 3, 6, 1, HAIR)   # se opreste ÎNAINTE de banda (y+4), nu se suprapun
        c.rect(fx, y + 5, fw, 1, HAIR)                  # breton
        c.rect(ox + 4, y + 6, 1, 3, HAIR_D)             # ceafa scurta (baza)
        if _HAIR == "long":
            c.rect(ox + 3, y + 6, 2, 4, HAIR_D)         # ceafa lunga, spre umar
        elif _HAIR == "bun":
            c.rect(ox + 2, y + 6, 2, 2, HAIR_D); c.put(ox + 3, y + 7, HAIR)  # coc rotund
        return
    # down (fata)
    if open_top:
        c.rect(ox + 5, y + 3, 6, 1, HAIR)       # se opreste ÎNAINTE de banda (y+4)
    c.rect(fx, y + 5, fw, 1, HAIR)                      # breton
    if _HAIR == "long":
        # 1px, lipite de obraz - mai late ar intra peste manecile ridicate din cheer()
        # (coloanele 2-3 si 12-13), unde parul ar trebui sa castige (se deseneaza ultimul
        # in "all"), dar in straturi separate tinuta e mereu suprapusa ultima (vezi punch())
        c.rect(fx - 1, y + 6, 1, 4, HAIR_D); c.rect(fx + fw, y + 6, 1, 4, HAIR_D)  # tample


def head(c, ox, y, facing, eyes="open", layer="all"):
    fw, fh = _BODY["face_w"], _BODY["face_h"]
    fx, fy = ox + 5 + _BODY["face_dx"], y + 5
    if facing == "side":
        draw_hat(c, ox, y, facing, layer)
        if L(layer, "body"):
            c.rect(fx, fy, fw, fh, SKIN)
        draw_hair(c, ox, y, facing, layer)
        if L(layer, "body"):
            c.rect(fx + fw, fy + 2, 1, 2, SKIN)          # nas
            if eyes == "open":
                c.put(fx + fw - 2, fy + 2, EYE)
            else:
                c.rect(fx + fw - 2, fy + 2, 2, 1, EYE)
            c.rect(fx, fy + fh - 1, fw, 1, SKIN_D)
    elif facing == "up":
        draw_hat(c, ox, y, facing, layer)
        if L(layer, "body"):
            c.rect(ox + 5, y + 5, 6, 5, SKIN)            # creștet - par (sau chelie) deasupra
        draw_hair(c, ox, y, facing, layer)
    else:
        draw_hat(c, ox, y, facing, layer)
        if L(layer, "body"):
            c.rect(fx, fy, fw, fh, SKIN)
        draw_hair(c, ox, y, facing, layer)
        if L(layer, "body"):
            c.rect(fx + fw - 1, fy + 1, 1, fh - 1, SKIN_D)
            if eyes == "open":
                c.put(fx + 1, fy + 2, EYE); c.put(fx + fw - 2, fy + 2, EYE)
            else:
                c.rect(fx + 1, fy + 2, 2, 1, EYE); c.rect(fx + fw - 2, fy + 2, 2, 1, EYE)


def torso(c, ox, y, facing, layer="all"):
    if not L(layer, "outfit"):
        return
    shirt, shirt_l, shirt_d = _CUR["shirt"], _CUR["shirt_l"], _CUR["shirt_d"]
    if facing == "side":
        c.rect(ox + 5, y, 7, 6, shirt)
        c.rect(ox + 5, y, 2, 6, shirt_l); c.rect(ox + 10, y, 2, 6, shirt_d)
    else:
        c.rect(ox + 4, y, 8, 6, shirt)
        c.rect(ox + 4, y, 2, 6, shirt_l); c.rect(ox + 10, y, 2, 6, shirt_d)
    c.rect(ox + 4 if facing != "side" else ox + 5, y + 5, 8 if facing != "side" else 7, 1, shirt_d)
    if _CUR["coat"]:                                    # pulpana lunga - doar keeper (D31 keeper)
        w, x0 = (7, ox + 5) if facing == "side" else (8, ox + 4)
        c.rect(x0, y + 6, w, 3, shirt_d)
        c.rect(x0, y + 8, w, 1, hexc("120c08", 140))    # tiv, usor umbrit


def arm(c, ox, x, y, length, hand=True, layer="all"):
    if L(layer, "outfit"):
        c.rect(ox + x, y, 2, length, _CUR["shirt"])
    if hand:
        punch(c, ox + x, y + length, 2, 2)   # mana poate cadea peste torso/picior desenate deja
        if L(layer, "body"):
            c.rect(ox + x, y + length, 2, 2, SKIN)
            if _BODY["hand_notch"]:
                punch(c, ox + x, y + length, 1, 1)   # un colt taiat - mana usor mai mica (body_b)


def leg(c, ox, x, top, length, boot=True, layer="all"):
    if not L(layer, "outfit"):
        return
    c.rect(ox + x, top, 2, length, PANTS)
    c.rect(ox + x, top + length - 1, 2, 1, PANTS_D)
    if boot:
        c.rect(ox + x, top + length, 2, 2, BOOT)


# (leg_left_x, leg_left_len, leg_right_x, leg_right_len, arm_back_x, arm_back_len,
#  arm_front_x, arm_front_len, bob)
WALK_SIDE = [
    (4, 5, 9, 5, 4, 4, 10, 4, 0),   # contact: picioare departate
    (6, 6, 8, 6, 5, 5, 9, 5, -1),   # trecere: corp ridicat
    (9, 5, 4, 5, 10, 4, 4, 4, 0),   # contact opus
    (6, 6, 8, 6, 5, 5, 9, 5, -1),
]
WALK_FRONT = [
    (5, 6, 9, 4, 3, 5, 11, 3, 0),
    (5, 5, 9, 5, 3, 4, 11, 4, -1),
    (5, 4, 9, 6, 3, 3, 11, 5, 0),
    (5, 5, 9, 5, 3, 4, 11, 4, -1),
]


def walk(c, ox, oy, facing, f, layer="all"):
    poses = WALK_SIDE if facing == "side" else WALK_FRONT
    lx, ll, rx, rl, abx, abl, afx, afl, bob = poses[f]
    hipY = oy + 15 + bob
    leg(c, ox, lx, hipY, ll, layer=layer)
    leg(c, ox, rx, hipY, rl, layer=layer)
    torso(c, ox, oy + 10 + bob, facing, layer=layer)
    arm(c, ox, abx, oy + 11 + bob, abl, layer=layer)
    arm(c, ox, afx, oy + 11 + bob, afl, layer=layer)
    head(c, ox, oy + bob, facing, layer=layer)


# Aceleasi 9 campuri ca WALK_*, dar impinse mai departe: pas mai lat (side) sau lungime
# inversata mai accentuat (front), bob 0/+3 (amplitudine 3 fata de 0/-1 = 1 la mers). Pe
# cadrele de zbor (1, 3) ambele picioare scad la lungime 2 - nu ating linia solului (rand 23)
# pe care o ating cadrele de contact; la mers, in schimb, piciorul cel mai lung ajunge mereu
# acolo, deci "mersul rapid" nu are niciodata ambele picioare vizibil ridicate deodata.
#
# bob NU coboara niciodata sub 0 (spre deosebire de WALK_*, care foloseste -1 la trecere).
# Motiv: capul se deseneaza la oy+bob: cu bob negativ, primul rand al palariei cade DEASUPRA
# propriei celule si ateriza pe ultimul rand al celulei DINAINTE in foaie (aceeasi mecanica
# exista deja, nevazuta, intre walk_down/walk_up, pentru ca acolo randul de dedesubt e mereu
# gol la acel pixel). Cu 3 randuri noi inlantuite (run_down->run_up->run_side), un asemenea
# "sarit peste margine" ar picta o pata straina de culoarea palariei peste personajul de
# dinaintea lui in foaie - verificat vizual, chiar asa se intampla cu bob negativ aici. Cu
# bob>=0 capul nu paraseste niciodata propria celula, deci problema nu mai poate aparea.
RUN_SIDE = [
    (2, 4, 12, 4,   2, 3, 12, 2,  3),   # contact: pas lat, corp jos (talpa pe randul 23)
    (6, 2,  9, 2,   6, 2,  9, 2,  0),   # zbor: ambele picioare stranse sub corp, in aer
    (12, 4,  2, 4,  12, 2,  2, 3,  3),  # contact opus (oglindit)
    (6, 2,  9, 2,   9, 2,  6, 2,  0),   # zbor (brate schimbate fata de cadrul 1)
]
RUN_FRONT = [
    (4, 4, 10, 2,   1, 4, 13, 2,  3),   # contact: stanga plantat lung, dreapta ridicat scurt
    (4, 2, 10, 2,   1, 2, 13, 3,  0),   # zbor: ambele picioare scurte, in aer
    (4, 2, 10, 4,   1, 2, 13, 4,  3),   # contact opus: lungimile inversate
    (4, 2, 10, 2,   1, 3, 13, 2,  0),   # zbor
]


def run(c, ox, oy, facing, f, layer="all"):
    """Ca walk(), dar pas mai lat si corp mai jos la contact (0, 2); pe cadrul de zbor (1, 3)
    ambele picioare urca scurte sub corp - niciunul nu atinge linia solului folosita la
    contact, deci se citeste "in aer" si nu doar "mers rapid". Bratele se prind cu 1px mai
    sus decat la mers si sunt mai scurte (indoite din cot). Pe vedere laterala, trunchiul,
    bratele si capul se muta impreuna 2px inainte fata de solduri - aplecarea de alergare;
    pe fata/spate ramane centrat, iar diferenta trece doar prin brate si pas (mai subtil)."""
    poses = RUN_SIDE if facing == "side" else RUN_FRONT
    lx, ll, rx, rl, abx, abl, afx, afl, bob = poses[f]
    lean = 2 if facing == "side" else 0
    hipY = oy + 15 + bob
    leg(c, ox, lx, hipY, ll, layer=layer)
    leg(c, ox, rx, hipY, rl, layer=layer)
    torso(c, ox + lean, oy + 10 + bob, facing, layer=layer)
    arm(c, ox + lean, abx, oy + 10 + bob, abl, layer=layer)
    arm(c, ox + lean, afx, oy + 10 + bob, afl, layer=layer)
    head(c, ox + lean, oy + bob, facing, layer=layer)


def idle(c, ox, oy, facing, f, layer="all"):
    bob = [0, 0, -1, 0][f]
    hipY = oy + 15 + bob
    leg(c, ox, 5, hipY, 6, layer=layer); leg(c, ox, 9, hipY, 6, layer=layer)
    torso(c, ox, oy + 10 + bob, facing, layer=layer)
    arm(c, ox, 3, oy + 11 + bob, 5, layer=layer); arm(c, ox, 11, oy + 11 + bob, 5, layer=layer)
    head(c, ox, oy + bob, facing, "open" if f != 3 else "shut", layer=layer)


def work(c, ox, oy, f, layer="all"):
    """Ciocan: ridicat, ridicat mai sus, lovitura, revenire."""
    lean = [0, 0, 1, 0][f]
    hipY = oy + 15
    leg(c, ox, 4, hipY, 6, layer=layer); leg(c, ox, 9, hipY, 6, layer=layer)
    torso(c, ox, oy + 10 + lean, "side", layer=layer)
    arm(c, ox, 4, oy + 11 + lean, 4, layer=layer)
    head(c, ox, oy + lean, "side", layer=layer)
    if f in (0, 1):
        hy = oy + 4 - f * 2
        if L(layer, "outfit"):
            c.rect(ox + 11, oy + 8 + lean, 2, 4, _CUR["shirt"])
        if L(layer, "body"):
            c.rect(ox + 11, oy + 6, 2, 2, SKIN)
        if L(layer, "outfit"):
            c.rect(ox + 12, hy + 2, 2, 6, TOOL)
            c.rect(ox + 10, hy, 6, 3, METAL); c.rect(ox + 10, hy + 2, 6, 1, METAL_D)
    else:
        # maneca se opreste inainte de coloana miinii (ox+12, de la oy+14 in jos) - altfel
        # s-ar suprapune cu pielea la separarea pe straturi (pe foaia veche mana o acoperea
        # oricum, fiind desenata ultima, deci taietura asta nu schimba nimic vizual)
        sy = oy + 12 + lean
        if L(layer, "outfit"):
            c.rect(ox + 11, sy, 2, 2 - lean, _CUR["shirt"])
            c.rect(ox + 11, oy + 14, 1, lean + 1, _CUR["shirt"])
        if L(layer, "body"):
            c.rect(ox + 12, oy + 14, 2, 2, SKIN)
        if L(layer, "outfit"):
            c.rect(ox + 13, oy + 13, 2, 5, TOOL)
            c.rect(ox + 12, oy + 17, 4, 3, METAL); c.rect(ox + 12, oy + 19, 4, 1, METAL_D)
            if f == 2:
                for k, (dx, dy) in enumerate(((-1, -2), (1, -3), (3, -1))):
                    c.put(ox + 12 + dx, oy + 16 + dy, hexc("ffe9a0"))


def carry(c, ox, oy, f, layer="all"):
    """Merge purtand o lada in fata."""
    bob = [0, -1, 0, -1][f]
    lx, ll, rx, rl = WALK_SIDE[f][0:4]
    hipY = oy + 15 + bob
    leg(c, ox, lx, hipY, ll, layer=layer); leg(c, ox, rx, hipY, rl, layer=layer)
    torso(c, ox, oy + 10 + bob, "side", layer=layer)
    head(c, ox, oy + bob, "side", layer=layer)
    cy = oy + 10 + bob
    if L(layer, "outfit"):
        # laza ocoleste coltul din stanga-jos, unde iese mana (pielea) peste ea
        c.rect(ox + 9, cy - 1, 7, 2, CRATE)
        c.rect(ox + 10, cy + 1, 6, 2, CRATE)
        c.rect(ox + 9, cy + 3, 7, 3, CRATE)
        c.rect(ox + 9, cy - 1, 7, 1, hexc("c08a4d")); c.rect(ox + 9, cy + 5, 7, 1, CRATE_D)
        c.rect(ox + 12, cy - 1, 1, 7, CRATE_D)
    punch(c, ox + 7, cy + 1, 3, 2)   # mana cade peste piept (torso e desenat deja)
    if L(layer, "body"):
        c.rect(ox + 7, cy + 1, 3, 2, SKIN)


def eat(c, ox, oy, f, layer="all"):
    """Ridica strachina la gura, cu doua maini."""
    hipY = oy + 15
    leg(c, ox, 5, hipY, 6, layer=layer); leg(c, ox, 9, hipY, 6, layer=layer)
    torso(c, ox, oy + 10, "down", layer=layer)
    head(c, ox, oy, "down", "open" if f in (0, 3) else "shut", layer=layer)
    by = [oy + 14, oy + 12, oy + 10, oy + 13][f]
    if L(layer, "outfit"):
        c.rect(ox + 5, by, 6, 3, hexc("a5713c"))
        c.rect(ox + 5, by, 6, 1, FOOD)
        c.rect(ox + 5, by + 2, 6, 1, CRATE_D)
        # maneca se opreste unde incepe mana (pielea o acoperea oricum mai jos)
        c.rect(ox + 3, by - 1, 2, 2, _CUR["shirt"])
        c.rect(ox + 11, by - 1, 2, 2, _CUR["shirt"])
    punch(c, ox + 3, by + 1, 2, 2); punch(c, ox + 11, by + 1, 2, 2)   # mainile cad peste piept
    if L(layer, "body"):
        c.rect(ox + 3, by + 1, 2, 2, SKIN)
        c.rect(ox + 11, by + 1, 2, 2, SKIN)
        if f == 2:
            c.put(ox + 7, oy + 9, hexc("b8735a"))
    if f == 3 and L(layer, "outfit"):
        c.put(ox + 12, by - 3, FOOD); c.put(ox + 13, by - 5, hexc("ffe9a0", 180))

def sleep(c, ox, oy, f, layer="all"):
    """Culcat pe o rogojina, cu capul spre dreapta si patura care respira."""
    base = oy + 21
    if L(layer, "outfit"):
        # centrata la "base" (nu base+1): la base+1 elipsa (ry=2) ajungea pana la oy+24,
        # adica peste marginea celulei, in randul URMATOR din foaie (vezi nota despre
        # scurgeri intre celule la RUN_SIDE) - inofensiv la "all", dar la separarea pe
        # straturi tinuta (aici, umbra) se suprapune mereu ultima, deci ar fi intunecat
        # orice desena parul chiar acolo, la o poza cu bob suficient de negativ (cheer f=2)
        c.ellipse(ox + 8, base, 7, 2, (0, 0, 0, 70))
        c.rect(ox + 1, base - 4, 14, 5, hexc("cbb289"))        # rogojina de paie
        c.rect(ox + 1, base - 4, 14, 1, hexc("e0c9a2"))
        c.rect(ox + 1, base, 14, 1, hexc("a08a66"))
    lift = [0, -1, -1, 0][f]
    if L(layer, "outfit"):
        c.rect(ox + 1, base - 7 + lift, 9, 6 - lift, BLANKET)  # patura peste corp
        c.rect(ox + 1, base - 7 + lift, 9, 1, BLANKET_L)
        c.rect(ox + 5, base - 6 + lift, 1, 5, hexc("3d6a4d"))
    punch(c, ox + 9, base - 9, 5, 5)   # capul cade peste marginea paturii
    if L(layer, "body"):
        c.rect(ox + 9, base - 9, 5, 5, SKIN)                   # capul
    if L(layer, "hair") and _HAIR != "bald":
        c.rect(ox + 9, base - 9, 5, 1, HAIR)
    if L(layer, "body"):
        c.rect(ox + 10, base - 7, 2, 1, EYE)
        c.rect(ox + 13, base - 7, 1, 2, SKIN_D)
    if L(layer, "outfit") and _CUR["hat_kind"] not in ("none", "band"):
        c.rect(ox + 8, base - 11, 7, 2, _CUR["hat"])           # palaria trasa peste ochi
        c.rect(ox + 8, base - 10, 7, 1, _CUR["hat_d"])
    if L(layer, "outfit"):
        for k in range(3):                                     # litere Z care urca
            zy = base - 14 - k * 4 - f
            zx = ox + 1 + k * 3
            col = hexc("eef4fb", 220 - k * 60)
            if zy >= oy:
                c.rect(zx, zy, 3, 1, col)
                c.put(zx + 1, zy + 1, col)
                c.rect(zx, zy + 2, 3, 1, col)

def cheer(c, ox, oy, f, layer="all"):
    """Sare cu bratele in sus; pentru sarbatoare la terminarea unei cladiri."""
    hop = [0, -2, -3, -1][f]
    hipY = oy + 15 + hop
    ll = 6 if f == 0 else 4
    leg(c, ox, 5, hipY, ll, layer=layer); leg(c, ox, 9, hipY, ll, layer=layer)
    torso(c, ox, oy + 10 + hop, "down", layer=layer)
    up = 0 if f == 0 else 4
    if L(layer, "outfit"):
        c.rect(ox + 2, oy + 11 + hop - up, 2, 5, _CUR["shirt"])
    if L(layer, "body"):
        c.rect(ox + 2, oy + 9 + hop - up, 2, 2, SKIN)
    if L(layer, "outfit"):
        c.rect(ox + 12, oy + 11 + hop - up, 2, 5, _CUR["shirt"])
    if L(layer, "body"):
        c.rect(ox + 12, oy + 9 + hop - up, 2, 2, SKIN)
    head(c, ox, oy + hop, "down", "shut" if f in (1, 2) else "open", layer=layer)
    if f in (1, 2) and L(layer, "outfit"):
        for dx, dy in ((0, 1), (15, 2), (3, 0), (12, 0)):
            c.put(ox + dx, oy + dy, hexc("ffe9a0"))


def fish(c, ox, oy, f, layer="all"):
    """Undita tinuta in fata, cu firul si plutitorul care sar pe apa."""
    bob = [0, 0, -1, 0][f]
    hipY = oy + 15 + bob
    leg(c, ox, 4, hipY, 6, layer=layer); leg(c, ox, 9, hipY, 6, layer=layer)
    torso(c, ox, oy + 10 + bob, "side", layer=layer)
    arm(c, ox, 4, oy + 11 + bob, 4, layer=layer)
    head(c, ox, oy + bob, "side", layer=layer)
    hy = oy + 12 + bob
    # maneca se opreste cu un rand inainte de mana (acelasi rand era acoperit oricum)
    if L(layer, "outfit"):
        c.rect(ox + 10, oy + 10 + bob, 2, 2, _CUR["shirt"])
    punch(c, ox + 10, hy, 2, 2)   # mana cade peste torso (desenat deja)
    if L(layer, "body"):
        c.rect(ox + 10, hy, 2, 2, SKIN)
    if L(layer, "outfit"):
        tilt = [0, 0, 1, 0][f]
        for i in range(11):                                    # batul, aproape vertical
            c.put(ox + 11 + i // 5 + tilt, hy - i, ROD)
        tipx, tipy = ox + 13 + tilt, hy - 10
        drop = [7, 8, 7, 6][f]
        for i in range(1, drop):                               # firul
            c.put(tipx, tipy + i, hexc("cfd8e2", 150))
        by = tipy + drop
        c.rect(tipx - 1, by, 2, 2, hexc("d8564a"))             # plutitorul
        c.rect(tipx - 1, by, 2, 1, hexc("f2efe7"))
        if f == 3:                                             # stropi cand musca pestele
            c.put(tipx - 2, by - 1, hexc("cfe4f5")); c.put(tipx + 1, by - 2, hexc("cfe4f5"))



# --- [D55] ROABA ----------------------------------------------------------------------------
# Owner-ul: "npc-urile cara driftwood-ul intr-un sac, nu intr-o roaba... si cand le pune apare un ciocan".
# Roaba insasi e un sprite separat (scripts/art/d55.py), pus de cod in fata omului; aici sunt doar
# bratele si corpul care o impinge. MAINILE stau la inaltimea manerelor (randul oy+15) indiferent de
# cadru: roaba ruleaza lin, deci mainile nu salta cu pasul -- doar corpul coboara putin la fiecare calcat.
# BOB DOAR IN JOS (0 sau 1): un bob negativ ar scurge palaria in ultimul rand al celulei dinainte (vezi
# nota de la RUN_SIDE) si ar schimba randul run_side, care e deja urcat.

# (picior_stang_x, lungime, picior_drept_x, lungime, bob). Soldul e la oy+15+bob; cu lungimea 5-bob
# talpa (cizma, doua randuri) se termina pe randul 21, ca la mers.
PUSH_SIDE = [
    (4, 4, 9, 4, 1),   # calcat: picioare departate, corpul apasa in jos
    (6, 5, 8, 5, 0),   # trecere
    (9, 4, 4, 4, 1),   # calcat opus
    (6, 5, 8, 5, 0),
]
# din fata/spate pasul se vede prin talpi care coboara pe rand (22 / 20), exact ca la WALK_FRONT
PUSH_FRONT = [
    (5, 5, 9, 3, 1),
    (5, 4, 9, 4, 0),
    (5, 3, 9, 5, 1),
    (5, 4, 9, 4, 0),
]
# Talpile in picioare, pe loc (incarcat, rasturnat): randul 21, ca la mers.
STAND_LEGS = (4, 5, 9, 5)


def reach(c, ox, sx, sy, hx, hy, layer, hand=True):
    """Brat intins in diagonala, de la umar (ox+sx, sy) la mana (ox+hx, hy). Maneca se opreste inaintea
    mainii; pielea se deseneaza dupa punch(), ca pe straturi separate tinuta sa n-o acopere."""
    steps = max(abs(hx - sx), abs(hy - sy), 1)
    if L(layer, "outfit"):
        for i in range(steps):
            t = i / steps
            c.rect(ox + round(sx + (hx - sx) * t), round(sy + (hy - sy) * t), 2, 2, _CUR["shirt"])
    if hand:
        punch(c, ox + hx, hy, 2, 2)
        if L(layer, "body"):
            c.rect(ox + hx, hy, 2, 2, SKIN)
            if _BODY["hand_notch"]:
                punch(c, ox + hx, hy, 1, 1)


def push(c, ox, oy, facing, f, layer="all"):
    """Mersul cu roaba. Lateral (spre dreapta, oglindit la stanga in joc): aplecat inainte cu un pixel,
    ambele brate intinse spre manere. Din fata: mainile in fata soldurilor, roaba vine peste picioare.
    Din spate: umerii si bratele trase spre inainte, mainile ascunse de corp."""
    if facing == "side":
        lx, ll, rx, rl, bob = PUSH_SIDE[f]
        lean = 1
        leg(c, ox, lx, oy + 15 + bob, ll, layer=layer)
        leg(c, ox, rx, oy + 15 + bob, rl, layer=layer)
        reach(c, ox, 7 + lean, oy + 11 + bob, 12, oy + 14, layer, hand=False)  # bratul din spate, in umbra
        torso(c, ox + lean, oy + 10 + bob, "side", layer=layer)
        head(c, ox + lean, oy + bob, "side", layer=layer)
        reach(c, ox, 8 + lean, oy + 11 + bob, 13, oy + 15, layer)
        return
    lx, ll, rx, rl, bob = PUSH_FRONT[f]
    leg(c, ox, lx, oy + 15 + bob, ll, layer=layer)
    leg(c, ox, rx, oy + 15 + bob, rl, layer=layer)
    torso(c, ox, oy + 10 + bob, facing, layer=layer)
    if facing == "up":
        head(c, ox, oy + bob, "up", layer=layer)
        reach(c, ox, 3, oy + 11 + bob, 4, oy + 13 + bob, layer, hand=False)
        reach(c, ox, 11, oy + 11 + bob, 10, oy + 13 + bob, layer, hand=False)
        return
    head(c, ox, oy + bob, "down", layer=layer)
    reach(c, ox, 3, oy + 11 + bob, 4, oy + 15, layer)
    reach(c, ox, 11, oy + 11 + bob, 10, oy + 15, layer)


def load_pose(c, ox, oy, f, layer="all"):
    """Incarcatul, lateral: se apleaca, prinde de jos, ridica, pune in roaba (care sta in dreapta)."""
    bob = [1, 2, 1, 0][f]
    lean = [1, 2, 1, 1][f]
    hand = [(12, oy + 19), (12, oy + 20), (12, oy + 15), (13, oy + 14)][f]
    lx, ll, rx, rl = STAND_LEGS
    leg(c, ox, lx, oy + 15 + bob, ll - bob, layer=layer)
    leg(c, ox, rx, oy + 15 + bob, rl - bob, layer=layer)
    torso(c, ox + lean, oy + 10 + bob, "side", layer=layer)
    head(c, ox + lean, oy + bob, "side", layer=layer)
    reach(c, ox, 8 + lean, oy + 11 + bob, hand[0], hand[1], layer)


def tip_pose(c, ox, oy, f, layer="all"):
    """Rasturnatul, lateral: mainile pe manere, le ridica tot mai sus (roaba se inclina in cod), apoi
    le coboara. Corpul se lasa in fata cand ridica."""
    bob = [0, 0, 1, 0][f]
    lean = [1, 1, 2, 1][f]
    hy = [oy + 15, oy + 12, oy + 10, oy + 13][f]
    lx, ll, rx, rl = STAND_LEGS
    leg(c, ox, lx, oy + 15 + bob, ll - bob, layer=layer)
    leg(c, ox, rx, oy + 15 + bob, rl - bob, layer=layer)
    # bratul din spate tinteste putin SUB mana din fata: mai sus ar trece prin barbie, iar pe straturi
    # separate maneca ar acoperi fata (verify_layers)
    reach(c, ox, 7 + lean, oy + 11 + bob, 12, hy + 1, layer, hand=False)
    torso(c, ox + lean, oy + 10 + bob, "side", layer=layer)
    head(c, ox + lean, oy + bob, "side", layer=layer)
    reach(c, ox, 8 + lean, oy + 11 + bob, 13, hy, layer)


def _draw_cell(c, ox, oy, row, f, layer):
    """Deseneaza o singura celula (rand, cadru) - dispecerul comun folosit de build_sheet
    si de verify_layers, ca ambele sa deseneze in EXACT aceeasi ordine (vezi nota despre
    bob negativ care se scurge in randul anterior din foaie - conteaza cand se aplica
    conturul fata de cand se deseneaza randul urmator)."""
    if row.startswith("walk"):
        walk(c, ox, oy, row.split("_")[1], f, layer)
    elif row.startswith("idle"):
        idle(c, ox, oy, row.split("_")[1], f, layer)
    elif row == "work":
        work(c, ox, oy, f, layer)
    elif row == "carry":
        carry(c, ox, oy, f, layer)
    elif row == "eat":
        eat(c, ox, oy, f, layer)
    elif row == "sleep":
        sleep(c, ox, oy, f, layer)
    elif row == "cheer":
        cheer(c, ox, oy, f, layer)
    elif row == "fish":
        fish(c, ox, oy, f, layer)
    elif row.startswith("run"):
        run(c, ox, oy, row.split("_")[1], f, layer)
    elif row.startswith("push"):
        push(c, ox, oy, row.split("_")[1], f, layer)
    elif row == "load":
        load_pose(c, ox, oy, f, layer)
    elif row == "tip":
        tip_pose(c, ox, oy, f, layer)


def build_sheet(layer="all", body="a", outfit="fisher", hair="short"):
    """layer: "all" (foaia completa, cu contur - character_anim.png), sau "body"/"hair"/
    "outfit" pentru cate o foaie separata cu un singur strat (fara contur propriu - el se
    aplica o singura data, pe personajul intreg, dupa suprapunere). body/outfit/hair aleg
    varianta - se seteaza global (set_body/set_outfit/set_hair) inainte de desen, la fel
    pentru toate cele 15 randuri x 4 cadre, ca fiecare foaie sa fie intern consecventa."""
    set_body(body); set_outfit(outfit); set_hair(hair)
    c = C(FW * COLS, FH * len(ROWS))
    for r, row in enumerate(ROWS):
        for f in range(COLS):
            _draw_cell(c, f * FW, r * FH, row, f, layer)
    # conturul se aplica abia dupa ce TOATE celulele sunt desenate (nu una cate una, pe
    # masura ce inaintam) - un cadru cu bob negativ se scurge in ultimul rand de pixeli al
    # celulei DINAINTE din foaie (vezi nota de la RUN_SIDE); daca am contura fiecare celula
    # imediat, celula DINAINTE ar fi deja conturata cand scurgerea soseste, si ar ramane cu
    # o pata fara contur propriu - inconsecvent, si diferit fata de suprapunerea pe straturi
    # separate (verify_layers), care oricum vede scurgerea abia dupa ce tot s-a desenat.
    # Conturul se pune pe FIECARE strat, nu doar pe foaia intreaga. Fara asta, straturile
    # suprapuse in joc dau siluete fara margine inchisa -- pete de culoare pe iarba, exact ce
    # citeste ca "ieftin". Da: in compunere apar si contururi interioare (capul conturat pe sub
    # palarie, parul pe sub ea); asa se deseneaza personajele pe straturi si asa trebuie.
    for r in range(len(ROWS)):
        for f in range(COLS):
            outline(c, f * FW, r * FH, FW, FH)
    return c


def verify_layers(body="a", hair="short", outfit="fisher"):
    """Verificare PROGRAMATICA (nu din ochi), pe foaia intreaga (nu doar un cadru): cele
    3 foi pe straturi (fiecare deja auto-consecventa, inclusiv scurgerile intre celule -
    vezi nota de la RUN_SIDE) se suprapun corp -> par -> tinuta pe o panza noua, apoi i se
    aplica ACELASI contur intarziat (dupa toate celulele, ca in build_sheet) - trebuie sa
    dea exact foaia "all"."""
    all_s = build_sheet("all", body, outfit, hair)
    body_s = build_sheet("body", body, outfit, hair)
    hair_s = build_sheet("hair", body, outfit, hair)
    outfit_s = build_sheet("outfit", body, outfit, hair)
    combo = C(all_s.w, all_s.h)
    for part in (body_s, hair_s, outfit_s):
        for y in range(combo.h):
            for x in range(combo.w):
                p = part.px[y][x]
                if p[3]:
                    combo.put(x, y, p)
    for r in range(len(ROWS)):
        for f in range(COLS):
            outline(combo, f * FW, r * FH, FW, FH)
    # Se compara IGNORAND pixelii de contur. De cand fiecare strat isi primeste conturul propriu
    # (fara el, siluetele compuse in joc ar fi pete de culoare fara margine), compunerea are in
    # plus contururi INTERIOARE -- capul conturat pe sub palarie, parul pe sub ea. Alea sunt
    # corecte si dorite; ce trebuie sa ramana identic e continutul: aceeasi piele, acelasi par,
    # aceleasi haine, in aceleasi locuri.
    def is_out(px):
        return px[3] > 0 and (px[0] + px[1] + px[2]) < 140

    for y in range(combo.h):
        for x in range(combo.w):
            a, b = combo.px[y][x], all_s.px[y][x]
            if a == b:
                continue
            if is_out(a) or is_out(b):
                continue  # difera doar prin contur: acceptat
            return False
    return True


def build_layers_preview():
    """Un cadru (idle_down, f=0) aratat de 4 ori la scara mare: corp singur, par singur,
    tinuta singura, si toate trei suprapuse (corp -> par -> tinuta, apoi conturul) - proba
    vizuala ca cele trei straturi cad exact peste personajul din character_anim.png."""
    set_body("a"); set_outfit("fisher"); set_hair("short")   # combinatia de baza, ca la "all"

    def frame(pose_layer):
        f = C(FW, FH)
        idle(f, 0, 0, "down", 0, layer=pose_layer)
        return f

    body_f, hair_f, outfit_f = frame("body"), frame("hair"), frame("outfit")
    combo = C(FW, FH)
    for part in (body_f, hair_f, outfit_f):
        for y in range(FH):
            for x in range(FW):
                p = part.px[y][x]
                if p[3]:
                    combo.put(x, y, p)
    outline(combo, 0, 0, FW, FH)

    s, pad = 10, 10
    panel = FW * s
    prev = C(panel * 4 + pad * 5, FH * s + pad * 2)
    prev.rect(0, 0, prev.w, prev.h, hexc("4a6b3c"))
    for i, part in enumerate((body_f, hair_f, outfit_f, combo)):
        left = pad + i * (panel + pad)
        for y in range(FH):
            for x in range(FW):
                p = part.px[y][x]
                if p[3] == 0:
                    continue
                for dy in range(s):
                    for dx in range(s):
                        prev.put(left + x * s + dx, pad + y * s + dy, (p[0], p[1], p[2], 255))
    return prev


def _retint(px, hue, sat, val_mul):
    """Recoloreaza un pixel gri-neutru (piele/par) pastrandu-i luminanta relativa - asta
    simuleaza in Python tint-ul aplicat la rulare in Roblox, DOAR pentru previzualizare;
    foile exportate pe disc raman neutre (body_*.png, hair_*.png)."""
    if px[3] == 0:
        return px
    r, g, b, a = px
    lum = min(1.0, max(0.05, (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 * val_mul))
    rr, gg, bb = colorsys.hsv_to_rgb((hue % 360) / 360.0, sat, lum)
    return (int(rr * 255 + 0.5), int(gg * 255 + 0.5), int(bb * 255 + 0.5), a)


def _apply_tint(c, skin, hair):
    """skin/hair = (hue, sat, val_mul). Recunoaste pixelii SKIN/SKIN_D/HAIR/HAIR_D dupa
    culoarea lor exacta (neutra) si ii recoloreaza; restul (ochi etc.) raman neatinsi."""
    out = C(c.w, c.h)
    sh, ss, sv = skin
    hh, hs, hv = hair
    for y in range(c.h):
        for x in range(c.w):
            p = c.px[y][x]
            if p[:3] == SKIN[:3]:
                out.px[y][x] = _retint(p, sh, ss, sv)
            elif p[:3] == SKIN_D[:3]:
                out.px[y][x] = _retint(p, sh, ss, sv * 0.85)
            elif p[:3] == HAIR[:3]:
                out.px[y][x] = _retint(p, hh, hs, hv)
            elif p[:3] == HAIR_D[:3]:
                out.px[y][x] = _retint(p, hh, hs, hv * 0.85)
            else:
                out.px[y][x] = p
    return out


def compose_person(body, hair, outfit, skin_tone, hair_tone):
    """Compune un singur cadru (idle_down, f=0) din cele 3 straturi pentru o combinatie
    data, cu tint de piele/par aplicat DOAR in previzualizare (vezi _retint)."""
    def frame(pose_layer):
        set_body(body); set_outfit(outfit); set_hair(hair)
        f = C(FW, FH)
        idle(f, 0, 0, "down", 0, layer=pose_layer)
        return f

    body_f = _apply_tint(frame("body"), skin_tone, hair_tone)
    hair_f = _apply_tint(frame("hair"), skin_tone, hair_tone)
    outfit_f = frame("outfit")   # culorile tinutei sunt deja finale, nu se recoloreaza
    combo = C(FW, FH)
    for part in (body_f, hair_f, outfit_f):
        for y in range(FH):
            for x in range(FW):
                p = part.px[y][x]
                if p[3]:
                    combo.put(x, y, p)
    outline(combo, 0, 0, FW, FH)
    return combo


def build_people_preview():
    """Grila cu oameni COMPUSI (body+hair+outfit), pentru verificarea ceruta: aceeasi
    meserie trebuie recunoscuta indiferent de build/piele/par, iar coafurile trebuie sa
    se deosebeasca intre ele. Acopera ambele build-uri, toate cele 5 meserii + jucatorul,
    fiecare meserie de doua ori cu aspect diferit (build/par/piele), ca sa se poata judeca
    exact intrebarea de la punctul 4 din verificare."""
    SKIN_TONES = [(28, 0.32, 1.05), (26, 0.55, 0.85), (22, 0.62, 0.58)]   # deschis/mediu/inchis
    HAIR_TONES = [(25, 0.55, 1.0), (45, 0.60, 1.15), (5, 0.65, 0.55)]     # castaniu/blond/roscat-inchis
    roster = [
        ("a", "short", "fisher"),    ("b", "long",  "fisher"),
        ("a", "bun",   "crafter"),   ("b", "bald",  "crafter"),
        ("a", "long",  "builder"),   ("b", "short", "builder"),
        ("a", "bun",   "gardener"),  ("b", "bald",  "gardener"),
        ("a", "long",  "innkeeper"), ("b", "short", "innkeeper"),
        ("a", "bun",   "keeper"),
    ]
    cols = 4
    rows = (len(roster) + cols - 1) // cols
    s, pad = 9, 7
    cellw, cellh = FW * s + pad, FH * s + pad
    prev = C(cellw * cols + pad, cellh * rows + pad)
    prev.rect(0, 0, prev.w, prev.h, hexc("4a6b3c"))
    for i, (body, hair, outfit) in enumerate(roster):
        person = compose_person(body, hair, outfit, SKIN_TONES[i % 3], HAIR_TONES[(i * 2) % 3])
        left = pad + (i % cols) * cellw
        top = pad + (i // cols) * cellh
        for y in range(FH):
            for x in range(FW):
                p = person.px[y][x]
                if p[3] == 0:
                    continue
                for dy in range(s):
                    for dx in range(s):
                        prev.put(left + x * s + dx, top + y * s + dy, (p[0], p[1], p[2], 255))
    set_body("a"); set_outfit("fisher"); set_hair("short")   # reseteaza starea globala
    return prev


if __name__ == "__main__":
    sheet = build_sheet("all", "a", "fisher", "short")
    png("character_anim.png", sheet.w, sheet.h, sheet.px)

    for body in ("a", "b"):
        s_body = build_sheet("body", body=body)
        png(f"body_{body}.png", s_body.w, s_body.h, s_body.px)

    for hair in ("short", "long", "bun", "bald"):
        s_hair = build_sheet("hair", hair=hair)
        png(f"hair_{hair}.png", s_hair.w, s_hair.h, s_hair.px)

    for outfit in ("fisher", "crafter", "builder", "gardener", "innkeeper", "keeper", "townsfolk", "traveler"):
        s_outfit = build_sheet("outfit", outfit=outfit)
        png(f"outfit_{outfit}.png", s_outfit.w, s_outfit.h, s_outfit.px)

    ok = verify_layers("a", "short", "fisher")
    print("verificare straturi (body_a+hair_short+outfit_fisher == all):", "OK" if ok else "ESUAT")

    layers_prev = build_layers_preview()
    png("_preview_layers.png", layers_prev.w, layers_prev.h, layers_prev.px)

    people_prev = build_people_preview()
    png("_preview_people.png", people_prev.w, people_prev.h, people_prev.px)

    s = 7
    prev = C(sheet.w * s + 40, sheet.h * s + 40)
    prev.rect(0, 0, prev.w, prev.h, hexc("4a6b3c"))
    for yy in range(sheet.h):
        for xx in range(sheet.w):
            p = sheet.px[yy][xx]
            if p[3] == 0:
                continue
            for dy in range(s):
                for dx in range(s):
                    prev.put(20 + xx * s + dx, 20 + yy * s + dy, (p[0], p[1], p[2], 255))
    png("_zoom_char.png", prev.w, prev.h, prev.px)
    print(f"foaie {sheet.w}x{sheet.h}, {len(ROWS)} randuri x {COLS} cadre")
    print(" ".join(ROWS))
