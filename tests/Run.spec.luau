local Catalog = require(Shared.Logic.Catalog)
local Cosmetics = require(Shared.Config.Cosmetics)
local Economy = require(Shared.Logic.Economy)
local Milestones = require(Shared.Logic.Milestones)
local Rank = require(Shared.Logic.Rank)
local RouteGen = require(Shared.Logic.RouteGen)
local RunRules = require(Shared.Logic.RunRules)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local Vote = require(Shared.Logic.Vote)

local function ctx(overrides)
	local base = {
		nextStop = 1,
		stopCount = Tuning.Run.StationCount,
		readyCount = 0,
		lobbyCount = 0,
		crewAlive = 4,
		integrity = 100,
		playerCount = 4,
		cruiseSeconds = 48,
		dwellSeconds = 80,
		chaseSeconds = 6,
	}
	for k, v in overrides or {} do
		base[k] = v
	end
	return base
end

describe("RunRules", function()
	it("walks a full stop in order", function()
		local c = ctx()
		local phase = "Boarding"
		local seen = {}
		for _ = 1, 7 do
			phase = RunRules.next(phase, c)
			table.insert(seen, phase)
		end
		expect(table.concat(seen, ",")).toBe("Junction,Cruise,Arrival,Dwell,LastCall,Departure,Junction")
	end)

	it("ends at the Terminus after the last stop", function()
		local c = ctx({ nextStop = Tuning.Run.StationCount + 1 })
		expect(RunRules.next("Arrival", c)).toBe("Terminus")
		expect(RunRules.next("Terminus", c)).toBe("RunEnd")
		expect(RunRules.duration("Junction", c)).toBe(Tuning.Run.FinalJunctionSeconds)
	end)

	it("splits the dwell so Last Call is always 15 seconds", function()
		local c = ctx({ dwellSeconds = 80 })
		expect(RunRules.duration("Dwell", c) + RunRules.duration("LastCall", c)).toBe(80)
	end)

	it("guards: wipe, derail and empty server", function()
		local phase, outcome = RunRules.guard("Dwell", ctx({ crewAlive = 0 }))
		expect(phase).toBe("RunEnd")
		expect(outcome).toBe("Wiped")
		phase, outcome = RunRules.guard("Cruise", ctx({ integrity = 0 }))
		expect(outcome).toBe("Derailed")
		phase = RunRules.guard("Cruise", ctx({ playerCount = 0 }))
		expect(phase).toBe("Lobby")
		expect((RunRules.guard("Dwell", ctx()))).toBe(nil)
	end)

	it("starts the countdown at half the lobby ready and cancels below it", function()
		expect((RunRules.guard("Lobby", ctx({ lobbyCount = 5, readyCount = 3 })))).toBe("Countdown")
		expect((RunRules.guard("Lobby", ctx({ lobbyCount = 5, readyCount = 2 })))).toBe(nil)
		expect((RunRules.guard("Countdown", ctx({ lobbyCount = 5, readyCount = 2 })))).toBe("Lobby")
		expect((RunRules.guard("Lobby", ctx({ lobbyCount = 1, readyCount = 1 })))).toBe("Countdown")
	end)
end)

