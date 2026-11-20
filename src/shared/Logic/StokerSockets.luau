--!strict
--[[
	What breathes out of the Stoker's hollow eye sockets (Tuning.BruteRemake.Sockets): frost in the cold, fog
	beside the fog bank, otherwise a very faint thread of embers. Pure; Visual/StokerSockets draws it.

	  mode  "Frost" while snow falls round the train or lies at the stop; else "Fog" when he stands within
	        FogNear studs of the fog front (or inside it); else "Embers"
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local S = Tuning.BruteRemake.Sockets

local StokerSockets = {}

-- `snowFalling` the falling snow's rate, `snowy` whether the stop lies under snow, `fogGap` how far in front
-- of the fog he stands (nil with no fog drawn).
function StokerSockets.mode(snowFalling: number, snowy: boolean, fogGap: number?): string
	if snowFalling > 0 or snowy then
		return "Frost"
	end
	if fogGap ~= nil and fogGap <= S.FogNear then
		return "Fog"
	end
	return "Embers"
end

return StokerSockets
