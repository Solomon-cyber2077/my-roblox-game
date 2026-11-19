local Tuning = require(Shared.Config.Tuning)
local StokerSockets = require(Shared.Logic.StokerSockets)

local S = Tuning.BruteRemake.Sockets

describe("The Stoker's eye sockets", function()
	it("breathe frost while snow falls or lies at the stop", function()
		expect(StokerSockets.mode(5, false, nil)).toBe("Frost")
		expect(StokerSockets.mode(0, true, nil)).toBe("Frost")
		-- the cold wins over the fog
		expect(StokerSockets.mode(5, false, 0)).toBe("Frost")
	end)

	it("let out fog beside the fog bank or inside it", function()
		expect(StokerSockets.mode(0, false, S.FogNear)).toBe("Fog")
		expect(StokerSockets.mode(0, false, -10)).toBe("Fog")
	end)

	it("show faint embers with neither", function()
		expect(StokerSockets.mode(0, false, S.FogNear + 1)).toBe("Embers")
		expect(StokerSockets.mode(0, false, nil)).toBe("Embers")
	end)
end)
