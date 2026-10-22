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
	  opacity  SetOpacityOffset thickens all of it (the idle reaction)

	Client only: nothing here is sent anywhere, so what one player sees never changes another's.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local TutorialConfig = require(Shared.Config.Tutorial)
local VoidMist = require(Shared.Logic.VoidMist)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local EdgeMist = require(script.Parent.Parent.Scenery.EdgeMist)

local PRESET_FADE = 2 -- seconds a preset change takes
local NEAR = 30 -- studs: rails further than this (plus half their width) are not measured

local MistController = {}

local handles: { [BasePart]: EdgeMist.Handle } = {}
local opacityOffset = 0

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

local function frame()
	local now = os.clock()
	if now - fadeStart <= PRESET_FADE + 0.1 then
		local a = math.clamp((now - fadeStart) / PRESET_FADE, 0, 1)
		shownMist = fromMist:Lerp(toMist, a)
		shownTint = fromTint:Lerp(toTint, a)
		for _, handle in handles do
			EdgeMist.setColor(handle, shownMist)
		end
	end
	Registry.AtmosphereController.SetMistTint(VoidMist.proximity(MistController.Distance()), shownTint)
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
	RunService.RenderStepped:Connect(function()
		Safe.call("MistController", frame)
	end)
end

return MistController
