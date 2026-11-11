--!strict
--[[
	The Depot's passive people: travellers and well-wishers who wait in the hall while the Hands
	come and go. They are not residents (Config/Npcs): no quests, no Talk prompt, no save. Each
	walks between the hall's spots, takes a bench seat for a while, stands about, or turns to a
	Hand nearby, waves and says the next of its three lines (Logic/Passenger picks; Services/
	PassengerService acts; Controllers/PassengerController shows the bubbles).

	Spots are in hall space (Builders/LobbyBuilder: +X along the platform, +Z from the track to
	the back wall, y = 0 the platform). `links` are the straight walks between spots that stay
	clear of everything solid and of `keepOut`: the boarding edge, the spawn ring, the departure
	board, the Outfitter and Ledger fronts and the back door. The visual audit rebuilds the hall
	and fails any spot or link that is not (target Passengers/Hall).

	Dress is the shared period kit (Config/Outfits, built by Builders/OutfitKit), worn on an R6
	body so every client walks, seats and turns them like the crew (Controllers/CharacterAnimator).
]]

local Outfits = require(script.Parent.Outfits)

export type Spot = { x: number, z: number }
export type Box = { x0: number, z0: number, x1: number, z1: number }
export type Space = {
	spots: { Spot },
	links: { { number } }, -- pairs of spot indices
	keepOut: { Box },
	count: number, -- people built
	performance: number, -- of those, how many a client under the Performance setting keeps
	seatName: string, -- the Seats (LobbyBuilder SeatName) they may take
	seen: { number }, -- spots in view from the spawn ring: half of all walks end at one of them
}
export type Person = { id: string, look: Outfits.Look, lines: { string } }

local Passengers = {}

Passengers.Hall = table.freeze({
	spots = {
		-- row A, along the platform clear of the edge
		{ x = -96, z = 0 }, -- 1
		{ x = -60, z = 0 }, -- 2
		{ x = -20, z = 0 }, -- 3
		{ x = 20, z = 0 }, -- 4
		{ x = 60, z = 0 }, -- 5
		{ x = 96, z = 0 }, -- 6
		-- row B, either side of the spawn ring
		{ x = -96, z = 18 }, -- 7
		{ x = -60, z = 18 }, -- 8
		{ x = -28, z = 18 }, -- 9
		{ x = 28, z = 18 }, -- 10
		{ x = 60, z = 18 }, -- 11
		{ x = 96, z = 18 }, -- 12
		-- row C, between the Ledger and the Outfitter
		{ x = -96, z = 30 }, -- 13
		{ x = -28, z = 30 }, -- 14
		{ x = 28, z = 30 }, -- 15
		{ x = 96, z = 30 }, -- 16
		-- row E, by the back benches
		{ x = -96, z = 58 }, -- 17
		{ x = -60, z = 58 }, -- 18
		{ x = -30, z = 58 }, -- 19
		{ x = 30, z = 58 }, -- 20
		{ x = 60, z = 58 }, -- 21
		{ x = 96, z = 58 }, -- 22
		-- row D, the corridor between the lamp row and the back benches
		{ x = -46, z = 47.5 }, -- 23
		{ x = -20, z = 47.5 }, -- 24
		{ x = 20, z = 47.5 }, -- 25
		{ x = 46, z = 47.5 }, -- 26
	},
	links = {
		{ 1, 2 },
		{ 2, 3 },
		{ 3, 4 },
		{ 4, 5 },
		{ 5, 6 },
		{ 7, 8 },
		{ 8, 9 },
		{ 10, 11 },
		{ 11, 12 },
		{ 1, 7 },
		{ 2, 8 },
		{ 5, 11 },
		{ 6, 12 },
		{ 7, 13 },
		{ 9, 14 },
		{ 10, 15 },
		{ 12, 16 },
		{ 17, 18 },
		{ 18, 19 },
		{ 20, 21 },
		{ 21, 22 },
		{ 23, 24 },
		{ 24, 25 },
		{ 25, 26 },
		{ 14, 24 },
		{ 15, 25 },
		{ 23, 18 },
		{ 26, 21 },
	},
	keepOut = {
		{ x0 = -112, z0 = -24, x1 = 112, z1 = -6 }, -- the boarding edge and its lamp row
		{ x0 = -14, z0 = 10, x1 = 14, z1 = 38 }, -- the spawn ring
		{ x0 = -26, z0 = 56, x1 = 26, z1 = 72 }, -- the departure board and the piano
		{ x0 = 42, z0 = 22, x1 = 72, z1 = 42 }, -- in front of the Outfitter
		{ x0 = -68, z0 = 26, x1 = -38, z1 = 44 }, -- in front of the Ledger
		{ x0 = 24, z0 = 62, x1 = 48, z1 = 72 }, -- the back door
	},
	count = 6,
	performance = 3,
	seatName = "Bench",
	seen = { 14, 15, 19, 20, 24, 25 }, -- between the Ledger and Outfitter, by the back benches, the corridor
} :: Space)

