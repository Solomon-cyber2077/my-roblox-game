--[[
	brutesim: the giant Brute's reach-in at a late stop, on the game's own rules.

	Real: every building plan (Logic/BuildingGen, all Config/Buildings kinds), its doors, windows and
	containers; the reach rule (Logic/ReachIn: openings, cover, choice, tell, cooldown); search times
	(Logic/LootRoll.holdSeconds); the struggle (Logic/SkillCheck, judged as lib/PlaytestSim does);
	crew bodies (Tuning.Crew walk) and the Brute's chase (Difficulty.HollowChase x kind chase).
	Modelled, not engine-exact: crew members search containers building by building and stand
	1.5 studs in front of each; the Brute comes at a stop-time share (BRUTE_FROM) and hunts one crew
	member at a time, picked at random among those inside; whether someone notices the tell (a face at
	the window, hands on the frame) is their device's awareness and how much they read the screen;
	pathing round a building is a straight walk at chase speed. Outdoor chases are not modelled here
	(lib/PlaytestSim covers them and does not tell kinds apart).

	Run:  lune run brutesim                         (the Tuning numbers, 4000 stops)
	      lune run brutesim --stops=8000 --sweep=1  (also the ranges in the rule paper)
]]

local process = require("@lune/process")

local Loader = require("./lib/Loader")
local Personas = require("./lib/Personas")

local Shared = Loader.roots.Shared
local function load(node: any): any
	return Loader.requireNode(node)
end

local Buildings = load(Shared.Config.Buildings)
local Difficulty = load(Shared.Config.Difficulty)
local Tuning = load(Shared.Config.Tuning)
local BuildingGen = load(Shared.Logic.BuildingGen)
local LootRoll = load(Shared.Logic.LootRoll)
local ReachIn = load(Shared.Logic.ReachIn)
local SkillCheck = load(Shared.Logic.SkillCheck)
local Rng = load(Shared.Util.Rng)

local args: { [string]: string } = {}
for _, arg in process.args do
	local key, value = string.match(arg, "^%-%-([%w_]+)=(.*)$")
	if key then
		args[key] = value
	end
end
local STOPS = tonumber(args.stops) or 4000
local SWEEP = args.sweep == "1"

local DT = 0.1
local STAND = 1.5 -- studs in front of a container where its searcher stands
local BRUTE_FROM = { 0.25, 0.5 } -- share of the stop gone when the Brute comes (fog spawn times) [guess]
local HUNT_SHARE = 0.6 -- chance it hunts someone inside rather than someone in the open, when both [guess]
local CONTAINERS_EACH = { 4, 7 } -- containers a crew member searches at a late stop (PlaytestSim spots) [guess]
local C = Difficulty.SkillCheck

-- every plan, once -------------------------------------------------------------------
local plans = {}
for kind in Buildings.Defs do
	for seed = 1, 12 do
		local ok, plan = pcall(BuildingGen.generate, kind, seed)
		if ok then
			local spots = {}
			for _, item in plan.items do
				if item.container and item.y <= 1 then
					local room = BuildingGen.room(plan, item.room)
					local cx, cz = item.x, item.z
					if room then
						local mx, mz = (room.rect.x0 + room.rect.x1) / 2, (room.rect.z0 + room.rect.z1) / 2
						local dx, dz = mx - cx, mz - cz
						local len = math.max(math.sqrt(dx * dx + dz * dz), 1e-6)
						cx, cz = cx + dx / len * STAND, cz + dz / len * STAND
					end
					local okHold, hold = pcall(LootRoll.holdSeconds, item.container, "Mid")
					table.insert(spots, { x = cx, z = cz, y = item.y, hold = if okHold then hold else 3 })
				end
			end
			if #spots > 0 then
				table.insert(plans, { kind = kind, plan = plan, spots = spots })
			end
		end
	end
end

local function exposure(cfg)
	local covered, total = 0, 0
	for _, p in plans do
		local openings = ReachIn.openings(p.plan, cfg)
		for _, s in p.spots do
			total += 1
			for _, o in openings do
				if ReachIn.covers(o, s.x, s.y, s.z, cfg) then
					covered += 1
					break
				end
			end
		end
	end
	return covered / math.max(total, 1), total
end

-- the struggle, judged as lib/PlaytestSim judges it -------------------------------------
local function gauss(rng)
	local u1 = math.max(rng:next(), 1e-9)
	local u2 = rng:next()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end
local function idealPress(check)
	local target = check.zoneWidth / 2
	local t = check.startsAt
	while t < check.startsAt + check.sweep do
		if SkillCheck.angleAt(check, t) - SkillCheck.zoneStartAt(check, t) >= target then
			return t
		end
		t += 1 / 240
	end
	return check.startsAt + check.sweep * 0.5
