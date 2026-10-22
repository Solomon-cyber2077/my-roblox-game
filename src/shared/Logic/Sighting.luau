--!strict
--[[
	Stop 1's scripted sighting on a first run (docs/FINAL-DESIGN.md Prompt 5; Config/Tutorial
	Sighting). Pure: HollowService places the Stalker and feeds each think; this module says when it
	withdraws.

	  seen      the first moment anyone had line of sight starts MinSeconds (3 s); nothing withdraws it
	            before that
	  withdraw  after the minimum: faced for FacedSeconds (1 s), or every living crew member off the
	            train has had SeenSeconds (1.5 s) of line of sight; and at MaxSeconds (12 s) after it
	            appeared, whatever happens. Crew still aboard are not waited for
	  distance  the point it stands on: Near..Far studs from the first player off, else the nearest
	            legal point up to Fallback
]]

local Shared = script.Parent.Parent
local Tutorial = require(Shared.Config.Tutorial)

local S = Tutorial.Sighting

local Sighting = {}

export type State = {
	age: number, -- seconds since it appeared
	firstSeenAt: number?, -- age when anyone first had line of sight
	faced: number, -- uninterrupted seconds it has been faced (after anyone saw it)
	seen: { [number]: number }, -- line-of-sight seconds per crew member (userId)
}

export type Watcher = {
	id: number,
	offTrain: boolean, -- alive and off the train (aboard crew are not waited for)
	sight: boolean, -- line of sight this think
	facing: boolean, -- their root faces it
}

function Sighting.new(): State
	return { age = 0, firstSeenAt = nil, faced = 0, seen = {} }
end

-- One think of `dt` seconds. Returns the state and the reason it withdraws now, or nil.
function Sighting.step(state: State, dt: number, watchers: { Watcher }): (State, string?)
	state.age += dt
	local anyFacing = false
	for _, w in watchers do
		if w.sight then
			state.seen[w.id] = (state.seen[w.id] or 0) + dt
			if state.firstSeenAt == nil then
				state.firstSeenAt = state.age
			end
			if w.facing then
				anyFacing = true
			end
		end
	end
	state.faced = if anyFacing then state.faced + dt else 0
	if state.age >= S.MaxSeconds then
		return state, "time"
	end
	local first = state.firstSeenAt
	if first == nil or state.age - first < S.MinSeconds then
		return state, nil
	end
	if state.faced >= S.FacedSeconds then
		return state, "faced"
	end
	local waiting = false
	local anyOff = false
	for _, w in watchers do
		if w.offTrain then
			anyOff = true
			if (state.seen[w.id] or 0) < S.SeenSeconds then
				waiting = true
			end
		end
	end
	if anyOff and not waiting then
		return state, "seen"
	end
	return state, nil
end

-- Whether a point `distance` studs from the first player off is in the preferred band.
function Sighting.preferred(distance: number): boolean
	return distance >= S.Near and distance <= S.Far
end

-- Whether it is a legal fallback distance.
function Sighting.fallback(distance: number): boolean
	return distance > 0 and distance <= S.Fallback
end

return table.freeze(Sighting)
