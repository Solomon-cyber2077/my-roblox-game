--!strict
-- Crew Rank from lifetime XP:  XP(L) = round(Scale * (L - 1) ^ Exponent), up to Max.

local Shared = script.Parent.Parent
local Progression = require(Shared.Config.Progression)

local Rank = {}

function Rank.xpFor(rank: number): number
	local curve = Progression.Rank
	local r = math.clamp(math.floor(rank), 1, curve.Max)
	return math.floor(curve.Scale * (r - 1) ^ curve.Exponent + 0.5)
end

function Rank.fromXp(xp: number): number
	local curve = Progression.Rank
	local rank = 1
	while rank < curve.Max and Rank.xpFor(rank + 1) <= xp do
		rank += 1
	end
	return rank
end

-- Returns rank, XP earned inside the current rank, and XP the current rank spans (0 at max).
function Rank.progress(xp: number): (number, number, number)
	local rank = Rank.fromXp(xp)
	if rank >= Progression.Rank.Max then
		return rank, 0, 0
	end
	local floor = Rank.xpFor(rank)
	return rank, xp - floor, Rank.xpFor(rank + 1) - floor
end

return table.freeze(Rank)
