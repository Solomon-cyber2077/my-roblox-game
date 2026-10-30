--[[
	Server-architecture simulation (`lune run servers`): players arrive, find a crew, play a
	run, and either play again or leave, second by second, under two setups:

	  current  Roblox drops arrivals into public hall servers (the fullest one with room). In a hall, players
	           who want a crew board a car (CarService: 2-4 a car; it leaves when full or Cars.CountdownSeconds
	           after its second rider) and teleport to a reserved server; players happy alone press Ready and
	           start the hall's own run, or join it in progress up to stop JoinInProgressMaxStation, or wait for
	           it to end (one run a server). Car crews play AGAIN in their reserved server.
	  queue    one matchmaking queue across every hall (the prompt-07 prototype): crews of up to 4 form from
	           every waiting player at once, under the same fill rule; anyone happy alone starts at once.

	Players are not perfectly patient: a crew-seeker waiting past their patience goes solo or leaves; a solo
	player blocked by a hall run leaves after theirs. Run lengths come from bot playtest sessions.
	Every behaviour number is a parameter (defaults in ServerSim.Defaults, sources in the report).
]]

local Loader = require("./Loader")
local Matchmaking = Loader.requireNode(Loader.roots.Shared.Logic.Matchmaking)

local Sim = {}

Sim.Defaults = {
	serverSize = 12, -- the place's max players (set in Roblox, not in the repo: confirm)
	carMax = 4, -- Tuning.Cars.MaxPlayers
	carCountdown = 20, -- Tuning.Cars.CountdownSeconds
	hallCountdown = 10, -- Tuning.Run.CountdownSeconds
	jipMaxStop = 6, -- Tuning.Run.JoinInProgressMaxStation
	partyShares = { 0.7, 0.2, 0.1 }, -- arrive alone, as 2, as 3
	seekerShare = 0.6, -- a lone arrival who wants a crew (the rest are happy solo)
	patienceMean = 120, -- seconds; casual Roblox players leave in under 2 minutes (GameAnalytics 2025)
	goSoloShare = 0.5, -- a seeker out of patience who plays solo instead of leaving
	replayShare = 0.35, -- a crew member who plays again after a run
	soloJoinWindow = 10, -- queue: seconds a player happy alone waits for a forming crew before starting solo
	teleportFail = 0.02, -- a car or queue teleport that fails and drops its crew back in the hall
	minutesPerStop = 4.1, -- a stop's dwell + junction + cruise + arrival (bot playtests: ~185 s dwell)
	runOverhead = 2, -- minutes of boarding, terminus and run card
}

local function xorshift(seed: number)
	local s = (seed % 2147483646) + 1
	return function(): number
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
end

local function poisson(rand, mean: number): number
	local l, k, p = math.exp(-mean), 0, 1
	repeat
		k += 1
		p *= rand()
	until p <= l
	return k - 1
end

