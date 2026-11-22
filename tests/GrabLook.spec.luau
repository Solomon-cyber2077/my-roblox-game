local GrabLook = require(Shared.Logic.GrabLook)
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)

describe("GrabLook", function()
	it("is off by default and keeps today's look when off", function()
		expect(Tuning.GrabLook.Enabled).toBe(false)
		expect(GrabLook.look("Stalker", false, true)).toBe(nil)
		expect(GrabLook.look("Brute", false, true)).toBe(nil)
	end)

	it("gives the Stalker cold, the Stoker heat, and leaves the Crawler and the old Brute alone", function()
		expect(GrabLook.look("Stalker", true, true)).toBe("Cold")
		expect(GrabLook.look("Brute", true, true)).toBe("Heat")
		expect(GrabLook.look("Brute", true, false)).toBe(nil)
		expect(GrabLook.look("Crawler", true, true)).toBe(nil)
	end)

	it("has a camera move for every Stalker hold and every Stoker hold", function()
		for _, def in Grabs.Kinds.Stalker do
			expect(GrabLook.move(def.id) ~= nil).toBe(true)
		end
		expect(GrabLook.move("Lift")).toBe("Rise")
		expect(GrabLook.move("Slam")).toBe("Drop")
		expect(GrabLook.move("Reach")).toBe("Jolts")
	end)

	it("maps every key to a distinct variant", function()
		local seen = {}
		for key = 1, GrabLook.Count do
			local v = GrabLook.variant(key)
			expect(v.key).toBe(key)
			local id = `{v.lean}|{v.speed}|{v.sway}`
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
	end)

	it("never rolls the last grab's variant, and can reach every other one", function()
		local seed = 7
		local pick = function(n: number): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			return (seed // 65536) % n + 1
		end
		for last = 1, GrabLook.Count do
			local reached = {}
			for _ = 1, 400 do
				local v = GrabLook.roll(last, pick)
				expect(v.key ~= last).toBe(true)
				reached[v.key] = true
			end
			local count = 0
			for _ in reached do
				count += 1
			end
			expect(count).toBe(GrabLook.Count - 1)
		end
		-- the edges of the pick map past the last key
		expect(GrabLook.roll(1, function()
			return 1
		end).key).toBe(2)
		expect(GrabLook.roll(GrabLook.Count, function(n)
			return n
		end).key).toBe(GrabLook.Count - 1)
	end)

	it("scales to three settings, Quality by default", function()
		expect(GrabLook.tier(nil)).toBe("Quality")
		expect(GrabLook.tier("Performance")).toBe("Performance")
		expect(GrabLook.tier("Balanced")).toBe("Balanced")
		for _, name in { "Quality", "Balanced", "Performance" } do
			local t = Tuning.GrabLook.Tiers[name]
			expect(t.specks).toBeGreaterThan(0) -- scaled down, never removed
			expect(t.fog).toBeGreaterThan(0)
		end
	end)

	it("closes the screen faster for a fast variant", function()
		expect(GrabLook.close(0.3, 1.4)).toBeGreaterThan(GrabLook.close(0.3, 0.7))
		expect(GrabLook.close(10, 0.7)).toBe(1)
		expect(GrabLook.close(0, 1)).toBe(0)
	end)
end)
