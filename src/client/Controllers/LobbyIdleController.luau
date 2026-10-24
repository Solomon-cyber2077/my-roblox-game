--!strict
--[[
	The Depot Hall idle view (docs/direction/2026-10-23_lobby-idle-final.md). Off unless
	Tuning.LobbyIdle.Enabled. After Delay seconds of continuous quiet while eligible
	(Logic/LobbyIdle), the view slowly turns round our character (Camera/IdleOrbit); any
	deliberate input, held control, movement or loss of eligibility cancels it at once and a
	fresh quiet interval is needed. One attempt per interval. The hall piano comes up at the same
	moment (AudioController.SetIdle) whether or not the view can turn, and goes down on the same
	cancel.

	Eligible: a state snapshot received, phase Lobby (the departure Countdown is not), our own
	living character standing on the hall floor (Tuning.LobbyIdle.Hall, so not on the track or the
	display road), no modal or MENU dropdown, the Roblox menu shut, no text or chat focus, the
	window focused and the train camera off. Losing any of it cancels both the turn and the piano;
	a new character starts a fresh interval. Reduced motion stops the turn (IdleOrbit) and the
	notes (PianoNotes) but not the piano.
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
local Menu = require(Client.UI.Menu)
local Modal = require(Client.UI.Modal)
local IdleClearance = require(Client.Camera.IdleClearance)
local IdleOrbit = require(Client.Camera.IdleOrbit)
local LobbyIdleInput = require(script.Parent.LobbyIdleInput)

local IDLE = Tuning.LobbyIdle
local MOVING = 0.5 -- studs per second of root speed that counts as moving
local ORIGIN = Tuning.World.LobbyOrigin

local LobbyIdleController = {}

local function alive(): boolean
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function inHall(): boolean
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return false
	end
	local p = root.Position
	return LobbyIdle.inHall(p.X - ORIGIN[1], p.Y - ORIGIN[2], p.Z - ORIGIN[3], IDLE.Hall)
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
			and inHall()
			and not Modal.anyOpen()
			and not Menu.isOpen()
			and not observer:IsBlocked()
			and not (trainCam and trainCam.Active())
	end

	local audio = Registry.AudioController
	local idle = false
	local quiet = LobbyIdle.new(os.clock(), IDLE.Delay)
	local function release()
		orbit:Cancel()
		if idle then
			idle = false
			audio.SetIdle(false)
		end
	end
	-- a new body (respawn) starts over: no turn or piano carried across, a fresh quiet interval
	Players.LocalPlayer.CharacterAdded:Connect(function()
		release()
		LobbyIdle.reset(quiet, os.clock())
	end)
	RunService.Heartbeat:Connect(function()
		Safe.call("LobbyIdleController", function()
			local ok = eligible()
			local active = stirred or observer:IsHeld() or moving()
			stirred = false
			if not ok or active then
				release()
			end
			if LobbyIdle.step(quiet, os.clock(), ok, active) then
				idle = true
				audio.SetIdle(true)
				orbit:Begin()
			end
		end)
	end)
end

return LobbyIdleController
