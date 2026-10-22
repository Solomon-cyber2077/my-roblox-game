--!strict
--[[
	The void mist's current (prompts/VM4; rules in Logic/VoidMist): walking outward through the
	edge zone in front of a sinkhole rail feels like wading against a current that slows you to a
	stop at the rail. Each physics step, outward speed above CurrentMaxOut x (1 - depth) is taken
	away. Nothing pushes back (no spring); Y, inward and sideways motion are never touched. The
	rail (MistService, StationDressing EdgeMark) is the hard stop; this is feel only, so it runs
	here, where the character's physics are.

	Why the move and not only the velocity: the Humanoid controller drives the root back to
	MoveDirection x WalkSpeed every step, so clamping AssemblyLinearVelocity alone was undone
	(Studio: still 21 studs/s at the rail), and a VectorForce would fight the controller. So the
	walk itself is capped: after the controls set this frame's move, Humanoid:Move gets the same
	move with its outward share capped (a partial move walks slower, like a half-pushed stick),
	bound to render just after the controls; in PreSimulation the Humanoid had already taken the
	frame's move (Studio: the capped Move there changed nothing).
	The velocity clamp stays for motion the walk does not explain.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local TutorialConfig = require(Shared.Config.Tutorial)
local VoidMist = require(Shared.Logic.VoidMist)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)

local V = Tuning.VoidMist
local NEAR = 20 -- studs: rails further than this (plus their half width) are skipped

local VoidCurrentController = {}

local rails: { [BasePart]: boolean } = {}
local label: TextLabel? = nil

-- The edge zone of a rail where it stands now, in world space (the station may be moving).
local function zoneOf(rail: BasePart): VoidMist.Zone
	local look = rail.CFrame.LookVector
	return VoidMist.zone(rail.Position.X, rail.Position.Z, look.X, look.Z, rail.Size.X)
end

local function debugLabel(): TextLabel?
	if not (V.Debug and RunService:IsStudio()) then
		return nil
	end
	if label == nil then
		local gui = Instance.new("ScreenGui")
		gui.Name = "VoidCurrentDebug"
		gui.ResetOnSpawn = false
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromOffset(260, 22)
		text.Position = UDim2.new(0, 8, 1, -120)
		text.BackgroundTransparency = 0.4
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Font = Enum.Font.Code
		text.TextSize = 14
		text.Parent = gui
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		label = text
	end
	return label
end

-- The local character and the deepest edge zone round them now: (root, humanoid, zone, depth),
-- or nil while dead, held, anchored or out of every zone.
local function current(): (BasePart?, Humanoid?, VoidMist.Zone?, number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root == nil or humanoid == nil or humanoid.Health <= 0 or root.Anchored then
		return nil, nil, nil, 0
	end
	if Registry.GrabController.IsHeld() then
		return nil, nil, nil, 0
	end
	local p = root.Position
	local best: VoidMist.Zone? = nil
	local bestDepth = -1
	for rail in rails do
		local gap = (rail.Position - p) * Vector3.new(1, 0, 1)
		if gap.Magnitude <= NEAR + rail.Size.X / 2 then
			local zone = zoneOf(rail)
			if VoidMist.isInside(zone, p.X, p.Z) then
				local depth = VoidMist.depth01(zone, p.X, p.Z)
				if depth > bestDepth then
					best, bestDepth = zone, depth
				end
			end
		end
	end
	return root, humanoid, best, bestDepth
end

-- The walk: right after the controls set this frame's move, the same move with its outward
-- share capped.
local function capMove()
	local _, humanoid, zone, depth = current()
	if humanoid == nil or zone == nil then
		return
	end
	local move = humanoid.MoveDirection
	local speed = humanoid.WalkSpeed
	if speed > 0 and move.Magnitude > 0 then
		local mx, mz = VoidMist.clampOutward(move.X * speed, move.Z * speed, zone, VoidMist.outwardCap(depth))
		humanoid:Move(Vector3.new(mx, 0, mz) / speed, false)
	end
end

-- Anything else carrying them outward (a knock, a jump's run-up), each physics step.
local function capVelocity()
	local root, _, zone, depth = current()
	local text = debugLabel()
	if root == nil or zone == nil then
		if text then
			text.Text = "current: out of the edge zone"
		end
		return
	end
	local cap = VoidMist.outwardCap(depth)
	local v = root.AssemblyLinearVelocity
	local vx, vz = VoidMist.clampOutward(v.X, v.Z, zone, cap)
	if vx ~= v.X or vz ~= v.Z then
		root.AssemblyLinearVelocity = Vector3.new(vx, v.Y, vz)
	end
	if text then
		text.Text = string.format("depth %.2f  cap %.1f  out %.1f", depth, cap, v.X * zone.ox + v.Z * zone.oz)
	end
end

function VoidCurrentController.Init() end

function VoidCurrentController.Start()
	local function add(instance: Instance)
		if instance:IsA("BasePart") then
			rails[instance] = true
		end
	end
	for _, instance in CollectionService:GetTagged(TutorialConfig.EdgeTag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TutorialConfig.EdgeTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TutorialConfig.EdgeTag):Connect(function(instance)
		rails[instance :: BasePart] = nil
	end)
	-- after the PlayerModule's controls (RenderPriority.Input) have set this frame's move
	RunService:BindToRenderStep("VoidCurrent", Enum.RenderPriority.Input.Value + 1, function()
		Safe.call("VoidCurrentController.move", capMove)
	end)
	RunService.PreSimulation:Connect(function()
		Safe.call("VoidCurrentController.velocity", capVelocity)
	end)
end

return VoidCurrentController
