--!strict
--[[
	Cosmetic catalog. Every item is visual only; nothing here changes a number
	that affects play (monetization rule M1 in the production blueprint).

	Unlock paths, checked in this order by Logic/Catalog:
	  default     owned by every profile
	  milestone   granted by Config/Progression milestones; a status item (its name claims an
	              achievement) carries `record`, the Line Mastery requirements that grant it, all
	              of which must be met (Prompt 8; Config/Progression builds its milestone from it)
	  brass       bought in the Outfitter: ordinary items only, never a status item
	  robux       a developer product; productId is bound after publishing
	  gamePass    a game pass; id is bound after publishing
	  charter     earned with Charter Stamps from private-server runs
	  npc         granted for finishing that resident's errand chain (Config/Npcs)
]]

export type Category = "Lantern" | "Headwear" | "Trail" | "Livery" | "Uniform"
export type Rarity = "Standard" | "Fine" | "Rare" | "Legendary"

-- A lifetime stat (Config/Progression.Stats) reaching a goal.
export type Requirement = { stat: string, goal: number }

export type CosmeticDef = {
	id: string,
	name: string,
	category: Category,
	rarity: Rarity,
	description: string,
	default: boolean?,
	brass: number?,
	milestone: string?,
	record: { Requirement }?, -- a status item's Line Mastery requirements, all of them (AND)
	robux: { productId: number?, price: number }?,
	gamePass: { id: number?, price: number }?,
	charterStamps: number?,
	npc: string?,
	look: { [string]: any },
}

