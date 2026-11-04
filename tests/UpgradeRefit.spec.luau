local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Leaks = require(Shared.Logic.Leaks)
local Ledger = require(Shared.Logic.Ledger)
local Stations = require(Shared.Config.Stations)
local Upgrades = require(Shared.Config.Upgrades)

local function anyStation()
	local ids = {}
	for id, arch in Stations.List do
		if not arch.terminus then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return Stations.List[ids[1]]
end

describe("Workshop upgrades bought mid-stop", function()
	it("Floodlamps and Steam Whistle refit a stop's params to match params made with the level", function()
		local arch = anyStation()
		for _, d in { 0, 0.5, 1 } do
			local before = DifficultyModel.params(d, arch, 3, {}, 2)
			local want = DifficultyModel.params(d, arch, 3, { Floodlamps = 1, SteamWhistle = 1 }, 2)
			expect(DifficultyModel.refit(before, "Floodlamps", 1)).toBe(true)
			expect(DifficultyModel.refit(before, "SteamWhistle", 1)).toBe(true)
			expect(before.safeBand).toBe(want.safeBand)
			expect(before.fogDps).toBeCloseTo(want.fogDps)
			expect(before.whistleHold).toBe(want.whistleHold)
			expect(before.chaseWindow).toBeCloseTo(want.chaseWindow)
		end
	end)

	it("a second level stacks the same way as params() does", function()
		local arch = anyStation()
		local p = DifficultyModel.params(0.7, arch, 2, { Floodlamps = 1 }, 4)
		local want = DifficultyModel.params(0.7, arch, 2, { Floodlamps = 2 }, 4)
		DifficultyModel.refit(p, "Floodlamps", 1)
		expect(p.safeBand).toBe(want.safeBand)
		expect(p.fogDps).toBeCloseTo(want.fogDps)
	end)

	it("leaves params alone for upgrades that are not hazard ones", function()
		local arch = anyStation()
		local p = DifficultyModel.params(0.5, arch, 2, {}, 1)
		local copy = table.clone(p)
		for _, id in { "CoalBunker", "PorterSatchels", "ArmorPlating", "FireboxBaffles" } do
			expect(DifficultyModel.refit(p, id, 1)).toBe(false)
		end
		for k, v in copy do
			expect(p[k]).toBe(v)
		end
	end)

	it("Armour Plating thins the leaks still to burst, keeping the earliest", function()
		local bursts = { 10, 20, 30, 40 }
		-- 4 x 0.75 = 3 exactly
		local kept = Leaks.thin(bursts, 1, 0.99)
		expect(#kept).toBe(3)
		expect(kept[1]).toBe(10)
		expect(kept[3]).toBe(30)
		expect(#bursts).toBe(4) -- the input list is not changed
		-- 3 x 0.75 = 2.25: the roll settles the quarter
		expect(#Leaks.thin({ 1, 2, 3 }, 1, 0.1)).toBe(3)
		expect(#Leaks.thin({ 1, 2, 3 }, 1, 0.5)).toBe(2)
		expect(#Leaks.thin({}, 1, 0)).toBe(0)
	end)

	it("Firebox Baffles shrinks only the coal still to burn on this leg", function()
		local m = Upgrades.Effects.BurnMultiplierPerLevel
		expect(Ledger.refitLegCost(10, 4, 1)).toBeCloseTo(4 + 6 * m)
		expect(Ledger.refitLegCost(10, 10, 1)).toBe(10)
		expect(Ledger.refitLegCost(10, 0, 2)).toBeCloseTo(10 * m * m)
	end)
end)
