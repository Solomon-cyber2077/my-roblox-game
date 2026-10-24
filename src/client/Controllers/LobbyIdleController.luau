--!strict
--[[
	The Depot Hall idle view (docs/direction/2026-10-23_lobby-idle-final.md). Off unless
	Tuning.LobbyIdle.Enabled. After Delay seconds of continuous quiet while eligible
	(Logic/LobbyIdle), the view slowly turns round our character (Camera/IdleOrbit); any
	deliberate input, held control, movement or loss of eligibility cancels it at once and a
	fresh quiet interval is needed. One attempt per interval.

	Eligible here: a state snapshot received, phase Lobby, our own living character, no modal,
	the Roblox menu shut, no text focus, the window focused and the train camera off. The
	physical hall bound, the piano and reduced-motion note handling come with prompts 5 and 6.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local LobbyIdle = require(Shared.Logic.LobbyIdle)
local Safe = require(Shared.Util.Safe)
local Tuning = require(Shared.Config.Tuning)

local Client = script.Parent.Parent
local Registry = require(Client.Registry)
local Session = require(Client.Session)
local Modal = require(Client.UI.Modal)
local IdleClearance = require(Client.Camera.IdleClearance)
local IdleOrbit = require(Client.Camera.IdleOrbit)
local LobbyIdleInput = require(script.Parent.LobbyIdleInput)

local IDLE = Tuning.LobbyIdle
local MOVING = 0.5 -- studs per second of root speed that counts as moving

local LobbyIdleController = {}

local function alive(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function moving(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid == nil or root == nil then
		return false
	end
	return humanoid.MoveDirection.Magnitude > 0.1 or root.AssemblyLinearVelocity.Magnitude > MOVING
end

function LobbyIdleController.Init() end

function LobbyIdleController.Start()
	if not IDLE.Enabled then
		return
	end
	local orbit = IdleOrbit.new(IdleClearance.new())
	local stirred = false
	local observer = LobbyIdleInput.new(function()
		stirred = true
		orbit:Cancel()
	end, { StickDeadzone = IDLE.StickDeadzone, MouseThreshold = IDLE.MouseThreshold })

	local function eligible(): boolean
		local state = Registry.StateController
		local trainCam = Registry.TrainCamController
		return state ~= nil
			and state.IsReady()
			and Session.phase() == "Lobby"
			and alive()
			and not Modal.anyOpen()
			and not observer:IsBlocked()
			and not (trainCam and trainCam.Active())
	end

	local quiet = LobbyIdle.new(os.clock(), IDLE.Delay)
	RunService.Heartbeat:Connect(function()
		Safe.call("LobbyIdleController", function()
			local ok = eligible()
			local active = stirred or observer:IsHeld() or moving()
			stirred = false
			if not ok or active then
				orbit:Cancel()
			end
			if LobbyIdle.step(quiet, os.clock(), ok, active) then
				orbit:Begin()
			end
		end)
	end)
end

return LobbyIdleController
