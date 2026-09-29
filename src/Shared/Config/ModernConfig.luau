--!strict
-- [D70] DESENUL MODERNIZARII DIN ERA 3, ca date (tabelele scoase de `python3 scripts/art/d70_modern.py luau`, in pixeli de
-- foaie; x Assets.PIXEL_SCALE = pixeli de lume). Treapta vine din ModernMath; aici e doar ce desen merge unde.
-- Pur, fara `game`: il citesc satul (UI/Modern, UI/ModernProps), macheta din balci si testele.
local ModernConfig = {}

-- Treapta 3 ("brick"): desenul de azi -> varianta lui moderna. Doar cladirile satului vechi (Landing); Moara si Wire
-- Works au desenele lor si nu trec prin aici.
ModernConfig.MODERN_OF =
    { -- desenul de azi -> varianta moderna (treapta 3); lipsa = ramane desenul de azi
        storage = "storage_modern",
        sawmill = "sawmill_modern",
        sawmill_grand = "sawmill_grand_modern",
        tavern = "tavern_modern",
        tavern_grand = "tavern_grand_modern",
        scrap_shed = "scrap_shed_modern",
        workshop_e1 = "workshop_modern",
        workshop_grand = "workshop_grand_modern",
    }

-- Treptele 4 ("glass") si 5 ("lights"): pentru fiecare casa, un strat de aceeasi marime cu ea, cu DOAR ferestrele ei noi,
-- in atlasele prop_windows_glass (treapta 4) si prop_windows_lit (treapta 5), pe aceleasi celule. Ce statea in fata
-- ferestrei (roaba, franghia) ramane in fata. Casele fara ferestre (colibele mici ale Smelter-ului etc.) n-au celula.
ModernConfig.WINDOW_CELLS = { -- casa -> dreptunghiul stratului ei in atlas (aceeasi marime cu casa)
    hut_porter_1 = { x = 0, y = 0, w = 32, h = 28 }, -- landing
    hut_porter_2 = { x = 40, y = 0, w = 40, h = 34 }, -- landing
    hut_sawyer_1 = { x = 80, y = 0, w = 32, h = 28 }, -- landing
    hut_sawyer_2 = { x = 120, y = 0, w = 40, h = 34 }, -- landing
    hut_hauler_1 = { x = 160, y = 0, w = 32, h = 28 }, -- landing
    hut_hauler_2 = { x = 200, y = 0, w = 40, h = 34 }, -- landing
    hut_scrap_collector_1 = { x = 240, y = 0, w = 32, h = 28 }, -- landing
    hut_scrap_collector_2 = { x = 280, y = 0, w = 40, h = 34 }, -- landing
    hut_scrap_porter_1 = { x = 0, y = 34, w = 32, h = 28 }, -- landing
    hut_scrap_porter_2 = { x = 40, y = 34, w = 40, h = 34 }, -- landing
    hut_smelter_2 = { x = 80, y = 34, w = 40, h = 34 }, -- landing
    hut_iron_hauler_1 = { x = 120, y = 34, w = 32, h = 28 }, -- landing
    hut_iron_hauler_2 = { x = 160, y = 34, w = 40, h = 34 }, -- landing
    hut_mill_collector_1 = { x = 200, y = 34, w = 32, h = 28 }, -- mill
    hut_mill_collector_2 = { x = 240, y = 34, w = 40, h = 34 }, -- mill
    hut_mill_porter_1 = { x = 280, y = 34, w = 32, h = 28 }, -- mill
    hut_mill_porter_2 = { x = 0, y = 68, w = 40, h = 34 }, -- mill
    hut_founder_2 = { x = 40, y = 68, w = 40, h = 34 }, -- mill
    hut_parts_hauler_1 = { x = 80, y = 68, w = 32, h = 28 }, -- mill
    hut_parts_hauler_2 = { x = 120, y = 68, w = 40, h = 34 }, -- mill
    hut_ore_collector_1 = { x = 160, y = 68, w = 32, h = 28 }, -- mill
    hut_ore_collector_2 = { x = 200, y = 68, w = 40, h = 34 }, -- mill
    hut_ore_porter_1 = { x = 240, y = 68, w = 32, h = 28 }, -- mill
    hut_ore_porter_2 = { x = 280, y = 68, w = 40, h = 34 }, -- mill
    hut_coppersmith_2 = { x = 0, y = 102, w = 40, h = 34 }, -- mill
    hut_copper_hauler_1 = { x = 40, y = 102, w = 32, h = 28 }, -- mill
    hut_copper_hauler_2 = { x = 80, y = 102, w = 40, h = 34 }, -- mill
    hut_works_collector_1 = { x = 120, y = 102, w = 32, h = 28 }, -- works
    hut_works_collector_2 = { x = 160, y = 102, w = 40, h = 34 }, -- works
    hut_works_porter_1 = { x = 200, y = 102, w = 32, h = 28 }, -- works
    hut_works_porter_2 = { x = 240, y = 102, w = 40, h = 34 }, -- works
    hut_wiredrawer_1 = { x = 280, y = 102, w = 32, h = 28 }, -- works
    hut_wiredrawer_2 = { x = 0, y = 136, w = 40, h = 34 }, -- works
    hut_coil_hauler_1 = { x = 40, y = 136, w = 32, h = 28 }, -- works
    hut_coil_hauler_2 = { x = 80, y = 136, w = 40, h = 34 }, -- works
    hut_battery_collector_1 = { x = 120, y = 136, w = 32, h = 28 }, -- works
    hut_battery_collector_2 = { x = 160, y = 136, w = 40, h = 34 }, -- works
    hut_battery_porter_1 = { x = 200, y = 136, w = 32, h = 28 }, -- works
    hut_battery_porter_2 = { x = 240, y = 136, w = 40, h = 34 }, -- works
    hut_electrician_1 = { x = 280, y = 136, w = 32, h = 28 }, -- works
    hut_electrician_2 = { x = 0, y = 170, w = 40, h = 34 }, -- works
    hut_power_hauler_1 = { x = 40, y = 170, w = 32, h = 28 }, -- works
    hut_power_hauler_2 = { x = 80, y = 170, w = 40, h = 34 }, -- works
}

