--!strict
-- [D70, pasul j12] STAREA LANTULUI DIN PROFIL, pura (pana acum StationService.StateFrom, pe server). O citesc serverul
-- (cu modelul jocului) si testele (cu oricare model: profilurile de aur ale Erelor 1-3 si startul barajului, sub FULL).
-- `bought` e parametru, nu `data.Pads`, ca sa se poata intreba si „cum ar arata DACA as cumpara platforma asta”: de acolo
-- vin deltele de pe fantome, cu exact aceeasi formula ca venitul real [D40].
local ChainMath = require(script and script.Parent.ChainMath or "./ChainMath")
local CrewMath = require(script and script.Parent.CrewMath or "./CrewMath")
local PassMath = require(script and script.Parent.PassMath or "./PassMath")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")

local ChainState = {}

-- Plasele, in ordinea din PADS, cu banda si felul lor; baza vine din rang (ChainMath.netIdentity).
local netPadIds: { string } = {}
local netPadLane: { [string]: number } = {}
local netPadKind: { [string]: string } = {}
for _, p in TycoonConfig.PADS do
    for _, e in p.effects do
        if e.kind == "net" then
            table.insert(netPadIds, p.id)
            netPadLane[p.id] = e.lane or 1
            netPadKind[p.id] = TycoonMath.netKind(p)
            break
        end
    end
end
ChainState.NET_PAD_IDS = netPadIds

-- Cate obiecte din catalog are jucatorul (Index): intra in TycoonMath.stateFor.
function ChainState.indexCount(data: any): number
    local n = 0
    for _ in data.Index or {} do
        n += 1
    end
    return n
end

-- Starea lantului unui profil, sub modelul `m` (fara el, al jocului).
function ChainState.from(
    data: any,
    bought: { [string]: boolean },
    m: ChainMath.Model?
): ChainMath.State
    local model = m or ChainMath.GAME
    local s = ChainMath.empty(m)
    local st = data.Stations
    for _, padId in netPadIds do
        if bought[padId] ~= true then
            continue
        end
        local entry = st.nets[padId]
        local net = ChainMath.netIdentity(padId) :: ChainMath.NetIdentity
        table.insert(s.nets, {
            base = ChainMath.netBaseRank(net.rank),
            baseLane = netPadLane[padId] or 1,
            level = if entry ~= nil then entry.level else 1,
            kind = netPadKind[padId] or "wood",
        })
    end
    -- Nivelul fiecarei cladiri a modelului, in campul numit de tabelul liniilor (saw -> sawLevel). `or 1`: o stare
    -- construita dintr-un profil necompletat nu are voie sa crape pe aritmetica cu nil.
    local fields: any = s
    for _, kinds in { model.processors, model.sellers } do
        for kind in kinds :: { [string]: any } do
            local field = ChainMath.levelField(kind)
            local entry = st[kind]
            if field ~= nil then
                fields[field] = if typeof(entry) == "table" then entry.level or 1 else 1
            end
        end
    end
    -- [D55, D56, D65, D67] fiecare linie cu conditie: steagul ei il ridica platforma atelierului ei (FlowConfig) -- Forge,
    -- roata de apa, cuptorul de cupru, masina cu abur, Power House, [D70] Kiln-ul. Steagul barajului vine din lume (R5):
    -- butoaiele, cablul si unirea n-au platforma, sunt acolo de la baraj.
    for _, line in model.lineOrder do
        local flag = StationConfig.LINES[line].openFlag
        if flag ~= nil and flag ~= "dam" then
            fields[flag] = bought[FlowConfig.LINES_ALL[line].processorPad or ""] == true
        end
    end
    s.dam = WorldConfig.sanitize(data.World) >= 2 -- [verificatorul j6] din lumea curatata
    -- OAMENII [D49]: cati sunt se numara din `data.Hands` (dupa rol), treapta vine din `data.Crews`. O platforma de
    -- meserie din `bought` fara om inca (intrebarea "daca as cumpara-o") numara un om: altfel cartonasul de la apropiere
    -- ar arata castig zero pe fiecare angajare.
    -- [D70] doar meseriile lumii jucatorului: la baraj, platformele satului vechi sunt tot ale lui, dar oamenii lor au
    -- iesit din lucru (sau lucreaza pe meseriile barajului)
    local world = WorldConfig.sanitize(data.World)
    s.crews = CrewMath.fromProfile(data.Hands, data.Crews, m)
    for role, crew in s.crews do
        local def = TycoonConfig.CREWS[role]
        local ofWorld = WorldConfig.worldOfEra(StationConfig.ERA_OF_ROLE[role] or 1) == world
        if crew.count == 0 and def ~= nil and bought[def.pad] == true and ofWorld then
            crew.count = 1
        end
    end
    -- Multiplicatorii raman de unde erau: sunt efecte de platforma, nu niveluri de statie.
    local old = TycoonMath.stateFor(bought, data.Rebirths, ChainState.indexCount(data))
    s.sackBig = old.sackBig
    -- [D61, partea 2] pass-ul 2x Flow, ca in PadService.StateFor: de aici ies TOATE cifrele afisate (venitul de pe HUD,
    -- idle si offline, deltele platformelor, "+N coins a minute"), deci se dubleaza toate, la fel
    s.priceMult = old.priceMult * PassMath.flowFactor(data)
    s.bells = old.bells
    s.indexFound = old.indexFound
    s.rebirths = old.rebirths
    return s
end

return ChainState
