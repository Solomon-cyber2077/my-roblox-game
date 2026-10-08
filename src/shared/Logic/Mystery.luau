--!strict
--[[
	The mystery ticket's rules (numbers in Config/Mystery). Pure.

	  offers    whether this junction has one: never before FirstLeg, never two junctions in a
	            row, PityAfter junctions without one forces it, otherwise a roll in [0, 1) under Chance
	  record    the history after a junction
	  pick      the real station behind the seal, from RouteGen on a seed only the server knows
	            (the run seed is public, so RouteGen on it would let any client read the seal)
	  redact    the public ticket: the archetype stand-in, no tier, no hint, the real distance
	  place     where the sealed ticket goes in the ballot: appended, or over the longest line
	            when the ballot is already full
	  sealed    the public destination while sealed: distance and coal only
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config.Mystery)
local Stations = require(Shared.Config.Stations)
local Types = require(Shared.Types)
local Rng = require(Shared.Util.Rng)
local RouteGen = require(script.Parent.RouteGen)

type RouteOption = Types.RouteOption

export type History = { since: number, last: boolean }

local Mystery = {}

Mystery.MaxOptions = 3
Mystery.Attempts = 8

function Mystery.newHistory(): History
	return { since = 0, last = false }
end

function Mystery.offers(history: History, leg: number, stopCount: number, roll: number): boolean
	if not Config.Enabled or leg < Config.FirstLeg or leg > stopCount or history.last then
		return false
	end
	if history.since >= Config.PityAfter then
		return true
	end
	return roll < Config.Chance
end

function Mystery.record(history: History, offered: boolean): History
	return { since = if offered then 0 else history.since + 1, last = offered }
end

-- The real station: the first RouteGen pick on the hidden seed that is not already on the ballot,
-- re-rolled on derived seeds a few times; past that (a thin pool on an early leg) a repeat is allowed.
function Mystery.pick(
	hiddenSeed: number,
	leg: number,
	stopCount: number,
	previous: string?,
	visible: { RouteOption }
): RouteOption?
	local taken: { [string]: boolean } = {}
	for _, option in visible do
		taken[option.archetype] = true
	end
	local chosen: RouteOption? = nil
	local fallback: RouteOption? = nil
	for attempt = 1, Mystery.Attempts do
		for _, option in RouteGen.options(Rng.derive(hiddenSeed, attempt), leg, stopCount, previous) do
			if not Stations.List[option.archetype].terminus then
				fallback = fallback or option
				if not taken[option.archetype] then
					chosen = option
					break
				end
			end
		end
		if chosen then
			break
		end
	end
	chosen = chosen or fallback
	if chosen == nil then
		return nil
	end
	local maxTier = if leg <= 2 then 2 else Config.MaxTier
	return {
		archetype = chosen.archetype,
		tier = math.clamp(chosen.tier + Config.DangerBias, 1, maxTier),
		distanceKm = chosen.distanceKm,
		hint = chosen.hint,
	}
end

function Mystery.redact(option: RouteOption): RouteOption
	return {
		archetype = Config.Archetype,
		tier = 0,
		distanceKm = option.distanceKm,
		hint = "",
		mystery = true,
	}
end

-- The index the sealed ticket takes: a new last slot, or the longest line's when the ballot is full.
function Mystery.place(options: { RouteOption }): number
	if #options < Mystery.MaxOptions then
		return #options + 1
	end
	local index = #options
	for i, option in options do
		if option.distanceKm >= options[index].distanceKm then
			index = i
		end
	end
	return index
end

function Mystery.sealed(distanceKm: number, coalCost: number): Types.Destination
	return {
		archetype = Config.Archetype,
		name = Config.Name,
		tier = 0,
		distanceKm = distanceKm,
		difficulty = 0,
		coalCost = coalCost,
		terminus = false,
		mystery = true,
		sealed = true,
	}
end

-- Whether a public option is the stand-in rather than a real station.
function Mystery.isSealed(option: RouteOption?): boolean
	return option ~= nil and option.mystery == true
end

function Mystery.lootMul(lootMul: number): number
	return lootMul * Config.LootBonus
end

return table.freeze(Mystery)
