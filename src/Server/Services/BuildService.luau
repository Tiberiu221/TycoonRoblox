--!strict
-- Cladirile asezarii: plasare validata pe server, construite in timp de colonisti [RIVERKEEP 4.3]
-- Sursa de adevar sta in profilul administratorului (D14), ca sa persiste intre sesiuni.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildingConfig = require(ReplicatedStorage.Shared.Config.BuildingConfig)
local Grid = require(ReplicatedStorage.Shared.Modules.Grid)
local RiverConfig = require(ReplicatedStorage.Shared.Config.RiverConfig)
local DataService = require(script.Parent.DataService)

export type Placed = {
    id: number,
    defId: string,
    x: number,
    y: number,
    progress: number, -- 0..buildWork; complet cand progress >= buildWork
}

local BuildService = {}
local map: Grid.Map
local deps: { Remotes: { [string]: RemoteEvent } }

local function owner(): (Player?, DataService.ProfileData?)
    for _, player in Players:GetPlayers() do
        local data = DataService.Get(player)
        if data ~= nil then
            return player, data
        end
    end
    return nil, nil
end

function BuildService.All(): { Placed }
    local _, data = owner()
    if data == nil then
        return {}
    end
    local out: { Placed } = {}
    for _, b in data.Buildings do
        table.insert(out, b)
    end
    table.sort(out, function(a, b)
        return a.id < b.id
    end)
    return out
end

function BuildService.IsComplete(b: Placed): boolean
    local d = BuildingConfig.get(b.defId)
    return d ~= nil and b.progress >= d.buildWork
end

-- Cladirile terminate, de tipul cerut (folosit de colonisti)
function BuildService.CompletedOfKind(kind: string): { { [string]: any } }
    local out = {}
    for _, b in BuildService.All() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and d.kind == kind and BuildService.IsComplete(b) then
            table.insert(out, {
                id = tostring(b.id),
                x = b.x,
                y = b.y,
                w = d.w * RiverConfig.TILE,
                h = d.h * RiverConfig.TILE,
                kind = d.kind,
                slots = d.slots,
            })
        end
    end
    return out
end

-- Santierele neterminate, pentru constructori
function BuildService.Sites(): { { [string]: any } }
    local out = {}
    for _, b in BuildService.All() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and b.progress < d.buildWork then
            table.insert(out, {
                id = tostring(b.id),
                x = b.x,
                y = b.y,
                w = d.w * RiverConfig.TILE,
                h = d.h * RiverConfig.TILE,
                kind = "site",
                slots = 4,
            })
        end
    end
    return out
end

function BuildService.Beds(): number
    local total = 0
    for _, b in BuildService.All() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and BuildService.IsComplete(b) then
            total += d.beds
        end
    end
    return total
end

local function rebuildGrid()
    if map == nil then
        return
    end
    table.clear(map.blocked)
    Grid.blockWorldRect(
        map,
        0,
        RiverConfig.RIVER_TOP,
        RiverConfig.WORLD_WIDTH,
        RiverConfig.RIVER_BOTTOM - RiverConfig.RIVER_TOP
    )
    for _, b in BuildService.All() do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil then
            Grid.blockWorldRect(map, b.x, b.y, d.w * RiverConfig.TILE, d.h * RiverConfig.TILE)
        end
    end
end

-- Trimite starea unui singur jucator (la cerere, ca sa nu se piarda mesajul initial)
function BuildService.SendTo(player: Player)
    if deps == nil then
        return
    end
    deps.Remotes.BuildingsState:FireClient(player, BuildService.All(), BuildService.Beds())
end

local function broadcast()
    if deps == nil then
        return
    end
    for _, player in Players:GetPlayers() do
        deps.Remotes.BuildingsState:FireClient(player, BuildService.All(), BuildService.Beds())
    end
end

-- Se poate pune aici? (in lume, pe uscat, fara suprapunere, nu peste raul sau personaj)
function BuildService.CanPlace(defId: string, x: number, y: number): (boolean, string)
    local d = BuildingConfig.get(defId)
    if d == nil then
        return false, "unknown_building"
    end
    local w, h = d.w * RiverConfig.TILE, d.h * RiverConfig.TILE
    if x < 0 or y < 0 or x + w > RiverConfig.WORLD_WIDTH or y + h > RiverConfig.WORLD_HEIGHT then
        return false, "outside_world"
    end
    -- raul si malul imediat sunt interzise
    if
        y + h > RiverConfig.RIVER_TOP - RiverConfig.TILE
        and y < RiverConfig.RIVER_BOTTOM + RiverConfig.TILE
    then
        return false, "too_close_to_river"
    end
    -- Terenul luminat e o LIMITA, nu o sugestie. Indiciul spune "aseaz-o pe pamantul luminat";
    -- daca poti construi si in afara lui, textul minte si conturul nu inseamna nimic.
    local plot = RiverConfig.PLOT
    if x < plot.x or y < plot.y or x + w > plot.x + plot.w or y + h > plot.y + plot.h then
        return false, "outside_plot"
    end
    for _, b in BuildService.All() do
        local od = BuildingConfig.get(b.defId)
        if od == nil then
            continue
        end
        local ow, oh = od.w * RiverConfig.TILE, od.h * RiverConfig.TILE
        if x < b.x + ow and x + w > b.x and y < b.y + oh and y + h > b.y then
            return false, "overlaps"
        end
    end
    return true, "ok"
