--[[
	bot playtest: crews of personas (lib/Personas) play whole runs on the game's own rules
	(lib/PlaytestSim) and the sessions are written as JSON for `lune run playtest-report`.

	Run with:  lune run playtest                          (200 sessions from seed 1)
	           lune run playtest --sessions=500 --seed=1000 --out=playtest/out/hp.json
	           lune run playtest --crew=mia,dev           (that crew every session)
	           lune run playtest --build=baseline         (label stored in every session)

]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Loader = require("./lib/Loader")
local Personas = require("./lib/Personas")
local Sim = require("./lib/PlaytestSim")

local function load(node: any): any
	return Loader.requireNode(node)
end

local Shared = Loader.roots.Shared
local mods = {
	Difficulty = load(Shared.Config.Difficulty),
	Tuning = load(Shared.Config.Tuning),
	Stations = load(Shared.Config.Stations),
	Items = load(Shared.Config.Items),
	DifficultyModel = load(Shared.Logic.DifficultyModel),
	Economy = load(Shared.Logic.Economy),
	HazardSchedule = load(Shared.Logic.HazardSchedule),
	Inventory = load(Shared.Logic.Inventory),
	LayoutGen = load(Shared.Logic.LayoutGen),
	Leaks = load(Shared.Logic.Leaks),
	Ledger = load(Shared.Logic.Ledger),
	LootRoll = load(Shared.Logic.LootRoll),
	RouteGen = load(Shared.Logic.RouteGen),
	Routes = load(Shared.Logic.Routes),
	SkillCheck = load(Shared.Logic.SkillCheck),
	StationReach = load(Shared.Logic.StationReach),
	Vote = load(Shared.Logic.Vote),
	Rng = load(Shared.Util.Rng),
}

local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	end
end

local sessions = tonumber(args.sessions) or 200
local firstSeed = tonumber(args.seed) or 1
local out = args.out or "playtest/out/local.json"
local build = args.build or "current"
local fixedCrew = if args.crew then string.split(args.crew, ",") else nil

-- crew size weights: solo 20%, duo 35%, trio 25%, full 20%
local SIZES = { 0.2, 0.35, 0.25, 0.2 }

local function crewFor(seed: number): { string }
	if fixedCrew then
		return fixedCrew
	end
	local rng = mods.Rng.new(mods.Rng.derive(seed, "crew"))
	local roll, size = rng:next(), 1
	local acc = 0
	for i, w in SIZES do
		acc += w
		if roll <= acc then
			size = i
			break
		end
	end
	local pool = {}
	for _, persona in Personas.List do
		table.insert(pool, persona.id)
	end
	rng:shuffle(pool)
	return table.move(pool, 1, size, 1, {})
end

local results = {}
local started = os.clock()
for i = 0, sessions - 1 do
	local seed = firstSeed + i
	local ok, session = pcall(Sim.run, mods, { seed = seed, crew = crewFor(seed), build = build })
	if ok then
		table.insert(results, session)
	else
		table.insert(results, { seed = seed, build = build, error = tostring(session) })
		print(`session {seed} failed: {session}`)
	end
end

local dir = string.match(out, "^(.*)[/\\]")
if dir and not fs.isDir(dir) then
	fs.writeDir(dir)
end
fs.writeFile(out, serde.encode("json", results, false))
print(
	string.format(
		"%d sessions (seeds %d-%d, build %s) in %.1f s -> %s",
		sessions,
		firstSeed,
		firstSeed + sessions - 1,
		build,
		os.clock() - started,
		out
	)
)
