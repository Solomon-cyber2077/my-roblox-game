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
	the details are hidden.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DetailController = {}

local TAG = "Detail"
local FALLBACK = "DetailFallback"
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
	end
end

local function applyAll()
	hidden = performance()
	for _, part in CollectionService:GetTagged(TAG) do
		apply(part)
	end
	for _, gui in CollectionService:GetTagged(FALLBACK) do
		applyFallback(gui)
	end
end

function DetailController.Init() end

function DetailController.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(apply)
	CollectionService:GetInstanceAddedSignal(FALLBACK):Connect(applyFallback)
	Players.LocalPlayer:GetAttributeChangedSignal(SETTING):Connect(applyAll)
	applyAll()
end

-- Whether finishing touches are hidden right now (the Performance setting).
function DetailController.Hidden(): boolean
	return hidden
end

return DetailController
