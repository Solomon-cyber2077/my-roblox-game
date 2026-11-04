--!strict
-- Junction votes: opens the ballot, records one vote per living crew member, tallies with Logic/Vote.
-- A mystery ticket's real station is held here, server-only, and never enters state (Logic/Mystery).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vote = require(Shared.Logic.Vote)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local RouteService = {}

local options: { Types.RouteOption } = {}
local hidden: { [number]: Types.RouteOption } = {}
local votes: { [string]: number } = {}
local castAt: { [string]: number } = {} -- seconds after the ballot opened that each vote was cast
local openedAt = 0
local rng = Random.new()

-- A vote still counts at the close only while its voter is in the game and alive. Keys that are not
-- user ids are Studio's fake voters (DevVote) and always count.
local function stillVoting(key: string): boolean
	local userId = tonumber(key)
	if userId == nil then
		return true
	end
	local player = Players:GetPlayerByUserId(userId)
	return player ~= nil and Registry.CrewService.IsAlive(player)
end

function RouteService.Init() end

function RouteService.Start()
	NetService.Handle("CastVote", function(player, option: number)
		if option < 1 or option > #options or option % 1 ~= 0 then
			return
		end
		local key = tostring(player.UserId)
		votes[key] = option
		castAt[key] = os.clock() - openedAt
		StateService.Set({ "run", "route", "votes" }, votes)
	end, function(player)
		return Registry.RunDirector.Phase() == "Junction" and Registry.CrewService.IsAlive(player)
	end)
	-- a crew member who leaves mid-ballot takes their vote with them (the ballot's stamps update)
	Players.PlayerRemoving:Connect(function(player)
		local key = tostring(player.UserId)
		if votes[key] ~= nil then
			votes[key] = nil
			castAt[key] = nil
			StateService.Set({ "run", "route", "votes" }, votes)
		end
	end)
end

-- `sealed` maps a ballot index holding a mystery stand-in to the real station behind it.
function RouteService.Open(nextOptions: { Types.RouteOption }, sealed: { [number]: Types.RouteOption }?)
	options = nextOptions
	hidden = sealed or {}
	votes = {}
	castAt = {}
	openedAt = os.clock()
	StateService.Set({ "run", "route" }, { options = options, votes = {}, chosen = nil })
end

-- The winner's index, its public option and the station it really leads to. Votes from crew who left
-- or went down before the close are dropped first.
function RouteService.Close(): (number, Types.RouteOption, Types.RouteOption)
	votes = Vote.prune(votes, stillVoting)
	StateService.Set({ "run", "route", "votes" }, votes)
	local index = Vote.tally(votes, options, rng:NextNumber())
	StateService.Set({ "run", "route", "chosen" }, index)
	if #options > 1 then
		local counted, last = 0, 0
		for _, count in Vote.counts(votes, #options) do
			counted += count
		end
		for key in votes do
			last = math.max(last, castAt[key] or 0)
		end
		Registry.TelemetryService.RouteVote(
			Registry.RunDirector.NextStop(),
			last,
			Vote.result(votes, #options),
			Vote.turnout(counted, Registry.CrewService.AliveCount())
		)
	end
	return index, options[index], hidden[index] or options[index]
end

-- Studio only (Dev `fakevote`): a vote from `key`, a voter who is not in the game, so the ballot
-- can be seen with more stamps than there are test players.
function RouteService.DevVote(key: string, option: number)
	if option >= 1 and option <= #options then
		votes[key] = option
		StateService.Set({ "run", "route", "votes" }, votes)
	end
end

function RouteService.Clear()
	options = {}
	hidden = {}
	votes = {}
	StateService.Set({ "run", "route" }, nil)
end

return RouteService
