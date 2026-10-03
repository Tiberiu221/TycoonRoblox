--!strict
-- [D70, pasul j1] DECORUL IMPRASTIAT AL SATULUI (lumea 1), intr-un singur loc: samanta, numarul si argumentele lui
-- WorldDecor.village. Il deseneaza SceneArt, il coace village_geometry (pamantul satului) si il fixeaza martorul lumii 1
-- (tests/WorldIdentity.test.luau). Pana acum argumentele erau copiate de mana in fiecare: o copie schimbata doar intr-un
-- loc ar fi desenat alt decor decat cel copt sau pazit, fara nicio eroare.
local RiverConfig =
    require(script and script.Parent.Parent.Config.RiverConfig or "../Config/RiverConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldDecor = require(script and script.Parent.WorldDecor or "./WorldDecor")

local VillageDecor = {}

VillageDecor.SEED = 20260910
VillageDecor.COUNT = 130

function VillageDecor.items(): { WorldDecor.Item }
    -- [D65] partea veche a satului isi tine copacii pe loc, fasia noua isi primeste ai ei
    return WorldDecor.village(VillageDecor.SEED, VillageDecor.COUNT, {
        width = RiverConfig.WORLD_WIDTH,
        height = RiverConfig.WORLD_HEIGHT,
        oldWidth = RiverConfig.ERA1_WORLD_WIDTH,
        strips = RiverConfig.DECOR_STRIPS, -- [D67]
    }, {
        -- Decorul trebuie sa stie cat de departe poate ajunge APA, nu unde e banda nominala:
        -- de cand malurile serpuiesc, raul urca pana la 392 si coboara pana la 824, iar un copac
        -- asezat dupa vechile 480/768 ar sta cu radacinile in rau.
        riverTop = RiverConfig.SHORE_FAR.baseY - RiverConfig.SHORE_FAR.amp,
        riverBottom = RiverConfig.SHORE_NEAR.baseY + RiverConfig.SHORE_NEAR.amp,
    }, RiverConfig.PLOT, RiverConfig.PLOT_ERA1, TycoonConfig.homeClearRects())
end

return VillageDecor
