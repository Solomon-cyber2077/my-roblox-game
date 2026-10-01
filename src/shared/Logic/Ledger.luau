--!strict
--[[
	The train's shared stores: coal, parts and integrity. Pure and immutable.
	Every change to train resources in the game goes through one of these
	functions, which is what makes the economy testable and replayable.
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Types = require(Shared.Types)

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

-- Integrity loss over dt seconds from open breaches and an empty firebox.
function Ledger.drain(train: Train, dt: number): Train
	local breaches = 0
	for _ in train.breaches do
		breaches += 1
	end
	local rate = breaches * Tuning.Train.BreachDrainPerSecond
	if train.starving then
		rate += Tuning.Train.StarvingDrainPerSecond
	end
	if rate <= 0 then
		return train
	end
	local nextTrain = copy(train)
	nextTrain.integrity = round1(math.max(train.integrity - rate * dt, 0))
	return nextTrain
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

function Ledger.hullPatch(train: Train): (Train, boolean, FailReason?)
	if train.integrity >= train.integrityMax then
		return train, false, "Full"
	end
	if train.parts < Tuning.Train.HullPatchCost then
		return train, false, "Parts"
	end
	local nextTrain = copy(train)
	nextTrain.parts -= Tuning.Train.HullPatchCost
	nextTrain.integrity = math.min(train.integrity + Tuning.Train.HullPatchAmount, train.integrityMax)
	return nextTrain, true, nil
end

function Ledger.openBreach(train: Train, id: string, anchor: string, now: number): Train
	local nextTrain = copy(train)
	nextTrain.breaches[id] = { anchor = anchor, openedAt = now }
	return nextTrain
end

function Ledger.patchBreach(train: Train, id: string): (Train, boolean, FailReason?)
	if train.breaches[id] == nil then
		return train, false, "Unknown"
	end
	if train.parts < Tuning.Train.BreachPatchCost then
		return train, false, "Parts"
	end
	local nextTrain = copy(train)
	nextTrain.parts -= Tuning.Train.BreachPatchCost
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
