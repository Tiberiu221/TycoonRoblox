#!/usr/bin/env python3
"""[D70, lotul A0] PLANSE FARA URCARE pentru barajul lumii 2 (docs/PLAN-MOTOR-UNIRE.md §16, PLAN-HARTA §7 pasul 1).
Scrie DOAR in scratchpad-ul sesiunii; nimic nu intra in assets/sprites si nimic nu se urca.

  a0_dam_wall.png -- zidul barajului la locul lui (lumea 2, x 640-880), cu fata din aval si spuma de la picior, ca sa nu
                     para pod. Doua variante: A, piatra (zidit din satul vechi, cum spune filmul); B, beton cu trei stavile.
                     Pamantul e cel copt la k12, cladirile sunt desenele de imprumut din joc.
  a0_dam_film.png -- sase cadre-cheie ale filmului (DamMath.FILM): clopotul, privirea peste sat (de la Wire Works la
                     Landing), oamenii la amurg, barajul care creste peste rau, cartonasul. Benzile, amurgul, textul, Skip si
                     camera vin din DamMath.frameAt (exportat cu Lune), deci cadrul arata ce face codul de azi. Satul e cel de la
                     sfarsitul Erei 3: pamantul copt, cladirile, casele, plasele, pontonul, barca balciului, stalpii cu sarma
                     (ModernConfig.wireSpans),
                     felinarele aprinse si tarusii topografilor. Ce e PROPUNERE A2 (siluetele, schelele, zidul pe jumatate,
                     camera care urca la rau, plasele scoase din apa) scrie pe cadru.

Rulare: python3 scripts/art/a0_dam.py [wall|film]      (fara argument, amandoua)
"""
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import preview_d55 as P  # noqa: E402
import village_ground as VG  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
SPR = os.path.join(ROOT, "assets", "sprites")
D = 3  # pixeli de lume pe pixel de arta (Assets.PIXEL_SCALE)
FONT = "/Applications/RobloxStudio.app/Contents/Resources/content/fonts/PressStart2P-Regular.ttf"

# ---- paleta zidului ---------------------------------------------------------------------------------------------------
STONE = ((206, 198, 182), (178, 170, 156), (150, 143, 132), (120, 114, 106), (90, 86, 80), (64, 62, 60))
CONCRETE = ((222, 218, 208), (198, 194, 184), (172, 168, 160), (142, 138, 132), (108, 106, 102), (74, 72, 70))
WATER_SHEET = ((236, 246, 250), (196, 226, 240), (150, 198, 224), (104, 160, 196))
WET = (70, 80, 86)
TIMBER = ((72, 52, 36), (112, 82, 54), (146, 110, 72), (176, 138, 92))

WALL_W, WALL_H = 80, 189  # cutia din TycoonConfig.WORLDS[2].wall (240 x 568 de lume)


def sprite(name):
    return Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")


def h01(x, y, salt=0):
    return VG.hash01(x, y, salt)


