--!strict
--[[
	Station archetypes. Lengths and depths are multiples of the 12-stud tile.

	loot:       weight multipliers per item category (coal, parts, relic, tools)
	hazard:     multipliers on collapse speed, fog reach and Hollow pressure
	containers: base container counts before difficulty scaling
	structures: blocking buildings (footprint in tiles) and props
	landmarks:  enterable buildings (Config/Buildings) the crew search room by room
	palette:    RGB colours the builder uses for ground, accent and trim
	edge:       the boundary round the open sides: the fence (or wall, or hedge) along
	            both ends and the far edge, and the trees standing along them
	dressing:   what the yard is littered with, the things that say what this place was
	            (StationDressing builds them all)
	layout:     how the stop is laid out (LayoutGen): the routes carved before anything is
	            placed, the barriers that pinch each zone boundary into chokepoints, and the
	            broken ground beside the routes. A stop without one is scattered at random.
]]

-- Street: a lane from the platform to the far edge and a cross street, lined with lots.
-- Plaza: an open square in the middle zone, a structure in its centre, lanes in and out.
-- Yard: an open forecourt by the platform with buildings round it and a lane on to the back.
-- Sidings: tracks running the length of the yard, joined by one lane, heaps between them.
export type Layout = {
	style: "Street" | "Plaza" | "Yard" | "Sidings",
	lane: number, -- the main route's width in tiles
	square: { number }?, -- Plaza and Yard: the open ground, in tiles
	centre: string?, -- Plaza: the structure standing in the middle of the square
	sidings: number?, -- Sidings: how many tracks
	barriers: { string }, -- what closes off the zone boundaries, a few tiles at a time
	fill: { number }, -- the share closed at the Near/Mid and the Mid/Far boundary
	ground: { string }, -- Rubble, BrokenRoad (on the routes), Deck, Trench, Wreck
	groundCount: number,
}

export type StructureRule = {
	kind: string,
	count: number,
	zones: { string },
}

export type LandmarkRule = {
	kind: string,
	zones: { string },
	decor: boolean?, -- set dressing (default false): searched, but not counted in the stop's size (dwell, Hollow cap)
}

export type Village = {
	rows: number, -- tiles of depth, the last rows of the stop
	landmarks: { LandmarkRule }, -- placed in the Village zone
	containers: { [string]: number }, -- on top of the stop's own, before difficulty scaling
}

export type Archetype = {
	id: string,
	name: string,
	tier: number,
	minStation: number,
	weight: number,
	length: number,
	depth: number,
	dwellMultiplier: number,
	hint: string,
	loot: { coal: number, parts: number, relic: number, tools: number },
	hazard: { collapse: number, fog: number, hollows: number },
	containers: { [string]: number },
	looseItems: number,
	structures: { StructureRule },
	landmarks: { LandmarkRule }?,
	lampSpacing: number,
	ground: string,
	palette: { ground: { number }, accent: { number }, trim: { number }, light: { number } },
	edge: { fence: string, trees: { string }, treeChance: number },
	dressing: { string },
	yardTrees: number,
	layout: Layout?,
	village: Village?,
	terminus: boolean?,
	emergency: boolean?, -- the Emergency Village: no platform buildings, a cinder bank and the train's lights
	yardLamps: number?, -- lamp pools at most (default Lamps.YardMax)
}

