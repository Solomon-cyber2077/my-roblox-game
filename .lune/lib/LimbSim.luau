--[[
	Limb-loss playtest simulation (`lune run limbsim`). A crew of personas (lib/Personas) works one
	station on the game's own rules, with limb loss switched on:

	  the yard        LayoutGen + StationReach (walks follow the tile path back to the doors)
	  the Hollow      one hunter, DifficultyModel's chase speed, straight at its prey
	  the grab        every skill check made by SkillCheck and judged by judgePress with the
	                  persona's spread, the device's latency and its ping
	  the rescue      Logic/Rescue: invitation, one rescuer, three beats from that rescuer's hands
	  the injury      Logic/Injury, CarryPriority overflow, Tonic heals (self, ally), the armless
	                  return against Config/Injury.ReturnSeconds

	Modelled, not engine-exact: line of sight is assumed; the Hollow walks through walls; a
	player loots for a fixed time per container; ally heals need the ally within HealReach and a
	Tonic. Every session is seeded and repeatable.

	LimbSim.session(mods, cfg) returns { trace, stats }: the trace follows the format in the
	the limb-tear SPLIT-2 notes (the Zenbook viewer reads it).
]]

local Personas = require("./Personas")

local LimbSim = {}

local DT = 0.25
local LOOT_SECONDS = 4
local DWELL = 110 -- seconds the station stays open in the sim
local HOLLOW_AT = { 18, 40 } -- when the hunter comes out
local GRAB_REACH = 2.5
local TONIC_CHANCE = 0.3 -- a container yields a Tonic this often
local SIGHT = 45 -- studs the hunter notices someone from
local CHASE_GIVE_UP = 15 -- seconds of chasing one person before it loses interest and roams

