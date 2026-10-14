local Breakdown = require(Shared.Logic.Breakdown)
local Difficulty = require(Shared.Config.Difficulty)
local Leaks = require(Shared.Logic.Leaks)
local Ledger = require(Shared.Logic.Ledger)
local Types = require(Shared.Types)

local C = Difficulty.Breakdown
local TRIP = 60

-- A rally made good at `at`: halted at 0, rallied, every repair made at `at`.
local function rallied(at: number): Breakdown.State
	local s = Breakdown.onFloor(Breakdown.new(), 0, false)
	s = Breakdown.tick(s, C.StopSeconds)
	for _ = 1, C.RallyRepairs do
		s = Breakdown.repair(s, at)
	end
	return s
end

-- Runs the train from `from` to `to` in 1 s steps as TrainService does: leaks held in the grace.
local function run(train: Types.TrainState, s: Breakdown.State, from: number, to: number): Types.TrainState
	for t = from, to - 1 do
		train = Ledger.drain(train, 1, TRIP, Breakdown.inGrace(s, t))
	end
	return train
end

local function leaky(): Types.TrainState
	local train = Ledger.openBreach(Ledger.newTrain(), "b1", "Car2", 0)
	train = Ledger.openBreach(train, "b2", "Car3", 0)
	train.integrity = C.RallyRestore
	return train
end

describe("Repair grace", function()
	it("starts on a successful rally and on a village with enough parts", function()
		local s = rallied(100)
		expect(s.phase).toBe("Limp")
		expect(s.graceUntil).toBe(100 + C.RepairGraceSeconds)
		expect(Breakdown.inGrace(s, 100)).toBe(true)
		expect(Breakdown.graceLeft(s, 100)).toBe(C.RepairGraceSeconds)
		expect(Breakdown.inGrace(s, 100 + C.RepairGraceSeconds)).toBe(false)
		expect(Breakdown.graceLeft(s, 100 + C.RepairGraceSeconds)).toBe(0)
		local v = Breakdown.onFloor(Breakdown.new(), 0, true)
		v = Breakdown.villageDone(v, C.VillageParts, C.VillageParts, 50)
		expect(v.graceUntil).toBe(50 + C.RepairGraceSeconds)
	end)

	it("pauses the leaks' drain during the grace", function()
		local train = run(leaky(), rallied(0), 0, C.RepairGraceSeconds)
		expect(train.integrity).toBe(C.RallyRestore)
		expect(Ledger.breachCount(train)).toBe(2) -- still open
		expect(train.breaches.b1.age).toBe(0) -- and no worse
	end)

	it("resumes the drain after the grace at the old rate", function()
		local s = rallied(0)
		local held = run(leaky(), s, 0, C.RepairGraceSeconds + 1)
		local fresh = Ledger.drain(leaky(), 1, TRIP)
		expect(held.integrity).toBeCloseTo(fresh.integrity)
		expect(C.RallyRestore - held.integrity).toBeCloseTo(2 * Leaks.rate(1, TRIP))
	end)

	it("keeps the hull where it is once every leak is patched", function()
		local s = rallied(0)
		local train = leaky()
		train.parts = 5
		train = run(train, s, 0, 5)
		train = Ledger.patchBreach(train, "b1")
		train = Ledger.patchBreach(train, "b2")
		train = run(train, s, 5, C.RepairGraceSeconds + 60)
		expect(train.integrity).toBe(C.RallyRestore)
	end)

	it("restarts with a new success", function()
		local v = Breakdown.onFloor(Breakdown.new(), 0, true)
		v = Breakdown.villageDone(v, C.VillageParts, C.VillageParts, 10)
		local later = Breakdown.villageDone(
			Breakdown.onFloor(Breakdown.new(), 0, true),
			C.VillageParts,
			C.VillageParts,
			500
		)
		expect(later.graceUntil).toBe(500 + C.RepairGraceSeconds)
		-- a short village falls back on the rally; making that good restarts the grace from then
		local short = Breakdown.villageDone(Breakdown.onFloor(Breakdown.new(), 0, true), 0, 3, 10)
		short = Breakdown.tick(short, 10 + C.StopSeconds)
		for _ = 1, C.RallyRepairs do
			short = Breakdown.repair(short, 200)
		end
		expect(short.graceUntil).toBe(200 + C.RepairGraceSeconds)
		expect(Breakdown.inGrace(v, 10 + C.RepairGraceSeconds + 1)).toBe(false)
	end)

	it("does not touch a failed rally: it still loses the train, with no grace", function()
		local s = Breakdown.onFloor(Breakdown.new(), 0, false)
		s = Breakdown.tick(s, C.StopSeconds)
		s = Breakdown.repair(s, 10)
		s = Breakdown.tick(s, C.StopSeconds + C.RallySeconds)
		expect(s.phase).toBe("Lost")
		expect(s.graceUntil).toBe(nil)
		expect(Breakdown.inGrace(s, 20)).toBe(false)
		-- and a second breakdown after a good rally is still the end, grace or not
		local again = Breakdown.onFloor(rallied(0), 1, false)
		expect(again.phase).toBe("Lost")
		expect(Breakdown.inGrace(again, 1)).toBe(false)
	end)

	it("ends when the train reaches its stop", function()
		expect(Breakdown.arrive(rallied(0)).graceUntil).toBe(nil)
	end)
end)
