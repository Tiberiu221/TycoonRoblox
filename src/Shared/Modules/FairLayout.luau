--!strict
-- [D60] GEOMETRIA BALCIULUI DE SEARA. Un singur loc din care se deseneaza locul si din care se verifica asezarea:
-- clientul citeste `SPOTS` ca sa puna obiectele, iar testul citeste tot `SPOTS` ca sa se asigure ca nimic nu intra in
-- altceva. Asa s-a prins si in macheta ca felinarele stateau in scena: 41 de obiecte, zero suprapuneri.
--
-- Bâlciul e rotund, ~1620 pe latime, cu vatra in mijloc si cate ceva de vazut/facut pe fiecare margine (owner,
-- 2026-09-16). Coordonatele sunt ale place-ului al doilea, nu ale satului: aici raul e jos, iar tu vii cu barca in
-- amonte si acostezi la debarcader.
--
-- `y` e BAZA obiectului (ancora 0.5, 1), ca peste tot in joc; `sprite` e cheia din Assets.fair.
local FairLayout = {}

export type Spot = { id: string, sprite: string, x: number, y: number, scale: number }
export type Rect = { x0: number, x1: number, y0: number, y1: number }
export type Edge = { id: string, label: string, x: number, y: number, open: boolean }

FairLayout.SIZE = { w = 1620, h = 1680 }
FairLayout.CENTER = { x = 810, y = 800 }
-- poiana de pamant batatorit, pe care se merge; in afara ei e iarba si padurea care inchide harta
FairLayout.FLOOR = { x = 810, y = 800, rx = 470, ry = 430 }
FairLayout.POND = { x = 210, y = 800, rx = 190, ry = 130 } -- iazul de concurs [D61]
FairLayout.WATER_Y = 1530 -- de aici in jos e raul pe care ai venit
FairLayout.SPAWN = { x = 810, y = 1330 } -- unde pui piciorul pe mal, dupa capatul debarcaderului
FairLayout.MAX_PLAYERS = 24 -- owner, 2026-09-16
-- Eticheta de sub fiecare trofeu (BoardController): trofeele stau din 90 in 90, deci eticheta are 84, ca sa nu se
-- atinga, si trei randuri (specia, marimea, numele taiat la `chars` litere). In Studio (2026-09-17), "Not caught yet"
-- era mai lat decat cutia si cele patru se calcau; testul verifica acum si textul, nu doar cutia.
FairLayout.TROPHY_TAG = { w = 84, h = 48, gap = 4, chars = 11 }

-- Marginile, in ordinea in care le vezi mergand de la debarcader spre stanga. `open = false` = desenata, dar se
-- deschide in D61; are indicatorul ei, ca nimeni sa nu astepte degeaba [D43].
FairLayout.EDGES = {
    { id = "ferry", label = "Ferry home", x = 810, y = 1500, open = true },
    { id = "stage", label = "Stage & Leaderboards", x = 810, y = 250, open = true },
    { id = "tables", label = "Tables & Music", x = 1300, y = 330, open = true },
    { id = "market", label = "Market", x = 1390, y = 520, open = true },
    { id = "tailor", label = "Tailor", x = 1234, y = 1140, open = false },
    { id = "gate", label = "Village Gate", x = 386, y = 1140, open = false },
    { id = "pond", label = "Contest Pond", x = 210, y = 640, open = false },
    { id = "games", label = "Games", x = 379, y = 250, open = false },
} :: { Edge }