Passengers.Walk = table.freeze({
	speed = 5, -- studs per second: a stroll (the crew walk at 16)
	clearance = 1.4, -- studs a walk keeps from anything solid or kept out (half a body and a little)
	idle = { 4, 11 }, -- seconds standing about at a spot
	sit = { 18, 40 }, -- seconds on a bench
	maxSitting = 2, -- at once, and never two on one bench
	stepTimeout = 12, -- seconds a single walk may take before it is given up
	greetRadius = 12, -- a Hand this close may be greeted
	greetCooldown = 50, -- seconds before the same person greets the same Hand again
	greetChance = 0.7, -- of greeting when a Hand is near and the cooldown allows
	waveSeconds = 2.2,
	quietRadius = 160, -- with no Hand this close to the hall, everyone stands still
	weights = { wander = 4, sit = 2, idle = 3 },
	personalSpace = 3.5, -- studs a walker keeps from anyone ahead (it waits), and a greeter from anyone near
	waitAhead = 4, -- seconds a walker waits for the way to clear before going on regardless
	sidestep = 2.4, -- studs a walker steps to its right to pass someone still in the way after waiting
	greetGap = 5, -- seconds between any two greetings in the hall: one speech bubble at a time
})

-- What a client shows when one of them speaks.
Passengers.Bubble = table.freeze({
	seconds = 4.5,
	hear = 26, -- studs from your character within which you see it
})

local PEWTER = { 120, 116, 108 }
local LINEN = { 226, 220, 206 }

