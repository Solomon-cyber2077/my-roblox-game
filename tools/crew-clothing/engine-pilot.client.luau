--!strict
-- Fixed front view for the isolated pilot scene; no production controllers are loaded.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CrewClothing)
local Visual = require(Shared.Visual.CrewClothing)

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.2, -14), Vector3.new(0, 3.8, 0))
camera.FieldOfView = 42

local shirtClean = Instance.new("Shirt")
shirtClean.ShirtTemplate = "rbxassetid://97730629765220"
local shirtWorn = Instance.new("Shirt")
shirtWorn.ShirtTemplate = "rbxassetid://103847740746022"
local pantsClean = Instance.new("Pants")
pantsClean.PantsTemplate = "rbxassetid://81737309623649"
local pantsWorn = Instance.new("Pants")
pantsWorn.PantsTemplate = "rbxassetid://105374856832482"
local hatMesh = Instance.new("SpecialMesh")
hatMesh.MeshId = "rbxassetid://87294038906929"
hatMesh.TextureId = "rbxassetid://99740939469532"
local gearMesh = Instance.new("SpecialMesh")
gearMesh.MeshId = "rbxassetid://93793321063305"
gearMesh.TextureId = "rbxassetid://99740939469532"
local atlas = Instance.new("Decal")
atlas.Texture = "rbxassetid://99740939469532"
local preloadItems = { shirtClean, shirtWorn, pantsClean, pantsWorn, hatMesh, gearMesh, atlas }
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
recipe.accessories[2] = table.clone(source.accessories[2])
recipe.shirt = 97730629765220
recipe.pants = 81737309623649
recipe.wornShirt = 103847740746022
recipe.wornPants = 105374856832482
recipe.validated = true
recipe.accessories[1].mesh = 87294038906929
recipe.accessories[1].texture = 99740939469532
recipe.accessories[2].mesh = 93793321063305
recipe.accessories[2].texture = 99740939469532
assert(Visual.Preload(recipe), "[CrewClothingPilot] client Visual.Preload failed")
print("[CrewClothingPilot] client Visual.Preload success")

RunService:BindToRenderStep("CrewClothingPilotCamera", Enum.RenderPriority.Camera.Value, function()
	if workspace.CurrentCamera ~= camera then
		return
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.2, -14), Vector3.new(0, 3.8, 0))
end)
