--!strict
--[[
	Crew Rank curve and Line Mastery milestones.

	XP needed to reach rank L:  XP(L) = round(120 * (L - 1) ^ 1.55), capped at rank 60.
	Milestones read lifetime stats from the profile; each grants once.
	Line Mastery is the record (docs/FINAL-DESIGN.md Prompt 8): the status items' milestones are built
	from their `record` in Config/Cosmetics, so the rule lives in one place. `all`, when present, lists
	every requirement (AND); `stat`/`goal` is then its first.
]]

local Cosmetics = require(script.Parent.Cosmetics)

export type Requirement = Cosmetics.Requirement

export type Milestone = {
	id: string,
	name: string,
	description: string,
	stat: string,
	goal: number,
	all: { Requirement }?,
	reward: { brass: number?, cosmetic: string? },
}

-- A status item's milestone: its requirements are the item's `record`, its reward the item.
local function record(id: string, name: string, description: string, cosmetic: string): Milestone
	local def = Cosmetics.ById[cosmetic]
	local all = def.record :: { Requirement }
	assert(def.milestone == id, `{cosmetic} names milestone {def.milestone}, not {id}`)
	return {
		id = id,
		name = name,
		description = description,
		stat = all[1].stat,
		goal = all[1].goal,
		all = if #all > 1 then all else nil,
		reward = { cosmetic = cosmetic },
	}
end

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
	-- the record: the status items, earned and never sold
	record("DeepLine", "Deep Line", "Reach stop 8 in a single Relief.", "hat_lampcap"),
	record("ClutchHand", "Clutch Hand", "Board in the final two seconds five times.", "trail_brass"),
	record("AuroraWatch", "Aurora Watch", "Reach the Terminus three times.", "lantern_aurora"),
	record("Stationmaster", "Stationmaster", "Reach the Terminus five times.", "hat_topper"),
	record("RoyalRoad", "Royal Road", "Finish the Long Line and depart 50 stops in all.", "livery_royal"),
	record("uniform_stoker_veteran", "Veteran Stoker", "Depart 25 stations alive.", "uniform_stoker_veteran"),
	record(
		"uniform_conductor_terminus",
		"Terminus Conductor",
		"Finish the Long Line.",
		"uniform_conductor_terminus"
	),
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
	-- how a requirement reads on the Outfitter and the Roll (%d is the goal)
	StatText = table.freeze({
		victories = "%d Terminus arrivals",
		longVictories = "%d Long Line finish",
		stationsDeparted = "%d stops departed",
		bestStation = "Reach stop %d",
		clutchBoards = "%d last-second boardings",
		rescues = "%d flare rescues",
		runs = "%d Reliefs",
		rank = "Crew Rank %d",
	} :: { [string]: string }),
	-- Lifetime stats every profile carries (missing keys default to 0).
	Stats = table.freeze({
		"runs",
		"victories",
		"longVictories", -- Long Line victories only (Prompt 10; gates the Long Line's status items)
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
