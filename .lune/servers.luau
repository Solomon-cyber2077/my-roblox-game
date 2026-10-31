--[[
	The server question in the simulator (lib/ServerSim): does a cross-server matchmaking queue beat the
	current hall servers + boarding cars, at the player counts Last Train Out can expect? Runs both setups
	on the same arrivals at several average CCUs (arrival rates calibrated so the simulated average online
	count hits each target), then a sensitivity sweep over the behaviour assumptions at the median CCU.

	Run with:  lune run playtest --sessions=600 --out=playtest/out/runs.json
	           lune run servers --runs=playtest/out/runs.json [--hours=8] [--out=docs/direction/x.md]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Sim = require("./lib/ServerSim")

local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	end
end
if not args.runs then
	print("pass --runs=<playtest json> (lune run playtest --sessions=600 --out=...)")
	process.exit(1)
end
local hours = tonumber(args.hours) or 8
local base = table.clone(Sim.Defaults)
local runs = Sim.runTable(serde.decode("json", fs.readFile(args.runs)), base)
for n = 1, 4 do
	if #runs[n] == 0 then
		print(`no playtest runs with a crew of {n}; run more sessions`)
		process.exit(1)
	end
end

local CCUS = { 10, 25, 50, 100, 200, 500 }
local SEED = 424242

-- arrivals a minute so the current setup's average online count hits the target (Little's law, refined)
local function calibrate(ccu: number, cfg): number
	local rate = ccu / 18 -- the launch CCU estimate's mean visit (18 minutes)
	for _ = 1, 3 do
		local s = Sim.run("current", rate, 3, runs, cfg, SEED)
		local online = s.online / math.max(s.onlineSamples, 1)
		if online > 0 then
			rate *= ccu / online
		end
	end
	return rate
end

local function pct(n: number, d: number): number
	return if d > 0 then 100 * n / d else 0
end
local function quantile(list: { number }, q: number): number
	if #list == 0 then
		return 0
	end
	return list[math.max(1, math.ceil(#list * q))]
end
local function summary(s)
	local playersInRuns = 0
	local crewSum = 0
	for n = 1, 4 do
		playersInRuns += s.crewOf[n]
		crewSum += s.crewOf[n] * n
	end
	return {
		online = s.online / math.max(s.onlineSamples, 1),
		lost = pct(s.churned, s.arrivals),
		median = quantile(s.waits, 0.5),
		p90 = quantile(s.waits, 0.9),
		solo = pct(s.crewOf[1], playersInRuns),
		crew = if playersInRuns > 0 then crewSum / playersInRuns else 0,
		jip = pct(s.jip, s.started),
		fails = s.teleportFails,
	}
end

local lines: { string } = {}
local function say(s: string)
	table.insert(lines, s)
end
say("# Servers in the simulator: hall servers + cars vs a cross-server queue")
say("")
say(
	string.format(
		"%d h simulated per row after a 20%% warm-up; run lengths from %d playtest runs; server size %d.",
		hours,
		#runs[1] + #runs[2] + #runs[3] + #runs[4],
		base.serverSize
	)
)
say("")
say(
	"| avg CCU | arrivals/min | setup | never played % | wait median s | wait p90 s | solo % | avg crew | joined in progress % |"
)
say("| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
local verdicts: { string } = {}
for _, ccu in CCUS do
	local rate = calibrate(ccu, base)
	local cur = summary(Sim.run("current", rate, hours, runs, base, SEED))
	local q = summary(Sim.run("queue", rate, hours, runs, base, SEED))
	for _, row in { { "current", cur }, { "queue", q } } do
		local r = row[2]
		say(
			string.format(
				"| %d | %.2f | %s | %.1f | %.0f | %.0f | %.1f | %.2f | %.1f |",
				ccu,
				rate,
				row[1],
				r.lost,
				r.median,
				r.p90,
				r.solo,
				r.crew,
				r.jip
			)
		)
	end
	local justified = (cur.lost - q.lost) >= 5 or (cur.median - q.median) >= 60
	table.insert(
		verdicts,
		string.format(
			"- %d CCU: queue %s (never played %.1f%% -> %.1f%%, median wait %.0f s -> %.0f s, avg crew %.2f -> %.2f)",
			ccu,
			if justified then "**justified**" else "not justified",
			cur.lost,
			q.lost,
			cur.median,
			q.median,
			cur.crew,
			q.crew
		)
	)
end
say("")
say("Rule (build nothing unless the data justifies it): the queue is justified when it cuts players lost")
say("before their first run by 5 points or more, or the median wait by 60 s or more.")
say("")
for _, v in verdicts do
	say(v)
end

-- sensitivity at the median CCU estimate
say("")
say("## Sensitivity at 100 average CCU (the median estimate)")
say("")
say(
	"| assumption | value | current never played % | queue never played % | current median s | queue median s |"
)
say("| --- | ---: | ---: | ---: | ---: | ---: |")
local SWEEP = {
	{ "patienceMean", { 60, 120, 240 } },
	{ "seekerShare", { 0.4, 0.6, 0.8 } },
	{ "serverSize", { 8, 12, 20 } },
	{ "replayShare", { 0.2, 0.35, 0.6 } },
}
for _, sweep in SWEEP do
	for _, value in sweep[2] do
		local cfg = table.clone(base)
		cfg[sweep[1]] = value
		local rate = calibrate(100, cfg)
		local cur = summary(Sim.run("current", rate, hours, runs, cfg, SEED))
		local q = summary(Sim.run("queue", rate, hours, runs, cfg, SEED))
		say(
			string.format(
				"| %s | %s | %.1f | %.1f | %.0f | %.0f |",
				sweep[1],
				tostring(value),
				cur.lost,
				q.lost,
				cur.median,
				q.median
			)
		)
	end
end
say("")
say(
	"Assumptions and sources: lib/ServerSim.luau Defaults. Patience: casual Roblox players leave in under 2 minutes"
)
say(
	"(GameAnalytics 2025 Roblox report). Server size, party mix, seeker share, replay share and teleport failures are"
)
say("not measured anywhere yet: the sweep shows how much the answer leans on them.")

local text = table.concat(lines, "\n") .. "\n"
print(text)
if args.out then
	fs.writeFile(args.out, text)
end
