--!strict
-- Prompt 8: one Brass loop, Line Mastery as the record (Config/Cosmetics record, Logic/Catalog,
-- Logic/Milestones), and the first-run Brass check printed for the report.

local Cosmetics = require(Shared.Config.Cosmetics)
local Progression = require(Shared.Config.Progression)
local Tuning = require(Shared.Config.Tuning)
local Catalog = require(Shared.Logic.Catalog)
local Economy = require(Shared.Logic.Economy)
local Milestones = require(Shared.Logic.Milestones)

local STATUS = { "hat_lampcap", "trail_brass", "lantern_aurora", "hat_topper", "livery_royal" }
local KEEP_PRICE = { "lantern_signal", "hat_conductor", "hat_goggles", "trail_steam" }

describe("Line Mastery record", function()
	it("takes the Brass price off the five status items and gates them by record", function()
		for _, id in STATUS do
			local def = Cosmetics.ById[id]
			expect(def.brass).toBe(nil)
			expect(def.record ~= nil).toBe(true)
			expect(Progression.ById[def.milestone :: string].reward.cosmetic).toBe(id)
		end
		for _, id in KEEP_PRICE do
			expect(Cosmetics.ById[id].brass ~= nil).toBe(true)
		end
	end)

	it("gives every cosmetic one coherent unlock path", function()
		for _, def in Cosmetics.List do
			local paths = 0
			for _, key in { "default", "brass", "milestone", "robux", "gamePass", "charterStamps", "npc" } do
				if (def :: any)[key] ~= nil then
					paths += 1
				end
			end
			expect(paths).toBe(1)
			expect((def :: any).rank).toBe(nil)
			if def.milestone then
				expect(Progression.ById[def.milestone] ~= nil).toBe(true)
			end
		end
	end)

	it("needs both halves of livery_royal", function()
		local royal = Progression.ById.RoyalRoad
		local def = Cosmetics.ById.livery_royal
		local one = { longVictories = 1, stationsDeparted = 49 }
		local other = { longVictories = 0, stationsDeparted = 80 }
		local both = { longVictories = 1, stationsDeparted = 50 }
		expect(Milestones.met(one, 1, royal)).toBe(false)
		expect(Milestones.met(other, 1, royal)).toBe(false)
		expect(Milestones.met(both, 1, royal)).toBe(true)
		expect(Catalog.recordMet(one, def)).toBe(false)
		expect(Catalog.recordMet(both, def)).toBe(true)
		expect(Catalog.recordText(def)).toBe("1 Long Line finish + 50 stops departed")
		-- the bar shows the half still owed
		local value, goal = Milestones.progress(one, 1, "RoyalRoad")
		expect(value).toBe(49)
		expect(goal).toBe(50)
	end)

	it("grants each record milestone once", function()
		local stats = { victories = 5, bestStation = 8, clutchBoards = 5 }
		local first = Milestones.newlyCompleted(stats, 1, {})
		for _, id in { "DeepLine", "ClutchHand", "AuroraWatch", "Stationmaster" } do
			expect(table.find(first, id) ~= nil).toBe(true)
		end
		local claimed = {}
		for _, id in first do
			claimed[id] = true
		end
		expect(#Milestones.newlyCompleted(stats, 1, claimed)).toBe(0)
	end)

	it("never discounts a status item as a daily special", function()
		for day = 20000, 20030 do
			for _, id in Catalog.dailySpecials(day) do
				expect(Cosmetics.ById[id].record).toBe(nil)
			end
		end
	end)
end)

describe("First Brass purchase", function()
	-- The report's check: a new Hand's first two Short Line Reliefs, run 1 a wipe at stop 4 (the
	-- day's first run), run 2 a Short Line finish, buys the cheapest Brass item. Milestone Brass
	-- counts: it is paid in the same summary.
	it("buys the cheapest Brass item within two Short Line runs", function()
		local cheapest = math.huge
		for _, def in Cosmetics.List do
			if def.brass and not def.default then
				cheapest = math.min(cheapest, def.brass)
			end
		end
		local stats: { [string]: number } = {}
		local claimed: { [string]: boolean } = {}
		local total = 0
		local function run(
			departed: number,
			coal: number,
			parts: number,
			relic: number,
			won: boolean,
			daily: boolean
		)
			local tally = Economy.emptyTally()
			tally.stationsDeparted = departed
			tally.coalDelivered = coal
			tally.partsDelivered = parts
			tally.relicBrass = relic
			tally.reachedTerminus = won
			local payout = Economy.payout(tally, {
				outcome = if won then "Victory" else "Wiped",
				dailyBonus = daily,
				soloCharter = false,
			})
			total += payout.brass
			stats.stationsDeparted = (stats.stationsDeparted or 0) + departed
			stats.bestStation = math.max(stats.bestStation or 0, departed)
			stats.victories = (stats.victories or 0) + (if won then 1 else 0)
			for _, id in Milestones.newlyCompleted(stats, 1, claimed) do
				claimed[id] = true
				total += Progression.ById[id].reward.brass or 0
			end
			return total
		end
		local after1 = run(3, 20, 5, 20, false, true)
		local after2 = run(Tuning.Run.Routes.Short, 30, 10, 20, true, false)
		print(`  [report] Brass after run 1 {after1}, after run 2 {after2}; cheapest Brass item {cheapest}`)
		expect(after2 >= cheapest).toBe(true)
	end)
end)
