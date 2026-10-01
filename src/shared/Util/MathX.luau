--!strict
-- Small numeric helpers shared by gameplay math, UI and tests.

local MathX = {}

function MathX.clamp(x: number, lo: number, hi: number): number
	if x < lo then
		return lo
	elseif x > hi then
		return hi
	end
	return x
end

function MathX.saturate(x: number): number
	return MathX.clamp(x, 0, 1)
end

function MathX.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function MathX.inverseLerp(a: number, b: number, x: number): number
	if a == b then
		return 0
	end
	return (x - a) / (b - a)
end

function MathX.remap(x: number, inLo: number, inHi: number, outLo: number, outHi: number): number
	return MathX.lerp(outLo, outHi, MathX.saturate(MathX.inverseLerp(inLo, inHi, x)))
end

function MathX.smoothstep(edge0: number, edge1: number, x: number): number
	local t = MathX.saturate(MathX.inverseLerp(edge0, edge1, x))
	return t * t * (3 - 2 * t)
end

function MathX.round(x: number, step: number?): number
	local s = step or 1
	return math.floor(x / s + 0.5) * s
end

-- Moves `current` toward `target` by at most `delta`.
function MathX.approach(current: number, target: number, delta: number): number
	if current < target then
		return math.min(current + delta, target)
	end
	return math.max(current - delta, target)
end

-- Frame-rate independent exponential smoothing factor for a given half-life.
function MathX.damp(halfLife: number, dt: number): number
	return 1 - 2 ^ (-dt / math.max(halfLife, 1e-4))
end

return table.freeze(MathX)
