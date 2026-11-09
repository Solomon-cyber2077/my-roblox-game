local Passenger = require(Shared.Logic.Passenger)
local Passengers = require(Shared.Config.Passengers)
local Rng = require(Shared.Util.Rng)

local function ctx(over: { [string]: any }): any
	local base = {
		sitting = false,
		satFor = 0,
		seatFree = true,
		othersSitting = 0,
		handNear = false,
		canGreet = false,
	}
	for k, v in over do
		base[k] = v
	end
	return base
end

local function tally(c: any, sitTime: number?): { [string]: number }
	local rng = Rng.new(7)
	local counts: { [string]: number } = {}
	for _ = 1, 2000 do
		local action = Passenger.choose(rng, c, sitTime or 30)
		counts[action] = (counts[action] or 0) + 1
	end
	return counts
end

describe("Passenger.choose", function()
	it("mixes walking, sitting and standing about, so nobody follows one script", function()
		local counts = tally(ctx({}))
		expect(counts.wander or 0).toBeGreaterThan(600)
		expect(counts.sit or 0).toBeGreaterThan(250)
		expect(counts.idle or 0).toBeGreaterThan(400)
		expect(counts.greet).toBe(nil)
	end)

	it("never sits when no seat is free or enough are already seated", function()
		expect(tally(ctx({ seatFree = false })).sit).toBe(nil)
		expect(tally(ctx({ othersSitting = Passengers.Walk.maxSitting })).sit).toBe(nil)
	end)

	it("greets a Hand nearby most of the time, but only off cooldown", function()
		local counts = tally(ctx({ handNear = true, canGreet = true }))
		expect(counts.greet).toBeBetween(1250, 1550)
		expect(tally(ctx({ handNear = true, canGreet = false })).greet).toBe(nil)
	end)

	it("stays seated until the time is up, then stands", function()
		local seated = tally(ctx({ sitting = true, satFor = 5 }), 30)
		expect(seated.idle).toBe(2000)
		local done = tally(ctx({ sitting = true, satFor = 31 }), 30)
		expect(done.stand).toBe(2000)
	end)
end)

