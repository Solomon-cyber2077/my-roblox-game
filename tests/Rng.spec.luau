local Rng = require(Shared.Util.Rng)

describe("Rng", function()
	it("repeats the same sequence for the same seed", function()
		local a, b = Rng.new(12345), Rng.new(12345)
		for _ = 1, 200 do
			expect(a:nextUint32()).toBe(b:nextUint32())
		end
	end)

	it("produces different sequences for different seeds", function()
		local a, b = Rng.new(1), Rng.new(2)
		local same = 0
		for _ = 1, 50 do
			if a:nextUint32() == b:nextUint32() then
				same += 1
			end
		end
		expect(same).toBeLessThan(2)
	end)

	it("keeps next() in [0, 1) with a mean near 0.5", function()
		local rng = Rng.new(99)
		local sum = 0
		for _ = 1, 20000 do
			local v = rng:next()
			expect(v).toBeAtLeast(0)
			expect(v).toBeLessThan(1)
			sum += v
		end
		expect(sum / 20000).toBeBetween(0.49, 0.51)
	end)

	it("returns inclusive integer bounds", function()
		local rng = Rng.new(7)
		local seen = {}
		for _ = 1, 2000 do
			local v = rng:int(3, 8)
			expect(v).toBeBetween(3, 8)
			expect(v % 1).toBe(0)
			seen[v] = true
		end
		for v = 3, 8 do
			expect(seen[v]).toBe(true)
		end
	end)

	it("forks independently of how many numbers were drawn", function()
		local a = Rng.new(555)
		local b = Rng.new(555)
		for _ = 1, 37 do
			b:next()
		end
		expect(a:fork("loot", 3):nextUint32()).toBe(b:fork("loot", 3):nextUint32())
		expect(a:fork("loot", 3):nextUint32() ~= a:fork("loot", 4):nextUint32()).toBe(true)
	end)

	it("respects weights", function()
		local rng = Rng.new(2024)
		local hits = { a = 0, b = 0 }
		for _ = 1, 10000 do
			local v = rng:weighted({ { weight = 3, value = "a" }, { weight = 1, value = "b" } })
			hits[v] += 1
		end
		expect(hits.a / 10000).toBeBetween(0.72, 0.78)
	end)
end)
