--!strict
--[[
	Runs one station's hazard timeline from Logic/HazardSchedule:
	  * collapse telegraphs, then slab collapses
	  * Hollow spawn attempts at the fog front
	  * fog damage to anyone standing past the fog front (4 Hz)
	Departure freezes the timeline; the station leaving does the rest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local HazardSchedule = require(Shared.Logic.HazardSchedule)
local HollowBudget = require(Shared.Logic.HollowBudget)
local LayoutGen = require(Shared.Logic.LayoutGen)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local TimedEventDirector = require(script.Parent.Parent.Events.TimedEventDirector)
local StationService = require(script.Parent.StationService)

type Timeline = {
	plan: LayoutGen.Plan,
	info: Types.StationInfo,
	geo: HazardSchedule.Geometry,
	events: { HazardSchedule.CollapseEvent },
	warnIndex: number,
	collapseIndex: number,
	spawns: { number },
	spawnIndex: number,
	wandererAt: number,
	wandererSpawned: boolean,
	frozenAt: number?,
	lastDamage: number,
	rng: Random,
}

local HazardDirector = {}

local timeline: Timeline? = nil
local connection: RBXScriptConnection? = nil

local DAMAGE_TICK = 0.25

local function spawnAtFront(state: Timeline, t: number, extra: boolean?): Model?
	local params = state.info.hazards
	local fog = HazardSchedule.fogFront(params, state.geo, t)
	local lanes = state.plan.spawnLanes
	local lane = lanes[(state.spawnIndex - 1) % #lanes + 1] + state.rng:NextNumber(-8, 8)
	local z = math.clamp(fog + state.rng:NextNumber(4, 16), params.safeBand + 30, state.plan.depth - 4)
	local _, model = Registry.HollowService.TrySpawn(lane, z, nil, nil, extra)
	return model
end

local function damageInFog(state: Timeline, t: number)
	local params = state.info.hazards
	if params.fogDps <= 0 then
		return
	end
	local fog = HazardSchedule.fogFront(params, state.geo, t)
	for _, player in Registry.CrewService.AlivePlayers() do
		if not Registry.CrewService.IsAboard(player) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 and not Registry.DevService.IsGod(player) then
				local z = StationService.ToLocal(root.Position).Z
				if z > fog then
					(character :: Model):SetAttribute("LastDamageSource", "Fog")
					humanoid:TakeDamage(params.fogDps * DAMAGE_TICK)
					NetService.Fire("Fx", player, "FogTick", {})
				end
			end
		end
	end
end

local function step()
	local state = timeline
	if state == nil then
		return
	end
	local now = Workspace:GetServerTimeNow()
	local t = (state.frozenAt or now) - state.info.startedAt

	while state.events[state.warnIndex] and state.events[state.warnIndex].warnAt <= t do
		local event = state.events[state.warnIndex]
		StationService.TelegraphSlab(event.slab, state.info.startedAt + event.at)
		state.warnIndex += 1
	end
	while state.events[state.collapseIndex] and state.events[state.collapseIndex].at <= t do
		StationService.CollapseSlab(state.events[state.collapseIndex].slab)
		state.collapseIndex += 1
	end
	if state.frozenAt == nil then
		if not state.wandererSpawned and t >= state.wandererAt then
			-- Retry failed placement/cap checks, but never create a second wanderer.
			for _, lane in state.plan.spawnLanes do
				if Registry.HollowService.TrySpawn(lane, state.plan.depth / 2, nil, true) then
					state.wandererSpawned = true
					break
				end
			end
		end
		while state.spawns[state.spawnIndex] and state.spawns[state.spawnIndex] <= t do
			spawnAtFront(state, t)
			state.spawnIndex += 1
		end
	end
	if state.frozenAt == nil then
		TimedEventDirector.Step(t)
	end
	if os.clock() - state.lastDamage >= DAMAGE_TICK then
		state.lastDamage = os.clock()
		damageInFog(state, t)
	end
end

function HazardDirector.Init() end

function HazardDirector.Start()
	StationService.Cleared:Connect(HazardDirector.Stop)
	TimedEventDirector.Start()
end

-- One extra Hollow at a normal spawn point at the fog front, past the cap (a timed event's).
function HazardDirector.SpawnExtra(): Model?
	local state = timeline
	if state == nil or state.frozenAt then
		return nil
	end
	for _ = 1, 4 do
		local model = spawnAtFront(state, Workspace:GetServerTimeNow() - state.info.startedAt, true)
		state.spawnIndex += 1
		if model then
			return model
		end
	end
	return nil
end

function HazardDirector.Begin(plan: LayoutGen.Plan, info: Types.StationInfo)
	HazardDirector.Stop()
	if info.terminus then
		return
	end
	-- One budget for every Hollow at the stop, by the players in the run (Logic/HollowBudget).
	if info.hazards.hollowCap > 0 then
		local hazards = table.clone(info.hazards)
		hazards.hollowCap = HollowBudget.total(#Registry.CrewService.MemberPlayers())
		info.hazards = hazards
		Registry.StateService.Set({ "run", "station", "hazards" }, hazards)
	end
	local geo = { depth = plan.depth, safe = Tuning.World.SafeStrip }
	local refs: { HazardSchedule.SlabRef } = {}
	for _, slab in plan.slabs do
		table.insert(refs, { id = slab.id, z = slab.z, kind = slab.kind :: string })
	end
	timeline = {
		plan = plan,
		info = info,
		geo = geo,
		events = HazardSchedule.collapsePlan(info.hazards, geo, refs, info.layoutSeed),
		warnIndex = 1,
		collapseIndex = 1,
		spawns = HazardSchedule.spawnTimes(info.hazards, info.layoutSeed),
		spawnIndex = 1,
		wandererAt = Difficulty.WandererDelay[1]
			+ (Difficulty.WandererDelay[2] - Difficulty.WandererDelay[1]) * info.hazards.difficulty,
		wandererSpawned = false,
		frozenAt = nil,
		lastDamage = 0,
		rng = Random.new(info.layoutSeed % 2147483647),
	}
	Registry.HollowService.Configure(info.hazards)
	Registry.HollowService.Prepare(plan)
	TimedEventDirector.Begin(info)
	connection = RunService.Heartbeat:Connect(step)
end

function HazardDirector.Freeze()
	if timeline and timeline.frozenAt == nil then
		timeline.frozenAt = Workspace:GetServerTimeNow()
	end
	TimedEventDirector.Finish()
end

function HazardDirector.Stop()
	TimedEventDirector.Finish()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	timeline = nil
end

return HazardDirector
