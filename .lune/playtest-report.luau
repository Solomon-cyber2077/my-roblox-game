--[[
	Merges bot playtest sessions (`lune run playtest`) into one Markdown report, and compares
	them with a baseline build when one is given.

	Run with:  lune run playtest-report playtest/out/hp.json playtest/out/zen.json
	           lune run playtest-report a.json b.json --baseline=base-hp.json,base-zen.json --out=playtest/report.md

	Also writes summary.json (the headline numbers) and voices-input.json (a few sessions per
	persona, for persona write-ups) next to the report.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Personas = require("./lib/Personas")

local files: { string } = {}
local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	else
		table.insert(files, arg)
	end
end
local out = args.out or "playtest/report.md"
local outDir = string.match(out, "^(.*)[/\\]") or "."

local function loadAll(list: { string }): { any }
	local sessions = {}
	for _, file in list do
		for _, s in serde.decode("json", fs.readFile(file)) do
			if not s.error then
				table.insert(sessions, s)
			end
		end
	end
	return sessions
end

local function pct(n: number, d: number): number
	return if d > 0 then n / d * 100 else 0
end

local function top(counts: { [string]: number }, n: number): { { string | number } }
	local list = {}
	for k, v in counts do
		table.insert(list, { k, v })
	end
	table.sort(list, function(a, b)
		return (a[2] :: number) > (b[2] :: number)
	end)
	return table.move(list, 1, math.min(n, #list), 1, {})
end

local function summarise(sessions: { any })
	local S = {
		sessions = #sessions,
		victories = 0,
		breakdowns = 0,
		stops = 0,
		brass = 0,
		players = 0,
		rating = 0,
		replay = 0,
		quits = 0,
		deaths = 0,
		left = 0,
		causes = {},
		quitReasons = {},
		byPlatform = {},
		byPersona = {},
		byStop = {},
	}
	local function group(tbl, key)
		local g = tbl[key]
		if not g then
			g = {
				players = 0,
				rating = 0,
				replay = 0,
				quits = 0,
				deaths = 0,
				Great = 0,
				Good = 0,
				Miss = 0,
				grabs = 0,
				escapes = 0,
				lag = 0,
				chases = 0,
				outran = 0,
				loot = 0,
				causes = {},
				quitReasons = {},
			}
			tbl[key] = g
		end
		return g
	end
	for _, s in sessions do
		if s.outcome == "Victory" then
			S.victories += 1
		elseif s.outcome == "Breakdown" then
			S.breakdowns += 1
		end
		S.stops += s.stopsReached
		S.brass += s.brass
		for _, st in s.stops do
			local b = S.byStop[st.stop]
			if not b then
				b = {
					visits = 0,
					deaths = 0,
					left = 0,
					grabs = 0,
					chases = 0,
					loot = 0,
					difficulty = 0,
					dwell = 0,
				}
				S.byStop[st.stop] = b
			end
			b.visits += 1
			b.deaths += st.deaths
			b.left += st.leftBehind
			b.grabs += st.grabs
			b.chases += st.chases
			b.loot += st.lootValue
			b.difficulty += st.difficulty
			b.dwell += st.dwell
		end
		local lagBy = {}
		for _, e in s.events do
			if e.kind == "lag" then
				lagBy[e.who] = (lagBy[e.who] or 0) + (tonumber(string.match(e.text, "^(%d+)")) or 1)
			end
		end
		for _, c in s.crew do
			S.players += 1
			S.rating += c.rating
			S.replay += if c.wouldReplay then 1 else 0
			local lost = c.status == "Dead" or c.status == "LeftBehind"
			if c.status == "Dead" then
				S.deaths += 1
			elseif c.status == "LeftBehind" then
				S.left += 1
			end
			if c.cause then
				S.causes[c.cause] = (S.causes[c.cause] or 0) + 1
			end
			if c.quitReason then
				S.quits += 1
				S.quitReasons[c.quitReason] = (S.quitReasons[c.quitReason] or 0) + 1
			end
			for _, g in { group(S.byPlatform, c.platform), group(S.byPersona, c.id) } do
				g.players += 1
				g.rating += c.rating
				g.replay += if c.wouldReplay then 1 else 0
				g.quits += if c.quitReason then 1 else 0
				g.deaths += if lost then 1 else 0
				g.Great += c.stats.Great
				g.Good += c.stats.Good
				g.Miss += c.stats.Miss
				g.grabs += c.stats.grabs
				g.escapes += c.stats.escapes
				g.chases += c.stats.chases
				g.outran += c.stats.outran
				g.loot += c.stats.lootValue
				g.lag += lagBy[c.name] or 0
				if c.cause then
					g.causes[c.cause] = (g.causes[c.cause] or 0) + 1
				end
				if c.quitReason then
					g.quitReasons[c.quitReason] = (g.quitReasons[c.quitReason] or 0) + 1
				end
			end
		end
	end
	return S
end

local function headline(S)
	local checks = 0
	local miss = 0
	local mobileMiss, pcMiss = 0, 0
	for platform, g in S.byPlatform do
		local n = g.Great + g.Good + g.Miss
		checks += n
		miss += g.Miss
		if platform == "Mobile" then
			mobileMiss = pct(g.Miss, n)
		else
			pcMiss = pct(g.Miss, n)
		end
	end
	local function rating(platform)
		local g = S.byPlatform[platform]
		return if g and g.players > 0 then g.rating / g.players else 0
	end
	return {
		{ "Victory rate %", pct(S.victories, S.sessions) },
		{ "Breakdown rate %", pct(S.breakdowns, S.sessions) },
		{ "Avg stops reached", S.stops / math.max(S.sessions, 1) },
		{ "Avg rating (1-10)", S.rating / math.max(S.players, 1) },
		{ "Would replay %", pct(S.replay, S.players) },
		{ "Quit mid-run %", pct(S.quits, S.players) },
		{ "Died %", pct(S.deaths, S.players) },
		{ "Left behind %", pct(S.left, S.players) },
		{ "Skill-check miss %", pct(miss, checks) },
		{ "PC miss %", pcMiss },
		{ "Mobile miss %", mobileMiss },
		{ "PC rating", rating("PC") },
		{ "Mobile rating", rating("Mobile") },
		{ "Avg brass per run", S.brass / math.max(S.sessions, 1) },
	}
end

local current = loadAll(files)
if #current == 0 then
	print("no sessions: pass the JSON files from `lune run playtest`")
	process.exit(1)
end
local S = summarise(current)
local H = headline(S)
local B, BH
if args.baseline and args.baseline ~= "" then
	local base = loadAll(string.split(args.baseline, ","))
	if #base > 0 then
		B = summarise(base)
		BH = headline(B)
	end
end

local lines: { string } = {}
local function w(text: string)
	table.insert(lines, text)
end
local function f1(x: number): string
	return string.format("%.1f", x)
end

w("# bot playtest report")
w("")
w(
	`{S.sessions} sessions, {S.players} bot players ({#Personas.List} personas, PC and mobile). Built on the game's own rules: routes, stations, loot, fog, collapse, Hollows, skill checks, coal and hull.`
)
w("")
w("## Headline")
w("")
if BH then
	w("| Metric | Baseline | This build | Change |")
	w("| --- | ---: | ---: | ---: |")
	for i, row in H do
		local before = BH[i][2] :: number
		local after = row[2] :: number
		local delta = after - before
		w(`| {row[1]} | {f1(before)} | {f1(after)} | {if delta >= 0 then "+" else ""}{f1(delta)} |`)
	end
else
	w("| Metric | Value |")
	w("| --- | ---: |")
	for _, row in H do
		w(`| {row[1]} | {f1(row[2] :: number)} |`)
	end
end

-- automatic findings
w("")
w("## Findings")
w("")
local findings = 0
local function find(text: string)
	findings += 1
	w(`- {text}`)
end
local pc, mobile = S.byPlatform.PC, S.byPlatform.Mobile
if pc and mobile then
	local pm = pct(pc.Miss, pc.Great + pc.Good + pc.Miss)
	local mm = pct(mobile.Miss, mobile.Great + mobile.Good + mobile.Miss)
	if mm - pm > 10 then
		find(
			`Mobile players miss {f1(mm)}% of skill checks against {f1(pm)}% on PC; {mobile.lag} presses were lost to input lag. Consider a wider zone or more latency tolerance on touch.`
		)
	end
	local pr, mr = pc.rating / pc.players, mobile.rating / mobile.players
	if pr - mr > 0.8 then
		find(`Mobile rates the game {f1(mr)} against {f1(pr)} on PC.`)
	end
end
local prevRate = nil
local stopsSorted = {}
for stop in S.byStop do
	table.insert(stopsSorted, stop)
end
table.sort(stopsSorted)
for _, stop in stopsSorted do
	local b = S.byStop[stop]
	local rate = (b.deaths + b.left) / math.max(b.visits, 1)
	if prevRate and prevRate > 0.05 and rate > prevRate * 2 and b.visits >= 10 then
		find(
			`Difficulty spike at stop {stop}: {f1(rate)} losses per visit against {f1(prevRate)} at the stop before.`
		)
	end
	prevRate = rate
end
local quitPct = pct(S.quits, S.players)
if quitPct > 20 then
	local reasons = top(S.quitReasons, 1)
	find(`{f1(quitPct)}% of players quit mid-run; the top reason is "{reasons[1] and reasons[1][1] or "?"}".`)
end
for id, g in S.byPersona do
	local replay = pct(g.replay, g.players)
	if replay < 40 and g.players >= 5 then
		local p = Personas.byId[id]
		local why = top(g.quitReasons, 1)[1] or top(g.causes, 1)[1]
		find(
			`{p.name} ({p.bio}) would replay only {f1(replay)}% of the time{if why
				then `; mostly "{why[1]}"`
				else ""}.`
		)
	end
end
if pct(S.left, S.players) > 8 then
	find(
		`{f1(pct(S.left, S.players))}% are left behind; check that the departure warning reaches players who are not reading the HUD.`
	)
end
if findings == 0 then
	w("- Nothing stood out.")
end

w("")
w("## PC vs mobile")
w("")
w(
	"| Platform | Players | Rating | Replay % | Quit % | Lost % | Great % | Good % | Miss % | Grabs escaped % | Lag-lost presses |"
)
w("| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
for _, platform in { "PC", "Mobile" } do
	local g = S.byPlatform[platform]
	if g then
		local n = math.max(g.Great + g.Good + g.Miss, 1)
		w(
			`| {platform} | {g.players} | {f1(g.rating / g.players)} | {f1(pct(g.replay, g.players))} | {f1(
				pct(g.quits, g.players)
			)} | {f1(pct(g.deaths, g.players))} | {f1(pct(g.Great, n))} | {f1(pct(g.Good, n))} | {f1(
				pct(g.Miss, n)
			)} | {f1(pct(g.escapes, g.grabs))} | {g.lag} |`
		)
	end
end

w("")
w("## Personas")
w("")
w("| Persona | Device | Players | Rating | Replay % | Quit % | Lost % | Miss % | Outran % | Top problem |")
w("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |")
for _, p in Personas.List do
	local g = S.byPersona[p.id]
	if g then
		local n = math.max(g.Great + g.Good + g.Miss, 1)
		local why = top(g.quitReasons, 1)[1] or top(g.causes, 1)[1]
		w(
			`| {p.name}, {p.age} | {Personas.Devices[p.device].label} | {g.players} | {f1(
				g.rating / g.players
			)} | {f1(pct(g.replay, g.players))} | {f1(pct(g.quits, g.players))} | {f1(
				pct(g.deaths, g.players)
			)} | {f1(pct(g.Miss, n))} | {f1(pct(g.outran, g.chases))} | {why and why[1] or "-"} |`
		)
	end
end

w("")
w("## Stop by stop")
w("")
w(
	"| Stop | Visits | Avg difficulty | Avg dwell s | Losses / visit | Grabs / visit | Chases / visit | Loot / visit |"
)
w("| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |")
for _, stop in stopsSorted do
	local b = S.byStop[stop]
	local v = math.max(b.visits, 1)
	w(
		`| {stop} | {b.visits} | {string.format("%.2f", b.difficulty / v)} | {f1(b.dwell / v)} | {string.format(
			"%.2f",
			(b.deaths + b.left) / v
		)} | {string.format("%.2f", b.grabs / v)} | {string.format("%.2f", b.chases / v)} | {f1(b.loot / v)} |`
	)
end

w("")
w("## How players were lost")
w("")
for _, row in top(S.causes, 8) do
	w(`- {row[1]}: {row[2]}`)
end
w("")
w("## Why players quit")
w("")
local any = false
for _, row in top(S.quitReasons, 8) do
	any = true
	w(`- {row[1]}: {row[2]}`)
end
if not any then
	w("- Nobody quit.")
end
w("")
w(
	"_Simulated players, not people: use this to catch regressions and balance problems between human playtests, not to replace the last one before release._"
)

if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end
fs.writeFile(out, table.concat(lines, "\n") .. "\n")

local summary = {}
for _, row in H do
	summary[row[1] :: string] = row[2]
end
fs.writeFile(outDir .. "/summary.json", serde.encode("json", summary, true))

-- a few sessions per persona for the voices: the ones with the most happening
local picks = {}
for _, p in Personas.List do
	local mine = {}
	for _, s in current do
		for _, c in s.crew do
			if c.id == p.id then
				table.insert(mine, { session = s, me = c })
			end
		end
	end
	table.sort(mine, function(a, b)
		return #a.session.events > #b.session.events
	end)
	for i = 1, math.min(2, #mine) do
		local s, me = mine[i].session, mine[i].me
		local crewNames = {}
		for _, c in s.crew do
			table.insert(crewNames, c.name)
		end
		table.insert(picks, {
			persona = p,
			device = Personas.Devices[p.device],
			crew = crewNames,
			route = s.route,
			outcome = s.outcome,
			stopsReached = s.stopsReached,
			stopCount = s.stopCount,
			brass = s.brass,
			me = me,
			stops = s.stops,
			events = s.events,
		})
	end
end
fs.writeFile(outDir .. "/voices-input.json", serde.encode("json", picks, false))
print(`report: {out} ({S.sessions} sessions{if B then `, baseline {B.sessions}` else ""})`)
