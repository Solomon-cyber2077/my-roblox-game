--!strict
--[[
	Client-side station effects:
	  * collapse telegraphs: a slab with a CollapseAt time cracks, glows ember red,
	    sheds dust and rumbles until it falls (pillar 3: no hit without a tell)
	  * the fog wall: a moving front evaluated locally from the replicated hazard
	    parameters, so it needs no network traffic
	  * searched containers darken so the crew can read the station at a glance
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

type Telegraph = {
	part: BasePart,
	at: number,
	base: Color3,
	cracks: { BasePart },
	dust: ParticleEmitter,
	rumbled: boolean,
}

local StationVisualsController = {}

local ROOT_OFFSET = CFrame.new(0, -2, 6)
local EMBER = Color3.fromRGB(255, 96, 40)

local telegraphs: { [BasePart]: Telegraph } = {}
local effects: Folder
local fogFront: Part
local fogVolume: Part
local station: Model? = nil

local function decor(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function clearTelegraph(part: BasePart)
	local entry = telegraphs[part]
	if entry then
		for _, crack in entry.cracks do
			crack:Destroy()
		end
		entry.dust:Destroy()
		if part.Parent then
			part.Color = entry.base
		end
		telegraphs[part] = nil
	end
end

local function startTelegraph(part: BasePart)
	if telegraphs[part] then
		return
	end
	local at = part:GetAttribute("CollapseAt")
	if type(at) ~= "number" then
		return
	end
	local cracks: { BasePart } = {}
	local rng = Random.new(math.floor(part.Position.X * 13 + part.Position.Z * 7))
	for _ = 1, 3 do
		local crack = Instance.new("Part")
		crack.Size = Vector3.new(rng:NextNumber(4, part.Size.X * 0.9), 0.06, 0.25)
		crack.CFrame = part.CFrame
			* CFrame.new(rng:NextNumber(-2, 2), part.Size.Y / 2 + 0.03, rng:NextNumber(-3, 3))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		crack.Color = EMBER
		crack.Material = Enum.Material.Neon
		decor(crack)
		crack.Parent = effects
		table.insert(cracks, crack)
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(120, 100, 84))
	dust.Rate = 26
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(60, 60)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.4) })
	dust.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Parent = part
	telegraphs[part] =
		{ part = part, at = at, base = part.Color, cracks = cracks, dust = dust, rumbled = false }
end

local function watchStation(model: Model)
	station = model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "Top" and descendant:GetAttribute("SlabId") then
			descendant:GetAttributeChangedSignal("CollapseAt"):Connect(function()
				startTelegraph(descendant)
			end)
			descendant:GetAttributeChangedSignal("Collapsed"):Connect(function()
				local entry = telegraphs[descendant]
				if entry and Registry.AudioController then
					Registry.AudioController.Play("Collapse", descendant.Position)
				end
				clearTelegraph(descendant)
			end)
		elseif descendant:IsA("Model") and descendant:GetAttribute("ContainerKind") then
			local container = descendant
			container:GetAttributeChangedSignal("Searched"):Connect(function()
				for _, part in container:GetDescendants() do
					if part:IsA("BasePart") then
						part.Color = part.Color:Lerp(Color3.new(0, 0, 0), 0.45)
					end
				end
			end)
		end
	end
end

local function onChild(child: Instance)
	if child:IsA("Model") and string.sub(child.Name, 1, 8) == "Station_" then
		-- Wait for the assembly to stream in before scanning it.
		task.delay(0.5, function()
			if child.Parent then
				watchStation(child)
			end
		end)
	end
end

