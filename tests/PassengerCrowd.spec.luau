--[[
	The hall's six passengers walked headless, to measure what HP measured in Play: over 90 s, how
	long the closest pair of standing or walking passengers is under 2.5 studs apart, and the longest
	stretch. Bodies are 2 studs wide (a walker that would come closer than that is blocked), walks run
	at Walk.speed along the walk graph, and the service's manners are followed: one wait per step for
	anyone in personal space ahead, then a sidestep to the right; a walk blocked past stepTimeout
	settles. Benches are left out (a sitter is out of the count anyway).

	`old` is the rule before 2026-11-08 (a blocked walker took the nearest spot where it stood);
	`new` is Passenger.nearestFree plus the standing gap (Services/PassengerService.settle).

	Finding (2026-11-08): here both rules keep the closest pair under 2.5 studs only ~9 s of 90, while
	HP measured 81 s in Play. What clumps them in Play is not in this model (Humanoids shoving, bench
	approaches, greetings), so this spec guards against regressions and does not prove the fix.
]]

local Passenger = require(Shared.Logic.Passenger)
local Passengers = require(Shared.Config.Passengers)
local Rng = require(Shared.Util.Rng)

local HALL, W = Passengers.Hall, Passengers.Walk
local DT, SECONDS, NEAR, BODY = 0.1, 90, 2.5, 1.8
local DEBUG = false

type Walker = {
	x: number,
	z: number,
	spot: number,
	target: number?,
	path: { number },
	leg: number, -- index into path of the spot being walked to
	waited: boolean,
	stepTime: number,
	aside: number, -- seconds left of a sidestep
	sx: number,
	sz: number,
	idle: number,
	rng: any,
}

local function taken(walkers: { Walker }, me: Walker): { [number]: boolean }
	local t: { [number]: boolean } = {}
	for _, a in walkers do
		if a ~= me then
			t[a.spot] = true
			if a.target then
				t[a.target] = true
			end
		end
	end
	return t
end

local function near(walkers: { Walker }, me: Walker, hx: number?, hz: number?): boolean
	for _, a in walkers do
		if a ~= me then
			local dx, dz = a.x - me.x, a.z - me.z
			if
				dx * dx + dz * dz < W.personalSpace ^ 2
				and (hx == nil or dx * (hx :: number) + dz * (hz :: number) > 0)
			then
				return true
			end
		end
	end
	return false
end

local function blocked(walkers: { Walker }, me: Walker, x: number, z: number): boolean
	for _, a in walkers do
		if a ~= me then
			local now = (a.x - me.x) ^ 2 + (a.z - me.z) ^ 2
			local after = (a.x - x) ^ 2 + (a.z - z) ^ 2
			if after < BODY * BODY and after < now then -- moving closer into a body
				return true
			end
		end
	end
	return false
end

local function goTo(a: Walker, to: number)
	local path = Passenger.route(HALL.links, a.spot, to)
	if path and #path > 1 then
		a.path, a.leg, a.target = path, 2, to
		a.waited, a.stepTime = false, 0
	end
end

local function settle(walkers: { Walker }, a: Walker, rule: string)
	if rule == "old" then
		a.spot = Passenger.nearest(HALL.spots, a.x, a.z)
		a.path, a.target = {}, nil
		a.idle = a.rng:range(W.idle[1], W.idle[2])
	else
		a.spot = Passenger.nearestFree(HALL.spots, a.x, a.z, taken(walkers, a))
		local s = HALL.spots[a.spot]
		a.path, a.leg, a.target = { a.spot, a.spot }, 2, a.spot -- walk onto it
		a.waited, a.stepTime = false, 0
		a.sx, a.sz = s.x, s.z
	end
end

