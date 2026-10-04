--!strict
--[[
	Procedural station layouts. Pure: the same archetype, seed and loot multiplier
	always produce the same plan, on the server, the client and in tests.

	The station is a grid of 12-stud tiles. x runs along the track (0 is the
	station centre), z runs away from the platform edge (0 is the edge).

	Collapse works on slabs: the safe strip is one slab that never falls, each
	building stands on one foundation slab that falls as a unit, and every other
	tile is its own slab. Props, containers and pickups are attached to the slab
	under them, so they fall with it.
]]

local Shared = script.Parent.Parent
local Buildings = require(Shared.Config.Buildings)
local Loot = require(Shared.Config.Loot)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)
local BuildingGen = require(script.Parent.BuildingGen)

export type Slab = {
	id: number,
	gx: number,
	gz: number,
	w: number,
	d: number,
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	kind: "Safe" | "Floor" | "Foundation",
	zone: string,
	structure: number?,
	building: number?,
}

-- An enterable building: its foundation slab and its own plan (Logic/BuildingGen), whose
-- building-local coordinates sit at station-local (x, z).
export type Building = {
	id: number,
	kind: string,
	slab: number,
	gx: number,
	gz: number,
	w: number,
	d: number,
	x: number,
	z: number,
	zone: string,
	plan: BuildingGen.Plan,
}

export type Sleeper = { x: number, y: number, z: number, rot: number, kind: string, building: number }

export type Structure = {
	id: number,
	kind: string,
	slab: number,
	gx: number,
	gz: number,
	w: number,
	d: number,
	x: number,
	z: number,
	rot: number,
}

export type Container = {
	id: number,
	kind: string, -- the loot table (Config/Loot)
	look: string?, -- the furniture it is, inside a building (Config/Buildings)
	building: number?,
	zone: string,
	slab: number,
	x: number,
	z: number,
	rot: number,
}
export type Loose = { id: number, item: string, slab: number, x: number, z: number }
-- size: a prop that spans a length (a fence along its tile, the platform canopy) is told how long.
export type Prop = { kind: string, slab: number, x: number, z: number, rot: number, size: number? }

export type Plan = {
	archetype: string,
	seed: number,
	length: number,
	depth: number,
	tile: number,
	cols: number,
	rows: number,
	safeRows: number,
	slabs: { Slab },
	structures: { Structure },
	buildings: { Building },
	containers: { Container },
	loose: { Loose },
	props: { Prop },
	sleepers: { Sleeper },
	spawnLanes: { number },
}

local CONTAINER_ORDER = { "Crate", "Locker", "CoalBin", "ToolChest", "Vault" }
local LANDMARK = 1000 -- occupancy ids at and above this are enterable buildings
local COAL_NEIGHBOURS = { CoalHeap = true, Hopper = true, CoalTower = true }
local TOOL_NEIGHBOURS = { Workshop = true, Shed = true, SignalBox = true, Headframe = true }
local NO_ROTATE = { TunnelMouth = true, Concourse = true }
local DIRECTIONS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }

local LayoutGen = {}

function LayoutGen.zoneFor(z: number, depth: number, safe: number): string
	if z < safe then
		return "Safe"
	elseif z < 0.4 * depth then
		return "Near"
	elseif z < 0.75 * depth then
		return "Mid"
	end
	return "Far"
end

