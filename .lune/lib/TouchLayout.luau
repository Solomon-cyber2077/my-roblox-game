--[[
	Exact touch layout (`lune run layout`): where every touch control lands on real phone screens, in
	millimetres, from the rules that place them. No renderer needed: the positions are arithmetic.

	Roblox's own controls follow its current client scripts (Roblox-Client-Tracker datamine, `roblox`
	branch): PlayerModule ControlModule TouchJump.lua, DynamicThumbstick.lua, and CoreScripts
	ContextActionTouch.lua. Ours follow our code: UIController (UIScale and Compact), MovementController
	(RUN), Hud placeWatch (LOOK and PING beside RUN), UI/ActionButton, UI/CashOut, UI/HuntedCue, Overlay.

	What is assumed, not read from code, is listed per device (`assumed`), and tools/studio/layout-dump.luau
	reads the same rectangles from a running game in Studio's Device Emulator to confirm it.
]]

local L = {}

-- Screens, landscape, in Roblox GUI units (points on iOS, dp on Android) with millimetres per unit.
-- iOS: pt = scale px / ppi. Android: 1 dp = 1/160 inch by definition (0.159 mm); size = px / (ppi / 160).
L.Devices = {
	{
		id = "iPhoneSE",
		label = "iPhone SE 2020 (the launch floor)",
		w = 667,
		h = 375,
		mm = 25.4 * 2 / 326,
		safe = { left = 0, right = 0, bottom = 0 },
	},
	{
		id = "iPhone15",
		label = "iPhone 15 (Dynamic Island)",
		w = 852,
		h = 393,
		mm = 25.4 * 3 / 460,
		safe = { left = 59, right = 59, bottom = 21 },
	},
	{
		id = "GalaxyA15",
		label = "Galaxy A15 (budget Android, 2340x1080 @396 ppi)",
		w = 2340 / (396 / 160),
		h = 1080 / (396 / 160),
		mm = 25.4 / 160,
		safe = { left = 0, right = 0, bottom = 0 },
		android = true,
	},
	{
		id = "MotoE13",
		label = "Moto E13 (low-end Android, 1600x720 @269 ppi)",
		w = 1600 / (269 / 160),
		h = 720 / (269 / 160),
		mm = 25.4 / 160,
		safe = { left = 0, right = 0, bottom = 0 },
		android = true,
	},
	{
		id = "iPad10",
		label = "iPad 10th gen",
		w = 1180,
		h = 820,
		mm = 25.4 * 2 / 264,
		safe = { left = 0, right = 0, bottom = 20 },
	},
}

L.TopBar = 58 -- GUI inset at the top (IgnoreGuiInset = false); not found in source: assumed, confirm in Studio
L.MinTapMm = 9.2 -- one-handed thumb, discrete taps (Parhi, Karlson, Bederson 2006)
L.MinGapUnits = 8 -- spacing between touch targets (Material Design: 8 dp)

export type Rect = { x: number, y: number, w: number, h: number }

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = x, y = y, w = w, h = h }
end

function L.overlap(a: Rect, b: Rect): boolean
	return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- The gap between two rectangles (0 when they touch or overlap).
function L.gap(a: Rect, b: Rect): number
	local dx = math.max(b.x - (a.x + a.w), a.x - (b.x + b.w), 0)
	local dy = math.max(b.y - (a.y + a.h), a.y - (b.y + b.h), 0)
	return math.sqrt(dx * dx + dy * dy)
end

-- UIController.fitScale: the scale of our ScreenGui and whether it is the Compact (phone) layout.
function L.uiScale(d): (number, boolean)
	local compact = d.h < 500 -- touch devices only: every device here is touch
	local fit = if compact then math.min(d.w / 1000, d.h / 540) else math.min(d.w / 1366, d.h / 768)
	return math.clamp(fit, 0.6, 1.15), compact
end

-- Our ScreenGui's area (CoreUISafeInsets + the top bar inset).
function L.guiArea(d): Rect
	return rect(d.safe.left, L.TopBar, d.w - d.safe.left - d.safe.right, d.h - L.TopBar - d.safe.bottom)
end

-- A GuiObject in our ScreenGui, under its UIScale `s`: Position {sx, ox, sy, oy}, Size {w, h}, AnchorPoint {ax, ay},
-- and an optional own UIScale `own` (scaled about the object's anchor point).
function L.place(d, pos: { number }, size: { number }, anchor: { number }, own: number?): Rect
	local s = L.uiScale(d)
	local area = L.guiArea(d)
	local cw, ch = area.w / s, area.h / s -- the canvas the UIScale stretches
	local o = own or 1
	local w, h = size[1] * o, size[2] * o
	local px = pos[1] * cw + pos[2]
	local py = pos[3] * ch + pos[4]
	return rect(area.x + s * (px - anchor[1] * w), area.y + s * (py - anchor[2] * h), w * s, h * s)
end

-- Roblox's jump button (TouchJump.lua). Ability-controls flag off (default branch) and on.
function L.jump(d, abilities: boolean?): Rect
	local area = rect(d.safe.left, L.TopBar, d.w - d.safe.left - d.safe.right, d.h - L.TopBar - d.safe.bottom)
	local small = math.min(area.w, area.h) <= 500
	if abilities then
		local size = if small then 72 else 120
		local ix, iy = if small then 64 else 100, if small then 64 else 112
		return rect(area.x + area.w - size - ix, area.y + area.h - size - iy, size, size)
	end
	local size = if small then 70 else 120
	local y = if small then -size - 20 else -size * 1.75
	return rect(area.x + area.w - (size * 1.5 - 10), area.y + area.h + y, size, size)
end

-- The dynamic thumbstick's touch zone (DynamicThumbstick.lua, landscape): left 40%, lower two thirds.
function L.thumbstickZone(d): Rect
	local area = L.guiArea(d)
	return rect(area.x, area.y + area.h / 3, area.w * 0.4, area.h * 2 / 3)
end

-- ContextActionService touch buttons (ContextActionTouch.lua): 45 units, 35 when the screen is <= 320 tall,
-- in a frame covering the right 30% and lower half of the screen (CoreGui, full screen).
function L.casSize(d, override: number?): number
	if override then
		return override
	end
	return if d.h <= 320 then 35 else 45
end

-- RUN: MovementController SetPosition(UDim2.new(1, -170, 1, -150)), top-left anchored in that frame.
function L.run(d, size: number?): Rect
	local s = L.casSize(d, size)
	return rect(d.w - 170, d.h - 150, s, s)
end

-- LOOK and PING: Hud placeWatch puts them on RUN's row, LOOK left of RUN, PING left of LOOK (GlanceTouchGap 8).
function L.lookPing(d, size: number?): (Rect, Rect)
	local run = L.run(d, size)
	local s = run.w
	local gap = 8
	return rect(run.x - gap - s, run.y, s, s), rect(run.x - 2 * (gap + s), run.y, s, s)
end

return L