local Catalog: { CosmeticDef } = {
	-- Lanterns: carried on the hip, cast light for everyone nearby.
	{
		id = "lantern_brakeman",
		name = "Brakeman's Lamp",
		category = "Lantern",
		rarity = "Standard",
		description = "Standard issue. Warm, steady, reliable.",
		default = true,
		look = {
			body = { 62, 58, 54 },
			glass = { 255, 214, 160 },
			light = { 255, 196, 128 },
			style = "Classic",
		},
	},
	{
		id = "lantern_signal",
		name = "Signal Green",
		category = "Lantern",
		rarity = "Fine",
		description = "Line-clear green, for crews that never stop.",
		brass = 600,
		look = {
			body = { 40, 46, 42 },
			glass = { 80, 222, 112 }, -- signal-lamp green, lit: deep green read too dark at a distance
			light = { 40, 220, 96 },
			style = "Signal",
		},
	},
	{
		id = "lantern_ember",
		name = "Ember Lamp",
		category = "Lantern",
		rarity = "Fine",
		description = "Earned by stokers who fed the firebox 100 coal.",
		milestone = "Stoker",
		look = {
			body = { 58, 30, 28 },
			glass = { 255, 170, 96 }, -- a coal's hot heart: crimson glass vanished on a dim screen
			light = { 255, 100, 52 }, -- the pool it throws stays ember red
			glow = 1.4,
			style = "Squat",
		}, -- ember
	},
	{
		id = "lantern_curio",
		name = "Curio Lantern",
		category = "Lantern",
		rarity = "Rare",
		description = "Gilded filigree for those who banked ten relics.",
		milestone = "Collector",
		look = {
			body = { 201, 160, 82 },
			glass = { 255, 214, 140 },
			light = { 255, 196, 104 },
			glow = 1.5, -- a collector's lamp: burns brighter than standard issue
			style = "Filigree",
		},
	},
	{
		id = "lantern_aurora",
		name = "Aurora Lamp",
		category = "Lantern",
		rarity = "Legendary",
		description = "Its flame drifts between teal and violet.",
		milestone = "AuroraWatch",
		record = { { stat = "victories", goal = 3 } },
		look = {
			body = { 36, 34, 48 },
			glass = { 90, 255, 230 },
			light = { 40, 235, 215 },
			light2 = { 216, 176, 255 }, -- the lens takes this too: a lavender violet that still reads
			glow = 1.6,
			style = "Prism",
		},
	},
	{
		id = "lantern_founder",
		name = "Founder's Lantern",
		category = "Lantern",
		rarity = "Legendary",
		description = "For the first crews to ride the line. Sparkles included.",
		gamePass = { id = nil, price = 249 },
		look = {
			body = { 206, 164, 72 }, -- gilt
			glass = { 255, 222, 140 },
			light = { 255, 204, 96 },
			glow = 1.3,
			style = "Crown",
			sparkle = true,
		},
	},

	-- Headwear: welded to the head, built from primitives.
	{
		id = "hat_none",
		name = "Bare Head",
		category = "Headwear",
		rarity = "Standard",
		description = "Nothing between you and the wind.",
		default = true,
		look = { style = "None" },
	},
	{
		id = "hat_conductor",
		name = "Conductor's Cap",
		category = "Headwear",
		rarity = "Fine",
		description = "Navy wool, brass badge, full authority.",
		brass = 400,
		look = { style = "Conductor", primary = { 34, 42, 66 }, secondary = { 201, 160, 82 } },
	},
	{
		id = "hat_signalman",
		name = "Signalman's Cap",
		category = "Headwear",
		rarity = "Rare",
		description = "Earned by firing a flare that brought someone home.",
		milestone = "NoOneLeftBehind",
		look = {
			style = "Conductor",
			primary = { 140, 34, 30 },
			secondary = { 220, 228, 232 },
			detail = "Rescue",
		},
	},
	{
		id = "hat_clerk",
		name = "Clerk's Punch Cap",
		category = "Headwear",
		rarity = "Rare",
		description = "Mabel's spare cap, her brass ticket punch pinned to the band.",
		npc = "Mabel",
		look = {
			style = "Conductor",
			detail = "Punch",
			primary = { 40, 50, 78 },
			secondary = { 214, 178, 96 },
		},
	},
	{
		id = "hat_goggles",
		name = "Stoker's Goggles",
		category = "Headwear",
		rarity = "Fine",
		description = "Soot-proof brass goggles.",
		brass = 750,
		look = { style = "Goggles", primary = { 92, 64, 40 }, secondary = { 201, 160, 82 } },
	},
	{
		id = "hat_lampcap",
		name = "Miner's Lamp Cap",
		category = "Headwear",
		rarity = "Rare",
		description = "A hard cap with a lamp that lights your path.",
		milestone = "DeepLine",
		record = { { stat = "bestStation", goal = 8 } },
		look = { style = "LampCap", primary = { 70, 66, 58 }, secondary = { 255, 230, 170 } },
	},
	{
		id = "hat_topper",
		name = "Stationmaster's Topper",
		category = "Headwear",
		rarity = "Legendary",
		description = "A tall hat for a tall reputation.",
		milestone = "Stationmaster",
		record = { { stat = "victories", goal = 5 } },
		look = { style = "TopHat", primary = { 26, 24, 26 }, secondary = { 132, 46, 52 } },
	},

	-- Trails: emitted from the feet while moving.
	{
		id = "trail_none",
		name = "No Trail",
		category = "Trail",
		rarity = "Standard",
		description = "Leave no trace.",
		default = true,
		look = { style = "None" },
	},
	{
		id = "trail_cinder",
		name = "Cinder Steps",
		category = "Trail",
		rarity = "Rare",
		description = "Earned by boarding in the last two seconds of a departure.",
		milestone = "LastSecondHero",
		look = { style = "Cinder", color = { 255, 120, 50 }, color2 = { 120, 40, 20 } },
	},
	{
		id = "trail_steam",
		name = "Steam Wake",
		category = "Trail",
		rarity = "Fine",
		description = "A soft plume of white steam behind every stride.",
		brass = 900,
		look = { style = "Steam", color = { 236, 236, 236 }, color2 = { 180, 180, 186 } },
	},
	{
		id = "trail_brass",
		name = "Brass Sparks",
		category = "Trail",
		rarity = "Rare",
		description = "Golden sparks off hobnailed boots.",
		milestone = "ClutchHand",
		record = { { stat = "clutchBoards", goal = 5 } },
		look = { style = "Sparks", color = { 255, 214, 120 }, color2 = { 201, 160, 82 } },
	},
	{
		id = "trail_wraith",
		name = "Wraith Mist",
		category = "Trail",
		rarity = "Legendary",
		description = "Pale mist that clings to your heels.",
		robux = { productId = nil, price = 149 },
		look = { style = "Mist", color = { 190, 220, 255 }, color2 = { 120, 140, 200 } },
	},

	-- Liveries: the train's paint for the whole crew (see CosmeticService for who chooses).
	{
		id = "livery_heritage",
		name = "Heritage Mahogany",
		category = "Livery",
		rarity = "Standard",
		description = "Varnished mahogany lined in gilt, deep green doors: the way she left the works in 1872.",
		default = true,
		look = {
			body = { 60, 33, 28 },
			trim = { 150, 120, 74 },
			roof = { 34, 33, 34 },
			accent = { 38, 70, 58 },
			lamp = { 240, 184, 116 },
		},
	},
	{
		id = "livery_smokebox",
		name = "Smokebox Black",
		category = "Livery",
		rarity = "Fine",
		description = "For crews who reached Crew Rank 10.",
		milestone = "OldHand",
		look = {
			body = { 28, 28, 30 },
			trim = { 168, 54, 42 },
			roof = { 40, 40, 42 },
			accent = { 52, 56, 60 },
			lamp = { 255, 210, 150 },
		},
	},
	{
		id = "livery_royal",
		name = "Royal Blue Express",
		category = "Livery",
		rarity = "Rare",
		description = "Deep blue lined out in white metal.",
		milestone = "RoyalRoad",
		record = { { stat = "longVictories", goal = 1 }, { stat = "stationsDeparted", goal = 50 } },
		look = {
			body = { 30, 52, 104 },
			trim = { 196, 206, 214 },
			roof = { 40, 42, 48 },
			accent = { 201, 160, 82 },
			lamp = { 230, 236, 255 },
		},
	},
	{
		id = "livery_crimson",
		name = "Charter Crimson",
		category = "Livery",
		rarity = "Rare",
		description = "Earned by private-server owners with five Charter Stamps.",
		charterStamps = 5,
		look = {
			body = { 120, 30, 34 },
			trim = { 201, 160, 82 },
			roof = { 44, 36, 36 },
			accent = { 40, 22, 24 },
			lamp = { 255, 206, 150 },
		},
	},
	{
		id = "livery_terminus",
		name = "Terminus Gold",
		category = "Livery",
		rarity = "Legendary",
		description = "Only for crews who reached the end of the line.",
		milestone = "EndOfTheLine",
		look = {
			body = { 176, 136, 62 },
			trim = { 40, 34, 28 },
			roof = { 70, 58, 42 },
			accent = { 64, 46, 30 },
			lamp = { 255, 236, 190 },
		},
	},
	{
		id = "livery_midnight",
		name = "Midnight Mail",
		category = "Livery",
		rarity = "Legendary",
		description = "Night-mail indigo with silver lining.",
		robux = { productId = nil, price = 299 },
		look = {
			body = { 26, 24, 54 },
			trim = { 196, 204, 220 },
			roof = { 30, 30, 40 },
			accent = { 120, 140, 255 },
			lamp = { 200, 214, 255 },
		},
	},
}

