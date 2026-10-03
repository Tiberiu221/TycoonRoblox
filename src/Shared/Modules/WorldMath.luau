--!strict
-- [D70, pasul j10] CE SE POATE FACE IN FIECARE LUME. Modul pur, citit de server la fiecare cerere a jucatorului (platforme,
-- niveluri, oameni, locuri, plase): un lucru al altei harti se refuza cu motiv (`closed`), nu in tacere [D43]. Aici vine,
-- la pasul j14, si trecerea in lumea 2 (`buildDam`).
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")

local WorldMath = {}

-- Lucrul unei ere se poate folosi in lumea `world`? Lumea vine curatata (WorldConfig.sanitize), era necunoscuta (nil)
-- nu e a niciunei harti anume: hotarasc serviciile, ca pana acum.
function WorldMath.allowed(world: any, era: number?): boolean
    if era == nil then
        return true
    end
    return WorldConfig.worldOfEra(era) == WorldConfig.sanitize(world)
end

-- Era fiecarei cladiri cu niveluri (atelierul unei linii, vanzatorul) si a fiecarui loc (magazie, atelier, iesire,
-- vanzator), din toate liniile scrise.
local eraOfStation: { [string]: number } = {}
local eraOfPlace: { [string]: number } = {}
for _, spec in FlowConfig.LINES_ALL do
    eraOfStation[spec.station] = spec.era
    if spec.store ~= nil then
        eraOfPlace[spec.store :: string] = spec.era
    end
    eraOfPlace[spec.processor] = spec.era
    eraOfPlace[spec.output] = spec.era
end
for _, spec in FlowConfig.SELLERS_ALL do
    eraOfStation[spec.station] = spec.era
    eraOfPlace[spec.seller] = spec.era
end

-- Era unei cladiri cu niveluri: `kind` din StationService (o plasa: dupa platforma ei, `id`).
function WorldMath.eraOfStation(kind: string, id: string?): number?
    if kind == "net" then
        local pad = if id ~= nil then TycoonConfig.byId[id] else nil
        return if pad ~= nil then pad.era else nil
    end
    return eraOfStation[kind]
end

-- Era unui loc din FlowConfig (UsePlace, AtPlace).
function WorldMath.eraOfPlace(place: string): number?
    return eraOfPlace[place]
end

-- Era unei meserii.
function WorldMath.eraOfRole(role: string): number?
    return StationConfig.ERA_OF_ROLE[role]
end

-- [D67] Clopotul care deschide zona fiecarei ere: platforma cu motivul "D" a erei dinainte (Landing Bell -> The Mill,
-- Mill Bell -> The Wire Works, Works Bell -> The Dam, Dam Bell -> ceata Erei 5).
local zoneBell: { [number]: string } = {}
for _, p in TycoonConfig.PADS do
    if p.motive == "D" then
        zoneBell[p.era + 1] = p.id
    end
end

-- [D70, pasul j10] Zonele LUMII jucatorului: "open" | "locked". Prima zona a unei lumi e deschisa (Landing in sat, Dam
-- Town la baraj); celelalte, cu clopotul erei dinainte. O zona a altei lumi (zona barajului din sat) ramane incuiata cat
-- era ei e in joc: barajul se ridica pe alta harta. Pana atunci se deschide cu clopotul, ca azi, si scrie „coming soon”.
-- `pads`: statusurile platformelor (PadService.Statuses); `eraIsLive`: cine e in joc (testele il dau).
function WorldMath.zoneStatuses(
    world: any,
    pads: { [string]: string },
    eraIsLive: ((number) -> boolean)?
): { [string]: string }
    local w = WorldConfig.sanitize(world)
    local live = eraIsLive or TycoonConfig.eraIsLive
    local out: { [string]: string } = {}
    for _, zone in TycoonConfig.zonesOf(w) do
        local bell = zoneBell[zone.era]
        local open = zone.era == WorldConfig.FIRST_ERA[w]
            or (bell ~= nil and pads[bell] == "bought")
        if WorldConfig.worldOfEra(zone.era) ~= w and live(zone.era) then
            open = false
        end
        out[zone.id] = if open then "open" else "locked"
    end
    return out
end

return WorldMath
