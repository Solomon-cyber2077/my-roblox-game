local Catalog = require(Shared.Logic.Catalog)

describe("Catalog developer unlock", function()
	it("allows the configured owner in live servers", function()
		expect(Catalog.devUnlocked(11744048795, false)).toBe(true)
	end)

	it("denies other live users", function()
		expect(Catalog.devUnlocked(1, false)).toBe(false)
	end)

	it("allows Studio users", function()
		expect(Catalog.devUnlocked(1, true)).toBe(true)
	end)

	it("requires a valid cosmetic id", function()
		expect(Catalog.canUse({}, "missing_cosmetic", 11744048795, false)).toBe(false)
	end)

	it("does not mutate ownership", function()
		local owned = {}
		expect(Catalog.canUse(owned, "lantern_aurora", 11744048795, false)).toBe(true)
		expect(owned.lantern_aurora).toBe(nil)
	end)
end)
