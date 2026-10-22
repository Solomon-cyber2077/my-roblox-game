--!strict
--[[
	The Depot Hall: ready-ups, lobby spawning, kiosk prompts and late joining.
	A player is "in the lobby" whenever they are not a live crew member and not
	aboard a boarding car (CarService); car players are ready by being aboard.
	Ready is per player: the hall's run takes only the players who pressed Ready, so one
	player can go solo while the rest of the hall stays put.
	The host (the lobby player who has been in the server longest) picks the opt-in
	run tier, up to the lowest tier any hall player has unlocked.
	The run card's AGAIN (Logic/Again, Prompt 5): pressed during RunEnd it is queued and applied
	after ResetReady; the hall then holds its countdown until the run's present members are all
	ready or 20 s pass with one ready. DEPOT leaves that player unready.
	The line (Logic/Routes, Prompt 10): with a new Hand in the hall the length is fixed and the hall
	is told so; otherwise each hall player may vote Short or Long (`VoteLine`), and the run counts
	its crew's votes at Boarding (a tie or none: Long). INVITE presses are logged (`Invited`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Difficulty = require(Shared.Config.Difficulty)
local Tuning = require(Shared.Config.Tuning)
local Again = require(Shared.Logic.Again)
local Routes = require(Shared.Logic.Routes)
local RunTier = require(Shared.Logic.RunTier)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local LobbyBuilder = require(script.Parent.Parent.Builders.LobbyBuilder)
local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local LobbyService = {}

local built: LobbyBuilder.Built? = nil
local ready: { [Player]: boolean } = {}
local spawnIndex = 0
local crewOverride: { Player }? = nil
local joinOrder: { Player } = {}
local selectedTier = Difficulty.RunTier.Default
local published: Types.LobbyTier? = nil
local card: Again.Card? = nil -- the ended run's AGAIN/DEPOT card
local cardAt = 0 -- os.clock() it opened
local cardOutcome = "aborted"
local lineVotes: { [Player]: string } = {} -- "Short" or "Long"
local publishedLine = ""

local function publishReady()
	local map: { [string]: boolean } = {}
	for player, isReady in ready do
		if isReady then
			map[tostring(player.UserId)] = true
		end
	end
	StateService.Set({ "lobby", "ready" }, map)
end

local function presentIds(): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for _, player in Players:GetPlayers() do
		out[player.UserId] = true
	end
	return out
end

local function readyIds(): { [number]: boolean }
	local out: { [number]: boolean } = {}
	for player, isReady in ready do
		if isReady and player.Parent ~= nil then
			out[player.UserId] = true
		end
	end
	return out
end

-- The card's state for the clients (UI/RunCard): who may press, who chose what, the ready count.
local function publishAgain()
	if card == nil then
		StateService.Set({ "lobby", "again" }, nil)
		return
	end
	local readyCount, of = Again.count(card, presentIds(), readyIds())
	local eligible: { [string]: boolean } = {}
	for id in card.eligible do
		eligible[tostring(id)] = true
	end
	local chose: { [string]: string } = {}
	for id in card.pressed do
		chose[tostring(id)] = "again"
	end
	for id in card.declined do
		chose[tostring(id)] = "depot"
	end
	StateService.Set(
		{ "lobby", "again" },
		{ ready = readyCount, of = of, eligible = eligible, chose = chose }
	)
end

local function prompt(part: BasePart, action: string, objectText: string, actionText: string)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Action", action)
	p.Parent = part
end

local function crewMax(crew: { Player }): number
	local unlocked: { number } = {}
	for _, player in crew do
		table.insert(unlocked, Registry.DataService.UnlockedTier(player))
	end
	return RunTier.crewMax(unlocked)
end

-- The longest-present player in the hall.
local function host(): Player?
	for _, player in joinOrder do
		if
			player.Parent ~= nil
			and not Registry.CrewService.IsMember(player)
			and not Registry.CarService.IsAboard(player)
		then
			return player
		end
	end
	return nil
end

local function publishTier()
	local max = crewMax(LobbyService.LobbyPlayers())
	local h = host()
	local info: Types.LobbyTier =
		{ selected = math.min(selectedTier, max), max = max, host = if h then tostring(h.UserId) else nil }
	local last = published
	if last and last.selected == info.selected and last.max == info.max and last.host == info.host then
		return
	end
	published = info
	StateService.Set({ "lobby", "tier" }, info)
end

-- lobby.line: is the hall's line fixed by a new Hand, and the hall's votes.
local function publishLine()
	local hall = LobbyService.LobbyPlayers()
	local votes: { [string]: string } = {}
	local short, long = 0, 0
	for _, player in hall do
		local vote = lineVotes[player]
		if vote then
			votes[tostring(player.UserId)] = vote
			if vote == "Short" then
				short += 1
			else
				long += 1
			end
		end
	end
	local anyNew = #Registry.TutorialService.NewHands(hall) > 0
	local route, fixed = Routes.decide(anyNew, nil, short, long)
	local line: Types.LobbyLine = { fixed = fixed, route = route, short = short, long = long, votes = votes }
	local key = `{fixed}|{route}|{short}|{long}`
	for id, vote in votes do
		key ..= `|{id}={vote}`
	end
	if key == publishedLine then
		return
	end
	publishedLine = key
	StateService.Set({ "lobby", "line" }, line)
end

function LobbyService.Init()
	local origin = Tuning.World.LobbyOrigin
	built = LobbyBuilder.build(CFrame.new(origin[1], origin[2], origin[3]), Workspace)
	local b = built :: LobbyBuilder.Built
	prompt(b.outfitter, "Outfitter", "Outfitter", "Browse")
	prompt(b.ledger, "Ledger", "Line Mastery", "Read")
	-- every chair and bench in the hall: walk into it and you sit (jump to stand); after standing
	-- the seat waits a moment before it takes anyone, so jumping off does not drop you straight back
	for _, seat in b.seats do
		seat.CanTouch = true
		local freeAt = 0
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			if seat.Occupant == nil then
				freeAt = os.clock() + Tuning.Lobby.SeatRetouchDelay
			end
		end)
		seat.Touched:Connect(function(hit)
			if seat.Occupant ~= nil or os.clock() < freeAt then
				return
			end
			local character = hit.Parent
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				humanoid
				and root
				and Players:GetPlayerFromCharacter(character)
				and humanoid.Health > 0
				and not humanoid.Sit
				and not root.Anchored
			then
				seat:Sit(humanoid)
			end
		end)
	end
	StateService.Set({ "lobby" }, { ready = {}, origin = origin })
	publishTier()
end

function LobbyService.Start()
	NetService.Handle("SetReady", function(player, isReady: boolean)
		ready[player] = isReady
		publishReady()
		publishAgain()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown")
			and not Registry.CrewService.IsMember(player)
			and not Registry.CarService.IsAboard(player)
	end)

	NetService.Handle("Again", function(player, again: boolean)
		local current = card
		if current == nil then
			return
		end
		local phase = Registry.RunDirector.Phase()
		if again then
			local accepted, now = Again.press(current, player.UserId, phase ~= "RunEnd", os.clock())
			if accepted then
				Registry.TelemetryService.AgainPressed(player, os.clock() - cardAt, cardOutcome)
			end
			if now then
				ready[player] = true
				publishReady()
			end
		else
			Again.depot(current, player.UserId)
			ready[player] = nil
			publishReady()
		end
		publishAgain()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "RunEnd" or phase == "Lobby" or phase == "Countdown")
			and not Registry.CarService.IsAboard(player)
	end)

	NetService.Handle("VoteLine", function(player, route: string)
		if route ~= "Short" and route ~= "Long" then
			return
		end
		lineVotes[player] = route
		publishLine()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown")
			and not Registry.CrewService.IsMember(player)
			and not Registry.CarService.IsAboard(player)
	end)

	-- the INVITE buttons (UI/Lobby, UI/RunCard) report a prompt they opened
	NetService.Handle("Invited", function(player, source: string)
		if source == "depot" or source == "runcard" then
			Registry.TelemetryService.InvitePrompted(player, source)
		end
	end)

	NetService.Handle("SetRunTier", function(_player, tier: number)
		selectedTier = RunTier.clamp(tier)
		publishTier()
	end, function(player)
		local phase = Registry.RunDirector.Phase()
		return (phase == "Lobby" or phase == "Countdown") and host() == player
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		lineVotes[player] = nil
		task.defer(publishLine)
		task.defer(publishAgain) -- a leaving member drops out of the AGAIN count
		local index = table.find(joinOrder, player)
		if index then
			table.remove(joinOrder, index)
		end
		publishReady()
	end)
	Players.PlayerAdded:Connect(function(player)
		table.insert(joinOrder, player)
		task.spawn(LobbyService.Spawn, player)
	end)
	for _, player in Players:GetPlayers() do
		table.insert(joinOrder, player)
		task.spawn(LobbyService.Spawn, player)
	end

	-- profiles load, players join, leave and come home from runs: keep the host and cap current
	task.spawn(function()
		while true do
			task.wait(Difficulty.RunTier.LobbyRefreshSeconds)
			Safe.call("LobbyService.publishTier", publishTier)
			Safe.call("LobbyService.publishLine", publishLine)
		end
	end)
