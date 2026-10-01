local Loot = require(Shared.Config.Loot)
local LootRoll = require(Shared.Logic.LootRoll)
local Stations = require(Shared.Config.Stations)

describe("Loot", function()
	it("pays 1x near, 2x mid and about 4x far for every container kind", function()
		for kind, def in Loot.Containers do
			if not def.farOnly then
				local near = LootRoll.expectedValue(kind, "Near", nil)
				local mid = LootRoll.expectedValue(kind, "Mid", nil)
				local far = LootRoll.expectedValue(kind, "Far", nil)
				expect(mid / near).toBeBetween(1.9, 2.1)
				expect(far / near).toBeBetween(3.4, 4.6)
			end
		end
	end)

	it("rolls the same items for the same container seed", function()
		local halt = Stations.List.Halt
		local seed = LootRoll.seedFor(1234, 7)
		local a = LootRoll.roll("Crate", "Mid", halt, seed)
		local b = LootRoll.roll("Crate", "Mid", halt, seed)
		expect(#a).toBe(2)
		for i = 1, #a do
			expect(a[i]).toBe(b[i])
		end
	end)

	it("shifts loot toward the archetype's bias", function()
		local yard = Stations.List.CoalYard
		local works = Stations.List.SignalWorks
		local coalShare = function(arch)
			local weights = LootRoll.weights("Crate", "Near", arch)
			local total, coal = 0, 0
			for _, entry in weights do
				total += entry.weight
				if Loot.Categories[entry.value] == "coal" then
					coal += entry.weight
				end
			end
			return coal / total
		end
		expect(coalShare(yard)).toBeGreaterThan(coalShare(works))
	end)

	it("takes longer to search further from the train", function()
		expect(LootRoll.holdSeconds("Crate", "Far")).toBeGreaterThan(LootRoll.holdSeconds("Crate", "Near"))
	end)
end)