-- Treapta 5: becurile firmelor si lampile aprinse ale cladirilor moderne, in prop_modern_lit.
ModernConfig.MODERN_LIT_CELLS =
    { -- cladirea moderna -> stratul ei aprins in prop_modern_lit (treapta 5)
        storage_modern = { x = 0, y = 0, w = 40, h = 32 },
        sawmill_modern = { x = 64, y = 0, w = 40, h = 32 },
        sawmill_grand_modern = { x = 128, y = 0, w = 40, h = 32 },
        tavern_modern = { x = 192, y = 0, w = 64, h = 48 },
        tavern_grand_modern = { x = 0, y = 48, w = 64, h = 48 },
        scrap_shed_modern = { x = 64, y = 48, w = 40, h = 32 },
        workshop_modern = { x = 128, y = 48, w = 64, h = 48 },
        workshop_grand_modern = { x = 192, y = 48, w = 64, h = 48 },
    }

-- Stalpii (prinsi de baza): unde se leaga cele doua fire, "near" (in fata) si "far" (in spate).
ModernConfig.WIRE_POLE_POST_X = 8 -- mijlocul stalpului in foaia de linie, unde se prinde de baza
ModernConfig.WIRE_POLE = { -- foaia 16x54, prinsa de baza (mijlocul stalpului la x 8)
    near = { x = 3, y = 11 },
    far = { x = 12, y = 6 },
}
ModernConfig.WIRE_POLE_END =
    { -- foaia 28x54: stalpul e mutat cu 12 px spre dreapta; doar la capatul de vest (oglindirea ramane pentru alta harta)
        near = { x = 15, y = 11 },
        far = { x = 24, y = 6 },
        postX = 20,
    }

-- Tarusii topografilor (x2, prinsi de baza): fasie de 3 cadre; sfoara dintre ei se leaga in `string`.
ModernConfig.SURVEY_STAKE =
    { -- x2, prinse de baza; cadrul 0 stegulet, 1 panglica, 2 nivela (fara sfoara)
        frame = { w = 12, h = 26 },
        frames = 3,
        string = { [0] = { x = 6, y = 15 }, [1] = { x = 6, y = 14 } },
    }

-- Firele dintre stalpi: near cu near, far cu far; sageata = sag x deschiderea; culorile ca RGB (Color3 il face clientul).
-- [D70, dupa verificator] sageata 3%, nu 6% ca pe plansa: la 6% firul din fata cobora pe deschiderile de 300 px peste
-- numele de sub tarabele Merchant si Clerk (testul TycoonConfig masoara curba fata de nume)
ModernConfig.WIRE = { -- firul dintre stalpi: near cu near, far cu far; sageata = sag * deschiderea
    colorNear = { 43, 54, 61 },
    colorFar = { 65, 76, 87 },
    thickness = 2,
    sag = 0.03,
}

