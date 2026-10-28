--!strict
-- Engine-only construction. Preload yields; Apply commits synchronously.
local Shared = script.Parent.Parent
local Config = require(Shared.Config.CrewClothing)
local Rules = require(Shared.Logic.CrewClothing)
local ContentProvider = game:GetService("ContentProvider")
local Visual = {}
type Snapshot = { originals: Folder, cleanup: RBXScriptConnection }
local snapshots: { [Model]: Snapshot } = {}
local function asset(id: number): string
	return "rbxassetid://" .. tostring(id)
end
function Visual.Preload(recipe: Config.Recipe): boolean
	if not Rules.available(recipe) then
		return false
	end
	local items: { Instance } = {}
	local expected = {}
	local function expect(id: number)
		expected[tostring(id)] = false
	end
	local shirt = Instance.new("Shirt")
	shirt.ShirtTemplate = asset(recipe.shirt)
	expect(recipe.shirt)
	table.insert(items, shirt)
	local pants = Instance.new("Pants")
	pants.PantsTemplate = asset(recipe.pants)
	expect(recipe.pants)
	table.insert(items, pants)
	for _, spec in recipe.accessories do
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshId = asset(spec.mesh)
		mesh.TextureId = asset(spec.texture)
		mesh.MeshType = Enum.MeshType.FileMesh
		expect(spec.mesh)
		expect(spec.texture)
		table.insert(items, mesh)
	end
	local fetched = true
	local ok = pcall(function()
		ContentProvider:PreloadAsync(items, function(contentId, status)
			local id = string.match(tostring(contentId), "%d+")
			if id ~= nil and expected[id] ~= nil then
				expected[id] = status == Enum.AssetFetchStatus.Success
			end
			if status ~= Enum.AssetFetchStatus.Success then
				fetched = false
			end
		end)
	end)
	for _, item in items do
		item:Destroy()
	end
	for _, loaded in expected do
		if not loaded then
			fetched = false
		end
	end
	return ok and fetched
end
local function removeGenerated(character: Model)
	for _, name in { "CrewUniform", "CrewUniformShirt", "CrewUniformPants" } do
		local item = character:FindFirstChild(name)
		if item then
			item:Destroy()
		end
	end
end
function Visual.Restore(character: Model)
	if snapshots[character] == nil then
		return
	end
	removeGenerated(character)
	character:SetAttribute("CrewUniformId", nil)
	local snapshot = snapshots[character]
	snapshot.cleanup:Disconnect()
	for _, original in snapshot.originals:GetChildren() do
		original.Parent = character
	end
	snapshot.originals:Destroy()
	snapshots[character] = nil
end
function Visual.Apply(character: Model, recipe: Config.Recipe): Folder?
	if not Rules.available(recipe) then
		return nil
	end
	local existing = character:FindFirstChild("CrewUniform")
	if existing and existing:IsA("Folder") and character:GetAttribute("CrewUniformId") == recipe.id then
		return existing
	end
	-- Validate and stage everything before touching the avatar. No yields below.
	for _, spec in recipe.accessories do
		local target = character:FindFirstChild(spec.limb)
		if target == nil or not target:IsA("BasePart") then
			return nil
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "CrewUniform"
	for _, spec in recipe.accessories do
		local target = character:FindFirstChild(spec.limb) :: BasePart
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = Vector3.one
		part.Color = Color3.new(1, 1, 1)
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.CFrame = target.CFrame
			* CFrame.new(spec.offset[1], spec.offset[2], spec.offset[3])
			* CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.FileMesh
		mesh.MeshId = asset(spec.mesh)
		mesh.TextureId = asset(spec.texture)
		mesh.Scale = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		mesh.Parent = part
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = target
		weld.Part1 = part
		weld.Parent = part
		part.Parent = folder
	end
	if snapshots[character] == nil then
		local originals = Instance.new("Folder")
		originals.Name = "OriginalAvatarClothing"
		for _, child in character:GetChildren() do
			local garment = child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
			local conflict = child:IsA("Accessory")
				and child.AccessoryType ~= Enum.AccessoryType.Hat
				and child.AccessoryType ~= Enum.AccessoryType.Hair
				and child.AccessoryType ~= Enum.AccessoryType.Face
			if garment or conflict then
				child.Parent = originals
			end
		end
		snapshots[character] = {
			originals = originals,
			cleanup = character.Destroying:Connect(function()
				originals:Destroy()
				snapshots[character] = nil
			end),
		}
	end
	removeGenerated(character)
	local shirt = Instance.new("Shirt")
	shirt.Name = "CrewUniformShirt"
	shirt.ShirtTemplate = asset(recipe.shirt)
	shirt.Parent = character
	local pants = Instance.new("Pants")
	pants.Name = "CrewUniformPants"
	pants.PantsTemplate = asset(recipe.pants)
	pants.Parent = character
	folder.Parent = character
	character:SetAttribute("CrewUniformId", recipe.id)
	return folder
end
return Visual
