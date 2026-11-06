local Again = require(Shared.Logic.Again)

local function set(ids: { number }): { [number]: boolean }
	local out = {}
	for _, id in ids do
		out[id] = true
	end
	return out
end

describe("Again presses", function()
	it("queues presses during RunEnd and applies them after the reset", function()
		local card = Again.card({ 1, 2, 3 })
		local accepted, now = Again.press(card, 1, false, 0)
		expect(accepted).toBe(true)
		expect(now).toBe(false)
		expect(card.firstAppliedAt).toBe(nil)
		local applied = Again.apply(card, 12)
		expect(#applied).toBe(1)
		expect(applied[1]).toBe(1)
		expect(card.firstAppliedAt).toBe(12) -- the fallback starts at the first applied press
		expect(#Again.apply(card, 13)).toBe(0)
	end)

	it("applies a Lobby press at once and starts the fallback if nothing was queued", function()
		local card = Again.card({ 1, 2 })
		Again.apply(card, 12)
		expect(card.firstAppliedAt).toBe(nil)
		local accepted, now = Again.press(card, 2, true, 15)
		expect(accepted).toBe(true)
		expect(now).toBe(true)
		expect(card.firstAppliedAt).toBe(15)
	end)

	it("accepts eliminated members but not strangers, and counts each player once", function()
		local card = Again.card({ 1, 2 })
		expect((Again.press(card, 9, true, 0))).toBe(false)
		expect((Again.press(card, 2, true, 0))).toBe(true)
		expect((Again.press(card, 2, true, 1))).toBe(false) -- accepted before: no second telemetry
	end)
end)

describe("Again hold", function()
	it("waits for every present eligible member, then lets the hall count down", function()
		local card = Again.card({ 1, 2, 3 })
		Again.press(card, 1, true, 0)
		local present = set({ 1, 2, 3 })
		expect(Again.hold(card, present, set({ 1 }), 5)).toBe(true)
		expect(Again.hold(card, present, set({ 1, 2, 3 }), 5)).toBe(false)
	end)

	it("goes after 12 s with at least one ready", function()
		local card = Again.card({ 1, 2 })
		Again.press(card, 1, true, 100)
		expect(Again.hold(card, set({ 1, 2 }), set({ 1 }), 111.9)).toBe(true)
		expect(Again.hold(card, set({ 1, 2 }), set({ 1 }), 112)).toBe(false)
	end)

	it("drops a leaving player from the wait", function()
		local card = Again.card({ 1, 2 })
		Again.press(card, 1, true, 0)
		expect(Again.hold(card, set({ 1 }), set({ 1 }), 1)).toBe(false)
	end)

	it("lets DEPOT leave a player unready without stalling the rest", function()
		local card = Again.card({ 1, 2 })
		Again.press(card, 2, false, 0)
		Again.depot(card, 2)
		expect(#Again.apply(card, 12)).toBe(0)
		Again.press(card, 1, true, 13)
		expect(Again.hold(card, set({ 1, 2 }), set({ 1 }), 14)).toBe(false)
	end)

	it("lets a solo crew go at once", function()
		local card = Again.card({ 7 })
		Again.press(card, 7, true, 0)
		expect(Again.hold(card, set({ 7 }), set({ 7 }), 0)).toBe(false)
	end)

	it("counts ready and waited-for members for the card", function()
		local card = Again.card({ 1, 2, 3 })
		Again.press(card, 1, false, 0)
		local ready, of = Again.count(card, set({ 1, 2, 3 }), {})
		expect(ready).toBe(1)
		expect(of).toBe(3)
	end)
end)

describe("Again in a car server after the run", function()
	it("keeps a queued or ready player, even when the wait is over", function()
		local card = Again.card({ 1, 2 })
		Again.press(card, 1, false, 0)
		expect(Again.leaves(card, 1, set({}), true)).toBe(false)
		expect(Again.leaves(card, 2, set({ 2 }), true)).toBe(false)
	end)

	it("sends DEPOT at once", function()
		local card = Again.card({ 1 })
		Again.depot(card, 1)
		expect(Again.leaves(card, 1, set({}), false)).toBe(true)
	end)

	it("holds an undecided player until the wait is over", function()
		local card = Again.card({ 1 })
		expect(Again.leaves(card, 1, set({}), false)).toBe(false)
		expect(Again.leaves(card, 1, set({}), true)).toBe(true)
	end)

	it("sends everyone when there is no card", function()
		expect(Again.leaves(nil, 1, set({ 1 }), false)).toBe(true)
	end)
end)
