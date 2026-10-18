--!strict

local Shared = script.Parent.Parent
local Haul = require(Shared.Config.Haul)

export type State = {
	initial: number,
	nearest: number,
	duo: number,
	carriers: { number },
	byCarrier: { [number]: number },
	delivered: boolean,
}

local Payroll = {}

local function hasCarrier(state: State, id: number): boolean
	for _, carrier in state.carriers do
		if carrier == id then
			return true
		end
	end
	return false
end

function Payroll.new(distance: number): State
	local initial = math.max(distance, 0)
	return {
		initial = initial,
		nearest = initial,
		duo = 0,
		carriers = {},
		byCarrier = {},
		delivered = false,
	}
end

function Payroll.join(state: State, id: number): boolean
	if state.delivered or hasCarrier(state, id) or #state.carriers >= 2 then
		return false
	end
	table.insert(state.carriers, id)
	if state.byCarrier[id] == nil then
		state.byCarrier[id] = 0
	end
	return true
end

function Payroll.leave(state: State, id: number): boolean
	for index, carrier in state.carriers do
		if carrier == id then
			table.remove(state.carriers, index)
			return true
		end
	end
	return false
end

function Payroll.sample(state: State, distance: number): number
	if state.delivered then
		return 0
	end
	local current = math.max(distance, 0)
	local delta = math.max(state.nearest - current, 0)
	state.nearest = math.min(state.nearest, current)
	if delta <= 0 then
		return 0
	end
	local count = #state.carriers
	if count == 0 then
		return 0
	end
	if count == 2 then
		state.duo += delta
		for _, id in state.carriers do
			state.byCarrier[id] = (state.byCarrier[id] or 0) + delta
		end
	end
	return delta
end

function Payroll.eligible(state: State): boolean
	return state.initial > 0 and state.duo / state.initial >= Haul.DoubleFraction
end

function Payroll.deliver(state: State): boolean
	if state.delivered then
		return false
	end
	local doubled = Payroll.eligible(state)
	state.delivered = true
	table.clear(state.carriers)
	return doubled
end

return Payroll
