--!strict

export type Accessory = {
	name: string,
	mesh: number,
	texture: number,
	limb: string,
	size: { number },
	offset: { number },
	yaw: number?, -- Degrees around the limb's local up axis; omitted means zero.
	triangles: number,
}

export type RecordGoal = { stat: string, goal: number }
export type Recipe = {
	id: string,
	name: string,
	starter: boolean,
	shirt: number,
	pants: number,
	wornShirt: number,
	wornPants: number,
	validated: boolean,
	accessories: { Accessory },
	record: { RecordGoal }?,
}

local gearGeometry: { [string]: { size: { number }, offset: { number }, triangles: number } } = {
	uniform_stoker = { -- the v2 apron and clasp (assets/crew-clothing/stoker-v2)
		size = { 1.625, 1.83, 0.231 },
		offset = { 0.0425, 0.065, -0.6155 },
		triangles = 372,
	},
	uniform_brakeman = {
		size = { 1.53, 1.63, 0.2725 },
		offset = { -0.0575, 0.075, -0.6513 },
		triangles = 292,
	},
	uniform_conductor = { size = { 1.56, 1.377, 0.194 }, offset = { 0.0, 0.2815, -0.617 }, triangles = 160 },
	uniform_trackwalker = {
		size = { 1.5075, 1.695, 0.2775 },
		offset = { 0.0737, 0.1325, -0.6538 },
		triangles = 133,
	},
	uniform_wayfarer = {
		size = { 1.5875, 1.745, 0.2725 },
		offset = { 0.0637, 0.1075, -0.6513 },
		triangles = 166,
	},
	uniform_stoker_veteran = {
		size = { 1.4605, 1.7007, 0.2991 },
		offset = { 0.0473, 0.1253, -0.638 },
		triangles = 372,
	},
	uniform_conductor_terminus = {
		size = { 1.56, 1.377, 0.194 },
		offset = { 0.0, 0.2815, -0.617 },
		triangles = 180,
	},
}

-- Uploaded under the owner's account: classic sheets as images, the gear as a mesh with the outfit's
-- atlas (stoker: assets/crew-clothing/stoker-v2/upload-status.json; the rest:
-- assets/crew-clothing/upload-status-2026-10-27.json). A recipe stays unvalidated until it passes
-- the engine pilots (docs/crew-clothing/VALIDATION.md).
type Uploaded = {
	shirt: number,
	pants: number,
	wornShirt: number,
	wornPants: number,
	mesh: number,
	texture: number,
}
local uploaded: { [string]: Uploaded } = {
	uniform_stoker = {
		shirt = 101979354774166,
		pants = 104204802579148,
		wornShirt = 90317117594409,
		wornPants = 100087790691733,
		mesh = 90362864770621,
		texture = 85553773814164,
	},
	uniform_brakeman = {
		shirt = 112789250534983,
		pants = 133444423059437,
		wornShirt = 88364378516986,
		wornPants = 83025738769589,
		mesh = 129711792940345,
		texture = 73098642897981,
	},
	uniform_conductor = {
		shirt = 132931422870812,
		pants = 136251956896552,
		wornShirt = 88363184328424,
		wornPants = 122461917996135,
		mesh = 93831794818197,
		texture = 133559151521048,
	},
	uniform_trackwalker = {
		shirt = 83300755079874,
		pants = 90720365454594,
		wornShirt = 77599111384776,
		wornPants = 74628556269207,
		mesh = 74122752836758,
		texture = 93042891306063,
	},
	uniform_wayfarer = {
		shirt = 87086586640518,
		pants = 114066066747644,
		wornShirt = 80004653176848,
		wornPants = 120076054608094,
		mesh = 73985586909190,
		texture = 134935301395876,
	},
	uniform_stoker_veteran = {
		shirt = 87136116614881,
		pants = 83261280185759,
		wornShirt = 139012054263592,
		wornPants = 92422689087541,
		mesh = 84211775439801,
		texture = 90209561549507,
	},
	uniform_conductor_terminus = {
		shirt = 125500198052270,
		pants = 126840229838470,
		wornShirt = 87142690985158,
		wornPants = 129150281398733,
		mesh = 101602380673627,
		texture = 82130306433456,
	},
}

local function recipe(id: string, name: string, starter: boolean, record: { RecordGoal }?): Recipe
	local ids = uploaded[id]
	return {
		id = id,
		name = name,
		starter = starter,
		shirt = ids.shirt,
		pants = ids.pants,
		wornShirt = ids.wornShirt,
		wornPants = ids.wornPants,
		validated = false,
		accessories = {
			{
				name = "Gear",
				mesh = ids.mesh,
				texture = ids.texture,
				limb = "Torso",
				yaw = 180, -- the OBJ import faces backwards (stoker-v2 pilot, 2026-10-27)
				size = gearGeometry[id].size,
				offset = gearGeometry[id].offset,
				triangles = gearGeometry[id].triangles,
			},
		},
		record = record,
	}
end

local list: { Recipe } = {
	recipe("uniform_stoker", "Stoker", true),
	recipe("uniform_brakeman", "Brakeman", true),
	recipe("uniform_conductor", "Conductor", true),
	recipe("uniform_trackwalker", "Trackwalker", true),
	recipe("uniform_wayfarer", "Wayfarer", true),
	recipe("uniform_stoker_veteran", "Stoker Veteran", false, { { stat = "stationsDeparted", goal = 25 } }),
	recipe(
		"uniform_conductor_terminus",
		"Conductor of the Terminus",
		false,
		{ { stat = "longVictories", goal = 1 } }
	),
}

local byId: { [string]: Recipe } = {}
for _, item in list do
	byId[item.id] = item
end

return table.freeze({
	Enabled = false,
	WearEnabled = false,
	Default = "uniform_stoker",
	WearStop = 3,
	MaxAccessories = 3,
	MaxTriangles = 1500,
	List = table.freeze(list),
	ById = table.freeze(byId),
})
