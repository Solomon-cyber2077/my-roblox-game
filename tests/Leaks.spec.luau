local Difficulty = require(Shared.Config.Difficulty)
local Leaks = require(Shared.Logic.Leaks)
local Ledger = require(Shared.Logic.Ledger)

local C = Difficulty.Leaks

-- Plays a trip of `seconds` frame by frame with leaks bursting at `shares`; nobody patches.
local function ride(seconds: number, shares: { number }): number
	local train = Ledger.newTrain()
	local dt = 0.25
	local t = 0
	local opened = 0
	while t < seconds - 1e-9 do
		while opened < #shares and t >= shares[opened + 1] * seconds - 1e-9 do
			opened += 1
			train = Ledger.openBreach(train, `L{opened}`, "CR1", 0)
		end
		train = Ledger.drain(train, dt, seconds)
		t += dt
	end
	return 100 - train.integrity
end

local function centred(n: number): { number }
	return Leaks.shares(n, function()
		return 0
	end)
end

describe("Leaks", function()
	it("costs about 10-15% of the hull for one leak left alone over a trip", function()
		local cost = Leaks.tripCost(centred(1))
		expect(cost).toBeAtLeast(10)
		expect(cost).toBeAtMost(15)
	end)

	it("costs about 35-45% for three", function()
		local cost = Leaks.tripCost(centred(3))
		expect(cost).toBeAtLeast(35)
		expect(cost).toBeAtMost(45)
	end)

	it("holds those costs on short and long trips alike: the rate follows the trip's length", function()
		for _, seconds in { 30, 48, 66, 90 } do
			expect(math.abs(ride(seconds, centred(1)) - Leaks.tripCost(centred(1)))).toBeLessThan(0.6)
			expect(math.abs(ride(seconds, centred(3)) - Leaks.tripCost(centred(3)))).toBeLessThan(1.5)
		end
		-- and the jitter keeps them in range
		for _, j in { -1, 1 } do
			local shares = Leaks.shares(3, function()
				return j
			end)
			expect(Leaks.tripCost(shares)).toBeAtLeast(33)
			expect(Leaks.tripCost(shares)).toBeAtMost(47)
		end
	end)

	it("grows a leak left alone, up to MaxSeverity", function()
		expect(Leaks.severity(0, 60)).toBe(1)
		expect(Leaks.severity(60, 60)).toBeCloseTo(1 + C.Growth)
		expect(Leaks.severity(6000, 60)).toBe(C.MaxSeverity)
		expect(Leaks.rate(2, 60)).toBeCloseTo(2 * Leaks.rate(1, 60))
	end)

	it("caps stops 1-3 at one leak and the rest at Cap", function()
		for stop = 1, 10 do
			for _, roll in { 0, 0.5, 0.999 } do
				local n = Leaks.count(stop, 1, nil, roll)
				expect(n).toBeAtMost(if stop <= 3 then 1 else C.Cap)
			end
		end
		expect(Leaks.cap(3)).toBe(1)
		expect(Leaks.cap(4)).toBe(C.Cap)
	end)

	it("plans fewer leaks with Armour Plating, and starts them a little into the trip", function()
		local plain = Leaks.count(8, 1, nil, 0.3)
		local armoured = Leaks.count(8, 1, { ArmorPlating = 2 }, 0.3)
		expect(armoured).toBeAtMost(plain)
		for _, u in centred(3) do
			expect(u).toBeAtLeast(C.FirstShare - 1e-9)
		end
	end)
end)

describe("Leaks on a first run", function()
	it("plans no leak on a first run's first cruise, and the usual cap after", function()
		for roll = 0, 0.99, 0.11 do
			expect(Leaks.count(1, 1, nil, roll, 1)).toBe(0)
		end
		expect(Leaks.cap(1, 1)).toBe(0)
		expect(Leaks.cap(2, 1)).toBe(C.EarlyCap)
		expect(Leaks.cap(1, 2)).toBe(C.EarlyCap)
		expect(Leaks.cap(1, nil)).toBe(C.EarlyCap)
	end)
end)
