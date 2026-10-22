--!strict
--[[
	The void mist on the client (prompts/VM5, VM6; rules in Logic/VoidMist, the look in
	Scenery/EdgeMist):

	  mist     every edge rail (tag SinkholeEdge) gets its mist when it streams in and loses it
	           with the rail
	  preset   the colour comes from the workspace attribute MistPreset (Teal, Slate, Amber;
	           Tuning.VoidMist.Presets); a change recolours everything over PresetFade seconds
	  tint     the nearer the local character is to an edge zone, the more AtmosphereController
	           tints and desaturates the grade toward the preset's tint
	  opacity  SetOpacityOffset thickens all of it
	  hum      a low hum (Config/Audio MistHum) at HumVolume x proximity, eased toward it
	  idle     no input for IdleSeconds within IdleRange of the edge mist: the mist thickens by
	           IdleOpacityBoost and the hum swells by IdleHumMult over IdleFadeIn; any input
	           (keys, mouse, a thumbstick, walking) takes both back over IdleFadeOut

	Client only: nothing here is sent anywhere, so what one player sees never changes another's.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Tuning = require(Shared.Config.Tuning)
local TutorialConfig = require(Shared.Config.Tutorial)
local VoidMist = require(Shared.Logic.VoidMist)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local EdgeMist = require(script.Parent.Parent.Scenery.EdgeMist)

local V = Tuning.VoidMist
local PRESET_FADE = 2 -- seconds a preset change takes
local NEAR = 30 -- studs: rails further than this (plus half their width) are not measured

local MistController = {}

local handles: { [BasePart]: EdgeMist.Handle } = {}
local opacityOffset = 0
local lastInput = os.clock()
local idleLevel = 0 -- 0..1, how far the idle reaction has come in
local humVolume = 0

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- The colour shown now and the one it is fading to.
local _, defaultPreset = VoidMist.preset(nil)
local shownMist = rgb(defaultPreset.mist)
local shownTint = rgb(defaultPreset.tint)
local fromMist, fromTint = shownMist, shownTint
local toMist, toTint = shownMist, shownTint
local fadeStart = -math.huge

local function presetChanged()
	local name = Workspace:GetAttribute("MistPreset")
	local _, preset = VoidMist.preset(if type(name) == "string" then name else nil)
	fromMist, fromTint = shownMist, shownTint
	toMist, toTint = rgb(preset.mist), rgb(preset.tint)
	fadeStart = os.clock()
end

local function add(instance: Instance)
	if instance:IsA("BasePart") and handles[instance] == nil then
		local handle = EdgeMist.build(instance, instance)
		EdgeMist.setColor(handle, shownMist)
		if opacityOffset ~= 0 then
			EdgeMist.setOpacityOffset(handle, opacityOffset)
		end
		handles[instance] = handle
	end
end

local function remove(instance: Instance)
	local handle = handles[instance :: BasePart]
	if handle then
		handles[instance :: BasePart] = nil
		EdgeMist.destroy(handle)
	end
end

-- Ground distance from the local character to the nearest edge zone, or math.huge.
function MistController.Distance(): number
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil then
		return math.huge
	end
	local p = root.Position
	local best = math.huge
	for rail in handles do
		local gap = (rail.Position - p) * Vector3.new(1, 0, 1)
		if gap.Magnitude <= NEAR + rail.Size.X / 2 then
			local look = rail.CFrame.LookVector
			local zone = VoidMist.zone(rail.Position.X, rail.Position.Z, look.X, look.Z, rail.Size.X)
			best = math.min(best, VoidMist.distanceTo(zone, p.X, p.Z))
		end
	end
	return best
end

-- Thicker mist: transparency taken off every layer (0 is the normal look).
function MistController.SetOpacityOffset(offset: number)
	if math.abs(offset - opacityOffset) < 0.002 then
		return
	end
	opacityOffset = offset
	for _, handle in handles do
		EdgeMist.setOpacityOffset(handle, offset)
	end
end

-- Whether the local player is idle by the mist: no input for IdleSeconds, within IdleRange.
function MistController.IsIdle(): boolean
	return idleLevel > 0
end

local function frame(dt: number)
	local now = os.clock()
	if now - fadeStart <= PRESET_FADE + 0.1 then
		local a = math.clamp((now - fadeStart) / PRESET_FADE, 0, 1)
		shownMist = fromMist:Lerp(toMist, a)
		shownTint = fromTint:Lerp(toTint, a)
		for _, handle in handles do
			EdgeMist.setColor(handle, shownMist)
		end
	end
	local distance = MistController.Distance()
	local proximity = VoidMist.proximity(distance)
	Registry.AtmosphereController.SetMistTint(proximity, shownTint)

	-- idle: walking counts as input (a held key raises no new event)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MoveDirection.Magnitude > 0 then
		lastInput = now
	end
	local idle = now - lastInput > V.IdleSeconds and distance <= V.IdleRange
	if idle then
		idleLevel = math.min(1, idleLevel + dt / V.IdleFadeIn)
	else
		idleLevel = math.max(0, idleLevel - dt / V.IdleFadeOut)
	end
	MistController.SetOpacityOffset(V.IdleOpacityBoost * idleLevel)

	-- the hum: proximity, swelled while idle, eased toward its target
	local sound = Registry.AudioController.LoopSound("MistHum")
	if sound then
		local target = V.HumVolume * proximity * (1 + (V.IdleHumMult - 1) * idleLevel)
		humVolume += (target - humVolume) * math.min(1, dt * V.HumSmoothing)
		sound.Volume = humVolume
	end
end

function MistController.Init() end

function MistController.Start()
	for _, instance in CollectionService:GetTagged(TutorialConfig.EdgeTag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(TutorialConfig.EdgeTag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(TutorialConfig.EdgeTag):Connect(remove)
	Workspace:GetAttributeChangedSignal("MistPreset"):Connect(presetChanged)
	presetChanged()
	fadeStart = -math.huge -- the first colour is shown at once
	shownMist, shownTint = toMist, toTint
	local function touched()
		lastInput = os.clock()
	end
	UserInputService.InputBegan:Connect(touched)
	-- mouse movement and thumbsticks arrive as changes, not beginnings
	UserInputService.InputChanged:Connect(touched)
	Registry.AudioController.Loop("MistHum", "MistHum", SoundService)
	RunService.RenderStepped:Connect(function(dt)
		Safe.call("MistController", frame, dt)
	end)
end

return MistController