Passengers.People = table.freeze({
	{
		id = "Clerk",
		look = {
			skin = { 230, 192, 160 },
			hair = { 70, 52, 40 },
			cut = "Sack",
			coat = { 64, 60, 56 },
			trim = PEWTER,
			waistcoat = { 96, 84, 66 },
			neck = { 40, 44, 70 },
			lower = { 54, 52, 50 },
			hat = "Bowler",
			hatColor = { 30, 28, 28 },
			prop = "Ledger",
		},
		lines = {
			"Evening. They're really sending her out again tonight?",
			"Whatever coal you lot bring back keeps my stove lit. Bless you for it.",
			"Keep to the lamps, Hand. Everyone says it, so it must be true.",
		},
	},
	{
		id = "Mother",
		look = {
			hairStyle = "Bun",
			skin = { 236, 204, 178 },
			hair = { 98, 66, 46 },
			cut = "Bodice",
			coat = { 70, 40, 50 },
			trim = { 196, 170, 120 },
			lower = { 62, 36, 44 },
			skirt = "Bustle",
			hat = "Bonnet",
			hatColor = { 52, 30, 36 },
			prop = "Reticule",
		},
		lines = {
			"My boy went out on the Relief. Have you seen him? Tall, red scarf.",
			"They say the far lines are lit up like Christmas. They say a lot of things.",
			"Bring him home if you find him. I'll wait right here.",
		},
	},
	{
		id = "Gentleman",
		look = {
			skin = { 222, 182, 150 },
			hair = { 150, 146, 140 },
			whiskers = "Full",
			cut = "Frock",
			coat = { 30, 32, 36 },
			trim = { 196, 160, 90 },
			waistcoat = { 110, 26, 30 },
			neck = LINEN,
			lower = { 44, 42, 46 },
			hat = "Top",
			hatColor = { 22, 22, 24 },
			prop = "Cane",
		},
		lines = {
			"I hold shares in this line. I should like to know where my coal has gone.",
			"In my day the trains ran on time and nothing walked the dark.",
			"Good luck, young Hand. Do mind the Company's property.",
		},
	},
	{
		id = "Porter",
		look = {
			whiskers = "Curtain",
			skin = { 196, 150, 118 },
			hair = { 40, 32, 28 },
			cut = "Reefer",
			coat = { 30, 40, 62 },
			trim = { 180, 148, 88 },
			lower = { 34, 38, 52 },
			hat = "Peaked",
			hatColor = { 26, 32, 48 },
			prop = "Post",
		},
		lines = {
			"Mind your backs! Coming through with the Company's post.",
			"Twenty years on this platform. Never seen fog like it.",
			"Board's up. Don't keep the driver waiting, he won't wait long.",
		},
	},
	{
		id = "Widow",
		look = {
			skin = { 226, 200, 184 },
			hair = { 200, 196, 190 },
			hairStyle = "Bun",
			cut = "Bodice",
			coat = { 22, 20, 24 },
			trim = { 90, 86, 84 },
			lower = { 20, 18, 22 },
			skirt = "Plain",
			-- no lace cap: its flat disc sat on the sculpted bun like a stray plate (owner, 11-10)
			prop = "Hanky",
		},
		lines = {
			"I come every evening. They tell me he isn't coming back. I come anyway.",
			"Listen. You can hear the line humming when the Relief's far out.",
			"Keep your lamp lit, dear. Mine went out once.",
		},
	},
	{
		id = "Newsboy",
		look = {
			skin = { 234, 196, 164 },
			hair = { 150, 96, 54 },
			cut = "Sack",
			coat = { 92, 70, 48 },
			trim = { 150, 130, 100 },
			neck = { 120, 30, 26 },
			lower = { 70, 62, 54 },
			hat = "Flat",
			hatColor = { 84, 76, 64 },
			prop = "Papers",
		},
		lines = {
			"Evening paper! Relief due out at dusk! Read all about it!",
			"They don't print what comes back. Only who.",
			"Penny for the paper? No? Suit yourself, Hand.",
		},
	},
} :: { Person })

