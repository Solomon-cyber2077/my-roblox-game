--[[
	One bot playtest session: a crew of personas (lib/Personas) plays a whole run headless on the
	game's own rules: RouteGen and Vote at junctions, DifficultyModel per stop, LayoutGen and
	StationReach for the yard, LootRoll for every container, HazardSchedule for fog, collapse
	and Hollow spawns, SkillCheck for every struggle press, Ledger and Leaks for coal and hull,
	Economy for the payout.

	What is modelled, not engine-exact: walking is along StationReach's path distance; a Hollow
	meets a player at a rate set by how many are out, how deep the player is and how careful;
	the chase is real speeds (Tuning.Crew vs params.hollowChase, stamina included); a grab is
	every check rolled and judged by SkillCheck with the device's latency and ping.

	Sim.run(mods, cfg) returns one session record (plain tables, ready for JSON).
]]

local Personas = require("./Personas")

local Sim = {}

local DT = 0.25
local ENCOUNTER_RATE = 0.012 -- encounters a second per active Hollow for a player at full depth
local SLEEPER_RATE = 0.02 -- extra a second per sleeper while searching its building
local SPOT_HEAD_START = 14 -- studs between player and Hollow when the player sees it first
local LATE_HEAD_START = 4
local GRAB_REACH = 1.5
-- touch prompts (docs/SIM-CALIBRATION.md section 3): a tap misses ~3% of the time on a target of 9.6 mm or more,
-- rising to ~25% at 4 mm, and 1.6x on a target that moves with the camera. The world chip is 64 pt drawn at 0.72 and
-- then at our UI's scale on that screen (UI_SCALE, from `lune run layout`), and it moves; the action button is
-- Logic/TouchCluster.Size units in screen space (it counter-scales) and fixed. A missed tap costs a retry.
local CHIP_PT, BUTTON_PT, MOVING = 64 * 0.72, 60, 1.6
local UI_SCALE = { Phone = 0.73, LowPhone = 0.67, BudgetAndroid = 0.79, Tablet = 0.86 } -- iPhone 15, SE, Moto E13, iPad
local PROMPT_RETRY = 1.2 -- seconds lost to a missed tap

local function tapMiss(mm: number): number
	return math.clamp(0.03 + (9.6 - mm) / (9.6 - 4) * 0.22, 0.03, 0.25)
end

-- what the game sees of a press: the device's input lag plus ~1.5 frames before it is read and shown
local function inputLag(device): number
	return device.latency + 1.5 / device.fps
end

local function clamp(x, lo, hi)
	return math.max(lo, math.min(hi, x))
end

local function gauss(rng)
	local u1 = math.max(rng:next(), 1e-9)
	local u2 = rng:next()
	return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

-- Session record helpers ----------------------------------------------------------

local function newPlayer(persona, rng)
	local device = Personas.Devices[persona.device]
	return {
		persona = persona,
		device = device,
		rng = rng,
		hp = 100,
		status = "Playing", -- Playing | Dead | LeftBehind | Quit | CashedOut
		fun = 0,
		frustration = 0,
		boredom = 0,
		confusion = 0,
		stats = {
			Great = 0,
			Good = 0,
			Miss = 0,
			grabs = 0,
			escapes = 0,
			chases = 0,
			outran = 0,
			lootValue = 0,
			containers = 0,
			clutchBoards = 0,
			closeCalls = 0,
			pries = 0,
			fogSeconds = 0,
			promptMisses = 0,
		},
		grabsSeen = 0,
	}
end

local function event(session, stop, who, kind, text)
	table.insert(
		session.events,
		{ stop = stop, who = who and who.persona.name or "crew", kind = kind, text = text }
	)
end

local function feel(p, field, amount)
	p[field] = math.max(p[field] + amount, 0)
end

-- Skill checks -----------------------------------------------------------------------

-- The instant the needle sits in the middle of the great block (the press a perfect player makes).
local function idealPress(SkillCheck, check)
	local target = check.zoneWidth / 2
	local t = check.startsAt
	local stop = check.startsAt + check.sweep
	while t < stop do
		local rel = SkillCheck.angleAt(check, t) - SkillCheck.zoneStartAt(check, t)
		if rel >= target then
			return t
		end
		t += 0.004
	end
	return stop
end