end
local function struggle(rng, persona, device, level, helpers, first)
	local zone = SkillCheck.zoneWidth(level)
	local finish = SkillCheck.finishSeconds(level, zone)
	local tolerance = SkillCheck.tolerance(device.ping)
	local progress, now, id = 0, C.FirstDelay, 0
	local roll = function(lo, hi)
		return rng:range(lo, hi)
	end
	while now < finish do
		id += 1
		local check = SkillCheck.new(id, now, zone, roll)
		local result, pressedAt
		if id == 1 and first and rng:chance(device.noPress * (1.2 - persona.skill)) then
			result = "Miss"
		else
			local spread = persona.jitter * (1 + persona.panic * 0.5)
			local press = idealPress(check) + gauss(rng) * spread + persona.reaction * 0.04
			local shift = if device.tap then -(C.TouchLead or 0) else 0
			local claimed = press + device.latency + 1.5 / device.fps + shift
			local arrived = claimed + device.ping / 2
			result = SkillCheck.judgePress(check, claimed, arrived, tolerance)
			pressedAt = arrived
		end
		local cost
		progress, cost = SkillCheck.apply(progress, result)
		finish -= cost
		for _ = 1, helpers do
			progress = SkillCheck.pry(progress)
		end
		if SkillCheck.freed(progress) then
			return true
		end
		now = (pressedAt or SkillCheck.endsAt(check)) + SkillCheck.gap(roll)
	end
	return false
end

