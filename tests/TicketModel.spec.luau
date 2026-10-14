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

	it("keeps every stamp of a pile inside the two ends of the strip, for 1 to MaxStamps", function()
		local spread, inset = 100, TicketModel.StampInset
		expect(TicketModel.stampX(1, 1, spread)).toBe(50)
		for slots = 2, TicketModel.MaxStamps do
			expect(TicketModel.stampX(1, slots, spread)).toBe(inset)
			expect(TicketModel.stampX(slots, slots, spread)).toBe(spread - inset)
			for order = 1, slots do
				expect(TicketModel.stampX(order, slots, spread)).toBeBetween(inset, spread - inset)
			end
		end
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

	it("shows the ballot only while the vote is open, or for the punch", function()
		local open = { options = { {}, {} }, votes = {} }
		local closed = { options = { {}, {} }, votes = {}, chosen = 2 }
		expect(TicketModel.ballotShown("Junction", open, true, false)).toBe(true)
		expect(TicketModel.ballotShown("Junction", open, false, false)).toBe(false)
		expect(TicketModel.ballotShown("Junction", closed, true, false)).toBe(false)
		expect(TicketModel.ballotShown("Cruise", closed, true, true)).toBe(true)
		expect(TicketModel.ballotShown("Cruise", closed, true, false)).toBe(false)
		expect(TicketModel.ballotShown("Dwell", open, true, false)).toBe(false)
		expect(TicketModel.ballotShown("Junction", nil, true, true)).toBe(false)
		expect(TicketModel.ballotShown("Junction", { options = {} }, true, false)).toBe(false)
	end)
	it("stamps a voter's initials from awkward names, falling back on the user name", function()
		expect(TicketModel.initials("TameGiant", "tamegiant6324")).toBe("TG")
		expect(TicketModel.initials("tame_Giant", nil)).toBe("TG")
		expect(TicketModel.initials("Tame Giant", nil)).toBe("TG")
		expect(TicketModel.initials("ada", nil)).toBe("A")
		expect(TicketModel.initials("x", nil)).toBe("X") -- one letter
		expect(TicketModel.initials("5O10M0N", nil)).toBe("OO") -- digits: the first letter leads
		expect(TicketModel.initials("1234", nil)).toBe("1") -- digits only
		expect(TicketModel.initials("___", "Player_1")).toBe("P") -- underscores only: user name
		expect(TicketModel.initials("Élodie", nil)).toBe("L") -- a Latin letter still leads
		expect(TicketModel.initials("Жора", nil)).toBe("Ж") -- another script: its first letter
		expect(TicketModel.initials("李小龙", nil)).toBe("李")
		expect(TicketModel.initials("🔥🔥", "FireFan")).toBe("FF") -- emoji only: user name
		expect(TicketModel.initials("🚂 Rail", nil)).toBe("R")
		expect(TicketModel.initials(string.rep("Longname", 40), nil)).toBe("LL") -- capped at two
		expect(TicketModel.initials("", "Player2")).toBe("P") -- empty display name
		expect(TicketModel.initials(nil, "Player2")).toBe("P")
		expect(TicketModel.initials("­¬", "bob")).toBe("B") -- broken UTF-8
		expect(TicketModel.initials("", "")).toBe("?") -- only when both are truly empty
		expect(TicketModel.initials(nil, nil)).toBe("?")
	end)
end)
