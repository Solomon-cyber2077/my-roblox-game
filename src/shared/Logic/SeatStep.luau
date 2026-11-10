--!strict
--[[
	Walk-on seats (hall and train): a seat takes you only when you step up onto its cushion,
	not when you brush its side walking past (owner's playtest, 11-08: "you have to get on it
	though, so that players dont get annoyed by constantly sitting").

	onCushion  x, y, z: the feet (the character's lowest point) in the seat part's own space
	           (seat.CFrame:PointToObjectSpace); sx, sy, sz: the seat part's size. True when the
	           feet are no lower than Slack under the cushion's top and inside its footprint,
	           grown by Margin each way.
]]

local SeatStep = {}

SeatStep.Slack = 0.6 -- studs the feet may sit below the cushion top (a step up still lands short)
SeatStep.Margin = 0.4 -- studs the footprint grows each way (a heel over the edge still counts)

-- Studs from the bottom of the root part to the feet: an R6 body's legs hang a fixed 2 under the
-- root with HipHeight 0 (the crew are R6); an R15 body stands on HipHeight.
function SeatStep.legs(humanoid: any): number
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		return 2
	end
	return humanoid.HipHeight
end

function SeatStep.onCushion(x: number, y: number, z: number, sx: number, sy: number, sz: number): boolean
	if y < sy / 2 - SeatStep.Slack then
		return false
	end
	return math.abs(x) <= sx / 2 + SeatStep.Margin and math.abs(z) <= sz / 2 + SeatStep.Margin
end

return table.freeze(SeatStep)