function StationVisualsController.Init()
	effects = Instance.new("Folder")
	effects.Name = "StationEffects"
	effects.Parent = Workspace

	fogFront = Instance.new("Part")
	fogFront.Name = "FogFront"
	fogFront.Transparency = 1
	fogFront.Size = Vector3.new(400, 60, 4)
	decor(fogFront)
	fogFront.Parent = effects
	local wall = Instance.new("ParticleEmitter")
	wall.Texture = "rbxasset://textures/particles/smoke_main.dds"
	wall.Color = ColorSequence.new(Color3.fromRGB(150, 138, 126), Color3.fromRGB(96, 88, 82))
	wall.Rate = 160
	wall.Lifetime = NumberRange.new(4, 6)
	wall.Speed = NumberRange.new(2, 5)
	wall.EmissionDirection = Enum.NormalId.Front
	wall.SpreadAngle = Vector2.new(30, 10)
	wall.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 22) })
	wall.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	wall.RotSpeed = NumberRange.new(-12, 12)
	wall.Shape = Enum.ParticleEmitterShape.Box
	wall.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	wall.Enabled = false
	wall.Parent = fogFront

	-- Behind the front: slow, heavy puffs spread through the whole fogged volume.
	fogVolume = Instance.new("Part")
	fogVolume.Name = "FogVolume"
	fogVolume.Transparency = 1
	decor(fogVolume)
	fogVolume.Parent = effects
	local bank = Instance.new("ParticleEmitter")
	bank.Name = "Bank"
	bank.Texture = "rbxasset://textures/particles/smoke_main.dds"
	bank.Color = ColorSequence.new(Color3.fromRGB(132, 122, 112), Color3.fromRGB(88, 82, 78))
	bank.Rate = 0
	bank.Lifetime = NumberRange.new(6, 9)
	bank.Speed = NumberRange.new(0.5, 2)
	bank.SpreadAngle = Vector2.new(180, 30)
	bank.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 30) })
	bank.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	bank.RotSpeed = NumberRange.new(-8, 8)
	bank.Shape = Enum.ParticleEmitterShape.Box
	bank.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	bank.Parent = fogVolume
end

function StationVisualsController.Start()
	Workspace.ChildAdded:Connect(onChild)
	for _, child in Workspace:GetChildren() do
		onChild(child)
	end

	RunService.RenderStepped:Connect(function()
		local now = Session.now()
		-- telegraph pulses
		for part, entry in telegraphs do
			if part.Parent == nil then
				clearTelegraph(part)
			else
				local remaining = entry.at - now
				local urgency = 1 - math.clamp(remaining / 2.2, 0, 1)
				local wave = 0.5 + 0.5 * math.sin(now * (8 + urgency * 14))
				part.Color = entry.base:Lerp(EMBER, 0.25 + 0.45 * wave * urgency)
				if not entry.rumbled and Registry.AudioController then
					entry.rumbled = true
					Registry.AudioController.Play("Rumble", part.Position)
				end
			end
		end

		-- fog front
		local phase = Session.phase()
		local info = Registry.StateController.Get({ "run", "station" })
		local root = station and station.Parent and station.PrimaryPart
		local emitter = fogFront:FindFirstChildOfClass("ParticleEmitter") :: ParticleEmitter
		local bank = fogVolume:FindFirstChild("Bank") :: ParticleEmitter
		if
			info
			and root
			and not info.terminus
			and (phase == "Dwell" or phase == "LastCall" or phase == "Departure")
		then
			local run = Registry.StateController.Get({ "run" }) or {}
			local t = (if phase == "Departure" then run.phaseStartedAt or now else now) - info.startedAt
			local geo = { depth = info.depth, safe = Tuning.World.SafeStrip }
			local z = HazardSchedule.fogFront(info.hazards, geo, t)
			local frame = root.CFrame * ROOT_OFFSET:Inverse()
			local width = info.length + 60
			fogFront.Size = Vector3.new(width, 60, 4)
			fogFront.CFrame = frame * CFrame.new(0, 24, z) * CFrame.Angles(0, math.pi, 0)
			emitter.Enabled = z < info.depth + 4
			local volumeDepth = math.max(info.depth - z + 40, 1)
			fogVolume.Size = Vector3.new(width, 40, volumeDepth)
			fogVolume.CFrame = frame * CFrame.new(0, 14, z + volumeDepth / 2 + 2)
			bank.Rate = if z < info.depth then math.clamp(width * volumeDepth / 450, 12, 140) else 0
		else
			emitter.Enabled = false
			bank.Rate = 0
		end
	end)
end

-- Station-local depth of the fog front right now, or nil when there is none.
function StationVisualsController.FogDepth(): number?
	local info = Registry.StateController.Get({ "run", "station" })
	local phase = Session.phase()
	if
		info == nil
		or info.terminus
		or not (phase == "Dwell" or phase == "LastCall" or phase == "Departure")
	then
		return nil
	end
	return HazardSchedule.fogFront(
		info.hazards,
		{ depth = info.depth, safe = Tuning.World.SafeStrip },
		Session.now() - info.startedAt
	)
end

-- Station-local position of a world point, when a station is present.
function StationVisualsController.ToLocal(position: Vector3): Vector3?
	local root = station and station.Parent and station.PrimaryPart
	if root == nil then
		return nil
	end
	return (root.CFrame * ROOT_OFFSET:Inverse()):PointToObjectSpace(position)
end

return StationVisualsController
