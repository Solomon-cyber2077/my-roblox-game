local Mystery = require(Shared.Logic.Mystery)
local RouteGen = require(Shared.Logic.RouteGen)
local Rng = require(Shared.Util.Rng)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local STOPS = Tuning.Run.StationCount

describe("RouteGen randomness", function()
	it("never shows the same station twice on one ballot, mystery included", function()
		for seed = 1, 300 do
			local previous = nil
			for leg = 1, STOPS do
				local options = RouteGen.options(seed, leg, STOPS, previous)
				local real = Mystery.pick(Rng.derive(seed, "hidden", leg), leg, STOPS, previous, options)
				if real then
					options[Mystery.place(options)] = real
				end
				local seen = {}
				for _, option in options do
					expect(seen[option.archetype]).toBe(nil)
					seen[option.archetype] = true
				end
				previous = options[1].archetype
			end
		end
	end)

	it("does not fix stop 1: many stations open runs across seeds", function()
		local first = {}
		local kinds = 0
		for seed = 1, 400 do
			for _, option in RouteGen.options(seed, 1, STOPS, nil) do
				if not first[option.archetype] then
					first[option.archetype] = true
					kinds += 1
				end
			end
		end
		local eligible = 0
		for _, id in Stations.Order do
			local arch = Stations.List[id]
			if arch.weight > 0 and not arch.terminus then
				eligible += 1
			end
		end
		expect(kinds).toBe(eligible)
	end)

	it("rolls a different ballot for different run seeds", function()
		local ballots = {}
		local distinct = 0
		for seed = 1, 50 do
			local key = ""
			for leg = 1, 3 do
				for _, option in RouteGen.options(seed * 7919, leg, STOPS, nil) do
					key ..= option.archetype .. ","
				end
			end
			if not ballots[key] then
				ballots[key] = true
				distinct += 1
			end
		end
		expect(distinct).toBeGreaterThan(40)
	end)

	it("stays the same for the same seed (clients and server agree)", function()
		local a = RouteGen.options(12345, 1, STOPS, nil)
		local b = RouteGen.options(12345, 1, STOPS, nil)
		expect(#a).toBe(#b)
		for i = 1, #a do
			expect(a[i].archetype).toBe(b[i].archetype)
		end
	end)
end)
