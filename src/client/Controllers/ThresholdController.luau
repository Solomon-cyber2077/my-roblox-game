--!strict
--[[
	The train's door threshold, for the local player only. Every frame it checks whether your
	character stands inside the carriage or the cab (the boxes TrainService.IsInside uses,
	published as ReplicatedStorage.TrainVolumes) and eases between the two worlds with
	Logic/Threshold:

	  Out()      0 aboard .. 1 out at the station: the station's cold grade (AtmosphereController)
	             and its sound (AudioController) come in, and go back to the train's warmth.
	  Shelter()  0..1 the carriage walls between you and the night (AudioController's muffle).
	  Crossed    fires (inside) the moment you step through a door during a run.

	Nothing here touches controls, the camera or the screen's brightness, and it answers at
	once on this client rather than waiting for the server's Aboard status.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Threshold = require(Shared.Logic.Threshold)
local Tuning = require(Shared.Config.Tuning)
local Safe = require(Shared.Util.Safe)

local Session = require(script.Parent.Parent.Session)

local ThresholdController = {}

local crossed = Instance.new("BindableEvent")
ThresholdController.Crossed = crossed.Event

local boxes: { { cframe: CFrame, half: Vector3 } } = {}
local inside = false
local known = false -- the first frame only learns where you are; it is not a crossing
local last: Vector3? = nil
local out = 0
local shelter = 0

local function isInside(position: Vector3, grow: number): boolean
	for _, box in boxes do
		local p = box.cframe:PointToObjectSpace(position)
		if Threshold.within(p.X, p.Y, p.Z, box.half.X, box.half.Y, box.half.Z, grow) then
			return true
		end
	end
	return false
end

local function frame(dt: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root == nil or #boxes == 0 then
		return
	end
	local position = root.Position
	local now = isInside(position, Threshold.grow(inside))
	local jumped = last ~= nil and (position - last :: Vector3).Magnitude > Tuning.Threshold.Teleport
	last = position
	if now ~= inside then
		inside = now
		if known and not jumped and Session.isRunActive() then
			crossed:Fire(inside)
		end
	end
	known = true
	out = Threshold.stepOut(out, inside, dt)
	shelter = Threshold.stepShelter(shelter, inside, out, dt)
end

function ThresholdController.Init() end

function ThresholdController.Start()
	task.spawn(function()
		local volumes = ReplicatedStorage:WaitForChild("TrainVolumes")
		for _, name in { "Car", "Cab" } do
			local cframe = volumes:GetAttribute(name .. "CFrame")
			local size = volumes:GetAttribute(name .. "Size")
			if typeof(cframe) == "CFrame" and typeof(size) == "Vector3" then
				table.insert(boxes, { cframe = cframe, half = size / 2 })
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		Safe.call("ThresholdController", frame, dt)
	end)
end

function ThresholdController.Inside(): boolean
	return inside
end

-- 0 aboard .. 1 at the station, eased: the share of the station's own light and sound.
function ThresholdController.Out(): number
	return Threshold.ease(out)
end

function ThresholdController.Shelter(): number
	return shelter
end

return ThresholdController
