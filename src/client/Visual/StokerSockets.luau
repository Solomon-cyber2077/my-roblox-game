--!strict
--[[
	The Stoker's hollow eye sockets breathing out (Logic/StokerSockets picks which): two points on his head, each
	with a faint frost puff, a fog wisp and a thread of embers, one of them on at a time. Performance plays them
	at Tuning.BruteRemake.Sockets.PerfShare of the rate: thinner, never gone.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tuning = require(ReplicatedStorage.Shared.Config.Tuning)

local S = Tuning.BruteRemake.Sockets
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

export type Handle = {
	emitters: { [string]: { ParticleEmitter } },
	rates: { [ParticleEmitter]: number },
	mode: string,
}

local StokerSockets = {}

local function curve(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function make(at: Attachment, mode: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Socket" .. mode
	e.EmissionDirection = Enum.NormalId.Front -- out of the face
	e.Enabled = false
	if mode == "Frost" then
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(214, 222, 228))
		e.Rate = 4
		e.Lifetime = NumberRange.new(0.8, 1.3)
		e.Speed = NumberRange.new(0.8, 1.4)
		e.Drag = 2
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = curve(0.12, 0.8)
		e.Transparency = curve(0.6, 1)
	elseif mode == "Fog" then
		e.Texture = SMOKE
		e.Color = ColorSequence.new(Color3.fromRGB(120, 124, 126))
		e.Rate = 3
		e.Lifetime = NumberRange.new(1.6, 2.6)
		e.Speed = NumberRange.new(0.3, 0.6)
		e.Drag = 1
		e.Acceleration = Vector3.new(0, -0.4, 0) -- fog sinks
		e.SpreadAngle = Vector2.new(25, 25)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Size = curve(0.25, 1.4)
		e.Transparency = curve(0.72, 1)
	else
		e.Texture = SPARK
		e.Color = ColorSequence.new(Color3.fromRGB(255, 140, 50))
		e.LightEmission = 1
		e.Rate = 1.5
		e.Lifetime = NumberRange.new(0.8, 1.4)
		e.Speed = NumberRange.new(0.4, 0.8)
		e.Acceleration = Vector3.new(0, 1.5, 0)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Size = curve(0.09, 0.03)
		e.Transparency = curve(0.35, 1)
	end
	e.Parent = at
	return e
end

-- The sockets on `head` (the block or the part the head mesh is welded to).
function StokerSockets.attach(head: BasePart): Handle
	local handle: Handle = { emitters = { Frost = {}, Fog = {}, Embers = {} }, rates = {}, mode = "" }
	for _, mouth in { S.L, S.R } do
		local at = Instance.new("Attachment")
		at.Name = "Socket"
		at.Position = Vector3.new(mouth[1], mouth[2], mouth[3])
		at.Parent = head
		for mode, list in handle.emitters do
			local e = make(at, mode)
			handle.rates[e] = e.Rate
			table.insert(list, e)
		end
	end
	return handle
end

-- Turn on `mode`'s pair (and off the others), thinner on the Performance setting.
function StokerSockets.set(handle: Handle, mode: string)
	local share = if Players.LocalPlayer:GetAttribute("GraphicsQuality") == "Performance"
		then S.PerfShare
		else 1
	for name, list in handle.emitters do
		for _, e in list do
			e.Enabled = name == mode
			e.Rate = (handle.rates[e] or e.Rate) * share
		end
	end
	handle.mode = mode
end

return StokerSockets
