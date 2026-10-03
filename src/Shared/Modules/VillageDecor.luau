--!strict
-- [D70, pasul j1] DECORUL IMPRASTIAT AL SATULUI (lumea 1), intr-un singur loc: samanta, numarul si argumentele lui
-- WorldDecor.village. Il deseneaza SceneArt, il coace village_geometry (pamantul satului) si il fixeaza martorul lumii 1
-- (tests/WorldIdentity.test.luau). Pana acum argumentele erau copiate de mana in fiecare: o copie schimbata doar intr-un
-- loc ar fi desenat alt decor decat cel copt sau pazit, fara nicio eroare.
local RiverConfig =
    require(script and script.Parent.Parent.Config.RiverConfig or "../Config/RiverConfig")
local TycoonConfig =
    require(script and script.Parent.Parent.Config.TycoonConfig or "../Config/TycoonConfig")
local WorldConfig =
    require(script and script.Parent.Parent.Config.WorldConfig or "../Config/WorldConfig")
local WorldDecor = require(script and script.Parent.WorldDecor or "./WorldDecor")

local VillageDecor = {}

VillageDecor.SEED = 20260910
VillageDecor.COUNT = 130

-- [D70, pasul k1] `world`: harta (fara ea, satul). Lumea 1 iese exact ca inainte (RiverConfig.WORLDS[1] are aceleasi
-- valori ca RiverConfig); la baraj, o singura fasie de decor, pe terenul lui.
function VillageDecor.items(world: number?): { WorldDecor.Item }
    local w = WorldConfig.sanitize(world)
    local river = (RiverConfig.WORLDS :: any)[w]
    -- [D65] partea veche a satului isi tine copacii pe loc, fasia noua isi primeste ai ei
    return WorldDecor.village(VillageDecor.SEED, VillageDecor.COUNT, {
        width = river.WORLD_WIDTH,
        height = river.WORLD_HEIGHT,
        oldWidth = river.ERA1_WORLD_WIDTH,
        strips = river.DECOR_STRIPS, -- [D67]
    }, {
        -- Decorul trebuie sa stie cat de departe poate ajunge APA, nu unde e banda nominala:
        -- de cand malurile serpuiesc, raul urca pana la 392 si coboara pana la 824, iar un copac
        -- asezat dupa vechile 480/768 ar sta cu radacinile in rau.
        riverTop = river.SHORE_FAR.baseY - river.SHORE_FAR.amp,
        riverBottom = river.SHORE_NEAR.baseY + river.SHORE_NEAR.amp,
    }, river.PLOT, river.PLOT_ERA1, TycoonConfig.homeClearRects(w))
end

return VillageDecor
