--!strict
--[[
	Client-side station effects:
	  * collapse telegraphs: a slab with a CollapseAt time cracks, glows ember red,
	    sheds dust and rumbles until it falls (pillar 3: no hit without a tell)
	  * the fog (Scenery/StationFog): a moving front evaluated locally from the
	    replicated hazard parameters, so it needs no network traffic, and the things
	    that live in it
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
local StationFog = require(script.Parent.Parent.Scenery.StationFog)

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
local station: Model? = nil
local whispering = false

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

	StationFog.build(effects)
end

function StationVisualsController.Start()
	Workspace.ChildAdded:Connect(onChild)
	for _, child in Workspace:GetChildren() do
		onChild(child)
	end

	RunService.RenderStepped:Connect(function(dt: number)
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

		-- the fog
		local phase = Session.phase()
		local info = Registry.StateController.Get({ "run", "station" })
		local root = station and station.Parent and station.PrimaryPart
		local open = phase == "Dwell" or phase == "LastCall" or phase == "Departure"
		if info and root and not info.terminus and open then
			local run = Registry.StateController.Get({ "run" }) or {}
			-- the fog stops where the station actually left (the end of the Last Call grace)
			local frozenAt = info.lastCallEndsAt or run.phaseStartedAt or now
			local t = (if phase == "Departure" then math.min(now, frozenAt) else now) - info.startedAt
			local geo = { depth = info.depth, safe = Tuning.World.SafeStrip }
			local frame = root.CFrame * ROOT_OFFSET:Inverse()
			local camera = Workspace.CurrentCamera
			StationFog.update({
				station = frame,
				length = info.length,
				depth = info.depth,
				front = HazardSchedule.fogFront(info.hazards, geo, t),
				waiting = math.clamp(t / math.max(HazardSchedule.fogStartTime(info.hazards), 1), 0, 1),
				camera = frame:PointToObjectSpace(camera.CFrame.Position),
				archetype = info.archetype,
				now = now,
			}, dt)
			local anchor = StationFog.anchor()
			if not whispering and anchor and Registry.AudioController then
				whispering = true
				Registry.AudioController.Loop("fogWhisper", "FogWhisper", anchor)
			end
		else
			StationFog.clear()
			if whispering and Registry.AudioController then
				whispering = false
				Registry.AudioController.StopLoop("fogWhisper")
			end
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
