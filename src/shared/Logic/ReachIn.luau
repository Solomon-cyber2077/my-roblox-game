--!strict
--[[
	The giant Brute's reach-in (Tuning.BruteRemake.Reach), pure so the server, the specs and the
	simulator agree. It is too tall for a door (Config/BruteBody Giant), so a player inside a
	building is taken only through an opening: it walks to a spot outside a door or window near
	them, holds the tell (bent at the hips, hands on the frame, looking in), then reaches in and
	hauls them out (Config/Grabs "Reach").

	Everything here is in one building's own frame (BuildingGen.Plan: x, z about its centre,
	y up from the station floor).

	  openings  every exterior door and every window it can reach through, with its wall's
	            outward normal and its floor height
	  covers    a point inside within Depth of an opening's inner face, beside it within Slack,
	            on the opening's floor: what it can take from there
	  choose    of the openings that cover the prey, the nearest to the Brute; with none, the
	            nearest few to the prey (Search), to wait at
	  step      one tick of the approach, the tell and the reach, with a cooldown per opening
	  returns   whether a stop rolls the late Brute (Tuning.BruteRemake.Return, Difficulty.BruteReturn)
]]

local Shared = script.Parent.Parent
local Buildings = require(Shared.Config.Buildings)
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local BuildingGen = require(Shared.Logic.BuildingGen)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)

export type Opening = {
	id: number,
	kind: string, -- "Door" or "Window"
	x: number, -- centre of the opening, on the wall's centre line
	z: number,
	nx: number, -- the wall's outward normal (one of them is 0)
	nz: number,
	width: number,
	floor: number, -- the floor height of the room behind it
	sill: number, -- y of the opening's bottom
}

export type Config = {
	Depth: number,
	Slack: number,
	MaxFloor: number,
	Stand: number,
	Arrive: number,
	Tell: number,
	Cooldown: number,
	Search: number,
	Lurk: number,
	Through: { [string]: boolean },
}

export type Track = {
	phase: string, -- "Idle", "Approach", "Tell", "Lurk"
	opening: number?, -- the opening's id
	t: number, -- seconds in this phase
	cooldown: { [number]: number }, -- seconds left before each opening can be used again
}

export type Input = {
	dt: number,
	covered: boolean, -- the prey is in reach through the chosen opening now
	there: boolean, -- the Brute stands at the opening's stand point
	lit: boolean, -- light at the opening (or on the prey) holds it off
}

local R = Tuning.BruteRemake.Reach
local HALF_WALL = Buildings.Wall / 2

local ReachIn = {}

ReachIn.Config = R :: Config

-- Every opening of `plan` it can reach through, on the ground floor (MaxFloor).
function ReachIn.openings(plan: BuildingGen.Plan, cfg: Config?): { Opening }
	local c = cfg or R
	local list: { Opening } = {}
	local ground = math.huge
	for _, room in plan.rooms do
		ground = math.min(ground, room.y)
	end
	if ground == math.huge then
		ground = 0
	end
	local function add(
		kind: string,
		x: number,
		z: number,
		axis: string,
		outward: number,
		width: number,
		floor: number,
		sill: number
	)
		if floor - ground > c.MaxFloor then
			return
		end
		local nx = if axis == "X" then 0 else outward
		local nz = if axis == "X" then outward else 0
		table.insert(list, {
			id = #list + 1,
			kind = kind,
			x = x,
			z = z,
			nx = nx,
			nz = nz,
			width = width,
			floor = floor,
			sill = sill,
		})
	end
	if c.Through.Door then
		for _, d in plan.doors do
			if d.exterior then
				add("Door", d.x, d.z, d.axis, d.outward, d.width, d.y, d.y)
			end
		end
	end
	for _, w in plan.windows do
		if c.Through[w.glass] then
			local room = BuildingGen.room(plan, w.room)
			local floor = if room then room.y else w.y0 - Buildings.WindowSill
			add("Window", w.x, w.z, w.axis, w.outward, w.width, floor, w.y0)
		end
	end
	return list
end

-- How far inside the opening's inner face (depth) and beside its middle (side) a point is.
function ReachIn.offset(o: Opening, x: number, z: number): (number, number)
	local dx, dz = x - o.x, z - o.z
	local inward = -(dx * o.nx + dz * o.nz)
	local side = math.abs(dx * o.nz - dz * o.nx)
	return inward - HALF_WALL, side
end

-- True when a player whose feet are at `y`, standing at (x, z), can be taken through `o`.
function ReachIn.covers(o: Opening, x: number, y: number, z: number, cfg: Config?): boolean
	local c = cfg or R
	if math.abs(y - o.floor) > 2.5 then
		return false
	end
	local depth, side = ReachIn.offset(o, x, z)
	return depth >= -HALF_WALL and depth <= c.Depth and side <= o.width / 2 + c.Slack
end

-- True when (x, z) is inside the building's outer walls.
function ReachIn.inside(plan: BuildingGen.Plan, x: number, z: number): boolean
	return math.abs(x) < plan.outerX and math.abs(z) < plan.outerZ
end

