local Omens = require(Shared.Logic.Omens)
local Tuning = require(Shared.Config.Tuning)

local S = Tuning.Sky
local SEED = 424242

-- Every distinct omen over `slots` slots, sampled each half second.
local function survey(seed: number, dark: number, slots: number): { Omens.Omen }
	local found: { Omens.Omen } = {}
	local last = -1
	for t = 0, slots * S.OmenSlot, 0.5 do
		local omen = Omens.at(seed, t, dark)
		if omen and omen.start ~= last then
			last = omen.start
			table.insert(found, omen)
		end
	end
	return found
end

describe("Omens", function()
	it("gives every client the same omen at the same moment", function()
		for t = 0, 3000, 7.25 do
			local a = Omens.at(SEED, t, 0.9)
			local b = Omens.at(SEED, t, 0.9)
			expect(a == nil).toBe(b == nil)
			if a and b then
				expect(a.kind).toBe(b.kind)
				expect(a.start).toBe(b.start)
				expect(a.seed).toBe(b.seed)
			end
		end
	end)

	it("keeps the dusk and the dawn clear", function()
		expect(#survey(SEED, S.OmenMinDark - 0.01, 200)).toBe(0)
		expect(#survey(SEED, 0, 200)).toBe(0)
	end)

	it("comes about as often as the tuning says, more often deeper in the night", function()
		local slots = 600
		local deep = #survey(SEED, 1, slots) / slots
		local shallow = #survey(SEED, S.OmenMinDark, slots) / slots
		expect(deep).toBeBetween(S.OmenChance[2] - 0.08, S.OmenChance[2] + 0.08)
		expect(deep).toBeGreaterThan(shallow)
	end)

	it("only shows each kind once the night is deep enough for it", function()
		local minDark: { [string]: number } = {}
		for _, def in S.Omens do
			minDark[def.kind] = def.minDark
		end
		for _, dark in { 0.3, 0.5, 0.6, 0.85, 1 } do
			local seen: { [string]: boolean } = {}
			for _, omen in survey(SEED + 1, dark, 400) do
				expect(dark).toBeAtLeast(minDark[omen.kind])
				seen[omen.kind] = true
			end
			if dark >= 0.85 then
				for kind in minDark do
					expect(seen[kind]).toBe(true)
				end
			end
		end
	end)

	it("fits each omen inside its own slot, so no two overlap", function()
		for _, omen in survey(SEED + 2, 1, 300) do
			local slot = math.floor(omen.start / S.OmenSlot)
			expect(omen.start).toBeAtLeast(slot * S.OmenSlot)
			expect(omen.start + omen.duration).toBeAtMost((slot + 1) * S.OmenSlot + 1e-9)
		end
	end)

	it("reports progress through the omen", function()
		for _, omen in survey(SEED + 3, 1, 100) do
			local mid = Omens.at(SEED + 3, omen.start + omen.duration / 2, 1)
			expect(mid).toBeTruthy()
			expect((mid :: Omens.Omen).progress).toBeCloseTo(0.5, 1e-6)
			expect(Omens.at(SEED + 3, omen.start + omen.duration + 0.01, 1) == nil).toBe(true)
		end
	end)

	it("brings no lightning without a storm, and more with a stronger one", function()
		local function count(storm: number): number
			local n, last = 0, -1
			for t = 0, 3000, 0.05 do
				local strike = Omens.strike(SEED, t, storm)
				if strike and strike.start ~= last then
					last = strike.start
					n += 1
				end
			end
			return n
		end
		expect(count(0)).toBe(0)
		local full = count(1)
		local light = count(0.3)
		expect(full / (3000 / S.StrikeSlot)).toBeBetween(S.StrikeChance - 0.08, S.StrikeChance + 0.08)
		expect(full).toBeGreaterThan(light)
		expect(light).toBeGreaterThan(0)
	end)

	it("flashes hardest on the first stroke and goes dark between strikes", function()
		local seen = 0
		for t = 0, 600, 0.02 do
			local strike = Omens.strike(SEED, t, 1)
			local flash = Omens.flash(strike, t)
			expect(flash).toBeBetween(0, 1)
			if strike then
				seen += 1
				expect(Omens.flash(strike, strike.start)).toBe(1)
				expect(Omens.flash(strike, strike.start + 5)).toBe(0)
				expect(Omens.thunderDelay(strike)).toBeBetween(
					S.StrikeRange[1] / S.ThunderSpeed,
					S.StrikeRange[2] / S.ThunderSpeed
				)
			else
				expect(flash).toBe(0)
			end
		end
		expect(seen).toBeGreaterThan(0)
	end)

	it("lights the TallOnes at each reveal and throws a red bolt in the Bleed", function()
		local tall: Omens.Omen = { kind = "TallOnes", start = 100, duration = 6, progress = 0, seed = 7 }
		for _, mark in S.RevealAt do
			local t = tall.start + mark * tall.duration + 0.01
			local strike = Omens.omenStrike(tall, t)
			expect(strike).toBeTruthy()
			expect(Omens.flash(strike, t)).toBeGreaterThan(0.5)
		end
		expect(Omens.omenStrike(tall, tall.start - 1) == nil).toBe(true)
		local bleed: Omens.Omen = { kind = "Bleed", start = 0, duration = 10, progress = 0, seed = 9 }
		local strike = Omens.omenStrike(bleed, 4.5 + 0.01)
		expect(strike and strike.red).toBe(true)
		local hush: Omens.Omen = { kind = "Hush", start = 0, duration = 6, progress = 0, seed = 1 }
		for t = 0, 6, 0.1 do
			expect(Omens.omenStrike(hush, t) == nil).toBe(true)
		end
	end)
end)