local function gauss(rng): number
	local u1 = math.max(rng:next(), 1e-9)
	local u2 = rng:next()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function round(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function LimbSim.session(mods, cfg)
	local Injury, Rescue, CarryPriority, SkillCheck =
		mods.Injury, mods.Rescue, mods.CarryPriority, mods.SkillCheck
	local Config, Tuning, Items = mods.InjuryConfig, mods.Tuning, mods.Items
	local crewTuning = Tuning.Crew
	local rng = mods.Rng.new(mods.Rng.derive(cfg.seed, "limbsim"))
	local plan = mods.LayoutGen.generate(cfg.station, cfg.seed, 1)
	local reach = mods.StationReach.measure(plan)
	local arch = mods.Stations.List[cfg.station]
	local d = mods.DifficultyModel.forStop(3, Tuning.Run.StationCount, arch.tier, 1)
	local params = mods.DifficultyModel.params(d, arch, #cfg.crew, nil, 3)
	local hollowSpeed = params.hollowChase
	local tile, cols = plan.tile, plan.cols

	local function centre(key: number): (number, number)
		local gx, gz = key % cols, key // cols
		return -plan.length / 2 + (gx + 0.5) * tile, (gz + 0.5) * tile
	end
	local function keyAt(x: number, z: number): number
		local gx, gz = mods.StationReach.tileOf(plan, x, z)
		return gz * cols + gx
	end
	-- the tile path from (x, z) back to the doors: always to the neighbour nearer the train
	local function pathHome(x: number, z: number): { { number } }
		local key = keyAt(x, z)
		local out = {}
		local guard = 0
		while reach.dist[key] and reach.dist[key] > tile and guard < 400 do
			guard += 1
			local gx, gz = key % cols, key // cols
			local best, bestD = nil, reach.dist[key]
			for _, dir in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local n = (gz + dir[2]) * cols + (gx + dir[1])
				local nd = reach.dist[n]
				if nd and nd < bestD and gx + dir[1] >= 0 and gx + dir[1] < cols then
					best, bestD = n, nd
				end
			end
			if best == nil then
				break
			end
			key = best
			local cx, cz = centre(key)
			table.insert(out, { cx, cz })
		end
		table.insert(out, { math.clamp(x, -8, 8), 1 })
		return out
	end
	local function reversed(list)
		local out = {}
		for i = #list, 1, -1 do
			table.insert(out, list[i])
		end
		return out
	end

	-- loot spots that a walk reaches
	local spots = {}
	for _, c in plan.containers do
		if reach.dist[keyAt(c.x, c.z)] then
			table.insert(spots, { c.x, c.z })
		end
	end
	for _, l in plan.loose do
		if reach.dist[keyAt(l.x, l.z)] then
			table.insert(spots, { l.x, l.z })
		end
	end
	local lootIds = {}
	for id, def in Items do
		if def.kind == "Cargo" or def.kind == "Relic" then
			table.insert(lootIds, id)
		end
	end
	table.sort(lootIds)

	local trace = {
		meta = { seed = cfg.seed, station = cfg.station, crew = {} },
		map = {
			tile = tile,
			cols = cols,
			rows = plan.rows,
			length = plan.length,
			blocked = {},
			buildings = {},
			train = {
				x0 = -plan.length / 2,
				x1 = plan.length / 2,
				z = -4,
			},
		},
		frames = {},
		events = {},
		summary = {},
	}
	for key in plan.blocked do
		table.insert(trace.map.blocked, key)
	end
	table.sort(trace.map.blocked)
	for _, b in plan.buildings do
		local x0 = -plan.length / 2 + b.gx * tile
		local z0 = b.gz * tile
		table.insert(trace.map.buildings, { x0, z0, x0 + b.w * tile, z0 + b.d * tile })
	end

	local t = 0
	local function event(e)
		e.t = round(t)
		table.insert(trace.events, e)
	end

	local base = crewTuning.BackpackSlots
	local crew = {}
	for i, id in cfg.crew do
		local persona = Personas.byId[id]
		local device = Personas.Devices[persona.device]
		local p = {
			id = i,
			persona = persona,
			device = device,
			x = (rng:next() * 2 - 1) * 8,
			z = 1,
			state = "Aboard", -- Aboard | Afield | Looting | Held | Dead | LeftBehind
			arms = Injury.new(),
			items = {},
			path = {},
			trips = 0,
			loot = 0,
			stamina = crewTuning.StaminaMax,
			heal = nil,
			startAt = rng:range(0, 4),
		}
		if cfg.preInjured == i then
			-- lost an arm at an earlier stop (injuries last the run)
			p.arms = Injury.tear(p.arms, if rng:chance(0.5) then "L" else "R", -100, true)
			if not cfg.noTonic then
				table.insert(p.items, Config.HealItem)
			end
		end
		table.insert(crew, p)
		table.insert(trace.meta.crew, {
			id = i,
			name = persona.name,
			persona = persona.id,
			device = device.id,
			rttMs = math.floor(device.ping * 1000),
		})
	end

	local stats = {
		grabs = 0,
		escapes = 0,
		rescues = 0,
		rescueFails = 0,
		noRescuer = 0,
		tears = 0,
		drops = 0,
		heals = 0,
		armless = 0,
		returned = 0,
		died = 0,
		leftBehind = 0,
		beatHits = 0,
		beatMisses = 0,
	}
	local hollow = {
		x = 0,
		z = 0,
		out = false,
		at = rng:range(HOLLOW_AT[1], HOLLOW_AT[2]),
		target = nil,
		reelUntil = 0,
		hold = nil,
	}

	local function speedOf(p): number
		local sprint = p.state == "Afield"
			and p.stamina > 10
			and (Injury.armless(p.arms) or hollow.target == p)
		if sprint then
			p.stamina -= crewTuning.StaminaDrainPerSecond * DT
		else
			p.stamina = math.min(crewTuning.StaminaMax, p.stamina + crewTuning.StaminaRegenPerSecond * DT)
		end
		local carry = mods.Inventory.speedMultiplier({ items = p.items, capacity = 99 })
		return (if sprint then crewTuning.SprintSpeed else crewTuning.WalkSpeed) * p.device.move * carry
	end

	local function walk(p)
		local budget = speedOf(p) * DT
		while budget > 0 and #p.path > 0 do
			local w = p.path[1]
			local dx, dz = w[1] - p.x, w[2] - p.z
			local len = math.sqrt(dx * dx + dz * dz)
			if len <= budget then
				p.x, p.z = w[1], w[2]
				budget -= len
				table.remove(p.path, 1)
			else
				p.x += dx / len * budget
				p.z += dz / len * budget
				budget = 0
			end
		end
	end

	local function goHome(p)
		p.path = pathHome(p.x, p.z)
		p.homeward = true
	end

	local function drop(p)
		local cap = Injury.capacity(base, p.arms)
		local kept, dropped = CarryPriority.overflow(p.items, cap)
		p.items = kept
		if #dropped > 0 then
			stats.drops += #dropped
			event({ type = "drop", who = p.id, items = dropped })
		end
	end

	local function holdsTonic(p): boolean
		return table.find(p.items, Config.HealItem) ~= nil
	end

	local function spend(p)
		local i = table.find(p.items, Config.HealItem)
		if i then
			table.remove(p.items, i)
		end
	end

	-- the hold's skill checks, from the victim's hands: true when they fight free
	local function struggle(p): (boolean, number)
		local zone = SkillCheck.zoneWidth(3)
		local finish = SkillCheck.finishSeconds(3, zone)
		local clock = mods.Difficulty.SkillCheck.FirstDelay
		local progress = 0
		local id = 0
		local roll = function(lo, hi)
			return rng:range(lo, hi)
		end
		local jitter = p.persona.jitter * (1 + p.persona.panic)
		while clock < finish do
			id += 1
			local check = SkillCheck.new(id, clock, zone, roll)
			check.drift = 0
			local aim = check.startsAt
				+ (SkillCheck.greatStart(check) + check.greatWidth / 2) / 360 * check.sweep
			local claimed = aim + gauss(rng) * jitter + p.device.latency
			local arrived = claimed + p.device.ping / 2
			local result = SkillCheck.judgePress(check, claimed, arrived, SkillCheck.tolerance(p.device.ping))
			local penalty
			progress, penalty = SkillCheck.apply(progress, result)
			if result == "Miss" then
				event({ type = "checkMiss", who = p.id })
			end
			finish -= penalty
			if SkillCheck.freed(progress) then
				return true, arrived
			end
			clock += check.sweep + SkillCheck.gap(roll)
		end
		return false, finish
	end

	-- the clock ran out on `p`: the crew's one rescue. Returns "Rescued", "Failed" or "Empty".
	local function rescue(p): (string, any)
		if Injury.targetArm(p.arms, 1) == nil then
			return "Empty", nil
		end
		local reachable = Config.Rescue.Reach + crewTuning.WalkSpeed * Config.Rescue.InviteMax
		local slowest, helpers = 0, {}
		for _, q in crew do
			if q ~= p and (q.state == "Afield" or q.state == "Looting") and Injury.canUseItems(q.arms) then
				local dist = math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2)
				if dist <= reachable then
					slowest = math.max(slowest, q.device.ping)
					table.insert(helpers, { q = q, dist = dist })
				end
			end
		end
		if #helpers == 0 then
			return "Empty", nil
		end
		local session = Rescue.new(1, t, slowest)
		event({ type = "rescueOpen", who = p.id })
		-- each helper who answers arrives after their reaction and the walk; the first is the rescuer
		local first, firstAt = nil, math.huge
		for _, h in helpers do
			if rng:chance(0.35 + 0.65 * h.q.persona.teamwork) then
				local arrive = t
					+ h.q.persona.reaction
					+ math.max(h.dist - Config.Rescue.Reach, 0) / (crewTuning.WalkSpeed * h.q.device.move)
					+ h.q.device.ping / 2
				if arrive < firstAt then
					first, firstAt = h.q, arrive
				end
			end
		end
		if first == nil or not Rescue.join(session, first.id, firstAt, first.device.ping) then
			Rescue.tick(session, session.inviteEndsAt + 0.01)
			return "Failed", first
		end
		-- the rescuer steps in
		first.path = { { p.x + 2, p.z } }
		first.homeward = false
		first.rescuing = true
		event({ type = "rescueJoin", who = p.id, by = first.id })
		local jitter = first.persona.jitter * (1 + 0.5 * first.persona.panic)
		for beat = 1, Rescue.BeatCount do
			local at = Rescue.beatAt(session, beat)
			local claimed = at + gauss(rng) * jitter + first.device.latency
			local arrive = claimed + first.device.ping / 2 + math.abs(gauss(rng)) * 0.015
			Rescue.tick(session, arrive)
			if Rescue.resolved(session) then
				break
			end
			local result = Rescue.press(session, first.id, beat, claimed, arrive)
			if result == "Hit" or result == "Miss" then
				if result == "Hit" then
					stats.beatHits += 1
				else
					stats.beatMisses += 1
				end
				table.insert(trace.events, {
					t = round(t + (arrive - session.openedAt)),
					type = "beat",
					who = p.id,
					by = first.id,
					beat = beat,
					result = result,
				})
			end
		end
		Rescue.tick(session, (Rescue.endsAt(session) :: number) + 1)
		t = Rescue.endsAt(session) :: number
		return session.phase, first
	end

	local function die(p, why: string)
		p.state = "Dead"
		p.heal = nil
		stats.died += 1
		event({ type = "death", who = p.id, text = why })
	end

	-- A grab: the hold plays out on its own clock. The outcome is decided now (every check and the
	-- rescue judged), stamped at the moment it happens, and applied to the yard when the hold ends.
	local function grab(p)
		stats.grabs += 1
		p.state = "Held"
		p.heal = nil
		hollow.target = nil
		hollow.holding = p
		local heldAt = t
		event({ type = "grab", who = p.id })
		local freed, seconds = struggle(p)
		if freed then
			stats.escapes += 1
			p.releaseAt = heldAt + seconds
			p.after = function()
				p.state = "Afield"
				p.immuneUntil = t + 8
				hollow.reelUntil = t + 3
				hollow.ignore, hollow.ignoreUntil = p, t + 10
				event({ type = "escape", who = p.id })
				goHome(p)
			end
			return
		end
		t = heldAt + seconds
		local outcome, rescuer = rescue(p)
		local endAt = t
		t = heldAt
		p.releaseAt = endAt
		p.after = function()
			if outcome == "Rescued" then
				stats.rescues += 1
				stats.tears += 1
				local arm = Injury.targetArm(p.arms, if rng:chance(0.5) then 1 else -1) :: string
				p.arms = Injury.tear(p.arms, arm, t, false)
				event({ type = "tear", who = p.id, by = rescuer and rescuer.id, arm = arm })
				p.state = "Afield"
				p.immuneUntil = t + 8
				hollow.reelUntil = t + Config.Rescue.Stagger
				hollow.ignore, hollow.ignoreUntil = p, t + 10
				drop(p)
				if Injury.armless(p.arms) then
					stats.armless += 1
					event({ type = "returnStart", who = p.id, deadline = round(p.arms.returnBy) })
				elseif holdsTonic(p) then
					p.heal = { doneAt = t + Config.HealSeconds, by = p.id }
					event({ type = "healStart", who = p.id, by = p.id })
				end
				goHome(p)
			else
				if outcome == "Empty" then
					stats.noRescuer += 1
				else
					stats.rescueFails += 1
				end
				die(p, if outcome == "Empty" then "Nobody near enough to rescue" else "The rescue failed")
				hollow.reelUntil = t + 2.6
			end
			if rescuer then
				rescuer.rescuing = nil
				rescuer.path = {}
			end
		end
	end

	local function frame()
		local f = { t = round(t), p = {}, h = {} }
		for _, p in crew do
			f.p[tostring(p.id)] = { round(p.x), round(p.z), p.state, Injury.attribute(p.arms), #p.items }
		end
		if hollow.out then
			table.insert(f.h, { round(hollow.x), round(hollow.z) })
		end
		table.insert(trace.frames, f)
	end

	while t < DWELL do
		t += DT
		-- the hunter
		if not hollow.out and t >= hollow.at then
			local far = spots[rng:int(1, math.max(#spots, 1))] or { 0, 60 }
			hollow.x, hollow.z, hollow.out = far[1], far[2] + 20, true
			event({ type = "hollow", text = "A Hollow comes out" })
		end
		for _, p in crew do
			if p.state == "Held" and p.releaseAt and t >= p.releaseAt then
				local after = p.after
				p.releaseAt, p.after = nil, nil
				hollow.holding = nil
				after()
			end
		end
		if hollow.out and hollow.holding == nil and t >= hollow.reelUntil then
			local best, bestD = nil, math.huge
			for _, p in crew do
				local ignored = hollow.ignore == p and t < (hollow.ignoreUntil or 0)
				if (p.state == "Afield" or p.state == "Looting") and not ignored and not p.rescuing then
					local dist = math.sqrt((p.x - hollow.x) ^ 2 + (p.z - hollow.z) ^ 2)
					if cfg.focus == p.id and dist <= SIGHT * 3 then
						-- scripted scenario: the hunter goes for this one
						best, bestD = p, -1
					elseif dist < bestD and dist <= SIGHT and bestD >= 0 then
						best, bestD = p, dist
					end
				end
			end
			if best ~= hollow.target then
				hollow.chaseFrom = t
			end
			if best and t - (hollow.chaseFrom or t) > CHASE_GIVE_UP then
				hollow.ignore, hollow.ignoreUntil = best, t + 12
				best = nil
			end
			hollow.target = best
			if best == nil then
				-- roam towards a loot spot
				hollow.roam = hollow.roam or spots[rng:int(1, math.max(#spots, 1))] or { 0, 60 }
				local dx, dz = hollow.roam[1] - hollow.x, hollow.roam[2] - hollow.z
				local len = math.sqrt(dx * dx + dz * dz)
				if len < 2 then
					hollow.roam = nil
				else
					local step = math.min(hollowSpeed * 0.4 * DT, len)
					hollow.x += dx / len * step
					hollow.z += dz / len * step
				end
			end
			if best then
				local dx, dz = best.x - hollow.x, best.z - hollow.z
				local len = math.max(bestD, 0.01)
				local step = math.min(hollowSpeed * DT, len)
				hollow.x += dx / len * step
				hollow.z += dz / len * step
				if len - step <= GRAB_REACH and best.z > 4 and t >= (best.immuneUntil or 0) then
					grab(best)
				elseif
					bestD < 30
					and not best.fleeing
					and rng:chance((0.3 + best.persona.caution) * best.device.awareness * DT * 2)
				then
					-- they see it coming and run for the train
					best.fleeing = true
					best.state = "Afield"
					goHome(best)
				end
			end
		end
		for _, p in crew do
			if
				p.state == "Aboard"
				and Injury.count(p.arms) == 1
				and holdsTonic(p)
				and p.heal == nil
				and not p.declined
			then
				-- one-armed with a Tonic: most use it before heading out
				if rng:chance(0.4 + 0.6 * p.persona.caution) then
					p.heal = { doneAt = t + Config.HealSeconds, by = p.id }
					event({ type = "healStart", who = p.id, by = p.id })
				else
					p.declined = true
				end
			end
			if
				p.state == "Aboard"
				and p.heal == nil
				and t >= p.startAt
				and p.trips < 2
				and t < DWELL - 30
				and not Injury.armless(p.arms)
			then
				local spot = spots[rng:int(1, math.max(#spots, 1))]
				if spot then
					p.state = "Afield"
					p.homeward = false
					p.trips += 1
					p.path = reversed(pathHome(spot[1], spot[2]))
					table.insert(p.path, { spot[1], spot[2] })
				end
			elseif p.state == "Afield" then
				walk(p)
				-- a rescuer stays braced at the victim until the hold ends
				if #p.path == 0 and not p.rescuing then
					if p.homeward then
						p.state = "Aboard"
						p.fleeing = nil
						if p.arms.returnBy then
							stats.returned += 1
							p.arms = Injury.board(p.arms)
						end
						event({ type = "board", who = p.id })
						p.loot += #p.items
						p.items = {}
						p.startAt = t + 6
					else
						p.state = "Looting"
						p.lootUntil = t + LOOT_SECONDS
					end
				end
			elseif p.state == "Looting" and t >= p.lootUntil then
				local found = { lootIds[rng:int(1, #lootIds)] }
				if rng:chance(0.5) then
					table.insert(found, lootIds[rng:int(1, #lootIds)])
				end
				if rng:chance(TONIC_CHANCE) then
					table.insert(found, 1, Config.HealItem)
				end
				local inv = mods.Inventory.addMany(
					{ items = p.items, capacity = Injury.capacity(base, p.arms) },
					found
				)
				p.items = inv.items
				p.state = "Afield"
				p.visits = (p.visits or 0) + 1
				local spot = spots[rng:int(1, math.max(#spots, 1))]
				if p.visits < 3 and spot and rng:chance(p.persona.greed) and mods.Inventory.free(inv) > 0 then
					-- on to another container before heading back
					p.path = reversed(pathHome(spot[1], spot[2]))
					table.insert(p.path, { spot[1], spot[2] })
				else
					p.visits = 0
					goHome(p)
				end
			end
			-- the bell: everyone still out heads back with time to walk it (careful ones earlier)
			if
				(p.state == "Afield" or p.state == "Looting")
				and not p.homeward
				and not p.rescuing
				and t >= DWELL - 28 - p.persona.caution * 14
			then
				p.state = "Afield"
				goHome(p)
			end
			-- a Tonic at work
			if p.heal and p.state ~= "Dead" then
				local danger = hollow.out and math.sqrt((p.x - hollow.x) ^ 2 + (p.z - hollow.z) ^ 2) < 6
				if danger or p.state == "Held" then
					p.heal = nil
					event({ type = "healStop", who = p.id })
				elseif t >= p.heal.doneAt then
					local giver = crew[p.heal.by]
					if holdsTonic(giver) then
						spend(giver)
						p.arms = Injury.restore(p.arms)
						stats.heals += 1
						event({ type = "heal", who = p.id, by = giver.id })
						if p.state == "Afield" and not p.homeward then
							goHome(p)
						end
					end
					p.heal = nil
				end
			end
			-- an armless crewmate: a crewmate with a Tonic within reach treats them
			if p.state == "Afield" and Injury.armless(p.arms) and p.heal == nil then
				for _, q in crew do
					if
						q ~= p
						and (q.state == "Afield" or q.state == "Looting")
						and holdsTonic(q)
						and Injury.canUseItems(q.arms)
					then
						if math.sqrt((q.x - p.x) ^ 2 + (q.z - p.z) ^ 2) <= Config.HealReach then
							p.heal = { doneAt = t + Config.HealSeconds, by = q.id }
							event({ type = "healStart", who = p.id, by = q.id })
							break
						end
					end
				end
			end
			if
				p.state ~= "Dead"
				and p.state ~= "Held"
				and Injury.expired(p.arms, t)
				and p.state ~= "Aboard"
			then
				die(p, "Did not make it back in time")
			end
		end
		frame()
	end
	for _, p in crew do
		if p.state == "Afield" or p.state == "Looting" then
			p.state = "LeftBehind"
			stats.leftBehind += 1
			event({ type = "leftBehind", who = p.id })
		end
	end
	frame()
	local alive = 0
	for _, p in crew do
		if p.state == "Aboard" then
			alive += 1
		end
	end
	trace.summary = {
		rescued = stats.rescues,
		died = stats.died,
		returned = stats.returned,
		text = string.format(
			"%d grabs, %d fought free, %d rescued (arm lost), %d rescue failed, %d with nobody near; %d items dropped, %d arms regrown; %d armless runs back, %d made it; %d of %d aboard at departure",
			stats.grabs,
			stats.escapes,
			stats.rescues,
			stats.rescueFails,
			stats.noRescuer,
			stats.drops,
			stats.heals,
			stats.armless,
			stats.returned,
			alive,
			#crew
		),
	}
	event({ type = "outcome", text = trace.summary.text })
	return { trace = trace, stats = stats }
end

--[[
	The rescue alone, many times: a rescuer of this persona on this device, already in reach,
	presses the three beats. Returns the share rescued. Uses the device's ping both ways and a
	small extra arrival spread.
]]
function LimbSim.rescueRate(mods, personaId: string, deviceId: string, n: number, seed: number): number
	local Rescue = mods.Rescue
	local persona = Personas.byId[personaId]
	local device = Personas.Devices[deviceId]
	local rng = mods.Rng.new(mods.Rng.derive(seed, personaId, deviceId))
	local wins = 0
	for i = 1, n do
		local s = Rescue.new(i, 0, device.ping)
		Rescue.join(s, 1, 0.3, device.ping)
		local jitter = persona.jitter * (1 + 0.5 * persona.panic)
		for beat = 1, Rescue.BeatCount do
			local at = Rescue.beatAt(s, beat)
			local claimed = at + gauss(rng) * jitter + device.latency
			local arrive = claimed + device.ping / 2 + math.abs(gauss(rng)) * 0.015
			Rescue.tick(s, arrive)
			if Rescue.resolved(s) then
				break
			end
			Rescue.press(s, 1, beat, claimed, arrive)
		end
		Rescue.tick(s, 10)
		if s.phase == "Rescued" then
			wins += 1
		end
	end
	return wins / n
end

return LimbSim
