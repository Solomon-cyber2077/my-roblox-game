--!strict
--[[
	The hunted cue (Tuning.HuntedCue, UI/HuntedCue). Pure: where on the screen's edge to show a Hollow
	that is hunting this player from off-screen, and how strongly.

	  place(x, y, inFront, w, h)   from a viewport point (Camera:WorldToViewportPoint) to a point on the
	                               edge of the inset screen and the angle toward it (degrees, 0 = up);
	                               nil when the Hollow is on screen inside the inset (the player can see it)
	  strength(distance)           0 past Range, rising to 1 at FullAt
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

local C = Tuning.HuntedCue

local HuntedCue = {}

export type Placement = { x: number, y: number, angle: number }

function HuntedCue.strength(distance: number): number
	if distance >= C.Range then
		return 0
	end
	if distance <= C.FullAt then
		return 1
	end
	return 1 - (distance - C.FullAt) / (C.Range - C.FullAt)
end

function HuntedCue.place(x: number, y: number, inFront: boolean, w: number, h: number): Placement?
	local cx, cy = w / 2, h / 2
	local insetX, insetY = w * C.Inset, h * C.Inset
	local dx, dy = x - cx, y - cy
	if inFront and math.abs(dx) <= cx - insetX and math.abs(dy) <= cy - insetY then
		return nil
	end
	if not inFront then
		-- behind the camera the projection is mirrored: point the other way
		dx, dy = -dx, -dy
		if dx == 0 and dy == 0 then
			dy = 1 -- straight behind: show it at the bottom
		end
	end
	-- push the direction out to the inset rectangle's edge
	local hx, hy = cx - insetX, cy - insetY
	local scale = math.min(
		if dx ~= 0 then hx / math.abs(dx) else math.huge,
		if dy ~= 0 then hy / math.abs(dy) else math.huge
	)
	local px, py = cx + dx * scale, cy + dy * scale
	return { x = px, y = py, angle = math.deg(math.atan2(dx, -dy)) }
end

return table.freeze(HuntedCue)
