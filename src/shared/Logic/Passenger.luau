--!strict
--[[
	What one of the Depot's passive people does next (Config/Passengers), as pure rules that
	Services/PassengerService acts on: walk to another spot, take a bench seat, stand about, or
	turn to a Hand nearby and greet them with the next of their lines. Also the walk graph's
	routes and the clearance test the visual audit holds every spot and link to.
]]

local Passengers = require(script.Parent.Parent.Config.Passengers)
local Rng = require(script.Parent.Parent.Util.Rng)

export type Context = {
	sitting: boolean, -- on a bench now
	satFor: number, -- seconds on it so far
	seatFree: boolean, -- a bench seat they may take (Logic says no if maxSitting are seated)
	othersSitting: number,
	handNear: boolean, -- a Hand within greetRadius
	canGreet: boolean, -- that Hand is off this person's cooldown
}

export type Action = "wander" | "sit" | "idle" | "greet" | "stand"

local Passenger = {}

local W = Passengers.Walk

-- The next thing to do. A seated person stays put until their time is up, unless greeting.
function Passenger.choose(rng: Rng.Rng, ctx: Context, sitTime: number): Action
	if ctx.handNear and ctx.canGreet and rng:chance(W.greetChance) then
		return "greet"
	end
	if ctx.sitting then
		return if ctx.satFor >= sitTime then "stand" else "idle"
	end
	local weights = W.weights
	local sit = if ctx.seatFree and ctx.othersSitting < W.maxSitting then weights.sit else 0
	local total = weights.wander + sit + weights.idle
	local roll = rng:next() * total
	if roll < weights.wander then
		return "wander"
	elseif roll < weights.wander + sit then
		return "sit"
	end
	return "idle"
end

-- Whether a Hand greeted at `last` (os.clock, nil never) may be greeted again at `now`.
function Passenger.offCooldown(now: number, last: number?, cooldown: number): boolean
	return last == nil or now - last > cooldown
end

-- Whether anyone may greet now, `lastAny` seconds-clock of the hall's last greeting: one bubble at a time.
function Passenger.mayGreet(now: number, lastAny: number, gap: number): boolean
	return now - lastAny >= gap
end

-- A spot to walk to that nobody else stands at or is heading for (`taken`), from `seen` half the time;
-- nil when every spot is taken.
function Passenger.pickSpot(
	rng: Rng.Rng,
	count: number,
	seen: { number },
	taken: { [number]: boolean }
): number?
	for _ = 1, 12 do
		local to = if rng:chance(0.5) then rng:pick(seen) else rng:int(1, count)
		if not taken[to] then
			return to
		end
	end
	for i = 1, count do
		if not taken[i] then
			return i
		end
	end
	return nil
end

-- The line after `index` (1-based) of `count`, round and round.
function Passenger.nextLine(index: number, count: number): number
	return if count <= 0 then 0 else index % count + 1
end

-- Spot indices from `from` to `to` along `links`, both ends included; nil when unreachable.
function Passenger.route(links: { { number } }, from: number, to: number): { number }?
	if from == to then
		return { from }
	end
	local near: { [number]: { number } } = {}
	for _, link in links do
		local a, b = link[1], link[2]
		near[a] = near[a] or {}
		near[b] = near[b] or {}
		table.insert(near[a], b)
		table.insert(near[b], a)
	end
	local came: { [number]: number } = { [from] = from }
	local queue = { from }
	local head = 1
	while head <= #queue do
		local at = queue[head]
		head += 1
		local around: { number } = near[at] or {}
		for _, nextSpot in around do
			if came[nextSpot] == nil then
				came[nextSpot] = at
				if nextSpot == to then
					local path = { to }
					local step = to
					while step ~= from do
						step = came[step]
						table.insert(path, 1, step)
					end
					return path
				end
				table.insert(queue, nextSpot)
			end
		end
	end
	return nil
end

-- The nearest free spot reachable directly without crossing a kept-out area. No unsafe fallback.
function Passenger.nearestFree(
	spots: { Passengers.Spot },
	x: number,
	z: number,
	taken: { [number]: boolean },
	keepOut: { Passengers.Box }?,
	clearance: number?
): number?
	local best, bestDistance = nil :: number?, math.huge
	for i, spot in spots do
		local clear = not taken[i]
		for _, box in keepOut or ({} :: { Passengers.Box }) do
			if not Passenger.clearOf(x, z, spot.x, spot.z, box, clearance or 0) then
				clear = false
				break
			end
		end
		if clear then
			local d = (spot.x - x) ^ 2 + (spot.z - z) ^ 2
			if d < bestDistance then
				best, bestDistance = i, d
			end
		end
	end
	return best
end

-- The spot nearest (x, z).
function Passenger.nearest(spots: { Passengers.Spot }, x: number, z: number): number
	local best, bestDistance = 1, math.huge
	for i, spot in spots do
		local d = (spot.x - x) ^ 2 + (spot.z - z) ^ 2
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

-- The spot to walk from to reach a seat: the nearest one on its open side, so the last steps
-- come from in front of the bench and never across it. (fx, fz) is the point in front of the seat
-- and (dx, dz) the way the sitter faces.
function Passenger.approach(
	spots: { Passengers.Spot },
	fx: number,
	fz: number,
	dx: number,
	dz: number
): number
	local best, bestDistance = Passenger.nearest(spots, fx, fz), math.huge
	for i, spot in spots do
		local ox, oz = spot.x - fx, spot.z - fz
		if ox * dx + oz * dz > 1 then
			local d = ox * ox + oz * oz
			if d < bestDistance then
				best, bestDistance = i, d
			end
		end
	end
	return best
end

-- Whether the walk from (ax, az) to (bx, bz) keeps `margin` studs from the box (a slab test on
-- the box grown by the margin).
function Passenger.clearOf(
	ax: number,
	az: number,
	bx: number,
	bz: number,
	box: Passengers.Box,
	margin: number
): boolean
	local x0, z0, x1, z1 = box.x0 - margin, box.z0 - margin, box.x1 + margin, box.z1 + margin
	local t0, t1 = 0, 1
	for _, axis in { { ax, bx - ax, x0, x1 }, { az, bz - az, z0, z1 } } do
		local start, delta, lo, hi = axis[1], axis[2], axis[3], axis[4]
		if math.abs(delta) < 1e-9 then
			if start < lo or start > hi then
				return true
			end
		else
			local a, b = (lo - start) / delta, (hi - start) / delta
			if a > b then
				a, b = b, a
			end
			t0, t1 = math.max(t0, a), math.min(t1, b)
			if t0 > t1 then
				return true
			end
		end
	end
	return false
end

return table.freeze(Passenger)
