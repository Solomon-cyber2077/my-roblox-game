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

local geometry = {
	uniform_stoker = { size = { 2.6, 0.4108, 2.0595 }, offset = { 0, 0.7554, 0 }, triangles = 600 },
	uniform_brakeman = { size = { 2.6, 0.445, 2.1295 }, offset = { 0, 0.7725, 0 }, triangles = 600 },
	uniform_conductor = { size = { 2.6, 0.635, 2.1295 }, offset = { 0, 0.8675, 0 }, triangles = 616 },
	uniform_trackwalker = { size = { 1.96, 0.7, 1.666 }, offset = { 0, 0.9, 0 }, triangles = 440 },
	uniform_wayfarer = { size = { 2.26, 0.55, 1.921 }, offset = { 0, 0.825, 0 }, triangles = 504 },
	uniform_stoker_veteran = { size = { 2.6, 0.4108, 2.0595 }, offset = { 0, 0.7554, 0 }, triangles = 600 },
	uniform_conductor_terminus = { size = { 2.6, 0.635, 2.1295 }, offset = { 0, 0.8675, 0 }, triangles = 616 },
}

local gearGeometry: { [string]: { size: { number }, offset: { number }, triangles: number } } = {
	uniform_stoker = {
		size = { 1.4605, 1.7007, 0.2991 },
		offset = { 0.0473, 0.1253, -0.638 },
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

local function recipe(id: string, name: string, starter: boolean, record: { RecordGoal }?): Recipe
	return {
		id = id,
		name = name,
		starter = starter,
		shirt = 0,
		pants = 0,
		wornShirt = 0,
		wornPants = 0,
		validated = false,
		accessories = {
			{
				name = "Hat",
				mesh = 0,
				texture = 0,
				limb = "Head",
				size = geometry[id].size,
				offset = geometry[id].offset,
				triangles = geometry[id].triangles,
			},
			{
				name = "Gear",
				mesh = 0,
				texture = 0,
				limb = "Torso",
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
