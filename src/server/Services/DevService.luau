--!strict
--[[
	Studio-only developer console. In a live server this service does nothing
	and the Dev remote does not exist.

	From the client command bar:
	  game.ReplicatedStorage.Remotes.Dev:FireServer("skip")
	Commands:
	  skip                 end the current phase now
	  warp <seconds>       move the station clock forward (hazards and timer)
	  god                  toggle: no damage, no falling, never left behind
	  search               search the nearest unsearched container
	  tp train|edge|mid|far  move to the train or a station zone
	  give <itemId>        put an item in your backpack
	  hollow [kind]        spawn a Hollow near you (Stalker, Crawler or Brute)
	  grab [kind]          a Hollow seizes you at once (a station must be docked)
	  coal <n> / parts <n> set train stores
	  state                print run, crew, train and backpack to the output
	  sky <hour> | sky     pin every client's sky to an hour (26 is two in the morning), or free it
	  omen <kind>          every client sees an omen now: Hush, TallOnes, Blink, Bleed or Eye
	  strike               a lightning strike now

	The sky commands set attributes on ReplicatedStorage that AtmosphereController reads in
	Studio only (DevSkyHour, DevOmen, DevStrike).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local DevService = {}

local function root(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function teleport(player: Player, cframe: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
	end
end

local Commands: { [string]: (Player, { string }) -> () } = {}

Commands.skip = function()
	Registry.RunDirector.ForceAdvance()
end

Commands.warp = function(_, args)
	Registry.RunDirector.DevWarp(tonumber(args[1]) or 10)
end

Commands.god = function(player)
	local on = not player:GetAttribute("DevGod")
	player:SetAttribute("DevGod", on)
	print(`[Dev] god mode {if on then "on" else "off"} for {player.Name}`)
end

Commands.search = function(player)
	local ok = Registry.LootService.DevSearchNearest(player)
	print(`[Dev] search nearest: {ok}`)
end

Commands.tp = function(player, args)
	local where = args[1] or "train"
	if where == "train" then
		teleport(player, Registry.TrainService.SpawnPoint(1))
		return
	end
	local info = Registry.StationService.Info()
	if info == nil then
		print("[Dev] no station")
		return
	end
	local depth = if where == "edge"
		then 12
		elseif where == "mid" then info.depth * 0.55
		else info.depth * 0.85
	local position = Registry.StationService.ToWorld(0, 4, depth)
	teleport(player, CFrame.new(position))
end

Commands.give = function(player, args)
	local itemId = args[1]
	if itemId and Items[itemId] then
		local leftovers = Registry.InventoryService.Give(player, { itemId })
		print(`[Dev] give {itemId}: {if #leftovers == 0 then "ok" else "backpack full"}`)
	else
		print(`[Dev] unknown item {itemId}`)
	end
end

Commands.hollow = function(player, args)
	local r = root(player)
	if r then
		local localPos = Registry.StationService.ToLocal(r.Position)
		local spawned = Registry.HollowService.TrySpawn(localPos.X + 10, localPos.Z + 30, args[1])
		print(`[Dev] hollow spawned: {spawned}`)
	end
end

Commands.grab = function(player, args)
	print(`[Dev] grab: {Registry.HollowService.DevGrab(player, args[1])}`)
end

Commands.coal = function(_, args)
	Registry.TrainService.DevSet("coal", tonumber(args[1]) or 50)
end

Commands.parts = function(_, args)
	Registry.TrainService.DevSet("parts", tonumber(args[1]) or 20)
end

Commands.state = function(player)
	local run = StateService.Get({ "run" }) or {}
	print(
		`[Dev] phase={run.phase} nextStop={run.nextStop} cleared={run.stationsCleared} endsIn={string.format(
			"%.1f",
			(run.phaseEndsAt or 0) - workspace:GetServerTimeNow()
		)}`
	)
	for key, entry in StateService.Get({ "crew" }) or {} do
		print(`[Dev] crew {key} {entry.name} {entry.status} cause={entry.cause} load={entry.load}`)
	end
	local train = StateService.Get({ "train" }) or {}
	print(`[Dev] train coal={train.coal}/{train.coalMax} parts={train.parts} hull={train.integrity}`)
	local inv = Registry.InventoryService.Get(player)
	print(`[Dev] backpack {table.concat(inv.items, ", ")} ({#inv.items} items, capacity {inv.capacity})`)
	local r = root(player)
	if r then
		local localPos = Registry.StationService.ToLocal(r.Position)
		print(
			`[Dev] position {r.Position} stationLocal={localPos} hollows={Registry.HollowService.Count()} safeStrip={Tuning.World.SafeStrip}`
		)
	end
end

Commands.sky = function(_, args)
	local hour = tonumber(args[1])
	ReplicatedStorage:SetAttribute("DevSkyHour", hour)
	print(`[Dev] sky {if hour then `pinned at {hour}` else "follows the run"}`)
end

Commands.omen = function(_, args)
	local kind = args[1] or "Blink"
	for _, spec in Tuning.Sky.Omens do
		if spec.kind == kind then
			ReplicatedStorage:SetAttribute("DevOmen", `{kind}@{workspace:GetServerTimeNow() + 0.5}`)
			print(`[Dev] omen {kind}`)
			return
		end
	end
	print(`[Dev] unknown omen {kind}`)
end

Commands.strike = function()
	ReplicatedStorage:SetAttribute("DevStrike", workspace:GetServerTimeNow() + 0.2)
end

function DevService.IsGod(player: Player): boolean
	return RunService:IsStudio() and player:GetAttribute("DevGod") == true
end

function DevService.Init()
	if not RunService:IsStudio() then
		return
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Dev"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	remote.OnServerEvent:Connect(function(player, line)
		if type(line) ~= "string" then
			return
		end
		local words = string.split(line, " ")
		local name = table.remove(words, 1) or ""
		local command = Commands[name]
		if command then
			local ok, err = (pcall :: any)(command, player, words)
			if not ok then
				warn(`[Dev] {name} failed: {err}`)
			end
		else
			print(`[Dev] unknown command {name}`)
		end
	end)
	print("[Dev] Studio developer console ready: Remotes.Dev:FireServer('state')")
end

function DevService.Start()
	if RunService:IsStudio() then
		Players.PlayerAdded:Connect(function(player)
			player:SetAttribute("DevGod", false)
		end)
	end
end

return DevService
