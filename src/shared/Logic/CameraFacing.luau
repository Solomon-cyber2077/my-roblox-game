--!strict

-- Pure turning for the Locked camera's body facing: the body turns to the camera's heading
-- (CameraController). Yaw is in radians about +Y, 0 looking down -Z, as CFrame.Angles(0, yaw, 0).
local CameraFacing = {}

local TAU = 2 * math.pi

-- The heading of a look vector, or nil when it points too nearly straight up or down to have one.
function CameraFacing.yaw(lookX: number, lookZ: number): number?
	if lookX * lookX + lookZ * lookZ < 1e-6 then
		return nil
	end
	return math.atan2(-lookX, -lookZ)
end

-- The signed shortest turn from `from` to `to`, in (-pi, pi].
function CameraFacing.delta(from: number, to: number): number
	local d = (to - from) % TAU
	if d > math.pi then
		d -= TAU
	end
	return d
end

-- One frame of turning toward `target`: the gap closes by 1 - e^(-rate * dt), so it is quick
-- but never snaps, and the same at any frame rate.
function CameraFacing.turn(current: number, target: number, dt: number, rate: number): number
	if dt <= 0 or rate <= 0 then
		return current
	end
	return current + CameraFacing.delta(current, target) * (1 - math.exp(-rate * dt))
end

return CameraFacing
