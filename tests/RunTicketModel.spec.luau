local RunTicketModel = require(Shared.Logic.RunTicketModel)
local Rank = require(Shared.Logic.Rank)

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
		expect(won.hero).toBe("ALL STOPS MADE")
		expect(won.won).toBe(true)
		expect(won.stamp).toBe("LONG LINE")
		local lost = RunTicketModel.build({ outcome = "Wiped", log = log(1), nextStop = 1, me = "1" })
		expect(lost.hero).toBe("THE CREW WAS LOST")
		expect(lost.stamp).toBe("ENTERED, NOT RECALLED")
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
		for _, cause in
			{ "Taken", "Smothered", "Fell", "Wrecked", "Stranded", "LeftBehind", "Other", "Disconnected" }
		do
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
	it("names the next Crew Rank and the XP left to it, and stops at the top", function()
		expect(RunTicketModel.nextLine(0)).toBe(`NEXT: CREW RANK 2 IN {Rank.xpFor(2)} XP`)
		expect(RunTicketModel.nextLine(Rank.xpFor(2))).toBe(
			`NEXT: CREW RANK 3 IN {Rank.xpFor(3) - Rank.xpFor(2)} XP`
		)
		expect(RunTicketModel.nextLine(Rank.xpFor(1000))).toBe(nil)
	end)
	it("tells a player who cashed out apart from the crew who were lost", function()
		local cashed = { ["2"] = "Tame Giant" }
		local crew = { ["1"] = { name = "Ann Bell", status = "Eliminated", cause = "Taken" } }
		local mine = RunTicketModel.build({
			outcome = "Wiped",
			log = log(5),
			me = "2",
			crew = crew,
			cashedOut = cashed,
		})
		expect(mine.causeTitle).toBe("CASHED OUT")
		expect(mine.stats[3].value).toBe("AB · TG")
		local theirs = RunTicketModel.build({
			outcome = "Wiped",
			log = log(5),
			me = "1",
			crew = crew,
			cashedOut = cashed,
		})
		expect(theirs.causeTitle == "CASHED OUT").toBe(false)
		local won = RunTicketModel.build({
			outcome = "Victory",
			log = log(10),
			me = "2",
			crew = {},
			cashedOut = cashed,
		})
		expect(won.causeTitle).toBe("CASHED OUT")
		local last =
			RunTicketModel.build({ outcome = "CashedOut", log = log(5), me = "2", cashedOut = cashed })
		expect(last.hero).toBe("THE CREW CASHED OUT")
		expect(last.crew[1].lost).toBe(false)
	end)
end)
