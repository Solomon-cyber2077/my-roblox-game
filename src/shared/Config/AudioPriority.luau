--!strict
--[[
	The mix's priority table (docs/FINAL-DESIGN.md Prompt 7, Milestone 1 part). Data read by
	Controllers/AudioController. It sits beside Config/Audio so the cue table keeps its shape.

	  1 Warnings  departure warnings and the clock (Config/Audio group "Warnings")
	  2 Threat    windup swipe, slam, scream, door-forcing, stalk breath, wake (mix "Cues")
	  3 Feedback  footsteps (mix "Steps"), hit, loot, deposit, UI (mix "Feedback")
	  4 Ambience  drone, wind, rain, train run, station eerie, the hall (mix "Ambience"/"Outdoor")
	  5 Piano     the lobby piano (mix "Piano")

	Higher ducks lower: every SoundGroup of a tier carries one sidechain compressor per group of
	each higher tier, set by that higher tier's `duck` (how hard it pushes everything below it).
	`voices` caps the one-shots a tier plays at once; a cue past the cap is dropped, except in the
	Warnings and Threat tiers, which never drop (Warnings also sit outside the Hush).

	IntentHush: a Hollow's replicated Intent (HollowService, Prompt 3) starts a 0.4 s predictive duck
	of the ambience and steps, for a Hollow targeting this player or within Range of them. Never from
	a Windup already under way; it may fire without a strike and never changes attack timing.
]]

export type Duck = { threshold: number, ratio: number, release: number }
export type Tier = {
	name: string,
	groups: { string }, -- the AudioController SoundGroups in this tier
	duck: Duck,
	voices: number, -- one-shots at once; 0 = no cap
}

local Tiers: { Tier } = {
	{
		name = "Warnings",
		groups = { "Warnings" },
		duck = { threshold = -30, ratio = 8, release = 0.5 },
		voices = 0,
	},
	{
		name = "Threat",
		groups = { "Cues" },
		duck = { threshold = -30, ratio = 8, release = 0.5 },
		voices = 0,
	},
	{
		name = "Feedback",
		groups = { "Steps", "Feedback" },
		duck = { threshold = -26, ratio = 2.5, release = 0.18 },
		voices = 10,
	},
	{
		name = "Ambience",
		groups = { "Ambience" }, -- Outdoor sits inside Ambience and ducks with it
		duck = { threshold = -24, ratio = 1.5, release = 0.4 }, -- CHOICE: only the piano is below
		voices = 8,
	},
	{
		name = "Piano",
		groups = { "Piano" },
		duck = { threshold = 0, ratio = 1, release = 0.1 }, -- the bottom: ducks nothing
		voices = 2,
	},
}

for _, tier in Tiers do
	table.freeze(tier.groups)
	table.freeze(tier.duck)
	table.freeze(tier)
end

return table.freeze({
	Tiers = table.freeze(Tiers),
	IntentHush = table.freeze({
		Seconds = 0.4, -- FIXED
		Ambience = 0.3, -- CHOICE: share of the ambience left at the depth of the hush
		Steps = 0.4, -- CHOICE: share of the footsteps left
		Range = 40, -- studs: a Hollow this near (or targeting you) hushes your mix
	}),
})
