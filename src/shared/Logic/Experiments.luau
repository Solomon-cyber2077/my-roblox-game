--!strict
--[[
	Crew-randomized experiments (Config/Experiments, docs/FINAL-DESIGN.md A.4). Pure.

	  arm(runSeed, def)        the crew's arm: drawn from Rng(hash(runSeed, salt)), the same for the whole
	                           crew and on every server that asks
	  pick(runSeed, def, ...)  the arm a run uses: a Studio override, else the hashed arm when the
	                           experiment is on and the crew has an eligible player, else nil (off)
	  label(def, arm)          the arm's Telemetry name (A, B)
	  expose(cohorts, def, arm) a player's stored arm: set once, never changed. Returns whether this
	                           exposure is the player's first (log cohort_assigned then)
]]

local Shared = script.Parent.Parent
local Config = require(Shared.Config.Experiments)
local Rng = require(Shared.Util.Rng)

export type Def = Config.Def

local Experiments = {}

function Experiments.arm(runSeed: number, def: Def): string
	-- drawn from the seeded stream, not the hash's low bits (those barely differ between salts)
	local rng = Rng.new(Rng.derive(runSeed, "experiment", def.salt))
	return def.arms[rng:int(1, #def.arms)]
end

function Experiments.pick(runSeed: number, def: Def, anyEligible: boolean, override: string?): string?
	if override ~= nil and table.find(def.arms, override) then
		return override
	end
	if not def.enabled or not anyEligible then
		return nil
	end
	return Experiments.arm(runSeed, def)
end

function Experiments.label(def: Def, arm: string): string
	local index = table.find(def.arms, arm)
	return Config.ArmNames[index or 1]
end

function Experiments.expose(cohorts: { [string]: string }, def: Def, arm: string): boolean
	if cohorts[def.id] ~= nil then
		return false
	end
	cohorts[def.id] = arm
	return true
end

return table.freeze(Experiments)
