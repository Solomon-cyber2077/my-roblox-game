local CashOut = require(Shared.Logic.CashOut)
local Tuning = require(Shared.Config.Tuning)

local STOP = Tuning.Run.CashOutStop

describe("CashOut", function()
	it("is offered after the cash-out stop on a line that runs past it", function()
		expect(CashOut.offered(10, STOP)).toBe(true)
		expect(CashOut.offered(10, STOP - 1)).toBe(false)
		expect(CashOut.offered(10, STOP + 1)).toBe(false)
		expect(CashOut.offered(STOP, STOP)).toBe(false) -- the Short Line ends there anyway
	end)

	it("lets only the crew aboard when it opened cash out, once, inside the window", function()
		local offer = CashOut.open(STOP, { 1, 2 }, 100)
		expect(CashOut.check(offer, 1, true, 50)).toBe(nil)
		expect(CashOut.check(offer, 3, true, 50)).toBe("not_offered") -- joined later or was down
		expect(CashOut.check(offer, 2, false, 50)).toBe("not_aboard")
		CashOut.take(offer, 1)
		expect(CashOut.check(offer, 1, true, 60)).toBe("taken") -- a second press changes nothing
		expect(CashOut.check(offer, 2, true, 101)).toBe("closed") -- no answer by the end: rides on
		expect(CashOut.check(nil, 2, true, 0)).toBe("closed")
	end)

	it("keeps each choice to its own player", function()
		local offer = CashOut.open(STOP, { 1, 2, 3 }, 100)
		CashOut.take(offer, 2)
		expect(CashOut.check(offer, 1, true, 10)).toBe(nil)
		expect(CashOut.check(offer, 3, true, 10)).toBe(nil)
		expect(offer.taken["2"]).toBe(true)
	end)
end)
