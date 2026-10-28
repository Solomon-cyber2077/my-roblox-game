-- All seven uniforms side by side on R6 rigs, clean in front and worn behind, applied through
-- Visual.Apply with each recipe marked validated for the pilot only. Studio only; Play and look.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.CrewClothing)
local Visual = require(ReplicatedStorage.Shared.Visual.CrewClothing)

local floor = Instance.new("Part")
floor.Anchored = true
floor.Size = Vector3.new(80, 1, 30)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Parent = workspace

local function rig(position: Vector3): Model
	local model = Players:CreateHumanoidModelFromDescriptionAsync(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R6
	)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.pi, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = part.Name == "HumanoidRootPart"
		end
	end
	model.Parent = workspace
	return model
end

for index, source in Config.List do
	local recipe = table.clone(source)
	recipe.validated = true
	local worn = table.clone(recipe)
	worn.shirt, worn.pants = recipe.wornShirt, recipe.wornPants
	local x = (index - (#Config.List + 1) / 2) * 6
	local clean = rig(Vector3.new(x, 3, 0))
	clean.Name = source.name
	local dirty = rig(Vector3.new(x, 3, 8))
	dirty.Name = source.name .. " (worn)"
	local okClean = Visual.Preload(recipe) and Visual.Apply(clean, recipe) ~= nil
	local okWorn = Visual.Apply(dirty, worn) ~= nil
	print(
		string.format(
			"[LineupPilot] %s %s clean=%s worn=%s",
			if okClean and okWorn then "PASS" else "FAIL",
			source.id,
			tostring(okClean),
			tostring(okWorn)
		)
	)
end
print("[LineupPilot] READY")
