--!strict
--[[
	Footsteps as pure rules: which surface a foot comes down on, how often a step falls at a
	speed, and which recording plays (Config/Audio Step<Surface><n>). Controllers/
	FootstepController feeds it what it finds under each crew member.

	  TrainFloor  anything that is part of the train
	  Snow        snow or ice, or a yard slab at a stop in snowy country (its sheet of snow
	              does not collide, so the slab under it is what the foot finds)
	  Plank       the platform's boards and anything wooden: floors, decks, stairs
	  Gravel      the rest: the yard's ground, cobbles, cinders, stone
]]

local Foley = require(script.Parent.Parent.Config.Foley)
local Tuning = require(script.Parent.Parent.Config.Tuning)

export type Surface = "TrainFloor" | "Snow" | "Plank" | "Gravel"
export type Landing = { kind: "Soft" | "Hard", gain: number }
export type Ground = {
	material: string, -- Enum.Material name
	onTrain: boolean,
	slabKind: string?, -- Safe (the platform), Floor or Foundation, when it is a station slab top
	snowy: boolean, -- the docked stop is in snowy country
}

local Footsteps = {}

local WOOD = { Wood = true, WoodPlanks = true }
local SNOW = { Snow = true, Glacier = true, Ice = true }

function Footsteps.surface(ground: Ground): Surface
	if ground.onTrain then
		return "TrainFloor"
	end
	if SNOW[ground.material] or (ground.snowy and ground.slabKind == "Floor") then
		return "Snow"
	end
	if ground.slabKind == "Safe" or WOOD[ground.material] then
		return "Plank"
	end
	return "Gravel"
end

-- Seconds between steps at `speed` studs a second, or nil when standing still.
function Footsteps.interval(speed: number): number?
	local T = Tuning.Footsteps
	if speed < T.MinSpeed then
		return nil
	end
	return math.clamp(T.Stride / speed, T.MinInterval, T.MaxInterval)
end

-- The first free crew slot (1..#Boots) given the slots in use: a joiner gets the lowest free one,
-- and nobody's slot changes during a run. Past four crew, slots wrap.
function Footsteps.freeSlot(used: { [number]: boolean }): number
	local boots = #Tuning.Footsteps.Boots
	for slot = 1, boots do
		if not used[slot] then
			return slot
		end
	end
	local n = 0
	for _ in used do
		n += 1
	end
	return n % boots + 1
end

-- A crew slot's boots: the base pitch and level its steps play at (nil slot: the first boots).
function Footsteps.boots(slot: number?): { name: string, pitch: number, gain: number }
	local boots = Tuning.Footsteps.Boots
	return boots[((slot or 1) - 1) % #boots + 1]
end

-- The cue for the `count`th step on `surface`: the takes in turn, so no take plays twice running.
function Footsteps.cue(surface: string, count: number): string
	local takes = Tuning.Footsteps.Takes[surface] or 1
	local prefix = if surface == "TrainFloor" then "StepTrain" else "Step" .. surface
	return prefix .. tostring(count % takes + 1)
end

-- How a fall coming down at `speed` studs a second lands (Config/Foley): nil below LandSoft, Soft
-- up to LandHard, Hard from it; the level over the step takes rises with the speed and stops there.
function Footsteps.landing(speed: number): Landing?
	if speed < Foley.LandSoft then
		return nil
	end
	local u = math.clamp((speed - Foley.LandSoft) / (Foley.LandHard - Foley.LandSoft), 0, 1)
	return {
		kind = if speed >= Foley.LandHard then "Hard" else "Soft",
		gain = Foley.LandGainMin + (Foley.LandGainMax - Foley.LandGainMin) * u,
	}
end

-- Whether leaving the ground at `rise` studs a second upward is a jump worth a sound, `since`
-- seconds after this body's last one.
function Footsteps.jumped(rise: number, since: number): boolean
	return rise >= Foley.JumpRise and since >= Foley.JumpGap
end

-- Breaking into a sprint: whether a body `wasFast` is fast now at `speed`, and whether this is the
-- moment it broke into a run (one scuff). Between SprintRearm and SprintFrom it keeps what it was.
function Footsteps.sprint(wasFast: boolean, speed: number): (boolean, boolean)
	if speed >= Foley.SprintFrom then
		return true, not wasFast
	end
	if speed < Foley.SprintRearm then
		return false, false
	end
	return wasFast, false
end

return table.freeze(Footsteps)
