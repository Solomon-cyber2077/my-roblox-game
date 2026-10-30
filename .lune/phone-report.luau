--[[
	The low-end mobile check, read from bot playtest sessions (`lune run playtest`).
	Compares labelled runs side by side on what that prompt asks about: the session as a whole,
	the contextual action (missed prompts and the time they cost), Hollow chases and grabs, the
	departure (left behind), the stop-five cash-out, stop length and frame time, and sim errors.

	Run with:  lune run phone-report low=a.json chip=b.json pc=c.json --out=report.md
	(label=file pairs; the first run is the one the others are compared against)
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local PROMPT_RETRY = 1.2 -- seconds a missed tap costs (lib/PlaytestSim)

local runs: { { label: string, sessions: { any } } } = {}
local out = "playtest/phone-report.md"
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key == "out" then
		out = value
	elseif not key then
		local label, file = string.match(arg, "^([%w_%-]+)=(.+)$")
		if label and file then
			table.insert(runs, { label = label, sessions = serde.decode("json", fs.readFile(file)) })
		end
	end
end
if #runs == 0 then
	print("pass label=file pairs from `lune run playtest`, e.g. low=a.json pc=b.json")
	process.exit(1)
end

local function pct(n: number, d: number): string
	return if d > 0 then string.format("%.1f", 100 * n / d) else "-"
end
local function avg(n: number, d: number, f: string?): string
	return if d > 0 then string.format(f or "%.2f", n / d) else "-"
end

type Row = { [string]: string }

local function measure(sessions: { any }): Row
	local m = {
		sessions = 0,
		errors = 0,
		players = 0,
		victories = 0,
		rating = 0,
		replay = 0,
		quit = 0,
		dead = 0,
		left = 0,
		cashed = 0,
		missedCard = 0,
		offered = 0,
		promptMisses = 0,
		containers = 0,
		grabs = 0,
		escapes = 0,
		chases = 0,
		outran = 0,
		checks = 0,
		checkMiss = 0,
		lag = 0,
		frameMs = 0,
		stops = 0,
		dwell = 0,
		visits = 0,
	}
	for _, s in sessions do
		if s.error then
			m.errors += 1
			continue
		end
		m.sessions += 1
		if s.outcome == "Victory" then
			m.victories += 1
		end
		for _, stop in s.stops or {} do
			m.visits += 1
			m.dwell += stop.dwell or 0
		end
		m.stops += s.stopsReached or 0
		for _, e in s.events or {} do
			if e.kind == "lag" then
				m.lag += tonumber(string.match(e.text or "", "^(%d+)")) or 0
			end
		end
		local offeredHere = (s.stopCount or 0) > 5 and (s.stopsReached or 0) >= 5
		for _, p in s.crew or {} do
			local st = p.stats or {}
			m.players += 1
			m.rating += p.rating or 0
			m.replay += if p.wouldReplay then 1 else 0
			m.quit += if p.status == "Quit" then 1 else 0
			m.dead += if p.status == "Dead" then 1 else 0
			m.left += if p.status == "LeftBehind" then 1 else 0
			m.cashed += if p.status == "CashedOut" then 1 else 0
			m.missedCard += if st.missedCashOut then 1 else 0
			if offeredHere then
				m.offered += 1
			end
			m.promptMisses += st.promptMisses or 0
			m.containers += st.containers or 0
			m.grabs += st.grabs or 0
			m.escapes += st.escapes or 0
			m.chases += st.chases or 0
			m.outran += st.outran or 0
			local checks = (st.Great or 0) + (st.Good or 0) + (st.Miss or 0)
			m.checks += checks
			m.checkMiss += st.Miss or 0
			m.frameMs += p.frameMs or 0
		end
	end
	return {
		Sessions = tostring(m.sessions),
		["Sim errors"] = tostring(m.errors),
		Players = tostring(m.players),
		["Victory %"] = pct(m.victories, m.sessions),
		["Rating (1-10)"] = avg(m.rating, m.players, "%.1f"),
		["Would replay %"] = pct(m.replay, m.players),
		["Quit mid-run %"] = pct(m.quit, m.players),
		["Died %"] = pct(m.dead, m.players),
		["Left behind %"] = pct(m.left, m.players),
		["Missed prompts / 100 searches"] = avg(100 * m.promptMisses, m.containers, "%.1f"),
		["Seconds lost to missed prompts / player"] = avg(m.promptMisses * PROMPT_RETRY, m.players, "%.1f"),
		["Chases outrun %"] = pct(m.outran, m.chases),
		["Grabs escaped %"] = pct(m.escapes, m.grabs),
		["Skill-check miss %"] = pct(m.checkMiss, m.checks),
		["Presses lost to lag / session"] = avg(m.lag, m.sessions, "%.1f"),
		["Cash-out taken % (of those offered)"] = pct(m.cashed, m.offered),
		["Cash-out card missed % (of those offered)"] = pct(m.missedCard, m.offered),
		["Avg stops reached"] = avg(m.stops, m.sessions, "%.1f"),
		["Avg stop length s"] = avg(m.dwell, m.visits, "%.0f"),
		["Frame time ms (device, assumed)"] = avg(m.frameMs, m.players, "%.1f"),
	}
end

local ORDER = {
	"Sessions",
	"Sim errors",
	"Players",
	"Victory %",
	"Rating (1-10)",
	"Would replay %",
	"Quit mid-run %",
	"Died %",
	"Left behind %",
	"Missed prompts / 100 searches",
	"Seconds lost to missed prompts / player",
	"Chases outrun %",
	"Grabs escaped %",
	"Skill-check miss %",
	"Presses lost to lag / session",
	"Cash-out taken % (of those offered)",
	"Cash-out card missed % (of those offered)",
	"Avg stops reached",
	"Avg stop length s",
	"Frame time ms (device, assumed)",
}

local rows: { Row } = {}
local header = { "| Metric |" }
local rule = { "| --- |" }
for _, run in runs do
	table.insert(rows, measure(run.sessions))
	table.insert(header, ` {run.label} |`)
	table.insert(rule, " ---: |")
end
local lines = {
	"# Low-end mobile, from the simulator",
	"",
	"Bot playtest sessions (`lune run playtest`), compared side by side. Frame time is the device's assumed",
	"frame rate in lib/Personas, not a measurement: the sim has no renderer.",
	"",
	table.concat(header),
	table.concat(rule),
}
for _, key in ORDER do
	local line = { `| {key} |` }
	for _, row in rows do
		table.insert(line, ` {row[key]} |`)
	end
	table.insert(lines, table.concat(line))
end
local dir = string.match(out, "^(.*)[/\\]")
if dir and not fs.isDir(dir) then
	fs.writeDir(dir)
end
fs.writeFile(out, table.concat(lines, "\n") .. "\n")
print(table.concat(lines, "\n"))
