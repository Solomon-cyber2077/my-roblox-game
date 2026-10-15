--!strict
--[[
	The floor arrows' path to a leak (Controllers/LeakController), in train-local studs: x along
	the train, z across it, the aisle at z = 0 (Config/Tuning LeakArrows). Pure.

	inside(from, leak)       down the aisle car to car, curving to the wall at the leak
	platform(from)           along the platform to the Last Light's door (its leaks are not
	                         reached through the cars)
	place(path, travelled)   chevrons along a path: a point and a unit heading each, `Spacing`
	                         apart from `Lead` ahead, shifted by `travelled` (the scroll)
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

local A = Tuning.LeakArrows

export type Point = { x: number, z: number }
export type Chevron = { x: number, z: number, dx: number, dz: number }

local LeakRoute = {}

local function sign(v: number): number
	return if v < 0 then -1 else 1
end

-- a quadratic bend from `a` through control `c` to `b`, without `a` itself
local function bend(path: { Point }, a: Point, c: Point, b: Point)
	for i = 1, 6 do
		local t = i / 6
		local u = 1 - t
		table.insert(path, {
			x = u * u * a.x + 2 * u * t * c.x + t * t * b.x,
			z = u * u * a.z + 2 * u * t * c.z + t * t * b.z,
		})
	end
end

function LeakRoute.inside(from: Point, leak: Point): { Point }
	local dir = sign(leak.x - from.x)
	local wall = { x = leak.x, z = sign(leak.z) * A.WallInset }
	local path: { Point } = { { x = from.x, z = from.z } }
	if math.abs(leak.x - from.x) <= A.CurveIn then
		-- already beside it: straight over to the wall
		table.insert(path, wall)
		return path
	end
	-- into the aisle, down it, then the bend toward the wall at the leak
	local turn = { x = leak.x - dir * A.CurveIn, z = 0 }
	table.insert(path, { x = from.x + dir * math.min(1.5, math.abs(turn.x - from.x)), z = 0 })
	table.insert(path, turn)
	bend(path, turn, { x = leak.x, z = 0 }, wall)
	return path
end

function LeakRoute.platform(from: Point): { Point }
	local door = { x = A.CabDoorX, z = A.CabDoorZ }
	local outZ = A.CabDoorZ + A.PlatformApproach
	local dir = sign(door.x - from.x)
	local path: { Point } = { { x = from.x, z = from.z } }
	if math.abs(door.x - from.x) > A.CurveIn then
		-- along the platform at your distance from the train (never inside it), then in to the door
		local z = math.max(from.z, outZ)
		local turn = { x = door.x - dir * A.CurveIn, z = z }
		table.insert(path, turn)
		bend(path, turn, { x = door.x, z = z }, door)
	else
		table.insert(path, { x = door.x, z = outZ })
		table.insert(path, door)
	end
	return path
end

function LeakRoute.place(path: { Point }, travelled: number): { Chevron }
	local out: { Chevron } = {}
	local offset = travelled % A.Spacing
	local want = A.Lead + offset
	local walked = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 1e-6 then
			while want <= walked + length and #out < A.Count do
				local t = (want - walked) / length
				table.insert(out, { x = a.x + dx * t, z = a.z + dz * t, dx = dx / length, dz = dz / length })
				want += A.Spacing
			end
			walked += length
		end
	end
	return out
end

return table.freeze(LeakRoute)
