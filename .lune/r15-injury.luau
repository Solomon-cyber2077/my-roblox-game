-- R15 wound placement and complete limb detachment, without a running Studio.
local roblox = require("@lune/roblox")
local Loader = require("./lib/Loader")
local Shim = require("./lib/Shim")

Shim.install()
Loader.env.task = { delay = function() end }
roblox.implementMethod("BasePart", "CanSetNetworkOwnership", function()
	return false
end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
local Wounds = Loader.requireNode(Loader.roots.Server.Builders.Wounds)
local tuning = Loader.requireNode(Loader.roots.Shared.Config.Tuning)
local Instance = roblox.Instance
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3
local character = Instance.new("Model")
local parts = {}

local function part(name, x, y)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = Vector3.new(0.6, 0.6, 0.6)
	value.CFrame = CFrame.new(x, y, 0)
	value.Position = Vector3.new(x, y, 0)
	value.Anchored = true
	value.CanCollide = false
	value.Massless = true
	value.Parent = character
	parts[name] = value
	return value
end

local function motor(name, from, to)
	local value = Instance.new("Motor6D")
	value.Name = name
	value.Part0 = parts[from]
	value.Part1 = parts[to]
	value.C0 = parts[from].CFrame:ToObjectSpace(parts[to].CFrame)
	value.Parent = parts[to]
	return value
end

part("UpperTorso", 0, 3)
part("LowerTorso", 0, 2)
part("Head", 0, 4)
motor("Neck", "UpperTorso", "Head")
for _, side in { "Left", "Right" } do
	local x = if side == "Left" then -1 else 1
	part(side .. "UpperArm", x, 3)
	part(side .. "LowerArm", x, 2)
	part(side .. "Hand", x, 1.5)
	part(side .. "UpperLeg", x * 0.5, 1.5)
	part(side .. "LowerLeg", x * 0.5, 0.5)
	part(side .. "Foot", x * 0.5, 0)
	motor(side .. "Shoulder", "UpperTorso", side .. "UpperArm")
	motor(side .. "Elbow", side .. "UpperArm", side .. "LowerArm")
	motor(side .. "Wrist", side .. "LowerArm", side .. "Hand")
	motor(side .. "Hip", "LowerTorso", side .. "UpperLeg")
	motor(side .. "Knee", side .. "UpperLeg", side .. "LowerLeg")
	motor(side .. "Ankle", side .. "LowerLeg", side .. "Foot")
end

local rng = Loader.env.Random.new(32)
for _, area in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
	Wounds.mark(character, area, rng)
end
local marks = character:FindFirstChild("Wounds")
assert(marks and #marks:GetChildren() == 6, "Every R15 grab area must carry its wound")
for _ = 1, 8 do
	Wounds.mark(character, "LeftArm", rng)
end
local armMarks = 0
for _, mark in marks:GetChildren() do
	if mark:GetAttribute("Limb") == "LeftUpperArm" then
		armMarks += 1
	end
end
assert(armMarks == tuning.Trauma.WoundsPerLimb, "Wound cap must survive segmented limbs")

assert(Wounds.sever(character, "LeftArm") == 1, "Shoulder must be found under its R15 child")
assert(Wounds.sever(character, "LeftArm") == 0, "An already severed arm must be harmless")
assert(character:FindFirstChild("LeftElbow", true), "Detached arm must retain its elbow")
assert(character:FindFirstChild("LeftWrist", true), "Detached arm must retain its hand")
for _, name in { "LeftUpperArm", "LeftLowerArm", "LeftHand" } do
	assert(
		not parts[name].Anchored and parts[name].CanCollide and not parts[name].Massless,
		name .. " must fall with the arm"
	)
end
assert(Wounds.sever(character, "Torso") == 2, "Both hips must detach from LowerTorso")
for _, side in { "Left", "Right" } do
	assert(character:FindFirstChild(side .. "Knee", true), side .. " knee must stay attached")
	assert(character:FindFirstChild(side .. "Ankle", true), side .. " ankle must stay attached")
	assert(
		not parts[side .. "Foot"].Anchored and parts[side .. "Foot"].CanCollide,
		side .. " foot must fall with the leg"
	)
end
assert(Wounds.sever(character, "Head") == 1, "Neck must detach from UpperTorso")
character:Destroy()
print(
	"R15 injury checks passed: six wound areas, wound cap, repeat-safe severing, complete arm/leg chains, neck."
)
