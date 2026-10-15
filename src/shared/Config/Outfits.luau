--!strict
--[[
	Period dress for the people of the line (LORE.md section 6, 1884-1892), as data that
	Builders/OutfitKit turns into a figure. One look describes a whole person:

	  cut      the upper garment: "Frock" (knee-length frock coat over a waistcoat),
	           "StaffFrock" (a railway guard's double-breasted frock coat, buttoned to the neck),
	           "Sack" (a shopkeeper's lounge coat), "Reefer" (railway staff jacket, two rows of
	           brass buttons) or "Bodice" (a fitted bodice with a lace collar)
	  belt     a guard's patent-leather shoulder belt and pouch
	  skirt    nil for trousers and boots; "Plain" or "Bustle" for a long skirt
	  hat      "Top", "Bowler", "Peaked" (company cap with a badge), "Lace" (a cap), "Bonnet"
	           or "Visor" (a clerk's eyeshade); nil for bare-headed indoors
	  prop     what they hold: "Punch", "Ledger", "Tape", "Lamp", "Pointer" or "Cloth"

	A pose bends the figure: `lean` tips the body forward at the hips, `armL`/`armR` swing each
	arm forward from the shoulder and `head` tips the head back up (all degrees).
]]

export type Look = {
	skin: { number },
	hair: { number },
	hairStyle: string?, -- "Short" (default), "Bun", "Bald"
	whiskers: boolean?,
	cut: string,
	coat: { number },
	trim: { number }, -- buttons, badge, watch chain
	waistcoat: { number }?,
	neck: { number }?, -- cravat or neckerchief
	lower: { number }, -- trousers or skirt
	skirt: string?,
	apron: { number }?,
	hat: string?,
	hatColor: { number }?,
	prop: string?,
	belt: boolean?,
}

export type Pose = { lean: number?, armL: number?, armR: number?, head: number? }

export type Resident = {
	id: string,
	name: string,
	role: string,
	look: Look,
	pose: Pose?,
}

local BRASS = { 180, 148, 88 }
local LINEN = { 226, 220, 206 }

-- The Depot Hall's people. LobbyBuilder decides where each one stands.
local Lobby: { [string]: Resident } = {
	TeaRoom = {
		id = "TeaRoom",
		name = "Mrs. Pell",
		role = "Tea Rooms",
		look = {
			skin = { 236, 200, 172 },
			hair = { 92, 72, 62 },
			hairStyle = "Bun",
			cut = "Bodice",
			coat = { 46, 40, 58 },
			trim = BRASS,
			lower = { 52, 44, 60 },
			skirt = "Plain",
			apron = LINEN,
			hat = "Lace",
			prop = "Cloth",
		},
		pose = { armR = 18 },
	},
	Outfitter = {
		id = "Outfitter",
		name = "Mr. Pyle",
		role = "Outfitter",
		look = {
			skin = { 224, 188, 160 },
			hair = { 62, 50, 42 },
			whiskers = true,
			cut = "Frock",
			coat = { 30, 32, 38 },
			trim = BRASS,
			waistcoat = { 108, 36, 34 },
			neck = { 34, 30, 32 },
			lower = { 72, 68, 64 },
			prop = "Tape",
		},
		pose = { armR = 12, armL = 8 },
	},
	TicketClerk = {
		id = "TicketClerk",
		name = "Mr. Lethbridge",
		role = "Booking Clerk",
		look = {
			skin = { 214, 176, 150 },
			hair = { 120, 110, 100 },
			whiskers = true,
			cut = "Reefer",
			coat = { 28, 36, 60 },
			trim = BRASS,
			waistcoat = { 28, 36, 60 },
			lower = { 34, 36, 48 },
			hat = "Peaked",
			hatColor = { 28, 36, 60 },
			prop = "Punch",
		},
		pose = { lean = 8, armR = 34, armL = 30 },
	},
	LineMastery = {
		id = "LineMastery",
		name = "The Line Superintendent",
		role = "Line Mastery",
		look = {
			skin = { 230, 196, 170 },
			hair = { 150, 146, 140 },
			whiskers = true,
			cut = "Frock",
			coat = { 22, 24, 30 },
			trim = BRASS,
			waistcoat = { 62, 66, 72 },
			neck = { 118, 30, 34 },
			lower = { 40, 40, 46 },
			hat = "Top",
			hatColor = { 20, 20, 24 },
			prop = "Pointer",
		},
		pose = { armL = 62, head = -4 },
	},
	Guard = {
		id = "Guard",
		name = "The Guard",
		role = "Guard",
		look = {
			skin = { 210, 168, 140 },
			hair = { 70, 60, 54 },
			whiskers = true,
			-- 1870s-90s guards: double-breasted frock coat, peaked cap, shoulder belt (LORE.md 6)
			cut = "StaffFrock",
			belt = true,
			coat = { 24, 30, 44 },
			trim = BRASS,
			waistcoat = { 24, 30, 44 },
			neck = { 128, 34, 30 },
			lower = { 30, 32, 40 },
			hat = "Peaked",
			hatColor = { 24, 30, 44 },
			prop = "Lamp",
		},
		-- lying forward over the veranda rail, forearms on the top rail, looking out
		pose = { lean = 28, armL = 104, armR = 100, head = 26 },
	},
}

return table.freeze({ Lobby = table.freeze(Lobby) })