-- Crew uniforms are intentionally gated until their classic-clothing and accessory
-- assets have passed the visual/triangle audit. They still appear in the locker so
-- a player can see the upcoming identities and their unlock paths.
local CrewClothing = require(script.Parent.CrewClothing)
for _, recipe in CrewClothing.List do
	table.insert(Catalog, {
		id = recipe.id,
		name = recipe.name,
		category = "Uniform",
		rarity = if recipe.starter then "Standard" else "Rare",
		description = "Crew issue uniform for the line.",
		default = if recipe.starter then true else nil,
		milestone = if recipe.record then recipe.id else nil,
		record = recipe.record,
		look = { uniform = recipe.id },
	})
end

local ById: { [string]: CosmeticDef } = {}
local Defaults: { [string]: string } = {}
for _, def in Catalog do
	def.look.rarity = def.rarity
	assert(ById[def.id] == nil, `duplicate cosmetic id {def.id}`)
	assert(
		def.record == nil or (def.milestone ~= nil and def.brass == nil),
		`{def.id}: a record item has no price`
	)
	ById[def.id] = def
	if def.default then
		Defaults[def.category] = def.id
	end
end
Defaults.Uniform = CrewClothing.Default

return table.freeze({
	-- One switch: virtual ownership for the developer and Studio; never persisted.
	DevUnlock = table.freeze({ Enabled = true, UserId = 11744048795 }),
	-- every lantern's lens (glass, and light2 where the lens cycles to it) and light must clear
	-- these linear Rec. 709 luminances, so a crewmate's lamp reads at 3:1 on a dim screen
	-- (docs/visibility/gates_45_fix1.md; tests/LanternLuminance.spec)
	LanternMinLuminance = table.freeze({ Glass = 0.5, Light = 0.3 }),
	List = table.freeze(Catalog),
	ById = table.freeze(ById),
	Defaults = table.freeze(Defaults),
	Categories = table.freeze({ "Lantern", "Headwear", "Trail", "Livery", "Uniform" }),
	RarityOrder = table.freeze({ Standard = 1, Fine = 2, Rare = 3, Legendary = 4 }),
	DailySpecialCount = 3,
	DailySpecialDiscount = 0.2,
})
