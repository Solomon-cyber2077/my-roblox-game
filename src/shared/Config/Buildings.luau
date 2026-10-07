--!strict
--[[
	Enterable buildings at the stops: a school, a cottage hospital, a railway hotel,
	a sorting office and the smaller places every station has (booking office,
	boiler house, workshop, lamp room, chapel, goods shed, engine shed, shop).

	A building is a programme of rooms that Logic/BuildingGen lays out inside its
	footprint and furnishes. Containers are furniture you would expect in that room
	(a teacher's desk, a ward's bedside cabinet, the coal bunker by a boiler), each
	searched with an existing loot table (Config/Loot).

	Layouts
	  Spine  rooms either side of a corridor that runs the building's length, a foyer at
	         the front door and an exit at each end of the corridor
	  Hall   one big room at the front with a strip of small rooms along the back, the
	         back room with a door of its own out of the rear
	  Row    a single row of rooms opening into each other (small buildings), the end
	         rooms with doors out of their sides

	Back rooms (`back`) hold the better loot: Spine buildings put them in the row behind
	the corridor, and each one keeps at least one container from BackLoot.

	Upper floors (`upper`, the largest Spine buildings only) stand over the back row. A
	stairwell at the west end of that row climbs to them on one ramp; the upper rooms
	open into each other in a row, and the far one has a broken window low enough to
	climb out of, so there is always a second way down.

	Placement patterns (Logic/BuildingGen)
	  wall    against a wall: far (opposite the door), near, sides, long or any
	  grid    rows across the floor, facing the far wall (desks, pews, beds)
	  center  one in the middle of the room
	  corner  one in a corner away from the door
]]

export type Placement = {
	pattern: string,
	item: string,
	wall: string?,
	count: number?,
	gap: number?, -- studs between neighbours (wall, grid)
	container: string?, -- loot kind (Config/Loot) when the piece can be searched
	share: number?, -- share of the placed pieces that are containers (default all)
}

export type Room = {
	label: string,
	place: { Placement },
	lamp: number, -- chance its lamp still works
	sleeper: number, -- chance a Hollow sleeps in it
	sleeperKind: string?,
	locked: number?, -- chance its door is locked (forced open with parts)
	rug: { number }?,
	back: boolean?, -- a back room: better loot, laid out behind the corridor
}

export type Upper = {
	rooms: { string }, -- in order, west to east, after the stairwell
	height: number, -- the upper storey's ceiling height
	tiles: number, -- the floor area in tiles, for the stop's size (Logic/DifficultyModel)
}

export type Building = {
	name: string,
	size: { number }, -- footprint in tiles: along the track, away from it
	layout: string,
	height: number,
	wall: { number },
	trim: { number },
	roof: { number },
	floor: { number },
	wallMaterial: string,
	floorMaterial: string,
	roofMaterial: string,
	roofStyle: string, -- Pitched or Flat
	front: string, -- the room behind the front door
	rooms: { string }, -- the others, in order (repeated when there are more spaces)
	corridor: { Placement }?,
	upper: Upper?,
}

export type Furniture = { w: number, d: number, name: string }

