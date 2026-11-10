--!strict
--[[
	A resident's stroll (Config/Npcs `walk`): pure rules, run by NpcService.

	The spots lie along one line through the car, in order, so a walk from spot i to spot j
	passes every spot between them and never cuts a corner past something players use. The
	first spot is the resident's post; from anywhere else she heads home on `homeBias`.
]]

local Npcs = require(script.Parent.Parent.Config.Npcs)

export type Walk = Npcs.Walk

local ResidentWalk = {}

-- The next spot to walk to from `current`, `roll` in [0, 1).
function ResidentWalk.nextSpot(walk: Walk, current: number, roll: number): number
	local n = #walk.spots
	if n < 2 then
		return current
	end
	if current ~= 1 and roll < walk.homeBias then
		return 1
	end
	-- any other spot, evenly, from the rest of the roll
	local rest = if current ~= 1 then (roll - walk.homeBias) / (1 - walk.homeBias) else roll
	local pick = 1 + math.floor(math.clamp(rest, 0, 0.9999) * (n - 1))
	return if pick >= current then pick + 1 else pick
end

-- The spots passed on the way from `from` to `to`, `to` included and `from` left out.
function ResidentWalk.route(from: number, to: number): { number }
	local out = {}
	local dir = if to > from then 1 else -1
	for i = from + dir, to, dir do
		table.insert(out, i)
	end
	return out
end

-- Moves (x, z) toward (tx, tz) by `speed * dt`; returns the new point and whether it arrived.
function ResidentWalk.step(
	x: number,
	z: number,
	tx: number,
	tz: number,
	speed: number,
	dt: number
): (number, number, boolean)
	local dx, dz = tx - x, tz - z
	local dist = math.sqrt(dx * dx + dz * dz)
	local move = speed * dt
	if dist <= move or dist < 1e-6 then
		return tx, tz, true
	end
	return x + dx / dist * move, z + dz / dist * move, false
end

-- The closest distance from (px, pz) to the segment a-b.
function ResidentWalk.segmentDistance(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	px: number,
	pz: number
): number
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

-- The first keep-out a spot or a leg between neighbouring spots comes inside, or nil.
function ResidentWalk.firstClash(walk: Walk): string?
	for i, a in walk.spots do
		local b = walk.spots[i + 1] or a
		for _, k in walk.keepOut do
			if ResidentWalk.segmentDistance(a.x, a.z, b.x, b.z, k.x, k.z) < k.r then
				return `spot {i} near the {k.name}`
			end
		end
	end
	return nil
end

return ResidentWalk
