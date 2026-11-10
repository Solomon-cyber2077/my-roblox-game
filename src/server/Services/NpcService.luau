--!strict
--[[
	The train's residents: builds each enabled NPC (Config/Npcs) at its post with a Talk
	prompt, runs their crew errands and says their lines.

	Who owns what:
	  saved   each player's own story per NPC, in profile.npcs (Logic/NpcSave), changed only
	          through DataService.Update; never blocks on a DataStore
	  run     one errand per NPC, shared by the crew (Logic/NpcQuest has the co-op rules)
	  lines   Config/NpcDialogue, picked by Logic/NpcDialogue
	The tracker is the private `quests` list (Types.QuestEntry); lines reach the speaker
	through the Dialogue remote. Errand Brass is paid on the run summary (TakeErrands).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Npcs = require(Shared.Config.Npcs)
local Quests = require(Shared.Config.NpcQuests)
local Tuning = require(Shared.Config.Tuning)
local NpcDialogue = require(Shared.Logic.NpcDialogue)
local NpcQuest = require(Shared.Logic.NpcQuest)
local NpcSave = require(Shared.Logic.NpcSave)
local ResidentWalk = require(Shared.Logic.ResidentWalk)
local RunRules = require(Shared.Logic.RunRules)
local Rng = require(Shared.Util.Rng)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)
local NpcFigure = require(script.Parent.Parent.Builders.NpcFigure)
local StationBuilder = require(script.Parent.Parent.Builders.StationBuilder)

local NpcService = {}

local T = Tuning.Npc

local runQuests: { [string]: NpcQuest.RunQuest } = {}
local startStages: { [Player]: { [string]: number } } = {} -- each player's stage when the run began
local heard: { [Player]: { [string]: boolean } } = {} -- lines said to the player this run
local talks: { [Player]: { [string]: number } } = {}
local lastTalk: { [Player]: { [string]: number } } = {}

local function progress(profile: Types.Profile, npcId: string): Types.NpcProgress
	local entry = profile.npcs[npcId]
	if entry == nil then
		entry = NpcSave.defaultProgress()
		profile.npcs[npcId] = entry
	end
	return entry
end

local function stageOf(player: Player, npcId: string): number?
	local profile = DataService.GetProfile(player)
	return if profile then progress(profile, npcId).stage else nil
end

local function phase(): string
	return Registry.RunDirector.Phase()
end

local function inRun(player: Player): boolean
	return RunRules.isRunPhase(phase() :: any) and Registry.CrewService.IsMember(player)
end

-- The tracker: every crew member sees the run's errands (through the run summary); anyone else none.
local function publish(player: Player)
	local entries: { Types.QuestEntry } = {}
	if inRun(player) or (phase() == "RunEnd" and Registry.CrewService.IsMember(player)) then
		for _, npcId in Npcs.Order do
			local rq = runQuests[npcId]
			if rq then
				table.insert(entries, {
					npc = npcId,
					name = Npcs.List[npcId].name,
					title = Quests[rq.quest].title,
					text = NpcQuest.trackerText(rq),
					status = rq.status :: string,
					helper = ((startStages[player] or {})[npcId] or stageOf(player, npcId)) ~= rq.stage,
				})
			end
		end
	end
	StateService.SetPrivate(player, { "quests" }, entries)
end

local function publishAll()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

local function notifyCrew(text: string)
	NetService.FireList("Notify", Registry.CrewService.MemberPlayers(), "Crew", text)
end

-- Finishing an errand credits everyone still in the run; players at its stage move on.
local function complete(rq: NpcQuest.RunQuest)
	if rq.status == "Done" then
		return
	end
	NpcQuest.complete(rq)
	local def = Npcs.List[rq.npc]
	local quest = Quests[rq.quest]
	for _, player in Registry.CrewService.AlivePlayers() do
		local stage = stageOf(player, rq.npc)
		if stage then
			local credit = NpcQuest.credit(rq, stage)
			if credit.advance then
				DataService.Update(player, function(profile)
					local entry = progress(profile, rq.npc)
					entry.done[quest.id] = true
					entry.stage += 1
					entry.failed = nil
					if entry.stage > #def.chain and def.cosmetic then
						profile.owned[def.cosmetic] = true
					end
				end)
				if credit.story then
					NetService.Fire("Notify", player, "Info", credit.story)
				end
			else
				NetService.Fire("Notify", player, "Info", `Lent {def.name} a hand.`)
			end
		end
	end
	notifyCrew(`Errand done for {def.name}: {quest.title}.`)
	publishAll()
end

local function startRun()
	table.clear(runQuests)
	table.clear(heard)
	table.clear(startStages)
	local crew = Registry.CrewService.MemberPlayers()
	for _, npcId in Npcs.Order do
		if Npcs.List[npcId].enabled then
			local stages: { number } = {}
			for _, player in crew do
				local profile = DataService.WaitForProfile(player, 10)
				if profile then
					local stage = progress(profile, npcId).stage
					table.insert(stages, stage)
					startStages[player] = startStages[player] or {}
					startStages[player][npcId] = stage
				end
			end
			local rq = NpcQuest.start(npcId, stages)
			if rq then
				runQuests[npcId] = rq
			end
		end
	end
	publishAll()
end

-- Hides a Find errand's item beside one of the docked station's ground containers.
local function hideItems()
	local built: StationBuilder.Built? = Registry.StationService.Built()
	local stop = Registry.RunDirector.NextStop()
	if built == nil then
		return
	end
	for npcId, rq in runQuests do
		if NpcQuest.shouldSpawn(rq, stop) then
			local far: { StationBuilder.ContainerHandle }, any: { StationBuilder.ContainerHandle } = {}, {}
			for _, handle in built.containers do
				if handle.def.y == nil and handle.def.zone ~= "Safe" then
					table.insert(any, handle)
					if handle.def.zone == "Far" then
						table.insert(far, handle)
					end
				end
			end
			local pool = if #far > 0 then far else any
			if #pool > 0 then
				table.sort(
					pool,
					function(a: StationBuilder.ContainerHandle, b: StationBuilder.ContainerHandle)
						return a.def.id < b.def.id
					end
				)
				local seed = (StateService.Get({ "run", "seed" }) :: number?) or 0
				local rng = Rng.new(Rng.derive(seed, "npc", npcId, stop))
				local handle: StationBuilder.ContainerHandle = rng:pick(pool)
				local angle = rng:range(0, math.pi * 2)
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * T.ItemOffset
				Registry.LootService.DropAt(
					Quests[rq.quest].item :: string,
					handle.promptPart.Position + offset
				)
			end
		end
	end
end

local function endRun()
	for npcId, rq in runQuests do
		if rq.status ~= "Done" then
			NpcQuest.finish(rq)
			for _, player in Registry.CrewService.MemberPlayers() do
				if stageOf(player, npcId) == rq.stage then
					DataService.Update(player, function(profile)
						progress(profile, npcId).failed = rq.quest
					end)
				end
			end
		end
	end
	publishAll()
end

local function onPhase(nextPhase: string)
	if nextPhase == "Boarding" then
		task.spawn(Safe.call, "NpcService.startRun", startRun)
	elseif nextPhase == "Dwell" then
		Safe.call("NpcService.hideItems", hideItems)
	elseif nextPhase == "RunEnd" then
		-- the last stop departed: errands that ride the whole line are done
		if StateService.Get({ "run", "outcome" }) == "Victory" then
			for _, rq in runQuests do
				if NpcQuest.completesAtLineEnd(rq) then
					complete(rq)
				end
			end
		end
		endRun()
	elseif nextPhase == "Lobby" then
		table.clear(runQuests)
		table.clear(heard)
		publishAll()
	end
end

-- Someone in the crew carrying a Find errand's item changes the tracker line.
local function scan()
	for _, rq in runQuests do
		local item = Quests[rq.quest].item
		if item and rq.status == "Active" then
			local found = false
			for _, player in Registry.CrewService.MemberPlayers() do
				if Registry.InventoryService.Has(player, item) then
					found = true
					break
				end
			end
			if found ~= rq.found then
				rq.found = found
				publishAll()
			end
		end
	end
end

local function flags(player: Player): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if not inRun(player) then
		return out
	end
	local current = phase()
	out.Danger = current == "LastCall" or current == "Departure"
	local train = Registry.TrainService.Get()
	out.LowSupplies = train.coal < train.coalMax * T.LowCoalFraction
	for _, member in Registry.CrewService.MemberPlayers() do
		local status = Registry.CrewService.Status(member)
		if status == "Eliminated" or status == "Straggler" then
			out.CrewDown = true
		end
	end
	local tally = Registry.CrewService.Tallies()[player]
	out.CloseCall = tally ~= nil and tally.closeCalls > 0
	out.NearEnd = Registry.RunDirector.NextStop() >= Registry.RunDirector.StopCount()
	return out
end

local function talk(player: Player, npcId: string)
	local def = Npcs.List[npcId]
	local profile = DataService.GetProfile(player)
	if profile == nil then
		return
	end
	local now = os.clock()
	local last = lastTalk[player] or {}
	lastTalk[player] = last
	if now - (last[npcId] or -math.huge) < T.TalkCooldown then
		return
	end
	last[npcId] = now

	local entry = progress(profile, npcId)
	local running = inRun(player)
	local rq = if running then runQuests[npcId] else nil
	if rq then
		local item = Quests[rq.quest].item
		if item and NpcQuest.canDeliver(rq, Registry.InventoryService.Has(player, item)) then
			Registry.InventoryService.Consume(player, item)
			complete(rq)
		end
	end

	local heardNow = heard[player] or {}
	heard[player] = heardNow
	local counts = talks[player] or {}
	talks[player] = counts
	local line = NpcDialogue.pick(def.lines, {
		inRun = running,
		travelling = running and RunRules.isTravel(phase() :: any),
		status = if rq then rq.status else nil,
		quest = if rq then rq.quest else nil,
		stage = entry.stage,
		failed = entry.failed ~= nil,
		flags = flags(player),
		choices = entry.choices,
		seen = entry.seen,
		heardThisRun = heardNow,
		talks = counts[npcId] or 0,
	})
	if line == nil then
		return
	end
	heardNow[line.id] = true
	counts[npcId] = (counts[npcId] or 0) + 1
	if rq and rq.status == "Offered" then
		NpcQuest.accept(rq)
		publishAll()
	end
	if not entry.seen[line.id] or (line.topic == "QuestFailed" and entry.failed) then
		DataService.Update(player, function(p)
			local e = progress(p, npcId)
			e.seen[line.id] = true
			if line.topic == "QuestFailed" then
				e.failed = nil
			end
		end)
	end
	NetService.Fire("Dialogue", player, { npc = npcId, name = def.name, role = def.role, text = line.text })
end

-- A resident with a `walk` strolls her spots (Logic/ResidentWalk) once her R6 rig is dressed. The
-- whole figure moves as one anchored model, with nothing on it colliding; the rig's root carries
-- the walking velocity so every client's CharacterAnimator steps her legs. A Hand within
-- `pauseRadius` stops her where she is, so she can always be caught for a word.
local function walker(def: Npcs.NpcDef, model: Model, origin: CFrame)
	local walk = def.walk :: Npcs.Walk
	local rig: Instance? = nil
	for _ = 1, 60 do
		rig = model:FindFirstChild("Rig")
		if rig or not model.Parent then
			break
		end
		task.wait(0.5)
	end
	local root = if rig then rig:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		return -- the kit figure cannot step its legs: it keeps to its post
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
		end
	end
	local spots = walk.spots
	local random = Random.new()
	local x, z, yaw = spots[1].x, spots[1].z, math.rad(spots[1].yaw)
	local placed = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function place(vx: number, vz: number)
		local target = origin * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
		model:PivotTo(target * placed:Inverse() * model:GetPivot())
		placed = target
		root.AssemblyLinearVelocity = origin:VectorToWorldSpace(Vector3.new(vx, 0, vz))
	end
	local function handNear(): boolean
		local here = placed.Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and hrp:IsA("BasePart") and (hrp.Position - here).Magnitude < walk.pauseRadius then
				return true
			end
		end
		return false
	end
	local function turnTo(target: number)
		local from = yaw
		local delta = (target - from + math.pi) % (2 * math.pi) - math.pi
		local t = 0
		while t < walk.turnSeconds and model.Parent do
			t += RunService.Heartbeat:Wait()
			yaw = from + delta * math.min(t / walk.turnSeconds, 1)
			place(0, 0)
		end
	end
	local current = 1
	while model.Parent do
		task.wait(random:NextNumber(walk.idle[1], walk.idle[2]))
		if model.Parent and not handNear() then
			local to = ResidentWalk.nextSpot(walk, current, random:NextNumber())
			for _, i in ResidentWalk.route(current, to) do
				local spot = spots[i]
				turnTo(math.atan2(-(spot.x - x), -(spot.z - z))) -- yaw 0 faces -Z
				local arrived = false
				while not arrived and model.Parent do
					if handNear() then
						place(0, 0)
						repeat
							task.wait(0.5)
						until not model.Parent or not handNear()
					end
					local dt = RunService.Heartbeat:Wait()
					local nx, nz
					nx, nz, arrived = ResidentWalk.step(x, z, spot.x, spot.z, walk.speed, dt)
					local vx, vz = (nx - x) / dt, (nz - z) / dt
					x, z = nx, nz
					place(if arrived then 0 else vx, if arrived then 0 else vz)
				end
				current = i
			end
			turnTo(math.rad(spots[current].yaw))
		end
	end
end

function NpcService.Init()
	local origin = Registry.TrainService.Origin()
	local folder = Instance.new("Folder")
	folder.Name = "Residents"
	folder.Parent = Workspace
	for _, npcId in Npcs.Order do
		local def = Npcs.List[npcId]
		local post = def.post
		if def.enabled and post then
			local cframe = origin * CFrame.new(post.x, 0, post.z) * CFrame.Angles(0, math.rad(post.yaw), 0)
			local figure = NpcFigure.build(def, cframe, folder)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Talk"
			prompt.ObjectText = `{def.name}, {def.role}`
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = T.PromptDistance
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("Action", "Talk")
			prompt.Parent = figure.body
			prompt.Triggered:Connect(function(player)
				Safe.call("NpcService.talk", talk, player, npcId)
			end)
			if def.walk then
				task.spawn(Safe.call, "NpcService.walk", walker, def, figure.model, origin)
			end
		end
	end
end

function NpcService.Start()
	Registry.RunDirector.PhaseChanged:Connect(onPhase)
	DataService.ProfileLoaded:Connect(function(player)
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		startStages[player] = nil
		heard[player] = nil
		talks[player] = nil
		lastTalk[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(T.ScanSeconds)
			Safe.call("NpcService.scan", scan)
		end
	end)
end

-- Studio developer console (DevService `npcreset`): wipes a player's story with one NPC, or
-- all of them. Refuses outside Studio even if called, so a live server can never reset a save.
function NpcService.DevReset(player: Player, npcId: string?): boolean
	if not RunService:IsStudio() then
		return false
	end
	if npcId and Npcs.List[npcId] == nil then
		return false
	end
	DataService.Update(player, function(profile)
		if npcId then
			profile.npcs[npcId] = NpcSave.defaultProgress()
		else
			profile.npcs = NpcSave.defaults()
		end
	end)
	heard[player] = nil
	talks[player] = nil
	publish(player)
	return true
end

return NpcService