local Rooms: { [string]: Room } = {
	Foyer = {
		label = "Entrance Hall",
		place = {
			{ pattern = "wall", item = "Counter", wall = "sides", count = 1, container = "Locker" },
			{ pattern = "wall", item = "Bench", wall = "sides", count = 2, gap = 2 },
			{ pattern = "wall", item = "NoticeBoard", wall = "near", count = 2, gap = 3 },
		},
		lamp = 0.5,
		sleeper = 0.1,
		rug = { 104, 40, 38 },
	},
	Classroom = {
		label = "Classroom",
		place = {
			{ pattern = "wall", item = "Chalkboard", wall = "far", count = 1 },
			{ pattern = "wall", item = "TeacherDesk", wall = "far", count = 1, container = "Locker" },
			{ pattern = "corner", item = "Cupboard", container = "Locker" },
			{ pattern = "grid", item = "SchoolDesk", gap = 2.6, container = "Crate", share = 0.2 },
		},
		lamp = 0.25,
		sleeper = 0.35,
	},
	BoilerRoom = {
		label = "Boiler Room",
		place = {
			{ pattern = "wall", item = "Boiler", wall = "far", count = 1 },
			{
				pattern = "wall",
				item = "CoalBunker",
				wall = "sides",
				count = 2,
				gap = 2,
				container = "CoalBin",
			},
			{ pattern = "corner", item = "CoalHeap" },
		},
		lamp = 0.7,
		sleeper = 0.5,
		sleeperKind = "Brute",
	},
	StaffRoom = {
		label = "Staff Room",
		place = {
			{ pattern = "center", item = "Table" },
			{ pattern = "wall", item = "Cupboard", wall = "far", count = 2, gap = 2, container = "Locker" },
			{ pattern = "wall", item = "Stove", wall = "sides", count = 1 },
		},
		lamp = 0.3,
		sleeper = 0.25,
		rug = { 60, 70, 92 },
		back = true,
	},
	Library = {
		label = "Library",
		place = {
			{
				pattern = "wall",
				item = "Bookshelf",
				wall = "any",
				gap = 0.6,
				container = "Crate",
				share = 0.35,
			},
			{ pattern = "center", item = "Table" },
		},
		lamp = 0.3,
		sleeper = 0.3,
		rug = { 92, 40, 36 },
	},
	Cloakroom = {
		label = "Cloakroom",
		place = {
			{ pattern = "wall", item = "Bench", wall = "long", count = 2, gap = 3 },
			{
				pattern = "wall",
				item = "SchoolLocker",
				wall = "far",
				gap = 0.3,
				container = "Locker",
				share = 0.5,
			},
		},
		lamp = 0.4,
		sleeper = 0.3,
		sleeperKind = "Crawler",
	},
	Ward = {
		label = "Ward",
		place = {
			{ pattern = "wall", item = "Bed", wall = "long", gap = 3.2 },
			{ pattern = "wall", item = "Bedside", wall = "far", count = 2, gap = 4, container = "Crate" },
			{ pattern = "center", item = "Trolley", container = "ToolChest" },
		},
		lamp = 0.3,
		sleeper = 0.45,
		sleeperKind = "Crawler",
	},
	Pharmacy = {
		label = "Dispensary",
		place = {
			{
				pattern = "wall",
				item = "MedicineCabinet",
				wall = "any",
				gap = 0.8,
				container = "ToolChest",
				share = 0.6,
			},
			{ pattern = "center", item = "Table" },
		},
		lamp = 0.2,
		sleeper = 0.2,
		locked = 0.7,
		back = true,
	},
	Office = {
		label = "Office",
		place = {
			{ pattern = "wall", item = "Desk", wall = "far", count = 1, container = "Locker" },
			{
				pattern = "wall",
				item = "FilingCabinet",
				wall = "sides",
				count = 3,
				gap = 0.4,
				container = "Locker",
				share = 0.5,
			},
			{ pattern = "corner", item = "Safe", container = "Vault" },
		},
		lamp = 0.35,
		sleeper = 0.2,
		locked = 0.35,
		rug = { 70, 50, 40 },
		back = true,
	},
	Kitchen = {
		label = "Kitchen",
		place = {
			{ pattern = "wall", item = "Range", wall = "far", count = 1, container = "CoalBin" },
			{ pattern = "wall", item = "Pantry", wall = "sides", count = 2, gap = 1, container = "Crate" },
			{ pattern = "center", item = "Table" },
		},
		lamp = 0.4,
		sleeper = 0.3,
	},
	Bedroom = {
		label = "Guest Room",
		place = {
			{ pattern = "wall", item = "Bed", wall = "far", count = 1 },
			{ pattern = "wall", item = "Wardrobe", wall = "sides", count = 1, container = "Locker" },
			{ pattern = "corner", item = "Trunk", container = "Crate" },
		},
		lamp = 0.25,
		sleeper = 0.4,
		rug = { 112, 60, 48 },
	},
	Cellar = {
		label = "Coal Cellar",
		place = {
			{
				pattern = "wall",
				item = "CoalBunker",
				wall = "any",
				count = 3,
				gap = 1.5,
				container = "CoalBin",
			},
			{ pattern = "corner", item = "Trunk", container = "ToolChest" },
			{ pattern = "corner", item = "Barrels" },
		},
		lamp = 0.2,
		sleeper = 0.5,
		sleeperKind = "Brute",
		locked = 0.6,
		back = true,
	},
	Counter = {
		label = "Post Office",
		place = {
			{
				pattern = "wall",
				item = "Counter",
				wall = "far",
				count = 2,
				container = "Locker",
				share = 0.5,
			},
			{ pattern = "wall", item = "Bench", wall = "sides", count = 2, gap = 2 },
			{ pattern = "wall", item = "NoticeBoard", wall = "near", count = 2, gap = 3 },
		},
		lamp = 0.5,
		sleeper = 0.1,
		rug = { 72, 60, 50 },
	},
	SortingRoom = {
		label = "Sorting Room",
		place = {
			{ pattern = "wall", item = "Pigeonholes", wall = "long", gap = 0.6 },
			{ pattern = "grid", item = "MailSacks", gap = 5, container = "Crate", share = 0.5 },
		},
		lamp = 0.3,
		sleeper = 0.35,
	},
	Strongroom = {
		label = "Strongroom",
		place = {
			{ pattern = "wall", item = "Safe", wall = "far", count = 2, gap = 2, container = "Vault" },
			{ pattern = "wall", item = "Shelving", wall = "sides", count = 1, container = "Crate" },
		},
		lamp = 0.1,
		sleeper = 0.15,
		locked = 1,
		back = true,
	},
	Nave = {
		label = "Nave",
		place = {
			{ pattern = "wall", item = "Altar", wall = "far", count = 1 },
			{ pattern = "grid", item = "Pew", gap = 2.2 },
			{ pattern = "corner", item = "PoorBox", container = "Crate" },
		},
		lamp = 0.5,
		sleeper = 0.5,
	},
	Vestry = {
		label = "Vestry",
		place = {
			{ pattern = "wall", item = "Wardrobe", wall = "far", count = 1, container = "Locker" },
			{ pattern = "corner", item = "Trunk", container = "ToolChest" },
		},
		lamp = 0.2,
		sleeper = 0.3,
		back = true,
	},
	StoreHall = {
		label = "Goods Shed",
		place = {
			{ pattern = "grid", item = "Shelving", gap = 5, container = "Crate", share = 0.35 },
			{ pattern = "corner", item = "Crates" },
		},
		lamp = 0.35,
		sleeper = 0.5,
	},
	CoalStore = {
		label = "Coal Store",
		place = {
			{
				pattern = "wall",
				item = "CoalBunker",
				wall = "any",
				count = 3,
				gap = 1.5,
				container = "CoalBin",
			},
			{ pattern = "corner", item = "CoalHeap" },
		},
		lamp = 0.2,
		sleeper = 0.3,
		sleeperKind = "Brute",
		locked = 0.6,
	},
	BoilerHall = {
		label = "Boiler House",
		place = {
			{ pattern = "wall", item = "Boiler", wall = "far", count = 2, gap = 4 },
			{
				pattern = "wall",
				item = "CoalBunker",
				wall = "sides",
				count = 2,
				gap = 2,
				container = "CoalBin",
			},
			{ pattern = "corner", item = "CoalHeap" },
		},
		lamp = 0.7,
		sleeper = 0.4,
		sleeperKind = "Brute",
	},
	WaitingRoom = {
		label = "Waiting Room",
		place = {
			{ pattern = "wall", item = "Bench", wall = "sides", count = 2, gap = 2 },
			{ pattern = "wall", item = "Stove", wall = "far", count = 1 },
			{ pattern = "wall", item = "NoticeBoard", wall = "near", count = 2, gap = 3 },
		},
		lamp = 0.5,
		sleeper = 0.15,
		rug = { 96, 44, 40 },
	},
	BookingOffice = {
		label = "Booking Office",
		place = {
			{ pattern = "wall", item = "Counter", wall = "far", count = 1, container = "Locker" },
			{ pattern = "corner", item = "Safe", container = "Vault" },
		},
		lamp = 0.4,
		sleeper = 0.2,
		locked = 0.4,
		back = true,
	},
	Parcels = {
		label = "Parcels Office",
		place = {
			{
				pattern = "wall",
				item = "Shelving",
				wall = "far",
				count = 2,
				gap = 1,
				container = "Crate",
				share = 0.5,
			},
			{ pattern = "corner", item = "Crates" },
			{ pattern = "corner", item = "Trunk", container = "Crate" },
		},
		lamp = 0.3,
		sleeper = 0.25,
	},
	WorkHall = {
		label = "Workshop",
		place = {
			{
				pattern = "wall",
				item = "Workbench",
				wall = "long",
				gap = 2,
				container = "ToolChest",
				share = 0.5,
			},
			{ pattern = "center", item = "Lathe" },
			{ pattern = "corner", item = "Crates" },
		},
		lamp = 0.45,
		sleeper = 0.4,
	},
	Store = {
		label = "Stores",
		place = {
			{
				pattern = "wall",
				item = "Shelving",
				wall = "any",
				count = 3,
				gap = 1,
				container = "Crate",
				share = 0.6,
			},
			{ pattern = "corner", item = "Trunk", container = "ToolChest" },
			{ pattern = "corner", item = "Barrels" },
		},
		lamp = 0.2,
		sleeper = 0.3,
		locked = 0.5,
		back = true,
	},
	LampHall = {
		label = "Lamp Room",
		place = {
			{ pattern = "wall", item = "LampRack", wall = "long", gap = 1 },
			{ pattern = "wall", item = "Workbench", wall = "far", count = 1, container = "ToolChest" },
			{ pattern = "center", item = "Table" },
		},
		lamp = 0.5,
		sleeper = 0.4,
	},
	Baths = {
		label = "Pithead Baths",
		place = {
			{
				pattern = "wall",
				item = "SchoolLocker",
				wall = "long",
				gap = 0.3,
				container = "Locker",
				share = 0.35,
			},
			{ pattern = "center", item = "Bench" },
		},
		lamp = 0.3,
		sleeper = 0.4,
		sleeperKind = "Crawler",
	},
	Shop = {
		label = "General Store",
		place = {
			{ pattern = "wall", item = "Counter", wall = "far", count = 1, container = "Locker" },
			{
				pattern = "wall",
				item = "ShopShelf",
				wall = "sides",
				gap = 0.6,
				container = "Crate",
				share = 0.4,
			},
			{ pattern = "corner", item = "Barrels" },
		},
		lamp = 0.45,
		sleeper = 0.3,
		rug = { 84, 66, 48 },
	},
	BackStore = {
		label = "Back Store",
		place = {
			{ pattern = "wall", item = "Shelving", wall = "any", count = 2, gap = 1, container = "Crate" },
			{ pattern = "corner", item = "Trunk", container = "ToolChest" },
			{ pattern = "corner", item = "CoalHeap" },
		},
		lamp = 0.2,
		sleeper = 0.3,
		locked = 0.5,
		back = true,
	},
	Stairwell = {
		label = "Stairwell",
		place = {
			{ pattern = "wall", item = "Bench", wall = "sides", count = 1 },
			{ pattern = "corner", item = "Trunk", container = "Crate" },
		},
		lamp = 0.5,
		sleeper = 0,
	},
	Parlour = {
		label = "Parlour",
		place = {
			{ pattern = "wall", item = "Stove", wall = "far", count = 1 },
			{
				pattern = "wall",
				item = "Bookshelf",
				wall = "sides",
				count = 2,
				gap = 1,
				container = "Crate",
				share = 0.5,
			},
			{ pattern = "center", item = "Table" },
		},
		lamp = 0.4,
		sleeper = 0.2,
		rug = { 100, 54, 44 },
	},
}

