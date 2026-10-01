--!strict
-- Evaluates Line Mastery milestones against lifetime stats. The caller grants rewards.

local Shared = script.Parent.Parent
local Progression = require(Shared.Config.Progression)

local Milestones = {}

function Milestones.statValue(stats: { [string]: number }, rank: number, stat: string): number
	if stat == "rank" then
		return rank
	end
	return stats[stat] or 0
end

-- Ids of milestones whose goal is met but which are not yet in `claimed`, in config order.
function Milestones.newlyCompleted(
	stats: { [string]: number },
	rank: number,
	claimed: { [string]: boolean }
): { string }
	local out: { string } = {}
	for _, milestone in Progression.Milestones do
		if
			not claimed[milestone.id]
			and Milestones.statValue(stats, rank, milestone.stat) >= milestone.goal
		then
			table.insert(out, milestone.id)
		end
	end
	return out
end

function Milestones.progress(stats: { [string]: number }, rank: number, id: string): (number, number)
	local milestone = Progression.ById[id]
	return math.min(Milestones.statValue(stats, rank, milestone.stat), milestone.goal), milestone.goal
end

return table.freeze(Milestones)
