--!strict
-- Fixed front view for the isolated pilot scene; no production controllers are loaded.
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Animation = game:GetService("ReplicatedStorage"):WaitForChild("Animation")
local Config = require(Shared.Config.CrewClothing)
local Visual = require(Shared.Visual.CrewClothing)
local CrewPoses = require(Animation.CrewPoses)

local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 42

local target = Vector3.new(0, 3.8, 0)
local views: { [string]: Vector3 } = {
	front = Vector3.new(0, 4.2, -25),
	back = Vector3.new(0, 4.2, 25),
	left = Vector3.new(-25, 4.2, 0),
	right = Vector3.new(25, 4.2, 0),
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

-- a failed fetch is reported, not swallowed: a recipe whose mesh does not exist must not preload
local broken = table.clone(recipe)
broken.accessories = { table.clone(recipe.accessories[1]) }
broken.accessories[1].mesh = 1
local failStarted = os.clock()
local brokenLoaded = Visual.Preload(broken)
print(
	string.format(
		"[CrewClothingPilot] %s client failed preload returns false (%.1f s)",
		if brokenLoaded then "FAIL" else "PASS",
		os.clock() - failStarted
	)
)

type PoseSpec = { name: string, input: any, make: ((now: number, seed: number) -> any)? }
local poses: { PoseSpec } = {
	{ name = "Idle", input = { speed = 0, phase = 0 } },
	{ name = "Walk", input = { speed = 4, phase = 0.8 } },
	{ name = "Run", input = { speed = 16, phase = 1.1 } },
	{ name = "Landing crouch", input = { speed = 0, phase = 0, crouching = true } },
	{ name = "Sit", input = { speed = 0, phase = 0, sitting = true } },
	{
		name = "Hang",
		input = {},
		make = function(now, seed)
			return CrewPoses.hang(now % 3, now, seed)
		end,
	},
	{
		name = "Haul",
		input = {},
		make = function(now, seed)
			return CrewPoses.haul(now % 3, now, seed)
		end,
	},
	{
		name = "Fall short",
		input = {},
		make = function(now, seed)
			return CrewPoses.fallShort(now % 3, now, seed)
		end,
	},
	{
		name = "Limp (death)",
		input = {},
		make = function(now, seed)
			return CrewPoses.limp(now, seed)
		end,
	},
}
-- every grab, struggling hard (the pry and wrench poses)
for _, style in { "Throttle", "Embrace", "Drag", "Pin", "Latch", "Ride", "Fist", "Shovel" } do
	table.insert(poses, {
		name = "Grab " .. style,
		input = {},
		make = function(now, seed)
			return CrewPoses.grabbed(style, now % 3, 0.9, 1, now, seed)
		end,
	})
end

local gearOffsets: { [Model]: { [BasePart]: CFrame } } = {}

local function applyPose(rig: Model, spec: PoseSpec, seed: number, now: number?)
	local input = {
		now = now or 0,
		seed = seed,
		speed = spec.input.speed or 0,
		vertical = 0,
		grounded = true,
		phase = spec.input.phase or 0,
		sitting = spec.input.sitting == true,
		load = 0,
		sprinting = false,
		exhausted = false,
		landing = spec.input.landing or 0,
		lookYaw = 0,
		lookPitch = 0,
		dread = 0,
		turn = 0,
	}
	if spec.input.crouching then
		input.landing = 0.85
	end
	local pose = if spec.make then spec.make(now or 0, seed) else CrewPoses.locomote(input)
	local jointOrder = { "RootJoint", "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }
	local moved = 0
	for _, jointName in jointOrder do
		local transform = pose[jointName]
		local joint = rig:FindFirstChild(jointName, true)
		if transform ~= nil and joint ~= nil and joint:IsA("Motor6D") then
			local part0 = joint.Part0
			local part1 = joint.Part1
			if part0 ~= nil and part1 ~= nil then
				local before = part1.Position
				part1.CFrame = part0.CFrame * joint.C0 * transform * joint.C1:Inverse()
				moved += (part1.Position - before).Magnitude
			end
		end
	end
	rig:SetAttribute("PilotJointDelta", moved)
	local torso = rig:FindFirstChild("Torso")
	if torso ~= nil and torso:IsA("BasePart") then
		local offsets = gearOffsets[rig]
		if offsets == nil then
			offsets = {}
			local uniform = rig:FindFirstChild("CrewUniform")
			if uniform ~= nil then
				for _, descendant in uniform:GetDescendants() do
					if descendant:IsA("BasePart") then
						offsets[descendant] = torso.CFrame:ToObjectSpace(descendant.CFrame)
					end
				end
			end
			gearOffsets[rig] = offsets
		end
		for part, offset in offsets do
			part.CFrame = torso.CFrame * offset
		end
	end
	rig:SetAttribute("PilotPose", spec.name)
	local head = rig:FindFirstChild("Head")
	if head ~= nil and head:IsA("BasePart") then
		local label = head:FindFirstChild("PilotLabel")
		if label == nil then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "PilotLabel"
			billboard.Size = UDim2.fromOffset(140, 28)
			billboard.StudsOffset = Vector3.new(0, 1.7, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = head
			label = billboard
		end
		local text = label:FindFirstChild("Text")
		if text == nil then
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Text"
			textLabel.Size = UDim2.fromScale(1, 1)
			textLabel.BackgroundTransparency = 1
			textLabel.TextColor3 = Color3.new(1, 1, 1)
			textLabel.TextStrokeTransparency = 0.35
			textLabel.TextScaled = true
			textLabel.Parent = label
			text = textLabel
		end
		(text :: TextLabel).Text = (if rig.Name:find("Worn") then "WORN " else "CLEAN ") .. spec.name
	end
end

local cleanSource = workspace:WaitForChild("StokerClean") :: Model
local wornSource = workspace:WaitForChild("StokerWorn") :: Model
local function placeOnFloor(rig: Model, position: Vector3)
	rig:PivotTo(CFrame.new(position))
	local bounds, size = rig:GetBoundingBox()
	local minimumY = bounds.Position.Y - size.Y / 2
	rig:PivotTo(rig:GetPivot() + Vector3.new(0, 0.5 - minimumY, 0))
end

placeOnFloor(cleanSource, Vector3.new(-2.4, 0, 0))
placeOnFloor(wornSource, Vector3.new(2.4, 0, 0))
local lineup = {
	{ rig = cleanSource, seed = 17 },
	{ rig = wornSource, seed = 18 },
}
for _, entry in lineup do
	applyPose(entry.rig, poses[1], entry.seed)
end
print("[CrewClothingPilot] phase=Idle moving=false")

local elapsed = 0
local phase = 1
RunService.Heartbeat:Connect(function(delta)
	elapsed += delta
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	local nextPhase = math.floor(os.clock() / 3) % #poses + 1
	if nextPhase ~= phase then
		phase = nextPhase
		print("[CrewClothingPilot] phase=" .. poses[phase].name .. " moving=true")
	end
	for _, entry in lineup do
		applyPose(entry.rig, poses[phase], entry.seed, os.clock())
	end
end)

RunService:BindToRenderStep("CrewClothingPilotCamera", Enum.RenderPriority.Camera.Value, function()
	if workspace.CurrentCamera ~= camera then
		return
	end
	camera.CFrame = CFrame.lookAt(views[view], target)
end)
