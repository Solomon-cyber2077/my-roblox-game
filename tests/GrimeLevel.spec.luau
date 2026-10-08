--!strict

local GrimeLevel = require(Shared.Logic.GrimeLevel)

describe("GrimeLevel", function()
	it("maps the ten stops and Terminus to the expected grime range", function()
		expect(GrimeLevel.forStop(1, 10, false)).toEqual(0)
		expect(GrimeLevel.forStop(5, 10, false)).toEqual(0.4)
		expect(GrimeLevel.forStop(10, 10, false)).toEqual(0.9)
		expect(GrimeLevel.forStop(1, 10, true)).toEqual(1)
	end)

	it("clamps invalid stop inputs safely", function()
		expect(GrimeLevel.forStop(-2, 10, false)).toEqual(0)
		expect(GrimeLevel.forStop(20, 10, false)).toEqual(1)
		expect(GrimeLevel.forStop(1, 0, false)).toEqual(0)
	end)

	it("produces deterministic bounded variation", function()
		for _, seed in { 1, 2, 42, 987654321 } do
			local first = GrimeLevel.variation(seed)
			local second = GrimeLevel.variation(seed)
			expect(first.tint).toEqual(second.tint)
			expect(first.scale).toEqual(second.scale)
			expect(first.accessory).toEqual(second.accessory)
			expect(first.tint >= 0.9 and first.tint <= 1.1).toEqual(true)
			expect(first.scale >= 0.9 and first.scale <= 1.1).toEqual(true)
			expect(first.accessory >= 1 and first.accessory <= 3).toEqual(true)
		end
	end)
end)