-- One grab, start to finish. Returns true when the player breaks free.
local function struggle(mods, session, p, stopLevel, helpers)
	local SkillCheck = mods.SkillCheck
	local C = mods.Difficulty.SkillCheck
	local rng = p.rng
	local persona, device = p.persona, p.device
	local roll = function(lo, hi)
		return rng:range(lo, hi)
	end
	local zone = SkillCheck.zoneWidth(stopLevel)
	local finish = SkillCheck.finishSeconds(stopLevel, zone)
	local tolerance = SkillCheck.tolerance(device.ping)
	local progress = 0
	local now = C.FirstDelay
	local id = 0
	local firstGrab = p.grabsSeen == 0
	p.grabsSeen += 1
	p.stats.grabs += 1
	local lagMisses = 0
	while now < finish do
		id += 1
		local check = SkillCheck.new(id, now, zone, roll)
		local result
		local pressedAt
		if
			id == 1
			and firstGrab
			and rng:chance(device.noPress * (1.2 - persona.skill) + (1 - persona.readsUi) * 0.08)
		then
			result = "Miss"
			feel(p, "confusion", 0.15)
			event(session, session.stop, p, "confused", "did not find the struggle button on the first check")
		else
			local spread = persona.jitter * (1 + persona.panic * 0.5)
			-- after a first grab players learn to press a little early for their device
			local lead = if firstGrab then 0 else inputLag(device) * 0.5 * persona.skill
			local press = idealPress(SkillCheck, check) + gauss(rng) * spread + persona.reaction * 0.04 - lead
			-- touch: builds with SkillCheck.TouchLead stamp a tap on touch-down, earlier by the lead;
			-- older ones fired the keycap on Activated, when the finger lifts (a whole tap late)
			local touchShift = 0
			if device.tap then
				touchShift = if C.TouchLead then -C.TouchLead else device.tap
			end
			local claimed = press + inputLag(device) + touchShift
			-- builds with SkillCheck.frameLead stamp a press a frame earlier (the marker was drawn a frame ago)
			if session.frameLead and mods.SkillCheck.frameLead then
				claimed -= mods.SkillCheck.frameLead(1 / device.fps)
			end
			local arrived = claimed + device.ping / 2
			result = SkillCheck.judgePress(check, claimed, arrived, tolerance)
			-- would the press have landed with no input latency? then the device cost it
			if result == "Miss" and SkillCheck.judge(check, press + math.max(touchShift, 0), 0) ~= "Miss" then
				lagMisses += 1
			end
			pressedAt = arrived
		end
		p.stats[result] += 1
		local cost
		progress, cost = SkillCheck.apply(progress, result)
		finish -= cost
		local ended = pressedAt or SkillCheck.endsAt(check)
		for _ = 1, helpers do
			progress = SkillCheck.pry(progress)
		end
		if SkillCheck.freed(progress) then
			if lagMisses > 0 then
				event(
					session,
					session.stop,
					p,
					"lag",
					`{lagMisses} press(es) lost to input lag on {device.label}`
				)
			end
			return true, lagMisses
		end
		now = ended + SkillCheck.gap(roll)
	end
	if lagMisses > 0 then
		event(session, session.stop, p, "lag", `{lagMisses} press(es) lost to input lag on {device.label}`)
	end
	-- did the lag decide it? only if the lost presses would have covered the shortfall
	local decisive = lagMisses * (1 + C.MissCost) >= C.Required - progress
	return false, if decisive then lagMisses else 0
end

-- A stop ---------------------------------------------------------------------------

local function buildYard(mods, archId, seed, params)
	local plan = mods.LayoutGen.generate(archId, seed, params.lootMul)
	local reach = mods.StationReach.measure(plan)
	local sleepersIn = {}
	for _, s in plan.sleepers do
		sleepersIn[s.building] = (sleepersIn[s.building] or 0) + 1
	end
	local spots = {}
	local arch = mods.Stations.List[archId]
	for _, c in plan.containers do
		local gx, gz = mods.StationReach.tileOf(plan, c.x, c.z)
		local dist = reach.dist[gz * plan.cols + gx]
		if dist then
			local items = mods.LootRoll.roll(c.kind, c.zone, arch, mods.LootRoll.seedFor(seed, c.id))
			local value = 0
			for _, id in items do
				local def = mods.Items[id]
				value += def and def.value or 0
			end
			table.insert(spots, {
				dist = math.max(dist, 4),
				z = c.z,
				hold = mods.LootRoll.holdSeconds(c.kind, c.zone),
				items = items,
				value = value,
				building = c.building,
				sleepers = c.building and sleepersIn[c.building] or 0,
			})
		end
	end
	for _, l in plan.loose do
		local gx, gz = mods.StationReach.tileOf(plan, l.x, l.z)
		local dist = reach.dist[gz * plan.cols + gx]
		local def = mods.Items[l.item]
		if dist and def then
			table.insert(spots, {
				dist = math.max(dist, 4),
				z = l.z,
				hold = 0.5,
				items = { l.item },
				value = def.value,
				sleepers = 0,
			})
		end
	end
	return plan, spots
