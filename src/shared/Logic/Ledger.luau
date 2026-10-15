--!strict
--[[
	The train's shared stores: coal, parts and integrity. Pure and immutable.
	Every change to train resources in the game goes through one of these
	functions, which is what makes the economy testable and replayable.
]]

local Shared = script.Parent.Parent
local Difficulty = require(Shared.Config.Difficulty)
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Types = require(Shared.Types)
local Leaks = require(script.Parent.Leaks)

type Train = Types.TrainState

export type Receipt = {
	coal: number,
	coalWasted: number,
	parts: number,
	relicBrass: number,
	relics: number,
}

export type Derived = {
	coalMax: number,
	burnMultiplier: number,
	chaseBonus: number,
	safeBand: number,
	fogDpsMultiplier: number,
	breachMultiplier: number,
	extraSlots: number,
}

local Ledger = {}

local function copy(train: Train): Train
	return {
		coal = train.coal,
		coalMax = train.coalMax,
		parts = train.parts,
		integrity = train.integrity,
		integrityMax = train.integrityMax,
		upgrades = table.clone(train.upgrades),
		breaches = table.clone(train.breaches),
		starving = train.starving,
		chest = table.clone(train.chest),
	}
end

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Ledger.newTrain(): Train
	local t = Tuning.Train
	return {
		coal = t.StartCoal,
		coalMax = t.CoalMax,
		parts = t.StartParts,
		integrity = t.IntegrityMax,
		integrityMax = t.IntegrityMax,
		upgrades = {},
		breaches = {},
		starving = false,
		chest = {},
	}
end

function Ledger.level(train: Train, upgradeId: string): number
	return train.upgrades[upgradeId] or 0
end

function Ledger.derived(train: Train): Derived
	local e = UpgradesConfig.Effects
	return {
		coalMax = Tuning.Train.CoalMax + e.CoalMaxPerLevel * Ledger.level(train, "CoalBunker"),
		burnMultiplier = e.BurnMultiplierPerLevel ^ Ledger.level(train, "FireboxBaffles"),
		chaseBonus = e.ChaseSecondsPerLevel * Ledger.level(train, "SteamWhistle"),
		safeBand = Tuning.World.SafeStrip + e.SafeBandPerLevel * Ledger.level(train, "Floodlamps"),
		fogDpsMultiplier = e.FogDpsMultiplierPerLevel ^ Ledger.level(train, "Floodlamps"),
		breachMultiplier = e.BreachMultiplierPerLevel ^ Ledger.level(train, "ArmorPlating"),
		extraSlots = e.SlotsPerLevel * Ledger.level(train, "PorterSatchels"),
	}
end

-- Coal a leg of `km` kilometres will burn with the current upgrades.
function Ledger.legCoalCost(train: Train, km: number): number
	return round1(km * Tuning.Train.BurnPerKm * Ledger.derived(train).burnMultiplier)
end

function Ledger.deposit(train: Train, cargo: { string }): (Train, Receipt)
	local receipt: Receipt = { coal = 0, coalWasted = 0, parts = 0, relicBrass = 0, relics = 0 }
	local nextTrain = copy(train)
	for _, id in cargo do
		local def = Items[id]
		if def then
			if def.coal then
				local room = math.max(nextTrain.coalMax - nextTrain.coal, 0)
				local added = math.min(def.coal, room)
				nextTrain.coal = round1(nextTrain.coal + added)
				receipt.coal += added
				receipt.coalWasted += def.coal - added
			end
			if def.parts then
				nextTrain.parts += def.parts
				receipt.parts += def.parts
			end
			if def.brass then
				receipt.relicBrass += def.brass
				receipt.relics += 1
			end
		end
	end
	if nextTrain.coal > 0 then
		nextTrain.starving = false
	end
	return nextTrain, receipt
end

function Ledger.spend(train: Train, parts: number): (Train, boolean)
	if parts < 0 or train.parts < parts then
		return train, false
	end
	local nextTrain = copy(train)
	nextTrain.parts -= parts
	return nextTrain, true
end

function Ledger.burn(train: Train, amount: number): Train
	if amount <= 0 then
		return train
	end
	local nextTrain = copy(train)
	nextTrain.coal = round1(math.max(train.coal - amount, 0))
	nextTrain.starving = nextTrain.coal <= 0
	return nextTrain
