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

-- Every requirement of a milestone (one, or its `all` list).
function Milestones.requirements(milestone: Progression.Milestone): { Progression.Requirement }
	return milestone.all or { { stat = milestone.stat, goal = milestone.goal } }
end

-- Whether every requirement is met (an AND milestone needs all of them).
function Milestones.met(stats: { [string]: number }, rank: number, milestone: Progression.Milestone): boolean
	for _, req in Milestones.requirements(milestone) do
		if Milestones.statValue(stats, rank, req.stat) < req.goal then
			return false
		end
	end
	return true
end

-- Ids of milestones whose goal is met but which are not yet in `claimed`, in config order.
function Milestones.newlyCompleted(
	stats: { [string]: number },
	rank: number,
	claimed: { [string]: boolean }
): { string }
	local out: { string } = {}
	for _, milestone in Progression.Milestones do
		if not claimed[milestone.id] and Milestones.met(stats, rank, milestone) then
			table.insert(out, milestone.id)
		end
	end
	return out
end

-- Progress toward the first unmet requirement (the last one once all are met).
function Milestones.progress(stats: { [string]: number }, rank: number, id: string): (number, number)
	local reqs = Milestones.requirements(Progression.ById[id])
	local shown = reqs[#reqs]
	for _, req in reqs do
		if Milestones.statValue(stats, rank, req.stat) < req.goal then
			shown = req
			break
		end
	end
	return math.min(Milestones.statValue(stats, rank, shown.stat), shown.goal), shown.goal
end

return table.freeze(Milestones)