-- Where it stands outside `o` to reach in: Stand studs out from the wall's outer face.
function ReachIn.stand(o: Opening, cfg: Config?): (number, number)
	local c = cfg or R
	local out = HALF_WALL + c.Stand
	return o.x + o.nx * out, o.z + o.nz * out
end

local function distance(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

--[[
	The opening to make for. `from` is the Brute, `prey` the player (feet y). Returns the opening
	and whether it already covers them. Openings still cooling down are skipped.
]]
function ReachIn.choose(
	openings: { Opening },
	px: number,
	py: number,
	pz: number,
	fromX: number,
	fromZ: number,
	cooldown: { [number]: number }?,
	cfg: Config?
): (Opening?, boolean)
	local c = cfg or R
	local best: Opening? = nil
	local bestDistance = math.huge
	for _, o in openings do
		if (cooldown and (cooldown[o.id] or 0) > 0) or not ReachIn.covers(o, px, py, pz, c) then
			continue
		end
		local sx, sz = ReachIn.stand(o, c)
		local d = distance(sx, sz, fromX, fromZ)
		if d < bestDistance then
			best, bestDistance = o, d
		end
	end
	if best then
		return best, true
	end
	-- none covers them: of the Search openings nearest the prey, the one nearest the Brute
	local near = {}
	for _, o in openings do
		if not (cooldown and (cooldown[o.id] or 0) > 0) and math.abs(py - o.floor) <= 2.5 then
			table.insert(near, o)
		end
	end
	table.sort(near, function(a, b)
		local da, db = distance(a.x, a.z, px, pz), distance(b.x, b.z, px, pz)
		if da ~= db then
			return da < db
		end
		return a.id < b.id
	end)
	for i = 1, math.min(c.Search, #near) do
		local o = near[i]
		local sx, sz = ReachIn.stand(o, c)
		local d = distance(sx, sz, fromX, fromZ)
		if d < bestDistance then
			best, bestDistance = o, d
		end
	end
	return best, false
end

function ReachIn.newTrack(): Track
	return { phase = "Idle", opening = nil, t = 0, cooldown = {} }
end

-- Aim the track at `opening` (a new choice restarts the approach; the same one keeps its phase).
function ReachIn.aim(track: Track, opening: Opening?): Track
	local id = if opening then opening.id else nil
	if id == track.opening and track.phase ~= "Idle" then
		return track
	end
	return { phase = if id then "Approach" else "Idle", opening = id, t = 0, cooldown = track.cooldown }
end

--[[
	One tick. Returns the new track and "Reach" on the tick it reaches in (the caller seizes; on
	success or failure the opening cools down), else nil.
	  Approach  walking to the stand point; there and covered: the tell; there and not: lurk
	  Tell      Tell seconds at the frame; the prey stepping out of reach ends it (back to Approach),
	            light ends it (the opening cools down)
	  Lurk      waits at the opening for the prey to come near; after Lurk seconds it cools that
	            opening so the next choice goes round to another
]]
function ReachIn.step(track: Track, input: Input, cfg: Config?): (Track, string?)
	local c = cfg or R
	local cooldown: { [number]: number } = {}
	for id, left in track.cooldown do
		local now = left - input.dt
		if now > 0 then
			cooldown[id] = now
		end
	end
	local id = track.opening
	local phase, t = track.phase, track.t + input.dt
	local fired: string? = nil
	if id == nil then
		return { phase = "Idle", opening = nil, t = 0, cooldown = cooldown }, nil
	end
	if input.lit then
		cooldown[id] = c.Cooldown
		return { phase = "Idle", opening = nil, t = 0, cooldown = cooldown }, nil
	end
	if phase == "Approach" then
		if input.there then
			phase, t = if input.covered then "Tell" else "Lurk", 0
		end
	elseif phase == "Tell" then
		if not input.covered or not input.there then
			phase, t = "Approach", 0
		elseif t >= c.Tell then
			fired = "Reach"
			cooldown[id] = c.Cooldown
			return { phase = "Idle", opening = nil, t = 0, cooldown = cooldown }, fired
		end
	elseif phase == "Lurk" then
		if input.covered and input.there then
			phase, t = "Tell", 0
		elseif t >= c.Lurk then
			cooldown[id] = c.Cooldown
			return { phase = "Idle", opening = nil, t = 0, cooldown = cooldown }, nil
		end
	end
	return { phase = phase, opening = id, t = t, cooldown = cooldown }, fired
end

--[[
	Whether stop `stop` of a run rolls the late Brute: past the tutorial runs, from FirstStop (by
	difficulty), with Chance, from the stop's own seed so every server agrees.
]]
function ReachIn.returns(seed: number, stop: number?, tutorial: number?, difficulty: number): boolean
	local Return = Tuning.BruteRemake.Return
	if stop == nil or (tutorial ~= nil and tutorial > 0) then
		return false
	end
	local pair = Difficulty.BruteReturn.FirstStop
	local first = math.floor(MathX.lerp(pair[1], pair[2], math.clamp(difficulty, 0, 1)) + 0.5)
	if stop < first then
		return false
	end
	return Rng.new(Rng.derive(seed, "brute")):next() < Return.Chance
end

return table.freeze(ReachIn)
