local Catalog = require(Shared.Logic.Catalog)
local Cosmetics = require(Shared.Config.Cosmetics)

describe("Catalog developer unlock", function()
	it("leaves the developer's account locked in live servers while Live is off", function()
		expect(Cosmetics.DevUnlock.Live).toBe(false)
		expect(Catalog.devUnlocked(Cosmetics.DevUnlock.UserId, false)).toBe(false)
	end)

	it("denies other live users", function()
		expect(Catalog.devUnlocked(1, false)).toBe(false)
	end)

	it("allows Studio users", function()
		expect(Catalog.devUnlocked(1, true)).toBe(true)
	end)

	it("requires a valid cosmetic id", function()
		expect(Catalog.canUse({}, "missing_cosmetic", 1, true)).toBe(false)
	end)

	it("does not mutate ownership", function()
		local owned = {}
		expect(Catalog.canUse(owned, "lantern_aurora", 1, true)).toBe(true)
		expect(owned.lantern_aurora).toBe(nil)
	end)
end)
