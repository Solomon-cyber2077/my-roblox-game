--!strict
-- Player preferences. Values are stable save keys, not translated UI labels.
local Tuning = require(script.Parent.Tuning)

return {
	FirstFewRuns = 3,
	MarkerMaxDistance = 96,
	MarkerOffset = 2.5,
	MarkerWidth = 82,
	MarkerHeight = 26,
	Defaults = {
		GraphicsQuality = "Quality",
		BrokenThingMarkers = "FirstFew",
		Hud = "Show",
		Visibility = tostring(Tuning.Visibility.Radius), -- studs, as a string like every save key
	},
	-- numeric settings (saved as whole-number strings): clamped on load and on the server.
	-- Visibility is the readability floor (Logic/Visibility); its ends come from the dim-screen
	-- harness (tools/visibility), not from guesses
	Ranges = {
		Visibility = { min = Tuning.Visibility.RadiusMin, max = Tuning.Visibility.RadiusMax },
	},
	Choices = {
		GraphicsQuality = { "Quality", "Performance" },
		BrokenThingMarkers = { "FirstFew", "Always", "Off" },
		Hud = { "Show", "Hide" },
	},
}
