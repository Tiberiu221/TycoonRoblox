--!strict
-- [D61, partea 2] CE DESEN ARE O PLATFORMA: casa omului (mica sau mare), cladirea, ruina, avizierul. Pana la vizite,
-- listele astea traiau in PadController; satul vizitat din balci (VillageDiorama) deseneaza aceleasi platforme din
-- fotografia altui jucator, iar doua liste ar fi ajuns sa spuna lucruri diferite. Aici e doar alegerea desenului --
-- cumparatul, cartonasul si pulsul raman in PadController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)
local ChainMath = require(ReplicatedStorage.Shared.Modules.ChainMath)
local GoodArt = require(script.Parent.GoodArt)

local PadArt = {}

-- [D55] COLIBELE. Platforma unei meserii cumparate arata casa omului, mica pentru unul si mare pentru doi.
PadArt.HOME_SPRITES = {
    first_runner = { "runner_hut", "runner_hut_2" },
    hire_porter = { "hut_porter_1", "hut_porter_2" },
    hire_sawyer = { "hut_sawyer_1", "hut_sawyer_2" },
    hire_hauler = { "hut_hauler_1", "hut_hauler_2" },
    dock_trader = { "stall", "stall_2" },
    -- [D56] oamenii fierului, fiecare langa locul lui
    hire_scrap_collector = { "hut_scrap_collector_1", "hut_scrap_collector_2" },
    hire_scrap_porter = { "hut_scrap_porter_1", "hut_scrap_porter_2" },
    hire_smelter = { "hut_smelter_1", "hut_smelter_2" },
    hire_iron_hauler = { "hut_iron_hauler_1", "hut_iron_hauler_2" },
    -- [D65] oamenii Morii (scripts/art/d65_crew.py). Cat casele lor nu sunt urcate, platforma o poarta pe a perechii
    -- din Era 1 (`home` mai jos).
    hire_mill_collector = { "hut_mill_collector_1", "hut_mill_collector_2" },
    hire_mill_porter = { "hut_mill_porter_1", "hut_mill_porter_2" },
    hire_founder = { "hut_founder_1", "hut_founder_2" },
    hire_parts_hauler = { "hut_parts_hauler_1", "hut_parts_hauler_2" },
    hire_merchant = { "stall_merchant", "stall_merchant_2" },
    hire_ore_collector = { "hut_ore_collector_1", "hut_ore_collector_2" },
    hire_ore_porter = { "hut_ore_porter_1", "hut_ore_porter_2" },
    hire_coppersmith = { "hut_coppersmith_1", "hut_coppersmith_2" },
    hire_copper_hauler = { "hut_copper_hauler_1", "hut_copper_hauler_2" },
    -- [D67] oamenii Wire Works. Cat casele lor nu sunt urcate, platforma o poarta pe a perechii din Moara.
    hire_works_collector = { "hut_works_collector_1", "hut_works_collector_2" },
    hire_works_porter = { "hut_works_porter_1", "hut_works_porter_2" },
    hire_wiredrawer = { "hut_wiredrawer_1", "hut_wiredrawer_2" },
    hire_coil_hauler = { "hut_coil_hauler_1", "hut_coil_hauler_2" },
    hire_clerk = { "stall_clerk", "stall_clerk_2" },
    hire_battery_collector = { "hut_battery_collector_1", "hut_battery_collector_2" },
    hire_battery_porter = { "hut_battery_porter_1", "hut_battery_porter_2" },
    hire_electrician = { "hut_electrician_1", "hut_electrician_2" },
    hire_power_hauler = { "hut_power_hauler_1", "hut_power_hauler_2" },
} :: { [string]: { string } }
-- taraba ramane recuzita mica (x2); colibele sunt cladiri (x3)
PadArt.HOME_SCALE = {
    dock_trader = TycoonConfig.PROP_SCALE,
    hire_merchant = TycoonConfig.PROP_SCALE,
    hire_clerk = TycoonConfig.PROP_SCALE,
} :: { [string]: number }

