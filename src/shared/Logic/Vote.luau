--!strict
--[[
	Junction vote tally.
	1. The option with the most votes wins.
	2. A tie, or no votes at all, goes to the shortest leg ("the driver takes the short line").
	3. A tie on distance is broken by the server's seeded coin, passed in as tieBreak in [0, 1).
]]

local Shared = script.Parent.Parent
local Types = require(Shared.Types)

local Vote = {}

function Vote.counts(votes: { [string]: number }, optionCount: number): { number }
	local counts = table.create(optionCount, 0)
	for _, choice in votes do
		if type(choice) == "number" and choice >= 1 and choice <= optionCount and choice % 1 == 0 then
			counts[choice] += 1
		end
	end
	return counts
end

function Vote.tally(votes: { [string]: number }, options: { Types.RouteOption }, tieBreak: number): number
	local counts = Vote.counts(votes, #options)
	local best = -1
	for _, count in counts do
		best = math.max(best, count)
	end
	local candidates: { number } = {}
	for i, count in counts do
		if count == best then
			table.insert(candidates, i)
		end
	end
	if #candidates == 1 then
		return candidates[1]
	end
	local shortest = math.huge
	for _, i in candidates do
		shortest = math.min(shortest, options[i].distanceKm)
	end
	local finalists: { number } = {}
	for _, i in candidates do
		if options[i].distanceKm == shortest then
			table.insert(finalists, i)
		end
	end
	local pick = math.clamp(math.floor(tieBreak * #finalists) + 1, 1, #finalists)
	return finalists[pick]
end

return table.freeze(Vote)
