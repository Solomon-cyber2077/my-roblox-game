--!strict
--[[
	The train's door threshold as one player feels it (Controllers/ThresholdController).

	out      0..1, how far the station's own light and sound have come in. Off the train it
	         rises over Tuning.Threshold.FadeOut seconds, back aboard it falls over FadeIn: a
	         crossfade in time, never a cut and never a dark screen.
	shelter  0..1, how much the carriage walls stand between you and the night. Stepping aboard
	         it closes almost at once (MuffleIn); stepping off it opens with the crossfade.
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local T = Tuning.Threshold

local Threshold = {}

-- Whether a point, in a box's own space, lies inside the box (half extents hx, hy, hz) grown
-- by `grow` studs on every side (negative shrinks it).
function Threshold.within(
	x: number,
	y: number,
	z: number,
	hx: number,
	hy: number,
	hz: number,
	grow: number
): boolean
	return math.abs(x) <= hx + grow and math.abs(y) <= hy + grow and math.abs(z) <= hz + grow
end

-- The grow to test with: once inside you must step a margin past the door to be out, and
-- the other way round, so standing on the sill never flickers between the two.
function Threshold.grow(inside: boolean): number
	return if inside then T.Margin else -T.Margin
end

function Threshold.stepOut(out: number, inside: boolean, dt: number): number
	if inside then
		return math.max(out - dt / T.FadeIn, 0)
	end
	return math.min(out + dt / T.FadeOut, 1)
end

-- The crossfade's curve: slow at both ends, so neither world arrives with a jolt.
function Threshold.ease(out: number): number
	local t = math.clamp(out, 0, 1)
	return t * t * (3 - 2 * t)
end

function Threshold.stepShelter(shelter: number, inside: boolean, out: number, dt: number): number
	if inside then
		return math.min(shelter + dt / T.MuffleIn, 1)
	end
	return math.max(math.min(shelter, 1 - Threshold.ease(out)), 0)
end

return Threshold
