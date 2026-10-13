--!strict
--[[
	Runs a stop's timed events (Config/TimedEvents, planned by Logic/TimedEventSchedule).
	HazardDirector drives it: Begin when the doors open, Step every frame while the stop's
	timeline runs, Finish when it freezes or stops, which cleans up whatever is running.

	The HUD hears about an event through attributes on ReplicatedStorage, read by the
	client's TimedEventToast: TimedEvent (its id, nil when none), TimedEventTitle,
	TimedEventText, TimedEventCue, TimedEventStartAt and TimedEventEndAt (server times).

	Testing: the game's owner (or anyone in Studio) types `/event surge` or
	`/event breakdown` in chat while the doors are open.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local TimedEvents = require(Shared.Config.TimedEvents)
local Schedule = require(Shared.Logic.TimedEventSchedule)
local Safe = require(Shared.Util.Safe)
local Types = require(Shared.Types)

local Registry = require(script.Parent.Parent.Registry)

type Running = { slot: Schedule.Slot, started: boolean, cleanup: (() -> ())? }

local TimedEventDirector = {}

local info: Types.StationInfo? = nil
local slots: { Schedule.Slot } = {}
local index = 1
local running: Running? = nil

local ATTRIBUTES = {
	"TimedEvent",
	"TimedEventTitle",
	"TimedEventText",
	"TimedEventCue",
	"TimedEventStartAt",
	"TimedEventEndAt",
}

-- Starts each event; returns its cleanup.
local Handlers: { [string]: (def: TimedEvents.Def) -> () -> () } = {
	Surge = function(def)
		Registry.HollowService.Alert(def.duration)
		local extra = Registry.HazardDirector.SpawnExtra()
		Registry.NetService.FireAll("Notify", "Alarm", "Surge! The Hollows are coming for you!")
		return function()
			Registry.HollowService.EndAlert()
			if extra and extra.Parent then
				Registry.HollowService.Dismiss(extra)
			end
		end
	end,
	Breakdown = function(def)
		for _ = 1, def.breaks or 2 do
			Registry.TrainService.OpenBreach()
		end
		-- the leaks stay for the crew to patch: nothing to undo
		return function() end
	end,
}

local function clearAttributes()
	for _, name in ATTRIBUTES do
		ReplicatedStorage:SetAttribute(name, nil)
	end
end

local function warn(slot: Schedule.Slot, startedAt: number)
	local def = TimedEvents.Events[slot.id]
	ReplicatedStorage:SetAttribute("TimedEventTitle", def.title)
	ReplicatedStorage:SetAttribute("TimedEventText", def.warning)
	ReplicatedStorage:SetAttribute("TimedEventCue", def.cue)
	ReplicatedStorage:SetAttribute("TimedEventStartAt", startedAt + slot.startAt)
	ReplicatedStorage:SetAttribute("TimedEventEndAt", startedAt + slot.endAt)
	-- set last: the client reads the rest when this changes
	ReplicatedStorage:SetAttribute("TimedEvent", slot.id)
end

-- Ends whatever event is warned or running, and cleans up after it.
function TimedEventDirector.Finish()
	local current = running
	running = nil
	if current and current.cleanup then
		Safe.call("TimedEventDirector.cleanup", current.cleanup)
	end
	clearAttributes()
end

function TimedEventDirector.Begin(stationInfo: Types.StationInfo)
	TimedEventDirector.Finish()
	info = stationInfo
	index = 1
	-- the Emergency Village has its own clock and toast (BreakdownService): no events there
	slots = if stationInfo.terminus or stationInfo.emergency
		then {}
		else Schedule.plan(stationInfo.dwell, stationInfo.lastCall, stationInfo.layoutSeed)
end

-- `t` is seconds since the doors opened.
function TimedEventDirector.Step(t: number)
	local station = info
	if station == nil then
		return
	end
	local current = running
	if current == nil then
		local slot = slots[index]
		if slot and t >= slot.warnAt then
			index += 1
			running = { slot = slot, started = false, cleanup = nil }
			warn(slot, station.startedAt)
		end
		return
	end
	if not current.started and t >= current.slot.startAt then
		current.started = true
		local def = TimedEvents.Events[current.slot.id]
		Safe.call("TimedEventDirector.start", function()
			current.cleanup = Handlers[current.slot.id](def)
		end)
	elseif current.started and t >= current.slot.endAt then
		TimedEventDirector.Finish()
	end
end

-- Runs `id` now (with its warning), for testing. Returns why not, or nil when it starts.
function TimedEventDirector.Force(id: string): string?
	local station = info
	if TimedEvents.Events[id] == nil then
		return `No event called {id}.`
	elseif station == nil or Registry.RunDirector.Phase() ~= "Dwell" then
		return "Events only run while the doors are open."
	elseif running then
		return "An event is already running."
	end
	local t = Workspace:GetServerTimeNow() - station.startedAt
	local slot = Schedule.slot(id, t)
	-- scheduled events that would now crowd this one are dropped
	while slots[index] and slots[index].warnAt < slot.endAt + TimedEvents.Gap[1] do
		index += 1
	end
	running = { slot = slot, started = false, cleanup = nil }
	warn(slot, station.startedAt)
	return nil
end

local function isOwner(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroupAsync(game.CreatorId)
	end)
	return ok and rank >= 255
end

local function onChatted(player: Player, message: string)
	local name = string.match(string.lower(message), "^/event%s+(%a+)")
	if name == nil or not isOwner(player) then
		return
	end
	local id: string? = nil
	for key in TimedEvents.Events do
		if string.lower(key) == name then
			id = key
		end
	end
	local why = TimedEventDirector.Force(id or name)
	Registry.NetService.Fire("Notify", player, "Warning", why or `Timed event {id} triggered.`)
end

function TimedEventDirector.Start()
	local function watch(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
end

return TimedEventDirector