function LayoutGen.generate(archetypeId: string, seed: number, lootMul: number): Plan
	local arch = Stations.List[archetypeId]
	assert(arch, `unknown archetype {archetypeId}`)

	local tile = Tuning.World.TileSize
	local safe = Tuning.World.SafeStrip
	local cols = arch.length // tile
	local rows = arch.depth // tile
	local safeRows = math.ceil(safe / tile)
	local rng = Rng.new(Rng.derive(seed, "layout", archetypeId))

	local function tileX(gx: number): number
		return -arch.length / 2 + (gx + 0.5) * tile
	end
	local function tileZ(gz: number): number
		return (gz + 0.5) * tile
	end
	local function zoneOf(gz: number): string
		return LayoutGen.zoneFor(tileZ(gz), arch.depth, safe)
	end
	local function index(gx: number, gz: number): number
		return gz * cols + gx + 1
	end

	-- 0 = walkable, otherwise the id of the structure standing there.
	local occupancy: { number } = table.create(cols * rows, 0)
	local structureKind: { [number]: string } = {}

	local function canPlace(gx: number, gz: number, w: number, d: number): boolean
		if gx < 0 or gz < safeRows or gx + w > cols or gz + d > rows then
			return false
		end
		-- One tile of margin keeps a walkable lane around every building.
		for x = gx - 1, gx + w do
			for z = gz - 1, gz + d do
				if x >= 0 and x < cols and z >= 0 and z < rows and occupancy[index(x, z)] ~= 0 then
					return false
				end
			end
		end
		return true
	end

	local function fill(gx: number, gz: number, w: number, d: number, value: number)
		for x = gx, gx + w - 1 do
			for z = gz, gz + d - 1 do
				occupancy[index(x, z)] = value
			end
		end
	end

	-- Every walkable tile must be reachable from the platform.
	local function connected(): boolean
		local walkable = 0
		for i = 1, cols * rows do
			if occupancy[i] == 0 then
				walkable += 1
			end
		end
		local seen: { [number]: boolean } = {}
		local queue: { { number } } = {}
		for gx = 0, cols - 1 do
			local i = index(gx, 0)
			if occupancy[i] == 0 then
				seen[i] = true
				table.insert(queue, { gx, 0 })
			end
		end
		local head = 1
		while head <= #queue do
			local cell = queue[head]
			head += 1
			for _, dir in DIRECTIONS do
				local nx, nz = cell[1] + dir[1], cell[2] + dir[2]
				if nx >= 0 and nx < cols and nz >= 0 and nz < rows then
					local i = index(nx, nz)
					if occupancy[i] == 0 and not seen[i] then
						seen[i] = true
						table.insert(queue, { nx, nz })
					end
				end
			end
		end
		return #queue == walkable
	end

	-- Enterable buildings first: they are the biggest, and the stop is built around them --
	local buildings: { Building } = {}
	local landmarks: { Stations.LandmarkRule } = arch.landmarks or {}
	for _, rule in landmarks do
		local def = Buildings.Defs[rule.kind]
		local w, d = def.size[1], def.size[2]
		for _attempt = 1, 80 do
			local zone = rng:pick(rule.zones)
			local zoneRows: { number } = {}
			for gz = safeRows, rows - d do
				if zoneOf(gz + d // 2) == zone then
					table.insert(zoneRows, gz)
				end
			end
			if #zoneRows > 0 then
				local gz = rng:pick(zoneRows)
				local gx = rng:int(0, cols - w)
				if canPlace(gx, gz, w, d) then
					local id = #buildings + 1
					fill(gx, gz, w, d, LANDMARK + id)
					if connected() then
						table.insert(buildings, {
							id = id,
							kind = rule.kind,
							slab = 0,
							gx = gx,
							gz = gz,
							w = w,
							d = d,
							x = tileX(gx) + (w - 1) * tile / 2,
							z = tileZ(gz) + (d - 1) * tile / 2,
							zone = zoneOf(gz + d // 2),
							plan = BuildingGen.generate(rule.kind, Rng.derive(seed, "landmark", id)),
						})
						break
					end
					fill(gx, gz, w, d, 0)
				end
			end
		end
	end

	-- Structures -------------------------------------------------------------------
	local structures: { Structure } = {}
	for _, rule in arch.structures do
		local footprint = Stations.Footprints[rule.kind]
		for _ = 1, rule.count do
			for _attempt = 1, 60 do
				local w, d = footprint[1], footprint[2]
				local rot = 0
				if w ~= d and not NO_ROTATE[rule.kind] and rng:chance(0.5) then
					w, d = d, w
					rot = 90
				end
				local zone = rng:pick(rule.zones)
				local zoneRows: { number } = {}
				for gz = safeRows, rows - d do
					if zoneOf(gz) == zone then
						table.insert(zoneRows, gz)
					end
				end
				if #zoneRows > 0 then
					local gz = if rule.kind == "TunnelMouth" then rows - d else rng:pick(zoneRows)
					local gx = rng:int(0, cols - w)
					if canPlace(gx, gz, w, d) then
						local id = #structures + 1
						fill(gx, gz, w, d, id)
						if connected() then
							structureKind[id] = rule.kind
							table.insert(structures, {
								id = id,
								kind = rule.kind,
								slab = 0,
								gx = gx,
								gz = gz,
								w = w,
								d = d,
								x = tileX(gx) + (w - 1) * tile / 2,
								z = tileZ(gz) + (d - 1) * tile / 2,
								rot = rot,
							})
							break
						end
						fill(gx, gz, w, d, 0)
					end
				end
			end
		end
	end

	-- Slabs -------------------------------------------------------------------------
	local slabs: { Slab } = {}
	local slabOfTile: { number } = table.create(cols * rows, 0)

	local safeSlab: Slab = {
		id = 1,
		gx = 0,
		gz = 0,
		w = cols,
		d = safeRows,
		x = 0,
		z = safeRows * tile / 2,
		sizeX = cols * tile,
		sizeZ = safeRows * tile,
		kind = "Safe",
		zone = "Safe",
		structure = nil,
	}
	table.insert(slabs, safeSlab)
	for gz = 0, safeRows - 1 do
		for gx = 0, cols - 1 do
			slabOfTile[index(gx, gz)] = 1
		end
	end

	for _, structure in structures do
		local id = #slabs + 1
		structure.slab = id
		table.insert(slabs, {
			id = id,
			gx = structure.gx,
			gz = structure.gz,
			w = structure.w,
			d = structure.d,
			x = structure.x,
			z = structure.z,
			sizeX = structure.w * tile,
			sizeZ = structure.d * tile,
			kind = "Foundation",
			zone = zoneOf(structure.gz + structure.d // 2),
			structure = structure.id,
		})
		for x = structure.gx, structure.gx + structure.w - 1 do
			for z = structure.gz, structure.gz + structure.d - 1 do
				slabOfTile[index(x, z)] = id
			end
		end
	end

	for _, building in buildings do
		local id = #slabs + 1
		building.slab = id
		table.insert(slabs, {
			id = id,
			gx = building.gx,
			gz = building.gz,
			w = building.w,
			d = building.d,
			x = building.x,
			z = building.z,
			sizeX = building.w * tile,
			sizeZ = building.d * tile,
			kind = "Foundation",
			zone = building.zone,
			structure = nil,
			building = building.id,
		})
		for x = building.gx, building.gx + building.w - 1 do
			for z = building.gz, building.gz + building.d - 1 do
				slabOfTile[index(x, z)] = id
			end
		end
	end

	for gz = safeRows, rows - 1 do
		for gx = 0, cols - 1 do
			local i = index(gx, gz)
			if slabOfTile[i] == 0 then
				local id = #slabs + 1
				slabOfTile[i] = id
				table.insert(slabs, {
					id = id,
					gx = gx,
					gz = gz,
					w = 1,
					d = 1,
					x = tileX(gx),
					z = tileZ(gz),
					sizeX = tile,
					sizeZ = tile,
					kind = "Floor",
					zone = zoneOf(gz),
					structure = nil,
				})
			end
		end
	end

	-- Containers ----------------------------------------------------------------------
	local claimed: { [number]: boolean } = {}

	local function freeTiles(zone: string?): { { number } }
		local out: { { number } } = {}
		for gz = safeRows, rows - 1 do
			if zone == nil or zoneOf(gz) == zone then
				for gx = 0, cols - 1 do
					local i = index(gx, gz)
					if occupancy[i] == 0 and not claimed[i] then
						table.insert(out, { gx, gz })
					end
				end
			end
		end
		return out
	end

	local function nextToKind(gx: number, gz: number, kinds: { [string]: boolean }): boolean
		for _, dir in DIRECTIONS do
			local nx, nz = gx + dir[1], gz + dir[2]
			if nx >= 0 and nx < cols and nz >= 0 and nz < rows then
				local id = occupancy[index(nx, nz)]
				if id ~= 0 and kinds[structureKind[id]] then
					return true
				end
			end
		end
		return false
	end

	local containers: { Container } = {}
	for _, kind in CONTAINER_ORDER do
		local base = arch.containers[kind] or 0
		local def = Loot.Containers[kind]
		if base > 0 and def then
			local count = math.max(1, math.floor(base * lootMul + 0.5))
			for _ = 1, count do
				local zone: string
				if def.farOnly then
					zone = "Far"
				else
					zone = rng:weighted({
						{ weight = def.zoneWeights.Near, value = "Near" },
						{ weight = def.zoneWeights.Mid, value = "Mid" },
						{ weight = def.zoneWeights.Far, value = "Far" },
					})
				end
				local candidates = freeTiles(zone)
				if #candidates == 0 and not def.farOnly then
					candidates = freeTiles(nil)
				end
				if #candidates == 0 then
					break
				end
				local weighted = {}
				for _, cell in candidates do
					local favoured = (kind == "CoalBin" and nextToKind(cell[1], cell[2], COAL_NEIGHBOURS))
						or (kind == "ToolChest" and nextToKind(cell[1], cell[2], TOOL_NEIGHBOURS))
					local weight = if favoured then 4 else 1
					table.insert(weighted, { weight = weight, value = cell })
				end
				local cell = rng:weighted(weighted)
				local i = index(cell[1], cell[2])
				claimed[i] = true
				table.insert(containers, {
					id = #containers + 1,
					kind = kind,
					zone = zoneOf(cell[2]),
					slab = slabOfTile[i],
					x = tileX(cell[1]) + rng:range(-2.5, 2.5),
					z = tileZ(cell[2]) + rng:range(-2.5, 2.5),
					rot = rng:int(0, 3) * 90 + rng:range(-8, 8),
				})
			end
		end
	end

	-- What the buildings hold: their furniture you can search, and what sleeps inside --
	local sleepers: { Sleeper } = {}
	for _, building in buildings do
		for _, item in building.plan.items do
			if item.container then
				local def = Loot.Containers[item.container]
				table.insert(containers, {
					id = #containers + 1,
					kind = item.container,
					look = item.kind,
					building = building.id,
					zone = if def and def.farOnly then "Far" else building.zone,
					slab = building.slab,
					x = building.x + item.x,
					z = building.z + item.z,
					rot = item.rot,
				})
			end
		end
		for _, spot in building.plan.sleepers do
			table.insert(sleepers, {
				x = building.x + spot.x,
				y = 0,
				z = building.z + spot.z,
				rot = spot.rot,
				kind = spot.kind,
				building = building.id,
			})
		end
	end

	-- Loose pickups -------------------------------------------------------------------
	local loose: { Loose } = {}
	for _ = 1, arch.looseItems do
		local zone = if rng:chance(0.6) then "Near" else "Mid"
		local candidates = freeTiles(zone)
		if #candidates == 0 then
			candidates = freeTiles(nil)
		end
		if #candidates == 0 then
			break
		end
		local cell = rng:pick(candidates)
		local i = index(cell[1], cell[2])
		claimed[i] = true
		table.insert(loose, {
			id = #loose + 1,
			item = rng:weighted({
				{ weight = 3 * arch.loot.coal, value = "CoalLump" },
				{ weight = 2 * arch.loot.parts, value = "Scrap" },
			}),
			slab = slabOfTile[i],
			x = tileX(cell[1]) + rng:range(-3, 3),
			z = tileZ(cell[2]) + rng:range(-3, 3),
		})
	end

	-- The platform ----------------------------------------------------------------------
	--[[
		A canopy on iron columns over its middle (its own lanterns light it), lamp standards
		beyond, benches, the name boards, and the clutter of a country station kept clear of
		all of them. Both ends are railed off.
	]]
	local props: { Prop } = {}
	local half = arch.length / 2
	local taken: { { number } } = {} -- {x0, x1, z0, z1} on the platform
	local function room(x0: number, x1: number, z0: number, z1: number): boolean
		for _, r in taken do
			if x0 < r[2] and r[1] < x1 and z0 < r[4] and r[3] < z1 then
				return false
			end
		end
		return x0 > -half + 3 and x1 < half - 3
	end
	local function onPlatform(kind: string, x: number, z: number, hx: number, hz: number, rot: number?)
		table.insert(props, { kind = kind, slab = 1, x = x, z = z, rot = rot or 0 })
		table.insert(taken, { x - hx, x + hx, z - hz, z + hz })
	end
	local canopy = if arch.terminus then 0 else math.clamp(half - 60, 30, Stations.CanopyHalfSpan)
	if canopy > 0 then
		table.insert(props, { kind = "Canopy", slab = 1, x = 0, z = 0, rot = 0, size = canopy * 2 })
		for _, x in Stations.canopyColumns(canopy) do
			table.insert(
				taken,
				{ x - 1.2, x + 1.2, Stations.CanopyColumnZ - 1.2, Stations.CanopyColumnZ + 1.2 }
			)
		end
	end
	local spacing = arch.lampSpacing
	local lampCount = math.floor(arch.length / spacing)
	for i = 0, lampCount - 1 do
		local x = -half + spacing * (i + 0.5)
		if math.abs(x) > canopy + 2 then
			onPlatform("Lamp", x, safe - 3, 1, 1)
		end
		if i % 2 == 0 and i < lampCount - 1 then
			onPlatform("Bench", x + spacing / 2, 12, 2.8, 1.2)
		end
	end
	onPlatform("Sign", 0, safe - 6, 7.4, 0.6)
	if arch.length >= 280 then
		onPlatform("Sign", -arch.length / 3, safe - 6, 7.4, 0.6)
		onPlatform("Sign", arch.length / 3, safe - 6, 7.4, 0.6)
	end
	-- a luggage trolley, milk churns, the fire buckets and the timetable, wherever they fit
	for _, spot in
		{
			{ kind = "Trolley", x = canopy + 13, z = 15.5, hx = 3.2, hz = 1.8, rot = 8 },
			{ kind = "Churns", x = -(canopy + 10), z = 16.5, hx = 2.4, hz = 1.6, rot = 0 },
			{ kind = "FireBuckets", x = 9.5, z = 21.6, hx = 2.2, hz = 0.8, rot = 0 },
			{ kind = "Timetable", x = -11, z = 21.4, hx = 2.4, hz = 0.8, rot = 0 },
			{ kind = "Planter", x = canopy * 0.55, z = 16.2, hx = 2, hz = 1, rot = 0 },
			{ kind = "Planter", x = -canopy * 0.55, z = 16.2, hx = 2, hz = 1, rot = 0 },
		}
	do
		for _, dx in { 0, 6, -6, 12, -12 } do
			local x = spot.x + dx
			if room(x - spot.hx, x + spot.hx, spot.z - spot.hz, spot.z + spot.hz) then
				onPlatform(spot.kind, x, spot.z, spot.hx, spot.hz, spot.rot)
				break
			end
		end
	end
	for _, side in { -1, 1 } do
		table.insert(props, {
			kind = "PlatformEnd",
			slab = 1,
			x = side * (half - 0.6),
			z = safe / 2,
			rot = if side > 0 then 0 else 180,
			size = safe - 2,
		})
	end

	-- The edge ------------------------------------------------------------------------
	--[[
		A boundary round the three open sides: fences, walls or a hedge along both ends and
		the far edge, and a treeline standing along them, so nobody walks off into the dark by
		accident. Each piece stands on the slab of the tile it is on and goes down with it when
		the ground collapses. Tiles a building or structure fills make their own boundary.
	]]
	local edge = arch.edge
	local function tree(gx: number, gz: number, x: number, z: number)
		local i = index(gx, gz)
		if #edge.trees > 0 and not claimed[i] then
			table.insert(props, {
				kind = rng:pick(edge.trees),
				slab = slabOfTile[i],
				x = x,
				z = z,
				rot = rng:range(0, 360),
			})
		end
	end
	for gx = 0, cols - 1 do
		local i = index(gx, rows - 1)
		if occupancy[i] == 0 then
			table.insert(props, {
				kind = edge.fence,
				slab = slabOfTile[i],
				x = tileX(gx),
				z = arch.depth - Stations.EdgeInset,
				rot = 0,
				size = tile,
			})
			if rng:chance(edge.treeChance) then
				tree(gx, rows - 1, tileX(gx) + rng:range(-3.5, 3.5), arch.depth - 2.8)
			end
		end
	end
	for _, gx in { 0, cols - 1 } do
		local s = if gx == 0 then -1 else 1
		for gz = safeRows, rows - 1 do
			local i = index(gx, gz)
			if occupancy[i] == 0 then
				-- the far corner belongs to the far fence
				local last = gz == rows - 1
				local cut = if last then 2 * Stations.EdgeInset + 1 else 0
				table.insert(props, {
					kind = edge.fence,
					slab = slabOfTile[i],
					x = s * (half - Stations.EdgeInset),
					z = tileZ(gz) - cut / 2,
					rot = 90,
					size = tile - cut,
				})
				if gz % 2 == 1 and rng:chance(edge.treeChance) then
					tree(gx, gz, s * (half - 2.8), tileZ(gz) + rng:range(-3, 3))
				end
			end
		end
	end

	-- The yard ---------------------------------------------------------------------------
	-- Inner tiles only: the edge strip belongs to the boundary.
	local function innerTiles(): { { number } }
		local out: { { number } } = {}
		for _, cell in freeTiles(nil) do
			if cell[1] > 0 and cell[1] < cols - 1 and cell[2] < rows - 1 then
				table.insert(out, cell)
			end
		end
		return out
	end
	local function onTile(kind: string, jitter: number, corner: boolean?): boolean
		local candidates = innerTiles()
		if #candidates == 0 then
			return false
		end
		local cell = rng:pick(candidates)
		local i = index(cell[1], cell[2])
		claimed[i] = true
		local x, z = tileX(cell[1]), tileZ(cell[2])
		if corner then
			x, z = x + tile / 2 - 1, z + tile / 2 - 1
		end
		table.insert(props, {
			kind = kind,
			slab = slabOfTile[i],
			x = x + rng:range(-jitter, jitter),
			z = z + rng:range(-jitter, jitter),
			rot = if corner then 0 else rng:range(0, 360),
		})
		return true
	end
	for _ = 1, cols // 5 do
		onTile("Lamp", 0, true)
	end
	if not arch.terminus then
		for _ = 1, cols // 4 do
			onTile("DecorCrates", 3)
		end
		-- the things that say what this place was: a haycart, a well, a swing in the school yard
		for n = 1, Stations.DressingCount do
			if #arch.dressing == 0 or not onTile(arch.dressing[(n - 1) % #arch.dressing + 1], 2) then
				break
			end
		end
		for _ = 1, arch.yardTrees do
			if #edge.trees == 0 or not onTile(rng:pick(edge.trees), 2) then
				break
			end
		end
	end

	-- Hollow spawn lanes along the far edge ---------------------------------------------
	local lanes: { number } = {}
	local laneCount = 8
	for i = 1, laneCount do
		table.insert(lanes, -arch.length / 2 + arch.length * (i - 0.5) / laneCount)
	end
	rng:shuffle(lanes)

	return {
		archetype = archetypeId,
		seed = seed,
		length = arch.length,
		depth = arch.depth,
		tile = tile,
		cols = cols,
		rows = rows,
		safeRows = safeRows,
		slabs = slabs,
		structures = structures,
		buildings = buildings,
		containers = containers,
		loose = loose,
		props = props,
		sleepers = sleepers,
		spawnLanes = lanes,
	}
end

-- Slab under a station-local point, or nil when the point is off the grid.
function LayoutGen.slabAt(plan: Plan, x: number, z: number): Slab?
	local gx = math.floor((x + plan.length / 2) / plan.tile)
	local gz = math.floor(z / plan.tile)
	if gx < 0 or gx >= plan.cols or gz < 0 or gz >= plan.rows then
		return nil
	end
	if gz < plan.safeRows then
		return plan.slabs[1]
	end
	for _, slab in plan.slabs do
		if gx >= slab.gx and gx < slab.gx + slab.w and gz >= slab.gz and gz < slab.gz + slab.d then
			return slab
		end
	end
	return nil
end

return table.freeze(LayoutGen)
