local ResidentWalk = require(Shared.Logic.ResidentWalk)
local Npcs = require(Shared.Config.Npcs)

describe("Resident walks", function()
	it("keeps every walking resident clear of what Hands use", function()
		for id, def in Npcs.List do
			if def.walk then
				expect(ResidentWalk.firstClash(def.walk)).toBe(nil)
				expect(#def.walk.spots >= 2).toBe(true)
				-- the post is the first spot
				local post = def.post :: any
				expect(def.walk.spots[1].x).toBe(post.x)
				expect(def.walk.spots[1].z).toBe(post.z)
				expect(id).toBe(def.id)
			end
		end
	end)

	it("catches a spot set in front of the bell", function()
		local walk: any = {
			spots = { { x = 0, z = 0, yaw = 0 }, { x = 10, z = 0, yaw = 0 } },
			keepOut = { { name = "bell", x = 5, z = 1, r = 2 } },
		}
		expect(ResidentWalk.firstClash(walk)).toBe("spot 1 near the bell")
	end)

	it("picks another spot, and home often from elsewhere", function()
		local walk: any = { homeBias = 0.5, spots = { {}, {}, {}, {} } }
		for i = 0, 99 do
			local roll = i / 100
			for current = 1, 4 do
				local nextSpot = ResidentWalk.nextSpot(walk, current, roll)
				expect(nextSpot ~= current).toBe(true)
				expect(nextSpot >= 1 and nextSpot <= 4).toBe(true)
			end
		end
		expect(ResidentWalk.nextSpot(walk, 3, 0.2)).toBe(1)
	end)

	it("walks through every spot between, never across", function()
		local r = ResidentWalk.route(1, 4)
		expect(#r).toBe(3)
		expect(r[1]).toBe(2)
		expect(r[3]).toBe(4)
		local back = ResidentWalk.route(4, 2)
		expect(#back).toBe(2)
		expect(back[2]).toBe(2)
	end)

	it("steps at its speed and lands on the spot", function()
		local x, z, arrived = ResidentWalk.step(0, 0, 10, 0, 4, 0.5)
		expect(x).toBe(2)
		expect(z).toBe(0)
		expect(arrived).toBe(false)
		x, z, arrived = ResidentWalk.step(9.5, 0, 10, 0, 4, 0.5)
		expect(x).toBe(10)
		expect(arrived).toBe(true)
	end)
end)
