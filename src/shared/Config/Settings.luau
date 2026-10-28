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
		Visibility = tostring(Tuning.Visibility.Default), -- studs, as a string like every save key
		Ambience = "Full", -- the drone and ambience volume (AmbienceLevels)
		Motion = "Full", -- Reduced holds the death witness view still (Controllers/DeathCamController)
		Camera = "Locked", -- Locked: third person at Tuning.Camera.LockZoom, body faces the view; Free: zoom in and out
	},
	-- the Ambience group's volume for each choice (AudioController); warnings, cues and footsteps
	-- are not in it, so they stay at full
	AmbienceLevels = { Full = 1, Half = 0.6, Low = 0.3, Off = 0 },
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
		Ambience = { "Full", "Half", "Low", "Off" },
		Camera = { "Locked", "Free" },
		Motion = { "Full", "Reduced" },
	},
}
