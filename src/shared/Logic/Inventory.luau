--!strict
--[[
	Backpack rules. Pure and immutable: every operation returns a new state.

	Capacity is counted in slot units. A heavy item uses 2 units and multiplies
	move speed by HeavySpeedMultiplier (stacking). Tools stay packed when cargo
	is deposited on the train.
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local Types = require(Shared.Types)

type State = Types.InventoryState

local Inventory = {}

function Inventory.new(capacity: number?): State
	return { items = {}, capacity = capacity or Tuning.Crew.BackpackSlots }
end

function Inventory.used(inv: State): number
	local used = 0
	for _, id in inv.items do
		local def = Items[id]
		used += if def then def.slots else 1
	end
	return used
end

function Inventory.free(inv: State): number
	return inv.capacity - Inventory.used(inv)
end

function Inventory.canAdd(inv: State, itemId: string): boolean
	local def = Items[itemId]
	return def ~= nil and Inventory.free(inv) >= def.slots
end

function Inventory.add(inv: State, itemId: string): (State, boolean)
	if not Inventory.canAdd(inv, itemId) then
		return inv, false
	end
	local items = table.clone(inv.items)
	table.insert(items, itemId)
	return { items = items, capacity = inv.capacity }, true
end

-- Adds as many items as fit, in order. Returns the new state and the items that did not fit.
function Inventory.addMany(inv: State, itemIds: { string }): (State, { string })
	local state = inv
	local leftovers: { string } = {}
	for _, id in itemIds do
		local ok
		state, ok = Inventory.add(state, id)
		if not ok then
			table.insert(leftovers, id)
		end
	end
	return state, leftovers
end

function Inventory.removeAt(inv: State, index: number): (State, string?)
	local id = inv.items[index]
	if id == nil then
		return inv, nil
	end
	local items = table.clone(inv.items)
	table.remove(items, index)
	return { items = items, capacity = inv.capacity }, id
end

function Inventory.indexOf(inv: State, itemId: string): number?
	return table.find(inv.items, itemId)
end

function Inventory.heavyCount(inv: State): number
	local count = 0
	for _, id in inv.items do
		local def = Items[id]
		if def and def.heavy then
			count += 1
		end
	end
	return count
end

function Inventory.speedMultiplier(inv: State): number
	return Tuning.Crew.HeavySpeedMultiplier ^ Inventory.heavyCount(inv)
end

function Inventory.jumpHeight(inv: State): number
	return if Inventory.heavyCount(inv) > 0 then Tuning.Crew.HeavyJumpHeight else Tuning.Crew.JumpHeight
end

-- Splits cargo and relics (deposited) from tools (kept).
function Inventory.splitCargo(inv: State): (State, { string })
	local kept: { string } = {}
	local cargo: { string } = {}
	for _, id in inv.items do
		local def = Items[id]
		if def and def.kind == "Tool" then
			table.insert(kept, id)
		else
			table.insert(cargo, id)
		end
	end
	return { items = kept, capacity = inv.capacity }, cargo
end

function Inventory.hasCargo(inv: State): boolean
	for _, id in inv.items do
		local def = Items[id]
		if def and def.kind ~= "Tool" then
			return true
		end
	end
	return false
end

function Inventory.withCapacity(inv: State, capacity: number): State
	return { items = table.clone(inv.items), capacity = capacity }
end

-- The hand. A tool's slot key puts it in the hand (the same key again puts it away) and E
-- uses it. These take and return the slot in hand (nil is an empty hand).

local function isTool(inv: State, slot: number?): boolean
	local id = if slot then inv.items[slot] else nil
	local def = if id then Items[id] else nil
	return def ~= nil and def.kind == "Tool"
end

-- The slot in hand after pressing `slot`'s key. Keys of slots without a tool change nothing.
function Inventory.select(inv: State, held: number?, slot: number): number?
	if not isTool(inv, slot) then
		return held
	end
	return if held == slot then nil else slot
end

-- The slot in hand after the backpack changed: it follows the item if it moved and
-- empties if the item left.
function Inventory.follow(inv: State, held: number?, heldId: string?): number?
	if held == nil or heldId == nil then
		return nil
	end
	if inv.items[held] == heldId then
		return held
	end
	return table.find(inv.items, heldId)
end

-- Whether E uses what is in hand: never while an interact prompt (Pick up, Pull free)
-- is showing, so E keeps meaning that prompt.
function Inventory.canUseHand(inv: State, held: number?, promptShowing: boolean): boolean
	return not promptShowing and isTool(inv, held)
end

return table.freeze(Inventory)
