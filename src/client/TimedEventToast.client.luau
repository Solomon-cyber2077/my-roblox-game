--!strict
--[[
	Shows the timed-event toast (UI/EventToast) from the attributes the server's
	Events/TimedEventDirector puts on ReplicatedStorage, and plays the event's cue once
	when its warning comes up.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Safe = require(ReplicatedStorage.Shared.Util.Safe)

local Registry = require(script.Parent.Registry)
local Session = require(script.Parent.Session)
local EventToast = require(script.Parent.UI.EventToast)

local current: string? = nil

local function onEvent()
	local id = ReplicatedStorage:GetAttribute("TimedEvent") :: string?
	if id == current then
		return
	end
	current = id
	if id == nil then
		EventToast.hide()
		return
	end
	local cue = ReplicatedStorage:GetAttribute("TimedEventCue") :: string?
	if cue and Session.isMember() and Registry.AudioController then
		Registry.AudioController.Play(cue)
	end
end

local function update()
	if current == nil or not Session.isMember() then
		EventToast.hide()
		return
	end
	local name = (ReplicatedStorage:GetAttribute("TimedEventTitle") :: string?) or "EVENT"
	local text = (ReplicatedStorage:GetAttribute("TimedEventText") :: string?) or ""
	local startAt = (ReplicatedStorage:GetAttribute("TimedEventStartAt") :: number?) or 0
	local left = startAt - Workspace:GetServerTimeNow()
	if left > 0 then
		EventToast.show(`{name} IN {math.ceil(left)}`, text)
	else
		EventToast.show(`{name}!`, text)
	end
end

ReplicatedStorage:GetAttributeChangedSignal("TimedEvent"):Connect(onEvent)
onEvent()
RunService.Heartbeat:Connect(function()
	Safe.call("TimedEventToast.update", update)
end)
