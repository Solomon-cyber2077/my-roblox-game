--!strict
--[[
	The readability floor as pure rules (Config/Tuning Visibility). Controllers/
	AtmosphereController clamps the composed sky to it through Scenery/Sky.floor, so no
	night, fog or chase ever takes the ground and obstacles round a player below it.

	  radius(setting)   the floor's reach in studs: the default, or a Settings slider's value
	                    clamped into RadiusMin..RadiusMax
	  scale(radius)     how far above the default floor that reach lifts the ambient floors
	  floor(rgb, r)     an ambient floor colour (0..255 channels) for a reach
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local V = Tuning.Visibility

local Visibility = {}

function Visibility.radius(setting: any): number
	if type(setting) ~= "number" or setting ~= setting then
		return V.Radius
	end
	return math.clamp(setting, V.RadiusMin, V.RadiusMax)
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

return table.freeze(Visibility)
