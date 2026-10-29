--!strict
--[[
	Local character movement: a jog, a sprint that burns stamina, carry weight and
	hit slows. Movement is client-simulated in Roblox, so the speed the server's rules
	imply is applied here every frame from replicated inventory state.

	Running dry is a commitment: you cannot sprint again until a share of stamina is
	back, and for a moment you are winded and slower than your jog. That gap is where
	a Hollow catches you.

	Shift is held to sprint. The touch RUN button and the gamepad's stick click toggle it
	instead (one thumb is on the stick, the other turns the camera); a toggled sprint ends
	when you stand still for TOGGLE_IDLE seconds. Running dry pauses it like a held Shift
	(Tuning.Crew.ToggleSprintResumes): it picks up again once the breath is back, so a phone
	player mid-chase does not have to find the RUN button again.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local Haul = require(Shared.Config.Haul)
local Inventory = require(Shared.Logic.Inventory)
local MathX = require(Shared.Util.MathX)

local Registry = require(script.Parent.Parent.Registry)
local Net = require(script.Parent.Parent.Net)

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
local sprintToggled = false -- the sprint is on from a tap (touch RUN, gamepad stick click)
local stillSince: number? = nil
local TOGGLE_IDLE = 1 -- seconds standing still that end a toggled sprint

local function onSprint(
	_: string,
	inputState: Enum.UserInputState,
	input: InputObject
): Enum.ContextActionResult
	local character = Players.LocalPlayer.Character
	local carriers = if character then character:GetAttribute("PayrollCarriers") else nil
	if typeof(carriers) == "number" and carriers > 0 then
		sprintHeld = false
		return Enum.ContextActionResult.Sink
	end
	if input.KeyCode == Enum.KeyCode.ButtonL3 or input.UserInputType == Enum.UserInputType.Touch then
		if inputState == Enum.UserInputState.Begin then
			sprintHeld = not sprintHeld
			sprintToggled = sprintHeld
			stillSince = nil
			ContextActionService:SetTitle("LTO_Sprint", if sprintHeld then "WALK" else "RUN")
		end
	else
		sprintToggled = false
		sprintHeld = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
	end
	-- Shift is also Roblox's shift-lock switch: passing it on toggled shift lock with every
	-- sprint and left the cursor locked to the middle of the screen
	return Enum.ContextActionResult.Sink
end

function MovementController.Init() end

function MovementController.Start()
	UserInputService.JumpRequest:Connect(function()
		local character = Players.LocalPlayer.Character
		if character == nil or character:GetAttribute("GrabStyle") ~= nil then
			return
		end
		local grasp = character:GetAttribute("Grasp")
		if grasp == "Hang" or grasp == "Haul" or grasp == "Miss" then
			return
		end
		local departure = Registry.DepartureClock
		local phase = Registry.StateController.Get({ "run", "phase" })
		if
			phase == "Departure"
			and departure
			and not departure.InGrace()
			and character:GetAttribute("OffTrain") == true
		then
			Net.Fire("Grasp")
		end
	end)
	ContextActionService:BindActionAtPriority(
		"LTO_Sprint",
		onSprint,
		true,
		Enum.ContextActionPriority.High.Value,
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
		local grasp = character:GetAttribute("Grasp")
		local grasping = grasp == "Hang" or grasp == "Haul"
		local carriers = character:GetAttribute("PayrollCarriers")
		local carrying = typeof(carriers) == "number" and carriers > 0
		local immobilized = frozen or held or grasping
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		local crew = Tuning.Crew
		local clock = os.clock()
		-- a tapped sprint ends on its own once you stop, or when your breath runs out
		if sprintToggled then
			if moving then
				stillSince = nil
			elseif stillSince == nil then
				stillSince = clock
			end
			local dry = exhausted and not Tuning.Crew.ToggleSprintResumes
			if dry or (stillSince ~= nil and clock - stillSince > TOGGLE_IDLE) then
				sprintHeld, sprintToggled, stillSince = false, false, nil
				ContextActionService:SetTitle("LTO_Sprint", "RUN")
			end
		end
		if exhausted and stamina >= crew.StaminaMax * crew.ExhaustedResume then
			exhausted = false
		end
		sprinting = sprintHeld
			and moving
			and stamina > 0
			and not exhausted
			and not immobilized
			and not humanoid.Sit
			and not carrying
		local inLobby = Registry.StateController
			and Registry.StateController.Get({ "run", "phase" }) == "Lobby"
		if inLobby then
			-- the lobby is for stretching your legs: stamina never runs down there
			stamina = crew.StaminaMax
			exhausted = false
			lastSprintAt = clock
		elseif sprinting then
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
		local carry = if carrying
			then 1 - if carriers == 2 then Haul.DuoPenalty else Haul.SoloPenalty
			else if inv and inv.items then Inventory.speedMultiplier(inv) else 1
		local slow = if clock < slowUntil then crew.HitSlowMultiplier else 1
		local winded = if clock < windedUntil then crew.WindedMultiplier else 1
		local base = if sprinting then crew.SprintSpeed else crew.WalkSpeed
		-- a stick moves you at WalkSpeed times how far it is pushed; a thumb rarely holds it at
		-- the rim, so a tapped sprint with the stick past SprintMinPush runs at full sprint speed
		local push = humanoid.MoveDirection.Magnitude
		local reach = if sprinting
				and sprintToggled
				and push > 0.1
			then 1 / math.clamp(push, crew.SprintMinPush, 1)
			else 1
		humanoid.WalkSpeed = if immobilized then 0 else base * carry * slow * winded * reach
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
