-- Rulare: lune run tests/_run.luau  (alias @frktest din .luaurc -> tests/vendor/frktest)
local process = require("@lune/process")

require("./OfflineCalc.test")()
require("./AABB.test")()
require("./RiverSim.test")()
require("./WorldMap.test")()
require("./Pathfind.test")()
require("./Storyteller.test")()
require("./WorldDecor.test")()
require("./ObjectiveConfig.test")()
require("./FoodBalance.test")()
require("./RiverConfig.test")()
require("./ItemConfig.test")()

local frktest = require("@frktest/frktest")
local console_reporter = require("@frktest/reporters/console_reporter")
console_reporter.init()

local passed = frktest.run()
if not passed then
    process.exit(1)
end
