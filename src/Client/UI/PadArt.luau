--!strict
-- [D61, partea 2] CE DESEN ARE O PLATFORMA: casa omului (mica sau mare), cladirea, ruina, avizierul. Pana la vizite,
-- listele astea traiau in PadController; satul vizitat din balci (VillageDiorama) deseneaza aceleasi platforme din
-- fotografia altui jucator, iar doua liste ar fi ajuns sa spuna lucruri diferite. Aici e doar alegerea desenului --
-- cumparatul, cartonasul si pulsul raman in PadController.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

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
} :: { [string]: { string } }
-- taraba ramane recuzita mica (x2); colibele sunt cladiri (x3)
PadArt.HOME_SCALE = { dock_trader = TycoonConfig.PROP_SCALE } :: { [string]: number }

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
} :: { [string]: () -> Assets.Sprite }

function PadArt.isNet(pad: TycoonConfig.Pad): boolean
    for _, e in pad.effects do
        if e.kind == "net" then
            return true
        end
    end
    return false
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

-- [D55] Casa omului, dupa cati sunt pe meserie: a doua treapta cand sunt doi. Arta lipsa cade pe prima.
function PadArt.home(padId: string, count: number): (Assets.Sprite?, number)
    local names = PadArt.HOME_SPRITES[padId]
    if names == nil then
        return nil, Assets.PIXEL_SCALE
    end
    local scale = PadArt.HOME_SCALE[padId] or Assets.PIXEL_SCALE
    for i = math.clamp(count, 1, #names), 1, -1 do
        local sprite = (Assets.tycoon :: any)[names[i]]
        if sprite ~= nil and Assets.has(sprite) then
            return sprite, scale
        end
    end
    return nil, scale
end

-- Ce sta pe o platforma cumparata. Casele oamenilor vin din `home` [D55]; taraba a ramas a Negustorului cand Sorting
-- Crate si Dock Stall au devenit niveluri ale debarcaderului [E1.3].
function PadArt.bought(padId: string, count: number): (Assets.Sprite?, number)
    if PadArt.HOME_SPRITES[padId] ~= nil then
        return PadArt.home(padId, count)
    elseif padId == "scrap_shed" then
        return Assets.tycoon.scrap_shed, Assets.PIXEL_SCALE -- [D55]
    elseif padId == "bigger_sack" then
        return Assets.tycoon.sack, TycoonConfig.PROP_SCALE
    elseif padId == "landing_bell" then
        return Assets.tycoon.bell, Assets.PIXEL_SCALE
    elseif padId == "workshop" then
        -- [D53] atelierul nou, in stilul tavernei; cel din era coloniei doar cat timp noul nu e urcat
        if Assets.has(Assets.tycoon.workshop_e1) then
            return Assets.tycoon.workshop_e1, Assets.PIXEL_SCALE
        end
        return Assets.buildings.workshop, Assets.PIXEL_SCALE
    end
    return nil, Assets.PIXEL_SCALE
end

-- [D53] Ruina de pe locul unei platforme necumparate.
function PadArt.ruin(padId: string): (Assets.Sprite?, number)
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

-- [D58] Numele de sub casa unei meserii, sau nil daca platforma nu e a unei meserii.
function PadArt.homeName(padId: string): string?
    local role = TycoonConfig.CREW_OF_PAD[padId]
    local crew = if role ~= nil then TycoonConfig.CREWS[role] else nil
    return if crew ~= nil then crew.name else nil
end

return PadArt
