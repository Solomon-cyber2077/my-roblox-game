--[[
	Frame-time probe, for `lune run framecost --probes=<dir>`: run in Studio's command bar on the CLIENT while
	playing, standing where a scene from `lune run audit` is in view (e.g. a stop of one archetype with the
	whole yard on screen, or the train on one biome's line). Set LABEL to that audit target's name first
	(e.g. "Scenery/Highland"). It samples 600 frames and prints one JSON line: mean and 95th-percentile frame
	time, the graphics quality level and the viewport. Save each line as <dir>/<anything>.json.
	Close other apps; keep the quality level the same for every probe.
]]

local LABEL = "Scenery/Highland"
local FRAMES = 600

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local samples: { number } = {}
while #samples < FRAMES do
	table.insert(samples, RunService.RenderStepped:Wait())
end
table.sort(samples)
local total = 0
for _, dt in samples do
	total += dt
end
local quality = UserSettings():GetService("UserGameSettings").SavedQualityLevel
local view = workspace.CurrentCamera.ViewportSize
print(HttpService:JSONEncode({
	label = LABEL,
	msMean = total / #samples * 1000,
	ms95 = samples[math.floor(#samples * 0.95)] * 1000,
	quality = quality.Name,
	viewport = { view.X, view.Y },
}))
