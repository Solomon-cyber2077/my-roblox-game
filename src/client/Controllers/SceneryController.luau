--!strict
--[[
	The world rushing past the static train, built and moved entirely on the
	client so it costs no network traffic.

	Logic/JourneyPlan decides what the world is (biomes, set pieces, the
	sinkhole of every station) and is unit-tested by playing whole runs; this
	controller only feeds it the replicated run state each frame and builds
	what it describes:

	  * chunks (Scenery/Land layers, Scenery/Features set pieces and
	    sinkholes), each welded to one anchored root, scrolled with a single
	    BulkMoveTo of the roots to x = landX - odometer
	  * a few chunks a frame, nearest first, and many while the screen is
	    faded or the train stands still
	  * Scenery/Life: crows over the fields, moved with the same odometer

	The odometer follows JourneyPlan.speed (the station's own velocity while
	one moves) plus JourneyPlan.correction, which keeps a present station
	exactly on its dock.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local JourneyPlan = require(Shared.Logic.JourneyPlan)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)
local Signal = require(Shared.Util.Signal)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Chunk = require(script.Parent.Parent.Scenery.Chunk)
local Features = require(script.Parent.Parent.Scenery.Features)
local Land = require(script.Parent.Parent.Scenery.Land)
local Life = require(script.Parent.Parent.Scenery.Life)
local World = require(script.Parent.Parent.Scenery.World)

export type Context = {
	tunnel: number, -- 0..1, how far the camera is inside a tunnel bore
	bridge: number, -- 0..1, the camera is over a gorge
	biomeA: string,
	biomeB: string,
	blend: number, -- weight of biomeB
	progress: number, -- run progress in legs (Logic/Journey)
	skyProgress: number, -- run progress as the sky and the clock count it (Journey.skyProgress)
}

type Wanted = { key: string, priority: number, build: () -> Chunk.Chunk }

local SceneryController = {
	-- Fires a couple of seconds before the locomotive enters a tunnel.
	TunnelAhead = Signal.new() :: Signal.Signal<>,
}

local FEATURE_FRONT = 2600
local FAR_FRONT = 4400
local FEATURE_BACK = -800
local LOCO_FRONT = 96
local WHISTLE_LEAD = 230

local folder: Folder
local plan = JourneyPlan.new()
local odometer = 0
local speed = 0
local apparentSpeed = 0
local stationModel: Model? = nil

local chunks: { [string]: Chunk.Chunk } = {}
local dirty: { [string]: boolean } = {}
local fastUntil = 0
local whistled: { [string]: boolean } = {}

local context: Context = {
	tunnel = 0,
	bridge = 0,
	biomeA = Journey.FirstBiome,
	biomeB = Journey.FirstBiome,
	blend = 0,
	progress = 0,
	skyProgress = 0,
}

local function qualityDensity(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if not ok or type(level) ~= "number" or level == 0 then
		return 0.85 -- Automatic
	end
	return math.clamp(0.45 + level * 0.055, 0.5, 1)
end

-- Chunk bookkeeping ---------------------------------------------------------------------------

-- Rebuilds every built chunk overlapping land [x0, x1] that starts at least `minAhead` ahead of the train.
local function invalidate(x0: number, x1: number, minAhead: number?)
	for key, chunk in chunks do
		if chunk.x0 < x1 and chunk.x1 > x0 and (minAhead == nil or chunk.x0 - odometer > minAhead) then
			dirty[key] = true
		end
	end
end

local function invalidateAll()
	for key in chunks do
		dirty[key] = true
	end
	table.clear(whistled)
	fastUntil = os.clock() + 1.5
end

local function pieceKey(piece: Journey.Piece): string
	return `P{piece.leg}:{piece.index}`
end

local function sinkholeKey(sinkhole: Journey.Sinkhole): string
	return `S{math.floor(sinkhole.center)}`
end

local function layerBuilder(layer: Land.Layer, k: number): () -> Chunk.Chunk
	return function()
		local x0 = k * layer.length
		local model, root = Chunk.begin(layer.name)
		Land.build(layer, k, model, x0)
		return Chunk.finish(
			`{layer.name}{k}`,
			layer.name,
			x0,
			x0 + layer.length,
			model,
			root,
			folder,
			layer.hideable
		)
	end
end

local function pieceBuilder(piece: Journey.Piece): () -> Chunk.Chunk
	return function()
		local model, root = Chunk.begin(piece.kind)
		Features.build(piece, model)
		return Chunk.finish(
			pieceKey(piece),
			"Feature",
			piece.at,
			piece.at + piece.length,
			model,
			root,
			folder,
			false
		)
	end
end

local function sinkholeBuilder(sinkhole: Journey.Sinkhole): () -> Chunk.Chunk
	return function()
		local model, root = Chunk.begin("Sinkhole")
		Features.buildSinkhole(sinkhole, model)
		return Chunk.finish(
			sinkholeKey(sinkhole),
			"Feature",
			sinkhole.rect.x0,
			sinkhole.rect.x1,
			model,
			root,
			folder,
			false
		)
	end
end

local wanted: { Wanted } = {}
local needed: { [string]: boolean } = {}

-- Marks a chunk as needed this frame; true when it still has to be built (or rebuilt).
local function wants(key: string): boolean
	needed[key] = true
	return chunks[key] == nil or dirty[key] == true
end

local function queue(key: string, worldX: number, build: () -> Chunk.Chunk)
	table.insert(wanted, { key = key, priority = math.abs(worldX), build = build })
end

local function manageChunks()
	table.clear(wanted)
	table.clear(needed)
	for _, layer in Land.Layers do
		local first = math.floor((odometer + layer.from) / layer.length)
		local last = math.floor((odometer + layer.to) / layer.length)
		for k = first, last do
			local key = `{layer.name}{k}`
			if wants(key) then
				queue(key, (k + 0.5) * layer.length - odometer, layerBuilder(layer, k))
			end
		end
	end
	for _, piece in World.pieces do
		local front = if Features.farReach(piece.kind) then FAR_FRONT else FEATURE_FRONT
		local x0, x1 = piece.at - odometer, piece.at + piece.length - odometer
		if x1 > FEATURE_BACK and x0 < front then
			local key = pieceKey(piece)
			if wants(key) then
				queue(key, math.max(x0, 0), pieceBuilder(piece))
			end
		end
	end
	for _, sinkhole in World.sinkholes do
		local x0, x1 = sinkhole.rect.x0 - odometer, sinkhole.rect.x1 - odometer
		if x1 > FEATURE_BACK and x0 < FAR_FRONT then
			local key = sinkholeKey(sinkhole)
			if wants(key) then
				queue(key, math.max(x0, 0), sinkholeBuilder(sinkhole))
			end
		end
	end

	for key, chunk in chunks do
		if not needed[key] then
			Chunk.destroy(chunk)
			chunks[key] = nil
			dirty[key] = nil
		end
	end

	table.sort(wanted, function(a, b)
		return a.priority < b.priority
	end)
	-- builds are time-sliced so a busy frame never hitches: a generous slice while the
	-- screen is still loading or the train stands, a thin one at speed (at least one chunk)
	local slice = if os.clock() < fastUntil then 0.05 elseif speed < 1 then 0.012 else 0.004
	local deadline = os.clock() + slice
	for i = 1, #wanted do
		if i > 1 and os.clock() > deadline then
			break
		end
		local entry = wanted[i]
		local ok, built = pcall(entry.build)
		local old = chunks[entry.key]
		if old then
			Chunk.destroy(old)
		end
		dirty[entry.key] = nil
		if ok then
			chunks[entry.key] = built
		else
			chunks[entry.key] = nil
			warn(`[Scenery] {entry.key}: {built}`)
		end
	end
end

-- The plan and the odometer -----------------------------------------------------------------------

local function findStation()
	for _, child in Workspace:GetChildren() do
		if child:IsA("Model") and string.sub(child.Name, 1, 8) == "Station_" then
			stationModel = child
			return
		end
	end
	stationModel = nil
end

local function advance(dt: number)
	local run = Registry.StateController.Get({ "run" })
	local phase = Session.phase()
	local now = Session.now()
	local root = stationModel and stationModel.PrimaryPart
	local stationX = if root then root.Position.X else nil
	local stationVelocity = if root then root.AssemblyLinearVelocity.X else nil
	local elapsed = if type(run) == "table" and run.phaseStartedAt then now - run.phaseStartedAt else 0

	speed = JourneyPlan.speed(speed, phase, dt, stationVelocity, elapsed)
	local before = odometer
	odometer += speed * dt
	local result = JourneyPlan.step(plan, {
		phase = phase,
		active = Session.isRunActive(),
		run = if type(run) == "table" then run else nil,
		odometer = odometer,
		speed = speed,
		now = now,
		stationX = stationX,
	})
	odometer += JourneyPlan.correction(plan, phase, odometer, stationX, dt)
	apparentSpeed = if dt > 0 then math.max((odometer - before) / dt, 0) else speed

	World.seed = plan.seed
	World.base = plan.base
	World.transitions = plan.transitions
	World.pieces = plan.pieces
	World.sinkholes = plan.sinkholes
	if result.rebuild then
		invalidateAll()
	end
	for _, change in result.changes do
		invalidate(change.x0, change.x1, change.minAhead)
	end
end

-- Context and cues ----------------------------------------------------------------------------------

local function updateContext()
	local camera = Workspace.CurrentCamera
	local position = camera.CFrame.Position
	local x = odometer + position.X
	local nearTrack = math.abs(position.Z) < 40 and position.Y < 40
	local tunnel, bridge = 0, 0
	local locoFront = odometer + LOCO_FRONT
	for _, piece in World.pieces do
		if piece.kind == "Tunnel" then
			local entry, exit = Journey.tunnelPortals(piece)
			if nearTrack then
				local inside = MathX.smoothstep(entry - 10, entry + 30, x)
					* (1 - MathX.smoothstep(exit - 30, exit + 10, x))
				tunnel = math.max(tunnel, inside)
			end
			local key = pieceKey(piece)
			if
				not whistled[key]
				and locoFront > entry - WHISTLE_LEAD
				and locoFront < entry
				and speed > 20
			then
				whistled[key] = true
				SceneryController.TunnelAhead:Fire()
			end
		elseif piece.kind == "Gorge" and nearTrack then
			local over = MathX.smoothstep(piece.at - 20, piece.at + 10, x)
				* (1 - MathX.smoothstep(piece.at + piece.length - 10, piece.at + piece.length + 20, x))
			bridge = math.max(bridge, over)
		end
	end
	local a, b, w = Journey.sample(World.base, World.transitions, x)
	context.tunnel = tunnel
	context.bridge = bridge
	context.biomeA = a
	context.biomeB = b
	context.blend = w
	context.progress = plan.progress
	context.skyProgress = plan.skyProgress
end

local function animate(now: number)
	for _, chunk in chunks do
		for _, motor in chunk.rotors do
			motor.Transform = CFrame.Angles(now * 0.9, 0, 0)
		end
		for i, light in chunk.flickers do
			local base = light:GetAttribute("Flicker")
			if type(base) == "number" then
				light.Brightness = base * (0.72 + 0.4 * math.noise(now * 7, i * 1.7, chunk.x0 * 0.01))
			end
		end
	end
end

-- Lifecycle -------------------------------------------------------------------------------------------

function SceneryController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Scenery"
	folder.Parent = Workspace
	World.density = qualityDensity()
	fastUntil = os.clock() + 3
	Life.init(folder)
end

function SceneryController.Start()
	Workspace.ChildAdded:Connect(findStation)
	Workspace.ChildRemoved:Connect(findStation)
	findStation()

	local roots: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		Safe.call("Scenery.advance", advance, dt)
		Safe.call("Scenery.chunks", manageChunks)

		-- a docked station brings its own track bed: drop ours out of sight under it
		local stationMin, stationMax = math.huge, -math.huge
		local root = stationModel and stationModel.PrimaryPart
		if root then
			local station = Registry.StateController.Get({ "run", "station" })
			local length = if station then station.length else 400
			stationMin, stationMax = root.Position.X - length / 2, root.Position.X + length / 2
		end

		table.clear(roots)
		table.clear(frames)
		for _, chunk in chunks do
			local x0 = chunk.x0 - odometer
			local hide = chunk.hideable and x0 + (chunk.x1 - chunk.x0) > stationMin and x0 < stationMax
			table.insert(roots, chunk.root)
			table.insert(frames, CFrame.new(x0, if hide then -4000 else 0, 0))
		end
		Workspace:BulkMoveTo(roots, frames, Enum.BulkMoveMode.FireCFrameChanged)

		Safe.call("Scenery.context", updateContext)
		Safe.call("Scenery.life", Life.update, odometer, dt, os.clock())
		animate(os.clock())
	end)
end

-- Current scroll speed in studs per second (the train's apparent speed).
function SceneryController.Speed(): number
	return apparentSpeed
end

-- Studs travelled since the client started; rail joints fall every 48 of them.
function SceneryController.Odometer(): number
	return odometer
end

function SceneryController.Context(): Context
	return context
end

return SceneryController