# ---- zidul ---------------------------------------------------------------------------------------------------------------
def dam_wall(variant, G, dry=False):
    """Zidul vazut de sus, cu lumina din stanga-sus: coama (pasarela, cu parapetul spre lac) la stanga, apoi fata din aval
    care coboara in trepte spre dreapta, pana la rau. Peste rau, deversorul: o panza de apa care curge pe trepte. Pe maluri
    zidul intra in pamant; capatul de sud (spre sat) se vede din fata. Rosu = A (piatra), B = beton cu stavile."""
    ramp = STONE if variant == "A" else CONCRETE
    img = Image.new("RGBA", (WALL_W, WALL_H), (0, 0, 0, 0))
    px = img.load()
    wall = G["dam"]["wall"]
    sp = G["dam"]["water"]["spillway"]
    far_row = lambda col: int((G["far"]["y"][int(wall["x"] / D) + col] - wall["y"]) / D)  # noqa: E731
    near_row = lambda col: int((G["near"]["y"][int(wall["x"] / D) + col] - wall["y"]) / D)  # noqa: E731
    sp_r0, sp_r1 = round((sp["y"] - wall["y"]) / D), round((sp["y"] + sp["h"] - wall["y"]) / D)
    crest = 16
    step = 8 if variant == "A" else 32  # A: trepte de piatra; B: o fata neteda, in doua panouri
    piers = (sp_r0 + (sp_r1 - sp_r0) // 3, sp_r0 + 2 * (sp_r1 - sp_r0) // 3) if variant == "B" else ()
    front = 7  # capatul de sud, vazut din fata
    for y in range(WALL_H):
        for x in range(WALL_W):
            in_river = far_row(x) <= y <= near_row(x)
            spill = sp_r0 <= y < sp_r1 and crest <= x and in_river and not dry  # pe santier, inca fara apa
            if y >= WALL_H - front:
                # fata de sud a capatului: blocuri mai inchise (umbra), cu rosturi
                k = y - (WALL_H - front)
                col = ramp[3] if k > 0 else ramp[1]
                if variant == "A" and (k % 3 == 0 or (x + (k // 3) * 4) % 8 == 0):
                    col = ramp[4]
                px[x, y] = col + (255,)
                continue
            if x < crest:
                # coama: parapetul spre lac (doi pixeli, cu muchia luminata), pasarela, balustrada spre aval
                if x == 0:
                    col = ramp[4]
                elif x in (1, 2):
                    col = ramp[0] if x == 1 else ramp[1]
                elif x == crest - 1:
                    col = TIMBER[1] if y % 6 == 0 else ramp[3]  # stalpii balustradei
                else:
                    if variant == "A":
                        col = ramp[1] if (y // 4 + x // 6) % 2 == 0 else ramp[2]
                        if y % 4 == 0 or (x + (y // 4) * 3) % 6 == 0:
                            col = ramp[3]  # rosturile pavajului
                    else:
                        col = ramp[1] if x < crest - 4 else ramp[2]
                    if variant == "B" and y % 24 == 0:
                        col = ramp[3]  # rosturile de dilatatie
                    if variant == "B" and piers and sp_r0 <= y < sp_r1 and (y - sp_r0) % ((sp_r1 - sp_r0) // 3) < 5:
                        col = (62, 58, 56)  # casa stavilei, pe coama
                px[x, y] = col + (255,)
                continue
            # fata din aval: in trepte (A) sau neteda (B), mai intunecata spre picior
            s = (x - crest) % step
            depth = (x - crest) / (WALL_W - crest)
            if variant == "A":
                col = ramp[0] if s == 0 else (ramp[4] if s == step - 1 else ramp[2 if depth < 0.5 else 3])
                if s not in (0, step - 1) and ((y + ((x - crest) // step) * 2) % 5 == 0):
                    col = ramp[3]  # rosturile blocurilor
            else:
                col = ramp[1] if depth < 0.4 else (ramp[2] if depth < 0.8 else ramp[3])
                if (x - crest) % 32 == 0:
                    col = ramp[3]
                if y % 24 == 0:
                    col = ramp[3]
            if piers and any(p <= y < p + 4 for p in piers):
                # pilele dintre stavile: piatra care iese din apa, cu muchia de sus luminata
                col = ramp[0] if y in piers else ramp[2]
                px[x, y] = col + (255,)
                continue
            if spill:
                # panza deversorului: curge spre dreapta; la fiecare treapta se albeste (apa rupta), apoi se limpezeste
                flow = (x - crest + y * 7) % 11
                tone = 2 if depth < 0.3 else 1
                if variant == "A" and s in (0, 1):
                    tone = 0
                if flow == 0 or h01(x, y, 3) > 0.93:
                    tone = 0
                if h01(x, y, 4) < 0.05:
                    tone = 3
                col = WATER_SHEET[tone]
            if x == WALL_W - 1:
                col = WET  # piciorul ud
            px[x, y] = col + (255,)
    # turbina zidita: o gura intunecata in fata zidului, in dreptul turbinei din joc (x 824-880, y 690-768)
    tb = G["dam"]["turbine"]
    tx0 = round((tb["x"] - tb["w"] / 2 - wall["x"]) / D)
    ty0 = round((tb["y"] - tb["h"] / 2 - wall["y"]) / D)
    for y in range(ty0 - 2, ty0 + round(tb["h"] / D)):
        for x in range(tx0 - 1, WALL_W):
            arch = (x - tx0 - 9) ** 2 / 100 + (y - ty0 - 12) ** 2 / 196
            if arch <= 1 and 0 <= y < WALL_H:
                # gura canalului turbinei: apa intunecata sub o bolta de piatra
                px[x, y] = (40, 62, 78, 255) if arch < 0.78 else STONE[3] + (255,)
    return img


def foam(G, variant):
    """Spuma de la piciorul deversorului: apa alba care fierbe, mai deasa langa zid, care se rupe spre aval."""
    sp = G["dam"]["water"]["spillway"]
    w, h = 26, round(sp["h"] / D)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    n = VG.Noise(77)
    for y in range(h):
        for x in range(w):
            t = x / w
            v = n.at(x * 3.0, y * 3.0, 9) - t * 0.75 + 0.18
            if v > 0.5:
                a = min(1.0, (v - 0.5) * 3.2)
                col = (244, 250, 252) if v > 0.66 else (200, 228, 240)
                px[x, y] = col + (round(220 * a),)
    return img


def wall_plate():
    G = VG.geometry(2)
    cv = VG.bake(G)
    rows = cv.rows()
    wall = G["dam"]["wall"]
    sp = G["dam"]["water"]["spillway"]
    tb = G["dam"]["turbine"]
    turbine = sprite("prop_turbine")
    # fereastra: lacul, zidul, puntea si piciorul lui, clopotnita si casele de sub el
    wx0, wx1, wy0, wy1 = 420, 1260, 330, 1110
    panels = []
    for variant in ("A", "B"):
        art, spray = dam_wall(variant, G), foam(G, variant)

        def paint(over, art=art, spray=spray):
            ax, ay = round(wall["x"] / D), round(wall["y"] / D)
            ap = art.load()
            for y in range(art.height):
                for x in range(art.width):
                    over(ax + x, ay + y, ap[x, y])
            fx, fy = round((wall["x"] + wall["w"]) / D) - 2, round(sp["y"] / D)
            fp = spray.load()
            for y in range(spray.height):
                for x in range(spray.width):
                    over(fx + x, fy + y, fp[x, y])
            k = min(tb["w"] / D / turbine.width, tb["h"] / D / turbine.height)
            tw, th = max(1, round(turbine.width * k)), max(1, round(turbine.height * k))
            small = turbine.resize((tw, th), Image.NEAREST).load()
            bx, by = round(tb["x"] / D - tw / 2), round((tb["y"] + tb["h"] / 2) / D - th)
            for y in range(th):
                for x in range(tw):
                    over(bx + x, by + y, small[x, y])

        full = VG.compose(G, rows, wall=paint)
        W, H = len(full[0]), len(full)
        img = Image.new("RGBA", (W, H))
        img.putdata([p for row in full for p in row])
        crop = img.crop((wx0 // D, wy0 // D, wx1 // D, wy1 // D)).resize(
            ((wx1 - wx0) // D * 3, (wy1 - wy0) // D * 3), Image.NEAREST
        )
        panels.append((variant, crop))
    gut, head = 24, 56
    pw, ph = panels[0][1].size
    out = Image.new("RGBA", (pw * 2 + gut * 3, ph + head + gut), (24, 28, 30, 255))
    font = ImageFont.truetype(FONT, 16)
    titles = {"A": "A  STONE, BUILT FROM THE OLD VILLAGE", "B": "B  CONCRETE, THREE SPILLWAY GATES"}
    dr = ImageDraw.Draw(out)
    for i, (variant, crop) in enumerate(panels):
        x = gut + i * (pw + gut)
        dr.text((x, 20), titles[variant], font=font, fill=(240, 233, 218))
        out.paste(crop, (x, head))
    path = os.path.join(P.SCRATCH, "a0_dam_wall.png")
    out.save(path)
    print("scris", path, out.size)


# ---- satul pentru film ---------------------------------------------------------------------------------------------------
def village_image():
    """Satul lumii 1, ca in joc la sfarsitul Erei 3: pamantul copt (feliile urcate), cladirile fixe si cele de pe
    platforme (aceleasi desene ca planse le Morii si Wire Works), copacii imprastiati."""
    import preview_mill_map as MM
    import preview_works_map as WM

    G = VG.geometry(1)
    W, H = G["world"]["w"] // D, G["world"]["h"] // D
    water = sprite("water_tile")
    img = Image.new("RGBA", (W, H))
    for y in range(0, H, water.height):
        for x in range(0, W, water.width):
            img.paste(water, (x, y))
    tile = G["tile"] // D
    for k, name in enumerate(("prop_village_ground", "prop_village_ground_2")):
        part = sprite(name)
        img.alpha_composite(part, (k * tile, 0))
    things = []  # (adancimea, sprite, x lume, baza lume, scara)
    sp = G["spots"]
    for key, name in (("tavern", "prop_tavern"), ("storage", "prop_storage"), ("sawmill", "prop_sawmill")):
        things.append((sp[key]["y"], name, sp[key]["x"], sp[key]["y"], 3))
    era1 = {
        "first_runner": ("prop_runner_hut_2", 3),
        "workshop": ("prop_workshop_e1", 3),
        "scrap_shed": ("prop_scrap_shed", 3),
        "landing_bell": ("prop_bell", 3),
        "dock_trader": ("prop_stall_2", 2),
    }
    pad_art = dict(era1)
    pad_art.update(MM.PAD_ART)
    pad_art.update(WM.PAD_ART)
    offsets = dict(MM.ART_OFFSET_Y)
    for pad in G["pads"]:
        art = pad_art.get(pad["id"])
        if art is None and pad["id"].startswith("hire_"):
            name = "prop_hut_" + pad["id"][5:] + "_2"
            art = (name, 3) if os.path.exists(os.path.join(SPR, name + ".png")) else None
        if art is not None:
            base = pad["y"] + 56 + offsets.get(pad["id"], 0)
            things.append((base, art[0], pad["x"], base, art[1]))
    for places, fixed in ((MM.mill_places(), MM.FIXED), (WM.mill_places(), WM.FIXED)):
        for key, name in fixed.items():
            box = places["fixed"][key]
            things.append((box["y"], name, box["x"], box["y"], 3))
    for item in G["scattered"]:
        name = {"tree_round": "prop_tree_round", "tree_pine": "prop_tree_pine", "bush": "prop_bush"}.get(item["kind"])
        if name:
            things.append((item["y"], name, item["x"], item["y"], 3))
    # [verificatorul A0] ce mai vede jucatorul la sfarsitul Erei 3 (din TycoonConfig, prin film_props): plasele si stalpii
    # lor, pontonul, barca balciului, stalpii cu sarma, felinarele aprinse, tarusii topografilor
    props = film_props()
    for net in props["nets"]:
        if net.get("hidden"):
            continue
        sprite_name = "prop_turbine" if net["turbine"] else "prop_net_water"
        things.append((net["laneY"], sprite_name, net["x"], net["laneY"] + 9 * 3, 3))
        things.append((net["y"], "prop_netpost", net["x"], net["y"] + 12, 3))
    pier = props["pier"]
    things.append((pier["y"], "prop_pier_long", pier["x"], pier["y"] + 104 * 3 / 2, 3))
    ferry = props["ferry"]
    things.append((ferry["y"], "prop_fair_ferry", ferry["x"], ferry["y"], 2))
    for pole in props["poles"]:
        # prins de baza cu stalpul (postX), nu cu mijlocul foii, si intors dupa `mirror` (ModernProps)
        kind = "end" if pole["kind"] == "end" else "line"
        name = "prop_wire_pole_end" if kind == "end" else "prop_wire_pole"
        tag = f"{name}@{props['postX'][kind]}{'m' if pole.get('mirror') else ''}"
        things.append((pole["y"], tag, pole["x"], pole["y"], 3))
    for lamp in props["lamps"]:
        things.append((lamp["y"], "prop_street_lamp_lit", lamp["x"], lamp["y"], 3))
    for stake in props["stakes"]:
        # foaia are trei cadre de 12 px (ModernConfig.SURVEY_STAKE), fiecare tarus cu cadrul lui
        things.append((stake["y"], f"prop_survey_stakes#{stake['frame']}", stake["x"], stake["y"], 2))
    for _d, name, x, base, scale in sorted(things, key=lambda t: t[0]):
        name, _, post = name.partition("@")
        name, _, cell = name.partition("#")
        s = sprite(name)
        if cell:
            s = s.crop((int(cell) * 12, 0, int(cell) * 12 + 12, s.height))
        k = scale / D
        if k != 1:
            s = s.resize((max(1, round(s.width * k)), max(1, round(s.height * k))), Image.NEAREST)
        left = round(x / D - s.width / 2)
        if post:
            mirror = post.endswith("m")
            px_ = int(post.rstrip("m"))
            if mirror:
                s = s.transpose(Image.FLIP_LEFT_RIGHT)
            left = round(x / D - ((s.width - px_) if mirror else px_))
        img.alpha_composite(s, (left, round(base / D - s.height)))
    # firele lasate dintre stalpi (ModernConfig.wireSpans), peste tot ce e pe teren, cum le pune jocul la adancimea strazii
    dr = ImageDraw.Draw(img)
    for span in props["wires"]:
        col = tuple(props["wireLook"][span["which"]]) + (255,)
        pts = [(p["x"] / D, p["y"] / D) for p in span["pts"]]
        dr.line(pts, fill=col, width=1)
    return G, img


FILM_EXPORT = """
local serde = require("@lune/serde")
local T = require("../../src/Shared/Config/TycoonConfig")
local DamMath = require("../../src/Shared/Modules/DamMath")
local ModernConfig = require("../../src/Shared/Config/ModernConfig")
local Assets = require("../../src/Shared/Config/Assets")
local out = { nets = {}, lamps = T.streetLamps(1), poles = T.wirePoles(1), pier = T.PIER, ferry = T.FERRY,
    stakes = T.SURVEY_STAKES, lanes = T.LANE_Y, frames = {} }
for _, p in T.padsOfWorld(1) do
    if p.live and p.x ~= nil then
        for _, e in p.effects do
            if e.kind == "net" and e.lane ~= nil then
                table.insert(out.nets, { id = p.id, x = p.x, y = p.y, laneY = T.LANE_Y[e.lane] or 0,
                    turbine = T.isTurbine(p) })
            end
        end
    end
end
local districts = T.districtsOf(1)
local first, last = districts[1].deck, districts[#districts].deck
local eastX, westX = (last.x0 + last.x1) / 2, (first.x0 + first.x1) / 2
for _, t in { 1, 3, 6, 9, 12, 15 } do
    local f = DamMath.frameAt(t, false)
    table.insert(out.frames, { t = t, phase = f.phase, text = f.text, sub = f.sub, progress = f.progress, bars = f.bars,
        skip = f.skip, camX = eastX + (westX - eastX) * f.pan, camY = T.PLOT_ORIGIN.y + 1100 })
end
-- firele dintre stalpi, ca in ModernProps (cu cel spre Power House), cate 9 puncte lasate pe fiecare deschidere
local poles = T.wirePoles(1)
local feed = nil
local house = T.byId[ModernConfig.POWER_FEED.pad]
local houseArt = Assets.tycoon.power_house
if house ~= nil and house.live and house.x ~= nil then
    local fx, fy = ModernConfig.feedPoint(house.x, T.buildingBase(house), houseArt.width, houseArt.height, 3)
    feed = { x = fx, y = fy }
end
out.wires = {}
for _, span in ModernConfig.wireSpans(poles, Assets.tycoon.wire_pole.height, 3, feed) do
    local pts = {}
    for i = 0, 8 do
        local x, y = ModernConfig.wirePoint(span.ax, span.ay, span.bx, span.by, i / 8)
        table.insert(pts, { x = x, y = y })
    end
    table.insert(out.wires, { which = span.which, pts = pts })
end
out.wireLook = { near = ModernConfig.WIRE.colorNear, far = ModernConfig.WIRE.colorFar }
out.postX = { line = ModernConfig.WIRE_POLE_POST_X, ["end"] = ModernConfig.WIRE_POLE_END.postX }
print(serde.encode("json", out))
"""

_PROPS = None


def film_props():
    """Locurile din joc (TycoonConfig) si cadrele filmului (DamMath.frameAt + DamFilm.panPoint), exportate cu Lune."""
    global _PROPS
    if _PROPS is None:
        import json
        import subprocess

        tmp = os.path.join(ROOT, "scripts", "_tmp_a0")
        os.makedirs(tmp, exist_ok=True)
        path = os.path.join(tmp, "film.luau")
        with open(path, "w") as f:
            f.write(FILM_EXPORT)
        try:
            res = subprocess.run(["lune", "run", path], cwd=ROOT, capture_output=True, text=True)
            if res.returncode != 0:
                sys.exit("exportul filmului a picat:\n" + res.stderr)
            _PROPS = json.loads(res.stdout)
        finally:
            os.remove(path)
            os.rmdir(tmp)
    return _PROPS


def person(rng, row=2, frame=0):
    """Un om din foile in straturi (corp, tinuta, par), cadrul `frame` din randul `row` (AnimConfig.ROWS)."""
    outfits = [n[7:-4] for n in os.listdir(SPR) if n.startswith("outfit_")]
    layers = [
        "body_" + rng.choice(("a", "b")),
        "outfit_" + rng.choice(sorted(outfits)),
        "hair_" + rng.choice(("short", "long", "bun")),
    ]
    out = Image.new("RGBA", (16, 24), (0, 0, 0, 0))
    for name in layers:
        sheet = sprite(name)
        out.alpha_composite(sheet.crop((frame * 16, row * 24, frame * 16 + 16, row * 24 + 24)))
    return out


def silhouette(fig, rim=(255, 170, 96)):
    """Silueta la apus: omul intunecat, cu marginea dinspre soare (stanga) aprinsa."""
    w, h = fig.size
    src = fig.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] > 60:
                edge = x == 0 or src[x - 1, y][3] <= 60
                px[x, y] = (rim + (255,)) if edge else (38, 24, 42, 255)
    return out


def tint(img, rgb, alpha):
    over = Image.new("RGBA", img.size, rgb + (round(alpha * 255),))
    return Image.alpha_composite(img, over)


def warm(img, amount):
    """Lumina de dupa-amiaza: un strat cald, inmultit (nu peste tot la fel de opac ca amurgul)."""
    r, g, b, a = img.split()
    r = r.point(lambda v: min(255, round(v * (1 + 0.10 * amount))))
    g = g.point(lambda v: round(v * (1 - 0.02 * amount)))
    b = b.point(lambda v: round(v * (1 - 0.16 * amount)))
    return Image.merge("RGBA", (r, g, b, a))


def scaffold(G, img, x0, x1, progress):
    """Schelele de lemn peste rau, intre maluri, si zidul care urca din ambele maluri spre mijloc (A2: propunere)."""
    dr = ImageDraw.Draw(img)
    wall = G["dam"] if "dam" in G else None
    ax0, ax1 = round(x0 / D), round(x1 / D)
    far = lambda ix: G["far"]["y"][ix] / D  # noqa: E731
    near = lambda ix: G["near"]["y"][ix] / D  # noqa: E731
    mid = ax0 + (ax1 - ax0) // 2
    top, bottom = round(far(mid)) - 4, round(near(mid)) + 4
    span = bottom - top
    # zidul: din fiecare mal cate `progress` din jumatatea lui
    built = round(span / 2 * progress)
    stone = dam_wall("A", wall_geometry(), dry=True)
    stone = stone.resize((ax1 - ax0, stone.height * (ax1 - ax0) // stone.width), Image.NEAREST)
    sh = stone.height
    north = stone.crop((0, 0, stone.width, min(sh, (top - (top - 4)) + built + 10)))
    img.alpha_composite(north, (ax0, top - 10))
    south_h = built + 14
    south = stone.crop((0, sh - south_h, stone.width, sh))
    img.alpha_composite(south, (ax0, bottom - south_h + 10))
    # schelele: stalpi, podine si contravantuiri peste golul ramas
    gap0, gap1 = top - 10 + north.height, bottom - south_h + 10
    for x in range(ax0 - 2, ax1 + 3, 9):
        dr.line([(x, gap0 - 6), (x, gap1 + 6)], fill=TIMBER[1], width=1)
    for y in range(gap0, gap1, 12):
        dr.rectangle([ax0 - 3, y, ax1 + 3, y + 1], fill=TIMBER[3])
        dr.line([(ax0 - 2, y + 2), (ax0 + 7, y + 11)], fill=TIMBER[0])
        dr.line([(ax1 + 2, y + 2), (ax1 - 7, y + 11)], fill=TIMBER[0])
    return (gap0, gap1)


_WALL_G = None


def wall_geometry():
    global _WALL_G
    if _WALL_G is None:
        _WALL_G = VG.geometry(2)
    return _WALL_G


def frame_view(village, cx, cy, view_w=1440, view_h=810):
    w, h = view_w // D, view_h // D
    x0 = max(0, min(village.width - w, round(cx / D - w / 2)))
    y0 = max(0, min(village.height - h, round(cy / D - h / 2)))
    return village.crop((x0, y0, x0 + w, y0 + h)), (x0, y0)


def letterbox(img, amount):
    dr = ImageDraw.Draw(img)
    bar = round(img.height * 0.12 * amount)
    if bar > 0:
        dr.rectangle([0, 0, img.width, bar], fill=(0, 0, 0, 255))
        dr.rectangle([0, img.height - bar, img.width, img.height], fill=(0, 0, 0, 255))
    return bar


def caption(img, text, bar):
    """Textul fazei, in mijlocul benzii de jos, cu Skip in coltul din dreapta (ca DamFilm.placeCaption)."""
    dr = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 8)
    tw = dr.textlength(text, font=font)
    x, y = round(img.width / 2 - tw / 2), round(img.height - bar / 2 - 4)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        dr.text((x + dx, y + dy), text, font=font, fill=(20, 16, 24, 255))
    dr.text((x, y), text, font=font, fill=(240, 233, 218, 255))


def skip(img, bar):
    dr = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT, 8)
    w, h = 40, 14
    x1, y1 = img.width - 6, img.height - max(6, (bar - h) // 2)
    dr.rectangle([x1 - w, y1 - h, x1, y1], fill=(120, 86, 56, 255), outline=(60, 40, 28, 255))
    dr.text((x1 - w + 5, y1 - h + 3), "Skip", font=font, fill=(240, 233, 218, 255))


def film_plate():
    G, village = village_image()
    props = film_props()
    rng = random.Random(4)
    F = {f["t"]: f for f in props["frames"]}
    frames = []

    def coded(t, camera=None, dusk_extra=0.0):
        """Un cadru cum il deseneaza DamFilm.render azi: benzile, amurgul (0,45 x cat s-a lasat), camera din panPoint."""
        f = F[t]
        cx, cy = camera if camera is not None else (f["camX"], f["camY"])
        img, origin = frame_view(village, cx, cy)
        dusk = f["progress"] if f["phase"] == "people" else (1 if f["phase"] in ("build", "card") else 0)
        if dusk + dusk_extra > 0:
            img = tint(img, (70, 34, 52), 0.45 * min(1, dusk + dusk_extra))
        return f, img, origin

    # 1. clopotul (0:01): benzile sunt deja intregi (FILM_BARS_IN = 0,5 s); un singur clopot (SoundController)
    f, img, _ = coded(1)
    letterbox(img, f["bars"])
    frames.append(("0:01  BELL", "the bars are in; one bell rings (sound)", img))
    # 2-3. privirea: camera aluneca pe strada, de la Wire Works la Landing; Skip de la secunda 3
    for t, desc in ((3, "the camera starts over the Wire Works; Skip appears"), (6, "...over the Mill toward the Landing")):
        f, img, _ = coded(t)
        bar = round(img.height * 0.12 * f["bars"])
        letterbox(img, f["bars"])
        caption(img, f["text"], bar)
        if f["skip"]:
            skip(img, bar)
        frames.append((f"0:0{t}  LOOK", desc, img))
    # 4. oamenii (0:09): amurgul pe jumatate (cat il lasa codul azi); siluetele sunt propunerea A2
    f, img, (ox, oy) = coded(9)
    # pe piata si pe alei, spre punte (strada de la y 1450 cade sub banda de jos a cadrului)
    walk_y = 1300 / D - oy
    for i in range(14):
        fig = silhouette(person(rng, row=7 if i % 3 == 0 else 2, frame=i % 4))
        x = 30 + i * 21 + rng.randint(-4, 4)
        y = walk_y - 24 + rng.randint(-10, 10) - (i % 2) * 16 - i * 3
        img.alpha_composite(fig, (x, round(y)))
    bar = round(img.height * 0.12)
    letterbox(img, 1)
    caption(img, f["text"], bar)
    skip(img, bar)
    frames.append(("0:09  PEOPLE", "A2 PROPOSAL: silhouettes walk to the river (dusk as the code sets it)", img))
    # 5. barajul (0:12): PROPUNERE A2 -- camera urca la rau (azi ramane pe strada), plasele de pe linia zidului (First si
    # Second Net) ies din apa (PLAN-HARTA §1), schelele si zidul cresc din ambele maluri
    wall_x0, wall_x1 = 640, 880
    for net in props["nets"]:
        net["hidden"] = wall_x0 - 60 <= net["x"] <= wall_x1 + 60
    _, lifted = village_image()
    for net in props["nets"]:
        net["hidden"] = False
    f = F[12]
    img, (ox, oy) = frame_view(lifted, 760, 690)
    img = tint(img, (70, 34, 52), 0.45)
    layer = Image.new("RGBA", lifted.size, (0, 0, 0, 0))
    gap = scaffold(G, layer, wall_x0, wall_x1, 0.55)
    img.alpha_composite(layer.crop((ox, oy, ox + img.width, oy + img.height)))
    for i in range(6):
        fig = silhouette(person(rng, row=6, frame=i % 4))
        x = round((wall_x0 + 20 + (i % 3) * 70) / D - ox)
        y = round(gap[0] - oy - 22 + (i // 3) * ((gap[1] - gap[0]) // 2))
        img.alpha_composite(fig, (x, y))
    for i in range(7):
        fig = silhouette(person(rng, row=7, frame=i % 4))
        x = round((900 + i * 64) / D - ox)
        y = round(800 / D - oy) + (i % 2) * 6
        img.alpha_composite(fig, (x, y))
    bar = round(img.height * 0.12)
    letterbox(img, 1)
    caption(img, f["text"], bar)
    skip(img, bar)
    frames.append(
        ("0:12  BUILD", "A2 PROPOSAL: camera rises to the river, the nets come out, scaffolds, the wall grows", img)
    )
    # 6. cartonasul (0:15): negru, cu titlul si randul de dedesubt (Strings.DAM_CARD_*), apoi reincarcarea
    f = F[15]
    img = Image.new("RGBA", frames[0][2].size, (0, 0, 0, 255))
    dr = ImageDraw.Draw(img)
    big, small = ImageFont.truetype(FONT, 24), ImageFont.truetype(FONT, 8)
    for text, font, y, col in (
        ("THE DAM", big, img.height * 0.40, (240, 233, 218)),
        ("Your people built this", small, img.height * 0.58, (196, 186, 168)),
    ):
        tw = dr.textlength(text, font=font)
        dr.text((round(img.width / 2 - tw / 2), round(y)), text, font=font, fill=col + (255,))
    if f["skip"]:
        skip(img, round(img.height * 0.12))  # [verificatorul A0] Skip ramane si pe cartonas (DamFilm.render)
    frames.append(("0:15  CARD", "black card (Skip still there), then the reload into the new map", img))

    scale, gut, head = 2, 24, 44
    fw, fh = frames[0][2].width * scale, frames[0][2].height * scale
    cols = 2
    rows_n = math.ceil(len(frames) / cols)
    out = Image.new("RGBA", (cols * fw + (cols + 1) * gut, rows_n * (fh + head) + (rows_n + 1) * gut), (24, 28, 30, 255))
    dr = ImageDraw.Draw(out)
    title, note = ImageFont.truetype(FONT, 12), ImageFont.truetype(FONT, 8)
    for i, (label, desc, f) in enumerate(frames):
        c, r = i % cols, i // cols
        x, y = gut + c * (fw + gut), gut + r * (fh + head + gut)
        dr.text((x, y), label, font=title, fill=(240, 233, 218))
        dr.text((x, y + 20), desc, font=note, fill=(170, 164, 152))
        out.paste(f.resize((fw, fh), Image.NEAREST), (x, y + head))
    path = os.path.join(P.SCRATCH, "a0_dam_film.png")
    out.save(path)
    print("scris", path, out.size)


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("wall", "all"):
        wall_plate()
    if what in ("film", "all"):
        film_plate()
