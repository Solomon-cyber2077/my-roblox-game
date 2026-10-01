--!strict
--[[
	The world rushing past the static train, built and moved entirely on the
	client so it costs no network traffic:
	  * a stone causeway with sleepers and rails under and around the train
	  * floating islands of a broken landscape at a distance on both sides
	  * ash falling from above and embers rising out of the abyss

	Everything scrolls along -X at the current speed with one BulkMoveTo per
	frame. Speed follows the phase; while a station is sliding in or out the
	scenery matches the station's own physics velocity so the two never drift.
	Causeway segments that overlap a present station drop out of sight.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Motion = require(Shared.Logic.Motion)
local MathX = require(Shared.Util.MathX)
local Kit = require(Shared.Visual.Kit)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)

type Scroller = {
	parts: { BasePart },
	offsets: { CFrame },
	x: number,
	span: number,
	minX: number,
	isDeck: boolean,
	halfLength: number,
}

local SceneryController = {}

local SEGMENT = 48
local DECK_SEGMENTS = 26
local DECK_MIN = -SEGMENT * DECK_SEGMENTS / 2
local ISLANDS = 34
local ISLAND_SPAN = 3600

local folder: Folder
local scrollers: { Scroller } = {}
local speed = 0
local stationModel: Model? = nil

local STONE = Color3.fromRGB(86, 78, 70)
local ROCK = Color3.fromRGB(54, 48, 44)

local function decor(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

local function buildSegment(index: number): Scroller
	local model = Kit.model("Causeway", folder)
	local origin = CFrame.new()
	local parts: { BasePart } = {}
	local function add(part: BasePart)
		decor(part)
		table.insert(parts, part)
	end
	add(
		Kit.block(
			model,
			Vector3.new(SEGMENT, 3, 20),
			origin * CFrame.new(0, -8.0, 0),
			STONE,
			{ material = Enum.Material.Cobblestone }
		)
	)
	add(
		Kit.block(
			model,
			Vector3.new(SEGMENT, 0.6, 14),
			origin * CFrame.new(0, -6.55, 0),
			Color3.fromRGB(70, 66, 62),
			{ material = Enum.Material.Pebble }
		)
	)
	for i = 0, 11 do
		add(
			Kit.block(
				model,
				Vector3.new(1.3, 0.5, 9),
				origin * CFrame.new(-SEGMENT / 2 + 2 + i * 4, -6.0, 0),
				Color3.fromRGB(74, 56, 40),
				{ material = Enum.Material.Wood, shadow = false }
			)
		)
	end
	for _, side in { -1, 1 } do
		add(
			Kit.block(
				model,
				Vector3.new(SEGMENT, 0.55, 0.5),
				origin * CFrame.new(0, -5.475, side * 2.6),
				Color3.fromRGB(120, 116, 112),
				{ material = Enum.Material.Metal, shadow = false }
			)
		)
		add(
			Kit.block(
				model,
				Vector3.new(SEGMENT, 2.4, 1.2),
				origin * CFrame.new(0, -5.3, side * 9.6),
				STONE,
				{ material = Enum.Material.Brick }
			)
		)
	end
	if index % 2 == 0 then
		add(
			Kit.block(
				model,
				Vector3.new(10, 150, 14),
				origin * CFrame.new(0, -84, 0),
				ROCK,
				{ material = Enum.Material.Brick, shadow = false }
			)
		)
		add(
			Kit.block(
				model,
				Vector3.new(14, 6, 18),
				origin * CFrame.new(0, -11.5, 0),
				STONE,
				{ material = Enum.Material.Brick, shadow = false }
			)
		)
	end
	if index % 3 == 0 then
		local side = if index % 2 == 0 then 1 else -1
		add(
			Kit.post(
				model,
				8,
				0.35,
				origin * CFrame.new(0, -0.1, side * 9.6),
				Color3.fromRGB(44, 44, 48),
				{ material = Enum.Material.Metal }
			)
		)
		add(
			Kit.neon(
				model,
				Vector3.new(0.7, 0.9, 0.7),
				origin * CFrame.new(0, 4.2, side * 9.6),
				Color3.fromRGB(255, 196, 128)
			)
		)
	end
	local offsets: { CFrame } = {}
	for _, part in parts do
		table.insert(offsets, part.CFrame)
	end
	return {
		parts = parts,
		offsets = offsets,
		x = DECK_MIN + (index - 0.5) * SEGMENT,
		span = SEGMENT * DECK_SEGMENTS,
		minX = DECK_MIN,
		isDeck = true,
		halfLength = SEGMENT / 2,
	}
end

local function buildIsland(index: number, rng: Random): Scroller
	local model = Kit.model("Island", folder)
	local side = if index % 2 == 0 then 1 else -1
	local z = side * rng:NextNumber(170, 900)
	local y = rng:NextNumber(-90, 25)
	local size = rng:NextNumber(30, 150) * (0.6 + math.abs(z) / 1200)
	local parts: { BasePart } = {}
	local function add(part: BasePart)
		decor(part)
		part.CastShadow = false
		table.insert(parts, part)
	end
	-- top crust and a tapering rock body underneath
	add(
		Kit.block(
			model,
			Vector3.new(size, size * 0.18, size * 0.8),
			CFrame.new(0, y, z) * Kit.angles(0, rng:NextNumber(0, 40), 0),
			Color3.fromRGB(74, 66, 56),
			{ material = Enum.Material.Ground }
		)
	)
	for layer = 1, 3 do
		local s = size * (1 - layer * 0.24)
		add(
			Kit.block(
				model,
				Vector3.new(s, size * 0.22, s * 0.75),
				CFrame.new(rng:NextNumber(-4, 4), y - layer * size * 0.17, z)
					* Kit.angles(rng:NextNumber(-8, 8), rng:NextNumber(0, 90), rng:NextNumber(-8, 8)),
				Kit.shade(ROCK, 0.85 + layer * 0.05),
				{ material = Enum.Material.Rock }
			)
		)
	end
	local feature = rng:NextNumber()
	if feature < 0.35 then
		-- ruined colonnade
		for i = -1, 1 do
			local h = rng:NextNumber(size * 0.15, size * 0.4)
			add(
				Kit.block(
					model,
					Vector3.new(size * 0.06, h, size * 0.06),
					CFrame.new(i * size * 0.18, y + h / 2, z),
					Color3.fromRGB(150, 140, 126),
					{ material = Enum.Material.Limestone }
				)
			)
		end
	elseif feature < 0.7 then
		-- dead tree
		local h = size * 0.35
		add(
			Kit.block(
				model,
				Vector3.new(size * 0.04, h, size * 0.04),
				CFrame.new(0, y + h / 2, z) * Kit.angles(0, 0, rng:NextNumber(-10, 10)),
				Color3.fromRGB(46, 38, 32),
				{ material = Enum.Material.Wood }
			)
		)
		add(
			Kit.block(
				model,
				Vector3.new(size * 0.025, h * 0.5, size * 0.025),
				CFrame.new(size * 0.05, y + h * 0.75, z) * Kit.angles(0, 0, -40),
				Color3.fromRGB(46, 38, 32),
				{ material = Enum.Material.Wood }
			)
		)
	elseif feature < 0.85 then
		-- broken signal gantry
		add(
			Kit.block(
				model,
				Vector3.new(size * 0.04, size * 0.5, size * 0.04),
				CFrame.new(-size * 0.15, y + size * 0.25, z),
				Color3.fromRGB(40, 40, 44),
				{ material = Enum.Material.Metal }
			)
		)
		add(
			Kit.block(
				model,
				Vector3.new(size * 0.4, size * 0.03, size * 0.03),
				CFrame.new(0, y + size * 0.48, z) * Kit.angles(0, 0, 12),
				Color3.fromRGB(40, 40, 44),
				{ material = Enum.Material.Metal }
			)
		)
	end
	local offsets: { CFrame } = {}
	for _, part in parts do
		table.insert(offsets, part.CFrame)
	end
	return {
		parts = parts,
		offsets = offsets,
		x = -ISLAND_SPAN / 2 + (index - 0.5) * ISLAND_SPAN / ISLANDS + rng:NextNumber(-40, 40),
		span = ISLAND_SPAN,
		minX = -ISLAND_SPAN / 2,
		isDeck = false,
		halfLength = size / 2,
	}
end

local function emitterPart(name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	decor(part)
	part.Parent = folder
	return part
end

local function buildAtmospherics()
	local ash = Instance.new("ParticleEmitter")
	ash.Texture = "rbxasset://textures/particles/smoke_main.dds"
	ash.Color = ColorSequence.new(Color3.fromRGB(140, 130, 124))
	ash.Rate = 60
	ash.Lifetime = NumberRange.new(6, 9)
	ash.Speed = NumberRange.new(4, 8)
	ash.EmissionDirection = Enum.NormalId.Bottom
	ash.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.15) })
	ash.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	ash.Drag = 0.4
	ash.Parent = emitterPart("Ash", Vector3.new(700, 1, 260), CFrame.new(0, 70, 30))

	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/fire_sparks_main.dds"
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 140, 70), Color3.fromRGB(180, 50, 20))
	embers.LightEmission = 1
	embers.Rate = 45
	embers.Lifetime = NumberRange.new(5, 8)
	embers.Speed = NumberRange.new(8, 18)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	embers.Parent = emitterPart("Embers", Vector3.new(900, 1, 600), CFrame.new(0, -140, 0))
	SceneryController.SetWind(0)
