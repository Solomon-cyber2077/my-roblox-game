--[[
	Limb-loss playtest simulation (`lune run limbsim`), format v3 (limb-tear SPLIT-3 notes).

	A crew of simulated people (lib/Humans: age, device, connection, the hour they play, moods) plays
	a whole run of several stops on the game's own rules, with limb loss switched on:

	  the stop        LayoutGen + StationReach (walks follow the tile path back to the doors);
	                  DifficultyModel per stop: dwell, Hollow count, spawn times, walk and chase speed
	  the Hollows     wander, notice a player within SIGHT, chase, give up after CHASE_GIVE_UP
	  the grab        every skill check made by SkillCheck and judged by judgePress, with the
	                  player's timing spread (traits, fear, fatigue), device latency and connection
	  the rescue      Logic/Rescue: invitation, one rescuer, three beats from that person's hands
	  the injury      Logic/Injury, CarryPriority overflow, Tonic heals (self, ally), the armless
	                  return against Config/Injury.ReturnSeconds
	  the people      moods move with events and change timing, caution and quitting; they speak
	                  (complaints, confusion, praise, calls to each other) when something real
	                  triggers it; `bug` lines come only from detections in this simulation

	Modelled, not engine-exact: line of sight is assumed, Hollows walk through walls, looting takes
	a fixed time, the ride between stops is a fixed time. Every session is seeded and repeatable.

	LimbSim.run(mods, cfg) -> { trace, stats }.
]]

local Humans = require("./Humans")

local LimbSim = {}

local DT = 0.25
local LOOT_SECONDS = 4
local RIDE_SECONDS = 40 -- between stops (the train ride, vote and departure)
local GRAB_REACH = 2.5
local TONIC_CHANCE = 0.3
local SIGHT = 35
local CHASE_GIVE_UP = 15
local IMMUNE = 8
local STRIKE_HIT = 0.42 -- share of strikes that land on an average player (calibrated to the persona sim)

local gauss = Humans.gauss

