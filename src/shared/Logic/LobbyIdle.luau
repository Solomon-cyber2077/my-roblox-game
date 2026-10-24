--!strict

-- Pure quiet-time policy. A controller owns input observation and eligibility;
-- this module only tracks one continuous quiet interval and its one-shot attempt.
local LobbyIdle = {}

export type State = {
	startedAt: number,
	delay: number,
	attempted: boolean,
	lastNow: number,
	wasEligible: boolean,
	hasSample: boolean,
}

local function finite(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function LobbyIdle.new(now: number, delay: number): State
	assert(finite(now), "LobbyIdle.new requires a finite time")
	assert(finite(delay) and delay >= 0, "LobbyIdle.new requires a finite non-negative delay")
	return {
		startedAt = now,
		delay = delay,
		attempted = false,
		lastNow = now,
		wasEligible = false,
		hasSample = false,
	}
end

function LobbyIdle.reset(state: State, now: number): State
	assert(finite(now), "LobbyIdle.reset requires a finite time")
	state.startedAt = now
	state.attempted = false
	state.lastNow = now
	state.wasEligible = false
	state.hasSample = true
	return state
end

function LobbyIdle.step(state: State, now: number, eligible: boolean, activeInput: boolean): boolean
	assert(finite(now), "LobbyIdle.step requires a finite time")
	if
		now < state.lastNow
		or not eligible
		or activeInput
		or (state.hasSample and eligible and not state.wasEligible)
	then
		LobbyIdle.reset(state, now)
		state.wasEligible = eligible
		state.lastNow = now
		return false
	end
	if not state.hasSample then
		state.hasSample = true
		state.startedAt = now
		state.wasEligible = eligible
		state.lastNow = now
		return false
	end
	state.lastNow = now
	state.wasEligible = eligible
	if state.attempted or now - state.startedAt < state.delay then
		return false
	end
	state.attempted = true
	return true
end

-- Moves a 0..1 envelope toward `target` linearly: a full rise takes `rise` seconds and a
-- full fall `fall` seconds; a change of direction starts from where it is.
function LobbyIdle.approach(current: number, target: number, rise: number, fall: number, dt: number): number
	if not (finite(current) and finite(target) and finite(dt)) or dt <= 0 then
		return if finite(current) then current else 0
	end
	local span = if target > current then rise else fall
	if not finite(span) or span <= 0 then
		return target
	end
	local step = dt / span
	if target > current then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-- Radians the idle view has turned after `elapsed` seconds: angular speed ramps linearly
-- from still to `speed` degrees per second over `ramp` seconds, then holds.
function LobbyIdle.orbitAngle(elapsed: number, speed: number, ramp: number): number
	if not (finite(elapsed) and finite(speed) and finite(ramp)) or elapsed <= 0 then
		return 0
	end
	local rate = math.rad(speed)
	if ramp <= 0 then
		return rate * elapsed
	end
	if elapsed < ramp then
		return rate * elapsed * elapsed / (2 * ramp)
	end
	return rate * (elapsed - ramp / 2)
end

return LobbyIdle
