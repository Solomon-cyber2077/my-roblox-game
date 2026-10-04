--!strict
--[[
	The rules of a grab (Config/Grabs), pure so the server and the specs agree.

	A hold's escape runs from 0 to Tuning.Grab.Escape:
	  press   the victim's struggle key adds the stop's grabMash, divided by the kind's grip
	  pry     a crewmate tearing at the Hollow adds AllyPresses times as much
	  slip    it slides back at grabSlip per second
	Damage comes in bites on the grab's rhythm, the first one bite after the snatch has
	settled, each worth dps * bite, where dps = hollowDamage * DpsShare * the kind's crush.

	Escape time for a victim pressing r times a second: Escape / (r * grabMash / grip - grabSlip).
]]

local Shared = script.Parent.Parent
local Grabs = require(Shared.Config.Grabs)
local Tuning = require(Shared.Config.Tuning)
local Rng = require(Shared.Util.Rng)
local Types = require(Shared.Types)

type Params = Types.HazardParams

export type Kind = { grip: number, crush: number }

local G = Tuning.Grab

local Grab = {}

function Grab.kind(name: string): Kind
	local def = (Tuning.HollowKinds :: any)[name]
	return if def then def else Tuning.HollowKinds.Stalker
end

-- Escape after one press of the victim's own struggle key.
function Grab.press(escape: number, params: Params, kind: Kind): number
	return escape + params.grabMash / kind.grip
end

-- Escape after a crewmate tears at the Hollow once.
function Grab.pry(escape: number, params: Params, kind: Kind): number
	return escape + params.grabMash * G.AllyPresses / kind.grip
end

-- Escape after `dt` seconds of the Hollow tightening its hold.
function Grab.slip(escape: number, params: Params, dt: number): number
	return math.max(escape - params.grabSlip * math.max(dt, 0), 0)
end

function Grab.free(escape: number): boolean
	return escape >= G.Escape - 1e-9
end

function Grab.dps(params: Params, kind: Kind): number
	return params.hollowDamage * G.DpsShare * kind.crush
end

-- How many bites land between `from` and `to` seconds into the hold (from < t <= to).
function Grab.bitesBetween(def: Grabs.Def, from: number, to: number): number
	local function count(t: number): number
		if t < G.Settle then
			return 0
		end
		return math.floor((t - G.Settle) / def.bite + 1e-9)
	end
	return math.max(count(to) - count(from), 0)
end

-- Damage of the bites that land between `from` and `to` seconds into the hold.
function Grab.damage(def: Grabs.Def, params: Params, kind: Kind, from: number, to: number): number
	return Grab.bitesBetween(def, from, to) * Grab.dps(params, kind) * def.bite
end

--[[
	The rhythm of a hold, for the bodies that act it out (the client's Animation modules):
	1 the instant a bite lands, easing off, then tensing again before the next one.
]]
function Grab.squeeze(def: Grabs.Def, t: number): number
	if t < G.Settle then
		return 0
	end
	local u = ((t - G.Settle) % def.bite) / def.bite
	local tense = math.clamp((u - 0.8) / 0.2, 0, 1)
	return math.max(math.exp(-u * 7), tense * tense * (3 - 2 * tense) * 0.55)
end

-- The kind's grabs in the order this Hollow tries them: each one has a favourite.
function Grab.order(kindName: string, seed: number): { Grabs.Def }
	local list = table.clone(Grabs.Kinds[kindName] or Grabs.Kinds.Stalker)
	return Rng.new(Rng.derive(seed, "grab")):shuffle(list)
end

-- Seconds a victim pressing `rate` times a second needs to break free alone (math.huge if never).
function Grab.escapeSeconds(params: Params, kind: Kind, rate: number): number
	local net = rate * params.grabMash / kind.grip - params.grabSlip
	if net <= 0 then
		return math.huge
	end
	return G.Escape / net
end

return table.freeze(Grab)