end

local function speedOf(mods, p, sprinting)
	local crew = mods.Tuning.Crew
	local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed
	if p.winded and p.winded > 0 then
		base *= crew.WindedMultiplier
	end
	-- a thumbstick rarely sits at the rim: builds with SprintMinPush make a tapped sprint full speed,
	-- leaving only the path's wobble
	local move = p.device.move
	if sprinting and p.device.toggleSprint and crew.SprintMinPush then
		move = math.max(move, 0.95)
	end
	return base * mods.Inventory.speedMultiplier(p.inv) * move * (0.9 + 0.1 * p.persona.skill)
end

local function stepStamina(mods, p, sprinting, dt)
	local crew = mods.Tuning.Crew
	-- a touch RUN toggle that switched off when they ran dry: no sprint until they tap it again
	if p.rearmIn then
		p.rearmIn -= dt
		if p.rearmIn > 0 then
			sprinting = false
		else
			p.rearmIn = nil
		end
	end
	if sprinting and not p.exhausted then
		p.stamina -= crew.StaminaDrainPerSecond * dt
		p.restFor = crew.StaminaRegenDelay
		if p.stamina <= 0 then
			p.stamina = 0
			p.exhausted = true
			p.winded = crew.WindedSeconds
			if p.device.toggleSprint and not crew.ToggleSprintResumes then
				-- finding RUN again under pressure: after the breath is back, plus a fumble
				local resume = crew.StaminaRegenDelay
					+ crew.StaminaMax * crew.ExhaustedResume / crew.StaminaRegenPerSecond
				p.rearmIn = resume + p.persona.reaction + p.rng:range(0.3, 1.5) * (1 + p.persona.panic)
			end
		end
		return true
	end
	p.winded = math.max((p.winded or 0) - dt, 0)
	p.restFor = math.max((p.restFor or 0) - dt, 0)
	if p.restFor <= 0 then
		p.stamina = math.min(p.stamina + crew.StaminaRegenPerSecond * dt, crew.StaminaMax)
	end
	if p.exhausted and p.stamina >= crew.StaminaMax * crew.ExhaustedResume then
		p.exhausted = false
	end
	return false
end

local function pickSpot(p, spots, t, departSeen, fogAt, speed)
	local persona = p.persona
	local best, bestScore = nil, 0
	for _, s in spots do
		if not s.taken and #s.items > 0 then
			local travel = math.abs(s.dist - p.d) + math.min(s.dist, p.d) * 0.3
			local arrive = t + travel / speed + persona.reaction
			local back = s.dist / speed
			local margin = 4 + persona.caution * 16
			if arrive + s.hold + back + margin < departSeen then
				local score = (s.value ^ (0.5 + persona.greed * 0.5)) / (travel / speed + s.hold + 1)
				if s.building then
					score *= 1 + persona.explore
				end
				if s.z > fogAt(arrive) - persona.caution * 24 then
					score *= 0.15 + (1 - persona.caution) * 0.5
				end
				score *= 1 + (p.rng:next() - 0.5) * (1.2 - persona.skill)
				if score > bestScore then
					best, bestScore = s, score
				end
			end
		end
	end
	return best
end

