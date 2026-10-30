local TouchAction = require(Shared.Logic.TouchAction)

local function entry(id: string, hold: number?)
	return { id = id, action = "Search", object = id, hold = hold or 0 }
end

describe("TouchAction", function()
	it("acts on the most recently shown prompt still in range", function()
		local s = TouchAction.new()
		expect(TouchAction.target(s)).toBe(nil)
		TouchAction.show(s, entry("crate"))
		TouchAction.show(s, entry("door"))
		expect(TouchAction.target(s).id).toBe("door")
		TouchAction.hide(s, "door")
		expect(TouchAction.target(s).id).toBe("crate")
		TouchAction.hide(s, "crate")
		expect(TouchAction.target(s)).toBe(nil)
	end)

	it("taps a prompt with no hold and reports no progress", function()
		local s = TouchAction.new()
		TouchAction.show(s, entry("crate"))
		expect(TouchAction.press(s, 10)).toBe("crate")
		expect(TouchAction.progress(s, 10.5)).toBe(0)
		expect(TouchAction.release(s)).toBe("crate")
		expect(TouchAction.release(s)).toBe(nil)
	end)

	it("holds for the server's hold time", function()
		local s = TouchAction.new()
		TouchAction.show(s, entry("vault", 2))
		TouchAction.press(s, 10)
		expect(TouchAction.progress(s, 11)).toBe(0.5)
		expect(TouchAction.progress(s, 13)).toBe(1)
		expect(TouchAction.press(s, 11)).toBe(nil) -- a second thumb does not restart it
	end)

	it("cancels a hold when its prompt goes or another takes its place", function()
		local s = TouchAction.new()
		TouchAction.show(s, entry("vault", 2))
		TouchAction.press(s, 10)
		expect(TouchAction.hide(s, "vault")).toBe("vault")
		expect(TouchAction.progress(s, 11)).toBe(0)

		TouchAction.show(s, entry("vault", 2))
		TouchAction.press(s, 20)
		expect(TouchAction.show(s, entry("door"))).toBe("vault")
		expect(TouchAction.release(s)).toBe(nil) -- nothing left held
		-- hiding something else leaves the hold alone
		TouchAction.press(s, 30)
		expect(TouchAction.hide(s, "vault")).toBe(nil)
		expect(TouchAction.release(s)).toBe("door")
	end)

	it("keeps the label short enough for a phone", function()
		expect(TouchAction.label("Search", "Crate")).toBe("SEARCH CRATE")
		expect(TouchAction.label("Open", "")).toBe("OPEN")
		expect(TouchAction.label("Deliver", "sealed payroll strongbox")).toBe("DELIVER")
	end)
end)
