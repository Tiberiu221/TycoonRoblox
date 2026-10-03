--!strict
-- [D70, pasul j10] CE SE POATE FACE IN FIECARE LUME. Modul pur, citit de server la fiecare cerere a jucatorului (platforme,
-- niveluri, oameni, locuri, plase): un lucru al altei harti se refuza cu motiv (`closed`), nu in tacere [D43]. Trecerea
-- in lumea 2 („Build the Dam”) nu sta aici, ci in DamMath (pasul j14).
local FlowConfig =
    require(script and script.Parent.Parent.Config.FlowConfig or "../Config/FlowConfig")
local StationConfig =
    require(script and script.Parent.Parent.Config.StationConfig or "../Config/StationConfig")
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local TycoonMath = require(script and script.Parent.TycoonMath or "./TycoonMath")
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

-- [D70, verificatorul j10] Clopotul pe care un jucator din `world` il asteapta inaintea erei `era`: nimic pentru prima era a
-- lumii lui (Dam Town n-asteapta Works Bell-ul sunat in satul vechi), altfel clopotul erei dinainte. Din sat, zona
-- barajului asteapta tot Works Bell. Il citesc zonele, iar pe client (pasul k2) ruinele si gardul.
function WorldMath.bellBefore(era: number, world: any): TycoonConfig.Pad?
    if era == WorldConfig.FIRST_ERA[WorldConfig.sanitize(world)] then
        return nil
    end
    local id = zoneBell[era]
    return if id ~= nil then TycoonConfig.byId[id] else nil
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
        local bell = WorldMath.bellBefore(zone.era, w)
        local open = if bell == nil
            then zone.era == WorldConfig.FIRST_ERA[w]
            else pads[bell.id] == "bought"
        if WorldConfig.worldOfEra(zone.era) ~= w and live(zone.era) then
            open = false
        end
        out[zone.id] = if open then "open" else "locked"
    end
    return out
end

-- [D70, pasul k2] CE SCRIE RUINA UNEI PLATFORME (cartonasul de langa ea, tasta E): intai clopotul erei dinainte, pe harta
-- ta (prima era a unei lumi n-asteapta nimic), apoi conditia ei (TycoonMath.padBlocker, pe lista hartii, cu venitul si 2x
-- Flow, ca serverul). nil = nimic de facut intai. `statuses`: statusurile de la server (doar ale hartii tale).
function WorldMath.ruinNeeds(
    pad: TycoonConfig.Pad,
    statuses: { [string]: string },
    world: any,
    levels: { [string]: number }?,
    income: number?,
    flowFactor: number?
): string?
    local bell = WorldMath.bellBefore(pad.era, world)
    if bell ~= nil and statuses[bell.id] ~= "bought" then
        return Strings.refuseZoneLocked(bell.name)
    end
    local bought: { [string]: boolean } = {}
    for id, status in statuses do
        if status == "bought" then
            bought[id] = true
        end
    end
    local blocker = TycoonMath.padBlocker(
        pad,
        bought,
        levels,
        TycoonConfig.padsOfWorld(world),
        income,
        flowFactor
    )
    return if blocker ~= nil then Strings.padNeeds(blocker) else nil
end

-- [D70, verificatorul j10] CE SCRIE O ZONA: panoul de la gardul ei (ZoneController) si textul care pluteste cand te apropii
-- de gard (Overlay). O singura regula, ca cele doua sa nu se contrazica [D40]:
--   * zona altei harti (barajul din sat): cat era ei nu e in joc, "coming soon" (D73); dupa, unde se ridica, fara clopot;
--     [pasul k6] iar cand se poate ridica acum (`ready`, serverul: damAvailable), de unde: masa Dam Plans;
--   * o era care nu e inca in joc: "coming soon", deschisa sau inchisa;
--   * inchisa: clopotul care o deschide; deschisa si facuta: nimic (panoul dispare).
-- `world` e lumea jucatorului (pe client, din pasul k1; azi satul); `eraIsLive` il dau testele.
local function zoneText(
    zone: TycoonConfig.Zone,
    open: boolean,
    world: any,
    eraIsLive: ((number) -> boolean)?,
    lockedText: (string) -> string,
    ready: boolean?
): string
    local live = eraIsLive or TycoonConfig.eraIsLive
    local w = WorldConfig.sanitize(world)
    if WorldConfig.worldOfEra(zone.era) ~= w and live(zone.era) then
        return if ready == true then Strings.zoneBuildAt(zone.name) else Strings.zoneAway(zone.name)
    end
    if not live(zone.era) then
        return zone.soon or Strings.zoneSoon(zone.name)
    end
    if open then
        return ""
    end
    local bell = WorldMath.bellBefore(zone.era, w)
    return lockedText(if bell ~= nil then bell.name else "next Bell")
end

-- Panoul zonei; "" = fara panou.
function WorldMath.zoneSign(
    zone: TycoonConfig.Zone,
    status: string?,
    world: any,
    eraIsLive: ((number) -> boolean)?,
    ready: boolean? -- [D70, pasul k6] barajul se poate ridica acum
): string
    return zoneText(zone, status == "open", world, eraIsLive, function(bell: string): string
        return Strings.zoneLocked(zone.name, bell)
    end, ready)
end

-- Textul de la gardul unei zone inchise, cand te apropii.
function WorldMath.fenceText(
    zone: TycoonConfig.Zone,
    world: any,
    eraIsLive: ((number) -> boolean)?,
    ready: boolean? -- [D70, pasul k6]
): string
    return zoneText(zone, false, world, eraIsLive, Strings.refuseZoneLocked, ready)
end

return WorldMath
