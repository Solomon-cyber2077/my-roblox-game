--!strict
--[[
	Crew Rank curve and Line Mastery milestones.

	XP needed to reach rank L:  XP(L) = round(120 * (L - 1) ^ 1.55), capped at rank 60.
	Milestones read lifetime stats from the profile; each grants once.
]]

export type Milestone = {
	id: string,
	name: string,
	description: string,
	stat: string,
	goal: number,
	reward: { brass: number?, cosmetic: string? },
}

local Milestones: { Milestone } = {
	{
		id = "AllAboard",
		name = "All Aboard",
		description = "Depart your first station alive.",
		stat = "stationsDeparted",
		goal = 1,
		reward = { brass = 50 },
	},
	{
		id = "LineRunner",
		name = "Line Runner",
		description = "Reach station 5 in a single run.",
		stat = "bestStation",
		goal = 5,
		reward = { brass = 150 },
	},
	{
		id = "Stoker",
		name = "Stoker",
		description = "Deliver 100 coal to the bunker.",
		stat = "coalDelivered",
		goal = 100,
		reward = { cosmetic = "lantern_ember" },
	},
	{
		id = "Tinker",
		name = "Tinker",
		description = "Deliver 50 parts to the train.",
		stat = "partsDelivered",
		goal = 50,
		reward = { brass = 200 },
	},
	{
		id = "NoOneLeftBehind",
		name = "No One Left Behind",
		description = "Fire a flare that brings a crewmate back.",
		stat = "rescues",
		goal = 1,
		reward = { cosmetic = "hat_signalman" },
	},
	{
		id = "LastSecondHero",
		name = "Last-Second Hero",
		description = "Board in the final two seconds of a departure.",
		stat = "clutchBoards",
		goal = 1,
		reward = { cosmetic = "trail_cinder" },
	},
	{
		id = "Collector",
		name = "Collector",
		description = "Bank 10 relics on the train.",
		stat = "relicsBanked",
		goal = 10,
		reward = { cosmetic = "lantern_curio" },
	},
	{
		id = "EndOfTheLine",
		name = "End of the Line",
		description = "Reach the Terminus.",
		stat = "victories",
		goal = 1,
		reward = { cosmetic = "livery_terminus" },
	},
	{
		id = "OldHand",
		name = "Old Hand",
		description = "Reach Crew Rank 10.",
		stat = "rank",
		goal = 10,
		reward = { cosmetic = "livery_smokebox" },
	},
	{
		id = "Veteran",
		name = "Veteran",
		description = "Finish 25 runs.",
		stat = "runs",
		goal = 25,
		reward = { brass = 300 },
	},
}

local ById: { [string]: Milestone } = {}
for _, milestone in Milestones do
	ById[milestone.id] = milestone
	table.freeze(milestone.reward)
	table.freeze(milestone)
end

return table.freeze({
	Milestones = table.freeze(Milestones),
	ById = table.freeze(ById),
	Rank = table.freeze({ Scale = 120, Exponent = 1.55, Max = 60 }),
	-- Lifetime stats every profile carries (missing keys default to 0).
	Stats = table.freeze({
		"runs",
		"victories",
		"stationsDeparted",
		"bestStation",
		"coalDelivered",
		"partsDelivered",
		"relicsBanked",
		"rescues",
		"clutchBoards",
		"charterStamps",
		"eliminations",
	}),
})
