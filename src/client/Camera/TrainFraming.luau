--!strict
-- Keep both the train and the moon in frame, including on narrow screens.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local C = Tuning.TrainCamera
local TrainFraming = {}

function TrainFraming.moon(
	center: Vector3,
	direction: Vector3,
	size: number,
	aspect: number
): (Vector3, Vector3, number)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	flat = if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zAxis
	local eye = center - flat * C.MoonDistance + Vector3.yAxis * C.MoonHeight
	local trainDirection = (center - eye).Unit
	local look = (trainDirection + direction).Unit
	local moonAngle = math.deg(math.acos(math.clamp(look:Dot(direction), -1, 1)))
	local right = look:Cross(Vector3.yAxis).Unit
	local up = right:Cross(look).Unit
	local ratio = math.max(aspect, 0.5)
	local extent = math.tan(math.rad(moonAngle + size / 2)) / math.min(ratio, 1)
	for _, x in { -C.TrainRadius, C.TrainRadius } do
		for _, y in { -C.TrainHalfHeight, C.TrainHalfHeight } do
			for _, z in { -C.TrainHalfWidth, C.TrainHalfWidth } do
				local offset = center + Vector3.new(x, y, z) - eye
				local depth = math.max(offset:Dot(look), 1)
				extent = math.max(
					extent,
					math.abs(offset:Dot(up)) / depth,
					math.abs(offset:Dot(right)) / depth / ratio
				)
			end
		end
	end
	local fov = math.deg(2 * math.atan(extent)) + C.MoonMargin * 2
	return eye, eye + look * 400, math.clamp(fov, 34, 100)
end

return TrainFraming
