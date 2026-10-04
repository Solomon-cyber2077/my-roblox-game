--!strict
--[[
	Local character movement: a jog, a sprint that burns stamina, carry weight and
	hit slows. Movement is client-simulated in Roblox, so the speed the server's rules
	imply is applied here every frame from replicated inventory state.

	Running dry is a commitment: you cannot sprint again until a share of stamina is
	back, and for a moment you are winded and slower than your jog. That gap is where
	a Hollow catches you.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Inventory = require(Shared.Logic.Inventory)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)

local MovementController = {}

local BASE_FOV = 70

local stamina = Tuning.Crew.StaminaMax
local sprintHeld = false
local sprinting = false
local exhausted = false
local lastSprintAt = 0
local slowUntil = 0
local windedUntil = 0
local fovKick = 0
local frozen = false -- watching through the train camera: the body stays put

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
			sprinting = false
			return
		end
		local held = character:GetAttribute("GrabStyle") ~= nil
		local immobilized = frozen or held
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local crew = Tuning.Crew
		local clock = os.clock()
		if exhausted and stamina >= crew.StaminaMax * crew.ExhaustedResume then
			exhausted = false
		end
		sprinting = sprintHeld
			and moving
			and stamina > 0
			and not exhausted
			and not immobilized
			and not humanoid.Sit
		if sprinting then
			stamina = math.max(stamina - crew.StaminaDrainPerSecond * dt, 0)
			lastSprintAt = clock
			if stamina <= 0 then
				exhausted = true
				windedUntil = clock + crew.WindedSeconds
				if Registry.AudioController then
					Registry.AudioController.Play("Winded")
				end
			end
		elseif clock - lastSprintAt > crew.StaminaRegenDelay then
			stamina = math.min(stamina + crew.StaminaRegenPerSecond * dt, crew.StaminaMax)
		end

		local inv = Registry.StateController.GetPrivate({ "inventory" })
		local carry = if inv and inv.items then Inventory.speedMultiplier(inv) else 1
		local slow = if clock < slowUntil then crew.HitSlowMultiplier else 1
		local winded = if clock < windedUntil then crew.WindedMultiplier else 1
		local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed
		humanoid.WalkSpeed = if immobilized then 0 else base * carry * slow * winded
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if immobilized
			then 0
			elseif inv and inv.items then Inventory.jumpHeight(inv)
			else crew.JumpHeight
		if immobilized then
			humanoid.Jump = false
		end

		-- the camera widens with a sprint and eases back after it
		local camera = Workspace.CurrentCamera
		if camera then
			local target = if sprinting then crew.SprintFov else 0
			local kick = MathX.lerp(fovKick, target, MathX.damp(if sprinting then 0.12 else 0.25, dt))
			camera.FieldOfView += kick - fovKick
			fovKick = kick
		end
	end)
end

function MovementController.StaminaFraction(): number
	return stamina / Tuning.Crew.StaminaMax
end

function MovementController.IsSprinting(): boolean
	return sprinting
end

-- True from running dry until enough breath is back to sprint again (the HUD shows it).
function MovementController.IsExhausted(): boolean
	return exhausted
end

-- Holds the body still (and unable to jump) while the train camera is out.
function MovementController.SetFrozen(on: boolean)
	frozen = on
end

function MovementController.ApplyHitSlow()
	slowUntil = os.clock() + Tuning.Crew.HitSlowSeconds
end

-- The field of view without the sprint's kick (for anything that sets the camera's own).
function MovementController.BaseFov(): number
	return BASE_FOV
end

return MovementController
