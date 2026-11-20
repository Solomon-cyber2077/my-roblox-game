--!strict
--[[
	Finishing touches follow the graphics setting. Builders tag a part "Detail" when the scene
	reads without it (a lantern's corner bars, a door back's window frame, a cornice's bead): the
	visual audit holds a model's part budget to everything else, and caps the full build
	separately. Under Settings' Performance this client hides every Detail part
	(LocalTransparencyModifier 1: a fully transparent part is not drawn); under Quality they show.
	Hidden, not removed: doors and anything else that moves or tracks these parts keep working,
	and parts that stream in later are caught as they arrive. A SurfaceGui tagged DetailFallback
	is the plain version of a Detail mesh laid over it (Builders/SignArt): it shows only while
	the details are hidden. A part tagged DetailFallback is the same for a mesh (a passenger's lighter
	phone hair or hat, Builders/PassengerFigure): drawn only under Performance.
	A ParticleEmitter tagged DetailEmitter is scaled down, never removed, under Performance: its
	Rate and Lifetime are multiplied by its LiteScale attribute (default 0.4).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DetailController = {}

local TAG = "Detail"
local FALLBACK = "DetailFallback"
local EMITTER = "DetailEmitter"
local SETTING = "GraphicsQuality"

local hidden = false

local function performance(): boolean
	return Players.LocalPlayer:GetAttribute(SETTING) == "Performance"
end

local function apply(part: Instance)
	if part:IsA("BasePart") then
		part.LocalTransparencyModifier = if hidden then 1 else 0
	end
end

local function applyFallback(gui: Instance)
	if gui:IsA("SurfaceGui") then
		gui.Enabled = hidden
	elseif gui:IsA("BasePart") then
		gui.LocalTransparencyModifier = if hidden then 0 else 1
	end
end

-- The emitter's full Rate and Lifetime are kept as attributes the first time it is seen.
local function applyEmitter(emitter: Instance)
	if not emitter:IsA("ParticleEmitter") then
		return
	end
	if emitter:GetAttribute("FullRate") == nil then
		emitter:SetAttribute("FullRate", emitter.Rate)
		emitter:SetAttribute("FullLifeMin", emitter.Lifetime.Min)
		emitter:SetAttribute("FullLifeMax", emitter.Lifetime.Max)
	end
	local scale = if hidden then (emitter:GetAttribute("LiteScale") :: number? or 0.4) else 1
	emitter.Rate = (emitter:GetAttribute("FullRate") :: number) * scale
	local lifeScale = if hidden then math.max(scale, 0.6) else 1
	emitter.Lifetime = NumberRange.new(
		(emitter:GetAttribute("FullLifeMin") :: number) * lifeScale,
		(emitter:GetAttribute("FullLifeMax") :: number) * lifeScale
	)
end

local function applyAll()
	hidden = performance()
	for _, part in CollectionService:GetTagged(TAG) do
		apply(part)
	end
	for _, gui in CollectionService:GetTagged(FALLBACK) do
		applyFallback(gui)
	end
	for _, emitter in CollectionService:GetTagged(EMITTER) do
		applyEmitter(emitter)
	end
end

function DetailController.Init() end

function DetailController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
	CollectionService:GetInstanceAddedSignal(FALLBACK):Connect(applyFallback)
	CollectionService:GetInstanceAddedSignal(EMITTER):Connect(applyEmitter)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING):Connect(applyAll)
	applyAll()
end

-- Whether finishing touches are hidden right now (the Performance setting).
function DetailController.Hidden(): boolean
	return hidden
end

return DetailController
