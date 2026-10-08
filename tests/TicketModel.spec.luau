local TicketModel = require(Shared.Logic.TicketModel)

local function joined(list)
	local out = {}
	for _, v in list do
		table.insert(out, tostring(v))
	end
	return table.concat(out, ",")
end

describe("TicketModel", function()
	it("maps danger to a seal number and 1-3 chalk strokes", function()
		expect(TicketModel.seal(1).number).toBe(1)
		expect(TicketModel.seal(1).strokes).toBe(1)
		expect(TicketModel.seal(2).strokes).toBe(2)
		expect(TicketModel.seal(3).strokes).toBe(3)
		expect(TicketModel.seal(5).number).toBe(5)
		expect(TicketModel.seal(5).strokes).toBe(3)
		expect(TicketModel.seal(0).strokes).toBe(1)
		expect(TicketModel.seal(2, true)).toBe(nil)
		expect(TicketModel.seal(nil)).toBe(nil)
	end)

	it("groups coal lumps in fives", function()
		local ten = TicketModel.coal(10)
		expect(joined(ten.groups)).toBe("5,5")
		expect(ten.label).toBe("x10")
		local twelve = TicketModel.coal(12)
		expect(joined(twelve.groups)).toBe("5,5,2")
		expect(twelve.lumps).toBe(12)
		expect(twelve.label).toBe("x12")
		expect(twelve.more).toBe(false)
		expect(TicketModel.coal(12.4).lumps).toBe(13)
		expect(TicketModel.coal(12.4).label).toBe("x12.4")
		local huge = TicketModel.coal(37)
		expect(huge.more).toBe(true)
		expect(#huge.groups).toBe(TicketModel.MaxLumps // TicketModel.LumpGroup)
		expect(huge.label).toBe("x37")
		expect(#TicketModel.coal(0).groups).toBe(0)
		expect(TicketModel.coal(nil)).toBe(nil)
	end)

	it("builds a ticket from nothing without erroring", function()
		local view = TicketModel.view(nil, nil, nil, nil)
		expect(view.serial).toBe("No. 00")
		expect(view.name).toBe("UNKNOWN LINE")
		expect(view.seal).toBe(nil)
		expect(view.coal).toBe(nil)
		expect(view.after).toBe(nil)
		expect(view.short).toBe(false)
		local stray =
			TicketModel.view({ archetype = "NoSuchPlace", tier = 2, distanceKm = 9, hint = "?" } :: any, 3)
		expect(stray.name).toBe("UNKNOWN LINE")
		expect(stray.kind).toBe("NO SUCH PLACE")
		expect(stray.seal.number).toBe(2)
		expect(stray.coal).toBe(nil)
	end)

	it("says what the bunker holds after the leg", function()
		local view =
			TicketModel.view({ archetype = "CoalYard", tier = 1, distanceKm = 10, hint = "" }, 7, 12, 30)
		expect(view.serial).toBe("No. 07")
		expect(view.after).toBe(18)
		expect(view.short).toBe(false)
		expect(
			TicketModel.view({ archetype = "CoalYard", tier = 1, distanceKm = 10, hint = "" }, 1, 12, 5).short
		).toBe(true)
	end)

	it("piles stamps by user id with the local player on top, at most four", function()
		local votes = { ["30"] = 1, ["4"] = 1, ["200"] = 1, ["9"] = 2 }
		local pile, extra = TicketModel.pile(votes, 1, "200")
		expect(joined(pile)).toBe("4,30,200")
		expect(extra).toBe(0)
		local crowd = { ["1"] = 1, ["2"] = 1, ["3"] = 1, ["4"] = 1, ["5"] = 1, ["6"] = 1 }
		local full, over = TicketModel.pile(crowd, 1, "2")
		expect(#full).toBe(TicketModel.MaxStamps)
		expect(joined(full)).toBe("4,5,6,2")
		expect(over).toBe(2)
		local none, zero = TicketModel.pile(nil, 1, "2")
		expect(#none).toBe(0)
		expect(zero).toBe(0)
	end)

	it("sweeps the dial and shows numerals only in the last ten seconds", function()
		local sweep, numeral = TicketModel.dial(105, 100, 120)
		expect(sweep).toBeCloseTo(0.25)
		expect(numeral).toBe(nil)
		local _, late = TicketModel.dial(111.5, 100, 120)
		expect(late).toBe(9)
		local over = TicketModel.dial(130, 100, 120)
		expect(over).toBe(1)
		expect(TicketModel.dial(5, nil, nil)).toBe(0)
	end)

	it("states the real tie-break", function()
		local options = {
			{ archetype = "Halt", tier = 1, distanceKm = 8, hint = "" },
			{ archetype = "Market", tier = 2, distanceKm = 12, hint = "" },
		}
		expect(TicketModel.tieNote({ a = 1 }, options)).toBe(nil)
		expect(TicketModel.tieNote({}, options)).toBe("NO VOTES: THE DRIVER TAKES THE SHORT LINE")
		expect(TicketModel.tieNote({ a = 1, b = 2 }, options)).toBe("A TIE: THE DRIVER TAKES THE SHORT LINE")
		options[2].distanceKm = 8
		expect(TicketModel.tieNote({ a = 1, b = 2 }, options)).toBe(
			"A TIE: SHORTEST LINES LEVEL, THE DRIVER TOSSES A COIN"
		)
	end)

	it("leans each ticket the same way every time, within limits", function()
		local a = TicketModel.tilt("run:3:1")
		expect(TicketModel.tilt("run:3:1")).toBe(a)
		expect(math.abs(a) <= TicketModel.MaxTilt).toBe(true)
		expect(TicketModel.track(8, 8, 16)).toBe(TicketModel.MinTrack)
		expect(TicketModel.track(16, 8, 16)).toBe(1)
		expect(TicketModel.track(10, 10, 10)).toBe(1)
	end)
end)
