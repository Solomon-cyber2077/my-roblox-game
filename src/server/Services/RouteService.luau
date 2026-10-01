--!strict
-- Junction votes: opens the ballot, records one vote per living crew member, tallies with Logic/Vote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Vote = require(Shared.Logic.Vote)
local Types = require(Shared.Types)

local NetService = require(script.Parent.NetService)
local Registry = require(script.Parent.Parent.Registry)
local StateService = require(script.Parent.StateService)

local RouteService = {}

local options: { Types.RouteOption } = {}
local votes: { [string]: number } = {}
local rng = Random.new()

function RouteService.Init() end

function RouteService.Start()
	NetService.Handle("CastVote", function(player, option: number)
		if option > #options then
			return
		end
		votes[tostring(player.UserId)] = option
		StateService.Set({ "run", "route", "votes" }, votes)
	end, function(player)
		return Registry.RunDirector.Phase() == "Junction" and Registry.CrewService.IsAlive(player)
	end)
end

function RouteService.Open(nextOptions: { Types.RouteOption })
	options = nextOptions
	votes = {}
	StateService.Set({ "run", "route" }, { options = options, votes = {}, chosen = nil })
end

function RouteService.Close(): (number, Types.RouteOption)
	local index = Vote.tally(votes, options, rng:NextNumber())
	StateService.Set({ "run", "route", "chosen" }, index)
	return index, options[index]
end

function RouteService.Clear()
	options = {}
	votes = {}
	StateService.Set({ "run", "route" }, nil)
end

return RouteService
