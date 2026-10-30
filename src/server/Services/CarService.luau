--!strict
--[[
	Boarding cars: every carriage of the Depot Hall's display train with a side door
	is a party room for 2-4 players. Hold E (tap on touch) at the door to board or to
	get out; rules in Logic/CarBoarding. A full car, or one whose countdown runs out,
	goes black and teleports its players to a reserved server, where the run starts
	at once. In Studio, where teleports fail, the run starts here instead.
	Solo players keep the hall's Ready button (LobbyService).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local CarBoarding = require(Shared.Logic.CarBoarding)
local CrewQueue = require(Shared.Logic.CrewQueue)
local Safe = require(Shared.Util.Safe)

local LobbyService = require(script.Parent.LobbyService)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local CarService = {}

type Car = {
	players: { Player },
	startedAt: number?,
	departing: boolean,
	since: number?, -- unix seconds the first rider boarded (the crew queue's order, MatchmakingService)
	generation: number, -- bumped each time the car empties: a fresh queue ticket per crew
	inside: CFrame, -- on the aisle at standing height, facing the door
	outside: CFrame, -- on the platform before the door, facing away from it
}

local cars: { Car } = {}
local aboard: { [Player]: number } = {}

-- A car under its own server: the reserved server a car teleported to.
local IS_CAR_SERVER = game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rules(car: Car): CarBoarding.Car
	return { count = #car.players, startedAt = car.startedAt, departing = car.departing }
end

local function publish()
	local out = {}
	for i, car in cars do
		local occupants = {}
		for _, player in car.players do
			table.insert(occupants, tostring(player.UserId))
		end
		out[i] = { occupants = occupants, startedAt = car.startedAt, departing = car.departing }
	end
	StateService.Set({ "lobby", "cars" }, out)
end

local function place(player: Player, cframe: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(cframe)
	end
end

local function slot(car: Car, index: number): CFrame
	local spread = (index - (Tuning.Cars.MaxPlayers + 1) / 2) * 2.2
	return car.inside * CFrame.new(spread, 0, 0)
end

local function remove(player: Player)
	local index = aboard[player]
	if index == nil then
		return
	end
	aboard[player] = nil
	local car = cars[index]
	local at = table.find(car.players, player)
	if at then
		table.remove(car.players, at)
	end
	if #car.players == 0 then
		car.since = nil
		car.generation += 1
	end
	if not car.departing then
		car.startedAt = CarBoarding.afterLeave(rules(car), now())
	elseif #car.players == 0 then
		car.departing = false
		car.startedAt = nil
	end
	publish()
end

local function board(player: Player, index: number)
	local car = cars[index]
	if
		car == nil
		or aboard[player] ~= nil
		or Registry.CrewService.IsMember(player)
		or not CarBoarding.canEnter(rules(car))
	then
		return
	end
	table.insert(car.players, player)
	aboard[player] = index
	if #car.players == 1 then
		car.since = DateTime.now().UnixTimestampMillis / 1000
	end
	LobbyService.ClearReady(player)
	car.startedAt = CarBoarding.afterEnter(rules(car), now())
	place(player, slot(car, #car.players))
	publish()
end

local function leave(player: Player, index: number)
	local car = cars[index]
	if car == nil or aboard[player] ~= index or not CarBoarding.canExit(rules(car), now()) then
		return
	end
	remove(player)
	place(player, car.outside * CFrame.new((math.random() - 0.5) * 3, 0, 0))
end

-- Teleports the car's players to a fresh reserved server, where the run starts on arrival; or, for a crew the
-- cross-server queue formed (MatchmakingService), into that crew's shared reserved server.
local function teleport(crew: { Player }, match: CrewQueue.Match?): boolean
	local userIds = {}
	for _, player in crew do
		table.insert(userIds, player.UserId)
	end
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		if match then
			options.ReservedServerAccessCode = match.code
			options:SetTeleportData({ carRun = true, crew = match.crew, matchId = match.matchId })
		else
			options.ShouldReserveServer = true
			options:SetTeleportData({ carRun = true, crew = userIds })
		end
		TeleportService:TeleportAsync(game.PlaceId, crew, options)
	end)
	if not ok then
		warn(`[CarService] teleport failed: {err}`)
	end
	return ok
end

-- A matched teleport that failed: try again a few times before the car opens up.
local function retry(crew: { Player }, match: CrewQueue.Match): boolean
	for _ = 2, Tuning.Cars.TeleportTries do
		task.wait(1)
		if teleport(crew, match) then
			return true
		end
	end
	return false
end

local function depart(index: number, match: CrewQueue.Match?)
	local car = cars[index]
	car.departing = true
	publish()
	task.delay(Tuning.Cars.FadeSeconds, function()
		Safe.call("CarService.depart", function()
			local crew = table.clone(car.players)
			if match then
				-- only the riders the match counted: someone who boarded since waits for the next crew
				for i = #crew, 1, -1 do
					if not table.find(match.crew, crew[i].UserId) then
						table.remove(crew, i)
					end
				end
			end
			if #crew == 0 then
				car.departing = false
				publish()
				return
			end
			if RunService:IsStudio() then
				-- Studio cannot teleport: run here with this car's players as the crew.
				if Registry.RunDirector.Launch(crew) then
					for _, player in crew do
						aboard[player] = nil
					end
					table.clear(car.players)
					car.departing, car.startedAt = false, nil
					publish()
					return
				end
				NetService.FireList(
					"Notify",
					crew,
					"Warning",
					"A run is underway on this server. Try again after it."
				)
			elseif teleport(crew, match) then
				return -- they stay aboard, black, until they leave the server
			elseif match and retry(crew, match) then
				return
			else
				NetService.FireList("Notify", crew, "Warning", "The train could not leave. Try again.")
			end
			car.departing = false
			car.startedAt = CarBoarding.afterLeave(rules(car), now())
			publish()
		end)
	end)
end

local function prompt(parent: BasePart, action: string, index: number, actionText: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = `Car {index}`
	p.HoldDuration = Tuning.Cars.HoldSeconds
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.MaxActivationDistance = Tuning.Cars.PromptDistance
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Action", action)
	p:SetAttribute("Car", index)
	p.Triggered:Connect(function(player)
		if action == "CarBoard" then
			board(player, index)
		else
			leave(player, index)
		end
	end)
	p.Parent = parent
end

local function marker(folder: Instance, name: string, cframe: CFrame, size: Vector3, index: number): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part:SetAttribute("Car", index)
	part.Parent = folder
	return part
end

-- In a car's reserved server: wait for the whole car (or the timeout), then start the run.
local function launchOnArrival()
	local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
	local data = first:GetJoinData().TeleportData
	local expected = if type(data) == "table" and type(data.crew) == "table" then #data.crew else 1
	-- a crew the queue formed comes from several halls: give the last car a little longer
	local matched = type(data) == "table" and data.matchId ~= nil
	local deadline = os.clock() + Tuning.Cars.ArrivalWaitSeconds + (if matched then 10 else 0)
	while #Players:GetPlayers() < expected and os.clock() < deadline do
		task.wait(0.25)
	end
	-- characters first, so BeginRun moves bodies that exist
	task.wait(1)
	Registry.RunDirector.Launch(Players:GetPlayers())
end

function CarService.Init()
	local display = LobbyService.DisplayTrain()
	local folder = Instance.new("Folder")
	folder.Name = "CarDoors"
	folder.Parent = if display then display.Parent else Workspace
	for index, cabin in LobbyService.DisplayCabins() do
		local door = cabin.door
		-- the door's frame: +Z points out of the car, and floor level is half a door below
		local ground = door * CFrame.new(0, -door.Position.Y + cabin.floor.Position.Y, 0)
		local inside = ground * CFrame.new(0, 3, -2.2)
		local outside = ground * CFrame.new(0, 3, 2.4)
		-- on the aisle down the middle, facing the door so its Get out prompt stays on screen
		local aislePos = (ground * CFrame.new(0, 3, -cabin.size.Z / 2 - 0.5)).Position
		local aisle = CFrame.lookAt(aislePos, inside.Position, door.UpVector)
		local car: Car = {
			players = {},
			startedAt = nil,
			departing = false,
			since = nil,
			generation = 1,
			inside = aisle,
			-- out on the platform clear of the door, so the camera has room behind
			outside = ground * CFrame.new(0, 3, 7) * CFrame.Angles(0, math.pi, 0),
		}
		cars[index] = car
		marker(folder, "CarZone", cabin.floor, Vector3.new(cabin.size.X, 0.2, cabin.size.Z), index)
		prompt(marker(folder, "CarDoorOut", outside, Vector3.new(1, 1, 1), index), "CarBoard", index, "Board")
		prompt(marker(folder, "CarDoorIn", inside, Vector3.new(1, 1, 1), index), "CarExit", index, "Get out")
	end
	publish()
end

function CarService.Start()
	Players.PlayerRemoving:Connect(remove)
	-- a player who resets in a car comes back in it
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3)
			local index = aboard[player]
			if index then
				local car = cars[index]
				place(player, slot(car, table.find(car.players, player) or 1))
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	TeleportService.TeleportInitFailed:Connect(function(player)
		local index = aboard[player]
		if index and cars[index].departing then
			remove(player)
			place(player, cars[index].outside)
			NetService.Fire("Notify", player, "Warning", "The train could not leave. Try again.")
		end
	end)

	RunService.Heartbeat:Connect(function()
		local t = now()
		for index, car in cars do
			-- a part car waits for the cross-server queue to couple it (MatchmakingService) until the
			-- fallback; a full car, or any car while the queue is down, leaves on its own countdown
			local full = #car.players >= Tuning.Cars.MaxPlayers
			local deadline = (car.startedAt or t) + Tuning.Cars.CountdownSeconds
			local queue = Registry.MatchmakingService
			local healthy = queue ~= nil and queue.Healthy()
			if
				CarBoarding.shouldDepart(rules(car), t)
				and not CrewQueue.holdLocal(full, healthy, deadline, t)
			then
				depart(index)
			end
		end
	end)

	if IS_CAR_SERVER then
		task.spawn(Safe.call, "CarService.launchOnArrival", launchOnArrival)
		-- the run over, everyone goes back to a public Depot Hall
		Registry.RunDirector.PhaseChanged:Connect(function(nextPhase: string, previous: string)
			if nextPhase == "Lobby" and previous ~= "Lobby" and previous ~= "Countdown" then
				local everyone = Players:GetPlayers()
				if #everyone > 0 then
					pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, everyone)
				end
			end
		end)
	end
end

-- Occupied cars for the crew queue (MatchmakingService): who is aboard, since when, and the unix time the
-- car's countdown ends (or would, for a lone rider: CountdownSeconds after boarding).
function CarService.Queueing(): {
	{
		index: number,
		generation: number,
		members: { number },
		since: number,
		deadline: number,
	}
}
	local out = {}
	local t, u = now(), DateTime.now().UnixTimestampMillis / 1000
	for index, car in cars do
		local since = car.since
		if since and not car.departing and #car.players > 0 and #car.players < Tuning.Cars.MaxPlayers then
			local members = {}
			for _, player in car.players do
				table.insert(members, player.UserId)
			end
			local deadline = if car.startedAt
				then u + (car.startedAt + Tuning.Cars.CountdownSeconds - t)
				else since + Tuning.Cars.CountdownSeconds
			table.insert(out, {
				index = index,
				generation = car.generation,
				members = members,
				since = since,
				deadline = deadline,
			})
		end
	end
	return out
end

-- The queue matched this car (MatchmakingService): send its riders to the crew's shared reserved server.
function CarService.DepartMatched(index: number, generation: number, match: CrewQueue.Match)
	local car = cars[index]
	if car == nil or car.generation ~= generation or car.departing or #car.players == 0 then
		return
	end
	depart(index, match)
end

function CarService.IsAboard(player: Player): boolean
	return aboard[player] ~= nil
end

return CarService
