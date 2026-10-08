--!strict
--[[
	The one client clock for a stop's departure. Every frame it reads run.station.departAt
	(StateService) against the server clock (Session.now), so the watch, the slate and every
	cue agree with the server's own departure; nothing else on the client counts a stop down.
	Logic/DepartureSchedule says when each warning fires; this plays them:

	  start, halfway  a chalk slate (Overlay.slate)
	  T-30            slate, bell and a low whistle from the chimney, a puff of steam;
	                  the pocket watch starts ticking (UI/Hud reads Level)
	  T-10            the long whistle from the chimney, heard across the stop; the tick doubles
	  T-0             a burst of steam (FxController plays the departure whistle), then Clear

	While the warning is up each tick is a quiet click and, at most once a second, a soft amber
	pulse on the screen's edges for players with the sound off. An amber grade of its own
	(Lighting.DepartureWarning) and a little extra fog (AtmosphereController.SetWarning) ease in
	from T-30 and back out after Clear.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local DepartureSchedule = require(Shared.Logic.DepartureSchedule)
local MathX = require(Shared.Util.MathX)
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local Overlay = require(script.Parent.Parent.UI.Overlay)

local DepartureClock = {}

local STOP_PHASES: { [string]: boolean } = { Dwell = true, LastCall = true, Departure = true }
local AMBER = Color3.fromRGB(240, 172, 64)
local GRADE_TINT = Color3.fromRGB(255, 228, 196) -- the warning grade at full warmth
local PULSE = { warning = 0.08, escalated = 0.14 } -- edge pulse strength per tick
local TICK_GAIN = { warning = 1, escalated = 1.5 }
local TICK_RATE = { warning = 1, escalated = 2 } -- ticks per second
local WARM_RATE = 0.6 -- per second, toward the warning look and back
local PUFF, BURST = 24, 70 -- smoke particles at T-30 and T-0

local tracker = DepartureSchedule.tracker()
local left: number? = nil
local level: DepartureSchedule.Level = "calm"
local clearedKey: number? = nil
local lastBeat = -1
local lastSecond = -1
local warmth = 0
local grade: ColorCorrectionEffect

local function play(cueName: string, gain: number?, fromChimney: boolean?)
	local audio = Registry.AudioController
	if audio == nil then
		return
	end
	local position: Vector3? = nil
	if fromChimney and Registry.TrainVisualsController then
		local chimney = Registry.TrainVisualsController.Chimney()
		position = chimney and chimney.Position
	end
	audio.Play(cueName, position, gain)
end

local function duck()
	if Registry.AudioController then
		Registry.AudioController.Duck(Tuning.Departure.DuckSeconds)
	end
end

local function puff(count: number)
	if Registry.TrainVisualsController then
		Registry.TrainVisualsController.Puff(count)
	end
end

-- Ends the warning for this stop: the ticking, the grade and the fog ease away. The one place
-- it ends, so a grace window after T-0 only has to move this call.
function DepartureClock.Clear()
	clearedKey = tracker.key
	level = "calm"
	lastBeat, lastSecond = -1, -1
end

local function onMilestone(milestone: DepartureSchedule.Milestone)
	local words = DepartureSchedule.slate(milestone)
	if words then
		Overlay.slate(words)
	end
	if milestone.kind == "warning" then
		duck()
		play("WarnBell")
		play("WarnWhistle", nil, true)
		puff(PUFF)
	elseif milestone.kind == "escalated" then
		duck()
		play("WarnWhistleLong", nil, true)
	elseif milestone.kind == "depart" then
		puff(BURST)
		DepartureClock.Clear()
	end
end

-- Ticks while the warning is up: a click on each beat, an edge pulse on each whole second.
local function tick(remaining: number)
	if level ~= "warning" and level ~= "escalated" then
		return
	end
	local beat = math.floor(remaining * TICK_RATE[level])
	if beat ~= lastBeat then
		lastBeat = beat
		play("WarnTick", TICK_GAIN[level])
	end
	local second = math.floor(remaining)
	if second ~= lastSecond then
		lastSecond = second
		Overlay.pulse(AMBER, PULSE[level], 0.6)
	end
end

local function frame(dt: number)
	local station = Registry.StateController.Get({ "run", "station" })
	if station == nil or not STOP_PHASES[Session.phase()] or not Session.isMember() then
		left = nil
		if level ~= "calm" then
			DepartureClock.Clear()
		end
	else
		local remaining = DepartureSchedule.remaining(station.departAt, Session.now())
		left = remaining
		local reached = DepartureSchedule.step(tracker, station.startedAt, station.dwell, remaining)
		level = if clearedKey == tracker.key then "calm" else DepartureSchedule.level(remaining)
		if reached then
			onMilestone(reached)
		end
		tick(remaining)
	end

	local target = if level == "warning" or level == "escalated" then 1 else 0
	warmth = MathX.lerp(warmth, target, math.min(WARM_RATE * dt * 4, 1))
	if math.abs(warmth - target) < 0.002 then
		warmth = target
	end
	grade.Enabled = warmth > 0
	grade.TintColor = Color3.new(1, 1, 1):Lerp(GRADE_TINT, warmth)
	if Registry.AtmosphereController then
		Registry.AtmosphereController.SetWarning(warmth)
	end
end

-- Seconds until departure while a stop is counting down (Dwell, LastCall, Departure), else nil.
function DepartureClock.Remaining(): number?
	return left
end

-- calm, warning (T-30) or escalated (T-10); calm again once Clear has run.
function DepartureClock.Level(): DepartureSchedule.Level
	return level
end

function DepartureClock.Init()
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DepartureWarning"
	grade.Enabled = false
	grade.Parent = Lighting
end

function DepartureClock.Start()
	RunService.RenderStepped:Connect(function(dt)
		Safe.call("DepartureClock", frame, dt)
	end)
end

return DepartureClock
