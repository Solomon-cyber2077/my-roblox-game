--!strict
--[[
	The client health report: frame rate, memory and load time, sent to Services/TelemetryService a
	minute in and then on Tuning.Telemetry's slow beat. Frames from a window without focus are thrown
	away, so an alt-tabbed PC or a backgrounded phone doesn't read as a slow device.
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
end

return HealthController
