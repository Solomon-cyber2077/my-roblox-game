local DifficultyModel = require(Shared.Logic.DifficultyModel)
local Journey = require(Shared.Logic.Journey)
local JourneyPlan = require(Shared.Logic.JourneyPlan)
local Motion = require(Shared.Logic.Motion)
local RouteGen = require(Shared.Logic.RouteGen)
local RunRules = require(Shared.Logic.RunRules)
local Tuning = require(Shared.Config.Tuning)

local DT = 1 / 30
local STOPS = Tuning.Run.StationCount
local J = Tuning.Journey

--[[
	Plays a run the way the server and a client would: the route from RouteGen,
	cruise lengths from DifficultyModel, the station on the Motion profiles, the
	scenery scrolling at JourneyPlan.speed and the plan stepped every frame.

	options.skipCruise[leg] = seconds: a dev skip that ends that cruise early.
	options.onDwell(stop, plan, odometer): called on the first frame of each stop.
]]
local function play(seed: number, options: { [string]: any }?)
	local opts = options or {}
	local plan = JourneyPlan.new()
	local run: { [string]: any } = { runId = `run{seed}`, seed = seed, stopCount = STOPS, nextStop = 1 }
	local now, odometer, speed = 0, 0, 0
	local log = { recuts = 0, rebuilds = 0, minGap = math.huge }
	local stationGone = math.huge -- server time the departed station despawns
	local departAccel = 5
	local departStart = 0

	local function frames(phase: string, duration: number, station: ((number) -> (number?, number?))?)
		run.phaseStartedAt = now
		run.phaseEndsAt = now + duration
		local start = now
		local first = true
		while now < run.phaseEndsAt - 1e-9 do
			local elapsed = now - start
			local x, v = nil, nil
			if station then
				x, v = station(elapsed)
			end
			speed = JourneyPlan.speed(speed, phase, DT, v, elapsed)
			odometer += speed * DT
			local before = plan.upcoming
			local result = JourneyPlan.step(plan, {
				phase = phase,
				active = RunRules.isRunPhase(phase :: any),
				run = run,
				odometer = odometer,
				speed = speed,
				now = now,
				stationX = x,
			})
			odometer += JourneyPlan.correction(plan, phase, odometer, x, DT)
			if result.rebuild then
				log.rebuilds += 1
			end
			-- a re-cut replaces the sinkhole already cut for this stop
			if before and plan.upcoming and plan.upcoming ~= before then
				log.recuts += 1
			end
			if first and opts.onPhase then
				opts.onPhase(phase, plan, odometer, x)
			end
			first = false
			now += DT
			if opts.skip and opts.skip(phase, run.nextStop, elapsed) then
				run.phaseEndsAt = now
			end
		end
	end

	local function departing(offset: number): (number) -> (number?, number?)
		return function(elapsed)
			local t = elapsed + offset
			if now >= stationGone then
				return nil, nil
			end
			return Motion.departureOffset(t, departAccel), Motion.departureVelocity(t, departAccel)
		end
	end

	frames("Boarding", Tuning.Run.BoardingSeconds, nil)
	local last: string? = nil
	for stop = 1, STOPS + 1 do
		run.nextStop = stop
		local final = stop > STOPS
		local junction = if final then Tuning.Run.FinalJunctionSeconds else Tuning.Run.JunctionSeconds
		frames("Junction", junction, if stop > 1 then departing(departStart) else nil)
		local option = if final
			then RouteGen.terminusOption()
			else RouteGen.options(seed, stop, STOPS, last)[1]
		last = option.archetype
		run.destination = { archetype = option.archetype }
		frames("Cruise", DifficultyModel.cruiseSeconds(option.distanceKm), nil)
		run.station = { archetype = option.archetype }
		frames("Arrival", Tuning.Run.ArrivalSeconds, function(elapsed)
			return Motion.arrivalOffset(elapsed), Motion.arrivalVelocity(elapsed)
		end)
		local docked = function(_: number): (number?, number?)
			return 0, 0
		end
		if final then
			frames("Terminus", Tuning.Run.TerminusSeconds, docked)
			break
		end
		frames("Dwell", 45, docked)
		frames("LastCall", Tuning.Run.LastCallSeconds, docked)
		frames("Departure", 6, departing(0))
		departStart = 6
		stationGone = now + Tuning.Motion.DepartureLingerSeconds
		run.station = nil
	end
	return plan, log, odometer
