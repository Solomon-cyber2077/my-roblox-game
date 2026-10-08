local MysteryConfig = require(Shared.Config.Mystery)
local RunLog = require(Shared.Logic.RunLog)

local function ballot(over)
	local b = {
		stop = 3,
		ticket = { archetype = "Halt", tier = 2, distanceKm = 40, hint = "x" },
		name = "Whistle-Stop Halt",
		difficulty = 0.4,
		coalBurned = 6,
		votes = { ["1"] = 2, ["2"] = 2, ["3"] = 1 },
		optionCount = 3,
		chosen = 2,
	}
	for k, v in over or {} do
		b[k] = v
	end
	return b
end

-- What a state snapshot can carry: dense arrays and string-keyed tables, nothing else.
local function wireSafe(value)
	if type(value) ~= "table" then
		return type(value) ~= "function" and type(value) ~= "userdata"
	end
	local n, count = #value, 0
	for k, v in value do
		count += 1
		if type(k) == "number" and (k < 1 or k > n or k % 1 ~= 0) then
			return false
		end
		if type(k) ~= "number" and type(k) ~= "string" then
			return false
		end
		if n > 0 and type(k) == "string" then
			return false -- mixed table
		end
		if not wireSafe(v) then
			return false
		end
	end
	return n == 0 or count == n
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

