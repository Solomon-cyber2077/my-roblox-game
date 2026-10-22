--!strict
--[[
	Steam leaks (Config/Difficulty Leaks). Pure: TrainService runs them, Ledger drains with them.

	A trip plans its leaks when it sets off: how many (the stop's expected count by station
	difficulty, fewer with Armour Plating, at most EarlyCap at stops 1..EarlyUntilStop and Cap
	after) and when, as shares of the trip: FirstShare, then Spacing apart, each +/- Jitter.

	A leak drains hull only while the train is moving. Its severity grows with the travel time it
	has been left open, as a share of the trip it is on: 1 + Growth * age / trip (MaxSeverity at
	most). It drains K * severity / trip hull per second, where K makes one leak opened at
	FirstShare and left alone cost OneLeakTrip over its trip, whatever the trip's length:

	    cost of a leak opened at share u0 = K * ((1 - u0) + Growth * (1 - u0)^2 / 2)
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local UpgradesConfig = require(Shared.Config.Upgrades)
local MathX = require(Shared.Util.MathX)

local C = Difficulty.Leaks

local Leaks = {}

-- Hull a leak opened at share `u0` costs over the rest of its trip, per unit of K.
local function integral(u0: number): number
	local rest = math.clamp(1 - u0, 0, 1)
	return rest + C.Growth * rest * rest / 2
end

-- The drain scale: hull % per (severity x trip-length), from OneLeakTrip.
function Leaks.k(): number
	return C.OneLeakTrip / integral(C.FirstShare)
end

-- Most leaks a trip toward stop `stop` may hold; a first run's first cruise holds none.
function Leaks.cap(stop: number, tutorialTier: number?): number
	if tutorialTier == 1 and stop <= 1 then
		return C.FirstCruiseCap
	end
	return if stop <= C.EarlyUntilStop then C.EarlyCap else C.Cap
end

-- Leaks a trip plans: `roll` in [0, 1) decides the fractional part of the expected count.
function Leaks.count(
	stop: number,
	d: number,
	upgrades: { [string]: number }?,
	roll: number,
	tutorialTier: number?
): number
	local armour = if upgrades then upgrades.ArmorPlating or 0 else 0
	local expected = MathX.lerp(C.ExpectedPerTrip[1], C.ExpectedPerTrip[2], MathX.saturate(d))
		* UpgradesConfig.Effects.BreachMultiplierPerLevel ^ armour
	local whole = math.floor(expected)
	local n = whole + (if roll < expected - whole then 1 else 0)
	return math.clamp(n, 0, Leaks.cap(stop, tutorialTier))
end

-- When each of `n` leaks bursts, as shares of the trip. `jitter(i)` in [-1, 1].
function Leaks.shares(n: number, jitter: (number) -> number): { number }
	local out = {}
	for i = 1, n do
		local u = C.FirstShare + (i - 1) * C.Spacing + C.Jitter * math.clamp(jitter(i), -1, 1)
		table.insert(out, math.clamp(u, 0.02, 0.9))
	end
	return out
end

-- A leak's severity after `age` seconds of travel open, on a trip of `tripSeconds`.
function Leaks.severity(age: number, tripSeconds: number): number
	local trip = math.max(tripSeconds, 1)
	return math.min(1 + C.Growth * math.max(age, 0) / trip, C.MaxSeverity)
end

-- Hull % per second a leak of `severity` drains on a trip of `tripSeconds`.
function Leaks.rate(severity: number, tripSeconds: number): number
	return Leaks.k() * severity / math.max(tripSeconds, 1)
end

-- Hull % that leaks opened at these shares cost over their trip if nobody patches them.
function Leaks.tripCost(shares: { number }): number
	local total = 0
	for _, u in shares do
		total += Leaks.k() * integral(u)
	end
	return total
end

return table.freeze(Leaks)
