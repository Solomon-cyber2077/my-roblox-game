--!strict
--[[
	Deterministic hazard timeline for one station stop.

	t is seconds since the doors opened (dwell start). z is studs measured from
	the platform edge away from the train, so z = 0 is the edge and z = depth is
	the far side. Server and clients evaluate the same functions from the same
	replicated parameters, so no per-frame hazard traffic is needed.

	Fog front:      f(t) = depth                                       for t <= t0
	                f(t) = depth - (depth - zEnd) * v ^ gamma          v = (t - t0) / (T - t0)
	Collapse front: c(t) = max(f(t - lag), safe)
	Spawn count:    N(u) = (T / I) * ((u - u1) + R / 3 * (u^3 - u1^3)),  u = t / T
]]

local Shared = script.Parent.Parent
local MathX = require(Shared.Util.MathX)
local Rng = require(Shared.Util.Rng)
local Types = require(Shared.Types)

type Params = Types.HazardParams

export type Geometry = { depth: number, safe: number }
export type CollapseEvent = { slab: number, warnAt: number, at: number }
export type SlabRef = { id: number, z: number, kind: string }

local BEYOND = 8 -- studs past the far edge where an inactive front waits

local HazardSchedule = {}

function HazardSchedule.fogStartTime(params: Params): number
	return params.fogStartU * params.dwell
end

function HazardSchedule.fogEndZ(params: Params, geo: Geometry): number
	return geo.safe + params.fogEndFraction * (geo.depth - geo.safe)
end

function HazardSchedule.fogFront(params: Params, geo: Geometry, t: number): number
	local total = params.dwell
	local t0 = HazardSchedule.fogStartTime(params)
	if t <= t0 then
		return geo.depth + BEYOND
	end
	local v = MathX.saturate((t - t0) / math.max(total - t0, 1e-3))
	local zEnd = HazardSchedule.fogEndZ(params, geo)
	return geo.depth - (geo.depth - zEnd) * v ^ params.fogGamma
end

function HazardSchedule.collapseFront(params: Params, geo: Geometry, t: number): number
	return math.max(HazardSchedule.fogFront(params, geo, t - params.collapseLag), geo.safe)
end

-- Time at which the collapse front reaches depth z, or nil if it never does before departure.
function HazardSchedule.collapseTimeAt(params: Params, geo: Geometry, z: number): number?
	if z < geo.safe then
		return nil
	end
	local total = params.dwell
	local t0 = HazardSchedule.fogStartTime(params)
	local zEnd = HazardSchedule.fogEndZ(params, geo)
	local tau: number
	if z >= geo.depth then
		tau = t0
	elseif z < zEnd then
		return nil
	else
		local fraction = (geo.depth - z) / math.max(geo.depth - zEnd, 1e-3)
		tau = t0 + fraction ^ (1 / params.fogGamma) * (total - t0)
	end
	local t = tau + params.collapseLag
	if t > total then
		return nil
	end
	return t
end

--[[
	Collapse events for every collapsible slab, sorted by time. Each slab's
	collapse line is shifted by up to `collapseJitter` studs so the edge reads
	as crumbling ground instead of a straight wipe.
]]
function HazardSchedule.collapsePlan(
	params: Params,
	geo: Geometry,
	slabs: { SlabRef },
	seed: number
): { CollapseEvent }
	local rng = Rng.new(Rng.derive(seed, "collapse"))
	local events: { CollapseEvent } = {}
	for _, slab in slabs do
		local jitter = rng:range(-params.collapseJitter, params.collapseJitter)
		if slab.kind ~= "Safe" then
			local at = HazardSchedule.collapseTimeAt(params, geo, math.max(slab.z + jitter, geo.safe))
			if at then
				table.insert(
					events,
					{ slab = slab.id, warnAt = math.max(at - params.collapseWarn, 0), at = at }
				)
			end
		end
	end
	table.sort(events, function(a, b)
		if a.at == b.at then
			return a.slab < b.slab
		end
		return a.at < b.at
	end)
	return events
end

-- Spawn attempt times (seconds into the dwell). The spawner skips an attempt while at the cap.
function HazardSchedule.spawnTimes(params: Params, seed: number): { number }
	local times: { number } = {}
	if params.hollowCap <= 0 then
		return times
	end
	local rng = Rng.new(Rng.derive(seed, "spawns"))
	local total = params.dwell
	local u1 = params.firstSpawnU
	local scale = total / params.spawnInterval
	local ramp = params.spawnRamp / 3
	local threshold = 0
	local count = 0
	local step = 0.002
	local u = u1
	while u <= 1 + 1e-9 do
		local expected = scale * ((u - u1) + ramp * (u ^ 3 - u1 ^ 3))
		if expected >= threshold then
			table.insert(times, u * total)
			count += 1
			threshold = count + rng:range(-0.25, 0.25)
		end
		u += step
	end
	return times
end

-- 0..1 tension used by music layers, camera shake and colour grading.
function HazardSchedule.intensity(params: Params, t: number): number
	local total = params.dwell
	local u = MathX.saturate(t / total)
	local lastCallStart = total - params.lastCall
	local lastCall = if t > lastCallStart then MathX.saturate((t - lastCallStart) / params.lastCall) else 0
	return MathX.saturate(0.75 * u ^ 1.5 + 0.35 * lastCall)
end

return table.freeze(HazardSchedule)
