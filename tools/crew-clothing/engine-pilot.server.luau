--!strict
-- Narrow engine pilot: verifies the imported Stoker assets against an R6 rig.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config.CrewClothing)
local Visual = require(Shared.Visual.CrewClothing)

Players.CharacterAutoLoads = false

local function check(ok: boolean, message: string)
	if not ok then
		error("[CrewClothingPilot] " .. message, 2)
	end
	print("[CrewClothingPilot] PASS " .. message)
end

local function near(actual: number, expected: number): boolean
	return math.abs(actual - expected) < 0.001
end

local function pilotRecipe(): any
	local source = Config.ById.uniform_stoker
	check(source ~= nil, "uniform_stoker recipe exists")
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
	return recipe
end

local function makeRig(name: string, position: Vector3): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = BrickColor.new("Light orange").Color
	description.LeftArmColor = BrickColor.new("Light orange").Color
	description.RightArmColor = BrickColor.new("Light orange").Color
	description.LeftLegColor = BrickColor.new("Dark stone grey").Color
	description.RightLegColor = BrickColor.new("Dark stone grey").Color
	description.TorsoColor = BrickColor.new("Dark stone grey").Color
	local rig = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
	rig.Name = name
	rig:PivotTo(CFrame.new(position))
	local boundsCFrame, boundsSize = rig:GetBoundingBox()
	local minimumY = boundsCFrame.Position.Y - boundsSize.Y / 2
	rig:PivotTo(rig:GetPivot() + Vector3.new(0, 0.5 - minimumY, 0))
	for _, child in rig:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
		end
	end
	rig.Parent = workspace
	return rig
end

local floor = Instance.new("Part")
floor.Name = "CrewClothingPilotFloor"
floor.Size = Vector3.new(32, 1, 18)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Anchored = true
floor.Color = Color3.fromRGB(52, 52, 58)
floor.Parent = workspace

local recipe = pilotRecipe()
local clean = makeRig("StokerClean", Vector3.new(-3, 3, 0))
local worn = makeRig("StokerWorn", Vector3.new(3, 3, 0))
local originalShirt = Instance.new("Shirt")
originalShirt.Name = "OriginalShirt"
originalShirt.ShirtTemplate = "rbxassetid://0"
originalShirt.Parent = clean
local originalPants = Instance.new("Pants")
originalPants.Name = "OriginalPants"
originalPants.PantsTemplate = "rbxassetid://0"
originalPants.Parent = clean
local originalHat = Instance.new("Accessory")
originalHat.Name = "OriginalHat"
originalHat.AccessoryType = Enum.AccessoryType.Hat
originalHat.Parent = clean
local originalHair = Instance.new("Accessory")
originalHair.Name = "OriginalHair"
originalHair.AccessoryType = Enum.AccessoryType.Hair
originalHair.Parent = clean
local originalFaceAccessory = Instance.new("Accessory")
originalFaceAccessory.Name = "OriginalFace"
originalFaceAccessory.AccessoryType = Enum.AccessoryType.Face
originalFaceAccessory.Parent = clean

local function addHandle(accessory: Accessory, transparency: number): BasePart
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = transparency
	handle.Massless = true
	handle.CanCollide = false
	handle.Parent = accessory
	return handle
end

local hatHandle = addHandle(originalHat, 0.2)
local hairHandle = addHandle(originalHair, 0.35)
local faceHandle = addHandle(originalFaceAccessory, 0.5)

local head = clean:FindFirstChild("Head")
check(head ~= nil and head:IsA("BasePart"), "R6 head remains present")
local originalHead = head :: BasePart
local originalCFrame = originalHead.CFrame
local originalFace = originalHead:FindFirstChild("face")
if originalFace == nil then
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Parent = originalHead
	originalFace = face
end
local jointSnapshots = {}
for _, descendant in clean:GetDescendants() do
	if descendant:IsA("Motor6D") then
		table.insert(
			jointSnapshots,
			{ instance = descendant, parent = descendant.Parent, c0 = descendant.C0, c1 = descendant.C1 }
		)
	end
