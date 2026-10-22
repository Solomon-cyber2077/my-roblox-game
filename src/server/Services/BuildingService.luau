--!strict
--[[
	The stop's enterable buildings while its doors are open.

	  Locked door  spend a part to force it. Behind it is the good stuff (a coal cellar, a
	               strongroom, a dispensary), and the noise wakes whatever sleeps nearby.

	A part is cargo in a backpack (Scrap and the like: Config/Items `parts`), spent here
	instead of being carried back to patch the train. That is the choice.

	  Forcing      on a forcing stop (Logic/Doors: from stop 3, 40% of stops, by the station's
	               seed) a hunting Hollow stopped by a shut locked door asks to force it. One
	               episode per door: the door booms for 3 s, a crew member holding it (its "Hold
	               the door" prompt) adds 4 s once, every other Hollow queues on the same timer.
	               Then it bursts open for good. Light on the door ends the episode.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Buildings = require(Shared.Config.Buildings)
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)
local Doors = require(Shared.Logic.Doors)
local LayoutGen = require(Shared.Logic.LayoutGen)
local RunRules = require(Shared.Logic.RunRules)
local Kit = require(Shared.Visual.Kit)
local Safe = require(Shared.Util.Safe)

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

type Lockup = { state: Active, lock: BuildingBuilder.Lock, prompt: ProximityPrompt }
type Force = { episode: Doors.Episode, lockup: Lockup, hold: ProximityPrompt, nextPulse: number }

local BuildingService = {}

local active: { [number]: Active } = {}
local lockups: { [BasePart]: Lockup } = {} -- every shut locked door, by its leaf
local forces: { [BasePart]: Force } = {} -- the forcing under way at each door
local forcingStop = false -- this stop's Hollows can force doors (Logic/Doors)
local PULSE = 0.8 -- seconds between the booms of a door being forced

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

local function stopForcing(leaf: BasePart)
	local f = forces[leaf]
	if f then
		forces[leaf] = nil
		f.hold:Destroy()
	end
end

-- The door swings open for good: the chain and padlock gone, the leaf against the wall.
local function open(state: Active, lock: BuildingBuilder.Lock, p: ProximityPrompt)
	p.Enabled = false
	lockups[lock.leaf] = nil
	stopForcing(lock.leaf)
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

local function force(player: Player, state: Active, lock: BuildingBuilder.Lock, p: ProximityPrompt)
	if state.fallen or not canInteract(player) or not p.Enabled then
		return
	end
	if not takeParts(player, Buildings.ForceCost) then
		NetService.Fire("Notify", player, "Warning", "Forcing the lock takes a part.")
		return
	end
	open(state, lock, p)
end

-- A crew member braces the door: the one hold extension of this episode.
local function brace(player: Player, leaf: BasePart)
	local f = forces[leaf]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if
		f == nil
		or root == nil
		or not canInteract(player)
		or (root.Position - leaf.Position).Magnitude > Tuning.DoorForce.HoldDistance
	then
		return
	end
	if Doors.hold(f.episode) then
		f.hold.Enabled = false
		NetService.Fire("Notify", player, "Info", "You brace the door. It will hold a little longer.")
	end
end

local function forceTick()
	local now = os.clock()
	for leaf, f in forces do
		local lockup = f.lockup
		-- fallen, opened by the crew, abandoned, or light on the door (the Hollows are repelled)
		if
			lockup.state.fallen
			or not lockup.prompt.Enabled
			or #f.episode.queue == 0
			or Registry.HollowService.IsLit(leaf.Position)
		then
			stopForcing(leaf)
		elseif Doors.done(f.episode, now) then
			open(lockup.state, lockup.lock, lockup.prompt)
		elseif now >= f.nextPulse then
			f.nextPulse = now + PULSE
			NetService.FireAll("Fx", "Sound", { cue = "DoorForce", position = leaf.Position })
		end
	end
end

function BuildingService.Init() end

function BuildingService.Start()
	RunService.Heartbeat:Connect(function()
		if next(forces) ~= nil then
			Safe.call("BuildingService.forceTick", forceTick)
		end
	end)
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
		for leaf in forces do
			stopForcing(leaf)
		end
		table.clear(lockups)
		forcingStop = false
	end)
end

-- Arms the locked doors of the station that just opened its doors.
function BuildingService.Activate(built: StationBuilder.Built, plan: LayoutGen.Plan)
	table.clear(active)
	for leaf in forces do
		stopForcing(leaf)
	end
	table.clear(lockups)
	local info = StationService.Info()
	local stop = if info then info.hazards.stop else nil
	forcingStop = info ~= nil
		and stop ~= nil
		and info.emergency == nil
		and Doors.forcing(info.layoutSeed, stop)
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
				lockups[lock.leaf] = { state = state, lock = lock, prompt = p }
				p.Triggered:Connect(function(player)
					force(player, state, lock, p)
				end)
			end
		end
	end
end

-- A hunting Hollow stopped by the shut door `leaf` asks to force it. True while it is being forced
-- (the Hollow waits at it); false when it cannot be (not a forcing stop, open, lit).
function BuildingService.RequestForce(leaf: BasePart, hollow: any): boolean
	local lockup = lockups[leaf]
	if not forcingStop or lockup == nil or lockup.state.fallen or not lockup.prompt.Enabled then
		return false
	end
	if Registry.HollowService.IsLit(leaf.Position) then
		stopForcing(leaf)
		return false
	end
	local f = forces[leaf]
	if f then
		Doors.join(f.episode, hollow)
		return true
	end
	local hold = prompt(leaf, "Hold", "Door", "Hold the door", 0.5)
	hold.MaxActivationDistance = Tuning.DoorForce.HoldDistance
	hold.Triggered:Connect(function(player)
		brace(player, leaf)
	end)
	forces[leaf] = { episode = Doors.start(os.clock(), hollow), lockup = lockup, hold = hold, nextPulse = 0 }
	return true
end

-- A Hollow gives up on the door (lost its prey, stunned, repelled). The episode goes on for any
-- other in the queue, and ends with the last.
function BuildingService.LeaveForce(leaf: BasePart, hollow: any)
	local f = forces[leaf]
	if f then
		Doors.leave(f.episode, hollow)
	end
end

-- Whether this stop's Hollows can force doors (Studio checks).
function BuildingService.IsForcingStop(): boolean
	return forcingStop
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
