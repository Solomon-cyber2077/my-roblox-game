--[[
	Fits the bot playtests to real players (`lune run sim-fit`): reads the durable telemetry sink's CSV (Dev
	`telemetry dump`, Logic/TelemetrySink: key,t,name,value,f1,f2,f3) and bot sessions from `lune run playtest`,
	and puts the same numbers side by side per device group, with the real sample's 95% margin and the sim
	knob each gap points at. Once live players exist this is how the sim stops being an estimate.

	Run with:  lune run sim-fit --telemetry=dump.csv sim=a.json [sim2=b.json ...] [--out=fit.md]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local args: { [string]: string } = {}
local simFiles: { string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	else
		local _, file = string.match(arg, "^([%w_%-]+)=(.+)$")
		if file then
			table.insert(simFiles, file)
		end
	end
end
if not args.telemetry or #simFiles == 0 then
	print("usage: lune run sim-fit --telemetry=dump.csv sim=a.json [more=b.json] [--out=fit.md]")
	process.exit(1)
end

local GROUPS = { "phone", "tablet", "desktop" }
local RUN_PHASES = {
	Boarding = true,
	Junction = true,
	Cruise = true,
	Arrival = true,
	Dwell = true,
	LastCall = true,
	Departure = true,
	Terminus = true,
}
-- metric -> the sim knob a gap points at (lib/Personas, lib/PlaytestSim)
local KNOBS = {
	victory = "overall difficulty: Hollow encounter rate, chase speeds, persona skill",
	died = "Hollow encounters and the grab struggle: ENCOUNTER_RATE, awareness, reaction, lag()",
	leftBehind = "reading the departure clock: readsUi, hudMiss, lateBy",
	cashedOut = "the cash-out choice: caution, frustration, thrill and greed weights",
	quit = "patience and tolerance; boredom and frustration growth",
	replay = "wouldReplay: rescale to real AGAIN presses",
}
local ORDER = { "victory", "died", "leftBehind", "cashedOut", "quit", "replay" }

type Tally = {
	players: number,
	victory: number,
	died: number,
	leftBehind: number,
	cashedOut: number,
	quit: number,
	replay: number,
}
local function tally(): Tally
	return { players = 0, victory = 0, died = 0, leftBehind = 0, cashedOut = 0, quit = 0, replay = 0 }
end

-- real players, from the sink: one player per key (placeId/serverId/userId) per run outcome
local real: { [string]: Tally } = {}
for _, g in GROUPS do
	real[g] = tally()
end
local rows = string.split(fs.readFile(args.telemetry), "\n")
type Seen = { device: string?, outcome: string?, leftBehind: boolean, quitInRun: boolean, again: boolean }
local players: { [string]: Seen } = {}
local function seen(key: string): Seen
	local s = players[key]
	if s == nil then
		s = { device = nil, outcome = nil, leftBehind = false, quitInRun = false, again = false }
		players[key] = s
	end
	return s
end
for i, row in rows do
	if i == 1 or row == "" then
		continue
	end
	local c = string.split(row, ",")
	local key, name, f1, f2 = c[1], c[3], c[5], c[6]
	if name == "player_run_outcome" then
		local s = seen(key)
		s.outcome, s.device = f1, f2
	elseif name == "player_eliminated" and f1 == "LeftBehind" then
		seen(key).leftBehind = true
	elseif name == "session_ended" and RUN_PHASES[f1] then
		local s = seen(key)
		s.quitInRun, s.device = true, s.device or f2
	elseif name == "again_pressed" then
		seen(key).again = true
	elseif name == "player_cashed_out" then
		local s = seen(key)
		s.outcome, s.device = "cashed_out", s.device or f2
	end
end
for _, s in players do
	local g = real[s.device or ""]
	if g and (s.outcome or s.quitInRun) then
		g.players += 1
		g.victory += if s.outcome == "victory" then 1 else 0
		g.died += if s.outcome == "eliminated" then 1 else 0
		g.leftBehind += if s.leftBehind then 1 else 0
		g.cashedOut += if s.outcome == "cashed_out" then 1 else 0
		g.quit += if s.quitInRun and s.outcome == nil then 1 else 0
		g.replay += if s.again then 1 else 0
	end
end

-- bot players, from playtest sessions
local sim: { [string]: Tally } = {}
local sessions, crewPlayers = 0, 0
for _, g in GROUPS do
	sim[g] = tally()
end
for _, file in simFiles do
	for _, session in serde.decode("json", fs.readFile(file)) do
		if session.error then
			continue
		end
		sessions += 1
		crewPlayers += #(session.crew or {})
		for _, p in session.crew or {} do
			local g = if p.platform == "PC"
				then "desktop"
				elseif p.device == "Tablet" then "tablet"
				else "phone"
			local t = sim[g]
			t.players += 1
			t.victory += if session.outcome == "Victory" and p.status == "Playing" then 1 else 0
			t.died += if p.status == "Dead" or p.status == "LeftBehind" then 1 else 0
			t.leftBehind += if p.status == "LeftBehind" then 1 else 0
			t.cashedOut += if p.status == "CashedOut" then 1 else 0
			t.quit += if p.status == "Quit" then 1 else 0
			t.replay += if p.wouldReplay then 1 else 0
		end
	end
end

local lines: { string } = { "# Sim vs real players", "" }
local function say(s: string)
	table.insert(lines, s)
end
local totalGap, counted = 0, 0
for _, g in GROUPS do
	local r, s = real[g], sim[g]
	say(`## {g}: {r.players} real players, {s.players} bot players`)
	say("")
	if r.players == 0 or s.players == 0 then
		say("Not enough of one side to compare.")
		say("")
		continue
	end
	say("| Metric | real % | gap margin (95%) | sim % | gap | tune |")
	say("| --- | ---: | ---: | ---: | ---: | --- |")
	for _, m in ORDER do
		local rp = 100 * (r :: any)[m] / r.players
		local sp = 100 * (s :: any)[m] / s.players
		-- both samples are finite: the margin of the difference, not of the real side alone; crewmates share
		-- a run's fate, so each side counts as players / crew size independent samples (the design effect)
		local deff = math.max(crewPlayers / math.max(sessions, 1), 1)
		local function var(pct: number, n: number): number
			local q = math.clamp(pct / 100, 0.05, 0.95)
			return q * (1 - q) * deff / n
		end
		local margin = 196 * math.sqrt(var(rp, r.players) + var(sp, s.players))
		local gap = sp - rp
		local off = math.abs(gap) > margin
		if off then
			totalGap += math.abs(gap)
			counted += 1
		end
		say(
			string.format(
				"| %s | %.1f | %.1f | %.1f | %s%+.1f%s | %s |",
				m,
				rp,
				margin,
				sp,
				if off then "**" else "",
				gap,
				if off then "**" else "",
				if off then KNOBS[m] else "within the margin"
			)
		)
	end
	say("")
end
say(
	if counted == 0
		then "Every metric is inside the real sample's margin."
		else string.format(
			"%d metric(s) outside the margin, %.1f points off on average.",
			counted,
			totalGap / counted
		)
)
say("")
say(
	string.format(
		"The margin covers sampling noise on both sides and crews sharing a fate (%.1f players a crew).",
		crewPlayers / math.max(sessions, 1)
	)
)
local out = table.concat(lines, "\n") .. "\n"
print(out)
if args.out then
	fs.writeFile(args.out, out)
end
