local Grab = require(Shared.Logic.Grab)
local LootRoll = require(Shared.Logic.LootRoll)
local Tuning = require(Shared.Config.Tuning)
local Injury = require(Shared.Config.Injury)

local P = Tuning.Grab.PinStage

describe("Grab.pinStage", function()
	it("runs fast checks first, then fades the check out to the death", function()
		local from, to = Grab.pinStage(100)
		expect(from).toBe(100 + P.FadeDelay)
		expect(to).toBe(from + P.FadeSeconds)
		expect(P.Speed).toBeLessThan(1) -- the second stage is faster
		expect(P.MaxMisses).toBeGreaterThan(0)
	end)

	it("fades from clear to gone over the window", function()
		local from, to = Grab.pinStage(0)
		expect(Grab.pinFade(0, from, to)).toBe(0)
		expect(Grab.pinFade(from, from, to)).toBe(0)
		expect(math.abs(Grab.pinFade((from + to) / 2, from, to) - 0.5)).toBeLessThan(1e-9)
		expect(Grab.pinFade(to, from, to)).toBe(1)
		expect(Grab.pinFade(to + 5, from, to)).toBe(1)
		expect(Grab.pinFade(3, 4, 4)).toBe(0)
		expect(Grab.pinFade(4, 4, 4)).toBe(1)
	end)
end)

describe("LootRoll boost", function()
	local function share(weights, item: string): number
		local total, mine = 0, 0
		for _, w in weights do
			total += w.weight
			if w.value == item then
				mine += w.weight
			end
		end
		return mine / total
	end

	it(
		"makes Flashbulbs likelier at a stop the Stoker comes to, and nothing else changes without it",
		function()
			local plain = LootRoll.weights("ToolChest", "Mid", nil)
			local boosted =
				LootRoll.weights("ToolChest", "Mid", nil, { Flashbulb = Tuning.BruteRemake.FlashbulbBoost })
			expect(share(boosted, "Flashbulb")).toBeGreaterThan(share(plain, "Flashbulb"))
			local same = LootRoll.weights("ToolChest", "Mid", nil, nil)
			for i, w in plain do
				expect(same[i].weight).toBe(w.weight)
			end
		end
	)

	it("keeps the Stoker's lanterns snuffed only at rescue distance", function()
		local heat = Tuning.BruteRemake.Heat
		expect(heat.Snuff).toBeLessThan(heat.Pull)
		expect(heat.Pull).toBeLessThan(heat.Strike)
		expect(heat.Snuff).toBe(Injury.Rescue.Reach + 2) -- out at rescue distance, a step before it
	end)
end)
