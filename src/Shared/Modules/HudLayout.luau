--!strict
-- [D63] ASEZAREA CIFRELOR DIN COLTUL HUD-ULUI, pe o grila. Modul pur: doar dreptunghiuri, in unitati logice ale panzei HUD.
--
-- Owner-ul, pe telefon (2026-09-19): "cam inghesuite din cauza acestor stats, nu sunt aranjate frumos". Aveau patru
-- inaltimi si trei aliniamente: sacul mai inalt si mai jos decat monedele, AWAY la coada randului de sus, la jumatatea
-- inaltimii, rata mai ingusta decat moneda de deasupra ei, iar linia NEXT de alta latime decat tot restul. Acum e UN BLOC
-- drept, de aceeasi latime pe toate randurile:
--   randul 1   monede | perle | sac          (aceeasi inaltime, aceeasi linie de sus)
--   randul 2   rata (sub monede) | AWAY (sub perle si sac)
--   randul 3   linia NEXT, lata cat blocul
-- Blocul e si cu ~180 de unitati mai ingust decat inainte (AWAY nu mai prelungeste randul de sus), deci acopera mai
-- putin din lume pe un telefon. HUDController citeste de aici; un test tine grila dreapta.
local HudLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }

HudLayout.X = 20 -- marginea din stanga a blocului
HudLayout.Y = 12 -- marginea de sus
HudLayout.GAP = 8 -- intre pastilele aceluiasi rand
HudLayout.ROW_GAP = 6 -- intre randuri (era 4: "inghesuite")
HudLayout.ROW1_H = 48
HudLayout.ROW2_H = 32
HudLayout.COIN_W = 196
HudLayout.PEARL_W = 150
HudLayout.SACK_W = 120
HudLayout.OBJ_H = 58
HudLayout.OBJ_H_STEP = 78 -- linia NEXT cu randul pasului [D51]

-- Latimea blocului: toate randurile o au pe aceeasi.
function HudLayout.width(): number
    return HudLayout.COIN_W + HudLayout.GAP + HudLayout.PEARL_W + HudLayout.GAP + HudLayout.SACK_W
end

function HudLayout.rects(withStep: boolean?): { [string]: Rect }
    local x, y, gap = HudLayout.X, HudLayout.Y, HudLayout.GAP
    local row2 = y + HudLayout.ROW1_H + HudLayout.ROW_GAP
    local row3 = row2 + HudLayout.ROW2_H + HudLayout.ROW_GAP
    local pearlX = x + HudLayout.COIN_W + gap
    return {
        coin = { x = x, y = y, w = HudLayout.COIN_W, h = HudLayout.ROW1_H },
        pearl = { x = pearlX, y = y, w = HudLayout.PEARL_W, h = HudLayout.ROW1_H },
        sack = {
            x = pearlX + HudLayout.PEARL_W + gap,
            y = y,
            w = HudLayout.SACK_W,
            h = HudLayout.ROW1_H,
        },
        rate = { x = x, y = row2, w = HudLayout.COIN_W, h = HudLayout.ROW2_H },
        away = {
            x = pearlX,
            y = row2,
            w = HudLayout.PEARL_W + gap + HudLayout.SACK_W,
            h = HudLayout.ROW2_H,
        },
        objective = {
            x = x,
            y = row3,
            w = HudLayout.width(),
            h = if withStep == true then HudLayout.OBJ_H_STEP else HudLayout.OBJ_H,
        },
    }
end

return HudLayout
