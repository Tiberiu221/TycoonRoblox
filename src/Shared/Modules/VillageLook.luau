--!strict
-- [D61, partea 2] CUM ARATA UN SAT, scos din profilul lui. Modul pur.
--
-- La poarta satelor din balci vizitezi satul altui jucator ca FOTOGRAFIE: serverul balciului are profilul gazdei
-- incarcat (e si ea acolo), iar de aici iese doar ce se VEDE -- platformele cumparate, nivelurile plaselor si ale
-- cladirilor, oamenii (meseria, al catelea, treapta, infatisarea, ce duc), decorul, Era. Nicio moneda, nicio gramada,
-- niciun quest: nimic din economia nimanui nu trece pe aici, deci o greseala in vizite nu poate costa progres.
--
-- `hands` e aceeasi lista pe care o trimite satul clientului (HandService.Snapshot o ia tot de aici), ca oamenii din
-- fotografie sa mearga pe aceleasi drumuri ca acasa (HandRoutes, din aceleasi argumente).
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local VillageConfig =
    require(script and script.Parent.Parent.Config.VillageConfig or "../Config/VillageConfig")
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local CrewMath = require(script and script.Parent.CrewMath or "./CrewMath")
local HandRoutes = require(script and script.Parent.HandRoutes or "./HandRoutes")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")
local HandConfig =
    require(script and script.Parent.Parent.Config.HandConfig or "../Config/HandConfig")

local VillageLook = {}

-- Infatisarea unui om, cu tinuta ROLULUI lui (HandConfig.ROLE_OUTFIT). O copie: profilul nu se atinge.
local function dressed(appearance: any, role: string): any
    if typeof(appearance) ~= "table" then
        return appearance
    end
    local copy = table.clone(appearance)
    copy.outfit = HandConfig.ROLE_OUTFIT[role] or copy.outfit
    return copy
end

export type HandSnap = {
    id: string,
    role: string,
    name: string,
    index: number,
    count: number,
    tier: number,
    nets: { string },
    cycleStartAt: number,
    carrying: number,
    carryKind: string?,
    capacity: number,
    appearance: any,
    x: number?,
    y: number?,
}

export type Snapshot = {
    era: number,
    pads: { [string]: boolean }, -- platformele cumparate care au loc pe harta
    netLevels: { [string]: number },
    stations: { saw: number, dock: number, forge: number },
    crews: { [string]: number }, -- meseria -> cati oameni (coliba mica sau mare)
    tiers: { [string]: number }, -- [D62] meseria -> treapta (bulinele de sub numele casei)
    hands: { HandSnap },
    decor: { [string]: boolean },
    decorCount: number,
    power: boolean, -- [D67, audit] gazda a vandut deja curent: felinarele strazii ei ard (ca DataService.Firsts.power)
}

local function netEffectOf(pad: TycoonConfig.Pad): number?
    for _, e in pad.effects do
        if e.kind == "net" then
            return e.rate
        end
    end
    return nil
end

-- Plasele DETINUTE, in ordinea platformelor -- intrarea pe care o cere HandRoutes.
function VillageLook.ownedNets(pads: { [string]: boolean }): { string }
    local ids: { string } = {}
    for _, p in TycoonConfig.PADS do
        if pads[p.id] and netEffectOf(p) ~= nil then
            table.insert(ids, p.id)
        end
    end
    return ids
end

-- [D55] Ce se vede in roaba: felul cu cele mai multe bucati, la egalitate cel dinainte in GOODS.
local GOOD_ORDER: { [string]: number } = {}
for i, g in TycoonConfig.GOODS do
    GOOD_ORDER[g.id] = i
end
function VillageLook.carryKind(items: { { g: string } }): string?
    local counts: { [string]: number } = {}
    local best: string? = nil
    for _, item in items do
        counts[item.g] = (counts[item.g] or 0) + 1
    end
    for good, n in counts do
        local b = best
        if
            b == nil
            or n > counts[b]
            or (n == counts[b] and (GOOD_ORDER[good] or 99) < (GOOD_ORDER[b] or 99))
        then
            best = good
        end
    end
    return best
end

