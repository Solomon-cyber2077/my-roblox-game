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

return LobbyIdle
