local Tuning = require(Shared.Config.Tuning)
local Doors = require(Shared.Logic.Doors)

describe("Doors.forcing", function()
	it("never forces before stop 3", function()
		for seed = 1, 200 do
			expect(Doors.forcing(seed, 1)).toBe(false)
			expect(Doors.forcing(seed, 2)).toBe(false)
		end
	end)

	it("forces on about 40% of later stops, the same every time for a seed", function()
		local hits, total = 0, 0
		for seed = 1, 2000 do
			if Doors.forcing(seed, 5) then
				hits += 1
			end
			total += 1
			expect(Doors.forcing(seed, 5)).toBe(Doors.forcing(seed, 5))
		end
		expect(hits / total).toBeBetween(0.36, 0.44)
	end)
end)

describe("Doors episodes", function()
	it("runs one shared 3 s timer however many Hollows queue", function()
		local a, b, c = {}, {}, {}
		local episode = Doors.start(100, a)
		Doors.join(episode, b)
		Doors.join(episode, c)
		Doors.join(episode, b) -- no double place
		expect(#episode.queue).toBe(3)
		expect(episode.endsAt).toBe(100 + Tuning.DoorForce.BaseSeconds)
		expect(Doors.done(episode, 102.9)).toBe(false)
		expect(Doors.done(episode, 103)).toBe(true)
	end)

	it("adds the 4 s hold once per episode, whoever holds", function()
		local episode = Doors.start(0, {})
		expect(Doors.hold(episode)).toBe(true)
		expect(Doors.hold(episode)).toBe(false)
		expect(Doors.hold(episode)).toBe(false)
		expect(episode.endsAt).toBe(Tuning.DoorForce.BaseSeconds + Tuning.DoorForce.HoldSeconds)
	end)

	it("lets a Hollow leave the queue and reports progress", function()
		local a, b = {}, {}
		local episode = Doors.start(0, a)
		Doors.join(episode, b)
		Doors.leave(episode, a)
		expect(episode.queue[1]).toBe(b)
		expect(Doors.progress(episode, 1.5)).toBeCloseTo(0.5)
	end)

	it("keeps a forced door open 6 s", function()
		expect(Doors.mayClose(10, 15.9)).toBe(false)
		expect(Doors.mayClose(10, 16)).toBe(true)
	end)
end)