-- one late stop with the Brute -----------------------------------------------------------
local function stop(rng, cfg, level, difficulty)
	local crewSize = rng:int(1, 4)
	local crew = {}
	local stopSeconds = Difficulty.StopClock.Search[1]
		+ (Difficulty.StopClock.Search[2] - Difficulty.StopClock.Search[1]) * difficulty
	-- the stop's buildings worth searching: two, shared by the crew (so crewmates can pry)
	local stopPlans = { plans[rng:int(1, #plans)], plans[rng:int(1, #plans)] }
	for i = 1, crewSize do
		local persona = Personas.List[rng:int(1, #Personas.List)]
		local device = Personas.Devices[persona.device]
		-- one building each, a few containers in it, walked between at the crew's walk
		local b = stopPlans[rng:int(1, 2)]
		local list = {}
		local n = math.min(rng:int(CONTAINERS_EACH[1], CONTAINERS_EACH[2]), #b.spots)
		local order = Rng.new(Rng.derive(rng:int(1, 1e9), "spots")):shuffle(table.clone(b.spots))
		for k = 1, n do
			table.insert(list, order[k])
		end
		crew[i] = {
			persona = persona,
			device = device,
			building = b,
			openings = ReachIn.openings(b.plan, cfg),
			spots = list,
			index = 1,
			left = list[1].hold,
			walking = 0,
			alive = true,
			hp = Tuning.Crew.MaxHealth,
			grabs = 0,
			first = true,
		}
	end
	local chase = (
		Difficulty.HollowChase[1] + (Difficulty.HollowChase[2] - Difficulty.HollowChase[1]) * difficulty
	) * Tuning.HollowKinds.Brute.chase
	local walk = Tuning.Crew.WalkSpeed
	local damage = Difficulty.HollowDamage[1]
		+ (Difficulty.HollowDamage[2] - Difficulty.HollowDamage[1]) * difficulty
	local comeAt = stopSeconds * rng:range(BRUTE_FROM[1], BRUTE_FROM[2])
	local out = {
		reaches = 0,
		dodged = 0,
		escapes = 0,
		deaths = 0,
		pried = 0,
		tells = 0,
		lurkSeconds = 0,
		huntInside = 0,
	}
	local brute = nil -- { target, x, z, track }
	local t = comeAt
	local cooldownUntil = 0
	while t < stopSeconds do
		t += DT
		-- crew members move through their containers
		for _, m in crew do
			if m.alive and m.index <= #m.spots then
				if m.walking > 0 then
					m.walking -= DT
				else
					m.left -= DT
					if m.left <= 0 then
						local from = m.spots[m.index]
						m.index += 1
						local to = m.spots[m.index]
						if to then
							m.left = to.hold
							m.walking = math.sqrt((to.x - from.x) ^ 2 + (to.z - from.z) ^ 2) / walk
						end
					end
				end
			end
		end
		if brute == nil and t >= cooldownUntil then
			local inside = {}
			for _, m in crew do
				if m.alive and m.index <= #m.spots then
					table.insert(inside, m)
				end
			end
			if #inside > 0 and rng:chance(HUNT_SHARE) then
				local m = inside[rng:int(1, #inside)]
				local a = rng:range(0, 2 * math.pi)
				local r = 30 + math.max(m.building.plan.outerX, m.building.plan.outerZ)
				brute = {
					target = m,
					x = math.cos(a) * r,
					z = math.sin(a) * r,
					track = ReachIn.newTrack(),
					noticed = nil,
				}
				out.huntInside += 1
			else
				cooldownUntil = t + 5 -- it hunts in the open a while
			end
		end
		if brute then
			local m = brute.target
			if not m.alive or m.index > #m.spots then
				brute = nil
			else
				local s = m.spots[m.index]
				local standing = m.walking <= 0
				local opening, covered =
					ReachIn.choose(m.openings, s.x, s.y, s.z, brute.x, brute.z, brute.track.cooldown, cfg)
				covered = covered and standing
				brute.track = ReachIn.aim(brute.track, opening)
				if opening then
					local sx, sz = ReachIn.stand(opening, cfg)
					local dx, dz = sx - brute.x, sz - brute.z
					local d = math.sqrt(dx * dx + dz * dz)
					local there = d <= cfg.Arrive
					if not there then
						local stepLen = math.min(chase * DT, d)
						brute.x += dx / d * stepLen
						brute.z += dz / d * stepLen
					end
					local before = brute.track.phase
					local fired
					brute.track, fired = ReachIn.step(
						brute.track,
						{ dt = DT, covered = covered, there = there, lit = false },
						cfg
					)
					if brute.track.phase == "Lurk" then
						out.lurkSeconds += DT
					end
					if brute.track.phase == "Tell" and before ~= "Tell" then
						out.tells += 1
						-- do they see it? a face at the window and hands on the frame, before it reaches
						local p, dev = m.persona, m.device
						local sees =
							rng:chance(dev.awareness * (0.55 + 0.45 * p.readsUi) * (1 - dev.hudMiss * 0.5))
						brute.noticed = if sees then t + p.reaction + 0.25 else nil -- 0.25 s to step back out of reach
					end
					if brute.track.phase == "Tell" and brute.noticed and t >= brute.noticed then
						-- stepped back: the search is cut short and they move on
						out.dodged += 1
						brute.noticed = nil
						m.left = 0
						m.walking = 0.4
					end
					if fired == "Reach" then
						out.reaches += 1
						m.grabs += 1
						local helpers = 0
						for _, other in crew do
							if
								other ~= m
								and other.alive
								and other.building == m.building
								and other.index <= #other.spots
							then
								if rng:chance(other.persona.teamwork * 0.6) then
									helpers += 1
								end
							end
						end
						if helpers > 0 then
							out.pried += 1
						end
						local free = struggle(rng, m.persona, m.device, level, helpers, m.first)
						m.first = false
						if free then
							out.escapes += 1
							m.hp -= damage
							-- hauled out: they lose the rest of that building and come back in
							m.left = 0
							m.walking = 3
							if m.hp <= 0 then
								m.alive = false
								out.deaths += 1
							end
						else
							m.alive = false
							out.deaths += 1
						end
						brute = nil
						cooldownUntil = t + Difficulty.PostGrab.StaggerSeconds + 2
					end
				end
			end
		end
	end
	out.crew = crewSize
	return out
end

local function run(cfg, n, seed)
	local rng = Rng.new(seed)
	local sum = {
		reaches = 0,
		dodged = 0,
		escapes = 0,
		deaths = 0,
		pried = 0,
		tells = 0,
		lurkSeconds = 0,
		huntInside = 0,
		crew = 0,
	}
	for i = 1, n do
		local level = 7 + (i % 4) -- stops 7-10
		local d = (i % 5) / 4
		local o = stop(rng, cfg, level, d)
		for k, v in o do
			sum[k] += v
		end
	end
	return sum
end

local function line(label, cfg)
	local share = exposure(cfg)
	local s = run(cfg, STOPS, 20261117)
	local per = function(x)
		return x / STOPS
	end
	print(
		string.format(
			"%-26s spots in reach %4.1f%% | per Brute stop: tells %.2f, reach-ins %.2f, stepped back %.2f | escape %4.1f%% (pried %4.1f%%) | deaths %.3f",
			label,
			share * 100,
			per(s.tells),
			per(s.reaches),
			per(s.dodged),
			100 * s.escapes / math.max(s.reaches, 1),
			100 * s.pried / math.max(s.reaches, 1),
			per(s.deaths)
		)
	)
	return s
end

local base = table.clone(Tuning.BruteRemake.Reach)
local share, spots = exposure(base)
print(`plans: {#plans} buildings, {spots} container spots; {STOPS} late stops (7-10) with the Brute`)
print(string.format("today's numbers: search spots within reach of an opening %.1f%%", share * 100))
local s = line("Tuning (Depth 4, Tell 1.2)", base)
print(
	string.format(
		"  hunts inside %.2f/stop, lurk %.1f s/stop, avg crew %.2f",
		s.huntInside / STOPS,
		s.lurkSeconds / STOPS,
		s.crew / STOPS
	)
)
if SWEEP then
	for _, depth in { 2, 3, 4, 5, 6 } do
		local cfg = table.clone(base)
		cfg.Depth = depth
		line(`Depth {depth}`, cfg)
	end
	for _, tell in { 0.8, 1.2, 1.6, 2.0 } do
		local cfg = table.clone(base)
		cfg.Tell = tell
		line(`Tell {tell}`, cfg)
	end
	for _, cd in { 4, 6, 10 } do
		local cfg = table.clone(base)
		cfg.Cooldown = cd
		line(`Cooldown {cd}`, cfg)
	end
	for _, search in { 1, 2, 4 } do
		local cfg = table.clone(base)
		cfg.Search = search
		line(`Search {search}`, cfg)
	end
	local cfg = table.clone(base)
	cfg.Through = table.clone(base.Through)
	cfg.Through.Glass = false
	line("closed glass holds it", cfg)
end
