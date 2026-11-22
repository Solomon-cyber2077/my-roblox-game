--!strict
--[[
	The grab remake's choices (Tuning.GrabLook), kept apart from the screen so they can be tested:

	  look     which screen a Hollow's grab gets: the Stalker "Cold" (fog, blue-grey), the Stoker "Heat"
	           (soot, embers); nil keeps today's tunnel (the Crawler, the old block Brute, the switch off)
	  move     the camera move for a hold: the Stalker lifts you by the throat ("Lifted"), presses you into
	           his ribs ("Pressed") or drags you by the ankle ("Dragged"); the Stoker lifts you ("Rise"),
	           slams you down ("Drop") or hauls you through a door ("Jolts")
	  roll     the small variation each grab gets: which side the dark leans to, how fast it closes, and the
	           camera's sway. 27 combinations, and never the one the last grab had
	  tier     the Quality / Balanced / Performance setting the effects scale to
]]

local GrabLook = {}

export type Look = "Cold" | "Heat"
export type Variant = {
	key: number, -- 1..27, unique per combination
	lean: number, -- -1 the dark leans left, 0 even, 1 right
	speed: number, -- how fast the screen closes: 0.7, 1 or 1.4
	sway: string, -- the camera's motion: "Shudder" (fine and fast), "Roll" (slow tilt) or "Kick" (sparse jolts)
}

local LEANS = { -1, 0, 1 }
local SPEEDS = { 0.7, 1, 1.4 }
local SWAYS = { "Shudder", "Roll", "Kick" }
GrabLook.Count = #LEANS * #SPEEDS * #SWAYS

local MOVES: { [string]: string } = {
	Throttle = "Lifted",
	Embrace = "Pressed",
	Drag = "Dragged",
	Lift = "Rise",
	Slam = "Drop",
	Reach = "Jolts",
}

-- The look for a grab by `kind` (the GrabKind attribute). `enabled`: Tuning.GrabLook.Enabled;
-- `stoker`: the Brute is the Stoker remake (Tuning.BruteRemake.Enabled).
function GrabLook.look(kind: string, enabled: boolean, stoker: boolean): Look?
	if not enabled then
		return nil
	end
	if kind == "Stalker" then
		return "Cold"
	elseif kind == "Brute" and stoker then
		return "Heat"
	end
	return nil
end

-- The camera move for a hold id (Config/Grabs), or nil for none (the view only turns to its face).
function GrabLook.move(holdId: string): string?
	return MOVES[holdId]
end

-- The variant with this key (1..Count).
function GrabLook.variant(key: number): Variant
	local k = math.clamp(math.floor(key), 1, GrabLook.Count) - 1
	local lean = k % #LEANS
	local speed = (k // #LEANS) % #SPEEDS
	local sway = k // (#LEANS * #SPEEDS)
	return { key = k + 1, lean = LEANS[lean + 1], speed = SPEEDS[speed + 1], sway = SWAYS[sway + 1] }
end

-- A new variant, never the one keyed `last`. `pick(n)` returns 1..n (Random:NextInteger).
function GrabLook.roll(last: number?, pick: (number) -> number): Variant
	if last == nil or last < 1 or last > GrabLook.Count then
		return GrabLook.variant(pick(GrabLook.Count))
	end
	-- one of the other Count - 1, evenly
	local n = pick(GrabLook.Count - 1)
	return GrabLook.variant(if n >= last then n + 1 else n)
end

-- The effects tier for the GraphicsQuality setting.
function GrabLook.tier(setting: any): string
	if setting == "Performance" or setting == "Balanced" then
		return setting
	end
	return "Quality"
end

-- 0..1: how far a screen that closes at `speed` has closed `since` seconds after the grab.
function GrabLook.close(since: number, speed: number): number
	local u = math.clamp(since * speed / 0.9, 0, 1)
	return 1 - (1 - u) ^ 3
end

return GrabLook
