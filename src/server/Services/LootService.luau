--!strict
--[[
	Container searches and world pickups on the active station.
	Every container rolls once, deterministically from the station seed, and the
	first crew member to finish the search takes the items.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Loot = require(Shared.Config.Loot)
local Stations = require(Shared.Config.Stations)
local LayoutGen = require(Shared.Logic.LayoutGen)
local LootRoll = require(Shared.Logic.LootRoll)
local RunRules = require(Shared.Logic.RunRules)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StationBuilder = require(script.Parent.Parent.Builders.StationBuilder)
local StationService = require(script.Parent.StationService)

local LootService = {}

type PromptEntry = { prompt: ProximityPrompt, slab: number }

local prompts: { PromptEntry } = {}
local active = false
local current: { built: StationBuilder.Built, plan: LayoutGen.Plan, prompts: { [number]: ProximityPrompt } }? =
	nil

local function canInteract(player: Player): boolean
	return active
		and RunRules.isStationOpen(Registry.RunDirector.Phase())
		and Registry.CrewService.IsAlive(player)
		and not Registry.CrewService.IsAboard(player)
end

local function makePrompt(
	parent: BasePart,
	kind: string,
	objectText: string,
	actionText: string,
	hold: number,
	slab: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Action", kind)
	prompt.Parent = parent
	table.insert(prompts, { prompt = prompt, slab = slab })
	return prompt
end

local function spawnPickup(itemId: string, position: Vector3): boolean
	local built = StationService.Built()
	local plan = StationService.Plan()
	if built == nil or plan == nil then
		return false
	end
	local localPos = StationService.ToLocal(position)
	local slab = LayoutGen.slabAt(plan, localPos.X, math.max(localPos.Z, 0.5))
	if slab == nil or StationService.IsCollapsed(slab.id) then
		return false
	end
	local base = built.slabParts[slab.id]
	local ground = StationService.ToWorld(localPos.X, 0.75, math.max(localPos.Z, 1))
	local piece = StationBuilder.pickup(itemId, built.model, base, ground)
	local body = piece.PrimaryPart :: BasePart
	local prompt = makePrompt(body, "Pickup", Items[itemId].name, "Pick up", 0.25, slab.id)
	prompt.Triggered:Connect(function(player)
		if not canInteract(player) or piece.Parent == nil then
			return
		end
		local leftovers = Registry.InventoryService.Give(player, { itemId })
		if #leftovers == 0 then
			piece:Destroy()
			NetService.Fire("Fx", player, "Found", { items = { itemId } })
		else
			NetService.Fire("Notify", player, "Warning", "Your backpack is full.")
		end
	end)
	return true
end

local function onSearch(
	player: Player,
	handle: StationBuilder.ContainerHandle,
	prompt: ProximityPrompt,
	stationSeed: number
)
	if not canInteract(player) or handle.model:GetAttribute("Searched") then
		return
	end
	handle.model:SetAttribute("Searched", true)
	prompt.Enabled = false
	local archetype = Stations.List[(StationService.Plan() :: LayoutGen.Plan).archetype]
	local items = LootRoll.roll(
		handle.def.kind,
		handle.def.zone,
		archetype,
		LootRoll.seedFor(stationSeed, handle.def.id)
	)
	local leftovers = Registry.InventoryService.Give(player, items)
	local origin = handle.promptPart.Position
	for i, itemId in leftovers do
		local angle = i * 2.1
		spawnPickup(itemId, origin + Vector3.new(math.cos(angle) * 3, 0, math.sin(angle) * 3))
	end
	NetService.Fire(
		"Fx",
		player,
		"Found",
		{ items = items, leftovers = leftovers, container = handle.def.kind }
	)
end

function LootService.Init() end

function LootService.Start()
	StationService.SlabCollapsed:Connect(function(slabId)
		for _, entry in prompts do
			if entry.slab == slabId then
				entry.prompt.Enabled = false
			end
		end
	end)
	StationService.Cleared:Connect(function()
		active = false
		current = nil
		table.clear(prompts)
	end)
end

-- Creates the search and pickup prompts for the station that just spawned.
function LootService.Activate(built: StationBuilder.Built, plan: LayoutGen.Plan)
	table.clear(prompts)
	active = true
	local searchPrompts: { [number]: ProximityPrompt } = {}
	current = { built = built, plan = plan, prompts = searchPrompts }
	for _, handle in built.containers do
		local def = Loot.Containers[handle.def.kind]
		local hold = LootRoll.holdSeconds(handle.def.kind, handle.def.zone)
		local prompt = makePrompt(handle.promptPart, "Search", def.name, "Search", hold, handle.def.slab)
		prompt:SetAttribute("Zone", handle.def.zone)
		searchPrompts[handle.def.id] = prompt
		prompt.Triggered:Connect(function(player)
			onSearch(player, handle, prompt, plan.seed)
		end)
	end
	for _, handle in built.loose do
		local body = handle.model.PrimaryPart :: BasePart
		local itemId = handle.item
		local prompt = makePrompt(body, "Pickup", Items[itemId].name, "Pick up", 0.25, handle.slab)
		prompt.Triggered:Connect(function(player)
			if not canInteract(player) or handle.model.Parent == nil then
				return
			end
			local leftovers = Registry.InventoryService.Give(player, { itemId })
			if #leftovers == 0 then
				handle.model:Destroy()
				NetService.Fire("Fx", player, "Found", { items = { itemId } })
			else
				NetService.Fire("Notify", player, "Warning", "Your backpack is full.")
			end
		end)
	end
end

-- Studio developer console: search the nearest unsearched container as if the prompt finished.
function LootService.DevSearchNearest(player: Player): boolean
	local state = current
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if state == nil or root == nil then
		return false
	end
	local best: StationBuilder.ContainerHandle? = nil
	local bestDistance = math.huge
	for _, handle in state.built.containers do
		if not handle.model:GetAttribute("Searched") and handle.model.Parent then
			local distance = (handle.promptPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = handle, distance
			end
		end
	end
	if best == nil then
		return false
	end
	onSearch(player, best, state.prompts[best.def.id], state.plan.seed)
	return best.model:GetAttribute("Searched") == true
end

function LootService.DropAt(itemId: string, position: Vector3): boolean
	return spawnPickup(itemId, position)
end

return LootService
