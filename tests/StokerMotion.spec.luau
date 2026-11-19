local Tuning = require(Shared.Config.Tuning)
local StokerMotion = require(Shared.Logic.StokerMotion)

local U = Tuning.BruteRemake.Uncanny

describe("The Stoker's uncanny weight", function()
	it("counts stillness only while he stands", function()
		expect(StokerMotion.still(0.5, 0.2, 0.1)).toBe(0.6)
		expect(StokerMotion.still(0.5, 6, 0.1)).toBe(0)
	end)

	it("unfolds slowly once still long enough, folds faster when he moves", function()
		expect(StokerMotion.unfold(0, U.StillAfter - 0.1, 0.5)).toBe(0)
		local u = StokerMotion.unfold(0, U.StillAfter, 0.5)
		expect(u > 0 and u < 1).toBe(true)
		expect(StokerMotion.unfold(1, U.StillAfter, 1)).toBe(1)
		expect(StokerMotion.unfold(0.5, 0, 1)).toBe(0)
	end)

	it("turns his head past a neck's limit, holds, then brings it back", function()
		local reach = U.LookMax / U.LookSpeed
		expect(StokerMotion.overturn(0, 1)).toBe(0)
		expect(math.abs((StokerMotion.overturn(reach, -1) :: number) + U.LookMax) < 1e-6).toBe(true)
		expect(StokerMotion.overturn(reach + U.LookHold * 0.5, 1)).toBe(U.LookMax)
		expect(U.LookMax > math.rad(110)).toBe(true) -- past where a person's head can go
		expect(StokerMotion.overturn(reach + U.LookHold + U.LookMax / U.LookBack + 0.1, 1)).toBe(nil)
	end)
end)
