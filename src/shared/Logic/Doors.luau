--!strict
--[[
	Door-forcing (docs/FINAL-DESIGN.md Prompt 2). Pure: Services/BuildingService owns the doors and
	runs one episode per door per forcing; HollowService asks for it.

	  forcing(seed, stop)   whether this stop's Hollows can force doors: from FromStop on, on Chance
	                        of stops, from the stop's own seed (every tutorial tier alike)
	  episode               one timer per door per episode: BaseSeconds, plus HoldSeconds once if a
	                        crew member holds the door, however many Hollows queue on it and however
	                        many crew hold; a forced door then stays open OpenSeconds before it may shut
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)

local D = Tuning.DoorForce

local Doors = {}

export type Episode = {
	startedAt: number,
	endsAt: number,
	held: boolean, -- the one hold extension has been used
	queue: { any }, -- the Hollows waiting on this door, first is the one forcing it
}

function Doors.forcing(stationSeed: number, stop: number): boolean
	if stop < D.FromStop then
		return false
	end
	return Rng.new(Rng.derive(stationSeed, "doorForce", stop)):next() < D.Chance
end

function Doors.start(now: number, hollow: any): Episode
	return { startedAt = now, endsAt = now + D.BaseSeconds, held = false, queue = { hollow } }
end

-- Another Hollow on the same door waits in the queue: no timer of its own.
function Doors.join(episode: Episode, hollow: any)
	if table.find(episode.queue, hollow) == nil then
		table.insert(episode.queue, hollow)
	end
end

function Doors.leave(episode: Episode, hollow: any)
	local i = table.find(episode.queue, hollow)
	if i then
		table.remove(episode.queue, i)
	end
end

-- A crew member holds the door: HoldSeconds more, once per episode. True if it extended.
function Doors.hold(episode: Episode): boolean
	if episode.held then
		return false
	end
	episode.held = true
	episode.endsAt += D.HoldSeconds
	return true
end

function Doors.done(episode: Episode, now: number): boolean
	return now >= episode.endsAt
end

-- The share of the episode gone (drives the door's shake).
function Doors.progress(episode: Episode, now: number): number
	local span = episode.endsAt - episode.startedAt
	return if span > 0 then math.clamp((now - episode.startedAt) / span, 0, 1) else 1
end

-- Whether a forced door may shut again at `now` (opened at `openedAt`).
function Doors.mayClose(openedAt: number, now: number): boolean
	return now - openedAt >= D.OpenSeconds
end

return table.freeze(Doors)
