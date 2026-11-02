local SaveLock = require(Shared.Logic.SaveLock)

describe("SaveLock", function()
	it("lets the session that holds the lock write", function()
		expect(SaveLock.owns({ lock = { job = "a" }, session = "s1" }, "a", "s1")).toBe(true)
		-- its own release, then a save during shutdown
		expect(SaveLock.owns({ session = "s1" }, "a", "s1")).toBe(true)
	end)

	it("refuses while another server holds the lock", function()
		expect(SaveLock.owns({ lock = { job = "b" }, session = "s2" }, "a", "s1")).toBe(false)
	end)

	it("refuses a late save after a newer session released the lock", function()
		expect(SaveLock.owns({ session = "s2" }, "a", "s1")).toBe(false)
	end)

	it("refuses a later load on the same server", function()
		expect(SaveLock.owns({ lock = { job = "a" }, session = "s2" }, "a", "s1")).toBe(false)
	end)

	it("writes to an empty key", function()
		expect(SaveLock.owns({}, "a", "s1")).toBe(true)
	end)
end)