local Corridors: { [string]: { Placement } } = {
	Lockers = {
		{
			pattern = "wall",
			item = "SchoolLocker",
			wall = "long",
			gap = 0.3,
			container = "Locker",
			share = 0.18,
		},
	},
	Benches = {
		{ pattern = "wall", item = "Bench", wall = "long", gap = 9 },
	},
	Plain = {},
}

local Defs: { [string]: Building } = {
	School = {
		name = "Ashgrove Board School",
		size = { 7, 4 },
		layout = "Spine",
		height = 13,
		wall = { 146, 84, 62 },
		trim = { 214, 204, 184 },
		roof = { 62, 66, 76 },
		floor = { 124, 92, 62 },
		wallMaterial = "Brick",
		floorMaterial = "WoodPlanks",
		roofMaterial = "Slate",
		roofStyle = "Pitched",
		front = "Foyer",
		rooms = { "Classroom", "BoilerRoom", "Classroom", "StaffRoom", "Library", "Classroom", "Cloakroom" },
		corridor = Corridors.Lockers,
		upper = { rooms = { "Library", "StaffRoom", "Classroom" }, height = 11, tiles = 8 },
	},
	Clinic = {
		name = "St. Brannoc's Cottage Hospital",
		size = { 6, 4 },
		layout = "Spine",
		height = 12,
		wall = { 204, 198, 184 },
		trim = { 92, 104, 96 },
		roof = { 70, 72, 80 },
		floor = { 176, 170, 158 },
		wallMaterial = "Plaster",
		floorMaterial = "Marble",
		roofMaterial = "Slate",
		roofStyle = "Pitched",
		front = "Foyer",
		rooms = { "Ward", "Pharmacy", "Ward", "Office", "BoilerRoom", "Ward" },
		corridor = Corridors.Benches,
		upper = { rooms = { "Ward", "Pharmacy", "Ward" }, height = 10, tiles = 6 },
	},
	Hotel = {
		name = "The Railway Hotel",
		size = { 6, 4 },
		layout = "Spine",
		height = 13,
		wall = { 196, 174, 136 },
		trim = { 52, 74, 60 },
		roof = { 128, 64, 50 },
		floor = { 104, 72, 50 },
		wallMaterial = "Plaster",
		floorMaterial = "WoodPlanks",
		roofMaterial = "ClayRoofTiles",
		roofStyle = "Pitched",
		front = "Foyer",
		rooms = { "Kitchen", "Bedroom", "Bedroom", "Cellar", "Bedroom", "Office" },
		corridor = Corridors.Plain,
		upper = { rooms = { "Bedroom", "Bedroom", "Office" }, height = 10, tiles = 6 },
	},
	PostOffice = {
		name = "Sorting Office",
		size = { 5, 4 },
		layout = "Spine",
		height = 12,
		wall = { 178, 150, 104 },
		trim = { 120, 40, 36 },
		roof = { 66, 64, 70 },
		floor = { 118, 98, 74 },
		wallMaterial = "Brick",
		floorMaterial = "WoodPlanks",
		roofMaterial = "Slate",
		roofStyle = "Flat",
		front = "Counter",
		rooms = { "SortingRoom", "Strongroom", "Office", "SortingRoom" },
		corridor = Corridors.Plain,
	},
	Chapel = {
		name = "Chapel of the Line",
		size = { 3, 4 },
		layout = "Hall",
		height = 15,
		wall = { 150, 146, 136 },
		trim = { 196, 190, 176 },
		roof = { 58, 60, 68 },
		floor = { 132, 126, 116 },
		wallMaterial = "Limestone",
		floorMaterial = "Slate",
		roofMaterial = "Slate",
		roofStyle = "Pitched",
		front = "Nave",
		rooms = { "Vestry" },
	},
	GoodsShed = {
		name = "Goods Shed",
		size = { 6, 3 },
		layout = "Hall",
		height = 14,
		wall = { 98, 76, 54 },
		trim = { 64, 48, 36 },
		roof = { 92, 86, 80 },
		floor = { 96, 90, 84 },
		wallMaterial = "WoodPlanks",
		floorMaterial = "Concrete",
		roofMaterial = "CorrodedMetal",
		roofStyle = "Pitched",
		front = "StoreHall",
		rooms = { "Office", "CoalStore" },
	},
	BoilerHouse = {
		name = "Boiler House",
		size = { 3, 3 },
		layout = "Hall",
		height = 14,
		wall = { 112, 66, 52 },
		trim = { 60, 52, 48 },
		roof = { 60, 58, 60 },
		floor = { 84, 80, 76 },
		wallMaterial = "Brick",
		floorMaterial = "Concrete",
		roofMaterial = "CorrodedMetal",
		roofStyle = "Flat",
		front = "BoilerHall",
		rooms = { "CoalStore" },
	},
	BookingHall = {
		name = "Booking Hall",
		size = { 3, 2 },
		layout = "Row",
		height = 12,
		wall = { 150, 110, 76 },
		trim = { 230, 220, 196 },
		roof = { 70, 70, 78 },
		floor = { 116, 86, 60 },
		wallMaterial = "Brick",
		floorMaterial = "WoodPlanks",
		roofMaterial = "Slate",
		roofStyle = "Pitched",
		front = "WaitingRoom",
		rooms = { "BookingOffice", "Parcels" },
	},
	Workshop = {
		name = "Signal Workshop",
		size = { 4, 3 },
		layout = "Hall",
		height = 14,
		wall = { 132, 128, 120 },
		trim = { 168, 54, 42 },
		roof = { 70, 72, 76 },
		floor = { 96, 94, 90 },
		wallMaterial = "Concrete",
		floorMaterial = "Concrete",
		roofMaterial = "CorrodedMetal",
		roofStyle = "Pitched",
		front = "WorkHall",
		rooms = { "Store" },
	},
	LampRoom = {
		name = "Lamp Room & Baths",
		size = { 4, 3 },
		layout = "Hall",
		height = 13,
		wall = { 120, 100, 80 },
		trim = { 60, 50, 40 },
		roof = { 66, 60, 56 },
		floor = { 92, 84, 76 },
		wallMaterial = "Brick",
		floorMaterial = "Concrete",
		roofMaterial = "CorrodedMetal",
		roofStyle = "Flat",
		front = "LampHall",
		rooms = { "Baths", "CoalStore" },
	},
	House = {
		name = "Station Cottage",
		size = { 3, 2 },
		layout = "Row",
		height = 11,
		wall = { 168, 150, 128 },
		trim = { 70, 52, 40 },
		roof = { 74, 70, 72 },
		floor = { 110, 82, 58 },
		wallMaterial = "Brick",
		floorMaterial = "WoodPlanks",
		roofMaterial = "Slate",
		roofStyle = "Pitched",
		front = "Parlour",
		rooms = { "Kitchen", "Bedroom" },
	},
	EngineShed = {
		name = "Engine Shed",
		size = { 5, 3 },
		layout = "Hall",
		height = 15,
		wall = { 84, 64, 54 }, -- soot-blackened brick
		trim = { 40, 38, 38 },
		roof = { 64, 60, 58 },
		floor = { 70, 66, 62 },
		wallMaterial = "Brick",
		floorMaterial = "Concrete",
		roofMaterial = "CorrodedMetal",
		roofStyle = "Pitched",
		front = "WorkHall",
		rooms = { "CoalStore", "Store" },
	},
	GeneralStore = {
		name = "General Store",
		size = { 3, 3 },
		layout = "Hall",
		height = 12,
		wall = { 162, 120, 84 },
		trim = { 46, 70, 64 },
		roof = { 110, 56, 46 },
		floor = { 112, 84, 58 },
		wallMaterial = "WoodPlanks",
		floorMaterial = "WoodPlanks",
		roofMaterial = "ClayRoofTiles",
		roofStyle = "Pitched",
		front = "Shop",
		rooms = { "BackStore" },
	},
}