local function tick(walkers: { Walker }, a: Walker, rule: string)
	if #a.path == 0 then
		a.idle -= DT
		if a.idle > 0 then
			return
		end
		if rule == "new" and near(walkers, a, nil, nil) then
			settle(walkers, a, rule) -- someone at its elbow: off to a spot of its own
			return
		end
		local to = Passenger.pickSpot(a.rng, #HALL.spots, HALL.seen, taken(walkers, a))
		if to and to ~= a.spot then
			goTo(a, to)
		else
			a.idle = a.rng:range(W.idle[1], W.idle[2])
		end
		return
	end
	local goal = HALL.spots[a.path[a.leg]]
	local gx, gz = goal.x, goal.z
	local dx, dz = gx - a.x, gz - a.z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 1.5 then -- arrived at this step
		a.spot = a.path[a.leg]
		a.leg += 1
		a.waited, a.stepTime = false, 0
		if a.leg > #a.path then
			a.path, a.target = {}, nil
			a.idle = a.rng:range(W.idle[1], W.idle[2])
		end
		return
	end
	a.stepTime += DT
	if a.stepTime > W.stepTimeout + (if a.waited then W.waitAhead else 0) then
		settle(walkers, a, rule) -- the walk failed
		return
	end
	local hx, hz = dx / d, dz / d
	if a.aside > 0 then -- stepping aside to the right
		a.aside -= DT
		hx, hz = -hz, hx
	elseif not a.waited and near(walkers, a, hx, hz) then
		a.waited = true
		a.idle = W.waitAhead -- stand, then go on (or step aside)
	end
	if a.idle > 0 and a.waited and a.aside <= 0 then
		a.idle -= DT
		if a.idle <= 0 and near(walkers, a, hx, hz) then
			a.aside = 1.2
		end
		return
	end
	local step = math.min(W.speed * DT, d)
	local nx, nz = a.x + hx * step, a.z + hz * step
	if not blocked(walkers, a, nx, nz) then
		a.x, a.z = nx, nz
	else
		-- a body in the way: slide round it as a Humanoid does, to the right first, then the left
		for _, side in { 1, -1 } do
			local px, pz = a.x - hz * side * step * 0.7, a.z + hx * side * step * 0.7
			if not blocked(walkers, a, px, pz) then
				a.x, a.z = px, pz
				break
			end
		end
	end
end

local function run(rule: string, seed: number): (number, number)
	local rng = Rng.new(seed)
	local walkers: { Walker } = {}
	local used: { [number]: boolean } = {}
	for _ = 1, HALL.count do
		local spot = rng:int(1, #HALL.spots)
		while used[spot] do
			spot = spot % #HALL.spots + 1
		end
		used[spot] = true
		local s = HALL.spots[spot]
		table.insert(walkers, {
			x = s.x,
			z = s.z,
			spot = spot,
			target = nil,
			path = {},
			leg = 1,
			waited = false,
			stepTime = 0,
			aside = 0,
			sx = s.x,
			sz = s.z,
			idle = rng:range(0, 3),
			rng = Rng.new(Rng.derive(seed, "agent", spot)),
		})
	end
	local close, stretch, longest = 0, 0, 0
	for _ = 1, math.floor(SECONDS / DT) do
		for _, a in walkers do
			tick(walkers, a, rule)
		end
		local closest = math.huge
		for i = 1, #walkers do
			for j = i + 1, #walkers do
				closest = math.min(
					closest,
					math.sqrt((walkers[i].x - walkers[j].x) ^ 2 + (walkers[i].z - walkers[j].z) ^ 2)
				)
			end
		end
		if closest < NEAR then
			close += DT
			stretch += DT
			longest = math.max(longest, stretch)
			if DEBUG and rule == "new" and math.abs(stretch - 8) < DT / 2 then
				for i, ag in walkers do
					print(
						string.format(
							"      seed %d walker %d at (%.1f, %.1f) spot %d path %d leg %d waited %s aside %.1f idle %.1f",
							seed,
							i,
							ag.x,
							ag.z,
							ag.spot,
							#ag.path,
							ag.leg,
							tostring(ag.waited),
							ag.aside,
							ag.idle
						)
					)
				end
			end
		else
			stretch = 0
		end
	end
	return close, longest
end

describe("Passengers in a crowd (headless, 90 s)", function()
	it("keep apart: the closest pair is rarely under 2.5 studs, and never for long", function()
		local seeds = { 1, 2, 3, 4, 5, 6, 7, 8 }
		local oldClose, newClose, newLongest = 0, 0, 0
		for _, seed in seeds do
			local c = run("old", seed)
			oldClose += c
			local nc, nl = run("new", seed)
			newClose += nc
			newLongest = math.max(newLongest, nl)
		end
		oldClose /= #seeds
		newClose /= #seeds
		print(
			string.format(
				"    crowd: old rule %.1f s of 90 under 2.5 studs; new rule %.1f s, longest stretch %.1f s",
				oldClose,
				newClose,
				newLongest
			)
		)
		-- A regression guard at the 2026-11-08 level (old 8.7 s, new 8.9 s, longest 11.9 s): this simplified
		-- crowd does not reproduce HP's Play figure (81 of 90 s), so Play stays the judge of the fix.
		expect(newClose).toBeLessThan(oldClose + 1.5)
		expect(newClose).toBeLessThan(15)
		expect(newLongest).toBeLessThan(15)
	end)
end)
