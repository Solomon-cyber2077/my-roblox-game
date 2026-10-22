--!strict
--[[
	The void mist's rules (prompts/VM1-VM7). Pure, on the ground plane (x, z) of whatever space the
	caller works in (station-local on the server, world on the client): a rail is its centre, the
	unit direction from the train toward the sinkhole (outward) and its width.

	  zone          the BufferDepth strip on the train side of the rail
	  depth01       0 at the zone's inner face, 1 at the rail
	  outwardCap    outward speed allowed at that depth: CurrentMaxOut x (1 - depth01)
	  clampOutward  takes away only the outward speed above the cap; Y, inward and sideways motion
	                are never touched, and nothing pushes back (no spring)
	  proximity     1 at the zone, falling to 0 at ProximityRange: the tint and hum
]]

local Tuning = require(script.Parent.Parent.Config.Tuning)
local V = Tuning.VoidMist

local VoidMist = {}

local EPS = 1e-6 -- the faces themselves count as inside

export type Zone = {
	x: number, -- the rail's centre
	z: number,
	ox: number, -- unit outward (toward the sinkhole)
	oz: number,
	width: number,
	depth: number,
}

-- A rail at (x, z) facing the train along (fx, fz) (its frame's -Z), width studs wide.
function VoidMist.zone(x: number, z: number, fx: number, fz: number, width: number): Zone
	local len = math.sqrt(fx * fx + fz * fz)
	assert(len > 1e-6, "rail facing must be horizontal")
	return { x = x, z = z, ox = -fx / len, oz = -fz / len, width = width, depth = V.BufferDepth }
end

-- (along, back): along the rail from its centre, and back from the rail toward the train.
local function frame(zone: Zone, px: number, pz: number): (number, number)
	local dx, dz = px - zone.x, pz - zone.z
	return dx * -zone.oz + dz * zone.ox, -(dx * zone.ox + dz * zone.oz)
end

function VoidMist.isInside(zone: Zone, px: number, pz: number): boolean
	local along, back = frame(zone, px, pz)
	return math.abs(along) <= zone.width / 2 + EPS and back >= -EPS and back <= zone.depth + EPS
end

function VoidMist.depth01(zone: Zone, px: number, pz: number): number
	local _, back = frame(zone, px, pz)
	return math.clamp(1 - back / zone.depth, 0, 1)
end

-- Ground distance to the zone's strip, 0 inside. Past the rail counts as inside the rail's reach.
function VoidMist.distanceTo(zone: Zone, px: number, pz: number): number
	local along, back = frame(zone, px, pz)
	local da = math.max(0, math.abs(along) - zone.width / 2)
	local db = math.max(0, back - zone.depth)
	return math.sqrt(da * da + db * db)
end

function VoidMist.proximity(distance: number): number
	return 1 - math.clamp(distance / V.ProximityRange, 0, 1)
end

function VoidMist.outwardCap(depth: number): number
	return V.CurrentMaxOut * (1 - math.clamp(depth, 0, 1))
end

-- The velocity (vx, vz) with outward speed above cap removed; vy is the caller's to keep.
function VoidMist.clampOutward(vx: number, vz: number, zone: Zone, cap: number): (number, number)
	local out = vx * zone.ox + vz * zone.oz
	if out <= cap then
		return vx, vz
	end
	local excess = out - cap
	return vx - zone.ox * excess, vz - zone.oz * excess
end

export type Preset = { mist: { number }, tint: { number } }

function VoidMist.preset(name: string?): (string, Preset)
	local presets = V.Presets :: { [string]: Preset }
	if name and presets[name] then
		return name, presets[name]
	end
	return V.DefaultPreset, presets[V.DefaultPreset]
end

return VoidMist