end

function LobbyService.DisplayTrain(): Model?
	return if built then built.displayTrain else nil
end

function LobbyService.DisplayCabins(): { LobbyBuilder.Cabin }
	return if built then built.displayCabins else {}
end

function LobbyService.Board(): BasePart?
	return if built then built.board else nil
end

function LobbyService.SpawnPoint(): CFrame
	local b = built :: LobbyBuilder.Built
	spawnIndex = spawnIndex % #b.spawnPoints + 1
	return b.spawnPoints[spawnIndex]
end

-- Loads a fresh character in the hall.
function LobbyService.Spawn(player: Player)
	Registry.CrewService.LoadCharacterAt(player, LobbyService.SpawnPoint())
end

function LobbyService.LobbyPlayers(): { Player }
	local out: { Player } = {}
	for _, player in Players:GetPlayers() do
		if not Registry.CrewService.IsMember(player) and not Registry.CarService.IsAboard(player) then
			table.insert(out, player)
		end
	end
	return out
end

function LobbyService.LobbyCount(): number
	return #LobbyService.LobbyPlayers()
end

function LobbyService.ReadyCount(): number
	local count = 0
	for player, isReady in ready do
		if isReady and player.Parent ~= nil and not Registry.CrewService.IsMember(player) then
			count += 1
		end
	end
	return count
