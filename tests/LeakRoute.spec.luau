local LeakRoute = require(Shared.Logic.LeakRoute)
local Tuning = require(Shared.Config.Tuning)

local A = Tuning.LeakArrows

describe("LeakRoute", function()
	it("runs down the aisle and ends at the wall beside the leak", function()
		local path = LeakRoute.inside({ x = -80, z = 1 }, { x = 12, z = -5.6 })
		local last = path[#path]
		expect(last.x).toBeCloseTo(12)
		expect(last.z).toBeCloseTo(-A.WallInset)
		-- the middle of the run is in the aisle
		expect(path[3].z).toBe(0)
		expect(path[3].x).toBeCloseTo(12 - A.CurveIn)
	end)

	it("goes straight to the wall when you are already beside the leak", function()
		local path = LeakRoute.inside({ x = 10, z = 0 }, { x = 12, z = -5.6 })
		expect(#path).toBe(2)
		expect(path[2].z).toBeCloseTo(-A.WallInset)
	end)

	it("lays chevrons a spacing apart, pointing along the path, capped", function()
		local path = { { x = 0, z = 0 }, { x = 100, z = 0 } }
		local chevrons = LeakRoute.place(path, 0)
		expect(#chevrons).toBe(A.Count)
		expect(chevrons[1].x).toBeCloseTo(A.Lead)
		expect(chevrons[2].x - chevrons[1].x).toBeCloseTo(A.Spacing)
		expect(chevrons[1].dx).toBeCloseTo(1)
		-- the scroll moves them forward and wraps every spacing
		expect(LeakRoute.place(path, 0.5)[1].x).toBeCloseTo(A.Lead + 0.5)
		expect(LeakRoute.place(path, A.Spacing)[1].x).toBeCloseTo(A.Lead)
	end)

	it("ends the platform path at the Last Light's door from either end", function()
		for _, from in { { x = -40, z = 12 }, { x = 90, z = 9 }, { x = 57, z = 15 } } do
			local path = LeakRoute.platform(from)
			local last = path[#path]
			expect(last.x).toBe(A.CabDoorX)
			expect(last.z).toBe(A.CabDoorZ)
			for _, p in path do
				expect(p.z).toBeAtLeast(A.CabDoorZ - 1e-6)
			end
		end
	end)
end)
