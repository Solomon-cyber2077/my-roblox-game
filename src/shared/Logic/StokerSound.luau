--!strict
--[[
	The Stoker's sound set (code id Brute, while Tuning.BruteRemake is on): which takes a footfall, a
	shovel drag and a breath play. Controllers/HollowAnimator plays them; the takes are Config/Audio
	Stoker*.

	  footfall  a heavy heel on every plant, over the ground's own crunch (Logic/Footsteps surfaces);
	            the stiff burnt left leg lands harder and lower, with more of the deep thud under it
	  drag      the shovel blade scrapes on the right (shovel-arm) step, loudest on the hunt; now and
	            then dry rust cracks off it
	  breath    a bellows out-stroke at the brightest of the embers' breathing and an in-stroke at the
	            dimmest, so the glow and the sound move together (faster on the hunt)
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local S = Tuning.BruteRemake.Sound

export type Step = { heel: string, gain: number, pitch: number, thud: number, ground: string }

local StokerSound = {}

local GROUND: { [string]: { string } } = {
	Gravel = { "StokerGroundGravel1", "StokerGroundGravel2" },
	Snow = { "StokerGroundSnow1", "StokerGroundSnow2" },
	Plank = { "StokerGroundPlank" },
	TrainFloor = { "StokerGroundPlank" },
	Stone = { "StokerGroundStone" },
}
StokerSound.Ground = GROUND
StokerSound.Drags = { "StokerDrag1", "StokerDrag2", "StokerDrag3" }
StokerSound.Rust = { "StokerRust1", "StokerRust2", "StokerRust3" }

local function pick(list: { string }, count: number): string
	return list[(count - 1) % #list + 1]
end

-- The `count`th footfall, `foot` "L" or "R", on `surface`; `roll` in 0..1 sets the pitch jitter.
function StokerSound.step(foot: string, surface: string, count: number, roll: number): Step
	local side = if foot == "L" then S.Left else S.Right
	return {
		heel = if foot == "L" then "StokerHeelL" else "StokerHeelR",
		gain = side.gain,
		pitch = side.pitch * (1 + (roll * 2 - 1) * S.Jitter),
		thud = side.thud,
		ground = pick(GROUND[surface] or GROUND.Gravel, count),
	}
end

-- The shovel drags on the right foot only.
function StokerSound.drags(foot: string): boolean
	return foot == "R"
end

-- The `count`th drag's take and level in `state`; `roll` in 0..1 sheds rust under RustShare.
function StokerSound.drag(count: number, state: string, roll: number): (string, number, string?)
	local gain = S.Drag[state] or S.Drag.Other
	local rust = if roll < S.RustShare then pick(StokerSound.Rust, count) else nil
	return pick(StokerSound.Drags, count), gain, rust
end

-- The embers' breathing rate in `state` (radians a second).
function StokerSound.breathRate(state: string): number
	return if state == "Hunt" then S.BreathRate.Hunt else S.BreathRate.Rest
end

local TAU = 2 * math.pi
local function crossed(from: number, to: number, mark: number): boolean
	-- did the angle pass `mark` (mod 2 pi) going from `from` to `to`?
	if to <= from then
		return false
	end
	local k = math.ceil((from - mark) / TAU)
	return mark + k * TAU <= to and mark + k * TAU > from
end

-- The bellows strokes between two times (the embers' breathing is sin(now * rate + seed)): "Out" at
-- its peak, "In" at its trough.
function StokerSound.breaths(before: number, after: number, rate: number, seed: number): { string }
	local out: { string } = {}
	local from, to = before * rate + seed, after * rate + seed
	if crossed(from, to, math.pi / 2) then
		table.insert(out, "Out")
	end
	if crossed(from, to, 3 * math.pi / 2) then
		table.insert(out, "In")
	end
	return out
end

return StokerSound
