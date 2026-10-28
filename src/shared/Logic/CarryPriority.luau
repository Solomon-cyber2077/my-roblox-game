--!strict
--[[
	Which carried items stay when capacity shrinks (an arm lost). Pure, so the server
	(Services/InventoryService) and the specs agree, and the hotbar can show the same
	prediction.

	The backpack's order is the priority: leftmost entries are kept first. When the items no
	longer fit, whole entries are dropped from the right until the rest fit, counting each
	item's slot cost (Logic/Inventory). Protected items (Config/Items `protected`, objectives)
	are never dropped; they ride in their own channel and do not count against capacity.

	Players change the order with `reorder`, which the server accepts only for a true
	permutation of their current backpack at the revision they saw.
]]

local Shared = script.Parent.Parent
local Items = require(Shared.Config.Items)

local CarryPriority = {}

function CarryPriority.protected(itemId: string): boolean
	local def = Items[itemId] :: any
	return def ~= nil and def.protected == true
end

local function cost(itemId: string): number
	local def = Items[itemId]
	return if def then def.slots else 1
end

-- Ordinary slot units used (protected items excluded).
function CarryPriority.used(items: { string }): number
	local used = 0
	for _, id in items do
		if not CarryPriority.protected(id) then
			used += cost(id)
		end
	end
	return used
end

--[[
	Splits `items` (in priority order) into those kept under `capacity` and those dropped,
	dropping whole rightmost entries first. Returns (kept, dropped) in their original order.
]]
function CarryPriority.overflow(items: { string }, capacity: number): ({ string }, { string })
	local keep = table.create(#items, true) :: { boolean }
	local used = CarryPriority.used(items)
	for i = #items, 1, -1 do
		if used <= capacity then
			break
		end
		local id = items[i]
		if not CarryPriority.protected(id) then
			keep[i] = false
			used -= cost(id)
		end
	end
	local kept: { string } = {}
	local dropped: { string } = {}
	for i, id in items do
		table.insert(if keep[i] then kept else dropped, id)
	end
	return kept, dropped
end

--[[
	Validates a reorder request: `order` lists 1-based indices of `items` in their new order.
	Accepted only when `revision` matches the backpack the server holds and `order` is a
	permutation of every index (so duplicates of one item cannot be invented or lost).
	Returns the new list, or nil and the reason.
]]
function CarryPriority.reorder(
	items: { string },
	currentRevision: number,
	order: any,
	revision: any
): ({ string }?, string?)
	if revision ~= currentRevision then
		return nil, "Stale"
	end
	if type(order) ~= "table" or #order ~= #items then
		return nil, "Shape"
	end
	local seen: { [number]: boolean } = {}
	local result: { string } = {}
	for i = 1, #items do
		local index = order[i]
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > #items or seen[index] then
			return nil, "Permutation"
		end
		seen[index] = true
		result[i] = items[index]
	end
	for key in order do
		if type(key) ~= "number" or key < 1 or key > #items or key % 1 ~= 0 then
			return nil, "Shape"
		end
	end
	return result, nil
end

return table.freeze(CarryPriority)