-- Run lengths in seconds by crew size, from playtest sessions: { [crewSize]: { seconds } }.
function Sim.runTable(sessions: { any }, cfg): { [number]: { number } }
	local out: { [number]: { number } } = { {}, {}, {}, {} }
	for _, s in sessions do
		if not s.error and s.crew then
			local n = math.clamp(#s.crew, 1, 4)
			local minutes = (s.stopsReached or 0) * cfg.minutesPerStop + cfg.runOverhead
			table.insert(out[n], minutes * 60)
		end
	end
	return out
end

type Player = {
	id: number,
	arrived: number,
	seeker: boolean,
	patience: number,
	party: number?,
	started: number?,
	crew: number?,
	triedCar: boolean?, -- a solo player blocked by the hall's run who boarded a car instead
}

function Sim.run(setup: string, ccuArrivalsPerMin: number, hours: number, runs, cfg, seed: number)
	local rand = xorshift(seed)
	local function pick(list: { number }): number
		return list[math.max(1, math.ceil(rand() * #list))]
	end
	local function runSeconds(n: number): number
		local list = runs[math.clamp(n, 1, 4)]
		if #list == 0 then
			list = runs[1]
		end
		return pick(list)
	end
	local function patience(): number
		return -cfg.patienceMean * math.log(math.max(rand(), 1e-9))
	end

	local nextId = 0
	local first: { [number]: Player } = {} -- every arrival, by id
	local stats = {
		arrivals = 0,
		started = 0,
		churned = 0,
		waitSum = 0,
		waits = {},
		crewOf = { 0, 0, 0, 0 },
		runs = 0,
		runCrew = { 0, 0, 0, 0 },
		teleportFails = 0,
		jip = 0,
		online = 0,
		onlineSamples = 0,
	}

	-- current setup state
	type Car = { members: { Player }, since: number? }
	type Server = {
		id: number,
		public: boolean,
		hall: { Player },
		cars: { Car },
		run: { crew: { Player }, startedAt: number, endsAt: number }?,
		playing: { Player },
	}
	local servers: { Server } = {}
	local reserved: { { crew: { Player }, endsAt: number } } = {}
	-- queue setup: parties waiting; `deadline` is when this entry stops waiting for a crew (a crew-seeker: the
	-- car countdown; a player happy alone: SoloJoinWindow, then they start solo)
	local queue: { { members: { Player }, since: number, deadline: number, solo: boolean } } = {}
	local solosWaiting: { { p: Player, server: Server } } = {}
	local now = 0

	local function population(sv: Server): number
		local n = #sv.hall + #sv.playing
		for _, car in sv.cars do
			n += #car.members
		end
		return n
	end

	local function startRun(crew: { Player }, inHall: Server?)
		local n = #crew
		stats.runs += 1
		stats.runCrew[math.min(n, 4)] += 1
		for _, p in crew do
			if p.started == nil then
				p.started, p.crew = now, n
				stats.started += 1
				local w = now - p.arrived
				stats.waitSum += w
				table.insert(stats.waits, w)
				stats.crewOf[math.min(n, 4)] += 1
			end
		end
		local seconds = runSeconds(n)
		if inHall then
			inHall.run = { crew = crew, startedAt = now, endsAt = now + seconds }
			for _, p in crew do
				table.insert(inHall.playing, p)
			end
		else
			table.insert(reserved, { crew = crew, endsAt = now + seconds })
		end
	end

	local function teleport(crew: { Player }, back: Server?): boolean
		if rand() < cfg.teleportFail then
			stats.teleportFails += 1
			if back then
				for _, p in crew do
					table.insert(back.hall, p)
				end
			end
			return false
		end
		startRun(crew, nil)
		return true
	end

	local function placeParty(party: { Player }): Server
		local best: Server? = nil
		for _, sv in servers do
			if sv.public and population(sv) + #party <= cfg.serverSize then
				if best == nil or population(sv) > population(best) then
					best = sv
				end
			end
		end
		if best == nil then
			best = { id = #servers + 1, public = true, hall = {}, cars = {}, run = nil, playing = {} }
			table.insert(servers, best)
		end
		return best :: Server
	end

	local function arrive()
		local r, size, acc = rand(), 1, 0
		for i, w in cfg.partyShares do
			acc += w
			if r <= acc then
				size = i
				break
			end
		end
		local party: { Player } = {}
		local seeker = size > 1 or rand() < cfg.seekerShare
		for _ = 1, size do
			nextId += 1
			local p: Player = {
				id = nextId,
				arrived = now,
				seeker = seeker,
				patience = patience(),
				party = if size > 1 then nextId else nil,
			}
			first[p.id] = p
			stats.arrivals += 1
			table.insert(party, p)
		end
		if setup == "queue" then
			table.insert(queue, {
				members = party,
				since = now,
				deadline = now + (if seeker then cfg.carCountdown else cfg.soloJoinWindow),
				solo = not seeker,
			})
			return
		end
		local sv = placeParty(party)
		if seeker then
			-- board the fullest car with room for the party, else a fresh car
			local car: Car? = nil
			for _, c in sv.cars do
				if
					#c.members + #party <= cfg.carMax and (car == nil or #c.members > #(car :: Car).members)
				then
					car = c
				end
			end
			if car == nil then
				car = { members = {}, since = nil }
				table.insert(sv.cars, car :: Car)
			end
			local c = car :: Car
			for _, p in party do
				table.insert(c.members, p)
			end
			if #c.members >= 2 and c.since == nil then
				c.since = now
			end
		else
			table.insert(sv.hall, party[1])
			table.insert(solosWaiting, { p = party[1], server = sv })
		end
	end

	local function leave(p: Player)
		if p.started == nil then
			stats.churned += 1
		end
	end

	local function tickCurrent()
		for _, sv in servers do
			-- cars: leave when full or counted down
			for i = #sv.cars, 1, -1 do
				local c = sv.cars[i]
				if #c.members >= cfg.carMax or (c.since and now - c.since >= cfg.carCountdown) then
					table.remove(sv.cars, i)
					teleport(c.members, sv)
				else
					-- out of patience in a car: go solo (Ready in the hall) or leave
					for j = #c.members, 1, -1 do
						local p = c.members[j]
						if p.party == nil and now - p.arrived > p.patience then
							table.remove(c.members, j)
							if rand() < cfg.goSoloShare then
								p.seeker = false
								p.triedCar = true -- a car already failed them: no second car
								p.patience = now - p.arrived + patience()
								table.insert(sv.hall, p)
								table.insert(solosWaiting, { p = p, server = sv })
							else
								leave(p)
							end
						end
					end
					if #c.members == 0 then
						table.remove(sv.cars, i)
					elseif #c.members < 2 then
						c.since = nil
					end
				end
			end
			-- the hall's run ends
			local run = sv.run
			if run and now >= run.endsAt then
				sv.run = nil
				for _, p in run.crew do
					local k = table.find(sv.playing, p)
					if k then
						table.remove(sv.playing, k)
					end
					if rand() < cfg.replayShare then
						table.insert(sv.hall, p)
						table.insert(solosWaiting, { p = p, server = sv })
					end
				end
			end
		end
		-- solo players in halls: start the hall run, join it in progress, or wait
		local starts: { [Server]: { Player } } = {}
		for i = #solosWaiting, 1, -1 do
			local w = solosWaiting[i]
			local sv, p = w.server, w.p
			local run = sv.run
			local inHall = table.find(sv.hall, p)
			if inHall == nil then
				table.remove(solosWaiting, i)
			elseif run == nil then
				starts[sv] = starts[sv] or {}
				table.insert(starts[sv], p)
				table.remove(solosWaiting, i)
				table.remove(sv.hall, inHall)
			else
				local stop = math.floor((now - run.startedAt) / 60 / cfg.minutesPerStop) + 1
				if #run.crew < 4 and stop <= cfg.jipMaxStop then
					table.insert(run.crew, p)
					table.insert(sv.playing, p)
					table.remove(sv.hall, inHall)
					table.remove(solosWaiting, i)
					if p.started == nil then
						p.started, p.crew = now, #run.crew
						stats.started += 1
						stats.jip += 1
						local wt = now - p.arrived
						stats.waitSum += wt
						table.insert(stats.waits, wt)
						stats.crewOf[math.min(#run.crew, 4)] += 1
					end
				elseif not p.triedCar then
					-- the hall's run is going and full or too far along: board a car to find a crew instead
					p.triedCar = true
					table.remove(sv.hall, inHall)
					table.remove(solosWaiting, i)
					local car = nil
					for _, c in sv.cars do
						if #c.members < cfg.carMax and (car == nil or #c.members > #car.members) then
							car = c
						end
					end
					if car == nil then
						car = { members = {}, since = nil }
						table.insert(sv.cars, car)
					end
					table.insert(car.members, p)
					if #car.members >= 2 and car.since == nil then
						car.since = now
					end
				elseif now - p.arrived > p.patience and p.started == nil then
					table.remove(sv.hall, inHall)
					table.remove(solosWaiting, i)
					leave(p)
				end
			end
		end
		for sv, crew in starts do
			-- the hall's ready countdown, folded into the start; a crew is at most Tuning.Run.MaxCrew (4)
			while #crew > 4 do
				local p = table.remove(crew) :: Player
				table.insert(sv.hall, p)
				table.insert(solosWaiting, { p = p, server = sv })
			end
			startRun(crew, sv)
		end
		-- reserved servers: AGAIN with whoever plays again
		for i = #reserved, 1, -1 do
			local r = reserved[i]
			if now >= r.endsAt then
				table.remove(reserved, i)
				local again: { Player } = {}
				for _, p in r.crew do
					if rand() < cfg.replayShare then
						table.insert(again, p)
					end
				end
				if #again > 0 then
					startRun(again, nil)
				end
			end
		end
	end

	local function tickQueue()
		-- form crews with the game's own rule (Logic/Matchmaking): oldest first, full or past the earliest deadline
		local entries = {}
		for _, q in queue do
			table.insert(entries, { size = #q.members, deadline = q.deadline })
		end
		local crews = Matchmaking.form(entries, now, cfg.carMax)
		local gone: { number } = {}
		for _, crewIdx in crews do
			local crew: { Player } = {}
			for _, idx in crewIdx do
				for _, p in queue[idx].members do
					table.insert(crew, p)
				end
				table.insert(gone, idx)
			end
			teleport(crew, nil)
		end
		table.sort(gone, function(a, b)
			return a > b
		end)
		for _, idx in gone do
			table.remove(queue, idx)
		end
		-- out of patience in the queue: go solo or leave (a party never gives up on itself)
		for i = #queue, 1, -1 do
			local q = queue[i]
			if q.solo and now >= q.deadline then
				-- happy alone and no crew formed in time: start solo
				table.remove(queue, i)
				teleport(q.members, nil)
			elseif #q.members == 1 and now - q.since > q.members[1].patience then
				table.remove(queue, i)
				if rand() < cfg.goSoloShare then
					teleport(q.members, nil)
				else
					leave(q.members[1])
				end
			end
		end
		for k = #reserved, 1, -1 do
			local r = reserved[k]
			if now >= r.endsAt then
				table.remove(reserved, k)
				local again: { Player } = {}
				for _, p in r.crew do
					if rand() < cfg.replayShare then
						table.insert(again, p)
					end
				end
				if #again > 0 then
					startRun(again, nil)
				end
			end
		end
	end

	local total = math.floor(hours * 3600)
	local warm = math.floor(total * 0.2)
	local perSecond = ccuArrivalsPerMin / 60
	for t = 1, total do
		now = t
		for _ = 1, poisson(rand, perSecond) do
			arrive()
		end
		if setup == "queue" then
			tickQueue()
		else
			tickCurrent()
		end
		if t % 60 == 0 and t > warm then
			local online = 0
			for _, r in reserved do
				online += #r.crew
			end
			for _, sv in servers do
				online += population(sv)
			end
			for _, q in queue do
				online += #q.members
			end
			stats.online += online
			stats.onlineSamples += 1
		end
	end
	table.sort(stats.waits)
	return stats
end

return Sim
