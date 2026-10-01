--!strict
--[[
	The world rushing past the static train, built and moved entirely on the
	client so it costs no network traffic.

	The landscape is planned in land coordinates (Logic/Journey) and built in
	chunks (Scenery/Land layers, Scenery/Features set pieces and sinkholes).
	Each chunk is welded to one anchored root, so a single BulkMoveTo of the
	roots scrolls everything to x = landX - odometer every frame.

	Run flow:
	  * a new run resets the plan (seed, first biome, leg 1) and rebuilds the
	    whole window under the boarding fade
	  * Departure starts the next leg: its set pieces are planned from the seed
	  * in Cruise the dock is predicted from the clock; the station's sinkhole is
	    cut there, the leg's pieces are trimmed clear of it and the destination
	    biome blends in from 35% of the leg
	  * at Arrival the prediction is checked against the real station and the
	    sinkhole re-cut if it is more than DockTolerance out (dev skips, late joins)

	Speed follows the phase; while a station slides in or out the scenery
	matches the station's own physics velocity so the two never drift.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Journey = require(Shared.Logic.Journey)
local MathX = require(Shared.Util.MathX)
local Motion = require(Shared.Logic.Motion)
local Safe = require(Shared.Util.Safe)
local Signal = require(Shared.Util.Signal)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Chunk = require(script.Parent.Parent.Scenery.Chunk)
local Features = require(script.Parent.Parent.Scenery.Features)
local Land = require(script.Parent.Parent.Scenery.Land)
local World = require(script.Parent.Parent.Scenery.World)

export type Context = {
	tunnel: number, -- 0..1, how far the camera is inside a tunnel bore
	bridge: number, -- 0..1, the camera is over a gorge
	biomeA: string,
	biomeB: string,
	blend: number, -- weight of biomeB
	progress: number, -- run progress in legs (Logic/Journey)
}

type Wanted = { key: string, priority: number, build: () -> Chunk.Chunk }

local SceneryController = {
	-- Fires a couple of seconds before the locomotive enters a tunnel.
	TunnelAhead = Signal.new() :: Signal.Signal<>,
}

local J = Tuning.Journey
local NEAR_FRONT = 2200
local FEATURE_FRONT = 2600
local FAR_FRONT = 4400
local FEATURE_BACK = -800
local PRUNE_BEHIND = 3000
local LOCO_FRONT = 96
local WHISTLE_LEAD = 230

local folder: Folder
local odometer = 0
local speed = 0
local stationModel: Model? = nil

local chunks: { [string]: Chunk.Chunk } = {}
local dirty: { [string]: boolean } = {}
local fastUntil = 0

local runKey: string? = nil
local legIndex = 0
local legStart = 0
local upcoming: Journey.Sinkhole? = nil
local transitionLeg = 0
local arrivalChecked = false
local lastPhase = ""
local progress = 0
local whistled: { [string]: boolean } = {}

local context: Context = {
	tunnel = 0,
	bridge = 0,
	biomeA = Journey.FirstBiome,
	biomeB = Journey.FirstBiome,
	blend = 0,
	progress = 0,
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
	local budget = if os.clock() < fastUntil then 60 elseif speed < 1 then 12 else 3
	for i = 1, math.min(budget, #wanted) do
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

-- The plan ---------------------------------------------------------------------------------------

local function beginLeg(leg: number, stops: number)
	legIndex = leg
	legStart = odometer
	upcoming = nil
	for _, piece in Journey.legPlan(World.seed, leg, odometer, leg > stops) do
		table.insert(World.pieces, piece)
	end
	-- forget what is far behind
	local keep: { Journey.Piece } = {}
	for _, piece in World.pieces do
		if piece.at + piece.length > odometer - PRUNE_BEHIND then
			table.insert(keep, piece)
		end
	end
	World.pieces = keep
	local sinkholes: { Journey.Sinkhole } = {}
	for _, sinkhole in World.sinkholes do
		if sinkhole.rect.x1 > odometer - PRUNE_BEHIND then
			table.insert(sinkholes, sinkhole)
		end
	end
	World.sinkholes = sinkholes
end

-- Cuts (or re-cuts) the sinkhole for the station the train is heading to.
local function setUpcoming(center: number, archetype: string)
	local arch = Stations.List[archetype]
	if arch == nil then
		return
	end
	local old = upcoming
	local sinkhole = Journey.sinkhole(center, arch.length, arch.depth, arch.id, arch.terminus == true)
	if old then
		local index = table.find(World.sinkholes, old)
		if index then
			table.remove(World.sinkholes, index)
		end
		invalidate(old.rect.x0 - 20, old.rect.x1 + 20)
	end
	table.insert(World.sinkholes, sinkhole)
	upcoming = sinkhole
	invalidate(sinkhole.rect.x0 - 20, sinkhole.rect.x1 + 20)

	-- this leg's pieces must end clear of the dock
	local legPieces: { Journey.Piece } = {}
	local others: { Journey.Piece } = {}
	for _, piece in World.pieces do
		table.insert(if piece.leg == legIndex then legPieces else others, piece)
	end
	local kept = Journey.trim(legPieces, sinkhole)
	local keptSet: { [Journey.Piece]: boolean } = {}
	for _, piece in kept do
		keptSet[piece] = true
		table.insert(others, piece)
	end
	for _, piece in legPieces do
		if not keptSet[piece] then
			local footprint = Journey.footprint(piece)
			invalidate(footprint.x0, footprint.x1)
		end
	end
	World.pieces = others

	-- the destination's biome takes over from 35% of the leg
	if transitionLeg ~= legIndex then
		transitionLeg = legIndex
		local at = Journey.blendStart(legStart, center, odometer + NEAR_FRONT + 100)
		World.addTransition({ at = at, length = J.BlendLength, biome = Journey.biomeFor(archetype) })
		invalidate(at, odometer + 10000, NEAR_FRONT)
	end
end

local function startRun(run: { [string]: any }, phase: string)
	runKey = run.runId
	local destination = run.destination
	local base = if phase == "Boarding" or destination == nil
		then Journey.FirstBiome
		else Journey.biomeFor(destination.archetype)
	World.reset(tonumber(run.seed) or 1931, base)
	transitionLeg = 0
	table.clear(whistled)
	local stops = run.stopCount or Tuning.Run.StationCount
	local leg = math.max(run.nextStop or 1, 1) + (if phase == "Departure" then 1 else 0)
	beginLeg(leg, stops)
	invalidateAll()
end

local function updatePlan()
	local run = Registry.StateController.Get({ "run" })
	local phase = Session.phase()
	if type(run) ~= "table" then
		return
	end
	if Session.isRunActive() and run.runId and run.runId ~= runKey then
		startRun(run, phase)
	end
	if runKey == nil then
		return
	end
	local stops = run.stopCount or Tuning.Run.StationCount
	if phase ~= lastPhase then
		if phase == "Departure" and lastPhase ~= "" then
			beginLeg((run.nextStop or legIndex) + 1, stops)
		end
		arrivalChecked = false
		lastPhase = phase
	end

	local destination = run.destination
	if phase == "Cruise" and destination and run.phaseEndsAt then
		local predicted = Journey.dockFromCruise(odometer, run.phaseEndsAt - Session.now())
		if
			upcoming == nil
			or math.abs(predicted - (upcoming :: Journey.Sinkhole).center) > J.DockTolerance
		then
			setUpcoming(predicted, destination.archetype)
		end
	end
	local root = stationModel and stationModel.PrimaryPart
	local station = run.station
	if
		root
		and station
		and (phase == "Arrival" or phase == "Dwell" or phase == "LastCall" or phase == "Terminus")
	then
		if not arrivalChecked then
			arrivalChecked = true
			local actual = odometer + root.Position.X
			if
				upcoming == nil
				or math.abs(actual - (upcoming :: Journey.Sinkhole).center) > J.DockTolerance
			then
				setUpcoming(actual, station.archetype)
			end
		end
	end

	if Session.isRunActive() then
		local dock = if upcoming then upcoming.center else nil
		progress = Journey.progress(legIndex, Journey.legShare(odometer, legStart, dock))
	elseif phase == "Lobby" then
		progress = 0
	end
end

-- Motion ------------------------------------------------------------------------------------------

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
	local root = stationModel and stationModel.PrimaryPart
	if (phase == "Arrival" or phase == "Departure") and root then
		return math.max(-root.AssemblyLinearVelocity.X, 0)
	end
	-- the station we just left keeps pulling away for a while: stay locked to it so it
	-- never slides out of its sinkhole, then carry on toward cruise once it is gone
	if phase == "Junction" and root and root.AssemblyLinearVelocity.X < -1 then
		return -root.AssemblyLinearVelocity.X
	end
	if phase == "Arrival" then
		return -Motion.arrivalVelocity(Session.now() - (run.phaseStartedAt or Session.now()))
	end
	if phase == "Junction" or phase == "Cruise" or phase == "Boarding" then
		return MathX.approach(speed, Tuning.Motion.CruiseSpeed, 9 * dt)
	end
	if phase == "Departure" then
		return MathX.approach(speed, Tuning.Motion.CruiseSpeed, 6 * dt)
	end
	if phase == "RunEnd" then
		return MathX.approach(speed, 0, 12 * dt)
	end
	return 0
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
				tunnel = math.max(
					tunnel,
					MathX.smoothstep(entry - 10, entry + 30, x)
						* (1 - MathX.smoothstep(exit - 30, exit + 10, x))
				)
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
			bridge = math.max(
				bridge,
				MathX.smoothstep(piece.at - 20, piece.at + 10, x)
					* (1 - MathX.smoothstep(piece.at + piece.length - 10, piece.at + piece.length + 20, x))
			)
		end
	end
	local a, b, w = Journey.sample(World.base, World.transitions, x)
	context.tunnel = tunnel
	context.bridge = bridge
	context.biomeA = a
	context.biomeB = b
	context.blend = w
	context.progress = progress
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
end

function SceneryController.Start()
	Workspace.ChildAdded:Connect(findStation)
	Workspace.ChildRemoved:Connect(findStation)
	findStation()

	local roots: { BasePart } = {}
	local frames: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		speed = targetSpeed(dt)
		odometer += speed * dt
		Safe.call("Scenery.plan", updatePlan)
		Safe.call("Scenery.chunks", manageChunks)

		-- a docked station brings its own track bed: drop ours out of sight under it
		local stationMin, stationMax = math.huge, -math.huge
		local root = stationModel and stationModel.PrimaryPart
		if root then
			local plan = Registry.StateController.Get({ "run", "station" })
			local length = if plan then plan.length else 400
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
		animate(os.clock())
	end)
end

-- Current scroll speed in studs per second (the train's apparent speed).
function SceneryController.Speed(): number
	return speed
end

-- Studs travelled since the client started; rail joints fall every 48 of them.
function SceneryController.Odometer(): number
	return odometer
end

function SceneryController.Context(): Context
	return context
end

return SceneryController
