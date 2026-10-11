--!strict
-- Player preferences. Values are stable save keys, not translated UI labels.
return {
	FirstFewRuns = 3,
	MarkerMaxDistance = 96,
	MarkerOffset = 2.5,
	MarkerWidth = 82,
	MarkerHeight = 26,
	Defaults = {
		GraphicsQuality = "Quality",
		BrokenThingMarkers = "FirstFew",
		OperatorsPanel = "Show",
		Hud = "Show",
	},
	Choices = {
		GraphicsQuality = { "Quality", "Performance" },
		BrokenThingMarkers = { "FirstFew", "Always", "Off" },
		OperatorsPanel = { "Show", "Hide" },
		Hud = { "Show", "Hide" },
	},
}
