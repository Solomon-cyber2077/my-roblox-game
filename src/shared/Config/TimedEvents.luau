--!strict
--[[
	Timed events at a stop (Logic/TimedEventSchedule plans them; the server's
	Events/TimedEventDirector runs them). Each comes with a HUD warning Lead seconds
	ahead, lasts `duration` and cleans up after itself. They only run while the doors are
	open (the Dwell phase), never two at once, with a Gap between them, and every one ends
	EndMargin seconds before Last Call. A dwell is roughly 94 to 150 seconds (Config/
	Difficulty Dwell, scaled by the station), so a typical stop gets one, a long one two.

	cue    an existing Config/Audio cue played with the warning
	title  the toast's headline; warning is the line under it
]]

export type Def = {
	weight: number,
	duration: number,
	title: string,
	warning: string,
	cue: string,
	breaks: number?,
}

local Events: { [string]: Def } = {
	-- every Hollow at the stop hunts the crew, and one more claws up at the fog front
	Surge = {
		weight = 1,
		duration = 15,
		title = "SURGE",
		warning = "The Hollows are stirring. Stay near the light!",
		cue = "HollowScream",
	},
	-- the boiler strains: two steam leaks burst once the train is moving again (leaks only burst
	-- while it runs: TrainService.OpenBreach)
	Breakdown = {
		weight = 1,
		duration = 6,
		title = "BOILER STRAIN",
		warning = "The boiler is straining. It will burst once we're moving!",
		cue = "SteamLeak",
		breaks = 2,
	},
}
for _, def in Events do
	table.freeze(def)
end

return table.freeze({
	Lead = 9, -- seconds of warning before an event starts (8 to 10)
	FirstWarn = table.freeze({ 24, 40 }), -- seconds after the doors open the first warning may come
	Gap = table.freeze({ 30, 45 }), -- seconds from the end of one event to the next warning (cooldown)
	EndMargin = 8, -- every event is over this long before Last Call
	MaxPerStop = 2,
	Events = table.freeze(Events),
})
