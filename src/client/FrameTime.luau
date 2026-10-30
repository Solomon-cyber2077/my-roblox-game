--!strict
--[[
	This client's smoothed frame time in seconds (RenderStepped), for stamping skill-check presses
	(SkillCheck.frameLead): the marker a player times a press against was drawn a frame ago.
]]

local RunService = game:GetService("RunService")

local FrameTime = {}

local SMOOTH = 0.1 -- share of each new frame in the average
local average = 1 / 60

RunService.RenderStepped:Connect(function(dt)
	-- one long hitch (a load, a tab switch) should not swing the stamp
	average += (math.min(dt, 0.25) - average) * SMOOTH
end)

function FrameTime.get(): number
	return average
end

return FrameTime
