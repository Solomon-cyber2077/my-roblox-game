--!strict
--[[
	The crew: who is on the run, where they are, and how they leave it.

	Status is derived ten times a second from each root part against the train's
	boarding volume (Aboard / Afield). Stragglers stay Stragglers until they board.
	Every elimination path ends in CrewService.Eliminate, which names the cause.

	Every character is a blocky R6 rig in the player's own avatar, built here from their
	HumanoidDescription. It has no default Animate script: every client animates it
	procedurally (CharacterAnimator), and its joints hold on death so a body falls as a
	body. Health comes back slowly, as it did with the default character scripts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Economy = require(Shared.Logic.Economy)
local Ledger = require(Shared.Logic.Ledger)
local RunRules = require(Shared.Logic.RunRules)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)

type CrewStatus = Types.CrewStatus
type Cause = Types.Cause

type Member = {
	player: Player,
	status: CrewStatus,
	cause: Cause?,
	rescued: boolean,
	load: number,
	tally: Types.CrewTally,
	clutchCounted: boolean,
}

local CrewService = {}

local members: { [Player]: Member } = {}
local pendingJoin: { [Player]: boolean } = {}
local downs = 0 -- eliminations this run, for the run log's per-stop haul
local missingAtLastCall: { [Player]: boolean } = {} -- not aboard when the whistle blew (T-0)
local spawnGeneration: { [Player]: number } = {}

local REGEN_SHARE = 0.01 -- of max health per second, as the default Health script gave
local descriptions: { [number]: HumanoidDescription } = {}

local CAUSE_TEXT: { [string]: string } = {
	LeftBehind = "was left behind",
	Taken = "was taken by a Hollow",
	Smothered = "was lost in the fog",
	Fell = "fell into the dark",
	Disconnected = "left the line",
}

local function isAliveStatus(status: CrewStatus): boolean
	return status == "Aboard" or status == "Afield" or status == "Straggler"
end

local function publish(member: Member)
	StateService.Set({ "crew", tostring(member.player.UserId) }, {
		name = member.player.DisplayName,
		status = member.status,
		cause = member.cause,
		rescued = member.rescued,
		load = member.load,
	})
end

local function unpublish(player: Player)
	StateService.Set({ "crew", tostring(player.UserId) }, nil)
end

local function onDied(player: Player, character: Model)
	local member = members[player]
	if member and isAliveStatus(member.status) and player.Character == character then
		local source = character:GetAttribute("LastDamageSource")
		CrewService.Eliminate(player, if source == "Fog" then "Smothered" else "Taken")
	elseif member == nil then
		task.delay(3, function()
			if player.Parent and members[player] == nil and player.Character == character then
				Registry.LobbyService.Spawn(player)
			end
		end)
	end
end

-- The player's own avatar (fetched once a server), or a plain crew member's for test players.
local function describe(player: Player): HumanoidDescription
	local cached = descriptions[player.UserId]
	if cached then
		return cached:Clone()
	end
	local description: HumanoidDescription? = nil
	if player.UserId > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			description = result
		end
	end
	if description == nil then
		local plain = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(226, 178, 140)
		plain.HeadColor = skin
		plain.LeftArmColor = skin
		plain.RightArmColor = skin
		plain.TorsoColor = Color3.fromRGB(58, 66, 82)
		plain.LeftLegColor = Color3.fromRGB(46, 42, 40)
		plain.RightLegColor = Color3.fromRGB(46, 42, 40)
		description = plain
	end
	local final = description :: HumanoidDescription
	descriptions[player.UserId] = final
	return final:Clone()
end

-- A blocky R6 body in the player's avatar, ready for CharacterAnimator, or nil if it failed.
local function buildR6(player: Player): Model?
	local ok, result = pcall(function()
		local description = describe(player)
		-- Preserve clothes, colours and accessories; package meshes can make an R6 rig
		-- non-blocky and invalidate the hands/feet assumed by the procedural poses.
		for _, property in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			(description :: any)[property] = 0
		end
		local body = Players:CreateHumanoidModelFromDescription(
			description,
			Enum.HumanoidRigType.R6,
			Enum.AssetTypeVerification.Always
		)
		description:Destroy()
		return body
	end)
	if not ok or result == nil then
		warn(`[Crew] could not build an R6 body for {player.Name}: {result}`)
		return nil
	end
	local model = result :: Model
	model.Name = player.Name
	-- every client animates it (CharacterAnimator); the default animations would fight that
	for _, descendant in model:GetDescendants() do
		if descendant.Name == "Animate" and (descendant:IsA("LocalScript") or descendant:IsA("Script")) then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = player.DisplayName
		humanoid.BreakJointsOnDeath = false
	end
	model:SetAttribute("Procedural", true)
	return model
end

-- Loads a fresh character at `cframe`. Yields until the character exists.
function CrewService.LoadCharacterAt(player: Player, cframe: CFrame)
	if player.Parent == nil then
		return
	end
	local generation = (spawnGeneration[player] or 0) + 1
	spawnGeneration[player] = generation
	pcall(function()
		player:RequestStreamAroundAsync(cframe.Position, 5)
	end)
	local body = buildR6(player)
	if spawnGeneration[player] ~= generation or not player:IsDescendantOf(Players) then
		if body then
			body:Destroy()
		end
		return -- a newer spawn request superseded this one
	end
	if body then
		local old = player.Character
		body:PivotTo(cframe)
		player.Character = body
		body.Parent = Workspace
		if old and old ~= body then
			old:Destroy()
		end
		local bodyRoot = body:FindFirstChild("HumanoidRootPart") :: BasePart?
		if bodyRoot then
			pcall(function()
				bodyRoot:SetNetworkOwner(player)
			end)
		end
	else
		player:LoadCharacterAsync()
	end
	if spawnGeneration[player] ~= generation then
		return
	end
	local character = player.Character
	if character == nil then
		return
	end
	WorldService.TagCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	character:WaitForChild("HumanoidRootPart", 5)
	character:PivotTo(cframe)
	if humanoid then
		humanoid.MaxHealth = Tuning.Crew.MaxHealth
		humanoid.Health = Tuning.Crew.MaxHealth
		humanoid.Died:Connect(function()
			onDied(player, character)
		end)
	end
	Registry.CosmeticService.Apply(player)
end

local function positionTick()
	local phase: Types.Phase = Registry.RunDirector.Phase()
	if not RunRules.isRunPhase(phase) or phase == "Boarding" then
		return
	end
	local departureEndsAt = if phase == "Departure" then Registry.RunDirector.PhaseEndsAt() else nil
	for player, member in members do
		if isAliveStatus(member.status) then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local position = root.Position
				if
					position.Y < Tuning.World.FloorY - Tuning.Crew.FallDepth
					and not Registry.DevService.IsGod(player)
				then
					CrewService.Eliminate(player, "Fell")
				else
					local inside = Registry.TrainService.IsInside(position)
					local nextStatus: CrewStatus = if inside
						then "Aboard"
						elseif member.status == "Straggler" then "Straggler"
						else "Afield"
					if nextStatus ~= member.status then
						if nextStatus == "Aboard" and departureEndsAt and not member.clutchCounted then
							local remaining = departureEndsAt - Workspace:GetServerTimeNow()
							if remaining <= Tuning.Crew.ClutchBoardSeconds then
								member.clutchCounted = true
								member.tally.clutchBoards += 1
								NetService.FireAll("Fx", "Clutch", { userId = player.UserId })
								NetService.FireAll(
									"Notify",
									"Crew",
									`{player.DisplayName} made it with {string.format(
										"%.1f",
										math.max(remaining, 0)
									)}s to spare!`
								)
							end
						end
						member.status = nextStatus
						publish(member)
					end
					if inside then
						Registry.InventoryService.DepositCargo(player)
					end
				end
			end
		end
	end
end

function CrewService.Init() end

function CrewService.Start()
	NetService.Handle("JoinInProgress", function(player)
		CrewService.RequestJoin(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingJoin[player] = nil
		spawnGeneration[player] = nil
		local member = members[player]
		if member then
			if isAliveStatus(member.status) then
				NetService.FireAll("Notify", "Crew", `{player.DisplayName} {CAUSE_TEXT.Disconnected}.`)
			end
			members[player] = nil
			unpublish(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1 / Tuning.Crew.PositionTickHz)
			Safe.call("CrewService.positionTick", positionTick)
		end
	end)
	-- health creeps back, a point a second, except in a Hollow's hands
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if
					humanoid
					and humanoid.Health > 0
					and humanoid.Health < humanoid.MaxHealth
					and not Registry.HollowService.IsHeld(player)
				then
					humanoid.Health =
						math.min(humanoid.MaxHealth, humanoid.Health + humanoid.MaxHealth * REGEN_SHARE)
				end
			end
		end
	end)
end

function CrewService.IsMember(player: Player): boolean
	return members[player] ~= nil
end

function CrewService.IsAlive(player: Player): boolean
	local member = members[player]
	return member ~= nil and isAliveStatus(member.status)
end

function CrewService.IsAboard(player: Player): boolean
	local member = members[player]
	return member ~= nil and member.status == "Aboard"
end

function CrewService.Status(player: Player): CrewStatus
	local member = members[player]
	return if member then member.status else "Lobby"
end

function CrewService.AliveCount(): number
	local count = 0
	for _, member in members do
		if isAliveStatus(member.status) then
			count += 1
		end
	end
	return count
end

function CrewService.AlivePlayers(): { Player }
	local out: { Player } = {}
	for player, member in members do
		if isAliveStatus(member.status) then
			table.insert(out, player)
		end
	end
	return out
end

function CrewService.MemberPlayers(): { Player }
	local out: { Player } = {}
	for player in members do
		table.insert(out, player)
	end
	return out
end

function CrewService.SetLoad(player: Player, load: number)
	local member = members[player]
	if member and member.load ~= load then
		member.load = load
		publish(member)
	end
end

function CrewService.RecordDeposit(player: Player, receipt: Ledger.Receipt)
	local member = members[player]
	if member == nil then
		return
	end
	member.tally.coalDelivered += receipt.coal
	member.tally.partsDelivered += receipt.parts
	member.tally.relicBrass += receipt.relicBrass
	member.tally.relicsBanked += receipt.relics
	StateService.Update({ "stats" }, function(stats)
		local s = stats or { coalDelivered = 0, partsDelivered = 0, relics = 0, stationsCleared = 0 }
		s.coalDelivered += receipt.coal
		s.partsDelivered += receipt.parts
		s.relics += receipt.relics
		return s
	end)
end

function CrewService.BeginRun(players: { Player })
	downs = 0
	table.clear(members)
	table.clear(pendingJoin)
	for i, player in players do
		local member: Member = {
			player = player,
			status = "Aboard",
			cause = nil,
			rescued = false,
			load = 0,
			tally = Economy.emptyTally(),
			clutchCounted = false,
		}
		members[player] = member
		publish(member)
		Registry.InventoryService.Reset(player)
		task.spawn(CrewService.LoadCharacterAt, player, Registry.TrainService.SpawnPoint(i))
	end
end

-- Sends every crew member back to the Depot Hall and forgets the run.
function CrewService.EndRun()
	local former = CrewService.MemberPlayers()
	for _, player in former do
		unpublish(player)
		Registry.InventoryService.Clear(player)
	end
	table.clear(members)
	table.clear(pendingJoin)
	StateService.Set({ "crew" }, {})
	for _, player in former do
		if player.Parent then
			task.spawn(Registry.LobbyService.Spawn, player)
		end
	end
end

function CrewService.Eliminate(player: Player, cause: Cause)
	local member = members[player]
	if member == nil or not isAliveStatus(member.status) then
		return
	end
	member.status = "Eliminated"
	member.cause = cause
	downs += 1
	member.load = 0
	publish(member)
	print(`[Crew] {player.Name} eliminated: {cause} at stop {Registry.RunDirector.NextStop()}`)
	Registry.InventoryService.Clear(player)
	NetService.Fire("Fx", player, "Eliminated", { cause = cause, canRescue = not member.rescued })
	NetService.FireAll("Notify", "Elimination", `{player.DisplayName} {CAUSE_TEXT[cause]}.`)

	local character = player.Character
	local generation = spawnGeneration[player]
	task.delay(if cause == "LeftBehind" then 2.5 else 3, function()
		if
			spawnGeneration[player] == generation
			and member.status == "Eliminated"
			and player.Character == character
			and character
		then
			character:Destroy()
		end
	end)
end

-- T-0, the Last Call whistle: remembers who is not aboard yet, for close calls.
function CrewService.MarkLastCall()
	table.clear(missingAtLastCall)
	for player, member in members do
		if isAliveStatus(member.status) and member.status ~= "Aboard" then
			missingAtLastCall[player] = true
		end
	end
end

-- Called when the chase window closes: anyone not aboard stays behind. Returns the display names
-- of this stop's close calls, for the run log.
function CrewService.ResolveDeparture(): { string }
	local aboard: { [Player]: boolean } = {}
	for player, member in members do
		aboard[player] = member.status == "Aboard"
	end
	local names: { string } = {}
	for _, player in RunRules.closeCalls(missingAtLastCall, aboard) do
		members[player].tally.closeCalls += 1
		table.insert(names, player.DisplayName)
		print(`[Crew] {player.Name} close call at stop {Registry.RunDirector.NextStop()}`)
	end
	table.clear(missingAtLastCall)
	for player, member in members do
		if isAliveStatus(member.status) then
			if member.status == "Aboard" then
				member.tally.stationsDeparted += 1
			elseif Registry.DevService.IsGod(player) then
				task.spawn(CrewService.LoadCharacterAt, player, Registry.TrainService.SpawnPoint(1))
			else
				CrewService.Eliminate(player, "LeftBehind")
			end
		end
		member.clutchCounted = false
	end
	return names
end

function CrewService.Downs(): number
	return downs
end

function CrewService.RescuableCount(): number
	local count = 0
	for player, member in members do
		if
			member.status == "Eliminated"
			and not member.rescued
			and member.cause ~= "Disconnected"
			and player.Parent
		then
			count += 1
		end
	end
	return count
end

-- Fires the rescue: every rescuable crew member returns as a Straggler.
function CrewService.Rescue(by: Player): number
	local count = 0
	for player, member in members do
		if
			member.status == "Eliminated"
			and not member.rescued
			and member.cause ~= "Disconnected"
			and player.Parent
		then
			member.rescued = true
			member.status = "Straggler"
			member.cause = nil
			publish(member)
			Registry.InventoryService.Reset(player)
			NetService.Fire("Fx", player, "Rescued", { by = by.UserId })
			task.spawn(CrewService.LoadCharacterAt, player, Registry.StationService.StragglerSpawn())
			count += 1
		end
	end
	local rescuer = members[by]
	if count > 0 and rescuer then
		rescuer.tally.rescues += 1
		NetService.FireAll(
			"Notify",
			"Rescue",
			`{by.DisplayName} fired a flare. {count} crew coming home. Run to the train!`
		)
	end
	return count
end

function CrewService.RequestJoin(player: Player)
	if members[player] or pendingJoin[player] then
		return
	end
	local phase = Registry.RunDirector.Phase()
	if
		not RunRules.isRunPhase(phase)
		or Registry.RunDirector.NextStop() > Tuning.Run.JoinInProgressMaxStation
	then
		NetService.Fire(
			"Notify",
			player,
			"Warning",
			"This run is too far down the line to join. Wait for the next departure."
		)
		return
	end
	pendingJoin[player] = true
	NetService.Fire(
		"Notify",
		player,
		"Info",
		"You will join the crew at the next station. Run for the train when you arrive!"
	)
	if phase == "Dwell" then
		CrewService.SpawnPendingJoiners()
	end
end

function CrewService.SpawnPendingJoiners()
	for player in pendingJoin do
		pendingJoin[player] = nil
		if player.Parent and members[player] == nil then
			local member: Member = {
				player = player,
				status = "Straggler",
				cause = nil,
				rescued = false,
				load = 0,
				tally = Economy.emptyTally(),
				clutchCounted = false,
			}
			members[player] = member
			publish(member)
			Registry.InventoryService.Reset(player)
			task.spawn(CrewService.LoadCharacterAt, player, Registry.StationService.StragglerSpawn())
			NetService.FireAll("Notify", "Crew", `{player.DisplayName} is running for the train!`)
		end
	end
end

function CrewService.MarkTerminus()
	for _, member in members do
		if isAliveStatus(member.status) then
			member.tally.reachedTerminus = true
		end
	end
end

function CrewService.Tallies(): { [Player]: Types.CrewTally }
	local out: { [Player]: Types.CrewTally } = {}
	for player, member in members do
		if player.Parent then
			out[player] = table.clone(member.tally)
		end
	end
	return out
end

return CrewService