local function round(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

local function dist(ax, az, bx, bz): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

function LimbSim.run(mods, cfg)
	local Injury, Rescue, CarryPriority, SkillCheck =
		mods.Injury, mods.Rescue, mods.CarryPriority, mods.SkillCheck
	local Config, Tuning, Items = mods.InjuryConfig, mods.Tuning, mods.Items
	local crewTuning = Tuning.Crew
	local rng = mods.Rng.new(mods.Rng.derive(cfg.seed, "limbsim3"))
	local base = crewTuning.BackpackSlots

	local lootIds = {}
	for id, def in Items do
		if def.kind == "Cargo" or def.kind == "Relic" then
			table.insert(lootIds, id)
		end
	end
	table.sort(lootIds)

	local trace = {
		meta = { seed = cfg.seed, crew = {}, stops = {} },
		map = nil,
		frames = {},
		events = {},
		summary = {},
	}
	local stats = {
		grabs = 0,
		escapes = 0,
		rescues = 0,
		rescueFails = 0,
		noRescuer = 0,
		unreachable = 0,
		tears = 0,
		drops = 0,
		heals = 0,
		armless = 0,
		returned = 0,
		died = 0,
		leftBehind = 0,
		quits = 0,
		quitsUnhappy = 0,
		beatHits = 0,
		beatMisses = 0,
		stops = 0,
		says = 0,
		holdsFailed = 0,
		rescueOpened = 0,
		complaints = {},
		bugs = {},
		praise = {},
		players = {},
	}
	local t = 0
	local stopN = 0

	local function event(e)
		e.t = round(e.t or t)
		table.insert(trace.events, e)
	end

	local crew = {}
	local size = cfg.size or rng:int(2, 4)
	for i = 1, size do
		local h = Humans.new(rng, (cfg.seed * 7 + i * 13) % 997 + 1)
		local p = {
			id = i,
			h = h,
			state = "Aboard", -- Aboard | Afield | Looting | Held | Dead | LeftBehind | Left
			arms = Injury.new(),
			items = {},
			path = {},
			x = 0,
			z = 1,
			stamina = crewTuning.StaminaMax,
			rescueTries = 0,
			rescueWins = 0,
			immuneUntil = 0,
		}
		if cfg.preInjured == i then
			p.arms = Injury.tear(p.arms, if rng:next() < 0.5 then "L" else "R", -100, true)
		end
		table.insert(crew, p)
		table.insert(trace.meta.crew, {
			id = i,
			name = h.name,
			persona = h.motive,
			device = h.deviceId,
			rttMs = math.floor(h.rtt * 1000),
			profile = Humans.profile(h),
		})
	end

	local function say(p, topic: string, cooldown: number?, detail: any?)
		local text = Humans.say(rng, p.h, topic, t, cooldown)
		if text then
			local kind = Humans.KIND[topic] or "social"
			event({ type = "say", who = p.id, kind = kind, topic = topic, text = text, detail = detail })
			stats.says += 1
			if kind == "complaint" or kind == "confusion" then
				local c = stats.complaints[topic] or { count = 0, examples = {} }
				stats.complaints[topic] = c
				c.count += 1
				if #c.examples < 4 and not table.find(c.examples, text) then
					table.insert(c.examples, text)
				end
			elseif kind == "praise" then
				stats.praise[topic] = (stats.praise[topic] or 0) + 1
			end
		end
	end

	-- a bug is only ever a detection of something that actually happened here
	local function bug(p, topic: string, text: string, detail)
		event({ type = "say", who = p.id, kind = "bug", topic = topic, text = text, detail = detail })
		stats.says += 1
		local b = stats.bugs[topic] or { count = 0, example = detail, text = text }
		b.count += 1
		stats.bugs[topic] = b
	end

	local function alive(p)
		return p.state == "Aboard" or p.state == "Afield" or p.state == "Looting" or p.state == "Held"
	end

	local function playStop(n: number)
		local station = mods.Stations.Order[rng:int(1, #mods.Stations.Order)]
		local arch = mods.Stations.List[station]
		local plan = mods.LayoutGen.generate(station, cfg.seed * 31 + n, math.max(1, math.ceil(n / 3)))
		local reach = mods.StationReach.measure(plan)
		local living = 0
		for _, p in crew do
			if alive(p) then
				living += 1
			end
		end
		local d = mods.DifficultyModel.forStop(n, Tuning.Run.StationCount, arch.tier, 1)
		local params = mods.DifficultyModel.params(d, arch, math.max(living, 1), nil, n)
		local dwell = math.clamp(params.dwell or 110, 60, 220)
		local tile, cols = plan.tile, plan.cols

		local function centre(key)
			local gx, gz = key % cols, key // cols
			return -plan.length / 2 + (gx + 0.5) * tile, (gz + 0.5) * tile
		end
		local function keyAt(x, z)
			local gx, gz = mods.StationReach.tileOf(plan, x, z)
			return gz * cols + gx
		end
		local function pathHome(x, z)
			local key = keyAt(x, z)
			local out = {}
			local guard = 0
			while reach.dist[key] and reach.dist[key] > tile and guard < 400 do
				guard += 1
				local gx, gz = key % cols, key // cols
				local best, bestD = nil, reach.dist[key]
				for _, dir in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
					local nx = gx + dir[1]
					local nk = (gz + dir[2]) * cols + nx
					local nd = reach.dist[nk]
					if nd and nd < bestD and nx >= 0 and nx < cols then
						best, bestD = nk, nd
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
		local function pathTo(x, z)
			local back = pathHome(x, z)
			local out = {}
			for i = #back, 1, -1 do
				table.insert(out, back[i])
			end
			table.insert(out, { x, z })
			return out
		end
		local function homeDistance(x, z)
			return reach.dist[keyAt(x, z)] or dist(x, z, 0, 0)
		end

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
		if #spots == 0 then
			spots = { { 0, 40 } }
		end

		local map = {
			tile = tile,
			cols = cols,
			rows = plan.rows,
			length = plan.length,
			blocked = {},
			buildings = {},
			train = { x0 = -plan.length / 2, x1 = plan.length / 2, z = -4 },
		}
		for key in plan.blocked do
			table.insert(map.blocked, key)
		end
		table.sort(map.blocked)
		for _, b in plan.buildings do
			local x0 = -plan.length / 2 + b.gx * tile
			table.insert(map.buildings, { x0, b.gz * tile, x0 + b.w * tile, b.gz * tile + b.d * tile })
		end
		trace.map = trace.map or map
		local stopInfo = { n = n, station = station, startT = round(t), endT = 0, map = map }
		table.insert(trace.meta.stops, stopInfo)
		event({ type = "stop", n = n, station = station, text = `Stop {n}: {station}` })
		stats.stops += 1
		local stopStart = t

		local hollows = {}
		local cap = math.clamp(params.hollowCap or 1, 1, 4)
		local hollowFirstAt = stopStart + dwell * math.clamp(params.firstSpawnU or 0.25, 0.05, 0.7)
		local interval = math.clamp(params.spawnInterval or 30, 10, 90)
		for i = 1, cap do
			table.insert(
				hollows,
				{ out = false, at = hollowFirstAt + (i - 1) * interval, x = 0, z = 0, reelUntil = 0 }
			)
		end
		local chase = params.hollowChase or 16
		local walkSpeed = params.hollowWalk or 8

		for _, p in crew do
			if alive(p) then
				p.state = "Aboard"
				p.x, p.z = (rng:next() * 2 - 1) * 8, 1
				p.path, p.homeward, p.trips, p.visits, p.fleeing = {}, false, 0, 0, nil
				p.startAt = stopStart + rng:range(0.5, 4) + Humans.reaction(p.h)
				p.immuneUntil = 0
				p.confusedUntil = nil
				p.missesBell = nil
			end
		end

		local function speedOf(p, hunted)
			local sprint = p.state == "Afield"
				and p.stamina > 10
				and (Injury.armless(p.arms) or hunted or p.fleeing)
			if sprint then
				p.stamina -= crewTuning.StaminaDrainPerSecond * DT
			else
				p.stamina = math.min(crewTuning.StaminaMax, p.stamina + crewTuning.StaminaRegenPerSecond * DT)
			end
			local carry = mods.Inventory.speedMultiplier({ items = p.items, capacity = 99 })
			return (if sprint then crewTuning.SprintSpeed else crewTuning.WalkSpeed) * p.h.device.move * carry
		end
		local function walk(p, hunted)
			local budget = speedOf(p, hunted) * DT
			while budget > 0 and #p.path > 0 do
				local w = p.path[1]
				local len = dist(w[1], w[2], p.x, p.z)
				if len <= budget then
					p.x, p.z = w[1], w[2]
					budget -= len
					table.remove(p.path, 1)
				else
					p.x += (w[1] - p.x) / len * budget
					p.z += (w[2] - p.z) / len * budget
					budget = 0
				end
			end
		end
		local function goHome(p)
			p.path = pathHome(p.x, p.z)
			p.homeward = true
			p.state = "Afield"
		end
		local function holdsTonic(p)
			return table.find(p.items, Config.HealItem) ~= nil
		end

		local function die(p, why)
			p.state = "Dead"
			p.heal = nil
			stats.died += 1
			Humans.feel(p.h, "died")
			event({ type = "death", who = p.id, text = why })
			for _, q in crew do
				if q ~= p and alive(q) then
					Humans.feel(q.h, "crewDied")
				end
			end
		end

		-- the victim's own checks: (freed, seconds it took, a miss came from a lag spike)
		local function struggle(p)
			local level = math.clamp(n, 1, 7)
			local zone = SkillCheck.zoneWidth(level)
			local finish = SkillCheck.finishSeconds(level, zone)
			local clock = mods.Difficulty.SkillCheck.FirstDelay
			local progress, id = 0, 0
			local roll = function(lo, hi)
				return rng:range(lo, hi)
			end
			local lagged = false
			while clock < finish do
				id += 1
				local check = SkillCheck.new(id, clock, zone, roll)
				check.drift = 0
				local aim = check.startsAt
					+ (SkillCheck.greatStart(check) + check.greatWidth / 2) / 360 * check.sweep
				local claimed = aim + gauss(rng) * Humans.jitter(p.h) + p.h.device.latency
				local oneWay, spike = Humans.oneWay(rng, p.h)
				local result =
					SkillCheck.judgePress(check, claimed, claimed + oneWay, SkillCheck.tolerance(p.h.rtt))
				if result == "Miss" and spike > 0 then
					lagged = true
				end
				local penalty
				progress, penalty = SkillCheck.apply(progress, result)
				finish -= penalty
				if SkillCheck.freed(progress) then
					return true, clock + check.sweep * 0.5, lagged
				end
				clock += check.sweep + SkillCheck.gap(roll)
			end
			return false, finish, lagged
		end

		-- the hold's clock ran out on `p` at time `at`: the crew's one rescue
		local function rescue(p, at)
			if Injury.targetArm(p.arms, 1) == nil then
				return "Armless", nil
			end
			-- as the server offers it (HollowService.openRescue): only to those who could still arrive
			local outer = Config.Rescue.Reach + crewTuning.WalkSpeed * Config.Rescue.InviteMax
			local slowest, near = 0, {}
			for _, q in crew do
				if
					q ~= p
					and (q.state == "Afield" or q.state == "Looting")
					and Injury.canUseItems(q.arms)
				then
					local d2 = dist(q.x, q.z, p.x, p.z)
					if d2 <= outer then
						slowest = math.max(slowest, q.h.rtt)
						table.insert(near, { q = q, dist = d2 })
					end
				end
			end
			local helpers = {}
			local invite = Rescue.inviteSeconds(slowest)
			for _, hlp in near do
				if hlp.dist <= Rescue.arrivalRadius(crewTuning.WalkSpeed, invite, hlp.q.h.rtt) then
					table.insert(helpers, hlp)
				end
			end
			if #helpers == 0 then
				return "Empty", nil
			end
			stats.rescueOpened += 1
			local session = Rescue.new(stats.rescueOpened, at, slowest)
			event({ t = at, type = "rescueOpen", who = p.id })
			local first, firstAt = nil, math.huge
			for _, hlp in helpers do
				local q = hlp.q
				if rng:next() < 0.3 + 0.7 * q.h.traits.teamwork * (1 - q.h.mood.fear * 0.4) then
					local arrive = at
						+ Humans.reaction(q.h)
						+ math.max(hlp.dist - Config.Rescue.Reach, 0) / (crewTuning.WalkSpeed * q.h.device.move)
						+ q.h.rtt / 2
					if arrive <= session.inviteEndsAt then
						if arrive < firstAt then
							first, firstAt = q, arrive
						end
					else
						stats.unreachable += 1
						say(q, "rescue_unreachable", 40)
						bug(
							q,
							"rescue_unreachable",
							"The rescue prompt was offered to me but I could not reach them in time",
							{
								studs = round(hlp.dist),
								needSeconds = round(arrive - at),
								windowSeconds = round(session.inviteEndsAt - at),
							}
						)
					end
				end
			end
			if first == nil or not Rescue.join(session, first.id, firstAt, first.h.rtt) then
				return "Failed", nil
			end
			first.path = { { p.x + 2, p.z } }
			first.homeward = false
			first.rescuing = true
			first.rescueTries += 1
			event({ t = firstAt, type = "rescueJoin", who = p.id, by = first.id })
			local timingMiss, lagMiss = false, false
			for beat = 1, Rescue.BeatCount do
				local beatAt = Rescue.beatAt(session, beat)
				local claimed = beatAt + gauss(rng) * Humans.jitter(first.h) + first.h.device.latency
				local oneWay, spike = Humans.oneWay(rng, first.h)
				local arrive = claimed + oneWay
				Rescue.tick(session, arrive)
				if Rescue.resolved(session) then
					break
				end
				local result = Rescue.press(session, first.id, beat, claimed, arrive)
				if result == "Late" and math.abs(claimed - beatAt) <= Config.Rescue.Window then
					bug(first, "beat_arrived_late", "I pressed in time but the game said too late", {
						beat = beat,
						pressError = round(claimed - beatAt),
						oneWayMs = math.floor(oneWay * 1000),
					})
				end
				if result == "Hit" or result == "Miss" then
					if result == "Hit" then
						stats.beatHits += 1
					else
						stats.beatMisses += 1
						if spike > 0 then
							lagMiss = true
						else
							timingMiss = true
						end
					end
					event({
						t = arrive,
						type = "beat",
						who = p.id,
						by = first.id,
						beat = beat,
						result = result,
					})
				end
			end
			Rescue.tick(session, (Rescue.endsAt(session) :: number) + 1)
			if session.phase ~= "Rescued" then
				if lagMiss then
					Humans.feel(first.h, "lagMiss")
					say(first, "lag", 30)
				elseif timingMiss then
					local touch = first.h.device.input == "touch" and rng:next() < 0.35
					say(first, if touch then "touch_button" else "rescue_timing", 40)
				end
			end
			return session.phase, first
		end

		local function grab(p, hol)
			stats.grabs += 1
			p.state = "Held"
			p.heal = nil
			hol.target, hol.holding = nil, p
			local heldAt = t
			Humans.feel(p.h, "grabbed")
			event({ type = "grab", who = p.id })
			if (p.lastRelease or -100) > t - IMMUNE - 6 then
				say(p, "hollow_again", 40)
			end
			for _, q in crew do
				if q ~= p and alive(q) then
					say(p, "social_help", 30)
					break
				end
			end
			local freed, seconds, lagged = struggle(p)
			if lagged then
				Humans.feel(p.h, "lagMiss")
				say(p, "lag", 30)
			end
			if freed then
				stats.escapes += 1
				p.releaseAt = heldAt + seconds
				p.after = function()
					p.state = "Afield"
					p.immuneUntil = t + IMMUNE
					p.lastRelease = t
					hol.reelUntil = t + 3
					hol.ignore, hol.ignoreUntil = p, t + 20
					Humans.feel(p.h, "escaped")
					event({ type = "escape", who = p.id })
					say(p, "praise_escape", 60)
					goHome(p)
				end
				return
			end
			stats.holdsFailed += 1
			local outcome, rescuer = rescue(p, heldAt + seconds)
			p.releaseAt = if rescuer then heldAt + seconds + 3 else heldAt + seconds
			p.after = function()
				if outcome == "Rescued" then
					stats.rescues += 1
					stats.tears += 1
					rescuer.rescueWins += 1
					local arm = Injury.targetArm(p.arms, if rng:next() < 0.5 then 1 else -1) :: string
					p.arms = Injury.tear(p.arms, arm, t, false)
					event({ type = "tear", who = p.id, by = rescuer.id, arm = arm })
					p.state = "Afield"
					p.immuneUntil = t + IMMUNE
					p.lastRelease = t
					hol.reelUntil = t + Config.Rescue.Stagger
					hol.ignore, hol.ignoreUntil = p, t + 20
					Humans.feel(p.h, "rescued")
					Humans.feel(rescuer.h, "rescuedOther")
					say(p, "praise_rescue", 30)
					Humans.feel(p.h, "armLost")
					local kept, dropped = CarryPriority.overflow(p.items, Injury.capacity(base, p.arms))
					p.items = kept
					if #dropped > 0 then
						stats.drops += #dropped
						Humans.feel(p.h, "itemsLost")
						event({ type = "drop", who = p.id, items = dropped })
						say(
							p,
							if rng:next() < p.h.traits.readsUi then "items_lost_understood" else "items_lost",
							30
						)
					end
					if Injury.armless(p.arms) then
						stats.armless += 1
						event({ type = "returnStart", who = p.id, deadline = round(p.arms.returnBy) })
						-- someone who misses the HUD does not set off straight away
						if rng:next() < (1 - p.h.traits.readsUi) * 0.6 then
							p.confusedUntil = t + rng:range(3, 10)
						else
							say(p, "armless_run", 30)
						end
						for _, q in crew do
							if q ~= p and alive(q) then
								say(q, "social_call", 20)
								break
							end
						end
					elseif holdsTonic(p) then
						p.heal = { doneAt = t + Config.HealSeconds, by = p.id }
						event({ type = "healStart", who = p.id, by = p.id })
					end
					goHome(p)
				else
					if outcome == "Empty" or outcome == "Armless" then
						stats.noRescuer += 1
						if outcome == "Empty" and #crew > 1 then
							say(p, "nobody_near", 40)
						end
					else
						stats.rescueFails += 1
						if rescuer then
							Humans.feel(rescuer.h, "rescueFailedOther")
						end
					end
					die(
						p,
						if outcome == "Empty"
							then "Nobody near enough to rescue"
							elseif outcome == "Armless" then "Taken with no arms left"
							else "The rescue failed"
					)
					hol.reelUntil = t + 2.6
				end
				if rescuer then
					rescuer.rescuing = nil
					rescuer.path = {}
				end
			end
		end

		local function frame()
			local f = { t = round(t), stop = n, p = {}, h = {} }
			for _, p in crew do
				local m = p.h.mood
				f.p[tostring(p.id)] = {
					round(p.x),
					round(p.z),
					p.state,
					Injury.attribute(p.arms),
					#p.items,
					{
						round(m.fear),
						round(m.frustration),
						round(m.fun),
						round(m.boredom),
						round(m.fatigue),
						round(m.energy),
					},
				}
			end
			for _, hol in hollows do
				if hol.out then
					table.insert(f.h, { round(hol.x), round(hol.z) })
				end
			end
			table.insert(trace.frames, f)
		end

		local bellAt = stopStart + dwell
		while t < bellAt do
			t += DT
			-- the Hollows
			for _, hol in hollows do
				if not hol.out and t >= hol.at then
					local far = spots[rng:int(1, #spots)]
					hol.x, hol.z, hol.out = far[1], far[2] + 15, true
					event({ type = "hollow", text = "A Hollow comes out" })
				end
				if hol.out and hol.holding == nil and t >= hol.reelUntil then
					local best, bestD = nil, math.huge
					for _, p in crew do
						local ignored = hol.ignore == p and t < (hol.ignoreUntil or 0)
						if
							(p.state == "Afield" or p.state == "Looting")
							and not ignored
							and not p.rescuing
						then
							local d2 = dist(p.x, p.z, hol.x, hol.z)
							if d2 < bestD and d2 <= SIGHT * (if cfg.focus == p.id then 3 else 1) then
								best, bestD = p, d2
							end
						end
					end
					if best ~= hol.target then
						hol.chaseFrom = t
					end
					if best and t - (hol.chaseFrom or t) > CHASE_GIVE_UP then
						hol.ignore, hol.ignoreUntil = best, t + 12
						best = nil
					end
					hol.target = best
					if best then
						local len = math.max(bestD, 0.01)
						local step = math.min(chase * DT, len)
						hol.x += (best.x - hol.x) / len * step
						hol.z += (best.z - hol.z) / len * step
						local notice = (0.3 + best.h.traits.caution + best.h.mood.fear * 0.3)
							* best.h.device.awareness
							* DT
							* 2
						if len - step <= GRAB_REACH and best.z > 4 and t >= best.immuneUntil then
							-- a strike can miss: the alert sidestep it and run (STRIKE_HIT, less for the aware)
							if
								rng:next()
								< STRIKE_HIT
									* (1.3 - best.h.device.awareness * 0.5 - best.h.traits.skill * 0.3)
							then
								grab(best, hol)
							else
								best.immuneUntil = t + 3
								hol.reelUntil = t + 1.2
								best.fleeing = true
								goHome(best)
							end
						elseif bestD < 30 and not best.fleeing and rng:next() < notice then
							best.fleeing = true
							goHome(best)
						end
					else
						hol.roam = hol.roam or spots[rng:int(1, #spots)]
						local len = dist(hol.roam[1], hol.roam[2], hol.x, hol.z)
						if len < 2 then
							hol.roam = nil
						else
							local step = math.min(walkSpeed * 0.5 * DT, len)
							hol.x += (hol.roam[1] - hol.x) / len * step
							hol.z += (hol.roam[2] - hol.z) / len * step
						end
					end
				end
			end
			-- holds that ended
			for _, p in crew do
				if p.state == "Held" and p.releaseAt and t >= p.releaseAt then
					local after = p.after
					p.releaseAt, p.after = nil, nil
					for _, hol in hollows do
						if hol.holding == p then
							hol.holding = nil
						end
					end
					after()
				end
			end
			-- the crew
			for _, p in crew do
				local threat = 0
				for _, hol in hollows do
					if hol.out then
						threat = math.max(threat, math.clamp(1 - dist(p.x, p.z, hol.x, hol.z) / 60, 0, 1))
					end
				end
				if p.state == "Held" then
					threat = 1
				end
				Humans.drift(
					p.h,
					DT,
					if alive(p) then threat else 0,
					p.state == "Aboard" or p.state == "Dead",
					p.state == "Aboard"
				)
				if p.state == "Dead" and p.h.mood.boredom > 0.6 then
					say(p, "boring_wait", 240)
				end
				if alive(p) and Humans.tired(p.h) > 0.65 then
					say(p, "tired", 240)
				end
				if alive(p) and p.h.mood.fear > 0.35 and p.h.mood.fun > 0.45 and rng:next() < 0.002 then
					say(p, "praise_tension", 300)
				end
				local hunted = false
				for _, hol in hollows do
					if hol.target == p then
						hunted = true
					end
				end
				if
					p.state == "Aboard"
					and Injury.count(p.arms) == 1
					and holdsTonic(p)
					and p.heal == nil
					and not p.declined
				then
					if rng:next() < 0.4 + 0.6 * p.h.traits.caution then
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
					and p.trips < 3
					and t < bellAt - 30
					and not Injury.armless(p.arms)
				then
					local spot = spots[rng:int(1, #spots)]
					p.homeward, p.visits = false, 0
					p.trips += 1
					p.path = pathTo(spot[1], spot[2])
					p.state = "Afield"
				elseif p.state == "Afield" then
					-- someone who missed the HUD stands there a moment, not knowing what the number is
					if not (p.confusedUntil and t < p.confusedUntil) then
						walk(p, hunted)
					end
					if #p.path == 0 and not p.rescuing then
						if p.homeward then
							p.state = "Aboard"
							p.fleeing = nil
							Humans.feel(p.h, "boarded")
							if p.arms.returnBy then
								stats.returned += 1
								p.arms = Injury.board(p.arms)
							end
							event({ type = "board", who = p.id })
							-- as in the game: cargo is loaded into the train, tools (Tonics) stay packed
							local kept = mods.Inventory.splitCargo({ items = p.items, capacity = 99 })
							p.items = kept.items
							p.startAt = t + 6 + Humans.reaction(p.h) * 4
						else
							p.state = "Looting"
							p.lootUntil = t + LOOT_SECONDS
						end
					end
				elseif p.state == "Looting" and t >= p.lootUntil then
					local found = { lootIds[rng:int(1, #lootIds)] }
					if rng:next() < 0.5 then
						table.insert(found, lootIds[rng:int(1, #lootIds)])
					end
					if rng:next() < TONIC_CHANCE then
						table.insert(found, 1, Config.HealItem)
					end
					local inv = mods.Inventory.addMany(
						{ items = p.items, capacity = Injury.capacity(base, p.arms) },
						found
					)
					p.items = inv.items
					Humans.feel(p.h, "loot")
					p.state = "Afield"
					p.visits += 1
					local spot = spots[rng:int(1, #spots)]
					local greed = p.h.traits.greed + p.h.mood.boredom * 0.3 - p.h.mood.fear * 0.4
					if p.visits < 3 and rng:next() < greed and mods.Inventory.free(inv) > 0 then
						p.path = pathTo(spot[1], spot[2])
					else
						goHome(p)
					end
				end
				-- the bell: still out, they head back (the careful and the alert earlier); someone who
				-- misses the HUD may not hear it at all this stop
				if p.missesBell == nil then
					p.missesBell = rng:next() < (1 - p.h.traits.readsUi) * 0.08
				end
				if
					(p.state == "Afield" or p.state == "Looting")
					and not p.homeward
					and not p.rescuing
					and t >= bellAt - 28 - p.h.traits.caution * 14 - (if rng:next() < p.h.traits.readsUi
						then 6
						else 0)
					and not (p.missesBell and t < bellAt - 4)
				then
					goHome(p)
				end
				-- a Tonic at work
				if p.heal and alive(p) then
					-- as in InjuryService: a grab, or the giver leaving reach, interrupts it
					local giver = crew[p.heal.by]
					local away = giver ~= p and dist(giver.x, giver.z, p.x, p.z) > Config.HealReach
					if p.state == "Held" or away or not alive(giver) then
						p.heal = nil
						event({ type = "healStop", who = p.id })
					elseif t >= p.heal.doneAt then
						local i = table.find(giver.items, Config.HealItem)
						if i then
							table.remove(giver.items, i)
							p.arms = Injury.restore(p.arms)
							stats.heals += 1
							Humans.feel(p.h, "healed")
							event({ type = "heal", who = p.id, by = giver.id })
							say(p, "healed", 60)
							if p.state == "Afield" and not p.homeward then
								goHome(p)
							end
						end
						p.heal = nil
					end
				end
				-- armless: a crewmate with a Tonic close by treats them
				if p.state == "Afield" and Injury.armless(p.arms) and p.heal == nil then
					for _, q in crew do
						if
							q ~= p
							and (q.state == "Afield" or q.state == "Looting")
							and holdsTonic(q)
							and Injury.canUseItems(q.arms)
							and dist(q.x, q.z, p.x, p.z) <= Config.HealReach
						then
							p.heal = { doneAt = t + Config.HealSeconds, by = q.id }
							event({ type = "healStart", who = p.id, by = q.id })
							break
						end
					end
				end
				if alive(p) and p.state ~= "Held" and p.state ~= "Aboard" and Injury.expired(p.arms, t) then
					local left = homeDistance(p.x, p.z)
					local speed = crewTuning.SprintSpeed * p.h.device.move
					if left / speed <= 1.5 then
						bug(
							p,
							"deadline_at_door",
							"The armless timer ran out when I was right at the train",
							{
								studsLeft = round(left),
								secondsShort = round(left / speed),
							}
						)
						say(p, "near_miss_timer", 10)
					elseif p.confusedUntil then
						say(p, "unclear_timer", 10)
					end
					die(p, "Did not make it back in time")
				end
			end
			frame()
		end
		-- departure
		for _, p in crew do
			if p.state == "Afield" or p.state == "Looting" then
				p.state = "LeftBehind"
				stats.leftBehind += 1
				Humans.feel(p.h, "died")
				event({ type = "leftBehind", who = p.id })
			elseif p.state == "Held" then
				p.state = "Dead"
				stats.died += 1
				event({ type = "death", who = p.id, text = "Still held when the train left" })
			end
		end
		stopInfo.endT = round(t)
		frame()
	end

	local maxStops = cfg.stops or 6
	repeat
		stopN += 1
		playStop(stopN)
		local any = false
		for _, p in crew do
			if p.state ~= "Left" then
				local reason = Humans.quits(rng, p.h, t / 60 + 2)
				if reason then
					-- a dead or stranded player leaving is not a mid-run quit; a living one is
					if p.state == "Aboard" then
						stats.quits += 1
						if reason == "frustrated" or reason == "bored" then
							stats.quitsUnhappy += 1
						end
						p.quit = reason
					else
						stats.leftAfterDeath = (stats.leftAfterDeath or 0) + 1
					end
					p.state = "Left"
					say(p, "quit_" .. reason, 0)
					event({ type = "quit", who = p.id, text = reason })
				end
			end
			if p.state == "Aboard" then
				any = true
			end
		end
		t += RIDE_SECONDS
		for _, p in crew do
			Humans.drift(p.h, RIDE_SECONDS, 0, true, true)
		end
	until not any or stopN >= maxStops

	local aboard, returnSum = 0, 0
	for _, p in crew do
		if p.state == "Aboard" then
			aboard += 1
		end
		local chance = Humans.returnChance(p.h)
		returnSum += chance
		table.insert(stats.players, {
			device = p.h.deviceId,
			input = p.h.device.input,
			connection = p.h.connection,
			region = p.h.region,
			age = p.h.age,
			hour = p.h.localHour,
			weekday = p.h.weekday,
			rttMs = math.floor(p.h.rtt * 1000),
			motive = p.h.motive,
			rescueTries = p.rescueTries,
			rescueWins = p.rescueWins,
			deaths = p.h.deaths,
			quit = p.quit,
			returnChance = math.floor(chance * 100) / 100,
			tired = math.floor(Humans.tired(p.h) * 100) / 100,
			energy = math.floor(p.h.mood.energy * 100) / 100,
		})
	end
	local complaints = {}
	for topic, c in stats.complaints do
		complaints[topic] = c.count
	end
	local bugs = {}
	for topic, b in stats.bugs do
		table.insert(bugs, { topic = topic, detail = b.example, count = b.count })
	end
	trace.summary = {
		rescued = stats.rescues,
		died = stats.died,
		returned = stats.returned,
		quits = stats.quits,
		quitsUnhappy = stats.quitsUnhappy,
		complaints = complaints,
		bugs = bugs,
		text = string.format(
			"%d stops; %d grabs, %d fought free, %d rescued, %d rescue failed, %d with nobody near; %d items dropped, %d arms regrown; %d armless, %d made it back; %d quit; %d of %d aboard at the end; would come back %d%%",
			stats.stops,
			stats.grabs,
			stats.escapes,
			stats.rescues,
			stats.rescueFails,
			stats.noRescuer,
			stats.drops,
			stats.heals,
			stats.armless,
			stats.returned,
			stats.quits,
			aboard,
			#crew,
			math.floor(returnSum / #crew * 100)
		),
	}
	event({ type = "outcome", text = trace.summary.text })
	table.sort(trace.events, function(a, b)
		return a.t < b.t
	end)
	return { trace = trace, stats = stats }
end

-- The rescue alone, many times, by people on this device and connection already in reach. Share rescued.
function LimbSim.rescueRate(
	mods,
	deviceId: string,
	connection: string,
	rttSeconds: number,
	n: number,
	seed: number
): number
	local Rescue = mods.Rescue
	local rng = mods.Rng.new(mods.Rng.derive(seed, deviceId, connection, math.floor(rttSeconds * 1000)))
	local wins = 0
	for i = 1, n do
		local h = Humans.new(rng, i)
		h.deviceId, h.device, h.connection = deviceId, Humans.Devices[deviceId], connection
		h.rtt = rttSeconds
		local s = Rescue.new(i, 0, h.rtt)
		Rescue.join(s, 1, 0.3, h.rtt)
		for beat = 1, Rescue.BeatCount do
			local at = Rescue.beatAt(s, beat)
			local claimed = at + gauss(rng) * Humans.jitter(h) + h.device.latency
			local arrive = claimed + Humans.oneWay(rng, h)
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
