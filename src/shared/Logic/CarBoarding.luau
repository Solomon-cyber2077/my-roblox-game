--!strict
--[[
	Boarding-car rules as pure functions. CarService owns the cars and the clock;
	this module decides who may get in or out and when a car leaves.

	A car's countdown starts when MinPlayers are aboard and starts over whenever
	someone gets out. People may get out before the countdown starts and during
	its first ExitWindowSeconds. A car leaves when it is full or its countdown ends.
	A rider left alone leaves solo after SoloWaitSeconds, so a quiet hall strands nobody.
]]

local Shared = script.Parent.Parent
local Tuning = require(Shared.Config.Tuning)

export type Car = {
	count: number,
	startedAt: number?, -- when the countdown started, nil while waiting for crew
	departing: boolean,
	soloSince: number?, -- when the rider was left alone, nil unless the car is below MinPlayers
}

local CarBoarding = {
	SoloWaitSeconds = 45, -- past the crew queue's own fallback, so a match still comes first
}

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

-- The lone rider's wait after someone got in or out: it runs on, or starts, while the car is under MinPlayers.
function CarBoarding.afterChange(car: Car, now: number): number?
	if car.count == 0 or car.count >= Tuning.Cars.MinPlayers then
		return nil
	end
	return car.soloSince or now
end

-- Seconds until a lone rider leaves solo, nil when nobody is waiting alone.
function CarBoarding.soloRemaining(car: Car, now: number): number?
	local soloSince = car.soloSince
	if soloSince == nil then
		return nil
	end
	return math.max(soloSince + CarBoarding.SoloWaitSeconds - now, 0)
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
	if car.departing or car.count == 0 then
		return false
	end
	if car.count < Tuning.Cars.MinPlayers then
		local solo = CarBoarding.soloRemaining(car, now)
		return solo ~= nil and solo <= 0
	end
	if car.count >= Tuning.Cars.MaxPlayers then
		return true
	end
	local left = CarBoarding.remaining(car, now)
	return left ~= nil and left <= 0
end

return CarBoarding
