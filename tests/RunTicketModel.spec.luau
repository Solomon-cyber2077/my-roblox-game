local RunTicketModel = require(Shared.Logic.RunTicketModel)

local function log(stops: number)
	local list = {}
	for i = 1, stops do
		table.insert(list, {
			stop = i,
			distanceKm = 5,
			coalBurned = 3,
			outcome = "Cleared",
			haul = { coal = 2, parts = 1, relics = 0, downs = 0 },
		})
	end
	return list
end

describe("RunTicketModel", function()
	it("gives one hero line per outcome and the stamp", function()
		local won = RunTicketModel.build({ outcome = "Victory", log = log(3), me = "1" })
		expect(won.hero).toBe("REACHED THE TERMINUS")
		expect(won.won).toBe(true)
		expect(won.stamp).toBe("TERMINUS")
		local lost = RunTicketModel.build({ outcome = "Wiped", log = log(1), nextStop = 1, me = "1" })
		expect(lost.hero).toBe("THE CREW WAS LOST")
		expect(lost.stamp).toBe("LOST AT STOP 1")
	end)

	it("never carries more than three supporting stats", function()
		local data = RunTicketModel.build({ outcome = "Wiped", log = log(4), me = "1" })
		expect(#data.stats).toBeAtMost(RunTicketModel.MaxStats)
		expect(data.stats[1].value).toBe("4")
		expect(data.stats[2].value).toBe("12")
	end)

	it("names your own cause of death", function()
		local data = RunTicketModel.build({
			outcome = "Wiped",
			log = log(1),
			me = "1",
			crew = { ["1"] = { name = "Ada", status = "Eliminated", cause = "Smothered" } },
		})
		expect(data.causeTitle).toBe("LOST IN THE FOG")
	end)

	it("never promises a solo player a crewmate", function()
		for _, cause in { "Taken", "Smothered", "Fell", "Wrecked", "LeftBehind", "Other", "Disconnected" } do
			local data = RunTicketModel.build({
				outcome = "Wiped",
				log = log(1),
				me = "1",
				crew = { ["1"] = { name = "Solo", status = "Eliminated", cause = cause } },
			})
			expect(string.find(string.lower(data.causeLine), "crewmate", 1, true)).toBe(nil)
			expect(string.find(string.lower(data.causeLine), "bring you back", 1, true)).toBe(nil)
		end
	end)

	it("reads Wrecked for those still aboard when the train failed, and MADE IT on a win", function()
		local wrecked = RunTicketModel.build({
			outcome = "Derailed",
			log = log(2),
			me = "1",
			crew = { ["1"] = { name = "A", status = "Aboard", cause = "Wrecked" } },
		})
		expect(wrecked.causeTitle).toBe("WRECKED")
		local won = RunTicketModel.build({
			outcome = "Victory",
			log = log(5),
			me = "1",
			crew = { ["1"] = { name = "A", status = "Aboard" } },
		})
		expect(won.causeTitle).toBe("MADE IT")
	end)

	it("lists the crew by initials, lost ones marked", function()
		local data = RunTicketModel.build({
			outcome = "Victory",
			log = log(1),
			me = "1",
			crew = {
				["1"] = { name = "Tame Giant", status = "Aboard" },
				["2"] = { name = "player_two", status = "Eliminated", cause = "Taken" },
			},
		})
		expect(data.stats[3].value).toBe("TG · PT")
		expect(data.crew[2].lost).toBe(true)
		expect(RunTicketModel.initials("TameGiant")).toBe("TG")
		expect(RunTicketModel.initials("ada")).toBe("AD")
		expect(RunTicketModel.initials("")).toBe("?")
	end)
end)