-- Footprints (studs) and the names the search prompt shows.
local Furniture: { [string]: Furniture } = {
	Counter = { w = 7, d = 2.4, name = "Counter Drawers" },
	Bench = { w = 6, d = 1.8, name = "Bench" },
	NoticeBoard = { w = 4, d = 0.5, name = "Notice Board" },
	Chalkboard = { w = 9, d = 0.5, name = "Chalkboard" },
	TeacherDesk = { w = 5, d = 2.6, name = "Teacher's Desk" },
	Cupboard = { w = 3.4, d = 1.8, name = "Cupboard" },
	SchoolDesk = { w = 3, d = 2.2, name = "School Desk" },
	Boiler = { w = 7, d = 5, name = "Boiler" },
	CoalBunker = { w = 4.5, d = 3.2, name = "Coal Bunker" },
	CoalHeap = { w = 4, d = 4, name = "Coal Heap" },
	Table = { w = 6, d = 3.4, name = "Table" },
	Stove = { w = 3, d = 2.6, name = "Stove" },
	Bookshelf = { w = 4, d = 1.4, name = "Bookshelf" },
	SchoolLocker = { w = 1.8, d = 1.6, name = "Locker" },
	Bed = { w = 3.4, d = 7, name = "Bed" },
	Bedside = { w = 1.8, d = 1.6, name = "Bedside Cabinet" },
	Trolley = { w = 3.4, d = 2, name = "Medicine Trolley" },
	MedicineCabinet = { w = 3, d = 1.4, name = "Medicine Cabinet" },
	Desk = { w = 5, d = 2.6, name = "Desk" },
	FilingCabinet = { w = 2, d = 2.2, name = "Filing Cabinet" },
	Safe = { w = 2.8, d = 2.6, name = "Safe" },
	Range = { w = 6, d = 2.8, name = "Kitchen Range" },
	Pantry = { w = 4, d = 1.6, name = "Pantry Shelves" },
	Wardrobe = { w = 3.8, d = 2, name = "Wardrobe" },
	Trunk = { w = 3, d = 1.8, name = "Travelling Trunk" },
	Barrels = { w = 4, d = 4, name = "Barrels" },
	Pigeonholes = { w = 4, d = 1.2, name = "Pigeonholes" },
	MailSacks = { w = 3.4, d = 3, name = "Mail Sacks" },
	Shelving = { w = 5, d = 2, name = "Shelving" },
	Altar = { w = 6, d = 2.6, name = "Altar" },
	Pew = { w = 8, d = 2.2, name = "Pew" },
	PoorBox = { w = 1.6, d = 1.6, name = "Poor Box" },
	Crates = { w = 4, d = 4, name = "Crates" },
	Workbench = { w = 6, d = 2.6, name = "Workbench" },
	Lathe = { w = 6, d = 2.6, name = "Lathe" },
	LampRack = { w = 4, d = 1.2, name = "Lamp Rack" },
	ShopShelf = { w = 4, d = 1.6, name = "Shop Shelves" },
	Lantern = { w = 1.4, d = 1.4, name = "Lantern" },
	-- the stairwell's ramp (BuildingBuilder draws it), wide enough for Hollows to path up
	Stairs = { w = 22, d = 6.2, name = "Stairs" },
}