-- Oamenii, cum ii deseneaza clientul: drumul se reface din (meserie, al catelea, cati, plase), ceasul din
-- `cycleStartAt`; cei care stau pe loc au doar locul lor.
function VillageLook.hands(data: { [string]: any }): { HandSnap }
    local result: { HandSnap } = {}
    local hands = data.Hands
    if typeof(hands) ~= "table" then
        return result
    end
    local nets = VillageLook.ownedNets(data.Pads or {})
    local crews = CrewMath.fromProfile(hands, data.Crews)
    for id, hand in hands do
        local crew = crews[hand.role] or { count = 0, tier = 1 }
        local index = CrewMath.indexOf(id)
        local walker = HandRoutes.isWalker(hand.role)
        local stand = HandRoutes.standFor(hand.role, index)
        local capacity = 0
        if walker then
            local cycle = HandRoutes.cycleFor(hand.role, index, crew.count, nets)
            capacity = HandRoutes.loadFor(ChainMath.walkerRate(hand.role, crew), cycle.duration)
        end
        table.insert(result, {
            id = id,
            role = hand.role,
            name = hand.name,
            index = index,
            count = crew.count,
            tier = crew.tier,
            nets = if walker then nets else {},
            cycleStartAt = hand.cycleStartAt,
            carrying = #hand.carry,
            carryKind = VillageLook.carryKind(hand.carry), -- [D55] ce se vede in roaba
            capacity = capacity,
            -- [D65] tinuta vine din ROL, nu din ce s-a salvat la angajare: cand meseria isi primeste tinuta ei (oamenii
            -- Morii au purtat-o pe a perechii din Era 1), o poarta si cei angajati deja [D44: rolul isi poarta tinuta]
            appearance = dressed(hand.appearance, hand.role),
            x = if stand ~= nil then stand.x else nil,
            y = if stand ~= nil then stand.y else nil,
        })
    end
    return result
end

-- Cate decoruri are satul (doar cele din catalog: o cheie ratacita in profil nu se numara).
function VillageLook.decorCount(data: { [string]: any }): number
    local village = data.Village
    local owned = if typeof(village) == "table" then village.decor else nil
    local n = 0
    if typeof(owned) == "table" then
        for _, decor in VillageConfig.DECOR do
            if owned[decor.id] == true then
                n += 1
            end
        end
    end
    return n
end

local function levelOf(station: any): number
    if typeof(station) == "table" and typeof(station.level) == "number" then
        local level = station.level :: number
        if level == level then
            return math.max(1, math.floor(level))
        end
    end
    return 1
end

-- Fotografia. Doar chei din config: nimic din profil nu ajunge la alt jucator decat ce e desenabil.
function VillageLook.of(data: { [string]: any }): Snapshot
    local bought: { [string]: boolean } = if typeof(data.Pads) == "table" then data.Pads else {}
    local stations: any = if typeof(data.Stations) == "table" then data.Stations else {}
    local netStations: any = if typeof(stations.nets) == "table" then stations.nets else {}
    local pads: { [string]: boolean } = {}
    local netLevels: { [string]: number } = {}
    for _, p in TycoonConfig.PADS do
        if bought[p.id] == true and p.x ~= nil and p.y ~= nil then
            pads[p.id] = true
            if netEffectOf(p) ~= nil then
                netLevels[p.id] = levelOf(netStations[p.id])
            end
        end
    end
    local crews: { [string]: number } = {}
    local tiers: { [string]: number } = {}
    if typeof(data.Hands) == "table" then
        for role, crew in CrewMath.fromProfile(data.Hands, data.Crews) do
            if crew.count > 0 then
                crews[role] = crew.count
                tiers[role] = crew.tier
            end
        end
    end
    local decor: { [string]: boolean } = {}
    local village = data.Village
    local owned = if typeof(village) == "table" then village.decor else nil
    if typeof(owned) == "table" then
        for _, d in VillageConfig.DECOR do
            if owned[d.id] == true then
                decor[d.id] = true
            end
        end
    end
    return {
        era = TycoonMath.era(bought),
        pads = pads,
        netLevels = netLevels,
        stations = {
            saw = levelOf(stations.saw),
            dock = levelOf(stations.dock),
            forge = levelOf(stations.forge),
        },
        crews = crews,
        tiers = tiers,
        hands = VillageLook.hands(data),
        decor = decor,
        decorCount = VillageLook.decorCount(data),
        power = typeof(data.Stats) == "table" and (tonumber(data.Stats.cellsSold) or 0) > 0,
    }
end

return VillageLook
