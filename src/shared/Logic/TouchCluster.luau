--!strict
--[[
	Where the touch buttons go (UI/TouchButtons, UI/ActionButton, UI/CashOut; checked on real screens by
	`lune run layout`). Pure, in screen units (points on iOS, dp on Android), placed around Roblox's own
	jump button so every device gets the same thumb geometry whatever our UI's scale or the safe area:

	  RUN      above the jump button, right-aligned with it
	  LOOK     left of RUN, PING left of LOOK, on RUN's row
	  ACTION   the contextual action button, left of the jump button on its row
	  BELT     on phones, two tool buttons left of PING on RUN's row (UI/ToolBelt): hold, then use
	  BAG      on phones, the bag button left of ACTION on its row: opens the bag sheet

	Every button is Size units on its short side: 60 is ~9.4 mm on an iPhone SE and more elsewhere,
	over the ~9.2 mm thumb minimum (Parhi, Karlson, Bederson 2006). Gap units keep them apart (Material:
	8 dp minimum).

	  jump(w, h, safe)   Roblox's jump button (TouchJump.lua, default branch) on a w x h screen, for when
	                     the real one is not there yet
	  place(jump)        { run, look, ping, action, belt = { two }, bag } rectangles
	  left(cluster)      the leftmost x any of them reaches (what the cash-out card keeps clear of)
	  sheet(cluster, area, count)
	                     the bag sheet: `count` cells (wrapping into rows) and three action buttons, all at Size
	                     units, left of the bag button inside `area` (the gui's screen rectangle)
]]

export type Rect = { x: number, y: number, w: number, h: number }
export type Cluster = { run: Rect, look: Rect, ping: Rect, action: Rect, belt: { Rect }, bag: Rect }
export type Sheet = { frame: Rect, cells: { Rect }, actions: { Rect } }

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
	local belt2 = { x = ping.x - g - s, y = run.y, w = s, h = s }
	local belt1 = { x = belt2.x - g - s, y = run.y, w = s, h = s }
	local bag = { x = action.x - g - s, y = action.y, w = s, h = s }
	return { run = run, look = look, ping = ping, action = action, belt = { belt1, belt2 }, bag = bag }
end

function TouchCluster.left(c: Cluster): number
	return math.min(c.run.x, c.look.x, c.ping.x, c.action.x, c.belt[1].x, c.bag.x)
end

function TouchCluster.sheet(c: Cluster, area: Rect, count: number): Sheet
	local s, g, pad = TouchCluster.Size, 8, 10
	-- left of the bag button (it stays up as the sheet's close), over the left of the screen: a modal, so it may
	-- cover the thumbstick zone; cells never shrink, they wrap into rows instead
	local left = area.x + g
	local right = c.bag.x - g
	local cols = math.max(1, math.min(count, math.floor((right - left - 2 * pad + g) / (s + g))))
	local rows = math.ceil(count / cols)
	local width = 2 * pad + cols * s + (cols - 1) * g
	local height = pad + rows * s + (rows - 1) * g + g + s + pad
	local top = math.max(area.y + g, area.y + (area.h - height) / 2)
	local frame = { x = right - width, y = top, w = width, h = height }
	local cells = {}
	for i = 1, count do
		local col, row = (i - 1) % cols, (i - 1) // cols
		table.insert(
			cells,
			{ x = frame.x + pad + col * (s + g), y = frame.y + pad + row * (s + g), w = s, h = s }
		)
	end
	local aw = (width - 2 * pad - 2 * g) / 3
	local actionsY = frame.y + pad + rows * (s + g)
	local actions = {}
	for i = 1, 3 do
		table.insert(actions, { x = frame.x + pad + (i - 1) * (aw + g), y = actionsY, w = aw, h = s })
	end
	return { frame = frame, cells = cells, actions = actions }
end

return table.freeze(TouchCluster)
