--!strict

-- Pure cosmetic progression and per-spawn variation for Hollow decorations.

local Rng = require(script.Parent.Parent.Util.Rng)

local GrimeLevel = {}

function GrimeLevel.forStop(stopIndex: number, stopCount: number, isTerminus: boolean): number
	if isTerminus then
		return 1
	end
	local count = math.max(1, stopCount)
	return math.clamp((stopIndex - 1) / count, 0, 1)
end

export type Variation = {
	tint: number,
	scale: number,
	accessory: number,
}

function GrimeLevel.variation(seed: number): Variation
	local rng = Rng.new(Rng.derive(seed, "hollow-cosmetics", "variation"))
	return {
		tint = rng:range(0.9, 1.1),
		scale = rng:range(0.9, 1.1),
		accessory = rng:int(1, 3),
	}
end

return table.freeze(GrimeLevel)
