--!strict
--[[
	Kinematics of the moving world. The train is static; stations slide past it.

	Arrival (constant braking):   x(t) = X0 * (1 - t / Ta)^2,  X0 = v * Ta / 2
	Departure (constant pull):    x(t) = -a * t^2 / 2
	x is the station's offset along the track (+X is ahead of the locomotive).
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local MathX = require(Shared.Util.MathX)

local Motion = {}

function Motion.arrivalDistance(): number
	return Tuning.Motion.CruiseSpeed * Tuning.Run.ArrivalSeconds / 2
end

function Motion.arrivalOffset(t: number): number
	local u = MathX.saturate(t / Tuning.Run.ArrivalSeconds)
	return Motion.arrivalDistance() * (1 - u) ^ 2
end

-- Signed velocity along X (negative: the station moves toward the back of the train).
function Motion.arrivalVelocity(t: number): number
	local total = Tuning.Run.ArrivalSeconds
	local u = MathX.saturate(t / total)
	return -2 * Motion.arrivalDistance() / total * (1 - u)
end

function Motion.departureOffset(t: number, accel: number): number
	local s = math.max(t, 0)
	return -0.5 * accel * s * s
end

function Motion.departureVelocity(t: number, accel: number): number
	return -accel * math.max(t, 0)
end

-- How far behind the platform a runner standing still ends up when the chase window closes.
function Motion.chaseDrift(window: number, accel: number): number
	return -Motion.departureOffset(window, accel)
end

return table.freeze(Motion)
