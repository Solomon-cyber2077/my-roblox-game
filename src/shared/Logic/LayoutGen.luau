--!strict
--[[
	Procedural station layouts. Pure: the same archetype, seed and loot multiplier
	always produce the same plan, on the server, the client and in tests.

	The station is a grid of 12-stud tiles. x runs along the track (0 is the
	station centre), z runs away from the platform edge (0 is the edge).

	Each archetype's layout (Config/Stations) carves routes first, so buildings line a street,
	a square, a yard or a goods yard's sidings; barriers pinch the zone boundaries into
	chokepoints and broken ground lies beside the routes.

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
	y: number?, -- floor height inside a building with an upper floor; nil on the ground
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
local BARRIER = -1 -- the occupancy of a tile a barrier closes off
local EDGE_CLEAR = 2.2 -- a barrier stops this far in from the station's side, clear of its fence
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

	-- Routes -----------------------------------------------------------------------------
	--[[
		The layout style carves the routes before anything is placed: a street, a square or a
		yard, or the sidings of a goods yard. Route tiles stay open, and buildings and
		structures prefer lots that front them (route holds each tile's frontage weight).
	]]
	local layout = arch.layout
	local route: { [number]: number } = {}
	local function reserve(gx: number, gz: number, weight: number)
		if gx >= 0 and gx < cols and gz >= safeRows and gz < rows then
			local i = index(gx, gz)
			route[i] = math.max(route[i] or 0, weight)
		end
	end
	-- A lane `width` tiles wide from row gz0 to gz1 that steps sideways now and then.
	local function lane(gx: number, gz0: number, gz1: number, width: number)
		for gz = gz0, gz1 do
			for k = 0, width - 1 do
				reserve(gx + k, gz, 5)
			end
			if gz < gz1 and (gz - gz0) % 3 == 2 then
				local nx = math.clamp(gx + rng:int(-1, 1), 1, cols - 1 - width)
				for x = math.min(gx, nx), math.max(gx, nx) + width - 1 do
					reserve(x, gz, 5)
				end
				gx = nx
			end
		end
	end
	local function middleRow(zone: string): number
		local found: { number } = {}
		for gz = safeRows, rows - 2 do
			if zoneOf(gz) == zone then
				table.insert(found, gz)
			end
		end
		return found[(#found + 1) // 2]
	end
	local square: { number }? = nil -- {gx, gz, w, d}
	if layout then
		local width = layout.lane
		if layout.style == "Street" then
			lane(rng:int(cols // 2 - cols // 6, cols // 2 + cols // 6 - width), safeRows, rows - 1, width)
			local cross = middleRow("Mid") + rng:int(-1, 1)
			for gx = 1, cols - 2 do
				reserve(gx, cross, 3)
			end
		elseif layout.style == "Plaza" or layout.style == "Yard" then
			local size = layout.square or { 5, 4 }
			local w, d = size[1], size[2]
			local gx = rng:int(2, cols - 2 - w)
			local gz = if layout.style == "Plaza"
				then math.clamp(middleRow("Mid") - d // 2, safeRows + 2, rows - 2 - d)
				else safeRows + rng:int(1, 2)
			square = { gx, gz, w, d }
			for x = gx, gx + w - 1 do
				for z = gz, gz + d - 1 do
					reserve(x, z, if layout.style == "Plaza" then 30 else 12)
				end
			end
			lane(rng:int(gx, gx + w - width), safeRows, gz - 1, width)
			lane(rng:int(gx, gx + w - width), gz + d, rows - 1, width)
		else
			lane(rng:int(3, cols - 3 - width), safeRows, rows - 1, width)
		end
	end

	-- Lots: every free footprint in the rows `rowOk` allows, weighted by the route it fronts.
	local function lots(w: number, d: number, rowOk: (number) -> boolean): { Rng.Weighted<{ number }> }
		local out: { Rng.Weighted<{ number }> } = {}
		for gz = safeRows, rows - d do
			if rowOk(gz) then
				for gx = 0, cols - w do
					if canPlace(gx, gz, w, d) then
						local free, front = true, 0
						for x = gx - 1, gx + w do
							for z = gz - 1, gz + d do
								local inside = x >= gx and x < gx + w and z >= gz and z < gz + d
								if x >= 0 and x < cols and z >= 0 and z < rows then
									local weight = route[index(x, z)]
									if weight and inside then
										free = false
									elseif weight then
										front = math.max(front, weight)
									end
								end
							end
						end
						if free then
							table.insert(out, { weight = 1 + front, value = { gx, gz } })
						end
					end
				end
			end
		end
		return out
	end
	-- Fills a weighted pick from `candidates` with `value`, trying others while the pick would
	-- cut ground off from the platform. Returns the lot, or nil.
	local function settle(
		candidates: { Rng.Weighted<{ number }> },
		w: number,
		d: number,
		value: number
	): { number }?
		for _ = 1, 16 do
			if #candidates == 0 then
				return nil
			end
			local lot = rng:weighted(candidates)
			fill(lot[1], lot[2], w, d, value)
			if connected() then
				return lot
			end
			fill(lot[1], lot[2], w, d, 0)
			for k, entry in candidates do
				if entry.value == lot then
					table.remove(candidates, k)
					break
				end
			end
		end
		return nil
	end
	local function inZones(zones: { string }, offset: number): (number) -> boolean
		local first = rng:pick(zones)
		return function(gz: number): boolean
			return zoneOf(gz + offset) == first
		end
	end
	local function anyZone(zones: { string }, offset: number): (number) -> boolean
		return function(gz: number): boolean
			return table.find(zones, zoneOf(gz + offset)) ~= nil
		end
	end

	-- Enterable buildings first: they are the biggest, and the stop is built around them --
	local buildings: { Building } = {}
	local landmarks: { Stations.LandmarkRule } = arch.landmarks or {}
	for _, rule in landmarks do
		local def = Buildings.Defs[rule.kind]
		local w, d = def.size[1], def.size[2]
		local id = #buildings + 1
		local lot = settle(lots(w, d, inZones(rule.zones, d // 2)), w, d, LANDMARK + id)
			or settle(lots(w, d, anyZone(rule.zones, d // 2)), w, d, LANDMARK + id)
		if lot then
			local gx, gz = lot[1], lot[2]
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
		end
	end

	-- The sidings run round the buildings: along the emptiest rows near evenly spaced marks.
	local sidings: { number } = {}
	if layout and layout.style == "Sidings" then
		local count = layout.sidings or 2
		for k = 1, count do
			local mark = safeRows + math.floor((rows - safeRows) * k / (count + 1)) + rng:int(0, 1)
			local best, bestCost = nil, math.huge
			for gz = math.max(safeRows + 1, mark - 2), math.min(rows - 3, mark + 2) do
				local cost = math.abs(gz - mark) * 0.5
				for gx = 1, cols - 2 do
					if occupancy[index(gx, gz)] ~= 0 then
						cost += 1
					end
				end
				local apart = not table.find(sidings, gz) and not table.find(sidings, gz - 1)
				if apart and cost < bestCost then
					best, bestCost = gz, cost
				end
			end
			if best then
				table.insert(sidings, best)
				for gx = 1, cols - 2 do
					reserve(gx, best, 4)
				end
			end
		end
	end

	-- Structures -------------------------------------------------------------------------
	local structures: { Structure } = {}
	local centred = false
	for _, rule in arch.structures do
		local footprint = Stations.Footprints[rule.kind]
		for _ = 1, rule.count do
			local w, d = footprint[1], footprint[2]
			local rot = 0
			if w ~= d and not NO_ROTATE[rule.kind] and rng:chance(0.5) then
				w, d = d, w
				rot = 90
			end
			local id = #structures + 1
			local lot: { number }? = nil
			if square and layout and layout.centre == rule.kind and not centred then
				-- the centrepiece stands in the middle of the square
				centred = true
				local spot = { square[1] + (square[3] - w) // 2, square[2] + (square[4] - d) // 2 }
				lot = settle({ { weight = 1, value = spot } }, w, d, id)
			end
			if lot == nil then
				local rowOk = if rule.kind == "TunnelMouth"
					then function(gz: number): boolean
						return gz == rows - d
					end
					else inZones(rule.zones, 0)
				lot = settle(lots(w, d, rowOk), w, d, id)
				if lot == nil and rule.kind ~= "TunnelMouth" then
					lot = settle(lots(w, d, anyZone(rule.zones, 0)), w, d, id)
				end
			end
			if lot then
				local gx, gz = lot[1], lot[2]
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
			end
		end
	end

	-- Barriers -----------------------------------------------------------------------------
	--[[
		Each zone boundary is closed off a few tiles at a time (more of the far one), with the
		routes left open through it, so the crew funnel through gaps and the far zone is a
		pocket behind the last line. A tile is only closed if all ground stays reachable.
	]]
	local barrierAt: { [number]: string } = {}
	local barrierRows: { number } = {}
	if layout then
		for b, zone in { "Mid", "Far" } do
			local first: number? = nil
			for gz = safeRows, rows - 2 do
				if first == nil and zoneOf(gz) == zone then
					first = gz
				end
			end
			local chosen: number? = nil
			if first then
				for _, gz in { first, first + 1, first - 1 } do
					local open = 0
					for gx = 0, cols - 1 do
						if route[index(gx, gz)] then
							open += 1
						end
					end
					if chosen == nil and gz > safeRows and gz < rows - 1 and open <= layout.lane + 2 then
						chosen = gz
					end
				end
			end
			if chosen then
				local gz = chosen
				table.insert(barrierRows, gz)
				local gx = 0
				while gx < cols do
					local span = rng:int(2, 4)
					if rng:chance(layout.fill[b]) then
						local kind = rng:pick(layout.barriers)
						for x = gx, math.min(gx + span - 1, cols - 1) do
							local i = index(x, gz)
							if occupancy[i] == 0 and route[i] == nil then
								occupancy[i] = BARRIER
								if connected() then
									barrierAt[i] = kind
								else
									occupancy[i] = 0
								end
							end
						end
						gx += span
					else
						gx += rng:int(1, 2)
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

	-- The sidings' track and the barriers, one tile each ----------------------------------
	local claimed: { [number]: boolean } = {}
	local groundProps: { Prop } = {}
	-- One tile of something that runs along x: joined end to end with its neighbours where
	-- `joined` says so, stopped short of the next tile (or the side fence) where not.
	local function along(gx: number, gz: number, kind: string, joined: (number) -> boolean)
		local x0, x1 = tileX(gx) - tile / 2, tileX(gx) + tile / 2
		if not joined(gx - 1) then
			x0 += if gx == 0 then EDGE_CLEAR else 0.5
		end
		if not joined(gx + 1) then
			x1 -= if gx == cols - 1 then EDGE_CLEAR else 0.5
		end
		local i = index(gx, gz)
		claimed[i] = true
		table.insert(groundProps, {
			kind = kind,
			slab = slabOfTile[i],
			x = (x0 + x1) / 2,
			z = tileZ(gz),
			rot = 0,
			size = x1 - x0,
		})
	end
	for _, gz in sidings do
		local function track(x: number): boolean
			return x >= 1 and x <= cols - 2 and occupancy[index(x, gz)] == 0
		end
		for gx = 1, cols - 2 do
			if track(gx) then
				along(gx, gz, "Siding", track)
			end
		end
	end
	for _, gz in barrierRows do
		for gx = 0, cols - 1 do
			local kind = barrierAt[index(gx, gz)]
			if kind then
				along(gx, gz, kind, function(x: number): boolean
					return x >= 0 and x < cols and barrierAt[index(x, gz)] == kind
				end)
				-- the gaps either side stay clear
				for _, x in { gx - 1, gx + 1 } do
					if x >= 0 and x < cols and occupancy[index(x, gz)] == 0 then
						claimed[index(x, gz)] = true
					end
				end
			end
		end
	end

	-- Containers ----------------------------------------------------------------------

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
						{ weight = def.zoneWeights.Far * (Stations.FarLoot[kind] or 1), value = "Far" },
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
					y = if item.y and item.y > 0 then item.y else nil,
				})
			end
		end
		for _, spot in building.plan.sleepers do
			if spot.y and spot.y > 0 then
				continue -- nothing sleeps upstairs (yet)
			end
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
	local props: { Prop } = table.clone(groundProps)
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
			if occupancy[i] == 0 or occupancy[i] == BARRIER then
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
	-- Inner tiles only: the edge strip belongs to the boundary, and the routes stay open
	-- unless `onRoutes`.
	local function innerTiles(onRoutes: boolean): { { number } }
		local out: { { number } } = {}
		for _, cell in freeTiles(nil) do
			local open = onRoutes or route[index(cell[1], cell[2])] == nil
			if open and cell[1] > 0 and cell[1] < cols - 1 and cell[2] < rows - 1 then
				table.insert(out, cell)
			end
		end
		return out
	end
	local function onTile(kind: string, jitter: number, corner: boolean?): boolean
		-- lamps stand at a tile's corner, so they may light a route
		local candidates = innerTiles(corner == true)
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

	-- Broken ground: rubble, raised decks, dug-in lines and wrecks beside the routes (deeper
	-- in, more of it), and the road itself breaking up on them.
	if layout then
		local function nextToRoute(gx: number, gz: number): boolean
			for _, dir in DIRECTIONS do
				local nx, nz = gx + dir[1], gz + dir[2]
				if nx >= 0 and nx < cols and nz >= 0 and nz < rows and route[index(nx, nz)] then
					return true
				end
			end
			return false
		end
		for n = 1, layout.groundCount do
			local kind = layout.ground[(n - 1) % #layout.ground + 1]
			local onRoute = kind == "BrokenRoad"
			local weighted: { Rng.Weighted<{ number }> } = {}
			for _, cell in innerTiles(true) do
				if (route[index(cell[1], cell[2])] ~= nil) == onRoute then
					local near = onRoute or nextToRoute(cell[1], cell[2])
					local deep = zoneOf(cell[2]) ~= "Near"
					local weight = (if near then 4 else 1) * (if deep then 2 else 1)
					table.insert(weighted, { weight = weight, value = cell })
				end
			end
			if #weighted > 0 then
				local cell = rng:weighted(weighted)
				local i = index(cell[1], cell[2])
				claimed[i] = true
				table.insert(props, {
					kind = kind,
					slab = slabOfTile[i],
					x = tileX(cell[1]) + rng:range(-0.6, 0.6),
					z = tileZ(cell[2]) + rng:range(-0.6, 0.6),
					rot = rng:int(0, 3) * 90 + rng:range(-5, 5),
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