local function playStop(mods, session, crew, train, stopInfo)
	local H = mods.HazardSchedule
	local rng = session.rng:fork("stop", stopInfo.index)
	local params = stopInfo.params
	local plan, spots = buildYard(mods, stopInfo.archetype, stopInfo.seed, params)
	local geo = { depth = plan.depth, safe = plan.safeRows * plan.tile }
	local departAt = params.dwell + params.lastCall
	local chaseEnd = departAt + params.chaseWindow
	local spawns = H.spawnTimes(params, stopInfo.seed)
	local record = {
		stop = stopInfo.index,
		level = stopInfo.level,
		archetype = stopInfo.archetype,
		tier = stopInfo.tier,
		difficulty = math.floor(params.difficulty * 100 + 0.5) / 100,
		dwell = params.dwell,
		spots = #spots,
		deaths = 0,
		leftBehind = 0,
		grabs = 0,
		chases = 0,
		lootValue = 0,
		hollowsOut = math.min(#spots > 0 and #spots or 0, params.hollowCap),
	}
	session.stop = stopInfo.index
	local fogAt = function(t)
		return H.fogFront(params, geo, t)
	end

	local active = {}
	for _, p in crew do
		if p.status == "Playing" then
			p.d, p.z, p.state, p.target = 0, 0, "Pick", nil
			p.stamina = mods.Tuning.Crew.StaminaMax
			p.exhausted, p.winded, p.collapseSafe = false, 0, nil
			p.inv = mods.Inventory.new(mods.Tuning.Crew.BackpackSlots)
			p.threatened = false
			p.headHome = false
			-- how many seconds late they read the departure clock: the watch and the slates are seen or not;
			-- with the sound on, the T-30 bell and the T-10 whistle catch most who missed them (SIM-CALIBRATION 5)
			local readChance = p.persona.readsUi * (1 - p.device.hudMiss)
			if rng:chance(readChance) then
				p.lateBy = 0
			elseif p.soundOn and rng:chance(0.85) then
				p.lateBy = rng:range(0, 4)
			else
				p.lateBy = rng:range(4, 22)
			end
			table.insert(active, p)
		end
	end

	local cargo = {}
	local t = 0
	while t < chaseEnd do
		t += DT
		local out = 0
		for _, at in spawns do
			if at <= t then
				out += 1
			end
		end
		out = math.min(out, params.hollowCap)
		local fog = fogAt(t)
		local collapse = H.collapseFront(params, geo, t)
		for _, p in active do
			if p.status == "Playing" and p.state ~= "Aboard" then
				local persona = p.persona
				local returning = p.state == "Return"
				local lateFeel = departAt - t
				local sprint = (returning and lateFeel < p.d / 22 + 6) or false
				local speed = speedOf(mods, p, sprint and not p.exhausted)
				stepStamina(mods, p, sprint, DT)

				if p.state == "Pick" then
					local s = if mods.Inventory.free(p.inv) > 0
						then pickSpot(p, spots, t, departAt + p.lateBy, fogAt, speed)
						else nil
					if s then
						s.taken = true
						p.target, p.state = s, "Go"
					else
						p.state = "Return"
						p.headHome = mods.Inventory.free(p.inv) > 0 or p.d <= 0
					end
				elseif p.state == "Go" then
					local s = p.target
					local step = speed * DT
					local startZ = p.z
					if math.abs(s.dist - p.d) <= step then
						p.d, p.z, p.state, p.searchLeft = s.dist, s.z, "Search", s.hold
						local ptMm = p.device.ptMm
						if ptMm and p.device.tap then
							local miss = if session.actionButton
								then tapMiss(BUTTON_PT * ptMm)
								else tapMiss(CHIP_PT * (UI_SCALE[p.device.id] or 1) * ptMm) * MOVING
							if p.rng:chance(miss * (1.3 - p.persona.skill)) then
								p.searchLeft += PROMPT_RETRY
								p.stats.promptMisses += 1
								feel(p, "confusion", 0.02)
							end
						end
					else
						p.d += if s.dist > p.d then step else -step
						p.z = startZ
							+ (s.z - startZ)
								* math.min(step / math.max(math.abs(s.dist - p.d) + step, 1), 1)
					end
				elseif p.state == "Search" then
					p.searchLeft -= DT
					if p.searchLeft <= 0 then
						local s = p.target
						local kept
						p.inv, kept = mods.Inventory.addMany(p.inv, s.items)
						local taken = 0
						for _, id in kept do
							local def = mods.Items[id]
							taken += def and def.value or 0
						end
						-- what did not fit stays in the container for the next crewmate
						local left = {}
						local used = {}
						for _, id in kept do
							used[id] = (used[id] or 0) + 1
						end
						for _, id in s.items do
							if (used[id] or 0) > 0 then
								used[id] -= 1
							else
								table.insert(left, id)
							end
						end
						s.items = left
						s.taken = #left == 0
						p.stats.lootValue += taken
						p.stats.containers += 1
						record.lootValue += taken
						feel(p, "fun", taken * 0.003 * (0.4 + persona.greed))
						p.state = "Pick"
					end
				elseif returning then
					p.d = math.max(p.d - speed * DT, 0)
					p.z = math.max(p.z - speed * DT * 0.7, 0)
					if p.d <= 0 then
						-- unload at the tender; head out again unless the clock sent them home
						local rest, items = mods.Inventory.splitCargo(p.inv)
						p.inv = rest
						for _, id in items do
							table.insert(cargo, id)
						end
						p.state = if p.headHome then "Aboard" else "Pick"
						if t > departAt then
							p.stats.clutchBoards += 1
							feel(p, "fun", 0.1 + persona.thrill * 0.15)
							event(
								session,
								session.stop,
								p,
								"clutch",
								`jumped aboard {string.format("%.1f", t - departAt)} s after the train pulled out`
							)
						elseif departAt - t < 5 then
							p.stats.closeCalls += 1
							feel(p, "fun", 0.05 + persona.thrill * 0.06)
						end
					end
				end

				-- head back when the clock (as they read it) says so
				if p.state ~= "Return" and p.state ~= "Aboard" then
					local need = p.d / speedOf(mods, p, false) + persona.reaction + 3 + persona.caution * 14
					if departAt + p.lateBy - t < need then
						p.state = "Return"
						p.headHome = true
					end
				end

				-- fog
				if p.z > fog and p.state ~= "Aboard" then
					p.hp -= params.fogDps * DT
					p.stats.fogSeconds += DT
					if p.stats.fogSeconds % 3 < DT then
						feel(p, "frustration", 0.02)
					end
					if p.rng:chance(DT / (persona.reaction + 0.5 + (1 - p.device.awareness))) then
						p.z = math.max(fog - 6, 0)
						if p.state == "Go" or p.state == "Search" then
							if p.target then
								p.target.taken = false
							end
							p.state = "Pick"
						end
					end
				end

				-- collapse: the floor goes once the front passes them
				if
					p.z > collapse
					and p.z > geo.safe
					and p.state ~= "Aboard"
					and p.collapseSafe ~= math.floor(collapse)
				then
					local seeIt = persona.reaction / math.max(p.device.awareness, 0.2)
					local window = params.collapseWarn
						* (0.5 + persona.skill * 0.5)
						* (0.6 + persona.readsUi * 0.4)
					if seeIt + p.rng:range(-0.3, 0.6) < window then
						p.collapseSafe = math.floor(collapse)
						p.z = math.max(collapse - 4, 0)
						feel(p, "fun", 0.04 * (0.5 + persona.thrill))
					else
						p.hp = 0
						p.cause = "Fell when the floor collapsed"
					end
				end

				-- Hollows
				if p.hp > 0 and out > 0 and p.state ~= "Aboard" and p.z > geo.safe then
					local depthShare = clamp(p.z / math.max(geo.depth, 1), 0, 1)
					local rate = out * ENCOUNTER_RATE * depthShare * (1.25 - persona.caution * 0.5)
					if p.state == "Search" and p.target and p.target.sleepers > 0 then
						rate += SLEEPER_RATE * p.target.sleepers
					end
					if p.rng:chance(rate * DT) then
						record.chases += 1
						p.stats.chases += 1
						p.threatened = true
						local spotted = p.rng:chance(p.device.awareness * (1 - persona.reaction / 1.6))
						-- the hunted cue (Tuning.HuntedCue, phones only): an off-screen Hollow that starts hunting
						-- shows as eyes at the screen's edge; a player who reads the edges, with no thumb over it, sees it
						if
							not spotted
							and session.huntedCue
							and p.device.platform == "Mobile"
							and p.device.id ~= "Tablet"
						then
							spotted = p.rng:chance((0.4 + 0.6 * persona.readsUi) * (1 - p.device.hudMiss))
						end
						local gap = if spotted then SPOT_HEAD_START else LATE_HEAD_START
						if p.target and (p.state == "Go" or p.state == "Search") then
							p.target.taken = false
						end
						-- the chase: real speeds, stamina and cargo
						local caught = false
						local guard = 0
						while p.d > 0 and guard < 400 do
							guard += 1
							if gap < 4 and persona.skill > 0.55 and mods.Inventory.heavyCount(p.inv) > 0 then
								p.inv = select(1, mods.Inventory.splitCargo(p.inv))
								event(
									session,
									session.stop,
									p,
									"drop",
									"dropped the heavy cargo to outrun a Hollow"
								)
							end
							local sprinting = stepStamina(mods, p, true, DT)
							local ps = speedOf(mods, p, sprinting)
							gap += (ps - params.hollowChase) * DT
							p.d = math.max(p.d - ps * DT, 0)
							p.z = math.max(p.z - ps * DT * 0.7, 0)
							if gap <= GRAB_REACH then
								caught = true
								break
							end
							if p.z <= geo.safe then
								break
							end
						end
						if not caught then
							p.stats.outran += 1
							feel(p, "fun", 0.06 + persona.thrill * 0.08)
							p.state = if p.d <= 0 then "Aboard" else "Return"
						else
							record.grabs += 1
							local helpers = 0
							for _, mate in active do
								if
									mate ~= p
									and mate.status == "Playing"
									and mate.state ~= "Aboard"
									and mate.hp > 0
								then
									if mate.rng:chance(mate.persona.teamwork * 0.6) then
										helpers += 1
										mate.stats.pries += 1
									end
								elseif mate ~= p and mate.status == "Playing" and mate.state == "Aboard" then
									if mate.rng:chance(mate.persona.teamwork * 0.25) then
										helpers += 1
										mate.stats.pries += 1
									end
								end
							end
							local free, lag = struggle(mods, session, p, stopInfo.level, helpers)
							if free then
								p.stats.escapes += 1
								p.hp -= params.hollowDamage
								feel(p, "fun", 0.1 + persona.thrill * 0.1)
								if helpers > 0 then
									event(
										session,
										session.stop,
										p,
										"rescued",
										`broke free with {helpers} crewmate(s) prying`
									)
								end
								p.state = "Return"
								if p.hp <= 0 then
									p.cause = "Bled out after a grab"
								end
							else
								p.hp = 0
								p.cause = if lag > 0
									then "Taken by a Hollow (lost presses to lag)"
									else "Taken by a Hollow"
								if lag > 0 then
									feel(p, "frustration", 0.15)
								end
							end
						end
					end
				end

				if p.hp <= 0 and p.status == "Playing" then
					p.status = "Dead"
					p.cause = p.cause or "Choked in the fog"
					p.deathStop = stopInfo.index
					record.deaths += 1
					feel(p, "frustration", 0.25 + (1 - persona.tolerance) * 0.2)
					event(session, session.stop, p, "death", p.cause)
				end
			end
		end
		local busy = false
		for _, p in active do
			if p.status == "Playing" and p.state ~= "Aboard" then
				busy = true
			end
		end
		if not busy and t < departAt then
			-- everyone aboard early: the rest is waiting
			for _, p in active do
				if p.status == "Playing" then
					feel(p, "boredom", (departAt - t) / (400 * (0.5 + p.persona.patience)))
				end
			end
			break
		end
	end

	-- the train leaves: deposit cargo, strand anyone not aboard
	for _, p in active do
		if p.status == "Playing" then
			if p.state == "Aboard" then
				local rest, items = mods.Inventory.splitCargo(p.inv)
				p.inv = rest
				for _, id in items do
					table.insert(cargo, id)
				end
				if not p.threatened then
					feel(p, "boredom", 0.05 * p.persona.thrill)
				end
			else
				p.status = "LeftBehind"
				p.deathStop = stopInfo.index
				p.cause = if p.lateBy > 0 then "Left behind (missed the departure warning)" else "Left behind"
				record.leftBehind += 1
				feel(p, "frustration", 0.3)
				event(session, session.stop, p, "left", p.cause)
			end
		end
	end
	local receipt
	train, receipt = mods.Ledger.deposit(train, cargo)
	session.tally.coalDelivered += receipt.coal
	session.tally.partsDelivered += receipt.parts
	session.tally.relicBrass += receipt.relicBrass
	session.tally.relicsBanked += receipt.relics
	session.tally.stationsDeparted += 1
	for _, p in active do
		session.tally.clutchBoards += p.stats.clutchBoards
		session.tally.closeCalls += p.stats.closeCalls
	end
	record.coalAboard = train.coal
	return train, record
end

-- The trip to the next stop: coal burned, leaks opened and patched.
local function travel(mods, session, crew, train, option, stopNext, d)
	local Leaks = mods.Leaks
	local rng = session.rng:fork("trip", stopNext)
	local cost = mods.Ledger.legCoalCost(train, option.distanceKm)
	local tripSeconds = mods.DifficultyModel.cruiseSeconds(option.distanceKm)
	local coalBefore = train.coal
	train = mods.Ledger.burn(train, cost)
	local starveShare = if cost > coalBefore then (cost - coalBefore) / cost else 0
	local integrity = train.integrity
	integrity -= mods.Difficulty.Hull.StarvingPerSecond * tripSeconds * starveShare

	local n = Leaks.count(stopNext, d, train.upgrades, rng:next())
	local shares = Leaks.shares(n, function()
		return rng:range(-1, 1)
	end)
	local alert, parts = 0, train.parts
	for _, p in crew do
		if p.status == "Playing" then
			alert = math.max(alert, p.persona.readsUi * (1 - p.device.hudMiss))
		end
	end
	for _, u in shares do
		local opened = u * tripSeconds
		local patchAt = opened + 4 + (1 - alert) * 25 + rng:range(0, 6)
		if alert == 0 or parts < mods.Difficulty.Leaks.PatchParts then
			patchAt = tripSeconds
		else
			parts -= mods.Difficulty.Leaks.PatchParts
		end
		local age = 0
		local stepT = 0.5
		local tt = opened
		while tt < math.min(patchAt, tripSeconds) do
			integrity -= Leaks.rate(Leaks.severity(age, tripSeconds), tripSeconds) * stepT
			age += stepT
			tt += stepT
		end
	end
	local nextTrain = table.clone(train)
	nextTrain.parts = parts
	nextTrain.integrity = math.max(integrity, mods.Difficulty.Hull.Floor)
	-- the workbench between stops: repair while parts allow
	while nextTrain.integrity < 70 and nextTrain.parts >= mods.Difficulty.Hull.RepairParts + 1 do
		local ok
		nextTrain, ok = mods.Ledger.repairHull(nextTrain)
		if not ok then
			break
		end
	end
	return nextTrain,
		{ leaks = n, coalBurned = cost, starving = starveShare > 0, hull = math.floor(nextTrain.integrity) }
end

local function vote(mods, session, crew, options, leg)
	local votes = {}
	for _, p in crew do
		if p.status == "Playing" then
			local best, bestScore = 1, -math.huge
			for i, o in options do
				local risk = o.tier + o.distanceKm / 8
				local score = risk * (p.persona.thrill + p.persona.greed - 2 * p.persona.caution)
					+ p.rng:range(-0.5, 0.5)
				if score > bestScore then
					best, bestScore = i, score
				end
			end
			votes[p.persona.id] = best
		end
	end
	return mods.Vote.tally(votes, options, session.rng:int(1, #options) + leg * 0)
end

-- A whole session ------------------------------------------------------------------

function Sim.run(mods, cfg)
	local Rng = mods.Rng
	local rng = Rng.new(Rng.derive(cfg.seed, "playtest"))
	local crew = {}
	local anyNew = false
	for i, id in cfg.crew do
		local persona = Personas.byId[id]
		local p = newPlayer(persona, rng:fork("player", i))
		if cfg.device then
			p.device = assert(Personas.Devices[cfg.device], "unknown device " .. cfg.device)
		end
		p.soundOn = not p.rng:chance(p.device.soundOff or 0)
		table.insert(crew, p)
		anyNew = anyNew or cfg.first == true or mods.Routes.isNew(persona.runs)
	end
	local route = cfg.route or mods.Routes.decide(anyNew, nil, 0, 1)
	local stopCount = mods.Routes.length(route)
	local session = {
		seed = cfg.seed,
		build = cfg.build,
		rng = rng,
		route = route,
		crew = {},
		stops = {},
		trips = {},
		events = {},
		tally = mods.Economy.emptyTally(),
		actionButton = cfg.actionButton ~= false,
		huntedCue = cfg.huntedCue ~= false,
		frameLead = cfg.frameLead ~= false,
	}
	local train = mods.Ledger.newTrain()
	local runSeed = cfg.seed
	local prev = nil
	local outcome, cause = "Wipe", "Everyone was lost"
	local stopsReached = 0

	-- the first two minutes: on a first session some players leave before the first stop (GameAnalytics 2025:
	-- casual Roblox players leave in under 2 minutes); the impatient and the unthrilled most (SIM-CALIBRATION 6)
	for _, p in crew do
		local first = cfg.first == true or p.persona.runs == 0
		if first and p.rng:chance(0.18 * (1 - p.persona.patience) * (1 - 0.5 * p.persona.thrill)) then
			p.status = "Quit"
			p.quitStop, p.quitReason = 0, "left in the first two minutes"
			event(session, 0, p, "quit", p.quitReason)
		end
	end

	for leg = 1, stopCount + 1 do
		local alive = 0
		for _, p in crew do
			if p.status == "Playing" then
				alive += 1
			end
		end
		if alive == 0 then
			break
		end
		local firstKm = if anyNew then mods.Tuning.Run.FirstLegKm else nil
		local options = mods.RouteGen.options(runSeed, leg, stopCount, prev, firstKm)
		local option = options[vote(mods, session, crew, options, leg)]
		local level = mods.Routes.level(route, math.min(leg, stopCount))
		local d = mods.DifficultyModel.forStop(level, mods.Tuning.Run.StationCount, option.tier, 1)
		local trip
		train, trip = travel(mods, session, crew, train, option, leg, d)
		trip.leg = leg
		table.insert(session.trips, trip)
		if mods.Ledger.atFloor(train) then
			outcome, cause =
				"Breakdown", if trip.starving then "Ran out of coal" else "Hull gave out to leaks"
			event(session, leg, nil, "breakdown", cause)
			for _, p in crew do
				if p.status == "Playing" then
					feel(p, "frustration", 0.2)
				end
			end
			break
		end
		if option.archetype == "Terminus" or leg > stopCount then
			outcome, cause = "Victory", "Reached the Terminus"
			session.tally.reachedTerminus = true
			stopsReached = stopCount
			for _, p in crew do
				if p.status == "Playing" then
					feel(p, "fun", 0.35)
				end
			end
			break
		end
		local arch = mods.Stations.List[option.archetype]
		local params = mods.DifficultyModel.params(d, arch, alive, train.upgrades, level)
		local stopSeed = Rng.derive(runSeed, "station", leg)
		local record
		train, record = playStop(mods, session, crew, train, {
			index = leg,
			level = level,
			archetype = option.archetype,
			tier = option.tier,
			seed = stopSeed,
			params = params,
		})
		table.insert(session.stops, record)
		stopsReached = leg
		prev = option.archetype

		-- the stop-five cash-out (Logic/CashOut): each living crew member aboard chooses at the junction;
		-- a missed card means ride on
		if mods.CashOut and mods.CashOut.offered(stopCount, leg) then
			local left = 0
			for _, p in crew do
				if p.status == "Playing" then
					local persona = p.persona
					local sawIt = not p.rng:chance(p.device.hudMiss * (1 - persona.readsUi))
					local want = clamp(
						0.12
							+ persona.caution * 0.35
							+ p.frustration * 0.5
							- persona.thrill * 0.25
							- persona.greed * 0.15,
						0.02,
						0.9
					)
					if not sawIt then
						p.stats.missedCashOut = true
						event(session, leg, p, "confused", "missed the cash-out card at the junction")
					elseif p.rng:chance(want) then
						p.status = "CashedOut"
						event(session, leg, p, "cashout", "cashed out at the junction")
					end
					if p.status == "Playing" then
						left += 1
					end
				end
			end
			if left == 0 then
				outcome, cause = "CashedOut", "Everyone cashed out at stop " .. leg
				break
			end
		end

		-- after the stop: dead crew spectate (boredom), and anyone may quit
		for _, p in crew do
			local persona = p.persona
			if p.status == "Dead" or p.status == "LeftBehind" then
				feel(p, "boredom", 0.12 / (0.4 + persona.patience))
			end
			if p.status ~= "Quit" and p.quitStop == nil then
				local reason
				if p.frustration > persona.tolerance * 1.3 and p.frustration > p.fun * 0.8 then
					reason = "frustrated: " .. (p.cause or "too many deaths and misses")
				elseif p.boredom > 0.9 + persona.patience * 0.6 and p.boredom > p.fun then
					reason = if p.status == "Playing"
						then "bored: stops felt slow or safe"
						else "bored of spectating"
				elseif p.confusion > 0.5 + persona.readsUi * 0.3 then
					reason = "confused by the controls"
				end
				if reason then
					p.quitStop, p.quitReason = leg, reason
					if p.status == "Playing" then
						p.status = "Quit"
					end
					event(session, leg, p, "quit", reason)
				end
			end
		end
	end
	if outcome == "Wipe" and stopsReached > 0 then
		cause = "Crew lost at stop " .. stopsReached
	end

	local payout = mods.Economy.payout(session.tally, {
		outcome = if outcome == "Victory" then "Victory" else "Defeat",
		dailyBonus = false,
		soloCharter = false,
		tier = 1,
	})
	for _, p in crew do
		local persona = p.persona
		-- brass matters to grinders
		feel(p, "fun", payout.brass * 0.0008 * persona.greed)
		local score = 5 + 6 * (p.fun - 0.6 * p.frustration - 0.5 * p.boredom - 0.4 * p.confusion)
		local rating = math.floor(clamp(score, 1, 10) * 10 + 0.5) / 10
		table.insert(session.crew, {
			id = persona.id,
			name = persona.name,
			device = p.device.id,
			platform = p.device.platform,
			frameMs = math.floor(1000 / p.device.fps * 10 + 0.5) / 10,
			status = p.status,
			cause = p.cause,
			deathStop = p.deathStop,
			quitStop = p.quitStop,
			quitReason = p.quitReason,
			rating = rating,
			-- AGAIN now and back tomorrow, as chances that rise with the rating (SIM-CALIBRATION 6: real day-1
			-- returns sit ~12-24%, so a yes/no at rating 6 was ~4x too rosy)
			wouldReplay = p.rng:chance(math.clamp(0.08 + 0.09 * (rating - 5), 0.02, 0.6)),
			returnsTomorrow = p.rng:chance(math.clamp(0.04 + 0.045 * (rating - 5), 0.01, 0.35)),
			soundOn = p.soundOn,
			fun = math.floor(p.fun * 100) / 100,
			frustration = math.floor(p.frustration * 100) / 100,
			boredom = math.floor(p.boredom * 100) / 100,
			confusion = math.floor(p.confusion * 100) / 100,
			stats = p.stats,
		})
	end
	session.rng = nil
	session.stop = nil
	session.outcome = outcome
	session.cause = cause
	session.stopCount = stopCount
	session.stopsReached = stopsReached
	session.brass = payout.brass
	session.coalLeft = train.coal
	session.hullLeft = math.floor(train.integrity)
	return session
end

return Sim
