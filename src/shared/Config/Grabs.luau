--!strict
--[[
	How each kind of Hollow holds its prey. A strike that lands seizes the target; the
	victim fights free by mashing the struggle key (Logic/Grab) while the Hollow bites,
	squeezes or yanks once per `bite` seconds. Every kind has three grabs, picked by the
	Hollow's seed and by the room around it (a grab that would push its victim into a wall
	gives way to one that fits).

	hold   where the victim's root sits, from the Hollow's root: x right, y up, z ahead is
	       negative. up is where the victim's head points, face where their front faces
	       ({0, 0, 1} faces the Hollow), both in the Hollow's frame.
	lying  the victim is on the ground (the room check uses a body lying down)
	name   what the struggle prompt calls it

	The poses that go with them live in the client's Animation/HollowPoses and
	Animation/CrewPoses; the audit checks the Hollow's hands meet the victim.
]]

export type Hold = {
	pos: { number },
	up: { number },
	face: { number },
}

export type Def = {
	id: string,
	name: string,
	hold: Hold,
	bite: number,
	lying: boolean,
}

local STANDING = { 0, 1, 0 }
local TOWARD = { 0, 0, 1 } -- facing the Hollow
local AWAY = { 0, 0, -1 }
local DOWN = { 0, -1, 0 }
local UP = { 0, 1, 0 }

local Grabs: { [string]: { Def } } = {
	-- the porter's long arms: he lifts you by the throat, folds you into his ribs, or takes
	-- an ankle and hauls you face down toward the fog
	Stalker = {
		{
			id = "Throttle",
			name = "LIFTED BY THE THROAT",
			hold = { pos = { 0.4, 0, -4.2 }, up = STANDING, face = TOWARD },
			bite = 0.9,
			lying = false,
		},
		{
			id = "Embrace",
			name = "CRUSHED IN ITS ARMS",
			hold = { pos = { 0, -1.7, -3.0 }, up = STANDING, face = TOWARD },
			bite = 1.1,
			lying = false,
		},
		{
			id = "Drag",
			name = "DRAGGED BY THE ANKLE",
			hold = { pos = { 0, -4.65, -5.8 }, up = AWAY, face = DOWN },
			bite = 0.8,
			lying = true,
		},
	},
	-- the passenger: it pounces and pins you on your back, latches onto your legs, or
	-- climbs your back and wraps itself around you
	Crawler = {
		{
			id = "Pin",
			name = "PINNED DOWN",
			hold = { pos = { 0, -2.95, -2.7 }, up = AWAY, face = UP },
			bite = 0.6,
			lying = true,
		},
		{
			id = "Latch",
			name = "CAUGHT BY THE LEGS",
			hold = { pos = { 0, -2.95, -6.6 }, up = AWAY, face = DOWN },
			bite = 0.7,
			lying = true,
		},
		{
			id = "Ride",
			name = "IT IS ON YOUR BACK",
			hold = { pos = { 0, -1.9, -3.2 }, up = STANDING, face = AWAY },
			bite = 0.65,
			lying = false,
		},
	},
	-- the stoker: he closes his fist on you, pins you under the shovel, or crushes you
	-- against the embers in his chest
	Brute = {
		{
			id = "Fist",
			name = "IN ITS FIST",
			hold = { pos = { -1.6, 0.4, -3.8 }, up = STANDING, face = TOWARD },
			bite = 1.2,
			lying = false,
		},
		{
			id = "Shovel",
			name = "PINNED UNDER THE SHOVEL",
			hold = { pos = { 0.9, -5.15, -5.2 }, up = AWAY, face = UP },
			bite = 1.0,
			lying = true,
		},
		{
			id = "Bearhug",
			name = "CRUSHED TO ITS CHEST",
			hold = { pos = { 0, -1.1, -2.9 }, up = STANDING, face = TOWARD },
			bite = 1.3,
			lying = false,
		},
	},
}

local ById: { [string]: Def } = {}
for _, list in Grabs do
	for _, def in list do
		assert(ById[def.id] == nil, `duplicate grab {def.id}`)
		ById[def.id] = def
		table.freeze(def.hold)
		table.freeze(def)
	end
	table.freeze(list)
end

return table.freeze({
	Kinds = table.freeze(Grabs),
	ById = table.freeze(ById),
})
