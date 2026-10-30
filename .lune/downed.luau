--[[
	Downed release gates in the simulator (Logic/Downed in lib/LimbSim; design: docs/direction/2026-10-29-downed-sol-final-pass.md).

	Run:     lune run downed --bleed=off|15|20|25 [--seed=1] [--sessions=200] --out=x.json
	         matched seeds: the same --seed range for every bleed; crew sizes cycle 1-4
	Report:  lune run downed --report off=a.json 20=b.json [15=..] [25=..] [--out=report.md]
	         the first file is the flag-off baseline

	Rescue success = rescued / all Downed entries (entries with no attempt count as failures). Offer coverage =
	entries / (entries + lethal holds excluded). Intervals are crew-clustered (ratio estimator over sessions).
	Gates (joint, set by the 2026-10-30 direction): Phone >= 70%, Desktop >= 80%, gap <= 9 points, nobody-near deaths -30%, spectating
	-40% against the flag-off baseline. Quitting is not used: the behavioural model would only echo its own
	assumptions. Downed.Enabled stays false whatever this prints.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Loader = require("./lib/Loader")
local LimbSim = require("./lib/LimbSim")

local args: { [string]: string } = {}
local pairs_: { { string } } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=?(.*)$")
	if key then
		args[key] = value
	else
		local label, file = string.match(arg, "^([%w_%-]+)=(.+)$")
		if label then
			table.insert(pairs_, { label, file })
		end
	end
end

if args.report == nil then
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
		Downed = load(Shared.Logic.Downed),
		DownedConfig = load(Shared.Config.Downed),
		Difficulty = load(Shared.Config.Difficulty),
		Stations = load(Shared.Config.Stations),
		Tuning = load(Shared.Config.Tuning),
		Items = load(Shared.Config.Items),
	}
	local bleed = if args.bleed and args.bleed ~= "off" then tonumber(args.bleed) else nil
	local first = tonumber(args.seed) or 1
	local n = tonumber(args.sessions) or 200
	local out = {}
	for i = 0, n - 1 do
		local seed = first + i
		local r = LimbSim.run(
			mods,
			{ seed = seed, size = i % 4 + 1, downed = if bleed then { bleed = bleed } else nil }
		)
		local s = r.stats
		table.insert(out, {
			seed = seed,
			size = i % 4 + 1,
			entries = s.downedEntries,
			rescued = s.downedRescued,
			taken = s.downedTaken,
			failed = s.downedFailed,
			retries = s.downedRetries,
			byDevice = s.downedByDevice,
			excluded = s.downedExcluded,
			noRescuer = s.noRescuer,
			holdsFailed = s.holdsFailed,
			died = s.died,
			spectate = s.spectateSeconds,
			downedSeconds = s.downedSeconds,
			hopeless = s.downedHopeless,
		})
	end
	fs.writeFile(args.out or "downed.json", serde.encode("json", out, false))
	print(`{n} sessions, bleed {args.bleed or "off"}, seeds {first}-{first + n - 1}`)
	return
end

-- report -----------------------------------------------------------------------------------
local function ratio(rows, num: (any) -> number, den: (any) -> number): (number, number)
	local N, D, n = 0, 0, 0
	for _, r in rows do
		N += num(r)
		D += den(r)
		n += 1
	end
	if D == 0 then
		return 0, 0
	end
	local R = N / D
	local acc = 0
	for _, r in rows do
		acc += (num(r) - R * den(r)) ^ 2
	end
	local var = if n > 1 then (n / (n - 1)) * acc / (D * D) else 0
	return R, 1.96 * math.sqrt(var)
end
local function sum(rows, f: (any) -> number): number
	local t = 0
	for _, r in rows do
		t += f(r)
	end
	return t
end
local function dev(name: string, field: string)
	return function(r)
		local d = r.byDevice and r.byDevice[name]
		return if d then d[field] else 0
	end
end

local data = {}
for _, p in pairs_ do
	table.insert(data, { label = p[1], rows = serde.decode("json", fs.readFile(p[2])) })
end
local base = data[1]
local baseNobody = sum(base.rows, function(r)
	return r.noRescuer
end)
local baseSpectate = sum(base.rows, function(r)
	return r.spectate
end)

local L = {
	"# Downed: simulator release gates",
	"",
	`Baseline (flag off): {base.label}, {#base.rows} sessions. Matched seeds; crew sizes 1-4 in turn.`,
	"",
	"| bleed | entries | rescued % (all entries) | Phone % | Desktop % | gap pts | offer coverage % | nobody-near deaths | spectating s | Downed s / entry | hopeless share % | gates |",
	"| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
}
for k = 2, #data do
	local d = data[k]
	local rows = d.rows
	local entries = sum(rows, function(r)
		return r.entries
	end)
	local all, allCi = ratio(rows, function(r)
		return r.rescued
	end, function(r)
		return r.entries
	end)
	local ph, phCi = ratio(rows, dev("Phone", "rescued"), dev("Phone", "entries"))
	local dk, dkCi = ratio(rows, dev("Desktop", "rescued"), dev("Desktop", "entries"))
	local excluded = sum(rows, function(r)
		local t = 0
		for why, c in r.excluded or {} do
			if why ~= "Solo" then -- a solo crew has nobody to offer it to: not a coverage miss
				t += c
			end
		end
		return t
	end)
	local coverage = if entries + excluded > 0 then entries / (entries + excluded) else 0
	local nobody = sum(rows, function(r)
		return r.noRescuer
	end)
	local spectate = sum(rows, function(r)
		return r.spectate
	end)
	local downedS = sum(rows, function(r)
		return r.downedSeconds
	end)
	local hopeless = sum(rows, function(r)
		return r.hopeless
	end)
	local gap = (dk - ph) * 100
	local gates = {}
	local function gate(name: string, ok: boolean)
		table.insert(gates, (if ok then "" else "**") .. name .. (if ok then " ok" else " FAIL**"))
	end
	gate("Phone>=70", ph >= 0.70)
	gate("Desktop>=80", dk >= 0.80)
	gate("gap<=9", gap <= 9)
	gate("nobody-near -30%", baseNobody > 0 and nobody <= baseNobody * 0.7)
	gate("spectating -40%", baseSpectate > 0 and spectate <= baseSpectate * 0.6)
	table.insert(
		L,
		string.format(
			"| %s | %d | %.1f +/- %.1f | %.1f +/- %.1f | %.1f +/- %.1f | %.1f | %.1f | %d (off %d) | %.0f (off %.0f) | %.1f | %.1f | %s |",
			d.label,
			entries,
			all * 100,
			allCi * 100,
			ph * 100,
			phCi * 100,
			dk * 100,
			dkCi * 100,
			gap,
			coverage * 100,
			nobody,
			baseNobody,
			spectate,
			baseSpectate,
			if entries > 0 then downedS / entries else 0,
			if downedS > 0 then 100 * hopeless / downedS else 0,
			table.concat(gates, ", ")
		)
	)
end
table.insert(L, "")
table.insert(L, "Downed.Enabled stays false whatever these gates say: the owner decides.")
local text = table.concat(L, "\n") .. "\n"
print(text)
if args.out then
	fs.writeFile(args.out, text)
end