end

-- The run tier for this crew: the host's pick, capped by what every member has unlocked.
-- The crew's line votes at Boarding: Short, Long.
function LobbyService.LineVotes(crew: { Player }): (number, number)
	local short, long = 0, 0
	for _, player in crew do
		local vote = lineVotes[player]
		if vote == "Short" then
			short += 1
		elseif vote == "Long" then
			long += 1
		end
	end
	return short, long
end

function LobbyService.TierFor(crew: { Player }): number
	return math.min(selectedTier, crewMax(crew))
end

-- The hall players who pressed Ready.
function LobbyService.ReadyPlayers(): { Player }
	local out: { Player } = {}
	for _, player in LobbyService.LobbyPlayers() do
		if ready[player] then
			table.insert(out, player)
		end
	end
	return out
end

-- The crew for the next Boarding: a launching car's players if one was set, else the hall's
-- ready players (the whole hall only if nobody is ready, as when a dev command starts a run).
function LobbyService.SetCrew(crew: { Player })
	crewOverride = crew
end

function LobbyService.TakeCrew(): { Player }
	local readied = LobbyService.ReadyPlayers()
	local crew = crewOverride or (if #readied > 0 then readied else LobbyService.LobbyPlayers())
	crewOverride = nil
	-- the run is leaving: the last card is done
	card = nil
	publishAgain()
	return crew
end

-- RunEnd: the card for this run's present members (alive or eliminated).
function LobbyService.OpenCard(players: { Player }, outcome: string)
	local ids: { number } = {}
	for _, player in players do
		if player.Parent ~= nil then
			table.insert(ids, player.UserId)
		end
	end
	card = Again.card(ids)
	cardAt = os.clock()
	cardOutcome = outcome
	publishAgain()
end

-- Enter.Lobby, after ResetReady: queued AGAIN presses become ready now (and start the 20 s wait).
function LobbyService.ApplyAgain()
	local current = card
	if current == nil then
		return
	end
	for _, id in Again.apply(current, os.clock()) do
		local player = Players:GetPlayerByUserId(id)
		if player then
			ready[player] = true
		end
	end
	publishReady()
	publishAgain()
end

-- Whether the hall holds its countdown for an AGAIN crew still readying.
function LobbyService.HoldCountdown(): boolean
	return Again.hold(card, presentIds(), readyIds(), os.clock())
end

function LobbyService.ClearReady(player: Player)
	ready[player] = nil
	publishReady()
end

function LobbyService.ResetReady()
	table.clear(ready)
	publishReady()
end

return LobbyService
