--!strict
--[[
	Local character movement: sprint with stamina, carry weight, hit slows.
	Movement is client-simulated in Roblox, so the speed the server's rules
	imply is applied here every frame from replicated inventory state.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(Shared.Logic.Inventory)

local Registry = require(script.Parent.Parent.Registry)

local MovementController = {}

local stamina = Tuning.Crew.StaminaMax
local sprintHeld = false
local sprinting = false
local lastSprintAt = 0
local slowUntil = 0

local function onSprint(
	_: string,
	inputState: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	if input.KeyCode == Enum.KeyCode.ButtonL3 then
		if inputState == Enum.UserInputState.Begin then
			sprintHeld = not sprintHeld
		end
	else
		sprintHeld = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	end
	return Enum.ContextActionResult.Pass
end

function MovementController.Init() end

function MovementController.Start()
	ContextActionService:BindAction(
		"LTO_Sprint",
		onSprint,
		true,
		Enum.KeyCode.LeftShift,
		Enum.KeyCode.RightShift,
		Enum.KeyCode.ButtonL3
	)
	ContextActionService:SetTitle("LTO_Sprint", "RUN")
	ContextActionService:SetPosition("LTO_Sprint", UDim2.new(1, -170, 1, -150))

	RunService.RenderStepped:Connect(function(dt)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local crew = Tuning.Crew
		sprinting = sprintHeld and moving and stamina > 0
		local clock = os.clock()
		if sprinting then
			stamina = math.max(stamina - crew.StaminaDrainPerSecond * dt, 0)
			lastSprintAt = clock
			if stamina <= 0 then
				sprintHeld = false
			end
		elseif clock - lastSprintAt > crew.StaminaRegenDelay then
			stamina = math.min(stamina + crew.StaminaRegenPerSecond * dt, crew.StaminaMax)
		end

		local inv = Registry.StateController.GetPrivate({ "inventory" })
		local carry = if inv and inv.items then Inventory.speedMultiplier(inv) else 1
		local slow = if clock < slowUntil then crew.HitSlowMultiplier else 1
		local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed
		humanoid.WalkSpeed = base * carry * slow
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if inv and inv.items then Inventory.jumpHeight(inv) else crew.JumpHeight
	end)
end

function MovementController.StaminaFraction(): number
	return stamina / Tuning.Crew.StaminaMax
end

function MovementController.IsSprinting(): boolean
	return sprinting
end

function MovementController.ApplyHitSlow()
	slowUntil = os.clock() + Tuning.Crew.HitSlowSeconds
end

return MovementController