end

local windTargets: { ParticleEmitter } = {}

function SceneryController.SetWind(strength: number)
	if #windTargets == 0 then
		for _, descendant in folder:GetDescendants() do
			if descendant:IsA("ParticleEmitter") then
				table.insert(windTargets, descendant)
			end
		end
	end
	for _, emitter in windTargets do
		emitter.Acceleration = Vector3.new(-strength, 0, 0)
	end
end

local function findStation()
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 8) == "Station_" then
			stationModel = child
			return
		end
	end
	stationModel = nil
end

local function targetSpeed(dt: number): number
	local phase = Session.phase()
	local run = Registry.StateController.Get({ "run" }) or {}
	local station = stationModel
	local root = station and station.PrimaryPart
	if (phase == "Arrival" or phase == "Departure") and root then
		return math.max(-root.AssemblyLinearVelocity.X, 0)
	end
	if phase == "Arrival" then
		return -Motion.arrivalVelocity(Session.now() - (run.phaseStartedAt or Session.now()))
	end
	if phase == "Junction" or phase == "Cruise" or phase == "Boarding" then
		local train = Registry.StateController.Get({ "train" })
		local cruise = Tuning.Motion.CruiseSpeed * (if train and train.starving then 0.65 else 1)
		return MathX.approach(speed, cruise, 9 * dt)
	end
	if phase == "Departure" then
		return MathX.approach(speed, Tuning.Motion.CruiseSpeed, 6 * dt)
	end
	if phase == "RunEnd" then
		return MathX.approach(speed, 0, 12 * dt)
	end
	return 0
