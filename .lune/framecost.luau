--[[
	Frame-time model for phones the sim cannot render on (`lune run framecost`).

	1. The load of every scene comes from `lune run audit` (parts, estimated triangles, lights switched on,
	   shadow casters, particles), which this runs and reads.
	2. Frame times measured in Studio on one machine (tools/studio/perf-probe.luau, one JSON file per scene,
	   `--probes=<dir>`) fit a linear cost: ms = base + per k-tris + per lit light + per shadow + per k-particles.
	3. That machine's 3DMark Wild Life Extreme score (`--ref=<score>`) and each phone's (below, from UL's
	   database) scale the fit to the phone: GPU-bound work grows with the score ratio. CPU-bound work (Lua,
	   physics, draw-call overhead) does not follow a GPU score: treat the phone numbers as a lower bound.

	Without probes it prints each scene's load and the phones' GPU ratios only (nothing is guessed).

	Run with:  lune run framecost
	           lune run framecost --probes=playtest/probes --ref=6000
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	end
end

-- 3DMark Wild Life Extreme, UL benchmarks database (user medians); nil = no published score found.
local PHONES = {
	{
		id = "iPhoneSE",
		label = "iPhone SE 2020 (A13)",
		wle = 1693,
		source = "benchmarks.ul.com: Apple iPhone SE (2020)",
	},
	{ id = "iPhone15", label = "iPhone 15 (A16)", wle = 2868, source = "benchmarks.ul.com: Apple iPhone 15" },
	{
		id = "GalaxyA15",
		label = "Galaxy A15 (Helio G99)",
		wle = 357,
		source = "benchmarks.ul.com: Realme 10 377, Doogee T30 Pro 337 (G99)",
	},
	{ id = "MotoE13", label = "Moto E13 (Unisoc T606)", wle = nil, source = "no score found" },
	{ id = "iPad10", label = "iPad 10th gen (A14)", wle = nil, source = "no score found" },
}
local BUDGET_MS = 1000 / 30 -- a playable floor

-- 1. scene loads from the audit
local audit = process.exec("lune", { "run", "audit" })
local text = string.gsub(audit.stdout .. audit.stderr, "\27%[[%d;]*m", "")
type Load = { parts: number, ktris: number, lights: number, lit: number, shadows: number, kparticles: number }
local loads: { [string]: Load } = {}
local order: { string } = {}
for line in string.gmatch(text, "[^\n]+") do
	local name, parts, ktris, lights, lit, shadows, particles = string.match(
		line,
		"^(%S+)%s+(%d+) parts ~%s*(%d+)k tris%s+(%d+) lights %((%d+) lit, (%d+) shadow%)%s+%d+ emitters %(%s*(%d+) particles%)"
	)
	if name and not loads[name] then
		loads[name] = {
			parts = tonumber(parts) :: number,
			ktris = tonumber(ktris) :: number,
			lights = tonumber(lights) :: number,
			lit = tonumber(lit) :: number,
			shadows = tonumber(shadows) :: number,
			kparticles = (tonumber(particles) :: number) / 1000,
		}
		table.insert(order, name)
	end
end
if #order == 0 then
	print("the audit printed no scene loads; run `lune run audit` and check its output")
	process.exit(1)
end

local lines: { string } = { "# Frame-time model", "" }
local function say(s: string)
	table.insert(lines, s)
end

-- 2. fit on probes, if any
local FEATURES = { "ktris", "lit", "shadows", "kparticles" }
local coef: { number }? = nil
local probes: { { label: string, ms: number } } = {}
if args.probes and fs.isDir(args.probes) then
	for _, file in fs.readDir(args.probes) do
		if string.match(file, "%.json$") then
			local p = serde.decode("json", fs.readFile(args.probes .. "/" .. file))
			if loads[p.label] then
				table.insert(probes, { label = p.label, ms = p.msMean })
			else
				say(`- probe {file}: label "{p.label}" is not an audit target, skipped`)
			end
		end
	end
end

-- least squares on [1, features...] with a light ridge so a few probes cannot blow up a coefficient
local function solve(rows: { { number } }, ys: { number }): { number }
	local n = #rows[1]
	local A: { { number } } = {}
	for i = 1, n do
		A[i] = table.create(n + 1, 0)
		A[i][i] = if i > 1 then 1e-3 else 0
	end
	for r, row in rows do
		for i = 1, n do
			for j = 1, n do
				A[i][j] += row[i] * row[j]
			end
			A[i][n + 1] += row[i] * ys[r]
		end
	end
	for c = 1, n do
		local pivot = c
		for r = c + 1, n do
			if math.abs(A[r][c]) > math.abs(A[pivot][c]) then
				pivot = r
			end
		end
		A[c], A[pivot] = A[pivot], A[c]
		local d = A[c][c]
		if math.abs(d) < 1e-12 then
			continue
		end
		for j = c, n + 1 do
			A[c][j] /= d
		end
		for r = 1, n do
			if r ~= c then
				local f = A[r][c]
				for j = c, n + 1 do
					A[r][j] -= f * A[c][j]
				end
			end
		end
	end
	local out = {}
	for i = 1, n do
		out[i] = A[i][n + 1]
	end
	return out
end

local function features(l: Load): { number }
	local row = { 1 }
	for _, f in FEATURES do
		table.insert(row, (l :: any)[f])
	end
	return row
end

if #probes >= #FEATURES + 1 then
	local rows, ys = {}, {}
	for _, p in probes do
		table.insert(rows, features(loads[p.label]))
		table.insert(ys, p.ms)
	end
	coef = solve(rows, ys)
	say(
		string.format(
			"Fit on %d probes: ms = %.2f + %.3f/k-tri + %.3f/lit light + %.3f/shadow + %.3f/k-particle.",
			#probes,
			coef[1],
			coef[2],
			coef[3],
			coef[4],
			coef[5]
		)
	)
elseif #probes > 0 then
	say(`Only {#probes} probe(s): the fit needs {#FEATURES + 1} scenes or more.`)
end
local ref = tonumber(args.ref)

-- 3. the table
say("")
local header = "| Scene | parts | k-tris | lit | shadows | k-particles |"
local rule = "| --- | ---: | ---: | ---: | ---: | ---: |"
local scaled = coef ~= nil and ref ~= nil
if scaled then
	for _, phone in PHONES do
		header ..= ` {phone.id} ms |`
		rule ..= " ---: |"
	end
end
say(header)
say(rule)
local slow: { string } = {}
for _, name in order do
	local l = loads[name]
	local line = string.format(
		"| %s | %d | %d | %d | %d | %.2f |",
		name,
		l.parts,
		l.ktris,
		l.lit,
		l.shadows,
		l.kparticles
	)
	if scaled then
		local c = coef :: { number }
		local row = features(l)
		local ms = 0
		for i, v in row do
			ms += v * c[i]
		end
		for _, phone in PHONES do
			if phone.wle then
				local m = ms * (ref :: number) / phone.wle
				line ..= string.format(" %.1f |", m)
				if m > BUDGET_MS then
					table.insert(
						slow,
						string.format("%s on %s: %.0f ms (%.0f fps)", name, phone.label, m, 1000 / m)
					)
				end
			else
				line ..= " - |"
			end
		end
	end
	say(line)
end
say("")
say("GPU scores (3DMark Wild Life Extreme):")
for _, phone in PHONES do
	say(`- {phone.label}: {phone.wle or "no score"} ({phone.source})`)
end
if not scaled then
	say("")
	say(
		"No phone frame times yet: pass `--probes=<dir>` (5+ scenes measured with tools/studio/perf-probe.luau)"
	)
	say("and `--ref=<score>`, the measuring machine's 3DMark Wild Life Extreme score.")
elseif #slow > 0 then
	say("")
	say("Under 30 fps (GPU-bound estimate; CPU-bound work makes it slower, not faster):")
	for _, s in slow do
		say(`- {s}`)
	end
end
local out = table.concat(lines, "\n") .. "\n"
print(out)
if args.out then
	fs.writeFile(args.out, out)
end
