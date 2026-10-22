--!strict
--[[
	The Stalk state's rules (docs/FINAL-DESIGN.md Prompt 2). Pure: Services/HollowService senses the
	world and moves the body; this module decides. Every distance comes from the server-owned
	Tuning.Stalk.ReferenceRadius r = 30, never from a player's Visibility slider.

	  band         shadow points between 0.8r and 1.1r (24-33 studs) from the target
	  facing       the target's root looks within FacingDegrees of the Hollow, from FacingRange or less
	               (the glance turns the camera, not the root, so it never counts)
	  step         one think of a stalk: an immediate commit (Surge, too close, another Hollow seized
	               the target), the maximum stalk (it overrides facing), or a timed back-turn commit
	               once the minimum stalk has run (halved when the target is alone and unlit)
	  guard        the first-strike guard: warning time with line of sight within 1.2r (36) per
	               Hollow per target; under WarnSeconds no Windup, lunge or strike, and no closing
	               inside GuardDistance on its own

	              sensed, beyond CommitRange, budget left
	   Prowl  ------------------------------------------>  Stalk
	     ^   <------------------------------------------    |
	     |    lost for Persistence, stunned (no Stalk 6 s)   | commit: Surge / close / seized /
	     |                                                   | max stalk / back turned
	     +-------------------------  Hunt  <-----------------+
	       lost for Persistence        | guarded: coil, hold off at 16, no Windup/lunge/strike
	                                   v  guard met
	                                 Windup -> strike
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local MathX = require(Shared.Util.MathX)

local S = Tuning.Stalk
local C = Difficulty.Stalk

local Stalk = {}

export type Settings = {
	min: number,
	max: number,
	backTurned: number,
	commitRange: number,
	aloneRadius: number,
}

export type Track = {
	elapsed: number, -- seconds of stalk so far
	unfaced: number, -- uninterrupted seconds the target has not faced it
}

export type Sense = {
	dt: number,
	faced: boolean,
	alone: boolean, -- no crewmate within AloneRadius
	lit: boolean, -- the target stands in a lamp pool or SafeLight
	distance: number,
	surge: boolean,
	seized: boolean, -- another Hollow has the target
}

local function blend(pair: { number }, d: number): number
	return MathX.lerp(pair[1], pair[2], MathX.saturate(d))
end

function Stalk.settings(d: number): Settings
	return {
		min = blend(C.MinStalkSeconds, d),
		max = blend(C.MaxStalkSeconds, d),
		backTurned = blend(C.BackTurnedSeconds, d),
		commitRange = blend(C.CommitRange, d),
		aloneRadius = blend(C.AloneRadius, d),
	}
end

function Stalk.radius(): number
	return S.ReferenceRadius
end

-- The shadow band's inner and outer distance from the target.
function Stalk.band(): (number, number)
	return S.BandNear * S.ReferenceRadius, S.BandFar * S.ReferenceRadius
end

function Stalk.inBand(distance: number): boolean
	local near, far = Stalk.band()
	return distance >= near and distance <= far
end

function Stalk.exposureRange(): number
	return S.ExposureScale * S.ReferenceRadius
end

-- The design's invariant: the band's inner edge clears the furthest proximity commit by 4 studs.
function Stalk.bandClearsCommit(): boolean
	local near = Stalk.band()
	return near >= math.max(C.CommitRange[1], C.CommitRange[2]) + 4
end

--[[
	Whether the target faces the Hollow: (lookX, lookZ) is the target root's look vector and
	(toX, toZ) the offset from the target to the Hollow, both flat.
]]
function Stalk.facing(lookX: number, lookZ: number, toX: number, toZ: number): boolean
	local distance = math.sqrt(toX * toX + toZ * toZ)
	local look = math.sqrt(lookX * lookX + lookZ * lookZ)
	if distance > S.FacingRange or look < 1e-6 then
		return false
	end
	if distance < 1e-6 then
		return true
	end
	local cos = (lookX * toX + lookZ * toZ) / (distance * look)
	return cos >= math.cos(math.rad(S.FacingDegrees))
end

function Stalk.newTrack(): Track
	return { elapsed = 0, unfaced = 0 }
end

--[[
	One think of a stalk. Returns the updated track and the commit reason, or nil to keep stalking:
	"surge", "seized", "close" (immediate), "max" (the maximum stalk, faced or not) or "back"
	(timed: the minimum stalk has run and the target's back has been turned long enough).
]]
function Stalk.step(track: Track, sense: Sense, settings: Settings): (Track, string?)
	if sense.surge then
		return track, "surge"
	elseif sense.seized then
		return track, "seized"
	elseif sense.distance <= settings.commitRange then
		return track, "close"
	end
	local nextTrack = {
		elapsed = track.elapsed + sense.dt,
		unfaced = if sense.faced then 0 else track.unfaced + sense.dt,
	}
	if nextTrack.elapsed >= settings.max then
		return nextTrack, "max"
	end
	local threshold = settings.backTurned * (if sense.alone and not sense.lit then 0.5 else 1)
	if nextTrack.elapsed >= settings.min and nextTrack.unfaced >= threshold then
		return nextTrack, "back"
	end
	return nextTrack, nil
end

-- Warning time after one think: it grows only with line of sight within the exposure range.
function Stalk.expose(exposure: number, dt: number, sight: boolean, distance: number): number
	if sight and distance <= Stalk.exposureRange() then
		return exposure + dt
	end
	return exposure
end

-- True while the first-strike guard holds: no Windup, lunge, strike or grab yet.
function Stalk.guarded(exposure: number): boolean
	return exposure < S.WarnSeconds
end

-- How far a guarded Hollow may advance on its own this think: never inside GuardDistance.
function Stalk.advance(distance: number, step: number): number
	return math.clamp(distance - S.GuardDistance, 0, math.max(step, 0))
end

-- Whether `other` (a crew member `otherDistance` away) takes over from a target `current` away.
function Stalk.switches(current: number, otherDistance: number): boolean
	return otherDistance < S.SwitchShare * current
end

return table.freeze(Stalk)
