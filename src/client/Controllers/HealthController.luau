--!strict
--[[
	The client health report: frame rate, memory and load time, sent to Services/TelemetryService a
	minute in and then on Tuning.Telemetry's slow beat. Frames from a window without focus are thrown
	away, so an alt-tabbed PC or a backgrounded phone doesn't read as a slow device.

	Also the stop's warning sounds: AudioController and HollowAnimator call Heard for each one that
	actually played here; the tally goes to the server once, when the stop's departure ends.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local ClientHealth = require(Shared.Logic.ClientHealth)
local Tuning = require(Shared.Config.Tuning)
local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)

local T = Tuning.Telemetry

local HealthController = {}

local sampler = ClientHealth.new()

-- warning sounds played at the current stop (Config/Telemetry Cue)
local CUE_OF = { WarnBell = "bell", WarnWhistleLong = "whistle" }
local cues = { bell = 0, whistle = 0, breath = 0 }
local stopEpoch = 0 -- goes up at each arrival, so a Hollow's breath counts once per stop
local atStop = false

local function resetCues()
	cues.bell, cues.whistle, cues.breath = 0, 0, 0
end

-- A warning cue played: an AudioController cue name, or "breath" for a stalking Hollow first heard.
function HealthController.Heard(cueName: string)
	local cue = CUE_OF[cueName] or (if cueName == "breath" then "breath" else nil)
	if cue and atStop then
		cues[cue] += 1
	end
end

function HealthController.StopEpoch(): number
	return stopEpoch
end

local STOP_PHASES = { Arrival = true, Dwell = true, LastCall = true, Departure = true }

local function onPhase(phase: any)
	local nowAtStop = STOP_PHASES[phase] == true
	if nowAtStop and not atStop then
		stopEpoch += 1
		resetCues()
	elseif atStop and not nowAtStop then
		Net.Fire("StopCues", cues.bell, cues.whistle, cues.breath)
		resetCues()
	end
	atStop = nowAtStop
end

-- False when the window was too short to send, so the load time waits for the next report.
local function report(loadSeconds: number): boolean
	local average, lowest = ClientHealth.take(sampler, T.HealthMinSeconds)
	if average and lowest then
		Net.Fire("ClientHealth", average, lowest, Stats:GetTotalMemoryUsageMb(), loadSeconds)
		return true
	end
	return false
end

local function run()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	local state = Registry.StateController
	if not state.IsReady() then
		state.Ready:Wait()
	end
	local player = Players.LocalPlayer
	if player.Character == nil then
		player.CharacterAdded:Wait()
	end
	local loadSeconds = time()
	ClientHealth.reset(sampler)
	task.wait(T.HealthFirstSeconds)
	local sent = report(loadSeconds)
	for _ = 2, T.HealthMaxReports do
		task.wait(T.HealthEverySeconds)
		sent = report(if sent then 0 else loadSeconds) or sent
	end
end

function HealthController.Init() end

function HealthController.Start()
	RunService.RenderStepped:Connect(function(dt)
		ClientHealth.frame(sampler, dt)
	end)
	local function restart()
		ClientHealth.reset(sampler)
	end
	UserInputService.WindowFocusReleased:Connect(restart)
	UserInputService.WindowFocused:Connect(restart)
	task.spawn(run)
	Registry.StateController.Observe("public", { "run", "phase" }, onPhase)
end

return HealthController
