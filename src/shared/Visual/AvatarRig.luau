--!strict
-- Stable block proportions and authored clothing anchors for segmented avatars.
local Rig = {}

local CHAINS: { [string]: { string } } = {
	Torso = { "UpperTorso", "LowerTorso" },
	["Left Arm"] = { "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	["Right Arm"] = { "RightUpperArm", "RightLowerArm", "RightHand" },
	["Left Leg"] = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
	["Right Leg"] = { "RightUpperLeg", "RightLowerLeg", "RightFoot" },
}

function Rig.Configure(description: HumanoidDescription)
	for _, property in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
		(description :: any)[property] = 0
	end
	description.HeightScale = 1
	description.WidthScale = 1
	description.DepthScale = 1
	description.HeadScale = 1
	description.BodyTypeScale = 0
	description.ProportionScale = 0
end

function Rig.Part(model: Model, name: string): BasePart?
	local chain = CHAINS[name]
	local part = model:FindFirstChild(if chain then chain[1] else name)
	if part == nil then
		part = model:FindFirstChild(name)
	end
	return if part and part:IsA("BasePart") then part else nil
end

function Rig.Frame(model: Model, name: string): CFrame?
	local part = Rig.Part(model, name)
	if part == nil then
		return nil
	end
	-- Clothing was authored around the centre of a two-stud whole limb.
	-- Keep its top edge aligned to the proximal segment's top edge.
	if CHAINS[name] and part.Name ~= name then
		return part.CFrame * CFrame.new(0, part.Size.Y / 2 - 1, 0)
	end
	return part.CFrame
end

function Rig.Anchor(model: Model, name: string, position: Vector3): BasePart?
	local chain = CHAINS[name]
	if chain == nil then
		return Rig.Part(model, name)
	end
	local best: BasePart? = nil
	local distance = math.huge
	for _, segment in chain do
		local part = model:FindFirstChild(segment)
		if part and part:IsA("BasePart") then
			local d = (part.Position - position).Magnitude
			if d < distance then
				distance = d
				best = part
			end
		end
	end
	return best or Rig.Part(model, name)
end

return Rig
