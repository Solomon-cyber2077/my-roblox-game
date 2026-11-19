--!strict
--[[
	The uncanny weight of the Stoker (Tuning.BruteRemake.Uncanny): pure timing, HollowAnimator poses him.

	  still     how long he has stood still (horizontal speed under 2 studs a second: a shuffle on the spot still counts)
	  unfold    0 stooped as he walks .. 1 drawn up to his full height, standing still past StillAfter
	  overturn  his head's extra yaw after losing his prey: past a neck's limit, held, then back; nil when done
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)

local U = Tuning.BruteRemake.Uncanny

local StokerMotion = {}

function StokerMotion.still(stillFor: number, speed: number, dt: number): number
	return if speed < 2 then stillFor + dt else 0
end

function StokerMotion.unfold(u: number, stillFor: number, dt: number): number
	if stillFor >= U.StillAfter then
		return math.min(1, u + U.UnfoldRate * dt)
	end
	return math.max(0, u - U.FoldRate * dt)
end

-- `t` seconds after he lost sight of them, turning toward `side` (-1 or 1).
function StokerMotion.overturn(t: number, side: number): number?
	local reach = U.LookMax / U.LookSpeed
	if t < reach then
		return side * U.LookSpeed * t
	end
	t -= reach
	if t < U.LookHold then
		return side * U.LookMax
	end
	t -= U.LookHold
	local back = U.LookMax - U.LookBack * t
	if back <= 0 then
		return nil
	end
	return side * back
end

return StokerMotion