local Archetypes: { [string]: Archetype } = {
	Halt = {
		id = "Halt",
		name = "Whistle-Stop Halt",
		tier = 1,
		minStation = 1,
		weight = 1.0,
		length = 432,
		depth = 348,
		dwellMultiplier = 0.95,
		hint = "Balanced haul",
		loot = { coal = 1.0, parts = 1.0, relic = 0.8, tools = 1.0 },
		hazard = { collapse = 0.9, fog = 1.0, hollows = 0.8 },
		containers = { Crate = 9, CoalBin = 3, ToolChest = 2 },
		looseItems = 9,
		structures = {
			{ kind = "CattleDock", count = 1, zones = { "Near", "Mid" } },
			{ kind = "WaterTower", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Shed", count = 3, zones = { "Mid", "Far" } },
		},
		landmarks = {
			{ kind = "BookingHall", zones = { "Near" } },
			{ kind = "StationmasterHouse", zones = { "Near", "Mid" } },
			{ kind = "GoodsShed", zones = { "Mid", "Far" } },
			{ kind = "House", zones = { "Mid", "Far" }, decor = true },
		},
		lampSpacing = 36,
		ground = "Cobblestone",
		palette = {
			ground = { 128, 116, 100 },
			accent = { 150, 110, 70 },
			trim = { 58, 50, 44 },
			light = { 255, 196, 128 },
		},
		edge = { fence = "FencePicket", trees = { "Oak", "Oak", "Poplar" }, treeChance = 0.8 },
		dressing = {
			"Haystack",
			"Cart",
			"Pump",
			"Wheelbarrow",
			"Puddle",
			"Barrels",
			"Scarecrow",
			"Well",
			"Haystack",
		},
		yardTrees = 6,
		layout = {
			style = "Street",
			lane = 1,
			barriers = { "FencePicket", "Wreck" },
			fill = { 0.4, 0.6 },
			ground = { "BrokenRoad", "Rubble", "Wreck" },
			groundCount = 8,
		},
		-- the hamlet up the lane: an inn and the cottages round the green
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Inn", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 3, ToolChest = 1, Vault = 1 },
		},
	},
	CoalYard = {
		id = "CoalYard",
		name = "Coaling Yard",
		tier = 2,
		minStation = 1,
		weight = 1.0,
		length = 480,
		depth = 372,
		dwellMultiplier = 1.0,
		hint = "Coal-rich",
		loot = { coal = 2.2, parts = 0.7, relic = 0.7, tools = 0.8 },
		hazard = { collapse = 1.25, fog = 1.0, hollows = 0.9 },
		containers = { Crate = 8, CoalBin = 12, ToolChest = 2, Vault = 1 },
		looseItems = 22,
		structures = {
			{ kind = "CoalTower", count = 1, zones = { "Mid" } },
			{ kind = "Chimney", count = 1, zones = { "Mid", "Far" } },
			{ kind = "CoalHeap", count = 7, zones = { "Near", "Mid", "Far" } },
			{ kind = "Hopper", count = 5, zones = { "Near", "Mid" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		landmarks = {
			{ kind = "BoilerHouse", zones = { "Mid", "Far" } },
			{ kind = "EngineShed", zones = { "Far", "Mid" } },
			{ kind = "CoalOffice", zones = { "Near" } },
			{ kind = "House", zones = { "Near", "Mid" }, decor = true },
		},
		lampSpacing = 42,
		ground = "Slate",
		palette = {
			ground = { 74, 70, 68 }, -- ash over slate
			accent = { 120, 84, 52 },
			trim = { 34, 33, 33 },
			light = { 255, 170, 96 },
		},
		edge = { fence = "FenceRail", trees = { "DeadTree", "Poplar", "DeadTree" }, treeChance = 0.6 },
		dressing = { "Barrels", "Wheelbarrow", "Puddle", "Bonfire", "Cart", "MineCart", "Bonfire" },
		yardTrees = 3,
		layout = {
			style = "Sidings",
			lane = 1,
			sidings = 3,
			barriers = { "Wreck", "FenceRail" },
			fill = { 0.4, 0.6 },
			ground = { "Rubble", "BrokenRoad", "Wreck" },
			groundCount = 9,
		},
		-- the railwaymen's row behind the depot, and their chapel
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Chapel", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, CoalBin = 2, ToolChest = 1, Vault = 1 },
		},
	},
	SignalWorks = {
		id = "SignalWorks",
		name = "Signal Works",
		tier = 2,
		minStation = 2,
		weight = 1.0,
		length = 468,
		depth = 420,
		dwellMultiplier = 1.0,
		hint = "Parts-rich",
		loot = { coal = 0.7, parts = 2.2, relic = 0.9, tools = 1.2 },
		hazard = { collapse = 0.9, fog = 1.0, hollows = 1.3 },
		containers = { Crate = 9, CoalBin = 2, ToolChest = 6, Vault = 1 },
		looseItems = 12,
		landmarks = {
			{ kind = "SignalCabin", zones = { "Near" } },
			{ kind = "Workshop", zones = { "Mid" } },
			{ kind = "GoodsShed", zones = { "Mid", "Far" } },
			{ kind = "House", zones = { "Far" } },
		},
		structures = {
			{ kind = "Gantry", count = 2, zones = { "Near", "Mid" } },
			{ kind = "Workshop", count = 1, zones = { "Mid", "Far" } },
			{ kind = "SignalBox", count = 1, zones = { "Far" } },
			{ kind = "CableDrums", count = 8, zones = { "Near", "Mid", "Far" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		lampSpacing = 36,
		ground = "Concrete",
		palette = {
			ground = { 132, 130, 124 },
			accent = { 168, 54, 42 },
			trim = { 60, 62, 64 },
			light = { 230, 236, 255 },
		},
		edge = { fence = "FenceIron", trees = { "Poplar", "Birch" }, treeChance = 0.65 },
		dressing = { "SignalPost", "Barrels", "Puddle", "Wheelbarrow", "Bonfire", "SignalPost" },
		yardTrees = 3,
		layout = {
			style = "Sidings",
			lane = 1,
			sidings = 3,
			barriers = { "FenceIron", "Wreck" },
			fill = { 0.35, 0.55 },
			ground = { "Deck", "Rubble", "Wreck" },
			groundCount = 9,
		},
		-- the linemen's cottages and the shop that served them
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "GeneralStore", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, ToolChest = 2, Vault = 1 },
		},
	},
	Market = {
		id = "Market",
		name = "Ashfall Market",
		tier = 2,
		minStation = 3,
		weight = 1.0,
		length = 480,
		depth = 408,
		dwellMultiplier = 1.05,
		hint = "Relics",
		loot = { coal = 0.9, parts = 0.9, relic = 1.8, tools = 1.1 },
		hazard = { collapse = 1.0, fog = 1.25, hollows = 1.0 },
		containers = { Crate = 12, CoalBin = 2, ToolChest = 2, Vault = 2 },
		looseItems = 10,
		landmarks = {
			{ kind = "MarketHall", zones = { "Mid" } },
			{ kind = "GeneralStore", zones = { "Near", "Mid" } },
			{ kind = "Inn", zones = { "Mid", "Far" } },
			{ kind = "GeneralStore", zones = { "Far" }, decor = true },
		},
		structures = {
			{ kind = "Fountain", count = 1, zones = { "Mid" } },
			{ kind = "ClockTower", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Stall", count = 16, zones = { "Near", "Mid", "Mid", "Far" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		lampSpacing = 30,
		ground = "Pavement",
		palette = {
			ground = { 146, 132, 116 },
			accent = { 132, 46, 52 },
			trim = { 70, 60, 52 },
			light = { 255, 186, 120 },
		},
		edge = { fence = "WallStone", trees = { "DeadTree", "Oak" }, treeChance = 0.6 },
		dressing = { "Barrels", "Cart", "Bonfire", "Puddle", "Pump", "PillarBox", "Cart" },
		yardTrees = 3,
		layout = {
			style = "Plaza",
			lane = 2,
			square = { 8, 5 },
			centre = "Fountain",
			barriers = { "WallStone", "Wreck" },
			fill = { 0.4, 0.6 },
			ground = { "BrokenRoad", "Rubble" },
			groundCount = 8,
		},
		-- the back streets: terraces down to the chapel
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Chapel", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 3, ToolChest = 1, Vault = 1 },
		},
	},
	Viaduct = {
		id = "Viaduct",
		name = "Viaduct Halt",
		tier = 3,
		minStation = 4,
		weight = 0.8,
		length = 612,
		depth = 216,
		dwellMultiplier = 0.9,
		hint = "Relics, fragile ground",
		loot = { coal = 1.0, parts = 1.0, relic = 2.0, tools = 1.4 },
		hazard = { collapse = 1.5, fog = 0.9, hollows = 0.9 },
		containers = { Crate = 9, CoalBin = 3, ToolChest = 4, Vault = 1 },
		looseItems = 10,
		structures = {
			{ kind = "Arches", count = 3, zones = { "Near", "Mid", "Far" } },
			{ kind = "SignalBox", count = 1, zones = { "Mid", "Far" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		landmarks = {
			{ kind = "Chapel", zones = { "Mid", "Far" } },
			{ kind = "SignalCabin", zones = { "Near", "Mid" } },
			{ kind = "CoalOffice", zones = { "Near" } },
			{ kind = "House", zones = { "Mid" }, decor = true },
		},
		lampSpacing = 40,
		ground = "Brick",
		palette = {
			ground = { 150, 96, 74 },
			accent = { 176, 141, 87 },
			trim = { 78, 50, 40 },
			light = { 255, 206, 150 },
		},
		edge = { fence = "WallStone", trees = { "Pine", "Birch", "Pine" }, treeChance = 0.55 },
		dressing = { "Graves", "Puddle", "Bonfire", "Barrels", "Graves" },
		yardTrees = 2,
		layout = {
			style = "Street",
			lane = 1,
			barriers = { "WallStone" },
			fill = { 0.4, 0.6 },
			ground = { "Rubble", "Trench", "BrokenRoad" },
			groundCount = 8,
		},
		-- the platelayers' cottages along the far edge, and their inn
		village = {
			rows = 5,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Inn", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, ToolChest = 1, Vault = 1 },
		},
	},
	Minehead = {
		id = "Minehead",
		name = "Minehead",
		tier = 3,
		minStation = 5,
		weight = 0.9,
		length = 480,
		depth = 432,
		dwellMultiplier = 1.1,
		hint = "Coal and parts",
		loot = { coal = 1.8, parts = 1.6, relic = 1.0, tools = 1.0 },
		hazard = { collapse = 1.0, fog = 1.2, hollows = 1.5 },
		containers = { Crate = 9, CoalBin = 8, ToolChest = 4, Vault = 1 },
		looseItems = 14,
		structures = {
			{ kind = "Headframe", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Chimney", count = 1, zones = { "Mid" } },
			{ kind = "TunnelMouth", count = 1, zones = { "Far" } },
			{ kind = "Shed", count = 3, zones = { "Near", "Mid" } },
			{ kind = "CoalHeap", count = 5, zones = { "Mid", "Far" } },
		},
		landmarks = {
			{ kind = "LampRoom", zones = { "Near", "Mid" } },
			{ kind = "WindingHouse", zones = { "Near", "Mid" } },
			{ kind = "CoalOffice", zones = { "Near" } },
			-- the pit row: miners' cottages up the hill
			{ kind = "Terrace", zones = { "Mid", "Far" } },
		},
		lampSpacing = 36,
		ground = "Ground",
		palette = {
			ground = { 98, 82, 64 }, -- wet pit mud
			accent = { 140, 98, 58 },
			trim = { 46, 40, 34 },
			light = { 255, 176, 100 },
		},
		edge = { fence = "FenceRail", trees = { "Pine", "DeadTree", "Pine" }, treeChance = 0.75 },
		dressing = { "MineCart", "Barrels", "Bonfire", "Puddle", "Wheelbarrow", "Puddle", "MineCart" },
		yardTrees = 4,
		layout = {
			style = "Yard",
			lane = 1,
			square = { 8, 4 },
			barriers = { "FenceRail", "Wreck" },
			fill = { 0.4, 0.6 },
			ground = { "Trench", "Rubble", "Deck" },
			groundCount = 10,
		},
		-- the top of the village: the chapel and the last rows
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Chapel", zones = { "Village" } },
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, CoalBin = 2, ToolChest = 1, Vault = 1 },
		},
	},
	Schoolhouse = {
		id = "Schoolhouse",
		name = "Ashgrove",
		tier = 2,
		minStation = 2,
		weight = 1.1,
		length = 480,
		depth = 408,
		dwellMultiplier = 1.0,
		hint = "A whole school to search",
		loot = { coal = 1.2, parts = 1.1, relic = 1.3, tools = 1.0 },
		hazard = { collapse = 0.9, fog = 1.0, hollows = 1.0 },
		containers = { Crate = 7, CoalBin = 3, ToolChest = 2 },
		looseItems = 10,
		structures = {
			{ kind = "WaterTower", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Shed", count = 3, zones = { "Mid", "Far" } },
		},
		landmarks = {
			{ kind = "School", zones = { "Mid" } },
			{ kind = "SchoolmasterHouse", zones = { "Near", "Mid" } },
			{ kind = "Chapel", zones = { "Far" } },
		},
		lampSpacing = 44,
		ground = "Pavement",
		palette = {
			ground = { 124, 118, 108 },
			accent = { 128, 52, 46 },
			trim = { 54, 50, 48 },
			light = { 255, 204, 140 },
		},
		edge = { fence = "FencePicket", trees = { "Oak", "Oak", "Poplar" }, treeChance = 0.8 },
		dressing = { "Swings", "Haystack", "Puddle", "Pump", "Scarecrow", "Graves", "Graves", "Swings" },
		yardTrees = 6,
		layout = {
			style = "Yard",
			lane = 1,
			square = { 8, 4 },
			barriers = { "Hedge", "FencePicket" },
			fill = { 0.35, 0.55 },
			ground = { "BrokenRoad", "Deck", "Rubble" },
			groundCount = 8,
		},
		-- the village the school served: a row, the inn, cottages
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Inn", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, ToolChest = 1, Vault = 1 },
		},
	},
	Infirmary = {
		id = "Infirmary",
		name = "Brannoc Infirmary",
		tier = 2,
		minStation = 3,
		weight = 0.9,
		length = 456,
		depth = 396,
		dwellMultiplier = 1.0,
		hint = "Tonics, tools, a locked dispensary",
		loot = { coal = 0.9, parts = 1.0, relic = 1.1, tools = 1.8 },
		hazard = { collapse = 1.0, fog = 1.1, hollows = 1.1 },
		containers = { Crate = 7, CoalBin = 3, ToolChest = 3 },
		looseItems = 10,
		structures = {
			{ kind = "Chimney", count = 1, zones = { "Mid" } },
			{ kind = "Shed", count = 3, zones = { "Mid", "Far" } },
		},
		landmarks = {
			{ kind = "Clinic", zones = { "Mid" } },
			{ kind = "DoctorsHouse", zones = { "Near", "Mid" } },
			{ kind = "Mortuary", zones = { "Far" } },
			{ kind = "Laundry", zones = { "Mid", "Far" } },
		},
		lampSpacing = 30,
		ground = "Concrete",
		palette = {
			ground = { 140, 138, 130 },
			accent = { 92, 104, 96 },
			trim = { 62, 64, 62 },
			light = { 236, 240, 255 },
		},
		edge = { fence = "FenceIron", trees = { "Poplar", "Pine" }, treeChance = 0.7 },
		dressing = { "Puddle", "Barrels", "Pump", "Graves", "Well", "Graves" },
		yardTrees = 4,
		layout = {
			style = "Yard",
			lane = 1,
			square = { 7, 4 },
			barriers = { "FenceIron", "Wreck" },
			fill = { 0.35, 0.55 },
			ground = { "Trench", "Rubble", "Wreck" },
			groundCount = 8,
		},
		-- the edge of the town: a row, a shop, cottages
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "GeneralStore", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, ToolChest = 2, Vault = 1 },
		},
	},
	RailwayHotel = {
		id = "RailwayHotel",
		name = "Gallowmere Junction",
		tier = 3,
		minStation = 4,
		weight = 0.9,
		length = 480,
		depth = 408,
		dwellMultiplier = 1.0,
		hint = "Guest rooms and a coal cellar",
		loot = { coal = 1.4, parts = 1.0, relic = 1.6, tools = 1.0 },
		hazard = { collapse = 1.1, fog = 1.0, hollows = 1.25 },
		containers = { Crate = 7, CoalBin = 4, ToolChest = 2 },
		looseItems = 10,
		structures = {
			{ kind = "Bandstand", count = 1, zones = { "Mid" } },
			{ kind = "Gantry", count = 1, zones = { "Near" } },
			{ kind = "Fountain", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		landmarks = {
			{ kind = "Hotel", zones = { "Mid" } },
			{ kind = "CoachHouse", zones = { "Mid", "Far" } },
			{ kind = "Inn", zones = { "Near", "Mid" } },
			{ kind = "GeneralStore", zones = { "Near" } },
		},
		lampSpacing = 30,
		ground = "Brick",
		palette = {
			ground = { 140, 102, 84 },
			accent = { 52, 74, 60 },
			trim = { 70, 50, 42 },
			light = { 255, 196, 128 },
		},
		edge = { fence = "Hedge", trees = { "Oak", "Poplar" }, treeChance = 0.7 },
		dressing = { "Topiary", "Puddle", "Well", "Barrels", "Topiary", "Cart" },
		yardTrees = 4,
		layout = {
			style = "Plaza",
			lane = 1,
			square = { 7, 5 },
			centre = "Bandstand",
			barriers = { "Hedge" },
			fill = { 0.4, 0.6 },
			ground = { "BrokenRoad", "Rubble" },
			groundCount = 8,
		},
		-- the town behind the hotel: two rows and their cottages
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, CoalBin = 1, ToolChest = 1, Vault = 1 },
		},
	},
	PostTown = {
		id = "PostTown",
		name = "Wickham Cross",
		tier = 3,
		minStation = 5,
		weight = 0.9,
		length = 492,
		depth = 420,
		dwellMultiplier = 0.95,
		hint = "A strongroom full of relics",
		loot = { coal = 1.0, parts = 1.3, relic = 1.8, tools = 1.1 },
		hazard = { collapse = 1.1, fog = 1.15, hollows = 1.2 },
		containers = { Crate = 7, CoalBin = 3, ToolChest = 2 },
		looseItems = 10,
		structures = {
			{ kind = "ClockTower", count = 1, zones = { "Near", "Mid" } },
			{ kind = "Stall", count = 6, zones = { "Near", "Mid" } },
			{ kind = "Shed", count = 2, zones = { "Far" } },
		},
		landmarks = {
			{ kind = "PostOffice", zones = { "Mid" } },
			{ kind = "CountingHouse", zones = { "Near", "Mid" } },
			{ kind = "GeneralStore", zones = { "Near", "Mid", "Far" } },
			{ kind = "Inn", zones = { "Mid", "Far" } },
		},
		lampSpacing = 30,
		ground = "Cobblestone",
		palette = {
			ground = { 130, 120, 108 },
			accent = { 120, 40, 36 },
			trim = { 60, 54, 50 },
			light = { 255, 190, 120 },
		},
		edge = { fence = "WallStone", trees = { "Oak", "DeadTree" }, treeChance = 0.6 },
		dressing = { "PillarBox", "Cart", "Puddle", "Barrels", "Pump", "PillarBox" },
		yardTrees = 3,
		layout = {
			style = "Street",
			lane = 2,
			barriers = { "WallStone", "Wreck" },
			fill = { 0.4, 0.6 },
			ground = { "BrokenRoad", "Rubble", "Wreck" },
			groundCount = 8,
		},
		-- the terraces down both streets
		village = {
			rows = 7,
			landmarks = {
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "Terrace", zones = { "Village" } },
				{ kind = "House", zones = { "Village" } },
				{ kind = "House", zones = { "Village" }, decor = true },
			},
			containers = { Crate = 2, ToolChest = 1, Vault = 1 },
		},
	},
	-- Not a station: the hamlet by the line where a broken-down train halts (Services/BreakdownService,
	-- Difficulty.Breakdown Village*). Repair parts only (every other loot category weighs nothing), one
	-- lamp at the lane's end, the threat of the stop the train was heading for.
	EmergencyVillage = {
		id = "EmergencyVillage",
		name = "Emergency Village",
		tier = 1,
		minStation = 99,
		weight = 0,
		length = 384,
		depth = 312,
		dwellMultiplier = 1,
		hint = "Repair parts",
		loot = { coal = 0, parts = 1, relic = 0, tools = 0 },
		hazard = { collapse = 0.8, fog = 1.0, hollows = 1.0 },
		containers = { Crate = 8, ToolChest = 3 },
		looseItems = 8,
		structures = {
			{ kind = "Shed", count = 3, zones = { "Mid", "Far" } },
			{ kind = "WaterTower", count = 1, zones = { "Mid" } },
		},
		landmarks = {
			{ kind = "Smithy", zones = { "Near", "Mid" } },
			{ kind = "House", zones = { "Near", "Mid" } },
			{ kind = "Terrace", zones = { "Mid", "Far" } },
			{ kind = "House", zones = { "Far" } },
			{ kind = "CoachHouse", zones = { "Far" } },
		},
		lampSpacing = 48,
		ground = "Ground",
		palette = {
			ground = { 88, 80, 70 }, -- cinders and mud
			accent = { 110, 84, 60 },
			trim = { 44, 40, 36 },
			light = { 255, 186, 120 },
		},
		edge = { fence = "FenceRail", trees = { "DeadTree", "Pine", "DeadTree" }, treeChance = 0.7 },
		dressing = { "Haystack", "Cart", "Pump", "Well", "Wheelbarrow", "Puddle", "Scarecrow" },
		yardTrees = 4,
		layout = {
			style = "Street",
			lane = 1,
			barriers = { "FenceRail", "Wreck" },
			fill = { 0.35, 0.5 },
			ground = { "BrokenRoad", "Rubble", "Wreck" },
			groundCount = 6,
		},
		emergency = true,
		yardLamps = 1,
	},
	Terminus = {
		id = "Terminus",
		name = "Terminus",
		tier = 1,
		minStation = 99,
		weight = 0,
		length = 324,
		depth = 156,
		dwellMultiplier = 1,
		hint = "End of the line",
		loot = { coal = 0, parts = 0, relic = 0, tools = 0 },
		hazard = { collapse = 0, fog = 0, hollows = 0 },
		containers = {},
		looseItems = 0,
		structures = {
			{ kind = "Concourse", count = 1, zones = { "Mid" } },
		},
		lampSpacing = 24,
		ground = "Marble",
		palette = {
			ground = { 196, 186, 168 },
			accent = { 201, 160, 82 },
			trim = { 120, 104, 82 },
			light = { 255, 226, 170 },
		},
		edge = { fence = "FenceIron", trees = {}, treeChance = 0 },
		dressing = {},
		yardTrees = 0,
		terminus = true,
	},
}

-- Footprints in tiles (width along the track, depth away from it).
local Footprints: { [string]: { number } } = {
	StationHouse = { 3, 2 },
	Shed = { 2, 2 },
	WaterTower = { 2, 2 },
	CoalTower = { 2, 2 },
	CoalHeap = { 2, 2 },
	Hopper = { 1, 2 },
	Workshop = { 3, 3 },
	SignalBox = { 2, 2 },
	CableDrums = { 1, 1 },
	Stall = { 1, 1 },
	Fountain = { 2, 2 },
	Headframe = { 3, 3 },
	TunnelMouth = { 4, 2 },
	Concourse = { 6, 3 },
	CattleDock = { 3, 2 },
	Chimney = { 2, 2 },
	Gantry = { 3, 1 },
	ClockTower = { 2, 2 },
	Arches = { 4, 1 },
	Bandstand = { 2, 2 },
}

for _, def in Archetypes do
	table.freeze(def)
end

local CANOPY_HALF_SPAN = 72 -- the platform canopy reaches at most this far either side of the middle
local CANOPY_COLUMN_Z = 20.5 -- its columns stand at the back of the platform
local CANOPY_BAY = 24 -- between columns

-- Where the canopy's columns stand along the platform (x), for a canopy reaching `half` each way.
-- None stands within a bay of the middle, where the station's name board is.
local function canopyColumns(half: number): { number }
	local xs: { number } = {}
	local x = half - 6
	while x > 12 do
		table.insert(xs, x)
		table.insert(xs, -x)
		x -= CANOPY_BAY
	end
	return xs
end

return table.freeze({
	List = table.freeze(Archetypes),
	Footprints = table.freeze(Footprints),
	CanopyHalfSpan = CANOPY_HALF_SPAN,
	CanopyColumnZ = CANOPY_COLUMN_Z,
	canopyColumns = canopyColumns,
	EdgeInset = 0.8, -- the boundary stands this far in from the station edge
	-- Walking distances (Logic/StationReach) start from the platform within this far of the
	-- middle, where the train's doors are
	Reach = table.freeze({ DoorHalfSpan = 72 }),
	-- Lamp pools along the routes: at least PoolGap tiles apart, so darkness lies between them
	-- (Hollows rest there). Yard lamps are not SafeLights; the platform's lamps are.
	-- LitMax: lights on as the stop docks; StationBuilder turns off moonlit panes, then working
	-- room bulbs (a building's power wakes them) past it, whatever the seed.
	Lamps = table.freeze({ PoolGap = 4.5, YardMax = 14, LitMax = 64 }),
	VillageFill = 0.55, -- the share of the Far/Village boundary closed off
	-- The sinkhole edge (props EdgeMark on every open edge tile): an unseen stop RailBack in
	-- from the edge; TapeBack is the margin HollowService keeps its teaching Crawler inside.
	Edge = table.freeze({ RailBack = 4.5, TapeBack = 6.6 }),
	DressingCount = 6, -- things scattered round the yard
	-- How much likelier the better containers are to stand in the far zone, behind the last barrier
	FarLoot = table.freeze({ ToolChest = 2.5, Crate = 1.3 }),
	Order = table.freeze({
		"Halt",
		"CoalYard",
		"SignalWorks",
		"Market",
		"Viaduct",
		"Minehead",
		"Schoolhouse",
		"Infirmary",
		"RailwayHotel",
		"PostTown",
	}),
})