-- Avizierele: pe oameni ii angajezi, nu ii reconstruiesti. Pictograma meseriei pe avizierul curat.
PadArt.BOARD_ICON = {
    hire_porter = function()
        return Assets.goods.driftwood
    end,
    hire_sawyer = function()
        return Assets.icons.saw
    end,
    hire_hauler = function()
        return Assets.goods.planks
    end,
    -- [D56] linia fierului: plasa, scrap-ul, ciocanul, fierul
    hire_scrap_collector = function()
        return Assets.icons.net
    end,
    hire_scrap_porter = function()
        return Assets.goods.scrap
    end,
    hire_smelter = function()
        return Assets.icons.hammer
    end,
    hire_iron_hauler = function()
        return Assets.goods.iron
    end,
    -- [D65] oamenii Morii, pe aceeasi regula: plasa, marfa bruta, ciocanul, marfa gata (GoodArt: desenul marfii cand e
    -- urcat, altfel al perechii)
    hire_mill_collector = function()
        return Assets.icons.net
    end,
    hire_mill_porter = function()
        return Assets.goods.scrap
    end,
    hire_founder = function()
        return Assets.icons.hammer
    end,
    hire_parts_hauler = function()
        return GoodArt.icon("parts") or Assets.goods.iron
    end,
    hire_ore_collector = function()
        return Assets.icons.net
    end,
    hire_ore_porter = function()
        return GoodArt.icon("ore") or Assets.goods.scrap
    end,
    hire_coppersmith = function()
        return Assets.icons.hammer
    end,
    hire_copper_hauler = function()
        return GoodArt.icon("copper") or Assets.goods.iron
    end,
    -- [D67] oamenii Wire Works, pe aceeasi regula
    hire_works_collector = function()
        return Assets.icons.net
    end,
    hire_works_porter = function()
        return GoodArt.icon("works_ore") or Assets.goods.scrap
    end,
    hire_wiredrawer = function()
        return Assets.icons.hammer
    end,
    hire_coil_hauler = function()
        return GoodArt.icon("coils") or Assets.goods.iron
    end,
    hire_battery_collector = function()
        return Assets.icons.net
    end,
    hire_battery_porter = function()
        return GoodArt.icon("battery") or Assets.goods.scrap
    end,
    hire_electrician = function()
        return Assets.icons.hammer
    end,
    hire_power_hauler = function()
        return GoodArt.icon("cell") or Assets.goods.iron
    end,
} :: { [string]: () -> Assets.Sprite }

-- [D65] Platforma al carei desen il poarta `padId`: ea insasi cand tabelul `tbl` o are, altfel perechea din Era 1
-- (TycoonConfig.PAD_LOOKS_LIKE), pana la arta Morii.
local function lookOf(padId: string, tbl: { [string]: any }?): string
    if tbl ~= nil and tbl[padId] ~= nil then
        return padId
    end
    return TycoonConfig.PAD_LOOKS_LIKE[padId] or padId
end
PadArt.lookOf = lookOf

-- [D67] LANTUL DE IMPRUMUT: platforma, perechea ei din era dinainte, perechea aceleia (Era 3 -> Moara -> Era 1). Cat
-- arta unei ere nu e urcata, poarta desenul primei perechi care il are; fara lant, o platforma a Erei 3 ar fi cazut pe
-- perechea din Moara si apoi pe nimic (ramurile de mai jos stiu doar numele Erei 1).
local function borrowChain(padId: string): { string }
    local out = { padId }
    local id = TycoonConfig.PAD_LOOKS_LIKE[padId]
    while id ~= nil and #out < 4 do
        table.insert(out, id)
        id = TycoonConfig.PAD_LOOKS_LIKE[id]
    end
    return out
end
PadArt.borrowChain = borrowChain