end

--[[
	Integrity lost over dt seconds of a trip `tripSeconds` long, from open leaks (Logic/Leaks:
	each grows with the travel time it is left open) and an empty firebox. Call it only while
	the train is moving (RunRules.hullDrains). It never takes the hull below Difficulty.Hull.Floor:
	reaching the floor is a breakdown (Services/BreakdownService). Integrity keeps its fraction,
	so slow drains are not lost to rounding.
]]
function Ledger.drain(train: Train, dt: number, tripSeconds: number, leaksHeld: boolean?): Train
	if dt <= 0 or ((leaksHeld or next(train.breaches) == nil) and not train.starving) then
		return train
	end
	local nextTrain = copy(train)
	local loss = 0
	-- held (the grace after a repair, Logic/Breakdown): open leaks neither drain nor worsen
	local open: typeof(train.breaches) = if leaksHeld then {} else train.breaches
	for id, breach in open do
		local age = breach.age or 0
		loss += Leaks.rate(Leaks.severity(age, tripSeconds), tripSeconds) * dt
		nextTrain.breaches[id] = { anchor = breach.anchor, openedAt = breach.openedAt, age = age + dt }
	end
	if train.starving then
		loss += Difficulty.Hull.StarvingPerSecond * dt
	end
	local floor = math.min(train.integrity, Difficulty.Hull.Floor)
	nextTrain.integrity = math.max(train.integrity - loss, floor)
	return nextTrain
end

-- True once the hull has drained to its floor (a breakdown).
function Ledger.atFloor(train: Train): boolean
	return train.integrity <= Difficulty.Hull.Floor + 1e-6
end

function Ledger.upgradeCost(train: Train, upgradeId: string): number?
	local def = UpgradesConfig.List[upgradeId]
	if def == nil then
		return nil
	end
	return def.costs[Ledger.level(train, upgradeId) + 1]
end

export type FailReason = "Unknown" | "Maxed" | "Parts" | "Full"

function Ledger.buyUpgrade(train: Train, upgradeId: string): (Train, boolean, FailReason?)
	if UpgradesConfig.List[upgradeId] == nil then
		return train, false, "Unknown"
	end
	local cost = Ledger.upgradeCost(train, upgradeId)
	if cost == nil then
		return train, false, "Maxed"
	end
	if train.parts < cost then
		return train, false, "Parts"
	end
	local nextTrain = copy(train)
	nextTrain.parts -= cost
	nextTrain.upgrades[upgradeId] = Ledger.level(train, upgradeId) + 1
	nextTrain.coalMax = Ledger.derived(nextTrain).coalMax
	return nextTrain, true, nil
end

-- Workbench "Repair hull": RepairParts parts for RepairAmount hull (Difficulty.Hull), up to the max.
function Ledger.repairHull(train: Train): (Train, boolean, FailReason?)
	local hull = Difficulty.Hull
	if train.integrity >= train.integrityMax then
		return train, false, "Full"
	end
	if train.parts < hull.RepairParts then
		return train, false, "Parts"
	end
	local nextTrain = copy(train)
	nextTrain.parts -= hull.RepairParts
	nextTrain.integrity = math.min(train.integrity + hull.RepairAmount, train.integrityMax)
	return nextTrain, true, nil
end

function Ledger.openBreach(train: Train, id: string, anchor: string, now: number): Train
	local nextTrain = copy(train)
	nextTrain.breaches[id] = { anchor = anchor, openedAt = now, age = 0 }
	return nextTrain
end

function Ledger.patchBreach(train: Train, id: string): (Train, boolean, FailReason?)
	if train.breaches[id] == nil then
		return train, false, "Unknown"
	end
	if train.parts < Difficulty.Leaks.PatchParts then
		return train, false, "Parts"
	end
	local nextTrain = copy(train)
	nextTrain.parts -= Difficulty.Leaks.PatchParts
	nextTrain.breaches[id] = nil
	return nextTrain, true, nil
end

function Ledger.breachCount(train: Train): number
	local count = 0
	for _ in train.breaches do
		count += 1
	end
	return count
end

return table.freeze(Ledger)
