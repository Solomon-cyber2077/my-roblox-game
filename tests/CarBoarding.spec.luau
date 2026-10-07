local CarBoarding = require(Shared.Logic.CarBoarding)
local Tuning = require(Shared.Config.Tuning)

local Cars = Tuning.Cars

local function car(count, startedAt, departing)
	return { count = count, startedAt = startedAt, departing = departing == true }
end

describe("CarBoarding", function()
	it("lets people in until the car is full or leaving", function()
		expect(CarBoarding.canEnter(car(0))).toBe(true)
		expect(CarBoarding.canEnter(car(Cars.MaxPlayers - 1))).toBe(true)
		expect(CarBoarding.canEnter(car(Cars.MaxPlayers))).toBe(false)
		expect(CarBoarding.canEnter(car(2, 0, true))).toBe(false)
	end)

	it("starts the countdown only once enough are aboard", function()
		expect(CarBoarding.afterEnter(car(1), 5)).toBe(nil)
		expect(CarBoarding.afterEnter(car(Cars.MinPlayers), 5)).toBe(5)
		-- a third boarder keeps the running countdown
		expect(CarBoarding.afterEnter(car(3, 2), 5)).toBe(2)
	end)

	it("starts the countdown over when someone leaves, or stops it", function()
		expect(CarBoarding.afterLeave(car(Cars.MinPlayers, 2), 7)).toBe(7)
		expect(CarBoarding.afterLeave(car(Cars.MinPlayers - 1, 2), 7)).toBe(nil)
	end)

	it("opens the door before the countdown and in its first seconds only", function()
		expect(CarBoarding.canExit(car(1), 100)).toBe(true)
		expect(CarBoarding.canExit(car(2, 0), Cars.ExitWindowSeconds - 0.1)).toBe(true)
		expect(CarBoarding.canExit(car(2, 0), Cars.ExitWindowSeconds)).toBe(false)
		expect(CarBoarding.canExit(car(2, nil, true), 0)).toBe(false)
	end)

	it("leaves when full or when the countdown ends, never alone", function()
		expect(CarBoarding.shouldDepart(car(Cars.MaxPlayers, 0), 0)).toBe(true)
		expect(CarBoarding.shouldDepart(car(2, 0), Cars.CountdownSeconds - 1)).toBe(false)
		expect(CarBoarding.shouldDepart(car(2, 0), Cars.CountdownSeconds)).toBe(true)
		expect(CarBoarding.shouldDepart(car(1), 1e6)).toBe(false)
		expect(CarBoarding.shouldDepart(car(Cars.MaxPlayers, 0, true), 0)).toBe(false)
	end)

	it("counts the countdown down", function()
		expect(CarBoarding.remaining(car(1), 3)).toBe(nil)
		expect(CarBoarding.remaining(car(2, 10), 15)).toBe(Cars.CountdownSeconds - 5)
		expect(CarBoarding.exitRemaining(car(2, 10), 15)).toBe(Cars.ExitWindowSeconds - 5)
	end)
end)
