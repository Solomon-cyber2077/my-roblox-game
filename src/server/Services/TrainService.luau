--!strict
--[[
	The train: its shared stores (through Logic/Ledger), coal burn per leg,
	hull breaches, the workshop, the signal mast, doors and livery.
	The train never moves; see StationService for the moving world.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local UpgradesConfig = require(Shared.Config.Upgrades)
local Ledger = require(Shared.Logic.Ledger)
local RunRules = require(Shared.Logic.RunRules)
local Signal = require(Shared.Util.Signal)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)
local TrainBuilder = require(script.Parent.Parent.Builders.TrainBuilder)

type Train = Types.TrainState

local TrainService = {
	UpgradeBought = Signal.new() :: Signal.Signal<string, number>,
}

local CAR_NAMES: { [string]: string } = {
	BV1 = "brake van",
	BV2 = "brake van",
	CR1 = "crew car",
	CR2 = "crew car",
	WS1 = "workshop",
	WS2 = "workshop",
	CAB = "cab",
}

local built: TrainBuilder.Built
local train: Train = Ledger.newTrain()
local leg: { cost: number, seconds: number, burned: number }? = nil
local breachRate = 0
local breachSeq = 0
local breachPrompts: { [string]: { prompt: ProximityPrompt, anchor: BasePart } } = {}
local rng = Random.new()
local lastPublished = ""

local function publish(force: boolean?)
	local signature =
		`{train.coal}|{train.parts}|{train.integrity}|{train.coalMax}|{train.starving}|{Ledger.breachCount(
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
			NetService.Fire("Notify", player, "Warning", "You need 1 part to patch a leak.")
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
	local prompt = makePrompt(anchor, "Breach", "Steam leak", "Patch (1 part)", Tuning.Train.BreachPatchHold)
	prompt.Triggered:Connect(function(player)
		patchBreach(player, id)
	end)
	breachPrompts[id] = { prompt = prompt, anchor = anchor }
	publish(true)
	notifyAll("Alarm", `Hull breach in the {CAR_NAMES[name] or "train"}!`)
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
	if RunRules.isTravel(phase) and Ledger.breachCount(train) < Tuning.Train.MaxBreaches then
		if rng:NextNumber() < breachRate * dt then
			openBreach()
		end
	end
	if RunRules.isTravel(phase) then
		train = Ledger.drain(train, dt)
	end
	publish()
end

function TrainService.Init()
	built = TrainBuilder.build(CFrame.new(0, Tuning.World.FloorY, 0), Workspace)
	built.model:SetAttribute("DoorsOpen", false)
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
	NetService.Handle("HullPatch", function(player)
		TrainService.HullPatch(player)
	end, isAboard)

	task.spawn(function()
		while true do
			local dt = task.wait(Tuning.Train.TickSeconds)
			tick(dt)
		end
	end)
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
	breachRate = 0
	publish(true)
end

function TrainService.SetBreachRate(rate: number)
	breachRate = rate
end

function TrainService.BeginLeg(km: number, seconds: number, rate: number)
	leg = { cost = Ledger.legCoalCost(train, km), seconds = math.max(seconds, 1), burned = 0 }
	breachRate = rate
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
	breachRate = 0
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

function TrainService.HullPatch(player: Player)
	local nextTrain, ok, reason = Ledger.hullPatch(train)
	if not ok then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			if reason == "Full" then "The hull is already sound." else "A hull patch costs 5 parts."
		)
		return
	end
	train = nextTrain
	publish(true)
	notifyAll("Upgrade", `{player.DisplayName} patched the hull (+{Tuning.Train.HullPatchAmount}).`)
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
	publish(true)
end

return TrainService