describe("Passenger lines", function()
	it("cycles through the lines and comes round again", function()
		expect(Passenger.nextLine(0, 3)).toBe(1)
		expect(Passenger.nextLine(1, 3)).toBe(2)
		expect(Passenger.nextLine(3, 3)).toBe(1)
		expect(Passenger.nextLine(0, 0)).toBe(0)
	end)

	it("gives everyone about three lines, short enough for a bubble", function()
		for _, person in Passengers.People do
			expect(#person.lines).toBe(3)
			for _, line in person.lines do
				expect(#line).toBeLessThan(90)
			end
		end
	end)
end)

describe("Passenger manners", function()
	it("greets the same Hand again only after the cooldown", function()
		local cooldown = Passengers.Walk.greetCooldown
		expect(Passenger.offCooldown(10, nil, cooldown)).toBe(true)
		expect(Passenger.offCooldown(10 + cooldown - 1, 10, cooldown)).toBe(false)
		expect(Passenger.offCooldown(10 + cooldown + 0.1, 10, cooldown)).toBe(true)
	end)

	it("comes round to the first line on the fourth greeting", function()
		local line = 0
		for _ = 1, 4 do
			line = Passenger.nextLine(line, 3)
		end
		expect(line).toBe(1)
	end)

	it("lets only one speak at a time: a bubble ends before the next greeting", function()
		local gap = Passengers.Walk.greetGap
		expect(gap).toBeGreaterThan(Passengers.Bubble.seconds)
		expect(Passenger.mayGreet(100, 100 - gap + 0.5, gap)).toBe(false)
		expect(Passenger.mayGreet(100, 100 - gap, gap)).toBe(true)
	end)

	it("after a failed walk, settles on a free spot, not on someone else's", function()
		local spots = Passengers.Hall.spots
		local s14 = spots[14]
		-- stuck right by spot 14 while someone else holds it: the old rule (nearest) put both on 14
		expect(Passenger.nearest(spots, s14.x + 0.5, s14.z)).toBe(14)
		local free = Passenger.nearestFree(spots, s14.x + 0.5, s14.z, { [14] = true })
		expect(free ~= 14).toBe(true)
		-- no free spot means wait, never claim an occupied spot
		local all: { [number]: boolean } = {}
		for i = 1, #spots do
			all[i] = true
		end
		expect(Passenger.nearestFree(spots, s14.x, s14.z, all)).toBe(nil)
	end)

	it("recovers along a clear segment instead of walking through a solid obstacle", function()
		local spots = { { x = 4, z = 0 }, { x = 0, z = 8 } }
		local boxes = { { x0 = 1, z0 = -1, x1 = 3, z1 = 1 } }
		expect(Passenger.nearestFree(spots, 0, 0, {}, boxes, 0)).toBe(2)
		expect(Passenger.nearestFree(spots, 0, 0, { [2] = true }, boxes, 0)).toBe(nil)
	end)
	it("keeps people on separate spots further apart than their personal space", function()
		local spots = Passengers.Hall.spots
		local closest = math.huge
		for i = 1, #spots do
			for j = i + 1, #spots do
				closest = math.min(
					closest,
					math.sqrt((spots[i].x - spots[j].x) ^ 2 + (spots[i].z - spots[j].z) ^ 2)
				)
			end
		end
		expect(closest).toBeGreaterThan(Passengers.Walk.personalSpace * 2)
	end)

	it("never sends two to the same spot", function()
		local rng = Rng.new(3)
		local taken = { [14] = true, [15] = true, [19] = true, [20] = true, [24] = true }
		for _ = 1, 200 do
			local to = Passenger.pickSpot(rng, #Passengers.Hall.spots, Passengers.Hall.seen, taken)
			expect(to ~= nil and not taken[to :: number]).toBe(true)
		end
		local all: { [number]: boolean } = {}
		for i = 1, #Passengers.Hall.spots do
			all[i] = true
		end
		expect(Passenger.pickSpot(rng, #Passengers.Hall.spots, Passengers.Hall.seen, all)).toBe(nil)
	end)
end)

describe("Passenger walk graph", function()
	local hall = Passengers.Hall

	it("links only real spots and reaches every spot from every other", function()
		for _, link in hall.links do
			expect(hall.spots[link[1]] ~= nil and hall.spots[link[2]] ~= nil).toBe(true)
		end
		for i = 1, #hall.spots do
			local path = Passenger.route(hall.links, 1, i)
			expect(path ~= nil).toBe(true)
			if path then
				expect(path[1]).toBe(1)
				expect(path[#path]).toBe(i)
			end
		end
	end)

	it("keeps every spot and link out of the kept-out areas", function()
		local margin = Passengers.Walk.clearance
		for _, box in hall.keepOut do
			for _, s in hall.spots do
				expect(Passenger.clearOf(s.x, s.z, s.x, s.z, box, margin)).toBe(true)
			end
			for _, link in hall.links do
				local a, b = hall.spots[link[1]], hall.spots[link[2]]
				expect(Passenger.clearOf(a.x, a.z, b.x, b.z, box, margin)).toBe(true)
			end
		end
	end)

	it("names only real spots as the ones seen from the spawn", function()
		for _, i in hall.seen do
			expect(hall.spots[i] ~= nil).toBe(true)
		end
	end)

	it("builds no more people than it has, and keeps fewer on Performance", function()
		expect(hall.count).toBeAtMost(#Passengers.People)
		expect(hall.performance).toBeLessThan(hall.count)
	end)
end)

describe("Passenger geometry", function()
	local box = { x0 = 0, z0 = 0, x1 = 10, z1 = 10 }

	it("tells a walk that crosses a box from one that passes it", function()
		expect(Passenger.clearOf(-5, 5, 15, 5, box, 0)).toBe(false)
		expect(Passenger.clearOf(-5, 12, 15, 12, box, 1)).toBe(true)
		expect(Passenger.clearOf(-5, 10.5, 15, 10.5, box, 1)).toBe(false) -- inside the margin
		expect(Passenger.clearOf(-5, -5, -1, -1, box, 0)).toBe(true) -- stops short
		expect(Passenger.clearOf(5, 5, 5, 5, box, 0)).toBe(false) -- standing inside
	end)

	it("approaches a seat from its open side", function()
		local spots = { { x = 0, z = 10 }, { x = 0, z = -4 } }
		-- the seat faces -Z, its front at (0, 0): the spot at z = -4 is in front, though further
		expect(Passenger.approach(spots, 0, 0, 0, -1)).toBe(2)
		expect(Passenger.approach(spots, 0, 0, 0, 1)).toBe(1)
		expect(Passenger.nearest(spots, 0, 2)).toBe(2)
	end)
end)
