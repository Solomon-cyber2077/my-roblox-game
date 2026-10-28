-- Fixed camera on the lineup: 1 front, 2 back.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local camera = workspace.CurrentCamera
local view = Vector3.new(0, 5, -30)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.One then
		view = Vector3.new(0, 5, -30)
	elseif input.KeyCode == Enum.KeyCode.Two then
		view = Vector3.new(0, 5, 38)
	end
end)
RunService:BindToRenderStep("LineupCamera", Enum.RenderPriority.Last.Value + 50, function()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 50
	camera.CFrame = CFrame.lookAt(view, Vector3.new(0, 3, 4))
end)
