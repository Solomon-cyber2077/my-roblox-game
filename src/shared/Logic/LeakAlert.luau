--!strict
--[[
	What the leak alert shows (the HUD's leak slot and the world arrow, Controllers/LeakController),
	derived from the leak objects themselves (every anchor TrainService tags Leak), never from a
	counter: no leaks, no alert, so patching the last one clears it the moment its tag goes.
	With Broken Things Markers off there is no alert at all; the world cues carry it. Pure.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)

export type Leak = { id: string, anchor: string?, x: number, y: number, z: number }
export type Point = { x: number, y: number, z: number }
export type View = {
	count: number,
	nearest: Leak,
	distance: number, -- studs from `me` to the nearest leak
	metres: number,
	car: string,
	text: string,
}

local LeakAlert = {}

-- The train's cars by leak anchor (TrainBuilder breachAnchor names).
LeakAlert.Cars = table.freeze({
	BV1 = "brake van",
	BV2 = "brake van",
	CR1 = "crew car",
	CR2 = "crew car",
	WS1 = "workshop",
	WS2 = "workshop",
	CAB = "cab",
} :: { [string]: string })

function LeakAlert.car(anchor: string?): string
	return if anchor then LeakAlert.Cars[anchor] or "train" else "train"
end

-- nil when there is nothing to show: no leaks, markers off, or nobody to measure from.
function LeakAlert.view(leaks: { Leak }, me: Point?, markersOn: boolean): View?
	if not markersOn or #leaks == 0 or me == nil then
		return nil
	end
	local best: Leak? = nil
	local bestDistance = math.huge
	for _, leak in leaks do
		local dx, dy, dz = leak.x - me.x, leak.y - me.y, leak.z - me.z
		local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
		if distance < bestDistance or (distance == bestDistance and best and leak.id < best.id) then
			best, bestDistance = leak, distance
		end
	end
	local nearest = best :: Leak
	local metres = math.floor(bestDistance * Difficulty.Leaks.StudsToMetres + 0.5)
	local car = LeakAlert.car(nearest.anchor)
	local text = if #leaks == 1
		then `STEAM LEAK  ·  {string.upper(car)}  ·  {metres} m`
		else `{#leaks} STEAM LEAKS  ·  NEAREST {string.upper(car)}  ·  {metres} m`
	return {
		count = #leaks,
		nearest = nearest,
		distance = bestDistance,
		metres = metres,
		car = car,
		text = text,
	}
end

return table.freeze(LeakAlert)
