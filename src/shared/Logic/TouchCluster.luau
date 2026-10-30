--!strict
--[[
	Where the touch buttons go (UI/TouchButtons, UI/ActionButton, UI/CashOut; checked on real screens by
	`lune run layout`). Pure, in screen units (points on iOS, dp on Android), placed around Roblox's own
	jump button so every device gets the same thumb geometry whatever our UI's scale or the safe area:

	  RUN      above the jump button, right-aligned with it
	  LOOK     left of RUN, PING left of LOOK, on RUN's row
	  ACTION   the contextual action button, left of the jump button on its row

	Every button is Size units on its short side: 60 is ~9.4 mm on an iPhone SE and more elsewhere,
	over the ~9.2 mm thumb minimum (Parhi, Karlson, Bederson 2006). Gap units keep them apart (Material:
	8 dp minimum).

	  jump(w, h, safe)   Roblox's jump button (TouchJump.lua, default branch) on a w x h screen, for when
	                     the real one is not there yet
	  place(jump)        { run, look, ping, action } rectangles
	  left(cluster)      the leftmost x any of them reaches (what the cash-out card keeps clear of)
]]

export type Rect = { x: number, y: number, w: number, h: number }
export type Cluster = { run: Rect, look: Rect, ping: Rect, action: Rect }

local TouchCluster = {}

TouchCluster.Size = 60
TouchCluster.Gap = 12
TouchCluster.ActionWidth = 176

function TouchCluster.jump(
	w: number,
	h: number,
	safe: { left: number, right: number, bottom: number }?,
	top: number?
): Rect
	local s = safe or { left = 0, right = 0, bottom = 0 }
	local ax, ay = s.left, top or 0
	local aw, ah = w - s.left - s.right, h - (top or 0) - s.bottom
	local small = math.min(aw, ah) <= 500
	local size = if small then 70 else 120
	local y = if small then -size - 20 else -size * 1.75
	return { x = ax + aw - (size * 1.5 - 10), y = ay + ah + y, w = size, h = size }
end

function TouchCluster.place(jump: Rect): Cluster
	local s, g = TouchCluster.Size, TouchCluster.Gap
	local run = { x = jump.x + jump.w - s, y = jump.y - g - s, w = s, h = s }
	local look = { x = run.x - g - s, y = run.y, w = s, h = s }
	local ping = { x = look.x - g - s, y = run.y, w = s, h = s }
	local action = {
		x = jump.x - g - TouchCluster.ActionWidth,
		y = jump.y + jump.h - s,
		w = TouchCluster.ActionWidth,
		h = s,
	}
	return { run = run, look = look, ping = ping, action = action }
end

function TouchCluster.left(c: Cluster): number
	return math.min(c.run.x, c.look.x, c.ping.x, c.action.x)
end

return table.freeze(TouchCluster)
