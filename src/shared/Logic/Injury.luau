--!strict
--[[
	A crew member's missing arms for the run (Config/Injury). Pure and immutable: every
	operation returns a new state, so the server (Services/InjuryService, the only judge) and
	the specs agree.

	  tear      one arm comes away (only from a successful crew rescue, Logic/Rescue)
	  restore   a Tonic brings back the arm lost last (right before left on a tie)
	  board     safe aboard with no arms: the return deadline is cleared (no free arm)
	  leave     stepping off the train with no arms starts a fresh deadline
	  expired   the deadline passed: strictly after it, so a heal or boarding at the very
	            instant of the deadline wins

	Capacity is always worked out from the current uninjured capacity (upgrades included),
	never by subtracting again on each event.
]]

local Config = require(script.Parent.Parent.Config.Injury)

export type Arm = "L" | "R"

export type State = {
	lost: { Arm }, -- the arms missing, in the order they were lost
	returnBy: number?, -- server time the armless crew member must be safe aboard by
}

local Injury = {}

function Injury.new(): State
	return { lost = {}, returnBy = nil }
end

function Injury.missing(state: State, arm: Arm): boolean
	return table.find(state.lost, arm) ~= nil
end

function Injury.count(state: State): number
	return #state.lost
end

function Injury.armless(state: State): boolean
	return #state.lost >= 2
end

-- "", "L", "R" or "LR": the character attribute every client reads (MissingArms).
function Injury.attribute(state: State): string
	local left = if Injury.missing(state, "L") then "L" else ""
	local right = if Injury.missing(state, "R") then "R" else ""
	return left .. right
end

function Injury.fromAttribute(value: any): State
	local lost: { Arm } = {}
	if type(value) == "string" then
		if string.find(value, "L", 1, true) then
			table.insert(lost, "L")
		end
		if string.find(value, "R", 1, true) then
			table.insert(lost, "R")
		end
	end
	return { lost = lost, returnBy = nil }
end

--[[
	The arm a final hold takes, from the side the Hollow is on in the victim's own frame
	(`localX` > 0: on their right). Never one already gone; nil when both are.
]]
function Injury.targetArm(state: State, localX: number): Arm?
	local first: Arm = if localX > 0 then "R" else "L"
	local other: Arm = if first == "R" then "L" else "R"
	if not Injury.missing(state, first) then
		return first
	elseif not Injury.missing(state, other) then
		return other
	end
	return nil
end

-- One arm comes away at server time `now`. A second loss off the train starts the deadline.
function Injury.tear(state: State, arm: Arm, now: number, aboard: boolean): State
	if Injury.missing(state, arm) then
		return state
	end
	local lost = table.clone(state.lost)
	table.insert(lost, arm)
	local returnBy = state.returnBy
	if #lost >= 2 and not aboard then
		returnBy = now + Config.ReturnSeconds
	end
	return { lost = lost, returnBy = returnBy }
end

-- The arm a Tonic brings back: the last lost.
function Injury.nextRestore(state: State): Arm?
	return state.lost[#state.lost]
end

-- One arm comes back. Restoring before the deadline clears it.
function Injury.restore(state: State): State
	if #state.lost == 0 then
		return state
	end
	local lost = table.clone(state.lost)
	table.remove(lost)
	return { lost = lost, returnBy = nil }
end

-- Safe aboard: the deadline is cleared. Arms stay missing.
function Injury.board(state: State): State
	if state.returnBy == nil then
		return state
	end
	return { lost = table.clone(state.lost), returnBy = nil }
end

-- Off the train with no arms: a fresh deadline (an old one is never kept).
function Injury.leave(state: State, now: number): State
	if not Injury.armless(state) or state.returnBy ~= nil then
		return state
	end
	return { lost = table.clone(state.lost), returnBy = now + Config.ReturnSeconds }
end

function Injury.expired(state: State, now: number): boolean
	return state.returnBy ~= nil and now > (state.returnBy :: number)
end

-- Ordinary carrying capacity in slot units, from the uninjured capacity `base`.
function Injury.capacity(base: number, state: State): number
	local n = #state.lost
	if n >= 2 then
		return 0
	elseif n == 1 then
		return math.max(0, base - Config.OneArmPenalty)
	end
	return base
end

-- Whether ordinary item use (combat, tools, self-heal) is possible: not with no arms.
function Injury.canUseItems(state: State): boolean
	return not Injury.armless(state)
end

return table.freeze(Injury)
