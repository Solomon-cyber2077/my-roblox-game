--!strict
--[[
	Backpacks. Holds each crew member's Inventory state, applies the pure rules
	in Logic/Inventory, deposits cargo into the train, and runs tool use.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CarryPriority = require(Shared.Logic.CarryPriority)
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(Shared.Logic.Inventory)
local RunRules = require(Shared.Logic.RunRules)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

type InventoryState = Types.InventoryState

local InventoryService = {}

local inventories: { [Player]: InventoryState } = {}
-- Items an arm's loss pushed out that could not be put down safely (no floor there): kept here,
-- never deleted, and handed back or set down as soon as there is room (Refit).
local held: { [Player]: { string } } = {}

local function set(player: Player, inv: InventoryState)
	local previous = inventories[player]
	local stamped = table.clone(inv)
	-- the hotbar's reorder requests name the revision they saw (CarryPriority.reorder)
	stamped.revision = (if previous then previous.revision or 0 else 0) + 1
	inv = stamped
	inventories[player] = inv
	StateService.SetPrivate(player, { "inventory" }, inv)
	Registry.CrewService.SetLoad(player, Inventory.used(inv))
end

function InventoryService.Init() end

function InventoryService.Start()
	NetService.Handle("UseItem", function(player, slot: number)
		InventoryService.Use(player, slot)
	end, function(player)
		return Registry.CrewService.IsAlive(player)
	end)
	NetService.Handle("DropItem", function(player, slot: number)
		InventoryService.Drop(player, slot)
	end, function(player)
		return Registry.CrewService.IsAlive(player)
	end)
	-- the player's new priority order for their backpack (leftmost kept first); feature flag only
	NetService.Handle("ReorderItems", function(player, order: { number }, revision: number)
		if not Registry.InjuryService.Enabled() then
			return
		end
		local inv = InventoryService.Get(player)
		local items, why = CarryPriority.reorder(inv.items, inv.revision or 0, order, revision)
		if items == nil then
			if why == "Stale" then
				-- the backpack changed under them: resend it so the hotbar catches up
				StateService.SetPrivate(player, { "inventory" }, inv)
			end
			return
		end
		set(player, { items = items, capacity = inv.capacity })
	end, function(player)
		return Registry.CrewService.IsAlive(player) and not Registry.HollowService.IsHeld(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
		held[player] = nil
	end)
end

-- Replaces a backpack outright (the crew chest's stow and take, Services/TrainService).
function InventoryService.Set(player: Player, inv: InventoryState)
	set(player, inv)
end

function InventoryService.Get(player: Player): InventoryState
	return inventories[player] or Inventory.new()
end

function InventoryService.Capacity(): number
	return Tuning.Crew.BackpackSlots + Registry.TrainService.Derived().extraSlots
end

-- This player's ordinary capacity: the train's, less what their missing arms cost (InjuryService).
function InventoryService.CapacityFor(player: Player): number
	return Registry.InjuryService.Capacity(player, InventoryService.Capacity())
end

function InventoryService.Reset(player: Player)
	held[player] = nil
	set(player, Inventory.new(InventoryService.CapacityFor(player)))
end

function InventoryService.Clear(player: Player)
	held[player] = nil
	set(player, Inventory.new(InventoryService.CapacityFor(player)))
end

--[[
	Fits the backpack to the player's current capacity. When it shrank below what they carry,
	whole rightmost entries are dropped first (CarryPriority.overflow) where they stand, with a
	receipt. An item that cannot be put down safely is held for them (`held`) rather than lost,
	and comes back as soon as there is room.
]]
function InventoryService.Refit(player: Player)
	local inv = InventoryService.Get(player)
	local capacity = InventoryService.CapacityFor(player)
	local kept, dropped = CarryPriority.overflow(inv.items, capacity)
	local waiting = held[player]
	if #dropped == 0 and waiting == nil and inv.capacity == capacity then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local placed: { string } = {}
	local keep: { string } = {}
	for i, itemId in dropped do
		local angle = i * 2.4
		local spot = if root
			then root.Position + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3)
			else nil
		if spot and Registry.LootService.DropAt(itemId, spot) then
			table.insert(placed, itemId)
		else
			table.insert(keep, itemId)
		end
	end
	local nextInv: InventoryState = { items = kept, capacity = capacity }
	-- held items come back first while there is room
	if waiting then
		local leftovers
		nextInv, leftovers = Inventory.addMany(nextInv, waiting)
		for _, itemId in leftovers do
			table.insert(keep, itemId)
		end
	end
	if #keep > 0 then
		held[player] = keep
	else
		held[player] = nil
	end
	set(player, nextInv)
	if #placed > 0 then
		local names: { string } = {}
		for _, itemId in placed do
			local def = Items[itemId]
			table.insert(names, if def then def.name else itemId)
		end
		NetService.Fire("Notify", player, "Warning", `Dropped where you stand: {table.concat(names, ", ")}.`)
		NetService.Fire("Fx", player, "DropReceipt", { items = placed })
	end
	if #keep > 0 and #dropped > 0 then
		NetService.Fire(
			"Notify",
			player,
			"Info",
			"Some things could not be set down here; you will get them back."
		)
	end
end

function InventoryService.RefreshCapacity()
	for player in inventories do
		InventoryService.Refit(player)
	end
end

-- Adds items; returns the ones that did not fit.
function InventoryService.Give(player: Player, items: { string }): { string }
	local inv, leftovers = Inventory.addMany(InventoryService.Get(player), items)
	if #leftovers < #items then
		set(player, inv)
	end
	return leftovers
end

function InventoryService.Has(player: Player, itemId: string): boolean
	return Inventory.indexOf(InventoryService.Get(player), itemId) ~= nil
end

function InventoryService.Consume(player: Player, itemId: string): boolean
	local inv = InventoryService.Get(player)
	local index = Inventory.indexOf(inv, itemId)
	if index == nil then
		return false
	end
	local nextInv = Inventory.removeAt(inv, index)
	set(player, nextInv)
	return true
end

-- Moves all cargo and relics into the train. Called while the player is aboard.
function InventoryService.DepositCargo(player: Player)
	local inv = InventoryService.Get(player)
	if not Inventory.hasCargo(inv) then
		return
	end
	local kept, cargo = Inventory.splitCargo(inv)
	set(player, kept)
	local receipt = Registry.TrainService.Deposit(cargo)
	Registry.CrewService.RecordDeposit(player, receipt)
	NetService.Fire("Fx", player, "Deposit", receipt)
	local parts: { string } = {}
	if receipt.coal > 0 then
		table.insert(parts, `{receipt.coal} coal`)
	end
	if receipt.parts > 0 then
		table.insert(parts, `{receipt.parts} parts`)
	end
	if receipt.relics > 0 then
		table.insert(parts, `{receipt.relics} relic{if receipt.relics > 1 then "s" else ""}`)
	end
	if #parts > 0 then
		NetService.FireAll("Notify", "Crew", `{player.DisplayName} loaded {table.concat(parts, ", ")}.`)
	end
	if receipt.coalWasted > 0 then
		NetService.FireAll("Notify", "Warning", `Bunker full: {receipt.coalWasted} coal spilled.`)
	end
end

function InventoryService.Use(player: Player, slot: number)
	local inv = InventoryService.Get(player)
	local itemId = inv.items[slot]
	if itemId == nil then
		return
	end
	local def = Items[itemId]
	local character = player.Character
	local carriers = if character then character:GetAttribute("PayrollCarriers") else nil
	if typeof(carriers) == "number" and carriers == 1 and def.kind == "Tool" and def.use ~= nil then
		return
	end
	if def.kind ~= "Tool" then
		return
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return
	end
	if def.use == "Heal" and Registry.InjuryService.NeedsArm(player) then
		-- an arm to bring back: a two-second treatment, spent only when it completes
		Registry.InjuryService.BeginSelfHeal(player)
	elseif def.use == "Heal" then
		if humanoid.Health >= humanoid.MaxHealth then
			NetService.Fire("Notify", player, "Warning", "You are already at full health.")
			return
		end
		set(player, (Inventory.removeAt(inv, slot)))
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + Tuning.Tools.TonicHeal)
		NetService.Fire("Fx", player, "Heal", {})
	elseif def.use == "Stun" then
		set(player, (Inventory.removeAt(inv, slot)))
		local stunned = Registry.HollowService.Stun(
			root.Position,
			Tuning.Tools.FlashRadius,
			Tuning.Tools.FlashStunSeconds
		)
		NetService.FireAll(
			"Fx",
			"Flash",
			{ position = root.Position, radius = Tuning.Tools.FlashRadius, count = stunned }
		)
	elseif def.use == "Rescue" then
		NetService.Fire("Notify", player, "Info", "Fire flares at the signal mast on the brake van.")
	end
end

function InventoryService.Drop(player: Player, slot: number)
	local character = player.Character
	local carriers = if character then character:GetAttribute("PayrollCarriers") else nil
	if typeof(carriers) == "number" and carriers > 0 then
		return
	end
	local phase = Registry.RunDirector.Phase()
	if not RunRules.isStationOpen(phase) or Registry.CrewService.IsAboard(player) then
		return
	end
	local inv = InventoryService.Get(player)
	local nextInv, itemId = Inventory.removeAt(inv, slot)
	if itemId == nil then
		return
	end
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	local at = root.Position + root.CFrame.LookVector * 3
	if Registry.LootService.DropAt(itemId, at) then
		set(player, nextInv)
		-- heard by everyone near where it landed (Config/Audio ItemDrop)
		NetService.FireAll("Fx", "Sound", { cue = "ItemDrop", position = at - Vector3.new(0, 2.5, 0) })
	end
end

return InventoryService
