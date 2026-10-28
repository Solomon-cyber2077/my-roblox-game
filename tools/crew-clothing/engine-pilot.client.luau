--!strict
-- Fixed front view for the isolated pilot scene; no production controllers are loaded.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CrewClothing)
local Visual = require(Shared.Visual.CrewClothing)

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 42

local target = Vector3.new(0, 3.8, 0)
local views: { [string]: Vector3 } = {
	front = Vector3.new(0, 4.2, -14),
	back = Vector3.new(0, 4.2, 14),
	left = Vector3.new(-14, 4.2, 0),
	right = Vector3.new(14, 4.2, 0),
}
local view = "front"
camera.CFrame = CFrame.lookAt(views[view], target)

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local nextView = ({
		[Enum.KeyCode.One] = "front",
		[Enum.KeyCode.Two] = "back",
		[Enum.KeyCode.Three] = "left",
		[Enum.KeyCode.Four] = "right",
	} :: { [Enum.KeyCode]: string })[input.KeyCode]
	if nextView ~= nil then
		view = nextView
		print("[CrewClothingPilot] camera view=" .. view)
	end
end)

local shirtClean = Instance.new("Shirt")
shirtClean.ShirtTemplate = "rbxassetid://101979354774166"
local shirtWorn = Instance.new("Shirt")
shirtWorn.ShirtTemplate = "rbxassetid://90317117594409"
local pantsClean = Instance.new("Pants")
pantsClean.PantsTemplate = "rbxassetid://104204802579148"
local pantsWorn = Instance.new("Pants")
pantsWorn.PantsTemplate = "rbxassetid://100087790691733"
local gearMesh = Instance.new("SpecialMesh")
gearMesh.MeshId = "rbxassetid://90362864770621"
gearMesh.TextureId = "rbxassetid://85553773814164"
local atlas = Instance.new("Decal")
atlas.Texture = "rbxassetid://85553773814164"
local preloadItems = { shirtClean, shirtWorn, pantsClean, pantsWorn, gearMesh, atlas }
for _, item in preloadItems do
	local ok, status = pcall(function(): Enum.AssetFetchStatus
		local result: Enum.AssetFetchStatus? = nil
		ContentProvider:PreloadAsync({ item }, function(_, fetched)
			result = fetched
		end)
		return result or Enum.AssetFetchStatus.None
	end)
	print(
		"[CrewClothingPilot] client asset="
			.. item.ClassName
			.. " ok="
			.. tostring(ok)
			.. " status="
			.. tostring(status)
	)
end

local source = Config.ById.uniform_stoker
local recipe = table.clone(source)
recipe.accessories = table.clone(source.accessories)
recipe.accessories[1] = table.clone(source.accessories[1])
recipe.shirt = 101979354774166
recipe.pants = 104204802579148
recipe.wornShirt = 90317117594409
recipe.wornPants = 100087790691733
recipe.validated = true
recipe.accessories[1].yaw = 180
recipe.accessories[1].mesh = 90362864770621
recipe.accessories[1].texture = 85553773814164
recipe.accessories[1].size = { 1.625, 1.83, 0.231 }
recipe.accessories[1].offset = { 0.0425, 0.065, -0.6155 }
assert(Visual.Preload(recipe), "[CrewClothingPilot] client Visual.Preload failed")
print("[CrewClothingPilot] client Visual.Preload success")

RunService:BindToRenderStep("CrewClothingPilotCamera", Enum.RenderPriority.Camera.Value, function()
	if workspace.CurrentCamera ~= camera then
		return
	end
	camera.CFrame = CFrame.lookAt(views[view], target)
end)
