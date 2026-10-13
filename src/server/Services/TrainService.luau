--!strict
--[[
	The train: its shared stores (through Logic/Ledger), coal burn per leg,
	hull breaches, the workshop, the signal mast, doors, livery and its seats
	(every one takes a Sit prompt; jump to stand).
	The train never moves; see StationService for the moving world.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local LeakAlert = require(Shared.Logic.LeakAlert)
local Leaks = require(Shared.Logic.Leaks)
local Ledger = require(Shared.Logic.Ledger)
local RunRules = require(Shared.Logic.RunRules)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)
local RailingPilot = require(script.Parent.Parent.Builders.RailingPilot)
local TrainBuilder = require(script.Parent.Parent.Builders.TrainBuilder)

type Train = Types.TrainState

local TrainService = {
	UpgradeBought = Signal.new() :: Signal.Signal<string, number>,
}

local built: TrainBuilder.Built
local train: Train = Ledger.newTrain()
-- this trip: its coal, and its leaks (Logic/Leaks) as burst times in seconds of travel
type Leg = {
	cost: number,
	seconds: number,
	burned: number,
	elapsed: number,
	bursts: { number },
	opened: number,
	cap: number,
}
local leg: Leg? = nil
local breachSeq = 0
local breachPrompts: { [string]: { prompt: ProximityPrompt, anchor: BasePart } } = {}
local pendingBursts = 0 -- leaks asked for while standing (a timed Breakdown): they burst once moving
local LEAK_TAG = "Leak" -- every open leak's anchor carries it: the HUD and markers count these
local rng = Random.new()
local lastPublished = ""
local safeGlows: { PointLight } = {}

local function publish(force: boolean?)
	-- integrity keeps its fraction (Ledger.drain); the crew sees it in tenths
	local signature =
		`{train.coal}|{train.parts}|{math.floor(train.integrity * 10)}|{train.coalMax}|{train.starving}|{Ledger.breachCount(
			train
		)}`
	if force or signature ~= lastPublished then
		lastPublished = signature
		StateService.Set({ "train" }, train)
		built.model:SetAttribute("CoalFill", math.clamp(train.coal / math.max(train.coalMax, 1), 0, 1))
	end
end

local function makePrompt(
	parent: BasePart,
	action: string,
	objectText: string,
	actionText: string,
	hold: number
): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute("Action", action)
	prompt.Parent = parent
	return prompt
end

local function notifyAll(kind: string, text: string)
	NetService.FireAll("Notify", kind, text)
end

local function isAboard(player: Player): boolean
	return Registry.CrewService.IsAboard(player)
end

local function closeBreach(id: string)
	local entry = breachPrompts[id]
	if entry then
		entry.prompt:Destroy()
		entry.anchor:SetAttribute("Breach", false)
		entry.anchor:SetAttribute("LeakId", nil)
		entry.anchor:RemoveTag(LEAK_TAG)
		breachPrompts[id] = nil
	end
end

local function patchBreach(player: Player, id: string)
	if not isAboard(player) then
		return
	end
	local nextTrain, ok, reason = Ledger.patchBreach(train, id)
	if not ok then
		if reason == "Parts" then
			NetService.Fire(
				"Notify",
				player,
				"Warning",
				`You need {Difficulty.Leaks.PatchParts} part{if Difficulty.Leaks.PatchParts == 1
					then ""
					else "s"} to patch a leak.`
			)
		end
		return
	end
	train = nextTrain
	closeBreach(id)
	publish(true)
	notifyAll("Crew", `{player.DisplayName} patched a leak.`)
end

local function openBreach()
	local free: { BasePart } = {}
	for _, anchor in built.breachAnchors do
		if anchor:GetAttribute("Breach") ~= true then
			table.insert(free, anchor)
		end
	end
	if #free == 0 then
		return
	end
	local anchor = free[rng:NextInteger(1, #free)]
	breachSeq += 1
	local id = `B{breachSeq}`
	local name = anchor:GetAttribute("BreachAnchor") :: string
	train = Ledger.openBreach(train, id, name, Workspace:GetServerTimeNow())
	anchor:SetAttribute("Breach", true)
	anchor:SetAttribute("LeakId", id)
	anchor:AddTag(LEAK_TAG)
	anchor:SetAttribute("LeakSeverity", 1)
	local prompt = makePrompt(
		anchor,
		"Breach",
		"Steam leak",
		`Patch ({Difficulty.Leaks.PatchParts} part{if Difficulty.Leaks.PatchParts == 1 then "" else "s"})`,
		Difficulty.Leaks.PatchHold
	)
	prompt.Triggered:Connect(function(player)
		patchBreach(player, id)
	end)
	breachPrompts[id] = { prompt = prompt, anchor = anchor }
	publish(true)
	notifyAll("Alarm", `Hull breach in the {LeakAlert.car(name)}!`)
end

local function tick(dt: number)
	local phase = Registry.RunDirector.Phase()
	if not RunRules.isRunPhase(phase) then
		return
	end
	if leg and phase == "Cruise" then
		local amount = math.min(leg.cost / leg.seconds * dt, leg.cost - leg.burned)
		if amount > 0 then
			leg.burned += amount
			train = Ledger.burn(train, amount)
		end
	end
	-- leaks burst and the hull drains only while the train is running (never at the vote or a stop)
	local current = leg
	local breakdown = Registry.BreakdownService
	local share = if breakdown then breakdown.SpeedShare() else 1
	if current and RunRules.hullDrains(phase) and share > 0 then
		-- leaks burst by distance travelled: a limping train reaches them later
		current.elapsed += dt * share
		local due = current.bursts[1]
		local wantsBurst = (due ~= nil and current.elapsed >= due) or pendingBursts > 0
		if
			wantsBurst
			and current.opened < current.cap
			and Ledger.breachCount(train) < Difficulty.Leaks.Cap
		then
			if due ~= nil and current.elapsed >= due then
				table.remove(current.bursts, 1)
			else
				pendingBursts -= 1
			end
			current.opened += 1
			openBreach()
		end
		train = Ledger.drain(train, dt, current.seconds)
		-- how bad each leak has got, for its steam and hiss (TrainVisualsController)
		for id, breach in train.breaches do
			local entry = breachPrompts[id]
			if entry then
				local severity = Leaks.severity(breach.age or 0, current.seconds)
				entry.anchor:SetAttribute("LeakSeverity", math.floor(severity * 10 + 0.5) / 10)
			end
		end
	end
	publish()
end

-- SafeLight parts (Config/Tutorial) along the train's platform side, one every SAFE_SPACING studs
-- of its length. HollowService keeps Hollows out of their radius while the tutorial lights them.
local SAFE_SPACING = 24
local function safeLights()
	local light = Difficulty.Tutorial.SafeLight
	local lo, hi = math.huge, -math.huge
	for _, volume in { built.carVolume, built.cabVolume } do
		local half = volume.size.X / 2
		lo = math.min(lo, volume.cframe.Position.X - half)
		hi = math.max(hi, volume.cframe.Position.X + half)
	end
	local count = math.max(math.floor((hi - lo) / SAFE_SPACING), 1)
	for i = 0, count do
		local x = lo + (hi - lo) * i / count
		local part = Instance.new("Part")
		part.Name = "SafeLight"
		part.Size = Vector3.new(1, 1, 1)
		part.Transparency = 1
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CFrame = TrainService.Origin() * CFrame.new(x, 9, Tuning.World.PlatformEdgeZ)
		part:SetAttribute("Radius", light.TrainRadius)
		part:AddTag(light.Tag)
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 196, 120)
		glow.Brightness = 0.9
		glow.Range = 22
		glow.Shadows = false
		glow.Enabled = false
		glow.Parent = part
		table.insert(safeGlows, glow)
		part.Parent = built.model
	end
end

-- A Sit prompt on every seat, hidden while someone is sitting in it.
local function seatPrompts()
	for _, seat in built.seats do
		local name = (seat:GetAttribute("SeatName") :: string?) or "Seat"
		local prompt = makePrompt(seat, "Sit", name, "Sit", 0)
		prompt.MaxActivationDistance = 5.5
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			prompt.Enabled = seat.Occupant == nil
		end)
		prompt.Triggered:Connect(function(player)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				humanoid
				and root
				and humanoid.Health > 0
				and seat.Occupant == nil
				and not humanoid.Sit
				and not root.Anchored
				and (root.Position - seat.Position).Magnitude < 9
			then
				seat:Sit(humanoid)
			end
		end)
	end
end

function TrainService.Init()
	built = TrainBuilder.build(TrainService.Origin(), Workspace)
	RailingPilot.build(TrainService.Origin())
	built.model:SetAttribute("DoorsOpen", false)
	seatPrompts()
	safeLights()
	makePrompt(built.workbench, "Workshop", "Workbench", "Upgrades", 0)
	local mastPrompt = makePrompt(built.mast, "Flare", "Signal mast", "Fire Signal Flare", 0.6)
	mastPrompt.Triggered:Connect(function(player)
		TrainService.FireFlare(player)
	end)
	TrainService.SetDoors(false)
	publish(true)
end

function TrainService.Start()
	NetService.Handle("BuyUpgrade", function(player, upgradeId: string)
		TrainService.BuyUpgrade(player, upgradeId)
	end, isAboard)
	NetService.Handle("RepairHull", function(player)
		TrainService.RepairHull(player)
	end, isAboard)

	task.spawn(function()
		while true do
			local dt = task.wait(Tuning.Train.TickSeconds)
			tick(dt)
		end
	end)
end

-- Train space (TrainBuilder): x along the track, y = 0 the floor, +Z the platform side.
function TrainService.Origin(): CFrame
	return CFrame.new(0, Tuning.World.FloorY, 0)
end

function TrainService.Model(): Model
	return built.model
end

function TrainService.Get(): Train
	return table.clone(train)
end

function TrainService.Integrity(): number
	return train.integrity
end

-- Sets the hull (a breakdown rally's repair, Services/BreakdownService), never past the max.
function TrainService.SetIntegrity(value: number)
	local nextTrain = table.clone(train)
	nextTrain.integrity = math.clamp(value, 0, train.integrityMax)
	train = nextTrain
	publish(true)
end

-- Where leaks burst, one or two per car (BreachAnchor attribute names the car).
function TrainService.BreachAnchors(): { BasePart }
	return table.clone(built.breachAnchors)
end

function TrainService.SpawnPoint(index: number): CFrame
	return built.spawnPoints[(index - 1) % #built.spawnPoints + 1]
end

function TrainService.IsInside(position: Vector3): boolean
	for _, volume in { built.carVolume, built.cabVolume } do
		local p = volume.cframe:PointToObjectSpace(position)
		local half = volume.size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
			return true
		end
	end
	return false
end

function TrainService.SetDoors(open: boolean)
	built.model:SetAttribute("DoorsOpen", open)
	for _, blocker in built.doorBlockers do
		blocker.CanCollide = not open
	end
end

function TrainService.ResetForRun()
	for id in breachPrompts do
		closeBreach(id)
	end
	train = Ledger.newTrain()
	leg = nil
	pendingBursts = 0
	publish(true)
end

-- The train's safe lights glow while the tutorial lights them (HollowService.Configure).
function TrainService.SetSafeGlow(on: boolean)
	for _, glow in safeGlows do
		glow.Enabled = on
	end
end

-- Bursts one steam leak (a timed Breakdown): now if the train is running, otherwise as soon as
-- it next is, since leaks only burst while moving. False if no spot is free right now.
function TrainService.OpenBreach(): boolean
	if not RunRules.hullDrains(Registry.RunDirector.Phase()) then
		pendingBursts += 1
		return true
	end
	local before = Ledger.breachCount(train)
	openBreach()
	return Ledger.breachCount(train) > before
end

-- A trip of `km` and `seconds` toward stop `stop` of difficulty `d`: plans its leaks.
function TrainService.BeginLeg(km: number, seconds: number, stop: number, d: number)
	local count = Leaks.count(stop, d, train.upgrades, rng:NextNumber())
	local shares = Leaks.shares(count, function()
		return rng:NextNumber(-1, 1)
	end)
	local bursts = {}
	for _, share in shares do
		table.insert(bursts, share * math.max(seconds, 1))
	end
	table.sort(bursts)
	leg = {
		cost = Ledger.legCoalCost(train, km),
		seconds = math.max(seconds, 1),
		burned = 0,
		elapsed = 0,
		bursts = bursts,
		opened = 0,
		cap = Leaks.cap(stop),
	}
end

-- Settles the leg's full coal cost even if the tick loop came up a little short.
function TrainService.EndLeg()
	if leg then
		local remaining = leg.cost - leg.burned
		if remaining > 0 then
			train = Ledger.burn(train, remaining)
		end
		leg = nil
	end
	publish()
end

function TrainService.Deposit(cargo: { string }): Ledger.Receipt
	local nextTrain, receipt = Ledger.deposit(train, cargo)
	train = nextTrain
	publish(true)
	return receipt
end

function TrainService.Derived(): Ledger.Derived
	return Ledger.derived(train)
end

function TrainService.BuyUpgrade(player: Player, upgradeId: string)
	local phase = Registry.RunDirector.Phase()
	if not RunRules.isRunPhase(phase) then
		return
	end
	local nextTrain, ok, reason = Ledger.buyUpgrade(train, upgradeId)
	if not ok then
		local messages = {
			Parts = "Not enough parts for that upgrade.",
			Maxed = "That upgrade is already fully fitted.",
		}
		NetService.Fire("Notify", player, "Warning", messages[reason or ""] or "That upgrade is unavailable.")
		return
	end
	train = nextTrain
	local level = Ledger.level(train, upgradeId)
	publish(true)
	local def = UpgradesConfig.List[upgradeId]
	notifyAll(
		"Upgrade",
		`{player.DisplayName} fitted {def.name}{if #def.costs > 1 then " " .. string.rep("I", level) else ""}.`
	)
	TrainService.UpgradeBought:Fire(upgradeId, level)
end

-- Workbench "Repair hull": the server checks the run, the parts and the hull (Ledger.repairHull).
function TrainService.RepairHull(player: Player)
	if not RunRules.isRunPhase(Registry.RunDirector.Phase()) then
		return
	end
	local hull = Difficulty.Hull
	local nextTrain, ok, reason = Ledger.repairHull(train)
	if not ok then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			if reason == "Full"
				then "The hull is already sound."
				else `A hull repair takes {hull.RepairParts} parts.`
		)
		return
	end
	train = nextTrain
	publish(true)
	notifyAll("Upgrade", `{player.DisplayName} repaired the hull (+{hull.RepairAmount}%).`)
end

function TrainService.FireFlare(player: Player)
	local phase = Registry.RunDirector.Phase()
	if phase ~= "Dwell" and phase ~= "LastCall" then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			"Flares only work while the train is standing at a station."
		)
		return
	end
	if not Registry.CrewService.IsAlive(player) then
		return
	end
	if not Registry.InventoryService.Has(player, "Flare") then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			"You need a Signal Flare. Search the far side of stations."
		)
		return
	end
	if Registry.CrewService.RescuableCount() == 0 then
		NetService.Fire("Notify", player, "Warning", "Nobody is waiting to be brought back.")
		return
	end
	Registry.InventoryService.Consume(player, "Flare")
	local rescued = Registry.CrewService.Rescue(player)
	NetService.FireAll(
		"Fx",
		"Flare",
		{ position = built.mastLamp.Position, by = player.UserId, count = rescued }
	)
end

-- Studio developer console: overwrite a store directly.
function TrainService.DevSet(key: string, value: number)
	local nextTrain = table.clone(train)
	if key == "coal" then
		nextTrain.coal = math.clamp(value, 0, nextTrain.coalMax)
		nextTrain.starving = nextTrain.coal <= 0
	elseif key == "parts" then
		nextTrain.parts = math.max(value, 0)
	end
	train = nextTrain
	publish(true)
end

function TrainService.ApplyLivery(look: { [string]: any })
	TrainBuilder.applyLivery(built.model, look)
	local display = Registry.LobbyService.DisplayTrain()
	if display then
		TrainBuilder.applyLivery(display, look)
	end
end

function TrainService.ClearBreaches()
	for id in breachPrompts do
		closeBreach(id)
	end
	local nextTrain = table.clone(train)
	nextTrain.breaches = {}
	train = nextTrain
	pendingBursts = 0
	publish(true)
end

return TrainService
