--!strict
--[[
	The journey as pure data and math. The client builds the landscape from it;
	the Lune specs pin the rules down.

	  * biomes: each leg runs from the last stop's biome into the destination's,
	    blending at Tuning.Journey.BlendAt of the leg
	  * set pieces: tunnels, gorges, burning towns and the rest, planned per leg
	    from the run seed and trimmed clear of the next dock
	  * sinkholes: the void each station sits in, on the platform (+Z) side
	  * the sky: time of day by run progress, from dusk at the lobby to sunrise
	    at the Terminus

	Coordinates are land coordinates: x is studs along the track (the odometer
	scale), so a land point at x is drawn at world x = x - odometer. z and y are
	world z and y (+Z is the platform side).
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)
local Motion = require(Shared.Logic.Motion)
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)

-- Corridor, Farmland, Coalfield, BurningTown, Highland, Mountain or Coast (see Scenery/Biomes).
export type Biome = string

export type PieceKind =
	"Tunnel"
	| "Gorge"
	| "BurningTown"
	| "Halt"
	| "Wreck"
	| "Gantry"
	| "HollowField"
	| "Graveyard"
	| "Lake"
	| "Crossing"

export type Piece = {
	kind: PieceKind,
	leg: number,
	index: number,
	at: number, -- land x where the piece starts
	length: number,
	side: number, -- +1 platform side, -1 far side, 0 both
	style: number, -- 1 or 2: a variant the builder picks from (truss or viaduct, and so on)
	seed: number,
}

export type Transition = { at: number, length: number, biome: Biome }
export type Rect = { x0: number, x1: number, z0: number, z1: number }
export type Span = { a: number, b: number, kind: string }

export type Sinkhole = {
	rect: Rect,
	center: number, -- land x of the station centre when docked
	archetype: string,
	terminus: boolean,
}

local J = Tuning.Journey

local Journey = {}

Journey.FirstBiome = "Corridor" :: Biome

local BIOMES: { [string]: Biome } = {
	Halt = "Farmland",
	CoalYard = "Coalfield",
	SignalWorks = "Corridor",
	Market = "BurningTown",
	Viaduct = "Highland",
	Minehead = "Mountain",
	Schoolhouse = "Farmland",
	Infirmary = "Highland",
	RailwayHotel = "Corridor",
	PostTown = "BurningTown",
	Terminus = "Coast",
}

-- The first piece of each leg is one of these, rotated by leg, so every run shows them.
local HEADLINERS: { PieceKind } = { "Tunnel", "Gorge", "BurningTown" }

type PieceDef = typeof(J.Pieces[1])

local DEFS: { [string]: PieceDef } = {}
for _, def in J.Pieces do
	DEFS[def.kind] = def
end

-- Biomes -------------------------------------------------------------------------------

function Journey.biomeFor(archetype: string?): Biome
	return if archetype and BIOMES[archetype] then BIOMES[archetype] else Journey.FirstBiome
end

--[[
	The biome mix at land x: (from, to, weight of `to`). Transitions must be sorted
	by `at`; each completed one becomes the base for the next.
]]
function Journey.sample(base: Biome, transitions: { Transition }, x: number): (Biome, Biome, number)
	local current = base
	for _, transition in transitions do
		if x < transition.at then
			break
		end
		local w = MathX.smoothstep(transition.at, transition.at + transition.length, x)
		if w >= 1 then
			current = transition.biome
		else
			return current, transition.biome, w
		end
	end
	return current, current, 0
end

-- Where the destination biome starts to show: a share of the leg, never inside what is already built.
function Journey.blendStart(legStart: number, dock: number, earliest: number): number
	return math.max(legStart + J.BlendAt * (dock - legStart), earliest)
end

-- Set pieces -----------------------------------------------------------------------------

function Journey.def(kind: PieceKind): PieceDef
	return DEFS[kind]
end

