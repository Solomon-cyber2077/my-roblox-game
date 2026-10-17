--!strict
--[[
	The readability floor as pure rules (Config/Tuning Visibility). Controllers/
	AtmosphereController clamps the composed sky to it through Scenery/Sky.floor, so no
	night, fog or chase ever takes the ground and obstacles round a player below it.

	  radius(setting)   the floor's reach in studs: the default, or a Settings slider's value
	                    clamped into RadiusMin..RadiusMax
	  scale(radius)     how far above the default floor that reach lifts the ambient floors
	  floor(rgb, r)     an ambient floor colour (0..255 channels) for a reach
	  chaseStep         the chase sequence: Calm -> Chase -> Hold (escaped, waiting) -> Relief
	  chaseLook         what the sequence shows at a time: dim, relief and the black flicker
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local V = Tuning.Visibility

local Visibility = {}

function Visibility.radius(setting: any): number
	-- Settings save it as a whole-number string ("24"); the slider sets a number
	local studs = if type(setting) == "string" then tonumber(setting) else setting
	if type(studs) ~= "number" or studs ~= studs then
		return V.Default
	end
	return math.clamp(studs, V.RadiusMin, V.RadiusMax)
end

-- 1 at the default reach, rising to 1.35 at the slider's top: more reach, more ambient.
function Visibility.scale(radius: number): number
	local t = (radius - V.Radius) / math.max(V.RadiusMax - V.Radius, 1)
	return 1 + 0.35 * math.clamp(t, 0, 1)
end

function Visibility.floor(channels: { number }, radius: number): (number, number, number)
	local k = Visibility.scale(radius)
	return math.min(channels[1] * k, 255), math.min(channels[2] * k, 255), math.min(channels[3] * k, 255)
end

export type ChaseMode = "Calm" | "Chase" | "Hold" | "Relief"
export type Chase = {
	mode: ChaseMode,
	since: number, -- when this mode began
	flickerAt: number, -- when the last black flicker began (only a fresh chase flickers)
}
export type ChaseLook = {
	dim: number, -- 0..1 the chase's dark
	relief: number, -- 0..1 the false relief, fading
	black: number, -- 0..1 the flicker's black over the screen
}

local C = V.Chase

function Visibility.chaseStart(): Chase
	return { mode = "Calm", since = -math.huge, flickerAt = -math.huge }
end

-- The sequence after one more look at whether you are being chased at `now`.
function Visibility.chaseStep(state: Chase, chased: boolean, now: number): Chase
	local mode = state.mode
	if chased then
		if mode == "Chase" then
			return state
		elseif mode == "Hold" then
			return { mode = "Chase", since = now, flickerAt = state.flickerAt }
		end
		return { mode = "Chase", since = now, flickerAt = now }
	end
	if mode == "Chase" then
		return { mode = "Hold", since = now, flickerAt = state.flickerAt }
	elseif mode == "Hold" and now - state.since >= C.Hold then
		return { mode = "Relief", since = now, flickerAt = state.flickerAt }
	elseif mode == "Relief" and now - state.since >= C.ReliefFade then
		return { mode = "Calm", since = now, flickerAt = state.flickerAt }
	end
	return state
end

function Visibility.flicker(age: number): number
	local black = 0
	if age < 0 then
		return 0
	end
	for _, key in C.Flicker do
		if age >= key[1] then
			black = key[2]
		end
	end
	return black
end

function Visibility.chaseLook(state: Chase, now: number): ChaseLook
	local mode = state.mode
	local held = mode == "Chase" or mode == "Hold"
	local relief = if mode == "Relief" then 1 - math.clamp((now - state.since) / C.ReliefFade, 0, 1) else 0
	return {
		dim = if held then 1 else 0,
		relief = relief,
		black = Visibility.flicker(now - state.flickerAt),
	}
end

return table.freeze(Visibility)
