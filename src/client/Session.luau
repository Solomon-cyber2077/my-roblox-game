--!strict
-- Convenience reads of replicated state from the local player's point of view.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunRules = require(ReplicatedStorage.Shared.Logic.RunRules)

local StateController = require(script.Parent.Controllers.StateController)

local Session = {}

Session.player = Players.LocalPlayer
Session.userKey = tostring(Players.LocalPlayer.UserId)

function Session.now(): number
	return Workspace:GetServerTimeNow()
end

function Session.phase(): string
	return StateController.Get({ "run", "phase" }) or "Lobby"
end

function Session.crew(): { [string]: any }?
	return StateController.Get({ "crew", Session.userKey })
end

function Session.status(): string
	local entry = Session.crew()
	return if entry then entry.status else "Lobby"
end

function Session.isMember(): boolean
	return Session.crew() ~= nil
end

function Session.isAlive(): boolean
	local status = Session.status()
	return status == "Aboard" or status == "Afield" or status == "Straggler"
end

function Session.isRunActive(): boolean
	return RunRules.isRunPhase(Session.phase() :: any)
end

function Session.profile(): { [string]: any }?
	return StateController.GetPrivate({ "profile" })
end

return Session
