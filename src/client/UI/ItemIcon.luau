--!strict
-- Renders an item's procedural model inside a ViewportFrame, the same model players see on the ground.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemModel = require(ReplicatedStorage.Shared.Visual.ItemModel)

local ItemIcon = {}

function ItemIcon.new(itemId: string, size: UDim2, angle: number?): ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Icon"
	viewport.BackgroundTransparency = 1
	viewport.Size = size
	viewport.Ambient = Color3.fromRGB(150, 140, 128)
	viewport.LightColor = Color3.fromRGB(255, 236, 210)
	viewport.LightDirection = Vector3.new(-1, -1.4, -0.6)

	local model = ItemModel.build(itemId, CFrame.Angles(0, math.rad(angle or 25), 0), 1)
	model.Parent = viewport

	local radius = ItemModel.radius(itemId)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	camera.CFrame = CFrame.lookAt(Vector3.new(radius * 2.4, radius * 1.7, radius * 3.1), Vector3.new(0, 0, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

return ItemIcon
