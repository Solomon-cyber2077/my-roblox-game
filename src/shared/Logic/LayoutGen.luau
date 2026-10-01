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
local Loot = require(Shared.Config.Loot)
local Stations = require(Shared.Config.Stations)
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)

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
}

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
	kind: string,
	zone: string,
	slab: number,
	x: number,
	z: number,
	rot: number,
}
export type Loose = { id: number, item: string, slab: number, x: number, z: number }
export type Prop = { kind: string, slab: number, x: number, z: number, rot: number }

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
	containers: { Container },
	loose: { Loose },
	props: { Prop },
	spawnLanes: { number },
}

local CONTAINER_ORDER = { "Crate", "Locker", "CoalBin", "ToolChest", "Vault" }
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

	-- Decorative props ------------------------------------------------------------------
	local props: { Prop } = {}
	local spacing = arch.lampSpacing
	local lampCount = math.floor(arch.length / spacing)
	for i = 0, lampCount - 1 do
		local x = -arch.length / 2 + spacing * (i + 0.5)
		table.insert(props, { kind = "Lamp", slab = 1, x = x, z = safe - 3, rot = 0 })
		if i % 2 == 0 and i < lampCount - 1 then
			table.insert(props, { kind = "Bench", slab = 1, x = x + spacing / 2, z = 12, rot = 0 })
		end
	end
	table.insert(props, { kind = "Sign", slab = 1, x = 0, z = safe - 6, rot = 0 })
	if arch.length >= 280 then
		table.insert(props, { kind = "Sign", slab = 1, x = -arch.length / 3, z = safe - 6, rot = 0 })
		table.insert(props, { kind = "Sign", slab = 1, x = arch.length / 3, z = safe - 6, rot = 0 })
	end

	local decorLamps = cols // 5
	for _ = 1, decorLamps do
		local candidates = freeTiles(nil)
		if #candidates == 0 then
			break
		end
		local cell = rng:pick(candidates)
		local i = index(cell[1], cell[2])
		claimed[i] = true
		table.insert(props, {
			kind = "Lamp",
			slab = slabOfTile[i],
			x = tileX(cell[1]) + tile / 2 - 1,
			z = tileZ(cell[2]) + tile / 2 - 1,
			rot = 0,
		})
	end

	if not arch.terminus then
		local decorCrates = cols // 4
		for _ = 1, decorCrates do
			local candidates = freeTiles(nil)
			if #candidates == 0 then
				break
			end
			local cell = rng:pick(candidates)
			local i = index(cell[1], cell[2])
			claimed[i] = true
			table.insert(props, {
				kind = "DecorCrates",
				slab = slabOfTile[i],
				x = tileX(cell[1]) + rng:range(-3, 3),
				z = tileZ(cell[2]) + rng:range(-3, 3),
				rot = rng:range(0, 360),
			})
		end
		for gx = 0, cols - 1 do
			local i = index(gx, rows - 1)
			if occupancy[i] == 0 and rng:chance(0.6) then
				table.insert(props, {
					kind = "Railing",
					slab = slabOfTile[i],
					x = tileX(gx),
					z = arch.depth - 1,
					rot = rng:range(-6, 6),
				})
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
		containers = containers,
		loose = loose,
		props = props,
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
