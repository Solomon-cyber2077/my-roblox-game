--!strict
--[[
	The crew chest in the stores car (Services/TrainService, UI/CrewChest): consumables the whole
	crew shares, stowed from a backpack and taken back with E. Pure.

	Consumables are tools with a use (Flare, Tonic, Flashbulb): never cargo, relics or an
	errand's keepsake. The chest holds Tuning.CrewChest.Capacity of them and empties with the
	train at a new run (it lives in the train's state, Logic/Ledger).
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(script.Parent.Inventory)
local Types = require(Shared.Types)

type InventoryState = Types.InventoryState

local CrewChest = {}

CrewChest.Capacity = Tuning.CrewChest.Capacity

function CrewChest.storable(itemId: string?): boolean
	local def = if itemId then Items[itemId] else nil
	return def ~= nil and def.kind == "Tool" and def.use ~= nil
end

-- Moves the item in backpack `slot` into the chest. On failure returns the reason and the
-- inputs unchanged: "Empty" (no item there), "NotStorable", "Full".
function CrewChest.stow(
	chest: { string },
	inv: InventoryState,
	slot: number
): ({ string }, InventoryState, string?)
	local itemId = inv.items[slot]
	if itemId == nil then
		return chest, inv, "Empty"
	elseif not CrewChest.storable(itemId) then
		return chest, inv, "NotStorable"
	elseif #chest >= CrewChest.Capacity then
		return chest, inv, "Full"
	end
	local nextInv = Inventory.removeAt(inv, slot)
	local nextChest = table.clone(chest)
	table.insert(nextChest, itemId)
	return nextChest, nextInv, nil
end

-- Moves one `itemId` from the chest into the backpack: "Missing" or "NoRoom" when it cannot.
function CrewChest.take(
	chest: { string },
	inv: InventoryState,
	itemId: string
): ({ string }, InventoryState, string?)
	local index = table.find(chest, itemId)
	if index == nil then
		return chest, inv, "Missing"
	end
	local nextInv, added = Inventory.add(inv, itemId)
	if not added then
		return chest, inv, "NoRoom"
	end
	local nextChest = table.clone(chest)
	table.remove(nextChest, index)
	return nextChest, nextInv, nil
end

-- How many of each item the chest holds, and the ids in a stable order (by item name).
function CrewChest.counts(chest: { string }): ({ [string]: number }, { string })
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, itemId in chest do
		if counts[itemId] == nil then
			counts[itemId] = 0
			table.insert(order, itemId)
		end
		counts[itemId] += 1
	end
	table.sort(order, function(a, b)
		return (Items[a] and Items[a].name or a) < (Items[b] and Items[b].name or b)
	end)
	return counts, order
end

return table.freeze(CrewChest)
