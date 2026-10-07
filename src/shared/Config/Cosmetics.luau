--!strict
--[[
	Cosmetic catalog. Every item is visual only; nothing here changes a number
	that affects play (monetization rule M1 in the production blueprint).

	Unlock paths, checked in this order by Logic/Catalog:
	  default     owned by every profile
	  milestone   granted by Config/Progression milestones
	  brass       bought in the Outfitter, optionally gated by Crew Rank
	  robux       a developer product; productId is bound after publishing
	  gamePass    a game pass; id is bound after publishing
	  charter     earned with Charter Stamps from private-server runs
]]

export type Category = "Lantern" | "Headwear" | "Trail" | "Livery"
export type Rarity = "Standard" | "Fine" | "Rare" | "Legendary"

export type CosmeticDef = {
	id: string,
	name: string,
	category: Category,
	rarity: Rarity,
	description: string,
	default: boolean?,
	brass: number?,
	rank: number?,
	milestone: string?,
	robux: { productId: number?, price: number }?,
	gamePass: { id: number?, price: number }?,
	charterStamps: number?,
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
			glass = { 150, 255, 170 },
			light = { 120, 235, 150 },
			style = "Classic",
		},
	},
	{
		id = "lantern_ember",
		name = "Ember Lamp",
		category = "Lantern",
		rarity = "Fine",
		description = "Earned by stokers who fed the firebox 100 coal.",
		milestone = "Stoker",
		look = { body = { 70, 42, 30 }, glass = { 255, 140, 70 }, light = { 255, 120, 50 }, style = "Squat" },
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
			glass = { 255, 236, 190 },
			light = { 255, 222, 150 },
			style = "Filigree",
		},
	},
	{
		id = "lantern_aurora",
		name = "Aurora Lamp",
		category = "Lantern",
		rarity = "Legendary",
		description = "Its flame drifts between teal and violet.",
		brass = 1800,
		rank = 15,
		look = {
			body = { 36, 34, 48 },
			glass = { 160, 255, 240 },
			light = { 110, 230, 220 },
			light2 = { 190, 120, 255 },
			style = "Filigree",
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
			body = { 236, 226, 200 },
			glass = { 255, 250, 228 },
			light = { 255, 244, 214 },
			style = "Filigree",
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
		look = { style = "Conductor", primary = { 140, 34, 30 }, secondary = { 236, 226, 200 } },
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
		brass = 1200,
		rank = 8,
		look = { style = "LampCap", primary = { 70, 66, 58 }, secondary = { 255, 230, 170 } },
	},
	{
		id = "hat_topper",
		name = "Stationmaster's Topper",
		category = "Headwear",
		rarity = "Legendary",
		description = "A tall hat for a tall reputation.",
		brass = 2000,
		rank = 20,
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
		brass = 1500,
		rank = 12,
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
		description = "Varnished mahogany and brass, the way she left the works in 1872.",
		default = true,
		look = {
			body = { 108, 50, 30 },
			trim = { 201, 160, 82 },
			roof = { 44, 40, 36 },
			accent = { 36, 70, 48 },
			lamp = { 255, 222, 160 },
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
			accent = { 236, 226, 200 },
			lamp = { 255, 210, 150 },
		},
	},
	{
		id = "livery_royal",
		name = "Royal Blue Express",
		category = "Livery",
		rarity = "Rare",
		description = "Deep blue with cream lining.",
		brass = 2400,
		look = {
			body = { 30, 52, 104 },
			trim = { 236, 226, 200 },
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
			accent = { 236, 226, 200 },
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
			accent = { 255, 240, 200 },
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

local ById: { [string]: CosmeticDef } = {}
local Defaults: { [string]: string } = {}
for _, def in Catalog do
	assert(ById[def.id] == nil, `duplicate cosmetic id {def.id}`)
	ById[def.id] = def
	if def.default then
		Defaults[def.category] = def.id
	end
end

return table.freeze({
	List = table.freeze(Catalog),
	ById = table.freeze(ById),
	Defaults = table.freeze(Defaults),
	Categories = table.freeze({ "Lantern", "Headwear", "Trail", "Livery" }),
	RarityOrder = table.freeze({ Standard = 1, Fine = 2, Rare = 3, Legendary = 4 }),
	DailySpecialCount = 3,
	DailySpecialDiscount = 0.2,
})
