--[[
	bot playtest: crews of personas (lib/Personas) play whole runs on the game's own rules
	(lib/PlaytestSim) and the sessions are written as JSON for `lune run playtest-report`.

	Run with:  lune run playtest                          (200 sessions from seed 1)
	           lune run playtest --sessions=500 --seed=1000 --out=playtest/out/hp.json
	           lune run playtest --crew=mia,dev           (that crew every session)
	           lune run playtest --build=baseline         (label stored in every session)
	           lune run playtest --device=LowPhone --first=1   (first session on a low-end phone)
	           lune run playtest --route=Long --chip=1     (force the Long Line; old touch prompts)
	           lune run playtest --cue=0 --framelead=0     (before the hunted cue and frame-stamped presses)

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
	CashOut = load(Shared.Logic.CashOut),
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
local device = args.device -- every player on this device (Personas.Devices), e.g. LowPhone
local first = args.first == "1" -- a first session: the new-hand route and onboarding rules
local route = args.route -- Short | Long, overriding the vote
local actionButton = args.chip ~= "1" -- --chip=1 replays the old tap-the-world-chip touch prompts

-- crew size weights: solo 20%, duo 35%, trio 25%, full 20%
local SIZES = { 0.2, 0.35, 0.25, 0.2 }
local MOBILE_SHARE = 0.78

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
	-- each seat is a phone or tablet player MOBILE_SHARE of the time (Roblox's device mix,
	-- docs/SIM-CALIBRATION.md section 1), drawn without repeats from that platform's personas
	local pools = { Mobile = {}, PC = {} }
	for _, persona in Personas.List do
		table.insert(pools[Personas.Devices[persona.device].platform], persona.id)
	end
	rng:shuffle(pools.Mobile)
	rng:shuffle(pools.PC)
	local crew = {}
	for _ = 1, size do
		local want = if rng:next() < MOBILE_SHARE then "Mobile" else "PC"
		local pool = if #pools[want] > 0 then pools[want] else pools[if want == "PC" then "Mobile" else "PC"]
		table.insert(crew, table.remove(pool))
	end
	return crew
end

local results = {}
local started = os.clock()
for i = 0, sessions - 1 do
	local seed = firstSeed + i
	local ok, session = pcall(Sim.run, mods, {
		seed = seed,
		crew = crewFor(seed),
		build = build,
		device = device,
		first = first,
		route = route,
		actionButton = actionButton,
		huntedCue = args.cue ~= "0", -- --cue=0 replays the build before the hunted cue
		frameLead = args.framelead ~= "0", -- --framelead=0 replays presses without the frame stamp
	})
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
