--[[
	Limb-loss playtest simulation, format v3 (lib/LimbSim, lib/Humans). Writes replay traces for the
	Zenbook viewer (tools/limbsim/viewer) and a report of many sessions. Simulated people, not real
	players: use it to rank risks and compare tunings, then check against real players.

	Run with:  lune run limbsim                          (300 sessions, ~16 saved traces, summary)
	           lune run limbsim --sessions=1000
	           lune run limbsim --one --seed=123 --out=tools/limbsim/traces/live/s123.json

	Output: tools/limbsim/traces/index.json + <id>.json, tools/limbsim/summary.json
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Loader = require("./lib/Loader")
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

local opts = { sessions = 300, one = false, seed = nil :: number?, out = nil :: string? }
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-(%w+)=?(.*)$")
	if key == "sessions" then
		opts.sessions = tonumber(value) or opts.sessions
	elseif key == "one" then
		opts.one = true
	elseif key == "seed" then
		opts.seed = tonumber(value)
	elseif key == "out" then
		opts.out = value
	end
end

local OUT = "tools/limbsim"

local function names(trace)
	local out = {}
	for _, c in trace.meta.crew do
		table.insert(out, c.name)
	end
	return out
end

local function outcomeOf(stats)
	if stats.armless > 0 then
		return "armless"
	elseif stats.rescues > 0 then
		return "rescued"
	elseif stats.rescueFails > 0 then
		return "rescue failed"
	elseif stats.quits > 0 then
		return "quit"
	elseif stats.died > 0 then
		return "deaths"
	end
	return "calm"
end

-- One fresh session for the viewer's New session button.
if opts.one then
	local seed = opts.seed or (os.time() % 100000)
	local result = LimbSim.run(mods, { seed = seed })
	local out = opts.out or `{OUT}/traces/live/s{seed}.json`
	local dir = string.match(out, "^(.*)/[^/]+$")
	if dir then
		fs.writeDir(dir)
	end
	fs.writeFile(out, serde.encode("json", result.trace))
	print(out)
	return
end

fs.writeDir(OUT .. "/traces")

local rng = mods.Rng.new(4242)
local totals: { [string]: number } = {}
local byStation = {}
local players = {}
local complaints = {}
local bugs = {}
local praise = {}
local saved = {}
local wanted = { armless = 4, rescued = 4, ["rescue failed"] = 3, quit = 3, deaths = 2, calm = 1 }

for i = 1, opts.sessions do
	local preInjured = if rng:next() < 0.2 then 1 else nil
	local result = LimbSim.run(mods, { seed = 2000 + i, preInjured = preInjured })
	local s = result.stats
	for key, value in s do
		if type(value) == "number" then
			totals[key] = (totals[key] or 0) + value
		end
	end
	for _, stop in result.trace.meta.stops do
		local b = byStation[stop.station] or { stops = 0 }
		b.stops += 1
		byStation[stop.station] = b
	end
	for _, p in s.players do
		table.insert(players, p)
	end
	for topic, c in s.complaints do
		local all = complaints[topic] or { count = 0, examples = {} }
		complaints[topic] = all
		all.count += c.count
		for _, ex in c.examples do
			if #all.examples < 5 and not table.find(all.examples, ex) then
				table.insert(all.examples, ex)
			end
		end
	end
	for topic, b in s.bugs do
		local all = bugs[topic] or { topic = topic, count = 0, example = b.example, text = b.text }
		bugs[topic] = all
		all.count += b.count
	end
	for topic, n in s.praise do
		praise[topic] = (praise[topic] or 0) + n
	end
	local kind = outcomeOf(s)
	if (wanted[kind] or 0) > 0 then
		wanted[kind] -= 1
		local id = string.format("%s-%d", (string.gsub(kind, " ", "-")), 2000 + i)
		fs.writeFile(`{OUT}/traces/{id}.json`, serde.encode("json", result.trace))
		table.insert(saved, {
			id = id,
			file = id .. ".json",
			kind = kind,
			crew = names(result.trace),
			stops = s.stops,
			outcome = result.trace.summary.text,
			title = string.format(
				"%s: %s (%d stops)",
				kind,
				table.concat(names(result.trace), ", "),
				s.stops
			),
		})
	end
end
fs.writeFile(OUT .. "/traces/index.json", serde.encode("json", saved, true))

-- breakdowns ----------------------------------------------------------------------------------------
local function mean(list, f): number?
	local sum, n = 0, 0
	for _, x in list do
		local v = f(x)
		if v ~= nil then
			sum += v
			n += 1
		end
	end
	return if n > 0 then math.floor(sum / n * 1000) / 1000 else nil
end
local function groupBy(list, keyOf)
	local groups = {}
	for _, x in list do
		local k = keyOf(x)
		groups[k] = groups[k] or {}
		table.insert(groups[k], x)
	end
	return groups
end
local function slot(hour: number): string
	return if hour < 6
		then "late night (0-6)"
		elseif hour < 12 then "morning (6-12)"
		elseif hour < 17 then "afternoon (12-17)"
		elseif hour < 21 then "evening (17-21)"
		else "night (21-24)"
end
local function breakdown(groups)
	local out = {}
	for k, list in groups do
		local tries, wins, quits = 0, 0, 0
		for _, p in list do
			tries += p.rescueTries
			wins += p.rescueWins
			if p.quit then
				quits += 1
			end
		end
		out[k] = {
			players = #list,
			returnChance = mean(list, function(p)
				return p.returnChance
			end),
			deathsPerPlayer = mean(list, function(p)
				return p.deaths
			end),
			quitShare = math.floor(quits / #list * 100) / 100,
			rescueSuccess = if tries > 0 then math.floor(wins / tries * 100) / 100 else nil,
			rescueTries = tries,
		}
	end
	return out
end
local byDevice = breakdown(groupBy(players, function(p)
	return p.device
end))
local byHour = breakdown(groupBy(players, function(p)
	return slot(p.hour)
end))
local byConnection = breakdown(groupBy(players, function(p)
	return p.connection
end))

-- the rescue alone by device and connection, at typical round trips
local rescue = {}
for _, row in
	{
		{ "Desktop", "ethernet", 0.05 },
		{ "Desktop", "wifi", 0.09 },
		{ "Laptop", "wifi", 0.09 },
		{ "Console", "wifi", 0.1 },
		{ "Tablet", "wifi", 0.1 },
		{ "Phone", "wifi", 0.12 },
		{ "Phone", "mobile", 0.18 },
		{ "Phone", "mobile", 0.28 },
	}
do
	table.insert(rescue, {
		device = row[1],
		connection = row[2],
		rttMs = math.floor(row[3] * 1000),
		rate = LimbSim.rescueRate(mods, row[1], row[2], row[3], 1000, 9),
	})
end

-- who these simulated people are
local population =
	{ ages = {}, devices = {}, hours = {}, regions = {}, motives = {}, connections = {}, players = #players }
for _, p in players do
	local band = if p.age < 13
		then "under 13"
		elseif p.age < 18 then "13-17"
		elseif p.age < 25 then "18-24"
		else "25+"
	population.ages[band] = (population.ages[band] or 0) + 1
	population.devices[p.device] = (population.devices[p.device] or 0) + 1
	population.hours[slot(p.hour)] = (population.hours[slot(p.hour)] or 0) + 1
	population.regions[p.region] = (population.regions[p.region] or 0) + 1
	population.motives[p.motive] = (population.motives[p.motive] or 0) + 1
	population.connections[p.connection] = (population.connections[p.connection] or 0) + 1
end

-- the feature report: a verdict per feature from the numbers, with the evidence it rests on
local function pct(a: number, b: number): number
	return if b > 0 then math.floor(a / b * 100) else 0
end
local function T(k: string): number
	return totals[k] or 0
end
local function count(list, topic): number
	return if list[topic] then list[topic].count else 0
end
local features = {}
local opened, failedHolds = T("rescueOpened"), T("holdsFailed")
table.insert(features, {
	name = "Crew rescue",
	verdict = if pct(opened, failedHolds) < 35
		then "rarely available"
		elseif pct(T("rescues"), opened) < 50 then "too hard"
		else "works",
	evidence = {
		`{pct(opened, failedHolds)}% of failed holds had a crewmate close enough to be offered the rescue ({opened} of {failedHolds})`,
		`{pct(T("rescues"), opened)}% of offered rescues succeeded; {T("unreachable")} crewmates were offered one they could not reach in time`,
		`beats hit {pct(T("beatHits"), T("beatHits") + T("beatMisses"))}% of the time`,
	},
	numbers = {
		offered = opened,
		holdsFailed = failedHolds,
		rescued = T("rescues"),
		failed = T("rescueFails"),
		unreachable = T("unreachable"),
	},
})
local surprised, understood = count(complaints, "items_lost"), praise.items_lost_understood or 0
table.insert(features, {
	name = "Carry priority and overflow",
	verdict = if T("drops") == 0
		then "rarely triggered"
		elseif surprised > understood then "confusing"
		else "understood",
	evidence = {
		`{T("drops")} items dropped by arm loss across {opts.sessions} sessions`,
		`{surprised} players were surprised by the drop; {understood} understood it`,
	},
	numbers = { drops = T("drops"), surprised = surprised, understood = understood },
})
table.insert(features, {
	name = "Tonic regrowth",
	verdict = if T("heals") >= T("tears") * 0.5 then "used" else "underused",
	evidence = { `{T("heals")} arms regrown for {T("tears")} torn (plus arms lost at earlier stops)` },
	numbers = { heals = T("heals"), tears = T("tears") },
})
local doorDeaths = count(bugs, "deadline_at_door")
table.insert(features, {
	name = "Armless return",
	verdict = if T("armless") == 0
		then "rarely triggered"
		elseif doorDeaths > 0 then "harsh at the door"
		else "fair",
	evidence = {
		`{T("armless")} players lost both arms; {T("returned")} made it back aboard`,
		`{doorDeaths} ran out of time within 1.5 s of the train`,
		`{count(complaints, "unclear_timer")} did not understand the countdown`,
	},
	numbers = { armless = T("armless"), returned = T("returned"), doorDeaths = doorDeaths },
})
local lag = count(complaints, "lag")
table.insert(features, {
	name = "Fairness on slow connections",
	verdict = if lag > opts.sessions * 0.2 then "lag hurts" else "acceptable",
	evidence = {
		`{lag} lag complaints in {opts.sessions} sessions`,
		`rescue alone: Desktop/ethernet {math.floor(rescue[1].rate * 100)}% vs Phone/mobile at 280 ms {math.floor(
			rescue[8].rate * 100
		)}%`,
	},
	numbers = { lagComplaints = lag },
})
local comeBack = mean(players, function(p)
	return p.returnChance
end) or 0
table.insert(features, {
	name = "Sessions and mood",
	-- rage and boredom quits say "unhappy"; a low come-back score alone means the runs end flat
	verdict = if T("quitsUnhappy") > #players * 0.15
		then "players leave unhappy"
		elseif comeBack < 0.45 then "few rage-quit, but runs end flat"
		else "players mostly leave content",
	evidence = {
		`{T("quits")} left mid-run in {opts.sessions} sessions: {T("quitsUnhappy")} frustrated or bored, the rest out of time or tired`,
		`average come-back score {math.floor(comeBack * 100)}% (relative: compare hours and devices, not a retention forecast)`,
	},
	numbers = { quits = T("quits"), quitsUnhappy = T("quitsUnhappy"), returnChance = comeBack },
})

local bugList = {}
for _, b in bugs do
	table.insert(bugList, { topic = b.topic, count = b.count, example = b.example, text = b.text })
end
table.sort(bugList, function(a, b)
	return a.count > b.count
end)

local summary = {
	sessions = opts.sessions,
	population = population,
	totals = totals,
	byStation = byStation,
	rescue = rescue,
	feedback = { complaints = complaints, bugs = bugList, praise = praise },
	features = features,
	byHour = byHour,
	byDevice = byDevice,
	byConnection = byConnection,
	note = "Simulated people on the game's own rules (lib/LimbSim, lib/Humans); a model to rank risks, not real player data.",
}
fs.writeFile(OUT .. "/summary.json", serde.encode("json", summary, true))

print(`{opts.sessions} sessions, {#players} simulated people, {#saved} traces saved`)
for _, f in features do
	print(string.format("  %-30s %s", f.name, f.verdict))
	for _, e in f.evidence do
		print("      " .. e)
	end
end
print("complaints:")
for topic, c in complaints do
	print(string.format("  %-22s %4d  e.g. %s", topic, c.count, c.examples[1] or ""))
end
print("bugs (detections):")
for _, b in bugList do
	print(string.format("  %-22s %4d", b.topic, b.count))
end
print("rescue alone:")
for _, r in rescue do
	print(string.format("  %-8s %-9s %4dms %5.1f%%", r.device, r.connection, r.rttMs, r.rate * 100))
end
print("by hour (come back / quit share):")
for k, v in byHour do
	print(string.format("  %-18s n=%-4d %.2f / %.2f", k, v.players, v.returnChance or 0, v.quitShare))
end
