--!strict
--[[
	The hull's effects as it fails (Logic/HullTier, Difficulty.Hull.Tiers), always on during a run:
	  below 75%  the train creaks now and then, and a first warning
	  below 50%  the train's lamps flicker (TrainVisualsController reads LightScale)
	  below 25%  emergency lighting (the lamps go red, LightTint) and the alarm
	Each tier's warning shows once as it is crossed. With Broken Things Markers off there is no
	leak alert, so everything here plays a notch stronger (HullTier.strength).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local HullTier = require(Shared.Logic.HullTier)
local Safe = require(Shared.Util.Safe)

local Registry = require(script.Parent.Parent.Registry)
local Session = require(script.Parent.Parent.Session)
local BrokenThingMarkers = require(script.Parent.Parent.UI.BrokenThingMarkers)
local Overlay = require(script.Parent.Parent.UI.Overlay)
local Theme = require(script.Parent.Parent.UI.Theme)

local HullController = {}

local CREAK_EVERY = { 9, 6, 4 } -- seconds between creaks at tiers 1, 2, 3
local ALARM_EVERY = 3.4
local EMERGENCY = Color3.fromRGB(255, 58, 40)
local WARNINGS = {
	"HULL BELOW 75%: SHE'S STARTING TO GIVE",
	"HULL BELOW 50%: THE LIGHTS ARE FAILING",
	"HULL BELOW 25%: EMERGENCY! REPAIR AT THE WORKBENCH",
}

local tier = 0
local warned = 0 -- the highest tier warned of this run
local runId = ""
local nextCreak = 0
local nextAlarm = 0

local function strength(): number
	return HullTier.strength(BrokenThingMarkers.visible())
end

local function audio(cue: string, gain: number, pitch: number?)
	if Registry.AudioController then
		Registry.AudioController.Play(cue, nil, gain, pitch)
	end
end

local function onTrain(train: any)
	if type(train) ~= "table" or type(train.integrity) ~= "number" then
		return
	end
	tier = HullTier.tier(train.integrity, train.integrityMax)
	local run = Registry.StateController.Get({ "run" }) or {}
	if run.runId ~= runId then
		runId = run.runId or ""
		warned = 0
	end
	if tier > warned and Session.isRunActive() then
		warned = tier
		Overlay.alert(WARNINGS[tier], if tier >= 3 then Theme.Color.signal else Theme.Color.caution, 3)
	elseif tier < warned then
		warned = tier -- repaired: crossing down again warns again
	end
end

local function creak(atTier: number, s: number)
	audio("SkyGroan", math.min(0.28 * s * (0.8 + 0.2 * atTier), 0.9), 0.55 + math.random() * 0.25)
end

local function alarm(s: number)
	audio("Alarm", math.min(0.4 * s, 0.85), 0.92)
end

local function step()
	if not Session.isRunActive() or tier == 0 then
		return
	end
	local clock = os.clock()
	local s = strength()
	if clock >= nextCreak then
		nextCreak = clock + CREAK_EVERY[tier] / s * (0.8 + math.random() * 0.4)
		creak(tier, s)
	end
	if tier >= 3 and clock >= nextAlarm then
		nextAlarm = clock + ALARM_EVERY / s
		alarm(s)
	end
end

-- Studio only: Dev `sound creak|alarm` plays one as at the Emergency tier (DevService).
local function devSound()
	local kind = string.match((ReplicatedStorage:GetAttribute("DevSound") :: string?) or "", "^(%a+)@")
	if kind == "creak" then
		creak(3, strength())
	elseif kind == "alarm" then
		alarm(strength())
	end
end

-- The share of its brightness the train's lamp `i` has at time `t` (1 when the hull is sound).
function HullController.LightScale(t: number, i: number): number
	if not Session.isRunActive() or tier < 2 then
		return 1
	end
	local s = strength()
	if tier >= 3 then
		-- emergency lamps: dim and pulsing
		return 0.55 + 0.25 * math.sin(t * 3 * s)
	end
	-- failing: now and then a lamp drops out
	local n = math.noise(t * 5.5, i * 3.3, 0.5)
	return if n > 0.42 / s then 0.12 else 1
end

-- The emergency tint for the train's lamps, or nil.
function HullController.LightTint(): Color3?
	return if Session.isRunActive() and tier >= 3 then EMERGENCY else nil
end

function HullController.Tier(): number
	return tier
end

function HullController.Init() end

function HullController.Start()
	Registry.StateController.Observe("public", { "train" }, onTrain)
	RunService.Heartbeat:Connect(function()
		Safe.call("HullController.step", step)
	end)
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("DevSound"):Connect(devSound)
	end
end

return HullController
