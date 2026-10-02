--!strict
--[[
	Procedural animation for Hollows. Each client writes Motor6D.Transform
	locally from the creature's velocity: a long loping stride, hanging arms,
	a twitching head, and a cowering pose while stunned. No animation assets.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

type Rig = {
	model: Model,
	root: BasePart,
	motors: { [string]: Motor6D },
	phase: number,
	seed: number,
}

local HollowAnimator = {}

local rigs: { [Model]: Rig } = {}

local function register(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if root == nil then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Motor6D") then
			motors[descendant.Name] = descendant
		end
	end
	rigs[model] = { model = model, root = root, motors = motors, phase = 0, seed = math.random() * 100 }
	model.AncestryChanged:Connect(function()
		if model.Parent == nil then
			rigs[model] = nil
		end
	end)
end

function HollowAnimator.Init() end

function HollowAnimator.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Hollows", 60)
		if folder == nil then
			return
		end
		folder.ChildAdded:Connect(function(child)
			task.spawn(register, child)
		end)
		for _, child in folder:GetChildren() do
			task.spawn(register, child)
		end
	end)

	RunService.Stepped:Connect(function(_, dt: number)
		local now = Workspace:GetServerTimeNow()
		local clock = os.clock()
		for _, rig in rigs do
			local m = rig.motors
			local velocity = rig.root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local stride = math.min(speed / 14, 1.3)
			rig.phase += dt * (2 + speed * 0.42)
			local p = rig.phase
			local stunned = (rig.model:GetAttribute("StunnedUntil") or 0) > now
			local twitch = math.noise(clock * 3, rig.seed)

			if stunned then
				local shiver = math.sin(clock * 40) * 0.05
				if m.LeftShoulder then
					m.LeftShoulder.Transform = CFrame.Angles(-2.3 + shiver, 0, 0.35)
				end
				if m.RightShoulder then
					m.RightShoulder.Transform = CFrame.Angles(-2.3 - shiver, 0, -0.35)
				end
				if m.RootJoint then
					m.RootJoint.Transform = CFrame.Angles(0.35, 0, shiver)
				end
				if m.Neck then
					m.Neck.Transform = CFrame.Angles(0.5, 0, 0)
				end
				if m.LeftHip then
					m.LeftHip.Transform = CFrame.Angles(0.3, 0, 0)
				end
				if m.RightHip then
					m.RightHip.Transform = CFrame.Angles(0.3, 0, 0)
				end
			else
				local swing = math.sin(p) * 0.75 * stride
				if m.LeftHip then
					m.LeftHip.Transform = CFrame.Angles(swing, 0, 0)
				end
				if m.RightHip then
					m.RightHip.Transform = CFrame.Angles(-swing, 0, 0)
				end
				if m.LeftShoulder then
					m.LeftShoulder.Transform =
						CFrame.Angles(-swing * 0.8 - 0.25 * stride, 0, 0.08 + math.sin(p * 0.5) * 0.05)
				end
				if m.RightShoulder then
					m.RightShoulder.Transform =
						CFrame.Angles(swing * 0.8 - 0.25 * stride, 0, -0.08 - math.sin(p * 0.5) * 0.05)
				end
				if m.RootJoint then
					local bob = math.abs(math.sin(p)) * 0.3 * stride
					m.RootJoint.Transform = CFrame.new(0, bob, 0)
						* CFrame.Angles(-0.2 * stride, 0, math.sin(p * 0.5) * 0.06)
				end
				if m.Neck then
					m.Neck.Transform =
						CFrame.Angles(twitch * 0.25, math.noise(clock * 2, rig.seed + 7) * 0.6, twitch * 0.15)
				end
			end
		end
	end)
end

-- Distance from `position` to the nearest Hollow, or math.huge when there is none.
function HollowAnimator.Nearest(position: Vector3): number
	local best = math.huge
	for _, rig in rigs do
		best = math.min(best, (rig.root.Position - position).Magnitude)
	end
	return best
end

return HollowAnimator
