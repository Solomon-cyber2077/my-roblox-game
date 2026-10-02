--!strict
--[[
	Turns a LayoutGen plan into a station: a floating island of slabs with its
	buildings, containers, pickups and props, plus the track bed under the train.

	Assembly rules (they are what makes collapse and motion work):
	  * Root is the only anchored part; the station moves and docks through it.
	  * Every slab top is welded to Root; everything standing on a slab is welded
	    to that slab, so breaking one slab's weld drops it with its contents.
	  * Station-local axes: +X along the track, +Z away from the train, y = 0 is
	    the platform surface, z = 0 is the platform edge.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemModel = require(Shared.Visual.ItemModel)
local Kit = require(Shared.Visual.Kit)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Loot = require(Shared.Config.Loot)
local Stations = require(Shared.Config.Stations)

local StructureKit = require(script.Parent.StructureKit)

type Plan = LayoutGen.Plan

export type ContainerHandle = { def: LayoutGen.Container, promptPart: BasePart, model: Model }
export type LooseHandle = { item: string, model: Model, slab: number }

export type Built = {
	model: Model,
	root: BasePart,
	slabParts: { [number]: BasePart },
	containers: { [number]: ContainerHandle },
	loose: { [number]: LooseHandle },
}

local StationBuilder = {}

local ROCK = Color3.fromRGB(58, 50, 44)
local COPING = Color3.fromRGB(196, 188, 172)
local TACTILE = Color3.fromRGB(226, 182, 58)
local SLEEPER = Color3.fromRGB(74, 56, 40)
local RAIL = Color3.fromRGB(120, 116, 112)
local BALLAST = Color3.fromRGB(70, 66, 62)

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.Concrete
end

local function addSparkle(part: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 2.5
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.LightEmission = 1
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 226, 170))
	emitter.Parent = part
end

-- Builds the station at `docked` (its resting frame beside the train). Not parented.
function StationBuilder.build(plan: Plan, docked: CFrame, stationName: string): Built
	local arch = Stations.List[plan.archetype]
	local palette = {
		ground = Kit.rgb(arch.palette.ground),
		accent = Kit.rgb(arch.palette.accent),
		trim = Kit.rgb(arch.palette.trim),
		light = Kit.rgb(arch.palette.light),
	}
	local groundMaterial = material(arch.ground)
	local rng = Random.new(plan.seed % 2147483647)

	local model = Kit.model(`Station_{plan.archetype}`)
	local function L(x: number, y: number, z: number): CFrame
		return docked * CFrame.new(x, y, z)
	end

	local root = Kit.block(
		model,
		Vector3.new(4, 1, 4),
		L(0, -2, 6),
		Color3.new(),
		{ transparency = 1, collide = false, shadow = false }
	)
	root.Name = "Root"
	model.PrimaryPart = root

	-- Track bed under the train (station-local z < 0) ------------------------------------
	local trackZ = -7
	local track = Kit.model("Track", model)
	Kit.block(
		track,
		Vector3.new(plan.length, 1, 15),
		L(0, -6.75, trackZ),
		BALLAST,
		{ material = Enum.Material.Pebble }
	)
	Kit.block(
		track,
		Vector3.new(plan.length, 8, 15),
		L(0, -11.25, trackZ),
		ROCK,
		{ material = Enum.Material.Rock }
	)
	for x = -plan.length / 2 + 1.5, plan.length / 2 - 1.5, 3 do
		Kit.block(
			track,
			Vector3.new(1.3, 0.5, 9),
			L(x, -6.0, trackZ),
			SLEEPER,
			{ material = Enum.Material.Wood, collide = false }
		)
	end
	for _, side in { -1, 1 } do
		Kit.block(
			track,
			Vector3.new(plan.length, 0.55, 0.5),
			L(0, -5.475, trackZ + side * 2.6),
			RAIL,
			{ material = Enum.Material.Metal, collide = false }
		)
	end
	for _, part in track:GetChildren() do
		if part:IsA("BasePart") then
			Kit.weld(part, root)
		end
	end

	-- Slabs ---------------------------------------------------------------------------------
	local slabParts: { [number]: BasePart } = {}
	for _, slab in plan.slabs do
		local slabModel = Kit.model(`Slab_{slab.id}`, model)
		local top: BasePart
		if slab.kind == "Safe" then
			top = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX, 2, slab.sizeZ),
				L(slab.x, -1, slab.z),
				Kit.shade(palette.ground, 1.18),
				{ material = Enum.Material.Concrete }
			)
			local coping = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX, 0.3, 1.55),
				L(slab.x, 0.15, 0.625),
				COPING,
				{ material = Enum.Material.Concrete }
			)
			local tactile = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX, 0.06, 0.7),
				L(slab.x, 0.03, 2.4),
				TACTILE,
				{ collide = false }
			)
			local face = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX + 0.1, 6, 0.6),
				L(slab.x, -3, 0.25),
				Kit.shade(palette.trim, 1.1),
				{ material = Enum.Material.Brick }
			)
			local under = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX, 12, slab.sizeZ - 0.6),
				L(slab.x, -8, slab.z + 0.3),
				ROCK,
				{ material = Enum.Material.Rock }
			)
			for _, part in { coping, tactile, face, under } do
				Kit.weld(part, top)
			end
		else
			local foundation = slab.kind == "Foundation"
			local color = if foundation
				then Kit.shade(palette.ground, 0.82)
				else Kit.jitter(palette.ground, 0.07, rng:NextNumber())
			top = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX - 0.12, 2, slab.sizeZ - 0.12),
				L(slab.x, -1, slab.z),
				color,
				{
					material = if foundation then Enum.Material.Concrete else groundMaterial,
				}
			)
			local depth = 4 + rng:NextNumber() * 10 + (slab.z / plan.depth) * 6
			local under = Kit.block(
				slabModel,
				Vector3.new(slab.sizeX - 0.8, depth, slab.sizeZ - 0.8),
				L(slab.x, -2 - depth / 2, slab.z) * Kit.angles(0, rng:NextNumber() * 6 - 3, 0),
				Kit.jitter(ROCK, 0.12, rng:NextNumber()),
				{ material = Enum.Material.Rock }
			)
			Kit.weld(under, top)
			if plan.archetype == "Viaduct" and slab.gz == plan.rows - 1 then
				local parapet = Kit.block(
					slabModel,
					Vector3.new(slab.sizeX - 0.2, 1.2, 1),
					L(slab.x, 0.6, slab.z + slab.sizeZ / 2 - 0.5),
					palette.trim,
					{ material = Enum.Material.Brick }
				)
				Kit.weld(parapet, top)
			end
		end
		top.Name = "Top"
		top:SetAttribute("SlabId", slab.id)
		top:SetAttribute("SlabKind", slab.kind)
		slabModel.PrimaryPart = top
		Kit.weld(top, root)
		slabParts[slab.id] = top
	end

	local function attachTo(container: Instance, slabId: number)
		local base = slabParts[slabId]
		for _, part in container:GetDescendants() do
			if
				part:IsA("BasePart")
				and part ~= base
				and part:FindFirstChildOfClass("WeldConstraint") == nil
			then
				Kit.weld(part, base)
			end
		end
	end

	-- Structures --------------------------------------------------------------------------------
	for _, structure in plan.structures do
		local piece = Kit.model(structure.kind, model)
		local width = (if structure.rot == 90 then structure.d else structure.w) * plan.tile
		local depth = (if structure.rot == 90 then structure.w else structure.d) * plan.tile
		StructureKit.building(structure.kind, {
			parent = piece,
			base = slabParts[structure.slab],
			frame = L(structure.x, 0, structure.z) * Kit.angles(0, structure.rot, 0),
			width = width,
			depth = depth,
			palette = palette,
			rng = Random.new(plan.seed % 1000003 + structure.id * 7919),
		})
		attachTo(piece, structure.slab)
	end

	-- Containers ---------------------------------------------------------------------------------
	local containers: { [number]: ContainerHandle } = {}
	for _, def in plan.containers do
		local piece = Kit.model(`Container_{def.id}`, model)
		local promptPart = StructureKit.container(def.kind, {
			parent = piece,
			base = slabParts[def.slab],
			frame = L(def.x, 0, def.z) * Kit.angles(0, def.rot, 0),
			width = 4,
			depth = 4,
			palette = palette,
			rng = Random.new(def.id * 104729 + plan.seed % 99991),
		})
		promptPart.Name = "PromptPart"
		piece.PrimaryPart = promptPart
		piece:SetAttribute("ContainerKind", def.kind)
		piece:SetAttribute("ContainerName", Loot.Containers[def.kind].name)
		piece:SetAttribute("Zone", def.zone)
		attachTo(piece, def.slab)
		containers[def.id] = { def = def, promptPart = promptPart, model = piece }
	end

	-- Loose pickups -----------------------------------------------------------------------------
	local loose: { [number]: LooseHandle } = {}
	for _, item in plan.loose do
		local piece = ItemModel.build(
			item.item,
			L(item.x, 0.75, item.z) * Kit.angles(0, rng:NextNumber() * 360, 0),
			1.25
		)
		piece.Name = `Loose_{item.id}`
		piece.Parent = model
		local body = piece.PrimaryPart :: BasePart
		addSparkle(body)
		attachTo(piece, item.slab)
		loose[item.id] = { item = item.item, model = piece, slab = item.slab }
	end

	-- Props -----------------------------------------------------------------------------------
	for _, prop in plan.props do
		local piece = Kit.model(prop.kind, model)
		StructureKit.prop(prop.kind, {
			parent = piece,
			base = slabParts[prop.slab],
			frame = L(prop.x, 0, prop.z) * Kit.angles(0, prop.rot, 0),
			width = 4,
			depth = 4,
			palette = palette,
			rng = Random.new(math.floor(prop.x * 31 + prop.z * 17) + plan.seed % 7907),
			label = stationName,
		})
		attachTo(piece, prop.slab)
	end

	-- Everything except Root moves with physics; Root holds the assembly when anchored.
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Station"
			part.Anchored = part == root
		end
	end
	root.Anchored = true

	return {
		model = model,
		root = root,
		slabParts = slabParts,
		containers = containers,
		loose = loose,
	}
end

-- Builds a loose pickup welded to `base` at a world position (for drops and overflow).
function StationBuilder.pickup(itemId: string, model: Instance, base: BasePart, position: Vector3): Model
	local piece = ItemModel.build(itemId, CFrame.new(position) * Kit.angles(0, math.random() * 360, 0), 1.25)
	piece.Name = `Drop_{itemId}`
	addSparkle(piece.PrimaryPart :: BasePart)
	for _, part in piece:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Station"
			Kit.weld(part, base)
			part.Anchored = false
		end
	end
	piece.Parent = model
	return piece
end

return StationBuilder