function PadArt.isNet(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
end

-- [D67] TURBINA. Sta in larg ca o plasa (aceeasi platforma, acelasi stalp, acelasi nivel), dar nu prinde nimic din rau:
-- se invarte si umple baterii. Desenul ei (`turbine`), cat nu e urcat, e roata de apa a Morii ("bobine + roata", D64),
-- de doua ori marimea foii, ca sa stea cat o plasa in apa. Aici, ca satul (NetController) si satul vizitat din balci
-- (VillageDiorama) sa deseneze aceeasi turbina: [D67, audit] macheta o desena ca pe o plasa de pescuit.
PadArt.TURBINE_SCALE = 2
-- UMBRA unui obiect inca necumparat (PadController.buildGhost): intunecat si pe jumatate transparent. Aici, ca satul si
-- satul vizitat din balci sa aiba aceeasi umbra.
PadArt.GHOST_TINT = Color3.fromRGB(26, 32, 42)
PadArt.GHOST_FADE = 0.48
function PadArt.isTurbine(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" and e.good == "turbine" then
            return true
        end
    end
    return false
end
function PadArt.turbineSprite(): Assets.Sprite?
    local own = (Assets.tycoon :: any).turbine
    if own ~= nil and Assets.has(own) then
        return own
    end
    return if Assets.has(Assets.tycoon.water_wheel) then Assets.tycoon.water_wheel else nil
end

-- Ce sta pe banda din rau a unei platforme cu plasa, cat inca n-o ai: umbra obiectului (`ruined` false) sau ruina lui
-- (`ruined` true), cu marimea desenata. [D67, audit] Turbina aparea ca o plasa (rupta sau stinsa), apoi, la cumparare,
-- sarea deodata intr-o roata de alta forma. Acum e chiar turbina, in ambele stari, iar apelantul o deseneaza ca umbra
-- stinsa (regula owner-ului: ce e incuiat se vede el insusi, stins). Ruina rotii de apa nu merge aici: e desenata
-- pentru uscat, cu iarba si umbra.
function PadArt.laneArt(pad: TycoonConfig.Pad, ruined: boolean): (Assets.Sprite, number, number)
    if PadArt.isTurbine(pad) then
        local sprite = PadArt.turbineSprite()
        if sprite ~= nil then
            return sprite, sprite.width * PadArt.TURBINE_SCALE, sprite.height * PadArt.TURBINE_SCALE
        end
    end
    local sprite = if ruined then Assets.tycoon.ruin_net else Assets.tycoon.net_water
    return sprite, TycoonConfig.NET_DRAW.w, TycoonConfig.NET_DRAW.h
end

-- Banda plasei unei platforme (1 = cea mai aproape de mal).
function PadArt.laneOf(pad: TycoonConfig.Pad): number
    local lane = 1
    for _, e in pad.effects do
        if e.kind == "net" and e.lane ~= nil then
            lane = e.lane :: number
        end
    end
    return lane
end

-- Numele desenului de casa ales pentru platforma asta (si scara lui): cel mai mare urcat, pana la `count`. [D65] Intai
-- din casele platformei insesi, apoi din ale perechii din Era 1 (cat arta Morii nu e urcata).
local function homeSpriteName(padId: string, count: number): (string?, number)
    for _, id in borrowChain(padId) do
        local names = PadArt.HOME_SPRITES[id]
        if names ~= nil then
            for i = math.clamp(count, 1, #names), 1, -1 do
                local sprite = (Assets.tycoon :: any)[names[i]]
                if sprite ~= nil and Assets.has(sprite) then
                    return names[i], PadArt.HOME_SCALE[id] or Assets.PIXEL_SCALE
                end
            end
        end
    end
    return nil, Assets.PIXEL_SCALE
end

-- [D55] Casa omului, dupa cati sunt pe meserie: a doua treapta cand sunt doi. Arta lipsa cade pe prima.
function PadArt.home(padId: string, count: number): (Assets.Sprite?, number)
    local name, scale = homeSpriteName(padId, count)
    return if name ~= nil then (Assets.tycoon :: any)[name] else nil, scale
end

-- [D62, pasul 5] CLADIRILE LANTULUI, dupa nivel: `kind` e statia ("saw" gaterul, "dock" taverna, "forge" forja). De la
-- pragul 25 (ChainMath.isGrand) au a doua infatisare; cat desenul ei nu e urcat, ramane cladirea de azi. Depozitul si
-- magazia de scrap n-au niveluri, deci nici variante.
local GRAND: { [string]: string } =
    { saw = "sawmill_grand", dock = "tavern_grand", forge = "workshop_grand" }
function PadArt.station(kind: string, level: number?): Assets.Sprite
    local key = GRAND[kind]
    if key ~= nil and level ~= nil and ChainMath.isGrand(level) then
        local grand = (Assets.tycoon :: any)[key]
        if grand ~= nil and Assets.has(grand) then
            return grand
        end
    end
    if kind == "dock" then
        return Assets.tycoon.tavern
    elseif kind == "forge" then
        -- [D53] atelierul nou, in stilul tavernei; cel din era coloniei doar cat timp noul nu e urcat
        if Assets.has(Assets.tycoon.workshop_e1) then
            return Assets.tycoon.workshop_e1
        end
        return Assets.buildings.workshop
    end
    return Assets.tycoon.sawmill
end

-- Ce sta pe o platforma cumparata. Casele oamenilor vin din `home` [D55]; taraba a ramas a Negustorului cand Sorting
-- Crate si Dock Stall au devenit niveluri ale debarcaderului [E1.3]. `forgeLevel`: nivelul forjei, pentru desenul ei.
-- [D65] Cladirile Morii care stau pe platforme, cu arta lor (scripts/art/d65_mill.py); cat nu e urcata, mai jos.
local OWN_BUILT: { [string]: string } = {
    water_wheel = "water_wheel",
    copper_furnace = "copper_furnace",
    ore_shed = "ore_shed",
    mill_bell = "mill_bell",
    -- [D67] cladirile Wire Works care stau pe platforme (arta lor vine la pasul 7)
    steam_engine = "steam_engine",
    power_house = "power_house",
    battery_shed = "battery_shed",
    works_bell = "works_bell",
}
local OWN_RUIN: { [string]: string } = {
    water_wheel = "ruin_water_wheel",
    copper_furnace = "ruin_copper_furnace",
    ore_shed = "ruin_ore_shed",
    mill_bell = "ruin_mill_bell",
    steam_engine = "ruin_steam_engine",
    power_house = "ruin_power_house",
    battery_shed = "ruin_battery_shed",
    works_bell = "ruin_works_bell",
}

local function ownSprite(tbl: { [string]: string }, padId: string): Assets.Sprite?
    local key = tbl[padId]
    local sprite = if key ~= nil then (Assets.tycoon :: any)[key] else nil
    return if sprite ~= nil and Assets.has(sprite) then sprite else nil
end

function PadArt.bought(padId: string, count: number, forgeLevel: number?): (Assets.Sprite?, number)
    if PadArt.HOME_SPRITES[padId] ~= nil then
        return PadArt.home(padId, count) -- casa ei, sau a primei perechi care o are urcata
    end
    -- [D67] desenul ei, apoi al perechii din era dinainte (Moara pentru Era 3), cat al ei nu e urcat
    local chain = borrowChain(padId)
    for _, id in chain do
        local own = ownSprite(OWN_BUILT, id)
        if own ~= nil then
            return own, Assets.PIXEL_SCALE
        end
    end
    if padId == "water_wheel" then
        -- [D65] pana la arta ei: roata de la carma (tot o roata de lemn), ca locul sa se vada
        return Assets.tycoon.wheel, Assets.PIXEL_SCALE
    end
    padId = chain[#chain] -- perechea din Era 1, pentru ramurile de mai jos
    if PadArt.HOME_SPRITES[padId] ~= nil then
        return PadArt.home(padId, count)
    elseif padId == "scrap_shed" then
        return Assets.tycoon.scrap_shed, Assets.PIXEL_SCALE -- [D55]
    elseif padId == "bigger_sack" then
        return Assets.tycoon.sack, TycoonConfig.PROP_SCALE
    elseif padId == "landing_bell" then
        return Assets.tycoon.bell, Assets.PIXEL_SCALE
    elseif padId == "workshop" then
        return PadArt.station("forge", forgeLevel), Assets.PIXEL_SCALE
    end
    return nil, Assets.PIXEL_SCALE
end

-- [D53] Ruina de pe locul unei platforme necumparate.
function PadArt.ruin(padId: string): (Assets.Sprite?, number)
    local chain = borrowChain(padId)
    for _, id in chain do
        local own = ownSprite(OWN_RUIN, id)
        if own ~= nil then
            return own, Assets.PIXEL_SCALE
        end
    end
    if padId == "water_wheel" then
        return Assets.tycoon.ruin_hut, Assets.PIXEL_SCALE -- [D65] de imprumut, pana la arta ei
    end
    if PadArt.BOARD_ICON[padId] ~= nil then
        return Assets.tycoon.board_old, TycoonConfig.PROP_SCALE
    end
    padId = chain[#chain] -- perechea din Era 1, pentru ramurile de mai jos
    if PadArt.BOARD_ICON[padId] ~= nil then
        return Assets.tycoon.board_old, TycoonConfig.PROP_SCALE
    elseif padId == "first_runner" then
        return Assets.tycoon.ruin_hut, Assets.PIXEL_SCALE
    elseif padId == "dock_trader" then
        return Assets.tycoon.ruin_stall, TycoonConfig.PROP_SCALE
    elseif padId == "bigger_sack" then
        return Assets.tycoon.ruin_sack, TycoonConfig.PROP_SCALE
    elseif padId == "landing_bell" then
        return Assets.tycoon.ruin_bell, Assets.PIXEL_SCALE
    elseif padId == "workshop" then
        return Assets.tycoon.ruin_workshop, Assets.PIXEL_SCALE
    elseif padId == "scrap_shed" then
        return Assets.tycoon.ruin_scrap_shed, Assets.PIXEL_SCALE -- [D55]
    end
    return nil, 1
end

-- Are platforma asta arta de ruina urcata? Fara ea, raman siluetele de dinainte.
function PadArt.ruinReady(pad: TycoonConfig.Pad): boolean
    if PadArt.isNet(pad) then
        return Assets.has(Assets.tycoon.ruin_netpost) and Assets.has(Assets.tycoon.ruin_net)
    end
    local sprite = PadArt.ruin(pad.id)
    return sprite ~= nil and Assets.has(sprite :: Assets.Sprite)
end

-- [D62, pasul 5] PLASA PE RANGURI (ChainMath.rankOf: pragurile 10 / 25 / 50): flotoare rosii, apoi mai multe si ata mai
-- deasa, apoi aurii. `full` = varianta plina. O varianta inca neurcata cade pe rangul de sub ea, pana la plasa de azi.
function PadArt.netSprite(rank: number, full: boolean): Assets.Sprite
    for r = math.clamp(rank, 0, 3), 1, -1 do
        local key = if full then `net_water_r{r}_full` else `net_water_r{r}`
        local sprite = (Assets.tycoon :: any)[key]
        if sprite ~= nil and Assets.has(sprite) then
            return sprite
        end
    end
    if full and Assets.has(Assets.tycoon.net_water_full) then
        return Assets.tycoon.net_water_full
    end
    return Assets.tycoon.net_water
end

-- [D62, pasul 5] HORNURILE: unde iese fumul din casa unei meserii (fractiuni din desen), masurate pe foile de sprite.
-- Casele mici n-au horn; cele mari (doi oameni) au, deci fumul e si el un semn ca meseria a crescut.
PadArt.CHIMNEY = {
    hut_porter_2 = { 0.675, 0.03 },
    hut_sawyer_2 = { 0.25, 0.03 },
    hut_hauler_2 = { 0.75, 0.03 },
    hut_scrap_porter_2 = { 0.75, 0.03 },
    hut_smelter_1 = { 0.688, 0.04 },
    hut_smelter_2 = { 0.688, 0.03 },
    hut_iron_hauler_2 = { 0.275, 0.03 },
    -- [D65] casele Morii (scripts/art/d65_crew.py): hornul de caramida al Founder-ului, cel incins in cupru al
    -- Coppersmith-ului, hornurile caselor mari
    hut_mill_porter_2 = { 0.7625, 0.03 },
    hut_founder_1 = { 0.672, 0.03 },
    hut_founder_2 = { 0.6875, 0.03 },
    hut_parts_hauler_2 = { 0.275, 0.03 },
    hut_ore_porter_2 = { 0.75, 0.03 },
    hut_coppersmith_1 = { 0.672, 0.03 },
    hut_coppersmith_2 = { 0.6875, 0.03 },
    hut_copper_hauler_2 = { 0.275, 0.03 },
    -- [D67] casele Wire Works (scripts/art/d67_crew.py): hornul de fier (3 px, la x 21 / 26) al Wiredrawer-ului si al
    -- Electrician-ului, singurele cu horn
    hut_wiredrawer_1 = { 0.703, 0.03 },
    hut_wiredrawer_2 = { 0.6875, 0.03 },
    hut_electrician_1 = { 0.703, 0.03 },
    hut_electrician_2 = { 0.6875, 0.03 },
} :: { [string]: { number } }

-- Hornul casei desenate acum pentru platforma asta (dupa cati oameni are meseria), sau nil.
function PadArt.chimneyOf(padId: string, count: number): { number }?
    local name = homeSpriteName(padId, count)
    return if name ~= nil then PadArt.CHIMNEY[name] else nil
end

-- [D65] DESENE CARE NU STAU PE PLATFORMA LOR. Roata de apa se cumpara de pe punte (platforma ei e acolo, ca jucatorul
-- sa ajunga la ea), dar sta IN RAU: desenul si ruina ei urca pana cu baza la marginea de sus a puntii (platforma e la
-- y 812, puntea incepe la 772), altfel piciorul de piatra si spuma ar fi stat peste scanduri. `inWater` = fara umbra pe
-- pamant (o pata intunecata pe apa ar arata a defect).
PadArt.ART_OFFSET = {
    water_wheel = { y = -44, inWater = true },
} :: { [string]: { y: number, inWater: boolean } }

-- [D58] Numele de sub casa unei meserii, sau nil daca platforma nu e a unei meserii.
function PadArt.homeName(padId: string): string?
    local role = TycoonConfig.CREW_OF_PAD[padId]
    local crew = if role ~= nil then TycoonConfig.CREWS[role] else nil
    return if crew ~= nil then crew.name else nil
end

return PadArt