end

local function checkDocks(seed: number, options: { [string]: any }?)
	local docks = 0
	local opts = options or {}
	opts.onPhase = function(phase, plan, odometer, x)
		if phase == "Dwell" or phase == "Terminus" then
			docks += 1
			local upcoming = plan.upcoming
			expect(upcoming ~= nil).toBe(true)
			-- the docked station (x = 0) sits on the centre of its sinkhole
			expect(math.abs(upcoming.center - (odometer + (x or 0)))).toBeLessThan(0.05)
			for _, piece in plan.pieces do
				if piece.leg == plan.leg then
					expect(piece.at + piece.length).toBeAtMost(upcoming.rect.x0 - J.DockClearance)
				end
			end
		end
	end
	local plan, log = play(seed, opts)
	expect(docks).toBe(STOPS + 1)
	return plan, log
end

describe("JourneyPlan runs", function()
	it("docks every station on its sinkhole without re-cutting", function()
		for _, seed in { 11, 2024, 777777 } do
			local _, log = checkDocks(seed)
			expect(log.recuts).toBe(0)
			expect(log.rebuilds).toBe(1)
		end
	end)

	it("re-cuts the sinkhole when a dev skip ends a cruise early", function()
		local skipped = false
		local _, log = checkDocks(5, {
			skip = function(phase, stop, elapsed)
				if phase == "Cruise" and stop == 3 and elapsed > 5 and not skipped then
					skipped = true
					return true
				end
				return false
			end,
		})
		expect(skipped).toBe(true)
		expect(log.recuts).toBe(1)
	end)

	it("plans every leg's biome change and ends at sunrise", function()
		local plan = checkDocks(42)
		expect(#plan.transitions).toBeAtLeast(1)
		local final = plan.transitions[#plan.transitions]
		expect(final.biome).toBe("Coast")
		expect(plan.progress).toBeCloseTo(STOPS + 1, 1e-6)
		expect(Journey.clock(Journey.hour(plan.progress, STOPS))).toBeCloseTo(J.Sky[#J.Sky].hour % 24, 1e-6)
	end)

	it("keeps the sky moving forward through the run", function()
		local last = -1
		play(9, {
			onPhase = function(_, plan)
				expect(plan.progress).toBeAtLeast(last - 1e-9)
				last = plan.progress
			end,
		})
		expect(last).toBeGreaterThan(STOPS)
	end)
end)

describe("JourneyPlan joins and speed", function()
	it("picks up a run joined mid-stop", function()
		local plan = JourneyPlan.new()
		local result = JourneyPlan.step(plan, {
			phase = "Dwell",
			active = true,
			run = {
				runId = "late",
				seed = 99,
				stopCount = STOPS,
				nextStop = 4,
				destination = { archetype = "Minehead" },
				station = { archetype = "Minehead" },
			},
			odometer = 12345,
			speed = 0,
			now = 0,
			stationX = 0,
		})
		expect(result.rebuild).toBe(true)
		expect(plan.leg).toBe(4)
		expect(plan.upcoming and plan.upcoming.center).toBeCloseTo(12345, 1e-6)
		expect(plan.progress).toBeCloseTo(4, 1e-6)
		expect(plan.base).toBe("Mountain")
	end)

	it("follows a moving station exactly and spins up otherwise", function()
		expect(JourneyPlan.speed(50, "Arrival", DT, -42, 3)).toBe(42)
		expect(JourneyPlan.speed(50, "Arrival", DT, nil, 0)).toBeCloseTo(-Motion.arrivalVelocity(0), 1e-6)
		expect(JourneyPlan.speed(50, "Junction", DT, -30, 1)).toBe(30)
		expect(JourneyPlan.speed(50, "Cruise", 1, nil, 0)).toBe(50 + Tuning.Motion.SpinUp)
		expect(JourneyPlan.speed(50, "Dwell", DT, 0, 0)).toBe(0)
		expect(JourneyPlan.speed(5, "RunEnd", 1, nil, 0)).toBe(0)
	end)
end)