-- Geometria firelor, comuna desenului (UI/ModernProps) si testelor de asezare, ca testul sa masoare exact firul din
-- joc. `pole` e un stalp din TycoonConfig.wirePoles(); `height` e inaltimea foii lui (pixeli de foaie), `scale` scara
-- desenului. Intoarce punctul de prindere al firului `which` ("near" | "far"), in pixeli de lume.
export type Pole = { x: number, y: number, kind: string, mirror: boolean }
function ModernConfig.wireTop(
    pole: Pole,
    which: string,
    height: number,
    scale: number
): (number, number)
    local isEnd = pole.kind == "end"
    local anchors: any = if isEnd then ModernConfig.WIRE_POLE_END else ModernConfig.WIRE_POLE
    local postX = if isEnd then ModernConfig.WIRE_POLE_END.postX else ModernConfig.WIRE_POLE_POST_X
    local p = anchors[which]
    local sign = if pole.mirror then -1 else 1
    return pole.x + sign * (p.x - postX) * scale, pole.y - (height - p.y) * scale
end

-- Punctul firului lasat dintre (ax, ay) si (bx, by) la `t` (0..1): dreapta dintre ele, plus sageata
-- sag * deschidere * 4t(1-t), cea mai adanca la mijloc.
function ModernConfig.wirePoint(
    ax: number,
    ay: number,
    bx: number,
    by: number,
    t: number
): (number, number)
    local sag = ModernConfig.WIRE.sag * math.abs(bx - ax) * 4 * t * (1 - t)
    return ax + (bx - ax) * t, ay + (by - ay) * t + sag
end

-- [D70, dupa verificator] Linia pleaca de la Power House: de la treapta 4 (Power House construita), firul din spate al
-- ultimului stalp merge pana la izolatorul din stanga (cel dinspre sat) de pe acoperisul ei. Masurat pe
-- prop_power_house.png (pixeli de foaie); scris de mana, nu de d70_modern.py.
ModernConfig.POWER_FEED = { pad = "power_house", insulator = { x = 20, y = 5 }, stage = 4 }

-- Izolatorul Power House in pixeli de lume, pentru o cladire de `spriteW` x `spriteH` (foaie) desenata la `scale` pe
-- platforma de la (padX, padY), de `padSize`: cladirile stau cu baza la 8 px sub cadrul platformei (PadController).
function ModernConfig.feedPoint(
    padX: number,
    padY: number,
    padSize: number,
    spriteW: number,
    spriteH: number,
    scale: number
): (number, number)
    local bottom = padY + padSize / 2 + 8
    local p = ModernConfig.POWER_FEED.insulator
    return padX - spriteW * scale / 2 + (p.x + 0.5) * scale, bottom - spriteH * scale + p.y * scale
end

-- Toate firele: near cu near si far cu far intre stalpii vecini (treapta 1), plus firul din spate al stalpului cel mai
-- apropiat de la vest de Power House pana la ea (`feed`, in pixeli de lume; treapta ei). Desenul si testele de asezare
-- citesc aceeasi lista.
export type Span = { ax: number, ay: number, bx: number, by: number, which: string, stage: number }
function ModernConfig.wireSpans(
    poles: { Pole },
    height: number,
    scale: number,
    feed: { x: number, y: number }?
): { Span }
    local out: { Span } = {}
    for i = 2, #poles do
        for _, which in { "far", "near" } do
            local ax, ay = ModernConfig.wireTop(poles[i - 1], which, height, scale)
            local bx, by = ModernConfig.wireTop(poles[i], which, height, scale)
            table.insert(out, { ax = ax, ay = ay, bx = bx, by = by, which = which, stage = 1 })
        end
    end
    local from: Pole? = nil
    if feed ~= nil then
        for _, pole in poles do
            if pole.x < feed.x and (from == nil or pole.x > from.x) then
                from = pole
            end
        end
    end
    if feed ~= nil and from ~= nil then
        local ax, ay = ModernConfig.wireTop(from, "far", height, scale)
        table.insert(out, {
            ax = ax,
            ay = ay,
            bx = feed.x,
            by = feed.y,
            which = "far",
            stage = ModernConfig.POWER_FEED.stage,
        })
    end
    return out
end

return ModernConfig
