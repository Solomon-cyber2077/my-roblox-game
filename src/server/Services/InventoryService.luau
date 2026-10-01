--!strict
--[[
	Backpacks. Holds each crew member's Inventory state, applies the pure rules
	in Logic/Inventory, deposits cargo into the train, and runs tool use.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
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

local function set(player: Player, inv: InventoryState)
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
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
end

function InventoryService.Get(player: Player): InventoryState
	return inventories[player] or Inventory.new()
end

function InventoryService.Capacity(): number
	return Tuning.Crew.BackpackSlots + Registry.TrainService.Derived().extraSlots
end

function InventoryService.Reset(player: Player)
	set(player, Inventory.new(InventoryService.Capacity()))
end

function InventoryService.Clear(player: Player)
	set(player, Inventory.new(InventoryService.Capacity()))
end

function InventoryService.RefreshCapacity()
	local capacity = InventoryService.Capacity()
	for player, inv in inventories do
		if inv.capacity ~= capacity then
			set(player, Inventory.withCapacity(inv, capacity))
		end
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
	if def.kind ~= "Tool" then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return
	end
	if def.use == "Heal" then
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
	local phase = Registry.RunDirector.Phase()
	if not RunRules.isStationOpen(phase) or Registry.CrewService.IsAboard(player) then
		return
	end
	local inv = InventoryService.Get(player)
	local nextInv, itemId = Inventory.removeAt(inv, slot)
	if itemId == nil then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return
	end
	if Registry.LootService.DropAt(itemId, root.Position + root.CFrame.LookVector * 3) then
		set(player, nextInv)
	end
end

return InventoryService
