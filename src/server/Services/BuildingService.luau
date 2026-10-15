--!strict
--[[
	The stop's enterable buildings while its doors are open.

	  Locked door  spend a part to force it. Behind it is the good stuff (a coal cellar, a
	               strongroom, a dispensary), and the noise wakes whatever sleeps nearby.

	A part is cargo in a backpack (Scrap and the like: Config/Items `parts`), spent here
	instead of being carried back to patch the train. That is the choice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local Items = require(Shared.Config.Items)
local LayoutGen = require(Shared.Logic.LayoutGen)
local RunRules = require(Shared.Logic.RunRules)
local Kit = require(Shared.Visual.Kit)

local BuildingBuilder = require(script.Parent.Parent.Builders.BuildingBuilder)
local StationBuilder = require(script.Parent.Parent.Builders.StationBuilder)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StationService = require(script.Parent.StationService)

type Active = {
	building: LayoutGen.Building,
	handle: BuildingBuilder.Handle,
	slab: BasePart,
	fallen: boolean,
	prompts: { ProximityPrompt },
}

local BuildingService = {}

local active: { [number]: Active } = {}

local function canInteract(player: Player): boolean
	return RunRules.isStationOpen(Registry.RunDirector.Phase())
		and Registry.CrewService.IsAlive(player)
		and not Registry.CrewService.IsAboard(player)
end

-- Spends `count` parts' worth of cargo from the backpack; false (and nothing spent) if short.
local function takeParts(player: Player, count: number): boolean
	local inv = Registry.InventoryService.Get(player)
	local chosen: { string } = {}
	local total = 0
	for _, itemId in inv.items do
		local def = Items[itemId] :: any
		if total < count and def and (def.parts or 0) > 0 then
			table.insert(chosen, itemId)
			total += def.parts
		end
	end
	if total < count then
		return false
	end
	for _, itemId in chosen do
		Registry.InventoryService.Consume(player, itemId)
	end
	return true
end

local function prompt(
	parent: BasePart,
	action: string,
	object: string,
	text: string,
	hold: number
): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = text
	p.ObjectText = object
	p.HoldDuration = hold
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Action", action)
	p.Parent = parent
	return p
end

local function origin(state: Active): CFrame
	-- the foundation's top part sits one stud under the floor, centred on the building
	return state.slab.CFrame * CFrame.new(0, 1, 0)
end

local function force(player: Player, state: Active, lock: BuildingBuilder.Lock, p: ProximityPrompt)
	if state.fallen or not canInteract(player) or not p.Enabled then
		return
	end
	if not takeParts(player, Buildings.ForceCost) then
		NetService.Fire("Notify", player, "Warning", "Forcing the lock takes a part.")
		return
	end
	p.Enabled = false
	local leaf = lock.leaf
	for _, child in leaf:GetChildren() do
		if child:IsA("WeldConstraint") or child:IsA("BasePart") then
			child:Destroy() -- the weld, and the chain and padlock hanging from it
		end
	end
	leaf.CFrame = origin(state) * lock.open
	leaf.CanCollide = false
	leaf.CanQuery = false
	Kit.weld(leaf, state.slab)
	NetService.FireAll("Fx", "Sound", { cue = "DoorForce", position = leaf.Position })
	Registry.HollowService.Disturb(leaf.Position, 40)
end

function BuildingService.Init() end

function BuildingService.Start()
	StationService.SlabCollapsed:Connect(function(slabId: number)
		for _, state in active do
			if state.building.slab == slabId then
				state.fallen = true
				for _, p in state.prompts do
					p.Enabled = false
				end
			end
		end
	end)
	StationService.Cleared:Connect(function()
		table.clear(active)
	end)
end

-- Arms the locked doors of the station that just opened its doors.
function BuildingService.Activate(built: StationBuilder.Built, plan: LayoutGen.Plan)
	table.clear(active)
	for _, building in plan.buildings do
		local handle = built.buildings[building.id]
		local slab = built.slabParts[building.slab]
		if handle and slab then
			local state: Active = {
				building = building,
				handle = handle,
				slab = slab,
				fallen = false,
				prompts = {},
			}
			active[building.id] = state
			for _, lock in handle.locks do
				local p =
					prompt(lock.leaf, "Force", "Locked Door", "Force the lock · 1 part", Buildings.ForceHold)
				table.insert(state.prompts, p)
				p.Triggered:Connect(function(player)
					force(player, state, lock, p)
				end)
			end
		end
	end
end

-- Buildings no longer have power to restore (the fuse boxes went 2026-10-14), so none is a
-- lit refuge; kept for HollowService, which asks.
function BuildingService.IsLitAt(_position: Vector3): boolean
	return false
end

-- A point just outside the nearest door of the building around `position`.
function BuildingService.ExitPoint(position: Vector3): Vector3?
	local localPos = StationService.ToLocal(position)
	for _, state in active do
		local building = state.building
		local plan = building.plan
		if
			math.abs(localPos.X - building.x) <= plan.outerX + 1
			and math.abs(localPos.Z - building.z) <= plan.outerZ + 1
		then
			local best: Vector3? = nil
			local bestDistance = math.huge
			for _, exit in plan.exits do
				local x, z = building.x + exit.x, building.z + exit.z
				local distance = (Vector3.new(x, 0, z) - Vector3.new(localPos.X, 0, localPos.Z)).Magnitude
				if distance < bestDistance then
					best, bestDistance = StationService.ToWorld(x, 3, z), distance
				end
			end
			return best
		end
	end
	return nil
end

return BuildingService
