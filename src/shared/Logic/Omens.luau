--!strict
--[[
	Omens and storms in the night sky, scheduled from the run seed and the server
	clock so every client sees the same bolt, the same blink and the same figures at
	the same moment: "did you see that?" always has an answer.

	  * omens: server time is cut into slots (Tuning.Sky.OmenSlot seconds). Each slot
	    rolls, from its own Rng stream, whether an omen falls in it, which kind and
	    when. How likely, and which kinds may appear, depends on `dark`: how deep into
	    the night the run is (0 at dusk and dawn, 1 at the darkest hour).
	  * strikes: lightning on shorter slots; `storm` (0..1) scales the chance. A
	    strike is a few seeded pulses of light; its distance sets the thunder delay.
	    The TallOnes and the Bleed bring their own strikes.

	Every slot draws the same numbers whatever `dark` or `storm` are, so the schedule
	never shifts as the night deepens; they only gate what is drawn.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)

export type Kind = "Hush" | "TallOnes" | "Blink" | "Bleed" | "Eye"

export type Omen = {
	kind: Kind,
	start: number, -- server time
	duration: number,
	progress: number, -- 0..1 at the time asked
	seed: number, -- for the omen's own details (where the figures stand)
}

export type Pulse = { at: number, width: number, peak: number } -- seconds after the strike starts

export type Strike = {
	start: number,
	seed: number, -- the bolt's shape
	pulses: { Pulse },
	distance: number, -- studs from the train
	azimuth: number, -- radians around the train: 0 ahead (+X), pi/2 the platform side (+Z)
	red: boolean, -- a Bleed strike
}

local S = Tuning.Sky

local Omens = {}

local function omenIn(seed: number, slot: number, dark: number): Omen?
	local rng = Rng.new(Rng.derive(seed, "omen", slot))
	local roll, pick, at, detail = rng:next(), rng:next(), rng:next(), rng:nextUint32()
	local chance = S.OmenChance[1] + (S.OmenChance[2] - S.OmenChance[1]) * math.clamp(dark, 0, 1)
	if dark < S.OmenMinDark or roll >= chance then
		return nil
	end
	local total = 0
	for _, def in S.Omens do
		if dark >= def.minDark then
			total += def.weight
		end
	end
	local chosen = nil
	local remaining = pick * total
	for _, def in S.Omens do
		if dark >= def.minDark then
			chosen = def
			remaining -= def.weight
			if remaining < 0 then
				break
			end
		end
	end
	if chosen == nil then
		return nil
	end
	return {
		kind = chosen.kind :: Kind,
		start = slot * S.OmenSlot + at * (S.OmenSlot - chosen.duration),
		duration = chosen.duration,
		progress = 0,
		seed = detail,
	}
end

-- The omen under way at server time `t`, or nil.
function Omens.at(seed: number, t: number, dark: number): Omen?
	local omen = omenIn(seed, math.floor(t / S.OmenSlot), dark)
	if omen and t >= omen.start and t < omen.start + omen.duration then
		omen.progress = (t - omen.start) / omen.duration
		return omen
	end
	return nil
end

-- A strike's flicker: a hard flash, a dimmer return stroke or two, each fading fast.
local function makeStrike(rng: Rng.Rng, start: number, red: boolean): Strike
	local pulses: { Pulse } = { { at = 0, width = rng:range(0.07, 0.12), peak = 1 } }
	local at = 0
	for _ = 1, rng:int(1, 3) do
		at += rng:range(0.09, 0.26)
		table.insert(pulses, { at = at, width = rng:range(0.05, 0.12), peak = rng:range(0.35, 0.85) })
	end
	return {
		start = start,
		seed = rng:nextUint32(),
		pulses = pulses,
		distance = rng:range(S.StrikeRange[1], S.StrikeRange[2]),
		azimuth = rng:range(0, math.pi * 2),
		red = red,
	}
end

-- The lightning strike flickering at server time `t` in a storm of strength `storm` (0..1).
function Omens.strike(seed: number, t: number, storm: number): Strike?
	local slot = math.floor(t / S.StrikeSlot)
	local rng = Rng.new(Rng.derive(seed, "strike", slot))
	local roll, at = rng:next(), rng:next()
	if roll >= math.clamp(storm, 0, 1) * S.StrikeChance then
		return nil
	end
	local start = slot * S.StrikeSlot + at * (S.StrikeSlot - S.StrikeSeconds)
	if t < start or t >= start + S.StrikeSeconds then
		return nil
	end
	return makeStrike(rng, start, false)
end

--[[
	The strikes an omen brings: the TallOnes are shown by lightning at Tuning.Sky.RevealAt,
	and the Bleed throws one red bolt at its height. Returns the one flickering at `t`.
]]
function Omens.omenStrike(omen: Omen?, t: number): Strike?
	if omen == nil then
		return nil
	end
	local marks: { number } = if omen.kind == "TallOnes"
		then S.RevealAt
		elseif omen.kind == "Bleed" then { 0.45 }
		else {}
	for i, mark in marks do
		local start = omen.start + mark * omen.duration
		if t >= start and t < start + S.StrikeSeconds then
			local rng = Rng.new(Rng.derive(omen.seed, "reveal", i))
			return makeStrike(rng, start, omen.kind == "Bleed")
		end
	end
	return nil
end

-- How bright the strike is at server time `t`, 0..1.
function Omens.flash(strike: Strike?, t: number): number
	if strike == nil then
		return 0
	end
	local since = t - strike.start
	local value = 0
	for _, pulse in strike.pulses do
		local k = (since - pulse.at) / pulse.width
		if k >= 0 and k < 1 then
			value = math.max(value, pulse.peak * (1 - k) * (1 - k))
		end
	end
	return value
end

-- Seconds between a strike's flash and its thunder.
function Omens.thunderDelay(strike: Strike): number
	return strike.distance / S.ThunderSpeed
end

return Omens