end

function BuildService.Place(player: Player, defId: string, x: number, y: number): (boolean, string)
    local data = DataService.Get(player)
    if data == nil then
        return false, "no_profile"
    end
    local d = BuildingConfig.get(defId)
    if d == nil then
        return false, "unknown_building"
    end
    -- aliniere pe grila: nu lasam cladiri intre celule
    x = math.floor(x / RiverConfig.TILE) * RiverConfig.TILE
    y = math.floor(y / RiverConfig.TILE) * RiverConfig.TILE
    local ok, reason = BuildService.CanPlace(defId, x, y)
    if not ok then
        return false, reason
    end
    if data.Materials < d.cost then
        return false, "not_enough_materials"
    end
    data.Materials -= d.cost
    data.Stats.buildsPlaced = (data.Stats.buildsPlaced or 0) + 1 -- pentru lantul de obiective
    local id = data.NextBuildingId
    data.NextBuildingId += 1
    data.Buildings[tostring(id)] = { id = id, defId = defId, x = x, y = y, progress = 0 }
    rebuildGrid()
    broadcast()
    return true, "ok"
end

-- O unitate de munca a unui constructor pe cel mai avansat santier
function BuildService.BuilderWork(points: number): boolean
    local _, data = owner()
    if data == nil then
        return false
    end
    local best: Placed? = nil
    for _, b in data.Buildings do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and b.progress < d.buildWork then
            if best == nil or b.progress > best.progress then
                best = b
            end
        end
    end
    if best == nil then
        return false
    end
    local d = BuildingConfig.get(best.defId) :: BuildingConfig.Def
    best.progress = math.min(d.buildWork, best.progress + points)
    if best.progress >= d.buildWork then
        rebuildGrid()
        data.Stats.buildsFinished = (data.Stats.buildsFinished or 0) + 1
        local player = owner()
        if player ~= nil and deps ~= nil then
            deps.Remotes.BuildingDone:FireClient(player, d.label)
        end
    end
    broadcast()
    return true
end

-- Termina instant toate santierele. Unealta de dezvoltare: altfel astepti constructorii.
function BuildService.FinishAllSites(): number
    local player, data = owner()
    if data == nil then
        return 0
    end
    local finished = 0
    for _, b in data.Buildings do
        local d = BuildingConfig.get(b.defId)
        if d ~= nil and b.progress < d.buildWork then
            b.progress = d.buildWork
            data.Stats.buildsFinished = (data.Stats.buildsFinished or 0) + 1
            finished += 1
            if player ~= nil and deps ~= nil then
                deps.Remotes.BuildingDone:FireClient(player, d.label)
            end
        end
    end
    if finished > 0 then
        rebuildGrid()
        broadcast()
    end
    return finished
end

-- Sterge tot ce s-a construit si pune la loc cladirile de start. Unealta de dezvoltare.
function BuildService.ResetToStarter(): number
    local _, data = owner()
    if data == nil then
        return 0
    end
    table.clear(data.Buildings)
    data.NextBuildingId = 1
    for _, starter in BuildingConfig.STARTER do
        local d = BuildingConfig.get(starter.defId)
        if d ~= nil then
            local id = data.NextBuildingId
            data.NextBuildingId += 1
            data.Buildings[tostring(id)] = {
                id = id,
                defId = starter.defId,
                x = starter.x,
                y = starter.y,
                progress = d.buildWork,
            }
        end
    end
    rebuildGrid()
    broadcast()
    return data.NextBuildingId - 1
end

function BuildService.HasSites(): boolean
    return #BuildService.Sites() > 0
end

function BuildService.Grid(): Grid.Map
    return map
end

function BuildService.Init(d: typeof(deps) & { Map: Grid.Map })
    deps = d
    map = d.Map

    DataService.ProfileLoaded:Connect(function(player: Player)
        local data = DataService.Get(player)
        if data == nil then
            return
        end
        -- profil salvat inainte de sistemul de cladiri: completeaza campurile lipsa
        if data.Buildings == nil then
            data.Buildings = {}
        end
        if data.NextBuildingId == nil then
            data.NextBuildingId = 1
        end
        -- prima intrare: asezarea de start
        if next(data.Buildings) == nil then
            for _, s in BuildingConfig.STARTER do
                local def = BuildingConfig.get(s.defId)
                if def ~= nil then
                    local id = data.NextBuildingId
                    data.NextBuildingId += 1
                    data.Buildings[tostring(id)] =
                        { id = id, defId = s.defId, x = s.x, y = s.y, progress = def.buildWork }
                end
            end
        end
        print(
            `[Driftwood] profil incarcat: {#BuildService.All()} cladiri, {BuildService.Beds()} paturi`
        )
        rebuildGrid()
        BuildService.SendTo(player)
        broadcast()
    end)
end

return BuildService
