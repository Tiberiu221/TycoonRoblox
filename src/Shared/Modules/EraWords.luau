--!strict
-- [2026-09-30] CE SPUNE UN ECHIPAJ AJUNS LA MAXIM PE VERIGA SLABA (2 oameni, treapta 5): nimic de cumparat la el, deci
-- trimite mai departe. Pur, folosit de meniul meseriei si de panoul Upgrades, ca amandoua sa spuna la fel.
--   * clopotul erei lui nu e tras: "ring the {bell}";
--   * e tras: frontiera, adica prima era din joc de dupa a lui cu clopotul netras ("build up The Wire Works"). Nu era de
--     alaturi: dupa Works Bell, cei din Landing trimiteau la Moara, apoi Moara la Wire Works, toate la plafon;
--   * toate clopotele erelor din joc sunt trase: era care vine ("more comes with The Dam"), altfel nimic.
-- "Clopotul tras nu mai e un pas urmator" [D40]: inainte, meniul trimitea la un clopot deja sunat.
local Strings = require(script and script.Parent.Parent.Config.Strings or "../Config/Strings")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")

local EraWords = {}

local function bellOf(era: number): TycoonConfig.Pad?
    for _, p in TycoonConfig.PADS do
        if p.era == era and p.motive == "D" then
            return p
        end
    end
    return nil
end

-- `padId` = platforma meseriei (rândul ei din meniu); `isBought(padId)` = platforma e cumparata.
function EraWords.maxedCrew(plural: string, padId: string, isBought: (string) -> boolean): string
    local pad = TycoonConfig.byId[padId]
    local era = if pad ~= nil then pad.era else 1
    local bell = bellOf(era)
    if bell ~= nil and not isBought(bell.id) then
        return Strings.crewMaxed(plural, bell.name)
    end
    local next = era + 1
    while TycoonConfig.eraIsLive(next) do
        local nextBell = bellOf(next)
        if nextBell == nil or not isBought(nextBell.id) then
            local name = TycoonConfig.eraName(next)
            if name ~= nil then
                return Strings.crewMaxedNext(plural, name)
            end
            break
        end
        next += 1
    end
    local coming = TycoonConfig.comingEra()
    if coming ~= nil then
        return Strings.crewMaxedComing(plural, coming.name)
    end
    return Strings.crewMaxedDone(plural)
end

return EraWords