end

function SceneryController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = Workspace
	for i = 1, DECK_SEGMENTS do
		table.insert(scrollers, buildSegment(i))
	end
	local rng = Random.new(1931)
	for i = 1, ISLANDS do
		table.insert(scrollers, buildIsland(i, rng))
	end
	buildAtmospherics()
end

function SceneryController.Start()
	Workspace.ChildAdded:Connect(findStation)
	Workspace.ChildRemoved:Connect(findStation)
	findStation()

	local allParts: { BasePart } = {}
	local allFrames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		speed = targetSpeed(dt)
		local dx = -speed * dt

		local stationMin, stationMax = math.huge, -math.huge
		local root = stationModel and stationModel.PrimaryPart
		if root and stationModel then
			local length = 400
			local plan = Registry.StateController.Get({ "run", "station" })
			if plan then
				length = plan.length
			end
			stationMin, stationMax = root.Position.X - length / 2, root.Position.X + length / 2
		end

		table.clear(allParts)
		table.clear(allFrames)
		for _, scroller in scrollers do
			scroller.x += dx
			if scroller.x < scroller.minX then
				scroller.x += scroller.span
			end
			local hide = scroller.isDeck
				and scroller.x + scroller.halfLength > stationMin
				and scroller.x - scroller.halfLength < stationMax
			local frame = CFrame.new(scroller.x, if hide then -4000 else 0, 0)
			for i, part in scroller.parts do
				table.insert(allParts, part)
				table.insert(allFrames, frame * scroller.offsets[i])
			end
		end
		Workspace:BulkMoveTo(allParts, allFrames, Enum.BulkMoveMode.FireCFrameChanged)
		SceneryController.SetWind(math.min(speed * 0.12, 14))
	end)
end

-- Current scroll speed in studs per second (the train's apparent speed).
function SceneryController.Speed(): number
	return speed
end

return SceneryController
