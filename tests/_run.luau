-- Rulare: lune run tests/_run.luau  (alias @frktest din .luaurc -> tests/vendor/frktest)
local process = require("@lune/process")

require("./OfflineCalc.test")()
require("./AABB.test")()
require("./RiverSim.test")()
require("./WorldMap.test")()
require("./Pathfind.test")()
require("./WorldDecor.test")()
require("./RiverConfig.test")()
require("./ItemConfig.test")()
require("./TycoonConfig.test")()
require("./FairLayout.test")()
require("./TitleMath.test")()
require("./BoardMath.test")()
require("./RideMath.test")()
require("./MarketMath.test")()
require("./FairPresence.test")()
require("./CrowdCodec.test")()
require("./FairScenery.test")()
require("./PondMath.test")() -- [D61]
require("./BoothMath.test")() -- [D61]
require("./TycoonMath.test")()
require("./ProfileMigrate.test")()
require("./HandMath.test")()
require("./HandRoutes.test")()
require("./RoadGraph.test")()
require("./TavernCrowd.test")()
require("./HandConfig.test")()
require("./CatchFloat.test")()
require("./NetMotion.test")()
require("./Shoreline.test")()
require("./ChainMath.test")()
require("./QuestMath.test")()
require("./WheelMath.test")()
require("./GuideMath.test")()
require("./RateLimiter.test")()
require("./AudioLevels.test")()
require("./FishMath.test")()
require("./ReelMath.test")()
require("./TreasureMath.test")()
require("./PearlBudget.test")()
require("./LookMath.test")()
require("./VillageLook.test")()
require("./ModernMath.test")() -- [D70]
require("./GlanceMath.test")() -- [D70] Look (V)
require("./EraWords.test")() -- [2026-09-30] finalul Erei 3
require("./ModernConfig.test")() -- [D70]
require("./VisitMath.test")()
require("./AmbitionMath.test")()
require("./HudLayout.test")()
require("./HeldBack.test")()
require("./ChainWords.test")() -- [D65]
require("./FlowMath.test")()
require("./PassMath.test")()
require("./DriftMath.test")()
require("./StreakMath.test")() -- [D71]
require("./CatchSound.test")() -- [D72]
require("./WorldIdentity.test")() -- [D70, pasul j1] martorul lumii 1
require("./WorldConfig.test")() -- [D70, pasul j6] lumile
require("./World2Layout.test")() -- [D70, pasul j7] asezarea barajului
require("./WorldMath.test")() -- [D70, pasul j10] portile pe lume
require("./DamMath.test")() -- [D70, pasul j14] ridicarea barajului, pura
require("./DamService.test")() -- [D70, pasul j15] barajul pe server
require("./SaveLoop.test")() -- [D70, verificatorul j15] salvarea fortata
require("./StateCopy.test")() -- [D70, pasul k3] copia starii pe linii

local frktest = require("@frktest/frktest")
local console_reporter = require("@frktest/reporters/console_reporter")
console_reporter.init()

local passed = frktest.run()
if not passed then
    process.exit(1)
end
