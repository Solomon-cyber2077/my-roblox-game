--!strict
--[[
	The moving world. A station is one welded assembly riding a PrismaticConstraint
	along the track. It is driven only while arriving or departing, and anchored
	while docked, so clients get smooth interpolated physics in motion and a
	perfectly still platform during the stop.

	Velocity command each Heartbeat:  v = v_profile(t) + Kp * (x_profile(t) - x_actual)
	with the profiles from Logic/Motion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Motion = require(Shared.Logic.Motion)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local StationBuilder = require(script.Parent.Parent.Builders.StationBuilder)

type Mode = "Arriving" | "Docked" | "Departing"

type Active = {
	built: StationBuilder.Built,
	plan: LayoutGen.Plan,
	info: Types.StationInfo,
	prismatic: PrismaticConstraint,
	rig: Folder,
	mode: Mode,
	modeStartedAt: number,
	accel: number,
	collapsed: { [number]: boolean },
	connection: RBXScriptConnection?,
}

local StationService = {
	Spawned = Signal.new() :: Signal.Signal<StationBuilder.Built, LayoutGen.Plan>,
	SlabCollapsed = Signal.new() :: Signal.Signal<number>,
	Cleared = Signal.new() :: Signal.Signal<>,
}

local DOCKED = CFrame.new(0, Tuning.World.FloorY, Tuning.World.PlatformEdgeZ)
local ROOT_OFFSET = CFrame.new(0, -2, 6) -- where StationBuilder puts Root, in station space
local DOCKED_ROOT = DOCKED * ROOT_OFFSET
local GAIN = 4

local active: Active? = nil

local function now(): number
	return Workspace:GetServerTimeNow()
end

--[[
	Anchoring keeps whatever velocity the assembly had when it was moving, and an
	anchored part with a velocity is a conveyor belt: everyone standing on the
	platform would slide along with it for the whole stop (badly so when a dev skip
	docks the station mid-brake). Stop the motor, anchor, then zero the motion.
]]
local function anchorAt(station: Active, cframe: CFrame)
	local root = station.built.root
	station.prismatic.ActuatorType = Enum.ActuatorType.None
	station.prismatic.Velocity = 0
	root.Anchored = true
	root.CFrame = cframe
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function release(station: Active)
	local root = station.built.root
	station.prismatic.ActuatorType = Enum.ActuatorType.Motor
	station.prismatic.Velocity = 0
	root.Anchored = false
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
end

local function step()
	local station = active
	if station == nil then
		return
	end
	local t = now() - station.modeStartedAt
	local current = station.prismatic.CurrentPosition
	if station.mode == "Arriving" then
		if t >= Tuning.Run.ArrivalSeconds then
			anchorAt(station, DOCKED_ROOT)
			station.mode = "Docked"
		else
			local target = Motion.arrivalOffset(t)
			station.prismatic.Velocity = Motion.arrivalVelocity(t) + GAIN * (target - current)
		end
	elseif station.mode == "Departing" then
		local target = Motion.departureOffset(t, station.accel)
		station.prismatic.Velocity = Motion.departureVelocity(t, station.accel) + GAIN * (target - current)
	end
end

function StationService.Init() end

function StationService.Start()
	RunService.Heartbeat:Connect(step)
end

-- Builds the station ahead of the train and starts braking it into the platform.
function StationService.Spawn(plan: LayoutGen.Plan, info: Types.StationInfo)
	StationService.Clear()
	local built = StationBuilder.build(plan, DOCKED, info.name)
	local offset = Motion.arrivalDistance()
	built.model:PivotTo(CFrame.new(offset, 0, 0) * built.model:GetPivot())

	local rig = Instance.new("Folder")
	rig.Name = "StationRig"
	local anchor = Instance.new("Part")
	anchor.Name = "RailAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Anchored = true
	anchor.CFrame = DOCKED_ROOT
	anchor.Parent = rig
	local a0 = Instance.new("Attachment")
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Parent = built.root

	local prismatic = Instance.new("PrismaticConstraint")
	prismatic.Attachment0 = a0
	prismatic.Attachment1 = a1
	prismatic.ActuatorType = Enum.ActuatorType.Motor
	prismatic.MotorMaxForce = math.huge
	prismatic.MotorMaxAcceleration = math.huge
	prismatic.Velocity = 0
	prismatic.LimitsEnabled = false
	prismatic.Visible = false
	prismatic.Parent = built.root

	rig.Parent = Workspace
	built.model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	built.model.Parent = Workspace

	local station: Active = {
		built = built,
		plan = plan,
		info = info,
		prismatic = prismatic,
		rig = rig,
		mode = "Arriving",
		modeStartedAt = now(),
		accel = 0,
		collapsed = {},
		connection = nil,
	}
	active = station
	release(station)
	StationService.Spawned:Fire(built, plan)
end

function StationService.Dock()
	local station = active
	if station and station.mode ~= "Docked" then
		anchorAt(station, DOCKED_ROOT)
		station.mode = "Docked"
	end
end

function StationService.BeginDeparture(accel: number)
	local station = active
	if station == nil then
		return
	end
	station.accel = accel
	station.mode = "Departing"
	station.modeStartedAt = now()
	release(station)
end

-- Lets the departing station slide on, then removes it.
function StationService.ReleaseAfter(seconds: number)
	local station = active
	task.delay(seconds, function()
		if active == station then
			StationService.Clear()
		end
	end)
end

function StationService.Clear()
	local station = active
	if station == nil then
		return
	end
	active = nil
	station.built.model:Destroy()
	station.rig:Destroy()
	StationService.Cleared:Fire()
end

function StationService.IsActive(): boolean
	return active ~= nil
end

function StationService.Built(): StationBuilder.Built?
	return if active then active.built else nil
end

function StationService.Plan(): LayoutGen.Plan?
	return if active then active.plan else nil
end

function StationService.Info(): Types.StationInfo?
	return if active then active.info else nil
end

function StationService.SetInfo(info: Types.StationInfo)
	if active then
		active.info = info
	end
end

-- The station's own frame (x along the track, z away from the train), wherever it is now.
function StationService.Frame(): CFrame
	if active then
		return active.built.root.CFrame * ROOT_OFFSET:Inverse()
	end
	return DOCKED
end

function StationService.ToLocal(position: Vector3): Vector3
	return StationService.Frame():PointToObjectSpace(position)
end

function StationService.ToWorld(x: number, y: number, z: number): Vector3
	return StationService.Frame() * Vector3.new(x, y, z)
end

function StationService.IsCollapsed(slabId: number): boolean
	return active ~= nil and active.collapsed[slabId] == true
end

function StationService.TelegraphSlab(slabId: number, at: number)
	local station = active
	if station == nil then
		return
	end
	local part = station.built.slabParts[slabId]
	if part then
		part:SetAttribute("CollapseAt", at)
	end
end

function StationService.CollapseSlab(slabId: number)
	local station = active
	if station == nil or station.collapsed[slabId] then
		return
	end
	local part: BasePart? = station.built.slabParts[slabId]
	if part == nil then
		return
	end
	station.collapsed[slabId] = true
	part:SetAttribute("Collapsed", true)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then
			if child.Part0 == station.built.root then
				child:Destroy()
			end
		end
	end
	local slabModel = part.Parent
	if slabModel then
		for _, descendant in slabModel:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CollisionGroup = "Debris"
			end
		end
	end
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	part.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.6
	StationService.SlabCollapsed:Fire(slabId)
	task.delay(7, function()
		if slabModel and slabModel.Parent then
			slabModel:Destroy()
		end
	end)
end

-- Where a rescued or late-joining crew member appears: standing ground at 60-80%
-- of the depth that is still clear of fog at this moment.
function StationService.StragglerSpawn(): CFrame
	local station = active
	if station == nil then
		return CFrame.new(0, 3, Tuning.World.PlatformEdgeZ + 10)
	end
	local plan = station.plan
	local safe = Tuning.World.SafeStrip
	local t = now() - station.info.startedAt
	local fog = HazardSchedule.fogFront(station.info.hazards, { depth = plan.depth, safe = safe }, t)
	local clear = math.min(fog, plan.depth) - safe
	local lo = safe + clear * Tuning.Crew.StragglerDepthMin
	local hi = safe + clear * Tuning.Crew.StragglerDepthMax
	local candidates: { LayoutGen.Slab } = {}
	for _, slab in plan.slabs do
		if slab.kind == "Floor" and not station.collapsed[slab.id] and slab.z >= lo and slab.z <= hi then
			table.insert(candidates, slab)
		end
	end
	if #candidates == 0 then
		local x = (math.random() - 0.5) * (plan.length - 24)
		return CFrame.new(StationService.ToWorld(x, 3, safe - 6))
	end
	local slab = candidates[math.random(1, #candidates)]
	local position = StationService.ToWorld(slab.x, 3, slab.z)
	return CFrame.lookAt(position, Vector3.new(position.X, position.Y, 0))
end

return StationService
