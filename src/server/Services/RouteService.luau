--!strict
-- Junction votes: opens the ballot, records one vote per living crew member, tallies with Logic/Vote.
-- A mystery ticket's real station is held here, server-only, and never enters state (Logic/Mystery).

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

-- `sealed` maps a ballot index holding a mystery stand-in to the real station behind it.
function RouteService.Open(nextOptions: { Types.RouteOption }, sealed: { [number]: Types.RouteOption }?)
	options = nextOptions
	hidden = sealed or {}
	votes = {}
	StateService.Set({ "run", "route" }, { options = options, votes = {}, chosen = nil })
end

-- The winner's index, its public option and the station it really leads to.
function RouteService.Close(): (number, Types.RouteOption, Types.RouteOption)
	local index = Vote.tally(votes, options, rng:NextNumber())
	StateService.Set({ "run", "route", "chosen" }, index)
	return index, options[index], hidden[index] or options[index]
end

function RouteService.Clear()
	options = {}
	hidden = {}
	votes = {}
	StateService.Set({ "run", "route" }, nil)
end

return RouteService
