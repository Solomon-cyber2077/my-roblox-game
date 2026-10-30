--!strict
--[[
	The touch action button (launch hardening step 5). Pure: UI/ActionButton feeds it the prompts
	ProximityPromptService shows for touch and the thumb's presses, and does what it returns.

	One button, labelled for the one prompt in range: the most recently shown one that is still shown
	(the engine's own choice, one prompt per input at a time). A tap triggers a prompt with no hold; a
	prompt whose server rule needs a hold (HoldDuration > 0) is held for that long. The hold is cancelled
	when its prompt goes (out of range, used up, destroyed) or another takes its place. Keyboard E and
	gamepad X keep driving the same prompts, so every input meets the same server checks.

	  show(state, entry)     a prompt appeared; returns the id whose hold must end, if one was cut off
	  hide(state, id)        a prompt went; returns the id whose hold must end, if it was held
	  target(state)          the prompt the button acts on, or nil (button hidden)
	  press(state, now)      the thumb went down: the id to begin holding
	  release(state)         the thumb came up: the id to end holding
	  progress(state, now)   0..1 of the current hold (0 when not holding or a tap prompt)
	  label(action, object)  the button's words, upper case, kept short for a phone
]]

export type Entry = { id: any, action: string, object: string, hold: number }
export type State = { shown: { Entry }, holding: any?, holdStartedAt: number? }

local MAX_LABEL = 18 -- characters; past this the object name is dropped

local TouchAction = {}

function TouchAction.new(): State
	return { shown = {}, holding = nil, holdStartedAt = nil }
end

local function indexOf(state: State, id: any): number?
	for i, entry in state.shown do
		if entry.id == id then
			return i
		end
	end
	return nil
end

function TouchAction.target(state: State): Entry?
	return state.shown[#state.shown]
end

-- Ends the current hold if `id` is no longer the target.
local function cutOff(state: State): any?
	local held = state.holding
	local target = TouchAction.target(state)
	if held ~= nil and (target == nil or target.id ~= held) then
		state.holding, state.holdStartedAt = nil, nil
		return held
	end
	return nil
end

function TouchAction.show(state: State, entry: Entry): any?
	local i = indexOf(state, entry.id)
	if i then
		table.remove(state.shown, i)
	end
	table.insert(state.shown, entry)
	return cutOff(state)
end

function TouchAction.hide(state: State, id: any): any?
	local i = indexOf(state, id)
	if i then
		table.remove(state.shown, i)
	end
	return cutOff(state)
end

function TouchAction.press(state: State, now: number): any?
	local target = TouchAction.target(state)
	if target == nil or state.holding ~= nil then
		return nil
	end
	state.holding, state.holdStartedAt = target.id, now
	return target.id
end

function TouchAction.release(state: State): any?
	local held = state.holding
	state.holding, state.holdStartedAt = nil, nil
	return held
end

function TouchAction.progress(state: State, now: number): number
	local target = TouchAction.target(state)
	local started = state.holdStartedAt
	if target == nil or started == nil or state.holding ~= target.id or target.hold <= 0 then
		return 0
	end
	return math.clamp((now - started) / target.hold, 0, 1)
end

function TouchAction.label(action: string, object: string): string
	local a, o = string.upper(action), string.upper(object)
	local full = if o ~= "" and a ~= "" then `{a} {o}` else a .. o
	if #full <= MAX_LABEL then
		return full
	end
	return if a ~= "" then string.sub(a, 1, MAX_LABEL) else string.sub(o, 1, MAX_LABEL)
end

return table.freeze(TouchAction)
