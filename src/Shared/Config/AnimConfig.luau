--!strict
-- Randurile din foaia de animatie a colonistilor si regula care alege randul potrivit [RIVERKEEP 9].
-- Foile in straturi (Assets.people) au 20 de randuri x 4 cadre de 16x24, in ordinea din ROWS; foaia veche
-- dintr-o bucata (Assets.character_anim) are doar primele 15.
-- `side = true` inseamna ca desenul e orientat spre DREAPTA si se oglindeste pentru stanga.
export type Row = { id: string, index: number, fps: number, side: boolean }

local function row(id: string, index: number, fps: number, side: boolean): Row
    return { id = id, index = index, fps = fps, side = side }
end

local AnimConfig = {
    FRAME_WIDTH = 16,
    FRAME_HEIGHT = 24,
    FRAMES_PER_ROW = 4,
}

AnimConfig.ROWS = {
    walk_down = row("walk_down", 0, 8, false),
    walk_up = row("walk_up", 1, 8, false),
    walk_side = row("walk_side", 2, 8, true),
    idle_down = row("idle_down", 3, 3, false),
    idle_up = row("idle_up", 4, 3, false),
    idle_side = row("idle_side", 5, 3, true),
    work = row("work", 6, 7, true),
    carry = row("carry", 7, 8, true),
    eat = row("eat", 8, 4, false),
    sleep = row("sleep", 9, 1.2, false),
    cheer = row("cheer", 10, 9, false),
    fish = row("fish", 11, 3, true),
    -- Alergarea: randuri DESENATE, nu ciclul de mers accelerat. Doar jucatorul alearga;
    -- colonistii isi pastreaza mersul, altfel o colonie intreaga ar parea in panica.
    run_down = row("run_down", 12, 11, false),
    run_up = row("run_up", 13, 11, false),
    run_side = row("run_side", 14, 11, true),
    -- [D55] Roaba: mersul cu ea in trei directii, incarcatul si rasturnatul (scripts/art/settlers.py).
    push_side = row("push_side", 15, 8, true),
    push_down = row("push_down", 16, 8, false),
    push_up = row("push_up", 17, 8, false),
    load = row("load", 18, 5, true),
    tip = row("tip", 19, 5, true),
}

local WALK_BY_FACING = {
    down = AnimConfig.ROWS.walk_down,
    up = AnimConfig.ROWS.walk_up,
    left = AnimConfig.ROWS.walk_side,
    right = AnimConfig.ROWS.walk_side,
}
local IDLE_BY_FACING = {
    down = AnimConfig.ROWS.idle_down,
    up = AnimConfig.ROWS.idle_up,
    left = AnimConfig.ROWS.idle_side,
    right = AnimConfig.ROWS.idle_side,
}
-- Ce face colonistul in cladirea in care a intrat, dupa felul cladirii
local USING_BY_KIND = {
    food = AnimConfig.ROWS.eat,
    rest = AnimConfig.ROWS.sleep,
    joy = AnimConfig.ROWS.cheer,
}

-- Randul potrivit pentru starea curenta. `moving` vine din interpolarea de pe client, nu de la server:
-- asa animatia se schimba exact cand se opreste sprite-ul, nu cand ajunge pachetul.
local RUN_BY_FACING = {
    down = AnimConfig.ROWS.run_down,
    up = AnimConfig.ROWS.run_up,
    left = AnimConfig.ROWS.run_side,
    right = AnimConfig.ROWS.run_side,
}

function AnimConfig.runRow(facing: string): Row
    return RUN_BY_FACING[facing] or AnimConfig.ROWS.run_down
end

-- [D55] Omul cu roaba: mersul dupa directie; pe loc, incarcatul sau rasturnatul (laterale).
local PUSH_BY_FACING = {
    down = AnimConfig.ROWS.push_down,
    up = AnimConfig.ROWS.push_up,
    left = AnimConfig.ROWS.push_side,
    right = AnimConfig.ROWS.push_side,
}

function AnimConfig.barrowRow(task: string, facing: string): Row
    if task == "load" then
        return AnimConfig.ROWS.load
    elseif task == "tip" then
        return AnimConfig.ROWS.tip
    end
    return PUSH_BY_FACING[facing] or AnimConfig.ROWS.push_side
end

function AnimConfig.rowFor(
    task: string,
    facing: string,
    moving: boolean,
    targetKind: string?,
    job: string?
): Row
    if moving then
        -- constructorul care se duce la santier duce materiale in brate
        if job == "Builder" and targetKind == "site" then
            return AnimConfig.ROWS.carry
        end
        return WALK_BY_FACING[facing] or AnimConfig.ROWS.walk_down
    end
    if task == "working" then
        return AnimConfig.ROWS.work
    end
    if task == "fishing" then
        return AnimConfig.ROWS.fish
    end
    if task == "using" then
        return USING_BY_KIND[targetKind or ""]
            or IDLE_BY_FACING[facing]
            or AnimConfig.ROWS.idle_down
    end
    return IDLE_BY_FACING[facing] or AnimConfig.ROWS.idle_down
end

return AnimConfig
