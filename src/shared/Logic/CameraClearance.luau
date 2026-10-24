--!strict

-- Pure clearance rules for the lobby idle view. The client casts (Camera/IdleClearance);
-- this module sizes the probe and turns the cast results into a bounded distance or an
-- explicit unavailable result. It never pushes the view through geometry to reach a minimum.
local CameraClearance = {}

export type Query = {
	desired: number, -- studs from the focus the view wants to sit
	minDistance: number, -- closer than this is unavailable
	hitDistance: number?, -- how far the probe travelled from the focus before touching geometry
	overlap: boolean, -- the probe already touched geometry at the focus
	sweepBlocked: boolean, -- the path from the previous accepted pose hit geometry
	previous: number?, -- the last accepted distance
	maxOut: number, -- studs the view may move outward this step
}

export type Result = { ok: true, distance: number } | { ok: false, reason: string }

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

-- Half width and half height of the near plane for a vertical FOV in degrees.
function CameraClearance.nearPlane(fovY: number, aspect: number, near: number): (number?, number?)
	if not (finite(fovY) and finite(aspect) and finite(near)) then
		return nil, nil
	end
	if fovY <= 0 or fovY >= 180 or aspect <= 0 or near <= 0 then
		return nil, nil
	end
	local halfH = near * math.tan(math.rad(fovY) / 2)
	return halfH * aspect, halfH
end

-- Radius of a sphere that holds the whole near plane (all four corners) plus the margin.
function CameraClearance.probeRadius(fovY: number, aspect: number, near: number, margin: number): number?
	if not finite(margin) or margin < 0 then
		return nil
	end
	local halfW, halfH = CameraClearance.nearPlane(fovY, aspect, near)
	if halfW == nil or halfH == nil then
		return nil
	end
	return math.sqrt(halfW * halfW + halfH * halfH + near * near) + margin
end

function CameraClearance.resolve(q: Query): Result
	if not (finite(q.desired) and finite(q.minDistance) and finite(q.maxOut)) then
		return { ok = false, reason = "invalid" }
	end
	if q.minDistance < 0 or q.maxOut < 0 or q.desired <= 0 then
		return { ok = false, reason = "invalid" }
	end
	if q.desired < q.minDistance then
		return { ok = false, reason = "too-close" }
	end
	if q.overlap then
		return { ok = false, reason = "overlap" }
	end
	if q.sweepBlocked then
		return { ok = false, reason = "sweep" }
	end
	local allowed = q.desired
	local hit = q.hitDistance
	if hit ~= nil then
		if not finite(hit) or hit < 0 then
			return { ok = false, reason = "invalid" }
		end
		allowed = math.min(allowed, hit)
	end
	if allowed < q.minDistance then
		return { ok = false, reason = "blocked" }
	end
	-- In at once for safety; back out only gradually.
	local previous = q.previous
	if previous ~= nil and finite(previous) and allowed > previous then
		allowed = math.max(math.min(allowed, previous + q.maxOut), q.minDistance)
	end
	return { ok = true, distance = allowed }
end

return CameraClearance
