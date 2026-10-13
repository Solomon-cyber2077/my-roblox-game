--!strict
--[[
	Breakdowns (Logic/Breakdown, Difficulty.Breakdown). The hull never drains below its floor by
	itself (Ledger.drain); reaching the floor while the train runs is a breakdown:

	  * the first in a run: the train stops and asks for an Emergency Village stop
	    (requestVillageStop, built in part 3; until then it is never granted). Refused, the
	    crew gets a rally: RallyRepairs repair prompts aboard and RallySeconds to make them.
	    Done, the hull goes back to RallyRestore and the train limps on at LimpShare of its
	    speed for the rest of the trip. Not done in time, the train is lost.
	  * a second in the same run: the train is lost, the run ends (outcome Derailed; the
	    run ticket reads THE TRAIN WAS LOST).

	While the train is stopped or limping the trip's clock is pushed back (RunDirector.ExtendPhase)
	so the trip still covers its distance; run.breakdown tells the clients (the scenery slows
	and stops with it). The rally shows in the timed-event toast (TimedEvent attributes).

	Rules for part 3's Emergency Village: it yields repair parts only, once per run, does not count
	as one of the ten stops, and its threat follows the same curve and tutorial tier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Breakdown = require(Shared.Logic.Breakdown)
local Ledger = require(Shared.Logic.Ledger)
local RunRules = require(Shared.Logic.RunRules)
local Safe = require(Shared.Util.Safe)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local C = Difficulty.Breakdown

local BreakdownService = {}

local state: Breakdown.State = Breakdown.new()
local prompts: { ProximityPrompt } = {}
local shownText = ""

local function now(): number
	return Workspace:GetServerTimeNow()
end

-- Part 3 supplies the Emergency Village: until then a breakdown is never sent there.
function BreakdownService.requestVillageStop(): boolean
	return false
end

local function publish()
	StateService.Set({ "run", "breakdown" }, {
		phase = state.phase,
		count = state.count,
		endsAt = state.endsAt,
		repairs = state.repairs,
		needed = state.needed,
	})
end

-- The rally's countdown in the timed-event toast (client TimedEventToast).
local function toast(on: boolean)
	if not on then
		if ReplicatedStorage:GetAttribute("TimedEvent") == "Rally" then
			for _, name in { "TimedEvent", "TimedEventTitle", "TimedEventText", "TimedEventCue" } do
				ReplicatedStorage:SetAttribute(name, nil)
			end
		end
		shownText = ""
		return
	end
	local left = math.max(math.ceil((state.endsAt or now()) - now()), 0)
	local text = `Repairs aboard: {state.repairs}/{state.needed}  ·  {left} s`
	if text ~= shownText then
		shownText = text
		ReplicatedStorage:SetAttribute("TimedEventTitle", "BREAKDOWN")
		ReplicatedStorage:SetAttribute("TimedEventText", text)
		ReplicatedStorage:SetAttribute("TimedEventStartAt", now())
		ReplicatedStorage:SetAttribute("TimedEventEndAt", state.endsAt)
		ReplicatedStorage:SetAttribute("TimedEventCue", "Alarm")
		ReplicatedStorage:SetAttribute("TimedEvent", "Rally")
	end
end

local function clearPrompts()
	for _, prompt in prompts do
		local holder = prompt.Parent
		prompt:Destroy()
		if holder and holder:IsA("Attachment") then
			holder:Destroy()
		end
	end
	table.clear(prompts)
end

local function lose()
	clearPrompts()
	toast(false)
	publish()
	NetService.FireAll("Notify", "Alarm", "The train has broken down for good. It is lost.")
	Registry.RunDirector.EndRun("Derailed")
end

local function onRepair(player: Player, prompt: ProximityPrompt)
	if state.phase ~= "Rally" or not Registry.CrewService.IsAboard(player) then
		return
	end
	local index = table.find(prompts, prompt)
	if index == nil then
		return
	end
	table.remove(prompts, index)
	local holder = prompt.Parent
	prompt:Destroy()
	if holder and holder:IsA("Attachment") then
		holder:Destroy()
	end
	local done
	state, done = Breakdown.repair(state)
	NetService.FireAll(
		"Notify",
		"Crew",
		`{player.DisplayName} made a repair ({state.repairs}/{state.needed}).`
	)
	if done then
		clearPrompts()
		toast(false)
		Registry.TrainService.SetIntegrity(C.RallyRestore)
		NetService.FireAll("Notify", "Upgrade", "Repaired! The train limps on.")
	end
	publish()
end

-- RallyRepairs repair prompts, one per car where it can, on the leak anchors' walls.
local function openRally()
	clearPrompts()
	local seen: { [string]: boolean } = {}
	local chosen: { BasePart } = {}
	local anchors = Registry.TrainService.BreachAnchors()
	for _, anchor in anchors do
		local car = string.sub((anchor:GetAttribute("BreachAnchor") :: string?) or anchor.Name, 1, 2)
		if not seen[car] and #chosen < state.needed then
			seen[car] = true
			table.insert(chosen, anchor)
		end
	end
	for _, anchor in anchors do
		if #chosen >= state.needed then
			break
		end
		if not table.find(chosen, anchor) then
			table.insert(chosen, anchor)
		end
	end
	for _, anchor in chosen do
		local spot = Instance.new("Attachment")
		spot.Name = "RallyRepair"
		spot.Position = Vector3.new(0, -1.6, 0)
		spot.Parent = anchor
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Repair"
		prompt.ObjectText = "Breakdown"
		prompt.HoldDuration = C.RallyHold
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Action", "Repair")
		prompt.Parent = spot
		prompt.Triggered:Connect(function(player)
			onRepair(player, prompt)
		end)
		table.insert(prompts, prompt)
	end
end

local function step(dt: number)
	local phase = Registry.RunDirector.Phase()
	if phase ~= "Cruise" or Breakdown.lost(state) then
		return
	end
	local before = state.phase
	if state.phase == "None" or state.phase == "Limp" then
		local train = Registry.TrainService.Get()
		if Ledger.atFloor(train) then
			local village = state.count == 0 and BreakdownService.requestVillageStop()
			local broken = Breakdown.onFloor(state, now(), village)
			state = broken
			if broken.phase == "Stopped" then
				NetService.FireAll("Notify", "Alarm", "The train has broken down!")
			end
		end
	end
	state = Breakdown.tick(state, now())
	if state.phase ~= before then
		if state.phase == "Rally" then
			openRally()
		elseif state.phase == "Lost" then
			lose()
			return
		end
		publish()
	end
	if state.phase == "Rally" then
		toast(true)
	end
	-- the trip is a distance: time stopped, and the limp's shortfall, are added to its clock
	local delay = Breakdown.delay(state, dt)
	if delay > 0 then
		Registry.RunDirector.ExtendPhase(delay)
	end
end

-- The share of its speed the train is running at (0 while broken down and stopped).
function BreakdownService.SpeedShare(): number
	return Breakdown.speedShare(state)
end

-- A new run: no breakdowns yet.
function BreakdownService.Reset()
	clearPrompts()
	toast(false)
	state = Breakdown.new()
	publish()
end

-- The train reached its stop: running normally again (the run's count stays).
function BreakdownService.Arrive()
	clearPrompts()
	toast(false)
	state = Breakdown.arrive(state)
	publish()
end

function BreakdownService.Init() end

function BreakdownService.Start()
	Registry.RunDirector.PhaseChanged:Connect(function(phase: string)
		if phase == "Boarding" or not RunRules.isRunPhase(phase :: any) then
			if phase ~= "RunEnd" then
				BreakdownService.Reset()
			else
				clearPrompts()
				toast(false)
			end
		elseif phase == "Arrival" then
			BreakdownService.Arrive()
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		Safe.call("BreakdownService.step", step, dt)
	end)
end

return BreakdownService