-- Clothing for the R6 body in place of the kit's box coat, sleeves, trousers, boots, skirt and bag
-- (tools/crew-clothing/passenger_textures.py, passenger_r6.py; sources in assets/crew-clothing/
-- passengers-r6): classic shirt and pants sheets and mesh pieces welded to limbs, as Mabel wears
-- (Config/Npcs). A person wears them only once both sheets and every piece have ids; until the uploads
-- land the kit dresses them as before (bound 11-10, uploaded under the owner's account). `prop` marks a piece that replaces the kit's prop.
-- Studio's OBJ import turns the pieces round (front to back), hence yaw 180.
export type WearPiece = {
	name: string,
	limb: string,
	mesh: number?,
	texture: number?,
	offset: { number },
	yaw: number,
	size: { number },
	prop: boolean?,
	-- the phone set's mesh (passenger_heads.py with PASSENGER_LOD=0.5, same atlas): shown instead under the
	-- Performance setting (Detail / DetailFallback tags, Controllers/DetailController)
	phone: number?,
}
-- `face`: a classic Roblox head with a painted face decal (tools/crew-clothing/passenger_faces.py) in
-- place of the kit's sculpted head and whiskers (owner, 11-10: "roblox heads with the same eerie tone")
-- `head`: the sculpted hair, whiskers and hat stand in for every kit piece on the head
export type Wear = { shirt: number?, pants: number?, face: number?, head: boolean?, pieces: { WearPiece } }

-- Mabel's uploaded skirt mesh (Config/Npcs), worn in each woman's own cloth
local function skirt(texture: number?): WearPiece
	return {
		name = "Skirt",
		limb = "Torso",
		mesh = 96135756126639,
		texture = texture,
		offset = { 0, -1.707, 0.06 },
		yaw = 180,
		size = { 3.063, 2.335, 2.137 },
	}
end

-- the bags (passenger_r6.py manifest: one atlas, bags.png); each replaces the kit's prop
local BAGS = 75170804867986
local BAG_POST: WearPiece = {
	name = "PostBag",
	limb = "Torso",
	mesh = 117355350677440,
	texture = BAGS,
	offset = { 0.62, -1.144, 0.736 },
	yaw = 180,
	size = { 1.025, 0.862, 0.398 },
	prop = true,
}
local BAG_PAPER: WearPiece = {
	name = "PaperBag",
	limb = "Torso",
	mesh = 132294118806403,
	texture = BAGS,
	offset = { 0.62, -0.988, 0.72 },
	yaw = 180,
	size = { 1.014, 1.175, 0.384 },
	prop = true,
}
local BAG_RETICULE: WearPiece = {
	name = "Reticule",
	limb = "Left Arm",
	mesh = 118089836112138,
	texture = BAGS,
	offset = { 0, -1.678, -0.1 },
	yaw = 180,
	size = { 0.52, 1.064, 0.52 },
	prop = true,
}

-- sculpted hair, whiskers, hats and coat pieces (tools/crew-clothing/passenger_heads.py, one atlas)
local HEADS = 80589939821623
-- the phone set, by piece name (assets/crew-clothing/passengers-r6/phone; owner uploads pending)
local PHONE: { [string]: number } = {}
local function headPiece(
	name: string,
	limb: string,
	mesh: number,
	offset: { number },
	size: { number }
): WearPiece
	return {
		name = name,
		limb = limb,
		mesh = mesh,
		texture = HEADS,
		offset = offset,
		yaw = 180,
		size = size,
		phone = PHONE[name],
	}
end
local HEAD_PIECES: { [string]: { WearPiece } } = {
	Clerk = {
		headPiece("ClerkHair", "Head", 123297463482216, { -0.004, 0.174, 0.007 }, { 1.286, 0.969, 1.259 }),
		headPiece("ClerkBowler", "Head", 137688806355414, { 0.006, 0.543, 0.005 }, { 1.849, 0.714, 2.004 }),
		headPiece("ClerkCoat", "Torso", 117614044555489, { -0.005, -1.034, 0.023 }, { 2.267, 0.977, 1.232 }),
	},
	Mother = {
		headPiece("MotherHair", "Head", 80472637476256, { 0.001, 0.173, 0.06 }, { 1.295, 0.955, 1.328 }),
		headPiece("MotherBonnet", "Head", 115440195872016, { 0, 0.07, 0.121 }, { 1.904, 1.816, 1.485 }),
		headPiece(
			"MotherBustle",
			"Torso",
			123457434236952,
			{ -0.009, -1.099, 0.905 },
			{ 2.273, 1.571, 0.751 }
		),
	},
	Gentleman = {
		headPiece("GentlemanHair", "Head", 90488999382602, { 0.002, 0.182, 0.058 }, { 1.353, 0.921, 1.248 }),
		headPiece("GentlemanBeard", "Head", 87459602620550, { 0, -0.437, -0.302 }, { 1.29, 1.215, 0.837 }),
		headPiece(
			"GentlemanTopHat",
			"Head",
			84721764741591,
			{ 0.006, 0.748, 0.005 },
			{ 1.969, 1.104, 2.133 }
		),
		headPiece(
			"GentlemanFrock",
			"Torso",
			82479189384957,
			{ -0.004, -1.536, 0.07 },
			{ 2.39, 1.976, 1.655 }
		),
	},
	Porter = {
		headPiece("PorterHair", "Head", 74035923247102, { 0.01, 0.141, 0.026 }, { 1.287, 0.978, 1.256 }),
		headPiece("PorterWhiskers", "Head", 104548563849159, { 0, -0.311, -0.254 }, { 1.317, 0.922, 0.678 }),
		headPiece("PorterCap", "Head", 123639014463686, { 0, 0.329, -0.148 }, { 1.62, 0.702, 1.908 }),
		headPiece(
			"PorterReefer",
			"Torso",
			122435259936413,
			{ -0.004, -0.986, 0.005 },
			{ 2.186, 0.874, 1.208 }
		),
	},
	Widow = {
		headPiece("WidowHair", "Head", 138944061769277, { -0.001, 0.176, 0.085 }, { 1.298, 0.953, 1.378 }),
		headPiece("WidowVeil", "Head", 120694103884542, { -0.02, -0.389, 0.31 }, { 1.571, 2.078, 1.172 }),
		headPiece("WidowShawl", "Torso", 88800382632590, { 0, 0.255, 0.005 }, { 2.231, 1.61, 1.3 }),
	},
	Newsboy = {
		headPiece("NewsboyHair", "Head", 76279041602489, { 0.006, 0.087, 0.001 }, { 1.379, 1.136, 1.404 }),
		headPiece("NewsboyCap", "Head", 135021005133986, { 0, 0.404, -0.088 }, { 1.521, 0.752, 1.847 }),
		headPiece(
			"NewsboyKerchief",
			"Torso",
			110601366120613,
			{ 0.022, 0.753, -0.257 },
			{ 1.018, 0.662, 0.753 }
		),
	},
}

local WEAR: { [string]: Wear } = {
	Clerk = { shirt = 123341283155742, pants = 72138147318622, face = 88504745702667, pieces = {} },
	Mother = {
		shirt = 79013536763641,
		pants = 116411447034393,
		face = 129542827975755,
		pieces = { skirt(101866923489772), BAG_RETICULE },
	},
	Gentleman = { shirt = 127815124237291, pants = 130620267136694, face = 93443120066114, pieces = {} },
	Porter = {
		shirt = 124284344455641,
		pants = 138727635610576,
		face = 137639748705187,
		pieces = { BAG_POST },
	},
	Widow = {
		shirt = 89073375936855,
		pants = 93642940005009,
		face = 72801263217418,
		pieces = { skirt(92381773347916) },
	},
	Newsboy = {
		shirt = 90911706316960,
		pants = 95755848352529,
		face = 116658704551546,
		pieces = { BAG_PAPER },
	},
}
-- The hall's four counter staff (Config/Outfits Lobby, built by Builders/LobbyBuilder) wear the same way
-- (tools/crew-clothing/staff_textures.py; sources in assets/crew-clothing/staff-r6). Mrs. Pell's apron
-- is painted on her bodice and skirt. The Guard stays the kit figure: he lies over the van rail.
WEAR.TeaRoom = { pieces = { skirt(nil) } }
WEAR.Outfitter = { pieces = {} }
WEAR.TicketClerk = { pieces = {} }
WEAR.LineMastery = { pieces = {} }

for id, wear in WEAR do
	local extra = HEAD_PIECES[id]
	if extra then
		for _, piece in extra do
			table.insert(wear.pieces, piece)
		end
		wear.head = true
	end
end
Passengers.Wear = table.freeze(WEAR)

-- Whether `id` is dressed in its sheets and pieces: every id is bound.
function Passengers.wearReady(id: string): boolean
	local wear = Passengers.Wear[id]
	if wear == nil or wear.shirt == nil or wear.pants == nil then
		return false
	end
	for _, piece in wear.pieces do
		if piece.mesh == nil or piece.texture == nil then
			return false
		end
	end
	return true
end

return table.freeze(Passengers)