end
local partSnapshots = {}
for _, descendant in clean:GetDescendants() do
	if descendant:IsA("BasePart") then
		table.insert(partSnapshots, {
			instance = descendant,
			size = descendant.Size,
			canCollide = descendant.CanCollide,
			massless = descendant.Massless,
		})
	end
end

local first = Visual.Apply(clean, recipe)
check(first ~= nil, "clean Apply creates uniform")
local second = Visual.Apply(clean, recipe)
check(first == second, "second Apply is idempotent")
local shirt = clean:FindFirstChildWhichIsA("Shirt")
local pants = clean:FindFirstChildWhichIsA("Pants")
check(shirt ~= nil and pants ~= nil, "classic garments exist")
check(originalHat.Parent == clean and originalHair.Parent == clean, "Apply preserves player hat and hair")
check(originalFaceAccessory.Parent == clean, "Apply preserves player face accessory")
check(
	near(hatHandle.Transparency, 0.2)
		and near(hairHandle.Transparency, 0.35)
		and near(faceHandle.Transparency, 0.5),
	"Apply preserves accessory handle transparency"
)
local appliedFolder = clean:FindFirstChild("CrewUniform")
check(
	appliedFolder ~= nil
		and appliedFolder:FindFirstChild("Gear") ~= nil
		and appliedFolder:FindFirstChild("Hat") == nil,
	"Apply creates gear without a hat"
)
Visual.Restore(clean)
check(clean:FindFirstChild("CrewUniform") == nil, "Restore removes generated uniform")
check(
	originalHead.Parent == clean
		and originalHead.CFrame == originalCFrame
		and originalFace.Parent == originalHead,
	"Restore preserves head and face identity and pose"
)
check(
	originalShirt.Parent == clean and originalPants.Parent == clean,
	"Restore preserves original garment identity"
)
check(
	originalHat.Parent == clean and originalHair.Parent == clean,
	"Restore preserves player hat and hair identity"
)
check(originalFaceAccessory.Parent == clean, "Restore preserves player face accessory identity")
check(
	hatHandle.Parent == originalHat
		and hairHandle.Parent == originalHair
		and faceHandle.Parent == originalFaceAccessory,
	"Restore preserves accessory handles"
)
check(
	near(hatHandle.Transparency, 0.2)
		and near(hairHandle.Transparency, 0.35)
		and near(faceHandle.Transparency, 0.5),
	"Restore preserves accessory handle transparency"
)
for _, snapshot in jointSnapshots do
	check(
		snapshot.instance.Parent == snapshot.parent
			and snapshot.instance.C0 == snapshot.c0
			and snapshot.instance.C1 == snapshot.c1,
		"Restore preserves Motor6D " .. snapshot.instance.Name
	)
end
for _, snapshot in partSnapshots do
	check(
		snapshot.instance.Size == snapshot.size
			and snapshot.instance.CanCollide == snapshot.canCollide
			and snapshot.instance.Massless == snapshot.massless,
		"Restore preserves part properties " .. snapshot.instance.Name
	)
end

local wornRecipe = table.clone(recipe)
wornRecipe.accessories = recipe.accessories
wornRecipe.shirt = recipe.wornShirt
wornRecipe.pants = recipe.wornPants
check(Visual.Apply(worn, wornRecipe) ~= nil, "worn Apply creates uniform")
check(Visual.Apply(clean, recipe) ~= nil, "side-by-side clean uniform creates")
local cleanUniform = clean:FindFirstChild("CrewUniform")
local wornUniform = worn:FindFirstChild("CrewUniform")
check(cleanUniform ~= nil and #cleanUniform:GetChildren() == 1, "clean uniform has one built gear item")
check(wornUniform ~= nil and #wornUniform:GetChildren() == 1, "worn uniform has one built gear item")
