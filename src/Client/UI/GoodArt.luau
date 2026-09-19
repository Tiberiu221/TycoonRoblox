--!strict
-- [D65] DESENUL UNEI MARFI: al ei cand e urcat, altfel al perechii din Era 1 (TycoonConfig.GOOD_LOOKS_LIKE). Gramezile
-- (PileView), roabele (PersonView), plasele (NetController) si raul (RiverRenderController) intreaba aici, ca regula sa
-- fie una: cand arta Morii se urca, fiecare loc o ia singur, fara nicio alta schimbare in cod.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local TycoonConfig = require(ReplicatedStorage.Shared.Config.TycoonConfig)

local GoodArt = {}

-- `spriteOf(marfa)` = desenul din tabelul celui care intreaba (iconita, fasia gramezii, incarcatura roabei), sau nil.
-- Intoarce primul desen URCAT: al marfii, apoi al perechii ei; nil daca niciunul.
function GoodArt.pick(good: string, spriteOf: (string) -> Assets.Sprite?): Assets.Sprite?
    local own = spriteOf(good)
    if own ~= nil and Assets.has(own) then
        return own
    end
    local twin = TycoonConfig.lookOf(good)
    if twin ~= good then
        local borrowed = spriteOf(twin)
        if borrowed ~= nil and Assets.has(borrowed) then
            return borrowed
        end
    end
    return nil
end

-- Iconita marfii (Assets.goods), cu aceeasi regula.
function GoodArt.icon(good: string): Assets.Sprite?
    return GoodArt.pick(good, function(g: string): Assets.Sprite?
        return (Assets.goods :: any)[g]
    end)
end

return GoodArt
