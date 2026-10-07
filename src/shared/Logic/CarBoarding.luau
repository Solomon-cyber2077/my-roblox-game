--!strict
--[[
	Boarding-car rules as pure functions. CarService owns the cars and the clock;
	this module decides who may get in or out and when a car leaves.

	A car's countdown starts when MinPlayers are aboard and starts over whenever
	someone gets out. People may get out before the countdown starts and during
	its first ExitWindowSeconds. A car leaves when it is full or its countdown ends.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

export type Car = {
	count: number,
	startedAt: number?, -- when the countdown started, nil while waiting for crew
	departing: boolean,
}

local CarBoarding = {}

function CarBoarding.canEnter(car: Car): boolean
	return not car.departing and car.count < Tuning.Cars.MaxPlayers
end

function CarBoarding.canExit(car: Car, now: number): boolean
	if car.departing then
		return false
	end
	local startedAt = car.startedAt
	return startedAt == nil or now - startedAt < Tuning.Cars.ExitWindowSeconds
end

-- The countdown after someone got in.
function CarBoarding.afterEnter(car: Car, now: number): number?
	if car.startedAt == nil and car.count >= Tuning.Cars.MinPlayers then
		return now
	end
	return car.startedAt
end

-- The countdown after someone got out or dropped: it starts over, or stops below MinPlayers.
function CarBoarding.afterLeave(car: Car, now: number): number?
	return if car.count >= Tuning.Cars.MinPlayers then now else nil
end

-- Seconds left on the countdown, nil while waiting for crew.
function CarBoarding.remaining(car: Car, now: number): number?
	local startedAt = car.startedAt
	if startedAt == nil then
		return nil
	end
	return math.max(startedAt + Tuning.Cars.CountdownSeconds - now, 0)
end

-- Seconds left to get out, 0 once the doors are locked.
function CarBoarding.exitRemaining(car: Car, now: number): number
	local startedAt = car.startedAt
	if car.departing then
		return 0
	elseif startedAt == nil then
		return math.huge
	end
	return math.max(startedAt + Tuning.Cars.ExitWindowSeconds - now, 0)
end

function CarBoarding.shouldDepart(car: Car, now: number): boolean
	if car.departing or car.count < Tuning.Cars.MinPlayers then
		return false
	end
	if car.count >= Tuning.Cars.MaxPlayers then
		return true
	end
	local left = CarBoarding.remaining(car, now)
	return left ~= nil and left <= 0
end

return CarBoarding
