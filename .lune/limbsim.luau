--[[
	Limb-loss playtest simulation (lib/LimbSim). Writes replay traces for the Zenbook viewer
	(tools/limbsim/viewer) and a summary of many sessions.

	Run with:  lune run limbsim                 (400 sessions, 12 saved traces)
	           lune run limbsim --sessions=2000

	Output: tools/limbsim/traces/index.json + <id>.json, tools/limbsim/summary.json
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Loader = require("./lib/Loader")
local Personas = require("./lib/Personas")
local LimbSim = require("./lib/LimbSim")

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared = Loader.roots.Shared
local mods = {
	Injury = load(Shared.Logic.Injury),
	Rescue = load(Shared.Logic.Rescue),
	CarryPriority = load(Shared.Logic.CarryPriority),
	SkillCheck = load(Shared.Logic.SkillCheck),
	Inventory = load(Shared.Logic.Inventory),
	LayoutGen = load(Shared.Logic.LayoutGen),
	StationReach = load(Shared.Logic.StationReach),
	DifficultyModel = load(Shared.Logic.DifficultyModel),
	Rng = load(Shared.Util.Rng),
	InjuryConfig = load(Shared.Config.Injury),
	Difficulty = load(Shared.Config.Difficulty),
	Stations = load(Shared.Config.Stations),
	Tuning = load(Shared.Config.Tuning),
	Items = load(Shared.Config.Items),
}

local sessions = 400
for _, arg in process.args do
	local n = string.match(arg, "^%-%-sessions=(%d+)$")
	if n then
		sessions = tonumber(n) :: number
	end
end

local OUT = "tools/limbsim"
fs.writeDir(OUT .. "/traces")

local ids = {}
for _, persona in Personas.List do
	table.insert(ids, persona.id)
end
table.sort(ids)

local function pickCrew(rng): { string }
	local pool = table.clone(ids)
	local size = rng:int(2, 4)
	local crew = {}
	for _ = 1, size do
		table.insert(crew, table.remove(pool, rng:int(1, #pool)))
	end
	return crew
end

local totals: { [string]: number } = {}
local byStation: { [string]: { armless: number, returned: number, sessions: number, died: number } } = {}
local saved = {}
local wanted = { rescued = 4, failed = 3, armless = 3, calm = 2 }
local rng = Loader.requireNode(Shared.Util.Rng).new(4242)

for i = 1, sessions do
	local station = mods.Stations.Order[rng:int(1, #mods.Stations.Order)]
	local crew = pickCrew(rng)
	-- a third of the crews carry an injury from an earlier stop
	local preInjured = if rng:chance(1 / 3) then rng:int(1, #crew) else nil
	local result =
		LimbSim.session(mods, { seed = 1000 + i, station = station, crew = crew, preInjured = preInjured })
	for key, value in result.stats do
		totals[key] = (totals[key] or 0) + value
	end
	local s = byStation[station] or { armless = 0, returned = 0, sessions = 0, died = 0 }
	s.sessions += 1
	s.armless += result.stats.armless
	s.returned += result.stats.returned
	s.died += result.stats.died
	byStation[station] = s
	-- keep a few of each kind for the viewer
	local kind = if result.stats.armless > 0
		then "armless"
		elseif result.stats.rescues > 0 then "rescued"
		elseif result.stats.rescueFails > 0 then "failed"
		elseif result.stats.grabs == 0 then "calm"
		else nil
	if kind and (wanted[kind] or 0) > 0 then
		wanted[kind] -= 1
		local id = string.format("%s-%s-%d", kind, string.lower(station), 1000 + i)
		fs.writeFile(`{OUT}/traces/{id}.json`, serde.encode("json", result.trace))
		local names = {}
		for _, c in result.trace.meta.crew do
			table.insert(names, c.name)
		end
		table.insert(saved, {
			id = id,
			title = string.format("%s at %s: %s", kind, station, table.concat(names, ", ")),
			file = id .. ".json",
		})
	end
end
-- scripted scenarios for the viewer (labelled as such): someone already one-armed, no Tonic,
-- and the hunter goes for them, so the second loss and the run back can be watched
local scripted = 0
for i = 1, 300 do
	if scripted >= 3 then
		break
	end
	local station = mods.Stations.Order[rng:int(1, #mods.Stations.Order)]
	local crew = pickCrew(rng)
	local result = LimbSim.session(
		mods,
		{ seed = 50000 + i, station = station, crew = crew, preInjured = 1, noTonic = true, focus = 1 }
	)
	if result.stats.armless > 0 then
		scripted += 1
		local id = string.format("scripted-armless-%s-%d", string.lower(station), 50000 + i)
		fs.writeFile(`{OUT}/traces/{id}.json`, serde.encode("json", result.trace))
		table.insert(saved, {
			id = id,
			title = string.format("Scripted: second arm lost at %s, run back to the train", station),
			file = id .. ".json",
		})
	end
end
fs.writeFile(OUT .. "/traces/index.json", serde.encode("json", saved, true))

-- rescue success by persona and device (each persona on its own device, and every persona on every device)
local rescue = {}
for _, persona in Personas.List do
	for deviceId, device in Personas.Devices do
		table.insert(rescue, {
			persona = persona.id,
			device = deviceId,
			rttMs = math.floor(device.ping * 1000),
			own = deviceId == persona.device,
			rate = LimbSim.rescueRate(mods, persona.id, deviceId, 1000, 9),
		})
	end
end

local summary = {
	sessions = sessions,
	totals = totals,
	byStation = byStation,
	rescue = rescue,
	note = "Simulated on the game's own rules (lib/LimbSim); not player or network data.",
}
fs.writeFile(OUT .. "/summary.json", serde.encode("json", summary, true))

print(`{sessions} sessions, {#saved} traces saved`)
for _, key in
	{
		"grabs",
		"escapes",
		"rescues",
		"rescueFails",
		"noRescuer",
		"tears",
		"drops",
		"heals",
		"armless",
		"returned",
		"died",
		"leftBehind",
		"beatHits",
		"beatMisses",
	}
do
	print(string.format("  %-12s %d", key, totals[key] or 0))
end
print("rescue success, each persona on their own device:")
for _, r in rescue do
	if r.own then
		print(string.format("  %-6s %-14s %4dms  %5.1f%%", r.persona, r.device, r.rttMs, r.rate * 100))
	end
end
