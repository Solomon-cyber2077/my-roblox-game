--!strict
--[[
	Station difficulty and every hazard parameter derived from it.

	D for stop n of N with danger tier t:
		R(n) = Start + Span * ((n - 1) / (N - 1)) ^ Exponent
		D    = clamp(R(n) + TierOffset[t], 0, 1)

	Each hazard parameter is a linear blend of its { atD0, atD1 } pair from
	Config/Difficulty, then scaled by the archetype's hazard biases and by the
	crew's train upgrades. Stops with big enterable buildings stay open longer and
	draw more Hollows, in proportion to the building tiles they hold.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Stations = require(Shared.Config.Stations)
local MathX = require(Shared.Util.MathX)
local Types = require(Shared.Types)
local BuildingGen = require(script.Parent.BuildingGen)

type Archetype = Stations.Archetype

local DifficultyModel = {}

local function blend(pair: { number }, d: number): number
	return MathX.lerp(pair[1], pair[2], d)
end

function DifficultyModel.base(stop: number, stopCount: number): number
	local curve = Difficulty.Base
	local t = if stopCount <= 1 then 0 else MathX.saturate((stop - 1) / (stopCount - 1))
	return curve.Start + curve.Span * t ^ curve.Exponent
end

function DifficultyModel.forStop(stop: number, stopCount: number, tier: number): number
	local offset = Difficulty.TierOffset[MathX.clamp(tier, 1, 3)]
	return MathX.saturate(DifficultyModel.base(stop, stopCount) + offset)
end

function DifficultyModel.hollowCap(d: number, crewCount: number, hollowBias: number): number
	if hollowBias <= 0 then
		return 0
	end
	local cap = Difficulty.HollowCap
	local raw = (cap.Base + cap.PerDifficulty * d + cap.PerExtraCrew * math.max(crewCount - 1, 0))
		* hollowBias
	return math.min(cap.Max, math.ceil(raw - 1e-9))
end

function DifficultyModel.params(
	d: number,
	archetype: Archetype,
	crewCount: number,
	upgrades: { [string]: number }?
): Types.HazardParams
	local levels: { [string]: number } = upgrades or {}
	local effects = UpgradesConfig.Effects
	local bias = archetype.hazard
	local flood = levels.Floodlamps or 0
	local whistle = levels.SteamWhistle or 0
	local armour = levels.ArmorPlating or 0

	local fogBias = math.max(bias.fog, 0.01)
	local collapseBias = math.max(bias.collapse, 0.01)
	local hollowBias = math.max(bias.hollows, 0.01)
	local tiles = BuildingGen.tiles(archetype.landmarks)
	local sizeDwell = 1 + Difficulty.SizeDwellPerTile * tiles
	local sizeCap = 1 + Difficulty.SizeCapPerTile * tiles

	return {
		difficulty = d,
		dwell = math.floor(blend(Difficulty.Dwell, d) * archetype.dwellMultiplier * sizeDwell + 0.5),
		lastCall = Tuning.Run.LastCallSeconds,
		fogStartU = MathX.clamp(blend(Difficulty.FogStartU, d) / fogBias, 0.08, 0.9),
		fogEndFraction = MathX.clamp(blend(Difficulty.FogEndFraction, d) / fogBias, 0.05, 1),
		fogGamma = blend(Difficulty.FogGamma, d),
		fogDps = blend(Difficulty.FogDps, d)
			* math.max(bias.fog, 0)
			* effects.FogDpsMultiplierPerLevel ^ flood,
		collapseLag = blend(Difficulty.CollapseLag, d) / collapseBias,
		collapseWarn = blend(Difficulty.CollapseWarn, d),
		collapseJitter = Difficulty.CollapseJitter,
		spawnInterval = blend(Difficulty.SpawnInterval, d) / hollowBias / sizeCap,
		spawnRamp = Difficulty.SpawnRamp,
		firstSpawnU = blend(Difficulty.FirstSpawnU, d),
		hollowCap = DifficultyModel.hollowCap(d, crewCount, bias.hollows * sizeCap),
		hollowWalk = blend(Difficulty.HollowWalk, d),
		hollowChase = blend(Difficulty.HollowChase, d),
		hollowDamage = math.floor(blend(Difficulty.HollowDamage, d) + 0.5),
		departureAccel = blend(Difficulty.DepartureAccel, d),
		chaseWindow = blend(Difficulty.ChaseWindow, d) + effects.ChaseSecondsPerLevel * whistle,
		lootMul = blend(Difficulty.LootMultiplier, d),
		breachRate = blend(Difficulty.BreachRate, d) * effects.BreachMultiplierPerLevel ^ armour,
		safeBand = Tuning.World.SafeStrip + effects.SafeBandPerLevel * flood,
	}
end

-- Breaches per second while travelling toward a stop of difficulty d.
function DifficultyModel.breachRate(d: number, upgrades: { [string]: number }?): number
	local levels: { [string]: number } = upgrades or {}
	local armour = levels.ArmorPlating or 0
	return blend(Difficulty.BreachRate, d) * UpgradesConfig.Effects.BreachMultiplierPerLevel ^ armour
end

-- Seconds of cruising for a leg of `km` kilometres.
function DifficultyModel.cruiseSeconds(km: number): number
	return Tuning.Run.CruiseBaseSeconds + Tuning.Run.CruiseSecondsPerKm * km
end

return table.freeze(DifficultyModel)