for _, room in Rooms do
	for _, placement in room.place do
		table.freeze(placement)
	end
	table.freeze(room.place)
	table.freeze(room)
end
for _, def in Defs do
	table.freeze(def)
end

local Buildings = {
	Defs = table.freeze(Defs),
	Rooms = table.freeze(Rooms),
	Furniture = table.freeze(Furniture),

	Wall = 1, -- exterior wall thickness
	Partition = 0.8, -- interior wall thickness
	Inset = 0.6, -- exterior walls stand this far inside the foundation's edge
	CorridorWidth = 8,
	DoorWidth = 6,
	FrontDoorWidth = 7,
	DoorHeight = 9,
	WindowSill = 3.4,
	WindowTop = 8,
	WindowWidth = 4,
	WindowEvery = 11, -- studs of exterior wall per window
	DoorClearance = 6, -- studs kept clear in front of every door
	Aisle = 6, -- studs kept clear between rows of furniture on facing walls
	StairwellWidth = 24, -- along the back row; the ramp runs its length against the back wall
	EscapeSill = 1.4, -- the upper floor's way out: a broken window this low
	EscapeTop = 8.6,
	MoonLights = 2, -- at most this many dead rooms per building lit through a broken window
	BackLoot = { ToolChest = true, Vault = true } :: { [string]: boolean }, -- what makes a back room worth the trip
	PowerCost = 1, -- parts to restore a building's power
	ForceCost = 1, -- parts to force a locked door
	PowerHold = 2.5,
	ForceHold = 2,
}

return table.freeze(Buildings)