describe("RouteGen", function()
	it("offers two options, three on wide junctions, and only eligible archetypes", function()
		for seed = 1, 20 do
			local previous = nil
			for leg = 1, Tuning.Run.StationCount do
				local options = RouteGen.options(seed, leg, Tuning.Run.StationCount, previous)
				local expected = if Tuning.Run.WideJunctions[leg] then 3 else 2
				expect(#options).toBe(expected)
				local seen = {}
				local short = false
				for _, option in options do
					local arch = Stations.List[option.archetype]
					expect(arch.minStation).toBeAtMost(leg)
					expect(seen[option.archetype]).toBe(nil)
					seen[option.archetype] = true
					expect(option.tier).toBeBetween(1, if leg <= 2 then 2 else 3)
					expect(option.distanceKm).toBeBetween(3, 8)
					short = short or option.distanceKm <= 5
				end
				expect(short).toBe(true)
				previous = options[1].archetype
			end
		end
	end)

	it("routes the last leg to the Terminus", function()
		local options = RouteGen.options(1, Tuning.Run.StationCount + 1, Tuning.Run.StationCount, "Halt")
		expect(#options).toBe(1)
		expect(options[1].archetype).toBe("Terminus")
	end)
end)

describe("Vote", function()
	local options = {
		{ archetype = "Halt", tier = 1, distanceKm = 6, hint = "" },
		{ archetype = "CoalYard", tier = 2, distanceKm = 4, hint = "" },
		{ archetype = "Market", tier = 2, distanceKm = 4, hint = "" },
	}
	it("picks the majority", function()
		expect(Vote.tally({ a = 1, b = 1, c = 2 }, options, 0)).toBe(1)
	end)
	it("breaks ties toward the shorter leg, then by the coin", function()
		expect(Vote.tally({ a = 1, b = 2 }, options, 0.9)).toBe(2)
		expect(Vote.tally({}, options, 0)).toBe(2)
		expect(Vote.tally({}, options, 0.99)).toBe(3)
	end)
	it("ignores invalid ballots", function()
		expect(Vote.tally({ a = 9, b = 1.5, c = 1 }, options, 0)).toBe(1)
	end)
end)

describe("Economy", function()
	it("pays the published rates", function()
		local tally = Economy.emptyTally()
		tally.stationsDeparted = 5
		tally.coalDelivered = 34
		tally.partsDelivered = 12
		tally.relicBrass = 30
		tally.rescues = 1
		local payout = Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = false })
		expect(payout.brass).toBe(30 + 6 + 4 + 30 + 10)
		expect(payout.xp).toBe(payout.brass + Tuning.Economy.XpPerRun)
	end)
	it("doubles the first run of the day up to the cap", function()
		local tally = Economy.emptyTally()
		tally.relicBrass = 500
		local payout = Economy.payout(tally, { outcome = nil, dailyBonus = true, soloCharter = false })
		expect(payout.brass).toBe(500 + Tuning.Economy.DailyBonusCap)
	end)
	it("pays solo charter runs at 60%", function()
		local tally = Economy.emptyTally()
		tally.stationsDeparted = 10
		local payout = Economy.payout(tally, { outcome = nil, dailyBonus = false, soloCharter = true })
		expect(payout.brass).toBe(36)
	end)
	it("pays a victory bonus", function()
		local tally = Economy.emptyTally()
		tally.reachedTerminus = true
		expect(Economy.payout(tally, { outcome = "Victory", dailyBonus = false, soloCharter = false }).brass).toBe(
			80
		)
	end)
end)

describe("Rank", function()
	it("inverts the XP curve", function()
		for r = 1, 60 do
			expect(Rank.fromXp(Rank.xpFor(r))).toBe(r)
			if r > 1 then
				expect(Rank.fromXp(Rank.xpFor(r) - 1)).toBe(r - 1)
			end
		end
		expect(Rank.xpFor(2)).toBe(120)
	end)
end)

describe("Catalog and milestones", function()
	it("owns defaults without buying", function()
		for _, id in Cosmetics.Defaults do
			expect(Catalog.isOwned({}, id)).toBe(true)
		end
	end)
	it("checks rank, price and unlock path", function()
		expect((Catalog.canBuyWithBrass({}, 5000, 1, "lantern_aurora", 0))).toBe("Rank")
		expect((Catalog.canBuyWithBrass({}, 10, 30, "lantern_aurora", 0))).toBe("Brass")
		expect((Catalog.canBuyWithBrass({}, 99999, 99, "lantern_ember", 0))).toBe("NotForBrass")
		expect((Catalog.canBuyWithBrass({}, 99999, 99, "trail_wraith", 0))).toBe("NotForBrass")
		expect((Catalog.canBuyWithBrass({ hat_conductor = true }, 99999, 99, "hat_conductor", 0))).toBe(
			"Owned"
		)
	end)
	it("rotates three discounted Brass items per day", function()
		local a = Catalog.dailySpecials(20000)
		local b = Catalog.dailySpecials(20000)
		expect(#a).toBe(3)
		for i = 1, 3 do
			expect(a[i]).toBe(b[i])
			expect(Cosmetics.ById[a[i]].brass ~= nil).toBe(true)
		end
		local special = a[1]
		expect(Catalog.brassPrice(special, 20000)).toBeLessThan(Cosmetics.ById[special].brass)
	end)
	it("completes milestones once", function()
		local stats = { coalDelivered = 120, stationsDeparted = 3 }
		local done = Milestones.newlyCompleted(stats, 1, {})
		expect(table.find(done, "Stoker") ~= nil).toBe(true)
		expect(table.find(done, "AllAboard") ~= nil).toBe(true)
		local again = Milestones.newlyCompleted(stats, 1, { Stoker = true, AllAboard = true })
		expect(#again).toBe(0)
	end)
end)
