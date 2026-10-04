--!strict
--[[
	Your side of a grab (Config/Grabs). While a Hollow holds you (the GrabStyle attribute
	the server puts on your character):

	  * the struggle plate (UI/Struggle) names what it is doing to you and shows the hold
	    weakening as you fight (GrabEscape, from the server)
	  * Space, gamepad A or a tap on the plate is one struggle: a Struggle remote, the
	    keycap punching down, a jolt of the camera, and your body thrashing harder
	    (CharacterAnimator reads Struggle())
	  * the view is dragged round toward the thing's face, every bite jolts it and pulses
	    the screen red, and your heart pounds
	  * when you tear free (or a flash makes it let go) you are thrown clear

	Your own "Pull free" prompt is the crew's, not yours: it is hidden on this client.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Grabs = require(Shared.Config.Grabs)

local Net = require(script.Parent.Parent.Net)
local Registry = require(script.Parent.Parent.Registry)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Struggle = require(script.Parent.Parent.UI.Struggle)
local Theme = require(script.Parent.Parent.UI.Theme)

local GrabController = {}

local ACTION = "LTO_Struggle"
local OUTCOMES: { [string]: { text: string, color: Color3 } } = {
	Escaped = { text = "YOU TORE FREE. RUN!", color = Theme.Color.go },
	Flash = { text = "IT LET GO. RUN!", color = Theme.Color.sky },
	Timeout = { text = "IT DROPPED YOU. RUN!", color = Theme.Color.caution },
}

local held = false
local struggle = 0 -- 0..1 how hard you have been fighting lately
local escapeShown = 0
local heartAt = 0
local watching: RBXScriptConnection? = nil

local function audio(cue: string, gain: number?, pitch: number?)
	if Registry.AudioController then
		Registry.AudioController.Play(cue, nil, gain, pitch)
	end
end

local function character(): Model?
	return Players.LocalPlayer.Character
end

-- One struggle against the hold.
local function press()
	if not held then
		return
	end
	Net.Fire("Struggle")
	struggle = math.min(struggle + 0.3, 1)
	Struggle.punch()
	Registry.CameraController.Shake(0.12)
	audio("Winded", 0.35, 0.8 + math.random() * 0.3)
end

local function onAction(_: string, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		press()
	end
	-- the jump key must not jump (nor anything else) while it has you
	return Enum.ContextActionResult.Sink
end

-- The Hollow that has you, and where its face is.
local function holderHead(model: Model): Vector3?
	local link = model:FindFirstChild("GrabbedBy")
	local hollow = if link and link:IsA("ObjectValue") then link.Value else nil
	if hollow and hollow:IsA("Model") then
		local head = hollow:FindFirstChild("Head") :: BasePart?
		if head then
			return head.Position
		end
	end
	return nil
end

local function hidePry(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then
		for _, prompt in root:GetChildren() do
			if prompt:IsA("ProximityPrompt") and prompt:GetAttribute("Action") == "Pry" then
				prompt.Enabled = false
			end
		end
	end
end

local function begin(model: Model, style: string)
	local def = Grabs.ById[style]
	local kind = (model:GetAttribute("GrabKind") :: string?) or "Stalker"
	held = true
	struggle = 0.6
	escapeShown = 0
	Struggle.show(if def then def.name else "IT HAS YOU", kind)
	ContextActionService:BindActionAtPriority(
		ACTION,
		onAction,
		false,
		Enum.ContextActionPriority.High.Value + 100,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonR2
	)
	hidePry(model)
	task.delay(0.1, function()
		if held then
			hidePry(model)
		end
	end)
end

local function finish(model: Model)
	if not held then
		return
	end
	held = false
	ContextActionService:UnbindAction(ACTION)
	Struggle.hide()
	Registry.CameraController.Focus(nil)
	local outcome = OUTCOMES[(model:GetAttribute("GrabOutcome") :: string?) or ""]
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if outcome and humanoid and humanoid.Health > 0 then
		Overlay.alert(outcome.text, outcome.color, 2.4)
	end
end

local function watch(model: Model)
	if watching then
		watching:Disconnect()
	end
	watching = model:GetAttributeChangedSignal("GrabStyle"):Connect(function()
		if model ~= Players.LocalPlayer.Character then
			return
		end
		local style = model:GetAttribute("GrabStyle") :: string?
		if style then
			begin(model, style)
		else
			finish(model)
		end
	end)
	local style = model:GetAttribute("GrabStyle") :: string?
	if style then
		begin(model, style)
	end
end

function GrabController.Init() end

function GrabController.Start()
	local ui = Registry.UIController.Gui()
	Struggle.mount(ui, press)
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(function(model)
		finish(model)
		if watching then
			watching:Disconnect()
			watching = nil
		end
	end)
	player.CharacterAdded:Connect(function(model)
		if held then
			held = false
			ContextActionService:UnbindAction(ACTION)
			Struggle.hide()
			Registry.CameraController.Focus(nil)
		end
		watch(model)
	end)
	if player.Character then
		watch(player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		struggle *= math.exp(-dt * 2.2)
		if not held then
			return
		end
		local model = character()
		if model == nil then
			return
		end
		local now = Workspace:GetServerTimeNow()
		local escape = (model:GetAttribute("GrabEscape") :: number?) or 0
		escapeShown += (escape - escapeShown) * math.min(dt * 12, 1)
		Struggle.set(escapeShown, now)
		-- the view is dragged round to its face
		Registry.CameraController.Focus(holderHead(model))
		-- your heart, quickening as the hold wears you down
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local life = if humanoid then humanoid.Health / math.max(humanoid.MaxHealth, 1) else 1
		if os.clock() >= heartAt then
			heartAt = os.clock() + 0.42 + 0.35 * life
			audio("Heartbeat", 0.9, 1)
			Registry.CameraController.Pulse(0.6)
		end
	end)
end

-- How hard you are fighting right now, 0..1 (your body thrashes with it).
function GrabController.Struggle(): number
	return if held then struggle else 0
end

function GrabController.IsHeld(): boolean
	return held
end

-- A bite, squeeze or yank landed on you (Fx from HollowService).
function GrabController.Bite()
	Overlay.pulse(Theme.Color.signal, 0.85, 0.5)
	Registry.CameraController.Shake(0.55)
	audio("Hit", 0.75, 0.85)
end

-- It just seized you.
function GrabController.Seized()
	Overlay.pulse(Theme.Color.signal, 1, 0.9)
	Registry.CameraController.Shake(1)
	audio("Hit", 1, 0.7)
end

-- A crewmate is tearing at it.
function GrabController.Pried(name: string)
	Struggle.helped(name)
end

-- Thrown clear as the hold breaks: the push lands once the server lets your body go.
function GrabController.Thrown(knockback: Vector3)
	task.spawn(function()
		local model = character()
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root == nil then
			return
		end
		local deadline = os.clock() + 0.6
		while root.Anchored and os.clock() < deadline do
			RunService.Heartbeat:Wait()
		end
		if not root.Anchored then
			root.AssemblyLinearVelocity += knockback
		end
	end)
end

return GrabController