describe("RunLog", function()
	it("builds an entry from the ticket and the vote split", function()
		local e = RunLog.entry(ballot())
		expect(e.stop).toBe(3)
		expect(e.name).toBe("Whistle-Stop Halt")
		expect(e.archetype).toBe("Halt")
		expect(e.tier).toBe(2)
		expect(e.distanceKm).toBe(40)
		expect(e.coalBurned).toBe(6)
		expect(e.votes).toEqual({ 1, 2, 0 })
		expect(e.chosen).toBe(2)
		expect(e.unanimous).toBe(false)
		expect(e.mystery).toBe(nil)
		expect(e.outcome).toBe("Cleared")
	end)

	it("calls a vote unanimous only with two or more ballots, all for the winner", function()
		expect(RunLog.entry(ballot({ votes = { ["1"] = 2, ["2"] = 2 } })).unanimous).toBe(true)
		expect(RunLog.entry(ballot({ votes = { ["1"] = 2 } })).unanimous).toBe(false)
		expect(RunLog.entry(ballot({ votes = {} })).unanimous).toBe(false)
		local noVotes = ballot()
		noVotes.votes = nil
		expect(RunLog.entry(noVotes).votes).toEqual({ 0, 0, 0 })
	end)

	it("keeps a sealed ticket sealed until it is revealed", function()
		local sealed =
			{ archetype = MysteryConfig.Archetype, tier = 0, distanceKm = 55, hint = "", mystery = true }
		local e = RunLog.entry(ballot({ ticket = sealed }))
		expect(e.name).toBe(MysteryConfig.Name)
		expect(e.tier).toBe(0)
		expect(e.difficulty).toBe(0)
		expect(e.mystery).toBe(true)
		expect(e.revealed).toBe(nil)
		expect(RunLog.option(e).mystery).toBe(true)
		local r = RunLog.reveal(e, "Halt", "Whistle-Stop Halt", 2, 0.5)
		expect(r.name).toBe("Whistle-Stop Halt")
		expect(r.revealed).toBe(true)
		expect(RunLog.option(r).mystery).toBe(nil)
		expect(e.revealed).toBe(nil) -- the pending entry is not mutated
		expect(RunLog.reveal(RunLog.entry(ballot()), "Halt", "H", 1, 0).revealed).toBe(nil)
	end)

	it("leaves optional fields nil and stamps nothing on a plain stop", function()
		local e = RunLog.resolve(RunLog.entry(ballot()), "Cleared", {})
		expect(e.closeCalls).toBe(nil)
		expect(e.mystery).toBe(nil)
		expect(#RunLog.stamps(e)).toBe(0)
		expect(RunLog.resolve(RunLog.entry(ballot()), "Cleared", nil).closeCalls).toBe(nil)
	end)

	it("stamps close calls, gambles with their outcome and unanimous votes", function()
		local sealed =
			{ archetype = MysteryConfig.Archetype, tier = 0, distanceKm = 55, hint = "", mystery = true }
		local e = RunLog.entry(ballot({ ticket = sealed, votes = { ["1"] = 2, ["2"] = 2 } }))
		local won = RunLog.stamps(RunLog.resolve(e, "Cleared", { "Ana" }))
		expect(#won).toBe(3)
		expect(won[1].text).toBe("CLOSE CALL")
		expect(won[2].text).toBe("GAMBLED · PAID OFF")
		expect(won[3].text).toBe("UNANIMOUS")
		local lost = RunLog.stamps(RunLog.resolve(e, "Wiped", nil))
		expect(lost[1].text).toBe("GAMBLED · LOST")
	end)

	it("keeps the log in stop order, one entry per stop", function()
		local log = RunLog.append(nil, RunLog.entry(ballot({ stop = 2 })))
		log = RunLog.append(log, RunLog.entry(ballot({ stop = 1 })))
		log = RunLog.append(log, RunLog.entry(ballot({ stop = 3 })))
		log = RunLog.append(log, RunLog.resolve(RunLog.entry(ballot({ stop = 2 })), "Wiped", nil))
		expect(#log).toBe(3)
		expect(log[1].stop).toBe(1)
		expect(log[2].stop).toBe(2)
		expect(log[2].outcome).toBe("Wiped")
		expect(log[3].stop).toBe(3)
	end)

	it("is snapshot-safe, so a late joiner gets the same log", function()
		local sealed =
			{ archetype = MysteryConfig.Archetype, tier = 0, distanceKm = 55, hint = "", mystery = true }
		local log =
			RunLog.append(nil, RunLog.resolve(RunLog.entry(ballot({ stop = 1 })), "Cleared", { "Ana", "Bo" }))
		log = RunLog.append(
			log,
			RunLog.resolve(RunLog.entry(ballot({ stop = 2, ticket = sealed })), "Wiped", nil)
		)
		expect(wireSafe(log)).toBe(true)
		expect(deepCopy(log)).toEqual(log)
	end)

	it("totals km, coal and close calls for the run card", function()
		local log =
			RunLog.append(nil, RunLog.resolve(RunLog.entry(ballot({ stop = 1 })), "Cleared", { "Ana" }))
		log = RunLog.append(
			log,
			RunLog.resolve(
				RunLog.entry(ballot({
					stop = 2,
					coalBurned = 4.5,
					ticket = { archetype = "Halt", tier = 1, distanceKm = 25, hint = "" },
				})),
				"Cleared",
				{ "Ana", "Bo" }
			)
		)
		local t = RunLog.totals(log)
		expect(t.km).toBe(65)
		expect(t.coal).toBeCloseTo(10.5)
		expect(t.stops).toBe(2)
		expect(t.closeCalls).toBe(3)
		expect(RunLog.totals(nil).stops).toBe(0)
	end)

	it("names the final stamp", function()
		expect(RunLog.final("Victory", 11)).toBe("TERMINUS")
		expect(RunLog.final("Derailed", 6)).toBe("DERAILED AT STOP 6")
		expect(RunLog.final("Wiped", 4)).toBe("LOST AT STOP 4")
		expect(RunLog.final(nil, nil)).toBe("LOST AT STOP 1")
		local cleared = RunLog.append(nil, RunLog.resolve(RunLog.entry(ballot({ stop = 2 })), "Cleared", nil))
		expect(RunLog.endStop(cleared, 3)).toBe(3)
		local lost = RunLog.append(cleared, RunLog.resolve(RunLog.entry(ballot({ stop = 3 })), "Wiped", nil))
		expect(RunLog.endStop(lost, 4)).toBe(3)
		expect(RunLog.endStop(nil, nil)).toBe(1)
	end)
end)