-- Obiectele, exact cum au fost aprobate pe macheta (2026-09-16).
FairLayout.SPOTS = {
    -- nord: scena care e si tabela, cu trofeele si soclul campionului
    { id = "stage", sprite = "stage", x = 810, y = 338, scale = 3 },
    { id = "plinth", sprite = "plinth", x = 1240, y = 418, scale = 3 },
    { id = "flag_left", sprite = "flag", x = 460, y = 513, scale = 3 },
    { id = "flag_right", sprite = "flag", x = 1160, y = 513, scale = 3 },
    { id = "trophy_1", sprite = "trophy", x = 540, y = 488, scale = 3 },
    { id = "trophy_2", sprite = "trophy", x = 630, y = 488, scale = 3 },
    { id = "trophy_3", sprite = "trophy", x = 720, y = 488, scale = 3 },
    { id = "trophy_4", sprite = "trophy", x = 810, y = 488, scale = 3 },
    -- nord-est: mesele, bancile lor si muzicantul
    { id = "table_1", sprite = "table", x = 1250, y = 590, scale = 3 },
    { id = "table_2", sprite = "table", x = 1394, y = 420, scale = 3 },
    { id = "bench_table_1", sprite = "bench", x = 1074, y = 490, scale = 3 },
    { id = "bench_table_2", sprite = "bench", x = 1234, y = 660, scale = 3 },
    -- est: tarabele negustorului
    { id = "stall_1", sprite = "stall_1", x = 1390, y = 615, scale = 3 },
    { id = "stall_2", sprite = "stall_2", x = 1390, y = 800, scale = 3 },
    { id = "stall_3", sprite = "stall_3", x = 1390, y = 985, scale = 3 },
    -- sud-est: cortul croitoresei [D61]
    { id = "tent", sprite = "tent", x = 1234, y = 1230, scale = 3 },
    -- sud: debarcaderul si barca
    { id = "dock", sprite = "dock", x = 810, y = 1560, scale = 3 },
    { id = "ferry", sprite = "ferry", x = 1010, y = 1610, scale = 3 },
    -- sud-vest: poarta satelor si satele scoase in fata [D61]
    { id = "arch", sprite = "arch", x = 386, y = 1230, scale = 3 },
    { id = "mini_1", sprite = "miniature", x = 271, y = 1365, scale = 3 },
    { id = "mini_2", sprite = "miniature", x = 386, y = 1365, scale = 3 },
    { id = "mini_3", sprite = "miniature", x = 501, y = 1365, scale = 3 },
    -- vest: iazul de concurs, cu jetiul si stuful [D61]
    { id = "pond_dock", sprite = "dock", x = 270, y = 840, scale = 3 },
    -- nord-vest: gheretele de joc [D61]
    { id = "booth_1", sprite = "booth", x = 379, y = 333, scale = 3 },
    { id = "booth_2", sprite = "booth", x = 230, y = 470, scale = 3 },
    -- mijlocul: vatra, roata zilnica cu focurile ei si bancile din jur
    { id = "bonfire", sprite = "bonfire", x = 810, y = 830, scale = 3 },
    { id = "wheel", sprite = "wheel", x = 560, y = 880, scale = 3 },
    { id = "brazier_1", sprite = "brazier", x = 710, y = 990, scale = 3 },
    { id = "brazier_2", sprite = "brazier", x = 560, y = 1070, scale = 3 },
    { id = "brazier_3", sprite = "brazier", x = 710, y = 760, scale = 3 },
    { id = "bench_1", sprite = "bench", x = 1050, y = 903, scale = 3 },
    { id = "bench_2", sprite = "bench", x = 879, y = 1035, scale = 3 },
    { id = "bench_3", sprite = "bench", x = 942, y = 589, scale = 3 },
    { id = "bench_4", sprite = "bench", x = 1066, y = 737, scale = 3 },
    -- felinarele inelului, care tin ghirlandele de becuri
    { id = "lamp_1", sprite = "lamppost", x = 1225, y = 954, scale = 3 },
    { id = "lamp_2", sprite = "lamppost", x = 985, y = 1179, scale = 3 },
    { id = "lamp_3", sprite = "lamppost", x = 642, y = 1182, scale = 3 },
    { id = "lamp_4", sprite = "lamppost", x = 395, y = 646, scale = 3 },
    { id = "lamp_5", sprite = "lamppost", x = 1150, y = 700, scale = 3 },
    -- recuzita
    { id = "crate_1", sprite = "crate", x = 1000, y = 500, scale = 3 },
    { id = "crate_2", sprite = "crate", x = 710, y = 1160, scale = 3 },
    { id = "barrel_1", sprite = "barrel", x = 930, y = 440, scale = 3 },
    { id = "reeds_1", sprite = "reeds", x = 120, y = 700, scale = 3 },
    { id = "reeds_2", sprite = "reeds", x = 150, y = 930, scale = 3 },
} :: { Spot }

-- Perechile care AU voie sa se atinga: pontonul intra in apa, jetiul sta pe iaz, stuful creste din mal.
FairLayout.TOUCHING = {
    dock_ferry = true,
    pond_dock_reeds_1 = true,
    pond_dock_reeds_2 = true,
}

function FairLayout.boxOf(spot: Spot, width: number, height: number): Rect
    local w, h = width * spot.scale, height * spot.scale
    return { x0 = spot.x - w / 2, x1 = spot.x + w / 2, y0 = spot.y - h, y1 = spot.y }
end

function FairLayout.overlap(a: Rect, b: Rect): boolean
    return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- Pe podeaua bâlciului se merge; in afara ei sta iarba, padurea si apa.
function FairLayout.onFloor(x: number, y: number): boolean
    local f = FairLayout.FLOOR
    local dx, dy = (x - f.x) / f.rx, (y - f.y) / f.ry
    return dx * dx + dy * dy <= 1
end

-- Unde se poate merge: pe harta, deasupra raului de jos si in afara iazului (inchis pana la D61). Ca in sat, se merge
-- si pe langa obiecte: in lumea vazuta de sus, doar apa opreste pasul.
function FairLayout.isWalkable(x: number, y: number): boolean
    if x < 0 or x > FairLayout.SIZE.w or y < 0 or y >= FairLayout.WATER_Y then
        return false
    end
    return not FairLayout.inPond(x, y)
end

function FairLayout.inPond(x: number, y: number): boolean
    local p = FairLayout.POND
    local dx, dy = (x - p.x) / p.rx, (y - p.y) / p.ry
    return dx * dx + dy * dy <= 1
end

return FairLayout