--[[
	Every set piece a leg could hold, from PieceStart past the leg start out to
	PlanLength. Deterministic in (seed, leg, legStart). The final leg runs along the
	coast, so its sided pieces all stand inland (side -1) and it has no lake.
]]
function Journey.legPlan(seed: number, leg: number, legStart: number, finalLeg: boolean): { Piece }
	local rng = Rng.new(Rng.derive(seed, "journey", leg))
	local pieces: { Piece } = {}
	local cursor = legStart + J.PieceStart + rng:range(0, 300)
	local previous: string? = nil
	local index = 0
	while cursor < legStart + J.PlanLength do
		index += 1
		local def: PieceDef
		if index == 1 then
			def = DEFS[HEADLINERS[(leg + seed) % #HEADLINERS + 1]]
		else
			local entries: { Rng.Weighted<PieceDef> } = {}
			for _, candidate in J.Pieces do
				if candidate.kind ~= previous and not (finalLeg and candidate.kind == "Lake") then
					table.insert(entries, { weight = candidate.weight, value = candidate })
				end
			end
			def = rng:weighted(entries)
		end
		local length = math.floor(rng:range(def.length[1], def.length[2] + 1))
		local side = 0
		if def.sided then
			side = if finalLeg then -1 else rng:sign()
		end
		table.insert(pieces, {
			kind = def.kind :: PieceKind,
			leg = leg,
			index = index,
			at = cursor,
			length = length,
			side = side,
			style = rng:int(1, 2),
			seed = Rng.derive(seed, "piece", leg, index),
		})
		previous = def.kind
		cursor += length + rng:range(J.PieceGap[1], J.PieceGap[2])
	end
	return pieces
end

-- Keeps the pieces that end at least DockClearance before the sinkhole opens.
function Journey.trim(pieces: { Piece }, sinkhole: Sinkhole): { Piece }
	local kept: { Piece } = {}
	for _, piece in pieces do
		if piece.at + piece.length <= sinkhole.rect.x0 - J.DockClearance then
			table.insert(kept, piece)
		end
	end
	return kept
end

-- The ground a piece reserves: ordinary props keep out of it.
function Journey.footprint(piece: Piece): Rect
	local def = DEFS[piece.kind]
	local z0, z1
	if piece.side > 0 then
		z0, z1 = def.reach[1], def.reach[2]
	elseif piece.side < 0 then
		z0, z1 = -def.reach[2], -def.reach[1]
	else
		z0, z1 = -def.reach[2], def.reach[2]
	end
	return { x0 = piece.at - def.pad, x1 = piece.at + piece.length + def.pad, z0 = z0, z1 = z1 }
end

-- The ground a piece removes outright (a gorge's void), or nil.
function Journey.groundCut(piece: Piece): Rect?
	if piece.kind == "Gorge" then
		return {
			x0 = piece.at,
			x1 = piece.at + piece.length,
			z0 = -J.GorgeHalfWidth,
			z1 = J.GorgeHalfWidth,
		}
	end
	return nil
end

-- Land x of a tunnel's entry and exit portals.
function Journey.tunnelPortals(piece: Piece): (number, number)
	return piece.at + J.TunnelCutting, piece.at + piece.length - J.TunnelCutting
end

-- Stations --------------------------------------------------------------------------------

--[[
	Land x where the station will dock, seen from Cruise with `secondsLeft` of
	cruise to run at the current scenery `speed` (cruise speed when omitted). A
	scenery still spinning up gains Tuning.Motion.SpinUp studs/s² until cruise.
]]
function Journey.dockFromCruise(odometer: number, secondsLeft: number, speed: number?): number
	local cruise = Tuning.Motion.CruiseSpeed
	local accel = Tuning.Motion.SpinUp
	local t = math.max(secondsLeft, 0)
	local v = math.min(speed or cruise, cruise)
	local distance: number
	local spinUp = (cruise - v) / accel
	if spinUp >= t then
		distance = v * t + accel * t * t / 2
	else
		distance = (cruise * cruise - v * v) / (2 * accel) + cruise * (t - spinUp)
	end
	return odometer + distance + Motion.arrivalDistance()
end

function Journey.sinkhole(
	center: number,
	length: number,
	depth: number,
	archetype: string,
	terminus: boolean
): Sinkhole
	local half = length / 2 + J.SinkholeMarginX
	local edge = Tuning.World.PlatformEdgeZ
	return {
		rect = { x0 = center - half, x1 = center + half, z0 = edge, z1 = edge + depth + J.SinkholeMarginZ },
		center = center,
		archetype = archetype,
		terminus = terminus,
	}
end

-- Geometry ----------------------------------------------------------------------------------

function Journey.overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.z0 < b.z1 and b.z0 < a.z1
end

function Journey.contains(rect: Rect, x: number, z: number, margin: number?): boolean
	local m = margin or 0
	return x > rect.x0 - m and x < rect.x1 + m and z > rect.z0 - m and z < rect.z1 + m
end

-- `rect` minus every cut, as non-overlapping rectangles.
function Journey.subtract(rect: Rect, cuts: { Rect }): { Rect }
	local pieces: { Rect } = { rect }
	for _, cut in cuts do
		local nextPieces: { Rect } = {}
		for _, r in pieces do
			if not Journey.overlaps(r, cut) then
				table.insert(nextPieces, r)
			else
				if cut.x0 > r.x0 then
					table.insert(nextPieces, { x0 = r.x0, x1 = cut.x0, z0 = r.z0, z1 = r.z1 })
				end
				if cut.x1 < r.x1 then
					table.insert(nextPieces, { x0 = cut.x1, x1 = r.x1, z0 = r.z0, z1 = r.z1 })
				end
				local mx0, mx1 = math.max(r.x0, cut.x0), math.min(r.x1, cut.x1)
				if cut.z0 > r.z0 then
					table.insert(nextPieces, { x0 = mx0, x1 = mx1, z0 = r.z0, z1 = cut.z0 })
				end
				if cut.z1 < r.z1 then
					table.insert(nextPieces, { x0 = mx0, x1 = mx1, z0 = cut.z1, z1 = r.z1 })
				end
			end
		end
		pieces = nextPieces
	end
	return pieces
end

-- Paints [a, b] over a list of ordered spans with `kind`, splitting where needed.
function Journey.split(spans: { Span }, a: number, b: number, kind: string): { Span }
	local out: { Span } = {}
	for _, span in spans do
		if b <= span.a or a >= span.b then
			table.insert(out, span)
		else
			if a > span.a then
				table.insert(out, { a = span.a, b = a, kind = span.kind })
			end
			table.insert(out, { a = math.max(a, span.a), b = math.min(b, span.b), kind = kind })
			if b < span.b then
				table.insert(out, { a = b, b = span.b, kind = span.kind })
			end
		end
	end
	return out
end

-- The sky ------------------------------------------------------------------------------------

-- How far through a leg the train is. Before the dock is known, a capped guess.
function Journey.legShare(odometer: number, legStart: number, dock: number?): number
	if dock then
		if dock <= legStart then
			return 1 -- joined at the station itself
		end
		return MathX.saturate((odometer - legStart) / (dock - legStart))
	end
	return math.clamp((odometer - legStart) / J.TypicalLeg, 0, J.UnknownShareCap)
end

-- Run progress in legs: 0 at the lobby, 1 docked at the first stop, stops + 1 at the Terminus.
function Journey.progress(leg: number, share: number): number
	return math.max(leg - 1, 0) + MathX.saturate(share)
end

-- Continuous hour for a run progress; past 24 means the small hours of the next day.
function Journey.hour(progress: number, stops: number): number
	local total = stops + 1
	local previousAt, previousHour = -math.huge, 0
	for i, key in J.Sky do
		local at = key.at
		if key.mode == "Share" then
			at = key.at * total
		elseif key.mode == "End" then
			at = total - key.at
		end
		if i == 1 and progress <= at then
			return key.hour
		end
		if progress <= at then
			return MathX.remap(progress, previousAt, at, previousHour, key.hour)
		end
		previousAt, previousHour = at, key.hour
	end
	return previousHour
end

-- Lighting.ClockTime for a continuous hour.
function Journey.clock(hour: number): number
	return hour % 24
end

return table.freeze(Journey)
